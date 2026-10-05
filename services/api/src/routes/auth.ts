import { Hono } from 'hono'
import { registerAccessToken } from '../middleware/household_auth.js'

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number; // 900 seconds (15 min)
}

export interface UserProfile {
  id: string;
  email?: string | null;
  name?: string | null;
  isAnonymous: boolean;
  householdId: string;
  createdAt: string;
}

export interface AuthResponse {
  user: UserProfile;
  tokens: AuthTokens;
  mergedFromGuest?: boolean;
}

// In-memory mock/store for Cloudflare Workers D1 migration
const usersStore = new Map<string, UserProfile>()
const magicLinksStore = new Map<string, { email: string; expiresAt: number; guestHouseholdId?: string }>()
const refreshTokensStore = new Map<string, { userId: string; expiresAt: number }>()
const householdEntitiesStore = new Map<string, Array<{ id: string; type: string; payload: Record<string, unknown> }>>()

export const authRouter = new Hono()

function generateToken(prefix: string): string {
  return `${prefix}_${Math.random().toString(36).substring(2)}${Date.now().toString(36)}`
}

function issueTokens(userId: string, householdId: string): AuthTokens {
  const accessToken = generateToken(`atk_${userId}`)
  const refreshToken = generateToken(`rtk_${userId}`)

  // 15-minute access token, 30-day refresh token
  refreshTokensStore.set(refreshToken, {
    userId,
    expiresAt: Date.now() + 30 * 24 * 60 * 60 * 1000
  })

  // Scope the access token to exactly one household so household-scoped routes can
  // authorize from the token instead of trusting a client-supplied householdId.
  registerAccessToken(accessToken, householdId)

  return {
    accessToken,
    refreshToken,
    expiresIn: 900 // 15 minutes
  }
}

// 1. Guest Authentication
authRouter.post('/v1/auth/guest', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as { deviceId?: string; regionPackId?: string }
  const deviceId = body.deviceId || generateToken('dev')

  const userId = `usr_guest_${deviceId.substring(0, 12)}`
  let user = usersStore.get(userId)

  if (!user) {
    user = {
      id: userId,
      email: null,
      name: 'Guest Cook',
      isAnonymous: true,
      householdId: `hh_${userId}`,
      createdAt: new Date().toISOString()
    }
    usersStore.set(userId, user)
  }

  const tokens = issueTokens(user.id, user.householdId)

  return c.json<AuthResponse>({
    user,
    tokens
  })
})

// 2. Email Magic Link - Send
authRouter.post('/v1/auth/magic-link/send', async (c) => {
  const body = (await c.req.json().catch(() => null)) as { email?: string; guestHouseholdId?: string } | null

  if (!body || !body.email || !body.email.includes('@')) {
    return c.json({ error: 'INVALID_EMAIL', message: 'Valid email required' }, 400)
  }

  const magicToken = generateToken('ml')
  magicLinksStore.set(magicToken, {
    email: body.email.toLowerCase().trim(),
    expiresAt: Date.now() + 15 * 60 * 1000, // 15 mins
    guestHouseholdId: body.guestHouseholdId
  })

  return c.json({
    success: true,
    message: 'Magic link dispatched',
    // In dev / test environment, return verification token
    debugVerificationToken: magicToken
  })
})

// 3. Email Magic Link - Verify
authRouter.post('/v1/auth/magic-link/verify', async (c) => {
  const body = (await c.req.json().catch(() => null)) as { token?: string } | null

  if (!body || !body.token) {
    return c.json({ error: 'INVALID_TOKEN', message: 'Verification token required' }, 400)
  }

  const record = magicLinksStore.get(body.token)
  if (!record || Date.now() > record.expiresAt) {
    return c.json({ error: 'EXPIRED_OR_INVALID', message: 'Token has expired or is invalid' }, 400)
  }

  magicLinksStore.delete(body.token)

  // Find or create user
  const email = record.email
  let user = Array.from(usersStore.values()).find((u) => u.email === email)
  let mergedFromGuest = false

  if (!user) {
    const userId = generateToken('usr')
    user = {
      id: userId,
      email,
      name: email.split('@')[0],
      isAnonymous: false,
      householdId: `hh_${userId}`,
      createdAt: new Date().toISOString()
    }
    usersStore.set(userId, user)
  } else {
    user.isAnonymous = false
  }

  // If there was an active guest household, perform non-destructive data merge
  if (record.guestHouseholdId && record.guestHouseholdId !== user.householdId) {
    const guestItems = householdEntitiesStore.get(record.guestHouseholdId) || []
    if (guestItems.length > 0) {
      const userItems = householdEntitiesStore.get(user.householdId) || []
      userItems.push(...guestItems)
      householdEntitiesStore.set(user.householdId, userItems)
      mergedFromGuest = true
    }
  }

  const tokens = issueTokens(user.id, user.householdId)

  return c.json<AuthResponse>({
    user,
    tokens,
    mergedFromGuest
  })
})

