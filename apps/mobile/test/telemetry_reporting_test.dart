import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/telemetry/frame_metrics.dart';
import 'package:siti_counter/telemetry/sentry_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FrameMetrics', () {
    test('starts empty', () {
      final m = FrameMetrics();
      expect(m.totalFrames, 0);
      expect(m.jankRatio, 0);
      expect(m.medianFrameTime, Duration.zero);
    });

    test('counts frames and identifies the slow ones', () {
      final m = FrameMetrics(slowFrameBudget: const Duration(milliseconds: 20));
      m.record(const [
        Duration(milliseconds: 8),
        Duration(milliseconds: 12),
        Duration(milliseconds: 40),
        Duration(milliseconds: 9),
      ]);

      expect(m.totalFrames, 4);
      expect(m.slowFrames, 1);
      expect(m.jankRatio, closeTo(0.25, 0.001));
    });

    test('a frame exactly at the budget is not slow', () {
      final m = FrameMetrics(slowFrameBudget: const Duration(milliseconds: 20));
      m.record(const [Duration(milliseconds: 20)]);
      expect(m.slowFrames, 0);
    });

    test('percentiles are computed over the sorted samples', () {
      final m = FrameMetrics();
      m.record([for (var ms = 1; ms <= 100; ms++) Duration(milliseconds: ms)]);

      expect(m.medianFrameTime.inMilliseconds, lessThanOrEqualTo(51));
      expect(m.p95FrameTime.inMilliseconds, greaterThan(m.medianFrameTime.inMilliseconds));
      expect(m.worstFrameTime.inMilliseconds, 100);
    });

    test('is bounded so a long session cannot grow without limit', () {
      final m = FrameMetrics(maxSamples: 10);
      m.record([for (var i = 0; i < 50; i++) Duration(milliseconds: i + 1)]);
      expect(m.totalFrames, 10);
      // The oldest samples are dropped, so the worst is the most recent one.
      expect(m.worstFrameTime.inMilliseconds, 50);
    });

    test('reports a compact summary', () {
      final m = FrameMetrics(slowFrameBudget: const Duration(milliseconds: 16));
      m.record(const [Duration(milliseconds: 4), Duration(milliseconds: 32)]);

      final report = m.toReport();
      expect(report['frames'], 2);
      expect(report['slowFrames'], 1);
      expect(report['jankRatio'], 0.5);
      expect(report['worstFrameMs'], 32.0);
    });

    test('reset clears the samples', () {
      final m = FrameMetrics();
      m.record(const [Duration(milliseconds: 50)]);
      m.reset();
      expect(m.totalFrames, 0);
    });

    test('starting is idempotent and stopping is safe', () {
      final m = FrameMetrics();
      m.start();
      m.start();
      expect(m.isRecording, isTrue);
      m.stop();
      m.stop();
      expect(m.isRecording, isFalse);
    });
  });

  group('StopwatchMetrics', () {
    test('keeps the slowest observation for a step', () {
      final m = StopwatchMetrics();
      m.record('screen.load', 100);
      m.record('screen.load', 900);
      m.record('screen.load', 300);
      // An average would hide the 900ms cold start.
      expect(m.worstFor('screen.load'), 900);
    });

    test('measures a synchronous step', () {
      final m = StopwatchMetrics();
      final result = m.measure('sync', () => 42);
      expect(result, 42);
      // Recorded even when it finished inside the clock's resolution.
      expect(m.toReport().containsKey('sync'), isTrue);
    });

    test('measures an asynchronous step', () async {
      final m = StopwatchMetrics();
      final result = await m.measureAsync('async', () async => 'done');
      expect(result, 'done');
      expect(m.toReport().containsKey('async'), isTrue);
    });

    test('records even when the step throws', () async {
      final m = StopwatchMetrics();
      await expectLater(
        m.measureAsync('failing', () async => throw StateError('boom')),
        throwsStateError,
      );
      // A failed step is often the slow one, so the measurement must survive the throw.
      expect(m.toReport().containsKey('failing'), isTrue);
    });
  });

  group('SentryReporter configuration', () {
    test('is disabled without a DSN and does not initialise', () async {
      final reporter = SentryReporter(dsn: '', environment: 'test', release: 'test');
      expect(reporter.isEnabled, isFalse);
      expect(await reporter.initialise(), isFalse);
    });

    test('capture is a no-op when disabled, and does not throw', () async {
      final reporter = SentryReporter(dsn: '', environment: 'test', release: 'test');
      await reporter.capture(StateError('boom'), StackTrace.current, reason: 'test');
      reporter.addTimingBreadcrumb('screen.load', const Duration(milliseconds: 5));
    });

    test('defaults to sampling performance rather than sending everything', () {
      final reporter = SentryReporter(
        dsn: 'https://example@example.ingest.sentry.io/1',
        environment: 'test',
        release: 'test',
      );
      expect(reporter.tracesSampleRate, lessThan(1.0));
    });
  });

  group('global error handlers', () {
    test('a platform error is reported and marked handled', () {
      final seen = <Object>[];
      installGlobalErrorHandlers(onError: (error, stack) => seen.add(error));

      final handled = PlatformDispatcher.instance.onError!(
        StateError('platform boom'),
        StackTrace.current,
      );

      expect(seen, hasLength(1));
      expect(handled, isTrue);
    });

    test('a flutter error is reported with its context', () {
      final seen = <String>[];
      installGlobalErrorHandlers(
        onError: (_, _) {},
        onFlutterError: (_, _, context) => seen.add(context),
      );

      FlutterError.reportError(FlutterErrorDetails(
        exception: StateError('widget boom'),
        stack: StackTrace.current,
        library: 'test library',
        context: ErrorDescription('while building the planner'),
      ));

      expect(seen, hasLength(1));
    });
  });
}