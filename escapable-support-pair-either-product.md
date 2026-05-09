# ~Escapable Support for Pair / Either / Product

<!--
---
version: 1.1.0
last_updated: 2026-05-09
status: DECISION
changelog:
  - v1.1.0 (2026-05-09): Shipped. Recommended action landed across the cohort plus institute-protocol upgrades:
    - swift-equation-primitives `3495e50` — Equation.Protocol now admits ~Escapable conformers.
    - swift-hash-primitives `0e5708e` — Hash.Protocol now admits ~Escapable conformers.
    - swift-comparison-primitives `a4fd209` — Comparison.Protocol now admits ~Escapable conformers.
    - swift-either-primitives `b6b7672` — swapped, value(of:), map (un-transformed arm) admit ~Escapable; institute conformances admit ~Escapable arms; flatMap/fold remain Escapable-only (Gap A); 65/65 tests on triple-toolchain.
    - swift-pair-primitives `7f7c7ef` — type-level ~Escapable upgrade; swapped + apply admit both arms ~Escapable; map/map admit ~Escapable on un-transformed arm; institute conformances admit ~Escapable arms; 32/32 tests on triple-toolchain.
    - swift-product-primitives — unchanged at `14f4278`; parameter-pack ~Copyable / ~Escapable suppression remains the Swift-language blocker.
  - v1.0.0 (2026-05-09): Initial RECOMMENDATION.
tier: 2
scope: cross-package
applies_to: [swift-pair-primitives, swift-either-primitives, swift-product-primitives]
trigger: forums-review of swift-either-primitives flagged "Verify and document the ~Escapable × swapped() lifetime story." User asked to research ~Escapable support across Either, Pair, and Product.
toolchains_verified:
  - Swift 6.3.1 (Xcode 26.4 default)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a (`org.swift.64202605071a`, version `6.4.20260507101`)
preceded_by:
  - nonescapable-ecosystem-state.md (DECISION, 2026-04-02) — the canonical state document for ~Escapable readiness
  - lifetime-annotation-escapable-swift-6.3.md — primitives-scoped lifetime annotation rules
relates_to:
  - noncopyable-property-extract-via-underscore-owned.md (this session, 2026-05-09)
---
-->

## Context

The `nonescapable-ecosystem-state.md` v1.0.0 (2026-04-02) records that **conditional `~Escapable` is viable for inline containers today** ("Box, Pair, fixed-element-count containers using the Sequence.Map pattern", §6 strategic recommendation 3). This research operationalizes that recommendation for the `swift-pair-primitives` / `swift-either-primitives` / `swift-product-primitives` cohort.

Current ~Escapable state across the cohort (verified 2026-05-09):

| Package | Type-level ~Escapable? | Functor methods admit ~Escapable arms? |
|---|:---:|:---:|
| swift-either-primitives | ✅ — `Either<Left: ~Copyable & ~Escapable, Right: ~Copyable & ~Escapable>: ~Copyable, ~Escapable` | ❌ — all functor methods constrain via `where Left: ~Copyable, Right: ~Copyable` (implicit Escapable from extension defaults) |
| swift-pair-primitives | ❌ — `Pair<First: ~Copyable, Second: ~Copyable>: ~Copyable` | ❌ — type doesn't even hold ~Escapable values |
| swift-product-primitives | ❌ — `Product<each Element>` (parameter pack, currently Copyable-only by language) | ❌ — same as Pair |

The forums-review of swift-either-primitives explicitly flagged: *"Verify and document the ~Escapable × swapped() lifetime story."* Empirical verification (2026-05-09): `Either.swapped(_:)` on `Either<NEResource, Int>` for an `NEResource: ~Escapable` arm produces:

```
error: referencing static method 'swapped' on 'Either' requires that 'NEResource' conform to 'Escapable'
note: 'where Left: Escapable' is implicit here
```

So Either's swapped doesn't admit ~Escapable arms today, even though the type itself supports them.

## Question

For each package in the cohort, can the functor surface (map / flatMap / fold / swapped / apply / append / prepend / zip / value extraction) be extended to admit `~Escapable` arms today on Swift 6.3.1 + Swift 6.4-dev? What lifetime annotations are required? Where does the Gap A closure-parameter-lifetime limitation block progress?

## Analysis

### Method classification by closure interaction

The cohort's functor surface splits into two classes:

