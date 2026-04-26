---
date: 2026-04-24
session_objective: Deliver swift-ownership-primitives + swift-property-primitives ecosystem integration (Property.View* built on Tagged<Tag, Ownership.*<Base>>) under a Swift 6.3.1/6.4-dev release-mode miscompile, and run a commit+push sweep across affected repos
packages:
  - swift-ownership-primitives
  - swift-property-primitives
  - swift-memory-primitives
  - swift-buffer-primitives
  - swift-async-primitives
  - swift-institute/Experiments
  - swift-institute/Audits
  - swift-institute/Blog
status: processed
processed_date: 2026-04-26
triage_outcomes:
  - type: skill_update
    target: experiment-process
    description: "[EXP-018] Claim Validation Trap — Synthetic-to-Production Extrapolation. Dual to [EXP-011]'s Workaround validation trap; minimal reproductions cannot validate claims at scale either. Per-target package-level regression tests required before extrapolating production-impact claims."
  - type: no_action
    description: ".docc-build/ pattern in Scripts/sync-gitignore.sh canonical block — already RESOLVED 2026-04-24 via commit a7ab681 (before this reflection was authored)."
  - type: research_topic
    target: withUnsafe-borrowing-noncopyable-pattern-reach-survey.md
    description: "IN_PROGRESS Tier 2 research doc surveying stdlib withUnsafe* APIs accepting borrowing parameters; empirical work (V13 + per-API reproducers + per-consumer regression guards) deferred until audit action A2 (upstream compiler-issue filing) is authorized."
---

# ~Copyable `@inlinable` ABI miscompile fix and V11 narrow-shape overclaim walk-back

## What Happened

The session opened with a `/handoff` skill tweak ([HANDOFF-011] — copy-pastable blocks must start with "for the next task, find the relevant skills…") and expanded into the swift-ownership-primitives + swift-property-primitives integration arc for the 0.1.0 pre-release, colliding mid-arc with a Swift 6.3.1 / 6.4-dev release-mode miscompile that blocked `Property.View.Read` from integrating with `Ownership.Borrow`.

**The compiler bug.** `withUnsafePointer(to: borrowing value)` where `Value: ~Copyable`, wrapped in an `@inlinable` init that stores the returned `UnsafePointer<Value>` into a `~Escapable` return value, returns a pointer into a *callee-frame spill slot* when inlined across a module boundary. The spill slot dies with the inlined call; release mode reads yield garbage or trap, debug mode reads happen to still hold the pre-death bits. `withUnsafeMutablePointer(to: &value)` with `inout value` works — the bug is specific to `borrowing` + `withUnsafePointer` under `@inlinable`.

**The workaround.** Remove `@inlinable` from both `Ownership.Borrow.init(borrowing:) where Value: ~Copyable` and `Property.View.@unsafe init(_ base: borrowing Base)`. The cross-module function-call boundary preserves the `@in_guaranteed` indirect ABI the inlined form loses. Applied in commits `ece5d7e` (Ownership.Borrow) and the paired property-primitives `764db07` (Property.View `@unsafe` init) + `a597340` (integration restore from WIP). The Copyable-Value path required a separate fix — `_Ownership_Borrow_OwnedBuffer` class holding a heap-allocated copy, since register-passed trivial types have no caller-stable address to borrow (commit `a02e96c`).

**Integration achieved on main.** `Property.View` now stores `Tagged<Tag, Ownership.Inout<Base>>`; `Property.View.Read` now stores `Tagged<Tag, Ownership.Borrow<Base>>`. Downstream consumer migration (`base.pointee` → `base.value`) landed across swift-memory-primitives (Memory.Pool, 2 files), swift-buffer-primitives (Buffer.Linear/Linked/Ring/Slab/Arena Property.View* extensions, 26 files).

**V10/V11 agent overclaim — walked back.** A subordinate agent produced V10/V11 field-of-self reproducers (non-generic `~Copyable` container with plain stored `~Copyable` field, `@inlinable` method doing `withUnsafePointer(to: _storage)`) and claimed a second compiler-bug variant affecting `Memory.Inline.pointer(at:)` in production release. Two successive `withUnsafePointer` calls in the reproducer returned addresses 8 bytes apart with garbage dereferences. Before accepting the claim and applying ecosystem-wide fixes, authored package-level regression-guard tests: `Memory.Inline<Int, 4>.pointer(at:)` stability (swift-memory-primitives `e390d7a`), `Buffer.Ring.Bounded.peek.front/back` (swift-buffer-primitives `92e53fe`), `Async.Timer.Wheel` cross-module public-state reads (swift-async-primitives `26e76e1`). **All 3 regression guards passed in release mode**. The V11 narrow-shape compiler bug does not reach production code with `@_rawLayout(likeArrayOf: Element, count: capacity)` + generic Element + stride-arithmetic pointer derivation. The precise structural discriminator was not isolated (V13 deferred until A2 filing). Audit finding #12 rewritten from HIGH to LOW (watchflag); shipping scope restored to NORMAL.

