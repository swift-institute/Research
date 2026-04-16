---
date: 2026-04-14
session_objective: Review the new IO witness + actor architecture produced by parallel agents and assess how it composes with the unrefactored IO Events / IO Completions modules.
packages:
  - swift-io
  - swift-witnesses
status: processed
processed_date: 2026-04-16
triage_outcomes:
  - type: research_topic
    target: witness-uniformity-vs-strategy-specialization.md
    description: "Resolve witness-uniformity vs strategy-specialization tension in @Witness macro design"
  - type: no_action
    description: "[package] Document load-bearing decisions in Package-Insights — generic guidance, no specific insight attached"
  - type: no_action
    description: "[skill] Require re-audit when scope generalizes — captured via research stub converged-scope-annotation-protocol.md"
---

# IO Witness Pivot — Multi-Agent Review Convergence and the Elided Events/Completions Elephant

## What Happened

Continuation session. Pre-compaction work (summarized in the conversation handoff) had produced a Tier 2 research document (`Research/io-witness-design-literature-study.md`) and an initial `IO = Context + Runner` implementation using `Task(executorPreference:)`. After compaction, parallel implementation agents diverged from that design and shipped a *different* shape: `IO` is now a **flat `@Witness` struct of five `@Sendable` async closures** (read, write, accept, close, unownedExecutor) backed by an internal `actor IO.Blocking.Actor` pinned to a concrete `Kernel.Thread.Executor`. Actor isolation provides mandatory binding — the load-bearing question from `HANDOFF-actor-runner-investigation.md` was answered correctly via mechanism C (actor with concrete executor, observable `unownedExecutor` for TCA26-style co-location).

The user asked me to review the new direction with full critical license. I read:

- `Sources/IO Core/IO.swift` (197 lines) — flat `@Witness` struct, 5 closures, manual extension methods for `close`/`unownedExecutor` because the macro can't generate methods for unlabeled-param or zero-arg closures
- `Sources/IO Core/IO.Error.swift` — unified 7-case `IO.Error` (connectionReset, brokenPipe, notConnected, timeout, cancelled, shutdown, platform)
- `Sources/IO Blocking/IO.Blocking.Actor.swift` — internal actor with sync syscall methods and `currentThreadID()` for tests
- `Sources/IO Blocking/IO+Blocking.swift` — `IO.blocking(_:)` and `IO.blocking(on:)` factories that bind the witness to one executor
- `Sources/IO Blocking/IO.Blocking.swift` — `IO.Blocking` pool (Sharded executors + Async.Semaphore admission)
- `Sources/IO Blocking/IO.Blocking.Run.swift` — separate `pool.run { }` API with admission, timeout, `Either<IO.Blocking.Error, E>` typed throws
- `Sources/IO Blocking/IO.Blocking.{Error,Options,Metrics}.swift`
- The vestigial `Sources/IO/` umbrella (20 files of pre-witness `IO.Reactor`, `IO.Run`, `IO.Stream`, `IO+open/read/write`)
- Confirmed `IO Events` (53 files) and `IO Completions` (50+ files) still implement the OLD closure-bag `Driver` model
- Verified `IO Core` builds clean

I delivered a 6-section critique covering: actor binding (correct), `unownedExecutor` exposure (correct), test thread-identity verification (correct), two parallel APIs in IO Blocking (witness vs pool) with different guarantees (problem), `accept` punting via runtime ENOTSUP (problem), two error types (problem), no cancellation/timeout in witness (problem), `IO.Blocking` capitalization-only naming collision (problem), `async` close + `~Copyable` ergonomic friction (Swift current-state limitation, well-documented), and the 100+ unrefactored files in IO Events / IO Completions still wired to the OLD architecture.

After my review I noticed a fresh-perspective review handoff from another Opus 4.6 session (`HANDOFF-io-layered-implementation-review.md`) and its point-by-point response (`HANDOFF-io-layered-implementation-review-response.md`). The other reviewer **independently identified the same load-bearing issue**: Events/Completions is "an elided ~100-file elephant" and the design ducks the question of whether `IO.Event.Channel`, `IO.Event.Selector`, `IO.Completion.Queue` etc. survive, get refactored, or move to `swift-sockets`. The response handoff explicitly agrees: "This is a genuine gap, not a context mismatch... The actor-runner investigation was scoped around 'how does `IO.blocking()` get mandatory executor binding?' That scope was deliberate. When the plan generalized from 'fix blocking' to 'unify swift-io's public API,' Events and Completions should have been brought into scope. They weren't."

## Handoff Triage

Eleven handoff files at `swift-foundations/swift-io/`. This session is a review session, not an implementation session — most handoffs belong to other agents' active workflows. Triage is conservative: annotate, do not delete.

