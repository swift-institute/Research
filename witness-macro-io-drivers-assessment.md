# @Witness Macro Adoption for IO Drivers — Assessment

<!--
---
version: 1.0.0
last_updated: 2026-03-04
status: DEFERRED
tier: 1
methodology: RES-004
depends_on: next-steps-witnesses.md, adoption-implementation-review.md
---
-->

## Context

`IO.Event.Driver` and `IO.Completion.Driver` are manually-constructed protocol witnesses in swift-io (Layer 3). Both conform to `Witness.Protocol` and `Witness.Key`, but neither uses the `@Witness` macro. The next-steps-witnesses.md document (v2.0.0) rated macro adoption as "Future — manual forwarding already exists, macro adds incremental value only."

This document investigates whether that assessment holds under scrutiny.

## Question

Could the `@Witness` macro ever be applied to `IO.Event.Driver` and `IO.Completion.Driver`, and if so, what value would it add over the current manual implementation?

---

## Analysis

### 1. Current Driver Structure

**IO.Event.Driver** (`IO.Event.Driver.swift`, 278 lines):
- 8 closure properties (`_create`, `_register`, `_modify`, `_deregister`, `_arm`, `_poll`, `_close`, `_createWakeupChannel`)
- 1 non-closure stored property (`capabilities: Capabilities`)
- 8 forwarding methods (public API)
- Manual `init` with all closure parameters
- 2 platform factory methods (`kqueue()`, `epoll()`)

**IO.Completion.Driver** (`IO.Completion.Driver.swift`, 185 lines):
- 6 closure properties (`_create`, `_submitStorage`, `_flush`, `_poll`, `_close`, `_createWakeupChannel`)
- 1 non-closure stored property (`capabilities: Capabilities`)
- 7 forwarding methods (public API; includes 2 `submit` overloads, one taking `consuming Operation`)
- Manual `init` with all closure parameters

### 2. Ownership Conventions in Closures

Both drivers use `borrowing` and `consuming` parameter conventions in their closure types:

**borrowing Handle** (IO.Event.Driver):
```swift
let _register: @Sendable (borrowing Handle, Int32, Interest) throws(IO.Event.Error) -> ID
let _modify:   @Sendable (borrowing Handle, ID, Interest) throws(IO.Event.Error) -> Void
let _deregister: @Sendable (borrowing Handle, ID) throws(IO.Event.Error) -> Void
let _arm:      @Sendable (borrowing Handle, ID, Interest) throws(IO.Event.Error) -> Void
let _poll:     @Sendable (borrowing Handle, Deadline?, inout [IO.Event]) throws(IO.Event.Error) -> Int
let _createWakeupChannel: @Sendable (borrowing Handle) throws(IO.Event.Error) -> Wakeup.Channel
```

**consuming Handle** (IO.Event.Driver):
```swift
let _close: @Sendable (consuming Handle) -> Void
```

The `Handle` types are `~Copyable`:
- `IO.Event.Driver.Handle: ~Copyable, Sendable` (line 27 of `IO.Event.Driver.Handle.swift`)
- `IO.Completion.Driver.Handle: ~Copyable, @unchecked Sendable` (line 30 of `IO.Completion.Driver.Handle.swift`)

IO.Completion.Driver additionally has `inout [Event]` in `_poll` and `Operation.Storage` (Copyable) in `_submitStorage`. Its public API also has a `consuming Operation` parameter on the convenience `submit` overload.

### 3. What the @Witness Macro Currently Generates

The macro (`WitnessMacro` in `WitnessMacro.swift`, ~1300 lines) generates the following for structs:

| Generated Artifact | Description |
|-------------------|-------------|
| **Public init** | Memberwise initializer with `@escaping` for closure properties |
| **Forwarding methods** | For closures with labeled parameters (`_ name:` convention) |
| **Action enum** | One case per closure, with associated values from closure parameters (ownership stripped via `baseType`) |
| **Action.Case** | Enumerable discriminant conforming to `Finite.Enumerable` |
| **Action.Result** | Typed result enum with `Swift.Result<Success, Failure>` per action |
| **Action.Outcome** | Pairs action with its typed result |
| **Action.Prisms** | Optic prisms for each action case |
| **Observe struct** | `before`/`after`/both observation wrappers |
| **unimplemented()** | Static method returning a witness where all closures throw `Witness.Unimplemented.Error` |
| **mock()** | (With `.mock` derive) Static method taking return values instead of closures |
| **constant()** | (With `.generator` derive) Static method for single-closure witnesses |

### 4. Macro's Handling of Ownership Specifiers

The macro already parses `borrowing` and `consuming` (lines 610-633 of `WitnessMacro.swift`):

```swift
case .keyword(.borrowing):
    ownership = .borrowing
case .keyword(.consuming):
    ownership = .consuming
```

It stores ownership in `ClosureParameter.ownership` and provides `baseType` to strip specifiers for Action enum associated values and prisms. The generated forwarding methods preserve the full `param.type` (including ownership specifiers) in their parameter lists.

**This means the macro already handles `borrowing` and `consuming` parameters syntactically.**

### 5. The Real Blockers

Despite the macro parsing ownership specifiers correctly, there are structural incompatibilities:

#### 5a. ~Copyable Types in Observe Closures

The `Observe` struct captures `[witness]` in closure capture lists and constructs new instances by reconstructing all closure properties. The Action enum uses associated values with `baseType` (ownership stripped). But `~Copyable` types like `Handle` cannot appear as associated values in an enum (Swift limitation: enum associated values must be `Copyable`).

