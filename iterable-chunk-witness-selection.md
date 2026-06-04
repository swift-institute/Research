# Iterable Chunk-Witness Selection

<!--
---
version: 1.0.0
last_updated: 2026-06-04
status: DECISION
tier: 2
scope: cross-package
---
-->

> **DECISION (implemented + twice-derived).** The per-conformer `Iterable` witness-selection rubric: dense, contiguously-stored conformers vend `Iterator.Chunk` directly over their storage's `span`; the `Iterator.Materializing` adapter is reserved for span-less generators. Decided and landed in the collection↔iterator drift arc (swift-collection-primitives `c78c349`), independently re-derived and confirmed by the MSB P-1 executor before merge. This note is the durable record — the decision previously lived only in a consumed handoff's Findings (`HANDOFF-collection-iterator-iterable-drift.md`).

## Context

`unified-iteration-design.md` v2.2.0 (the iteration arc's design authority) re-pointed `Iterable` to the span-primitive shape per SE-0516: `associatedtype Iterator: __IteratorChunkProtocol, ~Copyable, ~Escapable` (`swift-iterator-primitives/Sources/Iterable/Iterable.swift:46` — [Verified: 2026-06-04]). That design decision left a per-conformer question open: which witness shape a given `Iterable` conformer vends.

The question became load-bearing through the drift incident: `swift-collection-primitives`' Test Support fixtures still vended hand-rolled scalar `Iterating` generators, which no longer satisfied the chunk-model requirement — every clean resolve of `Collection Primitives Test Support` failed, blocking the heap/stack/dictionary/slab test bundles and byte-collection's CI. The fixture migration forced the witness-shape decision; no witness-decision doc existed in either package's `Research/` (checked three times across the two arcs — iterator-primitives has no `Research/` at all).

Routing provenance: MSB W3 program termination carry-forward ("the chunk-witness decision needs a Research note — route via reflections-processing"), executed by the 2026-06-04 reflections-processing run (session "Scribe") under principal dispatch.

## Question

Which `Iterable` witness shape does a conformer vend: `Iterator.Chunk` directly over its storage's span, or the `Iterator.Materializing` adapter over a scalar generator?

## Analysis

**The rubric** — selection follows the conformer's storage, not convenience:

| Conformer's storage | Witness | Why |
|---------------------|---------|-----|
| Dense, contiguously stored (array-backed, heap-backed — anything that projects a `span`) | `Iterator.Chunk(storage.span)`, a FRESH chunk per `makeIterator()` call (multipass preserved) | The span IS the bulk tier; `span[i]` is a borrowing addressor, so one chunk witness serves both element kinds |
| Span-less generator (computed sequences, one-shot sources) | `Iterator.Materializing` over the scalar `Iterator.Protocol` generator | The adapter is RESERVED for this case; it materializes through an owned slot, so `Element: Copyable & Escapable` only |

**Four anchors** (each [Verified: 2026-06-04] on disk):

1. The protocol requirement: `Iterable.swift:46` — `associatedtype Iterator: __IteratorChunkProtocol, ~Copyable, ~Escapable`.
2. The adapter's own contract (`Sources/Iterator Chunk Primitives/Iterator.Materializing.swift`, doc comment): *"Dense, contiguously-stored containers do NOT use this adapter: they vend `Iterator.Chunk` directly over their `span`, which carries both element kinds."*
3. The protocol author's canonical fixture `IntSource` (`swift-iterator-primitives/Tests/Iterable Tests/Iterable.Terminals Tests.swift:6-12`) uses exactly the chunk-over-span shape, module-qualified spelling included.
4. `Collection.Protocol`'s where-clauses hold under the chunk witness: `Iterator.Element == Element`, `Iterator.Failure == Never` (`Iterator.Chunk.Failure = Never`).

**Canonical spelling** (the protocol author's fixture and the migrated collection fixtures agree):

```swift
public import Iterator_Chunk_Primitives

@_lifetime(borrow self)
public borrowing func makeIterator() -> Iterator_Chunk_Primitives.Iterator.Chunk<Element> {
    Iterator_Chunk_Primitives.Iterator.Chunk(_elements.span)
}
```

Wiring note: the consuming target needs the `Iterator Chunk Primitives` product explicitly — `Iterable`'s umbrella re-exports only the scalar tier, so under MemberImportVisibility the chunk tier needs its own `public import` + product dependency (the drift fix's `027a74e`).

## Outcome

**Status**: DECISION — implemented, independently confirmed, fleet-consistent.

- **Implementation**: swift-collection-primitives `c78c349` (+ `027a74e` dep wiring) — both fixtures' scalar `Iterating` structs deleted (zero direct consumers; terminals-only usage), witnesses now chunk-over-span (`Tests/Support/Collection Primitives Test Support.swift:57-64, :123-130` — [Verified: 2026-06-04]). In-worktree 20/20 tests, 7 suites.
- **Independent confirmation**: the MSB P-1 executor re-derived the shape from iterator-primitives' own conformers per [HANDOFF-013] before merging — same four anchors, same verdict. Collection main fast-forwarded `7f8e095 → c78c349`; 20/20 cold post-merge; all four drift dependents green (heap 135/19, stack 143/33, dictionary 51/6 including the gate-(b) + CoW suites, slab 18/2).
- **Fleet consistency**: the `+Iterable.swift` conformers on mains are already chunk-shaped (heap and buffer-linear bind `IterableIterator = Iterator.Chunk<Element>` via `@_implements`; parser's `Parser.Test.Iterator: __IteratorChunkProtocol`; single-iterator vends `Iterator.Materializing<Iterator.Once<Element>>` — the generator path, correctly per the rubric). The drift class (scalar witness bound to `Iterable`) closed org-wide with the fixture migration.
- **Scope boundary**: `Sequenceable` (the single-pass/consuming tier, `swift-sequence-primitives`) deliberately binds the scalar `Iterator.Protocol` — the consuming tier owes no chunk reconciliation; this rubric governs `Iterable` conformers only.

## References

- `swift-institute/Research/unified-iteration-design.md` v2.2.0 — the design authority this note implements at per-conformer granularity (the span-primitive realignment, §2.3 shape). This note is subordinate to it: if the design doc moves, this rubric re-derives.
- swift-collection-primitives `c78c349`, `027a74e` (the fixture migration); swift-iterator-primitives `26353e1` (protocol side, unchanged — the `ask:` for a public-surface change never fired).
- `HANDOFF-collection-iterator-iterable-drift.md` Findings (2026-06-03/04, consumed) — the two derivations' full evidence trail.
- `Research/Reflections/2026-06-04-msb-capability-tower-w3-endgame.md` + the W3 PROGRESS termination record — routing provenance.
