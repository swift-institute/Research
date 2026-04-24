---
date: 2026-04-21
session_objective: Audit Sendable surface in swift-property-primitives against the ecosystem's isolation-first preference; settle the outer conditional Sendable and the class-based State's @unchecked annotation; investigate whether a value-type ~Copyable State could eliminate the workaround.
packages:
  - swift-property-primitives
  - swift-primitives
  - swift-institute/Skills/handoff
  - swift-institute/Skills/experiment-process
  - swift-institute/Research/modern-concurrency-conventions
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Sendable audit, Option C, and the workaround-locus dimension

## What Happened

Continuation of the same day's session that produced the per-module test-target split and the `[SWIFT-TEST-003]` skill broadening (covered in `2026-04-21-swift-test-003-generic-hard-error.md`). This entry covers the subsequent work.

- **Coverage gap fills**: `Property.View.Typed` family had zero tests (4 source files in the View Primitives + 1 in View Read Primitives). Added 8 tests across new suite files. Also populated `Property.Consuming` Edge Case + Integration with the canonical `_read`/`_modify` + `defer { restore() }` accessor recipe — that's the public contract the DocC article promotes.
- **Test Support refactor** (suggested by the user when I proposed it): shared `Phantom` enum (12 local `struct Tag {}` declarations → one fixture; renamed from `Tag` after colliding with `Testing.Tag`), split `Slice.swift` (166 lines, 3 nested types) into 3 files, dropped unused `Container.Merge.Replace`, removed Performance suite stubs from all 10 files (they're INST-TEST scope, not main-target), extracted `RequireCopyable`/`RequireSendable` constraint helpers to Test Support.
- **Sendable audit** against `modern-concurrency-conventions.md`: Property / Property.Typed / Property.Consuming have conditional Sendable; State has unconditional `@unchecked Sendable` justified as a workaround to propagate the outer conditional through a reference-typed field.
- **Option A (applied)**: narrowed State's `@unchecked Sendable` from unconditional to conditional-on-`Base: Sendable` — the scope of the trust-me claim now matches the outer conformance. Commit `a54cab8`.
- **Option C (experimented)**: replaced class State with `struct State: ~Copyable`. Single-module debug experiment CONFIRMED — Sendable conforms WITHOUT `@unchecked`. Attempted production adoption.
- **Release-mode inliner crash surfaced**: Swift 6.3.1 SIL `EarlyPerfInliner` aborts with signal 6 (`Cannot initialize a nonCopyable type with a guaranteed value`) when the canonical `_read` accessor yielding a `~Copyable` Consuming is inlined across a module boundary. `@_optimize(none)` on the accessor works around it.
- **Perf benchmark**: class-State vs struct-State in direct-construction path (avoids the inliner crash path). Across 4 trial batches (best-of-10, N=10M), within measurement noise. The theoretical heap-allocation elimination doesn't materialize — escape analysis stack-promotes the class in tight loops.
- **Four-commit dance** (apply → revert → reapply → revert) driven by user challenges: "reconsider if we need @_optimize(none)" → perf benchmark → "why not do it now and remove @_optimize(none) when possible? that's closer to our timeless infrastructure" → clarification that the workaround is on CONSUMER sites, not in the library → "then Option C is not allowed right?" → settled on Option A.
- **Experiments relocated** from `swift-primitives/Experiments/` to `swift-property-primitives/Experiments/` per `[EXP-002c]` — package-local revalidation is the point.
- **Branching handoff** written for `pure-language-ownership-feasibility` — the broader question the Option C experience surfaced: if Swift 6.x has `consume` / `borrow` / `consuming` / `borrowing` / `~Copyable` / `~Escapable` / `@_lifetime`, can the four custom wrapper families be replaced with pure language semantics at equivalent ergonomics?

## What Worked and What Didn't

**Worked**:

- Applying Option A before Option C — the narrower-but-still-workaround form was a useful intermediate landing that made the subsequent Option C experiment's trade-offs concrete.
- User challenging each step — "reconsider if we need @_optimize(none)" → "why not do it now" → "then Option C is not allowed right?" — each question produced a different decision dimension. The productive four-commit revert dance was driven by these.
- Running the perf benchmark before committing to a design. The benchmark refuted my hypothesis cleanly (within noise across replicates).
- Relocating the two experiments into the package — revalidation is now `cd Experiments/property-consuming-value-state && swift build -c release`; when that stops crashing, Option C is viable.

**Didn't work initially**:

- My first Option C experiment validated debug-only, single-module. The release-mode cross-module inliner crash only surfaced when I attempted production adoption. A design-adoption experiment should have validated `-c release` + cross-module split up-front — those are the shipping build's properties.
- My initial Sendable-or-not recommendation under-weighted the consumer-side distribution of the workaround. I framed Option C as "transient debt replacing permanent debt" without first answering: where does the debt live? The user's "is this just OUR internal code" question was the crucial reframing.
- I let the user drive clarification by asking "would this mean each consumer would need to do @_optimize(none)?" That's a question I should have proactively answered before proposing Option C adoption.

## Patterns and Root Causes

**Pattern 1: The workaround-locus dimension is as important as the transient/permanent dimension when evaluating `@unchecked Sendable` alternatives.**

When a design requires a compiler workaround, four dimensions characterize the cost:

| Dimension | Option A (class State) | Option C (struct State) |
|-----------|------------------------|-------------------------|
| Duration | permanent (until redesign) | transient (until compiler fix) |
| Locus | library (one extension) | consumer (every accessor site) |
| Surface | type-level (@unchecked claim) | build-level (@_optimize(none) pragma) |
| Ergonomics for adopters | zero (conformance is library-internal) | signal-6 crash on first release build |

"Timeless infrastructure" sounds like it favors the transient option — but that framing silently ignores locus. A distributed transient workaround paid by every consumer can be strictly worse than a localized permanent workaround paid by the library once. The published-API version of "timeless" means *consumers don't inherit transient debt*; the library has to eat it.

This dimension deserves first-class status in `modern-concurrency-conventions.md` Convention 3 (`@unchecked Sendable` requires justification) — the "why a higher-ranked mechanism cannot be used" answer must include *where the cost of the chosen mechanism lands*, not just that the mechanism is necessary.

**Pattern 2: Design-adoption experiments must validate release-mode + cross-module, not just debug + single-module.**

The `property-consuming-value-state` experiment built cleanly and I marked it CONFIRMED. That validation was against `swift build` in the experiment's own directory — debug-mode, single-module. The production shape (release-mode build of a test target that imports Test Support which uses the canonical accessor pattern) crashed. The gap between "experiment says CONFIRMED" and "production adoption works" was six compiler passes' worth of optimization that the experiment's build mode didn't exercise.

The fix is mechanical: `[EXP-003a]` already allows per-experiment `swiftSettings`; the discipline addition is *if the experiment validates a design intended for production adoption, add `-c release` and a split library+executable target layout to the validation criteria before writing CONFIRMED*. Single-module debug is fine for "does this shape compile?" — insufficient for "is this safe to adopt?"

The earlier `sendnonsendable-iife-borrowing-init-crash` reducer (from the same day) needed the same discovery — single-module didn't crash; cross-module + release did. The shape of validation-gap is the same.

**Pattern 3: "Eliminates heap allocations" is a Swift-6-specific perf hypothesis that needs measurement.**

I proposed Option C in part on the theory that replacing a class State with a struct State eliminates N heap allocations per N Consuming instances. Measured: within noise. Escape analysis stack-promotes the class in tight loops. The `final class: @unchecked Sendable` + `let _state` pattern that looks expensive on paper is cheap in practice when the class doesn't escape.

Generalizable: before citing "eliminates allocations" as justification for replacing class with struct, benchmark with release + a non-trivially-folding workload. Modern Swift + ARC + escape analysis makes class allocation cost highly context-dependent. The corollary: `@unchecked Sendable` on a class that doesn't escape its local scope costs zero runtime — the cost it carries is type-honesty, not performance.

**Pattern 4: User-driven course correction via targeted questions is the productive shape of supervised investigation.**

The four-commit dance (Option A → Option C attempt → revert → Option C reapply → revert) cost ~45 minutes of wall-clock and produced four commits in a repo that doesn't strictly need four commits. But each cycle surfaced a different evaluation dimension:
1. Apply Option A: establishes baseline with narrowed claim.
2. Attempt Option C: surfaces the release-mode inliner crash.
3. Revert: establishes that @_optimize(none) is a cost.
4. Reapply Option C: tests the "timeless infrastructure" frame.
5. Revert: establishes that locus matters.

Each user question (`reconsider if we need @_optimize(none)?`, `why not do it now and remove @_optimize(none) when possible?`, `would this mean each consumer would need to do @_optimize(none)?`, `so then Option C is not allowed right?`) was the right question at the right moment. The total information gained would not have been available from a single analytical pass — it required the empirical cycle. This is a feature of well-supervised investigation, not a bug.

## Action Items

- [ ] **[skill]** experiment-process: add release-mode + cross-module validation requirement for design-adoption experiments. Single-module debug passes are insufficient for experiments whose CONFIRMED verdict would admit production adoption. The 2026-04-21 property-consuming-value-state experiment + sendnonsendable-iife-borrowing-init-crash reducer both exhibited the gap. Cite both as provenance. Candidate requirement ID `[EXP-003f]` or an extension to `[EXP-003a]`.
- [ ] **[doc]** modern-concurrency-conventions.md: add a "workaround locus" sub-section to Convention 3. The `@unchecked Sendable`-requires-justification rule currently asks *what mechanism provides thread safety* and *why a higher-ranked mechanism cannot be used* — it should also ask *where does the cost of the chosen mechanism land*. Library-local @unchecked on a non-escaping class is a different class of cost than consumer-distributed @_optimize(none).
- [ ] **[package]** swift-property-primitives: the branching handoff `HANDOFF-pure-language-ownership-feasibility.md` is the consolidated investigation into whether the four custom wrapper families (Property / Property.Typed / Property.Consuming / Property.View) can be replaced with pure Swift 6.x ownership semantics. Keep as an in-flight investigation; the findings section on that file is the returning-point.
