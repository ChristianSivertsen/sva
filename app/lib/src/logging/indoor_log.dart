import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/places/form_parts.dart';
import 'package:sva/src/routes.dart';
import 'package:sva/src/shell/log_sheet.dart' show deviceTimeZone;
import 'package:sva_core/sva_core.dart'
    show AscentStyle, GradeSystem, LoggedAscent, RouteHistory, gymTap;
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// One tile in the log: a colour of the gym, or a grade in a graded gym.
typedef _Tile = ({
  String label,
  Color? fill,
  String? colourId,
  String? gradeId,
});

/// A route climbed this session: on a wall, with a tile's colour or grade.
typedef _Route = ({String wallId, String kind, _Tile tile});

/// One tap: topped or not, after how many tries, and how on a rope.
class _Entry {
  new({required this.route, required this.ropeType});

  int route;
  bool topped = true;
  int tries = 1;
  String? ropeType;
}

/// Logging at the gym (prototype/gym-log.html): pick the wall, then tap
/// the colour you topped. The style follows from what you logged on that
/// climb before (sva_core `gymTap`); topping a colour you fell on earlier
/// this session counts as the same climb.
class IndoorLog extends ConsumerStatefulWidget {
  const new({required this.onSaved, super.key});

  /// Called after the session is saved.
  final VoidCallback onSaved;

  @override
  ConsumerState<IndoorLog> createState() => _IndoorLogState();
}

class _IndoorLogState extends ConsumerState<IndoorLog> {
  String? _gymId;
  String _kind = 'boulder';
  final _wall = <String, String>{};
  String _ropeType = 'lead';
  final _routes = <_Route>[];
  final _entries = <_Entry>[];
  var _saving = false;

  /// The gym to log at: the one picked, else the one logged at last, else
  /// the first set up.
  String? _gym(List<Area> gyms) {
    if (_gymId case final id? when gyms.any((g) => g.id == id)) return id;
    final sessions = ref.watch(mySessionsProvider).value ?? const [];
    final last = sessions
        .where((s) => s.setting == 'indoor' && s.areaId != null)
        .map((s) => s.areaId)
        .firstOrNull;
    if (gyms.any((g) => g.id == last)) return last;
    return gyms.firstOrNull?.id;
  }

  /// Each entry's climb as it will be logged, worked out in order.
  List<LoggedAscent> _climbs() {
    final logs = [for (final _ in _routes) <LoggedAscent>[]];
    return [
      for (final e in _entries)
        () {
          final ascent = gymTap(
            RouteHistory.from(
              logs[e.route],
              boulder: _routes[e.route].kind == 'boulder',
              gym: true,
            ),
            topped: e.topped,
            tries: e.tries,
          );
          logs[e.route].add(ascent);
          return ascent;
        }(),
    ];
  }

  void _tap(String wallId, _Tile tile) {
    // Topping a colour you fell on earlier this session is most likely the
    // same climb; otherwise it is a new one.
    final open = [
      for (final (i, r) in _routes.indexed)
        if (r.wallId == wallId &&
            r.tile.colourId == tile.colourId &&
            r.tile.gradeId == tile.gradeId &&
            _entries.any((e) => e.route == i) &&
            !_entries.any((e) => e.route == i && e.topped))
          i,
    ];
    final route =
        open.lastOrNull ??
        () {
          _routes.add((wallId: wallId, kind: _kind, tile: tile));
          return _routes.length - 1;
        }();
    setState(
      () => _entries.add(
        _Entry(route: route, ropeType: _kind == 'rope' ? _ropeType : null),
      ),
    );
  }

  void _remove(int index) => setState(() {
    final route = _entries.removeAt(index).route;
    // A route nothing points at any more is dropped, so it is not saved.
    if (!_entries.any((e) => e.route == route)) {
      _routes.removeAt(route);
      for (final e in _entries) {
        if (e.route > route) e.route--;
      }
    }
  });

