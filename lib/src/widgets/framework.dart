import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../core/graph/node.dart';
import '../core/systems/engine.dart';

/// An InheritedWidget that provides the current FlashNode to descendants.
class InheritedFNode extends InheritedWidget {
  final FNode node;
  final FEngine engine;

  const InheritedFNode({required this.node, required this.engine, required super.child, super.key});

  @override
  bool updateShouldNotify(InheritedFNode oldWidget) => oldWidget.node != node || oldWidget.engine != engine;
}

/// Extension for easy access to Flash engine from BuildContext.
///
/// Usage:
/// ```dart
/// final engine = context.flash; // Returns FEngine?
/// context.flash?.scene.addChild(myNode);
/// ```
extension FContext on BuildContext {
  /// Get the Flash engine from context. Returns null if outside FView.
  FEngine? get flash => dependOnInheritedWidgetOfExactType<InheritedFNode>()?.engine;

  /// Get the current parent node from context. Returns null if outside FView.
  FNode? get flashNode => dependOnInheritedWidgetOfExactType<InheritedFNode>()?.node;
}

/// Base class for all declarative Flash widgets.
abstract class FNodeWidget extends StatefulWidget {
  final v.Vector3? position;
  final v.Vector3? rotation;
  final v.Vector3? scale;
  final String? name;
  final Widget? child; // Optional child for nesting provided by subclasses

  final bool billboard;

  const FNodeWidget({
    super.key,
    this.name,
    this.position,
    this.rotation,
    this.scale,
    this.child,
    this.billboard = false,
  });
}

/// State class for FlashNodeWidget that manages the lifecycle of a FlashNode.
abstract class FNodeWidgetState<T extends FNodeWidget, N extends FNode> extends State<T> {
  late N node;
  FNode? _parent;

  N createNode();

  @override
  void initState() {
    super.initState();
    node = createNode();
    applyProperties();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parentHost = context.dependOnInheritedWidgetOfExactType<InheritedFNode>();
    final newParent = parentHost?.node;
    if (_parent != newParent) {
      _parent?.removeChild(node);
      _parent = newParent;
      _parent?.addChild(node);
    }
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    applyProperties(oldWidget);
  }

  @mustCallSuper
  void applyProperties([T? oldWidget]) {
    if (widget.name != oldWidget?.name) node.name = widget.name ?? node.name;

    // Only apply transform properties if they've actually changed in the widget.
    // This prevents overwriting runtime-calculated properties (like physics) on every build.
    if (widget.position != null && (oldWidget == null || widget.position != oldWidget.position)) {
      node.transform.position = widget.position!;
    }
    if (widget.rotation != null && (oldWidget == null || widget.rotation != oldWidget.rotation)) {
      node.transform.rotation = widget.rotation!;
    }
    if (widget.scale != null && (oldWidget == null || widget.scale != oldWidget.scale)) {
      node.transform.scale = widget.scale!;
    }
    if (widget.billboard != oldWidget?.billboard) {
      node.billboard = widget.billboard;
    }
  }

  @override
  void dispose() {
    _parent?.removeChild(node);
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If the widget has a child, wrap it in InheritedFlashNode so it finds this node as parent
    if (widget.child != null) {
      final engine = context.dependOnInheritedWidgetOfExactType<InheritedFNode>()?.engine;
      if (engine != null) {
        return InheritedFNode(node: node, engine: engine, child: widget.child!);
      }
    }
    return widget.child ?? const SizedBox.shrink();
  }
}

/// Base class for widgets that can have multiple children (like Groups).
abstract class FMultiNodeWidget extends FNodeWidget {
  final List<Widget> children;

  const FMultiNodeWidget({super.key, required this.children, super.position, super.rotation, super.scale, super.name})
    : super(child: null);
}

abstract class FMultiNodeWidgetState<T extends FMultiNodeWidget, N extends FNode> extends FNodeWidgetState<T, N> {
  @override
  Widget build(BuildContext context) {
    final engine = context.dependOnInheritedWidgetOfExactType<InheritedFNode>()?.engine;
    if (engine == null) return const SizedBox.shrink();

    return InheritedFNode(
      node: node,
      engine: engine,
      child: Stack(children: widget.children),
    );
  }
}
