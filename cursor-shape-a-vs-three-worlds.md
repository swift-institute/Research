# Cursor Shape A vs Three Worlds: Storage-as-Borrow-Carrier Re-Evaluation

<!--
---
version: 1.0.0
last_updated: 2026-05-18
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
---
-->

## Context

`cursor-abstractions-l1-ecosystem.md` v1.4.0 (2026-05-17, IMPLEMENTED Shape γ) is the canonical L1 cursor decision. Its Three-Worlds architecture rests on the rejection of Shape A (single generic `Cursor<Storage>` type) with the stated reason "Swift offers no way to make `Escapable` conditional on a generic parameter — A type is either Escapable or `~Escapable`, the bit is fixed at declaration."

That stated reason is empirically false. `Tagged<Tag, Underlying>` at `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:55` declares `~Copyable, ~Escapable` and lifts Copyable/Escapable conditionally per `Underlying`'s own conformance:

```swift
public struct Tagged<Tag: ~Copyable & ~Escapable, Underlying: ~Copyable & ~Escapable>: ~Copyable, ~Escapable { ... }
extension Tagged: Copyable where Tag: ~Copyable & ~Escapable, Underlying: Copyable & ~Escapable {}
extension Tagged: Escapable where Tag: ~Copyable & ~Escapable, Underlying: Escapable & ~Copyable {}
```

The `cursor-shape-a-feasibility` experiment (`swift-institute/Experiments/cursor-shape-a-feasibility`, commit `fa990a4` 2026-05-18) confirmed that this pattern transfers cleanly to a Storage-parameterized Cursor type — V1, V2, V5, V6, V7 all CONFIRMED. V3, V4 also revealed a narrower but real Swift constraint: conditional Copyable/Escapable conformance cannot depend on `Mode == X` (same-type) or `Mode: SomeProtocol` (custom-marker-protocol) discriminator constraints. The compiler's diagnostic:

```
error: conditional conformance to suppressible protocol 'Copyable' cannot depend on 'Mode == CursorV3.Owned'
error: conditional conformance to suppressible protocol 'Copyable' cannot depend on 'Mode: CursorV4_OwnedMode'
```

But that narrower constraint is not what v1.4.0 said. The doc evaluated Shape A as if the only structuring option was a Mode discriminator (the kind V3/V4 try, which the language genuinely forbids); it missed the institute's existing borrow-pattern primitives — `Ownership.Borrow.\`Protocol\``, `String.Borrowed`, `Path.Borrowed` — which encode the affine semantics in the **Storage type itself**, not in a discriminator generic.

This research arc revisits the Three-Worlds decision with that gap closed.

**Trigger**: principal redirect 2026-05-18: "but what is the OwnedMode etc even used for? perhaps that approach was wrong to begin with? See also ownership-primitives and String.Borrowed for example from string-primitives."

**Scope**: Ecosystem-wide (all three Worlds of the cursor architecture, plus the consumers in swift-binary-parser-primitives, swift-lexer-primitives, swift-foundations/swift-json, swift-foundations/swift-lexer).

**Tier**: 3 — successor to a Tier 3 arc; precedent-setting (cursor substrate is foundational to every parser, lexer, serializer in the ecosystem); cost of error very high; expected lifetime timeless.

## Question

Does Shape A — a single generic `Cursor<Storage, PositionTag>` primitive leveraging the institute's existing `Ownership.Borrow.\`Protocol\`` patterns as the Storage substrate — win on legibility, perf, and Phase 4 cost vs the currently-shipping Three-Worlds shape (`Cursor.Span<DomainTag>` + planned `Cursor.OwnedReader` / `Cursor.OwnedReaderWriter` / `Cursor.Input`)?

Five sub-questions:

1. Does a `Bytes.Borrowed: ~Copyable, ~Escapable, Ownership.Borrow.\`Protocol\`` primitive already exist, or does it need creating?
2. What is Shape A's exact shape with Storage-as-borrow-carrier — Storage protocol bounds, init signatures, op surfaces?
3. Does the BENCH-011 GREEN signal hold under generic-Storage indirection vs the current hardcoded `Swift.Span<UInt8>` storage?
4. What is the migration cost from currently-shipping Three Worlds to Shape A?
5. What does Phase 4 Shape ι expansion look like under Shape A vs Three Worlds — does it collapse from three new types into one extended type?

