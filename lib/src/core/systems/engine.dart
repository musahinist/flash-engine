import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../graph/node.dart';
import '../graph/tree.dart';
import '../rendering/camera.dart';
import '../rendering/light.dart';
import '../systems/physics.dart';
import '../systems/particle.dart';
import '../native/particles_ffi.dart';
import 'audio.dart';
import 'input.dart';
import 'scene_manager.dart';
import 'tween.dart';

class FEngine extends ChangeNotifier {
  final FSceneTree tree = FSceneTree();
  FNode get scene => tree.root;

  final FAudioSystem audio = FAudioSystem();
  final FInputSystem input = FInputSystem();
  final FSceneManager sceneManager = FSceneManager();
  final FTweenManager tweenManager = FTweenManager();

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

  VoidCallback? onUpdate;
  double _lastTime = 0.0;
  int tickerCount = 0;
  double fps = 0.0;
  int _frameCount = 0;
  double _fpsLastMeasureTime = 0.0;

  /// Total elapsed time since engine started (in seconds).
  /// Use this for time-based animations without setState.
  double elapsed = 0.0;

  FEngine() {
    // Ensure native libraries are loaded
    init();
    _ticker = Ticker(_tick);
  }

  /// Manually initialize native libraries (if using components without FEngine instance)
  static void init() {
    try {
      FlashNativeParticles.init();
    } catch (e) {
      print('Failed to initialize native particles: $e');
    }
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
    FlashNativeParticles.init();
    _ticker.start();
  }

  void stop() {
    _ticker.stop();
    // Do NOT dispose audio here if we want to restart?
    // But stop() is called by Flash.dispose().
    // We should clean up scene first
    scene.dispose(); // Stops all audio nodes
    audio.dispose();
  }

  @override
  void dispose() {
    // physicsWorld is owned by the creator (e.g. FView widget or Game), not the Engine.
    // Do not dispose it here to avoid double-free if the creator also disposes it.
    _ticker.dispose();
    audio.dispose();
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

    physicsWorld?.update(dt);
    sceneManager.update(dt);
    tweenManager.update(dt);

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

    if (onUpdate != null) {
      onUpdate!();
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

    // Always recurse into children (unless the node logic explicitly culls children too, which we don't do here)
    // Note: If !node.visible, we returned early, so children are skipped (correct for visibility graph).
    // But for culling, we must continue.
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
