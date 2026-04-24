---
date: 2026-04-21
session_objective: Work the HANDOFF-mod-017-batch-followups.md investigation — resolve three pre-existing defects surfaced by the MOD-017 batch migration (empty Algebra Core scaffolding; Binary umbrella missing two re-exports causing 390 test errors; Machine test suite hitting a Swift 6.3.1 SILGen crash on typed-throws @Sendable closure cast).
packages:
  - swift-algebra-primitives
  - swift-binary-primitives
  - swift-machine-primitives
  - swift-institute/Experiments
  - swift-institute/Skills/code-surface
  - swift-institute/Skills/implementation
  - swift-institute/Skills/audit
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# MOD-017 batch follow-ups: iterating a SILGen workaround under tightening design constraints

## What Happened

Dispatched from `/Users/coen/Developer/swift-primitives/HANDOFF-mod-017-batch-followups.md` with `/implementation` pre-loaded and `/code-surface`, `/modularization`, `/platform` loaded on request. The handoff enumerated three defects verified as non-regressions by the batch agents: (1) Algebra Core reduced to a one-line re-export shell, (2) Binary umbrella missing `Binary_Cursor_Primitives` + `Binary_LEB128_Primitives` causing 390 compile errors in tests, (3) Machine test suite hitting a signal-5 SILGen crash in `createInputFunctionArgument` / `LoweredParamGenerator::claimNext` on `store.insert({ ... } as @Sendable (In) throws(E) -> Out)`. Scope: apply fixes for 2 and 3; propose only for 1.

Landed in this order:

**Issue 2 (clean).** Read `Sources/Binary Primitives/exports.swift`, confirmed Package.swift already declared Cursor + LEB128 in the umbrella's target dependencies, added two `@_exported public import` lines. `rm -rf .build && swift test` went from 390 errors to 0; 328 tests pass. Committed on branch `modularize-binary` (`0ee9655`); the parent session later merged it into main via `5f895d6`.

**Issue 3 (iterated).** Reproduced the crash in the real package, built a minimal standalone reproducer at `/tmp/silgen-repro` (Store-shaped types + generic `insert<V: Sendable>`), then iterated through workaround shapes under the user's tightening constraints:

| Iteration | Form | User response |
|----|------|---------------|
| V1 | drop `@Sendable` from cast | fails — Sendable required |
| V2b | let-bind with explicit type annotation | works |
| V3 | let-bind with `as` cast | works | "interested in a better solution than V3" |
| Free function helper | file-scope `insert(&store, _:)` | works | dead end — adds new identifier |
| `insertThrowing` fileprivate overload | trailing-closure call site | works | "insertThrowing is NOT what we want … we DO NOT want to have throwing as identifiers. ever" |
| Type annotation on result | `let: ID<@Sendable ...> = store.insert { ... }` | still crashes — callsite shape unchanged |
| Overload + simple recursion body | `self.insert(fn)` | compiles, runtime stack overflow |
| Overload + `unsafeBitCast` disambiguation | erase to `any Sendable`, call base, bitcast result | works but `unsafe` |
| **Overload + nested-generic `dispatchToBase<V: Sendable>`** | opaque `V` prevents outer overload from matching → base wins | **works, no unsafe, no compound, no new names, clean trailing-closure at call sites** |

User then requested `/experiment-process` formalization before applying. Built `silgen-sendable-typed-throws-closure-cast/` at `swift-institute/Experiments/` with a standalone 90-line reproducer (no package imports — just `Store`-shaped inline types), full [EXP-003b] header with [EXP-007a] anchor, `_index.json` entry cross-referencing `silgen-thunk-noncopyable-sending-capture/` and `Research/silgen-bug-prone-primitive-compositions.md`. Verified the experiment reproduces the same `createInputFunctionArgument` / `claimNext` frames as production. Committed (`a4526ea`), then applied the overload fix to 3 test files (`Machine.Transform Tests.swift`, `Machine.Frame Tests.swift`, `Machine.Node Tests.swift`) with 8 call sites migrated to trailing-closure form. 105 tests pass. Committed on machine-primitives main (`dff4b80`).

