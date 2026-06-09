# Store.Inline: Span-Based Access vs the In-Place Raw Pointer

<!--
---
version: 1.1.0
last_updated: 2026-06-09
status: ACCEPTED
tier: 2
scope: cross-package
---
-->

## Context

The five-layer tower migration ships an inline typed-storage type
`Store.Inline<Element, n>` (Storage tier,
`swift-primitives/swift-storage-primitives/Sources/Store Inline Primitives/`).
It embeds `@_rawLayout(likeArrayOf: Element, count: n)` bytes inside its own
value footprint and accesses them via a raw pointer **recomputed in-place per
operation** — a fresh `withUnsafePointer(to: _storage)` /
`withUnsafeMutablePointer(to: &_storage)` scope each time, never cached
(`Store.Inline.swift:23-35`, `Store.Inline+Store.Protocol.swift:23-35`). The
reason it is never cached is empirically established: a cached pointer into the
value's own `@_rawLayout` footprint **dangles the instant the value moves** —
the cross-module spike "probe 5" and the rich-fidelity spike "B-finding", and
before them the (now superseded) `swift-set-primitives` `inline-span-investigation`
experiment ("`Span` depends on local variable `ptr`"; `withUnsafePointer(to:)`
creates a closure scope a span cannot escape from).

The heap path (`Storage.Contiguous` over an element-free `Memory.Heap`
allocation) instead caches a `_base` pointer into stable *external* heap bytes
— sound there because the bytes do not move with the value — and vends
`span` / `mutableSpan` / `outputSpan` from it
(`Storage.Contiguous+Span.swift`). The inline case cannot cache a base; the two
paths therefore have *different* access mechanics.

Separately, the ecosystem **previously did substantial work migrating FROM
pointer-based access TO Span-based access** — deleting the
`@unsafe func pointer(at:) -> UnsafeMutablePointer<Element>` requirement from
`Storage.Protocol` and replacing it with a typed slot seam plus a
`Span`/`MutableSpan`/`OutputSpan` whole-region surface
(`Reflections/2026-06-02-storage-protocol-depointer-merge-and-cross-arc-source-break.md`).
The `swift-span-primitives` package now hosts the span-vending capability
(`Span.\`Protocol\``, `Span.Mutable.\`Protocol\``) on a domain-neutral
namespace, with the `borrow self` lifetime contract proven the unifier across
owned and borrowed conformers.

**Trigger**: design question raised during the tower migration — would the
Span/`~Escapable` approach let inline `@_rawLayout` storage be accessed
move-safely WITHOUT raw pointers, replacing the in-place `withUnsafePointer`
approach and aligning `Store.Inline` with the ecosystem's pointer→span
direction?

## Question

Does a `MutableSpan`/`Span` yielded from a `borrowing`/`mutating` accessor —
lifetime-bound (`~Escapable`) to the borrow of `self` — resolve the inline
move-dangle that an escaped raw pointer suffers? Specifically:

1. Does it make `Store.Inline` **fully pointer-free**?
2. Could Span-based access **unify** the inline and heap accessor surfaces
   (both vend a `MutableSpan`), reducing or eliminating the
   `Store.Inline`-vs-`Storage.Contiguous` split?
3. What does `swift-span-primitives` actually provide, and is it consumable
   here?
4. Does `@_rawLayout` storage interoperate with constructing a lifetime-bound
   `MutableSpan` over it on Swift 6.3.2 — the empirical crux?

## Prior Art (internal — cited per [RES-019])

