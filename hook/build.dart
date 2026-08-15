// Build hook for the Flash native core.
//
// Compiles src/native/*.cpp into a shared library that the Dart/Flutter
// toolchain bundles for whatever platform is being built, and registers it as
// the code asset `package:flash/flash_core`. The Dart bindings reference that
// asset id via @DefaultAsset, so there is no runtime path lookup at all.
//
// This replaces scripts/build_native.sh, which only ever produced a macOS host
// dylib plus an iOS Simulator slice, and whose output was loaded through
// absolute paths hard-coded to one developer's machine.

import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Translation units of the native core.
///
/// Listed explicitly rather than globbed: the directory also holds headers,
/// and any future standalone file with a `main()` would silently break the
/// link if it were swept in.
const _sources = [
  'src/native/particles.cpp',
  'src/native/physics.cpp',
  'src/native/broadphase.cpp',
  'src/native/joints.cpp',
  'src/native/nodes.cpp',
  'src/native/abi_probe.cpp',
];

void main(List<String> args) async {
  await build(args, (input, output) async {
    final builder = CBuilder.library(
      name: 'flash_core',
      assetName: 'flash_core',
      language: Language.cpp,
      std: 'c++17',
      cppLinkStdLib: 'c++',
      sources: _sources,
      includes: const ['src/native'],
      // Matches the -O3 -ffast-math the old shell script used. -flto is
      // deliberately not carried over; it broke linking on some toolchains.
      optimizationLevel: OptimizationLevel.o3,
    );

    await builder.run(input: input, output: output);
  });
}
