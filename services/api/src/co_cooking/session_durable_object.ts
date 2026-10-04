import {
  CookingSessionState,
  CrewMember,
  ActiveCookingTimer,
  ClientMessage,
  ServerMessage,
} from './types.js'

interface SocketAttachment {
  memberId: string
  memberName: string
  role: 'leadCook' | 'coCook'
  deviceId?: string
}

export class CookingSessionDurableObject {
  state: DurableObjectState
  env: unknown
  sessionState: CookingSessionState | null = null
  private socketAttachments = new WeakMap<WebSocket, SocketAttachment>()
  private inMemorySockets = new Set<WebSocket>()

  constructor(state: DurableObjectState, env: unknown) {
    this.state = state
    this.env = env
  }

  private async ensureState(sessionId: string): Promise<CookingSessionState> {
    if (this.sessionState) return this.sessionState

    const stored = await this.state.storage?.get<CookingSessionState>('sessionState')
    if (stored) {
      this.sessionState = stored
      return this.sessionState
    }

    const now = new Date().toISOString()
    this.sessionState = {
      sessionId,
      recipeId: '',
      recipeTitle: 'Active Cooking Session',
      currentWhistles: 0,
      targetWhistles: 0,
      currentStepIndex: 0,
      totalSteps: 1,
      isAlarmActive: false,
      presence: [],
      timers: [],
      createdAt: now,
      updatedAt: now,
    }
    await this.state.storage?.put('sessionState', this.sessionState)
    return this.sessionState
  }

  private getSessionIdFromUrl(url: string): string {
    try {
      const parsed = new URL(url)
      const parts = parsed.pathname.split('/').filter(Boolean)
      // /v1/co-cooking/:sessionId/...
      const idx = parts.indexOf('co-cooking')
      if (idx !== -1 && parts[idx + 1]) {
        return parts[idx + 1]
      }
      return parts[parts.length - 1] || 'default-session'
    } catch {
      return 'default-session'
    }
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url)
    const sessionId = this.getSessionIdFromUrl(request.url)
    await this.ensureState(sessionId)

