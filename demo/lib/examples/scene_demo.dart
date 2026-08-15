import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Demonstrates scene management with transitions using engine.sceneManager
class SceneManagerDemoExample extends StatefulWidget {
  const SceneManagerDemoExample({super.key});

  @override
  State<SceneManagerDemoExample> createState() => _SceneManagerDemoExampleState();
}

class _SceneManagerDemoExampleState extends State<SceneManagerDemoExample> {
  SceneTransition _selectedTransition = SceneTransition.fade;
  bool _initialized = false;

  final List<SceneTransition> _transitions = [
    SceneTransition.fade,
    SceneTransition.slideLeft,
    SceneTransition.slideRight,
    SceneTransition.slideUp,
    SceneTransition.slideDown,
    SceneTransition.scale,
    SceneTransition.rotate,
  ];

  void _initScenes(FSceneManager sceneManager) {
    if (_initialized) return;
    _initialized = true;

    // Register scenes with engine.sceneManager
    sceneManager.registerScene(
      FSceneWrapper(name: 'menu', onEnter: () => debugPrint('Menu entered'), onExit: () => debugPrint('Menu exited')),
    );

    sceneManager.registerScene(
      FSceneWrapper(name: 'game', onEnter: () => debugPrint('Game entered'), onExit: () => debugPrint('Game exited')),
    );

    sceneManager.registerScene(
      FSceneWrapper(
        name: 'settings',
        onEnter: () => debugPrint('Settings entered'),
        onExit: () => debugPrint('Settings exited'),
      ),
    );

    // Start at menu
    sceneManager.goTo('menu', transition: SceneTransition.none);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(title: const Text('Scene Manager Demo'), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: FView(
        child: Builder(
          builder: (context) {
            final inherited = context.dependOnInheritedWidgetOfExactType<InheritedFNode>();
            final engine = inherited?.engine;

            if (engine == null) {
              return const Center(
                child: Text('Engine not found', style: TextStyle(color: Colors.white)),
              );
            }

            // Initialize scenes using engine.sceneManager (auto-updated by engine)
            _initScenes(engine.sceneManager);

            // Listen to scene manager changes
            engine.addUpdateListener((dt) => setState(() {}));

            return Stack(
              children: [
                // Camera
                FCamera(position: v.Vector3(0, 0, 500), fov: 60),

                // Scene content with transitions
                FSceneTransitionWidget(
                  sceneManager: engine.sceneManager, // Use engine's sceneManager
                  builder: (scene) => _buildSceneContent(scene.name),
                ),

                // Controls
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Current scene indicator
                        Text(
                          '📍 Current: ${engine.sceneManager.currentScene?.name ?? "none"}',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        // Transition selector
                        const Text('🎭 Transition:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 35,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _transitions.map((t) {
                              final isSelected = _selectedTransition == t;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedTransition = t),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.greenAccent : Colors.white24,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      t.name,
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Scene buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSceneButton(engine.sceneManager, 'menu', Icons.home, Colors.blueAccent),
                            _buildSceneButton(engine.sceneManager, 'game', Icons.games, Colors.orangeAccent),
                            _buildSceneButton(engine.sceneManager, 'settings', Icons.settings, Colors.purpleAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSceneButton(FSceneManager sm, String name, IconData icon, Color color) {
    final isActive = sm.currentScene?.name == name;
    return GestureDetector(
      onTap: () {
        if (!isActive && !sm.isTransitioning) {
          sm.goTo(name, transition: _selectedTransition, duration: 0.5);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Colors.white : color, size: 28),
            const SizedBox(height: 4),
            Text(
              name.toUpperCase(),
              style: TextStyle(color: isActive ? Colors.white : color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneContent(String name) {
    switch (name) {
      case 'menu':
        return _buildScene(Icons.home, 'MENU', 'Welcome to Flash Engine!', Colors.blue);
      case 'game':
        return _buildScene(Icons.games, 'GAME', 'Your game content here!', Colors.orange);
      case 'settings':
        return _buildScene(Icons.settings, 'SETTINGS', 'Configure your preferences', Colors.purple);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildScene(IconData icon, String title, String subtitle, MaterialColor color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.shade900, color.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 60),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
