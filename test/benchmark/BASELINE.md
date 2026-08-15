# Frame-time baseline

Recorded before the optimisation work, so later claims can be checked rather
than asserted.

**Machine:** Apple Silicon, `flutter test` (JIT, host). Real AOT-on-mobile
numbers will be several times worse; these are for *relative* comparison
between commits, not absolute budget planning.

Reproduce:

```bash
flutter test test/benchmark/engine_benchmark.dart
```

| Scenario | avg frame | p95 | Dominant section |
|---|---|---|---|
| empty scene | 0.028 ms | 0.045 | prepareRender 0.024 |
| 1000 static nodes | 0.053 ms | 0.065 | tree 0.042 |
| 1000 moving nodes | 0.079 ms | 0.104 | tree 0.052, transforms 0.020 |
| deep hierarchy (11110 nodes, depth 4) | 0.841 ms | **1.865** | tree 0.570, prepareRender 0.152 |
| **500 rigid bodies** | **1.059 ms** | 1.204 | **physics 0.761 (72%)** |
| 100k particles | 0.281 ms | 0.489 | tree 0.275 (spawn loop) |

## What the numbers changed about the plan

**Physics is the largest measured cost by a wide margin** — 0.761 ms of a
1.059 ms frame at the 500-body target. That is exactly where the narrow-phase
trig waste lives (64 cos/sin per box pair, and the full SAT re-run inside every
position iteration). Phase 1 is correctly ordered first.

**The "tree" section at 100k particles is the spawn loop**, not the scene
walk — `FParticleEmitter.process` calling `spawn_particle` once per particle.
At the 1M demo's emission rate this is 5x larger again.

**Dart allocation churn costs less wall-clock than estimated.** `prepareRender`
is 0.087 ms for 501 bounded nodes, not the dominant term. The object count is
still high (~10 per bounded node per frame) and the concern is GC pressure
rather than inline cost — but that needs an allocation profile to demonstrate,
not a stopwatch. Phase 3 should be justified on allocation counts, and its
priority relative to Phase 2 lowered accordingly.

**Deep hierarchies have the worst p95** (1.865 ms vs 0.841 avg), which points
at `_canProcess` walking to the root and `setWorldDirty` propagating through
subtrees — both O(depth) per node.

## Gaps

- Plain `FNode` has no bounds, so the node-count scenarios never exercise
  frustum culling. Only the rigid-body scenario does (`FPhysicsBody` has
  bounds).
- Nothing here measures the paint path (`paint.sort`, `paint.nodes`,
  `paint.particles`) — those sections only run under a real `CustomPaint`.
- No allocation counts. DevTools memory profiling on the demo is the tool for
  Phase 3.


---

# Results

Measured the same way, by reverting just the file under test and re-running.

## Phase 1 — waste inside C++

| Change | Scenario | Before | After | |
|---|---|---|---|---|
| Narrow-phase box frames built once per body (64 trig/pair → 4) + position solver works from stored anchors instead of re-running SAT | 300 boxes stacking (physics section) | 0.386 ms | 0.316 ms | **−18%** |
| same | 500 mixed bodies (physics section) | 0.761 ms | 0.687 ms | **−10%** |
| Unit polygon hoisted out of the per-particle loop; 1/w carried from pass1 | particle vertex fill, 100k @ 12 sides | 1.945 ms | 0.920 ms | **−53% (2.1x)** |

### What this corrected about the plan

The arithmetic said the narrow-phase trig was "the single biggest item" — 64
cos/sin per box pair, re-run in every position iteration, ~128,000 per frame.
The measured win is 10–18%, not an order of magnitude. Trig is cheap on modern
hardware relative to everything else the solver does (memory traffic, impulse
iterations, broadphase), and the mixed scenario spends most of its time in
circle paths that never reach `detectBoxBox`.

The particle vertex fill is the opposite: an unglamorous constant hoisted out
of an inner loop, and it halved the cost of the path the 1M-particle target
depends on. At 1M this is roughly 19.5 ms → 9.2 ms per fill — still far past a
60 fps budget, but half of it.

Estimating from operation counts ranked these two the wrong way round.

### Changes that measured as nothing

Moving the broadphase pair buffer off the per-step heap and onto the world:
0.687 → 0.703 ms (500 bodies), 0.316 → 0.319 ms (300 boxes). Both inside the
noise. Two `new[]`/`delete[]` calls per frame are simply not significant next
to the solver work they sit beside.

Kept anyway — a per-frame heap allocation in a game loop is still the wrong
shape, and on a memory-constrained device it fragments — but it is not a
performance fix and is not counted as one. On the same evidence, replacing the
`std::map` warm-start cache with a flat table was **dropped**: allocation is
demonstrably not where the time goes here, so the risk is not worth it.

