import 'package:sqflite/sqflite.dart';

import '../onboarding/onboarding_state.dart';
import 'settings_repository.dart';

/// How often the household actually cooks, which changes what a sensible default plan is.
enum CookingRhythm {
  daily('daily'),
  mostDays('most_days'),
  occasionally('occasionally'),
  festivalsOnly('festivals_only');

  const CookingRhythm(this.wireValue);
  final String wireValue;
}

/// Parses a stored cooking rhythm, falling back to the default.
///
/// A top-level function rather than a `static CookingRhythm.fromWire` method: Dart parses
/// `static <EnumName>.<name>(...)` as a *named constructor declaration*, which may not be
/// static, so that spelling is a compile error.
CookingRhythm cookingRhythmFromWire(String? value) {
  return CookingRhythm.values.firstWhere(
    (r) => r.wireValue == value,
    orElse: () => CookingRhythm.mostDays,
  );
}

/// Measurement system for portions and shopping quantities.
enum UnitSystem {
  metric('metric'),
  metricWithTraditional('metric_traditional'),
  imperial('imperial');

  const UnitSystem(this.wireValue);
  final String wireValue;
}

/// Parses a stored unit system, falling back to pau/mana/metric.
UnitSystem unitSystemFromWire(String? value) {
  return UnitSystem.values.firstWhere(
    (u) => u.wireValue == value,
    orElse: () => UnitSystem.metricWithTraditional,
  );
}

/// The household profile the setup screens read and write.
///
/// An interface rather than the concrete SQLite service so the UI can be exercised without
/// a live database: sqflite's real I/O never completes inside `testWidgets`' fake-async
/// zone, so a screen wired straight to the database is untestable in a widget test.
abstract class HouseholdSettings {
  Future<bool> get isOnboardingComplete;
  Future<void> setOnboardingComplete(bool value);

  Future<String> get language;
  Future<void> setLanguage(String code);

  Future<String> get regionPackId;
  Future<List<String>> get stoveTypes;
  Future<double> get elevationMeters;
  Future<List<String>> get dietaryRules;
  Future<bool> get isGuest;

  Future<void> saveOnboardingPreferences(OnboardingPreferences prefs);
  Future<OnboardingPreferences> loadPreferences({
    int adultsCount,
    int childrenCount,
    int eldersCount,
  });

  Future<UnitSystem> get unitSystem;
  Future<void> setUnitSystem(UnitSystem value);

  Future<CookingRhythm> get cookingRhythm;
  Future<void> setCookingRhythm(CookingRhythm value);

  Future<List<String>> get fastingDays;
  Future<void> setFastingDays(List<String> value);

  Future<List<String>> get enabledMealSlots;
  Future<void> setEnabledMealSlots(List<String> value);
}

/// Typed accessors over [SettingsRepository] for the household profile.
///
/// Everything the first-run flow collects is written here, so the answers survive a restart
/// and the setup checklist can read what is already configured.
class SettingsService implements HouseholdSettings {
  final SettingsRepository repository;

  SettingsService(this.repository);

  static Future<SettingsService> openOnDisk([
    String path = 'siti_settings.db',
  ]) async {
    final repository = await SettingsRepository.openOnDisk(path);
    return SettingsService(repository);
  }

  /// Underlying handle, for callers that need to join against other tables in the same
  /// database rather than go through the key/value API.
  Database get database => repository.database;

  // --- Onboarding basics ---

  @override
  Future<bool> get isOnboardingComplete =>
      repository.readBool(SettingsRepository.keyOnboardingComplete);

  @override
  Future<void> setOnboardingComplete(bool value) =>
      repository.write(SettingsRepository.keyOnboardingComplete, value);

  @override
  Future<String> get language =>
      repository.readString(SettingsRepository.keyLanguage, fallback: 'ne');

  @override
  Future<void> setLanguage(String code) =>
      repository.write(SettingsRepository.keyLanguage, code);

  @override
  Future<String> get regionPackId => repository.readString(
    SettingsRepository.keyRegionPackId,
    fallback: 'nepal-bagmati',
  );

  @override
  Future<List<String>> get stoveTypes async {
    final stored = await repository.readStringList(
      SettingsRepository.keyStoveTypes,
    );
    return stored.isEmpty ? const ['lpg_gas'] : stored;
  }

  @override
  Future<double> get elevationMeters => repository.readDouble(
    SettingsRepository.keyElevationMeters,
    fallback: 1400,
  );

  @override
  Future<List<String>> get dietaryRules =>
      repository.readStringList(SettingsRepository.keyDietaryRules);

  @override
  Future<bool> get isGuest =>
      repository.readBool(SettingsRepository.keyIsGuest, fallback: true);

  /// Persists the answers the onboarding wizard collected.
  @override
  Future<void> saveOnboardingPreferences(OnboardingPreferences prefs) async {
    await repository.write(SettingsRepository.keyLanguage, prefs.language);
    await repository.write(
      SettingsRepository.keyRegionPackId,
      prefs.regionPackId,
    );
    await repository.write(
      SettingsRepository.keyStoveTypes,
      prefs.stoveTypes,
    );
    await repository.write(
      SettingsRepository.keyElevationMeters,
      prefs.elevationMeters,
    );
    await repository.write(
      SettingsRepository.keyDietaryRules,
      prefs.dietaryRules,
    );
    await repository.write(SettingsRepository.keyIsGuest, prefs.isGuest);
    await setOnboardingComplete(true);
  }

  /// Rebuilds the in-memory preferences the app renders with, from what is stored.
  ///
  /// Household counts are not stored here: they are derived from the member profiles the
  /// consumption database holds, so there is one source of truth for them.
  @override
  Future<OnboardingPreferences> loadPreferences({
    int adultsCount = 1,
    int childrenCount = 0,
    int eldersCount = 0,
  }) async {
    return OnboardingPreferences(
      language: await language,
      regionPackId: await regionPackId,
      stoveTypes: await stoveTypes,
      elevationMeters: await elevationMeters,
      dietaryRules: await dietaryRules,
      isGuest: await isGuest,
      adultsCount: adultsCount,
      childrenCount: childrenCount,
      eldersCount: eldersCount,
    );
  }

  // --- Extended household setup ---

  @override
  Future<UnitSystem> get unitSystem async {
    return unitSystemFromWire(
      await repository.readString(SettingsRepository.keyUnitSystem),
    );
  }

  @override
  Future<void> setUnitSystem(UnitSystem value) =>
      repository.write(SettingsRepository.keyUnitSystem, value.wireValue);

  @override
  Future<CookingRhythm> get cookingRhythm async {
    return cookingRhythmFromWire(
      await repository.readString(SettingsRepository.keyCookingRhythm),
    );
  }

  @override
  Future<void> setCookingRhythm(CookingRhythm value) =>
      repository.write(SettingsRepository.keyCookingRhythm, value.wireValue);

  /// Fasting days the household observes, e.g. `ekadashi`, `ramadan`.
  @override
  Future<List<String>> get fastingDays =>
      repository.readStringList(SettingsRepository.keyFastingDays);

  @override
  Future<void> setFastingDays(List<String> value) =>
      repository.write(SettingsRepository.keyFastingDays, value);

  /// Which meal rhythm slots this household actually eats, by slot id.
  @override
  Future<List<String>> get enabledMealSlots =>
      repository.readStringList(SettingsRepository.keyMealSlots);

  @override
  Future<void> setEnabledMealSlots(List<String> value) =>
      repository.write(SettingsRepository.keyMealSlots, value);
}