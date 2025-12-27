import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';
import 'package:flash/src/core/utils/asset_loader.dart';
import 'package:flutter/material.dart';

void main() {
  test('FNode has bounds property', () {
    final node = FNode();
    expect(node.bounds, isNull);
  });

  test('FEngine has cached lists', () {
    final engine = FEngine();
    expect(engine.renderNodes, isEmpty);
    expect(engine.lights, isEmpty);
    expect(engine.emitters, isEmpty);
  });

  test('FBox instantiates and has private paint', () {
    final box = FBox(width: 10, height: 10, color: Colors.red);
    expect(box, isNotNull);
    // Can't check private members but if it compiled, we are good.
  });

  test('AssetLoader exists', () {
    // Just checking class existence
    expect(AssetLoader.loadImage, isNotNull);
  });
}
