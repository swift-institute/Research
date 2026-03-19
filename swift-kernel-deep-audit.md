# swift-kernel Deep Audit

**Date**: 2026-03-19 (audit), 2026-03-19 (fixes applied)
**Package**: swift-kernel (Layer 3 — Foundations)
**Location**: `/Users/coen/Developer/swift-foundations/swift-kernel/`
**Scope**: 51 source files → 59 source files (8 new from splits + deduplication), 7 test support files, 6 test files
**Status**: ALL CRITICAL, HIGH, and actionable MEDIUM findings FIXED. 91/91 tests pass.
**Dependencies**: swift-kernel-primitives, swift-system-primitives, swift-binary-primitives, swift-dimension-primitives, swift-queue-primitives, swift-reference-primitives, swift-posix, swift-darwin, swift-linux, swift-windows, swift-strings, Ownership_Primitives

---

## Executive Summary

swift-kernel is a well-architected unification layer. Every type either provides genuine cross-platform value (thread management, file operations, system info dispatchers) or cleanly re-exports primitives. No redundant wrappers were found — the package earns its place as the unified kernel abstraction.

The primary issues are:

1. **Massive code duplication** (~400 lines) between Atomic and Streaming write APIs — identical path resolution, rename, sync, hex encoding, and writeAll implementations.
2. **Direct platform C library imports in L3** — several files import Darwin/Glibc/Musl/WinSDK directly rather than going through the platform package chain, violating L3 layering.
3. **One untyped `throws` violation** in the streaming write `fill` closure.
4. **Multiple-types-per-file violations** in Synchronization and Worker files.
5. **TOCTOU-prone rename pattern** using `try?` + post-verification instead of propagating the actual error.

**Severity distribution**: 2 CRITICAL, 7 HIGH, 12 MEDIUM, 5 LOW

---

## Type Origin Map

| Kernel Type | Source Package | Relationship | Assessment |
|-------------|---------------|--------------|------------|
| `Kernel.Thread.Executor` | **New in L3** | SerialExecutor/TaskExecutor backed by OS thread | **Genuine value** — Swift concurrency integration |
| `Kernel.Thread.Executors` | **New in L3** | Sharded round-robin executor pool | **Genuine value** — bounded threading |
| `Kernel.Thread.Executors.Options` | **New in L3** | Pool configuration | **Genuine value** |
| `Kernel.Thread.Executor.Job` | stdlib `UnownedJob` | Typealias | **Clean re-export** |
| `Kernel.Thread.Executor.Job.Queue` | Queue_Primitives `Deque` | Composition | **Genuine value** — typed FIFO wrapper |
| `Kernel.Thread.Synchronization<N>` | Kernel_Thread_Primitives `Mutex`, `Condition` | Composition | **Genuine value** — value-generic N-condition wrapper with waiter tracking |
| `Kernel.Thread.Worker` | Kernel_Thread_Primitives `Handle` | Composition | **Genuine value** — managed lifecycle with stop token |
| `Kernel.Thread.Worker.Token` | stdlib `Atomic<Bool>` | Composition | **Genuine value** |
| `Kernel.Thread.Spawn` | Kernel_Thread_Primitives `create` | Callable wrapper | **Genuine value** — ergonomic syntax + ~Copyable transfer |
| `Kernel.Thread.Trap` | Kernel.Thread.Spawn | Fatal variant | **Genuine value** |
| `Kernel.Thread.Gate` | Kernel.Thread.SingleSync | Composition | **Genuine value** — one-shot barrier |
| `Kernel.Thread.Barrier` | Kernel_Thread_Primitives `Mutex`, `Condition` | Composition | **Genuine value** — N-way rendezvous |
| `Kernel.Thread.AffinityAccessor` | Linux/Windows `Thread.Affinity.apply` | Cross-platform dispatcher | **Genuine value** — unified affinity API |
| `Kernel.Thread.Count` | Cardinal_Primitives `Tagged<_, Cardinal>` | Typealias + conversion | **Clean re-export** with domain tagging |
| `Kernel.Thread.Handle+joinChecked` | Kernel_Thread_Primitives `Handle` | Extension | **Genuine value** — safety precondition |
| `Kernel.Thread.Handle.Reference` | Kernel_Thread_Primitives `Handle` | Reference wrapper | **Genuine value** — stores ~Copyable in arrays |
| `Kernel.File.Open.Configuration` | **New in L3** | High-level open config | **Genuine value** — bundles mode/create/truncate/cache |
| `Kernel.File.open()` | Kernel_File_Primitives `Open.open` | Composition | **Genuine value** — Direct I/O resolution |
| `Kernel.File.Clone.clone()` | Platform-specific syscalls | Cross-platform dispatcher | **Genuine value** — reflink/copy strategies |
| `Kernel.File.Copy.copy()` | Kernel.File.Clone | Composition | **Genuine value** — attribute preservation, symlink handling |
| `Kernel.File.Write.Atomic` | Multiple primitives | Complex pipeline | **Genuine value** — crash-safe write |
| `Kernel.File.Write.Streaming` | Multiple primitives | Complex pipeline | **Genuine value** — memory-efficient write |
| `Kernel.Continuation.Context` | stdlib `Atomic<UInt8>` | New type | **Genuine value** — exactly-once resumption |
| `Kernel.Failure` | All domain errors | Aggregation | **Genuine value** — unified error routing |
| `Kernel.System.Processor.count` | Platform-specific | Cross-platform dispatcher | **Genuine value** |
| `Kernel.System.Processor.Physical.count` | Platform-specific | Cross-platform dispatcher | **Genuine value** |
| `Kernel.System.Memory.total` | Platform-specific | Cross-platform dispatcher | **Genuine value** |
| `Kernel.Lock.Acquire.timeout()` | `Clock.Continuous` | Convenience | **Genuine value** — Duration-to-deadline |
| `Tagged+Kernel.Atomic.Flag` | Kernel_Thread_Primitives `Atomic.Flag` | Forwarding extension | **Genuine value** — tagged flag ergonomics |
| `Optional._take()` | **New utility** | ~Copyable optional consume | **Misplaced** — should be in primitives |
| `Swift.String+Kernel` | Kernel_String_Primitives | Conversion extension | **Genuine value** — platform-conditional |

