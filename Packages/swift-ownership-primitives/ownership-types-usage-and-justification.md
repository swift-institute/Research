# Ownership Types — Merits, Completeness, and Naming

<!--
---
version: 2.2.0
last_updated: 2026-04-24
status: IMPLEMENTED
tier: 2
scope: cross-package
---
-->

## Changelog

- **v2.2.0 (2026-04-24)** — Timeless-0.1.0 completion. The ownership
  lattice is now total at fifteen types: the direction × kind matrix
  of the Transfer family fills both new positions (`Transfer.Retained<T>.Incoming`,
  `Transfer.Erased.Incoming`) and two additional ownership cells ship
  (`Ownership.Latch` as the one-shot atomic primitive, `Ownership.Indirect`
  as the heap CoW value cell). Clusters A + B + E land per the Design
  Review recommendations; Cluster D (Shared/Mutable symmetry rename)
  remains deferred per the companion research doc.

- **v2.1.0 (2026-04-23)** — Revalidated the "~Copyable generic blocks
  Sendable inference" claim on Swift 6.3.1 via
  `swift-institute/Experiments/noncopyable-generic-sendable-inference/`.
  Finding: **FIXED** for `final class Shared<Value: ~Copyable & Sendable>`
  with an immutable stored property — the compiler accepts plain
  `Sendable`. `Ownership.Shared` is now spelled as checked `Sendable`
  (no `@unchecked` escape hatch). For `Ownership.Unique`, the
  `@unchecked` is still required, but the blocker is `UnsafeMutablePointer<Value>?`
  storage (non-Sendable by stdlib `@unsafe` conformance), NOT the
  `~Copyable` generic parameter — docstring corrected. Category D / SP-4
  row removed from the @unchecked Sendable breakdown table.

- **v2.0.0 (2026-04-23)** — Reframed per principal direction: evaluate each
  type on **merits** (unique contract in the ownership space), not ecosystem
  usage. The package is positioned as **total** for ownership — every
  sensible ownership contract should be covered. Added naming review
  (are the names what an experienced Swift engineer would expect?) and
  completeness analysis (is the set total given the domain?). The
  v1.0.0 DEPRECATE verdicts for `Transfer.Storage` and `Transfer.Box`
  are **reversed** — usage absence is not grounds for removal when the
  type occupies a distinct position in the ownership lattice. Usage
  counts relocated to an appendix for reference.

- **v1.0.0 (2026-04-23)** — Initial usage-based evaluation; SUPERSEDED.

## Context

Before tagging `swift-ownership-primitives` 0.1.0, the package author asked for:

1. A **merit-based** per-type evaluation (does the type occupy a unique,
   principled position in the ownership space?).
2. A **completeness check** — the package should be *total* for the
   ownership domain; gaps should be identified.
3. A **naming review** — is each name what a seasoned Swift engineer would
   expect when coming to the type fresh?

Plus a specific concern: the `@unchecked Sendable` types are suspicious —
region-based isolation (SE-0430 `sending`, SE-0518 `~Sendable`) should
cover what they cover. Are they still necessary on their merits?

Provenance: several types were relocated from `swift-reference-primitives`
per that package's Reference.swift doc:

| Old name | New name |
|----------|----------|
| `Reference.Box` | `Ownership.Shared` |
| `Reference.Indirect` | `Ownership.Mutable` |
| `Reference.Slot` | `Ownership.Slot` |
| `Reference.Transfer` | `Ownership.Transfer` |

The 0.1.0 tag freezes these names; pre-tag is the last cheap moment
to adjust.

## Question

For each type currently shipped in `swift-ownership-primitives`:

1. **Merit**: does the type hold down a unique, principled position in the
   ownership space, distinct from every other type in the package and
   from stdlib primitives?
2. **Name**: is the name what a seasoned Swift engineer would reach for?
3. **Completeness**: taken as a set, does the package cover the full
   ownership domain? What's missing?

## The Ownership Space — Axes

Before evaluating individual types, enumerate the axes that partition
the domain:

| Axis | Values |
|------|--------|
| **Lifetime** | Scoped-to-source · Heap-owned (independent) · Transferred (one-shot) |
| **Mutability** | Read-only · Mutable |
| **Ownership multiplicity** | Exclusive (single owner) · Shared (ARC-multi) |
| **Thread-sync** | None (intra-isolation) · Immutability (Sendable by construction) · Atomic / CAS · Caller-asserted external |
| **Copyability of wrapper** | `Copyable` · `~Copyable` · Reference type |

Every type in the package occupies one point in this 5-axis lattice. A
*total* package covers every principled point; redundant types share a
point with another; missing types leave gaps.

The "principled" qualifier matters: not every 5-tuple needs a type —
some are incoherent (e.g. "scoped + shared + mutable + no sync" would
require time-travel), some are stdlib responsibilities (`Mutex`,
`Sendable`-by-inference, `Optional`).

