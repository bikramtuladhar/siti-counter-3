/// Siti Counter 3.0 — Generated Design Tokens (Dart / Flutter)
/// Generated from W3C Design Tokens JSON. Do not edit manually.
library;

import 'package:flutter/material.dart';

class SitiColors {
  // Brand & Accents
  static const Color terracotta = Color(0xFFD95328);
  static const Color terracottaDark = Color(0xFFB9421E);
  static const Color freshGreen = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color alert = Color(0xFFD32F2F);

  // Backgrounds
  static const Color warmWhite = Color(0xFFFAF9F6);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color dark = Color(0xFF1A1A1A);
  static const Color cardDark = Color(0xFF242424);
}

class SitiSpacing {
  static const double touchTargetMin = 48.0;
  static const double displayTouchTargetMin = 64.0;

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class SitiRadius {
  static const double none = 0.0;
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 9999.0;

  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(xl));
}

class SitiTypography {
  // Siti Counter font sizes for distance viewing
  static const double counterNear = 56.0;       // Phone handheld (<1m)
  static const double counterArmsLength = 80.0; // Kitchen counter (1-2m)
  static const double counterAcrossRoom = 120.0;// Smart display across room (>2m)

  static const TextStyle counterNearStyle = TextStyle(
    fontSize: counterNear,
    fontWeight: FontWeight.w800,
    color: SitiColors.terracotta,
  );

  static const TextStyle counterArmsLengthStyle = TextStyle(
    fontSize: counterArmsLength,
    fontWeight: FontWeight.w900,
    color: SitiColors.terracotta,
  );
}
