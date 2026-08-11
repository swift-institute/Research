# Stack Indexed Access: ADT Tension and Resolution

<!--
---
version: 1.0.0
last_updated: 2026-02-14
status: RECOMMENDATION
tier: 2
---
-->

## Context

The discipline-boundary analysis (`stack-discipline-boundary-analysis.md`) identified 8 "contested" APIs on `stack-primitives` that provide indexed/positional access to stack elements:

| API | Variants | Access Level |
|-----|----------|--------------|
| `subscript(index:)` (read/modify) | All 4 | Full random access |
| `subscript(index: Index.Bounded<capacity>)` | Static | Bounded random access |
| `element(at:) -> Element?` | Dynamic, Bounded | Optional safe access |
| `element(at:) throws` | Dynamic, Bounded | Throwing safe access |
| `withElement(at:_:)` | Static, Small | ~Copyable closure access |
| `span` | All 4 | Full contiguous read access |
| `mutableSpan` | All 4 | Full contiguous write access |

The boundary analysis recommended documenting these as "escape hatches" but deferred the architectural question. This document resolves it with a full literature study and empirical consumer analysis.

**Trigger**: [RES-001] Investigation — the discipline-boundary audit flagged these APIs as contested, requiring systematic analysis.

**Scope**: Package-specific (swift-stack-primitives), with cross-package pattern implications.

## Question

Should `stack-primitives` expose indexed access APIs, and if so, how should they be surfaced?

**Options under evaluation**:

1. **Accept status quo** — keep all APIs at top level, no changes
2. **Document-only** — keep all APIs, add escape-hatch documentation
3. **Namespace behind `.indexed` accessor** — gate indexed APIs behind a nested accessor
4. **Remove indexed access** — delete all contested APIs

---

## Prior Art Survey

### Formal ADT Specification

The Stack ADT is defined by exactly two constructors and three observers:

```
Operations:
  new:              → Stack
  push: Stack × E   → Stack
  pop:  Stack        → Stack
  top:  Stack        → E
  isEmpty: Stack     → Bool

Axioms:
  top(push(S,e))   = e
  pop(push(S,e))   = S
  top(new)         = error
  pop(new)         = new
  isEmpty(new)     = true
  isEmpty(push(S,e)) = false
```

These axioms are **complete** — every expression over the Stack algebra reduces using these rewrite rules. No operation has a positional parameter. The stack's identity is the LIFO discipline, and there is no axiom of the form `access(push(S,i), n)`.

Sources: UNC COMP 410; Liskov & Guttag, "Abstraction and Specification in Program Development."

### Implementation Survey

| Language/Library | Dedicated Stack? | Indexed Access | Encapsulated? |
|------------------|:---:|:---:|:---:|
| C++ `std::stack` | Yes (adaptor) | **No** | Yes |
| Java `Stack` | Yes (legacy) | **Yes** (design flaw) | No |
| Java `Deque` | Yes (replacement) | **No** | Yes |
| Haskell `Data.Stack` | Yes (abstract) | **No** | Yes |
| .NET `Stack<T>` | Yes | **No** (proposal rejected) | Yes |
| Rust | No (`Vec` convention) | Yes (not a stack type) | No |
| Python | No (`list` convention) | Yes (not a stack type) | No |
| Swift | No (`Array` convention) | Yes (not a stack type) | No |

**Key findings**:

**C++ `std::stack`** is a container adaptor that deliberately wraps `std::deque` and **hides** `operator[]`, `at()`, and all iterators. The entire value proposition is restriction. No `begin()`, no `end()`, no indexed access.

**Java `Stack`** extends `Vector`, inheriting `get(int)`, `elementAt(int)`, and the full `List` interface. This is universally cited as a design mistake. The Java documentation itself warns: "A more complete and consistent set of LIFO stack operations is provided by the Deque interface and its implementations, which should be used in preference to this class." Java's recommended replacement `Deque` explicitly excludes indexed access.

**Haskell `Data.Stack`** exports exactly 6 functions: `stackNew`, `stackPush`, `stackPop`, `stackPeek`, `stackIsEmpty`, `stackSize`. The type is abstract (opaque). No indexed access, no iteration, no mapping.

**.NET `Stack<T>`** — GitHub issue #15922 (2015) proposed adding indexed access. The proposal was rejected. Maintainer Matt Ellis: "I don't think it's a good idea to break the abstraction."

