import 'package:flash/src/core/graph/node.dart';
import 'package:flash/src/core/graph/signal.dart';

/// FTimer - A Godot-style timer node.
///
/// Counts down `waitTime` seconds and emits [timeout] signal when complete.
/// Can be configured to run once ([oneShot]) or repeat continuously.
///
/// Example:
/// ```dart
/// final timer = FTimer(waitTime: 2.0, oneShot: true);
/// timer.timeout.connect(() => print("2 seconds passed!"));
/// timer.start();
/// ```
class FTimer extends FNode {
  /// Time to wait before emitting [timeout] (in seconds).
  double waitTime;

  /// If true, stops after first timeout. If false, repeats indefinitely.
  bool oneShot;

  /// If true, starts counting immediately when added to tree.
  bool autoStart;

  /// Emitted when the timer reaches zero.
  final FSignal<void> timeout = FSignal();

  // Internal state
  double _timeLeft = 0;
  bool _running = false;
  bool _paused = false;

  FTimer({super.name = 'Timer', this.waitTime = 1.0, this.oneShot = false, this.autoStart = false});

  /// Whether the timer is currently running.
  bool get isRunning => _running && !_paused;

  /// Whether the timer is paused.
  bool get isPaused => _paused;

  /// Remaining time until timeout (in seconds).
  double get timeLeft => _timeLeft;

  /// Start or restart the timer.
  void start([double? customWaitTime]) {
    _timeLeft = customWaitTime ?? waitTime;
    _running = true;
    _paused = false;
  }

  /// Stop the timer and reset.
  void stop() {
    _running = false;
    _paused = false;
    _timeLeft = 0;
  }

  /// Pause the timer (can resume with [resume]).
  void pause() {
    if (_running) {
      _paused = true;
    }
  }

  /// Resume a paused timer.
  void resume() {
    _paused = false;
  }

  @override
  void ready() {
    super.ready();
    if (autoStart) {
      start();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_running || _paused) return;

    _timeLeft -= dt;

    if (_timeLeft <= 0) {
      _timeLeft = 0;
      timeout.emit(null);

      if (oneShot) {
        _running = false;
      } else {
        // Restart for repeating timer
        _timeLeft = waitTime;
      }
    }
  }
}
