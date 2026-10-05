import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CommunityModerationEngine Dart Parity Tests', () {
    test('screens authentic community recipe and auto-approves as community', () {
      const validRecipe = CommunityRecipePayload(
        titleEn: 'Kwati (Mixed Sprouted Bean Curry)',
        titleNe: 'क्वाँटी',
        cuisine: 'Newa',
        servings: 6,
        prepTimeMinutes: 20,
        cookTimeMinutes: 35,
        whistleCount: 4,
        ingredients: [
          CommunityIngredientItem(
            nameEn: 'Sprouted Mixed Beans',
            nameNe: 'टुसा उम्रेको गेडागुडी',
            quantity: 500,
            unit: 'g',
          ),
          CommunityIngredientItem(
            nameEn: 'Ajwain (Jowano)',
            nameNe: 'ज्वायन',
            quantity: 5,
            unit: 'g',
          ),
        ],
        steps: [
          CommunityRecipeStepItem(
            order: 1,
            instructionEn: 'Heat mustard oil and splutter ajwain.',
            instructionNe: 'तोरीको तेल तताएर ज्वायन पड्काउनुहोस्।',
          ),
          CommunityRecipeStepItem(
            order: 2,
            instructionEn: 'Add soaked kwati beans and fry for 5 minutes.',
            instructionNe: 'क्वाँटी हालेर ५ मिनेट भुट्नुहोस्।',
          ),
          CommunityRecipeStepItem(
            order: 3,
            instructionEn: 'Add warm water, seal lid, and cook for 4 whistles.',
            instructionNe: 'पानी हालेर बिर्को लगाई ४ सिट्ठी लगाउनुहोस्।',
            isWhistleStep: true,
            whistles: 4,
          ),
        ],
        authorHouseholdId: 'hh_ktm_01',
        authorDisplayName: 'Sunita Shakya',
        culturalStory: 'Traditional Gunhu Punhi festive recipe passed down across four generations in Patan.',
      );

      final scorecard = CommunityModerationEngine.screenRecipe(validRecipe);
      expect(scorecard.isSafe, isTrue);
      expect(scorecard.profanityDetected, isFalse);
      expect(scorecard.medicalClaimDetected, isFalse);
      expect(scorecard.automatedAction, AutomatedAction.autoApproveCommunity);
      expect(scorecard.suggestedBadge, VerificationBadge.community);
      expect(scorecard.feedbackEn, contains('Published as Community recipe'));
    });

    test('detects and rejects recipes containing medical cure claims', () {
      const medicalRecipe = CommunityRecipePayload(
        titleEn: 'Miracle Garlic Tea',
        titleNe: 'लसुनको जादुयी चिया',
        cuisine: 'Home Remedy',
        servings: 2,
        prepTimeMinutes: 5,
        cookTimeMinutes: 10,
        ingredients: [
          CommunityIngredientItem(
            nameEn: 'Garlic',
            nameNe: 'लसुन',
            quantity: 4,
            unit: 'cloves',
          ),
        ],
        steps: [
          CommunityRecipeStepItem(
            order: 1,
            instructionEn: 'Drink every morning because this recipe cures cancer completely.',
            instructionNe: 'पिउनुहोस् किनकि यसले क्यान्सर निको गर्छ।',
          ),
        ],
        authorHouseholdId: 'hh_spammer',
        authorDisplayName: 'Remedy Guru',
      );

      final scorecard = CommunityModerationEngine.screenRecipe(medicalRecipe);
      expect(scorecard.isSafe, isFalse);
      expect(scorecard.medicalClaimDetected, isTrue);
      expect(scorecard.automatedAction, AutomatedAction.autoReject);
      expect(scorecard.structuralIssues.any((i) => i.contains('medical cure or treatment')), isTrue);
    });

    test('screens regional ingredient aliases and flags spam/links', () {
      const validAlias = CommunityIngredientAliasPayload(
        canonicalIngredientId: 'cauliflower',
        dialectRegion: 'Newa / Kathmandu',
        aliasEn: 'Kauli',
        aliasNe: 'काउली',
        notes: 'Colloquially referred to as Kauli in Kathmandu Valley.',
        authorHouseholdId: 'hh_ktm_01',
        authorDisplayName: 'Prakash Maharjan',
      );

      final validResult = CommunityModerationEngine.screenIngredientAlias(validAlias);
      expect(validResult.isSafe, isTrue);
      expect(validResult.automatedAction, AutomatedAction.autoApproveCommunity);

      const spamAlias = CommunityIngredientAliasPayload(
        canonicalIngredientId: 'potato',
        dialectRegion: 'Spam',
        aliasEn: 'Check https://buycheapcrypto.com for potatoes',
        aliasNe: 'आलु',
        authorHouseholdId: 'hh_spam',
        authorDisplayName: 'Bot',
      );

      final spamResult = CommunityModerationEngine.screenIngredientAlias(spamAlias);
      expect(spamResult.isSafe, isFalse);
      expect(spamResult.automatedAction, AutomatedAction.autoReject);
    });

    test('screens price reports and flags extreme anomalies against Kalimati baseline', () {
      const normalPrice = CommunityPriceReportPayload(
        commodityId: 'potato_red',
        commodityNameEn: 'Potato Red',
        commodityNameNe: 'आलु रातो',
        marketName: 'Balkhu Agriculture Market',
        marketType: 'wholesale',
        observedPrice: 48,
        unit: 'kg',
        district: 'Kathmandu',
        reporterHouseholdId: 'hh_ktm_01',
        reporterDisplayName: 'Kiran',
      );

      final normalResult = CommunityModerationEngine.screenPriceReport(normalPrice, 50);
      expect(normalResult.isSafe, isTrue);
      expect(normalResult.priceAnomalyDetected, isFalse);
      expect(normalResult.automatedAction, AutomatedAction.autoApproveCommunity);

      const anomalyPrice = CommunityPriceReportPayload(
        commodityId: 'potato_red',
        commodityNameEn: 'Potato Red',
        commodityNameNe: 'आलु रातो',
        marketName: 'Balkhu Agriculture Market',
        marketType: 'wholesale',
        observedPrice: 500,
        unit: 'kg',
        district: 'Kathmandu',
        reporterHouseholdId: 'hh_ktm_01',
        reporterDisplayName: 'Kiran',
      );

      final anomalyResult = CommunityModerationEngine.screenPriceReport(anomalyPrice, 50);
      expect(anomalyResult.isSafe, isFalse);
      expect(anomalyResult.priceAnomalyDetected, isTrue);
      expect(anomalyResult.automatedAction, AutomatedAction.requireHumanReview);
    });

    test('applies human moderation review to promote community recipe to verified badge', () {
      const contribution = CommunityContribution(
        id: '0192a000-0000-7000-8000-000000000001',
        type: ContributionType.recipe,
        payload: {},
        status: ContributionStatus.autoApproved,
        badge: VerificationBadge.community,
        moderation: ModerationScorecard(
          isSafe: true,
          automatedAction: AutomatedAction.autoApproveCommunity,
          suggestedBadge: VerificationBadge.community,
          feedbackEn: 'Approved',
          feedbackNe: 'स्वीकृत',
        ),
        submittedAt: '2026-10-05T08:00:00Z',
      );

      final reviewed = CommunityModerationEngine.applyHumanReview(
        contribution,
        reviewerId: 'editor_chefcounsel',
        decision: 'promote_to_verified',
        reviewerNotes: 'Verified recipe proportions and authentic Newa spicing technique.',
      );

      expect(reviewed.status, ContributionStatus.verified);
      expect(reviewed.badge, VerificationBadge.verified);
      expect(reviewed.reviewerId, 'editor_chefcounsel');
      expect(reviewed.reviewedAt, isNotNull);
      expect(reviewed.reviewerNotes, 'Verified recipe proportions and authentic Newa spicing technique.');
    });
  });
}
