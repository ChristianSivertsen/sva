import 'package:drift/drift.dart';
import 'package:sva_core/sva_core.dart';
import 'package:sva_data/src/attributes/attribute_repository.dart';
import 'package:sva_data/src/database/sva_database.dart';
import 'package:sva_data/src/ids.dart';
import 'package:sva_data/src/repositories/gym_routes.dart';
import 'package:sva_data/src/repositories/repository.dart';
import 'package:sva_data/src/repositories/session_repositories.dart';

/// One climb as the log sheet fills it in. Details are value keys from
/// the attribute definitions (`feel.hard`, `tag.pumpy`).
final class ClimbDraft {
  const new({
    required this.routeId,
    required this.style,
    required this.tries,
    required this.ascentType,
    this.feel,
    this.personalGradeId,
    this.tags = const [],
    this.qualityStars,
  });

  final String routeId;
  final AscentStyle style;
  final int tries;

  /// `lead`, `follow`, `toprope`, `boulder` and the other ascent types.
  final String ascentType;
  final String? feel;
  final String? personalGradeId;
  final List<String> tags;

  /// 0 to 3.
  final int? qualityStars;
}

/// A session as the log sheet fills it in.
final class SessionDraft {
  const new({
    required this.localDate,
    required this.tz,
    required this.visibility,
    required this.climbs,
    this.title,
    this.description,
    this.conditions,
    this.partners = const [],
  });

  /// `YYYY-MM-DD` in the session's own time zone.
  final String localDate;

  /// IANA time zone, such as `Europe/Oslo`.
  final String tz;
  final String visibility;

  /// In the order they were climbed.
  final List<ClimbDraft> climbs;
  final String? title;
  final String? description;

  /// A `condition.*` value key.
  final String? conditions;

  /// Partners' names, stored on this device only until tagging (M13).
  final List<String> partners;
}

/// Changes to a logged session (M2-6). The date and setting stay as they
/// were; the texts, conditions and partners are replaced by these.
final class SessionEdit {
  const new({
    this.title,
    this.description,
    this.conditions,
    this.partners = const [],
    this.removed = const {},
    this.added = const [],
  });

  final String? title;
  final String? description;

  /// A `condition.*` value key.
  final String? conditions;

  /// Partners' names, stored on this device only until tagging (M13).
  final List<String> partners;

  /// Ids of the session's climbs to remove.
  final Set<String> removed;

  /// Forgotten climbs, added after the session's other climbs.
  final List<ClimbDraft> added;
}

/// One gym route in an indoor session: one logged before ([routeId]), or
/// a new one on a wall, with a colour or a grade as the gym grades.
final class IndoorRouteDraft {
  const new({this.routeId, this.wallId, this.colourId, this.gradeId});

  final String? routeId;
  final String? wallId;
  final String? colourId;
  final String? gradeId;
}

/// One climb in an indoor session, on [route] (an index into
/// [IndoorSessionDraft.routes]), as the gym log worked it out (sva_core
/// `gymTap`).
final class IndoorClimbDraft {
  const new({
    required this.route,
    required this.style,
    required this.tries,
    required this.ascentType,
  });

  final int route;
  final AscentStyle style;
  final int tries;

  /// One of `indoorAscentTypes`: `boulder` on a boulder wall, `lead` or
  /// `toprope` on a rope wall.
  final String ascentType;
}

/// An indoor session as the gym log fills it in.
final class IndoorSessionDraft {
  const new({
    required this.gymId,
    required this.localDate,
    required this.tz,
    required this.visibility,
    required this.routes,
    required this.climbs,
    this.title,
  });

  final String gymId;

  /// `YYYY-MM-DD` in the session's own time zone.
  final String localDate;

  /// IANA time zone, such as `Europe/Oslo`.
  final String tz;
  final String visibility;
  final List<IndoorRouteDraft> routes;

  /// In the order they were climbed.
  final List<IndoorClimbDraft> climbs;
  final String? title;
}

/// Thrown when a climb breaks the style and tries rules (M1-4).
class ClimbRejected implements Exception {
  new(this.index, this.issues);

