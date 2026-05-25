# Sequence.Protocol Count-Default Relocation: Impact Assessment

<!--
---
version: 1.1.0
last_updated: 2026-05-25
status: ACCEPTED — Phases 1–2 landed; Phases 3–4 pending
tier: 2
scope: ecosystem-wide
---
-->

## Update — disposition (2026-05-25)

This RECOMMENDATION has been accepted and partially executed.

- **Phase 1 (relocate total `count` to `Collection.\`Protocol\``)** — **LANDED** (prior session): removed `var count: Cardinal { consuming get }` from `Sequence.\`Protocol\`` (`swift-sequence-primitives` `31bbb42`); added `var count: Index<Element>.Count { borrowing get }` to `Collection.\`Protocol\`` (`swift-collection-primitives` `a1d2de9`).
- **Phase 2 (supersede the fluent `Collection.Count.View`)** — **LANDED** 2026-05-25 (`swift-collection-primitives` `0360762`). The `.count.all` / `.count.where` fluent shape was deleted (target + product + umbrella re-export removed); `Collection.\`Protocol\`` now exposes exactly one `count`. This closed a live `ambiguous use of 'count'` defect — the direct `count` (Phase 1) and the View `count` were both `@_exported` by the umbrella, so any **mutable** `Collection.\`Protocol\`` conformer used **without type context** hit the ambiguity (immutable/type-pinned/`.all` uses resolved fine, which is why it stayed latent). Verified: clean build + 16 tests; the 10 L1 Collection-conformer consumers (set, dictionary, heap, queue, stack, list, array, buffer-linear, slab, cache) clean-rebuilt green against `0360762`, with the deleted `Collection_Count_Primitives` module absent from every consumer `.build`. Pre-flight confirmed zero ecosystem callers of `.count.all` / `.count.where` and zero external importers of the `Collection Count Primitives` product.
- **`count(where:)` placement** — **CONFIRMED on `Sequence.\`Protocol\``** (this doc's RECOMMENDATION refinement, §RECOMMENDATION, upheld). Re-derived from first principles: `count(where:)` is a single-pass value-fold whose minimal required capability is single-pass iteration (`Sequence`'s essence), in the family of `reduce` / `contains` / `first(where:)` / `satisfies`. An additive `borrowing count(where:)` on `Collection.\`Protocol\`` was implemented and then **backed out** — it re-creates dual-conformer shadowing (a `Sequence`+`Collection` conformer gets two `count(where:)`: consuming→`Cardinal` vs borrowing→`Index<Element>.Count`, ambiguous on a bare call; confirmed via `swiftc` probe), and that population is the entire pending Phase 4 cohort. Governing principle established: **structural queries (size, position) live on `Collection`; element-value folds (predicate over contents) live on `Sequence`.** (Total `count` is a non-destructive repeatable *property* → Collection; `count(where:)` is a single-pass fold *method* → Sequence — they are different kinds of member, so different homes is correct, not inconsistent.) Candidate for codification in the `code-surface` / `implementation` skill.
- **Phase 3 (detach `Sequence.\`Protocol\`` from affected Buffer types) and Phase 4 (Group A cohort → `Collection.\`Protocol\`` migration, ~36 types)** — **PENDING** (separate arc). Phase-4 note: migrated types become `Sequence`+`Collection` dual-conformers, so every count-style operation must stay single-homed per the principle above, or the shadowing returns across the whole cohort.

## Background & motivation

The institute's `Sequence.\`Protocol\`` (in `swift-sequence-primitives`) carries a default `var count: Cardinal { consuming get }` at `Sequence.Protocol+Count.swift:21`, plus a companion `consuming func count(where:) -> Cardinal` at the same file:39. Both bodies iterate the sequence via `consuming makeIterator()` and tally. The placement of the eager-count *property* on `Sequence.\`Protocol\`` is a deliberate institute choice ratified yesterday (2026-05-21) by `swift-sequence-primitives/Research/count-direct-vs-fluent-and-hint-namespace.md` v1.0.0 (DECISION, commit `ac09a43`). That DECISION chose Option 3 of three alternatives — direct `seq.count: Cardinal` plus a separate `seq.hint.count` namespace — explicitly to "honor the stdlib-aligned `seq.count: Cardinal` ergonomics for the common case." The DECISION's verification grep across `swift-primitives`, `swift-standards`, `swift-foundations` found "no downstream consumer in the workspace imports `Sequence_Primitives`'s `.count.all` / `.count.where` paths."

That DECISION was authored without knowledge of a separate defect that surfaced the next day in `swift-buffer-primitives`: nine-plus test compile errors with diagnostic `'buffer' used after consume`, manifesting on `Buffer<Int>.Ring.Inline<4>`, `Buffer<Int>.Ring.Small<4>`, `Buffer<Int>.Linked<2>.Inline<8>`, and `Buffer<Int>.Linear.Inline<...>` test fixtures. The sibling investigation `swift-buffer-primitives/HANDOFF-buffer-borrowing-count-sequence-detachment.md` Findings section (RECOMMENDATION 2026-05-22) traced the defect to overload-resolution shadowing: each affected Buffer type carries a typed `var count: Index<Element>.Count { borrowing get }` accessor on a `~Copyable`-gated extension, AND conforms to `Sequence.\`Protocol\`` with a tighter `where Element: Copyable` clause. When the test instantiates with `Int` (Copyable), Swift selects the protocol-default consuming `count: Cardinal` per its more-specific where-clause, even though the typed accessor sits in a direct extension. The receiver is unconditionally `~Copyable` (storage is `@_rawLayout`), so the `consuming get` is a real consume — not the implicit-copy escape hatch for Copyable receivers. Subsequent test lines that touch `buffer` fail with use-after-consume.

The buffer-side Findings recommend Option 1 of three options enumerated in that brief: drop `Sequence.\`Protocol\`` from the affected Buffer types and (where consumer iteration requires it) add `Collection.\`Protocol\``. That recommendation is local — it resolves the buffer test failures by removing the shadowing conformance on the affected types, leaving `Sequence.\`Protocol\``'s count default in place for everyone else. The principal's reframe (per the brief that opened this assessment): **a local fix at the conformer is decision-aligned; the first-principles question is whether `count` belongs on `Sequence.\`Protocol\`` at all.** Apple's stdlib answer is no — `Sequence` has `underestimatedCount: Int { get }` (default 0, optimization hint) and no eager `count`; `Collection` has `count: Int { get }` (O(n) default, O(1) under `RandomAccessCollection`). The institute deviated from that placement on stdlib-mental-model-match grounds (per the prior DECISION's Option 3 rationale), but the same Apple-mirror argument is more accurately satisfied by mirroring Apple's *placement* (count on Collection.Protocol, hint on Sequence.Protocol) than by mirroring only Apple's *ergonomic shape* (direct vs fluent) at the wrong level.