**Issue 1 (initially proposed, later applied on user request).** Read five prior-research docs (`algebra-primitives-package-split.md`, `algebra-split-tier-analysis.md`, `algebra-aggregate-decomposition.md`, `algebra-adt-package-relationship.md`, `intra-package-modularization-patterns.md`), inventoried the 13 type files in the umbrella (Pair, Either, Product, Bool+XOR, Parity, Sign, Polarity, Ternary, Monotonicity, Bound, Boundary, Endpoint, Gradient — all import-free, no `@retroactive`), evaluated three options against [MOD-001]/[MOD-005]/[MOD-017]. Recommended Option 3 (move umbrella content back to Core). When the user said "lets address algebra," executed 13 `git mv` operations, verified `swift-algebra-primitives` tests (23 pass) and downstream `swift-dimension-primitives` still builds clean through the re-export chain. Committed (`9ccbbcf`).

**Audit parking per [AUDIT-017].** On user request, added an `## Implementation — 2026-04-21` section to `swift-machine-primitives/Audits/audit.md` with both SILGen workarounds as DEFERRED findings: finding #1 (this session's test-side overload, [IMPL-061]), finding #2 (pre-existing source-side `withRawThrowing` bypass at `Machine.Transform.Throwing.swift:35-38`, [IMPL-077]). Each carries experiment pointers, commit SHAs, and explicit revisit instructions for the 6.4-dev nightly sweep. Force-added `audit.md` (Audits/ is gitignored by ecosystem convention; `_index.json` stays local-only). Committed (`39d58c7`).

Produced: four commits across three repos plus one in `swift-institute/Experiments`; one new experiment package; one audit section; Findings block appended to the handoff.

Handoff file triage per [REFL-009]: `HANDOFF-mod-017-batch-followups.md` is in this session's cleanup authority (I wrote the Findings section and worked all three issues). No supervisor ground-rules block — the Constraints section was a plain "Do Not Touch" paths list. All three issues applied, Findings filled out, no pending escalation. Per [REFL-009]'s disposition rule: delete.

Out-of-scope handoffs at the workspace root (not written or worked by this session): `HANDOFF-kernel-event-consolidation.md`, `HANDOFF-ownership-primitives-sending-region-isolation.md`, `HANDOFF-effect-primitives-ncopyable-modernization.md`, `HANDOFF-shims-cross-package-test-visibility.md`, `HANDOFF-io-uring-full-opcode-coverage.md`, `HANDOFF.md`, plus 10 per-package handoffs. Left untouched per [REFL-009] bounded cleanup authority.

Audit finding cleanup per [REFL-010]: this session's audit additions are DEFERRED (parked by design). No findings were RESOLVED in-session to update. No cleanup needed.

## What Worked and What Didn't

### Worked

1. **Standalone reproducer at `/tmp` was the fast inner loop.** Iterating workaround shapes against the minimal 30-line `Store`-shaped reproducer built in `/tmp/silgen-repro` was ~2–3 seconds per variant vs ~30 seconds against the real package. The nine variants I tested would have been prohibitively slow against the full machine-primitives test build. The reproducer also became the committed experiment with almost no rewriting — inline struct types map directly to the canonical experiment shape.

2. **User's design constraints ratcheted toward the right answer.** Each rejection eliminated a class of workarounds rather than narrowing a parameter: V3 rejection → ruled out per-site boilerplate; `insertThrowing` rejection → ruled out compound identifiers; "throwing as identifier ever" clarification → ruled out single-word-keyword-adjective names too; "better than V3" implicitly required trailing-closure ergonomics. By the time I landed on nested-generic `dispatchToBase`, the search space had collapsed to one answer. Unconstrained I would have shipped the `unsafeBitCast` form and called it done.

3. **Experiment-first formalization before applying the fix.** User's `/experiment-process` request turned what would have been a scattered workaround into a durable corpus entry. The experiment carries the full stack trace, the filing-ready reproducer, and a [EXP-007a] anchor for mechanical revalidation sweeps. When the 6.4-dev nightly ships, the retirement path is one `swift build` against the experiment.

4. **Reading all five prior-research docs before proposing Issue 1.** The 2026-02-04 split plan explicitly lists "12 files — Into algebra-primitives (core, tier 0)" with the exact file names. Option 3 wasn't my invention — it was what the split plan said Core should contain. Had I proposed Options 1 or 2 without reading the prior research, the proposal would have contradicted the ecosystem-level decision. The research reads cost maybe 10 minutes; they prevented a wrong recommendation.