| Document | Carried-forward finding | Verification |
|----------|-------------------------|--------------|
| `nonescapable-support-memory-storage-buffer.md` §III Candidate B, §4.2 | A prior incarnation of `Storage.Inline` **already exposed `.mutableSpan` via `@_lifetime(&self)`** and `.span` via `@_lifetime(borrow self)`, assessed **Sound** (MutableSpan + Property.View cover the inline access patterns; a bespoke `MutableView` is "Not needed"). | Carried forward — this doc re-establishes it empirically on 6.3.2 (probe below). |
| `Reflections/2026-06-02-storage-protocol-depointer-merge…` | The canonical pointer→span migration. Under the *prior* `Storage.Protocol`, `Storage.Inline`'s **silently-unsound** witness was a `MutableSpan` formed from `borrowing self` (an exclusivity violation laundered by `_overrideLifetime`). The fix was a yielding `_modify` over **exclusive `&self`**, which is sound by construction. "When a design frames safety as a trade-off against capability or performance, suspect the framing first." | Verified: 2026-06-09 — the soundness hinge is `&self` exclusivity, confirmed by the exclusivity-violation probe below. |
| `nonescapable-support…` §4.1, line 260 | `_overrideLifetime` is `@unsafe` "returning-model technical debt" (28 sites); the **yielding** `_read`/`_modify` model is "Sound by construction. No `_overrideLifetime` needed." | Carried forward — central to the recommendation's nuance. |
| `swift-span-primitives` `Span.Protocol.swift:130-132` | The `span` requirement's docstring asserts the `borrow self` contract is "Safe for both heap and inline storage." | Verified: 2026-06-09 against source. |
| `swift-span-primitives` `Span.Mutable.Protocol.swift:78-92` | **`mutableSpan` property forwarding through a constrained generic is borrow-walled** ("probe-proven insufficient for generic forwarding … the no-generic-`mutableSpan` gate is structural"). A count-*method* CAN forward. | Carried forward — load-bearing for the unification question (b). |
| `Reflections/2026-04-06-unsafe-pointer-audit-span-migration.md` | Span/MutableSpan are the ecosystem's async-safe view type; the pointer→span migration is "pulling an existing API up through the stack," not designing a new one. | Carried forward (direction-setting). |

The internal corpus already answers the *direction* (Span over pointer) and the
*soundness shape* (yielding `_modify` over `&self`). What it did NOT settle is
whether the **current W2 nested-`@_rawLayout`-struct** `Store.Inline` form can
vend lifetime-bound spans on 6.3.2, and whether doing so removes the raw
pointer. That is what the probe below establishes.

## Empirical Probe (Swift 6.3.2, `org.swift.632202605101a`)

Toolchain confirmed: `Apple Swift version 6.3.2 (swift-6.3.2-RELEASE)`.
Scratch only (`/tmp/inline-span-probe/`); **no real package edited**. The probe
struct mirrors the committed `Store.Inline` exactly — nested
`@_rawLayout(likeArrayOf: Element, count: n)` `_Raw` struct, the
`[MEM-SAFE-027]` `_deinitWorkaround: AnyObject?` first field, a count/ledger,
unconditional `~Copyable`, a deinit oracle — and adds `span` / `mutableSpan`
accessors built from a per-op base (recomputed inside `withUnsafePointer(to:)`),
re-anchored to `self` with `_overrideLifetime`. Features:
`RawLayout`, `LifetimeDependence`, `Lifetimes`.

### (a) Compiles + move-safe at runtime — PASS (debug AND release)

`probe.swift`: mutate through `mutableSpan`, then **`consume`-move the value
into a new binding and use it again** (the case that dangles a cached raw
pointer), then mutate the moved value through *its* span:

```
after mutate via span: 100 200 30
after move + append: 100 200 30 40
after post-move mutate: 400
```

Identical output in `-O` release. The move is safe because the span borrow has
already ended before the `consume`; the post-move accessor recomputes the base
against the value's *current* footprint. This is the same per-op recomputation
the current `Store.Inline` already does — the Span wrapper does not introduce a
cached base.

### (b) The span is genuinely lifetime-bound — PASS (escape rejected)

`escape.swift` — returning the span past the borrow of the local it views:

```
error: a function with a ~Escapable result needs a parameter to depend on
```

The `~Escapable` span cannot escape the accessor's borrow. This is exactly the
guard the escaped raw pointer lacks.

