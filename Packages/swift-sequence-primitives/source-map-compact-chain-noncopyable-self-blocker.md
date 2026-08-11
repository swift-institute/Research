# `source.map.compact { }` Chain on `~Copyable & ~Escapable` Self — Language-Level Blocker

<!--
---
version: 1.0.0
last_updated: 2026-05-21
status: DEFERRED
tier: 2
scope: package
---
-->

## Context

The Sequence.Map refactor (see `Sources/Sequence Map/`) ships:

- `source.map { transform }` — direct consuming method on `Sequence.Protocol where Self: ~Copyable & ~Escapable, Element: Copyable` — WORKS for `let source: NCSource`. Defers to `Sequence.Map.eager(consume self, transform)`.
- `source.compactMap { transform }` and `source.flatMap { transform }` — same direct-consuming-method shape on `Sequence.Protocol`. WORKS for `let source: NCSource`.
- `source.map { transform }`, `source.map.compact { transform }`, `source.map.flat { transform }` — fluent chain via `var map: Sequence.Map<Self> { consuming get { Sequence.Map(_base: self) } }` on `Sequence.Protocol where Self: Copyable`. WORKS for `let source: ArraySource` (Copyable).
- `source.map.compact { transform }` / `source.map.flat { transform }` — same fluent chain, NOT shipped for `Sequence.Protocol where Self: ~Copyable & ~Escapable`. BLOCKED.

This research records why the asymmetric surface — Copyable Self gets the fluent chain; `~Copyable & ~Escapable` Self gets the direct consuming method only — is the canonical answer in current Swift (6.3.2 stable / 6.4-dev / 6.5-dev internal), not a deficiency to be removed in a subsequent ship.

## Question

Is there an implementable path in Swift 6.3.2, 6.4-dev (latest nightly 2026-05-12-a), or 6.5-dev (internal) for `source.map.compact { closure }` (and `.flat`, `.eager`-via-`callAsFunction`) at a **direct user call site** when `Self: ~Copyable & ~Escapable` and `source` is a `let`-bound local binding?

## Analysis

### Option A — `consuming get` on protocol extension (the failing direction)

```swift
extension Sequence.`Protocol` where Self: ~Copyable & ~Escapable {
    public var map: Sequence.Map<Self> {
        consuming get { Sequence.Map(_base: self) }
    }
}
```

Direct call site:
```swift
let source = NCSource([1, 2, 3])
let m = source.map  // FAILS
```

**Verdict**: REFUTED.

Empirical evidence in `swift-primitives/swift-parser-primitives/Experiments/owned-consuming-get-on-protocol-extension/EXPERIMENT.md` §"Toolchain results matrix" (rows V5a/V5b/V5c): direct call site fails on Swift 6.4-dev nightlies `2026-05-07-a` AND `2026-05-12-a` with `error: noncopyable 'c' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type`. V5d (`consume c` keyword variant) additionally CRASHES the SIL verifier at `MemoryLifetimeVerifier.cpp:263`. Swift 6.3.1/6.3.2 reject `@_owned` entirely as an unknown attribute (`include/swift/Basic/Features.def:611` — `UnderscoreOwned` is gated).

The blocker is in the move-checker, not Sema or SILGen, and is documented as a principled compiler design constraint in `swift-institute/Research/2026-05-18-consuming-get-protocol-extension-noncopyable-limitation.md` §"Diagnostic emission site" (`swiftlang/swift/include/swift/AST/DiagnosticsSIL.def:886`, `sil_movechecking_capture_consumed`). Compiler test fixture `swiftlang/swift/test/SILGen/resilient_consuming_getter_nonescapable_test.swift` explicitly validates the rejection — *not* a coverage gap, *not* a bug, *not* in-flight.

The parent investigation hit three failure modes at this shape:
1. `'self' is borrowed and cannot be consumed` — emitted on `consuming get` direct-call-site bodies.
2. `cannot infer the lifetime dependence scope on a method with a ~Escapable parameter` — emitted when trying to mix `@_lifetime` annotations to dodge (1).
3. `copy of noncopyable typed value. This is a compiler bug.` — emitted as a separate SILGen edge case for generic `~Copyable` enum patterns; the Apr-2026 SILGen wave (PRs `2637592bee3`, `4640b58e990`, `645e2dc3bad`) addressed the SILGen layer of (3) but did not relax (1).

All three modes funnel back to the move-checker's principled rejection.

