# Memory, Byte, and Bit — Domain Orthogonality and Bridge Decomposition

<!--
---
version: 1.0.0
last_updated: 2026-06-03
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
normative: true
applies_to:
  - swift-memory-primitives
  - swift-memory-arena-primitives
  - swift-memory-buffer-primitives
  - swift-memory-cursor-primitives
  - swift-memory-map-primitives
  - swift-memory-pool-primitives
  - swift-byte-primitives
  - swift-binary-primitives
  - swift-bit-primitives
  - swift-bit-index-primitives
  - swift-span-primitives (authorized 2026-06-03)
depends_on:
  - swift-institute/Research/cross-layer-capability-protocol-model.md
  - swift-institute/Research/binary-byte-namespace-domain-foundations.md
  - swift-institute/Research/nonescapable-support-memory-storage-buffer.md
  - swift-institute/Research/memory-storage-composition-feasibility.md
---
-->

> **Historical note (2026-06-23).** This document is the dated design record that
> recommended lifting the `span`-vending capability out of the Memory namespace. Two
> outcomes have since landed and are reflected in the body in past tense: (1) the
> capability was lifted into the namespace-neutral **`Span.Protocol`** (`swift-span-primitives`),
> retiring `Memory.ContiguousProtocol` / `__Memory_Contiguous_Borrowed_Protocol` as
> recommended; (2) the owned typed region `Memory.Contiguous<Element>` (the generic struct)
> was subsequently **dissolved into `Storage.Contiguous`** (the typed storage tier).
> Where the body discusses the pre-lift / pre-dissolution state it was reasoning about, it
> names the type as it then stood, paired with its successor.

## Context

The principal raised, in discussion with ChatGPT (2026-06-03):

> *"Memory and bit/byte shouldn't necessarily have a dependency on one another … a `memory-byte-primitives` (and perhaps a `memory-bit-primitives`) bridge package should be preferred. Memory is not necessarily tied to bit/byte (mostly is, but not ALWAYS), so the semantic model is wrong to tie them at memory-primitives."*

Steers that refined the pass:

1. **"Optimize decomposition (and composition via bridge packages)."**
2. **"Work bottom-up — don't reason *from* the higher packages; they refactor to fit the perfect foundation."** And: in `Memory.Shift`, **the `UInt8`/`FixedWidthInteger` form is vestigial; `Bit` is the intended one.**
3. A ChatGPT dialogue proposing to **decompose the then-`Memory.Contiguous.Protocol`** (the span-vending capability, since lifted to `Span.Protocol`) into orthogonal capability protocols (`Memory` · `Contiguous` · `Span` · `Span.Mutable`) composed with `&`, rather than a precomposed nested conjunction.
4. **"Ignore the [RES-018] gate — `Span.(Mutable.)Protocol` would be new"** (consistent with [ARCH-LAYER-008]: correctness, not consumer count, drives pre-1.0).

