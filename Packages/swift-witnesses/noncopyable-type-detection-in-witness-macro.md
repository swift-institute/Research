# Noncopyable Type Detection in @Witness Macro

<!--
---
version: 3.0.0
last_updated: 2026-03-04
status: DECISION
---
-->

## Context

The `@Witness` macro generates `Action` and `Action.Result` enums with associated values. `~Copyable` types cannot appear as associated values of a Copyable enum. The macro must either detect `~Copyable` types and handle them differently, or generate code that works for both Copyable and `~Copyable` types without distinguishing.

The current approach uses an inference heuristic: any type appearing with `borrowing`/`consuming` parameter annotations is assumed `~Copyable`. This fails for factory-only witnesses where the `~Copyable` type appears only as a return type.

## Question

What does a theoretically perfect implementation look like — deterministic, correct in all cases, no heuristic? And what is the path to achieving it?

## Fundamental Constraint

The observe pattern generates closures that must **return the result to the caller** AND **pass it to the observer**:

```swift
fetch: { [witness] (id) throws(E) -> String in
    let action: Action = .fetch(id)
    do {
        let result = try await witness.fetch(id)
        after(Action.Outcome(action: action, result: .fetch(.success(result))))
        return result
    } catch {
        after(Action.Outcome(action: action, result: .fetch(.failure(error))))
        throw error
    }
}
```

For Copyable types, `result` is implicitly copied — one copy goes to the Outcome, one is returned. For `~Copyable` types, `result` has exactly one owner. It cannot be both stored in the Outcome and returned. **This is a language-level semantic truth, not a macro limitation.**

Therefore, the generated code MUST differ for `~Copyable` return types — either by substituting Void in the Result (current approach) or by using a borrowing observation pattern.

## Analysis

### Path 1: Perfect Detection (macro knows which types are `~Copyable`)

#### 1a. Semantic information from the compiler

Swift macros execute **before type checking** by design. `MacroExpansionContext` exposes:
- `makeUniqueName`, `diagnose`, `location`, `lexicalContext`, `buildConfiguration`

It does NOT expose: type resolution, conformance checking, member lookup, or any semantic analysis. `lexicalContext` explicitly strips member blocks from enclosing types.

`SwiftLexicalLookup` provides unqualified name matching only — no type information.

The compiler plugin communication protocol (`CompilerPluginMessageHandler`) transmits only syntax nodes, lexical context (stripped), build configuration, and diagnostics. No semantic data crosses the boundary.

**Verdict**: No path forward in current Swift. This is architectural — macros are sandboxed from the type checker.

#### 1b. External tooling (SourceKit, build tool plugins)

SourceKit provides `source.request.cursorinfo` with full type information, but operates in the IDE layer, not during compilation. Build tool plugins run before compilation but generate source files — they could theoretically invoke SourceKit, but this would couple the build to SourceKit availability and add significant latency.

**Verdict**: Theoretically possible but architecturally wrong — fragile, slow, and couples compilation to IDE infrastructure.

#### 1c. Explicit declaration (user tells the macro)

```swift
@Witness(noncopyable: UniqueResource.self)
struct Factory: Sendable {
    let create: @Sendable () -> UniqueResource
}
```

Parse `.self` expressions from the attribute. Union with heuristic.

**Verdict**: Deterministic, works in all cases. But shifts burden to the user. Pragmatic fallback.

### Path 2: Generated Code Works for Both (no detection needed)

#### 2a. Make Action.Result always `~Copyable`

```swift
public enum Result: ~Copyable, Sendable {
    case fetchSuccess(String)
    case fetchFailure(Error)
    case createSuccess(NoncopyableHandle)
    case createFailure(Error)
}
```

Swift 6 supports `~Copyable` enums with `~Copyable` associated values. This compiles for all types.

**But**: The observer still needs the result value. Constructing `Outcome(action:, result: .createSuccess(result))` consumes `result`, so we can't return it to the caller. The fundamental constraint from above applies.

For the observer to borrow the result without consuming it, we need the **borrow-observe-return** pattern:

```swift
create: { [witness] () throws(E) -> NoncopyableHandle in
    let result = try witness._create()
    // Observer borrows result, then we return it
    withBorrow(of: result) { ref in
        after(action: .create, resultRef: ref)
    }
    return result
}
```

