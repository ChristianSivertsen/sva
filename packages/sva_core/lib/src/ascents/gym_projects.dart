import 'package:sva_core/src/ascents/ascent_rules.dart';

/// Whether a gym route is still an open project: tried, not sent, and not
/// [retired] (gone, or its wall was reset). Gym routes have no timer
/// (PLAN.md decision 4), so nothing else ends a project.
bool isOpenProject(RouteHistory history, {required bool retired}) =>
    !retired && !history.sent && history.earlierTries > 0;
