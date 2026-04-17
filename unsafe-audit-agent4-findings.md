<!--
version: 1.0.0
last_updated: 2026-04-15
status: PHASE_1_CLASSIFICATION
agent: 4
scope: swift-primitives/{swift-hash-table-primitives, swift-identity-primitives, swift-index-primitives, swift-cardinal-primitives, swift-ordinal-primitives} Sources/
-->

# Agent 4 Findings — Hash / Identity / Index / Cardinal / Ordinal

## Summary

Sources/-only grep for `@unchecked Sendable` across Agent 4 scope:

| Package | Sources/ hits |
|---------|:-------------:|
| swift-hash-table-primitives | 3 |
| swift-identity-primitives | 0 |
| swift-index-primitives | 0 |
| swift-cardinal-primitives | 0 |
| swift-ordinal-primitives | 0 |
| **Total** | **3** |

Four of the five packages (identity, index, cardinal, ordinal) are **clean** — zero `@unchecked Sendable` hits. These packages implement typed wrappers around raw integers (`Cardinal`, `Ordinal`, `Index<T>`) and identity scaffolding (`Tagged<Tag, RawValue>`). Despite being the prototypical sites for phantom-type Sendable inference gaps, they resolve cleanly without `@unchecked`. The structural-Sendable workaround only surfaces at *consumers* of these types that combine phantom parameters with value-generics or heap storage.

All 3 hits live in swift-hash-table-primitives. Category distribution:

| Category | Count | Notes |
|----------|:-----:|-------|
| A (synchronized) | 0 | — |
| B (ownership transfer) | 0 | — |
| C (thread-confined) | 0 | — |
| D (structural workaround) | 2 candidates | Flagged to adjudication queue |
| LOW_CONFIDENCE | 1 | `Hash.Occupied.View` — pointer-lifetime invariant, doesn't fit A/B/C/D cleanly |

The two D candidates (`Hash.Table` and `Hash.Table.Static<N>`) are both `~Copyable` AND have phantom/value-generic parameters. Per task instructions, both-conditions-true → flag as D for principal adjudication. The principal must decide whether the phantom-type gap or the `~Copyable` ownership is load-bearing on each site.

**Note on scope**: The task description anticipated a D-heavy skew, and the finding matches: 2 of 3 hits are D candidates, 1 is a LOW_CONFIDENCE edge case. Zero A/B/C sites.

---

## Classifications

### swift-hash-table-primitives

#### 1. `Hash.Occupied.View` — Hash.Occupied.View.swift:17

**Declaration site**: `@unsafe public struct View: Copyable, @unchecked Sendable`

**Classification**: **LOW_CONFIDENCE** (edge case — neither A/B/C/D fits cleanly)

**Stored fields**:
- `let _hashes: UnsafePointer<Int>`
- `let _positions: UnsafePointer<Int>`
- `let _capacity: Hash.Table<Source>.Bucket.Index.Count`
- `package let _count: Index<Source>.Count`

**Why not A**: No runtime synchronization (no mutex, atomic, lock). This is a pointer-holding view, not a synchronized container.

**Why not B**: Struct is explicitly `Copyable` (declared `Copyable, @unchecked Sendable`). No `~Copyable` ownership semantics. The pointers are shared-borrow, not owned.

**Why not C**: Not thread-confined. The whole point of the View+Iterator API is to iterate from any context that holds the pointers live. No "single-thread access" contract in the docstring.

**Why not clean D**: Category D's test is "no caller-visible invariant". This site has a *clear* caller invariant: the pointers must outlive the view and the underlying Hash.Table must not be mutated during iteration. That's exactly why the outer struct is also `@unsafe`. The `@unchecked Sendable` here is not "compiler can't prove structural Sendable through phantom types" — it's "raw pointer can only be sent if the caller upholds lifetime + non-mutation invariants."

