import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sva/src/app.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/shell/app_shell.dart';
import 'package:sva/src/shell/log_sheet.dart';
import 'package:sva_core/sva_core.dart' show AscentStyle, gradeSystems;
import 'package:sva_data/sva_data.dart';

/// Records the indoor session the log saves. Saving and its checks are
/// tested in sva_data.
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

final _gym = Area(
  id: 'g1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  createdBy: localUserId,
  visibility: 'private',
  type: 'gym',
  name: 'Gnisten',
  countryCode: 'NO',
  locationHidden: false,
);

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

void main() {
  late _FakeLogger logger;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = SvaDatabase.inMemory();
    addTearDown(db.close);
    logger = _FakeLogger(db);
    final container = ProviderContainer(
      overrides: [
        sessionLoggerProvider.overrideWithValue(logger),
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
        // Two gyms, so the gym picker shows; the last gym logged at is
        // picked.
        gymsProvider.overrideWith(
          (ref) => Stream.value([
            Area(
              id: 'g0',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              createdBy: localUserId,
              visibility: 'private',
              type: 'gym',
              name: 'Another gym',
              countryCode: 'NO',
              locationHidden: false,
            ),
            _gym,
          ]),
        ),
        gymSetupProvider.overrideWith(
          (ref, id) async => (
            gym: _gym,
            grading: 'colour',
            walls: [
              _wall('cave', 'Cave', 'boulder', 0),
              _wall('board', 'Board', 'boulder', 1),
              _wall('main', 'Main wall', 'rope', 2),
            ],
            colours: [
              _colour('green', 'Green', '#3FA34D', 0),
              _colour('blue', 'Blue', '#2F6FD1', 1),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SvaApp()),
    );
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(LogSheet), matching: finder);

  testWidgets('M3-4: logging a gym climb takes 3 taps when the wall and '
      'type are already chosen', (tester) async {
    await open(tester);
    var taps = 0;
    Future<void> tap(Finder target) async {
      taps++;
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap(find.byKey(logButtonKey));
    await tap(inSheet(find.bySemanticsLabel('Topped a Blue on Boulder')));
    await tap(inSheet(find.text('Save session')));

    expect(taps, 3);
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

  testWidgets('M3-4: the indoor log works out each climb from the taps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await tester.tap(find.byKey(logButtonKey));
    await tester.pumpAndSettle();
    Future<void> tap(Finder target) async {
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    // A blue in the cave: fell twice, then topped it. The second tap on
    // blue is the same climb, a redpoint on try 3.
    await tap(inSheet(find.bySemanticsLabel('Topped a Blue on Boulder')));
    await tap(inSheet(find.text("Didn't top")));
    await tap(inSheet(find.byTooltip('More tries')));
    await tap(inSheet(find.bySemanticsLabel('Topped a Blue on Boulder')));
    expect(inSheet(find.text('Redpoint')), findsWidgets);

    // A green on the board, then undone.
    await tap(
      inSheet(find.widgetWithText(FilterChip, 'Board · 4.5 m · Overhang')),
    );
    await tap(inSheet(find.bySemanticsLabel('Topped a Green on Boulder')));
    await tap(inSheet(find.text('Undo')));

    // A blue on the main wall on top rope.
    await tap(inSheet(find.text('Rope')));
    await tap(inSheet(find.bySemanticsLabel('Topped a Blue on Rope')));
    await tap(inSheet(find.widgetWithText(FilterChip, 'Top rope')));
    expect(inSheet(find.text('This session · 3 climbs')), findsOneWidget);
    await tap(inSheet(find.text('Save session (3 climbs)')));

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
}
