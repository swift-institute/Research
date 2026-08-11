# Tagged Literal Conformances — Fresh Perspective

<!--
---
version: 1.1.0
last_updated: 2026-04-30
status: RECOMMENDATION
tier: 2
---
-->

<!--
Changelog:
- v1.1.0 (2026-04-30, addendum): policy reconciliation per
  `sli-literal-vs-strideable-tradeoff.md` (DECISION 2026-04-30).
  Production-grade literal conformances now ship via the
  `Tagged Primitives Standard Library Integration` (SLI) target,
  not via the v3.0 label-the-3 plan. The SLI choice corresponds to
  Option E (consumer opt-in) reframed: previous v1.0 dismissed
  Option E as "empirically refuted" because the consumer-side
  conformance attempt failed structurally (`tagged-literal-consumer-
  opt-in` experiment); the SLI form succeeds because the conformance
  is authored CENTRALLY in the package's own SLI target rather than
  by the consumer. Strideable is excluded from SLI to keep the
  literal-conformance footgun dormant for SLI-only consumers; per-
  domain Strideable on Index types remains approved at the swift-
  index-primitives layer (constraint 6 unchanged). The "Constraints
  6: Strideable must coexist" framing is preserved at the per-domain
  level (Index: Strideable per `swift-index-primitives/Research/
  Strideable Index Design.md`); generic Tagged: Strideable is no
  longer co-shipped with literal conformances at the same import
  layer. Residual footgun risk: when a consumer also brings in a
  package adding Strideable to a Tagged-aliased type, the misfire
  reactivates on those types specifically — narrower blast radius
  than v1.0's worry that any Strideable landing reactivates it
  globally.
- v1.0.0 (2026-04-21): initial fresh-perspective analysis. Outcome
  was leaning Option A (do nothing) or Option B (v3.0 label-the-3
  with honest cost accounting). Both paths were predicated on
  shipping literals in main; the SLI mechanism (added 2026-04-30
  with the SLI module assembly) gives a third path that v1.0 didn't
  consider because SLI didn't exist yet.
-->

## Context

`tagged-literal-conformances.md` v3.0 (2026-03-04, DECISION) and its companion
`revisiting-tagged-production-literal-conformances.md` v2.0 (DECISION, same date)
approved moving `ExpressibleByIntegerLiteral` / `ExpressibleByFloatLiteral` from
test support to production on `Tagged`, contingent on labeling 3 non-identity
cross-domain inits (`Bit.Index.init(byte:)`, `Memory.Shift.init(count:)`,
`Affine.Discrete.Ratio.init(stride:)`). As of 2026-04-21 none of those labels
have been applied and the conformance remains test-only.

Picking this work up again, a fresh examination produced three empirical findings
that materially change the decision landscape from v3.0:

1. The footgun is currently dormant for a *structural* reason v3.0 did not call out.
2. That structural reason disappears the moment we add a separately-motivated and
   already-approved feature (`Strideable` on `Tagged` per
   `swift-index-primitives/Research/Strideable Index Design.md` DECISION).
3. Every remaining mitigation path (marker protocol, struct wrappers, consumer
   opt-in, label-the-3) carries a cost that v3.0 understated.

This document captures those findings, re-enumerates the available options with
corrected cost accounting, and offers a recommendation. It does not supersede
v3.0 — it augments it. v3.0's label-the-3 plan is still one of the two surviving
recommendations; the difference is that v3.0 presented it as nearly free, and it
isn't.

### Trigger

[RES-001] Implementation blocked. Consumers (Time.Offset, SVG coordinate types,
angle types) want ergonomic literal construction. The v3.0 plan has not been
executed, and re-examining it surfaced the findings above.

## Question

Can we enable production `ExpressibleByIntegerLiteral`/`ExpressibleByFloatLiteral`
on `Tagged` — together with the already-approved `Strideable` conformance — while
preventing the confirmed cross-domain overload resolution footgun, without paying
costs that outweigh the ergonomic gain?

## Analysis

### 1. Fresh examination — three findings v3.0 missed

#### Finding 1: The footgun is currently dormant due to Strideable's absence

