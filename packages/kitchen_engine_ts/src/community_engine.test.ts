import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  CommunityModerationEngine,
  CommunityRecipePayload,
  CommunityIngredientAliasPayload,
  CommunityPriceReportPayload,
  CommunityContribution,
} from './community_engine.js';

describe('CommunityModerationEngine TypeScript Unit Tests', () => {
  it('screens valid authentic community recipe and auto-approves as community', () => {
    const validRecipe: CommunityRecipePayload = {
      titleEn: 'Kwati (Mixed Sprouted Bean Curry)',
      titleNe: 'क्वाँटी',
      cuisine: 'Newa',
      servings: 6,
      prepTimeMinutes: 20,
      cookTimeMinutes: 35,
      whistleCount: 4,
      ingredients: [
        { nameEn: 'Sprouted Mixed Beans', nameNe: 'टुसा उम्रेको गेडागुडी', quantity: 500, unit: 'g' },
        { nameEn: 'Ajwain (Jowano)', nameNe: 'ज्वायन', quantity: 5, unit: 'g' },
        { nameEn: 'Mustard Oil', nameNe: 'तोरीको तेल', quantity: 30, unit: 'ml' },
      ],
      steps: [
        { order: 1, instructionEn: 'Heat mustard oil and splutter ajwain.', instructionNe: 'तोरीको तेल तताएर ज्वायन पड्काउनुहोस्।' },
        { order: 2, instructionEn: 'Add soaked kwati beans and fry for 5 minutes.', instructionNe: 'क्वाँटी हालेर ५ मिनेट भुट्नुहोस्।' },
        { order: 3, instructionEn: 'Add warm water, seal lid, and cook for 4 whistles.', instructionNe: 'पानी हालेर बिर्को लगाई ४ सिट्ठी लगाउनुहोस्।', isWhistleStep: true, whistles: 4 },
      ],
      author: { householdId: 'hh_ktm_01', displayName: 'Sunita Shakya' },
      culturalStory: 'Traditional Gunhu Punhi festive recipe passed down across four generations in Patan.',
    };

    const scorecard = CommunityModerationEngine.screenRecipe(validRecipe);
    assert.strictEqual(scorecard.isSafe, true);
    assert.strictEqual(scorecard.profanityDetected, false);
    assert.strictEqual(scorecard.medicalClaimDetected, false);
    assert.strictEqual(scorecard.automatedAction, 'auto_approve_community');
    assert.strictEqual(scorecard.suggestedBadge, 'community');
    assert.ok(scorecard.feedbackEn.includes('Published as Community recipe'));
  });

  it('detects and rejects recipes containing medical cure claims (Section 22 guardrail)', () => {
    const medicalRecipe: CommunityRecipePayload = {
      titleEn: 'Miracle Garlic Tea',
      titleNe: 'लसुनको जादुयी चिया',
      cuisine: 'Home Remedy',
      servings: 2,
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      ingredients: [{ nameEn: 'Garlic', nameNe: 'लसुन', quantity: 4, unit: 'cloves' }],
      steps: [{ order: 1, instructionEn: 'Drink every morning because this recipe cures cancer completely.', instructionNe: 'पिउनुहोस् किनकि यसले क्यान्सर निको गर्छ।' }],
      author: { householdId: 'hh_spammer', displayName: 'Remedy Guru' },
    };

    const scorecard = CommunityModerationEngine.screenRecipe(medicalRecipe);
    assert.strictEqual(scorecard.isSafe, false);
    assert.strictEqual(scorecard.medicalClaimDetected, true);
    assert.strictEqual(scorecard.automatedAction, 'auto_reject');
    assert.ok(scorecard.structuralIssues.some((issue) => issue.includes('medical cure or treatment')));
  });

  it('detects and rejects recipes containing profanity or abusive language', () => {
    const offensiveRecipe: CommunityRecipePayload = {
      titleEn: 'Scam Food fake',
      titleNe: 'नक्कली खाना',
      cuisine: 'Modern',
      servings: 2,
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      ingredients: [{ nameEn: 'Salt', nameNe: 'नुन', quantity: 1, unit: 'g' }],
      steps: [{ order: 1, instructionEn: 'This is bullshit scam recipe.', instructionNe: 'नक्कली' }],
      author: { householdId: 'hh_troll', displayName: 'Troll' },
    };

    const scorecard = CommunityModerationEngine.screenRecipe(offensiveRecipe);
    assert.strictEqual(scorecard.isSafe, false);
    assert.strictEqual(scorecard.profanityDetected, true);
    assert.strictEqual(scorecard.automatedAction, 'auto_reject');
  });

  it('screens regional ingredient aliases and flags spam/links', () => {
    const validAlias: CommunityIngredientAliasPayload = {
      canonicalIngredientId: 'cauliflower',
      dialectRegion: 'Newa / Kathmandu',
      aliasEn: 'Kauli',
      aliasNe: 'काउली',
      notes: 'Colloquially referred to as Kauli in Kathmandu Valley.',
      author: { householdId: 'hh_ktm_01', displayName: 'Prakash Maharjan' },
    };

    const validResult = CommunityModerationEngine.screenIngredientAlias(validAlias);
    assert.strictEqual(validResult.isSafe, true);
    assert.strictEqual(validResult.automatedAction, 'auto_approve_community');

    const spamAlias: CommunityIngredientAliasPayload = {
      canonicalIngredientId: 'potato',
      dialectRegion: 'Spam',
      aliasEn: 'Check https://buycheapcrypto.com for potatoes',
      aliasNe: 'आलु',
      author: { householdId: 'hh_spam', displayName: 'Bot' },
    };

    const spamResult = CommunityModerationEngine.screenIngredientAlias(spamAlias);
    assert.strictEqual(spamResult.isSafe, false);
    assert.strictEqual(spamResult.automatedAction, 'auto_reject');
  });

  it('screens price reports and flags extreme anomalies against Kalimati baseline', () => {
    // Baseline price for potato is 50 NPR/kg
    const normalPrice: CommunityPriceReportPayload = {
      commodityId: 'potato_red',
      commodityNameEn: 'Potato Red',
      commodityNameNe: 'आलु रातो',
      marketName: 'Balkhu Agriculture Market',
      marketType: 'wholesale',
      observedPrice: 48,
      unit: 'kg',
      district: 'Kathmandu',
      reporter: { householdId: 'hh_ktm_01', displayName: 'Kiran' },
    };

    const normalResult = CommunityModerationEngine.screenPriceReport(normalPrice, 50);
    assert.strictEqual(normalResult.isSafe, true);
    assert.strictEqual(normalResult.priceAnomalyDetected, false);
    assert.strictEqual(normalResult.automatedAction, 'auto_approve_community');

    // Extreme anomaly: NPR 500/kg (10x wholesale price)
    const anomalyPrice: CommunityPriceReportPayload = {
      ...normalPrice,
      observedPrice: 500,
    };

    const anomalyResult = CommunityModerationEngine.screenPriceReport(anomalyPrice, 50);
    assert.strictEqual(anomalyResult.isSafe, false);
    assert.strictEqual(anomalyResult.priceAnomalyDetected, true);
    assert.strictEqual(anomalyResult.automatedAction, 'require_human_review');
  });

  it('applies human moderation review to promote community recipe to verified badge', () => {
    const contribution: CommunityContribution = {
      id: '0192a000-0000-7000-8000-000000000001',
      type: 'recipe',
      payload: {},
      status: 'auto_approved',
      badge: 'community',
      moderation: {
        isSafe: true,
        toxicityScore: 0,
        spamScore: 0,
        medicalClaimDetected: false,
        profanityDetected: false,
        priceAnomalyDetected: false,
        structuralIssues: [],
        automatedAction: 'auto_approve_community',
        suggestedBadge: 'community',
        feedbackEn: 'Approved',
        feedbackNe: 'स्वीकृत',
      },
      submittedAt: new Date().toISOString(),
    };

    const reviewed = CommunityModerationEngine.applyHumanReview(contribution, {
      contributionId: contribution.id,
      reviewerId: 'editor_chefcounsel',
      decision: 'promote_to_verified',
      reviewerNotes: 'Verified recipe proportions and authentic Newa spicing technique.',
    });

    assert.strictEqual(reviewed.status, 'verified');
    assert.strictEqual(reviewed.badge, 'verified');
    assert.strictEqual(reviewed.reviewerId, 'editor_chefcounsel');
    assert.ok(reviewed.reviewedAt);
    assert.strictEqual(reviewed.reviewerNotes, 'Verified recipe proportions and authentic Newa spicing technique.');
  });
});
