# Column Spelling Ergonomics — the Alias Vocabulary & the Gate Cost

<!--
---
version: 1.0.0
last_updated: 2026-06-10
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

R4 of the post-archaeology research arc, in two halves. **Near-term (W5-blocking):** the ratified
two-column tower produces type-position spellings like
`Array<Shared<Int, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Int>>.Linear>>`;
consumers need a column-alias vocabulary before W5 migrates them. **Long-tail:** quantify SE-0527's
runtime-dispatch objection as it actually lands in the tower's shape; record the default-generic-argument
and macro-route status; keep the swift-collections `Shared` watch current. The two-column design itself
is ratified and not in question (`stdlib-array-family-source-archaeology.md` F2; PROPOSAL R-1/R-2).

Verification: 6 web claims [RES-020]-verified (6/6); typealias capabilities and the gate cost re-probed
first-hand on Swift 6.3.2 (`TOOLCHAINS=org.swift.632202605101a`), artifacts preserved at
`.handoffs/probes-2026-06-10/r4-alias-gate-probe/`.

## Question

1. What mechanism should carry the column-alias vocabulary on Swift 6.3.2, and what naming shapes are
   lawful under [API-NAME-001/002]?
2. What does the per-mutation uniqueness gate actually cost in the tower's shape (SE-0527's objection,
   quantified)?
3. Do default generic arguments or macros change the answer; has the swift-collections `Shared` artifact
   moved?

## Near-term: the column-alias vocabulary

### The demand is already proven, privately

The public surface ships **zero** column aliases; construction is already spell-free for the default
columns via the split pinned constructors ([MEM-COPY-017] — e.g. both `Array(initialCapacity:)`
overloads pin `where S == …` full spellings, `Array.swift`). The gap is **type position** (stored
properties, signatures, generic arguments) — and every test suite has independently invented the same
fix [Verified: 2026-06-10]:

```swift
// swift-array-primitives/Tests/Array Primitives Tests/Array Surface Tests.swift:18–28
private typealias HeapColumn<E: ~Copyable> =
    Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear
private typealias SharedColumn<E: ~Copyable> = Shared<E, HeapColumn<E>>
private typealias MoveArray<E: ~Copyable> = Array<HeapColumn<E>>
// shared-primitives tests: the same pattern again (HeapStorage/GrowableRing/SharedRing)
```

Per-file private re-derivation across suites is the textbook signal that a shared vocabulary is missing.

### The mechanism verdict: generic typealiases, fully capable today

First-hand probe + stdlib precedent [Verified: 2026-06-10, both re-derived]:

| Capability (6.3.2) | Status | Evidence |
|---|---|---|
| Generic params on a typealias | YES | probe; TSPL `StringDictionary<Value>` |
| Constraints — param-list AND trailing `where`, **enforced** | YES | probe (misuse → 2 conformance errors); stdlib ships it: `public typealias FlattenCollection<T: Collection> = FlattenSequence<T> where T.Element: Collection` (`Flatten.swift:143`) |
| `~Copyable` suppression on alias params | YES | probe (`typealias ColAlias<E: ~Copyable> = Col<E>`); upstream tests `inverse_generics.swift:35`, module-interface round-trip |
| Nested under a NON-generic namespace enum with own generic params | YES | probe: `enum Column { typealias Direct<E: ~Copyable> = Col<E> }` compiles and is usable as `Column.Direct<NC>` |
| Nested inside a GENERIC type as a free vocabulary | NO | nested aliases inherit the outer generic context (`Array<S>.X` needs `S`) — unusable as vocabulary |

One documentation caveat: TSPL states a typealias "can't introduce additional generic constraints," but
the compiler accepts and **enforces** added constraints and the stdlib relies on it (`MigrationSupport.swift:54`
adds constraints over `LazyCollection`). Treat the capability as real-but-documented-narrower; risk low.

**Alternatives ruled out** [Verified: 2026-06-10]:

- **Default generic arguments**: the feature does not exist (no `Features.def` entry; GenericsManifesto
  future-direction only); the sole proposal attempt is swift-evolution PR #591, closed unmerged in 2017,
  with no successor and no live pitch (last forums thread 2024-08-31). Decisively, **SE-0527 argues
  against the pattern even if it existed**: a defaulted-allocator `UniqueArray<Element, Alloc: Allocator
  = SystemAllocator>` sketch is followed by "this assumes the implementation of a major new language
  feature that does not currently exist," and the proposal rejects the shape independently — "such viral
  type argument pollution is a frequent complaint of C++ programmers" and "stack traces would spell out
  the full type names, including defaulted arguments." Do not plan around defaults arriving.
- **Macros**: a declaration macro can emit top-level typealiases only as a **closed, statically-named
  list** — `arbitrary` names are forbidden at global scope (`ERROR(global_arbitrary_name…)`,
  `DiagnosticsSema.def:8123` on 632; SE-0389 names-coverage rule). For a closed vocabulary a macro is
  pure machinery over hand-written aliases; revisit only if the vocabulary ever became combinatorial —
  which SE-0527's anti-pollution argument suggests would itself be a design smell.

