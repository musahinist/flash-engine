import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class JointsDemoExample extends StatefulWidget {
  const JointsDemoExample({super.key});

  @override
  State<JointsDemoExample> createState() => _JointsDemoExampleState();
}

class _JointsDemoExampleState extends State<JointsDemoExample> {
  int selectedDemo = 0;
  final List<String> demoNames = [
    'Rope Bridge (Distance)',
    'Pendulum (Revolute)',
    'Piston (Prismatic)',
    'Ragdoll (Weld)',
    'All Joints',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Box2D Joints Demo'),
        backgroundColor: Colors.black87,
        actions: [
          DropdownButton<int>(
            value: selectedDemo,
            dropdownColor: Colors.black87,
            style: const TextStyle(color: Colors.white),
            items: List.generate(demoNames.length, (i) => DropdownMenuItem(value: i, child: Text(demoNames[i]))),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedDemo = value);
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Flash(
        child: Stack(
          children: [
            FlashCamera(position: v.Vector3(0, 0, 800)),

            // Ground
            FlashStaticBody(
              name: 'Ground',
              position: v.Vector3(0, -350, 0),
              width: 1000,
              height: 40,
              child: FlashBox(width: 1000, height: 40, color: Colors.grey[900]!),
            ),

            // Demo content based on selection
            if (selectedDemo == 0) ..._buildRopeBridge(),
            if (selectedDemo == 1) ..._buildPendulum(),
            if (selectedDemo == 2) ..._buildPiston(),
            if (selectedDemo == 3) ..._buildRagdoll(),
            if (selectedDemo == 4) ..._buildAllJoints(),

            // HUD
            _buildHUD(),
          ],
        ),
      ),
    );
  }

  // Demo 1: Rope Bridge (Distance Joints)
  List<Widget> _buildRopeBridge() {
    const segmentCount = 10;
    const segmentSize = 30.0;
    const spacing = 35.0;

    return [
      // Left anchor
      FlashStaticBody(
        name: 'LeftAnchor',
        position: v.Vector3(-200, 100, 0),
        width: 20,
        height: 20,
        child: FlashBox(width: 20, height: 20, color: Colors.brown),
      ),

      // Right anchor
      FlashStaticBody(
        name: 'RightAnchor',
        position: v.Vector3(200, 100, 0),
        width: 20,
        height: 20,
        child: FlashBox(width: 20, height: 20, color: Colors.brown),
      ),

      // Rope segments
      for (int i = 0; i < segmentCount; i++)
        FlashRigidBody.square(
          key: ValueKey('rope_segment_$i'),
          name: 'RopeSegment$i',
          position: v.Vector3(-200 + spacing * (i + 1), 100, 0),
          size: segmentSize,
          child: FlashBox(width: segmentSize, height: segmentSize, color: Colors.orange.withValues(alpha: 0.8)),
        ),

      // Heavy weight in the middle
      FlashRigidBody.circle(
        key: const ValueKey('weight'),
        name: 'Weight',
        position: v.Vector3(0, 150, 0),
        radius: 40,
        child: FlashCircle(radius: 40, color: Colors.red),
      ),
    ];
  }

