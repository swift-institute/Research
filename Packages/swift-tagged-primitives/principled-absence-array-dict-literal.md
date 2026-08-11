# Principled Absence — `ExpressibleByArrayLiteral` / `ExpressibleByDictionaryLiteral`

<!--
---
version: 1.2.1
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

<!--
Changelog:
- v1.2.1 (2026-04-30, ABI commitment status added): explicit ABI
  paragraph addressing whether `(T...) -> R` and `([T]) -> R` are
  committed-ABI-compatible or current-implementation-observation, with
  failure-mode + mitigation plan. Closes the load-bearing open question
  from the pre-launch forums-review pressure-test (Angle 3 P0).
- v1.2.0 (2026-04-30, carve-out authorized): per-user direction
  ("lets Allow unsafeBitCast for these specific cases"), SLI now
  ships fully-parametric `ExpressibleByArrayLiteral` and
  `ExpressibleByDictionaryLiteral` via the pointfreeco
  `unsafeBitCast` pattern. This is the **first and only documented
  carve-out** from the package's `[MEM-SAFE-001]` strict-memory-safety
  stance. The carve-out is bounded — only these two specific
  conformances, only these specific bitcast call sites, marked with
  the `unsafe` expression keyword in the implementation. Coverage:
  Array, ContiguousArray, Data, Set, Dictionary, and any custom
  ExpressibleByArrayLiteral / ExpressibleByDictionaryLiteral type
  (i.e., the pointfreeco parametric coverage matched 1:1). The earlier
  RRC-constrained safe path is replaced because it does not subsume
  the `Set` / `Dictionary` cases.
- v1.1.0 (2026-04-30, partial-coverage update — SUPERSEDED by v1.2.0):
  RangeReplaceableCollection-constrained safe-Swift path for Array.
  Dictionary literal remained excluded.
- v1.0.0 (2026-04-30): initial classification HARD-by-policy for both
  array and dict literal protocols.
-->

## Context

`pointfreeco/swift-tagged` declares conditional conformances for both array-shaped and dictionary-shaped literals on `Tagged`:

```swift
extension Tagged: ExpressibleByArrayLiteral
where Underlying: ExpressibleByArrayLiteral { ... }

extension Tagged: ExpressibleByDictionaryLiteral
where Underlying: ExpressibleByDictionaryLiteral { ... }
```

The implementation forwards through `unsafeBitCast` to bridge Swift's collection-literal initializers (`init(arrayLiteral:)` / `init(dictionaryLiteral:)`) into the parameterized `Tagged<Tag, Underlying>` initialization path. The bitcast is a load-bearing implementation detail — collection-literal constructors take variadic parameters, and Swift's protocol witness machinery for those collisions across the `Tag` parameter is hard to navigate without a bitcast escape hatch.

Swift Institute's `swift-tagged-primitives` deliberately removes both conformances. The argument is **memory-safety stance compatibility**: per `[MEM-SAFE-001]`, the package opts into `.strictMemorySafety()` (verified at `Package.swift:56`); per the broader Institute primitives convention, no `unsafeBitCast` / `unsafeDowncast` / pointer reinterpretation appears in production code. Adopting pointfree's implementation would require importing `unsafeBitCast` into our codebase, which the memory-safety posture explicitly prohibits.

