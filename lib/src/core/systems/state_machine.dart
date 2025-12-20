import 'package:flutter/widgets.dart';

/// Base class for states in a state machine
abstract class FlashState<T> {
  /// Unique name/identifier for this state
  String get name;

  /// Reference to the state machine owning this state
  FlashStateMachine<T>? machine;

  /// Called when entering this state
  void onEnter(T? previousState) {}

  /// Called when exiting this state
  void onExit(T? nextState) {}

  /// Called every frame while in this state
  void onUpdate(double dt) {}

  /// Check if can transition to another state
  bool canTransitionTo(T state) => true;
}

/// Simple state implementation using callbacks
class FlashSimpleState<T> extends FlashState<T> {
  @override
  final String name;

  final void Function(T? previousState)? enter;
  final void Function(T? nextState)? exit;
  final void Function(double dt)? update;
  final bool Function(T state)? canTransition;

  FlashSimpleState({required this.name, this.enter, this.exit, this.update, this.canTransition});

  @override
  void onEnter(T? previousState) => enter?.call(previousState);

  @override
  void onExit(T? nextState) => exit?.call(nextState);

  @override
  void onUpdate(double dt) => update?.call(dt);

  @override
  bool canTransitionTo(T state) => canTransition?.call(state) ?? true;
}

/// State machine for managing game states with transitions
class FlashStateMachine<T> extends ChangeNotifier {
  final Map<T, FlashState<T>> _states = {};
  FlashState<T>? _currentState;
  FlashState<T>? _previousState;

  /// History of state transitions
  final List<T> _history = [];
  final int maxHistorySize;

  /// Whether transitions are currently locked
  bool _locked = false;

  /// Current state
  FlashState<T>? get currentState => _currentState;

  /// Previous state
  FlashState<T>? get previousState => _previousState;

  /// Current state identifier
  T? get current => _currentState != null ? _findKeyForState(_currentState!) : null;

  /// Check if currently in a specific state
  bool isInState(T state) => current == state;

  /// State history
  List<T> get history => List.unmodifiable(_history);

  FlashStateMachine({this.maxHistorySize = 10});

  /// Register a state
  void addState(T key, FlashState<T> state) {
    state.machine = this;
    _states[key] = state;
  }

  /// Register multiple states
  void addStates(Map<T, FlashState<T>> states) {
    states.forEach(addState);
  }

  /// Remove a state
  void removeState(T key) {
    _states[key]?.machine = null;
    _states.remove(key);
  }

  /// Transition to a new state
  bool transitionTo(T newState) {
    if (_locked) {
      debugPrint('StateMachine: Transition locked');
      return false;
    }

    final targetState = _states[newState];
    if (targetState == null) {
      debugPrint('StateMachine: State "$newState" not found');
      return false;
    }

    // Check if current state allows transition
    if (_currentState != null && !_currentState!.canTransitionTo(newState)) {
      debugPrint('StateMachine: Transition to "$newState" not allowed');
      return false;
    }

    _locked = true;

    // Exit current state
    final previousKey = current;
    _currentState?.onExit(newState);

    // Update state
    _previousState = _currentState;
    _currentState = targetState;

    // Add to history
    if (previousKey != null) {
      _history.add(previousKey);
      if (_history.length > maxHistorySize) {
        _history.removeAt(0);
      }
    }

    // Enter new state
    _currentState!.onEnter(previousKey);

    _locked = false;
    notifyListeners();

    return true;
  }

  /// Go back to previous state in history
  bool goBack() {
    if (_history.isEmpty) return false;
    final previousState = _history.removeLast();
    return transitionTo(previousState);
  }

  /// Force set state without callbacks
  void forceState(T state) {
    final targetState = _states[state];
    if (targetState != null) {
      _previousState = _currentState;
      _currentState = targetState;
      notifyListeners();
    }
  }

  /// Update current state (call every frame)
  void update(double dt) {
    _currentState?.onUpdate(dt);
  }

  /// Reset to initial state
  void reset(T initialState) {
    _history.clear();
    _previousState = null;
    _currentState = null;
    transitionTo(initialState);
  }

  T? _findKeyForState(FlashState<T> state) {
    for (final entry in _states.entries) {
      if (entry.value == state) return entry.key;
    }
    return null;
  }
}

/// Widget that provides a state machine to its children and rebuilds on state changes
class FlashStateMachineWidget<T> extends StatelessWidget {
  final FlashStateMachine<T> machine;
  final Widget Function(BuildContext context, T? state) builder;

  const FlashStateMachineWidget({super.key, required this.machine, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: machine, builder: (context, _) => builder(context, machine.current));
  }
}

/// Predefined game states enum
enum GameState { loading, menu, playing, paused, gameOver, victory }

/// Predefined character states enum
enum CharacterState { idle, walking, running, jumping, falling, attacking, hurt, dead }
