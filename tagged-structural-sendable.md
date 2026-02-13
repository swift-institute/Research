# Tagged Structural Sendable

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: IN_PROGRESS
tier: 1
---
-->

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

*Pending.*
