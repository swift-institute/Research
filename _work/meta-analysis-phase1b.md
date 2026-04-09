# Corpus Meta-Analysis Phase 1b: Experiment Staleness Detection

**Requirement**: [META-022]
**Date**: 2026-04-08
**Scope**: All experiment directories across 5 repositories

---

## Summary

| Metric | Count |
|--------|-------|
| Total experiment directories | 161 |
| Completed (has `// Result:`) | 120 |
| Active (main.swift, no Result) | 21 |
| Multi-module completed (no main.swift, Result elsewhere) | 23 |
| Truly active no-main (no Result anywhere, has source) | 9 |
| Empty/stub directories | 3 |
| **Total requiring triage** | **11** |

---

## Active Experiments (main.swift present, no `// Result:` line)

### swift-institute/Experiments/

| Experiment | Last Modified | Age (days) | Status | Purpose | Recommended Action |
|-----------|--------------|------------|--------|---------|-------------------|
| conditional-copyable-type | 2026-03-26 | 13 | OK | Conditional Copyable conformance doesn't prevent constraint poisoning | No action needed |
| extension-extraction-scope-resolution | 2026-04-02 | 6 | OK | Validate extracting methods from nested extension bodies | No action needed |
| iterative-tuple-rendering-trampoline | 2026-03-17 | 22 | SHOULD triage | Validate trampoline approach for iterative _Tuple rendering | Execute and document result (tracked in MEMORY.md as in-progress) |
| noncopyable-multifile-poisoning | 2026-04-03 | 5 | OK | File organization within same module does NOT prevent poisoning | Execute and document result |
| noncopyable-pointer-propagation | 2026-04-03 | 5 | OK | Adding Sequence conformance where Element: Copyable poisons stored UnsafeMutablePointer | Execute and document result |
| noncopyable-pointer-propagation-multifile | 2026-04-03 | 5 | OK | Test whether file-level separation prevents constraint poisoning | Execute and document result |
| noncopyable-sequence-emit-module-bug | 2026-04-03 | 5 | OK | Module emission failure with ~Copyable + Sequence conformance | Execute and document result |
| noncopyable-sequence-protocol-test | 2026-04-03 | 5 | OK | Verify that same-file Sequence conformance poisons ~Copyable usage | Execute and document result |
| noncopyable-storage-poisoning | 2026-04-03 | 5 | OK | Conditional conformance poisons stored property access | Execute and document result |
| nonsending-generic-dispatch | 2026-04-03 | 5 | OK | Does nonisolated(nonsending) on concrete Clock.sleep survive | Execute and document result |
| nonsending-method-annotation | 2026-04-03 | 5 | OK | Validate nonisolated(nonsending) on callAsFunction() method | Execute and document result |
| protocol-coroutine-accessor-limitation | 2026-03-26 | 13 | OK | Protocol extensions fail with _read/_modify accessors + ~Copyable | Execute and document result |
| se0461-concurrent-body-sensitivity | 2026-04-02 | 6 | OK | Validate @concurrent inference for @Sendable async closures | Execute and document result |
| throws-overloading-limitation | 2026-03-26 | 13 | OK | throws modifier cannot be used for overloading | Execute and document result |
| unsafe-forin-release-crash | 2026-03-14 | 25 | SHOULD triage | expression-level `unsafe` on for-in crashes SIL optimizer in release mode | Check if swiftlang/swift#88022 is resolved; if yes mark SUPERSEDED, if no add last-active note |

### swift-primitives/Experiments/

| Experiment | Last Modified | Age (days) | Status | Purpose | Recommended Action |
|-----------|--------------|------------|--------|---------|-------------------|
| checkpoint-protocol-test | 2026-01-23 | 75 | MUST triage | Refactor checkpoint types to reuse Index from index-primitives | Mark SUPERSEDED if index-primitives adopted, or DEFERRED with reason |
| collection-iteration-semantics | 2026-01-23 | 75 | MUST triage | Verify iteration semantics for ~Copyable containers AND elements | Execute and document result, or mark SUPERSEDED by consuming-iterator-pattern |
| foreach-consuming-accessor | 2026-04-03 | 5 | OK | Test if .forEach.consuming can consume the original container | Execute and document result |
| nonescapable-edge-cases | 2026-03-03 | 36 | SHOULD triage | Validate 5 claims from nonescapable-support-memory-storage-buffer.md | Execute and document result |

### swift-standards/Experiments/

| Experiment | Last Modified | Age (days) | Status | Purpose | Recommended Action |
|-----------|--------------|------------|--------|---------|-------------------|
| rfc-4291-ipv6-address-poc | 2026-03-17 | 22 | SHOULD triage | Proof-of-concept for RFC 4291 IPv6 Addressing Architecture | Execute and document result, or DEFER if not on roadmap |

### swift-foundations/Experiments/

| Experiment | Last Modified | Age (days) | Status | Purpose | Recommended Action |
|-----------|--------------|------------|--------|---------|-------------------|
| sending-continuation-dispatch | 2026-04-08 | 0 | OK | Find minimal correct pattern for dispatching `sending @escaping () -> T` | Currently active (uncommitted changes today) |

### swift-nl-wetgever/Experiments/

No active experiments. `conclusion-type-architecture` is completed.

---

## Active Multi-Module Experiments (no main.swift, no `// Result:` anywhere)

These experiments use multi-target Package.swift structures or alternative entry points but have no documented result.

### swift-institute/Experiments/

