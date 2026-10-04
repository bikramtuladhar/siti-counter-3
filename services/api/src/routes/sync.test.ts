import { describe, it, beforeEach } from 'node:test'
import assert from 'node:assert'
import { app } from '../index.js'
import { resetSyncStore } from './sync.js'
import { UuidV7 } from '@siti-counter/kitchen-engine'

describe('POST /v1/sync - Delta Synchronization API', () => {
  beforeEach(() => {
    resetSyncStore()
  })

  it('rejects requests without householdId', async () => {
    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ changes: [] })
    })

    assert.strictEqual(res.status, 400)
    const data = (await res.json()) as any
    assert.strictEqual(data.error, 'INVALID_REQUEST')
  })

  it('rejects oversized payload exceeding 30KB budget', async () => {
    const hugePayload = 'X'.repeat(31 * 1024)
    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId: 'h1',
        changes: [{ id: UuidV7.generate(), entityType: 'batch', entityId: 'b1', version: 1, payload: { data: hugePayload } }]
      })
    })

    assert.strictEqual(res.status, 413)
    const data = (await res.json()) as any
    assert.strictEqual(data.error, 'PAYLOAD_TOO_LARGE')
  })

  it('applies batch changes with UUIDv7 and returns syncToken', async () => {
    const householdId = 'h_ktm_01'
    const id1 = UuidV7.generate()
    const id2 = UuidV7.generate()

    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId,
        changes: [
          {
            id: id1,
            entityType: 'meal_plan',
            entityId: 'plan_2080_07_15',
            version: 1,
            payload: { dish: 'Kwati', slot: 'dinner' }
          },
          {
            id: id2,
            entityType: 'grocery_item',
            entityId: 'kwati_beans',
            version: 1,
            payload: { packagesToBuy: 2 }
          }
        ]
      })
    })

    assert.strictEqual(res.status, 200)
    const data = (await res.json()) as any
    assert.strictEqual(data.applied, 2)
    assert.strictEqual(data.conflicts.length, 0)
    assert.ok(data.syncToken.startsWith('st_'))
    assert.ok(data.serverTime)
  })

  it('rejects mutations with invalid UUIDv7 format', async () => {
    const res = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId: 'h1',
        changes: [
          {
            id: 'not-a-valid-uuid',
            entityType: 'batch',
            entityId: 'b1',
            version: 1,
            payload: {}
          }
        ]
      })
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

    // First, sync member with peanut and mustard allergies
    const id1 = UuidV7.generate(1000)
    await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId,
        changes: [
          {
            id: id1,
            entityType: 'member',
            entityId: memberId,
            version: 1,
            payload: { name: 'Aayush', allergies: ['peanut', 'mustard'] }
          }
        ]
      })
    })

    // Now, another client attempts to sync dropping peanut allergy
    const id2 = UuidV7.generate(2000)
    const conflictRes = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId,
        changes: [
          {
            id: id2,
            entityType: 'member',
            entityId: memberId,
            version: 2,
            payload: { name: 'Aayush', allergies: ['dairy'] }
          }
        ]
      })
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

    // Device A uploads a meal plan
    const tokenRes = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId,
        changes: [
          {
            id: UuidV7.generate(),
            entityType: 'meal_plan',
            entityId: 'lunch_monday',
            version: 1,
            payload: { dish: 'Aalu Tama Bodi' }
          }
        ]
      })
    })
    const initialSync = (await tokenRes.json()) as any
    const syncTokenA = initialSync.syncToken

    // Device B syncs with empty changes and lastSyncToken = null -> receives Device A's changes
    const deviceBRes = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId,
        lastSyncToken: null,
        changes: []
      })
    })

    const dataB = (await deviceBRes.json()) as any
    assert.strictEqual(dataB.remoteChanges.length, 1)
    assert.strictEqual(dataB.remoteChanges[0].entityId, 'lunch_monday')
    assert.strictEqual(dataB.remoteChanges[0].payload.dish, 'Aalu Tama Bodi')

    // Device B syncs again with the token it received -> 0 remote changes
    const deviceBSubsequentRes = await app.request('/v1/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId,
        lastSyncToken: dataB.syncToken,
        changes: []
      })
    })
    const dataB2 = (await deviceBSubsequentRes.json()) as any
    assert.strictEqual(dataB2.remoteChanges.length, 0)
  })
})
