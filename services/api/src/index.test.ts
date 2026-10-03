import test from 'node:test'
import assert from 'node:assert/strict'
import { app } from './index.js'

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
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  })
  assert.equal(res.status, 400)

  const body = (await res.json()) as { error: string }
  assert.equal(body.error, 'INVALID_REQUEST')
})

test('POST /v1/sync applies client changes and issues syncToken', async () => {
  const res = await app.request('/v1/sync', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      householdId: 'hh_01923456-7890-7abc-def0-123456789abc',
      changes: [
        {
          id: 'chg_1',
          entityType: 'household',
          entityId: 'hh_01923456-7890-7abc-def0-123456789abc',
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
