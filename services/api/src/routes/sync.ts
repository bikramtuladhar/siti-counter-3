import { Hono } from 'hono'
import { UuidV7, SyncChange, SyncConflictResolver } from '@siti-counter/kitchen-engine'
import { requireHousehold } from '../middleware/household_auth.js'

export interface ClientSyncChange {
  id: string
  entityType: 'household' | 'member' | 'recipe' | 'meal_plan' | 'grocery_item' | 'batch' | 'consumption' | 'pantry_item'
  entityId: string
  version: number
  payload: Record<string, unknown>
  deleted?: boolean
  createdAt?: number
}

export interface SyncRequest {
  householdId: string
  lastSyncToken?: string | null
  changes: ClientSyncChange[]
}

export interface SyncConflictInfo {
  id: string
  entityId: string
  entityType: string
  reason: string
  message: string
  requiresPrompt?: boolean
  safeMergedPayload?: Record<string, unknown>
}

export interface SyncResponse {
  syncToken: string
  applied: number
  serverTime: string
  conflicts: SyncConflictInfo[]
  remoteChanges: ClientSyncChange[]
}

// In-memory sync log storage for fast serverless runtime / tests
// In production D1, this is backed by the sync_entries table
const householdSyncStore = new Map<string, Map<string, ClientSyncChange & { serverTimestamp: number }>>()

export function resetSyncStore(): void {
  householdSyncStore.clear()
}

/** Returns the live entity map for a household, creating it on first write. */
export function getHouseholdEntities(householdId: string): Map<string, ClientSyncChange & { serverTimestamp: number }> {
  let entities = householdSyncStore.get(householdId)
  if (!entities) {
    entities = new Map()
    householdSyncStore.set(householdId, entities)
  }
  return entities
}

/** All non-deleted entities of one type for a household, newest server write last. */
export function getHouseholdEntitiesOfType(
  householdId: string,
  entityType: ClientSyncChange['entityType']
): Array<ClientSyncChange & { serverTimestamp: number }> {
  return Array.from(getHouseholdEntities(householdId).values())
    .filter((e) => e.entityType === entityType && !e.deleted)
    .sort((a, b) => a.serverTimestamp - b.serverTimestamp)
}

export const syncRouter = new Hono()

const MAX_PAYLOAD_BYTES = 30 * 1024 // 30 KB budget per Section 21.3

syncRouter.use('/v1/sync', requireHousehold())

