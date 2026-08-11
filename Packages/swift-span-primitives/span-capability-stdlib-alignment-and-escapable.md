# Span Capability — Standard-Library Alignment and the ~Escapable Question

<!--
---
version: 1.0.0
last_updated: 2026-06-23
status: RECOMMENDATION
tier: 2
scope: null
builds_on:
  - "swift-institute/Research/memory-byte-bit-domain-orthogonality.md — the lift of the span capability out of the Memory namespace; the original owned/borrowed split."
  - "swift-institute/Research/cross-layer-capability-protocol-model.md §12 + v1.5.0 — the lattice + the 2026-06-04 Unify currency note (Span.Mutable.Protocol 'stands unchanged')."
  - "swift-institute/Research/nonescapable-support-memory-storage-buffer.md (DECISION) — ~Escapable is surgical; owners stay Escapable."
  - "swift-institute/Research/iterable-se0516-alignment.md — the ITERATOR counterpart: institute Iterable ↔ SE-0516 (formerly BorrowingSequence)."
  - "Experiments/span-typealias-hosting/ — the typealias/hosting redesign whose mutable-linchpin step this doc informs."
changelog:
  - "1.0.0 (2026-06-23): Initial. Maps Span.Protocol ↔ stdlib ContiguousStorage (SE-0447, deferred); records the @_lifetime-requirement convergence (SE-0516); read-linchpin is stdlib-intended; mutable single-span-vending protocol has NO stdlib precedent; the ~Escapable 'reason' was a language-limitation, now resolved."
---
-->

## Context

The `span-typealias-hosting` experiment proposes redesigning `swift-span-primitives` so `Span` aliases `Swift.Span`, `Span.Mutable` aliases `Swift.MutableSpan`, and the capability protocols (`Span.Protocol`, `Span.Mutable.Protocol`) are surfaced via member typealiases. A step in that redesign — making a bare `Swift.MutableSpan` a *linchpin conformer* of the mutable capability (symmetric with `Swift.Span: Span.Protocol`) — requires restating `~Escapable` on `Span.Mutable.Protocol`, which today is owned-only.

This raised a recollection of "a first-principles reason for no `~Escapable` here." This doc records what the standard library's own design says about a span-vending *protocol* and `~Escapable`, so the redesign's mutable-side decision rests on the actual prior art rather than memory. It is the **span-primitives** counterpart to `iterable-se0516-alignment.md` (which covers the *iterator* axis).

## Question

For the single-span-vending capability protocols of this package:
1. Is there a stdlib precedent for `Span.Protocol`, and is it `~Escapable`?
2. Is there a stdlib precedent for a *mutable* single-span-vending protocol (the model for `Span.Mutable.Protocol` and a `MutableSpan` linchpin)?
3. Is there any first-principles reason against `~Escapable` on these protocols — and has the stdlib's posture changed in 6.4/6.5?

## Analysis

### The capability map (span-primitives ↔ stdlib)

| span-primitives | stdlib analog | stdlib status |
|---|---|---|
| `Span.Protocol` — vends one `Swift.Span<Element>` | **`ContiguousStorage<Element>`** (SE-0447, *Future directions*) | **deferred** |
| `Span.Mutable.Protocol` — vends one `Swift.MutableSpan<Element>` | — *none* (`MutableSpan` is a type, not a vending protocol) | does not exist |
| `Iterable` (iterator-primitives, not this package) | `BorrowingSequence` / `BorrowingIteratorProtocol` (**SE-0516**) | shipping (`SwiftStdlib 6.4`) |

The third row is the iterator axis, already handled by `iterable-se0516-alignment.md`; it is *not* this package's analog and is listed only to keep the two axes distinct.

### 1. The read capability is the stdlib's own (deferred) `~Escapable` protocol

SE-0447's *Future directions* sketches the protocol this package realizes [Verified: 2026-06-23 — SE-0447, "Future directions › ContiguousStorage"]:

```swift
// stdlib SE-0447 (deferred)                 // institute (shipping, Span.Protocol.swift:122)
public protocol ContiguousStorage<Element>:   public protocol `Protocol`:
    ~Copyable, ~Escapable {                       ~Copyable, ~Escapable {
  associatedtype Element: ~Copyable…            associatedtype Element: ~Copyable
  var storage: Span<Element> { _read }          var span: Swift.Span<Element> { @_lifetime(borrow self) get }
}                                             }
```

