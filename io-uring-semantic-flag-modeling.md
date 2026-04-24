# IO Uring Semantic Flag Modeling

<!--
---
version: 2.0.0
last_updated: 2026-04-10
status: DECISION
changelog:
  - v2.0.0 (2026-04-10): IMPLEMENTED. All 4 decompositions done (timeout→Clock enum, poll→Trigger enum, fallocate→Mode enum, xattr→Disposition enum). 12 types moved to correct owners. 6 duplicates deleted. .Options convention adopted ecosystem-wide. Remaining: Wait.Options move to iso-9945.
tier: 2
applies_to: [swift-linux-primitives, swift-kernel-primitives]
inputs:
  - io-uring-l1-api-audit-and-recommendations.md
  - linux-io-uring-api-reference.md
skills_consulted:
  - platform [PLAT-ARCH-005a]
  - code-surface [API-NAME-001, API-ERR-001]
  - implementation [IMPL-COMPILE, IMPL-001]
  - ecosystem-data-structures [DS-*]
  - existing-infrastructure [INFRA-*]
---
-->

## Context

The io_uring Prepare API currently has 29 flag parameters across 63+ prep methods. All
are typed as OptionSets. However, many of these "flags" encode mutually exclusive choices
that OptionSet cannot enforce at compile time, and many duplicate types that already
exist elsewhere in the ecosystem.

This research performs full semantic domain modeling: for each io_uring operation's
parameters, determine (1) which types already exist in the ecosystem and should be
reused, (2) which flag sets encode exclusive choices that should be enums, and (3) which
are genuinely combinable flags that correctly remain OptionSets.

**Governing principles:**
- [IMPL-COMPILE]: Express invariants in the type system where possible
- [IMPL-001]: If OptionSet allows an invalid combination, the absence of that invalid
  state is principled — model it as an enum
- [PLAT-ARCH-005a]: io_uring does not own POSIX/Linux types — reference them

## Question

For each io_uring operation parameter: what is the correct type, where should it live,
and does it require semantic decomposition beyond OptionSet?

---

## Part I: Ecosystem Type Reuse (Duplicates to Eliminate)

These types already exist in the ecosystem. The io_uring Prepare methods should
**reference** them, not re-define them.

### 1.1 Direct replacements

| Current io_uring type | Ecosystem type | Location | Action |
|----------------------|----------------|----------|--------|
| `Kernel.IO.Uring.File.Open.Options` | `Kernel.File.Open.Options` | swift-kernel-primitives | **Delete** io_uring type; use ecosystem type |
| `Kernel.IO.Uring.File.Rename.Options` | `Kernel.File.Rename.Options` | swift-linux-primitives (Linux Kernel Primitives) | **Delete** io_uring type; use existing |
| `Kernel.IO.Uring.Pipe.Options` (for pipe create) | `Kernel.Pipe.Options` | swift-linux-primitives (Linux Kernel Primitives) | **Delete** io_uring type; use existing |
| accept `flags:` parameter | `Kernel.Socket.Options` | swift-kernel-primitives | Already using ✓ |

### 1.2 Types to reference once created in correct owner

These types don't yet exist at the ecosystem level but should NOT live in io_uring.
They are general Linux/POSIX concepts used by standalone syscalls. The io_uring prep
methods should accept them as parameters once they exist.

