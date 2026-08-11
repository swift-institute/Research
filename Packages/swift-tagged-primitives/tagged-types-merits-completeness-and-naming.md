# Tagged Types — Merits, Completeness, and Naming

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: RECOMMENDATION
tier: 2
---
-->

## Context

`swift-tagged-primitives` is a pre-0.1.0 tag candidate. The last systematic audit (`swift-institute/Research/audits/implementation-naming-2026-03-20/swift-small-packages-batch.md`) returned CLEAN but predates three structural changes: the rename from `swift-identity-primitives` → `swift-tagged-primitives` (commit `0d6d0f9`), the generic widening to admit `~Escapable` Tag and Underlying (commit `1cf5396`), and the migration from the bespoke `Viewable` protocol to the unified `Ownership.Borrow.\`Protocol\`` (commit `9ac9b04`).

Before cementing the 0.1.0 API surface — load-bearing across ~308 call-site files in `swift-primitives`, ~12 in `swift-foundations`, and ~5 in `swift-standards` — this document asks three questions the prior audit was not structured to answer:

1. **Merit** — does `Tagged<Tag, Underlying>` occupy a unique position in the design space? What would be lost if it didn't exist, or if consumers adopted Point-Free's `swift-tagged` instead?
2. **Completeness** — is there a Tagged-adjacent primitive that SHOULD exist but doesn't?
3. **Naming** — does every public declaration pass the diametric-collision check against Rust / Swift stdlib / Point-Free vocabulary? Does the rename from `swift-identity-primitives` → `swift-tagged-primitives` carry its weight?

The document also enumerates the design lattice the type claims to support and marks which cells are exercised by tests and experiments, which are covered by conformance signatures alone, and which are genuinely absent.

### Trigger

[RES-012] Discovery. The 0.1.0 tag cements the current shape for the ecosystem. A merit / completeness / naming pass is warranted before the tag, symmetric with the parent session's ownership-primitives pre-tag audit (which produced `swift-ownership-primitives/Research/ownership-types-merits-completeness-and-naming.md`).

### Scope

Package-specific ([RES-002a]). Cross-ecosystem implications (the ordinal / cardinal / affine specialisations that live in sibling packages) are referenced but not re-decided here.

## Prior Art

- `comparative-analysis-pointfree-swift-tagged.md` (DECISION, 2026-02-26) — full dimension-by-dimension comparison. Summary: every divergence from Point-Free is principled (type safety, `~Copyable` support, Foundation independence, zero-cost verification). Not replayed here; cited where relevant.
- `tagged-literal-conformances-fresh-perspective.md` (RECOMMENDATION, 2026-04-21) — literal-conformance lattice cell currently resolved as "test-only". Not re-litigated.
- `swift-property-primitives/Research/property-tagged-semantic-roles.md` — the canonical domain-identity vs verb-namespace taxonomy that separates `Tagged` from `Property<Tag, Base>`. `Tagged` is the domain-identity member of that pair; this document treats the taxonomy as settled.
- `swift-carrier-primitives/Research/capability-lift-pattern.md` — super-protocol unification analysis; outcome deferred. Tagged and Property remain separate nominal types.

## Analysis

### 1. Merit

The merit question has three sub-forms: merit vs an alternative wrapper library, merit vs hand-rolled per-domain newtypes, and merit vs related ecosystem types that occupy adjacent positions in the lattice.

#### 1.1 Merit vs Point-Free's `swift-tagged`

Resolved by `comparative-analysis-pointfree-swift-tagged.md` (DECISION, 2026-02-26) and re-confirmed for 0.1.0:

| Dimension | Our delta | Merit verdict |
|-----------|-----------|---------------|
| `~Copyable` / `~Escapable` support in Tag AND Underlying | Both admitted | **Distinctive** — neither stdlib's `RawRepresentable` nor `pointfreeco/swift-tagged` admits this; both predate Swift's noncopyable-generics features (SE-0427, SE-0446). Required for `Index<Element>` where `Element: ~Copyable`. |
| Zero-cost verification | `@inlinable` + `@usableFromInline` + codegen experiment + 7 MemoryLayout proof tests | **Superior** — Point-Free claims zero-cost; we prove it. |
| Operator non-forwarding | Deliberate | **Diverges** — Point-Free ships `Numeric` / `AdditiveArithmetic` / `Strideable`. We don't. The divergence is the safety guarantee: if `Tagged<Graph, Int>` conformed to `Numeric`, `Index<Graph> + Index<Bit>.Count` would compile. |
| Typed throws | `throws(E)` on `map` | **Superior** — Point-Free's `rethrows` erases to `any Error`. |
| Foundation dependency | None | **Required** — primitives layer per [PRIM-FOUND-001]. |

