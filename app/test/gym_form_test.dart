import 'dart:async';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sva/src/app.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/gyms/gym_form_screen.dart';
import 'package:sva/src/router.dart';
import 'package:sva/src/routes.dart';
import 'package:sva/src/settings/settings_screen.dart';
import 'package:sva_core/sva_core.dart' show Grade, colourRange, gradeSystems;
import 'package:sva_data/sva_data.dart';

/// Records what the gym form saves. Storage and its checks are tested in
/// sva_data.
class _FakeGyms extends GymEditor {
  new(super.db, {this.existing, this.fail = false});

  final GymSetup? existing;
  final bool fail;
  NewGym? gym;
  List<WallDraft>? walls;
  List<ColourDraft>? colours;
  String? called;

  @override
  Future<String> addGym(
    NewGym gym, {
    required List<WallDraft> walls,
    required String userId,
    List<ColourDraft> colours = const [],
  }) async {
    if (fail) throw StateError('disk full');
    this.gym = gym;
    this.walls = walls;
    this.colours = colours;
    called = 'addGym';
    return 'g1';
  }

  @override
  Future<void> updateGym(
    String gymId,
    NewGym gym, {
    required List<WallDraft> walls,
    required String userId,
    List<ColourDraft> colours = const [],
  }) async {
    this.gym = gym;
    this.walls = walls;
    this.colours = colours;
    called = 'updateGym';
  }

  @override
  Future<void> saveOwn(
    String gymId, {
    required List<WallDraft> walls,
    required String userId,
    List<ColourDraft> colours = const [],
  }) async {
    this.walls = walls;
    this.colours = colours;
    called = 'saveOwn';
  }

  @override
  Future<GymSetup?> setup(String gymId, {required String userId}) async =>
      existing;
}

Area _gym({String createdBy = localUserId, String visibility = 'private'}) =>
    Area(
      id: 'g1',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      createdBy: createdBy,
      visibility: visibility,
      type: 'gym',
      name: 'Klatreverket',
      countryCode: 'NO',
      locationHidden: false,
    );

GymWall _wall(String id, String name, String kind, double height) => GymWall(
  id: id,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  ownerId: localUserId,
  gymId: 'g1',
  name: name,
  heightM: height,
  angle: 'angle.vertical',
  kind: kind,
  sort: 0,
);

