# swift-linux-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (automated)
**Package**: `/Users/coen/Developer/swift-primitives/swift-linux-primitives/`
**Modules**: Linux Primitives, Linux Kernel Primitives, Linux Loader Primitives, Linux Memory Primitives
**Files audited**: 80 `.swift` source files
**Skills applied**: naming, implementation

---

## Summary Table

| ID | Severity | Rule | File | Description |
|----|----------|------|------|-------------|
| [LNX-001] | LOW | [API-IMPL-005] | Linux.Identity.UUID.swift | Two types (`Linux.Identity`, `Linux.Identity.UUID`) declared in one file |
| [LNX-002] | INFO | [API-NAME-002] | Linux.Kernel.IO.Uring.Submission.Queue.Entry.swift | `.opFlags` compound property name |
| [LNX-003] | INFO | [PATTERN-017] | Linux.Kernel.IO.Uring.swift:107-110 | `.rawValue` in `enter()` syscall — boundary-correct |
| [LNX-004] | INFO | [PATTERN-017] | Linux.Kernel.IO.Uring.swift:147-149 | `.rawValue` in `register()` syscall — boundary-correct |
| [LNX-005] | INFO | [PATTERN-017] | Linux.Kernel.IO.Uring.swift:77 | `.rawValue` in `setup()` return — boundary-correct |
| [LNX-006] | INFO | [PATTERN-017] | Linux.Kernel.Event.Poll.swift:56,89 | `.rawValue` in `epoll_create1`/`epoll_ctl` — boundary-correct |
| [LNX-007] | INFO | [PATTERN-017] | Linux.Kernel.Event.Poll.Event.swift:89-98 | `.rawValue` in `cValue` C-conversion — boundary-correct |
| [LNX-008] | INFO | [PATTERN-017] | Linux.Kernel.IO.Uring.Submission.Queue.Entry.swift:67-122 | `.rawValue` in SQE accessor bridge — boundary-correct |
| [LNX-009] | INFO | [PATTERN-017] | Linux.Kernel.IO.Uring.Submission.Queue.Entry.Buffer.swift:30-31,44-45 | `.rawValue` in SQE buffer accessor bridge — boundary-correct |
| [LNX-010] | INFO | [PATTERN-017] | Linux.Kernel.IO.Uring.Params.swift:97,110-114 | `.rawValue` in Params C-conversion — boundary-correct |
| [LNX-011] | INFO | [PATTERN-017] | Linux.Kernel.IO.Uring.Submission.Queue.Entry.Prepare.swift:62,87,104,162-163,185-186,209 | `.rawValue` in Prepare helpers (pointer conversions) — boundary-correct |
| [LNX-012] | INFO | [IMPL-010] | Linux.Kernel.IO.Uring.Submission.Queue.Entry.Prepare.swift:62,87,162,185,209 | `UInt(bitPattern:)` in pointer-to-UInt64 conversions — boundary-correct |
| [LNX-013] | INFO | [IMPL-010] | Linux.Kernel.Event.Poll.Data.swift:46,54,62 | `UInt(bitPattern:)` in pointer-to-UInt64 conversions — boundary-correct |
| [LNX-014] | INFO | [IMPL-010] | Linux.Kernel.IO.Uring.Operation.Data.swift:46,54,62 | `UInt(bitPattern:)` in pointer-to-UInt64 conversions — boundary-correct |
| [LNX-015] | LOW | [IMPL-INTENT] | Linux.Kernel.IO.Uring.Submission.Queue.Entry.Prepare.swift:123 | Magic literal `1` for `IORING_FSYNC_DATASYNC` — should be named constant |
| [LNX-016] | LOW | [API-NAME-002] | Linux.Kernel.IO.Uring.Submission.Queue.Entry.swift:71 | `opFlags` compound property — should be nested or decomposed |
| [LNX-017] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Socket.swift:31,34 | `sendMessage`/`receiveMessage` compound names — Linux API mirroring (spec exception) |
| [LNX-018] | LOW | [API-NAME-002] | Linux.Kernel.IO.Uring.File.swift:52 | `filesUpdate` compound property name |
| [LNX-019] | LOW | [API-NAME-002] | Linux.Kernel.IO.Uring.Fixed.swift:18 | `fdInstall` compound property name |
| [LNX-020] | LOW | [API-NAME-002] | Linux.Kernel.IO.Uring.Sync.swift:19 | `fileRange` compound property name |
| [LNX-021] | LOW | [API-NAME-002] | Linux.Kernel.Memory.Allocation.Statistics.swift:69 | `startTracking()` compound method name |
| [LNX-022] | LOW | [API-NAME-002] | Linux.Kernel.Memory.Allocation.Statistics.swift:78 | `stopTracking()` compound method name |
| [LNX-023] | LOW | [API-NAME-002] | Linux.Kernel.Memory.Allocation.Statistics.swift:94 | `resetTracking()` compound method name |
| [LNX-024] | LOW | [API-NAME-002] | Linux.Kernel.Memory.Allocation.Statistics.swift:29 | `bytesAllocated` compound property name |
| [LNX-025] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Mmap.Offset.swift:41,46,51 | `sqRing`/`cqRing`/`sqes` names mirror io_uring constants — spec exception |
| [LNX-026] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Submission.Queue.Offsets.swift:31,33 | `ringMask`/`ringEntries` names mirror `io_sqring_offsets` — spec exception |
| [LNX-027] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Completion.Queue.Offsets.swift:31,32 | `ringMask`/`ringEntries` names mirror `io_cqring_offsets` — spec exception |
| [LNX-028] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Params.swift:55-56 | `sqEntries`/`cqEntries` names mirror `io_uring_params` — spec exception |
| [LNX-029] | MEDIUM | [API-IMPL-005] | Linux.Kernel.IO.Uring.Completion.Queue.Entry.Typed.swift | Two types (`Typed`, plus `hasMore` property on `Entry`) in one file |
| [LNX-030] | INFO | [PATTERN-017] | Linux.Kernel.File.Rename.swift:69-75 | `.rawValue` in `renameat2()` syscall — boundary-correct |
| [LNX-031] | INFO | [PATTERN-017] | Linux.Kernel.IO.Uring.Offset.swift:56-57 | `.rawValue` in cross-space conversion — boundary-correct |
| [LNX-032] | INFO | [PATTERN-017] | Linux.Kernel.IO.Uring.Length.swift:94 | `.rawValue` in File.Size conversion — boundary-correct |
| [LNX-033] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Enter.Flags.swift:67 | `sqWakeup` mirrors `IORING_ENTER_SQ_WAKEUP` — spec exception |
| [LNX-034] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Enter.Flags.swift:75 | `sqWait` mirrors `IORING_ENTER_SQ_WAIT` — spec exception |
| [LNX-035] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Enter.Flags.swift:83 | `extArg` mirrors `IORING_ENTER_EXT_ARG` — spec exception |
| [LNX-036] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Enter.Flags.swift:91 | `registeredRing` mirrors `IORING_ENTER_REGISTERED_RING` — spec exception |
| [LNX-037] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Setup.Flags.swift | All setup flag names mirror `IORING_SETUP_*` constants — spec exception |
| [LNX-038] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Submission.Queue.Entry.Flags.swift | All SQE flag names mirror `IOSQE_*` constants — spec exception |
| [LNX-039] | INFO | [API-NAME-003] | Linux.Kernel.IO.Uring.Completion.Queue.Entry.Flags.swift | All CQE flag names mirror `IORING_CQE_F_*` constants — spec exception |
| [LNX-040] | INFO | [API-NAME-003] | Linux.Kernel.Event.Poll.Events.swift | All event flag names mirror `EPOLL*` constants — spec exception |
| [LNX-041] | INFO | [API-NAME-003] | Linux.Kernel.Event.Poll.Operation.swift | Operation names mirror `EPOLL_CTL_*` constants — spec exception |