The two conformances are treated together because:
1. The `unsafeBitCast` rationale is identical for both.
2. Both have the same shape (variadic-literal init that can't easily traverse the parametric Tag).
3. Both are niche enough that Tagged consumers rarely need them — collection-valued domains (e.g., `Tagged<UserGroup, [Int]>`) are unusual in primitives-layer use.

This document establishes the rationale and empirically classifies the absence.

**Trigger**: Per-protocol absence work directed by user 2026-04-30. Per [RES-001].

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` conform to `ExpressibleByArrayLiteral` and/or `ExpressibleByDictionaryLiteral` (when `Underlying` does)? If absent by default, what is the legitimate opt-in path, and is a SAFE-Swift conformance authorable on Swift 6.3.1?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §5 (table) — original removal rationale ("niche, unsafeBitCast in their implementation").
- [`tagged-literal-conformances.md`](./tagged-literal-conformances.md) and [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md) — establish the literal-quarantine policy: literal conformances ship in Test Support, not main. Array/dict literals would extend the same quarantine pattern if we shipped them at all.
- `[MEM-SAFE-001]` — strict-memory-safety opt-in; codifies the no-unsafe-escape-hatch posture.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) `extension Tagged: ExpressibleByArrayLiteral` / `ExpressibleByDictionaryLiteral`.

## Analysis

### Option A — Conform via unsafeBitCast (pointfreeco pattern)

```swift
extension Tagged: ExpressibleByArrayLiteral
where Underlying: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Underlying.ArrayLiteralElement...) {
        // pointfree-style: bitcast the variadic parameter through to Underlying's init
        let raw = unsafeBitCast(elements, to: [Underlying.ArrayLiteralElement].self)
        let _ = raw  // pseudo — actual implementation in pointfree is more involved
        // (full pointfree impl uses bitcast across the Tagged-vs-Underlying layout)
    }
}
```

**Pros**:
- Drop-in `let tagged: Tagged<Tag, [Int]> = [1, 2, 3]` ergonomics.
- Compatible with `[Int]` / `[String: Int]` etc. literal-friendly underlying values.

**Cons**:
1. **Requires `unsafeBitCast` in production code**. Conflicts with `[MEM-SAFE-001]` strict-memory-safety opt-in. The Institute's primitives layer does not ship `unsafeBitCast` in production; this conformance would be the first exception.
2. **Bridges a variadic-init shape that doesn't fit Tagged's structure cleanly**. The bitcast is structural, not stylistic — there's no straight `self.init(_unchecked: Underlying(arrayLiteral: elements...))` form because variadic forwarding into `init(arrayLiteral:...)` requires unboxing the implicit array. Swift's protocol-witness machinery ties the variadic shape to the type's static identity, and Tagged's parametric Tag complicates the resolution.

### Option B — SLI opt-in (with safe-Swift conformance only)

The SLI opt-in would require a non-`unsafeBitCast` implementation. Empirically: is one authorable?

```swift
extension Tagged: ExpressibleByArrayLiteral
where Tag: ~Copyable & ~Escapable, Underlying: ExpressibleByArrayLiteral & Escapable {
    public typealias ArrayLiteralElement = Underlying.ArrayLiteralElement
    public init(arrayLiteral elements: Underlying.ArrayLiteralElement...) {
        // Safe-Swift: try to forward through Underlying's init.
        // (Empirical question: does Swift's variadic-bridging compile here?)
        self.init(_unchecked: Underlying(arrayLiteral: elements))
        // ^^^ but Underlying.init(arrayLiteral:) takes variadic, not [Element]
        // ^^^ and this signature collision is the root structural issue
    }
}
```

**Cons**:
- Empirical: likely doesn't compile cleanly because `Underlying.init(arrayLiteral:)` is variadic and Swift's variadic re-forwarding from one type's protocol witness to another is structurally limited.
- Even if it compiles via spread / unboxing, the implementation has subtleties (variadic-array-vs-Array conversion) that pointfree's `unsafeBitCast` sidesteps for performance reasons.

### Option C — Hard absence + per-domain conformance

```swift
// Consumer's domain authors per-domain conformance:
struct UserGroup: ExpressibleByArrayLiteral {
    let storage: Tagged<UserGroupTag, [Int]>
    init(arrayLiteral elements: Int...) {
        self.storage = Tagged<UserGroupTag, [Int]>(_unchecked: Array(elements))
    }
}

