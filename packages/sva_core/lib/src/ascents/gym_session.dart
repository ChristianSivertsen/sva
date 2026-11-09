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

/// The taps of one gym session, in order, and the routes they are on
/// (prototype/gym-log.html). Immutable: every change returns a new log.
final class GymSessionLog {
  const new({this.routes = const [], this.entries = const []});

  final List<GymRouteKey> routes;
  final List<GymTapEntry> entries;

  /// Logs a top on [key]. Topping a colour you fell on earlier in this
  /// session, on the same wall and of the same kind, counts as the same
  /// climb; anything else is a new route. Rope climbs need a [ropeType].
  GymSessionLog tap(GymRouteKey key, {String? ropeType}) {
    if ((key.kind == 'rope') != (ropeType != null)) {
      throw ArgumentError.value(ropeType, 'ropeType');
    }
    final open = [
      for (final (i, r) in routes.indexed)
        if (r == key && !entries.any((e) => e.route == i && e.topped)) i,
    ].lastOrNull;
    final route = open ?? routes.length;
    return GymSessionLog(
      routes: open == null ? [...routes, key] : routes,
      entries: [
        ...entries,
        (route: route, topped: true, tries: 1, ropeType: ropeType),
      ],
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
    return GymSessionLog(
      routes: routes,
      entries: [
        for (final (i, x) in entries.indexed)
          if (i == index)
            (
              route: x.route,
              topped: topped ?? x.topped,
              tries: tries ?? x.tries,
              ropeType: ropeType ?? x.ropeType,
            )
          else
            x,
      ],
    );
  }

  /// Removes entry [index]. A route no entry is on any more is dropped, so
  /// it is not saved, and the routes after it move up.
  GymSessionLog remove(int index) {
    final route = entries[index].route;
    final left = [...entries]..removeAt(index);
    if (left.any((e) => e.route == route)) {
      return GymSessionLog(routes: routes, entries: left);
    }
    return GymSessionLog(
      routes: [...routes]..removeAt(route),
      entries: [
        for (final e in left)
          if (e.route > route)
            (
              route: e.route - 1,
              topped: e.topped,
              tries: e.tries,
              ropeType: e.ropeType,
            )
          else
            e,
      ],
    );
  }

  /// Each entry as it will be logged, worked out in order (sva_core
  /// [gymTap]). Every route is new in this session, so nothing logged
  /// before counts yet; projects from earlier sessions come with M3-7.
  List<LoggedAscent> get climbs {
    final logs = [for (final _ in routes) <LoggedAscent>[]];
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
}
