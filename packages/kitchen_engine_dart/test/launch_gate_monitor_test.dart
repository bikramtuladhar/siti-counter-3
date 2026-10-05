import 'package:test/test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

void main() {
  group('LaunchGateMonitor Dart Parity Tests', () {
    group('Gate 1: Crash-Free User Sessions (>= 99.5%)', () {
      test('passes when crash-free rate meets or exceeds 99.5%', () {
        const metrics = CrashFreeMetrics(
          totalSessions: 10000,
          crashedSessions: 20, // 99.8% crash-free
        );

        final result = LaunchGateMonitor.evaluateCrashFreeRate(metrics);
        expect(result.passesGate, isTrue);
        expect(result.crashFreeRate, equals(0.998));
        expect(result.crashFreePercentage, equals(99.8));
        expect(result.remainingCrashBudget, equals(30));
      });

      test('fails when crash-free rate drops below 99.5%', () {
        const metrics = CrashFreeMetrics(
          totalSessions: 1000,
          crashedSessions: 10, // 99.0% crash-free
        );

        final result = LaunchGateMonitor.evaluateCrashFreeRate(metrics);
        expect(result.passesGate, isFalse);
        expect(result.crashFreeRate, equals(0.99));
        expect(result.crashFreePercentage, equals(99.0));
        expect(result.remainingCrashBudget, equals(0));
      });

      test('handles zero sessions gracefully', () {
        const metrics = CrashFreeMetrics(
          totalSessions: 0,
          crashedSessions: 0,
        );

        final result = LaunchGateMonitor.evaluateCrashFreeRate(metrics);
        expect(result.passesGate, isTrue);
        expect(result.crashFreeRate, equals(1.0));
      });
    });

    group('Gate 2: Cloudflare Free-Tier Utilization (< 70% alert threshold)', () {
      test('passes when all metrics stay below 70% threshold', () {
        const usage = CloudflareResourceUsage(
          workersRequestsDaily: 45000, // 45% of 100k
          workersCpuTimeMsAvg: 3.2, // 32% of 10ms
          d1ReadsDaily: 50000, // 30% of 166.6k
          d1WritesDaily: 30000, // 30% of 100k
          kvReadsDaily: 25000, // 25% of 100k
          kvWritesDaily: 300, // 30% of 1k
          r2StorageGb: 3.0, // 30% of 10GB
        );

        final result = LaunchGateMonitor.evaluateCloudflareFreeTierUtilization(usage);
        expect(result.passesGate, isTrue);
        expect(result.alerts, isEmpty);
        expect(result.maxUtilizationRate, lessThan(0.70));
        expect(result.resources['workersRequests']?.severity, equals(AlertSeverity.notice));
      });

      test('triggers alert when a resource crosses 70%', () {
        const usage = CloudflareResourceUsage(
          workersRequestsDaily: 75000, // 75% -> ALERT
          workersCpuTimeMsAvg: 3.0,
          d1ReadsDaily: 40000,
          d1WritesDaily: 20000,
          kvReadsDaily: 10000,
          kvWritesDaily: 200,
          r2StorageGb: 2.0,
        );

        final result = LaunchGateMonitor.evaluateCloudflareFreeTierUtilization(usage);
        expect(result.passesGate, isFalse);
        expect(result.alerts.length, equals(1));
        expect(result.resources['workersRequests']?.alertTriggered, isTrue);
        expect(result.resources['workersRequests']?.severity, equals(AlertSeverity.alert));
      });
    });

    group('Gate 3: Privacy Policy & Regulatory Compliance', () {
      test('passes with complete audit compliance', () {
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
      });

      test('flags any compliance violations', () {
        const audit = PrivacyComplianceAudit(
          nepalPrivacyAct2075Compliant: true,
          gdprCompliant: false, // VIOLATION
          audioNeverLeavesPhone: true,
          zeroAdvertisingRankBias: true,
          childrenCalorieFree: true,
          dataRetentionDaysSpecified: true,
          dataExportSupported: true,
          accountErasureSupported: false, // VIOLATION
        );

        final result = LaunchGateMonitor.evaluatePrivacyCompliance(audit);
        expect(result.passesGate, isFalse);
        expect(result.failingItems.length, equals(2));
      });
    });

    group('Gate 4: Active Weekly Cooking Rate (>= 40%)', () {
      test('passes when active weekly cooking cohort is >= 40%', () {
        const cohort = [
          BetaHouseholdActivity(
            householdId: 'h1',
            enrolledAt: '2026-09-01',
            completedCookingSessionsLast7Days: 3,
            totalAppOpensLast7Days: 10,
          ),
          BetaHouseholdActivity(
            householdId: 'h2',
            enrolledAt: '2026-09-02',
            completedCookingSessionsLast7Days: 1,
            totalAppOpensLast7Days: 5,
          ),
          BetaHouseholdActivity(
            householdId: 'h3',
            enrolledAt: '2026-09-03',
            completedCookingSessionsLast7Days: 0,
            totalAppOpensLast7Days: 2,
          ),
        ]; // 2 out of 3 = 66.7%

        final result = LaunchGateMonitor.evaluateWeeklyCookingRate(cohort);
        expect(result.passesGate, isTrue);
        expect(result.weeklyCookingRate, closeTo(0.6667, 0.001));
      });

      test('fails when weekly cooking rate is below 40%', () {
        const cohort = [
          BetaHouseholdActivity(
            householdId: 'h1',
            enrolledAt: '2026-09-01',
            completedCookingSessionsLast7Days: 0,
            totalAppOpensLast7Days: 4,
          ),
          BetaHouseholdActivity(
            householdId: 'h2',
            enrolledAt: '2026-09-02',
            completedCookingSessionsLast7Days: 0,
            totalAppOpensLast7Days: 2,
          ),
          BetaHouseholdActivity(
            householdId: 'h3',
            enrolledAt: '2026-09-03',
            completedCookingSessionsLast7Days: 1,
            totalAppOpensLast7Days: 5,
          ),
        ]; // 1 out of 3 = 33.3%

        final result = LaunchGateMonitor.evaluateWeeklyCookingRate(cohort);
        expect(result.passesGate, isFalse);
        expect(result.weeklyCookingPercentage, equals(33.3));
      });
    });

    group('Unified Launch Gate Report', () {
      test('declares readyForOpenBeta when all 4 gates succeed', () {
        final report = LaunchGateMonitor.evaluateLaunchGate(
          crashFree: const CrashFreeMetrics(totalSessions: 5000, crashedSessions: 10),
          cloudflareUsage: const CloudflareResourceUsage(
            workersRequestsDaily: 30000,
            workersCpuTimeMsAvg: 2.0,
            d1ReadsDaily: 40000,
            d1WritesDaily: 20000,
            kvReadsDaily: 10000,
            kvWritesDaily: 200,
            r2StorageGb: 1.0,
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
          betaHouseholds: const [
            BetaHouseholdActivity(
              householdId: 'h1',
              enrolledAt: '2026-09-01',
              completedCookingSessionsLast7Days: 2,
              totalAppOpensLast7Days: 5,
            ),
          ],
        );

        expect(report.readyForOpenBeta, isTrue);
        expect(report.passedGatesCount, equals(4));
        expect(report.remediationPlan, isEmpty);
      });
    });
  });
}
