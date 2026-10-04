/**
 * Fuel Engine (TypeScript): LPG Cylinder Depletion Estimator & Power-Cut Mode
 *
 * Implements Section 10.5 of Siti Counter 3.0 specification:
 * - LPG cylinder burn-rate estimation based on session logs & flame level
 * - Refill reminder alerts when cylinder is predicted to deplete in <= 4 days
 * - Power-cut mode: filters gas-only and no-cook recipes, excluding electric appliances
 */

export type LpgCylinderTypeKey = 'standard14_2' | 'commercial19' | 'mini5';

export interface LpgCylinderTypeSpec {
  netGasCapacityKg: number;
  defaultTareWeightKg: number;
  label: string;
}

export const LPG_CYLINDER_TYPES: Record<LpgCylinderTypeKey, LpgCylinderTypeSpec> = {
  standard14_2: {
    netGasCapacityKg: 14.2,
    defaultTareWeightKg: 15.3,
    label: 'Standard Domestic (14.2 kg)',
  },
  commercial19: {
    netGasCapacityKg: 19.0,
    defaultTareWeightKg: 18.5,
    label: 'Commercial Cylinder (19 kg)',
  },
  mini5: {
    netGasCapacityKg: 5.0,
    defaultTareWeightKg: 6.2,
    label: 'Chhotu / Mini (5 kg)',
  },
};

export type FlameIntensityLevel = 'high' | 'medium' | 'low';

export const FLAME_INTENSITY_RATES: Record<FlameIntensityLevel, { gramsPerHour: number; label: string }> = {
  high: { gramsPerHour: 200.0, label: 'High Flame (ठूलो आगो)' },
  medium: { gramsPerHour: 130.0, label: 'Medium Flame (मध्यम आगो)' },
  low: { gramsPerHour: 70.0, label: 'Simmer / Low (मन्द आगो)' },
};

export type RefillUrgencyLevel = 'normal' | 'order_soon' | 'critical' | 'empty';

export interface CookingFuelSessionProps {
  sessionId: string;
  recipeName: string;
  startTime: Date | string;
  durationMinutes: number;
  flameIntensity?: FlameIntensityLevel;
  burnerCount?: number;
}

export class CookingFuelSession {
  public readonly sessionId: string;
  public readonly recipeName: string;
  public readonly startTime: Date;
  public readonly durationMinutes: number;
  public readonly flameIntensity: FlameIntensityLevel;
  public readonly burnerCount: number;

  constructor(props: CookingFuelSessionProps) {
    this.sessionId = props.sessionId;
    this.recipeName = props.recipeName;
    this.startTime = typeof props.startTime === 'string' ? new Date(props.startTime) : props.startTime;
    this.durationMinutes = props.durationMinutes;
    this.flameIntensity = props.flameIntensity ?? 'medium';
    this.burnerCount = props.burnerCount ?? 1;
  }

  public get gasConsumedGrams(): number {
    const rate = FLAME_INTENSITY_RATES[this.flameIntensity].gramsPerHour / 60.0;
    return this.durationMinutes * rate * this.burnerCount;
  }
}

export interface LpgCylinderStateProps {
  id: string;
  type?: LpgCylinderTypeKey;
  brand?: string;
  installationDate: Date | string;
  initialNetGasKg: number;
  remainingGasKg: number;
  tareWeightKg: number;
  lastCalibratedDate?: Date | string;
}

export class LpgCylinderState {
  public readonly id: string;
  public readonly type: LpgCylinderTypeKey;
  public readonly brand: string;
  public readonly installationDate: Date;
  public readonly initialNetGasKg: number;
  public readonly remainingGasKg: number;
  public readonly tareWeightKg: number;
  public readonly lastCalibratedDate?: Date;