void main() {
  late _FakeGyms gyms;

  /// Opens settings, and the gym form for [existing] when given.
  Future<void> open(
    WidgetTester tester, {
    GymSetup? existing,
    bool fail = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = SvaDatabase.inMemory();
    addTearDown(db.close);
    gyms = _FakeGyms(db, existing: existing, fail: fail);
    final container = ProviderContainer(
      overrides: [
        gymEditorProvider.overrideWithValue(gyms),
        gymsProvider.overrideWith((ref) => Stream.value(const [])),
        settingsProvider.overrideWith((ref) => Stream.value(const Settings())),
        gradeSystemsProvider.overrideWith((ref) async => gradeSystems),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SvaApp()),
    );
    // A page's result is not needed here.
    unawaited(container.read(routerProvider).push(Routes.settings));
    await tester.pumpAndSettle();
    if (existing != null) {
      unawaited(container.read(routerProvider).push(Routes.gym('g1')));
      await tester.pumpAndSettle();
    }
  }

  Finder field(String text) => find.widgetWithText(TextFormField, text);

  testWidgets('M3-1: a gym with 4 walls is set up in under 2 minutes', (
    tester,
  ) async {
    await open(tester);
    // Each tap or typed field is one step: a handful is well under
    // 2 minutes.
    var steps = 0;
    Future<void> tap(Finder target) async {
      steps++;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> type(Finder target, String text) async {
      steps++;
      await tester.enterText(target, text);
      await tester.pumpAndSettle();
    }

    await tap(find.text('Add a gym'));
    expect(find.byType(GymFormScreen), findsOneWidget);
    await type(field('Name'), 'Klatreverket');
    await tap(find.text('Add a wall'));
    await tap(find.text('Add a wall'));
    await type(field('Wall 4'), 'Board');
    await tap(find.text('Save gym'));

    expect(steps, lessThanOrEqualTo(6));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(gyms.called, 'addGym');
    expect(gyms.gym!.name, 'Klatreverket');
    expect(gyms.gym!.grading, 'colour');
    expect(gyms.walls!.map((w) => (w.name, w.kind, w.heightM, w.angle)), [
      ('Main wall', 'rope', 14.0, 'angle.vertical'),
      ('Boulder area', 'boulder', 4.5, 'angle.overhang'),
      ('Wall 3', 'boulder', 4.5, 'angle.vertical'),
      ('Board', 'boulder', 4.5, 'angle.vertical'),
    ]);
  });

  testWidgets('M3-1: the wall editor changes, adds and removes walls', (
    tester,
  ) async {
    await open(
      tester,
      existing: (
        gym: _gym(),
        grading: 'standard',
        walls: [
          _wall('w1', 'Lead wall', 'rope', 15),
          _wall('w2', 'Cave', 'boulder', 4),
        ],
        colours: const <GymColourGrade>[],
      ),
    );
    expect(find.text('Edit gym'), findsOneWidget);
    expect(field('Lead wall'), findsOneWidget);

    // A height typed with a decimal comma carries over to a new wall.
    await tester.enterText(field('4'), '4,5');
    await tester.tap(find.text('Add a wall'));
    await tester.pumpAndSettle();
    // The remove button follows the typed name.
    await tester.enterText(field('Wall 3'), 'Board');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove Board'), findsOneWidget);
    final cave = find.ancestor(of: field('Cave'), matching: find.byType(Card));
    await tester.tap(
      find.descendant(
        of: cave,
        matching: find.widgetWithText(FilterChip, 'Roof'),
      ),
    );
    await tester.tap(find.byTooltip('Remove Lead wall'));
    await tester.pumpAndSettle();
    // Adding after a removal does not repeat a name.
    await tester.tap(find.text('Add a wall'));
    await tester.pumpAndSettle();
    expect(field('Wall 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Wall 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save gym'));
    await tester.pumpAndSettle();

    expect(gyms.called, 'updateGym');
    expect(gyms.gym!.grading, 'standard');
    expect(gyms.walls!.map((w) => (w.id, w.name, w.heightM, w.angle)), [
      ('w2', 'Cave', 4.5, 'angle.roof'),
      (null, 'Board', 4.5, 'angle.vertical'),
    ]);
  });

  testWidgets('M3-1: the gym form checks its fields and keeps one wall', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Add a gym'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Main wall'), ' ');
    await tester.enterText(field('14'), '0,5');
    await tester.tap(find.text('Save gym'));
    await tester.pumpAndSettle();
    expect(find.text('Give the gym a name.'), findsOneWidget);
    expect(find.text('Give the wall a name.'), findsOneWidget);
    expect(
      find.text('Use a height from 1 to 60 m, or leave it empty.'),
      findsOneWidget,
    );
    expect(gyms.called, isNull, reason: 'nothing saved');

    // With one wall left, it has no remove button.
    await tester.tap(find.byTooltip('Remove Boulder area'));
    await tester.pumpAndSettle();
    final lastWall = find.ancestor(
      of: field('0,5'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: lastWall, matching: find.byType(IconButton)),
      findsNothing,
    );
  });

  testWidgets('M3-1: on a shared gym only your walls are saved', (
    tester,
  ) async {
    await open(
      tester,
      existing: (
        gym: _gym(createdBy: 'someone else', visibility: 'public'),
        grading: 'colour',
        walls: const <GymWall>[],
        colours: const <GymColourGrade>[],
      ),
    );
    expect(
      find.text('This gym is shared, so only your walls can be changed here.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(field('Klatreverket')).enabled,
      isFalse,
    );
    await tester.tap(find.text('Add a wall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save gym'));
    await tester.pumpAndSettle();
    expect(gyms.called, 'saveOwn');
    expect(gyms.walls!.single.name, 'Wall 1');
  });

  testWidgets('M3-1: a gym that cannot be saved says so', (tester) async {
    await open(tester, fail: true);
    await tester.tap(find.text('Add a gym'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'Klatreverket');
    await tester.tap(find.text('Save gym'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't save. Check the fields and try again."),
      findsOneWidget,
    );
    expect(find.byType(GymFormScreen), findsOneWidget);
  });

  testWidgets('M3-2: the colour editor maps colours to grade ranges', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Add a gym'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'Klatreverket');
    expect(find.text('Colours, easiest first'), findsOneWidget);
    Finder card(String colour) =>
        find.ancestor(of: field(colour), matching: find.byType(Card));
    Finder inCard(String colour, Finder finder) =>
        find.descendant(of: card(colour), matching: finder);

    // Blue spans Font 6A to 6B for boulders. Picking the start first
    // makes a one-grade range.
    final boulderFrom = inCard(
      'Blue',
      find.byType(DropdownButton<Grade?>),
    ).first;
    await tester.ensureVisible(boulderFrom);
    await tester.tap(boulderFrom);
    await tester.pumpAndSettle();
    await tester.tap(find.text('6A').last);
    await tester.pumpAndSettle();
    final boulderTo = inCard('Blue', find.byType(DropdownButton<Grade>)).first;
    await tester.tap(boulderTo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('6B').last);
    await tester.pumpAndSettle();

    // Add a colour, name it, and move it above blue.
    await tester.ensureVisible(find.text('Add a colour'));
    await tester.tap(find.text('Add a colour'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Colour 3'), 'Yellow');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move Yellow up'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Green'));
    await tester.pumpAndSettle();

    // The swatch opens the colour picker; closing it keeps the colour.
    final swatch = inCard('Blue', find.byType(InkWell)).first;
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);
    Navigator.of(tester.element(find.byType(ColorPicker))).pop();
    await tester.pumpAndSettle();

    // Another grading hides the colours but keeps them.
    await tester.tap(find.widgetWithText(FilterChip, 'Standard grades'));
    await tester.pumpAndSettle();
    expect(find.text('Colours, easiest first'), findsNothing);
    await tester.tap(find.text('Save gym'));
    await tester.pumpAndSettle();

    final font = gradeSystems.firstWhere((s) => s.key == 'font');
    expect(gyms.gym!.grading, 'standard');
    expect(
      gyms.colours!.map((c) => (c.name, c.colourHex, c.boulder, c.route)),
      [
        ('Yellow', '#808080', null, null),
        (
          'Blue',
          '#2F6FD1',
          colourRange(font.parse('6A')!, font.parse('6B')!),
          null,
        ),
      ],
    );
  });

  testWidgets("M3-2: a gym's saved colours load into the editor, and a "
      'hidden colour without a name is shown again', (tester) async {
    final semantics = tester.ensureSemantics();
    final font = gradeSystems.firstWhere((s) => s.key == 'font');
    final range = colourRange(font.parse('6A')!, font.parse('6B')!);
    await open(
      tester,
      existing: (
        gym: _gym(),
        grading: 'colour',
        walls: [_wall('w1', 'Cave', 'boulder', 4)],
        colours: [
          GymColourGrade(
            id: 'c1',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            ownerId: localUserId,
            gymId: 'g1',
            sort: 0,
            name: 'Blue',
            colourHex: '#2F6FD1',
            boulderMinScore: range.min,
            boulderMaxScore: range.max,
          ),
        ],
      ),
    );
    expect(field('Blue'), findsOneWidget);
    // The range pickers say which colour and grade they set.
    expect(
      find.bySemanticsLabel(RegExp(r'^Easiest grade for Blue \(Boulders\)')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Hardest grade for Blue \(Boulders\)')),
      findsOneWidget,
    );

    // Clear the name, then hide the colours behind another grading.
    await tester.enterText(field('Blue'), '');
    await tester.tap(find.widgetWithText(FilterChip, 'Ungraded'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save gym'));
    await tester.pumpAndSettle();
    expect(find.text('Colours, easiest first'), findsOneWidget);
    expect(find.text('Give the colour a name.'), findsOneWidget);
    expect(gyms.called, isNull, reason: 'nothing saved');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Colour name'),
      'Blå',
    );
    await tester.tap(find.text('Save gym'));
    await tester.pumpAndSettle();
    expect(gyms.colours!.single.id, 'c1');
    expect(gyms.colours!.single.name, 'Blå');
    expect(gyms.colours!.single.boulder, range);
    semantics.dispose();
  });
}
