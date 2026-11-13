import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva/src/data/providers.dart';
import 'package:sva/src/gyms/colour_scale_editor.dart';
import 'package:sva/src/places/form_parts.dart';
import 'package:sva/src/places/labels.dart';
import 'package:sva/src/places/location_picker.dart';
import 'package:sva_core/sva_core.dart' show angleForDegrees, isWallAngleDeg;
import 'package:sva_data/sva_data.dart';
import 'package:sva_ui/sva_ui.dart';

/// Angles a wall can be set as, from the attribute definitions.
final List<String> _angles = attributeSeed
    .firstWhere((d) => d.key == 'angle')
    .valueKeys;

/// The form for a gym, its walls and its colours: new without [gymId],
/// else that gym.
/// A new gym starts with a rope wall and a boulder area, so a typical gym
/// needs only a name and a wall or two more.
class GymFormScreen extends ConsumerStatefulWidget {
  const new({this.gymId, super.key});

  final String? gymId;

  @override
  ConsumerState<GymFormScreen> createState() => _GymFormScreenState();
}

/// One wall while it is edited.
class _Wall {
  new({
    required String name,
    required this.kind,
    this.id,
    double? heightM,
    this.angle,
    int? angleDeg,
    this.lastResetOn,
  }) : name = TextEditingController(text: name),
       height = TextEditingController(text: _metres(heightM)),
       degrees = TextEditingController(text: angleDeg?.toString() ?? '');

  final String? id;
  final TextEditingController name;
  final TextEditingController height;

  /// Degrees past vertical; empty when not known.
  final TextEditingController degrees;
  String kind;
  String? angle;

  /// `YYYY-MM-DD` of the wall's last reset, or `null` if never.
  String? lastResetOn;

  /// A unique key, so removing a wall keeps the others' fields.
  final key = UniqueKey();

  static String _metres(double? m) => switch (m) {
    null => '',
    final m when m == m.roundToDouble() => '${m.round()}',
    final m => '$m',
  };

  void dispose() {
    name.dispose();
    height.dispose();
    degrees.dispose();
  }
}

