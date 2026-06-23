# Read-Only Foreign Column

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

**Trigger.** Round-2 dispatch of the Memory.Foreign arc promoted Residual #4 of `memory-foreign-and-memory-protocol.md` (v1.1.1): a 2026-06-12 scouting inventory found swift-file-system's zero-copy candidates — digest/checksum/streaming reads over large files — blocked because read-only mappings cannot enter `Memory.Foreign`'s mutable-exclusive adoption contract, leaving `File.System.Read.Full` (heap-allocate + read; `swift-file-system/Sources/File System Core/File.System.Read.Full.swift`) as the only correct path. The standing send-path motivation (immutable payload pinning, retransmission) carries over from the parent doc's Residual #3/#4.

**Bindings.** (P1) no load-bearing Sendable — isolation crossing via region-based sending per [MEM-SEND-010]/[MEM-SEND-012]/[MEM-SEND-013]; types may conform additively where semantically correct. (P2) Span types over `Unsafe*` pointer APIs.

**[RES-019] internal-first.** No prior research doc covers a read-only owning column; the standing pointer is the parent doc's Residual #4. The decisive internal prior art turned out to be *shipped source*, not a doc: the `Memory.Map` owning envelope (below), whose existence materially corrects the parent doc's Q2 framing.

**Tier 2**: cross-package (memory-map, memory-foreign, span, file-system, swift-memory L3); reversible (RECOMMENDATION; no source edits land in this arc).

## Question

