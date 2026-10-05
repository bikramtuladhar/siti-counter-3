/// Siti Counter 3.0 - Companion Display & Native Widget Engine (Section 23.4)
/// Formats, serializes, and manages glanceable data across:
/// - Home screen widgets (iOS WidgetKit, Android Glance): Today's Meals, Active Siti Count, Grocery Checklist.
/// - Apple Watch (watchOS) & Wear OS companion extensions: Live whistle counts, haptic alert triggers, step completion toggles.
library;

/// Lifecycle of an active cooking session as rendered on glanceable surfaces.
///
/// - `idle`      no session running yet
/// - `cooking`   session running, below the whistle target
/// - `paused`    session held by the user (Watch/app), still below target
/// - `alarm`     whistle target reached and not yet acknowledged
/// - `completed` target was reached and the alarm was acknowledged (session finished)
///
/// Note: `completed` is terminal. Re-deriving the alarm from `currentWhistles >= targetWhistles`
/// must NOT resurrect an acknowledged session; see `CompanionDisplayEngine.resolveAlarm`.
enum CompanionStatus {
  idle,
  cooking,
  paused,
  alarm,
  completed,
}

extension CompanionStatusValue on CompanionStatus {
  String get wireValue => name;

  static CompanionStatus fromWire(String? value) {
    return CompanionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => CompanionStatus.idle,
    );
  }
}

/// Number of grocery rows a glanceable surface shows before collapsing into a count.
const int groceryPreviewLimit = 5;

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

  factory WidgetPlannedMealSummary.fromJson(Map<String, dynamic> json) {
    return WidgetPlannedMealSummary(
      slotId: json['slotId'] as String? ?? '',
      slotTitleEn: json['slotTitleEn'] as String? ?? '',
      slotTitleNe: json['slotTitleNe'] as String? ?? '',
      recipeTitleEn: json['recipeTitleEn'] as String? ?? '',
      recipeTitleNe: json['recipeTitleNe'] as String? ?? '',
      servings: (json['servings'] as num?)?.toInt() ?? 0,
    );
  }
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

  factory TodaysMealsWidgetData.fromJson(Map<String, dynamic> json) {
    // Skip rows that are not shaped like a meal summary rather than throwing: a cache row
    // written by an older/newer schema must not make the whole feed unreadable.
    final meals = (json['meals'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WidgetPlannedMealSummary.fromJson)
        .toList();
    return TodaysMealsWidgetData(
      dateIso: json['dateIso'] as String? ?? '',
      rituNameEn: json['rituNameEn'] as String? ?? '',
      rituNameNe: json['rituNameNe'] as String? ?? '',
      meals: meals,
      totalPlannedMeals: (json['totalPlannedMeals'] as num?)?.toInt() ?? meals.length,
    );
  }
}

class ActiveSitiWidgetData {
  final String sessionId;
  final String dishTitleEn;
  final String dishTitleNe;
  final int currentWhistles;
  final int targetWhistles;
  final int progressPercent;
  final bool isAlarmActive;
  final CompanionStatus status;

  /// True once the alarm has been acknowledged; suppresses automatic re-arming.
  final bool isAlarmAcknowledged;

  const ActiveSitiWidgetData({
    required this.sessionId,
    required this.dishTitleEn,
    required this.dishTitleNe,
    required this.currentWhistles,
    required this.targetWhistles,
    required this.progressPercent,
    required this.isAlarmActive,
    required this.status,
    this.isAlarmAcknowledged = false,
  });

