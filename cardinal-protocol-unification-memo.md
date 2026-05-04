---
title: Cardinal.`Protocol` unification — bare-vs-Carrier overload split pattern
status: SUPERSEDED by cardinal-trivial-self-revert-plan.md
date: 2026-05-03
decided: 2026-05-04
context: tagged-primitives + carrier-primitives downstream rename cascade, tier-12 checkpoint
---

## Supersession (2026-05-04)

**SUPERSEDED by `cardinal-trivial-self-revert-plan.md`.** Phase 5 verified
green on 2026-05-04 with Option C build-blocker scope: 10 L1 BLOCKERS +
1 L2 BLOCKER fixed, downstream cascade unblocked. Stylistic-only leftovers
and newly-discovered cascade repos enumerated in the plan's "Deferred
follow-up — Tagged-rename adoption sweep" section.

The Cardinal.`Protocol` unification approach below was the working theory
during the tier-12 checkpoint; the trivial-self revert architecture
(restoring `Cardinal/Ordinal/Affine.Discrete.Vector: Carrier<Self>` with
per-type `rawValue: UInt|Int` fields) replaced it. Historical notes
preserved below for reference.

## Decision (2026-05-04)

**Option C accepted.** Add `Cardinal.\`Protocol\`` upstream in
`swift-cardinal-primitives`; defer `Vector.\`Protocol\`` until L3 evidence
accumulates.

### Migration outcome (2026-05-04)

Five of the six listed packages migrated cleanly to the unified
`Cardinal.\`Protocol\`` constraint with net deletion ~120 lines:

