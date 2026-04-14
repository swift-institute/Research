# ~Escapable Readiness Assessment

<!--
---
version: 2.3.0
last_updated: 2026-03-26
status: SUPERSEDED
superseded_by: nonescapable-ecosystem-state.md
tier: 2
trigger: Pointfree #355/#356 analysis — ~Escapable as third pillar alongside isolation and ~Copyable
---
-->

> **SUPERSEDED** (2026-04-02) by [nonescapable-ecosystem-state.md](nonescapable-ecosystem-state.md) (swift-institute).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

Pointfree #355 (Feb 23, 2026) identified `~Escapable` as the third pillar of Swift's ownership story alongside isolation and `~Copyable`. They observed that ~Escapable types tie lifetimes to other values, work hand-in-hand with ~Copyable for even more power, and that the fundamentals are in place with the Lifetimes experimental feature. Their TCA2 store handles in effects are ~Copyable and could additionally become ~Escapable (tied to effect scope).

The Swift Institute async ecosystem already:
- Enables `Lifetimes` as an experimental feature in both `swift-async-primitives` and `swift-async` (swift-foundations)
- Extensively uses `~Copyable` for single-use, move-only, and unique-ownership types
- Has existing `~Escapable` usage in `Kernel.Path.View`, `Path.View`, and `Span.Iterator`

The question is: which async types are candidates for `~Escapable`, and what would it unlock?

## Question

Which types in the Swift Institute async ecosystem are candidates for `~Escapable`, and what would it unlock?

## Experiment Validation

Empirical testing (2026-02-25) in `swift-institute/Experiments/nonescapable-closure-storage/` challenged several assumptions from the initial analysis. The results correct the assessment's characterization of blockers.

**Toolchain**: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21), macOS 26.0 (arm64).

### Finding 1: ~Escapable CAN Store @escaping Closures

**Previous claim**: "~Escapable types cannot store closures today" / "Swift 6.2 cannot store non-escaping closures in types."

**Correction**: A `~Escapable` struct with `@_lifetime(immortal)` and a stored `@escaping @Sendable () -> Void` property compiles and runs correctly. This was confirmed with two patterns:

```swift
// Pattern 1: Direct storage
struct NEWithClosure: ~Escapable {
    let action: @Sendable () -> Void
    @_lifetime(immortal)
    init(action: @escaping @Sendable () -> Void) {
        self.action = action
    }
}

// Pattern 2: Resumption mirror (scoped, consuming)
struct ScopedResumption: ~Escapable {
    let thunk: @Sendable () -> Void
    @_lifetime(immortal)
    init(_ action: @escaping @Sendable () -> Void) {
        self.thunk = action
    }
    consuming func execute() { thunk() }
}
```

Both compile and execute without issue. The original assessment's claim that "the closure integration gap" prevents all closure storage in ~Escapable types was overstated.

### Finding 2: The ACTUAL Closure Context Gaps

The real blockers are more specific:

**Gap A -- `@_lifetime` cannot depend on Escapable values**: Attempting `@_lifetime(copy action)` on an `@escaping` closure parameter produces:
```
error: invalid lifetime dependence on an Escapable value with consuming ownership
```
This means a ~Escapable type's lifetime cannot be tied to a closure parameter. The type can *store* a closure, but it cannot derive its *lifetime* from one.

**Gap B -- Lifetime-dependent ~Escapable values cannot be captured in closures**: A borrow-lifetime ~Escapable value (e.g., `@_lifetime(borrow ptr)`) cannot be captured in any closure, including non-escaping closures:
```
error: lifetime-dependent variable 'ne' escapes its scope
note: this use causes the lifetime-dependent value to escape
```

These two gaps -- not a blanket "can't store closures" -- are the precise closure context limitations.

### Finding 3: ~Escapable + Sendable Works

A `~Escapable, Sendable` struct compiles and works correctly:

```swift
struct NESendable: ~Escapable, Sendable {
    let value: Int
    @_lifetime(immortal)
    init(value: Int) { self.value = value }
}
```

The interaction is orthogonal: `~Escapable` constrains scope/lifetime, `Sendable` constrains thread-safety. The compiler handles the combination without issue.

### Finding 4: ~Escapable Survives Across await

An `@_lifetime(immortal)` ~Escapable value survives `await Task.yield()` and can even be passed to a `Task` closure if Sendable:

```swift
func testAsync() async {
    let ne = NESendable(value: 77)
    let result = await Task { ne.value }.value  // works
}
```

This is significant: immortal-lifetime ~Escapable values are not restricted to synchronous contexts. Whether borrow-lifetime ~Escapable values survive suspension points remains untested.

### Finding 5: Revised Resumption Viability

Since ~Escapable CAN store `@escaping` closures, a `ScopedResumption: ~Escapable` pattern with `@_lifetime(immortal)` is viable TODAY. However, this does not achieve the zero-allocation goal because the closure is still `@escaping` (heap-allocated). The vision of non-escaping closure storage -- where the closure context itself is stack-allocated -- requires the closure context gaps (Finding 2) to close.

### Summary Table (v1.1.0 — Swift 6.2.3, Feb 25)

| Tested Scenario | Result |
|----------------|--------|
| ~Escapable stores @escaping closure (immortal lifetime) | WORKS |
| ~Escapable + Sendable | WORKS |
| ~Escapable survives await (immortal lifetime) | WORKS |
| ~Escapable passed to Task (immortal, Sendable) | WORKS |
| @_lifetime depends on closure parameter | FAILS (Gap A) |
| Borrow-lifetime ~Escapable captured in closure | FAILS (Gap B) |

## v2.0.0 Experiment Validation (2026-03-02)

**Toolchain**: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4), macOS 26.0 (arm64).
**Trigger**: Pointfree #356 demonstrated ~Copyable + ~Escapable SQLite Reader/Writer pattern.

