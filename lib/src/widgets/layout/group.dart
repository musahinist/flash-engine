import 'package:flutter/material.dart';
import '../../core/graph/node.dart';
import '../framework.dart';

class FlashNodes extends FlashMultiNodeWidget {
  const FlashNodes({super.key, required super.children, super.position, super.rotation, super.scale, super.name});

  @override
  State<FlashNodes> createState() => _FlashNodesState();
}

class _FlashNodesState extends FlashMultiNodeWidgetState<FlashNodes, FlashNode> {
  @override
  FlashNode createNode() => FlashNode();
}

class FlashNodeGroup extends FlashNodeWidget {
  const FlashNodeGroup({super.key, super.position, super.rotation, super.scale, super.name, super.child});

  @override
  State<FlashNodeGroup> createState() => _FlashNodeGroupState();
}

class _FlashNodeGroupState extends FlashNodeWidgetState<FlashNodeGroup, FlashNode> {
  @override
  FlashNode createNode() => FlashNode();
}