| Concept | Correct owner | Current io_uring duplicate | Used by non-io_uring syscalls? |
|---------|--------------|---------------------------|-------------------------------|
| Socket message flags (`MSG_*`) | `Kernel.Socket.Message.Options` in kernel-primitives | `Kernel.IO.Uring.Socket.Message.Options` | Yes — send(2), recv(2), sendmsg(2), recvmsg(2) |
| Path resolution flags (`AT_*`) | `Kernel.File.At.Options` in kernel-primitives or iso-9945 | `Kernel.IO.Uring.File.At.Options` | Yes — openat(2), fstatat(2), linkat(2), unlinkat(2) |
| Splice flags (`SPLICE_F_*`) | `Kernel.Pipe.Splice.Options` in linux-primitives | `Kernel.IO.Uring.Splice.Options` | Yes — splice(2), tee(2) |
| sync_file_range flags | `Kernel.File.Sync.Range.Options` in linux-primitives | `Kernel.IO.Uring.Sync.Options` | Yes — sync_file_range(2) |
| Futex flags (`FUTEX_*`) | `Kernel.Futex.Options` in linux-primitives | `Kernel.IO.Uring.Futex.Options` | Yes — futex(2) |
| Extended attr flags (`XATTR_*`) | `Kernel.File.Xattr.Options` in kernel-primitives or iso-9945 | `Kernel.IO.Uring.Xattr.Options` | Yes — setxattr(2), getxattr(2) |
| Fallocate modes (`FALLOC_FL_*`) | `Kernel.File.Allocate.Mode` in linux-primitives | `Kernel.IO.Uring.File.Allocate.Mode` | Yes — fallocate(2) |
| waitid flags | `Kernel.Process.Wait.Options` in iso-9945 | `Kernel.IO.Uring.Wait.Options` | Yes — waitid(2) |

**Phasing**: These can be created in their correct owners and io_uring updated to
reference them. This can be done incrementally — the io_uring duplicates work in the
meantime. Each migration is a single-type move with grep-and-replace at call sites.

---

## Part II: Semantic Decomposition (OptionSet → Richer Types)

These flag sets encode semantic structure that OptionSet cannot express. The fix is
decomposition into enums, separate parameters, or method overloads.

### 2.1 Timeout: Clock + Interpretation + Options

**Current**: `flags: Kernel.IO.Uring.Timeout.Options` — combines clock choice, relative/absolute,
and behavioral options in one OptionSet.

**Problem**: `[.boottime, .realtime]` compiles but is undefined behavior. `.absolute` is
meaningless without knowing the clock. `.update` and `.linkUpdate` are different operations.

**Semantic model**:

```
Timeout has three independent axes:
1. Clock source:  monotonic (default) | boottime | realtime     → enum
2. Interpretation: relative (default) | absolute                → overload
3. Options:       multishot, etimeSuccess                       → booleans or small OptionSet
```

**Proposed API**:

```swift
extension Kernel.IO.Uring {
    /// Clock source for timeout operations.
    enum Clock: Sendable {
        case monotonic   // default — CLOCK_MONOTONIC
        case boottime    // IORING_TIMEOUT_BOOTTIME — includes suspend time
        case realtime    // IORING_TIMEOUT_REALTIME — wall clock
    }
}
```

Prep methods — two overloads (relative vs absolute):

```swift
// Relative timeout (after duration)
prepare.timeout(
    after: Kernel.Time.Deadline,       // or timespec — relative duration
    clock: Kernel.IO.Uring.Clock,      // .monotonic (default)
    multishot: Bool,                    // false (default)
    data: Operation.Data
)

// Absolute timeout (at deadline)
prepare.timeout(
    deadline: Kernel.Time.Deadline,     // absolute instant
    clock: Kernel.IO.Uring.Clock,      // .monotonic (default)
    multishot: Bool,
    data: Operation.Data
)
```

Timeout remove and link timeout get their own methods (they are different operations,
not flag variants of the same operation):

```swift
prepare.timeout.remove(target:, data:)
prepare.timeout.update(target:, newDeadline:, clock:, data:)
prepare.timeout.link(after:, clock:, data:)
prepare.timeout.link(deadline:, clock:, data:)
```

**Internal mapping**: The prep method computes the flags bitfield:
```swift
var rawFlags: UInt32 = 0
if isAbsolute { rawFlags |= IORING_TIMEOUT_ABS }
switch clock {
case .monotonic: break
case .boottime: rawFlags |= IORING_TIMEOUT_BOOTTIME
case .realtime: rawFlags |= IORING_TIMEOUT_REALTIME
}
if multishot { rawFlags |= IORING_TIMEOUT_MULTISHOT }
```

