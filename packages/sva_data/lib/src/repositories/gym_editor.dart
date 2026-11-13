import 'package:drift/drift.dart';
import 'package:sva_core/sva_core.dart';
import 'package:sva_data/src/attributes/attribute_repository.dart';
import 'package:sva_data/src/database/sva_database.dart';
import 'package:sva_data/src/ids.dart';
import 'package:sva_data/src/repositories/place_repositories.dart';
import 'package:sva_data/src/repositories/route_editor.dart';

/// How a gym grades its climbs (docs/schema.md, gym_profiles).
const gymGradings = {'colour', 'standard', 'none'};

/// What a gym wall is for.
const wallKinds = {'rope', 'boulder'};

/// Lowest and tallest gym wall, in metres.
const minWallHeightM = 1.0;
const maxWallHeightM = 60.0;

/// A gym as the gym form fills it in.
final class NewGym {
  const new({
    required this.name,
    required this.countryCode,
    required this.grading,
    this.location,
  });

  final String name;

  /// ISO 3166-1 alpha-2, such as `NO`.
  final String countryCode;

  /// One of [gymGradings].
  final String grading;
  final LatLon? location;
}

/// One wall in the gym form. With an [id] it changes that wall; without,
/// it adds one.
final class WallDraft {
  const new({
    required this.name,
    required this.kind,
    this.id,
    this.heightM,
    this.angle,
    this.angleDeg,
  });

  final String? id;
  final String name;

  /// One of [wallKinds].
  final String kind;
  final double? heightM;

  /// An `angle.*` value key. Ignored when [angleDeg] is set: the angle
  /// then follows from the degrees.
  final String? angle;

  /// Degrees past vertical, negative for slabs: whole numbers from
  /// [minWallAngleDeg] to [maxWallAngleDeg].
  final int? angleDeg;

  /// The angle type to store: from the degrees when they are set.
  String? get angleType => switch (angleDeg) {
    final deg? => angleForDegrees(deg),
    null => angle,
  };
}

/// One colour in a gym's colour scale, as the gym form fills it in. With
/// an [id] it changes that colour; without, it adds one. The ranges are
/// spans on the shared difficulty scale (sva_core `colourRange`), `null`
/// when the colour is not mapped.
final class ColourDraft {
  const new({
    required this.name,
    required this.colourHex,
    this.id,
    this.boulder,
    this.route,
  });

  final String? id;
  final String name;

  /// `#RRGGBB`.
  final String colourHex;
  final ScoreRange? boulder;
  final ScoreRange? route;
}

/// A gym with its grading and the user's walls and colours on it, each in
/// order (colours easiest first).
typedef GymSetup = ({
  Area gym,
  String grading,
  List<GymWall> walls,
  List<GymColourGrade> colours,
});

/// Sets up gyms and their walls from the gym form. The gym is a shared
/// place, created private like a crag; walls are each user's own for now
/// (docs/schema.md, gym_walls). Everything is checked here, at the
/// boundary: a bad value throws [ArgumentError] and nothing is written.
class GymEditor {
  new(SvaDatabase db, {DateTime Function()? clock})
    : this._(db, clock ?? (() => DateTime.now().toUtc()));

  new _(this.db, this.clock)
    : _areas = AreaRepository(db, clock: clock),
      _walls = GymWallRepository(db, clock: clock),
      _colours = GymColourGradeRepository(db, clock: clock),
      _attributes = AttributeRepository(db, clock: clock);

  final SvaDatabase db;
  final DateTime Function() clock;
  final AreaRepository _areas;
  final GymWallRepository _walls;
  final GymColourGradeRepository _colours;
  final AttributeRepository _attributes;

  /// Adds a gym with [walls] and [colours] for [userId]. Returns the
  /// gym's id.
  Future<String> addGym(
    NewGym gym, {
    required List<WallDraft> walls,
    required String userId,
    List<ColourDraft> colours = const [],
  }) async {
    final name = _checkGym(gym);
    await _checkWalls(walls);
    _checkColours(colours);
    return await db.transaction(() async {
      final id = await _areas.createPrivate(
        AreasCompanion(
          type: const Value('gym'),
          name: Value(name),
          countryCode: Value(gym.countryCode),
          latitude: Value(gym.location?.lat),
          longitude: Value(gym.location?.lon),
        ),
        userId: userId,
      );
      final now = clock();
      await db
          .into(db.gymProfiles)
          .insert(
            GymProfilesCompanion.insert(
              id: newId(),
              createdAt: now,
              updatedAt: now,
              createdBy: Value(userId),
              areaId: id,
              grading: gym.grading,
            ),
          );
      await _saveWalls(id, walls, userId);
      await _saveColours(id, colours, userId);
      return id;
    });
  }

