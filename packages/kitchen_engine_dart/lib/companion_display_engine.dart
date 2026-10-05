/// Siti Counter 3.0 - Companion Display & Native Widget Engine (Section 23.4)
/// Formats, serializes, and manages glanceable data across:
/// - Home screen widgets (iOS WidgetKit, Android Glance): Today's Meals, Active Siti Count, Grocery Checklist.
/// - Apple Watch (watchOS) & Wear OS companion extensions: Live whistle counts, haptic alert triggers, step completion toggles.
library;

class WidgetPlannedMealSummary {
  final String slotId;
  final String slotTitleEn;
  final String slotTitleNe;
  final String recipeTitleEn;
  final String recipeTitleNe;
  final int servings;

  const WidgetPlannedMealSummary({
    required this.slotId,
    required this.slotTitleEn,
    required this.slotTitleNe,
    required this.recipeTitleEn,
    required this.recipeTitleNe,
    required this.servings,
  });

  Map<String, dynamic> toJson() => {
    'slotId': slotId,
    'slotTitleEn': slotTitleEn,
    'slotTitleNe': slotTitleNe,
    'recipeTitleEn': recipeTitleEn,
    'recipeTitleNe': recipeTitleNe,
    'servings': servings,
  };
}

class TodaysMealsWidgetData {
  final String dateIso;
  final String rituNameEn;
  final String rituNameNe;
  final List<WidgetPlannedMealSummary> meals;
  final int totalPlannedMeals;

  const TodaysMealsWidgetData({
    required this.dateIso,
    required this.rituNameEn,
    required this.rituNameNe,
    required this.meals,
    required this.totalPlannedMeals,
  });

  Map<String, dynamic> toJson() => {
    'dateIso': dateIso,
    'rituNameEn': rituNameEn,
    'rituNameNe': rituNameNe,
    'meals': meals.map((m) => m.toJson()).toList(),
    'totalPlannedMeals': totalPlannedMeals,
  };
}

class ActiveSitiWidgetData {
  final String sessionId;
  final String dishTitleEn;
  final String dishTitleNe;
  final int currentWhistles;
  final int targetWhistles;
  final int progressPercent;
  final bool isAlarmActive;
  final String status;

  const ActiveSitiWidgetData({
    required this.sessionId,
    required this.dishTitleEn,
    required this.dishTitleNe,
    required this.currentWhistles,
    required this.targetWhistles,
    required this.progressPercent,
    required this.isAlarmActive,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'dishTitleEn': dishTitleEn,
    'dishTitleNe': dishTitleNe,
    'currentWhistles': currentWhistles,
    'targetWhistles': targetWhistles,
    'progressPercent': progressPercent,
    'isAlarmActive': isAlarmActive,
    'status': status,
  };
}

class GroceryItemWidgetSummary {
  final String itemId;
  final String nameEn;
  final String nameNe;
  final String quantityStr;
  final bool isCompleted;

  const GroceryItemWidgetSummary({
    required this.itemId,
    required this.nameEn,
    required this.nameNe,
    required this.quantityStr,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'nameEn': nameEn,
    'nameNe': nameNe,
    'quantityStr': quantityStr,
    'isCompleted': isCompleted,
  };
}

class GroceryChecklistWidgetData {
  final int totalItems;
  final int completedItems;
  final int pendingItems;
  final List<GroceryItemWidgetSummary> previewItems;

  const GroceryChecklistWidgetData({
    required this.totalItems,
    required this.completedItems,
    required this.pendingItems,
    required this.previewItems,
  });

  Map<String, dynamic> toJson() => {
    'totalItems': totalItems,
    'completedItems': completedItems,
    'pendingItems': pendingItems,
    'previewItems': previewItems.map((i) => i.toJson()).toList(),
  };
}

enum WatchHapticPattern {
  tick,
  whistle,
  targetReached,
  none,
}

class WatchCompanionState {
  final String sessionId;
  final String dishTitleEn;
  final String dishTitleNe;
  final int currentWhistles;
  final int targetWhistles;
  final int currentStepIndex;
  final int totalSteps;
  final String currentStepInstructionEn;
  final String currentStepInstructionNe;
  final bool isAlarmActive;
  final String status;
  final WatchHapticPattern lastHapticPattern;