### Option B — `_read` yielding ~Escapable Builder that borrows self (Reframing A)

```swift
extension Sequence.`Protocol` where Self: ~Copyable & ~Escapable {
    public var map: Sequence.Map.Borrowed<Self> {
        @_lifetime(borrow self)
        _read { yield Sequence.Map.Borrowed(borrowing: self) }
    }
}
```

This is the `Property.Borrow` shape canonical in `swift-property-primitives`, formalized in the `property-primitives` skill at `[PRP-009]`. The accessor is a borrow, not a consume, so the `sil_movechecking_capture_consumed` diagnostic does not fire. The chain compiles in principle.

**Verdict**: REJECTED for L1 production.

Two structural blockers, both load-bearing:

1. **Doesn't cover the case the package asks about.** The chain only iterates terminally if the borrowed-base wrapper can produce an `Iterator`. Sequence.Protocol's `consuming func makeIterator()` requires moving base; a borrow cannot. The two viable downstream iteration paths are:

   - Dual-conform base to `Sequence.Borrowing.Protocol` (declared in `Sources/Sequence Borrowing/Sequence.Borrowing.Protocol.swift:43`) and iterate via `@_lifetime(borrow self) borrowing func makeIterator()`. This requires base to provide contiguous-span storage with non-destructive iteration semantics. **Generator-style iterators, one-shot file-descriptor yielders, resource pools that mutate irreversible state on each step CANNOT conform** — `borrowing makeIterator()` is structurally impossible for them. These ARE the production `~Copyable & Sequence.Protocol`-only sources the chain is meant to support (the case `Element: ~Copyable` exists for).

   - `UnsafePointer.move()` at terminal iteration to forcibly extract base from the borrow. This leaves the source binding's storage in a moved-out state; deinit at scope-end would double-fault. UNSAFE in the formal Swift-ownership sense — violates the borrow-checker's invariants by escape hatch.

   Reframing A solves "chain over Sequence.Borrowing.Protocol dual-conformers," not "chain over `~Copyable & Sequence.Protocol`-only Self." The latter is exactly the case for which the asymmetric direct-method shape exists.

2. **Pointer-storage pattern carries a known release-mode miscompile load-bearing for L1.** The pattern's core is `withUnsafePointer(to: base) { unsafe $0 }` returning a typed pointer to be stored in the wrapper. Quoting `swift-property-primitives/Sources/Property Inout Primitives/Property.Inout.swift:90-101` verbatim:

   > "Do NOT add `@inlinable` to this init. The same Swift 6.3.1 / 6.4-dev release-mode miscompile […] when inlined across a module boundary, `withUnsafePointer(to: base) { $0 }` begins returning a callee-frame spill slot that dies when the closure returns."

   Detailed at `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md`. The mitigation is to drop `@inlinable` on the init, which forfeits cross-module specialization on a foundational accessor. swift-sequence-primitives is L1; every higher-layer package (swift-collection-primitives, swift-buffer-primitives, swift-async-primitives, swift-foundations consumers) imports it. A pattern that miscompiles in release mode across module boundaries on a hot L1 accessor — and whose mitigation forfeits inlining — is not safely shippable at this layer.

### Option C — `mutating _read` Property.View on `var source` (Reframing B)

```swift
extension Sequence.`Protocol` where Self: ~Copyable & ~Escapable {
    public var map: Sequence.Map.Mutating<Self> {
        @_lifetime(&self)
        mutating _read { yield Sequence.Map.Mutating(&self) }
    }
}
```

This is the `Property.View` / `Property.Inout` shape from `swift-property-primitives`'s `[PRP-008]`. The accessor mutating-borrows self; `&self` is the lifetime root. The chain compiles in principle but requires the caller to declare `var source`, not `let source`.

**Verdict**: REJECTED for L1 production.

Inherits blockers (1) and (2) above (iteration model + pointer-storage miscompile risk) AND adds:

3. **`var source` is a call-site cost imposed on every consumer.** Every downstream package that wants to consume the chain must rewrite `let source: NCSource = ...` to `var source: NCSource = ...`. The direct-consuming-method form (`source.compactMap { transform }`) works on `let source` because it's a method invocation, not a property access; method invocations on `let`-bound `~Copyable` Self consume cleanly. Imposing a `var` requirement to enable a stylistic property-chain when the direct method already works is a non-starter for an L1 surface.

### Option D — direct consuming method on `Sequence.Protocol` (the canonical ship-state)

