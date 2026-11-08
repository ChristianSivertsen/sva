import 'package:sva_core/sva_core.dart' show AscentStyle;
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
}