### (c) Exclusivity is enforced — PASS (overlap rejected)

`excl.swift` — two distinct overlap hazards, both **rejected** (the diagnostic
fires in the SIL exclusivity pass, *not* in `-typecheck`; a `-typecheck`-only
run silently passes and must not be relied on):

```
error: overlapping accesses to 'a', but modification requires exclusive access [#ExclusivityViolation]
  // mutate `a` while a span borrow is live
error: overlapping accesses to 'a', but modification requires exclusive access [#ExclusivityViolation]
  // two live mutableSpan borrows into the same value
```

The `mutating get` on `mutableSpan` (`@_lifetime(&self)`) makes a live mutable
span an exclusive borrow of `self`: the value cannot be mutated or moved while
the span is live. This is the move-dangle fix — the borrow *prevents the move*
during the span's lifetime, and the escape check *prevents the span* outliving
the borrow.

### (d) `@_rawLayout` ↔ lifetime-bound span interop — PASS

`@_rawLayout(likeArrayOf: Element, count: n)` storage forms a working
`Swift.Span`/`Swift.MutableSpan` over its element bytes on 6.3.2, via a base
recomputed inside `withUnsafePointer(to:)` and re-anchored with
`_overrideLifetime`. No wall.

**Repro:** `/tmp/inline-span-probe/{probe.swift, escape.swift, excl.swift}`.

### The crux finding: Span makes the surface safe-by-construction, but is NOT pointer-free

The decisive nuance. On 6.3.2 the **only** way to obtain a base address into
`@_rawLayout` inline storage is `withUnsafe[Mutable]Pointer(to: &_storage)` (the
"`Working Paths`"/"`@_rawLayout` element access BLOCKED" finding of
`nonescapable-storage-mechanisms.md`: every path from raw storage to a typed
element requires a pointer type, and pointer `Pointee` is implicitly
`Escapable`; the layout compiles but typed access goes through a pointer). The
Span constructor `Swift.Span(_unsafeStart:count:)` itself takes an
`UnsafePointer`. So a Span-based `Store.Inline` still computes a raw pointer
internally — it does **not** become "pointer-free." What it changes is the
**public access surface and its safety**:

- Today's surface: a typed slot seam (`subscript`/`initialize`/`move`) over a
  per-op pointer — already not vending raw pointers to callers, already
  recompute-per-op, already move-safe.
- Span surface: additionally a `span`/`mutableSpan` whole-region view that is
  `~Escapable`, bounds-checked, lifetime-bound, and enforces exclusivity — at
  the cost of the `_overrideLifetime` `@unsafe` bridge (the acknowledged
  "returning-model technical debt", 28 sites ecosystem-wide).

So the hypothesis's *premise* — "pointer-free by construction" — is **not
literally achievable on 6.3.2** for `@_rawLayout` storage. The achievable and
valuable thing is a **safe-by-construction whole-region view** that replaces
ad-hoc per-op raw access with a bounds-checked, lifetime-/exclusivity-enforced
span, hiding the (irreducible) internal pointer behind a `@_lifetime` contract.

## Analysis

### Option 1 — Keep the in-place-pointer Store.Inline (status quo)

The committed `Store.Inline` (`de84968`) exposes the typed 4-op seam over a
per-op `withUnsafePointer`. Already move-safe (never caches the base). Already
does not vend raw pointers to callers. ~12 `unsafe` expressions, 4
`withUnsafe*` sites, no `_overrideLifetime`.

- **Pros**: Committed and tested; soundness self-evident (per-op borrow);
  zero `_overrideLifetime` debt; no `~Escapable` surface to audit.
- **Cons**: No whole-region span surface — consumers wanting bulk/contiguous
  access (the `Span.\`Protocol\`` capability the ecosystem standardizes on) get
  the slot seam only; *diverges from* the heap path, which DOES vend spans.

