---
date: 2026-03-31
session_objective: Strict /audit of swift-async-primitives against /code-surface, then implement all findings
packages:
  - swift-async-primitives
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: code-surface
    description: Refined [API-IMPL-005] exception — most ~Copyable types extract cleanly with fully-qualified names; only deep-cross-reference State types are genuine exceptions
  - type: package_insight
    target: swift-async-primitives
    description: Timer.Wheel.Storage.Free slab free list — investigate Buffer.Slab fit
  - type: no_action
    description: Agent failure recovery guidance — agent workflow, not code pattern; implementation skill governs code style
---

# Code-Surface Audit and Full Remediation of swift-async-primitives

## What Happened

Ran a strict code-surface audit of swift-async-primitives (62 source files, 12 modules) checking the full requirement set — prior audit only checked 5 rules. Found 33 findings (3 HIGH, 16 MEDIUM, 14 LOW). Then implemented all fixes across 10 commits:

1. **[API-IMPL-008]** — Extracted methods from type bodies to extensions in 20 files. Hit a Swift name-lookup limitation: `extension Parent.Child` can't resolve sibling types from `extension Parent where Element: ~Copyable`. Fixed with fully-qualified names (user explicitly preferred this over typealiases).

2. **[API-IMPL-005]** — Extracted 23+ types to dedicated files. Channel ~Copyable types extracted successfully using [PATTERN-022]. Channel State files remain multi-type (justified per [MEM-COPY-006]).

3. **[API-NAME-002]** — Refactored compound identifiers across 10+ files. Lifecycle.State got a `~Copyable ~Escapable` pointer-based view for `shutdown.begin()`/`shutdown.complete()`. Timer.Config got 4 namespace accessor structs. Duration got a `Divided` namespace.

4. **[API-IMPL-003]** — Unbounded.State `_closed: Bool` → `Status` enum mirroring Bounded. Broadcast `Is.finished: Bool` → enum `{ active, finished }`.

5. **[API-NAME-001]** — Mutex `_AsyncMutexValue`/`_AsyncMutexLock` nested as `._Value`/`._Lock`.

## What Worked and What Didn't

**Worked well**: Parallelizing agents by module for Phase 1 (body→extension) was effective — 4 agents completed 20 files in one round. The audit-then-fix workflow gave clear, numbered targets.

**Didn't work well**: Agent failures accumulated. Three agents were rejected by the user (timing), one hit an API error (500), one ran out of usage mid-file (left partial changes: types deleted but not re-created, Bool renamed but not all references updated). Each failure required manual investigation and cleanup. The partially-applied changes were the most dangerous — they left the build broken in non-obvious ways.

**Confidence was low on**: Whether Channel ~Copyable types could be extracted. I initially deferred them as "justified exceptions" but the user pushed back. They extracted cleanly using [PATTERN-022] — I was wrong to assume they couldn't.

## Patterns and Root Causes

**Sibling-type resolution is a recurring obstacle**: This is the third time (after the initial Phase 1 Storage fix and the Broadcast.Subscription fix) that `extension Parent.Child` failed to find sibling types. The root cause is Swift's name lookup for nested type extensions — it doesn't traverse conditional extensions of the parent. Fully-qualified names with the generic parameter (`Async.Channel<Element>.Bounded.State`) are the consistent fix. This is now documented in memory.

**Partial agent failures are the highest-risk failure mode**: An agent that completes 80% of a multi-file refactoring leaves the codebase in a broken state that's harder to diagnose than a complete failure. The `swift build` output shows errors in files the agent DIDN'T touch (cascading from incomplete changes). Mitigation: build after every agent round, not at the end of a phase.

**"Justified exception" is an easy escape hatch that deserves skepticism**: I classified 6 Channel files as justified exceptions per [MEM-COPY-006]. The user challenged this, and 5 of 6 extracted cleanly. The State files genuinely can't be extracted (deep cross-references), but the others were simpler than I assumed. The lesson: try the extraction first, defer only after compiler confirmation.

## Action Items

- [ ] **[skill]** implementation: Add guidance on agent failure recovery — build after every agent round, never batch multiple rounds without verification. Partial failures are worse than complete failures.
- [ ] **[skill]** code-surface: Add note to [API-IMPL-005] that ~Copyable channel types (Take, Ends, Receive, Send, Elements, Iterator) CAN be extracted per [PATTERN-022] with fully-qualified sibling names — only State files are genuine exceptions.
- [ ] **[package]** swift-async-primitives: Timer.Wheel.Storage.Free hand-rolls a slab free list — investigate whether Buffer.Slab from swift-slab-primitives is a better fit (handoff written: HANDOFF-storage-free-data-structure.md).
