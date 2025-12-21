import 'package:vector_math/vector_math_64.dart';
import '../systems/audio.dart';
import '../graph/node.dart';

// We need a way to access the AudioSystem.
// Usually nodes don't access singletons directly, but for now we might need to
// rely on the Widget layer to inject it, OR Engine provides it.
// Assuming we pass Engine or AudioSystem to update?
// FlashNode.update(dt) doesn't pass context.
// Ideally, the Node should be registered with the AudioSystem.

class FlashAudioNode extends FlashNode {
  final String assetPath;
  final bool autoplay;
  final bool loop;
  final bool is3D;
  final double volume;

  final double minDistance;
  final double maxDistance;

  // Runtime state
  AudioSource? _source;
  final List<SoundHandle> _handles = [];
  FlashAudioSystem? _system;
  Vector3 _lastPosition = Vector3.zero();

  FlashAudioNode({
    required this.assetPath,
    super.name = 'AudioNode',
    this.autoplay = true,
    this.loop = false,
    this.is3D = true, // Default to 3D since it's a node in the graph
    this.volume = 1.0,
    this.minDistance = 50.0,
    this.maxDistance = 2000.0,
  });

  // Called when node is added to scene.. or customized lifecycle?
  // Since we don't have "onEnterTree" yet in generic FlashNode,
  // we rely on declarative widget to trigger init, OR we add lazy init in update.

  Future<void> initialize(FlashAudioSystem system) async {
    if (_source != null) return; // Already initialized

    _system = system;
    _lastPosition = worldPosition.clone();
    await system.ready; // Wait for initialization
    _source = await system.loadAsset(assetPath);
    if (_source != null && autoplay) {
      play();
    }
  }

  Future<void> play() async {
    if (_source == null || _system == null) return;

    // Prune invalid handles
    _handles.removeWhere((h) => !_system!.isValidHandle(h));

    try {
      final handle = await _system!.play(
        _source!,
        loop: loop,
        volume: volume,
        position: is3D ? worldPosition : null,
        paused: false,
      );

      _handles.add(handle);

      // Initial 3D update
      if (is3D) {
        _system!.setSourceAttributes(handle, worldPosition, minDistance, maxDistance);
      }
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void stop() {
    if (_system != null) {
      for (final handle in _handles) {
        _system!.stop(handle);
      }
    }
    _handles.clear();
  }

  bool get isPlaying => _handles.isNotEmpty;

  @override
  void update(double dt) {
    super.update(dt);

    if (_system != null && is3D) {
      final pos = worldPosition;
      for (final handle in _handles) {
        _system!.setSourceAttributes(handle, pos, minDistance, maxDistance);
      }
    }
  }

  @override
  void dispose() {
    stop();
    // We don't dispose the Source because it might be cached/shared?
    // SoLoud manages sources.
    super.dispose();
  }
}
