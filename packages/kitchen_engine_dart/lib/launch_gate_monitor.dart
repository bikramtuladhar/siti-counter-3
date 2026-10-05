/// Launch Gate Monitor & Verification Engine (Section 28.3)
/// Evaluates the 4 mandatory launch gates for Siti Counter 3.0 Open Beta:
/// 1. Crash-free user sessions >= 99.5%
/// 2. Cloudflare free-tier utilization below 70% with automated alert thresholds
/// 3. Privacy policy and terms compliant with Nepal Privacy Act 2075 and GDPR
/// 4. Active weekly cooking rate >= 40% among closed beta households

enum AlertSeverity {
  healthy,
  notice,
  warning,
  alert,
  critical,
}

class CrashFreeMetrics {
  final int totalSessions;
  final int crashedSessions;

  const CrashFreeMetrics({
    required this.totalSessions,
    required this.crashedSessions,
  });

  Map<String, dynamic> toJson() => {
        'totalSessions': totalSessions,
        'crashedSessions': crashedSessions,
      };
}

class CrashFreeResult {
  final int totalSessions;
  final int crashedSessions;
  final double crashFreeRate; // e.g. 0.998
  final double crashFreePercentage; // 99.8
  final bool passesGate; // >= 0.995
  final int remainingCrashBudget;

  const CrashFreeResult({
    required this.totalSessions,
    required this.crashedSessions,
    required this.crashFreeRate,
    required this.crashFreePercentage,
    required this.passesGate,
    required this.remainingCrashBudget,
  });

  Map<String, dynamic> toJson() => {
        'totalSessions': totalSessions,
        'crashedSessions': crashedSessions,
        'crashFreeRate': crashFreeRate,
        'crashFreePercentage': crashFreePercentage,
        'passesGate': passesGate,
        'remainingCrashBudget': remainingCrashBudget,
      };
}

class CloudflareResourceUsage {
  final int workersRequestsDaily; // Free limit: 100,000 / day
  final double workersCpuTimeMsAvg; // Free threshold: 10 ms / request
  final int d1ReadsDaily; // Free limit: ~166,666 / day (5M / mo)
  final int d1WritesDaily; // Free limit: 100,000 / day
  final int kvReadsDaily; // Free limit: 100,000 / day
  final int kvWritesDaily; // Free limit: 1,000 / day
  final double r2StorageGb; // Free limit: 10 GB

  const CloudflareResourceUsage({
    required this.workersRequestsDaily,
    required this.workersCpuTimeMsAvg,
    required this.d1ReadsDaily,
    required this.d1WritesDaily,
    required this.kvReadsDaily,
    required this.kvWritesDaily,
    required this.r2StorageGb,
  });

  Map<String, dynamic> toJson() => {
        'workersRequestsDaily': workersRequestsDaily,
        'workersCpuTimeMsAvg': workersCpuTimeMsAvg,
        'd1ReadsDaily': d1ReadsDaily,
        'd1WritesDaily': d1WritesDaily,
        'kvReadsDaily': kvReadsDaily,
        'kvWritesDaily': kvWritesDaily,
        'r2StorageGb': r2StorageGb,
      };
}

class ResourceUtilizationDetail {
  final double current;
  final double limit;
  final double utilizationRate;
  final double utilizationPercentage;
  final AlertSeverity severity;
  final bool alertTriggered;

  const ResourceUtilizationDetail({
    required this.current,
    required this.limit,
    required this.utilizationRate,
    required this.utilizationPercentage,
    required this.severity,
    required this.alertTriggered,
  });

  Map<String, dynamic> toJson() => {
        'current': current,
        'limit': limit,
        'utilizationRate': utilizationRate,
        'utilizationPercentage': utilizationPercentage,
        'severity': severity.name.toUpperCase(),
        'alertTriggered': alertTriggered,
      };
}

class CloudflareFreeTierResult {
  final bool passesGate;
  final double maxUtilizationRate;
  final String highestResource;
  final List<String> alerts;
  final Map<String, ResourceUtilizationDetail> resources;

  const CloudflareFreeTierResult({
    required this.passesGate,
    required this.maxUtilizationRate,
    required this.highestResource,
    required this.alerts,
    required this.resources,
  });