  /// Changes [userId]'s private gym [gymId] and makes its walls and
  /// colours exactly [walls] and [colours], as [saveOwn] does. Throws
  /// [ArgumentError] for a gym that is not the user's to change; walls and
  /// colours on a shared gym go through [saveOwn] alone.
  Future<void> updateGym(
    String gymId,
    NewGym gym, {
    required List<WallDraft> walls,
    required List<ColourDraft> colours,
    required String userId,
  }) async {
    final name = _checkGym(gym);
    await _checkWalls(walls);
    _checkColours(colours);
    await db.transaction(() async {
      final area = await _visibleGym(gymId, userId);
      if (area.createdBy != userId || area.visibility != 'private') {
        throw ArgumentError.value(gymId, 'gymId', 'not your gym to change');
      }
      await _areas.update(
        gymId,
        AreasCompanion(
          name: Value(name),
          countryCode: Value(gym.countryCode),
          latitude: Value(gym.location?.lat),
          longitude: Value(gym.location?.lon),
        ),
        userId: userId,
      );
      await (db.update(
        db.gymProfiles,
      )..where((p) => p.areaId.equals(gymId))).write(
        GymProfilesCompanion(
          grading: Value(gym.grading),
          updatedAt: Value(clock()),
        ),
      );
      await _saveWalls(gymId, walls, userId);
      await _saveColours(gymId, colours, userId);
    });
  }

  /// Makes [userId]'s walls and colours on gym [gymId] exactly [walls]
  /// and [colours]: drafts with an id change that row, new ones are added
  /// and rows left out are deleted (soft, like every delete), so both
  /// lists are always given in full. Works on any gym the user can see,
  /// since walls and colours are each user's own.
  Future<void> saveOwn(
    String gymId, {
    required List<WallDraft> walls,
    required List<ColourDraft> colours,
    required String userId,
  }) async {
    await _checkWalls(walls);
    _checkColours(colours);
    await db.transaction(() async {
      await _visibleGym(gymId, userId);
      await _saveWalls(gymId, walls, userId);
      await _saveColours(gymId, colours, userId);
    });
  }

  /// Gym [gymId] with its grading and [userId]'s walls and colours, or
  /// `null` when it
  /// is gone or private to someone else.
  Future<GymSetup?> setup(String gymId, {required String userId}) async {
    final gym = await _gymFor(gymId, userId);
    if (gym == null) return null;
    final profile =
        await (db.select(db.gymProfiles)
              ..where((p) => p.areaId.equals(gymId) & p.deletedAt.isNull()))
            .getSingleOrNull();
    return (
      gym: gym,
      grading: profile?.grading ?? 'none',
      walls: await _wallsOf(gymId, userId),
      colours: await _coloursOf(gymId, userId),
    );
  }

  /// A new gym route on [userId]'s wall [wallId], starting with the
  /// wall's height and angle; the angle can be changed for one climb
  /// before it is saved. Rope walls give `sport`, boulder walls `boulder`.
  Future<RoutesCompanion> newGymRoute(
    String wallId, {
    required String userId,
  }) async {
    final wall = await _walls.get(wallId);
    if (wall == null || wall.ownerId != userId) {
      throw ArgumentError.value(wallId, 'wallId', 'no such wall');
    }
    return RoutesCompanion(
      areaId: Value(wall.gymId),
      kind: const Value('gym'),
      discipline: Value(wall.kind == 'boulder' ? 'boulder' : 'sport'),
      gymWallId: Value(wall.id),
      lengthM: Value(wall.heightM),
      angle: Value(wall.angle),
      status: const Value('open'),
    );
  }

  String _checkGym(NewGym gym) {
    final name = RouteEditor.checkName(gym.name);
    RouteEditor.checkCountry(gym.countryCode);
    RouteEditor.checkLocation(gym.location);
    if (!gymGradings.contains(gym.grading)) {
      throw ArgumentError.value(gym.grading, 'grading');
    }
    return name;
  }