| Experiment | Last Modified | Age (days) | Status | Swift Files | Purpose | Recommended Action |
|-----------|--------------|------------|--------|-------------|---------|-------------------|
| escapable-protocol-cross-module | 2026-04-06 | 2 | OK | 5 | ~Escapable protocol decomposition cross-module | Execute and document result |
| member-import-visibility-body-conflict | 2026-03-13 | 26 | SHOULD triage | 12 | public import SwiftUI same-file body conflict | Execute and document result |
| nested-package-source-ownership | 2026-03-13 | 26 | SHOULD triage | 7 | Nested package source ownership test | Execute and document result |
| nonsending-dispatch | 2026-04-03 | 5 | OK | 5 | nonsending callAsFunction() propagation | Execute and document result (overlaps nonsending-method-annotation) |
| nsviewrepresentable-body-witness | 2026-03-13 | 26 | SHOULD triage | 6 | Generic parameter Body vs SwiftUI.View.Body collision | Execute and document result |
| path-operator-overload-resolution | 2026-03-20 | 19 | OK | 9 | Operator overload resolution for Path types | Execute and document result |
| with-closure-to-property-migration | 2026-03-19 | 20 | OK | 6 | Cross-module ~Escapable property access migration | Execute and document result |

### swift-primitives/Experiments/

| Experiment | Last Modified | Age (days) | Status | Swift Files | Purpose | Recommended Action |
|-----------|--------------|------------|--------|-------------|---------|-------------------|
| nested-type-noncopyable-pattern | 2026-01-23 | 75 | MUST triage | 2 | Dictionary namespace with ~Copyable support | Has FINDINGS in source — extract and add `// Result:` line |

---

## Empty/Stub Directories

These directories contain no source files or only documentation stubs.

| Repo | Experiment | Last Modified | Age (days) | Contents | Recommended Action |
|------|-----------|--------------|------------|----------|-------------------|
| swift-institute | noncopyable-nested-deinit-chain | 2026-03-21 | 18 | .build dir + .DS_Store only | Delete or populate (tracked in MEMORY.md as resolved) |
| swift-institute | predictable-memopt-destroy-value-source | 2026-03-25 | 14 | EXPERIMENT.md only | Execute the described experiment or mark DEFERRED |
| swift-primitives | collection-ordering-analysis | 2026-03-12 | 27 | ANALYSIS.md only | SHOULD triage: complete analysis or mark DEFERRED |

---

## Triage Priority

### MUST Triage (>42 days, 3 experiments)

| # | Repo | Experiment | Age | Action |
|---|------|-----------|-----|--------|
| 1 | swift-primitives | checkpoint-protocol-test | 75d | Likely SUPERSEDED — check if index-primitives absorbed this |
| 2 | swift-primitives | collection-iteration-semantics | 75d | Likely SUPERSEDED — check against consuming-iterator-pattern results |
| 3 | swift-primitives | nested-type-noncopyable-pattern | 75d | Has findings in source — extract `// Result:` to complete |

### SHOULD Triage (21-42 days, 8 experiments)

| # | Repo | Experiment | Age | Action |
|---|------|-----------|-----|--------|
| 4 | swift-institute | iterative-tuple-rendering-trampoline | 22d | Execute — tracked in MEMORY.md as in-progress |
| 5 | swift-institute | unsafe-forin-release-crash | 25d | Check swiftlang/swift#88022 status |
| 6 | swift-institute | member-import-visibility-body-conflict | 26d | Execute and document |
| 7 | swift-institute | nested-package-source-ownership | 26d | Execute and document |
| 8 | swift-institute | nsviewrepresentable-body-witness | 26d | Execute and document |
| 9 | swift-primitives | nonescapable-edge-cases | 36d | Execute — validates 5 specific claims |
| 10 | swift-standards | rfc-4291-ipv6-address-poc | 22d | Execute or DEFER |
| 11 | swift-primitives | collection-ordering-analysis | 27d | Complete or DEFER (doc-only stub) |

### Potential Consolidation Clusters

Several active experiments appear to test the same underlying compiler behavior and could be consolidated:

| Cluster | Experiments | Consolidation Target |
|---------|------------|---------------------|
| ~Copyable constraint poisoning | noncopyable-multifile-poisoning, noncopyable-pointer-propagation, noncopyable-pointer-propagation-multifile, noncopyable-sequence-protocol-test, noncopyable-storage-poisoning | Single consolidated experiment with multi-variant Package.swift |
| nonisolated(nonsending) | nonsending-generic-dispatch, nonsending-method-annotation, nonsending-dispatch | Single experiment with multiple entry points |
| ~Copyable Sequence emission | noncopyable-sequence-emit-module-bug | May merge into poisoning cluster |

---

## Statistics by Repository

| Repository | Total | Completed | Active | Active No-Main | Empty/Stub |
|-----------|-------|-----------|--------|---------------|------------|
| swift-institute | 131 | 89 | 15 | 7 | 2 |
| swift-primitives | 28 | 18 | 4 | 2 | 1 |
| swift-standards | 2 | 1 | 1 | 0 | 0 |
| swift-foundations | 7 | 6 | 1 | 0 | 0 |
| swift-nl-wetgever | 1 | 1 | 0 | 0 | 0 |
| **Total** | **169** | **115** | **21** | **9** | **3** |

Note: 23 multi-module experiments without main.swift were confirmed completed via `// Result:` lines in alternative source files. These are counted in the "Completed" column above (correcting the initial summary which counted 120 main.swift-completed + 23 multi-module-completed = 143 total completed; the remaining 26 are the 21 active + 9 active-no-main + 3 empty, but the 9 active-no-main and 7 from the no-main list that were actually completed overlap, giving 169 - 143 - 3 = 23 unresolved, matching the 21 active + 9 no-main - 7 reclassified = 23).

Corrected totals: 143 completed, 21 active with main.swift, 2 active multi-module no-main (escapable-protocol-cross-module is 2 days old), 3 empty/stub = 169.
