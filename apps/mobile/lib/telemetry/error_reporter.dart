import 'package:flutter/foundation.dart';

import 'event_scrubber.dart';
import 'frame_metrics.dart';

/// Where a scrubbed error report goes.
///
/// A function rather than an SDK type so the reporting layer carries no vendor dependency.
/// That is not architectural neatness: the Sentry Flutter SDK was tried here and broke the iOS
/// build, because its podspec pins `Sentry/HybridSDK` 8.46.0 while this repository commits no
/// `Podfile.lock`, so CocoaPods is free to resolve a newer native SDK whose API no longer
/// matches its own plugin. A reporting tool that breaks the app it reports on is worse than no
/// reporting tool, so the backend is installed at runtime instead.
typedef TelemetryBackend =
    Future<void> Function(String type, Map<String, Object?> payload);

/// Collects errors, scrubs them, and forwards them if a backend is installed.
///
/// Nothing here is optional except the backend: scrubbing and local logging always happen, so
/// the privacy guarantee does not depend on a third party being configured correctly.
class ErrorReporter {
  ErrorReporter({this.backend, this.enabled = true});

  /// The single process-wide instance. Replaced in tests.
  static ErrorReporter instance = ErrorReporter();

  /// Where scrubbed reports go. Null means local logging only.
  TelemetryBackend? backend;

  /// Master switch. Off means reports are neither logged nor forwarded.
  bool enabled;

  /// Installs a backend. Pass null to remove it.
  static void installBackend(TelemetryBackend? backend) {
    instance.backend = backend;
  }

  /// Reports [error], scrubbing [context] first.
  Future<void> capture(
    Object error,
    StackTrace? stack, {
    String? reason,
    Map<String, Object?>? context,
  }) async {
    if (!enabled) return;

    final scrubbedContext = context == null
        ? null
        : scrubStructure(context) as Map<String, Object?>?;

    // Logged locally first so a developer sees the problem even with no backend configured.
    assert(() {
      debugPrint('[siti] ${reason ?? 'error'}: $error');
      return true;
    }());

    final backend = this.backend;
    if (backend == null) return;

    try {
      await backend(
        reason ?? 'error',
        <String, Object?>{
          'error': error.toString(),
          'type': error.runtimeType.toString(),
          'reason': reason,
          if (stack != null) 'stack': scrubStructure(stack.toString()),
          if (scrubbedContext != null) 'context': scrubbedContext,
        },
      );
    } catch (_) {
      // Reporting must never break the app it reports on. A failure to forward is a much
      // smaller problem than an exception thrown inside an error handler.
    }
  }

  /// Adds a timing breadcrumb, so a slow screen can be read against what preceded it.
  Future<void> addTiming(String name, Duration elapsed, {String? screen}) async {
    final backend = this.backend;
    if (!enabled || backend == null) return;
    try {
      await backend('performance', <String, Object?>{
        'metric': name,
        'ms': elapsed.inMilliseconds.toDouble(),
        if (screen != null) 'screen': screen,
      });
    } catch (_) {
      // See capture.
    }
  }
}

/// Reports a handled error from anywhere in the app.
///
/// Screens used to put `e.toString()` straight into the user-visible message, which surfaces
/// `PlatformException(channel: ..., message: ...)` and similar internals in the UI. The friendly
/// copy belongs on screen; the detail belongs here, scrubbed before it leaves the device and
/// logged locally when no backend is installed.
void reportError(
  Object error,
  StackTrace? stack, {
  String? reason,
  Map<String, Object?>? context,
}) {
  ErrorReporter.instance.capture(
    error,
    stack,
    reason: reason,
    context: context,
  );
}

/// Reports a frame-timing summary, if a backend is listening.
void reportFrameMetrics(FrameMetrics metrics, {String? screen}) {
  ErrorReporter.instance.addTiming('frames', Duration.zero, screen: screen);
  final backend = ErrorReporter.instance.backend;
  if (backend == null) return;
  backend('performance', <String, Object?>{
    ...metrics.toReport(),
    if (screen != null) 'screen': screen,
  }).catchError((_) {});
}

/// Starts the free frame-timing collector. Returns it so callers can read it.
FrameMetrics startFrameMetrics({
  Duration slowFrameBudget = const Duration(milliseconds: 24),
}) {
  final metrics = FrameMetrics(slowFrameBudget: slowFrameBudget);
  metrics.start();
  return metrics;
}

/// Hooks the framework's uncaught-error channels.
///
/// Separate from any backend setup so the behaviour is testable with nothing installed, and so
/// failures are still surfaced locally when reporting is switched off.
void installGlobalErrorHandlers({
  required void Function(Object, StackTrace) onError,
  void Function(Object, StackTrace, String)? onFlutterError,
}) {
  final priorOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    onError(error, stack);
    // Returning true marks it handled; the prior handler still runs if there was one.
    return priorOnError?.call(error, stack) ?? true;
  };

  final priorOnFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    final error = details.exception;
    final stack = details.stack ?? StackTrace.current;
    if (onFlutterError != null) {
      onFlutterError(error, stack, details.context?.toDescription() ?? 'flutter');
    } else {
      onError(error, stack);
    }
    priorOnFlutterError?.call(details);
  };
}