The confirmed 2026-02-11 footgun chain was:
```
(0..<5).map(Bit.Index.init)
    → Swift finds unlabeled init(_: Index<UInt8>) on Bit.Index
    → Index<UInt8> conforms to ExpressibleByIntegerLiteral via test-support
    → 0..<5 inferred as Range<Index<UInt8>>  ← requires Index<UInt8>: Strideable
    → each element passes through ×8 scaling
    → crash
```

Step 4 requires `Index<UInt8>: Strideable` — `Range<T>` is a `Sequence` only
when `T: Strideable where Stride: SignedInteger`. Production `Tagged`
*deliberately omits* `Strideable` (see `comparative-analysis-pointfree-swift-tagged.md`
§3.2). Production `Ordinal` is not `Strideable` either. So in the current
ecosystem the inference chain cannot complete.

Verified 2026-04-21 via experiment
`tagged-literal-footgun-6-3-revalidation/production-reality-check`: with real
`Bit.Index` + `Tagged Primitives Test Support` (which provides the blanket
literal conformance), `(0..<5).map(Bit.Index.init)` produces `["0","1","2","3","4"]`
(the correct `integerLiteral` path), *not* the `[0, 8, 16, 24, 32]` byte-to-bit path.

#### Finding 2: Adding Strideable reactivates the footgun

`swift-index-primitives/Research/Strideable Index Design.md` (2026-01-28,
DECISION) proposes `extension Index: Strideable where Tag: ~Copyable`.
`Index<Tag>` represents a position and striding through positions is
semantically valid. The conformance has not yet been applied, but it is
architecturally approved — `for i in byteRange` ought to work.

Experiment `tagged-literal-footgun-6-3-revalidation` Variant 1, with
`Tagged: Strideable` added to the minimal repro:
`(0..<5).map(BitIndex.init) = [0, 8, 16, 24, 32]` — **footgun reproduces**.

Crucially, `@_disfavoredOverload` on the literal init does *not* prevent this
(Variant 1 and Variant 4 both had the attribute and both produced the wrong
values). This matches the prior finding from
`literal-vs-throwing-init-disambiguation` (2026-03-19) that the attribute
affects ranking among equally-applicable candidates but does not override
resolution when one candidate is uniquely matched.

Implication: the current safety is accidental. Any of the independently-motivated
improvements (`Strideable`, production literal, `Time.Offset` construction) is
*individually* fine; the *combination* re-enables the footgun.

#### Finding 3: Consumer-side opt-in is structurally impossible at scale

One seemingly attractive escape hatch: ship tagged-primitives with no blanket
literal conformance, let each consumer package add
`extension Tagged: ExpressibleByIntegerLiteral where Tag == MyTag, Underlying == Int`
for its own types. This is structurally rejected by Swift.

Experiment `tagged-literal-consumer-opt-in` — verified 2026-04-21:

| Scenario | Result |
|---|---|
| ConsumerA alone adds conformance for `Tagged<UserTag, UInt32>` | Compiles ✓ |
| ConsumerA + ConsumerB both imported, each with disjoint constraints | **Compile error**: "type alias 'X' requires the types 'CoordTag' and 'UserTag' be equivalent" |

Swift's "one conditional conformance per (type, protocol) pair" rule applies
across module boundaries. Two consumer packages each adding a conformance with
mutually exclusive constraints cannot coexist in the same program. Exactly one
package in the whole build graph can own `Tagged`'s literal conformance.

This closes the "distribute the decision to consumers" door. Ownership is
centralized whether we like it or not.

### 2. The corrected option set

With the three findings above, the viable options are:

#### Option A — Do nothing (status quo)

Ship Tagged without production literal conformance. Keep the quarantine in
`Tagged Primitives Test Support`.

