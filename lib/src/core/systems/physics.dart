import 'package:forge2d/forge2d.dart' as f2d;
export 'package:forge2d/forge2d.dart' show Contact, BodyDef, FixtureDef, BodyType, Vector2;
import '../graph/node.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Core physics constants and utilities
class FlashPhysics {
  /// Default conversion factor: 100 pixels = 1 meter
  /// Forge2D/Box2D works best with object sizes between 0.1 and 10 meters.
  static double pixelsPerMeter = 100.0;

  /// Standard downward gravity in Y-up coordinate system
  static v.Vector2 get standardGravity => v.Vector2(0, -9.81);

  /// Convert pixels to meters
  static double toMeters(double pixels) => pixels / pixelsPerMeter;

  /// Convert pixels vector to meters vector
  static v.Vector2 toMetersV(v.Vector2 pixels) => pixels / pixelsPerMeter;

  /// Convert meters to pixels
  static double toPixels(double meters) => meters * pixelsPerMeter;

  /// Convert meters vector to pixels vector
  static v.Vector2 toPixelsV(v.Vector2 meters) => meters * pixelsPerMeter;
}

class FlashPhysicsWorld extends f2d.ContactListener {
  final f2d.World world;
  v.Vector2 gravity;

  FlashPhysicsWorld({v.Vector2? gravity})
    : gravity = gravity ?? FlashPhysics.standardGravity,
      world = f2d.World((gravity ?? FlashPhysics.standardGravity)) {
    world.setContactListener(this);
  }

  void update(double dt) {
    world.stepDt(dt);
  }

  @override
  void beginContact(f2d.Contact contact) {
    _handleContact(contact, true);
  }

  @override
  void endContact(f2d.Contact contact) {
    _handleContact(contact, false);
  }

  @override
  void preSolve(f2d.Contact contact, f2d.Manifold oldManifold) {}

  @override
  void postSolve(f2d.Contact contact, f2d.ContactImpulse impulse) {}

  void _handleContact(f2d.Contact contact, bool isStart) {
    final userDataA = contact.fixtureA.body.userData;
    final userDataB = contact.fixtureB.body.userData;

    if (userDataA is FlashPhysicsBody) {
      if (isStart) {
        userDataA.onCollisionStart?.call(contact);
      } else {
        userDataA.onCollisionEnd?.call(contact);
      }
    }

    if (userDataB is FlashPhysicsBody) {
      if (isStart) {
        userDataB.onCollisionStart?.call(contact);
      } else {
        userDataB.onCollisionEnd?.call(contact);
      }
    }
  }
}

class FlashPhysicsBody extends FlashNode {
  final f2d.Body body;
  void Function(f2d.Contact)? onCollisionStart;
  void Function(f2d.Contact)? onCollisionEnd;
  void Function(f2d.Body)? onUpdate;

  FlashPhysicsBody({required this.body, super.name = 'PhysicsBody'}) {
    body.userData = this;
    _syncFromPhysics();
  }

  @override
  void update(double dt) {
    onUpdate?.call(body);
    super.update(dt);
    _syncFromPhysics();
  }

  void _syncFromPhysics() {
    final pos = body.position;
    final angle = body.angle;

    // Convert from meters back to pixels for rendering
    transform.position = v.Vector3(FlashPhysics.toPixels(pos.x), FlashPhysics.toPixels(pos.y), 0);
    transform.rotation = v.Vector3(0, 0, angle);
  }
}

/// Helper class for defining collision layers and masks
class FlashCollisionLayer {
  static const int none = 0x0000;
  static const int all = 0xFFFF;

  static const int layer1 = 0x0001;
  static const int layer2 = 0x0002;
  static const int layer3 = 0x0004;
  static const int layer4 = 0x0008;
  static const int layer5 = 0x0010;
  static const int layer6 = 0x0020;
  static const int layer7 = 0x0040;
  static const int layer8 = 0x0080;
  static const int layer9 = 0x0100;
  static const int layer10 = 0x0200;
  static const int layer11 = 0x0400;
  static const int layer12 = 0x0800;
  static const int layer13 = 0x1000;
  static const int layer14 = 0x2000;
  static const int layer15 = 0x4000;
  static const int layer16 = 0x8000;

  /// Helper to combine multiple layers into a mask
  static int maskOf(List<int> layers) {
    int mask = 0;
    for (final layer in layers) {
      mask |= layer;
    }
    return mask;
  }
}