The shapes are the same capability, and the stdlib's is explicitly **`~Copyable, ~Escapable`**. It is deferred for two **language-limitation** reasons [Verified: 2026-06-23 — SE-0447]: (a) the inability to suppress requirements on `associatedtype` declarations (deferred during SE-0427 review), and (b) `_read` accessors cannot be protocol requirements. Neither is a first-principles objection to a `~Escapable` span-vending protocol.

This package routed around both: it uses `SuppressedAssociatedTypes` for (a), and `@_lifetime(borrow self) get` (returning) instead of `_read` (yielding) for (b).

### 2. The `@_lifetime`-requirement convergence (SE-0516)

The stdlib has since converged on this package's technique. `BorrowingSequence`/`BorrowingIteratorProtocol` (SE-0516, `SwiftStdlib 6.4`) put `@_lifetime` on bare protocol requirements rather than waiting on `_read` [Verified: 2026-06-23 — `swiftlang/swift` `stdlib/public/core/BorrowingSequence.swift:15,56-58,100,145`]:

- `public protocol BorrowingIteratorProtocol<Element>: ~Copyable, ~Escapable` (`:15`), with `@_lifetime(&self) @_lifetime(self: copy self) mutating func nextSpan(maximumCount: Int) -> Span<Element>` (`:56-58`).
- `public protocol BorrowingSequence<Element>: ~Copyable, ~Escapable`, `@_lifetime(borrow self) func makeBorrowingIterator()` (`:145,154`).
- A concrete `~Escapable` conformer, `public struct SpanIterator<Element>: BorrowingIteratorProtocol, ~Copyable, ~Escapable` (`:100`), storing a `Span` and vending sub-spans.

So `@_lifetime`-annotated, `~Escapable`, span-vending protocols are now stdlib practice — direct external validation of `Span.Protocol`'s shape.

### 3. The read *linchpin* is stdlib-intended

SE-0447 states `Span` "can be retroactively conformed to the new protocol family when the new protocols are ready" [Verified: 2026-06-23 — SE-0447]. That is exactly this package's `extension Swift.Span: Span.Protocol` (the `Swift.Span+Span.Protocol.swift` linchpin). The institute is ahead of, not divergent from, the stdlib here.

### 4. The mutable capability has NO stdlib precedent

SE-0447 sketches **no** `MutableContiguousStorage`, and the stdlib ships none [Verified: 2026-06-23 — SE-0447 has no mutable ContiguousStorage; `swiftlang/swift` stdlib has no public `var mutableSpan`-requirement protocol]. In the stdlib model, `MutableSpan` is the **vended leaf** — the borrowed-mutable view returned by an owner's `.mutableSpan` — *not a vendor*. The broader ownership-aware effort (`MutableContainer` / `RangeReplaceableContainer`) is about *owned collections*, not a "vends a MutableSpan" protocol.

Therefore a `MutableSpan` mutable-linchpin (`Swift.MutableSpan: Span.Mutable.Protocol`, vending itself) would be **institute-pioneered** — the structural mirror of the read linchpin, with no external model either way.

### 5. The "first-principles reason against ~Escapable" — what it actually was

Three candidate "reasons," none a standing barrier to the capability protocols:

| Candidate | What it is | Bearing on the mutable linchpin |
|---|---|---|
| SE-0447 `ContiguousStorage` deferral | Language limitations (assoc-type suppression; `_read`-as-requirement) | None — it *argues for* `~Escapable`, and the blockers are resolved |
| `nonescapable-support-…md` DECISION — "~Escapable is surgical; owners stay Escapable" | A first-principles argument, but about *owners / integer-address views* (e.g. `Memory.Buffer`) | None — admitting the *already-`~Escapable`* `MutableSpan` as a conformer makes **no owner** `~Escapable` |
| "owned and borrowed can't be one protocol — witness-table contracts differ" (`Span.Protocol.swift:21`; `memory-byte-…md:101`) | A first-principles-*sounding* claim | **Already REFUTED** for the read side by the 2026-06-04 Unify (`borrow self` is the unifier) |

### Contextualization ([RES-021]) — what the mutable linchpin costs in this type system