  /// Which climb in [SessionDraft.climbs], from 0.
  final int index;
  final List<AscentIssue> issues;

  @override
  String toString() => 'ClimbRejected: climb $index $issues';
}

/// Thrown when an edit would break the style and tries rules for a climb
/// logged later on the same route: removing the send that a later repeat
/// follows, say, or adding an attempt before a later flash.
class LaterClimbRejected implements Exception {
  new(this.routeId, this.issues);

  final String routeId;
  final List<AscentIssue> issues;

  @override
  String toString() => 'LaterClimbRejected: route $routeId $issues';
}

/// Ascent types the log sheet offers outdoors.
const outdoorAscentTypes = {'lead', 'follow', 'toprope', 'solo', 'boulder'};

/// Most partners on one session, and longest texts, in characters.
const maxPartners = 20;
const maxTitleLength = 120;
const maxDescriptionLength = 2000;
const maxPartnerNameLength = 80;

/// Saves an outdoor session with all its climbs in one transaction, so a
/// half-logged session never reaches sync. Everything is checked here, at
/// the boundary: bad values throw [ArgumentError] naming the field, a climb
/// that breaks the style and tries rules throws [ClimbRejected], and in
/// both cases nothing is written.
class SessionLogger {
  new(SvaDatabase db, {DateTime Function()? clock})
    : this._(db, clock ?? (() => DateTime.now().toUtc()));

  new _(this.db, this.clock)
    : _sessions = SessionRepository(db, clock: clock),
      _ascents = AscentRepository(db, clock: clock),
      _attributes = AttributeRepository(db, clock: clock);

  final SvaDatabase db;
  final DateTime Function() clock;
  final SessionRepository _sessions;
  final AscentRepository _ascents;
  final AttributeRepository _attributes;

  /// Logs [draft] for [userId]. Returns the session's id.
  ///
  /// The climbs are checked against everything already logged on each
  /// route, as if this session came last. Climbs forgotten in a past
  /// session are added with [editOutdoor].
  Future<String> logOutdoor(
    SessionDraft draft, {
    required String userId,
  }) async {
    if (draft.climbs.isEmpty) {
      throw ArgumentError.value(draft.climbs, 'climbs', 'none');
    }
    _checkDayAndZone(draft.localDate, draft.tz);
    checkVisibility(draft.visibility);
    final (:title, :description, :partners) = await _checkSessionFields(
      title: draft.title,
      description: draft.description,
      conditions: draft.conditions,
      partners: draft.partners,
    );
    await _checkClimbs(draft.climbs);

    return await db.transaction(() async {
      await _checkRules(draft.climbs, userId);
      final sessionId = await _sessions.create(
        SessionsCompanion(
          setting: const Value('outdoor'),
          localDate: Value(draft.localDate),
          tz: Value(draft.tz),
          visibility: Value(draft.visibility),
          title: Value(title),
          description: Value(description),
          conditions: Value(draft.conditions),
        ),
        userId: userId,
      );
      for (final (i, climb) in draft.climbs.indexed) {
        await _addClimb(sessionId, i + 1, climb, userId);
      }
      await _addPartners(sessionId, draft.visibility, partners, userId);
      return sessionId;
    });
  }