The two libraries are not substitutable. A consumer that needs `Index<MoveOnlyElement>` cannot use Point-Free's `Tagged`; it cannot be expressed. A consumer that needs blanket `Numeric` on `Tagged<Tag, Int>` cannot use ours by design. The merit verdict is **occupies-a-distinct-position-in-the-design-space**, not **strictly-better-than**.

#### 1.2 Merit vs hand-rolled per-domain newtypes

The hand-rolled alternative is one struct per domain:

```swift
public struct UserID: Hashable, Codable {
    public let underlying: UInt64
    public init(_ underlying: UInt64) { self.underlying = underlying }
}
public struct OrderID: Hashable, Codable {
    public let underlying: UInt64
    public init(_ underlying: UInt64) { self.underlying = underlying }
}
// ... repeated N times
```

`Tagged` collapses this to:

```swift
public enum User {}
public enum Order {}
typealias UserID  = Tagged<User,  UInt64>
typealias OrderID = Tagged<Order, UInt64>
```

| Comparison | Hand-rolled | Tagged |
|------------|-------------|--------|
| Lines per domain | ~10 (struct + init + conformances) | 2 (enum + typealias) |
| Functor operations | Missing (every domain re-implements) | `map`, `retag` uniformly |
| `~Copyable` support | Per-domain effort | Automatic |
| Ecosystem composition | None — `Set<UserID>` cannot use a shared `UserID`-indexed storage with `OrderID` because they are nominally distinct | `Tagged`-indexed infrastructure (boundary overloads, test support literals) works for every domain |
| Ecosystem reach | ~300 call sites would each pay the hand-roll cost | One central declaration; call sites pay nothing |

**Merit verdict**: hand-rolled newtypes scale linearly in boilerplate and do not compose across domains. `Tagged` is the centralized alternative.

#### 1.3 Merit vs adjacent ecosystem types

Three adjacent types occupy nearby positions. The distinctions matter for completeness analysis (§2):

| Type | Position | Confusable with Tagged? |
|------|----------|-------------------------|
| `Property<Tag, Base>` (swift-property-primitives) | Verb-namespace phantom wrapper; same shape, different role | Yes — same structural form. Disambiguated by `property-tagged-semantic-roles.md`. See the dedicated `Phantom-Tag-Semantics.md` DocC article. |
| `Ownership.Borrow<Value>` / `Ownership.Inout<Value>` | Lifetime-bounded reference (`~Escapable`) | No — phantom-tag wrappers are values; Ownership types are references with a lifetime contract. `Tagged<T, Ownership.Inout<V>>` is a common composition (see swift-property-primitives). |
| `Reference.Box<Value>` (swift-reference-primitives) | Heap-allocated indirection | No — orthogonal. Used where move-only values must appear in `Copyable`-constrained contexts. |

The only genuine adjacency is `Property`. The two-type split is preserved because a unified `PhantomTagged<Tag, Value, Role>` would collapse the extension-namespace boundary — `extension Property<Push, Stack>` would bleed into `Tagged<Ordinal, Int>` and vice versa. See the taxonomy research.

### 2. Completeness

The brief asks: is there a Tagged-adjacent primitive that SHOULD exist but doesn't?

#### 2.1 `Tagged.Set` / `Tagged.Dictionary` — DO NOT EXIST, principled absence

A naive expectation: because `Tagged<Tag, Int>` is `Hashable` when `Int` is, there should be a `Tagged.Set<Tag, Element>` that discriminates `Set` instances by `Tag` in the same way `Tagged<Tag, Int>` discriminates `Int` values.

This is already possible without a new primitive. The phantom tag composes through standard-library collections:

```swift
typealias PerUserQuota = Tagged<User, Set<String>>    // tagged set
typealias PerOrderMap  = Tagged<Order, [String: Int]> // tagged dictionary

// Or, equivalently:
typealias UserIDs  = Set<Tagged<User,  UInt64>>   // set of tagged values
typealias OrderIDs = Set<Tagged<Order, UInt64>>   // set of tagged values
```

