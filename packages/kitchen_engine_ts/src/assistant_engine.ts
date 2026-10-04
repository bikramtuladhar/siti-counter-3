import {
  checkRecipeSafety,
  AllergenCatalog,
  MemberAllergyProfile,
  DietaryRule,
} from './allergen_engine.js';
import { UnitConverter, AltitudeCalculator } from './index.js';
import { RegionRecipe } from './region_pack_manager.js';
import { WasteEngine, StorageCondition, ClimateZone } from './waste_engine.js';

export type AiRoutingTier = 'deterministic' | 'onDevice' | 'cloudGemini';

export type ActionType =
  | 'cookNow'
  | 'addToPlan'
  | 'addToList'
  | 'startTimer'
  | 'viewRecipe';

export interface ExecutableAction {
  type: ActionType;
  labelEn: string;
  labelNe: string;
  recipeId?: string;
  recipeTitleEn?: string;
  recipeTitleNe?: string;
  whistles?: number;
  timerMinutes?: number;
  ingredientsToAdd?: string[];
}

export interface AssistantRequest {
  prompt: string;
  currentLanguage?: string;
  householdMemberNames?: string[];
  memberAllergies?: MemberAllergyProfile[];
  dietaryRules?: DietaryRule[];
  catalogRecipes?: RegionRecipe[];
  pantryIngredientIds?: string[];
  currentElevationMeters?: number;
  hasCloudConsent?: boolean;
}

export interface AssistantResponse {
  tier: AiRoutingTier;
  replyEn: string;
  replyNe: string;
  suggestedRecipes?: RegionRecipe[];
  actions: ExecutableAction[];
  safetyVerified: boolean;
  safetyFiltered?: boolean;
  safetyNotes?: string[];
  consentPromptRequired?: boolean;
}

export interface PseudonymizedResult {
  text: string;
  nameMap: Record<string, string>;
}

export class DataPseudonymizer {
  private static readonly emailRegex =
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;
  private static readonly phoneRegex =
    /\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/g;

