# Feature Flags: CoroutineAccessors, BorrowAndMutateAccessors, UnderscoreOwned

<!--
---
version: 1.0.0
date: 2026-03-03
applies_to: [swift-primitives, swift-foundations]
status: research
---
-->

## Summary

Investigation of three experimental Swift feature flags for potential adoption across
`swift-primitives` and `swift-foundations`. All three relate to property accessor
evolution and ~Copyable type ergonomics.

| Feature | SE Proposal | Status | Verdict |
|---------|------------|--------|---------|
| `CoroutineAccessors` | SE-0474 | Accepted, experimental | **Wait** |
| `BorrowAndMutateAccessors` | Pre-proposal | Experimental | **Wait** |
| `UnderscoreOwned` | None (compiler-internal) | Unstable | **Skip** |

---

## 1. CoroutineAccessors (`yielding borrow` / `yielding mutate`)

### What It Replaces

`_read` and `_modify` are underscored coroutine accessors that yield borrowed or
mutable references. SE-0474 formalizes these as `yielding borrow` and `yielding mutate`.

The transformation is mechanical:

```swift
// Current (underscored)
var value: T {
    _read { yield _value }
    _modify { yield &_value }
}

// SE-0474
var value: T {
    yielding borrow { yield _value }
    yielding mutate { yield &_value }
}
```

For `mutating _read` / `mutating _modify` (the Property.View pattern):

```swift
// Current
var drain: Property<Drain, Self>.View {
    mutating _read {
        yield unsafe Property<Drain, Self>.View(&self)
    }
    mutating _modify {
        var view = unsafe Property<Drain, Self>.View(&self)
        yield &view
    }
}

// SE-0474
var drain: Property<Drain, Self>.View {
    mutating yielding borrow {
        yield unsafe Property<Drain, Self>.View(&self)
    }
    mutating yielding mutate {
        var view = unsafe Property<Drain, Self>.View(&self)
        yield &view
    }
}
```

### Current Usage Counts

#### swift-primitives (Sources only, excluding Experiments/Tests)

| Accessor | Occurrences | Files | Notes |
|----------|-------------|-------|-------|
| `_read {` | 225 | ~100 | Includes both `_read` and `mutating _read` |
| `_modify {` | 169 | ~95 | Includes both `_modify` and `mutating _modify` |
| `mutating _read {` | 156 | ~75 | Property.View pattern dominant |
| `mutating _modify {` | 121 | ~70 | Always paired with `mutating _read` |
| **Total** | **394** | **~130** | |

The non-mutating `_read`/`_modify` count: approximately 69 `_read` and 48 `_modify`
that are NOT `mutating`. These are primarily in:
- `Property.base` accessors (`_read { yield _base }` / `_modify { yield &_base }`)
- Subscript accessors on ~Copyable containers (Array.Static, Buffer.*)
- Simple stored-property forwarding

#### swift-foundations (Sources only)

| Accessor | Occurrences | Files | Notes |
|----------|-------------|-------|-------|
| `_read {` | 2 | 1 | `IO.Blocking.Threads.Acceptance.Queue` |
| `_modify {` | 1 | 1 | Same file |
| `mutating _read {` | 1 | 1 | Same file |
| **Total** | **3** | **1** | Foundations uses these sparingly |

### Representative Examples

**Pattern 1: Property.View accessor (156 instances in primitives)**

File: `swift-primitives/swift-heap-primitives/Sources/Heap Small Primitives/Heap.Small Copyable.swift`, lines 182-228

```swift
public var drain: Drain.View {
    mutating _read { yield unsafe .init(&self) }
    mutating _modify { var view: Drain.View = unsafe .init(&self); yield &view }
}
```

This pattern repeats 8 times in this single file for different operations (drain,
forEach, satisfies, first, reduce, contains, drop, prefix).

**Pattern 2: Subscript on ~Copyable container (14+ instances)**

File: `swift-primitives/swift-array-primitives/Sources/Array Static Primitives/Array.Static ~Copyable.swift`, lines 80-90

```swift
public subscript(_ index: Index) -> Element {
    @_lifetime(borrow self)
    _read {
        precondition(index < count, "Index out of bounds")
        yield _buffer[index]
    }
    _modify {
        precondition(index < count, "Index out of bounds")
        yield &_buffer[index]
    }
}
```

**Pattern 3: Stored-property forwarding (30+ instances)**

