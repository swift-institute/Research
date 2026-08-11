# Noncopyable Optional Access Patterns

<!--
---
version: 1.0.0
last_updated: 2026-02-09
status: DECISION
---
-->

## Context

`Buffer.Linear.Small<N>` stores a `Buffer<Element>.Linear?` field (`_heapBuffer`) that is `~Copyable` when `Element: ~Copyable`. Borrowing-context access (computed property getters, `_read` coroutines) to properties of the wrapped value fails with "self is borrowed and cannot be consumed" because force-unwrap (`!`), optional chaining (`?.`), and `if let` all **consume** the `~Copyable` optional in Swift 6.2.

This blocks all read-only property access (`count`, `capacity`, `isEmpty`, `isFull`) and `_read`-based subscript access.

## Question

What is the correct access pattern for reading Copyable fields through a `~Copyable` optional in borrowing contexts?

## Analysis

### Option A: `switch` Pattern Matching (SE-0432)

`switch _heapBuffer { case .some(let heap): return heap.count; case .none: return _inlineBuffer.count }`

SE-0432 (Borrowing and consuming pattern matching for noncopyable types) makes `switch` default to **borrowing** for `~Copyable` subjects. The `let` binding inside `.some(let heap)` borrows the wrapped value without consuming the optional.

**Advantages**: Preserves `Buffer.Linear` composition; direct delegation to heap buffer methods in `_modify`; consistent with SE-0432 intent; future-proof.

**Disadvantages**: More verbose than `!` or `?.` (4 lines per property).

### Option B: Decomposed Storage

Store `Header?` + `Storage<Element>.Heap?` separately instead of `Buffer.Linear?`. Both are Copyable, so `?.` works.

**Advantages**: Familiar optional chaining syntax.

**Disadvantages**: Breaks `Buffer.Linear` composition; loses CoW via `ensureUnique()`; must reconstruct static ops calls manually; larger refactor for `Set.Ordered.Small` migration.

### Option C: Force-Unwrap Only (Status Quo — fails)

`_heapBuffer!.count` — does not compile in borrowing context.

### Option D: Optional Chaining (fails)

`_heapBuffer?.count ?? _inlineBuffer.count` — consumes, same error.

### Option E: `if let` (fails)

`if let heap = _heapBuffer { return heap.count }` — consumes, same error.

### Comparison

| Criterion | A: switch | B: Decomposed | C: `!` | D: `?.` | E: `if let` |
|-----------|-----------|---------------|--------|---------|-------------|
| Compiles in borrowing | Yes | Yes | No | No | No |
| Preserves composition | Yes | No | — | — | — |
| CoW support | Natural | Manual | — | — | — |
| Verbosity | Moderate | Low | — | — | — |
| SE-0432 aligned | Yes | N/A | — | — | — |

### Experiment Evidence

`Experiments/noncopyable-optional-access/` — all five patterns tested empirically. `switch` is the only language-level pattern that borrows correctly for `~Copyable` optionals in Swift 6.2.

## Outcome

**Status**: DECISION

**Use `switch _heapBuffer { case .some(let heap): ... case .none: ... }` for all borrowing access to `~Copyable` optional fields.** Use force-unwrap (`_heapBuffer!`) only in mutating contexts (`mutating func`, `_modify` coroutine) where consumption is allowed.

### Access Pattern Rules

| Context | Pattern | Rationale |
|---------|---------|-----------|
| Computed property getter | `switch _heapBuffer { case .some(let heap): }` | SE-0432 borrowing switch |
| `_read` coroutine | `switch _heapBuffer { case .some(let heap): }` | Same borrowing semantics |
| `_modify` coroutine | `_heapBuffer!` | Mutating context allows consume |
| `mutating func` | `_heapBuffer!` | Mutating context allows consume |
| `nil` check | `_heapBuffer != nil` | Comparison borrows, doesn't consume |

## References

- SE-0432: Borrowing and consuming pattern matching for noncopyable types
- SE-0427: Noncopyable generics
- SE-0437: Noncopyable Standard Library Primitives
- `Experiments/noncopyable-optional-access/` — empirical verification
