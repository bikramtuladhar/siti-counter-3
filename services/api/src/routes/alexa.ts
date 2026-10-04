import { Hono } from 'hono';
import {
  AlexaSkillHandler,
  AlexaRequestBody,
  AlexaResponseBody,
  TodayMealItem,
  FlameLevel,
} from '@siti-counter/kitchen-engine';

export const alexaRouter = new Hono();

// In-memory or request-scoped active cooking session provider for Alexa Skill
export interface AlexaServerState {
  todayMeals?: TodayMealItem[];
  activeCookingSession?: {
    recipeName: string;
    stepIndex: number;
    totalSteps: number;
    instruction: string;
    whistlesCount: number;
    whistlesTarget: number;
    timerRemainingSeconds: number;
    flameLevel: FlameLevel;
  } | null;
}

let serverState: AlexaServerState = {
  todayMeals: [
    {
      slot: 'Bihanko Dal Bhat',
      recipeName: 'Kalo Dal, Basmati Chamal & Rayoko Saag',
      timeEstimateMinutes: 30,
      whistlesTarget: 4,
    },
    {
      slot: 'Diusoko Khaja',
      recipeName: 'Chiura Tarkari with Aloo Chana',
      timeEstimateMinutes: 15,
      whistlesTarget: 2,
    },
    {
      slot: 'Belukako Bhat',
      recipeName: 'Khasiko Masu & Steamed Rice',
      timeEstimateMinutes: 40,
      whistlesTarget: 5,
    },
  ],
  activeCookingSession: null,
};

export function setAlexaServerState(state: Partial<AlexaServerState>): void {
  serverState = { ...serverState, ...state };
}

export function resetAlexaServerState(): void {
  serverState = {
    todayMeals: [
      {
        slot: 'Bihanko Dal Bhat',
        recipeName: 'Kalo Dal, Basmati Chamal & Rayoko Saag',
        timeEstimateMinutes: 30,
        whistlesTarget: 4,
      },
      {
        slot: 'Diusoko Khaja',
        recipeName: 'Chiura Tarkari with Aloo Chana',
        timeEstimateMinutes: 15,
        whistlesTarget: 2,
      },
      {
        slot: 'Belukako Bhat',
        recipeName: 'Khasiko Masu & Steamed Rice',
        timeEstimateMinutes: 40,
        whistlesTarget: 5,
      },
    ],
    activeCookingSession: null,
  };
}

alexaRouter.post('/v1/alexa', async (c) => {
  try {
    const rawBody = await c.req.json<AlexaRequestBody>();

    if (!rawBody || !rawBody.request || !rawBody.request.type) {
      return c.json(
        {
          error: 'BAD_REQUEST',
          message: 'Malformed Alexa Skills Kit request structure.',
        },
        400
      );
    }

    const handler = new AlexaSkillHandler({
      getTodayMenu: () => serverState.todayMeals ?? [],
      getActiveCookingSession: () => serverState.activeCookingSession ?? null,
    });

    const response: AlexaResponseBody = handler.handleRequest(rawBody);

    return c.json(response, 200);
  } catch (err) {
    return c.json(
      {
        error: 'INTERNAL_ERROR',
        message: (err as Error).message,
      },
      500
    );
  }
});
