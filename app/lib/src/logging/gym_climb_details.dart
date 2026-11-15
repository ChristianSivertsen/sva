import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/places/form_parts.dart';
import 'package:sva_core/sva_core.dart'
    show AscentStyle, GymTapEntry, maxTriesPerTap;
import 'package:sva_data/sva_data.dart' show attributeSeed, maxBetaLength;
import 'package:sva_ui/sva_ui.dart';

/// What a climb's result can be: `send` (topped, clean on a rope),
/// `rests` (topped with rests on a rope) or `no` (didn't top).
String climbResult(GymTapEntry e) => !e.topped
    ? 'no'
    : e.rested
    ? 'rests'
    : 'send';

/// The details of one gym climb, for when you want them
/// (prototype/gym-log.html, `editHTML`): result, tries, rope type, wall,
/// angle, your grade, main holds, movement and beta. The gym log owns the
/// values; this shows them and reports changes.
class GymClimbDetails extends StatelessWidget {
  const new({
    required this.title,
    required this.entry,
    required this.style,
    required this.walls,
    required this.wallId,
    required this.angle,
    required this.wallAngle,
    required this.grades,
    required this.gradeId,
    required this.holds,
    required this.movement,
    required this.beta,
    required this.onResult,
    required this.onTries,
    required this.onRopeType,
    required this.onWall,
    required this.onAngle,
    required this.onGrade,
    required this.onHolds,
    required this.onMovement,
    required this.onBeta,
    required this.onRemove,
    required this.onDone,
    super.key,
  });

  /// Such as `Blue, boulder`.
  final String title;
  final GymTapEntry entry;
  final AscentStyle style;

  /// The walls of the climb's kind: id and name.
  final List<(String, String)> walls;
  final String wallId;

  /// The climb's `angle.*` key, and its wall's.
  final String? angle;
  final String? wallAngle;

  /// Five grades around the climb's, as id and label; empty when the gym's
  /// grade for it is unknown.
  final List<(String, String)> grades;
  final String? gradeId;
  final Set<String> holds;
  final Set<String> movement;
  final String beta;

  /// With [climbResult]'s values.
  final ValueChanged<String> onResult;
  final ValueChanged<int> onTries;
  final ValueChanged<String> onRopeType;
  final ValueChanged<String> onWall;
  final ValueChanged<String?> onAngle;
  final ValueChanged<String?> onGrade;
  final ValueChanged<Set<String>> onHolds;
  final ValueChanged<Set<String>> onMovement;
  final ValueChanged<String> onBeta;
  final VoidCallback onRemove;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    final colors = context.svaColors;
    final muted = text.caption.copyWith(color: colors.textMuted);
    final rope = entry.ropeType != null;
    List<(String, String)> options(String key) => [
      for (final value
          in attributeSeed.firstWhere((d) => d.key == key).valueKeys)
        (value, l10n.attributeValue(value.replaceAll('.', '_'))),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SvaSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: SvaSpace.md,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: text.headline),
                  ),
                ),
                SvaStyleTag(
                  style: style.name,
                  label: l10n.ascentStyle(style.name),
                ),
              ],
            ),
            ChipGroup(
              label: l10n.logIndoorResult,
              options: [
                if (rope) ...[
                  ('send', l10n.logIndoorResultClean),
                  ('rests', l10n.logIndoorResultRests),
                ] else
                  ('send', l10n.logIndoorResultTopped),
                ('no', l10n.logIndoorDidntTop),
              ],
              selected: {climbResult(entry)},
              onChanged: (v) {
                if (v.isNotEmpty) onResult(v.single);
              },
            ),
            if (entry.topped && grades.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: SvaSpace.xs,
                children: [
                  ChipGroup(
                    label: l10n.logIndoorMyGrade,
                    options: grades,
                    selected: {?gradeId},
                    // Tap the picked grade again to clear it.
                    onChanged: (v) => onGrade(v.firstOrNull),
                  ),
                  Text(l10n.logIndoorMyGradeHint, style: muted),
                ],
              ),
            Row(
              children: [
                Expanded(child: Text(l10n.logIndoorTries, style: text.label)),
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
            if (entry.ropeType case final type?)
              ChipGroup(
                label: l10n.logIndoorRopeType,
                options: [
                  for (final t in const ['lead', 'toprope'])
                    (t, l10n.ascentType(t)),
                ],
                selected: {type},
                onChanged: (v) {
                  if (v.isNotEmpty) onRopeType(v.single);
                },
              ),
            if (walls.length > 1)
              ChipGroup(
                label: l10n.logIndoorWall,
                options: walls,
                selected: {wallId},
                onChanged: (v) {
                  if (v.isNotEmpty) onWall(v.single);
                },
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: SvaSpace.xs,
              children: [
                ChipGroup(
                  label: l10n.logIndoorAngle,
                  options: options('angle'),
                  selected: {?angle},
                  onChanged: (v) => onAngle(v.firstOrNull),
                ),
                if (angle != null && angle == wallAngle)
                  Text(l10n.logIndoorAngleFromWall, style: muted),
              ],
            ),
            ChipGroup(
              label: l10n.logIndoorHolds,
              options: options('climb_hold'),
              selected: holds,
              multi: true,
              onChanged: onHolds,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: SvaSpace.xs,
              children: [
                ChipGroup(
                  label: l10n.logIndoorMovement,
                  options: options('movement'),
                  selected: movement,
                  multi: true,
                  onChanged: onMovement,
                ),
                Text(l10n.logIndoorStyleNote, style: muted),
              ],
            ),
            TextFormField(
              initialValue: beta,
              decoration: InputDecoration(
                labelText: l10n.logIndoorBeta,
                hintText: l10n.logIndoorBetaHint,
                helperText: l10n.logIndoorBetaNote,
              ),
              maxLength: maxBetaLength,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: onBeta,
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.danger,
                side: BorderSide(color: colors.danger),
              ),
              onPressed: onRemove,
              child: Text(l10n.logIndoorRemoveClimb),
            ),
            FilledButton(onPressed: onDone, child: Text(l10n.logIndoorDone)),
          ],
        ),
      ),
    );
  }
}
