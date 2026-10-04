library;

import 'sync_engine.dart';

/// Supported physical vessel forms for intuitive portioning.
enum VesselType {
  katori, // Small metal/ceramic bowl (150 ml standard) for dal, curries, yogurt
  bowl,   // Medium bowl (250 ml standard) for soups, cereals, salad
  plate,  // Thali / dinner plate (400 g standard) for rice / dal bhat
  ladle,  // Daadu / Panche (60 ml standard) for curries, dal servings
  roti,   // Flatbread piece (40 g standard)
  piece,  // Discrete units (50 g standard) for momo, samosa, bara, wo
  cup,    // Drinking / measuring cup (240 ml standard)
}

/// A calibrated vessel representation with volume/weight calibration.
class CalibratedVessel {
  final String id;
  final String nameEn;
  final String nameNe;
  final VesselType type;
  final double volumeMl;
  final double standardGrams;
  final String descriptionEn;
  final String descriptionNe;
  final bool isCustom;

  const CalibratedVessel({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.type,
    required this.volumeMl,
    required this.standardGrams,
    required this.descriptionEn,
    required this.descriptionNe,
    this.isCustom = false,
  });

  CalibratedVessel copyWith({
    double? volumeMl,
    double? standardGrams,
    bool? isCustom,
  }) {
    return CalibratedVessel(
      id: id,
      nameEn: nameEn,
      nameNe: nameNe,
      type: type,
      volumeMl: volumeMl ?? this.volumeMl,
      standardGrams: standardGrams ?? this.standardGrams,
      descriptionEn: descriptionEn,
      descriptionNe: descriptionNe,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameEn': nameEn,
        'nameNe': nameNe,
        'type': type.name,
        'volumeMl': volumeMl,
        'standardGrams': standardGrams,
        'descriptionEn': descriptionEn,
        'descriptionNe': descriptionNe,
        'isCustom': isCustom,
      };

  factory CalibratedVessel.fromJson(Map<String, dynamic> json) =>
      CalibratedVessel(
        id: json['id'] as String,
        nameEn: json['nameEn'] as String,
        nameNe: json['nameNe'] as String,
        type: VesselType.values.byName(json['type'] as String),
        volumeMl: (json['volumeMl'] as num).toDouble(),
        standardGrams: (json['standardGrams'] as num).toDouble(),
        descriptionEn: json['descriptionEn'] as String? ?? '',
        descriptionNe: json['descriptionNe'] as String? ?? '',
        isCustom: json['isCustom'] as bool? ?? false,
      );

  /// Standard factory presets for household vessels
  static List<CalibratedVessel> get standardVessels => const [
        CalibratedVessel(
          id: 'katori',
          nameEn: 'Katori (Small Bowl)',
          nameNe: 'कचौरा / कटोरी',
          type: VesselType.katori,
          volumeMl: 150.0,
          standardGrams: 150.0,
          descriptionEn: 'Standard small steel katori for dal, vegetable tarkari, or yogurt.',
          descriptionNe: 'दाल, तरकारी वा दही खाने सानो कचौरा।',
        ),
        CalibratedVessel(
          id: 'bowl',
          nameEn: 'Medium Bowl',
          nameNe: 'मध्यम कचौरा / बाउल',
          type: VesselType.bowl,
          volumeMl: 250.0,
          standardGrams: 250.0,
          descriptionEn: 'Medium deep bowl for soup, thukpa, or oats.',
          descriptionNe: 'सुप, थुक्पा वा खाजा खाने मध्यम कचौरा।',
        ),
        CalibratedVessel(
          id: 'plate',
          nameEn: 'Dinner Plate / Thali',
          nameNe: 'थाली / प्लेट',
          type: VesselType.plate,
          volumeMl: 400.0,
          standardGrams: 400.0,
          descriptionEn: 'Standard plate mound for rice, dal bhat, or noodles.',
          descriptionNe: 'दाल-भात वा मुख्य खाना पस्कने थाली।',
        ),
        CalibratedVessel(
          id: 'ladle',
          nameEn: 'Ladle (Dadu)',
          nameNe: 'डडु / पन्चे',
          type: VesselType.ladle,
          volumeMl: 60.0,
          standardGrams: 60.0,
          descriptionEn: 'Serving ladle for pouring dal, curry, or gravies.',
          descriptionNe: 'दाल र रसदार तरकारी पस्कने डडु।',
        ),
        CalibratedVessel(
          id: 'roti',
          nameEn: 'Roti / Chapati',
          nameNe: 'रोटी',
          type: VesselType.roti,
          volumeMl: 40.0,
          standardGrams: 40.0,
          descriptionEn: 'Count of whole wheat flatbreads or pancakes.',
          descriptionNe: 'गहुँको रोटी वा चपाती।',
        ),
        CalibratedVessel(
          id: 'piece',
          nameEn: 'Piece (Bara/Momo/Snack)',
          nameNe: 'टुक्रा / पिस',
          type: VesselType.piece,
          volumeMl: 50.0,
          standardGrams: 50.0,
          descriptionEn: 'Discrete count for momos, bara, wo, or samosas.',
          descriptionNe: 'म:म, बारा, समोसा वा खाजाको गणना।',
        ),
        CalibratedVessel(
          id: 'cup',
          nameEn: 'Cup (Chiya/Milk)',
          nameNe: 'कप',
          type: VesselType.cup,
          volumeMl: 240.0,
          standardGrams: 240.0,
          descriptionEn: 'Standard drinking cup for tea, milk, or beverage.',
          descriptionNe: 'चिया वा दूध पिउने कप।',
        ),
      ];
}

/// Household calibration container for vessel customization.
class HouseholdVesselProfile {
  final Map<String, double> customVolumes; // vesselId -> volumeMl

