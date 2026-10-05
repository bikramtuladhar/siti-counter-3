import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/telemetry/session_telemetry_service.dart';

void main() {
  group('SessionTelemetryService Mobile Tests', () {
    test('records session and calculates local crash-free rate', () async {
      final service = SessionTelemetryService(
        transport: ({required url, required method, body, headers}) async {
          expect(url, contains('/v1/telemetry/session'));
          expect(method, equals('POST'));
          expect(body?['sessionId'], equals('test-session-001'));
          return {'status': 'recorded'};
        },
      );

      final ok = await service.recordSession(
        sessionId: 'test-session-001',
        durationMs: 300000,
        crashed: false,
      );

      expect(ok, isTrue);

      final stats = service.evaluateLocalCrashFreeRate();
      expect(stats.totalSessions, equals(1));
      expect(stats.crashedSessions, equals(0));
      expect(stats.passesGate, isTrue);
      expect(stats.crashFreeRate, equals(1.0));
    });

    test('fetches Cloudflare free tier budget and alerts from edge', () async {
      final service = SessionTelemetryService(
        transport: ({required url, required method, body, headers}) async {
          expect(url, contains('/v1/telemetry/cf-budget'));
          return {
            'status': 'PASS',
            'evaluation': {
              'passesGate': true,
              'maxUtilizationRate': 0.38,
              'highestResource': 'workersRequests',
              'alerts': <String>[],
              'resources': {
                'workersRequests': {
                  'current': 38000.0,
                  'limit': 100000.0,
                  'utilizationRate': 0.38,
                  'utilizationPercentage': 38.0,
                  'severity': 'NOTICE',
                  'alertTriggered': false,
                },
              },
            },
          };
        },
      );

      final cfResult = await service.fetchCloudflareBudget();
      expect(cfResult, isNotNull);
      expect(cfResult!.passesGate, isTrue);
      expect(cfResult.alerts, isEmpty);
      expect(cfResult.maxUtilizationRate, equals(0.38));
    });

    test('fetches Launch Gate certification status from edge', () async {
      final service = SessionTelemetryService(
        transport: ({required url, required method, body, headers}) async {
          expect(url, contains('/v1/telemetry/launch-gate-status'));
          return {
            'report': {
              'evaluatedAt': '2026-10-05T09:00:00Z',
              'readyForOpenBeta': true,
              'passedGatesCount': 4,
              'totalGatesCount': 4,
              'gates': {
                'crashFreeSessions': {
                  'totalSessions': 5000,
                  'crashedSessions': 8,
                },
              },
              'remediationPlan': <String>[],
            },
          };
        },
      );

      final report = await service.fetchLaunchGateStatus();
      expect(report, isNotNull);
      expect(report!.readyForOpenBeta, isTrue);
      expect(report.passedGatesCount, equals(4));
      expect(report.totalGatesCount, equals(4));
    });
  });
}
