/**
 * Launch Gate Monitor & Verification Engine (Section 28.3)
 * Evaluates the 4 mandatory launch gates for Siti Counter 3.0 Open Beta:
 * 1. Crash-free user sessions >= 99.5%
 * 2. Cloudflare free-tier utilization below 70% with automated alert thresholds
 * 3. Privacy policy and terms compliant with Nepal Privacy Act 2075 and GDPR
 * 4. Active weekly cooking rate >= 40% among closed beta households
 */

export interface CrashFreeMetrics {
  totalSessions: number;
  crashedSessions: number;
}

export interface CrashFreeResult {
  totalSessions: number;
  crashedSessions: number;
  crashFreeRate: number; // e.g. 0.998 for 99.8%
  crashFreePercentage: number; // 99.8
  passesGate: boolean; // >= 0.995
  remainingCrashBudget: number; // Max allowed additional crashes before breaching gate
}

export interface CloudflareResourceUsage {
  workersRequestsDaily: number; // Free limit: 100,000 / day
  workersCpuTimeMsAvg: number; // Free threshold: 10 ms / request
  d1ReadsDaily: number; // Free limit: ~166,666 / day (5,000,000 / mo)
  d1WritesDaily: number; // Free limit: 100,000 / day
  kvReadsDaily: number; // Free limit: 100,000 / day
  kvWritesDaily: number; // Free limit: 1,000 / day
  r2StorageGb: number; // Free limit: 10 GB
}

export type AlertSeverity = 'HEALTHY' | 'NOTICE' | 'WARNING' | 'ALERT' | 'CRITICAL';

export interface ResourceUtilizationDetail {
  current: number;
  limit: number;
  utilizationRate: number; // e.g. 0.65
  utilizationPercentage: number; // 65.0
  severity: AlertSeverity;
  alertTriggered: boolean; // >= 0.70 (70%)
}

export interface CloudflareFreeTierResult {
  passesGate: boolean; // all resources < 0.70
  maxUtilizationRate: number;
  highestResource: string;
  alerts: string[];
  resources: {
    workersRequests: ResourceUtilizationDetail;
    workersCpuTime: ResourceUtilizationDetail;
    d1Reads: ResourceUtilizationDetail;
    d1Writes: ResourceUtilizationDetail;
    kvReads: ResourceUtilizationDetail;
    kvWrites: ResourceUtilizationDetail;
    r2Storage: ResourceUtilizationDetail;
  };
}

export interface PrivacyComplianceAudit {
  nepalPrivacyAct2075Compliant: boolean;
  gdprCompliant: boolean;
  audioNeverLeavesPhone: boolean;
  zeroAdvertisingRankBias: boolean;
  childrenCalorieFree: boolean;
  dataRetentionDaysSpecified: boolean;
  dataExportSupported: boolean;
  accountErasureSupported: boolean;
}

export interface PrivacyComplianceResult {
  passesGate: boolean;
  checklist: Record<string, boolean>;
  failingItems: string[];
}

export interface BetaHouseholdActivity {
  householdId: string;
  enrolledAt: string;
  completedCookingSessionsLast7Days: number;
  totalAppOpensLast7Days: number;
}

export interface WeeklyCookingRateResult {
  totalBetaHouseholds: number;
  activeCookingHouseholds: number;
  weeklyCookingRate: number; // e.g. 0.45
  weeklyCookingPercentage: number; // 45.0
  passesGate: boolean; // >= 0.40
}

export interface LaunchGateReport {
  evaluatedAt: string;
  readyForOpenBeta: boolean;
  passedGatesCount: number;
  totalGatesCount: number;
  gates: {
    crashFreeSessions: CrashFreeResult;
    cloudflareFreeTier: CloudflareFreeTierResult;
    privacyCompliance: PrivacyComplianceResult;
    weeklyCookingRate: WeeklyCookingRateResult;
  };
  remediationPlan: string[];
}

export class LaunchGateMonitor {
  // Cloudflare Free Tier Daily Limits
  static readonly CF_LIMITS = {
    WORKERS_REQUESTS_DAILY: 100000,
    WORKERS_CPU_MS_MAX: 10,
    D1_READS_DAILY: 166666, // 5M per 30-day month
    D1_WRITES_DAILY: 100000,
    KV_READS_DAILY: 100000,
    KV_WRITES_DAILY: 1000,
    R2_STORAGE_GB: 10,
  } as const;

  static readonly THRESHOLDS = {
    MIN_CRASH_FREE_RATE: 0.995, // 99.5%
    MAX_CF_UTILIZATION_RATE: 0.70, // 70% threshold
    MIN_WEEKLY_COOKING_RATE: 0.40, // 40%
  } as const;