  const HouseholdVesselProfile({this.customVolumes = const {}});

  HouseholdVesselProfile copyWith({Map<String, double>? customVolumes}) {
    return HouseholdVesselProfile(
      customVolumes: customVolumes ?? this.customVolumes,
    );
  }

  CalibratedVessel getEffectiveVessel(String vesselId) {
    final standard = CalibratedVessel.standardVessels.firstWhere(
      (v) => v.id == vesselId,
      orElse: () => CalibratedVessel.standardVessels.first,
    );
    if (customVolumes.containsKey(vesselId)) {
      final customVol = customVolumes[vesselId]!;
      return standard.copyWith(
        volumeMl: customVol,
        standardGrams: customVol, // 1 ml ≈ 1 g assumption for cooked foods
        isCustom: true,
      );
    }
    return standard;
  }

  Map<String, dynamic> toJson() => {'customVolumes': customVolumes};

  factory HouseholdVesselProfile.fromJson(Map<String, dynamic> json) =>
      HouseholdVesselProfile(
        customVolumes: (json['customVolumes'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            const {},
      );
}

/// Member dietary and portion configuration.
class MemberDietaryProfile {
  final String memberId;
  final String name;
  final String role; // 'Adult', 'Child', 'Toddler', 'Elderly'
  final String nutritionProfile; // 'everyday', 'child', 'baby', 'elderly', 'pregnancy', 'fitness'
  final double portionMultiplier;
  final String preferredVesselId;
  final double defaultVesselCount;

  const MemberDietaryProfile({
    required this.memberId,
    required this.name,
    this.role = 'Adult',
    this.nutritionProfile = 'everyday',
    this.portionMultiplier = 1.0,
    this.preferredVesselId = 'katori',
    this.defaultVesselCount = 1.0,
  });

  bool get isChildOrBaby =>
      nutritionProfile == 'child' || nutritionProfile == 'baby' || role == 'Toddler' || role == 'Child';

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'name': name,
        'role': role,
        'nutritionProfile': nutritionProfile,
        'portionMultiplier': portionMultiplier,
        'preferredVesselId': preferredVesselId,
        'defaultVesselCount': defaultVesselCount,
      };

  factory MemberDietaryProfile.fromJson(Map<String, dynamic> json) =>
      MemberDietaryProfile(
        memberId: json['memberId'] as String,
        name: json['name'] as String,
        role: json['role'] as String? ?? 'Adult',
        nutritionProfile: json['nutritionProfile'] as String? ?? 'everyday',
        portionMultiplier: (json['portionMultiplier'] as num?)?.toDouble() ?? 1.0,
        preferredVesselId: json['preferredVesselId'] as String? ?? 'katori',
        defaultVesselCount: (json['defaultVesselCount'] as num?)?.toDouble() ?? 1.0,
      );
}

/// Portion entry for an individual member during a meal.
class MemberConsumptionEntry {
  final String memberId;
  final String memberName;
  final String vesselId;
  final double vesselCount;
  final double calculatedGrams;
  final bool ateUsual;
  final bool skipped;
  final String? notes;

