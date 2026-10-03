import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('UnitConverter', () {
    test('converts pau to grams correctly', () {
      expect(UnitConverter.pauToGrams(1), equals(250.0));
      expect(UnitConverter.pauToGrams(4), equals(1000.0));
    });

    test('converts grams to pau correctly', () {
      expect(UnitConverter.gramsToPau(500), equals(2.0));
    });

    test('converts dharni to grams correctly', () {
      expect(UnitConverter.dharniToGrams(1), equals(2500.0));
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
    });
  });
}
