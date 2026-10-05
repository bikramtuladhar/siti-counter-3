/**
 * Siti Counter 3.0 - Multi-Dish Kitchen Engine (Section 10.6)
 * Simultaneous multi-cooker management, parallel cooking lanes,
 * burner & vessel conflict detection, and acoustic whistle disambiguation.
 */

export type CookerVesselType =
  | 'pressure_cooker_5l'
  | 'pressure_cooker_3l'
  | 'kadai_pan'
  | 'saucepan'
  | 'tawa'
  | 'electric_rice_cooker'
  | 'kettle';

export type LaneStatus = 'cooking' | 'waiting' | 'paused' | 'completed';

export interface CookingLane {
  readonly id: string;
  readonly dishName: string;
  readonly dishNameNe: string;
  readonly vesselType: CookerVesselType;
  readonly vesselId: string; // e.g. 'vessel_pc_5l_1'
  readonly requiresBurner: boolean;
  readonly burnerIndex?: number; // 1-indexed burner slot
  status: LaneStatus;
  isAcousticCooker: boolean;
  currentWhistles: number;
  targetWhistles: number;
  remainingSeconds: number;
  totalSeconds: number;
  heatLevel: 'high' | 'medium' | 'low' | 'simmer' | 'off';
}

export interface MultiDishConflict {
  readonly type: 'burner_capacity' | 'vessel_collision';
  readonly messageEn: string;
  readonly messageNe: string;
  readonly conflictingLaneIds: readonly string[];
  readonly suggestionEn: string;
  readonly suggestionNe: string;
}

export interface WhistleDisambiguationRequest {
  readonly timestamp: string;
  readonly candidateLaneIds: readonly string[];
  readonly candidateDishNames: readonly string[];
  resolved: boolean;
  attributedLaneId?: string;
}

export interface MultiDishKitchenConfig {
  maxBurners: number; // typically 2 or 3 in Nepali households
}

export class MultiDishKitchenEngine {
  private lanes: Map<string, CookingLane> = new Map();
  private maxBurners: number;
  private pendingDisambiguation: WhistleDisambiguationRequest | null = null;

  constructor(config?: Partial<MultiDishKitchenConfig>) {
    this.maxBurners = config?.maxBurners ?? 2;
  }

  public getMaxBurners(): number {
    return this.maxBurners;
  }

  public setMaxBurners(burners: number): void {
    this.maxBurners = Math.max(1, burners);
  }

  public getLanes(): readonly CookingLane[] {
    return Array.from(this.lanes.values());
  }

  public getLane(id: string): CookingLane | undefined {
    return this.lanes.get(id);
  }

  public addLane(lane: CookingLane): void {
    this.lanes.set(lane.id, { ...lane });
  }

  public removeLane(id: string): boolean {
    return this.lanes.delete(id);
  }

  public updateLaneStatus(id: string, status: LaneStatus): void {
    const lane = this.lanes.get(id);
    if (lane) {
      lane.status = status;
    }
  }

