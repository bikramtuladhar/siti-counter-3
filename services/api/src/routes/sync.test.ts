import { describe, it, beforeEach } from 'node:test'
import assert from 'node:assert'
import { app } from '../index.js'
import { resetSyncStore } from './sync.js'
import { resetTokenStore, registerAccessToken } from '../middleware/household_auth.js'
import { UuidV7 } from '@siti-counter/kitchen-engine'

/**
 * Mints a bearer token scoped to `householdId`, mirroring what `/v1/auth/*` issues, and
 * returns the headers every authenticated sync request must carry.
 */
function authHeaders(householdId: string): Record<string, string> {
  const token = `atk_test_${householdId}_${UuidV7.generate()}`
  registerAccessToken(token, householdId)
  return { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }
}

function post(householdId: string, body: Record<string, unknown>) {
  return app.request('/v1/sync', {
    method: 'POST',
    headers: authHeaders(householdId),
    body: JSON.stringify({ householdId, ...body }),
  })
}

describe('POST /v1/sync - Delta Synchronization API', () => {
  beforeEach(() => {
    resetSyncStore()
    resetTokenStore()
  })

  it('rejects requests without householdId', async () => {
    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: authHeaders('h1'),
      body: JSON.stringify({ changes: [] }),
    })

    assert.strictEqual(res.status, 400)
    const data = (await res.json()) as any
    assert.strictEqual(data.error, 'INVALID_REQUEST')
  })

  it('rejects requests without a bearer token', async () => {
    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ householdId: 'h1', changes: [] }),
    })

    assert.strictEqual(res.status, 401)
    const data = (await res.json()) as any
    assert.strictEqual(data.error, 'UNAUTHORIZED')
  })

  it('rejects an unknown bearer token', async () => {
    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer atk_forged' },
      body: JSON.stringify({ householdId: 'h1', changes: [] }),
    })

    assert.strictEqual(res.status, 401)
  })

  it('rejects a body claiming a household the token is not scoped to', async () => {
    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: authHeaders('h_owner'),
      body: JSON.stringify({ householdId: 'h_victim', changes: [] }),
    })

    assert.strictEqual(res.status, 403)
    const data = (await res.json()) as any
    assert.strictEqual(data.error, 'FORBIDDEN')

    // The other household's store must be untouched by the rejected write.
    const victimRes = await post('h_victim', { changes: [] })
    const victimData = (await victimRes.json()) as any
    assert.strictEqual(victimData.applied, 0)
  })

  it('rejects oversized payload exceeding 30KB budget', async () => {
    const householdId = 'h1'
    const hugePayload = 'X'.repeat(31 * 1024)
    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: authHeaders(householdId),
      body: JSON.stringify({
        changes: [
          {
            id: UuidV7.generate(),
            entityType: 'batch',
            entityId: 'b1',
            version: 1,
            payload: { data: hugePayload },
          },
        ],
      }),
    })

    assert.strictEqual(res.status, 413)
    const data = (await res.json()) as any
    assert.strictEqual(data.error, 'PAYLOAD_TOO_LARGE')
  })

  it('applies batch changes with UUIDv7 and returns syncToken', async () => {
    const householdId = 'h_ktm_01'
    const id1 = UuidV7.generate()
    const id2 = UuidV7.generate()

    const res = await post(householdId, {
      changes: [
        {
          id: id1,
          entityType: 'meal_plan',
          entityId: 'plan_2080_07_15',
          version: 1,
          payload: { dish: 'Kwati', slot: 'dinner' },
        },
        {
          id: id2,
          entityType: 'grocery_item',
          entityId: 'kwati_beans',
          version: 1,
          payload: { packagesToBuy: 2 },
        },
      ],
    })

    assert.strictEqual(res.status, 200)
    const data = (await res.json()) as any
    assert.strictEqual(data.applied, 2)
    assert.strictEqual(data.conflicts.length, 0)
    assert.ok(data.syncToken.startsWith('st_'))
    assert.ok(data.serverTime)
  })

  it('rejects mutations with invalid UUIDv7 format', async () => {
    const res = await post('h1', {
      changes: [
        {
          id: 'not-a-valid-uuid',
          entityType: 'batch',
          entityId: 'b1',
          version: 1,
          payload: {},
        },
      ],
    })

    assert.strictEqual(res.status, 200)
    const data = (await res.json()) as any
    assert.strictEqual(data.applied, 0)
    assert.strictEqual(data.conflicts.length, 1)
    assert.strictEqual(data.conflicts[0].reason, 'INVALID_UUIDV7')
  })

  it('detects safety conflicts on allergen modification', async () => {
    const householdId = 'h_allergy_01'
    const memberId = 'm_aayush'

    await post(householdId, {
      changes: [
        {
          id: UuidV7.generate(1000),
          entityType: 'member',
          entityId: memberId,
          version: 1,
          payload: { name: 'Aayush', allergies: ['peanut', 'mustard'] },
        },
      ],
    })

    const conflictRes = await post(householdId, {
      changes: [
        {
          id: UuidV7.generate(2000),
          entityType: 'member',
          entityId: memberId,
          version: 2,
          payload: { name: 'Aayush', allergies: ['dairy'] },
        },
      ],
    })

    const data = (await conflictRes.json()) as any
    assert.strictEqual(data.applied, 0)
    assert.strictEqual(data.conflicts.length, 1)
    assert.strictEqual(data.conflicts[0].requiresPrompt, true)
    assert.strictEqual(data.conflicts[0].reason, 'ALLERGY_MODIFICATION_REQUIRES_CONFIRMATION')
    assert.ok(data.conflicts[0].safeMergedPayload.allergies.includes('peanut'))
  })

  it('delivers remote changes to a secondary device using lastSyncToken', async () => {
    const householdId = 'h_multi_01'

    const tokenRes = await post(householdId, {
      changes: [
        {
          id: UuidV7.generate(),
          entityType: 'meal_plan',
          entityId: 'lunch_monday',
          version: 1,
          payload: { dish: 'Aalu Tama Bodi' },
        },
      ],
    })
    const initialSync = (await tokenRes.json()) as any
    assert.ok(initialSync.syncToken)

    const deviceBRes = await post(householdId, { lastSyncToken: null, changes: [] })
    const dataB = (await deviceBRes.json()) as any
    assert.strictEqual(dataB.remoteChanges.length, 1)
    assert.strictEqual(dataB.remoteChanges[0].entityId, 'lunch_monday')
    assert.strictEqual(dataB.remoteChanges[0].payload.dish, 'Aalu Tama Bodi')

    const deviceBSubsequentRes = await post(householdId, {
      lastSyncToken: dataB.syncToken,
      changes: [],
    })
    const dataB2 = (await deviceBSubsequentRes.json()) as any
    assert.strictEqual(dataB2.remoteChanges.length, 0)
  })
})