**Blog draft.** `Blog/Draft/introducing-ownership-primitives.md` (BLOG-IDEA-063, ~1700 words) produced as companion to the already-reviewed `Blog/Review/se-0519-first-class-references.md`, taking path 1 (separate companion, voice per `feedback_ownership_reference_last_resort.md` — last-resort framing, no marquee/flagship language). Converged through `/collaborative-discussion` (4 rounds with ChatGPT) and `/swift-forums-review` pressure-test. User approved draft; publishing deferred per `feedback_blog_publish_two_steps.md` (Blog-push separate, swift-institute.org port separate).

**Commit + push sweep (end of session).** User authorized "commit all, push, dont make public, dont tag." 9 new commits authored this turn for pre-existing uncommitted work, grouped by semantic unit via diff-reading:

| Repo | Commits |
|---|---|
| swift-memory-primitives | `d5bb2c4` — Memory.Pool `.pointee` → `.value` |
| swift-buffer-primitives | `db34b05e` — Buffer Property.View* `.pointee` → `.value` (26 files) |
| swift-async-primitives | `8f0bbd88` drop Mutex coroutine API; `9ca7ae4d` Semaphore withPermit `Either<Error, E>`; `1a2c752b` Channel import reorder; `6b77be2d` DocC Semantics + README; `4d014e4c` Research forum-review + inventories |
| swift-institute/Experiments | `e6cda0f` — tagged-string-literal identity→tagged rename |
| swift-institute/Audits | `7af4bb3` — post-cycle-3 audit + cycle-3 handoff |

Then pushed 69 total commits across 7 repos (ownership 30, property 7, memory 3, buffer 2, async 7, Experiments 11, Audits 9). `swift-institute.org` untouched. No tags. `Sources/Async Primitives/Async Primitives.docc/.docc-build/` left untracked (build output; see Action Items).

**Handoff scan** (CWD = `/Users/coen/Developer/swift-institute/swift-institute.org`; no HANDOFF files at CWD root). Two session-scoped HANDOFF files at `/Users/coen/Developer/` in bounded-authority case (b) (actively-worked items):

- `HANDOFF-ownership-borrow-release-miscompile.md` — annotated with current Next Steps status (B1–B6 editorial all complete, pushes landed, A2 upstream filing still DEFERRED, publishing + tag 0.1.0 gated on separate per-action auth). **Retained** — A2 + publishing + tag items remain open.
- `HANDOFF-ownership-primitives-precursor-blog.md` — annotated scope-complete (path 1 chosen, draft + convergence + forums-review done). **Retained** for path-decision rationale; publishing covered by the parent handoff.
- 7 other HANDOFF-*.md files at `/Users/coen/Developer/` (ci-centralization, ci-rollout, docc-umbrella, executor-main-platform-runloop, heritage-transfers, io-completion-migration, migration-audit, package-refactor) — out-of-session-scope, left untouched.

