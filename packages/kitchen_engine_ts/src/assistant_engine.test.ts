import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  DeterministicAssistantRouter,
  DataPseudonymizer,
  SafetyGuardrail,
  ThreeTierAssistantCoordinator,
  AssistantRequest,
  OnDeviceAiProvider,
  CloudGeminiProvider,
} from './assistant_engine.js';
import { AllergenCatalog } from './allergen_engine.js';
import { RegionRecipe } from './region_pack_manager.js';

class MockOnDeviceProvider implements OnDeviceAiProvider {
  constructor(private reply?: string) {}

  async generateLocalResponse(): Promise<string | null> {
    return this.reply ?? 'Local advice: Cook gently with love for [FamilyMember_1].';
  }
}

class MockCloudGeminiProvider implements CloudGeminiProvider {
  constructor(
    private reply: string = 'I suggest making Masyaura Dal and Peanut Chutney for [FamilyMember_1].'
  ) {}

  async queryGemini(): Promise<string> {
    return this.reply;
  }
}

describe('AssistantEngine TypeScript Parity Tests', () => {
  const dalRecipe: RegionRecipe = {
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
    ingredients: [
      { ingredientId: 'musuro_dal', quantity: 200, unit: 'g' },
      { ingredientId: 'onion', quantity: 100, unit: 'g' },
    ],
    pressureCooker: {
      enabled: true,
      recommendedWhistles: 3,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'medium',
      releaseType: 'natural',
    },
    seasonality: ['all_year'],
    tags: ['dal', 'lentils'],
  };

  const peanutRecipe: RegionRecipe = {
    id: 'peanut_chutney',
    titleEn: 'Peanut Chutney',
    titleNe: 'बदामको अचार',
    category: 'Pickles & Chutneys',
    cuisine: 'Nepali',
    dietary: ['Vegetarian'],
    prepTimeMinutes: 10,
    cookTimeMinutes: 5,
    servings: 4,
    difficulty: 'Easy',
    ingredients: [
      { ingredientId: 'peanut', quantity: 100, unit: 'g' },
      { ingredientId: 'garlic', quantity: 10, unit: 'g' },
    ],
    pressureCooker: {
      enabled: false,
      recommendedWhistles: 0,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'none',
      releaseType: 'none',
    },
    seasonality: ['all_year'],
    tags: ['chutney', 'peanut'],
  };

  describe('Tier 1 Deterministic Kitchen Engine', () => {
    test('answers unit conversion queries deterministically without LLM', () => {
      const req: AssistantRequest = {
        prompt: 'How many grams in 2 pau?',
      };
      const resp = DeterministicAssistantRouter.matchQuery(req);

      assert.ok(resp);
      assert.strictEqual(resp.tier, 'deterministic');
      assert.ok(resp.replyEn.includes('2 pau is exactly 500 grams (500 g)'));
    });

    test('answers mana and dharni volume/mass queries', () => {
      const req1: AssistantRequest = { prompt: 'Convert 1 mana to ml' };
      const resp1 = DeterministicAssistantRouter.matchQuery(req1);
      assert.ok(resp1?.replyEn.includes('568 ml'));

      const req2: AssistantRequest = { prompt: 'What is 1 dharni in kg?' };
      const resp2 = DeterministicAssistantRouter.matchQuery(req2);
      assert.ok(resp2?.replyEn.includes('2.5 kg'));
    });

    test('answers altitude boiling point queries', () => {
      const req: AssistantRequest = {
        prompt: 'What is the water boiling point in Kathmandu?',
        currentElevationMeters: 1400,
      };
      const resp = DeterministicAssistantRouter.matchQuery(req);

      assert.ok(resp);
      assert.ok(resp.replyEn.includes('1400m elevation'));
      assert.ok(resp.replyEn.includes('95.1°C'));
    });

    test('whistle count lookup provides executable Cook Now and Add to Plan actions', () => {
      const req: AssistantRequest = {
        prompt: 'How many whistles for masyaura dal?',
        catalogRecipes: [dalRecipe],
        currentElevationMeters: 1400,
      };
      const resp = DeterministicAssistantRouter.matchQuery(req);

      assert.ok(resp);
      assert.strictEqual(resp.tier, 'deterministic');
      assert.ok(resp.replyEn.includes('Masyaura Dal takes 4 whistles'));
      assert.strictEqual(resp.actions.length, 2);
      assert.strictEqual(resp.actions[0].type, 'cookNow');
      assert.strictEqual(resp.actions[0].whistles, 4);
      assert.strictEqual(resp.actions[1].type, 'addToPlan');
    });

    test('pantry search suggests recipes with executable actions', () => {
      const req: AssistantRequest = {
        prompt: 'What can I cook with musuro dal?',
        catalogRecipes: [dalRecipe],
        pantryIngredientIds: ['musuro_dal'],
      };
      const resp = DeterministicAssistantRouter.matchQuery(req);

      assert.ok(resp);
      assert.ok(resp.suggestedRecipes?.some((r) => r.id === dalRecipe.id));
      assert.ok(resp.actions.some((a) => a.type === 'cookNow'));
    });

    test('leftover safety answers shelf life deterministically', () => {
      const req: AssistantRequest = {
        prompt: 'How long does cooked dal last in the fridge?',
      };
      const resp = DeterministicAssistantRouter.matchQuery(req);

      assert.ok(resp);
      assert.ok(resp.replyEn.includes('48 hours'));
      assert.strictEqual(resp.actions[0].type, 'viewRecipe');
    });
  });

  describe('Guardrails & Privacy', () => {
    test('DataPseudonymizer scrubs household names and PII', () => {
      const prompt =
        'Please suggest a dinner for Bikram and Sita. Email: bikram@example.com, Phone: 9841234567';
      const res = DataPseudonymizer.pseudonymize(prompt, ['Bikram', 'Sita']);

      assert.ok(!res.text.includes('Bikram'));
      assert.ok(!res.text.includes('Sita'));
      assert.ok(res.text.includes('[FamilyMember_1]'));
      assert.ok(res.text.includes('[FamilyMember_2]'));
      assert.ok(res.text.includes('[Email_Scrubbed]'));
      assert.ok(res.text.includes('[Phone_Scrubbed]'));

      const rehydrated = DataPseudonymizer.rehydrate(
        'Dinner ready for [FamilyMember_1] and [FamilyMember_2]!',
        res.nameMap
      );
      assert.strictEqual(rehydrated, 'Dinner ready for Bikram and Sita!');
    });

    test('Blocks medical and pediatric calorie advice per Section 22.2', () => {
      assert.strictEqual(
        SafetyGuardrail.isMedicalOrPediatricCalorieQuery(
          'What is the pediatric calorie target for my baby?'
        ),
        true
      );
      assert.strictEqual(
        SafetyGuardrail.isMedicalOrPediatricCalorieQuery('Calorie limit for my toddler'),
        true
      );
      assert.strictEqual(
        SafetyGuardrail.isMedicalOrPediatricCalorieQuery('How many calories in this dal?'),
        false
      );

      const resp = SafetyGuardrail.buildMedicalSafetyResponse();
      assert.ok(resp.replyEn.includes('does not provide medical or pediatric calorie targets'));
      assert.ok(resp.replyEn.includes('family pediatrician'));
      assert.strictEqual(resp.actions.length, 0);
    });

    test('Strict deterministic allergen post-check excludes unsafe AI recommendations', () => {
      const postCheck = SafetyGuardrail.postCheckRecipes({
        candidates: [dalRecipe, peanutRecipe],
        memberAllergies: [
          {
            allergen: AllergenCatalog.peanuts,
            severity: 'severe',
            memberName: 'Bikram',
          },
        ],
      });

      assert.ok(postCheck.safeRecipes.some((r) => r.id === dalRecipe.id));
      assert.ok(!postCheck.safeRecipes.some((r) => r.id === peanutRecipe.id));
      assert.strictEqual(postCheck.hadUnsafeFiltered, true);
      assert.ok(postCheck.notes[0].includes('Peanut Chutney'));
    });
  });

  describe('ThreeTierAssistantCoordinator Integration', () => {
    test('returns deterministic response if matched, bypassing AI tiers', async () => {
      const coordinator = new ThreeTierAssistantCoordinator({
        onDeviceProvider: new MockOnDeviceProvider(),
        cloudProvider: new MockCloudGeminiProvider(),
      });

      const req: AssistantRequest = {
        prompt: 'Convert 2 pau to grams',
      };
      const resp = await coordinator.process(req);

      assert.strictEqual(resp.tier, 'deterministic');
      assert.ok(resp.replyEn.includes('500 grams'));
    });

    test('requires explicit cloud consent before routing to Cloud Gemini', async () => {
      const coordinator = new ThreeTierAssistantCoordinator({
        cloudProvider: new MockCloudGeminiProvider(),
      });

      const req: AssistantRequest = {
        prompt: 'Suggest a creative fusion dinner for Bikram',
        hasCloudConsent: false,
      };
      const resp = await coordinator.process(req);

      assert.strictEqual(resp.consentPromptRequired, true);
      assert.ok(resp.replyEn.includes('enable cloud assistance'));
    });

    test('routes to Cloud Gemini with consent, pseudonymizing and filtering allergens', async () => {
      const coordinator = new ThreeTierAssistantCoordinator({
        cloudProvider: new MockCloudGeminiProvider(),
      });

      const req: AssistantRequest = {
        prompt: 'Suggest a creative fusion dinner for Bikram',
        householdMemberNames: ['Bikram'],
        memberAllergies: [
          {
            allergen: AllergenCatalog.peanuts,
            severity: 'severe',
            memberName: 'Bikram',
          },
        ],
        catalogRecipes: [dalRecipe, peanutRecipe],
        hasCloudConsent: true,
      };

      const resp = await coordinator.process(req);

      assert.strictEqual(resp.tier, 'cloudGemini');
      assert.ok(resp.replyEn.includes('Bikram'));
      assert.ok(resp.suggestedRecipes?.some((r) => r.id === dalRecipe.id));
      assert.ok(!resp.suggestedRecipes?.some((r) => r.id === peanutRecipe.id));
      assert.strictEqual(resp.safetyFiltered, true);
      assert.ok(resp.actions.some((a) => a.type === 'cookNow'));
    });
  });
});