**Conclusion**: 0 redundant wrappers, 0 re-implementations. All 30+ types add cross-platform or compositional value beyond what primitives provide. One utility (`Optional._take()`) is misplaced.

---

## Findings by Category

### CRITICAL

#### C-1: Massive code duplication between Atomic and Streaming write APIs

**Files**:
- `Kernel.File.Write.Atomic+API.swift` (610 lines)
- `Kernel.File.Write.Streaming+API.swift` (726 lines)

**Description**: The following private helper functions are duplicated **verbatim** between these two files:

| Function | Atomic lines | Streaming lines |
|----------|-------------|-----------------|
| `resolvePaths(_:)` | 144-153 | 309-318 |
| `normalizeWindowsPath(_:)` | 156-170 | 321-335 |
| `windowsParentDirectory(of:)` | 172-184 | 337-349 |
| `posixParentDirectory(of:)` | 193-201 | 351-359 |
| `fileName(of:)` | 186-191 / 203-208 | 431-443 |
| `fileExists(_:)` | 215-224 | 366-375 |
| `syncFile(_:durability:)` | 411-425 | 600-614 |
| `closeFile(_:)` | 427-433 | 616-622 |
| `atomicRename(from:to:)` | 439-458 | 628-648 |
| `atomicRenameNoClobber(from:to:)` | 461-497 | 650-687 |
| `syncDirectory(_:)` | 499-534 | 689-726 |
| `randomToken(length:)` | 300-319 | 446-466 |
| `hexEncode(_:)` | 322-331 | 469-478 |
| `writeAll(_:to:pathString:)` | 351-405 | 485-539 |

**Impact**: ~400 lines of identical code across two files. Any bug fix must be applied twice. Any behavioral divergence becomes a silent correctness issue.

**Rules violated**: [IMPL-INTENT] — duplicated mechanism obscures shared intent.

**Recommendation**: Extract shared helpers into a `Kernel.File.Write` extension namespace (e.g., `Kernel.File.Write+Shared.swift` or `Kernel.File.Write.Helpers.swift`).

---

#### C-2: Direct platform C library imports in L3 code

**Files**:
- `Kernel.File.Write.Atomic+API.swift:14-22`
- `Kernel.File.Write.Streaming+API.swift:14-22`
- `Kernel.Failure.swift:131-133`
- `Kernel.File.Clone.swift:12` (less severe — uses `Kernel_Primitives`)

**Description**: Three files import platform C libraries directly:

```swift
// Kernel.File.Write.Atomic+API.swift:14-22
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
internal import WinSDK
#endif
```

```swift
// Kernel.Failure.swift:131-133
#if canImport(Darwin)
    internal import Darwin
#elseif canImport(Glibc)
    internal import Glibc
#elseif canImport(Musl)
    internal import Musl
#endif
```

**Impact**: Per [PLAT-ARCH-008], L3 consumers should import `Kernel`, not platform C libraries. The `Kernel.Failure.message(for:)` calls `strerror()` directly — this should be provided by the error primitives or platform packages.

**Investigation needed**: Determine exactly which symbols from Darwin/Glibc/WinSDK are used that aren't already available through the Kernel re-export chain. The write APIs may actually only need them for type annotations that could be avoided.

**Rules violated**: [PLAT-ARCH-008] — consumer import rule.

---

### HIGH

#### H-1: `Kernel.Thread.Barrier` uses raw Mutex/Condition instead of Synchronization<1>

**File**: `Kernel.Thread.Barrier.swift:34-35`

