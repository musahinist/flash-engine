import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../../core/systems/verlet.dart';
import '../framework.dart';
import '../../core/systems/engine.dart';

/// Declarative widget for creating Verlet rope physics
class FRope extends StatefulWidget {
  /// Starting anchor position
  final v.Vector3 anchorPosition;

  /// Number of rope segments
  final int segments;

  /// Total rope length
  final double length;

  /// Gravity applied to rope
  final v.Vector3 gravity;

  /// Damping factor (0-1)
  final double damping;

  /// Number of constraint solver iterations
  final int constraintIterations;

  /// Called with rope positions on each update
  final void Function(List<v.Vector3> positions)? onUpdate;

  /// Custom painter for rope rendering
  final CustomPainter Function(List<v.Vector3> positions)? painter;

  FRope({
    super.key,
    required this.anchorPosition,
    this.segments = 10,
    this.length = 100,
    v.Vector3? gravity,
    this.damping = 0.98,
    this.constraintIterations = 5,
    this.onUpdate,
    this.painter,
  }) : gravity = gravity ?? v.Vector3(0, -300, 0);

  @override
  State<FRope> createState() => FRopeState();
}

class FRopeState extends State<FRope> {
  late FVerletRopeJoint _rope;

  /// Access rope positions directly
  List<v.Vector3> get positions => _rope.positions;

  /// Move the anchor point to a new position
  void moveAnchor(v.Vector3 position) {
    _rope.movePoint(0, position);
  }

  /// Move any point on the rope
  void movePoint(int index, v.Vector3 position) {
    _rope.movePoint(index, position);
  }

  @override
  void initState() {
    super.initState();
    _createRope();
  }

  void _createRope() {
    _rope = FVerletRopeJoint(
      anchorA: widget.anchorPosition,
      segments: widget.segments,
      totalLength: widget.length,
      gravity: widget.gravity,
      damping: widget.damping,
      constraintIterations: widget.constraintIterations,
    );
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

  void _onEngineUpdate(double dt) {
    _rope.update(dt);
    widget.onUpdate?.call(_rope.positions);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _engine?.removeUpdateListener(_onEngineUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(FRope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.segments != oldWidget.segments ||
        widget.length != oldWidget.length ||
        widget.gravity != oldWidget.gravity) {
      _createRope();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.painter != null) {
      return CustomPaint(painter: widget.painter!(_rope.positions), size: Size.infinite);
    }
    // Default: no visual, just physics simulation
    return const SizedBox.shrink();
  }
}

/// Pre-built rope painter with glow effect
class FRopePainter extends CustomPainter {
  final List<v.Vector3> positions;
  final Color color;
  final double strokeWidth;
  final Offset center;
  final bool showNodes;

  FRopePainter({
    required this.positions,
    required this.color,
    this.strokeWidth = 4,
    required this.center,
    this.showNodes = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;

    final path = Path();
    path.moveTo(center.dx + positions.first.x, center.dy - positions.first.y);

    for (int i = 1; i < positions.length; i++) {
      path.lineTo(center.dx + positions[i].x, center.dy - positions[i].y);
    }

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = strokeWidth * 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Main line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Nodes
    if (showNodes) {
      final nodePaint = Paint()..color = const Color(0xFFFFFFFF);
      for (int i = 0; i < positions.length; i++) {
        final x = center.dx + positions[i].x;
        final y = center.dy - positions[i].y;
        final radius = i == 0 ? 10.0 : (i == positions.length - 1 ? 8.0 : 4.0);
        canvas.drawCircle(Offset(x, y), radius, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FRopePainter oldDelegate) => true;
}
