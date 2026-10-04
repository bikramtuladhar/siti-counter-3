import { Hono } from 'hono'
import { CookingSessionDurableObject } from '../co_cooking/session_durable_object.js'

export interface CoCookingEnv {
  COOKING_SESSION?: DurableObjectNamespace
  [key: string]: unknown
}

export const coCookingRouter = new Hono<{ Bindings: CoCookingEnv }>()

// Fallback in-memory map of Durable Objects for test/dev environment without Cloudflare runtime
const localSessions = new Map<string, CookingSessionDurableObject>()

function getLocalDurableObject(sessionId: string): CookingSessionDurableObject {
  let doInstance = localSessions.get(sessionId)
  if (!doInstance) {
    const memoryStorage = new Map<string, unknown>()
    const mockStorage = {
      get: async <T>(key: string) => memoryStorage.get(key) as T | undefined,
      put: async <T>(key: string, val: T) => {
        memoryStorage.set(key, val)
      },
      delete: async (key: string) => memoryStorage.delete(key),
    }

    const mockState = {
      storage: mockStorage,
      acceptWebSocket: (ws: WebSocket) => {},
      getWebSockets: () => [],
    } as unknown as DurableObjectState

    doInstance = new CookingSessionDurableObject(mockState, {})
    localSessions.set(sessionId, doInstance)
  }
  return doInstance
}

/**
 * WebSocket endpoint for live co-cooking crew synchronization
 * Connect via: ws://.../v1/co-cooking/:sessionId/ws
 */
coCookingRouter.get('/v1/co-cooking/:sessionId/ws', async (c) => {
  const sessionId = c.req.param('sessionId')
  if (!sessionId) {
    return c.text('Missing sessionId', 400)
  }

  // If running inside Cloudflare Workers with COOKING_SESSION binding:
  if (c.env?.COOKING_SESSION) {
    const id = c.env.COOKING_SESSION.idFromName(sessionId)
    const sessionDO = c.env.COOKING_SESSION.get(id)
    return sessionDO.fetch(c.req.raw)
  }

  // Local / test fallback
  const sessionDO = getLocalDurableObject(sessionId)
  return sessionDO.fetch(c.req.raw)
})

/**
 * HTTP REST fallback endpoint to inspect session snapshot
 */
coCookingRouter.get('/v1/co-cooking/:sessionId/state', async (c) => {
  const sessionId = c.req.param('sessionId')
  if (!sessionId) {
    return c.json({ error: 'MISSING_SESSION_ID' }, 400)
  }

  if (c.env?.COOKING_SESSION) {
    const id = c.env.COOKING_SESSION.idFromName(sessionId)
    const sessionDO = c.env.COOKING_SESSION.get(id)
    return sessionDO.fetch(c.req.raw)
  }

  const sessionDO = getLocalDurableObject(sessionId)
  return sessionDO.fetch(new Request(`https://api.siticounter.com/v1/co-cooking/${sessionId}/state`))
})
