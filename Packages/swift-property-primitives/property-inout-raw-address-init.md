# Property.Inout / Property.Borrow Raw-Address Construction

<!--
---
version: 1.1.0
last_updated: 2026-05-09
status: CONVERGED-PRUNED
tier: 1
scope: per-package
preceded_by:
  - swift-institute/Research/property-ownership-escapable-base-upgrade.md (DECISION v1.0.0, 2026-05-09) — institute-wide rationale for the Property + Ownership cascade
  - swift-property-primitives/Research/escapable-base-upgrade.md (CONVERGED v1.0.0, 2026-05-09) — Property type-level Base widening (shipped at 5bb2f67); §L documents this dispatch's trigger
  - swift-ownership-primitives/Research/escapable-value-upgrade.md (CONVERGED v1.0.0, 2026-05-09) — Ownership.Inout Value widening (shipped at 30f44a2)
  - swift-institute/Research/escapable-support-pair-either-product.md (DECISION v1.1.0, 2026-05-09) — canonical cohort pattern
  - swift-institute/Research/nonescapable-ecosystem-state.md (DECISION, 2026-04-02) — ecosystem readiness (UnsafeMutablePointer Escapable constraint, withUnsafeMutablePointer Escapable-gated)
  - swift-property-primitives/Research/property-type-family.md (IMPLEMENTED, 2026-01-21) — foundational design
relates_to:
  - swift-collection-primitives/Research/escapable-protocol-foreach-count-view.md (downstream cascade — re-derives parked Item B Candidate 2 widening using these new APIs)
toolchains_verified:
  - Swift 6.3.1 (Xcode 26.4.1 default)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a (`org.swift.64202605071a`, version `6.4.20260507101`)
  - Swift 6.4-dev/Embedded
trigger: §L of `escapable-base-upgrade.md` documents that the type-level Property Base widening shipped at 5bb2f67 leaves the functional construction path requiring Escapable Base. `Property.Inout(_:)` inout-init delegates to `Ownership.Inout(mutating:)` which uses `withUnsafeMutablePointer(to:)` (stdlib-gated `where T: Escapable`). Consumers attempting `Property.Inout(&self)` from a mutating accessor on `Self: ~Copyable & ~Escapable` get `error: referencing initializer 'init(_:)' on 'Property.Inout' requires that 'Self' conform to 'Escapable'`.
---
-->

## Status: CONVERGED-PRUNED (v1.1.0, 2026-05-09)

> The design analysis below CONVERGED in Phase 1 of `HANDOFF-property-inout-raw-address-init-cascade.md` and the implementation shipped at swift-property-primitives `be0e3a2` + `9ee0c37`. The Property tier source was subsequently **PRUNED** by the surgical follow-up `HANDOFF-escapable-property-tier-prune.md` (2026-05-09): the 7 raw-address-form inits, 7 admission tests, and the type-level Property Base widening from `5bb2f67` were reverted in a single new commit on top of `9ee0c37`, returning Sources/+Tests/ to the pre-cascade `49dce56` state.
>
> **Why pruned**: Property's distinguishing value-add over raw `Ownership.Inout/Borrow` is the fluent-accessor namespace pattern (`container.fluent.accessor`), which is structurally view-of-self. View-of-self is blocked at the Swift language level (`#ExclusivityViolation` on dual-`&self` arguments at the call boundary; the boundary-derived raw pointer is body-scoped and dies on function return). Without view-of-self, Property's `~Escapable Base` admission has no distinguishing consumer pattern over raw Ownership — the cascade was speculative tail. See §B + Appendix A for the empirical SIL reproduction.
>
> **What survives**: this research note, preserved on disk verbatim. The design space, the empirical findings, the structural-blocker analysis, and the language-affordance trigger condition are load-bearing learnings that survive the source prune. When the Swift toolchain ships a user-package mechanism for raw-pointer derivation from inout self without dual-borrow violation (e.g., `Builtin.addressOfBorrow` exposed at user level, or a `~Escapable`-admitting `withUnsafeMutablePointer` variant, or a `Reborrow<T>: ~Escapable`-style facility), this note is the resume-from-here pointer for re-shipping the cascade with confidence.
>
> **What does not survive**: the 7 init signatures + 7 admission tests + type-level Base widening shipped at `5bb2f67`/`be0e3a2`/`9ee0c37`. They are reverted out of Sources/+Tests/ as of the prune commit (post-`9ee0c37`). Re-shipping them requires re-attempting the cascade once the language affordance lands.
>
> **What the broader institute program retains**: `swift-ownership-primitives` `30f44a2` is **not pruned** — Ownership's `~Escapable Value` admission stays. Ownership-tier consumers (Buffer.Inout, Carrier composition, mapped-region patterns) are coherent with the separate-source storage/owner shape; view-of-self is not the gating consumer pattern at the Ownership tier. Cohort base (Pair / Either / Product `~Escapable` arms) and institute protocols (Equation / Hash / Comparison admit `~Escapable` conformers) also stay — proven consumers exist.

