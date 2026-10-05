import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { syncRouter } from './routes/sync.js'
import { authRouter } from './routes/auth.js'
import { coCookingRouter } from './routes/co_cooking.js'
import { aiRouter } from './routes/ai.js'
import { alexaRouter } from './routes/alexa.js'
import { checkoutRouter } from './routes/checkout.js'
import { marketRouter } from './routes/market.js'
import { communityRouter } from './routes/community.js'
import { telemetryRouter } from './routes/telemetry.js'
import { legalRouter } from './routes/legal.js'
import { commerceRouter } from './routes/commerce.js'
import { KalimatiService } from './market/kalimati_service.js'

export const app = new Hono()

app.use('*', logger())
app.use('*', cors())

// Health check endpoint
app.get('/health', (c) => {
  return c.json({
    status: 'healthy',
    service: 'siti-counter-api',
    version: '0.1.0',
    timestamp: new Date().toISOString(),
  })
})

// Authentication & Identity endpoints (/v1/auth/*)
app.route('/', authRouter)

// Delta sync endpoint (/v1/sync)
app.route('/', syncRouter)

// Realtime co-cooking synchronization endpoint (/v1/co-cooking/*)
app.route('/', coCookingRouter)

// AI Assistant endpoint (/v1/ai/assistant)
app.route('/', aiRouter)

// Smart Display Alexa Skill endpoint (/v1/alexa)
app.route('/', alexaRouter)

// Web Checkout & Entitlements endpoints (/v1/checkout/*, /v1/subscriptions/*, /v1/entitlements/*)
app.route('/', checkoutRouter)

// Regional Market Price Board endpoints (/v1/market/*)
app.route('/', marketRouter)

// Community contributions & moderation endpoints (/v1/community/*)
app.route('/', communityRouter)

// Telemetry & Launch Gate monitoring endpoints (/v1/telemetry/*)
app.route('/', telemetryRouter)

// Legal, Privacy & Compliance endpoints (/v1/legal/*)
app.route('/', legalRouter)

// Direct Partner Cart Checkout endpoints (/v1/commerce/*)
app.route('/', commerceRouter)

// 404 fallback
app.notFound((c) => {
  return c.json({ error: 'NOT_FOUND', message: 'Route not found' }, 404)
})

// Export Durable Object class for Cloudflare Workers runtime
export { CookingSessionDurableObject } from './co_cooking/session_durable_object.js'
export * from './co_cooking/types.js'

// Export Cloudflare Worker handlers (HTTP Fetch & Scheduled Cron for Kalimati Daily Ingestion)
export default {
  fetch: app.fetch,
  async scheduled(event: any, env: any, ctx: any) {
    if (ctx && typeof ctx.waitUntil === 'function') {
      ctx.waitUntil(KalimatiService.ingestDailyPrices())
    } else {
      await KalimatiService.ingestDailyPrices()
    }
  }
}

