import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:ui' as ui;
import '../../core/graph/node.dart';
import '../framework.dart';
import '../../core/utils/asset_loader.dart';

class FSprite extends FNodeWidget {
  final ui.Image image;
  final double? width;
  final double? height;

  /// The region of [image] to draw, in image pixels. Null draws all of it.
  ///
  /// This is how you pick a frame out of an atlas, which is the usual way a
  /// game ships sprites. `fromAsset` already advertised a `src` parameter and
  /// silently dropped it: every sprite drew the whole sheet squashed into its
  /// destination rect, however many frames the sheet held.
  final ui.Rect? src;

  /// Mirrors the sprite horizontally, for a character that walks both ways
  /// off one set of frames.
  final bool flipX;

  /// Mirrors the sprite vertically.
  final bool flipY;

  const FSprite({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.src,
    this.flipX = false,
    this.flipY = false,
    super.position,
    super.rotation,
    super.scale,
    super.name,
    super.child,
  });

  static Future<FSprite> fromAsset(
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
    return FSprite(
      key: key,
      image: image,
      width: width,
      height: height,
      src: src,
      position: position,
      rotation: rotation,
      scale: scale,
      name: name,
    );
  }

  @override
  State<FSprite> createState() => _FSpriteState();
}

class _FSpriteState extends FNodeWidgetState<FSprite, _FSpriteNode> {
  @override
  _FSpriteNode createNode() => _FSpriteNode(
    image: widget.image,
    width: widget.width,
    height: widget.height,
    src: widget.src,
    flipX: widget.flipX,
    flipY: widget.flipY,
  );

  @override
  void applyProperties([FSprite? oldWidget]) {
    super.applyProperties(oldWidget);
    node.image = widget.image;
    node.width = widget.width;
    node.height = widget.height;
    node.src = widget.src;
    node.flipX = widget.flipX;
    node.flipY = widget.flipY;
  }
}

class _FSpriteNode extends FNode {
  ui.Image image;
  double? width;
  double? height;
  Rect? src;
  bool flipX;
  bool flipY;

  final Paint _paint = Paint();

  _FSpriteNode({
    required this.image,
    this.width,
    this.height,
    this.src,
    this.flipX = false,
    this.flipY = false,
  }) {
    _paint.filterQuality = FilterQuality.medium;
    _paint.isAntiAlias = true;
  }

  /// Falls back to the sprite's source size, so a frame from an atlas is drawn
  /// at the frame's size rather than the whole sheet's.
  Size get _drawSize {
    final source = src;
    return Size(
      width ?? source?.width ?? image.width.toDouble(),
      height ?? source?.height ?? image.height.toDouble(),
    );
  }

  @override
  void draw(Canvas canvas) {
    final size = _drawSize;
    final source = src ?? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height);

    // The engine is Y-up and the canvas is Y-down, so the sprite is flipped
    // back before drawing; the flip flags fold into the same scale.
    canvas.scale(flipX ? -1 : 1, flipY ? 1 : -1);
    canvas.drawImageRect(image, source, dst, _paint);
  }

  @override
  Rect? get bounds {
    final size = _drawSize;
    return Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height);
  }
}
