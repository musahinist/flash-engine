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

  /// Current lighting for this node (available during draw)
  List<FlashLight> _currentLights = [];
  List<FlashLight> get lights => _currentLights;

  bool _worldDirty = true;
  final Matrix4 _cachedWorldMatrix = Matrix4.identity();
  Vector3? _cachedWorldPosition;

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
  void renderSelf(Canvas canvas, Matrix4 viewportProjectionMatrix, List<FlashLight> activeLights) {
    if (!visible) return;

    _currentLights = activeLights;
    final renderMatrix = viewportProjectionMatrix * worldMatrix;

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
