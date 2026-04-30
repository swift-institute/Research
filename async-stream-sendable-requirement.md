# Async.Stream: Should It Require Element: Sendable?

<!--
---
version: 1.1.0
last_updated: 2026-04-30
status: DEFERRED
tier: 2
workflow: Investigation [RES-001]
trigger: Dropping Sendable from Channel<Element> (cbea779) exposed the question — which Sendable constraints in the async layer are essential vs inherited?
scope: swift-async (L3), swift-async-primitives (L1), sequence-primitives (L1)
---
-->

## Context

`Async.Channel<Element>` dropped its `& Sendable` requirement on Element (commit `cbea779`), using `sending` for region-based transfer instead. This exposed that `Async.Stream<Element: Sendable>` still requires Sendable elements. The bridge extensions (`Receiver.stream()`) now need `where Element: Sendable` gates.

The broader question: is `Element: Sendable` an essential constraint for Stream's design, or a legacy of Channel's old requirement that can now be relaxed?

### Prior Research

This investigation draws on three existing documents and one experiment:

| Document | Status | Key Finding |
|----------|--------|-------------|
| `stream-isolation-preserving-operators.md` (v1.0.0) | RECOMMENDATION | Concrete operator types preserve isolation. Two-tier architecture recommended. |
| `stream-isolation-propagation.md` (v1.2.0) | DEFERRED | All 40+ Stream operators break isolation. Root cause: @Sendable closures + sync closure limitation. |
| `modern-concurrency-conventions.md` (v1.0.0) | RECOMMENDATION | Non-Sendable over Sendable. Isolation first. Sendable is viral. |
| Experiment: `stream-isolation-preservation/` | CONFIRMED | Concrete types with non-@Sendable closures preserve isolation. @unchecked Sendable on types does NOT break isolation. Late erasure preserves isolation. |

## Question

Should `Async.Stream<Element>` require `Element: Sendable`?

## Constraints

1. `Async.Stream.Iterator` stores `@Sendable () async -> Element?`. A `@Sendable` closure returning `Element?` requires `Element: Sendable`.
2. `Async.Stream: Sendable` — the struct can be sent across isolation domains. Its stored closures must be `@Sendable`.
3. `NonisolatedNonsendingByDefault` is enabled across all 252 ecosystem packages.
4. `Sequence.Protocol` (L1 sequence-primitives) has no Sendable requirement — it supports `~Copyable` elements via span-based iteration.
5. `AsyncSequence` (stdlib) does NOT require `Element: Sendable` at the protocol level.
6. `sending` on stored closure types is not supported — `sending` is a calling-convention annotation for function declarations, not closure types.

## Analysis

### Option A: Status Quo — `Stream<Element: Sendable>: Sendable`

Keep the current design. Stream is a Sendable, sharable, type-erased async sequence. Bridge extensions gated on `where Element: Sendable`.

**How it works**: Stream stores `@Sendable () -> Iterator` and Iterator stores `@Sendable () async -> Element?`. The @Sendable annotation requires Element: Sendable for the return type. Stream itself is Sendable, enabling storage in actors, passing across tasks, and use in concurrent combinators (merge, zip, combineLatest).

**Advantages**:
- No changes required (already implemented)
- Can be stored in actors, shared across isolation domains
- Enables concurrent combinators (merge, zip, share, replay)
- Clear mental model: Stream crosses boundaries, Channel transfers elements
- `Iterator.Box` (`Ownership.Mutable.Unchecked`) already enables wrapping non-Sendable *iterators* — only the Element needs Sendable

**Disadvantages**:
- Non-Sendable elements cannot flow through Stream
- All 40+ operators break caller isolation (stream-isolation-propagation.md finding)
- @Sendable closures are viral — every operator requires @Sendable transforms
- Misaligned with ecosystem direction: "Non-Sendable over Sendable" (Convention 2)

### Option B: Non-Sendable Stream — `Stream<Element>`

Drop Sendable from Stream. Use non-@Sendable closures internally. No Element: Sendable requirement.

**How it works**: Stream stores `() -> Iterator` and Iterator stores `() async -> Element?`. Under `NonisolatedNonsendingByDefault`, these closures are nonsending — they inherit caller isolation. Stream is consumed within a single task. Mirrors `Sequence.Protocol` from sequence-primitives.

**Advantages**:
- No Element: Sendable requirement
- Operator closures preserve caller isolation (experiment Test B2)
- Aligns with ecosystem direction and sequence-primitives design
- Simpler mental model within a task: compose, consume, done

**Disadvantages**:
- Cannot be stored in actors or shared across tasks
- Breaks existing API (all current consumers expect Sendable)
- Concurrent combinators (merge, zip) require unstructured Task — these create new isolation domains, so they'd need to re-establish isolation
- Multi-consumer patterns (share, replay) become impossible without Sendable

