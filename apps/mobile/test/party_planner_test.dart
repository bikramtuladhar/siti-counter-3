import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/planner/party_planner_screen.dart';

void main() {
  group('PartyPlannerScreen Widget Tests', () {
    testWidgets('renders party header, guest count stepper, and equipment conflict banner', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartyPlannerScreen(
            currentLanguage: 'en',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & guest count
      expect(find.text('Party Mode Planner'), findsOneWidget);
      expect(find.byKey(const Key('guest_count_text')), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('4.0x Scale'), findsOneWidget);

      // Increment guest count
      await tester.tap(find.byKey(const Key('guest_count_increment')));
      await tester.pumpAndSettle();

      expect(find.text('18'), findsOneWidget);
      expect(find.text('4.5x Scale'), findsOneWidget);

      // Default menu has two dishes using pressure_cooker_5l simultaneously -> conflict banner expected
      expect(find.byKey(const Key('conflict_alert_banner')), findsOneWidget);
      expect(find.textContaining('Equipment / Burner Conflicts Detected'), findsOneWidget);
    });

    testWidgets('navigates tabs to view T-Minus timeline, menu, and combined groceries', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartyPlannerScreen(
            currentLanguage: 'ne',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Devanagari title
      expect(find.text('पार्टी मोड योजनाकार'), findsOneWidget);

      // Verify timeline tasks
      expect(find.text('खसीको मासु पकाउनुहोस्'), findsOneWidget);
      expect(find.textContaining('👤 Bikram'), findsWidgets);

      // Switch to Menu & Gear tab
      await tester.tap(find.text('मेनु र उपकरण'));
      await tester.pumpAndSettle();

      expect(find.text('मेनुका परिकारहरू (5)'), findsOneWidget);
      expect(find.text('खसीको मासु'), findsOneWidget);
      expect(find.text('दाल मखनी'), findsOneWidget);
      expect(find.text('जीरा राइस'), findsOneWidget);

      // Switch to Groceries tab
      await tester.tap(find.text('सामग्री सूची'));
      await tester.pumpAndSettle();

      expect(find.text('कुल पार्टी सामग्री (7)'), findsOneWidget);
      expect(find.text('खसीको मासु'), findsOneWidget);
      // 16 guests / 4 = 4x scale -> 800g * 4 = 3200 g
      expect(find.text('3200 g'), findsOneWidget);
    });

    testWidgets('shows feasible banner when equipment conflicts are resolved', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const nonConflictingInput = PartyPlanInput(
        titleEn: 'Simple Dinner',
        titleNe: 'साधारण भोज',
        guestCount: 8,
        serveTime: '19:00',
        availableEquipment: ['pressure_cooker_5l', 'rice_cooker'],
        burnerCount: 3,
        menuItems: [
          PartyMenuItem(
            recipeId: 'mutton',
            nameEn: 'Mutton Curry',
            nameNe: 'खसीको मासु',
            course: CourseType.main,
            prepDurationMinutes: 15,
            cookDurationMinutes: 45,
            requiredEquipment: ['pressure_cooker_5l'],
            requiredBurners: 1,
          ),
          PartyMenuItem(
            recipeId: 'rice',
            nameEn: 'Rice',
            nameNe: 'भात',
            course: CourseType.side,
            prepDurationMinutes: 5,
            cookDurationMinutes: 20,
            requiredEquipment: ['rice_cooker'],
            requiredBurners: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: PartyPlannerScreen(
            initialInput: nonConflictingInput,
            currentLanguage: 'en',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feasible_banner')), findsOneWidget);
      expect(find.text('Timeline Feasible: No Equipment Conflicts'), findsOneWidget);
    });
  });
}
