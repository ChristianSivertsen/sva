import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sva/src/app.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/logging/gym_tiles.dart';
import 'package:sva/src/logging/here.dart';
import 'package:sva/src/shell/app_shell.dart';
import 'package:sva/src/shell/log_sheet.dart';
import 'package:sva_core/sva_core.dart' show AscentStyle, gradeSystems;
import 'package:sva_data/sva_data.dart';

/// Records the indoor session the log saves. Saving and its checks are
/// tested in sva_data; which taps are one climb, in sva_core.
class _FakeLogger extends SessionLogger {
  new(super.db);

  IndoorSessionDraft? saved;

  @override
  Future<String> logIndoor(
    IndoorSessionDraft draft, {
    required String userId,
  }) async {
    saved = draft;
    return 'session';
  }
}

Area _area(String id, String name, {double? lat, double? lon}) => Area(
  id: id,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  createdBy: localUserId,
  visibility: 'private',
  type: 'gym',
  name: name,
  countryCode: 'NO',
  latitude: lat,
  longitude: lon,
  locationHidden: false,
);

final Area _gym = _area('g1', 'Gnisten');

GymWall _wall(String id, String name, String kind, int sort) => GymWall(
  id: id,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  ownerId: localUserId,
  gymId: 'g1',
  name: name,
  heightM: kind == 'rope' ? 15 : 4.5,
  angle: 'angle.overhang',
  kind: kind,
  sort: sort,
);

GymColourGrade _colour(String id, String name, String hex, int sort) =>
    GymColourGrade(
      id: id,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      ownerId: localUserId,
      gymId: 'g1',
      sort: sort,
      name: name,
      colourHex: hex,
    );

final List<GymWall> _walls = [
  _wall('cave', 'Cave', 'boulder', 0),
  _wall('board', 'Board', 'boulder', 1),
  _wall('main', 'Main wall', 'rope', 2),
];
final List<GymColourGrade> _colours = [
  _colour('green', 'Green', '#3FA34D', 0),
  _colour('blue', 'Blue', '#2F6FD1', 1),
];

