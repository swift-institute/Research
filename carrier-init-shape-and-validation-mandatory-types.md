# Carrier init shape and Tagged–Underlying alignment

<!--
---
version: 1.1.0
last_updated: 2026-05-01
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

<!--
Changelog:
- v1.1.0 (2026-05-01): Corrected the central premise. v1.0.0 recommended
  keeping the `__unchecked:`-only discipline on the basis that it preserves
  protection for validation-mandatory types. Verifying against
  Tagged+Carrier.swift surfaced that Tagged's existing Carrier conformance
  already exposes `init(_ underlying:)` publicly via the protocol's init
  requirement. The protection the v1.0.0 recommendation was meant to
  preserve was already absent at the Carrier-conformance boundary.
  Recommendation flipped to a four-part compound change: adopt V5; remove
  `__unchecked:`; drop `rawValue`; rename `RawValue` → `Underlying`. Adds
  Impact Assessment section (originally absent).
- v1.0.0 (2026-05-01): Initial RECOMMENDATION (path-a, since superseded).
-->

## Context

### Trigger

The README of `swift-tagged-primitives` previously showed `User.ID(__unchecked: (), n)` at a consumer call site. The Institute's stance is that `__unchecked:` is the package's escape hatch for declaring custom inits on domain types, not for direct use at consumer call sites. The README was corrected (commit `5f9fb4c`) to declare a public `init(_ value: UInt64)` that wraps `__unchecked:` internally.

