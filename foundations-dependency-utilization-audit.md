# Foundations Dependency Utilization Audit

<!--
---
version: 1.1.0
last_updated: 2026-03-16
status: RECOMMENDATION
tier: 1
---
-->

## Context

Swift-foundations Layer 3 packages `swift-io` and `swift-kernel` depend heavily on primitives (Layer 1). This discovery audit [RES-012] evaluates whether these packages fully leverage available infrastructure from their dependencies, cross-referencing against [IMPL-*] (implementation skill) and [INFRA-*] (existing-infrastructure skill).

**Scope**: `swift-io` (209 source files, 6 modules) and `swift-kernel` (48 source files, 1 module).

**Trigger**: Proactive cross-package review [RES-012] — convention compliance verification [RES-015].

## Question

Where do `swift-io` and `swift-kernel` use mechanism (`Int(bitPattern:)`, `.rawValue`, manual construction) at call sites when typed infrastructure exists?

## Analysis

### Kernel Module: Clean

**Verdict**: Production-ready. No actionable findings.

The Kernel module demonstrates strict convention compliance:

| Pattern | Count | Assessment |
|---------|-------|------------|
| `Int(bitPattern:)` | 1 | Proper boundary overload in `Kernel.Thread.Count` |
| `.rawValue` | 2-3 | `RawRepresentable` enums (Phase, Strategy) — not Tagged types |
| `while` loops | 7 | All synchronization waits or write loops at system boundary |
| `withUnsafe*` | 6 | File I/O and string encoding — necessary at syscall layer |
| Foundation | 0 | Clean |

The file I/O write loops (`Kernel.File.Write.Atomic+API.swift:388-427`, `Kernel.File.Write.Streaming+API.swift:523-562`) use `Int` arithmetic for byte tracking. This is correct — they operate at the kernel syscall boundary where `Kernel.IO.Write.write()` returns `Int`. No typed infrastructure applies.

---

### IO Module: Six Improvement Areas

#### Finding 1: Tagged Atomic Flag — `.rawValue` leak at call sites

> **Resolved: 2026-03-16**: Implemented in Tagged+Kernel.Atomic.Flag.swift. Call sites updated.

**Files**: `IO.Event.Poll.Loop.swift:63`, `IO.Completion.Queue.swift:488,491`

**Current** (mechanism — [PATTERN-017]):
```swift
while !shutdownFlag.rawValue.isSet {       // Poll.Loop
shutdownFlag.rawValue.set()                 // Completion.Queue
bridge.rawValue.finish()                    // Completion.Queue
```

`Shutdown.Flag` is `Tagged<Shutdown, Kernel.Atomic.Flag>`. The `.rawValue` unwraps the Tagged wrapper to access `Flag.isSet` and `Flag.set()`. This exposes mechanism at every call site.

**Recommended** (intent — [IMPL-002]):
```swift
while !shutdownFlag.isSet {
shutdownFlag.set()
bridge.finish()
```

**Resolution**: Add forwarding extension on Tagged where `RawValue == Kernel.Atomic.Flag`:

```swift
extension Tagged where RawValue == Kernel.Atomic.Flag, Tag: ~Copyable {
    public var isSet: Bool { rawValue.isSet }
    public func set() { rawValue.set() }
}
```

**Location**: Could live in `swift-kernel` (where `Kernel.Atomic.Flag` is defined) or `swift-io` (package-local). Kernel is better — all consumers benefit.

**Impact**: 3+ call sites in IO Events, 2+ in IO Completions.

---

#### Finding 2: `Int(bitPattern:)` at call sites for `reserveCapacity` and `store`

> **Stale (unverified 2026-03-16)**: Issue persists at IO.Event.Registration.Queue and IO.Completion.Submission.Queue call sites.

**Files**: `IO.Event.Registration.Queue.swift:29`, `IO.Completion.Submission.Queue.swift:28`, `IO.Blocking.Threads.Runtime.State.swift:397`, `IO.Blocking.Lane.Abandoning.Runtime.swift:75,138`, `IO.Handle.Waiters.swift:73`

**Current** (mechanism — [IMPL-010]):
```swift
elements.reserveCapacity(Int(bitPattern: deque.count))           // Registration.Queue
state._gauge._queueDepth.store(Int(bitPattern: state.queue.count), ordering: .relaxed)  // Gauge
if Int(bitPattern: state.queue.count) >= options.queue.limit {    // Abandoning
internal var count: Int { Int(bitPattern: queue.count) }         // Waiters
```

