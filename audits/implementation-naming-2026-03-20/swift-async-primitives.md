# swift-async-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Scope**: 54 source files across 6 modules
**Rules**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [IMPL-033], [PATTERN-017], [API-IMPL-005], [API-ERR-001]

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 0 |
| HIGH | 2 |
| MEDIUM | 4 |
| LOW | 3 |
| INFO | 2 |

The package has good Nest.Name discipline for types but several compound method/property names and a few typed-throws gaps. The `_ChannelError` workaround and `popEligible`/`reapFlagged` compound names are documented with tracking comments.

## Findings

### [ASYNC-001] `_ChannelError` prefixed with underscore and not nested
**Rule**: [API-NAME-001]
**Severity**: HIGH
**File**: `Sources/Async Channel Primitives/Async.Channel.Error.swift`, lines 13-14, 21
**Finding**: `Async._ChannelError` is defined at the `Async` level with a leading underscore and a compound name (`ChannelError`). The comment explains this works around a Swift compiler IRGen crash with typed throws + async + nested generic error types. `Async.Channel.Error` is a typealias to `Async._ChannelError`.
**Mitigation**: Documented workaround for compiler bug. The public API surface uses `Async.Channel<Element>.Error` which is clean. The `_ChannelError` name is the workaround artifact.

### [ASYNC-002] `popEligible` and `reapFlagged` are compound method names
**Rule**: [API-NAME-002]
**Severity**: HIGH (documented workaround)
**Files**: `Sources/Async Waiter Primitives/Queue.Fixed+Async.Waiter.swift`, lines 42-43, 71-72; `Sources/Async Waiter Primitives/Queue+Async.Waiter.swift`, lines 24-25, 53-54
**Finding**: `popEligible(flaggedInto:)` and `reapFlagged(into:)` are compound identifiers. Both have WORKAROUND comments: "Property.View cannot express method-level `where Element ==` constraints."
**Mitigation**: Tracked with "WHEN TO REMOVE: When Swift supports constrained Property.View extensions with same-type requirements." Acceptable as documented workaround.

### [ASYNC-003] `Async.Channel.Error.swift` filename is `File.swift` in header comment
**Rule**: [API-IMPL-005]
**Severity**: LOW
**File**: `Sources/Async Channel Primitives/Async.Channel.Error.swift`, line 2
**Finding**: The file header comment says `File.swift` instead of `Async.Channel.Error.swift`. This is a cosmetic issue in the file header, not a structural violation.

### [ASYNC-004] `Async.Channel.Bounded.State` file contains multiple nested types
**Rule**: [API-IMPL-005]
**Severity**: MEDIUM
**File**: `Sources/Async Channel Primitives/Async.Channel.Bounded.State.swift`
**Finding**: This single file contains `Async.Channel.Bounded.State`, `Async.Channel.Bounded.State.Phase`, `Async.Channel.Bounded.State.Sender`, `Async.Channel.Bounded.State.Receiver`, `Async.Channel.Bounded.State.Send`, `Async.Channel.Bounded.State.Send.Action`, `Async.Channel.Bounded.State.Send.Cancel`, `Async.Channel.Bounded.State.Receive`, `Async.Channel.Bounded.State.Receive.Action`, `Async.Channel.Bounded.State.Receive.Cancel`, `Async.Channel.Bounded.State.Close`. This is 11+ types in one file (523 lines).
**Recommendation**: Split into `Async.Channel.Bounded.State.swift` (core), `Async.Channel.Bounded.State.Send.swift`, `Async.Channel.Bounded.State.Receive.swift`, `Async.Channel.Bounded.State.Close.swift`.

### [ASYNC-005] `Async.Channel.Unbounded.State` file contains multiple nested types
**Rule**: [API-IMPL-005]
**Severity**: MEDIUM
**File**: `Sources/Async Channel Primitives/Async.Channel.Unbounded.State.swift`
**Finding**: Contains `Async.Channel.Unbounded.State`, `Async.Channel.Unbounded.State.Slot`, `Async.Channel.Unbounded.State.Send`, `Async.Channel.Unbounded.State.Send.Action`, `Async.Channel.Unbounded.State.Receive`, `Async.Channel.Unbounded.State.Receive.Step`, `Async.Channel.Unbounded.State.Receive.Stop`, `Async.Channel.Unbounded.State.Close`. 8+ types in one file (235 lines).
**Recommendation**: Split into separate files per major nested type.

### [ASYNC-006] `Async.Broadcast.State` file contains multiple nested types
**Rule**: [API-IMPL-005]
**Severity**: MEDIUM
**File**: `Sources/Async Broadcast Primitives/Async.Broadcast.State.swift`
**Finding**: Contains `Async.Broadcast.State`, `Async.Broadcast.NextIndex`, `Async.Broadcast.SubscriberID`, `Async.Broadcast.Is`. Four types/structs in one file. `NextIndex`, `SubscriberID`, and `Is` are separate types at the `Async.Broadcast` level, not nested in `State`.
**Recommendation**: Each should have its own file: `Async.Broadcast.NextIndex.swift`, `Async.Broadcast.SubscriberID.swift`, `Async.Broadcast.Is.swift`.

