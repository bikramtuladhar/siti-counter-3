/**
 * Realtime Co-Cooking Session & Crew Synchronization Types
 * Section 12.6, 20.2 - Cloudflare Durable Objects WebSockets
 */

export type CrewRole = 'leadCook' | 'coCook'

export interface CrewMember {
  memberId: string
  memberName: string
  role: CrewRole
  deviceId?: string
  isConnected: boolean
  joinedAt: string
}

export interface ActiveCookingTimer {
  timerId: string
  label: string
  durationSeconds: number
  remainingSeconds: number
  isRunning: boolean
  startedAt?: string
}

export interface CookingSessionState {
  sessionId: string
  recipeId: string
  recipeTitle: string
  currentWhistles: number
  targetWhistles: number
  currentStepIndex: number
  totalSteps: number
  isAlarmActive: boolean
  alarmDismissedBy?: { memberId: string; memberName: string }
  presence: CrewMember[]
  timers: ActiveCookingTimer[]
  createdAt: string
  updatedAt: string
}

export type ClientMessage =
  | {
      type: 'JOIN'
      memberId: string
      memberName: string
      role: CrewRole
      deviceId?: string
      recipeId?: string
      recipeTitle?: string
      targetWhistles?: number
      totalSteps?: number
    }
  | { type: 'LEAVE'; memberId: string }
  | { type: 'WHISTLE_UPDATE'; whistles: number; target?: number; soundConfidence?: number }
  | { type: 'STEP_UPDATE'; stepIndex: number; completedBy?: string }
  | { type: 'ALARM_TRIGGER'; reason?: string }
  | { type: 'ALARM_DISMISS'; memberId: string; memberName: string }
  | { type: 'TIMER_START'; timerId: string; label: string; durationSeconds: number }
  | { type: 'TIMER_PAUSE'; timerId: string }
  | { type: 'TIMER_RESUME'; timerId: string }
  | { type: 'TIMER_STOP'; timerId: string }
  | { type: 'SYNC_REQUEST' }

export type ServerMessage =
  | { type: 'SESSION_SYNC'; state: CookingSessionState }
  | { type: 'PRESENCE_CHANGE'; presence: CrewMember[]; joined?: CrewMember; left?: string }
  | {
      type: 'WHISTLE_BROADCAST'
      currentWhistles: number
      targetWhistles: number
      isTargetReached: boolean
      soundConfidence?: number
    }
  | { type: 'SHARED_ALARM'; targetWhistles: number; recipeTitle: string; timestamp: string }
  | { type: 'ALARM_DISMISSED'; memberId: string; memberName: string }
  | { type: 'STEP_CHANGED'; stepIndex: number; completedByMemberName?: string }
  | { type: 'TIMER_UPDATE'; timer: ActiveCookingTimer }
  | { type: 'TIMER_REMOVED'; timerId: string }
  | { type: 'ERROR'; code: string; message: string }