| File | Status | Disposition |
|------|--------|-------------|
| `HANDOFF.md` | Pre-witness io_uring integration plan. Blockers 1 and 3 (typed Submission/Event, SQE module-boundary access) addressed by Kernel.Completion L1 promotion. Blocker 2 (compiler bug) likely still open. Next Steps 4-5 (io_uring CQ drain, IO.Reader iteration) superseded by witness pivot architecture. | Leave with annotation noting witness pivot supersedes most Next Steps. Other agent owns this. |
| `HANDOFF-actor-runner-investigation.md` | Investigation complete — actor binding shipped via `IO.Blocking.Actor`. Question 1 (consequences of actor isolation) answered by ship. Question 2 (avoid `@Sendable` on body) — current code still uses `@Sendable` closures. | Leave; the residual question 2 may matter for Events/Completions. |
| `HANDOFF-actor-state-visibility-fix.md` | Self-annotated INVESTIGATION COMPLETE — fix DEFERRED, audit-tracked. Five findings in `Research/audit.md`. | Leave; correctly self-managed. |
| `HANDOFF-blocking-driver-followups.md` | P0–P3 regressions from 2026-04-08 blocking refactor. Witness pivot may have changed the meaning of some (e.g., P0 sync-path-touches-cooperative-pool no longer applies under actor binding). | Leave; needs a reviewer who owns the blocking driver. |
| `HANDOFF-io-layered-implementation.md` | Active canonical handoff for the layered-capabilities design. References the superseded shape-b file as historical context. | Leave active. |
| `HANDOFF-io-layered-implementation-review.md` | Completed advisory review by independent Opus session. Findings document. | Leave; serves as durable record. |
| `HANDOFF-io-layered-implementation-review-response.md` | Active response handoff. | Leave active. |
| `HANDOFF-io-performance-measurement-response.md` | Completed measurement-response. Confirms Framing E with 320 ns/op data. | Leave; durable record. |
| `HANDOFF-io-shape-b-implementation.md` | Self-annotated SUPERSEDED 2026-04-14. Linked from the active layered-implementation handoff as historical context. | Leave (link target preservation). |
| `HANDOFF-shutdown-state-visibility.md` | Self-annotated DEFERRED, audit-tracked. CopyPropagation crash fixed; actor state visibility still an open compiler-interaction issue. | Leave; correctly self-managed. |
| `HANDOFF-split-cancellation-propagation.md` | Investigation pending — 4 disabled tests in IO Events. | Leave; pending investigation. |

No deletions performed. No audit findings updated (this session identified architectural issues but did not fix audit-tracked findings).

## What Worked and What Didn't

**Worked**:

- **Actor-isolated execution** as the answer to mandatory executor binding. Replacing `Task(executorPreference:)` (advisory per SE-0417) with an actor holding a concrete `Kernel.Thread.Executor` makes the binding survive `Task.sleep`, `@MainActor` hops, and unstructured tasks. The performance measurement handoff confirmed the per-op overhead is 320 ns (0.95× raw syscall) — well within the "≤ 2× raw" threshold. The pivot was correct and the mechanism is right.
- **TCA26 zero-hop co-location pattern** (`unownedExecutor` forwarded from consumer actor) is documented with a working example (`IO.swift:182-191`). This is the right ergonomic answer to the "actor sandwich" problem.
- **Multi-agent independent convergence** as a validation signal. Two reviewers (me, the fresh-perspective Opus session) working from different prompts and different prior context arrived at the *same* central critique (Events/Completions elided) and *several* of the same secondary critiques (accept ENOTSUP is a runtime lie; macro paying partial rent; capitalization-only API distinction). Independent convergence on a critique is far stronger evidence of a real problem than one reviewer's opinion.
- **Honest documentation of macro limitations.** `IO.swift:46-59` admits `@Witness(.mock)` cannot synthesize mocks for `borrowing Kernel.Descriptor` (the macro drops ownership annotations), names the workaround (manual init), and explains the `fatalError`-on-unimplemented behavior. Not glossed over.
- **Performance measurement handoff** (`HANDOFF-io-performance-measurement-response.md`) shows discipline: a real benchmark (`Experiments/io-stacked-actor-bench/RESULTS.md`) supersedes a prior intuition-based decision and explicitly notes "the load-bearing unknown is now known."

**Didn't work**:

- **Scope discipline on multi-agent handoffs.** The actor-runner investigation handoff was deliberately scoped to blocking-binding. The implementation handoff inherited that scope without re-auditing whether it still made sense after the goal generalized to "unify swift-io's public API." The result: ~100 files of pre-Shape-B runtime code in IO Events / IO Completions silently became "Phase 2 / Phase 3 roadmap" — i.e., elided.
- **Two parallel APIs co-existing in one module without a documented boundary.** `IO.blocking()` returns a witness (no admission, no timeout, mandatory binding via actor). `IO.Blocking().run { }` is a pool API (admission, timeout, advisory binding via `executorPreference`). They are differentiated only by `b` vs `B` capitalization. A consumer cannot tell from naming alone which guarantees they get.
- **Witness-contract uniformity vs strategy specialization** is unresolved. `IO.Blocking.Actor.accept` throws `.platform(.POSIX.ENOTSUP)` because blocking accept doesn't make sense in this strategy. Two cleaner type-system answers exist (split `IO` vs `IO.Socket` per the layered handoff; or capability-typed `IO<.AcceptCapable>`), but the current code chose neither and accepted the runtime lie.
- **The "umbrella IO/" module** (20 files: `IO.Reactor`, `IO.Stream`, `IO.Run`, `IO+open/read/write`) coexists with the new witness in the same `import IO` namespace. Different signatures (`IO.read(from: consuming) -> [UInt8]` vs witness `IO.read(from: borrowing, into: buffer) -> Int`), both reachable. Vestigial code from the previous design lives alongside the current design, with no deprecation markers.

