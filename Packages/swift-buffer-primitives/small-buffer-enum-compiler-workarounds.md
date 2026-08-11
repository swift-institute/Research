# Small Buffer Enum Representation: Compiler Bugs and Workarounds

<!--
---
version: 1.0.0
last_updated: 2026-02-15
status: DECISION
---
-->

## Context

During release-build validation of buffer-primitives on Swift 6.2 (development snapshot 2026-02-08-a), all five `Small` types (`Ring.Small`, `Linear.Small`, `Slab.Small`, `Linked.Small`, `Arena.Small`) crashed with LLVM verifier error "Instruction does not dominate all uses!" (14 errors from 5 types). The root cause was the two-field struct representation where a `~Copyable` struct contained both a `@_rawLayout` field (`Storage.Inline`) and a `ManagedBuffer` class reference (`Storage.Heap`). The compiler-generated implicit destructor emitted incorrect LLVM IR for this combination.

The fix was to change all five `Small` types from two-field structs to `@frozen` enums with `case inline | case heap`. This was a reversal of the prior DECISION in [small-buffer-storage-representation.md](small-buffer-storage-representation.md), which had concluded that enum representation was impractical due to the lack of `_modify` into enum payloads. The LLVM verifier crash made the two-field approach untenable — correctness overrides performance.

**Trigger**: LLVM verifier crash blocking release builds.

**Prior research**: [small-buffer-storage-representation.md](small-buffer-storage-representation.md) — original analysis that chose two-field storage (Option B). That decision has been superseded.

## Question

What compiler bugs were encountered during the enum representation refactoring, and what workarounds were applied?

## Bug Catalog

Three distinct compiler bugs were encountered. All are in the SIL optimizer or diagnostic passes, not in the type checker. The code is well-formed Swift — only the compiler's intermediate representation handling is broken.

### Bug 1: LLVM Verifier — "Instruction does not dominate all uses!" (release, signal 6)

**Category**: Implicit destructor codegen
**Signal**: 6 (SIGABRT)
**Pass**: LLVM verification (after SIL lowering)
**Trigger**: `~Copyable` struct with BOTH `@_rawLayout` stored property AND `ManagedBuffer` class stored property
**Reproduction**: Any `Small` type before the enum refactoring, built with `swift build -c release`

**Root cause**: The compiler-generated implicit destructor for a struct containing both `@_rawLayout` fields (which use custom memory layout with no standard destroy sequence) and `ManagedBuffer` subclass references (which use ARC release) emits LLVM IR where an instruction's definition does not dominate its uses. This is invalid SSA form.

**Fix**: Enum representation. With `case inline | case heap`, only one variant exists at destruction time. The compiler generates separate destruction paths per case, avoiding the mixed-storage problem entirely.

**Affected types** (all 5 Small variants):

| Type | Module |
|------|--------|
| `Buffer<Element>.Ring.Small<inlineCapacity>` | Buffer Ring Primitives |
| `Buffer<Element>.Linear.Small<inlineCapacity>` | Buffer Linear Primitives |
| `Buffer<Element>.Slab.Small<inlineCapacity>` | Buffer Slab Primitives |
| `Buffer<Element>.Linked<N>.Small<inlineCapacity>` | Buffer Linked Primitives |
| `Buffer<Element>.Arena.Small<inlineCapacity>` | Buffer Arena Primitives |

**Workaround applied**: Enum `_Representation` with `@frozen` attribute. Declared in `Buffer.swift`:

```swift
@frozen
public struct Small<let inlineCapacity: Int>: ~Copyable {
    // WORKAROUND: Enum storage instead of two-field struct
    @frozen @usableFromInline
    package enum _Representation: ~Copyable {
        case inline(Inline<inlineCapacity>)
        case heap(Buffer<Element>.Ring)  // or Linear, Slab, Linked<N>, Arena
    }
    @usableFromInline
    package var _storage: _Representation
}
```

**`@frozen` requirement**: Without `@frozen` on both the struct and the enum, the compiler produces 103 "cannot partially consume 'self' of non-frozen type" errors. Mutations require consuming the enum payload via `case .heap(var buf)`, modifying it, and reinitializing `self = Self(_storage: .heap(consume buf))`. This consume-modify-reinit pattern requires `@frozen` so the compiler can prove layout stability.

**Mutation pattern**: Every mutating method follows the same pattern:

```swift
mutating func operation(_ element: consuming Element) {
    switch _storage {
    case .heap(var buf):
        buf.operation(consume element)
        self = Self(_storage: .heap(consume buf))
    case .inline(var buf):
        buf.operation(consume element)
        self = Self(_storage: .inline(consume buf))
    }
}
```

This is the inherent cost of enum storage vs Optional's `_modify { yield &_heapBuffer! }` — two extra moves per mutation (move out + move back). Accepted as the price of correctness.

### Bug 2: DiagnoseStaticExclusivity — Signal 11 (debug and release)

