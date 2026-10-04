import 'consumption_engine.dart';
import 'nepali_calendar.dart';

/// Storage condition of leftovers.
enum StorageCondition {
  refrigerated,
  roomTemperature,
}

/// Climate zone / ambient temperature category.
enum ClimateZone {
  hotSummer, // > 28°C, monsoon / Terai heat
  temperate,  // 18°C - 27°C, Kathmandu valley spring/autumn
  coolWinter, // < 17°C, winter / high altitude
}

/// Urgency classification for leftover consumption.
enum LeftoverUrgency {
  fresh,    // Plenty of shelf life remaining
  eatSoon,  // Should be planned for the next meal
  urgent,   // "Eat First" - expiring within hours
  expired,  // Past safe use-by window
}

/// Detailed expiration information for a leftover dish.
class ExpiryInfo {
  final DateTime useByDate;
  final int shelfLifeHours;
  final LeftoverUrgency urgency;
  final bool isEatFirst;
  final String messageEn;
  final String messageNe;

  const ExpiryInfo({
    required this.useByDate,
    required this.shelfLifeHours,
    required this.urgency,
    required this.isEatFirst,
    required this.messageEn,
    required this.messageNe,
  });
}

/// Tracked household leftover record.
class TrackedLeftover {
  final String id;
  final String? mealLogId;
  final String recipeId;
  final String titleEn;
  final String titleNe;
  final int servingsRemaining;
  final double remainingGrams;
  final DateTime preparedAt;
  final DateTime useByDate;
  final StorageCondition storageCondition;
  final bool isConsumed;
  final DateTime? consumedAt;
  final bool isDiscarded;
  final String? discardReason;

  const TrackedLeftover({
    required this.id,
    this.mealLogId,
    required this.recipeId,
    required this.titleEn,
    required this.titleNe,
    required this.servingsRemaining,
    required this.remainingGrams,
    required this.preparedAt,
    required this.useByDate,
    this.storageCondition = StorageCondition.refrigerated,
    this.isConsumed = false,
    this.consumedAt,
    this.isDiscarded = false,
    this.discardReason,
  });

  /// Evaluates current urgency relative to the given [now] timestamp.
  LeftoverUrgency getUrgency([DateTime? now]) {
    if (isConsumed || isDiscarded) return LeftoverUrgency.fresh;
    final current = now ?? DateTime.now();
    final remainingMinutes = useByDate.difference(current).inMinutes;

    if (remainingMinutes <= 0) return LeftoverUrgency.expired;
    if (remainingMinutes <= 240) return LeftoverUrgency.urgent; // <= 4 hours
    if (remainingMinutes <= 720) return LeftoverUrgency.eatSoon; // <= 12 hours
    return LeftoverUrgency.fresh;
  }

  /// Whether this leftover should be prominently badged as "Eat First" / "पहिले खानुहोस्".
  bool isEatFirst([DateTime? now]) {
    final u = getUrgency(now);
    return u == LeftoverUrgency.urgent || u == LeftoverUrgency.eatSoon;
  }

