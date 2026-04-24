---
date: 2026-04-24
session_objective: Land `/code-surface` compliance, fix DocC symbol resolution, and restructure carrier-primitives docs per the four-layer audience model
packages:
  - swift-primitives/swift-carrier-primitives
  - swift-institute/Blog
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Carrier Primitives — `/code-surface` pass, DocC symbol fix, and four-layer documentation split

## What Happened

Single session resumed from `swift-carrier-primitives/HANDOFF.md` and ran three consecutive arcs before committing at `5cf7941`:

**Arc 1 — `/code-surface` compliance pass**. Replaced every compound identifier (`UserID`, `OrderID`, `FileHandleCarrier`, `SpanCarrier`, `InoutCarrier`, `SomeNoncopyableCarrier`) with `Nest.Name` forms (`User.ID`, `Order.ID`, `File.Handle` / `File.Descriptor`, `Buffer.View<Element>`, `Buffer.Scope<Base>`) across README, DocC landing, 4 DocC articles, 7 tutorial step files, `GettingStarted.tutorial`, `Tutorials.tutorial`, 3 test fixtures, and 5 Research documents. Converted every inline `struct Foo: Carrier { ... }` to standalone `extension Foo: Carrier { ... }` per `[API-IMPL-008]`. Reframed the phantom-domain narrative — the tutorial previously told readers to "declare an empty `User` enum whose sole purpose is to serve as a type-level tag"; this is wrong per the 2026-04-24 directive. The idiomatic shape reuses an existing domain type (`struct User { var name; var email }`) with a nested identifier wrapper (`User.ID`). Removed terminal-posture "0.1.0 is the final release" framing from public DocC per the internal-only directive. 17/17 tests pass on the rewritten fixtures.

**Arc 2 — DocC symbol resolution fix**. After landing the `/code-surface` pass, the DocC preview sidebar rendered only articles — no `Carrier` symbol under any group. Initial diagnosis: `Carrier.md` line 1's bare `# ``Carrier`` ` heading didn't resolve against the `Carrier_Primitives` module. First fix applied: qualify to `# ``Carrier_Primitives/Carrier`` ` per `[DOC-019a]`. Warnings persisted — `No symbol matched 'Carrier_Primitives/Carrier'`. Sent a structured report to another agent (who was simultaneously working the issue); the agent's response corrected the diagnosis: the pool-ambiguity from SLI's `@_exported public import` shadowed the umbrella's `Carrier` symbol. The canonical pipeline — `patch-umbrella-symbol-graph.py` with `--exclude-module Carrier_Primitives_Test_Support` and an isolated umbrella-only `--additional-symbol-graph-dir` — resolved the symbol. Verified via `curl /index/index.json` showing `Core Protocol → Carrier → init(_:) / underlying / Domain / Underlying`.

**Arc 3 — four-layer documentation split**. User review of the restructured docs: "the docc landing page has information that should be elsewhere." Loaded `readme` skill and re-read `documentation`. Diagnosed per `[DOC-027]`'s canonical-home rule: the landing page carried ~60% technical detail (Quadrant table, full protocol Shape block, 5-bullet "Package design decisions") that belonged in the per-symbol article; `Carrier.swift` inline docstrings carried 70+ lines of explanatory prose with Research/Experiments refs that `[DOC-010]` forbids inline; README carried a nine-dimension RawRepresentable philosophy block and a "Research Corpus" catalog that violated `[README-023]` evaluator's-lens and `[README-016]` prohibited-content rules. Absorbed landing's technical content into `Carrier.md` (now 181 lines), trimmed landing to metadata + one-paragraph overview + `@CallToAction` + Topics per `[DOC-021]` / `[DOC-080]` / `[DOC-084]` (42 lines), trimmed `Carrier.swift` inline to summary + short Example + `<doc:>` cross-ref (50 lines), slimmed README to Title/badge/one-liner + two motivated Quick Start examples + Installation + Architecture + Platform + Related Packages + License (135 lines). 17/17 tests still pass; DocC preview renders with zero Carrier-resolution warnings after symbol-graph rebuild.

Committed the whole session as `5cf7941` after explicit user authorization (31 files, +941 / -329). Wrote `Blog/HANDOFF-carrier-primitives-blogs.md` dispatching two future blog posts (pre-cursor + launching) to a downstream agent.

## What Worked and What Didn't