```swift
private let mutex = Kernel.Thread.Mutex()
private let condition = Kernel.Thread.Condition()
```

**Description**: `Gate` correctly uses `SingleSync()` (line 45 of `Kernel.Thread.Gate.swift`), but `Barrier` bypasses the `Synchronization<N>` abstraction and uses raw primitives directly. This creates an inconsistency and loses waiter tracking capabilities.

**Rules violated**: [IMPL-INTENT] — mechanism visible where `Synchronization<1>` already expresses the intent.

---

#### H-2: Streaming write `fill` closure uses untyped `throws`

**File**: `Kernel.File.Write.Streaming+API.swift:123`

```swift
fill: (inout [UInt8]) throws -> Int
```

**Description**: Bare `throws` violates [API-ERR-001]. The closure should use typed throws. Since the fill is user-provided, a reasonable signature would be `throws(some Error)` or a generic `throws(E)`.

**Rules violated**: [API-ERR-001] — all throwing functions must use typed throws.

---

#### H-3: `try!` in default parameter of Job.Queue init

**File**: `Kernel.Thread.Executor.Job.Queue.swift:18`

```swift
init(initialCapacity: Index<Kernel.Thread.Executor.Job>.Count = try! .init(64)) {
```

**Description**: `try!` in a default parameter expression traps at the call site if the initialization fails. `Count.init(64)` should never fail for a positive value, but `try!` is still an unrecoverable trap path that should be replaced with a non-throwing construction (e.g., a static constant or unchecked init).

**Rules violated**: [IMPL-INTENT] — mechanism (failable init + forced try) where intent (fixed capacity) should be expressed directly.

---

#### H-4: `Optional._take()` is misplaced in swift-kernel

**File**: `Optional+take.swift`

**Description**: This extension provides a general-purpose `_take()` on `Optional where Wrapped: ~Copyable`. It's not kernel-specific — it's a language-level utility for consuming move-only optionals. It should live in swift-ownership-primitives or a similar primitives package.

The file itself documents this: *"This is a stopgap utility until Swift stdlib provides equivalent functionality."*

**Rules violated**: Layer placement — general utilities shouldn't be defined in a domain-specific L3 package.

---

#### H-5: TOCTOU-prone rename pattern via `try?` + post-verification

**Files**:
- `Kernel.File.Write.Atomic+API.swift:443-458`
- `Kernel.File.Write.Streaming+API.swift:632-648`

```swift
private static func atomicRename(from source: String, to dest: String) throws(Error) {
    try? Kernel.Path.scope(source, dest) { sourcePath, destPath in
        do {
            try Kernel.File.Move.move(from: sourcePath, to: destPath)
        } catch {
            // Error handled below
        }
    }
    // Verify rename succeeded
    if !fileExists(dest) {
        throw .renameFailed(...)
    }
}
```

**Description**: The actual rename error is silently swallowed (`try?` + empty catch), then a `stat` check verifies the result. This:
1. Loses the actual platform error code
2. Is TOCTOU-racy — another process could create/delete the dest between rename and stat
3. The post-verification `fileExists(dest)` could return `true` for a file that existed before the rename (if rename actually failed)

**Recommendation**: Propagate the actual error from `Kernel.File.Move.move`. The verification should be the error's error code, not a separate stat.

**Rules violated**: [IMPL-INTENT] — mechanism (stat verification) masking intent (rename error propagation).

---

#### H-6: `Kernel.Continuation.Context` state uses raw `UInt8` instead of enum

**File**: `Kernel.Continuation.Context.swift:56-63`

```swift
private let state: Atomic<UInt8>

public static var pending: UInt8 { 0 }
public static var completed: UInt8 { 1 }
public static var cancelled: UInt8 { 2 }
public static var failed: UInt8 { 3 }
```

**Description**: Four states represented as raw UInt8 computed properties. This should be an enum with `AtomicRepresentable` conformance, or at minimum an `@frozen` enum backed by UInt8.

**Rules violated**: [API-IMPL-003] — use enums for states, not boolean/integer flags.

---

#### H-7: `atomicRenameNoClobber` has redundant existence check (both files)

**Files**:
- `Kernel.File.Write.Atomic+API.swift:461-497`
- `Kernel.File.Write.Streaming+API.swift:650-687`

```swift
private static func atomicRenameNoClobber(...) throws(Error) {
    // Check if destination exists first      ← TOCTOU: another process can create it here
    if fileExists(dest) {
        throw .destinationExists(path: dest)
    }
    try? Kernel.Path.scope(source, dest) { ... }   ← actual noClobber rename
    // Verify the move succeeded              ← second TOCTOU window
    if !fileExists(dest) || fileExists(source) {
```

**Description**: The `Kernel.File.Move.noClobber` syscall already handles the existence check atomically (via `renameat2(RENAME_NOREPLACE)` on Linux, `renamex_np(RENAME_EXCL)` on macOS). The pre-check `fileExists(dest)` is redundant and introduces a TOCTOU window.

