import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class StateMachineDemoExample extends StatefulWidget {
  const StateMachineDemoExample({super.key});

  @override
  State<StateMachineDemoExample> createState() => _StateMachineDemoExampleState();
}

class _StateMachineDemoExampleState extends State<StateMachineDemoExample> with FlashEventMixin {
  late FlashStateMachine<CharacterState> _characterSM;
  int _score = 0;
  int _health = 100;
  String _lastEventMsg = 'No events yet';

  @override
  void initState() {
    super.initState();

    // Initialize State Machine
    _characterSM = FlashStateMachine<CharacterState>();

    _characterSM.addStates({
      CharacterState.idle: FlashSimpleState(name: 'Idle', enter: (prev) => debugPrint('Entered Idle from $prev')),
      CharacterState.walking: FlashSimpleState(name: 'Walking', update: (dt) => debugPrint('Character is walking...')),
      CharacterState.jumping: FlashSimpleState(
        name: 'Jumping',
        enter: (prev) {
          debugPrint('JUMP!');
          // Auto transition back to idle after a delay
          Future.delayed(const Duration(seconds: 1), () {
            if (_characterSM.isInState(CharacterState.jumping)) {
              _characterSM.transitionTo(CharacterState.idle);
            }
          });
        },
      ),
      CharacterState.hurt: FlashSimpleState(
        name: 'Hurt',
        enter: (prev) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_characterSM.isInState(CharacterState.hurt)) {
              _characterSM.transitionTo(CharacterState.idle);
            }
          });
        },
      ),
    });

    _characterSM.transitionTo(CharacterState.idle);

    // Subscribe to events using FlashEventMixin
    subscribe<ScoreChangedEvent>((event) {
      if (mounted) setState(() => _score = event.newScore);
    });

    subscribe<PlayerDamageEvent>((event) {
      if (mounted) {
        setState(() {
          _health = event.remainingHealth;
          _lastEventMsg = 'Took ${event.damage} damage!';
        });
        _characterSM.transitionTo(CharacterState.hurt);
      }
    });

    subscribe<FlashSignal>((event) {
      if (mounted) setState(() => _lastEventMsg = 'Signal received: ${event.signal}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('State Machine & Event Demo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Flash(
        child: Builder(
          builder: (context) {
            final engine = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>()?.engine;
            if (engine != null) {
              engine.onUpdate = () => _characterSM.update(1 / 60.0);
            }

            return Stack(
              children: [
                // Camera
                FlashCameraWidget(position: v.Vector3(0, 0, 500), fov: 60),

                // Character Visualization
                Center(
                  child: FlashStateMachineWidget<CharacterState>(
                    machine: _characterSM,
                    builder: (context, state) {
                      Color color = Colors.blue;
                      double scale = 1.0;
                      double rotation = 0.0;

                      switch (state) {
                        case CharacterState.idle:
                          color = Colors.blue;
                          break;
                        case CharacterState.walking:
                          color = Colors.green;
                          scale = 1.1;
                          break;
                        case CharacterState.jumping:
                          color = Colors.orange;
                          scale = 1.5;
                          break;
                        case CharacterState.hurt:
                          color = Colors.red;
                          rotation = 0.5;
                          break;
                        default:
                          break;
                      }

                      return FlashCube(
                        position: v.Vector3(0, state == CharacterState.jumping ? 100 : 0, 0),
                        size: 80,
                        color: color,
                        scale: v.Vector3(scale, scale, scale),
                        rotation: v.Vector3(0, rotation, 0),
                      );
                    },
                  ),
                ),

                // UI Overlay
                Positioned(
                  top: 100,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoText('State: ${_characterSM.currentState?.name ?? "None"}', Colors.cyanAccent),
                      _infoText('Health: $_health', _health > 30 ? Colors.greenAccent : Colors.redAccent),
                      _infoText('Score: $_score', Colors.yellowAccent),
                      const SizedBox(height: 20),
                      _infoText('Last Event: $_lastEventMsg', Colors.white70),
                    ],
                  ),
                ),

                // Controls
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _controlBtn('WALK', () => _characterSM.transitionTo(CharacterState.walking)),
                      _controlBtn('IDLE', () => _characterSM.transitionTo(CharacterState.idle)),
                      _controlBtn('JUMP', () => _characterSM.transitionTo(CharacterState.jumping)),
                      _controlBtn('HURT', () {
                        emit(PlayerDamageEvent(10, _health - 10));
                      }),
                      _controlBtn('COIN', () {
                        emit(ScoreChangedEvent(_score, _score + 100));
                        signal('COIN_COLLECTED');
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoText(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))],
      ),
    );
  }

  Widget _controlBtn(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white10,
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white30),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
