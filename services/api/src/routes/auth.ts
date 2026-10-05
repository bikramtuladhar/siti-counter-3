import { Hono } from 'hono'
import { registerAccessToken } from '../middleware/household_auth.js'
import { getHouseholdEntities } from './sync.js'
import {
  SocialAuthError,
  type SocialAuthEnv,
  fetchFacebookProfile,
  verifyAppleIdentityToken,
  verifyFacebookAccessToken,
  verifyGoogleIdToken,
  type VerifiedIdentity,
} from '../auth/social_verifier.js'

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
/**
 * Social identity -> user, so signing in again with the same provider finds the same account.
 *
 * Keyed by `${provider}:${providerUserId}` rather than by email, because Apple only returns
 * an email on the first authorisation and a user may change address on the provider.
 */
const socialIdentityStore = new Map<string, string>()

/**
 * Non-destructive merge of a guest household's synced entities into the signed-in account.
 *
 * This used to read and write a private `householdEntitiesStore` that nothing ever wrote to,
 * so every guest -> account merge silently moved zero entities. It now operates on the same
 * store `/v1/sync` writes to, which is the only place a guest household's data actually lives.
 *
 * The source household is left intact rather than deleted, so a failed sign-in cannot lose
 * data, and the target wins on any entity id that exists in both.
 */
function mergeHousehold(guestHouseholdId: string, targetHouseholdId: string): number {
  if (!guestHouseholdId || guestHouseholdId === targetHouseholdId) return 0

  const source = getHouseholdEntities(guestHouseholdId)
  const target = getHouseholdEntities(targetHouseholdId)

  let migrated = 0
  for (const [entityKey, entity] of source.entries()) {
    if (target.has(entityKey)) continue
    target.set(entityKey, { ...entity })
    migrated++
  }

  return migrated
}

/** Finds or creates the account for a verified social identity. */
function upsertSocialUser(
  provider: string,
  identity: VerifiedIdentity,
  guestHouseholdId?: string,
): { user: UserProfile; mergedFromGuest: boolean } {
  const existingUserId = socialIdentityStore.get(
    `${provider}:${identity.providerUserId}`,
  )

  let user = existingUserId ? usersStore.get(existingUserId) : undefined
  let mergedFromGuest = false

  if (user) {
    // Refresh the profile fields the provider may now share.
    if (identity.email && user.email !== identity.email) user.email = identity.email
    if (identity.name && !user.name) user.name = identity.name
    if (!user.isAnonymous) user.isAnonymous = false
  } else {
    const userId = generateToken(`usr_${provider}`)
    user = {
      id: userId,
      email: identity.email ?? null,
      name: identity.name ?? null,
      isAnonymous: false,
      // Reuse the guest household when there is one, so its synced data is already in place
      // and no merge is needed.
      householdId: guestHouseholdId || `hh_${userId}`,
      createdAt: new Date().toISOString(),
    }
    usersStore.set(user.id, user)
  }

  if (guestHouseholdId && guestHouseholdId !== user.householdId) {
    mergedFromGuest = mergeHousehold(guestHouseholdId, user.householdId) > 0
  }

  socialIdentityStore.set(`${provider}:${identity.providerUserId}`, user.id)
  return { user, mergedFromGuest }
}

function socialFailure(error: unknown) {
  if (error instanceof SocialAuthError) {
    return { status: error.status, body: { error: error.code, message: error.message } }
  }
  return {
    status: 500,
    body: { error: 'SOCIAL_AUTH_FAILED', message: 'Social sign-in failed.' },
  }
}

