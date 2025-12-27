import 'package:flutter_test/flutter_test.dart';
import 'package:flash/src/core/systems/engine.dart';

void main() {
  test('Engine initializes with culling support', () {
    final engine = FEngine();
    expect(engine.renderNodes, isEmpty);
    engine.dispose();
  });
}
