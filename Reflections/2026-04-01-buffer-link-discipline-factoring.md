---
date: 2026-04-01
session_objective: Factor pure link topology out of Buffer.Linked into Buffer.Link<N>, re-derive Buffer.Linked and timer wheel as compositions
packages:
  - swift-buffer-primitives
  - swift-async-primitives
  - swift-list-primitives
status: pending
---

# Buffer.Link Discipline — Algorithm Factoring as the Unification Primitive

## What Happened

Session started with reading a branching handoff investigating whether the timer wheel's ad-hoc intrusive linked list (~120 lines) could be replaced by `List.Linked<E, 2>`. The investigation found two blocking gaps: no cursor API and no ABA protection in Storage.Pool.

Two research documents followed:
1. **Cursor and arena-backing improvements** — concluded the cursor API should be added to List.Linked (independently justified), but ABA protection belongs in Arena (not Pool), and the timer wheel's intrusive design is correct.
2. **Theoretical perfect** — identified `Buffer.Link<N>` as the right decomposition: factor the link topology (pure index algebra) out of `Buffer.Linked`, making it reusable by any storage backend.

Implementation followed: `Buffer Link Primitives` as a new modularized target (7 operations), `Buffer.Linked` re-derived to delegate, timer wheel refactored to use `Buffer.Link<2>` directly with its arena.

Key naming correction at the end: `Slot` typealias for `Header` was removed — parameter names must match type semantics, not introduce domain aliases that obscure the actual type.

## What Worked and What Didn't

**Worked well**: The research → implementation pipeline. Two research documents built conviction in the design before writing any code. The theoretical perfect document asked the right question ("what is a linked list at the type level?") and arrived at a clean answer ("pure index algebra, parametric over node access").

**Worked well**: The `nodeAt` closure pattern. `(Index<Node>) -> UnsafeMutablePointer<Node>` is the simplest possible abstraction — no protocols, no generic parameters beyond what Buffer already provides, no unsafe pointer-to-field arithmetic. Call sites are trivial: `{ unsafe storage.pointer(at: $0) }`.

**Didn't work initially**: The plan initially proposed typealiases (`typealias Node = ...`, `typealias Slot = ...`). The user correctly caught both [API-NAME-004] violations. Node was salvageable ([PATTERN-024] — generic instantiation), but Slot was a semantic rename (Header ≠ Slot). The fix: remove Slot, rename parameters from `slot` to `header`.

**Could improve**: The modularization repo situation. Two worktrees of the same repo diverged with 25+ unique commits on each side. Working on both in parallel adds maintenance burden. A handoff was created for investigation.

## Patterns and Root Causes

**The factoring insight**: The link operations in `Buffer.Linked` and the timer wheel are the same algorithm with different field access. The decomposition is: share the **algorithm** (`Buffer.Link`), compose with **storage** and **element access** at the consumer level. This is the Strategy pattern applied at the type level with zero-cost abstraction via generic specialization and `@inlinable` closures.

**Naming as type-level truth**: The `Slot` → `Header` correction reveals a principle. When the ecosystem provides a type with a name (`Header`), and your domain concept is different (`Slot`), the resolution is NOT to rename the type — it's to let variable/field names carry the domain semantics while the type carries the implementation semantics. `Level.slots: [Header]` — the array name says "slots," the type says "linked list header." Both are true simultaneously.

**Research as implementation insurance**: The two research documents took maybe 20 minutes but prevented several dead ends: adding generation tokens to Storage.Pool (wrong abstraction), creating Buffer.Arena.Linked (unnecessary complexity), premature intrusive list extraction (one consumer). Without the research, the implementation might have started down one of these paths.

## Action Items

- [ ] **[skill]** code-surface: Add guidance that parameter names MUST match type semantics — domain concepts live in field/array names, not parameter renames of ecosystem types
- [ ] **[research]** Can the `nodeAt` closure pattern be generalized to other buffer disciplines (Tree.N, Queue.Linked) that also fuse allocation with topology?
- [ ] **[package]** swift-list-primitives: Buffer.Link provides the cursor operations (unlink, insertAfter) that list-primitives research identified as the #1 gap — investigate surfacing these through List.Linked's public API
