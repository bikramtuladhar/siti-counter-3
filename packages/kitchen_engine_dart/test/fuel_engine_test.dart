import 'package:test/test.dart';
import 'package:kitchen_engine/fuel_engine.dart';

void main() {
  group('LPG Cylinder Consumption & State Tests', () {
    test('calculates session gas consumption by flame intensity and burner count', () {
      // 30 minutes on high flame (200 g/hr -> 100 g)
      final sessionHigh = CookingFuelSession(
        sessionId: 's-1',
        recipeName: 'Dal Bhat',
        startTime: DateTime.now(),
        durationMinutes: 30,
        flameIntensity: FlameIntensity.high,
        burnerCount: 1,
      );
      expect(sessionHigh.gasConsumedGrams, closeTo(100.0, 0.1));

      // 60 minutes on medium flame (130 g/hr -> 130 g)
      final sessionMed = CookingFuelSession(
        sessionId: 's-2',
        recipeName: 'Khasiko Masu',
        startTime: DateTime.now(),
        durationMinutes: 60,
        flameIntensity: FlameIntensity.medium,
        burnerCount: 1,
      );
      expect(sessionMed.gasConsumedGrams, closeTo(130.0, 0.1));

      // 30 minutes on 2 burners with low flame (70 g/hr * 2 = 140 g/hr -> 70 g)
      final sessionTwoBurner = CookingFuelSession(
        sessionId: 's-3',
        recipeName: 'Tea & Snacks',
        startTime: DateTime.now(),
        durationMinutes: 30,
        flameIntensity: FlameIntensity.low,
        burnerCount: 2,
      );
      expect(sessionTwoBurner.gasConsumedGrams, closeTo(70.0, 0.1));
    });

    test('updates cylinder remaining gas on consumption', () {
      final cylinder = LpgCylinderState.newCylinder(
        type: LpgCylinderType.standard14_2,
        brand: 'Nepal Gas',
      );

      expect(cylinder.initialNetGasKg, equals(14.2));
      expect(cylinder.remainingGasKg, equals(14.2));
      expect(cylinder.percentageRemaining, equals(100.0));

      // Deduct 1000g (1 kg)
      final updated = cylinder.recordConsumption(1000.0);
      expect(updated.remainingGasKg, closeTo(13.2, 0.01));
      expect(updated.percentageRemaining, closeTo((13.2 / 14.2) * 100.0, 0.1));
    });

    test('calibrates cylinder from gross scale reading', () {
      final cylinder = LpgCylinderState.newCylinder(
        tareWeightKg: 15.3,
      );

      // Scale reads 20.3 kg gross -> 20.3 - 15.3 = 5.0 kg net gas
      final calibrated = cylinder.calibrateFromGrossWeight(20.3);
      expect(calibrated.remainingGasKg, closeTo(5.0, 0.01));
      expect(calibrated.percentageRemaining, closeTo((5.0 / 14.2) * 100.0, 0.1));
    });
  });

  group('LPG Depletion Prediction & Refill Alerts', () {
    test('predicts normal status when gas is abundant (>4 days / >15%)', () {
      final cylinder = LpgCylinderState(
        id: 'cyl-1',
        installationDate: DateTime.now().subtract(const Duration(days: 10)),
        initialNetGasKg: 14.2,
        remainingGasKg: 10.0,
        tareWeightKg: 15.3,
      );

      final forecast = FuelEngine.predictDepletion(cylinder: cylinder);
      expect(forecast.urgency, equals(RefillUrgency.normal));
      expect(forecast.isRefillNeeded, isFalse);
      expect(forecast.estimatedDaysRemaining, greaterThan(25));
      expect(forecast.refillAlertMessageEn, contains('healthy'));
    });

    test('triggers orderSoon refill alert when predicted days <= 4.0', () {
      // 1.0 kg remaining at default burn rate (~280g/day) is ~3.57 days
      final cylinder = LpgCylinderState(
        id: 'cyl-1',
        installationDate: DateTime.now().subtract(const Duration(days: 40)),
        initialNetGasKg: 14.2,
        remainingGasKg: 1.0,
        tareWeightKg: 15.3,
      );

      final forecast = FuelEngine.predictDepletion(cylinder: cylinder);
      expect(forecast.urgency, equals(RefillUrgency.orderSoon));
      expect(forecast.isRefillNeeded, isTrue);
      expect(forecast.estimatedDaysRemaining, closeTo(3.57, 0.2));
      expect(forecast.refillAlertMessageEn, contains('Refill Reminder'));
      expect(forecast.refillAlertMessageNe, contains('रिफिल रिमाइन्डर'));
    });

    test('triggers critical alert when <= 1.5 days remaining', () {
      // 0.35 kg remaining at ~280g/day is ~1.25 days
      final cylinder = LpgCylinderState(
        id: 'cyl-1',
        installationDate: DateTime.now().subtract(const Duration(days: 45)),
        initialNetGasKg: 14.2,
        remainingGasKg: 0.35,
        tareWeightKg: 15.3,
      );

      final forecast = FuelEngine.predictDepletion(cylinder: cylinder);
      expect(forecast.urgency, equals(RefillUrgency.critical));
      expect(forecast.isRefillNeeded, isTrue);
      expect(forecast.refillAlertMessageEn, contains('URGENT'));
    });

    test('triggers empty alert when gas is depleted (<= 0.05 kg)', () {
      final cylinder = LpgCylinderState(
        id: 'cyl-1',
        installationDate: DateTime.now().subtract(const Duration(days: 50)),
        initialNetGasKg: 14.2,
        remainingGasKg: 0.0,
        tareWeightKg: 15.3,
      );

      final forecast = FuelEngine.predictDepletion(cylinder: cylinder);
      expect(forecast.urgency, equals(RefillUrgency.empty));
      expect(forecast.isRefillNeeded, isTrue);
      expect(forecast.estimatedDaysRemaining, equals(0.0));
      expect(forecast.refillAlertMessageEn, contains('EMPTY'));
    });
  });

  group('Power-Cut Outage Mode Tests', () {
    final catalog = [
      const PowerCutRecipeItem(
        id: 'r1',
        nameEn: 'Chiura Dahi & Banana',
        nameNe: 'चिउरा दही र केरा',
        powerProfile: RecipePowerProfile.noCook,
        cookTimeMinutes: 5,
        isGasSaver: true,
      ),
      const PowerCutRecipeItem(
        id: 'r2',
        nameEn: 'Quick Yellow Dal',
        nameNe: 'छिटो पहेँलो दाल',
        powerProfile: RecipePowerProfile.gasPressureCooker,
        cookTimeMinutes: 15,
        whistles: 2,
        isGasSaver: true,
      ),
      const PowerCutRecipeItem(
        id: 'r3',
        nameEn: 'Slow Braised Khasi Masu',
        nameNe: 'खसीको मासु',
        powerProfile: RecipePowerProfile.gasPressureCooker,
        cookTimeMinutes: 45,
        whistles: 5,
        isGasSaver: false,
      ),
      const PowerCutRecipeItem(
        id: 'r4',
        nameEn: 'Induction Cream Soup & Mixer Puree',
        nameNe: 'इन्डक्सन सुप',
        powerProfile: RecipePowerProfile.electricAppliance,
        cookTimeMinutes: 25,
        isGasSaver: false,
      ),
    ];

    test('filters out electric appliances during power-cut', () {
      final filtered = FuelEngine.filterForPowerCut(recipes: catalog);
      expect(filtered.length, equals(3));
      expect(filtered.any((r) => r.id == 'r4'), isFalse);
      expect(filtered.any((r) => r.id == 'r1'), isTrue);
      expect(filtered.any((r) => r.id == 'r2'), isTrue);
      expect(filtered.any((r) => r.id == 'r3'), isTrue);
    });

    test('filters no-cook recipes only when specified', () {
      final noCook = FuelEngine.filterForPowerCut(recipes: catalog, noCookOnly: true);
      expect(noCook.length, equals(1));
      expect(noCook.first.id, equals('r1'));
    });

    test('filters gas-saver recipes to preserve LPG during emergency', () {
      final gasSavers = FuelEngine.filterForPowerCut(recipes: catalog, gasSaverOnly: true);
      expect(gasSavers.length, equals(2));
      expect(gasSavers.map((r) => r.id), containsAll(['r1', 'r2']));
      expect(gasSavers.any((r) => r.id == 'r3'), isFalse);
    });
  });
}
