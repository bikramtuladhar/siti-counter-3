import test from 'node:test'
import assert from 'node:assert/strict'
import { app } from './index.js'
import { registerAccessToken } from './middleware/household_auth.js'
import { UuidV7 } from '@siti-counter/kitchen-engine'

function authHeaders(householdId: string): Record<string, string> {
  const token = `atk_index_${UuidV7.generate()}`
  registerAccessToken(token, householdId)
  return { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }
}

test('GET /health returns healthy status', async () => {
  const res = await app.request('/health')
  assert.equal(res.status, 200)

  const body = (await res.json()) as { status: string; service: string }
  assert.equal(body.status, 'healthy')
  assert.equal(body.service, 'siti-counter-api')
})

test('POST /v1/sync rejects request without householdId', async () => {
  const res = await app.request('/v1/sync', {
    method: 'POST',
    headers: authHeaders('hh_01923456-7890-7abc-def0-123456789abc'),
    body: JSON.stringify({})
  })
  assert.equal(res.status, 400)

  const body = (await res.json()) as { error: string }
  assert.equal(body.error, 'INVALID_REQUEST')
})

test('POST /v1/sync rejects an unauthenticated request', async () => {
  const res = await app.request('/v1/sync', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ householdId: 'hh_anonymous', changes: [] })
  })
  assert.equal(res.status, 401)
})

test('POST /v1/sync applies client changes and issues syncToken', async () => {
  const householdId = 'hh_01923456-7890-7abc-def0-123456789abc'
  const res = await app.request('/v1/sync', {
    method: 'POST',
    headers: authHeaders(householdId),
    body: JSON.stringify({
      householdId,
      changes: [
        {
          id: UuidV7.generate(),
          entityType: 'household',
          entityId: householdId,
          version: 1,
          payload: { name: 'Tuladhar Home', regionPack: 'nepal-bagmati' }
        }
      ]
    })
  })

  assert.equal(res.status, 200)
  const body = (await res.json()) as { syncToken: string; applied: number }
  assert.equal(body.applied, 1)
  assert.ok(body.syncToken.startsWith('st_'))
})