**Category**: SIL diagnostic pass crash
**Signal**: 11 (SIGSEGV)
**Pass**: DiagnoseStaticExclusivity
**Trigger**: `borrowing get` or `_read` coroutine that delegates to a payload's `.span` property through a `@frozen ~Copyable` enum, when the delegated-to property has lifetime annotations (`_overrideLifetime`)
**Reproduction**: `Buffer.Linear.Small.span` delegating to `heap.span` or `buf.span`

**Root cause**: The DiagnoseStaticExclusivity SIL pass (which verifies Law of Exclusivity at compile time) crashes with a null pointer or out-of-bounds access when analyzing the lifetime chain through enum payload projection → borrowing property → `_overrideLifetime`. The chain involves:
1. `switch _storage { case .heap(let heap): }` — enum payload projection
2. `heap.span` — borrowing property access on the projected value
3. `_overrideLifetime(span, borrowing: self)` — lifetime annotation back to the outer type

The pass cannot model this multi-level borrow chain through an enum payload.

**Affected operations**:

| Operation | File | Status |
|-----------|------|--------|
| `span` borrowing get | `Buffer.Linear.Small+Span.swift` | Fixed (direct pointer construction) |
| `mutableSpan` mutating get | `Buffer.Linear.Small+Span.swift` | Fixed (extract-then-construct) |
| `~Copyable subscript _modify` | `Buffer.Linear.Small+Subscript.swift` | Disabled (commented out) |

**Workaround 1 — Direct pointer construction for `span`**: Instead of delegating to `heap.span` (which has its own `_overrideLifetime`), construct `Span` directly from the storage pointer:

```swift
// BEFORE (crashes):
case .heap(let heap):
    return unsafe _overrideLifetime(heap.span, borrowing: self)

// AFTER (works):
case .heap(let heap):
    let span = unsafe Span(
        _unsafeStart: UnsafePointer(heap.storage.pointer(at: .zero)),
        count: heap.header.count
    )
    return unsafe _overrideLifetime(span, borrowing: self)
```

**Workaround 2 — Extract-then-construct for `mutableSpan`**: The `_overrideLifetime(span, mutating: &self)` call inside the switch creates overlapping access (`switch` borrows `self`, `&self` needs exclusive access). Fix: extract pointer and count from the switch, then construct the span outside:

```swift
public var mutableSpan: MutableSpan<Element> {
    @_lifetime(&self) @inlinable
    mutating get {
        let start: UnsafeMutablePointer<Element>
        let elementCount: Index<Element>.Count
        switch _storage {
        case .heap(let heap):
            unsafe start = heap.storage.pointer(at: .zero)
            elementCount = heap.header.count
        case .inline(let buf):
            let inlineBounded = Index<Element>.Bounded<inlineCapacity>(.zero)!
            unsafe start = buf.storage.pointer(at: inlineBounded)
            elementCount = buf.header.count
        }
        let span = unsafe MutableSpan(_unsafeStart: start, count: elementCount)
        return unsafe _overrideLifetime(span, mutating: &self)
    }
}
```

**Workaround 3 — `_modify` disabled**: The `~Copyable` subscript `_modify` remains commented out because yielding a pointer into an enum payload triggers the same DiagnoseStaticExclusivity crash. The Copyable subscript `_modify` works because it can use `ensureUnique()` and then yield through the pointer directly.

### Bug 3: CopyPropagation — Signal 6 (release only)

**Category**: SIL optimization pass crash
**Signal**: 6 (SIGABRT)
**Pass**: CopyPropagation
**Trigger**: Two distinct patterns:
1. Moving `~Copyable` elements in a loop with conditional bitmap checks + `storage.move()` / `storage.deinitialize()`
2. Consuming a `~Copyable Element` parameter inside `switch _storage { case .heap(var heap) }` — two consuming operations (the element and the enum payload) in one branch

**Root cause**: The CopyPropagation SIL optimization pass cannot model the ownership state of `~Copyable` values in loops where consumption is conditional on runtime state (bitmap bits), or in enum switches where multiple values are consumed in the same branch.

**Workaround**: `@_optimize(none)` on the affected functions. This disables all SIL optimization passes including CopyPropagation for the specific function, while leaving the rest of the module fully optimized.

**Affected functions**:

| Function | File | Module | Pre-existing? |
|----------|------|--------|---------------|
| `Buffer.Slab.Inline.consume()` | `Buffer.Slab.Inline+Consume.swift:59` | Buffer Slab Primitives | Yes |
| `Buffer.Slab.Inline.removeAll()` | `Buffer.Slab.Inline.swift:82` | Buffer Slab Primitives | Yes |
| `Buffer.Slab.Inline.drain()` | `Buffer.Slab.Inline.swift:126` | Buffer Slab Primitives | Yes |
| `Buffer.Slab.Small._spillToHeapMoving()` | `Buffer.Slab.Small.swift:150` | Buffer Slab Primitives | No (enum refactoring) |
| `Buffer.Linked.Small._insertFrontAfterSpill()` | `Buffer.Linked.Small ~Copyable.swift:164` | Buffer Linked Primitives | No (enum refactoring) |
| `Buffer.Linked.Small._insertBackAfterSpill()` | `Buffer.Linked.Small ~Copyable.swift:178` | Buffer Linked Primitives | No (enum refactoring) |

