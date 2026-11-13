import 'dart:math';

/// The great-circle distance in kilometres between two points in decimal
/// degrees.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthKm = 6371.0;
  double rad(double deg) => deg * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * earthKm * asin(sqrt(h));
}

/// How far a gym can be and still count as where you are: a phone's
/// approximate location is often a kilometre or two off.
const nearbyGymKm = 3.0;

/// The id of the place nearest to ([lat], [lon]) within [maxKm], or `null`
/// when none is that close. [places] are (id, lat, lon); places without a
/// location are skipped.
String? nearestWithin(
  double lat,
  double lon,
  Iterable<(String, double?, double?)> places, {
  double maxKm = nearbyGymKm,
}) {
  String? best;
  var bestKm = maxKm;
  for (final (id, pLat, pLon) in places) {
    if (pLat == null || pLon == null) continue;
    final km = distanceKm(lat, lon, pLat, pLon);
    if (km <= bestKm) {
      best = id;
      bestKm = km;
    }
  }
  return best;
}