| Class | Methods | Closure parameter? |
|---|---|---|
| **No-closure** | `Either.swapped`, `Pair.swapped`, `Product.swapped` (free function), `Product.append`, `Product.prepend`, `Product.zip`, `Either+Never.value(of:)`, `Pair+Conversion.tuple` | No |
| **Closure-bearing** | `Either.map(left:)/(right:)/(left:right:)`, `Either.flatMap(left:)/(right:)`, `Either.fold(left:right:)`, `Pair.map(first:)/(second:)/(first:second:)`, `Pair.apply`, `Product.map`, `Product.fold` | Yes — closure consumes the arm and produces a transform |

This split is the dividing line for ~Escapable feasibility today.

### Empirical: Either.swapped admits ~Escapable arms with `@_lifetime(copy either)`

Setup (verified on Swift 6.4-dev nightly 2026-05-07-a):

```swift
struct NEResource: ~Escapable {
    let id: Int
    @_lifetime(immortal)
    init(_ id: Int) { self.id = id }
}

extension Either where Left: ~Copyable & ~Escapable, Right: ~Copyable & ~Escapable {
    @_lifetime(copy either)
    public static func swappedNE(_ either: consuming Either) -> Either<Right, Left> {
        switch consume either {
        case .left(let l): .right(consume l)
        case .right(let r): .left(consume r)
        }
    }
}
```

Build clean. `[Verified: 2026-05-09]` `/tmp/escapable-research/` test target. The result's lifetime is `copy of either` — the result Either holds the moved payload, lifetime-anchored to the input.

### Empirical: Closure-bearing methods hit Gap A on full ~Escapable

```swift
extension Either where Left: ~Copyable & ~Escapable, Right: ~Copyable & ~Escapable {
    @_lifetime(copy either)
    public static func mapNE<NewRight: ~Copyable & ~Escapable, E: Swift.Error>(
        _ either: consuming Either,
        right transform: (consuming Right) throws(E) -> NewRight
    ) throws(E) -> Either<Left, NewRight> {
        switch consume either {
        case .left(let l): .left(consume l)
        case .right(let r): try .right(transform(consume r))
        }
    }
}
```

Build error: `error: lifetime-dependent value escapes its scope`. `[Verified: 2026-05-09]`

This is **Gap A** ("lifetime from Escapable closure" — `nonescapable-ecosystem-state.md` §5). Closure parameter lifetime dependencies are not ready in current Swift; the closure body's result lifetime cannot be tied back to the consumed input. The map result `Either<Left, NewRight>` would need to inherit a lifetime from `transform`'s output, which Gap A doesn't support.

### Empirical: Mixed-arm map IS supportable

```swift
extension Either where Left: ~Copyable & ~Escapable, Right: ~Copyable {
    @_lifetime(copy either)
    public static func mapPartial<NewRight: ~Copyable, E: Swift.Error>(
        _ either: consuming Either,
        right transform: (consuming Right) throws(E) -> NewRight
    ) throws(E) -> Either<Left, NewRight> {
        switch consume either {
        case .left(let l): .left(consume l)
        case .right(let r): try .right(transform(consume r))
        }
    }
}
```

Build clean. `[Verified: 2026-05-09]`

Mixed arms (Left ~Escapable, Right Escapable + ~Copyable) admit a closure-bearing map because the result's escapability depends only on Left's lifetime — Right's transform is independent. The lifetime annotation `@_lifetime(copy either)` ties the result to the input's Left payload.

This is significant: **mixed-arm functors are usable today**, even though both-arms-~Escapable is blocked.

### Empirical: Pair type-level ~Escapable upgrade is feasible

Pair currently has no ~Escapable at type level. The upgrade path:

```swift
public struct PairNE<First: ~Copyable & ~Escapable, Second: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    public var first: First
    public var second: Second
    @_lifetime(copy first, copy second)
    public init(_ first: consuming First, _ second: consuming Second) {
        self.first = first
        self.second = second
    }
}

extension PairNE: Copyable where First: Copyable & ~Escapable, Second: Copyable & ~Escapable {}
extension PairNE: Escapable where First: Escapable & ~Copyable, Second: Escapable & ~Copyable {}

extension PairNE where First: ~Copyable & ~Escapable, Second: ~Copyable & ~Escapable {
    @_lifetime(copy pair)
    public static func swapped(_ pair: consuming PairNE) -> PairNE<Second, First> {
        return PairNE<Second, First>(pair.second, pair.first)
    }
}
```

Build clean on 2026-05-07-a. `[Verified: 2026-05-09]`

Three findings:

1. **Conditional conformances must be explicit on the orthogonal axis.** When the type-level constraint is `~Copyable & ~Escapable`, every `extension Pair: Copyable where ...` MUST also state `& ~Escapable` (to prevent re-introducing Escapable as default), and every `extension Pair: Escapable where ...` MUST also state `& ~Copyable`. Without this, the compiler emits: `error: conditional conformance to 'Copyable' must explicitly state whether 'First' is required to conform to 'Escapable' or not`. `[Verified: 2026-05-09]`

