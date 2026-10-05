import '../settings/settings_service.dart';

/// Identifiers for the pieces of household setup that must be configured.
class SetupTaskIds {
  const SetupTaskIds._();

  static const String mealRhythm = 'meal_rhythm';
  static const String units = 'units';
  static const String members = 'members';
  static const String cookingRhythm = 'cooking_rhythm';

  static const List<String> all = [mealRhythm, units, members, cookingRhythm];
}

/// How complete the household setup is.
///
/// Completion is derived from real data (a member exists, a vessel is calibrated) rather
/// than from an "I did this" flag, so the checklist cannot drift out of step with reality.
class SetupProgress {
  final int total;
  final int completed;
  final List<String> completedIds;
  final List<String> remainingIds;

  const SetupProgress({
    required this.total,
    required this.completed,
    required this.completedIds,
    required this.remainingIds,
  });

  bool get isComplete => remainingIds.isEmpty;

  double get fraction => total == 0 ? 1 : completed / total;
}

/// Inputs to [deriveSetupProgress], all of them observable facts about the household.
class SetupInputs {
  /// Meal rhythm slots the household said it eats.
  final List<String> enabledMealSlots;

  /// Vessels that have been calibrated against real measurements.
  final int calibratedVesselCount;

  /// Household member profiles on record.
  final int memberCount;

  final CookingRhythm cookingRhythm;

  /// Fasting days observed, e.g. Ekadashi or Ramadan.
  final List<String> fastingDays;

  const SetupInputs({
    this.enabledMealSlots = const [],
    this.calibratedVesselCount = 0,
    this.memberCount = 0,
    this.cookingRhythm = CookingRhythm.mostDays,
    this.fastingDays = const [],
  });
}

/// Works out which setup tasks are done.
///
/// A task counts as done when the household has actually configured the thing, not when a
/// flag was flipped. [CookingRhythm.mostDays] is the default, so only an explicit change or
/// a fasting day counts as having configured that task.
///
/// Kept pure so both the home-screen checklist and the profile screen derive progress the
/// same way, and so it can be tested without a database.
SetupProgress deriveSetupProgress(SetupInputs inputs) {
  final completed = <String>[
    if (inputs.enabledMealSlots.isNotEmpty) SetupTaskIds.mealRhythm,
    if (inputs.calibratedVesselCount > 0) SetupTaskIds.units,
    if (inputs.memberCount > 0) SetupTaskIds.members,
    if (inputs.cookingRhythm != CookingRhythm.mostDays ||
        inputs.fastingDays.isNotEmpty)
      SetupTaskIds.cookingRhythm,
  ];

  return SetupProgress(
    total: SetupTaskIds.all.length,
    completed: completed.length,
    completedIds: completed,
    remainingIds: SetupTaskIds.all
        .where((id) => !completed.contains(id))
        .toList(),
  );
}

/// Reads the observable household facts and derives progress from them.
///
/// Returns an empty (all-incomplete) progress rather than throwing when the consumption
/// database is unavailable, so the checklist reports outstanding work instead of failing.
Future<SetupProgress> loadSetupProgress({
  required HouseholdSettings settings,
  required Future<int> Function() memberCount,
  required Future<int> Function() calibratedVesselCount,
}) async {
  try {
    return deriveSetupProgress(
      SetupInputs(
        enabledMealSlots: await settings.enabledMealSlots,
        calibratedVesselCount: await calibratedVesselCount(),
        memberCount: await memberCount(),
        cookingRhythm: await settings.cookingRhythm,
        fastingDays: await settings.fastingDays,
      ),
    );
  } catch (_) {
    return deriveSetupProgress(const SetupInputs());
  }
}