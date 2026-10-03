import 'package:flutter/material.dart';

/// Devanagari typography optimization for low-end Android devices and high-glare kitchens.
/// Configures generous line-heights (1.4 - 1.55) to prevent vertical clipping of
/// upper matras (े, ै, ं, ँ) and subscript virama/conjunct ligatures (ु, ू, ृ, ्).
class NepaliTypography {
  static const String fontPrimary = 'NotoSansDevanagari';
  static const List<String> fontFallbacks = [
    'Mukta',
    'Roboto',
    'sans-serif',
  ];

  /// Standard Devanagari line-height multiplier to prevent glyph clipping.
  static const double standardLineHeight = 1.45;
  static const double headlineLineHeight = 1.35;
  static const double bodyLineHeight = 1.50;

  static TextStyle get displayLarge => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: headlineLineHeight,
        letterSpacing: 0.1,
      );

  static TextStyle get headlineMedium => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: headlineLineHeight,
        letterSpacing: 0.1,
      );

  static TextStyle get headlineSmall => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: headlineLineHeight,
        letterSpacing: 0.1,
      );

  static TextStyle get titleLarge => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: standardLineHeight,
      );

  static TextStyle get titleMedium => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: standardLineHeight,
      );

  static TextStyle get titleSmall => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: standardLineHeight,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: bodyLineHeight,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: bodyLineHeight,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: bodyLineHeight,
      );

  static TextStyle get labelLarge => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: standardLineHeight,
      );

  static TextStyle get labelMedium => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: standardLineHeight,
      );

  static TextStyle get labelSmall => const TextStyle(
        fontFamily: fontPrimary,
        fontFamilyFallback: fontFallbacks,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: standardLineHeight,
      );

  static TextTheme createTextTheme(Color textColor) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: textColor),
      headlineMedium: headlineMedium.copyWith(color: textColor),
      headlineSmall: headlineSmall.copyWith(color: textColor),
      titleLarge: titleLarge.copyWith(color: textColor),
      titleMedium: titleMedium.copyWith(color: textColor),
      titleSmall: titleSmall.copyWith(color: textColor),
      bodyLarge: bodyLarge.copyWith(color: textColor),
      bodyMedium: bodyMedium.copyWith(color: textColor),
      bodySmall: bodySmall.copyWith(color: textColor),
      labelLarge: labelLarge.copyWith(color: textColor),
      labelMedium: labelMedium.copyWith(color: textColor),
      labelSmall: labelSmall.copyWith(color: textColor),
    );
  }
}