**Why LOW_CONFIDENCE**: The pattern is closer to Category A in spirit (caller must uphold an invariant), but the invariant is lifetime/aliasing, not synchronization. The pilot's template speaks in terms of "synchronized" (A) or "~Copyable single-owner" (B). Neither matches. The principal may choose to:
- (a) Extend Category A to cover "invariant-bearing" including pointer lifetime (apply `@unsafe @unchecked Sendable` + docstring stating the pointer-lifetime invariant), OR
- (b) Classify as a new subcategory (raw-pointer view), OR
- (c) Note that the outer `@unsafe` marker already signals the invariant to callers, so the Sendable conformance can stay bare.

Given that the outer struct carries `@unsafe` already, option (a) is the most coherent — add `@unsafe` on the Sendable conformance and write a Safety Invariant docstring describing pointer lifetime. But this is a judgment call beyond my classification mandate.

**Recommended escalation**: Raise to principal alongside Tier 2 "debatable" sites list in the findings doc.

---

#### 2. `Hash.Table.Static<let bucketCapacity: Int>` — Hash.Table.Static.swift:164

**Declaration site**: `extension Hash.Table.Static: @unchecked Sendable where Element: Sendable {}`

**Classification**: **D candidate** (flagged to queue)

See "Category D Adjudication Queue Entries" section below for details.

---

#### 3. `Hash.Table<Element: ~Copyable>` — Hash.Table.swift:141

**Declaration site**: `extension Hash.Table: @unchecked Sendable where Element: Sendable {}`

**Classification**: **D candidate** (flagged to queue)

See "Category D Adjudication Queue Entries" section below for details.

---

## Appendix — Packages with Zero Hits

The following four packages have **zero** `@unchecked Sendable` occurrences in Sources/:

- `swift-identity-primitives`
- `swift-index-primitives`
- `swift-cardinal-primitives`
- `swift-ordinal-primitives`

These packages house the phantom-type primitives (`Tagged`, `Index<T>`, `Cardinal`, `Ordinal`, `Offset`, `Count`) themselves. The fact that they are *clean* is an important data point: the compiler successfully infers `Sendable` on the base primitives. The structural-inference gap only surfaces at *composition* sites (containers using phantom parameters + value-generics + heap storage), which is exactly where D candidates land (Hash.Table family here, and similar in Agent 2/3 scopes per the research doc).

This supports the broader finding that Category D is a **composition-layer** phenomenon, not a base-type phenomenon.

---

## Low-Confidence Flags

1. **`Hash.Occupied.View` (Hash.Occupied.View.swift:17)** — Category ambiguous (raw-pointer view with lifetime invariant). See classification above. Recommendation: principal decides whether to extend Category A to cover pointer-lifetime invariants, treat as a separate Tier 2 site, or leave the Sendable conformance bare since the outer `@unsafe` already signals the danger.

---

## Preexisting Warnings Noted

No `swift build` was run during classification (per memory `feedback_ask_before_build_test.md`). This section left empty pending Phase 2 application.

---

## Category D Adjudication Queue Entries

These entries are also written to `unsafe-audit-category-d-queue.md` under the "Agent 4" section. Reproduced here for findings-file completeness.

### D-candidate: `Hash.Table<Element: ~Copyable>` — swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.swift:141

**Why D, not B**:

The `@unchecked` conformance is constrained `where Element: Sendable`. If the `@unchecked` genuinely encoded `~Copyable` move semantics for the heap buffer, the constraint would not need to mention `Element: Sendable` at all — `Element` is a **phantom parameter** (never stored, used only for type-level position safety and Hash.Protocol resolution at call sites). The fact that the conformance is gated on `Element: Sendable` strongly suggests the `@unchecked` is a structural workaround for the phantom-type inference gap: the compiler cannot propagate `Sendable` through the phantom `Element` parameter, so the author explicitly gated it.

If the `@unchecked` were purely about `~Copyable` ownership of the heap buffer, a correct annotation would be an unconstrained `extension Hash.Table: @unchecked Sendable {}` with no `where Element: Sendable`. The constraint on `Element` betrays the phantom-type concern.

