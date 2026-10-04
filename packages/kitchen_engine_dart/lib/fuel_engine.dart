/// Fuel Engine: LPG Cylinder Depletion Estimator & Power-Cut Outage Mode
///
/// Implements Section 10.5 of Siti Counter 3.0 specification:
/// - LPG cylinder burn-rate estimation based on session logs & flame level
/// - Refill reminder alerts when cylinder is predicted to deplete in <= 4 days
/// - Power-cut mode: filters gas-only and no-cook recipes, excluding electric appliances

enum LpgCylinderType {
  standard14_2(14.2, 15.3, 'Standard Domestic (14.2 kg)'),
  commercial19(19.0, 18.5, 'Commercial Cylinder (19 kg)'),
  mini5(5.0, 6.2, 'Chhotu / Mini (5 kg)');

  final double netGasCapacityKg;
  final double defaultTareWeightKg;
  final String label;

  const LpgCylinderType(this.netGasCapacityKg, this.defaultTareWeightKg, this.label);
}

enum FlameIntensity {
  high(200.0, 'High Flame (ठूलो आगो)'),
  medium(130.0, 'Medium Flame (मध्यम आगो)'),
  low(70.0, 'Simmer / Low (मन्द आगो)');

  /// Consumption rate in grams per hour per standard burner
  final double gramsPerHour;
  final String label;

  const FlameIntensity(this.gramsPerHour, this.label);

  /// Consumption rate in grams per minute
  double get gramsPerMinute => gramsPerHour / 60.0;
}

enum RefillUrgency {
  normal,
  orderSoon, // <= 4 days remaining or <= 15%
  critical,  // <= 1.5 days remaining or <= 5%
  empty,     // 0 days / <= 0 kg
}

class CookingFuelSession {
  final String sessionId;
  final String recipeName;
  final DateTime startTime;
  final int durationMinutes;
  final FlameIntensity flameIntensity;
  final int burnerCount;

  const CookingFuelSession({
    required this.sessionId,
    required this.recipeName,
    required this.startTime,
    required this.durationMinutes,
    this.flameIntensity = FlameIntensity.medium,
    this.burnerCount = 1,
  });

  /// Gas consumed during this cooking session in grams
  double get gasConsumedGrams {
    return durationMinutes * flameIntensity.gramsPerMinute * burnerCount;
  }
}

class LpgCylinderState {
  final String id;
  final LpgCylinderType type;
  final String brand; // e.g. 'Nepal Gas', 'Sugam', 'Everest', 'Indane'
  final DateTime installationDate;
  final double initialNetGasKg;
  final double remainingGasKg;
  final double tareWeightKg;
  final DateTime? lastCalibratedDate;

  const LpgCylinderState({
    required this.id,
    this.type = LpgCylinderType.standard14_2,
    this.brand = 'Nepal Gas',
    required this.installationDate,
    required this.initialNetGasKg,
    required this.remainingGasKg,
    required this.tareWeightKg,
    this.lastCalibratedDate,
  });

  factory LpgCylinderState.newCylinder({
    String id = 'cyl-primary',
    LpgCylinderType type = LpgCylinderType.standard14_2,
    String brand = 'Nepal Gas',
    DateTime? installationDate,
    double? tareWeightKg,
  }) {
    final now = installationDate ?? DateTime.now();
    return LpgCylinderState(
      id: id,
      type: type,
      brand: brand,
      installationDate: now,
      initialNetGasKg: type.netGasCapacityKg,
      remainingGasKg: type.netGasCapacityKg,
      tareWeightKg: tareWeightKg ?? type.defaultTareWeightKg,
      lastCalibratedDate: now,
    );
  }

