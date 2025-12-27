# Flash Engine Project Rules

## Core Philosophy
1.  **Mobile First**: The engine is optimized for mobile performance (iOS/Android).
    *   **Simulator Priority**: Functionality MUST work on iOS Simulator (`x86_64` / `arm64`). Native libraries must be compiled specifically for it (`libflash_core_sim.dylib`).
    *   **Performance**: Use FFI and native memory (Vectors) where possible to avoid GC pressure. This is a primary design constraint.

## Coordinate System & Physics
1.  **Y-Up System**: The `FlashPainter` rendering engine inverts the Y-axis (`scale(1, -1)`).
    *   `+Y` is UP (Top of screen).
    *   `-Y` is DOWN (Bottom of screen).
    *   **Gravity**: MUST be Negative (e.g., `-9.8`). Explicitly override C++ defaults if necessary.
2.  **Native Integration**:
    *   **Struct Alignment**: Dart FFI structs (`particles_ffi.dart`) MUST exactly match C++ headers (`physics.h`).
    *   **Library Loading**: Always handle `Platform.isIOS` specifically to load the simulator-compatible dylib.

## Development Workflow
1.  **Hot Restart vs Cold Restart**: Native binary changes (`.dylib`) require a **Cold Restart** (Stop & Run). Hot Restart does not reload native code.
2.  **Visual Debugging**:
    *   `FlashPhysicsBody.debugDraw` defaults to `false` to prevent conflict with Flutter Widgets.
    *   Enable it explicitly for pure physics demos (`SimpleJointsDemo`).

## Build Instructions
1.  **Native Development**:
  - **Manual Rebuilds**: C++ changes require a cold restart and manual compilation:
    - **macOS Desktop**: `clang++ -dynamiclib -std=c++17 -o lib/src/core/native/bin/libflash_core.dylib src/native/physics.cpp src/native/joints.cpp src/native/broadphase.cpp src/native/particles.cpp`
    - **iOS Simulator**: `clang++ -dynamiclib -std=c++17 -arch arm64 -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path) -o lib/src/core/native/bin/libflash_core_sim.dylib src/native/physics.cpp src/native/joints.cpp src/native/broadphase.cpp src/native/particles.cpp`
  - **Troubleshooting**: If you see `linker command failed with exit code 1`, it means you forgot to include a `.cpp` file (e.g., `particles.cpp`) in the build command.
  - **Reference Implementation**: All native physics implementation MUST explicitly follow the patterns and logic found in the generated `box2d-main` or `JoltPhysics-master` folders within the project root. Do not invent custom physics solvers; adapt established logic from these sources.
  - **Ownership**: The native C++ layer (`PhysicsWorld`, `bodies` vector) owns all memory. Dart has NO state logic, only UI representation.
  - **FFI Boundary**: Dart only reads positions from `bodies` via `FlashNativeParticles.stepPhysics`. No logic in Dart. simulator requires `xcrun` and arch flags (advanced).

## Verification Protocol (Strict)
1.  **Never Assume Success**: After editing code, YOU MUST verify it.
2.  **Tooling Mandatory**:
    *   Run `flutter analyze [file_path]` to catch syntax errors immediately.
    *   For native code, ensure compilation output is clean.
3.  **Honesty**: If a fix fails, report the failure. Do not claim "fixed" without tool verification.

## Architecture & Memory (Vital)
1.  **Memory Ownership**:
    *   **C++ Owns Physics**: The `PhysicsWorld` and `NativeBody` structs are allocated/freed in C++.
    *   **Dart is a View**: Dart classes (`FlashPhysicsBody`) only hold *pointers*. Never try to `free()` a physics body from Dart manually; let the C++ world destruction handle it.
2.  **State Synchronization**:
    *   **Native Truth**: The C++ simulation is the "Single Source of Truth" for position/rotation.
    *   **One-Way Sync**: `FlashPhysicsBody._syncFromPhysics()` pulls data from C++ to Dart every frame. Never overwrite C++ positions from Dart update loops unless explicitly teleporting.
3.  **Performance Limits**:
    *   **Particles**: Use Hardware Instancing (via `particles_ffi`) for counts > 10,000.
    *   **Rigid Bodies**: Keep active generic bodies under 500 for mobile 60fps.

## Layout & Coordinates (Vital)
1.  **Coordinate Origin**:
    *   **Center is (0,0)**:Unlike Flutter (Top-Left), the Flash Engine (and most game engines) places `(0,0)` at the **center of the viewport**.
    *   **Dimensions**: Visible area depends on the viewport size. If `Scaffold` has an `AppBar`, the viewport height is reduced.
2.  **Safe Areas**:
    *   **Canvas Size != Screen Size**: Always respect the `size` passed to `FlashPainter`. Do not assume full screen (1920x1080).
    *   **Padding**: Account for `AppBar` height (~56px) and Status Bar when calculating "Top" edge boundaries.
3.  **Positioning Rule**:
    *   **Don't Guess**: Use `FlashCamera.getWorldBounds()` (if available) or assume a Safe Zone (e.g., +/- 150px) rather than hardcoding large values like `y: -500` which might be off-screen.


### Native Development Rules
- **Manual Recompilation**: Any change to C++ files (`src/native/*.cpp`) **REQUIRES** a manual recompilation of the dylib. Hot Restart will NOT pick up C++ changes.
- **Build Command**: Use `clang++ -dynamiclib -std=c++17 -undefined dynamic_lookup -o lib/src/core/native/bin/libflash_core.dylib src/native/*.cpp` for macOS.

### Physics Stability Rules
- **Sub-stepping**: Run the physics solver at least 8 times per frame (`substeps = 8`) to ensure rock-solid floors.
- **Contact Hardness**: With 8x sub-stepping, use `contactHertz = 120.0` for rigid bodies. High stiffness prevents ALL sinking.
- **Solver Iterations**: Use 4 Position and 4 Velocity iterations per SUB-STEP (Total 32/frame).
- **Collision Shapes**: Prefer Circle-Circle collisions for high-speed or chaotic simulations (like Pachinko).
- **Shared World**: All rigid bodies must share the same `FlashPhysicsSystem` instance from the engine context.