**Rules violated**: [IMPL-INTENT] — the intent (no-clobber rename) is already expressed by the syscall.

---

### MEDIUM

#### M-1: Multiple types per file in Synchronization.swift

**File**: `Kernel.Thread.Synchronization.swift`

**Description**: This 347-line file contains:
- `Kernel.Thread.Synchronization<N>` (lines 38-228)
- `Kernel.Thread.SingleSync` typealias (line 237)
- `Kernel.Thread.DualSync` typealias (line 243)
- `Kernel.Thread.Synchronization.ConditionAccessor` (lines 260-324) — nested struct
- `Kernel.Thread.DualSync.BroadcastAll` (lines 329-340) — nested struct

**Assessment**: `ConditionAccessor` and `BroadcastAll` are nested types, so they could stay as per [API-IMPL-005] exception for nested types. However, the typealiases and the `where N == 2` extension should be in separate files:
- `Kernel.Thread.SingleSync.swift` — typealias
- `Kernel.Thread.DualSync.swift` — typealias
- `Kernel.Thread.Synchronization+DualSync.swift` — `where N == 2` convenience

**Rules violated**: [API-IMPL-005] — one type per file (for typealiases and constrained extensions).

---

#### M-2: Multiple types per file in Worker.swift

**File**: `Kernel.Thread.Worker.swift`

**Description**: Contains both `Worker` struct (lines 50-62) and `Worker.Token` class (lines 81-99). `Token` is a public nested class with its own API surface.

**Assessment**: Per [API-IMPL-005], `Token` should be in `Kernel.Thread.Worker.Token.swift`.

**Rules violated**: [API-IMPL-005].

---

#### M-3: `Kernel.File.Write.Atomic.Options` uses 6 boolean flags

**File**: `Kernel.File.Write.Atomic.Options.swift:17-24`

```swift
public var preservePermissions: Bool
public var preserveOwnership: Bool
public var strictOwnership: Bool
public var preserveTimestamps: Bool
public var preserveExtendedAttributes: Bool
public var preserveACLs: Bool
```

**Assessment**: Six boolean flags for preservation behavior. An `OptionSet` (e.g., `Kernel.File.Write.Atomic.Preservation: OptionSet`) would be more expressive and extensible. `strictOwnership` is particularly problematic — it only applies when `preserveOwnership` is true, creating a hidden dependency.

**Rules violated**: [API-IMPL-003] — prefer enums/option sets over boolean flags.

---

#### M-4: `Kernel.File.Copy.swift:94` uses raw integer `2` for ENOENT

**File**: `Kernel.File.Copy.swift:94`

```swift
code == 2 /* ENOENT */
```

**Description**: Magic number instead of typed error code constant.

**Rules violated**: [IMPL-002] — use typed constants, not raw integers.

---

#### M-5: `Kernel.File.Clone.swift` has extensive `#if os()` conditionals in L3

**File**: `Kernel.File.Clone.swift:60, 72, 96, 109, 130, 167, 185, 192, 212`

**Description**: 9 `#if os()` conditional blocks across three methods (`cloneReflinkOnly`, `cloneWithFallback`, `copyOnly`). Each method has a 3-way or 4-way platform split.

**Assessment**: This is inherent to the unification role — the clone APIs dispatch to platform-specific syscalls (clonefile on macOS, FICLONE on Linux, CopyFileW on Windows). The per-method structure is correct, but the internal helpers (`Clonefile.attempt`, `Ficlone.attempt`, `CopyRange.copy`, `Copy.file`, `Copyfile.clone`, `Copyfile.data`) are called but not visible in the source files read — they may be defined in the primitives layer where they belong.

**Rules violated**: Borderline [PLAT-ARCH-002] — L3 should primarily dispatch, not implement platform-specific logic.

---

#### M-6: `Exports.swift` uses `canImport` instead of `#if os()` for platform identity

**File**: `Exports.swift:21`

```swift
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    @_exported public import POSIX_Kernel
#endif
```

**Description**: Per [PATTERN-004c], `canImport` is for capability detection, `#if os()` is for platform identity. The decision to export POSIX_Kernel is a platform identity decision (POSIX platforms), not a capability check.

**Rules violated**: [PATTERN-004c].

---

#### M-7: `Gate.open()` uses manual lock/unlock with early return

**File**: `Kernel.Thread.Gate.swift:58-65`

```swift
public func open() {
    sync.lock()
    if _isOpen {
        sync.unlock()
        return
    }
    _isOpen = true
    sync.broadcast(condition: 0)
    sync.unlock()
}
```

**Description**: Manual lock/unlock with an early return between them. While correct, this could be expressed with `withLock`:

```swift
public func open() {
    sync.withLock {
        guard !_isOpen else { return }
        _isOpen = true
    }
    sync.broadcast(condition: 0)
}
```

