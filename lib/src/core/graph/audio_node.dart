import '../systems/audio.dart';
import '../graph/node.dart';

/// A sound attached to a point in the scene graph.
///
/// The node does not reach for the audio system itself; [initialize] is called
/// by the widget layer, which has the engine and therefore the system.
class FAudioNode extends FNode {
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
  FAudioSystem? _system;

  FAudioNode({
    required this.assetPath,
    super.name = 'AudioNode',
    this.autoplay = true,
    this.loop = false,
    this.is3D = true, // Default to 3D since it's a node in the graph
    this.volume = 1.0,
    this.minDistance = 50.0,
    this.maxDistance = 2000.0,
  });

  Future<void> initialize(FAudioSystem system) async {
    if (_source != null) return; // Already initialized

    _system = system;
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

    // Errors are not caught here. Playback failing used to be swallowed with a
    // print to stdout, which a library has no business doing and which no
    // caller could react to. It now travels back through this Future, where
    // Flutter's error reporting picks it up with a stack trace.
    final handle = await _system!.play(
      _source!,
      loop: loop,
      volume: volume,
      position: is3D ? worldPosition : null,
      paused: false,
    );

    _handles.add(handle);

    if (is3D) {
      _system!.setSourceAttributes(handle, worldPosition, minDistance, maxDistance);
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
  void process(double dt) {

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
