---
date: 2026-05-08
session_objective: Execute the HANDOFF-extract-pair-product-either-primitives.md dispatch — extract Pair / Product / Either from swift-algebra-primitives into three new private Tier 0 packages, drop the source files from algebra-primitives, rewire the 19-file Scope-B consumer set, and run the [HANDOFF-035] ecosystem-wide cascade-termination gate.
packages:
  - swift-pair-primitives
  - swift-either-primitives
  - swift-product-primitives
  - swift-algebra-primitives
  - swift-symmetry-primitives
  - swift-finite-primitives
  - swift-dimension-primitives
  - swift-region-primitives
  - swift-async-primitives
  - swift-parser-primitives
  - swift-geometry-primitives
  - swift-iso-9945
  - swift-posix
  - swift-file-system
  - swift-pdf-render
  - swift-threads
  - swift-io
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: NoAction [HANDOFF-026] strengthening with 3 sub-classes deferred (small-scope amendment, candidate for follow-up). NoAction [HANDOFF-040] transitive-consumer-via-re-export-chain extension already covered by [HANDOFF-040] amendment with form-position variants (landed Cluster A). NoAction [MOD-NNN] post-extraction re-export-chain repair patterns deferred to follow-up modularization sweep.
---

# Pair / Either / Product Extraction Execution and Scope-B Cascade

## What Happened

Executed the four-step extraction dispatch on `HANDOFF-extract-pair-product-either-primitives.md`. Total landed: 3 new private Tier 0 repos created and pushed (each `{X} Primitives` single-product); algebra-primitives narrowed; 14 consumer repos rewired across L1 / L2 / L3; ecosystem-wide cascade-termination gate satisfied.

Supervisor escalations (2):

1. **Class-(c) structural shape conflict at dispatch start.** The handoff's Step 1 prescribed `{X} Namespace + {X} Primitives Core + {X} Primitives` (umbrella) targets — the algebra-primitives shape — but Pair/Product/Either are concrete generic types at module scope, not namespace enums. A `Pair Namespace` target with `public enum Pair {}` would collide with the existing `public struct Pair<First, Second>` in the umbrella's import surface. The closest institute precedents (`swift-tagged-primitives`, `swift-carrier-primitives`) both ship the simpler one-target shape. Surfaced inline-markdown to supervisor per `feedback_escalate_inline_not_askuserquestion`. Supervisor resolved with "ONE module per package" — single library product, single source target, single test target. No Test Support, no SLI, no umbrella, no Namespace target.

2. **Class-(c) [HANDOFF-026] gap at Step 2.** After deleting the three source files from algebra-primitives, `swift build` failed with 9 errors — the algebra-flavored enum files (`Bound`/`Boundary`/`Endpoint`/`Gradient`/`Monotonicity`/`Parity`/`Polarity`/`Sign`/`Ternary`) all carry public typealiases of shape `<Self>.Value<Payload> = Pair<Self, Payload>`. The handoff labeled them "Preserved (separate dispatch)" without compile-verifying that they reference the moved Pair. Surfaced to supervisor with five resolution options. Supervisor stamped the [HANDOFF-026] miss as a writer-side gap, amended the MUST NOT in flight to permit `public import Pair_Primitives` on those 9 files only (no rename, no API removal — strictly the mechanical residue), and authorized Option A. Tier shift: algebra-primitives moved Tier 0 → Tier 1.

Scope-B cascade (Step 3): the original 19-file Scope-B list expanded to 23+ files during execution. Four transitive consumers the import-anchored Scope-B grep missed:

| Package | Transitive consumer | How it broke |
|---|---|---|
| swift-finite-primitives | `Comparison+Finite.swift` | Used `Pair<Comparison, Payload>` via `@_exported public import Algebra_Primitives` in `exports.swift`; no explicit import. |
| swift-dimension-primitives | `Chirality.swift`, `Orientation.swift`, `Winding.swift`, `exports.swift` | Used `Pair<...>` via `@_exported import struct Algebra_Primitives.Pair` (symbol-level re-export) in `exports.swift`. |
| swift-bit-primitives | `Bit.Value.swift` | Used `Pair<Bit, Payload>` via finite-primitives' transitive re-export chain. Required no source change after finite-primitives' exports.swift gained `@_exported public import Pair_Primitives`. |
| swift-iso-9945 | `Pipe.swift`, `Pipe.Close.swift`, `Socket.Pair.swift`, plus read.swift / write.swift Either consumers | Used Pair / Either via `@_exported public import Algebra_Primitives` in target exports.swifts. |
| swift-parser-primitives | `Parser.OneOf.Two.swift`, `Parser.OneOf.Three.swift` | Used `Product<...>` via `Parser Error Primitives`' re-export chain. Discovered post-Either rewiring; required adding `Product Primitives` re-export. |

