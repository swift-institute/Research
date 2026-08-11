# Small Buffer Storage Representation

<!--
---
version: 2.0.0
last_updated: 2026-02-15
status: SUPERSEDED
---
-->

## Context

During force-unwrap inventory of buffer-primitives, all four `Small` variants (Linear, Ring, Arena, Linked) were found to share the same storage pattern: two stored properties `_inlineBuffer` + `_heapBuffer: Optional`, with a `heap` computed property that centralizes `_heapBuffer!` force-unwrap behind `_read`/`_modify` coroutines. All call sites guard `_heapBuffer != nil` before accessing `heap`, but this is convention-enforced, not structurally guaranteed. The question is whether an enum storage representation would be safer.

**Trigger**: Concern that the force-unwrap inside the `heap` accessor is a footgun — a new method that forgets the `nil` guard would crash at runtime.

**Prior research**: [noncopyable-optional-access-patterns.md](noncopyable-optional-access-patterns.md) established that `switch` is the only borrowing-correct pattern for `~Copyable` optionals, and that `_heapBuffer!` is valid only in mutating contexts where consumption is allowed.

## Question

Should `Small` variants use an enum (`case inline(InlineBuffer) | case heap(HeapBuffer)`) instead of two stored properties (`_inlineBuffer` + `_heapBuffer: Optional`) to structurally eliminate force-unwrap?

## Constraint: Spill Semantics

A preliminary concern: "only the spillover gets transferred to heap." Prior art analysis shows this is not the case — **all SBO implementations transfer ALL elements during spill**. This is a universal invariant:

| Implementation | Spill Behavior | Simultaneous Active | Direction |
|----------------|---------------|---------------------|-----------|
| Rust SmallVec v1 | ALL elements | No | One-way (reversible) |
| Rust SmallVec v2 | ALL elements | No | One-way (reversible) |
| LLVM SmallVector | ALL elements | No | One-way |
| Boost small_vector | ALL elements | No | Permanent |
| folly::small_vector | ALL elements | No | One-way |
| Swift String (SSO) | Value replacement | N/A | N/A |
| **Buffer.*.Small** | **ALL elements** | **No** | **Reversible via `removeAll()`** |

Every `_spillToHeap` implementation in buffer-primitives confirms this: all elements move from inline to heap, then inline header resets to empty. After spill, `_inlineBuffer` is dead weight — it exists (embedded in the struct via value generic) but holds zero elements.

This means an enum **would** accurately model the state space: exactly one storage is active at a time.

### Why Not Partial Spill?

A natural question: could only the *overflow* element go to heap, keeping existing elements inline? This was evaluated and rejected.

**The spill cost is negligible.** Inline capacity is typically 4–16 elements. Moving 16 `Int64`s is 128 bytes — two cache lines, ~10ns. The `malloc` for the heap buffer costs 50–200ns. Element moves are noise next to the allocation.

**Every subsequent operation pays forever.** With split storage, every operation must check both storages and combine results:

| Operation | All-on-heap (current) | Split (inline + heap overflow) |
|-----------|----------------------|-------------------------------|
| `count` | Field read | Addition of two counts |
| `isEmpty` | Field comparison | Check both storages |
| `forEach` | Single iteration | Chain two iterators, branch per element |
| `subscript[i]` | Pointer + offset | Branch: `i < N` → inline, else → heap |
| `removeFirst()` | Shift in one buffer | Shift inline, pull from heap to fill gap |

One extra branch per operation, ~1–5ns each. After ~10 operations post-spill, the savings from not moving elements are already lost.

**Contiguous Span is impossible.** Linear and Ring guarantee contiguous memory — callers can obtain an `UnsafeBufferPointer` / `Span` over the elements. With elements split across stack-inline and heap, no single pointer can cover both regions. Every span access would require copying to a temporary contiguous buffer, which is strictly worse than moving once during spill.

**Linked can't cross storage boundaries.** Indices in Linked are offsets into a single `Storage.Pool`. A node at inline slot 3 can point to inline slot 5 via its link, but cannot point to heap slot 0 — they are different pools with different base addresses. A tagged-index scheme (which pool?) on every link traversal would be required.

