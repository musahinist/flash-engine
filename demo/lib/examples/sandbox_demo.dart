import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class SandboxDemoExample extends StatefulWidget {
  const SandboxDemoExample({super.key});

  @override
  State<SandboxDemoExample> createState() => _SandboxDemoExampleState();
}

class _SandboxDemoExampleState extends State<SandboxDemoExample> {
  late FPhysicsSystem physicsSystem;
  final List<_DrawnLine> _staticLines = [];
  final List<_DropObject> _dynamicObjects = [];
  int _sceneKeyCounter = 0;
  int _objectCounter = 0;

  // Optimized drawing state using ValueNotifier
  final ValueNotifier<List<Offset>> _currentPoints = ValueNotifier([]);

  @override
  void initState() {
    super.initState();
    FEngine.init();
    physicsSystem = FPhysicsSystem(gravity: v.Vector2(0, -900));
  }

  @override
  void dispose() {
    physicsSystem.dispose();
    _currentPoints.dispose();
    super.dispose();
  }

  // Optimize: Simplify line by skipping points that are too close
  void _addStaticLine(List<Offset> points, Size boxSize) {
    if (points.length < 2) return;

    const double worldHeight = 1000.0;
    final scale = worldHeight / boxSize.height;

    v.Vector2 toWorld(Offset p) {
      return v.Vector2((p.dx - boxSize.width / 2) * scale, -(p.dy - boxSize.height / 2) * scale);
    }

    setState(() {
      v.Vector2 lastPoint = toWorld(points[0]);
      for (int i = 1; i < points.length; i++) {
        final currentPoint = toWorld(points[i]);
        final delta = currentPoint - lastPoint;
        final length = delta.length;

        // OPTIMIZATION: Merge small segments into longer ones
        if (length < 15 && i < points.length - 1) continue;

        final center = lastPoint + (delta * 0.5);
        final angle = atan2(delta.y, delta.x);

        _staticLines.add(_DrawnLine(position: center, length: length, angle: angle, color: Colors.cyanAccent));
        lastPoint = currentPoint;
      }
    });
  }

  void _spawnObject() {
    final rnd = Random();
    setState(() {
      _dynamicObjects.add(
        _DropObject(
          id: _objectCounter++,
          position: v.Vector2((rnd.nextDouble() - 0.5) * 600, 480),
          size: 20.0 + rnd.nextDouble() * 15.0,
          isCircle: rnd.nextBool(),
          color: [
            Colors.orangeAccent,
            Colors.pinkAccent,
            Colors.greenAccent,
            Colors.purpleAccent,
            Colors.yellowAccent,
            Colors.blueAccent,
          ][rnd.nextInt(6)],
        ),
      );
    });

    if (_dynamicObjects.length > 200) {
      // Increased capacity for massive world building
      _dynamicObjects.removeAt(0);
    }
  }

