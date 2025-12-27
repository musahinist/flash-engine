import 'package:flutter/material.dart';
import '../graph/scene.dart';

/// Scene transition types
enum SceneTransition { none, fade, slideLeft, slideRight, slideUp, slideDown, scale, rotate }

/// Scene state
enum SceneState { entering, active, exiting, inactive }

/// Scene wrapper for managing scene lifecycle
class FSceneWrapper {
  final String name;
  final FSceneRoot scene;
  final Widget Function(BuildContext context, FSceneRoot scene)? builder;

  SceneState state = SceneState.inactive;
  double transitionProgress = 0;

  /// Called when scene becomes active
  void Function()? onEnter;

  /// Called when scene becomes inactive
  void Function()? onExit;

  /// Called every frame while active
  void Function(double dt)? onUpdate;

  FSceneWrapper({required this.name, FSceneRoot? scene, this.builder, this.onEnter, this.onExit, this.onUpdate})
    : scene = scene ?? FSceneRoot(name: name);
}

/// Scene manager for handling multiple scenes and transitions
class FSceneManager extends ChangeNotifier {
  final Map<String, FSceneWrapper> _scenes = {};
  String? _currentSceneName;
  String? _previousSceneName;

  SceneTransition _transition = SceneTransition.none;
  double _transitionDuration = 0.5;
  double _transitionProgress = 0;
  bool _isTransitioning = false;

  /// Register a scene
  void registerScene(FSceneWrapper scene) {
    _scenes[scene.name] = scene;
  }

  /// Unregister a scene
  void unregisterScene(String name) {
    _scenes.remove(name);
    if (_currentSceneName == name) {
      _currentSceneName = null;
    }
  }

  /// Get current scene
  FSceneWrapper? get currentScene => _currentSceneName != null ? _scenes[_currentSceneName] : null;

  /// Get previous scene (during transition)
  FSceneWrapper? get previousScene => _previousSceneName != null ? _scenes[_previousSceneName] : null;

  /// Check if transitioning
  bool get isTransitioning => _isTransitioning;

  /// Transition progress (0-1)
  double get transitionProgress => _transitionProgress;

  /// Current transition type
  SceneTransition get transition => _transition;

  /// All registered scene names
  List<String> get sceneNames => _scenes.keys.toList();

  /// Go to a scene with optional transition
  void goTo(String sceneName, {SceneTransition transition = SceneTransition.fade, double duration = 0.5}) {
    if (!_scenes.containsKey(sceneName)) {
      debugPrint('Scene "$sceneName" not found');
      return;
    }

    if (_currentSceneName == sceneName) return;
    if (_isTransitioning) return;

    _previousSceneName = _currentSceneName;
    _currentSceneName = sceneName;
    _transition = transition;
    _transitionDuration = duration;
    _transitionProgress = 0;
    _isTransitioning = duration > 0;

    // Update states
    previousScene?.state = SceneState.exiting;
    currentScene?.state = SceneState.entering;

    if (!_isTransitioning) {
      _completeTransition();
    }

    notifyListeners();
  }

  /// Update scene manager (call every frame)
  void update(double dt) {
    // Update current scene
    currentScene?.onUpdate?.call(dt);

    // Handle transition
    if (_isTransitioning && _transitionDuration > 0) {
      _transitionProgress += dt / _transitionDuration;

      if (_transitionProgress >= 1) {
        _transitionProgress = 1;
        _completeTransition();
      }

      notifyListeners();
    }
  }

  void _completeTransition() {
    _isTransitioning = false;

    // Call lifecycle callbacks
    previousScene?.onExit?.call();
    previousScene?.state = SceneState.inactive;

    currentScene?.onEnter?.call();
    currentScene?.state = SceneState.active;

    _previousSceneName = null;
  }

  /// Get transition offset for slide animations
  Offset getTransitionOffset(Size size, {bool isEntering = true}) {
    final progress = isEntering ? (1 - _transitionProgress) : _transitionProgress;

    switch (_transition) {
      case SceneTransition.slideLeft:
        return Offset(size.width * (isEntering ? 1 : -1) * progress, 0);
      case SceneTransition.slideRight:
        return Offset(size.width * (isEntering ? -1 : 1) * progress, 0);
      case SceneTransition.slideUp:
        return Offset(0, size.height * (isEntering ? 1 : -1) * progress);
      case SceneTransition.slideDown:
        return Offset(0, size.height * (isEntering ? -1 : 1) * progress);
      default:
        return Offset.zero;
    }
  }

  /// Get transition opacity for fade animations
  double getTransitionOpacity({bool isEntering = true}) {
    if (_transition != SceneTransition.fade) return 1;
    return isEntering ? _transitionProgress : (1 - _transitionProgress);
  }

  /// Get transition scale for scale animations
  double getTransitionScale({bool isEntering = true}) {
    if (_transition != SceneTransition.scale) return 1;
    final progress = isEntering ? _transitionProgress : (1 - _transitionProgress);
    return 0.5 + (0.5 * progress);
  }

  /// Get transition rotation for rotate animations
  double getTransitionRotation({bool isEntering = true}) {
    if (_transition != SceneTransition.rotate) return 0;
    final progress = isEntering ? (1 - _transitionProgress) : _transitionProgress;
    return progress * 0.5; // Half rotation
  }
}

/// Widget for rendering scene transitions
class FSceneTransitionWidget extends StatelessWidget {
  final FSceneManager sceneManager;
  final Widget Function(FSceneWrapper scene) builder;

  const FSceneTransitionWidget({super.key, required this.sceneManager, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sceneManager,
      builder: (context, _) {
        final currentScene = sceneManager.currentScene;
        final previousScene = sceneManager.previousScene;

        if (currentScene == null) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              children: [
                // Previous scene (during transition)
                if (previousScene != null && sceneManager.isTransitioning)
                  _buildSceneWidget(previousScene, size, isEntering: false),

                // Current scene
                _buildSceneWidget(currentScene, size, isEntering: true),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSceneWidget(FSceneWrapper scene, Size size, {required bool isEntering}) {
    Widget child = builder(scene);

    // Apply transition effects
    switch (sceneManager.transition) {
      case SceneTransition.fade:
        child = Opacity(
          opacity: sceneManager.getTransitionOpacity(isEntering: isEntering),
          child: child,
        );
        break;
      case SceneTransition.slideLeft:
      case SceneTransition.slideRight:
      case SceneTransition.slideUp:
      case SceneTransition.slideDown:
        final offset = sceneManager.getTransitionOffset(size, isEntering: isEntering);
        child = Transform.translate(offset: offset, child: child);
        break;
      case SceneTransition.scale:
        child = Transform.scale(
          scale: sceneManager.getTransitionScale(isEntering: isEntering),
          child: Opacity(
            opacity: sceneManager.getTransitionOpacity(isEntering: isEntering),
            child: child,
          ),
        );
        break;
      case SceneTransition.rotate:
        child = Transform.rotate(
          angle: sceneManager.getTransitionRotation(isEntering: isEntering),
          child: Opacity(
            opacity: sceneManager.getTransitionOpacity(isEntering: isEntering),
            child: child,
          ),
        );
        break;
      case SceneTransition.none:
        break;
    }

    return child;
  }
}
