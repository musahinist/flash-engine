// Physics ID definitions to abstract the underlying implementation
// (Pointer or Int) from the high-level API.

import 'dart:ffi'; // For Pointer
import 'particles_ffi.dart'; // For PhysicsWorld struct

/// Represents a Handle/ID for the Physics World.
/// In the current FFI implementation, this is a Pointer to the World struct.
typedef WorldId = Pointer<PhysicsWorld>;

/// Represents a unique ID for a Physics Body.
/// The native engine returns an Int32 index/ID.
typedef BodyId = int;

/// Represents a unique ID for a Shape (fixture).
/// Currently mapped to int.
typedef ShapeId = int;

/// Represents a unique ID for a Joint.
/// The native engine returns an Int32 index/ID.
typedef JointId = int;

/// Extension to check if an ID is valid
extension PhysicsIdExt on int {
  bool get isValid => this >= 0;
}