  /// Logs an indoor session [draft] at a gym for [userId], with any new
  /// gym routes it climbed, in one transaction. Returns the session's id.
  ///
  /// Each climb is checked with the same style and tries rules as outdoors
  /// (gym routes flash rather than onsight), against everything already
  /// logged on its route, as if this session came last. A climb that breaks
  /// them throws [ClimbRejected]; bad values throw [ArgumentError]. Either
  /// way nothing is written.
  Future<String> logIndoor(
    IndoorSessionDraft draft, {
    required String userId,
  }) async {
    if (draft.climbs.isEmpty) {
      throw ArgumentError.value(draft.climbs, 'climbs', 'none');
    }
    _checkDayAndZone(draft.localDate, draft.tz);
    checkVisibility(draft.visibility);
    final (:title, description: _, partners: _) = await _checkSessionFields(
      title: draft.title,
      description: null,
      conditions: null,
      partners: const [],
    );
    for (final (i, route) in draft.routes.indexed) {
      if ((route.routeId == null) == (route.wallId == null)) {
        throw ArgumentError.value(i, 'routes', 'a route or a wall, not both');
      }
    }
    for (final climb in draft.climbs) {
      if (climb.route < 0 || climb.route >= draft.routes.length) {
        throw ArgumentError.value(climb.route, 'route');
      }
      if (!indoorAscentTypes.contains(climb.ascentType)) {
        throw ArgumentError.value(climb.ascentType, 'ascentType');
      }
    }

    return await db.transaction(() async {
      final gym =
          await (db.select(db.areas)..where(
                (a) =>
                    a.id.equals(draft.gymId) &
                    a.type.equals('gym') &
                    a.deletedAt.isNull() &
                    (a.visibility.equals('public') |
                        a.createdBy.equals(userId)),
              ))
              .getSingleOrNull();
      if (gym == null) throw ArgumentError.value(draft.gymId, 'gymId');

      // The session's routes, the new ones added now, with what was logged
      // on each before.
      final gymRoutes = GymRouteRepository(db, clock: clock);
      final routes = <Route>[];
      final logs = <List<LoggedAscent>>[];
      for (final route in draft.routes) {
        final id =
            route.routeId ??
            await gymRoutes.add(
              NewGymRoute(
                wallId: route.wallId!,
                setOn: draft.localDate,
                colourId: route.colourId,
                gradeId: route.gradeId,
              ),
              userId: userId,
            );
        final row =
            await (db.select(db.routes)..where(
                  (r) =>
                      r.id.equals(id) &
                      r.kind.equals('gym') &
                      r.areaId.equals(draft.gymId) &
                      r.createdBy.equals(userId) &
                      r.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (row == null) throw ArgumentError.value(id, 'routeId');
        routes.add(row);
        logs.add(
          route.routeId == null
              ? []
              : await _ascents.routeLog(id, userId: userId),
        );
      }

      for (final (i, climb) in draft.climbs.indexed) {
        final route = routes[climb.route];
        final boulder = route.discipline == 'boulder';
        if (boulder != (climb.ascentType == 'boulder')) {
          throw ArgumentError.value(climb.ascentType, 'ascentType');
        }
        final ascent = (style: climb.style, tries: climb.tries);
        final issues = RouteHistory.from(
          logs[climb.route],
          boulder: boulder,
          gym: true,
        ).check(ascent);
        if (issues.isNotEmpty) throw ClimbRejected(i, issues);
        logs[climb.route].add(ascent);
      }

      final sessionId = await _sessions.create(
        SessionsCompanion(
          setting: const Value('indoor'),
          areaId: Value(draft.gymId),
          localDate: Value(draft.localDate),
          tz: Value(draft.tz),
          visibility: Value(draft.visibility),
          title: Value(title),
        ),
        userId: userId,
      );
      for (final (i, climb) in draft.climbs.indexed) {
        await _ascents.create(
          AscentsCompanion(
            sessionId: Value(sessionId),
            routeId: Value(routes[climb.route].id),
            ordinal: Value(i + 1),
            ascentType: Value(climb.ascentType),
            style: Value(climb.style.name),
            tries: Value(climb.tries),
          ),
          userId: userId,
        );
      }
      return sessionId;
    });
  }

  /// A real calendar day (no 30 February), not after tomorrow, which covers
  /// every time zone ahead of the device's clock, and an IANA time zone.
  void _checkDayAndZone(String localDate, String tz) {
    final day = DateTime.tryParse(localDate);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(localDate) ||
        day == null ||
        !day.toIso8601String().startsWith(localDate) ||
        day.isAfter(clock().add(const Duration(days: 1)))) {
      throw ArgumentError.value(localDate, 'localDate');
    }
    if (!RegExp(r'^[A-Za-z_+\-]+(/[A-Za-z0-9_+\-]+)*$').hasMatch(tz)) {
      throw ArgumentError.value(tz, 'tz');
    }
  }

  /// Applies [edit] to one of [userId]'s outdoor sessions in one
  /// transaction. Its date stays as logged.
  ///
  /// Every route the edit touches is checked again from its first ascent:
  /// a removed or added attempt moves the tries of the redpoint after it,
  /// an added climb that breaks the rules throws [ClimbRejected] (its index
  /// in [SessionEdit.added]), and a later climb the edit would break throws
  /// [LaterClimbRejected]. When no climbs are left, the session is deleted
  /// with everything in it; returns `true` then. The screen asks first.
  Future<bool> editOutdoor(
    String sessionId,
    SessionEdit edit, {
    required String userId,
  }) async {
    final (:title, :description, :partners) = await _checkSessionFields(
      title: edit.title,
      description: edit.description,
      conditions: edit.conditions,
      partners: edit.partners,
    );
    await _checkClimbs(edit.added);

    return await db.transaction(() async {
      final session =
          await (db.select(db.sessions)..where(
                (s) =>
                    s.id.equals(sessionId) &
                    s.deletedAt.isNull() &
                    s.ownerId.equals(userId) &
                    s.setting.equals('outdoor'),
              ))
              .getSingleOrNull();
      if (session == null) throw NotYourRow('sessions', sessionId);
      final current = await _ascents.watchInSession(sessionId).first;
      final removed = [
        for (final a in current)
          if (edit.removed.contains(a.id)) a,
      ];
      if (removed.length != edit.removed.length) {
        throw ArgumentError.value(edit.removed, 'removed');
      }
      final recounted = await _recheck(sessionId, removed, edit.added, userId);
      for (final MapEntry(key: id, value: tries) in recounted.entries) {
        await _ascents.update(
          id,
          AscentsCompanion(tries: Value(tries)),
          userId: userId,
        );
      }
      if (removed.isNotEmpty &&
          removed.length == current.length &&
          edit.added.isEmpty) {
        await _sessions.softDelete(sessionId, userId: userId);
        return true;
      }
      for (final a in removed) {
        await _ascents.softDelete(a.id, userId: userId);
      }
      final last = current.isEmpty ? 0 : current.last.ordinal;
      for (final (i, climb) in edit.added.indexed) {
        await _addClimb(sessionId, last + i + 1, climb, userId);
      }
      await _sessions.update(
        sessionId,
        SessionsCompanion(
          title: Value(title),
          description: Value(description),
          conditions: Value(edit.conditions),
        ),
        userId: userId,
      );
      await _replacePartners(session, partners, userId);
      return false;
    });
  }

  /// Checks every route an edit touches from its first ascent, with the
  /// [removed] climbs gone and the [added] ones at the end of the session.
  /// Returns the climbs whose tries change, by id.
  Future<Map<String, int>> _recheck(
    String sessionId,
    List<Ascent> removed,
    List<ClimbDraft> added,
    String userId,
  ) async {
    final gone = {for (final a in removed) a.id};
    final changes = <String, int>{};
    for (final routeId in {
      for (final a in removed) a.routeId,
      for (final c in added) c.routeId,
    }) {
      // A climb can be removed even when its route was since deleted or
      // hidden; only added climbs need a route the user can log.
      final boulder = added.any((c) => c.routeId == routeId)
          ? (await _route(routeId, userId)).discipline == 'boulder'
          : removed.firstWhere((a) => a.routeId == routeId).discipline ==
                'boulder';
      final entries = await _ascents.routeEntries(routeId, userId: userId);
      // Added climbs go after everything up to and including this session.
      final upTo = await _ascents.routeEntries(
        routeId,
        userId: userId,
        upToSession: sessionId,
      );
      final at = upTo.where((e) => !gone.contains(e.id)).length;
      final before = [for (final e in entries) (e.id, e.ascent)];
      final after =
          [
            for (final e in before)
              if (!gone.contains(e.$1)) e,
          ]..insertAll(at, [
            for (final (i, c) in added.indexed)
              if (c.routeId == routeId)
                ('$i', (style: c.style, tries: c.tries)),
          ]);
      final log = recountTries(before, after, boulder: boulder);
      final known = {for (final e in entries) e.id};
      final wasWrong = {
        for (final (i, issues) in checkRouteLog([
          for (final e in entries) e.ascent,
        ], boulder: boulder).indexed)
          if (issues.isNotEmpty) entries[i].id,
      };
      for (final (i, issues) in checkRouteLog(log, boulder: boulder).indexed) {
        final key = after[i].$1;
        if (!known.contains(key)) {
          if (issues.isNotEmpty) throw ClimbRejected(int.parse(key), issues);
        } else {
          // A climb that already broke the rules does not block the edit.
          if (issues.isNotEmpty && !wasWrong.contains(key)) {
            throw LaterClimbRejected(routeId, issues);
          }
          if (log[i].tries != after[i].$2.tries) changes[key] = log[i].tries;
        }
      }
    }
    return changes;
  }

  Future<void> _addClimb(
    String sessionId,
    int ordinal,
    ClimbDraft climb,
    String userId,
  ) async {
    if (climb.personalGradeId case final grade?) {
      await _checkGrade(grade, climb.routeId);
    }
    final official = await _officialGrade(climb.routeId);
    final ascentId = await _ascents.create(
      AscentsCompanion(
        sessionId: Value(sessionId),
        routeId: Value(climb.routeId),
        ordinal: Value(ordinal),
        ascentType: Value(climb.ascentType),
        style: Value(climb.style.name),
        tries: Value(climb.tries),
        feel: Value(climb.feel),
        personalGradeId: Value(climb.personalGradeId),
        // The route's grade may change later (consensus, moderators);
        // the climb keeps the grade it was logged at.
        officialGradeId: Value(official?.id),
        difficultyScore: Value(official?.score),
        qualityStars: Value(climb.qualityStars),
      ),
      userId: userId,
    );
    if (climb.tags.isNotEmpty) {
      await _attributes.setAscentAttribute(
        ascentId,
        'tag',
        climb.tags,
        userId: userId,
      );
    }
  }

  Future<void> _addPartners(
    String sessionId,
    String visibility,
    Iterable<String> names,
    String userId,
  ) async {
    final now = clock();
    for (final name in names) {
      await db
          .into(db.sessionMembers)
          .insert(
            SessionMembersCompanion.insert(
              id: newId(),
              createdAt: now,
              updatedAt: now,
              ownerId: userId,
              visibility: visibility,
              sessionId: sessionId,
              guestName: Value(name),
              status: 'guest',
              invitedBy: Value(userId),
            ),
          );
    }
  }

  /// Keeps the partners still named, removes the others and adds the new
  /// ones, so unchanged partners keep their rows.
  Future<void> _replacePartners(
    Session session,
    List<String> names,
    String userId,
  ) async {
    final members =
        await (db.select(db.sessionMembers)..where(
              (m) =>
                  m.sessionId.equals(session.id) &
                  m.deletedAt.isNull() &
                  m.status.equals('guest'),
            ))
            .get();
    final wanted = names.toSet();
    final now = clock();
    for (final m in members) {
      if (!wanted.remove(m.guestName)) {
        await (db.update(
          db.sessionMembers,
        )..where((r) => r.id.equals(m.id))).write(
          SessionMembersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
      }
    }
    await _addPartners(session.id, session.visibility, wanted, userId);
  }

  /// The session's texts, cleaned, after checking them and [conditions].
  Future<({String? title, String? description, List<String> partners})>
  _checkSessionFields({
    required String? title,
    required String? description,
    required String? conditions,
    required List<String> partners,
  }) async {
    // The same name twice is one partner.
    final names = {
      for (final name in partners)
        ?_text(name, maxPartnerNameLength, 'partners'),
    }.toList();
    if (names.length > maxPartners) {
      throw ArgumentError.value(names.length, 'partners');
    }
    final sessionDefs = await _attributes.definitions(
      level: AttributeLevel.session,
    );
    _checkValue(sessionDefs, 'conditions', conditions);
    return (
      title: _text(title, maxTitleLength, 'title'),
      description: _text(description, maxDescriptionLength, 'description'),
      partners: names,
    );
  }

  Future<void> _checkClimbs(List<ClimbDraft> climbs) async {
    final ascentDefs = await _attributes.definitions(
      level: AttributeLevel.ascent,
    );
    for (final climb in climbs) {
      if (!outdoorAscentTypes.contains(climb.ascentType)) {
        throw ArgumentError.value(climb.ascentType, 'ascentType');
      }
      if (climb.qualityStars case final stars? when stars < 0 || stars > 3) {
        throw ArgumentError.value(stars, 'qualityStars');
      }
      _checkValue(ascentDefs, 'feel', climb.feel);
      for (final tag in climb.tags) {
        _checkValue(ascentDefs, 'tag', tag);
      }
    }
  }

  /// A live outdoor route [userId] can log, or [ArgumentError].
  Future<Route> _route(String routeId, String userId) async {
    final route =
        await (db.select(db.routes)..where(
              (r) =>
                  r.id.equals(routeId) &
                  r.deletedAt.isNull() &
                  (r.visibility.equals('public') | r.createdBy.equals(userId)),
            ))
            .getSingleOrNull();
    if (route == null || route.kind != 'outdoor') {
      throw ArgumentError.value(routeId, 'routeId');
    }
    return route;
  }

  /// Checks each climb against the route's logged history and the climbs
  /// before it in this session.
  Future<void> _checkRules(List<ClimbDraft> climbs, String userId) async {
    final logs = <String, List<LoggedAscent>>{};
    for (final (i, climb) in climbs.indexed) {
      final route = await _route(climb.routeId, userId);
      final log = logs[climb.routeId] ??= await _ascents.routeLog(
        climb.routeId,
        userId: userId,
      );
      final issues = RouteHistory.from(
        log,
        boulder: route.discipline == 'boulder',
      ).check((style: climb.style, tries: climb.tries));
      if (issues.isNotEmpty) throw ClimbRejected(i, issues);
      log.add((style: climb.style, tries: climb.tries));
    }
  }

  /// The route's official climbing grade now, with its difficulty score.
  /// `null` for an ungraded route, or one graded only per pitch.
  Future<({String id, double? score})?> _officialGrade(String routeId) async {
    final row = await db
        .customSelect(
          'SELECT g.id, g.score FROM route_grades rg '
          'JOIN grades g ON g.id = rg.grade_id AND g.deleted_at IS NULL '
          'WHERE rg.route_id = ? AND rg.pitch_id IS NULL '
          // The climbing grade, not a danger or commitment grade.
          "AND rg.grade_type IN ('free_route', 'boulder') "
          "AND rg.source = 'official' AND rg.deleted_at IS NULL "
          'ORDER BY g.sort LIMIT 1',
          variables: [Variable.withString(routeId)],
          readsFrom: {db.routeGrades, db.grades},
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (
      id: row.read<String>('id'),
      score: row.readNullable<double>('score'),
    );
  }

  /// A personal grade must be a grade of the route's kind (route or
  /// boulder).
  Future<void> _checkGrade(String gradeId, String routeId) async {
    final row = await db
        .customSelect(
          'SELECT s.grade_type, r.discipline FROM grades g '
          'JOIN grade_systems s ON s.key = g.system_key '
          'AND s.deleted_at IS NULL '
          'JOIN routes r ON r.id = ?2 '
          'WHERE g.id = ?1 AND g.deleted_at IS NULL',
          variables: [
            Variable.withString(gradeId),
            Variable.withString(routeId),
          ],
          readsFrom: {db.grades, db.gradeSystems, db.routes},
        )
        .getSingleOrNull();
    final wanted = row?.read<String>('discipline') == 'boulder'
        ? 'boulder'
        : 'free_route';
    if (row?.read<String>('grade_type') != wanted) {
      throw ArgumentError.value(gradeId, 'personalGradeId');
    }
  }

  /// [raw] trimmed, `null` when empty, or [ArgumentError] when too long.
  static String? _text(String? raw, int max, String field) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.length > max) throw ArgumentError.value(raw, field, 'too long');
    return text;
  }

  static void _checkValue(List<AttributeDef> defs, String key, String? value) {
    if (value == null) return;
    final def = defs.where((d) => d.key == key).firstOrNull;
    if (def == null || !def.accepts([value])) {
      throw ArgumentError.value(value, key);
    }
  }
}
