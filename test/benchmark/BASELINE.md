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