### Option 2 — Add Span/MutableSpan accessors to Store.Inline (yielding model)

Add `span` (`@_lifetime(borrow self) get`) and `mutableSpan`
(`@_lifetime(&self) mutating get`) — conforming `Span.\`Protocol\`` and
`Span.Mutable.\`Protocol\`` — over the existing per-op base. Probe-proven to
compile, be move-safe, lifetime-bound, and exclusivity-enforced on 6.3.2.

- **Pros**: Gives `Store.Inline` the same span surface as the heap path;
  conforms the ecosystem capability protocols; safe-by-construction whole-region
  view; aligns with the pointer→span direction.
- **Cons**: Requires the `_overrideLifetime` `@unsafe` bridge (returning-model
  debt). Does NOT make `Store.Inline` pointer-free (the internal
  `withUnsafePointer` remains — it is irreducible for `@_rawLayout` on 6.3.2).
  Revisits committed code (W2/W3-pre).

### Option 3 — Deep unification: one generic accessor surface for inline + heap

Make a single generic discipline vend `MutableSpan` over both inline and heap
storage so `Store.Inline`-vs-`Storage.Contiguous` collapses to one accessor
surface.

- **Blocked at the capability boundary.** `Span.Mutable.Protocol.swift:78-92`
  records the structural wall: **`mutableSpan` *property* forwarding through a
  constrained generic is borrow-walled** ("the no-generic-`mutableSpan` gate is
  structural, not conventional"). A count-*method*
  (`mutableSpan(count:) -> MutableSpan`) CAN forward — which is exactly how a
  growable `Buffer.Linear`/`Buffer.Ring` already vends a mutable span over an
  arbitrary substrate. So a *uniform protocol surface* (both conform
  `Span.Mutable.\`Protocol\``; buffers consume via the count-method) is
  attainable; a *collapse of the two storage types into one* is not — and is
  independently forbidden by `occupancy-lives-in-the-leaf.md` ([the placement
  law], Tier 3, ratified 2026-06-07): inline and heap leaves stay distinct
  leaves; copyability flows from the leaf (inline `@_rawLayout` ⇒ move-only;
  heap class-backed ⇒ conditionally-Copyable). The split is lawful, not
  accidental.
- **Verdict**: uniform *accessor surface* via the capability protocols = yes
  (that is Option 2's conformance, applied to both leaves). Type-level
  *unification* of the leaves = no (capability wall + placement law).

### Comparison

| Criterion | 1: in-place pointer | 2: + Span accessors | 3: deep unification |
|-----------|---------------------|---------------------|----------------------|
| Move-safe | Yes (per-op) | Yes (probe) | n/a |
| Pointer-free | No (per-op `withUnsafePointer`) | **No** (internal ptr irreducible) | No |
| Whole-region span surface | No | Yes | Yes (uniform) |
| `Span.\`Protocol\`` conformance | No | Yes | Yes |
| Matches heap path surface | No | Yes | Yes |
| `_overrideLifetime` debt | None | +bridge sites | +bridge sites |
| Lifetime/exclusivity enforced | n/a (no span) | Yes (probe) | Yes |
| Type-level leaf collapse | — | No | **Blocked** (cap wall + placement law) |
| Touches committed code | No | Yes (flag) | Yes (flag) |

## Outcome

**Status: ACCEPTED (2026-06-09)** — principal ruling, on ChatGPT + seat + research convergence.

**Accepted decision:**
1. **Add `Span`/`MutableSpan` accessors to `Store.Inline`** (additive, object-local), matching the heap `Storage.Contiguous` span surface.
2. **Span is the canonical public contiguous-region surface;** the in-place raw-pointer coroutines become internal/underscored.
3. **Keep the per-slot typed seam public** (`subscript`/`initialize(at:to:)`/`move(at:)`) — region-view (Span) and element-lifecycle (seam) are distinct concerns, NOT competitors.
4. **No type-level unification** of `Store.Inline` and `Storage.Contiguous` (shared *operation* surface ≠ shared *object* identity — Non-Collapse).
5. **Consumer-driven** — land in W3/W4 when a buffer/ADT first wants the uniform span surface across heap+inline; not speculative. Prefer the yielding `_read`/`_modify` model (no `_overrideLifetime` debt) where the access pattern allows.

**Pointer-freedom is a *surface* invariant**, not a leaf one: consumers see only non-escaping spans; the leaf's wrapped `UnsafePointer` is irreducible on Swift 6.3.2 and auto-improves (no API churn) once SE-0465 lands. **Naming:** the inline type is `Store.Inline<Element, n>` (the W2 "C" ruling — avoids the phantom `Allocation` of `Storage<Allocation>.Contiguous<Element>.Inline`); the accessor is the object-local `Store.Inline.mutableSpan` (ChatGPT's "accessor on the relevant object" concern, satisfied).

---


**The Span/`~Escapable` approach resolves the inline move-dangle as a *safety
property of a whole-region view*, but it does NOT make `Store.Inline`
pointer-free, and it does NOT unify the inline and heap *types*.** Precisely:

- **Move-dangle**: resolved. A `mutableSpan` under `@_lifetime(&self)` is an
  exclusive borrow — the value cannot move while the span is live (probe c), and
  the span cannot escape the borrow (probe b). This is the guard the escaped raw
  pointer lacked. But note the current `Store.Inline` is *already* move-safe
  via per-op recomputation; Span does not *fix a present bug*, it adds a
  *safe-by-construction whole-region surface* the slot seam lacks.
- **Pointer-free (a)**: NO. `@_rawLayout` typed access is irreducibly via a
  pointer on 6.3.2 (`nonescapable-storage-mechanisms.md`); `Swift.Span` is
  itself constructed from an `UnsafePointer`. The internal `withUnsafePointer`
  remains. The premise "move-safe by construction AND pointer-free" is half
  true: safe-by-construction at the surface, not pointer-free underneath.
- **Unification (b)**: a uniform *accessor surface* via `Span.\`Protocol\`` /
  `Span.Mutable.\`Protocol\`` is attainable (both leaves conform; buffers
  consume the forward-able `mutableSpan(count:)` method). Type-level
  *unification* of `Store.Inline` and `Storage.Contiguous` is **blocked** by the
  documented `mutableSpan`-property generic-forwarding wall AND by
  `occupancy-lives-in-the-leaf.md`'s ratified placement law (distinct leaves;
  copyability flows from the leaf).
