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

  // A blue in the cave, tried three times last week.
  const project = (id: 'r1', key: caveBlue, tries: 3, lastTried: '2026-11-05');

  test('M3-7: sending a project from last week logs as a redpoint counting '
      'its earlier tries', () {
    var log = const GymSessionLog(past: [project]);
    expect(log.projects('boulder'), [(route: project, tries: 3)]);
    expect(log.projects('rope'), isEmpty);

    // Two more falls tonight still count, then the send.
    log = log.sendProject('r1').update(0, topped: false, tries: 2);
    expect(log.projects('boulder'), [(route: project, tries: 5)]);
    log = log.sendProject('r1');
    expect(log.routeIds, ['r1']);
    expect(climbs(log), [
      (0, AscentStyle.attempt, 2),
      (0, AscentStyle.redpoint, 6),
    ]);
    expect(log.projects('boulder'), isEmpty, reason: 'sent');
    expect(() => log.sendProject('r1'), throwsArgumentError);
    expect(() => log.sendProject('nope'), throwsArgumentError);
  });

  test('M3-7: a tap offers the climbs it could be, and can move there', () {
    // A new blue in the cave could be last week's project.
    var log = const GymSessionLog(past: [project]).tap(caveBlue);
    expect(log.isFresh(0), isTrue);
    const asProject = (kind: GymMatchKind.project, route: null, pastId: 'r1');
    expect(log.matches(0), [asProject]);
    log = log.moveTo(0, asProject);
    expect(log.routeIds, ['r1']);
    expect(log.climbs.single, (style: AscentStyle.redpoint, tries: 4));

    // It was a different blue after all.
    expect(log.isFresh(0), isFalse);
    log = log.moveToNew(0);
    expect(log.routes, [caveBlue]);
    expect(log.routeIds, [null]);
    expect(log.climbs.single.style, AscentStyle.flash);

    // A fall on one blue tonight, then a blue that was a new one: it could
    // be the one tried. After a send, the same blue again is offered too.
    log = const GymSessionLog()
        .tap(caveBlue)
        .update(0, topped: false)
        .tap(caveBlue)
        .moveToNew(1);
    const tried = (kind: GymMatchKind.triedToday, route: 0, pastId: null);
    expect(log.matches(1), [tried]);
    log = log.update(0, topped: true).tap(caveBlue).moveToNew(2);
    // Both earlier blues are sends now, the latest first.
    expect(log.matches(2), [
      (kind: GymMatchKind.sentToday, route: 1, pastId: null),
      (kind: GymMatchKind.sentToday, route: 0, pastId: null),
    ]);
    log = log.update(2, topped: false);
    expect(log.matches(2), isEmpty, reason: 'a fall is no repeat');
    expect(() => log.moveTo(1, tried), throwsArgumentError);
    // Only the same colour on the same wall can be the same climb.
    expect(
      const GymSessionLog(past: [project]).tap(boardBlue).matches(0),
      isEmpty,
    );
  });

  test('M3-7: moving a climb drops the route it leaves and keeps the rest '
      'in line', () {
    // Sent a blue, then fell on a blue: the send was on that one after all.
    var log = const GymSessionLog()
        .tap(caveBlue)
        .tap(caveBlue)
        .update(1, topped: false);
    expect(log.routes, [caveBlue, caveBlue]);
    const tried = (kind: GymMatchKind.triedToday, route: 1, pastId: null);
    expect(log.matches(0), [tried]);
    log = log.moveTo(0, tried);
    expect(log.routes, [caveBlue]);
    expect([for (final e in log.entries) e.route], [0, 0]);

    // A project after a dropped route keeps its id.
    log = const GymSessionLog(past: [project])
        .tap(caveGreen)
        .sendProject('r1')
        .remove(0);
    expect(log.routes, [caveBlue]);
    expect(log.routeIds, ['r1']);
    expect(log.entries.single.route, 0);
    expect(log.climbs.single, (style: AscentStyle.redpoint, tries: 4));
  });

  test('M3-7: a project marked as gone leaves the log', () {
    final log = const GymSessionLog(past: [project]).withoutProject('r1');
    expect(log.projects('boulder'), isEmpty);
    expect(log.tap(caveBlue).matches(0), isEmpty);
    // One already climbed tonight stays, or the session could not be saved.
    expect(
      () =>
          const GymSessionLog(past: [project])
              .sendProject('r1')
              .withoutProject('r1'),
      throwsArgumentError,
    );
  });
}