  const MemberConsumptionEntry({
    required this.memberId,
    required this.memberName,
    required this.vesselId,
    required this.vesselCount,
    required this.calculatedGrams,
    required this.ateUsual,
    this.skipped = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'memberName': memberName,
        'vesselId': vesselId,
        'vesselCount': vesselCount,
        'calculatedGrams': calculatedGrams,
        'ateUsual': ateUsual,
        'skipped': skipped,
        if (notes != null) 'notes': notes,
      };

  factory MemberConsumptionEntry.fromJson(Map<String, dynamic> json) =>
      MemberConsumptionEntry(
        memberId: json['memberId'] as String,
        memberName: json['memberName'] as String,
        vesselId: json['vesselId'] as String,
        vesselCount: (json['vesselCount'] as num).toDouble(),
        calculatedGrams: (json['calculatedGrams'] as num).toDouble(),
        ateUsual: json['ateUsual'] as bool? ?? true,
        skipped: json['skipped'] as bool? ?? false,
        notes: json['notes'] as String?,
      );
}

/// Fully logged home-cooked meal consumption record.
class MealConsumptionLog {
  final String id;
  final String? mealPlanId;
  final String recipeId;
  final String recipeTitle;
  final String mealSlot;
  final DateTime consumedAt;
  final List<MemberConsumptionEntry> memberPortions;
  final double totalServings;
  final bool loggedAsUsual;
  final double? batchYieldGrams;
  final double? leftoverGrams;

