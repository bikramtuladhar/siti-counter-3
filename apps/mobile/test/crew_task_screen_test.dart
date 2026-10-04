import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kitchen_engine/crew_engine.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:siti_counter/crew/crew_repository.dart';
import 'package:siti_counter/crew/crew_task_screen.dart';
import 'package:siti_counter/crew/fair_share_screen.dart';
import 'package:siti_counter/screens/recipe_detail_screen.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<CrewRepository> makeRepo(WidgetTester tester) async {
  final repo = await tester.runAsync(() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await CrewRepository.createTables(db);
    return CrewRepository(db);
  });
  return repo!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final sampleRecipe = RegionRecipe(
    id: 'dal_bhat_tarkari',
    titleEn: 'Masyaura Dal',
    titleNe: 'मस्यौरा दाल',
    category: 'Lentils & Pulses',
    cuisine: 'Nepali',
    dietary: const ['Vegetarian'],
    prepTimeMinutes: 15,
    cookTimeMinutes: 25,
    servings: 4,
    difficulty: 'Easy',
    ingredients: const [
      RecipeIngredientItem(ingredientId: 'musuro_dal', quantity: 200, unit: 'g'),
      RecipeIngredientItem(ingredientId: 'ginger_garlic', quantity: 25, unit: 'g'),
      RecipeIngredientItem(ingredientId: 'onion', quantity: 100, unit: 'g'),
    ],
    pressureCooker: const RecipeWhistleProfile(
      enabled: true,
      recommendedWhistles: 3,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'medium',
      releaseType: 'natural',
    ),
    elevationBand: const RecipeElevationBand(
      testedElevationMeters: 1400,
      boilingPointCelsius: 95.3,
      waterMultiplier: 1.15,
    ),
    seasonality: const ['all_year'],
    tags: const ['dal', 'lentils'],
    steps: const [
      RecipeStepItem(
        stepNumber: 1,
        instructionEn: 'Wash dal thoroughly and chop onions.',
        instructionNe: 'दाल पखाल्ने र प्याज काट्ने।',
      ),
      RecipeStepItem(
        stepNumber: 2,
        instructionEn: 'Grind ginger and garlic into a paste.',
        instructionNe: 'अदुवा र लसुन पिस्ने।',
      ),
    ],
  );

  group('CrewTaskScreen Widget Tests', () {
    testWidgets('renders invitation banner, crew chips, and split task categories', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: CrewTaskScreen(
            recipe: sampleRecipe,
            repository: repo,
            currentLanguage: 'en',
          ),
        ),
      );
      await settle(tester);

      // Verify AppBar title
      expect(find.text('Co-Cooking Crew Tasks'), findsOneWidget);

      // Verify Lead Cook invitation banner
      expect(find.text('Lead Cook Crew Invitation'), findsOneWidget);
      expect(find.textContaining('Invite Srijana & Aayush to help with Masyaura Dal'), findsOneWidget);
      expect(find.text('Invite Crew to Kitchen'), findsOneWidget);

      // Verify active crew chips
      expect(find.textContaining('(Lead)'), findsOneWidget);
      expect(find.text('Bikram (Lead)'), findsOneWidget);
      expect(find.text('Srijana'), findsWidgets);
      expect(find.text('Aayush'), findsWidgets);

      // Verify section headers for parallel tasks
      expect(find.text('1. Prep Tasks (Wash, Chop, Grind)'), findsOneWidget);
      expect(find.text('2. Active Cooking & Whistles'), findsOneWidget);
      expect(find.text('3. Clean-up & Table Prep'), findsOneWidget);

      // Verify individual task titles
      expect(find.text('Wash & Chop Vegetables'), findsOneWidget);
      expect(find.text('Grind Fresh Masala'), findsOneWidget);
      expect(find.textContaining('Watch Pressure Cooker (3 whistles)'), findsOneWidget);
      expect(find.text('Clean-up & Set the Table'), findsOneWidget);

      // Verify Kid-Friendly badge
      expect(find.text('Kid-Friendly'), findsWidgets);

      // Verify Action buttons
      expect(find.text('Start Cooking with Crew'), findsOneWidget);
      expect(find.text('View Fair-Share Teamwork Rota'), findsOneWidget);
    });

    testWidgets('toggles task status from pending to in progress and completed', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: CrewTaskScreen(
            recipe: sampleRecipe,
            repository: repo,
            currentLanguage: 'en',
          ),
        ),
      );
      await settle(tester);

      // Find the first task status icon (radio_button_unchecked)
      final statusIconFinder = find.byIcon(Icons.radio_button_unchecked_rounded).first;
      expect(statusIconFinder, findsOneWidget);

      // Tap to set in progress
      await tester.tap(statusIconFinder);
      await tester.pump();
      expect(find.byIcon(Icons.timelapse_rounded), findsOneWidget);

      // Tap again to mark completed
      await tester.tap(find.byIcon(Icons.timelapse_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('tapping invite crew shows confirmation snackbar', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: CrewTaskScreen(
            recipe: sampleRecipe,
            repository: repo,
            currentLanguage: 'en',
          ),
        ),
      );
      await settle(tester);

      final inviteButton = find.text('Invite Crew to Kitchen');
      expect(inviteButton, findsOneWidget);

      await tester.tap(inviteButton);
      await tester.pump();

      expect(find.text('Cooking crew notified on household channel!'), findsOneWidget);
    });
  });

  group('FairShareScreen Widget Tests', () {
    testWidgets('renders celebratory headline, member badges, and rotation tip', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      // Pre-seed contributions
      await tester.runAsync(() async {
        await repo.logContribution(
          RotaContributionRecord(
            id: 'c1',
            sessionId: 'sess_1',
            recipeId: 'dal',
            memberId: 'm1',
            memberName: 'Bikram',
            taskType: TaskType.simmerStir,
            role: 'leadCook',
            completedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        );
        await repo.logContribution(
          RotaContributionRecord(
            id: 'c2',
            sessionId: 'sess_1',
            recipeId: 'dal',
            memberId: 'm3',
            memberName: 'Aayush',
            taskType: TaskType.watchCooker,
            role: 'coCook',
            completedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        );
        await repo.logContribution(
          RotaContributionRecord(
            id: 'c3',
            sessionId: 'sess_2',
            recipeId: 'dal',
            memberId: 'm3',
            memberName: 'Aayush',
            taskType: TaskType.watchCooker,
            role: 'coCook',
            completedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: FairShareScreen(
            repository: repo,
            currentLanguage: 'en',
          ),
        ),
      );
      await settle(tester);

      // Verify Header
      expect(find.text('Cooking Crew & Fair-Share Rota'), findsOneWidget);
      expect(find.textContaining('shared cooking sessions'), findsOneWidget);
      expect(find.text('Crew Meals'), findsOneWidget);
      expect(find.text('Tasks Done'), findsOneWidget);

      // Verify Member Badges
      expect(find.text('Household Contributions'), findsOneWidget);
      expect(find.text('Bikram'), findsOneWidget);
      expect(find.text('Aayush'), findsOneWidget);
      expect(find.text('Whistle Guardian 🔔'), findsOneWidget);

      // Verify Rotation Tip
      expect(find.text('Joyful Rotation Tip'), findsOneWidget);
      expect(find.textContaining('Next session tip:'), findsOneWidget);
    });
  });

  group('RecipeDetailScreen: Cook with Crew Integration', () {
    testWidgets('displays Cook with Crew button when crewRepository is provided', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);
      bool crewPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RecipeDetailScreen(
            recipe: sampleRecipe,
            currentLanguage: 'en',
            crewRepository: repo,
            onCookWithCrew: () {
              crewPressed = true;
            },
          ),
        ),
      );
      await settle(tester);

      final cookWithCrewBtn = find.byKey(const Key('cook_with_crew_button'));
      await tester.ensureVisible(cookWithCrewBtn);
      await tester.pumpAndSettle();
      expect(cookWithCrewBtn, findsOneWidget);
      expect(find.text('Cook with Crew & Split Tasks'), findsOneWidget);

      await tester.tap(cookWithCrewBtn);
      await tester.pump();

      expect(crewPressed, isTrue);
    });
  });
}
