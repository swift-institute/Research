# Audit: swift-linux-primitives

## Implementation (Domain Modelling) — 2026-04-09

### Scope

- **Target**: `Linux Kernel IO Uring Primitives` (63 source files)
- **Skill**: implementation — [IMPL-INTENT], [IMPL-002], [IMPL-006], [IMPL-010], [IMPL-COMPILE]
- **Focus**: Domain modelling quality. All raw `Int`, `UInt32`, `UInt64`, `Int32`, `UInt16`, `UInt8` in public API surfaces, stored properties, and type definitions.
- **Files**: 63 source files in `Sources/Linux Kernel IO Uring Primitives/`

### Existing Infrastructure

The ecosystem provides typed infrastructure that io_uring SHOULD be using but doesn't:

**Ring Index Infrastructure** (the exact abstraction io_uring needs):

| Ecosystem Type | Package | Purpose | io_uring equivalent |
|----------------|---------|---------|---------------------|
| `Index<T>.Modular` | cyclic-index-primitives | Runtime-capacity modular index with wrapping successor/physical | SQ/CQ head/tail (UInt32 & mask) |
| `Index<T>.Cyclic<N>` | cyclic-index-primitives | Compile-time cyclic index with auto-wrap arithmetic | — (io_uring uses runtime capacity) |
| `Buffer.Ring.Header` | buffer-primitives | Ring header: `head: Index<E>`, `count: Index<E>.Count`, `capacity: Index<E>.Count` | Uring stored properties (9× raw UInt32) |
| `Index<T>.Count` | index-primitives | `Tagged<T, Cardinal>` — typed element count | setup entries, enter toSubmit/minComplete, pendingSubmissions |
| `Index<T>` | index-primitives | `Tagged<T, Ordinal>` — typed position | SQ/CQ head/tail positions |

**Memory Infrastructure** (already partially used):

| Ecosystem Type | Package | Purpose | io_uring status |
|----------------|---------|---------|-----------------|
| `Kernel.Memory.Address` | kernel-primitives | Typed address with `.mutablePointer` | ✓ Used for mmap regions |
| `Kernel.Memory.Map.Region` | kernel-primitives | `base: Address`, `length: File.Size`, `Span<UInt8>` access | ✗ Not used — stores raw addr+size pairs |
| `Kernel.File.Size` | kernel-primitives | Typed byte magnitude | ✓ Used for mmap sizes |
| `Memory.Address.Offset` | memory-primitives | Typed byte displacement | ✗ Not used — Offsets structs are raw UInt32 |

**Dimension Infrastructure** (partially adopted):

| Ecosystem Type | Package | Purpose | io_uring status |
|----------------|---------|---------|-----------------|
| `Coordinate.X<Space>.Value<T>` | dimension-primitives | Typed position | ✓ Used for Offset |
| `Magnitude<Space>.Value<T>` | dimension-primitives | Non-directional size | ✓ Used for Length |
| `Tagged<Tag, RawValue>` | dimension-primitives | Zero-cost phantom wrapper | ✓ Used for Operation.Data, Personality.ID |

**Cardinal/Ordinal Arithmetic** (not used at all):

| Operation | Infrastructure | io_uring does instead |
|-----------|---------------|----------------------|
| `.zero`, `.one` | `Cardinal.Protocol` | `0`, `1` literals |
| `count + .one` | `Cardinal.Protocol.+` | `_pendingCount &+= 1` |
| `position.successor` | `Ordinal.Protocol` | `head &+= 1` |
| `slot < capacity` | Typed comparison | `sqEntries &- (tail &- sqHead.pointee) > 0` |
| `Index.Modular.physical(forLogical:head:capacity:)` | cyclic-index-primitives | `Int(tail & sqMask)` |

