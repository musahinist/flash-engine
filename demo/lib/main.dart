import 'package:flutter/material.dart';
import 'examples/basic_scene.dart';
import 'examples/solar_system.dart';
import 'examples/particle_field.dart';
import 'examples/physics_demo.dart';
import 'examples/depth_diorama.dart';
import 'examples/declarative_demo.dart';
import 'examples/godot_demo.dart';
import 'examples/three_d_demo.dart';
import 'examples/lighting_demo.dart';
import 'examples/audio_demo.dart';
import 'examples/input_demo.dart';
import 'examples/particle_demo.dart';
import 'examples/tween_demo.dart';
import 'examples/joint_demo.dart';
import 'examples/scene_demo.dart';
import 'examples/state_machine_demo.dart';

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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Text(
                  'Flash Engine',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Explore 2D/2.5D Rendering Examples',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.cyanAccent),
                ),
                const SizedBox(height: 60),
                Expanded(
                  child: ListView(
                    children: [
                      _ExampleCard(
                        title: 'Basic Scene',
                        description: 'Simple 3D shapes with random rotations and Z-sorting.',
                        icon: Icons.grid_view_rounded,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const BasicSceneExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Solar System',
                        description: 'Hierarchical node transformations (Sun > Earth > Moon).',
                        icon: Icons.brightness_high_rounded,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SolarSystemExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Particle Field',
                        description: 'Stress test with 200 independently moving particles.',
                        icon: Icons.bubble_chart_rounded,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ParticleFieldExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Physics World',
                        description: 'Rigid body dynamics with gravity and collisions (Forge2D).',
                        icon: Icons.architecture_rounded,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const PhysicsDemoExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: '2.5D Diorama',
                        description: 'Multi-layer Z-sorting and parallax effects.',
                        icon: Icons.layers_rounded,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const DepthDioramaExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Declarative API',
                        description: 'Build scenes with simple Widgets and Stacks.',
                        icon: Icons.code_rounded,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const DeclarativeDemoExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Godot-like Nodes',
                        description: 'Sprites, Labels, and RigidBody components.',
                        icon: Icons.rocket_launch_rounded,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GodotDemo())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: '3D Primitives',
                        description: 'Complex 3D objects like Cubes built with declarative nodes.',
                        icon: Icons.view_in_ar_rounded,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThreeDDemo())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Dynamic Lighting',
                        description: 'Point light system affecting 3D cubes and spheres.',
                        icon: Icons.lightbulb_outline_rounded,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LightingDemo())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: '3D Audio',
                        description: 'Spatial audio source with SoLoud integration.',
                        icon: Icons.surround_sound_rounded,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioDemo())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Input System',
                        description: 'Keyboard, mouse, and touch gesture handling.',
                        icon: Icons.gamepad_rounded,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const InputDemoExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Particle Effects',
                        description: 'Fire, smoke, sparkle, snow, and explosion effects.',
                        icon: Icons.auto_awesome,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ParticleDemoExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Tween Animation',
                        description: 'Smooth property animations with easing functions.',
                        icon: Icons.animation,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const TweenDemoExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Joint System',
                        description: 'Rope and spring physics with Verlet integration.',
                        icon: Icons.link,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const JointDemoExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'Scene Manager',
                        description: 'Scene transitions: fade, slide, scale, rotate.',
                        icon: Icons.layers,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SceneManagerDemoExample())),
                      ),
                      const SizedBox(height: 20),
                      _ExampleCard(
                        title: 'State & Events',
                        description: 'State machine transitions and global event bus.',
                        icon: Icons.account_tree_rounded,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StateMachineDemoExample())),
                      ),
                    ],
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

class _ExampleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ExampleCard({required this.title, required this.description, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.cyanAccent, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
