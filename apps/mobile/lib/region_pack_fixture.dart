import 'package:flutter/material.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:siti_counter/data/region_pack_repository.dart';
import 'package:siti_counter/groceries/grocery_list_screen.dart';
import 'package:siti_counter/planner/monthly_planner_view.dart';
import 'package:siti_counter/planner/planner_models.dart';
import 'package:siti_counter/planner/planner_repository.dart';
import 'package:siti_counter/screens/seasonal_kitchen_screen.dart';

/// Fixtures for the screenshot harness.
///
/// The demo pack is deliberately a realistic size rather than three rows: reviewing a
/// three-item list says nothing about how a full pack behaves on screen.

const _allRitus = [
  'sharad',
  'bhadra',
  'ashwin',
  'kartik',
  'mangsir',
  'poush',
  'magh',
  'falgun',
  'chaitra',
  'baishakh',
  'jestha',
  'ashadh',
];

const _manifest = RegionPackManifest(
  id: 'nepal-bagmati',
  version: '1.0.0',
  name: 'Bagmati',
  country: 'Nepal',
  countryCode: 'NP',
  region: 'Bagmati',
  status: 'beta',
  elevationMeters: 1400,
  defaultLanguage: 'ne',
  calendar: 'bikram-sambat',
  seasonSystem: 'six-ritus',
);

RegionRecipe _recipe({
  required String id,
  required String en,
  required String ne,
  required String category,
  List<String> roles = const ['mainCourse'],
  List<String> times = const ['midday', 'evening', 'night'],
  List<String> ingredients = const [],
  int prep = 10,
  int cook = 25,
}) =>
    RegionRecipe(
      id: id,
      titleEn: en,
      titleNe: ne,
      category: category,
      cuisine: 'nepali',
      dietary: const ['vegetarian'],
      prepTimeMinutes: prep,
      cookTimeMinutes: cook,
      servings: 4,
      difficulty: 'easy',
      pressureCooker: const RecipeWhistleProfile(
        enabled: false,
        recommendedWhistles: 0,
        altitudeWhistleOffsetKathmandu: 0,
        heatLevel: 'low',
        releaseType: 'natural',
      ),
      ingredients: [
        for (final ingredientId in ingredients)
          RecipeIngredientItem(
            ingredientId: ingredientId,
            quantity: 1,
            unit: 'cup',
          ),
      ],
      steps: const [],
      seasonality: const ['sharad'],
      tags: const [],
      costEstimateNpr: 65,
      dishRoles: roles,
      mealTimes: times,
    );

final _recipes = <RegionRecipe>[
  _recipe(
    id: 'dal-bhat',
    en: 'Dal Bhat (Lentils with Rice)',
    ne: 'दाल भात',
    category: 'dal',
    ingredients: ['rice', 'dal', 'mustard', 'jimbu'],
    times: const ['morning', 'midday', 'evening', 'night'],
  ),
  _recipe(
    id: 'masu-bhat',
    en: 'Masu Bhat (Rice with Meat)',
    ne: 'मासु भात',
    category: 'masu',
    ingredients: ['rice', 'pork'],
    prep: 20,
    cook: 75,
  ),
  _recipe(
    id: 'tarkari',
    en: 'Mixed Vegetable Tarkari',
    ne: 'मिश्रित तरकारी',
    category: 'tarkari',
    ingredients: ['pumpkin', 'potato', 'cauliflower'],
    times: const ['morning', 'midday', 'evening', 'night'],
  ),
  _recipe(
    id: 'achar',
    en: 'Achar (Pickled Vegetables)',
    ne: 'अचार',
    category: 'achar',
    roles: const ['sideDish'],
    ingredients: ['mustard'],
    times: const ['morning', 'midday', 'evening', 'night'],
  ),
  _recipe(
    id: 'saag',
    en: 'Saag (Mustard Leaf Greens)',
    ne: 'साग',
    category: 'saag',
    ingredients: ['mustard', 'jimbu'],
    prep: 10,
    cook: 15,
  ),
  _recipe(
    id: 'momo',
    en: 'Momo (Steamed Dumplings)',
    ne: 'मःम',
    category: 'momo',
    ingredients: ['flour', 'pork'],
    prep: 40,
    cook: 20,
  ),
  _recipe(
    id: 'thukpa',
    en: 'Thukpa Noodle Soup',
    ne: 'थुक्पा',
    category: 'soup',
    ingredients: ['noodles', 'carrot'],
    prep: 15,
    cook: 35,
  ),
  _recipe(
    id: 'gundruk',
    en: 'Gundruk (Fermented Greens)',
    ne: 'गुन्द्रुक',
    category: 'achar',
    roles: const ['sideDish'],
    ingredients: ['mustard'],
    times: const ['morning', 'midday', 'evening', 'night'],
  ),
];

