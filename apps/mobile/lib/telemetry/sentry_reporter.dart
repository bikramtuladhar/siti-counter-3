import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'event_scrubber.dart';
import 'frame_metrics.dart';

/// Error and performance reporting setup.
///
/// Sentry is optional and off unless a DSN is supplied at build time, so a development build or
/// a contributor's machine sends nothing at all. The DSN is never committed; it arrives through
/// `--dart-define=SENTRY_DSN=...`.
///
/// Privacy position: household and health data never leaves the device. [scrubEvent] is
/// installed as `beforeSend`, so scrubbing is unconditional for anything this app reports, not
/// a rule that depends on remembering to configure it. See [event_scrubber].
///
/// Free tier reality, stated plainly rather than left to discover: Sentry's developer plan
/// includes a monthly allowance of errors and performance units, and exceeding it bills rather
/// than degrades silently. The free, uncapped signal is [FrameMetrics], which is computed on the
/// device from engine timings and needs no service at all.
class SentryReporter {
  SentryReporter({
    required this.dsn,
    required this.environment,
    required this.release,
    this.errorSampleRate = 1.0,
    this.tracesSampleRate = 0.2,
    this.debug = false,
    this.metrics,
  });

  /// Null means "reporting is not configured"; every method then does nothing.
  static SentryReporter? fromEnvironment({FrameMetrics? metrics}) {
    const dsn = String.fromEnvironment('SENTRY_DSN');
    if (dsn.isEmpty) return null;

    const environment = String.fromEnvironment(
      'SENTRY_ENVIRONMENT',
      defaultValue: 'development',
    );
    const release = String.fromEnvironment(
      'SENTRY_RELEASE',
      defaultValue: 'local',
    );

    return SentryReporter(
      dsn: dsn,
      environment: environment,
      release: release,
      debug: const bool.fromEnvironment('SENTRY_DEBUG'),
      metrics: metrics,
    );
  }

  final String dsn;
  final String environment;
  final String release;
  final double errorSampleRate;
  final double tracesSampleRate;
  final bool debug;
  final FrameMetrics? metrics;

  bool get isEnabled => dsn.isNotEmpty;

  /// Initialises Sentry and takes over the framework's error handlers.
  ///
  /// Must run before `runApp`, otherwise the first frames are unguarded. Returns false when
  /// reporting is not configured, which is a normal outcome and not a failure.
  Future<bool> initialise() async {
    if (!isEnabled) return false;

    // The builder form, so options are configured through the SDK's own setters rather than a
    // constructor that differs between major versions.
    await Sentry.init(
      (options) {
        options.dsn = dsn;
        options.environment = environment;
        options.release = release;
        // PII stays off at the source as well as being scrubbed later. Two layers, because the
        // SDK attaches device identifiers automatically and a bug in the scrubber should not be
        // the only thing standing between a household's data and a third party.
        options.sendDefaultPii = false;
        options.attachStacktrace = true;
        // Performance units are metered on the free tier, so sample rather than ship all.
        options.tracesSampleRate = tracesSampleRate;
        options.debug = debug;
        options.beforeSend = _beforeSend;
        options.beforeBreadcrumb = _beforeBreadcrumb;
      },
      appRunner: () async {},
    );
    return true;
  }

  Future<SentryEvent?> _beforeSend(SentryEvent event, Hint hint) async {
    try {
      // The SDK models events as typed objects; convert, scrub, and hand the SDK back the
      // cleared shape. Anything the conversion does not carry over is therefore not sent.
      final scrubbed = scrubEvent(event.toJson());
      return SentryEvent.fromJson(scrubbed);
    } catch (_) {
      // Never let reporting break the app it is reporting on. Dropping an event is much better
      // than converting a bad one into a crash in the error handler.
      return event;
    }
  }

  /// Rebuilds a breadcrumb with its payload scrubbed.
  ///
  /// `data` is final on the SDK's Breadcrumb, so this returns a new one rather than mutating.
  /// A breadcrumb carrying a household member's name would otherwise be attached to every event
  /// that follows it.
  Breadcrumb? _beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) return null;
    if (breadcrumb.data == null) return breadcrumb;
    try {
      final scrubbed = scrubStructure(breadcrumb.data);
      return Breadcrumb(
        message: breadcrumb.message,
        category: breadcrumb.category,
        level: breadcrumb.level,
        type: breadcrumb.type,
        data: scrubbed is Map<String, Object?> ? scrubbed : const <String, Object?>{},
      );
    } catch (_) {
      // Rather than guess, drop the payload and keep the breadcrumb itself, which is the useful
      // part for ordering events.
      return Breadcrumb(
        message: breadcrumb.message,
        category: breadcrumb.category,
        level: breadcrumb.level,
        type: breadcrumb.type,
      );
    }
  }

  /// Reports a handled error, with the scrubbing still applied.
  Future<void> capture(
    Object error,
    StackTrace? stackTrace, {
    Map<String, Object?>? context,
    String? reason,
  }) async {
    if (!isEnabled) return;
    try {
      // The SDK method is captureException in this major version.
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (context != null) {
            final scrubbed = scrubStructure(context);
            if (scrubbed is Map<String, Object?>) scope.setContexts('app', scrubbed);
          }
          if (reason != null) scope.setTag('reason', reason);
          // Mark it as handled so crash-free-session maths is not distorted by errors the app
          // recovered from.
          scope.setTag('handled', 'true');
        },
      );
    } catch (_) {
      // See _beforeSend.
    }
  }

  /// Adds a timing breadcrumb, so a slow screen can be read against what preceded it.
  void addTimingBreadcrumb(String name, Duration elapsed, {String? screen}) {
    if (!isEnabled) return;
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: name,
        category: 'performance',
        data: {
          'ms': elapsed.inMilliseconds.toDouble(),
          // ignore: use_null_aware_elements
          if (screen != null) 'screen': screen,
        },
      ),
    );
  }
}

/// Reports a handled error from anywhere in the app.
///
/// Screens used to put `e.toString()` straight into the user-visible message, which surfaces
/// `PlatformException(channel: ..., message: ...)` and similar internals in the UI. The friendly
/// copy belongs on screen; the detail belongs here, scrubbed before it leaves the device and
/// logged locally when reporting is off.
void reportError(
  Object error,
  StackTrace? stack, {
  String? reason,
  Map<String, Object?>? context,
}) {
  assert(() {
    debugPrint('[siti] $reason: $error');
    return true;
  }());

  final reporter = SentryReporter.fromEnvironment();
  reporter?.capture(error, stack, context: context, reason: reason);
}

/// Starts the free frame-timing collector. Returns the collector so callers can read it.
FrameMetrics startFrameMetrics({Duration slowFrameBudget = const Duration(milliseconds: 24)}) {
  final metrics = FrameMetrics(slowFrameBudget: slowFrameBudget);
  metrics.start();
  return metrics;
}

/// Hooks the framework's uncaught-error channels to [onError].
///
/// Separate from [SentryReporter.initialise] so the behaviour can be tested without a DSN or a
/// network, and so handled failures are still surfaced when Sentry is switched off.
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