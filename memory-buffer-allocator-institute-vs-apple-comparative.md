# Memory, Buffer & Allocator: Institute vs. Apple/Swiftlang — Comparative Analysis

<!--
---
version: 1.0.0
last_updated: 2026-05-31
status: ANALYSIS
statusDetail: "Round 2 of 2 — comparative analysis of the Swift Institute's memory/buffer/allocator approach against apple/swiftlang (Round 1: apple-swiftlang-memory-buffer-allocator-survey.md + apple-swiftlang-arena-allocator-family-implementations.md). Surfaces decision points for principal convergence; does NOT unilaterally mandate changes."
tier: 2
scope: ecosystem-wide
---
-->

## Context

**Trigger.** Round 2 of the two-round study the principal requested. Round 1 produced a pure external survey of apple/swiftlang's memory/buffer/allocator approach (`apple-swiftlang-memory-buffer-allocator-survey.md` v1.1.0) and an implementation deep-dive of their arena/allocator families (`apple-swiftlang-arena-allocator-family-implementations.md` v1.0.0), both deliberately *without* Institute comparison. This document is that comparison.

**Method.** The apple/swiftlang side is the two Round-1 docs (primary-source-verified, adversarially checked). The Institute side was gathered fresh for this round by five parallel agents reading **current source with `file:line`**, treating Institute research docs as *leads, not ground truth* per [RES-013a]/[RES-023] — every load-bearing Institute claim below is anchored to verified code, and one agent confirmed a clean `swift build` of `swift-memory-arena-primitives`. The agents surfaced ~10 stale Institute docs (catalogued in Appendix B) — a corpus-health signal, separate from the comparison.

**Governing discipline — [RES-021] contextualization.** "Universal adoption does not imply universal necessity." Where a concept is present in one ecosystem and absent in the other, this document **concretizes what it would cost** in the other's type system before classifying it as a gap vs. a deliberate design choice. Several "X exists here, not there" findings resolve to *deliberate divergence*, not gap, in both directions.

**Maturity-fairness note.** apple/swiftlang's pieces (Span family, InlineArray, `Atomic`/`Mutex`) are *shipped in released Swift 6.2* (some back-deployed). The Institute's pieces are *shipped-in-package* but (a) ride the **same** experimental compiler substrate apple's do (`Lifetimes`/`LifetimeDependence` flags, underscored `@_lifetime`), (b) include explicit **transitional stand-ins** for not-yet-shipped stdlib features (e.g. `Ownership.Borrow`/`Inout` stand in for SE-0519), and (c) carry a live `@_rawLayout` deinit-bug workaround (`swiftlang/swift#86652`). Neither side is "more settled" on the experimental lifetime substrate — both bet on the same in-flight language features.

---

## Question

How does the Swift Institute's approach to memory, buffers, and allocators compare to apple/swiftlang's — where does it converge (reuse), where does it deliberately diverge (and why), and which differences are genuine decision points vs. settled design?

---

## Analysis

### The thesis: shared substrate, divergent surface and mission

The comparison resolves into one structural picture:

