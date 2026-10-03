import { test } from 'node:test';
import assert from 'node:assert';
import { app } from '../index.js';

test('POST /v1/auth/guest creates anonymous guest user and session tokens', async () => {
  const res = await app.request('/v1/auth/guest', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: 'test_dev_001', regionPackId: 'nepal-bagmati' })
  });

  assert.strictEqual(res.status, 200);
  const data = (await res.json()) as any;
  assert.strictEqual(data.user.isAnonymous, true);
  assert.ok(data.user.id.startsWith('usr_guest_'));
  assert.ok(data.user.householdId.startsWith('hh_'));
  assert.ok(data.tokens.accessToken.startsWith('atk_'));
  assert.ok(data.tokens.refreshToken.startsWith('rtk_'));
  assert.strictEqual(data.tokens.expiresIn, 900);
});

test('POST /v1/auth/magic-link send and verify flow', async () => {
  const sendRes = await app.request('/v1/auth/magic-link/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'nepalicook@example.com', guestHouseholdId: 'hh_test_guest' })
  });

  assert.strictEqual(sendRes.status, 200);
  const sendData = (await sendRes.json()) as any;
  assert.strictEqual(sendData.success, true);
  assert.ok(sendData.debugVerificationToken);

  // Verify magic link token
  const verifyRes = await app.request('/v1/auth/magic-link/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: sendData.debugVerificationToken })
  });

  assert.strictEqual(verifyRes.status, 200);
  const verifyData = (await verifyRes.json()) as any;
  assert.strictEqual(verifyData.user.email, 'nepalicook@example.com');
  assert.strictEqual(verifyData.user.isAnonymous, false);
  assert.ok(verifyData.tokens.accessToken);
});

test('POST /v1/auth/google verifies and logs in user', async () => {
  const res = await app.request('/v1/auth/google', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      idToken: 'mock_google_id_token_123',
      email: 'bikram@example.com',
      name: 'Bikram Tuladhar',
      guestHouseholdId: 'hh_guest_prior'
    })
  });

  assert.strictEqual(res.status, 200);
  const data = (await res.json()) as any;
  assert.strictEqual(data.user.email, 'bikram@example.com');
  assert.strictEqual(data.user.name, 'Bikram Tuladhar');
  assert.strictEqual(data.user.isAnonymous, false);
});

test('POST /v1/auth/refresh rotates refresh token and returns fresh access token', async () => {
  // First obtain guest token
  const guestRes = await app.request('/v1/auth/guest', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: 'test_dev_refresh' })
  });
  const guestData = (await guestRes.json()) as any;
  const oldRefreshToken = guestData.tokens.refreshToken;

  // Refresh token
  const refreshRes = await app.request('/v1/auth/refresh', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken: oldRefreshToken })
  });

  assert.strictEqual(refreshRes.status, 200);
  const refreshData = (await refreshRes.json()) as any;
  assert.ok(refreshData.tokens.accessToken);
  assert.notStrictEqual(refreshData.tokens.refreshToken, oldRefreshToken);

  // Reusing the old refresh token should be rejected (revoked / rotated)
  const reusedRes = await app.request('/v1/auth/refresh', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken: oldRefreshToken })
  });
  assert.strictEqual(reusedRes.status, 401);
});
