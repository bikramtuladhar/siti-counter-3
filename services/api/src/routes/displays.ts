import { Hono } from 'hono'
import { CompanionDisplayEngine } from '@siti-counter/kitchen-engine'
import { requireHousehold } from '../middleware/household_auth.js'
import { getHouseholdEntitiesOfType } from './sync.js'

/**
 * Glanceable display feed (Section 23.4).
 *
 * The API is the source of truth for what the home screen widgets and the watch companion
 * render. Clients cache the response and revalidate with `If-None-Match`; an unchanged
 * household answers 304 with no body, so a routine widget refresh costs no payload bytes.
 *
 * The payload is assembled from the same entity store that backs `POST /v1/sync`, so a
 * glanceable surface can never disagree with the data the app synced.
 */
export const displayRouter = new Hono()

displayRouter.use('/v1/displays/feed', requireHousehold())

interface FeedEntity {
  id: string
  payload: Record<string, unknown>
}

function readString(payload: Record<string, unknown>, key: string, fallback = ''): string {
  const value = payload[key]
  return typeof value === 'string' ? value : fallback
}

function readNumber(payload: Record<string, unknown>, key: string, fallback = 0): number {
  const value = payload[key]
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function readBoolean(payload: Record<string, unknown>, key: string, fallback = false): boolean {
  const value = payload[key]
  return typeof value === 'boolean' ? value : fallback
}

function readStringArray(payload: Record<string, unknown>, key: string): string[] {
  const value = payload[key]
  return Array.isArray(value) ? value.filter((v): v is string => typeof v === 'string') : []
}

/** Builds the today's-meals widget payload from `meal_plan` entities. */
function buildTodaysMeals(householdId: string, dateIso?: string) {
  const plans = getHouseholdEntitiesOfType(householdId, 'meal_plan')
  const today = dateIso ?? new Date().toISOString().split('T')[0]

  // The newest plan per (date, slot) wins, so a re-planned slot is not listed twice.
  const bySlot = new Map<string, FeedEntity>()
  for (const plan of plans) {
    const payload = plan.payload as Record<string, unknown>
    const date = readString(payload, 'dateIso', today)
    if (date !== today) continue
    const slotId = readString(payload, 'slotId', 'slot')
    bySlot.set(slotId, { id: plan.entityId, payload })
  }

  const meals = Array.from(bySlot.values())
    .sort((a, b) => readNumber(a.payload, 'sortOrder') - readNumber(b.payload, 'sortOrder'))
    .map(({ id, payload }) => ({
      slotId: readString(payload, 'slotId', id),
      slotTitleEn: readString(payload, 'slotTitleEn', readString(payload, 'slotTitle')),
      slotTitleNe: readString(payload, 'slotTitleNe', readString(payload, 'slotTitle')),
      recipeTitleEn: readString(payload, 'recipeTitleEn', readString(payload, 'recipeTitle')),
      recipeTitleNe: readString(payload, 'recipeTitleNe', readString(payload, 'recipeTitle')),
      servings: readNumber(payload, 'servings', 4),
    }))

  const firstPayload = meals.length > 0 ? plans[plans.length - 1].payload as Record<string, unknown> : {}

  return CompanionDisplayEngine.buildTodaysMealsWidget({
    dateIso: today,
    rituNameEn: readString(firstPayload, 'rituNameEn'),
    rituNameNe: readString(firstPayload, 'rituNameNe'),
    meals,
  })
}

/**
 * Builds the active siti counter + watch companion payload from `batch` entities.
 *
 * A batch is the active cooking session: the whistle target and step list live on it. The
 * highest-`updatedAt` batch is the live session, which is what both the phone widget and the
 * watch render.
 */
function buildActiveSession(householdId: string) {
  const batches = getHouseholdEntitiesOfType(householdId, 'batch')
  if (batches.length === 0) return null

  const live = batches.reduce((latest, candidate) =>
    readNumber(candidate.payload, 'updatedAt') >= readNumber(latest.payload, 'updatedAt')
      ? candidate
      : latest,
  )

  const payload = live.payload as Record<string, unknown>
  const currentWhistles = readNumber(payload, 'currentWhistles')
  const targetWhistles = readNumber(payload, 'targetWhistles')
  const isAlarmAcknowledged = readBoolean(payload, 'isAlarmAcknowledged')

  const stepsEn = readStringArray(payload, 'stepsEn')
  const stepsNe = readStringArray(payload, 'stepsNe')
  const stepIndex = readNumber(payload, 'currentStepIndex')

  const activeSiti = CompanionDisplayEngine.buildActiveSitiWidget({
    sessionId: live.entityId,
    dishTitleEn: readString(payload, 'dishTitleEn', readString(payload, 'dishTitle')),
    dishTitleNe: readString(payload, 'dishTitleNe', readString(payload, 'dishTitle')),
    currentWhistles,
    targetWhistles,
    isAlarmActive: readBoolean(payload, 'isAlarmActive'),
    isAlarmAcknowledged,
  })

  const watchState = CompanionDisplayEngine.buildWatchCompanionState({
    sessionId: live.entityId,
    dishTitleEn: activeSiti.dishTitleEn,
    dishTitleNe: activeSiti.dishTitleNe,
    currentWhistles,
    targetWhistles,
    currentStepIndex: stepIndex,
    totalSteps: stepsEn.length || readNumber(payload, 'totalSteps'),
    currentStepInstructionEn: stepsEn[stepIndex] ?? '',
    currentStepInstructionNe: stepsNe[stepIndex] ?? '',
    isAlarmActive: activeSiti.isAlarmActive,
    isAlarmAcknowledged,
  })

  return { activeSiti, watchState }
}

/** Builds the grocery checklist payload from `grocery_item` entities. */
function buildGroceryChecklist(householdId: string) {
  const items = getHouseholdEntitiesOfType(householdId, 'grocery_item').map(({ entityId, payload }) => ({
    itemId: entityId,
    nameEn: readString(payload, 'nameEn', readString(payload, 'name')),
    nameNe: readString(payload, 'nameNe', readString(payload, 'name')),
    quantityStr: readString(payload, 'quantityStr', readString(payload, 'quantity')),
    isCompleted: readBoolean(payload, 'isCompleted', readBoolean(payload, 'inPantry')),
  }))

  return CompanionDisplayEngine.buildGroceryChecklistWidget(items)
}

/**
 * Deterministic feed fingerprint used as the ETag.
 *
 * Derived from the entity ids, versions and server write timestamps that feed the response,
 * so any change that can alter the payload changes the ETag, and nothing else does.
 */
function computeEtag(householdId: string): string {
  const parts: string[] = []
  for (const entityType of ['meal_plan', 'grocery_item', 'batch'] as const) {
    for (const entity of getHouseholdEntitiesOfType(householdId, entityType)) {
      parts.push(`${entityType}:${entity.entityId}:${entity.version}:${entity.serverTimestamp}`)
    }
  }
  // Weak ETag: the payload is semantically identical when these match, byte-identical or not.
  return `W/"${householdId.length}-${parts.join('|').length}-${simpleHash(parts.join('|'))}"`
}

function simpleHash(input: string): string {
  let hash = 5381
  for (let i = 0; i < input.length; i++) {
    hash = ((hash << 5) + hash + input.charCodeAt(i)) | 0
  }
  return (hash >>> 0).toString(16)
}

displayRouter.get('/v1/displays/feed', (c) => {
  const householdId = c.get('householdId' as never) as string
  const etag = computeEtag(householdId)

  // Revalidation: the client's cached copy is still current, so spend no payload bytes.
  const ifNoneMatch = c.req.header('If-None-Match')
  if (ifNoneMatch && matchesEtag(ifNoneMatch, etag)) {
    c.header('ETag', etag)
    c.header('Cache-Control', 'private, max-age=0, must-revalidate')
    return c.body(null, 304)
  }

  const session = buildActiveSession(householdId)

  c.header('ETag', etag)
  c.header('Cache-Control', 'private, max-age=0, must-revalidate')

  return c.json({
    householdId,
    fetchedAt: new Date().toISOString(),
    etag,
    todaysMeals: buildTodaysMeals(householdId, c.req.query('date')),
    activeSiti: session?.activeSiti ?? null,
    watchState: session?.watchState ?? null,
    groceryChecklist: buildGroceryChecklist(householdId),
  })
})

/** Tolerates a client sending a comma-separated list of ETags, as HTTP allows. */
function matchesEtag(ifNoneMatch: string, etag: string): boolean {
  return ifNoneMatch
    .split(',')
    .map((candidate) => candidate.trim())
    .some((candidate) => candidate === etag || candidate === '*')
}