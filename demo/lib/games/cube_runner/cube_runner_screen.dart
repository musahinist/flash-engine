import 'package:flash/flash.dart';
import 'package:flutter/material.dart';

import 'cube_runner_game.dart';
import 'cube_runner_hud.dart';

/// CubeRunner - Flash Engine powered cube game
class CubeRunnerScreen extends StatefulWidget {
  const CubeRunnerScreen({super.key});

  @override
  State<CubeRunnerScreen> createState() => _CubeRunnerScreenState();
}

class _CubeRunnerScreenState extends State<CubeRunnerScreen> {
  late CubeRunnerGame _game;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _game = CubeRunnerGame();
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  void _handleSwipe(Offset delta) {
    if (_game.isGameOver) return;

    final dx = delta.dx;
    final dy = delta.dy;

    // Isometric direction detection
    if ((dx > 0 && dy > 0) || (dx < 0 && dy < 0)) {
      _game.triggerMove(dx > 0 ? 0 : 1); // East or West
    } else {
      _game.triggerMove(dx > 0 ? 3 : 2); // South or North
    }
  }

  void _handleTap(Offset position, Size screenSize) {
    if (_game.isGameOver) return;

    final center = Offset(screenSize.width / 2, screenSize.height / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;

    if ((dx > 0 && dy > 0) || (dx < 0 && dy < 0)) {
      _game.triggerJump(dx > 0 ? 0 : 1);
    } else {
      _game.triggerJump(dx > 0 ? 3 : 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0221), Color(0xFF150734), Color(0xFF1A0A47)],
          ),
        ),
        child: FScene(
          autoUpdate: true,
          showDebugOverlay: false,
          onInit: (engine, viewport) {
            if (!_initialized) {
              _game.initialize(viewport);
              _initialized = true;
            }
          },
          onUpdate: () {
            _game.update(1 / 60); // 60fps fixed timestep
          },
          sceneBuilder: (context, elapsed) {
            return _buildScene(context, elapsed);
          },
          overlay: [
            // HUD
            CubeRunnerHud(game: _game),

            // Game Over Overlay
            ListenableBuilder(
              listenable: _game,
              builder: (context, _) {
                if (!_game.isGameOver) return const SizedBox.shrink();
                return FGameOverOverlay(
                  score: _game.scoreSystem.score,
                  highScore: _game.scoreSystem.highScore,
                  onRestart: () => setState(() {
                    _game.reset();
                    _initialized = false;
                  }),
                  onExit: () => Navigator.pop(context),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScene(BuildContext context, double elapsed) {
    // Sync viewport
    final engine = context.flash;
    if (engine != null && engine.viewportSize.x > 0) {
      _game.updateViewport(Size(engine.viewportSize.x, engine.viewportSize.y));
    }

    final widgets = <Widget>[];

    // Game objects (Camera, Grid, Cubes)
    // FCamera handles projection now, FLineRenderer handles grid
    widgets.addAll(_game.buildGameObjects(elapsed));

    // Gesture handling layer (Invisible, on top of 3D world)
    widgets.add(
      Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) =>
                  _handleTap(details.localPosition, Size(constraints.maxWidth, constraints.maxHeight)),
              onPanEnd: (details) {
                final velocity = details.velocity.pixelsPerSecond;
                if (velocity.distance > 400) {
                  // Velocity threshold
                  _handleSwipe(velocity);
                }
              },
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );

    return widgets;
  }
}
