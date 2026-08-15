import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FSceneManager]: named scenes with a transition between them.
///
/// The manager is a `Listenable`, and [FSceneTransitionWidget] already listens
/// to it. This demo used to also register an engine update listener that called
/// `setState` unconditionally every frame — which was both unnecessary and
/// unbounded, since it ran inside `build` and so added another listener on
/// every rebuild it caused.
class SceneManagerDemoExample extends StatefulWidget {
  const SceneManagerDemoExample({super.key});

  @override
  State<SceneManagerDemoExample> createState() => _SceneManagerDemoExampleState();
}

class _SceneManagerDemoExampleState extends State<SceneManagerDemoExample> {
  static const List<SceneTransition> _transitions = SceneTransition.values;

  static const Map<String, ({IconData icon, String subtitle, Color colour})> _scenes = {
    'menu': (icon: Icons.menu_rounded, subtitle: 'the title screen', colour: DemoTheme.accent),
    'game': (icon: Icons.sports_esports_rounded, subtitle: 'playing', colour: DemoTheme.positive),
    'settings': (icon: Icons.settings_rounded, subtitle: 'options', colour: DemoTheme.warning),
  };

  SceneTransition _transition = SceneTransition.fade;
  FSceneManager? _manager;
  String _current = 'none';

  void _register(FSceneManager manager) {
    if (_manager != null) return;
    _manager = manager;

    for (final name in _scenes.keys) {
      manager.registerScene(
        FSceneWrapper(
          name: name,
          onEnter: () {
            if (mounted) setState(() => _current = name);
          },
        ),
      );
    }
    manager.goTo('menu', transition: SceneTransition.none);
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Scene Manager',
      subtitle: 'Named scenes, and the transition between them.',
      controls: [
        DemoPanel(
          title: 'Go to',
          children: [
            for (final name in _scenes.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DemoButton(
                  label: name,
                  icon: _scenes[name]!.icon,
                  tint: _scenes[name]!.colour,
                  selected: _current == name,
                  width: 190,
                  onPressed: () => _manager?.goTo(name, transition: _transition),
                ),
              ),
          ],
        ),
        DemoPanel(
          title: 'Transition',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _transitions)
                  DemoButton(
                    label: t.name,
                    selected: t == _transition,
                    onPressed: () => setState(() => _transition = t),
                  ),
              ],
            ),
          ],
        ),
      ],
      readouts: [
        DemoStat(label: 'Current', value: _current),
        DemoStat(label: 'Transition', value: _transition.name),
      ],
      hint: 'onEnter and onExit fire per scene; the widget listens to the manager.',
      scene: FView(
        child: Builder(
          builder: (context) {
            final engine = context.flash;
            if (engine == null) return const SizedBox.shrink();
            _register(engine.sceneManager);

            return Stack(
              children: [
                FCamera(position: v.Vector3(0, 0, 500), fov: 60),
                FSceneTransitionWidget(
                  sceneManager: engine.sceneManager,
                  builder: (scene) => _content(scene.name),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(String name) {
    final scene = _scenes[name];
    if (scene == null) return const SizedBox.shrink();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(scene.icon, size: 96, color: scene.colour),
          const SizedBox(height: DemoTheme.gapLarge),
          Text(
            name.toUpperCase(),
            style: DemoTheme.title.copyWith(fontSize: 34, letterSpacing: 4, color: scene.colour),
          ),
          const SizedBox(height: 4),
          Text(scene.subtitle, style: DemoTheme.subtitle),
        ],
      ),
    );
  }
}
