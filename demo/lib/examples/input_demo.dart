import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class InputDemoExample extends StatefulWidget {
  const InputDemoExample({super.key});

  @override
  State<InputDemoExample> createState() => _InputDemoExampleState();
}

class _InputDemoExampleState extends State<InputDemoExample> {
  // Player position
  v.Vector3 _playerPos = v.Vector3(0, 0, 0);
  final double _speed = 300.0;

  // Gesture feedback
  String _lastGesture = 'None';
  int _touchCount = 0;
  double _pinchScale = 1.0;

  // Virtual joystick
  Offset _joystickOffset = Offset.zero;
  bool _joystickActive = false;

  @override
  void initState() {
    super.initState();
    FEngine.init(); // Initialize native libraries
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(title: const Text('Input System Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: FView(
        autoUpdate: true,
        enableInputCapture: true,
        child: Builder(
          builder: (context) {
            final engineWidget = context.dependOnInheritedWidgetOfExactType<InheritedFNode>();
            final engine = engineWidget?.engine;

            if (engine == null) {
              return const Center(
                child: Text('Engine not found', style: TextStyle(color: Colors.white)),
              );
            }

            // Register default movement actions
            engine.input.registerActions([
              FInputAction.moveUp,
              FInputAction.moveDown,
              FInputAction.moveLeft,
              FInputAction.moveRight,
              FInputAction.jump,
            ]);

            // Update logic
            engine.onUpdate = () {
              final dt = 1 / 60.0;
              final input = engine.input;

              // Desktop keyboard movement (Flash uses Y-up, so negate)
              final movement = input.getMovementVector();
              _playerPos.x += movement.dx * _speed * dt;
              _playerPos.y -= movement.dy * _speed * dt; // Negate: screen Y-down → world Y-up

              // Mobile virtual joystick movement (also negate Y)
              if (_joystickActive) {
                _playerPos.x += _joystickOffset.dx * _speed * dt;
                _playerPos.y -= _joystickOffset.dy * _speed * dt; // Negate Y
              }

              // Clamp position to screen bounds
              _playerPos.x = _playerPos.x.clamp(-350, 350);
              _playerPos.y = _playerPos.y.clamp(-200, 200);

              // Update gesture feedback
              setState(() {
                _touchCount = input.touchCount;
                _pinchScale = input.pinchScale;

                if (input.isDoubleTap) {
                  _lastGesture = '👆👆 Double Tap!';
                  _playerPos = v.Vector3(0, 0, 0); // Reset position
                } else if (input.isLongPressTriggered) {
                  _lastGesture = '👇 Long Press!';
                } else if (input.swipeDirection != null) {
                  _lastGesture = '👉 Swipe ${input.swipeDirection!.name}';
                } else if (input.isPinching) {
                  _lastGesture = '🤏 Pinch (${_pinchScale.toStringAsFixed(2)}x)';
                }
              });
            };

            return Stack(
              children: [
                // Camera
                FCamera(position: v.Vector3(0, 0, 500), fov: 60),

                // Light Source - at the center of the scene
                FLight(position: v.Vector3(0, 0, 100), color: Colors.white, intensity: 1.5),
                // Player - use clone() to ensure new reference on each build
                FSphere(position: _playerPos.clone(), radius: 30, color: Colors.cyanAccent),

                // Control hints (top)
                Positioned(
                  left: 16,
                  top: 100,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🎮 Controls',
                          style: TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Desktop: WASD / Arrows', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('Mobile: Virtual Joystick', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('Double Tap: Reset', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                // Gesture feedback (right side)
                Positioned(
                  right: 16,
                  top: 100,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Last: $_lastGesture',
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Touches: $_touchCount', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          'Pos: (${_playerPos.x.toInt()}, ${_playerPos.y.toInt()})',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                // Virtual Joystick (bottom left)
                Positioned(left: 40, bottom: 80, child: _buildVirtualJoystick()),

                // Action Button (bottom right)
                Positioned(
                  right: 40,
                  bottom: 100,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _lastGesture = '🔵 Action Button!';
                      });
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.cyanAccent.withValues(alpha: 0.3),
                        border: Border.all(color: Colors.cyanAccent, width: 3),
                      ),
                      child: const Icon(Icons.flash_on, color: Colors.cyanAccent, size: 32),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVirtualJoystick() {
    const double baseSize = 120;
    const double knobSize = 50;
    const double maxOffset = (baseSize - knobSize) / 2;

    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _joystickActive = true;
        });
      },
      onPanUpdate: (details) {
        final center = const Offset(baseSize / 2, baseSize / 2);
        var delta = details.localPosition - center;

        // Clamp to circle
        if (delta.distance > maxOffset) {
          delta = delta / delta.distance * maxOffset;
        }

        setState(() {
          _joystickOffset = Offset(delta.dx / maxOffset, delta.dy / maxOffset);
        });
      },
      onPanEnd: (_) {
        setState(() {
          _joystickActive = false;
          _joystickOffset = Offset.zero;
        });
      },
      child: Container(
        width: baseSize,
        height: baseSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: Colors.white30, width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: _joystickOffset * maxOffset,
            child: Container(
              width: knobSize,
              height: knobSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _joystickActive ? Colors.cyanAccent.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.3),
                border: Border.all(color: _joystickActive ? Colors.cyanAccent : Colors.white54, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
