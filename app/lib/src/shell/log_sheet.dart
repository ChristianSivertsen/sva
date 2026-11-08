import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/logging/climb_editor.dart';
import 'package:sva/src/logging/indoor_log.dart';
import 'package:sva/src/logging/time_zone.dart';
import 'package:sva/src/places/form_parts.dart';
import 'package:sva/src/places/grade_badge.dart';
import 'package:sva/src/places/labels.dart';
import 'package:sva/src/routes.dart';
import 'package:sva/src/sessions/session_screen.dart';
import 'package:sva_core/sva_core.dart'
    show LoggedAscent, RouteHistory, seasonOf;
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// The log sheet as a page, so `/log` works as a deep link and the system
/// back gesture closes it. Slides up over the current tab.
class LogSheetPage extends CustomTransitionPage<void> {
  new({super.key, String? sessionId})
    : super(
        child: LogSheet(sessionId: sessionId),
        fullscreenDialog: true,
        opaque: false,
        barrierDismissible: true,
        barrierColor: SvaColors.scrim,
        transitionDuration: SvaMotion.sheet,
        reverseTransitionDuration: SvaMotion.sheet,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final reduced = MediaQuery.disableAnimationsOf(context);
          if (reduced) return child;
          final curved = CurvedAnimation(
            parent: animation,
            curve: SvaMotion.easeOut,
            reverseCurve: SvaMotion.easeIn,
          );
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      );
}

/// Closes the sheet. If it was opened as the first page (an old link to
/// `/log`), there is nothing to go back to, so it opens the feed instead.
void closeLogSheet(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.feed);
  }
}

/// The log sheet: pick outdoor or indoor, add climbs, then save the
/// session. Opens on the setting of the session logged last. With a
/// [sessionId] it edits that session instead: remove climbs, add forgotten
/// ones and change the texts, on the day it was logged.
class LogSheet extends ConsumerStatefulWidget {
  const new({this.sessionId, super.key});

  final String? sessionId;

