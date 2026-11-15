import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva_data/sva_data.dart' show maxTitleLength;
import 'package:sva_ui/sva_ui.dart';

/// One colour or grade in the finish sheet's bars, and how its climbs
/// went.
typedef GymFinishBar = ({
  String label,
  int flash,
  int redpoint,
  int repeat,
  int attempt,
});

/// What you fill in when you finish: the title (empty for the filled-in
/// one), partners' names and who can see the session.
typedef GymFinishChoices = ({
  String? title,
  List<String> partners,
  String visibility,
});

/// Finishing a gym session (prototype/gym-log.html, `finishHTML`): how it
/// went, what is filled in, then title, partners and who can see it. The
/// gym log works out the numbers and saves; this shows them.
class GymFinishSheet extends StatefulWidget {
  const new({
    required this.stats,
    required this.projectSends,
    required this.bars,
    required this.bothKinds,
    required this.filledIn,
    required this.autoTitle,
    required this.visibility,
    required this.onSave,
    required this.onClose,
    super.key,
  });

  /// Climbs, sends, flashes, and metres on rope or the best send.
  final List<SvaCardStat> stats;

  /// One line for each project sent.
  final List<String> projectSends;
  final List<GymFinishBar> bars;

  /// Boulders and rope climbs in one session: the bars say which.
  final bool bothKinds;

  /// Such as `Gnisten · 18:02–20:15`.
  final String filledIn;

  /// The title used when it is left empty.
  final String autoTitle;

  /// Who can see it at first, from settings.
  final String visibility;

  /// Saves the session. Returns why it wasn't saved, or `null` once it is.
  final Future<String?> Function(GymFinishChoices choices) onSave;
  final VoidCallback onClose;

  @override
  State<GymFinishSheet> createState() => _GymFinishSheetState();
}

class _GymFinishSheetState extends State<GymFinishSheet> {
  final _title = TextEditingController();
  final _partners = TextEditingController();
  late String _visibility = widget.visibility;
  var _saving = false;

  /// Why the last save failed, shown above Save: a snackbar would be
  /// hidden behind this sheet.
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _partners.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final title = _title.text.trim();
    final error = await widget.onSave((
      title: title.isEmpty ? null : title,
      partners: _partners.text.split(','),
      visibility: _visibility,
    ));
    if (error != null && mounted) {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    final colors = context.svaColors;
    final muted = text.caption.copyWith(color: colors.textMuted);
    final most = [
      1,
      for (final b in widget.bars) b.flash + b.redpoint + b.repeat + b.attempt,
    ].reduce(max);

    // Close on the left, the title in the middle and Save always in view
    // (docs/DESIGN.md, Sheet).
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SvaSpace.xs,
              SvaSpace.xs,
              SvaSpace.xs,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.logFinishBack,
                  onPressed: widget.onClose,
                  icon: const Icon(LucideIcons.x),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.logFinishTitle,
                      style: text.headline,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: SvaSpace.minTouchTarget),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SvaSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: SvaSpace.md,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final stat in widget.stats)
                        Expanded(child: SvaStat(stat)),
                    ],
                  ),
                  for (final line in widget.projectSends)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SvaSpace.sm,
                        vertical: SvaSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSunk,
                        border: BorderDirectional(
                          start: BorderSide(
                            color: colors.redpoint,
                            width: SvaSpace.xxs,
                          ),
                        ),
                      ),
                      child: Text(line, style: text.body),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: SvaSpace.xs,
                    children: [
                      for (final bar in widget.bars) _Bar(bar, most: most),
                      Wrap(
                        spacing: SvaSpace.sm,
                        runSpacing: SvaSpace.xxs,
                        children: [
                          if (widget.bothKinds)
                            Text(l10n.logFinishKindLegend, style: muted),
                          for (final (style, fill) in [
                            ('flash', colors.flash),
                            ('redpoint', colors.redpoint),
                            ('repeat', colors.repeat),
                            ('attempt', null),
                          ])
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: SvaSpace.xxs,
                              children: [
                                _Swatch(fill: fill),
                                Text(l10n.ascentStyle(style), style: muted),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: SvaSpace.sm,
                    children: [
                      Text(l10n.logFinishFilledIn, style: muted),
                      Expanded(child: Text(widget.filledIn, style: text.label)),
                    ],
                  ),
                  TextField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: l10n.logTitle,
                      hintText: widget.autoTitle,
                      helperText: l10n.logFinishTitleHint(widget.autoTitle),
                      helperMaxLines: 3,
                    ),
                    maxLength: maxTitleLength,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  TextField(
                    controller: _partners,
                    decoration: InputDecoration(
                      labelText: l10n.logPartners,
                      hintText: l10n.logPartnersHint,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: SvaSpace.xs,
                    children: [
                      Text(l10n.logFinishVisibility, style: text.label),
                      SegmentedButton<String>(
                        segments: [
                          for (final v in const [
                            'public',
                            'friends',
                            'private',
                          ])
                            ButtonSegment(
                              value: v,
                              label: Text(l10n.settingsVisibilityOption(v)),
                            ),
                        ],
                        selected: {_visibility},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) =>
                            setState(() => _visibility = v.single),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(SvaSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: SvaSpace.xs,
                children: [
                  if (_error case final error?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: text.caption.copyWith(color: colors.danger),
                      ),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(l10n.logFinishSave),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One colour's climbs as a bar: flashes, redpoints, repeats, then
/// attempts as an outline, against the colour climbed most.
class _Bar extends StatelessWidget {
  const new(this.bar, {required this.most});

  final GymFinishBar bar;
  final int most;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    final colors = context.svaColors;
    final total = bar.flash + bar.redpoint + bar.repeat + bar.attempt;
    return Semantics(
      label: l10n.logFinishBar(
        bar.label,
        bar.flash,
        bar.redpoint,
        bar.repeat,
        bar.attempt,
      ),
      excludeSemantics: true,
      child: Row(
        spacing: SvaSpace.sm,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              bar.label,
              style: text.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                for (final (count, fill) in [
                  (bar.flash, colors.flash),
                  (bar.redpoint, colors.redpoint),
                  (bar.repeat, colors.repeat),
                  (bar.attempt, null),
                ])
                  if (count > 0)
                    Expanded(
                      flex: count,
                      child: _Swatch(fill: fill),
                    ),
                if (most > total) Spacer(flex: most - total),
              ],
            ),
          ),
          SizedBox(
            width: SvaSpace.lg,
            child: Text(
              '$total',
              style: text.caption.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// A style's colour, or an outline for attempts.
class _Swatch extends StatelessWidget {
  const new({required this.fill});

  final Color? fill;

  @override
  Widget build(BuildContext context) => Container(
    width: SvaSpace.sm,
    height: SvaSpace.sm,
    decoration: BoxDecoration(
      color: fill,
      border: fill == null
          ? Border.all(color: context.svaColors.attempt)
          : null,
      borderRadius: const BorderRadius.all(SvaRadius.badge),
    ),
  );
}
