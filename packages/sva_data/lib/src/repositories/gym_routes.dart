import 'package:drift/drift.dart';
import 'package:sva_core/sva_core.dart';
import 'package:sva_data/src/attributes/attribute_repository.dart';
import 'package:sva_data/src/database/sva_database.dart';
import 'package:sva_data/src/ids.dart';
import 'package:sva_data/src/repositories/gym_editor.dart';
import 'package:sva_data/src/repositories/place_repositories.dart';
import 'package:sva_data/src/repositories/route_editor.dart';
import 'package:sva_data/src/repositories/session_repositories.dart';

/// Longest note on a gym route, such as "the blue in the cave corner".
const maxSetterNoteLength = 200;

/// A gym route as logging creates it: on a wall, with a colour or a grade.
/// The angle starts as the wall's and can be changed for this route.
final class NewGymRoute {
  const new({
    required this.wallId,
    required this.setOn,
    this.colourId,
    this.gradeId,
    this.angle,
    this.note,
  });

  final String wallId;

  /// `YYYY-MM-DD`, the day the route was first logged or set.
  final String setOn;

  /// One of the user's colours at the gym, for colour-graded gyms.
  final String? colourId;

  /// A grade of the wall's kind, for gyms with standard grades.
  final String? gradeId;

  /// An `angle.*` value key, when it differs from the wall's.
  final String? angle;
  final String? note;
}

/// A gym route the user has tried and not sent: how many tries so far, the
/// day of the latest one, and its grade at a gym with standard grades.
typedef GymProject = ({
  Route route,
  int tries,
  String lastTried,
  String? gradeId,
});

/// How a gym route is shown, since it has no name: its colour (or its
/// grade, with the grade's system) and its wall. All `null` parts are
/// unknown, such as the wall of a route whose wall was removed.
typedef GymRouteLabel = ({
  String? colour,
  String? grade,
  String? gradeSystem,
  String? wall,
});

/// Temporary gym routes: each user's own, on their walls. There is no
/// timer (PLAN.md decision 4): a route stays until its wall is reset or
/// it is marked as gone, which retire it. Everything is checked here, at
/// the boundary.
class GymRouteRepository {
  new(SvaDatabase db, {DateTime Function()? clock})
    : this._(db, clock ?? (() => DateTime.now().toUtc()));

  new _(this.db, this.clock)
    : _routes = RouteRepository(db, clock: clock),
      _walls = GymWallRepository(db, clock: clock),
      _ascents = AscentRepository(db, clock: clock),
      _gyms = GymEditor(db, clock: clock),
      _attributes = AttributeRepository(db, clock: clock);

  final SvaDatabase db;
  final DateTime Function() clock;
  final RouteRepository _routes;
  final GymWallRepository _walls;
  final AscentRepository _ascents;
  final GymEditor _gyms;
  final AttributeRepository _attributes;

