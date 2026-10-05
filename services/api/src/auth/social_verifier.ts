import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose'

/**
 * Verification of third-party identity tokens (Google, Apple) and Facebook access tokens.
 *
 * Sign-in endpoints must never trust a client-supplied token: without signature
 * verification anyone could POST `{"idToken": "<forged>"}` and take over an arbitrary
 * account. Each verifier below checks the provider's signature, issuer and audience against
 * the provider's published keys.
 *
 * Facebook differs from Google and Apple: its access tokens are opaque, so they are
 * validated by asking Facebook whether the token is live and belongs to our app.
 */

/** The identity a provider asserts, once its token has been verified. */
export interface VerifiedIdentity {
  /** Stable provider-scoped subject id. */
  providerUserId: string
  email?: string
  /** Present only on the first authorisation for Apple, which is email-private. */
  emailVerified?: boolean
  name?: string
}

export interface AppleConfig {
  /** Bundle id of the iOS app; Apple sets this as the token audience. */
  clientId: string
  /** Optional App Store Connect issuer, when the app also offers Sign in with Apple on macOS. */
  issuer?: string
}

export interface GoogleConfig {
  /** OAuth client id (web) or the Android/iOS client id. */
  clientId: string
}

export interface FacebookConfig {
  /** Facebook app id. */
  appId: string
  /** App secret, used to prove the caller owns the app when calling debug_token. */
  appSecret: string
}

/**
 * Bindings the Worker expects for social sign-in.
 *
 * Each is optional so a deployment can enable only the providers it has configured; the
 * corresponding route answers 503 NOT_CONFIGURED when its binding is absent, instead of
 * silently accepting unverified tokens.
 */
export interface SocialAuthEnv {
  APPLE_CLIENT_ID?: string
  APPLE_ISSUER?: string
  GOOGLE_CLIENT_ID?: string
  FACEBOOK_APP_ID?: string
  FACEBOOK_APP_SECRET?: string
}

export class SocialAuthError extends Error {
  readonly code: string
  readonly status: number

  constructor(code: string, message: string, status = 401) {
    super(message)
    this.name = 'SocialAuthError'
    this.code = code
    this.status = status
  }
}

const APPLE_JWKS = createRemoteJWKSet(
  new URL('https://appleid.apple.com/auth/keys'),
  { cooldownDuration: 60_000 },
)

const GOOGLE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/oauth2/v3/certs'),
  { cooldownDuration: 60_000 },
)

/**
 * Verifies a Google ID token.
 *
 * Checks the RS256 signature against Google's published keys, that the issuer is Google,
 * and that the audience is our client id. The email is only trusted when `email_verified`
 * is true, otherwise a user could claim someone else's address.
 */
export async function verifyGoogleIdToken(
  idToken: string,
  config: GoogleConfig,
): Promise<VerifiedIdentity> {
  let payload: JWTPayload
  try {
    const result = await jwtVerify(idToken, GOOGLE_JWKS, {
      issuer: ['https://accounts.google.com', 'accounts.google.com'],
      audience: config.clientId,
    })
    payload = result.payload
  } catch {
    throw new SocialAuthError(
      'INVALID_ID_TOKEN',
      'Google ID token could not be verified.',
    )
  }

  if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
    throw new SocialAuthError('INVALID_ID_TOKEN', 'Google ID token has no subject.')
  }

  if (payload.email !== undefined && payload.email_verified !== true) {
    throw new SocialAuthError(
      'UNVERIFIED_EMAIL',
      'Google account email is not verified.',
      403,
    )
  }

  return {
    providerUserId: payload.sub,
    email: typeof payload.email === 'string' ? payload.email : undefined,
    emailVerified: payload.email_verified === true,
    name: typeof payload.name === 'string' ? payload.name : undefined,
  }
}

/**
 * Verifies an Apple identity token.
 *
 * Apple signs with ES256 and only sends the email on the very first authorisation, so
 * callers must cope with a missing email and fall back to the subject id.
 */