  const MealConsumptionLog({
    required this.id,
    this.mealPlanId,
    required this.recipeId,
    required this.recipeTitle,
    required this.mealSlot,
    required this.consumedAt,
    required this.memberPortions,
    required this.totalServings,
    required this.loggedAsUsual,
    this.batchYieldGrams,
    this.leftoverGrams,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (mealPlanId != null) 'mealPlanId': mealPlanId,
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
        'mealSlot': mealSlot,
        'consumedAt': consumedAt.toIso8601String(),
        'memberPortions': memberPortions.map((m) => m.toJson()).toList(),
        'totalServings': totalServings,
        'loggedAsUsual': loggedAsUsual,
        if (batchYieldGrams != null) 'batchYieldGrams': batchYieldGrams,
        if (leftoverGrams != null) 'leftoverGrams': leftoverGrams,
      };

  factory MealConsumptionLog.fromJson(Map<String, dynamic> json) =>
      MealConsumptionLog(
        id: json['id'] as String,
        mealPlanId: json['mealPlanId'] as String?,
        recipeId: json['recipeId'] as String,
        recipeTitle: json['recipeTitle'] as String,
        mealSlot: json['mealSlot'] as String,
        consumedAt: DateTime.parse(json['consumedAt'] as String),
        memberPortions: (json['memberPortions'] as List<dynamic>)
            .map((e) => MemberConsumptionEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalServings: (json['totalServings'] as num).toDouble(),
        loggedAsUsual: json['loggedAsUsual'] as bool? ?? true,
        batchYieldGrams: (json['batchYieldGrams'] as num?)?.toDouble(),
        leftoverGrams: (json['leftoverGrams'] as num?)?.toDouble(),
      );
}

/// Outside food or quick-add snack consumption record.
class OutsideFoodEntry {
  final String id;
  final String memberId;
  final String memberName;
  final String foodName;
  final String mealSlot;
  final DateTime consumedAt;
  final String portionSize; // 'small', 'medium', 'large'
  final int? estimatedCalories;
  final List<String> tags;

  const OutsideFoodEntry({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.foodName,
    required this.mealSlot,
    required this.consumedAt,
    required this.portionSize,
    this.estimatedCalories,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'memberName': memberName,
        'foodName': foodName,
        'mealSlot': mealSlot,
        'consumedAt': consumedAt.toIso8601String(),
        'portionSize': portionSize,
        if (estimatedCalories != null) 'estimatedCalories': estimatedCalories,
        'tags': tags,
      };

  factory OutsideFoodEntry.fromJson(Map<String, dynamic> json) =>
      OutsideFoodEntry(
        id: json['id'] as String,
        memberId: json['memberId'] as String,
        memberName: json['memberName'] as String,
        foodName: json['foodName'] as String,
        mealSlot: json['mealSlot'] as String,
        consumedAt: DateTime.parse(json['consumedAt'] as String),
        portionSize: json['portionSize'] as String? ?? 'medium',
        estimatedCalories: json['estimatedCalories'] as int?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}

/// Member weekly summary reflecting gentle, non-shaming health metrics.
class MemberConsumptionSummary {
  final String memberId;
  final String memberName;
  final String nutritionProfile;
  final int mealsLogged;
  final int mealsSkipped;
  final int snacksLogged;
  final double totalGramsConsumed;
  final int? estimatedCalories; // Strictly null for child/baby to avoid shaming
  final String gentleFeedback;

  const MemberConsumptionSummary({
    required this.memberId,
    required this.memberName,
    required this.nutritionProfile,
    required this.mealsLogged,
    required this.mealsSkipped,
    required this.snacksLogged,
    required this.totalGramsConsumed,
    this.estimatedCalories,
    required this.gentleFeedback,
  });
}

/// Full household weekly nutrition & consumption summary.
class WeeklyHouseholdSummary {
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final int totalMealsLogged;
  final int totalHomeCookedMeals;
  final int totalOutsideSnacksLogged;
  final double usualComplianceRate; // % confirmed as "Yes, usual"
  final Map<String, int> mealSlotFrequencies;
  final List<MemberConsumptionSummary> memberSummaries;
  final String householdRhythmStatus;
  final String gentleFamilyFeedback;

  const WeeklyHouseholdSummary({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.totalMealsLogged,
    required this.totalHomeCookedMeals,
    required this.totalOutsideSnacksLogged,
    required this.usualComplianceRate,
    required this.mealSlotFrequencies,
    required this.memberSummaries,
    required this.householdRhythmStatus,
    required this.gentleFamilyFeedback,
  });
}

/// Core domain engine for minimal-effort meal logging and vessel calibration.
class ConsumptionEngine {
  /// Logs a meal immediately when user confirms "Yes, everyone ate their usual".
  static MealConsumptionLog logUsualMeal({
    String? id,
    String? mealPlanId,
    required String recipeId,
    required String recipeTitle,
    required String mealSlot,
    DateTime? consumedAt,
    required List<MemberDietaryProfile> members,
    HouseholdVesselProfile vesselProfile = const HouseholdVesselProfile(),
    double? batchYieldGrams,
    double? leftoverGrams,
  }) {
    final logId = id ?? UuidV7.generate();
    final logTime = consumedAt ?? DateTime.now();

    final portions = <MemberConsumptionEntry>[];
    double totalServings = 0.0;

    for (final m in members) {
      final vessel = vesselProfile.getEffectiveVessel(m.preferredVesselId);
      final grams = vessel.standardGrams * m.defaultVesselCount * m.portionMultiplier;

      portions.add(
        MemberConsumptionEntry(
          memberId: m.memberId,
          memberName: m.name,
          vesselId: m.preferredVesselId,
          vesselCount: m.defaultVesselCount,
          calculatedGrams: grams,
          ateUsual: true,
          skipped: false,
        ),
      );
      totalServings += m.portionMultiplier;
    }

    return MealConsumptionLog(
      id: logId,
      mealPlanId: mealPlanId,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      mealSlot: mealSlot,
      consumedAt: logTime,
      memberPortions: portions,
      totalServings: totalServings,
      loggedAsUsual: true,
      batchYieldGrams: batchYieldGrams,
      leftoverGrams: leftoverGrams,
    );
  }

  /// Logs a meal when portions were adjusted by vessel or skipped.
  static MealConsumptionLog logAdjustedMeal({
    String? id,
    String? mealPlanId,
    required String recipeId,
    required String recipeTitle,
    required String mealSlot,
    DateTime? consumedAt,
    required List<MemberDietaryProfile> members,
    required Map<String, ({String vesselId, double vesselCount, bool skipped, String? notes})>
        adjustments,
    HouseholdVesselProfile vesselProfile = const HouseholdVesselProfile(),
    double? batchYieldGrams,
    double? leftoverGrams,
  }) {
    final logId = id ?? UuidV7.generate();
    final logTime = consumedAt ?? DateTime.now();

    final portions = <MemberConsumptionEntry>[];
    double totalServings = 0.0;

    for (final m in members) {
      final adj = adjustments[m.memberId];
      if (adj != null) {
        if (adj.skipped) {
          portions.add(
            MemberConsumptionEntry(
              memberId: m.memberId,
              memberName: m.name,
              vesselId: adj.vesselId,
              vesselCount: 0.0,
              calculatedGrams: 0.0,
              ateUsual: false,
              skipped: true,
              notes: adj.notes ?? 'Skipped meal',
            ),
          );
        } else {
          final vessel = vesselProfile.getEffectiveVessel(adj.vesselId);
          final grams = vessel.standardGrams * adj.vesselCount;
          final portionFraction = adj.vesselCount / (m.defaultVesselCount > 0 ? m.defaultVesselCount : 1.0);

          portions.add(
            MemberConsumptionEntry(
              memberId: m.memberId,
              memberName: m.name,
              vesselId: adj.vesselId,
              vesselCount: adj.vesselCount,
              calculatedGrams: grams,
              ateUsual: adj.vesselCount == m.defaultVesselCount && adj.vesselId == m.preferredVesselId,
              skipped: false,
              notes: adj.notes,
            ),
          );
          totalServings += m.portionMultiplier * portionFraction;
        }
      } else {
        // Fallback to usual
        final vessel = vesselProfile.getEffectiveVessel(m.preferredVesselId);
        final grams = vessel.standardGrams * m.defaultVesselCount * m.portionMultiplier;
        portions.add(
          MemberConsumptionEntry(
            memberId: m.memberId,
            memberName: m.name,
            vesselId: m.preferredVesselId,
            vesselCount: m.defaultVesselCount,
            calculatedGrams: grams,
            ateUsual: true,
            skipped: false,
          ),
        );
        totalServings += m.portionMultiplier;
      }
    }

    return MealConsumptionLog(
      id: logId,
      mealPlanId: mealPlanId,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      mealSlot: mealSlot,
      consumedAt: logTime,
      memberPortions: portions,
      totalServings: totalServings,
      loggedAsUsual: false,
      batchYieldGrams: batchYieldGrams,
      leftoverGrams: leftoverGrams,
    );
  }

  /// Quick adds an outside snack or restaurant meal.
  static OutsideFoodEntry quickAddOutsideFood({
    String? id,
    required String memberId,
    required String memberName,
    required String foodName,
    String mealSlot = 'snack',
    DateTime? consumedAt,
    String portionSize = 'medium',
    int? estimatedCalories,
    List<String> tags = const [],
  }) {
    return OutsideFoodEntry(
      id: id ?? UuidV7.generate(),
      memberId: memberId,
      memberName: memberName,
      foodName: foodName,
      mealSlot: mealSlot,
      consumedAt: consumedAt ?? DateTime.now(),
      portionSize: portionSize,
      estimatedCalories: estimatedCalories,
      tags: tags,
    );
  }

  /// Calculates calm, non-shaming weekly summary across household.
  static WeeklyHouseholdSummary calculateWeeklySummary({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<MealConsumptionLog> mealLogs,
    required List<OutsideFoodEntry> outsideLogs,
    required List<MemberDietaryProfile> members,
  }) {
    final filteredMeals = mealLogs
        .where((m) => m.consumedAt.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
                      m.consumedAt.isBefore(weekEnd.add(const Duration(seconds: 1))))
        .toList();

    final filteredOutside = outsideLogs
        .where((o) => o.consumedAt.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
                      o.consumedAt.isBefore(weekEnd.add(const Duration(seconds: 1))))
        .toList();

    int usualCount = 0;
    final slotFreq = <String, int>{};

    for (final meal in filteredMeals) {
      if (meal.loggedAsUsual) usualCount++;
      slotFreq[meal.mealSlot] = (slotFreq[meal.mealSlot] ?? 0) + 1;
    }

    final totalMeals = filteredMeals.length;
    final usualRate = totalMeals > 0 ? (usualCount / totalMeals) * 100.0 : 100.0;

    final memberSummaries = <MemberConsumptionSummary>[];

    for (final m in members) {
      int mealsCount = 0;
      int skippedCount = 0;
      double totalGrams = 0.0;

      for (final meal in filteredMeals) {
        final portion = meal.memberPortions.cast<MemberConsumptionEntry?>().firstWhere(
              (p) => p?.memberId == m.memberId,
              orElse: () => null,
            );
        if (portion != null) {
          if (portion.skipped) {
            skippedCount++;
          } else {
            mealsCount++;
            totalGrams += portion.calculatedGrams;
          }
        }
      }

      final snacksCount = filteredOutside.where((o) => o.memberId == m.memberId).length;

      // Section 8 & 11: Children & toddlers are never shown calorie counts.
      int? calories;
      if (!m.isChildOrBaby && mealsCount > 0) {
        // Approximate ~1.3 kcal/g for balanced dal bhat meals
        calories = (totalGrams * 1.3).round();
      }

      String gentleFeedback;
      if (m.isChildOrBaby) {
        gentleFeedback = mealsCount >= 10
            ? 'उत्कृष्ट पोषण: नियमित घरको खानाले वृद्धि विकासमा राम्रो सहयोग पुगिरहेको छ।'
            : 'सन्तुलित पोषण: विभिन्न प्रकारका फलफूल र दाल मिसाएर खुवाउनु उपयुक्त हुन्छ।';
      } else {
        gentleFeedback = mealsCount >= 12
            ? 'उत्कृष्ट लय: प्राय: सबै छाक घरमै पाकेको ताजा र पौष्टिक खाना खाइएको छ।'
            : 'सन्तुलित हप्ता: घरको खानाको मात्रा सन्तोषजनक छ, प्रोटिनयुक्त दाल नियमित गर्नुहोस्।';
      }

      memberSummaries.add(
        MemberConsumptionSummary(
          memberId: m.memberId,
          memberName: m.name,
          nutritionProfile: m.nutritionProfile,
          mealsLogged: mealsCount,
          mealsSkipped: skippedCount,
          snacksLogged: snacksCount,
          totalGramsConsumed: totalGrams,
          estimatedCalories: calories,
          gentleFeedback: gentleFeedback,
        ),
      );
    }

    final rhythmStatus = totalMeals >= 12
        ? 'नियमित र सन्तुलित (Consistent)'
        : 'मध्यम (Moderate Rhythm)';

    final familyFeedback = totalMeals >= 10
        ? 'तपाईंको परिवारले यस हप्ता धेरैजसो छाक घरमै पाकेको ताजा दाल-भात उपभोग गरेको छ।'
        : 'यस हप्ताको खानाको लय राम्रो छ। नियमित समयमा खाना खाने तालिका कायम राख्नुहोस्।';

    return WeeklyHouseholdSummary(
      weekStartDate: weekStart,
      weekEndDate: weekEnd,
      totalMealsLogged: totalMeals,
      totalHomeCookedMeals: totalMeals,
      totalOutsideSnacksLogged: filteredOutside.length,
      usualComplianceRate: usualRate,
      mealSlotFrequencies: slotFreq,
      memberSummaries: memberSummaries,
      householdRhythmStatus: rhythmStatus,
      gentleFamilyFeedback: familyFeedback,
    );
  }
}
