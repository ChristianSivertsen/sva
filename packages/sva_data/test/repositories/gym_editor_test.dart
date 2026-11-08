import 'package:sva_data/sva_data.dart';
import 'package:test/test.dart';

void main() {
  late SvaDatabase db;
  late GymEditor gyms;

  setUp(() async {
    db = SvaDatabase.inMemory();
    await AttributeRepository(db).seed();
    gyms = GymEditor(db);
  });
  tearDown(() => db.close());

  const walls = [
    WallDraft(
      name: 'Main wall',
      kind: 'rope',
      heightM: 14,
      angle: 'angle.vertical',
    ),
    WallDraft(name: 'Cave', kind: 'boulder', heightM: 4.5, angle: 'angle.roof'),
  ];

  test('M3-1: a gym and its walls are saved and changed', () async {
    final id = await gyms.addGym(
      const NewGym(
        name: ' Klatreverket ',
        countryCode: 'NO',
        grading: 'colour',
      ),
      walls: walls,
      userId: 'me',
    );
    var setup = (await gyms.setup(id, userId: 'me'))!;
    expect(setup.gym.name, 'Klatreverket');
    expect(setup.gym.type, 'gym');
    expect(setup.gym.visibility, 'private');
    expect(setup.grading, 'colour');
    expect(setup.walls.map((w) => (w.name, w.kind, w.heightM, w.angle)), [
      ('Main wall', 'rope', 14.0, 'angle.vertical'),
      ('Cave', 'boulder', 4.5, 'angle.roof'),
    ]);

    // Rename a wall, drop one, add one, and switch to standard grades.
    final main = setup.walls.first;
    await gyms.updateGym(
      id,
      const NewGym(
        name: 'Klatreverket Oslo',
        countryCode: 'NO',
        grading: 'standard',
      ),
      walls: [
        WallDraft(id: main.id, name: 'Lead wall', kind: 'rope', heightM: 15),
        const WallDraft(
          name: 'Board',
          kind: 'boulder',
          angle: 'angle.overhang',
        ),
      ],
      colours: const [],
      userId: 'me',
    );
    setup = (await gyms.setup(id, userId: 'me'))!;
    expect(setup.gym.name, 'Klatreverket Oslo');
    expect(setup.grading, 'standard');
    expect(setup.walls.map((w) => (w.id == main.id, w.name, w.heightM)), [
      (true, 'Lead wall', 15.0),
      (false, 'Board', null),
    ]);

    // Someone else can't see or change a private gym.
    expect(await gyms.setup(id, userId: 'someone else'), isNull);
    expect(
      () => gyms.updateGym(
        id,
        const NewGym(name: 'Mine now', countryCode: 'NO', grading: 'none'),
        walls: walls,
        colours: const [],
        userId: 'someone else',
      ),
      throwsArgumentError,
    );

    // Bad values are refused and nothing is written.
    Future<void> add(NewGym gym, List<WallDraft> walls) =>
        gyms.addGym(gym, walls: walls, userId: 'me');
    const ok = NewGym(name: 'Gym', countryCode: 'NO', grading: 'none');
    expect(
      () => add(
        const NewGym(name: ' ', countryCode: 'NO', grading: 'none'),
        walls,
      ),
      throwsArgumentError,
    );
    expect(
      () => add(
        const NewGym(name: 'Gym', countryCode: 'NO', grading: 'fancy'),
        walls,
      ),
      throwsArgumentError,
    );
    expect(
      () => add(ok, const [WallDraft(name: '', kind: 'rope')]),
      throwsArgumentError,
    );
    expect(
      () => add(ok, const [WallDraft(name: 'W', kind: 'ice')]),
      throwsArgumentError,
    );
    expect(
      () => add(ok, const [WallDraft(name: 'W', kind: 'rope', heightM: 0)]),
      throwsArgumentError,
    );
    expect(
      () => add(ok, const [
        WallDraft(name: 'W', kind: 'rope', angle: 'angle.sideways'),
      ]),
      throwsArgumentError,
    );
    expect(
      await (db.select(db.areas)..where((a) => a.type.equals('gym'))).get(),
      hasLength(1),
    );
  });

  test(
    'M3-1: a new climb on a wall starts with its height and angle',
    () async {
      final id = await gyms.addGym(
        const NewGym(
          name: 'Klatreverket',
          countryCode: 'NO',
          grading: 'colour',
        ),
        walls: walls,
        userId: 'me',
      );
      final [rope, cave] = (await gyms.setup(id, userId: 'me'))!.walls;

      final onRope = await gyms.newGymRoute(rope.id, userId: 'me');
      expect(onRope.areaId.value, id);
      expect(onRope.kind.value, 'gym');
      expect(onRope.gymWallId.value, rope.id);
      expect(onRope.lengthM.value, 14);
      expect(onRope.angle.value, 'angle.vertical');
      expect(onRope.discipline.value, 'sport');

      final onCave = await gyms.newGymRoute(cave.id, userId: 'me');
      expect(onCave.discipline.value, 'boulder');
      expect(onCave.angle.value, 'angle.roof');

      // The angle can be changed for one climb.
      final steeper = onCave.copyWith(angle: const Value('angle.overhang'));
      expect(steeper.angle.value, 'angle.overhang');

      expect(
        () => gyms.newGymRoute(rope.id, userId: 'someone else'),
        throwsArgumentError,
      );
    },
  );

  test("M3-1: walls on a shared gym are the user's own to change", () async {
    final id = await gyms.addGym(
      const NewGym(name: 'Klatreverket', countryCode: 'NO', grading: 'colour'),
      walls: walls,
      userId: 'me',
    );
    // Moderators accept it (M12): it becomes shared.
    await (db.update(db.areas)..where((a) => a.id.equals(id))).write(
      const AreasCompanion(visibility: Value('public')),
    );

    expect(
      () => gyms.updateGym(
        id,
        const NewGym(name: 'Renamed', countryCode: 'NO', grading: 'none'),
        walls: walls,
        colours: const [],
        userId: 'me',
      ),
      throwsArgumentError,
      reason: 'a shared gym changes through moderators',
    );
    await gyms.saveOwn(
      id,
      walls: const [WallDraft(name: 'Their cave', kind: 'boulder')],
      colours: const [],
      userId: 'someone else',
    );
    expect(
      (await gyms.setup(id, userId: 'someone else'))!.walls.map((w) => w.name),
      ['Their cave'],
    );
    expect((await gyms.setup(id, userId: 'me'))!.walls.map((w) => w.name), [
      'Main wall',
      'Cave',
    ], reason: 'walls are personal');
    expect((await gyms.setup(id, userId: 'me'))!.gym.name, 'Klatreverket');
  });

  test('M3-1: wall changes are checked before anything is written', () async {
    final id = await gyms.addGym(
      const NewGym(name: 'Klatreverket', countryCode: 'NO', grading: 'colour'),
      walls: walls,
      userId: 'me',
    );
    final other = await gyms.addGym(
      const NewGym(name: 'Other', countryCode: 'NO', grading: 'none'),
      walls: const [WallDraft(name: 'Elsewhere', kind: 'rope')],
      userId: 'me',
    );
    final [main, cave] = (await gyms.setup(id, userId: 'me'))!.walls;
    final elsewhere = (await gyms.setup(other, userId: 'me'))!.walls.single;

    Future<void> save(List<WallDraft> walls) =>
        gyms.saveOwn(id, walls: walls, colours: const [], userId: 'me');
    expect(
      () => save([WallDraft(id: elsewhere.id, name: 'Moved', kind: 'rope')]),
      throwsArgumentError,
      reason: 'a wall from another gym',
    );
    for (final height in [double.nan, double.infinity, 0.5, 61.0]) {
      expect(
        () => save([WallDraft(name: 'W', kind: 'rope', heightM: height)]),
        throwsArgumentError,
        reason: '$height m',
      );
    }
    expect(
      () => save([WallDraft(name: 'x' * (maxNameLength + 1), kind: 'rope')]),
      throwsArgumentError,
    );
    expect((await gyms.setup(id, userId: 'me'))!.walls.map((w) => w.id), [
      main.id,
      cave.id,
    ], reason: 'nothing changed');

    // A wall left out is deleted, softly.
    await save([WallDraft(id: main.id, name: 'Main wall', kind: 'rope')]);
    final row = await (db.select(
      db.gymWalls,
    )..where((w) => w.id.equals(cave.id))).getSingle();
    expect(row.deletedAt, isNotNull);

    // A refused gym leaves no walls behind either.
    final before = await db.select(db.gymWalls).get();
    await expectLater(
      gyms.addGym(
        const NewGym(name: 'Bad', countryCode: 'NOR', grading: 'none'),
        walls: walls,
        userId: 'me',
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.gymWalls).get(), hasLength(before.length));
  });

  test(
    "M3-2: a gym's colours are saved in order, with optional ranges",
    () async {
      final id = await gyms.addGym(
        const NewGym(
          name: 'Klatreverket',
          countryCode: 'NO',
          grading: 'colour',
        ),
        walls: walls,
        colours: const [
          ColourDraft(name: 'Green', colourHex: '#3fa34d'),
          ColourDraft(
            name: 'Blue',
            colourHex: '#2F6FD1',
            boulder: (min: 20, max: 30),
            route: (min: 40, max: 50),
          ),
        ],
        userId: 'me',
      );
      var colours = (await gyms.setup(id, userId: 'me'))!.colours;
      expect(
        colours.map(
          (c) => (c.name, c.colourHex, c.boulderMinScore, c.routeMaxScore),
        ),
        [('Green', '#3FA34D', null, null), ('Blue', '#2F6FD1', 20.0, 50.0)],
      );

      // Map green, drop blue, add red as the hardest.
      final green = colours.first;
      await gyms.saveOwn(
        id,
        walls: const [WallDraft(name: 'Main wall', kind: 'rope')],
        colours: [
          ColourDraft(
            id: green.id,
            name: 'Green',
            colourHex: '#3FA34D',
            boulder: (min: 10, max: 15),
          ),
          const ColourDraft(name: 'Red', colourHex: '#D33A2C'),
        ],
        userId: 'me',
      );
      colours = (await gyms.setup(id, userId: 'me'))!.colours;
      expect(
        colours.map((c) => (c.id == green.id, c.name, c.boulderMaxScore)),
        [(true, 'Green', 15.0), (false, 'Red', null)],
      );

      Future<void> save(ColourDraft colour) =>
          gyms.saveOwn(id, walls: const [], colours: [colour], userId: 'me');
      expect(
        () => save(const ColourDraft(name: 'Teal', colourHex: 'teal')),
        throwsArgumentError,
      );
      expect(
        () => save(const ColourDraft(name: ' ', colourHex: '#00AA99')),
        throwsArgumentError,
      );
      expect(
        () => save(
          const ColourDraft(
            name: 'Teal',
            colourHex: '#00AA99',
            route: (min: 50, max: 40),
          ),
        ),
        throwsArgumentError,
      );
      expect((await gyms.setup(id, userId: 'me'))!.colours, hasLength(2));
    },
  );

  test("M3-2: colours are each user's own", () async {
    final id = await gyms.addGym(
      const NewGym(name: 'Klatreverket', countryCode: 'NO', grading: 'colour'),
      walls: walls,
      colours: const [ColourDraft(name: 'Green', colourHex: '#3FA34D')],
      userId: 'me',
    );
    await (db.update(db.areas)..where((a) => a.id.equals(id))).write(
      const AreasCompanion(visibility: Value('public')),
    );
    await gyms.saveOwn(
      id,
      walls: const [],
      colours: const [ColourDraft(name: 'Gul', colourHex: '#F2C230')],
      userId: 'someone else',
    );
    final mine = (await gyms.setup(id, userId: 'me'))!.colours;
    expect(mine.map((c) => c.name), ['Green']);
    expect(
      (await gyms.setup(
        id,
        userId: 'someone else',
      ))!.colours.map((c) => c.name),
      ['Gul'],
    );

    // Someone else can't change or remove my colour by its id.
    expect(
      () => gyms.saveOwn(
        id,
        walls: const [],
        colours: [
          ColourDraft(id: mine.single.id, name: 'Taken', colourHex: '#000000'),
        ],
        userId: 'someone else',
      ),
      throwsArgumentError,
    );
    expect((await gyms.setup(id, userId: 'me'))!.colours.single.name, 'Green');
  });
}
