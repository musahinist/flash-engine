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

