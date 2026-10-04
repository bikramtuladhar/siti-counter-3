import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  CastProtocolEngine,
  CastCookingSessionState,
  SITI_CAST_NAMESPACE,
  AlexaAPLBuilder,
  AlexaSkillHandler,
  AlexaRequestBody,
} from './smart_display_engine.js';

describe('SmartDisplayEngine - Google Cast Protocol', () => {
  it('defines correct custom namespace for Siti Counter cooking', () => {
    assert.equal(SITI_CAST_NAMESPACE, 'urn:x-cast:com.siticounter.cooking');
  });

  it('serializes and deserializes session update message correctly', () => {
    const state: CastCookingSessionState = {
      sessionId: 'session-123',
      recipeNameEn: 'Yellow Lentil Dal',
      recipeNameNe: 'पहेँलो दाल',
      currentStepIndex: 1,
      totalSteps: 4,
      stepInstructionEn: 'Cover pressure cooker lid and heat on high flame until 3 whistles.',
      stepInstructionNe: 'प्रेशर कुकरको बिर्को लगाएर ३ सिठीसम्म ठूलो आगोमा पकाउनुहोस्।',
      whistlesTarget: 3,
      whistlesCurrent: 2,
      timerSecondsRemaining: 300,
      flameLevel: 'high',
      isPaused: false,
      targetReached: false,
    };

    const msg = CastProtocolEngine.createSessionUpdate(state);
    assert.equal(msg.type, 'COOKING_SESSION_UPDATE');
    assert.ok(msg.timestamp > 0);
    assert.deepEqual(msg.payload, state);

    const serialized = CastProtocolEngine.serialize(msg);
    assert.ok(typeof serialized === 'string');

    const deserialized = CastProtocolEngine.deserialize(serialized);
    assert.deepEqual(deserialized, msg);
  });

  it('creates siti count update and flags target completion', () => {
    const notDone = CastProtocolEngine.createSitiCountUpdate(2, 3);
    assert.equal(notDone.payload.reached, false);
    assert.equal(notDone.payload.current, 2);

    const done = CastProtocolEngine.createSitiCountUpdate(3, 3);
    assert.equal(done.payload.reached, true);
    assert.equal(done.payload.current, 3);
  });

  it('creates timer update and celebration payload', () => {
    const timer = CastProtocolEngine.createTimerUpdate(125, false);
    assert.equal(timer.type, 'TIMER_UPDATE');
    assert.equal(timer.payload.remainingSeconds, 125);
    assert.equal(timer.payload.isPaused, false);

    const celebration = CastProtocolEngine.createTargetReachedCelebration('Khasiko Masu', 4);
    assert.equal(celebration.type, 'TARGET_REACHED');
    assert.equal(celebration.payload.recipeName, 'Khasiko Masu');
    assert.equal(celebration.payload.whistles, 4);
  });

  it('throws on invalid cast message parsing', () => {
    assert.throws(() => {
      CastProtocolEngine.deserialize('not a json');
    });
    assert.throws(() => {
      CastProtocolEngine.deserialize(JSON.stringify({ some: 'key' }));
    });
  });
});

describe('SmartDisplayEngine - Alexa Presentation Language (APL) Builder', () => {
  it('builds valid Today Menu APL document with dark theme and data sources', () => {
    const meals = [
      { slot: 'Morning', recipeName: 'Dal Bhat', timeEstimateMinutes: 30, whistlesTarget: 3 },
      { slot: 'Dinner', recipeName: 'Roti Tarkari', timeEstimateMinutes: 20 },
    ];
    const { document, datasources } = AlexaAPLBuilder.buildTodayMenuDocument(meals);

    assert.equal(document.type, 'APL');
    assert.equal(document.version, '1.4');
    assert.equal(document.theme, 'dark');
    assert.ok(Array.isArray((document.mainTemplate as { items: unknown[] }).items));
    assert.equal((datasources.menuData as { meals: unknown[] }).meals.length, 2);
  });

  it('builds cooking step APL document with timer and whistle indicators', () => {
    const { document, datasources } = AlexaAPLBuilder.buildCookingStepDocument({
      recipeName: 'Aloo Tama Bodi',
      stepIndex: 2,
      totalSteps: 5,
      instruction: 'Add bodi and tama, stir well and simmer for 5 minutes.',
      whistlesCount: 2,
      whistlesTarget: 2,
      timerSecondsRemaining: 95,
    });

    assert.equal(document.type, 'APL');
    const stepData = (datasources as { stepData: { timerFormatted: string; whistlesCount: number } }).stepData;
    assert.equal(stepData.timerFormatted, '1:35');
    assert.equal(stepData.whistlesCount, 2);
  });

  it('builds whistle monitor APL document with giant typography and completion status', () => {
    const { document, datasources } = AlexaAPLBuilder.buildWhistleMonitorDocument({
      currentWhistles: 4,
      targetWhistles: 4,
      flameStatus: 'off',
      isFinished: true,
    });

    assert.equal(document.type, 'APL');
    const whistleData = (datasources as { whistleData: { isFinished: boolean; flameStatus: string } }).whistleData;
    assert.equal(whistleData.isFinished, true);
    assert.equal(whistleData.flameStatus, 'OFF');
  });
});