RegionIngredient _ingredient({
  required String id,
  required String en,
  required String ne,
  required AvailabilityLevel level,
}) =>
    RegionIngredient(
      id: id,
      nameEn: en,
      nameNe: ne,
      aliases: const [],
      category: 'vegetable',
      standardUnit: 'kg',
      marketPackageGrams: 1000,
      storageDays: 7,
      allergens: const [],
      availability: {for (final ritu in _allRitus) ritu: level.name},
    );

final _ingredients = <RegionIngredient>[
  _ingredient(id: 'rice', en: 'Rice', ne: 'चामल', level: AvailabilityLevel.peak),
  _ingredient(id: 'dal', en: 'Lentils', ne: 'दाल', level: AvailabilityLevel.available),
  _ingredient(id: 'mustard', en: 'Mustard Seed', ne: 'सरसौं', level: AvailabilityLevel.peak),
  _ingredient(id: 'jimbu', en: 'Dried Fern', ne: 'जिम्बु', level: AvailabilityLevel.peak),
  _ingredient(id: 'pumpkin', en: 'Pumpkin', ne: 'काक्रो', level: AvailabilityLevel.peak),
  _ingredient(id: 'potato', en: 'Potato', ne: 'आलु', level: AvailabilityLevel.peak),
  _ingredient(id: 'cauliflower', en: 'Cauliflower', ne: 'कोपला', level: AvailabilityLevel.inSeason),
  _ingredient(id: 'pork', en: 'Pork', ne: 'पसु मासु', level: AvailabilityLevel.available),
  _ingredient(id: 'flour', en: 'Flour', ne: 'पिठो', level: AvailabilityLevel.available),
  _ingredient(id: 'noodles', en: 'Noodles', ne: 'नूडल्स', level: AvailabilityLevel.outOfSeason),
  _ingredient(id: 'carrot', en: 'Carrot', ne: 'गाजर', level: AvailabilityLevel.peak),
];

RegionPack buildDemoRegionPack() => RegionPack(
  manifest: _manifest,
  seasonality: RegionSeasonality(
    regionId: 'nepal-bagmati',
    ritus: const [
      RituSeason(
        id: 'sharad',
        name: 'Sharad',
        monthsBS: ['Ashwin', 'Kartik'],
        monthsGregorian: ['Sep', 'Oct'],
        signatureProduce: ['pumpkin', 'cauliflower'],
      ),
      RituSeason(
        id: 'bhadra',
        name: 'Bhadra',
        monthsBS: ['Bhadra', 'Ashwin'],
        monthsGregorian: ['Aug', 'Sep'],
        signatureProduce: ['carrot'],
      ),
    ],
  ),
  ingredients: _ingredients,
  recipes: _recipes,
  festivals: const [],
  preservationSuggestions: const [
    PreservationSuggestion(
      id: 'dry-cauliflower',
      titleEn: 'Sun-dry cauliflower for achar',
      titleNe: 'अचारका लागि कोपला सुकाउने',
      descriptionEn: 'Peak-season cauliflower is at its best dried right now.',
      descriptionNe: 'सुकाउने समय कोपला उत्कृष्ट हुन्छ।',
      targetSeason: 'sharad',
      primaryIngredients: ['cauliflower'],
      method: 'sun-dry',
    ),
  ],
);

class SeasonalKitchenHarness extends StatelessWidget {
  final RegionPack pack;
  final String language;

  const SeasonalKitchenHarness({
    super.key,
    required this.pack,
    required this.language,
  });

  @override
  Widget build(BuildContext context) => SeasonalKitchenScreen(
    initialPack: pack,
    currentLanguage: language,
    initialRituId: 'sharad',
  );
}