    // REST state inspection endpoint
    if (url.pathname.endsWith('/state')) {
      return new Response(JSON.stringify(this.sessionState), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // WebSocket upgrade check
    const upgradeHeader = request.headers.get('Upgrade')
    if (!upgradeHeader || upgradeHeader.toLowerCase() !== 'websocket') {
      return new Response('Expected WebSocket Upgrade', { status: 426 })
    }

    // Handle WebSocket pair
    // In Cloudflare Workers runtime, WebSocketPair is global.
    // In Node.js testing, we can use a shim or WebSocketPair.
    let clientWs: WebSocket
    let serverWs: WebSocket

    if (typeof WebSocketPair !== 'undefined') {
      const pair = new (WebSocketPair as unknown as { new (): { 0: WebSocket; 1: WebSocket } })()
      clientWs = pair[0]
      serverWs = pair[1]
    } else {
      // In mock/test environments
      const mockPair = (this.env as { createMockWebSocketPair?: () => [WebSocket, WebSocket] })
        ?.createMockWebSocketPair?.()
      if (mockPair) {
        clientWs = mockPair[0]
        serverWs = mockPair[1]
      } else {
        return new Response('WebSocketPair not supported', { status: 500 })
      }
    }

    if (this.state.acceptWebSocket) {
      this.state.acceptWebSocket(serverWs)
    } else {
      this.inMemorySockets.add(serverWs)
    }

    return new Response(null, {
      status: 101,
      webSocket: clientWs,
    } as ResponseInit)
  }

  private ensureSocketRegistered(ws: WebSocket) {
    if (this.state.acceptWebSocket && this.state.getWebSockets) {
      const existing = this.state.getWebSockets()
      if (!existing.includes(ws)) {
        this.state.acceptWebSocket(ws)
      }
    }
    this.inMemorySockets.add(ws)
  }

  private getConnectedWebSockets(): WebSocket[] {
    const list: WebSocket[] = []
    if (this.state.getWebSockets) {
      list.push(...this.state.getWebSockets())
    }
    for (const ws of this.inMemorySockets) {
      if (!list.includes(ws)) list.push(ws)
    }
    return list
  }

  private broadcast(message: ServerMessage, excludeWs?: WebSocket) {
    const data = JSON.stringify(message)
    const sockets = this.getConnectedWebSockets()
    for (const ws of sockets) {
      if (ws !== excludeWs) {
        try {
          ws.send(data)
        } catch {
          // Ignore closed sockets
        }
      }
    }
  }

  private getAttachment(ws: WebSocket): SocketAttachment | null {
    if (typeof (ws as any).deserializeAttachment === 'function') {
      try {
        const att = (ws as any).deserializeAttachment()
        if (att) return att as SocketAttachment
      } catch {
        // Fall back to WeakMap
      }
    }
    return this.socketAttachments.get(ws) ?? null
  }

  private setAttachment(ws: WebSocket, attachment: SocketAttachment) {
    if (typeof (ws as any).serializeAttachment === 'function') {
      try {
        ;(ws as any).serializeAttachment(attachment)
      } catch {
        // Fall back to WeakMap
      }
    }
    this.socketAttachments.set(ws, attachment)
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    this.ensureSocketRegistered(ws)
    const str = typeof message === 'string' ? message : new TextDecoder().decode(message)
    let msg: ClientMessage
    try {
      msg = JSON.parse(str)
    } catch {
      ws.send(JSON.stringify({ type: 'ERROR', code: 'INVALID_JSON', message: 'Failed to parse message' }))
      return
    }

    if (!this.sessionState) {
      await this.ensureState('default-session')
    }
    const state = this.sessionState!
    const now = new Date().toISOString()
    state.updatedAt = now

    switch (msg.type) {
      case 'JOIN': {
        const attachment: SocketAttachment = {
          memberId: msg.memberId,
          memberName: msg.memberName,
          role: msg.role,
          deviceId: msg.deviceId,
        }
        this.setAttachment(ws, attachment)

        // Initialize recipe metadata if provided by lead cook
        if (msg.recipeId) state.recipeId = msg.recipeId
        if (msg.recipeTitle) state.recipeTitle = msg.recipeTitle
        if (msg.targetWhistles !== undefined) state.targetWhistles = msg.targetWhistles
        if (msg.totalSteps !== undefined) state.totalSteps = msg.totalSteps

        // Update presence
        const existingIdx = state.presence.findIndex((p) => p.memberId === msg.memberId)
        const memberInfo: CrewMember = {
          memberId: msg.memberId,
          memberName: msg.memberName,
          role: msg.role,
          deviceId: msg.deviceId,
          isConnected: true,
          joinedAt: now,
        }

        if (existingIdx !== -1) {
          state.presence[existingIdx] = memberInfo
        } else {
          state.presence.push(memberInfo)
        }

        // Send full session sync to joining client
        ws.send(JSON.stringify({ type: 'SESSION_SYNC', state }))

        // Broadcast presence change to crew
        this.broadcast(
          {
            type: 'PRESENCE_CHANGE',
            presence: state.presence,
            joined: memberInfo,
          },
          ws
        )
        break
      }

      case 'LEAVE': {
        const existing = state.presence.find((p) => p.memberId === msg.memberId)
        if (existing) {
          existing.isConnected = false
        }
        this.broadcast({
          type: 'PRESENCE_CHANGE',
          presence: state.presence,
          left: msg.memberId,
        })
        break
      }

      case 'WHISTLE_UPDATE': {
        state.currentWhistles = msg.whistles
        if (msg.target !== undefined) {
          state.targetWhistles = msg.target
        }

        const isTargetReached = state.targetWhistles > 0 && state.currentWhistles >= state.targetWhistles

        this.broadcast({
          type: 'WHISTLE_BROADCAST',
          currentWhistles: state.currentWhistles,
          targetWhistles: state.targetWhistles,
          isTargetReached,
          soundConfidence: msg.soundConfidence,
        })

        // When target whistles is reached, broadcast shared alarm to all crew phones!
        if (isTargetReached && !state.isAlarmActive) {
          state.isAlarmActive = true
          this.broadcast({
            type: 'SHARED_ALARM',
            targetWhistles: state.targetWhistles,
            recipeTitle: state.recipeTitle,
            timestamp: now,
          })
        }
        break
      }

      case 'ALARM_TRIGGER': {
        state.isAlarmActive = true
        this.broadcast({
          type: 'SHARED_ALARM',
          targetWhistles: state.targetWhistles,
          recipeTitle: state.recipeTitle,
          timestamp: now,
        })
        break
      }

      case 'ALARM_DISMISS': {
        state.isAlarmActive = false
        state.alarmDismissedBy = {
          memberId: msg.memberId,
          memberName: msg.memberName,
        }
        this.broadcast({
          type: 'ALARM_DISMISSED',
          memberId: msg.memberId,
          memberName: msg.memberName,
        })
        break
      }

      case 'STEP_UPDATE': {
        state.currentStepIndex = msg.stepIndex
        const att = this.getAttachment(ws)
        this.broadcast({
          type: 'STEP_CHANGED',
          stepIndex: msg.stepIndex,
          completedByMemberName: att?.memberName,
        })
        break
      }

      case 'TIMER_START': {
        const timer: ActiveCookingTimer = {
          timerId: msg.timerId,
          label: msg.label,
          durationSeconds: msg.durationSeconds,
          remainingSeconds: msg.durationSeconds,
          isRunning: true,
          startedAt: now,
        }
        const existingIdx = state.timers.findIndex((t) => t.timerId === msg.timerId)
        if (existingIdx !== -1) {
          state.timers[existingIdx] = timer
        } else {
          state.timers.push(timer)
        }
        this.broadcast({ type: 'TIMER_UPDATE', timer })
        break
      }

      case 'TIMER_PAUSE': {
        const timer = state.timers.find((t) => t.timerId === msg.timerId)
        if (timer) {
          timer.isRunning = false
          this.broadcast({ type: 'TIMER_UPDATE', timer })
        }
        break
      }

      case 'TIMER_RESUME': {
        const timer = state.timers.find((t) => t.timerId === msg.timerId)
        if (timer) {
          timer.isRunning = true
          this.broadcast({ type: 'TIMER_UPDATE', timer })
        }
        break
      }

      case 'TIMER_STOP': {
        state.timers = state.timers.filter((t) => t.timerId !== msg.timerId)
        this.broadcast({ type: 'TIMER_REMOVED', timerId: msg.timerId })
        break
      }

      case 'SYNC_REQUEST': {
        ws.send(JSON.stringify({ type: 'SESSION_SYNC', state }))
        break
      }
    }

    await this.state.storage?.put('sessionState', state)
  }

  async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean) {
    this.inMemorySockets.delete(ws)
    const att = this.getAttachment(ws)
    if (att && this.sessionState) {
      const member = this.sessionState.presence.find((p) => p.memberId === att.memberId)
      if (member) {
        member.isConnected = false
        this.broadcast({
          type: 'PRESENCE_CHANGE',
          presence: this.sessionState.presence,
          left: att.memberId,
        })
        await this.state.storage?.put('sessionState', this.sessionState)
      }
    }
  }

  async webSocketError(ws: WebSocket, error: unknown) {
    this.inMemorySockets.delete(ws)
  }
}