  TrackedLeftover copyWith({
    String? id,
    String? mealLogId,
    String? recipeId,
    String? titleEn,
    String? titleNe,
    int? servingsRemaining,
    double? remainingGrams,
    DateTime? preparedAt,
    DateTime? useByDate,
    StorageCondition? storageCondition,
    bool? isConsumed,
    DateTime? consumedAt,
    bool? isDiscarded,
    String? discardReason,
  }) {
    return TrackedLeftover(
      id: id ?? this.id,
      mealLogId: mealLogId ?? this.mealLogId,
      recipeId: recipeId ?? this.recipeId,
      titleEn: titleEn ?? this.titleEn,
      titleNe: titleNe ?? this.titleNe,
      servingsRemaining: servingsRemaining ?? this.servingsRemaining,
      remainingGrams: remainingGrams ?? this.remainingGrams,
      preparedAt: preparedAt ?? this.preparedAt,
      useByDate: useByDate ?? this.useByDate,
      storageCondition: storageCondition ?? this.storageCondition,
      isConsumed: isConsumed ?? this.isConsumed,
      consumedAt: consumedAt ?? this.consumedAt,
      isDiscarded: isDiscarded ?? this.isDiscarded,
      discardReason: discardReason ?? this.discardReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (mealLogId != null) 'mealLogId': mealLogId,
        'recipeId': recipeId,
        'titleEn': titleEn,
        'titleNe': titleNe,
        'servingsRemaining': servingsRemaining,
        'remainingGrams': remainingGrams,
        'preparedAt': preparedAt.toIso8601String(),
        'useByDate': useByDate.toIso8601String(),
        'storageCondition': storageCondition.name,
        'isConsumed': isConsumed,
        if (consumedAt != null) 'consumedAt': consumedAt!.toIso8601String(),
        'isDiscarded': isDiscarded,
        if (discardReason != null) 'discardReason': discardReason,
      };

  factory TrackedLeftover.fromJson(Map<String, dynamic> json) => TrackedLeftover(
        id: json['id'] as String,
        mealLogId: json['mealLogId'] as String?,
        recipeId: json['recipeId'] as String,
        titleEn: json['titleEn'] as String,
        titleNe: json['titleNe'] as String,
        servingsRemaining: json['servingsRemaining'] as int? ?? 1,
        remainingGrams: (json['remainingGrams'] as num).toDouble(),
        preparedAt: DateTime.parse(json['preparedAt'] as String),
        useByDate: DateTime.parse(json['useByDate'] as String),
        storageCondition: StorageCondition.values.byName(
          json['storageCondition'] as String? ?? 'refrigerated',
        ),
        isConsumed: json['isConsumed'] as bool? ?? false,
        consumedAt: json['consumedAt'] != null
            ? DateTime.parse(json['consumedAt'] as String)
            : null,
        isDiscarded: json['isDiscarded'] as bool? ?? false,
        discardReason: json['discardReason'] as String?,
      );
}

/// Actionable, non-shaming waste reduction insight based on historical patterns.
class WasteInsight {
  final String recipeId;
  final String recipeTitle;
  final int dayOfWeek; // 1 = Monday .. 7 = Sunday
  final String dayNameEn;
  final String dayNameNe;
  final int occurrences;
  final double averagePreparedServings;
  final double averageConsumedServings;
  final double recommendedServings;
  final double averageLeftoverGrams;
  final double estimatedMonthlySavingsNpr;
  final String insightEn;
  final String insightNe;

  const WasteInsight({
    required this.recipeId,
    required this.recipeTitle,
    required this.dayOfWeek,
    required this.dayNameEn,
    required this.dayNameNe,
    required this.occurrences,
    required this.averagePreparedServings,
    required this.averageConsumedServings,
    required this.recommendedServings,
    required this.averageLeftoverGrams,
    required this.estimatedMonthlySavingsNpr,
    required this.insightEn,
    required this.insightNe,
  });
}

/// Household waste & leftover intelligence summary.
class HouseholdWasteSummary {
  final int totalLeftoversTracked;
  final int activeLeftoversCount;
  final int eatFirstCount;
  final int consumedCount;
  final int discardedCount;
  final int expiredCount;
  final double wastePreventionRate; // % consumed rather than discarded
  final double totalGramsSaved;
  final List<WasteInsight> insights;
  final String gentleFeedbackEn;
  final String gentleFeedbackNe;

