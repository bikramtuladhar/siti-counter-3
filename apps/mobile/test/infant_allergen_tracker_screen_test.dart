import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/safety/infant_allergen_tracker_screen.dart';

void main() {
  testWidgets('InfantAllergenTrackerScreen renders pediatric disclaimer, allergen cards, and logs exposure',
      (tester) async {
    final initialLogs = [
      InfantAllergenLog(
        id: 'log-1',
        memberId: 'baby-aarav',
        allergen: AllergenCatalog.peanuts,
        foodDescription: 'Thinned peanut butter 1/4 tsp',
        exposureDate: DateTime.now().subtract(const Duration(days: 2)),
        portionGrams: 1.0,
        dayOfProtocol: 1,
        reactionSeverity: ReactionSeverity.none,
      ),
    ];

    InfantAllergenLog? savedLog;

    await tester.pumpWidget(
      MaterialApp(
        home: InfantAllergenTrackerScreen(
          childName: 'Aarav (8 Months)',
          childMemberId: 'baby-aarav',
          initialLogs: initialLogs,
          currentLanguage: 'ne',
          onLogSaved: (log) => savedLog = log,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify child banner & pediatric disclaimer
    expect(find.text('Aarav (8 Months)'), findsOneWidget);
    expect(find.textContaining('बालरोग विशेषज्ञ सल्लाह'), findsWidgets);

    // 2. Verify priority food items are displayed
    expect(find.text('Peanuts'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.textContaining('परिचय हुँदैछ'), findsOneWidget);

    // 3. Expand Peanuts card
    await tester.tap(find.text('Peanuts'));
    await tester.pumpAndSettle();

    // Verify choking hazard tip and history
    expect(find.textContaining('घाँटीमा अड्किने चेतावनी'), findsOneWidget);
    expect(find.textContaining('Day 1 (1.0g): Thinned peanut butter'), findsOneWidget);

    // 4. Tap '+ नयाँ खुराक थप्नुहोस्' (+ Log New Exposure)
    final addBtn = find.text('+ नयाँ खुराक थप्नुहोस्');
    await tester.ensureVisible(addBtn);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Verify modal bottom sheet opened
    expect(find.text('नयाँ खुराक दर्ता गर्नुहोस्'), findsOneWidget);

    // Tap save exposure log
    final saveBtn = find.text('सुरक्षित गर्नुहोस्');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(savedLog, isNotNull);
    expect(savedLog!.allergen, equals(AllergenCatalog.peanuts));
  });
}