  /// Adds a gym route for [userId] on one of their walls. Returns its id.
  Future<String> add(NewGymRoute route, {required String userId}) async {
    _checkDay(route.setOn, 'setOn');
    final note = route.note?.trim();
    if (note != null && note.length > maxSetterNoteLength) {
      // The length, not the note: errors may end up in logs one day.
      throw ArgumentError.value(note.length, 'note', 'too long');
    }
    if (route.angle case final angle?) {
      final defs = await _attributes.definitions(level: AttributeLevel.route);
      final def = defs.where((d) => d.key == 'angle').firstOrNull;
      if (def == null || !def.accepts([angle])) {
        throw ArgumentError.value(angle, 'angle');
      }
    }
    return await db.transaction(() async {
      final draft = await _gyms.newGymRoute(route.wallId, userId: userId);
      final gymId = draft.areaId.value;
      final boulder = draft.discipline.value == 'boulder';
      // A colour gym's routes have a colour, a standard gym's a grade, and
      // an ungraded gym's neither.
      final grading =
          (await (db.select(db.gymProfiles)..where(
                    (p) => p.areaId.equals(gymId) & p.deletedAt.isNull(),
                  ))
                  .getSingleOrNull())
              ?.grading ??
          'none';
      if (route.colourId != null && grading != 'colour') {
        throw ArgumentError.value(
          route.colourId,
          'colourId',
          'not a colour gym',
        );
      }
      if (route.gradeId != null && grading != 'standard') {
        throw ArgumentError.value(route.gradeId, 'gradeId', 'not a graded gym');
      }
      if (route.colourId case final id?) {
        final colour =
            await (db.select(db.gymColourGrades)..where(
                  (c) =>
                      c.id.equals(id) &
                      c.gymId.equals(gymId) &
                      c.ownerId.equals(userId) &
                      c.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (colour == null) throw ArgumentError.value(id, 'colourId');
      }
      final gradeType = boulder ? 'boulder' : 'free_route';
      if (route.gradeId case final id?) {
        await RouteEditor.checkGrade(db, id, gradeType);
      }
      final routeId = await _routes.createPrivate(
        draft.copyWith(
          gymColourGradeId: Value(route.colourId),
          setOn: Value(route.setOn),
          setterNote: Value(note == null || note.isEmpty ? null : note),
          angle: route.angle == null ? draft.angle : Value(route.angle),
        ),
        userId: userId,
      );
      if (route.gradeId case final gradeId?) {
        final now = clock();
        await db
            .into(db.routeGrades)
            .insert(
              RouteGradesCompanion.insert(
                id: newId(),
                createdAt: now,
                updatedAt: now,
                createdBy: Value(userId),
                routeId: routeId,
                gradeType: gradeType,
                gradeId: gradeId,
                source: 'official',
              ),
            );
      }
      return routeId;
    });
  }

  /// How [userId]'s gym route [routeId] is shown, or `null` when it is
  /// not one of their gym routes.
  Future<GymRouteLabel?> label(String routeId, {required String userId}) async {
    final route =
        await (db.select(db.routes)..where(
              (r) =>
                  r.id.equals(routeId) &
                  r.kind.equals('gym') &
                  r.createdBy.equals(userId),
            ))
            .getSingleOrNull();
    if (route == null) return null;
    // Removed walls and colours still name the climbs logged on them.
    final colour = route.gymColourGradeId == null
        ? null
        : await (db.select(db.gymColourGrades)
                ..where((c) => c.id.equals(route.gymColourGradeId!)))
              .getSingleOrNull();
    final wall = route.gymWallId == null
        ? null
        : await (db.select(
            db.gymWalls,
          )..where((w) => w.id.equals(route.gymWallId!))).getSingleOrNull();
    final grade =
        await (db.select(db.routeGrades).join([
              innerJoin(
                db.grades,
                db.grades.id.equalsExp(db.routeGrades.gradeId),
              ),
            ])..where(
              db.routeGrades.routeId.equals(routeId) &
                  db.routeGrades.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return (
      colour: colour?.name,
      grade: grade?.readTable(db.grades).label,
      gradeSystem: grade?.readTable(db.grades).systemKey,
      wall: wall?.name,
    );
  }

  /// [userId]'s routes still up on wall [wallId], newest set first.
  Future<List<Route>> stillUp(String wallId, {required String userId}) =>
      (db.select(db.routes)
            ..where(
              (r) =>
                  r.gymWallId.equals(wallId) &
                  r.createdBy.equals(userId) &
                  r.kind.equals('gym') &
                  r.status.equals('open') &
                  r.deletedAt.isNull(),
            )
            ..orderBy([(r) => OrderingTerm.desc(r.setOn)]))
          .get();

  /// [userId]'s open projects at gym [gymId] (sva_core `isOpenProject`),
  /// last tried first.
  Future<List<GymProject>> projects(
    String gymId, {
    required String userId,
  }) async {
    final routes =
        await (db.select(db.routes)..where(
              (r) =>
                  r.areaId.equals(gymId) &
                  r.createdBy.equals(userId) &
                  r.kind.equals('gym') &
                  r.deletedAt.isNull(),
            ))
            .get();
    final projects = <GymProject>[];
    for (final route in routes) {
      final entries = await _ascents.routeEntries(route.id, userId: userId);
      final history = RouteHistory.from(
        [for (final e in entries) e.ascent],
        boulder: route.discipline == 'boulder',
        gym: true,
      );
      if (!isOpenProject(history, retired: route.status == 'retired')) {
        continue;
      }
      final last = await (db.select(
        db.sessions,
      )..where((s) => s.id.equals(entries.last.sessionId))).getSingle();
      final grade =
          await (db.select(db.routeGrades)..where(
                (g) => g.routeId.equals(route.id) & g.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      projects.add((
        route: route,
        tries: history.earlierTries,
        lastTried: last.localDate,
        gradeId: grade?.gradeId,
      ));
    }
    return projects..sort((a, b) => b.lastTried.compareTo(a.lastTried));
  }

  /// Marks [userId]'s gym route [routeId] as gone: it is no longer up, so
  /// it stops being suggested. Its climbs stay in the log.
  Future<void> markGone(String routeId, {required String userId}) async {
    final route = await _routes.get(routeId);
    if (route == null || route.kind != 'gym' || route.createdBy != userId) {
      throw ArgumentError.value(routeId, 'routeId', 'no such gym route');
    }
    await _routes.update(
      routeId,
      const RoutesCompanion(status: Value('retired')),
      userId: userId,
    );
  }

  /// Marks [userId]'s wall [wallId] as reset on day [on]: every route still
  /// up on it is retired.
  Future<void> resetWall(
    String wallId, {
    required String on,
    required String userId,
  }) async {
    _checkDay(on, 'on');
    // A day ahead of the device's own date allows for time zones.
    final latest = clock().add(const Duration(days: 1));
    if (DateTime.parse(on).isAfter(latest)) {
      throw ArgumentError.value(on, 'on', 'in the future');
    }
    await db.transaction(() async {
      final wall = await _walls.get(wallId);
      if (wall == null || wall.ownerId != userId) {
        throw ArgumentError.value(wallId, 'wallId', 'no such wall');
      }
      // An older reset logged late never moves the date back.
      if (wall.lastResetOn == null || wall.lastResetOn!.compareTo(on) < 0) {
        await _walls.update(
          wallId,
          GymWallsCompanion(lastResetOn: Value(on)),
          userId: userId,
        );
      }
      for (final route in await stillUp(wallId, userId: userId)) {
        await _routes.update(
          route.id,
          const RoutesCompanion(status: Value('retired')),
          userId: userId,
        );
      }
    });
  }

  static void _checkDay(String day, String field) {
    final parsed = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)
        ? DateTime.tryParse(day)
        : null;
    // DateTime.parse accepts 2026-02-30 as 2 March; a real day prints back
    // the same.
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != day) {
      throw ArgumentError.value(day, field);
    }
  }
}