The OptionSet `Timeout.Options` is deleted. The bitfield computation is internal to the
prep method.

---

### 2.2 Open: Access Mode + Options

**Current**: `flags: Kernel.IO.Uring.File.Open.Options` — mixes access mode (exclusive) with
open options (combinable).

**Problem**: `[.readOnly, .writeOnly, .readWrite]` compiles. Also, this duplicates
`Kernel.File.Open.Options` which already exists.

**Semantic model**:

```
Open has two independent axes:
1. Access mode: readOnly | writeOnly | readWrite              → enum
2. Options:     create, exclusive, truncate, append, ...      → OptionSet
                (these ARE genuinely combinable)
3. Descriptor:  closeOnExec, nonBlock, direct, sync, dataSync → OptionSet
                (these are descriptor behavior, not file behavior)
```

**Proposed API**:

```swift
extension Kernel.File.Open {
    /// How the file will be accessed.
    enum Access: Sendable {
        case readOnly
        case writeOnly
        case readWrite
    }
}
```

`Kernel.File.Open.Options` already exists as an OptionSet — it should contain the
combinable flags (create, exclusive, truncate, append, etc.).

Prep method:

```swift
prepare.openat(
    target: Target,
    path: UnsafePointer<CChar>,
    access: Kernel.File.Open.Access,
    options: Kernel.File.Open.Options,     // [.create, .truncate, .closeOnExec]
    mode: Kernel.File.Permissions,         // already exists
    data: Operation.Data
)
```

The io_uring-specific `File.Open.Options` type is **deleted**. The prep method computes
`O_RDONLY | O_CREAT | O_TRUNC | O_CLOEXEC` internally from the enum + OptionSet.

---

### 2.3 Fallocate: Operation Mode (Enum, Not OptionSet)

**Current**: `mode: Kernel.IO.Uring.File.Allocate.Mode` — OptionSet allowing contradictory
combinations like `[.punchHole, .insertRange]`.

**Semantic model**: Fallocate has distinct operations where only `.keepSize` combines:

| Operation | Kernel flags | Combines with keepSize? |
|-----------|-------------|------------------------|
| Allocate (default) | 0 | Yes |
| Punch hole | `FALLOC_FL_PUNCH_HOLE` | **Required** |
| Collapse range | `FALLOC_FL_COLLAPSE_RANGE` | No |
| Zero range | `FALLOC_FL_ZERO_RANGE` | Yes |
| Insert range | `FALLOC_FL_INSERT_RANGE` | No |
| Unshare range | `FALLOC_FL_UNSHARE_RANGE` | No |

**Proposed API** — either separate prep methods or an enum:

```swift
extension Kernel.File.Allocate {
    enum Mode: Sendable {
        case allocate(keepSize: Bool)
        case punch                          // implies keepSize
        case collapse
        case zero(keepSize: Bool)
        case insert
        case unshare
    }
}
```

The `rawValue` computation is internal:
```swift
switch mode {
case .allocate(let keepSize):
    flags = keepSize ? FALLOC_FL_KEEP_SIZE : 0
case .punch:
    flags = FALLOC_FL_PUNCH_HOLE | FALLOC_FL_KEEP_SIZE
case .collapse:
    flags = FALLOC_FL_COLLAPSE_RANGE
case .zero(let keepSize):
    flags = FALLOC_FL_ZERO_RANGE | (keepSize ? FALLOC_FL_KEEP_SIZE : 0)
case .insert:
    flags = FALLOC_FL_INSERT_RANGE
case .unshare:
    flags = FALLOC_FL_UNSHARE_RANGE
}
```

---

### 2.4 Poll: Events + Trigger + Multishot

**Current**: `flags: Kernel.IO.Uring.Poll.Options` combines control flags with what should
be poll events.

