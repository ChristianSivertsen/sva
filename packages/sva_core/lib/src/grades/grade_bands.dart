/// Where a grade sits in the four bands a graded gym's climbs are shaded
/// by: beginner, intermediate, advanced and elite. `band` is 0 to 3, and
/// `depth` goes from 0 for the band's easiest grade to 1 for its hardest,
/// so a band starts pale again and the step up is easy to see
/// (prototype/gym-log.html, `ramp`).
typedef GradeBand = ({int band, double depth});

/// The shared-scale scores (see grade_tables.dart) of each band's easiest
/// and hardest grade. Boulders: up to V2, V3 to V6, V7 to V10, then V11
/// and up. Routes: up to 5c, 6a to 6c+, 7a to 8a, then 8a+ and up.
const _bands = {
  'boulder': [(10.0, 13.5), (14.0, 20.0), (21.0, 25.0), (26.0, 32.0)],
  'free_route': [(8.0, 14.0), (15.0, 20.0), (21.0, 27.0), (28.0, 37.0)],
};

/// The band of a grade at [score] on the shared scale for [gradeType]
/// (`boulder` or `free_route`), or `null` for any other grade type.
GradeBand? gradeBand(double score, String gradeType) {
  final bands = _bands[gradeType];
  if (bands == null) return null;
  final band = bands.lastIndexWhere((b) => score >= b.$1).clamp(0, 3);
  final (low, high) = bands[band];
  return (band: band, depth: ((score - low) / (high - low)).clamp(0.0, 1.0));
}