Concretely, the mutable linchpin is: restate `~Escapable` on `Span.Mutable.Protocol` (so the suppression admits `~Escapable` conformers, exactly as `Span.Protocol` already does), then `extension Swift.MutableSpan: Span.Mutable.Protocol` whose `mutableSpan` vends `self` under `@_lifetime(&self)`. It compiles [Verified: 2026-06-23 — scratch probe; `mutableSpan { mutating get { self } }` with `~Escapable` restated]. Cost: the owned conformers (Buffer/Storage, which are `Escapable`) are unaffected (suppression *admits* both regimes); the only semantic change is that the mutable capability stops being owned-only — symmetric with the read capability. What "compiles" does **not** establish is *soundness* of the self-vend under exclusivity, which `[EXP-017]` requires be proven in release + cross-module before adoption.

## Outcome

**Status: RECOMMENDATION.**

1. **The read side is stdlib-aligned and settled.** `Span.Protocol: ~Copyable, ~Escapable` + the `Swift.Span` linchpin *is* the stdlib's intended `ContiguousStorage` design (SE-0447), realized early via `@_lifetime`-requirements (which the stdlib then adopted in SE-0516). There is **no first-principles barrier** to `~Escapable` on the span capability; the historical "reason" was a now-resolved language limitation.

2. **The mutable linchpin is an institute frontier, gated on soundness — not principle.** No stdlib precedent exists for a mutable single-span-vending protocol; the stdlib treats `MutableSpan` as the vended leaf. A `Swift.MutableSpan: Span.Mutable.Protocol` linchpin (requiring the `~Escapable` restatement) is the structural mirror of the read linchpin and compiles, and it does not violate the `nonescapable-support` DECISION (no owner becomes `~Escapable`). The decision to adopt it therefore rests on **empirical soundness** of the `MutableSpan` self-vend under `@_lifetime(&self)`, validated release + cross-module per `[EXP-017]`.

3. **Disposition for the redesign:** proceed with the read alignment as-is. The mutable linchpin + `~Escapable` restatement is **soundness-confirmed for concrete use** by the companion experiment `Experiments/mutablespan-self-vend-soundness/` (CONFIRMED — backing storage `[21,5,9] → [42,105,109]` through the self-vended `mutableSpan`, debug + release, cross-module), with the discriminator that the self-vend MUST use the non-consuming `extracting(...)`, not `{ self }` (which consumes the `~Copyable` self — caught only by a real build). Generic forwarding of the `var mutableSpan` form remains gated by the pre-existing no-generic-`mutableSpan` wall, orthogonal to the linchpin.

4. **Forward direction (SE-0507 borrow/mutate).** The cleanest expression of these requirements — `var span { borrow }` / `var mutableSpan { mutate }` (no `@_lifetime`/`_overrideLifetime`, and a `mutate` accessor that permits in-place generic mutation) — is the SE-0507 path the stdlib `Span` family has already taken. It is **experimental**: `-enable-experimental-feature BorrowAndMutateAccessors`, rejected by release compilers ("cannot be enabled in production compiler"); a development-snapshot toolchain compiles it [Verified: 2026-06-23 — `main-snapshot-2026-05-27` compiles a `borrow`/`mutate` probe with the flag; default 6.3.2 rejects it]. It is therefore **not adoptable in the shipping surface** (which builds on the released toolchain) until SE-0507 reaches a release. A borrow/mutate spike belongs in `Experiments/` under a snapshot toolchain, not in `Sources/`.

This RECOMMENDATION does not authorize any `Sources/` change.

## References

- [SE-0447: Span — Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) — the deferred `ContiguousStorage<Element>: ~Copyable, ~Escapable`; the deferral blockers; "Span … retroactively conformed."
- [SE-0456: Add Span-providing Properties](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md) — concrete `.span`/`.mutableSpan`, no protocol.
- SE-0516 "Iterable (formerly BorrowingSequence)" — `swiftlang/swift` `stdlib/public/core/BorrowingSequence.swift` (`SwiftStdlib 6.4`; `:15,56-58,100,145`), local clone HEAD `6f5d855aedf`.
- `swift-institute/Research/memory-byte-bit-domain-orthogonality.md`; `cross-layer-capability-protocol-model.md` (§12, v1.5.0); `nonescapable-support-memory-storage-buffer.md`; `iterable-se0516-alignment.md`.
- `Experiments/span-typealias-hosting/` (this package) — the redesign; `Experiments/mutablespan-self-vend-soundness/` (companion soundness spike).