2. **`init` requires `@_lifetime(copy first, copy second)`** when the type is ~Escapable. `[Verified: 2026-05-09]`

3. **`let consumed = consume pair` followed by `PairNE(consumed.second, consumed.first)` triggers the same compiler-bug move-checker diagnostic** ("copy of noncopyable typed value") that we hit on swift-product-primitives in the 2026-05-09 cohort consolidation. The workaround is to use direct field access `pair.second, pair.first` on the consuming parameter without an intermediate `let`-binding. This is the same shape that worked on Product's instance-canonical methods. Cross-reference: `pack-expand-on-consuming-param-property.md` memory entry. `[Verified: 2026-05-09]`

### Product: blocked by parameter-pack ~Copyable limitation

`Product<each Element>` uses Swift's parameter packs. Currently (Swift 6.3.1 + 6.4-dev) parameter packs do not admit `each T: ~Copyable`, let alone `each T: ~Copyable & ~Escapable`. `feedback_pack_concrete_same_type.md` documents related pack-substrate limitations.

The cohort's `swift-product-primitives` is currently Copyable-only by language; the consuming consolidation in this session preserved that Copyable-only stance per the empirical compiler-crash workaround.

~Escapable on Product would require:
1. Pack-syntax support for `each T: ~Copyable` (in pitch / future Swift)
2. Pack-syntax support for `each T: ~Copyable & ~Escapable` (further future)
3. Lifetime-annotation propagation through pack-expanded expressions

None of these are available today. **~Escapable on Product is deferred indefinitely**.

### Type-level ~Escapable does NOT block static-canonical pattern

For Pair, the static-canonical pattern (recently shipped in this session) survives the type-level ~Escapable upgrade. The static method body's body shape — direct field access on the consuming parameter without intermediate `let consumed = consume pair` — is the working shape. The instance method delegate pattern continues to work because instance methods on `~Copyable` types take an implicit consuming-self.

For Either, the static-canonical pattern (also recently shipped) similarly survives.

## Outcome

**Status**: RECOMMENDATION

**Recommended action per package**:

### swift-either-primitives — landed-ready

Add `~Escapable` arm support to **non-closure methods**:

| Method | Action |
|---|---|
| `Either.swapped(_:)` | Add `& ~Escapable` to where-clause; add `@_lifetime(copy either)`. Verified working. |
| `Either.swapped()` (instance) | Same — add `& ~Escapable`; instance method delegates to static, which has the `@_lifetime`. |
| `Either+Never` `value` property accessor | Currently Copyable-only. Skip — the `consuming get` + `@_owned` story (separate research) blocks the property form for ~Copyable too; a `~Escapable & ~Copyable` form would compound the blockers. |
| `Either+Never` `value(of:)` free function | Add `& ~Escapable` to generic constraint; add `@_lifetime(copy either)`. The function consumes either; the result is the moved-out payload with lifetime tied to the original. Implementation: gate on Swift 6.3.1+ + `Lifetimes` experimental feature (already in package settings via institute baseline). |

**Defer** for closure-bearing methods (`map`, `flatMap`, `fold`):

- `where Left: ~Copyable & ~Escapable, Right: ~Copyable & ~Escapable` constraint + closure parameter hits Gap A.
- `where Left: ~Copyable & ~Escapable, Right: ~Copyable` mixed-arm form WORKS but doubles the API surface (one constraint pair per closure direction). Defer until a concrete consumer needs the mixed-arm form; no use case has surfaced.

### swift-pair-primitives — type-level upgrade required

**Phase 1 (now)**: Type-level ~Escapable upgrade.

1. Change `Pair<First: ~Copyable, Second: ~Copyable>: ~Copyable` to `Pair<First: ~Copyable & ~Escapable, Second: ~Copyable & ~Escapable>: ~Copyable, ~Escapable`.
2. Update conditional conformances:
   - `extension Pair: Copyable where First: Copyable & ~Escapable, Second: Copyable & ~Escapable {}` (NEW)
   - Existing `extension Pair: Copyable where First: Copyable, Second: Copyable {}` is replaced by the above.
   - Add `extension Pair: Escapable where First: Escapable & ~Copyable, Second: Escapable & ~Copyable {}` (NEW)
   - Update Sendable extension to include `& ~Copyable & ~Escapable` on each arm.
