---
date: 2026-04-01
session_objective: Re-audit swift-io against /code-surface after 5-phase remediation, fix test compilation
packages:
  - swift-io
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: skill_update
    target: code-surface
    description: "Add [API-NAME-002] exclusions subsection — is/has boolean predicates, Swift protocol requirements (rawValue), and single-concept phrasal verbs are not compound identifiers"
  - type: skill_update
    target: memory-safety
    description: "Add guidance for non-frozen imported ~Copyable types — field extraction fails, copy on property access fails, only whole-value consume or borrowing works"
  - type: research_topic
    target: swift-io test hang pattern
    description: "Three separate handoffs about test/benchmark hanging suggest systemic actor/thread teardown issue — consolidate into one investigation"
---

# swift-io Code Surface Re-Audit — Agent Accuracy and ~Copyable Test Patterns

## What Happened

Re-audited 273 swift-io source files across 7 modules against /code-surface in strict mode ([IMPL-024] disabled). Spawned 7 parallel Explore agents (one per module) for initial scan, then 4 verification agents to confirm prior finding resolutions. Targeted reads to filter false positives. Replaced Code Surface section in `Research/audit.md`: 40→14 findings, all 12 HIGH resolved, zero public API compound identifiers remain.

Fixed 6 test compilation issues from API changes (Capabilities init, Deadline removal, `[Kernel.Event]` parser ambiguity) and ~Copyable cascade (`IO.Completion.Event` non-Copyable, `Kernel.Pipe.Descriptors` partial consumption). Tests compile but hang at runtime — handed off to `/issue-investigation` via `HANDOFF-swift-test-hang.md`.

## What Worked and What Didn't

**Worked**: Parallel agent scan covered 273 files in one round. Verification agents efficiently confirmed 34/40 prior findings resolved. The audit skill + code-surface skill combination gave clear process.

**Didn't work**: Initial agents had high false-positive rates for [API-NAME-002]. Three agents flagged standard Swift boolean predicates (`isInitialized`, `isFulfilled`, `rawValue`) as compound identifiers. One agent (IO Events) said "CLEAN" when the module genuinely was clean post-remediation — but another agent (IO Blocking) produced 14 "findings" where 10 were false positives. Required manual verification pass on every agent's output.

**Didn't work**: ~Copyable test fixes required three attempts for pipe partial consumption. First tried field extraction (`let readFD = pipe.read`), then `copy` keyword, finally `_ = consume pipe`. Each attempt revealed a new constraint about non-frozen imported ~Copyable types.

## Patterns and Root Causes

**Agent compound-identifier false positives stem from missing boundary definition.** The code-surface skill defines [API-NAME-002] with examples like `openWrite`→`open.write`, but doesn't explicitly exclude standard Swift naming patterns. The `is`/`has` boolean prefix, `rawValue` protocol requirements, and phrasal verbs like `isShuttingDown` are NOT compound identifiers — they're grammatical markers or single concepts. Without this boundary, agents over-apply the rule. The skill should add an exclusions subsection.

**Non-frozen ~Copyable partial consumption is a distinct pattern from ~Copyable in general.** The compiler can track per-field consumption within the declaring module but NOT for non-frozen imported types. This means: (1) `copy` doesn't work on property access expressions, (2) field extraction fails, (3) the only options are borrowing (pass to a function) or consuming the whole value (`_ = consume pipe`). This is distinct from the intra-module ~Copyable patterns documented in memory-safety skill.

**Test hangs after compilation success are a recurring swift-io pattern.** This is at least the third handoff about test/benchmark hanging (`HANDOFF-test-hang.md` superseded, `HANDOFF-post-test-hang.md`, now `HANDOFF-swift-test-hang.md`). The root cause likely involves actor/thread infrastructure that starts during test setup and never shuts down, blocking the test runner. This pattern should be investigated holistically rather than per-symptom.

## Action Items

- [ ] **[skill]** code-surface: Add [API-NAME-002] exclusions subsection — standard `is`/`has` boolean predicates, Swift protocol requirements (`rawValue`, `hashValue`), and single-concept phrasal verbs are not compound identifiers
- [ ] **[skill]** memory-safety: Add guidance for non-frozen imported ~Copyable types — field extraction fails, `copy` on property access fails, only whole-value `consume` or borrowing works
- [ ] **[research]** swift-io test hang pattern: three separate handoffs about test/benchmark hanging suggest a systemic issue with actor/thread teardown in test infrastructure — consolidate into one investigation
