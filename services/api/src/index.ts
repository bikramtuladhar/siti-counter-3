import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'

const app = new Hono()

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

// Delta sync endpoint skeleton (Section 21.3)
app.post('/v1/sync', async (c) => {
  const body = await c.req.json().catch(() => ({}))
  return c.json({
    syncToken: `sync_${Date.now()}`,
    applied: 0,
    conflicts: [],
    changes: []
  })
})

export default app
