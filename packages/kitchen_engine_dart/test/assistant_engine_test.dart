import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

class MockOnDeviceProvider implements OnDeviceAiProvider {
  final String? reply;
  MockOnDeviceProvider([this.reply]);

  @override
  Future<String?> generateLocalResponse({
    required String pseudonymizedPrompt,
    required String language,
  }) async {
    return reply ?? 'Local advice: Cook gently with love for [FamilyMember_1].';
  }
}

class MockCloudGeminiProvider implements CloudGeminiProvider {
  final String reply;
  MockCloudGeminiProvider([this.reply = 'I suggest making Masyaura Dal and Peanut Chutney for [FamilyMember_1].']);

  @override
  Future<String> queryGemini({
    required String pseudonymizedPrompt,
    required String language,
  }) async {
    return reply;
  }
}

void main() {
  final dalRecipe = RegionRecipe(
    id: 'masyaura_dal',
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
  );

  final peanutRecipe = RegionRecipe(
    id: 'peanut_chutney',
    titleEn: 'Peanut Chutney',
    titleNe: 'बदामको अचार',
    category: 'Pickles & Chutneys',
    cuisine: 'Nepali',
    dietary: const ['Vegetarian'],
    prepTimeMinutes: 10,
    cookTimeMinutes: 5,
    servings: 4,
    difficulty: 'Easy',
    ingredients: const [
      RecipeIngredientItem(ingredientId: 'peanut', quantity: 100, unit: 'g'),
      RecipeIngredientItem(ingredientId: 'garlic', quantity: 10, unit: 'g'),
    ],
    pressureCooker: const RecipeWhistleProfile(
      enabled: false,
      recommendedWhistles: 0,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'none',
      releaseType: 'none',
    ),
    elevationBand: const RecipeElevationBand(
      testedElevationMeters: 1400,
      boilingPointCelsius: 95.3,
      waterMultiplier: 1.0,
    ),
    seasonality: const ['all_year'],
    tags: const ['chutney', 'peanut'],
  );

  group('AssistantEngine: Tier 1 Deterministic Kitchen Engine', () {
    test('answers unit conversion queries deterministically without LLM', () {
      final req = AssistantRequest(
        prompt: 'How many grams in 2 pau?',
      );
      final resp = DeterministicAssistantRouter.matchQuery(req);

      expect(resp, isNotNull);
      expect(resp!.tier, equals(AiRoutingTier.deterministic));
      expect(resp.replyEn, contains('2.0 pau is exactly 500 grams (500 g)'));
    });

    test('answers mana and dharni volume/mass queries', () {
      final req1 = AssistantRequest(prompt: 'Convert 1 mana to ml');
      final resp1 = DeterministicAssistantRouter.matchQuery(req1);
      expect(resp1?.replyEn, contains('568 ml'));

      final req2 = AssistantRequest(prompt: 'What is 1 dharni in kg?');
      final resp2 = DeterministicAssistantRouter.matchQuery(req2);
      expect(resp2?.replyEn, contains('2.5 kg'));
    });

    test('answers altitude boiling point queries', () {
      final req = AssistantRequest(
        prompt: 'What is the water boiling point in Kathmandu?',
        currentElevationMeters: 1400,
      );
      final resp = DeterministicAssistantRouter.matchQuery(req);

      expect(resp, isNotNull);
      expect(resp!.replyEn, contains('1400m elevation'));
      expect(resp.replyEn, contains('95.1°C'));
    });

    test('whistle count lookup provides executable Cook Now and Add to Plan actions', () {
      final req = AssistantRequest(
        prompt: 'How many whistles for masyaura dal?',
        catalogRecipes: [dalRecipe],
        currentElevationMeters: 1400,
      );
      final resp = DeterministicAssistantRouter.matchQuery(req);

      expect(resp, isNotNull);
      expect(resp!.tier, equals(AiRoutingTier.deterministic));
      expect(resp.replyEn, contains('Masyaura Dal takes 4 whistles'));
      expect(resp.actions, hasLength(2));
      expect(resp.actions.first.type, equals(ActionType.cookNow));
      expect(resp.actions.first.whistles, equals(4));
      expect(resp.actions[1].type, equals(ActionType.addToPlan));
    });

    test('pantry search suggests recipes with executable actions', () {
      final req = AssistantRequest(
        prompt: 'What can I cook with musuro dal?',
        catalogRecipes: [dalRecipe],
        pantryIngredientIds: ['musuro_dal'],
      );
      final resp = DeterministicAssistantRouter.matchQuery(req);

      expect(resp, isNotNull);
      expect(resp!.suggestedRecipes, contains(dalRecipe));
      expect(resp.actions.any((a) => a.type == ActionType.cookNow), isTrue);
    });

    test('leftover safety answers shelf life deterministically', () {
      final req = AssistantRequest(
        prompt: 'How long does cooked dal last in the fridge?',
      );
      final resp = DeterministicAssistantRouter.matchQuery(req);

      expect(resp, isNotNull);
      expect(resp!.replyEn, contains('48 hours'));
      expect(resp.actions.first.type, equals(ActionType.viewRecipe));
    });
  });

  group('AssistantEngine: Guardrails & Privacy', () {
    test('DataPseudonymizer scrubs household names and PII', () {
      const prompt = 'Please suggest a dinner for Bikram and Sita. Email: bikram@example.com, Phone: 9841234567';
      final res = DataPseudonymizer.pseudonymize(
        prompt,
        knownNames: ['Bikram', 'Sita'],
      );

      expect(res.text, isNot(contains('Bikram')));
      expect(res.text, isNot(contains('Sita')));
      expect(res.text, contains('[FamilyMember_1]'));
      expect(res.text, contains('[FamilyMember_2]'));
      expect(res.text, contains('[Email_Scrubbed]'));
      expect(res.text, contains('[Phone_Scrubbed]'));

      // Test rehydration
      final rehydrated = DataPseudonymizer.rehydrate(
        'Dinner ready for [FamilyMember_1] and [FamilyMember_2]!',
        res.nameMap,
      );
      expect(rehydrated, equals('Dinner ready for Bikram and Sita!'));
    });

    test('Blocks medical and pediatric calorie advice per Section 22.2', () {
      expect(
        SafetyGuardrail.isMedicalOrPediatricCalorieQuery('What is the pediatric calorie target for my baby?'),
        isTrue,
      );
      expect(
        SafetyGuardrail.isMedicalOrPediatricCalorieQuery('Calorie limit for my toddler'),
        isTrue,
      );
      expect(
        SafetyGuardrail.isMedicalOrPediatricCalorieQuery('How many calories in this dal?'),
        isFalse,
      );

      final resp = SafetyGuardrail.buildMedicalSafetyResponse();
      expect(resp.replyEn, contains('does not provide medical or pediatric calorie targets'));
      expect(resp.replyEn, contains('family pediatrician'));
      expect(resp.actions, isEmpty);
    });

    test('Strict deterministic allergen post-check excludes unsafe AI recommendations', () {
      final allergyProfiles = [
        const MemberAllergyProfile(
          allergen: AllergenCatalog.peanuts,
          severity: AllergySeverity.severe,
          memberName: 'Bikram',
        ),
      ];

      final postCheck = SafetyGuardrail.postCheckRecipes(
        candidates: [dalRecipe, peanutRecipe],
        memberAllergies: allergyProfiles,
        dietaryRules: const [],
      );

      expect(postCheck.safeRecipes, contains(dalRecipe));
      expect(postCheck.safeRecipes, isNot(contains(peanutRecipe)));
      expect(postCheck.hadUnsafeFiltered, isTrue);
      expect(postCheck.notes.first, contains('Peanut Chutney'));
    });
  });

  group('ThreeTierAssistantCoordinator Integration', () {
    test('returns deterministic response if matched, bypassing AI tiers', () async {
      final coordinator = ThreeTierAssistantCoordinator(
        onDeviceProvider: MockOnDeviceProvider(),
        cloudProvider: MockCloudGeminiProvider(),
      );

      final req = AssistantRequest(
        prompt: 'Convert 2 pau to grams',
      );
      final resp = await coordinator.process(req);

      expect(resp.tier, equals(AiRoutingTier.deterministic));
      expect(resp.replyEn, contains('500 grams'));
    });

    test('requires explicit cloud consent before routing to Cloud Gemini', () async {
      final coordinator = ThreeTierAssistantCoordinator(
        cloudProvider: MockCloudGeminiProvider(),
      );

      final req = AssistantRequest(
        prompt: 'Suggest a creative fusion dinner for Bikram',
        hasCloudConsent: false, // User has not consented to cloud AI
      );
      final resp = await coordinator.process(req);

      expect(resp.consentPromptRequired, isTrue);
      expect(resp.replyEn, contains('enable cloud assistance'));
    });

    test('routes to Cloud Gemini with consent, pseudonymizing and filtering allergens', () async {
      final coordinator = ThreeTierAssistantCoordinator(
        cloudProvider: MockCloudGeminiProvider(),
      );

      final req = AssistantRequest(
        prompt: 'Suggest a creative fusion dinner for Bikram',
        householdMemberNames: ['Bikram'],
        memberAllergies: const [
          MemberAllergyProfile(
            allergen: AllergenCatalog.peanuts,
            severity: AllergySeverity.severe,
            memberName: 'Bikram',
          ),
        ],
        catalogRecipes: [dalRecipe, peanutRecipe],
        hasCloudConsent: true,
      );

      final resp = await coordinator.process(req);

      expect(resp.tier, equals(AiRoutingTier.cloudGemini));
      // Rehydration replaced [FamilyMember_1] back to Bikram
      expect(resp.replyEn, contains('Bikram'));
      // Peanut recipe was filtered out by the deterministic post-check
      expect(resp.suggestedRecipes, contains(dalRecipe));
      expect(resp.suggestedRecipes, isNot(contains(peanutRecipe)));
      expect(resp.safetyFiltered, isTrue);
      expect(resp.actions.any((a) => a.type == ActionType.cookNow), isTrue);
    });
  });
}