  void _clear() {
    final oldPhysics = physicsSystem;
    setState(() {
      _sceneKeyCounter++; // Forces FScene (and FEngine) to restart
      physicsSystem = FPhysicsSystem(gravity: v.Vector2(0, -900));
      _staticLines.clear();
      _dynamicObjects.clear();
      _objectCounter = 0;
      _currentPoints.value = [];
    });

    // Safe disposal of native world after the current frame finishes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldPhysics.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020205),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          _currentPoints.value = [box.globalToLocal(details.globalPosition)];
        },
        onPanUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          // OPTIMIZATION: ValueNotifier update avoids full scene rebuild
          final newPoint = box.globalToLocal(details.globalPosition);
          if (_currentPoints.value.isEmpty || (newPoint - _currentPoints.value.last).distance > 5) {
            _currentPoints.value = [..._currentPoints.value, newPoint];
          }
        },
        onPanEnd: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          _addStaticLine(_currentPoints.value, box.size);
          _currentPoints.value = [];
        },
        child: FScene(
          key: ValueKey(_sceneKeyCounter),
          physicsWorld: physicsSystem,
          enableInputCapture: false,
          showDebugOverlay: true,
          scene: [
            const _NeonGrid(),
            FCamera(position: v.Vector3(0, 0, 1000), isOrthographic: true, orthographicSize: 500.0),

            // BOUNDARIES
            FStaticBody(position: v.Vector3(0, -510, 0), width: 2000, height: 20, color: Colors.transparent),
            FStaticBody(position: v.Vector3(-510, 0, 0), width: 20, height: 2000, color: Colors.transparent),
            FStaticBody(position: v.Vector3(510, 0, 0), width: 20, height: 2000, color: Colors.transparent),

            // STATIC LINES
            for (int i = 0; i < _staticLines.length; i++)
              FStaticBody(
                key: ValueKey('line_${_sceneKeyCounter}_$i'),
                position: v.Vector3(_staticLines[i].position.x, _staticLines[i].position.y, 0),
                width: _staticLines[i].length,
                height: 10,
                rotation: v.Vector3(0, 0, _staticLines[i].angle),
                color: _staticLines[i].color,
                restitution: 0.7,
                debugDraw: true,
              ),

            // DYNAMIC OBJECTS
            for (final obj in _dynamicObjects)
              obj.isCircle
                  ? FRigidBody.circle(
                      key: ValueKey('obj_${obj.id}'),
                      position: v.Vector3(obj.position.x, obj.position.y, 0),
                      radius: obj.size / 2,
                      color: obj.color,
                      restitution: 0.6,
                      friction: 0.2,
                      debugDraw: true,
                    )
                  : FRigidBody(
                      key: ValueKey('obj_${obj.id}'),
                      position: v.Vector3(obj.position.x, obj.position.y, 0),
                      width: obj.size,
                      height: obj.size,
                      color: obj.color,
                      restitution: 0.4,
                      friction: 0.4,
                      debugDraw: true,
                    ),
          ],
          overlay: [_buildHUD(), _buildDrawingOverlay()],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton.extended(
              heroTag: 'spawn',
              onPressed: _spawnObject,
              label: const Text('SPAWN'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            const SizedBox(width: 16),
            FloatingActionButton.extended(
              heroTag: 'clear',
              onPressed: _clear,
              label: const Text('CLEAR'),
              icon: const Icon(Icons.delete_sweep),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    return Positioned(
      top: 40,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HUDLabel(text: 'MODE: NEON_ARCHITECT', color: Colors.cyanAccent),
          const SizedBox(height: 4),
          _HUDLabel(
            text: 'BODIES: ${_staticLines.length + _dynamicObjects.length}',
            color: Colors.white.withValues(alpha: 0.3),
            isSmall: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingOverlay() {
    return ValueListenableBuilder<List<Offset>>(
      valueListenable: _currentPoints,
      builder: (context, points, _) {
        return IgnorePointer(
          child: CustomPaint(
            painter: _DrawingPainter(points: points),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

// --- MODELS ---

class _DrawnLine {
  final v.Vector2 position;
  final double length;
  final double angle;
  final Color color;
  _DrawnLine({required this.position, required this.length, required this.angle, required this.color});
}

class _DropObject {
  final int id;
  final v.Vector2 position;
  final double size;
  final bool isCircle;
  final Color color;
  _DropObject({
    required this.id,
    required this.position,
    required this.size,
    required this.isCircle,
    required this.color,
  });
}

// --- VISUALS ---

class _DrawingPainter extends CustomPainter {
  final List<Offset> points;
  _DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

class _NeonGrid extends StatelessWidget {
  const _NeonGrid();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: CustomPaint(painter: _GridPainter()));
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 60) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 60) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _HUDLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool isSmall;
  const _HUDLabel({required this.text, required this.color, this.isSmall = false});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        fontSize: isSmall ? 10 : 14,
        letterSpacing: 1.5,
      ),
    );
  }
}
