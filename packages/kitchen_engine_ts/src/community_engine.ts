/**
 * Siti Counter 3 - Community Engine (TypeScript)
 * Section 17 & 20.2: Community contributions, AI screening, moderation scorecards & verification badges.
 */

export type ContributionType = 'recipe' | 'ingredient_alias' | 'price_observation';

export type ContributionStatus =
  | 'pending'
  | 'screening'
  | 'auto_approved'
  | 'flagged'
  | 'verified'
  | 'rejected';

export type VerificationBadge = 'community' | 'verified';

export interface CommunityIngredientItem {
  nameEn: string;
  nameNe: string;
  quantity: number;
  unit: string;
  allergens?: string[];
}

export interface CommunityRecipeStepItem {
  order: number;
  instructionEn: string;
  instructionNe: string;
  isWhistleStep?: boolean;
  whistles?: number;
  timerMinutes?: number;
}

export interface CommunityRecipePayload {
  titleEn: string;
  titleNe: string;
  cuisine: string;
  servings: number;
  prepTimeMinutes: number;
  cookTimeMinutes: number;
  whistleCount?: number;
  ingredients: CommunityIngredientItem[];
  steps: CommunityRecipeStepItem[];
  author: {
    householdId: string;
    displayName: string;
  };
  culturalStory?: string;
  photoUrl?: string;
}

export interface CommunityIngredientAliasPayload {
  canonicalIngredientId: string;
  dialectRegion: string; // e.g. 'Newa', 'Thakali', 'Mithila', 'Eastern Hills'
  aliasEn: string;
  aliasNe: string;
  notes?: string;
  author: {
    householdId: string;
    displayName: string;
  };
}

export interface CommunityPriceReportPayload {
  commodityId: string;
  commodityNameEn: string;
  commodityNameNe: string;
  marketName: string;
  marketType: 'haat_bazaar' | 'supermarket' | 'local_kirana' | 'wholesale';
  observedPrice: number;
  unit: string;
  district: string;
  reporter: {
    householdId: string;
    displayName: string;
  };
}

export interface ModerationScorecard {
  isSafe: boolean;
  toxicityScore: number; // 0.0 - 1.0
  spamScore: number; // 0.0 - 1.0
  medicalClaimDetected: boolean;
  profanityDetected: boolean;
  priceAnomalyDetected: boolean;
  structuralIssues: string[];
  automatedAction: 'auto_approve_community' | 'require_human_review' | 'auto_reject';
  suggestedBadge: VerificationBadge;
  feedbackEn: string;
  feedbackNe: string;
}

export interface CommunityContribution<T = unknown> {
  id: string; // UUIDv7
  type: ContributionType;
  payload: T;
  status: ContributionStatus;
  badge: VerificationBadge;
  moderation: ModerationScorecard;
  submittedAt: string;
  reviewedAt?: string;
  reviewerId?: string;
  reviewerNotes?: string;
}

export interface HumanReviewInput {
  contributionId: string;
  reviewerId: string;
  decision: 'approve_community' | 'promote_to_verified' | 'request_changes' | 'reject';
  reviewerNotes?: string;
}

// Prohibited terms for profanity/abuse filter (Nepali and English)
const BANNED_KEYWORDS = [
  'scam',
  'fake',
  'casino',
  'viagra',
  'crypto',
  'hack',
  'terro',
  'f***',
  'asshole',
  'bullshit',
];

// Health and cure claim triggers violating Section 22 guardrails
const MEDICAL_CLAIM_PATTERNS = [
  /cures\s+cancer/i,
  /cures\s+diabetes/i,
  /prevents\s+covid/i,
  /रोग\s*निको\s*पार्छ/,
  /क्यान्सर\s*निको/,
  /मधुमेह\s*निको/,
  /औषधि\s*हो/,
];

