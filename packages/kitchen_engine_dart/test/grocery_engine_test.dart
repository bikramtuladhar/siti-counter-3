import 'dart:convert';
import 'dart:io';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:test/test.dart';

void main() {
  group('GroceryEngine: Stall Resolution', () {
    test('resolves wet market stalls from categories accurately', () {
      expect(resolveMarketStall('vegetables'), equals(MarketStall.vegetables));
      expect(resolveMarketStall('greens'), equals(MarketStall.vegetables));
      expect(resolveMarketStall('fermented'), equals(MarketStall.vegetables));

      expect(resolveMarketStall('fruits'), equals(MarketStall.fruit));
      expect(resolveMarketStall('fruit'), equals(MarketStall.fruit));

      expect(resolveMarketStall('meat'), equals(MarketStall.meatFish));
      expect(resolveMarketStall('fish'), equals(MarketStall.meatFish));

      expect(resolveMarketStall('spices'), equals(MarketStall.spices));
      expect(resolveMarketStall('aromatics'), equals(MarketStall.spices));
      expect(resolveMarketStall('seeds'), equals(MarketStall.spices));

      expect(resolveMarketStall('grains'), equals(MarketStall.grainsStaples));
      expect(resolveMarketStall('pulses'), equals(MarketStall.grainsStaples));
      expect(resolveMarketStall('flour'), equals(MarketStall.grainsStaples));
      expect(resolveMarketStall('oils'), equals(MarketStall.grainsStaples));
      expect(resolveMarketStall('dairy'), equals(MarketStall.grainsStaples));
      expect(resolveMarketStall('sweeteners'), equals(MarketStall.grainsStaples));
      expect(resolveMarketStall(null), equals(MarketStall.grainsStaples));
      expect(resolveMarketStall('unknown'), equals(MarketStall.grainsStaples));
    });

    test('verifies stall metadata properties', () {
      expect(MarketStall.vegetables.id, equals('vegetables'));
      expect(MarketStall.vegetables.icon, equals('🥕'));
      expect(MarketStall.fruit.icon, equals('🍎'));
      expect(MarketStall.meatFish.icon, equals('🍗'));
      expect(MarketStall.spices.icon, equals('🌶️'));
      expect(MarketStall.grainsStaples.icon, equals('🌾'));

      expect(MarketStall.vegetables.nameEn, equals('Vegetables'));
      expect(MarketStall.vegetables.nameNe, contains('तरकारी'));
      expect(MarketStall.spices.nameNe, contains('मसला'));
      expect(MarketStall.grainsStaples.nameNe, contains('खाद्यान्न'));
    });
  });

  group('GroceryEngine: Vendor Unit Formatting', () {
    test('formats pau units correctly in English and Devanagari', () {
      // 1 pau (250g)
      expect(
        formatVendorQuantity(
          totalGrams: 250,
          standardUnit: 'pau',
          marketPackageGrams: 250,
          packagesToBuy: 1,
          preferNepali: false,
        ),
        equals('1 pau (250 g)'),
      );
      expect(
        formatVendorQuantity(
          totalGrams: 250,
          standardUnit: 'pau',
          marketPackageGrams: 250,
          packagesToBuy: 1,
          preferNepali: true,
        ),
        equals('१ पाउ (२५० ग्राम)'),
      );

      // 4 pau = 1 kg (1000g)
      expect(
        formatVendorQuantity(
          totalGrams: 1000,
          standardUnit: 'pau',
          marketPackageGrams: 250,
          packagesToBuy: 4,
          preferNepali: false,
        ),
        equals('1 kg (4 pau)'),
      );
      expect(
        formatVendorQuantity(
          totalGrams: 1000,
          standardUnit: 'pau',
          marketPackageGrams: 250,
          packagesToBuy: 4,
          preferNepali: true,
        ),
        equals('१ के.जी. (४ पाउ)'),
      );
    });

    test('formats kg units correctly', () {
      expect(
        formatVendorQuantity(
          totalGrams: 2000,
          standardUnit: 'kg',
          marketPackageGrams: 1000,
          packagesToBuy: 2,
          preferNepali: false,
        ),
        equals('2 kg'),
      );
      expect(
        formatVendorQuantity(
          totalGrams: 2000,
          standardUnit: 'kg',
          marketPackageGrams: 1000,
          packagesToBuy: 2,
          preferNepali: true,
        ),
        equals('२ के.जी.'),
      );
    });

    test('formats mana units (grains/pulses) correctly', () {
      expect(
        formatVendorQuantity(
          totalGrams: 800,
          standardUnit: 'mana',
          marketPackageGrams: 400,
          packagesToBuy: 2,
          preferNepali: false,
        ),
        equals('2 mana (800 g)'),
      );
      expect(
        formatVendorQuantity(
          totalGrams: 800,
          standardUnit: 'mana',
          marketPackageGrams: 400,
          packagesToBuy: 2,
          preferNepali: true,
        ),
        equals('२ माना (८०० ग्राम)'),
      );
    });

    test('formats bunch / muthi units correctly', () {
      expect(
        formatVendorQuantity(
          totalGrams: 250,
          standardUnit: 'bunch',
          marketPackageGrams: 250,
          packagesToBuy: 1,
          preferNepali: false,
        ),
        equals('1 bunch (250 g)'),
      );
      expect(
        formatVendorQuantity(
          totalGrams: 500,
          standardUnit: 'muthi',
          marketPackageGrams: 250,
          packagesToBuy: 2,
          preferNepali: false,
        ),
        equals('2 bunches (500 g)'),
      );
      expect(
        formatVendorQuantity(
          totalGrams: 500,
          standardUnit: 'muthi',
          marketPackageGrams: 250,
          packagesToBuy: 2,
          preferNepali: true,
        ),
        equals('२ मुठा (५०० ग्राम)'),
      );
    });

    test('formats piece, packet, and liter units', () {
      expect(
        formatVendorQuantity(
          totalGrams: 1600,
          standardUnit: 'piece',
          marketPackageGrams: 800,
          packagesToBuy: 2,
          preferNepali: false,
        ),
        equals('2 pieces (1600 g)'),
      );
      expect(
        formatVendorQuantity(
          totalGrams: 1600,
          standardUnit: 'piece',
          marketPackageGrams: 800,
          packagesToBuy: 2,
          preferNepali: true,
        ),
        equals('२ वटा (१६०० ग्राम)'),
      );

      expect(
        formatVendorQuantity(
          totalGrams: 200,
          standardUnit: 'packet',
          marketPackageGrams: 200,
          packagesToBuy: 1,
          preferNepali: false,
        ),
        equals('1 packet (200 g)'),
      );
      expect(
        formatVendorQuantity(
          totalGrams: 200,
          standardUnit: 'packet',
          marketPackageGrams: 200,
          packagesToBuy: 1,
          preferNepali: true,
        ),
        equals('१ प्याकेट (२०० ग्राम)'),
      );

      expect(
        formatVendorQuantity(
          totalGrams: 910,
          standardUnit: 'l',
          marketPackageGrams: 910,
          packagesToBuy: 1,
          preferNepali: false,
        ),
        equals('1 L'),
      );
      expect(
        formatVendorQuantity(
          totalGrams: 910,
          standardUnit: 'l',
          marketPackageGrams: 910,
          packagesToBuy: 1,
          preferNepali: true,
        ),
        equals('१ लिटर'),
      );
    });
  });

  group('GroceryEngine: Generation from Planned Meals', () {
    late List<RegionRecipe> recipes;
    late List<RegionIngredient> ingredients;

    setUpAll(() {
      final recipesJson = File('../../packages/region-packs/nepal-bagmati/recipes.json')
          .readAsStringSync();
      final ingredientsJson = File('../../packages/region-packs/nepal-bagmati/ingredients.json')
          .readAsStringSync();

      recipes = (jsonDecode(recipesJson) as List)
          .map((r) => RegionRecipe.fromJson(r as Map<String, dynamic>))
          .toList();
      ingredients = (jsonDecode(ingredientsJson) as List)
          .map((i) => RegionIngredient.fromJson(i as Map<String, dynamic>))
          .toList();
    });

    test('aggregates ingredients across multiple planned meals for a week', () {
      final meals = [
        const GroceryPlanMealInput(recipeId: 'aloo-gobi-tarkari', servings: 4),
        const GroceryPlanMealInput(recipeId: 'aloo-tama-bodi', servings: 4),
        const GroceryPlanMealInput(recipeId: 'kalo-dal-jimbu', servings: 4),
      ];

      final result = generateGroceryListFromRegion(
        meals: meals,
        recipes: recipes,
        ingredients: ingredients,
      );

      expect(result.totalItems, greaterThan(0));
      expect(result.stalls.isNotEmpty, isTrue);

      // Potato is used in aloo-gobi-tarkari and aloo-tama-bodi
      final potato = result.items.firstWhere((i) => i.ingredientId == 'potato');
      expect(potato.usedByRecipeIds.length, equals(2));
      expect(potato.stall, equals(MarketStall.vegetables));
      expect(potato.totalRequiredGrams, greaterThan(0));
      expect(potato.packagesToBuy, greaterThan(0));
      expect(potato.isSufficientInPantry, isFalse);
    });

    test('subtracts pantry quantities and marks sufficient items', () {
      final meals = [
        const GroceryPlanMealInput(recipeId: 'kalo-dal-jimbu', servings: 4),
      ];

      // kalo-dal-jimbu uses kalo_dal, ghee, jimbu, garlic, ginger, turmeric
      // Suppose we have plenty of kalo_dal (1000g) and ghee (500g) in pantry
      final pantry = {
        'kalo_dal': 1000.0,
        'ghee': 500.0,
      };

      final result = generateGroceryListFromRegion(
        meals: meals,
        recipes: recipes,
        ingredients: ingredients,
        pantryAvailableGrams: pantry,
      );

      final kaloDalItem = result.items.firstWhere((i) => i.ingredientId == 'kalo_dal');
      expect(kaloDalItem.isSufficientInPantry, isTrue);
      expect(kaloDalItem.netNeededGrams, equals(0.0));
      expect(kaloDalItem.packagesToBuy, equals(0));

      final gheeItem = result.items.firstWhere((i) => i.ingredientId == 'ghee');
      expect(gheeItem.isSufficientInPantry, isTrue);
      expect(gheeItem.packagesToBuy, equals(0));

      // Items not in pantry require purchase
      final jimbuItem = result.items.firstWhere((i) => i.ingredientId == 'jimbu');
      expect(jimbuItem.isSufficientInPantry, isFalse);
      expect(jimbuItem.packagesToBuy, greaterThan(0));

      expect(result.totalPantryCoveredItems, greaterThanOrEqualTo(2));
    });

    test('orders stalls in standard Haat Bazaar walking order', () {
      final meals = [
        const GroceryPlanMealInput(recipeId: 'khasiko-masu-jhol', servings: 4), // meat (goat_meat)
        const GroceryPlanMealInput(recipeId: 'aloo-gobi-tarkari', servings: 4), // veg + spices
        const GroceryPlanMealInput(recipeId: 'kalo-dal-jimbu', servings: 4), // grains/pulses (kalo_dal)
      ];

      final result = generateGroceryListFromRegion(
        meals: meals,
        recipes: recipes,
        ingredients: ingredients,
      );

      final stallIds = result.stalls.map((s) => s.stall.id).toList();
      // Walking order: vegetables -> fruit -> meat_fish -> spices -> grains_staples
      final vegIdx = stallIds.indexOf('vegetables');
      final meatIdx = stallIds.indexOf('meat_fish');
      final spiceIdx = stallIds.indexOf('spices');
      final grainsIdx = stallIds.indexOf('grains_staples');

      expect(vegIdx, isNot(equals(-1)));
      expect(meatIdx, isNot(equals(-1)));
      expect(spiceIdx, isNot(equals(-1)));
      expect(grainsIdx, isNot(equals(-1)));

      expect(vegIdx, lessThan(meatIdx));
      expect(meatIdx, lessThan(spiceIdx));
      expect(spiceIdx, lessThan(grainsIdx));
    });

    test('calculates surplus and generates surplus recommendations', () {
      // aloo-gobi-tarkari needs 200g tomatoes, market package is 250g -> buy 1 pkg (250g) -> 50g surplus
      // if 2 servings x 4 = 8 servings -> 400g needed -> 2 packages (500g) -> 100g surplus
      // or 6 servings -> 300g needed -> 2 packages (500g) -> 200g surplus -> triggers surplus suggestion!
      final meals = [
        const GroceryPlanMealInput(recipeId: 'aloo-gobi-tarkari', servings: 6),
      ];

      final result = generateGroceryListFromRegion(
        meals: meals,
        recipes: recipes,
        ingredients: ingredients,
      );

      final tomato = result.items.firstWhere((i) => i.ingredientId == 'tomato');
      expect(tomato.surplusGrams, greaterThanOrEqualTo(150));
      expect(tomato.surplusSuggestionEn, isNotNull);
      expect(tomato.surplusSuggestionEn, contains('tomato achar'));
    });

    test('exports clean localized plain text for WhatsApp, Viber, or SMS', () {
      final meals = [
        const GroceryPlanMealInput(recipeId: 'aloo-gobi-tarkari', servings: 4),
        const GroceryPlanMealInput(recipeId: 'kalo-dal-jimbu', servings: 4),
      ];

      final pantry = {
        'kalo_dal': 500.0,
      };

      final result = generateGroceryListFromRegion(
        meals: meals,
        recipes: recipes,
        ingredients: ingredients,
        pantryAvailableGrams: pantry,
      );

      // Export in Nepali
      final textNe = exportGroceryListText(result, preferNepali: true);
      expect(textNe, contains('🛒 सिटि काउन्टर - हप्ताको किनमेल सूची'));
      expect(textNe, contains('तरकारी गल्ली'));
      expect(textNe, contains('आलु'));
      expect(textNe, contains('पाउ'));
      expect(textNe, contains('सिटि काउन्टर ३.०'));
      // Kalo dal is fully in pantry, so by default excluded from purchase export
      expect(textNe, isNot(contains('कालो दाल')));

      // Export in English including pantry items
      final textEn = exportGroceryListText(result, preferNepali: false, includePantryCovered: true);
      expect(textEn, contains('🛒 Siti Counter - Weekly Grocery List'));
      expect(textEn, contains('Potato'));
      expect(textEn, contains('[✓] Black Urad Lentils'));
      expect(textEn, contains('Generated by Siti Counter 3.0'));
    });

    test('enriches grocery list with normalized market prices and flags budget heroes', () {
      final meals = [
        const GroceryPlanMealInput(recipeId: 'aloo-gobi-tarkari', servings: 4),
      ];

      final marketPrices = {
        'potato': const CommodityMarketPriceInfo(avgPrice: 60, priceTrend: 'rising'),
        'cauliflower': const CommodityMarketPriceInfo(avgPrice: 40, priceTrend: 'falling'),
        'tomato': const CommodityMarketPriceInfo(avgPrice: 70, priceTrend: 'stable'),
      };

      final result = generateGroceryListFromRegion(
        meals: meals,
        recipes: recipes,
        ingredients: ingredients,
        marketPrices: marketPrices,
      );

      expect(result.totalEstimatedCostNpr, isNotNull);
      expect(result.totalEstimatedCostNpr!, greaterThan(0));
      expect(result.budgetHeroCount, greaterThanOrEqualTo(1));

      final potato = result.items.firstWhere((i) => i.ingredientId == 'potato');
      expect(potato.pricePerUnitNpr, equals(60));
      expect(potato.priceTrend, equals('rising'));
      expect(potato.estimatedPriceNpr, isNotNull);

      final cauliflower = result.items.firstWhere((i) => i.ingredientId == 'cauliflower');
      expect(cauliflower.isBudgetHero, isTrue);
      expect(cauliflower.priceTrend, equals('falling'));
    });
  });
}