`deque.count` and `queue.count` return `Index<Element>.Count` (i.e., `Tagged<Element, Cardinal>`). Per [INFRA-002], `Int(bitPattern: Cardinal)` exists in the Cardinal Standard Library Integration module, so the conversion compiles. But per [IMPL-010], the conversion should live in boundary overloads, not at every call site.

**Recommended**:

For `reserveCapacity` — add to Cardinal Standard Library Integration:
```swift
extension Array {
    public mutating func reserveCapacity(_ capacity: some Cardinal.Protocol) {
        self.reserveCapacity(Int(bitPattern: capacity))
    }
}
```

For `Atomic<Int>.store` / `wrappingAdd` — these are stdlib `Synchronization` module APIs. Adding overloads on `Atomic<Int>` accepting `Cardinal.Protocol` would push the boundary into one location. However, `Atomic` is not a primitives type, so the coupling may not be worth it. **Assessment**: The `Int(bitPattern:)` conversions at the Atomic boundary are acceptable as genuine stdlib boundaries per [IMPL-010].

For `options.queue.limit` comparison — the limit is typed as `Int`. If it were typed as `Cardinal` or `Index<...>.Count`, the comparison would be typed. **Assessment**: This is a design choice in the options type, not an infrastructure gap.

For `IO.Handle.Waiters.count` — returning `Int` forces all consumers to work in untyped space. Returning `Index<...>.Count` would preserve type safety downstream. **Assessment**: Internal API, easy to change.

**Priority**: Medium. The `reserveCapacity` overload benefits the entire ecosystem.

---

#### Finding 3: `__unchecked` constructor for capacity

> **Stale (unverified 2026-03-16)**: IO.Handle.Waiters.swift:62-64 still uses hand-rolled pattern.

**File**: `IO.Handle.Waiters.swift:62-64`

**Current** (mechanism — [PATTERN-017]):
```swift
let typedCapacity = Index<Async.Waiter.Entry<Void, Waiter.Token>>.Count(
    __unchecked: (), Cardinal(UInt(max(capacity, 1)))
)
```

This chains `Int → max → UInt → Cardinal → __unchecked Tagged`. Per [INFRA-002], `Tagged<Tag, Cardinal>.init(_ int: Int) throws(Cardinal.Error)` exists.

**Recommended** (intent):
```swift
let typedCapacity: Index<Async.Waiter.Entry<Void, Waiter.Token>>.Count = try! .init(max(capacity, 1))
```

Or if `capacity` is guaranteed positive, the `max` is redundant and a direct `try!` suffices.

**Priority**: Low. Single call site, internal code.

---

#### Finding 4: Hand-rolled accessor structs on reference type

> **Stale (unverified 2026-03-16)**: IO.Blocking.Threads.Runtime.State still uses hand-rolled structs.

**File**: `IO.Blocking.Threads.Runtime.State.swift:299-351`

**Current**:
```swift
var waiter: Waiter { Waiter(state: self) }
struct Waiter {
    let state: IO.Blocking.Threads.Runtime.State
    var acceptance: Acceptance { Acceptance(state: state) }
}
struct Acceptance {
    let state: IO.Blocking.Threads.Runtime.State
    func cancel(ticket:disposition:) -> Bool { ... }
}
struct Gauge {
    let state: IO.Blocking.Threads.Runtime.State
    var queueDepth: Int { ... }
}
```

Three hand-rolled structs follow the verb-as-property pattern but don't use `Property<Tag, Base>` [INFRA-106].

**Assessment**: `State` is a `final class` (reference type, Copyable). `Property<Tag, Base>` works with Copyable bases. However, the existing structs are simple, internal, and functional. The benefit of migrating to `Property<Tag, Base>` is consistency with the ecosystem pattern, not functionality.

**Priority**: Low. The current pattern works. Migration would be a consistency improvement, not a bug fix. If these types grow in complexity, `Property<Tag, Base>` would prevent accessor struct proliferation.

---

#### Finding 5: Atomic in-flight count uses `Int` instead of typed count

**File**: `IO.Blocking.Threads.Runtime.State.swift:41,100,106,112,118`

**Current**:
```swift
private let _inFlightCount: Atomic<Int>

func incrementInFlight() {
    _ = _inFlightCount.wrappingAdd(1, ordering: .relaxed)
}

func addInFlight(_ count: some Cardinal.Protocol) {
    _ = _inFlightCount.wrappingAdd(Int(bitPattern: count.cardinal), ordering: .relaxed)
}
```

