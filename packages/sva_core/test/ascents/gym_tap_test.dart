import 'package:sva_core/sva_core.dart';
import 'package:test/test.dart';

void main() {
  test('M3-4: a tap in the gym log gets its style from the route history', () {
    RouteHistory history(List<LoggedAscent> log) =>
        RouteHistory.from(log, boulder: true, gym: true);
    LoggedAscent tap(
      List<LoggedAscent> log, {
      bool topped = true,
      int tries = 1,
    }) => gymTap(history(log), topped: topped, tries: tries);
    const fell = (style: AscentStyle.attempt, tries: 3);

    expect(tap([]), (style: AscentStyle.flash, tries: 1));
    // Topped after falling earlier tonight: tries count the falls.
    expect(tap([], tries: 2), (style: AscentStyle.redpoint, tries: 2));
    expect(tap([fell]), (style: AscentStyle.redpoint, tries: 4));
    expect(tap([fell, (style: AscentStyle.redpoint, tries: 4)]), (
      style: AscentStyle.repeat,
      tries: 1,
    ));
    expect(tap([fell], topped: false, tries: 2), (
      style: AscentStyle.attempt,
      tries: 2,
    ));

    // Whatever the tap gives, the rules accept it.
    for (final log in [
      <LoggedAscent>[],
      [fell],
    ]) {
      for (final topped in [true, false]) {
        expect(history(log).check(tap(log, topped: topped)), isEmpty);
      }
    }
  });
}