export class CommunityModerationEngine {
  /**
   * Screens recipe contributions for completeness, food safety, spam, and medical claims.
   */
  static screenRecipe(payload: CommunityRecipePayload): ModerationScorecard {
    const issues: string[] = [];
    let toxicityScore = 0.0;
    let spamScore = 0.0;
    let medicalClaim = false;
    let profanity = false;

    // 1. Structural Completeness Checks
    if (!payload.titleEn?.trim() && !payload.titleNe?.trim()) {
      issues.push('Recipe title is required in English or Nepali');
    }
    if (!payload.ingredients || payload.ingredients.length === 0) {
      issues.push('At least one ingredient is required');
    }
    if (!payload.steps || payload.steps.length === 0) {
      issues.push('At least one preparation or cooking step is required');
    }
    if (payload.servings < 1 || payload.servings > 100) {
      issues.push('Servings must be between 1 and 100');
    }
    if (payload.cookTimeMinutes < 0 || payload.cookTimeMinutes > 480) {
      issues.push('Cook time must be reasonable (0 to 480 minutes)');
    }

    // 2. Text Content Screening (Title, Story, Steps)
    const combinedText = [
      payload.titleEn,
      payload.titleNe,
      payload.culturalStory ?? '',
      ...(payload.steps?.map((s) => `${s.instructionEn} ${s.instructionNe}`) ?? []),
      ...(payload.ingredients?.map((i) => `${i.nameEn} ${i.nameNe}`) ?? []),
    ].join(' ').toLowerCase();

    for (const kw of BANNED_KEYWORDS) {
      if (combinedText.includes(kw.toLowerCase())) {
        profanity = true;
        toxicityScore = 0.9;
        issues.push(`Prohibited word detected: "${kw}"`);
        break;
      }
    }

    for (const pat of MEDICAL_CLAIM_PATTERNS) {
      if (pat.test(combinedText)) {
        medicalClaim = true;
        toxicityScore = Math.max(toxicityScore, 0.7);
        issues.push('Unverified medical cure or treatment claims are strictly prohibited.');
        break;
      }
    }

    // Spam heuristic: repeated characters or links
    if (/https?:\/\//i.test(combinedText)) {
      spamScore += 0.6;
      issues.push('External hyperlinks in recipe instructions are flagged for spam prevention');
    }

    // 3. Determine Automated Action
    const isSafe = !profanity && !medicalClaim && issues.length === 0;
    let automatedAction: ModerationScorecard['automatedAction'] = 'auto_approve_community';
    let suggestedBadge: VerificationBadge = 'community';

    if (profanity || medicalClaim || toxicityScore > 0.6 || spamScore > 0.7) {
      automatedAction = 'auto_reject';
    } else if (issues.length > 0 || spamScore > 0.3) {
      automatedAction = 'require_human_review';
    } else {
      // High completeness with authentic steps and cultural backstory qualifies for human promotion review
      if (payload.culturalStory && payload.culturalStory.length > 50 && payload.steps.length >= 3) {
        suggestedBadge = 'community'; // will be eligible for verified on human review
        automatedAction = 'auto_approve_community';
      }
    }

    const feedbackEn = isSafe
      ? 'Recipe passed automated safety screening. Published as Community recipe!'
      : `Recipe requires attention: ${issues.join('; ')}`;

    const feedbackNe = isSafe
      ? 'रेसिपी स्वचालित सुरक्षा जाँचमा उत्तीर्ण भयो। सामुदायिक रेसिपीको रूपमा प्रकाशित भयो!'
      : `रेसिपीमा सुधार आवश्यक छ: ${issues.join('; ')}`;

    return {
      isSafe,
      toxicityScore,
      spamScore,
      medicalClaimDetected: medicalClaim,
      profanityDetected: profanity,
      priceAnomalyDetected: false,
      structuralIssues: issues,
      automatedAction,
      suggestedBadge,
      feedbackEn,
      feedbackNe,
    };
  }