  static pseudonymize(input: string, knownNames: string[] = []): PseudonymizedResult {
    let scrubbed = input.replace(this.emailRegex, '[Email_Scrubbed]');
    scrubbed = scrubbed.replace(this.phoneRegex, '[Phone_Scrubbed]');

    const nameMap: Record<string, string> = {};
    let memberIndex = 1;

    for (const name of knownNames) {
      if (!name || name.trim().length === 0) continue;
      const token = `[FamilyMember_${memberIndex}]`;
      const regex = new RegExp(`\\b${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'gi');
      if (regex.test(scrubbed)) {
        scrubbed = scrubbed.replace(regex, token);
        nameMap[token] = name;
        memberIndex++;
      }
    }

    return { text: scrubbed, nameMap };
  }

  static rehydrate(text: string, nameMap: Record<string, string>): string {
    let rehydrated = text;
    for (const [token, originalName] of Object.entries(nameMap)) {
      rehydrated = rehydrated.replaceAll(token, originalName);
    }
    return rehydrated;
  }
}

export class SafetyGuardrail {
  private static readonly medicalCaloriePatterns: RegExp[] = [
    /\b(pediatric|baby|toddler|infant|child)\b.*?\b(calorie|calories|calorie target|calorie deficit|diet|nutrition plan)\b/i,
    /\b(how many calories|calorie limit|calorie target|diet plan)\b.*?\b(baby|toddler|child|infant|\d+\s*year old)\b/i,
    /\b(cure diabetes|insulin dose|treat cancer|medical diet|starvation diet)\b/i,
  ];

  static isMedicalOrPediatricCalorieQuery(prompt: string): boolean {
    return this.medicalCaloriePatterns.some((pattern) => pattern.test(prompt));
  }

  static buildMedicalSafetyResponse(): AssistantResponse {
    return {
      tier: 'deterministic',
      replyEn:
        'Siti Counter is designed for wholesome home cooking and family meals, but does not provide medical or pediatric calorie targets. For child growth and nutrition advice, please consult your family pediatrician.',
      replyNe:
        'सिट्ठी काउन्टर स्वस्थ घरायसी खाना पकाउनको लागि हो, तर यसले चिकित्सा वा बालबालिकाको क्यालोरी सम्बन्धी सल्लाह दिँदैन। बालबालिकाको पोषणको लागि कृपया बालरोग विशेषज्ञसँग परामर्श लिनुहोस्।',
      safetyVerified: true,
      actions: [],
      safetyNotes: ['Pediatric calorie advice blocked per Section 22.2 safety policy.'],
    };
  }

  static postCheckRecipes({
    candidates,
    memberAllergies = [],
    dietaryRules = [],
  }: {
    candidates: RegionRecipe[];
    memberAllergies?: MemberAllergyProfile[];
    dietaryRules?: DietaryRule[];
  }): {
    safeRecipes: RegionRecipe[];
    hadUnsafeFiltered: boolean;
    notes: string[];
  } {
    const safeRecipes: RegionRecipe[] = [];
    let hadUnsafeFiltered = false;
    const notes: string[] = [];

    for (const recipe of candidates) {
      const ingredientIds = recipe.ingredients.map((i) => i.ingredientId);
      const verdict = checkRecipeSafety({
        ingredientIds,
        allergyProfiles: memberAllergies,
        dietaryRules,
      });

      if (verdict.isSafe && !verdict.hasSevereConflict) {
        safeRecipes.push(recipe);
      } else {
        hadUnsafeFiltered = true;
        const reason = verdict.primaryWarning || 'Excluded due to household allergy/dietary safety';
        notes.push(`Excluded "${recipe.titleEn}": ${reason}`);
      }
    }

    return { safeRecipes, hadUnsafeFiltered, notes };
  }
}

export class DeterministicAssistantRouter {
  static matchQuery(request: AssistantRequest): AssistantResponse | null {
    const prompt = request.prompt.toLowerCase().trim();
    const elevation = request.currentElevationMeters ?? 1400;

    // 1. Unit Conversions (Pau, Mana, Dharni)
    const pauMatch = /(\d+(?:\.\d+)?)\s*(?:pau|पाउ)/i.exec(prompt);
    if (pauMatch && (prompt.includes('gram') || prompt.includes('g') || prompt.includes('how much') || prompt.includes('कति'))) {
      const pauVal = parseFloat(pauMatch[1]);
      const grams = UnitConverter.pauToGrams(pauVal);
      const gramsFormatted = Math.round(grams);
      return {
        tier: 'deterministic',
        replyEn: `${pauVal} pau is exactly ${gramsFormatted} grams (${gramsFormatted} g).`,
        replyNe: `${pauVal} पाउ बराबर ठीक ${gramsFormatted} ग्राम हुन्छ।`,
        actions: [],
        safetyVerified: true,
      };
    }

    const manaMatch = /(\d+(?:\.\d+)?)\s*(?:mana|माना)/i.exec(prompt);
    if (manaMatch && (prompt.includes('ml') || prompt.includes('liter') || prompt.includes('how much') || prompt.includes('कति'))) {
      const manaVal = parseFloat(manaMatch[1]);
      const ml = UnitConverter.manaToMl(manaVal);
      const mlFormatted = Math.round(ml);
      return {
        tier: 'deterministic',
        replyEn: `${manaVal} mana is approximately ${mlFormatted} ml (${(ml / 1000).toFixed(2)} liters).`,
        replyNe: `${manaVal} माना लगभग ${mlFormatted} मि.लि. (${(ml / 1000).toFixed(2)} लिटर) हुन्छ।`,
        actions: [],
        safetyVerified: true,
      };
    }

    const dharniMatch = /(\d+(?:\.\d+)?)\s*(?:dharni|धार्नी)/i.exec(prompt);
    if (dharniMatch && (prompt.includes('kg') || prompt.includes('gram') || prompt.includes('कति'))) {
      const dharniVal = parseFloat(dharniMatch[1]);
      const grams = UnitConverter.dharniToGrams(dharniVal);
      const kg = grams / 1000;
      return {
        tier: 'deterministic',
        replyEn: `${dharniVal} dharni is exactly ${kg % 1 === 0 ? kg : kg.toFixed(1)} kg (${grams} g).`,
        replyNe: `${dharniVal} धार्नी बराबर ठीक ${kg % 1 === 0 ? kg : kg.toFixed(1)} के.जी. (${grams} ग्राम) हुन्छ।`,
        actions: [],
        safetyVerified: true,
      };
    }

    // 2. Altitude Adjustments
    if (prompt.includes('altitude') || prompt.includes('boiling point') || prompt.includes('उमाल्ने बिन्दु')) {
      const bp = AltitudeCalculator.boilingPointCelsius(elevation);
      const bpFormatted = bp.toFixed(1);
      return {
        tier: 'deterministic',
        replyEn: `At ${Math.round(elevation)}m elevation, water boils at ${bpFormatted}°C (below the 100°C sea level baseline). Pressure cooking is recommended for pulses & grains.`,
        replyNe: `${Math.round(elevation)} मिटरको उचाइमा पानी ${bpFormatted}°C मा उम्लन्छ। दाल र गेडागुडीको लागि प्रेसर कुकर उपयुक्त हुन्छ।`,
        actions: [],
        safetyVerified: true,
      };
    }

    // 3. Whistle & Timer Lookup
    if (prompt.includes('whistle') || prompt.includes('siti') || prompt.includes('सिट्ठी')) {
      const catalog = request.catalogRecipes || [];
      for (const recipe of catalog) {
        if (
          prompt.includes(recipe.titleEn.toLowerCase()) ||
          prompt.includes(recipe.id.replace(/_/g, ' '))
        ) {
          const target = recipe.pressureCooker?.enabled
            ? recipe.pressureCooker.recommendedWhistles
            : 0;
          const adjusted = AltitudeCalculator.adjustSitiCount(target, elevation);

          return {
            tier: 'deterministic',
            replyEn: `${recipe.titleEn} takes ${adjusted} whistles in the pressure cooker (tested at ${Math.round(elevation)}m).`,
            replyNe: `${recipe.titleNe} पकाउन प्रेसर कुकरमा ${adjusted} सिट्ठी चाहिन्छ।`,
            suggestedRecipes: [recipe],
            actions: [
              {
                type: 'cookNow',
                labelEn: `Cook Now (${adjusted} Whistles)`,
                labelNe: `अहिले पकाउनुहोस् (${adjusted} सिट्ठी)`,
                recipeId: recipe.id,
                recipeTitleEn: recipe.titleEn,
                recipeTitleNe: recipe.titleNe,
                whistles: adjusted,
              },
              {
                type: 'addToPlan',
                labelEn: 'Add to Meal Plan',
                labelNe: 'खाना तालिकामा थप्नुहोस्',
                recipeId: recipe.id,
                recipeTitleEn: recipe.titleEn,
                recipeTitleNe: recipe.titleNe,
              },
            ],
            safetyVerified: true,
          };
        }
      }
    }

    // 4. Pantry & Available Ingredient Matching
    if (prompt.includes('what can i cook') || prompt.includes('recipes with') || prompt.includes('के पकाउने')) {
      const catalog = request.catalogRecipes || [];
      const pantry = request.pantryIngredientIds || [];

      const matchingRecipes = catalog.filter((recipe) => {
        const recipeIngs = recipe.ingredients.map((i) => i.ingredientId.toLowerCase());
        for (const p of pantry) {
          if (recipeIngs.includes(p.toLowerCase())) return true;
        }
        for (const part of prompt.split(/[, ]+/)) {
          if (part.length >= 4 && recipeIngs.some((i) => i.includes(part))) {
            return true;
          }
        }
        return false;
      });

      if (matchingRecipes.length > 0) {
        const postCheck = SafetyGuardrail.postCheckRecipes({
          candidates: matchingRecipes,
          memberAllergies: request.memberAllergies,
          dietaryRules: request.dietaryRules,
        });

        const safeList = postCheck.safeRecipes;
        if (safeList.length > 0) {
          const topRecipe = safeList[0];
          const namesEn = safeList.slice(0, 3).map((r) => r.titleEn).join(', ');
          const namesNe = safeList.slice(0, 3).map((r) => r.titleNe).join(', ');

          return {
            tier: 'deterministic',
            replyEn: `Based on your available ingredients, you can make: ${namesEn}.`,
            replyNe: `तपाईंसँग भएका सामग्रीबाट बनाउन मिल्ने परिकारहरू: ${namesNe}।`,
            suggestedRecipes: safeList.slice(0, 3),
            safetyVerified: true,
            safetyFiltered: postCheck.hadUnsafeFiltered,
            safetyNotes: postCheck.notes,
            actions: [
              {
                type: 'cookNow',
                labelEn: `Cook ${topRecipe.titleEn}`,
                labelNe: `${topRecipe.titleNe} पकाउनुहोस्`,
                recipeId: topRecipe.id,
                recipeTitleEn: topRecipe.titleEn,
                recipeTitleNe: topRecipe.titleNe,
                whistles: topRecipe.pressureCooker?.recommendedWhistles,
              },
              {
                type: 'addToList',
                labelEn: 'Add Missing Items to List',
                labelNe: 'बाँकी सामग्री सूचीमा थप्नुहोस्',
                recipeId: topRecipe.id,
              },
            ],
          };
        }
      }
    }

    // 5. Leftover / Shelf-Life queries
    if (
      prompt.includes('leftover') ||
      prompt.includes('shelf life') ||
      prompt.includes('बाँकी खाना') ||
      prompt.includes('how long does')
    ) {
      let dish = 'dal';
      if (prompt.includes('rice') || prompt.includes('bhat') || prompt.includes('भात')) {
        dish = 'bhat';
      } else if (prompt.includes('roti') || prompt.includes('रोटी')) {
        dish = 'roti';
      }

      const hours = WasteEngine.getBaseShelfLifeHours({
        dishCategory: dish,
        storage: 'refrigerated',
        climate: 'temperate',
      });
      const days = Math.round(hours / 24);

      return {
        tier: 'deterministic',
        replyEn: `Refrigerated cooked ${dish} stays fresh for about ${hours} hours (~${days} days). For best taste and nutrition, consume within this window.`,
        replyNe: `फ्रिजमा राखिएको पाकेको ${dish} लगभग ${hours} घण्टा (~${days} दिन) सम्म ताजा रहन्छ।`,
        actions: [
          {
            type: 'viewRecipe',
            labelEn: 'View Leftovers Tracker',
            labelNe: 'बाँकी खाना हेर्नुहोस्',
          },
        ],
        safetyVerified: true,
      };
    }

    return null;
  }
}

export interface OnDeviceAiProvider {
  generateLocalResponse(args: {
    pseudonymizedPrompt: string;
    language?: string;
  }): Promise<string | null>;
}

export interface CloudGeminiProvider {
  queryGemini(args: {
    pseudonymizedPrompt: string;
    language?: string;
  }): Promise<string>;
}

export class ThreeTierAssistantCoordinator {
  constructor(
    private readonly options?: {
      onDeviceProvider?: OnDeviceAiProvider;
      cloudProvider?: CloudGeminiProvider;
    }
  ) {}

  async process(request: AssistantRequest): Promise<AssistantResponse> {
    // Guardrail Step 0: Check for Medical or Pediatric Calorie triggers
    if (SafetyGuardrail.isMedicalOrPediatricCalorieQuery(request.prompt)) {
      return SafetyGuardrail.buildMedicalSafetyResponse();
    }

    // Tier 1: Deterministic Kitchen Engine
    const deterministicMatch = DeterministicAssistantRouter.matchQuery(request);
    if (deterministicMatch) {
      return deterministicMatch;
    }

    // Pseudonymize prompt before evaluating any generative model
    const pseudonymResult = DataPseudonymizer.pseudonymize(
      request.prompt,
      request.householdMemberNames || []
    );

    // Tier 2: On-Device Model
    if (this.options?.onDeviceProvider) {
      const localReply = await this.options.onDeviceProvider.generateLocalResponse({
        pseudonymizedPrompt: pseudonymResult.text,
        language: request.currentLanguage,
      });

      if (localReply && localReply.trim().length > 0) {
        const rehydrated = DataPseudonymizer.rehydrate(localReply, pseudonymResult.nameMap);
        return {
          tier: 'onDevice',
          replyEn: rehydrated,
          replyNe: rehydrated,
          safetyVerified: true,
          actions: this.extractDefaultActions(request),
        };
      }
    }

    // Tier 3: Cloud Gemini Online - strictly requires explicit user consent
    if (!request.hasCloudConsent) {
      return {
        tier: 'deterministic',
        replyEn:
          'To answer this creative culinary question with Cloud Gemini AI, please enable cloud assistance. Your personal data is always pseudonymized before transmission.',
        replyNe:
          'क्लाउड जेमिनी एआईबाट यो प्रश्नको जवाफ पाउन कृपया क्लाउड अनुमति दिनुहोस्। तपाईंको व्यक्तिगत विवरण सधैँ सुरक्षित र नामरहित बनाइन्छ।',
        consentPromptRequired: true,
        safetyVerified: true,
        actions: [],
      };
    }

    // Route to Cloud Gemini
    if (this.options?.cloudProvider) {
      const cloudReplyRaw = await this.options.cloudProvider.queryGemini({
        pseudonymizedPrompt: pseudonymResult.text,
        language: request.currentLanguage,
      });

      const rehydrated = DataPseudonymizer.rehydrate(cloudReplyRaw, pseudonymResult.nameMap);

      // Deterministic allergen post-check on matched recipes
      const catalog = request.catalogRecipes || [];
      const matchedRecipes = catalog.filter((r) =>
        rehydrated.toLowerCase().includes(r.titleEn.toLowerCase())
      );

      const postCheck = SafetyGuardrail.postCheckRecipes({
        candidates: matchedRecipes,
        memberAllergies: request.memberAllergies,
        dietaryRules: request.dietaryRules,
      });

      const actions: ExecutableAction[] = [];
      for (const rec of postCheck.safeRecipes.slice(0, 2)) {
        actions.push({
          type: 'cookNow',
          labelEn: `Cook ${rec.titleEn}`,
          labelNe: `${rec.titleNe} पकाउनुहोस्`,
          recipeId: rec.id,
          recipeTitleEn: rec.titleEn,
          recipeTitleNe: rec.titleNe,
          whistles: rec.pressureCooker?.recommendedWhistles,
        });
        actions.push({
          type: 'addToPlan',
          labelEn: 'Add to Plan',
          labelNe: 'तालिकामा थप्नुहोस्',
          recipeId: rec.id,
          recipeTitleEn: rec.titleEn,
          recipeTitleNe: rec.titleNe,
        });
      }

      return {
        tier: 'cloudGemini',
        replyEn: rehydrated,
        replyNe: rehydrated,
        suggestedRecipes: postCheck.safeRecipes,
        actions: actions.length > 0 ? actions : this.extractDefaultActions(request),
        safetyVerified: true,
        safetyFiltered: postCheck.hadUnsafeFiltered,
        safetyNotes: postCheck.notes,
      };
    }

    return {
      tier: 'deterministic',
      replyEn:
        'I am here to help with cooking timers, pantry ideas, conversions, and whistle counting. How can I assist in the kitchen today?',
      replyNe:
        'म भान्सामा सिट्ठी गन्न, खानाको तालिका बनाउन, र सामग्री रूपान्तरण गर्न मद्दत गर्दछु।',
      safetyVerified: true,
      actions: [],
    };
  }

  private extractDefaultActions(request: AssistantRequest): ExecutableAction[] {
    const catalog = request.catalogRecipes || [];
    if (catalog.length === 0) return [];
    const first = catalog[0];
    return [
      {
        type: 'cookNow',
        labelEn: `Cook ${first.titleEn}`,
        labelNe: `${first.titleNe} पकाउनुहोस्`,
        recipeId: first.id,
        recipeTitleEn: first.titleEn,
        recipeTitleNe: first.titleNe,
        whistles: first.pressureCooker?.recommendedWhistles,
      },
    ];
  }
}
