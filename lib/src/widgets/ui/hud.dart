import 'package:flutter/material.dart';

/// A stat card for displaying game statistics in HUD.
///
/// Example:
/// ```dart
/// FStatCard(
///   icon: Icons.star,
///   color: Colors.amber,
///   value: '1250',
///   label: 'Score',
/// )
/// ```
class FStatCard extends StatelessWidget {
  /// Icon to display
  final IconData icon;

  /// Icon and accent color
  final Color color;

  /// Main value (e.g., "1250")
  final String value;

  /// Label text (e.g., "Score")
  final String label;

  /// Background color
  final Color? backgroundColor;

  const FStatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: backgroundColor ?? Colors.black38, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
}

/// Timer display with urgency styling.
class FTimerDisplay extends StatelessWidget {
  /// Time remaining
  final Duration time;

  /// Threshold for "low time" warning styling
  final Duration lowTimeThreshold;

  /// Normal color
  final Color normalColor;

  /// Warning color
  final Color warningColor;

  const FTimerDisplay({
    super.key,
    required this.time,
    this.lowTimeThreshold = const Duration(seconds: 10),
    this.normalColor = Colors.cyanAccent,
    this.warningColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = time <= lowTimeThreshold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLow ? warningColor.withValues(alpha: 0.7) : Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: isLow ? Border.all(color: warningColor, width: 2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: isLow ? Colors.white : normalColor, size: 22),
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

/// Simple HUD bar layout.
class FHudBar extends StatelessWidget {
  /// Widgets to display on the left
  final List<Widget> left;

  /// Widgets to display on the right
  final List<Widget> right;

  /// Widgets to display in center
  final Widget? center;

  /// Padding around the bar
  final EdgeInsets padding;

  /// Spacing between items
  final double spacing;

  const FHudBar({
    super.key,
    this.left = const [],
    this.right = const [],
    this.center,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            // Left items
            ...left.map(
              (w) => Padding(
                padding: EdgeInsets.only(right: spacing),
                child: w,
              ),
            ),

            const Spacer(),

            // Center
            ?center,

            const Spacer(),

            // Right items
            ...right.map(
              (w) => Padding(
                padding: EdgeInsets.only(left: spacing),
                child: w,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