### Option C: Two-Tier Architecture — Concrete Operators + Type-Erased Stream

Keep Stream as the Sendable boundary. Add concrete operator types on `AsyncSequence` for non-Sendable, isolation-preserving composition.

**How it works** (per `stream-isolation-preserving-operators.md`):
- ~20 concrete operator types (`Async.Map<Base, Output>`, `Async.Filter<Base>`, etc.) store non-@Sendable closures
- Extensions on `AsyncSequence` return concrete types
- Concrete types preserve caller isolation (experiment Tests G, H, K)
- Type erasure to `Async.Stream` is an explicit concurrency boundary
- Stream retains `Element: Sendable` for concurrent combinators

```
Channel<Element: ~Copyable>
    │
    ├─→ receiver.elements: AsyncSequence ─→ .map { }.filter { }
    │   (concrete types, isolation-preserving, Element: ~Sendable OK)
    │
    └─→ Async.Stream(pipeline)  ← explicit erasure boundary
        (type-erased, Sendable, Element: Sendable required)
        ─→ .merge() .share() .combineLatest()
```

**Advantages**:
- Non-Sendable elements supported in concrete operator layer
- Isolation preserved through composition (empirically verified)
- Stream retains Sendable for concurrent use cases
- Backwards compatible — existing Stream API unchanged
- Aligns with prior art: Kotlin Flow (context preservation default, flowOn explicit), Rust (spawn_local vs spawn)
- `some AsyncSequence<Element>` handles type explosion via opaque return types
- No language changes required

**Disadvantages**:
- Significant implementation effort (~20 concrete types)
- Two composition APIs to learn (concrete vs type-erased)
- Generic type chains in concrete layer (mitigated by opaque return types)
- Maintenance burden: operators exist twice (concrete + type-erased)

### Option D: Dual Stream Types — `Stream` (Sendable) + `Stream.Local` (~Sendable)

Keep `Async.Stream` as-is. Add a non-Sendable variant for single-task composition.

**How it works**: `Async.Stream.Local<Element>` stores non-@Sendable closures. It can wrap any `AsyncSequence`, compose with operators, and be consumed with `for await`. It cannot be sent across tasks. Conversion to `Async.Stream` requires `Element: Sendable`.

**Advantages**:
- Non-Sendable elements supported via Local variant
- Existing Stream API unchanged
- Simpler than Option C (no concrete type explosion)
- Clear naming: Stream = cross-task, Stream.Local = single-task

**Disadvantages**:
- All operators duplicated (Sendable and non-Sendable versions)
- Naming/discovery burden: two types that look similar but behave differently
- Local variant still breaks isolation for sync closures (same limitation as Document 2, cause 2)
- Does not solve the isolation preservation problem that concrete types solve

## Comparison

| Criterion | A: Status Quo | B: Non-Sendable | C: Two-Tier | D: Dual Types |
|-----------|---------------|-----------------|-------------|---------------|
| Non-Sendable Element support | No | Yes | Yes (concrete layer) | Yes (Local variant) |
| Cross-task sharing | Yes | No | Yes (Stream layer) | Yes (Stream) / No (Local) |
| Isolation preservation | No (all operators break) | Partial (async closures only) | Yes (concrete layer) | Partial (async closures only) |
| API complexity | Low | Low | Medium | Medium |
| Backwards compatibility | Full | Breaking | Full | Full |
| Implementation effort | None | Medium | High | High |
| Operator duplication | None | None | Yes (~20 concrete types) | Yes (all operators × 2) |
| Alignment with ecosystem direction | Partial | Strong | Strong | Moderate |
| Prior art alignment | Weak | Moderate | Strong (Kotlin Flow, Rust) | Moderate |

## Key Insight

The experiment (`stream-isolation-preservation`, Test H) proved that `@unchecked Sendable` on a concrete type does NOT break isolation — only `@Sendable` on the *closure type itself* severs the isolation chain. This means concrete operator types can be BOTH isolation-preserving AND crossable across boundaries when needed. The @Sendable annotation on closures is the sole gatekeeper.

This makes Option C strictly better than Options B and D for isolation preservation. Options B and D still suffer from the sync closure limitation (cause 2 from `stream-isolation-propagation.md`) because their type-erased closures are created in nonisolated contexts. Only concrete types, where `next()` inherits caller isolation and calls the stored transform in that context, fully preserve isolation.

## Outcome

**Status**: IN_PROGRESS

### Preliminary Assessment

The evidence points toward **Option C (Two-Tier Architecture)** as the strongest long-term design:

1. It preserves the current Stream API (backwards compatible)
2. It enables non-Sendable elements in the concrete layer
3. It solves isolation preservation (the only option that does for sync closures)
4. It aligns with the ecosystem's concrete operator recommendation (`stream-isolation-preserving-operators.md`)
5. It aligns with prior art (Kotlin Flow, Rust)

