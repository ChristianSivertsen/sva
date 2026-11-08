import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/places/labels.dart';
import 'package:sva/src/routes.dart';
import 'package:sva_core/sva_core.dart' show sessionTotals;
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// Climbs shown on a card before "+N more climbs", as in the prototype.
const _climbsShown = 6;

/// Tags shown on a card, as in the prototype.
const _tagsShown = 6;

/// One of the user's sessions in the feed, laid out like the prototype's
/// post. The topo or wall image joins it once photos, walls and topos
/// exist (M3, M5, M15).
class FeedCard extends ConsumerWidget {
  const new({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final climbs = ref.watch(sessionAscentsProvider(session.id)).value ?? [];
    final hits = {
      for (final id in {for (final c in climbs) c.routeId})
        id: ref.watch(routeHitProvider(id)).value,
    };
    final partners = ref.watch(sessionPartnersProvider(session.id)).value;
    final weather = ref.watch(sessionWeatherProvider(session.id)).value;
    final tags = ref.watch(sessionTagsProvider(session.id)).value ?? [];
    final showGrade = ref.watch(gradeDisplayProvider);
    // Gym climbs have no route name: they show as colour (or grade) and
    // wall, at the session's gym.
    final indoor = session.setting == 'indoor';
    final gym = switch (session.areaId) {
      final id? when indoor => ref.watch(placeNameProvider(id)).value,
      _ => null,
    };
    final labels = {
      if (indoor)
        for (final id in {for (final c in climbs) c.routeId})
          id: ref.watch(gymRouteLabelProvider(id)).value,
    };

    final crags = {for (final c in climbs) ?hits[c.routeId]?.crag};
    final shown = climbs.take(_climbsShown);
    final routes = [for (final c in climbs) hits[c.routeId]?.route];
    final totals = sessionTotals([
      for (final r in routes.nonNulls)
        (pitchCount: r.pitchCount, lengthM: r.lengthM),
    ]);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final tagLabels = [
      for (final tag in tags)
        if (l10n.attributeValue(tag.replaceAll('.', '_')) case final label
            when label.isNotEmpty)
          label,
    ].take(_tagsShown).toList();

    return SvaSessionCard(
      place:
          gym ??
          (crags.isEmpty
              ? l10n.feedSetting(session.setting)
              : crags.join(', ')),
      when: [
        formatDay(l10n, session.localDate),
        if (partners case final names? when names.isNotEmpty)
          l10n.feedWith(names.join(', ')),
      ].join(' · '),
      note: weather == null ? null : weatherLine(l10n, weather),
      title: session.title,
      description: session.description,
      climbs: [
        for (final climb in shown)
          if (labels[climb.routeId] case final label?)
            SvaCardClimb(
              name: label.colour ?? label.grade ?? label.wall ?? '',
              detail: label.colour != null || label.grade != null
                  ? label.wall ?? ''
                  : '',
              style: climb.style,
              styleLabel: l10n.ascentStyle(climb.style),
              grade: switch (label.grade) {
                final grade? => showGrade(grade, label.gradeSystem),
                null => null,
              },
            )
          else
            SvaCardClimb(
              name: hits[climb.routeId]?.route.name ?? '',
              detail: _detail(l10n, hits[climb.routeId]?.route),
              style: climb.style,
              styleLabel: l10n.ascentStyle(climb.style),
              grade: _grade(hits[climb.routeId], showGrade),
            ),
      ],
      more: climbs.length > _climbsShown
          ? l10n.feedMoreClimbs(climbs.length - _climbsShown)
          : null,
      tags: tagLabels,
      // Unknown values are left out rather than shown as a guess. Totals
      // wait until every route is loaded, so they never count too low.
      stats: [
        if (climbs.isNotEmpty && routes.every((r) => r != null)) ...[
          SvaCardStat(
            value: number.format(totals.pitches),
            label: l10n.feedStatPitches,
          ),
          if (totals.metres case final metres?)
            SvaCardStat(
              value: number.format(metres.round()),
              unit: l10n.feedStatMetres,
              label: l10n.feedStatClimbed,
            ),
        ],
        if (session.elevationGainM case final gain?)
          SvaCardStat(
            value: number.format(gain),
            unit: l10n.feedStatMetres,
            label: l10n.feedStatElevation,
          ),
      ],
      openLabel: l10n.feedOpenSession,
      onOpen: () => context.push(Routes.session(session.id)),
      // Indoor sessions are edited once gyms arrive (M3).
      action: session.setting == 'outdoor'
          ? IconButton(
              tooltip: l10n.sessionEdit,
              onPressed: () => context.push(Routes.sessionEdit(session.id)),
              icon: Icon(LucideIcons.pencil, color: context.svaColors.text),
            )
          : null,
    );
  }

  /// The route's grade in the user's system, or `null` without one.
  static String? _grade(
    RouteHit? hit,
    String Function(String label, String? systemKey) show,
  ) => switch (hit?.grade) {
    final grade? => show(grade, hit?.gradeSystem),
    null => null,
  };

  /// A climb's kind, such as `Sport · 3 pitches`.
  static String _detail(AppLocalizations l10n, Route? route) {
    if (route == null) return '';
    return [
      l10n.discipline(route.discipline),
      if (route.pitchCount > 1) l10n.routePitches(route.pitchCount),
    ].where((part) => part.isNotEmpty).join(' · ');
  }
}
