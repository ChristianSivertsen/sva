import 'package:drift/drift.dart';
import 'package:sva_core/sva_core.dart';
import 'package:sva_data/src/database/sva_database.dart';
import 'package:sva_data/src/ids.dart';
import 'package:sva_data/src/repositories/repository.dart';

/// The keys a search term is matched with. A term typed with æ, ø or å
/// means those letters, so it matches only the search key; a term without
/// them also matches the ascii key, so "floyen" finds "Fløyen".
({String search, String ascii}) _termKeys(String term) {
  final key = searchKey(term);
  return (
    search: key,
    ascii: key.contains(RegExp('[æøå]')) ? key : asciiKey(term),
  );
}

/// [_termKeys] as LIKE patterns. Keys hold only letters, digits and single
/// spaces, so nothing needs escaping.
({String search, String ascii}) _patterns(String term) {
  final keys = _termKeys(term);
  return (search: '%${keys.search}%', ascii: '%${keys.ascii}%');
}

/// The search keys for a name, as companion values.
({Value<String?> search, Value<String?> ascii}) _keysFor(String? name) => (
  search: Value(name == null ? null : searchKey(name)),
  ascii: Value(name == null ? null : asciiKey(name)),
);

/// Keeps the search keys in step with the name on every update.
mixin _NameKeyed<T extends Table, R> on Repository<T, R> {
  @override
  Set<String> get protectedColumns => {
    ...super.protectedColumns,
    'search_key',
    'ascii_key',
  };

  @override
  Map<String, Expression<Object>> derivedColumns(
    Map<String, Expression<Object>> changes,
  ) {
    final name = changes['name'];
    if (name == null) return const {};
    final keys = _keysFor((name as Variable<Object>).value as String?);
    return {
      'search_key': Variable(keys.search.value),
      'ascii_key': Variable(keys.ascii.value),
    };
  }
}

