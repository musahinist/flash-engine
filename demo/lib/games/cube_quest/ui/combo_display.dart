import 'package:flutter/material.dart';

/// Combo display widget with animation
class ComboDisplay extends StatelessWidget {
  final int multiplier;
  final int count;

  const ComboDisplay({super.key, required this.multiplier, required this.count});

  @override
  Widget build(BuildContext context) {
    if (multiplier <= 1) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.5, end: 1.0),
      duration: const Duration(milliseconds: 200),
      key: ValueKey(count),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getComboColor(multiplier).withValues(alpha: 0.8),
                  _getComboColor(multiplier).shade700.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: _getComboColor(multiplier).withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, color: Colors.white, size: 24),
                const SizedBox(width: 4),
                Text(
                  '${multiplier}x COMBO!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 1))],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  MaterialColor _getComboColor(int multiplier) {
    if (multiplier >= 10) return Colors.purple;
    if (multiplier >= 7) return Colors.red;
    if (multiplier >= 5) return Colors.orange;
    if (multiplier >= 3) return Colors.yellow;
    return Colors.green;
  }
}

/// Power-up active indicator
class ActivePowerUpIndicator extends StatelessWidget {
  final String name;
  final Color color;
  final Duration remaining;

  const ActivePowerUpIndicator({super.key, required this.name, required this.color, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            '$name ${remaining.inSeconds}s',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
