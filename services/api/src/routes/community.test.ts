import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { app } from '../index.js';
import { CommunityWorkflowService } from '../community/community_workflow.js';

describe('Community & Moderation API Route Tests', () => {
  beforeEach(() => {
    CommunityWorkflowService.resetStore();
  });

  it('POST /v1/community/contribute/recipe accepts valid recipe and auto-approves with community badge', async () => {
    const payload = {
      titleEn: 'Gorkhali Lamb Curry',
      titleNe: 'गोर्खाली खसीको मासु',
      cuisine: 'Khas/Parbate',
      servings: 4,
      prepTimeMinutes: 15,
      cookTimeMinutes: 30,
      whistleCount: 5,
      ingredients: [
        { nameEn: 'Mutton', nameNe: 'खसीको मासु', quantity: 500, unit: 'g' },
        { nameEn: 'Mustard Oil', nameNe: 'तोरीको तेल', quantity: 40, unit: 'ml' },
      ],
      steps: [
        { order: 1, instructionEn: 'Brown meat in mustard oil.', instructionNe: 'तोरीको तेलमा मासु भुट्नुहोस्।' },
        { order: 2, instructionEn: 'Add spices, water, and cook for 5 whistles.', instructionNe: 'मसला र पानी हालेर ५ सिट्ठी लगाउनुहोस्।', isWhistleStep: true, whistles: 5 },
      ],
      author: { householdId: 'hh_pokhara_01', displayName: 'Bikash Gurung' },
      culturalStory: 'A robust mountain curry made during Dashain gatherings in the hills of Gorkha.',
    };

    const res = await app.request('/v1/community/contribute/recipe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    assert.strictEqual(res.status, 201);
    const data = (await res.json()) as any;
    assert.ok(data.id);
    assert.strictEqual(data.status, 'auto_approved');
    assert.strictEqual(data.badge, 'community');
    assert.strictEqual(data.moderation.isSafe, true);
    assert.strictEqual(data.moderation.automatedAction, 'auto_approve_community');
  });

  it('POST /v1/community/contribute/recipe rejects prohibited medical cure claims', async () => {
    const badPayload = {
      titleEn: 'Cancer Cure Soup',
      titleNe: 'क्यान्सर निको गर्ने झोल',
      cuisine: 'Remedy',
      servings: 1,
      prepTimeMinutes: 5,
      cookTimeMinutes: 5,
      ingredients: [{ nameEn: 'Herbs', nameNe: 'जडीबुटी', quantity: 10, unit: 'g' }],
      steps: [{ order: 1, instructionEn: 'Drink to cure cancer completely.', instructionNe: 'क्यान्सर निको पार्छ' }],
      author: { householdId: 'hh_bad', displayName: 'Bad Actor' },
    };

    const res = await app.request('/v1/community/contribute/recipe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(badPayload),
    });

    assert.strictEqual(res.status, 201);
    const data = (await res.json()) as any;
    assert.strictEqual(data.status, 'rejected');
    assert.strictEqual(data.moderation.isSafe, false);
    assert.strictEqual(data.moderation.medicalClaimDetected, true);
  });

  it('POST /v1/community/contribute/ingredient-alias registers regional name', async () => {
    const aliasPayload = {
      canonicalIngredientId: 'cauliflower',
      dialectRegion: 'Newa / Kathmandu',
      aliasEn: 'Kauli',
      aliasNe: 'काउली',
      notes: 'Standard Newari colloquial term for cauliflower.',
      author: { householdId: 'hh_ktm_01', displayName: 'Suman Shrestha' },
    };

    const res = await app.request('/v1/community/contribute/ingredient-alias', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(aliasPayload),
    });

    assert.strictEqual(res.status, 201);
    const data = (await res.json()) as any;
    assert.strictEqual(data.type, 'ingredient_alias');
    assert.strictEqual(data.status, 'auto_approved');
    assert.strictEqual(data.badge, 'community');
  });

  it('POST /v1/community/contribute/price-report screens prices and flags outliers to moderation queue', async () => {
    // Normal price sighting
    const normalPrice = {
      commodityId: 'potato_red',
      commodityNameEn: 'Potato Red',
      commodityNameNe: 'आलु रातो',
      marketName: 'Asan Tole Haat',
      marketType: 'haat_bazaar',
      observedPrice: 55,
      unit: 'kg',
      district: 'Kathmandu',
      reporter: { householdId: 'hh_ktm_01', displayName: 'Pooja' },
    };

    const res1 = await app.request('/v1/community/contribute/price-report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(normalPrice),
    });

    assert.strictEqual(res1.status, 201);
    const data1 = (await res1.json()) as any;
    assert.strictEqual(data1.status, 'auto_approved');

    // Extreme price outlier (NPR 900 for potato where baseline is ~50)
    const anomalyPrice = {
      ...normalPrice,
      observedPrice: 900,
    };

    const res2 = await app.request('/v1/community/contribute/price-report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(anomalyPrice),
    });

    assert.strictEqual(res2.status, 201);
    const data2 = (await res2.json()) as any;
    assert.strictEqual(data2.status, 'flagged');
    assert.strictEqual(data2.moderation.priceAnomalyDetected, true);
  });

  it('GET /v1/community/feed returns published community items', async () => {
    // Seed an item
    await app.request('/v1/community/contribute/recipe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        titleEn: 'Aloo Tama Bodi',
        titleNe: 'आलु तामा बोडी',
        cuisine: 'Newa',
        servings: 4,
        prepTimeMinutes: 10,
        cookTimeMinutes: 20,
        ingredients: [{ nameEn: 'Bamboo Shoots', nameNe: 'तामा', quantity: 100, unit: 'g' }],
        steps: [{ order: 1, instructionEn: 'Simmer with bodi and aloo.', instructionNe: 'बोडी र आलुसँग पकाउनुहोस्।' }],
        author: { householdId: 'hh_01', displayName: 'Chef' },
      }),
    });

    const res = await app.request('/v1/community/feed');
    assert.strictEqual(res.status, 200);
    const body = (await res.json()) as any;
    assert.ok(body.total >= 1);
    assert.strictEqual(body.items[0].payload.titleEn, 'Aloo Tama Bodi');
  });

  it('Moderation Flow: flags anomaly into queue and human review promotes to "verified"', async () => {
    // 1. Submit price anomaly that gets flagged
    const anomalyPrice = {
      commodityId: 'potato_red',
      commodityNameEn: 'Potato Red',
      commodityNameNe: 'आलु रातो',
      marketName: 'Luxury Organic Store',
      marketType: 'supermarket',
      observedPrice: 400,
      unit: 'kg',
      district: 'Kathmandu',
      reporter: { householdId: 'hh_ktm_01', displayName: 'Pooja' },
    };

    const postRes = await app.request('/v1/community/contribute/price-report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(anomalyPrice),
    });
    const item = (await postRes.json()) as any;
    assert.strictEqual(item.status, 'flagged');

    // 2. Check moderation queue
    const queueRes = await app.request('/v1/community/moderation/queue');
    assert.strictEqual(queueRes.status, 200);
    const queueBody = (await queueRes.json()) as any;
    assert.ok(queueBody.total >= 1);
    const queueItem = queueBody.queue.find((q: any) => q.id === item.id);
    assert.ok(queueItem);

    // 3. Human Review: Reviewer confirms it was special imported organic cultivar and promotes it
    const reviewRes = await app.request(`/v1/community/moderation/${item.id}/review`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        reviewerId: 'editor_market_curator',
        decision: 'promote_to_verified',
        reviewerNotes: 'Verified as certified organic boutique heirloom potato.',
      }),
    });

    assert.strictEqual(reviewRes.status, 200);
    const reviewed = (await reviewRes.json()) as any;
    assert.strictEqual(reviewed.status, 'verified');
    assert.strictEqual(reviewed.badge, 'verified');
    assert.strictEqual(reviewed.reviewerId, 'editor_market_curator');
  });
});