  Future<void> _checkWalls(List<WallDraft> walls) async {
    final angle = (await _attributes.definitions(level: AttributeLevel.route))
        .where((d) => d.key == 'angle')
        .firstOrNull;
    for (final wall in walls) {
      RouteEditor.checkName(wall.name);
      if (!wallKinds.contains(wall.kind)) {
        throw ArgumentError.value(wall.kind, 'kind');
      }
      if (wall.heightM case final h?
          when !h.isFinite || h < minWallHeightM || h > maxWallHeightM) {
        throw ArgumentError.value(h, 'heightM');
      }
      if (wall.angleDeg case final d? when !isWallAngleDeg(d)) {
        throw ArgumentError.value(d, 'angleDeg');
      }
      if (wall.angleType case final a?
          when angle == null || !angle.accepts([a])) {
        throw ArgumentError.value(a, 'angle');
      }
    }
  }

  /// The live gym [gymId] that [userId] can see, or `null`.
  Future<Area?> _gymFor(String gymId, String userId) async {
    final area = await _areas.get(gymId);
    if (area == null ||
        area.type != 'gym' ||
        area.mergedIntoId != null ||
        (area.visibility != 'public' && area.createdBy != userId)) {
      return null;
    }
    return area;
  }

  /// The live gym [gymId] that [userId] can see, or [ArgumentError].
  Future<Area> _visibleGym(String gymId, String userId) async =>
      await _gymFor(gymId, userId) ??
      (throw ArgumentError.value(gymId, 'gymId', 'no such gym'));

  Future<List<GymWall>> _wallsOf(String gymId, String userId) =>
      (db.select(db.gymWalls)
            ..where(
              (w) =>
                  w.gymId.equals(gymId) &
                  w.ownerId.equals(userId) &
                  w.deletedAt.isNull(),
            )
            ..orderBy([(w) => OrderingTerm.asc(w.sort)]))
          .get();

  Future<void> _saveWalls(
    String gymId,
    List<WallDraft> walls,
    String userId,
  ) async {
    final current = {for (final w in await _wallsOf(gymId, userId)) w.id};
    final kept = {for (final w in walls) ?w.id};
    if (!current.containsAll(kept)) {
      throw ArgumentError.value(kept.difference(current), 'walls', 'not here');
    }
    for (final id in current.difference(kept)) {
      await _walls.softDelete(id, userId: userId);
    }
    for (final (sort, wall) in walls.indexed) {
      final fields = GymWallsCompanion(
        name: Value(wall.name.trim()),
        kind: Value(wall.kind),
        heightM: Value(wall.heightM),
        angle: Value(wall.angleType),
        angleDeg: Value(wall.angleDeg),
        sort: Value(sort),
      );
      if (wall.id case final id?) {
        await _walls.update(id, fields, userId: userId);
      } else {
        await _walls.create(
          fields.copyWith(gymId: Value(gymId)),
          userId: userId,
        );
      }
    }
  }

  static void _checkColours(List<ColourDraft> colours) {
    for (final colour in colours) {
      RouteEditor.checkName(colour.name);
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(colour.colourHex)) {
        throw ArgumentError.value(colour.colourHex, 'colourHex');
      }
      for (final range in [colour.boulder, colour.route]) {
        if (range case (:final min, :final max)
            when !min.isFinite || !max.isFinite || min > max) {
          throw ArgumentError.value(range, 'range');
        }
      }
    }
  }

  Future<List<GymColourGrade>> _coloursOf(String gymId, String userId) =>
      (db.select(db.gymColourGrades)
            ..where(
              (c) =>
                  c.gymId.equals(gymId) &
                  c.ownerId.equals(userId) &
                  c.deletedAt.isNull(),
            )
            ..orderBy([(c) => OrderingTerm.asc(c.sort)]))
          .get();

  Future<void> _saveColours(
    String gymId,
    List<ColourDraft> colours,
    String userId,
  ) async {
    final current = {for (final c in await _coloursOf(gymId, userId)) c.id};
    final kept = {for (final c in colours) ?c.id};
    if (!current.containsAll(kept)) {
      throw ArgumentError.value(
        kept.difference(current),
        'colours',
        'not here',
      );
    }
    for (final id in current.difference(kept)) {
      await _colours.softDelete(id, userId: userId);
    }
    for (final (sort, colour) in colours.indexed) {
      final fields = GymColourGradesCompanion(
        name: Value(colour.name.trim()),
        colourHex: Value(colour.colourHex.toUpperCase()),
        sort: Value(sort),
        boulderMinScore: Value(colour.boulder?.min),
        boulderMaxScore: Value(colour.boulder?.max),
        routeMinScore: Value(colour.route?.min),
        routeMaxScore: Value(colour.route?.max),
      );
      if (colour.id case final id?) {
        await _colours.update(id, fields, userId: userId);
      } else {
        await _colours.create(
          fields.copyWith(gymId: Value(gymId)),
          userId: userId,
        );
      }
    }
  }
}
