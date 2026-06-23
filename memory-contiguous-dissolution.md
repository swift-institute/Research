# Memory.Contiguous Dissolution — completing the element-free Memory tier

<!--
---
version: 1.1.0
last_updated: 2026-06-23
status: DECISION (principal intent stated in-session 2026-06-23; recorded per F4b)
tier: 3
scope: ecosystem-wide
records: tower-layering-status-quo-2026-06-22.md §F4 (F4a type-smell + F4b unrecorded-plan)
supersedes_in_part:
  - owned-typed-memory-region-abstraction.md   # flips its DECISION:create → DISSOLVED
updates_pending:
  - "[DS-006]"                                  # ecosystem-data-structures: stops citing Memory.Contiguous as canonical
  - REPORT-layering-harvest-ledger.md           # drop Memory.Contiguous<Memory.X> from the converged core
  - "code-surface, modularization, memory-safety" # skill cites of Memory.Contiguous as current/model
decoupled_from:
  - .handoffs/HANDOFF-memory-tier-cleanup.md    # the Tracked+Unique arc (F1/F2/F3); shares the swift-memory-primitives tree — must NOT run concurrently
---
-->

## Decision

`Memory.Contiguous<Element: BitwiseCopyable>` is **removed**. It is the last typed, counted,
`Span`-vending type stranded on the Memory floor after the element-free leaf refactor
(`tower-layering-status-quo-2026-06-22.md` F4a; `Memory.Contiguous.swift:72`). Its three jobs
split across layers that already exist; the type then deletes. This note records the principal's
in-session removal intent so the corpus stops contradicting it (F4b) — **record first, migrate
later**, gated on the allocator redesign settling.

This is the third and largest piece of the same element-free Memory-tier cleanup whose first two
pieces (`Memory.Tracked.Protocol`, `Memory.Unique.Protocol` → F1/F2/F3) live in the **separate**
`HANDOFF-memory-tier-cleanup.md` arc. The two arcs edit the same package (`swift-memory-primitives`)
and therefore must be **serialized, never run concurrently** (`[feedback_no_duplicate_dispatch_shared_tree]`).

## The three-jobs split (destinations all already exist)

| Job `Memory.Contiguous` does today | Where it goes | Authority |
|---|---|---|
| Owns raw bytes — the **provenance-carrying pointer**, freed on `deinit` (`Memory.Contiguous.swift:76,119`) | **merge into `Memory.Heap`** (the concrete heap region; de-type `UnsafePointer<Element>` → `UnsafeMutableRawPointer`) | `[MEM-SAFE-029]` (cached base lawful behind a concrete heap-pinned path) |
| Typed + `count` + owned typed view | **`Storage.Contiguous`** (the typed tier) | `[MOD-PLACE]`, `[DS-006]` |
| Borrowed **read** view (`span`) (`Memory.Contiguous+Span.Protocol.swift:26,33`) | **bare `Swift.Span`** (no nominal at this layer) | the orthogonality decision (`Memory.Contiguous.swift:68-71`); `[MEM-SAFE-030]` |
| Address as a **value** (describe/compare) | **`Memory.Address`** seam — derived per access in generic code | `[MEM-SAFE-029]` |
| Adopt the region as one allocation | **`Memory.Allocator`** (adopts a `Memory.Region`) | `Memory.Allocator.swift:37-46` |

`Memory.Heap` and `Memory.Contiguous` are today redundant (`Heap` *wraps* `Memory.Contiguous<Byte>`,
`Memory.Heap.swift:33`); the dissolution **merges** Contiguous's owned-pointer core into `Heap` and
**lifts** its typed veneer to `Storage.Contiguous`. The `<Element>` + `count` + `Span`-member
veneer is the only part deleted; the owned-pointer mechanism is load-bearing and survives.

## Provenance is load-bearing — the owner keeps the real pointer (corpus law, not a new finding)

`Memory.Heap` MUST store the **real, provenance-carrying pointer** and free through it; `Memory.Address`
is a *derived seam value only* (`Tagged<Memory, Ordinal>` — an integer; `Memory.Heap ~Copyable.swift:39`
already records "the integer-address model carries no provenance"). This is already canon:

- **`[MEM-SAFE-029]`** — generic code derives addresses per-access through the seam; a **cached base
  pointer is lawful only behind a concrete heap-pinned path** (which `Memory.Heap` is).
- **`[MEM-OWN-015]`** — no raw extraction / **reconstruction across boundaries**.
- **`[MEM-SAFE-025a]`** — the one confined `unsafe` carries a `// SAFETY:` invariant comment.

