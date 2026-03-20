# swift-windows-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (Opus 4.6)
**Scope**: All `.swift` files in `Sources/` (82 files across 4 modules)
**Skills**: naming, implementation

---

## Summary Table

| ID | Severity | Rule | File | Description |
|----|----------|------|------|-------------|
| [WIN-001] | MEDIUM | [API-NAME-002] | Socket.Options | `getOption`/`setOption`/`getBoolOption`/`setBoolOption`/`getIntOption`/`setIntOption` — compound method names |
| [WIN-002] | MEDIUM | [API-NAME-002] | Socket.Options | `setReuseAddress`, `setNoDelay`, `setReceiveBuffer`, `setSendBuffer`, `setKeepAlive` — compound method names |
| [WIN-003] | MEDIUM | [API-NAME-002] | Socket.Options | `getSockName`, `getPeerName`, `getError` — compound method names |
| [WIN-004] | MEDIUM | [API-NAME-002] | Socket.Send | `sendTo` — compound method name |
| [WIN-005] | MEDIUM | [API-NAME-002] | Socket.Receive | `receiveFrom`, `receiveFromIPv4`, `receiveFromIPv6` — compound method names |
| [WIN-006] | MEDIUM | [API-NAME-002] | Socket.Accept | `acceptIPv4`, `acceptIPv6` — compound method names |
| [WIN-007] | MEDIUM | [API-NAME-002] | Process | `getCurrentId`, `getCurrentHandle`, `getExitCode` — compound method names |
| [WIN-008] | MEDIUM | [API-NAME-002] | Pipe.Named | `getInfo` — compound method name |
| [WIN-009] | MEDIUM | [API-NAME-002] | Console | `standardInput`, `standardOutput`, `standardError`, `isConsole` — compound method names |
| [WIN-010] | MEDIUM | [API-NAME-002] | Console | `getInputMode`, `setInputMode`, `getOutputMode`, `setOutputMode` — compound method names |
| [WIN-011] | MEDIUM | [API-NAME-002] | Console | `getScreenBufferInfo`, `setCursorPosition` — compound method names |
| [WIN-012] | MEDIUM | [API-NAME-002] | Time | `systemTime`, `systemTimeRaw`, `unixTime`, `unixTimeNanoseconds` — compound method names |
| [WIN-013] | MEDIUM | [API-NAME-002] | Time | `performanceCounter`, `performanceFrequency`, `elapsedNanoseconds` — compound method names |
| [WIN-014] | MEDIUM | [API-NAME-002] | Time | `tickCount`, `tickCount64` — compound method names |
| [WIN-015] | MEDIUM | [API-NAME-002] | Loader.Library | `getHandle` — compound method name |
| [WIN-016] | MEDIUM | [API-NAME-002] | File.Stats.Get | `getStats`, `getAttributes`, `getSize`, `isDirectory`, `isRegularFile`, `getType` — compound method names |
| [WIN-017] | MEDIUM | [API-NAME-002] | File.Attributes | `setAttributes`, `getAttributes`, `setReadOnly`, `setHidden` — compound method names |
| [WIN-018] | MEDIUM | [API-NAME-002] | File.Times | `setTimes`, `getTimes`, `fileTimeFromUnix`, `unixFromFileTime`, `currentFileTime`, `getBasicInfo`, `setBasicInfo`, `copyBasicInfo` — compound method names |
| [WIN-019] | MEDIUM | [API-NAME-002] | Thread | `currentID` — compound method name |
| [WIN-020] | MEDIUM | [API-NAME-002] | Memory.Allocation | `allocateAligned`, `systemPageSize` — compound method names |
| [WIN-021] | MEDIUM | [API-NAME-002] | Memory.Map | `mapAnonymous` — compound method name |
| [WIN-022] | LOW | [API-NAME-002] | Loader.Error | `captureLastErrorMessage` — compound free function name |
| [WIN-023] | LOW | [API-NAME-002] | Socket.Error | `captureLastSocketError` — compound free function name |
| [WIN-024] | MEDIUM | [API-NAME-001] | Socket | `SocketType` — compound type name (should be `Socket.Kind` or nested) |
| [WIN-025] | MEDIUM | [API-NAME-001] | Console | `InputMode`, `OutputMode`, `ScreenBufferInfo` — compound type names |
| [WIN-026] | MEDIUM | [API-NAME-001] | Pipe.Named | `OpenMode`, `PipeMode` — compound type names |
| [WIN-027] | MEDIUM | [API-NAME-001] | Socket.Send | `SendFlags` — compound type name |
| [WIN-028] | MEDIUM | [API-NAME-001] | Socket.Receive | `ReceiveFlags` — compound type name |
| [WIN-029] | MEDIUM | [API-NAME-001] | Socket.Options | `OptionLevel`, `OptionName` — compound type names |
| [WIN-030] | MEDIUM | [API-NAME-001] | Socket.Accept | `AcceptResult` — compound type name |
| [WIN-031] | MEDIUM | [API-NAME-001] | File.Stats.Get | `FileType` — compound type name |
| [WIN-032] | MEDIUM | [API-NAME-001] | File.Times | `BasicInfo` — compound type name |
| [WIN-033] | LOW | [PATTERN-017] | Memory.Map.Flags | `.rawValue` in non-boundary query methods (`isAnonymous`, `isPrivate`, `isShared`) |
| [WIN-034] | LOW | [PATTERN-017] | Memory.Map.Protection | `.rawValue` in conversion methods (acceptable boundary code) |
| [WIN-035] | LOW | [PATTERN-017] | Console | `.rawValue` in `setInputMode`/`setOutputMode` pass-through |
| [WIN-036] | INFO | [PATTERN-017] | Various | `.rawValue` usage in Win32 API boundary calls — this is expected boundary code |
| [WIN-037] | LOW | [IMPL-INTENT] | File.Stats.Get | `isDirectory`/`isRegularFile`/`isSymlink`/`isReadOnly`/`isHidden`/`isSystem` use bitwise mask on DWORD — mechanism over intent |
| [WIN-038] | LOW | [IMPL-INTENT] | File.Rename | Manual pointer arithmetic for `FILE_RENAME_INFO` — necessary but reads as mechanism |
| [WIN-039] | INFO | [API-IMPL-005] | File.Stats.Get | Contains `Stats` struct, `FileType` enum, and multiple `File` extensions — multiple types |
| [WIN-040] | INFO | [API-IMPL-005] | File.Times | Contains `BasicInfo` struct alongside `Times` and `File` extensions — multiple types |
| [WIN-041] | INFO | [API-IMPL-005] | Console | Contains `Console`, `InputMode`, `OutputMode`, `ScreenBufferInfo` — multiple types |
| [WIN-042] | INFO | [API-IMPL-005] | Socket | Contains `Family`, `SocketType`, `Protocol` — multiple types |
| [WIN-043] | LOW | [API-NAME-001] | Loader.Error | `ErrorCode` — compound type name nested under `Windows.Loader` |
| [WIN-044] | LOW | [IMPL-002] | Pipe.Named | `openMode.rawValue` and `pipeMode.rawValue` passed directly to `CreateNamedPipeW` |

