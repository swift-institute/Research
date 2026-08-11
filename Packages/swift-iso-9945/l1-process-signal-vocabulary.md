# L1 Process/Signal Vocabulary Design

Research findings on type placement across L1 (Kernel Process Primitives) and L2 (ISO 9945).

---

## Kernel.Process: Namespace vs Struct

### Current state

`Kernel.Process` is a namespace enum at L1 (`Kernel Process Primitives/Kernel.Process.swift`, line 22):

```swift
public enum Process {}
```

It contains:
- `Kernel.Process.ID` — struct with platform-conditional `RawValue` (Int32 on POSIX, UInt32 on Windows)
- `Kernel.Process.Group` — namespace enum (empty at L1, extended at L2)

### Analysis

**Namespace enum is correct.** The reasoning:

1. **No single cross-platform representation exists.** POSIX identifies a process by a single `pid_t`. Windows identifies a process by a `HANDLE` (for operations) and a `DWORD` PID (for lookup). A struct at L1 would force choosing one model or papering over both with a union, which is exactly the wrong abstraction at the vocabulary layer.

2. **`Kernel.Process.ID` already handles the representational split.** The `ID` struct uses `#if os(Windows)` to switch between `UInt32` and `Int32`. This is the right granularity — the ID is the vocabulary type; the process namespace is just a container.

3. **Precedent within L1.** `Kernel.Group` (file-ownership GID) and `Kernel.User` (UID) are also namespace enums containing only an `ID` typealias. `Kernel.Process` follows the same pattern.

4. **A struct would imply owning or referencing a process.** That is an L3 concept (e.g., a process handle that manages lifetime). L1 provides only vocabulary and identity.

### Recommendation

**Keep `Kernel.Process` as namespace enum.** No change needed.

---

## Process.Group.ID Location

### Current state

Defined at L2 in `ISO 9945 Core/ISO 9945.Kernel.Process.Group.ID.swift` (line 39):

```swift
public typealias ID = Tagged<ISO_9945.Kernel.Process.Group, Int32>
```

Uses `Int32` (not `pid_t`), with a `.current` constant calling `getpgrp()`. Located in Core as a cycle-breaker: `ISO 9945 Kernel Signal` needs `Process.Group.ID` for `Signal.Send.toGroup(pgid:)`, and `ISO 9945 Kernel Process` needs `Signal.Number` for `Process.Kill`.

### Analysis: L1 vs L2

**Process.Group.ID should stay at L2.** Reasoning:

1. **Process groups are a POSIX concept, not a cross-platform one.** Windows has "job objects" which serve a similar organizational role but have fundamentally different semantics (HANDLE-based, hierarchical containment model, no negative-PID signaling convention). There is no cross-platform vocabulary for "process group."

2. **Contrast with `Kernel.Process.ID`, which IS at L1.** Every operating system has a process identifier (PID on POSIX, DWORD on Windows). `Process.ID` is genuinely cross-platform vocabulary. `Process.Group.ID` is not.

3. **The L1 `Kernel.Process.Group` namespace is already empty.** It exists as a namespace placeholder (line 27 of `Kernel.Process.swift`). It does not define an `ID` type — deliberately, because L1 cannot commit to what "group" means across platforms.

4. **The `Int32` raw value is POSIX-specific.** The decision to use `Int32` (matching `pid_t` on all POSIX platforms) is itself a POSIX design choice. Windows job objects use `HANDLE`.

5. **The `.current` constant calls `getpgrp()`.** This is a POSIX syscall. Even the constant cannot exist at L1 without platform guards, and L1 kernel primitives should not call libc.

### Recommendation

**Keep `Process.Group.ID` at L2 (ISO 9945 Core).** It is POSIX vocabulary, not cross-platform vocabulary.

---

## Signal.Number Location

### Current state

`Signal.Number` struct is defined at L2 in `ISO 9945 Core/ISO 9945.Kernel.Signal.Number.swift`:

```swift
extension ISO_9945.Kernel.Signal {
    public struct Number: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: Int32
    }
}
```

The `Signal` namespace itself is also in Core (`ISO 9945.Kernel.Signal.swift`). Signal constants (`.interrupt`, `.terminate`, etc.) and operations (`.Send`, `.Mask`, `.Action`, `.Set`) are in the `ISO 9945 Kernel Signal` target.

**There is no signal-related target at L1.** The `swift-kernel-primitives/Sources/` directory has no `Kernel Signal Primitives` target.

### The original cycle

Before the Core target was introduced, the cycle was:
- `ISO 9945 Kernel Signal` needs `Process.Group.ID` (for `Signal.Send.toGroup(pgid:)`)
- `ISO 9945 Kernel Process` needs `Signal.Number` (for `Process.Kill.kill(_:_:)`)

The cycle-breaker strategy moved both `Signal.Number` (struct only) and `Process.Group.ID` into `ISO 9945 Core`, which both Signal and Process targets depend on.

### Could Signal.Number move back if Process.Group.ID moved to L1?

This question is moot given the recommendation above (Process.Group.ID stays at L2). But even hypothetically: **no**. The cycle has two edges:

1. Signal target needs Process.Group.ID → moving Group.ID to L1 would resolve this as an L1 dependency
2. Process target needs Signal.Number → this edge would STILL exist

Even in the hypothetical where Process.Group.ID were at L1 (not recommended), Signal.Number would still need to be in Core (or Signal would need to depend on Process, recreating a different cycle). Both types remaining in Core is the correct resolution.

