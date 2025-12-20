import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';

void main() {
  test('FlashNode hierarchy test', () {
    final root = FlashNode(name: 'root');
    final child = FlashNode(name: 'child');
    root.addChild(child);
    expect(root.children.length, 1);
    expect(child.parent, root);
  });
}
