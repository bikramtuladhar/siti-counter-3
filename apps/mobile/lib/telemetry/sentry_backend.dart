import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'error_reporter.dart';
import 'frame_metrics.dart';

/// Installs Sentry as the delivery backend for scrubbed error reports.
///
/// Kept separate from [ErrorReporter] for two reasons. Scrubbing is not optional and must not
/// live in code a vendor package owns, or removing a backend would silently remove the privacy
/// guarantee. And the reporting layer carries no vendor dependency, so a native SDK problem
/// cannot take the app's build with it again.
///
/// Version matters here: sentry_flutter 8.14.2 does not compile against the native SDK that
/// Swift Package Manager resolves — "S1entryBinaryImageCache has no member 'image'" — and this
/// project uses SPM rather than CocoaPods, so there is no Podfile.lock to pin with. 9.x builds.
const String _supportedMajor = '9';

/// Configures Sentry from `--dart-define` values, or returns false when not configured.
///
/// Called before `runApp` so the earliest failures are the ones captured.
Future<bool> initialiseSentry({
  required FrameMetrics? metrics,
}) async {
  const dsn = String.fromEnvironment('SENTRY_DSN');
  if (dsn.isEmpty) return false;

  const environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'development',
  );
  const release = String.fromEnvironment(
    'SENTRY_RELEASE',
    defaultValue: 'local',
  );

  await Sentry.init(
    (options) {
      options.dsn = dsn;
      options.environment = environment;
      options.release = release;
      // Off at the source as well as scrubbed in flight. Two layers, because the SDK attaches
      // device identifiers on its own and the scrubber should not be the only thing standing
      // between a household's data and a third party.
      options.sendDefaultPii = false;
      options.attachStacktrace = true;
      // Performance units are metered on the free tier.
      options.tracesSampleRate = 0.2;
      options.debug = const bool.fromEnvironment('SENTRY_DEBUG');
      options.beforeSend = (event, hint) async {
        // Belt and braces. ErrorReporter already scrubs the payload it hands over, but an
        // event can also be produced by the SDK itself — a framework error, a crash — and those
        // have not been through our own path.
        event.user = SentryUser();
        event.serverName = null;
        return event;
      };
    },
    appRunner: () async {},
  );

  ErrorReporter.installBackend(_send);

  // Frame timings are computed locally and shipped as a periodic metric rather than as
  // transactions: the engine already measured them, and a sampled trace would not aggregate to
  // a jank figure a human can act on.
  _reportFramesPeriodically(metrics);

  return true;
}

Future<void> _send(String type, Map<String, Object?> payload) async {
  if (payload.containsKey('stack')) {
    await Sentry.captureException(
      '${payload['type']}: ${payload['error']}',
      stackTrace: _parseStack(payload['stack'] as String?),
      withScope: (scope) {
        scope.setTag('reason', type);
        if (payload['context'] != null) {
          scope.setContexts(
            'app',
            payload['context'] as Map<String, Object?>,
          );
        }
      },
    );
    return;
  }

  if (payload.containsKey('frames') || payload['metric'] != null) {
    await Sentry.captureMessage(
      'metrics: $type',
      withScope: (scope) {
        scope.setContexts('metrics', payload);
      },
    );
    return;
  }

  await Sentry.captureMessage(
    payload['error']?.toString() ?? type,
    withScope: (scope) => scope.setContexts('app', payload),
  );
}

/// Rebuilds a stack trace Sentry can symbolicate.
StackTrace? _parseStack(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return StackTrace.fromString(raw);
}

/// Reports a frame-timing summary on a slow cadence.
void _reportFramesPeriodically(FrameMetrics? metrics) {
  if (metrics == null) return;
  Timer.periodic(const Duration(minutes: 15), (_) {
    if (!metrics.isRecording || metrics.totalFrames == 0) return;
    reportFrameMetrics(metrics);
  });
}

/// Removes Sentry as the backend, for tests and for sign-out.
void uninstallSentry() {
  ErrorReporter.installBackend(null);
}

/// The SDK major this integration was verified against.
///
/// Surfaced so a dependency bump that reintroduces the native mismatch is obvious in review
/// rather than discovered on a build machine.
@visibleForTesting
const String sentrySupportedMajor = _supportedMajor;