---

## Detailed Findings

### [WIN-001] through [WIN-023]: Compound Method Names (API-NAME-002)

**Classification: Our own invention (VIOLATIONS)**

These are NOT Win32 API mirror names. Win32 uses flat C function names (`GetCurrentProcessId`, `getsockopt`, etc.). Our Swift wrapper layer is where naming decisions are made, and [API-NAME-002] requires nested accessors instead of compound names.

**Examples of what should change:**

| Current (compound) | Suggested (nested) |
|--------------------|--------------------|
| `Process.getCurrentId()` | `Process.current.id` |
| `Process.getCurrentHandle()` | `Process.current.handle` |
| `Process.getExitCode(handle:)` | `Process.exit.code(handle:)` |
| `Socket.getOption(...)` | `Socket.option.get(...)` |
| `Socket.setOption(...)` | `Socket.option.set(...)` |
| `Socket.setReuseAddress(...)` | `Socket.reuse.address(...)` or via `option` accessor |
| `Socket.setNoDelay(...)` | `Socket.noDelay(...)` or `Socket.option.noDelay(...)` |
| `Socket.getSockName(...)` | `Socket.name.local(...)` or `Socket.local.name(...)` |
| `Socket.getPeerName(...)` | `Socket.name.peer(...)` or `Socket.peer.name(...)` |
| `Socket.sendTo(...)` | overload `Socket.send(... to:)` |
| `Socket.receiveFrom(...)` | overload `Socket.receive(... from:)` |
| `Socket.acceptIPv4(...)` | overload `Socket.accept.ipv4(...)` |
| `Console.standardInput()` | `Console.standard.input` |
| `Console.getInputMode(...)` | `Console.input.mode(...)` |
| `Console.getScreenBufferInfo(...)` | `Console.screen.buffer.info(...)` |
| `Console.setCursorPosition(...)` | `Console.cursor.position(...)` |
| `Time.systemTime()` | `Time.system()` or `Time.system.fileTime` |
| `Time.tickCount()` | `Time.tick.count` |
| `Time.performanceCounter()` | `Time.performance.counter` |
| `File.getStats(...)` | `File.stats(...)` |
| `File.getAttributes(...)` | `File.attributes(...)` |
| `File.setReadOnly(...)` | `File.readOnly(...)` |
| `Loader.Library.getHandle(...)` | `Loader.Library.handle(moduleName:)` |

**Note**: Some of these (like `getStats`, `getAttributes`) could be considered Win32-mirroring, but the Win32 names are `GetFileInformationByHandle` and `GetFileAttributesW` — we have already diverged from the Win32 names, so the [API-NAME-003] spec-mirroring exception does not apply.

### [WIN-024] through [WIN-032]: Compound Type Names (API-NAME-001)

**Classification: Our own invention (VIOLATIONS)**