## Phase 2 — batching the boundary

| Change | Scenario | Before | After | |
|---|---|---|---|---|
| `emit_particles`: one call per burst, randomisation and spread rotation moved native | 100k particles (engine loop) | 0.303 ms | 0.109 ms | **−64% (2.8x)** |

The old path spent one FFI crossing and roughly four Dart allocations *per
particle*. At the 1M-particle target's emission rate that is ~500,000 crossings
and ~2,000,000 allocations a second. The new path is one crossing per burst
regardless of count, so it does not scale with particle count at all — the
measured 2.8x at 100k understates it, because the old cost grows linearly from
here and the new one does not.

Also in phase 2, unmeasured individually but each removing per-item crossings:
batch soft-body point reads (was one FFI call plus two calloc/free pairs *per
point per frame*), `getBodyPosition` reading the struct directly instead of
calling through FFI for fields already read that way, the camera matrix copied
once per frame instead of once per emitter, and particle gravity written only
when it changes.

## Cumulative, against the original baseline

| Scenario | baseline | after phases 1–2 | |
|---|---|---|---|
| empty scene | 0.028 ms | 0.023 ms | −18% |
| 1000 static nodes | 0.053 ms | 0.050 ms | −6% |
| 1000 moving nodes | 0.079 ms | 0.081 ms | noise |
| deep hierarchy | 0.841 ms (p95 1.865) | 0.724 ms (p95 **1.211**) | −14% avg, **−35% p95** |
| 500 rigid bodies | 1.059 ms | 0.973 ms | −8% |
| 300 boxes stacking | 0.448 ms | 0.367 ms | −18% |
| 100k particles | 0.281 ms | 0.109 ms | −61% |
| particle vertex fill | 1.945 ms | 0.920 ms | −53% |

The p95 improvement on deep hierarchies is the worldVersion gate: fewer
boundary reads means fewer of the spikes that were setting the tail.

## Phase 3 — Dart allocation

| Change | Scenario | Before | After | |
|---|---|---|---|---|
| Allocation-free frustum culling (in-place multiply, outcode AND, early exit) + camera matrices cached per frame | 500 rigid bodies, `prepareRender` | 0.090 ms | 0.047 ms | **−48%** |

`prepareRender` is the only section where culling runs at width, because it is
the only scenario with many bounded nodes. Culling previously allocated a
Matrix4, a List and eight Vector4s *per bounded node per frame*, and
`getViewMatrix` ran a full general 4x4 inverse at least twice a frame plus once
per FProjector, every call producing the same matrix.

Also here, not separately measured: `Paint`/`Path`/`Gradient` caching in
FCircle, FTriangle and FSphere (a `Path` is a native SkPath and was rebuilt
every frame); bounds added to FCircle, FTriangle and FSphere, which were never
being culled at all; `_canProcess` cached per frame instead of walking to the
root per node; `List.of(children)` dropped from the per-node update loop.

### A caveat on the deep-hierarchy scenario

Repeated runs of the 11,110-node hierarchy give 0.650, 0.729 and 1.067 ms. That
spread is wider than most of the changes being measured, so **that scenario
cannot support attribution** at this sample size — it is GC-dominated. An
apparent regression there after phase 3 turned out to be noise. Only the
steadier scenarios are quoted above.

### What is still unmeasured

Phase 3's case was always GC pressure rather than inline cost, and object
counts have not been measured — that needs a DevTools allocation profile
against the running demo, not a stopwatch in a headless test. The wall-clock
evidence above covers culling and the camera cache only.

---

# The paint path, and what it says about phase 4

Phase 4 proposed moving culling, Z-sorting and the MVP multiply into
`nodes.cpp`. The plan's own open question said to re-measure that payoff once
phase 3 had cleaned up the Dart side, and narrow the scope if the gap came out
smaller than expected. It did.

`FPainter` never runs in the scenarios above — they have no `CustomPaint` — so
the paint sections were blank. Driven directly against a real `Canvas`, 1000
boxes with 993 surviving culling:

| section | cost |
|---|---|
| tree | 0.035 ms |
| prepareRender (culling) | 0.068 ms |
| **paint.sort** | **0.148 ms** |
| **paint.nodes** | **0.431 ms** |

So the paint path is roughly six times culling, and it is where phase 4's case
had to be made. Decomposing `paint.nodes` over the same 993 nodes:

| part | cost | share | can it move to C++? |
|---|---|---|---|
| MVP multiply (`vp * world`) | 0.021 ms | **5.9%** | yes |
| `canvas.save/transform/restore` | 0.148 ms | 42% | **no** — dart:ui |
| `drawRect` | 0.184 ms | 52% | **no** — Skia |

