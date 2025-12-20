import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../core/graph/node.dart';
import '../framework.dart';

class FlashLabel extends FlashNodeWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const FlashLabel({
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
  State<FlashLabel> createState() => _FlashLabelState();
}

class _FlashLabelState extends FlashNodeWidgetState<FlashLabel, _LabelNode> {
  @override
  _LabelNode createNode() => _LabelNode(text: widget.text, style: widget.style, textAlign: widget.textAlign);

  @override
  void applyProperties() {
    super.applyProperties();
    node.text = widget.text;
    node.style = widget.style;
    node.textAlign = widget.textAlign;
  }
}

class _LabelNode extends FlashNode {
  String text;
  TextStyle style;
  TextAlign textAlign;
  final TextPainter _textPainter = TextPainter(textDirection: TextDirection.ltr);
  ui.Image? _cachedImage;
  double _lastWidth = 0;
  double _lastHeight = 0;
  bool _isGenerating = false;

  _LabelNode({required this.text, required this.style, required this.textAlign}) {
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

  Future<void> _layout() async {
    if (_isGenerating) return;
    _isGenerating = true;

    _textPainter.text = TextSpan(text: text, style: style);
    _textPainter.textAlign = textAlign;
    _textPainter.layout();

    _lastWidth = _textPainter.width;
    _lastHeight = _textPainter.height;

    if (_lastWidth <= 0 || _lastHeight <= 0) {
      _isGenerating = false;
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
