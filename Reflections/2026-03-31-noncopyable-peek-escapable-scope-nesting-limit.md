---
date: 2026-03-31
session_objective: Investigate whether ~Escapable types can enable property-based peek for ~Copyable deque elements
packages:
  - swift-queue-primitives
  - swift-buffer-primitives
  - swift-ownership-primitives
  - swift-property-primitives
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Added [IMPL-079] Property.View is terminal ~Escapable layer
  - type: skill_update
    target: memory-safety
    description: Added [MEM-LIFE-005] nested coroutine ~Escapable scope limitation
  - type: experiment_topic
    target: swift-queue-primitives/Experiments/nested-read-escapable-composition
    description: Test whether nested _read limitation is fundamental or View-specific
---

# ~Escapable Peek Investigation — Property.View Is the Terminal Scope

## What Happened

Investigated three avenues for replacing `func peek<R>(_ body: (borrowing Element) -> R) -> R?` with `var peek: Ownership.Borrow<Element>?` on Queue.DoubleEnded. Wrote experiment `noncopyable-peek-escapable` (7/7 CONFIRMED in isolation): `Optional<Copyable & ~Escapable>` works in Swift 6.3 for functions, properties, and `_read` coroutines. Key finding: the blocker is `~Copyable + Optional` (consumption), not `~Escapable + Optional` (lifetime).

The other agent created `Ownership.Borrow<Value>` in swift-ownership-primitives with stdlib `Borrow<T>` (SE-0519) parity.

Attempted to wire up `var peek: Ownership.Borrow<Element>?` through the production Property.View architecture. Hit a hard wall: `Ownership.Borrow` returned from `Buffer.Ring.Peek.View.front` (inner `_read`) could not be yielded from `Queue.Front.View.peek` (outer `_read`). The compiler correctly rejected this — the Borrow's lifetime was tied to the inner Peek.View scope, which ends before the outer yield.

Reverted all production changes. Closure-based peek remains. Filed DEFERRED audit finding.

## What Worked and What Didn't

**Worked**: The experiment design was sound. Testing `Optional<Copyable & ~Escapable>` in isolation confirmed feasibility. The distinction between `~Copyable + Optional` (blocked) and `~Escapable + Optional` (works) is a genuine and useful finding.

**Didn't work**: Attempting to wire through the Property.View architecture without first verifying the scope composition. We hit the nested `_read` + `~Escapable` issue only after modifying four files across two packages. Should have written a targeted experiment for the two-level coroutine composition BEFORE touching production code.

**Confidence gap**: I was not certain the nested `_read` pattern would work but proceeded anyway. The user correctly pushed back ("please be certain"). The right call was to experiment first.

## Patterns and Root Causes

**Property.View is the terminal ~Escapable layer.** This is the deepest insight. Across the entire ecosystem, no Property.View method returns another ~Escapable value. Views return Copyable values (copies) or use closures (borrows). This is not accidental — it's a structural consequence of `_read` coroutine scoping. A ~Escapable value produced inside an inner `_read` cannot escape to an outer `_read` because its lifetime is tied to the inner scope.

This pattern was invisible until we tried to violate it. It should be documented as a design rule in the implementation or memory-safety skill.

**The experiment-production gap**: The standalone experiment worked because everything was in one `_read` scope. Production requires crossing two scopes (Buffer → Queue) through the Property.View indirection. Experiments test language capabilities; production tests architectural composition. The gap between these is where we lost time.

**Complexity budget exceeded**: The ergonomic improvement (`deque.front.peek?.value` vs `deque.front.peek { $0.value }`) didn't justify the architectural complexity of making it work through nested ~Escapable scopes. The user correctly called this — "whether that improvement justifies the complexity."

## Action Items

- [ ] **[skill]** implementation: Add rule documenting that Property.View is the terminal ~Escapable layer — View methods must return Copyable values or use closures, never return another ~Escapable value. Root cause: nested `_read` coroutine scoping prevents ~Escapable values from crossing View boundaries.
- [ ] **[skill]** memory-safety: Add [MEM-LIFE-*] rule: ~Escapable values produced in an inner `_read` cannot be yielded from an outer `_read`. The lifetime dependency on the inner scope prevents escape. This applies to any nested coroutine composition, not just Property.View.
- [ ] **[experiment]** Test nested `_read` + `~Escapable` composition directly (without Property.View) to determine if the limitation is fundamental to coroutine scoping or specific to the View pattern. If `buffer.front` (direct `_read`) works from Queue's `_read`, then the limitation is View-specific and a non-View path is viable.