This assessment evaluates three concrete options for relocating or removing the `count` default on `Sequence.\`Protocol\``: (a) move `count` onto `Collection.\`Protocol\`` with a typed return; (b) move `count` onto a new opt-in sub-protocol (e.g., `Sequence.Counting.\`Protocol\``); (c) remove the default entirely and require conformers to provide their own. It does not pre-decide the answer; it produces the substrate the principal needs to choose.

Composes with: `swift-institute/Research/collection-sequence-protocol-detachment.md` v1.1.0 (DECISION, 2026-02-23) which established that `Collection.\`Protocol\`` does not inherit from `Sequence.\`Protocol\``; verified in-tree at `swift-collection-primitives/Sources/Collection Protocol Primitives/Collection.Protocol.swift:39–44`. Composes with `swift-sequence-primitives/Research/sequence-protocol-surface-simplification.md` v1.1.0 (DECISION, 2026-02-23) which keeps the six-protocol Sequence family as-is on capability-orthogonality grounds. Neither prior doc addresses where `count` *as a default method* should live; they address the protocol-hierarchy shape only.

## Current shape of the count defaults

Enumeration of every counting-related or count-adjacent default on `Sequence.\`Protocol\`` (verified file:line at write time per `[RES-023]`):

| Default | File:Line | Return type | Ownership | Where-clause | Notes |
|---|---|---|---|---|---|
| `var count: Cardinal` | `swift-sequence-primitives/Sources/Sequence Protocol Primitives/Sequence.Protocol+Count.swift:21` | `Cardinal` | `consuming get` | `Self: ~Copyable, Element: Copyable` | The shadowing site identified in the sibling Buffer handoff |
| `consuming func count(where:)` | `Sequence.Protocol+Count.swift:39` | `Cardinal` | `consuming func` | `Self: ~Copyable, Element: Copyable` | Method form; takes `(borrowing Element) -> Bool` |
| `consuming func collect()` | `swift-sequence-primitives/Sources/Sequence Hint Primitives/Sequence.Protocol+collect.swift:21` | `[Element]` | `consuming func` | `Self: ~Copyable, Element: Copyable` | Eager terminal; reads `self.hint.count` for capacity pre-allocation |

Cross-checked against every file in `Sources/Sequence Protocol Primitives/` and every `consuming` default across `Sources/Sequence */`:

- `Sequence.Protocol.swift` (the protocol declaration) requires only `consuming func makeIterator() -> Iterator` per file lines 97–128. It declares NO `count`, NO `isEmpty`, NO `underestimatedCount`, NO `first`. The protocol's only requirement is the iterator factory.
- `Sequence.Protocol+Count.swift` (above) is the sole file that adds counting-flavored defaults on the protocol-extension layer.
- `Sequence.Protocol+collect.swift` adds the eager terminal; it consumes self but is named `collect`, not `count`. It calls `self.hint.count` (the under-estimate hint via `Property.Inout` — see below).
- Sibling files `Sequence.Protocol+ForEach.swift`, `Sequence.Protocol+Map.swift`, `Sequence.Protocol+Filter.swift`, `Sequence.Protocol+Drop.swift`, `Sequence.Protocol+Prefix.swift`, `Sequence.Protocol+Reduce.swift`, `Sequence.Protocol+Contains.swift`, `Sequence.Protocol+Satisfies.swift`, `Sequence.Protocol+First.swift`, `Sequence.Protocol+compactMap.swift`, `Sequence.Protocol+flatMap.swift` each provide tag-based fluent accessors (`var forEach: Property<…>.Inout`, `var map: …`, etc.). These return `Property.Inout` views — they are NOT counting defaults and do not exhibit the shadowing pattern. They are out of scope for this assessment.
- `Sequence.Hint+Property.Inout.swift:29` provides `var count: Cardinal { .zero }` on `Property.Inout where Base: Sequence.\`Protocol\`, Tag == Sequence.Hint`. This is the institute's stdlib-aligned `underestimatedCount` analogue: cheap, defaults to zero, lives under the `seq.hint.*` namespace per the 2026-05-21 DECISION. It is NOT a sibling of `Sequence.Protocol`'s direct `count`; it is the under-estimate hint and is consumed by `collect()` for `Array.reserveCapacity`. This default does NOT shadow anything because (a) `seq.hint` is a `Property.Inout` accessor, not a property on `Self`, and (b) the comparable Buffer types do not provide a `seq.hint.count` override.

**Conclusion of §2**: only `var count: Cardinal { consuming get }` (Sequence.Protocol+Count.swift:21) exhibits the bug-vulnerable shadowing shape. The companion `count(where:)` method has no shadowing risk because no concrete type provides a same-name method with a different return type (a name-and-arity collision with a typed accessor cannot occur — `var count` vs `func count(where:)` have distinct identifiers at the call site). `collect()` and `hint.count` do not interact with the shadowing issue. The defect surface is one accessor.

## Direct conformers

Workspace enumeration completed via subagent (read-only; full conformer list available in subagent report). **Total: 73 direct conformers** of `Sequence.\`Protocol\``, classified per the brief:

### Summary

| Group | Count | Where | Counting impact of `count` relocation |
|---|---|---|---|
| **A — Multi-pass indexed storage** | 40 | Buffer (8), Queue (8), Array (4), Stack (4), Set.Ordered (4), Dictionary.Ordered (5), Heap (5), Vector (2), Bit.Vector (6), Input.Slice (1) [`Verified: 2026-05-22`] | Bug-vulnerable. Each carries (or could carry) a typed `var count: Index<Element>.Count { borrowing get }`. Relocation to `Collection.\`Protocol\`` resolves the shadowing on whichever of these also conforms to Collection.\`Protocol\``. |
| **B — Lazy single-pass / consuming chain** | 32 | Sequence.{Map, Map.Eager, Map.Flat, Map.Compact, FlatMap, CompactMap, Filter, Drop.First, Drop.While, Prefix.First, Prefix.While, Difference.Changes, Difference.Steps} (combinator core); Bit.Vector.{Ones, Zeros}.View; Hash.Occupied.{View, Static}; Cyclic.Group.Static (iterator-typed) [`Verified: 2026-05-22`] | Semantically defensible for consuming-count: these are lazy pipelines; counting requires consuming iteration by construction. Loss of the default would force each to provide its own count or omit it. |
| **C — Other** | 1 | `Input.Slice` (cross-classified: also Collection.Slice.Protocol; both lazy-slice semantics and indexed access) | Negligible — single instance, behavior tracks Group A. |

Verified subagent observations (each carried-forward finding rechecked against current source at write time):

