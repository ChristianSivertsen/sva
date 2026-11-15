import 'package:flutter/material.dart';
import 'package:sva_ui/src/theme/sva_theme.dart';
import 'package:sva_ui/src/theme/sva_tokens.dart';
import 'package:sva_ui/src/widgets/badges.dart';

/// One climb on a [SvaSessionCard].
final class SvaCardClimb {
  const new({
    required this.name,
    required this.style,
    required this.styleLabel,
    this.detail = '',
    this.grade,
  });

  final String name;

  /// What kind of climb, such as `Sport · 3 pitches`.
  final String detail;

  /// The style's stable key, such as `flash`.
  final String style;
  final String styleLabel;
  final String? grade;
}

/// One number in a [SvaSessionCard]'s stats row, such as `135 m` over
/// `Climbed`.
final class SvaCardStat {
  const new({required this.value, required this.label, this.unit});

  final String value;

  /// Shown small after the value, such as `m`.
  final String? unit;
  final String label;
}

/// A session in the feed: where and when, its texts, the climbs with
/// style and grade, details as tags and a stats row (docs/DESIGN.md,
/// Card). The whole card opens the session.
class SvaSessionCard extends StatelessWidget {
  const new({
    required this.place,
    required this.when,
    required this.climbs,
    required this.openLabel,
    this.title,
    this.description,
    this.note,
    this.more,
    this.tags = const [],
    this.stats = const [],
    this.onOpen,
    this.action,
    super.key,
  });

  /// The crags climbed at, such as `Kolsås`.
  final String place;

  /// The day and who came along, such as `17 Oct 2026 · with Kari`.
  final String when;

  /// A quiet line under [when], such as the day's weather.
  final String? note;
  final String? title;
  final String? description;
  final List<SvaCardClimb> climbs;

  /// Says how many climbs are left out, such as `+2 more climbs`.
  final String? more;
  final List<String> tags;
  final List<SvaCardStat> stats;

  /// What a screen reader says the card does, such as `Open session`.
  final String openLabel;
  final VoidCallback? onOpen;

  /// A button beside the place, such as edit for the user's own session.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.svaColors;
    final text = context.svaText;
    final muted = text.caption.copyWith(color: colors.textMuted);
    return Card(
      margin: EdgeInsets.zero,
      child: Semantics(
        button: onOpen != null,
        label: openLabel,
        child: InkWell(
          onTap: onOpen,
          borderRadius: const BorderRadius.all(SvaRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(SvaSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: SvaSpace.sm,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place, style: text.label),
                          Text(when, style: muted),
                          if (note case final note? when note.isNotEmpty)
                            Text(note, style: muted),
                        ],
                      ),
                    ),
                    ?action,
                  ],
                ),
                if (title != null || description != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: SvaSpace.xxs,
                    children: [
                      if (title case final title?)
                        Text(title, style: text.headline),
                      if (description case final description?)
                        Text(description, style: text.body),
                    ],
                  ),
                if (climbs.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: SvaSpace.xs,
                    children: [
                      for (final climb in climbs) _ClimbRow(climb),
                      if (more case final more?) Text(more, style: muted),
                    ],
                  ),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: SvaSpace.xxs,
                    runSpacing: SvaSpace.xxs,
                    children: [for (final tag in tags) SvaTag(tag)],
                  ),
                if (stats.isNotEmpty)
                  // Large text does not fit four to a row, so the stats
                  // wrap instead of clipping (docs/DESIGN.md, Accessibility).
                  if (MediaQuery.textScalerOf(context).scale(10) > 13)
                    Wrap(
                      spacing: SvaSpace.xl,
                      runSpacing: SvaSpace.xs,
                      children: [for (final stat in stats) SvaStat(stat)],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final stat in stats)
                          Expanded(child: SvaStat(stat)),
                        // Stats keep their quarter width when some are
                        // unknown, so they line up from card to card.
                        for (var i = stats.length; i < 4; i++) const Spacer(),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClimbRow extends StatelessWidget {
  const new(this.climb);

  final SvaCardClimb climb;

  @override
  Widget build(BuildContext context) {
    final text = context.svaText;
    return Row(
      spacing: SvaSpace.xs,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: climb.name,
              style: text.label.copyWith(fontWeight: FontWeight.w600),
              children: [
                if (climb.detail.isNotEmpty)
                  TextSpan(
                    text: '  ${climb.detail}',
                    style: text.caption.copyWith(
                      color: context.svaColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SvaStyleTag(style: climb.style, label: climb.styleLabel),
        if (climb.grade case final grade?) SvaGradeBadge(grade),
      ],
    );
  }
}

/// One number over its label, as in a [SvaSessionCard]'s stats row.
class SvaStat extends StatelessWidget {
  const new(this.stat, {super.key});

  final SvaCardStat stat;

  @override
  Widget build(BuildContext context) {
    final text = context.svaText;
    final muted = text.caption.copyWith(color: context.svaColors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: stat.value,
            children: [
              if (stat.unit case final unit?)
                TextSpan(text: ' $unit', style: muted),
            ],
          ),
          style: text.number,
        ),
        Text(stat.label, style: muted),
      ],
    );
  }
}