**Problem**: The poll flags (`IORING_POLL_ADD_MULTI`, `IORING_POLL_ADD_LEVEL`) are
io_uring control flags, but the ACTUAL poll events (POLLIN, POLLOUT, etc.) are passed
in a different SQE field. The ecosystem already has `Kernel.Event.Poll.Events` for
epoll events.

**Semantic model**:

```
Poll has:
1. Events to monitor: POLLIN, POLLOUT, POLLPRI, etc.  → Kernel.Event.Poll.Events (exists!)
2. Trigger mode: edge (default) | level               → enum or Bool
3. Multishot: true | false                             → Bool
```

**Proposed API**:

```swift
prepare.poll(
    target: Target,
    events: Kernel.Event.Poll.Events,      // reuse existing type
    multishot: Bool,                        // IORING_POLL_ADD_MULTI
    trigger: Kernel.IO.Uring.Poll.Trigger,  // .edge (default) | .level
    data: Operation.Data
)

extension Kernel.IO.Uring.Poll {
    enum Trigger: Sendable {
        case edge    // default
        case level   // IORING_POLL_ADD_LEVEL
    }
}
```

Poll update is a separate operation:

```swift
prepare.poll.update(
    target: Operation.Data,                 // user_data of poll to update
    events: Kernel.Event.Poll.Events,
    data: Operation.Data
)
```

`Kernel.IO.Uring.Poll.Options` is **deleted**.

---

### 2.5 Socket Create: Domain + Type + Protocol

**Current**: `socket(domain:type:protocol:flags:)` where flags is `Kernel.Socket.Options`.