**However**: `Hash.Table` *is* genuinely `~Copyable` and stores a heap-allocated `Buffer<Int>.Slots<Int>`. So single-owner move semantics are real — just not the reason for the `@unchecked`. Principal must decide whether the classification follows the *reason for `@unchecked`* (D) or the *type's ownership model* (B). Per task instructions, this dual-condition case is flagged to queue.

**Stored fields**:
- `_count: Index<Element>.Count` — pure value (Cardinal-backed typed count)
- `_occupied: Index<Bucket>.Count` — pure value (Cardinal-backed typed count)
- `_buffer: Buffer<Int>.Slots<Int>` — heap-allocated, `~Copyable`, itself has `@unchecked Sendable where Element: Sendable` (Agent 2 scope)

**Generic parameters involved**:
- `Element: ~Copyable` — **phantom type-generic** (never appears in stored fields; used only for phantom position typing via `Index<Element>` and resolving `Hash.Protocol` at call sites)

**Current annotation site**: Extension, not declaration: `extension Hash.Table: @unchecked Sendable where Element: Sendable {}`

**Is it also `~Copyable`?**: **Yes.** Declared `public struct Table<Element: ~Copyable>: ~Copyable`. It owns a heap-allocated `Buffer.Slots` via unique ownership. However, the **reason** for `@unchecked Sendable` appears to be the phantom-type gap (evidenced by the `where Element: Sendable` constraint — an irrelevant constraint if ownership-transfer were the concern), not ownership transfer per se. Principal to adjudicate: does the phantom-type-gap motivation outweigh the `~Copyable` ownership reality for classification purposes?

---

### D-candidate: `Hash.Table.Static<let bucketCapacity: Int>` — swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.Static.swift:164

**Why D, not B**:

This is the **canonical Category D example** per `unsafe-audit-findings.md` §"Known sites". Two compounding structural gaps:

1. **Value-generic `<let bucketCapacity: Int>`**: Swift's structural Sendable inference does not propagate through integer-valued generic parameters. Even though the stored `InlineArray<bucketCapacity, Int>` is provably a pure value type of Sendable bytes, the compiler cannot prove it.
2. **Phantom `Element: ~Copyable` parameter (inherited from extension scope)**: The outer extension is `extension Hash.Table where Element: ~Copyable`, making `Element` the phantom parameter for `Hash.Table.Static`. Never stored; used only for phantom position typing.

The conformance is `where Element: Sendable` — again betraying the phantom-type concern (if pure `~Copyable` ownership were the reason, the `Element: Sendable` gate would be incoherent).

**Stored fields**:
- `_hashes: InlineArray<bucketCapacity, Int>` — pure inline value bytes (no heap)
- `_positions: InlineArray<bucketCapacity, Int>` — pure inline value bytes (no heap)
- `_count: Index<Element>.Count` — pure value (Cardinal-backed typed count)
- `_occupied: Bucket.Index.Count` — pure value (Cardinal-backed typed count)

All four are **pure value types with no heap allocation**. There is no owned resource for single-owner semantics to protect.

**Generic parameters involved**:
- `Element: ~Copyable` — **phantom type-generic** (inherited from extension scope; never stored; used only for `Hash.Table<Element>.empty` / `.deleted` / `.normalize` forwarding and phantom position typing)
- `bucketCapacity: Int` — **value-generic** (drives `InlineArray` dimension)

**Current annotation site**: Extension, not declaration: `extension Hash.Table.Static: @unchecked Sendable where Element: Sendable {}`

**Is it also `~Copyable`?**: **Yes, but incidentally.** Declared `public struct Static<let bucketCapacity: Int>: ~Copyable` inside `extension Hash.Table where Element: ~Copyable`. The `~Copyable` trait is **inherited from the parent-type layering convention** (Hash.Table is ~Copyable because `Element` may be ~Copyable), NOT because the type owns a heap resource. All storage is inline `InlineArray` and typed counts — no allocation, no deinit, no single-owner semantic necessity. Unlike `Hash.Table` (which owns `Buffer.Slots`), `Hash.Table.Static` has nothing to single-own. This is the cleanest D candidate in my scope: the `~Copyable` is a type-system artifact of the extension scope, not a semantic ownership claim. Principal to confirm.
