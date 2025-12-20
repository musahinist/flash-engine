import 'package:forge2d/forge2d.dart' as f2d;
export 'package:forge2d/forge2d.dart' show Contact, BodyDef, FixtureDef, BodyType, Vector2;
import '../graph/node.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class FlashPhysicsWorld extends f2d.ContactListener {
  final f2d.World world;
  double gravity;

  FlashPhysicsWorld({this.gravity = 9.81}) : world = f2d.World(v.Vector2(0, gravity)) {
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

    transform.position = v.Vector3(pos.x, pos.y, 0);
    transform.rotation = v.Vector3(0, 0, angle);
  }
}