export async function verifyAppleIdentityToken(
  identityToken: string,
  config: AppleConfig,
): Promise<VerifiedIdentity> {
  const issuers = ['https://appleid.apple.com']
  if (config.issuer) issuers.push(config.issuer)

  let payload: JWTPayload
  try {
    const result = await jwtVerify(identityToken, APPLE_JWKS, {
      issuer: issuers,
      audience: config.clientId,
    })
    payload = result.payload
  } catch {
    throw new SocialAuthError(
      'INVALID_IDENTITY_TOKEN',
      'Apple identity token could not be verified.',
    )
  }

  if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
    throw new SocialAuthError(
      'INVALID_IDENTITY_TOKEN',
      'Apple identity token has no subject.',
    )
  }

  return {
    providerUserId: payload.sub,
    email: typeof payload.email === 'string' ? payload.email : undefined,
    // Apple omits email_verified on later sign-ins, so absence is not a failure here.
    emailVerified: payload.email_verified === true || payload.email !== undefined,
  }
}

/**
 * Verifies a Facebook access token by asking Facebook whether it is valid.
 *
 * Facebook access tokens are opaque strings rather than signed JWTs, so the only sound check
 * is a server-to-server `debug_token` call. `is_valid` confirms the token is live, and the
 * app id check confirms it was issued to *this* app rather than another one using the same
 * token.
 */
export async function verifyFacebookAccessToken(
  accessToken: string,
  config: FacebookConfig,
): Promise<VerifiedIdentity> {
  const url = new URL('https://graph.facebook.com/debug_token')
  url.searchParams.set('input_token', accessToken)
  url.searchParams.set('access_token', `${config.appId}|${config.appSecret}`)

  let body: { data?: { is_valid?: boolean; user_id?: string; app_id?: string; error?: { message?: string } } }
  try {
    const response = await fetch(url.toString())
    if (!response.ok) {
      throw new SocialAuthError(
        'PROVIDER_UNAVAILABLE',
        'Facebook token verification is unavailable.',
        503,
      )
    }
    body = (await response.json()) as typeof body
  } catch (error) {
    if (error instanceof SocialAuthError) throw error
    throw new SocialAuthError(
      'PROVIDER_UNAVAILABLE',
      'Facebook token verification is unavailable.',
      503,
    )
  }

  const data = body?.data
  if (!data?.is_valid) {
    throw new SocialAuthError(
      'INVALID_ACCESS_TOKEN',
      data?.error?.message ?? 'Facebook access token is not valid.',
    )
  }

  if (data.app_id !== undefined && data.app_id !== config.appId) {
    throw new SocialAuthError(
      'WRONG_APP',
      'Facebook token was issued to a different app.',
      403,
    )
  }

  if (typeof data.user_id !== 'string' || data.user_id.length === 0) {
    throw new SocialAuthError('INVALID_ACCESS_TOKEN', 'Facebook token has no user id.')
  }

  return { providerUserId: data.user_id }
}

/**
 * Fetches the profile for a verified Facebook user.
 *
 * A separate call because the access token has to be presented again, and because the email
 * is only granted with the `email` permission. A missing email is not an error: the account
 * is still linked by its Facebook user id.
 */
export async function fetchFacebookProfile(
  accessToken: string,
): Promise<{ email?: string; name?: string }> {
  const url = new URL('https://graph.facebook.com/me')
  url.searchParams.set(
    'fields',
    'id,name,email',
  )
  url.searchParams.set('access_token', accessToken)

  try {
    const response = await fetch(url.toString())
    if (!response.ok) return {}
    const body = (await response.json()) as {
      email?: string
      name?: string
    }
    return {
      email: typeof body.email === 'string' ? body.email : undefined,
      name: typeof body.name === 'string' ? body.name : undefined,
    }
  } catch {
    return {}
  }
}