import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class AssetLoader {
  static Future<ui.Image> loadImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
