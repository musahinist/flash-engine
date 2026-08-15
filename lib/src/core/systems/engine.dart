import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../graph/node.dart';
import '../graph/tree.dart';
import '../rendering/camera.dart';
import '../rendering/light.dart';
import '../systems/physics.dart';
import '../systems/particle.dart';
import '../native/flash_native_bindings.dart' as native;
import '../native/flash_native_bindings.dart' show NativeScene;
import '../native/flash_native.dart';
import 'audio.dart';
import 'input.dart';
import 'scene_manager.dart';
import 'tween.dart';

class FEngine extends ChangeNotifier {
  late final FSceneTree tree;
  FNode get scene => tree.root;

  final FAudioSystem audio = FAudioSystem();
  final FInputSystem input = FInputSystem();
  final FSceneManager sceneManager = FSceneManager();
  final FTweenManager tweenManager = FTweenManager();

  /// Native transform hierarchy, or `null` when the native core is
  /// unavailable. Tier 0: the scene graph keeps working either way — [FNode]
  /// falls back to pure-Dart transform maths when it has no native slot.
  Pointer<NativeScene>? _nativeScene;

  /// The native scene pointer. Only valid when [hasNativeSceneGraph].
  Pointer<NativeScene> get nativeScene => _nativeScene!;

  /// Whether transforms are being resolved natively.
  bool get hasNativeSceneGraph => _nativeScene != null;

  /// Current viewport size in pixels
  v.Vector2 viewportSize = v.Vector2(0, 0);

  FCameraNode? activeCamera;
  FPhysicsSystem? physicsWorld;
  FCameraNode? _defaultCamera;
  final Set<FCameraNode> _activeCameras = {};

  // cached render lists to avoid allocation
  final List<FNode> renderNodes = [];
  final List<FLightNode> lights = [];
  final List<FParticleEmitter> emitters = [];

  late final Ticker _ticker;

  /// Per-frame callback owned by the host widget ([FView]).
  ///
  /// Receives the real frame delta. Widgets that need their own per-frame work
  /// must use [addUpdateListener] instead of assigning here — several used to
  /// "chain" this single slot by capturing the previous value, which leaked
  /// (never unsubscribed), grew on every didChangeDependencies, and was wiped
  /// wholesale by FView.didUpdateWidget.
  void Function(double dt)? onUpdate;

  final List<void Function(double dt)> _updateListeners = [];

  /// Subscribes [listener] to the frame loop. Safe to call from widget state;
  /// pair with [removeUpdateListener] in `dispose`.
  void addUpdateListener(void Function(double dt) listener) {
    _updateListeners.add(listener);
  }

  /// Unsubscribes a listener added with [addUpdateListener].
  void removeUpdateListener(void Function(double dt) listener) {
    _updateListeners.remove(listener);
  }
  double _lastTime = 0.0;
  int tickerCount = 0;
  double fps = 0.0;
  int _frameCount = 0;
  double _fpsLastMeasureTime = 0.0;

  /// Total elapsed time since engine started (in seconds).
  /// Use this for time-based animations without setState.
  double elapsed = 0.0;

  FEngine() {
    // Native scene graph (10k node pool). Must exist before the root node is
    // created. On a build without the native core this stays null and FNode
    // resolves world matrices in Dart instead — the scene graph, renderer,
    // cameras, tweens, timers, input and audio all still work.
    if (FlashNative.isAvailable) {
      _nativeScene = native.createNativeScene(10000);
    }

    tree = FSceneTree(this);

    _ticker = Ticker(_tick);
  }

  /// Register a camera when it's added to the scene
  void registerCamera(FCameraNode camera) {
    _activeCameras.add(camera);
  }

  /// Unregister a camera when it's removed from the scene
  void unregisterCamera(FCameraNode camera) {
    _activeCameras.remove(camera);
  }

  void start() {
    audio.init();
    _ticker.start();
  }

  /// Stops the frame loop and tears down the scene.
  ///
  /// Audio is disposed in [dispose], not here — FView calls stop() then
  /// dispose(), and doing it in both ran audio.dispose() twice.
  void stop() {
    _ticker.stop();
    scene.dispose();
  }

  @override
  void dispose() {
    _ticker.dispose();
    audio.dispose();
    final scene = _nativeScene;
    if (scene != null) {
      native.destroyNativeScene(scene);
      _nativeScene = null;
    }
    super.dispose();
  }

