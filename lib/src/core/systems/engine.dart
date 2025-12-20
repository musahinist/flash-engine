import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../graph/scene.dart';
import '../rendering/camera.dart';
import '../systems/physics.dart';
import 'audio.dart';
import 'input.dart';
import 'scene_manager.dart';
import 'tween.dart';

class FlashEngine extends ChangeNotifier {
  final FlashScene scene = FlashScene();
  final FlashAudioSystem audio = FlashAudioSystem();
  final FlashInputSystem input = FlashInputSystem();
  final FlashSceneManager sceneManager = FlashSceneManager();
  final FlashTweenManager tweenManager = FlashTweenManager();

  /// Current viewport size in pixels
  v.Vector2 viewportSize = v.Vector2(0, 0);

  FlashCameraNode? activeCamera;
  FlashPhysicsSystem? physicsWorld;
  FlashCameraNode? _defaultCamera;
  final Set<FlashCameraNode> _activeCameras = {};

  late final Ticker _ticker;

  VoidCallback? onUpdate;
  double _lastTime = 0.0;
  int tickerCount = 0;
  double fps = 0.0;
  int _frameCount = 0;
  double _fpsLastMeasureTime = 0.0;

  FlashEngine() {
    _ticker = Ticker(_tick);
  }

  /// Register a camera when it's added to the scene
  void registerCamera(FlashCameraNode camera) {
    _activeCameras.add(camera);
  }

  /// Unregister a camera when it's removed from the scene
  void unregisterCamera(FlashCameraNode camera) {
    _activeCameras.remove(camera);
  }

  void start() {
    audio.init();
    _ticker.start();
  }

  void stop() {
    _ticker.stop();
    audio.dispose();
  }

  void _tick(Duration elapsed) {
    // Clear "justPressed/justReleased" states from previous frame
    input.beginFrame();

    final currentTime = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final dt = currentTime - _lastTime;
    _lastTime = currentTime;
    tickerCount++;
    _frameCount++;

    // Calculate FPS every second
    if (currentTime - _fpsLastMeasureTime >= 1.0) {
      fps = _frameCount / (currentTime - _fpsLastMeasureTime);
      _frameCount = 0;
      _fpsLastMeasureTime = currentTime;
    }

    scene.update(dt);
    physicsWorld?.update(dt);
    sceneManager.update(dt);
    tweenManager.update(dt);

    // Use first visible registered camera (O(1) instead of O(n) tree traversal)
    activeCamera = _activeCameras.firstWhere(
      (cam) => cam.visible,
      orElse: () {
        _defaultCamera ??= FlashCameraNode(name: 'DefaultCamera');
        return _defaultCamera!;
      },
    );

    // Update Audio Listener
    audio.updateListener(activeCamera!);

    notifyListeners();

    if (onUpdate != null) {
      onUpdate!();
    }
  }
}
