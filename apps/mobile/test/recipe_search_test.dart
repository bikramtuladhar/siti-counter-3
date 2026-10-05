import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

import 'package:siti_counter/planner/planner_models.dart';
import 'package:siti_counter/planner/recipe_picker_sheet.dart';
import 'package:siti_counter/widgets/recipe_search.dart';

RegionRecipe makeRecipe({
  required String id,
  required String titleEn,
  String titleNe = '',
  String category = 'main',
  String cuisine = 'nepali',
  List<String> tags = const [],
  List<String> dietary = const [],
  List<String> seasonality = const [],
  List<RecipeIngredientItem> ingredients = const [],
}) {
  return RegionRecipe(
    id: id,
    titleEn: titleEn,
    titleNe: titleNe,
    category: category,
    cuisine: cuisine,
    dietary: dietary,
    prepTimeMinutes: 10,
    cookTimeMinutes: 20,
    servings: 4,
    difficulty: 'easy',
    pressureCooker: const RecipeWhistleProfile(
      enabled: false,
      recommendedWhistles: 0,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'low',
      releaseType: 'quick',
    ),
    elevationBand: const RecipeElevationBand(
      testedElevationMeters: 1400,
      boilingPointCelsius: 95.3,
      waterMultiplier: 1.0,
    ),
    ingredients: ingredients,
    steps: const [],
    seasonality: seasonality,
    tags: tags,
    rating: 4.5,
    caloriesPerServing: 300,
    costEstimateNpr: 120,
  );
}

