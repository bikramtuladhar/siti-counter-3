import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('UnitConverter - Mass', () {
    test('converts pau to grams and back', () {
      expect(UnitConverter.pauToGrams(1), equals(250.0));
      expect(UnitConverter.pauToGrams(4), equals(1000.0));
      expect(UnitConverter.gramsToPau(500), equals(2.0));
      expect(UnitConverter.gramsToPau(250), equals(1.0));
    });

    test('converts dharni to grams and back', () {
      expect(UnitConverter.dharniToGrams(1), equals(2500.0));
      expect(UnitConverter.dharniToGrams(2), equals(5000.0));
      expect(UnitConverter.gramsToDharni(2500), equals(1.0));
    });

    test('converts tola and seer', () {
      expect(UnitConverter.tolaToGrams(1), closeTo(11.66, 0.01));
      expect(UnitConverter.seerToGrams(1), closeTo(933.1, 0.1));
    });

    test('converts muthi (handful)', () {
      expect(UnitConverter.muthiToGrams(2), equals(100.0));
      expect(UnitConverter.gramsToMuthi(150), equals(3.0));
    });
  });

  group('UnitConverter - Volume', () {
    test('converts mana (568ml)', () {
      expect(UnitConverter.manaToMl(1), equals(568.0));
      expect(UnitConverter.manaToMl(2), equals(1136.0));
      expect(UnitConverter.mlToMana(568), equals(1.0));
    });

    test('distinguishes metric cup (250ml) vs US cup (240ml)', () {
      expect(UnitConverter.metricCupToMl(1), equals(250.0));
      expect(UnitConverter.usCupToMl(1), equals(240.0));
      expect(UnitConverter.metricCupToMl(1) - UnitConverter.usCupToMl(1), equals(10.0));
    });

    test('converts tablespoons and teaspoons', () {
      expect(UnitConverter.tablespoonToMl(1), equals(15.0));
      expect(UnitConverter.teaspoonToMl(1), equals(5.0));
      expect(UnitConverter.mlToTablespoon(30), equals(2.0));
      expect(UnitConverter.mlToTeaspoon(15), equals(3.0));
    });
  });

  group('UnitConverter - Formatting', () {
    test('formats local units in English and Nepali', () {
      expect(UnitConverter.formatLocalUnit(grams: 500), equals('2 pau'));
      expect(UnitConverter.formatLocalUnit(grams: 500, preferNepali: true), equals('2 पाउ'));
      expect(UnitConverter.formatLocalUnit(grams: 2500), equals('1 dharni'));
      expect(UnitConverter.formatLocalUnit(grams: 2500, preferNepali: true), equals('1 धार्नी'));
      expect(UnitConverter.formatLocalUnit(grams: 1200), equals('1.2 kg'));
      expect(UnitConverter.formatLocalUnit(grams: 150), equals('150 g'));
    });
  });

  group('MarketCalculator', () {
    test('computes store purchase units and surplus for tomatoes', () {
      // Recipe needs 750g tomato, store sells by 1 kg (1000g)
      final result = MarketCalculator.calculatePurchase(
        ingredientName: 'Tomato (गोलभेडा)',
        recipeQuantityGrams: 750,
        standardPackageGrams: 1000,
        alreadyHaveGrams: 0,
      );

      expect(result.packagesToBuy, equals(1));
      expect(result.totalPurchasedGrams, equals(1000.0));
      expect(result.surplusGrams, equals(250.0));
      expect(result.surplusSuggestion, contains('fresh tomato achar'));
    });

    test('handles already-have quantity correctly', () {
      // Recipe needs 500g, already have 200g, store sells in 250g pau
      final result = MarketCalculator.calculatePurchase(
        ingredientName: 'Potato',
        recipeQuantityGrams: 500,
        standardPackageGrams: 250,
        alreadyHaveGrams: 200,
      );

      // net needed: 300g -> 2 packs of 250g = 500g
      expect(result.packagesToBuy, equals(2));
      expect(result.totalPurchasedGrams, equals(500.0));
      expect(result.surplusGrams, equals(200.0));
    });
  });

  group('AltitudeCalculator', () {
    test('calculates boiling point at Kathmandu altitude (1400m)', () {
      final bp = AltitudeCalculator.boilingPointCelsius(1400);
      expect(bp, closeTo(95.0, 0.5));
    });

    test('adjusts siti count at altitude', () {
      expect(AltitudeCalculator.adjustSitiCount(baseSiti: 5, elevationMeters: 1400), equals(6));
      expect(AltitudeCalculator.adjustSitiCount(baseSiti: 5, elevationMeters: 100), equals(5));
      expect(AltitudeCalculator.adjustSitiCount(baseSiti: 4, elevationMeters: 3600), equals(5));
    });

    test('provides human-readable explanation', () {
      final explanation = AltitudeCalculator.altitudeExplanation(
        originalSiti: 5,
        adjustedSiti: 6,
        elevationMeters: 1400,
      );
      expect(explanation, contains('At 1400 m: 6 siti instead of 5'));
      expect(explanation, contains('water boils at 95.1°C'));
    });
  });
}
