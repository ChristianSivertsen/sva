import 'package:sva_core/src/ascents/ascent_rules.dart';
import 'package:sva_core/src/ascents/gym_session.dart';

/// One colour (or grade) of one kind in a gym session, and how its climbs
/// went (prototype/gym-log.html, the finish sheet's bars).
typedef GymGradeCount = ({
  String kind,
  String? colourId,
  String? gradeId,
  int flash,
  int redpoint,
  int repeat,
  int attempt,
});

/// A project from an earlier session sent in this one: entry `index`, on
/// the `tries` try in all, last tried on `lastTried` (`YYYY-MM-DD`).
typedef GymProjectSend = ({int index, int tries, String lastTried});

/// What the finish sheet shows about a gym session.
typedef GymSessionSummary = ({
  int climbs,
  int sends,
  int flashes,
  int boulders,
  int ropes,

  /// Metres climbed on a rope: a wall's height for a top, and for each try
  /// that wasn't. `null` without rope climbs, or when a wall's height is
  /// unknown, so a partial sum never passes for the total.
  double? metres,

  /// The hardest send of each kind (`boulder`, `rope`), when one is known.
  Map<String, GymRouteKey> best,

  /// Each colour or grade climbed, easiest first within a kind, boulders
  /// first.
  List<GymGradeCount> grades,
  List<GymProjectSend> projectSends,
});

extension GymSessionSummaryOf on GymSessionLog {
  /// This session's summary. [heightM] is a wall's height; [rank] orders a
  /// colour or grade of a kind from easy to hard, `null` when unknown. It
  /// looks only at a key's `kind`, `colourId` and `gradeId`.
  GymSessionSummary summary({
    required double? Function(String wallId) heightM,
    required int? Function(GymRouteKey key) rank,
  }) {
    final climbs = this.climbs;
    var sends = 0;
    var flashes = 0;
    var boulders = 0;
    var ropes = 0;
    var metres = 0.0;
    var heightUnknown = false;
    final best = <String, GymRouteKey>{};
    final counts = <(String, String?, String?), List<int>>{};
    final projectSends = <GymProjectSend>[];
    for (final (i, e) in entries.indexed) {
      final key = routes[e.route];
      final style = climbs[i].style;
      if (style != AscentStyle.attempt) sends++;
      if (style == AscentStyle.flash) flashes++;
      if (key.kind == 'boulder') {
        boulders++;
      } else {
        ropes++;
        switch (heightM(key.wallId)) {
          case final h?:
            metres += h * (e.topped ? 1 : e.tries);
          case null:
            heightUnknown = true;
        }
      }
      if (style != AscentStyle.attempt) {
        final r = rank(key);
        final top = best[key.kind];
        if (r != null && (top == null || r > rank(top)!)) best[key.kind] = key;
      }
      final c = counts.putIfAbsent((
        key.kind,
        key.colourId,
        key.gradeId,
      ), () => [0, 0, 0, 0]);
      c[switch (style) {
        AscentStyle.flash || AscentStyle.onsight => 0,
        AscentStyle.redpoint => 1,
        AscentStyle.repeat => 2,
        AscentStyle.attempt => 3,
      }]++;
      if (routeIds[e.route] case final id? when style == AscentStyle.redpoint) {
        projectSends.add((
          index: i,
          tries: climbs[i].tries,
          lastTried: past.firstWhere((p) => p.id == id).lastTried,
        ));
      }
    }
    int order(String kind, String? colourId, String? gradeId) =>
        rank((
          wallId: '',
          kind: kind,
          colourId: colourId,
          gradeId: gradeId,
          angle: null,
        )) ??
        1 << 30;
    final grades = counts.entries.toList()
      ..sort((a, b) {
        final (ak, ac, ag) = a.key;
        final (bk, bc, bg) = b.key;
        if (ak != bk) return ak == 'boulder' ? -1 : 1;
        return order(ak, ac, ag).compareTo(order(bk, bc, bg));
      });
    return (
      climbs: entries.length,
      sends: sends,
      flashes: flashes,
      boulders: boulders,
      ropes: ropes,
      metres: ropes == 0 || heightUnknown ? null : metres,
      best: best,
      grades: [
        for (final MapEntry(key: (kind, colourId, gradeId), value: c) in grades)
          (
            kind: kind,
            colourId: colourId,
            gradeId: gradeId,
            flash: c[0],
            redpoint: c[1],
            repeat: c[2],
            attempt: c[3],
          ),
      ],
      projectSends: projectSends,
    );
  }
}
