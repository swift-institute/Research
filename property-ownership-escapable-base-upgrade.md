# Property + Ownership ~Escapable Base/Value Upgrade

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: CONVERGED
tier: 2
scope: cross-package
applies_to: [swift-property-primitives, swift-ownership-primitives]
preceded_by:
  - swift-institute/Research/escapable-support-pair-either-product.md (DECISION v1.1.0, 2026-05-09) — canonical cohort pattern
  - swift-institute/Research/nonescapable-ecosystem-state.md (DECISION, 2026-04-02) — ecosystem readiness
  - swift-property-primitives/Research/property-view-escapable-removal.md (DECISION 2026-03-22, SUPERSEDED 2026-03-25 by restoration commit `43247e3`)
  - swift-property-primitives/Research/property-type-family.md (IMPLEMENTED, 2026-01-21) — foundational design
relates_to:
  - swift-ownership-primitives/Research/escapable-value-upgrade.md (per-package execution)
  - swift-property-primitives/Research/escapable-base-upgrade.md (per-package execution)
  - swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md (DECISION v1.1.0, 2026-05-09)
toolchains_verified:
  - Swift 6.3.1 (Xcode 26.4 default)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a (`org.swift.64202605071a`, version `6.4.20260507101`)
  - Swift 6.4-dev/Embedded
trigger: Sibling cohort (Pair / Either / Product) hit a structural blocker on Item B Candidate 2 — `Collection.Protocol`'s `forEach: Property<Collection.ForEach, Self>.Inout` accessor cannot admit `Self: ~Copyable & ~Escapable` because `Property<Tag, Base: ~Copyable>`'s Base parameter is implicitly Escapable. Diagnosis traced to Property core. The cohort dispatch took Path A (rollback Collection.Protocol attempt; capture deferral pointing at this dispatch). This research is the structural-fix design.
---
-->

## Context

The 2026-05-09 cohort cascade established `~Escapable` admission across `Pair` / `Either` / `Product`'s functor surface (per `escapable-support-pair-either-product.md` v1.1.0) and across the institute protocols `Equation.Protocol` / `Hash.Protocol` / `Comparison.Protocol`. Item B Candidate 2 of the cohort's parked dispatch (`HANDOFF-escapable-cohort-followups.md` Item B) attempted to widen `Collection.Protocol`'s `forEach` accessor to admit `Self: ~Copyable & ~Escapable`. The attempt failed because the accessor's return type, `Property<Collection.ForEach, Self>.Inout`, ultimately requires `Self: ~Escapable` to flow through `Property<Tag, Base>`'s outer `Base: ~Copyable` constraint and through `Tagged<Tag, Ownership.Inout<Base>>` private storage inside `Property.Inout`. The cohort rolled back, parked a deferral pointing here, and dispatched this structural fix.

Phase 0 + Phase 0.5 surfaced two stalenesses on the dispatch's original framing:

1. **The `Property.View` family was already renamed** to `Property.Inout` / `Property.Borrow` / `Property.Consume` per `swift-property-primitives` commits `acec3c5` / `a372ee0` / `040c834` / `2e5bb61` / `5da7f17`.
2. **`~Escapable` was already restored** on the renamed types per `swift-property-primitives` commit `43247e3` (2026-03-25), reflected in `swift-property-primitives` commit `2a20349`. The restoration is recorded in `property-view-escapable-removal.md`'s SUPERSEDED stamp and in memory entry `copypropagation-nonescapable-fix.md`.

