import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/telemetry/error_reporter.dart';
import 'package:siti_counter/telemetry/sentry_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initialiseSentry', () {
    test('does nothing when no DSN is configured', () async {
      // The default for a local build and for every test run.
      expect(await initialiseSentry(metrics: null), isFalse);
      expect(ErrorReporter.instance.backend, isNull);
    });

    test('leaves the backend clear when it declines to start', () async {
      await initialiseSentry(metrics: null);
      // Nothing should be installed, so a report cannot leak anywhere.
      expect(ErrorReporter.instance.backend, isNull);
    });
  });

  group('uninstallSentry', () {
    test('removes any installed backend', () async {
      ErrorReporter.installBackend((_, _) async {});
      expect(ErrorReporter.instance.backend, isNotNull);

      uninstallSentry();
      expect(ErrorReporter.instance.backend, isNull);
    });
  });

  group('sentry version guard', () {
    test('records the major that was verified against a working iOS build', () {
      // 8.14.2 does not compile against the sentry-cocoa that SPM resolves, and this project
      // uses Swift Package Manager, so there is no Podfile.lock to pin with.
      expect(sentrySupportedMajor, '9');
    });
  });
}