  const HouseholdWasteSummary({
    required this.totalLeftoversTracked,
    required this.activeLeftoversCount,
    required this.eatFirstCount,
    required this.consumedCount,
    required this.discardedCount,
    required this.expiredCount,
    required this.wastePreventionRate,
    required this.totalGramsSaved,
    required this.insights,
    required this.gentleFeedbackEn,
    required this.gentleFeedbackNe,
  });
}

/// Domain engine for automatic leftover tracking, climate-aware expiration, and waste insights.
class WasteEngine {
  /// Base shelf-life in hours for different dish categories.
  static int getBaseShelfLifeHours({
    required String dishCategory,
    required StorageCondition storage,
    required ClimateZone climate,
  }) {
    final cat = dishCategory.toLowerCase();
    final isRice = cat.contains('rice') || cat.contains('bhat');
    final isDal = cat.contains('dal') || cat.contains('pulse') || cat.contains('curry');
    final isMeat = cat.contains('meat') || cat.contains('chicken') || cat.contains('buff') || cat.contains('mutton');
    final isRoti = cat.contains('roti') || cat.contains('bread') || cat.contains('chapati');

    if (storage == StorageCondition.refrigerated) {
      if (isRice) return 36; // Rice is susceptible to Bacillus cereus
      if (isMeat) return 48;
      if (isDal) return 48;
      if (isRoti) return 72;
      return 48; // Standard refrigerated cooked vegetable/curry
    } else {
      // Room temperature: highly climate sensitive
      switch (climate) {
        case ClimateZone.hotSummer:
          if (isMeat) return 6;
          if (isRice) return 8;
          if (isDal) return 8;
          if (isRoti) return 24;
          return 8;
        case ClimateZone.temperate:
          if (isMeat) return 10;
          if (isRice) return 10;
          if (isDal) return 12;
          if (isRoti) return 30;
          return 12;
        case ClimateZone.coolWinter:
          if (isMeat) return 14;
          if (isRice) return 14;
          if (isDal) return 20;
          if (isRoti) return 36;
          return 18;
      }
    }
  }