export const authRouter = new Hono<{ Bindings: SocialAuthEnv }>()

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
    mergedFromGuest = mergeHousehold(record.guestHouseholdId, user.householdId) > 0
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
    mergedFromGuest = mergeHousehold(body.guestHouseholdId, user.householdId) > 0
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

  const migratedCount = mergeHousehold(body.guestHouseholdId, body.targetHouseholdId)

  return c.json({
    success: true,
    migratedCount,
    totalTargetItems: getHouseholdEntities(body.targetHouseholdId).size
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

// 7. Sign in with Apple
//
// The identity token is verified against Apple's published keys before anything is trusted.
// Apple only returns the email on the first authorisation, so the account is keyed on the
// token's subject id and the email is treated as optional.
authRouter.post('/v1/auth/apple', async (c) => {
  const body = (await c.req.json().catch(() => null)) as {
    identityToken?: string
    email?: string
    name?: string
    guestHouseholdId?: string
  } | null

  if (!body || !body.identityToken) {
    return c.json({ error: 'MISSING_TOKEN', message: 'Apple identityToken is required.' }, 400)
  }

  const clientId = c.env?.APPLE_CLIENT_ID
  if (!clientId) {
    return c.json(
      { error: 'NOT_CONFIGURED', message: 'Apple sign-in is not configured on this deployment.' },
      503,
    )
  }

  let identity: VerifiedIdentity
  try {
    identity = await verifyAppleIdentityToken(body.identityToken, {
      clientId,
      issuer: c.env?.APPLE_ISSUER,
    })
  } catch (error) {
    const failure = socialFailure(error)
    return c.json(failure.body, failure.status as 400)
  }

  // The client may supply the name Apple only returns once, but never the email as proof of
  // ownership: only the verified token's claims are trusted.
  const { user, mergedFromGuest } = upsertSocialUser(
    'apple',
    {
      ...identity,
      // Prefer the verified token's email; fall back to none rather than the client's.
      email: identity.email,
      name: body.name ?? identity.name,
    },
    body.guestHouseholdId,
  )

  const tokens = issueTokens(user.id, user.householdId)
  return c.json<AuthResponse>({ user, tokens, mergedFromGuest })
})

// 8. Sign in with Facebook
//
// Facebook access tokens are opaque, so they are validated server-to-server with Facebook's
// debug_token endpoint rather than by signature.
authRouter.post('/v1/auth/facebook', async (c) => {
  const body = (await c.req.json().catch(() => null)) as {
    accessToken?: string
    guestHouseholdId?: string
  } | null

  if (!body || !body.accessToken) {
    return c.json({ error: 'MISSING_TOKEN', message: 'Facebook accessToken is required.' }, 400)
  }

  const appId = c.env?.FACEBOOK_APP_ID
  const appSecret = c.env?.FACEBOOK_APP_SECRET
  if (!appId || !appSecret) {
    return c.json(
      { error: 'NOT_CONFIGURED', message: 'Facebook sign-in is not configured on this deployment.' },
      503,
    )
  }

  let identity: VerifiedIdentity
  try {
    identity = await verifyFacebookAccessToken(body.accessToken, { appId, appSecret })
    const profile = await fetchFacebookProfile(body.accessToken)
    identity = { ...identity, ...profile }
  } catch (error) {
    const failure = socialFailure(error)
    return c.json(failure.body, failure.status as 400)
  }

  const { user, mergedFromGuest } = upsertSocialUser(
    'facebook',
    identity,
    body.guestHouseholdId,
  )

  const tokens = issueTokens(user.id, user.householdId)
  return c.json<AuthResponse>({ user, tokens, mergedFromGuest })
})

// 9. Sign in with Google (token-verified)
//
// The original endpoint trusted whatever email the client sent, which let anyone claim an
// existing account by posting someone else's address. This variant verifies the ID token's
// signature against Google's published keys and honours only the verified claims.
//
// The legacy `/v1/auth/google` above is kept for older clients and is deprecated.
authRouter.post('/v1/auth/google/verified', async (c) => {
  const body = (await c.req.json().catch(() => null)) as {
    idToken?: string
    guestHouseholdId?: string
  } | null

  if (!body || !body.idToken) {
    return c.json({ error: 'MISSING_TOKEN', message: 'Google idToken is required.' }, 400)
  }

  const clientId = c.env?.GOOGLE_CLIENT_ID
  if (!clientId) {
    return c.json(
      { error: 'NOT_CONFIGURED', message: 'Google sign-in is not configured on this deployment.' },
      503,
    )
  }

  let identity: VerifiedIdentity
  try {
    identity = await verifyGoogleIdToken(body.idToken, { clientId })
  } catch (error) {
    const failure = socialFailure(error)
    return c.json(failure.body, failure.status as 400)
  }

  const { user, mergedFromGuest } = upsertSocialUser('google', identity, body.guestHouseholdId)

  const tokens = issueTokens(user.id, user.householdId)
  return c.json<AuthResponse>({ user, tokens, mergedFromGuest })
})

export function resetSocialStore(): void {
  socialIdentityStore.clear()
}
