import 'package:sva_core/sva_core.dart';
import 'package:test/test.dart';

void main() {
  double score(GradeSystem system, String label) =>
      system.grades.firstWhere((g) => g.label == label).score;

  test('M3-9: grades fall in four bands that deepen with difficulty', () {
    // Each band starts pale and ends deep.
    expect(gradeBand(score(vScale, 'VB'), 'boulder'), (band: 0, depth: 0.0));
    expect(gradeBand(score(vScale, 'V2'), 'boulder'), (band: 0, depth: 1.0));
    expect(gradeBand(score(vScale, 'V3'), 'boulder')?.band, 1);
    expect(gradeBand(score(vScale, 'V6'), 'boulder'), (band: 1, depth: 1.0));
    expect(gradeBand(score(vScale, 'V7'), 'boulder'), (band: 2, depth: 0.0));
    expect(gradeBand(score(vScale, 'V11'), 'boulder'), (band: 3, depth: 0.0));
    expect(gradeBand(score(vScale, 'V17'), 'boulder'), (band: 3, depth: 1.0));
    expect(gradeBand(score(french, '5c'), 'free_route'), (band: 0, depth: 1.0));
    expect(gradeBand(score(french, '6a'), 'free_route'), (band: 1, depth: 0.0));
    expect(gradeBand(score(french, '7a'), 'free_route'), (band: 2, depth: 0.0));
    expect(gradeBand(score(french, '8a+'), 'free_route')?.band, 3);
    // Other systems land in the same bands by score.
    expect(gradeBand(score(norwegian, '7'), 'free_route')?.band, 1);
    // Beyond either end stays in the end bands.
    expect(gradeBand(2, 'free_route'), (band: 0, depth: 0.0));
    expect(gradeBand(50, 'boulder'), (band: 3, depth: 1.0));
    expect(gradeBand(15, 'ice'), isNull);
  });
}
