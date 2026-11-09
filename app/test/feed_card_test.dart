import 'package:flutter/material.dart' hide Route;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sva/src/app.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/feed/feed_card.dart';
import 'package:sva/src/sessions/session_screen.dart';
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

Session _session(
  String id,
  String day, {
  String? title,
  String? description,
  int? elevationGainM,
}) => Session(
  id: id,
  createdAt: DateTime.utc(2026, 11),
  updatedAt: DateTime.utc(2026, 11),
  ownerId: localUserId,
  visibility: 'private',
  setting: 'outdoor',
  localDate: day,
  tz: 'Europe/Oslo',
  locationHidden: false,
  title: title,
  description: description,
  elevationGainM: elevationGainM,
);

Ascent _climb(String sessionId, int ordinal, String routeId, String style) =>
    Ascent(
      id: '$sessionId-$ordinal',
      createdAt: DateTime.utc(2026, 11),
      updatedAt: DateTime.utc(2026, 11),
      ownerId: localUserId,
      visibility: 'private',
      sessionId: sessionId,
      routeId: routeId,
      ordinal: ordinal,
      ascentType: 'lead',
      style: style,
      tries: 1,
      setting: 'outdoor',
      discipline: 'sport',
    );

RouteHit _hit(
  String id,
  String name, {
  int pitches = 1,
  double? lengthM,
  String discipline = 'sport',
}) => (
  route: Route(
    id: id,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    visibility: 'public',
    areaId: 'kolsas',
    kind: 'outdoor',
    name: name,
    discipline: discipline,
    pitchCount: pitches,
    lengthM: lengthM,
    status: 'open',
  ),
  grade: '6+',
  gradeSystem: 'nor',
  crag: 'Kolsås',
  lastClimbed: null,
  distanceKm: null,
  location: null,
);

