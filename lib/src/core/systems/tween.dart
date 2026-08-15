import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../graph/node.dart';

/// Easing function signature
typedef EasingFunction = double Function(double t);

/// Common easing functions
class FEasing {
  // Linear
  static double linear(double t) => t;

  // Quadratic
  static double easeInQuad(double t) => t * t;
  static double easeOutQuad(double t) => t * (2 - t);
  static double easeInOutQuad(double t) => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  // Cubic
  static double easeInCubic(double t) => t * t * t;
  static double easeOutCubic(double t) => (--t) * t * t + 1;
  static double easeInOutCubic(double t) => t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;

  // Quartic
  static double easeInQuart(double t) => t * t * t * t;
  static double easeOutQuart(double t) => 1 - (--t) * t * t * t;
  static double easeInOutQuart(double t) => t < 0.5 ? 8 * t * t * t * t : 1 - 8 * (--t) * t * t * t;

  // Sine
  static double easeInSine(double t) => 1 - math.cos(t * math.pi / 2);
  static double easeOutSine(double t) => math.sin(t * math.pi / 2);
  static double easeInOutSine(double t) => -(math.cos(math.pi * t) - 1) / 2;

  // Exponential
  static double easeInExpo(double t) => t == 0 ? 0 : math.pow(2, 10 * t - 10).toDouble();
  static double easeOutExpo(double t) => t == 1 ? 1 : 1 - math.pow(2, -10 * t).toDouble();
  static double easeInOutExpo(double t) {
    if (t == 0) return 0;
    if (t == 1) return 1;
    return t < 0.5 ? math.pow(2, 20 * t - 10).toDouble() / 2 : (2 - math.pow(2, -20 * t + 10).toDouble()) / 2;
  }