File: `swift-primitives/swift-property-primitives/Sources/Property Primitives/Property.swift`, lines 152-155

```swift
public var base: Base {
    _read { yield _base }
    _modify { yield &_base }
}
```

**Pattern 4: IO coroutine with swap semantics (1 instance)**

File: `swift-foundations/swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Acceptance.Queue.swift`, lines 295-310

```swift
var expired: Expired {
    mutating _read {
        var placeholder = Queue(capacity: 0)
        swap(&self, &placeholder)
        var proxy = Expired(queue: placeholder)
        yield proxy
        swap(&self, &proxy.queue)
    }
    _modify {
        var placeholder = Queue(capacity: 0)
        swap(&self, &placeholder)
        var proxy = Expired(queue: placeholder)
        yield &proxy
        swap(&self, &proxy.queue)
    }
}
```

### Risk Assessment

| Concern | Assessment |
|---------|-----------|
| ABI stability | Not a concern. These are `@inlinable` in packages, not ABI-stable frameworks. The compiler emits identical coroutine lowerings for `_read`/`yielding borrow` and `_modify`/`yielding mutate`. |
| Suppressibility | The feature flag is additive. Removing it reverts to `_read`/`_modify`. No functional difference. |
| Migration cost | Mechanical find-and-replace. 394 sites in primitives, 3 in foundations. Estimated 30 minutes with scripted replacement. |
| Compiler maturity | SE-0474 was accepted but the implementation is still marked experimental. Compiler crashes or regressions are possible on edge cases (especially `mutating yielding borrow`). |
| Downstream impact | None. Accessor keywords are not part of the module interface when compiled. Consumers see the same ABI. |

### Recommendation: WAIT

SE-0474 is accepted but the experimental flag indicates the implementation is not
compiler-team-blessed for production use. The migration is mechanical and low-risk,
so there is no urgency. Enable when one of:
- The feature graduates from experimental (no flag needed), OR
- The Swift 6.2 toolchain ships with it enabled by default

**Do not partially migrate.** When we migrate, do all 394 sites at once via script.

---

## 2. BorrowAndMutateAccessors (`borrow` / `mutate`)

### What It Enables

Non-yielding `borrow` and `mutate` accessors. Unlike `yielding borrow` (which is a
coroutine that yields and resumes), `borrow` would be a simple accessor that returns
a borrowed reference. Similarly, `mutate` would provide direct mutable access without
the coroutine overhead.

```swift
// Hypothetical
var value: T {
    borrow { _value }      // Non-yielding borrow
    mutate { &_value }     // Non-yielding mutate
}
```

### Current Ecosystem Patterns That Would Benefit

**a) Property.View.Read accessor pattern**

Currently, non-mutating read access on ~Copyable types uses `_read` with
`withUnsafePointer(to: self)`:

```swift
public var forEach: Property<Sequence.ForEach, Self>.View.Read {
    _read {
        yield Property<Sequence.ForEach, Self>.View.Read(borrowing: self)
    }
}
```

A `borrow` accessor could eliminate the coroutine overhead:

```swift
public var forEach: Property<Sequence.ForEach, Self>.View.Read {
    borrow {
        Property<Sequence.ForEach, Self>.View.Read(borrowing: self)
    }
}
```

There are approximately 56 `Property.View.Read` usages across 26 files in
swift-primitives Sources.

**b) Simple stored-property forwarding**

The common `_read { yield _base }` pattern would become `borrow { _base }`,
eliminating coroutine frame overhead for trivial projections. Approximately 30+
instances.

**c) Subscript getters on ~Copyable containers**

Currently ~Copyable subscript getters use `_read` to avoid copying. A `borrow`
accessor would express the intent more clearly and potentially optimize better.

### Risk Assessment

| Concern | Assessment |
|---------|-----------|
| Proposal status | Pre-proposal. No SE number. Much less mature than CoroutineAccessors. |
| Compiler support | Minimal. The flag exists but coverage is thin. |
| Interaction with ~Copyable | This is where the value would be highest, but also where compiler bugs are most likely. |
| Migration cost | Would require semantic analysis, not just find-and-replace. Need to determine which `_read` sites are true borrows vs. which need coroutine semantics (e.g., swap pattern in IO). |

### Recommendation: WAIT

Too immature. The value is clear (eliminating coroutine overhead on simple borrows)
but the compiler support is not ready. The existing `_read` accessor works correctly.
Revisit when a formal SE proposal is filed.

---

