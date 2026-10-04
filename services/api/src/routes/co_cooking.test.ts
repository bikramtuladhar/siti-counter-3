import test from 'node:test'
import assert from 'node:assert/strict'
import { app } from '../index.js'
import { CookingSessionDurableObject } from '../co_cooking/session_durable_object.js'
import { ServerMessage } from '../co_cooking/types.js'

class MockWebSocket {
  messages: string[] = []
  readyState = 1 // OPEN
  attachment: unknown = null
  otherSide?: MockWebSocket

  send(data: string) {
    if (this.otherSide) {
      this.otherSide.messages.push(data)
    } else {
      this.messages.push(data)
    }
  }

  close() {
    this.readyState = 3 // CLOSED
  }

  serializeAttachment(data: unknown) {
    this.attachment = data
  }

  deserializeAttachment(): unknown {
    return this.attachment
  }
}

function createMockDurableObject() {
  const memory = new Map<string, unknown>()
  const sockets: WebSocket[] = []

  const mockStorage = {
    get: async <T>(key: string) => memory.get(key) as T | undefined,
    put: async <T>(key: string, val: T) => {
      memory.set(key, val)
    },
    delete: async (key: string) => memory.delete(key),
  }

  const mockState = {
    storage: mockStorage,
    acceptWebSocket: (ws: WebSocket) => {
      sockets.push(ws)
    },
    getWebSockets: () => sockets,
  } as unknown as DurableObjectState

  const doInstance = new CookingSessionDurableObject(mockState, {})
  return { doInstance, sockets, memory }
}

test('GET /v1/co-cooking/:sessionId/state returns session state snapshot', async () => {
  const res = await app.request('/v1/co-cooking/session-dal-bhat/state')
  assert.equal(res.status, 200)

  const body = (await res.json()) as { sessionId: string; currentWhistles: number; presence: unknown[] }
  assert.equal(body.sessionId, 'session-dal-bhat')
  assert.equal(body.currentWhistles, 0)
  assert.equal(body.presence.length, 0)
})

test('Co-Cooking Durable Object: Lead cook joins and initializes recipe session', async () => {
  const { doInstance } = createMockDurableObject()
  const serverWs = new MockWebSocket()

  // Lead cook joins
  await doInstance.webSocketMessage(
    serverWs as unknown as WebSocket,
    JSON.stringify({
      type: 'JOIN',
      memberId: 'lead-bikram',
      memberName: 'Bikram',
      role: 'leadCook',
      recipeId: 'masoor-dal',
      recipeTitle: 'Masoor Dal',
      targetWhistles: 3,
      totalSteps: 4,
    })
  )

  assert.equal(serverWs.messages.length, 1)
  const syncMsg = JSON.parse(serverWs.messages[0]) as ServerMessage
  assert.equal(syncMsg.type, 'SESSION_SYNC')
  if (syncMsg.type === 'SESSION_SYNC') {
    assert.equal(syncMsg.state.recipeId, 'masoor-dal')
    assert.equal(syncMsg.state.targetWhistles, 3)
    assert.equal(syncMsg.state.presence.length, 1)
    assert.equal(syncMsg.state.presence[0].memberId, 'lead-bikram')
    assert.equal(syncMsg.state.presence[0].role, 'leadCook')
    assert.equal(syncMsg.state.presence[0].isConnected, true)
  }
})

