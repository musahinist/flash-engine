import 'package:flutter/material.dart';

import 'examples/area_demo.dart';
import 'examples/audio_demo.dart';
import 'examples/basic_scene.dart';
import 'examples/collision_layers_demo.dart';
import 'examples/depth_diorama.dart';
import 'examples/event_bus_demo.dart';
import 'examples/grid_ai_demo.dart';
import 'examples/grid_camera_demo.dart';
import 'examples/input_demo.dart';
import 'examples/joints_demo.dart';
import 'examples/lighting_demo.dart';
import 'examples/master_tech_demo.dart';
import 'examples/native_particle_demo.dart';
import 'examples/native_soft_body_demo.dart';
import 'examples/particle_demo.dart';
import 'examples/particle_field.dart';
import 'examples/pendulum_demo.dart';
import 'examples/physics_demo.dart';
import 'examples/procedural_demo.dart';
import 'examples/profiler_demo.dart';
import 'examples/raycast_demo.dart';
import 'examples/rendering_demo.dart';
import 'examples/rope_demo.dart';
import 'examples/sandbox_demo.dart';
import 'examples/scene_demo.dart';
import 'examples/soft_body_demo.dart';
import 'examples/solar_system.dart';
import 'examples/sprite_demo.dart';
import 'examples/state_machine_demo.dart';
import 'examples/three_d_audio_demo.dart';
import 'examples/three_d_demo.dart';
import 'examples/tilemap_demo.dart';
import 'examples/timer_demo.dart';
import 'examples/tween_builder_demo.dart';
import 'examples/tween_demo.dart';
import 'games/games_catalog.dart';
import 'shared/demo_catalog.dart';
import 'shared/demo_theme.dart';

void main() => runApp(const FlashDemoApp());

class FlashDemoApp extends StatelessWidget {
  const FlashDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flash Engine',
      debugShowCheckedModeBanner: false,
      theme: DemoTheme.materialTheme(),
      home: const ExampleMenu(),
    );
  }
}