Three parallel experiments were conducted:

### Track 1: Resumption ~Copyable + ~Escapable — REVERTED

**Experiment**: `swift-institute/Experiments/resumption-nonescapable-noncopyable/`

All 7 variants pass on Swift 6.2.4:

| Variant | Pattern | Result |
|---------|---------|--------|
| V1 | Basic `~Copyable, ~Escapable, Sendable` struct | PASS |
| V2 | `Optional<Resumption>` | PASS |
| V3 | Consuming parent returns Resumption | PASS |
| V4 | Inline create + consume in drain closure | PASS |
| V5 | Let-bind then consume | PASS |
| V6 | Consuming closure parameter | PASS |
| V7 | Optional binding | PASS |

**Annotations required**:
- `@_lifetime(immortal)` on `init` (no borrowable source — closure is Escapable)
- `@_lifetime(immortal)` on functions returning Resumption with no borrowable parameter (e.g., `consuming func resumption(with:)`)
- Mutating functions returning `Resumption?` infer `@_lifetime(borrow self)` — no annotation needed

**Production change applied then REVERTED**: `Async.Waiter.Resumption` was temporarily changed to `~Copyable, ~Escapable, Sendable` with `consuming func resume()`. All 5 downstream call sites in swift-io compiled without changes. However, `swift-cache-primitives` and `swift-pool-primitives` collect Resumptions into `[Async.Waiter.Resumption]` (Swift.Array) for batch-resume-outside-lock patterns. Arrays are heap-backed and require `Element: Escapable` (confirmed blocker #1 from storage-mechanisms research). The `~Escapable` was reverted; Resumption remains `~Copyable, Sendable`.

**Lesson (EXP-011 workaround validation trap)**: The experiment validated the pattern in isolation. The 5 swift-io call sites all use single-inline-consume (`entry.resumption(with: outcome).resume()`). But cache/pool use batch-collect-then-resume, which requires dynamic collections. Testing only immediate call sites was insufficient — the full dependency graph must be verified.

### Track 2: Conditional Escapable Containers — PARTIAL

**Experiment**: `swift-institute/Experiments/conditional-escapable-container/`

| Variant | Pattern | Result |
|---------|---------|--------|
| V1 | Single-element Box, conditional Escapable | **PASS** |
| V2 | Multi-element FixedArray (heap-backed) | **BLOCKED** |
| V3 | Ring buffer (heap-backed) | **BLOCKED** |
| V4 | Nested `Box<Box<~Escapable>>` | **PASS** |
| V5 | `_read` accessor for ~Escapable element | **PASS** |
| V6 | `Optional<Container<~Escapable>>` | **PASS** |
| V7 | Container in closure | **PARTIAL** |
| V8 | Pair container (two-element) | **PASS** |

**Fundamental blocker for heap-backed containers**: `UnsafeMutablePointer<T>` requires `T: Escapable` (implicit constraint — `Pointee: ~Copyable` without `& ~Escapable`). Confirmed via compiler source FIXME (`lib/ClangImporter/ImportType.cpp:507`) and SE-0465 explicit deferral. No feature flag exists to toggle this.

**What works**: Single-element and fixed-element-count containers (struct fields), and **enum-based variable-occupancy storage** (NEW, v2.1.0 — see `pointer-nonescapable-storage` V14/V15). Conditional Escapable conformance composes through nesting.

**NEW (v2.1.0): Enum-based variable-occupancy storage**: An enum with cases for each occupancy level (`empty`, `one(Element)`, `two(Element, Element)`, ...) provides variable-count inline storage for ~Escapable elements. `consume self` + `self = .case(...)` is full reinit (avoids partial reinit blocker). Practical for capacities up to 4-8.

**What doesn't work**: Any container that uses `UnsafeMutablePointer.allocate()`, `.initialize()`, `.move()`, or `.deinitialize()` for ~Escapable elements. Also `Optional<Element>` as a stored property in ~Escapable containers (lifetime escape error, even when both slots filled). Also `InlineArray<N, Element>` (same implicit Escapable). Also `@_rawLayout` element access — the layout declaration compiles with `~Escapable` (V16 PASS), but all element access methods require typed pointers with implicit Escapable (V17/V17b BLOCKED). This is the **layout-vs-access gap**: `@_rawLayout` is the correct future solution when pointer types gain `~Escapable` support.

### Track 3A: Gap Re-validation on 6.2.4 — GAPS PERSIST (with refinement)

**Experiment**: `swift-institute/Experiments/nonescapable-gap-revalidation-624/`

| Gap | Status on 6.2.4 | Change from 6.2.3 |
|-----|-----------------|-------------------|
| Gap A (`@_lifetime(copy action)`) | **STILL BLOCKED** | No change |
| Gap A (async variant) | **STILL BLOCKED** | No change |
| Gap B (stored closure) | **STILL BLOCKED** | No change |
| Gap B+ (immediately-invoked closure) | **PASS** | **NEW** — works on 6.2.4 |
| Gap B++ (immortal control) | PASS | No change |
| `@_lifetime(immortal)` workaround | PASS | No change |

**Key new finding**: Gap B+ (immediately-invoked closure capturing a borrow-lifetime ~Escapable value) now **passes** on 6.2.4. The compiler can verify the lifetime doesn't escape when the closure is immediately invoked, but NOT when the closure is stored to a `let` binding first. This means `withLock`-style patterns work:
```swift
let result = { () -> Int in ne.ptr.pointee }()  // WORKS on 6.2.4
let fn = { ne.ptr.pointee }; fn()  // STILL BLOCKED
```

## Analysis

### Current Feature Flag Status

Both packages enable the `Lifetimes` experimental feature:

**swift-async-primitives** (`https://github.com/swift-primitives/swift-async-primitives/blob/main/Package.swift`, line 64):
```swift
.enableExperimentalFeature("Lifetimes"),
```

**swift-async** (`https://github.com/swift-foundations/swift-async/blob/main/Package.swift`, line 55):
```swift
.enableExperimentalFeature("Lifetimes"),
```

Both packages also use Swift 6.2 toolchains (swift-tools-version: 6.2) and enable strict memory safety. The compiler infrastructure is in place.

### Candidate Inventory

| Type | Location | Current Ownership | ~Escapable Candidate? | What It Unlocks | Blockers |
|------|----------|-------------------|----------------------|-----------------|----------|
| `Async.Waiter.Entry` | async-primitives | `~Copyable, Sendable` | HIGH | Compile-time scope enforcement, no use-after-resume | ~Escapable generics in collections |
| `Async.Waiter.Resumption` | async-primitives | `~Copyable, Sendable` | **REVERTED** (v2.3.0) | ~Escapable prevents storage in dynamic collections needed by cache/pool | Heap-backed containers require Escapable; batch-resume pattern incompatible |
| `Async.Channel.Bounded.Receiver` | async-primitives | `~Copyable, @unchecked Sendable` | MEDIUM | Lifetime-scoped to channel, no use-after-channel-drop | Receiver must outlive send scope for async iteration |
| `Async.Channel.Unbounded.Receiver` | async-primitives | `~Copyable, @unchecked Sendable` | MEDIUM | Same as Bounded.Receiver | Same as Bounded.Receiver |
| `Async.Channel.Bounded.Ends` | async-primitives | `~Copyable, @unchecked Sendable` | MEDIUM | Bundle lifetime tied to channel | Contains Receiver which holds Storage ref |
| `Async.Channel.Unbounded.Ends` | async-primitives | `~Copyable, @unchecked Sendable` | MEDIUM | Bundle lifetime tied to channel | Same as Bounded.Ends |
| `Async.Broadcast.Subscription` | async-primitives | `Sendable` (holds `Broadcast` ref) | LOW | Scoped to broadcast lifetime | Must be passed to Task for async iteration; Sendable required |
| `Async.Stream.Iterator` | swift-async | `Sendable` (stores `@escaping` closure) | HIGH | Non-escaping next(), stack-allocated iterator | Closure lifetime dependencies (Gap A), closure context capture of ~Escapable values (Gap B) |
| `Async.Callback` | async-primitives | `Sendable` (stores `@escaping` closures) | MEDIUM-HIGH | Non-escaping closure storage, zero allocation | Callback explicitly designed for escape (passed to arbitrary scopes) |
| `Async.Publication` | async-primitives | `final class, @unchecked Sendable` | LOW | Scoped publication slot | Must be captured by `onCancel:` closure -- fundamentally needs escape |
| `Async.Completion` | async-primitives | `final class, @unchecked Sendable` | LOW | Scoped completion token | Cross-scope CAS protocol requires reference semantics |
| `Async.Bridge` | async-primitives | `final class, @unchecked Sendable` | LOW | Scoped bridge | Explicitly bridges sync to async boundaries; must escape |
| `Async.Promise` | async-primitives | `final class, @unchecked Sendable` | LOW | N/A | Explicitly multi-awaiter; must escape to arbitrary scopes |
| `Async.Stream.Replay.Subscription` | swift-async | `actor` | LOW | Scoped to replay state | Actor isolation requires escapability for Task usage |
| `Async.Waiter.Queue.Flagged` | async-primitives | `~Copyable, Sendable` | MEDIUM | Scoped to lock-held region | Already consumed under lock; lifetime trivially bounded |

### Per-Candidate Deep Analysis

#### 1. `Async.Waiter.Entry` -- HIGH PRIORITY

**File**: `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Primitives/Async.Waiter.Entry.swift`

**Current design**: `~Copyable, Sendable` struct holding a continuation, flag, and metadata. Created under lock, consumed via `resumption(with:)` which yields a `Resumption` thunk.

**Why ~Escapable fits**: Entry is the textbook scoped-lifetime type. It is:
- Created within a lock scope
- Consumed (via `consuming func resumption()`) before the lock scope ends or shortly after
- Never legitimately stored beyond the waiter queue that owns it

**What it unlocks**:
- **Compile-time scope enforcement**: The compiler would prevent an Entry from escaping beyond the waiter queue's lifetime. Currently this is only enforced by the `~Copyable` single-use pattern.
- **Stack allocation**: If the compiler can prove the Entry does not escape, it can allocate it on the stack rather than needing to manage it through the queue's heap-allocated backing storage.

**Blockers**:
- Entry is `Sendable` because it may be accessed from the cancellation handler's thread. Experiment validation (Finding 3) confirms that `~Escapable + Sendable` works at the type-declaration level -- this is no longer a blocker.
- Entry is stored in `Async.Waiter.Queue.Bounded`/`Unbounded` arrays. Track 2 (v2.0.0) confirmed that `UnsafeMutablePointer<T>` requires `T: Escapable` — ALL heap-backed containers are blocked from holding ~Escapable elements. Only inline (stack-stored, fixed-element-count) containers work. This is a fundamental Swift stdlib constraint, not a feature flag issue.
- **v2.0.0 assessment**: Entry becoming ~Escapable requires the Queue to hold ~Escapable elements. Since Queue uses heap-allocated ring buffers (`UnsafeMutablePointer`), this is blocked until Swift stdlib relaxes the Escapable requirement on `UnsafeMutablePointer`. Alternatively, Entry with `@_lifetime(immortal)` could be explored, but the containment cascade (Edge Case 2) would force Queue to also become ~Escapable.

#### 2. `Async.Waiter.Resumption` -- **REVERTED** (v2.3.0, was IMPLEMENTED in v2.0.0)

**File**: `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Waiter Primitives/Async.Waiter.Resumption.swift`

**Current design**: `~Copyable, Sendable` struct wrapping `@escaping @Sendable () -> Void` with `consuming func resume()`. The `~Escapable` was reverted.

**What was attempted** (v2.0.0):
1. Added `~Escapable` to struct declaration → `~Copyable, ~Escapable, Sendable`
2. Added `@_lifetime(immortal)` to `init` and `Entry.resumption(with:)`
3. Changed `func resume()` to `consuming func resume()`

**Why it was reverted** (v2.3.0): `swift-cache-primitives` and `swift-pool-primitives` collect Resumptions into `[Async.Waiter.Resumption]` (dynamic arrays) for batch-resume-outside-lock patterns:
```swift
var resumptions: [Async.Waiter.Resumption] = []
_storage.withLock { state in
    waiters.queue.drain { entry in
        resumptions.append(entry.resumption(with: result))
    }
}
resumptions.drain { $0.resume() }  // Resume outside lock
```
Dynamic arrays are heap-backed (`UnsafeMutablePointer`) and require `Element: Escapable` — confirmed blocker #1 from `nonescapable-storage-mechanisms.md`. The 5 swift-io call sites all use single-inline-consume and compiled fine, but the full dependency graph was not verified before deployment.

**What remains**: `~Copyable` (prevents double-resume) + `consuming func resume()` (enforces consumption). The `~Escapable` scope enforcement was the experimental addition that proved incompatible with batch-resume patterns.

**Lesson (EXP-011)**: "Minimal reproductions validate that a bug exists. They CANNOT validate that a workaround works at scale." The experiment tested 7 patterns in isolation — all passed. But cache/pool's batch-collect-then-resume pattern requires dynamic collections, which was outside the experiment's scope.

**Future path**: When `UnsafeMutablePointer` gains `~Escapable` support (SE-0465 deferral), Resumption can re-adopt `~Escapable` without breaking downstream consumers.

**Experiment**: `swift-institute/Experiments/resumption-nonescapable-noncopyable/` — all 7 variants PASS (pattern works in isolation).

#### 3. `Async.Channel.{Bounded,Unbounded}.Receiver` -- MEDIUM PRIORITY

**Files**:
- `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Primitives/Async.Channel.Bounded.Receiver.swift`
- `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Primitives/Async.Channel.Unbounded.Receiver.swift`

**Current design**: `~Copyable, @unchecked Sendable` structs holding a reference to shared `Storage`. Exactly one Receiver exists per channel. The Receiver borrows from the channel's Storage (a heap-allocated mutex-protected state).

**Why ~Escapable fits**: Receiver is semantically scoped to its channel:
- Created by the channel's `init`
- Should not outlive the channel's Storage
- If Storage is deallocated while a Receiver exists, the Receiver holds a dangling reference

**What it unlocks**:
- **Use-after-channel-drop prevention**: `~Escapable` with `@_lifetime(borrow storage)` would prevent the Receiver from outliving its backing Storage at compile time.
- **No @unchecked Sendable**: If the lifetime is compiler-verified, the `@unchecked Sendable` could potentially be replaced with proper Sendable inference.

**Blockers**:
- **Async iteration requires escape**: `for try await value in channel.receiver.elements` needs the iterator to survive across suspension points. A `~Escapable` Receiver cannot be passed into an async context if its lifetime is bound to the synchronous scope where the channel was created.
- **Task handoff pattern**: The documented usage pattern is "hand off Receiver to a consumer Task." This fundamentally requires the Receiver to escape the creation scope.
- **Borrow-lifetime closure capture (Gap B)**: Finding 2 confirms that borrow-lifetime ~Escapable values cannot be captured in closures. Since Receiver would use `@_lifetime(borrow storage)` rather than `@_lifetime(immortal)`, it would be subject to Gap B.
- This candidate becomes viable only when Swift supports "scoped but transferable" lifetime annotations -- the Receiver's lifetime should be tied to `Storage`, not to the lexical scope where it was created. This requires dependent lifetimes between heap objects, not just stack-to-stack dependencies.

#### 4. `Async.Channel.{Bounded,Unbounded}.Ends` -- MEDIUM PRIORITY

**Files**:
- `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Primitives/Async.Channel.Bounded.swift` (lines 135-178)
- `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Primitives/Async.Channel.Unbounded.swift` (lines 136-179)

**Current design**: `~Copyable, @unchecked Sendable` struct bundling a Storage reference and a Receiver. Created by `channel.take().ends()` which consumes the channel.

**Analysis**: Same constraints as Receiver. The Ends bundle inherits Receiver's lifetime requirements. If Receiver cannot be ~Escapable (due to async iteration), neither can Ends. Tied to Receiver's resolution.

#### 5. `Async.Stream.Iterator` -- HIGH PRIORITY (but blocked)

**File**: `https://github.com/swift-foundations/swift-async/blob/main/Sources/Async Stream/Async.Stream.Iterator.swift`

**Current design**: Sendable struct wrapping `@escaping @Sendable () async -> Element?`. The iterator is an "async closure thunk" -- each call to `next()` invokes the stored closure.

**Why ~Escapable fits**: Stream.Iterator is the async analog of `Span.Iterator`:
- Created by `makeAsyncIterator()`
- Should live only for the duration of the `for await` loop
- The closure captures mutable state (via `Iterator.Box`) that must not be shared

**What experiment validation changes**: Like Resumption, an `@_lifetime(immortal)` ~Escapable struct storing an `@escaping` closure works (Finding 1). However, Stream.Iterator has additional requirements beyond what Resumption needs:
- The iterator must survive across suspension points. Finding 4 confirms this works for immortal-lifetime values with await, which is encouraging.
- The `_next` closure property would ideally derive the iterator's lifetime from the closure. Finding 2 (Gap A) prevents this -- `@_lifetime` cannot depend on Escapable values.

**What it unlocks**:
- **Non-escaping async closure storage**: The `_next` closure could become non-escaping, eliminating heap allocation for the closure context.
- **Stack-allocated iterators**: For simple streams (from sequence, just, empty), the iterator could be entirely stack-allocated.
- **Symmetry with Span.Iterator**: `Span.Iterator` is already `~Escapable, ~Copyable` in the ecosystem. `Async.Stream.Iterator` would mirror this for the async world.

**Revised blockers**:
- **Closure lifetime dependencies (Gap A)**: `@_lifetime` cannot depend on the closure parameter. This blocks making the iterator's lifetime meaningful (tied to its data source).
- **Closure context capture (Gap B)**: If the iterator itself were borrow-lifetime ~Escapable, it could not be captured in the `for await` desugaring.
- **AsyncIteratorProtocol**: The `mutating func next()` method on `AsyncIteratorProtocol` is called across suspension points. Finding 4 shows immortal ~Escapable values survive await, but protocol conformance with ~Escapable associated types remains limited (SE-0446 S4.4).

#### 6. `Async.Callback` -- MEDIUM-HIGH PRIORITY (but blocked)

**File**: `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Primitives/Async.Callback.swift`

**Current design**: Sendable struct wrapping `@escaping @Sendable ((@escaping @Sendable (Value) -> Void)) -> Void`. Double-escaping: the `run` closure escapes, and it receives a callback closure that also escapes.

**Why ~Escapable would help**: If `Callback` were `~Escapable`, the outer `run` closure could be non-escaping, saving one allocation. However, the callback parameter passed to `run` must still escape (it's called asynchronously).

**What it unlocks**:
- **One fewer allocation**: The `run` closure itself could be stack-allocated.
- **Clearer ownership**: The Callback's lifetime would be tied to the scope that created it.

**Blockers**:
- `Callback` is explicitly designed for deferred computation. Its `map`, `flatMap`, and `async` combinators create new Callbacks that capture `self` -- requiring self to escape.
- The `value` async property bridges to `withCheckedContinuation`, which requires the Callback to outlive the synchronous scope.
- Fundamentally, `Callback` is a "computation description" meant to be passed around. ~Escapable conflicts with this purpose.
- **Verdict**: Callback is not a good candidate. Its design is fundamentally about escaping computations.

#### 7. `Async.Publication` -- LOW PRIORITY

**File**: `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Primitives/Async.Publication.swift`

**Current design**: `final class, @unchecked Sendable`. Reference type with mutex-protected optional value. Used in `withTaskCancellationHandler` patterns where both the operation closure and `onCancel:` race to `take()`.

**Why NOT ~Escapable**: Publication is captured in `@Sendable` closures (`onCancel: { [publication] in ... }`). The entire purpose is to provide a shared coordination point between two closures that outlive the synchronous scope. Making it `~Escapable` would prevent this capture.

**What would help instead**: Publication is actually well-served by its current design. The `final class` with `@unchecked Sendable` is correct for a shared coordination primitive. If anything, it could benefit from being `~Copyable` (to enforce single-owner semantics), but the capture-list pattern requires Copyable (ARC).

#### 8. `Async.Broadcast.Subscription` -- LOW PRIORITY

**File**: `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Primitives/Async.Broadcast.swift` (lines 212-325)

**Current design**: Sendable struct holding a reference to the `Broadcast` and a subscriber ID. Conforms to `AsyncSequence` for `for await` iteration.

**Why NOT ~Escapable**: Subscription is designed to be passed to Tasks for independent consumption. The `for await msg in sub1 { ... }` pattern requires the subscription to escape to an async context. The subscription's logical lifetime is "until cancelled or broadcast finishes," which is not a lexical scope.

#### 9. `Async.Waiter.Queue.Flagged` -- MEDIUM PRIORITY

**File**: `https://github.com/swift-primitives/swift-async-primitives/blob/main/Sources/Async Primitives/Async.Waiter.Queue.swift` (lines 81-125)

**Current design**: `~Copyable, Sendable` struct containing a `Flag.Reason` and an `Entry`. Created during `popEligible(flaggedInto:)` under lock, consumed outside lock to create resumptions.

**Why ~Escapable fits**: Identical pattern to Entry -- created under lock, consumed in the immediately following scope.

**What it unlocks**: Same as Entry -- compile-time scope enforcement and potential stack allocation.

**Blockers**: Same as Entry -- stored in drain queues, needs ~Escapable generic support.

### What ~Escapable Unlocks

#### Performance

| Improvement | Mechanism | Affected Types | Impact |
|------------|-----------|---------------|--------|
| Stack allocation of closures | Non-escaping closure storage in ~Escapable types | Resumption, Stream.Iterator | Eliminates heap allocation per resume/next() |
| Zero-allocation deferred resumption | Resumption thunks on stack | Resumption | High-throughput channels: 100K+ allocs/sec eliminated |
| Reduced ARC traffic | Stack-allocated values need no retain/release | Entry, Flagged, Resumption | Reduces atomic operation overhead in hot paths |
| Inline storage | Compiler can prove non-escape then inline in containing struct | Entry in Queue | Better cache locality for waiter queue scanning |

#### Safety

| Improvement | Mechanism | Affected Types | Impact |
|------------|-----------|---------------|--------|
| No use-after-scope | Compiler prevents value from outliving parent | Entry, Resumption, Flagged | Eliminates class of bugs: double-resume, stale entry |
| No use-after-channel-drop | Lifetime tied to Storage | Receiver, Ends | Prevents dangling reference bugs (currently only runtime-caught) |
| Exactly-once by construction | ~Copyable + ~Escapable together | Resumption | Current: ~Copyable prevents copy. Future: ~Escapable prevents escape. Together: provably used exactly once in exactly one scope. |

#### API Design

| Improvement | Mechanism | Impact |
|------------|-----------|--------|
| Non-escaping closures in types | ~Escapable types can store non-escaping closures | Enables lightweight callback types without heap allocation -- Pointfree's "third pillar" vision |
| Scoped accessor pattern | Return ~Escapable views instead of closures | Mirror Span/MutableSpan pattern for async primitives |
| Compiler-enforced protocols | Protocols with ~Escapable associated types | `AsyncIteratorProtocol` could require ~Escapable iterators for scoped iteration |

### Swift Language Blockers

#### Resolved (available in Swift 6.2 with Lifetimes feature)

| Feature | SE Proposal | Status | Used In Ecosystem |
|---------|------------|--------|------------------|
| ~Escapable types | SE-0446 | Accepted, experimental | `Kernel.Path.View`, `Path.View`, `Span.Iterator` |
| @_lifetime annotations | SE-0456 | Accepted, experimental | `Kernel.Path.View.init`, `Span.Iterator.init` |
| Span<T> as ~Escapable | SE-0447 | Accepted, in stdlib | Used throughout |
| ~Escapable + Sendable | SE-0446 | Works (confirmed by experiment) | Validated in nonescapable-closure-storage |
| ~Escapable + @escaping closure storage | SE-0446 + SE-0456 | Works with @_lifetime(immortal) | Validated in nonescapable-closure-storage |
| ~Escapable across await (immortal) | SE-0446 + SE-0456 | Works with @_lifetime(immortal) | Validated in nonescapable-closure-storage |

#### Unresolved (blocking further async adoption)

| Feature | Status | Impact | Needed For |
|---------|--------|--------|-----------|
| **Closure parameter lifetime dependencies** | Not supported (Gap A: still blocked on 6.2.4) | CRITICAL -- blocks zero-allocation closure storage | Resumption (zero-alloc goal), Stream.Iterator |
| **Closure context capture of ~Escapable values** | Partially resolved (Gap B stored: BLOCKED; Gap B+ immediately-invoked: **PASS on 6.2.4**) | HIGH -- stored closure capture still blocked, but immediately-invoked closures now work | Receiver (borrow-lifetime), withLock patterns |
| **`UnsafeMutablePointer<T>` requires `T: Escapable`** | Confirmed blocker (v2.0.0). Root cause: stdlib declares `Pointee: ~Copyable` without `& ~Escapable`. FIXME exists in compiler (`ImportType.cpp:507`). SE-0465 deferred to future proposal. No feature flag. | CRITICAL -- blocks ALL heap-backed containers from holding ~Escapable elements | Queue storing Entry, Array/Ring/Deque with ~Escapable elements |
| **`Optional<Element>` as stored property in ~Escapable container** | **NEW blocker** (v2.1.0). Error: "lifetime-dependent variable 'self' escapes its scope". Triggers even when both slots filled (not nil-related). | HIGH -- blocks Optional-slot multi-element inline containers | Any growable inline container |
| **~Escapable generics** | Partially supported (SE-0446 S4.3); inline containers work, heap-backed blocked. **NEW (v2.1.0): Enum-based variable-occupancy storage works** (V14/V15 in `pointer-nonescapable-storage`). | MEDIUM -- enum pattern viable for capacities 2-8 | Small fixed-capacity containers |
| **Lifetime dependencies between heap objects** | Not proposed | MEDIUM -- "scoped to Storage, not to lexical scope" | Receiver, Ends |
| **~Escapable + protocol associated types** | Limited (SE-0446 S4.4) | MEDIUM -- AsyncIteratorProtocol conformance | Stream.Iterator |
| **~Escapable across await (borrow lifetime)** | Untested | MEDIUM -- immortal works, borrow-lifetime unknown | Stream.Iterator, channel iteration with scoped receivers |

#### The Closure Context Gaps (Critical Path)

Related analysis in `https://github.com/swift-primitives/swift-memory-primitives/blob/main/Research/lifetime-dependent-borrowed-cursors.md`.

Experiment validation (Finding 2) identifies two precise closure context gaps:

**Gap A -- `@_lifetime` cannot depend on Escapable values**: The compiler rejects `@_lifetime(copy action)` when `action` is an `@escaping` closure parameter with the error "invalid lifetime dependence on an Escapable value with consuming ownership." This means a ~Escapable type can store an `@escaping` closure (the closure is just a regular stored property), but the type's lifetime cannot be derived from the closure. Without this, the type must use `@_lifetime(immortal)` or derive its lifetime from some other non-Escapable value.

**Gap B -- Borrow-lifetime ~Escapable values cannot be captured in closures**: A ~Escapable value with a borrow-lifetime dependency (e.g., `@_lifetime(borrow ptr)`) cannot be captured in a stored closure. The compiler treats closure capture as an escape, producing "lifetime-dependent variable 'ne' escapes its scope."

**Refinement (v2.0.0, Swift 6.2.4)**: Gap B has been partially resolved. Immediately-invoked closures (`{ () -> T in ne.ptr.pointee }()`) now compile on 6.2.4 — the compiler can verify the lifetime doesn't escape when the closure is immediately invoked. Only storing the closure to a `let` binding first (`let fn = { ne.ptr.pointee }; fn()`) remains blocked. This enables `withLock`-style patterns where the closure result is returned immediately.

Note that the original assessment's third point -- "~Escapable types cannot store closures (even non-escaping ones)" -- is INCORRECT for `@escaping` closures. A ~Escapable type with `@_lifetime(immortal)` can freely store `@escaping` closures. What remains unsupported is storing *non-escaping* closures (closures without `@escaping`), which is the feature needed for zero-allocation closure storage.

### Cross-Reference with Pointfree's Vision

| Pointfree Observation | Swift Institute Ecosystem Parallel |
|----------------------|-----------------------------------|
| "~Escapable ties lifetimes to other values" | Receiver tied to Storage, Entry tied to lock scope, Resumption tied to deferred-resume scope |
| "Works hand-in-hand with ~Copyable" | Entry is already ~Copyable + should be ~Escapable. Receiver is already ~Copyable + should be ~Escapable. The combination gives exactly-once-in-scope guarantees. |
| "Storing non-escaping closures in types" | Resumption wraps a closure. Stream.Iterator wraps a closure. Both would become zero-allocation with non-escaping closure storage. Experiment confirms @escaping closure storage works today -- the gap is specifically non-escaping closure storage. |
| "TCA2 store handles are ~Copyable, could become ~Escapable" | Our channel Receiver handles are ~Copyable, would benefit from ~Escapable (scoped to channel lifetime). Same pattern. |
| "Still in active development" | Our experience confirms: Lifetimes flag is enabled, we have working ~Escapable types (Kernel.Path.View, Span.Iterator), and experiment validates that ~Escapable + Sendable, ~Escapable + @escaping closure storage, and ~Escapable + await all work. The remaining gaps are more specific than initially assessed: closure parameter lifetime dependencies and borrow-lifetime closure capture. |

## Outcome

**Status**: IN_PROGRESS (v2.3.0 — Resumption reverted, further candidates tracked)

### Summary

The Swift Institute async ecosystem has **8 candidate types** for `~Escapable`, with 3 at HIGH priority. **None are currently ~Escapable** — the one attempted deployment (Resumption) was reverted.

1. **Async.Waiter.Resumption** -- **REVERTED** (v2.3.0, was IMPLEMENTED in v2.0.0). The `~Escapable` constraint prevented storage in dynamic collections (`[Resumption]`) needed by cache/pool batch-resume patterns. Remains `~Copyable, Sendable`. The heap-backed container blocker has **practical cascading consequences** beyond just blocking ~Escapable container types — it also blocks storing ~Escapable elements in any existing collection.
2. **Async.Waiter.Entry** -- Strong candidate for scope enforcement. Blocked by `UnsafeMutablePointer` requiring `T: Escapable` — heap-backed Queue cannot hold ~Escapable entries. Only becomes viable when Swift stdlib relaxes this constraint.
3. **Async.Stream.Iterator** -- Blocked by Gap A (closure parameter lifetime dependencies). The `@_lifetime(immortal)` workaround provides no safety benefit over current Escapable design (immortal = no lifetime to track). Should wait for Gap A fix.

### What Changed in v2.3.0

| Finding | Impact |
|---------|--------|
| Resumption ~Escapable **REVERTED** | Downstream consumers (cache/pool) need `[Resumption]` — arrays require Escapable elements |
| EXP-011 workaround validation trap confirmed | Single call-site verification insufficient — must verify full dependency graph |
| `@_rawLayout` layout-vs-access gap confirmed | Declaration compiles with ~Escapable, element access blocked by pointer constraint |
| Heap-backed container blocker has cascade consequences | Not only blocks ~Escapable containers, also blocks storing ~Escapable values in ANY existing collection |

### What Changed in v2.0.0–v2.2.0

| Finding | Impact |
|---------|--------|
| `UnsafeMutablePointer<T>` requires `T: Escapable` | Blocks ALL heap-backed containers from ~Escapable elements |
| Gap B+ (immediately-invoked closure) passes on 6.2.4 | `withLock`-style patterns now work for borrow-lifetime ~Escapable |
| Gap A, Gap B (stored) remain blocked on 6.2.4 | Zero-allocation and stored closure capture still blocked |
| Conditional Escapable conformance works for inline containers | `Box<NE>`, `Pair<NE, Int>`, nested containers work; only heap-backed blocked |
| Enum-based variable-occupancy storage works | 2-8 element containers via `consume self` + full reinit |
| `@_rawLayout` declaration with ~Escapable compiles | Layout-vs-access gap: layout works, element access blocked |

### Recommendations

1. **Resumption stays `~Copyable` only.** The `~Escapable` addition was reverted because cache/pool require `[Resumption]` (dynamic array). Re-adopt `~Escapable` only when `UnsafeMutablePointer` gains `~Escapable` support, which would also unblock Entry and Queue.

2. **No async type should adopt `~Escapable` today.** The Resumption revert demonstrates that even types with pure inline-consume call sites in one package may have batch-collect call sites in another. Until heap-backed containers support ~Escapable elements, the cascading incompatibility is too broad.

3. **Entry is blocked by heap container constraints.** Do not attempt until `UnsafeMutablePointer` drops its `Escapable` requirement. Track Swift Evolution for `UnsafeMutablePointer<T: ~Escapable>` support.

4. **Stream.Iterator should wait for Gap A.** The `@_lifetime(immortal)` workaround provides no safety advantage. When `@_lifetime(copy action)` works on closure parameters, Stream.Iterator becomes the next conversion target.

5. **Conditional Escapable is viable for inline containers.** Types like `Box`, `Pair`, and fixed-element-count containers can support ~Escapable elements TODAY using the `Sequence.Map` conditional conformance pattern. Heap-backed containers (Queue, Array, Ring) remain blocked.

6. **Track three Swift Evolution milestones** (all three must land before re-attempting async ~Escapable):
   - `UnsafeMutablePointer<T: ~Escapable>` — unblocks Entry, heap-backed containers, AND Resumption re-adoption
   - Closure parameter lifetime dependencies (Gap A) — unblocks zero-allocation Resumption, Stream.Iterator
   - Non-escaping closure storage — the ultimate zero-allocation enabler

### Maturity Assessment (v2.3.0)

| Aspect | Readiness |
|--------|-----------|
| Compiler infrastructure (Lifetimes flag) | READY |
| ~Escapable type declaration | READY |
| @_lifetime annotations | READY |
| ~Escapable + Sendable | READY (confirmed) |
| ~Escapable + @escaping closure storage (immortal lifetime) | READY (confirmed in experiment; Resumption deployment **REVERTED** due to downstream collection incompatibility) |
| ~Escapable + async/await (immortal lifetime) | PARTIALLY READY (works with immortal; untested with borrow lifetime across suspension) |
| ~Escapable + consuming func | READY (confirmed in experiment; Resumption deployment **REVERTED**) |
| Optional<~Copyable + ~Escapable> | READY (SE-0465, confirmed) |
| Conditional Escapable conformance (inline containers) | READY (Box, Pair — confirmed) |
| **Enum-based variable-occupancy storage** | **READY** (v2.1.0 — `pointer-nonescapable-storage` V14/V15) |
| Closure parameter lifetime dependencies | NOT READY (Gap A — still blocked on 6.2.4) |
| Closure context capture — stored | NOT READY (Gap B — still blocked on 6.2.4) |
| Closure context capture — immediately-invoked | **READY** (Gap B+ — **new on 6.2.4**) |
| Non-escaping closure storage in types | NOT READY (not proposed) |
| `UnsafeMutablePointer<T: ~Escapable>` | **NOT READY** (blocker confirmed — FIXME in compiler, SE-0465 deferred, no feature flag) |
| `Optional<Element>` stored in ~Escapable container | **NOT READY** (v2.1.0 — lifetime escape even with non-nil init) |
| `InlineArray<N, Element: ~Escapable>` | **NOT READY** (implicit Escapable on Element) |
| `@_rawLayout` declaration with `~Escapable` | **READY** (v2.1.0 — layout compiles, `MemoryLayout` correct) |
| `@_rawLayout` element access with `~Escapable` | **NOT READY** (layout-vs-access gap — access requires typed pointers with implicit Escapable) |
| ~Escapable generics (inline containers) | READY (confirmed) |
| ~Escapable generics (heap-backed containers) | NOT READY (blocked by UnsafeMutablePointer constraint) |
| Ecosystem readiness (~Copyable preconditions) | READY (most candidates already ~Copyable) |

**Overall (v2.3.0)**: **No async type is currently ~Escapable.** The `Async.Waiter.Resumption` `~Escapable` deployment was reverted — downstream consumers (cache/pool) collect Resumptions into dynamic arrays (`[Resumption]`), which are heap-backed and require `Element: Escapable`. This demonstrates that the pointer Escapable blocker has **cascade consequences** beyond just blocking ~Escapable container types — it also prevents storing ~Escapable values in ANY existing collection (Swift.Array, Array_Primitives, Buffer.Ring, Drain, etc.). The blocker is a **stdlib-level** limitation (not a feature flag), with a FIXME in the compiler and explicit deferral in SE-0465. Enum-based variable-occupancy storage works for small fixed capacities (2-8). `@_rawLayout` is the correct future solution (layout compiles, element access blocked). **No further async ~Escapable adoption should be attempted until `UnsafeMutablePointer` gains `~Escapable` support.**

## References

- Pointfree #355: Beyond Basics: Isolation, ~Copyable, ~Escapable (Feb 23, 2026)
- Pointfree #356: Beyond Basics: Superpowers (Feb 2026) — ~Copyable + ~Escapable SQLite Reader/Writer pattern
- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable generics
- SE-0446: Non-escapable types
- SE-0447: Span -- Safe access to contiguous storage
- SE-0456: Lifetime dependency annotations (@_lifetime)
- SE-0465: Noncopyable/non-escapable Optional (enables `Optional<~Escapable>`)
- SE-0474: Import non-copyable and non-escapable C/C++ types (partial)
- `https://github.com/swift-primitives/swift-memory-primitives/blob/main/Research/lifetime-dependent-borrowed-cursors.md` -- Closure integration gap analysis
- `https://github.com/swift-primitives/swift-memory-primitives/blob/main/Research/span-access-abstraction.md` -- Span access patterns
- `https://github.com/swift-primitives/swift-kernel-primitives/blob/main/Sources/Kernel Primitives/Kernel.Path.View.swift` -- Existing ~Escapable type in ecosystem
- `https://github.com/swift-primitives/swift-sequence-primitives/blob/main/Sources/Sequence Primitives Standard Library Integration/Swift.Span.Iterator.swift` -- Existing ~Escapable iterator
- `https://github.com/swift-primitives/swift-sequence-primitives/blob/main/Sources/Sequence Primitives Core/Sequence.Map.swift` -- Canonical conditional Escapable pattern
- `Experiments/nonescapable-closure-storage/` -- Experiment: ~Escapable edge case validation (2026-02-25)
- `Experiments/resumption-nonescapable-noncopyable/` -- Experiment: Resumption ~Copyable + ~Escapable (2026-03-02)
- `Experiments/conditional-escapable-container/` -- Experiment: Conditional Escapable containers (2026-03-02)
- `Experiments/nonescapable-gap-revalidation-624/` -- Experiment: Gap A/B re-validation on Swift 6.2.4 (2026-03-02)
- `https://github.com/swift-primitives/Experiments/tree/main/nonescapable-edge-cases/` -- Experiment: ~Escapable edge cases (2026-02-28)
- `Experiments/pointer-nonescapable-storage/` -- Experiment: Exhaustive storage mechanism test including @_rawLayout (2026-03-02, v2.2.0)
- `Research/nonescapable-storage-mechanisms.md` -- Research: Storage mechanisms analysis including @_rawLayout gap (2026-03-02, v1.1.0)
- Swift compiler source: `swiftlang/swift/lib/ClangImporter/ImportType.cpp:507` -- FIXME confirming pointer ~Escapable gap
- SE-0437: Noncopyable Standard Library Primitives (pointer ~Copyable support without ~Escapable)