test('Co-Cooking Durable Object: Co-cook joins, presence broadcasted to crew', async () => {
  const { doInstance } = createMockDurableObject()
  const leadWs = new MockWebSocket()
  const coCookWs = new MockWebSocket()

  // 1. Lead cook joins
  await doInstance.webSocketMessage(
    leadWs as unknown as WebSocket,
    JSON.stringify({
      type: 'JOIN',
      memberId: 'lead-bikram',
      memberName: 'Bikram',
      role: 'leadCook',
      recipeId: 'masoor-dal',
      recipeTitle: 'Masoor Dal',
      targetWhistles: 3,
    })
  )
  leadWs.messages = [] // Clear initial sync

  // 2. Co-cook joins
  await doInstance.webSocketMessage(
    coCookWs as unknown as WebSocket,
    JSON.stringify({
      type: 'JOIN',
      memberId: 'co-srijana',
      memberName: 'Srijana',
      role: 'coCook',
    })
  )

  // Co-cook should receive SESSION_SYNC with state
  assert.equal(coCookWs.messages.length, 1)
  const coCookSync = JSON.parse(coCookWs.messages[0]) as ServerMessage
  assert.equal(coCookSync.type, 'SESSION_SYNC')
  if (coCookSync.type === 'SESSION_SYNC') {
    assert.equal(coCookSync.state.presence.length, 2)
  }

  // Lead cook should receive PRESENCE_CHANGE broadcast indicating Srijana joined
  assert.equal(leadWs.messages.length, 1)
  const leadPresenceMsg = JSON.parse(leadWs.messages[0]) as ServerMessage
  assert.equal(leadPresenceMsg.type, 'PRESENCE_CHANGE')
  if (leadPresenceMsg.type === 'PRESENCE_CHANGE') {
    assert.equal(leadPresenceMsg.joined?.memberId, 'co-srijana')
    assert.equal(leadPresenceMsg.presence.length, 2)
  }
})

test('Co-Cooking Durable Object: Synchronized whistle counts and shared alarm trigger', async () => {
  const { doInstance } = createMockDurableObject()
  const leadWs = new MockWebSocket()
  const coCookWs = new MockWebSocket()

  await doInstance.webSocketMessage(
    leadWs as unknown as WebSocket,
    JSON.stringify({
      type: 'JOIN',
      memberId: 'lead-bikram',
      memberName: 'Bikram',
      role: 'leadCook',
      targetWhistles: 2,
      recipeTitle: 'Masoor Dal',
    })
  )

  await doInstance.webSocketMessage(
    coCookWs as unknown as WebSocket,
    JSON.stringify({
      type: 'JOIN',
      memberId: 'co-srijana',
      memberName: 'Srijana',
      role: 'coCook',
    })
  )

  leadWs.messages = []
  coCookWs.messages = []

  // Whistle 1 detected (1/2) -> Broadcast to crew
  await doInstance.webSocketMessage(
    leadWs as unknown as WebSocket,
    JSON.stringify({
      type: 'WHISTLE_UPDATE',
      whistles: 1,
      target: 2,
    })
  )

  assert.equal(coCookWs.messages.length, 1)
  const w1 = JSON.parse(coCookWs.messages[0]) as ServerMessage
  assert.equal(w1.type, 'WHISTLE_BROADCAST')
  if (w1.type === 'WHISTLE_BROADCAST') {
    assert.equal(w1.currentWhistles, 1)
    assert.equal(w1.isTargetReached, false)
  }

  leadWs.messages = []
  coCookWs.messages = []

  // Whistle 2 detected (2/2) -> Target reached! Triggers SHARED_ALARM across all crew phones
  await doInstance.webSocketMessage(
    leadWs as unknown as WebSocket,
    JSON.stringify({
      type: 'WHISTLE_UPDATE',
      whistles: 2,
      target: 2,
    })
  )

  // Both lead and coCook should receive WHISTLE_BROADCAST and SHARED_ALARM
  const coCookMsgs = coCookWs.messages.map((m) => JSON.parse(m) as ServerMessage)
  assert.ok(coCookMsgs.some((m) => m.type === 'WHISTLE_BROADCAST' && m.isTargetReached))
  assert.ok(coCookMsgs.some((m) => m.type === 'SHARED_ALARM' && m.targetWhistles === 2))

  // State should record alarm as active
  assert.equal(doInstance.sessionState?.isAlarmActive, true)

  // Co-cook in the dining room dismisses the alarm on their phone
  leadWs.messages = []
  coCookWs.messages = []

  await doInstance.webSocketMessage(
    coCookWs as unknown as WebSocket,
    JSON.stringify({
      type: 'ALARM_DISMISS',
      memberId: 'co-srijana',
      memberName: 'Srijana',
    })
  )

  assert.equal(doInstance.sessionState?.isAlarmActive, false)
  assert.equal(doInstance.sessionState?.alarmDismissedBy?.memberName, 'Srijana')

  // Lead cook receives ALARM_DISMISSED broadcast
  assert.equal(leadWs.messages.length, 1)
  const dismissMsg = JSON.parse(leadWs.messages[0]) as ServerMessage
  assert.equal(dismissMsg.type, 'ALARM_DISMISSED')
  if (dismissMsg.type === 'ALARM_DISMISSED') {
    assert.equal(dismissMsg.memberName, 'Srijana')
  }
})

