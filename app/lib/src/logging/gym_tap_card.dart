import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/places/form_parts.dart';
import 'package:sva_core/sva_core.dart'
    show AscentStyle, GymTapEntry, maxTriesPerTap;
import 'package:sva_ui/sva_ui.dart';

/// What the last tap logged, with quick changes: undo, not topped, tries,
/// and lead or top rope for a rope climb.
class GymTapCard extends StatelessWidget {
  const new({
    required this.entry,
    required this.style,
    required this.label,
    required this.onUndo,
    required this.onTopped,
    required this.onTries,
    required this.onRopeType,
    super.key,
  });

  final GymTapEntry entry;
  final AscentStyle style;

  /// The tile's label, such as `Blue`.
  final String label;
  final VoidCallback onUndo;
  final ValueChanged<bool> onTopped;
  final ValueChanged<int> onTries;
  final ValueChanged<String> onRopeType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(SvaSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: SvaSpace.sm,
          children: [
            Wrap(
              spacing: SvaSpace.xs,
              runSpacing: SvaSpace.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  entry.topped
                      ? l10n.logIndoorAddedSend(label)
                      : l10n.logIndoorAddedAttempt(label),
                  style: text.label,
                ),
                SvaStyleTag(
                  style: style.name,
                  label: l10n.ascentStyle(style.name),
                ),
                TextButton.icon(
                  onPressed: onUndo,
                  icon: const Icon(LucideIcons.undo2),
                  label: Text(l10n.logIndoorUndo),
                ),
              ],
            ),
            Wrap(
              spacing: SvaSpace.sm,
              runSpacing: SvaSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => onTopped(!entry.topped),
                  child: Text(
                    entry.topped
                        ? l10n.logIndoorDidntTop
                        : l10n.logIndoorToppedIt,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.logIndoorTries, style: text.label),
                    IconButton(
                      tooltip: l10n.logIndoorFewerTries,
                      onPressed: entry.tries > 1
                          ? () => onTries(entry.tries - 1)
                          : null,
                      icon: const Icon(LucideIcons.minus),
                    ),
                    Text('${entry.tries}', style: text.number),
                    IconButton(
                      tooltip: l10n.logIndoorMoreTries,
                      onPressed: entry.tries < maxTriesPerTap
                          ? () => onTries(entry.tries + 1)
                          : null,
                      icon: const Icon(LucideIcons.plus),
                    ),
                  ],
                ),
              ],
            ),
            if (entry.ropeType case final rope?)
              ChipGroup(
                label: l10n.logIndoorRopeType,
                options: [
                  for (final t in const ['lead', 'toprope'])
                    (t, l10n.ascentType(t)),
                ],
                selected: {rope},
                onChanged: (v) {
                  if (v.isNotEmpty) onRopeType(v.single);
                },
              ),
          ],
        ),
      ),
    );
  }
}
