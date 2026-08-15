import 'package:flash/src/core/graph/node.dart';
import 'package:flash/src/core/graph/signal.dart';
import 'package:flash/src/core/systems/physics.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// FRayCast2D Node - Casts a ray and reports collisions.
///
/// Mimics Godot's RayCast2D:
/// - `targetPosition`: The end point of the ray (relative to this node or absolute).
/// - `enabled`: Whether the ray is actively casting.
/// - `colliding`: Whether the ray is currently hitting something.
/// - `collisionPoint`: World position of the hit.
/// - `collisionNormal`: Surface normal at the hit point.
/// - `colliderBodyId`: The BodyId of the hit physics body.
///
/// Signals:
/// - `bodyEntered(BodyId)`: Emitted when the ray first hits a body.
/// - `bodyExited(BodyId)`: Emitted when the ray stops hitting a body.
class FRayCast2D extends FNode {
  /// The end point of the ray relative to this node's origin.
  v.Vector2 targetPosition;

  /// Whether the ray should actively cast.
  bool enabled;

  /// Color for debug drawing.
  Color debugColor;

  /// Whether to draw the ray visually.
  bool debugDraw;

  // --- State ---
  bool _colliding = false;
  v.Vector2 _collisionPoint = v.Vector2.zero();
  v.Vector2 _collisionNormal = v.Vector2.zero();
  BodyId? _colliderBodyId;
  BodyId? _previousColliderBodyId;

  // --- Signals ---
  final FSignal<BodyId> bodyEntered = FSignal();
  final FSignal<BodyId> bodyExited = FSignal();

  // --- World Reference ---
  WorldId? _world;

  FRayCast2D({
    super.name = 'RayCast2D',
    v.Vector2? targetPosition,
    this.enabled = true,
    this.debugDraw = true,
    this.debugColor = Colors.red,
  }) : targetPosition = targetPosition ?? v.Vector2(0, -100);

  /// Set the physics world this raycast operates in.
  void setWorld(WorldId world) {
    _world = world;
  }

  // --- Getters ---
  bool get isColliding => _colliding;
  v.Vector2 get collisionPoint => _collisionPoint;
  v.Vector2 get collisionNormal => _collisionNormal;
  BodyId? get colliderBodyId => _colliderBodyId;

  @override
  void update(double dt) {
    super.update(dt);

    if (!enabled || _world == null) {
      _colliding = false;
      return;
    }

    // Calculate world-space ray start and end
    final from = v.Vector2(transform.position.x, transform.position.y);
    final to = from + targetPosition;

    final hit = FPhysicsSystem.rayCast(_world!, from.x, from.y, to.x, to.y);

    _previousColliderBodyId = _colliderBodyId;

    if (hit != null) {
      _colliding = true;
      _collisionPoint = v.Vector2(hit.x, hit.y);
      _collisionNormal = v.Vector2(hit.normalX, hit.normalY);
      _colliderBodyId = hit.bodyId;

      // Emit signal if we just started hitting this body
      if (_previousColliderBodyId != _colliderBodyId) {
        if (_previousColliderBodyId != null) {
          bodyExited.emit(_previousColliderBodyId!);
        }
        bodyEntered.emit(_colliderBodyId!);
      }
    } else {
      _colliding = false;
      _colliderBodyId = null;

      // Emit signal if we just stopped hitting
      if (_previousColliderBodyId != null) {
        bodyExited.emit(_previousColliderBodyId!);
      }
    }
  }

  @override
  void render(Canvas canvas, v.Matrix4 globalTransform) {
    super.render(canvas, globalTransform);

    if (!debugDraw) return;

    final from = Offset(transform.position.x, transform.position.y);
    final to = from + Offset(targetPosition.x, targetPosition.y);

    final paint = Paint()
      ..color = _colliding ? Colors.green : debugColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw the ray line
    if (_colliding) {
      // Draw to hit point, then a small indicator to target
      final hitOffset = Offset(_collisionPoint.x, _collisionPoint.y);
      canvas.drawLine(from, hitOffset, paint);

      // Draw normal at hit point
      final normalEnd = hitOffset + Offset(_collisionNormal.x * 20, _collisionNormal.y * 20);
      final normalPaint = Paint()
        ..color = Colors.yellow
        ..strokeWidth = 2.0;
      canvas.drawLine(hitOffset, normalEnd, normalPaint);

      // Draw a circle at hit point
      canvas.drawCircle(hitOffset, 5, Paint()..color = Colors.green);
    } else {
      canvas.drawLine(from, to, paint);
    }
  }
}