## Context

The Property + Ownership cascade closed in two pushes on 2026-05-09:

1. `swift-ownership-primitives` 30f44a2 — `Ownership.Inout<Value>` admits `Value: ~Copyable & ~Escapable`; storage rewrites `UnsafeMutablePointer<Value>` → `UnsafeMutableRawPointer`; new `init(unsafeRawAddress:mutating:)` in `where Value: ~Copyable & ~Escapable` extension; existing typed/inout-init paths gate `where Value: ~Copyable` (Escapable implicit) preserving the Escapable contracts.

2. `swift-property-primitives` 5bb2f67 — `Property<Tag, Base>` admits `Base: ~Copyable & ~Escapable`; Property itself becomes `~Copyable, ~Escapable`; conditional Copyable/Sendable/Escapable conformances on orthogonal axes per cohort canonical pattern; `Property.Inout` / `Property.Borrow` / their `Typed` / `Typed.Valued` / `Typed.Valued.Valued` nestings widen at type level. Each variant's existing `init(_ base: inout Base)` / `init(_ base: borrowing Base)` was relocated from the struct body into a separate extension at narrower constraint `where Base: ~Copyable` (Escapable implicit) — because the inner construction path delegates to `Ownership.Inout(mutating:)` / `Ownership.Borrow(borrowing:)`, both of which use `with{Unsafe,UnsafeMutable}Pointer(to:)` and require Escapable.

§L of `escapable-base-upgrade.md` calls out the residual structural surface: type-level admission shipped, but the *functional construction path* for `~Escapable` Base remains absent. A consumer like `swift-collection-primitives`' parked `Collection.Protocol+ForEach.swift`, which widens its where-clause to `Self: ~Copyable & ~Escapable` and calls `Property<Collection.ForEach, Self>.Inout(&self)` from a `mutating _read`, fails to compile: `error: referencing initializer 'init(_:)' on 'Property.Inout' requires that 'Self' conform to 'Escapable'`.

Pre-flight verified 2026-05-09 at HEAD `5bb2f67`:

- Working tree clean.
- `swift test` baseline: **48 tests in 48 suites passed** in 0.002s.
- 7 Property variants in scope (4 Inout + 3 Borrow). All 7 currently declare `~Copyable, ~Escapable` storage `Tagged<Tag, Ownership.{Inout,Borrow}<Base>>`. All 7 carry exactly one existing init at `where Base: ~Copyable` (Escapable implicit), gated by the inner Ownership delegate's Escapable requirement.
- Upstream Ownership precedent already shipped — `swift-ownership-primitives` 30f44a2 lines 113–139 (`Ownership.Inout` `init(unsafeRawAddress:mutating:)`), `swift-ownership-primitives` `Ownership.Borrow.swift` lines 257–284 (`Ownership.Borrow` `init(unsafeRawAddress:borrowing:)`).

## Question

What is the file-level shape of the raw-address-construction surface — init signature per variant, Tagged-composition body, `@_lifetime` annotation, consumer call-site pattern from `mutating _read`, NEResource test fixture — that admits `Base: ~Copyable & ~Escapable` construction across all 7 Property.{Inout,Borrow}[.Typed[.Valued[.Valued]]] variants while preserving the existing `init(_ base: inout/borrowing Base)` Escapable contracts at the public API boundary?

## Analysis

### A. Precedent — Ownership.Inout / Ownership.Borrow at 30f44a2

Mirroring the precedent VERBATIM is the dispatch's stated approach (§D of `property-ownership-escapable-base-upgrade.md`). Ownership.Inout's new init shape (`swift-ownership-primitives/Sources/Ownership Inout Primitives/Ownership.Inout.swift:113-139`):