Note: broadcast outside lock is actually preferable (avoids thundering herd under lock), so the current pattern has a valid reason — the broadcast should be outside `withLock`. However, the lock/unlock around the state mutation could still use `withLock`.

**Rules violated**: [IMPL-EXPR-001] — expression-first style.

---

#### M-8: `Kernel.Thread.Executors.swift:49` uses `Int(options.count)` — untyped conversion

**File**: `Kernel.Thread.Executors.swift:49`

```swift
self.executors = (0..<Int(options.count)).map { _ in Executor() }
```

**Description**: `options.count` is `Kernel.Thread.Count` (a `Tagged<Kernel.Thread, Cardinal>`), and `Int(options.count)` does a raw conversion. Per [IMPL-002], typed arithmetic should be used. The `(0..<Int(count)).map` pattern is also imperative — [IMPL-EXPR-003] would prefer a more declarative construction.

**Rules violated**: [IMPL-002], [IMPL-EXPR-003].

---

#### M-9: `Kernel.Thread.Executors.swift:72` uses mixed `UInt64`/`Int` arithmetic

**File**: `Kernel.Thread.Executors.swift:71-72`

```swift
let index = counter.wrappingAdd(1, ordering: .relaxed).oldValue
return executors[Int(index % UInt64(executors.count))]
```

**Description**: `UInt64` atomic counter, `Int` array count, `UInt64` modulo, `Int` conversion for subscript. Multiple untyped conversions.

**Rules violated**: [IMPL-002] — typed arithmetic.

---

#### M-10: `Kernel.Failure.message(for:)` hardcodes MAKELANGID value

**File**: `Kernel.Failure.swift:~150` (Windows code path)

```swift
let langId: DWORD = 0x0400
```

**Description**: Comment says `MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)` but uses a hardcoded hex value instead of the actual macro or a named constant.

**Rules violated**: [IMPL-INTENT] — magic number where intent should be expressed.

---

#### M-11: `Kernel.File.Write.Streaming.Context` is `Sendable` but holds a mutable descriptor

**File**: `Kernel.File.Write.Streaming.Context.swift`

**Description**: `Context` is `Sendable` and holds a `Kernel.Descriptor` (file descriptor). The descriptor is used for write operations from potentially different contexts. If the Context is shared across threads (which `Sendable` allows), concurrent writes to the same fd are undefined behavior.

**Assessment**: Need to verify whether `Context` is actually shared. If it's always used from a single writer, `@unchecked Sendable` with documentation would be more appropriate than unconditional `Sendable`.

---

#### M-12: `syncFile` doesn't distinguish `full` vs `dataOnly` durability

**Files**:
- `Kernel.File.Write.Atomic+API.swift:415-416`
- `Kernel.File.Write.Streaming+API.swift:604-605`

```swift
case .full, .dataOnly:
    try Kernel.File.Flush.flush(fd)
```

**Description**: Both `full` and `dataOnly` call `Kernel.File.Flush.flush()` (fsync). But `dataOnly` should use `fdatasync` (via `Kernel.File.Flush.data()`), which skips metadata sync for better performance. The `Durability` enum distinguishes these cases but the implementation treats them identically.

**Rules violated**: Semantic correctness — the API promises a distinction it doesn't deliver.

---

### LOW

#### L-1: Header comment style inconsistency

**Description**: Some files use the full banner style:
```swift
// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
// ...
// ===----------------------------------------------------------------------===//
```

Others use the minimal style:
```swift
//  Kernel.Thread.Executor.swift
//  swift-kernel
//  Created by ...
```

**Files with minimal header**: Executor, Executors, Executors.Options, Job, Job.Queue, Continuation, Continuation.Context, System.Processor.Count, System.Processor.Physical.Count, System.Memory.Total.

---

#### L-2: `Kernel.Thread.Synchronization.wait(condition:timeout:)` clamps UInt64 to Int64

**File**: `Kernel.Thread.Synchronization.swift:95`

```swift
let clampedNanos = Int64(clamping: nanoseconds)
```

**Description**: The `UInt64` timeout overload clamps to `Int64`. Values above `Int64.max` (~292 years) are silently reduced. This is semantically correct (no one waits 292 years) but the API accepting `UInt64` then clamping internally is misleading. The `Duration` overload is the preferred interface.

---

#### L-3: Missing `@inlinable` on hot-path Synchronization methods

**File**: `Kernel.Thread.Synchronization.swift`

**Description**: `lock()` (line 55), `unlock()` (line 60), `signal()` (line 118), `broadcast()` (line 127) are not marked `@inlinable`. These are thin wrappers around Mutex/Condition methods and are called in tight loops (executor run loop, worker signaling).

---

#### L-4: `Kernel.Thread.Handle.Reference.join()` modifies state without synchronization

**File**: `Kernel.Thread.Handle.Reference.swift:52`

