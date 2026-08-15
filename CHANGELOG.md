# Changelog

## Unreleased

Large hardening pass. The engine was written in a single sprint and then sat
untouched for months; this is the first sustained round of fixes on top of it.
There is no deprecation policy yet — removed API is removed, and the bundled
demos are migrated in the same commit.

### Packaging

- The native C++ core is now compiled from source by `hook/build.dart` and
  bundled as the Dart code asset `package:flash/flash_core`. Previously the FFI
  loader opened dylibs through paths hard-coded to one developer's machine, so
  the package only worked there; Android, real iOS devices, Windows and Linux
  had no binary at all.
- `scripts/build_native.sh` and the committed dylibs are gone.
- Bindings use `@Native`/`@DefaultAsset` instead of `DynamicLibrary.open`, with
  `isLeaf` on the hot paths.
- Declared supported platforms; web is explicitly excluded (`dart:ffi`).

### Native core

- Fixed undefined behaviour in `destroy_physics_world`, which released
  `calloc`'d memory with `delete[]`/`delete`.
- The warm-start impulse cache was never freed and never cleared, growing for
  the lifetime of the world. Its key packing could also collide, handing a
  contact the wrong cached impulse.
- Removed `fprintf(stderr)` from inside the soft-body collision loop — tens of
  thousands of writes per second at a 120Hz fixed step.
- Added `destroy_native_node`: the node pool had no free path, so every
  add/remove cycle burned a slot until allocation started failing silently.
- `update_scene_transforms` no longer assumes parents come before children in
  the pool, which also makes re-parenting correct.

### Behaviour fixes

- `ProcessMode` and `FSceneTree.paused` now do something. Every node subclass
  overrode `update` instead of `process`, so disabled nodes kept working, and
  pausing the tree left physics and tweens running underneath.
- `setWorldDirty()` no longer short-circuits on an already-dirty flag, which
  had frozen culled and invisible nodes in place.
- `FTransform` detects in-place edits to the vectors it hands out.
- `FLabel` regenerates its cached image when the text changes.
- Non-looping particle emitters stop after one burst instead of re-firing
  forever.
- `FRayCast2D` draws its debug ray (it overrode a method nothing calls) and
  casts from its world position rather than its local one.
- `FArea`'s collision callbacks are connected.
- `FEngine.onUpdate` is a listener list carrying the real frame delta, instead
  of a single slot that widgets chained, leaked and overwrote.
- Shading is shared: a box and a sphere under identical lights now agree.
- Colour maths uses the modern `Color` API; shaded colours were collapsing to
  transparent black.
- `FPainter`'s particle buffers grow on demand instead of allocating a fixed
  360 MB.
- Draw order tie-breaks on creation index rather than `hashCode`, which is not
  stable between runs.

### Grid and camera

- Grids live on the XZ plane with `+Y` as height, so they share the engine's
  Y-up convention instead of carrying their own Y-down one.
- `FGridCamera` is removed; follow, dead zone, bounds, zoom and shake are on
  `FCameraNode`. Following is frame-rate independent, and shake uses real
  randomness applied at view-matrix time.
- `FCameraNode.isometric()` and `.topDown()` replace the isometric matrix that
  had been hand-written in four places. `core/projection/` is deleted.
- New `FGridNode`, `FTileMapNode` and the `FGridView`/`FCell`/`FTileMap`
  widgets — the grid system had no widget layer at all.
- `FGridAgent` is a node driven by the frame loop; it previously required the
  caller to feed it a wall-clock timestamp, which ignored pausing entirely.

### Documentation and tests

- README rewritten. The previous one documented fifteen classes that no longer
  existed and a physics API built on removed Forge2D types; not one line of it
  compiled. Every sample is now covered by a test.
- Tests: 11 → 109. New coverage for the FFI ABI (struct sizes and field
  offsets), graceful degradation, process modes, camera behaviour, grid maths
  and the widget layer.

### Performance

Measured throughout, against a baseline recorded first. `test/benchmark/` holds
the harness and `test/benchmark/BASELINE.md` the numbers, including the changes
that measured as nothing and the one estimate that ranked two items the wrong
way round.

- Added `FProfiler` and `FEngine.debugTick`, so frame cost is attributable per
  section. The only previous indicator was `FEngine.fps`, which measures tick
  frequency — a frame using 90% of its budget looked identical to one using 10%.
- The world matrix version gate compared the scene-wide `totalUpdates`, which
  increments every frame regardless, so a stationary node re-read sixteen floats
  across the FFI boundary every frame. It now gates on the node's own
  `worldVersion`, which C++ only bumps when the matrix actually changes. Deep
  hierarchy p95 1.865 → 1.109 ms.
- Particle emission is one FFI call per burst rather than per particle, with the
  randomisation and spread rotation done natively. The old path cost roughly
  500,000 crossings and 2,000,000 Dart allocations a second at the engine's
  stated 1M-particle target. 100k particles: 0.303 → 0.109 ms.
- Box narrow phase builds each body's frame once instead of calling `rotate` —
  and therefore `cos` and `sin` — per corner per axis: 64 trig calls per pair
  down to 4. The position solver reuses the velocity phase's contact anchors
  instead of re-running the full SAT test in every iteration.
- The particle vertex builder hoisted a per-shape constant out of its
  per-particle loop, halving its cost, and runs on a persistent thread pool. The
  parallel path previously constructed `std::thread`s per chunk per pass per
  frame, so its threshold sat at 100,000 particles and never engaged; it is now
  4,096, measured. 1M particles: 5.83 → 2.13 ms.
- `ray_cast` uses the broadphase tree instead of testing every body in the
  world. Cost no longer grows with world size: 12.78 → 0.04 us at 2,000 bodies.
  Soft body contacts do the same, and hoist the per-body trig out of the point
  loop.
- Frustum culling no longer allocates a `Matrix4`, a `List` and eight `Vector4`s
  per bounded node per frame; camera matrices are cached for the frame rather
  than recomputing a general 4x4 inverse several times; `FCircle`, `FTriangle`
  and `FSphere` cache their `Paint`, `Path` and gradient instead of rebuilding
  them every frame, and gained the `bounds` that means they are culled at all.
- Batched the remaining per-item crossings: soft body point reads, body
  positions, the particle camera matrix and gravity writes.

### Removed

No deprecation shims. These were all API that did nothing.

- `FPhysicsSystem.setWarmStarting`, whose body was a commented-out line.
- `spawn_particle`, superseded by the batched `emit_particles`.
- `NativeBody.isSensor`, `isBullet` and `islandId`: written once at creation,
  never read. The Dart mirror described `isBullet` as enabling continuous
  collision detection, which does not exist.
- `NativeNode.visible`: set beside `alive`, which already meant the same thing,
  and read by neither — while Dart wrote scene visibility into the same field.
- `PhysicsWorld.manifolds`: an array of `2 x maxBodies` allocated at
  construction, freed at destruction, never touched in between.
- Joint creation no longer prints to stdout. Three of the four joint types
  ignored `create_joint`'s result entirely, so exceeding the 200-joint pool gave
  a joint that silently did not exist; all four now throw.
- `FAudioNode.play` no longer swallows exceptions behind a `print`.

## 0.0.1

Initial version.
