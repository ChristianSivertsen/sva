import 'package:sva_core/sva_core.dart';
import 'package:test/test.dart';

void main() {
  test('M3-6: setting degrees sets the matching angle type', () {
    const cases = {
      -45: 'angle.slab',
      -1: 'angle.slab',
      0: 'angle.vertical',
      5: 'angle.vertical',
      6: 'angle.overhang',
      30: 'angle.overhang',
      60: 'angle.overhang',
      61: 'angle.roof',
      90: 'angle.roof',
    };
    for (final MapEntry(key: deg, value: angle) in cases.entries) {
      expect(angleForDegrees(deg), angle, reason: '$deg°');
    }
    // Only whole degrees from -45 to 90 are wall angles.
    expect(isWallAngleDeg(minWallAngleDeg), isTrue);
    expect(isWallAngleDeg(maxWallAngleDeg), isTrue);
    expect(isWallAngleDeg(-46), isFalse);
    expect(isWallAngleDeg(91), isFalse);
    expect(() => angleForDegrees(91), throwsArgumentError);
  });
}