  constructor(props: LpgCylinderStateProps) {
    this.id = props.id;
    this.type = props.type ?? 'standard14_2';
    this.brand = props.brand ?? 'Nepal Gas';
    this.installationDate = typeof props.installationDate === 'string' ? new Date(props.installationDate) : props.installationDate;
    this.initialNetGasKg = props.initialNetGasKg;
    this.remainingGasKg = props.remainingGasKg;
    this.tareWeightKg = props.tareWeightKg;
    this.lastCalibratedDate = props.lastCalibratedDate
      ? typeof props.lastCalibratedDate === 'string'
        ? new Date(props.lastCalibratedDate)
        : props.lastCalibratedDate
      : undefined;
  }

  public static newCylinder(options?: {
    id?: string;
    type?: LpgCylinderTypeKey;
    brand?: string;
    installationDate?: Date;
    tareWeightKg?: number;
  }): LpgCylinderState {
    const typeKey = options?.type ?? 'standard14_2';
    const spec = LPG_CYLINDER_TYPES[typeKey];
    const now = options?.installationDate ?? new Date();

    return new LpgCylinderState({
      id: options?.id ?? 'cyl-primary',
      type: typeKey,
      brand: options?.brand ?? 'Nepal Gas',
      installationDate: now,
      initialNetGasKg: spec.netGasCapacityKg,
      remainingGasKg: spec.netGasCapacityKg,
      tareWeightKg: options?.tareWeightKg ?? spec.defaultTareWeightKg,
      lastCalibratedDate: now,
    });
  }

  public get percentageRemaining(): number {
    if (this.initialNetGasKg <= 0) return 0;
    const pct = (this.remainingGasKg / this.initialNetGasKg) * 100.0;
    return Math.max(0, Math.min(100, pct));
  }

  public recordConsumption(gramsConsumed: number): LpgCylinderState {
    const kgDeducted = gramsConsumed / 1000.0;
    const updated = Math.max(0, Math.min(this.initialNetGasKg, this.remainingGasKg - kgDeducted));
    return new LpgCylinderState({
      id: this.id,
      type: this.type,
      brand: this.brand,
      installationDate: this.installationDate,
      initialNetGasKg: this.initialNetGasKg,
      remainingGasKg: updated,
      tareWeightKg: this.tareWeightKg,
      lastCalibratedDate: this.lastCalibratedDate,
    });
  }

  public calibrateFromGrossWeight(grossWeightKg: number): LpgCylinderState {
    const calculatedNet = Math.max(0, Math.min(this.initialNetGasKg, grossWeightKg - this.tareWeightKg));
    return new LpgCylinderState({
      id: this.id,
      type: this.type,
      brand: this.brand,
      installationDate: this.installationDate,
      initialNetGasKg: this.initialNetGasKg,
      remainingGasKg: calculatedNet,
      tareWeightKg: this.tareWeightKg,
      lastCalibratedDate: new Date(),
    });
  }
}

export interface LpgDepletionForecast {
  remainingGasKg: number;
  remainingPercentage: number;
  averageDailyBurnGrams: number;
  estimatedDaysRemaining: number;
  estimatedDepletionDate: Date;
  urgency: RefillUrgencyLevel;
  refillAlertMessageEn: string;
  refillAlertMessageNe: string;
  isRefillNeeded: boolean;
}

export type RecipePowerProfileType =
  | 'no_cook'
  | 'gas_pressure_cooker'
  | 'gas_stove_top'
  | 'electric_appliance';

export interface PowerCutRecipeItem {
  id: string;
  nameEn: string;
  nameNe: string;
  powerProfile: RecipePowerProfileType;
  cookTimeMinutes: number;
  whistles?: number;
  isGasSaver?: boolean;
}

export class FuelEngine {
  public static readonly defaultDailyBurnGrams = 280.0;

