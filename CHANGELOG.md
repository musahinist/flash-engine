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

## 0.0.1

Initial version.
