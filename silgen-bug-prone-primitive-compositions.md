# SILGen Bug-Prone Primitive Compositions

**Status**: IN_PROGRESS
**Tier**: 2
**Scope**: ecosystem-wide

## Context

The 2026-04-17 Effect.Continuation.One modernization session hit a Swift 6.3.1 SILGen bug when composing `~Copyable` + `sending` + `@Sendable` capture + typed-throws at a single closure boundary (reflection `2026-04-17-effect-primitives-ncopyable-widening-silgen-workaround.md`). The synchronous form at `Kernel.Event.Driver.swift:117` works — `var slot + take!` inside the same scope. The async form detonated: either SILGen crash in `emitApplyWithRethrow` → `buildThunkBody` → `createThunk`, or bogus SIL producing a task-allocator violation on first suspension.

Two-callback storage fallback landed as the working workaround per `[IMPL-092]`. A `noncopyable-optional-capture-crash` reproducer experiment captures the minimal trigger for the effect-primitives case.

The session raised a follow-on question: is this the only site in the ecosystem where three-or-more primitives compose dangerously, or are there other latent hazards that will fire in consumer code before they fire in a reduction?

## Question

**Which combinations of ownership/concurrency primitives (`~Copyable`, `~Escapable`, `sending`, `@Sendable` capture, `consuming`, `borrowing`, typed throws) produce SILGen crashes or miscompilation when layered at a single syntactic site in Swift 6.3.1 and 6.4-dev?**

Sub-questions:
- What is the minimal bug-prone composition on each toolchain?
- Are there sites in `swift-primitives` L1 that currently layer 3+ primitives and would break under consumer async wrapping?
- Does the `Kernel.Event.Driver.swift:117` pattern (sync `var slot + take!`) generalize cleanly across all typed-throws consumers, or does adding one more primitive tip it over?

## Analysis (stub)

Proposed survey approach:

1. **Inventory composition sites**: grep L1 packages for function signatures carrying 3+ of `(consuming|borrowing) ~Copyable`, `sending`, `@Sendable` capture inside body, typed throws, `~Escapable`.
2. **Classify by async-boundary crossing**: which of those sites are reachable from an async context where an `@Sendable` capture is forced?
3. **Build reproducers per-composition** under `swift-institute/Experiments/` and run on 6.3.1 + 6.4-dev nightly.
4. **Record FIXED verdicts** for compositions that stabilize on 6.4-dev; retire workarounds per `[IMPL-092]`'s two-callback fallback clause.

## Outcome (placeholder)

Pending survey execution. Expected artifacts: a table mapping `(composition, toolchain) → {compiles | SILGen crash | miscompile | runtime crash}`, plus a recommended audit rule for future L1 API design.

## Provenance

- `Research/Reflections/2026-04-17-effect-primitives-ncopyable-widening-silgen-workaround.md`
- `[IMPL-092]` two-callback storage fallback
- Experiment: `swift-effect-primitives/Experiments/noncopyable-optional-capture-crash/`

## References

- `Skills/implementation/errors.md` — `[IMPL-092]` and heuristic for recognizing toolchain-blocked composition
- `swift-foundations/swift-io/Sources/.../Kernel.Event.Driver.swift:117` — working synchronous reference pattern