Two orthogonal compositions — "tag the whole collection" vs "tag each element" — both work. A dedicated `Tagged.Set` primitive would conflate the two or force a choice. **Principled absence**.

#### 2.2 Typed ordinal / cardinal / affine specialisations — EXIST, in sibling packages

`Index<Element>`, `Index<T>.Count`, `Index<T>.Offset`, `Memory.Address`, `Bit.Index`, `Hash.Value` are all `Tagged` typealiases, but they live in `swift-ordinal-primitives`, `swift-cardinal-primitives`, `swift-affine-primitives`, `swift-bit-index-primitives`, `swift-identity-primitives`, and `swift-hash-primitives` respectively. The specialisations exist; `swift-tagged-primitives` exports the substrate only.

This is correct per the tier architecture: `Tagged` is tier 0 / tier 1 (see §2.6 below on the ownership dependency); the specialisations are tier 3+ where the ordinal / cardinal / affine concepts are defined. A `Tagged.Index` re-export in this package would duplicate the downstream typealiases and create cross-layer coupling.

**Principled split**, not a gap.

#### 2.3 `Tagged.Range<Tag, Bound>` — DOES NOT EXIST, non-obvious absence

A typed range — `for i in (start: Index<Graph> ..< end: Index<Graph>)` — is currently expressed via `Swift.Range<Index<Graph>>`, which works only when the bound conforms to `Strideable`. Per `comparative-analysis-pointfree-swift-tagged.md` §3.2, `Tagged: Strideable` is a principled absence (stride semantics are domain-specific), but `swift-index-primitives/Research/Strideable Index Design.md` (DECISION, 2026-01-28) approved `Index: Strideable where Tag: ~Copyable` at the specialisation layer.

Today: the range machinery lives in `swift-index-primitives`, not here. This package ships the phantom-type substrate only.

**Not a gap in `swift-tagged-primitives`.** The `Strideable`-adjacent question is settled in `swift-index-primitives`.

#### 2.4 Missing literal conformances — RESOLVED, test-only quarantine

`tagged-literal-conformances-fresh-perspective.md` (RECOMMENDATION, 2026-04-21) re-examined the question. The current position (literals in Test Support only) is RECOMMENDED as Option A with a narrow margin over Option B (production literals with 3 non-identity label fixes). This document does not re-litigate.

**Deferred to the existing literal-conformances research corpus.**

#### 2.5 Functor laws — EXPLICITLY TESTED, structurally guaranteed

Both functor laws are tested (`Tagged Tests.swift` lines 302–317):

- Identity: `tagged.map { $0 } == tagged`
- Composition: `tagged.map { f(g($0)) } == tagged.map(g).map(f)`

The bifunctor structure (covariant in Underlying via `map`, phantom-varying in Tag via `retag`) is complete. `retag` laws (round-trip, associativity across three tags) are also tested (lines 322–336). No gap.

#### 2.6 Ownership-primitives relationship — conformance migrated, tagged stays atomic (revised 2026-04-24)

Earlier revisions of this document recorded `swift-tagged-primitives` as depending on `swift-ownership-primitives` via an in-package conformance file. A subsequent review concluded the dependency direction was ecosystem-inconsistent: other specialist primitives (`swift-ordinal-primitives`, `swift-format-primitives`) host their own `Tagged` extensions and conformances, depending on `swift-tagged-primitives`, rather than forcing `swift-tagged-primitives` to know about them. Ownership was the one outlier. The `Tagged: Ownership.Borrow.\`Protocol\`` conformance was moved to `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Tagged+Ownership.Borrow.Protocol.swift` in the coordinated commits of 2026-04-24.

Post-move state:

- `swift-tagged-primitives` ships with **zero external dependencies** — it's back at tier 0 in the strict zero-dependency sense.
- `swift-ownership-primitives` adds `swift-tagged-primitives` as a package-level dependency, scoped to the `Ownership Borrow Primitives` target only.
- Wrapper transparency is preserved: any consumer that imports `swift-ownership-primitives` (directly or transitively) sees `Tagged<Tag, X>.Borrowed == X.Borrowed` whenever `X` conforms.

