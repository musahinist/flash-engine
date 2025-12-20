import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../core/graph/node.dart';
import '../framework.dart';

class FlashSprite extends FlashNodeWidget {
  final ui.Image image;
  final double? width;
  final double? height;

  const FlashSprite({
    super.key,
    required this.image,
    this.width,
    this.height,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
  });

  @override
  State<FlashSprite> createState() => _FlashSpriteState();
}

class _FlashSpriteState extends FlashNodeWidgetState<FlashSprite, _SpriteNode> {
  @override
  _SpriteNode createNode() => _SpriteNode(image: widget.image, width: widget.width, height: widget.height);

  @override
  void applyProperties() {
    super.applyProperties();
    node.image = widget.image;
    node.width = widget.width;
    node.height = widget.height;
  }
}

class _SpriteNode extends FlashNode {
  ui.Image image;
  double? width;
  double? height;

  _SpriteNode({required this.image, this.width, this.height});

  @override
  void draw(Canvas canvas) {
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;

    final double drawWidth = width ?? image.width.toDouble();
    final double drawHeight = height ?? image.height.toDouble();

    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(center: Offset.zero, width: drawWidth, height: drawHeight);

    canvas.scale(1, -1); // Un-flip Y for drawing in engine space
    canvas.drawImageRect(image, src, dst, paint);
  }
}