**Arena's slot invariant breaks.** Arena promises that a `Position` handle obtained before spill remains valid after spill. The current design preserves this by copying elements to the *same* slot positions in the new heap allocation. With split storage, slot 2 could mean inline slot 2 or heap slot 2 depending on when it was issued.

**Prior art is unanimous.** No SBO implementation in any language (Rust SmallVec, LLVM SmallVector, Boost small_vector, folly::small_vector) splits elements across two active storages. The contiguous-memory guarantee makes partial spill fundamentally incompatible.

## Analysis

### Option A: Enum Storage

```swift
public struct Small<let inlineCapacity: Int>: ~Copyable {
    enum _Storage: ~Copyable {
        case inline(Inline<inlineCapacity>)
        case heap(Buffer<Element>.Linear)  // or Ring, Arena, Linked<N>
    }
    var _storage: _Storage
}
```

**Read access** — works via SE-0432 borrowing switch:
```swift
var count: Index<Element>.Count {
    switch _storage {
    case .inline(let buf): return buf.count
    case .heap(let buf): return buf.count
    }
}
```

**Mutation — the problem**. Swift enums do not support in-place mutation of associated values. Every mutating operation requires:
```swift
mutating func append(_ element: consuming Element) {
    switch _storage {
    case .inline(var buf):       // 1. Move payload OUT of enum (consume)
        if !buf.isFull {
            _ = buf.append(consume element)
            _storage = .inline(buf)  // 2. Move payload BACK into enum
        } else { /* spill */ }
    case .heap(var buf):         // 1. Move payload OUT
        buf.append(consume element)
        _storage = .heap(buf)    // 2. Move payload BACK
    }
}
```

Each mutation pays two extra moves (move out + move back). Contrast with the current design where `heap.append(element)` yields `&_heapBuffer!` via `_modify` — a direct mutable reference with zero moves.

**Critical limitation**: `Optional` has special compiler support for `_modify { yield &optional! }`, which yields a mutable reference directly into the wrapped value's storage location. Arbitrary `enum` types have no such support. There is no way to write `_modify { yield &_storage.heapPayload }` in Swift. This means every `_modify`-based accessor pattern (the `heap` property) becomes impossible with an enum.

**Compiler-level root cause** (validated against `swiftlang/swift` source): Optional's force-unwrap lowers to `ForceOptionalObjectComponent` in `SILGenLValue.cpp`, which emits the `unchecked_take_enum_data_addr` SIL instruction. This projects a mutable address directly into the `.some` payload without consuming the enum. The compiler comment states: *"safe to apply to Optional, because it is a single-payload enum."* For single-payload enums, the discriminant is stored in spare bits outside the payload — projection does not disturb the discriminant. For multi-payload enums, discriminant bits may overlap with payload data, making the same projection destructive (`UncheckedTakeEnumDataAddrInst` has an `isDestructive()` flag). The `MoveOnlyPartialReinitialization` experimental feature exists but applies only to structs and tuples. See `Experiments/noncopyable-enum-modify/` for the full 8-variant empirical validation.

**`removeAll()` transition**: With an enum, returning to inline mode means consuming the `.heap` case (dropping the heap buffer) and constructing a fresh `Inline<inlineCapacity>()`. With two fields, the `_inlineBuffer` already exists — just set `_heapBuffer = nil`. The enum approach constructs a new inline buffer each time.

**Advantages**:
- Structurally eliminates force-unwrap (compiler-enforced exhaustive switch)
- Accurately models the "one active at a time" state space
- No dead-weight `_inlineBuffer` after spill

**Disadvantages**:
- Two extra moves per mutation (move-out + move-back for ~Copyable payload)
- No `_modify` coroutine into enum payload — loses zero-cost mutable access
- `removeAll()` must construct fresh `InlineBuffer` (vs already existing)
- Larger refactor across all four Small variants + Buffer.swift type declarations
- Enum with `~Copyable` associated values has limited Swift compiler support; edge cases may not compile

### Option B: Two Fields with `heap` Accessor (Status Quo)

```swift
public struct Small<let inlineCapacity: Int>: ~Copyable {
    var _inlineBuffer: Inline<inlineCapacity>
    var _heapBuffer: Buffer<Element>.Linear?
}
```

With `package var heap` accessor:
```swift
package var heap: Buffer<Element>.Linear {
    _read { yield _heapBuffer! }
    _modify { yield &_heapBuffer! }
}
```