syncRouter.post('/v1/sync', async (c) => {
  // Low-bandwidth payload size validation (<30KB)
  const contentLength = c.req.header('content-length')
  if (contentLength && parseInt(contentLength, 10) > MAX_PAYLOAD_BYTES) {
    return c.json(
      {
        error: 'PAYLOAD_TOO_LARGE',
        message: `Sync payload exceeds ${MAX_PAYLOAD_BYTES / 1024}KB low-bandwidth budget.`
      },
      413
    )
  }

  const rawBody = await c.req.text().catch(() => null)
  if (!rawBody || rawBody.length > MAX_PAYLOAD_BYTES) {
    return c.json(
      {
        error: 'PAYLOAD_TOO_LARGE',
        message: `Sync payload exceeds ${MAX_PAYLOAD_BYTES / 1024}KB low-bandwidth budget.`
      },
      413
    )
  }

  let body: SyncRequest
  try {
    body = JSON.parse(rawBody) as SyncRequest
  } catch {
    return c.json({ error: 'INVALID_JSON', message: 'Malformed JSON payload' }, 400)
  }

  if (!body || !body.householdId) {
    return c.json(
      {
        error: 'INVALID_REQUEST',
        message: 'householdId is required for synchronization'
      },
      400
    )
  }

  // The bearer token is the authority; a body claiming another household is rejected.
  const tokenHouseholdId = c.get('householdId' as never) as string
  if (body.householdId !== tokenHouseholdId) {
    return c.json(
      {
        error: 'FORBIDDEN',
        message: 'Token is not authorized for the requested household.'
      },
      403
    )
  }

  const { householdId, lastSyncToken, changes = [] } = body
  const serverNow = Date.now()
  const nextSyncToken = `st_${serverNow}`

  const entityMap = getHouseholdEntities(householdId)

  const appliedChanges: ClientSyncChange[] = []
  const conflicts: SyncConflictInfo[] = []
  const uploadedIds = new Set<string>()

  for (const clientChange of changes) {
    uploadedIds.add(clientChange.id)

    // Validate UUIDv7
    if (!UuidV7.isValid(clientChange.id)) {
      conflicts.push({
        id: clientChange.id,
        entityId: clientChange.entityId,
        entityType: clientChange.entityType,
        reason: 'INVALID_UUIDV7',
        message: `Change ID '${clientChange.id}' is not a valid RFC 9562 UUIDv7.`
      })
      continue
    }

    const entityKey = `${clientChange.entityType}:${clientChange.entityId}`
    const existing = entityMap.get(entityKey)

    if (existing) {
      // Convert to engine SyncChange models for resolution
      const localEngineChange: SyncChange = {
        id: existing.id,
        householdId,
        entityType: existing.entityType,
        entityId: existing.entityId,
        version: existing.version,
        payload: existing.payload,
        deleted: existing.deleted,
        createdAt: existing.createdAt ?? existing.serverTimestamp
      }

      const clientEngineChange: SyncChange = {
        id: clientChange.id,
        householdId,
        entityType: clientChange.entityType,
        entityId: clientChange.entityId,
        version: clientChange.version,
        payload: clientChange.payload,
        deleted: clientChange.deleted,
        createdAt: clientChange.createdAt ?? UuidV7.getTimestampMs(clientChange.id) ?? serverNow
      }

      const resolution = SyncConflictResolver.resolve({
        local: localEngineChange,
        remote: clientEngineChange
      })

      if (resolution.action === 'promptUser') {
        conflicts.push({
          id: clientChange.id,
          entityId: clientChange.entityId,
          entityType: clientChange.entityType,
          reason: resolution.conflict?.reason ?? 'SAFETY_CONFLICT',
          message: 'Allergy modification requires explicit user confirmation.',
          requiresPrompt: true,
          safeMergedPayload: resolution.effectivePayload
        })
        continue
      } else if (resolution.action === 'keepLocal') {
        conflicts.push({
          id: clientChange.id,
          entityId: clientChange.entityId,
          entityType: clientChange.entityType,
          reason: 'OUTDATED_VERSION',
          message: `Server already holds a newer or equal version (${existing.version}) of this entity.`
        })
        continue
      }
    }

    // Apply change to store
    entityMap.set(entityKey, {
      ...clientChange,
      createdAt: clientChange.createdAt ?? UuidV7.getTimestampMs(clientChange.id) ?? serverNow,
      serverTimestamp: serverNow
    })
    appliedChanges.push(clientChange)
  }

  // Parse lastSyncToken to find remote changes since then
  let lastSyncTime = 0
  if (lastSyncToken && lastSyncToken.startsWith('st_')) {
    lastSyncTime = parseInt(lastSyncToken.replace('st_', ''), 10) || 0
  }

  const remoteChanges: ClientSyncChange[] = []
  for (const stored of entityMap.values()) {
    if (stored.serverTimestamp > lastSyncTime && !uploadedIds.has(stored.id)) {
      remoteChanges.push({
        id: stored.id,
        entityType: stored.entityType,
        entityId: stored.entityId,
        version: stored.version,
        payload: stored.payload,
        deleted: stored.deleted,
        createdAt: stored.createdAt
      })
    }
  }

  return c.json<SyncResponse>({
    syncToken: nextSyncToken,
    applied: appliedChanges.length,
    serverTime: new Date(serverNow).toISOString(),
    conflicts,
    remoteChanges
  })
})
