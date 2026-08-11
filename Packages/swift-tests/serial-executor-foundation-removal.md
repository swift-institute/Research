# Serial Executor Foundation Removal

<!--
---
version: 1.0.0
last_updated: 2026-02-26
status: RECOMMENDATION
---
-->

## Context

`SerialExecutor.swift` is the only file in swift-tests that imports Foundation. It provides `withSerialExecutor()` — a deterministic async testing utility that hooks into the Swift runtime's `swift_task_enqueueGlobal_hook` to redirect all global task enqueues to the main actor.

The Foundation import exists solely for `dlopen` and `dlsym`. No Foundation types (Thread, Date, Data, etc.) are used. The file also carries a platform conditional `#if !os(WASI) && !os(Windows) && !os(Android)` that excludes platforms where the hook may not be available.

**Trigger**: Audit finding F7 — Foundation imports are forbidden.

## Question

How should swift-tests resolve the `swift_task_enqueueGlobal_hook` symbol without importing Foundation?

## Analysis

### Current Implementation

```swift
#if !os(WASI) && !os(Windows) && !os(Android)
import Foundation

nonisolated(unsafe)
private let _taskEnqueueHookPointer: UnsafeMutablePointer<TaskEnqueueHook?> = {
    let handle = dlopen(nil, 0)
    let symbol = dlsym(handle, "swift_task_enqueueGlobal_hook")
    return symbol!.assumingMemoryBound(to: TaskEnqueueHook?.self)
}()
#endif
```

Issues:
1. `import Foundation` — forbidden per ecosystem rules
2. `#if !os(WASI) && !os(Windows) && !os(Android)` — platform conditionals restricted to platform packages
3. `symbol!` — force-unwrap crashes if the runtime symbol is absent
4. Raw `dlopen`/`dlsym` — ecosystem has typed infrastructure for this

### Option A: Use `Loader.Symbol.lookup` from swift-loader

swift-loader (Layer 3, same as swift-tests) provides:

```swift
extension Loader.Symbol {
    public static func lookup(
        name: UnsafePointer<CChar>,
        in scope: Scope
    ) throws(Loader.Error) -> UnsafeRawPointer
}
```

With `Scope.default` searching all loaded libraries (equivalent to `dlopen(nil, 0)` + `dlsym`).

**Implementation sketch**:

```swift
import Loader

nonisolated(unsafe)
private let _taskEnqueueHookPointer: UnsafeMutablePointer<TaskEnqueueHook?>? = {
    guard let symbol = try? Loader.Symbol.lookup(
        name: "swift_task_enqueueGlobal_hook",
        in: .default
    ) else { return nil }
    return UnsafeMutablePointer(
        mutating: symbol.assumingMemoryBound(to: TaskEnqueueHook?.self)
    )
}()
```

**Advantages**:
- Eliminates `import Foundation` entirely
- Eliminates platform conditional — Loader handles platform differences internally
- Failable lookup replaces force-unwrap (graceful degradation on unsupported platforms)
- Uses existing ecosystem infrastructure per [IMPL-INTENT]
- Typed throws per [API-ERR-001]

**Disadvantages**:
- Adds swift-loader as a dependency (one more package)

### Option B: Import Darwin/Glibc directly

```swift
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
```

**Advantages**:
- No new dependency
- Minimal change

**Disadvantages**:
- Introduces platform conditional in swift-tests (forbidden per constraint)
- Still uses raw `dlopen`/`dlsym` when typed infrastructure exists
- Still force-unwraps the symbol

### Option C: Use `@_silgen_name` to import the hook directly

```swift
@_silgen_name("swift_task_enqueueGlobal_hook")
var _swift_task_enqueueGlobal_hook: TaskEnqueueHook?
```

**Advantages**:
- No imports at all
- No dlopen/dlsym needed
- Zero dependencies

**Disadvantages**:
- `@_silgen_name` is underscored/unsupported Swift API
- Assumes the symbol's existence at link time (linker error if absent)
- Doesn't work for weak symbols that may be absent at runtime
- Brittle — symbol name or type could change between Swift runtime versions

### Comparison

| Criterion | A: Loader | B: Darwin/Glibc | C: @_silgen_name |
|-----------|-----------|------------------|------------------|
| Foundation-free | Yes | Yes | Yes |
| No platform conditionals | Yes | No | Yes |
| Uses ecosystem infra | Yes | No | No |
| Graceful degradation | Yes (failable) | No (force-unwrap) | No (linker error) |
| New dependency | swift-loader | None | None |
| Stability | Stable API | Stable API | Underscored/fragile |

## Outcome

**Status**: RECOMMENDATION

**Use Option A** — `Loader.Symbol.lookup` from swift-loader.

**Rationale**:
1. swift-loader is Layer 3 (same layer as swift-tests) — no layering violation
2. Eliminates Foundation AND platform conditionals
3. Failable lookup provides graceful degradation: if the symbol doesn't exist on a platform, `withSerialExecutor` becomes a no-op rather than crashing
4. Follows [IMPL-INTENT] — `Loader.Symbol.lookup` reads as intent; raw `dlsym` reads as mechanism
5. The `#if` platform conditional can be removed entirely — the feature self-disables on unsupported platforms via the failable lookup

**Implementation steps**:
1. Add `swift-loader` dependency to swift-tests `Package.swift`
2. Replace `import Foundation` with `import Loader`
3. Replace raw `dlopen`/`dlsym` with `Loader.Symbol.lookup(name:in:.default)`
4. Make the hook pointer optional (nil = feature unavailable)
5. Remove `#if !os(WASI) && !os(Windows) && !os(Android)` — let the lookup fail gracefully
6. Update `_useSerialExecutor` to handle nil hook pointer

## References

- `Loader.Symbol.lookup`: `/Users/coen/Developer/swift-foundations/swift-loader/Sources/Loader/Loader.Symbol.swift`
- `ISO_9945.Loader.Symbol` (POSIX impl): `/Users/coen/Developer/swift-standards/swift-iso-9945/Sources/ISO 9945 Loader/ISO 9945.Loader.Symbol.swift`
- Current SerialExecutor: `/Users/coen/Developer/swift-foundations/swift-tests/Sources/Tests/SerialExecutor.swift`
