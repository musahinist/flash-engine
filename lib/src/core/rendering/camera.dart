import 'dart:math';
import 'dart:ui' show Rect;

import 'package:vector_math/vector_math_64.dart';
import '../graph/node.dart';

/// How a camera tracks its [FCameraNode.followTarget].
enum CameraFollowMode {
  /// Ignore the target.
  none,

  /// Snap to the target every frame.
  instant,

  /// Ease toward the target.
  smooth,

  /// Only move once the target leaves a rectangle around the camera.
  deadZone,
}

class FCameraNode extends FNode {
  double fov = 60.0;
  double near = 0.1;
  double far = 2000.0;
  bool isOrthographic = false;
  double orthographicSize = 400.0; // Half-height in ortho mode

  // --- Follow behaviour ---
  //
  // These used to live on a separate, non-node FGridCamera that maintained its
  // own position/zoom/rotation scalars and produced its own Matrix4 in a
  // Y-down space. Two cameras meant two competing sources of truth for the
  // same viewpoint; following is a behaviour on a transform, not a projection
  // concern, so it belongs here and works for perspective cameras too.

  /// Node to track. Following is skipped while this is null.
  FNode? followTarget;

  /// Offset from the target, in world units.
  Vector3 followOffset = Vector3.zero();

  CameraFollowMode followMode = CameraFollowMode.smooth;

  /// Smoothing time constant in **seconds** — roughly how long the camera
  /// takes to cover most of the distance to its target.
  ///
  /// The old implementation applied `position += delta * lerpSpeed` with no
  /// dt, so behaviour changed with frame rate, and CubeRunner passed 5.0,
  /// overshooting the target five times over every frame.
  double followSmoothing = 0.15;

  /// Rectangle around the camera the target may move inside without pulling
  /// it. Interpreted on the XZ plane, in world units.
  Rect? deadZone;

  /// Clamps the camera position on the XZ plane. Null means unbounded.
  Aabb2? worldBounds;

  // --- Screen shake ---
  final Vector3 _shakeOffset = Vector3.zero();
  double _shakeRemaining = 0;
  double _shakeDuration = 0;
  double _shakeMagnitude = 0;
  late Random _shakeRandom;

  FCameraNode({super.name = 'Camera', int? shakeSeed}) {
    _shakeRandom = Random(shakeSeed);
    // Default position back
    transform.position.setValues(0, 0, 1000);
  }

  /// Starts a screen shake.
  ///
  /// Shake is applied when building the view matrix rather than written into
  /// the transform, so it cannot fight the follow logic or leak into the
  /// native transform sync.
  void shake({required double magnitude, double duration = 0.3}) {
    _shakeMagnitude = magnitude;
    _shakeDuration = duration;
    _shakeRemaining = duration;
  }

  /// Whether a shake is currently playing.
  bool get isShaking => _shakeRemaining > 0;

  @override
  void process(double dt) {
    _updateFollow(dt);
    _updateShake(dt);
  }

  void _updateFollow(double dt) {
    final target = followTarget;
    if (target == null || followMode == CameraFollowMode.none) return;

    final desired = target.worldPosition + followOffset;
    final current = transform.position;

    // All three axes move, so [followOffset] fully describes where the camera
    // sits relative to its target. That is what makes the same follow code
    // work for a top-down camera (offset straight up) and an isometric one
    // (offset along the view direction).
    switch (followMode) {
      case CameraFollowMode.none:
        return;

      case CameraFollowMode.instant:
        current.setFrom(desired);

      case CameraFollowMode.smooth:
        // Frame-rate independent exponential smoothing: the fraction covered
        // depends on elapsed time, not on how many frames elapsed.
        final t = followSmoothing <= 0 ? 1.0 : 1 - exp(-dt / followSmoothing);
        current.x += (desired.x - current.x) * t;
        current.y += (desired.y - current.y) * t;
        current.z += (desired.z - current.z) * t;

      case CameraFollowMode.deadZone:
        // Dead zone applies on the XZ ground plane, which is where grid games
        // measure it.
        final zone = deadZone;
        if (zone == null) break;
        final halfW = zone.width / 2;
        final halfH = zone.height / 2;
        if (desired.x < current.x - halfW) {
          current.x = desired.x + halfW;
        } else if (desired.x > current.x + halfW) {
          current.x = desired.x - halfW;
        }
        if (desired.z < current.z - halfH) {
          current.z = desired.z + halfH;
        } else if (desired.z > current.z + halfH) {
          current.z = desired.z - halfH;
        }
    }

    final bounds = worldBounds;
    if (bounds != null) {
      current.x = current.x.clamp(bounds.min.x, bounds.max.x);
      current.z = current.z.clamp(bounds.min.y, bounds.max.y);
    }

    // The vectors were mutated in place, which bypasses the setter.
    transform.syncExternalMutations();
  }