**Audit scan.** `Audits/borrow-pointer-storage-release-miscompile.md` (12 findings). Agent updated statuses during session — 8 RESOLVED 2026-04-24 (#2, #3, #4, #5, #6, #7, #8, #10), 2 OPEN (#9 trivial doc update, #12 V11 watchflag), 1 DEFERRED (#1 upstream compiler bug). Per [REFL-010] no further status updates pending — session's work is already reflected.

## What Worked and What Didn't

**Worked**:

- The user's mid-session redirect *"the whole pay-off is to have the latter be built on the former. That's the integration!"* collapsed the remaining design space in one sentence. Prior to that redirect the work drifted toward "independent packages build cleanly" which did not address the actual integration goal. One framing correction saved what would have been a meandering optimization arc.
- Authoring package-level regression tests BEFORE accepting the subordinate agent's V10/V11 production-impact claim. Caught the HIGH→LOW severity inversion on audit finding #12 that would otherwise have blocked shipping on a compiler bug the production code does not reach. The 3/3 empirical signal (memory, buffer, async all pass release) is stronger evidence than any synthetic reproducer could provide.
- `/swift-forums-review` pressure-test on the blog draft. The skill's triage artifact (concreteness-anchor counts per archetype post) separated "archetype-shaped noise" from "load-bearing critique" mechanically; the draft passed the triage with only sentence-scale clarifications needed.
- Splitting the end-of-session commit sweep by semantic unit via diff-reading rather than one bulk commit. 40+ pre-existing uncommitted files landed as 9 clear commits ("drop coroutine API," "partition errors via Either," "DocC Semantics + README guidance," "forum-review artifacts") rather than a misc WIP dump.
- Honoring `feedback_no_public_or_tag_without_explicit_yes.md` end-to-end: pushed to pre-existing public repos where visibility did not change; did not push swift-institute.org; did not tag 0.1.0; both deferred to explicit per-action yes.

**Didn't work**:

- Initial Copyable-path `_Ownership_Borrow_OwnedBuffer` struct implementation hit `cannot infer implicit initialization lifetime` on the implicit memberwise init. Had to add an explicit internal designated init with `@_lifetime(borrow pointer)`. Would have been faster to preempt by writing the designated init with the lifetime attribute from the start — the implicit memberwise init on an `~Escapable` struct is a known trap.
- V10/V11 overclaim almost propagated into HIGH-severity audit findings and an ecosystem-wide production-code sweep. The principal's *"shouldn't we verify with a test in each package (would act as a regression guard later)"* prompt was the saving throw; without it the subordinate's synthetic-reproducer claim would have become session-level truth.
- Test-count reporting ("46/48 pass release and debug on property-primitives; 113/47 pass release and debug on ownership-primitives") initially read to the user as pass/fail ratios. The denominators are suite counts. Minor communication friction corrected within one turn.
- End-of-session Experiments push-question wasn't unambiguously answered by the user's combined reply ("we also want to commit pre-existing, but in clear commits"). Proceeded on the combined-instruction reading (push includes Experiments; "don't make public" is about visibility change, not push-destination). Correct in retrospect per the canonical feedback memory, but the ambiguity cost a sentence of hedging in the final reply.

## Patterns and Root Causes

**Pattern 1 — `@inlinable` is load-bearing for ~Copyable ABI.** The standard ergonomic guidance ("mark inits `@inlinable` for cross-module performance") collides with the stdlib's `@in_guaranteed` indirect-passing convention for ~Copyable borrowing parameters. When a wrapper init on a `borrowing T` (T: ~Copyable) is inlined into the caller, the caller's frame becomes the source of truth for the borrowed value's address — and any `UnsafePointer<T>` derived via `withUnsafePointer(to:)` inside the inlined body points into that inlined caller's frame, not into the original caller's. Storing that pointer into a `~Escapable` return (the `@_lifetime(borrow value)` affordance) captures a lifetime that ends at the inlined call's frame boundary, which is not the lifetime `@_lifetime(borrow value)` intends to name. Removing `@inlinable` is therefore **ABI preservation, not an optimization choice** — the cross-module function-call boundary is the thing keeping the `@in_guaranteed` indirect address stable.

The generalization: any wrapper init that takes `borrowing T` where `T: ~Copyable` and stores an `UnsafePointer<T>` derived from `withUnsafePointer(to:)` has the same latent issue. `Ownership.Borrow` and `Property.View` were the two the session hit; the action-item research question surveys whether `withUnsafeBytes(of:)`, `withUnsafeMutablePointer(to: consuming/borrowing)`, and `withUnsafeTemporaryAllocation` exhibit the same shape.

**Pattern 2 — Synthetic reproducers validate pattern existence, not pattern reach.** V11's narrow-shape reproducer triggered a genuine compiler bug in its constructed shape. But the constructed shape is not the production shape. Production `Memory.Inline` uses `@_rawLayout(likeArrayOf: Element, count: capacity)` + generic Element + stride arithmetic inside the `withUnsafePointer` closure; one or more of those invariants prevents the optimizer from producing the failing code path. The minimal reproducer *narrowed* the bug to a specific combination of language features; the production code evaded that combination by structural accident (or structural design — the `@_rawLayout` discriminator hasn't been isolated).

[EXP-011] "Workaround validation trap" already says minimal reproductions cannot validate workarounds at scale. The dual holds: minimal reproductions cannot validate *claims* at scale either. Package-level regression guards are the mandatory grounding step between *"the reproducer shows the pattern"* and *"production code is affected."* Three empirical passes on three different production shapes (Memory, Buffer, Async) is a much stronger signal than N synthetic variants.

**Pattern 3 — Multi-agent cycles work when handbacks are explicit.** The session alternated between main-context decision-steering and spawned-agent implementation/research. Each handback explicitly named: what was done, what verification ran, what decision was deferred to principal. This prevented execution drift (`feedback_supervisor_no_execution_drift.md`) and kept claims accountable. The V11 overclaim was caught at a handback — principal's *"verify with package tests first"* redirect arrived before the claim propagated into ecosystem edits. The pattern: synthesis stays with principal; subordinate's job is to enumerate options, not to decide.

## Action Items

- [ ] **[skill]** experiment-process: Extend [EXP-011] "Workaround validation trap" to also cover claim validation — synthetic reproducer claims about production-code impact MUST be validated by package-level regression tests in the target packages before extrapolation, regardless of whether the context is workaround-validation (current scope) or pattern-reach validation (new scope). Provenance: 2026-04-24 V10/V11 HIGH→LOW audit-finding inversion after memory/buffer/async regression guards empirically passed 3/3.
- [ ] **[package]** swift-institute: Add `.docc-build/` pattern to `Scripts/sync-gitignore.sh` canonical gitignore template; currently leaks into `git status` on any package that has run local DocC builds (observed this session on swift-async-primitives).
- [ ] **[research]** Does the `withUnsafePointer(to: borrowing value)` + `~Copyable` Value + `@inlinable` + cross-module miscompile pattern extend to other `withUnsafe*` APIs — `withUnsafeBytes(of:)`, `withUnsafeMutablePointer(to:)` under `borrowing`/`consuming` parameters, `withUnsafeTemporaryAllocation`? Scope: enumerate the stdlib's unsafe-pointer family accepting `borrowing` parameters; construct minimal reproducers per API; cross-check production `Memory.*` / `Property.*` / `Buffer.*` consumers. Output feeds the eventual upstream compiler-issue filing (gated on A2).
