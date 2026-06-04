# The `Storage.Small` Substrate + the No-Typealias End-State — the tower's terminal shape

<!--
---
version: 1.0.1
last_updated: 2026-06-05
status: DECISION (self-ratified — Cleave-3, principal-authorized addendum 2026-06-05; the Phase-D
        seat-ratification gate was removed; receipt-backed per [SUPER-009a]).
        v1.0.1: mitigation REVISED Route 2 → ~Copyable-only on E1 in-package seam-integration evidence
        (see "REVISION v1.0.1" — the conditional-Copyable unlock is deferred, not regressed).
tier: 3
scope: ecosystem-wide (the MSB capability tower)
normative: true
applies_to:
  - swift-storage-primitives (the Storage.Small substrate + the Storage.Inline-leaf composition + the Heap-alias retirement)
  - swift-memory-primitives (Memory.Inline tracked-leaf story; Memory.Heap is the spill arm — reused, not new)
  - the ~29 Storage<E>.Heap-alias consumer packages (verbose-spelling respell, E2)
  - the 12+ hand-rolled .Small/.Inline variant packages (absorption/reshape, E3)
depends_on:
  - swift-institute/Research/storage-memory-split.md (the #3 packet — the substrate this builds on; Memory.Heap, Storage.Contiguous, Store.Tracked.Protocol, the Heap bridge alias)
  - swift-institute/Research/cross-layer-capability-protocol-model.md (CLCPM §3.3 0-witness HARD gate; §12 span; the Tracked tier)
  - swift-institute/Research/memory-byte-bit-domain-orthogonality.md (the Memory strategy family; the location/layout axis)
  - swift-primitives/swift-buffer-primitives/Research/buffer-core-pattern-unification.md (INV-INLINE-004a + the named unlock)
  - swift-primitives/swift-storage-primitives/Research/storage-inline-invariants.md (the INV-INLINE family)
  - .handoffs/HANDOFF-msb-tower-followups.md §A (#4/#5/#5a/#6); .handoffs/HANDOFF-tower-endstate.md (the dispatch + ADDENDUM)
receipts: ~/Developer/.probe-bank/cleave-3/ (G1-wall-reprobe/, Small-mitigations/, enumerations/, baseline-verification.txt)
---
-->

> **Cleave-3 Phase-D packet.** Reaches the tower's END-STATE: (#5) one generic hybrid substrate
> `Storage<E>.Small<let n>` — a REAL struct, inline ≤ n ⊕ heap-after — absorbing the 12+ hand-rolled
> `.Small`/`.Inline` variants; (#5a(i)) the no-typealias verbose truth spellings everywhere — every
> consumer spells `Storage<E>.Contiguous<Memory.Heap<E>>`-class forms; the `Storage<E>.Heap` alias is
> the in-cascade bridge ONLY and retires at the end (E4). Builds directly on the #3 packet (landed).
> **Self-ratified per the principal-authorized ADDENDUM (2026-06-05): no seat round-trip D→E.**

## REVISION v1.0.1 (E1 in-package integration, 2026-06-05) — mitigation Route 2 → ~Copyable-only

**The §2.2 wall-mitigation DECISION is REVISED on in-package evidence: from Route 2 (Optional-slot
`InlineArray`, conditionally Copyable) to the ~Copyable-only path (the packet's documented fallback).**
Transparency note: this revises the packet's headline ("conditional Copyability achievable today"). It is
NOT a STOP-class (the wall does not survive — the ~Copyable-only mitigation works; not a new wall; no naming).
It is an evidence-driven, packet-decided mitigation choice within the bounded mitigation space.

**Why (decisive, E1 build evidence — receipts below):** Route 2's `/tmp` probes validated the wall-mitigation,
teardown, and 0-witness against a *simplified value-return seam*. The REAL `Store.Protocol` seam is built on
typed `Index<Element>` + **raw-pointer + `Offset` arithmetic** (`$0 + Index<Element>.Offset(fromZero: slot)`;
`_modify` yields a STABLE element pointer — sound only because the backing is class/`@_rawLayout`). The
Optional-slot `InlineArray` arm fights this on three confirmed counts: (a) a `~Copyable` `subscript` MUST be
`_read`/`_modify` (compiler: "noncopyable subscript cannot provide a read and set accessor" — the `_read`+`set`
sidestep is illegal); (b) `_modify` cannot project a stable mutable element pointer through a value-inline arm
inside an enum (the documented limitation, Storage.Inline+Storage.Protocol.swift:110); (c) there is **no
`Index<Element>`→`Int` conversion** in the ecosystem (the seam never Int-indexes — it is pointer-based), and
**zero precedent** for `InlineArray`-as-mutable-element-storage. Forcing Route 2 would require novel,
unsafe-heavy, grain-fighting plumbing in load-bearing infrastructure — failing the timeless-infrastructure bar.

**The revised shape (proven, seam-fitting):**
```swift
public struct Small<let inlineCapacity: Int>: ~Copyable {           // ~Copyable (INV-INLINE-004a retained)
    @frozen enum _Representation: ~Copyable {
        case inline(Storage<Element>.Inline<inlineCapacity>)        // the proven @_rawLayout+bitmap arm
        case heap(Memory.Heap<Element>)                             // the tower's #3 leaf (spill arm)
    }
    var _storage: _Representation
}
```
Both arms are seam-proven (Storage.Inline ships; Memory.Heap is the #3 leaf, P1-proven); the seam witnesses
delegate to the active arm; the spill (`reserveCapacity`/`create`/`_spillToHeap`) relocates the proven
`Buffer.Linear.Small` machinery down to the storage tier. This is the per-container generalization of the
existing `_Representation` shape into ONE substrate.

**Impact = NO regression, deferral only.** The 12+ absorbed variants are ALL `~Copyable` today (INV-INLINE-004a);
a `~Copyable`-only unified `Storage.Small` matches their current capability EXACTLY — the #5 unification goal is
fully achieved. The conditional-`Copyable` UNLOCK (Route 2) becomes a documented FUTURE enhancement, tied to the
`INV-INLINE-004a` lift (follow-up #27 / `InlineArray.init(unsafeUninitializedCapacity:)` arrival + a typed-seam
value-`_modify` story). Route 2's banked receipts (`Small-mitigations/`) stand as that future arc's evidence.
G1 is unaffected (§0 — wall HOLDS, recorded). §2.2 below records the original Route-2 analysis for the record.

## 0. The G1 outcome — RECORDED (the MUST-record gate)

**The `bd04f32` wall STILL HOLDS** — `deinitializer cannot be declared in generic struct that conforms
to 'Copyable'` — verified identical on **6.3.2, 6.4-dev (2026-03-16), and 6.5-dev (2026-05-27)**. A
conditionally-Copyable generic struct cannot carry a user `deinit`; an unconditionally `~Copyable` one
can. Receipt: `~/Developer/.probe-bank/cleave-3/G1-wall-reprobe/RECEIPT.txt` (Shape A rejected on all
three; Shape B compiles on all three; live `swift --version` confirmed per
`feedback_snapshot_labels_must_match_empirical_version` — the 2026-05-27 "swift-latest" is 6.5-dev).

**Consequence (NO silent scope expansion):** the wall did NOT fall → the leaf-class cleanup oracle
stays → **Pool/Arena/Slab dissolution does NOT unlock** → this packet proceeds on the un-reshaped
design. No new scope is taken.

## 1. Context

The #3 packet (`storage-memory-split.md`, DECISION, landed) un-fused `Storage<E>.Heap` into
`Storage<E>.Contiguous<Memory.Heap<E>>` over the class-backed `Memory.Heap` leaf, inserted
`Store.Tracked.Protocol` (the initialization ledger as a protocol requirement), and left
`Storage<E>.Heap` as a **bridge typealias** explicitly marked "the correct intermediate, NOT the
end-state." This packet lands the end-state: the second creatable substrate (#5) and the verbose
spelling flip + alias retirement (#5a(i)).

**The binding constraints (both from prior art, both verified):**
- **The `bd04f32` wall** (§0): no discipline-side / generic-composer `deinit` under conditional Copyability.
- **`INV-INLINE-004a`** (`storage-inline-invariants.md`; `buffer-core-pattern-unification.md:194`):
  `Storage.Inline` is `@_rawLayout` ⇒ unconditionally `~Copyable`; therefore every container embedding it
  (the 12+ `.Small`/`.Inline` variants) **comments out** its own `Copyable where Element: Copyable`
  conformance. The named unlock was `InlineArray.init(unsafeUninitializedCapacity:)`.

## 2. The Small substrate — design (the wall-mitigation DECISION)

### 2.1 The proven prior-art shape (the spine — not reinvented)

Every hand-rolled `.Small`/`.Inline` is the same shape, and it is proven + shipping:

```swift
@frozen enum _Representation: ~Copyable {        // (Buffer.Ring.Small._Representation)
    case inline(<inline storage>)                 // payload = STORAGE ONLY
    case heap(<heap storage>)
}
```

The enum (not a two-field struct) is **release-correctness-load-bearing**: mixing `@_rawLayout`
(`Storage.Inline`) + a class ref (`Memory.Heap`) in one struct trips an LLVM release verifier crash
("Instruction does not dominate all uses!"); the enum destroys exactly one arm at a time.
`Storage<E>.Small<n>` is the **per-container generalization** of this shape into ONE substrate — it does
not reinvent it.

### 2.2 The wall-mitigation candidates (probed; each with a 0-witness receipt where claimed)

The dispatch named three mitigations for Small's CoW-inline arm. Probing them — anchored in the prior
art — surfaced a clean fork on a single axis: **does Small keep the `@_rawLayout`+bitmap inline arm
(unconditionally `~Copyable`) or adopt a compiler-managed inline arm (conditionally Copyable)?**

| Route | Inline arm | Copyable | All elements | Toolchain | Verdict |
|---|---|---|---|---|---|
| **Status quo (~Copyable-only)** | `Storage.Inline` (`@_rawLayout`+bitmap, user `deinit`) | NO (INV-INLINE-004a) | yes | ships today | proven; the conservative fallback |
| Route 1 (prior-art-named) | bitmap + `InlineArray.init(unsafeUninitializedCapacity:)` | YES | yes | **init ABSENT on 6.5-dev** | **blocked** (stdlib API not arrived) |
| **Route 2 (chosen)** | `InlineArray<n, Element?>` (Optional slots, compiler-managed teardown, **no user `deinit`**) | **YES** | yes | **works on production 6.3.2** | **adopted** |
| Box pattern | inline behind a class | YES | yes | — | rejected: an allocation defeats "inline" |

**DECISION: Route 2.** `Storage<E>.Small<let n>` is a REAL `~Copyable` struct:

```swift
struct Small<Element: ~Copyable, let n: Int>: ~Copyable {
    enum Backing: ~Copyable {
        case inline(InlineArray<n, Element?>)   // payload = the variable-size store ONLY
        case heap(Memory.Heap<Element>)          // the #3 leaf — REUSED as the spill arm
    }
    var backing: Backing
    var count: Int                               // fixed field — SEPARATE from the variable-size payload
}
extension Small.Backing: Copyable where Element: Copyable {}
extension Small: Copyable where Element: Copyable {}   // ← lifts INV-INLINE-004a
```

No user `deinit` anywhere ⇒ the `bd04f32` wall is **sidestepped** (teardown is compiler-synthesized
aggregate destruction: the inline `InlineArray<n, Element?>` destroys its live `.some` slots; the heap
arm is `Memory.Heap`, whose backing class owns its `deinit`). The Optional discriminant (`nil` =
uninitialized) IS the per-slot initialization ledger.

**Why Route 2 over the status quo (full justification — this is the packet-decided wall mitigation):**
1. **It restores a capability the whole family wanted.** All 12+ variants comment out `Copyable where
   Element: Copyable` under INV-INLINE-004a. Route 2 un-comments it — `Buffer<Storage<Int>.Small<8>>.Linear`
   becomes a Copyable value type when `Int` is.
2. **It is MORE space-efficient for the actual "Small" capacity range.** `Storage.Inline` carries a fixed
   40-byte overhead (256-bit `_slots` bitmap + 8-byte `_deinitWorkaround` for swift#86652). Route 2's
   Optional tags cost ≤ n bytes for non-niche elements and **0** for niche-optimized elements
   (classes/pointers). For n ≤ 32 (the Small range), Route 2 is the smaller representation.
3. **Safer codegen.** No `@_rawLayout` ⇒ no swift#86652 `_deinitWorkaround`, no LLVM field-ordering
   crash class, no unsafe pointer arithmetic — plain Swift the optimizer handles.
4. **Fully receipt-backed** (§5): typechecks (Copyable + `~Copyable`); runtime-correct in debug AND
   release on **production 6.3.2** (and 6.3.1, 6.5-dev) — inline+spill teardown, CoW value-copy
   independence, `~Copyable` teardown, no leak / no double-free; **0-`witness_method`** (CLCPM §3.3) on
   6.3.2 and 6.5-dev.

**The layout discipline is load-bearing (banked the hard way).** The enum payload MUST hold ONLY the
variable-size store — a bare `Int` beside `InlineArray<n,…>` in one payload tripped a 6.3.x
`CopyPropagation` ownership miscompile (`Have operand with incompatible ownership?! load [take] Int →
struct_extract Int._value`). `count` lives as a SEPARATE struct field — exactly the prior-art
`_Representation` shape. With that discipline, release is clean on 6.3.2.

The `~Copyable`-only status quo remains the documented fallback (parity 0-witness; reuse `Storage.Inline`
verbatim) should Route 2 ever regress on a future toolchain.

## 3. The named opens — resolved

1. **Per-access discriminant cost** — RESOLVED (receipt, no benchmark gate per the dispatch). The
   0-witness probe drives a concrete `Small<Int,8>` through the inline arm AND the heap spill via a
   generic seam consumer: `concreteDriver` and the specialized generic both = **0 `witness_method`** at
   `-O` on 6.3.2 and 6.5-dev. The inline/heap discriminant is a plain devirtualized enum switch — no
   witness dispatch. Receipt: `Small-mitigations/route2-0witness/`.
2. **Memory.Inline tracked-leaf story** (it must join `Store.Tracked`) — RESOLVED. Raw `Memory.Inline`
   (`@_rawLayout`, zero-overhead, untracked — [DS-006]) keeps its charter UNCHANGED. The **tracked**
   inline behavior is the Optional-slot representation (`nil`=uninit IS the ledger), which conforms
   `Store.Tracked.Protocol` natively (the `initialization` witness is *derived* from the slots — the same
   "real, derived, linear-discipline" witness `Storage.Inline` vends today). So: tracking lives in the
   Optional-slot store, not in raw `Memory.Inline`; the two coexist (raw for untracked manual-lifecycle
   callers, tracked for dense disciplines).
3. **Promotion placement** (growth is buffer-tier in the model) — RESOLVED. Small's inline→heap **spill**
   is *storage-substrate-internal* — `Storage.Small` owns it, triggered inside its own seam ops when
   `count` exceeds `n`. This is ORTHOGONAL to buffer-tier capacity *growth* (a `Buffer` asking its storage
   for more room). The buffer is oblivious: it drives the `Store` seam; Small spills transparently
   underneath. This is the unification dividend — the spill logic moves DOWN from N buffer-level variants
   into ONE substrate.
4. **The `initialization`-discoverability call** (docs-only vs a marker protocol; never capability-as-Bool)
   — RESOLVED: **no new marker protocol.** The #3 arc already established `Store.Tracked.Protocol` as the
   type-level tracked-vs-inert marker (conformance-as-capability). Small conforms `Store.Tracked.Protocol`
   (it has a real ledger); an inert store does not. The "second creatable tracked substrate" distinction
   the supervisor deferred here is therefore carried by the EXISTING Tracked conformance — docs note it;
   no `static var tracksInitializationRanges: Bool` (the rejected capability-as-Bool). Clean, zero new surface.

## 4. Dispositions (decide-and-justify; naming = ask-class, flagged to the seat)

- **#4 — the Storage fold** (`Storage<M>` = the flat storage itself): **DEFER.** The fold was CONDITIONAL
  on #3 shrinking the family; ①-rev KEEPS `Storage.{Arena,Pool,Slab}` (the namespace stays loaded — they
  are structurally irreducible while the wall holds, §0). With the family not shrinking and no dissolution
  unlock, the fold buys nothing now. Revisit only if the wall falls (#27(a) on a future toolchain).
- **#6 — buffer-arena collapse relationship**: **stays QUEUED, independent.** Cleave-3 absorbs the
  `Buffer.Arena.Inline`/`.Small` *inline variants* into `Storage.Small` (E3). That is disjoint from #6's
  structural job (delete `swift-buffer-arena-primitives`, fold Header/Position) — which is itself gated on
  [ARCH-LAYER-009] (no package `rm` pre-1.0; #6 is a reshape-or-defer, not this arc). Cleave-3 touches the
  arena inline variants via reshape; #6 owns the package-level collapse later. Coordinate at the E3 window.
- **#5a(ii) — vocabulary** (slab/Bonwick tension; arena-doubled-name): **NAMING = ask-class → seat.**
  Recommendation: **keep current names + document the divergence**, the lowest-risk option, and NOT
  blocking the substrate work. The Bonwick "slab" (fixed-size object cache ≈ `Memory.Pool`) vs `Buffer.Slab`
  (bitmap sparse occupancy) tension and the `Buffer<Storage<E>.Arena>.Arena` doubled name are truth-
  intermediate; a rename is a separate vocabulary pass. **Surfaced, not decided silently.**

## 5. Probe receipts (CLCPM §3.3 protocol; all banked to `~/Developer/.probe-bank/cleave-3/`)

| Probe | Verdict | Receipt |
|---|---|---|
| G1 wall re-probe (#27(a)) | Wall HOLDS on 6.3.2 / 6.4-dev / 6.5-dev | `G1-wall-reprobe/RECEIPT.txt` |
| Route 1 (`init(unsafeUninitializedCapacity:)`) | ABSENT on 6.3.2 AND 6.5-dev | `Small-mitigations/INV-INLINE-004a-routes.txt` |
| Route 2 runtime (15 checks) | ALL PASS — debug+release on 6.3.1/6.3.2/6.5-dev (teardown, spill, CoW independence, ~Copyable teardown, no leak/double-free) | `Small-mitigations/route2-runtime/RECEIPT.txt` |
| Route 2 0-witness (§3.3 HARD) | concreteDriver=0, specialized generic=0 on 6.3.2 AND 6.5-dev (4 residuals in retained templates — §3.3-blessed) | `Small-mitigations/route2-0witness/RECEIPT.txt` |

## 6. Enumerations (re-run at write-time per [HANDOFF-021]/[HANDOFF-040]; banked to `enumerations/`)

- **A — `Storage<E>.Heap`-alias consumers (the E2 respell scope + the E4 gate-grep target):**
  **272 Sources files across 29 packages** (28 swift-primitives + 1 swift-foundations/swift-async;
  0 swift-standards); **165 same-type pins** (`S == Storage<E>.Heap`). Packet-era ~230/~25/209 — RE-RUN
  values supersede. Lists: `enumerations/A-heap-alias-{files,packages}.txt`, `A-heap-same-type-pins.txt`.
- **B — the hand-rolled `.Small`/`.Inline` element-storage variants (the E3 absorption set):** the named 12
  (array, heap, deque, dictionary-ordered, list-linked, queue-linked, buffer-{linear,ring,slab,linked,arena}
  incl. Buffer.Arena.Inline) **plus DELTAS** the "12" framing undercounts — set-ordered, stack, queue,
  tree-n, Heap.MinMax. ALL are `~Copyable` with **commented-out** `Copyable` conformances (INV-INLINE-004a).
  EXCLUDED (different domain, not absorbed): Binary.Parse.Inline, Bit.Vector*.Inline, Bitset.Small (word
  stores). Substrate-machinery (NOT consumer variants): Storage.Inline, Memory.Inline, Storage.{Arena,Pool}.Inline.
- **C — docs/docc/prose forms of `Storage.Heap`:** **62 files** (.docc catalogs, READMEs, Research). Updated
  in E2 where normative; non-normative prose may retain the alias name with a note. List: `enumerations/C-heap-docs-forms.txt`.

## 7. Retirement mechanism (E3/E4) — confirmed against [ARCH-LAYER-009] (Phase-D requirement)

[ARCH-LAYER-009]: pre-1.0, NO `Sources/<X>/` or package removal; **permissible = rename / reshape public
API / reorganize files within a module.** Therefore:
- **E3 (12+ variant absorption):** each variant is **RESHAPED** — its `_Representation` inline arm becomes
  `Storage<E>.Small`'s arm, or the variant collapses to a composition (`Buffer<Storage<E>.Small<n>>.Linear`).
  The Sources modules **STAY** (no `rm`). Consumers migrate spellings. Mechanism = reshape / API-collapse.
- **E4 (Heap-alias retirement):** remove the `typealias Heap = Storage<Element>.Contiguous<Memory.Heap<Element>>`
  **declaration** (an API reshape). The `Storage Heap Primitives` MODULE STAYS (its `@_exported public import
  Memory_Heap_Primitives` + pinned ergonomics surface remain). Gate: alias-references = 0 ecosystem-wide first.
- Both land under ONE enumerated seat-verified window + one batched principal YES (the lone irreversible
  boundary). NO per-variant stream. NO `rm`.

## 8. Phase E plan (E1/E2 autonomous per the ADDENDUM; E3/E4 at the seat window; mains-direct)

- **E1 (additive; suites green):** land `Storage<E>.Small<let n>` (Route 2, §2.2) as a new target in
  swift-storage-primitives, conforming `Store.Protocol` + `Store.Tracked.Protocol` + `Storage.Protocol`
  (marker) + `Span.Protocol` (conditional); heap arm = `Memory.Heap` (reused). Land the Storage.Inline-leaf
  composition (P2 shape) per the goal. Tests: ported coverage + a composed-CoW divergence suite. Two-tier
  bar (warm mid-wave, cold at close). Additive ⇒ nothing else changes.
- **E2 (verbose-spelling respell):** respell the 272 alias-consumer files (29 packages) from `Storage<E>.Heap`
  to `Storage<E>.Contiguous<Memory.Heap<E>>` (and the 165 same-type pins), per-package, dependency order,
  two-tier bar, green at every wave boundary. The bridge alias keeps each wave green until E4.
- **E3 → E4 → E5** at the seat re-engagement: absorb/reshape the 12+ variants (per-action-YES batch) →
  retire the Heap alias (gate-grep=0 first) → termination sweep ([HANDOFF-035] width) → [SUPER-011].

## 9. Self-ratification

Per the principal-authorized ADDENDUM (2026-06-05), the Phase-D seat gate is removed. Self-review bar met:
probes run incl. the #27(a) G1 re-probe (§0, wall HOLDS — recorded); the four named opens resolved (§3);
dispositions argued (§4; naming flagged ask-class); enumerations re-run (§6); 0-witness receipts where the
design claims them (§5). The retirement mechanism is confirmed non-destructive (§7). **Phase D is
successful — proceeding autonomously to E1 + E2.** No silent scope expansion (the wall held).

## References
- #3 packet: `swift-institute/Research/storage-memory-split.md`
- CLCPM §3.3/§12: `swift-institute/Research/cross-layer-capability-protocol-model.md`
- INV-INLINE-004a + unlock: `swift-primitives/swift-buffer-primitives/Research/buffer-core-pattern-unification.md:194`; `swift-primitives/swift-storage-primitives/Research/storage-inline-invariants.md`
- Prior-art shape: `swift-primitives/swift-buffer-ring-primitives/Sources/Buffer Ring Small Primitive/Buffer.Ring.Small.swift`
- Receipts: `~/Developer/.probe-bank/cleave-3/`
- Dispatch + ADDENDUM: `.handoffs/HANDOFF-tower-endstate.md`; queue: `.handoffs/HANDOFF-msb-tower-followups.md` §A
