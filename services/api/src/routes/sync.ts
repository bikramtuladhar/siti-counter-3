import { Hono } from 'hono'

export interface ClientSyncChange {
  id: string
  entityType: 'household' | 'member' | 'recipe' | 'meal_plan' | 'grocery_item' | 'batch' | 'consumption'
  entityId: string
  version: number
  payload: Record<string, unknown>
  deleted?: boolean
}

export interface SyncRequest {
  householdId: string
  lastSyncToken?: string | null
  changes: ClientSyncChange[]
}

export interface SyncResponse {
  syncToken: string
  applied: number
  serverTime: string
  conflicts: Array<{ id: string; reason: string }>
  remoteChanges: ClientSyncChange[]
}

export const syncRouter = new Hono()

syncRouter.post('/v1/sync', async (c) => {
  const body = (await c.req.json().catch(() => null)) as SyncRequest | null

  if (!body || !body.householdId) {
    return c.json(
      {
        error: 'INVALID_REQUEST',
        message: 'householdId is required for synchronization'
      },
      400
    )
  }

  const { householdId, lastSyncToken, changes = [] } = body
  const serverNow = Date.now()
  const nextSyncToken = `st_${serverNow}`

  // In production, changes are persisted into D1 sync_entries
  // and remote changes newer than lastSyncToken are fetched.
  return c.json<SyncResponse>({
    syncToken: nextSyncToken,
    applied: changes.length,
    serverTime: new Date(serverNow).toISOString(),
    conflicts: [],
    remoteChanges: []
  })
})