- Only **3 of 40 Group A** types currently ALSO conform to `Collection.\`Protocol\``: `Queue.DoubleEnded`, `Queue.DoubleEnded.Fixed`, and `Buffer.Linear` (via `Buffer.Linear+Collection.Protocol.swift`). Plus `Input.Slice` conforms via `Collection.Slice.Protocol`. The remaining ~36 Group A types are Collection.Protocol-conformance-eligible but haven't migrated yet — a pre-existing class-(c) ecosystem follow-up cited explicitly in `count-direct-vs-fluent-and-hint-namespace.md` §"Cross-package coordination note." [`Verified: 2026-05-22`]
- The bug-vulnerable population — Group A types that have BOTH (i) typed `var count` accessors AND (ii) `Sequence.\`Protocol\`` conformance — is roughly the entire 40 of Group A (every Group A type carries its own typed count by construction; the conformance set is the shadowing population).
- Heap variants explicitly override `underestimatedCount: Int` (in their `Swift.Sequence` integration, not `Sequence.\`Protocol\``). Buffer.Ring conformers similarly override `underestimatedCount` at `Buffer.Ring+Span.swift:122`. These overrides are unrelated to the institute-side `var count: Cardinal`; they target Apple's `Sequence.underestimatedCount`. [`Verified: 2026-05-22`]
- ZERO conformers exist outside `swift-primitives/`. `swift-standards/`, `swift-foundations/`, `swift-institute/`, `rule-institute/`, `rule-law/` contribute zero direct conformers. Foundation-grep cross-references in `swift-foundations/swift-linter-rules/Research/` flag `Sequence` as a stdlib-shadowing protocol but those are linter-rule research, not source conformances. [`Verified: 2026-05-22`]
- Sibling `Sequence.Borrowing.\`Protocol\`` is co-conformed by Buffer.Linear and Buffer.Ring variants on the same line as `Sequence.\`Protocol\`` — load-bearing for span-based iteration optimization. Relocation of `count` off `Sequence.\`Protocol\`` does NOT remove the `Sequence.Borrowing.\`Protocol\`` conformance because they are sibling protocols. [`Verified: 2026-05-22`]

### Group A — representative instances (file:line for each)

| Type | Conformance site | Where-clause | Also Collection.Protocol? |
|---|---|---|---|
| `Buffer.Ring.Inline<capacity>` | `Buffer.Ring.Inline Copyable.swift:57` | `where Element: Copyable` (`@unsafe`) | No |
| `Buffer.Linear` | `Buffer.Linear+Span.swift:51` | `where Element: Copyable` | **Yes** (`Buffer.Linear+Collection.Protocol.swift:5`) |
| `Buffer.Linear.Bounded` | `Buffer.Linear+Span.swift:108` | `where Element: Copyable` | No |
| `Buffer.Linked` | `Buffer.Linked Copyable.swift:186` | `where Element: Copyable` | No |
| `Bit.Vector.Ones.View` | `Bit.Vector.Ones.View+Sequence.Protocol.swift` | unconditional | No |
| `Bit.Vector.Zeros.View` | `Bit.Vector.Zeros.View+Sequence.Protocol.swift` | unconditional | No |
| `Vector` | `Vector+Sequence.Protocol.swift` | unconditional | No |
| `Hash.Occupied.View` | `Hash.Occupied.View+Sequence.Protocol.swift` | unconditional | No |
| `Cyclic.Group.Static<modulus>` | `Cyclic.Group.Static+Sequence.Protocol.swift` | unconditional | No |
| `Set.Ordered.{Fixed, Static, Small} Copyable.swift` (4 instances) | `Set Ordered Primitives/*.swift` | `where Element: Copyable` (4 sites) | No |
| `Dictionary.Ordered.{Bounded, Static, Small} Copyable.swift` (5 instances) | `Dictionary Ordered/Bounded Primitives/*.swift` | `where (Key, Value): Copyable` (5 sites) | No |
| `Queue.{Static, Fixed, Small, Dynamic, DoubleEnded, Linked} Copyable.swift` (6 instances) | `Queue */*.swift` | varies | Two of six (DoubleEnded variants) |
| `Heap.{Static, Small, Fixed, MinMax, Binary} Copyable.swift` (5 instances) | `Heap */*.swift` | `where Element: Copyable` (5 sites) | No |
| `Array.{Dynamic, Small, Fixed, Static}` (4 instances) | `Array */*.swift` | varies (~Copyable / Copyable) | No (the array unification work targets `Collection.Bidirectional` per `collection-sequence-protocol-detachment.md`; not landed yet) |

[`Verified: 2026-05-22`]

### Group B — representative instances

| Type | Conformance site | Notes |
|---|---|---|
| `Sequence.Map<Source, Output>` | `Sequence.Map.swift` | Lazy combinator; consuming chain |
| `Sequence.Filter<Source>` | `Sequence.Filter.swift` | Lazy combinator |
| `Sequence.Drop.First<Source>` | `Sequence.Drop.First.swift` | Lazy combinator |
| `Sequence.Drop.While<Source>` | `Sequence.Drop.While.swift` | Lazy combinator |
| `Sequence.Prefix.First<Source>` | `Sequence.Prefix.First.swift` | Lazy combinator |
| `Sequence.Prefix.While<Source>` | `Sequence.Prefix.While.swift` | Lazy combinator |
| `Sequence.Map.{Compact, Flat, Eager}` (3) | `Sequence.Map.*.swift` | Lazy combinators |
| `Sequence.CompactMap<Source, Output>` | `Sequence.CompactMap.swift` | Lazy combinator |
| `Sequence.FlatMap<Source, Output>` | `Sequence.FlatMap.swift` | Lazy combinator |
| `Sequence.Difference.{Changes, Steps}` (2) | `Sequence.Difference.*.swift` | Diff iteration |

For Group B, `count: Cardinal { consuming get }` is semantically correct (these are by-construction single-pass; counting requires consumption). No shadowing risk for Group B because none of them carry a typed `var count: Index<…>.Count` accessor — they have no stored count to expose.

### Group C — representative instances

`Input.Slice` is the sole Group C — co-conforms to both Collection.Slice.Protocol and Sequence.Protocol; behavior tracks Group A patterns for the indexed surface. Single instance.

## Direct call sites