3. Add `@_lifetime(copy first, copy second)` to `init(_:_:)`.
4. Update non-closure methods (`swapped`) to admit ~Escapable: add `& ~Escapable` to where-clause; add `@_lifetime(copy pair)` to static method.
5. Update non-closure method bodies: replace `let consumed = consume pair; ... consumed.second` with direct field access `pair.second` to avoid the move-checker bug on generic ~Copyable+~Escapable.
6. Update Codable conformance: should still apply when both arms are Copyable+Escapable+Codable (existing is `where First: Codable, Second: Codable`; defaults change so verify).
7. Verify triple-toolchain: 6.3.1 + 6.4-dev nightly + 6.4-dev/Embedded.

**Defer** closure-bearing methods (`apply`, `map(first:)`, `map(second:)`, `map(first:second:)`) — Gap A.

### swift-product-primitives — defer indefinitely

Parameter-pack syntax does not admit `each T: ~Copyable & ~Escapable` in Swift 6.3.1 + 6.4-dev. Track `swiftlang/swift` for pack-syntax extensions to noncopyable/nonescapable. When that lands, revisit.

The free function `swapped(_:)` (arity-2 only) on Product MAY be extendable independently — it doesn't use packs in its constraint. Test: the function takes `consuming Product<First, Second>` where First, Second are non-pack generics. Adding `~Escapable` to those is straightforward. Out of scope of this research; a follow-up empirical test would confirm.

### Cross-cohort: cohort uniformity considerations

After the recommended changes, the cohort's functor-surface support for ~Escapable would be:

| Type | swapped (~Escapable arms) | map/fold (~Escapable arms) | value(of:) (~Escapable arms) |
|---|:---:|:---:|:---:|
| Either | ✅ | ❌ Gap A — defer | ✅ |
| Pair | ✅ | ❌ Gap A — defer | n/a (no `value` accessor on Pair) |
| Product | ❌ pack-syntax limit | ❌ pack-syntax limit + Gap A | n/a |

Asymmetry between Either / Pair (closure methods deferred) and Product (everything deferred) is honest about Swift compiler current state. Mark Product's deferral conspicuously in DocC + audit notes; future revisit when pack syntax catches up.

### Migration risk

For swift-pair-primitives' Phase 1:

| Risk | Assessment |
|---|---|
| Source-compatibility break for existing consumers | LOW. Adding `& ~Escapable` to type parameter constraint is *additive* — Copyable+Escapable types still satisfy. No downstream code change required. |
| ABI break | N/A — pre-1.0, no ABI commitments. |
| Move-checker bug exposure | Already isolated to "let consume self" body shape; the recommended migration uses direct field access on consuming parameter, which empirically works. |
| Test coverage | Existing 30 Pair tests cover MoveOnly + Int arms. Adding ~Escapable test arms would require introducing a test-local ~Escapable type with `@_lifetime(immortal)` init. Bounded-cost addition (~3-5 tests). |

### Recommended ship order

1. **swift-either-primitives** — extend `swapped` + `value(of:)` to ~Escapable arms. Lowest-risk, fastest. Pure addition; existing API surface unchanged.
2. **swift-pair-primitives** — type-level ~Escapable upgrade + `swapped` extension. Higher cost (every conditional conformance touched + body shape rewrite for non-let-binding form) but well-bounded by the working pattern verified above.
3. **swift-product-primitives** — defer; document the deferral in audit + DocC.

## References

- Institute prior research:
  - `nonescapable-ecosystem-state.md` v1.0.0 (DECISION, 2026-04-02) — canonical state document, §6 recommendation 3 cited
  - `lifetime-annotation-escapable-swift-6.3.md` — primitives-scoped lifetime annotation rules
  - `noncopyable-property-extract-via-underscore-owned.md` (this session, 2026-05-09) — companion research on `@_owned` property accessor
- Memory entries:
  - `pack-expand-on-consuming-param-property.md` (this session) — explains the move-checker bug and the let-binding workaround
- Empirical reproductions: `/tmp/escapable-research/` (PairNE + Either ~Escapable variants)
- swiftlang/swift HEAD `e578b3a1e17`:
  - `include/swift/AST/AccessorKinds.def` — accessor kind enumeration
  - `test/SILGen/Inputs/resilient_consuming_getter_nonescapable.swift` — `~Escapable & ~Copyable` accessor patterns referenced for technique
- Cohort current state:
  - `swift-pair-primitives/Sources/Pair Primitives/Pair.swift:27` — current type-level constraint
  - `swift-either-primitives/Sources/Either Primitives/Either.swift:77` — current type-level constraint
  - `swift-product-primitives/Sources/Product Primitives/Product.swift:25` — current type-level constraint
