import 'package:flutter/foundation.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

/// Service managing glanceable data payloads for native home screen widgets (iOS WidgetKit, Android Glance)
/// and coordinating two-way state synchronization with Apple Watch (watchOS) and Wear OS companion apps.
class CompanionWidgetService extends ChangeNotifier {
  TodaysMealsWidgetData? _todaysMealsWidget;
  ActiveSitiWidgetData? _activeSitiWidget;
  GroceryChecklistWidgetData? _groceryChecklistWidget;
  WatchCompanionState? _watchCompanionState;

  TodaysMealsWidgetData? get todaysMealsWidget => _todaysMealsWidget;
  ActiveSitiWidgetData? get activeSitiWidget => _activeSitiWidget;
  GroceryChecklistWidgetData? get groceryChecklistWidget => _groceryChecklistWidget;
  WatchCompanionState? get watchCompanionState => _watchCompanionState;

  /// Updates Today's Meals widget payload
  void updateTodaysMeals({
    required String dateIso,
    required String rituNameEn,
    required String rituNameNe,
    required List<WidgetPlannedMealSummary> meals,
  }) {
    _todaysMealsWidget = CompanionDisplayEngine.buildTodaysMealsWidget(
      dateIso: dateIso,
      rituNameEn: rituNameEn,
      rituNameNe: rituNameNe,
      meals: meals,
    );
    notifyListeners();
  }

  /// Updates Active Siti Counter widget payload
  void updateActiveSiti({
    required String sessionId,
    required String dishTitleEn,
    required String dishTitleNe,
    required int currentWhistles,
    required int targetWhistles,
    required String status,
  }) {
    _activeSitiWidget = CompanionDisplayEngine.buildActiveSitiWidget(
      sessionId: sessionId,
      dishTitleEn: dishTitleEn,
      dishTitleNe: dishTitleNe,
      currentWhistles: currentWhistles,
      targetWhistles: targetWhistles,
      status: status,
    );
    notifyListeners();
  }

  /// Updates Grocery Checklist widget payload
  void updateGroceryChecklist(List<GroceryItemWidgetSummary> items) {
    _groceryChecklistWidget = CompanionDisplayEngine.buildGroceryChecklistWidget(items);
    notifyListeners();
  }

  /// Sets or updates watch companion state
  void updateWatchCompanionState(WatchCompanionState state) {
    _watchCompanionState = state;
    notifyListeners();
  }

  /// Simulates/handles whistle increment received from Watch or main app
  void incrementWatchWhistle() {
    final current = _watchCompanionState;
    if (current == null) return;

    final nextWhistle = current.currentWhistles + 1;
    final reachedTarget = current.targetWhistles > 0 && nextWhistle >= current.targetWhistles;

    _watchCompanionState = WatchCompanionState(
      sessionId: current.sessionId,
      dishTitleEn: current.dishTitleEn,
      dishTitleNe: current.dishTitleNe,
      currentWhistles: nextWhistle,
      targetWhistles: current.targetWhistles,
      currentStepIndex: current.currentStepIndex,
      totalSteps: current.totalSteps,
      currentStepInstructionEn: currentStepInstructionEn(current.currentStepIndex),
      currentStepInstructionNe: currentStepInstructionNe(current.currentStepIndex),
      isAlarmActive: reachedTarget,
      status: reachedTarget ? 'alarm' : 'cooking',
      lastHapticPattern: reachedTarget ? WatchHapticPattern.targetReached : WatchHapticPattern.whistle,
    );

    // Also sync with active siti widget if same session
    if (_activeSitiWidget != null && _activeSitiWidget!.sessionId == current.sessionId) {
      updateActiveSiti(
        sessionId: current.sessionId,
        dishTitleEn: current.dishTitleEn,
        dishTitleNe: current.dishTitleNe,
        currentWhistles: nextWhistle,
        targetWhistles: current.targetWhistles,
        status: reachedTarget ? 'alarm' : 'cooking',
      );
    }

    notifyListeners();
  }

  /// Simulates/handles step toggle or advance from Watch
  void advanceWatchStep({List<String>? stepsEn, List<String>? stepsNe}) {
    final current = _watchCompanionState;
    if (current == null) return;

    final nextIndex = (current.currentStepIndex + 1) < current.totalSteps
        ? current.currentStepIndex + 1
        : current.currentStepIndex;

    final instructionEn = (stepsEn != null && nextIndex < stepsEn.length)
        ? stepsEn[nextIndex]
        : current.currentStepInstructionEn;
    final instructionNe = (stepsNe != null && nextIndex < stepsNe.length)
        ? stepsNe[nextIndex]
        : current.currentStepInstructionNe;

    _watchCompanionState = WatchCompanionState(
      sessionId: current.sessionId,
      dishTitleEn: current.dishTitleEn,
      dishTitleNe: current.dishTitleNe,
      currentWhistles: current.currentWhistles,
      targetWhistles: current.targetWhistles,
      currentStepIndex: nextIndex,
      totalSteps: current.totalSteps,
      currentStepInstructionEn: instructionEn,
      currentStepInstructionNe: instructionNe,
      isAlarmActive: current.isAlarmActive,
      status: current.status,
      lastHapticPattern: WatchHapticPattern.tick,
    );
    notifyListeners();
  }

  /// Dismisses alarm from Watch or phone
  void dismissAlarm() {
    final current = _watchCompanionState;
    if (current != null && current.isAlarmActive) {
      _watchCompanionState = WatchCompanionState(
        sessionId: current.sessionId,
        dishTitleEn: current.dishTitleEn,
        dishTitleNe: current.dishTitleNe,
        currentWhistles: current.currentWhistles,
        targetWhistles: current.targetWhistles,
        currentStepIndex: current.currentStepIndex,
        totalSteps: current.totalSteps,
        currentStepInstructionEn: current.currentStepInstructionEn,
        currentStepInstructionNe: current.currentStepInstructionNe,
        isAlarmActive: false,
        status: 'done',
        lastHapticPattern: WatchHapticPattern.none,
      );
    }

    if (_activeSitiWidget != null && _activeSitiWidget!.isAlarmActive) {
      _activeSitiWidget = ActiveSitiWidgetData(
        sessionId: _activeSitiWidget!.sessionId,
        dishTitleEn: _activeSitiWidget!.dishTitleEn,
        dishTitleNe: _activeSitiWidget!.dishTitleNe,
        currentWhistles: _activeSitiWidget!.currentWhistles,
        targetWhistles: _activeSitiWidget!.targetWhistles,
        progressPercent: _activeSitiWidget!.progressPercent,
        isAlarmActive: false,
        status: 'done',
      );
    }

    notifyListeners();
  }

  /// Exports all current payloads for native platform storage (WidgetKit UserDefaults / Glance SharedPreferences)
  Map<String, dynamic> exportNativeWidgetPayloads() {
    return {
      'todaysMeals': _todaysMealsWidget?.toJson(),
      'activeSiti': _activeSitiWidget?.toJson(),
      'groceryChecklist': _groceryChecklistWidget?.toJson(),
      'watchState': _watchCompanionState?.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  String currentStepInstructionEn(int index) => _watchCompanionState?.currentStepInstructionEn ?? '';
  String currentStepInstructionNe(int index) => _watchCompanionState?.currentStepInstructionNe ?? '';
}