5. **Verifying downstream `swift-dimension-primitives` before committing Algebra.** The `@_exported import struct Algebra_Primitives.Pair` syntax in dimension's `exports.swift` was a plausible breakage surface — it module-qualifies a single type against what was historically Algebra_Primitives. A 30-second check (`rm -rf .build && swift build`) confirmed the re-export chain still resolves. Would have regretted skipping it.

### Didn't Work

1. **Proposed `insertThrowing` without pre-checking code-surface rules.** I had `/code-surface` loaded; [API-NAME-002] "no compound identifiers" was literally in my context. I still proposed `insertThrowing` — a textbook compound — without running the rule over the name. The user had to call it out. The existing rule would have caught it if consulted; the gap was in the consultation step. This mirrors the "post-commit memory scan" gap documented in [REFL-006] — the rule existed, the implementer did not consult it. Here it was worse: the rule was actively loaded in this session, and I still missed it.

2. **Attempted type-annotation-on-result as a "no-cast" alternative.** After the `insertThrowing` rejection I briefly tried `let captureID: ID<@Sendable ...> = store.insert { ... }` hoping the result annotation would propagate back to the closure. That's geometrically naive — the callsite shape (argument to a generic Sendable parameter) is unchanged by what the result is assigned to. The test crashed (correctly, identically), but I spent a reproducer round on it. Reasoning through the callsite shape first would have skipped this variant.

3. **Fileprivate overload with simple `self.insert(fn)` body — stack overflow not caught at compile time.** First fileprivate-overload attempt had a body of `self.insert(fn)` which recurses into itself (more-specific overload wins). The code compiled; the compiler does not detect runtime recursion. I had to instrument with a counter (which itself triggered Sendable concurrency diagnostics in Swift 6 mode) to confirm. Reasoning: at the call site `self.insert(fn)` where `fn: @Sendable (In) throws(E) -> Out`, the fileprivate overload's parameter type matches fn exactly (more specific than `<V: Sendable>`), so the fileprivate overload is selected — not the base. The whole stack-overflow/SIGBUS dance could have been skipped by thinking about overload resolution at the call site before testing. Runtime signal 10 on macOS for stack overflow is also confusingly non-obvious; signal 11 (SIGSEGV) is more typical, and signal 10 (SIGBUS) with zero test output read initially as "bitcast crash" not "recursion crash."

4. **cwd drift after an exploratory `cd`.** A mid-session `cd /Users/coen/Developer/swift-primitives/swift-kernel-primitives && git check-ignore …` (for ecosystem-precedent lookup) persisted the cwd, so a later `git add -f Audits/audit.md` ran in kernel-primitives, staging a pre-existing unrelated audit.md change. Caught it via `git diff --cached --stat` before committing. The Bash tool documentation says "shell state does not persist" but the working directory DOES persist across Bash calls — that's the specific hazard. The session had at least one other `cd` earlier without obvious trouble, so the failure mode here was "first time doing a destructive op after a cd for a read-only lookup." Absolute paths throughout is the structural fix.

## Patterns and Root Causes

### Pattern 1 — Loaded skills are not consulted skills

`[API-NAME-002]` was in my context the entire session. I still proposed a compound identifier. The skill's *existence* in context does not create the *consultation* at the moment of decision; the decision path (pick a name → validate against rules) has to be the right way around, not (pick a name → ship → hope reviewer catches it). This is a structurally distinct failure mode from "rule was absent" — it's "rule was present, decision bypassed it." The reflect-session skill added a post-commit memory scan for exactly this class of gap ([REFL-006] per 2026-04-20-file-name-nul-fix); the skill-vs-implementation axis is the analogue on the loaded-skill side, and it has no corresponding prophylactic. A pre-naming consultation step ("before proposing a method/property name, run it through [API-NAME-002]'s decision test") would make the consultation mechanical.

Corollary observation: the user's correction sharpened [API-NAME-002] beyond its written form. The existing rule forbids compound identifiers and notes exceptions for `isEmpty`-style booleans and spec-mirroring names. The user said "we DO NOT want to have throwing as identifiers. ever" — which is a *third* category: keyword-adjective-as-identifier, regardless of compound-ness. A hypothetical single-word `throwing(_:)` method would pass the compound test but fail the user's rule. The existing rule text allows it; the ecosystem's operative rule forbids it. The rule text is incomplete relative to the ecosystem's enforcement.

### Pattern 2 — Nested-generic dispatch as overload-escape