  /**
   * Checks for equipment conflicts:
   * 1. Burner capacity: Total active lanes requiring a burner exceeds available burners.
   * 2. Vessel collision: Two simultaneously cooking lanes assigned the exact same physical vessel.
   */
  public detectConflicts(): MultiDishConflict[] {
    const conflicts: MultiDishConflict[] = [];
    const activeLanes = Array.from(this.lanes.values()).filter(
      (l) => l.status === 'cooking'
    );

    // 1. Burner capacity check
    const burnerLanes = activeLanes.filter((l) => l.requiresBurner);
    if (burnerLanes.length > this.maxBurners) {
      const excess = burnerLanes.length - this.maxBurners;
      conflicts.push({
        type: 'burner_capacity',
        messageEn: `Cooktop capacity exceeded: ${burnerLanes.length} dishes active on ${this.maxBurners} burners.`,
        messageNe: `चुल्होको क्षमता नाघ्यो: ${this.maxBurners} बर्नरमा ${burnerLanes.length} परिकार पाक्दैछन्।`,
        conflictingLaneIds: burnerLanes.map((l) => l.id),
        suggestionEn: `Move ${excess} dish(es) to waiting status or cook ahead.`,
        suggestionNe: `${excess} परिकारलाई पर्खने सूचीमा राख्नुहोस् वा अगाडि नै पकाउनुहोस्।`,
      });
    }

    // 2. Vessel collision check
    const vesselUsage = new Map<string, string[]>();
    for (const lane of activeLanes) {
      if (!vesselUsage.has(lane.vesselId)) {
        vesselUsage.set(lane.vesselId, []);
      }
      vesselUsage.get(lane.vesselId)!.push(lane.id);
    }

    for (const [vesselId, laneIds] of vesselUsage.entries()) {
      if (laneIds.length > 1) {
        const laneNames = laneIds
          .map((id) => this.lanes.get(id)?.dishName || id)
          .join(' & ');
        conflicts.push({
          type: 'vessel_collision',
          messageEn: `Vessel conflict: Multiple dishes (${laneNames}) assigned to the same vessel '${vesselId}'.`,
          messageNe: `भाँडो जुधाइ: एउटै भाँडो (${vesselId}) धेरै परिकारहरू (${laneNames}) मा प्रयोग गरिएको छ।`,
          conflictingLaneIds: laneIds,
          suggestionEn: 'Assign an alternate pot or finish one dish before starting the next.',
          suggestionNe: 'अर्को भाँडो प्रयोग गर्नुहोस् वा पहिलेको परिकार पाकिसकेपछि सुरु गर्नुहोस्।',
        });
      }
    }

    return conflicts;
  }

  /**
   * Handles an acoustic whistle detection event across all lanes.
   * If exactly 1 acoustic cooker is cooking, increments count immediately.
   * If > 1 acoustic cooker is cooking, raises a disambiguation request.
   */
  public handleAcousticWhistle(timestamp?: Date): {
    attributedLaneId?: string;
    needsDisambiguation: boolean;
    disambiguationRequest?: WhistleDisambiguationRequest;
  } {
    const activeCookers = Array.from(this.lanes.values()).filter(
      (l) => l.status === 'cooking' && l.isAcousticCooker
    );

    if (activeCookers.length === 0) {
      return { needsDisambiguation: false };
    }

    if (activeCookers.length === 1) {
      const cooker = activeCookers[0];
      cooker.currentWhistles += 1;
      if (cooker.currentWhistles >= cooker.targetWhistles) {
        cooker.status = 'completed';
      }
      return {
        attributedLaneId: cooker.id,
        needsDisambiguation: false,
      };
    }

    // Multiple acoustic cookers active simultaneously!
    const req: WhistleDisambiguationRequest = {
      timestamp: (timestamp ?? new Date()).toISOString(),
      candidateLaneIds: activeCookers.map((c) => c.id),
      candidateDishNames: activeCookers.map((c) => c.dishName),
      resolved: false,
    };
    this.pendingDisambiguation = req;

    return {
      needsDisambiguation: true,
      disambiguationRequest: req,
    };
  }

  public getPendingDisambiguation(): WhistleDisambiguationRequest | null {
    return this.pendingDisambiguation;
  }

  /**
   * Resolves a pending whistle disambiguation by attributing the whistle to a specific lane.
   */
  public resolveDisambiguation(laneId: string): boolean {
    if (!this.pendingDisambiguation || !this.pendingDisambiguation.candidateLaneIds.includes(laneId)) {
      return false;
    }

    const lane = this.lanes.get(laneId);
    if (lane) {
      lane.currentWhistles += 1;
      if (lane.currentWhistles >= lane.targetWhistles) {
        lane.status = 'completed';
      }
    }

    this.pendingDisambiguation.resolved = true;
    this.pendingDisambiguation.attributedLaneId = laneId;
    this.pendingDisambiguation = null;
    return true;
  }

  /**
   * Increments timer tick by deltaSeconds for all active simmer/timer lanes.
   */
  public tickTimers(deltaSeconds: number): void {
    for (const lane of this.lanes.values()) {
      if (lane.status === 'cooking' && lane.remainingSeconds > 0) {
        lane.remainingSeconds = Math.max(0, lane.remainingSeconds - deltaSeconds);
        if (lane.remainingSeconds === 0 && !lane.isAcousticCooker) {
          lane.status = 'completed';
        }
      }
    }
  }
}
