# [API-NAME-002] Amendment Recommendation: `<verb>IfPresent` / `<verb>IfStored` Stdlib-Idiom Exemption

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: RECOMMENDATION
---
-->

## Context

Post-Wave-3 residual: 4 `compound identifier` findings on `swift-ownership-primitives`
([wave-3-aggregate-2026-05-11.md](wave-3-aggregate-2026-05-11.md) v1.2.0 Open
Follow-Up #6, HANDOFF Open Q3). All four fire on stdlib-idiom-shaped
Optional-returning paired variants of destructive consume APIs:

| Site | Pair (precondition / Optional) |
|---|---|
| `Ownership.Latch.takeIfPresent()` — `Ownership Latch Primitives/Ownership.Latch.swift:225` | `take()` precondition-asserts; `takeIfPresent()` returns `Value?` |
| `Ownership.Transfer.Erased.Incoming.consumeIfStored(_:)` — `Ownership Transfer Erased Primitives/Ownership.Transfer.Erased.Incoming.swift:82` | `consume<T>(_:)` precondition-asserts; `consumeIfStored<T>(_:)` returns `T?` (delegates to `_latch.takeIfPresent()`) |
| `Ownership.Transfer.Retained.Incoming.consumeIfStored()` — `Ownership Transfer Primitives/Ownership.Transfer.Retained.Incoming.swift:96` | `consume()` precondition-asserts; `consumeIfStored()` returns `T?` (delegates to `_latch.takeIfPresent()`) |
| `Ownership.Transfer.Value.Incoming.consumeIfStored()` — `Ownership Transfer Primitives/Ownership.Transfer.Value.Incoming.swift:87` | `consume()` precondition-asserts; `consumeIfStored()` returns `V?` (delegates to `_latch.takeIfPresent()`) |

## Classification

**RULE-WRONG.** The compound-identifier rule fires correctly per its current letter
([API-NAME-002] No Compound Identifiers), but the pattern is a stdlib-idiom-shaped
delegator — precisely the class of compound that Wave 2's amendment #1 admitted via
the `stdlib-idiom-pattern` citation mechanism for `Optional.flatMap`, `Sequence.compactMap`,
etc. The "Optional-returning paired variant" idiom belongs in the same exemption
family.

## Stdlib Precedent

Swift stdlib pairs destructive operations with Optional-returning variants:

| Precondition-asserting | Optional-returning variant | Shape |
|---|---|---|
| `RangeReplaceableCollection.removeFirst()` | `Collection.popFirst()` | destructive consume of front element |
| `RangeReplaceableCollection.removeLast()` | `BidirectionalCollection.popLast()` | destructive consume of tail element |
| `Dictionary.subscript(key) { get }` (precondition via `!`) | `Dictionary.subscript(key) -> V?` (Optional get) | keyed lookup |
| Various `Iterator.next()` (Optional by definition) | — | the protocol bakes the idiom in |

Swift's distinction between `removeFirst`/`popFirst` is the closest analogue: the
distinction is in the VERB (`remove` vs `pop`), not a suffix. The Institute-style
`take`/`takeIfPresent` pair uses a SUFFIX instead — equally valid as a pairing
convention, and arguably clearer at call sites where the relationship to the base
verb is preserved.

## Proposed Amendment

Extend [API-NAME-002] with a new exemption category alongside the existing
`stdlib-idiom-pattern` citations:

```
Exemption: <verb>IfPresent / <verb>IfStored stdlib-idiom delegator

A compound name of the form <verb>IfPresent or <verb>IfStored (or <verb>If<Condition>
where Condition names the state predicate) is permitted when ALL of the following hold:

  1. A base verb <verb>() exists in the same type with a precondition-asserting variant
     (the non-Optional return).
  2. The compound method returns Optional<T> (or Optional<Value> for a paired non-generic).
  3. The implementation is a delegator: the compound's body shape is roughly
     `guard ... else { return nil }; return <base-verb-body>` — i.e., Optional.flatMap-shaped.
  4. The compound's return type carries the same payload type as the base verb,
     just wrapped in Optional.

Cite as `stdlib-idiom-pattern: Optional-returning paired variant (cf. popFirst / popLast)`.
```

The four findings on `swift-ownership-primitives` all satisfy (1)–(4) at the listed
file/line locations.

## Decision Axes (carry-forward from HANDOFF.md Open Q3)

| Path | Cost | Benefit |
|---|---|---|
| **RULE-FIX (recommended)** — amend [API-NAME-002] with the stdlib-idiom-pattern exemption above; close all 4 residuals | One amendment commit in `swift-institute/Skills/` + one commit in `swift-institute-linter-rules/` (Compound rule's idiom-pattern dict) + 4–6 tests | Preserves clear call-site names (`take()` / `takeIfPresent()` reads as a pair, suffix-paired); avoids breaking-API rename for a stdlib-precedent shape |
| **SOURCE-FIX** — refactor `<verb>IfPresent()` to `<verb>.ifPresent()` via nested-accessor pattern | Breaking API at 4 call sites + ~80 lines of new accessor struct code per type (Latch, Erased.Incoming, Retained.Incoming, Value.Incoming); call sites become `_latch.take.ifPresent()` which reads as if `take` is a property | Mechanical rule-compliance; lower future maintenance burden vs another exemption category |
| **NO-FIX** — accept the 4 residuals as known carve-outs via `// swift-linter:disable:next compound identifier` per finding | One disable directive per call site (4 total) + a `// REASON:` citing this doc | Zero rule-corpus churn; explicit per-finding deviation surface for reviewers |

## Recommendation

**RULE-FIX (rule amendment).** The pattern is stdlib-grade in shape and meaning; the
exemption category is one of a handful of recurring Wave-2 patterns (per the Wave 2
ledger's "six recurring exemption shapes" carry-forward to `[RULE-EXEMPT-*]`); admitting
it now via the existing `stdlib-idiom-pattern` mechanism keeps the rule corpus
self-consistent without introducing a fourth pattern (per-site disable, nested
accessor, exemption, etc.).

## Deferral Note

Per HANDOFF.md Open Q3 ("takeIfPresent API-design cycle timing"), the actual
rule-amendment commit is deferred until the next API-design cycle opens. This
RECOMMENDATION is the prep work; the cycle MAY adopt RULE-FIX, SOURCE-FIX, or
NO-FIX based on broader API-design context not visible from the lint-pass alone.

## Cross-references

- [wave-3-aggregate-2026-05-11.md](wave-3-aggregate-2026-05-11.md) v1.2.0 Open
  Follow-Up #6 (this is the prep for that follow-up)
- [wave-2-rule-amendments-2026-05-11.md](wave-2-rule-amendments-2026-05-11.md)
  amendment #1 (existing `stdlib-idiom-pattern` mechanism)
- `swift-institute/Skills/code-surface/SKILL.md` [API-NAME-002] (the amendment target)
