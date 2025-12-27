import 'package:demo/examples/rendering_demo.dart';
import 'package:flutter/material.dart';
import 'examples/basic_scene.dart';
import 'examples/solar_system.dart';
import 'examples/particle_field.dart';
import 'examples/physics_demo.dart';
import 'examples/depth_diorama.dart';
import 'examples/three_d_demo.dart';
import 'examples/lighting_demo.dart';
import 'examples/audio_demo.dart';
import 'examples/input_demo.dart';
import 'examples/particle_demo.dart';
import 'examples/tween_demo.dart';
import 'examples/scene_demo.dart';
import 'examples/state_machine_demo.dart';
import 'examples/collision_layers_demo.dart';
import 'examples/three_d_audio_demo.dart';
import 'examples/native_particle_demo.dart';
import 'examples/joints_demo.dart';
import 'examples/master_tech_demo.dart';
import 'examples/raycast_demo.dart';
import 'examples/timer_demo.dart';
import 'examples/pendulum_demo.dart';
import 'examples/soft_body_demo.dart';
import 'examples/sandbox_demo.dart';

void main() {
  runApp(const FlashDemoApp());
}

class FlashDemoApp extends StatelessWidget {
  const FlashDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flash Engine Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const ExampleMenu(),
    );
  }
}

class ExampleMenu extends StatelessWidget {
  const ExampleMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_ExampleData> examples = [
      _ExampleData(
        title: 'Basic Scene',
        description: '3D shapes & Z-sorting.',
        icon: Icons.grid_view_rounded,
        builder: (_) => BasicSceneExample(),
      ),
      _ExampleData(
        title: 'Solar System',
        description: 'Hierarchical nodes.',
        icon: Icons.brightness_high_rounded,
        builder: (_) => const SolarSystemExample(),
      ),
      _ExampleData(
        title: 'Particle Field',
        description: '200 particle stress test.',
        icon: Icons.bubble_chart_rounded,
        builder: (_) => const ParticleFieldExample(),
      ),
      _ExampleData(
        title: 'Native Physics',
        description: 'Native C++ world.',
        icon: Icons.architecture_rounded,
        builder: (_) => const PhysicsDemoExample(),
      ),
      _ExampleData(
        title: 'Kinetic Sculpture',
        description: 'Neon mechanical masterpiece.',
        icon: Icons.hub_rounded,
        builder: (_) => const JointsDemoExample(),
      ),
      _ExampleData(
        title: 'Neon Cradle',
        description: "Newton's Cradle physics.",
        icon: Icons.unfold_more_double_rounded,
        builder: (_) => const PendulumDemoExample(),
      ),
      _ExampleData(
        title: 'Neon Jelly',
        description: 'Soft body physics blob.',
        icon: Icons.vignette_rounded,
        builder: (_) => const SoftBodyDemoExample(),
      ),
      _ExampleData(
        title: 'Neon Sandbox',
        description: 'Draw lines & drop objects.',
        icon: Icons.architecture_rounded,
        builder: (_) => const SandboxDemoExample(),
      ),
      _ExampleData(
        title: '2.5D Diorama',
        description: 'Parallax & Z-sorting.',
        icon: Icons.layers_rounded,
        builder: (_) => const DepthDioramaExample(),
      ),
      _ExampleData(
        title: '3D Primitives',
        description: 'Cubes & primitive nodes.',
        icon: Icons.view_in_ar_rounded,
        builder: (_) => const ThreeDDemo(),
      ),
      _ExampleData(
        title: 'Dynamic Light',
        description: 'Point light system.',
        icon: Icons.lightbulb_outline_rounded,
        builder: (_) => const LightingDemo(),
      ),
      _ExampleData(
        title: 'Physics Audio',
        description: 'Native collision sounds.',
        icon: Icons.surround_sound_rounded,
        builder: (_) => const AudioDemo(),
      ),
      _ExampleData(
        title: '3D Audio Orbit',
        description: 'Moving listener demo.',
        icon: Icons.spatial_audio_off_rounded,
        builder: (_) => const ThreeDAudioDemo(),
      ),
      _ExampleData(
        title: 'Input System',
        description: 'Gestures & keyboard.',
        icon: Icons.gamepad_rounded,
        builder: (_) => const InputDemoExample(),
      ),
      _ExampleData(
        title: 'Particles',
        description: 'Fire, smoke, explosions.',
        icon: Icons.auto_awesome,
        builder: (_) => const ParticleDemoExample(),
      ),
      _ExampleData(
        title: 'Tweening',
        description: 'Property animations.',
        icon: Icons.animation,
        builder: (_) => const TweenDemoExample(),
      ),
      _ExampleData(
        title: 'Scene Manager',
        description: 'Transitions & effects.',
        icon: Icons.layers,
        builder: (_) => const SceneManagerDemoExample(),
      ),
      _ExampleData(
        title: 'State & Events',
        description: 'FSM & event bus.',
        icon: Icons.account_tree_rounded,
        builder: (_) => const StateMachineDemoExample(),
      ),
      _ExampleData(
        title: 'Collisions',
        description: 'Native impact test.',
        icon: Icons.filter_center_focus_rounded,
        builder: (_) => const CollisionLayersDemoExample(),
      ),
      _ExampleData(
        title: 'Native FFI Particles',
        description: '100k particles stress test.',
        icon: Icons.speed_rounded,
        builder: (_) => const NativeParticleDemo(),
      ),
      _ExampleData(
        title: 'Rendering',
        description: 'Path & trails.',
        icon: Icons.gesture_rounded,
        builder: (_) => const RenderingDemoExample(),
      ),
      _ExampleData(
        title: 'Master Tech Demo',
        description: 'Signals, Groups, Physics.',
        icon: Icons.verified_rounded,
        builder: (_) => const MasterTechDemo(),
      ),
      _ExampleData(
        title: 'RayCast Demo',
        description: 'Ray-based detection.',
        icon: Icons.flash_on_rounded,
        builder: (_) => const RayCastDemo(),
      ),
      _ExampleData(
        title: 'Timer Demo',
        description: 'Godot-style timers.',
        icon: Icons.timer_rounded,
        builder: (_) => const TimerDemo(),
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A12), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flash Engine',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Explore 2D/2.5D Rendering',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.cyanAccent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 40),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: examples.length,
                    itemBuilder: (context, index) {
                      final item = examples[index];
                      return _ExampleCard(
                        title: item.title,
                        description: item.description,
                        icon: item.icon,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: item.builder)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExampleData {
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;

  _ExampleData({required this.title, required this.description, required this.icon, required this.builder});
}

class _ExampleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ExampleCard({required this.title, required this.description, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.cyanAccent, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
