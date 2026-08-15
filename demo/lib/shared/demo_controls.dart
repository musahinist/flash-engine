import 'package:flutter/material.dart';

import 'demo_theme.dart';

/// The overlay chrome every demo draws on top of its scene.
///
/// Each of these replaced a `_buildButton` / `_buildHUD` / `_buildSlider`
/// private method that had been copied between demos and drifted — twenty of
/// them across twenty-six files, no two quite alike.

/// A translucent container for a cluster of controls or readouts.
class DemoPanel extends StatelessWidget {
  const DemoPanel({
    super.key,
    required this.children,
    this.title,
    this.tint = DemoTheme.accent,
    this.width,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;

  /// Small all-caps heading. Omit for an unlabelled cluster.
  final String? title;
  final Color tint;
  final double? width;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(DemoTheme.panelPadding),
      decoration: DemoTheme.glass(tint),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (title != null) ...[
            Text(title!.toUpperCase(), style: DemoTheme.label.copyWith(color: tint)),
            const SizedBox(height: DemoTheme.gap),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// A single action.
///
/// [selected] draws it as the active choice in a set, which is how most demos
/// were using their hand-rolled buttons.
class DemoButton extends StatelessWidget {
  const DemoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tint = DemoTheme.accent,
    this.selected = false,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color tint;
  final bool selected;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? tint : DemoTheme.textMuted;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(DemoTheme.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.22 : 0.08),
              borderRadius: BorderRadius.circular(DemoTheme.radius),
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.9 : 0.35),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? DemoTheme.textPrimary : DemoTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A button that reports and flips a boolean.
class DemoToggle extends StatelessWidget {
  const DemoToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.tint = DemoTheme.accent,
    this.width,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color tint;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return DemoButton(
      label: label,
      icon: value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
      tint: tint,
      selected: value,
      width: width,
      onPressed: () => onChanged(!value),
    );
  }
}

/// A labelled slider that shows its current value.
class DemoSlider extends StatelessWidget {
  const DemoSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.fractionDigits = 1,
    this.suffix = '',
    this.tint = DemoTheme.accent,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int fractionDigits;
  final String suffix;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: DemoTheme.body),
            Text(
              '${value.toStringAsFixed(fractionDigits)}$suffix',
              style: DemoTheme.readout.copyWith(fontSize: 13, color: tint),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: tint,
            thumbColor: tint,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

/// A label above a value, for anything the scene reports back.
class DemoStat extends StatelessWidget {
  const DemoStat({
    super.key,
    required this.label,
    required this.value,
    this.tint = DemoTheme.textPrimary,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: DemoTheme.label),
          Text(value, style: DemoTheme.readout.copyWith(color: tint)),
        ],
      ),
    );
  }
}

/// A colour swatch beside a description, for explaining what is on screen.
class DemoLegend extends StatelessWidget {
  const DemoLegend({super.key, required this.entries});

  final List<({Color color, String label})> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: e.color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [BoxShadow(color: e.color.withValues(alpha: 0.5), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: DemoTheme.gap),
                Text(e.label, style: DemoTheme.body),
              ],
            ),
          ),
      ],
    );
  }
}

/// One line telling the user what to do. Demos are useless if the interaction
/// is undiscoverable, and most of these were relying on the visitor guessing.
class DemoHint extends StatelessWidget {
  const DemoHint({super.key, required this.text, this.icon = Icons.touch_app_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: DemoTheme.glass(DemoTheme.textPrimary, opacity: 0.04),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: DemoTheme.textMuted),
          const SizedBox(width: DemoTheme.gap),
          Flexible(child: Text(text, style: DemoTheme.body)),
        ],
      ),
    );
  }
}
