import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:siti_counter/consumption/consumption_repository.dart';
import 'package:siti_counter/onboarding/onboarding_state.dart';
import 'package:siti_counter/settings/settings_repository.dart';
import 'package:siti_counter/settings/settings_service.dart';
import 'package:siti_counter/settings/setup_progress.dart';

/// In-memory [HouseholdSettings] for tests.
///
/// The real service is SQLite-backed, and sqflite's file I/O never completes inside
/// `testWidgets`' fake-async zone, so UI tests drive this instead. The SQLite implementation
/// is covered separately by the data-layer tests below.
/// In-memory [HouseholdSettings] for tests.
///
/// The real service is SQLite-backed, and sqflite's file I/O never completes inside
/// `testWidgets`' fake-async zone, so UI tests drive this instead. The SQLite implementation
/// is covered separately by the data-layer tests below.
///
/// Fields are the stored truth; the interface getters read them, so a test can seed state
/// by assignment and assert on it directly.
class FakeSettings implements HouseholdSettings {
  bool onboardingComplete = false;
  String languageCode = 'ne';
  String regionPack = 'nepal-bagmati';
  List<String> stoves = const ['lpg_gas'];
  double elevation = 1400;
  List<String> dietary = const [];
  bool guest = true;
  UnitSystem units = UnitSystem.metricWithTraditional;
  CookingRhythm rhythm = CookingRhythm.mostDays;
  List<String> fasting = const [];
  List<String> slots = const [];

  @override
  Future<bool> get isOnboardingComplete async => onboardingComplete;

  @override
  Future<void> setOnboardingComplete(bool value) async =>
      onboardingComplete = value;

  @override
  Future<String> get language async => languageCode;

  @override
  Future<void> setLanguage(String code) async => languageCode = code;

  @override
  Future<String> get regionPackId async => regionPack;

  @override
  Future<List<String>> get stoveTypes async => stoves;

  @override
  Future<double> get elevationMeters async => elevation;

  @override
  Future<List<String>> get dietaryRules async => dietary;

  @override
  Future<bool> get isGuest async => guest;

  @override
  Future<UnitSystem> get unitSystem async => units;

  @override
  Future<void> setUnitSystem(UnitSystem value) async => units = value;

  @override
  Future<CookingRhythm> get cookingRhythm async => rhythm;

  @override
  Future<void> setCookingRhythm(CookingRhythm value) async => rhythm = value;

  @override
  Future<List<String>> get fastingDays async => fasting;

  @override
  Future<void> setFastingDays(List<String> value) async => fasting = value;

  @override
  Future<List<String>> get enabledMealSlots async => slots;

  @override
  Future<void> setEnabledMealSlots(List<String> value) async =>
      slots = value;

  @override
  Future<void> saveOnboardingPreferences(OnboardingPreferences prefs) async {
    languageCode = prefs.language;
    regionPack = prefs.regionPackId;
    stoves = List.of(prefs.stoveTypes);
    elevation = prefs.elevationMeters;
    dietary = List.of(prefs.dietaryRules);
    guest = prefs.isGuest;
    onboardingComplete = true;
  }

  @override
  Future<OnboardingPreferences> loadPreferences({
    int adultsCount = 1,
    int childrenCount = 0,
    int eldersCount = 0,
  }) async {
    return OnboardingPreferences(
      language: languageCode,
      regionPackId: regionPack,
      stoveTypes: stoves,
      elevationMeters: elevation,
      dietaryRules: dietary,
      isGuest: guest,
      adultsCount: adultsCount,
      childrenCount: childrenCount,
      eldersCount: eldersCount,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late List<Directory> tempDirs;

  /// A unique on-disk database per test.
  ///
  /// `inMemoryDatabasePath` is one shared database under the ffi factory, so tests leak
  /// state into each other and concurrent opens can deadlock.
  Future<String> freshDbPath(String name) async {
    final dir = Directory.systemTemp.createTempSync('siti_settings_test');
    tempDirs.add(dir);
    return '${dir.path}/$name.db';
  }

  Future<SettingsService> makeSettings({String name = 'settings'}) async {
    final db = await databaseFactoryFfi.openDatabase(await freshDbPath(name));
    await SettingsRepository.createTables(db);
    return SettingsService(SettingsRepository(db));
  }

  Future<ConsumptionRepository> makeConsumption() async {
    final db = await databaseFactoryFfi.openDatabase(await freshDbPath('consumption'));
    await ConsumptionRepository.createTables(db);
    return ConsumptionRepository(db);
  }

  setUp(() => tempDirs = []);

  tearDown(() {
    for (final dir in tempDirs) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Best effort cleanup.
      }
    }
  });

