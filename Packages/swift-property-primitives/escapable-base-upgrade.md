# Property `~Escapable` Base Upgrade

<!--
---
version: 1.1.0
last_updated: 2026-05-09
status: CONVERGED-PRUNED
tier: 1
scope: per-package
preceded_by:
  - swift-institute/Research/property-ownership-escapable-base-upgrade.md (DECISION, 2026-05-09) — institute-wide rationale
  - swift-institute/Research/escapable-support-pair-either-product.md (DECISION v1.1.0, 2026-05-09) — canonical cohort pattern
  - swift-property-primitives/Research/property-view-escapable-removal.md (DECISION 2026-03-22, SUPERSEDED 2026-03-25 by restoration commit `43247e3`)
  - swift-property-primitives/Research/property-type-family.md (IMPLEMENTED, 2026-01-21) — foundational design
  - swift-ownership-primitives/Research/escapable-value-upgrade.md — upstream upgrade (lands first)
relates_to:
  - swift-property-primitives/Research/variant-decomposition-rationale.md
toolchains_verified:
  - Swift 6.3.1 (Xcode 26.4 default)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a (`org.swift.64202605071a`)
  - Swift 6.4-dev/Embedded
trigger: Cohort cascade Item B Candidate 2 — `Collection.Protocol`'s `forEach: Property<Collection.ForEach, Self>.Inout` accessor cannot admit `Self: ~Copyable & ~Escapable` because `Property<Tag, Base: ~Copyable>` constrains `Base` to implicit Escapable.
---
-->

## Status: CONVERGED-PRUNED (v1.1.0, 2026-05-09)

> The design analysis below CONVERGED in Phase 1 of `HANDOFF-property-primitives-escapable-upgrade.md` (the predecessor detour, superseded) and the type-level admission shipped at swift-property-primitives `5bb2f67`. The downstream functional-construction work shipped at `be0e3a2` + `9ee0c37` per the follow-on `HANDOFF-property-inout-raw-address-init-cascade.md`. The Property tier source was subsequently **PRUNED** by the surgical follow-up `HANDOFF-escapable-property-tier-prune.md` (2026-05-09): the type-level Base widening, the conditional-conformance discipline applied to Copyable/Sendable/Escapable extensions, the Property.Typed widening, and the Property.Consume Sendable adjustment were all reverted in a single new commit on top of `9ee0c37`, returning Sources/+Tests/ to the pre-cascade `49dce56` state.
>
> **Why pruned**: see the rationale in `property-inout-raw-address-init.md` §Status — Property's value-add over raw Ownership is structurally view-of-self-locked, and view-of-self is blocked at the Swift language level until a relevant affordance ships. The §L Phase-2 implementation refinement here (relocating struct-body inits to narrower Escapable-implicit extensions) was correct under the cascade's design assumptions but is moot under the prune.
>
> **What survives**: this research note, preserved on disk verbatim. The design space (§A–§K), the empirical Phase-2 verification (§M, 48/48 → 55/55 verified clean on triple-toolchain at the cascade SHAs), the conditional-conformance discipline mandated by the cohort canonical pattern, and the cross-package readiness audit (Tagged + Carrier already admit ~Escapable Underlying) are all load-bearing learnings that survive the source prune. When the Swift toolchain ships the missing language affordance, this note is the resume-from-here pointer.
>
> **What does not survive**: the type-level admission of `~Escapable Base` on `Property<Tag, Base>`, Property.Typed's matching widening, Property.Consume's adjusted conditional Sendable, the conditional Copyable/Sendable/Escapable extensions on the orthogonal axis, and the relocated struct-body inits from §L. All reverted out of Sources/+Tests/ as of the prune commit (post-`9ee0c37`).
>
> **What the broader institute program retains**: `swift-ownership-primitives` `30f44a2` (Ownership.Inout admits ~Escapable Value) is **not pruned** — see `property-inout-raw-address-init.md` §Status for the rationale.