**The MVP multiply is 5.9% of the pass.** The plan treated it as one of phase
4's main terms — the reason `build_render_list` had to return matrices rather
than just indices. Ninety-four percent of `paint.nodes` is `Canvas` work that
cannot cross the boundary in either direction, and the plan itself already ruled
`draw(Canvas)` out of scope.

That leaves the sort (0.148 ms) and part of culling (~0.03 ms) — about **0.18
ms of a 0.69 ms frame** — as phase 4's real payoff, against ABI 1→3, a new
translation unit, a dual-producer equivalence test, and migrating every
primitive from `renderSelf` to `drawAt`.

The sort in particular cannot be moved on its own. Passing 993 x (layer, z,
index) out and a permutation back is ~20 KB crossed for ~10,000 comparisons of
work — arithmetic intensity around 1, the exact anti-pattern this review is
built on. It only earns C++ if those keys are *already* in the native node
array, which is the full `NativeNode` expansion. The plan was right about why;
it was wrong about how much.

Cheap Dart wins the measurement did surface:

- `setFrom` + `multiply` into a scratch matrix is **38.7% cheaper** than
  `vp * world` and allocates nothing. `Matrix4 operator *` is
  `dynamic operator *(dynamic)`, so it both allocates and cannot devirtualise.

**Phase 4 is not being done as specified.** The remaining budget goes to the
1M-particle target instead — see below.

---

# The particle vertex fill, and a correction

The paragraph above originally read that `fill_vertex_buffer` was "0.920 ms at
100k particles single-threaded, so about 9.2 ms at 1M — a whole 60 fps frame".
**That extrapolation was wrong**, in two ways, and measuring it is what showed
that up.

It scaled the 12-sided shape out to 1M particles. The demo cannot reach that
combination: `native_particle_demo` caps at `isTriangleMode ? 1000000 : 500000`,
and triangle mode is a 3-vertex shape. So 1M particles only ever run at 3
vertices each, not 30. And the 0.920 ms figure was not single-threaded — 100,000
is not *below* a threshold of 100,000, so it had already taken the old parallel
path.

Measured, on 8 threads:

| shape | count | serial | parallel | bytes written | |
|---|---|---|---|---|---|
| 12-sided | 100,000 | 1.71 ms | **0.93 ms** | 34 MB | 1.8x |
| triangle | 100,000 | 0.57 ms | **0.18 ms** | 3 MB | 3.2x |
| triangle | 1,000,000 | 5.83 ms | **2.13 ms** | 34 MB | 2.7x |
| quad | 1,000,000 | 7.46 ms | **2.95 ms** | 69 MB | 2.5x |
| 12-sided | 500,000 | 8.37 ms | **4.93 ms** | 172 MB | 1.7x |

**The stated 1M target costs 2.13 ms, not 9.2 ms.** That is 13% of a 60 fps
budget, on the shape the demo actually uses at that count. The heaviest
configuration the demo can reach at all is 500k 12-sided, at 4.93 ms.

The two 34 MB rows are the useful comparison: 12-sided at 100k and triangle at
1M write the same number of bytes, but the 1M row takes 2.3x as long. So this is
not purely bandwidth-bound — per-particle work (the projection, the culling
test, the fan expansion) matters as much as the output volume. That is why more
threads help at all; it is also why they help less than linearly, and why the
36 GB/s rows are close to the ceiling.

## The thread pool

The parallel path used to construct `std::thread`s per chunk per pass per frame
— two spawn-and-join barriers every frame. Thread construction costs on the
order of the work being handed out, which is presumably why the threshold was
set at 100,000 and, at that value, effectively never engaged for a real emitter.

A persistent pool (`src/native/thread_pool.h`) parks its workers on a condition
variable, so dispatching is a lock, a counter bump and a notify. The calling
thread joins in rather than blocking. Chunks are claimed atomically and there
are 4x more of them than threads, so a chunk that is mostly culled does not
leave its thread idle.

That drops the dispatch cost to a flat ~0.03 ms, which is what lets the
threshold fall from 100,000 to **4,096** — measured, not guessed:

| particles | serial | parallel | ratio |
|---|---|---|---|
| 1,000 | 0.016 ms | 0.033 ms | 0.48 |
| 2,000 | 0.033 ms | 0.040 ms | 0.81 |
| **4,000** | 0.071 ms | 0.052 ms | **1.36** |
| 8,000 | 0.128 ms | 0.069 ms | 1.87 |
| 32,000 | 0.530 ms | 0.156 ms | 3.40 |

The crossover is near 3,000. Below it the serial path genuinely wins and the
threshold keeps it. The band from ~4k to 100k particles is where the old
threshold was leaving 2-3x on the table for every emitter in every demo.

