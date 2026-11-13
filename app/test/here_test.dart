import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sva/src/logging/here.dart';

/// A phone's location service, as the test sets it up.
class _FakeLocation extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  new({
    this.on = true,
    this.permission = LocationPermission.whileInUse,
    this.answer = LocationPermission.whileInUse,
    this.last,
    this.current,
  });

  final bool on;
  LocationPermission permission;

  /// What the user picks when asked.
  final LocationPermission answer;
  final Position? last;

  /// The new position, or `null` to time out.
  final Position? current;
  int asked = 0;
  int fetched = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => on;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    asked++;
    return permission = answer;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => last;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    fetched++;
    return current ?? (throw TimeoutException('no fix'));
  }
}

Position _at(double lat, double lon, DateTime when) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: when,
  accuracy: 500,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  Future<Object?> here(_FakeLocation fake) async {
    GeolocatorPlatform.instance = fake;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(hereProvider, (_, _) {});
    addTearDown(sub.close);
    return await container.read(hereProvider.future);
  }

  final now = DateTime.now();

  test(
    'M3-4: the phone position comes from a recent fix, or a new one',
    () async {
      // A fix from a minute ago is good enough, so no new one is asked for.
      final recent = _FakeLocation(
        last: _at(59.93, 10.77, now.subtract(const Duration(minutes: 1))),
      );
      expect(await here(recent), (lat: 59.93, lon: 10.77));
      expect(recent.fetched, 0);

      // An old fix is not: a new one is asked for.
      final old = _FakeLocation(
        last: _at(63.43, 10.39, now.subtract(const Duration(hours: 2))),
        current: _at(59.93, 10.77, now),
      );
      expect(await here(old), (lat: 59.93, lon: 10.77));
      expect(old.fetched, 1);

      // Asked the first time, and allowed.
      final fresh = _FakeLocation(
        permission: LocationPermission.denied,
        current: _at(59.93, 10.77, now),
      );
      expect(await here(fresh), isNotNull);
      expect(fresh.asked, 1);
    },
  );

  test('M3-4: without location the phone position is unknown', () async {
    expect(
      await here(_FakeLocation(on: false, current: _at(1, 1, now))),
      isNull,
    );
    final refused = _FakeLocation(
      permission: LocationPermission.denied,
      answer: LocationPermission.denied,
      current: _at(1, 1, now),
    );
    expect(await here(refused), isNull);
    // Refused for good: not asked again.
    final never = _FakeLocation(
      permission: LocationPermission.deniedForever,
      current: _at(1, 1, now),
    );
    expect(await here(never), isNull);
    expect(never.asked, 0);
    // No fix in time.
    expect(await here(_FakeLocation()), isNull);
  });
}
