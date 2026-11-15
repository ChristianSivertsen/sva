import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sva_ui/src/theme/sva_colors.dart';
import 'package:sva_ui/src/theme/sva_theme.dart';
import 'package:sva_ui/src/theme/sva_tokens.dart';

/// The shade of a graded gym's grade: [band] 0 to 3 (beginner,
/// intermediate, advanced, elite) in sea, sun, granite and night (foam in
/// Midnight sun), from pale at [depth] 0 to deep at 1
/// (prototype/gym-log.html, `ramp`). Like gym colours, these are
/// illustration colours, not theme tokens.
Color gymGradeShade(Brightness brightness, int band, double depth) {
  const night = SvaColors.midnight;
  const day = SvaColors.daylight;
  final dark = brightness == Brightness.dark;
  final hue = dark
      ? [night.sea, night.sun, night.granite, night.text][band]
      : [day.sea, _amber, day.granite, day.text][band];
  return dark
      ? Color.lerp(_dusk, hue, .45 + .55 * depth)!
      : Color.lerp(day.surfaceSunk, hue, .22 + .7 * depth)!;
}

/// Sun for intermediate in Daylight, where the `sun` token is granite.
const _amber = Color(0xFFC98A12);

/// What a pale shade starts from in Midnight sun.
const _dusk = Color(0xFF2A3360);

/// An indoor session's picture (docs/DESIGN.md, Gym walls): a plywood wall
/// with one cluster of holds per climb, in the climb's colour, and a label
/// such as `Gnisten · 5 climbs` in the corner. A climb without a colour
/// gets plain holds. [seed], such as the session's id, keeps the holds in
/// the same places every time it is drawn.
class SvaGymWall extends StatelessWidget {
  const new({
    required this.holds,
    required this.label,
    required this.semanticLabel,
    required this.seed,
    super.key,
  });

  /// One colour per climb, in order; `null` for plain holds.
  final List<Color?> holds;
  final String label;
  final String semanticLabel;
  final String seed;

  @override
  Widget build(BuildContext context) {
    const night = SvaColors.midnight;
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(SvaRadius.large),
        child: AspectRatio(
          aspectRatio: _width / _height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _WallPainter(holds, seed)),
              ),
              PositionedDirectional(
                start: SvaSpace.xs,
                top: SvaSpace.xs,
                end: SvaSpace.xs,
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: night.background.withValues(alpha: .82),
                      borderRadius: const BorderRadius.all(SvaRadius.badge),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SvaSpace.xs,
                        vertical: SvaSpace.xxs,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.svaText.caption.copyWith(
                          color: night.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _width = 300.0;
const _height = 220.0;

/// Plywood panels, the bolt-hole grid, the mat and plain holds.
const _panel = Color(0xFFD6CEC0);
const _panelLeft = Color(0xFFCBC2B2);
const _panelMiddle = Color(0xFFDDD5C8);
const _panelRight = Color(0xFFBFB6A5);
const _boltHole = Color(0xFF8A8172);
const _mat = Color(0xFF3A3F45);
const _plainHold = Color(0xFF6B6F75);
const _holdEdge = Color(0x59000000);

class _WallPainter extends CustomPainter {
  new(this.holds, this.seed);

  final List<Color?> holds;
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _width, size.height / _height);
    void polygon(List<Offset> points, Color colour) => canvas.drawPath(
      Path()..addPolygon(points, true),
      Paint()..color = colour,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _width, _height),
      Paint()..color = _panel,
    );
    polygon(const [
      Offset.zero,
      Offset(110, 0),
      Offset(95, 220),
      Offset(0, 220),
    ], _panelLeft);
    polygon(const [
      Offset(200, 0),
      Offset(300, 0),
      Offset(300, 220),
      Offset(215, 220),
    ], _panelRight);
    polygon(const [
      Offset(95, 0),
      Offset(200, 0),
      Offset(215, 220),
      Offset(95, 220),
    ], _panelMiddle);
    final hole = Paint()..color = _boltHole;
    for (var x = 8.0; x < _width; x += 16) {
      for (var y = 8.0; y < _height; y += 16) {
        canvas.drawCircle(Offset(x, y), .9, hole);
      }
    }

    // Each climb's holds go up the wall from its own spot along the mat.
    final random = _Mulberry32(_hash(seed));
    final edge = Paint()
      ..color = _holdEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    for (final (i, colour) in holds.indexed) {
      final fill = Paint()..color = colour ?? _plainHold;
      var x = 20 + (i + .5) * (260 / holds.length) + (random.next() - .5) * 10;
      var y = 200.0;
      for (var k = 0; k < 6; k++) {
        y -= 24 + random.next() * 10;
        x += (random.next() - .5) * 22;
        final rx = 5 + random.next() * 6;
        final ry = 4 + random.next() * 4;
        final turn = random.next() * math.pi;
        final hold = Rect.fromCenter(
          center: Offset.zero,
          width: rx * 2,
          height: ry * 2,
        );
        canvas
          ..save()
          ..translate(x, y)
          ..rotate(turn)
          ..drawOval(hold, fill)
          ..drawOval(hold, edge)
          ..restore();
      }
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, 204, _width, 16),
      Paint()..color = _mat,
    );
  }

  @override
  bool shouldRepaint(_WallPainter old) =>
      old.seed != seed || !_sameColours(old.holds, holds);

  static bool _sameColours(List<Color?> a, List<Color?> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
}

/// FNV-1a over [text]'s code units: the same number on every run and
/// platform, unlike `String.hashCode`.
int _hash(String text) {
  var h = 0x811C9DC5;
  for (final unit in text.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// A small seeded random number generator (Mulberry32), as in the
/// prototype, so a session's wall looks the same everywhere.
class _Mulberry32 {
  new(this._state);

  int _state;

  /// The next number from 0 up to 1.
  double next() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= t + _imul(t ^ (t >>> 7), t | 61);
    t &= 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  /// 32-bit multiplication, as JavaScript's `Math.imul`.
  static int _imul(int a, int b) {
    final low = (a & 0xFFFF) * b;
    final high = ((a >>> 16) * b) & 0xFFFF;
    return (low + (high << 16)) & 0xFFFFFFFF;
  }
}
