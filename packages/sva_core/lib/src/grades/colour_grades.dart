import 'package:sva_core/src/grades/grade_system.dart';

/// A gym colour's span on the shared difficulty scale for one grade type
/// (docs/schema.md, gym_colour_grades).
typedef ScoreRange = ({double min, double max});

/// The span from grade [easiest] to grade [hardest], both included. Throws
/// [ArgumentError] when [hardest] is easier than [easiest].
ScoreRange colourRange(Grade easiest, Grade hardest) {
  if (hardest.scoreHigh < easiest.scoreLow) {
    throw ArgumentError.value(hardest.label, 'hardest', 'easier than easiest');
  }
  return (min: easiest.scoreLow, max: hardest.scoreHigh);
}

/// The score a climb on a colour joins grade stats at: the middle of the
/// colour's [range], or `null` when the colour is not mapped.
double? colourScore(ScoreRange? range) =>
    range == null ? null : (range.min + range.max) / 2;

/// Whether a climb with [score] belongs in grade stats (pyramids, top
/// grades). A climb without a score, such as one on an unmapped gym
/// colour, is left out of those only: volume, angle and hold stats count
/// every climb.
bool countsInGradeStats(double? score) => score != null;
