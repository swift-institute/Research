---
status: NOTES
date: 2026-05-01
---

# Notes on possible interaction with stdlib SE-0519

## Scope and non-commitment

This document captures **possible** interaction patterns between `swift-ownership-primitives` and the in-evolution `Borrow<T>` / `Inout<T>` types proposed under [SE-0519](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0519-borrow-inout-types.md). SE-0519 has not landed; its final shape may differ from the current proposal. **Nothing in this document is a consumer commitment**: the package's behaviour at the moment SE-0519 ships will be determined at that moment based on the proposal's final shape, the toolchain's then-current capabilities, and downstream consumer impact.

The package's current 0.1.x stability commitment is operational and lives in the README. This document is a contributor-facing note about the design space; it is not part of the source-stability commitment.

## Current state (2026-05-01)

`Ownership.Borrow<Value>` and `Ownership.Inout<Value>` mirror the SE-0519 shape under the current proposal. The package ships them today on Swift 6.3.1 via `_read` / `nonmutating _modify` coroutines — the implementation strategy that works before `BorrowAndMutateAccessors` (SE-0507) ships in a stable toolchain.

The `Ownership.Borrow.\`Protocol\`` capability typealias exists to work around SE-0404 (no nested protocols inside generic types). Adopters who conform via the typealias get the canonical borrow path.

The `Ownership.Borrow.init(borrowing:)` overload for a `Copyable Value` heap-allocates a class-owned copy as a workaround for the pre-SE-0519 register-pass miscompile. The cost is documented inline at the call site.

The `Ownership.Borrow.init(borrowing:)` overload for a `~Copyable Value` is non-`@inlinable` to preserve the cross-module `@in_guaranteed` ABI; same-module consumers can use the `init(_ pointer:)` overload directly. Documented at the call site.

## Possible interaction shapes when SE-0519 stabilises

The shape SE-0519 ultimately ships in stdlib will determine what this package does. **Several scenarios are plausible**, and the package will choose at the time:

- If stdlib `Borrow<T>` / `Inout<T>` ship with the shape currently proposed: the package may deprecate `Ownership.Borrow` / `Ownership.Inout` in favour of stdlib equivalents, retaining the `Ownership.Borrow.\`Protocol\`` capability typealias as an alias to the stdlib equivalent. A deprecation window is plausible. None of this is committed today.
- If stdlib ships with a meaningfully different shape (different parameterisation, different lifetime semantics, different conformance contract): the package may adopt the stdlib types where they fit and retain the package types where they don't. The decision rests on consumer-impact analysis at the time.
- If SE-0519 stalls or is materially revised: the package continues to ship its current shape until a clearer path emerges.

The owned-storage primitives (`Unique`, `Shared`, `Mutable`, `Slot`, `Latch`) and the Transfer family are NOT covered by SE-0519 and are not affected by the above scenarios.

## Workaround removal

The heap-owning Copyable workaround in `Ownership.Borrow.init(borrowing:)` exists because of a pre-SE-0519 toolchain miscompile. Once stdlib's register-pass miscompile fix lands (with or without SE-0519 itself), the workaround may become unnecessary; removal would be evaluated at that point.

## What this means for consumers today

Read the README's Stability section for the operational commitment. This document explains the contributor-facing context behind that commitment, not additional consumer-facing guarantees.

## Provenance

Replaces the "Migration to stdlib SE-0519" prose previously embedded in `swift-ownership-primitives/README.md` (commit `0d5b399`, removed in cohort evaluator-pass cleanup 2026-05-01). The earlier prose framed the migration as a four-step deprecation plan, which asserted forecast as fact; this note replaces that framing with explicit non-commitment.

Cross-reference: `swift-institute/Research/cohort-readme-evaluator-pass.md` (the cohort-wide audit triggering this relocation).