/// Countries, regions, crags, sectors, walls, boulders and gyms.
class AreaRepository extends Repository<$AreasTable, Area>
    with _NameKeyed<$AreasTable, Area> {
  new(super.db, {super.clock});

  @override
  $AreasTable get table => db.areas;
  @override
  RowAccess get access => RowAccess.shared;

  /// Adds a place as [userId]'s private row; it becomes shared when a
  /// moderator accepts it (docs/schema.md, How a route becomes shared).
  /// Returns the new id.
  Future<String> createPrivate(
    AreasCompanion draft, {
    required String userId,
  }) async {
    final id = newId();
    final now = clock();
    final keys = _keysFor(draft.name.present ? draft.name.value : null);
    await insert(
      draft.copyWith(
        id: Value(id),
        createdAt: Value(now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        createdBy: Value(userId),
        visibility: const Value('private'),
        mergedIntoId: const Value(null),
        searchKey: keys.search,
        asciiKey: keys.ascii,
      ),
    );
    return id;
  }

  /// The places directly under [parentId] (top-level ones when `null`),
  /// in Norwegian name order. Others' private places are left out.
  Stream<List<Area>> watchChildren(String? parentId, {required String userId}) {
    final query = live()
      ..where(
        (a) =>
            (parentId == null
                ? a.parentId.isNull()
                : a.parentId.equals(parentId)) &
            _visibleTo(a, userId),
      );
    return query.watch().map(_byName);
  }

  /// Places of the given [types] that [userId] can see, such as every crag
  /// and sector for the route form, in Norwegian name order, live.
  Stream<List<Area>> watchOfTypes(Set<String> types, {required String userId}) {
    final query = live()
      ..where((a) => a.type.isIn(types) & _visibleTo(a, userId));
    return query.watch().map(_byName);
  }

  /// Places whose name contains [term], up to [limit], in Norwegian name
  /// order. Æ, ø and å match as Norwegians expect (sva_core `searchKey`).
  Future<List<Area>> search(
    String term, {
    required String userId,
    int limit = 30,
  }) async {
    final like = _patterns(term);
    final query = live()
      ..where(
        (a) =>
            (a.searchKey.like(like.search) | a.asciiKey.like(like.ascii)) &
            _visibleTo(a, userId),
      );
    return _byName(await query.get()).take(limit).toList();
  }

  static List<Area> _byName(List<Area> areas) =>
      areas..sort((a, b) => compareNames(a.name, b.name));

  static Expression<bool> _visibleTo($AreasTable a, String userId) =>
      a.visibility.equals('public') | a.createdBy.equals(userId);
}

/// A point on the map, in degrees.
typedef LatLon = ({double lat, double lon});

/// A route in search results, with what the list shows and why it ranks
/// where it does.
///
/// - `grade`: the official grade's label, such as `7-`, or `null`.
/// - `gradeSystem`: the key of that grade's system, such as `nor`.
/// - `crag`: the crag the route is in, or its nearest place without one.
/// - `lastClimbed`: `YYYY-MM-DD` of the user's latest climb on it.
/// - `distanceKm`: from the point searched from, `null` without one.
/// - `location`: where the route is, from the nearest place above it that
///   has one, or `null`.
typedef RouteHit = ({
  Route route,
  String? grade,
  String? gradeSystem,
  String? crag,
  String? lastClimbed,
  double? distanceKm,
  LatLon? location,
});

/// Every climbable line, outdoors or in a gym.
class RouteRepository extends Repository<$RoutesTable, Route>
    with _NameKeyed<$RoutesTable, Route> {
  new(super.db, {super.clock});

  @override
  $RoutesTable get table => db.routes;
  @override
  RowAccess get access => RowAccess.shared;

  /// Adds a route as [userId]'s private route. Gym routes stay private.
  /// Returns the new id.
  Future<String> createPrivate(
    RoutesCompanion draft, {
    required String userId,
  }) async {
    final id = newId();
    final now = clock();
    final keys = _keysFor(draft.name.present ? draft.name.value : null);
    await insert(
      draft.copyWith(
        id: Value(id),
        createdAt: Value(now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        createdBy: Value(userId),
        visibility: const Value('private'),
        mergedIntoId: const Value(null),
        consensusScore: const Value(null),
        qualityAvg: const Value(null),
        searchKey: keys.search,
        asciiKey: keys.ascii,
      ),
    );
    return id;
  }

  /// The routes in one place, in Norwegian name order, without others'
  /// private routes.
  Stream<List<Route>> watchInArea(String areaId, {required String userId}) {
    final query = live()
      ..where((r) => r.areaId.equals(areaId) & _visibleTo(r, userId));
    return query.watch().map(
      (routes) =>
          routes..sort((a, b) => compareNames(a.name ?? '', b.name ?? '')),
    );
  }

  /// Outdoor routes for search and the route picker, best first, up to
  /// [limit]. Gym routes never appear here (PLAN.md 4).
  ///
  /// With a [term], only routes whose name, or the name of one of the
  /// three places above them, contains it; æ, ø and å match as Norwegians
  /// expect (sva_core `searchKey`). Routes with a word in their own name
  /// starting with the term come first, then routes whose name contains
  /// it, then routes whose place matches. Within each group, and for an
  /// empty term: routes [userId] climbed, most recent first; then nearest
  /// to [near]; then by name.
  ///
  /// Ranking happens in Dart over every match, which stays fast for the
  /// few thousand routes a device holds. Move it into SQL if devices start
  /// holding far more.
  Future<List<RouteHit>> find({
    required String userId,
    String term = '',
    LatLon? near,
    int limit = 30,
  }) async {
    if (_matchesNothing(term)) return const [];
    return _rank(
      await _select(userId: userId, term: term).get(),
      term: term,
      near: near,
      limit: limit,
    );
  }

  /// [find], updating whenever a route, place, climb or grade changes, so
  /// a route added or logged shows up straight away.
  Stream<List<RouteHit>> watchFind({
    required String userId,
    String term = '',
    LatLon? near,
    int limit = 30,
  }) => _matchesNothing(term)
      ? Stream.value(const [])
      : _select(userId: userId, term: term).watch().map(
          (rows) => _rank(rows, term: term, near: near, limit: limit),
        );

  /// A term of only punctuation, such as "-", has an empty key; it should
  /// find nothing rather than every route.
  static bool _matchesNothing(String term) =>
      term.trim().isNotEmpty && searchKey(term).isEmpty;

  /// One route as [find] shows it, or `null` when it is gone, a gym route
  /// or private to someone else.
  Future<RouteHit?> hit(
    String routeId, {
    required String userId,
    LatLon? near,
  }) async {
    final rows = await _select(userId: userId, routeId: routeId).get();
    return _rank(rows, near: near, limit: 1).firstOrNull;
  }

  /// SQL for one [column] of the route's official climbing grade (not a
  /// danger or commitment grade), for the route `r`.
  static String _officialGrade(String column) =>
      '(SELECT g.$column FROM route_grades rg '
      'JOIN grades g ON g.id = rg.grade_id AND g.deleted_at IS NULL '
      'WHERE rg.route_id = r.id AND rg.pitch_id IS NULL '
      "AND rg.grade_type IN ('free_route', 'boulder') "
      "AND rg.source = 'official' AND rg.deleted_at IS NULL "
      'ORDER BY g.sort LIMIT 1)';

  Selectable<QueryRow> _select({
    required String userId,
    String term = '',
    String? routeId,
  }) {
    final like = _patterns(term);
    return db.customSelect(
      'SELECT r.*, '
      'COALESCE('
      "CASE WHEN a1.type = 'crag' THEN a1.name END, "
      "CASE WHEN a2.type = 'crag' THEN a2.name END, "
      "CASE WHEN a3.type = 'crag' THEN a3.name END, "
      'a1.name) AS crag_name, '
      'COALESCE(a1.latitude, a2.latitude, a3.latitude) AS lat, '
      'COALESCE(a1.longitude, a2.longitude, a3.longitude) AS lon, '
      'mine.last_climbed, '
      '${_officialGrade('label')} AS grade_label, '
      '${_officialGrade('system_key')} AS grade_system '
      'FROM routes r '
      'LEFT JOIN areas a1 ON a1.id = r.area_id AND ${_visibleArea('a1')} '
      'LEFT JOIN areas a2 ON a2.id = a1.parent_id '
      'AND a2.deleted_at IS NULL '
      'LEFT JOIN areas a3 ON a3.id = a2.parent_id '
      'AND a3.deleted_at IS NULL '
      'LEFT JOIN ( '
      'SELECT x.route_id, MAX(s.local_date) AS last_climbed '
      'FROM ascents x JOIN sessions s ON s.id = x.session_id '
      'WHERE x.owner_id = ?1 AND x.deleted_at IS NULL '
      'AND s.deleted_at IS NULL '
      'GROUP BY x.route_id '
      ') mine ON mine.route_id = r.id '
      "WHERE r.deleted_at IS NULL AND r.kind = 'outdoor' "
      "AND (r.visibility = 'public' OR r.created_by = ?1) "
      // An empty term ('%%') matches every route, named or not.
      "AND (?2 = '%%' OR ${_matchAny(const ['r', 'a1', 'a2', 'a3'])}) "
      'AND (?4 IS NULL OR r.id = ?4)',
      variables: [
        Variable.withString(userId),
        Variable.withString(like.search),
        Variable.withString(like.ascii),
        Variable<String>(routeId),
      ],
      readsFrom: {
        db.routes,
        db.areas,
        db.ascents,
        db.sessions,
        db.routeGrades,
        db.grades,
      },
    );
  }

  List<RouteHit> _rank(
    List<QueryRow> rows, {
    required LatLon? near,
    required int limit,
    String term = '',
  }) {
    final (search: key, :ascii) = _termKeys(term);
    final ranked = [
      for (final row in rows)
        (
          hit: (
            route: db.routes.map(row.data),
            grade: row.readNullable<String>('grade_label'),
            gradeSystem: row.readNullable<String>('grade_system'),
            crag: row.readNullable<String>('crag_name'),
            lastClimbed: row.readNullable<String>('last_climbed'),
            distanceKm: _distanceKm(
              near,
              row.readNullable<double>('lat'),
              row.readNullable<double>('lon'),
            ),
            location: switch ((
              row.readNullable<double>('lat'),
              row.readNullable<double>('lon'),
            )) {
              (final lat?, final lon?) => (lat: lat, lon: lon),
              _ => null,
            },
          ),
          sortKey: nameSortKey(row.readNullable<String>('name') ?? ''),
          tier: _matchTier(
            key,
            ascii,
            row.readNullable<String>('search_key'),
            row.readNullable<String>('ascii_key'),
          ),
        ),
    ]..sort(_compareRanked);
    return [for (final r in ranked.take(limit)) r.hit];
  }

  // Places above a route count only when the user can see them, so a
  // public route under someone's private crag does not show its name or
  // location.
  static String _visibleArea(String t) =>
      "$t.deleted_at IS NULL AND ($t.visibility = 'public' "
      'OR $t.created_by = ?1)';

  /// SQL that is true when the term matches the name keys of any of
  /// [aliases]. `?2` and `?3` are the search and ascii patterns.
  static String _matchAny(List<String> aliases) => [
    for (final t in aliases) ...[
      '$t.search_key LIKE ?2',
      '$t.ascii_key LIKE ?3',
    ],
  ].join(' OR ');

  /// 0 when a word in the route's own name starts with the term, 1 when
  /// the name contains it elsewhere, 2 when only a place matches.
  static int _matchTier(
    String key,
    String ascii,
    String? routeKey,
    String? routeAscii,
  ) {
    if (key.isEmpty) return 0;
    bool startsWord(String? name, String term) =>
        name != null && (name.startsWith(term) || name.contains(' $term'));
    if (startsWord(routeKey, key) || startsWord(routeAscii, ascii)) return 0;
    if ((routeKey?.contains(key) ?? false) ||
        (routeAscii?.contains(ascii) ?? false)) {
      return 1;
    }
    return 2;
  }

  static int _compareRanked(
    ({RouteHit hit, String sortKey, int tier}) a,
    ({RouteHit hit, String sortKey, int tier}) b,
  ) {
    // A typed name wins: an exact route-name match beats a route you
    // climbed that only matched on its crag. Without a term all tiers are 0.
    final tier = a.tier.compareTo(b.tier);
    if (tier != 0) return tier;
    // Climbed before not climbed, the latest first.
    final climbed = _compareNullsLast(
      a.hit.lastClimbed,
      b.hit.lastClimbed,
      descending: true,
    );
    if (climbed != 0) return climbed;
    final distance = _compareNullsLast(a.hit.distanceKm, b.hit.distanceKm);
    if (distance != 0) return distance;
    return a.sortKey.compareTo(b.sortKey);
  }

  /// Orders values ascending, or [descending], with `null` last either way.
  static int _compareNullsLast<C extends Comparable<Object>>(
    C? a,
    C? b, {
    bool descending = false,
  }) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return descending ? b.compareTo(a) : a.compareTo(b);
  }

  static Expression<bool> _visibleTo($RoutesTable r, String userId) =>
      r.visibility.equals('public') | r.createdBy.equals(userId);
}

/// Great-circle distance in km, or `null` when a point is missing.
double? _distanceKm(LatLon? from, double? lat, double? lon) {
  if (from == null || lat == null || lon == null) return null;
  return distanceKm(from.lat, from.lon, lat, lon);
}

/// A user's own walls in a gym; gyms themselves are shared areas.
class GymWallRepository extends Repository<$GymWallsTable, GymWall> {
  new(super.db, {super.clock});

  @override
  $GymWallsTable get table => db.gymWalls;
  @override
  RowAccess get access => RowAccess.owned;

  /// Adds a wall for [userId]. Returns the new id.
  Future<String> create(
    GymWallsCompanion draft, {
    required String userId,
  }) async {
    final id = newId();
    final now = clock();
    await insert(
      draft.copyWith(
        id: Value(id),
        createdAt: Value(now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        ownerId: Value(userId),
      ),
    );
    return id;
  }

  /// [userId]'s walls in [gymId], in their order.
  Stream<List<GymWall>> watchInGym(String gymId, {required String userId}) {
    final query = live()
      ..where((w) => w.gymId.equals(gymId) & w.ownerId.equals(userId))
      ..orderBy([
        (w) => OrderingTerm(expression: w.sort),
        (w) => OrderingTerm(expression: w.name),
      ]);
    return query.watch();
  }
}

/// A user's own colour scale for a gym, easiest first.
class GymColourGradeRepository
    extends Repository<$GymColourGradesTable, GymColourGrade> {
  new(super.db, {super.clock});

  @override
  $GymColourGradesTable get table => db.gymColourGrades;
  @override
  RowAccess get access => RowAccess.owned;

  /// Adds a colour for [userId]. Returns the new id.
  Future<String> create(
    GymColourGradesCompanion draft, {
    required String userId,
  }) async {
    final id = newId();
    final now = clock();
    await insert(
      draft.copyWith(
        id: Value(id),
        createdAt: Value(now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        ownerId: Value(userId),
      ),
    );
    return id;
  }

  /// [userId]'s colours for [gymId], easiest first.
  Stream<List<GymColourGrade>> watchForGym(
    String gymId, {
    required String userId,
  }) {
    final query = live()
      ..where((g) => g.gymId.equals(gymId) & g.ownerId.equals(userId))
      ..orderBy([(g) => OrderingTerm(expression: g.sort)]);
    return query.watch();
  }
}
