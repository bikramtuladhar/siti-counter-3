/// Core kitchen engine library for Siti Counter 3.0.
library kitchen_engine;

/// Converts South Asian market units to grams.
class UnitConverter {
  static const double pauInGrams = 250.0;
  static const double dharniInGrams = 2500.0;

  /// Converts pau to grams (1 pau = 250g).
  static double pauToGrams(double pau) => pau * pauInGrams;

  /// Converts grams to pau.
  static double gramsToPau(double grams) => grams / pauInGrams;

  /// Converts dharni to grams (1 dharni = 2.5kg = 10 pau).
  static double dharniToGrams(double dharni) => dharni * dharniInGrams;

  /// Converts grams to dharni.
  static double gramsToDharni(double grams) => grams / dharniInGrams;
}

/// Calculates altitude adjustments for boiling point and cooking times.
class AltitudeCalculator {
  /// Estimates water boiling temperature in Celsius for a given elevation in meters.
  /// Standard approximation: temperature drops ~1°C per 285m.
  static double boilingPointCelsius(double elevationMeters) {
    if (elevationMeters <= 0) return 100.0;
    return 100.0 - (elevationMeters / 285.0);
  }

  /// Calculates whistle multiplier at altitude compared to sea level.
  static int adjustSitiCount({
    required int baseSiti,
    required double elevationMeters,
  }) {
    if (elevationMeters < 800) return baseSiti;
    if (elevationMeters < 1800) {
      // Kathmandu band (~1,400m): add 1 siti if base >= 3
      return baseSiti >= 3 ? baseSiti + 1 : baseSiti;
    }
    // High altitude (>1800m)
    return (baseSiti * 1.3).round();
  }
}
