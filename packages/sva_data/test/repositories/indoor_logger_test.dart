import 'package:sva_core/sva_core.dart' show AscentStyle, AttributeLevel;
import 'package:sva_data/sva_data.dart';
import 'package:test/test.dart';

void main() {
  late SvaDatabase db;
  late SessionLogger logger;
  late String gymId;
  late String cave;
  late String main;
  late String blue;

  setUp(() async {
    db = SvaDatabase.inMemory();
    await GradeRepository(db).seed();
    await AttributeRepository(db).seed();
    logger = SessionLogger(db, clock: () => DateTime.utc(2026, 11, 8));
    final gyms = GymEditor(db);
    gymId = await gyms.addGym(
      const NewGym(name: 'Gnisten', countryCode: 'NO', grading: 'colour'),
      walls: const [
        WallDraft(name: 'Cave', kind: 'boulder', heightM: 4.5),
        WallDraft(name: 'Main wall', kind: 'rope', heightM: 15),
      ],
      colours: const [ColourDraft(name: 'Blue', colourHex: '#2F6FD1')],
      userId: 'me',
    );
    final setup = (await gyms.setup(gymId, userId: 'me'))!;
    [cave, main] = [for (final w in setup.walls) w.id];
    blue = setup.colours.single.id;
  });
  tearDown(() => db.close());

  IndoorSessionDraft draft(
    String day,
    List<IndoorRouteDraft> routes,
    List<IndoorClimbDraft> climbs,
  ) => IndoorSessionDraft(
    gymId: gymId,
    localDate: day,
    tz: 'Europe/Oslo',
    visibility: 'private',
    routes: routes,
    climbs: climbs,
  );
  IndoorClimbDraft climb(
    int route,
    AscentStyle style,
    int tries, {
    String type = 'boulder',
  }) => IndoorClimbDraft(
    route: route,
    style: style,
    tries: tries,
    ascentType: type,
  );

  test(
    'M3-4: an indoor session saves with new and existing gym routes',
    () async {
      // Tuesday: fell three times on a blue in the cave, flashed a blue on
      // the main wall on lead.
      final tuesday = await logger.logIndoor(
        draft(
          '2026-11-03',
          [
            IndoorRouteDraft(wallId: cave, colourId: blue),
            IndoorRouteDraft(wallId: main, colourId: blue),
          ],
          [
            climb(0, AscentStyle.attempt, 3),
            climb(1, AscentStyle.flash, 1, type: 'lead'),
          ],
        ),
        userId: 'me',
      );
      final session = (await SessionRepository(db).get(tuesday))!;
      expect(session.setting, 'indoor');
      expect(session.areaId, gymId);
      final caveBlue = (await GymRouteRepository(
        db,
      ).projects(gymId, userId: 'me')).single.route;
      expect(caveBlue.setOn, '2026-11-03');
      expect(caveBlue.lengthM, 4.5);
      // Gym routes have no name: they show as their colour and wall.
      expect(await GymRouteRepository(db).label(caveBlue.id, userId: 'me'), (
        colour: 'Blue',
        grade: null,
        gradeSystem: null,
        wall: 'Cave',
      ));
      expect(
        await GymRouteRepository(db).label(caveBlue.id, userId: 'someone else'),
        isNull,
      );

      // Thursday: sent it on try 4, and a new blue on the main wall after a
      // fall the same night.
      final thursday = await logger.logIndoor(
        draft(
          '2026-11-05',
          [
            IndoorRouteDraft(routeId: caveBlue.id),
            IndoorRouteDraft(wallId: main, colourId: blue),
          ],
          [
            climb(0, AscentStyle.redpoint, 4),
            climb(1, AscentStyle.attempt, 1, type: 'toprope'),
            climb(1, AscentStyle.redpoint, 2, type: 'toprope'),
          ],
        ),
        userId: 'me',
      );
      final climbs = await AscentRepository(db).watchInSession(thursday).first;
      expect(climbs.map((a) => (a.ordinal, a.style, a.tries, a.ascentType)), [
        (1, 'redpoint', 4, 'boulder'),
        (2, 'attempt', 1, 'toprope'),
        (3, 'redpoint', 2, 'toprope'),
      ]);
      expect(climbs.first.routeId, caveBlue.id);
      expect(
        await GymRouteRepository(db).projects(gymId, userId: 'me'),
        isEmpty,
      );
    },
  );

  test('M3-4: an indoor session that breaks a rule saves nothing', () async {
    final sessionsBefore = await db.select(db.sessions).get();
    final routesBefore = await db.select(db.routes).get();
    Future<void> log(
      List<IndoorRouteDraft> routes,
      List<IndoorClimbDraft> climbs,
    ) => logger.logIndoor(draft('2026-11-05', routes, climbs), userId: 'me');
    final newBlue = IndoorRouteDraft(wallId: cave, colourId: blue);

    // A flash after a fall the same night.
    await expectLater(
      log(
        [newBlue],
        [climb(0, AscentStyle.attempt, 1), climb(0, AscentStyle.flash, 1)],
      ),
      throwsA(isA<ClimbRejected>().having((e) => e.index, 'index', 1)),
    );
    // Lead on a boulder wall, and boulder on a rope wall.
    await expectLater(
      log([newBlue], [climb(0, AscentStyle.flash, 1, type: 'lead')]),
      throwsArgumentError,
    );
    await expectLater(
      log(
        [IndoorRouteDraft(wallId: main, colourId: blue)],
        [climb(0, AscentStyle.flash, 1)],
      ),
      throwsArgumentError,
    );
    await expectLater(
      log([newBlue], [climb(0, AscentStyle.flash, 1, type: 'auto_belay')]),
      throwsArgumentError,
    );
    await expectLater(
      log([newBlue], [climb(1, AscentStyle.flash, 1)]),
      throwsArgumentError,
    );
    await expectLater(log([newBlue], []), throwsArgumentError);
    await expectLater(
      log(
        [const IndoorRouteDraft(routeId: 'nope')],
        [climb(0, AscentStyle.flash, 1)],
      ),
      throwsArgumentError,
    );
    await expectLater(
      logger.logIndoor(
        IndoorSessionDraft(
          gymId: 'nope',
          localDate: '2026-11-05',
          tz: 'Europe/Oslo',
          visibility: 'private',
          routes: [newBlue],
          climbs: [climb(0, AscentStyle.flash, 1)],
        ),
        userId: 'me',
      ),
      throwsArgumentError,
    );
    expect(
      await db.select(db.sessions).get(),
      hasLength(sessionsBefore.length),
    );
    expect(
      await db.select(db.routes).get(),
      hasLength(routesBefore.length),
      reason: 'no new route left behind',
    );
  });

  test('M3-4: an indoor session takes each route once, and none that is '
      'gone', () async {
    final tuesday = await logger.logIndoor(
      draft(
        '2026-11-03',
        [IndoorRouteDraft(wallId: cave, colourId: blue)],
        [climb(0, AscentStyle.attempt, 1)],
      ),
      userId: 'me',
    );
    final route = (await AscentRepository(
      db,
    ).watchInSession(tuesday).first).single.routeId;
    // Twice, the two redpoints would never be checked against each other.
    await expectLater(
      logger.logIndoor(
        draft(
          '2026-11-05',
          [IndoorRouteDraft(routeId: route), IndoorRouteDraft(routeId: route)],
          [
            climb(0, AscentStyle.redpoint, 2),
            climb(1, AscentStyle.redpoint, 2),
          ],
        ),
        userId: 'me',
      ),
      throwsArgumentError,
    );
    await GymRouteRepository(db).markGone(route, userId: 'me');
    await expectLater(
      logger.logIndoor(
        draft(
          '2026-11-05',
          [IndoorRouteDraft(routeId: route)],
          [climb(0, AscentStyle.redpoint, 2)],
        ),
        userId: 'me',
      ),
      throwsArgumentError,
    );
  });

  test("M3-4: a graded gym's climbs save with their grade", () async {
    final gyms = GymEditor(db);
    final graded = await gyms.addGym(
      const NewGym(name: 'Harbour', countryCode: 'NO', grading: 'standard'),
      walls: const [WallDraft(name: 'Cave', kind: 'boulder')],
      userId: 'me',
    );
    final wall = (await gyms.setup(graded, userId: 'me'))!.walls.single.id;
    final id = await logger.logIndoor(
      IndoorSessionDraft(
        gymId: graded,
        localDate: '2026-11-05',
        tz: 'Europe/Oslo',
        visibility: 'private',
        routes: [
          IndoorRouteDraft(wallId: wall, gradeId: seedId('grade:font:6A')),
        ],
        climbs: [climb(0, AscentStyle.flash, 1)],
      ),
      userId: 'me',
    );
    final route = (await AscentRepository(
      db,
    ).watchInSession(id).first).single.routeId;
    expect(await GymRouteRepository(db).label(route, userId: 'me'), (
      colour: null,
      grade: '6A',
      gradeSystem: 'font',
      wall: 'Cave',
    ));
  });

  test("M3-8: a climb's holds, movement and beta are saved with it", () async {
    // Seeded grades have ids made from their system and label.
    String grade(String system, String label) => seedId('grade:$system:$label');
    final font6a = grade('font', '6A');
    final id = await logger.logIndoor(
      draft(
        '2026-11-03',
        [IndoorRouteDraft(wallId: cave, colourId: blue, angle: 'angle.roof')],
        [
          IndoorClimbDraft(
            route: 0,
            style: AscentStyle.flash,
            tries: 1,
            ascentType: 'boulder',
            personalGradeId: font6a,
            holds: const ['hold.crimp', 'hold.volume'],
            movement: const ['movement.dyno'],
            beta: ' Heel hook on the volume ',
          ),
        ],
      ),
      userId: 'me',
    );
    final ascent = await (db.select(
      db.ascents,
    )..where((a) => a.sessionId.equals(id))).getSingle();
    expect(ascent.personalGradeId, font6a);
    final values = await AttributeRepository(db)
        .valuesAt(AttributeLevel.ascent, ascent.id);
    expect(
      values['climb_hold'],
      unorderedEquals(['hold.crimp', 'hold.volume']),
    );
    expect(values['movement'], ['movement.dyno']);
    final beta = await db.select(db.ascentBeta).getSingle();
    expect(
      (beta.ascentId, beta.betaNotes),
      (ascent.id, 'Heel hook on the volume'),
    );
    final route = await (db.select(
      db.routes,
    )..where((r) => r.id.equals(ascent.routeId))).getSingle();
    expect(route.angle, 'angle.roof', reason: 'steeper than the wall');

    // Each is checked first: nothing is saved otherwise.
    final before = await db.select(db.ascents).get();
    Future<void> log(IndoorClimbDraft climb) => logger.logIndoor(
      draft(
        '2026-11-04',
        [IndoorRouteDraft(wallId: cave, colourId: blue)],
        [climb],
      ),
      userId: 'me',
    );
    IndoorClimbDraft flash({
      List<String> holds = const [],
      List<String> movement = const [],
      String? beta,
      String? grade,
    }) => IndoorClimbDraft(
      route: 0,
      style: AscentStyle.flash,
      tries: 1,
      ascentType: 'boulder',
      holds: holds,
      movement: movement,
      beta: beta,
      personalGradeId: grade,
    );
    final nor6 = grade('nor', '6');
    for (final bad in [
      flash(holds: const ['hold.undercling']),
      flash(movement: const ['movement.crimpy']),
      flash(beta: 'x' * (maxBetaLength + 1)),
      flash(grade: nor6),
    ]) {
      await expectLater(log(bad), throwsArgumentError);
    }
    expect(await db.select(db.ascents).get(), hasLength(before.length));
  });

  test('M3-8: a live session saves its times and partners', () async {
    IndoorSessionDraft live(DateTime? start, DateTime? end) =>
        IndoorSessionDraft(
          gymId: gymId,
          localDate: '2026-11-07',
          tz: 'Europe/Oslo',
          visibility: 'friends',
          routes: [IndoorRouteDraft(wallId: cave, colourId: blue)],
          climbs: [climb(0, AscentStyle.flash, 1)],
          partners: const [' Ingrid ', ''],
          startAt: start,
          endAt: end,
        );
    final start = DateTime.utc(2026, 11, 7, 17, 2);
    final end = DateTime.utc(2026, 11, 7, 19, 15);
    final id = await logger.logIndoor(live(start, end), userId: 'me');
    final session = (await SessionRepository(db).get(id))!;
    expect((session.startAt, session.endAt), (start, end));
    final members = await db.select(db.sessionMembers).get();
    expect(members.map((m) => (m.sessionId, m.guestName)), [(id, 'Ingrid')]);

    // Both or neither, in order, within a day, and not ahead of the clock.
    for (final (s, e) in [
      (start, null),
      (null, end),
      (end, start),
      (start.subtract(const Duration(days: 2)), end),
      (start, DateTime.utc(2026, 11, 9)),
    ]) {
      await expectLater(
        logger.logIndoor(live(s, e), userId: 'me'),
        throwsArgumentError,
      );
    }
  });
}