The remaining live structural work is `Property<Tag, Base>`'s Base widening to admit `~Escapable` Base, with one cross-package implication on `swift-ownership-primitives`' `Ownership.Inout<Value>` (which Property.Inout's storage depends on). This document specifies the joint upgrade.

## Question

What cross-package coordination admits `~Escapable` Base on `Property<Tag, Base>` and on the Tagged-composed `Ownership.Inout<Value>` storage backing `Property.Inout`? In what cascade order should the packages land?

## Analysis

### A. Cohort pattern as canonical template (already shipped)

`escapable-support-pair-either-product.md` v1.1.0 established the canonical cohort pattern for owned-storage type-level `~Escapable` upgrades. Verified empirical landings on triple toolchain (2026-05-09):

- swift-pair-primitives `7f7c7ef` — type-level `~Escapable` upgrade; `swapped` admits both arms `~Escapable`; conditional conformances explicit on the orthogonal axis; 32/32 tests on triple-toolchain.
- swift-either-primitives `b6b7672` — `swapped` / `value(of:)` admit `~Escapable`; flatMap/fold remain Escapable-only (Gap A); 65/65 tests.
- swift-equation-primitives / swift-hash-primitives / swift-comparison-primitives — institute-protocol upgrades admitting `~Escapable` conformers.

The structural lessons codified in v1.1.0 §Empirical (paraphrased):

| Lesson | Application |
|--------|-------------|
| Conditional conformances must be explicit on the orthogonal axis | Every `extension T: Copyable where ...` MUST also state `& ~Escapable`; every `extension T: Escapable where ...` MUST also state `& ~Copyable`; absence triggers `error: conditional conformance to 'Copyable' must explicitly state whether '...' is required to conform to 'Escapable' or not` |
| `init` requires `@_lifetime(copy x)` when the type is `~Escapable` and Base is owned-storage | Direct mirror for `Property` and `Property.Typed` whose storage is `var _base: Base` |
| Direct field access on consuming parameter (no intermediate `let consumed = consume value`) | Workaround for the move-checker bug filed as `swiftlang/swift#88985` and `#88987` |

### B. Cross-package readiness audit (Phase 0 + Phase 0.5 findings)

| Component | File:line | Constraint | Ready? |
|-----------|-----------|------------|--------|
| `Tagged<Tag, Underlying>` | `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:55` | `Tag: ~Copyable & ~Escapable, Underlying: ~Copyable & ~Escapable` | YES |
| `Carrier.\`Protocol\`` (`_CarrierProtocol`) | `swift-carrier-primitives/Sources/Carrier Primitives/_CarrierProtocol.swift:26,36` | `~Copyable, ~Escapable`; `associatedtype Underlying: ~Copyable & ~Escapable` | YES |
| `Ownership.Borrow<Value>` | `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Ownership.Borrow.swift:69` | `Value: ~Copyable & ~Escapable` | YES |
| `Ownership.Inout<Value>` | `swift-ownership-primitives/Sources/Ownership Inout Primitives/Ownership.Inout.swift:36` | `Value: ~Copyable` | **NO** |
| `Property<Tag, Base>` | `swift-property-primitives/Sources/Property Primitives Core/Property.swift:46` | `Base: ~Copyable` | **NO** |

Two packages need upgrades. Tagged and Carrier are pre-prepared. Open Question 1 from the dispatch (`HANDOFF-property-primitives-escapable-upgrade.md` § Open Questions: "Tagged needs corresponding upgrade?") resolves NO.

### C. Ownership.Borrow as structural template for Inout

`Ownership.Borrow` already solved the same structural problem `Ownership.Inout` faces. The relevant decisions are documented inline in `Ownership.Borrow.swift` (lines 36-67, 257-284):

| Concern | Borrow's decision |
|---------|-------------------|
| `Value: ~Escapable` admission requires storage that does not implicitly require `Pointee: Escapable` | Storage = `UnsafeRawPointer`, not `UnsafePointer<Value>` |
| Typed init paths require `Value: Escapable` (because `UnsafePointer<Value>` requires it) | Typed inits gated `where Value: ~Copyable` (Escapable implicit); raw-address init gated `where Value: ~Copyable & ~Escapable` |
| Value access via `assumingMemoryBound(to:)` requires `Value: Escapable` | `var value` accessor gated `where Value: ~Copyable` (Escapable implicit) |

`Ownership.Inout`'s upgrade mirrors this exactly, minus two pieces Inout doesn't need:

- **`_owner: AnyObject?` field** — Borrow has it for the by-register Copyable-Value case where `withUnsafePointer(to: borrowing value)` would capture a callee-frame spill slot. Inout's `init(mutating value: inout Value)` uses `inout`, which is always indirect; the address is stable; no heap allocation needed.
- **`init(borrowing: borrowing Value)` path** — Inout's analog is `init(mutating: inout Value)`. The borrow-pointer release-mode miscompile gotcha (documented at `swift-institute/Experiments/borrow-pointer-storage-release-miscompile/`) does not apply.

Inout is structurally simpler than Borrow.

### D. Cascade execution order

`swift-ownership-primitives` lands FIRST. `swift-property-primitives` lands SECOND.

Rationale:

- Property.Inout's private storage is `Tagged<Tag, Ownership.Inout<Base>>` (Property.Inout.swift:68). Widening Property's Base to admit `~Escapable` instantiates `Ownership.Inout<Base>` with a `~Escapable` Value. Until Ownership.Inout's `Value` admits `~Escapable`, the Property-side widening fails to compile.
- The reverse order would force Property to ship a build-broken state pending the ownership-primitives push.
- The ownership-primitives upgrade lands cleanly without property-side coordination (zero downstream consumers in `swift-standards` / `swift-foundations`; the four `swift-property-primitives` source consumers wrap Inout in private storage that's not exposed in Property's public API).

### E. Per-package scope (cross-link)

Execution specifications live in per-package research:

- `swift-ownership-primitives/Research/escapable-value-upgrade.md` — Ownership.Inout `Value` widening, storage rewrite, init split, accessor switch.
- `swift-property-primitives/Research/escapable-base-upgrade.md` — Property `Base` widening, conditional-conformance shape, per-subtarget where-clause cascade, Property.Typed widening decision, Property.Consume confirmed unchanged.

### F. Open-question resolution from `HANDOFF-property-primitives-escapable-upgrade.md`

| Open Question | Resolution |
|---------------|------------|
| 1. Tagged needs corresponding upgrade? | NO — Tagged already admits `Underlying: ~Copyable & ~Escapable` (Tagged.swift:55) |
| 2. Property.View `~Escapable` re-add commit shape — bundled or separate? | SUPERSEDED — restoration is already shipped at `swift-property-primitives` commit `43247e3` (2026-03-25); no commit needed in this dispatch |
| 3. Supersession path for `property-view-escapable-removal.md` — [META-003] or [META-004]? | SUPERSEDED — already done (research doc carries SUPERSEDED stamp citing 2026-03-25 restoration) |
| 4. Carrier.Protocol composition affected? | NO — Carrier.`Protocol` already admits `~Escapable` Underlying (`_CarrierProtocol.swift:26,36`); the Property+Carrier conformance's `where Base: ~Copyable` cascades cleanly to `where Base: ~Copyable & ~Escapable` |

### G. Toolchain + per-toolchain expectations

Both packages already enable the required experimental features in `Package.swift`:

- `enableExperimentalFeature("Lifetimes")`
- `enableExperimentalFeature("LifetimeDependence")`
- `enableUpcomingFeature("LifetimeDependence")`

`@_lifetime(copy base)` / `@_lifetime(borrow base)` / `@_lifetime(&base)` / `@_lifetime(borrow self)` annotations are already in widespread use across both packages (Property.Inout / Property.Borrow inits already annotated; Ownership.Borrow inits already annotated). Verification on Swift 6.3.1 (Xcode default) + Swift 6.4-dev nightly 2026-05-07-a + Swift 6.4-dev/Embedded is the existing cohort discipline.

Release-mode noise to watch for, per memory `pack-expand-on-consuming-param-property.md`: parameter-pack expansion is NOT used in either Property or Ownership.Inout, so `swiftlang/swift#88985` / `#88987` do not apply here.

## Outcome

**Status**: DECISION

The joint upgrade lands as a two-package cascade:

1. **`swift-ownership-primitives`** — `Ownership.Inout<Value>`'s `Value` widens from `~Copyable` to `~Copyable & ~Escapable`. Storage rewrites from `UnsafeMutablePointer<Value>` to `UnsafeMutableRawPointer`. Init paths split per the Ownership.Borrow template. See `swift-ownership-primitives/Research/escapable-value-upgrade.md`.

2. **`swift-property-primitives`** — `Property<Tag, Base>`'s `Base` widens from `~Copyable` to `~Copyable & ~Escapable`. Property itself becomes `~Copyable, ~Escapable`. Conditional conformances expanded per the cohort canonical pattern. The cascade propagates through `Property.Inout` / `Property.Borrow` / `Property.Inout.Typed.*` / `Property.Borrow.Typed.*` extension where-clauses. `Property.Typed` widens (DECISION: see per-package execution doc § Property.Typed). `Property.Consume` does NOT widen (Copyable-only by construction). `Property+Carrier`'s conformance widens. See `swift-property-primitives/Research/escapable-base-upgrade.md`.

Each push is independently gated on per-action user authorization per `[GIT-001]`. Class-(c) public-repo push class.

Triple-toolchain verification per package before each push. Per-package single-commit-per-package via amend + force-push, per `[RELEASE-013]` First-Publication Clean-History and the cohort precedent.

No tags; no scope expansion beyond `swift-ownership-primitives` + `swift-property-primitives` without further authorization. If implementation surfaces a third-package implication, escalate before expanding.

## References

- Cohort canonical: `swift-institute/Research/escapable-support-pair-either-product.md` v1.1.0
- Ecosystem state: `swift-institute/Research/nonescapable-ecosystem-state.md`
- Borrow template: `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Ownership.Borrow.swift` lines 36-67, 257-284
- Tagged readiness: `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:55`
- Carrier readiness: `swift-carrier-primitives/Sources/Carrier Primitives/_CarrierProtocol.swift:26,36`
- Inout current: `swift-ownership-primitives/Sources/Ownership Inout Primitives/Ownership.Inout.swift:36`
- Property current: `swift-property-primitives/Sources/Property Primitives Core/Property.swift:46`
- Property.View supersession: `swift-property-primitives/Research/property-view-escapable-removal.md` (SUPERSEDED 2026-03-25)
- Memory: `copypropagation-nonescapable-fix.md`, `pack-expand-on-consuming-param-property.md`, `feedback_escapable_over_with_closures.md`
- Per-package execution: `swift-ownership-primitives/Research/escapable-value-upgrade.md`, `swift-property-primitives/Research/escapable-base-upgrade.md`
- Sibling cohort handoff: `HANDOFF-escapable-cohort-followups.md` (parked) Item B Candidate 2
- Active dispatch: `HANDOFF-property-primitives-escapable-upgrade.md`