This requires `@_lifetime(borrow)` / lifetime dependence — still experimental in Swift 6.2.

**Verdict**: Achievable in principle. Blocked by lifetime dependence being experimental. Changes the observer API signature.

#### 2b. Separate the result from the observation

Don't put the return value in `Action.Outcome` at all. The observer receives:
- **Before**: `Action` (what operation, with Copyable argument values) — unchanged
- **After**: `Action` + success/failure status — but NOT the result value

```swift
public struct Outcome: Sendable {
    public let action: Action
    public let succeeded: Bool
    public let error: (any Error)?
}
```

This always compiles, is always Copyable, and never needs to know about `~Copyable`.

**Tradeoff**: Observers lose access to success values. For Copyable types, this is a regression — currently observers CAN inspect `result: .fetch(.success("value"))`. This matters for logging, metrics, side effects.

**Verdict**: Deterministic but lossy. Not acceptable as the only option.

#### 2c. Conditional design: rich Outcome for Copyable, simple for `~Copyable`

The ideal: generate rich `Result<Success, Failure>` when Success is Copyable, and omit the value when it's `~Copyable`. This IS what the current code does — the question is detection.

With a `~Copyable` Result enum and conditional Copyable conformance:
```swift
enum MaybeResult<T: ~Copyable>: ~Copyable {
    case success(T)
    case failure(any Error)
}
extension MaybeResult: Copyable where T: Copyable {}
```

But `Action.Result` has HETEROGENEOUS cases — different return types per action. You can't express conditional conformance over "all associated value types are Copyable" without a single generic parameter.

**Verdict**: Doesn't compose with heterogeneous enums. Would require per-action Result types instead of a unified enum.

#### 2d. Per-action Result types

Instead of one `Action.Result` enum, generate per-action result types:

```swift
public enum Action: Sendable {
    case fetch(Int)
    case create

    // Per-action Result:
    public struct FetchResult: Sendable {
        public let value: Swift.Result<String, Error>
    }
    public struct CreateResult: ~Copyable, Sendable {
        public let value: Swift.Result<NoncopyableHandle, Error>  // ~Copyable Result
    }
}
```

Wait — `Swift.Result` requires `Success: Copyable`. A custom `Result<Success: ~Copyable>: ~Copyable` is needed:

```swift
// Generated helper
public enum ActionResult<Success: ~Copyable, Failure: Error>: ~Copyable {
    case success(Success)
    case failure(Failure)
}
extension ActionResult: Copyable where Success: Copyable {}
```

Then the Outcome carries a typed, per-action result. But this changes the Outcome type significantly — it becomes generic or existential, losing the clean `switch outcome.result { case .fetch(.success(let v)): ... }` pattern.

**Verdict**: Technically sound but significantly complicates the generated API. Loses the unified switch-based observation pattern.

### Path 3: Theoretical Ideal

The theoretically perfect implementation combines:

1. **`~Copyable` Action.Result enum** — always use actual types, never substitute Void
2. **Borrowing observation** — observer borrows the result value, caller retains ownership
3. **Conditional Copyable conformance** — Result is Copyable when all return types are, `~Copyable` otherwise

The generated observe closure:
```swift
create: { [witness] () throws(E) -> NoncopyableHandle in
    let action: Action = .create
    do {
        let result = try witness._create()
        // Borrow result for observer, then return to caller
        after(action, borrowing: result)
        return result
    } catch {
        after(action, error: error)
        throw error
    }
}
```

The observer signature:
```swift
after: @Sendable (Action, borrowing some ~Copyable) -> Void
// or with lifetime dependence:
after: @Sendable (borrowing Action.Outcome) -> Void
```

**Requirements**:
- Stable lifetime dependence (`@_lifetime`) to create Outcome that borrows result
- `borrowing` closure parameters (supported in Swift 6)
- `~Copyable` enum associated values (supported since Swift 5.8)
- Conditional Copyable conformance on generated enums (supported)

**Blocking**: `@_lifetime` is experimental. Without it, you cannot create an Outcome struct that borrows a local variable's value and passes it to a closure.

