# Canonical Buffer Discipline — Cross-Language Survey

<!--
---
version: 1.0.0
last_updated: 2026-05-23
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
---
-->

## Context

`swift-buffer-primitives` has just had all eight buffer disciplines extracted to
sibling packages — `swift-buffer-{linear,ring,slab,linked,slots,arena,unbounded,aligned}-primitives`
— leaving the owner package as pure substrate. The owner's current `Sources/`
are exactly three targets (verified 2026-05-23):

- `Buffer Primitive` — the `Buffer<Element>` namespace enum (the `Nest` that every
  discipline hangs `.Linear` / `.Ring` / `.Slab` / … off of)
- `Buffer Growth Primitives` — `Buffer.Growth.Policy` and growth strategy
- `Buffer Primitives` — the umbrella re-export

The open architectural question: **should the owner package designate (and retain)
a single CANONICAL default general-purpose buffer discipline**, or should it remain
pure substrate with all disciplines living equally as peer siblings?

This matters because every consumer that reaches for "just a buffer" — without
caring about ring/slab/arena specifics — currently has to pick a sibling package
explicitly. A canonical-in-owner discipline would give `import Buffer_Primitives`
a default growable buffer out of the box, mirroring how `import` of a language's
standard prelude hands you `Vec` / `vector` / `ArrayList` / `list` without further
qualification.