**However**, Option C has significant implementation cost. The **immediate action** regardless of long-term direction is clear:

- `Async.Stream<Element: Sendable>` keeps its Sendable requirement (structurally necessary for its role)
- Bridge extensions use `where Element: Sendable` (correctly narrows availability)
- Channel receivers remain usable without Sendable via their `.elements` AsyncSequence directly

### Open Questions

1. **Naming**: Should concrete operators live on `AsyncSequence` (stdlib-style) or as `Async.Stream.Concrete.*` (namespaced)?
2. **Module placement**: Concrete operators in swift-async (L3) or a new package?
3. **Priority**: Is the concrete operator layer worth building now, or should we wait for Swift Evolution to address `sending` in closure types?

### Status — DEFERRED (2026-04-30)

**Disposition**: The preliminary recommendation (Option C, two-tier architecture) is sound and the structural conclusions (`Async.Stream<Element: Sendable>` keeps its requirement; bridge extensions narrow availability via `where Element: Sendable`; channel receivers remain usable without Sendable via `.elements`) are immediately actionable.

**Blocker**: Implementation of the concrete operator layer requires a strategic decision on the three open questions above — naming, module placement, and priority. Two of those decisions are sensitive to upstream Swift Evolution work on `sending` in closure types; committing to a layout now risks rework if the language gains a structural fix.

**Resumption trigger** (any of):
- Swift Evolution review/acceptance of `sending` in closure types lands (closes Open Question 3)
- A second consumer surfaces with a concrete need for non-Sendable element processing in the async layer (forces the priority decision)
- Ecosystem priority cycle reaches the async layer cleanup work (covers the strategic-prioritization channel)

**Held immediately-actionable findings** (apply regardless of deferral):
- `Async.Stream<Element: Sendable>` Sendable requirement is preserved as structurally necessary
- Bridge extensions use `where Element: Sendable` (correctly narrows availability)
- Channel receivers remain usable without Sendable via their `.elements` AsyncSequence path
4. **Scope**: Which operators need concrete versions? The recommendation identifies ~20 linear operators vs ~20 concurrent operators that inherently need type erasure.

### Immediate Decision (for the current migration)

**`Async.Stream<Element: Sendable>` keeps `Element: Sendable`.** This is not a workaround — it's the structurally correct constraint for a Sendable, type-erased async sequence. The bridge extensions correctly gate on `where Element: Sendable` to express: "you can convert a Channel receiver to a Stream when your elements are Sendable."

## References

### Internal Research
- `stream-isolation-preserving-operators.md` — Concrete operator architecture recommendation
- `stream-isolation-propagation.md` — 40+ operator isolation analysis
- `modern-concurrency-conventions.md` — Ecosystem concurrency philosophy
- `non-sendable-strategy-isolation-design.md` — Non-Sendable strategy pattern

### Internal Experiments
- `stream-isolation-preservation/` — 13-variant isolation test (Tests A-M)
- `nonsending-closure-type-constraints/` — Sync closure limitation
- `nonsending-sendable-iterator/` — @Sendable + nonsending interaction
- `sending-mutex-noncopyable-region/` — Slot pattern for region transfer

### External
- SE-0421: `next(isolation:)` for AsyncIteratorProtocol
- SE-0430: `sending` parameter and result values
- SE-0461: `NonisolatedNonsendingByDefault`
- PF #360: Mutex soundness, viral Sendability anti-pattern

## Update: Apple HTTP API Proposal (2026-04-02)

Apple sidesteps the `Element: Sendable` question entirely by designing their own `AsyncReader`/`AsyncWriter` protocols — no `AsyncSequence`, no `AsyncStream`, no iterator-based streaming at all. This validates the "design alternative streaming protocols" workaround identified in Option C of the analysis above.

Key observations:

- Apple's protocols are `~Copyable & ~Escapable` — they are structurally incompatible with `AsyncSequence`, which requires `Copyable & Escapable` conformers. This is not a temporary workaround but a deliberate architectural choice.
- Elements flow through `consuming Span<ReadElement>` (reader) and `inout OutputSpan<WriteElement>` (writer) — the element type itself can be `~Copyable`. No `Sendable` constraint on elements anywhere in the streaming layer.
- The protocols use `EitherError<ReadFailure, Failure>` for typed throws instead of existential error erasure.

This confirms that for high-performance IO streaming, purpose-built protocols that bypass `AsyncSequence`'s constraint requirements are the production-viable path. The `Async.Stream<Element: Sendable>` decision remains correct for type-erased async sequences; Apple simply chose not to use type-erased async sequences for IO.

**Source**: `https://github.com/apple/swift-http-api-proposal/blob/main/Sources/AsyncStreaming/Reader/AsyncReader.swift`