  void _updateShake(double dt) {
    if (_shakeRemaining <= 0) {
      if (_shakeOffset.length2 != 0) _shakeOffset.setZero();
      return;
    }

    _shakeRemaining -= dt;
    if (_shakeRemaining <= 0) {
      _shakeRemaining = 0;
      _shakeOffset.setZero();
      return;
    }

    // Real randomness, damped over the shake's lifetime. The old version
    // derived "randomness" from `_shakeDuration.hashCode % 1000`, which is
    // neither random nor stable.
    final damping = _shakeDuration <= 0 ? 0.0 : _shakeRemaining / _shakeDuration;
    final amplitude = _shakeMagnitude * damping;
    _shakeOffset.setValues(
      (_shakeRandom.nextDouble() * 2 - 1) * amplitude,
      (_shakeRandom.nextDouble() * 2 - 1) * amplitude,
      0,
    );
  }

  Matrix4 getProjectionMatrix(double width, double height) {
    if (width <= 0 || height <= 0) return Matrix4.identity();
    final aspect = width / height;

    if (isOrthographic) {
      final halfH = orthographicSize;
      final halfW = halfH * aspect;
      return makeOrthographicMatrix(-halfW, halfW, -halfH, halfH, near, far);
    }

    return makePerspectiveMatrix(radians(fov), aspect, near, far);
  }

  Matrix4 getViewMatrix() {
    // The view matrix is the inverse of the camera's world matrix.
    final matrix = Matrix4.copy(worldMatrix);
    if (_shakeOffset.length2 != 0) {
      matrix.setTranslation(matrix.getTranslation() + _shakeOffset);
    }
    matrix.invert();
    return matrix;
  }

  /// Calculates the visible world size at a given distance from the camera
  /// Returns half-width and half-height as a Vector2
  Vector2 getWorldBounds(double distance, Vector2 viewportSize) {
    if (viewportSize.x <= 0 || viewportSize.y <= 0) return Vector2.zero();

    if (isOrthographic) {
      final aspect = viewportSize.x / viewportSize.y;
      return Vector2(orthographicSize * aspect, orthographicSize);
    }

    final aspect = viewportSize.x / viewportSize.y;
    final halfHeight = distance * tan(radians(fov / 2));
    final halfWidth = halfHeight * aspect;

    return Vector2(halfWidth, halfHeight);
  }

  /// An orthographic camera looking straight down at the XZ plane.
  ///
  /// This is the setup grid games want: cells lie on XZ, `+Y` is height, and
  /// [orthographicSize] plays the role the old FGridCamera called `zoom`.
  factory FCameraNode.topDown({String name = 'Camera', double orthographicSize = 400, double height = 1000}) {
    final camera = FCameraNode(name: name);
    camera.isOrthographic = true;
    camera.orthographicSize = orthographicSize;
    camera.transform.position.setValues(0, height, 0);
    camera.transform.rotation.setValues(-pi / 2, 0, 0);
    camera.followOffset = Vector3(0, height, 0);
    camera.transform.syncExternalMutations();
    return camera;
  }

  /// A true isometric camera: orthographic, yawed 45° and pitched by
  /// `atan(1/sqrt(2))` ≈ 35.264°.
  ///
  /// Isometric is a camera pose, not a separate projection type. That matrix
  /// was previously hand-written in four different places (two games, the
  /// isometric cube widget, and FIsometricGrid).
  factory FCameraNode.isometric({String name = 'Camera', double orthographicSize = 400, double distance = 1000}) {
    final camera = FCameraNode(name: name);
    camera.isOrthographic = true;
    camera.orthographicSize = orthographicSize;
    camera.transform.rotation.setValues(-atan(1 / sqrt2), -pi / 4, 0);
    // Step back along the camera's own forward axis so the target ends up
    // centred in view.
    final offset = camera.transform.matrix.getRotation() * Vector3(0, 0, distance);
    camera.transform.position.setFrom(offset);
    camera.followOffset = offset.clone();
    camera.transform.syncExternalMutations();
    return camera;
  }

  /// Full world -> screen-pixel matrix: viewport · projection · view.
  ///
  /// This is exactly what [FPainter] builds, exposed so canvas painters and
  /// widget positioning share one projection path instead of each rolling
  /// their own.
  Matrix4 getScreenMatrix(Vector2 viewportSize) {
    final viewport = Matrix4.identity()
      ..setTranslationRaw(viewportSize.x / 2, viewportSize.y / 2, 0.0)
      ..scaleByVector3(Vector3(viewportSize.x / 2, -viewportSize.y / 2, 1.0));
    return viewport * getProjectionMatrix(viewportSize.x, viewportSize.y) * getViewMatrix();
  }

  /// Projects a world point to screen pixels through [getScreenMatrix].
  Vector2 worldToScreen(Vector3 world, Vector2 viewportSize) {
    final m = getScreenMatrix(viewportSize);
    final p = m * Vector4(world.x, world.y, world.z, 1.0);
    if (p.w == 0) return Vector2.zero();
    return Vector2(p.x / p.w, p.y / p.w);
  }

  /// The axis-aligned world rectangle this camera can see on the XZ plane.
  ///
  /// Used by tilemaps to decide which cells to draw; a batch renderer needs
  /// this to avoid walking an infinite grid.
  Rect getVisibleWorldRect(Vector2 viewportSize) {
    final pos = worldPosition;
    final half = getWorldBounds((pos.z).abs(), viewportSize);
    return Rect.fromLTRB(pos.x - half.x, pos.y - half.y, pos.x + half.x, pos.y + half.y);
  }
}