**Rust, Python, Swift** have no dedicated stack types. They use general-purpose arrays with `push`/`pop` methods. This represents failure to encapsulate the ADT, not endorsement of indexed stacks.

### Academic Consensus

**CLRS** (Cormen et al., "Introduction to Algorithms," Ch. 10.1): Defines stacks with exactly PUSH and POP. No indexed access.

**Knuth** ("The Art of Computer Programming," Vol. 1, §2.2): Defines stacks as "push-down lists" with insertions and deletions at one end only. Classifies deques, steques, and random-access structures as separate ADTs — each combination of operations defines a distinct structure.

**Okasaki** ("Purely Functional Data Structures," 1998): Treats stacks (cons lists) and random-access lists as **categorically different data structures**. When adding `lookup`/`update` to a cons list, Okasaki creates a new type: "random-access list" (Ch. 10.1.2). The addition of indexed access changes the ADT identity.

**Sedgewick** ("Algorithms," 4th Ed., §1.3): Explicitly warns against Java's `Stack` for providing indexed access: "Although having such extra operations may appear to be a bonus, it is actually a curse."

### ADT Taxonomy

| ADT | Operations | Indexed Access |
|-----|-----------|:---:|
| Stack | push, pop, top | No |
| Queue | enqueue, dequeue, front | No |
| Deque | push/pop at both ends | No |
| List / Sequence | insert-at, remove-at, access-at | **Yes** |
| Random-access list (Okasaki) | cons, head, tail, lookup, update | **Yes** |

**Consensus**: Adding indexed access to a stack crosses the boundary from "restricted-access" to "random-access" container. The literature treats this as a change of ADT, not an extension.

---

## Empirical Analysis: Consumer Usage

A search of all 61+ packages in the swift-primitives monorepo found:

**Zero external consumers** of the indexed access APIs on Stack types.

| API | Internal usage | External usage |
|-----|:---:|:---:|
| `subscript(index:)` | Test suite only | **0** |
| `element(at:)` | Test suite only | **0** |
| `withElement(at:)` | Test suite only | **0** |
| `span` | Test suite only | **0** |
| `mutableSpan` | Test suite only | **0** |

Graph algorithms (`swift-graph-primitives`) use `Stack` for DFS traversal across 7 files — none use indexed access. They push, pop, and peek only, confirming the stack ADT contract is sufficient for the primary consumer.

---

## Analysis

### Option 1: Accept Status Quo

Keep all APIs at the top level unchanged.

| Criterion | Assessment |
|-----------|-----------|
| ADT fidelity | Poor — indexed access contradicts the stack's identity as a restricted-access container |
| Prior art alignment | Poor — contradicts C++, Haskell, .NET, all textbooks |
| Consumer impact | None — no consumers use these APIs |
| Maintenance cost | Low — the code exists and works |
| Risk | New consumers may treat `Stack` as `Array` with different naming |

### Option 2: Document-Only

Keep all APIs, add escape-hatch documentation per the boundary analysis recommendation.

