---
date: 2026-04-03
session_objective: Run strict /implementation audits on swift-io's three mechanisms (Events, Blocking, Completions) and fix quick wins
packages:
  - swift-io
status: pending
---

# swift-io Implementation Audit — Three Mechanisms + Quick Wins

## What Happened

Ran parallel `/audit regarding /implementation` on swift-io's three I/O mechanisms: Events (66 files), Blocking (95 files), Completions (58 files). Three agents audited simultaneously, producing 82 total findings (2 critical, 26 high, 36 medium, 12 low). Findings written to `swift-io/Research/audit.md` as three new sections replacing the prior single Implementation section.

Key findings by mechanism:
- **Events**: 2 CRITICAL per-poll Array allocations in kqueue path (triple-handling), per-event Array literal in dispatch loop, 10+ `__unchecked` + raw Int32 kevent constructions
- **Blocking**: Abandoning module's per-job thread spawn + 3 heap allocs, 6x `Int(typedCount)` at loop boundaries (needs primitives range iteration), 20+ bare `Int` in public Metrics/Options
- **Completions**: 12 `.rawValue`/`Kernel.Descriptor(rawValue:)` in platform backends, excellent ~Copyable Entry/Submission design (zero-allocation completion-to-resume path)

Quick wins implemented:
1. Poll.Loop.swift: `for interest in [.read, .write, .priority]` Array literal → 3 direct `if` checks (hot-path heap alloc eliminated)
2. Registration.Queue.swift: `nonisolated(unsafe)` workaround → `deque.push(element, to: .back)` (unsafe eliminated entirely)
3. Four stale/inaccurate doc comments fixed in Completions
4. Queue.ID.next() `defer` cleanup
5. WORKAROUND annotations added per [PATTERN-016]

Also added **[PLAT-ARCH-005a]** to the `/platform` skill: "No platform C types in public API." Generalizes [PLAT-ARCH-005] (descriptors) to all C types.

Branching handoff created for `sending` + Mutex composition investigation. Agent completed the research: Property.View `_modify` coroutine is opaque to the region isolation checker (compiler limitation, not bug). Site 1 fix: bypass coroutine with `deque.push(element, to: .back)`. Site 2 (kqueue poll Array copy): fundamental region constraint, accepted.

## What Worked and What Didn't

**Worked well**: Three parallel audit agents produced comprehensive, accurate findings in ~4 minutes. Cross-referencing with the prior AUDIT-intent.md (2026-02-24) showed clear progress — 13 of 70 findings resolved. The agent accuracy was high because the implementation skill has precise, verifiable requirement IDs.

**Worked well**: The `sending` investigation produced a genuinely useful root-cause analysis. The fix for Site 1 (`deque.push(element, to: .back)`) was hiding in plain sight — the `~Copyable` overload 40 lines below already used it. The research correctly identified coroutine accessor opacity as the root cause and SE-0414/SE-0430 as the governing specifications.

**Didn't work**: Build verification was slow and got interrupted multiple times. The user ended up building themselves and confirming it was clean. Build/test should be deferred to the user when tooling gets stuck.

**Pattern observed**: The audit found many findings that require primitives-layer infrastructure changes (range iteration on typed counts, `Dictionary.removeAll(where:)`, boundary overloads). These are the highest-leverage fixes but cross repo boundaries.

## Patterns and Root Causes

**The `sending` composition gap is architectural, not incidental.** Property.View's `_modify` coroutine pattern is foundational to the ecosystem's verb-as-property API design ([IMPL-020]). The fact that it doesn't compose with `Mutex.withLock`'s `(inout sending State)` means every Mutex-protected mutation of a type using Property.View accessors will hit this wall. The workaround (use direct methods instead of accessor chains) works but undermines the accessor pattern's purpose. This is worth tracking as a compiler evolution item.

**Infrastructure gaps cluster at type boundaries.** The bare `Int` findings (20+ in Blocking, 2 in Events, 2 in Completions) and the `Int(typedCount)` conversions (6 sites) all stem from the same root: typed count/index types in primitives lack the convenience operations (range iteration, comparison with Int) needed at boundaries. One infrastructure addition (`Kernel.Thread.Count` conforming to some range-iterable protocol) eliminates 6 conversion sites. The leverage ratio of primitives work is high.

**Platform backends accumulate the most debt.** The io_uring and IOCP code in Completions has 12 `.rawValue`/`init(rawValue:)` sites, all behind `#if os(Linux/Windows)`. These are never compiled on Darwin CI, so they accumulate unchecked. The new [PLAT-ARCH-005a] rule codifies what was already implied but never enforced.

## Action Items

- [ ] **[skill]** existing-infrastructure: Add `Dictionary.removeAll(where:)` to the ecosystem data structures catalog once implemented — it's a gap referenced by 2 audit findings
- [ ] **[package]** swift-darwin-primitives: Add `Kqueue.register(_:event:)` singular overload per [PLAT-ARCH-005a] — eliminates 4 per-operation Array allocations in swift-io and removes `UnsafeBufferPointer<kevent>` from public API
- [ ] **[research]** Can `Kernel.Thread.Count` / `Lane.Count` support range iteration without violating cardinal/ordinal type semantics? 6 `Int(...)` conversion sites depend on the answer