Three of six were pre-existing (verified by stashing enum changes and running original release build — the Slab.Inline functions crashed before our changes too). The other three were introduced by the enum refactoring.

**Note on Linked.Small**: The original `_insertFront` method had a nested switch pattern:

```swift
case .inline(var buf):
    if !buf.isFull {
        // inline insert
    } else {
        self = Self(_storage: .inline(consume buf))
        _spillToHeapMoving()
        // nested switch _storage { case .heap(var heap): consume element }
    }
```

The nested switch with consuming `element` inside a branch that already consumed `buf` crashed CopyPropagation. The fix was to extract the post-spill insertion into separate methods (`_insertFrontAfterSpill`, `_insertBackAfterSpill`), but the crash followed the consuming pattern into the extracted methods. Only `@_optimize(none)` on those methods resolved it.

## Workaround Summary

| # | Bug | Workaround | Scope | Performance Impact |
|---|-----|-----------|-------|-------------------|
| 1 | LLVM Verifier | Enum `_Representation` | All 5 Small types | 2 extra moves per mutation |
| 2a | DiagnoseStaticExclusivity (span) | Direct pointer construction | Linear.Small.span | None (same codegen) |
| 2b | DiagnoseStaticExclusivity (mutableSpan) | Extract-then-construct | Linear.Small.mutableSpan | None (same codegen) |
| 2c | DiagnoseStaticExclusivity (_modify) | Disabled | Linear.Small subscript | ~Copyable elements cannot be modified in-place |
| 3 | CopyPropagation | `@_optimize(none)` | 6 functions | No inlining/optimization for those functions |

## Removal Criteria

All workarounds follow [PATTERN-016] and include removal criteria in code comments.

| Workaround | When to Remove |
|------------|---------------|
| Enum `_Representation` | When Swift fixes implicit destructor codegen for mixed `@_rawLayout` + class stored properties. At that point, the two-field struct representation could be restored — but the enum has been proven correct and may be preferable to keep. |
| Direct pointer construction (span) | When DiagnoseStaticExclusivity handles borrowing delegation through `@frozen ~Copyable` enum payloads with lifetime annotations. |
| Extract-then-construct (mutableSpan) | Same as span. |
| `_modify` disabled | Same as span. Alternatively, when Swift supports `_modify` into enum payloads (the `MoveOnlyPartialReinitialization` feature). |
| `@_optimize(none)` functions | When CopyPropagation handles `~Copyable` element moves in conditional loops and multi-consume enum branches. |

## Validation

### Debug build
All modules compile clean. Zero warnings, zero errors.

### Release build
All modules compile clean after all workarounds applied. Zero warnings, zero errors.

### Tests
333 tests pass across 32 suites. All buffer variants (Linear, Ring, Slab, Linked, Arena) and their Small/Inline sub-variants tested.

### Pre-existing verification
Stashing the enum changes and running the original release build confirmed:
- 9 instances of "Instruction does not dominate all uses!" (the LLVM verifier crash we fixed)
- 3 CopyPropagation crashes on Slab.Inline functions (pre-existing, now annotated)

## Outcome

**Status**: DECISION

All workarounds are applied, documented per [PATTERN-016], and validated. The enum representation is correct and the release build succeeds. The workarounds are conservative — they disable compiler optimization on 6 specific functions and disable one subscript `_modify` accessor. No functional regression exists (all 333 tests pass).

The three compiler bugs should be reported to `swiftlang/swift` with minimal reproductions when time permits.

## References

- [small-buffer-storage-representation.md](small-buffer-storage-representation.md) — original analysis (Option B chosen, now superseded by this document)
- [noncopyable-optional-access-patterns.md](noncopyable-optional-access-patterns.md) — access pattern rules for ~Copyable optionals
- `Buffer.swift` lines 115–136 — Ring.Small enum declaration with full WORKAROUND annotation
- `Buffer.Linear.Small+Span.swift` — direct pointer construction workaround
- `Buffer.Linear.Small+Subscript.swift` — disabled `_modify` with WORKAROUND annotation
- `Buffer.Linked.Small ~Copyable.swift` lines 157–189 — `@_optimize(none)` after-spill methods
- `Buffer.Slab.Inline.swift` — `@_optimize(none)` on removeAll, drain
- `Buffer.Slab.Inline+Consume.swift` — `@_optimize(none)` on consume
- `Buffer.Slab.Small.swift` — `@_optimize(none)` on _spillToHeapMoving
- Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-02-08-a
- Platform: macOS 15.x (arm64)