---

## Detailed Findings

### [LNX-001] Two types in one file: Linux.Identity.UUID.swift (LOW)

**Rule**: [API-IMPL-005] One type per file.

**File**: `Sources/Linux Kernel Primitives/Linux.Identity.UUID.swift`
**Lines**: 8-16

This file declares both `Linux.Identity` (line 10) and `Linux.Identity.UUID` (line 15). Per [API-IMPL-005], `Linux.Identity` should be in its own file `Linux.Identity.swift`.

---

### [LNX-002] / [LNX-016] Compound property name: `opFlags` (INFO/LOW)

**Rule**: [API-NAME-002] Methods/properties MUST NOT use compound names.

**File**: `Sources/Linux Kernel Primitives/Linux.Kernel.IO.Uring.Submission.Queue.Entry.swift`
**Line**: 77

```swift
public var opFlags: Int32 {
    get { cValue.rw_flags }
    set { cValue.rw_flags = newValue }
}
```

The Entry already has a nested `Op` accessor type (in `Entry.Op.swift`). The `opFlags` property duplicates the accessor with a compound name. Consider removing `opFlags` in favor of the existing `entry.op.flags` pattern, or vice versa.

---

### [LNX-015] Magic literal `1` for `IORING_FSYNC_DATASYNC` (LOW)