- **Consumability (c)**: `swift-span-primitives` provides the `Span.\`Protocol\``
  (read, `@_lifetime(borrow self)`) and `Span.Mutable.\`Protocol\`` (mutable,
  `@_lifetime(&self) mutating get`, plus the forward-able `mutableSpan(count:)`
  method) capabilities, domain-neutral over the stdlib `Swift.Span` family.
  `OutputSpan`/`RawSpan` sub-namespaces are declared-but-deferred ("ship when a
  conformer needs them"). It is consumable here; the heap path already consumes
  the equivalent surface.
- **`@_rawLayout` interop (d)**: PASS on 6.3.2.

### Recommendation for the tower

**Adopt Option 2 — add `span`/`mutableSpan` (and, if a consumer needs the
uninitialized-tail append, `outputSpan`) accessors to `Store.Inline`,
conforming `Span.\`Protocol\`` / `Span.Mutable.\`Protocol\``, using the
yielding-where-possible model — driven by an actual consumer need, not
speculatively.** Rationale, per [RES-022] (structural correctness dominates):
the heap path vends spans; uniform capability conformance across the two leaves
is the structurally-correct surface, and it is the ecosystem's standardized
access capability. **Do NOT pursue Option 3's type-level collapse** — it is
walled and law-forbidden; the leaves stay distinct.

Two caveats that downgrade this from "do it now" to "do it when a consumer
needs it":

1. **It is not the pointer elimination the hypothesis hoped for.** The internal
   `withUnsafePointer` is irreducible on 6.3.2; Option 2 buys a *safe view
   surface*, not pointer-freedom. If the only goal were "remove the raw
   pointer," Option 2 does not achieve it (REMOVE-WHEN: stdlib adds `~Escapable`
   pointer pointees per SE-0465 deferral — then `@_rawLayout` typed access could
   become genuinely pointer-free; track it).