**Read access** at call sites: `if _heapBuffer != nil { return heap.count } else { return _inlineBuffer.count }`

**Mutation** at call sites: `if _heapBuffer != nil { heap.append(element) }` — `_modify` yields a direct mutable reference. Zero extra moves.

**Advantages**:
- Zero-cost mutation via `_modify { yield &_heapBuffer! }` — direct in-place access
- `removeAll()` reuses existing `_inlineBuffer` — no construction
- Current design, no refactor needed
- `Optional._modify` has special compiler support

**Disadvantages**:
- Force-unwrap in `_read`/`_modify` relies on convention (callers guard `_heapBuffer != nil`)
- Dead-weight `_inlineBuffer` exists after spill (empty but present — struct size includes inline storage regardless)

### Option C: Two Fields, No `heap` Accessor (switch everywhere)

Eliminate the `heap` computed property. Use `switch` for reads (per [noncopyable-optional-access-patterns.md](noncopyable-optional-access-patterns.md)) and `_heapBuffer!` directly for mutations (already inside `mutating func`).

**Read access**: `switch _heapBuffer { case .some(let heap): return heap.count; case .none: return _inlineBuffer.count }`

**Mutation**: `if _heapBuffer != nil { _heapBuffer!.append(element) }` — the `_heapBuffer!` is in a `mutating func` context where consumption is allowed.

**Advantages**:
- Eliminates the `heap` accessor (one less abstraction)
- Force-unwrap only appears in mutating contexts (consistent with [noncopyable-optional-access-patterns.md](noncopyable-optional-access-patterns.md) decision)
- `_read`-equivalent access uses borrowing `switch` — no force-unwrap for reads
- Each call site's `switch`/`if` guard is local and visible

**Disadvantages**:
- Force-unwrap scattered at mutation call sites (currently 8-15 per Small variant)
- More verbose than `heap.X()` delegation
- Duplicates the routing pattern per-method instead of centralizing it

### Comparison

| Criterion | A: Enum | B: Two Fields + `heap` (status quo) | C: Two Fields, no `heap` |
|-----------|---------|-------------------------------------|--------------------------|
| Force-unwrap eliminated | Yes (structurally) | No (8 sites in accessor) | No (scattered in mutating funcs) |
| Zero-cost mutation | No (2 extra moves) | Yes (`_modify` coroutine) | Yes (direct `_heapBuffer!`) |
| `_modify` yield into payload | Impossible | Yes | Not applicable |
| SE-0432 aligned for reads | Yes | No (`_read` uses `!`) | Yes |
| Convention discipline needed | None | Yes (guard before `heap`) | Yes (guard before `!`) |
| Refactor scope | Large (Buffer.swift + all 4 variants) | None | Medium (remove accessor, update all methods) |
| Dead weight after spill | None | `_inlineBuffer` (empty) | `_inlineBuffer` (empty) |
| `removeAll()` inline return | Constructs new InlineBuffer | Reuses existing | Reuses existing |

## Outcome

**Status**: SUPERSEDED by [small-buffer-enum-compiler-workarounds.md](small-buffer-enum-compiler-workarounds.md)

**Original decision (v1.x)**: Keep two-field storage (Option B), with improved documentation.

**Reversal (v2.0.0, 2026-02-15)**: Adopted enum storage (Option A) due to LLVM verifier crash. The two-field struct representation — where a `~Copyable` struct contains both `@_rawLayout` fields (`Storage.Inline`) and `ManagedBuffer` class references (`Storage.Heap`) — triggers "Instruction does not dominate all uses!" in release builds. This is a compiler-generated implicit destructor codegen bug, not a limitation of the Swift type system. The enum approach, while incurring two extra moves per mutation, produces correct code.

The performance analysis in v1.x remains valid: enum storage IS slower for mutations. But correct-and-slower beats incorrect-and-fast. See [small-buffer-enum-compiler-workarounds.md](small-buffer-enum-compiler-workarounds.md) for the full bug catalog and workaround documentation.

### Original Rationale (preserved for reference)

### Rationale

