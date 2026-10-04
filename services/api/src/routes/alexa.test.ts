import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { app } from '../index.js';
import { setAlexaServerState, resetAlexaServerState } from './alexa.js';

describe('POST /v1/alexa - Smart Display Alexa Skill', () => {
  beforeEach(() => {
    resetAlexaServerState();
  });

  it('rejects malformed Alexa requests with 400', async () => {
    const res = await app.request('/v1/alexa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });

    assert.equal(res.status, 400);
    const data = await res.json() as { error: string };
    assert.equal(data.error, 'BAD_REQUEST');
  });

  it('handles LaunchRequest on audio-only Echo device', async () => {
    const res = await app.request('/v1/alexa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        version: '1.0',
        request: {
          type: 'LaunchRequest',
          requestId: 'req-audio-1',
          timestamp: new Date().toISOString(),
        },
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json() as { response: { outputSpeech: { text: string }; directives?: unknown[] } };
    assert.ok(body.response.outputSpeech.text.includes('Welcome to Siti Counter!'));
    assert.equal(body.response.directives, undefined);
  });

  it('handles LaunchRequest on Echo Show with APL directive rendering Today Menu', async () => {
    const res = await app.request('/v1/alexa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
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
          requestId: 'req-apl-1',
          timestamp: new Date().toISOString(),
        },
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json() as { response: { directives: Array<{ type: string; document: unknown }> } };
    assert.ok(body.response.directives && body.response.directives.length === 1);
    assert.equal(body.response.directives[0].type, 'Alexa.Presentation.APL.RenderDocument');
  });

  it('handles LaunchRequest with active cooking session on Echo Show', async () => {
    setAlexaServerState({
      activeCookingSession: {
        recipeName: 'Khasiko Masu',
        stepIndex: 1,
        totalSteps: 4,
        instruction: 'Sear meat on high heat with spices.',
        whistlesCount: 2,
        whistlesTarget: 4,
        timerRemainingSeconds: 180,
        flameLevel: 'high',
      },
    });

    const res = await app.request('/v1/alexa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
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
          requestId: 'req-active-1',
          timestamp: new Date().toISOString(),
        },
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json() as {
      response: {
        outputSpeech: { text: string };
        directives: Array<{ type: string; datasources: { stepData: { recipeName: string } } }>;
      };
    };
    assert.ok(body.response.outputSpeech.text.includes('cooking Khasiko Masu'));
    assert.equal(body.response.directives[0].datasources.stepData.recipeName, 'Khasiko Masu');
  });

  it('handles TodaysMenuIntent', async () => {
    const res = await app.request('/v1/alexa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        version: '1.0',
        request: {
          type: 'IntentRequest',
          requestId: 'req-menu-1',
          timestamp: new Date().toISOString(),
          intent: { name: 'TodaysMenuIntent' },
        },
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json() as { response: { outputSpeech: { text: string } } };
    assert.ok(body.response.outputSpeech.text.includes('Kalo Dal'));
  });

  it('handles CookingStepIntent with active session', async () => {
    setAlexaServerState({
      activeCookingSession: {
        recipeName: 'Yellow Dal',
        stepIndex: 2,
        totalSteps: 3,
        instruction: 'Add jimbu tadka and let rest for 2 minutes.',
        whistlesCount: 3,
        whistlesTarget: 3,
        timerRemainingSeconds: 120,
        flameLevel: 'off',
      },
    });

    const res = await app.request('/v1/alexa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        version: '1.0',
        request: {
          type: 'IntentRequest',
          requestId: 'req-step-1',
          timestamp: new Date().toISOString(),
          intent: { name: 'CookingStepIntent' },
        },
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json() as { response: { outputSpeech: { text: string } } };
    assert.ok(body.response.outputSpeech.text.includes('Step 3 for Yellow Dal'));
  });

  it('handles WhistleCountIntent with active session and reports target status', async () => {
    setAlexaServerState({
      activeCookingSession: {
        recipeName: 'Pulao',
        stepIndex: 1,
        totalSteps: 2,
        instruction: 'Wait for 2 whistles.',
        whistlesCount: 2,
        whistlesTarget: 2,
        timerRemainingSeconds: 0,
        flameLevel: 'high',
      },
    });

    const res = await app.request('/v1/alexa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
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
          type: 'IntentRequest',
          requestId: 'req-whistle-1',
          timestamp: new Date().toISOString(),
          intent: { name: 'WhistleCountIntent' },
        },
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json() as {
      response: {
        outputSpeech: { text: string };
        directives: Array<{ datasources: { whistleData: { isFinished: boolean } } }>;
      };
    };
    assert.ok(body.response.outputSpeech.text.includes('Turn off the flame'));
    assert.equal(body.response.directives[0].datasources.whistleData.isFinished, true);
  });

  it('handles SetTimerIntent and StopIntent', async () => {
    const timerRes = await app.request('/v1/alexa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        version: '1.0',
        request: {
          type: 'IntentRequest',
          requestId: 'req-timer-1',
          timestamp: new Date().toISOString(),
          intent: {
            name: 'SetTimerIntent',
            slots: { duration: { name: 'duration', value: '15' } },
          },
        },
      }),
    });

    assert.equal(timerRes.status, 200);
    const timerBody = await timerRes.json() as { response: { outputSpeech: { text: string } } };
    assert.ok(timerBody.response.outputSpeech.text.includes('15 minutes'));

    const stopRes = await app.request('/v1/alexa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        version: '1.0',
        request: {
          type: 'IntentRequest',
          requestId: 'req-stop-1',
          timestamp: new Date().toISOString(),
          intent: { name: 'AMAZON.StopIntent' },
        },
      }),
    });

    assert.equal(stopRes.status, 200);
    const stopBody = await stopRes.json() as { response: { shouldEndSession: boolean; outputSpeech: { text: string } } };
    assert.equal(stopBody.response.shouldEndSession, true);
    assert.ok(stopBody.response.outputSpeech.text.includes('Goodbye'));
  });
});