The tempting regression — store `base: Memory.Address` and **reconstitute** a pointer in `deinit`
to free — is **forbidden** by both `[MEM-SAFE-029]` (it moves the cached base out of the concrete
heap path) and `[MEM-OWN-015]` (reconstruction): the reconstituted pointer has no provenance, so the
optimizer may assume non-aliasing (mis-compiles), `deallocate` is no longer guaranteed to act on the
origin allocation, and PAC/MTE metadata is stripped (forgeable / faulting). Keep the origin pointer.

## Two unsafe surfaces on the leaf — keep them separate (SE-0465 upgrade path)

The leaf's `unsafe` is **two distinct surfaces**; conflating them obscures the upgrade path:

- **(a) Permanent floor — `allocate`/`deallocate` + the cached base pointer.** Irreducible: Swift
  has no safe stable-base *runtime* raw allocator (`Memory.Inline` is `unsafe`-free only via
  compile-time `@_rawLayout`). Confined + marked in `Memory.Heap` per `[MEM-SAFE-029]`/`[MEM-SAFE-025a]`.
  **SE-0465 does not remove this** — alloc/free are intrinsically pointer ops.
- **(b) SE-0465-gated — read-`Span` vending.** Today on `Memory.Contiguous` (`+Span.Protocol`),
  rides `Span.Protocol` per `[MEM-SAFE-030]`/`[MEM-SAFE-012]`; after dissolution it lives on
  `Storage.Contiguous` / bare `Swift.Span`. **This** is the surface the "zero-`unsafe` leaf" goal
  targets and the one SE-0465 upgrades.

The general two-surface rule (which the memory-safety skill does **not** yet state — SE-0465 appears
nowhere in it) is proposed as a skill amendment; this note records only its application to this arc.

## Reconciliation with the orthogonality decision (and why it is NOT F4b's record)

`Memory.Contiguous.swift:68-71` already records an "orthogonality decision": the invariant-free
*borrowed*-contiguous nominal was pruned (a borrowed contiguous view is a bare `Swift.Span`;
keep-nominal is reserved for `Path`/`String`). The dissolution **composes with** that — it reuses
exactly that borrowed-side destination (bare `Swift.Span`) for the read view.

But that decision governs only the **borrowed** side; it does not remove the **owned** form
(`Memory.Contiguous` the type). So it is **not** the recorded rationale F4b is asking for — F4b wants
the *owned-form removal* decision, the destinations, the sequence, and the blast radius. **This note
is that record.**

## Blast radius

~8 direct `swift-primitives` consumers / ~15 ecosystem-wide (`.build-tsan/checkouts/…` matches are
build artifacts, not consumers — excluded):

- **Heavy (own-storage → `Storage.Contiguous`):** `swift-binary-primitives` (`Binary._storage:
  Memory.Contiguous<Byte>`, `Binary.swift:85`), `swift-string-primitives`, `swift-path-primitives`
  (both `Memory.Contiguous<Char>`).
- **Light (conformance / seam refs → `Swift.Span` or unaffected):** `swift-span-primitives`,
  `swift-storage-primitives` (`Store.swift`), `swift-buffer-{linear,primitives}`, `swift-lexer-primitives`,
  `swift-cursor-primitives`, `swift-list-linked`/`queue-linked` (Iterable conformances).
- **Satellites (dissolve with the type):** `swift-memory-iterator-primitives` (`+Iterable`),
  `swift-memory-sequence-primitives` (`+Sequenceable`).
- **Internal:** `swift-memory-heap-primitives` (the `<Byte>` wrap it sheds).

## Sequence (bottom-up; gated; serialized against the Tracked+Unique arc)

0. **Gate A** — the allocator redesign (`Memory.Allocatable` ← `Iterable`-shaped) settles.
0′. **Gate B** — the Tracked+Unique arc (`HANDOFF-memory-tier-cleanup.md`) is **not** editing
   `swift-memory-primitives` concurrently; these two arcs share the tree and must serialize.
1. **`Memory.Heap` absorbs Contiguous's owned-pointer core** + its own free; drop the
   `Memory.Contiguous<Byte>` wrap; derive `base: Memory.Address` from the cached pointer for the
   `Memory.Region` seam.
2. *(adjacent, F6)* `Memory.Aligned` de-`unsafe` via the same compose pattern — optional, same arc.
3. **Retarget consumers** — borrowed-read → `Swift.Span`; own-storage (`binary`/`string`/`path`) →
   `Storage.Contiguous`.