**Partial unblock**: If the observer takes `(Action, borrowing Success)` instead of `(Action.Outcome)`, lifetime dependence isn't needed — the borrow is direct. But then the observer signature is per-action rather than unified.

## Comparison

| Criterion | Heuristic (current) | Explicit arg | Always ~Copyable | Borrowing (ideal) |
|-----------|:---:|:---:|:---:|:---:|
| Deterministic | NO | YES | YES | YES |
| All cases | NO | YES | YES | YES |
| No user burden | YES | NO | YES | YES |
| Rich observation | YES | YES | NO | YES |
| Stable Swift | YES | YES | YES | NO (`@_lifetime`) |
| No API change | YES | YES | NO | NO |

## Experimental Verification

All patterns verified in `Research/borrowing-observation-experiment/` (Swift 6.2.4, Lifetimes feature enabled — already active in swift-witnesses Package.swift).

### Pattern A: Direct borrow passing — WORKS

```swift
func withObservation(
    create: () -> Handle,
    observe: (borrowing Handle) -> Void
) -> Handle {
    let result = create()
    observe(result)   // borrows result
    return result     // result still available — not consumed
}
```

The compiler understands that `observe(result)` borrows rather than consumes. The caller can return the value after the observer is done.

**Limitation**: Tuples with `~Copyable` elements are not supported in Swift 6.2. Cannot write `-> (Handle, R)`. Workaround: `inout` parameter.

### Pattern B: `~Escapable` observation wrapper — WORKS

```swift
struct Observation: ~Copyable, ~Escapable {
    let fd: Int
    @_lifetime(borrow handle)
    init(of handle: borrowing Handle) { self.fd = handle.fd }
}
```

### Pattern C: Enum with conditional Copyable — WORKS

```swift
enum ActionResult<T: ~Copyable>: ~Copyable {
    case success(T)
    case failure(any Error)
}
extension ActionResult: Copyable where T: Copyable {}
```

When `T` is Copyable (e.g., `ActionResult<Int>`), the type is implicitly Copyable. When `T` is `~Copyable`, the enum is `~Copyable` and requires `consuming` extraction.

## Outcome

**Status**: DECISION — Implemented 2026-03-04

### Decision: Eliminate the heuristic with borrow-then-consume-extract pattern

The heuristic (`collectNoncopyableTypeNames`) has been deleted. The macro now generates uniform code that works for ALL types — Copyable and `~Copyable` — without detection.

**Commits**:
- `60a62eb` — "Eliminate ~Copyable heuristic: uniform borrowing observation pattern"
- `687e2ba` — "Add ~Copyable-aware Result type as Swift.Result drop-in replacement" (swift-standard-library-extensions)
- `e3d73cb` — "Add Standard_Library_Extensions dependency and @_exported re-export" (swift-witness-primitives)
- `e084ea1` — "Move Result type to Standard_Library_Extensions, update macro references" (swift-witnesses)

### What was implemented

1. **`Result<Success: ~Copyable, Failure: Error>`** in `swift-standard-library-extensions` — drop-in replacement for `Swift.Result` that supports `~Copyable` success values. Full API parity: `.get()`, `.map()`, `.flatMap()`, `.mapError()`, `.flatMapError()`, `init(catching:)`. Conditional conformances: `Copyable where Success: Copyable`, `Sendable where Success: Sendable, Failure: Sendable`. Shadows `Swift.Result` across the ecosystem via existing `@_exported` chains — intentional, as this is the strictly more general type. `Witness_Primitives` re-exports `Standard_Library_Extensions` so all `@Witness` consumers get the type transitively.

2. **`Action.Result: ~Copyable, Sendable`** — always uses actual return types (no more Void substitution). Cases use `Standard_Library_Extensions.Result<T, E>` (fully qualified in generated code to avoid inference issues with `~Copyable` enums).

3. **`Action.Outcome: ~Copyable, Sendable`** — with `consuming func __consumeResult() -> Result` accessor for extracting the result after observation.

4. **Observer closures take `borrowing Action.Outcome`** — can inspect action and result via borrowing, cannot store the Outcome itself. For Copyable types, `borrowing` is a no-op.

