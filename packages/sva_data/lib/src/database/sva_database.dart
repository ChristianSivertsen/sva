import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sva_core/sva_core.dart' show asciiKey, searchKey;
import 'package:sva_data/src/database/tables/personal.dart';
import 'package:sva_data/src/database/tables/places.dart';
import 'package:sva_data/src/database/tables/routes.dart';
import 'package:sva_data/src/database/tables/sessions.dart';
import 'package:sva_data/src/database/tables/users.dart';

part 'sva_database.g.dart';

/// The app's local database. Tables follow docs/schema.md and the
/// PowerSync rules in `tables/conventions.dart`.
///
/// Changing a table: bump [schemaVersion] and add a step to [migration].
/// Then, in `packages/sva_data`, save the new schema with
/// `dart run drift_dev schema dump lib/src/database/sva_database.dart
/// drift_schemas/sva/` and write the test helpers with
/// `dart run drift_dev schema generate drift_schemas/sva/
/// test/generated_migrations/sva/generated/`.
/// `test/database/schema_test.dart` migrates every saved version. Never
/// edit a step that has been merged.
@DriftDatabase(
  tables: [
    Profiles,
    Areas,
    GymProfiles,
    GymWalls,
    GymColourGrades,
    Routes,
    Pitches,
    GradeSystems,
    Grades,
    RouteGrades,
    AttributeDefs,
    RouteAttributes,
    Topos,
    Trips,
    TripMembers,
    ClimbGroups,
    Sessions,
    WeatherSnapshots,
    SessionMembers,
    Ascents,
    AscentBeta,
    AscentPitches,
    AscentAttributes,
    AscentGear,
    Media,
    GearModels,
    GearPieces,
    GearEvents,
    Shoes,
    ShoeResoles,
    TicklistItems,
    Projects,
    Goals,
    BenchmarkDefs,
    BenchmarkResults,
  ],
)
class SvaDatabase extends _$SvaDatabase {
  new(super.e);

  /// A database that lives only in memory, for tests.
  new inMemory() : this(NativeDatabase.memory());

  /// The database in [file], opened on a background isolate so queries
  /// never block the UI.
  new onDevice(File file) : this(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Name search keys for æ, ø and å (M2-1).
        await m.addColumn(areas, areas.searchKey);
        await m.addColumn(areas, areas.asciiKey);
        await m.addColumn(routes, routes.searchKey);
        await m.addColumn(routes, routes.asciiKey);
        await m.createIndex(routeGradesRoute);
        await fillNameKeys();
      }
      // Checks `to` as well, so a test that migrates only to an earlier
      // version gets exactly that schema.
      if (from < 3 && to >= 3) {
        // The app language, chosen in settings (M2-8).
        await m.addColumn(profiles, profiles.language);
      }
      if (from < 4 && to >= 4) {
        // A wall's exact angle in degrees (M3-6).
        await m.addColumn(gymWalls, gymWalls.angleDeg);
      }
    },
  );

  /// Sets the search keys of every place and route that has a name but no
  /// keys yet: rows from before the keys existed, and seed rows. Leaves
  /// `updated_at` alone, since the name itself did not change.
  Future<void> fillNameKeys() => transaction(() async {
    for (final table in ['areas', 'routes']) {
      final rows = await customSelect(
        // The table name is one of the two constants above.
        'SELECT id, name FROM $table '
        'WHERE name IS NOT NULL AND search_key IS NULL',
      ).get();
      for (final row in rows) {
        final name = row.read<String>('name');
        await customStatement(
          'UPDATE $table SET search_key = ?, ascii_key = ? WHERE id = ?',
          [searchKey(name), asciiKey(name), row.read<String>('id')],
        );
      }
    }
  });
}