## Patterns and Root Causes

**Pattern 1 — Multi-agent independent convergence as critique-validation.** When two reviewers working from different prompts independently identify the same central issue, that issue is real with high probability. The Events/Completions elision was flagged by both me (after reading the new code) and the fresh-perspective Opus reviewer (after reading the implementation handoff). The implementation author's response handoff agrees. Three independent agents converging means this isn't an opinion call — the design is incomplete and the path forward (resolve before propagating to Events/Completions) is settled. This is a useful pattern: when stakes warrant it, deliberately spawn an independent reviewer agent who hasn't seen the parent's reasoning trail. Convergence is signal; divergence is also signal.

**Pattern 2 — Scope generalization without scope-re-audit.** A handoff scoped narrowly ("fix blocking-binding") gets generalized to a broader problem ("unify swift-io's public API") without explicitly re-auditing what was previously elided. The original elision was justified for the original scope but becomes a load-bearing gap for the new scope. The actor-runner investigation correctly excluded Events/Completions because they weren't the blocking-binding problem. The implementation handoff inherited that exclusion silently. Generalization should be paired with: "What did I exclude under the old scope that must be brought back in under the new scope?"

**Pattern 3 — Witness contract uniformity is a design forcing function.** When a strategy can't honor an operation, three responses are available: (a) runtime trap (current — `throw ENOTSUP`), (b) type split (separate `IO` and `IO.Socket` witnesses), (c) capability typing (`IO<Capability>`). The current code chose (a) — the cheapest path that ducks the design question. (a) is a code smell: every consumer must know which strategy supports which operation, and the type system doesn't help. This recurs in any witness-based capability API: the type system either expresses capability differences or it pushes them to runtime. The `@Witness` macro has no opinion; the design must.

**Pattern 4 — Vestigial code accumulates during architectural pivots.** Three layers of dead/incompatible code from the design pivot:
1. `Sources/IO/` umbrella module (20 files) — pre-witness types living in the same namespace as the new witness
2. `Sources/IO Events/` (53 files) — closure-bag Driver model marked "Phase 2"
3. `Sources/IO Completions/` (50+ files) — closure-bag Driver model marked "Phase 3"

"Phase N" labels mask the fact that these aren't greenfield — they're consumer-facing runtime code that needs *refactoring* (or deletion, or relocation), not *adding*. The honest framing is "we have three competing architectures coexisting until we decide their fate." Calling them "phases" implies a forward path that doesn't actually exist.

**Pattern 5 — `@Witness` macro paying partial rent.** Per `IO.swift:121-135` and `IO.swift:46-59`: mock generation disabled (can't handle `borrowing`), manual extension methods needed for `close` (`consuming` keyword has no label) and `unownedExecutor` (zero-arg closure), `Calls` enum drops ownership params (descriptor-identity assertions need separate construction-time wrapping). When a macro is paying this much partial rent, the threshold question is: is the macro still earning its keep, or is it adding more cognitive overhead than handwritten boilerplate? The honest answer requires line-counting both alternatives. This is worth a swift-witnesses package insight even if the answer is "yes, still worth it."

## Action Items

- [ ] **[research]** Resolve the witness-uniformity-vs-strategy-specialization tension for IO. Three options on the table (runtime ENOTSUP, type split via `IO`/`IO.Socket`, capability-typed `IO<Capability>`). This blocks Events/Completions refactor — picking the wrong shape now multiplies into Phase 2/3. Decide before any further IO work.
- [ ] **[package]** swift-io: Document the load-bearing decisions in `Research/_Package-Insights.md` — (1) witness vs pool API split for Blocking (`IO.blocking()` no-admission-mandatory-binding vs `IO.Blocking().run { }` admission-advisory-binding); (2) `accept` ENOTSUP is provisional pending witness-uniformity decision; (3) `Sources/IO/` umbrella module and `IO Events`/`IO Completions` are pre-pivot code, not greenfield Phase 2/3.
- [ ] **[skill]** handoff: When a handoff's scope is generalized (e.g., "fix X" becomes "unify Y"), the agent MUST re-audit what was excluded under the original scope and explicitly re-classify each exclusion as still-out-of-scope or now-in-scope. The actor-runner investigation excluded IO Events/Completions correctly under "fix blocking-binding." The implementation handoff inherited that exclusion silently when the scope generalized to "unify swift-io public API," producing the elided-elephant gap that two independent reviewers caught.