That correction prompted the question: should the wrapping pattern ship in `swift-tagged-primitives` (or `swift-carrier-primitives`, since Carrier is Tagged's super-protocol) so consumers don't have to declare it per-domain? And if so, should the wrapping init also admit a throwing/validating shape?

A six-variant experiment was conducted at `swift-tagged-primitives/Experiments/generic-throws-init/` (commits `2e0308c` and `3686e7c`). Results: H1 / H3 / H4 / H5 / H6 CONFIRMED, H2 REFUTED. The simple "single API via `E == Never` inference from a default empty closure" shape (H2) doesn't compile. The working answer for the throwing init is **V5**: a default extension on `Carrier` providing a generic-throws init that delegates to the existing non-throwing init requirement. Zero migration cost; every Carrier conformer (Tagged, the 28 stdlib trivial-self carriers, downstream packages) inherits the throwing init for free.

### Premise correction (v1.1.0)

The v1.0.0 recommendation was to keep the `__unchecked:`-only discipline on the basis that it preserved protection for validation-mandatory types — types whose semantics require all direct construction to go through validated factories. The user surfaced that Tagged's existing Carrier conformance already exposes a public init.

Verifying against `swift-tagged-primitives/Sources/Tagged Primitives/Tagged+Carrier.swift`:

```swift
extension Tagged: Carrier
where Tag: ~Copyable & ~Escapable, RawValue: Carrier {
    public typealias Domain = Tag
    public typealias Underlying = RawValue.Underlying
    public var underlying: Underlying {
        _read { yield rawValue.underlying }
    }
    public init(_ underlying: consuming Underlying) {  // ← public init, no __unchecked:
        self.init(__unchecked: (), RawValue(underlying))
    }
}
```

The Carrier conformance ships a public `init(_ underlying:)` whenever `RawValue: Carrier`. For the typical Tagged-aliased domain type (e.g., `Tagged<User, UInt64>` where UInt64 is a stdlib trivial-self carrier shipped via Carrier's SLI), this means `Tagged<User, UInt64>(42)` compiles today as a public call — bypassing the `__unchecked:` label entirely.

The `__unchecked:`-only protection at Tagged's level is therefore already broken at the Carrier-conformance boundary. The v1.0.0 recommendation's "protection preservation" rationale was based on an incorrect premise. The corrected reading reframes the problem.

### Scope

Ecosystem-wide [RES-002a]. Affects Carrier, Tagged, every existing and future Carrier conformer, and every consumer of Tagged across the Institute's primitives ecosystem.

### Constraints (user-directed)

| Constraint | Direction (2026-05-01) |
|---|---|
| Marker protocol (e.g., StrictCarrier) | OUT of consideration |
| `RawValue: Carrier` constraint added to Tagged itself | OUT of consideration |
| Removing `__unchecked:` from Tagged's public surface | IN scope |
| Dropping `rawValue` accessor from Tagged | IN scope |
| Renaming Tagged's generic parameter `RawValue` → `Underlying` | IN scope |
| Tagged's Carrier conformance | KEEP |

## Question

Given:

- The user's constraint set above
- Carrier's existing `init(_ underlying:)` requirement (load-bearing for the carrier-cascade design)
- The empirical evidence from the generic-throws-init experiment

What public-init shape should Tagged and Carrier ship, and what associated alignments to Tagged's API surface follow?

## Prior Art Survey [RES-021]

### Internal

| Document | Relevance |
|---|---|
| [`asymmetric-quadrant-ergonomics-as-rejection-criterion.md`](./asymmetric-quadrant-ergonomics-as-rejection-criterion.md) (RECOMMENDATION 2026-04-26) | Rule that asymmetric-quadrant ergonomic affordances on Carrier are rejected; uniform affordances are accepted. V5 satisfies the uniform-quadrant criterion (works across all four quadrants of `~Copyable × ~Escapable`). Supports adopting V5. |
| [`cross-domain-init-overload-resolution-footgun.md`](./cross-domain-init-overload-resolution-footgun.md) (RECOMMENDATION 2026-02-11) | Documents that Swift's overload resolution can silently choose unintended init overloads in function-reference contexts. Removing `__unchecked:` from public surface reduces the candidate-init set; argues *for* the simplification. |
| [`carrier-launch-skill-incorporation-backlog.md`](./carrier-launch-skill-incorporation-backlog.md) (PLAN 2026-04-29) | Carrier's launch process is explicitly framed as a learning event. The v0.1.x release cohort (carrier → ownership → tagged → property) has not yet cut its tags; a Tagged redesign at this point lands cleanly within the cohort rather than after. |

### External

| Source | Relevance |
|---|---|
| [Swift SE-0413: Typed Throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) | Establishes `throws(E) where E: Error`. The H2 REFUTATION is consistent with the proposal's stated inference behaviour. |
| [pointfreeco/swift-tagged](https://github.com/pointfreeco/swift-tagged) | The Institute fork's upstream. Upstream uses `init(rawValue:)` and `var rawValue:` directly. The Institute fork added `__unchecked:` as an explicit discipline overlay. The proposed redesign retires the overlay and aligns Tagged's surface with Carrier instead of with upstream's pattern. |

## Analysis [RES-005] [RES-009]

### Reframed problem

The corrected analysis collapses the v1.0.0 binary (path-a vs path-b) into a single observation: **Tagged is a Carrier transformer**. The `__unchecked:` discipline was a vestige of the upstream `init(rawValue:)` pattern, layered on top of Tagged's design. With Carrier's `init(_ underlying:)` already providing the public construction path (and `var underlying:` already providing the public read accessor), the `__unchecked:` and `rawValue` surfaces are redundant — they serve the same job Carrier's API serves, with worse names.

The real design question is no longer "which protection level for Tagged?" but "should Tagged keep its dual API (per-level via `rawValue`/`__unchecked:` plus cascade via Carrier), or align fully on Carrier's cascade-only API?"

### Option (a) Status quo

Keep both surfaces. Tagged exposes `__unchecked:` + `rawValue` (per-level, vestige of upstream) AND Carrier's `init(_ underlying:)` + `underlying` (cascade). Two ways to construct, two ways to read.

**Cons**:
- Two construction paths for the same conceptual operation; consumers face a choice they don't need
- The `__unchecked:` label was meant as a discipline speed bump but Carrier's cleaner public init bypasses it — the speed bump is doing no work
- `rawValue` (immediate wrap) and `underlying` (deep cascade) differ only for nested Tagged, which is a rare case; consumers usually want `underlying`
- README and DocC have to teach two parallel surfaces

### Option (b) Aligned on Carrier (the four-part compound change)

Remove `__unchecked:`. Drop `rawValue` accessor. Rename generic parameter `RawValue` → `Underlying`. Adopt V5 (Carrier extension shipping the throwing init). Tagged becomes purely a phantom-typed Carrier transformer.

**Pros**:
- One canonical construction path: Carrier's `init(_ underlying:)`. One canonical accessor: Carrier's `.underlying`.
- Naming alignment: Tagged's parameter named `Underlying` matches Carrier's vocabulary; documentation and teaching simplify.
- Removes a vestige (the `__unchecked:` label) that wasn't earning its complexity.
- V5 ships throwing inits across all Carrier conformers for free; per-domain throwing-init declarations become unnecessary.
- Pre-tag (no shipped 0.1.x), so the breaking change lands in the launch-cohort window without disrupting external consumers.

**Cons**:
- For Tagged specializations where `RawValue` doesn't conform to Carrier, the type becomes externally uninhabitable. Consumers who want such Tagged types must voluntarily conform their RawValue to Carrier (a one-line trivial-self conformance: `extension MyType: Carrier { typealias Underlying = MyType }`). The constraint shifts from "any RawValue at the type level" to "any RawValue at the type level *but only Carrier-RawValue ones can be constructed publicly*."
- Nested Tagged (`Tagged<X, Tagged<Y, UInt64>>`) loses the per-level read accessor. The deep cascade `.underlying` (UInt64) replaces the immediate `.rawValue` (Tagged<Y, UInt64>). Real but rare loss.
- Breaking change in source (parameter rename, accessor drop). Mitigated by deprecation cycle within the 0.1.x line.
- The internal escape hatch (for tests, SLI conformances, and the package's own implementation) needs a `package`-scoped init replacing the current public `__unchecked:`.

### Comparison

| Criterion | (a) Status quo | (b) Aligned on Carrier |
|---|---|---|
| Surface complexity | Two parallel APIs | One canonical API |
| Naming alignment | `RawValue` vs `Underlying` | Aligned on `Underlying` |
| Per-domain throwing-init declaration friction | Required | Eliminated (V5 covers) |
| External consumers using non-Carrier RawValue | Supported via `__unchecked:` | Externally uninhabitable; consumers conform RawValue to Carrier (one-line) |
| Nested-Tagged per-level access | Yes (`.rawValue`) | No (only deep `.underlying`) |
| Breaking change scope | None | Parameter rename + accessor drop + init signature change (within Tagged); V5 addition (Carrier; non-breaking) |
| Mid-launch-cohort timing | Neutral | Lands cleanly pre-tag |

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: **Option (b) — the four-part compound change.**

### Four parts

1. **Adopt V5 in `swift-carrier-primitives`** — ship a default extension on `Carrier where Self: ~Copyable & ~Escapable` providing `init<E: Error>(_ underlying: consuming Underlying, validate: (borrowing Underlying) throws(E) -> Void) throws(E)`. Body delegates to the existing non-throwing `init(_ underlying:)` requirement after validation passes. Zero migration cost; every Carrier conformer inherits.

2. **Remove `init(__unchecked:, _:)` from Tagged's public API**, replacing it with `package init(_ underlying: consuming Underlying)`. Tagged consumers construct via Carrier's `init(_ underlying:)` (when `Underlying: Carrier`) or via per-domain declared inits in their own constrained extensions. The `package` init handles internal package code (tests, SLI conformances, the Carrier-conformance body).

3. **Drop `var rawValue: RawValue` accessor.** Tagged's read surface aligns with Carrier's `.underlying`. Provide a one-minor-version deprecation cycle: mark `rawValue` as `@available(*, deprecated, renamed: "underlying")` for trivial-self cases (where the rename is exact), with a bespoke message for nested-Tagged cases (where the rename loses information).

4. **Rename Tagged's generic parameter `RawValue` → `Underlying`** to align with Carrier's vocabulary. The Carrier-conformance typealias becomes `public typealias Underlying = Underlying.Underlying` (LHS is the protocol witness; RHS first `Underlying` is Tagged's generic param; resolves correctly in both trivial-self and nested cases despite the literal-text awkwardness).

### Resulting Tagged shape (v0.2.0 target)

```swift
@frozen
public struct Tagged<Tag: ~Copyable & ~Escapable, Underlying: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    @usableFromInline internal var _storage: Underlying

    @inlinable
    @_lifetime(copy underlying)
    package init(_ underlying: consuming Underlying) {
        self._storage = underlying
    }
}

extension Tagged: Carrier where Tag: ~Copyable & ~Escapable, Underlying: Carrier {
    public typealias Domain = Tag
    public typealias Underlying = Underlying.Underlying

    public var underlying: Underlying {
        _read { yield _storage.underlying }
    }

    @inlinable
    @_lifetime(copy underlying)
    public init(_ underlying: consuming Underlying) {
        self.init(Self.Underlying(underlying))  // construct immediate via cascade end
    }
}
```

(Plus the existing functor operations — `map`, `retag`, `modify` package-internal — adapted to the new parameter name. V5 lives in `swift-carrier-primitives` and is inherited automatically.)

### Rationale

The user's constraints removed every alternative except (b). The corrected analysis showed that (a)'s justification rested on a protection-argument that was already false. (b) is the structurally clean shape: one canonical surface, one canonical name, one Carrier-derived public path. The friction reduction (no per-domain init declarations needed for the simple case; throwing inits free via V5) is real and ecosystem-wide. The cost — non-Carrier-RawValue Tagged becomes externally uninhabitable — is bounded: the typical case (stdlib RawValue, Institute primitive RawValue) is covered automatically; the atypical case has a one-line consumer-side resolution (conform RawValue to Carrier).

Pre-tag timing matters. The redesign lands cleanly in the v0.1.x line within Carrier's launch cohort, before any external consumer has bound to a tagged release. Doing it later would require a major-version bump (0.x → 1.x) or a breaking 0.x → 0.(x+1) cycle.

## Impact Assessment

The change touches multiple files in `swift-tagged-primitives` and may ripple into downstream packages. Categorized below by scope and dependency depth.

### A. swift-tagged-primitives (the package itself)

| Surface | Files | Change |
|---|---|---|
| Core type | `Sources/Tagged Primitives/Tagged.swift` | Rename `RawValue` → `Underlying`; replace `init(__unchecked:, _:)` with `package init(_ underlying:)`; drop `var rawValue` (with deprecation alias for the migration window); update `_storage` type and `modify` package-internal helper |
| Carrier conformance | `Sources/Tagged Primitives/Tagged+Carrier.swift` | Update typealias to `Underlying = Underlying.Underlying`; update init body to use `Self.Underlying(_underlying)` cascade pattern with the new internal `package init`; rename `where RawValue: Carrier` → `where Underlying: Carrier` |
| Functor / formatting | `Sources/Tagged Primitives/Tagged+CustomStringConvertible.swift` | Rename `RawValue` → `Underlying` in extension constraints; replace any `.rawValue` accessor with `.underlying` (or `_storage` for internal access) |
| SLI literal conformances | `Sources/Tagged Primitives Standard Library Integration/Tagged+Literals.swift` | All 9 literal inits currently call `self.init(__unchecked: (), RawValue(integerLiteral: value))` etc. Change to `package init` calls; rename `RawValue` → `Underlying`; update the carve-out `unsafeBitCast` block to use the new names |
| SLI other conformances | `Sources/.../Tagged+Identifiable.swift`, `Tagged+LosslessStringConvertible.swift`, `Tagged+Sequence.swift`, `Tagged+Collection.swift` | Each currently uses `.rawValue` accessor and `RawValue` parameter constraint; rename throughout |
| Test Support | `Tests/Support/exports.swift` (and any helper code) | Update to new names |
| Tests | `Tests/Tagged Primitives Tests/Tagged Tests.swift` (54 tests) and `Tests/Tagged Primitives Standard Library Integration Tests/*` | All test fixtures using `__unchecked:` or `.rawValue` need to be migrated |
| Experiments | `Experiments/tagged-noncopyable-rawvalue/`, `Experiments/tagged-no-*/` (10 experiments), `Experiments/tagged-zero-cost-codegen/`, `Experiments/tagged-modify-escapable-revalidation/`, `Experiments/tagged-literal-*/`, `Experiments/tagged-view-*/`, `Experiments/tagged-viewable-char-crossmodule/`, `Experiments/generic-throws-init/` | All use `__unchecked:` and `.rawValue`; some use `RawValue` as a parameter reference. Each experiment's `Sources/main.swift` (and any header anchors per [EXP-007a]) needs updating |
| Documentation | `README.md`, `Sources/.../Tagged Primitives.docc/Tagged Primitives.md`, `.../Tagged.md`, `.../Phantom-Tag-Semantics.md` | All references to `__unchecked:`, `rawValue`, `RawValue` need rewriting; the Quick Start examples need migration; the Architecture / SLI tables need updating |
| Research | `Research/comparative-analysis-pointfree-swift-tagged.md`, `Research/tagged-types-merits-completeness-and-naming.md`, `Research/principled-absence-array-dict-literal.md`, `Research/sli-literal-vs-strideable-tradeoff.md`, `Research/tagged-literal-conformances*.md`, others | The comparative-analysis doc explicitly contrasts upstream's `init(rawValue:)` with the Institute fork's `init(__unchecked:, _:)`; the comparative dimensions need re-framing. Other research docs that quote Tagged's API need verification per [RES-013a] |

### B. Carrier-side change (V5 adoption)

| Surface | Files | Change |
|---|---|---|
| Carrier protocol package | `swift-carrier-primitives/Sources/Carrier Primitives/Carrier.swift` (or a new file `Carrier+ThrowingInit.swift`) | Add the V5 default extension: `extension Carrier where Self: ~Copyable & ~Escapable { @_lifetime(copy underlying) public init<E: Error>(_ underlying: consuming Underlying, validate: (borrowing Underlying) throws(E) -> Void) throws(E) { try validate(underlying); self.init(underlying) } }` |
| Carrier tests | `Tests/Carrier Primitives Tests/*` | Add coverage for V5; ensure trivial-self and cascading conformers both behave correctly |
| Carrier docs / README | `swift-carrier-primitives/README.md`, `Sources/Carrier Primitives/Carrier Primitives.docc/Conformance-Recipes.md`, `.../Carrier-vs-RawRepresentable.md`, `.../Round-trip-Semantics.md`, `.../Understanding-Carriers.md` | Document the throwing init for consumers; show the validation pattern in Conformance Recipes |

### C. swift-primitives ecosystem (direct dependents of Tagged)

**Live counts** (verified 2026-05-01 per [RES-023]):

- **53 files** in `swift-tagged-primitives/` itself contain `__unchecked` (171 total occurrences)
- **262 files** in other `swift-primitives/swift-*` packages contain `__unchecked` — these are Tagged-aliased consumer call sites at `Index(__unchecked: (), Ordinal(...))` and similar shapes
- **188 files** across the entire `/Users/coen/Developer/` workspace `import Tagged_Primitives`

Grepped a sample to confirm: e.g., `swift-index-primitives/Sources/Index Primitives Core/Index.swift` uses `Index(__unchecked: (), Ordinal(UInt(5)))` — that's a Tagged-derived call (Index<Element> is a typealias for `Tagged<Element, Ordinal>`). The 262-file figure is dominated by these Tagged-aliased consumer uses.

The packages with the highest concentration of Tagged usage (sample, not exhaustive):

- `swift-index-primitives` (Index<Element> = Tagged<Element, Ordinal>; many internal sites)
- `swift-ordinal-primitives` (Ordinal.Protocol conformance on Tagged)
- `swift-cardinal-primitives` (Cardinal trivial-self carrier; Tagged<T, Cardinal> use)
- `swift-affine-primitives` (Affine.Discrete.Vector + Tagged<T, Affine.Discrete.Vector>)
- `swift-graph-primitives`, `swift-set-primitives`, `swift-structured-queries-primitives`, `swift-hash-primitives`, `swift-binary-primitives`, `swift-finite-primitives`, `swift-property-primitives` (Property.View stores Tagged)
- … and more across the swift-primitives ecosystem

### D. swift-foundations / swift-standards (transitive consumers)

**Live counts** (verified 2026-05-01):

- **37 files** in `swift-foundations/` packages contain `__unchecked` (Tagged consumer call sites)
- Transitive Tagged use in `swift-iso/`, `swift-foundations/swift-kernel`, `swift-foundations/swift-darwin`, `swift-foundations/swift-tests`, and others

Concrete sample: `swift-iso/swift-iso-9945/` ships several Tagged-aliased domain types (`ISO 9945.Kernel.Process.Group.ID`, `ISO 9945.Kernel.Group`, `ISO 9945.Kernel.User`, etc.) and consumes them via `__unchecked:` calls. Migration affects each of these.

### Total ecosystem reach

Combining A + C + D (`__unchecked` use sites only):

- **~352 files** across the workspace use `__unchecked` directly. All are Tagged-related.
- **~382 `.rawValue` references** in swift-primitives (note: includes false positives from stdlib `RawRepresentable.rawValue` uses — actual Tagged-only count is lower; needs filtering at migration time).
- **188 `import Tagged_Primitives` sites** workspace-wide — these are the touchpoints where the parameter rename `RawValue → Underlying` may surface visibly (in extension declarations or generic constraints).

This is roughly 10× larger than the v1.0.0 plan-time prediction. The recommendation is structurally unchanged, but the migration shape carries materially more weight than initially scoped.

### E. Tests, experiments, and DocC across the ecosystem

Every `Experiments/<exp>/Sources/main.swift` that uses `__unchecked:` or `.rawValue` needs updating. Per [EXP-007a], header anchors in those files must be preserved. Mechanical updates are likely cheaper than per-experiment rework, but each experiment must be re-run on the migrated state to revalidate per [EXP-006] / [EXP-007].

DocC articles in `Tagged Primitives.docc/` and any cross-package DocC catalog that references Tagged need migration.

### F. The Research/Audits corpus

Research docs that quote Tagged's API surface (e.g., comparative-analysis-pointfree-swift-tagged.md, tagged-types-merits-completeness-and-naming.md, this very doc) need the API references updated. Per [RES-013a] (Synthesis Verification), each doc reference to `__unchecked:` / `.rawValue` / `RawValue` must be re-verified against the new shape.

The Audits/ corpus, especially any audit that cited Tagged's `__unchecked:` discipline, needs revisiting.

### G. External consumers (forked-from lineage)

Tagged is a fork of `pointfreeco/swift-tagged`. External consumers binding to either the fork (since pre-tag, none yet expected) or the upstream (any number) are unaffected by the fork's redesign — upstream stays as it was.

### Verification commands ([RES-023] empirical-claim verification at execution time)

Before the redesign lands, the following commands MUST produce live counts; the impact assessment numbers above are plan-time predictions:

```bash
# Direct consumer-site usages of __unchecked:
grep -rln "__unchecked" /Users/coen/Developer/swift-primitives/ /Users/coen/Developer/swift-foundations/ /Users/coen/Developer/swift-standards/ 2>/dev/null

# Direct consumer-site usages of .rawValue on Tagged-aliased types
grep -rln "\.rawValue" /Users/coen/Developer/swift-primitives/ 2>/dev/null
# (false positives: rawValue is a stdlib idiom, RawRepresentable.rawValue, etc.; needs filtering)

# Tagged imports across the workspace
grep -rln "import Tagged_Primitives" /Users/coen/Developer/ 2>/dev/null

# RawValue as a generic-parameter reference in extensions on Tagged
grep -rln "where.*RawValue" /Users/coen/Developer/swift-primitives/swift-tagged-primitives/ 2>/dev/null
```

### Migration shape

A reasonable migration shape:

| Phase | What lands | Expected duration |
|---|---|---|
| 1 | V5 ships in `swift-carrier-primitives` (additive, non-breaking) | Single-PR |
| 2 | Tagged adds deprecation aliases for `__unchecked:` and `.rawValue` (`@available(*, deprecated, ...)`) and the renamed surface (`init(_ underlying:)`, `var underlying`); `RawValue` and `Underlying` typealias each other for a transition window; consumer code can migrate incrementally | Single-PR |
| 3 | Downstream packages migrate their internal usage (per the verification-commands grep) | Per-package PR; ecosystem-wide sweep |
| 4 | Tagged removes the deprecated surface; bumps to v0.2.0 (or absorbs into v0.1 if the cohort hasn't tagged yet) | Single-PR |

Phases 1 and 2 can land in either order; Phase 3 requires Phase 2; Phase 4 requires Phase 3 to complete.

### Risk assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Downstream packages break at internal call sites | **CONFIRMED** (~352 files use `__unchecked:` directly; all need migration) | Medium-High | Phase 2's deprecation cycle gives migration warnings before phase 4 removes; mechanical sed-style replacement covers the trivial-self majority |
| Hidden non-Carrier-RawValue Tagged uses become uninhabitable | Low (the 188 Tagged importers nearly all use Carrier RawValues — the trivial-self stdlib conformances and Institute primitives) | Medium | Grep audit pre-migration; affected consumers add one-line trivial-self conformance |
| The `typealias Underlying = Underlying.Underlying` Carrier-conformance line confuses readers | Medium | Low | Document inline; add a `// LHS is the protocol witness, RHS is the cascade through the generic param` comment |
| Test fixtures using `Tagged.init(__unchecked:, ...)` proliferate across the ecosystem | **CONFIRMED** (262 files in swift-primitives outside tagged itself) | Low | Mechanical rewrite; sed-style replacement is safe for the trivial-self pattern `(__unchecked: (), x)` → `(x)` |
| Experiment headers / `_index.json` entries reference the old API | High | Low | Per-experiment header update + revalidation per [EXP-007] |
| Migration scope underestimated; unforeseen call sites surface late | Medium | Medium | Phase 2 deprecation cycle catches surfaces at compile time across the ecosystem; per [HANDOFF-035] the cascade-migration termination criterion is workspace-wide grep-clean + `swift build --build-tests` clean across every transitive consumer |
| `.rawValue` on Tagged versus stdlib `RawRepresentable.rawValue` ambiguity at migration time | Low | Low | Migration tooling distinguishes by type (Tagged-aliased types via the import set); manual review for the ambiguous cases |

## References

### Primary

- [Experiments/generic-throws-init/](https://github.com/swift-primitives/swift-tagged-primitives/tree/main/Experiments/generic-throws-init) — six-variant experiment; commits `2e0308c` and `3686e7c` on `swift-tagged-primitives`.
- [`Tagged+Carrier.swift`](https://github.com/swift-primitives/swift-tagged-primitives/blob/main/Sources/Tagged%20Primitives/Tagged%2BCarrier.swift) — the existing public Carrier-derived init that grounded the v1.1.0 premise correction.
- [Swift SE-0413: Typed Throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md)
- [pointfreeco/swift-tagged](https://github.com/pointfreeco/swift-tagged) — upstream package; the source of the `init(rawValue:)` / `var rawValue:` shape that the Institute fork's `__unchecked:` discipline overlaid.

### Internal cross-references

- [`asymmetric-quadrant-ergonomics-as-rejection-criterion.md`](./asymmetric-quadrant-ergonomics-as-rejection-criterion.md) — quadrant-uniformity precedent for V5 adoption.
- [`cross-domain-init-overload-resolution-footgun.md`](./cross-domain-init-overload-resolution-footgun.md) — overload-resolution discipline; supports surface-simplification.
- [`carrier-launch-skill-incorporation-backlog.md`](./carrier-launch-skill-incorporation-backlog.md) — Carrier launch as learning event; supports landing the redesign within the cohort.
