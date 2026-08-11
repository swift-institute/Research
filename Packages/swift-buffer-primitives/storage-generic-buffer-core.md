# Buffer/Storage Deduplication via Capability Protocols

> **Working document — single source of truth for the buffer/storage deduplication arc during the `Buffer.Linear` spike** (principal direction 2026-05-25). Consolidates the 2026-05-23 Claude×ChatGPT converged plan + transcript (ephemeral `/tmp/buffer-storage-generic-{converged,transcript}.md`, absorbed) and the 2026-05-25 in-session `Buffer.Protocol` capability findings. Originally titled "Storage-Generic Buffer Core" (v1.0.0); the original Question/Analysis/Outcome follow the Latest Findings block below as the detailed substrate. Update this doc as the spike progresses — see § Consolidation Log.

<!--
---
version: 1.1.0
last_updated: 2026-05-25
status: WORKING DOCUMENT (spike in progress)
tier: 2
type: investigation/architecture
---
-->

## Context

The linear buffer algorithm in `swift-buffer-linear-primitives` is duplicated across a 2×2 matrix of files — `Buffer.Linear+Heap Copyable`, `+Heap ~Copyable`, `+Inline Copyable`, `+Inline ~Copyable` — because each leaf type (`Buffer.Linear`, `.Inline<capacity>`, `.Small<n>`, `.Bounded`) **hardcodes its storage** as a concrete field (`Storage<Element>.Heap` / `Storage<Element>.Inline<capacity>`).

A capability protocol that would let the algorithm be written once already exists in `swift-storage-primitives` — `Storage.Protocol` (hoisted as `__StorageProtocol`): `~Copyable`, `associatedtype Element: ~Copyable`, `var capacity`, `@unsafe func pointer(at:)` — but `swift-buffer-linear-primitives` does not consume it.

**Verified empirical state (2026-05-24):**
- Concrete `Storage.Heap` references in `swift-buffer-linear-primitives/Sources`: **35 files**. `[Verified: 2026-05-24]`
- Concrete `Storage.Inline` references: **11 files**. `[Verified: 2026-05-24]`
- `Storage.Protocol` (generic) references: **0**. `[Verified: 2026-05-24]`
- Initialization tracking is split between the buffer `Header` and `storage.initialization` (Heap = range-tracked; Inline = per-slot bit-vector). `[Verified: 2026-05-24]`

**Trigger**: [RES-001] / [RES-011] — a Claude×ChatGPT design discussion converged on hoisting the shared algorithm to be generic over storage; the design question then needed systematic resolution and empirical validation before any production refactor. Two specialization experiments were run (see References); this document is the durable record of the decision they validated.

**Prior research consulted** (per [RES-019]):

| Document | Status | Relevance |
|----------|--------|-----------|
| `storage-pointer-access-level.md` | DECISION | Buffers consume `Storage.Heap.pointer(at:)` raw; higher-level Storage operation-wrappers (Option C) were rejected as over-abstraction. Directly constrains where the shared algorithm lives. |
| `buffer-core-pattern-unification.md` | RECOMMENDATION | Conformance/naming parity across variants; `isSpilled` is an encapsulated implementation detail. Does **not** cover the generic-core hoist — this doc extends it. |
| `theoretical-buffer-primitives-design.md` | RECOMMENDATION | Three-layer architecture (Header / static operations / composed types) — the layer vocabulary this doc builds on. |
| `small-buffer-storage-representation.md` | — | `.Small` SBO is a hybrid representation, not a single storage backing. |
| `swift-institute/Research/canonical-buffer-discipline-cross-language-survey.md` | — | Cross-language buffer-discipline survey. |

---

## Latest Findings (2026-05-25) — Capability-Protocol Deduplication

### Goal — deduplication (the north star)

The buffer and storage packages carry **far too much duplicate code**; removing it is the point of this arc. Two structural duplications drive everything:

1. **Storage-backed algorithm duplication (the 2×2)** — the linear algorithm is copied across `Heap`/`Inline` × `Copyable`/`~Copyable` because each leaf hardcodes its storage. `[Verified 2026-05-24: 35 files ref Storage.Heap, 11 ref Storage.Inline, 0 storage-generic.]`
2. **Per-discipline buffer-logic duplication** — derived/observable buffer logic (`count`, `isEmpty`, `forEach`, front/back, the span surface, Sequence/Collection plumbing) is re-declared on every leaf of every discipline. `[Verified 2026-05-25: count/isEmpty/forEach identical-shaped across the 4 linear leaves.]`

