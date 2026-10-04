import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/safety/emergency_allergy_card_screen.dart';

void main() {
  testWidgets('EmergencyAllergyCardScreen renders bilingual card and switches to restaurant mode',
      (tester) async {
    const card = EmergencyAllergyCard(
      memberName: 'Maya Tuladhar',
      memberAge: 5,
      severeAllergens: [
        AllergenCatalog.peanuts,
        AllergenCatalog.milk,
      ],
      moderateAllergens: [
        AllergenCatalog.sesame,
      ],
      carriesEpiPen: true,
      emergencyContacts: [
        EmergencyContact(
          name: 'Sunita Tuladhar',
          relationship: 'Mother',
          phone: '+977-9812345678',
        ),
      ],
      doctorName: 'Dr. Anita Joshi',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: EmergencyAllergyCardScreen(
          card: card,
          currentLanguage: 'ne',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify title & offline notice
    expect(find.text('आकस्मिक एलर्जी कार्ड'), findsWidgets);
    expect(find.textContaining('१००% अफलाइन उपलब्ध छ'), findsOneWidget);

    // 2. Verify Member name and severe allergens
    expect(find.text('Maya Tuladhar (Age: 5)'), findsOneWidget);
    expect(find.textContaining('Peanuts'), findsWidgets);
    expect(find.textContaining('Dairy'), findsWidgets);

    // 3. Verify cross-contact warnings (ghee, butter, methi)
    expect(find.textContaining('ghee'), findsWidgets);

    // 4. Verify EpiPen alert
    expect(find.text('CARRIES EPINEPHRINE (EpiPen)'), findsOneWidget);

    // 5. Verify Emergency contact
    expect(find.text('Sunita Tuladhar (Mother)'), findsOneWidget);
    expect(find.text('+977-9812345678'), findsOneWidget);

    // 6. Tap Restaurant Mode button to enter high-contrast fullscreen
    final restaurantBtn = find.text('रेस्टुरेन्ट मोड');
    await tester.ensureVisible(restaurantBtn);
    await tester.tap(restaurantBtn);
    await tester.pumpAndSettle();

    expect(find.text('बन्द गर्नुहोस्'), findsOneWidget);

    // 7. Exit restaurant mode
    await tester.tap(find.text('बन्द गर्नुहोस्'));
    await tester.pumpAndSettle();

    expect(find.text('बन्द गर्नुहोस्'), findsNothing);
  });
}