Workspace-wide grep over `Sources/` and `Tests/` for `.count` on Sequence.Protocol-typed receivers (sampled and characterized per the brief's "20-30 sites, then characterize" guidance):

**The over-inclusive grep `grep -rn "\.count\b"` returns thousands of hits across the workspace, the vast majority being `.count` on concrete types (Swift.Array, Swift.String, `Index<T>.Count`, Buffer.X.count direct, etc.). These are IRRELEVANT to this assessment — concrete-type `.count` resolves to the type's own member regardless of whether `Sequence.\`Protocol\``'s default exists.**

The load-bearing class is `.count` calls where the receiver is a generic parameter constrained `some Sequence.\`Protocol\`` or `where T: Sequence.\`Protocol\``. The targeted grep against `Sources/`:

```bash
grep -rn "where.*Sequence\.\`Protocol\`\|some Sequence\.\`Protocol\`" \
  swift-primitives/ swift-standards/ swift-foundations/ swift-institute/ \
  2>/dev/null | grep -v Tests | grep -v Experiments | grep -v "\.docc/"
```

Returns:

- README example (1): `swift-sequence-primitives/README.md:20` — documentation example, not a call site.
- Property.Inout extension constraints (6): `Sequence.{ForEach, Reduce, Hint, Contains, First, Satisfies}+Property.Inout.swift` — these are TAG-EXTENSION constraints (`where Base: Sequence.\`Protocol\`, Tag == Sequence.X`), NOT generic-function call sites. They constrain a Property.Inout view's Base type and do not call `.count` on the constrained generic.

**Generic-context call-site count: ZERO in workspace Sources/**. The `count-direct-vs-fluent-and-hint-namespace.md` v1.0.0 DECISION's verification grep (executed 2026-05-21) reached the same conclusion: "No downstream consumer in the workspace imports `Sequence_Primitives`'s `.count.all` / `.count.where` paths." Twenty-four hours later, the same is true for the new `seq.count: Cardinal` shape — the eager-count property on Sequence.Protocol-typed generic receivers is consumed only by tests and documentation, not by production sources.

**Load-bearing call-site count via concrete-type instantiation**: this is the bug-vulnerable population from §3 Group A. When a test or consumer writes `let buffer: Buffer<Int>.Ring.Inline<4> = …; buffer.count`, overload resolution sees BOTH the typed accessor AND the Sequence.Protocol default (because Buffer.Ring.Inline conforms to Sequence.Protocol). The default wins per the more-specific where-clause rule (per the sibling buffer handoff's Findings §"Diagnosis refinement"). This is the empirically-confirmed defect class.

Estimate of bug-vulnerable call sites: at minimum the 9+ enumerated failing tests in `swift-buffer-primitives` per the sibling handoff brief; the actual count across Group A's 40 conformers is substantially higher when production code or tests instantiate Group A types and access `.count`. The full enumeration requires per-Group-A-type test-suite scan, which is out-of-scope for this assessment (it's a downstream consequence of the placement decision, not input to it).

**Classification table** (sample of 6 sites; representative shape):

| Site | Receiver | Generic vs concrete | Load-bearing? |
|---|---|---|---|
| `swift-buffer-primitives/Tests/.../Buffer.Ring.Inline Tests.swift` (per HANDOFF brief enumeration) | `Buffer<Int>.Ring.Inline<4>` | Concrete (Group A) | YES — shadowing site |
| `swift-buffer-primitives/Tests/.../Buffer.Ring.Small Tests.swift` (per brief) | `Buffer<Int>.Ring.Small<4>` | Concrete (Group A) | YES |
| `swift-buffer-primitives/Tests/.../Buffer.Linked.Inline Tests.swift` (per brief) | `Buffer<Int>.Linked<2>.Inline<8>` | Concrete (Group A) | YES |
| `swift-sequence-primitives/Tests/.../count Tests.swift` (per `count-direct-vs-fluent` DECISION migration) | `Sequence.Fixture.Source` (test fixture) | Concrete (test type) | Test-only |
| `swift-sequence-primitives/Sources/Sequence Hint Primitives/Sequence.Protocol+collect.swift:22` | `self` (in `consuming func collect()` extension on `Sequence.\`Protocol\``) | Generic body call | **Calls `self.hint.count`, NOT `self.count`** — out of scope for this defect |
| `swift-foundations/*/Sources/**.swift` | (none found via grep) | — | None |

## Option-by-option impact analysis

### Option (a): Move `count` to `Collection.\`Protocol\``

#### What lands where

`Sequence.Protocol+Count.swift:21` removed. New file at `swift-collection-primitives/Sources/Collection Count Primitives/Collection.Protocol+Count.swift`:

```swift
public import Index_Primitives

extension Collection.`Protocol` where Self: ~Copyable {
    /// The number of elements in the collection.
    ///
    /// Default iterates from `startIndex` to `endIndex` counting. O(n)
    /// for protocol-default implementations; O(1) when overridden on
    /// types with stored counts (most Group A conformers).
    @inlinable
    public var count: Index<Element>.Count {
        borrowing get {
            var index = startIndex
            let end = endIndex
            var count = Cardinal.zero
            while index < end {
                count += .one
                index = index(after: index)
            }
            return Index<Element>.Count(_unchecked: count)
        }
    }
}
```

Return type changes from `Cardinal` to typed `Index<Element>.Count` — matches the institute's `Collection.\`Protocol\`` ergonomic conventions and the typed-accessor shape Group A conformers already provide. Ownership is `borrowing get` (Collection's contract is multi-pass; counting via index traversal does not consume). The current `Collection.\`Protocol\``'s `Collection.Count.View<Base>` fluent shape (the `.count.all` / `.count.where` shape) is the class-(c)-queued migration cited in `count-direct-vs-fluent-and-hint-namespace.md`'s "Cross-package coordination note"; the new direct accessor either supersedes or coexists with it per implementer choice. (Recommendation below picks supersede.)

`count(where:)`: leave on `Sequence.\`Protocol\`` at `Sequence.Protocol+Count.swift:39`. It does not exhibit the shadowing concern (different identifier shape — `func count(where:)` vs `var count`; no concrete-type method with the same signature shadows it). Sequence.Protocol's combinator chains can still filter-count via `.count(where:)`.

`collect()` at `Sequence.Protocol+collect.swift`: unchanged. It reads `self.hint.count` (the Property.Inout hint, not the eager count). Independent of this relocation.

#### Direct-conformer impact

- **Group A (40 conformers)**: gain the new typed `count` automatically once they conform to `Collection.\`Protocol\``. The 3+1 already-conformant types get it immediately; the ~36 not-yet-conformant types are the same set queued under the buffer-borrowing recommendation (drop Sequence.Protocol, add Collection.Protocol). Group A's typed accessors (e.g., `Buffer.Ring.Inline.swift:21`'s `var count: Index<Element>.Count { borrowing get { header.count } }`) override the protocol default with O(1) shapes. No accessor regressions; resolves the shadowing because Sequence.Protocol no longer carries a competing default.
- **Group B (32 conformers)**: lose `.count: Cardinal`. None of them conform to `Collection.\`Protocol\`` (they have no indexed storage), so they lose the eager-count property entirely. They retain `.count(where:)` (filter-count remains on Sequence.Protocol) and `.collect()` (terminal). For combinators like `Sequence.Map` and `Sequence.Filter`, the eager-count loss is semantically correct — these are lazy pipelines and counting them is a terminal operation; the canonical terminal is `.collect().count` (where the materialized Array's `count` is O(1)) or a hypothetical `.count(where: { _ in true })`. Per the prior DECISION's verification grep, no workspace consumer relies on `seq.count` on a lazy combinator.
- **Group C (1 conformer)**: `Input.Slice` already participates in Collection.Slice.Protocol; presumably gains the new count via Collection.Protocol's transitively related shape. Verify at execution time.

#### Call-site impact

Per §4, **zero** workspace generic-context call sites currently consume `seq.count` on a `some Sequence.\`Protocol\``-constrained receiver. The Group A concrete-instantiation sites that today resolve to the consuming default would resolve to the typed accessor instead — the desired behavior, resolving the bug. Test sites in `Sequence.Count Tests.swift` (in `swift-sequence-primitives/Tests/`) that use `Sequence.Fixture.Source` (a Group B-shaped test fixture without Collection.Protocol conformance) would lose `seq.count` and need to migrate to `seq.collect().count` or `seq.count(where: { _ in true })`. Estimated test migration: 1–2 test files in swift-sequence-primitives; no production migration; an indeterminate number of bug-fixed test sites in swift-buffer-primitives and other Group A consumers.

#### Lazy-chain impact

`Sequence.Map`, `Sequence.Filter`, etc. lose `.count`. `collect()` is unchanged (consumes `self.hint.count`, not `self.count`). Verified: `collect()` at `Sequence.Protocol+collect.swift:22` reads `self.hint.count` (Property.Inout hint, defaults to zero) for `Array.reserveCapacity` — independent of the eager count. `count(where:)` stays on Sequence.Protocol — combinators retain filter-count.

The 2026-05-21 DECISION's commit message and rationale state Option 3 was chosen "to honor the stdlib-aligned `seq.count: Cardinal` ergonomics for the common case." Under Option (a), `seq.count` on a Sequence.Protocol receiver no longer exists; the stdlib-alignment argument relocates from "match stdlib's `Collection.count` on the wrong protocol" to "match stdlib's `Collection.count` on the right protocol." The user-facing ergonomic for the common case (Buffer/Array/Set/Dictionary types, which are Collection.Protocol-shape) is preserved and improved — the typed `Index<Element>.Count` return is institute-canonical and `borrowing get` removes the surprise-consume footgun.

#### Test exposure

Estimate: 1–2 sequence-primitives test files (`Sequence.Count Tests.swift` and possibly its dependents) need migration; 9+ buffer-primitives tests resolve correctly (the bug-fix); zero estimated breakage in `swift-standards`/`swift-foundations`/`swift-institute` per the §4 grep. Total: <20 test sites across the workspace.

#### Risks / unknowns

- **Migration timing for Group A's Collection.Protocol conformance**: the ~36 Group A conformers not yet at Collection.Protocol need to land that conformance to get the new `count`. The buffer-borrowing brief recommends this in its Phase 2; the rest of the cohort (Heap, Set.Ordered, Dictionary.Ordered, etc.) follow the same pattern. If a Group A type is on the bug-vulnerable list AND not yet on Collection.Protocol, the relocation removes the Sequence-side shadowing but leaves the type without a default `count` until it conforms. The typed accessor on the concrete type remains and is now unshadowed; this is the *fixed* state, not the broken state.
- **Collection.Count.View<Base> fluent shape coexistence**: the existing `Collection.Count.View` (at `Collection.Count.swift:50`) provides `.count.all` / `.count.where`. If the new direct `count: Index<Element>.Count` lands without removing the View, there are now TWO `count` accessors on `Collection.\`Protocol\`` — a direct property and a fluent View. This is a sub-decision the implementer should resolve at execution time: either supersede the View (delete `Collection.Count.swift` + replace with the direct shape, matching the Sequence.Protocol side's Option 3 cleanup) or coexist (rename one). Recommendation below picks supersede for symmetry with the recent Sequence side.
- **Collection.Indexed legacy**: per `collection-sequence-protocol-detachment.md` Step B, `Collection.Indexed` is queued for deletion. Group A conformers migrating to multi-pass collections should target `Collection.\`Protocol\`` or `Collection.Bidirectional`, NOT `Collection.Indexed`.

### Option (b): Move `count` to a new opt-in sub-protocol `Sequence.Counting.\`Protocol\``

#### What lands where

New file `swift-sequence-primitives/Sources/Sequence Counting Primitives/Sequence.Counting.Protocol.swift`:

```swift
extension Sequence {
    public protocol Counting: Sequence.`Protocol` & ~Copyable {}
}

extension Sequence.Counting where Element: Copyable {
    @inlinable
    public var count: Cardinal {
        consuming get { /* iterate + count */ }
    }
}
```

Existing `Sequence.Protocol+Count.swift:21` removed from `Sequence.\`Protocol\``'s extension; relocated to `Sequence.Counting`'s extension. `count(where:)` stays on `Sequence.\`Protocol\``. Group B combinators that want `.count` opt into `Sequence.Counting`. Group A conformers do not opt in (they avoid the shadowing). Collection.Protocol-conformant types do not opt in either (they get `count` from Collection.Protocol via the buffer-borrowing-recommended migration, but the Sequence-side count is a separate ladder).