  const WatchCompanionState({
    required this.sessionId,
    required this.dishTitleEn,
    required this.dishTitleNe,
    required this.currentWhistles,
    required this.targetWhistles,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.currentStepInstructionEn,
    required this.currentStepInstructionNe,
    required this.isAlarmActive,
    required this.status,
    this.lastHapticPattern = WatchHapticPattern.none,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'dishTitleEn': dishTitleEn,
    'dishTitleNe': dishTitleNe,
    'currentWhistles': currentWhistles,
    'targetWhistles': targetWhistles,
    'currentStepIndex': currentStepIndex,
    'totalSteps': totalSteps,
    'currentStepInstructionEn': currentStepInstructionEn,
    'currentStepInstructionNe': currentStepInstructionNe,
    'isAlarmActive': isAlarmActive,
    'status': status,
    'lastHapticPattern': lastHapticPattern.name,
  };
}

class CompanionDisplayEngine {
  /// Builds Today's Meals Home Screen Widget snapshot
  static TodaysMealsWidgetData buildTodaysMealsWidget({
    required String dateIso,
    required String rituNameEn,
    required String rituNameNe,
    required List<WidgetPlannedMealSummary> meals,
  }) {
    return TodaysMealsWidgetData(
      dateIso: dateIso,
      rituNameEn: rituNameEn,
      rituNameNe: rituNameNe,
      meals: meals,
      totalPlannedMeals: meals.length,
    );
  }

  /// Builds Active Siti Counter Widget snapshot
  static ActiveSitiWidgetData buildActiveSitiWidget({
    required String sessionId,
    required String dishTitleEn,
    required String dishTitleNe,
    required int currentWhistles,
    required int targetWhistles,
    required String status,
  }) {
    final target = targetWhistles > 0 ? targetWhistles : 1;
    final progress = ((currentWhistles / target) * 100).round().clamp(0, 100);
    final isAlarm = status == 'alarm' || (targetWhistles > 0 && currentWhistles >= targetWhistles);

    return ActiveSitiWidgetData(
      sessionId: sessionId,
      dishTitleEn: dishTitleEn,
      dishTitleNe: dishTitleNe,
      currentWhistles: currentWhistles,
      targetWhistles: targetWhistles,
      progressPercent: progress,
      isAlarmActive: isAlarm,
      status: isAlarm ? 'alarm' : status,
    );
  }

  /// Builds Grocery Checklist Home Screen Widget snapshot
  static GroceryChecklistWidgetData buildGroceryChecklistWidget(
    List<GroceryItemWidgetSummary> items,
  ) {
    final completed = items.where((i) => i.isCompleted).length;
    final pending = items.length - completed;

    return GroceryChecklistWidgetData(
      totalItems: items.length,
      completedItems: completed,
      pendingItems: pending,
      previewItems: items.take(5).toList(),
    );
  }

  /// Builds Watch Companion App state payload for Apple Watch and Wear OS
  static WatchCompanionState buildWatchCompanionState({
    required String sessionId,
    required String dishTitleEn,
    required String dishTitleNe,
    required int currentWhistles,
    required int targetWhistles,
    required int currentStepIndex,
    required int totalSteps,
    required String currentStepInstructionEn,
    required String currentStepInstructionNe,
    bool isAlarmActive = false,
    String status = 'cooking',
  }) {
    final isAlarm = isAlarmActive ||
        (targetWhistles > 0 && currentWhistles >= targetWhistles);

    WatchHapticPattern haptic = WatchHapticPattern.none;
    if (isAlarm) {
      haptic = WatchHapticPattern.targetReached;
    } else if (currentWhistles > 0) {
      haptic = WatchHapticPattern.whistle;
    }

    return WatchCompanionState(
      sessionId: sessionId,
      dishTitleEn: dishTitleEn,
      dishTitleNe: dishTitleNe,
      currentWhistles: currentWhistles,
      targetWhistles: targetWhistles,
      currentStepIndex: currentStepIndex,
      totalSteps: totalSteps,
      currentStepInstructionEn: currentStepInstructionEn,
      currentStepInstructionNe: currentStepInstructionNe,
      isAlarmActive: isAlarm,
      status: isAlarm ? 'alarm' : status,
      lastHapticPattern: haptic,
    );
  }
}