Pre-existing baseline blocker: swift-standard-library-extensions had an in-progress dirty worktree from another stream (`Optional.Builder.swift:71` `component ?? nil` → `component` flip — broken). Per `feedback_triage_dirty_worktree` I did not touch it and surfaced. Supervisor (user as relay) fixed it inline.

Cascade-termination gate per [HANDOFF-035] (Step 4): end-of-cascade workspace-wide grep returned only the documented out-of-scope research markdown (`async-primitives/Research/typed-throws-audit-2026-04-24.md`); sample clean builds on swift-algebra-primitives (1.48s), swift-finite-primitives (transitive, 14.60s), swift-file-system (L3 bottom-of-chain, 149.30s) all green. All 14 repos pushed (PRIVATE — visibility unchanged); upstream HEAD on each matches the rewiring/cleanup commit.

**HANDOFF scan:** 50 `HANDOFF*.md` files at `/Users/coen/Developer/`; 1 in session authority (`HANDOFF-extract-pair-product-either-primitives.md` — wrote no part of it but actively worked all 4 steps; case (b) per [REFL-009]); 49 out-of-session-scope (other agents' / sessions' work). Disposition for the in-authority file: all Next Steps complete, all 9 supervisor ground-rules entries verified end-to-end (5 MUST NOT + 2 MUST + 2 ask: — verification line per [SUPER-011]), no pending escalation → DELETE per [REFL-009].

## What Worked and What Didn't

### Worked

- **Inline-markdown supervisor escalation** per `feedback_escalate_inline_not_askuserquestion`. Both escalations (structural-shape + [HANDOFF-026]) landed cleanly with the user-as-relay forwarding to supervisor and clear A/B/C decision-table responses. The structural-shape conflict in particular needed a 5-option resolution table and got a one-paragraph clean answer.
- **Per-package build verification as cascade-discovery mechanism.** `swift build --build-tests` immediately after each Package.swift edit caught the 4 transitive consumers (finite, dimension, iso-9945, parser-Product) one at a time. Without per-package builds, those would have been silent breaks at consumer build time later.
- **Triage-not-touch on dirty worktree** per `feedback_triage_dirty_worktree`. The pre-existing dirty changes in swift-standard-library-extensions were correctly identified as another stream's work and surfaced rather than blanket-staged or reverted.
- **[SUPER-033] in-absentia + cascade lowest-loss interpretation** for the 5 Open Questions and 2 `ask:` items. Defaults specified in the handoff covered all 5 OQs cleanly; the 2 `ask:` items were surfaced to supervisor (NOT auto-applied) because they were explicitly typed as `ask:`. Supervisor confirmed defaults and overruled one (Test Support → no Test Support).
- **Topological build order** prevented thrash. L1 → L2 (iso-9945) → L3 ordering meant each package's deps were already buildable before that package was attempted. Once standard-library-extensions was unblocked, the L3 packages built clean in sequence.

### Didn't Work