```swift
extension Ownership.Inout where Value: ~Copyable & ~Escapable {
    @unsafe
    @inlinable
    @_lifetime(&owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeMutableRawPointer,
        mutating owner: inout Owner
    ) {
        unsafe (self._pointer = pointer)
    }
}
```

Ownership.Borrow's new init shape (`swift-ownership-primitives/Sources/Ownership Borrow Primitives/Ownership.Borrow.swift:257-284`):

```swift
extension Ownership.Borrow where Value: ~Copyable & ~Escapable {
    @unsafe
    @inlinable
    @_lifetime(borrow owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeRawPointer,
        borrowing owner: borrowing Owner
    ) {
        unsafe (self._pointer = pointer)
        self._owner = nil
    }
}
```

Both exist as the only construction path for `~Escapable Value`. Their tests (`swift-ownership-primitives/Tests/Ownership Primitives Tests/Ownership.Inout Tests.swift`, `Ownership.Borrow Tests.swift`) verify *compile-time admission only*: closure literals reference the new init for ~Escapable Value but never invoke it at runtime. The `value` accessor remains gated `where Value: ~Copyable` (Escapable implicit) — `assumingMemoryBound(to: Value.self)` returns `UnsafeMutablePointer<Value>` which requires `Value: Escapable`.

### B. Consumer call-site mechanics — empirical verification (2026-05-09)

The dispatch's premise required empirical verification: how does a consumer, holding `inout Self` where `Self: ~Copyable & ~Escapable`, produce the `UnsafeMutableRawPointer` argument required by the new init? Stdlib's `withUnsafeMutablePointer(to:)` and `withUnsafeMutableBytes(of:)` both require `T: Escapable` (verified by `xcrun swiftc -typecheck` against an `inout NEResource` argument; both reject with `error: requires that 'NEResource' conform to 'Escapable'`).

Empirical finding: **Swift's implicit `inout T` → `UnsafeMutableRawPointer` conversion at call-argument boundary admits `~Escapable T`**. The probe:

```swift
struct NEResource: ~Copyable, ~Escapable {
    var id: Int
    @_lifetime(immortal)
    init(_ id: Int) { self.id = id }
}

extension NEResource {
    var asRef: InoutRef<NEResource> {
        @_lifetime(&self)
        mutating _read {
            yield unsafe InoutRef(unsafeRawAddress: &self, mutating: &self)
        }
    }
}
```

…typechecks cleanly under `-enable-experimental-feature Lifetimes -enable-experimental-feature LifetimeDependence` on Swift 6.3.1 + Swift 6.4-dev nightly 2026-05-07-a. The `&self` argument in `unsafeRawAddress:` position implicitly converts the inout reference to `UnsafeMutableRawPointer` at the call boundary — independently of `Self: Escapable`. The `mutating: &self` argument anchors the `@_lifetime(&owner)` lifetime dependency.

This empirical mechanism is the missing piece between the precedent (compile-time admission only at Ownership) and the runtime consumer (Collection.Protocol+ForEach). It is *not* a new design vocabulary — `&self` → `UnsafeMutableRawPointer` is an existing Swift compiler feature. It is documented here because no prior research note in the corpus exercises it for `~Escapable Self`.

