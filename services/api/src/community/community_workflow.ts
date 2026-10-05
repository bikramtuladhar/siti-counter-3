/**
 * Siti Counter 3 - Community Moderation Workflow (Cloudflare Workflows & Workers AI)
 * Section 17 & 20.2: Automated moderation pipeline and human review queue.
 */

import {
  CommunityModerationEngine,
  CommunityRecipePayload,
  CommunityIngredientAliasPayload,
  CommunityPriceReportPayload,
  ModerationScorecard,
  CommunityContribution,
  ContributionStatus,
  VerificationBadge,
  HumanReviewInput,
  UuidV7,
} from '@siti-counter/kitchen-engine';
import { KalimatiService } from '../market/kalimati_service.js';

export interface WorkflowContext {
  step: {
    do: <T>(name: string, fn: () => Promise<T> | T) => Promise<T>;
  };
}

export interface WorkersAiBinding {
  run: (model: string, input: Record<string, unknown>) => Promise<any>;
}

// In-memory backing store for local testing/dev environments (backed by D1 in production)
const memoryStore = new Map<string, CommunityContribution>();

export class CommunityWorkflowService {
  /**
   * Cloudflare Workflow Entrypoint for processing new community contributions.
   * Steps:
   * 1. Validate Structure
   * 2. Workers AI Text & Safety Screening
   * 3. Domain & Kalimati Price Anomaly Check
   * 4. Automated Triage & Initial Badge Assignment
   * 5. Persist to Database & Output Result
   */
  static async processContributionWorkflow(
    type: 'recipe' | 'ingredient_alias' | 'price_observation',
    payload: any,
    ai?: WorkersAiBinding
  ): Promise<CommunityContribution> {
    const contributionId = UuidV7.generate();
    const now = new Date().toISOString();

    // Step 1: Validate Structure
    let scorecard: ModerationScorecard;
    let title = '';
    let authorHouseholdId = '';
    let authorDisplayName = '';

    if (type === 'recipe') {
      const recipePayload = payload as CommunityRecipePayload;
      title = recipePayload.titleNe || recipePayload.titleEn;
      authorHouseholdId = recipePayload.author?.householdId || '';
      authorDisplayName = recipePayload.author?.displayName || 'Anonymous Cook';
      scorecard = CommunityModerationEngine.screenRecipe(recipePayload);
    } else if (type === 'ingredient_alias') {
      const aliasPayload = payload as CommunityIngredientAliasPayload;
      title = `${aliasPayload.canonicalIngredientId} -> ${aliasPayload.aliasNe || aliasPayload.aliasEn}`;
      authorHouseholdId = aliasPayload.author?.householdId || '';
      authorDisplayName = aliasPayload.author?.displayName || 'Community Member';
      scorecard = CommunityModerationEngine.screenIngredientAlias(aliasPayload);
    } else {
      const pricePayload = payload as CommunityPriceReportPayload;
      title = `${pricePayload.commodityNameNe || pricePayload.commodityNameEn} @ ${pricePayload.marketName}`;
      authorHouseholdId = pricePayload.reporter?.householdId || '';
      authorDisplayName = pricePayload.reporter?.displayName || 'Haat Sighting';

      // Compare with Kalimati baseline wholesale price
      const baseline = KalimatiService.getLatestPrice(pricePayload.commodityId);
      const baselineAvg = baseline?.avgPrice;
      scorecard = CommunityModerationEngine.screenPriceReport(pricePayload, baselineAvg);
    }

    // Step 2: Workers AI Screening (Cloudflare Workers AI @cf/meta/llama-3-8b-instruct or llama-guard)
    if (ai && scorecard.isSafe) {
      try {
        const textSample = JSON.stringify(payload).slice(0, 1000);
        const aiResponse = await ai.run('@cf/meta/llama-3-8b-instruct', {
          prompt: `You are a culinary moderation assistant. Screen this content for spam, hate speech, dangerous chemicals, or medical cure claims. Reply ONLY 'SAFE' or 'FLAG: reason'. Content: ${textSample}`,
          max_tokens: 30,
        });

        const reply = String(aiResponse?.response || '').trim();
        if (reply.startsWith('FLAG:')) {
          scorecard = {
            ...scorecard,
            isSafe: false,
            automatedAction: 'require_human_review',
            structuralIssues: [...scorecard.structuralIssues, `Workers AI: ${reply}`],
          };
        }
      } catch {
        // Fallback to deterministic rules on Workers AI timeout or offline
      }
    }

    // Step 4: Automated Triage & Badge Assignment
    let status: ContributionStatus = 'auto_approved';
    let badge: VerificationBadge = 'community';

    if (!scorecard.isSafe) {
      if (scorecard.automatedAction === 'auto_reject') {
        status = 'rejected';
      } else {
        status = 'flagged'; // Enters human review moderation queue
      }
    } else {
      status = 'auto_approved';
      badge = 'community';
    }

    // Step 5: Persist record
    const contribution: CommunityContribution = {
      id: contributionId,
      type,
      payload,
      status,
      badge,
      moderation: scorecard,
      submittedAt: now,
    };

    memoryStore.set(contributionId, contribution);
    return contribution;
  }

  /**
   * Retrieves published contributions for the community feed.
   */
  static getFeed({
    type,
    badge,
    limit = 50,
  }: {
    type?: string;
    badge?: string;
    limit?: number;
  }): CommunityContribution[] {
    const list = Array.from(memoryStore.values()).filter(
      (c) => c.status === 'auto_approved' || c.status === 'verified'
    );

    return list
      .filter((c) => !type || c.type === type)
      .filter((c) => !badge || c.badge === badge)
      .slice(0, limit);
  }

  /**
   * Retrieves pending items requiring human moderation review.
   */
  static getModerationQueue(): CommunityContribution[] {
    return Array.from(memoryStore.values()).filter(
      (c) => c.status === 'flagged' || c.status === 'pending'
    );
  }

  /**
   * Applies human moderator review action to promote to "Verified" or reject.
   */
  static reviewContribution(review: HumanReviewInput): CommunityContribution | null {
    const existing = memoryStore.get(review.contributionId);
    if (!existing) return null;

    const updated = CommunityModerationEngine.applyHumanReview(existing, review);
    memoryStore.set(review.contributionId, updated);
    return updated;
  }

  /**
   * Clears memory store (used in unit test isolation).
   */
  static resetStore(): void {
    memoryStore.clear();
  }
}