  /// Percentage of gas remaining (0.0 to 100.0)
  double get percentageRemaining {
    if (initialNetGasKg <= 0) return 0.0;
    final pct = (remainingGasKg / initialNetGasKg) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  /// Returns a copy with deducted gas consumption
  LpgCylinderState recordConsumption(double gramsConsumed) {
    final kgDeducted = gramsConsumed / 1000.0;
    final updatedRemaining = (remainingGasKg - kgDeducted).clamp(0.0, initialNetGasKg);
    return LpgCylinderState(
      id: id,
      type: type,
      brand: brand,
      installationDate: installationDate,
      initialNetGasKg: initialNetGasKg,
      remainingGasKg: updatedRemaining,
      tareWeightKg: tareWeightKg,
      lastCalibratedDate: lastCalibratedDate,
    );
  }

  /// Calibrates remaining gas from a physical scale reading (gross weight - tare)
  LpgCylinderState calibrateFromGrossWeight(double grossWeightKg) {
    final calculatedNet = (grossWeightKg - tareWeightKg).clamp(0.0, initialNetGasKg);
    return LpgCylinderState(
      id: id,
      type: type,
      brand: brand,
      installationDate: installationDate,
      initialNetGasKg: initialNetGasKg,
      remainingGasKg: calculatedNet,
      tareWeightKg: tareWeightKg,
      lastCalibratedDate: DateTime.now(),
    );
  }
}

class LpgDepletionForecast {
  final double remainingGasKg;
  final double remainingPercentage;
  final double averageDailyBurnGrams;
  final double estimatedDaysRemaining;
  final DateTime estimatedDepletionDate;
  final RefillUrgency urgency;
  final String refillAlertMessageEn;
  final String refillAlertMessageNe;

  const LpgDepletionForecast({
    required this.remainingGasKg,
    required this.remainingPercentage,
    required this.averageDailyBurnGrams,
    required this.estimatedDaysRemaining,
    required this.estimatedDepletionDate,
    required this.urgency,
    required this.refillAlertMessageEn,
    required this.refillAlertMessageNe,
  });

  bool get isRefillNeeded =>
      urgency == RefillUrgency.orderSoon ||
      urgency == RefillUrgency.critical ||
      urgency == RefillUrgency.empty;
}

/// Power-Cut / Load-Shedding Recipe Compatibility
enum RecipePowerProfile {
  noCook,            // e.g. Chiura Dahi, Aloo Sadheko, Salad, Fruit Chaat
  gasPressureCooker, // e.g. Dal Bhat, Khasiko Masu, Khichdi
  gasStoveTop,       // e.g. Tarkari, Roti on Tawa, Fried Rice
  electricAppliance, // e.g. Induction, Mixer Grinder, Microwave, Oven, Air Fryer
}

class PowerCutRecipeItem {
  final String id;
  final String nameEn;
  final String nameNe;
  final RecipePowerProfile powerProfile;
  final int cookTimeMinutes;
  final int whistles;
  final bool isGasSaver; // Quick cook <= 20 mins or <= 2 whistles

  const PowerCutRecipeItem({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.powerProfile,
    required this.cookTimeMinutes,
    this.whistles = 0,
    this.isGasSaver = false,
  });

  bool get isCompatibleWithPowerCut =>
      powerProfile != RecipePowerProfile.electricAppliance;
}

class FuelEngine {
  /// Default household daily burn rate when not enough history exists (~280g/day for typical Nepal family)
  static const double defaultDailyBurnGrams = 280.0;

