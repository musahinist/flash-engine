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

## Known bug found while testing

Two **dynamic** boxes do not stack: they collapse into a single layer. Circles
stack correctly, and a box rests correctly on a *static* box, so it is specific
to dynamic-box against dynamic-box contacts. Verified against unmodified
`physics.cpp` — pre-existing, not a regression from this work. Covered by a
skipped test in `test/physics_behaviour_test.dart`.