#### Direct-conformer impact

- **Group A (40)**: stop conforming to `Sequence.Counting` (do not opt in); avoid shadowing. The Sequence.Protocol conformance is preserved unchanged, so makeIterator() / forEach / etc. still work. This is the conservative migration — no Group A conformer changes its conformance list except by NOT acquiring the new sub-protocol.
- **Group B (32)**: opt into `Sequence.Counting` to preserve `.count`. ~32 added conformance declarations across Sequence combinator types. Per-conformer cost is one line (`extension Sequence.Map: Sequence.Counting where Source: Sequence.`Protocol`, Source.Element: Copyable {}` or similar).
- **Group C (1)**: per Group A pattern, does not opt in.

#### Call-site impact

`seq.count` on a `some Sequence.\`Protocol\``-typed receiver no longer compiles — would need `some Sequence.Counting`. Per §4, zero workspace generic-context call sites exist; the impact is documentary-only (README example updates). Group A concrete-instantiation shadowing is resolved by Group A's non-opt-in.

#### Lazy-chain impact

Combinators that opt in retain `.count`. Combinators that don't opt in lose `.count`. The chain composition is preserved (lazy combinators wrap lazy combinators regardless of `Sequence.Counting` membership).

#### Test exposure

Roughly similar to Option (a) — 1–2 sequence-primitives tests need migration; plus ~32 conformance-declaration additions on Group B types (mechanical, low-risk).

#### Risks / unknowns

