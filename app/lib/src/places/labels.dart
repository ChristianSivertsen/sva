import 'package:intl/intl.dart';
import 'package:sva/l10n/app_localizations.dart';
import 'package:sva_core/sva_core.dart' show AttributeValues;
import 'package:sva_data/sva_data.dart' show GymRouteLabel, WeatherSnapshot;

/// Route details shown as tags, in this order. Discipline is shown on its
/// own line, so it is not here.
const _tagKeys = [
  'rock_type',
  'aspect',
  'angle',
  'feature',
  'hold',
  'protection',
  'descent',
  'rope_length_m',
];

/// The display text for each detail in [values] that the app has words
/// for. Unknown keys are left out rather than shown raw.
List<String> detailTags(AppLocalizations l10n, AttributeValues values) => [
  for (final key in _tagKeys)
    for (final value in values[key] ?? const <String>[])
      if (_label(l10n, key, value) case final label? when label.isNotEmpty)
        label,
];

String? _label(AppLocalizations l10n, String key, String value) =>
    switch (key) {
      'aspect' => l10n.aspect(value),
      'rope_length_m' => switch (num.tryParse(value)) {
        final metres? => l10n.routeRopeLength(metres.round()),
        null => null,
      },
      _ => l10n.attributeValue(value.replaceAll('.', '_')),
    };

/// A `YYYY-MM-DD` day as `1 Nov 2026` in the app's language
/// (docs/DESIGN.md, Writing).
String formatDay(AppLocalizations l10n, String day) =>
    DateFormat('d MMM y', l10n.localeName).format(DateTime.parse(day));

/// A day's weather in one line, such as `10 °C · 0,4 mm regn · 3 m/s
/// vind`, with numbers in the app's language. Empty when nothing is known.
String weatherLine(AppLocalizations l10n, WeatherSnapshot weather) {
  final number = NumberFormat.decimalPattern(l10n.localeName)
    ..maximumFractionDigits = 1;
  return [
    if (weather.tempC case final t?) l10n.weatherTemp(number.format(t.round())),
    // Less than a tenth of a millimetre would read as 0 mm.
    if (weather.precipMm case final mm? when mm >= 0.05)
      l10n.weatherRain(number.format(mm)),
    if (weather.windMs case final ms?)
      l10n.weatherWind(number.format(ms.round())),
  ].join(' · ');
}

/// How a gym climb is named, since gym routes have none: its colour with
/// its wall as the place, or in a graded or ungraded gym its wall (the
/// grade shows as a badge).
({String name, String? place}) gymClimbText(GymRouteLabel label) =>
    switch (label.colour) {
      final colour? => (name: colour, place: label.wall),
      null => (name: label.wall ?? '', place: null),
    };
