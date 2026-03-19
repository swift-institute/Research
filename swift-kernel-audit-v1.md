# swift-kernel Audit — /implementation + /naming

<!--
---
version: 1.0.0
last_updated: 2026-03-19
status: INVENTORY
tier: 2
---
-->

## Context

Audit of `swift-kernel` (Layer 3, swift-foundations) strictly against the /implementation and /naming skills. 63 source files, single module (Kernel).

**Package**: `/Users/coen/Developer/swift-foundations/swift-kernel/`

## Summary

| Severity | Count | Primary themes |
|----------|-------|----------------|
| CRITICAL | 0 | — |
| HIGH | 5 | .rawValue at call sites (1), compound method names (28 methods across 4 files), `try!` on known-valid values (2) |
| MEDIUM | 11 | Compound names in error enums (~31 cases), compound names with WORKAROUND annotations (6), intermediate variables for error shuttling (3), preconditions where typed throws fit (10+), typed-count boundary break (1) |
| LOW | 8 | Preconditions in deinit (2), `== false` instead of `!` (2), minor intermediates (2), `rawValue` in description (1), unreachable catch clauses (2) |

**Clean files**: 41 of 63 (65%) have zero findings.

---

## HIGH Findings

### H-1: `.rawValue` at call site for comparison [IMPL-004]

**File**: `Kernel.File.Write.Atomic.Commit.Phase.swift:64,69`

```swift
public var published: Bool { self.rawValue >= Self.renamedPublished.rawValue }
public var durabilityAttempted: Bool { self.rawValue >= Self.flushed.rawValue }
```

The type already has `Comparable` (line 74). Should be `self >= .renamedPublished`.

### H-2: Compound method names — File write shared helpers [API-NAME-002]

**File**: `Kernel.File.Write+Shared.swift` — 14 compound names:

`resolvePaths`, `normalizeWindowsPath`, `windowsParentDirectory`, `posixParentDirectory`, `fileExists`, `randomToken`, `hexEncode`, `writeAll`, `writeAllRaw`, `syncFile`, `closeFile`, `atomicRename`, `atomicRenameNoClobber`, `syncDirectory`

All `internal`. Nested accessor style (e.g., `sync.file()`, `rename.atomic()`) would conform.

### H-3: Compound method names — File operations [API-NAME-002]

**File**: `Kernel.File.Clone.swift` — 6: `cloneReflinkOnly`, `cloneWithFallback`, `copyOnly`, `openSource`, `createDestination`, `getSize`

**File**: `Kernel.File.Copy.swift` — 5: `getSourceStats`, `handleDestination`, `cloneFile`, `copySymlink`, `copyAttributes`

**File**: `Kernel.File.Write.Atomic+API.swift` — 3: `statIfExists`, `createTempFileWithRetry`, `applyMetadata`

### H-4: `Int(bitPattern:)` at call site [IMPL-010]

**File**: `Kernel.Thread.Count.swift:33`

```swift
public init(_ count: Kernel.Thread.Count) { self = Int(bitPattern: count) }
```

This IS a boundary overload (Int.init extension), so it's the correct location for the conversion. Reclassify as **acceptable** — this is the boundary, not a call site.

### H-5: `try!` for compile-time-known values [IMPL-030]

**File**: `Kernel.Thread.Executor.Job.Queue.swift:20` — `try! .init(64)`
**File**: `Kernel.Thread.Executors.Options.swift:21-22` — `try! Kernel.Thread.Count(4)`

Both construct typed counts from compile-time-known literals. Should use static constants or literal conformances.

---

## MEDIUM Findings

### M-1: Compound names in Streaming.Error enum [API-NAME-002]

**File**: `Kernel.File.Write.Streaming.Error.swift` — 14 compound case names + 8 compound `is*` properties:

Cases: `parentVerificationFailed`, `fileCreationFailed`, `writeFailed`, `syncFailed`, `closeFailed`, `renameFailed`, `destinationExists`, `directorySyncFailed`, `durabilityNotGuaranteed`, `directorySyncFailedAfterCommit`, `invalidState`, `randomGenerationFailed`, `userError`, `invalidFillResult`