## Analysis

### Step 0 — Internal prior-art grep per [RES-019]

Three load-bearing prior research artifacts surfaced:

1. **`ownership-borrow-protocol-unification.md`** v1.0.0 (DECISION, 2026-04-22, Tier 2). Establishes `Ownership.Borrow.\`Protocol\`` as the canonical borrow-capability protocol with `associatedtype Borrowed: ~Copyable, ~Escapable = Ownership.Borrow<Self>`. Conformer Cases A (no custom Borrowed — default suffices), B (Type owns interior storage + encodes type-level invariant — custom Borrowed required), C (Tagged forwarding). The protocol ships at `swift-ownership-primitives/Sources/Ownership Borrow Primitives/__Ownership_Borrow_Protocol.swift:30`.

2. **`nested-view-vs-borrowed-naming.md`** v1.2.0 (DECISION). Classifies cursor types as **Pattern 3** (stateful cursor / iterator, `~Copyable` with mutable state) — explicitly NOT `Ownership.Borrow.\`Protocol\`` conformers. Pattern 1 (borrow-view, passive projection) types — `Path.Borrowed`, `String.Borrowed` — ARE conformers. The naming convention reserves `.Borrowed` for Pattern 1 and `.View` for Pattern 3.

3. **`cursor-abstractions-l1-ecosystem.md`** v1.4.0 (IMPLEMENTED Shape γ, 2026-05-17, Tier 3). The doc being revisited.

The two priors compose: Shape A's `Storage` parameter is a Pattern 1 borrow-view (or owned-storage); the cursor itself is Pattern 3. Storage carries the borrow attribute; cursor carries the stateful position. The two layers are structurally distinct.

### Sub-Question 1: Does Bytes.Borrowed exist?

**Verified empirical claim per [RES-023]**:

```bash
grep -rln "struct Borrowed" /Users/coen/Developer/swift-primitives/swift-byte-primitives/
# Result: (no matches, 2026-05-18)
grep -rln ": Ownership\.Borrow\.\`Protocol\`" /Users/coen/Developer/swift-primitives/
# Result: String, Path, Tagged (conditional). NOT byte.
```

Existing `Ownership.Borrow.\`Protocol\`` conformers in the ecosystem at HEAD 2026-05-18:

| Conformer | Package | File:line | Case |
|---|---|---|---|
| `String` (via `String.Borrowed`) | swift-string-primitives | `String.Borrowed.swift:36`, `String.Borrowed.swift:18` (conformance) | B |
| `Path` (via `Path.Borrowed`) | swift-path-primitives | `Path.Borrowed.swift` | B |
| `Tagged` (conditional, parametric forwarding) | swift-ownership-primitives | `Tagged+Ownership.Borrow.Protocol.swift:23-24` | C |

**Verdict**: NO, `Bytes.Borrowed` does not exist. It would be a new Case B conformer parallel to `String.Borrowed`. Natural home: `swift-byte-primitives` (alongside `Byte` — matches the `String` ↔ `String.Borrowed` pattern). Shape:

```swift
extension Byte {
    @safe
    public struct Borrowed: ~Copyable, ~Escapable {
        @usableFromInline
        internal let span: Swift.Span<UInt8>

        @inlinable
        @_lifetime(borrow span)
        public init(_ span: borrowing Swift.Span<UInt8>) {
            self.span = copy span
        }

        // OR pointer + count, parallel to String.Borrowed:
        // public let pointer: UnsafePointer<UInt8>
        // public let count: Int
    }
}

extension Byte: Ownership.Borrow.`Protocol` {
    public typealias Borrowed = Byte.Borrowed
}
```

