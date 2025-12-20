import 'dart:async';
import 'package:flutter/widgets.dart';

/// Base class for all events
abstract class FlashEvent {
  final DateTime timestamp = DateTime.now();

  /// Event name for debugging
  String get name => runtimeType.toString();
}

/// Typed event with payload
class FlashDataEvent<T> extends FlashEvent {
  final T data;

  FlashDataEvent(this.data);

  @override
  String get name => 'FlashDataEvent<${T.runtimeType}>($data)';
}

/// Simple string event
class FlashSignal extends FlashEvent {
  final String signal;

  FlashSignal(this.signal);

  @override
  String get name => signal;
}

/// Event subscription holder
class _Subscription<T extends FlashEvent> {
  final void Function(T event) handler;
  final bool once;
  bool cancelled = false;

  _Subscription(this.handler, {this.once = false});

  void call(T event) {
    if (!cancelled) handler(event);
  }

  void cancel() => cancelled = true;
}

/// Subscription handle for unsubscribing
class FlashEventSubscription {
  final VoidCallback _unsubscribe;

  FlashEventSubscription(this._unsubscribe);

  void cancel() => _unsubscribe();
}

/// Global event bus for game-wide communication
class FlashEventBus {
  static final FlashEventBus _instance = FlashEventBus._internal();
  static FlashEventBus get instance => _instance;

  factory FlashEventBus() => _instance;

  FlashEventBus._internal();

  final Map<Type, List<_Subscription>> _handlers = {};
  final List<FlashEvent> _eventHistory = [];
  final int maxHistorySize = 50;

  /// Stream controller for reactive listening
  final StreamController<FlashEvent> _streamController = StreamController.broadcast();

  /// Stream of all events
  Stream<FlashEvent> get stream => _streamController.stream;

  /// Event history
  List<FlashEvent> get history => List.unmodifiable(_eventHistory);

  /// Subscribe to events of a specific type
  FlashEventSubscription on<T extends FlashEvent>(void Function(T event) handler) {
    _handlers.putIfAbsent(T, () => []);
    final sub = _Subscription<T>(handler);
    _handlers[T]!.add(sub);

    return FlashEventSubscription(() {
      sub.cancel();
      _handlers[T]?.remove(sub);
    });
  }

  /// Subscribe to an event type, but only fire once
  FlashEventSubscription once<T extends FlashEvent>(void Function(T event) handler) {
    late FlashEventSubscription subscription;
    subscription = on<T>((event) {
      handler(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// Emit an event to all subscribers
  void emit<T extends FlashEvent>(T event) {
    // Add to history
    _eventHistory.add(event);
    if (_eventHistory.length > 50) {
      _eventHistory.removeAt(0);
    }

    // Notify stream listeners
    _streamController.add(event);

    // Notify type-specific handlers
    final handlers = _handlers[T];
    if (handlers != null) {
      // Create copy to avoid modification during iteration
      for (final handler in List.from(handlers)) {
        if (!handler.cancelled) {
          (handler as _Subscription<T>).call(event);
        }
      }
      // Clean up cancelled handlers
      handlers.removeWhere((h) => h.cancelled);
    }

    // Also notify handlers for parent types (FlashEvent catches all)
    if (T != FlashEvent) {
      final baseHandlers = _handlers[FlashEvent];
      if (baseHandlers != null) {
        for (final handler in List.from(baseHandlers)) {
          if (!handler.cancelled) {
            (handler as _Subscription<FlashEvent>).call(event);
          }
        }
      }
    }
  }

  /// Emit a simple signal
  void signal(String name) => emit(FlashSignal(name));

  /// Emit a data event
  void data<T>(T payload) => emit(FlashDataEvent<T>(payload));

  /// Clear all handlers
  void clear() {
    _handlers.clear();
    _eventHistory.clear();
  }

  /// Remove all handlers for a specific type
  void clearType<T extends FlashEvent>() {
    _handlers.remove(T);
  }

  void dispose() {
    clear();
    _streamController.close();
  }
}

/// Widget that listens to events and rebuilds
class FlashEventListener<T extends FlashEvent> extends StatefulWidget {
  final Widget Function(BuildContext context, T? lastEvent) builder;
  final void Function(T event)? onEvent;

  const FlashEventListener({super.key, required this.builder, this.onEvent});

  @override
  State<FlashEventListener<T>> createState() => _FlashEventListenerState<T>();
}

class _FlashEventListenerState<T extends FlashEvent> extends State<FlashEventListener<T>> {
  FlashEventSubscription? _subscription;
  T? _lastEvent;

  @override
  void initState() {
    super.initState();
    _subscription = FlashEventBus.instance.on<T>((event) {
      widget.onEvent?.call(event);
      if (mounted) setState(() => _lastEvent = event);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _lastEvent);
}

/// Mixin for widgets that need to subscribe to events
mixin FlashEventMixin<T extends StatefulWidget> on State<T> {
  final List<FlashEventSubscription> _subscriptions = [];

  /// Subscribe to an event type
  void subscribe<E extends FlashEvent>(void Function(E event) handler) {
    _subscriptions.add(FlashEventBus.instance.on<E>(handler));
  }

  /// Emit an event
  void emit<E extends FlashEvent>(E event) {
    FlashEventBus.instance.emit(event);
  }

  /// Emit a signal
  void signal(String name) {
    FlashEventBus.instance.signal(name);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

// --- Common Game Events ---

/// Player took damage
class PlayerDamageEvent extends FlashEvent {
  final int damage;
  final int remainingHealth;

  PlayerDamageEvent(this.damage, this.remainingHealth);
}

/// Player died
class PlayerDeathEvent extends FlashEvent {}

/// Score changed
class ScoreChangedEvent extends FlashEvent {
  final int oldScore;
  final int newScore;

  ScoreChangedEvent(this.oldScore, this.newScore);

  int get delta => newScore - oldScore;
}

/// Level completed
class LevelCompleteEvent extends FlashEvent {
  final int level;
  final int stars;

  LevelCompleteEvent(this.level, this.stars);
}

/// Game paused/resumed
class GamePauseEvent extends FlashEvent {
  final bool paused;

  GamePauseEvent(this.paused);
}

/// Collectible collected
class CollectEvent extends FlashEvent {
  final String itemType;
  final int value;

  CollectEvent(this.itemType, this.value);
}