  // Demo 2: Pendulum (Revolute Joint)
  List<Widget> _buildPendulum() {
    return [
      // Ceiling anchor
      FlashStaticBody(
        name: 'Ceiling',
        position: v.Vector3(0, 200, 0),
        width: 60,
        height: 20,
        child: FlashBox(width: 60, height: 20, color: Colors.grey[800]!),
      ),

      // Pendulum bob
      FlashRigidBody.circle(
        key: const ValueKey('pendulum_bob'),
        name: 'PendulumBob',
        position: v.Vector3(150, 0, 0),
        radius: 50,
        child: FlashCircle(radius: 50, color: Colors.blue),
      ),

      // Motorized wheel
      FlashRigidBody.circle(
        key: const ValueKey('motor_wheel'),
        name: 'MotorWheel',
        position: v.Vector3(-150, 100, 0),
        radius: 60,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Center(child: Icon(Icons.settings, color: Colors.white, size: 40)),
        ),
      ),

      // Motor anchor
      FlashStaticBody(
        name: 'MotorAnchor',
        position: v.Vector3(-150, 100, 0),
        width: 10,
        height: 10,
        child: FlashBox(width: 10, height: 10, color: Colors.yellow),
      ),
    ];
  }

  // Demo 3: Piston (Prismatic Joint)
  List<Widget> _buildPiston() {
    return [
      // Piston cylinder (static)
      FlashStaticBody(
        name: 'Cylinder',
        position: v.Vector3(0, 0, 0),
        width: 200,
        height: 60,
        child: Container(
          width: 200,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[700],
            border: Border.all(color: Colors.grey[400]!, width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Piston head (moves)
      FlashRigidBody.square(
        key: const ValueKey('piston_head'),
        name: 'PistonHead',
        position: v.Vector3(0, 0, 0),
        size: 50,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.orange,
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(child: Icon(Icons.arrow_forward, color: Colors.white)),
        ),
      ),

      // Elevator platform
      FlashRigidBody(
        key: const ValueKey('elevator'),
        name: 'Elevator',
        position: v.Vector3(200, 100, 0),
        width: 100,
        height: 20,
        child: Container(
          width: 100,
          height: 20,
          color: Colors.teal,
          child: const Center(
            child: Text('ELEVATOR', style: TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ),
      ),

      // Elevator rail (static)
      FlashStaticBody(
        name: 'Rail',
        position: v.Vector3(200, 0, 0),
        width: 10,
        height: 400,
        child: FlashBox(width: 10, height: 400, color: Colors.grey[600]!.withValues(alpha: 0.5)),
      ),
    ];
  }

  // Demo 4: Ragdoll (Weld Joints)
  List<Widget> _buildRagdoll() {
    return [
      // Head
      FlashRigidBody.circle(
        key: const ValueKey('head'),
        name: 'Head',
        position: v.Vector3(0, 150, 0),
        radius: 30,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.pink[200],
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: const Center(child: Text('😊', style: TextStyle(fontSize: 30))),
        ),
      ),

      // Torso
      FlashRigidBody(
        key: const ValueKey('torso'),
        name: 'Torso',
        position: v.Vector3(0, 80, 0),
        width: 50,
        height: 80,
        child: Container(
          width: 50,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.blue[300],
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Left arm
      FlashRigidBody(
        key: const ValueKey('left_arm'),
        name: 'LeftArm',
        position: v.Vector3(-50, 100, 0),
        width: 15,
        height: 60,
        child: FlashBox(width: 15, height: 60, color: Colors.pink[300]!),
      ),

      // Right arm
      FlashRigidBody(
        key: const ValueKey('right_arm'),
        name: 'RightArm',
        position: v.Vector3(50, 100, 0),
        width: 15,
        height: 60,
        child: FlashBox(width: 15, height: 60, color: Colors.pink[300]!),
      ),

      // Left leg
      FlashRigidBody(
        key: const ValueKey('left_leg'),
        name: 'LeftLeg',
        position: v.Vector3(-20, 0, 0),
        width: 20,
        height: 70,
        child: FlashBox(width: 20, height: 70, color: Colors.blue[700]!),
      ),

      // Right leg
      FlashRigidBody(
        key: const ValueKey('right_leg'),
        name: 'RightLeg',
        position: v.Vector3(20, 0, 0),
        width: 20,
        height: 70,
        child: FlashBox(width: 20, height: 70, color: Colors.blue[700]!),
      ),
    ];
  }

  // Demo 5: All Joints Combined
  List<Widget> _buildAllJoints() {
    return [
      // Distance joint example (chain)
      FlashStaticBody(
        name: 'ChainAnchor',
        position: v.Vector3(-300, 200, 0),
        width: 20,
        height: 20,
        child: FlashBox(width: 20, height: 20, color: Colors.brown),
      ),
      for (int i = 0; i < 3; i++)
        FlashRigidBody.circle(
          key: ValueKey('chain_$i'),
          name: 'Chain$i',
          position: v.Vector3(-300, 150 - i * 40, 0),
          radius: 15,
          child: FlashCircle(radius: 15, color: Colors.grey),
        ),

      // Revolute joint example (spinning wheel)
      FlashStaticBody(
        name: 'WheelAnchor',
        position: v.Vector3(-100, 100, 0),
        width: 10,
        height: 10,
        child: FlashBox(width: 10, height: 10, color: Colors.red),
      ),
      FlashRigidBody.circle(
        key: const ValueKey('wheel'),
        name: 'Wheel',
        position: v.Vector3(-100, 100, 0),
        radius: 40,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),

      // Prismatic joint example (slider)
      FlashRigidBody.square(
        key: const ValueKey('slider'),
        name: 'Slider',
        position: v.Vector3(100, 100, 0),
        size: 40,
        child: FlashBox(width: 40, height: 40, color: Colors.orange),
      ),

      // Weld joint example (connected boxes)
      FlashRigidBody.square(
        key: const ValueKey('weld1'),
        name: 'Weld1',
        position: v.Vector3(250, 100, 0),
        size: 30,
        child: FlashBox(width: 30, height: 30, color: Colors.purple),
      ),
      FlashRigidBody.square(
        key: const ValueKey('weld2'),
        name: 'Weld2',
        position: v.Vector3(290, 100, 0),
        size: 30,
        child: FlashBox(width: 30, height: 30, color: Colors.pink),
      ),
    ];
  }

  Widget _buildHUD() {
    final descriptions = [
      'Distance joints connect bodies with a spring-like constraint. Great for ropes, chains, and bridges.',
      'Revolute joints allow rotation around a point. Perfect for hinges, wheels, and pendulums. Supports motors!',
      'Prismatic joints constrain movement to a single axis. Ideal for pistons, elevators, and sliders.',
      'Weld joints rigidly connect bodies. Used for ragdolls, compound shapes, and fixed structures.',
      'All joint types working together in harmony!',
    ];

    return Positioned(
      left: 20,
      bottom: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: Colors.cyanAccent, size: 24),
                const SizedBox(width: 12),
                Text(
                  demoNames[selectedDemo].toUpperCase(),
                  style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(descriptions[selectedDemo], style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            const Divider(color: Colors.cyanAccent, height: 1),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amberAccent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Powered by Native C++ Engine with FFI.',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