- **Surface area growth**: adds a seventh Sequence-family protocol. `sequence-protocol-surface-simplification.md` v1.1.0 concluded the existing six protocols capture orthogonal capabilities and cannot be simplified. Adding a seventh on an axis the prior research did not consider (counting capability as orthogonal to iteration) requires explicit justification under the same orthogonality framing. The justification is plausible — count IS an orthogonal capability to iteration in the lazy-vs-eager sense — but it is precedent-setting.
- **Group B opt-in coverage**: every existing Sequence combinator needs the opt-in declaration. ~32 sites to touch.
- **Cross-protocol semantics**: `Sequence.Counting` refines `Sequence.\`Protocol\``; conformers must still provide `makeIterator()`. The opt-in is not free — it carries the consuming-iteration contract, which combinators already satisfy. No additional API surface required from Group B opt-in conformers.
- **Naming**: `Sequence.Counting` (gerund) per `[PKG-NAME-007]`-style precedent — gerunds for capability protocols. Alternative `Sequence.Countable` (adjective) is rejected by ecosystem-naming patterns. `Sequence.Counting.\`Protocol\`` follows the `Nest.Name` pattern per `[API-NAME-001]`.

### Option (c): Remove the default entirely

#### What lands where

`Sequence.Protocol+Count.swift:21` (the property) removed. `count(where:)` retained at file:39 (no shadowing risk). No replacement protocol or default. Conformers wishing to expose an eager count provide their own implementation.

#### Direct-conformer impact

- **Group A (40)**: each provides own `var count` if it doesn't already. Most already do (the typed accessors at e.g. `Buffer.Ring.Inline.swift:21`). The shadowing collision dissolves because Sequence.Protocol no longer provides a competing default. Net Group A impact: zero changes; the bug fix happens automatically.
- **Group B (32)**: each provides own `var count` OR omits the accessor. The combinators' natural implementations either delegate to the source's `count` (recursive — would need source to have one) or iterate and tally (a duplicate of the removed default body). Practically, Group B types would either:
  - Provide a per-combinator implementation: ~32 short methods copy-pasting the removed default's body (an antipattern — replicates the very code we're removing).
  - Drop the `count` accessor entirely from combinators: callers consume the combinator chain via `.collect()` and call `.count` on the resulting Array. This is the cleanest option but is a behavior change.
  - Group B retains `count(where:)` as a hook for filtered counting that callers can use via a trivially-true predicate (`.count(where: { _ in true })`) — semantically equivalent but ergonomically worse.
- **Group C (1)**: Input.Slice — provides own.

#### Call-site impact

Per §4, zero workspace generic-context call sites currently consume `seq.count` on a Sequence.Protocol-typed receiver. Test fixtures in sequence-primitives that use the default need migration. Group A concrete-instantiation shadowing is resolved.

#### Lazy-chain impact

If Group B combinators each provide own `count` (the duplicate-default route), the lazy-chain semantics are preserved. If they omit `count`, callers must `.collect()` to count — a behavior change that increases composition cost (forces materialization for counting).

#### Test exposure

Highest of the three options if Group B opts for per-combinator `count` implementations (~32 new methods + their tests). Lowest if Group B opts for `.collect().count` (~1–2 sequence-primitives test migrations + documentation updates).

#### Risks / unknowns

- **Replication antipattern**: each Group B combinator providing its own near-identical `count` body replicates the removed default — a code-smell.
- **Behavior change for lazy chains**: forcing `.collect()` for combinator counts is a real cost (materializes the chain). Acceptable if no one was relying on it (per §4 grep, no one was), but the institute would be making a different ergonomic statement than the 2026-05-21 DECISION.
- **No new protocol invented**: the cleanest option from a "minimum protocol surface" perspective. `sequence-protocol-surface-simplification.md` v1.1.0's "keep all six" verdict is preserved literally — no seventh protocol added.

## Cross-protocol consistency check

| Sibling protocol | File | Currently provides counting default? | Could inherit one? | Impact of relocating only Sequence.Protocol's count |
|---|---|---|---|---|
| `Sequence.Borrowing.\`Protocol\`` | `Sequence.Borrowing.Protocol.swift:43` | No — declaration is `protocol \`Protocol\`<Element>: ~Copyable, ~Escapable` with only `makeIterator()` and `associatedtype Iterator`. No `count` default. | Could — its iterator is borrowing and span-based, so a count could iterate spans and tally. No structural blocker. | NEUTRAL — Sequence.Borrowing.Protocol is the chunked-span optimization sibling per `sequence-protocol-surface-simplification.md` v1.1.0's reframing. It doesn't currently provide count; whether to add one is a separate decision. Relocating Sequence.Protocol's count doesn't create or resolve any Sequence.Borrowing-side issue. [`Verified: 2026-05-22`] |
| `Sequence.Drain.\`Protocol\`` | `Sequence.Drain.swift:73` | No — sole requirement is `mutating func drain(_:)`. No counting defaults. | Could not naturally — drain consumes elements, so count via drain would destroy state. The semantically correct counting for Drain conformers is a count *before* drain, not via drain. Conformers that want it provide a separate accessor. | NEUTRAL — independent from this assessment. [`Verified: 2026-05-22`] |
| `Sequence.Clearable` | `Sequence.Clearable.swift:32` | No — sole requirement is `mutating func removeAll()`. No counting defaults. | Could (inherits from Sequence.\`Protocol\``). Today Clearable inherits Sequence.Protocol's count by virtue of refinement; under Options (a), (b), (c) Clearable's behavior reflects the parent decision. Under Option (b) Clearable could additionally refine `Sequence.Counting` if its semantic warrants. | Tracks Sequence.Protocol's decision. [`Verified: 2026-05-22`] |
| `Sequence.Consume.\`Protocol\`` | `Sequence.Consume.swift:85` | No — requires `consuming func consume() -> View<Element, ConsumeState>`. No counting defaults. | Could — like Drain, counting before consume is the right shape; via consume destroys state. | NEUTRAL. [`Verified: 2026-05-22`] |
| `Sequence.Iterator.\`Protocol\`` | `swift-sequence-primitives/Sources/Sequence Iterator Primitives/...` (not read at this assessment depth) | No — iterator protocols carry `next()` and `nextSpan(maximumCount:)`; no count concept. | No — iterators don't have a count of their own; the source does. | NEUTRAL. |

**Consistency observation**: only `Sequence.\`Protocol\`` carries a counting default among the six sequence protocols. The decision is therefore localized; siblings do not need parallel relocation. Under Option (b) the new `Sequence.Counting.\`Protocol\`` would be a seventh sibling, consistent with the six-protocol-orthogonality framing (counting is an orthogonal capability).

## Apple stdlib parallel

Apple's standard library places counting concerns as follows (verified primary sources per `[RES-032]`):

