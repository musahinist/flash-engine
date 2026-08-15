# Flash Engine Project Rules

## Core Philosophy
1.  **Mobile First**: The engine is optimized for mobile performance (iOS/Android).
    *   **Every platform builds from source**: `hook/build.dart` compiles `src/native/` for whatever target the app is built for. There is no per-platform dylib to maintain and no simulator special case — that was an artefact of the old absolute-path loader.
    *   **Performance**: Use FFI and native memory (Vectors) where possible to avoid GC pressure. This is a primary design constraint.
    *   **No fixed-size arena allocations.** Buffers sized for a worst case (the old 1M-particle vertex buffer was 360 MB) must grow on demand instead.

## Master References & Design Philosophy
1.  **Godot Engine (Primary Inspiration)**:
    *   **Role**: The absolute master reference for engine structure, naming conventions, and node-based architecture.
    *   **Goal**: Create a **declarative**, node-based game engine in Flutter that mirrors Godot's developer experience (`Node`, `Scene`, `Signals`).
    *   **Difference**: Unlike Flame (imperative), Flash MUST be declarative and "Flutter-like".
2.  **Physics Masters**:
    *   **Box2D & JoltPhysics**: These are the sources of truth for physics implementation. All physics logic, naming, and structures should mirror these C++ engines.
3.  **Flame Engine (Secondary Resource)**:
    *   **Role**: Reference for **UI rendering optimizations** and Flutter-specific game loop mechanics.
    *   **Note**: Do not copy Flame's imperative component system. Use it only to understand how to optimize rendering in the Flutter context.

> [!NOTE]
> **Reference Access**: The source code for these master references (Godot, Box2D, JoltPhysics, Flame) is maintained in the `other_repo/` directory within this workspace. Always consult these local copies when in doubt.

## Coordinate System & Physics
1.  **Y-Up System**: The `FPainter` rendering engine inverts the Y-axis (`scale(1, -1)`).
    *   `+Y` is UP (Top of screen).
    *   `-Y` is DOWN (Bottom of screen).
    *   **Gravity**: MUST be Negative (e.g., `-9.8`). Explicitly override C++ defaults if necessary.
2.  **Native Integration**:
    *   **Struct Alignment**: Dart FFI structs (`flash_native_bindings.dart`) MUST exactly match the C++ headers, field for field. `test/native_abi_test.dart` enforces it — a mismatch corrupts reads silently rather than failing to compile.
    *   **Library Loading**: There is none. Symbols resolve through `@DefaultAsset('package:flash/flash_core')`; never reintroduce a runtime path lookup.
3.  **Input Transformation**:
    *   **Invert Y**: Mobile Input (Touch/Joystick) provides Screen Coordinates (Y-Down). Physics requires Y-Up. You MUST invert the Y-axis of any screen input before applying it to physics bodies (`dy = -input.y`).
4.  **Grids live on the XZ plane**: a cell maps to world `(x, 0, z)` and `+Y` is height above the grid. This is what lets grids share the engine's Y-up convention rather than carrying a second, Y-down one. `FGrid.gridToWorld`/`worldToGrid` are the only place that mapping is written down — do not re-derive it.
5.  **Isometric is a camera pose, not a projection type**: use `FCameraNode.isometric()`. The matrix was previously hand-written in four separate places.

## Development Workflow
1.  **Hot Restart vs Cold Restart**: Native binary changes (`.dylib`) require a **Cold Restart** (Stop & Run). Hot Restart does not reload native code.
2.  **Visual Debugging**:
    *   `FPhysicsBody.debugDraw` defaults to `false` to prevent conflict with Flutter Widgets.
    *   Enable it explicitly for pure physics demos (`SimpleJointsDemo`).

