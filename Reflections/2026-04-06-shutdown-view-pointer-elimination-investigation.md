---
date: 2026-04-06
session_objective: Investigate whether Shutdown view types can eliminate UnsafeMutablePointer
packages:
  - swift-io
  - swift-property-primitives
  - swift-storage-primitives
status: pending
---

# Shutdown View Pointer Elimination — @_unsafeNonescapableResult Is Orthogonal to TemporaryPointers

## What Happened

Executed a branching handoff investigation (`HANDOFF-shutdown-view-pointer-elimination.md`)
evaluating four alternatives for removing `UnsafeMutablePointer` from `IO.Event.Channel.Shutdown`
and `IO.Stream.Shutdown`. Both are `~Copyable, ~Escapable` view types yielded by `_read`/`_modify`
coroutines, storing a pointer to their parent for mutating access through non-mutating methods.
10 total `unsafe` sites (7 channel, 3 stream).

Investigated all four alternatives:
1. Closure-based / enum: eliminates all `unsafe` but changes API shape
2. Inout parameter: strictly worse than enum, not recommended
3. `@_unsafeNonescapableResult`: wrong diagnostic — addresses lifetime-dependence, not TemporaryPointers
4. Wait for Swift: recommended — current design is provably safe

Also discovered a fifth approach (stored values + mutating methods) that partially works
for the channel layer but not the stream layer. Findings appended to the handoff document.

## What Worked and What Didn't

**Worked well**: Cross-ecosystem research. The swift-primitives `Property.View` pattern
(85+ files using `UnsafeMutablePointer<Base>` in `~Escapable` views) immediately established
that the pointer pattern is the ecosystem norm, not a local workaround. The
`REVALIDATION-lifetime-read-6.3.md` and `escapable-deinit-lifetime.md` research documents
in swift-storage-primitives provided precise evidence that `@_unsafeNonescapableResult`
targets a different diagnostic.

**Confidence was high** throughout — the investigation was well-scoped by the handoff
document, and each alternative could be definitively assessed without writing experimental code.

**One non-obvious finding**: The "stored values + mutating methods" approach (not listed in
the handoff) eliminates the pointer for `IO.Event.Channel.Shutdown` but fails for
`IO.Stream.Shutdown` because the stream layer delegates to the channel layer and requires
a reference to the parent. This asymmetry — the same pattern failing at different layers
for different reasons — is worth noting for future view type designs.

## Patterns and Root Causes

**Diagnostic orthogonality**: `TemporaryPointers` and lifetime-dependence are orthogonal
compiler checks. `@_unsafeNonescapableResult` suppresses lifetime tracking on return values;
`TemporaryPointers` fires at pointer-creation sites regardless of lifetime annotations.
The handoff correctly suspected this might not work ("check if the attribute works on
`_read`/`_modify` coroutines") but the reason it doesn't apply is more fundamental than a
crash bug — it's the wrong tool for the job.

**Layer delegation prevents local fixes**: `IO.Stream.Shutdown` exists to map
`IO.Event.Failure` to `IO.Error`. This error-mapping wrapper requires a reference to the
parent, which requires a pointer. Any approach that works at the channel layer alone
(stored values, closures receiving channel) still leaves the stream layer needing a pointer.
This is a recurring theme: wrapper layers that exist purely for type adaptation re-introduce
the constraints that lower layers might escape.

**The ecosystem has chosen its pattern**: 85+ files in swift-primitives use
`~Escapable` + `UnsafeMutablePointer`. The `Property.View` type is the canonical
implementation. Deviating from this pattern for two types in swift-io would create
inconsistency without eliminating `unsafe` from the ecosystem overall. The real fix is
a language feature (stored `inout` or smarter diagnostics), not a per-type workaround.

## Action Items

- [ ] **[skill]** memory-safety: Add guidance that `@_unsafeNonescapableResult` suppresses lifetime-dependence diagnostics only, not `TemporaryPointers` — they are orthogonal checks
- [ ] **[research]** Track Swift Evolution proposals for stored `inout` references or `TemporaryPointers` improvements that would eliminate `~Escapable` view pointer workarounds ecosystem-wide
- [ ] **[package]** swift-io: When Swift gains stored `inout` for `~Escapable` types, both Shutdown views and the REVALIDATION file can be updated — channel and stream layers together
