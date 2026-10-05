import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { app } from '../index.js';

describe('Telemetry & Launch Gate Verification Endpoints (Section 28.3)', () => {
  it('POST /v1/telemetry/session accepts anonymized session metrics and calculates crash-free rate', async () => {
    const res = await app.request('/v1/telemetry/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        sessionId: '01925b44-a1e4-7d5a-93f0-4dc81001a001',
        durationMs: 450000,
        crashed: false,
        platform: 'android',
        appVersion: '3.0.0-beta.1',
      }),
    });

    assert.equal(res.status, 201);
    const body = (await res.json()) as any;
    assert.equal(body.status, 'recorded');
    assert.equal(body.sessionId, '01925b44-a1e4-7d5a-93f0-4dc81001a001');
    assert.equal(body.crashFreeStats.passesGate, true);
    assert.ok(body.crashFreeStats.crashFreeRate >= 0.995);
  });

  it('POST /v1/telemetry/session rejects requests missing sessionId', async () => {
    const res = await app.request('/v1/telemetry/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        durationMs: 20000,
      }),
    });

    assert.equal(res.status, 400);
    const body = (await res.json()) as any;
    assert.equal(body.error, 'INVALID_PAYLOAD');
  });

  it('GET /v1/telemetry/cf-budget returns sustainable free-tier usage under 70%', async () => {
    const res = await app.request('/v1/telemetry/cf-budget', {
      method: 'GET',
    });

    assert.equal(res.status, 200);
    const body = (await res.json()) as any;
    assert.equal(body.status, 'PASS');
    assert.equal(body.evaluation.passesGate, true);
    assert.equal(body.evaluation.alerts.length, 0);
    assert.ok(body.evaluation.maxUtilizationRate < 0.70);
  });

  it('GET /v1/telemetry/cf-budget triggers alert when simulated requests exceed 70%', async () => {
    // 78,000 requests = 78% of 100k daily free tier
    const res = await app.request('/v1/telemetry/cf-budget?requests=78000', {
      method: 'GET',
    });

    assert.equal(res.status, 200);
    const body = (await res.json()) as any;
    assert.equal(body.status, 'ALERT_TRIGGERED');
    assert.equal(body.evaluation.passesGate, false);
    assert.ok(body.evaluation.alerts.length > 0);
    assert.match(body.evaluation.alerts[0], /workersRequests.*exceeded 70%/);
  });

  it('GET /v1/telemetry/launch-gate-status certifies Week 24 Open Beta readiness', async () => {
    const res = await app.request('/v1/telemetry/launch-gate-status', {
      method: 'GET',
    });

    assert.equal(res.status, 200);
    const body = (await res.json()) as any;
    assert.equal(body.gate, 'Week 24 Open Beta Gate (Section 28.3)');
    const report = body.report;

    assert.equal(report.readyForOpenBeta, true);
    assert.equal(report.passedGatesCount, 4);
    assert.equal(report.totalGatesCount, 4);

    // Gate 1: Crash-free >= 99.5%
    assert.equal(report.gates.crashFreeSessions.passesGate, true);
    assert.ok(report.gates.crashFreeSessions.crashFreeRate >= 0.995);

    // Gate 2: Cloudflare free-tier < 70%
    assert.equal(report.gates.cloudflareFreeTier.passesGate, true);

    // Gate 3: Privacy & compliance
    assert.equal(report.gates.privacyCompliance.passesGate, true);
    assert.equal(report.gates.privacyCompliance.checklist['Nepal Individual Privacy Act 2075 Compliance'], true);
    assert.equal(report.gates.privacyCompliance.checklist['EU GDPR Articles 12-23 (Access, Rectification, Erasure)'], true);
    assert.equal(report.gates.privacyCompliance.checklist['100% On-Device Acoustic Processing (Zero Audio Transmission)'], true);

    // Gate 4: Weekly cooking rate >= 40%
    assert.equal(report.gates.weeklyCookingRate.passesGate, true);
    assert.ok(report.gates.weeklyCookingRate.weeklyCookingRate >= 0.40);
  });

  it('GET /v1/legal/privacy returns Nepal Privacy Act & GDPR guarantees', async () => {
    const res = await app.request('/v1/legal/privacy', {
      method: 'GET',
    });

    assert.equal(res.status, 200);
    const body = (await res.json()) as any;
    assert.equal(body.policyVersion, '3.0.0');
    assert.ok(body.regulations.includes('Nepal Individual Privacy Act, 2075 (2018)'));
    assert.ok(body.regulations.includes('EU General Data Protection Regulation (GDPR)'));
    assert.match(body.commitments.audioProcessing, /100% on-device/);
    assert.match(body.commitments.advertisingRankBias, /Zero advertising/);
  });

  it('GET /v1/legal/terms returns non-medical disclaimer and governing law', async () => {
    const res = await app.request('/v1/legal/terms', {
      method: 'GET',
    });

    assert.equal(res.status, 200);
    const body = (await res.json()) as any;
    assert.equal(body.termsVersion, '3.0.0');
    assert.match(body.safetyDisclaimers.notMedicalDevice, /not medical/);
    assert.match(body.safetyDisclaimers.physicalSafety, /physical pressure cooker safety/);
    assert.match(body.governingLaw, /Laws of Nepal/);
  });
});