## Build Instructions
1.  **Native Development**:
  - **No manual compilation.** `hook/build.dart` builds `src/native/*.cpp` as part of `flutter run`/`flutter test`/`flutter build`, and registers the result as the code asset `package:flash/flash_core`. Adding a `.cpp` file means adding it to the `_sources` list in that hook.
  - **Cold restart required**: C++ changes are picked up on a full restart, not hot restart.
  - **Exported symbols must be marked `FLASH_API`** (see `src/native/flash_export.h`). Without it, Windows links a DLL with no usable entry points.
  - **Reference Implementation**: All native physics implementation MUST explicitly follow the patterns and logic found in the generated `box2d-main` or `JoltPhysics-master` folders within `other_repo/`. Do not invent custom physics solvers; adapt established logic from these sources.
  - **Ownership**: The native C++ layer (`PhysicsWorld`, `bodies` vector) owns all memory. Dart has NO state logic, only UI representation.
  - **Allocator symmetry**: whatever allocates must match what frees — `calloc`/`free`, `new`/`delete`, `new[]`/`delete[]`. Mixing them is undefined behaviour and does not reliably crash.
  - **ABI changes**: bump `FLASH_ABI_VERSION` in `physics.h` and `kFlashAbiVersion` in `flash_native.dart` together, and extend `src/native/abi_probe.cpp` if a struct gained a field. `test/native_abi_test.dart` is what stops a layout change corrupting reads silently.

## Graceful Degradation (Vital)
The engine is layered so a build without the native core still does something useful. Respect the tier when adding features:
1.  **Tier 0 — scene graph, rendering, cameras, tweens, timers, input, audio.** Must never require native code. `FNode` falls back to pure-Dart transform maths.
2.  **Tier 1 — particles.** Decorative: disable and warn once, never throw.
3.  **Tier 2 — physics, joints, raycasting, soft bodies.** Cannot be faked. Throw `FlashNativeUnavailableError` at construction. A physics game that silently does not simulate is worse than one that refuses to start.

## Verification Protocol (Strict)
1.  **Never Assume Success**: After editing code, YOU MUST verify it.
2.  **Tooling Mandatory**:
    *   Run `flutter analyze [file_path]` to catch syntax errors immediately.
    *   For native code, ensure compilation output is clean.
3.  **Honesty**: If a fix fails, report the failure. Do not claim "fixed" without tool verification.

## Node Lifecycle (Vital)
1.  **Override `process(double dt)`, never `update(double dt)`.** `update` is the pump: it evaluates `ProcessMode`, syncs the transform to native, then calls `process` and recurses into children. Overriding `update` and working after `super.update(dt)` — which every subclass used to do — silently defeats `ProcessMode` and runs the parent's frame work *after* its children have already read it.
2.  **Per-frame work in a widget belongs in `engine.addUpdateListener`**, paired with `removeUpdateListener` in `dispose`. Do not assign `engine.onUpdate`; that slot belongs to `FView`.

## Architecture & Memory (Vital)
1.  **Memory Ownership**:
    *   **C++ Owns Physics**: The `PhysicsWorld` and `NativeBody` structs are allocated/freed in C++.
    *   **Dart is a View**: Dart classes (`FPhysicsBody`) only hold *pointers*. Never try to `free()` a physics body from Dart manually; let the C++ world destruction handle it.
2.  **State Synchronization**:
    *   **Native Truth**: The C++ simulation is the "Single Source of Truth" for position/rotation.
    *   **One-Way Sync**: `FPhysicsBody._syncFromPhysics()` pulls data from C++ to Dart every frame. Never overwrite C++ positions from Dart update loops unless explicitly teleporting.
3.  **Performance Limits**:
    *   **Particles**: Use Hardware Instancing (via the native emitter) for counts > 10,000.
    *   **Rigid Bodies**: Keep active generic bodies under 500 for mobile 60fps.

## Layout & Coordinates (Vital)
1.  **Coordinate Origin**:
    *   **Center is (0,0)**:Unlike Flutter (Top-Left), the Flash Engine (and most game engines) places `(0,0)` at the **center of the viewport**.
    *   **Dimensions**: Visible area depends on the viewport size. If `Scaffold` has an `AppBar`, the viewport height is reduced.
2.  **Safe Areas**:
    *   **Canvas Size != Screen Size**: Always respect the `size` passed to `FPainter`. Do not assume full screen (1920x1080).
    *   **Padding**: Account for `AppBar` height (~56px) and Status Bar when calculating "Top" edge boundaries.
