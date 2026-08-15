import 'package:flutter/material.dart';

import 'demo_controls.dart';
import 'demo_theme.dart';

/// The standard demo page: a full-bleed scene with chrome floating over it.
///
/// Every demo used to build its own scaffold. Some had an `AppBar`, some drew a
/// back arrow by hand at whatever corner was free, and the ones with controls
/// positioned each panel with its own magic numbers. The result was that no two
/// demos put the same thing in the same place, and a few had no way back at all
/// on a phone-sized window.
///
/// The scene is full-bleed on purpose — an engine demo should not be letterboxed
/// by a title bar. The chrome sits on top and, apart from the controls
/// themselves, does not take pointer events, so a demo that reacts to taps and
/// drags still receives them everywhere the user is not actually pressing a
/// button.
class DemoPage extends StatelessWidget {
  const DemoPage({
    super.key,
    required this.title,
    required this.scene,
    this.subtitle,
    this.controls = const [],
    this.readouts = const [],
    this.hint,
    this.overlays = const [],
    this.accent = DemoTheme.accent,
    this.controlsWidth = 232,
  });

  /// Shown top-left. Keep it to a couple of words.
  final String title;

  /// One line saying what the demo actually demonstrates. Worth writing: the
  /// title alone rarely says which part of the API is on show.
  final String? subtitle;

  /// The engine view. Fills the page.
  final Widget scene;

  /// Interactive controls, stacked under the title.
  final List<Widget> controls;

  /// Values the scene reports back, top-right.
  final List<Widget> readouts;

  /// One line telling the user what they can do, bottom-centre.
  final String? hint;

  /// Anything that needs its own placement — a joystick, a drawing layer.
  /// These are stacked above the scene and below the standard chrome.
  final List<Widget> overlays;

  final Color accent;

  /// Widened by demos whose controls need the room.
  final double controlsWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // On a short window the control column would run off the bottom, so it
    // scrolls rather than overflowing.
    final maxControlsHeight = media.size.height * 0.62;

    return Scaffold(
      backgroundColor: DemoTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          scene,
          ...overlays,
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(DemoTheme.edgeInset),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: controlsWidth,
                        maxHeight: maxControlsHeight,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(title: title, subtitle: subtitle, accent: accent),
                            if (controls.isNotEmpty) ...[
                              const SizedBox(height: DemoTheme.gapLarge),
                              for (final control in controls)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: DemoTheme.gap),
                                  child: control,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (readouts.isNotEmpty)
                    Align(
                      alignment: Alignment.topRight,
                      child: IgnorePointer(
                        child: DemoPanel(
                          tint: accent,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: readouts,
                        ),
                      ),
                    ),
                  if (hint != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(child: DemoHint(text: hint!)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, required this.accent});

  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _BackButton(accent: accent),
        const SizedBox(width: DemoTheme.gap),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: DemoTheme.title),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: DemoTheme.subtitle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(DemoTheme.radius),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: DemoTheme.glass(accent),
          child: Icon(Icons.arrow_back_rounded, size: 18, color: accent),
        ),
      ),
    );
  }
}
