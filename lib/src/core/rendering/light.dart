import 'package:flutter/widgets.dart';
import '../graph/node.dart';

class FlashLight extends FlashNode {
  Color color;
  double intensity;

  FlashLight({super.name = 'FlashLight', this.color = const Color(0xFFFFFFFF), this.intensity = 1.0});
}