  void _tick(Duration elapsedDuration) {
    // Clear "justPressed/justReleased" states from previous frame
    input.beginFrame();

    final currentTime = elapsedDuration.inMicroseconds / Duration.microsecondsPerSecond;
    final dt = currentTime - _lastTime;
    _lastTime = currentTime;
    elapsed = currentTime; // Expose total elapsed time
    tickerCount++;
    _frameCount++;

    // Calculate FPS every second
    if (currentTime - _fpsLastMeasureTime >= 1.0) {
      fps = _frameCount / (currentTime - _fpsLastMeasureTime);
      _frameCount = 0;
      _fpsLastMeasureTime = currentTime;
    }

    // Process the SceneTree (lifecycle updates)
    tree.process(dt);

    // Pausing the tree has to pause the simulation with it. These three used
    // to keep running regardless, so a "paused" game still had physics
    // settling and tweens finishing underneath the pause menu.
    if (!tree.paused) {
      physicsWorld?.update(dt);
      sceneManager.update(dt);
      tweenManager.update(dt);
    }

    // Update Native Transforms Hierarchy
    final nativeScenePtr = _nativeScene;
    if (nativeScenePtr != null) {
      native.updateSceneTransforms(nativeScenePtr);
    }

    // Use first visible registered camera (O(1) instead of O(n) tree traversal)
    activeCamera = _activeCameras.firstWhere(
      (cam) => cam.visible,
      orElse: () {
        _defaultCamera ??= FCameraNode(name: 'DefaultCamera');
        return _defaultCamera!;
      },
    );

    // Update Audio Listener
    audio.updateListener(activeCamera!);

    _prepareRender();

    notifyListeners();

    onUpdate?.call(dt);

    // Copy: a listener may remove itself (or another) during the callback.
    for (final listener in List.of(_updateListeners)) {
      listener(dt);
    }
  }

  void _prepareRender() {
    renderNodes.clear();
    lights.clear();
    emitters.clear();

    if (activeCamera == null) {
      _collectNodes(scene, null);
      return;
    }

    final proj = activeCamera!.getProjectionMatrix(viewportSize.x, viewportSize.y);
    final view = activeCamera!.getViewMatrix();
    final vpMatrix = proj * view;

    _collectNodes(scene, vpMatrix);
  }

  /// Projects a world position to screen space pixels.
  v.Vector2? project(v.Vector3 worldPos) {
    if (activeCamera == null || viewportSize.x <= 0 || viewportSize.y <= 0) return null;

    final proj = activeCamera!.getProjectionMatrix(viewportSize.x, viewportSize.y);
    final view = activeCamera!.getViewMatrix();
    final vp = proj * view;

    final point = v.Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
    final res = vp * point;

    if (res.w == 0) return null;

    // NDC [-1, 1]
    final ndcX = res.x / res.w;
    final ndcY = res.y / res.w;

    // Map to Viewport Pixels [0, size]
    final screenX = (ndcX + 1.0) * viewportSize.x / 2.0;
    final screenY = (1.0 - ndcY) * viewportSize.y / 2.0;

    return v.Vector2(screenX, screenY);
  }

  void _collectNodes(FNode node, v.Matrix4? vpMatrix) {
    if (node != scene) {
      if (!node.visible) return;

      bool isVisible = true;
      if (vpMatrix != null && node.bounds != null) {
        isVisible = _isNodeVisible(node, vpMatrix);
      }

      if (isVisible) {
        if (node is FLightNode) {
          lights.add(node);
        } else if (node is FParticleEmitter) {
          emitters.add(node);
        } else {
          renderNodes.add(node);
        }
      }
    }

    // Recurse into children. An invisible node returned early above, so its
    // subtree is skipped with it — hiding a node hides its descendants.
    // Frustum culling, by contrast, only drops the node itself.
    for (final child in node.children) {
      _collectNodes(child, vpMatrix);
    }
  }

  bool _isNodeVisible(FNode node, v.Matrix4 vpMatrix) {
    final bounds = node.bounds!;
    // MVP = VP * World
    final mvp = vpMatrix * node.worldMatrix;

    // Check 4 corners of the local bounds rect (at z=0)
    final corners = [
      v.Vector4(bounds.left, bounds.top, 0.0, 1.0),
      v.Vector4(bounds.right, bounds.top, 0.0, 1.0),
      v.Vector4(bounds.right, bounds.bottom, 0.0, 1.0),
      v.Vector4(bounds.left, bounds.bottom, 0.0, 1.0),
    ];

    int outLeft = 0;
    int outRight = 0;
    int outTop = 0;
    int outBottom = 0;
    int outNear = 0;
    int outFar = 0;

    for (final p in corners) {
      final res = mvp * p;
      // Check NDC bounds [-w, w]
      if (res.x < -res.w) outLeft++;
      if (res.x > res.w) outRight++;
      if (res.y < -res.w) outTop++;
      if (res.y > res.w) outBottom++;
      // Z range depends on library, typically -w to w for GL-like
      if (res.z < -res.w) outNear++;
      if (res.z > res.w) outFar++;
    }

    // If all corners are outside of one plane, the object is culled
    if (outLeft == 4 || outRight == 4 || outTop == 4 || outBottom == 4 || outNear == 4 || outFar == 4) {
      return false;
    }

    return true;
  }
}