## Analysis

### 1. `Ownership.Borrow` — KEEP, name CORRECT

**Merit — position held**: Scoped-to-source · Read-only · Exclusive
(though `Copyable` wrapper permits in-scope forks) · No sync
(intra-isolation) · `Copyable` wrapper.

No other type in the package or stdlib holds this position on production
Swift 6.3.1. SE-0519 `Borrow<T>` (SwiftStdlib 6.4) will share the
position once it ships stable; the ecosystem `Ownership.Borrow` uses
`UnsafeRawPointer` storage explicitly because `Builtin.Borrow<Value>`
is stdlib-private.

**Region-based-isolation alternative**: `borrowing Value` parameter. Covers
the scoped-borrow-as-parameter case, not the scoped-borrow-as-stored-field
case that `Ownership.Borrow` serves (see `swift-property-primitives`'
`Property.View.Read` — stores `Tagged<Tag, Ownership.Borrow<Base>>` as a
field).

**Name**: `Borrow` is what SE-0519 chose, what Rust chose (`&T`), what
every surveyed literature calls it. Unambiguous; the name an experienced
Swift engineer would expect.

**Name verdict**: CORRECT.
**Merit verdict**: KEEP.

---

### 2. `Ownership.Inout` — KEEP, name CORRECT

**Merit — position held**: Scoped-to-source · Mutable · Exclusive
(enforced by `~Copyable` on the wrapper) · No sync · `~Copyable` wrapper.

Mirror of `Borrow` on the mutable axis. Same scoped-field-storage
justification — `inout Base` parameters cannot be stored.

**Region-based-isolation alternative**: `inout Value` parameter. Same
parameter-vs-stored-field split as Borrow.

**Name**: `Inout` is Swift's keyword for the concept. SE-0519 uses it.
An experienced Swift engineer seeing `Ownership.Inout<T>` immediately
recognises "mutable reference bound to a source, like `inout` but
storable".

**Name verdict**: CORRECT.
**Merit verdict**: KEEP.

---

### 3. `Ownership.Unique` — KEEP, name QUESTION

**Merit — position held**: Heap-owned · Mutable (through
`withMutableValue`) · Exclusive (enforced by `~Copyable` wrapper) · No
sync (Sendable when `Value: Sendable` — exclusive ownership subsumes
sync) · `~Copyable` wrapper.

Unique position. The only other candidate is "plain `~Copyable` container
with inline allocation" — but that's a DIY pattern per type, not a
reusable primitive. `Ownership.Unique` is the *named* abstraction for
"heap-owned exclusive `~Copyable` cell with deterministic deinit". Rust
ships it as `Box<T>`; C++ as `std::unique_ptr`; Swift stdlib as… nothing
(the closest is `ManagedBuffer`, but that requires subclassing).

**Region-based-isolation alternative**: none. `sending` covers
transferring a value across boundaries; it does not provide heap
placement. Orthogonal concern.

**Name**: `Unique` describes the **ownership contract** (exclusive
ownership). This is consistent with Rust's `Unique<T>` (the unstable
stdlib primitive) and with C++'s `std::unique_ptr`. But the more common
colloquialism is:

| Option | Evoked by | Clarity | Tradition |
|--------|-----------|---------|-----------|
| `Ownership.Unique` (current) | Describes the contract: single-owner | Clear once understood; "Unique" is jargon-lite | Rust stdlib (unstable), C++ partial |
| `Ownership.Box` | Describes storage: heap box | Very clear; Rust's stable name | Rust (`Box<T>`); many engineers will reach here first |
| `Ownership.Owner` | Describes the role | Overlaps generic English | Weak |
| `Ownership.Heap` | Describes where it lives | Clear but awkward ("use a Heap of") | Weak |

Argument for `Ownership.Box`: experienced Swift engineers who have
touched Rust will reach for `Box` when they want heap-backed exclusive
ownership. `Unique` requires a docstring read to confirm the same thing.

Argument against `Ownership.Box`: the package already has
`Ownership.Transfer.Box` (type-erased transfer). Two "Box" types in the
same namespace is confusing; one of them would have to rename.