| Criterion | Assessment |
|---|---|
| Production literals on Tagged | No |
| Footgun risk | None — structurally impossible |
| Strideable compatible | Yes (Strideable alone doesn't reproduce footgun without literal conformance) |
| Consumer cost | Convenience-init wrapping at each literal-needing site (e.g., `Time.Offset(years: Int, ...)` accepting `Int` and wrapping internally) |
| Aligns with [IMPL-010] "Push Int to the Edge" | Yes |

#### Option B — v3.0 plan (label 3 non-identity inits + add blanket)

Add blanket `ExpressibleByIntegerLiteral` / `ExpressibleByFloatLiteral`. Label
the 3 non-identity cross-domain inits (`byte:`, `count:` / `bits:`, `stride:`).
Codify the convention "unlabeled `init(_:)` on Tagged MUST preserve numeric
identity; non-identity conversions MUST be labeled."

| Criterion | Assessment |
|---|---|
| Production literals on Tagged | Yes |
| Footgun risk | Low — 3 known footgun sites closed; future regressions prevented only by convention + review |
| Strideable compatible | Yes, with labels in place |
| Consumer cost | 3 labels + 1 `Cardinal.Protocol` conformance removal (`Memory.Shift` violates round-trip contract; see §3) |
| Convention decay risk | Real — a future developer adding a new unlabeled non-identity cross-domain init reopens the footgun class |

Updated honest cost compared to v3.0: the 3 labels ARE labels, however small the
count, and the ecosystem has explicit feedback against gratuitous labeling. The
labels here are defensible because the operations (×8 scaling, narrowing,
reinterpretation) are semantically non-obvious and match Swift stdlib labeling
convention (`Int(truncatingIfNeeded:)`, `Int(bitPattern:)`). They are not labels
for their own sake.

#### Option C — Marker protocol on Underlying (Tagged.LiteralSafe)

Gate the blanket on a marker protocol that Underlyings opt into. Int, UInt32,
Double opt in; Ordinal, Cardinal, Memory.Address do not.

| Criterion | Assessment |
|---|---|
| Production literals on Tagged | Yes, for LiteralSafe Underlyings |
| Footgun risk | None — Ordinal-backed Tagged types cannot accept literals, chain blocked at step 3 |
| Strideable compatible | Yes |
| Consumer cost | Extra API surface on Tagged (`TaggedLiteralSafe` protocol), conformance declarations for each Underlying, loss of literal ergonomics for Ordinal-backed typealiases |
| Per-tag opt-in possible? | **No** — verified by experiment. Swift's single-conformance rule prevents per-tag re-enabling |

Experimentally verified working for the main mechanism; verified impossible
for per-domain opt-in. The asymmetry ("Int-backed typealiases get literals,
Ordinal-backed don't, no workaround") was rejected by the package owner on
API-surface grounds.

#### Option D — Struct wrappers per domain

Domain types that need literal ergonomics become proper structs (not typealiases)
that wrap Tagged and add their own `ExpressibleByIntegerLiteral`.

| Criterion | Assessment |
|---|---|
| Production literals on Tagged | No (per-struct, not blanket) |
| Footgun risk | None for wrapped types |
| Consumer cost | Abandons Tagged's zero-cost-typealias value for every type that wants literals |
| Rejected | Yes — defeats the fundamental purpose of Tagged |

#### Option E — Consumer opt-in (no central blanket)

Ship nothing from tagged-primitives, each consumer adds conformance for its
own types.

| Criterion | Assessment |
|---|---|
| Viable at scale | **No** — verified REFUTED. Cross-module conformance conflict the moment a second consumer adds theirs |

### 3. The Memory.Shift / Cardinal.Protocol architectural issue

Independent of the literal question, the fresh examination surfaced that
`Memory.Shift: Cardinal.Protocol` is dishonest. `Cardinal.Protocol`'s doc
comment states conforming types "wrap or represent a `Cardinal` value and can
**round-trip** through it" (Cardinal.Protocol.swift:12). `Memory.Shift` is
`UInt8`-backed and the `init(_ cardinal: Cardinal)` narrows via
`UInt8(cardinal.underlying)` (traps on overflow). Any `Cardinal > 255` fails the
round-trip contract.

This is an architectural smell regardless of what we do with literals. The fix
is to drop `Memory.Shift: Cardinal.Protocol` conformance. The protocol was
intended for identity-numeric Cardinal wrappers (`Tagged<Tag, Cardinal>`,
bare `Cardinal`); Memory.Shift is a different kind of type (a shift amount in
bits, not a wrapped count). Grep shows 19 generic `Cardinal.Protocol`-dispatch
sites in ordinal-primitives and affine-primitives — none of them meaningfully
want a narrowing Cardinal.

If Option B is adopted, the `Memory.Shift.init(count:)` or
`Memory.Shift.init(bits:)` label + conformance removal is a single coordinated
change.

### 4. The tension summarized

Swift's type system does not let us have all seven of:

1. Blanket production `ExpressibleByIntegerLiteral` on Tagged
2. Unlabeled `init(_:)` as canonical cross-domain conversion (PATTERN-012)
3. `Strideable` on Tagged
4. No footgun
5. No marker protocol
6. No struct wrappers
7. No per-domain labels

Each option gives up at least one. Options A and B survive the rejection of
(5), (6), and the empirical death of the "consumer opt-in" escape hatch.

### Comparison

| Criterion | A: Do nothing | B: Label 3 + blanket | C: Marker | D: Structs | E: Consumer opt-in |
|---|:---:|:---:|:---:|:---:|:---:|
| Production literals on Tagged | No | Yes | Yes (filtered) | Per-struct | No |
| Footgun risk | None | Low (convention) | None | None | N/A |
| Strideable compatible | Yes | Yes | Yes | Yes | Yes |
| Convention decay risk | N/A | Real | None | None | N/A |
| API surface cost | None | 3 labels | +marker protocol | +structs | N/A |
| Convenience at consumer sites | Poor | Excellent | Excellent for opt-in Underlyings | Excellent for wrapped types | N/A |
| Rejected by user | No | Pending | Yes | Yes | N/A (empirically refuted) |

## Constraints

1. **Consumer opt-in is empirically refuted** (experiment
   `tagged-literal-consumer-opt-in`). Centralized ownership of the conformance
   is forced, not chosen.
2. **@_disfavoredOverload does not protect** against the footgun once
   Strideable is in play (experiment `tagged-literal-footgun-6-3-revalidation`
   Variants 1 & 4). v2.0/v3.0 already noted this for the equally-applicable
   case; the new evidence confirms it in the Strideable-enabled case.
3. **Swift allows only one conditional conformance per (type, protocol) pair**
   even with disjoint constraints (experiment `tagged-literal-safe-marker`
   Variant 5; experiment `tagged-literal-consumer-opt-in`). This forecloses
   both per-tag opt-in within a single package and distributed ownership
   across packages.
4. **[PRIM-FOUND-001]** constrains solution space: no Foundation imports.
5. **The architectural `Memory.Shift: Cardinal.Protocol` issue is real and
   independent** of the literal question. It should be fixed in either A or B.
6. **`Strideable` on Tagged has an already-approved DECISION** in
   `swift-index-primitives/Research/Strideable Index Design.md`. Any viable
   path must be compatible with that eventually landing.

## Outcome

**Status**: RECOMMENDATION

The choice is between Option A (do nothing, accept the verbose convenience-init
pattern at consumer sites) and Option B (v3.0 three-label plan, with honest cost
accounting and the Memory.Shift architectural fix).

### Recommendation priority

**A over B, by a narrow margin**, for the following reasons:

1. **Structural safety is forever; conventions decay.** Option A keeps the
   footgun structurally impossible. Option B relies on a convention-and-review
   guard against future non-identity unlabeled inits.
2. **The "serious problem" motivating this work is narrower than a blanket
   conformance.** Specific consumer pain points (Time.Offset, SVG ViewBox,
   angles) can be resolved with per-type convenience inits that accept
   plain `Int`/`Double` and wrap. This aligns with [IMPL-010] "Push Int to
   the Edge" — the boundary overload pattern. `Time.Offset(years: 2, months: 3)`
   taking `Int` parameters reads cleanly and is arguably *better* API than
   `Time.Offset(years: Tagged<Year, Int>(2))`.
3. **Once Strideable lands, the cost of reversing B is nontrivial.** Consumers
   will rely on the literal ergonomics; removing it later is a breaking change.
   Option A keeps optionality open — a future language feature (e.g., a
   `@literalSafe(false)` attribute or negative constraints) could cleanly
   re-enable Option C.

**B remains viable** if the ecosystem verdict is that consumer-site verbosity
is the bigger concern. In that case:

- Label `Bit.Index.init(byte:)`, `Memory.Shift.init(bits:)` (preferred over
  `count:` for semantic clarity), `Affine.Discrete.Ratio.init(stride:)`.
- Drop `Memory.Shift: Cardinal.Protocol` conformance (architectural fix).
- Move `ExpressibleByIntegerLiteral` and `ExpressibleByFloatLiteral` from test
  support to production. The other 5 test-support conformances (unicode scalar,
  grapheme cluster, string, boolean, string interpolation) need a separate
  decision; v3.0 did not address them. Recommendation: keep them test-only —
  they serve no production ergonomic need comparable to integer/float.
- Add `@_disfavoredOverload` to both production literal conformances (matching
  test support), even though the attribute provides no footgun protection —
  it at least makes explicit constructors preferred in the equally-applicable
  case.
- Codify the convention: "Unlabeled `init(_:)` on Tagged types MUST preserve
  numeric identity. Non-identity transformations use labels." Enforce in review.

### What this document does NOT decide

- Whether the 5 additional test-support literal conformances (unicode scalar,
  grapheme cluster, string, boolean, string interpolation) move to production.
  If anyone ends up on Option B, this is a separate call.
- The exact `bits:` vs `count:` label for `Memory.Shift`. Noun clarity ("shift by
  N bits" reads cleaner than "shift by count N") weakly prefers `bits:`.
- Whether to add a `@literalSafe(false)` marker attribute or otherwise pursue
  Option C-like gating in a future iteration. The current rejection is on
  API-surface grounds and may be revisited when the ecosystem has more data
  on convention decay.

## References

### Prior research (this series)

- `tagged-literal-conformances.md` v3.0 (DECISION, 2026-03-04) — approved the
  label-the-3 plan (Option B here). The prior DECISION stands in principle;
  this document's findings suggest Option A may now be preferable but does not
  unilaterally change v3.0's status. A future update to v3.0 (or a new DECISION
  document) would formalize any shift.
- `revisiting-tagged-production-literal-conformances.md` v2.0 (DECISION,
  2026-03-04) — established identity-numeric safety argument.
- `comparative-analysis-pointfree-swift-tagged.md` (DECISION, 2026-02-26) —
  documents principled removal of Strideable et al. from Tagged.

### External DECISIONs that intersect

- `swift-index-primitives/Research/Strideable Index Design.md` (DECISION,
  2026-01-28) — `Index: Strideable where Tag: ~Copyable` approved.
- `swift-primitives/Research/labeled-cross-domain-init-convention.md` v2.0
  (DECISION, 2026-03-04) — cross-domain init convention analysis.
- `swift-primitives/Research/cross-domain-init-overload-resolution-footgun.md`
  (RECOMMENDATION, 2026-02-11) — original footgun analysis.

### Experiments (all 2026-04-21, Swift 6.3.1)

- `tagged-literal-footgun-6-3-revalidation/` — PARTIAL (footgun dormant without
  Strideable; live with it). Includes sub-package `production-reality-check/`
  that verifies findings against real `Bit.Index` + test support.
- `tagged-literal-safe-marker/` — CONFIRMED (marker works for main mechanism)
  + REFUTED (per-tag opt-in impossible due to single-conformance rule).
- `tagged-literal-consumer-opt-in/` — REFUTED (cross-module consumer opt-in
  fails with second consumer).

### Code references

- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift` —
  production Tagged definition (no Strideable, no literal conformances).
- `swift-tagged-primitives/Tests/Support/Tagged Primitives Test Support.swift` —
  7 test-only literal conformances with `@_disfavoredOverload`.
- `swift-bit-index-primitives/Sources/Bit Index Primitives/Bit.Index+Byte.swift` —
  unlabeled cross-domain init, ×8 scaling, footgun anchor.
- `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Shift+Cardinal.Protocol.swift` —
  narrowing init + `Cardinal.Protocol` conformance (architectural issue).
- `swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete.Ratio+Tagged.swift` —
  reinterpretation init.
- `swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Protocol.swift` —
  round-trip contract.