This doc composes with the **APPROVED `cross-layer-capability-protocol-model.md` (CLCPM, Tier 3)** and the **IMPLEMENTED `binary-byte-namespace-domain-foundations.md` (Tier 3)**. CLCPM established the capability-protocol *normal form* (minimal cores + orthogonal cross-cutting concerns, compose-don't-refine, bounded by the 0-`witness_method` specialization boundary). binary-byte established **Bit → Byte → Binary** as the representation axis, omitting Memory. This doc supplies the **orthogonal location/layout axis (Memory)** and resolves the memory↔byte/bit coupling — *applying CLCPM's own normal form one level deeper than CLCPM did*, to the `span`-vending capability itself.

### Trigger

[RES-001] Architecture choice. Whether — and how — the memory layer couples to the bit and byte domains is precedent-setting for the L1 dependency DAG. [RES-020] Tier 3.

### Constraints

- **[ARCH-LAYER-001/008]** Downward-only deps; correctness drives pre-1.0 (so [RES-018]'s consumer-count hurdle does not gate new capability primitives — principal-confirmed).
- **[SEM-DEP-006/008/009]** Essential vs incidental; orthogonal integrations / cross-cutting concerns are not baked into cores.
- **[MOD-DOMAIN]** One domain per package; each owns its vocabulary. **[API-NAME-002]** No compound identifiers (a precomposed mutable-span protocol nested under the region — the then-candidate `Memory.Contiguous.Mutable.Protocol`, rejected in favor of `Span.Mutable.Protocol` — is a compound identifier in a nested path).
- **[INFRA-*]** Reuse existing typed infrastructure before inventing (the fix is usually an import).
- **CLCPM v1.3.0** (APPROVED 2026-05-28) — governs the capability normal form; this doc refines its then-`Memory.Contiguous` (span-capability) disposition and must be reconciled into it, not contradicted.
- **`binary-byte-namespace-domain-foundations.md` v3.1.0** — governs Bit/Byte/Binary.

## Questions

- **Q1** — Is Memory tied to **bit** and to **byte**? Are the ties essential or incidental, and symmetric?
- **Q2** — Separate "byte/bit as a *unit/quantity*" from "as a *value type / capability*." What does the memory core actually require, and how typed?
- **Q3** — Is the then-`Memory.Contiguous.Protocol` `span`-vending capability really a *Memory* core, or a cross-cutting *Span* capability mis-located in the Memory namespace? (Answered: lifted out to `Span.Protocol`.)
- **Q4** — How is the memory↔byte coupling best removed: a bridge package, or lifting the capability out of the Memory namespace?
- **Q5** — Is a `swift-memory-bit-primitives` bridge justified?
- **Q6** — Optimal bottom-up decomposition, reconciled with CLCPM.

## Internal Research Survey [per [RES-019]]

| Document | Status | Bearing |
|---|---|---|
| **`cross-layer-capability-protocol-model.md` v1.3.0** | **APPROVED (Tier 3)** | **GOVERNS.** The four-layer normal form (Memory→Storage→Buffer→Collection; minimal cores + orthogonal concerns; compose-don't-refine; specialization boundary). Disposes the span capability (then `Memory.Contiguous.Protocol`, since lifted to `Span.Protocol`) = EXTEND (single primitive `span`). **Crucially, §3.4 already has Storage *provide* `span`** ("`where Self: …` default supplying that capability's `.span` from `pointer(at:.zero)`+`capacity`") — i.e. span is *already* treated as composable across cores, not Memory's exclusive property. This doc completes that logic. |
| `binary-byte-namespace-domain-foundations.md` v3.1.0 | IMPLEMENTED (Tier 3) | Bit→Byte→Binary representation axis; Memory omitted (the orthogonal axis this doc adds). |
| `nonescapable-support-memory-storage-buffer.md` | — | The owned-vs-borrowed `~Escapable` span lifetime split across memory/storage/buffer — the constraint that forces two span protocols. |
| `memory-storage-composition-feasibility.md` v1.0.0 | RECOMMENDATION | Raw/typed split; Memory as the raw-region layer. |

**Internal research governs** per [RES-019]. This doc *refines* CLCPM's then-`Memory.Contiguous` (span-capability) disposition; the refinement must be folded back into CLCPM (§Recommendation).

## Empirical State Verification [per [RES-023]]

All verified against current source on 2026-06-03. The bit, byte, and memory domains are each L1 **families** (bit = 7 pkgs incl. `bit-index`/`bit-pack`/`bit-vector`; byte = 5; memory = 10; plus `storage`/`buffer`/`collection`/`range`/`interval` primitives — `swift-span-primitives` does **not** yet exist).

### The byte coupling is a *mis-named cross-cutting span capability*, already shared by three domains

The span-vending protocols **as they then stood** (in `swift-memory-primitives/Sources/Memory Contiguous Primitives/`, before the lift to `Span.Protocol` in `swift-span-primitives`) — retained verbatim as the empirical evidence the lift was reasoning about:

```swift
// Memory.ContiguousProtocol.swift:77 — OWNED (Escapable Self; borrows self, _overrideLifetime)
public protocol ContiguousProtocol: ~Copyable { associatedtype Element: ~Copyable
    var span: Span<Element> { get } }                                   // single requirement

// __Memory_Contiguous_Borrowed_Protocol.swift:41 — BORROWED (~Escapable Self; holds the span)
public protocol __Memory_Contiguous_Borrowed_Protocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    var span: Swift.Span<Element> { @_lifetime(copy self) get } }
```

The borrowed protocol's own header (`:20-35`) is decisive on two points:

1. **It already had three conformers from three domains** — *"the Memory-region borrowed view itself (then `Memory.Contiguous.Borrowed`); `Byte.Borrowed` from swift-byte-primitives (Element = Byte); `Binary.Borrowed` from swift-binary-primitives (Element = Byte)."* The capability "vends a borrowed `Span`" was therefore **already cross-domain**. Naming the protocol `Memory.Contiguous.Borrowed.Protocol` (since lifted to `Span.Borrowed.Protocol`) was the *sole* reason `Byte.Borrowed` and `Binary.Borrowed` carried a conformance to a **Memory**-namespaced protocol. That naming **was** the coupling.
2. **Owned and borrowed cannot be one protocol** — *"the witness-table contract for `var span` differs across the two lifetime regimes"* (owned borrows self + `_overrideLifetime`; borrowed *is* `~Escapable`, scope IS the lifetime). The `__`-mangled name is a sibling-resolution workaround ([feedback_sibling_type_resolution]).

So the `span`-vending capability was **a cross-cutting capability misfiled under `Memory.Contiguous`** (now the namespace-neutral `Span.Protocol`), exactly the "core/cross-cutting-concern conflation" CLCPM names as the root incoherence — and the generic struct itself (then `Memory.Contiguous<Element>`, since dissolved into `Storage.Contiguous`) is byte-agnostic; only this protocol's *name* tied byte→memory.

### The bit coupling is essential and under-typed (not vestigial)

`Memory.Shift` *is a count of bit positions* (power-of-2 exponent; `Memory.Shift.swift:1-8`), stored as `rawValue: UInt8` (`:34`) — the untyped legacy. `Memory.Alignment` wraps it; `Memory.Allocation` consumes Alignment. The bit domain already ships the typed quantity: **`Bit.Index = Index<Bit> = Tagged<Bit, Ordinal>`** (`swift-bit-index-primitives/.../Bit.Index.swift:26`), with `Bit.Index.Count` used as a first-class quantity in `swift-bit-pack-primitives` (`Bit.Pack.Location.swift:94`). So `memory → bit` is **essential** (alignment is denominated in bit-positions); the fix is to *type* it, and to aim the dep at `bit-index-primitives` (where the quantity lives), not the bare `Bit` atom (`Package.swift:63,117`).

### The genuine memory⊗bit-vector join is already a sibling

`Memory.Pool._allocationBits: Bit.Vector` (`swift-memory-pool-primitives/.../Memory.Pool.swift:101`) — a slot-allocation bitmap. Correctly its own package on `bit-vector`.

## Prior Art Survey [per [RES-021]]

Verified primary sources (parallel subagents, [RES-020]/[RES-032]); CLCPM §9 additionally surveys the capability-protocol question cross-language.

- **Memory layout is universally decoupled from a byte *value-type*.** Rust `core::mem`/`alloc` use `usize` byte-*counts* (`size_of`, `Layout`); `core::ptr` is generic; `bytes`/`bitvec` are separate crates. Swift `MemoryLayout.size/stride/alignment` are `Int` byte-counts; SE-0107 splits raw(untyped, byte-granular)/typed; raw byte = `UInt8`, no nominal `Byte`. Reynolds (LICS 2002): `Heap = Address ⇀ Value`, addresses and values are **separate sorts**; CompCert: location = `(block, byte-offset)`, distinct from `val`. [Verified: 2026-06-03]
- **"vending a contiguous view" as a *capability*, not a namespace.** Rust `AsRef<[T]>`/`Deref<Target=[T]>`, C++ `std::span`/`contiguous_range`, Swift `ContiguousBytes` / `withContiguousStorageIfAvailable` — all express "I can produce a contiguous view" as a *capability* a type conforms to, never tied to a "Memory" namespace. This is the cross-language warrant for `Span.Protocol`.
- **The byte *unit* is contingent.** `CHAR_BIT ≥ 8` (ISO C/C++; POSIX pins 8); word/bit-addressable hardware exists (PDP-10, TI C28x, 8051). `std::byte` (C++17) is a distinct raw-storage type — confirms the institute's `Byte`≠`UInt8` split — yet `sizeof`/`Layout` don't depend on it.
- **Bit axis — stricter than prior art.** Mainstream types shift amounts as **bare integers**; the institute's bit-*typing* of the exponent (`Bit.Index.Count`) is a deliberate typed-primitives divergence, not a prior-art norm.

**Contextualization [per [RES-021]]:** the dominant pattern decouples layout/quantity from any byte value-type, and treats "vends a contiguous view" as a capability. The institute is already on this side for `Address`/`Count`/`Alignment`; the lone deviations were (a) the span capability then misfiled under `Memory.Contiguous` (since lifted to `Span.Protocol`), and (b) the untyped `UInt8` shift.

## Theoretical Grounding / Formal Semantics [per [RES-024]]

### Two orthogonal axes; span is a third, cross-cutting capability

```
  REPRESENTATION AXIS (what)        LOCATION/LAYOUT AXIS (where)        CROSS-CUTTING CAPABILITY
  Bit → Byte → Binary               Memory.Address / Alignment /        Span.Protocol (vend Span)
  (binary-byte doc)                 Allocation / Contiguous / Inline    Span.Mutable.Protocol
                                    (this doc)                          — composed OVER cores
```

Following Reynolds, `H : Address ⇀ Value`; the memory core is the algebra of `dom(H)`, parametric in `Value`. Per CLCPM's normal form, **a capability core declares only its irreducible primitives; derived families (iteration, algebra, …) attach orthogonally via `where Self: Core & Concern`.** This doc adds: **"vends a `Span`" is such a cross-cutting capability** — an owned typed region vends one (then `Memory.Contiguous`, now `Storage.Contiguous`), a contiguous `Storage` vends one (CLCPM §3.4), a `Byte.Borrowed`/`Binary.Borrowed` vends one — so it belongs to a namespace-neutral `Span.Protocol`, composed over each core, **not** baked into (or named after) the Memory core.

### Q2 — three notions, three typings

| Notion | Correct typing | Depends on |
|---|---|---|
| byte-as-**unit** (address granularity) | `Memory.Address.Offset/.Count` = `Tagged<Memory, …>` | nothing (no byte/bit pkg) |
| bit-position-**count** (shift/alignment exponent) | `Bit.Index.Count` = `Tagged<Bit, Cardinal>` | `bit-index-primitives` (essential) |
| **span**-vending (contiguous view capability) | `Span.Protocol` / `Span.Borrowed.Protocol` / `Span.Mutable.Protocol` | `span-primitives` (a capability, not Memory) |

The `Byte` *value-type* never enters the memory core: byte appears only as the `Element` of a `Span`-capability conformance, which is namespace-neutral.

### The owned/borrowed lifetime regimes (forces two span protocols)

`Swift.Span` is `~Escapable`. A conformer either **computes** a span borrowing `self` (owned, Escapable Self, `@_lifetime(borrow self)` + `_overrideLifetime`) or **is** the borrow (`~Escapable` Self, `@_lifetime(copy self)`). The current code proves a single protocol cannot express both (witness-table contracts differ). So the lift preserves the split:

- `Span.Protocol: ~Copyable` — owned/Escapable; `var span: Span<Element> { @_lifetime(borrow self) get }`.
- `Span.Borrowed.Protocol: ~Copyable, ~Escapable` — `var span: Span<Element> { @_lifetime(copy self) get }`.
- `Span.Mutable.Protocol: Span.Protocol` — adds `var mutableSpan: MutableSpan<Element> { mutating get }` (refine, not a precomposed region-nested mutable protocol — the rejected then-form `Memory.Contiguous.Mutable`).

### Soundness

Renaming the protocol does not change witnesses (`Byte.Borrowed`/`Binary.Borrowed`/the Memory-region borrowed view, then `Memory.Contiguous.Borrowed`, already implement `var span`). Each domain hosts its own conformance to the shared `Span` capability (downward dep on `span-primitives`); no `@retroactive`, no orphan instances. Re-typing the shift onto `Bit.Index.Count` is range-preserving (`0…63`/`< Carrier.bitWidth` invariant over a typed quantity).

## Analysis & Options

### Q3/Q4 — bridge vs lift

The earlier draft of this doc recommended a **`swift-memory-byte-primitives` bridge** to *relocate* `Byte.Borrowed`'s conformance to the then-Memory-named borrowed-span protocol (`Memory.Contiguous<Byte>.Borrowed.Protocol`, since lifted to `Span.Borrowed.Protocol`). That was **superseded**: the conformance referenced a *Memory-named* protocol, so a bridge relocates the coupling without removing it — and it does nothing for `Binary.Borrowed`. **Lifting the capability out of the Memory namespace removes the coupling's cause** and fixes byte *and* binary *and* retires the `__`-mangled workaround.

| Option | Verdict | Why |
|---|---|---|
| **A — status quo** | REJECT | span capability then misfiled under `Memory.Contiguous` (byte/binary→memory naming coupling); untyped `UInt8` shift; bit dep aimed at the atom. |
| **B — `memory-byte-primitives` bridge** (earlier rec) | SUPERSEDED | relocates the byte↔memory conformance; doesn't fix binary; capability still Memory-named. Strictly weaker than C. |
| **C — lift `span` to a `Span` capability** *(RECOMMENDED)* | ADOPT | new `swift-span-primitives` owns `Span.Protocol` (owned) + `Span.Borrowed.Protocol` (~Escapable) + `Span.Mutable.Protocol` (refine). The owned typed region and its borrowed view (then `Memory.Contiguous(.Borrowed)`, now `Storage.Contiguous`), `Byte.Borrowed`, `Binary.Borrowed` each conform to the namespace-neutral capability. **No memory↔byte/binary edge remains.** Cursor generalizes to `where DomainTag.Borrowed: Span.Borrowed.Protocol, …Element == Byte`. [RES-018] waived. |
| **D — `memory-bit-primitives` bridge** | REJECT | memory↔bit is essential denomination, not a join; the only memory⊗bit join (pool bitmap) is already a sibling. Fix = type the shift via `bit-index`. |
| **E — `Contiguous.Protocol` topology split + `Contiguous.Run`** | HOLD (separate) | Splitting *topology* (one run) from *capability* (vends span) is defensible (CLCPM already gates span to "contiguous disciplines" informally) — but it is **not needed to dissolve the byte coupling** (C does that), and **`Contiguous.Run` must not be invented**: reuse `swift-interval-primitives`/`swift-range-primitives` ([INFRA]). Pursue only if a real contiguous-but-not-span conformer is named. |
| **F — `Memory.Protocol` bare marker** | REJECT | ChatGPT's `Memory.Protocol` has an associated type and *no operation* — vacuous once `span` lifts out. "Memory" is a namespace/domain, not a contentless protocol. |
| **G — parameterize the addressable unit** | REJECT | Swift targets only 8-bit-byte platforms; generality for zero benefit. |

### Reconciliation with CLCPM (mandatory)

CLCPM (APPROVED) dispositions the span capability (then `Memory.Contiguous.Protocol`, since lifted to `Span.Protocol`) as **EXTEND — no change to requirements**, treating `span` as the Memory core's single primitive. Option C **refines that**: it lifts `span` into a cross-cutting `Span` capability — which is the *same* "don't bake a cross-cutting concern into a core" move CLCPM applies to Set's algebra and to iteration, and which CLCPM half-anticipates by having Storage *provide* `span` (§3.4). Because CLCPM is **unexecuted** and the principal **opened the whole stack**, this is in-scope, but it MUST be folded back into CLCPM as an amendment (the capability normal form is CLCPM's to own); this doc owns only the *consequence* (the memory↔byte/binary decoupling).

## Recommendation

**Status: RECOMMENDATION** (class-(c); principal decides; **no package edits made — research only**). **Execution isolation (principal, 2026-06-03): all implementation proceeds in isolated git worktrees via separate agents, so it cannot interfere with ongoing work** (notably the `swift-memory-primitives--msb` checkout and any parallel sessions); nothing is edited in the live package trees from this chat. One coherent bottom-up plan:

1. **Span axis — lift the capability (dissolves byte↔memory & binary↔memory).** Create **`swift-span-primitives`** (**AUTHORIZED 2026-06-03**; a low-tier capability package over `Swift.Span`/`MutableSpan`/…, authored via a *separate dispatch* — not this chat): `Span.Protocol` (owned), `Span.Borrowed.Protocol` (~Escapable), `Span.Mutable.Protocol` (refines `Span.Protocol`); `Span.Raw[.Mutable]` / `Span.Output[.Raw]` per the same shape. Retire `Memory.ContiguousProtocol` / `__Memory_Contiguous_Borrowed_Protocol` in favor of these (the owned typed region kept its struct, then *conforming* to `Span.Protocol` — and was itself subsequently dissolved into `Storage.Contiguous`). `Byte.Borrowed`, `Binary.Borrowed`, and the Memory-region borrowed view (then `Memory.Contiguous.Borrowed`) each conform to `Span.Borrowed.Protocol`. Cursor ops constrain on `Span.Borrowed.Protocol`. **No memory↔byte/binary edge survives.**
2. **Bit axis — type the essential dependency (DECIDED).** The shift/alignment exponent is semantically an **unsigned count of bit positions** → `Tagged<Bit, Cardinal>` = **`Bit.Index.Count`** (*reuse*). Rationale: it is a *count/magnitude* (how many positions to shift; how many doublings), not `Ordinal` (a single addressed position) and not `Affine.Discrete.Vector` (a *signed* displacement — a shift is unsigned). Re-type `Memory.Shift`'s storage `rawValue: UInt8 → Bit.Index.Count`, preserving the `0…63` / `< Carrier.bitWidth` validation as construction logic; repoint the core's Shift/Alignment dep `bit-primitives → bit-index-primitives`. Do **not** mint a new `Bit.Exponent`/`Bit.Shift` *tagged* type — `Bit.Index.Count` is the correct existing shape ([INFRA] reuse, per principal). Deepest bottom-up form (optional): keep `Memory.Shift` / a bit-family `Bit.Shift` only as a *named validated wrapper* over `Bit.Index.Count` carrying the magnitude/mask ops, reused by `Memory.Alignment` and `Binary.Mask`.
3. **No `memory-bit` bridge; no `memory-byte` bridge.** The span lift removes the byte join; the pool already owns the bit-vector join.
4. **Compose, don't precompose.** Express requirements as `M: Memory.* & Span.Mutable.Protocol` etc., never a nested region-mutable-protocol conjunction (the rejected then-form `Memory.Contiguous.Mutable.Protocol`) ([API-NAME-002]).
5. **Reconcile into CLCPM** as a §3.4 amendment (span = cross-cutting capability); coordinate sequencing with CLCPM's set-layer execution. Consumers (cursor/buffer/binary) refactor to the lifted capability — expected, bottom-up.

**Outcome.** The memory core is the byte/bit-value-type-free algebra of addressing/alignment/allocation, denominated in `Memory`-tagged byte quantities and `Bit`-tagged exponents; "vends a span" is a namespace-neutral `Span` capability that memory, byte, and binary each conform to independently. The original goal — *memory and byte not depending on one another* — is met **at the root** (the capability is no longer Memory-named), not by a bridge.

### Dispositions and open sub-decisions

- **`.Borrowed` proliferation (RESOLVED — prune; revises the prior "keep nominal").** Two governing DECISIONs answer "must each type have a `.Borrowed`?" — **no.** `ownership-borrow-protocol-unification.md` (DECISION, 2026-04-22, IMPLEMENTED) makes **`Ownership.Borrow<T>` the generic default** (associated type `Borrowed = Ownership.Borrow<Self>`) and reserves a nominal `.Borrowed` for **Case B only: interior storage AND a type-level invariant** (Case A scalars and Case C `Tagged` forwarding get the generic free). `view-vs-span-borrowed-access-types.md` (DECISION, 2026-02-28) makes the invariant precise — a borrowed view is irreducible vs `Span` *only* when it carries a guarantee `Span` cannot (`Path`/`String` **null-termination**, for C-interop + non-owned syscall pointers); its hierarchy states **"View minus its guarantee = Span."** Applying both: **`Byte.Borrowed`, `Binary.Borrowed`, and the Memory-region borrowed view (then `Memory.Contiguous.Borrowed`) carried NO invariant** — each is a bare `Swift.Span<Element>` + `count` + `init` (`Byte.Borrowed.swift:63-88`; the Memory-region borrowed view's `_span` + `@safe`; `Binary.Borrowed.swift:48` explicitly "adds no borrowed-shape invariants") — and were added *after* the 2026-04-22 DECISION, **drifting from its Case-B bar**. → **Collapse them to `Swift.Span<Element>` surfaced via the lifted `Span.Borrowed.Protocol`** (no nominal); domain operations attach via `extension Span.Borrowed.Protocol where Element == X`, covering every byte-span uniformly. **Keep nominal only `Path.Borrowed` / `String.Borrowed`** (genuine Case B — null-termination). Net: the nominal `.Borrowed` set prunes **6 → 2**, and there is **no `byte-borrow-primitives` bridge**. *(This revises last turn's "keep `Byte.Borrowed` nominal for consistency" — the invariant criterion governs; consistency does not. If `Binary`/`Byte` later grow a real borrowed-shape invariant, a nominal `.Borrowed` is re-introducible per-type at that point — the prune is reversible.)*
- **"Borrow<*> at use sites" — yes, by shape.** Scalar borrows → the generic **`Ownership.Borrow<T>`** (Case A default); contiguous-region borrows → **`Swift.Span<Element>`** surfaced via `Span.Borrowed.Protocol`. A per-type nominal is reserved for an actual type-level invariant only. **Mechanism to verify in the span spike**: `Byte`/`Binary`'s `Ownership.Borrow.Protocol.Borrowed` becomes `Span<Element>` (overriding the scalar `Ownership.Borrow<Self>` default), `Span<Element>` conforms `Span.Borrowed.Protocol` (identity), and `Cursor<DomainTag>` operates over the capability — sound in principle (Span is `~Copyable & ~Escapable`; the cursor already targets the borrowed-span capability), but confirm the `Borrowed`-override resolves and stays 0-`witness_method`.
- **`swift-span-primitives` (AUTHORIZED 2026-06-03).** Authored via a **separate dispatch**, not this chat. Open: ship `Span.Raw`/`Span.Output` now or later; final naming.
- **Bit exponent (DECIDED): `Bit.Index.Count` = `Tagged<Bit, Cardinal>`** (reuse). Open only: also lift a named `Bit.Shift` validated wrapper into the bit family (deepest form) vs re-type `Memory.Shift` in place.
- **CLCPM §3.4 amendment (DONE).** Folded into `cross-layer-capability-protocol-model.md` as §12 / v1.4.0 (2026-06-03); awaits supervisor re-approval (it refines an APPROVED disposition).
- **Option E** (Contiguous-topology split): defer unless a real non-span contiguous conformer is named; reuse `interval`/`range`, never `Contiguous.Run`.
- **`--msb` coordination**: the `swift-memory-primitives--msb` checkout (active 2026-06-03 13:23) may touch `Memory.Shift`; coordinate before the bit re-typing.
### Span-primitives capability spike (scope — span lift + `.Borrowed` prune folded in)

A single `/tmp` capability prototype (two modules for cross-module SIL, `-O`, reduced stand-ins per CLCPM §6 / [EXP-004]: `Element == UInt8`/`Int`, a minimal `Cursor`, a stand-in `Ownership.Borrow.Protocol`) — proves the compiler capability *before* any production build; touches **no live package** (so it is isolated by construction; the worktree discipline applies to the production build that follows, which must coordinate with `--msb`). Executed by a **separate agent**, not this chat. Hypotheses (each PASS/FAIL):

- **H1 — capability lattice compiles** with the structural owned/borrowed split: `Span.Protocol` (owned/Escapable, `var span: Span<E> { @_lifetime(borrow self) get }`), `Span.Borrowed.Protocol` (`~Escapable`, `@_lifetime(copy self)`), `Span.Mutable.Protocol: Span.Protocol` (`mutableSpan`). (Use the `__`-hoist only if SE-0404 nesting fails.)
- **H2 — `Swift.Span<E>: Span.Borrowed.Protocol`** (identity: `var span { self }`). *The linchpin of the prune* — without it, region-views can't simply BE `Span`.
- **H3 — prune mechanism**: a scalar domain tag's `Ownership.Borrow.Protocol.Borrowed = Span<E>` (overriding the `Ownership.Borrow<Self>` default), with **no nominal `.Borrowed`**, and `Cursor<Tag>` derives `Span<E>` as its storage.
- **H4 — owned conformer**: an owned-region-shaped struct (then `Memory.Contiguous`, now `Storage.Contiguous`) conforms `Span.Protocol` (computes span borrowing self).
- **H5 — invariant-bearing nominal coexists**: a `Path`-shaped stand-in keeps a *nominal* `Borrowed` (null-termination stand-in) AND conforms `Span.Borrowed.Protocol` — proving keep-nominal (Case B) and prune (invariant-free) coexist under one capability.
- **H6 — 0-`witness_method` (HARD gate)**: `Cursor` peek/advance/consume over `where DomainTag.Borrowed: Span.Borrowed.Protocol, …Element == UInt8` specializes to **0 `witness_method`**, release, cross-module (replicate the `storage-protocol-specialization` / CLCPM §6 harness).
- **H7 — domain ops on the capability**: `extension Span.Borrowed.Protocol where Element == UInt8 { … }` attaches and is callable on a bare `Span<UInt8>` (proving domain ops need no nominal carrier).

**Pass = all of H1–H7** (esp. H2/H3/H6). Any FAIL ⇒ a mechanism gap in the lift or prune — report it, don't force. **Out of scope:** `Span.Raw`/`Span.Output`; production package authoring; the bit-axis `Bit.Index.Count` re-typing (separate worktree step); any live-package edit. On PASS, the production build (real `swift-span-primitives` + reconform/prune + `Shift` re-typing) proceeds as worktree-isolated separate agents, coordinated with `--msb`, after CLCPM §12 re-approval.

## What this closes

- **Q1**: essentially tied to **bit** (alignment = bit-position counts); **not** tied to the **byte value-type** (the only byte edge was a mis-named span-capability conformance). Asymmetric.
- **Q2**: core needs byte-as-unit (Memory-tagged) + bit-position-count (Bit-tagged); not the `Byte` type.
- **Q3**: the `span` capability is cross-cutting, was mis-located in `Memory.Contiguous` (since lifted to `Span.Protocol`).
- **Q4**: **lift** the capability to a namespace-neutral `Span` capability (supersedes the bridge); dissolves byte *and* binary coupling.
- **Q5**: no `memory-bit` bridge.
- **Q6**: families + a `Span` capability package + bit-index-typed alignment; reconciled into CLCPM.

## What this opens

- **CLCPM §3.4 amendment**: `span` as a cross-cutting `Span` capability (owned/borrowed/mutable), composed over Memory/Storage/Buffer cores; `Storage`'s span-provision (§3.4) becomes a `Span.Protocol` conformance.
- **`swift-span-primitives`** authoring (Span/Borrowed/Mutable/Raw/Output capability lattice).
- **Skill promotion**: two-axis model (location ⊥ representation; quantity-typed-by-its-domain; capabilities namespace-neutral) — candidate `[ARCH-LAYER-*]`/`[SEM-DEP-*]` companion to the Bit/Byte/Binary model and CLCPM's normal form.
- **README correction** for `swift-memory-primitives` (overstates the byte tie; mislabels the bit tie).

## References

- **Internal (governs):** `cross-layer-capability-protocol-model.md` v1.3.0 (APPROVED, Tier 3); `binary-byte-namespace-domain-foundations.md` v3.1.0 (IMPLEMENTED, Tier 3); `nonescapable-support-memory-storage-buffer.md`; `memory-storage-composition-feasibility.md` v1.0.0.
- **Source (as cited 2026-06-03, pre-lift):** the span-vending protocols then at `Memory.ContiguousProtocol.swift:77` / `__Memory_Contiguous_Borrowed_Protocol.swift:20-56` (since lifted to `Span.Protocol` in `swift-span-primitives`), `Memory.Contiguous+Byte.Borrowed.swift:32`, `Memory.Shift.swift:34`; `swift-bit-index-primitives/.../Bit.Index.swift:26`, `swift-bit-pack-primitives/.../Bit.Pack.Location.swift:94`; `swift-memory-pool-primitives/.../Memory.Pool.swift:101`; `swift-binary-primitives/.../Binary.Borrowed.swift:123`; existing `swift-interval-primitives` / `swift-range-primitives`.
- **Skills:** [ARCH-LAYER-001/006/008]; [SEM-DEP-006/008/009]; [MOD-DOMAIN]; [API-NAME-002]; [INFRA-*]; [RES-018/019/020/021/022/023/024/025/029].
- **External [Verified: 2026-06-03]:** Rust [core::mem](https://doc.rust-lang.org/core/mem/fn.size_of.html)/[Layout](https://doc.rust-lang.org/core/alloc/struct.Layout.html)/[AsRef], C++ [std::span](https://eel.is/c++draft/views.span)/[contiguous_range], Swift [SE-0107](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0107-unsaferawpointer.md)/[ContiguousBytes], Reynolds *Separation Logic* (LICS 2002), [C++ std::byte](https://eel.is/c++draft/cstddef.syn), [Word-addressable](https://en.wikipedia.org/wiki/Word-addressable).

## Changelog

- **v1.0.0** (2026-06-03): Initial RECOMMENDATION. Tier 3, ecosystem-wide. Memory (location axis) ⊥ Bit/Byte/Binary (representation axis), with an **asymmetry**: memory↔**bit** is essential denomination (alignment = bit-position counts; type `Memory.Shift` onto `Bit.Index.Count`, repoint to `bit-index-primitives`), memory↔**byte** is *not* a real tie — the only byte edge is the `span`-vending capability **mis-named** `Memory.Contiguous.Borrowed.Protocol` (since lifted to `Span.Borrowed.Protocol`), which already had three cross-domain conformers (the Memory-region borrowed view — then `Memory.Contiguous.Borrowed` — plus `Byte.Borrowed`, `Binary.Borrowed`). **Recommends lifting `span` into a namespace-neutral `swift-span-primitives` capability** (`Span.Protocol` owned / `Span.Borrowed.Protocol` ~Escapable / `Span.Mutable.Protocol` refine — the owned/borrowed split is structural, witness-table contracts differ), which **dissolves the byte & binary coupling at the root** and supersedes the earlier `memory-byte-primitives` bridge. Rejects `memory-bit-primitives` (pool already owns the bit-vector join), `Memory.Protocol` (vacuous marker), inventing `Contiguous.Run` (reuse interval/range). Holds the Contiguous-topology split (Option E) as separate/optional. Reconciles with — and proposes a §3.4 amendment to — the APPROVED CLCPM (capability normal form). [RES-018] waived per principal. Bottom-up; consumers refactor. Research only; no package edits. Caveat: `swift-memory-primitives--msb` checkout active 2026-06-03 13:23.