### Two dedup levers — one capability protocol per composition layer

Per `[DS-001]` (Memory → Storage → Buffer → Collection; each layer adds one concern), each layer gets a capability protocol that lets its shared logic be written **once**:

| Lever | Protocol | Collapses | Status |
|---|---|---|---|
| Storage-generic Layer-2 algorithm | `Storage.Protocol` (`__StorageProtocol`) | the 2×2 — algorithm written once over `some Storage.Protocol` | **EXISTS** (`swift-storage-primitives` @ `0aef787`) |
| Buffer-level shared logic | `Buffer.Protocol` (`__BufferProtocol`) | per-discipline logic — derived ops as protocol-extension default impls | **NEW** (this arc) |

Both follow the `Bit.Vector.Protocol` precedent (`nested-protocols-in-generic-types.md`): each variant conforms in ~3-4 lines; higher-level ops are protocol defaults.

### Two-axis ownership → the protocols are orthogonal

Storage owns *physical* truth (occupancy/allocation/topology); the buffer `Header` owns *logical* truth (initialized order/count/extent). A buffer **has-a** storage; it is **not a kind-of** storage. Therefore `Buffer.Protocol` does **NOT** refine `Storage.Protocol` (principal decision 2026-05-25) — refinement would leak physical `pointer(at:)`/`capacity` into the logical layer.

### Buffer.Protocol — concrete design (RECOMMENDATION, validate in spike)