/// The catalogue.
///
/// Grouped by what part of the engine an example exercises, rather than the
/// single flat grid this used to be — at thirty-odd entries a flat list is a
/// wall, and the ordering carried no meaning.
class ExampleMenu extends StatelessWidget {
  const ExampleMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogPage(
      title: 'Flash Engine',
      subtitle: 'A 2.5D engine for Flutter, with a native C++ core.',
      sections: [
        CatalogSection(
          title: 'Scene graph',
          entries: [
            CatalogEntry(
              title: 'Basic Scene',
              description: 'Primitives and Z-sorting under one camera.',
              icon: Icons.grid_view_rounded,
              builder: (_) => const BasicSceneExample(),
            ),
            CatalogEntry(
              title: 'Solar System',
              description: 'Nested FNodes: a child inherits its parent transform.',
              icon: Icons.brightness_high_rounded,
              builder: (_) => const SolarSystemExample(),
            ),
            CatalogEntry(
              title: '3D Primitives',
              description: 'FCube, FSphere, FBox and FLabel in depth.',
              icon: Icons.view_in_ar_rounded,
              builder: (_) => const ThreeDDemo(),
            ),
            CatalogEntry(
              title: '2.5D Diorama',
              description: 'Parallax from Z depth alone.',
              icon: Icons.layers_rounded,
              builder: (_) => const DepthDioramaExample(),
            ),
            CatalogEntry(
              title: 'Sprites',
              description: 'FSprite: atlas frames, flipping and animation.',
              icon: Icons.image_rounded,
              builder: (_) => const SpriteDemo(),
            ),
            CatalogEntry(
              title: 'Rendering',
              description: 'FLineRenderer and FTrailRenderer.',
              icon: Icons.gesture_rounded,
              builder: (_) => const RenderingDemoExample(),
            ),
            CatalogEntry(
              title: 'Dynamic Light',
              description: 'FLight and the normal-shaded primitives.',
              icon: Icons.lightbulb_outline_rounded,
              builder: (_) => const LightingDemo(),
            ),
          ],
        ),
        CatalogSection(
          title: 'Physics',
          entries: [
            CatalogEntry(
              title: 'Native Physics',
              description: 'FRigidBody and FStaticBody on the C++ solver.',
              icon: Icons.architecture_rounded,
              builder: (_) => const PhysicsDemoExample(),
            ),
            CatalogEntry(
              title: 'Joints',
              description: 'Distance, revolute, prismatic and weld joints.',
              icon: Icons.hub_rounded,
              tint: DemoTheme.accentAlt,
              builder: (_) => const JointsDemoExample(),
            ),
            CatalogEntry(
              title: "Newton's Cradle",
              description: 'Restitution and joint chains under gravity.',
              icon: Icons.unfold_more_double_rounded,
              builder: (_) => const PendulumDemoExample(),
            ),
            CatalogEntry(
              title: 'Trigger Areas',
              description: 'FArea: overlap callbacks without a collision response.',
              icon: Icons.crop_free_rounded,
              tint: DemoTheme.positive,
              builder: (_) => const AreaDemo(),
            ),
            CatalogEntry(
              title: 'Collision Layers',
              description: 'categoryBits and maskBits filtering.',
              icon: Icons.filter_center_focus_rounded,
              builder: (_) => const CollisionLayersDemoExample(),
            ),
            CatalogEntry(
              title: 'Raycasting',
              description: 'FPhysicsSystem.rayCast against the broadphase.',
              icon: Icons.flash_on_rounded,
              builder: (_) => const RayCastDemo(),
            ),
            CatalogEntry(
              title: 'Native Soft Body',
              description: 'Pressure soft bodies in C++, draggable.',
              icon: Icons.auto_fix_high_rounded,
              tint: DemoTheme.accentAlt,
              builder: (_) => const NativeSoftBodyDemo(),
            ),
            CatalogEntry(
              title: 'Verlet Soft Body',
              description: 'The Dart verlet solver, for comparison.',
              icon: Icons.vignette_rounded,
              builder: (_) => const SoftBodyDemoExample(),
            ),
            CatalogEntry(
              title: 'Rope',
              description: 'FRope: a verlet chain you can grab.',
              icon: Icons.linear_scale_rounded,
              builder: (_) => const RopeDemo(),
            ),
            CatalogEntry(
              title: 'Sandbox',
              description: 'Draw static geometry, then drop bodies on it.',
              icon: Icons.draw_rounded,
              builder: (_) => const SandboxDemoExample(),
            ),
          ],
        ),
        CatalogSection(
          title: 'Particles',
          entries: [
            CatalogEntry(
              title: 'Presets',
              description: 'Fire, smoke, rain, snow and the rest.',
              icon: Icons.auto_awesome,
              tint: DemoTheme.warning,
              builder: (_) => const ParticleDemoExample(),
            ),
            CatalogEntry(
              title: 'Particle Field',
              description: 'Emitters attached to moving nodes.',
              icon: Icons.bubble_chart_rounded,
              builder: (_) => const ParticleFieldExample(),
            ),
            CatalogEntry(
              title: 'Million Particles',
              description: 'The native vertex builder at full stretch.',
              icon: Icons.speed_rounded,
              tint: DemoTheme.warning,
              builder: (_) => const NativeParticleDemo(),
            ),
          ],
        ),
        CatalogSection(
          title: 'Grids and procedural',
          entries: [
            CatalogEntry(
              title: 'Grid & Camera',
              description: 'FSquareGrid and FIsometricGrid on the XZ plane.',
              icon: Icons.grid_4x4_rounded,
              builder: (_) => const GridCameraDemo(),
            ),
            CatalogEntry(
              title: 'Tilemap',
              description: 'FTileMap: one painter, culled to the viewport.',
              icon: Icons.dashboard_rounded,
              builder: (_) => const TileMapDemo(),
            ),
            CatalogEntry(
              title: 'Procedural',
              description: 'FProceduralGenerator: noise, rooms and mazes.',
              icon: Icons.terrain_rounded,
              tint: DemoTheme.positive,
              builder: (_) => const ProceduralDemo(),
            ),
            CatalogEntry(
              title: 'Grid AI',
              description: 'A* paths, FWandererAgent and FFleeAgent.',
              icon: Icons.route_rounded,
              tint: DemoTheme.positive,
              builder: (_) => const GridAiDemo(),
            ),
          ],
        ),
        CatalogSection(
          title: 'Systems',
          entries: [
            CatalogEntry(
              title: 'Input',
              description: 'Keyboard, pointer and the virtual joystick.',
              icon: Icons.gamepad_rounded,
              builder: (_) => const InputDemoExample(),
            ),
            CatalogEntry(
              title: 'Tween System',
              description: 'FTweenManager driving nodes imperatively.',
              icon: Icons.animation,
              builder: (_) => const TweenDemoExample(),
            ),
            CatalogEntry(
              title: 'Tween Widgets',
              description: 'FTweenBuilder and FAnimated, declaratively.',
              icon: Icons.auto_graph_rounded,
              builder: (_) => const TweenBuilderDemo(),
            ),
            CatalogEntry(
              title: 'Timers',
              description: 'FTimer and FGameTimer, one-shot and looping.',
              icon: Icons.timer_rounded,
              builder: (_) => const TimerDemo(),
            ),
            CatalogEntry(
              title: 'Scene Manager',
              description: 'Named scenes and transitions.',
              icon: Icons.layers,
              builder: (_) => const SceneManagerDemoExample(),
            ),
            CatalogEntry(
              title: 'State Machine',
              description: 'FStateMachine driving behaviour.',
              icon: Icons.account_tree_rounded,
              builder: (_) => const StateMachineDemoExample(),
            ),
            CatalogEntry(
              title: 'Event Bus',
              description: 'FEventBus: typed events between unrelated nodes.',
              icon: Icons.podcasts_rounded,
              builder: (_) => const EventBusDemo(),
            ),
            CatalogEntry(
              title: 'Physics Audio',
              description: 'Collision callbacks triggering sounds.',
              icon: Icons.surround_sound_rounded,
              builder: (_) => const AudioDemo(),
            ),
            CatalogEntry(
              title: '3D Audio',
              description: 'Positional sources around a moving listener.',
              icon: Icons.spatial_audio_off_rounded,
              builder: (_) => const ThreeDAudioDemo(),
            ),
            CatalogEntry(
              title: 'Profiler',
              description: 'FProfiler: where the frame actually goes.',
              icon: Icons.monitor_heart_rounded,
              tint: DemoTheme.warning,
              builder: (_) => const ProfilerDemo(),
            ),
          ],
        ),
        CatalogSection(
          title: 'Putting it together',
          entries: [
            CatalogEntry(
              title: 'Master Tech Demo',
              description: 'Signals, groups, physics and input at once.',
              icon: Icons.verified_rounded,
              tint: DemoTheme.accentAlt,
              builder: (_) => const MasterTechDemo(),
            ),
            CatalogEntry(
              title: 'Games',
              description: 'Three complete games built on the engine.',
              icon: Icons.sports_esports_rounded,
              tint: DemoTheme.warning,
              builder: (_) => const GamesCatalog(),
            ),
          ],
        ),
      ],
    );
  }
}