### Naming shapes lawful under the institute rules

[API-NAME-001/002] forbid top-level compound names — so the classic fully-applied alias vocabulary
(swift-nio's `HTTPClientRequestPart = HTTPPart<HTTPRequestHead, IOData>` family, `HTTPTypes.swift:160–169`,
the strongest upstream precedent for role-named aliases) is **not directly portable**: `MoveArray`,
`CowArray`, `ArrayValue` are compound top-level identifiers. The corpus also establishes **"CoW" is a
design term, never a spelling identifier** (docstring-only across the tower sources — grep-verified).
The lawful shape the probe validates is the **namespace-enum-nested generic alias**:

```swift
public enum Column {                                  // non-generic namespace
  public typealias Heap<E: ~Copyable> = Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear
  public typealias Shared<E> = Shared_Primitives.Shared<E, Heap<E>>   // CoW over the default heap column
  // + Bounded<E>, Ring<E>, Inline<E, n>, … as the families land
}
// consumer spelling:  Array<Column.Heap<Int>>   ·   Array<Column.Shared<Int>>
```

### Options and recommendation

| Option | Shape | Assessment |
|---|---|---|
| **A — column-vocabulary namespace module** (recommended) | One `Column`-style namespace of generic aliases, shipped as its own importable module | ADT-agnostic (one vocabulary serves Array/Set/Dictionary/Deque/SlotMap alike); composes (`Array<Column.Shared<Int>>`); smallest permanent surface; **matches the Audit-#9 ruling verbatim** ("consumers import the column-vocabulary modules explicitly"); [API-NAME]-lawful; probe-verified mechanism |
| B — per-ADT fully-applied aliases (the NIO pattern) | `Array.…`-level role aliases | Multiplies ADT × column; top-level spellings hit the compound-name wall; nested-in-generic is unusable; everything B offers is expressible by a consumer in one line atop A |
| C — status quo | per-file `private typealias` | The demand evidence itself; repetitive, drift-prone across W5 consumers |

**Recommend A**, per [RES-022] (structural: one vocabulary, every family, sanctioned import shape). The
**names are the seat's call** (permanent API; PROPOSE-don't-bake per the executor discipline): the
namespace noun (`Column` reads as the design term the corpus already uses) and the member nouns (`Heap`,
`Shared`, `Bounded`, `Ring`, `Inline`) are candidates with prior-art backing, not decisions. SE-0483
(InlineArray's `[n of T]`) records the language-sugar escalation path for first-party hot spellings —
not available to a third-party tower; noted for completeness.

## Long-tail: the gate cost, quantified

SE-0527's objection to a conditionally-copyable Array has two parts: (1) Swift cannot query copyability
of a type argument at runtime; (2) "consulting the Swift runtime every time a function needs to mutate
an array instance seems unlikely to be acceptable." In the tower's ratified shape, **(1) does not apply
at all** — the column is chosen statically; the move-only column's gate is a defaulted no-op (0 ns), and
only the Copyable `Shared` column pays a uniqueness check, which is CoW's irreducible cost (stdlib
`Array` pays the same check in `_makeMutableAndUnique` per public mutating call).

**(2) is now a number.** Microprobe (Swift 6.3.2, `-O`, Apple Silicon; `final class` box,
`isKnownUniquelyReferenced(&box)` per iteration on an always-unique box, opaque `@inline(never)` work;
50M iterations × 3 runs; artifacts preserved):

| Shape | ns/op |
|---|---|
| gated per-element mutation (always-true uniqueness check) | **5.1–5.2** |
| ungated | **0.8** |
| ⇒ the gate, worst case | **≈ 4.3 ns/mutation** |

The optimizer did **not** hoist the check across the opaque call boundary. Interpretation, honestly
bounded per the [BENCH] integration-probe discipline (`copyable-wrapper-vs-multi-buffer-storage.md` —
micro-benches bound the primitive, they do not predict workloads):

- This is the **worst case**: a per-element seam mutation on the Shared column with trivial work — the
  cost the Audit-#1 self-gating fix (60361b0) consciously accepted ("the per-op
  `isKnownUniquelyReferenced` is a cheap true branch"). Cheap = ~4.3 ns, now on record.
- The design's sanctioned hot path amortizes it to ~0: one gate per public mutating **call** or per
  mutable-span **vend** (`ensureUnique()` before `withMutableSpan` — the archaeology constraint), then
  unchecked bulk writes. This is stdlib's own factoring, validated rather than challenged by the number.
- Consequence for W5 guidance: per-element loops over a Shared column should prefer
  `withMutableSpan`/bulk ops; the direct column is unaffected (no-op gate). No design change
  recommended.