4. **Delete `Memory.Contiguous`** + its `+Span`/`+Iterable`/`+Sequenceable` satellites.
5. **Corpus reconciliation** — flip `owned-typed-memory-region-abstraction.md` (create → DISSOLVED);
   update `[DS-006]`, the harvest-ledger converged-core entry, and the skill cites that still treat
   `Memory.Contiguous` as canonical/model.

The **only behavioral edit** in the whole arc is at the consumer retarget; steps 1–4 are
target-removal + composition + umbrella/manifest drops.

## Follow-on (out of THIS arc's scope) — String/Path generic-over-leaf (SSO)

This dissolution correctly lands `String`/`Path` on **concrete `Memory.Heap`** (the egress-capable raw
leaf — owned bytes + `take()`/`unsafeBaseAddress` for the `char*` syscall path; `Storage.Contiguous`'s
no-escape posture cannot serve egress). Recorded here so it is not lost: the natural next step is to
make the **owning** `String`/`Path` *generic over the raw leaf*, which unlocks small-string optimization.

- **Shape:** `String<Backing>` where `Backing` is a raw-leaf protocol = `Memory.Region` (base+capacity)
  + a borrowed raw-base egress accessor + **conditional** `Memory.Growable`. Admits `Memory.Heap`,
  `Memory.Small<n>`, `Memory.Inline<n>`; `Shared<…>` layers CoW value-semantics.
- **Wins:** **SSO via `Memory.Small<n>`** (inline ≤ n bytes, heap spill) — the prize; bounded/inline via
  `Memory.Inline<n>` (borrowed egress only — move-sensitive footprint address); value-vs-move via `Shared<>`.
- **Ownership boundary — do NOT widen the generic.** Keep `String<Backing>` to the **self-owning,
  self-freeing, egress-capable** leaves (uniform lifecycle). The zero-copy / foreign / arena cases are a
  *different* ownership model and belong to the **existing owning/borrowed split**: `String.Borrowed` /
  `Path.Borrowed` already exist as non-owning views — `Memory.Foreign` (adopted + release callback) rides
  those, not a wider backing generic. Arena is an allocation-source concern; defer until a real need.
  Rationale is `[DS-023]` (inline/small are *leaf* concerns — the same principle dissolving
  `Buffer.Slab.Inline/.Small`): SSO routes through `Memory.Small`, never a `Buffer`/`Storage` variant.
- **Ergonomic default — NOT a typealias.** `typealias String = String<Memory.Heap>` does **not** work:
  the alias name collides with the generic `String<…>` itself (two `String`s in one scope). Instead provide
  convenience inits via a constrained extension — `extension String where Backing == Memory.Heap { init(…) }`
  — so `String("…")` construction still infers the heap default. **Arc tasks:** verify Swift infers
  `Backing` from the constrained-init `where` clause for bare `String(…)`; and resolve bare-`String`
  *type-annotation* ergonomics (a `: String` annotation would otherwise need `: String<Memory.Heap>`).
- **Scope:** a SEPARATE follow-on arc, AFTER this dissolution lands — a real API change (`String`/`Path`
  gain a generic parameter → wide consumer impact), justified by the SSO payoff (the large majority of
  strings are short). Not to be folded into the live dissolution.

## References

- **Audit:** `swift-institute/Audits/tower-layering-status-quo-2026-06-22.md` §F4 (F4a/F4b), §Q2, §7.
- **Superseded decision:** `owned-typed-memory-region-abstraction.md` (DECISION:create → DISSOLVED).
- **Rules:** `[MEM-SAFE-029]` (no generic address caching), `[MEM-OWN-015]` (no reconstruction),
  `[MEM-SAFE-030]` (read-only fence / reads ride `Span`), `[MEM-SAFE-025a]`, `[MEM-SAFE-012]`,
  `[MEM-SAFE-015]`, `[MOD-PLACE]`, `[DS-006]`.
- **Code anchors:** `Memory.Contiguous.swift:72` (decl), `:68-71` (orthogonality decision), `:76,:119`
  (owned pointer + free), `+Span.Protocol.swift:26,33`; `Memory.Heap.swift:33`,
  `Memory.Heap ~Copyable.swift:26,39,40`; `Memory.Region.swift:34-40`; `Memory.Allocator.swift:37-46`.
- **Separate arc (do not co-mingle):** `.handoffs/HANDOFF-memory-tier-cleanup.md` (Tracked+Unique).
