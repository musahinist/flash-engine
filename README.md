# Flash Engine

A declarative, node-based 2.5D game engine for Flutter, with a native C++ core for physics and particles.

Godot's node model, expressed as Flutter widgets. You describe a scene; the engine owns the frame loop, the transform hierarchy, the render order and the simulation.

> **Status: pre-release (0.0.1).** The API is not stable and there is no deprecation policy yet — things get renamed or removed outright between commits.

## Requirements

- Flutter ≥ 3.35, Dart ≥ 3.10
- Android, iOS, macOS, Windows, Linux. **Not web** — the engine depends on `dart:ffi`.

The native core is compiled from source by a Dart build hook when your app builds. There is nothing to install, and no prebuilt binaries are shipped.

## Getting started

```yaml
dependencies:
  flash:
    path: ../flash
```

A scene is a widget:

```dart
import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class MyGame extends StatelessWidget {
  const MyGame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FScene(
        scene: [
          FCamera(position: v.Vector3(0, 0, 500), fov: 60),
          FLight(position: v.Vector3(100, 100, 200), intensity: 1.5),
          FBox(position: v.Vector3(0, 0, 0), width: 100, height: 100, color: Colors.blue),
        ],
      ),
    );
  }
}
```

`FScene` wraps `FView`, which owns the `FEngine`. Use `sceneBuilder` instead of `scene` when the contents change every frame:

```dart
FScene(
  sceneBuilder: (context, elapsed) => [
    FCamera(position: v.Vector3(0, 0, 500)),
    FBox(
      position: v.Vector3(math.cos(elapsed) * 200, 0, 0),
      width: 50,
      height: 50,
      color: Colors.orange,
    ),
  ],
)
```

## Coordinates

Two conventions matter, and they are not Flutter's:

- **Origin is the centre of the viewport**, not the top-left.
- **+Y is up.** Gravity is therefore negative, and screen input must have its Y inverted before being applied to physics.

Grids are the exception worth knowing: they lie on the **XZ plane**, so a cell maps to `(x, 0, z)` and `+Y` is height above the grid.

## What's in the box

### Primitives
`FBox` · `FSphere` · `FCube` · `FCircle` · `FTriangle` · `FIsometricCubeWidget`

### Physics
`FRigidBody` · `FStaticBody` · `FArea` · `FDistanceJoint` · `FRevoluteJoint` · `FPrismaticJoint` · `FWeldJoint` · `FSoftBodyWidget`

Backed by a C++ solver adapted from Box2D: sub-stepped, warm-started, with an AABB broadphase.

```dart
FScene(
  physicsWorld: FPhysicsSystem(gravity: v.Vector2(0, -980)),
  scene: [
    FStaticBody.square(position: v.Vector3(0, -200, 0), size: 800, color: Colors.grey),
    FRigidBody.circle(position: v.Vector3(0, 200, 0), radius: 20, color: Colors.red),
  ],
)
```

### Grids and tilemaps
`FGridView` · `FCell` · `FTileMap` · `FSquareGrid` · `FIsometricGrid` · `FGridAgent`

```dart
FGridView(
  grid: const FIsometricGrid(cellWidth: 64),
  children: [
    FTileMap(tilePainter: paintTile),
    FCell(x: playerX, y: playerY, child: FCube(size: 40, color: Colors.cyan)),
  ],
)
```

A tilemap draws every visible cell in a single node, so a large or infinite map costs one entry in the render list rather than one per cell.

### Cameras
`FCamera` — perspective or orthographic, with follow, dead zone, bounds and screen shake. `FCameraNode.isometric()` and `FCameraNode.topDown()` are presets; isometric is a camera *pose*, not a separate projection mode.

### Lighting
`FLight` with `FLightType.point`, `.directional` or `.ambient`. A directional light is aimed by its own rotation.

### Particles
`FParticles` with ~20 presets (`fire`, `smoke`, `explosion`, `rain`, `confetti`…). Simulated and vertex-built in C++, drawn in one `drawVertices` call.

### Also
Scene graph (`FNode`, signals, groups, `ProcessMode`) · tweens and easing · timers · input (keyboard, pointer, gestures) · 3D positional audio · raycasting · procedural generation · scene transitions · HUD widgets.

## Running the examples

```bash
cd demo
flutter run
```

26 examples and 3 games. Every code block above is lifted from something in there.

## Degradation

The engine is layered so a build without the native core still does something useful:

| Tier | Covers | Without the native core |
|---|---|---|
| 0 | Scene graph, rendering, cameras, tweens, timers, input, audio | Works — transforms fall back to pure Dart |
| 1 | Particles | Emitters disable themselves and warn once |
| 2 | Physics, joints, raycasting, soft bodies | Throws `FlashNativeUnavailableError` at construction |

Tier 2 fails loudly on purpose: a physics game that silently does not simulate is worse than one that refuses to start.

## Working on the engine

```bash
flutter analyze
flutter test
```

C++ lives in `src/native/` and is built by `hook/build.dart`. Changing it requires a **cold restart** — hot restart does not reload native code.

`test/native_abi_test.dart` is the one to watch: the Dart bindings mirror the C++ structs field by field, and a layout change on one side only corrupts reads silently instead of failing to compile.

### Measuring

```bash
flutter test test/benchmark/engine_benchmark.dart
```

It is not named `*_test.dart`, so `flutter test` skips it — it is slow and it prints rather than asserts. `FEngine.profiler` is off by default; the harness turns it on and reports per-section cost for scenes at the engine's target scale.

`test/benchmark/BASELINE.md` holds the numbers, and the rule that produced them: measure before claiming. It records the changes that turned out to be worth nothing, the scenario too noisy to attribute anything to, and the estimate that ranked two optimisations the wrong way round — those are the useful parts.

## License

MIT
