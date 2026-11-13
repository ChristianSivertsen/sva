import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:sva_data/sva_data.dart';
import 'package:test/test.dart';

import '../generated_migrations/sva/generated/schema.dart';

/// Every table in docs/schema.md that lives on the device. Server-only
/// tables (device tokens, suggested edits, social) are not here.
const _tables = {
  'profiles',
  'areas',
  'gym_profiles',
  'gym_walls',
  'gym_colour_grades',
  'routes',
  'pitches',
  'grade_systems',
  'grades',
  'route_grades',
  'attribute_defs',
  'route_attributes',
  'topos',
  'trips',
  'trip_members',
  'climb_groups',
  'sessions',
  'weather_snapshots',
  'session_members',
  'ascents',
  'ascent_beta',
  'ascent_pitches',
  'ascent_attributes',
  'ascent_gear',
  'media',
  'gear_models',
  'gear_pieces',
  'gear_events',
  'shoes',
  'shoe_resoles',
  'ticklist_items',
  'projects',
  'goals',
  'benchmark_defs',
  'benchmark_results',
};

/// Tables in the shared database: no owner, a `created_by` instead.
const _shared = {
  'areas',
  'gym_profiles',
  'routes',
  'pitches',
  'grade_systems',
  'grades',
  'route_grades',
  'attribute_defs',
  'route_attributes',
  'topos',
  'gear_models',
};

void main() {
  group('a new database', newDatabaseTests);

  test('M2-1: upgrading to version 2 fills in name search keys', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      'INSERT INTO areas (id, created_at, updated_at, created_by, '
      'visibility, type, name, country_code, location_hidden) '
      "VALUES ('a', '2026', '2026', 'me', 'private', 'crag', 'Fløyen', "
      "'NO', 0)",
    );
    final db = SvaDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    final row = await db.customSelect('SELECT * FROM areas').getSingle();
    expect(row.read<String>('search_key'), 'fløyen');
    expect(row.read<String>('ascii_key'), 'floyen');
    expect(row.read<String>('updated_at'), '2026', reason: 'not an edit');
    await db.close();
  });

  test('M3-6: walls from before degrees keep working without them', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      'INSERT INTO gym_walls (id, created_at, updated_at, owner_id, gym_id, '
      'name, angle, kind, sort) '
      "VALUES ('w', '2026-11-01T10:00:00Z', '2026-11-01T10:00:00Z', 'me', "
      "'g', 'Cave', 'angle.overhang', "
      "'boulder', 0)",
    );
    final db = SvaDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    final wall = await db.select(db.gymWalls).getSingle();
    expect(
      (wall.name, wall.angle, wall.angleDeg),
      ('Cave', 'angle.overhang', null),
    );
    await db.close();
  });

  test(
    'M1-1: migration from every earlier version to the latest works',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      for (final version in GeneratedHelper.versions) {
        final connection = await verifier.startAt(version);
        final migrated = SvaDatabase(connection);
        await verifier.migrateAndValidate(migrated, migrated.schemaVersion);
        await migrated.close();
      }
    },
  );
}

void newDatabaseTests() {
  late SvaDatabase db;

  setUp(() => db = SvaDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<QueryRow>> query(String sql) => db.customSelect(sql).get();

  Future<Map<String, String>> columnsOf(String table) async => {
    for (final row in await query('PRAGMA table_info($table)'))
      row.read<String>('name'): row.read<String>('type'),
  };

  test('M1-1: migrations create every table from an empty database', () async {
    final rows = await query(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%'",
    );
    expect(rows.map((row) => row.read<String>('name')).toSet(), _tables);
  });

  test('M1-1: every table follows the sync conventions', () async {
    for (final table in _tables) {
      final columns = await columnsOf(table);
      expect(
        columns,
        containsPair('id', 'TEXT'),
        reason: '$table needs a text id',
      );
      for (final column in ['created_at', 'updated_at', 'deleted_at']) {
        expect(columns, containsPair(column, 'TEXT'), reason: table);
      }
      if (_shared.contains(table)) {
        expect(columns, contains('created_by'), reason: table);
        expect(columns, isNot(contains('owner_id')), reason: table);
      } else if (table != 'profiles') {
        // Profiles are owned by their own id.
        expect(columns, contains('owner_id'), reason: table);
      }

      // PowerSync stores only these types and has no keys or constraints.
      expect(
        columns.values.toSet().difference({'TEXT', 'INTEGER', 'REAL'}),
        isEmpty,
        reason: table,
      );
      final pk = await query(
        "SELECT name FROM pragma_table_info('$table') WHERE pk > 0",
      );
      expect(pk.map((row) => row.read<String>('name')), ['id'], reason: table);
      expect(
        await query('PRAGMA foreign_key_list($table)'),
        isEmpty,
        reason: table,
      );
      final sql = (await query(
        "SELECT sql FROM sqlite_master WHERE name = '$table'",
      )).single.read<String>('sql');
      // drift adds `CHECK (x IN (0, 1))` to booleans. That is harmless
      // under PowerSync, which stores the same 0 and 1; any other check
      // would be a rule the synced tables silently lose.
      final checks = sql.replaceAll(RegExp(r'CHECK \("\w+" IN \(0, 1\)\)'), '');
      expect(checks, isNot(contains('CHECK')), reason: table);
      // PowerSync's views ignore SQL defaults; defaults are set in Dart.
      expect(sql, isNot(contains('DEFAULT')), reason: table);
      final unique = await query(
        "SELECT name FROM pragma_index_list('$table') "
        "WHERE \"unique\" = 1 AND origin != 'pk'",
      );
      expect(unique, isEmpty, reason: '$table has a unique index');
    }
  });
}
