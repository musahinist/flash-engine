import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FStateController] driving what gets drawn, with [FEventBus] on top.
///
/// The state machine decides the character's state; [FStateMachine] rebuilds
/// from it. The event bus is how unrelated parts talk: pressing HURT emits a
/// `PlayerDamageEvent` and nothing calls the state machine directly — a
/// subscriber does, on receipt.
class StateMachineDemoExample extends StatefulWidget {
  const StateMachineDemoExample({super.key});

  @override
  State<StateMachineDemoExample> createState() => _StateMachineDemoExampleState();
}

class _StateMachineDemoExampleState extends State<StateMachineDemoExample> with FEventMixin {
  late final FStateController<CharacterState> _machine;
  FEngine? _engine;

  int _score = 0;
  int _health = 100;
  String _lastEvent = 'none yet';

  @override
  void initState() {
    super.initState();

    _machine = FStateController<CharacterState>()
      ..addStates({
        CharacterState.idle: FSimpleState(name: 'Idle'),
        CharacterState.walking: FSimpleState(name: 'Walking'),
        // Timed states return to idle on their own. A dart:async Future is
        // used rather than an FTimer only because the machine is not a node.
        CharacterState.jumping: FSimpleState(
          name: 'Jumping',
          enter: (_) => _returnToIdle(CharacterState.jumping, const Duration(seconds: 1)),
        ),
        CharacterState.hurt: FSimpleState(
          name: 'Hurt',
          enter: (_) => _returnToIdle(CharacterState.hurt, const Duration(milliseconds: 500)),
        ),
      })
      ..transitionTo(CharacterState.idle);

    // Subscriptions are managed by FEventMixin, which cancels them on dispose.
    subscribe<ScoreChangedEvent>((event) {
      if (mounted) setState(() => _score = event.newScore);
    });
    subscribe<PlayerDamageEvent>((event) {
      if (!mounted) return;
      setState(() {
        _health = event.remainingHealth;
        _lastEvent = 'PlayerDamageEvent(${event.damage})';
      });
      _machine.transitionTo(CharacterState.hurt);
    });
    subscribe<FSignalEvent>((event) {
      if (mounted) setState(() => _lastEvent = 'FSignalEvent(${event.signal})');
    });
  }

  void _returnToIdle(CharacterState from, Duration after) {
    Future.delayed(after, () {
      if (mounted && _machine.isInState(from)) _machine.transitionTo(CharacterState.idle);
    });
  }

  /// Advances the machine once per frame. Registered from onReady — doing it
  /// from build() added a listener on every rebuild.
  void _attach(FEngine engine) {
    if (_engine != null) return;
    _engine = engine;
    engine.addUpdateListener(_machine.update);
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'State Machine',
      subtitle: 'FStateController picks the visual; FEventBus carries the news.',
      controls: [
        DemoPanel(
          title: 'Transition',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                DemoButton(
                  label: 'Idle',
                  selected: _machine.isInState(CharacterState.idle),
                  onPressed: () => _machine.transitionTo(CharacterState.idle),
                ),
                DemoButton(
                  label: 'Walk',
                  tint: DemoTheme.positive,
                  selected: _machine.isInState(CharacterState.walking),
                  onPressed: () => _machine.transitionTo(CharacterState.walking),
                ),
                DemoButton(
                  label: 'Jump',
                  tint: DemoTheme.warning,
                  selected: _machine.isInState(CharacterState.jumping),
                  onPressed: () => _machine.transitionTo(CharacterState.jumping),
                ),
              ],
            ),
          ],
        ),
        DemoPanel(
          title: 'Emit an event',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                DemoButton(
                  label: 'Damage',
                  icon: Icons.heart_broken_rounded,
                  tint: DemoTheme.danger,
                  onPressed: () => emit(PlayerDamageEvent(10, (_health - 10).clamp(0, 100))),
                ),
                DemoButton(
                  label: 'Coin',
                  icon: Icons.monetization_on_rounded,
                  tint: DemoTheme.warning,
                  onPressed: () {
                    emit(ScoreChangedEvent(_score, _score + 100));
                    signal('COIN_COLLECTED');
                  },
                ),
                DemoButton(
                  label: 'Heal',
                  icon: Icons.healing_rounded,
                  tint: DemoTheme.positive,
                  onPressed: () => setState(() => _health = 100),
                ),
              ],
            ),
          ],
        ),
      ],
      readouts: [
        DemoStat(label: 'State', value: _machine.currentState?.name ?? 'none'),
        DemoStat(
          label: 'Health',
          value: '$_health',
          tint: _health > 30 ? DemoTheme.positive : DemoTheme.danger,
        ),
        DemoStat(label: 'Score', value: '$_score', tint: DemoTheme.warning),
        DemoStat(label: 'Last event', value: _lastEvent),
      ],
      hint: 'Damage goes through the bus: nothing calls the state machine directly.',
      scene: FView(
        onReady: _attach,
        child: Stack(
          children: [
            FCamera(position: v.Vector3(0, 0, 500), fov: 60),
            FStateMachine<CharacterState>(
              machine: _machine,
              builder: (context, state) {
                final look = switch (state) {
                  CharacterState.walking => (DemoTheme.positive, 1.1, 0.0, 0.0),
                  CharacterState.jumping => (DemoTheme.warning, 1.5, 0.0, 100.0),
                  CharacterState.hurt => (DemoTheme.danger, 1.0, 0.5, 0.0),
                  _ => (DemoTheme.accent, 1.0, 0.0, 0.0),
                };
                return FCube(
                  position: v.Vector3(0, look.$4, 0),
                  size: 80,
                  color: look.$1,
                  scale: v.Vector3.all(look.$2),
                  rotation: v.Vector3(0, look.$3, 0),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
