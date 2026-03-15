# Rendering.Context — Protocol vs Witness

<!--
---
version: 1.1.0
last_updated: 2026-03-15
status: SUPERSEDED
tier: 2
superseded_by: rendering-context-witness-migration-implications.md (Option A chosen over Option C)
---
-->

## Context

The markdown→HTML/PDF rendering pipeline uses `HTML.AnyView` type erasure that causes stack overflow in PDF rendering (see `swift-foundations/swift-pdf/Research/sigbus-stack-overflow-handoff.md`). The proposed fix — direct context rendering — has the `HTMLConverter` walk the markdown AST and emit `Rendering.Action` values instead of producing intermediate view trees.

The `Rendering.Action` enum is conceptually what a `@Witness` macro would generate from the `Rendering.Context` protocol. This raises the question: should `Rendering.Context` itself become a witness struct?

Prior research:
- `swift-institute/Research/markdown-direct-context-rendering.md` — Direct context rendering design (RECOMMENDATION)
- `swift-institute/Research/protocol-witness-effects-capability-abstraction.md` — Protocol vs witness for capability abstraction (IN_PROGRESS, preliminary recommendation: witnesses)
- `swift-institute/Research/witnesses-ecosystem-adoption-audit.md` — Ecosystem witness adoption audit (COMPLETE)

## Question

Should `Rendering.Context` be expressed as a **protocol** (current), a **witness struct**, or a **hybrid** (protocol with derived Action enum)?

## Analysis

### Option A: Protocol (current)

`Rendering.Context` is a protocol with 27 methods. Every view type carries `static func _render<C: Rendering.Context>`. The compiler specializes the entire rendering pipeline per context type (HTML vs PDF). There are 40+ locations with `C: Rendering.Context` constraints and exactly 3 concrete conformers (`HTML.Context`, `PDF.Context`, `PDF.HTML.Context`).

**Advantages**:
- Zero-cost dispatch in release (full generic specialization and inlining)
- Established pattern — zero migration cost
- `Property.View` push/pop accessors work through protocol constraints

**Disadvantages**:
- No `Rendering.Action` enum — must be hand-derived separately
- Generic `C` parameter on 40+ view types adds API complexity
- Testing requires mock conformer

### Option B: Witness struct

`Rendering.Context` becomes a `~Copyable` struct with 27 stored closure properties. Concrete implementations become factory methods (`.html(...)`, `.pdf(...)`, `.pdfHTML(...)`). The `Rendering.Action` enum falls out naturally as the reified operation set.

**Advantages**:
- Action enum derivation is natural (each closure → enum case)
- No generic `C` parameter — all `_render` methods take concrete `Rendering.Context`
- Value composition: swap individual closures for testing or customization
- Trivial test doubles (override individual closures)

**Disadvantages**:
- Migration cost: 40+ `_render<C>` locations + 3 conformers → 3 factory methods
- `Property.View` extensions need redesign (currently constrained to protocol)
- Layer 1 constraint: no `@Witness` macro (Layer 3), must hand-write

### Option C: Hybrid — protocol with derived Action enum

Keep the protocol for dispatch. Add a hand-derived `Rendering.Action` enum that mirrors the protocol methods. The `HTMLConverter` produces `[Rendering.Action]` per element; the converter interprets them against the protocol-based context.

**Advantages**:
- Zero migration of existing `_render<C>` code
- Protocol dispatch performance preserved
- Action enum provides deferred rendering for markdown pipeline
- `Property.View` accessors unchanged

**Disadvantages**:
- Two abstractions (protocol + enum) representing the same operations
- Action enum must be kept in sync with protocol manually
- Action interpretation adds switch dispatch + array allocation overhead

### Empirical Results

Experiment: `swift-institute/Experiments/rendering-context-protocol-vs-witness/`

Toolchain: Swift 6.2.4 (swiftlang-6.2.4.1.4), macOS 26.0, arm64, Apple M1 Max (8-core).

All five variants produce identical byte output (validated by assertion).

#### Debug Build

| Variant | 10 el. | 100 el. | 1000 el. | 10000 el. | Trend |
|---------|--------|---------|----------|-----------|-------|
| V1 Protocol (baseline) | 7.41 µs | 71.75 µs | 679.00 µs | 6.859 ms | 1.00x |
| V2 Witness (closures) | 8.00 µs (1.07x) | 69.58 µs (0.96x) | 680.58 µs (1.00x) | 6.989 ms (1.01x) | **~1.00x** |
| V3 Action Batch | 13.95 µs (1.88x) | 126.04 µs (1.75x) | 1.258 ms (1.85x) | 12.272 ms (1.78x) | **~1.8x** |
| V4 Action Reuse | 16.62 µs (2.24x) | 155.08 µs (2.16x) | 1.515 ms (2.23x) | 14.780 ms (2.15x) | **~2.2x** |
| V5 AnyView (existential) | 9.54 µs (1.28x) | 78.29 µs (1.09x) | 765.79 µs (1.12x) | 7.494 ms (1.09x) | **~1.1x** |

#### Release Build

