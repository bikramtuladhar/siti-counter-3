/**
 * Siti Counter 3 - Community & Moderation API Routes
 * Section 17 & 20.2: Community contributions, AI screening, and human review queue.
 */

import { Hono } from 'hono';
import {
  CommunityWorkflowService,
  WorkersAiBinding,
} from '../community/community_workflow.js';
import { HumanReviewInput } from '@siti-counter/kitchen-engine';

export interface CommunityEnv {
  Bindings: {
    AI?: WorkersAiBinding;
  };
}

export const communityRouter = new Hono<CommunityEnv>();

/**
 * POST /v1/community/contribute/recipe
 * Submits a community recipe and triggers automated screening workflow.
 */
communityRouter.post('/v1/community/contribute/recipe', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as any;

  if (!body.titleEn && !body.titleNe) {
    return c.json({ error: 'INVALID_PAYLOAD', message: 'Recipe title is required' }, 400);
  }

  const result = await CommunityWorkflowService.processContributionWorkflow(
    'recipe',
    body,
    c.env?.AI
  );

  return c.json(result, 201);
});

/**
 * POST /v1/community/contribute/ingredient-alias
 * Submits a regional / dialect ingredient name sighting.
 */
communityRouter.post('/v1/community/contribute/ingredient-alias', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as any;

  if (!body.canonicalIngredientId || (!body.aliasEn && !body.aliasNe)) {
    return c.json(
      {
        error: 'INVALID_PAYLOAD',
        message: 'canonicalIngredientId and aliasEn/aliasNe are required',
      },
      400
    );
  }

  const result = await CommunityWorkflowService.processContributionWorkflow(
    'ingredient_alias',
    body,
    c.env?.AI
  );

  return c.json(result, 201);
});

/**
 * POST /v1/community/contribute/price-report
 * Submits a crowdsourced haat bazaar / market price report.
 */
communityRouter.post('/v1/community/contribute/price-report', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as any;

  if (!body.commodityId || !body.marketName || body.observedPrice === undefined) {
    return c.json(
      {
        error: 'INVALID_PAYLOAD',
        message: 'commodityId, marketName, and observedPrice are required',
      },
      400
    );
  }

  const result = await CommunityWorkflowService.processContributionWorkflow(
    'price_observation',
    body,
    c.env?.AI
  );

  return c.json(result, 201);
});

/**
 * GET /v1/community/feed
 * Retrieves public community feed with optional filters for type and badge ('community' | 'verified').
 */
communityRouter.get('/v1/community/feed', (c) => {
  const type = c.req.query('type');
  const badge = c.req.query('badge');
  const limit = Number(c.req.query('limit')) || 50;

  const items = CommunityWorkflowService.getFeed({ type, badge, limit });
  return c.json({
    total: items.length,
    items,
  });
});

/**
 * GET /v1/community/moderation/queue
 * Retrieves items pending human review or flagged by automated screening.
 */
communityRouter.get('/v1/community/moderation/queue', (c) => {
  const queue = CommunityWorkflowService.getModerationQueue();
  return c.json({
    total: queue.length,
    queue,
  });
});

/**
 * POST /v1/community/moderation/:id/review
 * Human review action: promote to 'verified', approve as 'community', or reject.
 */
communityRouter.post('/v1/community/moderation/:id/review', async (c) => {
  const contributionId = c.req.param('id');
  const body = (await c.req.json().catch(() => ({}))) as Partial<HumanReviewInput>;

  if (!body.reviewerId || !body.decision) {
    return c.json(
      { error: 'INVALID_REVIEW', message: 'reviewerId and decision are required' },
      400
    );
  }

  const updated = CommunityWorkflowService.reviewContribution({
    contributionId,
    reviewerId: body.reviewerId,
    decision: body.decision,
    reviewerNotes: body.reviewerNotes,
  });

  if (!updated) {
    return c.json(
      { error: 'NOT_FOUND', message: `Contribution ${contributionId} not found` },
      404
    );
  }

  return c.json(updated, 200);
});