  Future<void> _save(String gymId) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final climbs = _climbs();
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionLoggerProvider)
          .logIndoor(
            IndoorSessionDraft(
              gymId: gymId,
              localDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
              tz: deviceTimeZone(DateTime.now().timeZoneOffset),
              visibility:
                  ref.read(settingsProvider).value?.defaultVisibility ??
                  const Settings().defaultVisibility,
              routes: [
                for (final r in _routes)
                  IndoorRouteDraft(
                    wallId: r.wallId,
                    colourId: r.tile.colourId,
                    gradeId: r.tile.gradeId,
                  ),
              ],
              climbs: [
                for (final (i, e) in _entries.indexed)
                  IndoorClimbDraft(
                    route: e.route,
                    style: climbs[i].style,
                    tries: climbs[i].tries,
                    ascentType: e.ropeType ?? 'boulder',
                  ),
              ],
            ),
            userId: ref.read(currentUserIdProvider),
          );
      widget.onSaved();
      messenger.showSnackBar(SnackBar(content: Text(l10n.logSaved)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.formSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The tiles of a gym for [kind]: its colours, the grades of the system
  /// chosen in settings, or one tile for an ungraded gym.
  List<_Tile> _tiles(GymSetup setup, String kind, AppLocalizations l10n) {
    switch (setup.grading) {
      case 'colour':
        return [
          for (final c in setup.colours)
            (
              label: c.name,
              fill: gymColourFromHex(c.colourHex),
              colourId: c.id,
              gradeId: null,
            ),
        ];
      case 'standard':
        final type = kind == 'boulder' ? 'boulder' : 'free_route';
        final settings = ref.watch(settingsProvider).value ?? const Settings();
        final systems =
            ref.watch(gradeSystemsProvider).value ?? const <GradeSystem>[];
        final system = systems
            .where((s) => s.key == settings.gradeSystemFor(type))
            .firstOrNull;
        if (system == null) return const [];
        return [
          for (final g in system.grades)
            (
              label: g.label,
              fill: null,
              colourId: null,
              gradeId: seedId('grade:${system.key}:${g.label}'),
            ),
        ];
      default:
        return [
          (
            label: l10n.logIndoorUngraded,
            fill: null,
            colourId: null,
            gradeId: null,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    final colors = context.svaColors;
    final muted = text.caption.copyWith(color: colors.textMuted);
    final gyms = ref.watch(gymsProvider).value;
    if (gyms == null) return const SizedBox.shrink();
    final gymId = _gym(gyms);
    if (gymId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: SvaSpace.sm,
        children: [
          Text(l10n.logIndoorNoGym, style: text.body),
          OutlinedButton(
            onPressed: () => context.push(Routes.gymNew),
            child: Text(l10n.settingsGymAdd),
          ),
        ],
      );
    }
    final setup = ref.watch(gymSetupProvider(gymId)).value;
    if (setup == null) return const SizedBox.shrink();
    final kinds = [
      for (final k in wallKinds)
        if (setup.walls.any((w) => w.kind == k)) k,
    ];
    final kind = kinds.contains(_kind) ? _kind : kinds.firstOrNull;
    final walls = [
      for (final w in setup.walls)
        if (w.kind == kind) w,
    ];
    final wall =
        walls.where((w) => w.id == _wall[kind]).firstOrNull ??
        walls.firstOrNull;
    final tiles = kind == null ? const <_Tile>[] : _tiles(setup, kind, l10n);
    final climbs = _climbs();
    final last = _entries.lastOrNull;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    String metres(double m) => '${number.format(m)} ${l10n.feedStatMetres}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (gyms.length > 1) ...[
          ChipGroup(
            label: l10n.logIndoorGym,
            options: [for (final g in gyms) (g.id, g.name)],
            selected: {gymId},
            // A session stays at one gym once it has climbs.
            disabled: {
              if (_entries.isNotEmpty)
                for (final g in gyms)
                  if (g.id != gymId) g.id,
            },
            onChanged: (v) {
              if (v.isNotEmpty) setState(() => _gymId = v.single);
            },
          ),
          formGap,
        ] else
          Text(setup.gym.name, style: text.headline),
        if (kind == null)
          Text(l10n.logIndoorNoWalls, style: text.body)
        else ...[
          if (kinds.length > 1) ...[
            SegmentedButton<String>(
              segments: [
                for (final k in kinds)
                  ButtonSegment(value: k, label: Text(l10n.gymWallKind(k))),
              ],
              selected: {kind},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _kind = v.single),
            ),
            const SizedBox(height: SvaSpace.sm),
          ],
          if (walls.length > 1)
            ChipGroup(
              label: l10n.logIndoorWall,
              options: [
                for (final w in walls)
                  (
                    w.id,
                    [
                      w.name,
                      if (w.heightM case final h?) metres(h),
                      if (w.angle case final a?)
                        l10n.attributeValue(a.replaceAll('.', '_')),
                    ].join(' · '),
                  ),
              ],
              selected: {wall!.id},
              onChanged: (v) {
                if (v.isNotEmpty) setState(() => _wall[kind] = v.single);
              },
            ),
          formGap,
          Text(l10n.logIndoorTapHint, style: muted),
          const SizedBox(height: SvaSpace.xs),
          Wrap(
            spacing: SvaSpace.xs,
            runSpacing: SvaSpace.xs,
            children: [
              for (final tile in tiles)
                _TileButton(
                  tile: tile,
                  semanticLabel: l10n.logIndoorTopped(
                    tile.label,
                    l10n.gymWallKind(kind),
                  ),
                  onTap: () => _tap(wall!.id, tile),
                ),
            ],
          ),
          if (last != null) ...[
            formGap,
            _LastClimb(
              entry: last,
              style: climbs.last.style,
              tile: _routes[last.route].tile,
              rope: _routes[last.route].kind == 'rope',
              onUndo: () => _remove(_entries.length - 1),
              onChanged: (ropeType) => setState(() {
                if (ropeType != null) _ropeType = ropeType;
              }),
            ),
          ],
        ],
        if (_entries.isNotEmpty) ...[
          formGap,
          Semantics(
            header: true,
            child: Text(
              l10n.logIndoorThisSession(_entries.length),
              style: text.headline,
            ),
          ),
          const SizedBox(height: SvaSpace.xs),
          for (final (i, e) in _entries.indexed)
            _EntryRow(
              tile: _routes[e.route].tile,
              wall: setup.walls
                  .where((w) => w.id == _routes[e.route].wallId)
                  .firstOrNull
                  ?.name,
              style: climbs[i].style,
              onRemove: () => _remove(i),
            ),
          formGap,
          FilledButton(
            onPressed: _saving ? null : () => _save(gymId),
            child: Text(l10n.logSave(_entries.length)),
          ),
        ],
      ],
    );
  }
}