  /**
   * Gate 1: Evaluate Crash-Free User Sessions
   * Formula: (totalSessions - crashedSessions) / totalSessions >= 0.995
   */
  static evaluateCrashFreeRate(metrics: CrashFreeMetrics): CrashFreeResult {
    const total = Math.max(0, metrics.totalSessions);
    const crashed = Math.min(total, Math.max(0, metrics.crashedSessions));

    if (total === 0) {
      return {
        totalSessions: 0,
        crashedSessions: 0,
        crashFreeRate: 1.0,
        crashFreePercentage: 100.0,
        passesGate: true,
        remainingCrashBudget: 0,
      };
    }

    const crashFreeRate = (total - crashed) / total;
    const crashFreePercentage = Math.round(crashFreeRate * 10000) / 100;
    const passesGate = crashFreeRate >= this.THRESHOLDS.MIN_CRASH_FREE_RATE;

    // Remaining crashes allowed before dropping below 99.5%
    const maxAllowedCrashes = Math.floor(total * (1 - this.THRESHOLDS.MIN_CRASH_FREE_RATE));
    const remainingCrashBudget = Math.max(0, maxAllowedCrashes - crashed);

    return {
      totalSessions: total,
      crashedSessions: crashed,
      crashFreeRate: Math.round(crashFreeRate * 10000) / 10000,
      crashFreePercentage,
      passesGate,
      remainingCrashBudget,
    };
  }

  /**
   * Helper to evaluate single Cloudflare resource utilization
   */
  private static assessResource(current: number, limit: number): ResourceUtilizationDetail {
    const safeCurrent = Math.max(0, current);
    const safeLimit = Math.max(1, limit);
    const rate = safeCurrent / safeLimit;
    const percentage = Math.round(rate * 1000) / 10;

    let severity: AlertSeverity = 'HEALTHY';
    if (rate >= 0.90) {
      severity = 'CRITICAL';
    } else if (rate >= this.THRESHOLDS.MAX_CF_UTILIZATION_RATE) {
      severity = 'ALERT';
    } else if (rate >= 0.50) {
      severity = 'WARNING';
    } else if (rate >= 0.30) {
      severity = 'NOTICE';
    }

    return {
      current: safeCurrent,
      limit: safeLimit,
      utilizationRate: Math.round(rate * 10000) / 10000,
      utilizationPercentage: percentage,
      severity,
      alertTriggered: rate >= this.THRESHOLDS.MAX_CF_UTILIZATION_RATE,
    };
  }

  /**
   * Gate 2: Evaluate Cloudflare Free-Tier Utilization
   * Flags alerts if any resource utilization is >= 70% of free limits.
   */
  static evaluateCloudflareFreeTierUtilization(usage: CloudflareResourceUsage): CloudflareFreeTierResult {
    const resources = {
      workersRequests: this.assessResource(usage.workersRequestsDaily, this.CF_LIMITS.WORKERS_REQUESTS_DAILY),
      workersCpuTime: this.assessResource(usage.workersCpuTimeMsAvg, this.CF_LIMITS.WORKERS_CPU_MS_MAX),
      d1Reads: this.assessResource(usage.d1ReadsDaily, this.CF_LIMITS.D1_READS_DAILY),
      d1Writes: this.assessResource(usage.d1WritesDaily, this.CF_LIMITS.D1_WRITES_DAILY),
      kvReads: this.assessResource(usage.kvReadsDaily, this.CF_LIMITS.KV_READS_DAILY),
      kvWrites: this.assessResource(usage.kvWritesDaily, this.CF_LIMITS.KV_WRITES_DAILY),
      r2Storage: this.assessResource(usage.r2StorageGb, this.CF_LIMITS.R2_STORAGE_GB),
    };

    const alerts: string[] = [];
    let maxUtilizationRate = 0;
    let highestResource = 'workersRequests';

    for (const [key, res] of Object.entries(resources)) {
      if (res.utilizationRate > maxUtilizationRate) {
        maxUtilizationRate = res.utilizationRate;
        highestResource = key;
      }
      if (res.alertTriggered) {
        alerts.push(
          `Resource [${key}] exceeded 70% free-tier threshold: ${res.utilizationPercentage}% (${res.current} / ${res.limit}) [${res.severity}]`
        );
      }
    }

    const passesGate = alerts.length === 0;

    return {
      passesGate,
      maxUtilizationRate,
      highestResource,
      alerts,
      resources,
    };
  }