### The duplicate Signal type problem (RESOLVED)

`ISO 9945 Kernel Process/ISO 9945.Kernel.Process.Kill.swift` previously defined its own `Process.Signal` struct with a subset of constants (`.stop`, `.cont`, `.kill`, `.term`, `.int`, `.hup`). This duplicated `Signal.Number` from Core, which was already available to the Process target.

**Resolution (2026-04-10):** `Process.Signal` was deleted. `Process.Kill.kill(_:_:)` now accepts `ISO_9945.Kernel.Signal.Number` directly from Core. Doc examples updated to use Signal.Number constant names (`.terminate`, `.stop`, `.continue`). This also resolved an [API-IMPL-005] audit finding (two type declarations in one file).

### Recommendation

**Keep `Signal.Number` in ISO 9945 Core.** The cycle-breaker placement is correct and minimal. The `Process.Signal` unification is complete.

---

## Process.Session.ID: pid_t to Int32

### Current state

`ISO 9945 Kernel Process/ISO 9945.Kernel.Process.Session.swift`, line 41:

```swift
public typealias ID = Tagged<ISO_9945.Kernel.Process.Session, pid_t>
```

### Finding

This uses `pid_t` as the `Tagged` raw value. The decision was already made to use `Int32` for `Process.Group.ID` (to avoid platform types leaking into public API). `Session.ID` should follow the same convention.

On all POSIX platforms, `pid_t` is `Int32`, so this is a source-compatible change. The issue is API hygiene: `pid_t` requires a Darwin/Glibc/Musl import to resolve, whereas `Int32` is a Swift stdlib type.

### What needs to change

Line 41 of `ISO 9945.Kernel.Process.Session.swift`:
```swift
// Current:
public typealias ID = Tagged<ISO_9945.Kernel.Process.Session, pid_t>

// Should become:
public typealias ID = Tagged<ISO_9945.Kernel.Process.Session, Int32>
```

The `public import Darwin` on line 15 can then be changed to `internal import Darwin` (it is currently `public` — likely only because `pid_t` leaks through the typealias).

---

## Dependency Graph

```
L1: Kernel Process Primitives
    ├── Kernel.Process          (namespace enum)
    ├── Kernel.Process.ID       (struct, Int32/UInt32)
    ├── Kernel.Process.Group    (namespace enum, empty)
    ├── Kernel.Group            (file-ownership GID, UInt32)
    └── Kernel.User             (UID, UInt32)

L2: ISO 9945 Core (cycle-breaker, internal target)
    ├── ISO_9945.Kernel.Signal          (namespace enum)
    ├── ISO_9945.Kernel.Signal.Number   (struct, Int32)  ← moved here to break cycle
    ├── ISO_9945.Kernel.Process.Group.ID (Tagged<..., Int32>)  ← moved here to break cycle
    ├── ISO_9945.Kernel.Error.*         (error types)
    └── imports: Kernel Process Primitives, Kernel Descriptor Primitives,
                 Kernel Error Primitives, Identity Primitives

L2: ISO 9945 Kernel Signal
    ├── Signal.Number+Constants   (.interrupt, .terminate, etc.)
    ├── Signal.Send               (uses Process.Group.ID from Core, Signal.Number from Core)
    ├── Signal.Action, .Mask, .Set
    └── imports: ISO 9945 Core, Kernel Syscall Primitives

L2: ISO 9945 Kernel Process
    ├── Process.ID extensions     (.current, .parent — typealiases to L1 Kernel.Process.ID)
    ├── Process.Group operations  (setpgid, getpgid — uses Group.ID from Core)
    ├── Process.Session           (setsid, getsid — Session.ID uses pid_t, should be Int32)
    ├── Process.Kill              (uses Signal.Number from Core)
    ├── Process.Fork, .Wait, .Execute, .Spawn, .Exit, .Status
    └── imports: ISO 9945 Core, Kernel Process Primitives, Kernel Syscall Primitives,
                 Kernel Path Primitives
```

### Cycle edges (both resolved by Core target)

```
Signal.Send.toGroup(pgid:)  ──needs──>  Process.Group.ID
Process.Kill.kill(_:_:)     ──needs──>  Signal.Number (uses Signal.Number from Core directly)
```

### Key observations

1. `ISO 9945 Kernel Signal` and `ISO 9945 Kernel Process` are peer targets — neither depends on the other. Both depend on `ISO 9945 Core`.
2. The Core target is internal (not a published product). This is correct — it exists solely as a cycle-breaker and shared type host.
3. The Process target uses `Signal.Number` from Core directly (duplicate `Process.Signal` was removed).
4. No signal vocabulary exists at L1. This is correct — signals are a POSIX concept (Windows uses structured exception handling, not signal numbers).

---

## Summary of Recommendations

| Item | Recommendation | Rationale |
|------|---------------|-----------|
| `Kernel.Process` | Keep as namespace enum | No single process representation exists cross-platform |
| `Process.Group.ID` | Keep at L2 (ISO 9945 Core) | POSIX-specific concept; Windows uses job objects |
| `Signal.Number` | Keep at L2 (ISO 9945 Core) | Signals are POSIX-specific; cycle-breaker placement is correct |
| `Process.Session.ID` | Change `pid_t` to `Int32` | Consistency with Group.ID; avoid platform type in public API |
| `Process.Signal` (in Kill.swift) | **DONE**: unified with `Signal.Number` (2026-04-10) | Duplicate removed; `kill(_:_:)` now accepts `Signal.Number` from Core |