  ActiveSitiWidgetData copyWith({
    String? sessionId,
    String? dishTitleEn,
    String? dishTitleNe,
    int? currentWhistles,
    int? targetWhistles,
    int? progressPercent,
    bool? isAlarmActive,
    CompanionStatus? status,
    bool? isAlarmAcknowledged,
  }) {
    return ActiveSitiWidgetData(
      sessionId: sessionId ?? this.sessionId,
      dishTitleEn: dishTitleEn ?? this.dishTitleEn,
      dishTitleNe: dishTitleNe ?? this.dishTitleNe,
      currentWhistles: currentWhistles ?? this.currentWhistles,
      targetWhistles: targetWhistles ?? this.targetWhistles,
      progressPercent: progressPercent ?? this.progressPercent,
      isAlarmActive: isAlarmActive ?? this.isAlarmActive,
      status: status ?? this.status,
      isAlarmAcknowledged: isAlarmAcknowledged ?? this.isAlarmAcknowledged,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'dishTitleEn': dishTitleEn,
    'dishTitleNe': dishTitleNe,
    'currentWhistles': currentWhistles,
    'targetWhistles': targetWhistles,
    'progressPercent': progressPercent,
    'isAlarmActive': isAlarmActive,
    'status': status.wireValue,
    'isAlarmAcknowledged': isAlarmAcknowledged,
  };

  factory ActiveSitiWidgetData.fromJson(Map<String, dynamic> json) {
    return ActiveSitiWidgetData(
      sessionId: json['sessionId'] as String? ?? '',
      dishTitleEn: json['dishTitleEn'] as String? ?? '',
      dishTitleNe: json['dishTitleNe'] as String? ?? '',
      currentWhistles: (json['currentWhistles'] as num?)?.toInt() ?? 0,
      targetWhistles: (json['targetWhistles'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
      isAlarmActive: json['isAlarmActive'] as bool? ?? false,
      status: CompanionStatusValue.fromWire(json['status'] as String?),
      isAlarmAcknowledged: json['isAlarmAcknowledged'] as bool? ?? false,
    );
  }
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

  factory GroceryItemWidgetSummary.fromJson(Map<String, dynamic> json) {
    return GroceryItemWidgetSummary(
      itemId: json['itemId'] as String? ?? '',
      nameEn: json['nameEn'] as String? ?? '',
      nameNe: json['nameNe'] as String? ?? '',
      quantityStr: json['quantityStr'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
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

  factory GroceryChecklistWidgetData.fromJson(Map<String, dynamic> json) {
    final preview = (json['previewItems'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GroceryItemWidgetSummary.fromJson)
        .toList();
    return GroceryChecklistWidgetData(
      totalItems: (json['totalItems'] as num?)?.toInt() ?? preview.length,
      completedItems: (json['completedItems'] as num?)?.toInt() ?? 0,
      pendingItems: (json['pendingItems'] as num?)?.toInt() ?? 0,
      previewItems: preview,
    );
  }
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
  final CompanionStatus status;

  /// True once the alarm has been acknowledged; suppresses automatic re-arming.
  final bool isAlarmAcknowledged;

  /// True when [currentStepIndex] points at a step the cook has already completed.
  /// Drives the reversible watch step toggle.
  final bool isStepCompleted;

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
    this.isAlarmAcknowledged = false,
    this.isStepCompleted = false,
    this.lastHapticPattern = WatchHapticPattern.none,
  });

  WatchCompanionState copyWith({
    String? sessionId,
    String? dishTitleEn,
    String? dishTitleNe,
    int? currentWhistles,
    int? targetWhistles,
    int? currentStepIndex,
    int? totalSteps,
    String? currentStepInstructionEn,
    String? currentStepInstructionNe,
    bool? isAlarmActive,
    CompanionStatus? status,
    bool? isAlarmAcknowledged,
    bool? isStepCompleted,
    WatchHapticPattern? lastHapticPattern,
  }) {
    return WatchCompanionState(
      sessionId: sessionId ?? this.sessionId,
      dishTitleEn: dishTitleEn ?? this.dishTitleEn,
      dishTitleNe: dishTitleNe ?? this.dishTitleNe,
      currentWhistles: currentWhistles ?? this.currentWhistles,
      targetWhistles: targetWhistles ?? this.targetWhistles,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      totalSteps: totalSteps ?? this.totalSteps,
      currentStepInstructionEn:
          currentStepInstructionEn ?? this.currentStepInstructionEn,
      currentStepInstructionNe:
          currentStepInstructionNe ?? this.currentStepInstructionNe,
      isAlarmActive: isAlarmActive ?? this.isAlarmActive,
      status: status ?? this.status,
      isAlarmAcknowledged: isAlarmAcknowledged ?? this.isAlarmAcknowledged,
      isStepCompleted: isStepCompleted ?? this.isStepCompleted,
      lastHapticPattern: lastHapticPattern ?? this.lastHapticPattern,
    );
  }

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
    'status': status.wireValue,
    'isAlarmAcknowledged': isAlarmAcknowledged,
    'isStepCompleted': isStepCompleted,
    'lastHapticPattern': lastHapticPattern.name,
  };

  factory WatchCompanionState.fromJson(Map<String, dynamic> json) {
    return WatchCompanionState(
      sessionId: json['sessionId'] as String? ?? '',
      dishTitleEn: json['dishTitleEn'] as String? ?? '',
      dishTitleNe: json['dishTitleNe'] as String? ?? '',
      currentWhistles: (json['currentWhistles'] as num?)?.toInt() ?? 0,
      targetWhistles: (json['targetWhistles'] as num?)?.toInt() ?? 0,
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
      currentStepInstructionEn: json['currentStepInstructionEn'] as String? ?? '',
      currentStepInstructionNe: json['currentStepInstructionNe'] as String? ?? '',
      isAlarmActive: json['isAlarmActive'] as bool? ?? false,
      status: CompanionStatusValue.fromWire(json['status'] as String?),
      isAlarmAcknowledged: json['isAlarmAcknowledged'] as bool? ?? false,
      isStepCompleted: json['isStepCompleted'] as bool? ?? false,
      lastHapticPattern: WatchHapticPattern.values.firstWhere(
        (h) => h.name == json['lastHapticPattern'],
        orElse: () => WatchHapticPattern.none,
      ),
    );
  }
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
    CompanionStatus status = CompanionStatus.cooking,
    bool isAlarmActive = false,
    bool isAlarmAcknowledged = false,
  }) {
    final alarm = resolveAlarm(
      currentWhistles: currentWhistles,
      targetWhistles: targetWhistles,
      requestedAlarm: isAlarmActive,
      isAlarmAcknowledged: isAlarmAcknowledged,
      requestedStatus: status,
    );

    return ActiveSitiWidgetData(
      sessionId: sessionId,
      dishTitleEn: dishTitleEn,
      dishTitleNe: dishTitleNe,
      currentWhistles: currentWhistles,
      targetWhistles: targetWhistles,
      progressPercent: progressPercent(currentWhistles, targetWhistles),
      isAlarmActive: alarm.isAlarmActive,
      status: alarm.status,
      isAlarmAcknowledged: isAlarmAcknowledged,
    );
  }

  /// Builds Grocery Checklist Home Screen Widget snapshot
  static GroceryChecklistWidgetData buildGroceryChecklistWidget(
    List<GroceryItemWidgetSummary> items,
  ) {
    final completed = items.where((i) => i.isCompleted).length;

    return GroceryChecklistWidgetData(
      totalItems: items.length,
      completedItems: completed,
      pendingItems: items.length - completed,
      previewItems: selectGroceryPreviewItems(items),
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
    bool isAlarmAcknowledged = false,
    CompanionStatus status = CompanionStatus.cooking,
  }) {
    final alarm = resolveAlarm(
      currentWhistles: currentWhistles,
      targetWhistles: targetWhistles,
      requestedAlarm: isAlarmActive,
      isAlarmAcknowledged: isAlarmAcknowledged,
      requestedStatus: status,
    );

    var haptic = WatchHapticPattern.none;
    if (alarm.isAlarmActive) {
      haptic = WatchHapticPattern.targetReached;
    } else if (currentWhistles > 0 && alarm.status != CompanionStatus.completed) {
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
      isAlarmActive: alarm.isAlarmActive,
      status: alarm.status,
      isAlarmAcknowledged: isAlarmAcknowledged,
      lastHapticPattern: haptic,
    );
  }

  /// A whistle target is only meaningful when the caller supplied a positive target.
  /// A zero/absent target means "no target configured" and must never raise an alarm.
  static bool isTargetReached(int currentWhistles, int targetWhistles) {
    if (targetWhistles <= 0) return false;
    return currentWhistles >= targetWhistles;
  }

  /// Progress toward the whistle target, clamped to 0..100.
  /// A missing target reports 0 rather than dividing by a substituted 1.
  static int progressPercent(int currentWhistles, int targetWhistles) {
    if (targetWhistles <= 0) return 0;
    final raw = (currentWhistles / targetWhistles) * 100;
    return raw.round().clamp(0, 100);
  }

  /// Resolves the effective alarm flag and status.
  ///
  /// Once [isAlarmAcknowledged] is set the session is terminal ([CompanionStatus.completed])
  /// and the alarm stays dismissed, so a later whistle increment cannot silently re-arm it.
  static ({bool isAlarmActive, CompanionStatus status}) resolveAlarm({
    required int currentWhistles,
    required int targetWhistles,
    bool requestedAlarm = false,
    bool isAlarmAcknowledged = false,
    CompanionStatus requestedStatus = CompanionStatus.cooking,
  }) {
    if (isAlarmAcknowledged) {
      return (isAlarmActive: false, status: CompanionStatus.completed);
    }

    final targetReached = isTargetReached(currentWhistles, targetWhistles);
    final isAlarm = requestedAlarm || targetReached;

    return (
      isAlarmActive: isAlarm,
      status: isAlarm ? CompanionStatus.alarm : requestedStatus,
    );
  }

  /// Picks the rows a glanceable grocery surface shows: pending items first, because a
  /// checklist widget exists to answer "what do I still need to buy?".
  static List<GroceryItemWidgetSummary> selectGroceryPreviewItems(
    List<GroceryItemWidgetSummary> items, [
    int limit = groceryPreviewLimit,
  ]) {
    final pending = items.where((i) => !i.isCompleted).toList();
    final completed = items.where((i) => i.isCompleted).toList();
    return [...pending, ...completed].take(limit < 0 ? 0 : limit).toList();
  }
}