import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/main.dart';
import 'package:siti_counter/onboarding/welcome_tour_screen.dart';
import 'package:siti_counter/onboarding/setup_wizard_screen.dart';
import 'package:siti_counter/onboarding/kitchen_ready_screen.dart';

void main() {
  testWidgets('Complete Onboarding Flow: Tour -> 5-Question Wizard -> Kitchen Ready -> Guest Kitchen', (tester) async {
    // Set a phone screen resolution
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const SitiCounterApp());
    await tester.pumpAndSettle();

    // 1. Welcome Tour Screen should be visible
    expect(find.byType(WelcomeTourScreen), findsOneWidget);
    expect(find.text('सिट्ठी गन्ने झन्झट सधैँका लागि अन्त्य'), findsOneWidget);

    // Tap "सिधै सुरु गर्नुहोस्" (Skip)
    await tester.tap(find.text('सिधै सुरु गर्नुहोस्'));
    await tester.pumpAndSettle();

    // 2. Setup Wizard Screen should be visible with Question 1
    expect(find.byType(SetupWizardScreen), findsOneWidget);
    expect(find.text('तपाईं कहाँ पकाउनुहुन्छ?'), findsOneWidget);

    // Q1: Select Nepal - Bagmati
    await tester.tap(find.text('अगाडि बढ्नुहोस्'));
    await tester.pumpAndSettle();

    // Q2: Language
    expect(find.text('कुन भाषा मन पराउनुहुन्छ?'), findsOneWidget);
    await tester.tap(find.text('अगाडि बढ्नुहोस्'));
    await tester.pumpAndSettle();

    // Q3: Stove
    expect(find.text('तपाईंको मुख्य चुलो कुन हो?'), findsOneWidget);
    await tester.tap(find.text('अगाडि बढ्नुहोस्'));
    await tester.pumpAndSettle();

    // Q4: Household size
    expect(find.text('घरमा कति जना खाना खानुहुन्छ?'), findsOneWidget);
    await tester.tap(find.text('अगाडि बढ्नुहोस्'));
    await tester.pumpAndSettle();

    // Q5: Dietary rules
    expect(find.text('खानासम्बन्धी कुनै नियम वा बन्देज?'), findsOneWidget);
    // Tap "किचन तयार गर्नुहोस्"
    await tester.tap(find.text('किचन तयार गर्नुहोस्'));
    await tester.pumpAndSettle();

    // 3. Kitchen Ready Screen should be visible
    expect(find.byType(KitchenReadyScreen), findsOneWidget);
    expect(find.text('तपाईंको किचन तयार भयो!'), findsOneWidget);
    expect(find.text('१. अहिलेको ऋतुमा ताजा पाइने तरकारी'), findsOneWidget);
    expect(find.text('२. पहिलो ५ दिनको बेलुकीको खाना योजना'), findsOneWidget);
    expect(find.text('३. सिट्ठी काउन्टर प्रत्यक्ष परीक्षण'), findsOneWidget);

    // Test the 10-second whistle simulator button
    final whistleBtnFinder = find.text('सिट्ठी');
    await tester.ensureVisible(whistleBtnFinder);
    await tester.tap(whistleBtnFinder);
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text('१'), findsOneWidget);

    // 4. Enter kitchen as guest
    final enterKitchenBtn = find.text('किचन सुरु गर्नुहोस् (खाता बिना)');
    await tester.ensureVisible(enterKitchenBtn);
    await tester.tap(enterKitchenBtn);
    await tester.pumpAndSettle();

    // Should now be on KitchenHomeScreen with Guest badge
    expect(find.byType(KitchenHomeScreen), findsOneWidget);
    expect(find.text('अतिथि (Guest)'), findsOneWidget);
    expect(find.text('सिट्ठी संख्या'), findsOneWidget);
  });
}
