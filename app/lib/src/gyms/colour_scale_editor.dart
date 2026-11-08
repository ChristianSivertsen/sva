import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva_core/sva_core.dart'
    show Grade, GradeSystem, ScoreRange, colourRange;
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// One colour while the gym form edits it.
class ColourEntry {
  new({
    required String name,
    required String hex,
    this.id,
    this.boulder,
    this.route,
  }) : name = TextEditingController(text: name),
       colour = gymColourFromHex(hex);

  /// The colour as stored.
  new fromRow(GymColourGrade row)
    : this(
        id: row.id,
        name: row.name,
        hex: row.colourHex,
        boulder: _range(row.boulderMinScore, row.boulderMaxScore),
        route: _range(row.routeMinScore, row.routeMaxScore),
      );

  final String? id;
  final TextEditingController name;
  Color colour;
  ScoreRange? boulder;
  ScoreRange? route;

  /// A unique key, so removing or moving a colour keeps the others'
  /// fields.
  final key = UniqueKey();

  /// What the gym editor saves.
  ColourDraft get draft => ColourDraft(
    id: id,
    name: name.text,
    colourHex: gymColourToHex(colour),
    boulder: boulder,
    route: route,
  );

  static ScoreRange? _range(double? min, double? max) =>
      min == null || max == null ? null : (min: min, max: max);

  void dispose() => name.dispose();
}

/// The colours a new gym starts with, easiest first, as in the prototype.
List<ColourEntry> defaultColours(AppLocalizations l10n) => [
  ColourEntry(name: l10n.gymColourGreen, hex: '#3FA34D'),
  ColourEntry(name: l10n.gymColourBlue, hex: '#2F6FD1'),
];

/// A gym's colours, easiest first: each with a name, its colour, and
/// optional boulder and route ranges in the grade systems chosen in
/// settings. Colours can be added, moved up and removed.
class ColourScaleEditor extends ConsumerWidget {
  const new({required this.colours, required this.onChanged, super.key});

  final List<ColourEntry> colours;

  /// Called after the list or a colour changed, so the form redraws.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    final systems = ref.watch(gradeSystemsProvider).value ?? const [];
    final settings = ref.watch(settingsProvider).value ?? const Settings();
    GradeSystem? systemFor(String type) => systems
        .where((s) => s.key == settings.gradeSystemFor(type))
        .firstOrNull;
    final boulders = systemFor('boulder');
    final routes = systemFor('free_route');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: SvaSpace.xl, bottom: SvaSpace.xs),
          child: Semantics(
            header: true,
            child: Text(l10n.gymFormColours, style: text.headline),
          ),
        ),
        Text(
          l10n.gymFormColoursNote,
          style: text.caption.copyWith(color: context.svaColors.textMuted),
        ),
        for (final (i, colour) in colours.indexed) ...[
          const SizedBox(height: SvaSpace.sm),
          _ColourCard(
            key: colour.key,
            colour: colour,
            boulders: boulders,
            routes: routes,
            onChanged: onChanged,
            onMoveUp: i == 0
                ? null
                : () {
                    colours
                      ..removeAt(i)
                      ..insert(i - 1, colour);
                    onChanged();
                  },
            onRemove: () {
              colours.removeAt(i);
              colour.dispose();
              onChanged();
            },
          ),
        ],
        const SizedBox(height: SvaSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              colours.add(
                ColourEntry(
                  name: l10n.gymColourNew(colours.length + 1),
                  // Grey until the user picks the colour.
                  hex: '#808080',
                ),
              );
              onChanged();
            },
            icon: const Icon(LucideIcons.plus),
            label: Text(l10n.gymFormColourAdd),
          ),
        ),
      ],
    );
  }
}

class _ColourCard extends StatelessWidget {
  const new({
    required this.colour,
    required this.boulders,
    required this.routes,
    required this.onChanged,
    required this.onMoveUp,
    required this.onRemove,
    super.key,
  });

  final ColourEntry colour;

  /// The systems ranges are picked in, `null` until they load.
  final GradeSystem? boulders;
  final GradeSystem? routes;
  final VoidCallback onChanged;

  /// `null` for the easiest colour.
  final VoidCallback? onMoveUp;
  final VoidCallback onRemove;

