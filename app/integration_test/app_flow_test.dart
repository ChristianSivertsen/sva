import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/main.dart' as app;
import 'package:sva/src/feed/feed_card.dart';
import 'package:sva/src/logging/gym_tiles.dart';
import 'package:sva/src/places/labels.dart';
import 'package:sva/src/places/route_search_screen.dart';
import 'package:sva/src/sessions/session_screen.dart';
import 'package:sva/src/shell/app_shell.dart';
import 'package:sva/src/shell/log_sheet.dart';
import 'package:sva/src/shell/tab_screens.dart';
import 'package:sva_ui/sva_ui.dart';

/// Flows: journeys across screens on a real device or emulator. See
/// docs/TESTING.md, layer 5. Texts come from the app's translations, so
/// flows pass whatever language the device uses. Taps go through the same
/// labels screen readers use, so a flow also breaks if a tab loses its label.
/// Debug builds start with the example data (M1-5).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M0-8: app starts and every tab can be opened', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AppShell)));
    expect(find.byType(FeedScreen), findsOneWidget);

    final tabs = {
      l10n.tabHistory: HistoryScreen,
      l10n.tabCv: CvScreen,
      l10n.tabTraining: TrainingScreen,
      l10n.tabFeed: FeedScreen,
    };
    for (final MapEntry(key: tab, value: screen) in tabs.entries) {
      await tester.tap(find.bySemanticsLabel(tab));
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget, reason: tab);
    }
  });

  testWidgets('M2-3: log an outdoor session with two climbs, see it in the '
      'feed', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AppShell)));
    final title = 'Flow ${DateTime.now().millisecondsSinceEpoch}';

    final (:inSheet, :reveal, :tap) = _sheetHelpers(tester);

    await tap(find.byKey(logButtonKey));
    await tap(inSheet(find.text(l10n.logOutdoor)));
    // Attempts are always allowed, whatever the example history holds.
    for (var i = 0; i < 2; i++) {
      await tap(
        inSheet(
          find.descendant(
            of: find.byType(RouteHitTile),
            matching: find.text('Hjemmebane'),
          ),
        ),
      );
      await tap(inSheet(find.text(l10n.ascentStyle('attempt'))));
      if (i == 0) await tap(inSheet(find.text(l10n.logAddClimb)));
    }
    final titleField = inSheet(find.widgetWithText(TextField, l10n.logTitle));
    await reveal(titleField);
    await tester.enterText(titleField, title);
    await tester.pumpAndSettle();
    await tap(inSheet(find.text(l10n.logSave(2))));

    expect(find.byType(FeedScreen), findsOneWidget);
    expect(find.text(title), findsOneWidget);
  });

  testWidgets('M2-6: edit a past session to add a forgotten climb', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AppShell)));
    final (:inSheet, :reveal, :tap) = _sheetHelpers(tester);

    // An example session from October. Its feed card lists its climbs,
    // each with a style tag; cards build lazily, so scroll to it first.
    final day = formatDay(l10n, '2026-10-17');
    final feed = find
        .descendant(
          of: find.byType(FeedScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    final card = find.ancestor(
      of: find.text('After-work laps'),
      matching: find.byType(FeedCard),
    );
    Future<int> climbsInRow() async {
      await tester.scrollUntilVisible(card, 200, scrollable: feed);
      await tester.pumpAndSettle();
      return find
          .descendant(of: card, matching: find.byType(SvaStyleTag))
          .evaluate()
          .length;
    }

    final before = await climbsInRow();
    await tester.tap(
      find.descendant(of: card, matching: find.text('After-work laps')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(day), findsOneWidget);

    await tester.tap(find.text(l10n.sessionEdit));
    await tester.pumpAndSettle();
    await tap(
      inSheet(
        find.descendant(
          of: find.byType(RouteHitTile),
          matching: find.text('Hjemmebane'),
        ),
      ),
    );
    // An attempt after the flash that day fits the rules.
    await tap(inSheet(find.text(l10n.ascentStyle('attempt'))));
    await tap(inSheet(find.text(l10n.logEditSave)));

    // Saving runs on the device's database, which can outlast the button's
    // animation that pumpAndSettle waits for.
    await _pumpUntilFound(tester, find.text(l10n.logEditSaved));
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.textContaining(day), findsOneWidget, reason: 'same day');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await climbsInRow(), before + 1);
  });

  testWidgets('M3-4: log a gym session with three climbs on two walls', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AppShell)));
    final (:inSheet, :reveal, :tap) = _sheetHelpers(tester);
    final gym = 'Flow gym ${DateTime.now().millisecondsSinceEpoch}';

    // Set the gym up once: it starts with a rope wall and a boulder area,
    // in green and blue.
    await tester.tap(find.bySemanticsLabel(l10n.tabCv));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.settingsOpen));
    await tester.pumpAndSettle();
    final addGym = find.text(l10n.settingsGymAdd);
    await tester.scrollUntilVisible(
      addGym,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addGym);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.formName),
      gym,
    );
    await tester.tap(find.text(l10n.gymFormSave));
    await _pumpUntilFound(tester, find.text(gym));
    await tester.tap(find.bySemanticsLabel(l10n.tabFeed));
    await tester.pumpAndSettle();

    await tap(find.byKey(logButtonKey));
    await tap(inSheet(find.text(l10n.logIndoor)));
    final gymChip = inSheet(find.widgetWithText(FilterChip, gym));
    if (gymChip.evaluate().isNotEmpty) await tap(gymChip);
    Finder tile(String colour) => inSheet(
      find.ancestor(
        of: find.text(colour),
        matching: find.byType(GymTileButton),
      ),
    );
    final rope = l10n.gymWallKind('rope');
    await tap(tile('Green'));
    await tap(tile('Blue'));
    await tap(inSheet(find.text(l10n.logIndoorDidntTop)));
    await tap(inSheet(find.text(rope)));
    await tap(tile('Blue'));
    await tap(inSheet(find.text(l10n.logSave(3))));

    await _pumpUntilFound(tester, find.text(l10n.logSaved));
    final card = find.ancestor(
      of: find.text(gym),
      matching: find.byType(FeedCard),
    );
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find
          .descendant(
            of: find.byType(FeedScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.descendant(of: card, matching: find.byType(SvaStyleTag)),
      findsNWidgets(3),
    );
  });
}

