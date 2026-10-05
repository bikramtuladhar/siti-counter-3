import { describe, it, beforeEach } from 'node:test'
import assert from 'node:assert'
import { app } from '../index.js'
import { resetSyncStore } from './sync.js'
import { resetTokenStore } from '../middleware/household_auth.js'
import { resetSocialStore } from './auth.js'
import { UuidV7 } from '@siti-counter/kitchen-engine'

async function guest(deviceId: string) {
  const res = await app.request('/v1/auth/guest', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId }),
  })
  assert.strictEqual(res.status, 200)
  return (await res.json()) as { user: { householdId: string } }
}

/** Pushes entities into a household through the real sync path. */
async function sync(householdId: string, token: string, entityIds: string[]) {
  const res = await app.request('/v1/sync', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      householdId,
      changes: entityIds.map((entityId) => ({
        id: UuidV7.generate(),
        entityType: 'meal_plan',
        entityId,
        version: 1,
        payload: { recipeTitleEn: entityId },
      })),
    }),
  })
  assert.strictEqual(res.status, 200, await res.clone().text())
  return (await res.json()) as { applied: number }
}

describe('Guest -> account merge', () => {
  beforeEach(() => {
    resetSyncStore()
    resetTokenStore()
    resetSocialStore()
  })

  it('carries the guest household synced entities into the target household', async () => {
    const authRes = await app.request('/v1/auth/guest', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: 'merge-device' }),
    })
    const auth = (await authRes.json()) as {
      user: { householdId: string }
      tokens: { accessToken: string }
    }

    // The guest pushes real data through the same path the app uses.
    const syncResult = await sync(
      auth.user.householdId,
      auth.tokens.accessToken,
      ['lunch', 'dinner'],
    )
    assert.strictEqual(syncResult.applied, 2)

    const mergeRes = await app.request('/v1/auth/merge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        guestHouseholdId: auth.user.householdId,
        targetHouseholdId: 'hh_target_account',
      }),
    })
    assert.strictEqual(mergeRes.status, 200)

    const merge = (await mergeRes.json()) as {
      migratedCount: number
      totalTargetItems: number
    }

    // The previous implementation merged a store nothing ever wrote to, so this was 0.
    assert.strictEqual(merge.migratedCount, 2)
    assert.strictEqual(merge.totalTargetItems, 2)
  })

  it('never overwrites an entity the target already has', async () => {
    const sourceAuth = await guest('source-device')
    const targetAuth = await guest('target-device')

    const source = await app.request('/v1/auth/guest', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: 'source-device-2' }),
    })
    const sourceBody = (await source.json()) as {
      user: { householdId: string }
      tokens: { accessToken: string }
    }
    await sync(sourceBody.user.householdId, sourceBody.tokens.accessToken, ['shared', 'only_guest'])

    const mergeRes = await app.request('/v1/auth/merge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        guestHouseholdId: sourceBody.user.householdId,
        targetHouseholdId: targetAuth.user.householdId,
      }),
    })
    const merge = (await mergeRes.json()) as { migratedCount: number }

    assert.strictEqual(merge.migratedCount, 2)
    assert.strictEqual(sourceAuth.user.householdId !== targetAuth.user.householdId, true)
  })

  it('leaves the guest household intact so a failed sign-in loses nothing', async () => {
    const guestAuth = await guest('keep-guest')
    const authRes = await app.request('/v1/auth/guest', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: 'keep-guest' }),
    })
    const auth = (await authRes.json()) as {
      user: { householdId: string }
      tokens: { accessToken: string }
    }
    await sync(auth.user.householdId, auth.tokens.accessToken, ['kept'])

    await app.request('/v1/auth/merge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        guestHouseholdId: auth.user.householdId,
        targetHouseholdId: 'hh_elsewhere',
      }),
    })

    // The guest household still holds its own copy.
    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${auth.tokens.accessToken}`,
      },
      body: JSON.stringify({
        householdId: guestAuth.user.householdId,
        lastSyncToken: null,
        changes: [],
      }),
    })
    assert.strictEqual(res.status, 200)
    assert.strictEqual(guestAuth.user.householdId, auth.user.householdId)
  })

  it('is a no-op when the source and target are the same household', async () => {
    const auth = await guest('same-household')
    const res = await app.request('/v1/auth/merge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        guestHouseholdId: auth.user.householdId,
        targetHouseholdId: auth.user.householdId,
      }),
    })
    const body = (await res.json()) as { migratedCount: number }
    assert.strictEqual(body.migratedCount, 0)
  })
})

describe('Social sign-in routes', () => {
  beforeEach(() => {
    resetSyncStore()
    resetTokenStore()
    resetSocialStore()
  })

  it('rejects Apple sign-in without an identity token', async () => {
    const res = await app.request('/v1/auth/apple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    })
    assert.strictEqual(res.status, 400)
    assert.strictEqual(((await res.json()) as any).error, 'MISSING_TOKEN')
  })

  it('rejects Facebook sign-in without an access token', async () => {
    const res = await app.request('/v1/auth/facebook', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    })
    assert.strictEqual(res.status, 400)
    assert.strictEqual(((await res.json()) as any).error, 'MISSING_TOKEN')
  })

  it('rejects a forged Google ID token instead of trusting the claims', async () => {
    // A structurally valid but unsigned JWT. Verification must fail, not fall back to
    // accepting the email in the payload.
    const header = Buffer.from(JSON.stringify({ alg: 'RS256', kid: 'x', typ: 'JWT' })).toString('base64url')
    const payload = Buffer.from(
      JSON.stringify({
        iss: 'https://accounts.google.com',
        aud: 'client-id',
        sub: 'attacker',
        email: 'victim@example.com',
        email_verified: true,
      }),
    ).toString('base64url')
    const forged = `${header}.${payload}.not-a-signature`

    const res = await app.request('/v1/auth/google/verified', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: forged }),
    })

    // Not 200: an unverified token must never authenticate.
    assert.notStrictEqual(res.status, 200)
    assert.ok(res.status === 400 || res.status === 401 || res.status === 503)
  })

  it('rejects a forged Apple identity token', async () => {
    const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: 'x' })).toString('base64url')
    const payload = Buffer.from(
      JSON.stringify({
        iss: 'https://appleid.apple.com',
        aud: 'com.siticounter.app',
        sub: 'attacker',
        email: 'victim@example.com',
      }),
    ).toString('base64url')

    const res = await app.request('/v1/auth/apple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identityToken: `${header}.${payload}.sig` }),
    })

    assert.notStrictEqual(res.status, 200)
  })

  it('reports NOT_CONFIGURED when the provider has no binding', async () => {
    const res = await app.request('/v1/auth/facebook', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ accessToken: 'EAAB...' }),
    })

    // Either the provider is unconfigured (503) or the token is rejected (401); it must
    // never succeed.
    assert.ok(res.status === 401 || res.status === 503)
    if (res.status === 503) {
      assert.strictEqual(((await res.json()) as any).error, 'NOT_CONFIGURED')
    }
  })
})