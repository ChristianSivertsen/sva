/// The steepest slab a wall can have, in degrees past vertical.
const minWallAngleDeg = -45;

/// A flat roof, in degrees past vertical.
const maxWallAngleDeg = 90;

/// Whether [deg] is a wall angle Sva accepts: whole degrees past vertical,
/// negative for slabs.
bool isWallAngleDeg(int deg) =>
    deg >= minWallAngleDeg && deg <= maxWallAngleDeg;

/// The angle type (an `angle.*` value key) for a wall [deg] degrees past
/// vertical: slab below 0°, vertical 0–5°, overhang 6–60°, roof above 60°.
String angleForDegrees(int deg) {
  if (!isWallAngleDeg(deg)) throw ArgumentError.value(deg, 'deg');
  return switch (deg) {
    < 0 => 'angle.slab',
    <= 5 => 'angle.vertical',
    <= 60 => 'angle.overhang',
    _ => 'angle.roof',
  };
}
