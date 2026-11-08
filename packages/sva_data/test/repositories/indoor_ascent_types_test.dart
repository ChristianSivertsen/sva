import 'package:sva_data/sva_data.dart';
import 'package:test/test.dart';

void main() {
  late SvaDatabase db;
  late String route;
  late String gymId;
  var ordinal = 0;

  setUp(() async {
    db = SvaDatabase.inMemory();
    await AttributeRepository(db).seed();
    final gyms = GymEditor(db);
    gymId = await gyms.addGym(
      const NewGym(name: 'Gnisten', countryCode: 'NO', grading: 'none'),
      walls: const [WallDraft(name: 'Main wall', kind: 'rope')],
      userId: 'me',
    );
    final wall = (await gyms.setup(gymId, userId: 'me'))!.walls.single.id;
    route = await GymRouteRepository(db).add(
      NewGymRoute(wallId: wall, setOn: '2026-11-03'),
      userId: 'me',
    );
  });
  tearDown(() => db.close());

  Future<String> session(String setting) => SessionRepository(db).create(
    SessionsCompanion(
      setting: Value(setting),
      localDate: const Value('2026-11-03'),
      tz: const Value('Europe/Oslo'),
      visibility: const Value('private'),
      areaId: Value(gymId),
    ),
    userId: 'me',
  );
  Future<String> climb(String sessionId, String type) =>
      AscentRepository(db).create(
        AscentsCompanion(
          sessionId: Value(sessionId),
          routeId: Value(route),
          ordinal: Value(++ordinal),
          ascentType: Value(type),
          style: const Value('attempt'),
          tries: const Value(1),
        ),
        userId: 'me',
      );

  test('M3-5: logging an indoor climb with auto_belay is rejected', () async {
    final indoors = await session('indoor');
    // An auto-belay climb logs as top rope (docs/schema.md, ascents).
    await expectLater(climb(indoors, 'auto_belay'), throwsArgumentError);
    await expectLater(climb(indoors, 'solo'), throwsArgumentError);
    for (final type in indoorAscentTypes) {
      expect(await climb(indoors, type), isNotEmpty);
    }
    expect(
      await db.select(db.ascents).get(),
      hasLength(indoorAscentTypes.length),
      reason: 'nothing refused was saved',
    );
  });

  test('M3-5: an indoor climb cannot be changed to auto_belay', () async {
    final id = await climb(await session('indoor'), 'lead');
    await expectLater(
      AscentRepository(db).update(
        id,
        const AscentsCompanion(ascentType: Value('auto_belay')),
        userId: 'me',
      ),
      throwsArgumentError,
    );
    await AscentRepository(db).update(
      id,
      const AscentsCompanion(ascentType: Value('toprope')),
      userId: 'me',
    );
    expect((await AscentRepository(db).get(id))!.ascentType, 'toprope');
  });

  test('M3-5: the indoor check leaves outdoor climbs alone', () async {
    // Following is an outdoor type; the session logger checks those.
    expect(await climb(await session('outdoor'), 'follow'), isNotEmpty);
  });
}
