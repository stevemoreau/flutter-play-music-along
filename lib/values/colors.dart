import 'package:flutter/material.dart';
import 'package:pigment/pigment.dart';

class MyColors {
  static Color bluegreen800 = Pigment.fromString("#008a8e");
  static Color warning = Pigment.fromString("#fff3cd");
  static Color warningBorder = Pigment.fromString("#ffeeba");
  static Color warningFont = Pigment.fromString("#856404");

  // Example of a material Color.
  static Map<int, Color> colorPrimary = {
    50: bluegreen800,
    100: bluegreen800,
    200: bluegreen800,
    300: bluegreen800,
    400: bluegreen800,
    500: bluegreen800,
    600: bluegreen800,
    700: bluegreen800,
    800: bluegreen800,
    900: bluegreen800,
  };
  static MaterialColor primaryColor = MaterialColor(0xFF880E4F, colorPrimary);
}
