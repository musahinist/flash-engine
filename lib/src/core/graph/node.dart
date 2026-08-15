import 'dart:ffi';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import '../math/transform.dart';
import '../rendering/light.dart';
import '../native/flash_native_bindings.dart' as native;
import '../native/flash_native_bindings.dart' show NativeNode;
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

  /// Coarse draw order. Lower layers paint first, before any depth sorting.
  /// Useful for backgrounds and tilemaps that must sit behind everything.
  int sortLayer = 0;

  /// Monotonic creation index, used as a stable final tie-break in the
  /// painter. hashCode was used before, which is not stable across runs and
  /// changes when a node is recreated.
  final int creationIndex = _nextCreationIndex++;
  static int _nextCreationIndex = 0;

  // -- Native Scenegraph --
  int _nativeNodeId = -1;
  int get nativeNodeId => _nativeNodeId;
  Pointer<NativeNode>? _nativeNodePtr;
  int _lastFetchedVersion = -1;

  /// Debug-only count of how many times the world matrix was pulled across
  /// the FFI boundary. Lets a test assert that a stationary node stops
  /// re-reading. Only maintained when asserts are enabled.
  @visibleForTesting
  int debugMatrixFetchCount = 0;
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

    // Claim a native transform slot when the native core is present. Without
    // one, worldMatrix falls back to computing the hierarchy in Dart.
    if (gameTree.engine.hasNativeSceneGraph) {
      final nativeScene = gameTree.engine.nativeScene;
      final parentNativeId = parent?.nativeNodeId ?? -1;
      _nativeNodeId = native.createNativeNode(nativeScene, parentNativeId);
      if (_nativeNodeId != -1) {
        _nativeNodePtr = Pointer<NativeNode>.fromAddress(
          nativeScene.ref.nodes.address + _nativeNodeId * sizeOf<NativeNode>(),
        );
        _syncToNative();
      }
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

    _releaseNativeNode();
    _tree = null;
  }

  /// Returns this node's slot to the native scene pool.
  ///
  /// The pool is fixed-size (10k slots). Without this, every add/remove cycle
  /// burned a slot permanently and `create_native_node` eventually started
  /// returning -1, silently dropping nodes onto the pure-Dart transform path.
  void _releaseNativeNode() {
    final ptr = _nativeNodePtr;
    if (ptr == null || _nativeNodeId < 0) return;

    final engine = _tree?.engine;
    if (engine != null && engine.hasNativeSceneGraph) {
      native.destroyNativeNode(engine.nativeScene, _nativeNodeId);
    }

    _nativeNodePtr = null;
    _nativeNodeId = -1;
    _lastFetchedVersion = -1;
    // Fall back to Dart-side transform maths from here on.
    _worldDirty = true;
    _localSyncNeeded = true;
    _cachedWorldPosition = null;
  }

  void dispose() {
    for (final child in children) {
      child.dispose();
    }
    _releaseNativeNode();
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

  /// Mark this node and all its descendants as dirty.
  ///
  /// There used to be an `if (_worldDirty) return;` short-circuit here, which
  /// looked like a harmless recursion guard but wasn't: `_worldDirty` is only
  /// cleared when the `worldMatrix` getter runs. A node that is culled or
  /// invisible never has its matrix read, so the flag stayed set, every later
  /// transform change bailed out before setting `_localSyncNeeded`, and
  /// `_syncToNative()` went quiet — the node froze in C++ and reappeared at a
  /// stale position once it became visible again.
  void setWorldDirty() {
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

  /// Drives this node and its subtree for one frame.
  ///
  /// This is the pump, not the extension point — override [process] instead.
  /// Subclasses used to override `update` and do their work *after* calling
  /// `super.update(dt)`, which meant two things went wrong: [processMode] was
  /// ignored entirely (the work ran even when disabled), and the parent's
  /// frame work landed after its children had already read it.
  void update(double dt, [int frame = -1]) {
    if (!_canProcess(frame)) return;

    _syncToNative();
    process(dt);

    // Iterate by index and re-check the length each step: a node that adds or
    // removes children during process() is handled without copying the list
    // for every node in the scene, every frame.
    for (int i = 0; i < children.length; i++) {
      children[i].update(dt, frame);
    }
  }

  // Cached for one frame. ProcessMode.inherit made this walk to the root for
  // every node on every frame, which is O(nodes x depth) to answer a question
  // whose answer cannot change mid-frame.
  int _processFrame = -1;
  bool _processCached = false;

  bool _canProcess([int frame = -1]) {
    if (frame >= 0 && _processFrame == frame) return _processCached;

    final bool result;
    switch (processMode) {
      case ProcessMode.disabled:
        result = false;
      case ProcessMode.always:
        // Runs even while the tree is paused.
        result = true;
      case ProcessMode.paused:
        // Godot semantics: only runs *while* paused.
        result = _tree?.paused ?? false;
      case ProcessMode.inherit:
        if (_tree?.paused ?? false) {
          result = false;
        } else {
          result = parent?._canProcess(frame) ?? true;
        }
    }

    if (frame >= 0) {
      _processFrame = frame;
      _processCached = result;
    }
    return result;
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
    // A node can hold a native slot while its tree reference is being torn
    // down, so this must not assume _tree is still attached.
    final engine = _tree?.engine;
    if (_nativeNodePtr != null && engine != null && engine.hasNativeSceneGraph) {
      final n = _nativeNodePtr!.ref;
      // Gate on this node's own worldVersion, which C++ only bumps when it
      // actually recomputes the matrix. The scene-wide totalUpdates was used
      // here before, and that increments unconditionally every frame — so the
      // comparison was always true and every node re-read 16 floats across the
      // FFI boundary every frame, moving or not.
      if (_lastFetchedVersion != n.worldVersion) {
        final nm = n.worldMatrix;
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
        _lastFetchedVersion = n.worldVersion;
        _worldDirty = false;
        assert(() {
          debugMatrixFetchCount++;
          return true;
        }());
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
    // Catches `transform.position.x += 5` style edits, which bypass the
    // setters and so never fired onChanged.
    transform.syncExternalMutations();

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
