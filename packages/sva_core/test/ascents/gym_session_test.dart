import 'package:sva_core/sva_core.dart';
import 'package:test/test.dart';

void main() {
  const caveBlue = (
    wallId: 'cave',
    kind: 'boulder',
    colourId: 'blue',
    gradeId: null,
  );
  const boardBlue = (
    wallId: 'board',
    kind: 'boulder',
    colourId: 'blue',
    gradeId: null,
  );
  const caveGreen = (
    wallId: 'cave',
    kind: 'boulder',
    colourId: 'green',
    gradeId: null,
  );
  const mainBlue = (
    wallId: 'main',
    kind: 'rope',
    colourId: 'blue',
    gradeId: null,
  );
  List<(int, AscentStyle, int)> climbs(GymSessionLog log) => [
    for (final (i, c) in log.climbs.indexed)
      (log.entries[i].route, c.style, c.tries),
  ];

  test('M3-4: a fall then a top on the same colour is one climb', () {
    var log = const GymSessionLog().tap(caveBlue);
    log = log.update(0, topped: false, tries: 2).tap(caveBlue);
    expect(log.routes, [caveBlue]);
    expect(climbs(log), [
      (0, AscentStyle.attempt, 2),
      (0, AscentStyle.redpoint, 3),
    ]);

    // Once topped, the same colour again is a new climb, and so is the same
    // colour on another wall, another colour, or the other kind.
    log = log
        .tap(caveBlue)
        .tap(boardBlue)
        .tap(caveGreen)
        .tap(mainBlue, ropeType: 'lead');
    expect(log.routes, [caveBlue, caveBlue, boardBlue, caveGreen, mainBlue]);
    expect(
      log.climbs.skip(2).map((c) => c.style),
      everyElement(AscentStyle.flash),
    );
    expect(log.entries.last.ropeType, 'lead');
  });

  test('M3-4: removing a climb drops its route and renumbers the rest', () {
    var log = const GymSessionLog()
        .tap(caveBlue)
        .tap(caveGreen)
        .tap(mainBlue, ropeType: 'toprope');
    log = log.remove(0);
    expect(log.routes, [caveGreen, mainBlue]);
    expect([for (final e in log.entries) e.route], [0, 1]);

    // A route with climbs left stays.
    log = log.update(0, topped: false).tap(caveGreen).remove(0);
    expect(log.routes, [caveGreen, mainBlue]);
    expect(climbs(log), [(1, AscentStyle.flash, 1), (0, AscentStyle.flash, 1)]);
  });

  test('M3-4: a gym log refuses taps it cannot save', () {
    expect(() => const GymSessionLog().tap(mainBlue), throwsArgumentError);
    expect(
      () => const GymSessionLog().tap(caveBlue, ropeType: 'lead'),
      throwsArgumentError,
    );
    final log = const GymSessionLog().tap(caveBlue);
    expect(() => log.update(0, tries: 0), throwsArgumentError);
    expect(() => log.update(0, tries: maxTriesPerTap + 1), throwsArgumentError);
    expect(() => log.update(0, ropeType: 'lead'), throwsArgumentError);
  });
}