  Map<String, dynamic> toJson() => {
        'passesGate': passesGate,
        'maxUtilizationRate': maxUtilizationRate,
        'highestResource': highestResource,
        'alerts': alerts,
        'resources': resources.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class PrivacyComplianceAudit {
  final bool nepalPrivacyAct2075Compliant;
  final bool gdprCompliant;
  final bool audioNeverLeavesPhone;
  final bool zeroAdvertisingRankBias;
  final bool childrenCalorieFree;
  final bool dataRetentionDaysSpecified;
  final bool dataExportSupported;
  final bool accountErasureSupported;

  const PrivacyComplianceAudit({
    required this.nepalPrivacyAct2075Compliant,
    required this.gdprCompliant,
    required this.audioNeverLeavesPhone,
    required this.zeroAdvertisingRankBias,
    required this.childrenCalorieFree,
    required this.dataRetentionDaysSpecified,
    required this.dataExportSupported,
    required this.accountErasureSupported,
  });

  Map<String, dynamic> toJson() => {
        'nepalPrivacyAct2075Compliant': nepalPrivacyAct2075Compliant,
        'gdprCompliant': gdprCompliant,
        'audioNeverLeavesPhone': audioNeverLeavesPhone,
        'zeroAdvertisingRankBias': zeroAdvertisingRankBias,
        'childrenCalorieFree': childrenCalorieFree,
        'dataRetentionDaysSpecified': dataRetentionDaysSpecified,
        'dataExportSupported': dataExportSupported,
        'accountErasureSupported': accountErasureSupported,
      };
}

class PrivacyComplianceResult {
  final bool passesGate;
  final Map<String, bool> checklist;
  final List<String> failingItems;

  const PrivacyComplianceResult({
    required this.passesGate,
    required this.checklist,
    required this.failingItems,
  });

  Map<String, dynamic> toJson() => {
        'passesGate': passesGate,
        'checklist': checklist,
        'failingItems': failingItems,
      };
}

class BetaHouseholdActivity {
  final String householdId;
  final String enrolledAt;
  final int completedCookingSessionsLast7Days;
  final int totalAppOpensLast7Days;

  const BetaHouseholdActivity({
    required this.householdId,
    required this.enrolledAt,
    required this.completedCookingSessionsLast7Days,
    required this.totalAppOpensLast7Days,
  });

  Map<String, dynamic> toJson() => {
        'householdId': householdId,
        'enrolledAt': enrolledAt,
        'completedCookingSessionsLast7Days': completedCookingSessionsLast7Days,
        'totalAppOpensLast7Days': totalAppOpensLast7Days,
      };
}

class WeeklyCookingRateResult {
  final int totalBetaHouseholds;
  final int activeCookingHouseholds;
  final double weeklyCookingRate;
  final double weeklyCookingPercentage;
  final bool passesGate;

  const WeeklyCookingRateResult({
    required this.totalBetaHouseholds,
    required this.activeCookingHouseholds,
    required this.weeklyCookingRate,
    required this.weeklyCookingPercentage,
    required this.passesGate,
  });

  Map<String, dynamic> toJson() => {
        'totalBetaHouseholds': totalBetaHouseholds,
        'activeCookingHouseholds': activeCookingHouseholds,
        'weeklyCookingRate': weeklyCookingRate,
        'weeklyCookingPercentage': weeklyCookingPercentage,
        'passesGate': passesGate,
      };
}

class LaunchGateReport {
  final String evaluatedAt;
  final bool readyForOpenBeta;
  final int passedGatesCount;
  final int totalGatesCount;
  final CrashFreeResult crashFreeSessions;
  final CloudflareFreeTierResult cloudflareFreeTier;
  final PrivacyComplianceResult privacyCompliance;
  final WeeklyCookingRateResult weeklyCookingRate;
  final List<String> remediationPlan;

  const LaunchGateReport({
    required this.evaluatedAt,
    required this.readyForOpenBeta,
    required this.passedGatesCount,
    required this.totalGatesCount,
    required this.crashFreeSessions,
    required this.cloudflareFreeTier,
    required this.privacyCompliance,
    required this.weeklyCookingRate,
    required this.remediationPlan,
  });

  Map<String, dynamic> toJson() => {
        'evaluatedAt': evaluatedAt,
        'readyForOpenBeta': readyForOpenBeta,
        'passedGatesCount': passedGatesCount,
        'totalGatesCount': totalGatesCount,
        'gates': {
          'crashFreeSessions': crashFreeSessions.toJson(),
          'cloudflareFreeTier': cloudflareFreeTier.toJson(),
          'privacyCompliance': privacyCompliance.toJson(),
          'weeklyCookingRate': weeklyCookingRate.toJson(),
        },
        'remediationPlan': remediationPlan,
      };
}

class LaunchGateMonitor {
  static const int cfWorkersRequestsDailyLimit = 100000;
  static const double cfWorkersCpuMsMax = 10.0;
  static const int cfD1ReadsDailyLimit = 166666;
  static const int cfD1WritesDailyLimit = 100000;
  static const int cfKvReadsDailyLimit = 100000;
  static const int cfKvWritesDailyLimit = 1000;
  static const double cfR2StorageGbLimit = 10.0;

  static const double minCrashFreeRate = 0.995;
  static const double maxCfUtilizationRate = 0.70;
  static const double minWeeklyCookingRate = 0.40;

  /// Gate 1: Evaluate Crash-Free User Sessions
  static CrashFreeResult evaluateCrashFreeRate(CrashFreeMetrics metrics) {
    final total = metrics.totalSessions < 0 ? 0 : metrics.totalSessions;
    final crashed = metrics.crashedSessions < 0
        ? 0
        : (metrics.crashedSessions > total ? total : metrics.crashedSessions);

    if (total == 0) {
      return const CrashFreeResult(
        totalSessions: 0,
        crashedSessions: 0,
        crashFreeRate: 1.0,
        crashFreePercentage: 100.0,
        passesGate: true,
        remainingCrashBudget: 0,
      );
    }

    final rate = (total - crashed) / total;
    final percentage = (rate * 10000).round() / 100.0;
    final passes = rate >= minCrashFreeRate;

    final maxAllowedCrashes = (total * (1.0 - minCrashFreeRate)).floor();
    final remainingBudget = maxAllowedCrashes > crashed ? maxAllowedCrashes - crashed : 0;

    return CrashFreeResult(
      totalSessions: total,
      crashedSessions: crashed,
      crashFreeRate: (rate * 10000).round() / 10000.0,
      crashFreePercentage: percentage,
      passesGate: passes,
      remainingCrashBudget: remainingBudget,
    );
  }

  static ResourceUtilizationDetail _assessResource(double current, double limit) {
    final safeCurrent = current < 0 ? 0.0 : current;
    final safeLimit = limit <= 0 ? 1.0 : limit;
    final rate = safeCurrent / safeLimit;
    final percentage = (rate * 1000).round() / 10.0;

    AlertSeverity severity = AlertSeverity.healthy;
    if (rate >= 0.90) {
      severity = AlertSeverity.critical;
    } else if (rate >= maxCfUtilizationRate) {
      severity = AlertSeverity.alert;
    } else if (rate >= 0.50) {
      severity = AlertSeverity.warning;
    } else if (rate >= 0.30) {
      severity = AlertSeverity.notice;
    }

    return ResourceUtilizationDetail(
      current: safeCurrent,
      limit: safeLimit,
      utilizationRate: (rate * 10000).round() / 10000.0,
      utilizationPercentage: percentage,
      severity: severity,
      alertTriggered: rate >= maxCfUtilizationRate,
    );
  }

  /// Gate 2: Evaluate Cloudflare Free-Tier Utilization
  static CloudflareFreeTierResult evaluateCloudflareFreeTierUtilization(
      CloudflareResourceUsage usage) {
    final resources = {
      'workersRequests': _assessResource(
          usage.workersRequestsDaily.toDouble(), cfWorkersRequestsDailyLimit.toDouble()),
      'workersCpuTime': _assessResource(usage.workersCpuTimeMsAvg, cfWorkersCpuMsMax),
      'd1Reads': _assessResource(usage.d1ReadsDaily.toDouble(), cfD1ReadsDailyLimit.toDouble()),
      'd1Writes': _assessResource(usage.d1WritesDaily.toDouble(), cfD1WritesDailyLimit.toDouble()),
      'kvReads': _assessResource(usage.kvReadsDaily.toDouble(), cfKvReadsDailyLimit.toDouble()),
      'kvWrites': _assessResource(usage.kvWritesDaily.toDouble(), cfKvWritesDailyLimit.toDouble()),
      'r2Storage': _assessResource(usage.r2StorageGb, cfR2StorageGbLimit),
    };

    final alerts = <String>[];
    double maxRate = 0.0;
    String highestResource = 'workersRequests';

    resources.forEach((key, res) {
      if (res.utilizationRate > maxRate) {
        maxRate = res.utilizationRate;
        highestResource = key;
      }
      if (res.alertTriggered) {
        alerts.add(
            'Resource [$key] exceeded 70% free-tier threshold: ${res.utilizationPercentage}% (${res.current.toInt()} / ${res.limit.toInt()}) [${res.severity.name.toUpperCase()}]');
      }
    });

    return CloudflareFreeTierResult(
      passesGate: alerts.isEmpty,
      maxUtilizationRate: maxRate,
      highestResource: highestResource,
      alerts: alerts,
      resources: resources,
    );
  }

  /// Gate 3: Evaluate Privacy & Regulatory Compliance
  static PrivacyComplianceResult evaluatePrivacyCompliance(PrivacyComplianceAudit audit) {
    final checklist = <String, bool>{
      'Nepal Individual Privacy Act 2075 Compliance': audit.nepalPrivacyAct2075Compliant,
      'EU GDPR Articles 12-23 (Access, Rectification, Erasure)': audit.gdprCompliant,
      '100% On-Device Acoustic Processing (Zero Audio Transmission)': audit.audioNeverLeavesPhone,
      'Zero Advertising & Sponsored Merchant Rank Bias': audit.zeroAdvertisingRankBias,
      'Pediatric Calorie Shielding (Zero Calorie Displays for Children)': audit.childrenCalorieFree,
      'Transparent Data Retention Limits': audit.dataRetentionDaysSpecified,
      'Data Portability (Self-Serve Export in JSON/CSV)': audit.dataExportSupported,
      'Right to Erasure (One-Tap Household Deletion)': audit.accountErasureSupported,
    };

    final failing = <String>[];
    checklist.forEach((item, passed) {
      if (!passed) {
        failing.add(item);
      }
    });

    return PrivacyComplianceResult(
      passesGate: failing.isEmpty,
      checklist: checklist,
      failingItems: failing,
    );
  }

  /// Gate 4: Evaluate Weekly Cooking Rate in Closed Beta Cohort
  static WeeklyCookingRateResult evaluateWeeklyCookingRate(
      List<BetaHouseholdActivity> households) {
    final total = households.length;
    if (total == 0) {
      return const WeeklyCookingRateResult(
        totalBetaHouseholds: 0,
        activeCookingHouseholds: 0,
        weeklyCookingRate: 0.0,
        weeklyCookingPercentage: 0.0,
        passesGate: false,
      );
    }

    final activeCooking = households
        .where((h) => h.completedCookingSessionsLast7Days >= 1)
        .length;

    final rate = activeCooking / total;
    final percentage = (rate * 1000).round() / 10.0;

    return WeeklyCookingRateResult(
      totalBetaHouseholds: total,
      activeCookingHouseholds: activeCooking,
      weeklyCookingRate: (rate * 10000).round() / 10000.0,
      weeklyCookingPercentage: percentage,
      passesGate: rate >= minWeeklyCookingRate,
    );
  }

  /// Unified Launch Gate Evaluation
  static LaunchGateReport evaluateLaunchGate({
    required CrashFreeMetrics crashFree,
    required CloudflareResourceUsage cloudflareUsage,
    required PrivacyComplianceAudit privacyAudit,
    required List<BetaHouseholdActivity> betaHouseholds,
  }) {
    final crashFreeResult = evaluateCrashFreeRate(crashFree);
    final cfResult = evaluateCloudflareFreeTierUtilization(cloudflareUsage);
    final privacyResult = evaluatePrivacyCompliance(privacyAudit);
    final cookingResult = evaluateWeeklyCookingRate(betaHouseholds);

    final remediation = <String>[];

    if (!crashFreeResult.passesGate) {
      remediation.add(
          'CRITICAL: Crash-free rate is ${crashFreeResult.crashFreePercentage}% (target >= 99.5%). Investigate top native crashes before public launch.');
    }
    if (!cfResult.passesGate) {
      remediation.add(
          'ALERT: Cloudflare free-tier utilization exceeded 70% threshold (${cfResult.alerts.join('; ')}). Optimize client caching or delta-sync frequency.');
    }
    if (!privacyResult.passesGate) {
      remediation.add(
          'LEGAL: Unresolved privacy compliance items: ${privacyResult.failingItems.join(', ')}. Must resolve before public distribution.');
    }
    if (!cookingResult.passesGate) {
      remediation.add(
          'ENGAGEMENT: Active weekly cooking rate is ${cookingResult.weeklyCookingPercentage}% (target >= 40.0%). Boost kitchen reminders and seasonal meal suggestions.');
    }

    final gatesPassed = [
      crashFreeResult.passesGate,
      cfResult.passesGate,
      privacyResult.passesGate,
      cookingResult.passesGate,
    ];

    final passedCount = gatesPassed.where((p) => p).length;

    return LaunchGateReport(
      evaluatedAt: DateTime.now().toUtc().toIso8601String(),
      readyForOpenBeta: passedCount == 4,
      passedGatesCount: passedCount,
      totalGatesCount: 4,
      crashFreeSessions: crashFreeResult,
      cloudflareFreeTier: cfResult,
      privacyCompliance: privacyResult,
      weeklyCookingRate: cookingResult,
      remediationPlan: remediation,
    );
  }
}
