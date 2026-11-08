import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/app.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/logging/indoor_log.dart';
import 'package:sva/src/shell/app_shell.dart';
import 'package:sva_core/sva_core.dart';
import 'package:sva_data/sva_data.dart';

/// Counts weather look-ups instead of calling Open-Meteo.
class _FakeWeather extends WeatherFiller {
  new(SvaDatabase db) : super(db, OpenMeteo());

  int runs = 0;

  @override
  Future<int> fillMissing({required String userId}) async {
    runs++;
    return 0;
  }
}

/// Records what the sheet saves. Saving and the rules themselves are
/// tested in sva_data and sva_core.
class _FakeLogger extends SessionLogger {
  new(super.db);

  SessionDraft? saved;

  @override
  Future<String> logOutdoor(
    SessionDraft draft, {
    required String userId,
  }) async {
    saved = draft;
    return 'session';
  }
}

RouteHit _hit(String id, String name, {String discipline = 'sport'}) => (
  route: Route(
    id: id,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    visibility: 'public',
    areaId: 'kolsas',
    kind: 'outdoor',
    name: name,
    discipline: discipline,
    pitchCount: 1,
    status: 'open',
  ),
  grade: '7-',
  gradeSystem: 'nor',
  crag: 'Kolsås',
  lastClimbed: null,
  distanceKm: null,
  location: (lat: 59.92, lon: 10.5),
);