**Trigger**: [RES-011] research-first design — the designation decision is
precedent-setting (it fixes, for the lifetime of the package, what "the default
buffer" means) and must be resolved before either (a) re-absorbing a discipline
into the owner or (b) ratifying the pure-substrate end-state. This is the
[RES-001] *Architecture choice* category.

**Precedent risk**: VERY HIGH. Buffer primitives sit at the junction between raw
storage and every higher-level ADT (Array, Stack, Queue, Heap, ordered Set/Dictionary).
What the owner designates as canonical shapes the default mental model for the
entire collection tier and is hard to undo once consumers depend on the umbrella's
default surface.

### The cycle constraint (verified 2026-05-23)

A canonical-in-owner discipline is bound by a hard structural constraint:
**it must depend only on the substrate (the owner's own targets) plus, at most,
a storage sibling — it cannot depend on another buffer sibling, or it forms a
[MOD-032] package-level cycle**, because every buffer sibling already declares
`.package(path: "../swift-buffer-primitives")` on the owner.

Empirical verification of each sibling's `Package.swift` `.package(path:)` declarations
(per [RES-023], read directly at write time):

| Sibling | Depends on owner? | Depends on another **buffer** sibling? | Cycle-safe to host in owner? |
|---|---|---|---|
| `swift-buffer-linear-primitives` | yes | **no** (storage, index, affine, ordinal, memory, finite, sequence, collection) | **YES** |
| `swift-buffer-aligned-primitives` | yes | **no** (byte, memory, index, affine, ordinal) | yes (but byte-domain, not general-purpose) |
| `swift-buffer-ring-primitives` | yes | no (storage, cyclic-index, …) | yes (but special-purpose) |
| `swift-buffer-slab-primitives` | yes | no (storage, storage-slab, bit-vector, …) | yes (but special-purpose) |
| `swift-buffer-linked-primitives` | yes | no (storage, storage-pool, link, …) | yes (but special-purpose) |
| `swift-buffer-slots-primitives` | yes | no (storage, storage-split, …) | yes (but special-purpose) |
| `swift-buffer-arena-primitives` | yes | no (storage, storage-arena, …) | yes (but special-purpose) |
| `swift-buffer-unbounded-primitives` | yes | **YES → `../swift-buffer-aligned-primitives`** | **NO — Unbounded→Aligned→owner is a cycle** |

The owner itself depends on `swift-index-primitives`, `swift-affine-primitives`,
`swift-memory-primitives` and **no buffer sibling** (verified). So the cycle is
created the moment the owner takes a path-dependency on any sibling.

[MOD-032] forbids package-level cycles *even when SwiftPM tolerates them* (the
target graph can be acyclic while the package graph is cyclic — the rule still
fires). This is the same rule that produced six reverts in the 2026-05-22
binary-primitives cohort. So the constraint is binding, not advisory.

**Consequence**: `Unbounded` is structurally disqualified as a canonical-in-owner
discipline (it transitively depends on a sibling). `Linear` is the cycle-safe
general-purpose candidate: it depends only on the owner's own targets
(`Buffer Primitive`, `Buffer Growth Primitives`) plus `Storage Heap Primitives`
(a storage sibling, verified — `swift-buffer-linear-primitives` uses
`Storage.Heap` as its backing) and lower-tier typed-arithmetic primitives — **no
other buffer sibling**. This research asks whether ecosystem precedent supports
making "contiguous / Linear" the canonical default, independent of the fact that
it is *also* the cycle-safe one.

---

## Question

1. Across data-structure libraries — in Swift and in other languages — which
   buffer/collection *discipline* is treated as the "canonical" or default
   general-purpose buffer, and why?
2. Is the contiguous/linear discipline the universal canonical default (vs.
   ring/deque, arena, linked, slab)?
3. What dependency and complexity trade-offs drive that choice?
4. Given the answer, **should `swift-buffer-primitives` designate a canonical
   buffer, and which discipline?**

---

## Step-0 Internal Prior Art ([RES-019] / [HANDOFF-013])

Grep of `swift-institute/Research/` and `swift-buffer-primitives/Research/`
surfaced directly load-bearing internal research. Per [RES-019], internal research
governs; this survey extends rather than re-derives it.

| Internal doc | Status | Relevance |
|---|---|---|
| `swift-buffer-primitives/Research/theoretical-buffer-primitives-design.md` (Tier 3) | DEFERRED | **Already ran an SLR** answering RQ1 "What buffer disciplines are considered canonical in systems programming?". Converged on **Linear, Ring, Slab** as the three fundamental disciplines; classifies Stack/Deque as higher-layer access-policy restrictions. Cites Rust `Vec`/`VecDeque`/`bytes`/`smallvec`, folly `IOBuf`, Boost.CircularBuffer. |
| `swift-institute/Research/ecosystem-data-structures-inventory.md` | (catalog) | Already labels `Buffer.Linear<E>` as **"General-purpose contiguous buffer; unknown size"** and lists its **"Backing for": Array, Stack, Heap, Dictionary.Ordered, Set.Ordered** — the broadest consumer set of any discipline. Ring backs only Queue; Linked backs List/linked-Queue; Slab/Arena/Slots back specialized structures. |
| `swift-institute/Research/data-structures-linear-collections-assessment.md` (Tier 2, DECISION) | DECISION | Confirms the consumer mapping in live source: `Array`→`Buffer.Linear`, `Stack`→`Buffer.Linear`, `Queue`→`Buffer.Ring`, `List.Linked`→`Buffer.Linked`. Linear already backs the two most-used collections. |
| `swift-institute/Research/comparative-buffer-primitives.md` (2026-02-24) | DECISION (stale shape) | Predates the 8-way sibling extraction — it describes all disciplines living in the owner. Its *layering* conclusion (buffer-primitives sits above Memory.Pool, below collections) remains valid; its module map does not. Flagged here so a future reader does not mistake it for current structure. |

The internal position is therefore already **"Linear is the general-purpose
contiguous default; Ring/Slab are the other two fundamental disciplines;
everything else is a specialization or a composite."** This survey's job is to
test that position against external cross-language precedent and translate it into
the specific *designation* decision the owner now faces.

---

## Systematic Literature Review — Cross-Language Survey

### Protocol

- **RQ1**: In each surveyed language's standard library (or its dominant idiom),
  which growable buffer is the canonical/default general-purpose container?
- **RQ2**: Is a ring/deque offered as a *peer* default or as a *specialization*?
- **RQ3**: What rationale does each ecosystem give (cache locality, amortized
  append, API ergonomics, dependency weight, memory contiguity guarantee)?
- **Inclusion**: standard-library or de-facto-standard growable sequence types,
  with primary documentation. **Exclusion**: application-level I/O buffering,
  GPU/numeric buffers, third-party-only types without standard-library standing
  (except where instructive, e.g. Rust `bytes`).

### Survey

Every load-bearing per-language claim below carries a `[Verified: 2026-05-23]`
tag against a primary source (the language's own standard-library documentation,
standard-library source, or the language's official style guidance), per
[RES-020] / [RES-032].

#### Swift (standard library)

`Array<Element>` is the canonical growable buffer. `ContiguousArray<Element>` is
the same discipline with the NSArray-bridging guarantee dropped (always contiguous,
native storage); `ArraySlice<Element>` is a view into a contiguous sub-range. All
three are the **contiguous/linear** discipline — Array's documentation describes it
as storing elements "in a contiguous region of memory."

**Is there a deque in the Swift standard library?** No. The Swift standard library
ships no `Deque`. A double-ended queue exists only in `swift-collections`
(`Deque`), an Apple-published but *separate* package — not in the prelude. So in
Swift the contiguous discipline is the *only* growable-buffer discipline that ships
by default; the ring/deque discipline is an opt-in dependency.
[Verified: 2026-05-23 — Swift stdlib `Array` documentation ("contiguous region of
memory"); absence of `Deque` from the stdlib, presence only in apple/swift-collections.]

#### Rust (`std`)

`Vec<T>` is "**A contiguous growable array type**, written as `Vec<T>`, short for
'vector'" — verbatim from the standard-library docs. It is "a `(pointer, capacity,
length)` triplet. No more, no less," documented as being "as low-overhead as
possible in the general case." `VecDeque<T>` is "A double-ended queue implemented
with a **growable ring buffer**," explicitly the peer for O(1)-at-both-ends access.
The std docs steer users from `Vec` to `VecDeque` precisely when front-removal is
needed (`Vec::remove(0)` is O(n); `VecDeque::pop_front` is O(1)).

**Canonical default**: `Vec` (contiguous). **Ring/deque**: `VecDeque`, offered as a
named *peer specialization*, not the default. **Rationale**: contiguity → lowest
overhead, cache locality, and the `(ptr, cap, len)` minimalism; the ring is reached
for only when both-ends mutation dominates.
[Verified: 2026-05-23 — doc.rust-lang.org `std::vec::Vec` ("contiguous growable
array type", "(pointer, capacity, length) triplet… as low-overhead as possible");
`std::collections::VecDeque` ("double-ended queue implemented with a growable ring
buffer").]

#### C++ (standard library + ISO C++ Core Guidelines)

`std::vector` stores elements contiguously; `std::deque` does **not** ("typical
implementations use a sequence of individually allocated fixed-size arrays," so
indexed access costs two dereferences vs vector's one). The ISO **C++ Core
Guidelines rule SL.con.2 is literally "Prefer using STL `vector` by default unless
you have a reason to use a different container."** The stated Reason: "`vector` and
`array` are the only standard containers that offer the following advantages: the
fastest general-purpose access (random access, including being
vectorization-friendly); the fastest default access pattern (begin-to-end or
end-to-begin is prefetcher-friendly); the lowest space overhead (contiguous layout
has zero per-element overhead, which is cache-friendly)." Guidance: use `deque`
when you add/remove at *both* front and back.

**Canonical default**: `std::vector` (contiguous), by explicit normative guideline.
**Ring/deque**: `std::deque`, a both-ends specialization. **Rationale**: random
access + prefetcher-friendliness + zero per-element overhead + cache locality —
the most explicit articulation of the contiguity rationale of any surveyed ecosystem.
[Verified: 2026-05-23 — cppreference `std::deque` ("elements are not stored
contiguously… two pointer dereferences"); C++ Core Guidelines SL.con.2 statement +
Reason as quoted.]

#### Java (`java.util`)

`ArrayList<E>` is the array-backed (contiguous-storage) general-purpose list and is
the de-facto default `List`. Java's own *Collections* tutorial says the
general-purpose `Deque` implementation to prefer is `ArrayDeque` ("more efficient
than `LinkedList` for add and remove operations at both ends"); `LinkedList` is
explicitly *not* recommended for general list use. So even Java's deque default is
**array-backed (circular array)** rather than linked.

**Canonical default**: `ArrayList` (array-backed). **Ring/deque**: `ArrayDeque`
(circular-array deque) as the both-ends peer. **Rationale**: contiguous array
backing wins on access cost and memory footprint; the linked alternative is
deprecated-by-guidance for general use.
[Verified: 2026-05-23 — Oracle *Collections* tutorial "Deque Implementations"
(prefer `ArrayDeque`); dev.java "ArrayList vs LinkedList" (ArrayList for
general-purpose lists, LinkedList only for stack/queue ends).]

#### Go (language built-in)

The **slice** (`[]T`) is the canonical growable sequence and is a language built-in,
not a library type. It is a `(pointer, length, capacity)` descriptor over a
contiguous backing array; `append` grows by allocating a larger contiguous backing
array and copying (amortized doubling for small sizes). Go ships no standard ring or
deque type — a deque is hand-rolled from a slice (or two slices) when needed.

**Canonical default**: slice (contiguous). **Ring/deque**: none in std; built from
slices. **Rationale**: the slice *is* the contiguous discipline elevated to a
language primitive; contiguity + amortized append is the whole model.
[Verified: 2026-05-23 — go.dev/blog "Arrays, slices: the mechanics of 'append'"
(slice as pointer/length/capacity over contiguous array; append reallocates a larger
contiguous array).]

#### Python (CPython)

`list` is the canonical sequence. CPython implements it as a **dynamic array**: a
contiguous array of `PyObject*` pointers with geometric over-allocation on append
(`list_resize` grows capacity roughly 1.125×, with a small additive term, to amortize).
There is `collections.deque` for a both-ends queue — implemented as a doubly-linked
list of fixed-size blocks — but `list` is the default the language hands you with
literal syntax `[]`.

**Canonical default**: `list` (contiguous dynamic array). **Ring/deque**:
`collections.deque` (block-linked), a stdlib-but-opt-in specialization (you must
`import collections`). **Rationale**: contiguity + over-allocated amortized append;
indexing and iteration are the dominant operations the default optimizes for.
[Verified: 2026-05-23 — CPython `listobject.c` `list_resize` over-allocation growth;
`collections.deque` documented as block-linked double-ended queue.]

#### C# (.NET)

`List<T>` is the canonical dynamic list, **array-backed** ("internally backed by an
array; when the data grows beyond the current array's capacity, the list allocates a
bigger array and copies the data over"). `Queue<T>` is array-backed with circular
(wrap-around) head/tail semantics — the ring peer.

**Canonical default**: `List<T>` (array-backed contiguous). **Ring/deque**:
`Queue<T>` (circular array). **Rationale**: same contiguity story; `Queue<T>` is the
specialization for FIFO at both ends.
[Verified: 2026-05-23 — .NET `System.Collections.Generic.List<T>` (array backing,
grow-and-copy); `Queue<T>` circular-array implementation.]

#### Zig (`std`)

`std.ArrayList(T)` is "a contiguous, growable list of items in memory"; when the
block is full it "allocates another contiguous and bigger block… copies the elements
to this new location." The std docs themselves note it "is similar to C++'s
`std::vector<T>` and Rust's `Vec<T>`." No std ring/deque is the default growable
buffer (Zig also offers `BoundedArray` and ring-buffer types, but `ArrayList` is the
general-purpose default).

**Canonical default**: `std.ArrayList` (contiguous). **Rationale**: explicitly modeled
on `vector`/`Vec` — contiguity + grow-and-copy.
[Verified: 2026-05-23 — ziglang/zig `lib/std/array_list.zig` ("contiguous, growable…
allocates a bigger contiguous block… similar to C++'s std::vector and Rust's Vec").]

#### Instructive non-stdlib data points (carried from internal SLR)

- **Rust `bytes` / `ringbuffer` crates**: separate the *discipline* (trait) from the
  *backing storage* — the same orthogonality the institute models as `Buffer.<Discipline>`
  over `Storage.<Strategy>`. Confirms discipline/storage separation is the prevailing
  design, not a Swift-Institute invention.
  [Verified: 2026-05-23 via internal `theoretical-buffer-primitives-design.md` SLR
  rows 4 & 6, which cite the crate docs directly.]
- **folly `IOBuf`, Boost.CircularBuffer, seL4 IPC ring buffers**: ring/circular
  buffers are universally treated as a *named special-purpose* discipline (FIFO,
  fixed-capacity, overwrite-on-full, IPC), never as the general-purpose default.
  [Verified: 2026-05-23 via internal SLR rows 8, 9, 13.]

### Synthesis

| Language | Canonical default growable buffer | Discipline | Ring/deque offered as | Stated rationale |
|---|---|---|---|---|
| Swift (stdlib) | `Array` (+`ContiguousArray`,`ArraySlice`) | **Contiguous/Linear** | **Not in stdlib** (only in swift-collections `Deque`) | Contiguous storage; bridging-free variant |
| Rust (std) | `Vec` | **Contiguous/Linear** | Peer specialization (`VecDeque`, growable ring) | Lowest overhead; `(ptr,cap,len)`; cache locality |
| C++ (Core Guidelines) | `std::vector` | **Contiguous/Linear** | Both-ends specialization (`std::deque`) | Random access, prefetcher-friendly, zero per-element overhead (**normative SL.con.2**) |
| Java | `ArrayList` | **Contiguous (array-backed)** | Specialization (`ArrayDeque`, circular array) | Access cost + footprint; linked deprecated-by-guidance |
| Go | slice `[]T` | **Contiguous (language built-in)** | None in std (hand-rolled) | Contiguity + amortized append, as a primitive |
| Python | `list` | **Contiguous (dynamic array)** | Opt-in stdlib (`collections.deque`, block-linked) | Over-allocated amortized append; indexing |
| C# | `List<T>` | **Contiguous (array-backed)** | Specialization (`Queue<T>`, circular array) | Array backing; grow-and-copy |
| Zig | `std.ArrayList` | **Contiguous** | Not the default (separate ring types exist) | Explicitly modeled on `vector`/`Vec` |

**Finding (RQ1+RQ2)**: The contiguous/linear discipline is the canonical
general-purpose growable buffer in **every** surveyed language — **8 of 8**, with no
exception. The ring/deque discipline is, in every case where it ships at all, a
**named peer specialization** reached for only when both-ends (or FIFO/wrap-around)
access dominates. In several ecosystems (Swift stdlib, Go) the ring/deque is *not in
the standard surface at all*; in others (Python) it is opt-in behind an import. No
surveyed ecosystem makes a ring, arena, slab, or linked structure its
general-purpose default.

**Finding (RQ3) — why contiguity wins as the default**:

1. **Cache locality / access cost.** Contiguous layout gives single-dereference
   random access and prefetcher-friendly sequential scans (C++ SL.con.2's explicit
   reasoning; Rust's "lowest overhead"; the universal cache-locality argument).
2. **Lowest space overhead.** Zero per-element bookkeeping (no node pointers, no
   per-slot occupancy word) — the `(ptr, cap, len)` triplet is the minimum viable
   descriptor (Rust, Go, C# all converge on exactly this shape).
3. **Amortized append is "good enough" for the common case.** Geometric growth
   (doubling, 1.5×, or ~1.125×) makes back-insertion amortized O(1); the *only* thing
   contiguity sacrifices is cheap front/middle mutation, which is a minority workload.
4. **API ergonomics / smallest mental model.** The default is the type you reach for
   when you have *no* special access pattern in mind; contiguity is the discipline
   with the fewest invariants to reason about (no head/tail cursor, no occupancy
   bitmap, no generation tokens). The other disciplines exist to *answer a specific
   question* (both-ends → ring; stable slots → slab/arena; cheap splice → linked).
5. **Dependency weight.** Contiguity needs only "a contiguous storage block + count" —
   i.e. the substrate plus a heap-storage primitive. Ring needs cyclic-index
   arithmetic; slab needs a bit-vector; linked needs a pool + link primitive; arena
   needs generation tokens. **The contiguous discipline is the one with the lightest
   transitive dependency set** — which is exactly why, in the institute's package
   graph, it is also the only general-purpose discipline that is cycle-safe to host
   in the owner (it needs no *buffer* sibling, only a *storage* sibling).

The dependency-weight finding (5) is the bridge between the external survey and the
institute's specific constraint: the same property that makes contiguity the
universal default (minimal substrate requirement) is the property that makes
`Buffer.Linear` the unique cycle-safe candidate for an owner-hosted canonical.

---

## Analysis — Should the owner designate a canonical buffer?

### Contextualization step ([RES-021])

Universal adoption is not universal necessity. Before treating "every language has a
default contiguous buffer" as a mandate, concretize what a *canonical designation*
means in this ecosystem and what it would cost.

A "canonical buffer" in `swift-buffer-primitives` could mean any of three distinct
things — these are genuinely different designs, and the survey above argues for some
but not others:

- **(D1) Re-absorb a discipline into the owner.** Move `Buffer.Linear` source back
  into the owner package so `import Buffer_Primitives` yields a concrete default
  buffer with no further dependency. The owner gains a path-dependency on
  `Storage Heap Primitives` (a storage sibling — permitted) but on **no buffer
  sibling** (required by [MOD-032]).
- **(D2) Designate without absorbing.** Keep `Buffer.Linear` in
  `swift-buffer-linear-primitives`, but have the owner's umbrella
  (`Buffer Primitives` target) `@_exported import` the linear sibling and *document*
  it as "the default." This makes the owner's umbrella depend on the linear sibling.
- **(D3) Documentation-only canonical.** Add no dependency; the owner's docs simply
  *name* Linear as the recommended default and point to the sibling. No code or
  manifest change.

### Option D1 — Re-absorb Linear into the owner

| | |
|---|---|
| **Shape** | `Buffer.Linear` (+ `.Bounded`, `.Inline`, `.Small`) source lives in the owner; owner depends on `Storage Heap/Inline` + lower-tier typed primitives; no buffer-sibling dep. The other seven disciplines stay as siblings. |
| **Pros** | Matches the *strongest* reading of the survey: in Rust/C++/Swift-stdlib/Go/Python/C#/Zig the default buffer is *in the prelude*, available without an extra dependency. A consumer importing the owner gets a working general-purpose buffer immediately. The cycle constraint is *satisfiable* precisely because Linear needs no buffer sibling. |
| **Cons** | Reverses, for one discipline, the 8-way extraction that was just completed — re-introduces discipline source into a package whose just-achieved identity is "pure substrate." Asymmetric: seven disciplines are siblings, one is in the owner. Creates a "why is Linear special at the package level?" question for every future reader. The owner is no longer substrate-only; its dependency set grows from {index, affine, memory} to include storage. |

### Option D2 — Umbrella re-exports Linear as the documented default

| | |
|---|---|
| **Shape** | `Buffer.Linear` stays in its sibling. The owner's `Buffer Primitives` umbrella target adds `.package(path: "../swift-buffer-linear-primitives")` + `@_exported public import Buffer_Linear_Primitives`, and docs name it canonical. |
| **Pros** | `import Buffer_Primitives` again yields `Buffer.Linear` for free (umbrella convenience) — closest *ergonomic* match to "the prelude hands you the default" without moving source. No discipline source re-enters the owner; extraction stays intact. |
| **Cons** | **Forms a [MOD-032] cycle.** The owner's umbrella would depend on `swift-buffer-linear-primitives`, which already depends on the owner (`Buffer Primitive` + `Buffer Growth Primitives` products). Owner ⇄ Linear bidirectional `.package(path:)` — exactly the configuration [MOD-032] forbids even when the *target* graph stays acyclic. This is the same defect class as the six 2026-05-22 cohort reverts. **Disqualified on the cycle axis.** (A separate "convenience umbrella" package *above* both — e.g. a `swift-buffer` aggregate — could re-export Linear without a cycle, but that is a new L1-aggregate package decision, out of scope for "what does the *owner* designate.") |

### Option D3 — Documentation-only canonical

| | |
|---|---|
| **Shape** | No manifest/source change. The owner's README / DocC names `Buffer.Linear` (in `swift-buffer-linear-primitives`) as the recommended general-purpose default, with a one-line decision table pointing Ring→both-ends/FIFO, Slab/Arena→stable slots, Linked→cheap splice, etc. The substrate-only owner is preserved exactly. |
| **Pros** | Zero cycle risk (no new dependency). Preserves the just-achieved pure-substrate identity of the owner. Still delivers the *decision-guidance* value the survey supports ("reach for Linear unless you have a specific reason") — which is what C++ SL.con.2 and Java's tutorial actually are: *guidance*, not a forced default. Symmetric: all eight disciplines remain peer siblings; the canonical status is a recommendation, not a structural privilege. Cheapest to reverse if the ecosystem later wants a different shape. |
| **Cons** | `import Buffer_Primitives` does **not** hand the consumer a concrete buffer — they must add `swift-buffer-linear-primitives` explicitly. Weaker ergonomic match to "the prelude gives you `Vec`." The canonical designation has no compiler-enforced teeth. |

### Comparison

| Criterion | D1 Re-absorb | D2 Umbrella re-export | D3 Doc-only |
|---|---|---|---|
| Matches survey (contiguity = default) | Strongest | Strong (ergonomic) | Adequate (guidance-level) |
| [MOD-032] cycle-safe | **Yes** (Linear needs no buffer sibling) | **No — forms owner⇄Linear cycle** | **Yes** (no new dep) |
| Preserves pure-substrate owner identity | No (one discipline re-enters) | Yes (source stays out) | Yes |
| Symmetric across the 8 disciplines | No (Linear privileged structurally) | No (Linear privileged structurally) | Yes (Linear privileged only by docs) |
| Ergonomics: `import` yields a buffer | Yes | Yes | No |
| Reversibility | Low (source move) | n/a (disqualified) | High (doc edit) |
| [RES-018] classification | Not a new primitive — placement of an existing one | same | same |

### Semantic-identity framing ([RES-029])

The designation question is partly a placement/identity question ("does the
canonical default *belong* in the owner, or is the owner *by identity* pure
substrate?"), so [RES-029]'s semantic-identity-first ranking applies; ergonomics and
cost are tiebreakers, not the primary axis.

- **Tier 1 (semantic identity).** What *is* the owner now? The 8-way extraction
  deliberately reduced it to substrate: the `Buffer` namespace + growth policy +
  umbrella. Its identity is "the `Nest` and the shared vocabulary off which
  disciplines hang," not "a discipline." Re-absorbing Linear (D1) contradicts that
  just-established identity; D2 contradicts it *and* forms a cycle; D3 respects it
  (Linear stays a sibling; the owner stays substrate). On the identity axis, **D3 is
  the only option that does not re-litigate the extraction that was just ratified.**
- **Tier 2 (operational behavior of adjacent ecosystem types).** The survey is the
  cross-system operational anchor: every language ships a contiguous default — but
  note *where* it ships. In Swift's own stdlib and in Go the default contiguous
  buffer is a **language/prelude primitive**, not a member of a "buffer disciplines"
  package. The institute's analog of "the prelude" is not the buffer *owner* — it is
  the higher collection tier (`Array` in `swift-array-primitives`, which **already**
  is `Buffer.Linear`-backed per the linear-collections assessment). So the
  operational precedent says "the contiguous default lives at the *collection* layer
  the user actually reaches for," which the ecosystem **already satisfies** via
  `Array`. The buffer owner does not need to re-host it to honor the precedent.
- **Tier 3 (ergonomics / cost) — tiebreaker only.** D1's ergonomic win
  (`import Buffer_Primitives` → a buffer) is real but secondary, and is *already*
  delivered one layer up by `Array`. It does not override the Tier-1 identity verdict.

### Why not compose existing primitives? ([RES-018] case classification)

This is **not** [RES-018] case (a) (a new cross-cutting primitive) — nothing new is
being created. It is a *placement/designation* decision about an existing type, which
falls under [RES-018] case (b) (domain-owned vocabulary) governed by [MOD-DOMAIN]:
"each domain owns its vocabulary and L1 functionality." The buffer domain already
*has* its contiguous discipline (`Buffer.Linear`); the only question is whether the
owner package re-hosts it, re-exports it, or merely names it. The composition that
already exists — `Array` = `Buffer.Linear` over `Storage.Heap`, surfaced at the
collection tier — already covers the "default contiguous buffer for consumers" use
case. No new primitive is warranted; the survey's "8/8 contiguity" finding argues for
*which discipline is canonical*, not for *creating* anything.

---

## Outcome

**Status**: RECOMMENDATION

### Recommendation

1. **Yes — designate a canonical default buffer discipline, and make it the
   contiguous/Linear discipline.** The cross-language evidence is unanimous (8 of 8
   surveyed ecosystems make a contiguous growable buffer the general-purpose default;
   ring/deque is universally a named peer specialization). The internal corpus
   already independently reached the same position (`Buffer.Linear` =
   "general-purpose contiguous buffer," backing Array/Stack/Heap/ordered
   Set+Dictionary). Contiguity wins for cache locality, lowest space overhead,
   amortized append, the smallest mental model, **and the lightest dependency set**.

2. **Implement the designation as D3 (documentation-only canonical), not D1 or D2.**
   - **D2 is disqualified** on the [MOD-032] cycle axis (owner⇄Linear bidirectional
     `.package(path:)`).
   - **D1 (re-absorb)** is *structurally permissible* — Linear is the one
     general-purpose discipline that is cycle-safe to host in the owner because it
     depends on no buffer sibling (only `Storage.Heap` + lower-tier primitives,
     verified) — but it is **not recommended**: it reverses, for a single discipline,
     the 8-way extraction that just established the owner as pure substrate, and it
     introduces a "why is Linear special at the package level?" asymmetry. The
     ergonomic benefit it buys (`import Buffer_Primitives` → a concrete buffer) is
     **already delivered one layer up** by `Array` (= `Buffer.Linear`-backed), which
     is the type consumers actually reach for. Per [RES-029], the Tier-1 identity
     verdict (owner = substrate) dominates the Tier-3 ergonomic tiebreaker.
   - **D3** preserves the owner's pure-substrate identity, keeps all eight disciplines
     as symmetric peer siblings, carries zero cycle risk, is maximally reversible,
     and still delivers exactly the value the external precedent actually represents:
     C++ SL.con.2 and Java's Collections tutorial are *normative guidance* ("prefer
     vector by default"), not a forced structural default. The institute's
     equivalent is a documented canonical-default recommendation in the owner's
     README/DocC plus a discipline-selection decision table.

3. **Concrete D3 content** (for whoever implements — this doc prescribes the
   decision, not the prose): the owner's README/DocC should state that the
   **contiguous/Linear discipline (`Buffer.Linear`, in
   `swift-buffer-linear-primitives`) is the recommended general-purpose default**,
   and that the other seven disciplines are reached for only to answer a specific
   question — Ring (both-ends / FIFO / wrap-around), Slab + Arena + Slots (stable
   slot identity / O(1) free-by-handle), Linked (cheap splice / pointer-stable
   nodes), Aligned (alignment-constrained byte buffers), Unbounded (the
   aligned-backed unbounded case). This mirrors, almost exactly, the
   `ecosystem-data-structures-inventory.md` "When to use" tables that already exist —
   so the work is to *state the default explicitly in the owner*, not to author new
   analysis.

### Why this is a RECOMMENDATION, not a DECISION

The choice between D1 and D3 is ultimately a principal call about the owner's
identity (pure-substrate-symmetric vs. substrate-plus-canonical-default). This doc
gives the structural facts (D2 disqualified; D1 cycle-safe but identity-reversing;
D3 cycle-safe and identity-preserving) and recommends D3, but the re-absorb-vs-doc
trade-off is a deliberate architectural-identity decision reserved for principal
ratification. No source or `Package.swift` was edited (read-only research per the
dispatch).

### Residual items ([RES-027])

All residual items below are **direction items** (research questions that may or may
not affect downstream design), not **premise items** (load-bearing unverified
claims). None gate this recommendation, so none require an immediate experiment
spike.

- **(direction)** A separate L1-aggregate package (`swift-buffer`, above both owner
  and siblings) could re-export Linear as a convenience default *without* a cycle —
  this is the only way to get D2's ergonomics cycle-safely. Whether the ecosystem
  wants such an aggregate is a distinct package-creation question, out of scope here.
- **(direction)** `comparative-buffer-primitives.md` (2026-02-24) describes the
  pre-extraction module layout and should be re-statused/superseded in a future
  corpus-health pass; flagged, not actioned (read-only dispatch).
- **(direction)** If D1 is later chosen, the `theoretical-buffer-primitives-design.md`
  (DEFERRED, Tier 3) three-layer design becomes the natural reference for *how* to
  re-host Linear cleanly on `Storage.Heap`; its deferral condition ("inline module
  split stable") is now met by the 8-way extraction, so it could be revived.

---

## References

### Primary sources (cross-language survey) — all [Verified: 2026-05-23]
- Rust `std::vec::Vec` — "A contiguous growable array type… (pointer, capacity, length) triplet… as low-overhead as possible." https://doc.rust-lang.org/std/vec/struct.Vec.html
- Rust `std::collections::VecDeque` — "A double-ended queue implemented with a growable ring buffer." https://doc.rust-lang.org/std/collections/struct.VecDeque.html
- C++ Core Guidelines SL.con.2 — "Prefer using STL `vector` by default unless you have a reason to use a different container." https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#slcon2-prefer-using-stl-vector-by-default-unless-you-have-a-reason-to-use-a-different-container
- cppreference `std::deque` — non-contiguous; "sequence of individually allocated fixed-size arrays." https://en.cppreference.com/cpp/container/deque
- Oracle Java Tutorials — Deque Implementations (prefer `ArrayDeque`). https://docs.oracle.com/javase/tutorial/collections/implementations/deque.html
- dev.java — "Choosing the Right Implementation Between ArrayList and LinkedList." https://dev.java/learn/api/collections-framework/arraylist-vs-linkedlist/
- Go Blog — "Arrays, slices (and strings): The mechanics of 'append'." https://go.dev/blog/slices
- CPython `listobject.c` `list_resize` over-allocation (dynamic-array growth). https://github.com/python/cpython/blob/main/Objects/listobject.c
- Python `collections.deque` (block-linked double-ended queue). https://docs.python.org/3/library/collections.html#collections.deque
- .NET `System.Collections.Generic.List<T>` (array-backed, grow-and-copy). https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.list-1
- Zig `lib/std/array_list.zig` — "contiguous, growable… similar to C++'s std::vector and Rust's Vec." https://github.com/ziglang/zig/blob/master/lib/std/array_list.zig

### Internal prior art
- `swift-buffer-primitives/Research/theoretical-buffer-primitives-design.md` (Tier 3, DEFERRED) — SLR converging on Linear/Ring/Slab as the three fundamental disciplines; Stack/Deque as access-policy restrictions.
- `swift-institute/Research/ecosystem-data-structures-inventory.md` — `Buffer.Linear` as "general-purpose contiguous buffer"; consumer-backing table.
- `swift-institute/Research/data-structures-linear-collections-assessment.md` (Tier 2, DECISION) — live-source consumer mapping (Array/Stack→Linear, Queue→Ring).
- `swift-institute/Research/comparative-buffer-primitives.md` (DECISION; pre-extraction module shape) — layering conclusion valid, module map stale.

### Skill requirements
- [MOD-032] No Package-Level Cycles, Even SwiftPM-Tolerated (the binding constraint).
- [MOD-DOMAIN] each domain owns its vocabulary and L1 functionality.
- [RES-018] cross-cutting-primitive gate — classified case (b), not case (a).
- [RES-019] internal prior-art grep; [RES-021] contextualization step; [RES-023] empirical-claim verification; [RES-027] residual premise-vs-direction; [RES-029] semantic-identity-first ranking; [RES-032] verified primary sources.

### Verification provenance
- Sibling `.package(path:)` dependency table: read from each `swift-buffer-*-primitives/Package.swift` on 2026-05-23.
- Owner substrate state (3 targets, no buffer-sibling deps): read from `swift-buffer-primitives/Package.swift` + `Sources/` listing on 2026-05-23.
- Linear→`Storage.Heap` backing: confirmed via `swift-buffer-linear-primitives` target products (`Storage Heap Primitives`) + source grep on 2026-05-23.
