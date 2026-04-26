---
date: 2026-04-24
session_objective: Finish Phase 2b-2 (reallocate) and fix post-hoc an [API-NAME-002] compliance miss surfaced by the user on the landed swapAt(_:_:) API.
packages:
  - swift-array-primitives
  - swift-buffer-primitives
status: processed
processed_date: 2026-04-26
triage_outcomes:
  - type: skill_update
    target: code-surface
    description: "[API-NAME-007] Convention-Known-Convention-Unapplied Heuristic — internal-capital + stdlib-pedigree triggers re-verification against [API-NAME-002] before commit"
  - type: skill_update
    target: code-surface
    description: "[API-NAME-008] Property.View vs Labeled Method Decision Rule — multi-form (2+ sub-ops) uses Property.View; single-form uses labeled methods; layer-consistency soft tie-breaker"
  - type: research_topic
    target: stdlib-naming-beats-ecosystem-naming.md
    description: "IN_PROGRESS Tier 2 — surveys when stdlib naming beats ecosystem naming and when it does not; case-study sweep across shadowed types pending"
---

# Post-hoc [API-NAME-002] compliance: swapAt → swap(at:with:)

## What Happened

Incremental continuation of the earlier `se-0527-outputspan-adoption-wave` session. Three coherent mini-cycles after that reflection was captured:

**1. reallocate(capacity:) landed** (Phase 2b-2).
- `swift-buffer-primitives@2b9d053` — `Buffer.Linear.reallocate(capacity:)` by delegating to the existing `_growTo` primitive with the grow-only guard lifted and a `capacity >= count` precondition. Both ~Copyable and CoW-aware Copyable paths.
- `swift-array-primitives@b98f721` — Array-level delegation.
- `swift-array-primitives@fcf50c6` — Research doc bump to v1.5.0.
- 6 + 4 new tests; full suites green (431 and 136).
- This item was selected via the "framework for reasoning about deferred items" I produced at the user's request earlier in the same day: decision-blocked, low stakes, low reversibility-cost → ship with plausible default.

**2. The user pointed out `Array.swapAt(_:_:)` violates [API-NAME-002]**.
- `swapAt` is a compound identifier (camelCased "swap" + "At"). I shipped it in `swift-array-primitives@f0cf7f2` earlier the same day. User asked: "how would you do that API to match the requirements? just show first, no change yet."
- I surveyed two alternatives and recommended Option A (direct labeled method `swap(at:with:)`) over Option B (Property.View nested accessor `swap.at(i, with: j)`). The Option B wrapping would add types/files per variant for zero callsite-expressivity gain; `swap` has one form, not a family.
- Option A also exactly matches `Buffer.Linear.swap(at:with:)` one layer down — consistency through the stack was the deciding factor.

**3. Rename executed**.
- `swift-array-primitives@c9c1083` — `git mv` both the source file and the test file (preserving history: 74% and 80% similarity), then updated content. Four variant extensions + five test cases migrated in one commit.
- `swift-array-primitives@dfb02a1` — Research doc bump to v1.6.0.
- 136 tests / 46 suites still green.

**Artifact cleanup**: no new HANDOFF files at any working directory root. `swift-buffer-primitives/HANDOFF-deinit-devirtualizer-crash.md` still present, still unrelated to this session. No `/audit` invocation occurred.

## What Worked and What Didn't

**Worked**:

- **Option A/B decision framework**. When the user asked "how would you do it," I produced two concrete code sketches, compared them against the ecosystem's existing patterns (Buffer.Linear labeled-method, Property.View multi-form nested accessors), and recommended the one that generalized. The pattern "enumerate, compare, recommend" is the same shape as the deferred-items framework from earlier in the day.
- **git mv for renames**. The rename preserved git history (74%/80% similarity metrics captured by git). Future `git log --follow` on the new path will surface the history.
- **Research doc changelog discipline**. Each corrective action (Option A, reallocate, swap rename) landed as its own changelog bump (v1.5.0 → v1.6.0 → v1.6.0 entry), keeping the research doc as an auditable trail of what actually shipped vs. what was originally written.

**Didn't work**:

