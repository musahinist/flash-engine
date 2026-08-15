import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../core/graph/node.dart';
import '../framework.dart';

class FLabel extends FNodeWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const FLabel({
    super.key,
    required this.text,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    this.style = const TextStyle(color: Colors.white, fontSize: 24),
    this.textAlign = TextAlign.center,
  });

  @override
  State<FLabel> createState() => _FLabelState();
}

class _FLabelState extends FNodeWidgetState<FLabel, _FLabelNode> {
  @override
  _FLabelNode createNode() => _FLabelNode(text: widget.text, style: widget.style, textAlign: widget.textAlign);

  @override
  void applyProperties([FLabel? oldWidget]) {
    super.applyProperties(oldWidget);
    // Must go through updateLayout, not the fields directly. Writing the
    // fields left the cached ui.Image untouched, so a label's text never
    // actually changed on screen after the first frame.
    node.updateLayout(text: widget.text, style: widget.style, textAlign: widget.textAlign);
  }
}

class _FLabelNode extends FNode {
  String text;
  TextStyle style;
  TextAlign textAlign;
  final TextPainter _textPainter = TextPainter(textDirection: TextDirection.ltr);
  ui.Image? _cachedImage;
  double _lastWidth = 0;
  double _lastHeight = 0;
  bool _isGenerating = false;

  _FLabelNode({required this.text, required this.style, required this.textAlign}) {
    _layout();
  }

  void updateLayout({String? text, TextStyle? style, TextAlign? textAlign}) {
    bool dirty = false;
    if (text != null && this.text != text) {
      this.text = text;
      dirty = true;
    }
    if (style != null && this.style != style) {
      this.style = style;
      dirty = true;
    }
    if (textAlign != null && this.textAlign != textAlign) {
      this.textAlign = textAlign;
      dirty = true;
    }

    if (dirty) {
      _layout();
    }
  }

  /// Set when text changes while an image is still being rasterised, so the
  /// change is not silently dropped.
  bool _relayoutQueued = false;

  Future<void> _layout() async {
    if (_isGenerating) {
      _relayoutQueued = true;
      return;
    }
    _isGenerating = true;

    _textPainter.text = TextSpan(text: text, style: style);
    _textPainter.textAlign = textAlign;
    _textPainter.layout();

    _lastWidth = _textPainter.width;
    _lastHeight = _textPainter.height;

    if (_lastWidth <= 0 || _lastHeight <= 0) {
      _isGenerating = false;
      _drainQueuedRelayout();
      return;
    }

    // Cache the rendering into an ui.Image to completely bypass text rendering in paint loop
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _lastWidth, _lastHeight));
    _textPainter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();

    final img = await picture.toImage(_lastWidth.toInt(), _lastHeight.toInt());

    // Dispose old image if it exists
    _cachedImage?.dispose();
    _cachedImage = img;
    _isGenerating = false;
    _drainQueuedRelayout();
  }

  void _drainQueuedRelayout() {
    if (!_relayoutQueued) return;
    _relayoutQueued = false;
    _layout();
  }

  @override
  void dispose() {
    _cachedImage?.dispose();
    super.dispose();
  }

  @override
  void draw(Canvas canvas) {
    if (_cachedImage != null) {
      final paint = Paint()..filterQuality = ui.FilterQuality.medium;
      canvas.scale(1, -1); // Un-flip Y for drawing in engine space
      canvas.drawImage(_cachedImage!, Offset(-_lastWidth / 2, -_lastHeight / 2), paint);
    }
  }
}