Ecosystem consistency argument: `Tagged` is an atomic wrapper substrate. Specialist protocol / behavior packages (ordinal, cardinal, format, ownership, …) extend `Tagged` for their own `Underlying`-specific concerns; they depend on tagged-primitives, not the reverse. This matches the "Tagged's core claim is transparency over stdlib capabilities; ecosystem-protocol transparency is the specialist's responsibility" principle.

**Net effect**: the cross-package "tier table stale" finding that earlier revisions flagged is resolved — tagged-primitives is back at tier 0, no ecosystem-wide documentation update needed.

### 3. Naming

The diametric-collision check compares every public declaration against Rust / Swift stdlib / Point-Free vocabulary. A collision is present when a Swift-fluent reader would misread the declaration.

#### 3.1 Package name: `swift-tagged-primitives`

| Source | Name | Meaning | Collision? |
|--------|------|---------|-----------|
| Point-Free (Swift) | `swift-tagged` | Phantom-tag wrapper | **Precedent** — "Tagged" is the established vocabulary in the Swift ecosystem for this concept. |
| Rust | `std::marker::PhantomData<T>` | Phantom parameter marker | No collision — different name, adjacent concept. |
| Haskell | `newtype` keyword | Phantom-tag wrapper via language feature | No collision. |
| OCaml | Module-level type abstraction | Phantom-tag via abstraction | No collision. |

Decision test per [PKG-NAME-005]: "Tagged" is the shortest natural noun. Alternatives:

| Candidate | Noun? | Gerund? | Available? | Verdict |
|-----------|-------|---------|------------|---------|
| `Tagged` | Adjective-as-noun; past participle functioning as noun (the tagged value) | No | Clear (Point-Free precedent) | **Chosen** |
| `Tag` | Noun | No | Shadows common stdlib parameter name `Tag`; would collide with the `Tag` generic parameter | Reject |
| `Tagging` | Noun (gerund) | Yes | Valid English gerund | Reject per [PKG-NAME-001] gerund prohibition |
| `Identity` | Abstract noun | No | Former name (`swift-identity-primitives`); does not name the type | Reject — abstract, did not describe what the package contains |

The rename `swift-identity-primitives` → `swift-tagged-primitives` (commit `0d6d0f9`) is principled:
- The package contains exactly one public type, `Tagged`. Naming the package after the type it ships mirrors `swift-property-primitives` (primary type: `Property`) and `swift-ownership-primitives` (primary namespace: `Ownership`).
- "Identity" was a category label; "Tagged" names the type. Per [PKG-NAME-005] shortest natural noun, the type's name wins.
- External compatibility per [PKG-NAME-003] is NOT claimed — this is not a Point-Free shim. The name alignment with Point-Free's `swift-tagged` is coincidental and beneficial (readers transferring knowledge) but not a constraint.

**Verdict**: package name correct.

#### 3.2 Top-level type: `Tagged<Tag, Underlying>`

Per [API-NAME-001] Nest.Name: the type does not nest under a namespace. This is consistent with tier 0 / tier 1 packages whose single public type IS the namespace (`Cardinal`, `Ordinal`, `Bit`). **No nest violation.**

Generic parameters:

| Parameter | Role | Collision? |
|-----------|------|-----------|
| `Tag` | Phantom discriminator | Shadows stdlib's convention of `Tag` in `Result` generics, but `Tagged` is the consuming context, not a conflict. |
| `Underlying` | Wrapped value | Shadows Swift's `RawRepresentable.Underlying`. The similarity is deliberate — `underlying` the property is conceptually aligned with `RawRepresentable.underlying`. We intentionally do NOT conform to `RawRepresentable` (see `comparative-analysis-pointfree-swift-tagged.md` §3.1); the name reuse is semantic alignment without conformance. **Not a collision.** |

**Verdict**: type + generic parameter names correct.

#### 3.3 Public declarations on `Tagged`

Enumerating every public declaration in `Sources/Tagged Primitives/`:

| Declaration | Kind | Naming check | Verdict |
|-------------|------|--------------|---------|
| `Tagged<Tag, Underlying>` | struct | §3.2 | ✓ |
| `underlying` | computed property (Carrier.\`Protocol\` witness) | Matches `Carrier.\`Protocol\`.underlying` by design; does NOT conform to `RawRepresentable` (principled) | ✓ |
| `init(_unchecked: consuming Underlying)` | package-internal init | `_unchecked` prefix signals "not domain-validated"; access level is `package`, so external consumers go through the public `Carrier.\`Protocol\``-derived `init(_ underlying:)` instead | ✓ — documents the semantic contract |
| `map(_:)` instance | consuming func | Swift stdlib precedent (`Optional.map`, `Sequence.map`); same semantics (functor map) | ✓ — aligned vocabulary |
| `map(_:transform:)` static | func | `static map` per [IMPL-023] (core logic lives on the static) | ✓ |
| `retag(_:)` instance | consuming func | Not in Swift stdlib; matches Rust's phantom-rename convention; more precise than Point-Free's `coerced(to:)` (changes the tag, not the value) | ✓ — correct vocabulary, precise |
| `retag(_:to:)` static | func | Paired with instance; [IMPL-023] | ✓ |
| `max(_:_:)` static | func | Swift stdlib precedent (`max`); same semantics | ✓ |
| `min(_:_:)` static | func | Same | ✓ |
| `description` | computed property (CustomStringConvertible) | Swift stdlib vocabulary | ✓ |
| (The `Tagged: Ownership.Borrow.\`Protocol\`` conformance moved to `swift-ownership-primitives` in 2026-04-24; see §2.6. The `Borrowed` typealias is defined there, not here.) | — | — | — |

No compound identifiers, no gerund forms, no `*Tag` suffix (per `feedback_no_tag_suffix`). **All surface declarations pass.**

#### 3.4 Extension file naming

| File | Compound check | Nested path | Verdict |
|------|----------------|-------------|---------|
| `Tagged.swift` | No compound | `Tagged` | ✓ |
| `Tagged+CustomStringConvertible.swift` | `+` suffix per [API-IMPL-007] | Extension | ✓ |

The former `Tagged+Ownership.Borrow.Protocol.swift` (noted in earlier revisions) moved to `swift-ownership-primitives` per §2.6. The extension-filename conventions discussed there (dotted-nested-path preservation) apply equally in ownership's home — `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Tagged+Ownership.Borrow.Protocol.swift` preserves the triple-dotted conformance path rather than flattening it.

**Verdict**: the two remaining source filenames pass unambiguously.

#### 3.5 Sendable doc comment

`Tagged.swift` line 77: `extension Tagged: Sendable where Tag: ~Copyable & ~Escapable, Underlying: ~Copyable & Sendable & Escapable {}`

No `@unchecked`; no `@unsafe`. The Sendable conformance is fully synthesised by the compiler per [MEM-SEND-004] — `Tagged` stores exactly one field, and when that field is `Sendable`, the containing type is structurally `Sendable`. **No workaround to revalidate.**

#### 3.6 `modify` package-internal method

`Tagged.swift` line 57: `package mutating func modify<T>(_ body: (_ underlying: inout Underlying) -> T) -> T`

The name `modify` is a Swift reserved-word-adjacent (coroutine `_modify`) but does not collide — it is a regular method with a closure parameter that captures `inout Underlying`. The comment explains why it is `package`-visible rather than `public`: consumer sites should use the `underlying` coroutine instead. **Correct name + access level.**

The associated comment (lines 49–54) notes the Swift 6.3 closure-parameter-lifetime gap for `~Escapable` types. This is a language-limitation claim — it belongs in Phase 3 workaround revalidation.

### 4. Five-axis design lattice

The brief asks: for Tagged the axes are narrower than ownership's lifecycle-axis lattice — enumerate the design axes Tagged claims to support and mark which cells are exercised.

The seven axes:

1. **Tag copyability**: `Tag: Copyable` OR `Tag: ~Copyable`
2. **Tag escapability**: `Tag: Escapable` OR `Tag: ~Escapable`
3. **Underlying copyability**: `Underlying: Copyable` OR `Underlying: ~Copyable`
4. **Underlying escapability**: `Underlying: Escapable` OR `Underlying: ~Escapable`
5. **Sendable conditional**: `Underlying: Sendable`
6. **Literal conformances (test support only)**: `Underlying: ExpressibleBy*Literal`
7. **Equatable / Hashable / Comparable / CustomStringConvertible / Codable / BitwiseCopyable**: `Underlying: X`

The phantom Tag contributes no runtime behavior; axes 1–2 only affect which generic extensions apply. The real discrimination happens on axes 3–4. The cross product of axes 3 × 4 produces four cells:

| Cell | Underlying | Conformance shape | Use case | Coverage |
|------|----------|-------------------|----------|----------|
| A | `Copyable & Escapable` | Full conditional stack: Copyable, Sendable, Equatable, Hashable, Comparable, Codable, BitwiseCopyable, CustomStringConvertible | Typical: `UserID`, `Index<Element>`, `Hash.Value` | **Fully tested** — 5 MemoryLayout tests, all conformance tests, functor laws, total-order laws |
| B | `~Copyable & Escapable` | Equatable + Hashable + Comparable + CustomStringConvertible (via SE-0499 ~Copyable support in compiler 6.4+); no Codable, no BitwiseCopyable, no Sendable synthesis | Move-only value domain: `Tagged<T, FileDescriptor>` | **Tested** — 5 Integration tests + 1 MemoryLayout test; SE-0499 conditional via `#if compiler(>=6.4)` |
| C | `Copyable & ~Escapable` | `Tagged: ~Escapable` (derived) — no Sendable, no Codable, no BitwiseCopyable | Scoped-value domain: borrowed spans, lifetime-bounded views | **Structurally covered**; no dedicated test — declaring an `~Escapable Copyable` Underlying in tests triggers lifetime annotation requirements. Declaration correctness verified by compile-time conformance signatures. |
| D | `~Copyable & ~Escapable` | `Tagged: ~Copyable, ~Escapable` (both derived) — minimal conformance set | Scoped + move-only: `Ownership.Borrow<T>` wrapped | **New Phase 1 test** (`Tagged admits ~Escapable Underlying in MemoryLayout`) covers layout; **Ownership.Borrow.\`Protocol\` conformance test** exercises this cell indirectly. |

Axes 1–2 (Tag variation) are orthogonal: every extension specifies `Tag: ~Copyable & ~Escapable`, so the Tag axis does not partition the lattice into additional cells — it lifts the universality.

**Lattice coverage verdict**:

| Cell | Coverage | Finding |
|------|----------|---------|
| A | Fully tested | None |
| B | Fully tested | None |
| C | Structural only | **MEDIUM finding** — no dedicated runtime test for `~Escapable Copyable` Underlying. The conformance declaration (`Tagged: Escapable where ... Underlying: Escapable & ~Copyable`, Tagged.swift line 68) is compile-time-verified whenever a consumer instantiates it; no ecosystem consumer currently does. |
| D | Layout tested + conformance tested | None (the Phase 1 Ownership.Borrow.\`Protocol\` test is in this cell) |

Axis 7 (individual conformances): every conformance is exercised in the existing 54 pre-existing tests plus the 5 Phase 1 additions.

Axis 5 (Sendable) and axis 6 (literal conformances) are tested.

### 5. Diametric-collision summary

Consolidated from §3:

| Candidate collision | Assessment |
|---------------------|-----------|
| `Tagged` vs Point-Free `Tagged` | Same vocabulary, disjoint implementations. Benefits readers. |
| `Tagged.underlying` vs `RawRepresentable.underlying` | Same name, no conformance. Deliberate semantic alignment, no collision. |
| `Tag` generic parameter vs stdlib conventional `Tag` in `Result` | Same vocabulary, local scope. No collision. |
| `map` method | Swift stdlib vocabulary (`Optional.map`, `Sequence.map`). Aligned. |
| `retag` method | Novel in Swift stdlib; closest relatives are Rust's newtype renames. Coinage. |
| `max` / `min` statics | Swift stdlib vocabulary; avoids verbose `Swift.max(a, b)` annotations. Aligned. |
| `Borrowed` typealias | `Ownership.Borrow.\`Protocol\`` associated type. Uniform across ecosystem. |

**No diametric collisions flagged.**

## Constraints

- **[PRIM-FOUND-001]** — Foundation-independent; this document cannot recommend any addition that imports Foundation.
- **Ecosystem reach** — ~308 call sites in swift-primitives alone. 0.1.0 cements the API surface; additions are cheaper than removals.
- **Tier placement** — with the 2026-04-24 conformance move (§2.6), swift-tagged-primitives is back at tier 0 (zero external dependencies). The `primitives` skill's Tier 0 enumeration remains accurate.
- **`Tagged.modify` `package mutating` method** exists as a package-internal escape hatch. Removing it would require auditing in-package consumers (none currently) but preserves the `public var underlying` coroutine as the sole mutable-access path.

## Outcome

**Status**: RECOMMENDATION.

### Merit

`Tagged<Tag, Underlying>` occupies a **distinct, load-bearing position** in the ecosystem design space:

- Vs Point-Free `swift-tagged`: different design priorities; this package adds `~Copyable`/`~Escapable` support, zero-cost verification, and Foundation-free operation at the cost of convenience conformances. Not substitutable.
- Vs hand-rolled per-domain newtypes: collapses O(N) domain boilerplate to O(1) tag declarations, with shared functor operations.
- Vs adjacent ecosystem types: the only real adjacency is `Property<Tag, Base>`, resolved by the domain-identity vs verb-namespace taxonomy.

**No merit concerns blocking 0.1.0.**

### Completeness

The completeness analysis surfaces **one non-blocking cross-package finding** (ecosystem-wide tier table is stale post-`9ac9b04`) and confirms that every lattice cell the package claims to support is either tested or structurally covered.

**No completeness gaps blocking 0.1.0.** Tier table update should be tracked as a follow-up in `swift-primitives/Documentation.docc/`, not in this package.

### Naming

**No naming changes for 0.1.0.** Every public declaration passes the diametric-collision check. The rename from `swift-identity-primitives` → `swift-tagged-primitives` is principled per [PKG-NAME-005] (shortest natural noun) and [PKG-NAME-001] (noun form, not gerund). The only Tagged-related extension file in this package is `Tagged+CustomStringConvertible.swift`; the `Tagged: Ownership.Borrow.Protocol` conformance file lives in `swift-ownership-primitives` per §2.6.

### Lattice

- **Cells A, B, D**: fully covered.
- **Cell C (`~Escapable Copyable` Underlying)**: structural-only coverage. **Finding — MEDIUM**: add a test that declares a `Copyable & ~Escapable` Underlying (a borrowed span or similar) and verifies `Tagged.underlying` access through a `borrowing` binding. Deferred to Phase 4 or post-0.1.0; the conformance signature is correct and the absent test is a coverage gap, not a correctness gap.

### What this document does NOT decide

- Literal conformance production migration (deferred to `tagged-literal-conformances-fresh-perspective.md`).
- Tier table updates in `swift-primitives/Documentation.docc/` (cross-package; out of scope).
- Whether the `modify` `package` method should widen or narrow before 0.1.0 (no in-package consumers currently; leave as-is).

## References

- `comparative-analysis-pointfree-swift-tagged.md` (DECISION, 2026-02-26)
- `tagged-literal-conformances-fresh-perspective.md` (RECOMMENDATION, 2026-04-21)
- `revisiting-tagged-production-literal-conformances.md` (DECISION, 2026-03-04)
- `tagged-literal-conformances.md` (DECISION, 2026-03-04)
- `swift-property-primitives/Research/property-tagged-semantic-roles.md` (DECISION, 2026-03-17) — canonical domain-identity vs verb-namespace taxonomy
- `swift-carrier-primitives/Research/capability-lift-pattern.md` — super-protocol unification deferred
- `swift-institute/Research/ownership-borrow-protocol-unification.md` (IMPLEMENTED, 2026-04-23) — the unification that first introduced `Tagged: Ownership.Borrow.\`Protocol\``
- `Sources/Tagged Primitives/Tagged.swift`
- `Sources/Tagged Primitives/Tagged+CustomStringConvertible.swift`
- `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Tagged+Ownership.Borrow.Protocol.swift` (conformance file, relocated 2026-04-24)
- `Tests/Tagged Primitives Tests/Tagged Tests.swift` — 58 tests (54 pre-existing + 4 Phase 1 conformance additions; the Ownership.Borrow.\`Protocol\` conformance test moved to `swift-ownership-primitives/Tests/Ownership Primitives Tests/Tagged+Ownership.Borrow.Protocol Tests.swift`)
- `Experiments/tagged-zero-cost-codegen/` (CONFIRMED, Swift 6.2) — codegen verification
- `Experiments/tagged-noncopyable-rawvalue/` (CONFIRMED, Swift 6.2) — ~Copyable Underlying verification
- `Experiments/tagged-literal-footgun-6-3-revalidation/` (PARTIAL, Swift 6.3.1) — footgun re-verified