1. **`_modify` is non-negotiable for ~Copyable buffers.** The `heap` accessor's `_modify { yield &_heapBuffer! }` provides zero-cost mutable access into the Optional's wrapped value. This is only possible because `Optional` has special compiler support — the `unchecked_take_enum_data_addr` SIL instruction projects a mutable address directly into the `.some` payload without consuming the enum (validated against `swiftlang/swift` compiler source). An enum cannot provide this. For a buffer primitive where every mutation is performance-critical, two extra moves per operation is an unacceptable regression.

2. **The enum accurately models state but cannot serve it.** The state space IS "one of two" — prior art unanimously confirms this. But Swift's enum limitations for ~Copyable associated values make the structurally-correct representation impractical. The type system cannot currently express "yield a mutable reference into an enum case's payload."

3. **The force-unwrap is centralized and documented.** The `heap` accessor concentrates the force-unwrap in exactly one place per variant (2 lines: `_read` + `_modify`), with a precondition doc comment. This is safer than scattering `_heapBuffer!` across 15+ mutation call sites (Option C).

4. **Dead-weight inline storage is inherent to SBO.** The inline buffer is embedded in the struct via value generic — its memory exists regardless. An enum would not save memory because `sizeof(enum) = max(sizeof(.inline), sizeof(.heap))`, and the inline case carries the entire inline buffer. The same bytes exist either way.

### Documentation Requirement

The `heap` accessor in each Small variant MUST include a comment explaining:
- Why `_heapBuffer!` is used (no `_modify` for enum payloads in Swift)
- Why it is safe (all callers guard `_heapBuffer != nil`)
- Cross-reference to this research and [noncopyable-optional-access-patterns.md](noncopyable-optional-access-patterns.md)

```swift
/// Projected access to the heap buffer.
///
/// - Precondition: `isSpilled` — callers MUST guard `_heapBuffer != nil` before access.
@inlinable
package var heap: Buffer<Element>.Linear {
    // Force-unwrap is necessary: Optional._modify has compiler support for
    // yielding &_heapBuffer! that arbitrary enums lack (no _modify into enum
    // payloads). An enum storage representation was evaluated and rejected —
    // see Research/small-buffer-storage-representation.md.
    // Safe: all callers guard `_heapBuffer != nil` before accessing `heap`.
    _read { yield _heapBuffer! }
    _modify { yield &_heapBuffer! }
}
```

## Prior Art

| Implementation | Representation | Discriminant |
|----------------|---------------|--------------|
| Rust SmallVec v1 | Enum (tagged union) | Enum discriminant (1 word) |
| Rust SmallVec v2 | Bare union | LSB of length field |
| LLVM SmallVector | Single pointer + inline buffer | `BeginX == getFirstEl()` comparison |
| Boost small_vector | vector + custom allocator | Allocator checks pointer origin |
| folly::small_vector | Union (pointer vs inline array) | High bits of size field |

Rust SmallVec v1's enum approach works because Rust has `match` with mutable borrows into enum variants (`if let Some(ref mut x) = opt`). Swift has no equivalent — `switch` with `var` binding consumes, it does not borrow mutably.

## References

- [noncopyable-optional-access-patterns.md](noncopyable-optional-access-patterns.md) — access pattern rules for ~Copyable optionals
- [Experiments/noncopyable-enum-modify/](../Experiments/noncopyable-enum-modify/) — 8-variant empirical validation of enum vs Optional `_modify` for ~Copyable types
- SE-0432: Borrowing and consuming pattern matching for noncopyable types
- SE-0427: Noncopyable generics
- [servo/rust-smallvec](https://github.com/servo/rust-smallvec) — SmallVec enum representation
- [llvm/SmallVector.h](https://github.com/llvm/llvm-project/blob/main/llvm/include/llvm/ADT/SmallVector.h) — single-pointer SBO
- Swift compiler source (`swiftlang/swift`):
  - `lib/SILGen/SILGenLValue.cpp:966-987` — `ForceOptionalObjectComponent` emits `unchecked_take_enum_data_addr`
  - `lib/SILGen/SILGenLValue.cpp:550-593` — `getPayloadOfOptionalValue`: "safe to apply to Optional, because it is a single-payload enum"
  - `include/swift/SIL/SILInstruction.h:7243` — `UncheckedTakeEnumDataAddrInst` with `isDestructive()` flag
  - `lib/SILOptimizer/Mandatory/MoveOnlyAddressCheckerUtils.cpp:1866` — TODO: "Revisit this when we introduce deinits on enums"