5. **Borrow-then-consume-extract pattern** in observe closures:
```swift
fetch: { [witness] (id) throws(E) -> String in
    let action: Action = .fetch(id)
    do throws(E) {
        let result = try await witness.fetch(id)
        let __outcome = Action.Outcome(action: action,
            result: Action.Result.fetch(Standard_Library_Extensions.Result<String, E>.success(result)))
        after(__outcome)                              // borrows __outcome
        let __result = __outcome.__consumeResult()    // consumes __outcome
        switch consume __result {
        case .fetch(.success(let __value)): return __value
        default: fatalError("unreachable")
        }
    } catch {
        let __outcome = Action.Outcome(action: action,
            result: Action.Result.fetch(Standard_Library_Extensions.Result<String, E>.failure(error)))
        after(__outcome)
        throw error
    }
}
```

6. **`do throws(E) { ... }` blocks** — required because `error` in catch blocks inside closures is `any Error` even with typed throws. The `do throws(E)` syntax properly types the catch variable.

### Resolved open questions

1. **How to express Outcome**: `~Copyable` struct with `consuming __consumeResult()` accessor. No `~Escapable` needed — the borrow-then-consume pattern avoids lifetime dependence.
2. **Heterogeneous return types**: `Action.Result` is a concrete (non-generic) `~Copyable` enum. No conditional Copyable on the enum — it is always `~Copyable`. This is acceptable because observer borrows the Outcome, and Copyable values are implicitly copied when pattern-matched from a borrowed enum.
3. **`borrowing` + `async` + `@Sendable`**: Yes, composes correctly. Validated in tests.
4. **Observer closure storage**: `@escaping @Sendable (borrowing Action.Outcome) -> Void` works in stored properties. No restrictions from `borrowing` on closure capture.

### Key discoveries during implementation

- `switch consume value.method()` does NOT compile — `consume` requires storage, not expression results. Fix: `let __result = value.method(); switch consume __result { ... }`
- `error` in catch blocks inside closures is always `any Error`, even when the closure declares `throws(E)`. Fix: `do throws(E) { ... } catch { ... }` properly types the catch variable.
- Fully-qualified `Standard_Library_Extensions.Result<T, E>.success(...)` needed in generated code — type inference through `~Copyable` enum constructors is weaker than for Copyable types.

### Verification

- 125/125 tests pass (+2 new tests validating ~Copyable observe.after)
- IO.Event.Driver builds clean
- IO.Completion.Driver builds clean (289 errors from previous session were resolved by this change — they were caused by `Witness.Result` living in `Witnesses` module which was imported internally, making it invisible in public macro-generated code)

## References

- `SuppressedTypeSyntax` in SwiftSyntax: `swift-syntax/Sources/SwiftSyntax/generated/syntaxNodes/SyntaxNodesQRS.swift`
- `MemberMacro` protocol: `swift-syntax/Sources/SwiftSyntaxMacros/MacroProtocols/MemberMacro.swift`
- `MacroExpansionContext`: `swift-syntax/Sources/SwiftSyntaxMacros/MacroExpansionContext.swift` — confirmed no type-checking APIs
- `CompilerPluginMessageHandler`: `swift-syntax/Sources/SwiftCompilerPluginMessageHandling/` — confirmed no semantic data in plugin protocol
- `SwiftLexicalLookup`: `swift-syntax/Sources/SwiftLexicalLookup/` — unqualified name lookup only
- `~Copyable` enum tests: `swiftlang/swift/test/SILGen/moveonly.swift`, `moveonly_consuming_switch.swift`
- Conditional Copyable conformance: `swiftlang/swift/test/SILGen/conditionally_copyable_conformance_descriptor.swift`
- Borrowing closures: `swiftlang/swift/test/Sema/lifetime_dependence_functype.swift`
- Borrowing switch: `swiftlang/swift/test/SILGen/borrowing_switch_subjects.swift`
- ~~Current heuristic: `WitnessMacro.swift`, `collectNoncopyableTypeNames`~~ (deleted)
- IO.Event.Driver (real-world consumer): `swift-foundations/swift-io/`
- `Result<Success: ~Copyable>`: `swift-standard-library-extensions/Sources/Standard Library Extensions/Result.swift`
