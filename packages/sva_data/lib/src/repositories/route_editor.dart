import 'package:drift/drift.dart';
import 'package:sva_core/sva_core.dart';
import 'package:sva_data/src/attributes/attribute_repository.dart';
import 'package:sva_data/src/database/sva_database.dart';
import 'package:sva_data/src/ids.dart';
import 'package:sva_data/src/repositories/place_repositories.dart';

/// A crag as the crag form fills it in.
final class NewCrag {
  const new({
    required this.name,
    required this.countryCode,
    this.parentId,
    this.rockType,
    this.location,
  });

  final String name;

  /// ISO 3166-1 alpha-2, such as `NO`.
  final String countryCode;

  /// The region or area the crag is in, if any.
  final String? parentId;

  /// A `rock.*` value key, such as `rock.granite`.
  final String? rockType;
  final LatLon? location;
}

/// One pitch of a multipitch route, from the bottom.
final class NewPitch {
  const new({this.gradeId, this.lengthM});

  final String? gradeId;
  final double? lengthM;
}

/// A route as the route form fills it in. Details are value keys from the
/// attribute definitions (`angle.slab`, `hold.crimp`).
final class NewRoute {
  const new({
    required this.areaId,
    required this.name,
    required this.discipline,
    this.gradeId,
    this.lengthM,
    this.pitches = const [],
    this.angle,
    this.features = const [],
    this.holds = const [],
    this.protection,
    this.descent,
    this.ropeLengthM,
    this.firstAscent,
  });

  /// The crag or sector the route is in.
  final String areaId;
  final String name;
  final String discipline;

  /// The official grade, a row in `grades`.
  final String? gradeId;
  final double? lengthM;

  /// Empty for a single-pitch route; otherwise one entry per pitch.
  final List<NewPitch> pitches;
  final String? angle;
  final List<String> features;
  final List<String> holds;
  final String? protection;
  final String? descent;
  final int? ropeLengthM;
  final String? firstAscent;
}

/// Longest name a place or route may have, in characters.
const maxNameLength = 120;

/// Highest number of pitches a route may have.
const maxPitches = 60;

/// Longest route, and longest pitch, in metres.
const maxRouteLengthM = 3000.0;

/// Adds crags and routes from the forms, each in one transaction, as the
/// user's private rows (docs/schema.md, How a route becomes shared).
/// Everything is checked here, at the boundary: a bad value throws
/// [ArgumentError] naming the field, and nothing is written.
class RouteEditor {
  new(SvaDatabase db, {DateTime Function()? clock})
    : this._(db, clock ?? (() => DateTime.now().toUtc()));

  new _(this.db, this.clock)
    : _areas = AreaRepository(db, clock: clock),
      _routes = RouteRepository(db, clock: clock),
      _attributes = AttributeRepository(db, clock: clock);

  final SvaDatabase db;
  final DateTime Function() clock;
  final AreaRepository _areas;
  final RouteRepository _routes;
  final AttributeRepository _attributes;

  /// Adds a crag for [userId]. Returns its id.
  Future<String> addCrag(NewCrag crag, {required String userId}) async {
    final name = checkName(crag.name);
    checkCountry(crag.countryCode);
    checkLocation(crag.location);
    final areaDefs = await _attributes.definitions(level: AttributeLevel.area);
    _checkValue(areaDefs, 'rock_type', crag.rockType);
    return await db.transaction(() async {
      if (crag.parentId case final parent?) {
        await _visibleArea(parent, userId, 'parentId', _cragParents);
      }
      return await _areas.createPrivate(
        AreasCompanion(
          type: const Value('crag'),
          name: Value(name),
          countryCode: Value(crag.countryCode),
          parentId: Value(crag.parentId),
          rockType: Value(crag.rockType),
          latitude: Value(crag.location?.lat),
          longitude: Value(crag.location?.lon),
        ),
        userId: userId,
      );
    });
  }

