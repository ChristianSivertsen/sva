import 'package:sva_core/sva_core.dart';
import 'package:test/test.dart';

void main() {
  final nor = gradeSystems.firstWhere((s) => s.key == 'nor');

  test('M3-2: a colour scores at the middle of its range, and an unmapped '
      'colour still counts outside grade stats', () {
    // Blue spans Norwegian 6- to 6+.
    final blue = colourRange(nor.parse('6-')!, nor.parse('6+')!);
    expect(blue.min, nor.parse('6-')!.scoreLow);
    expect(blue.max, nor.parse('6+')!.scoreHigh);
    expect(colourScore(blue), (blue.min + blue.max) / 2);
    expect(nor.nearest(colourScore(blue)!).label, '6');

    // A single-grade colour scores at that grade.
    final seven = nor.parse('7')!;
    expect(colourScore(colourRange(seven, seven)), closeTo(seven.score, 0.5));

    // Without a range a climb has no grade score: grade charts leave it
    // out, while volume, angle and hold stats count it (M6-1).
    expect(colourScore(null), isNull);
    expect(countsInGradeStats(colourScore(null)), isFalse);
    expect(countsInGradeStats(colourScore(blue)), isTrue);

    // A range runs easiest to hardest.
    expect(
      () => colourRange(nor.parse('7')!, nor.parse('6')!),
      throwsArgumentError,
    );
  });
}