## Context

`Property<Tag, Base>` is currently declared `public struct Property<Tag, Base: ~Copyable>: ~Copyable` (`Sources/Property Primitives Core/Property.swift:46`). `Base` is `~Copyable` only — `Escapable` is implicit. Consumers needing `Property<Tag, Self>.Inout` accessors on `Self: ~Copyable & ~Escapable` containers (e.g., `Collection.Protocol+ForEach.swift` in `swift-collection-primitives`) cannot instantiate Property because the outer constraint rejects `~Escapable` Base.

The original dispatch framing (`HANDOFF-property-primitives-escapable-upgrade.md` Upgrade 1: "Property.View family re-adoption of ~Escapable") is **already shipped** at HEAD `49dce56`:

- The Property.View family was renamed to Property.Inout / Property.Borrow / Property.Consume per commits `acec3c5` / `a372ee0` / `040c834` / `2e5bb61` / `5da7f17`.
- `~Escapable` was restored on the renamed types per commit `43247e3` (2026-03-25), reflected in commit `2a20349`.
- All 7 variants currently carry `~Copyable, ~Escapable` (Property.Inout.swift:66, Property.Borrow.swift:57, Property.Inout.Typed.swift:46, Property.Inout.Typed.Valued.swift:42, Property.Inout.Typed.Valued.Valued.swift:37, Property.Borrow.Typed.swift:44, Property.Borrow.Typed.Valued.swift:44).

The remaining live work is `Property<Tag, Base>`'s outer Base widening — the structural fix for the cohort's Item B Candidate 2 blocker.

Pre-flight (verified 2026-05-09 at HEAD `49dce56`):

- Working tree clean.
- `swift test` baseline: **48 tests in 48 suites passed** in 0.001s.
- Six subtargets in scope: Property Primitives Core (with `Property.swift` + `Property+Carrier.swift`), Property Inout Primitives (4 source files), Property Borrow Primitives (3 source files), Property Typed Primitives (1 source file), Property Consume Primitives (2 source files), Property Primitives umbrella (DocC catalog + re-exports).
- Tagged is `~Escapable`-ready (`Underlying: ~Copyable & ~Escapable`); Carrier.`Protocol` is `~Escapable`-ready (`Underlying: ~Copyable & ~Escapable`); Ownership.Inout requires upstream upgrade per `swift-ownership-primitives/Research/escapable-value-upgrade.md`.

## Question

What is the file-level shape of the Property `Base` widening — type declaration, conditional-conformance shape, per-subtarget extension where-clause cascade, Property.Typed widening DECISION, Property.Consume confirmation — that admits `Base: ~Copyable & ~Escapable` while preserving the existing Copyable Base contracts and the existing Property.Inout / Property.Borrow / Property.{Inout,Borrow}.Typed.* family at the public API boundary?

## Analysis

### A. Property core declaration (`Property.swift`)

| Element | Current (file:line) | Proposed |
|---------|---------------------|----------|
| Type declaration | `public struct Property<Tag, Base: ~Copyable>: ~Copyable {` (line 46) | `public struct Property<Tag, Base: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {` |
| `init(_ base: consuming Base)` (line 67) | unannotated | `@_lifetime(copy base)` |
| `extension Property where Base: ~Copyable { ... var base: Base ... }` (line 72) | `where Base: ~Copyable` | `where Base: ~Copyable & ~Escapable` |
| `extension Property: Copyable where Base: Copyable {}` (line 81) | `where Base: Copyable` | `where Base: Copyable & ~Escapable {}` |
| `extension Property: Sendable where Base: Sendable {}` (line 82) | `where Base: Sendable` | `where Base: Sendable & ~Copyable & ~Escapable {}` |
| (NEW) `extension Property: Escapable where Base: Escapable & ~Copyable {}` | n/a | NEW per cohort canonical pattern |