class _GymFormScreenState extends ConsumerState<GymFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _country = TextEditingController(text: 'NO');
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  var _grading = 'colour';
  final _walls = <_Wall>[];
  final _colours = <ColourEntry>[];

  /// Whether the gym's own fields can be changed: always for a new gym,
  /// and for the user's private gyms. Walls and colours are the user's own
  /// either way.
  var _ownGym = true;
  var _loading = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.gymId case final id?) {
      _loading = true;
      unawaited(_load(id));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.gymId == null && _walls.isEmpty) {
      final l10n = AppLocalizations.of(context);
      _walls.addAll([
        _Wall(
          name: l10n.gymFormWallDefaultRope,
          kind: 'rope',
          heightM: 14,
          angle: 'angle.vertical',
        ),
        _Wall(
          name: l10n.gymFormWallDefaultBoulder,
          kind: 'boulder',
          heightM: 4.5,
          angle: 'angle.overhang',
        ),
      ]);
      _colours.addAll(defaultColours(l10n));
    }
  }

  Future<void> _load(String id) async {
    final userId = ref.read(currentUserIdProvider);
    GymSetup? setup;
    try {
      setup = await ref.read(gymEditorProvider).setup(id, userId: userId);
    } on Object {
      setup = null;
    }
    if (!mounted) return;
    if (setup == null) {
      // Looked up after the await: the screen can't read its context
      // while initState runs.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).gymFormNotFound)),
      );
      context.pop();
      return;
    }
    final (:gym, :grading, :walls, :colours) = setup;
    setState(() {
      _name.text = gym.name;
      _country.text = gym.countryCode;
      _lat.text = gym.latitude?.toStringAsFixed(5) ?? '';
      _lon.text = gym.longitude?.toStringAsFixed(5) ?? '';
      _grading = grading;
      _ownGym = gym.createdBy == userId && gym.visibility == 'private';
      _walls.addAll([
        for (final w in walls)
          _Wall(
            id: w.id,
            name: w.name,
            kind: w.kind,
            heightM: w.heightM,
            angle: w.angle,
            angleDeg: w.angleDeg,
            lastResetOn: w.lastResetOn,
          ),
      ]);
      _colours.addAll([for (final c in colours) ColourEntry.fromRow(c)]);
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _country, _lat, _lon]) {
      c.dispose();
    }
    for (final wall in _walls) {
      wall.dispose();
    }
    for (final colour in _colours) {
      colour.dispose();
    }
    super.dispose();
  }

  void _addWall() {
    final l10n = AppLocalizations.of(context);
    // A new wall copies the kind of the last one: gyms list their walls
    // of a kind together.
    final last = _walls.lastOrNull;
    // The next number no wall is named after yet, so removing a wall and
    // adding one never gives two walls the same name.
    final names = {for (final w in _walls) w.name.text.trim()};
    var number = _walls.length + 1;
    while (names.contains(l10n.gymFormWallDefault(number))) {
      number++;
    }
    setState(
      () => _walls.add(
        _Wall(
          name: l10n.gymFormWallDefault(number),
          kind: last?.kind ?? 'rope',
          heightM: last == null ? null : parseDecimal(last.height.text),
          angle: 'angle.vertical',
        ),
      ),
    );
  }

  /// Marks [wall] as reset today, after asking: the routes still up on it
  /// stop being suggested. Saved at once, since it is something that
  /// happened at the gym, not an edit to the form.
  Future<void> _resetWall(_Wall wall) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.svaColors;
    final name = wall.name.text;
    // It ends the open projects on the wall, so ask first and say so
    // (docs/DESIGN.md, Destructive button).
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.gymFormWallResetTitle(name)),
        content: Text(l10n.gymFormWallResetBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.gymFormWallResetCancel),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.gymFormWallResetConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await ref
          .read(gymRouteRepositoryProvider)
          .resetWall(
            wall.id!,
            on: today,
            userId: ref.read(currentUserIdProvider),
          );
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.formSaveFailed)));
      return;
    }
    if (!mounted) return;
    setState(() => wall.lastResetOn = today);
    // Replaces a message from an earlier try, so this one shows now.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.gymFormWallResetDone(wall.name.text))),
      );
  }

  void _removeWall(_Wall wall) => setState(() {
    _walls.remove(wall);
    wall.dispose();
  });

  Future<void> _save() async {
    // Colours are kept, out of sight, while another grading is picked. One
    // without a name would fail to save, so show them again with the
    // message where the user can see it.
    if (_grading != 'colour' &&
        _colours.any((c) => c.name.text.trim().isEmpty)) {
      setState(() => _grading = 'colour');
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _form.currentState?.validate(),
      );
      return;
    }
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    final gym = NewGym(
      name: _name.text,
      countryCode: _country.text.trim().toUpperCase(),
      grading: _grading,
      location: LocationFields.locationOf(_lat, _lon),
    );
    final walls = [
      for (final w in _walls)
        WallDraft(
          id: w.id,
          name: w.name.text,
          kind: w.kind,
          heightM: parseDecimal(w.height.text),
          angle: w.angle,
          angleDeg: _degrees(w.degrees.text),
        ),
    ];
    // Colours are kept while another grading is picked, so switching back
    // does not lose them.
    final colours = [for (final c in _colours) c.draft];
    final editor = ref.read(gymEditorProvider);
    final userId = ref.read(currentUserIdProvider);
    try {
      if (widget.gymId case final id? when !_ownGym) {
        // A shared gym: only the user's walls and colours are theirs to
        // change.
        await editor.saveOwn(
          id,
          walls: walls,
          colours: colours,
          userId: userId,
        );
      } else if (widget.gymId case final id?) {
        await editor.updateGym(
          id,
          gym,
          walls: walls,
          colours: colours,
          userId: userId,
        );
      } else {
        await editor.addGym(
          gym,
          walls: walls,
          colours: colours,
          userId: userId,
        );
      }
      router.pop();
    } on Object {
      // The form checks every field first, so this is a database failure
      // or a value the editor refused.
      messenger.showSnackBar(SnackBar(content: Text(l10n.formSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.svaText;
    final muted = text.caption.copyWith(color: context.svaColors.textMuted);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gymId == null ? l10n.gymFormNew : l10n.gymFormEdit),
      ),
      body: _loading
          ? const SizedBox.shrink()
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(SvaSpace.screen),
                children: [
                  if (!_ownGym) ...[
                    Text(l10n.gymFormNotYours, style: muted),
                    formGap,
                  ],
                  TextFormField(
                    controller: _name,
                    enabled: _ownGym,
                    decoration: InputDecoration(labelText: l10n.formName),
                    textCapitalization: TextCapitalization.words,
                    maxLength: maxNameLength,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? l10n.gymFormNameMissing
                        : null,
                  ),
                  formGap,
                  ChipGroup(
                    label: l10n.gymFormGrading,
                    options: [
                      for (final grading in gymGradings)
                        (grading, l10n.gymGrading(grading)),
                    ],
                    selected: {_grading},
                    disabled: _ownGym ? const {} : {...gymGradings},
                    onChanged: (v) {
                      if (v.isNotEmpty) setState(() => _grading = v.single);
                    },
                  ),
                  if (_grading == 'colour')
                    ColourScaleEditor(
                      colours: _colours,
                      onChanged: () => setState(() {}),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: SvaSpace.xl,
                      bottom: SvaSpace.xs,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(l10n.gymFormWalls, style: text.headline),
                    ),
                  ),
                  Text(l10n.gymFormWallsNote, style: muted),
                  for (final wall in _walls) ...[
                    const SizedBox(height: SvaSpace.sm),
                    _WallCard(
                      key: wall.key,
                      wall: wall,
                      onChanged: () => setState(() {}),
                      onRemove: _walls.length > 1
                          ? () => _removeWall(wall)
                          : null,
                      // Only a saved wall can have routes to reset.
                      onReset: wall.id == null
                          ? null
                          : () => unawaited(_resetWall(wall)),
                    ),
                  ],
                  const SizedBox(height: SvaSpace.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _addWall,
                      icon: const Icon(LucideIcons.plus),
                      label: Text(l10n.gymFormWallAdd),
                    ),
                  ),
                  if (_ownGym) ...[
                    formGap,
                    TextFormField(
                      controller: _country,
                      decoration: InputDecoration(
                        labelText: l10n.cragFormCountry,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                      validator: (v) =>
                          RegExp(r'^[A-Za-z]{2}$').hasMatch((v ?? '').trim())
                          ? null
                          : l10n.cragFormCountryInvalid,
                    ),
                    formGap,
                    LocationFields(
                      lat: _lat,
                      lon: _lon,
                      mapLabel: l10n.gymFormMap,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SvaSpace.screen),
          child: FilledButton(
            onPressed: _saving || _loading ? null : _save,
            child: Text(l10n.gymFormSave),
          ),
        ),
      ),
    );
  }
}