void main() {
  late _FakeLogger logger;

  /// Opens the log with [gyms]; the last session was at Gnisten, whose
  /// setup is [grading], [walls] and [colours].
  Future<void> open(
    WidgetTester tester, {
    List<Area>? gyms,
    String grading = 'colour',
    List<GymWall>? walls,
    List<GymColourGrade>? colours,
    LatLon? here,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = SvaDatabase.inMemory();
    addTearDown(db.close);
    logger = _FakeLogger(db);
    final container = ProviderContainer(
      overrides: [
        sessionLoggerProvider.overrideWithValue(logger),
        hereProvider.overrideWith((ref) async => here),
        lastSettingProvider.overrideWith((ref) async => 'indoor'),
        mySessionsProvider.overrideWith(
          (ref) => Stream.value([
            Session(
              id: 'earlier',
              createdAt: DateTime.utc(2026, 11),
              updatedAt: DateTime.utc(2026, 11),
              ownerId: localUserId,
              visibility: 'private',
              setting: 'indoor',
              areaId: 'g1',
              localDate: '2026-11-01',
              tz: 'Europe/Oslo',
              locationHidden: false,
            ),
          ]),
        ),
        settingsProvider.overrideWith((ref) => Stream.value(const Settings())),
        gradeSystemsProvider.overrideWith((ref) async => gradeSystems),
        // Two gyms by default, so the gym picker shows; the last gym
        // logged at is picked.
        gymsProvider.overrideWith(
          (ref) => Stream.value(gyms ?? [_area('g0', 'Another gym'), _gym]),
        ),
        gymSetupProvider.overrideWith(
          (ref, id) async => (
            gym: _gym,
            grading: grading,
            walls: walls ?? _walls,
            colours: colours ?? _colours,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SvaApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(logButtonKey));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(LogSheet), matching: finder);
  Finder tile(String label) => inSheet(
    find.ancestor(of: find.text(label), matching: find.byType(GymTileButton)),
  );
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('M3-4: logging a gym climb takes 3 taps when the wall and '
      'type are already chosen', (tester) async {
    await open(tester);
    // The log button was tap 1.
    await tap(tester, tile('Blue'));
    await tap(tester, inSheet(find.text('Save session')));

    final saved = logger.saved!;
    expect(saved.gymId, 'g1');
    expect(saved.routes.single.wallId, 'cave');
    expect(saved.routes.single.colourId, 'blue');
    final climb = saved.climbs.single;
    expect(
      (climb.route, climb.style, climb.tries, climb.ascentType),
      (0, AscentStyle.flash, 1, 'boulder'),
    );
    expect(find.text('Session saved'), findsOneWidget);
  });

  testWidgets('M3-4: the indoor log shows each tap and saves the session', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);

    // A screen reader can log a climb too, by the tile's label.
    tester.semantics.tap(find.semantics.byLabel('Topped Blue, boulder'));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('Blue: send added')), findsOneWidget);

    // Fell twice on it, then topped it: one climb, a redpoint on try 3.
    await tap(tester, inSheet(find.text("Didn't top")));
    await tap(tester, inSheet(find.byTooltip('More tries')));
    await tap(tester, tile('Blue'));
    expect(inSheet(find.text('Redpoint')), findsWidgets);

    // A green on the board, then undone.
    await tap(
      tester,
      inSheet(find.widgetWithText(FilterChip, 'Board · 4.5 m · Overhang')),
    );
    await tap(tester, tile('Green'));
    await tap(tester, inSheet(find.text('Undo')));

    // A blue on the main wall on top rope; the gym is now locked.
    await tap(tester, inSheet(find.text('Rope')));
    await tap(tester, tile('Blue'));
    await tap(tester, inSheet(find.widgetWithText(FilterChip, 'Top rope')));
    expect(
      tester
          .widget<FilterChip>(
            inSheet(find.widgetWithText(FilterChip, 'Another gym')),
          )
          .onSelected,
      isNull,
    );
    expect(inSheet(find.text('This session · 3 climbs')), findsOneWidget);
    await tap(tester, inSheet(find.text('Save session (3 climbs)')));

    final saved = logger.saved!;
    expect(
      [for (final r in saved.routes) (r.wallId, r.colourId)],
      [('cave', 'blue'), ('main', 'blue')],
    );
    expect(
      [for (final c in saved.climbs) (c.route, c.style, c.tries, c.ascentType)],
      [
        (0, AscentStyle.attempt, 2, 'boulder'),
        (0, AscentStyle.redpoint, 3, 'boulder'),
        (1, AscentStyle.flash, 1, 'toprope'),
      ],
    );
    semantics.dispose();
  });

  testWidgets('M3-4: a rope-only gym logs rope climbs', (tester) async {
    await open(tester, walls: [_wall('main', 'Main wall', 'rope', 0)]);
    // No boulder or rope choice to make: only rope walls.
    expect(inSheet(find.byType(SegmentedButton<String>)), findsNothing);
    await tap(tester, tile('Green'));
    expect(inSheet(find.widgetWithText(FilterChip, 'Lead')), findsOneWidget);
    await tap(tester, inSheet(find.text('Save session')));
    expect(logger.saved!.climbs.single.ascentType, 'lead');
  });

  testWidgets('M3-4: a graded gym has a tile for each grade', (tester) async {
    await open(tester, grading: 'standard');
    // Font grades, the boulder system in settings.
    await tap(tester, tile('6A'));
    await tap(tester, inSheet(find.text('Save session')));
    expect(logger.saved!.routes.single.gradeId, seedId('grade:font:6A'));
    expect(logger.saved!.routes.single.colourId, isNull);
  });

  testWidgets('M3-4: an ungraded gym has one tile', (tester) async {
    await open(tester, grading: 'none');
    await tap(tester, tile('Climb'));
    await tap(tester, inSheet(find.text('Save session')));
    final route = logger.saved!.routes.single;
    expect((route.colourId, route.gradeId), (null, null));
  });

  testWidgets('M3-4: the indoor log says what is missing', (tester) async {
    await open(tester, colours: const []);
    expect(inSheet(find.textContaining('Nothing to tap yet.')), findsOneWidget);
  });

  testWidgets('M3-4: the indoor log asks for a gym with walls', (tester) async {
    await open(tester, walls: const []);
    expect(
      inSheet(
        find.text(
          'This gym has no walls yet. Add them in Settings, under Gyms.',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('M3-4: without a gym the indoor log offers to add one', (
    tester,
  ) async {
    await open(tester, gyms: const []);
    expect(
      inSheet(find.text('Set up your gym first: its walls and colours.')),
      findsOneWidget,
    );
    expect(inSheet(find.text('Add a gym')), findsOneWidget);
  });

  testWidgets('M3-4: the log opens on the gym you are at', (tester) async {
    // Another gym is in Oslo; Gnisten, where you logged last, is in Alta.
    final gyms = [
      _area('g0', 'Another gym', lat: 59.9330, lon: 10.7660),
      _area('g1', 'Gnisten', lat: 69.9689, lon: 23.2716),
    ];
    bool picked(String name) => tester
        .widget<FilterChip>(inSheet(find.widgetWithText(FilterChip, name)))
        .selected;

    await open(tester, gyms: gyms, here: (lat: 59.9350, lon: 10.7700));
    expect(picked('Another gym'), isTrue);
    expect(inSheet(find.text('Found from your location')), findsOneWidget);
  });

  testWidgets('M3-4: away from every gym the log opens on your last gym', (
    tester,
  ) async {
    final gyms = [
      _area('g0', 'Another gym', lat: 59.9330, lon: 10.7660),
      _area('g1', 'Gnisten', lat: 69.9689, lon: 23.2716),
    ];
    await open(tester, gyms: gyms, here: (lat: 63.43, lon: 10.39));
    expect(
      tester
          .widget<FilterChip>(
            inSheet(find.widgetWithText(FilterChip, 'Gnisten')),
          )
          .selected,
      isTrue,
    );
    expect(inSheet(find.text('Found from your location')), findsNothing);
  });
}