void main() {
  final catalogue = <RegionRecipe>[
    makeRecipe(id: 'dal-bhat', titleEn: 'Dal Bhat', titleNe: 'दाल भात'),
    makeRecipe(id: 'khichdi', titleEn: 'Khichdi', titleNe: 'खिचडी'),
    makeRecipe(
      id: 'aloo-tama',
      titleEn: 'Aloo Tama Tarkari',
      titleNe: 'आलु तामा तरकारी',
      category: 'vegetable',
      ingredients: [
        RecipeIngredientItem(ingredientId: 'potato', quantity: 2, unit: 'kg'),
        RecipeIngredientItem(ingredientId: 'cauliflower', quantity: 1, unit: 'pc'),
      ],
    ),
    makeRecipe(
      id: 'masala-dal',
      titleEn: 'Masala Dal',
      titleNe: 'मसला दाल',
      dietary: ['vegetarian'],
      tags: ['quick'],
    ),
  ];

  group('RecipeSearch.filter', () {
    test('an empty query returns everything', () {
      expect(RecipeSearch.filter(catalogue, '', preferNepali: false).length, 4);
      expect(RecipeSearch.filter(catalogue, '   ', preferNepali: false).length, 4);
    });

    test('matches the English title case-insensitively', () {
      final results = RecipeSearch.filter(catalogue, 'DAL BHAT', preferNepali: false);
      expect(results.map((r) => r.id), ['dal-bhat']);
    });

    test('matches the Nepali title even when the UI is in English', () {
      // A cook may know the Nepali name while reading the English interface.
      final results = RecipeSearch.filter(catalogue, 'खिचडी', preferNepali: false);
      expect(results.map((r) => r.id), ['khichdi']);
    });

    test('matches the Nepali title when the UI is in Nepali', () {
      final results = RecipeSearch.filter(catalogue, 'दाल', preferNepali: true);
      expect(results.map((r) => r.id), containsAll(['dal-bhat', 'masala-dal']));
    });

    test('matches on category, cuisine, tag and dietary fields', () {
      expect(
        RecipeSearch.filter(catalogue, 'vegetable', preferNepali: false)
            .map((r) => r.id),
        ['aloo-tama'],
      );
      expect(
        RecipeSearch.filter(catalogue, 'quick', preferNepali: false)
            .map((r) => r.id),
        ['masala-dal'],
      );
      expect(
        RecipeSearch.filter(catalogue, 'vegetarian', preferNepali: false)
            .map((r) => r.id),
        ['masala-dal'],
      );
    });

    test('matches on an ingredient, which is what a cook often recalls', () {
      expect(
        RecipeSearch.filter(catalogue, 'cauliflower', preferNepali: false)
            .map((r) => r.id),
        ['aloo-tama'],
      );
    });

    test('multiple terms narrow the result set rather than widening it', () {
      // "dal" alone matches two recipes; adding "masala" must leave one.
      expect(RecipeSearch.filter(catalogue, 'dal', preferNepali: false).length, 2);
      expect(
        RecipeSearch.filter(catalogue, 'dal masala', preferNepali: false)
            .map((r) => r.id),
        ['masala-dal'],
      );
    });

    test('no match returns an empty list rather than everything', () {
      expect(RecipeSearch.filter(catalogue, 'zzzz', preferNepali: false), isEmpty);
    });

    test('surrounding and repeated whitespace is ignored', () {
      expect(
        RecipeSearch.filter(catalogue, '  dal   bhat  ', preferNepali: false)
            .map((r) => r.id),
        ['dal-bhat'],
      );
    });

    test('preserves the original ordering', () {
      final results = RecipeSearch.filter(catalogue, 'dal', preferNepali: false);
      final originalOrder = catalogue
          .where((r) => r.id == 'dal-bhat' || r.id == 'masala-dal')
          .map((r) => r.id)
          .toList();
      expect(results.map((r) => r.id), originalOrder);
    });

    test('matches ignores whether the Nepali preference is set', () {
      // The same query must not depend on the interface language for its result set.
      expect(
        RecipeSearch.filter(catalogue, 'khichdi', preferNepali: true).length,
        RecipeSearch.filter(catalogue, 'khichdi', preferNepali: false).length,
      );
    });
  });

  group('RecipeSearchField', () {
    testWidgets('reports changes after the debounce interval', (tester) async {
      final reported = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeSearchField(
              preferNepali: false,
              debounceMilliseconds: 100,
              onChanged: reported.add,
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('recipe_search_field')), 'dal');
      // Not yet reported: the debounce has not elapsed.
      expect(reported, isEmpty);

      await tester.pump(const Duration(milliseconds: 150));
      expect(reported, ['dal']);
    });

    testWidgets('clearing applies immediately and shows a clear button', (
      tester,
    ) async {
      final reported = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeSearchField(
              preferNepali: false,
              debounceMilliseconds: 500,
              onChanged: reported.add,
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('recipe_search_field')), 'dal');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recipe_search_clear')), findsOneWidget);

      await tester.tap(find.byKey(const Key('recipe_search_clear')));
      await tester.pumpAndSettle();

      // Immediate, not after the 500ms debounce the user just set.
      expect(reported.last, '');
      expect(find.byKey(const Key('recipe_search_clear')), findsNothing);
    });

    testWidgets('uses Nepali hint text when preferred', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeSearchField(preferNepali: true, onChanged: (_) {}),
          ),
        ),
      );

      expect(find.textContaining('खोज्नुहोस्'), findsOneWidget);
    });
  });

  group('RecipeSearchEmpty', () {
    testWidgets('offers a way out when nothing matched', (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeSearchEmpty(
              query: 'zzz',
              preferNepali: false,
              onClear: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.textContaining('zzz'), findsOneWidget);
      await tester.tap(find.byKey(const Key('recipe_search_empty_clear')));
      expect(cleared, isTrue);
    });
  });

  group('RecipePickerSheet', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      List<RegionRecipe>? recipes,
      List<LeftoverItem> leftovers = const [],
      RegionRecipe? selected,
      LeftoverItem? usedLeftover,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipePickerSheet(
              recipes: recipes ?? catalogue,
              leftovers: leftovers,
              preferNepali: false,
              onSelectRecipe: (r) => selected = r,
              onUseLeftover: (l) => usedLeftover = l,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists every recipe before searching', (tester) async {
      await pumpSheet(tester);

      for (final recipe in catalogue) {
        expect(
          find.byKey(Key('recipe_picker_item_${recipe.id}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('narrowing the list reports the match count', (tester) async {
      await pumpSheet(tester);

      await tester.enterText(
        find.byKey(const Key('recipe_search_field')),
        'dal',
      );
      await tester.pumpAndSettle();

      expect(find.text('2 of 4 recipes'), findsOneWidget);
      expect(
        find.byKey(const Key('recipe_picker_item_dal-bhat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recipe_picker_item_khichdi')),
        findsNothing,
      );
    });

    testWidgets('shows an empty state with a clear action when nothing matches', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.enterText(
        find.byKey(const Key('recipe_search_field')),
        'zzzz',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recipe_picker_empty')), findsOneWidget);
      expect(find.byKey(const Key('recipe_picker_item_dal-bhat')), findsNothing);

      await tester.tap(find.byKey(const Key('recipe_search_empty_clear')));
      await tester.pumpAndSettle();

      // The full list comes back.
      expect(find.byKey(const Key('recipe_picker_empty')), findsNothing);
      expect(
        find.byKey(const Key('recipe_picker_item_dal-bhat')),
        findsOneWidget,
      );
    });

    testWidgets('tapping a recipe closes the sheet without throwing', (
      tester,
    ) async {
      await pumpSheet(tester, recipes: catalogue);

      await tester.tap(find.byKey(const Key('recipe_picker_item_khichdi')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The callback fires after the pop, so the tile is gone from the tree.
      expect(find.byKey(const Key('recipe_picker_item_khichdi')), findsNothing);
    });

    testWidgets('offers leftovers above the recipe list', (tester) async {
      await pumpSheet(
        tester,
        leftovers: [
          LeftoverItem(
            id: 'l1',
            recipeId: 'dal-bhat',
            titleEn: 'Dal Bhat',
            titleNe: 'दाल भात',
            servingsRemaining: 2,
            preparedDateIso: '2026-10-04',
            useByDateIso: '2026-10-06',
          ),
        ],
      );

      expect(find.byKey(const Key('leftover_option_l1')), findsOneWidget);
      expect(find.textContaining('Available Leftovers'), findsOneWidget);
    });

    testWidgets('a leftover can be converted into a recipe shape', (tester) async {
      final leftover = LeftoverItem(
        id: 'l1',
        recipeId: 'dal-bhat',
        titleEn: 'Dal Bhat',
        titleNe: 'दाल भात',
        servingsRemaining: 3,
        preparedDateIso: '2026-10-04',
        useByDateIso: '2026-10-06',
      );

      final recipe = RecipePickerSheet.leftoverAsRecipe(leftover);
      expect(recipe.id, 'dal-bhat');
      expect(recipe.servings, 3);
      expect(recipe.tags, contains('leftover'));
    });
  });
}
