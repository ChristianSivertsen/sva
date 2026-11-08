import 'package:sva_core/src/ascents/ascent_rules.dart';

/// Whether a gym route is still an open project: tried, not sent, and not
/// [retired] (gone, or its wall was reset). Gym routes have no timer
/// (PLAN.md decision 4), so nothing else ends a project.
bool isOpenProject(RouteHistory history, {required bool retired}) =>
    !retired && !history.sent && history.earlierTries > 0;

/// What a tap in the gym log means for a route with [history]: topped
/// ([topped]) or not, after [tries] tries this time. Not topped is an
/// attempt; topped is a repeat once sent, a flash on a first try with no
/// earlier tries, and otherwise a redpoint, whose tries count the earlier
/// attempts (PLAN.md decision 7).
LoggedAscent gymTap(
  RouteHistory history, {
  required bool topped,
  required int tries,
}) {
  if (!topped) return (style: AscentStyle.attempt, tries: tries);
  if (history.sent) return (style: AscentStyle.repeat, tries: tries);
  if (history.earlierTries == 0 && tries == 1) {
    return (style: AscentStyle.flash, tries: 1);
  }
  return (style: AscentStyle.redpoint, tries: history.earlierTries + tries);
}