| Criterion | Assessment |
|-----------|-----------|
| ADT fidelity | Poor (documentation doesn't enforce discipline) |
| Prior art alignment | Poor (same surface area as Java `Stack`) |
| Consumer impact | None |
| Maintenance cost | Low |
| Risk | Documentation is advisory, not architectural. Consumers may ignore the warning. |

### Option 3: Namespace Behind `.indexed` Accessor

Gate all indexed access APIs behind a nested accessor:

```swift
// Instead of:
stack[index]
stack.element(at: i)

// Require:
stack.indexed[i]
stack.indexed.element(at: i)
stack.indexed.span
stack.indexed.mutableSpan
```

This follows the `stack.algebra.symmetric.difference(other)` pattern from Set.

| Criterion | Assessment |
|-----------|-----------|
| ADT fidelity | Good — the stack's primary surface is pure LIFO; indexed access requires an explicit opt-in |
| Prior art alignment | Novel but principled — makes the escape hatch architecturally visible |
| Consumer impact | None — zero consumers to migrate |
| Maintenance cost | Medium — requires introducing `Stack.Indexed` wrapper type across 4 variants |
| Risk | Adds complexity for a currently-unused API surface |

### Option 4: Remove Indexed Access

Delete all contested APIs. Consumers needing indexed access should use `Array` instead.

| Criterion | Assessment |
|-----------|-----------|
| ADT fidelity | Excellent — matches C++ `std::stack`, Haskell `Data.Stack` |
| Prior art alignment | Excellent |
| Consumer impact | None — zero consumers to migrate |
| Maintenance cost | Negative — less code to maintain |
| Risk | If a legitimate need arises later, the APIs would need to be re-added |

### Comparison

| Criterion | Status Quo | Document | Namespace | Remove |
|-----------|:---:|:---:|:---:|:---:|
| ADT fidelity | - | - | + | ++ |
| Prior art alignment | - | - | ~ | ++ |
| Consumer impact | 0 | 0 | 0 | 0 |
| Architectural clarity | - | - | + | ++ |
| Reversibility | N/A | Easy | Medium | Easy (re-add) |
| Complexity cost | 0 | Low | Medium | Negative |

### `span` / `mutableSpan` — Special Consideration

`span` and `mutableSpan` deserve separate treatment from `subscript`/`element(at:)`:

1. They are the standard Swift mechanism for safe contiguous memory access
2. They enable zero-copy FFI, serialization, and bulk operations
3. Swift's own `Array`, `ContiguousArray`, and `InlineArray` all expose them
4. They do not establish random-access *citizenship* (no Collection conformance)

However, `Span` provides full indexed access (`span[i]`), making it functionally equivalent to a subscript. If the goal is to prevent indexed access, `span` undermines it.

The pragmatic resolution: `span`/`mutableSpan` exist for interop and performance, not as a random-access API. They are escape hatches by nature. If namespacing is chosen (Option 3), they should live on the `.indexed` accessor alongside the subscript. If removal is chosen (Option 4), they should be retained — they serve a different purpose than positional element access.

---

## Outcome

**Status**: RECOMMENDATION

### Recommended: Option 3 (Namespace) for subscript/element, retain span/mutableSpan

The evidence overwhelmingly supports that indexed access is not part of the Stack ADT. Every well-designed implementation excludes it. No consumer in the monorepo uses it. The existing APIs were added speculatively.

However, **removal** is too aggressive given that the APIs are already implemented and tested. A future consumer may have a legitimate need for stack inspection (debugger integration, serialization, profiling). The infrastructure investment has already been made.

**Namespace** (Option 3) provides the right balance:
- The stack's top-level surface becomes purely LIFO — push, pop, peek, count, isEmpty
- Indexed access remains available but requires an explicit `.indexed` opt-in
- The architecture communicates intent: "you are leaving the stack contract"
- Zero consumer migration cost
- Follows the `.algebra.symmetric` precedent from Set

**Concrete recommendation**:

1. Introduce `Stack.Indexed` (and variants) as thin wrapper types
2. Move `subscript(index:)`, `element(at:)`, `withElement(at:)` behind `.indexed` accessor
3. **Keep** `span` and `mutableSpan` at the top level — they serve interop/FFI purposes distinct from positional element access and are standard Swift container surface area
4. Update tests to use `.indexed` accessor
5. Document the `.indexed` accessor as an escape hatch from the LIFO contract

**Priority**: Medium. No consumers are affected. This can be done as part of a normal release cycle.

**Implementation scope**: ~4 files per variant (16 files total), plus test updates.

---

## References

- Liskov & Guttag, "Abstraction and Specification in Program Development" — ADT axioms
- UNC COMP 410 ADT Axiomatic Semantics — https://www.cs.unc.edu/~stotts/COMP410/adt/
- Cormen, Leiserson, Rivest, Stein, "Introduction to Algorithms," Ch. 10.1
- Knuth, "The Art of Computer Programming," Vol. 1, §2.2
- Okasaki, "Purely Functional Data Structures" (1998), Ch. 10.1.2
- Sedgewick & Wayne, "Algorithms," 4th Ed., §1.3
- cppreference, `std::stack` — https://en.cppreference.com/w/cpp/container/stack.html
- Haskell `Data.Stack` 0.4.0 — https://hackage.haskell.org/package/Stack-0.4.0/docs/Data-Stack.html
- Java SE 8 `Deque` — https://docs.oracle.com/javase/8/docs/api/java/util/Deque.html
- .NET `Stack<T>` indexed access proposal (rejected) — https://github.com/dotnet/runtime/issues/15922
- `stack-discipline-boundary-analysis.md` — companion analysis in this package
