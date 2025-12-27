import 'node.dart';

/// Manages the game loop, root node, and global state.
/// This mirrors Godot's SceneTree.
class FSceneTree {
  /// The absolute root of the scene tree.
  late final FNode root;

  /// The currently active scene (usually a child of root).
  FNode? currentScene;

  bool paused = false;

  /// Global group management (Group Name -> Set of Nodes)
  final Map<String, Set<FNode>> _groups = {};

  FSceneTree() {
    root = FNode(name: 'root');
    // Root is technically always "in the tree"
    root.processMode = ProcessMode.always;
    _initializeRoot();
  }

  void _initializeRoot() {
    // Manually trigger enterTree for root since it has no parent to propagate it
    root.propagateEnterTree(this);
  }

  /// Change the current scene.
  /// This removes the old scene and adds the new one to root.
  void changeScene(FNode newScene) {
    if (currentScene != null) {
      currentScene!.queueFree();
      // For now, manual remove
      root.removeChild(currentScene!);
    }
    currentScene = newScene;
    root.addChild(currentScene!);
  }

  /// Main process loop.
  void process(double dt) {
    if (paused) return; // Or handle Paused process mode
    root.update(dt);
  }

  // --- Group Management ---

  /// Registers a node to a group. Internal use by FNode.
  void registerNodeToGroup(FNode node, String group) {
    _groups.putIfAbsent(group, () => {}).add(node);
  }

  /// Unregisters a node from a group. Internal use by FNode.
  void unregisterNodeFromGroup(FNode node, String group) {
    final set = _groups[group];
    if (set != null) {
      set.remove(node);
      if (set.isEmpty) {
        _groups.remove(group);
      }
    }
  }

  /// Execute a callback on all nodes in the specified group.
  /// Safe to remove nodes during iteration (creates a copy).
  void callGroup(String group, void Function(FNode node) callback) {
    final nodes = _groups[group];
    if (nodes == null) return;

    for (final node in List.of(nodes)) {
      callback(node);
    }
  }

  /// Type-safe version of callGroup.
  /// Only executes callback if the node is of type T.
  void notifyGroup<T extends FNode>(String group, void Function(T node) callback) {
    final nodes = _groups[group];
    if (nodes == null) return;

    for (final node in List.of(nodes)) {
      if (node is T) {
        callback(node);
      }
    }
  }

  /// Returns a list of all nodes in a group.
  List<FNode> getNodesInGroup(String group) {
    return _groups[group]?.toList() ?? [];
  }
}
