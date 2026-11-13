import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/logging/gym_tap_card.dart';
import 'package:sva/src/logging/gym_tiles.dart';
import 'package:sva/src/logging/here.dart';
import 'package:sva/src/logging/time_zone.dart';
import 'package:sva/src/places/form_parts.dart';
import 'package:sva/src/routes.dart';
import 'package:sva_core/sva_core.dart'
    show GradeSystem, GymRouteKey, GymSessionLog, nearestWithin;
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// Logging at the gym (prototype/gym-log.html): pick the wall, then tap
/// the tile you topped. Which taps are the same climb, and each climb's
/// style, are sva_core's (`GymSessionLog`); this screen shows them.
class IndoorLog extends ConsumerStatefulWidget {
  const new({required this.onSaved, super.key});

  /// Called after the session is saved.
  final VoidCallback onSaved;

  @override
  ConsumerState<IndoorLog> createState() => _IndoorLogState();
}

class _IndoorLogState extends ConsumerState<IndoorLog> {
  /// The gym picked, or pinned by the first climb.
  String? _gymId;
  String? _kind;
  final _wall = <String, String>{};

  /// The rope type the last rope climb used, for the next one.
  String _ropeType = 'lead';
  GymSessionLog _log = const GymSessionLog();

  /// What each route's tile looked like when tapped, for the list.
  final _tiles = <GymTile>[];
  var _saving = false;

  /// The gym to log at: the one picked (or pinned by the first climb),
  /// else the one you are at, else the one logged at last, else the first
  /// set up. `here` says it was found from your location; `waiting` that
  /// the position is still coming, so the log does not open on one gym and
  /// then jump to another.
  ({String? id, bool here, bool waiting}) _choose(List<Area> gyms) {
    if (_gymId case final id? when gyms.any((g) => g.id == id)) {
      return (id: id, here: false, waiting: false);
    }
    // Location is asked for only when it could change which gym opens: more
    // than one gym, and at least one with a location.
    if (gyms.length > 1 &&
        gyms.any((g) => g.latitude != null && g.longitude != null)) {
      final here = ref.watch(hereProvider);
      if (here.isLoading) return (id: null, here: false, waiting: true);
      if (here.value case final p?) {
        final nearest = nearestWithin(p.lat, p.lon, [
          for (final g in gyms) (g.id, g.latitude, g.longitude),
        ]);
        if (nearest != null) return (id: nearest, here: true, waiting: false);
      }
    }
    final sessions = ref.watch(mySessionsProvider).value ?? const [];
    final last = sessions
        .where((s) => s.setting == 'indoor' && s.areaId != null)
        .map((s) => s.areaId)
        .firstOrNull;
    final id = gyms.any((g) => g.id == last) ? last : gyms.firstOrNull?.id;
    return (id: id, here: false, waiting: false);
  }

  void _tap(String gymId, String wallId, String kind, GymTile tile) {
    final key = (
      wallId: wallId,
      kind: kind,
      colourId: tile.colourId,
      gradeId: tile.gradeId,
    );
    setState(() {
      // The session stays at this gym once it has a climb.
      _gymId = gymId;
      final routes = _log.routes.length;
      _log = _log.tap(key, ropeType: kind == 'rope' ? _ropeType : null);
      if (_log.routes.length > routes) _tiles.add(tile);
    });
  }

  void _remove(int index) => setState(() {
    final route = _log.entries[index].route;
    final routes = _log.routes.length;
    _log = _log.remove(index);
    if (_log.routes.length < routes) _tiles.removeAt(route);
  });

  void _update(int index, {bool? topped, int? tries, String? ropeType}) =>
      setState(() {
        if (ropeType != null) _ropeType = ropeType;
        _log = _log.update(
          index,
          topped: topped,
          tries: tries,
          ropeType: ropeType,
        );
      });

