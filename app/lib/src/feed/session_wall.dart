import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva_core/sva_core.dart' show gradeBand;
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// An indoor session's wall image, for the feed card and the session page:
/// one cluster of holds per climb, in its colour at a colour gym or its
/// grade's shade at a graded gym. Nothing until every climb's label is
/// loaded, so holds never change colour once shown, and nothing for a
/// session without climbs.
class SessionWall extends ConsumerWidget {
  const new({required this.session, required this.climbs, super.key});

  final Session session;
  final List<Ascent> climbs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ids = {for (final c in climbs) c.routeId};
    final labels = {
      for (final id in ids)
        if (ref.watch(gymRouteLabelProvider(id)) case AsyncData(:final value))
          id: value,
    };
    if (climbs.isEmpty || labels.length < ids.length) {
      return const SizedBox.shrink();
    }
    final gym =
        switch (session.areaId) {
          final id? => ref.watch(placeNameProvider(id)).value,
          null => null,
        } ??
        l10n.feedSetting(session.setting);
    final brightness = Theme.of(context).brightness;
    return SvaGymWall(
      holds: [for (final c in climbs) _hold(labels[c.routeId], brightness)],
      label: l10n.wallLabel(gym, climbs.length),
      semanticLabel: l10n.wallSemantics(gym, climbs.length),
      seed: session.id,
    );
  }

  /// A stored gym colour, `#RRGGBB`.
  static final _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// The colour of a climb's holds: its gym colour, its grade's shade, or
  /// `null` for plain holds, also when a stored colour is malformed.
  static Color? _hold(GymRouteLabel? label, Brightness brightness) {
    if (label?.colourHex case final hex?) {
      return _hex.hasMatch(hex) ? gymColourFromHex(hex) : null;
    }
    if ((label?.gradeScore, label?.gradeType) case (
      final score?,
      final type?,
    )) {
      if (gradeBand(score, type) case (:final band, :final depth)) {
        return gymGradeShade(brightness, band, depth);
      }
    }
    return null;
  }
}