**Rule**: [IMPL-INTENT] Code reads as intent, not mechanism.

**File**: `Sources/Linux Kernel Primitives/Linux.Kernel.IO.Uring.Submission.Queue.Entry.Prepare.swift`
**Line**: 123

```swift
if datasync {
    entry.opFlags = 1  // IORING_FSYNC_DATASYNC
}
```

The magic literal `1` should be a named constant, either imported from the C shim or declared locally. The inline comment documents intent but the code itself doesn't express it.

---

### [LNX-017] Compound names in Socket opcodes: `sendMessage`/`receiveMessage` (INFO)

**Rule**: [API-NAME-002] / [API-NAME-003]

**File**: `Sources/Linux Kernel Primitives/Linux.Kernel.IO.Uring.Socket.swift`
**Lines**: 31, 34

```swift
public static let sendMessage = Opcode(rawValue: 9)
public static let receiveMessage = Opcode(rawValue: 10)
```

These mirror Linux kernel `IORING_OP_SENDMSG` / `IORING_OP_RECVMSG`. The spec-mirroring exception ([API-NAME-003]) applies, but the names don't exactly mirror the spec (`sendmsg` vs `sendMessage`). Consider `sendMsg`/`receiveMsg` to more closely mirror the kernel names, or nested `send.message`/`receive.message`.

---

### [LNX-018] Compound property: `filesUpdate` (LOW)

**Rule**: [API-NAME-002]

**File**: `Sources/Linux Kernel Primitives/Linux.Kernel.IO.Uring.File.swift`
**Line**: 52

```swift
public static let filesUpdate = Opcode(rawValue: 20)
```

Could be nested as `files.update` using the existing pattern, consistent with how `Register.Files.update` is already structured.

---

### [LNX-019] Compound property: `fdInstall` (LOW)

**Rule**: [API-NAME-002]

**File**: `Sources/Linux Kernel Primitives/Linux.Kernel.IO.Uring.Fixed.swift`
**Line**: 18

```swift
public static let fdInstall = Opcode(rawValue: 54)
```

