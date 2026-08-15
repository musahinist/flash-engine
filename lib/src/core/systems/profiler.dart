import 'dart:developer' as developer;

/// Frame-time instrumentation for the engine loop.
///
/// The engine's only performance signal used to be [FEngine.fps], which counts
/// ticker callbacks per second. That is capped by the display refresh, so it
/// reads a steady 60 whether a frame costs 2 ms or 16 ms — it cannot show
/// "we're at 60fps but 90% of the budget is gone". This measures the work
/// itself.
///
/// Sections are also emitted to the DevTools timeline via `dart:developer`, so
/// the same breakdown is visible in a real profile run.
class FProfiler {
  /// Named sections measured every frame, in the order they run.
  static const List<String> sections = [
    'tree',
    'physics',
    'transforms',
    'tilemaps',
    'prepareRender',
    'paint.sort',
    'paint.nodes',
    'paint.particles',
  ];

  /// Turns measurement on. Off by default: reading the clock per section costs
  /// something, and a shipped game should not pay for it.
  bool enabled = false;

  final Map<String, _Accumulator> _accumulators = {};
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _frameStartUs = 0;
  final List<double> _frameTimes = <double>[];

  /// Rolling window used for percentiles.
  static const int _windowFrames = 240;

  /// Milliseconds the last frame's engine work took.
  double lastFrameMs = 0;

  /// Runs [body] as a named section, timing it when [enabled].
  ///
  /// Always emits a timeline sync block, which is free when no profiler is
  /// attached.
  T section<T>(String name, T Function() body) {
    if (!enabled) return developer.Timeline.timeSync(name, body);

    final start = _stopwatch.elapsedMicroseconds;
    try {
      return developer.Timeline.timeSync(name, body);
    } finally {
      final elapsed = _stopwatch.elapsedMicroseconds - start;
      (_accumulators[name] ??= _Accumulator()).add(elapsed);
    }
  }

  void beginFrame() {
    if (!enabled) return;
    _frameStartUs = _stopwatch.elapsedMicroseconds;
  }

  void endFrame() {
    if (!enabled) return;
    lastFrameMs = (_stopwatch.elapsedMicroseconds - _frameStartUs) / 1000.0;
    _frameTimes.add(lastFrameMs);
    if (_frameTimes.length > _windowFrames) _frameTimes.removeAt(0);
  }

  /// Mean engine-work milliseconds per frame over the rolling window.
  double get averageFrameMs {
    if (_frameTimes.isEmpty) return 0;
    var total = 0.0;
    for (final t in _frameTimes) {
      total += t;
    }
    return total / _frameTimes.length;
  }

  /// 95th percentile frame time. The number that actually decides whether a
  /// game feels smooth — an average hides the hitches.
  double get p95FrameMs {
    if (_frameTimes.isEmpty) return 0;
    final sorted = List<double>.of(_frameTimes)..sort();
    return sorted[((sorted.length - 1) * 0.95).round()];
  }

  /// Mean milliseconds spent in [name] per frame.
  double averageMs(String name) {
    final acc = _accumulators[name];
    if (acc == null || acc.count == 0) return 0;
    return acc.totalUs / acc.count / 1000.0;
  }

  /// Total calls recorded for [name]. Useful for counting per-item work that
  /// should have been batched.
  int callCount(String name) => _accumulators[name]?.count ?? 0;

  void reset() {
    _accumulators.clear();
    _frameTimes.clear();
    lastFrameMs = 0;
  }

  /// One-line-per-section report, for benchmarks and debug overlays.
  String report() {
    final buffer = StringBuffer()
      ..writeln('frame: avg ${averageFrameMs.toStringAsFixed(3)} ms  '
          'p95 ${p95FrameMs.toStringAsFixed(3)} ms  '
          '(${_frameTimes.length} frames)');
    for (final name in sections) {
      final ms = averageMs(name);
      if (ms == 0) continue;
      buffer.writeln('  ${name.padRight(18)} ${ms.toStringAsFixed(3)} ms');
    }
    return buffer.toString();
  }
}

class _Accumulator {
  int totalUs = 0;
  int count = 0;

  void add(int us) {
    totalUs += us;
    count++;
  }
}