Properties: `isNotFound`, `isPermissionDenied`, `isDestinationExists`, `isReadOnly`, `isNoSpace`, `isUserError`, `isDurabilityNotGuaranteed`, `isInvalidState`

**Note**: Error enum case naming is pervasive across the kernel. If remediated, this should be a coordinated sweep, not piecemeal.

### M-2: Compound names with WORKAROUND annotations [API-NAME-002]

**File**: `Kernel.Thread.Synchronization.swift` — `broadcastAll`, `waitTracked`, `signalIfWaiters`, `broadcastIfWaiters`
**File**: `Kernel.Thread.Synchronization.Channel.swift` — re-exposes same compound names
**File**: `Kernel.Thread.Handle+joinChecked.swift` — `joinChecked`

All annotated with structured `// WORKAROUND:` comments tracking [API-NAME-002] with removal conditions. Known accepted deviations blocked on property-primitives adoption.

### M-3: Intermediate variables for error shuttling [IMPL-030]

**File**: `Kernel.File.Write+Shared.swift:311-331,342-367` — `var moveError: (any Swift.Error)?` shuttles errors out of `Kernel.Path.scope` closures. Same at `Kernel.File.Copy.swift:186`.
**File**: `Kernel.File.Write.Atomic+API.swift:228-249` — `var result: Result<Kernel.Descriptor, any Swift.Error>` same pattern.

Root cause: `Kernel.Path.scope` closures don't propagate typed throws. The `(any Swift.Error)?` intermediate erases the concrete error type.

### M-4: Streaming API implementation patterns [IMPL-INTENT]

**File**: `Kernel.File.Write.Streaming+API.swift`
- Lines 148-169: `while true` + manual `break` produce loop
- Lines 171-185: manual pointer extraction from buffer
- Lines 303-337: nested if/switch for commit policy dispatch

### M-5: Compound names in Streaming.Context [API-NAME-002]

**File**: `Kernel.File.Write.Streaming.Context.swift:45,48,51,58` — `tempPathString`, `resolvedPathString`, `parentPathString`, `isAtomic`

### M-6: Compound names in strategy enums [API-NAME-002]

**File**: `Kernel.File.Write.Streaming.Atomic.Strategy.swift:18,26` — `replaceExisting`, `noClobber`
**File**: `Kernel.File.Write.Streaming.Durability.swift:23` — `dataOnly`
**File**: `Kernel.File.Write.Streaming.Direct.Options.swift:34` — `expectedSize`

### M-7: Preconditions where typed throws would fit [IMPL-040]

**File**: `Kernel.Thread.Synchronization.swift` — 10 preconditions for condition index bounds checking (lines 79, 94, 110, 118, 127, 155, 175-176, 203-204, 224-225, 242-243). Also `precondition(N >= 1)` at line 47.
**File**: `Kernel.Thread.Barrier.swift:41` — `precondition(count >= 1)`

The condition index bounds are caller-controllable, so typed throws per [IMPL-040] would be more composable.

### M-8: Typed-count boundary break [IMPL-002]

**File**: `Kernel.Thread.Executors.swift:49,57` — `Int(options.count)` raw conversion at call site; `count` property returns `Int` instead of `Kernel.Thread.Count`.

### M-9: Duplicated write loops [IMPL-033]

**File**: `Kernel.File.Write+Shared.swift` — `writeAll` (lines 154-203) and `writeAllRaw` (lines 205-253) implement identical partial-write retry loops. Only difference is `Span<UInt8>` vs `UnsafeRawBufferPointer` input.

### M-10: Package.swift — Missing direct dependencies

- `Ownership_Primitives` imported in `Kernel.Thread.Executor.swift:8` and `Kernel.Thread.spawn.swift:12` but not a declared product dependency
- `Kernel_String_Primitives` and `String_Primitives` imported in `Swift.String+Kernel.swift` via transitive resolution only

### M-11: Streaming+API intermediate variables [IMPL-030]

**File**: `Kernel.File.Write.Streaming+API.swift` — `let pathString = Swift.String(path)` repeated at lines 66-67, 87-88, 105-106, 138-139 (4 instances). Also `baseName` + `random` intermediates at lines 399-400.

