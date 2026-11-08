import 'package:sva_core/sva_core.dart';
import 'package:test/test.dart';

void main() {
  test('M3-3: a gym route is an open project until it is sent, reset or '
      'gone', () {
    RouteHistory history(List<LoggedAscent> log) =>
        RouteHistory.from(log, gym: true);
    const attempt = (style: AscentStyle.attempt, tries: 3);
    const send = (style: AscentStyle.redpoint, tries: 4);

    expect(isOpenProject(history([attempt]), retired: false), isTrue);
    // Not tried yet: nothing to come back to.
    expect(isOpenProject(history([]), retired: false), isFalse);
    // Sent: done, even if tried again since.
    expect(isOpenProject(history([attempt, send]), retired: false), isFalse);
    expect(
      isOpenProject(
        history([attempt, send, (style: AscentStyle.attempt, tries: 1)]),
        retired: false,
      ),
      isFalse,
    );
    // Its wall was reset, or it was marked as gone.
    expect(isOpenProject(history([attempt]), retired: true), isFalse);
  });
}