let group: UserGroup = [1, 2, 3]
```

**Pros**:
- Domain owns the literal-construction semantics.
- No `unsafeBitCast` in our package — strict-memory-safety stance preserved.
- The variadic-forwarding at the consumer's struct level is straightforward (Swift handles `Array(variadic)` natively); the difficulty pointfree solves with bitcast doesn't apply at the wrapper-struct level.
- Aligns with the Test-Support literal-quarantine pattern.

**Cons**:
- Per-domain author responsibility — consumer writes the wrapper struct.

## Empirical verification

[`Experiments/tagged-no-array-dict-literal/`](../Experiments/tagged-no-array-dict-literal/) tests Option B's authorability on Swift 6.3.1 (without `unsafeBitCast`) and demonstrates Option C's per-domain alternative.

## Outcome

**[v1.2.0 update — fully parametric via documented `unsafeBitCast` carve-out]**:

Per user direction 2026-04-30, the strict-memory-safety stance gets one documented carve-out for `ExpressibleByArrayLiteral` and `ExpressibleByDictionaryLiteral`. SLI ships the pointfreeco-style fully-parametric conformances in `Tagged+Literals.swift`:

```swift
extension Tagged: ExpressibleByArrayLiteral
where Tag: ~Copyable, Underlying: ExpressibleByArrayLiteral {
    @_disfavoredOverload
    public init(arrayLiteral elements: Underlying.ArrayLiteralElement...) {
        let f = unsafe unsafeBitCast(
            Underlying.init(arrayLiteral:) as (Underlying.ArrayLiteralElement...) -> Underlying,
            to: (([Underlying.ArrayLiteralElement]) -> Underlying).self
        )
        self.init(_unchecked: f(elements))
    }
}

