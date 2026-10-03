import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { syncRouter } from './routes/sync.js'
import { authRouter } from './routes/auth.js'

export const app = new Hono()

app.use('*', logger())
app.use('*', cors())

// Health check endpoint
app.get('/health', (c) => {
  return c.json({
    status: 'healthy',
    service: 'siti-counter-api',
    version: '0.1.0',
    timestamp: new Date().toISOString()
  })
})

// Authentication & Identity endpoints (/v1/auth/*)
app.route('/', authRouter)

// Delta sync endpoint (/v1/sync)
app.route('/', syncRouter)

// 404 fallback
app.notFound((c) => {
  return c.json({ error: 'NOT_FOUND', message: 'Route not found' }, 404)
})

export default app
