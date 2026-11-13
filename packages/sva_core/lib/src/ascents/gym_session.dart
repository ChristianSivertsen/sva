import 'package:sva_core/src/ascents/ascent_rules.dart';
import 'package:sva_core/src/ascents/gym_projects.dart';

/// A gym route climbed in a session, before it is saved: on a wall, of a
/// kind (`boulder` or `rope`), with a colour or a grade (both `null` in an
/// ungraded gym). Two taps with the same key may be the same climb.
typedef GymRouteKey = ({
  String wallId,
  String kind,
  String? colourId,
  String? gradeId,
});

/// One tap in the gym log: on `route` (an index into
/// [GymSessionLog.routes]), topped or not, after `tries` tries, and how on
/// a rope (`lead` or `toprope`, `null` for a boulder).
typedef GymTapEntry = ({int route, bool topped, int tries, String? ropeType});

/// Most tries one tap can count; more is a typo.
const maxTriesPerTap = 99;

/// An open project from an earlier session at this gym: the route's `id`,
/// what it is, the `tries` on it so far and the day it was `lastTried`
/// (`YYYY-MM-DD`).
typedef GymPastRoute = ({
  String id,
  GymRouteKey key,
  int tries,
  String lastTried,
});

/// Why a climb might be another one: tried earlier in this session, a
/// project from an earlier session, or sent earlier in this session.
enum GymMatchKind { triedToday, project, sentToday }

/// A climb an entry might be instead: [GymSessionLog.routes] index `route`,
/// or the project `pastId` from [GymSessionLog.past].
typedef GymMatch = ({GymMatchKind kind, int? route, String? pastId});

/// The taps of one gym session, in order, and the routes they are on
/// (prototype/gym-log.html). Routes are new, or open projects from earlier
/// sessions ([past]), whose tries count. Immutable: every change returns a
/// new log.
final class GymSessionLog {
  /// An empty log at a gym where [past] are your open projects.
  const new({this.past = const []})
    : routes = const [],
      routeIds = const [],
      entries = const [];

  const new _(this.routes, this.routeIds, this.entries, this.past);

  final List<GymRouteKey> routes;

  /// For each of [routes], the project's id when it is one of [past], else
  /// `null` for a route new in this session.
  final List<String?> routeIds;
  final List<GymTapEntry> entries;

  /// Your open projects at this gym from earlier sessions.
  final List<GymPastRoute> past;

  /// Logs a top on [key]. Topping a colour you fell on earlier in this
  /// session, on the same wall and of the same kind, counts as the same
  /// climb; anything else is a new route. Rope climbs need a [ropeType].
  GymSessionLog tap(GymRouteKey key, {String? ropeType}) {
    _checkRopeType(key, ropeType);
    final open = [
      for (final (i, r) in routes.indexed)
        if (r == key && routeIds[i] == null && !_sent(i)) i,
    ].lastOrNull;
    return _add(open, key, null, ropeType);
  }

  /// Logs a send of project [id]: its tries so far count.
  GymSessionLog sendProject(String id, {String? ropeType}) {
    final project = past.where((p) => p.id == id).firstOrNull;
    if (project == null) throw ArgumentError.value(id, 'id', 'not a project');
    final route = routeIds.indexOf(id);
    if (route >= 0 && _sent(route)) {
      throw ArgumentError.value(id, 'id', 'already sent');
    }
    _checkRopeType(project.key, ropeType);
    return _add(route >= 0 ? route : null, project.key, id, ropeType);
  }

  /// The projects to offer for [kind]: those not sent in this session,
  /// with `tries` counting this session's falls on them.
  List<({GymPastRoute route, int tries})> projects(String kind) => [
    for (final p in past)
      if (p.key.kind == kind && !_sentProject(p.id))
        (
          route: p,
          tries:
              p.tries +
              [
                for (final e in entries)
                  if (routeIds[e.route] == p.id) e.tries,
              ].fold(0, (a, b) => a + b),
        ),
  ];

  /// The log without project [id], once it is gone. One climbed in this
  /// session stays, so the session can still be saved.
  GymSessionLog withoutProject(String id) {
    if (routeIds.contains(id)) {
      throw ArgumentError.value(id, 'id', 'climbed in this session');
    }
    return GymSessionLog._(routes, routeIds, entries, [
      for (final p in past)
        if (p.id != id) p,
    ]);
  }

  /// Whether entry [index] is on a route new in this session with no other
  /// entry, so it is not the same climb as anything yet.
  bool isFresh(int index) {
    final route = entries[index].route;
    return routeIds[route] == null &&
        entries.where((e) => e.route == route).length == 1;
  }

  /// Climbs entry [index] might be instead, likeliest first: one of the
  /// same colour on the same wall you tried in this session, a project of
  /// it, then for a send one you sent in this session.
  List<GymMatch> matches(int index) {
    final entry = entries[index];
    final key = routes[entry.route];
    return [
      for (final (i, r) in routes.indexed.toList().reversed)
        if (i != entry.route && r == key && routeIds[i] == null && !_sent(i))
          (kind: GymMatchKind.triedToday, route: i, pastId: null),
      for (final p in past)
        if (p.key == key &&
            routeIds.indexOf(p.id) != entry.route &&
            !_sentProject(p.id))
          (kind: GymMatchKind.project, route: null, pastId: p.id),
      if (entry.topped)
        for (final (i, r) in routes.indexed.toList().reversed)
          if (i != entry.route && r == key && _sent(i))
            (kind: GymMatchKind.sentToday, route: i, pastId: null),
    ];
  }