**Key insight**: `Buffer.Ring.Header` is the EXACT domain model for io_uring's SQ/CQ ring state. The difference is that io_uring's rings are shared-memory (mmap'd kernel pointers) rather than process-owned heap storage. But the INDEX DISCIPLINE — head, tail, count, mask, wrapping — is identical.

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | CRITICAL | [IMPL-006] | Uring.swift:51-65 | **Ring stored properties are all raw UInt32.** `sqHead`, `sqTail`, `sqMask`, `sqEntries`, `sqArray` (SQ); `cqHead`, `cqTail`, `cqMask` (CQ); `_pendingCount` — 9 stored properties storing ring indices, masks, and counts as bare `UInt32`. These are the core of the data structure. Needs: `Ring.Index` (for head/tail), `Ring.Mask`, `Ring.Count` (for entries, pending). | OPEN |
| 2 | CRITICAL | [IMPL-002] | Uring.swift:158 | **`setup(entries: UInt32)` — public factory parameter is raw.** This is the primary entry point. Should be a typed count: `Submission.Queue.Count` or similar. | OPEN |
| 3 | CRITICAL | [IMPL-002] | Uring.swift:193-194 | **`enter(toSubmit: UInt32, minComplete: UInt32)` — both parameters are raw.** Core syscall bridge. `toSubmit` is a submission count, `minComplete` is a completion count. These are fundamentally different quantities mixed under the same `UInt32`. | OPEN |
| 4 | CRITICAL | [IMPL-002] | Uring.swift:236 | **`register(count: UInt32)` — parameter is raw.** Registration item count. | OPEN |
| 5 | CRITICAL | [IMPL-002] | Uring.swift:339 | **`pendingSubmissions` returns `UInt32`.** Public property on the ring struct. Should return typed count. | OPEN |
| 6 | CRITICAL | [IMPL-010] | Uring.swift:288-290 | **`Int(params.sqOff.array)`, `Int(params.sqEntries)` etc — 12 raw Int casts in init.** Size calculations for mmap regions chain through raw `Int`. These should use typed `Kernel.Memory.Address` / `Kernel.File.Size` arithmetic. | OPEN |
| 7 | CRITICAL | [IMPL-010] | Uring.swift:349-354 | **Ring index masking uses raw UInt32 arithmetic.** `Int(tail & sqMask)`, `UInt32(idx)`, wrapping add — pure mechanism at what should be the intent layer. Needs `Ring.Index` with masking built in. | OPEN |
| 8 | CRITICAL | [IMPL-006] | Params.swift:55-58 | **`Params.sqEntries: UInt32` and `Params.cqEntries: UInt32`.** Ring sizes are the first thing consumers read from params. Should be typed counts. | OPEN |
| 9 | HIGH | [IMPL-002] | Params.swift:67 | **`Params.features: UInt32`.** Kernel feature bitmask exposed as raw integer. Should be a typed `Features` OptionSet. | OPEN |
| 10 | HIGH | [IMPL-002] | Params.Submission.Thread.swift:19-22 | **`Thread.cpu: UInt32` and `Thread.idle: UInt32`.** CPU is a processor ID, idle is milliseconds. Two completely different domains collapsed to the same raw type. | OPEN |
| 11 | HIGH | [IMPL-006] | SQ.Offsets.swift:28-34 | **All 7 SQ Offsets fields are raw `UInt32`.** `head`, `tail`, `ringMask`, `ringEntries`, `flags`, `dropped`, `array` — byte offsets into the mmap'd SQ ring region. These are `Kernel.Memory.Address.Offset` or a dedicated `Ring.Offset` type. | OPEN |
| 12 | HIGH | [IMPL-006] | CQ.Offsets.swift:28-34 | **All 7 CQ Offsets fields are raw `UInt32`.** Same issue as SQ Offsets: `head`, `tail`, `ringMask`, `ringEntries`, `overflow`, `cqes`, `flags`. | OPEN |
| 13 | HIGH | [IMPL-002] | SQE.swift:71 | **`Entry.flags: UInt8` getter/setter.** SQE flags exposed as raw byte. Already has `Submission.Queue.Entry.Flags` type — this property should use it. | OPEN |
| 14 | HIGH | [IMPL-002] | SQE.swift:77 | **`Entry.opFlags: Int32` getter/setter.** Operation-specific flags as raw signed integer. Should be typed per-operation or use `Op.Flags`. | OPEN |
| 15 | HIGH | [IMPL-002] | SQE.swift:95 | **`Entry.addr: UInt64` getter/setter.** Buffer address as raw 64-bit value. Should use `Kernel.Memory.Address` or `UnsafeRawPointer` wrapper. | OPEN |
| 16 | HIGH | [IMPL-002] | CQE.swift:72 | **`Entry.res: Int32`.** Operation result code — the primary output of every io_uring operation. Should be `Kernel.IO.Uring.Result` or at minimum `Kernel.Error.Code`-aware. | OPEN |
| 17 | HIGH | [IMPL-002] | CQE.swift:79 | **`Entry.flags: UInt32`.** CQE flags as raw integer. Already has `Completion.Queue.Entry.Flags` type — this property should use it. | OPEN |
| 18 | HIGH | [IMPL-002] | Prepare.swift:155-228 | **SQE prepare methods take raw Int32/UInt32 for socket params.** `accept(addrLen: UInt32, flags: Int32)`, `connect(addrLen: UInt32)`, `send(flags: Int32)`, `recv(flags: Int32)` — 6 parameters across 4 methods. Should use `Socket.Flags`, `Socket.Address.Length`. | OPEN |
| 19 | HIGH | [IMPL-006] | Mmap.Offset.swift:41-51 | **Mmap offset constants are raw `Int64`.** `.sqRing = 0`, `.cqRing = 0x8000000`, `.sqes = 0x1000_0000` — magic mmap offsets. Should use `Kernel.File.Offset` or `Kernel.Memory.Address.Offset`. | OPEN |
| 20 | MEDIUM | [IMPL-002] | CQE.Entry.Buffer.swift:30-32 | **Buffer ID extracted as raw `UInt16` via bitwise shift on `UInt32` flags.** Should return typed `Buffer.Index` or `Buffer.ID`. | OPEN |
| 21 | MEDIUM | [IMPL-002] | SQE.Entry.Op.swift:37-44 | **`Op` init takes `flags: Int32`.** Raw signed integer for operation-specific flags. | OPEN |
| 22 | MEDIUM | [IMPL-INTENT] | Uring.swift:393-401 | **CQ drain loop is pure mechanism.** `var head = cqHead.pointee; while head != tail { cqes[Int(head & cqMask)]; head &+= 1 }` — index masking, wrapping add, raw pointer indexing. Should read as intent: `ring.completions.drain(limit:visitor:)`. | OPEN |
| 23 | MEDIUM | [IMPL-INTENT] | Uring.swift:348-354 | **SQ entry acquisition is pure mechanism.** `sqEntries &- (tail &- sqHead.pointee) > 0`, `sqArray[idx] = UInt32(idx)` — ring fullness check and index assignment should be encapsulated. | OPEN |
| 24 | LOW | [IMPL-006] | Priority.swift:32 | **`Priority.rawValue: UInt16`** with public init. Already a `RawRepresentable` struct but uses raw backing. Could use `Tagged<Kernel.IO.Uring.Priority, UInt16>`. | OPEN |
| 25 | LOW | [IMPL-006] | Buffer.Group.swift:33 | **`Buffer.Group.rawValue: UInt16`** — same pattern as Priority. Hand-rolled RawRepresentable instead of `Tagged`. | OPEN |
| 26 | LOW | [IMPL-006] | Buffer.Index.swift:27 | **`Buffer.Index.rawValue: UInt16`** — same pattern. | OPEN |

### Systemic Patterns

**Pattern A: The Ring has no domain model.** The core ring abstraction — head, tail, mask, entries, pending count — is entirely raw `UInt32`. This is the highest-impact deficiency. A proper ring index type with masking built into its arithmetic would eliminate findings #1, #5, #6, #7, #22, #23 as corollaries.

**Proposed domain types for the Ring:**

```
Kernel.IO.Uring.Ring.Index      — UInt32-backed, wrapping arithmetic, mask-aware
Kernel.IO.Uring.Ring.Mask       — power-of-2 mask, used by Index for wrapping
Kernel.IO.Uring.Submission.Count — UInt32-backed cardinal for SQ quantities
Kernel.IO.Uring.Completion.Count — UInt32-backed cardinal for CQ quantities
```

**Pattern B: Offsets structs are byte-offset bags.** Both `Submission.Queue.Offsets` and `Completion.Queue.Offsets` are 7-field structs of raw `UInt32` representing byte offsets into mmap'd regions. These should use a typed `Ring.Byte.Offset` so the `init(descriptor:params:)` factory can do typed pointer arithmetic instead of 12 raw `Int()` casts.

**Pattern C: SQE/CQE properties re-expose raw C fields.** The `Entry` types have typed flag/data types (`Entry.Flags`, `Completion.Queue.Entry.Flags`, `Operation.Data`) but the entry properties return raw integers instead of these types. The typed types exist but aren't used at the accessor layer.

**Pattern D: Public API parameters use raw integers for counts.** `setup(entries:)`, `enter(toSubmit:minComplete:)`, `register(count:)`, and `pendingSubmissions` all traffic in `UInt32`. These are the public-facing ring operations — the API consumers actually call. Fixing these is the highest-visibility improvement.

**Pattern E: Socket/network parameters are raw.** The `prepare` methods for accept, connect, send, recv pass through raw `Int32` for socket flags and `UInt32` for address lengths. These should use types from a socket primitives layer or at minimum local typed wrappers.

### Recommended Type Catalog

**Adopt from ecosystem** (no new types needed — just import and use):

| Ecosystem Type | Replaces | Usage | Impact |
|----------------|----------|-------|--------|
| `Index<Submission.Queue.Entry>.Count` | `UInt32` in setup, enter, pendingSubmissions | SQ entry count | 5 public API sites |
| `Index<Completion.Queue.Entry>.Count` | `UInt32` in enter(minComplete:) | CQ entry count | 1 public API site |
| `Index<Submission.Queue.Entry>` | `UInt32` head/tail stored properties | SQ ring position | 4 stored properties |
| `Index<Completion.Queue.Entry>` | `UInt32` head/tail stored properties | CQ ring position | 4 stored properties |
| `Index.Modular.physical(forLogical:head:capacity:)` | `Int(tail & sqMask)` raw masking | Ring index wrapping | 2 internal sites |
| `Kernel.Memory.Map.Region` | `(sqRingAddr, sqRingSize)` pairs | mmap'd region ownership | 3 stored property pairs → 3 Region values |
| `Memory.Address.Offset` | `UInt32` in Offsets structs | Byte offset into mmap'd region | 14 fields (both Offsets structs) |

**Adopt from system-primitives** (ordinal complement to existing Count):

| Ecosystem Type | Package | Replaces | Notes |
|----------------|---------|----------|-------|
| `System.Processor.ID` (proposed) | system-primitives | `UInt32` cpu in Thread | `Tagged<System.Processor, Ordinal>` — ordinal complement to existing `System.Processor.Count = Tagged<System.Processor, Cardinal>`. Identifies WHICH processor, not HOW MANY. |

**New types to introduce** (io_uring-specific):

| Type | Backing | Replaces | Usage |
|------|---------|----------|-------|
| `Params.Features` | OptionSet struct, `UInt32` | `UInt32` in Params.features | Kernel feature flags |

**Existing types to connect** (types exist in io_uring but aren't used by entry accessors):

| Existing Type | Currently Returns | Should Return |
|---------------|-------------------|---------------|
| `Submission.Queue.Entry.Flags` | `UInt8` via `.flags` | `Entry.Flags` |
| `Completion.Queue.Entry.Flags` | `UInt32` via `.flags` | `Entry.Flags` |
| `Operation.Data` | `UInt64` via `.addr` | `Operation.Data` or `Kernel.Memory.Address` |

**Architecture note**: The ring index infrastructure (`Index.Modular`, `Index.Cyclic`) is the linchpin. Adopting it eliminates findings #1, #5, #6, #7, #22, #23 as corollaries — the wrapping arithmetic, masking, fullness checks all become method calls on typed indices instead of raw UInt32 bit manipulation.

### Summary

26 findings: 7 critical, 12 high, 4 medium, 3 low.
**Post-refactor (2026-04-09)**: 15 RESOLVED, 11 remain (mostly internal ring properties — deferred as kernel ABI boundary).

The io_uring target has strong namespace structure (`Kernel.IO.Uring.Submission.Queue.Entry.Prepare`) and already uses ecosystem types for some dimensions (`Offset`, `Length`, `Operation.Data`). But the core ring management, public API parameters, and entry accessor properties are entirely raw integers. The domain model is incomplete: typed wrappers exist but aren't connected to the API surface.

The systemic fix is a ring index type with mask-aware arithmetic, typed counts for submission/completion quantities, and entry accessors that return their companion typed types instead of raw integers. This is a breaking-change refactor with ~20 files affected.

---

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/audit-primitives.md (2026-04-03)

**Pre-publication dependency-tree audit — P0/P1/P2 checks**

#### P2: Methods in Type Body [API-IMPL-008]

All in `Sources/Linux Kernel Primitives/`:

| File | Items in body |
|------|---------------|
| `Linux.Kernel.IO.Uring.Submission.Queue.Entry.Prepare.swift` | 12 |
| `Linux.Kernel.IO.Uring.Submission.Queue.Entry.swift` | 10 |
| `Linux.Kernel.IO.Uring.swift` | 7 |
| `Linux.Kernel.IO.Uring.Completion.Queue.Entry.swift` | 7 |

**Assessment**: Platform packages consistently define methods inside struct/enum bodies rather than using extensions. This appears to be a systematic pattern in the platform layer, possibly because these are thin syscall wrappers where the extension pattern adds overhead without benefit.

**Recommendation**: Consider as a batch cleanup across all platform packages, but lower priority since these are platform-specific code.

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-linux-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=1, MEDIUM=3, LOW=20, INFO=34
Finding IDs: IMPL-010, LNX-001, LNX-002, LNX-003, LNX-004, LNX-005, LNX-006, LNX-007, LNX-008, LNX-009, LNX-010, LNX-011, LNX-012, LNX-013, LNX-014 (+28 more)
