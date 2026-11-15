import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/logging/gym_climb_details.dart';
import 'package:sva/src/logging/gym_finish_sheet.dart';
import 'package:sva/src/logging/gym_tap_card.dart';
import 'package:sva/src/logging/gym_tiles.dart';
import 'package:sva/src/logging/here.dart';
import 'package:sva/src/logging/time_zone.dart';
import 'package:sva/src/places/form_parts.dart';
import 'package:sva/src/places/labels.dart';
import 'package:sva/src/routes.dart';
import 'package:sva_core/sva_core.dart'
    show
        Grade,
        GradeSystem,
        GymMatchKind,
        GymPastRoute,
        GymRouteKey,
        GymSessionLog,
        GymSessionSummaryOf,
        nearestWithin;
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

  /// The gym [_log]'s projects are from.
  String? _logGym;

  /// The details of each of [_log]'s entries, in the same order.
  final _details = <_ClimbDetails>[];

  /// Live, the session starts with its first climb and ends at Finish.
  /// Otherwise it is logged afterwards, on [_day], with no times.
  var _live = true;
  DateTime? _startedAt;
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  /// Keeps a live session's minutes current.
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_live && _startedAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  /// Picks a day other than today or yesterday for a past session.
  Future<void> _pickDay() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(1950),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

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

  void _tap(String gymId, GymWall wall, GymTile tile) {
    final key = (
      wallId: wall.id,
      kind: wall.kind,
      colourId: tile.colourId,
      gradeId: tile.gradeId,
      angle: wall.angle,
    );
    setState(() {
      if (_live) _startedAt ??= DateTime.now();
      // The session stays at this gym once it has a climb.
      _gymId = gymId;
      _log = _log.tap(key, ropeType: wall.kind == 'rope' ? _ropeType : null);
      _details.add(_ClimbDetails());
    });
  }

  void _sendProject(String gymId, GymPastRoute project) => setState(() {
    if (_live) _startedAt ??= DateTime.now();
    _gymId = gymId;
    _log = _log.sendProject(
      project.id,
      ropeType: project.key.kind == 'rope' ? _ropeType : null,
    );
    _details.add(_ClimbDetails());
  });

  /// Marks [project] as gone, so it is no longer offered.
  Future<void> _gone(
    GymPastRoute project, {
    required String colour,
    required String wall,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.svaColors;
    // You can't log on it afterwards, so ask first (docs/DESIGN.md,
    // Destructive button).
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logIndoorProjectGoneTitle(colour, wall)),
        content: Text(l10n.logIndoorProjectGoneBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.logIndoorProjectGoneCancel),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logIndoorProjectGoneConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await ref
          .read(gymRouteRepositoryProvider)
          .markGone(project.id, userId: ref.read(currentUserIdProvider));
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.logIndoorProjectGoneFailed)),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _log = _log.withoutProject(project.id));
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.logIndoorProjectGoneDone(colour, wall))),
    );
  }

  void _remove(int index) => setState(() {
    _log = _log.remove(index);
    _details.removeAt(index);
    // Live, the next first climb starts it again.
    if (_log.entries.isEmpty) _startedAt = null;
  });

  void _update(
    int index, {
    bool? topped,
    bool? rested,
    int? tries,
    String? ropeType,
  }) => setState(() {
    if (ropeType != null) _ropeType = ropeType;
    _log = _log.update(
      index,
      topped: topped,
      rested: rested,
      tries: tries,
      ropeType: ropeType,
    );
  });

  /// Saves the session with what was filled in when finishing, live
  /// until [endAt]. Returns why it wasn't saved, or `null` once it is.
  Future<String?> _save(
    String gymId,
    GymSetup setup,
    GymFinishChoices choices, {
    required String autoTitle,
    required DateTime endAt,
  }) async {
    final l10n = AppLocalizations.of(context);
    final climbs = _log.climbs;
    var startAt = _live ? (_startedAt ?? endAt) : null;
    final day = startAt ?? _day;
    // Left running for over a day: kept on the day it started, without
    // times that can't be right.
    if (startAt != null &&
        endAt.difference(startAt) > const Duration(days: 1)) {
      startAt = null;
    }
    try {
      await ref
          .read(sessionLoggerProvider)
          .logIndoor(
            IndoorSessionDraft(
              gymId: gymId,
              localDate: DateFormat('yyyy-MM-dd').format(day),
              tz: deviceTimeZone(day.timeZoneOffset),
              visibility: choices.visibility,
              title: choices.title ?? autoTitle,
              partners: choices.partners,
              startAt: startAt,
              endAt: startAt == null ? null : endAt,
              routes: [
                for (final (i, GymRouteKey r) in _log.routes.indexed)
                  if (_log.routeIds[i] case final id?)
                    IndoorRouteDraft(routeId: id)
                  else
                    IndoorRouteDraft(
                      wallId: r.wallId,
                      colourId: r.colourId,
                      gradeId: r.gradeId,
                      // Only when it differs: the wall's is the default.
                      angle:
                          r.angle ==
                              setup.walls
                                  .where((w) => w.id == r.wallId)
                                  .firstOrNull
                                  ?.angle
                          ? null
                          : r.angle,
                    ),
              ],
              climbs: [
                for (final (i, e) in _log.entries.indexed)
                  IndoorClimbDraft(
                    route: e.route,
                    style: climbs[i].style,
                    tries: climbs[i].tries,
                    ascentType: e.ropeType ?? 'boulder',
                    // Your grade is for a climb you topped.
                    personalGradeId: e.topped ? _details[i].gradeId : null,
                    holds: [..._details[i].holds],
                    movement: [..._details[i].movement],
                    beta: _details[i].beta,
                  ),
              ],
            ),
            userId: ref.read(currentUserIdProvider),
          );
      return null;
    } on ClimbRejected catch (e) {
      return l10n.logClimbRejected(e.index + 1);
    } on Object {
      return l10n.formSaveFailed;
    }
  }

  /// The other climbs entry [index], shown as [colour], might be, and a
  /// different one of that colour when it was matched to one.
  List<(String, VoidCallback)> _matches(
    AppLocalizations l10n,
    int index,
    String colour,
  ) => [
    for (final m in _log.matches(index))
      (
        switch (m.kind) {
          GymMatchKind.triedToday => l10n.logIndoorMatchTried(colour),
          GymMatchKind.project => l10n.logIndoorMatchProject(
            colour,
            formatDay(
              l10n,
              _log.past.firstWhere((p) => p.id == m.pastId).lastTried,
            ),
          ),
          GymMatchKind.sentToday => l10n.logIndoorMatchAgain(colour),
        },
        () => setState(() => _log = _log.moveTo(index, m)),
      ),
    if (!_log.isFresh(index))
      (
        l10n.logIndoorMatchDifferent(colour),
        () => setState(() => _log = _log.moveToNew(index)),
      ),
  ];

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
    // Without its projects the log still works, as for a new gym.
    final projectsValue = ref.watch(gymProjectsProvider(gymId));
    if (projectsValue.isLoading && !projectsValue.hasValue) {
      return const _Loading();
    }
    if (_logGym != gymId && _log.entries.isEmpty) {
      _logGym = gymId;
      _log = GymSessionLog(
        past: _pastRoutes(projectsValue.value ?? const [], setup),
      );
    }

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
    final tilesByKind = <String, List<GymTile>>{};
    List<GymTile> tilesFor(String kind) => tilesByKind[kind] ??= gymTiles(
      setup,
      system: _system(kind),
      ungraded: l10n.logIndoorUngraded,
    );
    final tiles = kind == null ? const <GymTile>[] : tilesFor(kind);
    final climbs = _log.climbs;
    final entries = _log.entries;
    String? wallName(String id) =>
        setup.walls.where((w) => w.id == id).firstOrNull?.name;
    // A route is shown as its tile: its colour, grade, or the ungraded one.
    GymTile? tileOf(GymRouteKey key) => tilesFor(key.kind)
        .where((t) => t.colourId == key.colourId && t.gradeId == key.gradeId)
        .firstOrNull;
    // A grade outside the grade system in settings, say after changing
    // it, has no tile; it shows as a climb, and taps can't match it.
    String labelOf(GymRouteKey key) =>
        tileOf(key)?.label ?? l10n.logIndoorUngraded;
    // Inside a sentence a colour is lowercase ("the blue you tried"); a
    // grade such as 6A stays as it is.
    String inSentence(GymRouteKey key) =>
        key.colourId == null ? labelOf(key) : labelOf(key).toLowerCase();
    final projects = kind == null
        ? const <({GymPastRoute route, int tries})>[]
        : _log.projects(kind);
    final systemFor = {for (final k in kinds) k: _system(k)};

    // Five grades around a climb's, in your grade system for its kind: the
    // gym's grade, or the middle of its colour's range. None when the gym
    // has no grade for it.
    List<(String, String)> gradeOptions(GymRouteKey key) {
      final system = systemFor[key.kind];
      if (system == null) return const [];
      String idOf(Grade g) => seedId('grade:${system.key}:${g.label}');
      double? score;
      if (key.colourId case final id?) {
        final c = setup.colours.where((c) => c.id == id).firstOrNull;
        final (lo, hi) = key.kind == 'boulder'
            ? (c?.boulderMinScore, c?.boulderMaxScore)
            : (c?.routeMinScore, c?.routeMaxScore);
        if (lo != null && hi != null) score = (lo + hi) / 2;
      } else if (key.gradeId case final id?) {
        score = system.grades.where((g) => idOf(g) == id).firstOrNull?.score;
      }
      if (score == null) return const [];
      return [for (final g in system.around(score)) (idOf(g), g.label)];
    }

    // The details sheet for entry [index]. It shows the log as it changes.
    void openDetails(int index) => unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheet) {
            void change(VoidCallback f) {
              setState(f);
              setSheet(() {});
            }

            if (index >= _log.entries.length) return const SizedBox.shrink();
            final e = _log.entries[index];
            final key = _log.routes[e.route];
            final d = _details[index];
            return GymClimbDetails(
              title: l10n.logIndoorDetailsTitle(
                labelOf(key),
                l10n.logIndoorKind(key.kind),
              ),
              entry: e,
              style: _log.climbs[index].style,
              walls: [
                for (final w in setup.walls)
                  if (w.kind == key.kind) (w.id, w.name),
              ],
              wallId: key.wallId,
              angle: key.angle,
              wallAngle: setup.walls
                  .where((w) => w.id == key.wallId)
                  .firstOrNull
                  ?.angle,
              grades: gradeOptions(key),
              gradeId: d.gradeId,
              holds: d.holds,
              movement: d.movement,
              beta: d.beta,
              onResult: (r) => change(
                () => _log = _log.update(
                  index,
                  topped: r != 'no',
                  rested: r == 'rests',
                ),
              ),
              onTries: (t) => change(() => _log = _log.update(index, tries: t)),
              onRopeType: (t) => change(() {
                _ropeType = t;
                _log = _log.update(index, ropeType: t);
              }),
              onWall: (id) => change(() {
                final w = setup.walls.firstWhere((w) => w.id == id);
                _log = _log.moveToWall(index, id, angle: w.angle);
                // Fixing the latest climb moves the log there too: you
                // most likely forgot to switch.
                if (index == _log.entries.length - 1) _wall[w.kind] = id;
              }),
              onAngle: (a) => change(
                () => _log = _log.moveToWall(index, key.wallId, angle: a),
              ),
              onGrade: (g) => change(() => d.gradeId = g),
              onHolds: (v) => change(() => d.holds = v),
              onMovement: (v) => change(() => d.movement = v),
              // The field keeps its own text; nothing else shows it.
              onBeta: (b) => d.beta = b,
              onRemove: () {
                Navigator.pop(sheetContext);
                _remove(index);
              },
              onDone: () => Navigator.pop(sheetContext),
            );
          },
        ),
      ),
    );

    final time = DateFormat.Hm(l10n.localeName);
    final today = DateUtils.dateOnly(DateTime.now());
    String dayOf(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

    // Finishing: how the session went, then what you fill in.
    void openFinish() {
      final s = _log.summary(
        heightM: (id) =>
            setup.walls.where((w) => w.id == id).firstOrNull?.heightM,
        // Tiles go from easy to hard.
        rank: (key) {
          final i = tilesFor(key.kind).indexWhere(
            (t) => t.colourId == key.colourId && t.gradeId == key.gradeId,
          );
          return i < 0 ? null : i;
        },
      );
      final bothKinds = s.boulders > 0 && s.ropes > 0;
      // Boulders and routes share a gym's colours, so a mixed session says
      // which.
      String kindLabel(GymRouteKey key) => bothKinds && key.colourId != null
          ? l10n.logIndoorDetailsTitle(
              labelOf(key),
              l10n.logIndoorKind(key.kind),
            )
          : labelOf(key);
      final best = [
        for (final k in const ['boulder', 'rope'])
          if (s.best[k] case final key?) kindLabel(key),
      ];
      final counts = [
        if (s.boulders > 0) l10n.logFinishBoulders(s.boulders),
        if (s.ropes > 0) l10n.logFinishRoutes(s.ropes),
      ];
      final autoTitle = [
        if (counts case [final a, final b])
          l10n.logFinishAnd(a, b)
        else
          ...counts,
        if (best.isNotEmpty) l10n.logFinishBestOf(best.join(' / ')),
      ].join(' · ');
      // What the sheet shows is what is saved.
      final endAt = DateTime.now();
      final day = _live ? today : _day;
      final started = _startedAt;
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (sheetContext) => GymFinishSheet(
            stats: [
              SvaCardStat(
                value: number.format(s.climbs),
                label: l10n.logFinishClimbs,
              ),
              SvaCardStat(
                value: number.format(s.sends),
                label: l10n.logFinishSends,
              ),
              SvaCardStat(
                value: number.format(s.flashes),
                label: l10n.logFinishFlashes,
              ),
              if (s.metres case final m?)
                SvaCardStat(
                  value: number.format(m.round()),
                  unit: l10n.feedStatMetres,
                  label: l10n.logFinishOnRope,
                )
              else
                SvaCardStat(
                  value: switch (s.best['boulder'] ?? s.best['rope']) {
                    final key? => labelOf(key),
                    null => '–',
                  },
                  label: l10n.logFinishBest,
                ),
            ],
            projectSends: [
              for (final p in s.projectSends)
                () {
                  final key = _log.routes[_log.entries[p.index].route];
                  return l10n.logFinishProjectSent(
                    labelOf(key),
                    wallName(key.wallId) ?? '',
                    p.tries,
                    // As calendar days, so a clock change doesn't count.
                    DateTime.utc(day.year, day.month, day.day)
                        .difference(DateTime.parse('${p.lastTried}T00:00Z'))
                        .inDays,
                  );
                }(),
            ],
            bars: [
              for (final g in s.grades)
                () {
                  final label = labelOf((
                    wallId: '',
                    kind: g.kind,
                    colourId: g.colourId,
                    gradeId: g.gradeId,
                    angle: null,
                  ));
                  return (
                    label: bothKinds
                        ? '$label ${l10n.logFinishKindShort(g.kind)}'
                        : label,
                    flash: g.flash,
                    redpoint: g.redpoint,
                    repeat: g.repeat,
                    attempt: g.attempt,
                  );
                }(),
            ],
            bothKinds: bothKinds,
            filledIn: [
              setup.gym.name,
              if (_live && started != null)
                '${time.format(started)}–${time.format(endAt)}'
              else
                formatDay(l10n, dayOf(_day)),
            ].join(' · '),
            autoTitle: autoTitle,
            visibility:
                ref.read(settingsProvider).value?.defaultVisibility ??
                const Settings().defaultVisibility,
            onClose: () => Navigator.pop(sheetContext),
            onSave: (choices) async {
              final messenger = ScaffoldMessenger.of(context);
              final error = await _save(
                gymId,
                setup,
                choices,
                autoTitle: autoTitle,
                endAt: endAt,
              );
              if (error == null) {
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                widget.onSaved();
                messenger.showSnackBar(SnackBar(content: Text(l10n.logSaved)));
              }
              return error;
            },
          ),
        ),
      );
    }

    final yesterday = DateUtils.addDaysToDate(today, -1);
    final dayKey = _day == today
        ? 'today'
        : _day == yesterday
        ? 'yesterday'
        : 'other';

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
        // Live, or logged afterwards on a day you pick (prototype,
        // "Log a past gym session").
        Row(
          children: [
            Expanded(
              child: Text(switch ((_live, _startedAt)) {
                (true, final t?) => l10n.logIndoorLive(
                  time.format(t),
                  max(1, DateTime.now().difference(t).inMinutes),
                ),
                (true, null) => l10n.logIndoorLiveWaiting,
                (false, _) => l10n.logIndoorPast,
              }, style: muted),
            ),
            TextButton(
              onPressed: () => setState(() {
                _live = !_live;
                _day = today;
                // Back to live with climbs logged: it runs from now.
                _startedAt = _live && entries.isNotEmpty
                    ? DateTime.now()
                    : null;
              }),
              child: Text(
                _live ? l10n.logIndoorLogPast : l10n.logIndoorLogLive,
              ),
            ),
          ],
        ),
        if (!_live)
          ChipGroup(
            label: l10n.logIndoorDay,
            options: [
              ('today', l10n.logIndoorToday),
              ('yesterday', l10n.logIndoorYesterday),
              (
                'other',
                dayKey == 'other'
                    ? formatDay(l10n, dayOf(_day))
                    : l10n.logIndoorOtherDay,
              ),
            ],
            selected: {dayKey},
            onChanged: (v) => switch (v.firstOrNull) {
              'today' => setState(() => _day = today),
              'yesterday' => setState(() => _day = yesterday),
              // Another day, or the one picked tapped again to change it.
              _ => unawaited(_pickDay()),
            },
          ),
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
                        _angleLabel(
                          l10n,
                          l10n.attributeValue(a.replaceAll('.', '_')),
                          w.angleDeg,
                        ),
                    ].join(' · '),
                  ),
              ],
              selected: {wall.id},
              onChanged: (v) {
                if (v.isNotEmpty) setState(() => _wall[kind] = v.single);
              },
            ),
          if (projects.isNotEmpty) ...[
            formGap,
            Semantics(
              header: true,
              child: Text(l10n.logIndoorProjects, style: text.label),
            ),
            Text(l10n.logIndoorProjectsHint, style: muted),
            const SizedBox(height: SvaSpace.xs),
            for (final (:route, :tries) in projects)
              _ProjectCard(
                tile: tileOf(route.key),
                colour: labelOf(route.key),
                wall: wallName(route.key.wallId) ?? '',
                detail: l10n.logIndoorProjectSub(
                  tries,
                  formatDay(l10n, route.lastTried),
                ),
                onSend: () => _sendProject(gymId, route),
                // One climbed in this session stays, so it can be saved.
                onGone: _log.routeIds.contains(route.id)
                    ? null
                    : () => _gone(
                        route,
                        colour: labelOf(route.key),
                        wall: wallName(route.key.wallId) ?? '',
                      ),
              ),
          ],
          formGap,
          if (tiles.isEmpty)
            message(l10n.logIndoorNoTiles)
          else ...[
            Text(l10n.logIndoorTapHint, style: muted),
            Text(l10n.logIndoorHoldHint, style: muted),
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
                    onTap: () => _tap(gymId, wall, tile),
                    onLongPress: () {
                      _tap(gymId, wall, tile);
                      openDetails(_log.entries.length - 1);
                    },
                    longPressHint: l10n.logIndoorAddDetails,
                  ),
              ],
            ),
          ],
          if (entries.isNotEmpty) ...[
            formGap,
            GymTapCard(
              entry: entries.last,
              style: climbs.last.style,
              label: labelOf(_log.routes[entries.last.route]),
              matches: _matches(
                l10n,
                entries.length - 1,
                inSentence(_log.routes[entries.last.route]),
              ),
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
                  child: Semantics(
                    button: true,
                    label: switch (wallName(_log.routes[e.route].wallId)) {
                      final wall? => l10n.logIndoorDetailsLabel(
                        labelOf(_log.routes[e.route]),
                        wall,
                      ),
                      // A wall removed since: the climb alone.
                      null => labelOf(_log.routes[e.route]),
                    },
                    onTap: () => openDetails(i),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => openDetails(i),
                      // Big enough to hit (docs/DESIGN.md, touch targets).
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          [
                            labelOf(_log.routes[e.route]),
                            ?wallName(_log.routes[e.route].wallId),
                          ].join(' · '),
                          style: text.body,
                        ),
                      ),
                    ),
                  ),
                ),
                SvaStyleTag(
                  style: climbs[i].style.name,
                  label: l10n.ascentStyle(climbs[i].style.name),
                ),
                IconButton(
                  tooltip: l10n.logRemoveClimb(labelOf(_log.routes[e.route])),
                  onPressed: () => _remove(i),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          formGap,
          FilledButton(
            onPressed: openFinish,
            child: Text(l10n.logIndoorFinish),
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

/// A wall's angle type, with its degrees when they are known.
String _angleLabel(AppLocalizations l10n, String angle, int? deg) =>
    deg == null ? angle : l10n.wallAngleDegrees(angle, deg);

/// [projects] as the gym log knows them. One on a wall that was removed
/// is left out: it can't be climbed.
List<GymPastRoute> _pastRoutes(List<GymProject> projects, GymSetup setup) => [
  for (final p in projects)
    if (p.route.gymWallId case final wall?
        when setup.walls.any((w) => w.id == wall))
      (
        id: p.route.id,
        key: (
          wallId: wall,
          kind: p.route.discipline == 'boulder' ? 'boulder' : 'rope',
          colourId: p.route.gymColourGradeId,
          gradeId: p.gradeId,
          angle: p.route.angle,
        ),
        tries: p.tries,
        lastTried: p.lastTried,
      ),
];

/// A project in "Your projects here": tap it when you send it, or mark it
/// as gone.
class _ProjectCard extends StatelessWidget {
  const new({
    required this.tile,
    required this.colour,
    required this.wall,
    required this.detail,
    required this.onSend,
    required this.onGone,
  });

  final GymTile? tile;
  final String colour;
  final String wall;

  /// Tries so far and when.
  final String detail;
  final VoidCallback onSend;

  /// `null` when it can't be marked as gone now.
  final VoidCallback? onGone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    final colors = context.svaColors;
    return Card(
      margin: const EdgeInsets.only(bottom: SvaSpace.xs),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.logIndoorProjectSend(colour, wall),
              onTap: onSend,
              excludeSemantics: true,
              child: InkWell(
                onTap: onSend,
                child: Padding(
                  padding: const EdgeInsets.all(SvaSpace.sm),
                  child: Row(
                    spacing: SvaSpace.sm,
                    children: [
                      Container(
                        width: SvaSpace.lg,
                        height: SvaSpace.lg,
                        decoration: BoxDecoration(
                          color: tile?.fill ?? colors.surfaceSunk,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.line),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                colour,
                                wall,
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: text.label,
                            ),
                            Text(
                              detail,
                              style: text.caption.copyWith(
                                color: colors.textMuted,
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
          if (onGone != null)
            Semantics(
              button: true,
              label: l10n.logIndoorProjectGoneLabel(colour, wall),
              onTap: onGone,
              excludeSemantics: true,
              child: TextButton(
                onPressed: onGone,
                child: Text(l10n.logIndoorProjectGone),
              ),
            ),
        ],
      ),
    );
  }
}

/// What you added to one climb in its details. Not rules, so the gym log
/// keeps them beside sva_core's entries.
class _ClimbDetails {
  Set<String> holds = {};
  Set<String> movement = {};
  String beta = '';

  /// Your own grade, for a climb you topped.
  String? gradeId;
}
