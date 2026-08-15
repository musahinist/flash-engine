import 'package:flutter/widgets.dart';
import '../../core/graph/node.dart';
import '../../core/systems/tween.dart';
import '../framework.dart';
import '../../core/systems/engine.dart';

/// Declarative tween animation builder widget
/// Automatically handles animation lifecycle with engine tick
class FTweenBuilder<T> extends StatefulWidget {
  /// Starting value
  final T from;

  /// Ending value
  final T to;

  /// Animation duration
  final Duration duration;

  /// Delay before starting
  final Duration delay;

  /// Easing function
  final EasingFunction easing;

  /// Number of times to repeat (-1 for infinite)
  final int repeat;

  /// Whether to reverse on each repeat
  final bool yoyo;

  /// Whether to auto-start
  final bool autoStart;

  /// Builder function receiving current animated value
  final Widget Function(BuildContext context, T value) builder;

  /// Called when animation completes
  final VoidCallback? onComplete;

  /// Lerp function for custom types
  final T Function(T a, T b, double t)? lerp;

  const FTweenBuilder({
    super.key,
    required this.from,
    required this.to,
    required this.duration,
    required this.builder,
    this.delay = Duration.zero,
    this.easing = FEasing.easeInOutQuad,
    this.repeat = 0,
    this.yoyo = false,
    this.autoStart = true,
    this.onComplete,
    this.lerp,
  });

  @override
  State<FTweenBuilder<T>> createState() => _FTweenBuilderState<T>();
}

class _FTweenBuilderState<T> extends State<FTweenBuilder<T>> {
  late _InternalTween<T> _tween;
  T? _currentValue;

  @override
  void initState() {
    super.initState();
    _createTween();
  }

  void _createTween() {
    _tween = _InternalTween<T>(
      from: widget.from,
      to: widget.to,
      duration: widget.duration.inMilliseconds / 1000.0,
      delay: widget.delay.inMilliseconds / 1000.0,
      easing: widget.easing,
      repeatCount: widget.repeat,
      yoyo: widget.yoyo,
      lerp: widget.lerp ?? _defaultLerp,
      onUpdate: (value) {
        if (mounted) setState(() => _currentValue = value);
      },
      onComplete: widget.onComplete,
    );
    _currentValue = widget.from;
    if (widget.autoStart) _tween.start();
  }

  T _defaultLerp(T a, T b, double t) {
    // Default lerp implementations for common types
    if (a is double && b is double) {
      return (a + (b - a) * t) as T;
    }
    if (a is int && b is int) {
      return (a + ((b - a) * t).round()) as T;
    }
    // For other types, just return a or b based on t
    return t < 0.5 ? a : b;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerWithEngine();
  }

  FEngine? _engine;

  void _registerWithEngine() {
    final engine = context.dependOnInheritedWidgetOfExactType<InheritedFNode>()?.engine;
    if (identical(engine, _engine)) return;

    _engine?.removeUpdateListener(_onEngineUpdate);
    _engine = engine;
    engine?.addUpdateListener(_onEngineUpdate);
  }

  void _onEngineUpdate(double dt) => _tween.update(dt);

  @override
  void dispose() {
    _engine?.removeUpdateListener(_onEngineUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(FTweenBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.from != oldWidget.from || widget.to != oldWidget.to || widget.duration != oldWidget.duration) {
      _createTween();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentValue ?? widget.from);
  }
}

/// Internal tween class
class _InternalTween<T> {
  final T from;
  final T to;
  final double duration;
  final double delay;
  final EasingFunction easing;
  final int repeatCount;
  final bool yoyo;
  final T Function(T a, T b, double t) lerp;
  final void Function(T value) onUpdate;
  final VoidCallback? onComplete;

  TweenState _state = TweenState.idle;
  double _elapsed = 0;
  double _delayElapsed = 0;
  int _currentRepeat = 0;
  bool _forward = true;

  _InternalTween({
    required this.from,
    required this.to,
    required this.duration,
    required this.delay,
    required this.easing,
    required this.repeatCount,
    required this.yoyo,
    required this.lerp,
    required this.onUpdate,
    this.onComplete,
  });

  void start() {
    _state = TweenState.running;
    _elapsed = 0;
    _delayElapsed = 0;
    _currentRepeat = 0;
    _forward = true;
  }

  void update(double dt) {
    if (_state != TweenState.running) return;

    // Handle delay
    if (_delayElapsed < delay) {
      _delayElapsed += dt;
      return;
    }

    _elapsed += dt;
    double t = (_elapsed / duration).clamp(0.0, 1.0);

    // Apply easing
    double easedT = easing(t);

    // Apply yoyo direction
    if (!_forward) easedT = 1.0 - easedT;

    // Calculate value
    final value = lerp(from, to, easedT);
    onUpdate(value);

    // Check completion
    if (_elapsed >= duration) {
      if (repeatCount == -1 || _currentRepeat < repeatCount) {
        _currentRepeat++;
        _elapsed = 0;
        if (yoyo) _forward = !_forward;
      } else {
        _state = TweenState.completed;
        onComplete?.call();
      }
    }
  }
}

/// Convenience widget for animating double values
class FAnimatedDouble extends FTweenBuilder<double> {
  const FAnimatedDouble({
    super.key,
    required super.from,
    required super.to,
    required super.duration,
    required super.builder,
    super.delay,
    super.easing,
    super.repeat,
    super.yoyo,
    super.autoStart,
    super.onComplete,
  }) : super(lerp: _doubleLerp);

  static double _doubleLerp(double a, double b, double t) => a + (b - a) * t;
}

/// Convenience widget for animating node position
class FPositionAnimation extends StatefulWidget {
  final FNode node;
  final dynamic from; // Vector3 or null (uses current)
  final dynamic to; // Vector3
  final Duration duration;
  final EasingFunction easing;
  final Widget child;

  const FPositionAnimation({
    super.key,
    required this.node,
    this.from,
    required this.to,
    required this.duration,
    this.easing = FEasing.easeInOutQuad,
    required this.child,
  });

  @override
  State<FPositionAnimation> createState() => _FPositionAnimationState();
}

class _FPositionAnimationState extends State<FPositionAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: _EasingCurve(widget.easing));
    _animation.addListener(_updatePosition);
    _controller.forward();
  }

  void _updatePosition() {
    final t = _animation.value;
    final from = widget.from ?? widget.node.transform.position;
    final to = widget.to;
    widget.node.transform.position.x = from.x + (to.x - from.x) * t;
    widget.node.transform.position.y = from.y + (to.y - from.y) * t;
    widget.node.transform.position.z = from.z + (to.z - from.z) * t;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Custom curve wrapper for easing functions
class _EasingCurve extends Curve {
  final EasingFunction easing;
  const _EasingCurve(this.easing);

  @override
  double transformInternal(double t) => easing(t);
}
