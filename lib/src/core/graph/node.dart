import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import '../math/transform.dart';
import '../rendering/light.dart';

class FlashNode {
  String name;
  final FlashTransform transform = FlashTransform();
  FlashNode? parent;
  final List<FlashNode> children = [];
  bool visible = true;
  bool billboard = false;

  /// Current lighting for this node (available during draw)
  List<FlashLightNode> _currentLights = [];
  List<FlashLightNode> get lights => _currentLights;

  bool _worldDirty = true;
  final Matrix4 _cachedWorldMatrix = Matrix4.identity();
  Vector3? _cachedWorldPosition;

  /// AABB for Frustum Culling. If null, node is always drawn.
  /// Subclasses should override this for performance.
  Rect? get bounds => null;

  FlashNode({this.name = 'FlashNode'}) {
    transform.onChanged = setWorldDirty;
  }

  void dispose() {
    for (final child in children) {
      child.dispose();
    }
  }

  void addChild(FlashNode child) {
    if (child.parent != null) {
      child.parent!.removeChild(child);
    }
    child.parent = this;
    children.add(child);
    child.setWorldDirty();
  }

  void removeChild(FlashNode child) {
    if (children.remove(child)) {
      child.parent = null;
      child.setWorldDirty();
    }
  }

  /// Mark this node and all its descendants as dirty
  void setWorldDirty() {
    if (_worldDirty) return;
    _worldDirty = true;
    _cachedWorldPosition = null;
    for (final child in children) {
      child.setWorldDirty();
    }
  }

  void update(double dt) {
    for (final child in children) {
      child.update(dt);
    }
  }

  void render(Canvas canvas, Matrix4 globalTransform) {
    if (!visible) return;

    final worldM = worldMatrix;

    canvas.save();
    canvas.transform(worldM.storage);
    draw(canvas);
    canvas.restore();

    for (final child in children) {
      child.render(canvas, worldM);
    }
  }

  /// Render only this node using its pre-calculated world matrix
  void renderSelf(Canvas canvas, Matrix4 viewportProjectionMatrix, List<FlashLightNode> activeLights) {
    if (!visible) return;

    // Frustum Culling check
    if (bounds != null) {
      // Very basic culling: Check if world position Z is behind camera is done in loop usually
      // Ideally we project bounds to screen and check intersection with viewport
      // For now, let's just skip if bounds are completely off-screen in simple 2D terms if needed
      // But we are in 3D, so we rely on standard pipeline for now.
      // Optimization: Subclasses with bounds will enable future spatial partitioning
    }

    _currentLights = activeLights;

    Matrix4 renderMatrix;
    if (billboard) {
      final worldPos = worldMatrix.getTranslation();
      final scaleX = Vector3(worldMatrix.storage[0], worldMatrix.storage[1], worldMatrix.storage[2]).length;
      final scaleY = Vector3(worldMatrix.storage[4], worldMatrix.storage[5], worldMatrix.storage[6]).length;
      final scaleZ = Vector3(worldMatrix.storage[8], worldMatrix.storage[9], worldMatrix.storage[10]).length;
      final avgScale = (scaleX + scaleY + scaleZ) / 3.0;

      renderMatrix = viewportProjectionMatrix.clone()
        ..translate(worldPos.x, worldPos.y, worldPos.z)
        ..scale(avgScale, avgScale, avgScale);
    } else {
      renderMatrix = viewportProjectionMatrix * worldMatrix;
    }

    canvas.save();
    canvas.transform(renderMatrix.storage);
    draw(canvas);
    canvas.restore();
  }

  /// Override this to draw the node's content.
  /// You can access [lights] to implement lighting effects.
  void draw(Canvas canvas) {}

  /// Calculate world position
  Vector3 get worldPosition {
    _cachedWorldPosition ??= worldMatrix.getTranslation();
    return _cachedWorldPosition!;
  }

  Matrix4 get worldMatrix {
    if (_worldDirty || transform.isDirty) {
      if (parent == null || parent is! FlashNode) {
        _cachedWorldMatrix.setFrom(transform.matrix);
      } else {
        _cachedWorldMatrix.setFrom((parent as FlashNode).worldMatrix * transform.matrix);
      }
      _worldDirty = false;
    }
    return _cachedWorldMatrix;
  }
}
