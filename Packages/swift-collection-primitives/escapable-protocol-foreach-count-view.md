# Collection.Protocol ~Escapable Admission: ForEach Re-Derivation + Count.View Widening

<!--
---
version: 1.2.0
last_updated: 2026-05-09
status: DEFERRED-TOOLCHAIN-PRUNED
tier: 1
scope: per-package
preceded_by:
  - swift-institute/Research/property-ownership-escapable-base-upgrade.md (DECISION v1.0.0, 2026-05-09) — institute-wide rationale for the Property + Ownership cascade that unblocks this widening
  - swift-property-primitives/Research/property-inout-raw-address-init.md (CONVERGED-PRUNED v1.1.0, 2026-05-09) — upstream Phase 2 PUSH #1 supplying the new construction APIs this widening consumes; pruned out of Sources/+Tests/ at swift-property-primitives `8ea61bb` (research preserved verbatim)
  - swift-property-primitives/Research/escapable-base-upgrade.md (CONVERGED-PRUNED v1.1.0, 2026-05-09) — Property type-level Base widening; pruned out of Sources/+Tests/ at swift-property-primitives `8ea61bb` (research preserved verbatim)
  - swift-ownership-primitives/Research/escapable-value-upgrade.md (CONVERGED v1.0.0, 2026-05-09) — Ownership.Inout Value widening (shipped at 30f44a2; NOT pruned — institute ~Escapable program retains this)
  - swift-institute/Research/escapable-support-pair-either-product.md (DECISION v1.1.0, 2026-05-09) — canonical cohort pattern
  - swift-institute/Research/nonescapable-ecosystem-state.md (DECISION, 2026-04-02) — ecosystem readiness (UnsafeMutablePointer Escapable constraint)
toolchains_verified:
  - Swift 6.3.1 (Xcode 26.4.1 default)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a (`org.swift.64202605071a`)
  - Swift 6.4-dev/Embedded
trigger: Cohort cascade Item B Candidate 2 — widening `Collection.Protocol`'s `forEach` accessor and `count` accessor to admit `Self: ~Copyable & ~Escapable`. Type-level admission shipped at swift-property-primitives 5bb2f67 (Property<Tag, Base> Base admits ~Escapable) but the functional construction path required additional raw-address-form inits (this package's upstream — swift-property-primitives Phase 2 PUSH #1 from `property-inout-raw-address-init.md`). Working-tree parked diff has the where-clause widenings on Collection.Protocol / Collection.Protocol+ForEach / Collection.Protocol+defaults / Collection.Count and is failing to compile until the new APIs land.
---
-->

## Context

The 2026-05-09 Property + Ownership cascade (`property-ownership-escapable-base-upgrade.md` v1.0.0) closed the type-level admission of `~Escapable Base` in `Property<Tag, Base>`. The parent cohort's parked Item B Candidate 2 — widening `Collection.Protocol`'s `forEach` accessor to admit `Self: ~Copyable & ~Escapable` — was diagnosed at the cohort's Phase 0.5 to require BOTH the type-level admission AND a functional construction path for `Property.Inout` whose existing `init(_ base: inout Base)` is gated by `Ownership.Inout(mutating:)` requiring Escapable. The cohort rolled back, parked the changes in working-tree, and dispatched two follow-on works:

1. The upstream `swift-property-primitives` Phase 2 PUSH #1 (this dispatch's prerequisite, `property-inout-raw-address-init.md`) — adds `init(unsafeRawAddress:mutating:)` / `init(unsafeRawAddress:borrowing:)` across all 7 Property.{Inout,Borrow}[.Typed[.Valued[.Valued]]] variants in `where Base: ~Copyable & ~Escapable` extensions.
2. THIS doc — the downstream `swift-collection-primitives` Phase 2 PUSH #2 — re-derives the parked widening using the new APIs and adds Collection.Count.View widening (the Count accessor's storage type).

Pre-flight verified 2026-05-09 at HEAD `e72ad2a`:

- Origin/main clean: `swift test` baseline (parked working-tree changes stashed): tests pass; build clean.
- Working-tree parked changes (4 files): `Collection.Protocol.swift` widens protocol from `~Copyable` to `~Copyable, ~Escapable`; `Collection.Protocol+ForEach.swift` widens extension where-clause to `Self: ~Copyable & ~Escapable`; `Collection.Protocol+defaults.swift` same widening; `Collection.Count.swift` same widening + Collection.Count.View remains at `Base: Collection.\`Protocol\` & ~Copyable` (NOT widened). With the parked changes applied, the build fails:
  - `Collection.Protocol+ForEach.swift:17` — `error: referencing initializer 'init(_:)' on 'Property.Inout' requires that 'Self' conform to 'Escapable'` (the `init(_ base: inout Base)` Escapable-implicit gating; resolved by upstream PUSH #1)
  - `Collection.Count.swift:17` — `error: type 'Self' does not conform to protocol 'Escapable'` (Collection.Count.View's `<Base: Collection.Protocol & ~Copyable>` constraint rejects ~Escapable Self; resolved by THIS dispatch's Count.View widening)
- Working-tree `Audits/audit.md` Deferred Capabilities entry cites this dispatch as the trigger to revisit.

## Question

What is the file-level shape of the Collection.Protocol ~Escapable admission cascade — Collection.Protocol+ForEach re-derivation against the new Property.Inout construction API, Collection.Count.View structural rewrite admitting ~Escapable Base, the two ride-along where-clause widenings, NEResource test fixture additions — that admits `Self: ~Copyable & ~Escapable` conformers across the protocol's accessor surface while preserving the existing `Self: ~Copyable` (Escapable-implicit) public API?

## Analysis

### A. Bucket inventory — recap of Phase 0 supervisor-approved scope

Two files need new construction APIs (bucket b):

1. **Collection.Protocol+ForEach.swift** — Calls `Property.Inout(&self)` from a `mutating _read` accessor on `Self: ~Copyable & ~Escapable`. Upstream PUSH #1 supplies the `init(unsafeRawAddress:mutating:)` API that admits ~Escapable Self.
2. **Collection.Count.swift** — Collection.Count.View has its OWN raw-storage (`UnsafeMutablePointer<Base>` in `where Base: Collection.\`Protocol\` & ~Copyable`); needs structural rewrite mirroring the Ownership.Inout precedent.

Two files ride along with pure where-clause widening (no construction-API need):

3. **Collection.Protocol.swift** — Protocol-level `~Copyable` → `~Copyable, ~Escapable` widening.
4. **Collection.Protocol+defaults.swift** — Extension where-clause widening on the `isEmpty` / `formIndex(after:)` defaults.

These four files together compose the parked Item B Candidate 2 working-tree state. No other files need changes (Phase 0 survey across 153 external consumer files returned zero non-parked bucket-(b) consumers; supervisor confirmed: "Survey gate per [SUPER-022] satisfied — the working-tree audit's Deferred Capabilities entry citing this dispatch is the closing evidence that the parked Item B Candidate 2 IS the entirety of the migration set.").

### B. Collection.Protocol+ForEach re-derivation — uses new Property.Inout init

#### Current (parked, failing to compile)

```swift
public import Property_Primitives

extension Collection.`Protocol` where Self: ~Copyable & ~Escapable {
    @inlinable
    public var forEach: Property<Collection.ForEach, Self>.Inout {
        mutating _read {
            yield Property<Collection.ForEach, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Collection.ForEach, Self>.Inout(&self)
            yield &accessor
        }
    }
}
```

The two `Property<…>.Inout(&self)` calls invoke the existing `init(_ base: inout Base)` which is in `extension Property.Inout where Base: ~Copyable` (Escapable implicit). For `Self: ~Copyable & ~Escapable`, that init is not visible.

#### Proposed (re-derived against the new API)

```swift
public import Property_Primitives

extension Collection.`Protocol` where Self: ~Copyable & ~Escapable {
    @inlinable
    public var forEach: Property<Collection.ForEach, Self>.Inout {
        @_lifetime(&self)
        mutating _read {
            yield unsafe Property<Collection.ForEach, Self>.Inout(unsafeRawAddress: &self, mutating: &self)
        }
        @_lifetime(&self)
        mutating _modify {
            var accessor = unsafe Property<Collection.ForEach, Self>.Inout(unsafeRawAddress: &self, mutating: &self)
            yield &accessor
        }
    }
}
```

Three modifications:

1. **Init switches** to the new `init(unsafeRawAddress:mutating:)` from upstream PUSH #1.
2. **`&self` in `unsafeRawAddress:` argument position** — Swift's implicit `inout T` → `UnsafeMutableRawPointer` conversion at call boundary admits `~Escapable T` (verified empirically at `swift-property-primitives/Research/property-inout-raw-address-init.md` §B). The `mutating: &self` argument anchors the `@_lifetime(&owner)` lifetime dependency.
3. **`@_lifetime(&self)` on the accessor** — required because the `mutating _read` / `_modify` returns a `~Escapable` result (`Property.Inout` is `~Escapable`). Without the annotation, the compiler emits `error: a mutating method with a ~Escapable result requires '@_lifetime(...)'`. The annotation matches the lifetime-anchor pattern from `escapable-base-upgrade.md` §I.
4. **`unsafe` expression marker** — required by the `@unsafe`-tagged new init.

### C. Collection.Count.swift widening — Option A structural rewrite

The Q2 supervisor directive: "Yes, mutating-form. `init(unsafeRawAddress: UnsafeMutableRawPointer, mutating owner: inout Owner)` mirrors existing `UnsafeMutablePointer<Base>` storage mutability and matches the through-pointer write in `.index(after:)`. […] Phase 1 design doc MUST cite the through-pointer write site at line/column to make the mutability rationale auditable."

**Through-pointer mutability evidence at site (Collection.Count.swift, current parked state)**:

| Line | Code | Mutation classification |
|------|------|-------------------------|
| 18 | `mutating _read { yield unsafe Collection.Count.View(&self) }` | The accessor itself is `mutating _read`. The construction site takes `&self` (an `inout` reference), and the View's storage type is `UnsafeMutablePointer<Base>` — load-bearing evidence for mutating-form: the storage was authored as mutable (not `UnsafePointer<Base>`). |
| 83 | `var index = unsafe base.pointee.startIndex` | Read of `pointee` (UnsafeMutablePointer's `_modify`-coroutine accessor). Even when the access is read-only, `_modify`-yielded references admit write-back; the optimizer treats `pointee` access as potentially mutating the pointee region, consistent with the storage's mutable typing. |
| 84 | `let endIndex = unsafe base.pointee.endIndex` | Same. |
| 86 | `if predicate(unsafe base.pointee[index]) { count += .one }` | Same — subscript through `pointee`. |
| 87 | `index = unsafe base.pointee.index(after: index)` | Same. The `.index(after:)` method on `Collection.Protocol` is non-mutating but is invoked through `pointee`-yielded reference. The mutating-form storage admits any future Collection.Protocol operation that requires mutable access (e.g., a hypothetical `mutating func index(after:)` for in-place index advancement on iterator-shaped collections). |
| 103-107 | `.all` accessor (same shape as `.where`) | Same pattern. |

The supervisor's framing is supported: the existing `UnsafeMutablePointer<Base>` storage (Collection.Count.swift:55) is the load-bearing evidence for mutating-form. Through-pointer access via `.pointee.{startIndex, endIndex, [position], index(after:)}` flows through the `_modify` coroutine accessor of `UnsafeMutablePointer<Base>.pointee`, preserving write-back capability even when the immediate accesses happen to be reads. Switching to `UnsafePointer<Base>` (read-only) would tighten the contract; this dispatch holds tight to the existing mutating shape and rewrites the storage to `UnsafeMutableRawPointer` — verbatim Ownership.Inout precedent.

Borrow-form (`UnsafeRawPointer` + `borrowing owner: borrowing Owner`) would be the more conservative shape if `.index(after:)` on Collection.Protocol were declared a pure read-only contract; picking it now would be a tightening change separately motivated. Filed as Option B deferred follow-up — see §F.

#### Current (parked, failing to compile)

```swift
public import Index_Primitives

extension Collection.`Protocol` where Self: ~Copyable & ~Escapable {
    public var count: Collection.Count.View<Self> {
        mutating _read {
            yield unsafe Collection.Count.View(&self)
        }
    }
}

extension Collection {
    public enum Count {}
}

extension Collection.Count {
    @safe
    public struct View<Base: Collection.`Protocol` & ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Base>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }

        @inlinable
        public var base: UnsafeMutablePointer<Base> { unsafe _base }
    }
}

extension Collection.Count.View {
    @inlinable
    public func `where`(_ predicate: (borrowing Base.Element) -> Bool) -> Index<Base.Element>.Count {
        var count = Cardinal.zero
        var index = unsafe base.pointee.startIndex
        let endIndex = unsafe base.pointee.endIndex
        while index < endIndex {
            if predicate(unsafe base.pointee[index]) { count += .one }
            index = unsafe base.pointee.index(after: index)
        }
        return Index<Base.Element>.Count(_unchecked: count)
    }

    @inlinable
    public var all: Index<Base.Element>.Count {
        // (same shape)
    }
}
```

#### Proposed (Option A — verbatim Ownership.Inout precedent)

```swift
public import Index_Primitives

extension Collection.`Protocol` where Self: ~Copyable & ~Escapable {
    public var count: Collection.Count.View<Self> {
        @_lifetime(&self)
        mutating _read {
            yield unsafe Collection.Count.View(unsafeRawAddress: &self, mutating: &self)
        }
    }
}

extension Collection {
    public enum Count {}
}

extension Collection.Count {
    @safe
    public struct View<Base: Collection.`Protocol` & ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _pointer: UnsafeMutableRawPointer
    }
}

// Existing typed init — preserved at narrower constraint (Escapable-implicit).
extension Collection.Count.View where Base: Collection.`Protocol` & ~Copyable {
    /// Creates a count view from a typed pointer.
    ///
    /// Only available when `Base: Escapable` — `UnsafeMutablePointer<Base>`
    /// requires `Base: Escapable`. ~Escapable Base constructs via
    /// ``init(unsafeRawAddress:mutating:)`` in the `~Escapable`-admitting extension.
    @inlinable
    @_lifetime(borrow base)
    public init(_ base: UnsafeMutablePointer<Base>) {
        unsafe _pointer = UnsafeMutableRawPointer(base)
    }
}

// New raw-address init — admits ~Escapable Base.
extension Collection.Count.View where Base: Collection.`Protocol` & ~Copyable & ~Escapable {
    /// Unsafely creates a count view using a raw address, with lifetime
    /// based on the mutating owner.
    ///
    /// This is the only construction path available when `Base` is `~Escapable`,
    /// because stdlib's typed `UnsafeMutablePointer<Base>` requires `Base: Escapable`.
    /// Mirrors `Ownership.Inout.init(unsafeRawAddress:mutating:)` (the
    /// underlying storage init pattern).
    ///
    /// - Parameters:
    ///   - pointer: The raw address of the value to view.
    ///   - owner: The owning instance whose mutation scope bounds this view.
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

// Value access — gated where Base: Escapable (per Ownership.Inout precedent).
extension Collection.Count.View where Base: Collection.`Protocol` & ~Copyable {
    @inlinable
    public var base: UnsafeMutablePointer<Base> {
        unsafe _pointer.assumingMemoryBound(to: Base.self)
    }
}

extension Collection.Count.View where Base: Collection.`Protocol` & ~Copyable {
    @inlinable
    public func `where`(_ predicate: (borrowing Base.Element) -> Bool) -> Index<Base.Element>.Count {
        // Body unchanged — base.pointee.* path now goes through assumingMemoryBound coercion.
        // Operations are identical; just the storage type underneath changed.
        var count = Cardinal.zero
        var index = unsafe base.pointee.startIndex
        let endIndex = unsafe base.pointee.endIndex
        while index < endIndex {
            if predicate(unsafe base.pointee[index]) { count += .one }
            index = unsafe base.pointee.index(after: index)
        }
        return Index<Base.Element>.Count(_unchecked: count)
    }

    @inlinable
    public var all: Index<Base.Element>.Count {
        var count = Cardinal.zero
        var index = unsafe base.pointee.startIndex
        let endIndex = unsafe base.pointee.endIndex
        while index < endIndex {
            count += .one
            index = unsafe base.pointee.index(after: index)
        }
        return Index<Base.Element>.Count(_unchecked: count)
    }
}
```

Five structural changes (in dependency order):

1. **Type-level Base widening**: `View<Base: Collection.\`Protocol\` & ~Copyable>` → `View<Base: Collection.\`Protocol\` & ~Copyable & ~Escapable>`.
2. **Storage rewrite**: `internal let _base: UnsafeMutablePointer<Base>` → `internal let _pointer: UnsafeMutableRawPointer`. Field renamed from `_base` to `_pointer` to match Ownership.Inout's naming convention (`Ownership.Inout.swift:51`).
3. **Init split**: existing `init(_ base: UnsafeMutablePointer<Base>)` relocated from struct body into `extension Collection.Count.View where Base: Collection.\`Protocol\` & ~Copyable` (Escapable-implicit, gating preserved by typed pointer parameter). New `init(unsafeRawAddress:mutating:)` in `extension Collection.Count.View where Base: Collection.\`Protocol\` & ~Copyable & ~Escapable`.
4. **Value access switch**: `var base: UnsafeMutablePointer<Base>` accessor body changes from direct return to `unsafe _pointer.assumingMemoryBound(to: Base.self)`. Stays gated `where Base: ~Copyable` (Escapable-implicit) because `assumingMemoryBound(to:)` returns `UnsafeMutablePointer<Base>` which requires `Base: Escapable`. Body of `.where` and `.all` unchanged in form (still `base.pointee.*`); only the underlying retrieval through `assumingMemoryBound` changes.
5. **`Collection.Protocol+ForEach.swift`-style call-site update**: The `count` accessor in the Collection.\`Protocol\` extension switches to the new init, gains `@_lifetime(&self)`, uses `&self` for the raw-address argument and `&self` for the mutating owner.

The `Collection.Count.View` case mirrors the Ownership.Inout structural rewrite step-for-step (compare `swift-ownership-primitives/Research/escapable-value-upgrade.md` §B–§D). No novel design — verbatim precedent application.

### D. Ride-along where-clause widenings — no construction-API need

`Collection.Protocol.swift` widens the protocol declaration:

```swift
// Before
public protocol `Protocol`: ~Copyable {
    associatedtype Element: ~Copyable
    // …
}

// After
public protocol `Protocol`: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    // …
}
```

`Collection.Protocol+defaults.swift` widens its extension where-clause:

```swift
// Before
extension Collection.`Protocol` where Self: ~Copyable {
    @inlinable public var isEmpty: Bool { startIndex == endIndex }
    @inlinable public func formIndex(after i: inout Index) { i = index(after: i) }
}

// After
extension Collection.`Protocol` where Self: ~Copyable & ~Escapable {
    @inlinable public var isEmpty: Bool { startIndex == endIndex }
    @inlinable public func formIndex(after i: inout Index) { i = index(after: i) }
}
```

Both pure where-clause widenings — no construction-API consumed; no additional `@_lifetime` annotations needed (`isEmpty` and `formIndex(after:)` return Escapable types and don't construct ~Escapable values).

### E. Test additions

Mirroring the cohort fixture pattern:

```swift
struct NEContainer: Collection.`Protocol`, ~Copyable, ~Escapable {
    @_lifetime(immortal)
    init() {}
    var startIndex: Index<Int> { .zero }
    var endIndex: Index<Int> { .zero }
    subscript(_ position: Index<Int>) -> Int { 0 }
    func index(after i: Index<Int>) -> Index<Int> { i }
}
```

Test coverage targets:

| Test (proposed name) | What it verifies |
|----------------------|------------------|
| `Collection.Protocol+ForEach admits ~Copyable & ~Escapable Self` | Compile-time admission of forEach accessor on NEContainer |
| `Collection.Count.View admits ~Copyable & ~Escapable Base` | Compile-time admission of Count.View on NEContainer |
| `Collection.Protocol+defaults admits ~Copyable & ~Escapable Self` | Compile-time admission of isEmpty / formIndex on NEContainer |
| `Collection.Count.View Copyable Base path unchanged` | Existing typed init still works via `extension Collection.Count.View where Base: Collection.Protocol & ~Copyable` |
| `Collection.Count.View ~Copyable Escapable Base regression guard` | Existing path with ~Copyable Escapable container (e.g., a moved-in Array.Static) still works |

Tests live in `Tests/Collection Primitives Tests/` per existing per-target organization (per supervisor Q3).

### F. Option B as deferred follow-up

The supervisor explicitly preserved Option B (replace Collection.Count.View's raw storage with `Tagged<…, Ownership.Borrow<Base>>`) as a deferred follow-up:

| Dimension | Option A (this dispatch) | Option B (deferred) |
|-----------|--------------------------|---------------------|
| Diff size | Minimal — verbatim Ownership.Inout precedent application | Larger — replaces raw storage with Property/Ownership composition |
| Public API surface | Preserved — existing `init(_ base: UnsafeMutablePointer<Base>)` and `var base: UnsafeMutablePointer<Base>` stay (gated `where Base: ~Copyable`) | Changed — typed `UnsafeMutablePointer<Base>` storage replaced with `Ownership.Borrow<Base>` |
| Mutability semantics | Mutating-form (matches existing storage type) | Borrow-form (tightening — assumes `.where` / `.all` are pure read-only) |
| Triggers to revisit | If a future audit decides Collection.Count.View should align with Property/Ownership conventions, OR if `.index(after:)` on Collection.Protocol is ever declared a pure read-only contract requiring `UnsafePointer<Base>` storage | TBD |

Option B's trigger condition is not surfaced in this dispatch; defer to a future audit driven by ecosystem-wide convention alignment work.

### G. File-modification summary

| File | Change kind | Lines (estimate) |
|------|-------------|------------------|
| `Sources/Collection Primitives/Collection.Protocol.swift` | Protocol-level `~Copyable` → `~Copyable, ~Escapable` widening | ~1 line |
| `Sources/Collection Primitives/Collection.Protocol+defaults.swift` | Where-clause widening | ~1 line |
| `Sources/Collection Primitives/Collection.Protocol+ForEach.swift` | Switch to new Property.Inout API; add `@_lifetime(&self)` annotations; add `unsafe` marker | ~6 lines |
| `Sources/Collection Primitives/Collection.Count.swift` | Type-level Base widening; storage rewrite; init split (existing → narrower extension; new init → wider extension); value access switch via assumingMemoryBound; `count` accessor switches to new construction API | ~30 lines |
| `Tests/Collection Primitives Tests/*` | NEContainer fixture + 5 admission/regression tests | +~80 lines |
| `Audits/audit.md` Deferred Capabilities entry | Update Status from OPEN to RESOLVED with this dispatch's commit SHA (post-Phase-2-PUSH-#2) | +1 line |
| `Package.swift` | Unchanged (Lifetimes already enabled) | 0 |

**Total: ~38 net new/changed lines across 4 source files; ~80 new test lines.**

### H. Per-toolchain expectations + cascade-execution-order

`Lifetimes` and `LifetimeDependence` features already enabled in `Package.swift`. No `Package.swift` changes required.

This package is the downstream cascade entry — Phase 2 PUSH #2 — gated on `swift-property-primitives` Phase 2 PUSH #1 (`property-inout-raw-address-init.md`) landing first. The new `Property.Inout.init(unsafeRawAddress:mutating:)` API is a hard precondition.

Triple-toolchain verification before push, per dispatch ground rule. Refined rule: NO NEW regressions; pre-existing baseline noise on swift-property-primitives' Optional+take.swift (Swift 6.4-dev nightly + Embedded) is documented and accommodated by upstream CI policy; `swift-collection-primitives` may inherit the same baseline noise transitively. Cite in commit message; do NOT bundle a fix.

### I. Cohort hand-back trail

Per the dispatch's `MUST` + per supervisor verification gate, after Phase 3 cascade-verification confirms Phase 2 PUSH #2 lands cleanly with no NEW regressions, append a hand-back note to `HANDOFF-escapable-cohort-followups.md` § Hand-back documenting Item B Candidate 2 fully cleared. Reference (a) the upstream PUSH #1 commit SHA, (b) this dispatch's PUSH #2 commit SHA, (c) the two research docs (`property-inout-raw-address-init.md`, this doc).

Update the working-tree `Audits/audit.md` Deferred Capabilities entry from OPEN to RESOLVED with the same SHAs and a back-link to the closing note.

## J. Structural blocker discovered at Phase 2 (2026-05-09 v1.1.0 amendment)

**The dispatched design's runtime call-site pattern is uncompilable.**

Phase 2 PUSH #2 attempted to re-derive `Collection.Protocol+ForEach.swift` against the new `Property.Inout.init(unsafeRawAddress:mutating:)` API per §B's "current vs proposed" specification. Real-code build of:

```swift
@_lifetime(&self)
mutating _read {
    yield unsafe Property<Collection.ForEach, Self>.Inout(unsafeRawAddress: &self, mutating: &self)
}
```

Fails with:

```
error: overlapping accesses to 'self', but modification requires exclusive access
       [#ExclusivityViolation]
       at unsafeRawAddress: &self, mutating: &self
error: lifetime-dependent variable 'self' escapes its scope
       note: error in compiler-generated '_read'
```

Same failure on Collection.Count.swift's analogous `count` accessor.

**Root cause** (verified via `xcrun swiftc -emit-sil` on a minimal NEResource-shaped probe):

The new init signature requires TWO arguments that both demand exclusive access to `self`:

- `unsafeRawAddress: &self` — implicit `inout T` → `UnsafeMutableRawPointer` conversion at call boundary takes an exclusive borrow.
- `mutating: &self` — explicit `inout` parameter takes an exclusive borrow.

Swift's exclusive-access law forbids this composition. Compounding the issue, the implicit `inout T → UnsafeMutableRawPointer` conversion produces a CALL-BOUNDARY-SCOPED pointer that dies on function return — so even if exclusivity were waived, storing it in the constructed `Property.Inout`'s `_pointer` field would create a dangling reference.

**Why §B's empirical "verification" was a false positive**

The Phase 1 verification used `xcrun swiftc -typecheck`. Type-checking does NOT run borrow-check or SIL generation. The borrow-check rejection (and the dangling-pointer detection) happens at SIL generation. **The verification methodology was insufficient.** The runtime call-site pattern claimed in §B was never structurally verified. `swiftc -emit-sil` on the same probe shape now confirms the failure.

**Bounded Option B probe (≤30 min, supervisor-authorized 2026-05-09)**

Investigated alternative API shapes; none compiled. Probes (each verified via `swiftc -emit-sil`):

| # | Hypothesis | Result |
|---|---|---|
| 1 | Closure-yielding-pointer factory (`with(_:body:)` pattern) | dangling pointer + lifetime escape |
| 2 | `_modify` coroutine + single-borrow | requires getter/read pair (Swift structural) |
| 3 | Single-arg init taking only raw pointer (no `mutating: &self`) | lifetime escape (no inout anchor) |
| 4 | `@_addressableForDependencies` on parameter | attribute can't be applied to declarations |
| 5 | `@_addressable` on type/parameter | wrong placement (type-attribute, not declaration) |
| 6 | `MutableRawSpan` stdlib bridge from inout | no facility admits ~Escapable inout |
| 7 | Direct inout→`UnsafeMutableRawPointer` derivation in init body | pointer is body-scoped, dies at call return |

No viable shape exists in current Swift toolchains (6.3.1 + 6.4-dev nightly 2026-05-07-a). Producing a stable raw pointer to ~Escapable inout in user-package code requires `Builtin.addressOfBorrow` or equivalent — accessible only from stdlib internals, not user packages.

## K. What PUSH #1 still delivers (the surviving scope)

The 7 new init signatures shipped at swift-property-primitives `be0e3a2` ARE compile-time-admission-correct. The admission tests pass (closure literals reference the new init's signature with separate `(storage, owner)` values; never invoked at runtime — matching the Ownership precedent's test shape verbatim). The new inits remain valid for any future ~Escapable consumer where the raw pointer is acquired from a non-self source: a pre-existing `UnsafeMutableRawPointer` field, kernel memory, file-mapped storage, or any external pointer source independent of the inout owner.

The structural gap is the **view-of-self consumer pattern** — `Property<...>.Inout(unsafeRawAddress: &self, mutating: &self)` from a `mutating _read` accessor. This pattern is what Item B Candidate 2 needs and what's currently uncompilable.

## L. Prune-Outcome (v1.2.0 amendment, 2026-05-09)

**Trigger**: Supervisor dispatch `HANDOFF-escapable-property-tier-prune.md` (2026-05-09) — surgical prune of the Property + Collection tier of the cascade.

**Reasoning**: §K's "surviving scope for non-self-derived raw-pointer consumers" is structurally hypothetical. Property's value-add over raw `Ownership.{Inout,Borrow}` IS the view-of-self fluent accessor pattern (the `extension Buffer { var insert: Property<Insert>.Inout { mutating _read { yield .init(&self) } } }` shape that names a verb namespace at the call site). With that pattern uncompilable for ~Escapable Self under the structural blocker in §J, the upstream's 7 raw-address-form inits + their admission tests no longer carry runtime value-add over the existing `init(_ base: inout Base)` overload (Escapable-implicit, all use sites). Keeping them in Sources/+Tests/ accumulates surface area without exercising any consumer path.

**Action taken at swift-property-primitives** (`8ea61bb`, 2026-05-09):

- Reverted Sources/ + Tests/ to pre-cascade `49dce56` baseline (the parent cohort's pre-Phase-2 state). 7 init signatures + 7 admission tests + supporting code removed from compilation.
- Test count: 48/48 passes at `8ea61bb` (matches `49dce56` baseline; v1.0.0's working-tree numbers of 41 in dispatch text were writer-side miscalculation — empirically 48 was always the baseline).
- Triple-toolchain green at `8ea61bb`: Swift 6.3.1 + Swift 6.4-dev nightly 2026-05-07-a + Swift 6.4-dev/Embedded.
- Research preserved verbatim with frontmatter status amended to `CONVERGED-PRUNED` (v1.0.0 → v1.1.0):
  - `swift-property-primitives/Research/property-inout-raw-address-init.md` — adds §Status block documenting what shipped, what got pruned, the re-ship trigger condition.
  - `swift-property-primitives/Research/escapable-base-upgrade.md` — adds analogous §Status block; cross-references property-inout-raw-address-init.md §Status for full rationale.
- Cohort hand-back trail (`HANDOFF-escapable-cohort-followups.md`, local-only) updated with prune SHA and rationale.

**Action taken at THIS package** (this v1.2.0 amendment, doc-only):

- Frontmatter status `DEFERRED-TOOLCHAIN` → `DEFERRED-TOOLCHAIN-PRUNED`; version 1.1.0 → 1.2.0.
- This §L amendment documents the upstream prune.
- `Research/_index.json` topic + statusDetail amended.
- `Audits/audit.md` (local-only per [AUDIT-002]) Deferred Capabilities entries amended `DEFERRED-TOOLCHAIN` → `DEFERRED-TOOLCHAIN-PRUNED`.
- **No source-file changes**. The 4 parked source-file changes at `e72ad2a` baseline were already reverted at v1.1.0's PUSH #2 (`2e60130`); v1.2.0 ships purely as research-status forward-amendment.

**What survives unchanged**:

- `swift-ownership-primitives 30f44a2` (Ownership.Inout Value admits ~Escapable) — institute ~Escapable program retains this; it carries independent value-add at the Ownership layer (raw-pointer storage was always Ownership's natural design point, not a hypothetical add).
- Cohort base + institute cohort protocols (`swift-institute/Research/escapable-support-pair-either-product.md` v1.1.0, `swift-institute/Research/property-ownership-escapable-base-upgrade.md` v1.0.0) — design rationale stays valid for the broader cascade.
- Research preserved verbatim at all four prune sites (this doc + 2 swift-property-primitives docs + the cross-package readiness audits in §F): design space, empirical findings, structural-blocker analysis, language-affordance trigger condition are load-bearing for future re-attempt when the toolchain ships the missing affordance.

**Re-ship trigger** (unchanged from §J/§K): a Swift toolchain user-package mechanism for raw-pointer derivation from inout self without dual-borrow violation (e.g., `Builtin.addressOfBorrow` exposed at user level, ~Escapable-admitting `withUnsafeMutablePointer` variant, `Reborrow<T>: ~Escapable`-style facility). Not a count trigger — a language-affordance trigger.

**Re-ship procedure when triggered**:

1. Re-apply `swift-property-primitives` cascade SHAs `5bb2f67` + `be0e3a2` + `9ee0c37` on top of the post-prune base.
2. Re-derive THIS package's parked Item B Candidate 2 (the 4 working-tree source files) using the new toolchain affordance instead of the dispatched `(unsafeRawAddress: &self, mutating: &self)` shape.
3. Verify view-of-self pattern via `swiftc -emit-sil` against an NEResource-shaped probe BEFORE Phase 1 design-doc claims compile-success (correcting v1.0.0's `swiftc -typecheck`-only verification methodology).

## Outcome

**Status**: DEFERRED-TOOLCHAIN-PRUNED (v1.2.0; v1.1.0 was DEFERRED-TOOLCHAIN; amended after upstream cascade-tail prune at swift-property-primitives `8ea61bb` per `HANDOFF-escapable-property-tier-prune.md`).

The Collection.Protocol ~Escapable admission cascade as designed in §B–§I cannot ship. The dispatched view-of-self consumer pattern is uncompilable under Swift's exclusive-access law on dual-`&self` arguments at the call boundary; combined with body-scoped lifetime of the implicit `inout T → UnsafeMutableRawPointer` conversion. No alternative API shape was found in the bounded Option B probe (Phase 2 §J).

v1.1.0's PUSH #2 (`2e60130`) shipped **doc-only**: design doc with §J–§K amendments + `Research/_index.json` registration. The 4 parked source-file changes documented as the design target in §B–§D were NOT shipped — reverted to baseline and the package returned to its pre-cohort `e72ad2a` state. v1.2.0 (this amendment) ships **doc-only** as well: §L Prune-Outcome + frontmatter status forward-amendment + `Research/_index.json` topic update; no source-file changes.

Item B Candidate 2 stays DEFERRED-TOOLCHAIN-PRUNED. Trigger condition for revisit (unchanged from v1.1.0):

> The Swift toolchain provides a user-package mechanism for raw-pointer derivation from inout self without dual-borrow violation. Plausible mechanisms: (a) `Builtin.addressOfBorrow` exposed at user level; (b) a new `~Escapable`-admitting `withUnsafeMutablePointer` variant; (c) a `Reborrow<T>: ~Escapable`-style language affordance; (d) a yet-unforeseen language feature.

This is not a count trigger; it is a language-affordance trigger. No deadline; reopen when the Swift project lands a relevant change.

The upstream `swift-property-primitives` cascade SHAs (`5bb2f67` Property Base widening; `be0e3a2` raw-address-form inits; `9ee0c37` corrective doc-only) were reverted out of Sources/+Tests/ at swift-property-primitives `8ea61bb` (2026-05-09) per the surgical-prune dispatch (see §L). Their research preserved verbatim with frontmatter status amended to `CONVERGED-PRUNED`. The corrective doc-comment update from v1.1.0 §J framing (about Property.Inout's misleading view-of-self example) is moot in the post-prune state — the new init signatures it documented no longer exist in source.

Option B (Property/Ownership composition rewrite of Collection.Count.View's storage) — preserved as deferred follow-up; trigger condition TBD as before. Independent of the structural blocker described in §J.

## References

- Institute-wide DECISION: `swift-institute/Research/property-ownership-escapable-base-upgrade.md` (v1.0.0)
- Cohort canonical pattern: `swift-institute/Research/escapable-support-pair-either-product.md` (v1.1.0)
- Ecosystem state: `swift-institute/Research/nonescapable-ecosystem-state.md` (DECISION, 2026-04-02)
- Upstream Phase 2 PUSH #1 (this dispatch's prerequisite): `swift-property-primitives/Research/property-inout-raw-address-init.md` (CONVERGED-PRUNED v1.1.0, 2026-05-09); shipped at `be0e3a2` + `9ee0c37`, pruned at `8ea61bb` (2026-05-09)
- Upstream type-level Property Base widening: `swift-property-primitives/Research/escapable-base-upgrade.md` (CONVERGED-PRUNED v1.1.0, 2026-05-09); shipped at SHA `5bb2f67`, pruned at `8ea61bb` (2026-05-09)
- Upstream Ownership.Inout Value widening: `swift-ownership-primitives/Research/escapable-value-upgrade.md` (CONVERGED v1.0.0, 2026-05-09); shipped at SHA `30f44a2` (2026-05-09; NOT pruned)
- Ownership.Inout precedent for Count.View storage rewrite: `swift-ownership-primitives/Sources/Ownership Inout Primitives/Ownership.Inout.swift` lines 36-53 (type decl + storage), 113-139 (raw-address init), 143-159 (assumingMemoryBound value access)
- Property.Inout new init (consumed by Collection.Protocol+ForEach re-derivation): `swift-property-primitives/Research/property-inout-raw-address-init.md` §C (Property.Inout subsection)
- Tagged readiness: `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:55`
- Carrier readiness: `swift-carrier-primitives/Sources/Carrier Primitives/_CarrierProtocol.swift:26,36`
- Memory: `pack-expand-on-consuming-param-property.md` (no application here), `feedback_escapable_over_with_closures.md`
- Active dispatch (v1.0.0 / v1.1.0): `HANDOFF-property-inout-raw-address-init-cascade.md`
- Active dispatch (v1.2.0 — surgical prune): `HANDOFF-escapable-property-tier-prune.md` (2026-05-09)
- Sibling cohort handoff (substantively closed; this dispatch closes its parked Item B Candidate 2): `HANDOFF-escapable-cohort-followups.md`
- Predecessor detour (superseded): `HANDOFF-property-primitives-escapable-upgrade.md`
- Working-tree `Audits/audit.md` Deferred Capabilities entry (this dispatch resolves)