  Future<void> _pick(BuildContext context) async {
    final picked = await showColorPickerDialog(
      context,
      colour.colour,
      pickersEnabled: const {
        ColorPickerType.both: true,
        ColorPickerType.primary: false,
        ColorPickerType.accent: false,
        ColorPickerType.wheel: true,
      },
    );
    colour.colour = picked;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(SvaSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: SvaSpace.sm,
          children: [
            ListenableBuilder(
              // Labels follow the name as it is typed, for screen readers.
              listenable: colour.name,
              builder: (context, _) => Row(
                children: [
                  Semantics(
                    button: true,
                    label: l10n.gymFormColourPick(colour.name.text),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => _pick(context),
                      customBorder: const CircleBorder(),
                      child: SizedBox.square(
                        dimension: SvaSpace.minTouchTarget,
                        child: Center(
                          child: DecoratedBox(
                            // The gym's own colour: data, not a theme token.
                            decoration: BoxDecoration(
                              color: colour.colour,
                              shape: BoxShape.circle,
                              border: Border.all(color: context.svaColors.line),
                            ),
                            child: const SizedBox.square(
                              dimension: SvaSpace.xxl,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SvaSpace.sm),
                  Expanded(
                    child: TextFormField(
                      controller: colour.name,
                      decoration: InputDecoration(
                        labelText: l10n.gymFormColourName,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: maxNameLength,
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? l10n.gymFormColourNameMissing
                          : null,
                    ),
                  ),
                  if (onMoveUp != null)
                    IconButton(
                      tooltip: l10n.gymFormColourEasier(colour.name.text),
                      onPressed: onMoveUp,
                      icon: const Icon(LucideIcons.arrowUp),
                    ),
                  IconButton(
                    tooltip: l10n.gymFormColourRemove(colour.name.text),
                    onPressed: onRemove,
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
            ),
            if (boulders case final system?)
              _RangePicker(
                label: l10n.gymFormColourBoulders,
                system: system,
                range: colour.boulder,
                onChanged: (range) {
                  colour.boulder = range;
                  onChanged();
                },
              ),
            if (routes case final system?)
              _RangePicker(
                label: l10n.gymFormColourRoutes,
                system: system,
                range: colour.route,
                onChanged: (range) {
                  colour.route = range;
                  onChanged();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// An optional range from one grade to another in [system]. Picking only
/// the easiest grade makes a one-grade range; "Not mapped" clears it.
class _RangePicker extends StatelessWidget {
  const new({
    required this.label,
    required this.system,
    required this.range,
    required this.onChanged,
  });

  final String label;
  final GradeSystem system;
  final ScoreRange? range;
  final ValueChanged<ScoreRange?> onChanged;

  /// The grade a range starts or ends at, in [system].
  Grade? _at(double? score, {required bool start}) {
    if (score == null) return null;
    final exact = system.grades.where(
      (g) => (start ? g.scoreLow : g.scoreHigh) == score,
    );
    return exact.firstOrNull ?? system.nearest(score);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final from = _at(range?.min, start: true);
    final to = _at(range?.max, start: false);
    DropdownMenuItem<Grade?> item(Grade? grade) => DropdownMenuItem(
      value: grade,
      child: Text(grade?.label ?? l10n.gymFormColourUnmapped),
    );
    return Wrap(
      spacing: SvaSpace.sm,
      runSpacing: SvaSpace.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          // Lines the two pickers up under each other.
          width: SvaSpace.huge * 2,
          child: Text(label, style: context.svaText.label),
        ),
        DropdownButton<Grade?>(
          value: from,
          hint: Text(l10n.gymFormColourUnmapped),
          items: [item(null), for (final g in system.grades) item(g)],
          onChanged: (grade) => onChanged(switch (grade) {
            null => null,
            // A harder end that is still fine stays; otherwise the range
            // becomes the one grade.
            final grade when to != null && to.scoreHigh >= grade.scoreLow =>
              colourRange(grade, to),
            final grade => colourRange(grade, grade),
          }),
        ),
        if (from != null) ...[
          Text(l10n.gymFormColourTo),
          DropdownButton<Grade>(
            value: to,
            items: [
              for (final g in system.grades)
                if (g.scoreHigh >= from.scoreLow)
                  DropdownMenuItem(value: g, child: Text(g.label)),
            ],
            onChanged: (grade) =>
                onChanged(grade == null ? null : colourRange(from, grade)),
          ),
        ],
      ],
    );
  }
}
