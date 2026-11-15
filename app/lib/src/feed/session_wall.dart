import 'package:flutter/material.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva_core/sva_core.dart' show gradeBand;
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// An indoor session's wall image: one cluster of holds per climb, in its
/// colour at a colour gym or its grade's shade at a graded gym. `null`
/// until every climb's label is loaded, so holds never change colour once
/// shown, and for a session without climbs.
Widget? sessionWall(
  BuildContext context, {
  required String sessionId,
  required String gym,
  required List<Ascent> climbs,
  required Map<String, GymRouteLabel?> labels,
}) {
  if (climbs.isEmpty) return null;
  if (climbs.any((c) => !labels.containsKey(c.routeId))) return null;
  final l10n = AppLocalizations.of(context);
  final brightness = Theme.of(context).brightness;
  Color? hold(GymRouteLabel? label) {
    if (label?.colourHex case final hex?) return gymColourFromHex(hex);
    if ((label?.gradeScore, label?.gradeType) case (
      final score?,
      final type?,
    )) {
      if (gradeBand(score, type) case final band?) {
        return gymGradeShade(brightness, band.band, band.depth);
      }
    }
    return null;
  }

  return SvaGymWall(
    holds: [for (final c in climbs) hold(labels[c.routeId])],
    label: l10n.wallLabel(gym, climbs.length),
    semanticLabel: l10n.wallSemantics(gym, climbs.length),
    seed: sessionId,
  );
}
