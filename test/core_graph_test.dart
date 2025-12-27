import 'package:flutter_test/flutter_test.dart';
import 'package:flash/src/core/graph/node.dart';
import 'package:flash/src/core/graph/tree.dart';
import 'package:flash/src/core/graph/signal.dart';
import 'package:flash/src/core/systems/engine.dart';

void main() {
  final engine = FEngine();
  group('FSignal', () {
    test('emit notifies listeners', () {
      final signal = FSignal<int>();
      int received = 0;
      signal.connect((payload) => received = payload);
      signal.emit(42);
      expect(received, 42);
    });

    test('disconnect removes listener', () {
      final signal = FSignalVoid();
      int count = 0;
      void listener() => count++;
      signal.connect(listener);
      signal.disconnect(listener);
      signal.emit();
      expect(count, 0);
    });
  });

  group('Groups', () {
    test('Nodes register/unregister with tree via groups', () {
      final tree = FSceneTree(engine);
      final node = FNode(name: 'GroupNode');

      // Add to group BEFORE entering tree
      node.addToGroup('enemies');
      expect(node.isInGroup('enemies'), isTrue);
      // Tree doesn't know about it yet
      expect(tree.getNodesInGroup('enemies'), isEmpty);

      // Enter tree
      tree.root.addChild(node);
      expect(tree.getNodesInGroup('enemies'), contains(node));

      // Remove from group
      node.removeFromGroup('enemies');
      expect(tree.getNodesInGroup('enemies'), isEmpty);
    });

    test('callGroup executes on all nodes', () {
      final tree = FSceneTree(engine);
      final node1 = FNode(name: 'n1');
      final node2 = FNode(name: 'n2');

      tree.root.addChild(node1);
      tree.root.addChild(node2);

      node1.addToGroup('all');
      node2.addToGroup('all');

      final hitList = <String>[];
      tree.callGroup('all', (n) => hitList.add(n.name));

      expect(hitList, containsAll(['n1', 'n2']));
    });

    test('Groups persist across tree re-parenting (enter/exit)', () {
      final tree = FSceneTree(engine);
      final node = FNode(name: 'PersistentNode');
      node.addToGroup('persistent');

      tree.root.addChild(node);
      expect(tree.getNodesInGroup('persistent'), contains(node));

      tree.root.removeChild(node);
      expect(tree.getNodesInGroup('persistent'), isEmpty);

      tree.root.addChild(node);
      expect(tree.getNodesInGroup('persistent'), contains(node));
    });
  });
}
