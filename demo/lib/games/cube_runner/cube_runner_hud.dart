import 'package:flash/flash.dart';
import 'package:flutter/material.dart';

import 'cube_runner_game.dart';

/// CubeRunner HUD using Flash Engine UI components
class CubeRunnerHud extends StatelessWidget {
  final CubeRunnerGame game;

  const CubeRunnerHud({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top HUD bar
                FHudBar(
                  left: [
                    // Score
                    FStatCard(
                      icon: Icons.star,
                      color: Colors.amber,
                      value: game.scoreSystem.score.toString(),
                      label: 'Score',
                    ),
                    // Lives
                    FStatCard(icon: Icons.favorite, color: Colors.red, value: game.lives.toString(), label: 'Lives'),
                  ],
                  right: [
                    // Timer
                    FTimerDisplay(time: game.gameTimer.remaining, lowTimeThreshold: const Duration(seconds: 10)),
                  ],
                ),

                const Spacer(),

                // Combo display (center bottom area)
                if (game.scoreSystem.comboCount > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: FComboDisplay(multiplier: game.scoreSystem.comboCount, count: game.scoreSystem.score ~/ 10),
                  ),

                // Active power-ups
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final id in game.powerUps.activeIds)
                        FPowerUpIndicator(
                          name: id.toUpperCase(),
                          color: _getPowerUpColor(id),
                          remaining: game.powerUps.getRemaining(id),
                          icon: _getPowerUpIcon(id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getPowerUpColor(String id) {
    switch (id) {
      case 'speed':
        return Colors.orange;
      case 'shield':
        return Colors.blue;
      case 'magnet':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getPowerUpIcon(String id) {
    switch (id) {
      case 'speed':
        return Icons.flash_on;
      case 'shield':
        return Icons.shield;
      case 'magnet':
        return Icons.attractions;
      default:
        return Icons.bolt;
    }
  }
}