---

## LOW Findings

| ID | File:Line | Description | Rule |
|----|-----------|-------------|------|
| L-1 | `Kernel.Thread.Executor.swift:84-89` | Precondition in deinit | [IMPL-040] |
| L-2 | `Kernel.Thread.Handle.Reference.swift:62-65` | Precondition in deinit | [IMPL-040] |
| L-3 | `Kernel.Thread.Worker.swift:132`, `Handle+joinChecked.swift:31` | `isCurrent == false` instead of `!isCurrent` | [IMPL-INTENT] |
| L-4 | `Kernel.Thread.Synchronization.swift:95` | Intermediate `clampedNanos` | [IMPL-030] |
| L-5 | `Kernel.Process.ID+CustomStringConvertible.swift:15` | `.rawValue` in description | [IMPL-002] |
| L-6 | `Kernel.File.Write+Shared.swift:192-193,242-243` | Unreachable `catch let error as Kernel.File.Write.Error` clauses | Dead code |
| L-7 | `Kernel.File.Write.Atomic+API.swift:351-352` | No-op metadata preservation flags silently discarded | Documentation |
| L-8 | `Kernel.File.Write+Shared.swift:112-133` | `randomToken` empty-string sentinel pattern | [IMPL-INTENT] |

---

## Per-File Inventory

### Clean Files (41 of 63)

| File | Types | Notes |
|------|-------|-------|
| Exports.swift | re-exports | Clean |
| Kernel.File.Write.swift | `Kernel.File.Write` namespace | Clean |
| Kernel.File.Write.Error.swift | `Kernel.File.Write.Error` | Clean |
| Kernel.File.Write.Atomic.swift | namespace | Clean |
| Kernel.File.Write.Atomic.Error.swift | `Kernel.File.Write.Atomic.Error` | Clean |
| Kernel.File.Write.Atomic.Options.swift | `Kernel.File.Write.Atomic.Options` | Clean |
| Kernel.File.Write.Atomic.Strategy.swift | `Kernel.File.Write.Atomic.Strategy` | Clean |
| Kernel.File.Write.Atomic.Durability.swift | `Kernel.File.Write.Atomic.Durability` | Clean |
| Kernel.File.Write.Atomic.Ownership.swift | `Kernel.File.Write.Atomic.Ownership` | Clean |
| Kernel.File.Write.Atomic.Preservation.swift | `Kernel.File.Write.Atomic.Preservation` | Clean |
| Kernel.File.Write.Atomic.Commit.swift | namespace | Clean |
| Kernel.File.Write.Streaming.swift | namespace | Clean |
| Kernel.File.Write.Streaming.Options.swift | `...Options` | Clean |
| Kernel.File.Write.Streaming.Commit.swift | namespace | Clean |
| Kernel.File.Write.Streaming.Commit.Policy.swift | `...Policy` | Clean |
| Kernel.File.Write.Streaming.Atomic.swift | namespace | Clean |
| Kernel.File.Write.Streaming.Atomic.Options.swift | `...Options` | Clean |
| Kernel.File.Write.Streaming.Direct.swift | namespace | Clean |
| Kernel.File.Write.Streaming.Direct.Strategy.swift | `...Strategy` | Clean |
| Kernel.File.Open.swift | `...Configuration` | Clean |
| Kernel.Thread.Affinity.swift | extension | Clean |
| Kernel.Thread.DualSync.swift | typealias | Clean |
| Kernel.Thread.DualSync.Broadcast.swift | `...Broadcast` | Clean |
| Kernel.Thread.Executor.Job.swift | typealias | Clean |
| Kernel.Thread.Gate.swift | `...Gate` | Clean |
| Kernel.Thread.SingleSync.swift | typealias | Clean |
| Kernel.Thread.Worker.Token.swift | `...Token` | Clean |
| Kernel.Thread.spawn.swift | `...Spawn` | Clean |
| Kernel.Thread.trap.swift | `...Trap` | Clean |
| Kernel.Continuation.swift | namespace | Clean |
| Kernel.Continuation.Context.swift | `...Context` + nested `State` | Clean |
| Kernel.Failure.swift | `Kernel.Failure` | Clean (C interop intermediates justified) |
| Kernel.Lock.Acquire+timeout.swift | extension | Clean |
| Kernel.System.Memory.Total.swift | extension | Clean |
| Kernel.System.Processor.Count.swift | extension | Clean |
| Kernel.System.Processor.Physical.Count.swift | extension | Clean |
| Optional+take.swift | extension | Clean |
| Tagged+Kernel.Atomic.Flag.swift | extension | Clean (this IS the rawValue forwarding fix) |
| Kernel.File.Write.Durability.swift | `...Durability` + 2 bridging extensions | Borderline [API-IMPL-005] |
| Kernel.Thread.Handle.Reference.swift | `...Reference` | L-2 only |
| Kernel.Thread.Worker.swift | `...Worker` | L-3 only |

