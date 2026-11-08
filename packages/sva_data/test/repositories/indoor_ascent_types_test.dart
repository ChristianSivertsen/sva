import 'package:sva_data/sva_data.dart';
import 'package:test/test.dart';

void main() {
  test('M3-5: logging an indoor climb with auto_belay is rejected', () async {
    final db = SvaDatabase.inMemory();
    addTearDown(db.close);
    await AttributeRepository(db).seed();
    final gyms = GymEditor(db);
    final gymId = await gyms.addGym(
      const NewGym(name: 'Gnisten', countryCode: 'NO', grading: 'none'),
      walls: const [WallDraft(name: 'Main wall', kind: 'rope')],
      userId: 'me',
    );
    final wall = (await gyms.setup(gymId, userId: 'me'))!.walls.single.id;
    final route = await GymRouteRepository(db).add(
      NewGymRoute(wallId: wall, setOn: '2026-11-03'),
      userId: 'me',
    );
    final session = await SessionRepository(db).create(
      SessionsCompanion(
        setting: const Value('indoor'),
        localDate: const Value('2026-11-03'),
        tz: const Value('Europe/Oslo'),
        visibility: const Value('private'),
        areaId: Value(gymId),
      ),
      userId: 'me',
    );
    var ordinal = 0;
    Future<String> climb(String type) => AscentRepository(db).create(
      AscentsCompanion(
        sessionId: Value(session),
        routeId: Value(route),
        ordinal: Value(++ordinal),
        ascentType: Value(type),
        style: const Value('attempt'),
        tries: const Value(1),
      ),
      userId: 'me',
    );

    // An auto-belay climb logs as top rope (docs/schema.md, ascents).
    expect(() => climb('auto_belay'), throwsArgumentError);
    expect(indoorAscentTypes, {'lead', 'toprope', 'boulder'});
    for (final type in indoorAscentTypes) {
      expect(await climb(type), isNotEmpty);
    }
    expect(() => climb('solo'), throwsArgumentError);
    expect(
      await db.select(db.ascents).get(),
      hasLength(indoorAscentTypes.length),
      reason: 'nothing refused was saved',
    );
  });
}