test('Co-Cooking Durable Object: Synchronized step completions and shared timers', async () => {
  const { doInstance } = createMockDurableObject()
  const leadWs = new MockWebSocket()
  const coCookWs = new MockWebSocket()

  await doInstance.webSocketMessage(
    leadWs as unknown as WebSocket,
    JSON.stringify({
      type: 'JOIN',
      memberId: 'lead-bikram',
      memberName: 'Bikram',
      role: 'leadCook',
    })
  )

  await doInstance.webSocketMessage(
    coCookWs as unknown as WebSocket,
    JSON.stringify({
      type: 'JOIN',
      memberId: 'co-srijana',
      memberName: 'Srijana',
      role: 'coCook',
    })
  )

  leadWs.messages = []
  coCookWs.messages = []

  // Step completed
  await doInstance.webSocketMessage(
    leadWs as unknown as WebSocket,
    JSON.stringify({
      type: 'STEP_UPDATE',
      stepIndex: 2,
    })
  )

  assert.equal(coCookWs.messages.length, 1)
  const stepMsg = JSON.parse(coCookWs.messages[0]) as ServerMessage
  assert.equal(stepMsg.type, 'STEP_CHANGED')
  if (stepMsg.type === 'STEP_CHANGED') {
    assert.equal(stepMsg.stepIndex, 2)
  }

  // Timer started
  leadWs.messages = []
  coCookWs.messages = []

  await doInstance.webSocketMessage(
    coCookWs as unknown as WebSocket,
    JSON.stringify({
      type: 'TIMER_START',
      timerId: 'simmer-timer',
      label: 'Simmer on Low Flame',
      durationSeconds: 300,
    })
  )

  assert.equal(leadWs.messages.length, 1)
  const timerMsg = JSON.parse(leadWs.messages[0]) as ServerMessage
  assert.equal(timerMsg.type, 'TIMER_UPDATE')
  if (timerMsg.type === 'TIMER_UPDATE') {
    assert.equal(timerMsg.timer.timerId, 'simmer-timer')
    assert.equal(timerMsg.timer.durationSeconds, 300)
    assert.equal(timerMsg.timer.isRunning, true)
  }
})

test('Co-Cooking Durable Object: Handles member disconnect gracefully', async () => {
  const { doInstance, sockets } = createMockDurableObject()
  const leadWs = new MockWebSocket()
  const coCookWs = new MockWebSocket()

  await doInstance.webSocketMessage(
    leadWs as unknown as WebSocket,
    JSON.stringify({
      type: 'JOIN',
      memberId: 'lead-bikram',
      memberName: 'Bikram',
      role: 'leadCook',
    })
  )

  await doInstance.webSocketMessage(
    coCookWs as unknown as WebSocket,
    JSON.stringify({
      type: 'JOIN',
      memberId: 'co-srijana',
      memberName: 'Srijana',
      role: 'coCook',
    })
  )

  leadWs.messages = []

  // Co-cook disconnects
  await doInstance.webSocketClose(coCookWs as unknown as WebSocket, 1000, 'Normal closure', true)

  assert.equal(leadWs.messages.length, 1)
  const presenceMsg = JSON.parse(leadWs.messages[0]) as ServerMessage
  assert.equal(presenceMsg.type, 'PRESENCE_CHANGE')
  if (presenceMsg.type === 'PRESENCE_CHANGE') {
    const srijana = presenceMsg.presence.find((p) => p.memberId === 'co-srijana')
    assert.equal(srijana?.isConnected, false)
  }
})