  // Back (overshoots)
  static double easeInBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return c3 * t * t * t - c1 * t * t;
  }

  static double easeOutBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
  }

  static double easeInOutBack(double t) {
    const c1 = 1.70158;
    const c2 = c1 * 1.525;
    return t < 0.5
        ? (math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
        : (math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2;
  }

  // Elastic
  static double easeInElastic(double t) {
    if (t == 0) return 0;
    if (t == 1) return 1;
    const c4 = (2 * math.pi) / 3;
    return -math.pow(2, 10 * t - 10) * math.sin((t * 10 - 10.75) * c4);
  }

  static double easeOutElastic(double t) {
    if (t == 0) return 0;
    if (t == 1) return 1;
    const c4 = (2 * math.pi) / 3;
    return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1;
  }

  static double easeInOutElastic(double t) {
    if (t == 0) return 0;
    if (t == 1) return 1;
    const c5 = (2 * math.pi) / 4.5;
    return t < 0.5
        ? -(math.pow(2, 20 * t - 10) * math.sin((20 * t - 11.125) * c5)) / 2
        : (math.pow(2, -20 * t + 10) * math.sin((20 * t - 11.125) * c5)) / 2 + 1;
  }

  // Bounce
  static double easeOutBounce(double t) {
    const n1 = 7.5625;
    const d1 = 2.75;
    if (t < 1 / d1) {
      return n1 * t * t;
    } else if (t < 2 / d1) {
      t -= 1.5 / d1;
      return n1 * t * t + 0.75;
    } else if (t < 2.5 / d1) {
      t -= 2.25 / d1;
      return n1 * t * t + 0.9375;
    } else {
      t -= 2.625 / d1;
      return n1 * t * t + 0.984375;
    }
  }

  static double easeInBounce(double t) => 1 - easeOutBounce(1 - t);
  static double easeInOutBounce(double t) =>
      t < 0.5 ? (1 - easeOutBounce(1 - 2 * t)) / 2 : (1 + easeOutBounce(2 * t - 1)) / 2;
}

/// Animation state
enum TweenState { idle, running, paused, completed }

/// Base tween class for animating values
abstract class FTween<T> {
  final T from;
  final T to;
  final double duration; // seconds
  final EasingFunction easing;
  final double delay; // seconds
  final int repeatCount; // -1 for infinite
  final bool yoyo; // reverse on repeat

  double _elapsed = 0;
  double _delayElapsed = 0;
  int _currentRepeat = 0;
  bool _forward = true;
  TweenState _state = TweenState.idle;

  /// Callbacks
  void Function(T value)? onUpdate;
  void Function()? onComplete;
  void Function()? onRepeat;

  FTween({
    required this.from,
    required this.to,
    required this.duration,
    this.easing = FEasing.easeOutQuad,
    this.delay = 0,
    this.repeatCount = 0,
    this.yoyo = false,
    this.onUpdate,
    this.onComplete,
    this.onRepeat,
  });

  TweenState get state => _state;
  bool get isRunning => _state == TweenState.running;
  bool get isCompleted => _state == TweenState.completed;

  /// Current progress (0-1)
  double get progress => duration > 0 ? (_elapsed / duration).clamp(0, 1) : 1;

  /// Current value
  T get value {
    double t = easing(progress);
    if (!_forward) t = 1 - t;
    return lerp(from, to, t);
  }

  /// Interpolation (must be implemented by subclasses)
  T lerp(T a, T b, double t);

  /// Start the animation
  void start() {
    _state = TweenState.running;
    _elapsed = 0;
    _delayElapsed = 0;
    _currentRepeat = 0;
    _forward = true;
  }

  /// Pause the animation
  void pause() {
    if (_state == TweenState.running) {
      _state = TweenState.paused;
    }
  }

  /// Resume the animation
  void resume() {
    if (_state == TweenState.paused) {
      _state = TweenState.running;
    }
  }

  /// Stop the animation
  void stop() {
    _state = TweenState.idle;
    _elapsed = 0;
  }

  /// Reset to start
  void reset() {
    _elapsed = 0;
    _delayElapsed = 0;
    _currentRepeat = 0;
    _forward = true;
    _state = TweenState.idle;
  }

  /// Update the animation (call every frame)
  void update(double dt) {
    if (_state != TweenState.running) return;

    // Handle delay. The frame that crosses the boundary carries its remainder
    // into the tween rather than being swallowed whole, so a long frame does
    // not push the start time out by up to a full dt.
    if (_delayElapsed < delay) {
      _delayElapsed += dt;
      final overshoot = _delayElapsed - delay;
      if (overshoot <= 0) return;
      dt = overshoot;
    }

    _elapsed += dt;

    // Notify value change
    onUpdate?.call(value);

    // Check completion
    if (_elapsed >= duration) {
      if (repeatCount == -1 || _currentRepeat < repeatCount) {
        // Repeat
        _currentRepeat++;
        _elapsed = 0;
        if (yoyo) _forward = !_forward;
        onRepeat?.call();
      } else {
        // Complete
        _state = TweenState.completed;
        onComplete?.call();
      }
    }
  }
}

/// Double tween
class FDoubleTween extends FTween<double> {
  FDoubleTween({
    required super.from,
    required super.to,
    required super.duration,
    super.easing,
    super.delay,
    super.repeatCount,
    super.yoyo,
    super.onUpdate,
    super.onComplete,
    super.onRepeat,
  });

  @override
  double lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Vector3 tween
class FVector3Tween extends FTween<Vector3> {
  FVector3Tween({
    required super.from,
    required super.to,
    required super.duration,
    super.easing,
    super.delay,
    super.repeatCount,
    super.yoyo,
    super.onUpdate,
    super.onComplete,
    super.onRepeat,
  });

  @override
  Vector3 lerp(Vector3 a, Vector3 b, double t) {
    return Vector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
  }
}

/// Color tween (using int ARGB)
class FColorTween extends FTween<int> {
  FColorTween({
    required super.from,
    required super.to,
    required super.duration,
    super.easing,
    super.delay,
    super.repeatCount,
    super.yoyo,
    super.onUpdate,
    super.onComplete,
    super.onRepeat,
  });

  @override
  int lerp(int a, int b, double t) {
    final aA = (a >> 24) & 0xFF;
    final aR = (a >> 16) & 0xFF;
    final aG = (a >> 8) & 0xFF;
    final aB = a & 0xFF;

    final bA = (b >> 24) & 0xFF;
    final bR = (b >> 16) & 0xFF;
    final bG = (b >> 8) & 0xFF;
    final bB = b & 0xFF;

    final rA = (aA + (bA - aA) * t).round();
    final rR = (aR + (bR - aR) * t).round();
    final rG = (aG + (bG - aG) * t).round();
    final rB = (aB + (bB - aB) * t).round();

    return (rA << 24) | (rR << 16) | (rG << 8) | rB;
  }
}

/// Tween manager for handling multiple tweens
class FTweenManager {
  final List<FTween> _tweens = [];

  /// Add a tween
  void add(FTween tween) {
    _tweens.add(tween);
    tween.start();
  }

  /// Remove a tween
  void remove(FTween tween) {
    _tweens.remove(tween);
  }

  /// Update all tweens
  void update(double dt) {
    for (int i = _tweens.length - 1; i >= 0; i--) {
      _tweens[i].update(dt);
      if (_tweens[i].isCompleted) {
        _tweens.removeAt(i);
      }
    }
  }

  /// Clear all tweens
  void clear() {
    _tweens.clear();
  }

  /// Number of active tweens
  int get count => _tweens.length;
}

/// Extension methods for easy node animation
extension FNodeTweenExtension on FNode {
  /// Animate position to target
  FVector3Tween tweenPosition({
    required Vector3 to,
    required double duration,
    EasingFunction easing = FEasing.easeOutQuad,
    double delay = 0,
    int repeatCount = 0,
    bool yoyo = false,
    void Function()? onComplete,
  }) {
    final tween = FVector3Tween(
      from: transform.position.clone(),
      to: to,
      duration: duration,
      easing: easing,
      delay: delay,
      repeatCount: repeatCount,
      yoyo: yoyo,
      onUpdate: (v) => transform.position = v,
      onComplete: onComplete,
    );
    tween.start();
    return tween;
  }

  /// Animate rotation to target
  FVector3Tween tweenRotation({
    required Vector3 to,
    required double duration,
    EasingFunction easing = FEasing.easeOutQuad,
    double delay = 0,
    int repeatCount = 0,
    bool yoyo = false,
    void Function()? onComplete,
  }) {
    final tween = FVector3Tween(
      from: transform.rotation.clone(),
      to: to,
      duration: duration,
      easing: easing,
      delay: delay,
      repeatCount: repeatCount,
      yoyo: yoyo,
      onUpdate: (v) => transform.rotation = v,
      onComplete: onComplete,
    );
    tween.start();
    return tween;
  }

  /// Animate scale to target
  FVector3Tween tweenScale({
    required Vector3 to,
    required double duration,
    EasingFunction easing = FEasing.easeOutQuad,
    double delay = 0,
    int repeatCount = 0,
    bool yoyo = false,
    void Function()? onComplete,
  }) {
    final tween = FVector3Tween(
      from: transform.scale.clone(),
      to: to,
      duration: duration,
      easing: easing,
      delay: delay,
      repeatCount: repeatCount,
      yoyo: yoyo,
      onUpdate: (v) => transform.scale = v,
      onComplete: onComplete,
    );
    tween.start();
    return tween;
  }
}
