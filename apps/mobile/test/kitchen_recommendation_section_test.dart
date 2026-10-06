import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/kitchen/kitchen_recommendation_section.dart';

RegionRecipe recipe(
  String id,
  String title, {
  List<String> roles = const ['mainCourse'],
  List<String> times = const ['midday', 'evening', 'night'],
  List<String> ingredients = const ['rice'],
  List<String> rituIds = const ['sharad'],
  String category = 'main',
}) => RegionRecipe(
  id: id,
  titleEn: title,
  titleNe: title,
  category: category,
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
    for (final name in ingredients)
      RecipeIngredientItem(ingredientId: name, quantity: 1, unit: 'cup'),
  ],
  steps: const [],
  seasonality: rituIds,
  tags: const [],
  dishRoles: roles,
  mealTimes: times,
);

RegionPack packOf(List<RegionRecipe> recipes) => RegionPack(
  manifest: const RegionPackManifest(
    id: 'test',
    version: '1.0.0',
    name: 'Test',
    country: 'Nepal',
    countryCode: 'NP',
    region: 'Bagmati',
    status: 'active',
    elevationMeters: 1400,
    defaultLanguage: 'ne',
    calendar: 'bikram-sambat',
    seasonSystem: 'nepali',
  ),
  seasonality: const RegionSeasonality(regionId: 'test', ritus: []),
  ingredients: const [],
  recipes: recipes,
  festivals: const [],
);

Widget host(
  RegionPack pack, {
  Set<String> excluded = const {},
  void Function(RegionRecipe)? onSelected,
}) =>
    MaterialApp(
      home: Scaffold(
        body: KitchenRecommendationSection(
          pack: pack,
          preferNepali: false,
          rituId: 'sharad',
          excludedIngredientIds: excluded,
          onRecipeSelected: onSelected ?? (_) {},
        ),
      ),
    );

void main() {
  group('KitchenRecommendationSection', () {
    testWidgets('offers a time chip per meal time', (tester) async {
      await tester.pumpWidget(host(packOf([recipe('r1', 'Dal bhat')])));

      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Midday'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);
    });

    testWidgets('never offers a side-dish-only dish as a meal', (tester) async {
      final pack = packOf([
        recipe('r1', 'Dal bhat'),
        recipe(
          'achar',
          'Achar',
          roles: const ['sideDish'],
          times: const ['morning', 'midday', 'evening', 'night'],
          ingredients: const ['mustard'],
          category: 'achar',
        ),
      ]);

      await tester.pumpWidget(host(pack));
      await tester.tap(find.text('Night'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('suggestion_r1')), findsOneWidget);
      expect(
        find.byKey(const Key('suggestion_achar')),
        findsNothing,
        reason: 'achar is only ever an accompaniment',
      );
    });

    testWidgets('hides times for which the pack has no main course',
        (tester) async {
      // Meat only in the evening, so breakfast has nothing to offer.
      final pack = packOf([
        recipe(
          'masu',
          'Masu',
          times: const ['evening', 'night'],
          ingredients: const ['pork'],
        ),
      ]);

      await tester.pumpWidget(host(pack));

      // No main course suits the morning, so the chip reports zero and is not tappable.
      expect(
        find.descendant(
          of: find.byKey(const Key('recommendation_chip_Morning')),
          matching: find.byKey(const Key('recommendation_count_Morning')),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('recommendation_count_Morning')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '0',
      );
      final onTap = tester
          .widget<InkWell>(find.byKey(const Key('recommendation_chip_Morning')))
          .onTap;
      expect(onTap, isNull, reason: 'an empty time should not open a sheet');

      await tester.tap(find.byKey(const Key('recommendation_chip_Night')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('suggestion_masu')), findsOneWidget);
    });

    testWidgets('pairs a side dish with the main it belongs to', (tester) async {
      final pack = packOf([
        recipe(
          'dal_bhat',
          'Dal bhat',
          ingredients: const ['rice', 'dal', 'mustard'],
        ),
        recipe(
          'achar',
          'Achar',
          roles: const ['sideDish'],
          ingredients: const ['mustard'],
          category: 'achar',
        ),
      ]);

      await tester.pumpWidget(host(pack));
      await tester.tap(find.byKey(const Key('recommendation_chip_Night')));
      await tester.pumpAndSettle();

      // The side dish appears only as an accompaniment chip on the main's row.
      expect(find.byKey(const Key('side_dish_achar')), findsOneWidget);
      expect(find.text('Achar'), findsOneWidget);
    });

    testWidgets('removes an excluded ingredient from mains and accompaniments',
        (tester) async {
      final pack = packOf([
        recipe(
          'dal_bhat',
          'Dal bhat',
          ingredients: const ['rice', 'mustard'],
        ),
        recipe(
          'achar',
          'Achar',
          roles: const ['sideDish'],
          ingredients: const ['mustard'],
          category: 'achar',
        ),
        recipe(
          'tarkari',
          'Tarkari',
          ingredients: const ['pumpkin'],
        ),
      ]);

      await tester.pumpWidget(host(pack, excluded: {'mustard'}));
      await tester.tap(find.byKey(const Key('recommendation_chip_Night')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('suggestion_dal_bhat')), findsNothing);
      expect(find.byKey(const Key('side_dish_achar')), findsNothing);
      expect(find.byKey(const Key('suggestion_tarkari')), findsOneWidget);
    });

    testWidgets('forwards the main course when a suggestion is tapped',
        (tester) async {
      RegionRecipe? tapped;
      final pack = packOf([recipe('r1', 'Dal bhat')]);

      await tester.pumpWidget(host(pack, onSelected: (r) => tapped = r));
      await tester.tap(find.byKey(const Key('recommendation_chip_Night')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('suggestion_r1')));
      await tester.pumpAndSettle();

      expect(tapped?.id, 'r1');
    });

    testWidgets('respects the household language', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KitchenRecommendationSection(
              pack: packOf([recipe('r1', 'Dal bhat')]),
              preferNepali: true,
              rituId: 'sharad',
              onRecipeSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('बिहानी'), findsOneWidget);
      expect(find.text('राति'), findsOneWidget);
    });
  });
}