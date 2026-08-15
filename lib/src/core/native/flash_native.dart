import 'flash_native_bindings.dart' as bindings;

/// ABI version the Dart bindings were written against.
///
/// Mirrors `FLASH_ABI_VERSION` in `src/native/physics.h`. Bump both together
/// whenever an exported struct layout or signature changes.
const int kFlashAbiVersion = 2;

/// Thrown when a feature that genuinely requires the native core is used on a
/// build where that core is unavailable.
class FlashNativeUnavailableError extends Error {
  FlashNativeUnavailableError(this.feature, this.reason);

  /// The engine feature that was requested, e.g. `'physics'`.
  final String feature;

  /// Why the native core could not be used.
  final String reason;

  @override
  String toString() =>
      'FlashNativeUnavailableError: $feature requires the Flash native core, '
      'which is not available.\n'
      '$reason\n'
      'The native core is compiled by hook/build.dart when the app is built. '
      'If you are running on an unsupported platform, or a build hook failed, '
      'physics, particles and raycasting cannot run. The scene graph, '
      'rendering, cameras, tweens, timers, input and audio all work without '
      'it.';
}

/// Gatekeeper for the native core.
///
/// The engine degrades in three tiers rather than failing as a whole:
///
/// * **Tier 0 — scene graph, rendering, cameras, tweens, timers, input,
///   audio.** Never depends on native code. [FNode] already falls back to
///   pure-Dart transform maths when no native node is attached, so a scene
///   still builds and draws.
/// * **Tier 1 — particles.** Decorative. Emitters disable themselves and log
///   once instead of throwing; a missing spark should not kill an app.
/// * **Tier 2 — physics, joints, raycasting, soft bodies.** Cannot be
///   meaningfully faked. These throw [FlashNativeUnavailableError] at
///   construction, loudly, because a physics game silently not simulating is
///   far worse than one that fails to start.
abstract final class FlashNative {
  static bool? _override;
  static bool? _available;
  static String _reason = '';

  /// Whether the native core is loaded and ABI-compatible.
  static bool get isAvailable {
    if (_override != null) return _override!;
    return _available ??= _probe();
  }

  /// Why [isAvailable] is false. Empty when the core is available.
  static String get unavailableReason => isAvailable ? '' : _reason;

  static bool _probe() {
    final int version;
    try {
      // Side-effect free and cheap: the ideal handshake.
      version = bindings.getPhysicsVersion();
    } catch (e) {
      _reason = 'The native library could not be loaded ($e).';
      return false;
    }
    if (version != kFlashAbiVersion) {
      _reason =
          'ABI mismatch: the native core reports version $version but these '
          'Dart bindings expect $kFlashAbiVersion. The compiled library is '
          'stale — rebuild it.';
      return false;
    }
    return true;
  }

  /// Throws unless the native core is usable. Used by Tier 2 features.
  static void require(String feature) {
    if (!isAvailable) {
      throw FlashNativeUnavailableError(feature, _reason);
    }
  }

  /// Forces [isAvailable] for tests. Pass `null` to restore real probing.
  static set debugOverrideAvailable(bool? value) {
    _override = value;
    if (value == false) {
      _reason = 'Disabled via FlashNative.debugOverrideAvailable.';
    }
  }

  /// The current override, if any.
  static bool? get debugOverrideAvailable => _override;
}
