import type { MiddlewareHandler } from 'hono'

/** Cloudflare bindings available to the Worker. */
export interface WorkerEnv {
  DB?: D1Database
  COOKING_SESSION?: DurableObjectNamespace
}

/**
 * Returns the D1 binding when one is configured.
 *
 * The sync/display stores currently run against an in-memory Map so the test suite works with
 * no D1 shim. Callers use this to detect whether durable storage is available and fall back
 * cleanly when it is not, rather than assuming either one.
 */
export function getD1(env: WorkerEnv | undefined): D1Database | null {
  return env?.DB ?? null
}

/**
 * Minimal bearer-token registry for household-scoped routes.
 *
 * Tokens are issued by `/v1/auth/*` (guest, magic link, Google, refresh) and map to exactly
 * one household. Routes guarded by `requireHousehold` therefore never trust a
 * caller-supplied `householdId`: the token is the authority, and each handler compares any
 * `householdId` in its own payload against `c.get('householdId')`, rejecting a mismatch.
 * That is what stops one household reading another's meal plan or grocery list.
 */
const tokenToHousehold = new Map<string, string>()

/** Registers a token for a household so auth flows can hand it to the client. */
export function registerAccessToken(token: string, householdId: string): void {
  tokenToHousehold.set(token, householdId)
}

export function revokeAccessToken(token: string): void {
  tokenToHousehold.delete(token)
}

/** Resolves the household a token is scoped to, or null when the token is unknown. */
export function resolveTokenHousehold(token: string | undefined | null): string | null {
  if (!token) return null
  return tokenToHousehold.get(token) ?? null
}

/** Test helper: drops every registered token. */
export function resetTokenStore(): void {
  tokenToHousehold.clear()
}

/**
 * Requires a valid bearer token and exposes the caller's household as `c.get('householdId')`.
 *
 * A `householdId` query parameter that disagrees with the token is rejected with 403. Handlers
 * that carry a householdId in the request body do the same check themselves, since the body has
 * already been consumed by the time this middleware could read it.
 */
export function requireHousehold(): MiddlewareHandler {
  return async (c, next) => {
    const authHeader = c.req.header('Authorization')
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7).trim() : null

    const householdId = resolveTokenHousehold(token)
    if (!householdId) {
      return c.json(
        {
          error: 'UNAUTHORIZED',
          message: 'A valid bearer access token is required for this endpoint.',
        },
        401,
      )
    }

    c.set('householdId' as never, householdId as never)

    const requested = c.req.query('householdId')
    if (requested && requested !== householdId) {
      return c.json(
        {
          error: 'FORBIDDEN',
          message: 'Token is not authorized for the requested household.',
        },
        403,
      )
    }

    await next()
  }
}