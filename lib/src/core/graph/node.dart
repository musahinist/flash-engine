import 'dart:ffi';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import '../math/transform.dart';
import '../rendering/light.dart';
import '../native/particles_ffi.dart';
import 'tree.dart';
import 'signal.dart';

enum ProcessMode { inherit, always, paused, disabled }

class FNode {
  String name;
  final FTransform transform = FTransform();
  FNode? parent;
  final List<FNode> children = [];
  bool visible = true;
  bool billboard = false;

  // -- Native Scenegraph --
  int _nativeNodeId = -1;
  int get nativeNodeId => _nativeNodeId;
  Pointer<NativeNode>? _nativeNodePtr;
  int _lastFetchedVersion = -1;
  bool _localSyncNeeded = true;

  // -- Lifecycle --
  FSceneTree? _tree;
  FSceneTree? get tree => _tree;
  bool get isInsideTree => _tree != null;

  ProcessMode processMode = ProcessMode.inherit;

  /// Current lighting for this node (available during draw)
  List<FLightNode> _currentLights = [];
  List<FLightNode> get lights => _currentLights;

  bool _worldDirty = true;
  final Matrix4 _cachedWorldMatrix = Matrix4.identity();
  Vector3? _cachedWorldPosition;

  /// AABB for Frustum Culling. If null, node is always drawn.
  Rect? get bounds => null;

  // -- Groups --
  final Set<String> _groups = {};

  // -- Signals --
  /// Emitted when the node enters the SceneTree.
  final FSignalVoid treeEntered = FSignalVoid();

  /// Emitted when the node exits the SceneTree.
  final FSignalVoid treeExited = FSignalVoid();

  FNode({this.name = 'FNode'}) {
    transform.onChanged = setWorldDirty;
  }

  // -- Groups API --

  void addToGroup(String group) {
    if (_groups.add(group)) {
      if (isInsideTree) {
        _tree!.registerNodeToGroup(this, group);
      }
    }
  }

  void removeFromGroup(String group) {
    if (_groups.remove(group)) {
      if (isInsideTree) {
        _tree!.unregisterNodeFromGroup(this, group);
      }
    }
  }

  bool isInGroup(String group) => _groups.contains(group);

  // -- Lifecycle Virtual Methods (Godot Style) --

  /// Called when the node enters the SceneTree.
  void enterTree() {}

  /// Called when the node is "ready", i.e. when all children have entered the tree.
  void ready() {}

  /// Called when the node is about to exit the SceneTree.
  void exitTree() {}

  /// Called every frame if processing is enabled.
  void process(double dt) {}

  // -- Internal Lifecycle --

  /// Internal: Propagates enterTree notification
  void propagateEnterTree(FSceneTree gameTree) {
    if (_tree != null) return; // Already in tree
    _tree = gameTree;

    // Register groups with the new tree
    for (final group in _groups) {
      gameTree.registerNodeToGroup(this, group);
    }

    enterTree();
    treeEntered.emit();

    // Create Native Node
    final nativeScene = gameTree.engine.nativeScene;
    final parentNativeId = parent?.nativeNodeId ?? -1;
    _nativeNodeId = FlashNativeParticles.createNativeNode!(nativeScene, parentNativeId);
    if (_nativeNodeId != -1) {
      _nativeNodePtr = Pointer<NativeNode>.fromAddress(
        nativeScene.ref.nodes.address + _nativeNodeId * sizeOf<NativeNode>(),
      );
      _syncToNative();
    }

    for (final child in children) {
      child.propagateEnterTree(gameTree);
    }

    propagateReady();
  }

  void propagateReady() {
    ready();
  }

  void propagateExitTree() {
    if (_tree == null) return;

    // Unregister groups from the old tree
    for (final group in _groups) {
      _tree!.unregisterNodeFromGroup(this, group);
    }

    exitTree();
    treeExited.emit();

    for (final child in children) {
      child.propagateExitTree();
    }
    _tree = null;
  }

  void dispose() {
    for (final child in children) {
      child.dispose();
    }
  }

  void addChild(FNode child) {
    if (child.parent != null) {
      child.parent!.removeChild(child);
    }
    child.parent = this;
    children.add(child);
    child.setWorldDirty();

    if (isInsideTree) {
      child.propagateEnterTree(_tree!);
    }
  }

  void removeChild(FNode child) {
    if (children.remove(child)) {
      if (child.isInsideTree) {
        child.propagateExitTree();
      }
      child.parent = null;
      child.setWorldDirty();
    }
  }

  /// Mark this node and all its descendants as dirty
  void setWorldDirty() {
    if (_worldDirty) return;
    _worldDirty = true;
    _localSyncNeeded = true;
    _cachedWorldPosition = null;
    _nativeNodePtr?.ref.dirty = 1;
    for (final child in children) {
      child.setWorldDirty();
    }
  }

  void queueFree() {
    if (parent != null) {
      parent!.removeChild(this);
    }
  }

  /// Recursively find a child node by its name.
  FNode? findChild(String name, {bool recursive = true}) {
    for (final child in children) {
      if (child.name == name) return child;
      if (recursive) {
        final found = child.findChild(name, recursive: true);
        if (found != null) return found;
      }
    }
    return null;
  }

  void update(double dt) {
    if (!_canProcess()) return;

    _syncToNative();
    process(dt);

    for (final child in List.of(children)) {
      child.update(dt);
    }
  }

  bool _canProcess() {
    if (processMode == ProcessMode.disabled) return false;
    if (processMode == ProcessMode.always) return true;
    if (processMode == ProcessMode.inherit) {
      if (parent != null) return parent!._canProcess();
      return true; // Root defaults to true
    }

    // Manage Paused state via Tree (TODO)
    // if (tree?.paused == true && processMode == ProcessMode.paused) ...
    return true;
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
  void renderSelf(Canvas canvas, Matrix4 viewportProjectionMatrix, List<FLightNode> activeLights) {
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
    if (_nativeNodePtr != null) {
      final nativeScene = _tree!.engine.nativeScene.ref;
      if (_lastFetchedVersion != nativeScene.totalUpdates) {
        final nm = _nativeNodePtr!.ref.worldMatrix;
        _cachedWorldMatrix.setValues(
          nm.m0,
          nm.m1,
          nm.m2,
          nm.m3,
          nm.m4,
          nm.m5,
          nm.m6,
          nm.m7,
          nm.m8,
          nm.m9,
          nm.m10,
          nm.m11,
          nm.m12,
          nm.m13,
          nm.m14,
          nm.m15,
        );
        _lastFetchedVersion = nativeScene.totalUpdates;
        _worldDirty = false;
      }
      return _cachedWorldMatrix;
    }

    if (_worldDirty || transform.isDirty) {
      if (parent == null || parent is! FNode) {
        _cachedWorldMatrix.setFrom(transform.matrix);
      } else {
        _cachedWorldMatrix.setFrom((parent as FNode).worldMatrix * transform.matrix);
      }
      _worldDirty = false;
    }
    return _cachedWorldMatrix;
  }

  void _syncToNative() {
    if (_nativeNodePtr == null || !_localSyncNeeded) return;
    final n = _nativeNodePtr!.ref;
    final pos = transform.position;
    final rot = transform.rotation;
    final scale = transform.scale;

    n.posX = pos.x;
    n.posY = pos.y;
    n.posZ = pos.z;
    n.rotX = rot.x;
    n.rotY = rot.y;
    n.rotZ = rot.z;
    n.scaleX = scale.x;
    n.scaleY = scale.y;
    n.scaleZ = scale.z;
    n.visible = visible ? 1 : 0;
    _localSyncNeeded = false;
  }
}