/// A colour or grade to tap when topped. Large, so it is easy to hit with
/// chalky hands.
class _TileButton extends StatelessWidget {
  const new({
    required this.tile,
    required this.semanticLabel,
    required this.onTap,
  });

  final _Tile tile;
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
    final ink = fill.computeLuminance() > 0.4 ? dark : light;
    return Semantics(
      button: true,
      label: semanticLabel,
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
                  style: context.svaText.headline.copyWith(
                    color: tile.fill == null ? colors.text : ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the last tap logged, with quick changes: undo, not topped, tries,
/// and lead or top rope.
class _LastClimb extends StatelessWidget {
  const new({
    required this.entry,
    required this.style,
    required this.tile,
    required this.rope,
    required this.onUndo,
    required this.onChanged,
  });

  final _Entry entry;
  final AscentStyle style;
  final _Tile tile;
  final bool rope;
  final VoidCallback onUndo;

  /// Called after the entry changed, with the rope type when that changed.
  final ValueChanged<String?> onChanged;

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
            Row(
              spacing: SvaSpace.xs,
              children: [
                Expanded(
                  child: Text(
                    entry.topped
                        ? l10n.logIndoorAddedSend(tile.label)
                        : l10n.logIndoorAddedAttempt(tile.label),
                    style: text.label,
                  ),
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
                  onPressed: () {
                    entry.topped = !entry.topped;
                    onChanged(null);
                  },
                  child: Text(
                    entry.topped
                        ? l10n.logIndoorDidntTop
                        : l10n.logIndoorToppedIt,
                  ),
                ),
                _Stepper(
                  label: l10n.logIndoorTries,
                  value: entry.tries,
                  onChanged: (v) {
                    entry.tries = v;
                    onChanged(null);
                  },
                ),
              ],
            ),
            if (rope)
              ChipGroup(
                label: l10n.logIndoorRopeType,
                options: [
                  for (final t in const ['lead', 'toprope'])
                    (t, l10n.ascentType(t)),
                ],
                selected: {?entry.ropeType},
                onChanged: (v) {
                  if (v.isEmpty) return;
                  entry.ropeType = v.single;
                  onChanged(v.single);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.svaText.label),
        IconButton(
          tooltip: l10n.logIndoorFewerTries,
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(LucideIcons.minus),
        ),
        Text('$value', style: context.svaText.number),
        IconButton(
          tooltip: l10n.logIndoorMoreTries,
          onPressed: value < maxLoggedTriesPerTap
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(LucideIcons.plus),
        ),
      ],
    );
  }
}

/// Most tries one tap can count; more is a typo.
const maxLoggedTriesPerTap = 99;

class _EntryRow extends StatelessWidget {
  const new({
    required this.tile,
    required this.wall,
    required this.style,
    required this.onRemove,
  });

  final _Tile tile;
  final String? wall;
  final AscentStyle style;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    return Row(
      spacing: SvaSpace.xs,
      children: [
        Expanded(
          child: Text([tile.label, ?wall].join(' · '), style: text.body),
        ),
        SvaStyleTag(style: style.name, label: l10n.ascentStyle(style.name)),
        IconButton(
          tooltip: l10n.logRemoveClimb(tile.label),
          onPressed: onRemove,
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }
}
