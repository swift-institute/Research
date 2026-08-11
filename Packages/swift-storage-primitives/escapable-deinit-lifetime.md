# ~Escapable Values in deinit: Lifetime-Dependence Limitation

<!--
---
version: 3.0.0
last_updated: 2026-02-23
status: DECISION
---
-->

## Context

`Storage.Inline` has no deinit — the consuming buffer type owns element cleanup (documented in `Research/inline-deinit-ownership.md`). The existing `_deinitializeTrackedSlots()` is a `public` method posing as internal API (underscore prefix).

The `Property.View(borrowing:)` change enables non-mutating accessors for `Property.View`, which seemed like the right tool to create a proper deinitialize path usable from deinit. The goal: replace `_deinitializeTrackedSlots()` with `storage.deinitialize()` via a property accessor returning `Property.View`.

## Question

Can `~Escapable` values (like `Property.View`) be used in deinit when they borrow stored properties of `self`?

## Analysis

### Experiment

`Experiments/escapable-deinit-lifetime/` tested 18 variants systematically. (SUPERSEDED — consolidated into `swift-buffer-primitives/Experiments/rawlayout-deinit-alternatives/` V03-escapable-lifetime)

### Findings

**Every standard construction method for `~Escapable` values fails in deinit:**

| Variant | Construction | Result |
|---------|-------------|--------|
| V1 | `_read` accessor + MutView | REFUTED |
| V2 | `_read` accessor + ConstView | REFUTED |
| V3 | Inline MutView construction | REFUTED |
| V4 | Inline ConstView construction | REFUTED |
| V5 | `borrowing func` | REFUTED |
| V8 | `_read` + `callAsFunction` | REFUTED |
| V10 | `_overrideLifetime` in deinit | REFUTED |
| V13 | `_overrideLifetime` immortal-like | REFUTED |
| V16 | `_read` delegating to `@_unsafeNonescapableResult` func | REFUTED |

The error is always: `lifetime-dependent value escapes its scope`. V16 is notable: even when the underlying func has `@_unsafeNonescapableResult`, the `_read` coroutine's yield re-establishes lifetime dependence on the yielded value.

**Patterns that work:**

| Variant | Pattern | Result |
|---------|---------|--------|
| V6 | Plain non-mutating method | CONFIRMED |
| V7 | Method that creates `~Escapable` internally | CONFIRMED |
| V9 | `withUnsafePointer` closure | CONFIRMED |
| V11 | `@_unsafeNonescapableResult` on `borrowing func` | CONFIRMED |
| V12 | `withUnsafePointer` + view in closure | CONFIRMED |
| V17 | `@_unsafeNonescapableResult` on `get` accessor | CONFIRMED |
| V18 | `@_unsafeNonescapableResult get` + `mutating _modify` | CONFIRMED |

**Compiler bugs:**

| Variant | Pattern | Result |
|---------|---------|--------|
| V14 | `@_unsafeNonescapableResult` on `_read` accessor | CRASH |
| V15 | Combined `_read` + `_modify` with attribute on `_read` | CRASH |

V14/V15 crash with: `Assertion failed: (unsafe apply result must be owned)` in `LifetimeDependenceUtils.swift:173`. The SIL pass assumes `@_unsafeNonescapableResult` results are `@owned`, but `_read` coroutines yield `@guaranteed` values.

### Root Cause

Swift's lifetime-dependence analysis treats `self` in deinit as having a constrained lifetime scope. Any `~Escapable` value whose `@_lifetime(borrow base)` dependency chains back to a stored property of `self` is considered to "escape" the deinit scope.

### Key Discovery: `get` vs `_read` (V17/V18)

`@_unsafeNonescapableResult` works on `get` but crashes on `_read` because:
- `get` returns an `@owned` value — the attribute suppresses lifetime tracking on the owned result
- `_read` yields a `@guaranteed` value — the SIL pass asserts that `@_unsafeNonescapableResult` results are owned

V18 proves the full pattern: `@_unsafeNonescapableResult get` for non-mutating access (deinit) + `mutating _modify` for tracked operations (bit clearing), on the same property.

```swift
var deinitialize: Property<Storage.Deinitialize, Self>.View {
    @_unsafeNonescapableResult
    get {
        unsafe Property<Storage.Deinitialize, Self>.View(borrowing: self)
    }
    mutating _modify {
        var view = unsafe Property<Storage.Deinitialize, Self>.View(&self)
        yield &view
    }
}
```

The `get` accessor is slightly less efficient than `_read` (owned copy vs guaranteed borrow), but for the deinitialize use case — called once at end of life — this is irrelevant.

## Outcome

**Status**: DECISION

### Solution: `@_unsafeNonescapableResult get` + `mutating _modify`

The `deinitialize` property uses:
- `@_unsafeNonescapableResult get` — suppresses lifetime diagnostics, enabling deinit use
- `mutating _modify` — unchanged, for tracked operations that clear bits

### Call Site

```swift
// deinit — uses get path (non-mutating, no bit clearing)
deinit {
    unsafe storage.deinitialize()
}

// mutating context — uses _modify path (tracked, clears bits)
storage.deinitialize(at: slot)
storage.deinitialize.all()
```

### Trade-off: `get` vs `_read`

`get` returns an owned copy; `_read` yields a borrow. For Property.View (which wraps a single pointer), the cost difference is negligible. The `_read` path would be semantically cleaner, but is blocked by a compiler bug (V14). When fixed, the `get` can be replaced with `@_unsafeNonescapableResult _read`.

### Compiler Bug

`@_unsafeNonescapableResult` on `_read` accessor triggers assertion failure. The attribute is syntactically valid for `OnAccessor` declarations but the `LifetimeDependenceDiagnostics` SIL pass assumes `@_unsafeNonescapableResult` results are `@owned`.

## References

- `Research/inline-deinit-ownership.md` — Storage.Inline has no deinit by design
- `Experiments/escapable-deinit-lifetime/` — Empirical verification (18 variants) (SUPERSEDED — consolidated into `swift-buffer-primitives/Experiments/rawlayout-deinit-alternatives/` V03-escapable-lifetime)
- Swift Evolution: Lifetime Dependence (SE-0456) — `@_lifetime` semantics
- `swift/include/swift/AST/Attr.def` — `@_unsafeNonescapableResult` declaration
- `swift/lib/SIL/Utils/LifetimeDependenceUtils.swift:173` — Crash site for V14/V15