For the `borrowing` form (Property.Borrow), the analogous pattern requires the call site to be either `mutating _read` or otherwise have a mutable reference to self, because `&self` is not available from a non-mutating `_read`. A pure `_read` accessor on `Self: ~Copyable & ~Escapable` cannot produce `UnsafeRawPointer` from `borrow self` via any current user-accessible mechanism (`withUnsafePointer(to:)` requires Escapable). This dispatch ships the Borrow new init as compile-time-admission-only (matching Ownership.Borrow's precedent); a runtime call-site pattern for non-mutating `_read` on ~Escapable Self is deferred until consumer surfaces.

### C. Init signatures — verbatim cascade across 4 Inout + 3 Borrow variants

Each variant gains exactly one new init in a new `where Base: ~Copyable & ~Escapable [, Element: ~Copyable]` extension. Storage delegates through Tagged + the inner Ownership.Inout/Borrow new init (composition path per Open Question 1, supervisor-confirmed):

#### Property.Inout (`Property.Inout.swift`)

```swift
extension Property.Inout where Base: ~Copyable & ~Escapable {
    /// Unsafely creates an exclusive mutable accessor using a raw address,
    /// with lifetime based on the mutating owner.
    ///
    /// This is the only construction path available when `Base` is `~Escapable`,
    /// because stdlib's typed `UnsafeMutablePointer<Base>` requires `Base: Escapable`.
    /// Mirrors `Ownership.Inout.init(unsafeRawAddress:mutating:)` (the underlying
    /// storage init) — same shape, composed through Tagged.
    ///
    /// - Parameters:
    ///   - pointer: The raw address of the value to mutate.
    ///   - owner: The owning instance whose mutation scope bounds this reference.
    @unsafe
    @inlinable
    @_lifetime(&owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeMutableRawPointer,
        mutating owner: inout Owner
    ) {
        self._storage = Tagged(_unchecked: unsafe Ownership.Inout(unsafeRawAddress: pointer, mutating: &owner))
    }
}
```

#### Property.Inout.Typed (`Property.Inout.Typed.swift`)

```swift
extension Property.Inout.Typed where Base: ~Copyable & ~Escapable, Element: ~Copyable {
    @unsafe
    @inlinable
    @_lifetime(&owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeMutableRawPointer,
        mutating owner: inout Owner
    ) {
        self._storage = Tagged(_unchecked: unsafe Ownership.Inout(unsafeRawAddress: pointer, mutating: &owner))
    }
}
```

#### Property.Inout.Typed.Valued (`Property.Inout.Typed.Valued.swift`)

Identical signature, identical body, in `extension Property.Inout.Typed.Valued where Base: ~Copyable & ~Escapable, Element: ~Copyable`.

#### Property.Inout.Typed.Valued.Valued (`Property.Inout.Typed.Valued.Valued.swift`)

Identical signature, identical body, in `extension Property.Inout.Typed.Valued.Valued where Base: ~Copyable & ~Escapable, Element: ~Copyable`.

#### Property.Borrow (`Property.Borrow.swift`)

```swift
extension Property.Borrow where Base: ~Copyable & ~Escapable {
    /// Unsafely creates a read-only accessor using a raw address, with
    /// lifetime based on the borrowed owner.
    ///
    /// This is the only construction path available when `Base` is `~Escapable`,
    /// because stdlib's typed `UnsafePointer<Base>` requires `Base: Escapable`.
    /// Mirrors `Ownership.Borrow.init(unsafeRawAddress:borrowing:)` (the
    /// underlying storage init) — same shape, composed through Tagged.
    ///
    /// - Parameters:
    ///   - pointer: The raw address of the value to borrow.
    ///   - owner: The owning instance whose lifetime scopes this borrow.
    @unsafe
    @inlinable
    @_lifetime(borrow owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeRawPointer,
        borrowing owner: borrowing Owner
    ) {
        self._storage = Tagged(_unchecked: unsafe Ownership.Borrow(unsafeRawAddress: pointer, borrowing: owner))
    }
}
```

#### Property.Borrow.Typed (`Property.Borrow.Typed.swift`)

Identical signature, identical body, in `extension Property.Borrow.Typed where Base: ~Copyable & ~Escapable, Element: ~Copyable`.

#### Property.Borrow.Typed.Valued (`Property.Borrow.Typed.Valued.swift`)

Identical signature, identical body, in `extension Property.Borrow.Typed.Valued where Base: ~Copyable & ~Escapable, Element: ~Copyable`.

### D. Tagged composition — confirmed

Each new init's body composes through Tagged:

```swift
self._storage = Tagged(_unchecked: unsafe Ownership.Inout(unsafeRawAddress: pointer, mutating: &owner))
```

This mirrors the existing init pattern (e.g., `Property.Inout.swift:79`) which uses `Tagged(_unchecked: Ownership.Inout(mutating: &base))` for the Escapable path. The choice to compose rather than bypass Tagged is the structural symmetry decision per Open Question 1: every Property variant's existing init flows through `Tagged(_unchecked:)`; the new init follows the same shape with the inner Ownership delegate switched to `unsafeRawAddress:` form. Tagged already admits `Underlying: ~Copyable & ~Escapable` (`swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:55`); no upgrade required.

The composition path empirically compiles (probe verified 2026-05-09 — see Appendix A). The bypass alternative (storing `UnsafeMutableRawPointer` directly in the Property variant rather than `Tagged<…, Ownership.Inout<Base>>`) would invalidate the `var base: Ownership.Inout<Base>` accessor pattern shipped at type-level widening (`Property.Inout.swift:130-133` and equivalents on 6 other variants), forcing a parallel Property-side accessor surface for ~Escapable Base. That is structurally larger, breaks the `_storage.underlying` pattern shipped at 5bb2f67, and doesn't compose cleanly with the existing `var base` `_read` coroutine.

### E. `@_lifetime` annotations — verbatim from precedent

| Variant | New init annotation | Source of pattern |
|---------|---------------------|-------------------|
| All 4 Inout variants | `@_lifetime(&owner)` | `Ownership.Inout.swift:132` |
| All 3 Borrow variants | `@_lifetime(borrow owner)` | `Ownership.Borrow.swift:276` |

The `@_lifetime(&owner)` shape on Inout is consistent with the existing `Ownership.Inout.init(unsafeAddress:mutating:)` at line 105 (mutable-owner shape). The `@_lifetime(borrow owner)` shape on Borrow mirrors `Ownership.Borrow.init(unsafeAddress:borrowing:)` at line 248.

### F. NEResource test fixture — reuse cohort precedent

The test fixture from `Ownership.Inout Tests.swift` (already shipped):

```swift
private struct NEResource: ~Escapable, ~Copyable {
    let id: Int
    @_lifetime(immortal)
    init(_ id: Int) { self.id = id }
}
```

Reuse VERBATIM in the property-primitives test files. No design originality at the fixture level.

### G. Test coverage — compile-time admission per variant + regression guards

Mirroring the Ownership precedent shape, each of the 7 new inits gets a compile-time-admission test:

| Test (proposed name) | Verifies |
|----------------------|----------|
| `Inout~Escapable type-level admission via init(unsafeRawAddress:mutating:)` | Property.Inout's new init compiles for `Base == NEResource` |
| `Inout.Typed~Escapable type-level admission via init(unsafeRawAddress:mutating:)` | Property.Inout.Typed's new init compiles |
| `Inout.Typed.Valued~Escapable type-level admission via init(unsafeRawAddress:mutating:)` | Property.Inout.Typed.Valued's new init compiles |
| `Inout.Typed.Valued.Valued~Escapable type-level admission via init(unsafeRawAddress:mutating:)` | Property.Inout.Typed.Valued.Valued's new init compiles |
| `Borrow~Escapable type-level admission via init(unsafeRawAddress:borrowing:)` | Property.Borrow's new init compiles |
| `Borrow.Typed~Escapable type-level admission via init(unsafeRawAddress:borrowing:)` | Property.Borrow.Typed's new init compiles |
| `Borrow.Typed.Valued~Escapable type-level admission via init(unsafeRawAddress:borrowing:)` | Property.Borrow.Typed.Valued's new init compiles |

Each test is structurally identical to the Ownership precedent's compile-time-admission test (`Ownership.Inout Tests.swift` `Inout~Escapable type-level admission via init(unsafeRawAddress:mutating:)`): a closure literal references the new init for `Base == NEResource`; never invoked. Compile-time regression catches type-level admission revert.

Existing 48 tests must all continue to pass.

### H. Public API surface — strictly additive

Each of the 11 source files (4 Inout + 4 Inout.Typed/Valued/Valued.Valued + 3 Borrow + Borrow.Typed/Valued) gains exactly one new extension block. Each new extension block contains exactly one new init. No existing init signatures change. No existing extension where-clauses change. No body rewrites on existing inits. No accessor-shape changes.

The seven existing `init(_ base: inout Base)` / `init(_ base: borrowing Base)` initializers in `where Base: ~Copyable` extensions stay verbatim. Downstream call sites passing Escapable Base are unaffected.

### I. File-modification summary

| File | Change kind | Lines (estimate) |
|------|-------------|------------------|
| `Sources/Property Inout Primitives/Property.Inout.swift` | +1 extension block (~16 lines) | +16 |
| `Sources/Property Inout Primitives/Property.Inout.Typed.swift` | +1 extension block | +16 |
| `Sources/Property Inout Primitives/Property.Inout.Typed.Valued.swift` | +1 extension block | +16 |
| `Sources/Property Inout Primitives/Property.Inout.Typed.Valued.Valued.swift` | +1 extension block | +16 |
| `Sources/Property Borrow Primitives/Property.Borrow.swift` | +1 extension block | +16 |
| `Sources/Property Borrow Primitives/Property.Borrow.Typed.swift` | +1 extension block | +16 |
| `Sources/Property Borrow Primitives/Property.Borrow.Typed.Valued.swift` | +1 extension block | +16 |
| `Tests/Property Inout Primitives Tests/*` | NEResource fixture + 4 admission tests | +~50 lines |
| `Tests/Property Borrow Primitives Tests/*` | NEResource fixture + 3 admission tests | +~40 lines |
| `Package.swift` | Unchanged (Lifetimes already enabled) | 0 |

**Total: ~112 lines across 7 source files; ~90 lines across 2 test directories.**

### J. Per-toolchain expectations

`Lifetimes` and `LifetimeDependence` features already enabled in `Package.swift`. No `Package.swift` changes required.

`@_lifetime(&owner)` and `@_lifetime(borrow owner)` annotations are stable on Swift 6.3.1 + Swift 6.4-dev nightly per `nonescapable-ecosystem-state.md` §1.

Parameter-pack expansion bugs (`swiftlang/swift#88985`, `#88987` per memory `pack-expand-on-consuming-param-property.md`) do NOT apply — the new inits use no parameter packs.

Pre-existing baseline noise on Swift 6.4-dev nightly + Embedded (Optional+take.swift, per dispatch's documented baseline) is accommodated by CI policy; cited in commit message; not bundled into a fix per supervisor ground rule (`MUST NOT silently expand scope`).

### K. Cascade-execution-order

This package is the only package modified by this dispatch's Phase 2 PUSH #1. The downstream `swift-collection-primitives` push (Phase 2 PUSH #2) re-derives the parked Item B Candidate 2 widening using these new APIs and adds Collection.Count.View widening — see `swift-collection-primitives/Research/escapable-protocol-foreach-count-view.md`.

Phase 3 cascade verification is package-level `swift build --build-tests` across the consumer-package set per [HANDOFF-035] (per supervisor scope direction: ~10–20 packages depending on bucket-(a) distribution; surface NEW regressions only).

### L. Open Question resolution

| Open Question (from dispatch) | Resolution |
|-------------------------------|------------|
| 1. Tagged composition — route through Tagged + Ownership new init, or bypass? | **Compose** — every existing variant's init uses `Tagged(_unchecked: Ownership.{Inout,Borrow}(…))`; the new init follows the same shape. Bypassing breaks `var base: Ownership.{Inout,Borrow}<Base>` accessor pattern shipped at 5bb2f67. |
| 2. Property.Consume analog | **Out of scope confirmed**. `extension Property where Base: Copyable` declares Property.Consume (`Property.Consume.swift:3`); `Optional<Base>` storage requires Copyable. ~Escapable structurally inapplicable. |
| 3. Other parked downstream consumers besides Collection.Protocol+ForEach + Collection.Count.View? | **None** — Phase 0 survey across 153 external consumer files returned zero matches for `where Self:.*~Copyable.*~Escapable` combined with `Property.Inout|Property.Borrow` construction. |

## Outcome

**Status**: CONVERGED.

The raw-address-construction surface lands as 7 verbatim mirrors of the Ownership.Inout/Borrow precedent (composed through Tagged) across 7 source files in swift-property-primitives, plus 7 compile-time-admission tests across 2 test directories. Per-package single amended commit per [RELEASE-013] First-Publication Clean-History; class-(c) public-repo push via per-action user authorization per [GIT-001].

Triple-toolchain verification (Swift 6.3.1 + Swift 6.4-dev nightly 2026-05-07-a + Swift 6.4-dev/Embedded) before push, per cohort discipline. Pre-existing baseline noise on Optional+take.swift accepted with commit-message citation per dispatch's refined triple-toolchain rule (no NEW regressions; pre-existing documented baseline failures MAY be accepted; MUST NOT silently expand scope).

No tags. No scope expansion to other packages without further authorization.

The empirical call-site mechanism documented in §B (Swift's implicit `inout T` → `UnsafeMutableRawPointer` conversion at call-argument boundary admits `~Escapable T`) is *not* a new institute-wide design vocabulary — it is an existing Swift compiler feature, used here for the first time in the corpus. Documenting it in this per-package note is sufficient; no institute-wide research doc needed (per supervisor C carry-forward: "No institute-wide note unless Phase 1 surfaces a non-derivative design choice").

## Appendix A — Empirical compile probe (2026-05-09)

Verified via `xcrun swiftc -typecheck -enable-experimental-feature Lifetimes -enable-experimental-feature LifetimeDependence` on Swift 6.3.1:

```swift
struct NEResource: ~Copyable, ~Escapable {
    var id: Int
    @_lifetime(immortal)
    init(_ id: Int) { self.id = id }
}

// Mock the new Property.Inout init shape composed through Tagged + Ownership.
struct Tagged<Tag, Underlying: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    var underlying: Underlying
    @_lifetime(copy underlying)
    init(_unchecked underlying: consuming Underlying) { self.underlying = underlying }
}

enum Ownership {}

extension Ownership {
    struct Inout<Value: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
        let _pointer: UnsafeMutableRawPointer
    }
}

extension Ownership.Inout where Value: ~Copyable & ~Escapable {
    @unsafe
    @inlinable
    @_lifetime(&owner)
    init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeMutableRawPointer,
        mutating owner: inout Owner
    ) { unsafe (self._pointer = pointer) }
}

struct PropertyInout<Tag, Base: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    var _storage: Tagged<Tag, Ownership.Inout<Base>>
}

extension PropertyInout where Base: ~Copyable & ~Escapable {
    @unsafe
    @inlinable
    @_lifetime(&owner)
    init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeMutableRawPointer,
        mutating owner: inout Owner
    ) {
        self._storage = Tagged(_unchecked: unsafe Ownership.Inout(unsafeRawAddress: pointer, mutating: &owner))
    }
}
```

Typechecks clean with no diagnostics. The Tagged + Ownership.Inout composition through the new init works as designed.

Consumer call-site shape probe (also typechecks clean):

```swift
extension NEResource {
    var asRef: PropertyInout<Tag, NEResource> {
        @_lifetime(&self)
        mutating _read {
            yield unsafe PropertyInout(unsafeRawAddress: &self, mutating: &self)
        }
    }
}
```

The `&self` argument in `unsafeRawAddress:` position implicitly converts `inout NEResource` to `UnsafeMutableRawPointer` at the call boundary, despite `NEResource: ~Escapable`.

## References

- Institute-wide DECISION: `swift-institute/Research/property-ownership-escapable-base-upgrade.md` (v1.0.0)
- Cohort canonical pattern: `swift-institute/Research/escapable-support-pair-either-product.md` (v1.1.0)
- Ecosystem state: `swift-institute/Research/nonescapable-ecosystem-state.md` (DECISION, 2026-04-02)
- Foundational design: `swift-property-primitives/Research/property-type-family.md` (IMPLEMENTED, 2026-01-21)
- Predecessor execution note (this dispatch's trigger documented at §L): `swift-property-primitives/Research/escapable-base-upgrade.md` (CONVERGED v1.0.0, 2026-05-09)
- Upstream precedent: `swift-ownership-primitives/Research/escapable-value-upgrade.md` (CONVERGED v1.0.0, 2026-05-09)
- Ownership.Inout precedent: `swift-ownership-primitives/Sources/Ownership Inout Primitives/Ownership.Inout.swift:113-139` (init(unsafeRawAddress:mutating:)); shipped at SHA `30f44a2` (2026-05-09)
- Ownership.Borrow precedent: `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Ownership.Borrow.swift:257-284` (init(unsafeRawAddress:borrowing:)); shipped at SHA `30f44a2`
- Ownership.Inout test (compile-time-admission shape): `swift-ownership-primitives/Tests/Ownership Primitives Tests/Ownership.Inout Tests.swift` `Inout~Escapable type-level admission via init(unsafeRawAddress:mutating:)`
- Tagged readiness: `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:55` (`Tag: ~Copyable & ~Escapable, Underlying: ~Copyable & ~Escapable`)
- Carrier readiness: `swift-carrier-primitives/Sources/Carrier Primitives/_CarrierProtocol.swift:26,36` (`~Copyable, ~Escapable`; `associatedtype Underlying: ~Copyable & ~Escapable`)
- Memory: `copypropagation-nonescapable-fix.md`, `pack-expand-on-consuming-param-property.md` (no application here), `feedback_escapable_over_with_closures.md`
- Active dispatch: `HANDOFF-property-inout-raw-address-init-cascade.md`
- Sibling cohort handoff (substantively closed): `HANDOFF-escapable-cohort-followups.md` Item B Candidate 2 — this dispatch closes the parked Candidate 2 deferral
- Predecessor detour (superseded): `HANDOFF-property-primitives-escapable-upgrade.md`