- **Substrate — convergent by deliberate reuse.** The Institute does **not** reimplement the stdlib's low-level memory machinery. There is no `swift-span-primitives` (verified absent); the Institute consumes stdlib `Span`/`RawSpan`/`MutableSpan`/`UTF8Span` directly. `Array.Inline<let N>` is a literal `typealias` to `Swift.InlineArray`. Atomics go through stdlib `AtomicRepresentable`/`Synchronization.Atomic`; `Async.Mutex` reuses `Synchronization.Mutex` where available. `@_rawLayout`, `~Copyable`/`~Escapable`, and underscored `@_lifetime` are the same primitives apple uses. **The Institute and apple stand on the same foundation.**
- **Surface — divergent by mission.** The Institute wraps that shared substrate in a **typed, layered, namespaced, Foundation-free protocol/type vocabulary** the stdlib deliberately omits: `Memory.Address` (typed-integer addressing), `Storage.Protocol` (`pointer(at:)`+`capacity`), `Buffer.*` disciplines, the `Ownership.*` family, and — the sharpest case — a public `Memory.Arena`/`Pool`/`Allocator` vocabulary at L1.
- **Mission/policy — divergent and non-negotiable.** Foundation-independence (hard, all-five-layers, lint-enforced), mandatory ecosystem-wide strict memory safety (vs. apple's opt-in SE-0458), and typed-everything (universal typed throws, typed indices/counts) are Institute invariants apple does not share.

The rest of this section is axis-by-axis. **CONVERGE** = Institute reuses/matches apple; **EXTEND** = Institute adds a typed/layered surface over the shared substrate; **DIVERGE** = genuinely different choice.

| Axis | apple/swiftlang | Institute | Verdict |
|---|---|---|---|
| A. Borrowed views (`Span` family) | stdlib `Span`/`RawSpan`/`MutableSpan`/`OutputSpan`/`UTF8Span` on `~Escapable`+`@_lifetime` | **Reuses** stdlib Span; adds `.Borrowed` nominal wrappers + typed-`Cardinal` iterators + `Sequence.Borrowing.Protocol` | **CONVERGE** (+ thin EXTEND) |
| B. Ownership substrate | `~Copyable`/`~Escapable`/`consuming`/`borrowing`; stdlib `Borrow`/`Inout` (SE-0519, 6.4) | Same substrate, pervasive (1,156 `~Copyable` files); **own `Ownership.*` 7-type family**, explicit pre-SE-0519 stand-ins | **CONVERGE substrate, EXTEND surface** |
| C. Fixed-size / inline storage | `InlineArray` (SE-0453), value generics (SE-0452), `ManagedBuffer` | **Reuses** `InlineArray` (`Array.Inline` = typealias); **adds** `@_rawLayout` `Memory.Inline` for the `~Copyable`/variable-count gap; `Array.Static` (0..N inline) | **CONVERGE + EXTEND** |
| D. Buffer/storage idiom | value-façade + `final class` CoW + `isKnownUniquelyReferenced` (NIO `ByteBuffer`, `Data`) | **Same idiom** on the Copyable/heap path; **adds** typed `Storage.Protocol`, a move-only `@_rawLayout` inline path (no CoW), per-slot bitmap init-tracking | **CONVERGE idiom, EXTEND** |
| E. Arenas / pools / allocators | pervasive but **hidden per-subsystem internal infra**; **NO public allocator/arena abstraction** | **Public, composable L1 stack**: `Memory.Arena`/`Pool`, `Storage`/`Buffer.Arena` (generational slotmap), public `Memory.Allocator.Protocol` (**dormant**) | **DIVERGE** (sharpest) |
| F. Synchronization | `Synchronization` module: `Atomic`/`Mutex` (`@_rawLayout`), separate module | **Reuses** stdlib `Atomic`/`Mutex`; **adds** `CPU.Atomic` (load/store-only, C11 shim) for externally-owned raw memory | **CONVERGE + niche EXTEND** |
| G. Philosophy / layering / safety | flat names; opt-in strict safety; no Foundation-independence req; typed-throws not pervasive | `Nest.Name`+spec-mirroring; **mandatory** strict safety + disclosure; **hard Foundation-independence**; universal typed throws; 5-layer/13-tier | **DIVERGE (policy)** |

---

### A. Borrowed views — the `Span` family

**CONVERGE (deliberate reuse).** apple's `Span` family is the centre of gravity of its recent memory work — non-owning, bounds- and lifetime-checked views on `~Escapable`. The Institute made an explicit DECISION (`span-view-integration-strategy.md` v1.1.0) to **integrate stdlib `Span` into its protocol hierarchy rather than build a custom one**; the verified reality matches: bare `Swift.Span<Element>` is surfaced through the namespace-neutral `Span.Protocol` capability (`swift-span-primitives/.../Span.Protocol.swift`, with `Swift.Span+Span.Protocol.swift` conforming the stdlib type directly), rather than wrapped in a nominal borrowed-view struct. Containers vend `.span`/`.mutableSpan` via `@_lifetime`-annotated getters exactly as apple's do (`Buffer.Linear+Span.swift:14,27`). [MEM-SAFE-012] mandates `Span` as the *primary* contiguous-access interface — apple positions it as the migration *destination*; the Institute makes it the default and pushes it down to L3 consumer sites ([MEM-SPAN-002]).

**Thin EXTEND:** the Institute adds (a) `.Borrowed` nominal wrappers so a borrowed view can carry an Institute conformance protocol (stdlib `Span` can't be retroactively conformed to carry one), (b) typed-`Cardinal` span iterators instead of stdlib's bare `Int`, and (c) `Sequence.Borrowing.Protocol` mirroring stdlib's experimental `_BorrowingSequence`.

**[RES-021] check:** the Institute does *not* lack anything apple has here; it consumes the same types. The wrappers are not a reimplementation — they are the minimal glue to fit stdlib `Span` into a nominal typed protocol hierarchy. No gap either direction.

### B. Ownership substrate

**CONVERGE (substrate).** Both stand on `~Copyable`/`~Escapable`/`consuming`/`borrowing` and the experimental `@_lifetime`/`Lifetimes` flag. Institute adoption is *deeper than a typical consumer codebase*: 1,156 `~Copyable` files, 192 `~Escapable`, 229 `@_lifetime`, the `Lifetimes` flag in 350 manifests — and, like apple, it uses **only** the underscored `@_lifetime` (one bare `@lifetime` is a doc comment), correctly tracking the LSG's "not yet standardized" posture.

**EXTEND (surface).** The Institute ships its own `Ownership.*` family (`swift-ownership-primitives`) — a **7-type contract matrix** (`Unique`/`Shared`/`Mutable`/`Slot`/`Transfer`/`Borrow`/`Inout`; `Ownership.swift:18-40`) plus a borrow-capability protocol `Ownership.Borrow.\`Protocol\`` adopted by 14 conformer types. Crucially, `Ownership.Borrow`/`Inout` (`Ownership.Borrow.swift:72`, `Ownership.Inout.swift:49`) are **explicit pre-SE-0519 stand-ins** for stdlib `Borrow<T>`/`Inout<T>` — raw-pointer-backed, using `_read` coroutines "until `borrow` accessor (SE-0507) ships," with a documented migration to the stdlib builtins once those land. apple has no equivalent *named* ownership type family because the language keywords + (forthcoming) stdlib `Borrow`/`Inout` are its surface.

**[RES-021] check:** Is apple's lack of an `Ownership.*` type family a gap? **No — deliberate.** Concretized: apple expresses ownership through language keywords and a minimal stdlib `Borrow`/`Inout`; a named 7-type family would be redundant surface for the stdlib's mission. Is the Institute's family premature, given it stands in for unshipped SE-0519? It is **transitional by design and documented as such** — judged on structural correctness + evergreen per `feedback_correctness_and_evergreen`, not consumer-demand, and it has 14 real conformers. Not premature; but its value compounds only once SE-0519/SE-0507 stabilize (a shared bet with apple's own Span family).

### C. Fixed-size / inline storage

**CONVERGE (reuse).** `Array.Inline<let N: Int>` is a literal `typealias Swift.InlineArray<N, Element>` (`swift-array-primitives/.../Array.Inline.swift:30`); `Linear.Vector<let N>`/`Linear.Matrix` *store* stdlib `InlineArray` directly (`Linear.Vector.swift:18-20`). Value/integer generics (SE-0452) are used pervasively. The Institute deferred the `[N of T]` *sugar* (SE-0483) pending verification (`swift-6.3-ecosystem-opportunities.md`), but uses the underlying type heavily (503+ sites).

**EXTEND (fills a stdlib gap with the same mechanism).** `InlineArray` requires `Copyable`-ish, all-N-initialized semantics. For the `~Copyable`-element / manual-lifecycle / variable-count-inline cases stdlib `InlineArray` can't serve, the Institute adds `Memory.Inline<Element: ~Copyable, let capacity: Int>` (`swift-memory-primitives/.../Memory.Inline.swift:50-77`) over `@_rawLayout(likeArrayOf:count:)` — the *same* `@_rawLayout` attribute stdlib uses for `Atomic`/`Mutex` cells — composed up into `Storage.Inline` → `Buffer.Linear.Inline` → `Array.Static<let capacity>` (variable count 0..N, inline-stored; `Array.Static.swift:40-42`). stdlib has no variable-count inline array.

**[RES-021] check:** The Institute's `Memory.Inline`/`Array.Static` is not "reinventing InlineArray" — it covers cases SE-0453 explicitly does not (`~Copyable` elements, partial initialization, 0..N count). Genuine EXTEND, not duplication. *Caveat (maturity):* the inline family is gated by the `@_rawLayout` deinit bug (`#86652`, not fixed in 6.3) — some `.Small`/`.Static` variants document non-auto-deinit-on-drop; treat inline-family drop-safety as compiler-limited.

### D. Buffer / storage idiom

**CONVERGE (idiom).** apple's recurring shape — value-type façade + `final class` CoW storage + `isKnownUniquelyReferenced` + index/slice bookkeeping, `Span` on top — is *exactly* the Institute's Copyable/heap path. `Storage.Heap` is a `~Copyable` struct over a `final class` `ManagedBuffer` backing, conditionally `Copyable where Element: Copyable` (`Storage.Heap.swift:62,135`); CoW is live (`isKnownUniquelyReferenced`→`ensureUnique()` wired into every mutator, `Storage.Heap Copyable.swift:27,53`), and `Buffer.Linear.ensureUnique()` delegates to it. `clone`/`reallocate` mirror SE-0527 semantics. This is the stdlib-`Array`/NIO-`ByteBuffer`/`Data` idiom, shipped.

**EXTEND (three additions stdlib lacks).** (1) A typed `Storage.Protocol` (`pointer(at:)` + `capacity`, `Storage.Protocol.swift:20-35`) with phantom `Index<Element>`; apple has no storage protocol (`ByteBufferAllocator` is a malloc vtable, a different concern). (2) A **parallel move-only inline path** (`@_rawLayout`, unconditionally `~Copyable`, no CoW) alongside the CoW heap path — stdlib ships only the heap/CoW shape. (3) Per-slot bitmap init-tracking (`Bit.Vector.Static`). The Institute also keeps `Buffer.Protocol` (logical `count`) and `Storage.Protocol` (physical `pointer`+`capacity`) deliberately orthogonal — *has-a, not is-a* (`Buffer.Protocol.swift:87-91`).

**Divergence in one detail:** `Buffer.Aligned` (the closest analog to NIO `ByteBuffer`'s malloc-backed storage) is **move-only with no CoW and no reader/writer-index model** (those are delegated to `Binary.Cursor`), and uses pure-Swift `UnsafeMutableRawPointer.allocate` (not malloc/posix_memalign). Growth is a **pluggable `@Sendable` closure policy** (`.doubling`/`.factor`/`.exact`/`.pageAligned`) — apple's NIO hard-codes next-power-of-two. The Institute's existing `canonical-buffer-discipline-cross-language-survey.md` (RECOMMENDATION) already concluded contiguous/`Linear` is the canonical default (8/8 languages) and that the Institute's `Array` already plays stdlib `Array`'s role — this synthesis extends, not contradicts, that.

### E. Arenas / pools / allocators — the sharpest divergence

This is where Round 1's most load-bearing finding meets the Institute head-on.

**Round 1 (verified):** apple/swiftlang implement slab-bump arenas *pervasively* (swift-syntax, task allocator, metadata, compiler, sourcekit-lsp, swift-java) but **8 of 9 are SPI/`package`/runtime-internal/Java** — there is **no public `Allocator`/`Arena` protocol** anywhere; the only public allocation surface is stdlib `withUnsafeTemporaryAllocation` + NIO's framework allocator.

**Institute (verified):** a **public, composable three-tier arena stack at L1**, with real cross-package consumers (Tree.*, Async.Timer.Wheel, Binary/Parser.Machine, Link, …):
- `Memory.Arena` — raw bump allocator, free-all-on-deinit + `reset()` (`swift-memory-arena-primitives/.../Memory.Arena.swift:27`). Shape ≈ apple's swift-syntax `BumpPtrAllocator`, but **public** and returning `nil` on exhaustion (no heap spill — a divergence from apple's universal fallback).
- `Storage.Arena` / `Buffer.Arena` — a **generation-token free-list slotmap** with a `Buffer.Arena.Position` capability handle (index+generation, use-after-free detection), conditionally `Copyable` with CoW (`Storage.Arena.swift:75,113-135`). **This is the Rust `slotmap`/`generational-arena` idiom — which apple/swiftlang does NOT have internally.**
- `Memory.Pool` (in-band LIFO free-list, bit-vector double-free guard, `Memory.Pool.swift:61,240-283`), `Storage.Pool` (composes `Memory.Pool`), `Pool.Bounded` (object-recycling resource pool ≈ NIO `Pool<Element>`).
- **A public `Memory.Allocator.Protocol`** (`swift-memory-primitives/Sources/Memory Allocation Primitives/Memory.Allocator.Protocol.swift:23`): `~Copyable`, typed-throws, alignment-on-both-ends. **apple has no such public protocol.**

**The critical honesty check — the public allocator protocol is DORMANT.** Exhaustive grep: it has **one conformer** (the system `Memory.Allocator`, `throws(Never)`) and **zero consumers**. `Memory.Arena`/`Pool` **do not conform to it** (their signatures don't match), and nothing is parameterized over `some Memory.Allocator.Protocol`. So while the Institute has *declared* the public abstraction apple deliberately omits, it has **not realized it as a live pluggable mechanism** — functionally, both ecosystems route allocation through concrete types today.

**[RES-021] contextualization (both directions):**
- *Is apple's absence of a public allocator a gap?* **No — deliberate.** Concretized in Swift terms: a pluggable `Allocator` protocol with associated `Error` and `~Copyable` support is *expressible* (the Institute proves it compiles), but the stdlib's mission is safe high-level containers + `Span`, not allocator plumbing; apple keeps arenas as hidden per-subsystem infra so each can pick its own free discipline without a one-size protocol. The cost of a stdlib allocator protocol would be ABI surface + the InlineArray/Span work would have to thread an allocator parameter — apple chose not to pay it. The Round-1 docs already reserved judgment here ("Whether this is a genuine gap *for the Institute* is a Round-2 question").
- *Is the Institute's dormant protocol a gap/smell?* **Yes, a mild one — flagged as a decision point** (see Open Decision Points). A public protocol with one conformer, zero consumers, that the concrete arenas/pools don't even conform to, is exactly the "reserved surface that may be premature" pattern [RES-018]/[MOD-RENT] caution against. It is *not* wrong (it's structurally coherent and documents intent), but it earns its keep only if the arenas/pools are wired to conform and at least one consumer is parameterized over it. Until then it's declared-not-realized.

**Net:** this is the Institute's most distinctive, genuinely-additive surface vs. apple — a public, typed, composable allocator/arena/pool vocabulary, including a generational-slotmap arena apple lacks entirely. It is also the surface most in need of a "wire it or mark it reserved" decision.

### F. Synchronization

**CONVERGE (reuse).** No Institute-reimplemented `Atomic<T>`: Institute value types conform to stdlib `AtomicRepresentable` (gated `#if SYNCHRONIZATION_AVAILABLE`, `Cardinal+AtomicRepresentable.swift:16`) and consumers use `Synchronization.Atomic` directly (`Executor.Shutdown.Flag`→`Atomic<Bool>`, `Ownership.Latch`→`Atomic<Int>` CAS). `Async.Mutex` is a platform multiplexer that **reuses `Synchronization.Mutex`** where available and ships its own `@_rawLayout`+`os_unfair_lock` inline impl on Darwin — the same `@_rawLayout` mechanism stdlib uses. (Note one dead `#if` branch referencing an absent `Kernel_Thread_Primitives` — Appendix B.)

**Niche EXTEND.** `CPU.Atomic` (`swift-cpu-primitives`, C11 `<stdatomic.h>` shim, liburing-style) provides ordered **load/store ONLY** on *externally-owned* `UnsafeMutablePointer` (mmap'd ring buffers, shared-memory IPC) — a case stdlib `Atomic<T>` cannot serve because it *owns* its storage. It is deliberately not a general atomic (no CAS/RMW); full RMW still goes through stdlib.

**[RES-021] check:** `CPU.Atomic` is not a reimplementation of stdlib atomics — it covers the externally-owned-memory niche stdlib structurally excludes. Genuine EXTEND. apple's lack of it is not a gap (apple's equivalent need, e.g. in swift-system's io_uring, is met by its own internal primitives behind a flag).

### G. Philosophy / layering / safety — the policy divergences

These are not type-level differences but **mission invariants**, all skill-codified and largely lint-mechanized:

- **Foundation-independence — the defining divergence.** [PRIM-FOUND-001] + [ARCH-LAYER-007] make it a hard, all-five-layers, lint-enforced invariant. apple has *no* such requirement. Rationale ([ECO-001]): cross-platform + Embedded compatibility, typed correctness, fine-grained packaging.
- **Strict memory safety is mandatory, not opt-in.** [MEM-SAFE-001] requires `.strictMemorySafety()` ecosystem-wide; apple ships SE-0458 as opt-in "for the foreseeable future." The Institute adopts apple's *semantics* verbatim (`@safe`/`@unsafe`/`unsafe`, the five-dimension taxonomy, expression-granularity, `Span`-as-destination — per `swift-safety-model-reference.md`, compiler-source-derived) but adds the **isolation discipline** ([MEM-SAFE-020] absorber/propagator + acid test) and **mandatory human-auditable `// SAFETY:`/`// WHY:` disclosure** on every `@safe` ([MEM-SAFE-025b/c]) — both stricter than SE-0458.
- **Typed everything.** Universal, lint-enforced typed throws ([API-ERR-001]) — vs. stdlib's mostly-untyped `throws`/`rethrows`; typed indices/counts/ordinals; spec-as-namespace (`RFC_4122.UUID`, not bare `UUID`).
- **`Nest.Name` + spec-mirroring + one-type-per-file** ([API-NAME-001/002/003], [API-IMPL-005]) — a wholesale rejection of stdlib's flat naming. (Open tension: `stdlib-naming-beats-ecosystem-naming.md` is an IN_PROGRESS stub triggered by the `swapAt` rename — the principled rule awaits an empirical sweep; the current lean is "ecosystem naming wins, [API-NAME-002] overrides stdlib pedigree." Do not present as settled.)
- **Byte/UInt8 domain separation** ([API-BYTE-*]) — `Byte` (byte-domain, no arithmetic) is a sibling of `UInt8` (arithmetic carrier); stdlib uses bare `UInt8` everywhere.
- **Layered quarantine generalized.** apple's narrow `Synchronization`-module quarantine of "sharp tools" becomes the Institute's 5-layer + L1 13-tier license-graded DAG ([ARCH-LAYER-001], [PRIM-ARCH-001]), plus an explicit "improve the Institute, don't reach for Apple/3rd-party" posture ([ARCH-LAYER-011]).

**Convergences worth preserving (not divergences):** `Span` as the normative interface; expression-granular `unsafe`; the five-dimension safety taxonomy; the `~Copyable`/`~Escapable`/`~Sendable` inverse-constraint direction; `@_rawLayout`-backed inline storage; and notably the **bare `@unchecked Sendable` convention the Institute deliberately revised (BREAKING, 2026-05-13, [MEM-SAFE-024]) to *match* observed stdlib/Apple convention** (zero `@unsafe @unchecked Sendable` pairs across the stdlib + 15 surveyed Apple packages).

---

## Outcome

**Status: ANALYSIS — Round 2 comparison complete.** This document characterizes and surfaces decision points; per the workspace collaboration protocol it does **not** unilaterally mandate code changes (those require principal convergence).

**Synthesized characterization:**

1. **The Institute is convergent-with-stdlib at the substrate, by deliberate policy.** It reuses stdlib `Span`, `InlineArray`, `Synchronization`, `@_rawLayout`, and the `~Copyable`/`~Escapable`/`@_lifetime` machinery rather than reimplementing — and is positioned (via documented stand-ins) to swap its transitional types for stdlib `Borrow`/`Inout` as SE-0507/0519 stabilize. Where it reimplements (`Memory.Inline`, `CPU.Atomic`), it covers cases stdlib structurally *cannot* (`~Copyable`/variable-count inline; externally-owned-memory atomics) — genuine EXTEND, not duplication.
2. **The Institute's distinctive surface is a typed, public, layered allocation/storage vocabulary** (`Memory.Address`/`Arena`/`Pool`/`Allocator.Protocol`, `Storage.Protocol`, `Buffer.*`, `Ownership.*`) that the stdlib deliberately omits — including a **generational-slotmap arena apple/swiftlang has nowhere**, and a **public allocator protocol apple has nowhere** (though currently dormant).
3. **The divergences that matter are mission/policy, not mechanism:** Foundation-independence, mandatory strict safety + disclosure, and typed-everything are non-negotiable Institute invariants with no apple counterpart. These are deliberate and well-rationalized; they are not gaps.
4. **Neither side is more "settled" on the experimental lifetime substrate** — both ride un-standardized `@_lifetime`; the Institute additionally carries transitional stand-ins and a live `@_rawLayout` compiler-bug workaround.

**Per [RES-021], the only items that read as genuine *gaps* (vs. deliberate divergence):**
- *(Institute-internal)* the **dormant `Memory.Allocator.Protocol`** — declared public surface not yet realized (decision point below).
- *(Institute-internal)* **no documented position** yet on apple's `OutputSpan`/`OutputRawSpan` "initialize-from-uninitialized" verb as a *first-class type* (the Institute reuses stdlib `OutputSpan` at `Buffer.Linear+OutputSpan`, but has not taken a stance on whether its construction story needs more) — minor synthesis surface.
- Everything else classified as CONVERGE or deliberate EXTEND/DIVERGE.

### Open decision points (for principal convergence — not unilateral recommendations)

1. **Wire or reserve `Memory.Allocator.Protocol`.** It is public with one conformer and zero consumers; `Memory.Arena`/`Pool` don't conform. Options: (a) make the arenas/pools conform and parameterize ≥1 consumer over `some Memory.Allocator.Protocol` (realize the pluggable abstraction apple lacks — a real differentiator); (b) keep it explicitly reserved with a doc note (avoid the [RES-018]/[MOD-RENT] "premature surface" smell); (c) defer. *Recommendation (pending decision): (a) if any consumer genuinely needs allocator-strategy injection; else (b).*
2. **The generational-slotmap arena (`Storage`/`Buffer.Arena` + `Position`) is a genuine novelty vs. apple/swiftlang.** Decision point: document it as a deliberate differentiator (and possibly a future Swift Evolution / forums talking point), since Round 1 confirmed apple has the bump/LIFO/CoW idioms but *not* the generational slotmap.
3. **`OutputSpan` construction stance** — confirm the Institute's incremental-buffer-construction story is fully served by reusing stdlib `OutputSpan`/`OutputRawSpan` (it appears to be, via `Buffer.Linear+OutputSpan`), or note any divergence.
4. **Naming convergence** ([RES-019]-flagged) — `stdlib-naming-beats-ecosystem-naming.md` remains IN_PROGRESS; this comparison reinforces that the question is live (apple's flat names vs. `Nest.Name`) but does not resolve it.

---

## References

**Round-1 apple/swiftlang baseline (this repo):** `apple-swiftlang-memory-buffer-allocator-survey.md` (v1.1.0, ANALYSIS) · `apple-swiftlang-arena-allocator-family-implementations.md` (v1.0.0, ANALYSIS).

**Institute source (verified `file:line`, 2026-05-31):** `swift-memory-primitives` (`Memory.Address.swift:54`, `Memory.Inline.swift:50-77`, `Memory Allocation Primitives/Memory.Allocator.Protocol.swift:23`, `Memory.Allocator.swift:14`) · `swift-span-primitives` (the borrowed contiguous view, then `Memory.Contiguous.Borrowed`, now bare `Swift.Span` via `Span.Protocol.swift`) · `swift-memory-arena-primitives` (`Memory.Arena.swift:27`) · `swift-memory-pool-primitives` (`Memory.Pool.swift:61`) · `swift-storage-primitives` (`Storage.Protocol.swift:20-35`, `Storage.Heap.swift:62`, `Storage.Heap Copyable.swift:27`, `Storage.Inline.swift:62`) · `swift-storage-arena-primitives` (`Storage.Arena.swift:75`) · `swift-storage-pool-primitives` (`Storage.Pool.swift`) · `swift-buffer-primitives` (`Buffer.Protocol.swift:22`) · `swift-buffer-linear-primitives` (`Buffer.Linear.swift:24`, `Buffer.Linear+Span.swift:14`) · `swift-buffer-arena-primitives` (`Buffer.Arena.swift:32`, `Buffer.Arena.Position.swift`) · `swift-buffer-aligned-primitives` (`Buffer.Aligned.swift:70`) · `swift-ownership-primitives` (`Ownership.swift:18-40`, `Ownership.Borrow.swift:72`, `Ownership.Inout.swift:49`) · `swift-array-primitives` (`Array.Inline.swift:30`, `Array.Static.swift:40-42`) · `swift-linear-primitives` (`Linear.Vector.swift:18-20`) · `swift-cpu-primitives` (`CPU.Atomic.swift`) · `swift-async-primitives` (`Async.Mutex.swift`).

**Institute skills/positions:** `memory-safety` ([MEM-SAFE-001/004/012/020/024/025b/c], [MEM-SPAN-001/002], [MEM-UNSAFE-004]) · `swift-institute` ([ARCH-LAYER-001/007/011]) · `primitives` ([PRIM-FOUND-001/004]) · `code-surface` ([API-NAME-001/002/003], [API-ERR-001], [API-IMPL-005]) · `byte-discipline` ([API-BYTE-001..007]) · `swift-institute-ecosystem` ([ECO-001/007]).

**Institute prior comparisons honored (not contradicted):** `canonical-buffer-discipline-cross-language-survey.md` (RECOMMENDATION) · `swift-safety-model-reference.md` (DECISION) · `memory-domain-cross-package-inventory.md` (DECISION) · `ecosystem-data-structures-inventory.md` (DECISION) · `swift-6.3-ecosystem-opportunities.md` (RECOMMENDATION) · `stdlib-naming-beats-ecosystem-naming.md` (IN_PROGRESS — unresolved).

---

## Appendix A — Confidence & gaps

**High confidence:** every comparative claim is anchored to Round-1 primary-source findings (apple side) and current-source `file:line` reads (Institute side); the pivotal/surprising claims — *no custom Institute Span*, *public-but-dormant `Memory.Allocator.Protocol`*, *generational-slotmap arena* — were grep-verified (zero-consumer confirmation) and one arena package built clean. The agents independently corrected three of this author's prompt premises (the ownership model is a 7-type contract matrix not a "5-axis lattice"; `swift-vector-primitives` is a functional generator not inline storage; `kernel-atomic` shipped as `CPU.Atomic`), which raises confidence in their rigor.

**Gaps:** no `swift test` run across the arena/pool/buffer suites (build-verified only for `swift-memory-arena-primitives`); Ring/Slab/Linked/Slots storage internals confirmed at type-signature level, not full file reads; per-platform (Linux/Windows) `Async.Mutex` branch behavior confirmed by `#if` reading only; the Institute's reserved internal docs named by the Round-1 hooks were read for *position* but several are stale (Appendix B).

## Appendix B — Doc-vs-code mismatches found (corpus-health signal)

Per [RES-013a]/[RES-023], Institute research docs were treated as leads; verification against code surfaced stale docs. These do **not** affect the code-verified comparison above, but are candidates for **reflections-processing / corpus-meta-analysis** triage:

1. `storage-primitives-comparative-analysis.md` (RECOMMENDATION) — stale on ≥3 load-bearing points: calls `Storage.Heap` "always Copyable / reference" (code: `~Copyable` value façade, conditionally Copyable); says "Storage Protocol REJECTED" (code: `__StorageProtocol` ships); marks `Storage.Arena`/`Pool` "planned" (both ship).
2. `memory-pool-arena-buffer-usage-analysis.md` (RECOMMENDATION) — recommends *removing* `Memory.Pool`/`Arena` on a "zero consumers" basis and says "Storage.Pool does NOT compose Memory.Pool"; code refutes both (Storage.Pool/Arena compose Memory.Pool/Arena; consumers exist). Central premise void. **[Superseded + archived to `_archived/` on 2026-05-31 per principal — banner added, do not act on its Option-C recommendation.]**
3. `storage-arena-architecture.md` (DECISION) — specifies `Storage.Arena` as `public final class`; code is a `~Copyable struct` value-façade over a private `Backing` class (composition decision held; shape drifted).
4. `kernel-atomic-memory-ordering.md` (DECISION) — names `Kernel.Atomic`/`swift-kernel-primitives` (absent); implementation shipped as `CPU.Atomic`/`swift-cpu-primitives`.
5. `async-mutex-rawlayout-inline-storage.md` (DEFERRED) — claims `Async.Mutex` "wraps a class"; stale (Darwin path uses `@_rawLayout`, committed 2026-05-12, after the doc).
6. `binary-buffer-primitives-architectural-review.md` (DECISION) — superseded by topology drift (`Buffer.Aligned`/`Unbounded` live in own packages; constraint is `Byte`, not `UInt8`).
7. `vector-primitives-role-and-dependency-analysis.md` (SUPERSEDED — correctly marked) — confirms `swift-vector-primitives` no longer holds fixed-size storage.
8. `comparative-buffer-primitives.md` (DECISION) — layering conclusion holds; module map predates the 8-way discipline extraction.
9. Dead `#if` branch: `Async.Mutex` Kernel fallback references `Kernel_Thread_Primitives` (package absent on disk).

*Item 2 was superseded + archived to `Research/_archived/` on 2026-05-31 per principal. The remaining items are not actioned here — route them to `/reflect-session` → `reflections-processing`, or a targeted `corpus-meta-analysis` pass, to re-status/refresh (would require principal sign-off per no-drift).*