If `Transfer.Box` renames (it arguably should — see #11 below) to
something like `Transfer.Erased`, then `Ownership.Box` frees up for the
Rust-style heap-owned cell, and the package reads more naturally to the
largest set of Swift engineers.

**Name verdict**: CONSIDER rename `Unique` → `Box` if and only if
`Transfer.Box` renames first.

**Merit verdict**: KEEP.

---

### 4. `Ownership.Shared` — KEEP, name CONSIDER

**Merit — position held**: Heap-owned · Read-only · Shared (ARC-multi)
· Sync via immutability · Reference type (`final class`), `~Copyable`
`Value`.

Unique position. `Ownership.Mutable` is the mutable sibling; no other
type in the package is immutable+ARC-shared.

**Region-based-isolation alternative**: none. `sending` is for transfer,
not sharing. A `final class` with `let value: T` is the hand-rolled
equivalent, but Sendable inference blocks on `~Copyable` generic
parameters today — so consumers would write `@unchecked Sendable`
themselves. `Ownership.Shared` concentrates that assertion.

**Sendable analysis (v2.1.0 — updated after revalidation)**: the
originally-documented Category D / SP-4 classification — "class is
structurally Sendable but `~Copyable` generic blocks the compiler's
inference" — was **refuted on Swift 6.3.1** by
`swift-institute/Experiments/noncopyable-generic-sendable-inference/`.
The compiler accepts `final class Shared<Value: ~Copyable & Sendable>: Sendable`
with `let value: Value` as plain, checked `Sendable`. The package now
uses plain `Sendable` with no `@unchecked` escape hatch.

**Name**: "Shared" describes the ownership multiplicity (shared among
multiple owners). But `Ownership.Mutable` is ALSO shared (ARC
multi-owner). The asymmetry — one name emphasises *sharing*, the other
*mutability* — is a real ambiguity.

Alternatives:

| Naming scheme | Immutable | Mutable | Clarity |
|---------------|-----------|---------|---------|
| Current | `Shared` | `Mutable` | Asymmetric — both are shared |
| Explicit pair | `Shared.Immutable` | `Shared.Mutable` | Symmetric; adds a layer of nesting; Mutable.Unchecked becomes `Shared.Mutable.Unchecked` |
| Drop "Shared" | `Immutable` | `Mutable` | Symmetric; but `Immutable` is too generic |
| Rust-style | `Rc` | `RcMut` | Unfamiliar to Swift-first readers |
| Const + Mutable | `Const` | `Mutable` | Swift doesn't use "const"; also asymmetric (Const ≠ immutable class reference) |

The Explicit pair (`Shared.Immutable` / `Shared.Mutable` / `Shared.Mutable.Unchecked`)
is the cleanest. It would be a 0.1.0 API-shape change from today.

Counter: `Shared` + `Mutable` is the pattern inherited from
`Reference.Box` + `Reference.Indirect`. The rename to `Shared` + `Mutable`
happened when the types moved into `Ownership`. Another rename pre-0.1.0
is possible but has a diminishing-returns feel.

**Name verdict**: CONSIDER reshaping to `Shared.Immutable` / `Shared.Mutable`
for symmetry. Higher effort than other name considerations in this
research because it affects all 13 current consumers of `Shared` + 19 of
`Mutable`. Leaving as-is is also acceptable — the current asymmetric
names have precedent and downstream consumers; the asymmetry is a
readability wart, not a correctness issue.

**Merit verdict**: KEEP.

---

### 5. `Ownership.Mutable` — KEEP, name CONSIDER (paired with #4)

**Merit — position held**: Heap-owned · Mutable · Shared (ARC-multi) ·
No sync (NOT Sendable by design) · Reference type (`final class`),
`~Copyable` `Value`.

Unique position. The mutable sibling of `Shared`. Explicitly non-Sendable
— the design philosophy is "mutable-shared-without-synchronization is
intra-isolation only; cross-isolation needs a `Mutex` or actor".

**Region-based-isolation alternative**:
- For **intra-isolation** multi-ref mutable state: stdlib has no analog.
  A `final class` with `var value: T` works but loses the policy nudge
  toward non-Sendable-by-default.
- For **cross-isolation** multi-ref mutable state: use `Mutex<T>` (stdlib
  `Synchronization`). Mutable is intentionally the wrong tool for that
  case.

**Name**: "Mutable" — see discussion under #4.

**Name verdict**: CONSIDER pair-rename with `Shared` for symmetry.
**Merit verdict**: KEEP.

---

### 6. `Ownership.Mutable.Unchecked` — KEEP (BUT PLAN FOR SE-0518), name CORRECT

**Merit — position held**: Heap-owned · Mutable · Shared (ARC-multi) ·
Sync via caller assertion · Reference wrapper, wrapping `Ownership.Mutable`.

Unique position — the explicit `@unchecked Sendable` opt-in for the
non-Sendable `Mutable` wrapper. Category C per [MEM-SAFE-024].

**Region-based-isolation alternative**: this IS the class of use that
SE-0518 `~Sendable` is designed to replace. When `~Sendable` stabilises,
the pattern becomes: mark the state `~Sendable` directly, and use
explicit `unsafe` at each transfer site. `Ownership.Mutable.Unchecked`
concentrates that `unsafe` assertion in a wrapper type today.

**Name**: `Unchecked` is Swift's conventional suffix for "bypasses
compiler checking" (e.g., stdlib's `Swift.Unchecked` conversions). Nested
inside `Ownership.Mutable`, the qualified name reads
`Ownership.Mutable.Unchecked` — clear.

**Name verdict**: CORRECT.
**Merit verdict**: KEEP at 0.1.0. Plan deprecation path when SE-0518
stabilises: DocC migration note → `@available(*, deprecated)` → removal.

---

### 7. `Ownership.Slot` — KEEP, name CORRECT

**Merit — position held**: Heap-owned · Mutable · Reusable (cycles
between empty and full) · Atomic sync (state machine) · Reference type,
`~Copyable` `Value`.

Unique position. The reusable atomic single-value channel/slot. Rust's
closest is `Cell<T>` (interior-mutability, single-thread) + atomic work
queues (thread-safe). Swift stdlib has no direct analog; `AsyncChannel`
is heavier.

**Region-based-isolation alternative**: none for the reusable-slot case.
`sending` is one-shot; `Slot` is reusable. `AsyncChannel` also works but
requires async context + continuations.

**`@unsafe @unchecked Sendable` analysis**: Category A (synchronized
via `Atomic<UInt8>` state machine + release/acquire publication). This
is the **correct** use of `@unchecked` per [MEM-SAFE-024] — the class
IS its own synchronization mechanism.

**Name**: `Slot` evokes "one slot that can be filled or empty" — exactly
the semantic. No ambiguity with other slot-like concepts in Swift
stdlib.

**Name verdict**: CORRECT.
**Merit verdict**: KEEP.

---

### 8. `Ownership.Slot.Move` — KEEP, name OK-BUT-DEBATABLE

**Merit — position held**: Fluent accessor for the trapping
store/take pair. Not a standalone type — provides `slot.move.in(_)` and
`slot.move.out`.

**Name**: `Move` captures the one-way transfer (value moves into, value
moves out of). Alternatives:

| Option | Reads as |
|--------|----------|
| `Slot.Move` (current) | `slot.move.in(x)` / `slot.move.out` — evokes "moving a value" |
| `Slot.Exchange` | `slot.exchange.in(x)` — evokes CAS/atomic exchange |
| `Slot.Transfer` | `slot.transfer.in(x)` — overlaps with `Ownership.Transfer` |

Current is fine; `Exchange` would be more precise about the atomic
nature but `Move` is more natural at call sites.

**Name verdict**: OK.
**Merit verdict**: KEEP.

---

### 9. `Ownership.Slot.Store` — KEEP, name QUESTION (duplicate verb)

**Merit — position held**: Result enum for the total `slot.store(_)`
operation. `.stored` vs `.occupied(Value)`.

**Name**: `Store` is the name of the OPERATION (`slot.store(x)`) AND the
RESULT TYPE (`Slot.Store` enum). That's the overloading that Swift
conventions call out:

- `slot.store(x)` — verb.
- `switch slot.store(x) { case .stored: … case .occupied: … }` — the
  result type named `Store`.

Parallel structure exists (`.store(x) -> .Store`) but can confuse.

Alternatives:

| Option | Reads as |
|--------|----------|
| `Slot.Store` (current) | `slot.store(x) -> Slot.Store` — noun-verb-noun |
| `Slot.Outcome` | `slot.store(x) -> Slot.Outcome` — single noun for result |
| `Slot.Store.Result` | `slot.store(x) -> Slot.Store.Result` — nested under Store |
| `Slot.Store.Outcome` | Same pattern, different leaf |
| `Slot.Stored` (past participle) | `slot.store(x) -> Slot.Stored` — describes "what happened" |

The stdlib has parallel constructions — `Atomic.compareExchange` returns
a tuple, not a named type. But where a named result is needed, the
convention is the past-participle (`Slot.Stored`) or a disambiguating
noun (`Slot.Outcome`, `Slot.StoreResult`).

**Name verdict**: CONSIDER rename `Slot.Store` → `Slot.Outcome` or
`Slot.Stored` to break the verb/noun collision.

**Merit verdict**: KEEP.

---

### 10. `Ownership.Transfer` (namespace enum) — KEEP, name CORRECT

**Merit — position held**: Namespace for one-shot cross-boundary ownership
transfer primitives.

**Name**: `Transfer` is the canonical term for "ownership moves across a
boundary" in Rust (`std::move`), Swift 6 (SE-0430 `sending`), operating
systems (thread hand-off). No ambiguity.

**Name verdict**: CORRECT.
**Merit verdict**: KEEP.

---

### 11. `Ownership.Transfer.Cell` — KEEP, name CONSIDER (paired with #12)

**Merit — position held**: One-shot transfer · Outbound direction (value
exists, ship it out) · `~Copyable` wrapper with `Copyable` token.

Unique position along the direction axis. The namespace table:

| Direction | Type |
|-----------|------|
| Outbound (value exists, consumer takes) | `Transfer.Cell` |
| Inbound (slot exists, producer stores) | `Transfer.Storage` |
| Outbound specialisation for AnyObject | `Transfer.Retained` |
| Outbound type-erased | `Transfer.Box` |

**Region-based-isolation alternative**: `sending T` parameter covers
Swift-Task boundaries. Does NOT cover pthread boundaries (OS threads
spawned outside Swift's concurrency runtime). The Transfer.* family is
for the latter case.

**Name**: `Cell` is ambiguous across languages:

| Cell in | Means |
|---------|-------|
| Rust | Interior mutability (non-atomic, single-thread) |
| This package | One-shot outbound transfer across `@Sendable` |
| Spreadsheet metaphor | A slot of data |

A Swift engineer coming from Rust might expect `Cell` to mean interior
mutability and be surprised. But an engineer without Rust baggage sees
it as "a cell with a value inside; take it out on the other side" —
which matches.

Alternative names:

| Option | Reads as |
|--------|----------|
| `Transfer.Cell` (current) | `Transfer.Cell(value)` |
| `Transfer.Outgoing` | `Transfer.Outgoing(value)` — direction-named, symmetric with `Incoming` |
| `Transfer.Send` | `Transfer.Send(value)` — action-named |
| `Transfer.Envelope` | `Transfer.Envelope(value)` — metaphor for boundary-crossing |

The symmetry win is `Outgoing` / `Incoming` if `Storage` also renames
(see #12). Today's asymmetry — `Cell` and `Storage` don't pair at the
name level — is a real readability wart.

**Name verdict**: CONSIDER rename `Cell` → `Outgoing` if and only if
`Storage` renames to `Incoming`. Paired rename or no rename.

**Merit verdict**: KEEP.

---

### 12. `Ownership.Transfer.Storage` — KEEP, name QUESTION (pair with #11)

**Merit — position held**: One-shot transfer · Inbound direction (slot
exists, producer deposits a value) · `~Copyable` wrapper with `Copyable`
token.

Unique position — the INVERSE direction of `Transfer.Cell`. Zero ecosystem
usage today (per the v1.0.0 inventory) but merit is independent of
adoption: the inbound direction exists in the ownership lattice, and if
a consumer needs "create a value inside a pthread and pick it up after
the thread joins," this is the type they want.

**Region-based-isolation alternative**: `sending T` return value from a
Task or actor method covers the equivalent direction, but requires
structured concurrency. For pthread-style "spawn, then join, then read"
patterns, `Transfer.Storage` is the direct tool.

**Name**: "Storage" is generic — it could describe any heap storage.
The fact that it's an **inbound transfer** slot is NOT evoked by the name.

Alternatives:

| Option | Reads as |
|--------|----------|
| `Transfer.Storage` (current) | Too generic |
| `Transfer.Incoming` | Direction-named; symmetric with `Outgoing` |
| `Transfer.Receive` | Action-named; symmetric with `Send` |
| `Transfer.Inbox` | Metaphor-named; symmetric with... `Outbox`? |
| `Transfer.ReverseCell` | Clarifies relationship but clunky |

**Name verdict**: RENAME `Storage` → something directionally paired
with `Cell` (or paired rename of both). Current name fails the "what do
you expect?" test — an engineer seeing `Ownership.Transfer.Storage`
cannot guess the direction.

**Merit verdict**: KEEP. The inverse-direction position is real and
should be filled; the name just needs fixing.

---

### 13. `Ownership.Transfer.Retained` — KEEP, name CORRECT-IN-DOMAIN

**Merit — position held**: One-shot transfer · Outbound · AnyObject
specialisation · Zero-allocation (uses `Unmanaged.passRetained`).

Unique position — the AnyObject-specialised, zero-alloc outbound
transfer. Distinct from `Transfer.Cell` by the heap-allocation cost
(Cell uses ARC-box; Retained uses `Unmanaged`).

**Region-based-isolation alternative**: `sending T: AnyObject` for Task
boundaries. For pthread boundaries, `Unmanaged` is the raw mechanism;
`Retained` is the typed wrapper.

**Name**: `Retained` matches Swift stdlib's vocabulary around `Unmanaged`
(`passRetained` / `takeRetainedValue`). An engineer seeing the name
immediately knows it's about manual retain balance — correct intuition.

**Name verdict**: CORRECT (within the Swift `Unmanaged` vocabulary
cluster).

**Merit verdict**: KEEP. Zero-alloc specialisation is a genuine
performance argument in executor hot paths.

---

### 14. `Ownership.Transfer.Box` — KEEP, name INCORRECT (rename strongly recommended)

**Merit — position held**: One-shot transfer · Type-erased (no generic
parameter on the slot) · For opaque-pointer interop (C `void*` context
pointers).

Unique position — the type-erasure specialisation of the Transfer family.
Distinct from `Cell` because the consumer side doesn't know `T` (opaque
pointer scenarios).

**Region-based-isolation alternative**: raw `Unmanaged.toOpaque()` +
`fromOpaque()`. That's lower-level. `Transfer.Box` wraps it into an
ownership-aware type.

**Name**: `Box` is heavily overloaded:

| Box in | Means |
|--------|-------|
| Rust | **Heap-owned exclusive cell** (Rust's `Box<T>`) |
| This package | **Type-erased transfer slot** |
| English metaphor | "Putting a value in a box" — ambiguous |

The Rust meaning is diametric to the current use: Rust's `Box<T>` is
what THIS package calls `Ownership.Unique`. Calling our type-erased
transfer slot `Box` invites the exact misreading.

Alternatives:

| Option | Reads as |
|--------|----------|
| `Transfer.Box` (current) | Confuses with Rust's Box |
| `Transfer.Erased` | Describes the type-erasure |
| `Transfer.Opaque` | Describes opacity (C-interop) |
| `Transfer.VoidPointer` | Overly literal |
| `Transfer.Anonymous` | Describes the type-anonymity |

`Transfer.Erased` is the cleanest. It says what the type is (erased),
doesn't collide with Rust's `Box`, and if `Ownership.Unique` later
renames to `Ownership.Box` (per #3), no conflict arises.

**Name verdict**: RENAME `Transfer.Box` → `Transfer.Erased`.

**Merit verdict**: KEEP.

---

## Completeness Analysis

Does the package cover the full ownership domain? Enumerate the
principled points in the 5-axis lattice:

| Lifetime | Mutability | Ownership | Sync | Copyability | Covered by |
|----------|-----------|-----------|------|-------------|------------|
| Scoped | Read-only | Exclusive (within scope) | None | Copyable wrapper | ``Borrow`` |
| Scoped | Mutable | Exclusive | None | `~Copyable` wrapper | ``Inout`` |
| Heap-owned | Mutable | Exclusive | None (Sendable by owner-uniqueness) | `~Copyable` wrapper | ``Unique`` |
| Heap-owned | Read-only | Shared (ARC) | Immutability | Reference | ``Shared`` |
| Heap-owned | Mutable | Shared (ARC) | None (intra-isolation) | Reference | ``Mutable`` |
| Heap-owned | Mutable | Shared (ARC) | Caller-asserted | Reference wrapper | ``Mutable.Unchecked`` |
| Heap-owned | Reusable | Atomic-cycled | Atomic | Reference | ``Slot`` |
| Transferred | Mutable | Outbound · any `~Copyable` | Atomic CAS | `~Copyable` wrapper | ``Transfer.Cell`` |
| Transferred | Mutable | Inbound · any `~Copyable` | Atomic CAS | `~Copyable` wrapper | ``Transfer.Storage`` |
| Transferred | Mutable | Outbound · `AnyObject` specialisation | Unmanaged retain | `~Copyable` wrapper | ``Transfer.Retained`` |
| Transferred | Mutable | Outbound · type-erased | Closure-erased | Reference wrapper | ``Transfer.Box`` |

### Gaps

Candidates for inclusion and their verdicts:

| Candidate | Why it could belong | Verdict |
|-----------|---------------------|---------|
| Transferred · Inbound · AnyObject specialisation | Mirror of `Transfer.Retained` on the inbound axis | **Gap** — could add `Transfer.Storage.Retained` (or `Incoming.Retained` under the rename scheme) for zero-alloc inbound class transfer |
| Transferred · Inbound · type-erased | Mirror of `Transfer.Box` on the inbound axis | **Gap** — could add `Transfer.Erased` inbound |
| Pinned ownership | Rust has `Pin<T>` for address-stable values | **Not needed** — Swift's stdlib types are inherently pinned when lifetime-managed by the compiler; no user-facing pinning concept exists |
| Lazily-initialised shared | `Ownership.Lazy` for deferred construction | **Not ownership** — belongs in a separate package or is just `let x = { ... }()` |
| Copy-on-write wrapper | `Ownership.CoW<T>` | **Not here** — CoW is a value-type concern (class-backed storage with `isKnownUniquelyReferenced`), not ownership. Probably `swift-copy-on-write-primitives` if wanted. |
| Weak / Unowned reference | `Weak<T>`, `Unowned<T>` | **Not here** — lives in `swift-reference-primitives`. That package explicitly owns non-owning references. |
| Lock-protected shared mutable | `Ownership.Locked<T>` | **Not here** — stdlib `Mutex<T>` covers it |

**Two genuine gaps** (now closed):

1. **Inbound AnyObject transfer** — mirror of the outgoing retained
   path. Shipped as ``Transfer.Retained<T>.Incoming``.
2. **Inbound type-erased transfer** — mirror of the outgoing erased
   path. Shipped as ``Transfer.Erased.Incoming``.

Both complete the symmetry of the Transfer family at 15 total ownership
types. The `Outgoing` / `Incoming` direction axis makes the complete
matrix structurally visible; the kind axis (`Value<V>`, `Retained<T>`,
`Erased`) anchors each cell's payload identity.

### Claims not to make

The package does NOT cover:

- **Weak / unowned / non-owning**: `swift-reference-primitives` territory.
- **Lazy / memoized**: separate concern.
- **Lock-protected shared mutable**: stdlib `Mutex` covers it.

These are correctly out of scope.

## Naming Summary

| Type | Current name | Verdict | Recommended action |
|------|--------------|---------|-------------------|
| `Ownership.Borrow` | `Borrow` | CORRECT | none |
| `Ownership.Inout` | `Inout` | CORRECT | none |
| `Ownership.Unique` | `Unique` | DEBATE | rename to `Box` if and only if `Transfer.Box` is renamed first (see below) |
| `Ownership.Shared` | `Shared` | DEBATE (asymmetric with `Mutable`) | optional pair-rename to `Shared.Immutable` / `Shared.Mutable` / `Shared.Mutable.Unchecked` |
| `Ownership.Mutable` | `Mutable` | DEBATE | pair-rename with `Shared` |
| `Ownership.Mutable.Unchecked` | `Unchecked` | CORRECT | none (plan deprecation for SE-0518) |
| `Ownership.Slot` | `Slot` | CORRECT | none |
| `Ownership.Slot.Move` | `Move` | OK | none |
| `Ownership.Slot.Store` | `Store` | QUESTION | CONSIDER rename to `Slot.Outcome` or `Slot.Stored` to break the verb/noun collision |
| `Ownership.Transfer` | `Transfer` | CORRECT | none |
| `Ownership.Transfer.Cell` | `Cell` | DEBATE | pair-rename `Cell` / `Storage` → `Outgoing` / `Incoming` for direction clarity |
| `Ownership.Transfer.Storage` | `Storage` | INCORRECT (too generic, not directionally evocative) | pair-rename per above |
| `Ownership.Transfer.Retained` | `Retained` | CORRECT (in Swift `Unmanaged` vocabulary) | optional rename under direction scheme: `Outgoing.Retained` |
| `Ownership.Transfer.Box` | `Box` | INCORRECT (collides with Rust's heap-owned Box) | **rename to `Transfer.Erased`** (strong recommendation) |

### Rename clusters (decide as groups)

**Cluster A: Transfer.Box rename (high-priority standalone)**:
- `Transfer.Box` → `Transfer.Erased`
- Motivation: the name `Box` has a diametric meaning in Rust (heap-owned
  exclusive cell = our `Unique`). Calling our type-erased slot `Box`
  invites misreading.
- Cost: rename one type in one target. Downstream consumers: zero
  direct (per v1.0.0 inventory). Low blast radius.
- **Recommended**.

**Cluster B: Transfer direction rename (optional, higher blast radius)**:
- `Transfer.Cell` → `Transfer.Outgoing`
- `Transfer.Storage` → `Transfer.Incoming`
- `Transfer.Retained` → `Transfer.Outgoing.Retained` (nested)
- Motivation: expose the direction in the name; make the inbound/outbound
  pairing visible; set up for adding `Incoming.Retained` and
  `Incoming.Erased` later to fill the completeness gaps.
- Cost: renames 3+ types, affects 1 real consumer (`Kernel.Thread.spawn`)
  + executor files (`Executor.Scheduled`, etc.) via `Retained`.
- Benefit: the name asymmetry Storage vs Cell disappears; the Transfer
  family becomes a coherent outbound/inbound-by-AnyObject/~Copyable/erased
  matrix.
- **Recommended if the user wants the rename effort**.

**Cluster C: Unique → Box rename (only after Cluster A)**:
- `Ownership.Unique` → `Ownership.Box`
- Motivation: Rust-level familiarity; `Box<T>` is the most common name
  for heap-owned exclusive cell in cross-language Swift literature.
- Precondition: Cluster A must ship first (otherwise `Ownership.Box`
  ambiguous with `Transfer.Box`).
- Cost: zero direct downstream consumers (v1.0.0 inventory) but the
  type IS in the doc table everyone reads.
- **Optional**.

**Cluster D: Shared / Mutable symmetry rename (optional, highest blast radius)**:
- `Ownership.Shared` → `Ownership.Shared.Immutable`
- `Ownership.Mutable` → `Ownership.Shared.Mutable`
- `Ownership.Mutable.Unchecked` → `Ownership.Shared.Mutable.Unchecked`
- Motivation: both types are ARC-shared; the only distinguishing axis
  is mutability, so the names should read that way.
- Cost: biggest — affects 13 + 19 + ~0 = 32+ call sites across the ecosystem.
- **Not recommended for 0.1.0** — diminishing returns vs Cluster A/B.

**Cluster E: Slot.Store result rename (low impact, optional)**:
- `Ownership.Slot.Store` (result enum) → `Ownership.Slot.Outcome`
  (or `Ownership.Slot.Stored`)
- Motivation: break the `slot.store(_) -> Slot.Store` verb/noun collision.
- Cost: tiny — the result enum is only mentioned in `Slot.Store` pattern
  matches.
- **Optional**.

## Outcome

**Status**: RECOMMENDATION.

### Revised verdict (supersedes v1.0.0)

**Keep every type**. The package is positioned as total for ownership,
and each type holds a unique position in the 5-axis lattice. Usage
absence (`Transfer.Storage`, `Transfer.Box`) is not grounds for removal
when the type fills a distinct position — the package exists to make
the ownership domain queryable by SHAPE, not by current uptake.

### @unchecked Sendable verdict

The user's concern is addressed:

- **Category A (synchronized)**: `Slot`, `_Box`, `Box.Pointer` — correct
  `@unchecked` use per [MEM-SAFE-024]. Region-based isolation cannot
  replace internal atomic synchronization.
- **Category B (ownership transfer)**: `Unique`, `Retained` — `~Copyable`
  exclusive ownership is its own sync mechanism. Not replaceable.
- **Category C (thread-confined, caller-asserted)**: `Mutable.Unchecked`
  — this IS the class replaceable by SE-0518 `~Sendable` + scoped
  `unsafe`. DEFER until `~Sendable` stabilises; then deprecate with a
  migration path.
- **Category D (structural workaround)**: empty. `Shared` was the
  only instance in the v2.0.0 classification; v2.1.0 refuted the
  underlying claim and `Shared` moved to plain checked `Sendable`.

Only **Category C** is a region-based-isolation alternative. The rest
are structural or synchronisation-internal.

### Naming actions to consider

Ordered by cost/benefit (highest-value first):

1. **`Transfer.Box` → `Transfer.Erased`** (Cluster A). Diametric
   collision with Rust. Low blast radius. Recommended.
2. **`Slot.Store` (result enum) → `Slot.Outcome`** (Cluster E). Low cost.
3. **Transfer direction rename** (Cluster B): `Cell` → `Outgoing`,
   `Storage` → `Incoming`, `Retained` → `Outgoing.Retained`. Surfaces the
   completeness gaps (inbound-Retained, inbound-Erased) and improves
   symmetry.
4. **`Unique` → `Box`** (Cluster C). Depends on Cluster A. Familiar to
   Rust-touched Swift engineers.
5. **`Shared` / `Mutable` symmetry** (Cluster D). Defer.

### Completeness gaps

Two narrow gaps if the package is to be truly total:

1. Inbound AnyObject transfer — shipped as `Transfer.Retained<T>.Incoming`.
2. Inbound type-erased transfer — shipped as `Transfer.Erased.Incoming`.

Both ship under the kind-namespace × direction matrix (Cluster B
landing refined to place the generic at the kind layer; see
`naming-transfer-direction-pair.md` Historical note).

**Landed in 0.1.0**: Clusters A + B + C + E (A1 + A2 + A3 + A5 + B1 +
B2) plus the Latch (Phase 1) and Indirect (Phase 2) additions. Cluster
D (Shared / Mutable symmetry rename) kept deferred per research-grade
recommendation (see `naming-shared-mutable-symmetry.md`).

## Appendix: usage inventory (v1.0.0 data)

Retained for reference. Usage counts do NOT drive the v2.0.0 verdicts.

| Type | File count (non-own-package) |
|------|------------------------------|
| `Borrow` | 4 direct + 1 structural |
| `Inout` | 2 structural |
| `Unique` | 1 (backward-compat doc) |
| `Shared` | 13 files |
| `Mutable` | 19 files (14 in one package) |
| `Mutable.Unchecked` | 0 |
| `Slot` | 16 files |
| `Transfer.Cell` | 3 files (1 real consumer) |
| `Transfer.Storage` | 0 |
| `Transfer.Retained` | 6 files (executor infra) |
| `Transfer.Box` | 0 |

Grep scope: swift-primitives/, swift-standards/, swift-foundations/,
swift-institute/Experiments/. Files in .build/, Research/, _index.json
excluded.

## References

- Swift Evolution SE-0519 — Builtin Borrow and Inout
- Swift Evolution SE-0507 — BorrowAndMutateAccessors
- Swift Evolution SE-0430 — `sending` regions
- Swift Evolution SE-0518 — `~Sendable`
- Rust `std::boxed::Box<T>` — heap-owned exclusive cell
- Rust `std::cell::Cell<T>` — interior mutability (non-atomic)
- Rust `std::sync::atomic` — reusable atomic cells
- `swift-reference-primitives/Sources/Reference Primitives/Reference.swift` — documents the Reference → Ownership rename
- `swift-institute/Research/noncopyable-ecosystem-state.md` — current state of ~Copyable patterns
- [MEM-SAFE-024] Sendable Category classification (memory-safety skill)
- [API-NAME-001] Nest.Name pattern (code-surface skill)

## Provenance

Commissioned 2026-04-23 pre-0.1.0 tag. v2.0.0 reframes the v1.0.0
usage-centric evaluation to merit+completeness+naming per principal
direction: "judge them on their merits; the package should be total for
ownership; get feedback on whether names are what's expected."