```swift
public func join() {
    guard let handle = inner._take() else {
```

**Description**: `inner._take()` is not synchronized. If `join()` were called from two threads simultaneously (a misuse, but possible since the type is `Sendable`), both could see a non-nil `inner` and race. The precondition catches the second call but not the data race itself.

**Assessment**: The type documents "called exactly once during shutdown" — this is a documentation issue, not a design flaw. Adding `Mutex` would add overhead for a correctness invariant that callers must maintain anyway.

---

#### L-5: `Kernel.File.Write.Atomic.Error` and `Streaming.Error` semantic accessor duplication

**Files**:
- `Kernel.File.Write.Atomic.Error.swift:73-211` (~140 lines)
- `Kernel.File.Write.Streaming.Error.swift:80+` (~140 lines)

**Description**: `isNotFound`, `isPermissionDenied`, `isDestinationExists`, `isReadOnly`, `isNoSpace` are implemented with nearly identical switch statements in both error types. These could potentially be unified via a protocol or shared error code matching.

---

## Per-File Inventory

| File | Types Defined | Issues | Recommendation |
|------|--------------|--------|----------------|
| `Exports.swift` | (re-exports) | M-6: `canImport` vs `os()` | Use `#if os()` for platform identity |
| `Kernel.Thread.spawn.swift` | `Spawn` | None | Clean |
| `Kernel.Thread.trap.swift` | `Trap` | None | Clean |
| `Kernel.Thread.Executor.swift` | `Executor` | None | Clean — well-documented lifecycle |
| `Kernel.Thread.Executors.swift` | `Executors` | M-8, M-9: untyped conversions | Use typed Count iteration |
| `Kernel.Thread.Executors.Options.swift` | `Executors.Options` | None | Clean |
| `Kernel.Thread.Executor.Job.swift` | `Job` (typealias) | None | Clean |
| `Kernel.Thread.Executor.Job.Queue.swift` | `Job.Queue` | H-3: `try!` in default param | Use static constant or unchecked init |
| `Kernel.Thread.Synchronization.swift` | `Synchronization<N>`, `SingleSync`, `DualSync`, `ConditionAccessor`, `BroadcastAll` | M-1: multiple types | Split typealiases and constrained extensions |
| `Kernel.Thread.Worker.swift` | `Worker`, `Token` | M-2: Token in same file | Move Token to own file |
| `Kernel.Thread.Count.swift` | `Count` (typealias) | None | Clean |
| `Kernel.Thread.Gate.swift` | `Gate` | M-7: manual lock/unlock | Minor — early return pattern is valid |
| `Kernel.Thread.Barrier.swift` | `Barrier` | H-1: raw Mutex/Condition | Use `Synchronization<1>` |
| `Kernel.Thread.Affinity.swift` | `AffinityAccessor` | None | Clean — good cross-platform dispatch |
| `Kernel.Thread.Handle+joinChecked.swift` | (extension) | None | Clean |
| `Kernel.Thread.Handle.Reference.swift` | `Reference` | L-4: unsynchronized `_take` | Document single-caller constraint |
| `Kernel.File.Open.swift` | `Configuration` + `open()` | None | Clean |
| `Kernel.File.Clone.swift` | (extensions) | M-5: extensive `#if os()` | Inherent to unification role |
| `Kernel.File.Copy.swift` | (extensions) | M-4: magic number `2` | Use `.POSIX.ENOENT` |
| `Kernel.File.Write.Atomic.swift` | `Atomic` (namespace) | None | Clean |
| `Kernel.File.Write.Atomic.Options.swift` | `Options` | M-3: 6 booleans | Consider `OptionSet` |
| `Kernel.File.Write.Atomic.Strategy.swift` | `Strategy` | None | Clean |
| `Kernel.File.Write.Atomic.Durability.swift` | `Durability` | None | Clean |
| `Kernel.File.Write.Atomic.Commit.Phase.swift` | `Commit.Phase` | None | Clean — well-designed state machine |
| `Kernel.File.Write.Atomic.Commit.swift` | `Commit` (namespace) | None | Clean |
| `Kernel.File.Write.Atomic.Error.swift` | `Error` | L-5: accessor duplication | Consider shared protocol |
| `Kernel.File.Write.Atomic+API.swift` | (extension) | **C-1**: duplication, **C-2**: direct imports, H-5: TOCTOU rename, H-7: redundant check, M-12: sync distinction | Major refactoring needed |
| `Kernel.File.Write.Streaming.swift` | `Streaming` (namespace) | None | Clean |
| `Kernel.File.Write.Streaming.Options.swift` | `Options` | None | Clean |
| `Kernel.File.Write.Streaming.Context.swift` | `Context` | M-11: Sendable + mutable fd | Document usage constraint |
| `Kernel.File.Write.Streaming.Error.swift` | `Error` | L-5: accessor duplication | Consider shared protocol |
| `Kernel.File.Write.Streaming.Commit.Policy.swift` | `Commit.Policy` | None | Clean |
| `Kernel.File.Write.Streaming.Commit.swift` | `Commit` (namespace) | None | Clean |
| `Kernel.File.Write.Streaming.Durability.swift` | `Durability` | None | Clean |
| `Kernel.File.Write.Streaming.Direct.swift` | `Direct` (namespace) | None | Clean |
| `Kernel.File.Write.Streaming.Direct.Strategy.swift` | `Direct.Strategy` | None | Clean |
| `Kernel.File.Write.Streaming.Direct.Options.swift` | `Direct.Options` | None | Clean |
| `Kernel.File.Write.Streaming.Atomic.swift` | `Atomic` (namespace) | None | Clean |
| `Kernel.File.Write.Streaming.Atomic.Strategy.swift` | `Atomic.Strategy` | None | Clean |
| `Kernel.File.Write.Streaming.Atomic.Options.swift` | `Atomic.Options` | None | Clean |
| `Kernel.File.Write.Streaming+API.swift` | (extension) | **C-1**: duplication, **C-2**: direct imports, H-2: untyped throws, H-5: TOCTOU rename, H-7: redundant check, M-12: sync distinction | Major refactoring needed |
| `Kernel.Continuation.swift` | `Continuation` (namespace) | None | Clean |
| `Kernel.Continuation.Context.swift` | `Context` | H-6: raw UInt8 state | Use enum |
| `Kernel.Failure.swift` | `Failure` | **C-2**: direct C imports, M-10: magic number | Route `strerror` through platform package |
| `Kernel.System.Processor.Count.swift` | (extension) | None | Clean |
| `Kernel.System.Processor.Physical.Count.swift` | (extension) | None | Clean |
| `Kernel.System.Memory.Total.swift` | (extension) | None | Clean |
| `Kernel.Lock.Acquire+timeout.swift` | (extension) | None | Clean |
| `Tagged+Kernel.Atomic.Flag.swift` | (extension) | None | Clean |
| `Optional+take.swift` | (extension) | H-4: misplaced | Move to ownership-primitives |
| `Swift.String+Kernel.swift` | (extensions) | None | Clean |

