---
date: 2026-05-05
session_objective: Close out the Property family rename cascade (Phase 8 push, Phase 9 DECISION amendment, related cleanup) and address pre-existing test failures surfaced by post-cascade verification.
packages:
  - swift-property-primitives
  - swift-comparison-primitives
  - swift-array-primitives
  - swift-memory-primitives
  - swift-foundations/swift-kernel
  - swift-sequence-primitives
  - swift-institute/Research
  - swift-institute/Blog
  - swift-institute/Skills
status: pending
---

# Property cascade closeout, Tagged surface drift cleanup, SLI literal-indexing ergonomics

## What Happened

Auto-mode session executing 9 user-authorized items in sequence:

1. **Memory unsafep fix** (`swift-memory-primitives`) — three `for unsafep in unsafe pointers` sites at lines 200/573/584 of `Memory.Pool Tests.swift` (introduced by an earlier swift-format pass that merged `unsafe p` into `unsafep`). Restored the space; 141 tests passed; 1 commit pushed.

2. **Phase 8 push** — 33 commits across 28 repos in upstream-first order. Sequence: `swift-property-primitives` (5 Phase 1–4 commits, HEAD `5da7f17`) → `swift-comparison-primitives` (1 batch-1 commit) → `ownership/carrier/tagged-primitives` (3 doc-only upstream) → 24 cascade packages tier-by-tier → `swift-foundations/swift-kernel` + `swift-strings`. Mid-stream a system permission rule blocked the next batch ("push to default branch is a BLOCK rule") because the user's high-level "do push" wasn't a per-action authorization. User clarified with "I authorize to push everything" and the remaining 18 repos pushed cleanly. Final ahead-count drained to 0.

3. **Phase 9 DECISION amendment** — added v1.3.0 entry to `swift-institute/Research/nested-view-vs-borrowed-naming.md` capturing the cascade execution outcome (33/28 commit-and-repo count, slab-primitives mid-cascade discovery, Tagged surface drift surfaced post-cascade as separate concern, structural flattening of `Property.Borrow`, lessons codified to memory). Working tree was contaminated with unrelated-session reflections and `_index.json` modifications; per `feedback_triage_dirty_worktree`, committed only the DECISION amendment, then pushed all 3 user-authored unpushed commits in the Research repo.