  /// Calculates expiration date, hours remaining, and urgency for a leftover item.
  static ExpiryInfo calculateExpiry({
    required DateTime preparedAt,
    String dishCategory = 'dal',
    StorageCondition storage = StorageCondition.refrigerated,
    ClimateZone climate = ClimateZone.temperate,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final hours = getBaseShelfLifeHours(
      dishCategory: dishCategory,
      storage: storage,
      climate: climate,
    );
    final useBy = preparedAt.add(Duration(hours: hours));
    final diffMinutes = useBy.difference(current).inMinutes;

    final LeftoverUrgency urgency;
    final bool isEatFirst;
    final String msgEn;
    final String msgNe;

    if (diffMinutes <= 0) {
      urgency = LeftoverUrgency.expired;
      isEatFirst = false;
      msgEn = 'Use-by time passed. Check smell and appearance before consuming.';
      msgNe = 'उपभोग गर्ने समय सकियो। खानुअघि सुँघेर र हेरेर यकिन गर्नुहोस्।';
    } else if (diffMinutes <= 240) { // <= 4 hours
      urgency = LeftoverUrgency.urgent;
      isEatFirst = true;
      msgEn = 'Eat first: best enjoyed in your next meal or today.';
      msgNe = 'पहिले खानुहोस्: आजकै अर्को छाकमा खानु उत्तम हुन्छ।';
    } else if (diffMinutes <= 720) { // <= 12 hours
      urgency = LeftoverUrgency.eatSoon;
      isEatFirst = true;
      msgEn = 'Eat soon: good for today’s lunch or dinner.';
      msgNe = 'चाँडै खानुहोस्: आजको खाना वा खाजाका लागि उपयुक्त छ।';
    } else {
      urgency = LeftoverUrgency.fresh;
      isEatFirst = false;
      msgEn = 'Fresh and safely stored.';
      msgNe = 'ताजा छ, सुरक्षित रूपमा राखिएको छ।';
    }

    return ExpiryInfo(
      useByDate: useBy,
      shelfLifeHours: hours,
      urgency: urgency,
      isEatFirst: isEatFirst,
      messageEn: msgEn,
      messageNe: msgNe,
    );
  }

  /// Automatically creates a "Eat First" leftover entry if cooked batch yield
  /// exceeds total consumed portions.
  static TrackedLeftover? createFromMealLog({
    required MealConsumptionLog log,
    String? id,
    StorageCondition storage = StorageCondition.refrigerated,
    ClimateZone climate = ClimateZone.temperate,
    double singleServingStandardGrams = 250.0,
    DateTime? now,
  }) {
    // 1. Calculate consumed grams
    final totalConsumedGrams = log.memberPortions
        .where((p) => !p.skipped)
        .fold<double>(0.0, (acc, p) => acc + p.calculatedGrams);

    // 2. Determine excess leftover grams
    final double excessGrams;
    if (log.leftoverGrams != null && log.leftoverGrams! > 0) {
      excessGrams = log.leftoverGrams!;
    } else if (log.batchYieldGrams != null && log.batchYieldGrams! > totalConsumedGrams) {
      excessGrams = log.batchYieldGrams! - totalConsumedGrams;
    } else {
      return null;
    }

    // Ignore negligible scraps under 50g
    if (excessGrams < 50.0) {
      return null;
    }

    // 3. Compute servings remaining
    final estimatedServings = (excessGrams / singleServingStandardGrams).round().clamp(1, 20);

    // 4. Calculate expiration
    final expiry = calculateExpiry(
      preparedAt: log.consumedAt,
      dishCategory: log.recipeTitle,
      storage: storage,
      climate: climate,
      now: now,
    );

    final leftoverId = id ?? 'leftover_${log.id}';

    return TrackedLeftover(
      id: leftoverId,
      mealLogId: log.id,
      recipeId: log.recipeId,
      titleEn: log.recipeTitle,
      titleNe: log.recipeTitle,
      servingsRemaining: estimatedServings,
      remainingGrams: excessGrams,
      preparedAt: log.consumedAt,
      useByDate: expiry.useByDate,
      storageCondition: storage,
      isConsumed: false,
    );
  }

  /// Day names in English and Nepali.
  static const _dayNames = [
    ('Monday', 'सोमबार'),
    ('Tuesday', 'मङ्गलबार'),
    ('Wednesday', 'बुधबार'),
    ('Thursday', 'बिहीबार'),
    ('Friday', 'शुक्रबार'),
    ('Saturday', 'शनिबार'),
    ('Sunday', 'आइतबार'),
  ];

  /// Analyzes historical meal logs to identify recurring over-portioning patterns.
  /// E.g. "Dal is often left over on Mondays; try 4 servings instead of 6".
  static List<WasteInsight> analyzeWastePatterns(
    List<MealConsumptionLog> logs, {
    int minimumOccurrences = 2,
    double singleServingStandardGrams = 250.0,
    double estimatedCostPerServingNpr = 65.0,
  }) {
    // Key: '$recipeId|$dayOfWeek'
    final patternBuckets = <String, List<({
      double preparedServings,
      double consumedServings,
      double leftoverGrams,
      String title,
      String recipeId,
      int dayOfWeek,
    })>>{};

    for (final log in logs) {
      final totalConsumed = log.memberPortions
          .where((p) => !p.skipped)
          .fold<double>(0.0, (acc, p) => acc + p.calculatedGrams);

      double leftoverGrams = 0.0;
      if (log.leftoverGrams != null && log.leftoverGrams! > 0) {
        leftoverGrams = log.leftoverGrams!;
      } else if (log.batchYieldGrams != null && log.batchYieldGrams! > totalConsumed) {
        leftoverGrams = log.batchYieldGrams! - totalConsumed;
      }

      // Only consider records with non-trivial excess leftover
      if (leftoverGrams >= 80.0) {
        final dayOfWeek = log.consumedAt.weekday; // 1 = Monday .. 7 = Sunday
        final key = '${log.recipeId}|$dayOfWeek';

        final consumedServings = totalConsumed > 0
            ? totalConsumed / singleServingStandardGrams
            : log.totalServings;
        final preparedServings = (totalConsumed + leftoverGrams) / singleServingStandardGrams;

        patternBuckets.putIfAbsent(key, () => []).add((
          preparedServings: preparedServings,
          consumedServings: consumedServings,
          leftoverGrams: leftoverGrams,
          title: log.recipeTitle,
          recipeId: log.recipeId,
          dayOfWeek: dayOfWeek,
        ));
      }
    }

    final insights = <WasteInsight>[];

    for (final entry in patternBuckets.entries) {
      final occurrences = entry.value.length;
      if (occurrences >= minimumOccurrences) {
        final first = entry.value.first;
        final avgPrepared = entry.value.fold<double>(0.0, (s, x) => s + x.preparedServings) / occurrences;
        final avgConsumed = entry.value.fold<double>(0.0, (s, x) => s + x.consumedServings) / occurrences;
        final avgLeftoverG = entry.value.fold<double>(0.0, (s, x) => s + x.leftoverGrams) / occurrences;

        final prepRound = avgPrepared.round().toDouble();
        final recRound = avgConsumed.round().clamp(1, 20).toDouble();

        // Only advise if there is a meaningful difference in rounded portions
        if (prepRound > recRound) {
          final dayIdx = first.dayOfWeek - 1;
          final dayPair = _dayNames[dayIdx];
          final title = first.title;

          final prepInt = prepRound.toInt();
          final recInt = recRound.toInt();

          final monthlySavings = (prepInt - recInt) * estimatedCostPerServingNpr * 4; // 4 weeks in a month

          final prepNe = NepaliCalendar.toDevanagariDigits(prepInt);
          final recNe = NepaliCalendar.toDevanagariDigits(recInt);

          final insightEn = '$title is often left over on ${dayPair.$1}s; try $recInt servings instead of $prepInt.';
          final insightNe = '${dayPair.$2} $title प्रायः बाँकी रहने गर्छ; $prepNe भागको सट्टा $recNe भाग पकाउनुहोस्।';

          insights.add(
            WasteInsight(
              recipeId: first.recipeId,
              recipeTitle: title,
              dayOfWeek: first.dayOfWeek,
              dayNameEn: dayPair.$1,
              dayNameNe: dayPair.$2,
              occurrences: occurrences,
              averagePreparedServings: avgPrepared,
              averageConsumedServings: avgConsumed,
              recommendedServings: recRound,
              averageLeftoverGrams: avgLeftoverG,
              estimatedMonthlySavingsNpr: monthlySavings,
              insightEn: insightEn,
              insightNe: insightNe,
            ),
          );
        }
      }
    }

    return insights;
  }

  /// Calculates a complete, gentle, non-shaming waste summary.
  static HouseholdWasteSummary calculateWasteSummary({
    required List<TrackedLeftover> leftovers,
    List<MealConsumptionLog> recentMealLogs = const [],
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    int activeCount = 0;
    int eatFirstCount = 0;
    int consumedCount = 0;
    int discardedCount = 0;
    int expiredCount = 0;
    double gramsSaved = 0.0;

    for (final l in leftovers) {
      if (l.isConsumed) {
        consumedCount++;
        gramsSaved += l.remainingGrams;
      } else if (l.isDiscarded) {
        discardedCount++;
      } else {
        activeCount++;
        final urgency = l.getUrgency(current);
        if (urgency == LeftoverUrgency.expired) {
          expiredCount++;
        } else if (urgency == LeftoverUrgency.urgent || urgency == LeftoverUrgency.eatSoon) {
          eatFirstCount++;
        }
      }
    }

    final totalResolved = consumedCount + discardedCount + expiredCount;
    final preventionRate = totalResolved > 0
        ? ((consumedCount / totalResolved) * 100.0).clamp(0.0, 100.0)
        : 100.0;

    final insights = analyzeWastePatterns(recentMealLogs);

    final String feedbackEn;
    final String feedbackNe;

    if (activeCount == 0 && eatFirstCount == 0) {
      feedbackEn = 'Kitchen fridge is tidy. No leftover dish is pending.';
      feedbackNe = 'भान्सा सफा र व्यवस्थित छ। कुनै खाना बाँकी छैन।';
    } else if (eatFirstCount > 0) {
      feedbackEn = '$eatFirstCount dish needs eating first today to prevent waste.';
      feedbackNe = 'खाना खेर जान नदिन आज $eatFirstCount वटा परिकार पहिले खानुहोस्।';
    } else {
      feedbackEn = '$activeCount dishes safely stored for upcoming meals.';
      feedbackNe = '$activeCount वटा परिकार आगामी छाकका लागि सुरक्षित छन्।';
    }

    return HouseholdWasteSummary(
      totalLeftoversTracked: leftovers.length,
      activeLeftoversCount: activeCount,
      eatFirstCount: eatFirstCount,
      consumedCount: consumedCount,
      discardedCount: discardedCount,
      expiredCount: expiredCount,
      wastePreventionRate: preventionRate,
      totalGramsSaved: gramsSaved,
      insights: insights,
      gentleFeedbackEn: feedbackEn,
      gentleFeedbackNe: feedbackNe,
    );
  }
}