The type-level invariant Case B requires — `String.Borrowed`'s null-termination, `Path.Borrowed`'s null-termination — is weaker for `Byte.Borrowed`: just "a borrowed contiguous span of bytes." That's still a real invariant (the span's lifetime constraint is type-level), but lighter than the string/path families. The Case B classification still applies because the type encodes affine ownership semantics via `~Copyable, ~Escapable`.

### Sub-Question 2: Shape A's exact shape

```swift
// In swift-cursor-primitives (new shape):

extension Cursor {
    @safe
    public struct Generic<
        Storage: ~Copyable & ~Escapable,
        PositionTag: ~Copyable
    >: ~Copyable, ~Escapable {
        @usableFromInline
        internal var storage: Storage

        @usableFromInline
        internal var _position: Tagged<PositionTag, Ordinal>

        // Copyable-Storage init (W3 case)
        @inlinable
        @_lifetime(borrow storage)
        public init(_ storage: borrowing Storage) where Storage: Copyable {
            self.storage = copy storage
            self._position = Tagged<PositionTag, Ordinal>(_unchecked: Ordinal(UInt(0)))
        }

        // ~Copyable-Storage init (W1, W2)
        @inlinable
        @_lifetime(copy storage)
        public init(consumingStorage storage: consuming Storage) {
            self.storage = storage
            self._position = Tagged<PositionTag, Ordinal>(_unchecked: Ordinal(UInt(0)))
        }
    }
}

extension Cursor.Generic: Copyable
where Storage: Copyable & ~Escapable, PositionTag: ~Copyable {}

extension Cursor.Generic: Escapable
where Storage: Escapable & ~Copyable, PositionTag: ~Copyable {}
```

World typealiases:

```swift
extension Cursor {
    /// W2 — borrowed Span-cursor for byte streams. Storage = Byte.Borrowed
    /// (Pattern 1 borrow-view). PositionTag is the phantom domain tag.
    public typealias Span<DomainTag: ~Copyable> =
        Cursor.Generic<Byte.Borrowed, DomainTag>

    /// W1 — owned read-only cursor over Memory.Contiguous storage. Phase 4.
    public typealias OwnedReader<Storage: Memory.Contiguous.`Protocol` & ~Copyable> =
        Cursor.Generic<Storage, Storage> where Storage.Element == UInt8

    /// W3 — owned Copyable input cursor. Phase 4.
    public typealias Input<Element> =
        Cursor.Generic<[Element], Element>
}
```

Operation surfaces are conditional extensions:

```swift
// W2 ops — peek/advance/consume over Byte.Borrowed's inner span
extension Cursor.Generic
where Storage == Byte.Borrowed, PositionTag: ~Copyable {
    public func peek() -> UInt8? { ... }
    public mutating func advance() { ... }
    public mutating func consume() -> UInt8 { ... }
    public mutating func seek(to: Tagged<PositionTag, Ordinal>) { ... }
}

// W3 ops — peek/advance/consume over [Element]
extension Cursor.Generic
where Storage == [UInt8], PositionTag == UInt8 {
    public func peek() -> UInt8? { ... }
    public mutating func advance() { ... }
    public mutating func consume() -> UInt8 { ... }
}

// W1 ops — dual-index reader-writer over Memory.Contiguous storage (Phase 4)
extension Cursor.Generic
where Storage: Memory.Contiguous.`Protocol` & ~Copyable,
      Storage.Element == UInt8 { ... }
```

The Cursor's Copyability inheritance:

| Instantiation | Storage attrs | Cursor result |
|---|---|---|
| `Cursor.Span<Byte>` = `Cursor.Generic<Byte.Borrowed, Byte>` | Byte.Borrowed: `~Copyable, ~Escapable` | `~Copyable, ~Escapable` ✓ |
| `Cursor.OwnedReader<Storage>` | Storage: `~Copyable, Escapable` | `~Copyable, Escapable` ✓ |
| `Cursor.Input<UInt8>` = `Cursor.Generic<[UInt8], UInt8>` | `[UInt8]`: `Copyable, Escapable` | `Copyable, Escapable` ✓ |

