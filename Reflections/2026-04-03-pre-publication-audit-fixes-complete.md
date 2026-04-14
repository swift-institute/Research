---
date: 2026-04-03
session_objective: Fix pre-publication code quality findings across 7 priority packages and audit the full swift-file-system dependency tree (59 packages)
packages:
  - swift-iso-32000
  - swift-iso-8601
  - swift-rfc-9110
  - swift-rfc-4648
  - swift-iso-3166
  - swift-base62-primitives
  - swift-incits-4-1986
  - swift-ascii
  - swift-iso-9899
  - swift-iso-9945
  - swift-queue-primitives
  - swift-paths
  - swift-memory
  - swift-environment
  - swift-handle-primitives
  - swift-binary-primitives
  - swift-test-primitives
status: processed
---

# Pre-Publication Audit Fixes — 18 Packages Across 3 Layers

## What Happened

Started from a handoff document with 277 findings across 7 priority packages. Executed P0 through P3 fixes: Foundation import removal, `__` error type nesting, 4 compound type renames in rfc-9110, one-type-per-file splits (62 new files across 5 packages), method extraction from type bodies, compound method→nested accessor conversions, and doc comment additions. All 1,013 tests green across the original 7 packages.

Then expanded scope to the full swift-file-system dependency tree (59 packages). Ran three parallel audit agents across primitives (39), foundations (17), and standards P2 (3). Found zero Foundation imports (P0 clean), limited compound names (INCITS, handle, binary, test, memory), a few multi-type files (queue errors, path errors, standards siblings), and one untyped-throws violation (environment). Fixed all actionable findings in 11 additional packages.

The iso-32000 file splits (28 files, 250+ types) were deferred by user decision — spec-section file organization is an acceptable deviation for literal spec encodings.

## What Worked and What Didn't

**Worked well**: Parallel agent deployment for mechanical fixes. Launching 2-4 background agents for independent packages dramatically reduced wall-clock time. The file-split pattern (read → extract to new file → trim original → build → test) was highly parallelizable.

**Worked well**: The "audit first, fix second" workflow. Running the full dependency tree audit before fixing anything revealed the ecosystem was far cleaner than expected — only ~30 actionable findings across 59 packages. This prevented over-engineering.

**Didn't work**: One agent (standards P2 + memory names) got stuck on file permissions and produced no code changes. Agent reliability for Write/Edit operations varies — the task description needs to be explicit about what tools the agent will need.

**Didn't work**: The environment typed-throws agent made correct changes but caused a stale `.build` cache issue. The fix was `rm -rf .build` — a known gotcha already in the feedback memory, but still bit us.

**Nearly wrong**: I initially flagged `__`-prefixed error types in set/dictionary/list/stack primitives as violations. The user corrected this — they're intentional, using the hoisting pattern per [PATTERN-022] for `~Copyable`-generic parents. The queue-primitives nesting was accepted, but the distinction between "hoisting for ~Copyable" and "lazy naming" is context-dependent.

## Patterns and Root Causes

**The ecosystem is architecturally sound.** Zero Foundation imports in 59 packages. The five-layer dependency discipline holds. The findings were cosmetic (naming, file organization) not structural. This validates the architecture skills.

**Spec-encoding packages resist one-type-per-file.** iso-32000 has 250+ types grouped by spec section. Splitting them loses the spec-correspondence that makes the package navigable. This is a genuine tension between [API-IMPL-005] and the "literal spec encoding" philosophy. The user's decision to defer is correct — the rule needs a documented exception for spec-section grouping.

**`MediaType` and the metatype trap.** `Media.Type` collides with Swift's metatype syntax. This is a language-level constraint that affects any type named `Type` nested inside another type. Worth documenting as a known limitation in the code-surface skill.

**Cross-package renames cascade.** Renaming INCITS compound types broke swift-ascii (consumer). The audit found the INCITS package clean in isolation, but the cross-package grep caught the downstream impact. Lesson: always grep the workspace after renaming public API.

## Action Items

- [ ] **[skill]** code-surface: Add documented exception to [API-IMPL-005] for spec-section file grouping in literal spec encodings (iso-32000 precedent)
- [ ] **[skill]** code-surface: Document `Type` as a reserved nested type name due to Swift metatype syntax collision under [API-NAME-001]
- [ ] **[skill]** implementation: Clarify that [PATTERN-022] hoisting pattern with `__` prefix is intentional for `~Copyable`-generic error types — do not nest these during audits