2. **`_overrideLifetime` is acknowledged returning-model debt.** Prefer the
   yielding `_read`/`_modify` model (sound *without* `_overrideLifetime`,
   per `nonescapable-support…` §4.2.3) wherever the consumer's access pattern
   allows it; reserve the returning `span`/`mutableSpan` properties (which need
   the bridge) for the whole-region cases where a yield does not fit. The
   committed slot seam (`subscript`/`initialize`/`move`) is already a yielding
   `_read`/`_modify` surface and should remain.

### Does this recommend changing the committed `Store.Inline`?

**Yes — explicitly flagged.** `Store.Inline` is built and committed
(`de84968` W3-pre, plus W2 hygiene `69aa0c5`/`b4b66fe`). Option 2 *adds*
accessors to it (a `+Span.swift` extension conforming the capability protocols);
it does not rewrite the existing slot seam. **This is a recommendation only —
per the dispatch ground rules, no source was edited and this revisiting of
committed code requires explicit principal authorization before any
implementation.** It is additive and low-risk (new accessors, existing seam
untouched), but it does touch a W2/W3-committed package and so must be a
deliberate, consumer-driven decision, not an automatic follow-on.

## References

- `swift-primitives/swift-storage-primitives/Sources/Store Inline Primitives/Store.Inline.swift` — the committed in-place-pointer `Store.Inline`.
- `swift-primitives/swift-storage-primitives/Sources/Storage Contiguous Primitives/Storage.Contiguous+Span.swift` — the heap-path span/mutableSpan/outputSpan accessors (the surface to match).
- `swift-primitives/swift-span-primitives/Sources/Span Protocol Primitives/{Span.Protocol,Span.Mutable.Protocol}.swift` — the capability protocols; the `mutableSpan`-property generic-forwarding wall (`:78-92`).
- `swift-institute/Research/nonescapable-support-memory-storage-buffer.md` — prior `Storage.Inline.mutableSpan`-was-Sound finding (Candidate B, §4.2); `_overrideLifetime`-as-debt; yielding-is-sound-by-construction.
- `swift-institute/Research/nonescapable-storage-mechanisms.md` — `@_rawLayout` typed access is irreducibly pointer-mediated on current toolchains (the "pointer-free" blocker); SE-0465 pointer-pointee deferral.
- `swift-institute/Research/occupancy-lives-in-the-leaf.md` — Tier 3 placement law: inline/heap leaves stay distinct; copyability flows from the leaf (blocks Option 3 type collapse).
- `swift-institute/Research/Reflections/2026-06-02-storage-protocol-depointer-merge-and-cross-arc-source-break.md` — the canonical pointer→span migration; the inline `&self`-exclusivity soundness hinge.
- `swift-institute/Research/Reflections/2026-04-06-unsafe-pointer-audit-span-migration.md` — Span as the ecosystem's safe view type; migration is pulling an existing API up the stack.
- `/Users/coen/Developer/.handoffs/HANDOFF-tower-cross-module-spike.md` (probe 5) and `HANDOFF-tower-rich-fidelity-spike.md` (B-finding) — the inline move-dangle empirical record this doc builds on.
- Probe repro: `/tmp/inline-span-probe/{probe.swift, escape.swift, excl.swift}` (Swift 6.3.2, `org.swift.632202605101a`).
- SE-0446 (Nonescapable Types); SE-0465 (Nonescapable Standard Library Primitives — pointer-pointee deferral); SE-0527 (OutputSpan).
