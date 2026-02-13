---
date: 2026-02-12
session_objective: Add zero-bit scanning infrastructure to Bit.Vector and update Storage.Pool.Inline.allocate() to use it
packages:
  - swift-bit-vector-primitives
  - swift-sequence-primitives
  - swift-storage-primitives
status: processed
processed_date: 2026-02-13
triage_outcomes:
  - type: skill_update
    target: existing-infrastructure
    description: Add Sequence.First tag to [INFRA-107] tag table
  - type: no_action
    description: Root-cause verification guidance — too generic for normative skill requirement; reflection itself captures the lesson
  - type: package_insight
    target: swift-bit-vector-primitives
    description: Test coverage gap for .ones.first and .ones.first { predicate }
---

# Bit Vector Zeros Infrastructure and Sequence.first

## What Happened

The session had two phases: research and implementation.

**Research**: Created `swift-institute/Research/bit-vector-zeros-infrastructure.md` analyzing the gap in `Bit.Vector` / `Bit.Vector.Static<N>` — the API had `.ones.forEach`, `.pop.first()` for set bits but nothing for zero bits. `Storage.Pool.Inline.allocate()` was using a raw `for i in 0..<capacity` loop to find the first unallocated slot, violating [IMPL-033] and [IMPL-002]. Recommended mirroring the full `.ones` API with `.zeros`.

**Implementation**: Created 9 files in `swift-bit-vector-primitives` mirroring the existing ones pattern exactly — `Zeros.View`, `Zeros.Static`, iterators, Sequence conformances, accessor properties on all three vector variants (`Bit.Vector`, `Bit.Vector.Static`, `Bit.Vector.Dynamic`). Updated the consumer in `Storage.Pool.Inline.allocate()` to use `_slots.zeros.first!`.

**The bug**: `_slots.zeros.first!` failed to compile. `.first` resolved to the `first(where:)` **method reference** (a function type) instead of a `var first: Element?` property. The `!` was applied to the method reference, which is non-optional, causing the error.

**Initial fix attempt**: Add `var first: Bit.Index?` directly to `Zeros.Static`. User rejected this and asked me to think it through.

**Initial (incorrect) root cause analysis**: I believed the issue was a disambiguation failure between `Swift.Sequence`'s `var first: Element?` property and its `first(where:)` method, caused by the dual conformance with `Sequence.Protocol`.

**Corrected root cause**: `var first: Element?` does NOT exist on `Swift.Sequence`. It is a `Collection`-only property (defined in `extension Collection`, not `extension Sequence`). On bare `Sequence` conformers — with or without `Sequence.Protocol` — `.first` resolves to the `first(where:)` method reference because that is the only member named `first`. The dual conformance with `Sequence.Protocol` is irrelevant. A bare `struct Foo: Swift.Sequence` has the exact same problem.

**Final fix**: Added `var first: Element?` to the `Sequence.Protocol where Self: Copyable` extension in `Sequence.Protocol+Swift.Sequence.swift`. This provides the convenience property that stdlib puts on `Collection` but not on `Sequence`. All three packages build clean.

**Audit**: Empirically verified all `Swift.Sequence` default implementations. `Swift.Sequence` provides only 2 properties: `underestimatedCount` (already disambiguated) and `lazy` (resolves fine, no conflict). All methods (`map`, `filter`, `reduce`, `sorted`, `min`, `max`, `contains(where:)`, `forEach`, `prefix`, `dropFirst`, etc.) resolve correctly. No further additions needed.

## What Worked and What Didn't

**Worked well**: The research-first approach produced a clean implementation plan. Mirroring the `Ones` pattern file-by-file made the 9-file implementation mechanical and correct — `swift-bit-vector-primitives` built on the first try. The consumer transformation (`_slots.zeros.first!`) reads as pure intent. The user's pushback ("think this through") prevented a per-type band-aid and led to the integration-layer fix. The follow-up audit corrected the root cause understanding.

**Didn't work well**: I misdiagnosed the root cause twice. First, I proposed a per-type fix without investigating. Second, when I moved the fix to the integration layer, I framed it as "disambiguation between `var first` and `first(where:)` on `Swift.Sequence`" — but `var first` doesn't exist on `Swift.Sequence` at all. The correct framing is "providing a missing convenience property." The misdiagnosis didn't affect the fix (the code is identical either way), but the doc comment was wrong until corrected by the audit.

**Confidence gap**: I assumed `var first: Element?` was a `Swift.Sequence` default because it's so universally available on stdlib collections. I never questioned this assumption until the empirical audit proved it wrong. This is a reminder that familiarity breeds false confidence — `Collection` refines `Sequence`, and most types conform to `Collection`, so the property *feels* like it belongs to `Sequence`.

## Patterns and Root Causes

**Pattern: `Collection` properties are not `Sequence` properties.** `var first: Element?`, `var isEmpty: Bool`, and `var count: Int` all live on `Collection`, not `Sequence`. Types that conform to `Swift.Sequence` without `Collection` (like `Zeros.Static`, `Ones.Static`, and any future lightweight iteration type) lack these properties. The `Sequence.Protocol where Self: Copyable` extension in the integration layer is the correct place to provide `var first` for these types.

**Pattern: Fix at the right abstraction level.** The per-type fix would have worked for `Zeros.Static` but left `Ones.Static` (and every future `Sequence.Protocol` conformer) without `var first`. The integration layer fix is a single addition that covers all current and future types. This is [IMPL-000] applied to infrastructure fixes: write the ideal fix, not the minimal fix.

**Pattern: Verify root causes before documenting them.** The initial doc comment ("disambiguates `Swift.Sequence.first` from `first(where:)`") was plausible but wrong. The audit — a 5-line Swift file — would have caught this immediately. When writing infrastructure-level documentation, empirical verification is cheap and prevents false knowledge from propagating.

## Action Items

- [ ] **[skill]** existing-infrastructure: Add `var first: Element?` to [INFRA-107] documentation, noting it is provided by the sequence integration layer because `Swift.Sequence` only has `first(where:)` — `var first` is `Collection`-only in stdlib
- [ ] **[skill]** implementation: Add guidance about verifying root causes empirically before documenting them — a 5-line test file is cheaper than propagating a wrong explanation
- [ ] **[package]** swift-bit-vector-primitives: `Ones.Static` and `Ones.View` never had `var first` exercised in tests — consider adding test coverage for `.ones.first` now that the integration layer provides it