All three Worlds emerge from one generic type with the correct attributes. No Mode discriminator.

### Sub-Question 3: BENCH-011 under generic Storage

**Not yet re-measured.** This research note frames the hypothesis; an experiment dispatch would empirically validate.

**Hypothesis**: Generic specialization at known instantiations (`Cursor.Generic<Byte.Borrowed, Byte>`, `Cursor.Generic<[UInt8], UInt8>`) should monomorphize to direct-storage access matching the current `Cursor.Span<DomainTag>` perf signal. The added indirection from `storage.span[p]` vs `source[p]` is one extra load through a known-shape struct — specializable.

**Risk**: cross-module specialization at the `Cursor.Generic<Byte.Borrowed, _>` boundary may not fully inline if Storage's `span` accessor is not `@inlinable`. Mitigation: ensure `Byte.Borrowed.span` accessor is `@inlinable @_alwaysEmitIntoClient`.

**Verification gate**: a `cursor-shape-a-bench-011-replay` experiment should re-run BENCH-011's binary + text loops under Shape A. If parity holds, proceed; if regression that mitigation can't close, fall back to Shape γ (current shipping shape).

### Sub-Question 4: Migration cost from currently-shipping Three Worlds

Migration sequence (estimated, pre-1.0 correctness-driver per `[ARCH-LAYER-008]`):

| Step | Change | Files | Commits |
|---|---|---|---|
| 1 | Add `Byte.Borrowed: ~Copyable, ~Escapable, Ownership.Borrow.\`Protocol\`` to `swift-byte-primitives` | 2 files (Byte.Borrowed.swift + conformance) | 1 |
| 2 | Re-shape `Cursor.Span<DomainTag>` → `Cursor.Generic<Byte.Borrowed, DomainTag>` typealias in `swift-cursor-primitives` | 3 files (Cursor.Generic.swift new, Cursor.Span.swift becomes typealias, Cursor.Span+Cursor.swift extensions retarget) | 1 |
| 3 | Re-run BENCH-011 probe. If RED → revert to Shape γ. If GREEN → proceed. | Experiment package | (no commit; verification gate) |
| 4 | Update `Binary.Bytes.Input.View` typealias path through `Cursor.Span<Byte>` (no change at construction sites — typealias still resolves) | 0 files (transitive) | (none — should require no commit if shape is layered cleanly) |
| 5 | Update `Lexer.Scanner` wrapper's `inner: Cursor.Span<Text>` field — no change at the wrapper's API surface (Cursor.Span typealias intact) | 0 files | (none) |
| 6 | Add `Ownership.Borrow.\`Protocol\`` dep on `swift-cursor-primitives` (for Storage bound) | 1 file (Package.swift) | 1 |

**Total**: 3 commits, ~6 files modified, plus 1 BENCH-011 experiment run.

**Costs**:
- Add `swift-byte-primitives` as dep of `swift-cursor-primitives` (currently NOT a dep — cursor-primitives was deliberately byte-agnostic).
- Add `swift-ownership-primitives` as dep of `swift-cursor-primitives`.
- Tier shift: cursor-primitives currently Tier 6-8 (Tagged + Ordinal + Cardinal + Index). Adding Byte (Tier 2) and Ownership (Tier 1-2) preserves tier-6-8 range — these deps already sit below cursor's tier.

**Benefits**:
- Eliminates the bespoke `BorrowedBytes` shape that the V5 experiment invented. `Byte.Borrowed` becomes the canonical institute primitive parallel to `String.Borrowed` / `Path.Borrowed`.
- Aligns Shape A with the existing `Ownership.Borrow.\`Protocol\`` framework (Case B conformer).
- Removes the conceptual gap noted in the principal redirect: the Mode-discriminator approach was attempting to invent a mechanism the institute already has.

### Sub-Question 5: Phase 4 Shape ι expansion

**Under Three Worlds (current planned Phase 4)**:
Add three new types to swift-cursor-primitives:
- `Cursor.OwnedReader<Storage>` (~Copyable, Escapable; single index)
- `Cursor.OwnedReaderWriter<Storage>` (~Copyable, Escapable; dual index)
- `Cursor.Input<Element>` (Copyable, Sendable; single index)