3.  **Positioning Rule**:
    *   **Don't Guess**: Use `FCamera.getWorldBounds()` (if available) or assume a Safe Zone (e.g., +/- 150px) rather than hardcoding large values like `y: -500` which might be off-screen.
4.  **Viewport-Relative Positioning (CRITICAL)**:
    *   **NEVER HARDCODE POSITIONS**: Do not use hardcoded pixel values like `position: Vector3(400, 300, 0)`. Different devices have different screen sizes.
    *   **Use engine.viewportSize**: Access `context.flash!.viewportSize` to get current viewport dimensions.
    *   **Calculate Relative Values**:
        ```dart
        final viewport = context.flash!.viewportSize;
        final x = (rnd.nextDouble() - 0.5) * viewport.x * 0.6; // 60% of width
        final y = (rnd.nextDouble() - 0.5) * viewport.y * 0.5; // 50% of height
        ```
    *   **World Space Calculation**: For 3D perspective (FOV 60°, Camera at z=500), visible width ≈ `viewport.y * 0.8` at z=0. Use this for spawn calculations.
    *   **Safe Margins**: Keep spawned objects within 80% of viewport dimensions to account for perspective distortion.


### Native Development Rules
- **No manual recompilation.** The build hook handles it; see "Build Instructions" above. Cold restart is still required for C++ changes.

### Physics Stability Rules
- **Sub-stepping**: Run the physics solver at least 8 times per frame (`substeps = 8`) to ensure rock-solid floors.
- **Contact Hardness**: With 8x sub-stepping, use `contactHertz = 120.0` for rigid bodies. High stiffness prevents ALL sinking.
- **Solver Iterations**: Use 4 Position and 4 Velocity iterations per SUB-STEP (Total 32/frame).
- **Collision Shapes**: Prefer Circle-Circle collisions for high-speed or chaotic simulations (like Pachinko).
- **Shared World**: All rigid bodies must share the same `FPhysicsSystem` instance from the engine context.

## FFI Best Practices (Dart-Native Boundary)
1.  **Hide Pointers from Dart Devs**:
    - Never expose `Pointer<Float>`, `calloc`, or `free` in public APIs.
    - Create helper methods that handle memory internally and return Dart types.
    - **Good**: `Offset getSoftBodyPointPos(world, id, index)` - returns clean `Offset`
    - **Bad**: `void getSoftBodyPoint(world, id, index, Pointer<Float> outX, Pointer<Float> outY)`

2.  **Double-Free Prevention**:
    - **CRITICAL**: Always review `calloc.free()` calls. Duplicate frees cause `SIGABRT` crashes.
    - Use try-finally or document ownership clearly.
    - Pattern: Allocate → Use → Free (exactly once, in same scope if possible).

3.  **Reusable Buffers**:
    - For high-frequency operations (every frame), allocate once and reuse:
      ```dart
      static final Pointer<Float> _pointX = calloc<Float>(); // Allocated once
      ```
    - Don't allocate/free in hot loops - GC pressure and fragmentation.

4.  **Symbol Lookup Safety**:
    - Wrap new FFI lookups in try-catch during development:
      ```dart
      try {
        setSoftBodyParams = _lib!.lookupFunction<...>('set_soft_body_params');
      } catch (e) {
        print('WARNING: Symbol not found: $e');
      }
      ```
    - This prevents hard crashes when native library is outdated.

## Known Issues & Roadmaps
- **Joint System Instability**:
    - **Issue**: Distance and Revolute joints may exhibit "rubber-banding" or snap behaviors under high stress or incorrect initialization.
    - **Status**: Pending optimization. Need to revisit the native solver's sub-stepping and warm-starting parameters to achieve perfect rigidity.
    - **Ref**: `pendulum_demo.dart` and `joints_demo.dart`.
- **No deprecation policy**: the package is pre-release with no external consumers, so removed API is removed outright and `demo/` is migrated in the same commit. Do not add `@Deprecated` shims.
- **Windows and Linux are unverified**: the build hook targets them and `FLASH_API` is in place, but neither has been compiled on real hardware.
- **`cube` and `cube_quest` do not use the engine**: both are pure Flutter despite the catalog billing them as "Built with Flash Engine".
