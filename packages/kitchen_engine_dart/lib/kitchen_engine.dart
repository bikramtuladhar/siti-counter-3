library;

import 'nepali_calendar.dart';
export 'allergen_engine.dart';
export 'auto_plan.dart';
export 'grocery_engine.dart';
export 'sync_engine.dart';
export 'region_pack.dart';
export 'region_pack_manager.dart';
export 'consumption_engine.dart';
export 'nutrition_engine.dart';
export 'waste_engine.dart';
export 'crew_engine.dart';
export 'assistant_engine.dart';
export 'voice_engine.dart';
export 'signal_engine.dart';
export 'allergen_card_engine.dart';
export 'fuel_engine.dart';

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

enum PantryStatus {
  sufficient,
  partiallyAvailable,
  missing;

  String get labelEn {
    switch (this) {
      case PantryStatus.sufficient:
        return 'Already in Pantry';
      case PantryStatus.partiallyAvailable:
        return 'Partially in Pantry';
      case PantryStatus.missing:
        return 'Need to Buy';
    }
  }

  String get labelNe {
    switch (this) {
      case PantryStatus.sufficient:
        return 'भण्डारमा छ (पर्देन)';
      case PantryStatus.partiallyAvailable:
        return 'केही छ (थप किन्नुपर्ने)';
      case PantryStatus.missing:
        return 'किन्नुपर्ने';
    }
  }
}

class IngredientPurchasePlan {
  final String ingredientId;
  final String nameEn;
  final String nameNe;
  final double recipeRequiredGrams;
  final double pantryAvailableGrams;
  final double netNeededGrams;
  final String vendorUnitLabelEn;
  final String vendorUnitLabelNe;
  final int packagesToBuy;
  final double totalPurchasedGrams;
  final double surplusGrams;
  final String? surplusSuggestionEn;
  final String? surplusSuggestionNe;
  final PantryStatus status;

  const IngredientPurchasePlan({
    required this.ingredientId,
    required this.nameEn,
    required this.nameNe,
    required this.recipeRequiredGrams,
    required this.pantryAvailableGrams,
    required this.netNeededGrams,
    required this.vendorUnitLabelEn,
    required this.vendorUnitLabelNe,
    required this.packagesToBuy,
    required this.totalPurchasedGrams,
    required this.surplusGrams,
    this.surplusSuggestionEn,
    this.surplusSuggestionNe,
    required this.status,
  });
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
  static String formatVendorUnits(double grams, {bool preferNepali = false}) {
    final intGrams = grams.round();
    if (intGrams >= 1000 && intGrams % 1000 == 0) {
      final kg = intGrams ~/ 1000;
      final pau = intGrams ~/ 250;
      return preferNepali
          ? '${NepaliCalendar.toDevanagariDigits(kg)} के.जी. (${NepaliCalendar.toDevanagariDigits(pau)} पाउ)'
          : '$kg kg ($pau pau)';
    }
    if (intGrams >= 250 && intGrams % 250 == 0) {
      final pau = intGrams ~/ 250;
      return preferNepali
          ? '${NepaliCalendar.toDevanagariDigits(pau)} पाउ (${NepaliCalendar.toDevanagariDigits(intGrams)} ग्राम)'
          : '$pau pau ($intGrams g)';
    }
    return preferNepali
        ? '${NepaliCalendar.toDevanagariDigits(intGrams)} ग्राम'
        : '$intGrams g';
  }

