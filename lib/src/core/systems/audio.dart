import 'dart:async';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vector_math/vector_math_64.dart';
import '../rendering/camera.dart';

class FlashAudioSystem {
  SoLoud? _soloud;
  bool _initialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  bool get isInitialized => _initialized;
  Future<void> get ready => _initCompleter.future;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _soloud = SoLoud.instance;
      await _soloud!.init();
      _initialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    } catch (e) {
      print('Failed to initialize audio: $e');
      // Should we complete with error? Best to complete so waiters can proceed/fail gracefully
      if (!_initCompleter.isCompleted) _initCompleter.completeError(e);
    }
  }

  int _pendingLoads = 0;
  bool _isDisposing = false;

  Future<AudioSource?> loadAsset(String path) async {
    if (!_initialized || _soloud == null || _isDisposing) return null;
    _pendingLoads++;
    try {
      final source = await _soloud!.loadAsset(path);
      return source;
    } catch (e) {
      print('Error loading audio asset $path: $e');
      return null;
    } finally {
      _pendingLoads--;
      if (_isDisposing && _pendingLoads == 0) {
        _performDeinit();
      }
    }
  }

  void dispose() {
    _isDisposing = true;
    _initialized = false; // Prevent new calls
    if (_pendingLoads == 0) {
      _performDeinit();
    }
    // Else: _performDeinit will be called by the last finishing loadAsset
  }

  void _performDeinit() {
    try {
      _soloud?.deinit();
    } catch (e) {
      print('Error during audio deinit: $e');
    }
    _soloud = null;
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

  void updateListener(FlashCamera camera) {
    if (!_initialized) return;

    final pos = camera.worldPosition;
    // Calculate forward/up vectors from camera rotation matrix
    final rot = camera.worldMatrix.getRotation();
    final fwd = rot.transform(Vector3(0, 0, -1)); // Assuming -Z is forward
    final up = rot.transform(Vector3(0, 1, 0)); // Assuming +Y is up

    _soloud!.set3dListenerParameters(pos.x, pos.y, pos.z, fwd.x, fwd.y, fwd.z, up.x, up.y, up.z, 0, 0, 0);
  }
}
