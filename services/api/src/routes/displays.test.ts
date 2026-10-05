import { describe, it, beforeEach } from 'node:test'
import assert from 'node:assert'
import { app } from '../index.js'
import { resetSyncStore } from './sync.js'
import { resetTokenStore, registerAccessToken } from '../middleware/household_auth.js'
import { UuidV7 } from '@siti-counter/kitchen-engine'

function authHeaders(householdId: string): Record<string, string> {
  const token = `atk_display_${householdId}_${UuidV7.generate()}`
  registerAccessToken(token, householdId)
  return { Authorization: `Bearer ${token}` }
}

async function sync(householdId: string, changes: Array<Record<string, unknown>>) {
  const res = await app.request('/v1/sync', {
    method: 'POST',
    headers: { ...authHeaders(householdId), 'Content-Type': 'application/json' },
    body: JSON.stringify({ householdId, changes }),
  })
  assert.strictEqual(res.status, 200, `sync failed: ${await res.clone().text()}`)
}

async function feed(householdId: string, headers: Record<string, string> = authHeaders(householdId)) {
  const res = await app.request('/v1/displays/feed', { headers })
  return res
}

const TODAY = new Date().toISOString().split('T')[0]

describe('GET /v1/displays/feed - glanceable widget & watch feed', () => {
  beforeEach(() => {
    resetSyncStore()
    resetTokenStore()
  })

  it('requires a bearer token', async () => {
    const res = await app.request('/v1/displays/feed')
    assert.strictEqual(res.status, 401)
    const data = (await res.json()) as any
    assert.strictEqual(data.error, 'UNAUTHORIZED')
  })

  it('rejects a householdId query parameter the token is not scoped to', async () => {
    const res = await app.request('/v1/displays/feed?householdId=h_someone_else', {
      headers: authHeaders('h_owner'),
    })
    assert.strictEqual(res.status, 403)
  })

  it('serves empty payloads for a household with no data', async () => {
    const res = await feed('h_empty')
    assert.strictEqual(res.status, 200)
    const data = (await res.json()) as any

    assert.strictEqual(data.todaysMeals.totalPlannedMeals, 0)
    assert.strictEqual(data.activeSiti, null)
    assert.strictEqual(data.watchState, null)
    assert.strictEqual(data.groceryChecklist.totalItems, 0)
    assert.ok(data.etag)
  })

  it('builds the todays meals payload from synced meal plans', async () => {
    const householdId = 'h_meals'
    await sync(householdId, [
      {
        id: UuidV7.generate(),
        entityType: 'meal_plan',
        entityId: 'slot_breakfast',
        version: 1,
        payload: {
          dateIso: TODAY,
          slotId: 'breakfast',
          slotTitleEn: 'Breakfast',
          slotTitleNe: 'बिहानीको खाना',
          recipeTitleEn: 'Masyang Dal & Bhat',
          recipeTitleNe: 'मास्याङ दाल र भात',
          servings: 4,
          sortOrder: 1,
          rituNameEn: 'Sharad',
          rituNameNe: 'शरद',
        },
      },
      {
        id: UuidV7.generate(),
        entityType: 'meal_plan',
        entityId: 'slot_dinner',
        version: 1,
        payload: {
          dateIso: TODAY,
          slotId: 'dinner',
          slotTitleEn: 'Dinner',
          slotTitleNe: 'रातिको खाना',
          recipeTitleEn: 'Aloo Tama',
          recipeTitleNe: 'आलु तामा',
          servings: 3,
          sortOrder: 2,
        },
      },
      // A different date must not leak into today's widget.
      {
        id: UuidV7.generate(),
        entityType: 'meal_plan',
        entityId: 'slot_tomorrow',
        version: 1,
        payload: { dateIso: '2099-01-01', slotId: 'lunch', recipeTitleEn: 'Future Khichdi' },
      },
    ])

    const res = await feed(householdId)
    const data = (await res.json()) as any

    assert.strictEqual(data.todaysMeals.totalPlannedMeals, 2)
    assert.strictEqual(data.todaysMeals.dateIso, TODAY)
    assert.deepStrictEqual(
      data.todaysMeals.meals.map((m: any) => m.slotId),
      ['breakfast', 'dinner'],
    )
    assert.strictEqual(data.todaysMeals.meals[0].servings, 4)
  })

  it('keeps only the newest version of a re-planned slot', async () => {
    const householdId = 'h_replan'
    await sync(householdId, [
      {
        id: UuidV7.generate(1000),
        entityType: 'meal_plan',
        entityId: 'slot_lunch',
        version: 1,
        payload: { dateIso: TODAY, slotId: 'lunch', recipeTitleEn: 'Old Khichdi', sortOrder: 1 },
      },
    ])
    await sync(householdId, [
      {
        id: UuidV7.generate(2000),
        entityType: 'meal_plan',
        entityId: 'slot_lunch',
        version: 2,
        payload: { dateIso: TODAY, slotId: 'lunch', recipeTitleEn: 'New Khichdi', sortOrder: 1 },
      },
    ])

    const data = (await (await feed(householdId)).json()) as any
    assert.strictEqual(data.todaysMeals.totalPlannedMeals, 1)
    assert.strictEqual(data.todaysMeals.meals[0].recipeTitleEn, 'New Khichdi')
  })

  it('builds the active siti and watch payloads from the live batch', async () => {
    const householdId = 'h_cooking'
    await sync(householdId, [
      {
        id: UuidV7.generate(),
        entityType: 'batch',
        entityId: 'session_1',
        version: 1,
        payload: {
          dishTitleEn: 'Khasi ko Masu',
          dishTitleNe: 'खसीको मासु',
          currentWhistles: 2,
          targetWhistles: 4,
          currentStepIndex: 1,
          updatedAt: 1000,
          stepsEn: ['Wash meat', 'Cook with spices', 'Add water', 'Pressure cook'],
          stepsNe: ['मासु धोऊनुहोस्', 'मसला राख्नुहोस्', 'पानी हाल्नुहोस्', 'कुकरमा पकाउनुहोस्'],
        },
      },
    ])

    const data = (await (await feed(householdId)).json()) as any

    assert.strictEqual(data.activeSiti.currentWhistles, 2)
    assert.strictEqual(data.activeSiti.targetWhistles, 4)
    assert.strictEqual(data.activeSiti.progressPercent, 50)
    assert.strictEqual(data.activeSiti.isAlarmActive, false)

    assert.strictEqual(data.watchState.totalSteps, 4)
    assert.strictEqual(data.watchState.currentStepIndex, 1)
    assert.strictEqual(data.watchState.currentStepInstructionEn, 'Cook with spices')
    assert.strictEqual(data.watchState.currentStepInstructionNe, 'मसला राख्नुहोस्')
    assert.strictEqual(data.watchState.lastHapticPattern, 'whistle')
  })

  it('raises the alarm when the whistle target is reached', async () => {
    const householdId = 'h_alarm'
    await sync(householdId, [
      {
        id: UuidV7.generate(),
        entityType: 'batch',
        entityId: 'session_alarm',
        version: 1,
        payload: {
          dishTitleEn: 'Kalo Dal',
          dishTitleNe: 'कालो दाल',
          currentWhistles: 4,
          targetWhistles: 4,
          updatedAt: 1000,
          stepsEn: ['Soak', 'Boil'],
          stepsNe: ['भिजाउनुहोस्', 'उमाल्नुहोस्'],
        },
      },
    ])

    const data = (await (await feed(householdId)).json()) as any
    assert.strictEqual(data.activeSiti.isAlarmActive, true)
    assert.strictEqual(data.activeSiti.status, 'alarm')
    assert.strictEqual(data.watchState.status, 'alarm')
    assert.strictEqual(data.watchState.lastHapticPattern, 'targetReached')
  })

  it('keeps an acknowledged alarm dismissed even at the target count', async () => {
    const householdId = 'h_ack'
    await sync(householdId, [
      {
        id: UuidV7.generate(),
        entityType: 'batch',
        entityId: 'session_ack',
        version: 1,
        payload: {
          dishTitleEn: 'Kalo Dal',
          dishTitleNe: 'कालो दाल',
          currentWhistles: 5,
          targetWhistles: 4,
          isAlarmActive: true,
          isAlarmAcknowledged: true,
          updatedAt: 1000,
          stepsEn: ['Soak'],
          stepsNe: ['भिजाउनुहोस्'],
        },
      },
    ])

    const data = (await (await feed(householdId)).json()) as any
    assert.strictEqual(data.activeSiti.isAlarmActive, false)
    assert.strictEqual(data.activeSiti.status, 'completed')
    assert.strictEqual(data.watchState.status, 'completed')
  })

  it('never raises an alarm when no whistle target is configured', async () => {
    const householdId = 'h_notarget'
    await sync(householdId, [
      {
        id: UuidV7.generate(),
        entityType: 'batch',
        entityId: 'session_notarget',
        version: 1,
        payload: {
          dishTitleEn: 'Steamed Vegetables',
          dishTitleNe: 'स्टिम्ड सब्जी',
          currentWhistles: 0,
          targetWhistles: 0,
          updatedAt: 1000,
          stepsEn: ['Steam'],
          stepsNe: ['स्टिम गर्नुहोस्'],
        },
      },
    ])

    const data = (await (await feed(householdId)).json()) as any
    assert.strictEqual(data.activeSiti.isAlarmActive, false)
    assert.strictEqual(data.activeSiti.progressPercent, 0)
  })

  it('surfaces pending grocery items first in the preview', async () => {
    const householdId = 'h_grocery'
    await sync(householdId, [
      ...[1, 2, 3, 4, 5, 6].map((n) => ({
        id: UuidV7.generate(),
        entityType: 'grocery_item',
        entityId: `item_${n}`,
        version: 1,
        // The first four are already in the pantry, so a naive "first five" preview would
        // show only completed rows.
        payload: { nameEn: `Item ${n}`, nameNe: `सामान ${n}`, quantityStr: '1 kg', isCompleted: n <= 4 },
      })),
    ])

    const data = (await (await feed(householdId)).json()) as any
    assert.strictEqual(data.groceryChecklist.totalItems, 6)
    assert.strictEqual(data.groceryChecklist.completedItems, 4)
    assert.strictEqual(data.groceryChecklist.pendingItems, 2)
    assert.strictEqual(data.groceryChecklist.previewItems.length, 5)
    assert.strictEqual(data.groceryChecklist.previewItems[0].isCompleted, false)
    assert.strictEqual(data.groceryChecklist.previewItems[0].nameEn, 'Item 5')
  })

  it('returns 304 with no body when the ETag still matches', async () => {
    const householdId = 'h_etag'
    await sync(householdId, [
      {
        id: UuidV7.generate(),
        entityType: 'grocery_item',
        entityId: 'item_salt',
        version: 1,
        payload: { nameEn: 'Salt', nameNe: 'नुन', quantityStr: '1 pkt', isCompleted: false },
      },
    ])

    const firstRes = await feed(householdId)
    assert.strictEqual(firstRes.status, 200)
    const etag = firstRes.headers.get('etag')
    assert.ok(etag, 'expected an ETag header')

    const revalidated = await feed(householdId, { ...authHeaders(householdId), 'If-None-Match': etag })
    assert.strictEqual(revalidated.status, 304)
    assert.strictEqual(await revalidated.text(), '')
  })

  it('changes the ETag once household data changes', async () => {
    const householdId = 'h_etag_change'
    await sync(householdId, [
      {
        id: UuidV7.generate(),
        entityType: 'grocery_item',
        entityId: 'item_rice',
        version: 1,
        payload: { nameEn: 'Rice', nameNe: 'भात', quantityStr: '1 kg', isCompleted: false },
      },
    ])

    const before = (await feed(householdId)).headers.get('etag')

    await sync(householdId, [
      {
        id: UuidV7.generate(),
        entityType: 'grocery_item',
        entityId: 'item_lentil',
        version: 1,
        payload: { nameEn: 'Lentil', nameNe: 'दाल', quantityStr: '1 kg', isCompleted: false },
      },
    ])

    const after = (await feed(householdId)).headers.get('etag')
    assert.notStrictEqual(after, before)
  })

  it('scopes the feed to the token household', async () => {
    await sync('h_alpha', [
      {
        id: UuidV7.generate(),
        entityType: 'grocery_item',
        entityId: 'alpha_item',
        version: 1,
        payload: { nameEn: 'Alpha Salt', quantityStr: '1 pkt' },
      },
    ])

    const alphaData = (await (await feed('h_alpha')).json()) as any
    const betaData = (await (await feed('h_beta')).json()) as any

    assert.strictEqual(alphaData.groceryChecklist.totalItems, 1)
    assert.strictEqual(betaData.groceryChecklist.totalItems, 0)
  })
})