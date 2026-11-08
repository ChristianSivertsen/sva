import 'package:flutter/painting.dart';

/// A gym's hold colour from its stored `#RRGGBB`. Gym colours are data the
/// user picks, not theme tokens, so they are only ever made here.
Color gymColourFromHex(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

/// [colour] as `#RRGGBB`, the way gym colours are stored.
String gymColourToHex(Color colour) {
  final rgb = colour.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
