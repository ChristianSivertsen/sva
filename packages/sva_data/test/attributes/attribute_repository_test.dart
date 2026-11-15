import 'package:drift/native.dart';
import 'package:sva_core/sva_core.dart';
import 'package:sva_data/sva_data.dart';
import 'package:test/test.dart';

void main() {
  late SvaDatabase db;
  late AttributeRepository repo;
  final now = DateTime.utc(2026, 11);

  setUp(() {
    db = SvaDatabase(NativeDatabase.memory());
    repo = AttributeRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<void> addArea(String id, {String? parentId, String? rock}) => db
      .into(db.areas)
      .insert(
        AreasCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          visibility: 'public',
          parentId: Value(parentId),
          type: parentId == null ? 'crag' : 'sector',
          name: id,
          countryCode: 'NO',
          rockType: Value(rock),
        ),
      );

  // Routes are the test user's private routes unless said otherwise.
  Future<void> addRoute(
    String id,
    String areaId, {
    String? angle,
    String visibility = 'private',
  }) => db
      .into(db.routes)
      .insert(
        RoutesCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          visibility: visibility,
          createdBy: const Value('me'),
          areaId: areaId,
          kind: 'outdoor',
          discipline: 'sport',
          status: 'open',
          angle: Value(angle),
        ),
      );

  Future<void> addAscent(String id, String routeId, {String? feel}) => db
      .into(db.ascents)
      .insert(
        AscentsCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          ownerId: 'me',
          visibility: 'friends',
          sessionId: 'session',
          routeId: routeId,
          ordinal: 1,
          ascentType: 'lead',
          style: 'redpoint',
          tries: 3,
          setting: 'outdoor',
          discipline: 'sport',
          feel: Value(feel),
        ),
      );

  Future<void> setHolds(String routeId, List<String> holds, {String? by}) =>
      repo.setRouteAttribute(routeId, 'hold', holds, userId: by ?? 'me');

  test('M1-2: seeded attribute definitions load', () async {
    await repo.seed();
    await repo.seed(); // seeding again updates instead of duplicating

    final loaded = await repo.definitions();
    expect(loaded, hasLength(attributeSeed.length));
    for (final def in attributeSeed) {
      final match = loaded.singleWhere((d) => d.key == def.key);
      expect(match.level, def.level, reason: def.key);
      expect(match.valueType, def.valueType, reason: def.key);
      expect(match.valueKeys, def.valueKeys, reason: def.key);
    }
    final rows = await db.select(db.attributeDefs).get();
    expect(
      rows.map((row) => row.id),
      containsAll(attributeSeed.map((d) => seedId('attribute_def:${d.key}'))),
      reason: 'seeded ids are the same on every device',
    );
    final ascentDefs = await repo.definitions(level: AttributeLevel.ascent);
    expect(ascentDefs.map((d) => d.key), [
      'feel',
      'tag',
      'climb_hold',
      'movement',
    ]);
  });

  test(
    'M1-2: an ascent resolves values from its crag, route and itself',
    () async {
      await repo.seed();
      await addArea('crag', rock: 'rock.gneiss');
      // The sector is nearer the route, so its rock wins over the crag's.
      await addArea('sector', parentId: 'crag', rock: 'rock.granite');
      await addRoute('route', 'sector', angle: 'angle.overhang');
      await setHolds('route', ['hold.pinch', 'hold.jug']);
      await addAscent('ascent', 'route', feel: 'feel.hard');
      await repo.setAscentAttribute('ascent', 'tag', [
        'tag.pumpy',
      ], userId: 'me');

      expect(await repo.resolvedForAscent('ascent'), {
        'rock_type': ['rock.granite'],
        'discipline': ['sport'],
        'angle': ['angle.overhang'],
        'hold': ['hold.jug', 'hold.pinch'],
        'feel': ['feel.hard'],
        'tag': ['tag.pumpy'],
      });
    },
  );

  test('M1-2: adding a definition in seed data needs no code change', () async {
    const surface = AttributeDef(
      key: 'surface',
      level: AttributeLevel.route,
      valueType: AttributeValueType.multi,
      valueKeys: ['surface.polished', 'surface.lichen'],
      sort: 99,
    );
    await repo.seed([...attributeSeed, surface]);
    await addArea('crag', rock: 'rock.limestone');
    await addRoute('route', 'crag');
    await addAscent('ascent', 'route');

    final routeDefs = await repo.definitions(level: AttributeLevel.route);
    expect(routeDefs.last.key, 'surface');

    await repo.setRouteAttribute('route', 'surface', [
      'surface.lichen',
    ], userId: 'me');
    expect((await repo.resolvedForAscent('ascent'))['surface'], [
      'surface.lichen',
    ]);

    // The same checks guard new attributes as existing ones.
    expect(
      () => repo.setRouteAttribute('route', 'surface', [
        'surface.mud',
      ], userId: 'me'),
      throwsArgumentError,
    );
    expect(
      () => repo.setRouteAttribute('route', 'angle', [
        'angle.slab',
      ], userId: 'me'),
      throwsArgumentError,
      reason: 'typed columns are written with the route',
    );
    expect(
      () => repo.setRouteAttribute('route', 'unknown', ['x'], userId: 'me'),
      throwsArgumentError,
    );
  });

  test('M1-2: changing values soft-deletes and revives rows', () async {
    await repo.seed();
    await addArea('crag');
    await addRoute('route', 'crag');
    Future<List<RouteAttribute>> rows() => db.select(db.routeAttributes).get();

    await setHolds('route', ['hold.crimp', 'hold.jug']);
    final first = await rows();
    await setHolds('route', ['hold.jug']);
    expect(
      (await rows()).where((r) => r.deletedAt != null).map((r) => r.value),
      ['hold.crimp'],
    );
    await setHolds('route', ['hold.jug', 'hold.crimp']);

    final last = await rows();
    expect(last, hasLength(2), reason: 'rows are never removed');
    expect(
      last.map((r) => r.id).toSet(),
      first.map((r) => r.id).toSet(),
      reason: 'a value that comes back keeps its id',
    );
    expect(last.every((r) => r.deletedAt == null), isTrue);
  });

  test('M1-2: only the owner writes, and only on private routes', () async {
    await repo.seed();
    await addArea('crag');
    await addRoute('public', 'crag', visibility: 'public');
    await addRoute('mine', 'crag');
    await addAscent('ascent', 'mine');

    expect(
      () => setHolds('public', ['hold.jug']),
      throwsStateError,
      reason: 'public routes change through moderated requests',
    );
    expect(
      () => setHolds('mine', ['hold.jug'], by: 'someone else'),
      throwsStateError,
    );
    expect(
      () => repo.setAscentAttribute('ascent', 'tag', [
        'tag.pumpy',
      ], userId: 'someone else'),
      throwsStateError,
    );

    await repo.setAscentAttribute('ascent', 'tag', ['tag.pumpy'], userId: 'me');
    final row = await db.select(db.ascentAttributes).getSingle();
    expect((row.ownerId, row.visibility), ('me', 'friends'));
  });

  test('M1-2: bad definitions and area loops are handled', () async {
    await repo.seed();
    final count = (await repo.definitions()).length;
    // A definition from a newer app version, one with broken value keys,
    // and one the server deleted are all left out.
    for (final (key, level, json, deleted) in [
      ('galaxy', 'galaxy', '[]', null),
      ('broken', 'route', '[1, 2]', null),
      ('gone', 'route', '["a"]', now),
    ]) {
      await db
          .into(db.attributeDefs)
          .insert(
            AttributeDefsCompanion.insert(
              id: key,
              createdAt: now,
              updatedAt: now,
              deletedAt: Value(deleted),
              key: key,
              level: level,
              valueType: 'multi',
              valueKeys: Value(json),
              sort: 1,
            ),
          );
    }
    expect(await repo.definitions(), hasLength(count));

    expect(
      () => repo.seed([
        const AttributeDef(
          key: 'parking',
          level: AttributeLevel.area,
          valueType: AttributeValueType.bool,
        ),
      ]),
      throwsArgumentError,
      reason: 'areas have no attribute table yet',
    );

    // Two areas that are each other's parent still resolve.
    await addArea('a', parentId: 'b', rock: 'rock.basalt');
    await addArea('b', parentId: 'a');
    await addRoute('route', 'a');
    await addAscent('ascent', 'route');
    expect((await repo.resolvedForAscent('ascent'))['rock_type'], [
      'rock.basalt',
    ]);
  });
}