## 3. UnderscoreOwned (`_owned get`)

### What It Enables

An `_owned get` accessor would return an owned value from a computed property,
enabling transfer of ~Copyable values through property syntax. This is the consuming
counterpart to `borrow`.

### Current Ecosystem Patterns

**Existing experiment:**
`swift-primitives/swift-sequence-primitives/Experiments/consuming-property-view/`

This experiment (dated earlier in the project) concluded:

> `consuming get` is SYNTACTICALLY accepted but SEMANTICALLY LIMITED. It cannot move
> stored properties from `self`. It is NOT useful for draining containers.

The ecosystem has worked around this limitation through:
1. `Property.Consuming<Element>` -- wraps the base value via `_modify` + defer
2. `Property.View` with `mutating func` -- pointer-based consuming through `_modify`
3. `consuming func` methods -- explicit consuming functions instead of properties

**Search results:** Zero `consuming get` or `_owned get` in production Sources across
both repos. Only in experiments.

### Risk Assessment

| Concern | Assessment |
|---------|-----------|
| Compiler status | No proposal. Compiler-internal underscore API. |
| Practical value | Low. The ecosystem has robust workarounds (Property.Consuming, Property.View). |
| Semantic gap | `consuming get` cannot move stored properties -- the fundamental limitation remains. |

### Recommendation: SKIP

No practical benefit. The existing `Property.View` and `Property.Consuming` patterns
are well-established, battle-tested, and work with current compiler. `_owned get`
does not solve the actual problem (moving stored properties through accessor syntax).

---

## 4. Current Feature Flag Inventory

### Ecosystem-wide settings (applied to all targets)

All 129 packages in swift-primitives and 44 packages in swift-foundations use the
same base settings:

**Upcoming features (4):**
```swift
.enableUpcomingFeature("ExistentialAny"),
.enableUpcomingFeature("InternalImportsByDefault"),
.enableUpcomingFeature("MemberImportVisibility"),
.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
```

**Experimental features (3):**
```swift
.enableExperimentalFeature("Lifetimes"),
.enableExperimentalFeature("SuppressedAssociatedTypes"),
.enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
```

**Per-package additions:**
- `BuiltinModule` -- used by a few low-level packages
- `RawLayout` -- used by storage primitives

**Not currently enabled:**
- `CoroutineAccessors` -- not present in any Package.swift
- `BorrowAndMutateAccessors` -- not present in any Package.swift
- `UnderscoreOwned` -- not a recognized feature flag

### Existing experiment

`swift-primitives/swift-property-primitives/Experiments/borrowing-read-accessor-test/`
documents the current state (as of 2026-02-23):

> SE-0474 CoroutineAccessors (experimental, not yet stable)
> BorrowAndMutateAccessors (experimental, not yet stable)

The experiment confirmed that `withUnsafePointer(to: self)` provides
pointer-from-borrow through public API, making `borrow` accessors a
nice-to-have rather than a blocker.

---

## 5. Migration Strategy (When Ready)

### CoroutineAccessors migration (deferred)

When the flag graduates from experimental:

```bash
# Phase 1: Mechanical replacement
sed -i '' 's/_read {/yielding borrow {/g'   Sources/**/*.swift
sed -i '' 's/_modify {/yielding mutate {/g'  Sources/**/*.swift

# Phase 2: Verify
swift build 2>&1 | head -50

# Phase 3: Single commit per repo
```

Estimated effort: 30 minutes per repo, plus CI verification.

### BorrowAndMutateAccessors migration (deferred)

When a formal proposal lands and the flag stabilizes:

1. Audit all 69 non-mutating `_read` sites for borrow eligibility
2. Convert simple borrows: `_read { yield x }` -> `borrow { x }`
3. Keep coroutine semantics where needed (swap patterns, multi-step yields)
4. Profile performance delta on buffer-primitives benchmarks

---

## 6. Conclusion

The ecosystem has **394 coroutine accessor sites** in swift-primitives and **3** in
swift-foundations. All are candidates for SE-0474 migration when it stabilizes. The
`borrow`/`mutate` non-yielding accessors would optimize approximately 100 of those
sites but remain too immature. `_owned get` provides no value given existing
infrastructure.

**Action items:**
- None immediate. Continue using `_read`/`_modify`.
- Track SE-0474 compiler stabilization (expected Swift 6.2 or 6.3).
- Re-evaluate `BorrowAndMutateAccessors` if/when an SE proposal is filed.