**Worked — skill substrate front-loading.** Loaded `swift-institute-core`, `code-surface`, `implementation`, `documentation`, `primitives`, `swift-package`, `memory-safety`, `swift-institute` at the opening (and `readme` at the layer-review moment). Every subsequent decision had a rule to cite: `[API-IMPL-008]` (minimal type body) grounded the fixture restructure, `[DOC-019a]` (per-symbol article headings) grounded the `Carrier.md` heading fix, `[DOC-027]` (content layering) grounded the four-layer split, `[README-023]` (evaluator's lens) grounded the README trim. The substrate paid for its cost multiple times — the layer-placement review that the user described vaguely ("information that should be elsewhere") resolved mechanically once the rules were in scope.

**Worked — parallel reads before any edits.** The Conformance-Recipes rewrite, the README rewrite, and the four-layer restructure each began with a batch of parallel reads (4–6 files) in one message. The four-layer picture was legible before any file changed; the rewrites were then executed atomically.

**Worked — empirical DocC verification via index.json.** After the patch-script + heading fix, confirmed the `Carrier` symbol was in the sidebar by parsing `/index/index.json`, not by trusting curl + screenshot. The index's `"title": "Carrier"` under `"title": "Core Protocol"` group marker was the load-bearing proof.

**Worked — authorization gating held.** Commit gated to explicit "commit" instruction; blog publish gated to a future session per `feedback_blog_publish_two_steps`. Auto mode executed implementation without per-step confirmation but these gates were respected.

**Didn't — first DocC diagnosis was incomplete.** Identified the heading issue but missed the pool-ambiguity root cause. Applied the heading fix; warnings persisted. The other agent's response cited the `patch-umbrella-symbol-graph.py` script from `swift-institute/Scripts/` (commit `e27dad1`) and the Category D/E pipeline discipline — I'd loaded `[DOC-019a]` and its "Cross-module ambiguity gotcha" paragraph, but that paragraph's prescriptions read as applying to `docc convert`. For `docc preview`, the same gotcha bites and the same patch-script fix applies, but this isn't explicit in the current skill text. Cost: one round-trip with the user as channel.

**Didn't — initial invocation of `swift package preview-documentation`.** Plugin isn't in `Package.swift` (no `swift-docc-plugin` dependency). Fell back to `xcrun docc preview` with manual symbol-graph emission. Minor friction, ~2 min.

**Didn't — fallback bundle identifier drift.** Used `org.swift-institute.Carrier_Primitives` locally; CI uses `swift-carrier-primitives.Carrier-Primitives`. No observed impact, but the inconsistency is a latent source of "works on my machine" confusion.

## Patterns and Root Causes

**Pipeline tools with multi-cause failure modes punish partial fixes.** The "no symbols in sidebar" symptom had three compounding causes: (1) bare heading not resolving; (2) SLI re-export pool-ambiguity shadowing the umbrella symbol; (3) test-support graph polluting the pool with spurious "replace with" suggestions. Fixing (1) alone produced a new warning (`No symbol matched 'Carrier_Primitives/Carrier'`) that looked like progress but wasn't. The canonical pipeline (patch-script + test-support exclusion + isolated `--additional-symbol-graph-dir`) addresses all three. The pattern generalizes: when a tool's failure mode compounds multiple causes and only one is visible per error-line, single-cause diagnosis is structurally insufficient — the fix must be pipeline-shaped, not claim-shaped. `[DOC-019a]` captures this but frames it around `docc convert`; the preview story deserves the same treatment explicitly.

**Canonical-home violations read as "feels off" until a rule surfaces.** The user's landing-page diagnosis — *"information that should be elsewhere"* — is vague until you name the rule it violates. With `[DOC-027]`'s canonical-home table in scope, the vagueness resolves: per-symbol rationale has a canonical home (the per-symbol article), pattern guides have theirs (topical article), call-site contract has its own (inline `///`). The user's intuition was correct but under-specified; the skill provided the specification. This is the strongest argument for skill-substrate front-loading: vague user signals become actionable once the rules are loaded.

**Inter-agent cross-talk via the user as channel worked.** The DocC diagnosis round-trip — my partial report → user relay → other agent's structured correction → user relay back → my revised action — compressed what would have been an iterative self-diagnosis cycle into one exchange. Each agent contributed structured analysis in its own context, the user acted as router, and neither agent needed to hold the other's full context. This is already implicit in `/handoff` + `/supervise` patterns but the "parallel-worker coordination via user as switchboard" shape isn't explicitly captured.

**Re-verify-after-edit caught the straggler.** Per `[REFL-006]`'s re-verify rule, the final grep pass for compound identifiers found `sli-void.md`'s hypothetical `Unit: Carrier` inline conformance — a ref that wasn't in the original handoff's scope list. Without the re-grep, it would have shipped. The discipline holds even when the edits feel "obviously complete."

## Action Items

- [ ] **[skill]** documentation: `[DOC-019a]`'s "Cross-module ambiguity gotcha" paragraph is prescriptive for `docc convert` but the same failure mode bites `docc preview` and the same patch-script fix applies. Add a paragraph (or extend the existing one) explicitly covering local preview of multi-target umbrella catalogs, citing the patch-script's `--exclude-module` flag and the `--additional-symbol-graph-dir` isolation requirement. The preview-story gap cost one diagnostic round-trip this session; it will recur.
- [ ] **[package]** swift-carrier-primitives: maintainers running DocC preview locally need the patch-script + test-support exclusion + isolated graph-dir incantation. Add `Scripts/preview-docs.sh` that wraps the full invocation (build → patch → preview) so future sessions don't rediscover the dance. Alternatively, document the invocation in a contributing section of the README. Optional but cheap.
- [ ] **[research]** Document the four-layer documentation split as a case study in `swift-institute/Research/` — which content moved from landing to per-symbol article, which from inline to per-symbol, which from README to topical article, with before/after line counts and the rules cited (`[DOC-010]`, `[DOC-021]`, `[DOC-027]`, `[README-023]`). Carrier Primitives is a clean reference example for packages landing into the four-layer discipline for the first time.