/// Pumps until [target] is on screen, for work that pumpAndSettle does not
/// wait for, such as a database write.
Future<void> _pumpUntilFound(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 100 && target.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (target.evaluate().isEmpty) fail('Not found: $target\n${_onScreen()}');
  await tester.pumpAndSettle();
}

/// The texts on screen, to make a failure on CI readable.
String _onScreen() {
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>();
  return 'On screen: ${texts.join(' | ')}';
}

typedef _SheetHelpers = ({
  Finder Function(Finder) inSheet,
  Future<void> Function(Finder) reveal,
  Future<void> Function(Finder) tap,
});

/// Finders and taps inside the log sheet.
_SheetHelpers _sheetHelpers(WidgetTester tester) {
  // Only look inside the sheet: the feed behind it shows the example
  // sessions, which mention the same routes.
  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(LogSheet), matching: finder);

  /// Scrolls the sheet until [target] is built and on screen. Its list
  /// builds rows lazily, so rows out of view may not exist yet: look
  /// above first, then below.
  Future<void> reveal(Finder target) async {
    for (final step in [-200.0, 200.0]) {
      if (find.byType(LogSheet).evaluate().isEmpty ||
          target.evaluate().isNotEmpty) {
        break;
      }
      try {
        await tester.scrollUntilVisible(
          target,
          step,
          scrollable: inSheet(find.byType(Scrollable)).first,
          maxScrolls: 30,
        );
        // scrollUntilVisible gives up with a StateError when the target
        // is not in this direction; then try the other one.
        // ignore: avoid_catching_errors
      } on StateError {
        continue;
      }
    }
    if (target.evaluate().isEmpty) fail('Not found: $target\n${_onScreen()}');
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tap(Finder target) async {
    await reveal(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  return (inSheet: inSheet, reveal: reveal, tap: tap);
}
