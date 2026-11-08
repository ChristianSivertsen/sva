/// An IANA time zone for the device's current offset. Dart has no IANA
/// name for the device zone without a native plugin, so whole-hour offsets
/// become `Etc/GMT±n` (whose sign is inverted by convention) and others
/// fall back to `Etc/UTC`. Enough to place a day; DST rules are not needed.
String deviceTimeZone(Duration offset) {
  if (offset.inMinutes % 60 != 0) return 'Etc/UTC';
  final hours = offset.inHours;
  if (hours == 0) return 'Etc/UTC';
  return 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
}