The in-flight count is stored as `Atomic<Int>` and manipulated via raw `Int` operations. Per [IMPL-006], stored properties that hold quantities should use typed wrappers.

**Assessment**: `Atomic<Int>` is a stdlib type — there's no `Atomic<Cardinal>`. The `Int` storage is a stdlib boundary constraint, not a design choice. The `addInFlight(_: some Cardinal.Protocol)` method already provides a typed entry point. The `Int(bitPattern:)` conversion inside that method is a proper boundary overload per [IMPL-010].

**Priority**: None. This is correct as-is — stdlib Atomic constrains the storage type.

---

#### Finding 6: Queue drain pattern could use bulk collection

> **Stale (unverified 2026-03-16)**: Original drain pattern persists; no Deque.drainAll() added.

**Files**: `IO.Event.Registration.Queue.swift:26-35`, `IO.Completion.Submission.Queue.swift:26-35`

**Current**:
```swift
public func drain<Element>() -> [Element] where Value == Mutex<Deque<Element>> {
    mutable.value.withLock { deque in
        var elements: [Element] = []
        elements.reserveCapacity(Int(bitPattern: deque.count))
        while let element = deque.front.take {
            elements.append(element)
        }
        return elements
    }
}
```

This drains a `Deque` element-by-element into an `Array`. Per [IMPL-032], bulk operations are preferred over per-element loops.

**Assessment**: The `while let` loop is implementing drain infrastructure itself — not calling it at a call site. If `Deque` provided a `drainAll() -> [Element]` or `Array.init(draining: Deque)` method, this code would be simpler. However, this is a one-time implementation inside the queue abstraction, and the `while let element = deque.front.take` pattern is idiomatic Swift for consuming.

**Priority**: Low. The drain implementation is correct and isolated. A `Deque.drainAll()` method in queue-primitives would benefit all consumers but is a separate infrastructure addition.

---

### Convention Compliance Summary

| Convention | IO | Kernel |
|------------|-----|--------|
| [PRIM-FOUND-001] No Foundation | PASS (tests only) | PASS |
| [API-ERR-001] Typed throws | PASS | PASS |
| [IMPL-002] Typed arithmetic | PASS (Finding 5 is stdlib boundary) | PASS |
| [IMPL-010] Push Int to edge | PARTIAL (Findings 1, 2, 3) | PASS |
| [IMPL-033] Iteration intent | PASS | PASS |
| [PATTERN-017] rawValue location | PARTIAL (Finding 1) | PASS |
| [INFRA-106] Property accessor | PARTIAL (Finding 4) | N/A |
| [API-NAME-001] Namespace structure | PASS | PASS |

## Outcome

**Status**: RECOMMENDATION

### Actionable Improvements (by priority)

**High — ecosystem-wide benefit**:

1. **Add forwarding extension for `Tagged where RawValue == Kernel.Atomic.Flag`** in `swift-kernel` or `swift-kernel-primitives`. Eliminates `.rawValue` at 5+ call sites across IO Events and IO Completions. Small change, high readability impact.

**Medium — ecosystem-wide benefit**:

2. **Add `Array.reserveCapacity(_ capacity: some Cardinal.Protocol)`** to Cardinal Standard Library Integration. Eliminates `Int(bitPattern:)` at 2+ call sites and benefits all future consumers of typed counts.

**Low — consistency improvements**:

3. **Replace `__unchecked` constructor** in `IO.Handle.Waiters.swift:62-64` with `try! .init(max(capacity, 1))`.

4. **Consider `Property<Tag, Base>`** for `IO.Blocking.Threads.Runtime.State` accessors if they grow in complexity.

5. **Consider `Deque.drainAll()`** in queue-primitives for the drain pattern used in Registration.Queue and Submission.Queue.

### No Action Required

- **Kernel module**: Clean. All patterns are at appropriate abstraction levels.
- **IO while loops**: All are run loops, synchronization waits, or infrastructure implementation — correct per [IMPL-033].
- **IO `withUnsafe*`**: All are low-level primitives (Slot.Container) or drain implementations — correct per [INFRA-024].
- **Atomic<Int> storage**: stdlib constraint, not design choice — correct per [IMPL-006].

## References

- [IMPL-002] Write the Math, Not the Mechanism
- [IMPL-010] Push Int to the Edge
- [IMPL-033] Iteration: Intent Over Mechanism
- [PATTERN-017] rawValue and Property Access Location
- [INFRA-002] Cardinal Integration
- [INFRA-106] Property<Tag, Base> Pattern
- [RES-012] Discovery Triggers
- [RES-015] Convention Compliance Verification
