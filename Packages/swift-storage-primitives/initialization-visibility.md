# Initialization Property Visibility

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
---
-->

> **Dependency**: This question may be superseded by `per-slot-initialization-tracking.md` — if BitVector-based per-slot tracking is adopted, the `_initialization` property may cease to exist as a settable property.

## Context

We refactored `Storage.Heap` to prevent "state drift" - a footgun where callers manually initialize/move/deinitialize elements but forget to update `initialization` state, leading to memory leaks or double-deinit crashes.

The solution implemented:
1. Made `initialization` read-only publicly (getter only)
2. Added `_initialization` with `package` visibility for internal use
3. Added tracked API: `initialize.next(to:)`, `move.last()`, `deinitialize.all()`

Now `buffer-primitives` (a separate package) fails to compile because it assigns to `storage.initialization` in 30 locations. Buffer-primitives is a higher-level abstraction that maintains its own header state and syncs it with storage's initialization state.

## Question

Should `_initialization` be made `public` to allow external packages like buffer-primitives to set initialization state directly?

## Analysis

### Option A: Make `_initialization` public

**Description**: Change `_initialization` from `package` to `public` visibility. External packages use `storage._initialization = ...`.

**Advantages**:
- Zero breaking changes for buffer-primitives (just rename `.initialization` to `._initialization`)
- Simple mechanical update (30 find-replace operations)
- Underscore prefix signals "advanced/internal use"
- Allows other legitimate higher-level abstractions to control storage state
- Consistent with Swift's convention of `_` prefix for internal-but-accessible APIs

**Disadvantages**:
- Undermines the "prevent state drift" goal for ALL users
- Any user can bypass the safe tracked API
- Underscore is a weak barrier - developers may use it anyway
- Creates two parallel APIs with different safety guarantees
- Documentation burden: must explain when to use which API

### Option B: Buffer-primitives updates to use `_initialization` (requires package visibility change)

This is equivalent to Option A since buffer-primitives is a SEPARATE package. Package visibility doesn't cross package boundaries.

### Option C: Add `@_spi(StorageInternal)` for selective access

**Description**: Use Swift's `@_spi` attribute to expose `_initialization` only to specific clients.

**Advantages**:
- Selective access - only explicitly opted-in clients can use it
- Clear contract: "you're using internal API"
- Stronger barrier than underscore prefix

**Disadvantages**:
- `@_spi` is underscored (unstable) Swift feature
- Requires buffer-primitives to `@_spi(StorageInternal) import Storage_Primitives`
- Additional complexity for legitimate use cases
- May not be supported long-term

### Option D: Buffer-primitives uses tracked API exclusively

**Description**: Refactor buffer-primitives to use only the safe tracked API (`initialize.next(to:)`, `move.last()`, `deinitialize.all()`).

**Advantages**:
- Validates that the tracked API is sufficient for real-world use
- Buffer-primitives becomes a showcase for safe storage usage
- No public `_initialization` needed
- Strongest safety guarantees

**Disadvantages**:
- Tracked API may be insufficient for buffer-primitives' needs:
  - Ring buffers need `.two(first:second:)` initialization (disjoint ranges)
  - Buffers sync from header state, not linear discipline
  - `initialize.next(to:)` assumes linear growth, not arbitrary slot access
- Would require significant tracked API expansion
- May force buffer-primitives into awkward patterns

### Option E: Separate "managed" vs "unmanaged" storage types

**Description**: Create `Storage.Heap.Managed` (tracked API only) and `Storage.Heap.Unmanaged` (direct access).

**Advantages**:
- Clear separation of concerns at type level
- Users choose their safety level explicitly
- No confusion about which API to use

**Disadvantages**:
- Significant API surface expansion
- Code duplication or complex type hierarchy
- Breaks existing code
- Over-engineering for the problem at hand

## Evaluation Criteria

| Criterion | Weight | A: Public | C: @_spi | D: Tracked Only | E: Separate Types |
|-----------|--------|-----------|----------|-----------------|-------------------|
| Safety for typical users | High | Poor | Good | Excellent | Excellent |
| Supports buffer-primitives | High | Excellent | Good | Poor | Good |
| Implementation effort | Medium | Trivial | Low | High | Very High |
| API clarity | Medium | Fair | Good | Excellent | Excellent |
| Future stability | Medium | Good | Poor | Good | Good |
| Ecosystem consistency | Low | Good | Fair | Good | Fair |

## Constraints

1. Buffer-primitives is a legitimate client that needs direct control over storage state
2. Buffer-primitives maintains its own header with initialization state
3. Ring buffers use `.two(first:second:)` for disjoint ranges - not supported by tracked API
4. The tracked API assumes linear discipline - buffer-primitives doesn't always follow this
5. We want to prevent state drift for typical users
6. We don't want to break working higher-level abstractions

## Key Insight

The tracked API (`initialize.next(to:)`, `move.last()`) was designed for **linear discipline** - contiguous elements from slot 0. Buffer-primitives supports:
- **Ring buffers**: Wrapped ranges with `.two(first:second:)`
- **Slab buffers**: Sparse allocation tracked by BitVector
- **Arbitrary slot access**: Initialize at any slot, not just "next"

The tracked API is fundamentally insufficient for buffer-primitives without major expansion.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option A - Make `_initialization` public

**Rationale**:
1. The tracked API is designed for linear discipline; buffer-primitives legitimately needs non-linear patterns
2. Making `_initialization` public with underscore prefix follows Swift convention for "internal but accessible"
3. The primary safety goal (protecting typical users) is still achieved - `initialization` is read-only
4. Advanced users (like buffer-primitives authors) can use `_initialization` when they understand the implications
5. Trivial implementation - just change `package` to `public`

**Implementation**:
```swift
// In Storage.Heap ~Copyable.swift
public var _initialization: Storage.Initialization {
    get { header.initialization }
    set { header.initialization = newValue }
}
```

**Migration for buffer-primitives**:
- Find-replace: `storage.initialization =` → `storage._initialization =`
- 30 occurrences, mechanical change

## References

- Research: `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/initialization-visibility.md`
- Related: State drift prevention design discussion (conversation context)

### Deferral

**Date**: 2026-03-15

**Reason**: The document reached RECOMMENDATION status (Option A: make `_initialization` public with underscore prefix). The implementation is trivial (change `package` to `public` on the `_initialization` property, then 30 find-replace operations in buffer-primitives). Execution was deferred because buffer-primitives focus shifted to the inline module split and higher-priority buffer restructuring work. The visibility change is a one-line fix that can be applied whenever buffer-primitives compilation against storage-primitives is next needed.

**Resume when**: Buffer-primitives needs to compile against updated storage-primitives with the read-only `initialization` property.