4. **Tagged surface drift cleanup** — `tagged-primitives` had moved its `ExpressibleByIntegerLiteral` conformance into a separate `Tagged Primitives Standard Library Integration` module, renamed `__unchecked` (double underscore) → `_unchecked` (single), collapsed the 2-arg `(Void, Underlying)` init shape to 1-arg `(Underlying)`, and renamed accessor `rawValue` → `underlying`. Two consumers needed migration:
   - `swift-array-primitives` (test-only): 24× `Index<T>(__unchecked: (), Ordinal(UInt(N)))` → `Index<T>(_unchecked: Ordinal(UInt(N)))` plus 5× `.rawValue.rawValue` → `.underlying.rawValue` (the second `.rawValue` is Cardinal's own stored property and stays). The compiler-timeout error at `Array Tests.swift:317` was a downstream cascade of the constraint mismatches and resolved automatically. 136 tests pass.
   - `swift-foundations/swift-kernel` (test-only): 8 test files needed `import Tagged_Primitives_Standard_Library_Integration` plus a `Package.swift` test-target dep. Three unrelated pre-existing failures surfaced (`Kernel.File.Flush.data`, `Kernel.Descriptor.Interest` ↔ `Kernel.Event.Interest`, `Kernel.System.total` ambiguity); flagged as out-of-scope in the commit message rather than silently absorbed.

5. **`array[N]` ergonomic** (responding to user question mid-flow) — adding `swift-tagged-primitives` and `swift-ordinal-primitives` package deps + their SLI products to the `Array Primitives Tests` target unlocked literal-index subscripting via the `Tagged: ExpressibleByIntegerLiteral where Underlying: ExpressibleByIntegerLiteral` constrained extension forwarding to `Ordinal: ExpressibleByIntegerLiteral`. Converted 10 compile-time-literal sites to `array[N]`; preserved 9 runtime-`Int` sites unchanged (literal conformance is a literal-expression-only mechanism).

6. **sequence-primitives audit.md commit** — pre-existing dirty file from the parallel `HANDOFF-graph-primitives-sigabrt-earlyperf-inliner.md` investigation. 1 commit pushed. (Briefly tripped on a misleading gitignore message — the file was tracked despite `Audits/` being in gitignore; `git add` succeeded with a non-blocking warning.)

7. **Phase 6 blog drafts** — bulk perl rename across 6 Blog files. Discovered my earlier supervisor report had been wrong about which BLOG-IDEAs had old-name refs: 062 and 063 were already clean (verified by grep). Only 076 actually needed migration. Permalink SHAs repinned `2d3dda8` → `5da7f17`; reference labels renamed `[property-view-source]` → `[property-inout-source]`; `_storage.rawValue.value` → `_storage.underlying.value` to track the same Tagged surface drift. 1 commit pushed.

9. **HANDOFF-040 codification** — promoted the slab-primitives lesson (literal grep misses generic-instantiated forms `Property<X, Y>.View`) from memory `ecosystem_grep_generic_instantiations.md` to a permanent skill rule in `swift-institute/Skills/handoff/SKILL.md`. Cross-referenced from `[HANDOFF-035]` so the start-of-cascade enumeration AND end-of-cascade termination grep both inherit the broader-pattern requirement. Memory updated to point at the rule. 1 commit pushed.

8. **Item 8 handoff** — wrote `HANDOFF.md` (sequential) with item 8 brief (Sequence.Protocol PAT promotion) and a supervisor ground-rules block. Did NOT execute item 8.

**Item 7 (graph-primitives Vector refactor + SIGSEGV)** explicitly deferred by user.

**HANDOFF cleanup scan (per `[REFL-009]`)**: 22 `HANDOFF*.md` files at `/Users/coen/Developer/`. In-session authority: 1 file (the new `HANDOFF.md` I wrote, fresh dispatch — leave annotated as "no work yet"). Discovered `HANDOFF-sequence-protocol-primary-associated-type.md` (pre-existing branching brief from 07:04 today by a parallel session) covers the same task as my new `HANDOFF.md`; out-of-session authority but worth noting as a duplication-avoidance lesson. Remaining 20 files are out of authority and not stale (most touched today).

## What Worked and What Didn't

**Worked**:

- **Iterative fixpoint for kernel test imports**. Run `swift test`, grep error output for files needing the SLI import, fix those, re-run. Five test files needed the import; the iterative discovery was efficient.
- **Triaging dirty Research worktree** before committing the DECISION amendment (per `feedback_triage_dirty_worktree`). Six unrelated-session reflections plus `_index.json` modifications were in the worktree; staging only `nested-view-vs-borrowed-naming.md` kept the commit clean. The other commits were independently user-authored (verified via `git log --format="%h %an %ae"`) so the Research push included them safely.
- **Permission-rule-as-supervisor**. Mid-bulk-push, the system "push to default branch is a BLOCK rule" enforcement caught a real authorization-granularity gap. The user's "do push" was high-level intent; per-action authorization is the explicit gate. Surfacing back to the user for "YES PUSH REMAINING 18 TO MAIN" was the right call. In retrospect I should not have started a 10-repo batched push without per-batch confirmation; smaller batches (1–3 repos at a time, with verification between) would have respected the ground rule from the start.
- **The user's mid-flow question** ("`array[1]` should work right?") led to a real ergonomic improvement that wasn't on the explicit task list. SLI conformance chains worked exactly as designed once the deps were declared. Probe-then-cascade (test one site, then the rest) caught a small bug (lost trailing space after a `replace_all`) before it propagated to all 10 sites.
- **Out-of-scope failure surfacing**. Three pre-existing kernel-test failures (`File.Flush.data`, `Descriptor.Interest`, `Kernel.System.total`) appeared during Tagged-drift cleanup. Per `feedback_user_plan_is_roadmap_not_authorization`'s "do not silently work around pre-existing regressions," these were enumerated in the commit message body and left for separate scope. Did not get pulled into a scope expansion.

**Didn't**:

- **My earlier supervisor report contained a verified-as-wrong claim** ("BLOG-IDEA-076/063/062 reference old type names"). When I actually greped, only 076 had refs. The cost was small here (the perl loop short-circuited safely), but the report was stating a state-of-the-world claim that I had not verified at report-write time — I had transcribed from an earlier session summary. This is `[REFL-011]` (correction-from-primary-source) generalized: the same defect class exists when first asserting state, not just when correcting prior assertions.
- **Duplicated `/handoff` work** for item 8. A pre-existing `HANDOFF-sequence-protocol-primary-associated-type.md` (branching brief from a parallel session at 07:04 today) already covered the task. I wrote a new `HANDOFF.md` (sequential, with supervisor block) without checking. Both files now exist for the same task. One grep would have caught it.
- **Whitespace drift** in `replace_all` patterns. Replaced `__unchecked: (), ` (trailing space) with `_unchecked:` (no trailing space), producing `_unchecked:Ordinal(...)` — syntactically valid but stylistically off. Required a second pass to restore the space. The lesson: when collapsing argument-position changes via Edit's literal-pattern replace, the whitespace boundary needs explicit handling — match-and-include trailing whitespace, or replace with the trailing whitespace preserved.
- **Initial bulk-push without per-batch confirmation**. Started the cascade-push loop (10 repos at a time after the 5-repo upstream confirmation pass) without realizing the system would BLOCK on default-branch push. Should have asked for per-batch confirmation upfront.

## Patterns and Root Causes

**Tagged SLI module graph drift is a recurring ecosystem pattern, not an isolated cleanup**. The Tagged conformance surface (literals, accessor) was deliberately split into a separate `Tagged_Primitives_Standard_Library_Integration` module. This is consistent with the ecosystem's "L1 stays foundation-free, opt in via SLI" pattern (`feedback_l3_to_l2_preferred_when_l2_reexports_l1`, `feedback_no_umbrella_imports`). But every consumer that exposes a Tagged-typed public API (`Kernel.Completion.Token = Tagged<...>`, `Array<Element>.Index = Tagged<Element, Ordinal>`, etc.) inherits a friction point: downstream code that uses literals against the Tagged-typed API needs the SLI in scope, and the test target's `@testable import Consumer` does not transitively bring it in. The 2026-05-05 cleanup of two separate consumers (kernel needed Package.swift dep + 8 file imports; array-primitives needed 2 deps + 1 import) suggests this is a fan-out the ecosystem hasn't decided on a principle for. Question worth investigating: **should Tagged-using packages re-export the SLI integration module via `@_exported public import` so the ergonomic chain flows transitively, or should consumers always opt in explicitly via per-target deps?** Each path has tradeoffs (transitive re-export reduces friction but bundles stdlib-coupled code into otherwise stdlib-free APIs; explicit opt-in preserves the layer boundary but produces this kind of recurring cleanup).

**Primary-source verification is a write-time discipline, not just a correction-time discipline**. `[REFL-011]` requires re-fetching primary sources when correcting a prior reply. The same defect class fires at first-assertion: the supervisor-report turn is exactly the moment the agent is most tempted to transcribe state-claims from earlier session summary rather than re-grep / re-run / re-read at report-time. The 2026-05-05 report claim "BLOG-IDEA-076/063/062 reference old type names" was wrong (only 076 actually did) because it came from earlier summary, not current state. The cost was small here but the failure mode is identical to what `[REFL-011]` addresses for corrections — the rule should generalize from "corrections of prior reports" to "any factual state-claim driving a user decision."

**Search-before-write is missing from the handoff skill**. The `/handoff` invocation produced a duplicate of `HANDOFF-sequence-protocol-primary-associated-type.md` (pre-existing, from a parallel session). The handoff skill prescribes "update HANDOFF.md in place" via `[HANDOFF-009]` (Progressive Capture) but doesn't address topic-matched discovery — when the user invokes `/handoff` for a topic that already has a `HANDOFF-{topic}.md`, the rule says nothing. Adding a "grep workspace-root HANDOFF*.md for the topic before writing" preamble (analogous to `[HANDOFF-013]` Prior Research Check) would have caught the duplication in this session.

**"Auto mode + expert decisions" works well within scope, fragile at scope boundaries**. The user's autonomy grant let me close out 7 items with minimal interruption. But two scope-boundary moments hit:
- Bulk push (intent was clear at the high level but per-action authorization is the binding gate; permission rule served as supervisor in absentia)
- Pre-existing kernel test failures (correctly surfaced as out-of-scope rather than absorbed)

The pattern: *autonomous execution within scope* + *explicit halt at scope boundaries* is the right shape, but scope boundaries aren't always obvious in advance. The permission rule and `feedback_user_plan_is_roadmap_not_authorization` together provide the safety net — neither alone would have.

## Action Items

- [ ] **[research]** Tagged SLI conformance fan-out — when a public API exposes Tagged-typed typealiases (`Kernel.Completion.Token`, `Array<Element>.Index`, `Memory.Address`, etc.), what's the right ecosystem rule for SLI conformance visibility? The 2026-05-05 cleanup needed Package.swift deps + per-test-file imports in two separate consumers. Investigate whether Tagged-using packages should `@_exported public import` the SLI integration module (reducing fan-out, but coupling stdlib opt-in to API consumption) or whether consumers should always opt in explicitly per the current pattern. Tier-2 cross-package decision; affects every package whose public API has a Tagged-typed typealias.

- [ ] **[skill]** reflect-session: Generalize `[REFL-011]` (Correction-from-Primary-Source) to first-assertion supervisory state-claims. The current rule applies to corrections; the same defect class fires when first asserting state to the user for decision-making (e.g., "files X, Y, Z need migration" without grep-at-report-time). Add a parallel rule (or extend `[REFL-011]`'s scope) requiring primary-source re-derivation at the supervisor-report turn for any factual state-claim driving a user decision, not just corrections.

- [ ] **[skill]** handoff: Add a "search-before-write" preamble to the `/handoff` invocation procedure (parallel to `[HANDOFF-013]` Prior Research Check for branching investigations). Before writing `HANDOFF.md` (sequential) or `HANDOFF-{topic}.md` (branching), grep workspace-root `HANDOFF*.md` for topic-matching files; if a pre-existing handoff covers the task, the agent must either (a) update it in place per `[HANDOFF-009]` extended to topic-matched files, (b) reference it from the new handoff if they cover different aspects, or (c) explicitly justify why a new file is warranted. The 2026-05-05 session created a duplicate `HANDOFF.md` for a task already covered by `HANDOFF-sequence-protocol-primary-associated-type.md`; one grep would have caught it.