1. Does `Storage.Contiguous`'s unconditional `_modify` preclude a read-only storage column outright?
2. Is the answer a Foreign-over-`Span.Raw` additive sibling plus a read-only storage product, or a constraint split?
3. How does this interact with the sharing model (Item A, parent Residual #3)?
4. What is the composition point with the existing L3 mapping surface (`swift-foundations/swift-memory`)?

## Current State (verified against source, 2026-06-12)

**The seam is mutable by construction.** `Store.Protocol`'s requirement set is `capacity` + `subscript { get set }` + `initialize(at:to:)` + `move(at:)` (+ defaulted `prepareForMutation()`) — three of its four core operations are mutations (`swift-store-primitives/Sources/Store Protocol Primitives/Store.Protocol.swift:20-82`), and `Storage.Contiguous` witnesses the subscript with an unconditional `_modify` over the typed base (`swift-storage-primitives/Sources/Storage Contiguous Primitives/Storage.Contiguous+Store.Protocol.swift:25-34`). The initialization ledger and deinit oracle exist to manage element *lifecycle* — meaningless for pre-initialized immutable bytes.

**The owning read-only mapped envelope already exists.** `Memory.Map` (L1, `swift-memory-map-primitives/Sources/Memory Map Primitives/Memory.Map.swift:36-98`) is not only the mapping vocabulary namespace — it is a concrete `~Copyable` RAII wrapper: stored `_region: Memory.Map.Region?` (guarded-deinit shape), `access`/`sharing`/`safety` fields, an injected platform cleanup witness `_unmap: @Sendable (Memory.Map.Region) -> Void`, and `deinit { guard let region = _region else { return }; _unmap(region) }`. The L3 factory constructs it from a file descriptor with `access: Access = .read` as the default (`swift-foundations/swift-memory/Sources/Memory/Memory.Map+Init.swift:27-113`). This corrects the parent doc's Q2 corollary, which presented the owning mapped envelope as a hypothetical Foreign composition: it ships today, specialized to mappings. (It also carries a pre-P1 concurrency posture — `@unsafe @unchecked Sendable` + a type-level `@Sendable` witness — noted below.)

**What the envelope lacks is a safe read surface.** Its entire byte access is `Unsafe*`: `withUnsafeBytes` / `withUnsafeMutableBytes` (closure-scoped) and `baseAddress` / `mutableBaseAddress` (`swift-foundations/swift-memory/Sources/Memory/Memory.Map+Operations.swift:107-118,192-198`). No `Span<Byte>`, no `Span.Protocol` conformance, on either the L1 struct or the L3 surface — exactly the API class P2 directs away from. The borrowing-span pattern it needs is already shipped twice in the immediate neighborhood: `Memory.Map.Region.span` (`Memory.Map.Region.swift:50-74`, `@_lifetime(borrow self)` over the raw window) and `Storage.Contiguous: Span.Protocol` (`Storage.Contiguous+Span.Protocol.swift`).

**Read-only memory and `Memory.Region`.** `Memory.Region`'s only production consumer is storage construction, which resolves the base with `assumingMemoryBound(to:)` and then hands out `_modify` (`Storage.Contiguous.swift:100-111` + the seam above). A read-only region conforming `Memory.Region` would therefore be an attractive nuisance: one convenience init away from faulting writes.

## Analysis

### Q1 — Does the unconditional `_modify` preclude a read-only storage column? Yes — and rightly.

A "read-only storage column" is a category error in this tower. The storage tier's job is element lifecycle over raw capacity (ledger, oracle, init/move transitions); a read-only view has no lifecycle to manage — its bytes arrive initialized and die with the envelope. The correct read tier already exists and is the one the ecosystem standardized for borrowing access: `Swift.Span` via `Span.Protocol`. The conclusions that follow:

- **No constraint split.** Splitting `Store.Protocol` into read/write halves would mutate a deliberately frozen 4+1-op seam (its own doc: "deletable convenience … never refined into storage identity") to serve a consumer that doesn't want slots at all. Rejected on tier grounds before doctrine grounds.
- **The fence**: read-only regime types MUST NOT conform `Memory.Region`. The conformance buys exactly one thing — entry into `Storage.Contiguous` — and that entry is UB for read-only memory. Non-conformance makes the misuse unrepresentable.

### Q2 — Sibling type, constraint split, or neither? **Decompose by provenance; the file-system case needs neither.**

The promoted motivation (file-system zero-copy) and the standing motivation (send path) turn out to want different things:

**(a) Mapped read-only provenance — the file-system consumer.** The ownership problem is already solved by `Memory.Map`; the *actual* gap is the missing safe read surface. The unblock is an additive borrowing span on the owning envelope (L1, one extension file), shaped like its own `Region.span` but over the user window:

```swift
extension Memory.Map {
    /// Borrowing read access to the user-visible window
    /// (base + offsetDelta ..< + userLength). Precondition: isMapped.
    public var span: Swift.Span<Byte> { @_lifetime(borrow self) borrowing get }
}
extension Memory.Map: Span.`Protocol` { /* Element == Byte */ }
```

A mutable counterpart, if ever wanted, must gate on `access.allows.write` — but it is a separate decision and nothing in the file-system motivation needs it. With this surface, the digest/checksum flow is `File.Handle` → `Memory.Map(fileDescriptor:range:access:.read)` → `map.span` → hash, with `advise(_:)` (`Memory.Map+Operations.swift:176`) covering the streaming hint. `File.System.Read.Full` remains the correct default for small files (a mapping round-trip is not free); the zero-copy path is for the large-file cases the scouting inventory named. **No new type, no new package — ~15 additive lines whose pattern ships twice already.**

**(b) Non-mapped read-only foreign provenance — the send path.** This is the genuine empty lattice cell (provenance = external × access = read × release = callback), and with file-system rerouted to (a), its only consumers are Item A's arc (immutable payload pinning; retransmission). Design recorded for that arc, not built now:

- Unique form: `Memory.Foreign.Immutable` — nested sibling (the in-ecosystem mutability vocabulary is `Span.Raw` vs `Span.Raw.Mutable`, and the existing converter is named `immutable`, `Span.Raw.Mutable.swift:165-170`; "ReadOnly" is a compound, and a `Descriptor` generic parameter would infect every downstream spelling exactly like the rejected Owner generic). Shape: over `Span.Raw`, plain finalizer, guarded deinit, `take()`, **no `Memory.Region` conformance** (the Q1 fence), `Span.Protocol` for reads, non-Sendable + `consuming sending` crossing — the parent doc's posture verbatim.
- Why not reuse `Memory.Map` for it: Map's identity is *kernel mapping* (access/sharing/safety/lock vocabulary, platform witnesses); arbitrary provider buffers have none of that. Same cut distinction as the parent doc's Q2 taxonomy.

### Q3 — Sharing interplay (Item A input)

Immutable bytes are where sharing becomes sound, and where the one semantically-correct type-level `@Sendable` lives. The shared holder for Item A is ARC-shaped:

```swift
public final class /* holder */: Sendable {
    let region: Span.Raw                                   // Sendable descriptor
    let finalizer: @Sendable (Span.Raw) -> Void            // REQUIRED @Sendable
    deinit { finalizer(region) }                           // ARC is the refcount
}
```

Every stored property is Sendable, so the conformance is **structurally checked — zero `@unchecked`**. The `@Sendable` finalizer here is not load-bearing Sendable in P1's prohibited sense: the last release runs on whichever thread drops the final reference, so the requirement is forced by the type's own semantics, and P1 explicitly permits conformance where semantically correct. This is Apple's `customOwner` case rebuilt safely (the owner is the holder itself), and it answers both N-readers digest fan-out and retransmission pinning — the two custody points the parent doc's contextualization correction reserved. Unique-carve over disjoint sub-regions remains the alternative for the mutable receive side. Decision belongs to Item A / the packet-currency arc.

**Posture observation (seat's queue, not this arc):** `Memory.Map` — which can hold *writable* mappings — carries the pre-P1 posture (`@unchecked Sendable` move-only absorber + type-level `@Sendable` witness, `Memory.Map.swift:27-36,68`). Under the doctrine that landed on `Memory.Foreign`, the mutable-capable envelope would be non-Sendable with `sending` crossings, and only the read-only/immutable shapes earn checked Sendable. Whether Map migrates is a reconciliation question for the tower/seat — flagged, not proposed.

### Q4 — Composition point

The L3 factory (`Memory.Map+Init.swift:27-113`) is the entry; the file-system flow needs no new composition machinery once the span surface exists. A later bridge from a mapped region into the foreign family (e.g. handing a mapped payload to the networking send path) would be an adoption-style factory at L3 — recorded as a direction; nothing present needs it.

## Outcome

**Status: RECOMMENDATION** (no source edits land in this arc; proposals route to the executor/seat).

1. **Unblock file-system with the span surface, not a new regime**: additive borrowing `span: Span<Byte>` (user window, `isMapped` precondition) + `Span.Protocol` conformance on `Memory.Map` at L1 — P2 applied to the one envelope that has only `Unsafe*` access today. Pattern existence-proof: `Memory.Map.Region.span` + `Storage.Contiguous: Span.Protocol`.
2. **No read-only Foreign sibling now.** The file-system motivation reroutes to (1); the remaining consumers are Item A's. The `Memory.Foreign.Immutable` sketch (unique, over `Span.Raw`, no `Memory.Region`, `Span.Protocol`, sending posture) is recorded here for that arc; same package when built (a sibling file, not a sibling package).
3. **Storage tier ruled out structurally**: the 4+1 seam is mutation; reading is `Span`'s tier; no constraint split. Read-only regimes never conform `Memory.Region` (the fence).
4. **Item A input recorded**: the ARC-shared immutable holder with structurally-checked Sendable and required-`@Sendable` finalizer — the lattice cell where type-level Sendable is correct; plus the `Memory.Map` posture reconciliation flag.

### Residual

- **Premises**: all empirical claims above are file:line-verified at write time ([RES-023]); the span-surface mechanism needs no new experiment — its pattern ships twice in the cited sources.
- **Direction (Item A arc)**: choose unique-carve vs ARC-shared holder; the Sendable analysis in Q3 is the standing input.
- **Direction (seat)**: `Memory.Map` concurrency-posture reconciliation.
- **Direction (file-system arc)**: size threshold policy for `Read.Full` vs map-and-span; `advise` tuning for streaming digests.

## References

- `swift-primitives/swift-memory-map-primitives/Sources/Memory Map Primitives/Memory.Map.swift` (:36-98) · `Memory.Map.Region.swift` (:50-74)
- `swift-foundations/swift-memory/Sources/Memory/Memory.Map+Init.swift` (:27-113) · `Memory.Map+Operations.swift` (:107-118,176,192-198)
- `swift-store-primitives/Sources/Store Protocol Primitives/Store.Protocol.swift` (:20-82) · `swift-storage-primitives/Sources/Storage Contiguous Primitives/Storage.Contiguous+Store.Protocol.swift` (:25-34)
- `swift-primitives/swift-span-primitives/Sources/Span Raw Primitives/Span.Raw.Mutable.swift` (:165-170)
- `swift-foundations/swift-file-system/Sources/File System Core/File.System.Read.Full.swift`
- Parent: `memory-foreign-and-memory-protocol.md` (v1.1.2) — Residual #3/#4, Q2 taxonomy, the sending posture; recycle-channel experiment `swift-memory-foreign-primitives/Experiments/foreign-recycle-channel/` (Item C, same dispatch)
