import 'package:flutter/widgets.dart';
import '../../core/graph/audio_node.dart';
import '../framework.dart';

class FlashAudioController {
  _FlashAudioPlayerState? _state;

  void _attach(_FlashAudioPlayerState state) => _state = state;
  void _detach() => _state = null;

  void play() => _state?.play();
  void stop() => _state?.stop();
  bool get isPlaying => _state?.isPlaying ?? false;
}

class FlashAudioPlayer extends FlashNodeWidget {
  final String assetPath;
  final bool autoplay;
  final bool loop;
  final bool is3D;
  final double volume;
  final double minDistance;
  final double maxDistance;
  final FlashAudioController? controller;

  const FlashAudioPlayer({
    super.key,
    required this.assetPath,
    this.autoplay = true,
    this.loop = false,
    this.is3D = true,
    this.volume = 1.0,
    this.minDistance = 50.0,
    this.maxDistance = 2000.0,
    this.controller,
    super.position,
    super.name,
  });

  @override
  State<FlashAudioPlayer> createState() => _FlashAudioPlayerState();
}

class _FlashAudioPlayerState extends FlashNodeWidgetState<FlashAudioPlayer, FlashAudioNode> {
  @override
  FlashAudioNode createNode() => FlashAudioNode(
    assetPath: widget.assetPath,
    autoplay: widget.autoplay,
    loop: widget.loop,
    is3D: widget.is3D,
    volume: widget.volume,
    minDistance: widget.minDistance,
    maxDistance: widget.maxDistance,
  );

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  void play() => node.play();
  void stop() => node.stop();
  bool get isPlaying => node.isPlaying;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get engine to initialize audio node
    final engine = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>()?.engine;
    if (engine != null) {
      // Initialize handles waiting for system readiness
      node.initialize(engine.audio);
    }
  }
}