### Files with Findings (22 of 63)

| File | Findings |
|------|----------|
| Kernel.File.Write+Shared.swift | H-2, M-3, M-9, L-6, L-8 (14 compound names, error shuttling, duplicated loops) |
| Kernel.File.Write.Atomic+API.swift | H-3, M-3, L-7 (3 compound names, error shuttling, no-op flags) |
| Kernel.File.Write.Atomic.Commit.Phase.swift | H-1 (.rawValue comparison) |
| Kernel.File.Clone.swift | H-3 (6 compound names) |
| Kernel.File.Copy.swift | H-3, M-3 (5 compound names, error shuttling) |
| Kernel.File.Write.Streaming.Error.swift | M-1 (14 compound cases + 8 compound properties) |
| Kernel.File.Write.Streaming+API.swift | M-4, M-11 (mechanism patterns, intermediates) |
| Kernel.File.Write.Streaming.Context.swift | M-5 (4 compound property names) |
| Kernel.File.Write.Streaming.Atomic.Strategy.swift | M-6 (2 compound cases) |
| Kernel.File.Write.Streaming.Durability.swift | M-6 (1 compound case) |
| Kernel.File.Write.Streaming.Direct.Options.swift | M-6 (1 compound property) |
| Kernel.Thread.Synchronization.swift | M-2, M-7 (compound names w/ WORKAROUND, preconditions) |
| Kernel.Thread.Synchronization.Channel.swift | M-2 (re-exposed compound names) |
| Kernel.Thread.Handle+joinChecked.swift | M-2, L-3 (compound name w/ WORKAROUND) |
| Kernel.Thread.Count.swift | H-4 → reclassified acceptable (IS the boundary) |
| Kernel.Thread.Executor.Job.Queue.swift | H-5 (try!) |
| Kernel.Thread.Executors.swift | M-8 (typed-count break) |
| Kernel.Thread.Executors.Options.swift | H-5 (try!) |
| Kernel.Thread.Executor.swift | L-1 |
| Kernel.Thread.Handle.Reference.swift | L-2 |
| Kernel.Thread.Worker.swift | L-3 |
| Kernel.Process.ID+CustomStringConvertible.swift | L-5 |

---

## Key Themes

### 1. Compound method names are the dominant issue

~56 compound method/property names across the file write subsystem (`internal` helpers), error enums, and thread synchronization. The thread sync compounds are tracked with WORKAROUND annotations. The file write helpers are all `internal` but pervasive.

### 2. Error shuttling through `Kernel.Path.scope`

3 sites use `var error: (any Swift.Error)?` to shuttle errors out of `Kernel.Path.scope` closures because the closure doesn't propagate typed throws. Root cause is in `Kernel.Path.scope`'s API design.

### 3. Typed throws and error enums are clean

Zero bare `throws` violations. All error types are properly nested. The typed throws convention is fully adopted.

### 4. Type naming is clean

Zero [API-NAME-001] violations. All types use `Nest.Name`. The namespace hierarchy is well-structured.

### 5. One-type-per-file is clean

Zero violations. All 63 files contain at most one primary type declaration.

---

## Cross-References

- Skills: **implementation** ([IMPL-*], [PATTERN-*]), **naming** ([API-NAME-*])
- Prior: This is the first audit of swift-kernel against these skills.
