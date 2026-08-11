# SLI — `Slice<Base>`: Skip

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: DECISION
tier: 1
scope: swift-carrier-primitives SLI target
---
-->

## Context

`Swift.Slice<Base>` is a generic view into a `Collection`, representing a contiguous subrange. Should it conform to `Carrier`?

## Analysis

Slice is a generic-over-Base type with the same parametric self-carriage considerations as Array/Set (see `sli-array.md`, `sli-set.md`). Trivial self-carriage is zero-payoff; parametric forms (unwrap through Base or Base.Element) are opinionated.

One Slice-specific wrinkle: Slice borrows its base collection's storage. Its semantic identity is "view into another collection," which doesn't match Carrier's "I wrap a value" abstraction cleanly. The wrapping feels weaker for Slice than for Array — Slice ISN'T carrying a value in the sense the Carrier abstraction assumes.

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: Same as `sli-array.md` plus the semantic-identity mismatch: Slice is a view, not a wrapped value. Consumers that want slice-of-Carrier semantics can declare their own specific shape.

## References

- Swift stdlib `Slice<Base>`.
- `sli-array.md`.