The nested-generic `dispatchToBase<V: Sendable>` pattern is a genuinely reusable technique: when you have a more-specific overload in scope and you need to dispatch through to the base from inside the overload's body, routing via a locally-defined generic function with an opaque parameter prevents the outer overload from matching. The key insight is type-level, not syntactic: at the inner call site `self.insert(v)` where `v: V` with `V: Sendable` unconstrained by concrete function type, Swift's overload resolution cannot match the outer `insert<In, Out, E>(_ fn: @Sendable (In) throws(E) -> Out)` — the base `<V: Sendable>(_ value: V)` is the only candidate.

This generalizes well beyond SILGen workarounds. Any time an extension declares an overload that semantically proxies to a base method (for type-narrowing, for diagnostics, for argument-shape transformation), and the body needs to dispatch through to the base from inside the more-specific overload, the same trick applies. Prior to this session I would have reached for a differently-named helper method or for `@_disfavoredOverload` (which goes the wrong direction). The pattern deserves documentation.

### Pattern 3 — Constraint ratcheting produces better workarounds than free iteration

The user's rejection sequence — V3 → `insertThrowing` → "throwing ever" → "better than V3" → `/experiment-process first` → `/audit to note so we can circle back` — looks structurally like supervision ([SUPER-*]) even though the session was not under an explicit handoff supervisor. Each rejection tightened the design space without prescribing the solution, which is the hardest form of feedback to give and the most productive to receive. My unsupervised trajectory would have been: V3 → ship, or `insertThrowing` → ship, or `unsafeBitCast` → ship — all worse than the final form on distinct axes.

The corresponding failure mode — implicit in my default path — is "satisfice early." When a workaround compiles and tests pass, the incentive to keep searching for a *cleaner* workaround is low. The ratcheting constraints inverted that incentive: each "works but ..." answer required going back to the search. This is a strong argument that for compiler-workaround code specifically (which lives in the codebase indefinitely until the compiler fix ships), the supervision cadence is worth the tax. The failure on unsupervised workaround-shipping is invisible at the moment of merging and accumulates into permanent cruft. The audit-parking mechanism ([AUDIT-017]) makes the cruft auditable, but only after the fact — the better intervention is quality ratcheting at introduction.

### Pattern 4 — Experiment corpus as retirement lever

Building `silgen-sendable-typed-throws-closure-cast/` before shipping the workaround moved the bug-retirement mechanism from "search the codebase for workaround comments + re-audit each one on a compiler update" to "re-run the experiment." This is [REFL-008]'s cleanup-session-context-now principle applied to deferrals: the session that discovered the bug is the cheapest evaluator of how to detect its fix. Every SILGen workaround in the ecosystem that doesn't have a paired experiment is rediscovery-deferred to a future session.

The audit finding I parked ([AUDIT-017] per user request) includes the experiment as the investigation pointer, which unifies the mechanisms: the audit.md DEFERRED finding says "revisit via experiment X"; the experiment's `_index.json` carries the toolchain version and reproducibility anchor; the combined system is mechanically revalidatable. No prose "re-test the SILGen crash on 6.4-dev" handwave required.

## Action Items

- [ ] **[skill]** code-surface: Sharpen [API-NAME-002] to forbid keyword-adjective-as-identifier regardless of compound-ness (e.g., `throwing`, `async`, `sending`, `borrowing` as method/property/label names). Current rule forbids compound identifiers with exceptions; user correction in this session ("we DO NOT want to have throwing as identifiers. ever") is a third category not captured in the written rule. Consider either extending [API-NAME-002] or adding [API-NAME-002c] Keyword-adjective identifiers. Cite the provenance of this reflection.
- [ ] **[skill]** implementation: Document the nested-generic-dispatch pattern (opaque generic parameter in a locally-defined generic function forcing overload resolution to pick the base method) in `/Users/coen/Developer/.claude/skills/implementation/patterns.md` or errors.md. Useful beyond SILGen workarounds — any time a more-specific overload needs to dispatch through to the base from inside its own body. Cite this session's use case and cross-reference [IMPL-092].
- [ ] **[research]** swift-institute: Extend `Research/silgen-bug-prone-primitive-compositions.md` (Tier 2, IN_PROGRESS) with the composition `@Sendable + typed throws(E) + inline as-cast + generic Sendable substitution` discovered this session; reference experiment `silgen-sendable-typed-throws-closure-cast`. The research doc explicitly tracks the catalog; this is catalog content.
