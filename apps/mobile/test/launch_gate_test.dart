import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

void main() {
  group('Week 24 Launch Gate End-to-End Verification (Section 28.3)', () {
    test('Gate 1: Crash-free user sessions >= 99.5%', () {
      // 10,000 recorded sessions with 22 crashes = 99.78% crash-free
      const metrics = CrashFreeMetrics(totalSessions: 10000, crashedSessions: 22);
      final result = LaunchGateMonitor.evaluateCrashFreeRate(metrics);

      expect(result.passesGate, isTrue);
      expect(result.crashFreeRate, greaterThanOrEqualTo(0.995));
      expect(result.crashFreePercentage, equals(99.78));
      expect(result.remainingCrashBudget, equals(28));
    });

    test('Gate 2: Cloudflare free-tier utilization strictly below 70%', () {
      // Daily production usage simulation
      const usage = CloudflareResourceUsage(
        workersRequestsDaily: 42000, // 42%
        workersCpuTimeMsAvg: 3.1, // 31%
        d1ReadsDaily: 55000, // 33%
        d1WritesDaily: 28000, // 28%
        kvReadsDaily: 20000, // 20%
        kvWritesDaily: 350, // 35%
        r2StorageGb: 2.5, // 25%
      );

      final result = LaunchGateMonitor.evaluateCloudflareFreeTierUtilization(usage);

      expect(result.passesGate, isTrue);
      expect(result.alerts, isEmpty);
      expect(result.maxUtilizationRate, lessThan(0.70));
    });

    test('Gate 3: Privacy policy & terms compliant with Nepal Privacy Act 2075 and GDPR', () {
      const audit = PrivacyComplianceAudit(
        nepalPrivacyAct2075Compliant: true,
        gdprCompliant: true,
        audioNeverLeavesPhone: true,
        zeroAdvertisingRankBias: true,
        childrenCalorieFree: true,
        dataRetentionDaysSpecified: true,
        dataExportSupported: true,
        accountErasureSupported: true,
      );

      final result = LaunchGateMonitor.evaluatePrivacyCompliance(audit);

      expect(result.passesGate, isTrue);
      expect(result.failingItems, isEmpty);
      expect(result.checklist.values.every((v) => v == true), isTrue);
    });

    test('Gate 4: Active weekly cooking rate >= 40% among closed beta households', () {
      // Closed beta cohort of 20 households across Nepal and Diaspora
      final cohort = List.generate(
        20,
        (i) => BetaHouseholdActivity(
          householdId: 'hh_beta_$i',
          enrolledAt: '2026-09-${(i % 20) + 1}',
          // 12 households cooked >= 1 time in the last 7 days = 60%
          completedCookingSessionsLast7Days: i < 12 ? (i % 4) + 1 : 0,
          totalAppOpensLast7Days: (i % 6) + 3,
        ),
      );

      final result = LaunchGateMonitor.evaluateWeeklyCookingRate(cohort);

      expect(result.passesGate, isTrue);
      expect(result.totalBetaHouseholds, equals(20));
      expect(result.activeCookingHouseholds, equals(12));
      expect(result.weeklyCookingRate, equals(0.60));
      expect(result.weeklyCookingPercentage, equals(60.0));
      expect(result.weeklyCookingRate, greaterThanOrEqualTo(0.40));
    });

    test('Unified Gate Certification approves Open Beta release', () {
      final report = LaunchGateMonitor.evaluateLaunchGate(
        crashFree: const CrashFreeMetrics(totalSessions: 10000, crashedSessions: 22),
        cloudflareUsage: const CloudflareResourceUsage(
          workersRequestsDaily: 42000,
          workersCpuTimeMsAvg: 3.1,
          d1ReadsDaily: 55000,
          d1WritesDaily: 28000,
          kvReadsDaily: 20000,
          kvWritesDaily: 350,
          r2StorageGb: 2.5,
        ),
        privacyAudit: const PrivacyComplianceAudit(
          nepalPrivacyAct2075Compliant: true,
          gdprCompliant: true,
          audioNeverLeavesPhone: true,
          zeroAdvertisingRankBias: true,
          childrenCalorieFree: true,
          dataRetentionDaysSpecified: true,
          dataExportSupported: true,
          accountErasureSupported: true,
        ),
        betaHouseholds: List.generate(
          20,
          (i) => BetaHouseholdActivity(
            householdId: 'hh_beta_$i',
            enrolledAt: '2026-09-01',
            completedCookingSessionsLast7Days: i < 12 ? 2 : 0,
            totalAppOpensLast7Days: 5,
          ),
        ),
      );

      expect(report.readyForOpenBeta, isTrue);
      expect(report.passedGatesCount, equals(4));
      expect(report.totalGatesCount, equals(4));
      expect(report.remediationPlan, isEmpty);
    });
  });
}
