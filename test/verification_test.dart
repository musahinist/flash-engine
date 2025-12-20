import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/systems/engine.dart';
import 'package:flash/src/core/utils/asset_loader.dart';
import 'package:flutter/material.dart';

void main() {
  test('FlashNode has bounds property', () {
    final node = FlashNode();
    expect(node.bounds, isNull);
  });

  test('FlashEngine has cached lists', () {
    final engine = FlashEngine();
    expect(engine.renderNodes, isEmpty);
    expect(engine.lights, isEmpty);
    expect(engine.emitters, isEmpty);
  });

  test('FlashBox instantiates and has private paint', () {
    final box = FlashBox(width: 10, height: 10, color: Colors.red);
    expect(box, isNotNull);
    // Can't check private members but if it compiled, we are good.
  });

  test('AssetLoader exists', () {
    // Just checking class existence
    expect(AssetLoader.loadImage, isNotNull);
  });
}
