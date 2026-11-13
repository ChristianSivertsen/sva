import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sva_data/sva_data.dart' show LatLon;

/// A position this recent is good enough for finding the gym you are at.
const _recent = Duration(minutes: 10);

/// How long to wait for a new position before giving up.
const _wait = Duration(seconds: 5);

/// Roughly where the phone is, for opening the gym log on the gym you are
/// at. Asks for permission the first time the gym log opens. `null` when
/// location is off, refused, unavailable or slow; the log then opens on the
/// gym you logged at last. Kept in memory only: never stored, logged or
/// sent anywhere.
final FutureProvider<LatLon?> hereProvider = FutureProvider.autoDispose((
  ref,
) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    // On Android, the system's own location service rather than Google
    // Play's, so no other service is involved.
    final android = defaultTargetPlatform == TargetPlatform.android;
    final last = await Geolocator.getLastKnownPosition(
      forceAndroidLocationManager: android,
    );
    if (last != null && DateTime.now().difference(last.timestamp) < _recent) {
      return (lat: last.latitude, lon: last.longitude);
    }
    final now = await Geolocator.getCurrentPosition(
      locationSettings: android
          ? AndroidSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: _wait,
              forceLocationManager: true,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: _wait,
            ),
    );
    return (lat: now.latitude, lon: now.longitude);
  } on Exception {
    // No plugin (tests), a timeout, or the platform said no: the log works
    // without a position.
    return null;
  }
});
