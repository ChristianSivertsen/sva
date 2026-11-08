import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/places/grade_badge.dart';
import 'package:sva/src/places/labels.dart';
import 'package:sva/src/routes.dart';
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// One session: its day, texts, partners and every climb, with edit and
/// delete for the owner.
class SessionScreen extends ConsumerStatefulWidget {
  const new({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  var _deleting = false;

  String get sessionId => widget.sessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider(sessionId));
    // Indoor sessions are edited once gyms arrive (M3).
    final own =
        session.value?.ownerId == ref.watch(currentUserIdProvider) &&
        session.value?.setting == 'outdoor';
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (own)
            IconButton(
              tooltip: l10n.sessionDelete,
              onPressed: _deleting ? null : _delete,
              icon: Icon(LucideIcons.trash2, color: context.svaColors.danger),
            ),
        ],
      ),
      body: switch (session) {
        AsyncData(value: final session?) => _SessionDetail(session: session),
        AsyncData() || AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(SvaSpace.xxl),
            child: Text(
              l10n.sessionNotFound,
              style: context.svaText.body,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        AsyncLoading() => const SizedBox.shrink(),
      },
      bottomNavigationBar: own
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(SvaSpace.screen),
                child: FilledButton(
                  onPressed: () => context.push(Routes.sessionEdit(sessionId)),
                  child: Text(l10n.sessionEdit),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _deleting = true);
    final sure = await confirmDelete(context, l10n.sessionDeleteBody);
    if (!sure || !mounted) {
      if (mounted) setState(() => _deleting = false);
      return;
    }
    try {
      // Through the logger, so later climbs on the same routes are checked
      // and recounted as for any removed climb.
      final climbs = await ref.read(sessionAscentsProvider(sessionId).future);
      await ref
          .read(sessionLoggerProvider)
          .editOutdoor(
            sessionId,
            SessionEdit(removed: {for (final a in climbs) a.id}),
            userId: ref.read(currentUserIdProvider),
          );
      router.go(Routes.feed);
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionDeleted)));
    } on LaterClimbRejected {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.logLaterClimbRejected)),
      );
      if (mounted) setState(() => _deleting = false);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.formSaveFailed)));
      if (mounted) setState(() => _deleting = false);
    }
  }
}

/// Asks before a session is deleted, saying what goes with it. `true` when
/// the user confirms.
Future<bool> confirmDelete(BuildContext context, String body) async {
  final l10n = AppLocalizations.of(context);
  final colors = context.svaColors;
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.sessionDeleteTitle),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.sessionKeep),
        ),
        // Destructive: danger border and label (docs/DESIGN.md).
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.danger,
            side: BorderSide(color: colors.danger),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.sessionDeleteConfirm),
        ),
      ],
    ),
  );
  return sure ?? false;
}

class _SessionDetail extends ConsumerWidget {
  const new({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.svaColors;
    final text = context.svaText;
    final climbs = ref.watch(sessionAscentsProvider(session.id)).value;
    final partners = ref.watch(sessionPartnersProvider(session.id)).value;
    final day = formatDay(l10n, session.localDate);
    final facts = [
      if (session.title != null) day,
      if (session.conditions case final c?)
        l10n.attributeValue(c.replaceAll('.', '_')),
    ].where((f) => f.isNotEmpty).join(' · ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SvaSpace.screen,
        0,
        SvaSpace.screen,
        SvaSpace.xxl,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(session.title ?? day, style: text.title),
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: SvaSpace.xxs),
          Text(facts, style: text.body.copyWith(color: colors.textMuted)),
        ],
        if (partners case final names? when names.isNotEmpty) ...[
          const SizedBox(height: SvaSpace.xxs),
          Text(l10n.sessionWith(names.join(', ')), style: text.body),
        ],
        if (session.description case final description?) ...[
          const SizedBox(height: SvaSpace.sm),
          Text(description, style: text.body),
        ],
        Padding(
          padding: const EdgeInsets.only(top: SvaSpace.xl, bottom: SvaSpace.xs),
          child: Semantics(
            header: true,
            child: Text(l10n.sessionClimbs, style: text.headline),
          ),
        ),
        for (final climb in climbs ?? const <Ascent>[]) _ClimbCard(climb),
      ],
    );
  }
}

class _ClimbCard extends ConsumerWidget {
  const new(this.climb);

  final Ascent climb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    final muted = text.caption.copyWith(color: context.svaColors.textMuted);
    final hit = ref.watch(routeHitProvider(climb.routeId)).value;
    // A gym climb has no route name: it shows as colour (or grade) and wall.
    final gym = climb.setting == 'indoor'
        ? ref.watch(gymRouteLabelProvider(climb.routeId)).value
        : null;
    final name = switch (gym) {
      final g? => g.colour ?? g.grade ?? g.wall ?? '',
      null => hit?.route.name ?? '',
    };
    final place = switch (gym) {
      final g? when g.colour != null || g.grade != null => g.wall,
      final _? => null,
      null => hit?.crag,
    };
    final feel = climb.feel == null
        ? ''
        : l10n.attributeValue(climb.feel!.replaceAll('.', '_'));
    return Padding(
      padding: const EdgeInsets.only(bottom: SvaSpace.sm),
      child: Card(
        child: InkWell(
          onTap: hit == null
              ? null
              : () => context.push(Routes.route(climb.routeId)),
          borderRadius: const BorderRadius.all(SvaRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(SvaSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: text.headline)),
                    if (gym?.grade ?? hit?.grade case final grade?)
                      GradeBadge(
                        grade,
                        system: gym?.gradeSystem ?? hit?.gradeSystem,
                      ),
                  ],
                ),
                if (place case final place?) Text(place, style: muted),
                const SizedBox(height: SvaSpace.xs),
                Wrap(
                  spacing: SvaSpace.xs,
                  runSpacing: SvaSpace.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SvaStyleTag(
                      style: climb.style,
                      label: l10n.ascentStyle(climb.style),
                    ),
                    Text(l10n.ascentTries(climb.tries), style: muted),
                    Text(l10n.ascentType(climb.ascentType), style: muted),
                    if (feel.isNotEmpty) Text(feel, style: muted),
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