- **I shipped `swapAt(_:_:)` despite knowing [API-NAME-002]**. The rule is in CLAUDE.md (pinned) AND in my auto-memory AND is one of the most frequently referenced conventions in this ecosystem. I wrote `swapAt`, committed it as `Add Array.swapAt(_:_:) across dynamic, Fixed, Small, Static variants`, and shipped it. The camelCase identifier IS the violation; the commit message announcing it IS a smell; the test filename `Array+swapAt Tests.swift` IS a smell. None of those triggered a check. The user caught it post-ship, asked me to self-correct, and I did.
- **Stdlib-alignment gravity**. The reason I wrote `swapAt` is that SE-0527 uses `swapAt(_:_:)` and `Swift.Array.swapAt(_:_:)` is the existing stdlib idiom. I was porting the stdlib API name directly. Under the gravitational pull of "match stdlib," the ecosystem's compound-identifier ban did not fire. The very reason Array shadows Swift.Array is that the ecosystem has its own naming rules — stdlib mimicry is a trap for exactly this class of violation.

## Patterns and Root Causes

### Pattern — "Convention-known, convention-unapplied" is a distinct failure mode

This isn't the same as forgetting a rule or never having learned it. I had [API-NAME-002] pinned in multiple durable locations (CLAUDE.md, memory entries, research docs) and invoke it regularly in API-design discussions. The failure was local: at the moment of naming a specific method, the check did not run. Neither did the check at commit time, despite the method name landing verbatim in the commit subject line.

This is the gap between declarative knowledge ("I know the rule") and procedural application ("the check actually fires at the decision point"). Declarative knowledge accumulates from reading skills and CLAUDE.md; procedural application requires explicit triggers at code-writing time. The triggers that could have fired:

- **Write-time**: proposed name contains an internal capital letter → `swapAt`, `walkFiles`, `openWrite` → flag for [API-NAME-002] check
- **Commit-time**: commit subject contains a proposed-new-method name with internal capital letters → same
- **Name-pedigree**: proposed name was copied/adapted from stdlib or SE proposal → external APIs routinely use compound identifiers that the ecosystem forbids → explicitly re-check

None fired because none are written down as explicit heuristics; they live in ambient judgment, which is what fails under external-API gravitational pull.

### Pattern — Single-form vs. multi-form decides Property.View wrapping

`remove.{first, last, all}`, `peek.{front, back}`, `forEach.{borrowing, consuming, index}` are all Property.View accessors because they namespace *multiple related sub-operations*. `swap(at:with:)` has one form. Wrapping a single method in a Property.View adds per-variant types + typealias + property getter for zero callsite-expressivity gain.

The operating rule that emerged from the Option A/B analysis:
- **Multi-form** (two or more sub-operations naturally under one root) → Property.View nested accessor
- **Single-form** (one operation, disambiguated by argument labels) → direct labeled method

This isn't a new rule; it's the existing practice of the ecosystem (Buffer.Linear.swap direct, remove Property.View for multi-form). But it's not explicit in [API-NAME-002] — that skill bans compound identifiers but is silent on when nested-accessor ceremony is warranted vs. when labeled methods suffice. The silence lets the wrong choice seem equally valid.

### Pattern — Layer-consistent naming as a soft tie-breaker

When two [API-NAME-002]-compliant names are both defensible, matching the name one layer down (here: `Buffer.Linear.swap(at:with:)`) is itself a correctness signal. Different names at different layers create friction at every delegation; matching names makes the delegation invisible. This is weaker than the compound-identifier ban (which is MUST), but worth naming as a SHOULD in the same skill.

## Action Items

- [ ] **[skill]** code-surface: Add an explicit heuristic to [API-NAME-002] for the "convention-known, convention-unapplied" failure: when a proposed method/property name (a) contains an internal capital letter OR (b) is copied/adapted from stdlib, SE proposal, or another language, it MUST be re-verified against the compound-identifier rule before commit. Precipitating case: `Array.swapAt(_:_:)` shipped in `swift-array-primitives@f0cf7f2`, caught post-ship by the user, renamed in `@c9c1083`.
- [ ] **[skill]** code-surface: Document the Property.View-vs-labeled-method decision rule explicitly. Currently [API-NAME-002] bans compounds and shows multi-form nested-accessor examples (`instance.open.write { }`), but doesn't articulate when nested accessors are ceremony vs. substance. Rule: multi-form operations (2+ related sub-operations) use Property.View; single-form operations use labeled methods. Precipitating case: Option A vs. Option B analysis on swap.
- [ ] **[research]** When stdlib naming beats ecosystem naming (and when it doesn't). `Array` shadows `Swift.Array`; we deliberately choose ecosystem conventions for the shadow. But there are cases where callers migrating from stdlib benefit from name continuity. What's the principle? Tier 2 research topic covering: signal vs. noise in shadowed-type renames, discoverability for migrating callers, cost of subtle differences. Target: a `Research/` document in `swift-institute/Research/` that informs every future stdlib-analog API decision.