| Protocol | Property | Default | Notes |
|---|---|---|---|
| `Swift.Sequence` | `underestimatedCount: Int { get }` | `0` | Optimization hint — meant for cheap capacity pre-allocation; never iterates. Documented at [Sequence/underestimatedCount](https://developer.apple.com/documentation/swift/sequence/underestimatedcount) |
| `Swift.Sequence` | (no `count` property) | — | Sequence has no `count` because sequences may be infinite or unknown-length. Counting is a Collection capability, not a Sequence capability. |
| `Swift.Collection` | `count: Int { get }` | iterates `startIndex...<endIndex` (O(n) for forward-only) | Documented at [Collection/count](https://developer.apple.com/documentation/swift/collection/count) |
| `Swift.RandomAccessCollection` | `count: Int { get }` (override) | O(1) via index distance | Per RandomAccessCollection's requirement that `distance(from:to:)` is O(1) |
| `Swift.Collection` | `isEmpty: Bool { get }` | `startIndex == endIndex` | Cheap check using indices |

The design rationale: Sequence is the iterator-producing abstraction; sequences may be infinite (lazy infinite ranges, infinite generators), so eager count is not a universal capability of sequences. Collection adds multi-pass stable storage with bounded indices, which makes count well-defined and computable. RandomAccessCollection further constrains to O(1) count via index arithmetic. This three-layer placement matches the institute's own `collection-sequence-protocol-detachment.md` v1.1.0 DECISION at the protocol-hierarchy level — but the institute's `count` placement on `Sequence.\`Protocol\`` (per the 2026-05-21 `count-direct-vs-fluent` DECISION) deviates from Apple's placement.

The deviation's intentional rationale was stdlib-mental-model-match for the *call-site shape* (direct `seq.count`, not fluent `seq.count.all`). The same stdlib-mental-model-match argument applied to *placement* (count on Collection, hint on Sequence) is more accurate to Apple's design than the current placement.

Tension with institute conventions: the institute's `Sequence.\`Protocol\`` admits ~Copyable Self AND ~Copyable Element per SuppressedAssociatedTypes adoption (`sequence-protocol-noncopyable-elements.md` v2.0.0); Apple's stdlib Sequence is gated on Copyable. The institute's broader semantic envelope sharpens the consuming-count concern — for ~Copyable Self conformers, `consuming get` is a real ownership transfer with no implicit-copy escape. Apple's Sequence does not face this concern because all Sequence conformers are Copyable. The institute therefore has stronger structural reasons than Apple to keep count off Sequence.Protocol; the bug found in `swift-buffer-primitives` is exactly the materialization of that concern on a ~Copyable storage type.

## RECOMMENDATION

**Recommend Option (a) — move `count` from `Sequence.\`Protocol\`` to `Collection.\`Protocol\``, with a small refinement: retain `count(where:)` on `Sequence.\`Protocol\`` (no shadowing risk).**

### Rationale ranking per `[RES-022]` and `[RES-029]`

**Tier 1 — semantic identity** (dispositive): per `[RES-029]`'s ranking, a placement question's first tier is "where does the operation semantically live?" Apple's stdlib answers unambiguously: count belongs on Collection (multi-pass indexed storage), not on Sequence (iterator factory). The institute's `collection-sequence-protocol-detachment.md` v1.1.0 DECISION already established the same protocol-hierarchy separation — `Collection.\`Protocol\`` is standalone and does NOT inherit from `Sequence.\`Protocol\``. Placing `count` on `Sequence.\`Protocol\`` puts the operation on the wrong side of the institute's own structural split. Option (a) corrects this; Options (b) and (c) leave it half-corrected (Option b adds a new sub-protocol but keeps the count concept on the Sequence side of the split; Option c removes the default but doesn't establish the right home).

**Tier 2 — operational behavior of adjacent ecosystem types**: Apple's stdlib (Sequence has hint, Collection has count) is the dominant cross-system precedent. Rust's `Iterator` trait has `count(self) -> usize` (consuming — analogous to Sequence.Protocol's current shape) but Rust does NOT have a Collection protocol parallel; Rust's container types provide `len()` directly. Haskell's `Foldable` has `length :: Foldable t => t a -> Int` (eager, consuming-ish via fold). The institute is closest to Apple structurally (typed-protocol hierarchy, ~Copyable affordances); Apple's placement is the operational anchor.

**Tier 3 — cost / pragmatism / call-site impact** (tiebreaker only): per §4, zero workspace generic-context call sites would break. Per §3 Group A, 36+ types acquire the new `count` automatically as they migrate to `Collection.\`Protocol\`` per the buffer-borrowing-recommended cohort migration. Per §5 Option (a) test exposure, <20 sites total. Per §3 Group B, ~32 lazy combinators lose `.count: Cardinal` — but per the prior DECISION's verification grep, this is consumed by no production caller. The cost is bounded and concentrated in test files; the structural gain is permanent and correct.

### Why Option (b) is rejected as primary

Option (b) adds a seventh Sequence-family protocol on an axis (counting capability) that is structurally already addressed by Collection.Protocol. The institute would carry both `Sequence.Counting.\`Protocol\`` (for lazy combinators that want count) AND `Collection.\`Protocol\`` (for stable-storage types that have count). Two parallel ladders for the same concept invites confusion: "do I want Sequence.Counting because I'm a lazy combinator that materializes my count? Or do I want Collection.Protocol because I have indexed storage?" The semantic distinction is real but is better served by Collection.Protocol for the stable-storage case and by `seq.collect().count` (terminal materialization) for the lazy case. Option (b)'s value-add is enabling lazy-combinator counts without materialization — a real ergonomic win — but it duplicates a capability Collection.Protocol provides. It also breaks `sequence-protocol-surface-simplification.md` v1.1.0's "keep all six" framing (the seventh's justification differs from the six existing capability axes but the precedent matters).

### Why Option (c) is rejected as primary

Option (c) is the cleanest "no new protocol" answer but loses the eager-count default for Sequence.Protocol consumers entirely. Lazy combinators (Group B) would either replicate the removed default body (antipattern) or force callers through `.collect()` for any count. The forced-`.collect()` ergonomic is a real cost for lazy-chain users that the institute does not need to pay; Collection.Protocol's count handles the common case (stable storage), and `.collect().count` is the rare-case bridge for lazy chains.

### Refinement: retain `count(where:)` on `Sequence.\`Protocol\``

`count(where:)` (Sequence.Protocol+Count.swift:39) does not exhibit the shadowing concern (different identifier shape — method vs property; no concrete type provides a same-signature method). It is semantically consistent with Sequence.Protocol (consuming filtered iteration), and removing it would lose a useful API without solving any problem. Recommend keeping it on `Sequence.\`Protocol\`` at the same file:line; this preserves Sequence.Protocol's filter-count capability for both Group A and Group B conformers, including lazy combinators.

### Migration scope estimate

| Phase | Action | Scope | Files | Estimated commits |
|---|---|---|---|---|
| Phase 1 | Move `count` default property from Sequence.Protocol+Count.swift to a new Collection.Protocol+Count.swift in swift-collection-primitives. Update Sequence.Protocol+Count.swift to retain only `count(where:)`. Update doc comments at both sites. | 2 files in 2 packages | 2 source + 2 docc | 1 |
| Phase 2 | Update Collection.Count.View (the existing fluent `.count.all` / `.count.where` shape in `Collection.Count.swift`) — either delete in favor of the new direct shape (recommended for symmetry with the Sequence-side Option 3 cleanup) or retain. If deleting, migrate the existing fluent tests. | 2–4 files in swift-collection-primitives | 1–2 source + 1–2 test | 1 |
| Phase 3 | Apply the buffer-borrowing recommendation's Phase 1 (drop Sequence.Protocol from affected Buffer types) and Phase 2 (add Collection.Protocol). The new direct count auto-resolves the Buffer test failures because Sequence.Protocol no longer provides a shadowing default. | 5–7 Buffer types + ~3 sibling files per type | per buffer-borrowing brief | per buffer-borrowing brief (probably 2–3) |
| Phase 4 | Workspace-wide cohort migration: remaining ~36 Group A types (Heap, Set.Ordered, Dictionary.Ordered, Queue.*, Stack.*, Bit.Vector views, Vector, Hash.Occupied views, Cyclic.Group, Array.*) add Collection.Protocol conformance. This is the class-(c) ecosystem follow-up cited in `count-direct-vs-fluent` and not strictly part of THIS arc — but the new direct count makes the migration's value proposition stronger. | ~36 types across ~10 packages | per-cohort | separate arc; bundle with the existing class-(c) follow-up |
| Phase 5 | Sequence-primitives test migration: 1–2 tests in `Tests/Sequence Primitives Tests/` lose `seq.count` on Sequence.Protocol-typed fixtures. Replace with `seq.collect().count` (terminal materialization) or `seq.count(where: { _ in true })` (filter-trivially-true). | 1–2 test files | minimal | bundle with Phase 1 |
| Phase 6 | Workspace-wide grep at start AND end per `[HANDOFF-035]`; ecosystem-wide `swift build --build-tests` gate per same; cite zero residuals. | n/a | n/a | n/a (verification step) |

**Total commit estimate**: 4–6 commits across 2–3 packages (swift-sequence-primitives, swift-collection-primitives, swift-buffer-primitives) for Phases 1–3 and 5–6. Phase 4 (Group A cohort migration to Collection.Protocol) is a separate larger arc with its own commit budget (~36 small commits per per-package discipline) that this assessment recommends bundling with the existing class-(c) follow-up rather than executing inline.

### Composes with

- **`HANDOFF-buffer-borrowing-count-sequence-detachment.md`** (sibling, Findings RECOMMENDATION 2026-05-22): both recommendations cohere. The buffer-borrowing brief recommends dropping Sequence.Protocol from Buffer types; this assessment recommends moving count off Sequence.Protocol entirely. Either alone resolves the buffer tests; together they form a stronger structural fix — the buffer-side recommendation removes the local mis-classification, this recommendation removes the source of the mis-classification's defect-generating power.
- **`count-direct-vs-fluent-and-hint-namespace.md` v1.0.0** (2026-05-21 DECISION): the prior DECISION's "stdlib-aligned ergonomics for the common case" rationale is preserved and strengthened by Option (a). The common case (Buffer, Array, Set, Dictionary) is Collection.Protocol-shape; placing count there matches stdlib's placement, not just stdlib's ergonomic. The DECISION's class-(c) coordination note (Collection.Count.View migration) becomes the natural next step rather than a separate deferred item.
- **`collection-sequence-protocol-detachment.md` v1.1.0** (2026-02-23 DECISION): this recommendation is consistent with — and amplifies — the structural split that DECISION established. Collection.Protocol is the multi-pass indexed-access protocol; count belongs there.
- **`sequence-protocol-surface-simplification.md` v1.1.0** (2026-02-23 DECISION): preserved literally — the six Sequence-family protocols stay six (Option a does not add a seventh). Option (b) would have required reopening this DECISION; Option (a) does not.

### Defer condition (if applicable)

Not deferred. The empirical and structural evidence is in hand; the workspace state is clean; the migration scope is bounded; the prior DECISION's rationale is preserved. The principal's go-ahead authorizes Phase 1 dispatch.

If the principal prefers to defer the relocation (e.g., to align with a broader Collection.Protocol-conformance cohort migration), the local buffer-borrowing recommendation (drop Sequence.Protocol from Buffer types) resolves the bug at the conformer level and this recommendation can land on a later schedule. The two are independent dispositively; together they are stronger.

## References

- `swift-institute/Research/collection-sequence-protocol-detachment.md` v1.1.0 (DECISION, 2026-02-23) — structural separation of Collection from Sequence at the protocol-hierarchy level
- `swift-institute/Research/2026-05-18-consuming-get-protocol-extension-noncopyable-limitation.md` — language-limitation context for `consuming get` on protocol-extension property accessors with ~Copyable types
- `swift-sequence-primitives/Research/count-direct-vs-fluent-and-hint-namespace.md` v1.0.0 (DECISION, 2026-05-21, commit `ac09a43`) — prior DECISION placing direct `count: Cardinal` on Sequence.Protocol; recommended Option 3 of three; the placement decision this assessment re-litigates
- `swift-sequence-primitives/Research/sequence-protocol-surface-simplification.md` v1.1.0 (DECISION, 2026-02-23) — Sequence-family six-protocol verdict; this recommendation does not violate
- `swift-buffer-primitives/HANDOFF-buffer-borrowing-count-sequence-detachment.md` Findings (RECOMMENDATION, 2026-05-22) — sibling investigation that surfaced the shadowing defect and recommended local fix (drop Sequence.Protocol from Buffer types); the structural defect this assessment recommends fixing at its source
- `swift-collection-primitives/Sources/Collection Protocol Primitives/Collection.Protocol.swift:39–44` — verified standalone (Step A of detachment DECISION complete in-tree)
- `swift-collection-primitives/Sources/Collection Count Primitives/Collection.Count.swift` — existing Collection.Count.View<Base> fluent shape, class-(c)-queued migration
- `swift-sequence-primitives/Sources/Sequence Protocol Primitives/Sequence.Protocol+Count.swift:21` — the relocation site (verified at write time)
- `swift-sequence-primitives/Sources/Sequence Protocol Primitives/Sequence.Protocol.swift` — Sequence.Protocol declaration (no count requirement)
- `swift-sequence-primitives/Sources/Sequence Hint Primitives/Sequence.Hint+Property.Inout.swift:29` — `seq.hint.count: Cardinal { .zero }` (institute's underestimatedCount analogue; unrelated to this relocation)
- Apple Swift stdlib: [Sequence/underestimatedCount](https://developer.apple.com/documentation/swift/sequence/underestimatedcount) and [Collection/count](https://developer.apple.com/documentation/swift/collection/count) — placement precedent