Each type has its own implementation file, its own operation surface, its own tests. Three distinct migration target sets in the existing W1 (Binary.Cursor / Binary.Reader at swift-binary-primitives) and W3 (Binary.Bytes.Input at swift-binary-parser-primitives) consumers.

**Under Shape A**:
Add typealiases on existing `Cursor.Generic`:
```swift
extension Cursor {
    public typealias OwnedReader<Storage: ...> = Cursor.Generic<Storage, Storage>
    public typealias Input<Element> = Cursor.Generic<[Element], Element>
}
```

Add conditional operation extensions on `Cursor.Generic` per Storage shape (Memory.Contiguous.Protocol-bound, [Element]-bound). The dual-index reader-writer is the only structural complication — it stores two positions, which doesn't fit `Cursor.Generic`'s single-position field.

**Two paths for the dual-index W1**:

A. Keep `Binary.Cursor<Storage>` (existing rw type) as a separate type, not unified. Shape A unifies the SINGLE-position cursors (W1 read-only, W2 borrowed, W3 input); dual-index reader-writer stays distinct.

B. Add a `secondaryPosition: Optional<Tagged<PositionTag, Ordinal>>` field to `Cursor.Generic` with conditional API. Read-only Worlds leave it nil; read-write World stores both. Adds storage overhead to read-only Worlds.

Path A is cleaner. The Three-Worlds → Shape A reshape unifies single-position cursors; dual-index is a sibling structural shape, not the same generic type. So Phase 4 under Shape A becomes:

- `Cursor.Generic` hosts W1 read-only, W2, W3 (three typealiases over one type)
- `Binary.Cursor<Storage>` (or rename to `Cursor.OwnedReaderWriter<Storage>`) hosts W1 read-write — separate type, dual-index

Net: Phase 4 under Shape A collapses three new types into one extension to existing `Cursor.Generic` + two typealiases, plus relocating `Binary.Cursor`'s read-write type into `swift-cursor-primitives` (which was Phase 4 ι expansion's goal anyway). Total new type-bodies: 1 (the rw cursor). Under Three Worlds: 3. Net savings: 2 types-worth of code body.

### Summary table

