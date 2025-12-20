import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../graph/scene.dart';
import '../rendering/camera.dart';
import '../systems/physics.dart';
import 'audio.dart';

class FlashEngine extends ChangeNotifier {
  final FlashScene scene = FlashScene();
  final FlashAudioSystem audio = FlashAudioSystem();
  FlashCamera? activeCamera;
  FlashPhysicsWorld? physicsWorld;
  FlashCamera? _defaultCamera; // Cached default camera to avoid per-frame allocation
  final Set<FlashCamera> _activeCameras = {}; // Track all cameras in scene

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
  void registerCamera(FlashCamera camera) {
    _activeCameras.add(camera);
  }

  /// Unregister a camera when it's removed from the scene
  void unregisterCamera(FlashCamera camera) {
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

    // Use first visible registered camera (O(1) instead of O(n) tree traversal)
    activeCamera = _activeCameras.firstWhere(
      (cam) => cam.visible,
      orElse: () {
        _defaultCamera ??= FlashCamera(name: 'DefaultCamera');
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
