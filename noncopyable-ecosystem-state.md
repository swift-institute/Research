<!--
version: 1.0.0
last_updated: 2026-04-02
status: DECISION
tier: 2
consolidates:
  - noncopyable-ergonomics-compiler-state.md (DECISION, 2026-03-31)
  - noncopyable-ownership-transfer-patterns.md (DECISION, 2026-03-31)
  - noncopyable-closure-capture-relaxation.md (IN_PROGRESS, 2026-03-31)
  - noncopyable-synchronization-ecosystem-audit.md (IN_PROGRESS, 2026-03-26)
  - noncopyable-value-generic-deinit-bug.md (DECISION, 2026-03-15)
  - mark-dependence-copypropagation-bug-report.md (IN_PROGRESS, 2026-03-22)
-->

# ~Copyable Ecosystem State

## Question

What is the current state of `~Copyable` support in Swift 6.2/6.3, what works,
what is permanently limited by design, what are bugs, and what are the canonical
patterns for ownership transfer?

## Context

Six separate research documents investigated overlapping aspects of ~Copyable
ergonomics, transfer patterns, synchronization, and compiler bugs. This
consolidation unifies their findings into a single authoritative reference.

---

## 1. Compiler State Summary

### Permanent by Design (5 items)

| Limitation | Mechanism | Workaround |
|-----------|-----------|------------|
| Closure capture reinitialization | Non-escaping closures capture by reference; consuming requires reinit because closures are potentially callable multiple times. Stdlib never consumes through capture. | `var slot: V? = value` + `slot.take()!`, or `consuming` closure parameter |
| Implicit Copyable on extensions | SE-0427 deliberate. `lib/AST/Requirement.cpp:367-387`. | Write `where Value: ~Copyable` on every extension |
| `switch consume` required | SE-0432: borrowing is the default for pattern matching | Write `switch consume x` |
| All Optional access is consuming | `if let`, `guard let`, `!`, `?.` all consume | `_read`/`_modify` projection |
| Continuations require `T: Copyable` | No `~Copyable` on `UnsafeContinuation` / `CheckedContinuation`. No TODOs in compiler. | Void-signal pattern (continuation carries Void, element via mutex buffer) |

(from noncopyable-ergonomics-compiler-state.md, 2026-03-31)

Apple's HTTP API proposal (`AsyncWriter.swift:123-140`) uses the same Optional+take
pattern and names the cause explicitly: "we don't have call-once closures." This is
the accepted industry workaround.
(from noncopyable-closure-capture-relaxation.md, 2026-04-02)

### Bugs (3 items)

| Bug | Symptom | Workaround | Upstream |
|-----|---------|------------|----------|
| Force unwrap IRGen crash | `Invalid bitcast, address space 64` on `!` into generic `consuming T` | `.take()!` | Not yet filed |
| Value-generic deinit (Bug A+B) | Deinit body skipped + member destruction not synthesized for cross-package @_rawLayout | `_deinitWorkaround: AnyObject? = nil` + manual pointer cleanup | swiftlang/swift #86652 (variant) |
| CopyPropagation / mark_dependence | Double `end_lifetime` on `~Copyable ~Escapable` values across control flow | Remove `~Escapable` from Property.View | Pending filing |

(from noncopyable-ergonomics-compiler-state.md, 2026-03-31;
noncopyable-value-generic-deinit-bug.md, 2026-03-15;
mark-dependence-copypropagation-bug-report.md, 2026-03-22)

**Deinit bug scale**: Workaround applied to 21 types across 9 packages (Queue, Array,
Stack, Heap, Set.Ordered, Dictionary.Ordered, Slab, List.Linked, Tree.N variants).
Trigger requires all 5 conditions: ~Copyable container, cross-package stored property,
value-generic parameter, `@_rawLayout` storage, generic element.
(from noncopyable-value-generic-deinit-bug.md, 2026-03-15)

---

## 2. Ownership Transfer Patterns

### The Mechanism Layer

Swift 6.3 requires an Optional wrapper to move a consuming `~Copyable` value into
a closure: `var slot: V? = value` then `slot.take()!` inside. Principle: consuming
values enter closures as parameters, not captures.
(from noncopyable-ownership-transfer-patterns.md, 2026-03-31)

### Three Canonical Patterns

**Pattern 1: Always-Consume [MEM-OWN-010]**

Every code path consumes. `Mutex.withLock(consuming:body:)` — body receives
`consuming V` as parameter. Used by `Async.Bridge.push()`.

**Pattern 2: Maybe-Consume [MEM-OWN-011]**

State machine decides per-path. Method takes `inout Element?`. Call site passes
`&slot`. Machine uses `.take()!` on consume paths, leaves Optional populated on
non-consume paths. Used by `Channel.Unbounded.Sender.send()`,
`Channel.Bounded.Sender.send()`.

**Pattern 3: Borrow-Only**

No ownership transfer. Standard `withLock { state in ... }`. Used by
`Bridge.finish()`, all query operations.

(from noncopyable-ownership-transfer-patterns.md, 2026-03-31)

### Decision Procedure

Is a `~Copyable` value being transferred?
- Every code path consumes → Pattern 1
- State machine decides → Pattern 2
- Read/mutate only → Pattern 3

### Action Enum Dispatch [MEM-OWN-012]

Lock produces a `~Copyable` action enum. `switch consume action` outside the lock.
Continuations resumed post-lock to prevent reentrancy and deadlock.
(from noncopyable-ownership-transfer-patterns.md, 2026-03-31)

