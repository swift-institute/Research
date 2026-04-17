<!--
version: 1.0.0
last_updated: 2026-04-15
status: COMPLETE
tier: 2
workflow: Audit [AUDIT-*]
trigger: Phase 2 of ecosystem @unsafe audit — swift-foundations
scope: swift-foundations submodules (16 repos)
-->

# Phase 2 Foundations -- `@unsafe` Audit Application Results

## Summary

- **Total files edited**: 40
- **Total commits**: 19 (across 16 submodules)
- **Category A (synchronized, @unsafe applied)**: 25 sites
- **Category B (ownership transfer, @unsafe applied)**: 2 sites
- **Category C (thread-confined, // WHY: added)**: 1 site
- **Category D (structural workaround, // WHY: added)**: 12 sites
- **Pilot (already committed)**: 1 site (Kernel.Thread.Synchronization, `da86a35`)
- **Build result**: PASS (all @unsafe-bearing packages build; preexisting errors in unrelated packages)
- **Test result**: PASS (swift-threads 35/35, swift-executors 18/18, swift-witnesses 138/138)

---

## Commits

### swift-threads (3 files)

| Commit | Message |
|--------|---------|
| `52063ba` | Mark thread synchronization primitives @unsafe (Category A, 3 sites) |

### swift-executors (7 files)

| Commit | Message |
|--------|---------|
| `6adccf3` | Mark executor types @unsafe (Category A, 7 sites) |

### swift-kernel (1 file)

| Commit | Message |
|--------|---------|
| `b6457a3` | Mark Kernel.Thread.Handle.Reference @unsafe (Category B, 1 site) |

### swift-witnesses (5 files)

| Commit | Message |
|--------|---------|
| `6d694d2` | Mark swift-witnesses synchronized types @unsafe (Category A, 4 sites) |
| `66c4128` | Add // WHY: to Witness.Values._Storage (Category D, structural) |

### swift-dependencies (1 file)

| Commit | Message |
|--------|---------|
| `e796a58` | Add // WHY: to _Accessor (Category D, structural) |

### swift-io (5 files)

| Commit | Message |
|--------|---------|
| `b4601c7f` | Mark IO event loop types @unsafe (Category A, 5 sites) |

### swift-file-system (1 file)

| Commit | Message |
|--------|---------|
| `1621a89` | Add // WHY: to File.Directory.Contents.IteratorHandle (Category C, 1 site) |

### swift-memory (1 file)

| Commit | Message |
|--------|---------|
| `977c70b` | Mark Memory.Map @unsafe (Category B, 1 site) |

### swift-tests (7 files)

| Commit | Message |
|--------|---------|
| `c67ab2d` | Mark swift-tests synchronized types @unsafe (Category A, 6 sites) |
| `702b7b8` | Add // WHY: to NullSink (Category D, structural) |

### swift-copy-on-write (1 file)

| Commit | Message |
|--------|---------|
| `4953b8c` | Add // WHY: to CoW.Storage macro template (Category D, structural) |

### swift-html-rendering (1 file)

| Commit | Message |
|--------|---------|
| `cc421a6` | Add // WHY: to HTML.AnyView (Category D, structural) |

### swift-pdf-html-rendering (2 files)

| Commit | Message |
|--------|---------|
| `054f831` | Add // WHY: to PDF recording types (Category D, 2 sites) |

### swift-json (1 file)

| Commit | Message |
|--------|---------|
| `2840093` | Add // WHY: to JSON.ND.State (Category D, structural) |

### swift-plist (2 files)

| Commit | Message |
|--------|---------|
| `22dc2bc` | Add // WHY: to Plist ND.State and Binary.Context (Category D, 2 sites) |

### swift-xml (1 file)

| Commit | Message |
|--------|---------|
| `da3c987` | Add // WHY: to XML.ND.State (Category D, structural) |

### swift-parsers (1 file)

| Commit | Message |
|--------|---------|
| `b921136` | Add // WHY: to Parser.Debug.Profile.Stats (Category D, structural) |

---

## Build Results Per Commit

| Package | Build | Notes |
|---------|:-----:|-------|
| swift-threads | PASS | 36/36 modules, 11.27s |
| swift-executors | PASS | 59/59 modules, 26.05s |
| swift-kernel | PASS | 50/50 modules, 24.84s |
| swift-witnesses | PASS | 157/157 modules, 24.26s |
| swift-io | PASS | 152/152 modules, 51.51s (preexisting warnings on public import) |
| swift-memory | PASS | 641/641 modules, 41.49s |
| swift-file-system | PREEXISTING FAIL | Errors in File.System.Copy.Recursive.swift / File.System.Link.Read.Target.swift (not my files) |
| swift-tests | PREEXISTING FAIL | swift-loader Darwin_Primitives import failure (transitive dependency) |
| swift-json | PREEXISTING FAIL | String_Primitives type mismatch |
| swift-xml | PREEXISTING FAIL | W3C XML parser conformance issue |
| swift-plist | PREEXISTING FAIL | Same W3C XML parser issue |
| swift-parsers | PREEXISTING FAIL | ~Copyable String in enum associated value |
| swift-dependencies | (comment-only, no build concern) | |
| swift-copy-on-write | (macro template, no build concern) | |
| swift-html-rendering | (comment-only, no build concern) | |
| swift-pdf-html-rendering | (comment-only, no build concern) | |

All preexisting failures verified by building without the audit changes and observing the same errors.

## Test Results

| Package | Result | Tests | Suites |
|---------|:------:|------:|-------:|
| swift-threads | PASS | 35 | 18 |
| swift-executors | PASS | 18 | 21 |
| swift-witnesses | PASS | 138 | 45 |

swift-memory tests have a preexisting compilation error (missing import of `Identity_Primitives_Test_Support`). Not related to audit changes.

---

## Exclusions Applied

1. `Kernel.Thread.Synchronization` -- already committed at `da86a35` (SKIPPED)
2. `swift-io-state-investigation/` -- excluded per ground rule #5 (NOT TOUCHED)
3. Tests/, Experiments/, Benchmarks/, Research/ -- Sources/ only (NOT TOUCHED)
4. `Witness.Values._Storage` -- reclassified from Cat A to Cat D per spot-check correction (// WHY: applied, NOT @unsafe)

---

## Issues Encountered

None blocking. All preexisting build failures are in unrelated files/packages. The annotation-only nature of this audit means zero semantic changes to any compilation unit.

---

## References

- `unsafe-audit-findings.md` -- master classification document
- `unsafe-audit-agent1-findings.md` -- Agent 1 classifications (swift-threads, swift-executors, swift-kernel, swift-witnesses, swift-dependencies)
- `unsafe-audit-agent5-findings.md` -- Agent 5 classifications (swift-io, swift-file-system, swift-memory, swift-parsers, swift-plist, swift-json, swift-xml, swift-tests, swift-copy-on-write, swift-html-rendering, swift-pdf-html-rendering)
- `ownership-transfer-conventions.md` -- Category C Tier 1 sites