### [ASYNC-007] `Async.Completion` contains deeply nested types in one file
**Rule**: [API-IMPL-005]
**Severity**: MEDIUM
**File**: `Sources/Async Primitives Core/Async.Completion.swift`
**Finding**: Contains `Async.Completion`, `Async.Completion.Result` (typealias), `Async.Completion.Error`, `Async.Completion.State`, `Async.Completion.Transition`, `Async.Completion.Transition.Error`. Six types in one file (294 lines).
**Recommendation**: Split `Async.Completion.Error.swift`, `Async.Completion.State.swift`, `Async.Completion.Transition.swift`.

### [ASYNC-008] `allocateHole`-style compound not present in async (clean)
**Rule**: [API-NAME-002]
**Severity**: N/A (PASS for most API)
**Finding**: Most public API uses clean names: `send(_:)`, `receive()`, `subscribe()`, `fulfill(_:)`, `arrive()`, `publish(_:)`, `take()`, `push(_:)`, `next()`, `finish()`, `close()`. The compound violations are limited to the waiter queue extensions (ASYNC-002).

### [ASYNC-009] `beginShutdown()` and `completeShutdown()` are compound method names
**Rule**: [API-NAME-002]
**Severity**: LOW
**File**: `Sources/Async Primitives Core/Async.Lifecycle.swift`, lines 117, 138
**Finding**: `beginShutdown()` and `completeShutdown()` are compound identifiers. Could be `shutdown.begin()` and `shutdown.complete()` via nested accessor. Since `Async.Lifecycle.State` is a simple enum value type used inside locks, the overhead of a nested accessor wrapper is not justified.

### [ASYNC-010] `isFulfilled`, `isFinished`, `isOpen`, `isReleased`, `isShuttingDown`, `isShutdownComplete` compound properties
**Rule**: [API-NAME-002]
**Severity**: LOW
**File**: Multiple files (Async.Promise, Async.Bridge, Async.Barrier, Async.Lifecycle)
**Finding**: Boolean predicates like `isFulfilled`, `isFinished`, `isOpen`, `isReleased`, `isShuttingDown`, `isShutdownComplete` are compound identifiers. These are idiomatic Swift for Boolean properties and follow stdlib convention (`isEmpty`, `isContiguousStorage`). Enforcing decomposition (e.g., `lifecycle.shutdown.isComplete`) adds ceremony without clarity for simple Boolean state queries.

### [ASYNC-011] `Async.Broadcast` uses untyped `throws` in AsyncIteratorProtocol conformance
**Rule**: [API-ERR-001]
**Severity**: INFO
**File**: `Sources/Async Broadcast Primitives/Async.Broadcast.swift`, line 240
**Finding**: `async throws(Async.Broadcast<Element>.Error) -> Element?` -- this IS typed throws. Clean pass.

### [ASYNC-012] `Async.Channel.Bounded.Sender.send` and `Async.Channel.Bounded.Receiver.receive` use typed throws
**Rule**: [API-ERR-001]
**Severity**: INFO (PASS)
**Finding**: All channel operations use `throws(Async.Channel<Element>.Error)`. All `Async.Completion` methods use `throws(Transition.Error)`. Typed throws compliance is excellent throughout the async package.

## Clean Passes

| Rule | Status |
|------|--------|
| [API-NAME-001] Nest.Name | PASS -- Types: `Async.Mutex`, `Async.Promise`, `Async.Barrier`, `Async.Bridge`, `Async.Channel.Bounded`, `Async.Channel.Unbounded`, `Async.Broadcast`, `Async.Timer.Wheel`, `Async.Waiter.Flag`, `Async.Waiter.Entry`, `Async.Waiter.Resumption`, `Async.Waiter.Queue`, `Async.Lifecycle.State`, `Async.Precedence`, `Async.Publication`, `Async.Completion`, `Async.Continuation`, `Async.Callback`. One exception: `Async._ChannelError` (ASYNC-001). |
| [IMPL-002] No .rawValue at call sites | PASS -- Zero `.rawValue` occurrences in all 54 files. |
| [PATTERN-017] .rawValue confined to boundary | PASS -- No `.rawValue` usage. |
| [IMPL-010] Int(bitPattern:) boundary only | PASS -- No `Int(bitPattern:)` usage in async package. |
| [API-ERR-001] Typed throws | PASS -- All throwing functions use typed throws (`throws(Error)`, `throws(Transition.Error)`, `throws(Async.Channel<Element>.Error)`, `throws(Async.Broadcast<Element>.Error)`). |

## Overall Assessment

swift-async-primitives demonstrates strong typed-throws discipline and clean Nest.Name patterns for types. The main areas for improvement are: (1) state machine files that pack many nested types into single files, violating [API-IMPL-005]; (2) compound method names in the waiter queue extensions (documented workaround); (3) the `_ChannelError` naming workaround for a compiler bug. The public API surface is clean with simple verb names (`send`, `receive`, `subscribe`, `fulfill`, `arrive`).