### Layer Model [IMPL-070]

| Layer | Contents | Rule |
|-------|----------|------|
| Layer 0 | `var slot` + `.take()!` | Inside Mutex extension only |
| Layer 1 | `withLock(consuming:)`, `withLock(deposit:)`, `Ownership.Slot` | Typed infrastructure |
| Layer 2 | `Bridge.push()`, `Channel.send()` | Domain API |

**`.take()!` MUST NOT appear at Layer 2** — any occurrence is a compliance violation.
(from noncopyable-ownership-transfer-patterns.md, 2026-03-31)

---

## 3. Synchronization and ~Copyable

### Ownership as synchronization

`~Copyable` types with `mutating` methods need no synchronization for stored state —
ownership guarantees exclusive access. Replacing `actor Lifecycle` with a plain stored
property yielded **3x write throughput improvement** in Channel refactoring.
Codified as [IMPL-063].
(from noncopyable-synchronization-ecosystem-audit.md, 2026-03-26)

### Stdlib patterns

| Framework | Pattern |
|-----------|---------|
| Stdlib `Mutex` | `inout sending Value` + `_Cell<Value>` with `@_rawLayout` |
| swift-nio | `NIOLockedValueBox` — reference-counted lock box, no ~Copyable |
| swift-system | `Mach.Port<RightType>: ~Copyable` with `borrowing` + `consuming func relinquish()` + `discard self` |

(from noncopyable-ergonomics-compiler-state.md, 2026-03-31)

### Ecosystem audit status

Stub only. Full audit of ~Copyable types using unnecessary synchronization is pending.
Audit method: grep for `~Copyable` type declarations, check for contained
actors/Atomic/Mutex, verify access pattern is mutating/consuming.
(from noncopyable-synchronization-ecosystem-audit.md, 2026-03-26)

---

## 4. End-State Vision

### Coroutine-capable struct Mutex

`@_rawLayout` inline storage. `nonmutating _modify` on a `~Copyable` Locked view.
Eliminates closures entirely:

```swift
_state.locked.value.buffer.push(consume element, to: .back)
```

No closure, no Optional, no `.take()!`. Performance parity with
`Synchronization.Mutex`. Proven by `mutex-coroutine-rawlayout` experiment (6/6),
`mutex-coroutine-realistic` (8/8).
(from noncopyable-ownership-transfer-patterns.md, 2026-03-31)

### `~Escapable` limitation on Locked view

The lifetime checker rejects `~Escapable` views on class stored properties. `~Copyable`
alone suffices — `_read` coroutine scope prevents escape, `~Copyable` prevents aliasing.
(from noncopyable-ownership-transfer-patterns.md, 2026-03-31)

### Coroutine layer model eliminates Layer 0

| Closure-based | Coroutine-based |
|---------------|-----------------|
| Layer 0: var slot + .take()! | (eliminated) |
| Layer 1: withLock extensions | Layer 1: StructMutex + Locked view |
| Layer 2: domain API | Layer 2: direct property access |

(from noncopyable-ownership-transfer-patterns.md, 2026-03-31)

### Future language improvements

| Improvement | Impact |
|-------------|--------|
| Consuming closures | Simplify Layer 0 of closure path |
| `~Copyable` continuations | Void-signal replaced by element-carrying |
| Implicit `~Copyable` on extensions | Remove `where` annotations |
| `~Escapable` on class stored properties | Add to Locked view for stronger safety |

(from noncopyable-ownership-transfer-patterns.md, 2026-03-31)

### Closure capture relaxation (possible future)

A Swift Evolution pitch to let the compiler verify once-consumed captures in
non-escaping closures could eliminate the Optional wrapper. Requires extending the
move checker. Worthwhile but reduced urgency given Apple has normalized the current
pattern. Overhead of current workaround: one class allocation + two atomic CAS per
send (for `Ownership.Slot`); or one branch + one byte (for bare Optional).
(from noncopyable-closure-capture-relaxation.md, 2026-03-31)

---

## 5. Active Workarounds

| Workaround | For | Permanent? |
|-----------|-----|:---:|
| `.take()!` instead of `!` | IRGen crash on force unwrap | No |
| `_deinitWorkaround: AnyObject? = nil` | Deinit body skipped (Bug A) | No |
| Manual mutable pointer cleanup in deinit | Member destruction not synthesized (Bug B) | No |
| Remove `~Escapable` from Property.View | CopyPropagation double end_lifetime | No |
| `var slot: V? = value` + `slot.take()!` | Consuming ~Copyable into closures | **Yes** |
| `where Value: ~Copyable` on extensions | Implicit Copyable constraint | **Yes** |
| `switch consume` instead of `switch` | Borrowing default on pattern match | **Yes** |
| `_read`/`_modify` projection | All Optional access consuming | **Yes** |
| Void-signal continuation + mutex buffer | Continuations require Copyable | **Yes** |

---

## Cross-References

- **memory-safety** skill: [MEM-COPY-001] through [MEM-COPY-014], [MEM-OWN-001]
  through [MEM-OWN-014], [MEM-LINEAR-001] through [MEM-LINEAR-003]
- **nonescapable-ecosystem-state.md**: Companion document for ~Escapable
- **ownership-transfer-conventions.md**: Companion document for sending/Sendable
- Experiments: mutex-coroutine-rawlayout, mutex-coroutine-realistic,
  mutex-escapable-accessor, bridge-noncopyable-ownership,
  optional-noncopyable-unwrap, copypropagation-noncopyable-switch-consume,
  noncopyable-nested-deinit-chain
