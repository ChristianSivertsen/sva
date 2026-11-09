import 'package:flutter/material.dart';
import 'package:sva_core/sva_core.dart' show Grade, GradeSystem;
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// One tile in the gym log: a colour of the gym, a grade in a graded gym,
/// or the one tile of an ungraded gym (no colour and no grade).
typedef GymTile = ({
  String label,
  Color? fill,
  String? colourId,
  String? gradeId,
});

/// The tiles of a gym: its colours easiest first, the grades of [system]
/// in a graded gym, or one tile named [ungraded] for an ungraded gym.
List<GymTile> gymTiles(
  GymSetup setup, {
  required GradeSystem? system,
  required String ungraded,
}) => switch (setup.grading) {
  'colour' => [
    for (final c in setup.colours)
      (
        label: c.name,
        fill: gymColourFromHex(c.colourHex),
        colourId: c.id,
        gradeId: null,
      ),
  ],
  'standard' => [
    for (final g in system?.grades ?? const <Grade>[])
      (
        label: g.label,
        fill: null,
        colourId: null,
        gradeId: seedId('grade:${system!.key}:${g.label}'),
      ),
  ],
  _ => [(label: ungraded, fill: null, colourId: null, gradeId: null)],
};

/// A tile to tap when you top it: large, so it is easy to hit with chalky
/// hands, in the gym's own colour.
class GymTileButton extends StatelessWidget {
  const new({
    required this.tile,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final GymTile tile;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.svaColors;
    final fill = tile.fill ?? colors.surfaceSunk;
    // The label in whichever of the theme's darkest and lightest colours
    // reads best on the gym's own colour.
    final (
      dark,
      light,
    ) = colors.text.computeLuminance() < colors.background.computeLuminance()
        ? (colors.text, colors.background)
        : (colors.background, colors.text);
    final ink = tile.fill == null
        ? colors.text
        : fill.computeLuminance() > 0.4
        ? dark
        : light;
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SvaRadius.card),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(SvaRadius.card),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: SvaSpace.huge * 2,
              minHeight: SvaSpace.huge * 1.5,
            ),
            child: Padding(
              padding: const EdgeInsets.all(SvaSpace.sm),
              child: Center(
                widthFactor: 1,
                child: Text(
                  tile.label,
                  style: context.svaText.headline.copyWith(color: ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
