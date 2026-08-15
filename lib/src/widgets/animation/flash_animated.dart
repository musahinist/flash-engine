import 'package:flutter/widgets.dart';

import '../../core/systems/engine.dart';
import '../framework.dart';

/// Rebuilds its subtree every engine frame, handing the builder the engine's
/// elapsed time in seconds.
///
/// ```dart
/// FAnimated(
///   builder: (context, elapsed) => FSphere(
///     position: v.Vector3(sin(elapsed) * 100, 0, 0),
///   ),
/// )
/// ```
///
/// This has to listen to the engine itself. It used to be a `StatelessWidget`
/// that read `context.flash` and returned `builder(context, engine.elapsed)`,
/// which looked right and never animated: `context.flash` depends on
/// `InheritedFNode`, whose `updateShouldNotify` compares the engine and the
/// node — both of which are the same objects on every frame, so it never
/// notified. And because `FView` hands its subtree the identical child widget
/// each rebuild, Flutter short-circuited the subtree too. The result was a
/// builder that ran exactly once, for the lifetime of the widget.
class FAnimated extends StatelessWidget {
  const FAnimated({super.key, required this.builder});

  /// Receives the engine's elapsed time, in seconds.
  final Widget Function(BuildContext context, double elapsed) builder;

  @override
  Widget build(BuildContext context) {
    return _EngineFrame(
      builder: (context, engine) => builder(context, engine.elapsed),
    );
  }
}

/// [FAnimated] for a list of children, for scenes built from one clock.
///
/// ```dart
/// FAnimatedList(
///   builder: (context, elapsed) => [
///     FSphere(position: v.Vector3(sin(elapsed) * 100, 0, 0)),
///     FBox(rotation: v.Vector3(0, elapsed, 0)),
///   ],
/// )
/// ```
class FAnimatedList extends StatelessWidget {
  const FAnimatedList({super.key, required this.builder});

  /// Receives the engine's elapsed time and returns the children to show.
  final List<Widget> Function(BuildContext context, double elapsed) builder;

  @override
  Widget build(BuildContext context) {
    return _EngineFrame(
      builder: (context, engine) => Stack(children: builder(context, engine.elapsed)),
    );
  }
}

/// Rebuilds `builder` whenever the engine ticks.
///
/// [FEngine] is a `Listenable` that notifies once per frame, so subscribing to
/// it directly is what makes the rebuild happen — rather than relying on an
/// ancestor to rebuild, which is the trap the previous version fell into.
class _EngineFrame extends StatelessWidget {
  const _EngineFrame({required this.builder});

  final Widget Function(BuildContext context, FEngine engine) builder;

  @override
  Widget build(BuildContext context) {
    final engine = context.flash;
    if (engine == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) => builder(context, engine),
    );
  }
}