  group('Settings persistence (SQLite)', () {
    test('reports onboarding incomplete until it is saved', () async {
      final settings = await makeSettings();
      expect(await settings.isOnboardingComplete, isFalse);

      await settings.saveOnboardingPreferences(
        OnboardingPreferences(
          language: 'en',
          stoveTypes: ['lpg_gas', 'induction'],
        ),
      );

      expect(await settings.isOnboardingComplete, isTrue);
      expect(await settings.language, 'en');
      expect(await settings.stoveTypes, ['lpg_gas', 'induction']);
    });

    test('multi-select stoves and dietary rules survive a round trip', () async {
      final settings = await makeSettings();
      await settings.saveOnboardingPreferences(
        OnboardingPreferences(
          stoveTypes: ['biomass_wood', 'induction'],
          dietaryRules: ['strict_vegetarian', 'no_onion_garlic'],
        ),
      );

      final prefs = await settings.loadPreferences();
      expect(prefs.stoveTypes, ['biomass_wood', 'induction']);
      expect(await settings.dietaryRules, [
        'strict_vegetarian',
        'no_onion_garlic',
      ]);
    });

    test('defaults are sensible when nothing is stored', () async {
      final settings = await makeSettings();
      final prefs = await settings.loadPreferences();

      expect(prefs.language, 'ne');
      expect(prefs.regionPackId, 'nepal-bagmati');
      expect(prefs.stoveTypes, ['lpg_gas']);
      expect(prefs.elevationMeters, 1400);
      expect(prefs.isGuest, isTrue);
    });

    test('language changes independently and does not complete onboarding', () async {
      final settings = await makeSettings();
      await settings.setLanguage('en');

      expect(await settings.language, 'en');
      expect(await settings.isOnboardingComplete, isFalse);
    });

    test('a null value reads as the default rather than throwing', () async {
      final settings = await makeSettings();
      await settings.repository.write('language', null);
      expect(await settings.language, 'ne');
    });

    test('extended setup values round-trip', () async {
      final settings = await makeSettings();
      expect(await settings.cookingRhythm, CookingRhythm.mostDays);
      expect(await settings.unitSystem, UnitSystem.metricWithTraditional);

      await settings.setCookingRhythm(CookingRhythm.daily);
      await settings.setUnitSystem(UnitSystem.imperial);
      await settings.setFastingDays(['ekadashi', 'ramadan']);
      await settings.setEnabledMealSlots(['breakfast', 'dinner']);

      expect(await settings.cookingRhythm, CookingRhythm.daily);
      expect(await settings.unitSystem, UnitSystem.imperial);
      expect(await settings.fastingDays, ['ekadashi', 'ramadan']);
      expect(await settings.enabledMealSlots, ['breakfast', 'dinner']);
    });

    test('wire parsing falls back for unknown values', () {
      expect(cookingRhythmFromWire('nonsense'), CookingRhythm.mostDays);
      expect(cookingRhythmFromWire(null), CookingRhythm.mostDays);
      expect(cookingRhythmFromWire('daily'), CookingRhythm.daily);
      expect(unitSystemFromWire('nonsense'), UnitSystem.metricWithTraditional);
      expect(unitSystemFromWire('imperial'), UnitSystem.imperial);
    });
  });

