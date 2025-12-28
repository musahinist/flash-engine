import 'package:flutter/material.dart';
import '../models/game_state.dart';
import 'combo_display.dart';

/// HUD overlay for game stats
class HudOverlay extends StatelessWidget {
  final GameState state;
  final VoidCallback? onPause;
  final VoidCallback? onRestart;

  const HudOverlay({super.key, required this.state, this.onPause, this.onRestart});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top bar
            Row(
              children: [
                // Back button
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                // Score
                _buildStatCard(icon: Icons.star, color: Colors.amber, value: '${state.score}', label: 'Score'),
                const SizedBox(width: 12),
                // Lives
                _buildStatCard(icon: Icons.favorite, color: Colors.red, value: '${state.lives}', label: 'Lives'),
                const Spacer(),
                // Time (if time mode)
                if (state.isTimeMode) _buildTimeCard(state.timeRemaining),
              ],
            ),
            const SizedBox(height: 8),
            // Active power-ups row
            if (state.activePowerUps.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: state.activePowerUps.entries
                      .where((e) => DateTime.now().isBefore(e.value))
                      .map(
                        (e) => ActivePowerUpIndicator(
                          name: e.key.name,
                          color: e.key.color,
                          remaining: e.value.difference(DateTime.now()),
                        ),
                      )
                      .toList(),
                ),
              ),
            const Spacer(),
            // Combo display (centered)
            if (state.comboMultiplier > 1) ComboDisplay(multiplier: state.comboMultiplier, count: state.comboCount),
            const SizedBox(height: 60),
            // Keys collected
            if (state.keysCollected > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.vpn_key, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${state.keysCollected}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required Color color, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(Duration time) {
    final isLow = time.inSeconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLow ? Colors.red.withValues(alpha: 0.7) : Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: isLow ? Border.all(color: Colors.red, width: 2) : null,
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: isLow ? Colors.white : Colors.cyanAccent, size: 22),
          const SizedBox(width: 8),
          Text(
            '${time.inSeconds}s',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: isLow ? [const Shadow(color: Colors.red, blurRadius: 8)] : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Game over overlay
class GameOverOverlay extends StatelessWidget {
  final int score;
  final int highScore;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const GameOverOverlay({
    super.key,
    required this.score,
    required this.highScore,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final isNewHighScore = score >= highScore && score > 0;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey.shade900, Colors.grey.shade800],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isNewHighScore ? Colors.amber : Colors.white24, width: 2),
            boxShadow: [
              BoxShadow(
                color: (isNewHighScore ? Colors.amber : Colors.black).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GAME OVER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  shadows: [Shadow(color: isNewHighScore ? Colors.amber : Colors.cyanAccent, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 24),
              if (isNewHighScore) ...[
                const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
                const SizedBox(height: 8),
                const Text(
                  '🎉 NEW HIGH SCORE! 🎉',
                  style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Score: $score',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('High Score: $highScore', style: const TextStyle(color: Colors.white60, fontSize: 16)),
              const SizedBox(height: 32),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Play Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: onExit,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Exit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