```swift
extension Sequence.`Protocol` where Self: ~Copyable & ~Escapable, Element: Copyable {
    @_lifetime(copy self) @inlinable
    public consuming func compactMap<Output>(
        _ transform: @escaping (Element) -> Output?
    ) -> Sequence.Map<Self>.Compact<Output> {
        Sequence.Map<Self>.compact(consume self, transform)
    }
}
```

Call site: `let source = NCSource([1, 2, 3]); for elem in source.compactMap({ Int($0) }) { … }` — works on `let source`.

**Verdict**: CANONICAL.

This shape IS the consuming-parameter-wrapper success pattern that parser-primitives' EXPERIMENT.md §"V1-V4 on Swift 6.4-dev with consuming-parameter wrappers — PASS" identified as the only working envelope for `~Copyable & ~Escapable` Self with `@_owned`-style consume semantics. Quoting EXPERIMENT.md line 195 verbatim:

> "all five variants … compile cleanly … The protocol-extension `@_owned consuming get` works only when the reader is a consuming-parameter function, not when invoked at the binding site."

`compactMap(_:)` IS the consuming-parameter function. The Sequence.Map static implementations at `Sources/Sequence Map/Sequence.Map+map.swift` (`.eager`, `.compact`, `.flat`) are themselves consuming-parameter wrappers in the same sense. The asymmetric ship-state is not a fallback or a workaround — it is the precise envelope of what is safely expressible in current Swift for the `~Copyable & ~Escapable` Sequence.Protocol case.

### Comparison

| Option | Direct-call-site chain `source.map.compact { }` | Works on `let source` | Iteration coverage | L1 release-mode safety |
|---|---|---|---|---|
| A — `consuming get` on protocol ext | yes (intent) | no — `sil_movechecking_capture_consumed` | n/a | n/a |
| B — `_read` ~Escapable Builder borrowing | yes (compiles) | yes | only Sequence.Borrowing.Protocol dual-conformers OR unsafe `pointer.move()` | NO — withUnsafePointer-to-borrow release-mode miscompile across modules |
| C — `mutating _read` Property.View | yes (compiles) | NO — requires `var source` | same as B | same as B |
| **D — direct consuming method (ship-state)** | **no — but `source.compactMap { }` shape works** | **yes** | **full Sequence.Protocol via `consume self → consume base`** | **YES** |

## Outcome

**Status**: DEFERRED.

### Decision

Ship the asymmetric surface as the canonical answer:

| Self constraint | Fluent chain shape | Direct method shape |
|---|---|---|
| `Self: Copyable` | `var map: Sequence.Map<Self> { consuming get { … } }` — works on `let source` via implicit copy | `compactMap` / `flatMap` — works on `let source` |
| `Self: ~Copyable & ~Escapable` | **NOT SHIPPED** — language-level blocker, no viable Reframing | `compactMap` / `flatMap` — works on `let source` via consuming-parameter wrapper [canonical envelope] |

The asymmetric shape reflects the principled move-checker constraint, not an ecosystem deficiency. Removing the asymmetry requires Swift compiler progress on `sil_movechecking_capture_consumed`-class diagnostics for direct-call-site reads of consuming-get property accessors on `~Copyable & ~Escapable` Self — currently a principled design, not in-flight.

### Revisit trigger

This research moves from `DEFERRED` to `IN_PROGRESS` when ANY of the following lands:

1. A Swift Evolution proposal accepts a relaxation of the move-checker constraint for `consuming get` direct-call-site reads on `~Copyable` Self (e.g., a "borrow-then-consume" property accessor mode, an extension to `@_owned`'s `UnderscoreOwned` semantics that admits direct call sites, or equivalent).
2. A Swift nightly compiles the V1 scaffold (`let source = NCSource([1,2,3]); _ = source.v1_map`) at `swift-institute/Experiments/sequence-map-fluent-chain-noncopyable-1/Sources/sequence-map-fluent-chain-noncopyable-1/V1_ConsumingGetBaseline.swift` (line uncomment required per inline comment) without the `sil_movechecking_capture_consumed` diagnostic.
3. Independent: a release-mode-safe shape for the Reframing-A pointer-storage pattern lands at L1 in the ecosystem (would not unblock case-1 generator-style sources, but would unblock the Sequence.Borrowing.Protocol dual-conformer subset, which a future revisit could ship as a partial fluent chain over the subset).

On any revisit:
- Re-run `swift-institute/Experiments/sequence-map-fluent-chain-noncopyable-1/` against the current toolchain.
- If V1 compiles clean: unify the package's `var map` accessor across the Copyable / `~Copyable & ~Escapable` boundary; remove the asymmetric ship-state.
- If only V3 becomes safely shippable: ship a partial fluent chain restricted to Sequence.Borrowing.Protocol dual-conformers; keep the direct `compactMap` / `flatMap` methods as the full coverage path for non-dual-conforming sources.

## References

- **`swift-primitives/swift-parser-primitives/Experiments/owned-consuming-get-on-protocol-extension/EXPERIMENT.md`** — v1.0.0 (2026-05-14). Primary empirical record. §"Toolchain results matrix" V5a/V5b/V5c REFUTED on Swift 6.4-dev nightlies 2026-05-07-a and 2026-05-12-a; V5d SIL verifier crash (`MemoryLifetimeVerifier.cpp:263`); §"V1-V4 on Swift 6.4-dev with consuming-parameter wrappers — PASS" establishes the consuming-parameter-function shape as the only working envelope.
- **`swift-institute/Research/2026-05-18-consuming-get-protocol-extension-noncopyable-limitation.md`** — v1.0.0 (2026-05-18). Ecosystem-wide language-limitation writeup. §"Diagnostic emission site" locates the constraint at `swiftlang/swift/include/swift/AST/DiagnosticsSIL.def:886` (`sil_movechecking_capture_consumed`) and cites the intentional-rejection compiler-test fixture at `swiftlang/swift/test/SILGen/resilient_consuming_getter_nonescapable_test.swift`. Status: COMPLETE — principled design, not in-flight.
- **`swift-primitives/swift-property-primitives/Sources/Property Inout Primitives/Property.Inout.swift:90-101`** — non-`@inlinable` warning block on `Property.Inout.init(_ base: borrowing Base)`. Cites the Swift 6.3.1 / 6.4-dev release-mode miscompile when `withUnsafePointer(to: base) { $0 }` is inlined across a module boundary, with detailed audit at `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md`. Load-bearing for the Reframing-A rejection at L1.
- **`swift-primitives/swift-sequence-primitives/Sources/Sequence Borrowing/Sequence.Borrowing.Protocol.swift`** — defines `Sequence.Borrowing.Protocol` with `@_lifetime(borrow self) borrowing func makeIterator()`. §"Distinction from `Sequence.Protocol`" (lines 9-17) makes explicit that the protocols are distinct iteration models: consume-then-iterate vs borrow-iterate-while-source-alive. Establishes why generator-style / one-shot `~Copyable & Sequence.Protocol`-only sources cannot conform to `Sequence.Borrowing.Protocol`, which forecloses Reframing-A's iteration coverage on the load-bearing case.

### Related

- **`swift-primitives/swift-parser-primitives/Sources/Parser Error Primitives/Parser.Error.swift:53-54`** — the `.error` accessor that motivated the parser-primitives investigation in the same shape (`var .error: Parser.Transform<Self>` on `Parser.Protocol where Self: ~Copyable`). Independent confirmation of the failure mode in a different package family.
- **`swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md`** — v1.1.0 (2026-05-09). DECISION on `@_owned + UnderscoreOwned + consuming get` for the `Either<Never, T: ~Copyable>.value` enum-payload-extraction case. Phase 1 ships free-function `value(of:)`; Phase 2 (property form) deferred indefinitely. Parallel shape: same compiler constraint, different package.
- **`swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`** — v1.2.1 (2026-05-18). Tier-3 ecosystem decision for the parser-protocol family. Option A (`@_owned consuming get`) EMPIRICALLY REFUTED for production; recommendation is α-stratified architecture (protocol-level relaxation only, combinators stay Copyable, ~Copyable conformers as terminals). Parallel architecture model: similar to swift-sequence-primitives's asymmetric ship-state.
- **Experiment scaffolds**: `swift-institute/Experiments/sequence-map-fluent-chain-noncopyable-1/Sources/sequence-map-fluent-chain-noncopyable-1/` — V1 (consuming get baseline), V2 (read yielding owned builder — structurally impossible), V3 (read yielding ~Escapable borrowed builder — Reframing A scaffold, rejected for L1 production), V4 (mutating _read Property.View — Reframing B scaffold, requires `var source`). Status: DEFERRED-revisit. Reproducers retained as detectors for future Swift relaxation per the revisit triggers above.
