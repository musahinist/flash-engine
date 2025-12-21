import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../rendering/camera.dart';

// Abstract handle for outside usage (just an ID)
class SoundHandle {
  final int id;
  const SoundHandle(this.id);
  @override
  bool operator ==(Object other) => other is SoundHandle && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

// Wrapper for an asset source
class AudioSource {
  final String path;
  AudioSource(this.path);
}

class FlashAudioSystem {
  static int _nextHandleId = 1;
  final Map<SoundHandle, AudioPlayer> _activePlayers = {};

  v.Vector3? _listenerPosition;

  bool _initialized = false;
  bool get isInitialized => _initialized;
  final Completer<void> _initCompleter = Completer();
  Future<void> get ready => _initCompleter.future;

  Future<void> init() async {
    if (_initialized) return;

    // AudioPlayers setup if needed
    // Global config can be set here
    _initialized = true;
    _initCompleter.complete();
  }

  void dispose() {
    // Stop all players
    for (final player in _activePlayers.values) {
      try {
        player.dispose();
      } catch (e) {
        // Already disposed
      }
    }
    _activePlayers.clear();
    _initialized = false;
  }

  Future<AudioSource?> loadAsset(String path) async {
    // Just return wrapper, AudioPlayers handles loading
    return AudioSource(path);
  }

  void updateListener(FlashCameraNode camera) {
    _listenerPosition = camera.worldPosition;
  }

  // Public method to set volume/pan for a specific handle
  void setSourceAttributes(SoundHandle handle, v.Vector3 position, double minDistance, double maxDistance) {
    final player = _activePlayers[handle];
    if (player == null || _listenerPosition == null) return;

    final distance = _listenerPosition!.distanceTo(position);

    // Linear attenuation
    // Volume: 1.0 at minDistance, 0.0 at maxDistance
    double volume = 1.0;
    if (distance > minDistance) {
      if (distance >= maxDistance) {
        volume = 0.0;
      } else {
        volume = 1.0 - ((distance - minDistance) / (maxDistance - minDistance));
      }
    }

    try {
      player.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      // Player may have been disposed unexpectedly, remove it
      _activePlayers.remove(handle);
    }
  }

  Future<SoundHandle> play(
    AudioSource source, {
    double volume = 1.0,
    double pan = 0.0,
    bool loop = false,
    bool paused = false,
    v.Vector3? position,
    v.Vector3? velocity,
  }) async {
    if (!_initialized) throw Exception('Audio system not init');

    final player = AudioPlayer();
    final handle = SoundHandle(_nextHandleId++);
    _activePlayers[handle] = player;

    // Remove from map when finished
    player.onPlayerComplete.listen((_) {
      if (!loop) {
        _activePlayers.remove(handle);
        try {
          player.dispose();
        } catch (e) {
          // Already disposed
        }
      }
    });

    await player.setSource(AssetSource(source.path));
    await player.setVolume(volume);

    // Balance for pan (-1.0 to 1.0)
    await player.setBalance(pan.clamp(-1.0, 1.0));

    if (loop) {
      await player.setReleaseMode(ReleaseMode.loop);
    } else {
      await player.setReleaseMode(ReleaseMode.release);
    }

    if (!paused) {
      await player.resume();
    }

    return handle;
  }

  Future<void> stop(SoundHandle handle) async {
    final player = _activePlayers[handle];
    if (player != null) {
      try {
        await player.stop();
      } catch (e) {
        // Already stopped or disposed
      }
      _activePlayers.remove(handle);
      try {
        await player.dispose();
      } catch (e) {
        // Already disposed
      }
    }
  }

  bool isValidHandle(SoundHandle handle) {
    return _activePlayers.containsKey(handle);
  }

  // Legacy stubs (unused but kept if interfaces expect them, or just removed)
  void set3dMinMaxDistance(SoundHandle handle, double min, double max) {}
  void set3dSourcePosition(SoundHandle handle, double x, double y, double z) {}
}