**Façade status (watch item):** unchanged — the single conditionally-Copyable CoW container remains
precedent-free; swift-collections' `Shared<Storage: ~Copyable>` is still `#if false // TODO`-gated and
consumed by nothing at the current main HEAD (re-checked: `af174fe…`, unchanged since 2026-06-09)
[Verified: 2026-06-10]. Watch triggers: an un-gating commit in `ContainersPreview`, or a pitch of the
copyable CoW `Box` (the McCall #58 / Ben Cohen #60 trail in the SE-0517 review).

## Tower impact

| # | Finding | Tower element | Verdict |
|---|---|---|---|
| 1 | Tests privately re-derive the same aliases; public surface has none | W5 consumer migration | Ship the Option-A vocabulary module before/with W5; seat names it |
| 2 | Generic typealiases: constraints + `~Copyable` fully work on 6.3.2 (probe + stdlib precedent) | Mechanism choice | Typealiases carry the vocabulary; no macro, no waiting on defaults |
| 3 | Defaults don't exist; SE-0527 argues against the pattern itself | Long-term spelling strategy | Two-column explicit spelling + alias vocabulary is the durable answer |
| 4 | Gate ≈ 4.3 ns worst-case per-element; 0 on move-only column; amortized by bulk factoring | SE-0527 objection vs the ratified design | Objection (1) inapplicable, (2) quantified and amortized — design unchanged |
| 5 | s-c `Shared` unmoved | Façade watch | Stays shelved; triggers recorded |

## Outcome

**Status: RECOMMENDATION** (research only).

1. Adopt **Option A**: a column-vocabulary namespace module of generic typealiases (probe-verified
   mechanism; Audit-#9-aligned import shape). Seat picks the namespace + member nouns; the executor
   ships it with or before the first W5 consumer migration.
2. Record the **gate-cost number** (~4.3 ns worst-case, 0 for move-only columns) in the family docs and
   the W5 guidance: span-first bulk mutation on Shared columns; per-element loops are the fallback, not
   the idiom.
3. Do not wait on default generic arguments (dead since 2017, upstream argues against the pattern);
   do not build a macro for a closed alias list.
4. Keep the façade shelved; watch triggers: s-c `Shared` un-gating, a copyable-`Box` pitch.

## Residual (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| Typealias capabilities on 6.3.2 | premise | First-hand probe + upstream test-suite citations; artifacts preserved (`.handoffs/probes-2026-06-10/r4-alias-gate-probe/`) |
| Gate cost | premise (bounded claim) | Microprobe preserved; explicitly a primitive bound, not a workload prediction ([BENCH] discipline); integration numbers belong to the first real W5 consumer if contested |
| Namespace + member nouns | direction (seat's permanent-API call) | Candidates recorded; [API-NAME] analysis done |
| Vocabulary members for not-yet-landed columns (Inline/Small/SlotMap) | direction | Add as the families land |
| TSPL-vs-compiler typealias-constraint documentation gap | direction | Harmless today (stdlib-load-bearing); candidate upstream doc fix, not institute-blocking |

## References

- **Probes (preserved)**: `.handoffs/probes-2026-06-10/r4-alias-gate-probe/` — `ta.swift` (capabilities),
  `ta2.swift` (enforcement), `gate.swift` (cost), RESULTS; Swift 6.3.2, 2026-06-10.
- **Local**: array tests `Array Surface Tests.swift:18–28` (the private vocabulary); `Array.swift` split
  pinned constructors; `tower-type-signature-inventory.md` + `DESIGN-msb-ideal-type-signatures.md`
  (canonical spellings); STATUS:84 (Audit-#9 ruling), :83 (60361b0 self-gating + the accepted per-op
  branch); `copyable-wrapper-vs-multi-buffer-storage.md` (micro-vs-integrated discipline).
- **Upstream**: TSPL Declarations.md:591–634; stdlib `Flatten.swift:143`, `MigrationSupport.swift:30–74`;
  632 tests `decl/typealias/generic.swift:59,445`, `Generics/inverse_generics.swift:35`;
  `DiagnosticsSema.def:8123` (global_arbitrary_name) + SE-0389 §names / SE-0397; GenericsManifesto
  §Default generic arguments; swift-evolution PR #591 (closed 2017); SE-0527 §alternatives (the
  defaulted-allocator rejection, verbatim-verified); swift-nio `HTTPTypes.swift:160–169`;
  swift-collections @ `af174fe` (`Ref.swift:148` `Borrow = Ref`; `Shared.swift:14–16` gate); SE-0483.
- **Parents**: `stdlib-array-family-source-archaeology.md` (F2 façade verdict; mutable-span constraint);
  PROPOSAL-tower-perfected-design.md (R-1/R-2; the ratified spellings).

### Verification

[RES-020]: 6/6 web claims independently re-fetched (PR #591; SE-0527 quotes; NIO aliases; Flatten.swift;
SE-0389/diagnostic; GenericsManifesto). Typealias capabilities and the gate cost re-derived first-hand
(probe outputs in the preserved artifacts).
