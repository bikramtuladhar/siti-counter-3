import { describe, it } from 'node:test'
import assert from 'node:assert'
import { UuidV7, SyncConflictResolver, SyncChange } from './sync_engine.js'

describe('TypeScript UuidV7 Generator & Validation', () => {
  it('generates valid RFC 9562 UUIDv7 strings', () => {
    const uuid = UuidV7.generate()
    assert.strictEqual(UuidV7.isValid(uuid), true)
    assert.strictEqual(uuid.length, 36)

    // Version nibble at index 14 must be '7'
    assert.strictEqual(uuid[14], '7')

    // Variant character at index 19 must be one of 8, 9, a, b
    assert.ok(['8', '9', 'a', 'b'].includes(uuid[19].toLowerCase()))
  })

  it('extracts Unix timestamp accurately', () => {
    const customMs = 1728000000123
    const uuid = UuidV7.generate(customMs)

    assert.strictEqual(UuidV7.isValid(uuid), true)
    const extracted = UuidV7.getTimestampMs(uuid)
    assert.strictEqual(extracted, customMs)
  })

  it('generates chronologically and lexicographically ordered IDs within same millisecond', () => {
    const fixedMs = 1728000000000
    const ids = Array.from({ length: 5 }, () => UuidV7.generate(fixedMs))

    for (let i = 0; i < ids.length - 1; i++) {
      assert.ok(ids[i].localeCompare(ids[i + 1]) < 0, `${ids[i]} should be less than ${ids[i + 1]}`)
    }
  })

  it('rejects invalid UUID formats', () => {
    assert.strictEqual(UuidV7.isValid(''), false)
    assert.strictEqual(UuidV7.isValid('not-a-uuid'), false)
    // Valid v4 uuid
    assert.strictEqual(UuidV7.isValid('c56a4180-65aa-42ec-a945-5fd21dec0538'), false)
  })
})

describe('TypeScript SyncConflictResolver: Deterministic Last-Write-Wins (LWW)', () => {
  it('higher record version strictly wins over lower version regardless of timestamp', () => {
    const local: SyncChange = {
      id: UuidV7.generate(1000),
      householdId: 'h1',
      entityType: 'meal_plan',
      entityId: 'p1',
      version: 1,
      payload: { dish: 'Dal Bhat' },
      createdAt: 1000
    }

    const remote: SyncChange = {
      id: UuidV7.generate(900), // earlier timestamp, but higher version
      householdId: 'h1',
      entityType: 'meal_plan',
      entityId: 'p1',
      version: 2,
      payload: { dish: 'Khichdi' },
      createdAt: 900
    }

    const res = SyncConflictResolver.resolve({ local, remote })
    assert.strictEqual(res.action, 'applyRemote')
    assert.strictEqual(res.winner?.id, remote.id)
    assert.strictEqual(res.effectivePayload?.dish, 'Khichdi')
  })

  it('newer timestamp wins when versions are identical', () => {
    const local: SyncChange = {
      id: UuidV7.generate(2000),
      householdId: 'h1',
      entityType: 'grocery_item',
      entityId: 'g1',
      version: 1,
      payload: { status: 'in_cart' },
      createdAt: 2000
    }

    const remote: SyncChange = {
      id: UuidV7.generate(1500),
      householdId: 'h1',
      entityType: 'grocery_item',
      entityId: 'g1',
      version: 1,
      payload: { status: 'pending' },
      createdAt: 1500
    }

    const res = SyncConflictResolver.resolve({ local, remote })
    assert.strictEqual(res.action, 'keepLocal')
    assert.strictEqual(res.winner?.id, local.id)
    assert.strictEqual(res.effectivePayload?.status, 'in_cart')
  })

  it('deterministic lexicographical tiebreaker when version and timestamp match', () => {
    const fixedMs = 3000
    const id1 = '018f0000-0000-7000-8000-000000000001'
    const id2 = '018f0000-0000-7000-8000-000000000002'

    const local: SyncChange = {
      id: id1,
      householdId: 'h1',
      entityType: 'batch',
      entityId: 'b1',
      version: 1,
      payload: { state: 'local' },
      createdAt: fixedMs
    }

    const remote: SyncChange = {
      id: id2,
      householdId: 'h1',
      entityType: 'batch',
      entityId: 'b1',
      version: 1,
      payload: { state: 'remote' },
      createdAt: fixedMs
    }

    const res = SyncConflictResolver.resolve({ local, remote })
    assert.strictEqual(res.action, 'applyRemote')
    assert.strictEqual(res.winner?.id, id2)
  })
})

describe('TypeScript SyncConflictResolver: Safety Gate for Allergies', () => {
  it('conflicting allergy changes require user prompt and provide safe union merge', () => {
    const local: SyncChange = {
      id: UuidV7.generate(2000),
      householdId: 'h1',
      entityType: 'member',
      entityId: 'm1',
      version: 2,
      payload: {
        name: 'Aayush',
        allergies: ['peanut', 'mustard']
      },
      createdAt: 2000
    }

    const remote: SyncChange = {
      id: UuidV7.generate(3000),
      householdId: 'h1',
      entityType: 'member',
      entityId: 'm1',
      version: 3,
      payload: {
        name: 'Aayush',
        allergies: ['dairy'] // dropped peanut and mustard
      },
      createdAt: 3000
    }

    const res = SyncConflictResolver.resolve({ local, remote })
    assert.strictEqual(res.action, 'promptUser')
    assert.strictEqual(res.conflict?.requiresPrompt, true)
    assert.strictEqual(res.conflict?.reason, 'ALLERGY_MODIFICATION_REQUIRES_CONFIRMATION')

    const allergies = res.effectivePayload?.allergies as string[]
    assert.ok(allergies.includes('dairy'))
    assert.ok(allergies.includes('mustard'))
    assert.ok(allergies.includes('peanut'))
  })

  it('identical allergy sets proceed with standard LWW', () => {
    const local: SyncChange = {
      id: UuidV7.generate(1000),
      householdId: 'h1',
      entityType: 'member',
      entityId: 'm1',
      version: 1,
      payload: {
        name: 'Sita',
        allergies: ['dairy']
      },
      createdAt: 1000
    }

    const remote: SyncChange = {
      id: UuidV7.generate(1500),
      householdId: 'h1',
      entityType: 'member',
      entityId: 'm1',
      version: 2,
      payload: {
        name: 'Sita Maya',
        allergies: ['dairy']
      },
      createdAt: 1500
    }

    const res = SyncConflictResolver.resolve({ local, remote })
    assert.strictEqual(res.action, 'applyRemote')
    assert.strictEqual(res.winner?.id, remote.id)
    assert.strictEqual(res.effectivePayload?.name, 'Sita Maya')
  })
})
