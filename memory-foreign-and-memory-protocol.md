# Memory.Foreign and Memory.Protocol

<!--
---
version: 1.0.0
last_updated: 2026-06-12
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

**Trigger.** The 2026-06-12 comparison of `apple/swift-network-evolution` against the institute IO stack surfaced a missing memory regime. The institute can represent memory it allocates and frees (`Memory.Heap`, `Memory.Inline`) and memory it borrows non-owningly (`Swift.Span` — `~Escapable`, cannot outlive the lending scope). It has no representation for the third regime: memory the process did **not** allocate but must **own past the lending scope**, released by invoking a provider-supplied callback (or dropping a retained owner) — never by `deallocate`. Apple's Network.framework extraction shows this regime is load-bearing in a production datapath: its packet currency `Frame: ~Copyable` backs onto a closed `Buffer` enum whose `.customOwner(buffer:owner:)` and `.customFinalizer(buffer:finalizer:)` cases carry exactly this ownership shape (`apple/swift-network-evolution/Sources/SwiftNetwork/Protocols/Frame.swift:30-35`, trapping `deinit` at `:120-124`, `@_lifetime(borrow self)` span accessor at `:134-149`) [Verified: 2026-06-12, direct read].

Apple welded the ownership polymorphism into one enum at the packet layer. The hypothesis under investigation: it belongs at the memory-substrate tier, where the whole MSB tower (Memory → Storage → Buffer → ADT, program complete through W5 on 2026-06-11) composes over it.

**Tier classification.** Tier 2 per [RES-020]: cross-package (memory family, storage, buffer, future networking), but reversible — the outcome is a RECOMMENDATION with package creation explicitly gated, and the protocol verdict is scoped to additive-only roles, so no hard-to-undo semantic commitment ships with this document.

**[RES-018] classification.** `Memory.Foreign` is case (b) — domain-owned vocabulary at L1. The memory family is a per-regime taxonomy (`swift-memory-{heap,inline,map,shared,small,…}-primitives`, one regime per package); Foreign fills the structurally-valid, currently-empty lattice cell *provenance = external, release = provider callback* ([RES-020a] merit framing). The composition check (why no existing primitive covers it) is in the Analysis. No consumer count is cited as justification.

**Constraints.** [PRIM-FOUND-001] no Foundation; [API-ERR-001] typed throws; [API-NAME-001] Nest.Name; [API-IMPL-005] one type per file; `.strictMemorySafety()` ecosystem-wide. The MSB tower's publication gate is active: "Nothing is pushed anywhere (publication is a separate, later decision)" with "publication gate · repo creation" listed as a push-time item (`.handoffs/OVERVIEW-tower.md:26,57`; "the tower publication gate" also at `.handoffs/HANDOFF-tower-SEAT.md:74`) [Verified: 2026-06-12].

**Supersedes/corrects.** This document supersedes the in-conversation 2026-06-12 brief it was dispatched from, and corrects three of that brief's premises against current source (§ Corrections below).

## Question

1. **Q1 — Shape and placement**: what is the right type shape for `Memory.Foreign` (owner vs finalizer, mutability, copyability), and where does it live?
2. **Q2 — Family boundaries**: how does Foreign relate to `Memory.Map` and `Memory.Shared`, precisely?
3. **Q3 — Does a `Memory.Protocol` emerge?** With Heap, Inline, Map, Shared, and Foreign, is a unifying memory-tier protocol warranted, and what may it be under the additive-only doctrine?
4. **Q4 — Timing**: build `swift-memory-foreign-primitives` now, or gate on the first consumer?

## Current State (verified against source, 2026-06-12)

### The memory-tier seam already exists: `Memory.Region`

