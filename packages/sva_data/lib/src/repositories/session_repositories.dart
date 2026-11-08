import 'package:drift/drift.dart';
import 'package:sva_core/sva_core.dart';
import 'package:sva_data/src/database/sva_database.dart';
import 'package:sva_data/src/ids.dart';
import 'package:sva_data/src/repositories/place_repositories.dart' show LatLon;
import 'package:sva_data/src/repositories/repository.dart';

/// A child table of a session or ascent and the column that points at its
/// parent. `hasVisibility` says whether it carries a copy of the session's
/// visibility (docs/schema.md, Visibility).
typedef _Child = ({
  TableInfo<Table, Object?> table,
  GeneratedColumn<String> parent,
  bool hasVisibility,
});

List<_Child> _ascentChildren(SvaDatabase db) => [
  (
    table: db.ascentPitches,
    parent: db.ascentPitches.ascentId,
    hasVisibility: true,
  ),
  (
    table: db.ascentAttributes,
    parent: db.ascentAttributes.ascentId,
    hasVisibility: true,
  ),
  (table: db.ascentGear, parent: db.ascentGear.ascentId, hasVisibility: true),
  // Beta notes are owner-only and never visible to others.
  (table: db.ascentBeta, parent: db.ascentBeta.ascentId, hasVisibility: false),
];

List<_Child> _sessionChildren(SvaDatabase db) => [
  (table: db.ascents, parent: db.ascents.sessionId, hasVisibility: true),
  (
    table: db.sessionMembers,
    parent: db.sessionMembers.sessionId,
    hasVisibility: true,
  ),
  (
    table: db.weatherSnapshots,
    parent: db.weatherSnapshots.sessionId,
    hasVisibility: true,
  ),
];

/// A day of climbing and everything under it.
class SessionRepository extends Repository<$SessionsTable, Session> {
  new(super.db, {super.clock});

  @override
  $SessionsTable get table => db.sessions;
  @override
  RowAccess get access => RowAccess.owned;

  /// The setting is cached on every ascent, so it is fixed at creation.
  @override
  Set<String> get protectedColumns => {...super.protectedColumns, 'setting'};