  /// Adds a route with its grade, details and pitches for [userId].
  /// Returns its id.
  Future<String> addRoute(NewRoute route, {required String userId}) async {
    final name = checkName(route.name);
    if (route.pitches.length > maxPitches) {
      throw ArgumentError.value(route.pitches.length, 'pitches');
    }
    _length(route.lengthM, 'lengthM');
    for (final pitch in route.pitches) {
      _length(pitch.lengthM, 'pitches');
    }
    if (route.ropeLengthM case final rope? when rope < 1 || rope > 200) {
      throw ArgumentError.value(rope, 'ropeLengthM');
    }
    final firstAscent = route.firstAscent?.trim();
    if (firstAscent != null && firstAscent.length > 200) {
      throw ArgumentError.value(firstAscent, 'firstAscent', 'too long');
    }
    final defs = await _attributes.definitions(level: AttributeLevel.route);
    _checkValue(defs, 'discipline', route.discipline);
    _checkValue(defs, 'angle', route.angle);
    _checkValue(defs, 'protection', route.protection);
    _checkValue(defs, 'descent', route.descent);
    for (final value in route.features) {
      _checkValue(defs, 'feature', value);
    }
    for (final value in route.holds) {
      _checkValue(defs, 'hold', value);
    }
    // Ice, mixed, aid and alpine grades come with their own systems later;
    // until then every route that is not a boulder takes a free grade.
    final gradeType = route.discipline == 'boulder' ? 'boulder' : 'free_route';

    return await db.transaction(() async {
      await _visibleArea(route.areaId, userId, 'areaId', _routePlaces);
      for (final id in [
        route.gradeId,
        for (final p in route.pitches) p.gradeId,
      ]) {
        if (id != null) await checkGrade(db, id, gradeType);
      }
      final id = await _routes.createPrivate(
        RoutesCompanion(
          areaId: Value(route.areaId),
          kind: const Value('outdoor'),
          name: Value(name),
          discipline: Value(route.discipline),
          status: const Value('open'),
          pitchCount: Value(route.pitches.isEmpty ? 1 : route.pitches.length),
          lengthM: Value(route.lengthM),
          angle: Value(route.angle),
          protection: Value(route.protection),
          descent: Value(route.descent),
          ropeLengthM: Value(route.ropeLengthM),
          firstAscent: Value(
            firstAscent == null || firstAscent.isEmpty ? null : firstAscent,
          ),
        ),
        userId: userId,
      );
      final now = clock();
      Future<void> grade(String gradeId, {String? pitchId}) => db
          .into(db.routeGrades)
          .insert(
            RouteGradesCompanion.insert(
              id: newId(),
              createdAt: now,
              updatedAt: now,
              createdBy: Value(userId),
              routeId: id,
              pitchId: Value(pitchId),
              gradeType: gradeType,
              gradeId: gradeId,
              source: 'official',
            ),
          );
      if (route.gradeId case final gradeId?) await grade(gradeId);
      for (final (i, pitch) in route.pitches.indexed) {
        final pitchId = newId();
        await db
            .into(db.pitches)
            .insert(
              PitchesCompanion.insert(
                id: pitchId,
                createdAt: now,
                updatedAt: now,
                createdBy: Value(userId),
                routeId: id,
                number: i + 1,
                lengthM: Value(pitch.lengthM),
              ),
            );
        if (pitch.gradeId case final gradeId?) {
          await grade(gradeId, pitchId: pitchId);
        }
      }
      if (route.features.isNotEmpty) {
        await _attributes.setRouteAttribute(
          id,
          'feature',
          route.features,
          userId: userId,
        );
      }
      if (route.holds.isNotEmpty) {
        await _attributes.setRouteAttribute(
          id,
          'hold',
          route.holds,
          userId: userId,
        );
      }
      return id;
    });
  }

  /// [raw] trimmed, or [ArgumentError] when empty or too long.
  static String checkName(String raw) {
    final name = raw.trim();
    if (name.isEmpty || name.length > maxNameLength) {
      throw ArgumentError.value(raw, 'name');
    }
    return name;
  }

  /// Throws [ArgumentError] unless [code] is an ISO 3166-1 alpha-2 code.
  static void checkCountry(String code) {
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      throw ArgumentError.value(code, 'countryCode');
    }
  }

  /// Throws [ArgumentError] unless [at] is `null` or a point on Earth.
  static void checkLocation(LatLon? at) {
    if (at == null) return;
    if (!at.lat.isFinite || at.lat.abs() > 90) {
      throw ArgumentError.value(at.lat, 'location', 'latitude');
    }
    if (!at.lon.isFinite || at.lon.abs() > 180) {
      throw ArgumentError.value(at.lon, 'location', 'longitude');
    }
  }

  static void _length(double? metres, String field) {
    if (metres != null &&
        (!metres.isFinite || metres <= 0 || metres > maxRouteLengthM)) {
      throw ArgumentError.value(metres, field);
    }
  }

  static void _checkValue(List<AttributeDef> defs, String key, String? value) {
    if (value == null) return;
    final def = defs.where((d) => d.key == key).firstOrNull;
    if (def == null || !def.accepts([value])) {
      throw ArgumentError.value(value, key);
    }
  }

  /// Places a crag can sit under, and places a route can be in.
  static const _cragParents = {'country', 'region', 'area'};
  static const _routePlaces = {'crag', 'sector', 'wall', 'boulder_block'};

  /// The live, unmerged place [id] of one of [types] that [userId] can
  /// see, or [ArgumentError].
  Future<Area> _visibleArea(
    String id,
    String userId,
    String field,
    Set<String> types,
  ) async {
    final area = await _areas.get(id);
    if (area == null ||
        area.mergedIntoId != null ||
        !types.contains(area.type) ||
        (area.visibility != 'public' && area.createdBy != userId)) {
      throw ArgumentError.value(id, field, 'no such place');
    }
    return area;
  }

  /// Throws [ArgumentError] unless grade [id] exists and is of
  /// [gradeType] (`free_route` or `boulder`).
  static Future<void> checkGrade(
    SvaDatabase db,
    String id,
    String gradeType,
  ) async {
    final row = await db
        .customSelect(
          'SELECT s.grade_type FROM grades g '
          'JOIN grade_systems s ON s.key = g.system_key '
          'AND s.deleted_at IS NULL '
          'WHERE g.id = ? AND g.deleted_at IS NULL',
          variables: [Variable.withString(id)],
          readsFrom: {db.grades, db.gradeSystems},
        )
        .getSingleOrNull();
    if (row?.read<String>('grade_type') != gradeType) {
      throw ArgumentError.value(id, 'gradeId', 'not a $gradeType grade');
    }
  }
}