void main() {
  late _FakeLogger logger;
  late _FakeWeather weather;

  /// Opens the app with faked data. [log] is what each route's history
  /// holds; [lastSetting] is the last session's setting.
  Future<void> start(
    WidgetTester tester, {
    Map<String, List<LoggedAscent>> log = const {},
    String? lastSetting,
    Settings settings = const Settings(),
  }) async {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = SvaDatabase.inMemory();
    logger = _FakeLogger(db);
    weather = _FakeWeather(db);
    final container = ProviderContainer(
      overrides: [
        sessionLoggerProvider.overrideWithValue(logger),
        weatherFillerProvider.overrideWithValue(weather),
        lastSettingProvider.overrideWith((ref) async => lastSetting),
        routeSearchProvider.overrideWith(
          (ref, term) => Stream.value([
            _hit('r1', 'Hjemmebane'),
            _hit('b1', 'Steinen', discipline: 'boulder'),
          ]),
        ),
        routeLogProvider.overrideWith((ref, id) async => [...?log[id]]),
        gradeSystemsProvider.overrideWith((ref) async => gradeSystems),
        mySessionsProvider.overrideWith((ref) => Stream.value(const [])),
        settingsProvider.overrideWith((ref) => Stream.value(settings)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SvaApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('M2-3: logging a known route takes at most 5 taps', (
    tester,
  ) async {
    await start(tester);
    var taps = 0;
    Future<void> tap(Finder target) async {
      taps++;
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap(find.byKey(logButtonKey));
    await tap(find.text('Hjemmebane'));
    await tap(find.text('Onsight'));
    await tap(find.text('Save session'));

    expect(taps, lessThanOrEqualTo(5));
    final climb = logger.saved!.climbs.single;
    expect(climb.routeId, 'r1');
    expect(climb.style, AscentStyle.onsight);
    expect(climb.tries, 1);
    expect(climb.ascentType, 'lead');
    expect(find.text('Session saved'), findsOneWidget);
  });

  testWidgets('M2-8: a new session gets the visibility chosen in settings', (
    tester,
  ) async {
    await start(tester, settings: const Settings(defaultVisibility: 'friends'));
    await tester.tap(find.byKey(logButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hjemmebane'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onsight'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save session'));
    await tester.pumpAndSettle();
    expect(logger.saved!.visibility, 'friends');
  });

  testWidgets('M2-3: the sheet opens on the last indoor or outdoor choice', (
    tester,
  ) async {
    await start(tester, lastSetting: 'indoor');
    await tester.tap(find.byKey(logButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(IndoorLog), findsOneWidget);
    expect(find.text('Save session'), findsNothing);

    await tester.tap(find.text('Outdoor'));
    await tester.pumpAndSettle();
    expect(find.text('Hjemmebane'), findsOneWidget);
  });

  testWidgets('M2-3: locked styles are struck through with a hint', (
    tester,
  ) async {
    await start(
      tester,
      log: {
        'r1': [(style: AscentStyle.attempt, tries: 2)],
      },
    );
    await tester.tap(find.byKey(logButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hjemmebane'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'You have 2 earlier tries on this route, so onsight and flash are '
        'not possible.',
      ),
      findsOneWidget,
    );
    FilterChip chip(String label) => tester.widget<FilterChip>(
      find.ancestor(of: find.text(label), matching: find.byType(FilterChip)),
    );
    expect(chip('Onsight').onSelected, isNull);
    expect(chip('Flash').onSelected, isNull);
    expect(chip('Repeat').onSelected, isNull, reason: 'not sent yet');

    // A redpoint starts at 3 tries: the 2 before and the send.
    await tester.tap(find.text('Redpoint'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    final fewer = find.ancestor(
      of: find.byTooltip('Fewer tries'),
      matching: find.byType(IconButton),
    );
    expect(
      tester.widget<IconButton>(fewer.first).onPressed,
      isNull,
      reason: 'no fewer than the rules allow',
    );

    // A boulder is never onsighted, so it has no onsight chip.
    await tester.tap(find.text('Change route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Steinen'));
    await tester.pumpAndSettle();
    expect(find.text('Onsight'), findsNothing);
    expect(find.text('Boulders are flashed, not onsighted.'), findsOneWidget);
  });

  testWidgets('M2-3: several climbs are added before the session is saved', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.byKey(logButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hjemmebane'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attempt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add climb and log another'));
    await tester.pumpAndSettle();

    // The attempt in this session counts: no onsight on the second go.
    await tester.tap(find.text('Hjemmebane').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 earlier try'), findsOneWidget);
    await tester.tap(find.text('Redpoint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add climb and log another'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Steinen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flash'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Kveld på Kolsås',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Partners'),
      'Kari, Ola',
    );
    await tester.tap(find.text('Save session (3 climbs)'));
    await tester.pumpAndSettle();

    final saved = logger.saved!;
    expect(saved.title, 'Kveld på Kolsås');
    expect(saved.partners.map((p) => p.trim()), ['Kari', 'Ola']);
    expect(saved.climbs.map((c) => (c.routeId, c.style, c.tries)), [
      ('r1', AscentStyle.attempt, 1),
      ('r1', AscentStyle.redpoint, 2),
      ('b1', AscentStyle.flash, 1),
    ]);
    expect(saved.climbs.last.ascentType, 'boulder');
  });

  testWidgets('M2-3: removing a climb rechecks the later ones', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(logButtonKey));
    await tester.pumpAndSettle();
    for (final style in ['Flash', 'Repeat']) {
      await tester.tap(find.text('Hjemmebane').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(style));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add climb and log another'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Hjemmebane · Repeat'), findsOneWidget);

    // Without the flash, the repeat has no send to repeat.
    await tester.tap(find.byTooltip('Remove Hjemmebane').first);
    await tester.pumpAndSettle();
    expect(find.text('Hjemmebane · Flash'), findsNothing);
    expect(find.text('Hjemmebane · Repeat'), findsNothing);
    expect(find.textContaining('were removed too'), findsOneWidget);
  });

  testWidgets("M2-5: the sheet names the season from the date and the crag's "
      'hemisphere', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(logButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hjemmebane'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onsight'));
    await tester.pumpAndSettle();
    // The route is at Kolsås, in the north, and the date is today.
    final season = seasonOf(DateTime.now(), latitude: 59.92).name;
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.textContaining(' · ${l10n.season(season)}'), findsOneWidget);

    await tester.tap(find.text('Save session'));
    await tester.pumpAndSettle();
    expect(weather.runs, 1, reason: 'weather is looked up after saving');
  });
}