extension Tagged: ExpressibleByDictionaryLiteral
where Tag: ~Copyable, Underlying: ExpressibleByDictionaryLiteral {
    @_disfavoredOverload
    public init(dictionaryLiteral elements: (Underlying.Key, Underlying.Value)...) {
        let f = unsafe unsafeBitCast(
            Underlying.init(dictionaryLiteral:) as ((Underlying.Key, Underlying.Value)...) -> Underlying,
            to: (([(Underlying.Key, Underlying.Value)]) -> Underlying).self
        )
        self.init(_unchecked: f(elements))
    }
}
```

The `unsafe` expression keyword on the `unsafeBitCast` call satisfies the `[MEM-SAFE-001]` strict-memory-safety opt-in's audit requirement: every unsafe operation is explicitly marked. The carve-out is bounded — only these two specific bitcast call sites, only these two specific protocol witnesses.

**Why the bitcast is operationally safe**: the conversion is from `(Element...) -> Underlying` to `([Element]) -> Underlying`. Swift's variadic parameters are themselves `Array<T>` at the ABI level; the function-type reinterpretation is exact. The `unsafe` marker exists because Swift's type system does not surface variadic-vs-array as compatible function types — the type-level safety is the unverified part, not the runtime behaviour.

Coverage now matches pointfreeco's parametric reach:

| Shape | Coverage |
|---|---|
| `Array<T>` | ✓ via `ExpressibleByArrayLiteral` parametric |
| `ContiguousArray<T>` | ✓ |
| `Data` | ✓ |
| `Set<T>` | ✓ via parametric `ExpressibleByArrayLiteral` (set literals reuse array syntax) |
| `Dictionary<K, V>` | ✓ via `ExpressibleByDictionaryLiteral` parametric |
| Custom literal-conformable collections | ✓ |

**Soft / Hard classification (revised)**:

| Protocol | Classification |
|---|---|
| `ExpressibleByArrayLiteral` | **SOFT** — shipped in SLI via documented `unsafeBitCast` carve-out |
| `ExpressibleByDictionaryLiteral` | **SOFT** — shipped in SLI via documented `unsafeBitCast` carve-out |

**Carve-out scope**: this is the FIRST AND ONLY documented exception from `[MEM-SAFE-001]` in `swift-tagged-primitives`. Future SLI conformances or main-target additions that would require `unsafeBitCast` MUST surface as a separate per-action user authorization; this carve-out is not a precedent for blanket relaxation of the strict-memory-safety stance.

**Forward-compatibility note**: if a future Swift surfaces a parametric mechanism for variadic-init forwarding without bitcast (e.g., variadic generics applied to literal-conformance witnesses, or a stdlib-level `LiteralConvertibleFromSequence` protocol), the carve-out should be revisited and the safe-Swift path adopted.

## ABI commitment status

The carve-out's correctness rests on a function-type ABI claim: that `(T...) -> R` and `([T]) -> R` are ABI-identical at the function-pointer level for any given `T` and `R`. This section addresses what kind of claim that is — committed by Swift's stable-ABI manifesto, or current-implementation observation — and what the failure mode + mitigation plan looks like if the claim ceases to hold.

### Claim status: current-implementation observation, not committed ABI

The Swift compiler implements variadic parameters as a synthesized `Array<T>` at the call site: a call `f(1, 2, 3)` against `func f(_ xs: T...)` is lowered to `f([1, 2, 3])`. At the function-reference (function-pointer) level, the function takes a single `Array<T>` argument in both the `(T...) -> R` and `([T]) -> R` shapes; the variadic syntax is sugar at the call site, not a distinct function-type kind.

This implementation has been stable across every Swift release since at least Swift 4.x and is empirically verified by the pointfreeco `swift-tagged` package having shipped this exact pattern in production for ~6 years across multiple Swift major versions without observed runtime breakage. However:

- **The variadic-as-Array implementation is not part of Swift's documented stable-ABI surface.** Swift's stable-ABI manifesto (post-5.1) covers stdlib type layouts, name-mangling rules, and the calling convention for known function shapes; it does not enumerate the function-pointer ABI for variadic functions vs. their Array-taking equivalents as an explicit invariant.
- **The claim therefore rides on de-facto stability**: the implementation has been stable, the alternative implementations (e.g., a varargs-style C-style argv list) would require the compiler team to break a large amount of existing code, and there is no proposed Swift Evolution work targeting this lowering.
- **`unsafeBitCast` between function types is itself well-defined when the callee-visible argument layouts match**; it is the type-system surface that needs the unsafe escape, not the runtime behaviour.

### Failure mode if the ABI claim ceases to hold

If a future Swift release changes the function-reference ABI of variadic functions — e.g., introducing a separate variadic-function-pointer type that is not bit-compatible with the Array-taking version — the bitcast at `Tagged+Literals.swift:121, 133` would produce one of:

1. **Compile-time mismatch** — most likely outcome. The `as (...) -> R` cast would fail to type-check because the variadic shape no longer exists as a function-type, or the bitcast would be statically rejected by the verifier. The package would fail to build on the new toolchain; consumers would see a compile error, not silent miscompile.
2. **Link-time mismatch** — a function-pointer with mismatched calling convention is invoked. On most platforms this manifests as a calling-convention violation at the first invocation (`Tagged<Tag, [Element]>(arrayLiteral: …)` or the dictionary equivalent). Behaviour is platform-specific but typically traps before producing observable results.
3. **Silent miscompile (worst case)** — calling convention happens to align by coincidence on the toolchain's target architectures. Extremely unlikely given the variadic-as-Array implementation's longevity, but is the scenario the `unsafe` keyword guards against in principle.

In any of (1), (2), or (3), the package's behaviour is bounded to the Array/Dict literal init path. The carve-out's narrow scope (two function-pointer reinterpretation sites, both consumed immediately by an init forwarding call, no value escapes the local scope) means failure-mode containment is at-most-the-init-call, not propagating into stored state.

### Mitigation plan

1. **CI coverage** — the package's CI exercises Array and Dict literal initialization on each toolchain change; any toolchain that breaks the ABI assumption will fail the literal test suite (`Tagged+Literals Tests.swift` Performance + Unit) before reaching consumers. The Performance sub-suite's `literal construction batched` test exercises the bitcast init path 1,000 times per run.
2. **Beta-toolchain testing** — when Swift beta toolchains for major version bumps are published, the package SHOULD be built against them as part of the regular ecosystem-wide cross-toolchain matrix. Failure on beta is the early-warning signal.
3. **Fallback removal path** — if the ABI assumption fails on a future toolchain, the carve-out's two conformances would be removed in a minor-version bump (`0.x → 0.(x+1)`). Consumers whose `Underlying` is Array-shaped retain the `RangeReplaceableCollection`-constrained safe-Swift path documented in v1.1.0 (now superseded but mechanically authorable). Consumers whose `Underlying` is `Dictionary` or non-RRC `Set` would author per-domain wrapper structs (Option C of this document).
4. **Forward-port to safe Swift** — if a future Swift surfaces variadic generics applied to literal-conformance witnesses, or a stdlib-level `LiteralConvertibleFromSequence`-style protocol, the carve-out is removed in favour of the safe-Swift path; consumer-visible behaviour is preserved.

### Confidence level

| Dimension | Assessment |
|---|---|
| Operational correctness on Swift 6.3.x | **HIGH** — empirically verified by `Experiments/tagged-zero-cost-codegen/`, which exercises both the canonical init and the bitcast inits at -O on arm64 macOS 26 and confirms functional equivalence (114/114 tests pass; runtime values are identical). pointfreeco's ~6-year track record across multiple Swift major versions provides corroborating evidence at the cross-toolchain dimension. |
| Runtime cost vs. canonical (non-folded) `Underlying.init(arrayLiteral:)` | **APPROXIMATELY EQUIVALENT** — the bitcast adds the function-pointer-reinterpretation cost (a single move into the function-pointer register) plus the call indirection; in release-mode codegen this is on the order of one extra call and a stack-frame setup vs. a direct dynamic init. For runtime-variable inputs (the typical primitives-layer use case), the bitcast init is a near-equivalent cost to a non-folded dynamic init through the same protocol witness. |
| Runtime cost vs. constant-folded literal-construction (direct path) | **HIGHER** — `let xs: [Int] = [1, 2, 3]` constant-folds to a static-Array reference under -O (~3 instructions); `let tagged: Tagged<Tag, [Int]> = [1, 2, 3]` does NOT reach the constant folder because `unsafeBitCast` is opaque to the optimizer (~36 instructions). This is a property of `unsafeBitCast`'s optimizer-opacity, not the carve-out's correctness. Consumers needing constant-folded Array literal performance should construct the Array first and wrap explicitly: `let xs: [Int] = [1, 2, 3]; let tagged = Tagged<Tag, [Int]>(_unchecked: xs)`. |
| ABI-commitment status | **CURRENT-IMPLEMENTATION RELIANCE** — not part of the documented stable-ABI manifesto; relies on the variadic-as-Array implementation's de-facto stability. |
| Failure-mode containment | **HIGH** — bounded to two init call sites; expected failure mode is compile-time, not runtime; no escape into stored state. |
| Recovery posture | **MEDIUM-HIGH** — clear minor-version-bump removal path; consumer migration to per-domain wrappers or RRC-shaped safe path is documented. |

The carve-out ships at HIGH confidence on operational correctness, APPROXIMATELY EQUIVALENT to non-folded canonical init at runtime, HIGHER cost than constant-folded literal direct path (because `unsafeBitCast` opacity blocks the optimizer's constant folder), MEDIUM-HIGH confidence on long-term ABI durability, and HIGH confidence on failure-mode bounds. The asymmetries are the structural cost of any `unsafeBitCast` site; the file-block documentation, this section, and the codegen experiment's per-path disassembly comparison make the cost explicit rather than hidden. The simple-literal SLI conformances (Integer / Float / Boolean / UnicodeScalar / ExtendedGraphemeCluster / String / StringInterpolation) do NOT use the bitcast path and ARE bitwise-identical to direct construction at -O — the cost asymmetry is specific to `ExpressibleByArrayLiteral` and `ExpressibleByDictionaryLiteral`.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §5 (the seed table).
- [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md) — literal-quarantine policy.
- [`sli-literal-vs-strideable-tradeoff.md`](./sli-literal-vs-strideable-tradeoff.md) — the parallel SLI policy decision (literals over Strideable) that this carve-out rides.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) `extension Tagged: ExpressibleByArrayLiteral` / `ExpressibleByDictionaryLiteral` (uses `unsafeBitCast` for fully-parametric coverage).
- [`Experiments/tagged-zero-cost-codegen/`](../Experiments/tagged-zero-cost-codegen/) — empirical codegen evidence covering the bitcast init path alongside the canonical init.