| Variant | 10 el. | 100 el. | 1000 el. | 10000 el. | Trend |
|---------|--------|---------|----------|-----------|-------|
| V1 Protocol (baseline) | 2.00 µs | 12.58 µs | 128.95 µs | 1.327 ms | 1.00x |
| V2 Witness (closures) | 1.83 µs (0.91x) | 13.16 µs (1.04x) | 129.20 µs (1.00x) | 1.322 ms (0.99x) | **~1.00x** |
| V3 Action Batch | 1.79 µs (0.89x) | 15.41 µs (1.22x) | 157.37 µs (1.22x) | 1.599 ms (1.20x) | **~1.2x** |
| V4 Action Reuse | 1.95 µs (0.97x) | 16.95 µs (1.34x) | 175.83 µs (1.36x) | 1.763 ms (1.32x) | **~1.3x** |
| V5 AnyView (existential) | 1.83 µs (0.91x) | 13.58 µs (1.07x) | 134.33 µs (1.04x) | 1.378 ms (1.03x) | **~1.0x** |

#### Analysis of Results

**V2 Witness ≈ V1 Protocol** (0.99–1.04x release, 0.96–1.07x debug): The closure-based witness has effectively zero overhead compared to protocol dispatch. This refutes the hypothesis that closure indirection would be measurably slower. The optimizer handles closure calls nearly as well as devirtualized protocol method calls in this workload.

**V5 AnyView has minimal dispatch overhead** (1.03–1.07x release): Existential dispatch itself is cheap. The real problem with the current AnyView path is not per-element dispatch cost but **recursive stack depth** — deeply nested view trees overflow the 64KB async task stack. This experiment cannot capture that structural problem since it measures flat iteration, not recursive nesting.

**V3/V4 Action overhead is moderate** (1.20–1.36x release): The overhead comes from enum allocation (heap for associated values) and switch dispatch. V4 is slower than V3 because `interpretActions` is called N times (once per element) vs once (for the whole batch). Each `@inline(never)` function call adds overhead. In production, the interpreter would likely be inlined, reducing V4's overhead.

**Debug-release gap**: V1 achieves 5.2x speedup from optimization at 10000 elements (6.859ms → 1.327ms). V2 achieves an identical 5.3x speedup (6.989ms → 1.322ms), confirming the optimizer handles closures as well as protocol dispatch. V3/V4 see 7–8x speedup, showing the optimizer's switch-dispatch and allocation optimizations are effective.

### Comparison

| Criterion | A: Protocol | B: Witness | C: Hybrid |
|-----------|-------------|------------|-----------|
| Release performance | 1.00x | 1.00x | 1.20–1.36x |
| Debug performance | 1.00x | 1.00x | 1.8–2.2x |
| Migration cost | None | 40+ locations | Action enum only |
| Action enum | Hand-derived separately | Natural derivation | Hand-derived |
| Generic complexity | `C: Rendering.Context` on 40+ types | None | Unchanged |
| Property.View compat | Full | Redesign needed | Full |
| Testability | Mock conformer | Override closures | Mock conformer |
| Stack overflow fix | Doesn't address | Doesn't address directly | Addresses via Action |
| Dual-abstraction risk | None | None | Protocol + enum sync |

### Key Insight

The experiment reveals that the performance question is settled: **witness closure dispatch costs nothing measurable** relative to protocol dispatch. The decision is therefore purely architectural.

The stack overflow problem requires eliminating recursive view tree construction. This is solved by the Action enum regardless of whether the context is a protocol or witness. Neither Option A nor Option B directly solves the stack overflow — they affect how the context is CONSUMED, not how rendering operations are PRODUCED.

The critical change is in the *producer* (HTMLConverter emitting actions instead of constructing view trees), not the *consumer* (protocol vs witness for interpreting those actions).

## Outcome

**Status**: DECISION

**Decision**: **Option C — Hybrid (protocol + derived Action enum)**.

**Rationale**:

1. **Performance is not a differentiator.** V2 (witness) performs identically to V1 (protocol). The choice between protocol and witness has zero performance implications. Removing performance from the equation, the decision is purely about architecture and migration cost.

2. **Migration cost is disproportionate for Option B.** Converting 40+ `_render<C>` locations and redesigning Property.View extensions is substantial work with no performance benefit. The 3 concrete conformers work correctly.

3. **The Action enum solves the actual problem.** The stack overflow is caused by recursive view tree construction, not by the context dispatch mechanism. The Action enum enables flat, iterative rendering regardless of whether the context is a protocol or witness. Adding the enum to the existing protocol architecture is the minimal change that addresses the problem.

4. **Option B remains a valid future path.** The empirical evidence that V2 ≈ V1 means a future migration to witness-based context would have no performance cost. If the protocol accumulates enough friction (more conformers, more test mocking needs, more generic complexity), the witness approach is proven viable.

**Implementation path**:
1. Add `Rendering.Action` enum to `swift-rendering-primitives` mirroring the protocol's 27 methods
2. Add `interpretActions<C: Rendering.Context>` function
3. Modify `HTMLConverter` in `swift-markdown-html-rendering` to emit `[Rendering.Action]` per AST node instead of constructing view trees
4. The converter interprets actions against the concrete context after each element

**Deferred**: Full witness migration (Option B). Revisit if:
- More than 5 concrete conformers emerge
- Property.View extensions become a maintenance burden
- `@Witness` macro evolves to Layer 1 viability (unlikely — depends on swift-syntax)

## References

- Experiment: `swift-institute/Experiments/rendering-context-protocol-vs-witness/`
- Prior research: `swift-institute/Research/markdown-direct-context-rendering.md`
- Stack overflow: `swift-foundations/swift-pdf/Research/sigbus-stack-overflow-handoff.md`
- Witness adoption: `swift-institute/Research/witnesses-ecosystem-adoption-audit.md`
- Witness effects: `swift-institute/Research/protocol-witness-effects-capability-abstraction.md`