  group('Member allergies (SQLite)', () {
    late ConsumptionRepository consumption;

    setUp(() async => consumption = await makeConsumption());

    test('allergens are recorded per member', () async {
      final member = await consumption.addMember(
        name: 'Aayush',
        role: 'Child',
        allergies: ['peanut', 'mustard'],
      );

      expect((await consumption.getMemberAllergies(member.memberId)).toSet(), {
        'peanut',
        'mustard',
      });
    });

    test('the household allergen set unions every member', () async {
      await consumption.addMember(name: 'A', allergies: ['peanut']);
      await consumption.addMember(name: 'B', allergies: ['mustard', 'peanut']);

      expect(await consumption.getHouseholdAllergens(), {'peanut', 'mustard'});
    });

    test('setting allergies replaces rather than appends', () async {
      final member = await consumption.addMember(
        name: 'A',
        allergies: ['peanut'],
      );
      await consumption.setMemberAllergies(member.memberId, ['dairy']);

      expect(await consumption.getMemberAllergies(member.memberId), {'dairy'});
    });

    test('a member with no allergens records none', () async {
      final member = await consumption.addMember(name: 'B');
      expect(await consumption.getMemberAllergies(member.memberId), isEmpty);
    });

    test('calibrated vessel count reflects saved calibrations', () async {
      expect(await consumption.countCalibratedVessels(), 0);

      await consumption.saveVesselCalibration('katori', 350);
      expect(await consumption.countCalibratedVessels(), 1);
    });
  });

  group('deriveSetupProgress', () {
    test('nothing configured leaves every task outstanding', () {
      final progress = deriveSetupProgress(const SetupInputs());

      expect(progress.total, 4);
      expect(progress.completed, 0);
      expect(progress.remainingIds, SetupTaskIds.all);
      expect(progress.isComplete, isFalse);
      expect(progress.fraction, 0);
    });

    test('each fact completes its own task', () {
      expect(
        deriveSetupProgress(
          const SetupInputs(enabledMealSlots: ['dinner']),
        ).completedIds,
        contains(SetupTaskIds.mealRhythm),
      );
      expect(
        deriveSetupProgress(
          const SetupInputs(calibratedVesselCount: 1),
        ).completedIds,
        contains(SetupTaskIds.units),
      );
      expect(
        deriveSetupProgress(const SetupInputs(memberCount: 2)).completedIds,
        contains(SetupTaskIds.members),
      );
    });

    test('a non-default cooking rhythm or any fasting day completes that task', () {
      expect(
        deriveSetupProgress(
          const SetupInputs(cookingRhythm: CookingRhythm.daily),
        ).completedIds,
        contains(SetupTaskIds.cookingRhythm),
      );
      expect(
        deriveSetupProgress(
          const SetupInputs(fastingDays: ['ekadashi']),
        ).completedIds,
        contains(SetupTaskIds.cookingRhythm),
      );
      // mostDays with no fasting is the untouched default, so it is not "configured".
      expect(
        deriveSetupProgress(
          const SetupInputs(cookingRhythm: CookingRhythm.mostDays),
        ).completedIds,
        isNot(contains(SetupTaskIds.cookingRhythm)),
      );
    });

    test('a fully configured household reports complete', () {
      final progress = deriveSetupProgress(
        const SetupInputs(
          enabledMealSlots: ['breakfast', 'dinner'],
          calibratedVesselCount: 2,
          memberCount: 4,
          cookingRhythm: CookingRhythm.daily,
        ),
      );

      expect(progress.isComplete, isTrue);
      expect(progress.fraction, 1);
      expect(progress.remainingIds, isEmpty);
    });
  });

  group('loadSetupProgress', () {
    test('degrades to all-outstanding when a source throws', () async {
      final settings = FakeSettings();

      final progress = await loadSetupProgress(
        settings: settings,
        memberCount: () async => throw StateError('db gone'),
        calibratedVesselCount: () async => throw StateError('db gone'),
      );

      expect(progress.completed, 0);
      expect(progress.remainingIds, SetupTaskIds.all);
    });

    test('reads facts from the settings store', () async {
      final settings = FakeSettings()
        ..slots = ['lunch']
        ..rhythm = CookingRhythm.festivalsOnly;

      final progress = await loadSetupProgress(
        settings: settings,
        memberCount: () async => 3,
        calibratedVesselCount: () async => 0,
      );

      expect(progress.completed, 3);
      expect(progress.remainingIds, [SetupTaskIds.units]);
    });
  });

  group('FakeSettings behaves like the interface', () {
    test('round-trips onboarding preferences', () async {
      final fake = FakeSettings();
      await fake.saveOnboardingPreferences(
        OnboardingPreferences(language: 'en', stoveTypes: ['induction']),
      );

      expect(fake.onboardingComplete, isTrue);
      final prefs = await fake.loadPreferences();
      expect(prefs.language, 'en');
      expect(prefs.stoveTypes, ['induction']);
    });
  });
}