  static ({String? en, String? ne}) getSurplusSuggestion(
    String ingredientName,
    double surplusGrams,
  ) {
    final lower = ingredientName.toLowerCase();
    final intSurplus = surplusGrams.round();
    if (surplusGrams >= 150) {
      if (lower.contains('tomato') || lower.contains('गोलभेडा')) {
        return (
          en: 'Leftover ${intSurplus}g tomatoes make fresh fire-roasted tomato achar (गोलभेडाको अचार)',
          ne: 'बाँकी ${NepaliCalendar.toDevanagariDigits(intSurplus)} ग्राम गोलभेडा: पोलेको गोलभेडाको ताजा अचार बनाउन उत्तम',
        );
      }
      if (lower.contains('potato') || lower.contains('आलु')) {
        return (
          en: 'Leftover ${intSurplus}g potatoes can be used for tomorrow\'s aloo paratha or tarkari',
          ne: 'बाँकी ${NepaliCalendar.toDevanagariDigits(intSurplus)} ग्राम आलु: भोलिको आलु पराठा वा खाजा बनाउन प्रयोग गर्नुहोस्',
        );
      }
      if (lower.contains('radish') || lower.contains('मूला')) {
        return (
          en: 'Leftover ${intSurplus}g radish: Slice and sun-dry for fermented radish achar (मूलाको चाना/अचार)',
          ne: 'बाँकी ${NepaliCalendar.toDevanagariDigits(intSurplus)} ग्राम मूला: चाना बनाएर घाममा सुकाई स्वादिष्ट अचार बनाउनुहोस्',
        );
      }
      if (lower.contains('cauliflower') || lower.contains('काउली')) {
        return (
          en: 'Leftover ${intSurplus}g cauliflower: Pair with green peas for tomorrow\'s curry',
          ne: 'बाँकी ${NepaliCalendar.toDevanagariDigits(intSurplus)} ग्राम काउली: भोलिको लागि केराउसँग तरकारी बनाउनुहोस्',
        );
      }
      if (lower.contains('spinach') || lower.contains('पालुङ्गो') || lower.contains('saag') || lower.contains('साग')) {
        return (
          en: 'Cook remaining greens within 2 days or wilt for gundruk fermentation',
          ne: 'बाँकी साग २ दिनभित्र पकाउनुहोस् वा गुन्द्रुक बनाउन ओइलाउनुहोस्',
        );
      }
      if (lower.contains('ginger') || lower.contains('अदुवा') || lower.contains('garlic') || lower.contains('लसुन')) {
        return (
          en: 'Store leftover peeled paste in clean jar with oil and salt',
          ne: 'बाँकी अदुवा-लसुनको पेस्टमा थोरै तेल र नुन मोलेर सिसाको बट्टामा राख्नुहोस्',
        );
      }
    }
    return (en: null, ne: null);
  }

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

    final suggestionObj = getSurplusSuggestion(ingredientName, surplus);

    return PurchaseRecommendation(
      ingredientName: ingredientName,
      recipeQuantityGrams: recipeQuantityGrams,
      packageSizeGrams: standardPackageGrams,
      packagesToBuy: packagesToBuy,
      totalPurchasedGrams: totalPurchased,
      surplusGrams: surplus,
      surplusSuggestion: suggestionObj.en,
    );
  }

  static IngredientPurchasePlan calculatePurchasePlan({
    required String ingredientId,
    required String nameEn,
    required String nameNe,
    required double recipeQuantityGrams,
    required double standardPackageGrams,
    double pantryAvailableGrams = 0.0,
  }) {
    final netNeededGrams = (recipeQuantityGrams - pantryAvailableGrams).clamp(0.0, double.infinity);

    final PantryStatus status;
    if (netNeededGrams == 0.0) {
      status = PantryStatus.sufficient;
    } else if (pantryAvailableGrams > 0.0) {
      status = PantryStatus.partiallyAvailable;
    } else {
      status = PantryStatus.missing;
    }

    final packagesToBuy = netNeededGrams > 0.0
        ? (netNeededGrams / standardPackageGrams).ceil()
        : 0;
    final totalPurchasedGrams = packagesToBuy * standardPackageGrams;
    final totalAvailable = pantryAvailableGrams + totalPurchasedGrams;
    final surplusGrams = (totalAvailable - recipeQuantityGrams).clamp(0.0, double.infinity);

    final suggestion = getSurplusSuggestion(nameEn, surplusGrams);

    return IngredientPurchasePlan(
      ingredientId: ingredientId,
      nameEn: nameEn,
      nameNe: nameNe,
      recipeRequiredGrams: recipeQuantityGrams,
      pantryAvailableGrams: pantryAvailableGrams,
      netNeededGrams: netNeededGrams,
      vendorUnitLabelEn: formatVendorUnits(totalPurchasedGrams, preferNepali: false),
      vendorUnitLabelNe: formatVendorUnits(totalPurchasedGrams, preferNepali: true),
      packagesToBuy: packagesToBuy,
      totalPurchasedGrams: totalPurchasedGrams,
      surplusGrams: surplusGrams,
      surplusSuggestionEn: suggestion.en,
      surplusSuggestionNe: suggestion.ne,
      status: status,
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
