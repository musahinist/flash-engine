import 'dart:ffi';
import 'dart:io';

/// Joint types matching C++ enum
class JointType {
  static const int distance = 0;
  static const int revolute = 1;
  static const int prismatic = 2;
  static const int weld = 3;
}

/// Joint definition struct for creating joints
final class JointDef extends Struct {
  @Int32()
  external int type;
  @Uint32()
  external int bodyA;
  @Uint32()
  external int bodyB;

  // Anchor points (local coordinates)
  @Float()
  external double anchorAx;
  @Float()
  external double anchorAy;
  @Float()
  external double anchorBx;
  @Float()
  external double anchorBy;

  // Distance joint parameters
  @Float()
  external double length;
  @Float()
  external double frequency;
  @Float()
  external double dampingRatio;

  // Revolute joint parameters
  @Float()
  external double referenceAngle;
  @Int32()
  external int enableLimit;
  @Float()
  external double lowerAngle;
  @Float()
  external double upperAngle;
  @Int32()
  external int enableMotor;
  @Float()
  external double motorSpeed;
  @Float()
  external double maxMotorTorque;

  // Prismatic joint parameters
  @Float()
  external double axisx;
  @Float()
  external double axisy;
  @Float()
  external double lowerTranslation;
  @Float()
  external double upperTranslation;
  @Float()
  external double maxMotorForce;

  // Weld joint parameters
  @Float()
  external double stiffness;
  @Float()
  external double damping;
}

/// Opaque joint handle
final class Joint extends Opaque {}

/// FFI function typedefs
typedef CreateJointNative = Int32 Function(Pointer<NativeType>, Pointer<JointDef>);
typedef CreateJointDart = int Function(Pointer<NativeType>, Pointer<JointDef>);

typedef DestroyJointNative = Void Function(Pointer<NativeType>, Int32);
typedef DestroyJointDart = void Function(Pointer<NativeType>, int);

/// Joints FFI wrapper
class PhysicsJointsFFI {
  final DynamicLibrary _lib;

  late final CreateJointDart createJoint;
  late final DestroyJointDart destroyJoint;

  PhysicsJointsFFI(this._lib) {
    createJoint = _lib.lookupFunction<CreateJointNative, CreateJointDart>('create_joint');
    destroyJoint = _lib.lookupFunction<DestroyJointNative, DestroyJointDart>('destroy_joint');
  }

  /// Load the native library
  static DynamicLibrary loadLibrary() {
    if (Platform.isIOS) {
      return DynamicLibrary.open('/Users/mshn/Documents/flash/lib/src/core/native/bin/libflash_core_sim.dylib');
    }

    String libPath;
    if (Platform.isMacOS) {
      libPath = '/Users/mshn/Documents/flash/lib/src/core/native/bin/libflash_core.dylib';
    } else if (Platform.isLinux || Platform.isAndroid) {
      libPath = '/Users/mshn/Documents/flash/lib/src/core/native/bin/libflash_core.so';
    } else if (Platform.isWindows) {
      libPath = r'C:\Users\mshn\Documents\flash\lib\src\core\native\bin\libflash_core.dll';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
    return DynamicLibrary.open(libPath);
  }
}
