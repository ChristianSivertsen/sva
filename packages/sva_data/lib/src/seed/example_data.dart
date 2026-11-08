import 'package:drift/drift.dart';
import 'package:sva_data/src/database/sva_database.dart';
import 'package:sva_data/src/ids.dart';
import 'package:sva_data/src/repositories/place_repositories.dart' show LatLon;

// EXAMPLE DATA FOR DEBUG BUILDS ONLY. A small slice of the prototype's
// made-up history, so screens have something to show while they are built.
// Row ids are derived from the user and an `example:` name, so
// [exampleIds] can list them and [removeExampleData] remove them. Both
// functions refuse to run where asserts are off (release builds), and sync
// (M11-4) must never upload these rows.

/// Throws in builds without asserts, so example data never reaches a
/// release build.
void _debugOnly() {
  var debug = false;
  assert(debug = true, 'only checks that asserts are on');
  if (!debug) throw StateError('Example data is for debug builds only');
}

/// Adds the example data for [userId] once; running it again changes
/// nothing. Places and routes are [userId]'s private rows.
Future<void> seedExampleData(SvaDatabase db, {required String userId}) async {
  _debugOnly();
  String exampleId(String name) => _exampleId(userId, name);
  final t = DateTime.utc(2026, 11);
  // Builds [row] with the example id for [name].
  Insertable<R> withId<R>(Insertable<R> Function(String id) row, String name) =>
      row(exampleId(name));

  await db.batch((b) {
    void area(
      String name,
      String type, {
      String? parent,
      String? rock,
      LatLon? at,
    }) => b.insert(
      db.areas,
      AreasCompanion.insert(
        id: exampleId(name),
        createdAt: t,
        updatedAt: t,
        visibility: 'private',
        createdBy: Value(userId),
        parentId: Value(parent == null ? null : exampleId(parent)),
        type: type,
        name: name,
        countryCode: 'NO',
        rockType: Value(rock),
        latitude: Value(at?.lat),
        longitude: Value(at?.lon),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    area('Kolsås', 'crag', rock: 'rock.basalt', at: (lat: 59.92, lon: 10.50));
    area(
      'Flatanger',
      'crag',
      rock: 'rock.granite',
      at: (lat: 64.49, lon: 10.80),
    );
    area('Hanshelleren', 'sector', parent: 'Flatanger');
    area('Home gym, Oslo', 'gym');
    // Its colours and walls, as in prototype/gym-log.html, so the gym log
    // can be tried straight away.
    final gym = exampleId('Home gym, Oslo');
    b.insert(
      db.gymProfiles,
      GymProfilesCompanion.insert(
        id: exampleId('gym profile'),
        createdAt: t,
        updatedAt: t,
        createdBy: Value(userId),
        areaId: gym,
        grading: 'colour',
      ),
      mode: InsertMode.insertOrIgnore,
    );
    for (final (i, (name, kind, height, angle)) in _exampleWalls.indexed) {
      b.insert(
        db.gymWalls,
        GymWallsCompanion.insert(
          id: exampleId('wall $name'),
          createdAt: t,
          updatedAt: t,
          ownerId: userId,
          gymId: gym,
          name: name,
          kind: kind,
          heightM: Value(height),
          angle: Value(angle),
          sort: Value(i),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    for (final (i, (name, hex)) in _exampleColours.indexed) {
      b.insert(
        db.gymColourGrades,
        GymColourGradesCompanion.insert(
          id: exampleId('colour $name'),
          createdAt: t,
          updatedAt: t,
          ownerId: userId,
          gymId: gym,
          sort: i,
          name: name,
          colourHex: hex,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    void route(String name, String area, String discipline, String angle) =>
        b.insert(
          db.routes,
          RoutesCompanion.insert(
            id: exampleId(name),
            createdAt: t,
            updatedAt: t,
            visibility: 'private',
            createdBy: Value(userId),
            areaId: exampleId(area),
            kind: 'outdoor',
            name: Value(name),
            discipline: discipline,
            status: 'open',
            angle: Value(angle),
            lengthM: const Value(22),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    for (final MapEntry(key: name, value: (place, discipline, angle))
        in _routes.entries) {
      route(name, place, discipline, angle);
    }

    // Sessions with climbs: (date, place, title, [(route, style, tries)]).
    final days = [
      (
        '2026-09-12',
        'Hanshelleren',
        'Flatanger pump fest',
        [('Varmen', 'onsight', 1), ('Nordlys', 'attempt', 3)],
      ),
      ('2026-09-14', 'Hanshelleren', 'Cave day', [('Nordlys', 'redpoint', 5)]),
      (
        '2026-10-17',
        'Kolsås',
        'After-work laps',
        [
          ('Hjemmebane', 'flash', 1),
          ('Kveldsløftet', 'attempt', 2),
          ('Skiferdiederet', 'onsight', 1),
        ],
      ),
      (
        '2026-10-31',
        'Kolsås',
        'Last warm evening',
        [('Kveldsløftet', 'redpoint', 4), ('Hjemmebane', 'repeat', 1)],
      ),
    ];
    for (final (date, place, title, climbs) in days) {
      b.insert(
        db.sessions,
        withId(
          (id) => SessionsCompanion.insert(
            id: id,
            createdAt: t,
            updatedAt: t,
            ownerId: userId,
            visibility: 'friends',
            areaId: Value(exampleId(place)),
            setting: 'outdoor',
            localDate: date,
            tz: 'Europe/Oslo',
            title: Value(title),
          ),
          'session $date',
        ),
        mode: InsertMode.insertOrIgnore,
      );
      for (final (i, (route, style, tries)) in climbs.indexed) {
        b.insert(
          db.ascents,
          withId(
            (id) => AscentsCompanion.insert(
              id: id,
              createdAt: t,
              updatedAt: t,
              ownerId: userId,
              visibility: 'friends',
              sessionId: exampleId('session $date'),
              routeId: exampleId(route),
              ordinal: i + 1,
              ascentType: 'lead',
              style: style,
              tries: tries,
              setting: 'outdoor',
              discipline: _routes[route]!.$2,
            ),
            'ascent $date $route',
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    }

    for (final (label, category, made) in [
      ('Cam #1', 'cam', '2018-06'),
      ('Cam #2', 'cam', '2023-05'),
      ('Nuts #1–11', 'nut', '2017-05'),
    ]) {
      b.insert(
        db.gearPieces,
        withId(
          (id) => GearPiecesCompanion.insert(
            id: id,
            createdAt: t,
            updatedAt: t,
            ownerId: userId,
            category: category,
            label: label,
            madeOn: Value(made),
            inDefaultRack: const Value(true),
          ),
          'gear $label',
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    for (final (brand, model) in [
      ('La Sportiva', 'Solution'),
      ('La Sportiva', 'TC Pro'),
    ]) {
      b.insert(
        db.shoes,
        withId(
          (id) => ShoesCompanion.insert(
            id: id,
            createdAt: t,
            updatedAt: t,
            ownerId: userId,
            brand: brand,
            model: model,
          ),
          'shoe $model',
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    b.insert(
      db.benchmarkDefs,
      withId(
        (id) => BenchmarkDefsCompanion.insert(
          id: id,
          createdAt: t,
          updatedAt: t,
          ownerId: Value(userId),
          key: 'max_hang',
          name: 'Max hang',
          protocol: const Value('20 mm edge · 7 s · half crimp'),
          unit: 'pct_bw',
          higherIsBetter: true,
        ),
        'benchmark max hang',
      ),
      mode: InsertMode.insertOrIgnore,
    );
    for (final (date, value) in [
      ('2025-11-10', 118.0),
      ('2026-04-02', 131.0),
      ('2026-10-01', 141.0),
    ]) {
      b.insert(
        db.benchmarkResults,
        withId(
          (id) => BenchmarkResultsCompanion.insert(
            id: id,
            createdAt: t,
            updatedAt: t,
            ownerId: userId,
            visibility: 'friends',
            benchmarkId: exampleId('benchmark max hang'),
            performedOn: date,
            value: value,
          ),
          'result $date',
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    b.insert(
      db.goals,
      withId(
        (id) => GoalsCompanion.insert(
          id: id,
          createdAt: t,
          updatedAt: t,
          ownerId: userId,
          visibility: 'friends',
          kind: 'first',
          target: '{"attribute": "feature.offwidth"}',
          status: 'active',
          sourceGap: const Value('feature.offwidth'),
        ),
        'goal offwidth',
      ),
      mode: InsertMode.insertOrIgnore,
    );
  });
  await db.fillNameKeys();
}

/// Example routes: name → (place, discipline, angle). Ascents take their
/// discipline cache from here, so the two cannot drift apart.
const _routes = {
  'Hjemmebane': ('Kolsås', 'sport', 'angle.vertical'),
  'Skiferdiederet': ('Kolsås', 'trad', 'angle.vertical'),
  'Kveldsløftet': ('Kolsås', 'sport', 'angle.vertical'),
  'Varmen': ('Hanshelleren', 'sport', 'angle.overhang'),
  'Nordlys': ('Hanshelleren', 'sport', 'angle.roof'),
};

/// The example gym's walls: name, kind, height in metres and angle.
const _exampleWalls = [
  ('Cave', 'boulder', 4.5, 'angle.overhang'),
  ('Board', 'boulder', 3.5, 'angle.overhang'),
  ('Slab corner', 'boulder', 4.0, 'angle.slab'),
  ('Main wall', 'rope', 15.0, 'angle.vertical'),
];

/// The example gym's colours, easiest first.
const _exampleColours = [
  ('Green', '#3FA34D'),
  ('Blue', '#2F6FD1'),
  ('Yellow', '#E8C21C'),
  ('Red', '#D33A2C'),
  ('Black', '#1E1E1E'),
];

String _exampleId(String userId, String name) =>
    seedId('example:$userId:$name');

/// The ids [seedExampleData] uses for [userId], for recognising and
/// removing them.
Set<String> exampleIds(String userId) => {
  for (final name in [
    'Kolsås',
    'Flatanger',
    'Hanshelleren',
    'Home gym, Oslo',
    'Hjemmebane',
    'Skiferdiederet',
    'Kveldsløftet',
    'Varmen',
    'Nordlys',
    for (final d in ['2026-09-12', '2026-09-14', '2026-10-17', '2026-10-31'])
      'session $d',
    'ascent 2026-09-12 Varmen',
    'ascent 2026-09-12 Nordlys',
    'ascent 2026-09-14 Nordlys',
    'ascent 2026-10-17 Hjemmebane',
    'ascent 2026-10-17 Kveldsløftet',
    'ascent 2026-10-17 Skiferdiederet',
    'ascent 2026-10-31 Kveldsløftet',
    'ascent 2026-10-31 Hjemmebane',
    'gear Cam #1',
    'gear Cam #2',
    'gear Nuts #1–11',
    'shoe Solution',
    'shoe TC Pro',
    'benchmark max hang',
    for (final d in ['2025-11-10', '2026-04-02', '2026-10-01']) 'result $d',
    'goal offwidth',
    'gym profile',
    for (final (name, _, _, _) in _exampleWalls) 'wall $name',
    for (final (name, _) in _exampleColours) 'colour $name',
  ])
    _exampleId(userId, name),
};

/// Soft-deletes [userId]'s example rows, so a tester can start clean.
Future<void> removeExampleData(SvaDatabase db, {required String userId}) async {
  _debugOnly();
  final ids = exampleIds(userId).toList();
  final now = DateTime.now().toUtc();
  await db.transaction(() async {
    for (final table in db.allTables) {
      if (table.columnsByName['id'] == null) continue;
      await db.customUpdate(
        // Names come from the generated tables, never from input.
        'UPDATE ${table.actualTableName} SET deleted_at = ?, updated_at = ? '
        'WHERE deleted_at IS NULL AND id IN '
        '(${List.filled(ids.length, '?').join(', ')})',
        variables: [
          Variable<DateTime>(now),
          Variable<DateTime>(now),
          for (final id in ids) Variable.withString(id),
        ],
        updates: {table},
        updateKind: UpdateKind.update,
      );
    }
  });
}