`Memory.Region` is a protocol nested in the `Memory` namespace — "The raw byte resource seam: a located run of raw bytes (`base` + `capacity` only)" — with a load-bearing non-collapse invariant: "A `Memory.Region` exposes `base` + `capacity` **only**. It MUST NOT expose an element type, slot identity, initialization state, collection count, storage layout, or any allocator discipline" (`swift-memory-primitives/Sources/Memory Region Primitives/Memory.Region.swift:15-40`) [Verified: 2026-06-12]. Requirements: `var base: Memory.Address { get }` (stable for the region's lifetime) and `var capacity: Memory.Address.Count { get }`. Conformers today: `Memory.Heap` (`swift-memory-heap-primitives/Sources/Memory Heap Primitives/Memory.Heap ~Copyable.swift:34`), `Memory.Inline` (`swift-memory-inline-primitives/Sources/Memory Inline Primitives/Memory.Inline+Memory.Region.swift:18`), and `Memory.Allocator.System` passthrough (`swift-memory-allocation-primitives/Sources/Memory Allocator Primitive/Memory.Allocator.System.swift:20`). Bound: `Memory.Allocator<Resource: ~Copyable & Memory.Region>` (`Memory.Allocator.swift:32`) [Verified: 2026-06-12].

### What `Storage.Contiguous` actually requires of its memory parameter

The current shape is `Storage<Allocation: ~Copyable>.Contiguous<Element: ~Copyable>` — the namespace parameter is the element-free **allocation**, and `Element` enters at the Contiguous product:

- **Designated init**: requires nothing of `Allocation` beyond `~Copyable` ownership — it takes the allocation plus an already-resolved typed `base` pointer and capacity (`swift-storage-primitives/Sources/Storage Contiguous Primitives/Storage.Contiguous.swift:71-82`).
- **Convenience init**: `extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable` — "Adopts a `Memory.Region` allocation as `capacity` typed slots, resolving its base once" (`Storage.Contiguous.swift:100-111`).
- **Crucially, the seam is construction-time-only**: "The typed base is **cached** (reference SHAPE) — read once under a `Memory.Region` (or pool) constraint at construction — so the deinit oracle needs no capability bound on the carrier" (`Storage.Contiguous.swift:21-27`). There is **zero protocol dispatch at runtime** through `Memory.Region`; the witness is consulted exactly once, at init.
- **Drop cascade**: the deinit oracle destroys exactly the ledger-tracked live slots, "THEN the `allocation` field is destroyed, freeing the raw bytes" (`Storage.Contiguous.swift:84-94`). Release semantics are entirely the allocation type's own `deinit` — the storage tier never names them.
- **Conformances**: `Storage.Contiguous: Store.Protocol` is **unconditional** over `Allocation: ~Copyable` (`Storage.Contiguous+Store.Protocol.swift:57`); Sendable is conditional: `@unchecked Sendable where Allocation: ~Copyable & Sendable, Element: ~Copyable & Sendable` (`Storage.Contiguous.swift:192`) [all Verified: 2026-06-12].

So the answer to the brief's critical sub-question Q3(a) is: **the existing constraint is `Memory.Region`** (for the convenience path; nothing at all for the designated path), and a new regime slots into the storage tier by conforming to it.

### The protocol landscape at the memory/store tiers

| Protocol | Cut | Conformers today | Notes |
|---|---|---|---|
| `Memory.Region` | located raw bytes (`base`+`capacity`), construction-time seam | `Memory.Heap`, `Memory.Inline`, `Memory.Allocator.System` | the memory-tier protocol [Verified above] |
| `Span.Protocol` (span-primitives) | OWNED typed span-vending capability | `Memory.Contiguous` et al. | the former "owned Memory contiguous protocol", deliberately relocated OUT of the Memory namespace — "the institute-neutral lift … so byte/binary/memory each conform without a cross-domain edge" (`Memory.Contiguous+Span.Protocol.swift:12-26`) [Verified: 2026-06-12] |
| `Store.Protocol` | 4+1-op typed element seam (`capacity`, subscript, `initialize`, `move`, `prepareForMutation`) | `Storage.Contiguous`, `Store.Inline`, `Memory.Small` | "a **deletable convenience code-share vehicle**, not a foundational layer … never refined into storage identity" (`swift-store-primitives/Sources/Store Protocol Primitives/Store.Protocol.swift:118-135`) [Verified: 2026-06-12] |
| `Store.Ledgered.Protocol` | `Store.Protocol` + settable `initialization` ledger | `Storage.Contiguous`, `Store.Inline` | ratified 2026-06-10 (ASK-A) precisely so "a composing discipline whose occupancy is not prefix-shaped" — "the ring now; **future wrapped/sparse disciplines**" — can sync the ledger generically (`Store.Ledgered.swift:21-55`) [Verified: 2026-06-12] |
| `Memory.Tracked.Protocol` / `Memory.Allocatable.Protocol` | typed self-cleaning leaf; + allocate/bulk-relocate | `Memory.Small` only | the narrow D1-B/D2 replacements for the eliminated universal capabilities (2026-06-05). Doc comments still name `Memory.Heap`/`Memory.Inline` as conformers — stale since Heap/Inline went element-free; only `Memory.Small` conforms (`swift-memory-small-primitives/Sources/.../Memory.Small+Store.Protocol.swift:102`, `+Memory.Allocatable.swift:59`) [Verified: 2026-06-12, grep across swift-primitives] |
| `Memory.Unique.Protocol` | CoW uniqueness (`isUnique`/`ensureUnique`) | sharing leaves only | not relevant to Foreign (single-owner) |

### The Buffer tier today: substrate-parametric namespace, heap-pinned operations

`Buffer<S: ~Copyable>` is the substrate-parametric namespace per W3 ⑤-(N) (`swift-buffer-primitives/Sources/Buffer Primitive/Buffer.swift:17-25`). But in the discipline packages, **every public operation entry point is same-type-pinned to the heap column**. For the ring [all Verified: 2026-06-12]:

- The only **public initializer** of `Buffer.Ring.Bounded` is `where S == Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>` (`swift-buffer-ring-primitives/Sources/Buffer Ring Bounded Primitive/Buffer.Ring.Bounded+Operations.swift:13`); the substrate-generic init is `package`-scoped (`Buffer.Ring.Bounded.swift:26`).
- The push/pop **view ops** are declared on `Property.Inout.Typed` extensions pinned to the heap column (`Buffer.Ring.Bounded.Push.swift:11-15`), with an explicit wall note: "the `.push`/`.pop`/`.remove` Property-view ops stay heap-pinned — generalizing a Property.Inout.Typed extension over an arbitrary storage S hits the value-generic same-type wall. #12a" (`Buffer Ring Primitive/Buffer.Ring+Operations.swift:153-155`).
- The **static ops** (layer 2) carry the same pin in their `where` clauses — while their own header states the bodies are substrate-generic in substance: "The element-moving operations (push/pop front/back, deinitialize-all) use ONLY the inherited element-store surface (`initialize(at:to:)` / `move(at:)`) plus the lifted `storage.initialization` sync (ASK-1 (b′), 2026-06-04). They are therefore generic over any `S: Store.`Protocol``" (`Buffer.Ring+Memory.Heap ~Copyable.swift:6-13`).
- Growth/compaction ops (`_grow`, `_growTo`, `compact`) genuinely require `S.create(minimumCapacity:)` and are rightly heap-pinned (`Buffer.Ring+Operations.swift:67-114`).

Consequence, independent of Foreign: **the pins fence out every non-heap region, including the already-shipping `Memory.Inline`**. No `Memory.Inline`-backed or pool/arena-region-backed column can reach the ring's public ops today either. This is a pre-existing tower-generality gap that Foreign merely makes visible; it is a tower-program item, not a Foreign-arc item (see Q4).

### Corrections to the dispatching brief

1. The brief's canonical spelling `Storage<Int>.Contiguous<Memory.Heap<Int>>` (taken from the doc comment at `Buffer.swift:23`) is stale. The current shape is `Storage<Allocation>.Contiguous<Element>`; the dense column is `Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Element>`, and `Memory.Heap` is element-free (`Memory.Heap.swift:16-40`) [Verified: 2026-06-12]. The `Buffer.swift:23` doc comment lags W4/W5 and should be fixed when the tower program next touches that file.
2. "The root package already declares … a `Memory.Contiguous.Protocol`" — partially stale. The owned-contiguous capability was lifted out of the Memory namespace into the namespace-neutral `Span.Protocol` (`Memory.Contiguous+Span.Protocol.swift:12-26`); the `Memory.swift:21` overview line still advertising ``Memory/Contiguous/Protocol`` is doc lag.
3. The brief's worry about "Copyability/@_rawLayout interactions" (INV-INLINE-004a) does not apply to Foreign: `@_rawLayout` constrains the **Inline/Small** storage variants (`Buffer.swift:27-36`); Foreign is a pointer-adopting regime like Heap and never touches raw layout.

## Empirical Probe (the load-bearing instantiation claim)

Experiment: `swift-buffer-ring-primitives/Experiments/foreign-region-tower-instantiation/` (committed `7dad2c9`), Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0, run 2026-06-12. Hypothesis tested: the brief's payoff thesis — "if Memory.Foreign satisfies whatever Storage.Contiguous requires of its memory parameter, then `Buffer<…>.Ring` (etc.) exists with zero changes to tiers 2–4."

**Verdict: PARTIAL — CONFIRMED at the Storage tier, REFUTED at the Buffer tier.**

| Variant | Result | Evidence |
|---|---|---|
| V1: `Foreign: ~Copyable` struct (adopted `UnsafeMutableRawBufferPointer` + escaping finalizer, `deinit { finalizer(buffer) }`) conforms `Memory.Region` | CONFIRMED | two computed properties (`base`, `capacity`); nothing in the seam asks who allocated or how to free |
| V2: `Storage<Foreign>.Contiguous<UInt8>` via the EXISTING `Memory.Region` convenience init; 4-op seam read/write/move; drop cascade | CONFIRMED | runs oracle-then-finalizer; finalizer invocations == 1 (exactly-once); **zero tier-2 changes** |
| V3: one generic function `where S: Store.Ledgered.Protocol, S.Element == UInt8` drives a wrapped-ring exercise (initialize/move + arbitrary-slot ledger overwrite) over BOTH the heap column and the foreign column | CONFIRMED | identical output `[10,11,12,13,14,15]` from both substrates — the ring discipline's storage-interaction surface is substrate-generic in substance |
| V4: negative probes (`-D` gated) against the buffer tier's public surface | REFUTED (as predicted by source) | `create`: "requires the types 'Foreign' and 'Memory.Allocator<Memory.Heap>.System' be equivalent"; `Bounded(minimumCapacity:)` and `push.back`: "cannot convert parent type 'Storage<Foreign>' to expected type 'Storage<Memory.Allocator<Memory.Heap>.System>'" |

The probe retires the brief's design risk in both directions: the storage tier needs **nothing** (Foreign conforms to `Memory.Region` and everything composes, including the Sendable clause and the deinit cascade), and the buffer tier needs a **bounded, mechanical** change (where-clause generalization of non-allocating ops from `S == Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>` to the already-ratified `Store.Ledgered` seam or to `Storage<A>.Contiguous<E> where A: Memory.Region`), which V3 demonstrates is sound for the op bodies as written.

## Prior Art

### Internal ([RES-019] step-0 — searched before the external survey)

No document in `swift-institute/Research/` or the tower packages' `Research/` corpora covers foreign/adopted/finalizer-released memory; the grep sweep (foreign, finalizer, deallocator, external storage, provenance) returns only incidental matches. The nearest positions:

- `allocation-substrate-first-principles.md` (v1.1.0, DECISION 2026-05-25) **defers** allocator-parameterized Heap (D3) — external allocation sources were consciously left out of the W-program's scope. Foreign is not a revisit of D3: D3 is about *who allocates for us*; Foreign is about *memory nobody allocated for us*.
- `storage-memory-split.md` (v1.1.2, DECISION 2026-06-05) and the seat capability-elimination decisions (D1-B/D2, `.handoffs/REPORT-msb-tower-capability-elimination-decisions.md`) establish the doctrine this document operates under: composition over concrete columns, protocols as deletable code-share seams, ledger/oracle at the leaf.
- `occupancy-lives-in-the-leaf.md` (v1.0.0, DECISION 2026-06-07, Tier 3): liveness tracking and teardown live in a single-allocation leaf; `Storage.Contiguous<Memory.X>` lifts leaves uniformly. Foreign is a dense leaf in exactly this sense — the placement law is satisfied by construction.
- The custody precedent for release contracts is `Completion.Entry`'s Terminal Law — `~Copyable` + `consuming resolve()` + deinit that resumes-then-traps (`swift-io/Sources/IO Completions/Completion.Entry.swift:102-131`) [Verified: 2026-06-12]. See Q1 for why Foreign deliberately does NOT adopt the trapping variant.
- `memory-byte-bit-domain-orthogonality.md` (v1.0.0, 2026-06-03) and `cross-layer-capability-protocol-model.md` (v1.5.0, 2026-06-04) document the span-capability lift that Correction 2 above rests on.

### External (claims verified against primary sources by parallel subagents per [RES-020], 2026-06-12)

Every production datapath surveyed solves the third regime the same way: **a per-buffer release callback owned by the packet/buffer object, invoked on last release — never the allocator**.

- **FreeBSD mbuf** [Verified: 2026-06-12 — MATCHES]: `m_extadd(mb, buf, size, freef, arg1, arg2, flags, type)` attaches caller-provided storage under `M_EXT`; `typedef void m_ext_free_t(struct mbuf *)` with opaque context stored in `m_ext.ext_arg1/ext_arg2`; `mb_free_ext()` invokes `ext_free` when the refcount hits one — "the provider's callback frees the storage; the kernel's … path frees only the mbuf header itself" (sys/sys/mbuf.h:258,265,467,845; sys/kern/kern_mbuf.c:1162-1241,1553-1573; man mbuf(9)).
- **Linux sk_buff** [Verified: 2026-06-12 — MATCHES, v6.15 tag]: `void (*destructor)(struct sk_buff *skb)` (include/linux/skbuff.h:921, invoked from `skb_release_head_state`, net/core/skbuff.c:1144-1150); for MSG_ZEROCOPY user memory, `struct ubuf_info` rides in `skb_shinfo()->destructor_arg` with `ops->complete` — "The callback notifies userspace to release buffers when skb DMA is done in lower device" (skbuff.h:535-554,578); the kernel signals, the provider releases (Documentation/networking/msg_zerocopy.rst).
- **DPDK external mbufs** [Verified: 2026-06-12 — PARTIAL, claim corrected]: `rte_pktmbuf_attach_extbuf()` attaches "user-managed anonymous buffer … with appropriate free callback"; `struct rte_mbuf_ext_shared_info { rte_mbuf_extbuf_free_callback_t free_cb; void *fcb_opaque; RTE_ATOMIC(uint16_t) refcnt; }` — note the **refcount co-locates with the foreign buffer's shared info, not the mbuf**; `free_cb(m->buf_addr, m->shinfo->fcb_opaque)` fires at refcnt zero; flag `RTE_MBUF_F_EXTERNAL` (named `EXT_ATTACHED_MBUF` before DPDK 21.11) (lib/mbuf/rte_mbuf.h:1131-1216,1302-1317; rte_mbuf_core.h:397-400,696-703).
- **io_uring provided-buffer rings** [Verified: 2026-06-12 — MATCHES]: buffer rings registered via `IORING_REGISTER_PBUF_RING` (legacy: the `IORING_OP_PROVIDE_BUFFERS` SQE opcode); on buffer-selected receive "the resulting CQE will have IORING_CQE_F_BUFFER set … and the upper IORING_CQE_BUFFER_SHIFT bits will contain the ID of the selected buffers"; after consumption the buffer "is no longer known to io_uring. It must be re-provided if so desired or freed by the application" (io_uring_enter(2), io_uring_register(2), io_uring_prep_provide_buffers(3), io_uring_buf_ring_add(3)). The application-owned window between CQE and re-provide **is** the Foreign regime; the re-provide is the finalizer.
- **SwiftNIO ByteBuffer** [Verified: 2026-06-12 — claim corrected, and the correction is instructive]: ByteBuffer is NIO-managed CoW storage via `ByteBufferAllocator`; the general public API has no foreign-adoption construction. Since NIO 2.96.0 an SPI escape hatch exists — `@_spi(CustomByteBufferAllocator) init(takingOwnershipOf:allocator:)` plus a custom-allocator init taking **whole-allocator vtables of context-free `@convention(c)` function pointers** (Sources/NIOCore/ByteBuffer-core.swift:129-144,630-700). Because the deallocator is an allocator property rather than a per-buffer closure — and the memory must additionally survive `reallocate`/CoW — *arbitrary foreign memory with an arbitrary per-buffer finalizer remains inexpressible in NIO*. This is the negative image of the mbuf/skb/DPDK/Frame consensus and a useful warning: hanging release behavior on the allocator instead of the buffer cannot represent receive-pool custody.
- **Apple Frame** [Verified: 2026-06-12 — direct read]: `.customOwner(buffer:owner: AnyObject)` releases by ARC drop of the owner when the case is overwritten; only `.customFinalizer(buffer:finalizer:)` invokes a callback (`finalizeBufferOnly`, Frame.swift:429-442). Two details worth not imitating: the finalizer is **not `@Sendable`** `((UnsafeMutableRawBufferPointer) -> Void`, Frame.swift:34) — tolerable only under their queue-confined model — and `finalize(success:)`'s success flag is ignored by buffer finalization (outcome reporting and memory release are conflated in one API but only one is real).
- **Swift Span/lifetimes** [Verified: 2026-06-12 — claim corrected]: `Span`/`RawSpan` are `~Escapable` borrowing views, both from SE-0447 (Implemented, Swift 6.2); the `~Escapable` constraint is SE-0446 "Nonescapable Types" (Implemented, Swift 6.2), which **explicitly defers** lifetime-dependency annotations; that follow-up ("Lifetime Dependency Annotations for Non-escapable Types", swift-evolution PR #2305) has never been accepted, and `@_lifetime`/`Lifetimes`/`LifetimeDependence` remain experimental in 6.3/6.4/main. Consequence: the borrowing regime cannot own past the lending scope *by design* — confirming that the owning third regime cannot be built from spans.

### Contextualization step ([RES-021])

Universal adoption does not imply universal necessity, so: what does the consensus pattern look like in *this* type system, and what would it cost? In C systems the callback+context lives as two raw words on the buffer object, with hand-maintained refcounts. In the institute's system the same semantics is a `~Copyable` struct whose `deinit` invokes a stored closure: uniqueness replaces the refcount (move-only ⇒ exactly-once release, machine-checked), and the closure context replaces `arg1/arg2`. Nothing is lost in translation, and two things are gained — exactly-once is structural rather than counted, and the regime is a *type* rather than an enum case, so the tower composes over it monomorphically. The absence of this regime in the ecosystem is therefore a genuine gap, not a deliberate design decision: the corpus shows it was never considered (the D3 deferral is the nearest neighbor and is about a different axis).

## Analysis

### Q1 — Shape and placement

**Placement**: a sibling regime package, `swift-memory-foreign-primitives`, matching the one-regime-per-package family layout (heap/inline/map/shared/small/…). Namespace: `Memory.Foreign` ([API-NAME-001]). Naming check ([RES-010a]-scope): *Foreign* over *External* (which collides with the generic "external storage" phrasing the docs already use for unrelated things) and over *Adopted* (describes the construction verb, not the regime; every regime has an adopting init — `Memory.Contiguous.init(adopting:)`, `Memory.Heap.init(adopting:)`). *Foreign* names the provenance, matching the family's provenance-based naming, and matches the domain vocabulary (DPDK "external buffer", mbuf "externally managed data") without colliding inside the ecosystem.

**Why not compose existing primitives ([RES-018] composition check)**:

| Candidate | Why it cannot cover the regime |
|---|---|
| `Memory.Heap` / `Memory.Contiguous<Byte>` | `deinit` deallocates (`Memory.Contiguous.swift:117-120`) — wrong release semantics; adopting kernel-pool memory into them would free memory we don't own |
| `Swift.Span` / `Span.Protocol` | `~Escapable` — cannot outlive the lending scope (SE-0447/SE-0446); the regime's defining property is owning *past* it |
| `Memory.Map.Region` | non-owning Copyable descriptor; release is an explicit platform `unmap`, no hook for provider callbacks (`Memory.Map.Region.swift:14-45`) |
| `Memory.Allocator<…>` | allocators allocate; foreign memory is definitionally not allocated by us (the D3-deferred allocator-injection axis is orthogonal) |
| `Completion.Entry` | op-custody currency, not a memory region; wrong domain and wrong tier |

**Owner representation — finalizer-only (Option B), with the owner case absorbed by capture.** The options from the brief:

| Option | Shape | Assessment |
|---|---|---|
| A. Closed enum (Apple's `Frame.Buffer`) | `.bytes / .customOwner / .customFinalizer` cases | wrong tier for this ecosystem: a sum type at tier 1 reintroduces per-access case dispatch the tower's monomorphic columns exist to eliminate, and provenance-mixing is a *queue*-level concern (see Q3 end) |
| B. Finalizer-only struct | `buffer + @Sendable (UnsafeMutableRawBufferPointer) -> Void`, `deinit` invokes | one mechanism covers everything: an owner-object release is `{ _ = owner }` capture (invoke-then-release of the closure drops the owner); a pool recycle is the pool's re-provide closure |
| C. Owner case as a second type | `Memory.Foreign` + `Memory.Foreign.Owned<Owner>` or enum-of-two | only justification would be avoiding closure-context allocation; see cost note — it evaporates under reuse |
| D. Generic `Memory.Foreign<Owner>` | owner as type parameter | infects every downstream spelling (`Storage<Memory.Foreign<UringPool>>.Contiguous<Byte>` …) for zero seam benefit; the seam never consults the owner |

Cost note on B vs C: Apple's `customOwner` case plausibly exists to avoid allocating a closure context per packet. In Swift, closures are reference values — a receive pool creates its recycle closure **once** (per pool, or per registered buffer) and each `Memory.Foreign` adoption *retains* it; per-packet cost is a retain/release pair, the same as the AnyObject owner case. The allocation argument only bites for genuinely one-off finalizers, which are off the hot path by nature. One mechanism, B, is structurally sufficient ([RES-022]: structural correctness first; B is also the smallest surface).

**Finalizer contract**:

- Signature: `(UnsafeMutableRawBufferPointer) -> Void`, **`@Sendable` required**. Foreign values are `~Copyable` and will move across isolation domains (a packet completes on the proactor's executor and may be consumed elsewhere); the release runs wherever the last owner drops it. A `@Sendable` finalizer is what makes the move-only-absorber Sendable conformance honest — `extension Memory.Foreign: @unchecked Sendable {}` mirroring `Memory.Heap`'s pattern ("Move-only owning absorber …; unique ownership means cross-thread transfer is a move that relinquishes the sender's access", `Memory.Heap ~Copyable.swift:50-54`). This is a deliberate improvement over Apple's non-`@Sendable` finalizer, which their queue confinement tolerates and the institute's executor model would not. The Storage Sendable clause then composes: `Storage<Memory.Foreign>.Contiguous<E>` is Sendable for Sendable `E`.
- Exactly-once: structural. `~Copyable` forbids duplicate owners; `deinit` is the single invocation site; an explicit `consuming func take() -> (buffer:finalizer:)` escape hatch (precedent: `Memory.Contiguous.take()`, `Memory.Contiguous.swift:109-115`) transfers custody without invoking — `discard self` — for re-wrapping at representation boundaries.
- **No trapping deinit.** Apple's `Frame` traps on unfinalized drop, and `Completion.Entry`'s Terminal Law resumes-then-traps — both are *explicit-resolution* types: something observable (a waiter, an outcome) depends on resolution happening deliberately. A memory regime has no waiter; RAII release-on-drop is the family contract (`Memory.Heap` frees on drop). Foreign's `deinit` *runs the finalizer*; it does not trap. Outcome-bearing release (`finalize(success:)`) belongs to the future packet-currency type if it ever needs it — and note Apple's own success flag is dead weight at the buffer level (Prior Art).
- Typed throws: the finalizer returns `Void` and cannot throw — release is infallible by contract (matching every surveyed system; an erroring free has nowhere to report). [API-ERR-001] is satisfied vacuously; the adopting init needs no throws either (validation of the buffer is the provider's problem; an empty-buffer guard can be a precondition).

**Mutability**: one type, mutable contract — the adopted memory must be exclusively owned and writable, because `Storage.Contiguous` vends `_modify` unconditionally and `Memory.Address` carries no mutability split at the Region seam. Read-only foreign memory (e.g. a read-only mapping) must NOT be adopted into `Memory.Foreign` — writing through the tower would fault; that use case stays at the borrowing tier (`Span`) where it already lives, or motivates a future read-only storage column (recorded as a direction, not designed here).

**Copyability/layout**: unconditionally `~Copyable` (a type with `deinit` must be); `@frozen`; pointer-adopting like `Memory.Contiguous` — no `@_rawLayout`, so INV-INLINE-004a is untouched. Strict-memory-safety posture mirrors the family: the adopting init is the `@unsafe` construction boundary (adopting a raw pointer is the unsafe act); thereafter the type is a safe absorber per the `Memory.Contiguous`/`Memory.Heap` precedent (`Memory.Contiguous.swift:33-44`).

**Sketch** (V1/V2-verified shape, final spelling for the package):

```swift
extension Memory {
    @frozen
    public struct Foreign: ~Copyable {
        @usableFromInline internal let _base: Memory.Address
        @usableFromInline internal let _capacity: Memory.Address.Count
        @usableFromInline internal let _finalizer: @Sendable (UnsafeMutableRawBufferPointer) -> Void

        @unsafe @inlinable
        public init(adopting buffer: UnsafeMutableRawBufferPointer,
                    finalizer: @escaping @Sendable (UnsafeMutableRawBufferPointer) -> Void)

        @unsafe @inlinable
        public consuming func take() -> (buffer: UnsafeMutableRawBufferPointer,
                                         finalizer: @Sendable (UnsafeMutableRawBufferPointer) -> Void)

        @inlinable deinit { /* finalizer(reconstructed buffer) */ }
    }
}
extension Memory.Foreign: Memory.Region { /* base, capacity */ }
extension Memory.Foreign: @unsafe @unchecked Sendable {}
```

### Q2 — Family boundaries: Foreign vs Map vs Shared

The family's regimes separate on two axes: *who releases* and *ownership posture*.

| Regime | Provenance | Release | Posture | `Memory.Region`? |
|---|---|---|---|---|
| `Memory.Heap` | we allocate | our `deinit` deallocates | owning `~Copyable` | yes |
| `Memory.Inline` | the value IS the bytes | nothing to release | owning `@_rawLayout` | yes |
| `Memory.Map` (`.Region`) | kernel maps on our request | explicit platform `unmap` syscall | **non-owning Copyable descriptor** + L2 syscall vocabulary (`Memory.Map.Region.swift:14-45`) | no (and shouldn't: no stable-ownership contract) |
| `Memory.Shared` | kernel object (`shm_open`/`CreateFileMappingW`) | explicit syscalls | vocabulary namespace; L2 fills in (`Memory.Shared.swift:12-34`) | no |
| `Memory.Foreign` (proposed) | a provider we don't control | provider's callback, invoked by our `deinit` | owning `~Copyable` | **yes — its entire integration** |

Delineation: **Map and Shared are kernel-mediated *mapping vocabulary* with descriptor records; Foreign is an *ownership envelope*.** They are different cuts, not overlapping regimes, and they compose rather than compete: an owning mapped region — should one ever be wanted — is `Memory.Foreign(adopting: mappedBytes, finalizer: munmap-wrapper)`, i.e. Map supplies the verbs and Foreign supplies the RAII envelope. No retrofit of Map/Shared is proposed (the Copyable-descriptor design is deliberate: mappings are shared, inherited across forks, and unmapped at explicit points — RAII would be a semantics change, and [RES-029] says the identity question "is Map a Foreign?" answers NO: kernel-mediated lifetime is not provider-callback lifetime). Per the brief's request, mmap is hereby dropped from Foreign's motivating use cases; the motivating consumers are the four networking custody points (receive pools, layered hand-up, send pinning, retransmission).

### Q3 — Does a `Memory.Protocol` emerge? **No — it already exists, and its name is `Memory.Region`.**

The question dissolves under the verified current state:

1. **The memory-tier seam exists**: `Memory.Region`, base + capacity only, with a written non-collapse invariant that excludes exactly the things a fatter `Memory.Protocol` would be tempted to absorb (element types, init state, layout, allocator discipline — and, by the same logic, release semantics).
2. **It is already additive-only in the strongest sense**: it is consulted **once at construction** (`Storage.Contiguous.swift:21-27`) and never dispatched on a hot path — stricter than the Buffer.Protocol precedent (which at least ships `count`/`isEmpty` witnesses). Foreign's integration is one conformance, two computed properties (probe V1/V2).
3. **A unifying protocol over the five regimes would have an empty requirement set.** Remove what varies per regime — allocation (heap family only), release (the *defining* per-regime variation; abstracting it is the category error the brief anticipated), element operations (higher tier), mapping verbs (L2 platform) — and what remains is "located bytes": `base` + `capacity`. That IS `Memory.Region`. A sixth protocol would be a rename, not a discovery.
4. **The Memory namespace already hosts a protocol *family*, not a protocol *gap***: `Memory.Region` (raw located bytes) · `Span.Protocol` (owned typed span-vending — deliberately namespace-neutral, so NOT the seed of a Memory protocol; different cut: contiguity-for-reading vs located-ownership) · `Memory.Tracked`/`Memory.Allocatable` (typed self-cleaning leaves above `Store.Protocol`) · `Memory.Unique` (CoW). Each names one capability; none should grow.

**Verdict on the brief's Q3 sub-questions**: (a) `Storage.Contiguous` requires `Memory.Region` (convenience) / nothing (designated) — answered empirically; (b) `Memory.Contiguous.Protocol` is not the seed — it left the namespace as `Span.Protocol` for documented reasons; contiguity and provenance are orthogonal cuts; (c) confirmed and strengthened: deallocation stays out of the protocol because release is regime identity, encapsulated in each regime's `deinit` — the tower already works this way (the storage drop cascade never names release semantics).

**Legitimate additive roles when Foreign lands** (scoped per the doctrine; none block anything):

- **Seam laws**: extend the existing law pattern ("seam-level (Store.`Protocol` × Buffer.`Protocol`) test-support laws", `swift-buffer-primitives/Tests/Support/Seam.swift:12-13` [Verified: 2026-06-12]) with `Memory.Region` laws in the foreign package's test support: base stability across the lifetime, capacity constancy, finalizer exactly-once / not-before-drop. Mechanically checkable; additive.
- **Test-harness substrate swapping** — the institute analog of Apple's `HarnessProtocols` (the most valuable testing idea in their repo) costs **zero new protocols** here: probe V3 is the demonstration. A fixture exercises the same generic (or the same concrete shape) over `Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Byte>` in tests and `Storage<Memory.Foreign>.Contiguous<Byte>` in production. Where genuinely generic code is wanted, `Store.Ledgered.Protocol` (already ratified for exactly this composition) is the constraint; where it isn't, per-path concrete types share the shape. Apple needed harness protocols because their stack is protocol-witnessed; the tower's substrate parametricity provides the swap point for free.

**The mixed-provenance queue fork (brief §3)** — recorded as a lean, decided later at the packet-currency arc (non-goal): prefer **(b) everything-is-Foreign on the receive path** — pooled, mapped, and promoted-heap receive buffers all enter as `Memory.Foreign` (heap promotion wraps a deallocating finalizer; pool buffers wrap the shared recycle closure; per-buffer cost is a closure retain) — so the receive column is the monomorphic `Buffer<Storage<Memory.Foreign>.Contiguous<Byte>>.…` and no per-access provenance dispatch exists, which is the tower's specialization thesis applied. Apple's closed enum (option a) optimizes a different architecture (protocol-witnessed stack, enum dispatch per access); per-path concrete types (option c) remain available for the send path, which keeps the caller's currency. This lean is consistent with the zero-`witness_method` evidence the tower program already banked for concrete columns.

### Q4 — Timing: design now (this document), package on first consumer, generalization to the tower program

Three separable deliverables, three different timings ([RES-022]: the structurally-correct full design is done *now*; what is gated is only repository materialization, under the documented **ecosystem-gating exception** — the gate and its unblock conditions are explicit below):

1. **The design — DONE here.** Type shape, contracts, taxonomy, and protocol verdict above; instantiation risk retired by the committed probe. Nothing about the design is consumer-contingent; it was derived from the regime's semantics and four independent prior-art systems.
2. **`swift-memory-foreign-primitives` creation — GATED, on whichever comes second of**: (a) the first consumer arc reaching its foreign-memory step (sockets Phase 2B+/proactor receive-pool work — `Sockets.TCP` is "Phase 2A ships the blocking-strategy implementation" and swift-sockets HEAD is `13d6a66` "Partial L1 catch-up (WIP, does not yet build)" [Verified: 2026-06-12], so this is not imminent), and (b) the tower publication gate clearing (`OVERVIEW-tower.md:26,57` — new-package creation is currently a push-time/seat decision). The cautionary precedent stands verified: `swift-network-primitives` — "**Status: Unnecessary** — This package is a namespace reservation with no implementation. … Candidate for removal" (`swift-network-primitives/README.md:3`) [Verified: 2026-06-12]. The probe makes this gate cheap: materialization is a ~60-line package plus laws, a single session when the consumer lands. Deferral costs nothing because the design doc, not the repo, is the durable artifact.
3. **The buffer-tier where-clause generalization — ROUTE TO THE TOWER PROGRAM; not dispatched by this arc.** The heap pins fence out *every* non-heap region today (including shipping `Memory.Inline`), so this is a pre-existing tower-generality item, not a Foreign prerequisite to smuggle in: non-allocating ops (Bounded push/pop/peek/remove, static element-movers, the public Bounded init) can move to the `Store.Ledgered` seam their own header comments describe (V3 proves the bodies as written), while growth/CoW/checkpoint ops rightly stay heap-pinned, and the #12a value-generic same-type wall constrains only the Property-view sugar, not direct methods. Whether and when to land it is the seat's call within Phase 3/weakness-sweep scope — this document supplies the receipts (probe V3/V4, the fence-out finding) and stops.

Note the asymmetry this resolves in the brief's "defensible middle": the middle is not a compromise — it is the *correct* sequencing, because the only work with a current consumer-independent payoff (the generalization) belongs to a different program's authority, and the only work this arc could do alone (the package) has its risk already retired.

## Outcome

**Status: RECOMMENDATION** (package-creation and buffer-generalization decisions sit with the principal / tower seat; everything recommendable without new authority is recommended here).

1. **Memory.Foreign placement and shape**: sibling package `swift-memory-foreign-primitives` when gated-in; single `@frozen ~Copyable` finalizer-only regime type `Memory.Foreign` (owner-object release = closure capture; no enum, no Owner generic); `@Sendable` finalizer + `@unchecked Sendable` move-only absorber; non-trapping RAII deinit (Terminal-Law trapping is for explicit-resolution types, not memory regimes); `@unsafe` adopting init + consuming `take()`; mutable-exclusive contract; conforms `Memory.Region` — and that conformance is its entire tower integration (probe-verified: zero tier-2 changes).
2. **Taxonomy**: Foreign = owning envelope for provider-released memory; Map/Shared = kernel-mediated mapping vocabulary + non-owning descriptors; different cuts that compose (owning mapping = Foreign over Map's verbs); no retrofit; mmap dropped from Foreign's motivation.
3. **Memory.Protocol verdict: no new protocol.** `Memory.Region` *is* the memory-tier protocol — minimal by written invariant, construction-time-only in practice, and exactly sufficient for Foreign. Release semantics stay out of any protocol (regime identity). Additive follow-ons when Foreign lands: `Memory.Region` seam laws in test support; harness substrate-swapping needs no new protocol (V3 pattern; `Store.Ledgered` where genuine genericity is wanted). Receive-path provenance lean: everything-is-Foreign (monomorphic column), decided finally at the packet-currency arc.
4. **Timing**: design adopted now; package creation gated on first consumer arc ∧ tower publication gate; buffer-tier where-clause generalization surfaced to the tower program (Phase 3/weakness-sweep) with receipts, since the heap pins currently fence out all non-heap regions including `Memory.Inline`.

### Residual ([RES-027] — premises vs directions)

- **Premise (backed by experiment)**: "a Foreign-shaped `Memory.Region` conformer instantiates the storage tier unchanged, and the buffer tier's pins are spelling-not-substance" — `swift-buffer-ring-primitives/Experiments/foreign-region-tower-instantiation/` (V1–V4, Swift 6.3.2, 2026-06-12). No unverified premise is carried forward.
- **Direction** (no downstream constraint until picked up): read-only foreign memory (read-only mappings, immutable send payloads) — stays at the `Span` tier today; a read-only storage column is a separate investigation if a consumer materializes.
- **Direction**: the packet-currency type (Apple's `Frame` analog; name must avoid `Machine.Frame` and the L2 wire-format `Frame` senses) — designed at the networking layer when a consumer exists, where the mixed-provenance lean above gets its decision.
- **Direction**: doc-lag cleanups noted in Corrections (Buffer.swift:23 spelling; Memory.swift:21 protocol pointer; Memory.Tracked conformer list) — tower-program housekeeping, not this arc.

## References

Internal (paths relative to `/Users/coen/Developer/`):
- `swift-primitives/swift-memory-primitives/Sources/Memory Region Primitives/Memory.Region.swift` · `Memory Contiguous Primitives/Memory.Contiguous{,+Span.Protocol}.swift` · `Memory {Tracked,Allocatable,Unique} Primitives/*.Protocol.swift`
- `swift-primitives/swift-memory-heap-primitives/Sources/Memory Heap Primitives/Memory.Heap{, ~Copyable}.swift`
- `swift-primitives/swift-storage-primitives/Sources/Storage Contiguous Primitives/Storage.Contiguous{,+Store.Protocol}.swift`
- `swift-primitives/swift-store-primitives/Sources/Store {Protocol,Ledgered} Primitives/Store.{Protocol,Ledgered}.swift`
- `swift-primitives/swift-buffer-ring-primitives/Sources/…` (pins and static ops as cited) and `Experiments/foreign-region-tower-instantiation/` (the probe, commit `7dad2c9`)
- `swift-foundations/swift-io/Sources/IO Completions/Completion.Entry.swift` (Terminal Law)
- Research: `storage-memory-split.md` · `allocation-substrate-first-principles.md` (swift-memory-primitives) · `memory-byte-bit-domain-orthogonality.md` · `cross-layer-capability-protocol-model.md` · `occupancy-lives-in-the-leaf.md` · `nonescapable-support-memory-storage-buffer.md` · tower records `.handoffs/{OVERVIEW-tower,HANDOFF-tower-SEAT,REPORT-msb-tower-capability-elimination-decisions}.md`

External (primary sources, subagent-verified 2026-06-12):
- FreeBSD: [mbuf(9)](https://man.freebsd.org/cgi/man.cgi?query=mbuf&sektion=9) · [sys/sys/mbuf.h](https://github.com/freebsd/freebsd-src/blob/main/sys/sys/mbuf.h) · [sys/kern/kern_mbuf.c](https://github.com/freebsd/freebsd-src/blob/main/sys/kern/kern_mbuf.c)
- Linux v6.15: [include/linux/skbuff.h](https://github.com/torvalds/linux/blob/v6.15/include/linux/skbuff.h) · [net/core/skbuff.c](https://github.com/torvalds/linux/blob/v6.15/net/core/skbuff.c) · [MSG_ZEROCOPY](https://docs.kernel.org/networking/msg_zerocopy.html)
- DPDK: [rte_mbuf.h API](https://doc.dpdk.org/api/rte__mbuf_8h.html) · [lib/mbuf/rte_mbuf_core.h](https://github.com/DPDK/dpdk/blob/main/lib/mbuf/rte_mbuf_core.h)
- io_uring: [io_uring_enter(2)](https://man7.org/linux/man-pages/man2/io_uring_enter.2.html) · [io_uring_register(2)](https://man7.org/linux/man-pages/man2/io_uring_register.2.html) · [io_uring_prep_provide_buffers(3)](https://man7.org/linux/man-pages/man3/io_uring_prep_provide_buffers.3.html) · [io_uring_buf_ring_add(3)](https://man7.org/linux/man-pages/man3/io_uring_buf_ring_add.3.html)
- SwiftNIO ≥2.96.0: [ByteBuffer-core.swift](https://github.com/apple/swift-nio/blob/main/Sources/NIOCore/ByteBuffer-core.swift) (`@_spi(CustomByteBufferAllocator)` inits)
- Swift Evolution: [SE-0447 Span](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) · [SE-0446 Nonescapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md) · [PR #2305 Lifetime Dependency Annotations](https://github.com/swiftlang/swift-evolution/pull/2305) (open, unnumbered)
- Apple: `apple/swift-network-evolution` @ `919cd6e`, `Sources/SwiftNetwork/Protocols/Frame.swift` (local clone, direct read)
