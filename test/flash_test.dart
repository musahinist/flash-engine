import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';

void main() {
  test('FNode hierarchy test', () {
    final root = FNode(name: 'root');
    final child = FNode(name: 'child');
    root.addChild(child);
    expect(root.children.length, 1);
    expect(child.parent, root);
  });
}