  /**
   * Gate 3: Evaluate Privacy & Regulatory Compliance (Nepal Privacy Act 2075 & GDPR)
   */
  static evaluatePrivacyCompliance(audit: PrivacyComplianceAudit): PrivacyComplianceResult {
    const checklist: Record<string, boolean> = {
      'Nepal Individual Privacy Act 2075 Compliance': audit.nepalPrivacyAct2075Compliant,
      'EU GDPR Articles 12-23 (Access, Rectification, Erasure)': audit.gdprCompliant,
      '100% On-Device Acoustic Processing (Zero Audio Transmission)': audit.audioNeverLeavesPhone,
      'Zero Advertising & Sponsored Merchant Rank Bias': audit.zeroAdvertisingRankBias,
      'Pediatric Calorie Shielding (Zero Calorie Displays for Children)': audit.childrenCalorieFree,
      'Transparent Data Retention Limits': audit.dataRetentionDaysSpecified,
      'Data Portability (Self-Serve Export in JSON/CSV)': audit.dataExportSupported,
      'Right to Erasure (One-Tap Household Deletion)': audit.accountErasureSupported,
    };

    const failingItems: string[] = [];
    for (const [key, passed] of Object.entries(checklist)) {
      if (!passed) {
        failingItems.push(key);
      }
    }

    return {
      passesGate: failingItems.length === 0,
      checklist,
      failingItems,
    };
  }

  /**
   * Gate 4: Evaluate Weekly Cooking Rate in Closed Beta Cohort
   * Formula: (Households with >=1 completed cooking session in last 7 days) / total households >= 0.40
   */
  static evaluateWeeklyCookingRate(households: BetaHouseholdActivity[]): WeeklyCookingRateResult {
    const total = households.length;
    if (total === 0) {
      return {
        totalBetaHouseholds: 0,
        activeCookingHouseholds: 0,
        weeklyCookingRate: 0.0,
        weeklyCookingPercentage: 0.0,
        passesGate: false,
      };
    }

    const activeCookingCount = households.filter(
      (h) => h.completedCookingSessionsLast7Days >= 1
    ).length;

    const rate = activeCookingCount / total;
    const percentage = Math.round(rate * 1000) / 10;
    const passesGate = rate >= this.THRESHOLDS.MIN_WEEKLY_COOKING_RATE;

    return {
      totalBetaHouseholds: total,
      activeCookingHouseholds: activeCookingCount,
      weeklyCookingRate: Math.round(rate * 10000) / 10000,
      weeklyCookingPercentage: percentage,
      passesGate,
    };
  }

  /**
   * Complete Open Beta Launch Gate Evaluation
   */
  static evaluateLaunchGate(params: {
    crashFree: CrashFreeMetrics;
    cloudflareUsage: CloudflareResourceUsage;
    privacyAudit: PrivacyComplianceAudit;
    betaHouseholds: BetaHouseholdActivity[];
  }): LaunchGateReport {
    const crashFree = this.evaluateCrashFreeRate(params.crashFree);
    const cloudflareFreeTier = this.evaluateCloudflareFreeTierUtilization(params.cloudflareUsage);
    const privacyCompliance = this.evaluatePrivacyCompliance(params.privacyAudit);
    const weeklyCookingRate = this.evaluateWeeklyCookingRate(params.betaHouseholds);

    const remediationPlan: string[] = [];

    if (!crashFree.passesGate) {
      remediationPlan.push(
        `CRITICAL: Crash-free rate is ${crashFree.crashFreePercentage}% (target >= 99.5%). Investigate top native crashes before public launch.`
      );
    }

    if (!cloudflareFreeTier.passesGate) {
      remediationPlan.push(
        `ALERT: Cloudflare free-tier utilization exceeded 70% threshold (${cloudflareFreeTier.alerts.join('; ')}). Optimize client caching or delta-sync frequency.`
      );
    }

    if (!privacyCompliance.passesGate) {
      remediationPlan.push(
        `LEGAL: Unresolved privacy compliance items: ${privacyCompliance.failingItems.join(', ')}. Must resolve before public distribution.`
      );
    }

    if (!weeklyCookingRate.passesGate) {
      remediationPlan.push(
        `ENGAGEMENT: Active weekly cooking rate is ${weeklyCookingRate.weeklyCookingPercentage}% (target >= 40.0%). Boost kitchen reminders and seasonal meal suggestions.`
      );
    }

    const gatesPassed = [
      crashFree.passesGate,
      cloudflareFreeTier.passesGate,
      privacyCompliance.passesGate,
      weeklyCookingRate.passesGate,
    ];

    const passedCount = gatesPassed.filter(Boolean).length;
    const readyForOpenBeta = passedCount === 4;

    return {
      evaluatedAt: new Date().toISOString(),
      readyForOpenBeta,
      passedGatesCount: passedCount,
      totalGatesCount: 4,
      gates: {
        crashFreeSessions: crashFree,
        cloudflareFreeTier,
        privacyCompliance,
        weeklyCookingRate,
      },
      remediationPlan,
    };
  }
}