Specifically, `IO.Event.Driver.Handle` appears as a `borrowing` parameter in 6 of 8 closures. The Action enum would need:
```swift
case register(Handle, Int32, Interest)  // Handle is ~Copyable — ILLEGAL
```

This is a **Swift language limitation**, not a macro limitation. The macro correctly strips ownership to get `baseType`, but the underlying type is still `~Copyable`.

#### 5b. Observe Wrapper Cannot Forward borrowing/consuming

The Observe closures wrap the original closures with before/after callbacks. They capture `[witness]` and forward arguments. But forwarding a `borrowing` parameter through a closure requires the outer closure to also declare the parameter as `borrowing`, and the inner call must use `copy` or forward ownership correctly. The current macro does not emit ownership specifiers on the generated closure parameter bindings.

More critically, `consuming` parameters cannot be forwarded through an observation wrapper — the observer would need to see the parameter before it is consumed, but once consumed, it cannot be observed.

#### 5c. unimplemented() Cannot Accept ~Copyable in Closure Signatures

The `unimplemented()` method generates closures like `{ (_, _, _) throws(E) -> T in throw ... }`. For closures taking `borrowing Handle`, the wildcard parameter binding works. But there is a subtlety: the closure type itself must match the stored property type exactly, including ownership specifiers. The macro generates wildcard parameters (`_`) without ownership annotations, which the compiler may reject when the closure type expects `borrowing` or `consuming` parameters.

#### 5d. The submit(operation: consuming Operation) Overload

`IO.Completion.Driver` has a convenience `submit(_:operation:)` method that takes a `consuming Operation` — this is not a closure property but a manually-written public API method that extracts `.storage` from the consumed operation. The macro only generates forwarding for closure properties; it cannot synthesize arbitrary convenience methods.

### 6. What the Macro Would Eliminate vs. What Remains Manual

| Component | Event Driver (lines) | Completion Driver (lines) | Macro Could Generate? |
|-----------|---------------------|--------------------------|----------------------|
| Closure stored properties | 31 | 21 | NO — these are the input, not output |
| Public init | 21 | 17 | YES (already does this) |
| Forwarding methods | 52 | 41 | YES (already does this) |
| Action enum | 0 (not present) | 0 (not present) | BLOCKED — ~Copyable associated values |
| Observe struct | 0 (not present) | 0 (not present) | BLOCKED — cannot forward borrowing/consuming through observation |
| unimplemented() | 0 (not present) | 0 (not present) | PARTIAL — closure type matching uncertain |
| Platform factories | 22+22 | (separate files) | NO — platform-specific, manual |
| Witness.Key conformance | 38 | 43 | NO — platform-specific, manual |
| Convenience submit overload | N/A | 8 | NO — manual convenience |

**Lines the macro could reliably eliminate: ~73 (init) + ~93 (forwarding methods) = ~166 lines across both drivers.**

**Lines that must remain manual: ~154 lines (closure declarations, platform factories, Witness.Key, convenience methods).**

**Features the macro would add but cannot generate: Action enum, Observe, unimplemented(). These are the primary value proposition of the macro, and they are all blocked.**

### 7. Incremental Value Assessment

If the macro were applied only for init + forwarding (suppressing Action/Observe/unimplemented), the value would be:

- **Reduced boilerplate:** ~166 lines saved. But these are the simplest, most mechanical parts of the code.
- **Lost documentation:** The manual init and methods have doc comments explaining thread safety, parameter semantics, and the ownership model. The macro does not carry these comments.
- **No test ergonomics improvement:** The key test-facing features (unimplemented(), mock(), Observe) are all blocked.
- **Increased cognitive cost:** A reader encountering `@Witness` on a driver type would expect the full macro feature set to be available, but would find that Action, Observe, and unimplemented() are all absent or broken.

---

## Comparison

| Criterion | Manual (current) | @Witness (hypothetical) |
|-----------|-----------------|------------------------|
| Correctness | Complete, verified | Partial — Action/Observe/unimplemented blocked |
| Lines of code | ~320 across both files | ~154 manual + macro expansion |
| Documentation | Full doc comments on all methods | Lost on generated methods |
| Test doubles | `testValue` with fatalError stubs | Same — unimplemented() blocked |
| Observation | Not present (not needed — poll thread only) | Blocked even if wanted |
| Maintainability | Clear, explicit, greppable | Mixed — some generated, some manual |
| ~Copyable safety | Manually correct borrowing/consuming | Relies on macro passing through specifiers correctly |
| Reader comprehension | Everything visible | Must understand macro limitations to know what is/isn't generated |

---

## Outcome

**Status: DEFERRED**

The `@Witness` macro cannot be meaningfully applied to the IO drivers. The blockers are:

1. **Swift language limitation:** `~Copyable` types cannot appear as enum associated values, which prevents Action enum generation.
2. **Ownership forwarding in Observe:** `borrowing`/`consuming` parameters cannot be transparently forwarded through observation wrappers.
3. **Value proposition inversion:** The features that *could* be generated (init, forwarding) are the least valuable; the features that *cannot* be generated (Action, Observe, unimplemented) are the primary macro value.

The original assessment in next-steps-witnesses.md was correct: "manual forwarding already exists, macro adds incremental value only." This investigation strengthens that conclusion — the incremental value is not only small but comes with documentation loss and reader confusion.

**Revisit when:**
- Swift gains support for `~Copyable` enum associated values (pitched but not yet implemented).
- The `@Witness` macro adds an option to suppress Action/Observe generation for ownership-heavy witnesses.
- A separate `@WitnessLite` macro is introduced that only generates init + forwarding methods.

**No action required.**
