import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/kitchen/fuel_tracker_screen.dart';

void main() {
  testWidgets('FuelTrackerScreen displays cylinder status and calibrates weight', (tester) async {
    final cylinder = LpgCylinderState.newCylinder(
      brand: 'Nepal Gas',
      tareWeightKg: 15.3,
    );

    LpgCylinderState? updatedCyl;

    await tester.pumpWidget(
      MaterialApp(
        home: FuelTrackerScreen(
          initialCylinder: cylinder,
          currentLanguage: 'ne',
          onCylinderUpdated: (c) => updatedCyl = c,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Check title & brand
    expect(find.text('ग्यास र इन्धन व्यवस्थापन'), findsOneWidget);
    expect(find.text('Nepal Gas'), findsOneWidget);
    expect(find.text('14.2'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // 2. Open calibration dialog
    await tester.tap(find.text('तौल मिलाउनुहोस्'));
    await tester.pumpAndSettle();

    expect(find.text('स्केलबाट तौल प्रविष्ट गर्नुहोस्'), findsOneWidget);

    // Enter gross weight: 21.3 kg -> net gas: 21.3 - 15.3 = 6.0 kg
    await tester.enterText(find.byType(TextField), '21.3');
    await tester.tap(find.text('अद्यावधिक गर्नुहोस्'));
    await tester.pumpAndSettle();

    expect(updatedCyl, isNotNull);
    expect(updatedCyl!.remainingGasKg, closeTo(6.0, 0.01));
    expect(find.text('6.0'), findsOneWidget);
  });

  testWidgets('FuelTrackerScreen displays refill alert when gas is low', (tester) async {
    // 1.0 kg remaining (~3.5 days left)
    final lowCylinder = LpgCylinderState(
      id: 'c-low',
      brand: 'Sugam Gas',
      installationDate: DateTime.now().subtract(const Duration(days: 40)),
      initialNetGasKg: 14.2,
      remainingGasKg: 1.0,
      tareWeightKg: 15.3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FuelTrackerScreen(
          initialCylinder: lowCylinder,
          currentLanguage: 'ne',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Refill Alert is shown
    expect(find.text('सिलिन्डर रिफिल सूचना'), findsOneWidget);
    expect(find.text('डिलरलाई फोन गर्नुहोस्'), findsOneWidget);
    expect(find.text('सुरक्षा जाँच सूची'), findsOneWidget);

    // 2. Tap safety check modal
    await tester.tap(find.text('सुरक्षा जाँच सूची'));
    await tester.pumpAndSettle();

    expect(find.text('एलपिजी ग्यास सुरक्षा जाँच'), findsOneWidget);
    expect(find.text('बुझें'), findsOneWidget);

    await tester.tap(find.text('बुझें'));
    await tester.pumpAndSettle();
  });

  testWidgets('FuelTrackerScreen toggles Power-Cut Mode and filters recipes', (tester) async {
    final cylinder = LpgCylinderState.newCylinder();

    await tester.pumpWidget(
      MaterialApp(
        home: FuelTrackerScreen(
          initialCylinder: cylinder,
          currentLanguage: 'ne',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially power cut mode is off
    expect(find.text('चिउरा दही र केरा'), findsNothing);

    // Toggle switch ON
    final toggle = find.byType(Switch);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // Power cut recipes appear
    expect(find.text('चिउरा दही र केरा'), findsOneWidget); // No-cook
    expect(find.text('भटमास साँधेको'), findsOneWidget); // No-cook
    expect(find.text('प्रेसर कुकर खिचडी'), findsOneWidget); // Gas pressure cooker
    expect(find.text('इन्डक्सन क्रिम सुप'), findsNothing); // Electric appliance excluded!

    // Filter by no-cook only
    final noCookChip = find.text('नो-कुक (आगो नचाहिने)');
    await tester.tap(noCookChip);
    await tester.pumpAndSettle();

    expect(find.text('चिउरा दही र केरा'), findsOneWidget);
    expect(find.text('प्रेसर कुकर खिचडी'), findsNothing);
  });
}