describe('SmartDisplayEngine - AlexaSkillHandler Intent Processing', () => {
  const handlerWithNoActiveSession = new AlexaSkillHandler({
    getTodayMenu: () => [
      { slot: 'Bihan', recipeName: 'Masuro Dal Bhat', timeEstimateMinutes: 25, whistlesTarget: 3 },
    ],
    getActiveCookingSession: () => null,
  });

  const handlerWithActiveCooking = new AlexaSkillHandler({
    getActiveCookingSession: () => ({
      recipeName: 'Khasiko Masu',
      stepIndex: 2,
      totalSteps: 4,
      instruction: 'Seal pressure cooker and wait for 4 whistles.',
      whistlesCount: 3,
      whistlesTarget: 4,
      timerRemainingSeconds: 240,
      flameLevel: 'high',
    }),
  });

  it('handles LaunchRequest on audio-only Echo without APL directives', () => {
    const req: AlexaRequestBody = {
      version: '1.0',
      request: {
        type: 'LaunchRequest',
        requestId: 'req-1',
        timestamp: new Date().toISOString(),
      },
    };

    const res = handlerWithNoActiveSession.handleRequest(req);
    assert.equal(res.version, '1.0');
    assert.ok(res.response.outputSpeech?.text?.includes('Welcome to Siti Counter!'));
    assert.equal(res.response.directives, undefined);
  });

  it('handles LaunchRequest on Echo Show with APL directives', () => {
    const req: AlexaRequestBody = {
      version: '1.0',
      context: {
        System: {
          device: {
            supportedInterfaces: {
              'Alexa.Presentation.APL': { runtime: { maxVersion: '1.4' } },
            },
          },
        },
      },
      request: {
        type: 'LaunchRequest',
        requestId: 'req-2',
        timestamp: new Date().toISOString(),
      },
    };

    const res = handlerWithNoActiveSession.handleRequest(req);
    assert.ok(res.response.outputSpeech?.text?.includes('Welcome to Siti Counter!'));
    assert.ok(res.response.directives && res.response.directives.length === 1);
    assert.equal(res.response.directives[0].type, 'Alexa.Presentation.APL.RenderDocument');
  });

  it('handles LaunchRequest with active cooking session', () => {
    const req: AlexaRequestBody = {
      version: '1.0',
      context: {
        System: {
          device: {
            supportedInterfaces: {
              'Alexa.Presentation.APL': { runtime: { maxVersion: '1.4' } },
            },
          },
        },
      },
      request: {
        type: 'LaunchRequest',
        requestId: 'req-3',
        timestamp: new Date().toISOString(),
      },
    };

    const res = handlerWithActiveCooking.handleRequest(req);
    assert.ok(res.response.outputSpeech?.text?.includes('cooking Khasiko Masu'));
    assert.ok(res.response.directives && res.response.directives.length === 1);
  });

  it('handles TodaysMenuIntent', () => {
    const req: AlexaRequestBody = {
      version: '1.0',
      request: {
        type: 'IntentRequest',
        requestId: 'req-4',
        timestamp: new Date().toISOString(),
        intent: { name: 'TodaysMenuIntent' },
      },
    };

    const res = handlerWithNoActiveSession.handleRequest(req);
    assert.ok(res.response.outputSpeech?.text?.includes('Masuro Dal Bhat'));
  });

  it('handles CookingStepIntent', () => {
    const req: AlexaRequestBody = {
      version: '1.0',
      request: {
        type: 'IntentRequest',
        requestId: 'req-5',
        timestamp: new Date().toISOString(),
        intent: { name: 'CookingStepIntent' },
      },
    };

    const res = handlerWithActiveCooking.handleRequest(req);
    assert.ok(res.response.outputSpeech?.text?.includes('Step 3 for Khasiko Masu'));
  });

  it('handles WhistleCountIntent and reports live siti counts', () => {
    const req: AlexaRequestBody = {
      version: '1.0',
      request: {
        type: 'IntentRequest',
        requestId: 'req-6',
        timestamp: new Date().toISOString(),
        intent: { name: 'WhistleCountIntent' },
      },
    };

    const res = handlerWithActiveCooking.handleRequest(req);
    assert.ok(res.response.outputSpeech?.text?.includes('blown 3 of 4 whistles'));
  });

  it('handles SetTimerIntent and Help/Stop intents', () => {
    const timerReq: AlexaRequestBody = {
      version: '1.0',
      request: {
        type: 'IntentRequest',
        requestId: 'req-7',
        timestamp: new Date().toISOString(),
        intent: {
          name: 'SetTimerIntent',
          slots: { duration: { name: 'duration', value: '10' } },
        },
      },
    };
    const timerRes = handlerWithNoActiveSession.handleRequest(timerReq);
    assert.ok(timerRes.response.outputSpeech?.text?.includes('10 minutes'));

    const stopReq: AlexaRequestBody = {
      version: '1.0',
      request: {
        type: 'IntentRequest',
        requestId: 'req-8',
        timestamp: new Date().toISOString(),
        intent: { name: 'AMAZON.StopIntent' },
      },
    };
    const stopRes = handlerWithNoActiveSession.handleRequest(stopReq);
    assert.equal(stopRes.response.shouldEndSession, true);
    assert.ok(stopRes.response.outputSpeech?.text?.includes('Goodbye'));
  });
});