`set_particle_parallel_threshold` is exported so both paths can be driven over
identical input — that is what the table above is, and what
`test/particle_parallel_test.dart` uses to assert the two produce byte-identical
vertex and colour buffers with visibility deliberately uneven across chunks.

---

# Spatial queries

The broadphase tree was built every frame and used for exactly one thing:
producing the collision pair list. Everything else that needed a spatial lookup
walked all bodies.

Measured by reverting `physics.cpp`, `broadphase.cpp` and `broadphase.h` and
re-running. Crowd bodies are rotated boxes, because the soft-body contact test
only does trigonometry on the box branch — a crowd of circles would not exercise
the change.

## `ray_cast`

| bodies | before | after | |
|---|---|---|---|
| 50 | 0.40 us | 0.07 us | 5.7x |
| 200 | 1.23 us | 0.04 us | 31x |
| 800 | 4.93 us | 0.04 us | 123x |
| 2,000 | 12.78 us | 0.04 us | **320x** |

The ratio is not the point; the shape of the column is. Before, cost grew
linearly with world size — every raycast ran an exact circle or oriented-box
intersection against every body in the world. After, it is flat, because a
segment prunes an AABB hierarchy at the first couple of levels and the exact
test only runs on the leaves it actually crosses.

A raycast is the query an AABB tree is best at, and the tree was already there,
maintained every frame, unused for this.

## Soft body against rigid body

| bodies | before | after | |
|---|---|---|---|
| 50 | 0.015 ms | 0.013 ms | −13% |
| 200 | 0.035 ms | 0.030 ms | −14% |
| 800 | 0.134 ms | 0.111 ms | −17% |
| 2,000 | 0.370 ms | 0.305 ms | −18% |

Smaller, and worth being clear about why: this column is a whole
`physics.update` — one soft body against N rigid bodies — and it is dominated by
the rigid solver stepping those N bodies, not by soft-body contact. The
soft-body loop itself went from O(points x all bodies) with two trig calls per
point per body, to O(points x nearby bodies) with the trig hoisted to once per
body. That is a large change to a small share of the frame.

Also removed here: an empty `if (b.type == 0 && ...) { }` block, and a run of
four identical `if (minPen == dLeft) nLocalX = -1;` statements interleaved with
the author's thinking-out-loud comments. The final assignment chain was correct;
the repetitions were debris.

Covered by `test/raycast_test.dart` (12 tests) and `test/soft_body_test.dart`
(6). The failure mode of a wrong broadphase is silent — a raycast that misses,
a soft body that sinks through geometry — so these check the nearest hit is
still nearest, that near-misses stay misses, that an axis-parallel ray still
resolves (the slab test divides by the ray direction, and a zero component is
where a naive reciprocal produces NaN), and that a crowd of distant bodies does
not change a soft body's resting position.

---

# Where the frame goes now

Same scenarios as the baseline table at the top, after all of the above.

| Scenario | baseline | now | |
|---|---|---|---|
| empty scene | 0.028 ms | 0.025 ms | |
| 1000 static nodes | 0.053 ms | 0.046 ms | −13% |
| 1000 moving nodes | 0.079 ms | 0.078 ms | noise |
| deep hierarchy | 0.841 ms (p95 1.865) | 0.704 ms (p95 1.109) | −16% avg, **−41% p95** |
| 500 rigid bodies | 1.059 ms | 0.974 ms | −8% |
| 300 boxes stacking | 0.448 ms | 0.350 ms | −22% |
| 100k particles (engine loop) | 0.281 ms | 0.105 ms | **−63%** |

And the sections the baseline could not see at all, because nothing drove the
paint path:

| section | 1000 drawables |
|---|---|
| prepareRender (culling) | 0.071 ms |
| paint.sort | 0.153 ms |
| paint.nodes | 0.417 ms |

**Physics is still the largest single cost at the engine's stated target**: 0.730
ms of a 0.974 ms frame at 500 rigid bodies, 75% of it. Phase 1 took 10% off that
and the remaining work there is structural — the solver's memory layout and its
`std::map` warm-start cache — not more arithmetic trimming. That is the honest
next place to look, not the render list.

The second is `paint.nodes` at 0.417 ms, and the decomposition above says 94% of
it is `Canvas` work that cannot move anywhere.

## Known bug found while testing

Two **dynamic** boxes do not stack: they collapse into a single layer. Circles
stack correctly, and a box rests correctly on a *static* box, so it is specific
to dynamic-box against dynamic-box contacts. Verified against unmodified
`physics.cpp` — pre-existing, not a regression from this work. Covered by a
skipped test in `test/physics_behaviour_test.dart`.
