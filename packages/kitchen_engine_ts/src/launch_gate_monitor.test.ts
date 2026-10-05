import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  LaunchGateMonitor,
  type CrashFreeMetrics,
  type CloudflareResourceUsage,
  type PrivacyComplianceAudit,
  type BetaHouseholdActivity,
} from './launch_gate_monitor.js';

describe('LaunchGateMonitor - Week 24 Launch Gate Verification', () => {
  describe('Gate 1: Crash-Free User Sessions (>= 99.5%)', () => {
    it('passes when crash-free rate exceeds 99.5% (e.g. 99.8%)', () => {
      const metrics: CrashFreeMetrics = {
        totalSessions: 10000,
        crashedSessions: 20, // 99.8% crash-free
      };

      const result = LaunchGateMonitor.evaluateCrashFreeRate(metrics);
      assert.equal(result.passesGate, true);
      assert.equal(result.crashFreeRate, 0.998);
      assert.equal(result.crashFreePercentage, 99.8);
      assert.equal(result.remainingCrashBudget, 30); // 50 allowed max (0.5% of 10000) - 20 = 30
    });

    it('fails when crash-free rate falls below 99.5% (e.g. 99.2%)', () => {
      const metrics: CrashFreeMetrics = {
        totalSessions: 1000,
        crashedSessions: 8, // 99.2% crash-free
      };

      const result = LaunchGateMonitor.evaluateCrashFreeRate(metrics);
      assert.equal(result.passesGate, false);
      assert.equal(result.crashFreeRate, 0.992);
      assert.equal(result.crashFreePercentage, 99.2);
      assert.equal(result.remainingCrashBudget, 0);
    });

    it('handles zero sessions gracefully with passing default', () => {
      const result = LaunchGateMonitor.evaluateCrashFreeRate({
        totalSessions: 0,
        crashedSessions: 0,
      });
      assert.equal(result.passesGate, true);
      assert.equal(result.crashFreeRate, 1.0);
    });
  });

  describe('Gate 2: Cloudflare Free-Tier Utilization (< 70% with automated alerts)', () => {
    it('passes when all resources operate below 70% threshold', () => {
      const usage: CloudflareResourceUsage = {
        workersRequestsDaily: 42000, // 42% of 100k
        workersCpuTimeMsAvg: 3.5, // 35% of 10ms
        d1ReadsDaily: 50000, // 30% of 166.6k
        d1WritesDaily: 25000, // 25% of 100k
        kvReadsDaily: 20000, // 20% of 100k
        kvWritesDaily: 400, // 40% of 1k
        r2StorageGb: 3.2, // 32% of 10GB
      };

      const result = LaunchGateMonitor.evaluateCloudflareFreeTierUtilization(usage);
      assert.equal(result.passesGate, true);
      assert.equal(result.alerts.length, 0);
      assert.ok(result.maxUtilizationRate < 0.70);
      assert.equal(result.resources.workersRequests.severity, 'NOTICE');
    });

    it('triggers automated alert when any resource exceeds 70%', () => {
      const usage: CloudflareResourceUsage = {
        workersRequestsDaily: 76000, // 76% (EXCEEDS 70%)
        workersCpuTimeMsAvg: 4.0,
        d1ReadsDaily: 40000,
        d1WritesDaily: 20000,
        kvReadsDaily: 15000,
        kvWritesDaily: 300,
        r2StorageGb: 2.0,
      };

      const result = LaunchGateMonitor.evaluateCloudflareFreeTierUtilization(usage);
      assert.equal(result.passesGate, false);
      assert.equal(result.alerts.length, 1);
      assert.match(result.alerts[0], /workersRequests.*exceeded 70%/);
      assert.equal(result.resources.workersRequests.alertTriggered, true);
      assert.equal(result.resources.workersRequests.severity, 'ALERT');
    });

    it('classifies severity as CRITICAL if utilization reaches 90%+', () => {
      const usage: CloudflareResourceUsage = {
        workersRequestsDaily: 20000,
        workersCpuTimeMsAvg: 2.0,
        d1ReadsDaily: 155000, // 93% of 166.6k
        d1WritesDaily: 10000,
        kvReadsDaily: 5000,
        kvWritesDaily: 100,
        r2StorageGb: 1.0,
      };

      const result = LaunchGateMonitor.evaluateCloudflareFreeTierUtilization(usage);
      assert.equal(result.passesGate, false);
      assert.equal(result.resources.d1Reads.severity, 'CRITICAL');
    });
  });

  describe('Gate 3: Privacy Policy & Regulatory Compliance', () => {
    it('passes when all regulatory and ethical safety standards are met', () => {
      const audit: PrivacyComplianceAudit = {
        nepalPrivacyAct2075Compliant: true,
        gdprCompliant: true,
        audioNeverLeavesPhone: true,
        zeroAdvertisingRankBias: true,
        childrenCalorieFree: true,
        dataRetentionDaysSpecified: true,
        dataExportSupported: true,
        accountErasureSupported: true,
      };

      const result = LaunchGateMonitor.evaluatePrivacyCompliance(audit);
      assert.equal(result.passesGate, true);
      assert.equal(result.failingItems.length, 0);
    });

    it('fails if biometric/audio leaves phone or advertising rank bias is present', () => {
      const audit: PrivacyComplianceAudit = {
        nepalPrivacyAct2075Compliant: true,
        gdprCompliant: true,
        audioNeverLeavesPhone: false, // VIOLATION
        zeroAdvertisingRankBias: false, // VIOLATION
        childrenCalorieFree: true,
        dataRetentionDaysSpecified: true,
        dataExportSupported: true,
        accountErasureSupported: true,
      };

      const result = LaunchGateMonitor.evaluatePrivacyCompliance(audit);
      assert.equal(result.passesGate, false);
      assert.equal(result.failingItems.length, 2);
    });
  });

  describe('Gate 4: Active Weekly Cooking Rate (>= 40%)', () => {
    it('passes when >= 40% of beta households cook during rolling 7-day period', () => {
      const betaCohort: BetaHouseholdActivity[] = [
        { householdId: 'h1', enrolledAt: '2026-09-01', completedCookingSessionsLast7Days: 4, totalAppOpensLast7Days: 12 },
        { householdId: 'h2', enrolledAt: '2026-09-02', completedCookingSessionsLast7Days: 2, totalAppOpensLast7Days: 6 },
        { householdId: 'h3', enrolledAt: '2026-09-03', completedCookingSessionsLast7Days: 0, totalAppOpensLast7Days: 2 },
        { householdId: 'h4', enrolledAt: '2026-09-04', completedCookingSessionsLast7Days: 1, totalAppOpensLast7Days: 5 },
        { householdId: 'h5', enrolledAt: '2026-09-05', completedCookingSessionsLast7Days: 0, totalAppOpensLast7Days: 1 },
      ]; // 3 out of 5 active = 60%

      const result = LaunchGateMonitor.evaluateWeeklyCookingRate(betaCohort);
      assert.equal(result.passesGate, true);
      assert.equal(result.totalBetaHouseholds, 5);
      assert.equal(result.activeCookingHouseholds, 3);
      assert.equal(result.weeklyCookingRate, 0.6);
      assert.equal(result.weeklyCookingPercentage, 60.0);
    });

    it('fails when active cooking rate is below 40%', () => {
      const betaCohort: BetaHouseholdActivity[] = [
        { householdId: 'h1', enrolledAt: '2026-09-01', completedCookingSessionsLast7Days: 3, totalAppOpensLast7Days: 8 },
        { householdId: 'h2', enrolledAt: '2026-09-02', completedCookingSessionsLast7Days: 0, totalAppOpensLast7Days: 2 },
        { householdId: 'h3', enrolledAt: '2026-09-03', completedCookingSessionsLast7Days: 0, totalAppOpensLast7Days: 1 },
        { householdId: 'h4', enrolledAt: '2026-09-04', completedCookingSessionsLast7Days: 0, totalAppOpensLast7Days: 1 },
      ]; // 1 out of 4 = 25%

      const result = LaunchGateMonitor.evaluateWeeklyCookingRate(betaCohort);
      assert.equal(result.passesGate, false);
      assert.equal(result.weeklyCookingRate, 0.25);
      assert.equal(result.weeklyCookingPercentage, 25.0);
    });
  });

  describe('Unified Launch Gate Report', () => {
    it('declares readyForOpenBeta when all 4 gates pass', () => {
      const report = LaunchGateMonitor.evaluateLaunchGate({
        crashFree: { totalSessions: 5000, crashedSessions: 10 }, // 99.8%
        cloudflareUsage: {
          workersRequestsDaily: 35000,
          workersCpuTimeMsAvg: 2.1,
          d1ReadsDaily: 45000,
          d1WritesDaily: 20000,
          kvReadsDaily: 15000,
          kvWritesDaily: 200,
          r2StorageGb: 1.5,
        },
        privacyAudit: {
          nepalPrivacyAct2075Compliant: true,
          gdprCompliant: true,
          audioNeverLeavesPhone: true,
          zeroAdvertisingRankBias: true,
          childrenCalorieFree: true,
          dataRetentionDaysSpecified: true,
          dataExportSupported: true,
          accountErasureSupported: true,
        },
        betaHouseholds: [
          { householdId: 'h1', enrolledAt: '2026-09-01', completedCookingSessionsLast7Days: 3, totalAppOpensLast7Days: 7 },
          { householdId: 'h2', enrolledAt: '2026-09-02', completedCookingSessionsLast7Days: 1, totalAppOpensLast7Days: 4 },
        ],
      });

      assert.equal(report.readyForOpenBeta, true);
      assert.equal(report.passedGatesCount, 4);
      assert.equal(report.totalGatesCount, 4);
      assert.equal(report.remediationPlan.length, 0);
    });

    it('generates actionable remediation items when gates fail', () => {
      const report = LaunchGateMonitor.evaluateLaunchGate({
        crashFree: { totalSessions: 1000, crashedSessions: 12 }, // 98.8% (FAILS)
        cloudflareUsage: {
          workersRequestsDaily: 85000, // 85% (FAILS)
          workersCpuTimeMsAvg: 2.1,
          d1ReadsDaily: 45000,
          d1WritesDaily: 20000,
          kvReadsDaily: 15000,
          kvWritesDaily: 200,
          r2StorageGb: 1.5,
        },
        privacyAudit: {
          nepalPrivacyAct2075Compliant: false, // FAILS
          gdprCompliant: true,
          audioNeverLeavesPhone: true,
          zeroAdvertisingRankBias: true,
          childrenCalorieFree: true,
          dataRetentionDaysSpecified: true,
          dataExportSupported: true,
          accountErasureSupported: true,
        },
        betaHouseholds: [
          { householdId: 'h1', enrolledAt: '2026-09-01', completedCookingSessionsLast7Days: 0, totalAppOpensLast7Days: 1 },
        ], // 0% (FAILS)
      });

      assert.equal(report.readyForOpenBeta, false);
      assert.equal(report.passedGatesCount, 0);
      assert.equal(report.remediationPlan.length, 4);
      assert.match(report.remediationPlan[0], /CRITICAL: Crash-free rate/);
      assert.match(report.remediationPlan[1], /ALERT: Cloudflare free-tier utilization/);
      assert.match(report.remediationPlan[2], /LEGAL: Unresolved privacy compliance/);
      assert.match(report.remediationPlan[3], /ENGAGEMENT: Active weekly cooking rate/);
    });
  });
});