  @override
  ConsumerState<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends ConsumerState<LogSheet> {
  /// The user's own choice; until then, the last session's setting.
  String? _setting;
  final _climbs = <PendingClimb>[];
  PendingClimb? _current;

  /// A new key gives a fresh, empty climb editor after "Add climb".
  var _editorKey = UniqueKey();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _partners = TextEditingController();
  String? _conditions;
  var _saving = false;

  /// Editing: the session as it was, until it has loaded.
  Session? _session;

  /// Editing: ids of the session's climbs marked for removal.
  final _removed = <String>{};

  bool get _editing => widget.sessionId != null;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId case final id?) unawaited(_load(id));
  }

  /// Fills the fields with the session being edited. A session that is
  /// gone, not the user's or not outdoors closes the sheet with a message.
  Future<void> _load(String id) async {
    Session? session;
    var partners = const <String>[];
    try {
      session = await ref.read(sessionProvider(id).future);
      partners = await ref.read(sessionPartnersProvider(id).future);
    } on Object {
      session = null;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (session == null ||
        session.ownerId != ref.read(currentUserIdProvider) ||
        session.setting != 'outdoor') {
      closeLogSheet(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionNotFound)));
      return;
    }
    final loaded = session;
    setState(() {
      _session = loaded;
      _title.text = loaded.title ?? '';
      _description.text = loaded.description ?? '';
      _partners.text = partners.join(', ');
      _conditions = loaded.conditions;
    });
  }

  /// What the rules see on [routeId] before the new climbs: everything
  /// logged, or when editing, everything up to this session less the
  /// climbs marked for removal.
  Future<List<LoggedAscent>> _logged(String routeId) async {
    final id = widget.sessionId;
    if (id == null) return await ref.read(routeLogProvider(routeId).future);
    final entries = await ref.read(routeLogUpToProvider((routeId, id)).future);
    return [
      for (final e in entries)
        if (!_removed.contains(e.id)) e.ascent,
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _partners.dispose();
    super.dispose();
  }

  List<PendingClimb> get _toSave => [..._climbs, ?_current];

  /// Removes climb [index] and any later climb on the same route that the
  /// rules no longer allow without it (a repeat whose send is gone, say).
  Future<void> _remove(int index) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final routeId = _climbs[index].hit.route.id;
    final logged = await _logged(routeId);
    if (!mounted) return;
    final remaining = [..._climbs]..removeAt(index);
    final history = [...logged];
    final kept = <PendingClimb>[];
    for (final climb in remaining) {
      final draft = climb.draft;
      if (draft.routeId == routeId) {
        final ascent = (style: draft.style, tries: draft.tries);
        final boulder = climb.hit.route.discipline == 'boulder';
        if (RouteHistory.from(
          history,
          boulder: boulder,
        ).check(ascent).isNotEmpty) {
          continue;
        }
        history.add(ascent);
      }
      kept.add(climb);
    }
    setState(() {
      final dropped = remaining.length - kept.length;
      _climbs
        ..clear()
        ..addAll(kept);
      // The open climb may depend on the removed one too: start it again.
      _current = null;
      _editorKey = UniqueKey();
      if (dropped > 0) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.logLaterClimbsRemoved)),
        );
      }
    });
  }

  void _addAnother() => setState(() {
    _climbs.add(_current!);
    _current = null;
    _editorKey = UniqueKey();
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateUtils.dateOnly(DateTime.now()),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (widget.sessionId case final id?) return await _saveEdit(id);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionLoggerProvider)
          .logOutdoor(
            SessionDraft(
              localDate: DateFormat('yyyy-MM-dd').format(_date),
              tz: deviceTimeZone(DateTime.now().timeZoneOffset),
              visibility:
                  ref.read(settingsProvider).value?.defaultVisibility ??
                  const Settings().defaultVisibility,
              climbs: [for (final c in _toSave) c.draft],
              title: _title.text,
              description: _description.text,
              conditions: _conditions,
              partners: _partners.text.split(','),
            ),
            userId: ref.read(currentUserIdProvider),
          );
      if (!mounted) return;
      final weather = ref.read(weatherFillerProvider);
      final userId = ref.read(currentUserIdProvider);
      closeLogSheet(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.logSaved)));
      // Look up the weather now if there is signal; otherwise later. The
      // session is saved either way, so a failure here is not the user's.
      unawaited(weather.fillMissing(userId: userId).catchError((_) => 0));
    } on ClimbRejected catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.logClimbRejected(e.index + 1))),
      );
      if (mounted) setState(() => _saving = false);
    } on Object {
      // A database failure or a value the logger refused.
      messenger.showSnackBar(SnackBar(content: Text(l10n.formSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Saves the changes to session [id]. Removing every climb deletes the
  /// session, so the user is asked first.
  Future<void> _saveEdit(String id) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final existing = ref.read(sessionAscentsProvider(id)).value ?? const [];
    if (_toSave.isEmpty && _removed.length >= existing.length) {
      final sure = await confirmDelete(context, l10n.sessionDeleteLastBody);
      if (!sure || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      final deleted = await ref
          .read(sessionLoggerProvider)
          .editOutdoor(
            id,
            SessionEdit(
              title: _title.text,
              description: _description.text,
              conditions: _conditions,
              partners: _partners.text.split(','),
              removed: {..._removed},
              added: [for (final c in _toSave) c.draft],
            ),
            userId: ref.read(currentUserIdProvider),
          );
      if (deleted) {
        router.go(Routes.feed);
      } else if (mounted) {
        closeLogSheet(context);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(deleted ? l10n.sessionDeleted : l10n.logEditSaved),
        ),
      );
    } on ClimbRejected catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.logClimbRejected(e.index + 1))),
      );
      if (mounted) setState(() => _saving = false);
    } on LaterClimbRejected {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.logLaterClimbRejected)),
      );
      if (mounted) setState(() => _saving = false);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.formSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Marks one of the session's climbs for removal, or keeps it again.
  /// The open climb may depend on it, so it starts again; saving checks
  /// the added climbs against the climbs that are left.
  void _toggleRemoved(String ascentId) => setState(() {
    if (!_removed.remove(ascentId)) _removed.add(ascentId);
    _current = null;
    _editorKey = UniqueKey();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.svaColors;
    final text = context.svaText;
    final editing = _editing;
    final setting = editing
        ? 'outdoor'
        : _setting ?? ref.watch(lastSettingProvider).value ?? 'outdoor';
    final outdoor = setting == 'outdoor';
    final count = _toSave.length;
    final existing = editing
        ? ref.watch(sessionAscentsProvider(widget.sessionId!)).value
        : null;
    if (editing && (_session == null || existing == null)) {
      return const SizedBox.shrink();
    }

    // Lift the sheet above the keyboard so the fields and Save stay
    // reachable.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height - keyboard) * 0.92,
            ),
            child: Material(
              color: colors.surface,
              elevation: 8,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: SvaRadius.sheet),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SvaSpace.xs,
                      SvaSpace.xs,
                      SvaSpace.screen,
                      0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: l10n.close,
                          onPressed: () => closeLogSheet(context),
                          icon: Icon(LucideIcons.x, color: colors.text),
                        ),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              editing ? l10n.logEditTitle : l10n.logSheetTitle,
                              style: text.title,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: SvaSpace.minTouchTarget),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(SvaSpace.screen),
                      children: [
                        if (existing != null) ...[
                          _ExistingClimbs(
                            climbs: existing,
                            removed: _removed,
                            onToggle: _toggleRemoved,
                          ),
                          formGap,
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.logEditForgotten,
                              style: text.headline,
                            ),
                          ),
                          const SizedBox(height: SvaSpace.xs),
                        ] else ...[
                          _SettingPicker(
                            setting: setting,
                            onChanged: (s) => setState(() => _setting = s),
                          ),
                          formGap,
                        ],
                        if (!outdoor)
                          IndoorLog(onSaved: () => closeLogSheet(context))
                        else ...[
                          for (final (i, climb) in _climbs.indexed)
                            _PendingRow(
                              number: i + 1,
                              climb: climb,
                              onRemove: () => _remove(i),
                            ),
                          if (_climbs.isNotEmpty) formGap,
                          ClimbEditor(
                            key: _editorKey,
                            upToSession: widget.sessionId,
                            removed: Set.unmodifiable(_removed),
                            earlierInSession: List.unmodifiable(_climbs),
                            onChanged: (c) => setState(() => _current = c),
                          ),
                          if (_current != null) ...[
                            formGap,
                            OutlinedButton(
                              onPressed: _addAnother,
                              child: Text(l10n.logAddClimb),
                            ),
                          ],
                          formGap,
                          _SessionFields(
                            date: switch (_session) {
                              final s? => DateTime.parse(s.localDate),
                              null => _date,
                            },
                            latitude: [
                              for (final c in _toSave) c.hit.location?.lat,
                            ].nonNulls.firstOrNull,
                            // A session keeps the day it was logged on.
                            onPickDate: editing ? null : _pickDate,
                            title: _title,
                            description: _description,
                            partners: _partners,
                            conditions: _conditions,
                            onConditions: (c) =>
                                setState(() => _conditions = c),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (outdoor)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(SvaSpace.screen),
                        child: FilledButton(
                          onPressed: _saving || (count == 0 && !editing)
                              ? null
                              : _save,
                          child: Text(
                            editing
                                ? l10n.logEditSave
                                : l10n.logSave(count == 0 ? 1 : count),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingPicker extends StatelessWidget {
  const new({required this.setting, required this.onChanged});

  final String setting;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget option(String value, IconData icon, String label, String hint) {
      final on = setting == value;
      final colors = context.svaColors;
      return Expanded(
        child: Semantics(
          inMutuallyExclusiveGroup: true,
          selected: on,
          button: true,
          label: label,
          onTap: () => onChanged(value),
          excludeSemantics: true,
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: const BorderRadius.all(SvaRadius.card),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: on ? colors.text : colors.surfaceSunk,
                borderRadius: const BorderRadius.all(SvaRadius.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(SvaSpace.sm),
                child: Row(
                  children: [
                    Icon(icon, color: on ? colors.background : colors.text),
                    const SizedBox(width: SvaSpace.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: context.svaText.label.copyWith(
                              color: on ? colors.background : colors.text,
                            ),
                          ),
                          Text(
                            hint,
                            style: context.svaText.caption.copyWith(
                              color: on ? colors.background : colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: l10n.logWhere,
      container: true,
      child: Row(
        children: [
          option(
            'outdoor',
            LucideIcons.mountain,
            l10n.logOutdoor,
            l10n.logOutdoorHint,
          ),
          const SizedBox(width: SvaSpace.sm),
          option(
            'indoor',
            LucideIcons.building2,
            l10n.logIndoor,
            l10n.logIndoorHint,
          ),
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const new({
    required this.number,
    required this.climb,
    required this.onRemove,
  });

  final int number;
  final PendingClimb climb;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = climb.hit.route.name ?? '';
    return Row(
      children: [
        Text('$number', style: context.svaText.caption),
        const SizedBox(width: SvaSpace.sm),
        Expanded(
          child: Text(
            '$name · ${l10n.ascentStyle(climb.draft.style.name)}',
            style: context.svaText.body,
          ),
        ),
        if (climb.hit.grade case final grade?)
          GradeBadge(grade, system: climb.hit.gradeSystem),
        IconButton(
          tooltip: l10n.logRemoveClimb(name),
          onPressed: onRemove,
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }
}

/// The climbs already in the session being edited, each with a button to
/// mark it for removal or keep it again.
class _ExistingClimbs extends ConsumerWidget {
  const new({
    required this.climbs,
    required this.removed,
    required this.onToggle,
  });

  final List<Ascent> climbs;
  final Set<String> removed;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.svaColors;
    final text = context.svaText;
    final marked = climbs.where((c) => removed.contains(c.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.logEditExisting, style: text.headline),
        ),
        for (final climb in climbs)
          _ExistingRow(
            climb: climb,
            gone: removed.contains(climb.id),
            onToggle: () => onToggle(climb.id),
          ),
        if (marked > 0)
          Text(
            l10n.logEditMarked(marked),
            style: text.caption.copyWith(color: colors.textMuted),
          ),
      ],
    );
  }
}

class _ExistingRow extends ConsumerWidget {
  const new({required this.climb, required this.gone, required this.onToggle});

  final Ascent climb;
  final bool gone;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hit = ref.watch(routeHitProvider(climb.routeId)).value;
    final name = hit?.route.name ?? '';
    final style = context.svaText.body;
    return Row(
      children: [
        Expanded(
          child: Text(
            '$name · ${l10n.ascentStyle(climb.style)}',
            style: gone
                ? style.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: context.svaColors.textMuted,
                  )
                : style,
          ),
        ),
        if (hit?.grade case final grade? when !gone)
          GradeBadge(grade, system: hit?.gradeSystem),
        IconButton(
          tooltip: gone ? l10n.logEditKeep(name) : l10n.logRemoveClimb(name),
          onPressed: onToggle,
          icon: Icon(gone ? LucideIcons.undo2 : LucideIcons.x),
        ),
      ],
    );
  }
}

class _SessionFields extends StatelessWidget {
  const new({
    required this.date,
    required this.latitude,
    required this.onPickDate,
    required this.title,
    required this.description,
    required this.partners,
    required this.conditions,
    required this.onConditions,
  });

  final DateTime date;

  /// Where the first climb is, to name the season; `null` until known.
  final double? latitude;

  /// `null` when the date is fixed.
  final VoidCallback? onPickDate;
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController partners;
  final String? conditions;
  final ValueChanged<String?> onConditions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final day = DateFormat('yyyy-MM-dd').format(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.logSession, style: context.svaText.headline),
        ),
        const SizedBox(height: SvaSpace.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onPickDate,
            icon: const Icon(LucideIcons.calendar),
            label: Text(
              [
                '${l10n.logDate}: ${formatDay(l10n, day)}',
                if (latitude case final lat?)
                  l10n.season(seasonOf(date, latitude: lat).name),
              ].join(' · '),
            ),
          ),
        ),
        formGap,
        TextField(
          controller: title,
          decoration: InputDecoration(labelText: l10n.logTitle),
          maxLength: maxTitleLength,
        ),
        formGap,
        TextField(
          controller: description,
          decoration: InputDecoration(labelText: l10n.logDescription),
          maxLength: maxDescriptionLength,
          minLines: 2,
          maxLines: 5,
        ),
        formGap,
        ChipGroup(
          label: l10n.logConditions,
          options: [
            for (final value
                in attributeSeed
                    .firstWhere((d) => d.key == 'conditions')
                    .valueKeys)
              (value, l10n.attributeValue(value.replaceAll('.', '_'))),
          ],
          selected: {?conditions},
          onChanged: (v) => onConditions(v.firstOrNull),
        ),
        formGap,
        TextField(
          controller: partners,
          decoration: InputDecoration(
            labelText: l10n.logPartners,
            hintText: l10n.logPartnersHint,
          ),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }
}