Future<ProviderContainer> _start(
  WidgetTester tester, {
  required Stream<List<Session>> Function(int limit) sessions,
  Map<String, List<Ascent>> climbs = const {},
  Map<String, RouteHit> hits = const {},
  Map<String, List<String>> partners = const {},
  Map<String, List<String>> tags = const {},
  Map<String, GymRouteLabel> gymRoutes = const {},
}) async {
  final container = ProviderContainer(
    overrides: [
      feedSessionsProvider.overrideWith((ref, limit) => sessions(limit)),
      sessionAscentsProvider.overrideWith(
        (ref, id) => Stream.value(climbs[id] ?? const []),
      ),
      routeHitProvider.overrideWith((ref, id) async => hits[id]),
      sessionPartnersProvider.overrideWith(
        (ref, id) => Stream.value(partners[id] ?? const []),
      ),
      sessionWeatherProvider.overrideWith((ref, id) => Stream.value(null)),
      sessionTagsProvider.overrideWith((ref, id) async => tags[id] ?? []),
      sessionProvider.overrideWith((ref, id) => Stream.value(null)),
      gymRouteLabelProvider.overrideWith((ref, id) async => gymRoutes[id]),
      placeNameProvider.overrideWith(
        (ref, id) async => id == 'g1' ? 'Gnisten' : null,
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const SvaApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets("M2-7: a feed card lays out the session like the prototype's "
      'post', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final full = _session(
      's1',
      '2026-10-17',
      title: 'After-work laps',
      description: 'Dry rock after a week of rain.',
      elevationGainM: 1240,
    );
    final partial = _session('s2', '2026-10-01');
    await _start(
      tester,
      sessions: (limit) => Stream.value([full, partial]),
      climbs: {
        's1': [
          _climb('s1', 1, 'multi', 'flash'),
          for (var i = 2; i <= 7; i++) _climb('s1', i, 'r$i', 'attempt'),
        ],
        's2': [
          _climb('s2', 1, 'multi', 'redpoint'),
          _climb('s2', 2, 'x', 'repeat'),
        ],
      },
      hits: {
        'multi': _hit('multi', 'Kveldsløftet', pitches: 3, lengthM: 90),
        for (var i = 2; i <= 7; i++)
          'r$i': _hit('r$i', 'Route $i', lengthM: 20),
        'x': _hit('x', 'Unmeasured'),
      },
      partners: {
        's1': ['Kari', 'Ola'],
      },
      tags: {
        's1': [
          'feature.face',
          'unknown.key',
          'hold.crimp',
          'tag.pumpy',
          'feature.corner',
          'hold.jug',
          'tag.techy',
          'tag.scary',
        ],
      },
    );

    final first = find.byType(FeedCard).first;
    Finder inFirst(String text) =>
        find.descendant(of: first, matching: find.text(text));
    expect(inFirst('Kolsås'), findsOneWidget);
    expect(inFirst('17 Oct 2026 · with Kari, Ola'), findsOneWidget);
    expect(inFirst('After-work laps'), findsOneWidget);
    expect(inFirst('Dry rock after a week of rain.'), findsOneWidget);
    // Six climbs, with style and grade, then how many more.
    expect(
      find.descendant(
        of: first,
        matching: find.textContaining('Kveldsløftet  Sport · 3 pitches'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: first, matching: find.textContaining('Route 6')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: first, matching: find.textContaining('Route 7')),
      findsNothing,
    );
    expect(inFirst('+1 more climb'), findsOneWidget);
    expect(inFirst('Flash'), findsOneWidget);
    expect(inFirst('Attempt'), findsNWidgets(5));
    expect(
      find.descendant(of: first, matching: find.byType(SvaGradeBadge)),
      findsNWidgets(6),
    );
    // The first six tags the app has words for.
    for (final tag in ['Face', 'Crimps', 'Pumpy', 'Corner', 'Jugs']) {
      expect(inFirst(tag), findsOneWidget);
    }
    expect(inFirst('Technical'), findsOneWidget);
    expect(inFirst('Scary'), findsNothing);
    expect(
      find.descendant(of: first, matching: find.byType(SvaTag)),
      findsNWidgets(6),
    );
    // The totals come from the routes' pitches and lengths (the sums
    // themselves are tested in sva_core).
    expect(inFirst('Pitches'), findsOneWidget);
    expect(
      find.descendant(
        of: first,
        matching: find.text('210 m', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(inFirst('Climbed'), findsOneWidget);
    expect(
      find.descendant(
        of: first,
        matching: find.text('1,240 m', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(inFirst('Elevation gain'), findsOneWidget);

    // Without a title, partners or all lengths, those parts are left out.
    final second = find.byType(FeedCard).last;
    Finder inSecond(String text) =>
        find.descendant(of: second, matching: find.text(text));
    expect(inSecond('1 Oct 2026'), findsOneWidget);
    expect(inSecond('Pitches'), findsOneWidget);
    expect(inSecond('Climbed'), findsNothing, reason: 'a length is unknown');
    expect(inSecond('Elevation gain'), findsNothing);

    await tester.tap(inFirst('After-work laps'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionScreen), findsOneWidget);
  });

  testWidgets('M2-7: a feed card reads out and wraps at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    await _start(
      tester,
      sessions: (limit) => Stream.value([
        _session(
          's1',
          '2026-10-17',
          title: 'After-work laps',
          elevationGainM: 1240,
        ),
      ]),
      climbs: {
        's1': [_climb('s1', 1, 'multi', 'flash')],
      },
      hits: {
        'multi': _hit(
          'multi',
          'Kveldsløftet med den lange avslutningen',
          pitches: 3,
          lengthM: 90,
        ),
      },
    );

    // Nothing overflows, and the climb's name is not cut short.
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Kveldsløftet med den lange avslutningen'),
      findsOneWidget,
    );
    final name = tester.renderObject<RenderParagraph>(
      find.textContaining('Kveldsløftet med den lange avslutningen'),
    );
    expect(name.didExceedMaxLines, isFalse);
    // The card opens the session, and edit is its own button.
    expect(find.bySemanticsLabel(RegExp('^Open session')), findsOneWidget);
    expect(
      tester.getSemantics(find.byTooltip('Edit session')),
      matchesSemantics(
        tooltip: 'Edit session',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('M2-7: the feed shows the newest sessions first and loads more '
      'at the end', (tester) async {
    // Newest first, as the repository sorts them.
    final all = [
      for (var i = 0; i < 45; i++)
        _session(
          's$i',
          DateTime.utc(
            2026,
            10,
            31,
          ).subtract(Duration(days: i)).toIso8601String().substring(0, 10),
          title: 'Session $i',
        ),
    ];
    final limits = <int>[];
    await _start(
      tester,
      sessions: (limit) {
        limits.add(limit);
        return Stream.value(all.take(limit).toList());
      },
    );

    final titles = find.descendant(
      of: find.byType(FeedCard),
      matching: find.textContaining('Session '),
    );
    expect((titles.evaluate().first.widget as Text).data, 'Session 0');
    expect(limits, [20]);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Session 19'),
      300,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    expect(limits, [20, 40]);
    await tester.scrollUntilVisible(
      find.text('Session 44'),
      300,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    expect(limits, [20, 40, 60]);
    // The last page was short, so there is nothing more to ask for.
    await tester.drag(list, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(limits, [20, 40, 60]);
  });

  testWidgets('M3-4: a gym session card shows the gym and its climbs', (
    tester,
  ) async {
    final session = Session(
      id: 'gym',
      createdAt: DateTime.utc(2026, 11),
      updatedAt: DateTime.utc(2026, 11),
      ownerId: localUserId,
      visibility: 'private',
      setting: 'indoor',
      areaId: 'g1',
      localDate: '2026-11-05',
      tz: 'Europe/Oslo',
      locationHidden: false,
    );
    Ascent climb(int ordinal, String routeId) => _climb(
      'gym',
      ordinal,
      routeId,
      'flash',
    ).copyWith(setting: 'indoor', discipline: 'boulder');
    await _start(
      tester,
      sessions: (limit) => Stream.value([session]),
      climbs: {
        'gym': [climb(1, 'blue'), climb(2, 'graded')],
      },
      gymRoutes: {
        'blue': (colour: 'Blue', grade: null, gradeSystem: null, wall: 'Cave'),
        'graded': (
          colour: null,
          grade: '6A',
          gradeSystem: 'font',
          wall: 'Board',
        ),
      },
    );
    final card = find.byType(FeedCard);
    Finder inCard(Finder f) => find.descendant(of: card, matching: f);
    expect(inCard(find.text('Gnisten')), findsOneWidget);
    // A colour climb is its colour on its wall; a graded one is its wall,
    // with the grade as a badge.
    expect(
      inCard(find.textContaining('Blue  Cave', findRichText: true)),
      findsOneWidget,
    );
    expect(
      inCard(find.textContaining('Board', findRichText: true)),
      findsOneWidget,
    );
    expect(inCard(find.text('6A')), findsOneWidget);
  });
}
