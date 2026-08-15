import 'package:flutter/material.dart';

/// The one place demo colours, spacing and text styles are defined.
///
/// Before this, twenty-six demos each picked their own background — twelve
/// different near-blacks between them — and re-derived the same neon panel
/// treatment inline. Anything a demo needs more than once belongs here.
abstract final class DemoTheme {
  // --- Surfaces -----------------------------------------------------------

  /// Page background. Deep enough that additive-looking neon reads as emissive.
  static const Color background = Color(0xFF07080F);

  /// A slightly lifted surface, for panels sitting on [background].
  static const Color surface = Color(0xFF10131F);

  /// The catalogue's backdrop, the only place a gradient is used.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF07080F), Color(0xFF121A2E), Color(0xFF0B2545)],
  );

  // --- Accents ------------------------------------------------------------

  /// Primary accent. Interactive things are this colour unless they mean
  /// something else.
  static const Color accent = Color(0xFF4DF3FF);

  /// Secondary accent, for a second series or an alternate mode.
  static const Color accentAlt = Color(0xFFB388FF);

  /// Positive / active.
  static const Color positive = Color(0xFF6BFFB8);

  /// Warning, and the colour for anything that is a stress test.
  static const Color warning = Color(0xFFFFC46B);

  /// Destructive or failing.
  static const Color danger = Color(0xFFFF6B8A);

  // --- Text ---------------------------------------------------------------

  static const Color textPrimary = Color(0xFFEFF3FF);
  static const Color textSecondary = Color(0xB3EFF3FF);
  static const Color textMuted = Color(0x66EFF3FF);

  static const TextStyle title = TextStyle(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle subtitle = TextStyle(
    color: textSecondary,
    fontSize: 13,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(color: textSecondary, fontSize: 13);

  static const TextStyle label = TextStyle(
    color: textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  /// Readouts that change every frame. Tabular figures so the panel does not
  /// jitter as digits change width.
  static const TextStyle readout = TextStyle(
    color: textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // --- Metrics ------------------------------------------------------------

  static const double gap = 8;
  static const double gapLarge = 16;
  static const double radius = 10;
  static const double panelPadding = 12;

  /// Distance overlays keep from the viewport edge.
  static const double edgeInset = 16;

  // --- Helpers ------------------------------------------------------------

  /// The translucent fill used by every panel and button, tinted by [accent].
  static BoxDecoration glass(Color tint, {double opacity = 0.08, bool border = true}) {
    return BoxDecoration(
      color: Color.lerp(surface.withValues(alpha: 0.82), tint, opacity * 0.5),
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: tint.withValues(alpha: 0.35)) : null,
    );
  }

  static ThemeData materialTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: Color(0x33EFF3FF),
        trackHeight: 3,
      ),
    );
  }
}