**Assessment**: This is already close to correct. The SOCK_NONBLOCK and SOCK_CLOEXEC
flags ARE genuinely combinable with the socket type. However, `domain` and `type` should
be typed enums, not raw integers (if they aren't already).

**Proposed**: Keep `Kernel.Socket.Options` for the combinable descriptor flags. Ensure
`domain` and `type` use typed enums from `Kernel.Socket.Domain` and `Kernel.Socket.Type`
(if they exist; create if not).

---

### 2.6 Shutdown: Already has Enum

`Kernel.Socket.Shutdown.How` already exists as an enum (.read, .write, .both). The
prep method should accept it directly. ✓

---

### 2.7 Madvise: Already has Type

`Kernel.Memory.Map.Advice` already exists. The prep method should accept it. ✓

---

## Part III: Types That Are Correctly OptionSet

These flag sets are genuinely combinable. OptionSet is the right model. But they should
live in the correct owning module.

| Flag set | Correct OptionSet | Correct owner | Genuinely combinable? |
|----------|------------------|---------------|----------------------|
| `MSG_*` | `Kernel.Socket.Message.Options` | kernel-primitives | Yes — `MSG_DONTWAIT \| MSG_NOSIGNAL` is valid |
| `AT_*` | `Kernel.File.At.Options` | kernel-primitives or iso-9945 | Yes — `AT_EMPTY_PATH \| AT_SYMLINK_NOFOLLOW` is valid |
| `SPLICE_F_*` | `Kernel.Pipe.Splice.Options` | linux-primitives | Yes — `SPLICE_F_MOVE \| SPLICE_F_MORE` is valid |
| `SYNC_FILE_RANGE_*` | `Kernel.File.Sync.Range.Options` | linux-primitives | Yes — `WAIT_BEFORE \| WRITE \| WAIT_AFTER` is the canonical pattern |
| `XATTR_*` | `Kernel.File.Xattr.Options` | kernel-primitives or iso-9945 | **No** — `.create` and `.replace` are mutually exclusive |
| `SOCK_*` for accept/socket | `Kernel.Socket.Options` | kernel-primitives | Yes — `SOCK_NONBLOCK \| SOCK_CLOEXEC` is valid |
| `IORING_MSG_RING_*` | `Kernel.IO.Uring.Message.Options` | io_uring (correct) | Yes — `.cqeSkip \| .flagsPass` is valid |
| `IORING_FIXED_FD_*` | `Kernel.IO.Uring.Fixed.Install.Options` | io_uring (correct) | Yes (currently single flag) |

### 2.7a Xattr Flags Exception

`XATTR_CREATE` and `XATTR_REPLACE` are mutually exclusive. This should be an enum:

```swift
extension Kernel.File.Xattr {
    enum Disposition: Sendable {
        case createOrReplace   // flags = 0 (default)
        case createOnly        // XATTR_CREATE — fail if exists
        case replaceOnly       // XATTR_REPLACE — fail if absent
    }
}
```

---

## Part IV: Remaining io_uring-Owned Types

After reuse and decomposition, only these types remain io_uring-specific:

| Type | Kind | Stays in io_uring? |
|------|------|-------------------|
| `Kernel.IO.Uring.Clock` (new) | enum | Yes — io_uring-specific clock selection |
| `Kernel.IO.Uring.Poll.Trigger` (new) | enum | Yes — io_uring poll trigger mode |
| `Kernel.IO.Uring.Message.Options` | OptionSet | Yes — io_uring inter-ring messaging |
| `Kernel.IO.Uring.Fixed.Install.Options` | OptionSet | Yes — io_uring fixed-fd install |
| `Kernel.IO.Uring.Setup.Options` | OptionSet | Yes ✓ (already correct) |
| `Kernel.IO.Uring.Enter.Options` | OptionSet | Yes ✓ (already correct) |
| `Kernel.IO.Uring.Submission.Queue.Entry.Options` | OptionSet | Yes ✓ (already correct) |
| `Kernel.IO.Uring.Completion.Queue.Entry.Options` | OptionSet | Yes ✓ (already correct) |
| `Kernel.IO.Uring.Target` | enum | Yes ✓ (already correct) |
| `Kernel.IO.Uring.Vector` | struct | Yes ✓ (wraps iovec for io_uring API) |

---

## Part V: Prep Method Signature Changes

### 5.1 Timeout

```
BEFORE: prepare.timeout(timespec:, flags: Timeout.Options, data:)
AFTER:  prepare.timeout(after:, clock: .monotonic, multishot: false, data:)
        prepare.timeout(deadline:, clock: .monotonic, multishot: false, data:)
        prepare.timeout.remove(target:, data:)
        prepare.timeout.update(target:, newDeadline:, clock:, data:)
        prepare.timeout.link(after:, clock:, data:)
        prepare.timeout.link(deadline:, clock:, data:)
```

### 5.2 Open

```
BEFORE: prepare.openat(target:, path:, flags: File.Open.Options, mode:, data:)
AFTER:  prepare.openat(target:, path:, access: .readWrite, options: [.create, .truncate],
                        mode: .standard, data:)
```

### 5.3 Fallocate

```
BEFORE: prepare.fallocate(target:, mode: File.Allocate.Mode, offset:, length:, data:)
AFTER:  prepare.fallocate(target:, mode: .zero(keepSize: true), offset:, length:, data:)
```

### 5.4 Poll

```
BEFORE: prepare.poll(target:, events:, flags: Poll.Options, data:)
AFTER:  prepare.poll(target:, events: [.in, .out], multishot: true,
                      trigger: .edge, data:)
```

### 5.5 Send/Recv (ownership change only)

```
BEFORE: prepare.send(target:, buffer:, length:, flags: IO.Uring.Socket.Message.Options, data:)
AFTER:  prepare.send(target:, buffer:, length:, flags: Kernel.Socket.Message.Options, data:)
```
(Same OptionSet, different owner. Type moves to kernel-primitives.)

### 5.6 Xattr

```
BEFORE: prepare.fsetxattr(target:, name:, value:, length:, flags: Xattr.Options, data:)
AFTER:  prepare.fsetxattr(target:, name:, value:, length:, disposition: .createOnly, data:)
```

### 5.7 Statx / Unlinkat / Linkat (ownership change only)

```
BEFORE: prepare.statx(target:, path:, flags: IO.Uring.File.At.Options, ...)
AFTER:  prepare.statx(target:, path:, flags: Kernel.File.At.Options, ...)
```

---

## Part VI: Implementation Plan

### Phase 1: Decompose io_uring-owned semantics (no cross-package changes)

1. Create `Kernel.IO.Uring.Clock` enum
2. Create `Kernel.IO.Uring.Poll.Trigger` enum
3. Refactor timeout prep methods (overloads + decomposed parameters)
4. Refactor poll prep methods (events + trigger + multishot)
5. Delete `Kernel.IO.Uring.Timeout.Options` and `Kernel.IO.Uring.Poll.Options`

### Phase 2: Create types in correct owners (cross-package)

6. Create `Kernel.Socket.Message.Options` in kernel-primitives
7. Create `Kernel.File.At.Options` in kernel-primitives
8. Create `Kernel.File.Open.Access` enum in kernel-primitives
9. Create `Kernel.File.Allocate.Mode` enum in linux-primitives
10. Create `Kernel.File.Xattr.Disposition` enum in kernel-primitives or iso-9945
11. Create `Kernel.Pipe.Splice.Options` in linux-primitives
12. Create `Kernel.File.Sync.Range.Options` in linux-primitives
13. Create `Kernel.Futex.Options` in linux-primitives
14. Create `Kernel.Process.Wait.Options` in iso-9945

### Phase 3: Wire io_uring prep methods to ecosystem types

15. Update prep method signatures to reference Phase 2 types
16. Delete io_uring duplicate types (File.Open.Options, File.Rename.Options, etc.)
17. Update openat to take `access:` enum + `options:` OptionSet
18. Update fallocate to take decomposed `Mode` enum

### Phase 4: Verify

19. Build swift-linux-primitives
20. Run tests
21. Verify no raw `Int32`/`UInt32` flags remain in public API

---

## Outcome

**Status**: RECOMMENDATION

### Summary

Of the 29 flag parameters in io_uring Prepare:
- **4 require semantic decomposition** (timeout → clock enum + overloads, open → access enum +
  options, fallocate → mode enum, poll → events + trigger + multishot)
- **1 requires enum instead of OptionSet** (xattr → disposition enum)
- **12 should move to their correct ecosystem owner** (MSG_*, AT_*, SPLICE_F_*, etc.)
- **3 duplicate existing ecosystem types** (File.Open.Options, File.Rename.Options, Pipe.Options)
- **5 are correctly io_uring-owned OptionSets** (Message.Options, Fixed.Install.Options, plus
  the pre-existing Setup/Enter/SQE/CQE flags)
- **4 are already using the correct ecosystem type** (Socket.Options for accept, Shutdown.How,
  Memory.Map.Advice, File.Permissions)

The net result: io_uring **owns** ~7 types (Clock, Poll.Trigger, Message.Options,
Fixed.Install.Options, Target, Vector, and the ring-management flags). Everything else
is **referenced** from the owning domain.

### Design Principle Confirmed

io_uring is a **submission mechanism**, not a domain owner. It submits socket operations
but doesn't own socket types. It submits file operations but doesn't own file types.
The typed parameters should reflect this: io_uring prep methods accept types from the
domains they operate on and only define types for io_uring-specific concepts (ring
management, submission control, completion interpretation).

## References

- Ecosystem inventory: agent analysis of swift-kernel-primitives, swift-linux-primitives,
  swift-clock-primitives Sources/ directories
- Existing types: `Kernel.File.Open.Options`, `Kernel.File.Rename.Options`,
  `Kernel.Pipe.Options`, `Kernel.Socket.Options`, `Kernel.Socket.Shutdown.How`,
  `Kernel.Event.Poll.Events`, `Kernel.Memory.Map.Advice`, `Kernel.File.Permissions`,
  `Kernel.Time.Deadline`, `Clock.Nanoseconds`
- Linux kernel io_uring spec: `linux-io-uring-api-reference.md` (this directory)
- Implementation audit: `io-uring-l1-api-audit-and-recommendations.md` (this directory)
