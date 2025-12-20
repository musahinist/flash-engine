import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:ui' as ui;
import '../../core/graph/node.dart';
import '../framework.dart';
import '../../core/utils/asset_loader.dart';

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

  static Future<FlashSprite> fromAsset(
    String path, {
    Key? key,
    double? width,
    double? height,
    ui.Rect? src,
    v.Vector3? position,
    v.Vector3? rotation,
    v.Vector3? scale,
    String? name,
  }) async {
    final image = await AssetLoader.loadImage(path);
    return FlashSprite(
      key: key,
      image: image,
      width: width,
      height: height,
      position: position,
      rotation: rotation,
      scale: scale,
      name: name,
    );
  }

  @override
  State<FlashSprite> createState() => _FlashSpriteState();
}

class _FlashSpriteState extends FlashNodeWidgetState<FlashSprite, _SpriteNode> {
  @override
  _SpriteNode createNode() => _SpriteNode(image: widget.image, width: widget.width, height: widget.height);

  @override
  void applyProperties([FlashSprite? oldWidget]) {
    super.applyProperties(oldWidget);
    node.image = widget.image;
    node.width = widget.width;
    node.height = widget.height;
  }
}

class _SpriteNode extends FlashNode {
  ui.Image image;
  double? width;
  double? height;

  final Paint _paint = Paint();

  _SpriteNode({required this.image, this.width, this.height}) {
    _paint.filterQuality = FilterQuality.medium;
    _paint.isAntiAlias = true;
  }

  @override
  void draw(Canvas canvas) {
    // Only rebuild rects if size changes? The rect creation is cheap enough for now,
    // but paint creation is expensive. We cached paint.

    final double drawWidth = width ?? image.width.toDouble();
    final double drawHeight = height ?? image.height.toDouble();

    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(center: Offset.zero, width: drawWidth, height: drawHeight);

    canvas.scale(1, -1); // Un-flip Y for drawing in engine space
    canvas.drawImageRect(image, src, dst, _paint);
  }

  @override
  Rect? get bounds {
    final double drawWidth = width ?? image.width.toDouble();
    final double drawHeight = height ?? image.height.toDouble();
    return Rect.fromCenter(center: Offset.zero, width: drawWidth, height: drawHeight);
  }
}