---

## Dependency Utilization Matrix

| Dependency | Import Style | Usage | Assessment |
|-----------|-------------|-------|-----------|
| `Kernel_Primitives` | `@_exported public import` | All Kernel.* base types (descriptors, errors, file ops, paths, threads, memory, events, sockets) | **Fully utilized** — core dependency |
| `Queue_Primitives` | `@_exported public import` | `Deque` for `Executor.Job.Queue` | **Utilized** — single usage is appropriate |
| `Dimension_Primitives` | `@_exported public import` | File offsets, sizes, dimensional arithmetic | **Utilized** — re-exported for consumers |
| `Reference_Primitives` | `@_exported public import` | Not directly referenced in swift-kernel source | **Verify** — may be used by consumers through re-export |
| `Ownership_Primitives` | `public import` (per-file) | `Ownership.Transfer.Cell`, `Ownership.Transfer.Retained` for thread spawn | **Utilized** — 2 files |
| `POSIX_Kernel` | `@_exported public import` (conditional) | EINTR-safe write/flush used by write APIs | **Utilized** |
| `Darwin_Kernel` / `Darwin_System` | `@_exported public import` (conditional) | System info, random | **Utilized** |
| `Linux_Kernel` / `Linux_System` | `@_exported public import` (conditional) | System info, affinity, NUMA, random | **Utilized** |
| `Windows_Kernel` | `@_exported public import` (conditional) | System info, affinity, glob | **Utilized** |
| `Synchronization` (stdlib) | `import` (per-file) | `Atomic<Bool>`, `Atomic<UInt64>`, `Atomic<UInt8>` | **Utilized** — 3 files |
| `Kernel_String_Primitives` | `public import` | `Kernel.String` type | **Utilized** — String+Kernel extensions |
| `String_Primitives` | `public import` | String conversion utilities | **Utilized** — String+Kernel extensions |
| `Cardinal_Primitives` | (via Kernel_Primitives) | `Index<T>.Count` for Job.Queue | **Utilized** |
| `System_Primitives` | Declared in Package.swift | Not directly imported in source | **Verify** — may come through re-export chain |
| `Binary_Primitives` | Declared in Package.swift | Not directly imported in source | **Verify** — may come through re-export chain |

**Findings**:
- `Reference_Primitives` — No direct usage found in swift-kernel source files. Verify whether it's used by downstream consumers through re-export.
- `System_Primitives` / `Binary_Primitives` — Listed as Package.swift dependencies but not directly imported. May arrive via transitive re-export from Kernel_Primitives.

---

## Platform Unification Assessment

### Unification Quality: **Good**

swift-kernel provides clean cross-platform unification for:

| Feature | Darwin | Linux | Windows | Unification Point |
|---------|--------|-------|---------|-------------------|
| **Thread creation** | pthread_create | pthread_create | _beginthreadex | `Kernel.Thread.create()` (primitives) |
| **Thread affinity** | Unsupported (.none) | pthread_setaffinity_np | SetThreadAffinityMask | `Kernel.Thread.AffinityAccessor` |
| **Processor count** | sysctl hw.physicalcpu | sysconf _SC_NPROCESSORS_ONLN | GetSystemInfo | `Kernel.System.Processor.count` |
| **Physical cores** | sysctl hw.physicalcpu | Falls back to logical | Falls back to logical | `Kernel.System.Processor.Physical.count` |
| **Total memory** | sysctl hw.memsize | sysinfo().totalram | GlobalMemoryStatusEx | `Kernel.System.Memory.total` |
| **File clone** | clonefile/copyfile | FICLONE/copy_file_range | CopyFileW | `Kernel.File.Clone.clone()` |
| **Atomic write** | fsync/rename | fsync/rename | FlushFileBuffers/MoveFileExW | `Kernel.File.Write.Atomic.write()` |
| **Random** | arc4random_buf | getrandom(2) | BCryptGenRandom | `Kernel.Random.fill()` (primitives) |

### Platform Conditional Placement

| File | `#if` Style | Assessment |
|------|------------|-----------|
| `Exports.swift` | `canImport(Darwin/Glibc/Musl)` | M-6: Should use `#if os()` |
| `Kernel.Thread.Affinity.swift` | `canImport(Darwin_Kernel)`, `os(Linux)`, `os(Windows)` | Mixed — `canImport` for imports, `#if os()` for dispatch. Correct. |
| `Kernel.File.Clone.swift` | `os(macOS)`, `os(Linux)`, `os(Windows)` | Correct — platform identity |
| `Kernel.File.Write.Atomic+API.swift` | `canImport(Darwin/Glibc/Musl)` | C-2: Direct C imports |
| `Kernel.File.Write.Streaming+API.swift` | `canImport(Darwin/Glibc/Musl)` | C-2: Direct C imports |
| `Kernel.System.*.swift` | `canImport(Darwin)`, `canImport(Glibc/Musl)`, `os(Windows)` | Mixed — imports use `canImport`, dispatch uses `os()`. Acceptable. |
| `Kernel.Lock.Acquire+timeout.swift` | `os(macOS) || os(iOS) || ... || os(Windows)` | Correct but verbose — could use `!os(WASI)` or similar |
| `Kernel.Failure.swift` | `!os(Windows)`, `canImport(Darwin/Glibc/Musl)` | C-2: Direct C imports |

### Consumer Experience

Consumers import `Kernel` and get a complete, platform-independent API. No `#if os()` needed at the consumer level for any of the unified features. This is the correct outcome per [PLAT-ARCH-008].

---

## Recommended Migration Order

### Phase 1: Code Duplication (C-1) — Highest impact

1. Extract shared write helpers into `Kernel.File.Write+Helpers.swift`:
   - `resolvePaths`, `posixParentDirectory`, `windowsParentDirectory`, `normalizeWindowsPath`
   - `fileName`, `fileExists`, `randomToken`, `hexEncode`
   - `writeAll`, `writeAllRaw`, `syncFile`, `closeFile`
   - `atomicRename`, `atomicRenameNoClobber`, `syncDirectory`
2. Have both Atomic+API and Streaming+API call the shared helpers.
3. Fix the TOCTOU rename pattern (H-5, H-7) during extraction.
4. Fix `syncFile` to distinguish `full` vs `dataOnly` (M-12) during extraction.

### Phase 2: Layering Fixes (C-2)

1. Identify exactly which C symbols are used from Darwin/Glibc/WinSDK.
2. For `strerror()` — add `Kernel.Error.Code.message` to error primitives or platform packages.
3. For `FormatMessageW` — add to Windows error primitives.
4. Remove direct C imports from L3 files.

### Phase 3: Type-Level Fixes (H-1 through H-7)

1. H-1: Refactor `Barrier` to use `Synchronization<1>`
2. H-2: Add typed throws to `fill` closure (requires API design decision for user-facing closures)
3. H-3: Replace `try!` with static constant for default capacity
4. H-4: Move `Optional._take()` to ownership-primitives (cross-package change)
5. H-6: Convert `Context` state to enum with `AtomicRepresentable`

### Phase 4: Code Organization (M-1, M-2)

1. Split Synchronization typealiases/extensions into separate files
2. Move `Worker.Token` to its own file

### Phase 5: Minor Improvements (M-3 through M-12, LOW)

1. M-3: Consider `OptionSet` for preservation flags
2. M-4: Replace magic `2` with `.POSIX.ENOENT`
3. M-8, M-9: Typed arithmetic in Executors
4. Remaining LOW items as time permits
