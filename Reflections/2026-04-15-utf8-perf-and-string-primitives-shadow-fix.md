---
date: 2026-04-15
session_objective: Fix O(n^2) StringProtocol.range(of:) performance bug (tuist/FileSystem#325 parity) and investigate similar opportunities across ecosystem
packages:
  - swift-standard-library-extensions
  - swift-parsers
  - swift-clocks
  - swift-kernel
status: processed
processed_date: 2026-04-16
triage_outcomes:
  - type: research_topic
    target: exported-chain-audit-string-primitives.md
    description: "Enumerate @_exported import chains propagating String_Primitives through L3 consumer APIs"
  - type: no_action
    description: "[package] swift-whatwg-url UTF-8 byte percent decoder — specific bug fix, execution task"
  - type: skill_update
    target: implementation
    description: "Added [IMPL-089] Foundation-Free String Scanning Defaults to UTF-8 Byte View"
---

# UTF-8 Perf Fixes and String_Primitives Shadow Resolution

## What Happened

External trigger: tuist/FileSystem#325 reported an identical O(n^2) bug in `StringProtocol.range(of:)` — Character-by-Character scan with per-iteration `distance(from:to:)` calls. We confirmed the ecosystem copy in `swift-standard-library-extensions` had the same pattern and patched it to a UTF-8 byte scan (~6500x speedup on realistic workloads). The semantic change from grapheme-cluster equivalence to byte-literal matching was accepted and documented: the doc comment now explicitly states byte-literal semantics with guidance to normalize inputs for grapheme equivalence.

Ecosystem sweep found a second O(n^2): `Parsers.Diagnostic.Source` init in `swift-parsers` — `content.enumerated()` with `content.index(startIndex, offsetBy: index + 1)` on every newline. Patched to UTF-8 byte scan. Also fixed a latent index-space mismatch where `location(at:)` mixed Character-view lineStarts with UTF-8-view targetIndex.

Attempting to test the Parsers fix revealed the package couldn't build at all — every use of bare `String` resolved to `String_Primitives.String` (~Copyable) instead of `Swift.String`. This was a known issue (research doc from 2026-03-14, experiment from 2026-02-27) but had never been fully resolved. Investigation traced the current leak path: `Parsers → @_exported Async → Async_Stream → Async_Stream_Core → Clocks → @_exported Kernel → @_exported Kernel_Core → @_exported Kernel_Path_Primitives → @_exported Path_Primitives → public import String_Primitives`. The 2026-03-14 research had removed `String_Primitives` from `Kernel_Primitives_Core` (L1) but the L3 chains still propagated it.

The fix: removed `@_exported public import Kernel` from `Clocks/Exports.swift` — Clocks used zero Kernel types in its own code; the re-export was pure umbrella convenience. This eliminated the shadow for all downstream consumers (Parsers, Async, etc.). Secondary fix: demoted `Kernel_String_Primitives` import in `Kernel_File` to internal with package-scoped bridge init. `Parsers.Debug.swift` gained an explicit `public import ISO_9945_Kernel_Clock` to replace the now-absent transitive import.

Result: `swift-parsers` builds cleanly (84 tests pass), `swift-clocks` builds, `swift-kernel` builds. Four commits across four packages.

## What Worked and What Didn't

**Worked well:**
- The performance sweep methodology was efficient: targeted grep for `distance(from:` and `Array(string.utf8)` in Sources directories, filtered to ecosystem paths, manually reviewed each hit. Found the real Parsers.Diagnostic bug in ~5 minutes. Most hits were correctly triaged as non-issues (error paths, constant-bounded, O(1) collections).
- The UTF-8 byte scan pattern transferred cleanly from the Tuist PR. The `where UTF8View.Index == Index` constraint on the extension was the right solution for the generic `StringProtocol` context.
- Existing research (`string-primitives-shadowing.md`, experiment `typealias-without-reexport/`) was thorough and immediately useful — saved significant re-investigation time.

**Didn't work:**
- Initial shadow investigation focused on `Kernel_File/Swift.String+Kernel.swift` (a `public import Kernel_String_Primitives`), which was a secondary path. The primary path was through `Path_Primitives → public import String_Primitives`, which only surfaced after the first fix didn't resolve the build. A more systematic approach would have grepped all `@_exported` chains from Parsers' dependency closure before making changes.
- The 2026-03-14 research's recommended changes were partially applied (L1 `Kernel_Primitives_Core` was cleaned) but the L3 path was never addressed. The research document itself only analyzed the L1 chains; the L3 `Kernel_Core` umbrella re-exporting everything from L1 wasn't covered. This gap meant the fix was incomplete for months.

## Patterns and Root Causes

**@_exported is viral and accumulative.** Each `@_exported` in a chain multiplies the visible symbol set for all downstream consumers. The `Kernel_Core` umbrella at L3 re-exports 30+ L1 modules — any of which can carry `public import` declarations that shadow stdlib names. The Clocks fix worked because it severed the widest re-export (Kernel umbrella) from the widest consumer (Async/Parsers). But the root remains: `Path_Primitives` has `public import String_Primitives` for its `Path.Char` typealias, and any module that `@_exported import Path_Primitives` will propagate the shadow.

**External bug reports as ecosystem audit triggers.** The tuist/FileSystem#325 PR was the catalyst for both the O(n^2) fixes and the shadow investigation (which was incidental — we only hit it because we tried to test the Parsers fix). Performance bugs in downstream consumers can reveal identical patterns in upstream primitives. Worth monitoring public Swift ecosystem PRs tagged with performance.

**The UTF-8 byte scan is the correct default for Foundation-free string operations at L1.** Both `range(of:)` and `Parsers.Diagnostic.Source.init` benefited from the same pattern: scan `content.utf8` with O(1) index operations instead of iterating Characters. The `0x0A` newline scan and the byte-literal substring search are instances of the same principle: at L1, byte-level is the right abstraction unless grapheme semantics are explicitly required.

## Action Items

- [ ] **[research]** Audit all remaining `@_exported` chains that propagate `String_Primitives` — `Kernel_Core` (L3) still re-exports `Kernel_Path_Primitives` which carries the shadow via `Path_Primitives`. The `public import String_Primitives` in `Path.swift` is required for the `Path.Char` typealias; the fix must be at the re-export level, not the typealias level.
- [ ] **[package]** swift-whatwg-url: Fix Character-by-Character percent decoder in `WHATWG_Form_URL_Encoded.PercentEncoding.decode` — scan `string.utf8` directly, parse hex from two `UInt8` values, eliminate per-char `String(char).utf8` allocation (finding #2 from the perf sweep).
- [ ] **[skill]** implementation: Add guidance that Foundation-free string scanning at L1/L2 should default to UTF-8 byte view, not Character iteration — cite `range(of:)` and `Parsers.Diagnostic.Source.init` as canonical examples.