| Current | Suggested |
|---------|-----------|
| `Socket.SocketType` | `Socket.Kind` (avoids reserved `Socket.Type`) |
| `Console.InputMode` | `Console.Input.Mode` |
| `Console.OutputMode` | `Console.Output.Mode` |
| `Console.ScreenBufferInfo` | `Console.Screen.Buffer.Info` |
| `Pipe.Named.OpenMode` | `Pipe.Named.Open.Mode` |
| `Pipe.Named.PipeMode` | `Pipe.Named.Mode` |
| `Socket.SendFlags` | `Socket.Send.Flags` |
| `Socket.ReceiveFlags` | `Socket.Receive.Flags` |
| `Socket.OptionLevel` | `Socket.Option.Level` |
| `Socket.OptionName` | `Socket.Option.Name` |
| `Socket.AcceptResult` | `Socket.Accept.Result` |
| `File.FileType` | `File.Kind` |
| `File.BasicInfo` | `File.Basic.Info` |
| `Loader.ErrorCode` | `Loader.Error.Code` (already partially used) |

### [WIN-033] through [WIN-036]: .rawValue Usage (PATTERN-017)

Most `.rawValue` usage is at the Win32 API boundary — passing values to `CreateNamedPipeW`, `SetConsoleMode`, `VirtualAlloc`, etc. This is exactly where `.rawValue` belongs per [PATTERN-017].

**True violations** (non-boundary usage):
- `Memory.Map.Flags.isAnonymous/isPrivate/isShared`: Uses `(rawValue & Self.anonymous.rawValue) != 0` instead of `contains(.anonymous)`. Should use `OptionSet.contains()`.

### [WIN-037] through [WIN-038]: Intent Over Mechanism (IMPL-INTENT)

- `File.Stats.Get` (line 63-95): The `isDirectory`/`isReadOnly` etc. computed properties use `(attributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0`. Since `attributes` is a raw `DWORD` (not an `OptionSet`), this is mechanism-heavy. The `Attributes` OptionSet type exists in `File.Attributes.swift` but is not used here — the `Stats` struct stores raw `DWORD` instead.

- `File.Rename.atomic`: The manual memory layout calculation for `FILE_RENAME_INFO` is necessary C interop, not a violation per se, but could benefit from a helper type.

### [WIN-039] through [WIN-042]: One Type Per File (API-IMPL-005)

Several files contain multiple type declarations:

- `Windows.Kernel.File.Stats.Get.swift`: Contains `Stats` struct, `FileType` enum, and multiple static method extensions on `Windows.Kernel.File`
- `Windows.Kernel.File.Times.swift`: Contains `BasicInfo` struct alongside `Times` and `File` extensions
- `Windows.Kernel.Console.swift`: Contains `Console`, `InputMode`, `OutputMode`, `ScreenBufferInfo`
- `Windows.Kernel.Socket.swift`: Contains `Family`, `SocketType`, `Protocol`

These should be split: one file per type, following the `Namespace.Type.swift` naming pattern.

### Spec-Mirroring Assessment (API-NAME-003)

The following items were reviewed and **confirmed as acceptable** under the [API-NAME-003] spec-mirroring exception:

1. **Win32 API function names used as WinSDK calls**: `CreateFileW`, `ReadFile`, `WriteFile`, `CloseHandle`, etc. — these are direct Win32 calls, not our API surface.
2. **Win32 constant names in static properties**: `PIPE_ACCESS_DUPLEX`, `FILE_ATTRIBUTE_READONLY`, `MSG_OOB`, etc. — mirror names for Win32 constants within OptionSet types.
3. **Socket operation names** (`bind`, `listen`, `accept`, `connect`, `send`, `receive`, `shutdown`): These mirror BSD/POSIX socket API names that Winsock2 also uses. Acceptable.
4. **Byte-order helpers** (`htons`, `ntohs`, `htonl`, `ntohl`): Standard network byte-order function names. Acceptable.

### Items NOT Flagged

- **Typed throws**: All throwing functions use typed throws. Compliant with [API-ERR-001].
- **Nest.Name pattern for namespaces**: `Windows.Kernel.IO.Completion.Port`, `Windows.Kernel.Socket`, etc. — all follow nested pattern. Compliant.
- **File naming**: Files follow the `Namespace.Type.swift` convention. Compliant.
- **No Foundation**: No Foundation imports found. Compliant with [PRIM-FOUND-001].

---

## Statistics

| Category | Count |
|----------|-------|
| Total files audited | 82 |
| Compound method findings | 23 (covering ~74 methods) |
| Compound type findings | 9 (covering ~14 types) |
| .rawValue violations (non-boundary) | 1 |
| IMPL-INTENT findings | 2 |
| One-type-per-file findings | 4 |
| **Total findings** | **44** |

## Risk Assessment

This package is a **platform boundary layer** — it wraps Win32 syscalls. The high count of compound names stems from mirroring the Win32 getter/setter pattern (`GetX`/`SetX`) in Swift instead of using nested accessor patterns. Since this is our API surface (not spec-mirrored names), the [API-NAME-003] exception does not apply.

**Priority**: The compound method names ([WIN-001] through [WIN-023]) are the highest-impact findings. They establish API patterns that consumers will depend on. Fixing them before the API stabilizes would prevent breaking changes later.