  /// Adds a session for [userId]. Returns the new id.
  Future<String> create(
    SessionsCompanion draft, {
    required String userId,
  }) async {
    checkVisibility(draft.visibility.value);
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

  /// [userId]'s sessions, newest day first. With [limit], only that many
  /// of the newest, so a feed can read one page at a time.
  Stream<List<Session>> watchMine({required String userId, int? limit}) {
    final query = live()
      ..where((s) => s.ownerId.equals(userId))
      ..orderBy([
        (s) => OrderingTerm.desc(s.localDate),
        (s) => OrderingTerm.desc(s.createdAt),
        (s) => OrderingTerm.desc(s.id),
      ]);
    if (limit != null) query.limit(limit);
    return query.watch();
  }

  /// The names of the partners on a session without the app, in the order
  /// they were added, live.
  Stream<List<String>> watchPartners(String sessionId) {
    final query = db.select(db.sessionMembers)
      ..where(
        (m) =>
            m.sessionId.equals(sessionId) &
            m.deletedAt.isNull() &
            m.status.equals('guest'),
      )
      ..orderBy([(m) => OrderingTerm(expression: m.createdAt)]);
    return query.watch().map((rows) => [for (final m in rows) ?m.guestName]);
  }

  /// A session's weather, once it has been fetched, live.
  Stream<WeatherSnapshot?> watchWeather(String sessionId) =>
      (db.select(db.weatherSnapshots)
            ..where((w) => w.sessionId.equals(sessionId) & w.deletedAt.isNull())
            ..orderBy([(w) => OrderingTerm.desc(w.fetchedAt)])
            ..limit(1))
          .watchSingleOrNull();

  /// `outdoor` or `indoor`: the setting of the session [userId] logged
  /// last (whatever its date), so the log sheet opens on the last choice.
  /// `null` before the first.
  Future<String?> lastSetting({required String userId}) async {
    final query = live()
      ..where((s) => s.ownerId.equals(userId))
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
      ..limit(1);
    return (await query.getSingleOrNull())?.setting;
  }

  /// Where [userId] climbed outdoors most recently: the place of their
  /// latest outdoor session with a known location (the session's place, or
  /// else its first climb's), looked up to three levels up. `null` when
  /// there is none. Search uses it for "nearby" until the app reads the
  /// phone's location.
  Future<LatLon?> lastOutdoorLocation({required String userId}) async {
    final row = await db
        .customSelect(
          'WITH places AS ( '
          'SELECT s.local_date, s.created_at, COALESCE(s.area_id, ( '
          'SELECT r.area_id FROM ascents x JOIN routes r ON r.id = x.route_id '
          'WHERE x.session_id = s.id AND x.deleted_at IS NULL '
          'ORDER BY x.ordinal LIMIT 1)) AS area_id '
          'FROM sessions s '
          'WHERE s.owner_id = ?1 AND s.deleted_at IS NULL '
          "AND s.setting = 'outdoor') "
          'SELECT COALESCE(a1.latitude, a2.latitude, a3.latitude) AS lat, '
          'COALESCE(a1.longitude, a2.longitude, a3.longitude) AS lon '
          'FROM places p '
          'JOIN areas a1 ON a1.id = p.area_id '
          'LEFT JOIN areas a2 ON a2.id = a1.parent_id '
          'LEFT JOIN areas a3 ON a3.id = a2.parent_id '
          'WHERE COALESCE(a1.latitude, a2.latitude, a3.latitude) IS NOT NULL '
          'AND COALESCE(a1.longitude, a2.longitude, a3.longitude) IS NOT NULL '
          'ORDER BY p.local_date DESC, p.created_at DESC LIMIT 1',
          variables: [Variable.withString(userId)],
          readsFrom: {db.sessions, db.ascents, db.routes, db.areas},
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (lat: row.read<double>('lat'), lon: row.read<double>('lon'));
  }

  /// Changes who can see a session, and the copies of its visibility on
  /// every child row, deleted ones included (they still sync), so sync
  /// rules decide on each row alone.
  Future<void> setVisibility(
    String id,
    String visibility, {
    required String userId,
  }) {
    checkVisibility(visibility);
    return db.transaction(() async {
      await writeChecked(id, userId, {'visibility': Variable(visibility)});
      final now = clock();
      final ascentIds = await _ascentIds(id);
      for (final (child, keys) in [
        for (final c in _sessionChildren(db)) (c, [id]),
        for (final c in _ascentChildren(db)) (c, ascentIds),
      ]) {
        if (!child.hasVisibility || keys.isEmpty) continue;
        await db.customUpdate(
          // Names come from the generated tables, never from input.
          'UPDATE ${child.table.actualTableName} '
          'SET visibility = ?, updated_at = ? '
          'WHERE ${child.parent.name} IN '
          '(${List.filled(keys.length, '?').join(', ')})',
          variables: [
            Variable<String>(visibility),
            Variable<DateTime>(now),
            for (final k in keys) Variable.withString(k),
          ],
          updates: {child.table},
          updateKind: UpdateKind.update,
        );
      }
    });
  }

  /// Soft-deletes a session with its ascents and all their child rows.
  @override
  Future<void> softDelete(String id, {required String userId}) =>
      db.transaction(() async {
        await checkWritable(id, userId);
        final ascentIds = await _ascentIds(id);
        await markDeleted(table, table.id, [id]);
        for (final child in _sessionChildren(db)) {
          await markDeleted(child.table, child.parent, [id]);
        }
        for (final child in _ascentChildren(db)) {
          await markDeleted(child.table, child.parent, ascentIds);
        }
      });

  Future<List<String>> _ascentIds(String sessionId) async {
    final rows = await (db.select(
      db.ascents,
    )..where((a) => a.sessionId.equals(sessionId))).get();
    return [for (final a in rows) a.id];
  }
}

/// One of the user's climbs on a route, for the route page: the session's
/// day, the climb, and the labels of its official grade as it was when
/// logged and of the user's personal grade.
typedef RouteClimb = ({
  String date,
  Ascent ascent,
  String? officialGrade,
  String? officialSystem,
  String? personalGrade,
  String? personalSystem,
});

/// One live ascent in a route's log, with its id and session.
typedef RouteLogEntry = ({String id, String sessionId, LoggedAscent ascent});

/// Ascent types a climb in an indoor session can have. An auto-belay climb
/// logs as top rope (docs/schema.md, ascents); outdoors, the session
/// logger offers `outdoorAscentTypes`.
const indoorAscentTypes = {'lead', 'toprope', 'boulder'};

/// Climbs logged in a session.
class AscentRepository extends Repository<$AscentsTable, Ascent> {
  new(super.db, {super.clock});

  @override
  $AscentsTable get table => db.ascents;
  @override
  RowAccess get access => RowAccess.owned;

  /// The session, route and their caches are fixed at creation: moving a
  /// climb is a delete and a new log.
  @override
  Set<String> get protectedColumns => {
    ...super.protectedColumns,
    'session_id',
    'route_id',
    'setting',
    'discipline',
  };

  /// Adds an ascent to one of [userId]'s sessions, on a route [userId] can
  /// see. Owner, visibility and the setting and discipline caches come from
  /// the session and the route, not from the caller. Returns the new id.
  Future<String> create(AscentsCompanion draft, {required String userId}) {
    if (!draft.sessionId.present || !draft.routeId.present) {
      throw ArgumentError.value(draft, 'draft', 'needs a session and route');
    }
    final sessionId = draft.sessionId.value;
    final routeId = draft.routeId.value;
    return db.transaction(() async {
      final session =
          await (db.select(db.sessions)..where(
                (s) =>
                    s.id.equals(sessionId) &
                    s.deletedAt.isNull() &
                    s.ownerId.equals(userId),
              ))
              .getSingleOrNull();
      if (session == null) throw NotYourRow('sessions', sessionId);
      if (session.setting == 'indoor' &&
          !indoorAscentTypes.contains(draft.ascentType.value)) {
        throw ArgumentError.value(draft.ascentType.value, 'ascentType');
      }
      final route =
          await (db.select(db.routes)..where(
                (r) =>
                    r.id.equals(routeId) &
                    r.deletedAt.isNull() &
                    (r.visibility.equals('public') |
                        r.createdBy.equals(userId)),
              ))
              .getSingleOrNull();
      if (route == null) throw ArgumentError.value(routeId, 'routeId');
      final id = newId();
      final now = clock();
      await insert(
        draft.copyWith(
          id: Value(id),
          createdAt: Value(now),
          updatedAt: Value(now),
          deletedAt: const Value(null),
          ownerId: Value(userId),
          visibility: Value(session.visibility),
          setting: Value(session.setting),
          discipline: Value(route.discipline),
        ),
      );
      return id;
    });
  }

  /// Soft-deletes one climb with its pitches, details, gear and beta.
  @override
  Future<void> softDelete(String id, {required String userId}) =>
      db.transaction(() async {
        await checkWritable(id, userId);
        await markDeleted(table, table.id, [id]);
        for (final child in _ascentChildren(db)) {
          await markDeleted(child.table, child.parent, [id]);
        }
      });

  /// The climbs in a session, in the order they were climbed.
  Stream<List<Ascent>> watchInSession(String sessionId) {
    final query = live()
      ..where((a) => a.sessionId.equals(sessionId))
      ..orderBy([(a) => OrderingTerm(expression: a.ordinal)]);
    return query.watch();
  }

  /// [userId]'s climbs on a route with each session's day and the labels
  /// of the official grade (as it was when logged) and the personal grade,
  /// newest first, updating as climbs are logged or removed.
  Stream<List<RouteClimb>> watchOnRoute(
    String routeId, {
    required String userId,
  }) {
    // Deleted grades still show their label: these are what the climb was
    // logged with.
    final official = db.alias(db.grades, 'official');
    final personal = db.alias(db.grades, 'personal');
    final query =
        db.select(db.ascents).join([
            innerJoin(
              db.sessions,
              db.sessions.id.equalsExp(db.ascents.sessionId),
            ),
            leftOuterJoin(
              official,
              official.id.equalsExp(db.ascents.officialGradeId),
            ),
            leftOuterJoin(
              personal,
              personal.id.equalsExp(db.ascents.personalGradeId),
            ),
          ])
          ..where(
            db.ascents.routeId.equals(routeId) &
                db.ascents.ownerId.equals(userId) &
                db.ascents.deletedAt.isNull() &
                db.sessions.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.desc(db.sessions.localDate),
            OrderingTerm.desc(db.sessions.createdAt),
            OrderingTerm.desc(db.ascents.ordinal),
          ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            date: row.readTable(db.sessions).localDate,
            ascent: row.readTable(db.ascents),
            officialGrade: row.readTableOrNull(official)?.label,
            officialSystem: row.readTableOrNull(official)?.systemKey,
            personalGrade: row.readTableOrNull(personal)?.label,
            personalSystem: row.readTableOrNull(personal)?.systemKey,
          ),
      ],
    );
  }