  public static predictDepletion(params: {
    cylinder: LpgCylinderState;
    recentSessions?: CookingFuelSession[];
    currentDate?: Date;
  }): LpgDepletionForecast {
    const now = params.currentDate ?? new Date();
    const cylinder = params.cylinder;

    let dailyBurnGrams: number;
    if (params.recentSessions && params.recentSessions.length > 0) {
      const totalGas = params.recentSessions.reduce((acc, s) => acc + s.gasConsumedGrams, 0);
      const daysSpan = Math.max(1.0, Math.min(90.0, (now.getTime() - cylinder.installationDate.getTime()) / (1000 * 3600 * 24)));
      dailyBurnGrams = Math.max(100.0, Math.min(900.0, totalGas / daysSpan));
    } else {
      dailyBurnGrams = FuelEngine.defaultDailyBurnGrams;
    }

    const remainingGrams = cylinder.remainingGasKg * 1000.0;
    const estimatedDays = dailyBurnGrams > 0 ? remainingGrams / dailyBurnGrams : 0.0;
    const depletionDate = new Date(now.getTime() + estimatedDays * 24 * 3600 * 1000);

    let urgency: RefillUrgencyLevel;
    if (cylinder.remainingGasKg <= 0.05 || estimatedDays <= 0.1) {
      urgency = 'empty';
    } else if (estimatedDays <= 1.5 || cylinder.percentageRemaining <= 5.0) {
      urgency = 'critical';
    } else if (estimatedDays <= 4.0 || cylinder.percentageRemaining <= 15.0) {
      urgency = 'order_soon';
    } else {
      urgency = 'normal';
    }

    let alertEn: string;
    let alertNe: string;

    switch (urgency) {
      case 'empty':
        alertEn = 'LPG Cylinder is EMPTY! Switch to spare cylinder or order refill immediately.';
        alertNe = 'एलपिजी सिलिन्डर रित्तियो! स्पेयर सिलिन्डर जोड्नुहोस् वा तुरुन्तै नयाँ मगाउनुहोस्।';
        break;
      case 'critical':
        alertEn = `URGENT: Only ~${estimatedDays.toFixed(1)} days (${cylinder.remainingGasKg.toFixed(1)} kg) of gas left. Call dealer for refill today!`;
        alertNe = `अति जरुरी: करिब ${estimatedDays.toFixed(1)} दिन (${cylinder.remainingGasKg.toFixed(1)} केजी) ग्यास मात्र बाँकी छ। आजै डिलरलाई अर्डर गर्नुहोस्!`;
        break;
      case 'order_soon':
        alertEn = `Refill Reminder: Cylinder predicted to deplete in ~${estimatedDays.toFixed(1)} days (${cylinder.percentageRemaining.toFixed(0)}% left). Order your refill.`;
        alertNe = `रिफिल रिमाइन्डर: सिलिन्डर करिब ${estimatedDays.toFixed(1)} दिनमा सकिनेछ (${cylinder.percentageRemaining.toFixed(0)}% बाँकी)। नयाँ सिलिन्डर बुक गर्नुहोस्।`;
        break;
      case 'normal':
        alertEn = `LPG gas level is healthy (${cylinder.remainingGasKg.toFixed(1)} kg, ~${estimatedDays.toFixed(0)} days remaining).`;
        alertNe = `एलपिजी ग्यास पर्याप्त छ (${cylinder.remainingGasKg.toFixed(1)} केजी, करिब ${estimatedDays.toFixed(0)} दिन बाँकी)।`;
        break;
    }

    return {
      remainingGasKg: cylinder.remainingGasKg,
      remainingPercentage: cylinder.percentageRemaining,
      averageDailyBurnGrams: dailyBurnGrams,
      estimatedDaysRemaining: estimatedDays,
      estimatedDepletionDate: depletionDate,
      urgency,
      refillAlertMessageEn: alertEn,
      refillAlertMessageNe: alertNe,
      isRefillNeeded: urgency === 'order_soon' || urgency === 'critical' || urgency === 'empty',
    };
  }

  public static filterForPowerCut(params: {
    recipes: PowerCutRecipeItem[];
    gasSaverOnly?: boolean;
    noCookOnly?: boolean;
  }): PowerCutRecipeItem[] {
    return params.recipes.filter((r) => {
      if (r.powerProfile === 'electric_appliance') return false;
      if (params.noCookOnly && r.powerProfile !== 'no_cook') return false;
      if (params.gasSaverOnly && !r.isGasSaver && r.powerProfile !== 'no_cook') return false;
      return true;
    });
  }
}
