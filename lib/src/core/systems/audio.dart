import 'dart:async';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vector_math/vector_math_64.dart';
import '../rendering/camera.dart';

class FlashAudioSystem {
  SoLoud? _soloud;
  bool _initialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  // Static reference counter to manage SoLoud singleton lifecycle
  static int _activeSystems = 0;

  bool get isInitialized => _initialized;
  Future<void> get ready => _initCompleter.future;

  Future<void> init() async {
    if (_initialized) return;

    _soloud = SoLoud.instance;
    _activeSystems++;

    // Prevent double initialization if SoLoud is already active
    if (_soloud!.isInitialized) {
      _initialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      return;
    }

    try {
      // Check if already initialized (if property available)
      // or just try init and catch failure
      await _soloud!.init();
    } catch (e) {
      print('Audio init failed ($e). Attempting cleanup and retry...');
      try {
        _soloud!.deinit(); // Force cleanup of previous session errors
        await _soloud!.init();
      } catch (retryError) {
        print('Failed to initialize audio after retry: $retryError');
        // Reduce count since we failed
        _activeSystems--;
        if (!_initCompleter.isCompleted) _initCompleter.completeError(retryError);
        return;
      }
    }

    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  int _pendingLoads = 0;
  bool _isDisposing = false;

  // Static cache for loaded sources to prevent memory leaks and redundant loading
  static final Map<String, AudioSource> _sourceCache = {};

  Future<AudioSource?> loadAsset(String path) async {
    if (!_initialized || _soloud == null || _isDisposing) return null;

    // Check cache first
    if (_sourceCache.containsKey(path)) {
      return _sourceCache[path];
    }

    _pendingLoads++;
    try {
      final source = await _soloud!.loadAsset(path);
      _sourceCache[path] = source;
      return source;
    } catch (e) {
      print('Error loading audio asset $path: $e');
      return null;
    } finally {
      _pendingLoads--;
      // Only deinit if this specific system is disposing AND no other systems are active
      if (_isDisposing && _pendingLoads == 0 && _activeSystems <= 0) {
        // Double check active systems just in case of race
        if (_activeSystems <= 0) _performDeinit();
      }
    }
  }

  void dispose() {
    if (_isDisposing) return;
    _isDisposing = true;
    _initialized = false;
    _activeSystems--;

    // Only deinit if no more active systems and no pending loads
    if (_activeSystems <= 0) {
      // Ensure we don't go negative
      _activeSystems = 0;
      if (_pendingLoads == 0) {
        _performDeinit();
      }
    }
  }

  void _performDeinit() {
    // Final check: if dynamic activation happened during wait?
    // But _activeSystems is static, so if it bumped up, we shouldn't deinit.
    if (_activeSystems > 0) return;

    // Final check: if dynamic activation happened during wait?
    // But _activeSystems is static, so if it bumped up, we shouldn't deinit.
    if (_activeSystems > 0) return;

    try {
      if (_soloud != null && _soloud!.isInitialized) {
        // Stopping all sounds prevents voice callbacks from firing after Isolate death
        // which causes the crash on Hot Restart.
        _soloud!.stopAll();

        // We do NOT deinit, because SoLoud C++ engine doesn't handle Hot Restart
        // gracefully (callbacks race with Isolates). Keeping it alive is safer.
        // _soloud!.deinit();
      }
    } catch (e) {
      print('Error during audio deinit: $e');
    }
    _sourceCache.clear();
    // _soloud = null;
  }

  Future<SoundHandle> play(
    AudioSource source, {
    bool loop = false,
    double volume = 1.0,
    Vector3? position,
    bool paused = false,
  }) async {
    if (!_initialized || _soloud == null) return SoundHandle(0);

    // Play the sound (initially paused to set attributes)
    final handle = await _soloud!.play(source, volume: volume, looping: loop, paused: true);

    if (position != null) {
      _soloud!.set3dSourceParameters(handle, position.x, position.y, position.z, 0, 0, 0);
    }

    if (!paused) {
      _soloud!.setPause(handle, false);
    }

    return handle;
  }

  void stop(SoundHandle handle) {
    if (!_initialized) return;
    _soloud?.stop(handle);
  }

  bool isValidHandle(SoundHandle handle) {
    if (!_initialized) return false;
    return _soloud?.getIsValidVoiceHandle(handle) ?? false;
  }

  void update3DSource(SoundHandle handle, Vector3 position, Vector3 velocity) {
    if (!_initialized) return;
    _soloud?.set3dSourceParameters(handle, position.x, position.y, position.z, velocity.x, velocity.y, velocity.z);
  }

  void set3dMinMaxDistance(SoundHandle handle, double min, double max) {
    if (!_initialized) return;
    _soloud?.set3dSourceMinMaxDistance(handle, min, max);
  }

  void set3dAttenuation(SoundHandle handle, int model, double rolloff) {
    if (!_initialized) return;
    // model: 0=Inverse, 1=Linear, 2=Exponential
    // mappings might vary. SoLoud enum usually available.
    // Explicitly using numeric or exposed types if imported.
    // _soloud?.set3dSourceAttenuation(handle, SoundAttenuationModel.values[model], rolloff);
    print('set3dAttenuation not implemented due to missing Enum export');
  }

  void updateListener(FlashCameraNode camera) {
    if (!_initialized) return;

    final pos = camera.worldPosition;
    // Calculate forward/up vectors from camera rotation matrix
    final rot = camera.worldMatrix.getRotation();
    final fwd = rot.transform(Vector3(0, 0, -1)); // Assuming -Z is forward
    final up = rot.transform(Vector3(0, 1, 0)); // Assuming +Y is up

    _soloud!.set3dListenerParameters(pos.x, pos.y, pos.z, fwd.x, fwd.y, fwd.z, up.x, up.y, up.z, 0, 0, 0);
  }
}