- `swift-ordinal-primitives` — ✅ migrated (commit `3bfab64`); 35 tests pass.
- `swift-affine-primitives` — ✅ Cardinal-side splits migrated (commit `384d43c`); Vector-side stays per Option C deferral.
- `swift-cyclic-primitives` — ✅ deleted local `Ordinal+Cardinal.Bare.swift` companion (commit `8f90085`); 33 tests pass.
- `swift-sequence-primitives` — ✅ reverted 5 `Cardinal(_:)` lifts at Ordinal-vs-Cardinal comparison sites (commit `2083160`); 160 tests pass.
- `swift-finite-primitives` — ✅ reverted 7 `Cardinal(_:)` lifts (commit `c8e6b3b`); 79 tests pass.
- `swift-bit-vector-primitives` — ✅ **migrated via operator-disfavor rebalance** (commits `7b40038` swift-ordinal-primitives + `3a2248c` swift-affine-primitives + `8e26916` swift-bit-vector-primitives); 70 tests pass.

  **Root cause of the bit-vector ambiguity.** Initial pass concluded
  bit-vector was not migratable until `Vector.\`Protocol\`` landed —
  incorrect. The actual conflict at `index += .one` was operator-resolution
  preference between three competing `+=` overloads:

  1. Cardinal-side generic (mine): `+= <O: Ordinal.\`Protocol\`, C: Cardinal.\`Protocol\`>(inout O, C) where O.Domain == C.Domain` — non-throwing
  2. Affine bare-Vector concrete: `+= <O: Ordinal.\`Protocol\`>(inout O, Affine.Discrete.Vector) throws` — concrete RHS, was non-disfavored
  3. Affine Carrier-of-Vector generic: `+= <O, V: Carrier.\`Protocol\`<Vector>>(inout O, V) throws` — `@_disfavoredOverload`

  Pre-`46ded75` (Tagged cascade), `Tagged<Tag, Vector>.Underlying =
  Vector.Underlying = Int`, so `Carrier where Underlying == Vector`
  extension did NOT apply to Tagged-of-Vector. `Tagged<UInt, Vector>.one`
  did not exist. Affine generic (#3) had no instantiable Tagged-of-Vector
  RHS. `.one` resolution had no Vector candidate.

  Post-`46ded75` (Tagged immediate-wrap), `Tagged<Tag, Vector>.Underlying ==
  Vector` — the extension applies, `Tagged<UInt, Vector>.one` exists, and
  affine generic (#3) becomes instantiable. Now `.one` had three candidate
  resolutions for `inout Index<UInt>` LHS:

  - `Tagged<UInt, Cardinal>.one` (via mine, forced by Domain == UInt)
  - `Affine.Discrete.Vector.one` (via affine bare #2)
  - `Tagged<UInt, Vector>.one` (via affine generic #3)

  Both mine and affine #2 were non-disfavored (mine carried the
  `@_disfavoredOverload` from the original concrete-form, but I'd already
  removed that mark thinking it was for literal disambig — no other
  overloads reach this site once #3 is filtered as disfavored). Then
  Swift's "concrete RHS beats generic RHS" rule made affine #2 win,
  forcing the throws version, breaking `.one` for non-throwing intent.

  **Fix:** mark affine #2 (`+ <O>(O, Vector) throws` and
  `+= <O>(inout O, Vector) throws`) as `@_disfavoredOverload` (commit
  `3a2248c`), keep mine non-disfavored (commit `7b40038`). The minus-side
  affine operators (`-`, `-=`) intentionally remain non-disfavored —
  there is no Cardinal-side counterpart for them, so no resolution
  conflict exists. The comparison operators (`<`, `<=`, `>`, `>=`) on
  the cross-type Ordinal-Cardinal side retain `@_disfavoredOverload`
  for their original `someOrdinal < .zero` literal-disambig role.

  This is a cleaner outcome than deferring bit-vector to Vector.\`Protocol\`.
  All six originally-listed packages migrated.

Net deleted: ~115 lines across all six packages. Vector-side affine
splits remain (Vector ↔ Cardinal cross-type comparisons; Vector ↔
Tagged-of-Vector arithmetic) for the future Vector.\`Protocol\` cycle.

Two corrections to the body below:

1. **The `46ded75` cascade-drop is upheld**, not reverted. The immediate-wrap
   form is academically correct (canonical phantom-type / newtype destructor
   semantics; one-level `Self(self.underlying) ≡ self` round-trip;
   admits `Tagged<Tag, Ownership.Inout<Base>>` for Property.View).

2. **The protocol shape sketched in § "Proposed fix" does not compile.** The
   form `Cardinal.\`Protocol\`: Carrier.\`Protocol\` where Underlying == UInt`
   would force `Tagged<Tag, Cardinal>.Underlying == UInt`, but post-`46ded75`
   `Tagged<Tag, Cardinal>.Underlying == Cardinal`. The working shape mirrors
   the existing `Ordinal.\`Protocol\`` precedent: a **sibling** to Carrier
   (not a refinement) with its own typed accessor:

   ```swift
   extension Cardinal {
       public protocol `Protocol` {
           associatedtype Domain: ~Copyable = Never
           var cardinal: Cardinal { get }
           init(_ cardinal: Cardinal)
       }
   }

   extension Cardinal: Cardinal.`Protocol` {
       public typealias Domain = Never
       public var cardinal: Cardinal { self }
       public init(_ cardinal: Cardinal) { self = cardinal }
   }

   extension Tagged: Cardinal.`Protocol`
   where Underlying: Cardinal.`Protocol`, Tag: ~Copyable {
       public typealias Domain = Tag
       public var cardinal: Cardinal { underlying.cardinal }
       @_disfavoredOverload
       public init(_ cardinal: Cardinal) {
           self.init(_unchecked: Underlying(cardinal))
       }
   }
   ```

   Both bare `Cardinal` and `Tagged<Tag, Cardinal>` (and any further nesting)
   satisfy `Cardinal.\`Protocol\``. Depth-axis (Carrier) and domain-axis
   (`Cardinal.\`Protocol\``) remain orthogonal — same architecture as
   `Ordinal.\`Protocol\``.

---

# Cardinal.`Protocol` unification memo

## TL;DR

Six packages migrated so far have independently produced the same workaround
to the same upstream shape change. The workaround is structural, not local.
We can either keep paying its cost in every remaining downstream package, or
add one small upstream protocol and unify. **Recommendation: add
`Cardinal.\`Protocol\`` upstream now.** The cost is one new empty marker protocol
plus three extensions; the benefit is removing a recurring 5–15 line per-package
split that will otherwise replicate through every remaining L1 primitive,
all of L2 (iso-9945), and all of L3 (foundations + darwin-standard).

## The observed pattern

After the swift-tagged-primitives `46ded75` cascade-drop ("Tagged: drop
cascade in Carrier conformance — unconditional + immediate"), Tagged's
Carrier conformance is unconditional + immediate:

```swift
extension Tagged: Carrier.`Protocol` {
    typealias Underlying = Underlying      // immediate generic param, no recursion
}
```

Combined with cardinal `ac7f308`'s own-field rename, where bare `Cardinal`
is now `Carrier.\`Protocol\`<UInt>` (NOT `<Cardinal>`), this means a
generic constraint like:

```swift
where Count: Carrier.`Protocol`<Cardinal>
```

matches `Tagged<Tag, Cardinal>` (because its `Underlying == Cardinal`)
but does **NOT** match bare `Cardinal` (because its `Underlying == UInt`).

Pre-cascade-drop, the recursive cascade made bare Cardinal also satisfy
`Carrier.\`Protocol\`<Cardinal>` (`Cardinal.Underlying == Cardinal.Underlying.Underlying == ... == Cardinal`
under self-Carrier). That's gone. Constraints written against
`Carrier.\`Protocol\`<Cardinal>` now select only Tagged-wrapped sites.

## Where it has bitten — six packages so far

Each of these had to introduce a bare-vs-Carrier overload split in this cascade:

1. **swift-ordinal-primitives** (commit `e42df9f`) — `Ordinal.\`Protocol\`.+`,
   `Ordinal.Distance.forward(to:)`, `Range<Bound: Ordinal.\`Protocol\`>.count`,
   `Range.init(start:count:)`. Two-extension split: `where Count == Cardinal`
   vs `where Count: Carrier.\`Protocol\`<Cardinal>`. Plus `Ordinal.Advance` used
   `@_disfavoredOverload` overload pair instead of the where-split.

2. **swift-affine-primitives** (commit `51fd126`) — `+`, `-`, `+=`, `-=` on
   `Affine.Discrete.Vector` arithmetic. Bare-Vector overloads paired with
   `@_disfavoredOverload` Carrier-of-Vector overloads.

3. **swift-cyclic-primitives** (commit `d3afe09`) — added new file
   `Ordinal+Cardinal.Bare.swift` providing bare-Ordinal/bare-Cardinal `%`
   and `<` overloads to complement the upstream Tagged-path overloads.

4. **swift-sequence-primitives** (commit `87e200e`) — four cross-type
   comparison sites lifted RHS through `Cardinal(_:)` because the disfavored
   `<O: Ordinal.\`Protocol\`, C: Carrier.\`Protocol\`<Cardinal>>` overloads no longer
   cover bare-Ordinal vs bare-Cardinal.

5. **swift-finite-primitives** (commit `ed5353b`) — seven `Cardinal(_:)`
   lifts at comparison sites for the same reason.

6. **swift-bit-vector-primitives** (commit `3abf42e`) — five call sites
   disambiguated with explicit `Index<UInt>.Count.one` because importing
   Affine made the bare `.one` ambiguous against the throwing
   `+= <O, V: Carrier.\`Protocol\`<Affine.Discrete.Vector>>` overload from
   affine.

The cost-shape is consistent: 5–15 lines per package of either explicit
`Cardinal(_:)` lifts or `@_disfavoredOverload`-paired bare overloads.
Each new package re-discovers it during build, the agent surfaces the
fix, then continues.

## Why this keeps recurring

Three observations make this not a one-off:

- **Cardinal is downstream-pervasive.** Every counting/sizing operation in
  the ecosystem uses bare Cardinal somewhere. Tagged-wrapped Cardinal is
  also pervasive (any `Index<T>.Count`). Generic code wants to write one
  signature that works for both.

- **The cascade-drop is correct.** Reverting it would re-introduce the
  blocker on `Property.View<Tag, Ownership.Inout<Base>>` that motivated
  `46ded75` in the first place.

- **The split is mechanically uniform.** Every site looks the same:
  add a bare-type overload, mark the Carrier overload `@_disfavoredOverload`,
  or lift the bare RHS through `Cardinal(_:)`. The repetitiveness is the
  signal that the abstraction is missing one level up.

## Proposed fix — `Cardinal.\`Protocol\`` sibling

Mirror the existing `Ordinal.\`Protocol\`` pattern in cardinal-primitives:

```swift
// In swift-cardinal-primitives:
extension Cardinal {
    public protocol `Protocol`: Carrier.`Protocol` where Underlying == UInt {}
}

extension Cardinal: Cardinal.`Protocol` {}

extension Tagged: Cardinal.`Protocol` where Underlying == Cardinal {}
```

(Or whatever shape matches the existing `Ordinal.\`Protocol\`` layout.
The exact requirements list of the protocol can start empty if there are
no operations that universally apply only to "Cardinal-ish things"; or it
can carry a few — `var asCardinal: Cardinal { get }` style accessors —
if helpful.)

After this, the six existing splits collapse to single signatures:

```swift
// Before (split):
extension Ordinal.`Protocol` {
    static func + (lhs: Self, rhs: Cardinal) -> Self { ... }
    @_disfavoredOverload
    static func + <C: Carrier.`Protocol`>(lhs: Self, rhs: C) -> Self
        where C.Underlying == Cardinal { ... }
}

// After (unified):
extension Ordinal.`Protocol` {
    static func + <C: Cardinal.`Protocol`>(lhs: Self, rhs: C) -> Self { ... }
}
```

Both `Cardinal` and `Tagged<Tag, Cardinal>` satisfy `Cardinal.\`Protocol\``,
so a single signature covers both.

## Symmetry with the existing ecosystem

The Ordinal side already has `Ordinal.\`Protocol\``:
- `Ordinal: Ordinal.\`Protocol\``
- `Tagged: Ordinal.\`Protocol\` where Underlying: Ordinal.\`Protocol\``
  (or similar — the existing shape is the precedent)

Cardinal does not currently have a sibling `Cardinal.\`Protocol\``. The
asymmetry is what surfaces the split pattern — Ordinal-side code can write
`where Count: Ordinal.\`Protocol\`` and match cleanly; Cardinal-side code
can't write the parallel `where Count: Cardinal.\`Protocol\``, so it falls
back to the `Carrier.\`Protocol\`<Cardinal>` constraint plus a bare overload.

A similar protocol may also be appropriate for `Affine.Discrete.Vector`
(same pattern hit affine itself) — `Vector.\`Protocol\``. The argument is
the same; the volume is smaller (Vector is less downstream-pervasive than
Cardinal). Decision can be deferred or batched with this one.

## Costs

| Item | Cost |
|------|------|
| Define `Cardinal.\`Protocol\`` empty marker protocol in cardinal-primitives | ~3 lines |
| `extension Cardinal: Cardinal.\`Protocol\` {}` | 1 line |
| `extension Tagged: Cardinal.\`Protocol\` where Underlying == Cardinal {}` | 1 line |
| Migration of 6 already-done packages — replace splits with unified signatures | ~30–60 lines net deletion |
| Migration impact on remaining downstream cascade | each new package writes 1 unified signature instead of 2-line split |
| Risk to existing Tagged Carrier semantics | none — adds conformance to a marker protocol, doesn't constrain Tagged's existing surface |
| Risk to bare Cardinal semantics | none — adds conformance to a marker protocol with no required members (or trivial ones) |

There is no install-base concern (pre-1.0, nothing tagged or pushed).

## Benefits

| Item | Benefit |
|------|---------|
| Eliminates split pattern in 6 already-done packages | net code deletion |
| Eliminates split pattern in remaining ~20 L1 primitives + L2 + L3 | prevents future recurrence at every layer |
| Cleaner generic API surface for downstream consumers | one constraint instead of "constraint plus overload pair" |
| Symmetry with existing `Ordinal.\`Protocol\`` | the asymmetry is what created the bug-shaped pattern |
| Removes `@_disfavoredOverload` boilerplate where it's been used purely to disambiguate the split | standard generic resolution handles it |

## Decision options

### Option A — ship as-is with the split pattern

Continue dispatching the remaining ~20 L1 primitives + L2 + L3 with
each agent re-discovering and patching the split locally. Costs 5–15
lines per package. Total estimated cost: 100–300 lines of split-overload
boilerplate distributed across the cascade. The pattern becomes load-bearing
in long-term consumer-side code; future agents will copy it without
understanding why.

### Option B — pause cascade, add Cardinal.\`Protocol\` upstream, then continue

1. Add `Cardinal.\`Protocol\`` to swift-cardinal-primitives (one upstream commit).
2. Migrate the six already-done packages to use the unified shape (six
   small commits).
3. Resume the L1 cascade with the unified pattern available from the start.

Estimated cost: one upstream commit (~10 lines) + six 5-line per-package
migrations to consume the new protocol. Estimated benefit: roughly 100–300
lines of net deletion across the remaining cascade, plus a cleaner API
surface visible to every future consumer.

### Option C — Option B for Cardinal only; defer Vector

Same as Option B but only for Cardinal. Affine.Discrete.Vector also has
the pattern but its blast radius is smaller; if you want to minimize
upstream surface change, defer Vector.\`Protocol\` and accept the local
split pattern in affine-consuming packages. Re-evaluate at the L3
foundations layer if it bites again.

## Recommendation

**Option C — add `Cardinal.\`Protocol\`` now; defer `Vector.\`Protocol\`` until
the L3 layer.**

Reasoning:
- Cardinal is pervasive enough that the cost of NOT adding the protocol
  compounds across every remaining tier.
- The cardinal-side fix is mechanically the smallest upstream change in
  this cascade — one marker protocol + two conformance lines.
- The symmetry argument is structural: `Ordinal.\`Protocol\`` exists, and
  the Cardinal-side asymmetry is what creates the bug-shaped pattern.
- Vector's blast radius is concentrated in affine-arithmetic-consuming
  code; its pattern hasn't yet shown up in tier 13+ packages, suggesting
  it may be containable. Defer the Vector.\`Protocol\` decision until we
  observe more evidence.

## What the cascade does while waiting

The cascade can either pause (no further L1 dispatches until decision) or
continue (each remaining tier accepts the per-package split). I recommend
**pause**, because:
- Continuing means the migration to the unified shape (Option B/C) becomes
  larger after each new package adds another local split.
- Each split is non-trivial enough that the agents authoring them have
  consistently flagged them as worth re-thinking; the consistency is the
  signal that the abstraction is missing.

If you choose Option A, no pause needed — just keep dispatching.

## Affected commits (for reference)

Already-landed local commits with the split pattern, ordered by tier:

- `e42df9f` swift-ordinal-primitives
- `51fd126` swift-affine-primitives
- `d3afe09` swift-cyclic-primitives (adds `Ordinal+Cardinal.Bare.swift`)
- `87e200e` swift-sequence-primitives
- `ed5353b` swift-finite-primitives
- `3abf42e` swift-bit-vector-primitives

Plus deferred-to-Option-A precedent:
- `04b9800` swift-binary-primitives — `Binary.Pattern.Mask` deferred from
  full Carrier conformance because the type's generic parameter is named
  `Carrier`. Independent of the unification question, but if Option B/C
  lands, the same migration pass can clean up Binary.Pattern.Mask.

## What I'm asking you

Pick one of: A (continue with split), B (add Cardinal.\`Protocol\`, also
add Vector.\`Protocol\`), C (add Cardinal.\`Protocol\`, defer Vector).

Or refine the proposal — e.g., narrow `Cardinal.\`Protocol\`` to specific
required members; or fold this into a broader "primitive-Protocol family"
discussion alongside any other patterns observed.

I'll resume the cascade once you decide.