  /// [userId]'s live ascents of a route, oldest first, in the form the
  /// style and tries rules take (sva_core `checkRouteLog`). The order is the
  /// one the server uses: session local date, then the session's creation
  /// time and id (for two sessions on one day), then the ascent's ordinal.
  Future<List<LoggedAscent>> routeLog(
    String routeId, {
    required String userId,
  }) async => [
    for (final entry in await routeEntries(routeId, userId: userId))
      entry.ascent,
  ];

  /// [routeLog] with each ascent's id and session. With [upToSession],
  /// only the ascents in that session and the sessions before it: what a
  /// climb added to that session follows.
  Future<List<RouteLogEntry>> routeEntries(
    String routeId, {
    required String userId,
    String? upToSession,
  }) async {
    final until = upToSession == null
        ? null
        : await (db.select(
                db.sessions,
              )..where((s) => s.id.equals(upToSession))).getSingleOrNull() ??
              (throw ArgumentError.value(upToSession, 'upToSession'));
    final query =
        db.select(db.ascents).join([
            innerJoin(
              db.sessions,
              db.sessions.id.equalsExp(db.ascents.sessionId),
            ),
          ])
          ..where(
            db.ascents.routeId.equals(routeId) &
                db.ascents.ownerId.equals(userId) &
                db.ascents.deletedAt.isNull() &
                db.sessions.deletedAt.isNull() &
                (until == null ? const Constant(true) : _upTo(until)),
          )
          ..orderBy([
            OrderingTerm(expression: db.sessions.localDate),
            OrderingTerm(expression: db.sessions.createdAt),
            OrderingTerm(expression: db.sessions.id),
            OrderingTerm(expression: db.ascents.ordinal),
          ]);
    return [
      for (final row in await query.get())
        if (AscentStyle.values.asNameMap()[row.readTable(db.ascents).style]
            case final style?)
          (
            id: row.readTable(db.ascents).id,
            sessionId: row.readTable(db.sessions).id,
            ascent: (style: style, tries: row.readTable(db.ascents).tries),
          ),
    ];
  }

  /// Sessions that sort no later than [session], in [routeLog]'s order.
  Expression<bool> _upTo(Session session) {
    final s = db.sessions;
    final date = Variable(session.localDate);
    final created = Variable(session.createdAt);
    return s.localDate.isSmallerThan(date) |
        (s.localDate.equalsExp(date) &
            (s.createdAt.isSmallerThan(created) |
                (s.createdAt.equalsExp(created) &
                    s.id.isSmallerOrEqualValue(session.id))));
  }
}
