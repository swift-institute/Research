# Buffer Core Pattern Unification

<!--
---
version: 1.0.0
last_updated: 2026-02-12
status: RECOMMENDATION
tier: 2
type: discovery/consistency-analysis
---
-->

## Context

Following the checkpoint Comparable trichotomy fix, a comparative analysis of all buffer variants in Buffer Primitives Core identified several pattern divergences. This literature study synthesizes prior research and conventions to determine which changes should be implemented, optimizing for **maximally correct implementations** with **minimal public API surface**.

**Trigger**: [RES-012] Discovery — post-audit unification of buffer variant patterns.

**Prior research consulted**:

| Document | Status | Relevance |
|----------|--------|-----------|
| `buffer-variant-parity-analysis.md` | IN_PROGRESS | P1 naming items largely resolved; P2–P5 remain open |
| `checkpoint-ordering-design.md` | RECOMMENDATION | Implemented — explicit `==` on all Checkpoint types |
| `theoretical-buffer-primitives-design.md` | RECOMMENDATION | Three-layer architecture; Header as Copyable/Sendable/Hashable |
| `buffer-ring-consumer-api-boundary.md` | IN_PROGRESS | Public API should encapsulate all buffer invariants |
| Design skill | — | API layering, minimal surface principle |
| Implementation skill | — | Intent-over-mechanism, error strategy |

## Question

Given the current state of Buffer Primitives Core, what specific changes are needed to achieve maximally correct implementations with minimal public API surface?

---

## Analysis

### Methodology

Each divergence is evaluated against two criteria:

1. **Correctness**: Does the current state violate a contract, invariant, or Swift language requirement?
2. **Minimal API surface**: Does the current state expose more than consumers need?

Changes are only recommended when they improve correctness OR reduce unnecessary API surface without sacrificing usability.

### Inventory: Already Resolved

The parity analysis (2026-02-11) identified Priority 1 naming inconsistencies. Verification against current code shows these are **already resolved**:

| P1 Item | Finding |
|---------|---------|
| P1-1: Error case `.capacityExhausted`/`.full` | All variants now use `.capacityExceeded` |
| P1-2: Arena `_arenaStorage` field name | All Arena variants now use `storage` |
| P1-3: Linked `static func create` instead of `init` | `init(minimumCapacity:)` exists (wraps `create` with `try!`) |
| P1-4: Linear `consumeFront` naming | All variants now use `removeFirst()` |
| P1-5: CoW `makeUnique`/`isStorageUnique` naming | All variants now use `ensureUnique() -> Bool` |
| Checkpoint trichotomy | Explicit `==` added to Ring.Checkpoint, Ring.Small.Checkpoint, Parser.Tracked.Checkpoint |

No Priority 1 naming work remains.

### Divergence 1: Header Hashable Conformance

**Current state**:

| Header | Copyable | Sendable | Hashable | Equatable |
|--------|----------|----------|----------|-----------|
| Ring.Header | ✓ | ✓ | **✓** | (via Hashable) |
| Ring.Header.Cyclic | ✓ | ✓ | ✗ | ✗ |
| Linear.Header | ✓ | ✓ | ✗ | ✗ |
| Slab.Header | ~Copyable | — | N/A | N/A |
| Slab.Header.Static | ✓ | ✓ | ✗ | ✗ |
| Linked.Header | ✓ | ✓ | ✗ | ✗ |
| Slots.Header | ✓ | ✓ | **✓** | (via Hashable) |
| Arena.Header | ✓ | ✓ | ✗ | ✗ |

**Literature**: The theoretical design document (line 470, 488) declares Headers as `Copyable, Sendable, Hashable`. This would mean adding Hashable to Linear.Header, Linked.Header, Arena.Header, Slab.Header.Static, and Ring.Header.Cyclic.

**Usage**: Grep across the entire swift-primitives repository finds **zero** uses of Header Hashable or Equatable. No code compares headers with `==`, uses them as dictionary keys, or stores them in Sets.

**Correctness assessment**: Auto-synthesized Hashable on all-Hashable-field value types is always correct. Neither adding nor removing Hashable introduces a correctness issue.

**API surface assessment**: Hashable implies Equatable. Committing to Hashable means: (a) all fields participate in equality forever, and (b) consumers may begin depending on header equality/hashing. For types that are pure cursor state (just integers), this commitment is low-risk. However, the minimal-surface principle says: don't commit to what isn't needed.

**Options**:

| Option | Action | API delta |
|--------|--------|-----------|
| A. Unify up | Add Hashable to all Copyable headers | +5 conformances |
| B. Unify down | Remove Hashable from Ring.Header and Slots.Header | −2 conformances |
| C. Status quo | Leave mixed | 0 (inconsistent) |

**Recommendation**: **Option B — Remove Hashable from Ring.Header and Slots.Header.**

Rationale:
- Zero demonstrated need across the codebase
- Minimal API surface: don't expose what isn't used
- Can be added back consistently later when a use case arises
- Removing Hashable also removes the implicit Equatable commitment
- If external code depends on `Ring.Header == Ring.Header`, this is source-breaking — but headers are expert-level types at the static-operations layer, and no evidence of such usage exists

### Divergence 2: `@frozen` on Linked.Node and Arena.Position

**Current state**: Only `Linked.Node` and `Arena.Position` are `@frozen`. All other structs (Checkpoints, Headers, buffer types) are not.

**Documented rationale** (Buffer.swift:637–638):
> `@frozen` because cross-module partial consumption of ~Copyable types requires known layout.

**Correctness assessment**: `@frozen` is a correctness requirement for cross-module move operations on ~Copyable types. `Linked.Node` is ~Copyable (contains `Element: ~Copyable`). `Arena.Position` is Copyable but `@frozen` for ABI stability of the compact 8-byte handle representation.

**No other type needs `@frozen`**:
- Checkpoints: Copyable, no cross-module consumption
- Headers: Copyable, no cross-module consumption
- Buffer types: ~Copyable, but only accessed through methods — never consumed cross-module by field

**Recommendation**: **No change.** The `@frozen` usage is correct and justified. The inconsistency is structural, not a style issue.

### Divergence 3: Linked.Node Public Init

**Current state**: `Linked.Node.init(element:links:)` is the only non-Header/non-Position struct init that is `public`. All buffer type inits are `package`.

**Analysis**: Node construction is an internal operation — `buffer.insertFront(element)` creates nodes internally. External consumers never construct nodes directly.

However, `@frozen` types with `package` init still work cross-module for storage operations. The `public` init is unnecessary unless direct node construction is a design intent.

**Recommendation**: **Demote to `package init`.** Buffer operations handle node construction. External consumers should not construct nodes directly.

Risk: If any external package constructs `Linked.Node` directly, this breaks. Verify before applying.

### Divergence 4: Arena.Small Missing Query Properties

**Current state**:

| Property | Ring.Small | Linear.Small | Linked.Small | Arena.Small |
|----------|:---------:|:------------:|:------------:|:-----------:|
| count/occupied | ✓ | ✓ | ✓ | **✗** |
| isEmpty | ✓ | ✓ | ✓ | **✗** |
| isFull | ✓ | ✓ | ✓ | **✗** |

**Correctness assessment**: Arena.Small is unusable from external packages — consumers cannot query element count, emptiness, or fullness. This is a **usability defect**.

**Recommendation**: **Add `occupied`, `isEmpty`, `isFull` to Arena.Small.** These are necessary for basic usability. Use `occupied` (not `count`) to match Arena's vocabulary.

```swift
extension Buffer.Arena.Small where Element: ~Copyable {
    public var occupied: Index<Element>.Count {
        _heapBuffer != nil ? heap.occupied : _inlineBuffer.header.occupied
    }

    public var isEmpty: Bool { occupied == .zero }

    public var isFull: Bool {
        _heapBuffer != nil ? false : _inlineBuffer.isFull
    }
}
```

Note: `isFull` returns `false` for spilled arenas because the heap variant is growable.

### Divergence 5: `isSpilled` Visibility

**Current state**: `public var isSpilled: Bool` exists on Ring.Small, Linear.Small, and Linked.Small. Arena.Small does not expose it.

**API surface assessment**: `isSpilled` reveals the inline-vs-heap storage strategy. This is an implementation detail. The consumer API boundary research (Option A) explicitly states buffer should encapsulate all internal concerns. Consumers should not branch on storage location.

**Counter-argument**: `isSpilled` is useful for:
- Testing: verify spill behavior
- Performance diagnostics: detect unexpected heap allocation
- Assertions: ensure inline path in hot loops

**Options**:

| Option | Action | API delta |
|--------|--------|-----------|
| A. Unify up | Add `isSpilled` to Arena.Small | +1 property |
| B. Unify down | Demote `isSpilled` to `package` on all Small variants | −3 properties (public → package) |
| C. Status quo | Leave mixed | 0 (inconsistent) |

**Recommendation**: **Option B — Demote `isSpilled` to `package` on all Small variants.**

