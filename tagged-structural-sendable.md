# Tagged Structural Sendable

<!--
---
version: 1.1.0
last_updated: 2026-03-10
status: SUPERSEDED
superseded_by: ownership-transfer-conventions.md
tier: 1
---
-->

> **SUPERSEDED** (2026-04-02) by [ownership-transfer-conventions.md](ownership-transfer-conventions.md).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

`Hash.Table.Static<N>` (and similar phantom-typed containers) uses `@unchecked Sendable where Element: Sendable` because `Tagged<Element, Cardinal>` may not structurally prove `Sendable` even when both `Element: Sendable` and `Cardinal: Sendable`.

Source: reflection `2026-02-12-data-structures-plan-completion.md` — Hash.Table Sendable inconsistency between Static (correct constraint) and Dynamic (overly broad constraint, since fixed).

## Question

Can `Tagged<Element, Cardinal>` prove structural `Sendable` when `Element: Sendable` and `Cardinal: Sendable`? If so, `@unchecked` could be removed from `Hash.Table` and similar phantom-typed containers.

## Analysis

*Pending investigation.*

Key sub-questions:
1. Does `Tagged<Tag, RawValue>` have a conditional `Sendable` conformance where `Tag: Sendable, RawValue: Sendable`?
2. If `Tag` is a phantom type parameter (never stored), does Swift require `Tag: Sendable` for structural Sendable?
3. What is the current state of `Tagged`'s Sendable conformance in identity-primitives?

## Outcome

**Status**: DEFERRED

Investigation never started. The question remains valid but is low-priority: `@unchecked Sendable` on phantom containers is a correctness annotation (sound by construction), not a safety hazard. Revisit when auditing `@unchecked` usage across the ecosystem or when Swift gains a mechanism for phantom type parameters to be excluded from Sendable inference.

**Deferred since**: 2026-03-10
