import 'package:sva_core/sva_core.dart';
import 'package:test/test.dart';

void main() {
  test('M3-4: the nearest gym is found within a few kilometres', () {
    // Oslo: Klatreverket Torshov and Kolsås are about 15 km apart.
    const torshov = ('torshov', 59.9330, 10.7660);
    const kolsas = ('kolsas', 59.9180, 10.5040);
    const nowhere = ('nowhere', null, null);
    const places = [nowhere, kolsas, torshov];

    // A few hundred metres from Torshov.
    expect(nearestWithin(59.9350, 10.7700, places), 'torshov');
    expect(nearestWithin(59.9190, 10.5100, places), 'kolsas');
    // Between them, more than 3 km from each: none is "here".
    expect(nearestWithin(59.9250, 10.6350, places), isNull);
    expect(nearestWithin(59.9250, 10.6350, places, maxKm: 10), isNotNull);
    expect(nearestWithin(59.93, 10.77, const []), isNull);

    expect(distanceKm(59.9330, 10.7660, 59.9180, 10.5040), closeTo(14.7, 0.5));
  });
}