The `extension Property: Escapable where Base: Escapable & ~Copyable {}` declaration is mandated by the cohort's Empirical finding 1 (`escapable-support-pair-either-product.md` v1.1.0): when the type-level constraint is `~Copyable & ~Escapable`, every conditional `Copyable` / `Escapable` extension must be explicit on the orthogonal axis or the compiler emits `error: conditional conformance to 'Copyable' must explicitly state whether 'Base' is required to conform to 'Escapable' or not`.

`@_lifetime(copy base)` on `init(_ base: consuming Base)` is mandated by the cohort's Empirical finding 2 — `init` requires the annotation when the type is `~Escapable` and storage is owned (`var _base: Base`).

### B. Property+Carrier.swift

| Element | Current (file:line) | Proposed |
|---------|---------------------|----------|
| `extension Property: Carrier.\`Protocol\` where Base: ~Copyable` (line 24) | `where Base: ~Copyable` | `where Base: ~Copyable & ~Escapable` |
| `var underlying: Base { _read { yield _base } }` | unannotated | unchanged (Carrier.`Protocol`'s `var underlying` is already `~Escapable`-ready per `_CarrierProtocol.swift:36`) |

Carrier.`Protocol` already admits `~Escapable` Underlying (`_CarrierProtocol.swift:26,36`). The conformance widening cascades cleanly.

### C. Property.Typed (DECISION REQUIRED — per supervisor directive)

`Property.Typed.swift:40` — currently `public struct Typed<Element>: ~Copyable {` inside `extension Property where Base: ~Copyable`. Storage is `internal var _base: Base` (owned, line 44). Conformances at lines 77-78: `Copyable where Base: Copyable`, `Sendable where Base: Sendable`.

#### Decision: WIDEN Property.Typed to admit `Base: ~Copyable & ~Escapable`.

Rationale:

1. **Structural symmetry with Property.** Property.Typed is the property-extension-shaped sibling of Property (method-extension-shaped). Both store Base directly. If Property's Base widens, Property.Typed's storage becomes structurally inconsistent unless it also widens — Property.Typed is currently nested in `extension Property where Base: ~Copyable`, which after Property's widening becomes `extension Property where Base: ~Copyable & ~Escapable` (per §F below). Property.Typed under that extension scope must already accept `~Escapable` Base.

2. **Use case parity.** Property.Typed exists specifically to lift value-generic property accessors (`var peek: Property<Peek>.Typed<Element>`). Without `~Escapable` admission, `~Escapable` consumers cannot expose property-shaped peek accessors — only method-shaped ones via Property. This breaks the Property type family's symmetry per the foundational design (`property-type-family.md` §3 Pattern Taxonomy).

3. **Cohort precedent.** The cohort's Pair upgrade (`escapable-support-pair-either-product.md` v1.1.0) shows owned-storage type-level `~Escapable` upgrades are feasible with `@_lifetime(copy x)` on init. Pair stores `var first: First, var second: Second` directly — same shape as Property.Typed's `var _base: Base`.

4. **No structural blocker.** Property.Typed has the standard `_read`/`_modify` coroutine accessor (`var base: Base { _read { yield _base } _modify { yield &_base } }`, lines 71-74). The cohort doc empirically validates this pattern under Lifetimes for `~Escapable` Base.

#### Property.Typed concrete changes

| Element | Current (file:line) | Proposed |
|---------|---------------------|----------|
| Outer extension constraint | `extension Property where Base: ~Copyable {` (line 3) | `extension Property where Base: ~Copyable & ~Escapable {` |
| Type declaration | `public struct Typed<Element>: ~Copyable {` (line 40) | `public struct Typed<Element>: ~Copyable, ~Escapable {` |
| `init(_ base: consuming Base)` (line 62) | unannotated | `@_lifetime(copy base)` |
| Inner extension | `extension Property.Typed where Base: ~Copyable` (line 68) | `extension Property.Typed where Base: ~Copyable & ~Escapable` |
| `extension Property.Typed: Copyable where Base: Copyable` (line 77) | unchanged constraint | `where Base: Copyable & ~Escapable {}` |
| `extension Property.Typed: Sendable where Base: Sendable` (line 78) | unchanged constraint | `where Base: Sendable & ~Copyable & ~Escapable {}` |
| (NEW) `extension Property.Typed: Escapable where Base: Escapable & ~Copyable {}` | n/a | NEW per cohort canonical pattern |

### D. Property.Consume — confirmed: NO widening

Property.Consume is declared inside `extension Property where Base: Copyable {` (`Property.Consume.swift:3`). The declaration explicitly requires `Base: Copyable`. Internal `State` class stores `Base?` (Copyable-required for Optional storage). The construct's semantic — borrow-or-consume with restoration — depends on Copyable Base.

`Property.Consume`'s outer constraint stays `where Base: Copyable`. After Property's widening, the Copyable extension's where-clause cascades to `where Base: Copyable & ~Escapable` per the cohort's orthogonal-axis discipline. The `Sendable` conditional at line 157 follows: `where Base: Sendable` → `where Base: Sendable & ~Copyable & ~Escapable` is **incorrect** here (Property.Consume is Copyable-only by construction); the right form is `where Base: Sendable & ~Escapable`.

| Element | Current (file:line) | Proposed |
|---------|---------------------|----------|
| Outer extension constraint | `extension Property where Base: Copyable {` (line 3) | `extension Property where Base: Copyable & ~Escapable {` |
| `extension Property.Consume: Sendable where Base: Sendable {}` (line 157) | `where Base: Sendable` | `where Base: Sendable & ~Escapable {}` |

### E. Property.Inout / Property.Borrow / Property.{Inout,Borrow}.Typed.* — extension where-clause cascade

These types are already `~Copyable, ~Escapable` declarations. The widening cascade affects only their **outer extension constraint** (the `extension Property where Base: ~Copyable {` chain that scopes them).

| File | Outer extension (current) | Outer extension (proposed) |
|------|---------------------------|----------------------------|
| `Property Inout Primitives/Property.Inout.swift:5` | `extension Property where Base: ~Copyable {` | `extension Property where Base: ~Copyable & ~Escapable {` |
| `Property Inout Primitives/Property.Inout.swift:121` (inner extension) | `extension Property.Inout where Base: ~Copyable {` | `extension Property.Inout where Base: ~Copyable & ~Escapable {` |
| `Property Inout Primitives/Property.Inout.swift:136` (pointer helpers) | `extension Property where Base: ~Copyable {` | `extension Property where Base: ~Copyable & ~Escapable {` |
| `Property Inout Primitives/Property.Inout.Typed.swift:5` | `extension Property.Inout where Base: ~Copyable {` | `extension Property.Inout where Base: ~Copyable & ~Escapable {` |
| `Property Inout Primitives/Property.Inout.Typed.swift:61` | `extension Property.Inout.Typed where Base: ~Copyable, Element: ~Copyable {` | `extension Property.Inout.Typed where Base: ~Copyable & ~Escapable, Element: ~Copyable {` |
| `Property Inout Primitives/Property.Inout.Typed.Valued.swift:5,57` | `where Base: ~Copyable, Element: ~Copyable` | `where Base: ~Copyable & ~Escapable, Element: ~Copyable` |
| `Property Inout Primitives/Property.Inout.Typed.Valued.Valued.swift:5,52` | `where Base: ~Copyable, Element: ~Copyable` | `where Base: ~Copyable & ~Escapable, Element: ~Copyable` |
| `Property Borrow Primitives/Property.Borrow.swift:5,72` | `where Base: ~Copyable` | `where Base: ~Copyable & ~Escapable` |
| `Property Borrow Primitives/Property.Borrow.Typed.swift:5,59` | `where Base: ~Copyable, Element: ~Copyable` | `where Base: ~Copyable & ~Escapable, Element: ~Copyable` |
| `Property Borrow Primitives/Property.Borrow.Typed.Valued.swift:5,59` | `where Base: ~Copyable, Element: ~Copyable` | `where Base: ~Copyable & ~Escapable, Element: ~Copyable` |

Inside the Property.Inout / Property.Borrow nested types, `Tagged<Tag, Ownership.Inout<Base>>` and `Tagged<Tag, Ownership.Borrow<Base>>` storage requires Tagged's `Underlying: ~Copyable & ~Escapable` (already satisfied) and Ownership.Inout's `Value: ~Copyable & ~Escapable` (satisfied after the upstream upgrade lands per `swift-ownership-primitives/Research/escapable-value-upgrade.md`).

### F. Element parameter on Property.Inout.Typed / Property.Borrow.Typed

The `Element` parameter on `Property.{Inout,Borrow}.Typed<Element: ~Copyable>` (Property.Inout.Typed.swift:46, Property.Borrow.Typed.swift:44) is currently `~Copyable` only. Element is the lifted value generic for property-extension constraints (`where Tag == ..., Base == ..., Element == ...`). Whether Element should also widen to admit `~Escapable` is orthogonal to Base's widening.

**Decision: Element stays `~Copyable` only in this dispatch.** Rationale: (a) the cohort's Item B Candidate 2 blocker is at the Base axis, not Element. (b) Widening Element to `~Copyable & ~Escapable` is a larger downstream cascade affecting all extension where-clauses and all consumers in `swift-buffer-primitives` / `swift-array-primitives` / etc. that bind Element. (c) No current consumer surfaces an Element-axis `~Escapable` need. If a future consumer surfaces one, that's a separate dispatch.

### G. Conditional-conformance discipline (cohort-mandated)

Per `escapable-support-pair-either-product.md` v1.1.0 Empirical finding 1, every conditional `Copyable` / `Escapable` / `Sendable` extension MUST be explicit on the orthogonal axis. Summary applied to Property:

| Existing extension | Proposed |
|--------------------|----------|
| `extension Property: Copyable where Base: Copyable {}` | `extension Property: Copyable where Base: Copyable & ~Escapable {}` |
| `extension Property: Sendable where Base: Sendable {}` | `extension Property: Sendable where Base: Sendable & ~Copyable & ~Escapable {}` |
| (NEW) `extension Property: Escapable where Base: Escapable & ~Copyable {}` | NEW |
| `extension Property.Typed: Copyable where Base: Copyable {}` | `extension Property.Typed: Copyable where Base: Copyable & ~Escapable {}` |
| `extension Property.Typed: Sendable where Base: Sendable {}` | `extension Property.Typed: Sendable where Base: Sendable & ~Copyable & ~Escapable {}` |
| (NEW) `extension Property.Typed: Escapable where Base: Escapable & ~Copyable {}` | NEW |
| `extension Property.Consume: Sendable where Base: Sendable {}` | `extension Property.Consume: Sendable where Base: Sendable & ~Escapable {}` |

Property.Inout / Property.Borrow / Property.{Inout,Borrow}.Typed.* are unconditionally `~Copyable, ~Escapable` (scope-bound borrow shapes); no conditional Copyable / Escapable / Sendable extensions on them — no orthogonal-axis declarations needed.

### H. Test additions

Existing tests: 48 in 48 suites (Property, Property.Typed, Property.Inout, Property.Inout.Typed, Property.Inout.Typed.Valued, Property.Inout.Typed.Valued.Valued, Property.Borrow, Property.Borrow.Typed, Property.Borrow.Typed.Valued, Property.Consume, Property.Consume.State, plus tutorial / integration / edge-case suites).

New test fixture (mirroring cohort pattern):

```swift
struct NEResource: ~Escapable {
    let id: Int
    @_lifetime(immortal)
    init(_ id: Int) { self.id = id }
}
```

Coverage targets:

| Test name (proposed) | What it verifies |
|----------------------|------------------|
| `Property_NEResource_init_consume_base` | `Property<Tag, NEResource>(consume resource)` compiles and stores |
| `Property_Typed_NEResource_init_consume_base` | `Property<Tag, NEResource>.Typed<Int>(consume resource)` compiles and stores |
| `Property_Inout_NEResource_admits_Self_~Escapable` | `extension MockContainer where Self: ~Copyable & ~Escapable { var x: Property<X>.Inout { ... } }` compiles |
| `Property_Borrow_NEResource_admits_Self_~Escapable` | `extension MockContainer where Self: ~Copyable & ~Escapable { var x: Property<X>.Borrow { ... } }` compiles |
| `Property_Carrier_conformance_NEResource` | `Property<Tag, NEResource>` satisfies `Carrier.\`Protocol\`` |
| `Copyable_path_unchanged` | Existing `Base: Copyable` accessor pattern still works (regression guard) |
| `~Copyable_path_unchanged` | Existing `Base: ~Copyable` (Escapable-implicit) accessor pattern still works (regression guard) |

Existing 48 tests must all continue to pass.

### I. Lifetimes feature + per-toolchain expectations

`Lifetimes` and `LifetimeDependence` features are already enabled in `Package.swift` (verified). No `Package.swift` changes required.

`@_lifetime(copy base)` annotations carry the same semantic as the cohort's `@_lifetime(copy first, copy second)` on Pair — the result Property's lifetime ties to the consumed Base.

`@_lifetime(borrow self)` annotations on `Property.Inout`'s `var base` (Property.Inout.swift:129), `Property.Inout.Typed`'s `var base` (Property.Inout.Typed.swift:65), `Property.Inout.Typed.Valued`'s `var base` (Property.Inout.Typed.Valued.swift:65), `Property.Inout.Typed.Valued.Valued`'s `var base` (Property.Inout.Typed.Valued.Valued.swift:56), `Property.Borrow`'s `var base` (Property.Borrow.swift:78) carry forward unchanged.

Parameter-pack expansion bugs (`#88985`, `#88987`) do NOT apply — Property and Property.Typed use no parameter packs.

The Swift 6.3.1 / 6.4-dev release-mode `withUnsafePointer(to: borrowing _)` miscompile (documented at `swift-institute/Experiments/borrow-pointer-storage-release-miscompile/` and warned about at `Property.Inout.swift:88-105`) is constrained to specific `@inlinable` cross-module patterns — the existing `Property.Inout.init(_ base: borrowing Base)` non-`@inlinable` shape preserves the cross-module function-call boundary and is unaffected by Base widening.

### J. File-modification summary

| File | Change kind | Lines (estimate) |
|------|-------------|------------------|
| `Sources/Property Primitives Core/Property.swift` | Type-level widening, +1 conditional Escapable extension, init annotation | ~5 lines |
| `Sources/Property Primitives Core/Property+Carrier.swift` | Where-clause widening | ~1 line |
| `Sources/Property Inout Primitives/Property.Inout.swift` | Where-clause widening on 3 extensions | ~3 lines |
| `Sources/Property Inout Primitives/Property.Inout.Typed.swift` | Where-clause widening on 2 extensions | ~2 lines |
| `Sources/Property Inout Primitives/Property.Inout.Typed.Valued.swift` | Where-clause widening on 2 extensions | ~2 lines |
| `Sources/Property Inout Primitives/Property.Inout.Typed.Valued.Valued.swift` | Where-clause widening on 2 extensions | ~2 lines |
| `Sources/Property Borrow Primitives/Property.Borrow.swift` | Where-clause widening on 2 extensions | ~2 lines |
| `Sources/Property Borrow Primitives/Property.Borrow.Typed.swift` | Where-clause widening on 2 extensions | ~2 lines |
| `Sources/Property Borrow Primitives/Property.Borrow.Typed.Valued.swift` | Where-clause widening on 2 extensions | ~2 lines |
| `Sources/Property Typed Primitives/Property.Typed.swift` | Type-level widening, init annotation, +1 conditional Escapable extension, conformance widenings, outer extension widening | ~6 lines |
| `Sources/Property Consume Primitives/Property.Consume.swift` | Outer extension widening, Sendable conformance widening | ~2 lines |
| `Tests/Property Primitives Tests/*` | Add NEResource fixture + 7 tests | +~80 lines |
| `Package.swift` | Unchanged | 0 |
| Property+Carrier.swift, exports.swift | Unchanged otherwise | 0 |

**Total: ~30 net new/changed lines across 11 source files; ~80 new test lines.**

The change is localized to where-clauses + type-declaration heads + `@_lifetime` annotations. No body rewrites. No accessor-shape changes (unlike the upstream Ownership.Inout upgrade which switches to `assumingMemoryBound`).

### K. Docs / DocC follow-ups (deferred)

Property's DocC catalog (`Property Primitives.docc/`) and the per-variant docs reference the existing `where Base: ~Copyable` pattern in tutorials and articles. The articles do not block compilation, but the canonical-usage examples will read inconsistently with the wider type after the upgrade. Updating DocC examples to demonstrate the `~Escapable` admission path (`extension Container where Self: ~Copyable & ~Escapable { ... }`) is a doc follow-up, **out of scope for this dispatch** per the active handoff's `MUST NOT bundle the property-primitives upgrade with downstream consumer migration` ground rule. Capture as a follow-up handoff item.

### L. Phase-2 implementation refinements

Discovered during execution; supersedes §E's "where-clause widening only" framing for the Inout/Borrow Property.* nested types.

| Concern | Refinement |
|---------|------------|
| Struct-body `init(_ base: inout Base)` on `Property.Inout`, `.Inout.Typed`, `.Inout.Typed.Valued`, `.Inout.Typed.Valued.Valued` | MUST be relocated out of the struct body into a separate extension at narrower constraint `extension Property.Inout[.Typed[.Valued[.Valued]]] where Base: ~Copyable` (Escapable implicit). Reason: `Ownership.Inout(mutating: &base)` is in `where Value: ~Copyable` (Escapable implicit) per upstream PUSH #1; if the init stayed in the wider `Base: ~Copyable & ~Escapable` extension, the call into `Ownership.Inout` would fail "requires that Base conform to Escapable". |
| Struct-body `init(_ base: borrowing Base)` on `Property.Borrow`, `.Borrow.Typed`, `.Borrow.Typed.Valued` | Same rule: relocate to `where Base: ~Copyable` (Escapable implicit). Reason: `Ownership.Borrow(borrowing: base)` is in `where Value: ~Copyable` (Escapable implicit). |
| `@unsafe init(_ base: borrowing Base)` on `Property.Inout` | Same rule: relocate. Reason: `withUnsafePointer(to: base)` requires `Base: Escapable`. |
| `unsafe withUnsafePointer(...)` / `unsafe withUnsafeMutablePointer(...)` in `Property.pointer` static helpers (Property.Inout.swift:147–167) | Pre-existing nightly warning ("no unsafe operations occur within 'unsafe' expression") fixed by removing the redundant `unsafe` keyword. Default toolchain accepts the unwrapped form. Bundled into this dispatch per `feedback_no_deferral_bundle_ecosystem_fixes.md`. |

Net file-count effect: each affected file gains one new extension block; type-declaration body shrinks. Public API surface is unchanged — the same init signatures remain, just at one tier narrower in the constraint hierarchy. Downstream call sites that pass Escapable Base are unaffected; downstream call sites that wish to construct `Property.Inout<NEResource>` (or any ~Escapable Base) need a future raw-address-form init analogous to `Ownership.Inout.init(unsafeRawAddress:mutating:)`. That extended construction surface is **deferred** to a follow-up dispatch — type-level admission is the load-bearing change for the cohort's Item B Candidate 2 blocker; functional construction with ~Escapable Base is not in scope.

### M. Phase-2 verification result

Triple-toolchain green (2026-05-09 at PUSH #2 candidate SHA):

| Toolchain | Build | Tests |
|-----------|-------|-------|
| Swift 6.3.1 (Xcode 26.4 default) | clean | 48 / 48 |
| Swift 6.4-dev nightly 2026-05-07-a (`org.swift.64202605071a`) | clean | 48 / 48 |
| Swift 6.4-dev / Embedded | clean | (build-only — Embedded does not run swift-testing) |

Type-level admission verified by 7 compile-time typealiases (one per Property variant + Inout.Typed.Valued nesting), all referencing the cohort fixture `NEResource: ~Copyable, ~Escapable`. Regression of the widening would fail the typealiases at compile time.

## Outcome

**Status**: CONVERGED. Implementation deferred to Phase 2, gated on (a) `swift-ownership-primitives` Ownership.Inout upgrade landing first, (b) per-action user authorization for the public-repo push.

**Cascade-execution-order**: This package lands SECOND, after `swift-ownership-primitives`. Property.Inout's private storage `Tagged<Tag, Ownership.Inout<Base>>` instantiates Ownership.Inout's Value with `~Escapable` Base; the upstream upgrade is a hard precondition.

Per [RELEASE-013] First-Publication Clean-History and the 2026-05-09 cohort precedent, the change lands as a **single amended commit** via amend + force-push. All 11 source files plus tests in one commit per the cohort convention.

Triple-toolchain verification (Swift 6.3.1 + 6.4-dev nightly 2026-05-07-a + 6.4-dev/Embedded) before push, per existing cohort discipline.

Tagged composition: NO upgrade to `swift-tagged-primitives` (already admits `~Escapable` Underlying). Carrier composition: NO upgrade to `swift-carrier-primitives` (already admits `~Escapable` Underlying).

## References

- Institute-wide DECISION: `swift-institute/Research/property-ownership-escapable-base-upgrade.md`
- Cohort canonical pattern: `swift-institute/Research/escapable-support-pair-either-product.md` v1.1.0
- Foundational design: `swift-property-primitives/Research/property-type-family.md` (IMPLEMENTED, 2026-01-21)
- Supersession trail: `swift-property-primitives/Research/property-view-escapable-removal.md` (DECISION 2026-03-22, SUPERSEDED 2026-03-25 by restoration commit `43247e3`)
- Upstream upgrade: `swift-ownership-primitives/Research/escapable-value-upgrade.md`
- Tagged readiness: `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:55`
- Carrier readiness: `swift-carrier-primitives/Sources/Carrier Primitives/_CarrierProtocol.swift:26,36`
- Property current: `Sources/Property Primitives Core/Property.swift:46, 67, 72, 81, 82`
- Property+Carrier: `Sources/Property Primitives Core/Property+Carrier.swift:24`
- Property.Typed current: `Sources/Property Typed Primitives/Property.Typed.swift:3, 40, 62, 68, 77, 78`
- Property.Consume current: `Sources/Property Consume Primitives/Property.Consume.swift:3, 157`
- Property.Inout family: `Sources/Property Inout Primitives/*` (4 files)
- Property.Borrow family: `Sources/Property Borrow Primitives/*` (3 files)
- Memory: `copypropagation-nonescapable-fix.md`, `pack-expand-on-consuming-param-property.md` (no application here), `feedback_escapable_over_with_closures.md`
- Active dispatch: `HANDOFF-property-primitives-escapable-upgrade.md`
- Sibling cohort handoff (parked): `HANDOFF-escapable-cohort-followups.md` Item B Candidate 2