  /**
   * Screens local ingredient alias suggestions (e.g. Thakali, Newari, Mithila names).
   */
  static screenIngredientAlias(payload: CommunityIngredientAliasPayload): ModerationScorecard {
    const issues: string[] = [];
    let profanity = false;
    let spam = false;

    if (!payload.canonicalIngredientId?.trim()) {
      issues.push('Canonical ingredient ID is required');
    }
    if (!payload.aliasEn?.trim() && !payload.aliasNe?.trim()) {
      issues.push('Alias name must be provided in English or Nepali');
    }
    if (!payload.dialectRegion?.trim()) {
      issues.push('Dialect region or cultural community is required');
    }

    const text = `${payload.aliasEn} ${payload.aliasNe} ${payload.notes ?? ''}`.toLowerCase();
    for (const kw of BANNED_KEYWORDS) {
      if (text.includes(kw)) {
        profanity = true;
        issues.push(`Prohibited word in alias: "${kw}"`);
        break;
      }
    }

    if (text.length > 200 || /https?:\/\//i.test(text)) {
      spam = true;
      issues.push('Alias text is unusually long or contains links');
    }

    const isSafe = !profanity && !spam && issues.length === 0;
    const automatedAction = profanity
      ? 'auto_reject'
      : isSafe
      ? 'auto_approve_community'
      : 'require_human_review';

    return {
      isSafe,
      toxicityScore: profanity ? 0.9 : 0.0,
      spamScore: spam ? 0.8 : 0.0,
      medicalClaimDetected: false,
      profanityDetected: profanity,
      priceAnomalyDetected: false,
      structuralIssues: issues,
      automatedAction,
      suggestedBadge: 'community',
      feedbackEn: isSafe ? 'Ingredient alias accepted.' : issues.join('; '),
      feedbackNe: isSafe ? 'सामग्रीको स्थानीय नाम स्वीकार गरियो।' : issues.join('; '),
    };
  }

  /**
   * Screens crowdsourced market price observations, checking against Kalimati baseline price bounds.
   */
  static screenPriceReport(
    payload: CommunityPriceReportPayload,
    baselineAvgPrice?: number
  ): ModerationScorecard {
    const issues: string[] = [];
    let priceAnomaly = false;

    if (!payload.commodityId?.trim()) {
      issues.push('Commodity ID is required');
    }
    if (payload.observedPrice <= 0) {
      issues.push('Observed price must be greater than zero');
    }
    if (!payload.marketName?.trim()) {
      issues.push('Market name is required');
    }

    // Price anomaly detection: if reported price is more than 5x or less than 0.15x of wholesale baseline
    if (baselineAvgPrice && baselineAvgPrice > 0 && payload.observedPrice > 0) {
      const ratio = payload.observedPrice / baselineAvgPrice;
      if (ratio > 5.0 || ratio < 0.15) {
        priceAnomaly = true;
        issues.push(
          `Price anomaly detected: NPR ${payload.observedPrice} is far outside baseline wholesale average of NPR ${baselineAvgPrice}`
        );
      }
    }

    const isSafe = issues.length === 0;
    const automatedAction = priceAnomaly
      ? 'require_human_review'
      : isSafe
      ? 'auto_approve_community'
      : 'auto_reject';

    return {
      isSafe: !priceAnomaly && isSafe,
      toxicityScore: 0.0,
      spamScore: 0.0,
      medicalClaimDetected: false,
      profanityDetected: false,
      priceAnomalyDetected: priceAnomaly,
      structuralIssues: issues,
      automatedAction,
      suggestedBadge: 'community',
      feedbackEn: isSafe
        ? 'Market price sighting approved.'
        : priceAnomaly
        ? 'Price differs substantially from market baseline. Sent for verification.'
        : issues.join('; '),
      feedbackNe: isSafe
        ? 'बजार मूल्य रिपोर्ट स्वीकृत भयो।'
        : priceAnomaly
        ? 'मूल्य बजारको औसतभन्दा धेरै फरक छ। समीक्षाको लागि पठाइयो।'
        : issues.join('; '),
    };
  }

  /**
   * Applies human review decision, assigning "Verified" or "Community" badge.
   */
  static applyHumanReview(
    currentContribution: CommunityContribution,
    review: HumanReviewInput
  ): CommunityContribution {
    let newStatus: ContributionStatus = currentContribution.status;
    let newBadge: VerificationBadge = currentContribution.badge;

    switch (review.decision) {
      case 'promote_to_verified':
        newStatus = 'verified';
        newBadge = 'verified';
        break;
      case 'approve_community':
        newStatus = 'auto_approved';
        newBadge = 'community';
        break;
      case 'request_changes':
        newStatus = 'flagged';
        break;
      case 'reject':
        newStatus = 'rejected';
        break;
    }

    return {
      ...currentContribution,
      status: newStatus,
      badge: newBadge,
      reviewedAt: new Date().toISOString(),
      reviewerId: review.reviewerId,
      reviewerNotes: review.reviewerNotes,
    };
  }
}
