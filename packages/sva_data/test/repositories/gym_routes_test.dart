import 'package:sva_core/sva_core.dart' show AscentStyle;
import 'package:sva_data/sva_data.dart';
import 'package:test/test.dart';

void main() {
  late SvaDatabase db;
  late GymRouteRepository routes;
  late String gymId;
  late String cave;
  late String board;
  late String blue;

  setUp(() async {
    db = SvaDatabase.inMemory();
    await GradeRepository(db).seed();
    await AttributeRepository(db).seed();
    routes = GymRouteRepository(db);
    final gyms = GymEditor(db);
    gymId = await gyms.addGym(
      const NewGym(name: 'Gnisten', countryCode: 'NO', grading: 'colour'),
      walls: const [
        WallDraft(
          name: 'Cave',
          kind: 'boulder',
          heightM: 4.5,
          angle: 'angle.overhang',
        ),
        WallDraft(
          name: 'Board',
          kind: 'boulder',
          heightM: 3.5,
          angle: 'angle.overhang',
        ),
      ],
      colours: const [ColourDraft(name: 'Blue', colourHex: '#2F6FD1')],
      userId: 'me',
    );
    final setup = (await gyms.setup(gymId, userId: 'me'))!;
    [cave, board] = [for (final w in setup.walls) w.id];
    blue = setup.colours.single.id;
  });
  tearDown(() => db.close());

  Future<String> session(String day) => SessionRepository(db).create(
    SessionsCompanion(
      setting: const Value('indoor'),
      localDate: Value(day),
      tz: const Value('Europe/Oslo'),
      visibility: const Value('private'),
      areaId: Value(gymId),
    ),
    userId: 'me',
  );
  var ordinal = 0;
  Future<void> climb(
    String sessionId,
    String routeId,
    AscentStyle style,
    int tries,
  ) => AscentRepository(db).create(
    AscentsCompanion(
      sessionId: Value(sessionId),
      routeId: Value(routeId),
      ordinal: Value(++ordinal),
      ascentType: const Value('boulder'),
      style: Value(style.name),
      tries: Value(tries),
    ),
    userId: 'me',
  );
  Future<String> blueOn(String wallId, {String setOn = '2026-11-03'}) =>
      routes.add(
        NewGymRoute(wallId: wallId, setOn: setOn, colourId: blue),
        userId: 'me',
      );

  test('M3-3: three attempts on Tuesday and a send on Thursday log as a '
      'redpoint on try 4', () async {
    final route = await blueOn(cave);
    final tuesday = await session('2026-11-03');
    for (var i = 0; i < 3; i++) {
      await climb(tuesday, route, AscentStyle.attempt, 1);
    }

    // Thursday: the same blue is still a project, with 3 tries.
    final project = (await routes.projects(gymId, userId: 'me')).single;
    expect(project.route.id, route);
    expect(project.tries, 3);
    expect(project.lastTried, '2026-11-03');

    // The rules themselves are M1-4's: a redpoint after 3 tries logs
    // as try 4.
    final thursday = await session('2026-11-05');
    await climb(thursday, route, AscentStyle.redpoint, 4);
    expect(await routes.projects(gymId, userId: 'me'), isEmpty);
  });

  test('M3-3: a project ends when it is sent, its wall is reset, or it is '
      'marked as gone', () async {
    final sent = await blueOn(cave);
    final gone = await blueOn(cave, setOn: '2026-11-04');
    final onBoard = await blueOn(board);
    final day = await session('2026-11-04');
    for (final route in [sent, gone, onBoard]) {
      await climb(day, route, AscentStyle.attempt, 2);
    }
    expect([
      for (final p in await routes.projects(gymId, userId: 'me')) p.route.id,
    ], unorderedEquals([sent, gone, onBoard]));
    expect(
      [for (final r in await routes.stillUp(cave, userId: 'me')) r.id],
      [gone, sent],
      reason: 'newest set first',
    );

    await climb(day, sent, AscentStyle.redpoint, 3);
    await routes.markGone(gone, userId: 'me');
    expect(
      [for (final p in await routes.projects(gymId, userId: 'me')) p.route.id],
      [onBoard],
    );
    expect(
      [for (final r in await routes.stillUp(cave, userId: 'me')) r.id],
      [sent],
      reason: 'a sent route is still up, for repeats',
    );

    await routes.resetWall(board, on: '2026-11-06', userId: 'me');
    expect(await routes.projects(gymId, userId: 'me'), isEmpty);
    expect(await routes.stillUp(board, userId: 'me'), isEmpty);
    final wall = await GymWallRepository(db).get(board);
    expect(wall!.lastResetOn, '2026-11-06');
    // The climbs stay in the log.
    expect(
      await AscentRepository(db).routeLog(onBoard, userId: 'me'),
      hasLength(1),
    );
  });

  test('M3-3: a new gym route starts with its wall and is checked', () async {
    final id = await routes.add(
      NewGymRoute(
        wallId: cave,
        setOn: '2026-11-03',
        colourId: blue,
        note: ' left of the arete ',
      ),
      userId: 'me',
    );
    final route = (await RouteRepository(db).get(id))!;
    expect(route.areaId, gymId);
    expect(route.gymWallId, cave);
    expect(route.lengthM, 4.5);
    expect(route.angle, 'angle.overhang');
    expect(route.setOn, '2026-11-03');
    expect(route.setterNote, 'left of the arete');
    expect(route.visibility, 'private');

    final steeper = await routes.add(
      NewGymRoute(
        wallId: cave,
        setOn: '2026-11-03',
        colourId: blue,
        angle: 'angle.roof',
      ),
      userId: 'me',
    );
    expect((await RouteRepository(db).get(steeper))!.angle, 'angle.roof');

    Future<void> add(NewGymRoute route, {String user = 'me'}) =>
        routes.add(route, userId: user);
    expect(
      () => add(NewGymRoute(wallId: cave, setOn: '2026-02-30')),
      throwsArgumentError,
    );
    expect(
      () => add(NewGymRoute(wallId: cave, setOn: '3 Nov')),
      throwsArgumentError,
    );
    expect(
      () =>
          add(NewGymRoute(wallId: cave, setOn: '2026-11-03', colourId: 'nope')),
      throwsArgumentError,
    );
    expect(
      () => add(
        NewGymRoute(wallId: cave, setOn: '2026-11-03', angle: 'angle.sideways'),
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          add(NewGymRoute(wallId: cave, setOn: '2026-11-03', note: 'x' * 201)),
      throwsArgumentError,
    );
    expect(
      () => add(
        NewGymRoute(wallId: cave, setOn: '2026-11-03'),
        user: 'someone else',
      ),
      throwsArgumentError,
    );
    expect(
      () => routes.markGone(id, userId: 'someone else'),
      throwsArgumentError,
    );
    expect(
      () => routes.resetWall(cave, on: '2026-11-06', userId: 'someone else'),
      throwsArgumentError,
    );
  });

  test(
    "M3-3: a gym route's colour or grade follows the gym's grading",
    () async {
      // A colour gym takes colours, not grades.
      expect(
        () => routes.add(
          NewGymRoute(
            wallId: cave,
            setOn: '2026-11-03',
            gradeId: seedId('grade:font:6A'),
          ),
          userId: 'me',
        ),
        throwsArgumentError,
      );

      final gyms = GymEditor(db);
      final graded = await gyms.addGym(
        const NewGym(name: 'Harbour', countryCode: 'NO', grading: 'standard'),
        walls: const [WallDraft(name: 'Cave', kind: 'boulder')],
        userId: 'me',
      );
      final wall = (await gyms.setup(graded, userId: 'me'))!.walls.single.id;
      final id = await routes.add(
        NewGymRoute(
          wallId: wall,
          setOn: '2026-11-03',
          gradeId: seedId('grade:font:6A'),
        ),
        userId: 'me',
      );
      final grade = await (db.select(
        db.routeGrades,
      )..where((g) => g.routeId.equals(id))).getSingle();
      expect(grade.gradeId, seedId('grade:font:6A'));
      expect(grade.gradeType, 'boulder');
      expect(
        () => routes.add(
          NewGymRoute(
            wallId: wall,
            setOn: '2026-11-03',
            gradeId: seedId('grade:nor:6'),
          ),
          userId: 'me',
        ),
        throwsArgumentError,
        reason: 'a route grade on a boulder wall',
      );
      expect(
        () => routes.add(
          NewGymRoute(wallId: wall, setOn: '2026-11-03', colourId: blue),
          userId: 'me',
        ),
        throwsArgumentError,
        reason: 'a graded gym takes grades, not colours',
      );
    },
  );

  test(
    'M3-3: a wall reset is never in the future and never moves back',
    () async {
      final clocked = GymRouteRepository(
        db,
        clock: () => DateTime.utc(2026, 11, 8),
      );
      await clocked.resetWall(cave, on: '2026-11-08', userId: 'me');
      expect(
        () => clocked.resetWall(cave, on: '2026-11-12', userId: 'me'),
        throwsArgumentError,
      );
      // A reset logged late doesn't move the date back.
      await clocked.resetWall(cave, on: '2026-11-01', userId: 'me');
      expect(
        (await GymWallRepository(db).get(cave))!.lastResetOn,
        '2026-11-08',
      );
    },
  );
}
