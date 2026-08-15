import 'dart:math';

import 'package:flutter/material.dart';

import 'demo_theme.dart';

/// An on-screen thumbstick, for demos that want to be usable without a keyboard.
///
/// Reports a normalised vector in **screen** coordinates: +y is down, matching
/// the drag. The engine is Y-up, so a caller feeding this into world movement
/// negates y — which is exactly the sort of thing that was being got wrong
/// differently in each of the three copies of this widget that existed before.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.onStickDrag,
    this.radius = 60,
    this.tint = DemoTheme.accent,
  });

  /// Called with each axis in -1..1, and with (0, 0) on release.
  final void Function(double dx, double dy) onStickDrag;

  final double radius;
  final Color tint;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _stick = Offset.zero;

  void _update(Offset localPosition) {
    final centre = Offset(widget.radius, widget.radius);
    final delta = localPosition - centre;
    final distance = delta.distance;
    final clamped = distance > 0
        ? delta / distance * min(distance, widget.radius)
        : Offset.zero;

    setState(() => _stick = clamped);
    widget.onStickDrag(clamped.dx / widget.radius, clamped.dy / widget.radius);
  }

  void _release() {
    setState(() => _stick = Offset.zero);
    widget.onStickDrag(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final knob = widget.radius * 0.62;

    return GestureDetector(
      onPanStart: (details) => _update(details.localPosition),
      onPanUpdate: (details) => _update(details.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: Container(
        width: widget.radius * 2,
        height: widget.radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DemoTheme.surface.withValues(alpha: 0.55),
          border: Border.all(color: widget.tint.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Center(
          child: Transform.translate(
            offset: _stick,
            child: Container(
              width: knob,
              height: knob,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.tint.withValues(alpha: 0.55),
                border: Border.all(color: widget.tint, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