/// The whole degrees in [text], or `null` when empty or not a number.
int? _degrees(String text) => int.tryParse(text.trim().replaceAll('−', '-'));

/// One wall: name, type, height, angle and degrees, and for a saved wall
/// its last reset.
class _WallCard extends StatelessWidget {
  const new({
    required this.wall,
    required this.onChanged,
    required this.onRemove,
    required this.onReset,
    super.key,
  });

  final _Wall wall;
  final VoidCallback onChanged;

  /// `null` for the last wall: a gym keeps at least one.
  final VoidCallback? onRemove;

  /// `null` for a wall that isn't saved yet.
  final VoidCallback? onReset;

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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: wall.name,
                    decoration: InputDecoration(
                      labelText: l10n.gymFormWallName,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: maxNameLength,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? l10n.gymFormWallNameMissing
                        : null,
                  ),
                ),
                if (onRemove != null)
                  // Follows the name as it is typed, so a screen reader
                  // names the right wall.
                  ListenableBuilder(
                    listenable: wall.name,
                    builder: (context, _) => IconButton(
                      tooltip: l10n.gymFormWallRemove(wall.name.text),
                      onPressed: onRemove,
                      icon: const Icon(LucideIcons.x),
                    ),
                  ),
              ],
            ),
            ChipGroup(
              label: l10n.gymFormWallKind,
              options: [
                for (final kind in wallKinds) (kind, l10n.gymWallKind(kind)),
              ],
              selected: {wall.kind},
              onChanged: (v) {
                if (v.isEmpty) return;
                wall.kind = v.single;
                onChanged();
              },
            ),
            TextFormField(
              controller: wall.height,
              decoration: InputDecoration(labelText: l10n.gymFormWallHeight),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final m = parseDecimal(v!);
                return m == null || m < minWallHeightM || m > maxWallHeightM
                    ? l10n.gymFormWallHeightInvalid
                    : null;
              },
            ),
            ChipGroup(
              label: l10n.gymFormWallAngle,
              options: [
                for (final angle in _angles)
                  (angle, l10n.attributeValue(angle.replaceAll('.', '_'))),
              ],
              selected: {?wall.angle},
              onChanged: (v) {
                wall.angle = v.firstOrNull;
                // Degrees that say otherwise no longer hold.
                if (_degrees(wall.degrees.text) case final d?
                    when isWallAngleDeg(d) &&
                        angleForDegrees(d) != wall.angle) {
                  wall.degrees.clear();
                }
                onChanged();
              },
            ),
            TextFormField(
              controller: wall.degrees,
              decoration: InputDecoration(
                labelText: l10n.gymFormWallDegrees,
                helperText: l10n.gymFormWallDegreesHelp,
                helperMaxLines: 2,
                suffixText: '°',
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              onChanged: (v) {
                if (_degrees(v) case final d? when isWallAngleDeg(d)) {
                  wall.angle = angleForDegrees(d);
                  onChanged();
                }
              },
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final d = _degrees(v!);
                return d == null || !isWallAngleDeg(d)
                    ? l10n.gymFormWallDegreesInvalid
                    : null;
              },
            ),
            if (onReset != null)
              Wrap(
                spacing: SvaSpace.sm,
                runSpacing: SvaSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    switch (wall.lastResetOn) {
                      final day? => l10n.gymFormWallResetOn(
                        formatDay(l10n, day),
                      ),
                      null => l10n.gymFormWallNeverReset,
                    },
                    style: context.svaText.caption.copyWith(
                      color: context.svaColors.textMuted,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: wall.name,
                    builder: (context, _) => Semantics(
                      container: true,
                      label: l10n.gymFormWallResetLabel(wall.name.text),
                      excludeSemantics: true,
                      button: true,
                      child: OutlinedButton(
                        onPressed: onReset,
                        child: Text(l10n.gymFormWallReset),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
