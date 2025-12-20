import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../core/graph/node.dart';
import '../core/systems/engine.dart';

/// An InheritedWidget that provides the current FlashNode to descendants.
class InheritedFlashNode extends InheritedWidget {
  final FlashNode node;
  final FlashEngine engine;

  const InheritedFlashNode({required this.node, required this.engine, required super.child, super.key});

  @override
  bool updateShouldNotify(InheritedFlashNode oldWidget) => true;
}

/// Base class for all declarative Flash widgets.
abstract class FlashNodeWidget extends StatefulWidget {
  final v.Vector3? position;
  final v.Vector3? rotation;
  final v.Vector3? scale;
  final String? name;
  final Widget? child; // Optional child for nesting provided by subclasses

  const FlashNodeWidget({super.key, this.position, this.rotation, this.scale, this.name, this.child});
}

/// State class for FlashNodeWidget that manages the lifecycle of a FlashNode.
abstract class FlashNodeWidgetState<T extends FlashNodeWidget, N extends FlashNode> extends State<T> {
  late N node;
  FlashNode? _parent;

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
    final parentHost = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>();
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
    applyProperties();
  }

  @mustCallSuper
  void applyProperties() {
    if (widget.position != null) node.transform.position = widget.position!;
    if (widget.rotation != null) node.transform.rotation = widget.rotation!;
    if (widget.scale != null) node.transform.scale = widget.scale!;
    if (widget.name != null) node.name = widget.name!;
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
      final engine = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>()?.engine;
      if (engine != null) {
        return InheritedFlashNode(node: node, engine: engine, child: widget.child!);
      }
    }
    return widget.child ?? const SizedBox.shrink();
  }
}

/// Base class for widgets that can have multiple children (like Groups).
abstract class FlashMultiNodeWidget extends FlashNodeWidget {
  final List<Widget> children;

  const FlashMultiNodeWidget({
    super.key,
    required this.children,
    super.position,
    super.rotation,
    super.scale,
    super.name,
  }) : super(child: null);
}

abstract class FlashMultiNodeWidgetState<T extends FlashMultiNodeWidget, N extends FlashNode>
    extends FlashNodeWidgetState<T, N> {
  @override
  Widget build(BuildContext context) {
    final engine = context.dependOnInheritedWidgetOfExactType<InheritedFlashNode>()?.engine;
    if (engine == null) return const SizedBox.shrink();

    return InheritedFlashNode(
      node: node,
      engine: engine,
      child: Stack(children: widget.children),
    );
  }
}
