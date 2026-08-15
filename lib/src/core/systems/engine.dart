import 'dart:ffi';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../graph/node.dart';
import '../graph/tree.dart';
import '../grids/tilemap_node.dart';
import '../rendering/camera.dart';
import '../rendering/light.dart';
import '../systems/physics.dart';
import '../systems/particle.dart';
import '../native/flash_native_bindings.dart' as native;
import '../native/flash_native_bindings.dart' show NativeScene;
import '../native/flash_native.dart';
import 'audio.dart';
import 'profiler.dart';
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

  /// Per-section frame timing. Disabled by default; see [FProfiler].
  final FProfiler profiler = FProfiler();

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

  /// The fallback camera used when no FCamera widget is present.
  ///
  /// It is attached to the scene so it receives process() ticks like any other
  /// node — the old lazily-created one lived outside the tree, so follow and
  /// shake would silently do nothing on it.
  FCameraNode _ensureDefaultCamera() {
    var camera = _defaultCamera;
    if (camera == null) {
      camera = FCameraNode(name: 'DefaultCamera');
      _defaultCamera = camera;
      scene.addChild(camera);
    }
    return camera;
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

  /// Runs one frame with an explicit delta, bypassing the Ticker.
  ///
  /// Benchmarks and tests need to drive the loop faster than vsync; without
  /// this the only way in was a real Ticker, which pins measurement to the
  /// display refresh.
  @visibleForTesting
  void debugTick(double dt) => _runFrame(dt, elapsed + dt);

  void _tick(Duration elapsedDuration) {
    final currentTime = elapsedDuration.inMicroseconds / Duration.microsecondsPerSecond;
    _runFrame(currentTime - _lastTime, currentTime);
  }

  void _runFrame(double dt, double currentTime) {
    profiler.beginFrame();

    // Clear "justPressed/justReleased" states from previous frame
    input.beginFrame();

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
    profiler.section('tree', () => tree.process(dt, tickerCount));

    // Pausing the tree has to pause the simulation with it. These three used
    // to keep running regardless, so a "paused" game still had physics
    // settling and tweens finishing underneath the pause menu.
    if (!tree.paused) {
      profiler.section('physics', () {
        physicsWorld?.update(dt);
        sceneManager.update(dt);
        tweenManager.update(dt);
      });
    }

    // Update Native Transforms Hierarchy
    final nativeScenePtr = _nativeScene;
    if (nativeScenePtr != null) {
      profiler.section('transforms', () => native.updateSceneTransforms(nativeScenePtr));
    }

    // Use first visible registered camera (O(1) instead of O(n) tree traversal)
    activeCamera = _activeCameras.firstWhere((cam) => cam.visible, orElse: _ensureDefaultCamera);
    // Cameras cache their projection/view/screen matrices for one frame; this
    // is what tells them the frame moved on.
    activeCamera!.frameStamp = tickerCount;

    // Update Audio Listener
    audio.updateListener(activeCamera!);

    profiler.section('tilemaps', _updateTileMaps);
    profiler.section('prepareRender', _prepareRender);

    profiler.endFrame();

    notifyListeners();

    onUpdate?.call(dt);

    // Copy: a listener may remove itself (or another) during the callback.
    for (final listener in List.of(_updateListeners)) {
      listener(dt);
    }
  }

  /// Hands each tilemap the region it needs to draw. Doing this once per
  /// frame keeps the culling decision in one place instead of every tilemap
  /// reaching for the camera itself.
  void _updateTileMaps() {
    final camera = activeCamera;
    if (camera == null || viewportSize.x <= 0) return;
    tree.callGroup(FTileMapNode.group, (node) {
      if (node is FTileMapNode) {
        node.visibleRect = camera.getVisibleWorldRect(viewportSize).translate(
          -node.worldPosition.x,
          -node.worldPosition.z,
        );
      }
    });
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
      if (vpMatrix != null) {
        // bounds is a getter that builds a Rect; it was being called twice.
        final bounds = node.bounds;
        if (bounds != null) isVisible = _isNodeVisible(node, vpMatrix, bounds);
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

  // Scratch for the culling test, reused across nodes and frames. This used to
  // allocate a Matrix4, a List and eight Vector4s per bounded node per frame.
  final v.Matrix4 _cullMvp = v.Matrix4.identity();

  bool _isNodeVisible(FNode node, v.Matrix4 vpMatrix, Rect bounds) {
    // MVP = VP * World, computed in place.
    _cullMvp
      ..setFrom(vpMatrix)
      ..multiply(node.worldMatrix);
    final m = _cullMvp.storage;

    // Outcode per corner of the local bounds rect (at z = 0), ANDed together.
    // If every corner is outside the same plane the node cannot be visible.
    // Bailing out the moment the intersection empties also skips the rest.
    var andMask = 0x3F;
    for (int i = 0; i < 4; i++) {
      final x = (i == 0 || i == 3) ? bounds.left : bounds.right;
      final y = (i < 2) ? bounds.top : bounds.bottom;

      final cx = m[0] * x + m[4] * y + m[12];
      final cy = m[1] * x + m[5] * y + m[13];
      final cz = m[2] * x + m[6] * y + m[14];
      final cw = m[3] * x + m[7] * y + m[15];

      var code = 0;
      if (cx < -cw) code |= 1;
      if (cx > cw) code |= 2;
      if (cy < -cw) code |= 4;
      if (cy > cw) code |= 8;
      if (cz < -cw) code |= 16;
      if (cz > cw) code |= 32;

      andMask &= code;
      if (andMask == 0) return true;
    }
    return andMask == 0;
  }


}
