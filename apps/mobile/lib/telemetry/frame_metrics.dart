import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Frame timing and jank statistics, with no external service.
///
/// This is the performance signal that is genuinely free: the engine already measures how long
/// each frame took to build and to raster, so there is nothing to buy and nothing to ship off
/// the device to read it. Sentry's tracing can forward a sample of this later, but the number
/// has to be computed somewhere regardless, and computing it here keeps it available in
/// development and in tests.
///
/// A frame is counted as jank when its total build+raster time exceeds [slowFrameBudget].
/// Flutter's own guidance treats roughly 16.7 ms as the 60 fps budget and allows some headroom
/// before a frame is worth reporting, so the default is deliberately looser than one vsync:
/// reporting every 17 ms frame as a problem would mean reporting nearly all of them.
class FrameMetrics {
  FrameMetrics({
    this.slowFrameBudget = const Duration(milliseconds: 24),
    this.maxSamples = 2000,
  });

  final Duration slowFrameBudget;

  /// Bounded so a long session cannot grow without limit.
  final int maxSamples;

  final List<Duration> _durations = [];
  bool _recording = false;

  bool get isRecording => _recording;

  /// Total frames observed since the last reset.
  int get totalFrames => _durations.length;

  /// Frames that exceeded [slowFrameBudget].
  int get slowFrames => _durations.where((d) => d > slowFrameBudget).length;

  /// Fraction of frames that were slow, 0..1.
  double get jankRatio =>
      _durations.isEmpty ? 0 : slowFrames / _durations.length;

  Duration get medianFrameTime => _percentile(0.50);
  Duration get p95FrameTime => _percentile(0.95);
  Duration get worstFrameTime =>
      _durations.isEmpty ? Duration.zero : _durations.reduce((a, b) => a > b ? a : b);

  /// Begins recording. Safe to call more than once.
  void start() {
    if (_recording) return;
    _recording = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_recording) return;
    _recording = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void reset() {
    _durations.clear();
  }

  /// Feed values in directly, so the statistics can be tested without a real frame pipeline.
  @visibleForTesting
  void record(List<Duration> frameTotals) {
    for (final d in frameTotals) {
      if (_durations.length >= maxSamples) _durations.removeAt(0);
      _durations.add(d);
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // totalSpan is build + raster + overhead for the frame; it is the number that decides
      // whether the user saw a dropped frame.
      _record(Duration(microseconds: timing.totalSpan.inMicroseconds));
    }
  }

  void _record(Duration d) {
    if (_durations.length >= maxSamples) _durations.removeAt(0);
    _durations.add(d);
  }

  Duration _percentile(double fraction) {
    if (_durations.isEmpty) return Duration.zero;
    final sorted = [..._durations]..sort();
    final index = (sorted.length * fraction).floor().clamp(0, sorted.length - 1);
    return sorted[index];
  }

  /// Compact report suitable for a metrics endpoint.
  Map<String, Object?> toReport() => {
    'frames': totalFrames,
    'slowFrames': slowFrames,
    'jankRatio': double.parse(jankRatio.toStringAsFixed(4)),
    'medianFrameMs': medianFrameTime.inMicroseconds / 1000,
    'p95FrameMs': p95FrameTime.inMicroseconds / 1000,
    'worstFrameMs': worstFrameTime.inMicroseconds / 1000,
  };
}

/// Times how long a named step took, for reporting slow screens and slow cold starts.
class StopwatchMetrics {
  final Map<String, int> _durationsMs = {};

  /// Records [step]'s elapsed time under [name].
  T measure<T>(String name, T Function() body) {
    final watch = Stopwatch()..start();
    try {
      return body();
    } finally {
      watch.stop();
      record(name, watch.elapsedMilliseconds);
    }
  }

  /// Records an asynchronous step.
  Future<T> measureAsync<T>(String name, Future<T> Function() body) async {
    final watch = Stopwatch()..start();
    try {
      return await body();
    } finally {
      watch.stop();
      record(name, watch.elapsedMilliseconds);
    }
  }

  void record(String name, int milliseconds) {
    // Keep the slowest observation for a name: a single 4s cold start matters more than ten
    // 200ms ones, and an average would hide it.
    //
    // The first observation always stores, including a 0 ms one. Comparing against a default
    // of 0 instead meant a step that completed inside the clock's resolution recorded nothing,
    // so the metric silently vanished rather than reporting that it was fast.
    final existing = _durationsMs[name];
    if (existing == null || milliseconds > existing) _durationsMs[name] = milliseconds;
  }

  int? worstFor(String name) => _durationsMs[name];

  Map<String, Object?> toReport() => Map<String, Object?>.from(_durationsMs);

  void clear() => _durationsMs.clear();
}