// 4. Google Sign-In
authRouter.post('/v1/auth/google', async (c) => {
  const body = (await c.req.json().catch(() => null)) as {
    idToken?: string;
    email?: string;
    name?: string;
    guestHouseholdId?: string;
  } | null

  if (!body || !body.email || !body.idToken) {
    return c.json({ error: 'INVALID_CREDENTIALS', message: 'Google idToken and email are required' }, 400)
  }

  const email = body.email.toLowerCase().trim()
  let user = Array.from(usersStore.values()).find((u) => u.email === email)
  let mergedFromGuest = false

  if (!user) {
    const userId = generateToken('usr_g')
    user = {
      id: userId,
      email,
      name: body.name || email.split('@')[0],
      isAnonymous: false,
      householdId: `hh_${userId}`,
      createdAt: new Date().toISOString()
    }
    usersStore.set(userId, user)
  } else {
    user.isAnonymous = false
    if (body.name) user.name = body.name
  }

  // Non-destructive data merge from guest household
  if (body.guestHouseholdId && body.guestHouseholdId !== user.householdId) {
    const guestItems = householdEntitiesStore.get(body.guestHouseholdId) || []
    if (guestItems.length > 0) {
      const userItems = householdEntitiesStore.get(user.householdId) || []
      userItems.push(...guestItems)
      householdEntitiesStore.set(user.householdId, userItems)
      mergedFromGuest = true
    }
  }

  const tokens = issueTokens(user.id, user.householdId)

  return c.json<AuthResponse>({
    user,
    tokens,
    mergedFromGuest
  })
})

// 5. Explicit Data Merge Endpoint
authRouter.post('/v1/auth/merge', async (c) => {
  const body = (await c.req.json().catch(() => null)) as {
    guestHouseholdId?: string;
    targetHouseholdId?: string;
  } | null

  if (!body || !body.guestHouseholdId || !body.targetHouseholdId) {
    return c.json({ error: 'INVALID_PARAMS', message: 'guestHouseholdId and targetHouseholdId required' }, 400)
  }

  const guestItems = householdEntitiesStore.get(body.guestHouseholdId) || []
  const targetItems = householdEntitiesStore.get(body.targetHouseholdId) || []

  // Merge items without duplication (by id)
  const existingIds = new Set(targetItems.map((i) => i.id))
  let migratedCount = 0

  for (const item of guestItems) {
    if (!existingIds.has(item.id)) {
      targetItems.push(item)
      migratedCount++
    }
  }

  householdEntitiesStore.set(body.targetHouseholdId, targetItems)

  return c.json({
    success: true,
    migratedCount,
    totalTargetItems: targetItems.length
  })
})

// 6. Token Rotation / Refresh
authRouter.post('/v1/auth/refresh', async (c) => {
  const body = (await c.req.json().catch(() => null)) as { refreshToken?: string } | null

  if (!body || !body.refreshToken) {
    return c.json({ error: 'MISSING_TOKEN', message: 'refreshToken is required' }, 400)
  }

  const record = refreshTokensStore.get(body.refreshToken)
  if (!record || Date.now() > record.expiresAt) {
    return c.json({ error: 'INVALID_REFRESH_TOKEN', message: 'Refresh token expired or invalid' }, 401)
  }

  // Invalidate old refresh token (rotating)
  refreshTokensStore.delete(body.refreshToken)

  const user = usersStore.get(record.userId)
  if (!user) {
    return c.json({ error: 'USER_NOT_FOUND', message: 'User does not exist' }, 404)
  }

  const tokens = issueTokens(user.id, user.householdId)

  return c.json({
    tokens,
    user
  })
})