Consumer-facing **capability** protocol (principal decision 2026-05-25: capability, NOT an op-dispatch surface). Hoisted per `[API-IMPL-009]` (`Buffer<Element>` is generic; protocols can't nest in a generic context per `nested-protocols-in-generic-types.md`):

```swift
public protocol __BufferProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    var count: Index<Element>.Count { get }
    var isEmpty: Bool { get }   // default impl: count == .zero  ← the dedup payoff
    func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)
}
extension Buffer where Element: ~Copyable { public typealias `Protocol` = __BufferProtocol }
```

Core = the logical surface universal across disciplines. Derivable observables (`isEmpty`, …) become **single default impls** instead of per-leaf copies — conformance shrinks each leaf to `count`/`forEach`. Deliberately OUT of the core:

- `span`/`mutableSpan` → stays on `Span.Protocol` (converged Decision #4 — not a core bound; contiguous-only).
- positional `subscript(Index)` → linear-family; base vs a `Buffer.Linear.Protocol` refinement = spike output (the per-family-protocol question, deferred per converged Decision #7).
- `capacity` → physical (Storage owns it, `Storage.Protocol.swift:25`); leaf convenience only — settle in spike.
- `Sequence`/`Collection`/by-value subscript/front/back → `Copyable`-gated, isolated per `[MOD-004]`; Copyable variants only.

### Modularization — Buffer.Protocol is its own module

Per `[MOD-031]` (per-sub-namespace decomposition) + `[MOD-017]` (zero-dep root) + the established precedent (`Storage.Protocol` → `Storage Protocol Primitives`; `Sequence.Protocol` → `Sequence Protocol Primitives`):

- `__BufferProtocol` + the `Buffer.`Protocol`` typealias live in a **new `Buffer Protocol Primitives` target** in `swift-buffer-primitives`.
- It is a *sub-namespace* target, NOT the zero-dep `Buffer Primitive` root, because it references `Index<Element>.Count` (external dep `Index_Primitives`) — the same `[MOD-017]` content-policy reason `Sequence.Protocol` lives outside `Sequence Primitive`.
- Each discipline package (`swift-buffer-linear-primitives`, …) conforms its leaves by depending on the `Buffer Protocol Primitives` product — symmetric to the storage disciplines conforming to `Storage.Protocol`.

### SIL boundary — what dedups safely vs what stays concrete

Dedup must not cost specialization. Two experiments `[CONFIRMED 2026-05-24]`:

- `storage-protocol-specialization` — a generic algorithm over `some Storage.Protocol` specializes cross-module to **0 `witness_method`** on `pointer(at:)`. → derived ops as protocol defaults / generic-over-`some Buffer.Protocol` code is expected to specialize (confirm in Phase 3).
- `property-inout-specialization` — concrete-Base `Property.Inout` accessors flatten to 0-witness **unconditionally**; **protocol-Base accessors do NOT** (need `@inlinable`, which lands on the documented `~Copyable` Property.Inout borrow-init miscompile). → the **hot mutating ops (append/remove) stay concrete-Base**; only *derived* logic moves to protocol defaults.

The internal-touching ops are co-located with storage as `@usableFromInline internal` per the **refined-C refactor** (`[MOD-036]`/`[MOD-037]`; `HANDOFF-buffer-type-ops-inlinable-refactor.md`). That refactor and this protocol arc both descend from this doc, share the buffer discipline packages, and a **single-writer** claim — coordinate, do not collide.

### Decision #7 reconciliation — dedup IS the concrete need

The converged plan's Decision #7 defers new capability protocols "until a concrete storage forces one / unless a concrete need surfaces." **The deduplication is that concrete need** — it has surfaced (the duplication above is the motivation). So introducing `Storage.Protocol` (done) and `Buffer.Protocol` (this arc) is justified now; the spike validates the dedup lands without losing specialization. Introduction is gated on the spike *validating*, not on the need *surfacing*.

### Buffer.Protocol spike additions (overlay on the Implementation Path / Phase 0–4 below)

- **P1+** — add the `Buffer Protocol Primitives` target; declare `__BufferProtocol` + typealias; conform `Buffer.Linear`; move `isEmpty` (+ any derivable observable) to a protocol default impl.
- **P2+** — conform `.Inline`/`.Small`/`.Bounded`; delete the now-duplicated per-leaf derived-observable declarations.
- **P3+** — SIL recheck ALSO on generic-over-`some Buffer.Protocol` call sites (0 `witness_method`); confirm hot mutating ops still flatten via concrete-Base.

### UPDATE 2026-05-25 (late) — Lever-1 UNBLOCKED; storage foundation COMPLETE

> Supersedes the `BLOCKED` / ask-stop status in the § Spike progress block below. Both cross-package blockers are dead.

**Storage value-type migration complete (waves 1–8, all FF-merged to `main`, unpushed).** Every single-region storage leaf conforms to `Storage.Protocol` under the natural `capacity: Index<Element>.Count` — the `slotCapacity`/`capacity` collision is gone (the leaves now PROVIDE `capacity`; the protocol-rename option was NOT taken), with REAL-conformer SIL zero-witness proven (closes the [EXP-020] synthetic-conformer gap). `Storage.Heap`/`.Slab`/`.Arena`/`.Pool` are conditionally-`Copyable` value-type façades over a private backing class with internal CoW; `.Inline`/`.Pool.Inline`/`.Arena.Inline` are `~Copyable`-only inline structs. → blocker-1 (zero conformers) and blocker-2 (Heap can't conform) are both resolved.

**Path = (B) two-axis-pure — supersedes the "lift `Storage.Move`/`.Initialize`/`.Deinitialize` onto the protocol" unblock step.** P0 already established the buffer `Header` owns the logical truth (count/order; it derives `initialization`). Take that literally: the generic linear algorithm does element lifecycle via `storage.pointer(at:)` + `UnsafeMutablePointer` ops and tracks liveness in the `Header` — it does NOT call `storage.initialize`/`.move`/`.deinitialize`, and the **generic core never touches `storage.initialization`**. But `storage.initialization` is NOT abandoned — the earlier "storage STOPS maintaining it / Header = sole truth" framing is unsafe and is corrected here (R1, `HANDOFF-buffer-heap-leaf-teardown.md`): the **concrete per-leaf heap shell** keeps it synced with the `Header` (`storage.initialization = header.initialization` after each count-changing op), because the `Storage.Heap` backing-class `deinit` — and `ensureUnique()`'s deep-copy — read it as the *sole* record of the live extent. The buffer `Header` is silently discarded when the buffer drops (no destructor runs on it), so it cannot drive element teardown; at the drop instant `storage.initialization` is the only readable truth. "Header = sole truth" holds for *live logical queries*, not at *teardown*. That sync is a concrete `Storage.Heap` call, never a `Storage.Protocol` requirement. Consequence: **today's `Storage.Protocol` (`capacity` + `pointer(at:)`) is sufficient for the generic core — NO protocol extension, no lifecycle-ops lift.** The storage-side `+Initialize/+Move/+Deinitialize` accessors on Heap/Inline become buffer-unused (a cleanup decision: remove, or relegate to standalone-storage use).

**Remaining work = the buffer consumer migration, which IS Lever-1.** Rewriting `Buffer.Linear` onto the value-type Heap (ownership annotations + the generic `some Storage.Protocol` algorithm, dropping `Buffer.Linear`'s own `isKnownUniquelyReferenced` — CoW now lives in the storage) simultaneously (a) repairs main's RED buffer layer (the value-type storage broke the by-value consumers — verified on buffer-linear: `parameter of noncopyable type 'Storage<Element>.Heap' must specify ownership`) and (b) lands the dedup. Then repoint Inline/Small/Bounded + delete the four `+{Heap,Inline}×{Copyable,~Copyable}` files; SIL re-gate the real heap leaf for lever-1 `pointer(at:)` (0 `witness_method`); roll to Ring/Gap/Slab.

### Spike progress (P0–P1, heap leaf) — 2026-05-25

Exploratory spike on branch `spike/buffer-storage-dedup` in `swift-buffer-linear-primitives` + `swift-buffer-primitives` (NOT pushed; may be discarded). Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108). Baseline verified green (build+test) on both in-scope packages before branching.

**What was done**

- **P0 (two-axis tracking) — confirmed already in place; no moves needed.** `Buffer.Linear.Header` (`Buffer.Linear.Header.swift`) already owns the LOGICAL truth: `count: Index<Element>.Count` + `capacity: Index<Element>.Count`, with `isEmpty`/`isFull` derived and `var initialization: Storage<Element>.Initialization { .init(self) }` deriving the contiguous `.one(0..<count)` range. PHYSICAL occupancy stays in `Storage<Element>.Heap` (`storage.initialization`, kept in sync by the mutating ops). Phase-0's precondition ("move logical tracking into the Header") was satisfied by `Buffer.Linear.Header` (commit `1008e1f`) — the spike confirmed it and moved nothing.

- **P1b (Lever 2 — `Buffer.Protocol` capability) — DONE + SIL-validated.** Added a new `Buffer Protocol Primitives` sub-namespace target in `swift-buffer-primitives` (per `[MOD-031]`/`[MOD-017]`: it references `Index<Element>.Count`, so it lives outside the zero-dep `Buffer Primitive` root — mirrors `Storage Protocol Primitives`; re-exported from the umbrella). Declared the hoisted `__BufferProtocol` per `[API-IMPL-009]` exactly as specced: `associatedtype Element: ~Copyable`, `var count: Index<Element>.Count { get }`, `var isEmpty: Bool { get }` **as a protocol-extension default impl (`count == .zero`)**, `func forEach<E: Swift.Error>(_:) throws(E)`, plus `extension Buffer where Element: ~Copyable { public typealias \`Protocol\` = __BufferProtocol }`. It does NOT refine `Storage.Protocol` (two-axis orthogonality). Conformed the heap leaf in one line — `extension Buffer.Linear: Buffer.\`Protocol\` where Element: ~Copyable {}` — `count`/`forEach` are satisfied by the leaf's existing witnesses and `isEmpty` comes from the default impl (the dedup payoff: zero per-leaf `isEmpty` needed for conformance). Debug build+test green on the branch.

- **P1a (Lever 1 — storage-generic algorithm) — BLOCKED, ask-stop (ground rule 6); NOT done.** See blocker below. No storage-generic algorithm was written/wired, because it cannot be exercised on the production heap shape without a cross-package `swift-storage-primitives` change.

**Where the (lever-2) capability protocol lives + why** — chose **a new dedicated sub-namespace target `Buffer Protocol Primitives`** over folding into an existing target. Reason: it is the exact structural twin of `Storage Protocol Primitives` (hoisted `__StorageProtocol` + namespace typealias), references `Index_Primitives` so it is barred from the zero-dep `Buffer Primitive` root by `[MOD-017]`'s content policy, and a dedicated target lets each discipline package conform its leaves by depending on just that product — symmetric to how the storage disciplines are meant to consume `Storage.Protocol`. (The lever-1 "where does the algorithm live" decision — `Storage.Protocol` extension methods vs free generic function — was NOT reached: the algorithm was never written, see blocker.)

**SIL verdict (lever 2) — PASS, with counts.** Release + cross-module per `[EXP-017]`: `swift package clean`; `swift build -c release`; cross-module `swiftc -emit-sil -O` of the spike-only `Buffer Protocol SIL Probe` executable (imports `Buffer_Linear_Primitive` from another module; calls `func bufferProtocolSum<B: Buffer.\`Protocol\` & ~Copyable>(_:) where B.Element == Int`, touching `count` + `isEmpty` + `forEach`). Receipt: `swift-buffer-linear-primitives/Outputs/sil-release.txt`.
- Runtime (release, cross-module): `sum: 10240000` — correct.
- **`witness_method` on the `some Buffer.Protocol` generic call: 0** on the load-bearing path — the SPECIALIZED `bufferProtocolSum<Buffer.Linear<Int>>` that `main` actually calls (signature `(Builtin.Int64, @guaranteed Storage<Int>.Heap) -> Int`) flattens the entire protocol surface to `index_addr -> load -> sadd_with_overflow_Int64`.
- The dump contains **6 `witness_method` total, ALL inside the unused generic-fallback body** (`sil hidden [noinline] bufferProtocolSum<B>`), which `main` never references — the same residue documented in `Experiments/storage-protocol-specialization`.
- **`witness_method` on lever-1 `pointer(at:)`: N/A — not validated (lever 1 blocked).**

**Blocker (lever 1) — cross-package `swift-storage-primitives` change required → STOP per ground rule 6.** Two independent findings:
1. `Storage.Protocol` is declared but **has zero conformers anywhere in the ecosystem** (only the storage umbrella re-exports it; no discipline conforms; `Storage Heap Primitives` does not even depend on `Storage Protocol Primitives`).
2. The production `Storage.Heap` **cannot conform to `Storage.Protocol` as currently declared.** The protocol requires `var capacity: Index<Element>.Count { get }`; `Storage.Heap` is a `ManagedBuffer` subclass that inherits `final public var capacity: Int` and exposes the typed value as `slotCapacity`. A `capacity: Index<Element>.Count` witness collides with the inherited `Int` member — `property 'capacity' with type 'Index<Element>.Count' cannot override a property with type 'Int'` (Swift rejects class-member type-override; reproduced minimally in `/tmp`). This holds whether the conformance is declared in-package or retroactively from the buffer package — it is a class-member-shape problem, not a visibility one.

Reconciling either point requires editing `swift-storage-primitives` (e.g., rename `Storage.Protocol`'s requirement to `slotCapacity`, or otherwise resolve the `capacity` shape), which is out of scope. Additionally, the *mutating* linear algorithm (`append`/`remove`/`replace`/`truncate`/`swap` in `Buffer.Linear+Storage.Heap ~Copyable.swift`) uses `storage.initialize`/`.move`/`.deinitialize`/`.initialization` — none of which are on `Storage.Protocol`; generalizing it would need `Storage.Move`/`.Initialize`/`.Deinitialize` lifted onto `Storage.Protocol`, the spec's explicitly-named ask-stop condition. Lever 1 therefore cannot be validated on the heap leaf without a `swift-storage-primitives` change; surfaced for the principal's decision rather than powered through.

**Deviations from the brief**
- Lever 1 (P1a) intentionally NOT attempted beyond the blocker analysis — ask-stop honored (no unwired scaffolding written, to keep the lever-2 commits clean).
- The SIL probe is a spike-only `.executableTarget` (`Buffer Protocol SIL Probe`, no published `.library` product) used solely to force the cross-module generic call into emitted SIL; remove on rollout or discard with the branch.
- `Outputs/sil-release.txt` was `git add -f`'d past this repo's deny-by-default `.gitignore` (root `/*`) so the receipt travels with the spike branch for review, per `[EXP-003c]` (multi-page SIL ⇒ commit).

**Remaining P2–P3 (next dispatch — gated on principal review of this verdict + the lever-1 blocker decision)**
- **Lever-1 unblock decision (principal):** authorize a `swift-storage-primitives` change to make `Storage.Heap` (and siblings) conform to `Storage.Protocol` — at minimum reconcile the `capacity`/`slotCapacity` requirement; for the mutating algorithm, lift `Storage.Move`/`.Initialize`/`.Deinitialize` onto `Storage.Protocol`. Then write the linear algorithm once over `some Storage.Protocol`, wire `Buffer.Linear` (heap) via concrete-Base `Property.Inout` accessors, and run the lever-1 `pointer(at:)` SIL check.
- **P2:** conform `.Inline`/`.Small`/`.Bounded` to `Buffer.Protocol`; delete the now-duplicated per-leaf `isEmpty` (and any other derivable-observable) declarations. Note `.Inline`/`.Small` are unconditionally `~Copyable`; `count`/`forEach`/`isEmpty` are `~Copyable`-clean so conformance is expected to be the same one-liner.
- **P3:** re-point Inline/Small/Bounded to the storage-generic algorithm and delete the four `+Heap`/`+Inline × Copyable/~Copyable` op files as subsumed; in-package SIL recheck on the real leaves (lever-1 `pointer(at:)` AND lever-2 `some Buffer.Protocol`); confirm hot mutating ops still flatten via concrete-Base. Then roll to Ring/Gap/Slab.

---

## Question

Where should storage-genericity be introduced in the buffer layer — at the leaf type or at the algorithm — and how should buffer operations be surfaced, such that (a) the 2×2 duplication collapses, (b) `.Small` SBO remains expressible, and (c) the hot-path `pointer(at:)` keeps static dispatch (no witness-table dispatch)?

---

## Analysis

### Methodology

Options were enumerated against four criteria: **duplication eliminated**, **`.Small` expressible**, **specialization preserved** (no `witness_method` on `pointer(at:)`, verified via SIL in release + cross-module), and **clear of documented `~Copyable` compiler sharp edges**.

### Option A — Leaf-generic `Buffer.Linear<Storage>`

Make the user-facing type generic over storage: `struct Linear<S: Storage.Protocol>`.

- **Pros**: one type, maximal apparent reuse.
- **Cons**: `.Small` (SBO) cannot be expressed — its inline-then-spill representation switch lives *in the buffer*, not in any single storage backing, so the "orthogonal Buffer × Storage matrix" has a permanent hole. Cross-language precedent agrees: C++ `absl::InlinedVector`, Rust `smallvec`/`arrayvec` are *distinct types*, never `Vec` parameterized over a storage policy. The capability surface also exceeds `pointer(at:)` (initialization-tracking differs per backend). **Rejected.**

### Option B — Layer-2 hoist: generic algorithm, concrete leaves *(recommended)*

Keep the leaf types concrete (each owns a concrete `Storage<Element>.X`); write the linear algorithm **once**, generic over `some Storage.Protocol`, at the static-operations layer. Leaves delegate to it.

- **Pros**: collapses the 2×2 to a single generic algorithm (× the unavoidable `Copyable`/`~Copyable` split); `.Small` stays a concrete leaf; specialization is preserved (see Evidence); composes with the existing `storage-pointer-access-level.md` decision (algorithm uses `pointer(at:)` directly). Mirrors Rust's `RawVec` (allocation/capacity) vs `Vec` (logical `len`) split, generalized.
- **Cons**: a thin per-leaf accessor remains (see operation-surface sub-question).

### Option C — `ADT<Shape>` witness composition

`typealias Array = ADT<Buffer.Linear, Storage.Contiguous.Heap>`, with behavior on `extension ADT where …`.

- **Cons**: a single accreting `ADT<…>` struct fights `[API-IMPL-005]` (one type per file) and `[API-NAME-001]`, obstructs specialization, and buys nothing over concrete composition (`Set.Ordered`/`Tensor` already own a concrete buffer field). **Rejected.**

### Sub-question — operation surface and reuse locus

The operation *surface* must follow the ecosystem's property-primitives pattern (`buffer.<namespace>.<verb>()` via `Property.Inout`), **not** a static `Buffer.Linear.Operations` enum. Within that, two reuse loci are possible:

- **Concrete-Base accessors**: operations on `extension Property.Inout where Base == <concrete leaf>`, forwarding to the shared generic-over-storage algorithm. Per-leaf accessor, but thin.
- **Protocol-Base accessors**: operations on `extension Property.Inout where Base: <LinearBufferProtocol>`, written once across all leaves.

### Comparison

| Criterion | A: leaf-generic | B: Layer-2 hoist | C: ADT\<Shape\> |
|-----------|:---:|:---:|:---:|
| 2×2 duplication eliminated | ✓ | ✓ | ✓ |
| `.Small` SBO expressible | ✗ | ✓ | ✓ |
| Specialization preserved | unverified | ✓ (verified) | ✗ |
| Clear of `~Copyable` sharp edges | — | ✓ | — |
| Convention fit (`[API-IMPL-005]`/`[API-NAME-*]`) | ✓ | ✓ | ✗ |

| Reuse locus | Specializes cross-package *without* `@inlinable`? | Lands on documented miscompile path? |
|-------------|:---:|:---:|
| Concrete-Base | **Yes, unconditionally** | No |
| Protocol-Base | **No** — needs `@inlinable` | **Yes** (`@inlinable` on the `~Copyable` `Property.Inout` borrow-init is documented miscompile-prone) |

### Evidence (specialization experiments)

Two experiments validated the load-bearing claim that the generic-over-`Storage.Protocol` algorithm specializes to **zero witness-table dispatch** on `pointer(at:)`, in release, across a module boundary, with `~Copyable` storage and a suppressed associated `Element`:

1. `swift-institute/Experiments/storage-protocol-specialization` — static-enum shape. SIL: `0 witness_method`; the generic core inlined to raw `index_addr` pointer arithmetic both within-module and cross-module. `[Verified: 2026-05-24, CONFIRMED]`
2. `swift-property-primitives/Experiments/property-inout-specialization` — the result transferred through the **real** `Property.Inout` / `Tagged` / `Ownership.Inout` accessor stack. Variant A (concrete-Base) flattened the entire accessor stack to direct pointer arithmetic, `0 witness_method`, unconditionally. Variant B (protocol-Base) kept `2 witness_method` and emitted no specialized `all<LinearBuffer>` — it collapses only with `@inlinable`/same-package CMO. Release runs correct; neither variant tripped swiftlang/swift#81624 nor the documented borrow-init release miscompile. `[Verified: 2026-05-24, CONFIRMED]`

The two-axis ownership split (Storage owns *physical* occupancy/topology; the buffer `Header` owns *logical* initialized order/count) is what makes the algorithm backing-agnostic; it is the resolution of the split-tracking state noted in Context. `Storage.Split` already embodies the split (metadata-driven; consumer owns validity) and is out of scope (multi-region, does not conform to single-region `Storage.Protocol`). `[Verified: 2026-05-24]`

---

## Outcome

**Status**: RECOMMENDATION

**Decision**: Adopt **Option B** — concrete Layer-3 leaves delegating to a single algorithm generic over `some Storage.Protocol`, with the operation surface expressed via **concrete-Base `Property.Inout` accessors** (not a `Buffer.Linear.Operations` enum, not protocol-Base accessors). The shared algorithm lives as `Storage.Protocol` extension methods reached through the accessors — consistent with `storage-pointer-access-level.md`'s decision to consume `pointer(at:)` raw rather than wrap operations on Storage.

**Rationale**: Option B is the only option that eliminates the 2×2 duplication while keeping `.Small` expressible and specialization intact. Concrete-Base accessors specialize unconditionally; protocol-Base would require `@inlinable` on the `~Copyable` `Property.Inout` path, which is exactly what `Property.Inout.swift` documents as release-miscompile-prone — so the marginal reuse it buys is not worth the correctness risk. Per [RES-022], structural correctness (unconditional specialization, no miscompile exposure) dominates the smaller-diff appeal of protocol-Base.

### Implementation path (phased, test-gated)

Branch first; `swift-buffer-linear-primitives` (+ `swift-storage-primitives`), never `main`.

| Phase | Action | Gate |
|-------|--------|------|
| 0 | Resolve init-tracking ownership: move *logical* tracking (count, initialized range) into `Buffer.Linear.Header`; leave *physical* occupancy in `Storage`. | Precondition for everything else. |
| 1 | Write the linear algorithm once as `Storage.Protocol` extension methods over `some Storage.Protocol`; wire `Buffer.Linear` (heap) via concrete-Base `Property.Inout` accessors. First check whether `Storage.Move`/`.Initialize`/`.Deinitialize` already generalize over `Storage.Protocol` or need lifting. | Builds; existing tests pass. |
| 2 | Re-point `.Inline`/`.Small`/`.Bounded`; delete the four `+Heap`/`+Inline × Copyable/~Copyable` op files as subsumed. | Tests pass; `.Small` spill logic stays in the leaf. |
| 3 | **In-package SIL recheck** on the real leaves: confirm `0 witness_method` on `pointer(at:)`; full test suite + benchmarks. | If green, validated on production shape. |
| 4 | Roll the pattern to Ring/Gap/Slab, each with its own discipline accessors over the shared slot-primitives. | Only after Phase 3. |

Decoupled (separate breaking-rename arc): `Buffer.Linear` → `Buffer.Linear.Heap` explicitization, parallel to `Storage.Heap`/`.Inline`.

### Residual (per [RES-027])

- **Premise — "the production refactor specializes"**: backed by the two extant capability experiments above; the Phase-3 in-package SIL recheck is the confirming step on the real types. Not a free-floating loose end.
- **Direction — shared-core placement as `Storage.Protocol` extension methods vs a free helper**: the experiments used an internal `Operations` enum as scaffolding; the production placement (StorageProtocol extension) is the same concrete-call-on-concrete-storage shape and is expected to specialize identically, confirmed at Phase 1.

## References

- `storage-pointer-access-level.md` — DECISION: `pointer(at:)` promoted to public; Storage operation-wrappers rejected.
- `buffer-core-pattern-unification.md` — variant conformance/naming parity (this doc extends it to the generic-core hoist).
- `theoretical-buffer-primitives-design.md` — three-layer architecture.
- `swift-institute/Research/canonical-buffer-discipline-cross-language-survey.md`, `comparative-buffer-primitives.md`, `copyable-wrapper-vs-multi-buffer-storage.md`.
- Experiments: `swift-institute/Experiments/storage-protocol-specialization`; `swift-property-primitives/Experiments/property-inout-specialization`.
- Prior art (cross-language): Rust `RawVec`/`Vec` (allocation vs logical length), `smallvec`/`arrayvec` (SBO as distinct types); C++ `std::vector<T, Allocator>` (allocator parameterizes residency, not the algorithm), `absl::InlinedVector`.
- `Storage.Protocol.swift` (`__StorageProtocol`); `Property.Inout.swift` (the `~Copyable` accessor pattern + documented borrow-init miscompile / swiftlang/swift#81624).

---

## Consolidation Log (2026-05-25)

This document is the **single working source of truth** for the buffer/storage deduplication arc (principal direction 2026-05-25). Disposition of related material:

- **Absorbed** (ephemeral; content folded into § Latest Findings): `/tmp/buffer-storage-generic-converged.md` (2026-05-23 Claude×ChatGPT converged plan), `/tmp/buffer-storage-generic-transcript.md`.
- **Supersession candidates — predecessor design-thread docs, PENDING REVIEW before banner-stamping** (fold + supersede each only after confirming its content is subsumed): `buffer-core-pattern-unification.md` (RECOMMENDATION — this doc "extends" it), `theoretical-buffer-primitives-design.md` (DEFERRED — three-layer vocabulary), `swift-storage-primitives/Research/split-storage-design.md` (RECOMMENDATION — storage-side).
- **Cited foundations — RETAINED, not superseded**: `storage-pointer-access-level.md` (DECISION), `swift-institute/Research/nested-protocols-in-generic-types.md` (DECISION), `swift-storage-primitives/Research/storage-contiguous-protocol-conformance.md` (DECISION), Experiments `storage-protocol-specialization` + `property-inout-specialization`, the comparative/survey docs.