  /// Predicts cylinder depletion and refill urgency based on history
  static LpgDepletionForecast predictDepletion({
    required LpgCylinderState cylinder,
    List<CookingFuelSession> recentSessions = const [],
    DateTime? currentDate,
  }) {
    final now = currentDate ?? DateTime.now();

    double dailyBurnGrams;
    if (recentSessions.isNotEmpty) {
      final totalGasGrams = recentSessions.fold<double>(
        0.0,
        (acc, s) => acc + s.gasConsumedGrams,
      );

      final daysSpan = (now.difference(cylinder.installationDate).inHours / 24.0).clamp(1.0, 90.0);
      dailyBurnGrams = (totalGasGrams / daysSpan).clamp(100.0, 900.0);
    } else {
      dailyBurnGrams = defaultDailyBurnGrams;
    }

    final remainingGrams = cylinder.remainingGasKg * 1000.0;
    final estimatedDays = dailyBurnGrams > 0 ? remainingGrams / dailyBurnGrams : 0.0;
    final depletionDate = now.add(Duration(hours: (estimatedDays * 24).round()));

    RefillUrgency urgency;
    if (cylinder.remainingGasKg <= 0.05 || estimatedDays <= 0.1) {
      urgency = RefillUrgency.empty;
    } else if (estimatedDays <= 1.5 || cylinder.percentageRemaining <= 5.0) {
      urgency = RefillUrgency.critical;
    } else if (estimatedDays <= 4.0 || cylinder.percentageRemaining <= 15.0) {
      urgency = RefillUrgency.orderSoon;
    } else {
      urgency = RefillUrgency.normal;
    }

    String alertEn;
    String alertNe;

    switch (urgency) {
      case RefillUrgency.empty:
        alertEn = 'LPG Cylinder is EMPTY! Switch to spare cylinder or order refill immediately.';
        alertNe = 'एलपिजी सिलिन्डर रित्तियो! स्पेयर सिलिन्डर जोड्नुहोस् वा तुरुन्तै नयाँ मगाउनुहोस्।';
        break;
      case RefillUrgency.critical:
        alertEn = 'URGENT: Only ~${estimatedDays.toStringAsFixed(1)} days (${cylinder.remainingGasKg.toStringAsFixed(1)} kg) of gas left. Call dealer for refill today!';
        alertNe = 'अति जरुरी: करिब ${estimatedDays.toStringAsFixed(1)} दिन (${cylinder.remainingGasKg.toStringAsFixed(1)} केजी) ग्यास मात्र बाँकी छ। आजै डिलरलाई अर्डर गर्नुहोस्!';
        break;
      case RefillUrgency.orderSoon:
        alertEn = 'Refill Reminder: Cylinder predicted to deplete in ~${estimatedDays.toStringAsFixed(1)} days (${cylinder.percentageRemaining.toStringAsFixed(0)}% left). Order your refill.';
        alertNe = 'रिफिल रिमाइन्डर: सिलिन्डर करिब ${estimatedDays.toStringAsFixed(1)} दिनमा सकिनेछ (${cylinder.percentageRemaining.toStringAsFixed(0)}% बाँकी)। नयाँ सिलिन्डर बुक गर्नुहोस्।';
        break;
      case RefillUrgency.normal:
        alertEn = 'LPG gas level is healthy (${cylinder.remainingGasKg.toStringAsFixed(1)} kg, ~${estimatedDays.toStringAsFixed(0)} days remaining).';
        alertNe = 'एलपिजी ग्यास पर्याप्त छ (${cylinder.remainingGasKg.toStringAsFixed(1)} केजी, करिब ${estimatedDays.toStringAsFixed(0)} दिन बाँकी)।';
        break;
    }

    return LpgDepletionForecast(
      remainingGasKg: cylinder.remainingGasKg,
      remainingPercentage: cylinder.percentageRemaining,
      averageDailyBurnGrams: dailyBurnGrams,
      estimatedDaysRemaining: estimatedDays,
      estimatedDepletionDate: depletionDate,
      urgency: urgency,
      refillAlertMessageEn: alertEn,
      refillAlertMessageNe: alertNe,
    );
  }

  /// Filters recipes for power-cut / load-shedding conditions
  static List<PowerCutRecipeItem> filterForPowerCut({
    required List<PowerCutRecipeItem> recipes,
    bool gasSaverOnly = false,
    bool noCookOnly = false,
  }) {
    return recipes.where((r) {
      if (!r.isCompatibleWithPowerCut) return false;
      if (noCookOnly && r.powerProfile != RecipePowerProfile.noCook) return false;
      if (gasSaverOnly && !r.isGasSaver && r.powerProfile != RecipePowerProfile.noCook) return false;
      return true;
    }).toList();
  }
}