  /// Moves entry [index] to [match], one of its [matches], as a first try
  /// there.
  GymSessionLog moveTo(int index, GymMatch match) {
    if (!matches(index).contains(match)) {
      throw ArgumentError.value(match, 'match');
    }
    final e = entries[index];
    var routes = this.routes;
    var ids = routeIds;
    var route = match.route;
    if (match.pastId case final id?) {
      route = ids.indexOf(id);
      if (route < 0) {
        route = routes.length;
        routes = [...routes, past.firstWhere((p) => p.id == id).key];
        ids = [...ids, id];
      }
    }
    return _with(routes, ids, _replace(index, _onRoute(e, route!, tries: 1)));
  }

  /// Moves entry [index] to a new route of the same colour: it was a
  /// different climb.
  GymSessionLog moveToNew(int index) {
    final e = entries[index];
    return _with(
      [...routes, routes[e.route]],
      [...routeIds, null],
      _replace(index, _onRoute(e, routes.length, tries: 1)),
    );
  }

  /// Changes entry [index]: topped or not, tries (1 to [maxTriesPerTap]),
  /// and the rope type for a rope climb.
  GymSessionLog update(
    int index, {
    bool? topped,
    int? tries,
    String? ropeType,
  }) {
    final e = entries[index];
    if (tries != null && (tries < 1 || tries > maxTriesPerTap)) {
      throw ArgumentError.value(tries, 'tries');
    }
    if (ropeType != null && e.ropeType == null) {
      throw ArgumentError.value(ropeType, 'ropeType', 'not a rope climb');
    }
    return GymSessionLog._(
      routes,
      routeIds,
      _replace(index, (
        route: e.route,
        topped: topped ?? e.topped,
        tries: tries ?? e.tries,
        ropeType: ropeType ?? e.ropeType,
      )),
      past,
    );
  }

  /// Removes entry [index]. A route no entry is on any more is dropped, so
  /// it is not saved, and the routes after it move up.
  GymSessionLog remove(int index) =>
      _with(routes, routeIds, [...entries]..removeAt(index));

  /// Each entry as it will be logged, worked out in order (sva_core
  /// [gymTap]). A project's earlier tries count.
  List<LoggedAscent> get climbs {
    final logs = [
      for (final id in routeIds)
        <LoggedAscent>[
          if (past.where((p) => p.id == id).firstOrNull case final p?)
            (style: AscentStyle.attempt, tries: p.tries),
        ],
    ];
    return [
      for (final e in entries)
        () {
          final ascent = gymTap(
            RouteHistory.from(
              logs[e.route],
              boulder: routes[e.route].kind == 'boulder',
              gym: true,
            ),
            topped: e.topped,
            tries: e.tries,
          );
          logs[e.route].add(ascent);
          return ascent;
        }(),
    ];
  }

  bool _sent(int route) => entries.any((e) => e.route == route && e.topped);

  bool _sentProject(String id) {
    final route = routeIds.indexOf(id);
    return route >= 0 && _sent(route);
  }

  static void _checkRopeType(GymRouteKey key, String? ropeType) {
    if ((key.kind == 'rope') != (ropeType != null)) {
      throw ArgumentError.value(ropeType, 'ropeType');
    }
  }

  /// A topped first try on [route], or on a new route [key] (with project
  /// [id]) when [route] is `null`.
  GymSessionLog _add(
    int? route,
    GymRouteKey key,
    String? id,
    String? ropeType,
  ) => GymSessionLog._(
    route == null ? [...routes, key] : routes,
    route == null ? [...routeIds, id] : routeIds,
    [
      ...entries,
      (
        route: route ?? routes.length,
        topped: true,
        tries: 1,
        ropeType: ropeType,
      ),
    ],
    past,
  );

  List<GymTapEntry> _replace(int index, GymTapEntry entry) => [
    for (final (i, e) in entries.indexed)
      if (i == index) entry else e,
  ];

  /// [entries] on [routes], dropping the routes no entry is on, so they are
  /// not saved, and moving the rest up.
  GymSessionLog _with(
    List<GymRouteKey> routes,
    List<String?> ids,
    List<GymTapEntry> entries,
  ) {
    final used = {for (final e in entries) e.route};
    final kept = [
      for (var i = 0; i < routes.length; i++)
        if (used.contains(i)) i,
    ];
    return GymSessionLog._(
      [for (final i in kept) routes[i]],
      [for (final i in kept) ids[i]],
      [for (final e in entries) _onRoute(e, kept.indexOf(e.route))],
      past,
    );
  }

  static GymTapEntry _onRoute(GymTapEntry e, int route, {int? tries}) => (
    route: route,
    topped: e.topped,
    tries: tries ?? e.tries,
    ropeType: e.ropeType,
  );
}