  Future<void> _save(String gymId) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final climbs = _log.climbs;
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
                for (final GymRouteKey r in _log.routes)
                  IndoorRouteDraft(
                    wallId: r.wallId,
                    colourId: r.colourId,
                    gradeId: r.gradeId,
                  ),
              ],
              climbs: [
                for (final (i, e) in _log.entries.indexed)
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
    } on ClimbRejected catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.logClimbRejected(e.index + 1))),
      );
      if (mounted) setState(() => _saving = false);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.formSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The grade system a graded gym's tiles use for [kind], from settings.
  GradeSystem? _system(String kind) {
    final type = kind == 'boulder' ? 'boulder' : 'free_route';
    final settings = ref.watch(settingsProvider).value ?? const Settings();
    final systems =
        ref.watch(gradeSystemsProvider).value ?? const <GradeSystem>[];
    return systems
        .where((s) => s.key == settings.gradeSystemFor(type))
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    final muted = text.caption.copyWith(color: context.svaColors.textMuted);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    Widget message(String body) => Text(body, style: text.body);

    final gymsValue = ref.watch(gymsProvider);
    if (gymsValue.hasError) return message(l10n.logIndoorLoadFailed);
    final gyms = gymsValue.value;
    if (gyms == null) return const _Loading();
    final (id: gymId, here: foundHere, :waiting) = _choose(gyms);
    if (waiting) return const _Loading();
    if (gymId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: SvaSpace.sm,
        children: [
          message(l10n.logIndoorNoGym),
          OutlinedButton(
            onPressed: () => context.push(Routes.gymNew),
            child: Text(l10n.settingsGymAdd),
          ),
        ],
      );
    }
    final setupValue = ref.watch(gymSetupProvider(gymId));
    if (setupValue.hasError) return message(l10n.logIndoorLoadFailed);
    final setup = setupValue.value;
    if (setup == null) return const _Loading();

    final kinds = [
      for (final k in const ['boulder', 'rope'])
        if (setup.walls.any((w) => w.kind == k)) k,
    ];
    // What the screen shows is what a tap logs. Boulder first, as most
    // gym climbs are.
    final kind = kinds.contains(_kind)
        ? _kind
        : kinds.contains('boulder')
        ? 'boulder'
        : kinds.firstOrNull;
    final walls = [
      for (final w in setup.walls)
        if (w.kind == kind) w,
    ];
    final wall =
        walls.where((w) => w.id == _wall[kind]).firstOrNull ??
        walls.firstOrNull;
    final tiles = kind == null
        ? const <GymTile>[]
        : gymTiles(
            setup,
            system: _system(kind),
            ungraded: l10n.logIndoorUngraded,
          );
    final climbs = _log.climbs;
    final entries = _log.entries;
    String? wallName(String id) =>
        setup.walls.where((w) => w.id == id).firstOrNull?.name;

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
              if (entries.isNotEmpty)
                for (final g in gyms)
                  if (g.id != gymId) g.id,
            },
            onChanged: (v) {
              if (v.isNotEmpty) setState(() => _gymId = v.single);
            },
          ),
        ] else
          Text(setup.gym.name, style: text.headline),
        if (foundHere) Text(l10n.logIndoorFoundHere, style: muted),
        formGap,
        if (kind == null || wall == null)
          message(l10n.logIndoorNoWalls)
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
                      if (w.heightM case final h?)
                        '${number.format(h)} ${l10n.feedStatMetres}',
                      if (w.angle case final a?)
                        switch (w.angleDeg) {
                          final deg? => l10n.wallAngleDegrees(
                            l10n.attributeValue(a.replaceAll('.', '_')),
                            deg,
                          ),
                          null => l10n.attributeValue(a.replaceAll('.', '_')),
                        },
                    ].join(' · '),
                  ),
              ],
              selected: {wall.id},
              onChanged: (v) {
                if (v.isNotEmpty) setState(() => _wall[kind] = v.single);
              },
            ),
          formGap,
          if (tiles.isEmpty)
            message(l10n.logIndoorNoTiles)
          else ...[
            Text(l10n.logIndoorTapHint, style: muted),
            const SizedBox(height: SvaSpace.xs),
            Wrap(
              spacing: SvaSpace.xs,
              runSpacing: SvaSpace.xs,
              children: [
                for (final tile in tiles)
                  GymTileButton(
                    tile: tile,
                    semanticLabel: l10n.logIndoorTopped(
                      tile.label,
                      l10n.logIndoorKind(kind),
                    ),
                    onTap: () => _tap(gymId, wall.id, kind, tile),
                  ),
              ],
            ),
          ],
          if (entries.isNotEmpty) ...[
            formGap,
            GymTapCard(
              entry: entries.last,
              style: climbs.last.style,
              label: _tiles[entries.last.route].label,
              onUndo: () => _remove(entries.length - 1),
              onTopped: (t) => _update(entries.length - 1, topped: t),
              onTries: (t) => _update(entries.length - 1, tries: t),
              onRopeType: (t) => _update(entries.length - 1, ropeType: t),
            ),
          ],
        ],
        if (entries.isNotEmpty) ...[
          formGap,
          Semantics(
            header: true,
            child: Text(
              l10n.logIndoorThisSession(entries.length),
              style: text.headline,
            ),
          ),
          const SizedBox(height: SvaSpace.xs),
          for (final (i, e) in entries.indexed)
            Row(
              spacing: SvaSpace.xs,
              children: [
                Expanded(
                  child: Text(
                    [
                      _tiles[e.route].label,
                      ?wallName(_log.routes[e.route].wallId),
                    ].join(' · '),
                    style: text.body,
                  ),
                ),
                SvaStyleTag(
                  style: climbs[i].style.name,
                  label: l10n.ascentStyle(climbs[i].style.name),
                ),
                IconButton(
                  tooltip: l10n.logRemoveClimb(_tiles[e.route].label),
                  onPressed: () => _remove(i),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          formGap,
          FilledButton(
            onPressed: _saving ? null : () => _save(gymId),
            child: Text(l10n.logSave(entries.length)),
          ),
        ],
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(SvaSpace.lg),
    child: Center(child: CircularProgressIndicator()),
  );
}