Rationale:
- Implementation detail per consumer API boundary design
- Testing can access via `@testable import`
- Minimal API surface: consumers shouldn't depend on storage strategy
- Consistent with the principle that Small variants present a unified interface regardless of backing storage

### Divergence 6: INV-INLINE-004a Comment Duplication

**Current state**: The same 6-line comment explaining why Inline variants can't conform to Copyable is repeated 5 times (Ring, Linear, Slab, Linked, Arena sections).

**Recommendation**: **Replace with single top-level comment and back-references.**

```swift
// MARK: - INV-INLINE-004a: Storage.Inline Copyable Restriction
//
// Storage.Inline uses @_rawLayout which is unconditionally ~Copyable.
// @_rawLayout is required because InlineArray has no uninitialized API
// and requires Copyable for init(repeating:), but Storage.Inline must
// support ~Copyable elements. If Swift adds
// InlineArray.init(unsafeUninitializedCapacity:), Storage.Inline could
// migrate and these conformances can be restored.

// MARK: - Conditional Conformances (Ring)
// ...
// Inline/Small: Copyable suppressed per INV-INLINE-004a.
```

### Not Recommended: Changes Considered and Rejected

| Change | Reason for rejection |
|--------|---------------------|
| Add Hashable to all Copyable Headers | Unnecessary API expansion; no demonstrated use |
| Add `@frozen` to Checkpoints | Checkpoints are Copyable; no cross-module consumption |
| Make `Linked.create(capacity:)` package | It's throwing and wraps pool allocation; `init(minimumCapacity:)` wraps it with `try!`. Both being public serves different error-handling preferences |
| Standardize Ring.Header.Cyclic to match Ring.Header conformances | If removing Hashable from Ring.Header, Cyclic is already correct (no Hashable) |
| Unify Sendable `@unchecked` pattern | Current pattern is correct: `@unchecked` on heap-backed (reference-semantic), plain `Sendable` on inline/small (value-semantic). Not an inconsistency — reflects ownership reality |
| Unify Header property access levels | All public — correct for the static-operations layer per three-layer architecture |
| Unify init consuming patterns | Variation is structurally driven: Slab consumes ~Copyable Header; Inline consumes @_rawLayout storage; others don't need consuming. Not an inconsistency |

---

## Outcome

**Status**: RECOMMENDATION

### Changes to Implement

Ordered by priority (correctness first, then API surface, then code quality):

| # | Change | Category | Files | Risk |
|---|--------|----------|-------|------|
| 1 | Remove `Hashable` from `Ring.Header` | API surface | Buffer.swift:210 | Low (no usage found) |
| 2 | Remove `Hashable` from `Slots.Header` | API surface | Buffer.swift:799 | Low (no usage found) |
| 3 | Add `occupied`, `isEmpty`, `isFull` to `Arena.Small` | Usability defect | Buffer.Arena.Small.swift | None (additive) |
| 4 | Demote `isSpilled` to `package` on Ring.Small, Linear.Small, Linked.Small | API surface | 3 Small .swift files | Low (implementation detail) |
| 5 | Demote `Linked.Node.init` to `package` | API surface | Buffer.swift:649 | Low (verify no external use) |
| 6 | Deduplicate INV-INLINE-004a comments | Code quality | Buffer.swift:1121–1210 | None |

### Verification

```bash
# After changes, verify all tests still pass:
cd /Users/coen/Developer/swift-primitives/swift-buffer-primitives && swift test
cd /Users/coen/Developer/swift-primitives/swift-input-primitives && swift test
cd /Users/coen/Developer/swift-primitives/swift-queue-primitives && swift test
```

### Changes NOT to Implement

The parity analysis P2–P5 items (missing protocol conformances, missing sub-variants, missing tests, file organization) are **out of scope** for this correctness+minimal-surface audit. They add API surface; they don't reduce it. They should be addressed in separate focused work.

## References

- `buffer-variant-parity-analysis.md` — Comprehensive parity audit (P1 items verified resolved)
- `checkpoint-ordering-design.md` — Checkpoint trichotomy fix (implemented)
- `theoretical-buffer-primitives-design.md` — Three-layer architecture, Header conformance design
- `buffer-ring-consumer-api-boundary.md` — Consumer API boundary design (Option A)
- `Buffer.swift:1–1212` — All type declarations and conditional conformances
- Design skill: [API-LAYER-001], [API-LAYER-002]
- Implementation skill: [IMPL-INTENT], [IMPL-040], [IMPL-041]
