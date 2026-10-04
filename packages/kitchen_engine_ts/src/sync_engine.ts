/**
 * RFC 9562 UUIDv7 generator and utility functions for TypeScript.
 *
 * Layout:
 * - 48 bits: Unix timestamp in milliseconds (Big Endian)
 * - 4 bits: Version 7 (0b0111)
 * - 12 bits: Sub-millisecond sequence counter / random seed
 * - 2 bits: Variant 1 (0b10)
 * - 62 bits: Pseudo-random data
 */
export class UuidV7 {
  private static lastTimestampMs = -1
  private static sequence = 0
  private static readonly uuidV7Regex =
    /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-7[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/

  /**
   * Generates a time-ordered UUIDv7 string.
   */
  public static generate(timestampMs?: number): string {
    const now = timestampMs ?? Date.now()

    if (now === this.lastTimestampMs) {
      this.sequence = (this.sequence + 1) & 0x0fff
    } else {
      this.lastTimestampMs = now
      this.sequence = Math.floor(Math.random() * 0x1000)
    }

    const tsHex = now.toString(16).padStart(12, '0')
    const timeHigh = tsHex.substring(0, 8)
    const timeMid = tsHex.substring(8, 12)

    const verAndSeq = `7${this.sequence.toString(16).padStart(3, '0')}`

    const variantNibble = (0x8 | Math.floor(Math.random() * 4)).toString(16)
    const randA = Math.floor(Math.random() * 0x1000)
      .toString(16)
      .padStart(3, '0')
    const randB1 = Math.floor(Math.random() * 0x10000)
      .toString(16)
      .padStart(4, '0')
    const randB2 = Math.floor(Math.random() * 0x10000)
      .toString(16)
      .padStart(4, '0')
    const randB3 = Math.floor(Math.random() * 0x10000)
      .toString(16)
      .padStart(4, '0')

    return `${timeHigh}-${timeMid}-${verAndSeq}-${variantNibble}${randA}-${randB1}${randB2}${randB3}`.toLowerCase()
  }

  /**
   * Verifies whether uuid matches RFC 9562 UUIDv7 format.
   */
  public static isValid(uuid: string): boolean {
    return this.uuidV7Regex.test(uuid)
  }

  /**
   * Extracts Unix epoch timestamp in milliseconds from a valid UUIDv7 string.
   */
  public static getTimestampMs(uuid: string): number | null {
    if (!this.isValid(uuid)) return null
    const clean = uuid.replace(/-/g, '')
    const timeHex = clean.substring(0, 12)
    const parsed = parseInt(timeHex, 16)
    return isNaN(parsed) ? null : parsed
  }
}

export type SyncEntityType =
  | 'household'
  | 'member'
  | 'recipe'
  | 'meal_plan'
  | 'grocery_item'
  | 'batch'
  | 'consumption'
  | 'pantry_item'

export interface SyncChange {
  id: string // UUIDv7
  householdId: string
  entityType: SyncEntityType | string
  entityId: string
  version: number
  payload: Record<string, unknown>
  deleted?: boolean
  createdAt: number // Unix epoch ms
}

export type SyncResolutionAction = 'applyRemote' | 'keepLocal' | 'promptUser' | 'applySafeMerge'

export interface SyncConflict {
  entityType: string
  entityId: string
  reason: string
  localChange: SyncChange
  remoteChange: SyncChange
  requiresPrompt: boolean
  safeMergedPayload?: Record<string, unknown>
}

export interface SyncResolutionResult {
  action: SyncResolutionAction
  winner?: SyncChange
  conflict?: SyncConflict
  effectivePayload?: Record<string, unknown>
}

export class SyncConflictResolver {
  /**
   * Resolves conflicts between a local change and a remote change.
   *
   * Safety Principle:
   * Allergies and critical safety dietary rules must NEVER be silently discarded by stale syncs.
   * If allergy sets conflict, a safe merge (union) is provided and user prompt is flagged.
   */
  public static resolve(params: { local: SyncChange; remote: SyncChange }): SyncResolutionResult {
    const { local, remote } = params

    // 1. Safety Gate: Member Allergies & Dietary Restrictions
    if (
      local.entityType === 'member' ||
      (local.payload && 'allergies' in local.payload) ||
      (remote.payload && 'allergies' in remote.payload)
    ) {
      const localAllergies = this.extractStringSet(local.payload?.allergies)
      const remoteAllergies = this.extractStringSet(remote.payload?.allergies)

      const allergiesDiffer = !this.setEquals(localAllergies, remoteAllergies)

      if (allergiesDiffer) {
        const safeUnion = Array.from(new Set([...localAllergies, ...remoteAllergies])).sort()
        const safeMerged: Record<string, unknown> = {
          ...(remote.payload || {}),
          allergies: safeUnion
        }

        const conflict: SyncConflict = {
          entityType: local.entityType,
          entityId: local.entityId,
          reason: 'ALLERGY_MODIFICATION_REQUIRES_CONFIRMATION',
          localChange: local,
          remoteChange: remote,
          requiresPrompt: true,
          safeMergedPayload: safeMerged
        }

        return {
          action: 'promptUser',
          conflict,
          effectivePayload: safeMerged,
          winner: { ...remote, payload: safeMerged }
        }
      }
    }

    // 2. Deterministic Last-Write-Wins (LWW)
    // Primary criterion: Record versioning
    if (remote.version > local.version) {
      return {
        action: 'applyRemote',
        winner: remote,
        effectivePayload: remote.payload
      }
    } else if (local.version > remote.version) {
      return {
        action: 'keepLocal',
        winner: local,
        effectivePayload: local.payload
      }
    }

    // Secondary criterion: Creation timestamp
    if (remote.createdAt > local.createdAt) {
      return {
        action: 'applyRemote',
        winner: remote,
        effectivePayload: remote.payload
      }
    } else if (local.createdAt > remote.createdAt) {
      return {
        action: 'keepLocal',
        winner: local,
        effectivePayload: local.payload
      }
    }

    // Tertiary tie-breaker: Lexicographical comparison of UUIDv7 strings
    if (remote.id.localeCompare(local.id) > 0) {
      return {
        action: 'applyRemote',
        winner: remote,
        effectivePayload: remote.payload
      }
    } else {
      return {
        action: 'keepLocal',
        winner: local,
        effectivePayload: local.payload
      }
    }
  }

  private static extractStringSet(val: unknown): Set<string> {
    if (Array.isArray(val)) {
      return new Set(val.map((x) => String(x).trim().toLowerCase()))
    }
    return new Set<string>()
  }

  private static setEquals(a: Set<string>, b: Set<string>): boolean {
    if (a.size !== b.size) return false
    for (const item of a) {
      if (!b.has(item)) return false
    }
    return true
  }
}
