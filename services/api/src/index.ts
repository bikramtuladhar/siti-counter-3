import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { syncRouter } from './routes/sync.js'
import { authRouter } from './routes/auth.js'
import { coCookingRouter } from './routes/co_cooking.js'

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

// 404 fallback
app.notFound((c) => {
  return c.json({ error: 'NOT_FOUND', message: 'Route not found' }, 404)
})

// Export Durable Object class for Cloudflare Workers runtime
export { CookingSessionDurableObject } from './co_cooking/session_durable_object.js'
export * from './co_cooking/types.js'

export default app
