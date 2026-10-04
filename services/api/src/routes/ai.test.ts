import test from 'node:test';
import assert from 'node:assert/strict';
import { app } from '../index.js';
import { AssistantResponse, AllergenCatalog, RegionRecipe } from '@siti-counter/kitchen-engine';

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

test('POST /v1/ai/assistant rejects requests with empty or missing prompt', async () => {
  const res = await app.request('/v1/ai/assistant', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
  });
  assert.equal(res.status, 400);
  const data = (await res.json()) as { error: string };
  assert.equal(data.error, 'INVALID_PROMPT');
});

test('POST /v1/ai/assistant blocks medical & pediatric calorie advice without LLM call', async () => {
  const prompts = [
    'What is the daily calorie limit for my 3-year-old toddler?',
    'Can this dal cure diabetes and heart disease?',
    'How many calories should an infant eat per day?',
  ];

  for (const prompt of prompts) {
    const res = await app.request('/v1/ai/assistant', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt }),
    });

    assert.equal(res.status, 200);
    const data = (await res.json()) as AssistantResponse;
    assert.equal(data.tier, 'deterministic');
    assert.match(data.replyEn, /pediatrician|medical professional|qualified healthcare provider/i);
    assert.equal(data.actions.length, 0);
  }
});

test('POST /v1/ai/assistant handles deterministic Tier 1 queries offline without consent', async () => {
  const res = await app.request('/v1/ai/assistant', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      prompt: 'How many grams in 2 pau?',
      hasCloudConsent: false,
    }),
  });

  assert.equal(res.status, 200);
  const data = (await res.json()) as AssistantResponse;
  assert.equal(data.tier, 'deterministic');
  assert.match(data.replyEn, /500 grams/);
});

test('POST /v1/ai/assistant returns 403 consent prompt when cloud query lacks consent', async () => {
  const res = await app.request('/v1/ai/assistant', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      prompt: 'Suggest an elaborate festival menu for Dashain with story and traditions',
      hasCloudConsent: false,
    }),
  });

  assert.equal(res.status, 403);
  const data = (await res.json()) as AssistantResponse;
  assert.equal(data.consentPromptRequired, true);
  assert.match(data.replyEn, /enable cloud assistance/i);
});

test('POST /v1/ai/assistant returns 200 with Cloud Gemini when cloud consent is provided', async () => {
  const res = await app.request('/v1/ai/assistant', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      prompt: 'Suggest an elaborate festival menu for Dashain with Aarav and Sunita',
      householdMemberNames: ['Aarav', 'Sunita'],
      hasCloudConsent: true,
      catalogRecipes: [dalRecipe],
    }),
  });

  assert.equal(res.status, 200);
  const data = (await res.json()) as AssistantResponse;
  assert.equal(data.tier, 'cloudGemini');
  assert.ok(!data.consentPromptRequired);
  // Aarav and Sunita should be de-pseudonymized
  assert.match(data.replyEn, /family|Masyaura/i);
});

test('POST /v1/ai/assistant applies deterministic allergen post-check on cloud results', async () => {
  const res = await app.request('/v1/ai/assistant', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      prompt: 'What can we cook today?',
      hasCloudConsent: true,
      memberAllergies: [
        {
          allergen: AllergenCatalog.peanuts,
          severity: 'severe',
          memberName: 'Bikram',
        },
      ],
      catalogRecipes: [dalRecipe, peanutRecipe],
    }),
  });

  assert.equal(res.status, 200);
  const data = (await res.json()) as AssistantResponse;
  assert.equal(data.tier, 'cloudGemini');
  // Peanut chutney must NOT be included in suggested actions due to peanut allergy
  const dangerousAction = data.actions.find((a) => a.recipeId === 'peanut_chutney');
  assert.equal(dangerousAction, undefined);
});
