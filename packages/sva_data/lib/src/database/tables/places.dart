import 'package:drift/drift.dart';
import 'package:sva_data/src/database/tables/conventions.dart';

/// One tree for every place, from country to boulder block or gym
/// (docs/schema.md §2).
@TableIndex(name: 'areas_parent', columns: {#parentId})
@TableIndex(name: 'areas_country', columns: {#countryCode})
class Areas extends Table with SyncedRow, SharedRow, Visible, NameKeys {
  TextColumn get parentId => text().nullable()();

  /// `country`, `region`, `area`, `crag`, `sector`, `wall`,
  /// `boulder_block`, `gym`.
  TextColumn get type => text()();
  TextColumn get name => text()();

  /// ISO 3166-1 alpha-2, set on every row for fast filtering.
  TextColumn get countryCode => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get altitudeM => integer().nullable()();
  TextColumn get rockType => text().nullable()();
  TextColumn get aspect => text().nullable()();
  IntColumn get approachMin => integer().nullable()();
  BoolColumn get locationHidden => boolean().clientDefault(() => false)();
  TextColumn get accessNotes => text().nullable()();
  TextColumn get mergedIntoId => text().nullable()();
}

/// Extra settings for areas of type `gym`.
class GymProfiles extends Table with SyncedRow, SharedRow {
  TextColumn get areaId => text()();

  /// `colour`, `standard`, `none`.
  TextColumn get grading => text()();
  IntColumn get routeExpiryWeeks => integer().nullable()();
}

/// Personal for now, like gym routes.
class GymWalls extends Table with SyncedRow, OwnedRow {
  TextColumn get gymId => text()();
  TextColumn get name => text()();
  RealColumn get heightM => real().nullable()();
  TextColumn get angle => text().nullable()();

  /// Degrees past vertical, negative for slabs (M3-6). When set, [angle]
  /// follows from it.
  IntColumn get angleDeg => integer().nullable()();

  /// `rope` or `boulder`.
  TextColumn get kind => text()();

  /// `YYYY-MM-DD`.
  TextColumn get lastResetOn => text().nullable()();
  IntColumn get sort => integer().clientDefault(() => 0)();
}

/// One row per colour in a gym's grading, easiest first. Personal for
/// now, like gym walls.
class GymColourGrades extends Table with SyncedRow, OwnedRow {
  TextColumn get gymId => text()();
  IntColumn get sort => integer()();
  TextColumn get name => text()();
  TextColumn get colourHex => text()();
  RealColumn get boulderMinScore => real().nullable()();
  RealColumn get boulderMaxScore => real().nullable()();
  RealColumn get routeMinScore => real().nullable()();
  RealColumn get routeMaxScore => real().nullable()();
}
