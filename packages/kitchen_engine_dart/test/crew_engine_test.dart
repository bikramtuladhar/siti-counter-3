import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CrewEngine: Recipe Task Splitting', () {
    final sampleDal = RegionRecipe(
      id: 'masyaura_dal',
      titleEn: 'Masyaura Dal',
      titleNe: 'मस्यौरा दाल',
      category: 'Lentils & Pulses',
      cuisine: 'Nepali',
      dietary: ['Vegetarian'],
      prepTimeMinutes: 15,
      cookTimeMinutes: 25,
      servings: 4,
      difficulty: 'Easy',
      ingredients: const [
        RecipeIngredientItem(ingredientId: 'musuro_dal', quantity: 200, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'ginger_garlic', quantity: 25, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'onion', quantity: 100, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'cumin_seeds', quantity: 5, unit: 'g'),
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
          instructionEn: 'Grind ginger and garlic into a fresh paste.',
          instructionNe: 'अदुवा र लसुन पिस्ने।',
        ),
        RecipeStepItem(
          stepNumber: 3,
          instructionEn: 'Pressure cook dal for 3 whistles.',
          instructionNe: 'कुकरमा ३ सिट्टी लगाउने।',
          whistles: 3,
        ),
        RecipeStepItem(
          stepNumber: 4,
          instructionEn: 'Heat ghee, temper with cumin seeds and stir.',
          instructionNe: 'घ्यू तताएर जिरा झाङ्ने र चलाउने।',
        ),
      ],
    );

    final sampleRoti = RegionRecipe(
      id: 'chapati_roti',
      titleEn: 'Phulka Roti',
      titleNe: 'फुल्का रोटी',
      category: 'Breads',
      cuisine: 'Nepali',
      dietary: ['Vegetarian'],
      prepTimeMinutes: 20,
      cookTimeMinutes: 15,
      servings: 4,
      difficulty: 'Medium',
      ingredients: const [
        RecipeIngredientItem(ingredientId: 'wheat_flour', quantity: 300, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'water', quantity: 180, unit: 'ml'),
      ],
      pressureCooker: const RecipeWhistleProfile(
        enabled: false,
        recommendedWhistles: 0,
        altitudeWhistleOffsetKathmandu: 0,
        heatLevel: 'medium',
        releaseType: 'none',
      ),
      elevationBand: const RecipeElevationBand(
        testedElevationMeters: 1400,
        boilingPointCelsius: 95.3,
        waterMultiplier: 1.0,
      ),
      seasonality: const ['all_year'],
      tags: const ['roti', 'bread'],
      steps: const [
        RecipeStepItem(
          stepNumber: 1,
          instructionEn: 'Knead soft dough and rest for 10 minutes.',
          instructionNe: 'पिठो मुछेर १० मिनेट राख्ने।',
        ),
        RecipeStepItem(
          stepNumber: 2,
          instructionEn: 'Roll round rotis and cook on hot tava.',
          instructionNe: 'रोटी बेल्ने र तावामा सेक्ने।',
        ),
      ],
    );

    test('splits pressure cooker dal recipe into parallel tasks', () {
      final tasks = CrewEngine.splitRecipe(recipe: sampleDal);

      expect(tasks.any((t) => t.taskType == TaskType.washChop), isTrue);
      expect(tasks.any((t) => t.taskType == TaskType.grindMasala), isTrue);
      expect(tasks.any((t) => t.taskType == TaskType.watchCooker), isTrue);
      expect(tasks.any((t) => t.taskType == TaskType.simmerStir), isTrue);
      expect(tasks.any((t) => t.taskType == TaskType.cleanUp), isTrue);

      // Verify whistle count is preserved in watch cooker task
      final whistleTask = tasks.firstWhere((t) => t.taskType == TaskType.watchCooker);
      expect(whistleTask.titleEn, contains('3 whistles'));
      expect(whistleTask.isKidFriendly, isTrue);
    });

    test('splits roti flatbread recipe into rollRotis and cleanup tasks', () {
      final tasks = CrewEngine.splitRecipe(recipe: sampleRoti);

      expect(tasks.any((t) => t.taskType == TaskType.rollRotis), isTrue);
      expect(tasks.any((t) => t.taskType == TaskType.cleanUp), isTrue);
      // Roti recipe has no pressure cooker whistles
      expect(tasks.any((t) => t.taskType == TaskType.watchCooker), isFalse);
    });
  });

  group('CrewEngine: Age Appropriateness & Safety Rules', () {
    final toddler = MemberCrewProfile(
      memberId: 'toddler_1',
      name: 'Aarav',
      age: 3,
    );

    final child = MemberCrewProfile(
      memberId: 'child_1',
      name: 'Rohan',
      age: 8,
    );

    final teen = MemberCrewProfile(
      memberId: 'teen_1',
      name: 'Pooja',
      age: 15,
    );

    final adult = MemberCrewProfile(
      memberId: 'adult_1',
      name: 'Sita',
      age: 36,
    );

    test('toddler can only do gentle clean-up / table tasks', () {
      expect(toddler.canPerformTask(TaskType.cleanUp), isTrue);
      expect(toddler.canPerformTask(TaskType.washChop), isFalse);
      expect(toddler.canPerformTask(TaskType.watchCooker), isFalse);
      expect(toddler.canPerformTask(TaskType.simmerStir), isFalse);
      expect(toddler.canPerformTask(TaskType.rollRotis), isFalse);
    });

    test('child (8yo) can watch cooker, set table, and wash veggies, but no hot oil or tava', () {
      expect(child.canPerformTask(TaskType.watchCooker), isTrue);
      expect(child.canPerformTask(TaskType.cleanUp), isTrue);
      expect(child.canPerformTask(TaskType.washChop), isTrue);
      expect(child.canPerformTask(TaskType.simmerStir), isFalse);
      expect(child.canPerformTask(TaskType.rollRotis), isFalse);
    });

    test('teen and adult can perform all tasks', () {
      for (final task in TaskType.values) {
        expect(teen.canPerformTask(task), isTrue);
        expect(adult.canPerformTask(task), isTrue);
      }
    });
  });

  group('CrewEngine: Task Assignment & Invitation Generation', () {
    final sita = MemberCrewProfile(
      memberId: 'm_sita',
      name: 'Sita',
      age: 38,
      skillLevel: SkillLevel.expert,
      preferredTasks: {TaskType.rollRotis, TaskType.simmerStir},
    );

    final bikram = MemberCrewProfile(
      memberId: 'm_bikram',
      name: 'Bikram',
      age: 40,
      skillLevel: SkillLevel.intermediate,
      preferredTasks: {TaskType.washChop, TaskType.grindMasala},
      avoidedTasks: {TaskType.cleanUp},
    );

    final rohan = MemberCrewProfile(
      memberId: 'm_rohan',
      name: 'Rohan',
      age: 9,
      skillLevel: SkillLevel.beginner,
      preferredTasks: {TaskType.watchCooker},
    );

    final dalRecipe = RegionRecipe(
      id: 'kalo_dal',
      titleEn: 'Kalo Dal',
      titleNe: 'कालो दाल',
      category: 'Lentils',
      cuisine: 'Nepali',
      dietary: ['Vegetarian'],
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      servings: 4,
      difficulty: 'Easy',
      ingredients: const [
        RecipeIngredientItem(ingredientId: 'kalo_daal', quantity: 200, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'ginger', quantity: 20, unit: 'g'),
      ],
      pressureCooker: const RecipeWhistleProfile(
        enabled: true,
        recommendedWhistles: 4,
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
      steps: const [],
    );

    test('assigns tasks respecting age safety, preferences, and lead cook role', () {
      final tasks = CrewEngine.splitRecipe(recipe: dalRecipe);
      final assigned = CrewEngine.assignTasks(
        tasks: tasks,
        crew: [sita, bikram, rohan],
        leadCookMemberId: sita.memberId,
      );

      // Rohan should be assigned to watch cooker (child-safe, preferred)
      final cookerTask = assigned.firstWhere((t) => t.taskType == TaskType.watchCooker);
      expect(cookerTask.assignedMemberId, equals(rohan.memberId));

      // Sita should be assigned primary simmer/stir cooking
      final stirTask = assigned.firstWhere((t) => t.taskType == TaskType.simmerStir);
      expect(stirTask.assignedMemberId, equals(sita.memberId));

      // Bikram should get prep tasks like washChop or grindMasala
      final prepTask = assigned.firstWhere((t) => t.taskType == TaskType.washChop);
      expect(prepTask.assignedMemberId, equals(bikram.memberId));
    });

    test('generates warm, engaging invitation prompt for lead cook', () {
      final tasks = CrewEngine.splitRecipe(recipe: dalRecipe);
      final assigned = CrewEngine.assignTasks(
        tasks: tasks,
        crew: [sita, bikram, rohan],
        leadCookMemberId: sita.memberId,
      );

      final prompt = CrewEngine.generateInvitationPrompt(
        recipe: dalRecipe,
        leadCook: sita,
        crew: [sita, bikram, rohan],
        assignedTasks: assigned,
      );

      expect(prompt, contains('Invite Bikram & Rohan to help with Kalo Dal?'));
      expect(prompt, contains('Rohan can count whistles'));
    });
  });

  group('CrewEngine: Fair-Share Rota & Non-Shaming Teamwork Analytics', () {
    final sita = MemberCrewProfile(memberId: 'm_sita', name: 'Sita', age: 38);
    final bikram = MemberCrewProfile(memberId: 'm_bikram', name: 'Bikram', age: 40);
    final rohan = MemberCrewProfile(memberId: 'm_rohan', name: 'Rohan', age: 9);

    final history = [
      RotaContributionRecord(
        id: 'rec_1',
        sessionId: 'sess_1',
        recipeId: 'dal',
        memberId: sita.memberId,
        memberName: sita.name,
        taskType: TaskType.simmerStir,
        role: 'leadCook',
        completedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      RotaContributionRecord(
        id: 'rec_2',
        sessionId: 'sess_1',
        recipeId: 'dal',
        memberId: rohan.memberId,
        memberName: rohan.name,
        taskType: TaskType.watchCooker,
        role: 'coCook',
        completedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      RotaContributionRecord(
        id: 'rec_3',
        sessionId: 'sess_1',
        recipeId: 'dal',
        memberId: bikram.memberId,
        memberName: bikram.name,
        taskType: TaskType.washChop,
        role: 'helper',
        completedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      RotaContributionRecord(
        id: 'rec_4',
        sessionId: 'sess_2',
        recipeId: 'tarkari',
        memberId: sita.memberId,
        memberName: sita.name,
        taskType: TaskType.simmerStir,
        role: 'leadCook',
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      RotaContributionRecord(
        id: 'rec_5',
        sessionId: 'sess_2',
        recipeId: 'tarkari',
        memberId: rohan.memberId,
        memberName: rohan.name,
        taskType: TaskType.watchCooker,
        role: 'coCook',
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    test('calculates fair-share summary with celebratory badges and zero guilt', () {
      final summary = CrewEngine.calculateFairShareSummary(
        crew: [sita, bikram, rohan],
        history: history,
      );

      expect(summary.totalSessions, equals(2));
      expect(summary.totalTasksCompleted, equals(5));
      expect(summary.celebratoryHeadline, contains('2 shared cooking sessions'));

      // Check Rohan's Whistle Guardian badge
      final rohanSummary = summary.memberSummaries.firstWhere((m) => m.memberId == rohan.memberId);
      expect(rohanSummary.celebratoryBadge, contains('Whistle Guardian'));

      // Summary should never contain shaming words
      expect(summary.teamworkInsight, isNot(contains('debt')));
      expect(summary.teamworkInsight, isNot(contains('lazy')));
      expect(summary.teamworkInsight, isNot(contains('behind')));
    });
  });
}
