---
date: 2026-04-15
session_objective: Apply Swift 6.3 @unsafe attribute to every @unchecked Sendable conformance across swift-primitives, swift-standards, and swift-foundations
packages:
  - swift-primitives
  - swift-foundations
  - swift-institute
status: processed
processed_date: 2026-04-16
triage_outcomes:
  - type: skill_update
    target: memory-safety
    description: "Modified [MEM-SAFE-024] — added Category D (structural workaround) with three subpatterns (SP-2 @_rawLayout, SP-4 non-Sendable generic, SP-5 pointer-backed Copyable)"
  - type: no_action
    description: "[package] swift-executors submodule conversion — execution verification task, commit da39012 is the record"
  - type: research_topic
    target: acceptance-gate-grep-design.md
    description: "Acceptance-gate grep design suitable for CI integration"
---

# Ecosystem @unsafe Audit — Full Lifecycle in One Session

## What Happened

Executed the complete HANDOFF-ecosystem-unsafe-audit.md from Phase 0 through Phase 2 acceptance gate in a single session. The audit classified and annotated every `@unchecked Sendable` conformance declaration in Sources/ across three superrepos (218 sites total; swift-standards was clean at 0).

**Phase 0** (investigation): Determined `@unsafe @unchecked Sendable` is semantic lint in Swift 6.3, not a compile requirement — 218 existing sites compiled without it under `.strictMemorySafety()`. Zero ecosystem precedent for the annotation form existed; this audit was the first application.

**Pilot**: Applied `@unsafe` + three-section docstring to `Kernel.Thread.Synchronization` in swift-threads. Verified: compiles, no strict-memory warnings, DocC syntax valid, 35/35 tests pass. Committed as `da86a35`.

**Phase 1** (classification): Dispatched 7 parallel agents across 5 subdomain partitions + 2 gap-fill agents. 218 hits classified into 35 Cat A (synchronized), 148 Cat B (ownership transfer), 1 Cat C (thread-confined), 35 Cat D (structural workaround). Spot-check: 17/21 correct, 1 incorrect, 3 ambiguous (4.8% misclassification, below 5% threshold). D adjudication collapsed 70 candidates into 8 subpattern decisions. Scope reconciliation caught that the initial count (232) was inflated by Experiments/Sources/ path contamination — true count was 216, agents covered 218 (minor overcount).

**Phase 2** (application): 2 agents (one per superrepo) edited 215 files across 53 commits on `unsafe-audit` branches. Acceptance gate: zero uncovered conformance declarations. Builds pass; tests pass.

**Structural fix**: Discovered swift-executors was tracked as individual files in the swift-foundations parent rather than as a submodule. Converted to proper submodule (`da39012`).

## What Worked and What Didn't

**Worked well**:
- **Pilot-first sequencing** was critical. The pilot proved the annotation syntax and established the canonical form before 218 files were at stake. Ground rule #10 made this mandatory — good call.
- **Four-category framework** (A/B/C/D) held up under scrutiny. The D adjudication collapsed 70 candidates to 8 clean subpattern decisions. The governing principle ("~Copyable + owns resources = B regardless of inference gaps") resolved the ambiguous middle ground decisively.
- **Scope reconciliation** caught a real gap (12 missing packages) that would have left 86 sites unannotated. The Phase 0 grep overcounted by ~33 hits due to Experiments/Sources/ path contamination — a subtle bug in glob patterns that would have gone undetected without per-package verification.
- **Agent classification quality**: 4.8% misclassification across 21 spot-checked samples. The one incorrect (Witness.Values._Storage: CoW conflated with synchronization) was isolated, not systemic.

**Didn't work well**:
- **Usage limits hit 5 of 9 agent dispatches**. Agents 1/2/3 and 6/7 all received "out of extra usage" messages. In all cases, files were written before the limit hit (work persisted), but the pattern suggests the parallel-5-agent dispatch model exceeds practical token budget. Smaller batches or sequential dispatch would be more reliable.
- **Acceptance gate grep was too naive** initially. The first gate matched docstring comments, `.build/checkouts/`, and `.claude/worktrees/`. Required a second pass with proper exclusions. The gate should have been designed with these exclusions from the start.
- **swift-executors submodule detection** was missed until the final commit step. The parent was tracking 33 individual files instead of a submodule pointer. This predated the audit but wasn't caught until `git status` revealed file-level changes where submodule-level was expected.

## Patterns and Root Causes

**Pattern 1: Category D is a genuine fourth category, not noise.** 35/218 = 16% of the ecosystem's `@unchecked Sendable` sites are structural workarounds with no caller invariant. Three distinct subpatterns: (a) `@_rawLayout` bridges, (b) non-Sendable generic parameters (AsyncIteratorProtocol, closures), (c) phantom type / value-generic inference gaps on otherwise-pure-value types. This exceeds the "handle inline" accommodation of ground rule #9 and warrants a formal `/skill-lifecycle` proposal to extend [MEM-SAFE-024] with Category D.

**Pattern 2: Parallel agent dispatch quality scales with subdomain coherence, not agent count.** Agent 2 (storage/queue/stack — homogeneous Cat B) had 100% accuracy on spot-checked samples. Agent 5 (grab-bag scatter — 57 hits across 28 packages) required a tightened 95% confidence threshold and still produced 6 LOW_CONFIDENCE flags. The correlation is clear: agents perform better when their subdomain has a consistent character. Future dispatches should optimize for subdomain coherence, not breadth-per-agent.

**Pattern 3: The B-vs-D boundary is one decision, not 40.** Agent 2 flagged 11 D-candidates. Agent 6 flagged 16. Most were the same `<let N: Int>` subpattern repeated across type families. The governing principle ("ownership transfer is the primary invariant; value-generic is incidental") resolved all ~31 instances at once. This confirms the user's prediction that "the 43 candidates will collapse to fewer distinct decisions."

## Action Items

- [ ] **[skill]** memory-safety: Propose Category D extension to [MEM-SAFE-024] via /skill-lifecycle. Evidence: 35 sites (16%), 8 subpatterns documented in unsafe-audit-findings.md "Category D Adjudication" section. Three distinct subpatterns (SP-2 @_rawLayout, SP-4 non-Sendable generic, SP-5 pointer-backed Copyable) form the core; SP-1/SP-8 are excluded (reclassified to B by governing principle).

- [ ] **[package]** swift-foundations: swift-executors was tracked as individual files, not a submodule. Converted in this session (`da39012`). Verify the conversion doesn't break CI or downstream consumers that may have assumed direct file tracking. Check if other packages have the same problem (scan for directories with `.git` but no `.gitmodules` entry).

- [ ] **[research]** Investigate acceptance-gate grep design: the naive `rg "@unchecked Sendable" | rg -v "@unsafe|WHY:"` matched docstrings, build checkouts, and worktrees. Design a canonical gate script that handles these exclusions, suitable for CI integration. Could live in `swift-institute/Scripts/`.