- **Scope-B import-anchored grep missed transitive consumers.** The handoff's Scope B (`grep -l "import Algebra_Primitives" | xargs grep ...`) listed 19 files. Actual rewiring set was 23+ files because `@_exported public import Algebra_Primitives` (and `@_exported import struct Algebra_Primitives.Pair`) in upstream packages' `exports.swift` made the types reachable transitively without per-file explicit imports. Files reaching types via re-export chains were invisible to Scope B.
- **[HANDOFF-026] writer-side compile-verification was skipped on the dispatch handoff itself.** The 9 algebra-flavored enum files were labeled "Preserved" without verifying their typealias surface didn't reference moved types. Supervisor acknowledged the writer-side miss in the resolution and amended the MUST NOT in flight.
- **Ten-Edit batch of source files lost 9 of 10 to "must Read first"** (the algebra-primitives 9-file `public import Pair_Primitives` add). My first Edit batch failed because Edit requires a prior Read. The Package.swift Edit (which had been Read earlier) succeeded; the 9 source-file Edits all failed with the same "File has not been read yet" error. Recovery: 9 parallel Reads then 9 parallel Edits.
- **Several touched packages have pre-existing test-target failures** unrelated to this dispatch (symmetry's Rotation Tests compiler timeout + Affine generic-spec; geometry's Bezier/Ellipse Tagged-rawValue + Radian arithmetic; iso-9945's Socket.Error.handle API drift; io's IO.Event.Primitives ambiguity; pdf-render's PreviewCopyPaste Foundation/EdgeInsets). Main-target builds verified clean per package, but the [HANDOFF-013b] `swift build --build-tests` clean-gate degrades to `swift build` clean-gate plus per-package documentation-of-pre-existing-failure for those packages.

## Patterns and Root Causes

**Re-export chain detection is the missing axis in extraction grep methodology.** Scope B is import-anchored: it finds files that explicitly `import {OldModule}`. But the institute pattern of `@_exported public import {Module}` in `exports.swift` files makes types reachable WITHOUT per-file explicit imports. Two distinct re-export shapes were observed:

1. **Module-level re-export:** `@_exported public import Algebra_Primitives` in `exports.swift` of an upstream package (finite-primitives, parser-primitives' Parser Error Primitives, iso-9945's Kernel File / Kernel Socket targets). Files in the same module use Pair/Either/Product as if they were native — no per-file import needed.
2. **Symbol-level re-export:** `@_exported import struct Algebra_Primitives.Pair` (dimension-primitives' exports.swift) — narrower than a module re-export but same effect: the symbol is grafted into the consuming module without per-file import.

Both patterns make the type a "module-resident" symbol. Grep for the import statement misses them entirely. The mechanical fix is a two-pass Scope B: pass 1 = the existing import-anchored grep; pass 2 = grep for `@_exported public import {OldModule}` and `@_exported import struct {OldModule}.Pair|Either|Product` in `exports.swift` files of the L1+L2+L3 ecosystem; for matching packages, treat ALL source files in that target as candidate consumers (since any of them can reach the type implicitly).

**The [HANDOFF-026] "Preserved" label is a load-bearing assertion that requires compile-verification when the moved type appears in PUBLIC API surface of the "preserved" files.** The 9 algebra-flavored enum files would have built fine if Pair were a `private` typealias dependency. They broke because the typealias was `public typealias <Self>.Value<Payload> = Pair<Self, Payload>` — the moved type was load-bearing on the file's PUBLIC surface, not just an implementation detail. Per [HANDOFF-026]'s mechanical check (`grep -l moved-type preserved-file`), the 9 hits were there at handoff-write time; the writer's mental model of "Preserved means independent" missed that Public-RHS typealiases are dependent.

This generalizes: the [HANDOFF-026] check should explicitly cover three sub-classes of "reference" — (a) implementation-body references (current rule), (b) typealias-RHS references (this case), and (c) generic-constraint references (where clauses, conformance constraints). All three are load-bearing for compilation.

**Three distinct re-export-chain repair patterns emerged during cleanup**, none documented:

| Pattern | Consumer | Edit |
|---|---|---|
| (a) Keep + add | finite-primitives' exports.swift | Kept `@_exported public import Algebra_Primitives`; added `@_exported public import Pair_Primitives`. Other algebra-flavored types (Bound/Sign/etc.) still reachable via the original re-export. |
| (b) Symbol-import swap | dimension-primitives' exports.swift | Swapped `@_exported import struct Algebra_Primitives.Pair` for `@_exported import struct Pair_Primitives.Pair`. Single-symbol surgical change. |
| (c) Module-import swap | parser-primitives' Parser Error Primitives, iso-9945's exports.swift's | Replaced `@_exported public import Algebra_Primitives` with two narrower lines (`Either_Primitives` + `Pair_Primitives` or `Product_Primitives`). Removes the wide re-export. |

The pattern choice depends on whether the consuming package needs to retain access to OTHER algebra-flavored types still in algebra-primitives. Finite-primitives uses Bound/Sign in addition to Pair (so pattern a). Parser-primitives doesn't use any algebra-flavored types except Either + Product (so pattern c). Dimension-primitives only used Pair from Algebra_Primitives at the symbol level (so pattern b is sufficient).

**Auxiliary observation: bulk-fix re-Edit gotcha.** Edit requires Read first. When applying a multi-file mechanical fix in one Tool batch, all files must be Read first. This isn't a defect of mine; it's a reminder that the Read-then-Edit invariant is per-tool-call, not per-session. Future bulk-edit patterns should batch Reads in one wave then Edits in another.

## Action Items

- [ ] **[skill]** handoff: Strengthen [HANDOFF-026] (Preserved-File Compile-Verification Sub-Requirement) to explicitly enumerate the three sub-classes of references that fail the Preserved label — (a) implementation-body references, (b) typealias-RHS references in PUBLIC API surface, (c) generic-constraint references. Add a worked example showing that `<Classifier>.Value<Payload> = Pair<<Classifier>, Payload>` would fail Preserved-compile-verification when Pair is being moved.
- [ ] **[skill]** handoff: Add a transitive-consumer-via-re-export-chain extension to [HANDOFF-040] / [HANDOFF-013a] (writer-side prior-research grep). Extraction handoffs MUST grep `@_exported public import {OldModule}` and `@_exported import struct {OldModule}.{Type}` across ALL `exports.swift` files in the ecosystem, not just files that explicitly `import {OldModule}`. For matching upstream packages, treat all source files in the affected target as candidate transitive consumers.
- [ ] **[skill]** modularization: Document the three post-extraction re-export-chain repair patterns under a new [MOD-NNN] rule. Pattern (a) keep+add (when consumer still uses other types in the old module), pattern (b) symbol-import swap (when consumer only used the moved type at symbol level), pattern (c) module-import swap with multiple narrower re-exports (when consumer's full re-export was for the moved types).