| Criterion | Three Worlds (status quo) | Shape A (proposed) |
|---|---|---|
| Type-system unification | Three distinct types | One Cursor.Generic + typealiases + dual-index sibling |
| Leverages existing institute infrastructure | No (bespoke shape per World) | Yes (Ownership.Borrow.\`Protocol\` Case B for W2 substrate) |
| Phase 4 expansion cost | 3 new types, 3 new test suites | 1 new dual-index type + 2 typealiases + conditional extensions |
| Requires new primitive | No (already shipping) | Yes (Byte.Borrowed in swift-byte-primitives) |
| Migration cost from current shipping | 0 (status quo) | 3 commits, ~6 files |
| BENCH-011 verification needed | Already GREEN | Needs re-measurement after Shape A reshape |
| Type-system constraint risk | None (proven) | One axis untested (generic-Storage specialization) |
| Reversibility | Trivially keep | Trivially revert if BENCH-011 fails |
| Phase 4 dispatch cost | Per-World implementation + tests | Mostly typealias addition + ops extension |
| Code surface area | More types, simpler each | Fewer types, more conditional extensions on one |
| Call-site ergonomics | `Cursor.Span<Byte>(span)` (clean) | `Cursor.Span<Byte>(Byte.Borrowed(span))` via convenience init — same call-site shape if init forwards |

## Outcome

**Status**: RECOMMENDATION (pending principal review; not yet DECISION).

**Recommendation**: Transition to Shape A as the canonical L1 cursor architecture, conditional on a `Bytes.Borrowed` (specifically `Byte.Borrowed`) primitive being added to `swift-byte-primitives` and a BENCH-011 re-measurement clearing GREEN under the generic-Storage indirection.

**Rationale**:

1. **The Three-Worlds rejection's stated reason was empirically wrong.** Shape A is structurally achievable. The v1.4.0 doc's reasoning is empirically refuted (Tagged precedent + cursor-shape-a-feasibility experiment V1/V5/V6/V7 CONFIRMED).

2. **Shape A leverages existing institute infrastructure.** The `Ownership.Borrow.\`Protocol\`` framework established in `ownership-borrow-protocol-unification.md` v1.0.0 already provides exactly what Shape A's Storage bound needs. Adding `Byte.Borrowed` is a Case B conformer parallel to `String.Borrowed` / `Path.Borrowed` — institute convention, not invention.

3. **Phase 4 expansion cost is lower under Shape A.** Two typealiases + one extension on existing `Cursor.Generic` vs three new types in Three Worlds. Net savings: two types-worth of implementation and testing.

4. **Pre-1.0 is the right window for the reshape.** The migration cost (3 commits, ~6 files) is bounded and pre-1.0-permissible per `[ARCH-LAYER-008]` correctness-driver. Post-1.0 the cost compounds with ABI considerations.

5. **The Three-Worlds shape was chosen against a phantom alternative.** The v1.4.0 doc evaluated Shape A as if the only structuring option was a Mode discriminator. With the Storage-as-borrow-carrier framing surfaced, the real comparison is between two structurally-valid architectures. The corrected comparison favors Shape A on type-system economy and Phase 4 cost.

**Risks and mitigation**:

| Risk | Mitigation |
|---|---|
| BENCH-011 regresses under generic-Storage indirection | Run BENCH-011 replay experiment BEFORE reshape lands; if RED, revert to Shape γ — no commits to cursor-primitives until evidence is in. |
| `Byte.Borrowed` naming bikeshed (Byte.Borrowed vs Bytes.Borrowed vs Binary.Bytes.Borrowed) | Use the case framing — Byte.Borrowed parallels String.Borrowed exactly; the institute convention is Type.Borrowed where Type is the value-domain singular. |
| Phase 4 dual-index reader-writer requires a separate sibling type | Acknowledge in this doc — Shape A unifies single-position cursors (W1 ro + W2 + W3); dual-index W1 rw is a sibling structural shape. Net: still 1 fewer new type than Three Worlds. |
| Migration cost surprise (transitive consumer breakage) | Same workspace grep discipline as the v1.4.0 Phase 3 termination gate. Three-Worlds already has the consumer-migration playbook. |

**What this RECOMMENDATION does NOT specify**:

- Naming of `Byte.Borrowed` vs alternatives — flagged as bikeshed; principal disposes.
- Whether `swift-cursor-primitives` adopts `swift-byte-primitives` as a direct dep, OR a third package (`swift-byte-borrowed-primitives` if package-purity demands). Implementation choice.
- The exact BENCH-011 replay experiment's design — flagged as the verification gate; experiment dispatch decides.
- Phase 4's dual-index reader-writer's exact name and home (`Cursor.OwnedReaderWriter` vs `Binary.Cursor` relocated, or other).

**If RECOMMENDATION is approved**: this doc transitions to DECISION; an implementation arc executes the migration sequence in Sub-Q4 with BENCH-011 replay as the hard gate. Phase 4 Shape ι expansion (currently scheduled per v1.4.0) collapses into typealiases on the unified `Cursor.Generic`.

**If RECOMMENDATION is rejected**: v1.4.0's Three Worlds remains the canonical shape. This research arc gets archived as `SUPERSEDED` with the rationale recorded. The corrected reasoning from this arc still gets back-ported into v1.4.0 (the "structurally impossible" claim is replaced with the narrower correct reasoning about Mode-discriminator constraints).

## References

### Internal prior research

- [ownership-borrow-protocol-unification.md](./ownership-borrow-protocol-unification.md) v1.0.0 (DECISION, 2026-04-22, Tier 2) — establishes Ownership.Borrow.\`Protocol\` and Case A/B/C framing.
- [nested-view-vs-borrowed-naming.md](./nested-view-vs-borrowed-naming.md) v1.2.0 (DECISION) — Pattern 1 borrow-view vs Pattern 3 stateful-cursor classification.
- [cursor-abstractions-l1-ecosystem.md](./cursor-abstractions-l1-ecosystem.md) v1.4.0 (IMPLEMENTED Shape γ, 2026-05-17) — the doc this arc revisits.
- [byte-cursor-primitive-unification.md](./byte-cursor-primitive-unification.md) v1.3.0 (IN_PROGRESS) — predecessor analytical input to cursor-abstractions.

### Source-code anchors (verified at HEAD 2026-05-18)

- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:55, :115-116` — Tagged declaration + conditional Copyable/Escapable conformance pattern (the empirical counter-precedent to v1.4.0's "structurally impossible" claim).
- `swift-ownership-primitives/Sources/Ownership Borrow Primitives/__Ownership_Borrow_Protocol.swift:30` — `__Ownership_Borrow_Protocol` declaration with `associatedtype Borrowed: ~Copyable, ~Escapable = Ownership.Borrow<Self>`.
- `swift-string-primitives/Sources/String Primitives/String.Borrowed.swift:36` — `String.Borrowed: ~Copyable, ~Escapable`, the Case B conformer pattern Bytes.Borrowed would mirror.
- `swift-string-primitives/Sources/String Primitives/String.Borrowed.swift:18` — `extension String: Ownership.Borrow.\`Protocol\` {}` conformance.
- `swift-path-primitives/Sources/Path Primitives/Path.Borrowed.swift` — second Case B example.
- `swift-byte-primitives/Sources/Byte Primitives/Byte.swift` — `Byte` value type; site where `Byte.Borrowed` would land.
- `swift-cursor-primitives/Sources/Cursor Span Primitives/Cursor.Span.swift` — current shipping `Cursor.Span<DomainTag>` (Three Worlds W2).

### Experiment

- `swift-institute/Experiments/cursor-shape-a-feasibility/EXPERIMENT.md` (commit `fa990a4`, 2026-05-18) — empirical verification of Shape A's structural achievability; V1/V2/V5/V6/V7 CONFIRMED, V3/V4 (Mode-discriminator) REFUTED.

### Swift Evolution

- [SE-0427 — Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0446 — Nonescapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md)
- [SE-0447 — Span: Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
- [SE-0499 — Support for Noncopyable Simple Protocols](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md)
- [SE-0503 — Suppressed Default Conformances on Associated Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md)
- [SE-0519 — Borrow<T>](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0519-borrow.md) — the stdlib analog `Ownership.Borrow<Value>` mirrors.

## Provenance

Surfaced 2026-05-18 by principal redirect on `cursor-abstractions-l1-ecosystem.md` v1.4.0's Shape A rejection reasoning:

> "Swift offers no way to make Escapable or Copyable conditional on a generic parameter is this true? you can have conditional extensions with where clauses?!"

Followed by:

> "but what is the OwnedMode etc even used for? perhaps that approach was wrong to begin with? See also ownership-primitives and String.Borrowed for example from string-primitives."

The principal observed that the experiment's V3/V4 Mode-discriminator approach was the wrong abstraction from the start — the institute already encodes borrow-vs-own in the Storage type itself via `Ownership.Borrow.\`Protocol\`` and Pattern 1 borrow-view types. This research arc closes the gap: Shape A leveraging existing institute borrow infrastructure was never evaluated in v1.4.0; this doc evaluates it.

## Changelog

- **v1.0.0** (2026-05-18): RECOMMENDATION — Transition to Shape A as the canonical L1 cursor architecture, conditional on Byte.Borrowed creation and BENCH-011 replay clearing GREEN. v1.4.0 Three-Worlds reasoning corrected (the "structurally impossible" claim is empirically false per Tagged + cursor-shape-a-feasibility V1/V5/V6/V7). The narrower true Swift constraint (no Mode-discriminator conditional conformance per V3/V4 diagnostic) doesn't block Shape A because Storage-as-borrow-carrier sidesteps the discriminator entirely. Recommendation pending principal review.