/// Meals shared by the planner and grocery fixtures so both screens agree.
/// Meals shared by the planner and grocery fixtures so both screens agree.
///
/// `recipeId` values are real ids from [buildDemoRegionPack]; the grocery engine resolves
/// ingredients by recipe id, so ids that match nothing correctly produce an empty list.
final demoPlannedMeals = <PlannedMeal>[
  for (final entry in const {
    '2026-10-02': [
      ['momo', 'Momo', 'मःम'],
      ['dal-bhat', 'Dal Bhat', 'दाल भात'],
    ],
    '2026-10-04': [
      ['dal-bhat', 'Dal Bhat', 'दाल भात'],
      ['tarkari', 'Mixed Vegetable Tarkari', 'मिश्रित तरकारी'],
      ['momo', 'Momo', 'मःम'],
    ],
    '2026-10-06': [
      ['thukpa', 'Thukpa', 'थुक्पा'],
    ],
    '2026-10-09': [
      ['masu-bhat', 'Masu Bhat', 'मासु भात'],
      ['saag', 'Saag', 'साग'],
      ['gundruk', 'Gundruk', 'गुन्द्रुक'],
      ['achar', 'Achar', 'अचार'],
    ],
    '2026-10-14': [
      ['dal-bhat', 'Dal Bhat', 'दाल भात'],
      ['saag', 'Saag', 'साग'],
    ],
    '2026-10-18': [
      ['momo', 'Momo', 'मःम'],
      ['dal-bhat', 'Dal Bhat', 'दाल भात'],
    ],
    '2026-10-21': [
      ['thukpa', 'Thukpa', 'थुक्पा'],
      ['tarkari', 'Mixed Vegetable Tarkari', 'मिश्रित तरकारी'],
    ],
    '2026-10-25': [
      ['masu-bhat', 'Masu Bhat', 'मासु भात'],
    ],
    '2026-10-28': [
      ['dal-bhat', 'Dal Bhat', 'दाल भात'],
      ['tarkari', 'Mixed Vegetable Tarkari', 'मिश्रित तरकारी'],
      ['saag', 'Saag', 'साग'],
    ],
    '2026-10-30': [
      ['momo', 'Momo', 'मःम'],
    ],
  }.entries)
    for (var i = 0; i < entry.value.length; i++)
      PlannedMeal(
        id: '${entry.key}_$i',
        dateIso: entry.key,
        slotId: i == 0 ? 'breakfast' : (i == 1 ? 'lunch' : 'dinner'),
        recipeId: entry.value[i][0],
        recipeTitleEn: entry.value[i][1],
        recipeTitleNe: entry.value[i][2],
      ),
];

class MonthlyPlannerHarness extends StatelessWidget {
  final String language;

  const MonthlyPlannerHarness({super.key, required this.language});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: MonthlyPlannerView(
        month: DateTime(2026, 10, 1),
        meals: demoPlannedMeals,
        preferNepali: language == 'ne',
        slotsPerDay: 3,
      ),
    ),
  );
}

/// Wraps [GroceryListScreen] with a repository built by the caller.
///
/// The repository must be constructed by the test inside `tester.runAsync`: sqflite FFI does
/// real I/O, which never completes inside the fake-async zone and leaves the screen spinning
/// forever. Building it in `initState` here deadlocks.
class GroceryListHarness extends StatelessWidget {
  final String language;
  final WeeklyPlannerRepository repository;

  const GroceryListHarness({
    super.key,
    required this.language,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) => GroceryListScreen(
    weekStart: DateTime(2026, 10, 4),
    repository: repository,
    currentLanguage: language,
  );
}

/// Builds a repository seeded with the demo meals for the week the grocery screen reads.
Future<WeeklyPlannerRepository> buildSeededGroceryRepository() async {
  // Inject the demo pack. Without this the screen falls back to reading assets through
  // rootBundle, which never completes inside the test's fake-async zone and leaves the
  // screenshot showing nothing but a spinner.
  RegionPackRepository().setPack(buildDemoRegionPack());

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  await WeeklyPlannerRepository.createTables(db);
  final repo = WeeklyPlannerRepository(db);

  for (final meal in demoPlannedMeals) {
    if (meal.dateIso.compareTo('2026-10-04') < 0) continue;
    if (meal.dateIso.compareTo('2026-10-10') > 0) continue;
    await repo.savePlannedMeal(meal);
  }
  return repo;
}
