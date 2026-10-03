/// Core kitchen engine library for Siti Counter 3.0.
/// Implements pure domain calculations for market units, altitude, and purchasable quantities.
library kitchen_engine;

/// Canonical mass and volume conversion constants and helpers.
class UnitConverter {
  // Mass in grams
  static const double pauInGrams = 250.0;
  static const double dharniInGrams = 2500.0;
  static const double tolaInGrams = 11.6638;
  static const double seerInGrams = 933.1;
  static const double muthiInGrams = 50.0; // One typical handful of rice/grains

  // Volume in milliliters
  static const double manaInMl = 568.0; // 1 mana ≈ 568 ml
  static const double metricCupInMl = 250.0;
  static const double usCupInMl = 240.0;
  static const double tablespoonInMl = 15.0;
  static const double teaspoonInMl = 5.0;

  // --- Mass Conversions ---
  static double pauToGrams(double pau) => pau * pauInGrams;
  static double gramsToPau(double grams) => grams / pauInGrams;

  static double dharniToGrams(double dharni) => dharni * dharniInGrams;
  static double gramsToDharni(double grams) => grams / dharniInGrams;

  static double tolaToGrams(double tola) => tola * tolaInGrams;
  static double gramsToTola(double grams) => grams / tolaInGrams;

  static double seerToGrams(double seer) => seer * seerInGrams;
  static double gramsToSeer(double grams) => grams / seerInGrams;

  static double muthiToGrams(double muthi) => muthi * muthiInGrams;
  static double gramsToMuthi(double grams) => grams / muthiInGrams;

  // --- Volume Conversions ---
  static double manaToMl(double mana) => mana * manaInMl;
  static double mlToMana(double ml) => ml / manaInMl;

  static double metricCupToMl(double cups) => cups * metricCupInMl;
  static double mlToMetricCup(double ml) => ml / metricCupInMl;

  static double usCupToMl(double cups) => cups * usCupInMl;
  static double mlToUsCup(double ml) => ml / usCupInMl;

  static double tablespoonToMl(double tbsp) => tbsp * tablespoonInMl;
  static double mlToTablespoon(double ml) => ml / tablespoonInMl;

  static double teaspoonToMl(double tsp) => tsp * teaspoonInMl;
  static double mlToTeaspoon(double ml) => ml / teaspoonInMl;

  /// Formats quantity in local South Asian or metric units.
  static String formatLocalUnit({
    required double grams,
    bool preferNepali = false,
  }) {
    if (grams >= dharniInGrams) {
      final dharni = grams / dharniInGrams;
      return preferNepali
          ? '${dharni.toStringAsFixed(dharni % 1 == 0 ? 0 : 1)} धार्नी'
          : '${dharni.toStringAsFixed(dharni % 1 == 0 ? 0 : 1)} dharni';
    } else if (grams >= pauInGrams && grams % pauInGrams == 0) {
      final pau = (grams / pauInGrams).round();
      return preferNepali ? '$pau पाउ' : '$pau pau';
    } else if (grams >= 1000) {
      final kg = grams / 1000.0;
      return preferNepali
          ? '${kg.toStringAsFixed(kg % 1 == 0 ? 0 : 1)} के.जी.'
          : '${kg.toStringAsFixed(kg % 1 == 0 ? 0 : 1)} kg';
    } else {
      return preferNepali ? '${grams.round()} ग्राम' : '${grams.round()} g';
    }
  }
}

/// Result of converting recipe needs into a purchasable store package.
class PurchaseRecommendation {
  final String ingredientName;
  final double recipeQuantityGrams;
  final double packageSizeGrams;
  final int packagesToBuy;
  final double totalPurchasedGrams;
  final double surplusGrams;
  final String? surplusSuggestion;

  const PurchaseRecommendation({
    required this.ingredientName,
    required this.recipeQuantityGrams,
    required this.packageSizeGrams,
    required this.packagesToBuy,
    required this.totalPurchasedGrams,
    required this.surplusGrams,
    this.surplusSuggestion,
  });
}

/// Calculates purchasable store quantities and tracks ingredient surplus.
class MarketCalculator {
  /// Converts required recipe weight into standard purchasable market package amounts.
  static PurchaseRecommendation calculatePurchase({
    required String ingredientName,
    required double recipeQuantityGrams,
    required double standardPackageGrams,
    double alreadyHaveGrams = 0.0,
  }) {
    final netNeeded = (recipeQuantityGrams - alreadyHaveGrams).clamp(0.0, double.infinity);

    if (netNeeded == 0.0) {
      return PurchaseRecommendation(
        ingredientName: ingredientName,
        recipeQuantityGrams: recipeQuantityGrams,
        packageSizeGrams: standardPackageGrams,
        packagesToBuy: 0,
        totalPurchasedGrams: 0.0,
        surplusGrams: alreadyHaveGrams - recipeQuantityGrams,
        surplusSuggestion: null,
      );
    }

    final packagesToBuy = (netNeeded / standardPackageGrams).ceil();
    final totalPurchased = packagesToBuy * standardPackageGrams;
    final totalAvailable = alreadyHaveGrams + totalPurchased;
    final surplus = totalAvailable - recipeQuantityGrams;

    String? suggestion;
    final lowerName = ingredientName.toLowerCase();
    if (surplus >= 200) {
      if (lowerName.contains('tomato') || lowerName.contains('गोलभेडा')) {
        suggestion = 'Leftover tomatoes make fresh tomato achar (गोलभेडाको अचार)';
      } else if (lowerName.contains('potato') || lowerName.contains('आलु')) {
        suggestion = 'Leftover potatoes can be used for tomorrow\'s khaja or aloo paratha';
      } else if (lowerName.contains('spinach') || lowerName.contains('पालुङ्गो')) {
        suggestion = 'Cook remaining spinach within 2 days to prevent wilting';
      }
    }

    return PurchaseRecommendation(
      ingredientName: ingredientName,
      recipeQuantityGrams: recipeQuantityGrams,
      packageSizeGrams: standardPackageGrams,
      packagesToBuy: packagesToBuy,
      totalPurchasedGrams: totalPurchased,
      surplusGrams: surplus,
      surplusSuggestion: suggestion,
    );
  }
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
    // High altitude (>1800m, e.g. La Paz 3,600m or Himalayan mountain areas)
    return (baseSiti * 1.3).round();
  }

  /// Human-readable explanation of the altitude adjustment for recipe screens.
  static String altitudeExplanation({
    required int originalSiti,
    required int adjustedSiti,
    required double elevationMeters,
  }) {
    if (originalSiti == adjustedSiti) {
      return 'At ${elevationMeters.round()} m: standard cooking pressure';
    }
    return 'At ${elevationMeters.round()} m: $adjustedSiti siti instead of $originalSiti (water boils at ${boilingPointCelsius(elevationMeters).toStringAsFixed(1)}°C)';
  }
}
