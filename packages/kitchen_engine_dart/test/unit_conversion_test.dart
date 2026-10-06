import 'package:test/test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

void main() {
  group('quantityToGrams', () {
    test('grams pass through unchanged', () {
      expect(quantityToGrams(200, 'g'), 200);
      expect(quantityToGrams(200, 'grams'), 200);
      expect(quantityToGrams(200, 'GM'), 200);
    });

    test('kilograms are scaled', () {
      // The bug this exists for: a `1 kg` line used to ask for one gram.
      expect(quantityToGrams(1, 'kg'), 1000);
      expect(quantityToGrams(1.5, 'kg'), 1500);
    });

    test('milligrams and litres', () {
      expect(quantityToGrams(500, 'mg'), 0.5);
      expect(quantityToGrams(1.5, 'l'), 1500);
    });

    test('imperial measures', () {
      expect(quantityToGrams(1, 'oz'), closeTo(28.3495, 0.001));
      expect(quantityToGrams(1, 'lb'), closeTo(453.592, 0.001));
    });

    test('spoons and cups', () {
      expect(quantityToGrams(2, 'tbsp'), 30);
      expect(quantityToGrams(1, 'tsp'), 5);
      expect(quantityToGrams(1, 'cup'), 240);
    });

    test('Nepali kitchen units', () {
      expect(quantityToGrams(1, 'tola'), closeTo(11.66, 0.001));
      expect(quantityToGrams(1, 'bhat'), 300);
      expect(quantityToGrams(1, 'katori'), 150);
    });

    test('an unknown unit is treated as grams, matching the packs here', () {
      expect(quantityToGrams(120, 'furlongs'), 120);
      expect(isKnownUnit('furlongs'), isFalse);
      expect(isKnownUnit('kg'), isTrue);
    });

    test('an empty unit is treated as grams', () {
      expect(quantityToGrams(50, ''), 50);
      expect(isKnownUnit(''), isFalse);
    });

    test('whitespace and case in the unit are tolerated', () {
      expect(quantityToGrams(1, ' KG '), 1000);
    });
  });

  group('grocery engine honours the unit', () {
    RegionRecipe recipeWith({required double quantity, required String unit}) =>
        RegionRecipe(
          id: 'r1',
          titleEn: 'Rice',
          titleNe: 'चामल',
          category: 'bhat',
          cuisine: 'nepali',
          dietary: const [],
          prepTimeMinutes: 10,
          cookTimeMinutes: 20,
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
            RecipeIngredientItem(ingredientId: 'rice', quantity: quantity, unit: unit),
          ],
          steps: const [],
          seasonality: const [],
          tags: const [],
        );

    RegionIngredient riceIngredient() => const RegionIngredient(
      id: 'rice',
      nameEn: 'Rice',
      nameNe: 'चामल',
      aliases: [],
      category: 'grain',
      standardUnit: 'kg',
      marketPackageGrams: 1000,
      storageDays: 300,
      allergens: [],
      availability: {},
    );

    test('a kilogram quantity is requested as a kilogram, not a gram', () {
      final result = generateGroceryListFromRegion(
        meals: [
          GroceryPlanMealInput(
            recipeId: 'r1',
            servings: 4,
            recipeTitleEn: 'Rice',
            recipeTitleNe: 'चामल',
            dateIso: '2026-10-04',
            slotId: 'lunch',
          ),
        ],
        recipes: [recipeWith(quantity: 1, unit: 'kg')],
        ingredients: [riceIngredient()],
        pantryAvailableGrams: const {},
        marketPrices: const {},
      );

      expect(result.items.single.totalRequiredGrams, 1000);
    });

    test('the same quantity in grams gives the same total', () {
      final result = generateGroceryListFromRegion(
        meals: [
          GroceryPlanMealInput(
            recipeId: 'r1',
            servings: 4,
            recipeTitleEn: 'Rice',
            recipeTitleNe: 'चामल',
            dateIso: '2026-10-04',
            slotId: 'lunch',
          ),
        ],
        recipes: [recipeWith(quantity: 1000, unit: 'g')],
        ingredients: [riceIngredient()],
        pantryAvailableGrams: const {},
        marketPrices: const {},
      );

      expect(result.items.single.totalRequiredGrams, 1000);
    });

    test('servings still scale a converted quantity', () {
      // 1 kg at 4 servings doubled to 8 must be 2 kg.
      final result = generateGroceryListFromRegion(
        meals: [
          GroceryPlanMealInput(
            recipeId: 'r1',
            servings: 8,
            recipeTitleEn: 'Rice',
            recipeTitleNe: 'चामल',
            dateIso: '2026-10-04',
            slotId: 'lunch',
          ),
        ],
        recipes: [recipeWith(quantity: 1, unit: 'kg')],
        ingredients: [riceIngredient()],
        pantryAvailableGrams: const {},
        marketPrices: const {},
      );

      expect(result.items.single.totalRequiredGrams, 2000);
    });
  });
}