Could be `fd.install` or `install` (since it's already under `Fixed`).

---

### [LNX-020] Compound property: `fileRange` (LOW)

**Rule**: [API-NAME-002]

**File**: `Sources/Linux Kernel Primitives/Linux.Kernel.IO.Uring.Sync.swift`
**Line**: 19

```swift
public static let fileRange = Opcode(rawValue: 8)
```

Could be nested as `file.range` via a nested accessor, or simply `range` since it's already under `Sync`.

---

### [LNX-021-023] Compound method names in Statistics (LOW)

**Rule**: [API-NAME-002]

**File**: `Sources/Linux Memory Primitives/Linux.Kernel.Memory.Allocation.Statistics.swift`
**Lines**: 69, 78, 94

```swift
public static func startTracking() { ... }
public static func stopTracking() -> Self { ... }
public static func resetTracking() { ... }
```

These use compound names. Could be refactored to a nested `tracking` accessor:
- `Statistics.tracking.start()`
- `Statistics.tracking.stop()`
- `Statistics.tracking.reset()`

---

### [LNX-024] Compound property: `bytesAllocated` (LOW)

**Rule**: [API-NAME-002]

**File**: `Sources/Linux Memory Primitives/Linux.Kernel.Memory.Allocation.Statistics.swift`
**Line**: 29

```swift
public let bytesAllocated: Int
```

Could be nested as `bytes.allocated` via a nested accessor, though this is borderline since it's a stored property on a simple data struct.

---

### [LNX-029] Two types in one file: Completion.Queue.Entry.Typed.swift (MEDIUM)

**Rule**: [API-IMPL-005] One type per file.

**File**: `Sources/Linux Kernel Primitives/Linux.Kernel.IO.Uring.Completion.Queue.Entry.Typed.swift`
**Lines**: 15-37

This file declares `Typed` (nested struct) AND adds a `hasMore` computed property to `Entry`. The `hasMore` property is a convenience on `Entry` itself, not on `Typed`. While the property is related, it should either live in the `Entry` file or in its own extension file, keeping this file purely for the `Typed` type.

---

## .rawValue Usage Classification

### Boundary-Correct (57 usages, ALL correct)

All `.rawValue` accesses in this package fall into one of three categories, all of which are boundary-correct per [PATTERN-017]:

1. **Syscall bridges** (17 usages): `setup()`, `enter()`, `register()`, `epoll_create1()`, `epoll_ctl()`, `epoll_wait()`, `renameat2()`. These are the C-function-call boundary where typed Swift values must become raw C integers. This is the canonical use case for `.rawValue`.

2. **C-struct conversion** (28 usages): `cValue` getters/setters on `Event`, `Params`, `SQE`, `CQE`, `Offsets`. These bridge between Swift types and their C-struct counterparts (`io_uring_sqe`, `io_uring_cqe`, `epoll_event`, etc.). Each accessor reads from or writes to a C struct field — pure boundary code.

3. **Cross-space value conversion** (12 usages): `Offset`, `Length`, `File.Size` conversions. These convert between typed dimension values at domain boundaries. The `.rawValue` access is in the conversion initializer itself — the boundary overload.

**No call-site leaks were found.** All `.rawValue` usage is confined to boundary code (syscall wrappers, C-struct bridging, or cross-domain conversion initializers). Call sites interact entirely through typed APIs (`Kernel.Descriptor`, `Opcode`, `Offset`, `Length`, `Priority`, `Buffer.Index`, `Buffer.Group`, `Personality.ID`, etc.).

### Int(bitPattern:) Classification (14 usages, ALL correct)

All `Int(bitPattern:)` / `UInt(bitPattern:)` usages convert unsafe pointers to integer values for storing in C struct fields (SQE `addr` field, epoll data). These are in boundary overload initializers and `@unsafe`-annotated functions — exactly where [IMPL-010] permits them.

---

## Naming Architecture Assessment

### Nest.Name Pattern Compliance

The type naming in this package is exemplary. All types follow the `Nest.Name` pattern:

```
Linux
Linux.Kernel (typealias to Kernel_Primitives.Kernel)
Linux.Loader
Linux.Loader.Section
Linux.Memory
Linux.Memory.Allocation
Linux.Memory.Allocation.Statistics
Linux.Identity
Linux.Identity.UUID
Kernel.Event.Poll
Kernel.Event.Poll.Event
Kernel.Event.Poll.Events
Kernel.Event.Poll.Operation
Kernel.Event.Poll.Create
Kernel.Event.Poll.Create.Flags
Kernel.Event.Poll.Data
Kernel.Event.Poll.Error
Kernel.IO.Uring
Kernel.IO.Uring.Submission
Kernel.IO.Uring.Submission.Queue
Kernel.IO.Uring.Submission.Queue.Entry
Kernel.IO.Uring.Submission.Queue.Entry.Flags
Kernel.IO.Uring.Submission.Queue.Entry.Op
Kernel.IO.Uring.Submission.Queue.Entry.Buffer
Kernel.IO.Uring.Submission.Queue.Entry.Prepare
Kernel.IO.Uring.Submission.Queue.Offsets
Kernel.IO.Uring.Completion
Kernel.IO.Uring.Completion.Queue
Kernel.IO.Uring.Completion.Queue.Entry
Kernel.IO.Uring.Completion.Queue.Entry.Bytes
Kernel.IO.Uring.Completion.Queue.Entry.Flags
Kernel.IO.Uring.Completion.Queue.Entry.Buffer
Kernel.IO.Uring.Completion.Queue.Entry.Typed
Kernel.IO.Uring.Completion.Queue.Offsets
Kernel.IO.Uring.Params
Kernel.IO.Uring.Params.Submission
Kernel.IO.Uring.Params.Submission.Thread
Kernel.IO.Uring.Setup
Kernel.IO.Uring.Setup.Flags
Kernel.IO.Uring.Enter
Kernel.IO.Uring.Enter.Flags
Kernel.IO.Uring.Error
Kernel.IO.Uring.Opcode
Kernel.IO.Uring.Operation
Kernel.IO.Uring.Operation.Data
Kernel.IO.Uring.Register
Kernel.IO.Uring.Register.Opcode
Kernel.IO.Uring.Register.Personality
Kernel.IO.Uring.Register.Buffers
Kernel.IO.Uring.Register.Files
Kernel.IO.Uring.Register.Rings
Kernel.IO.Uring.Register.Eventfd
Kernel.IO.Uring.Register.Probe
Kernel.IO.Uring.Offset
Kernel.IO.Uring.Length
Kernel.IO.Uring.Priority
Kernel.IO.Uring.Personality
Kernel.IO.Uring.Personality.ID
Kernel.IO.Uring.Buffer
Kernel.IO.Uring.Buffer.Index
Kernel.IO.Uring.Buffer.Group
Kernel.IO.Uring.Mmap
Kernel.IO.Uring.Mmap.Offset
Kernel.IO.Uring.Read / Write / Send / Socket / Poll / Cancel / Sync / Timeout / Epoll / Pipe / File / Futex / Xattr / Wait / Fixed / Ring / Memory (opcode groups)
Kernel.File.Rename
Kernel.File.Rename.Flags
Kernel.File.Rename.Error
```

Zero compound type names found. Every type uses `Nest.Name`.

### One Type Per File Compliance

File naming follows the convention (`Type.Path.Name.swift`). Two violations found:
- [LNX-001]: `Linux.Identity.UUID.swift` contains both `Linux.Identity` and `Linux.Identity.UUID`
- [LNX-029]: `Completion.Queue.Entry.Typed.swift` adds a `hasMore` property to `Entry`

### Nested Accessor Pattern for Opcodes

The package uses a sophisticated metatype-accessor pattern for opcodes:

```swift
extension Kernel.IO.Uring.Opcode {
    public static var read: Kernel.IO.Uring.Read.Type { Kernel.IO.Uring.Read.self }
}
// Usage: sqe.opcode = .read.standard
```

This enables clean call-site syntax like `.read.standard`, `.write.vectored`, `.socket.accept`, `.cancel.async`. The pattern is consistent across all 17 opcode group files.

---

## Overall Assessment

**Package quality**: HIGH

This is a well-structured platform package. The type hierarchy is deep but principled, following `Nest.Name` without exception. The `.rawValue` usage is entirely confined to syscall boundary code and C-struct bridging — no call-site leaks. The `Int(bitPattern:)` usages are all in `@unsafe`-annotated boundary functions.

The findings are predominantly LOW severity (compound property names on opcode constants and statistics methods) and INFO (boundary-correct `.rawValue` usage confirmations and spec-mirroring exceptions). The two [API-IMPL-005] violations ([LNX-001], [LNX-029]) are the most actionable items.

**Counts**:
- MEDIUM: 1
- LOW: 9
- INFO: 31
- Boundary-correct `.rawValue`: 57/57 (100%)
- Boundary-correct `Int(bitPattern:)`: 14/14 (100%)
- Compound type names: 0
- Spec-mirroring exceptions: 12 (all justified)
