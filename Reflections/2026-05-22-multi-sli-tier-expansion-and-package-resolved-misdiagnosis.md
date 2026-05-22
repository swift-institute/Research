---
date: 2026-05-22
session_objective: Implement Cardinal SLI Overload Expansion (Tiers 1–3) per the handoff, then opportunistically extend Ordinal and Affine SLIs, drive consumer migrations across ~13 data-structure packages, and attempt mechanizing the resulting cleanup pattern as a lint rule.
packages:
  - swift-primitives/swift-cardinal-primitives
  - swift-primitives/swift-ordinal-primitives
  - swift-primitives/swift-affine-primitives
  - swift-primitives/swift-sequence-primitives
  - swift-primitives/swift-buffer-primitives
  - swift-primitives/swift-storage-primitives
  - swift-primitives/swift-hash-table-primitives
  - swift-primitives/swift-primitives-linter-rules
  - swift-institute/Skills
  - swift-institute/Audits
status: pending
---

# Multi-SLI Tier expansion + Package.resolved misdiagnosis + lint rule REVERT

## What Happened

Session objective per HANDOFF.md: implement the ~14 typed-Cardinal overloads in cardinal-primitives' Standard Library Integration target, tier-by-tier, per the research artifact `cardinal-sli-overload-expansion-survey.md @ commit f80911a` on cardinal-primitives main.

Scope expanded from "Cardinal Tiers 1-3" to "all three SLI primitives + extension batch + lint promotion attempt" across the arc.

**Cardinal SLI Tier 1** (commit `1fb2691`): `RangeReplaceableCollection.removeFirst(_: some Carrier.Protocol<Cardinal>)`; `BidirectionalCollection.removeLast(_:) where Self: RangeReplaceableCollection`; `Collection.{prefix, suffix, dropFirst, dropLast}` — all returning `SubSequence`. Empirically corrected the research's "Sequence" placement to "Collection" (Sequence has no `SubSequence` associatedtype; all four `(_:Int) -> SubSequence` forms live on Collection in stdlib).

**Cardinal SLI Tier 2** (commit `5098356`): Set + Dictionary `reserveCapacity(_:)` + `init(minimumCapacity:)`. Per-type since neither conforms to `RangeReplaceableCollection`.

**Cardinal SLI Tier 3** (commit `fbad738` + refinement `15d2e1b`): `Swift.Array.init(repeating:count:)`, `Swift.Array.init(unsafeUninitializedCapacity:initializingWith:)`, `ContiguousArray.init(unsafeUninitializedCapacity:initializingWith:)`, `String.init(repeating:count:)`. The `unsafeUninitializedCapacity` form refined to use a single generic `C: Carrier.Protocol<Cardinal>` for BOTH capacity and the inout count closure parameter — preserves count domain across the API.

**Span / MutableSpan extracting overloads** (commit `9439453`): `extracting(first/droppingFirst/last/droppingLast:)` on `Span` and `MutableSpan`. MutableSpan delegates internally to stdlib's `_mutatingExtracting(...)` family (macOS 26.x renamed the mutating `extracting(_:Int)` form to disambiguate from non-mutating `Span.extracting`).

**Raw buffer + raw span SLI** (commit `3642047`): `UnsafeRawBufferPointer.init(start:count:)`, `UnsafeMutableRawBufferPointer.init(start:count:)` + `allocate(byteCount:alignment:)`, `RawSpan.init(_unsafeStart:byteCount:)`, `MutableRawSpan.init(_unsafeStart:byteCount:)` — all accepting `some Carrier.Protocol<Cardinal>`.

**Ordinal SLI Tier 1** (commit `f07a4a1`): `MutableCollection.swapAt(_:_:) where Self.Index == Int`; `RangeReplaceableCollection.{insert(_:at:), remove(at:)} where Self.Index == Int`. Three overloads covering Array, ContiguousArray, ArraySlice via the `Self.Index == Int` constraint.

**Affine SLI Tier 1** (commit `6779cee`): `Collection.{index(_:offsetBy:), index(_:offsetBy:limitedBy:), formIndex(_:offsetBy:), formIndex(_:offsetBy:limitedBy:)}` + raw pointer `advanced(by:)`, `load(fromByteOffset:as:)`, `storeBytes(of:toByteOffset:as:)` — all accepting `some Carrier.Protocol<Affine.Discrete.Vector>`. Companion to the existing Ordinal-typed `advanced(by:)` (non-negative); Vector form covers signed displacement.

**Generic `Int.init(bitPattern: some ...)` overloads** (3 commits across cardinal-primitives `3064f5c`, ordinal-primitives `b0f4c56`, affine-primitives `51c10c2`): generalized the bare-type `Int.init(bitPattern: Cardinal/Ordinal/Vector)` forms to `some Carrier.Protocol<X>` / `some Ordinal.Protocol`. The bigger-than-expected value: existing call sites that already passed typed values directly via `Int(bitPattern: typedValue)` started resolving cleanly without explicit accessor unwrap.

**UInt32.init from Ordinal** (commit `9da5ccb`): sibling to `Cardinal Primitives Standard Library Integration`'s existing `UInt32.init(_ cardinal: some Carrier.Protocol<Cardinal>)` — `UInt32.init(_ position: some Ordinal.Protocol)`. Closes the `UInt32(Int(bitPattern: slot))` intermediate-Int dance found in buffer-primitives' Buffer.Arena+Heap.

**Consumer migrations**:
- swift-sequence-primitives `32f6dca`: `contextBuffer.dropFirst(skip)` via Tier 1 Collection.dropFirst.
- swift-sequence-primitives `99e2866`: `Span.extracting(first:)` migrations in Sequence.Difference.Steps.Iterator + Changes.Iterator.
- swift-buffer-primitives `00710a2`, `95e79df`, `79eecc2`: Buffer.Aligned + Buffer.Aligned+Convenience + Buffer.Arena.Inline cleanups (raw buffer / raw span + accessor-chain stripping).
- swift-storage-primitives `01a284a`: Storage.Split ~Copyable accessor cleanup.
- swift-hash-table-primitives `f963893`: Hash.Table.Static Index.Bounded position write cleanup.

**Misdiagnosed-as-Swift-compiler-bug investigation (REFUTED)**: handoff cited a `~Copyable Self` extension resolution-stress site (`swift-sequence-primitives @ 1f8965a / Sequence.Protocol+collect.swift:25`). Spent ~2 hours building a multi-variant minimal reproducer per `/experiment-process` (minimal single-module, minimal cross-module, full-Carrier.Protocol-shape multi-module, real-deps via SwiftPM mirror). Every variant compiled clean. Root cause discovered mid-investigation via user prompt ("is it perhaps resolving against main/origin for cardinal? is this an issue with our swift package mirror setup?"): SwiftPM `Package.resolved` in swift-sequence-primitives was pinned to cardinal-primitives `@ 4b7a83a` (Initial publication 2026-05-12), pre-dating the entire reserveCapacity arc. The typed-Cardinal `reserveCapacity` overload genuinely did not exist in the resolved upstream module — the compiler correctly failed to find it. `swift package update` re-resolved against the local mirror's current HEAD, fixed every "resolution-stress" symptom in one command. Experiment outcome: REFUTED (`swift-cardinal-primitives/Experiments/copyable-self-cardinal-resolution`, commit `a7f7cc2`).

**Parallel agent fan-out for migration sweep**: 4 agents launched in parallel covering 13 packages (buffer; hash-table+tensor; queue+dict+heap; bit-vector+tree+set+stack+storage+input+system). Each agent: `swift package update` → identify cleanable Int(bitPattern:) sites → migrate → build clean → commit. Total wall time ~10 minutes; 5 mechanical migrations across 4 files; surfaced 2 SLI gaps (UInt32.init from Ordinal — landed; stride-aware pointer + count operator — deferred). Confirmed workspace was already substantially clean of `.cardinal`/`.ordinal`/`.underlying`/`.vector` accessor-chain anti-patterns; the new generic `Int.init` overloads delivered their primary value by making existing typed-direct calls resolve, not by enabling bulk cleanup.

**Lint rule promotion attempt (`[INFRA-020a]` bitpattern carrier accessor) — REVERT**: ran the 8-phase `lint-rule-promotion` pipeline. Phase 1 Pass A + B PASS; Pass C(1) identified Int.init recursion carve-out (mechanical via parent extension check); Pass C(2) acknowledged custom-type false positives as warn-only-suppressible. Decision: MECHANIZE. Phase 2 placement: primitives tier, `Primitives Linter Rule RawValue` pack. Phase 3 implementation: 120-line AST visitor with parent-chain InitializerDecl traversal for the Int.init carve-out. Phase 4-5: 10 tests (4 positive + 6 edge) all passing. Phase 6 validation against the ladder: 82 findings across cardinal (44) / affine (9) / ordinal (29) — all concentrated in SLI bridging bodies. Branch 3 (REVERT) triggered: the carve-out for `extension Int { init(bitPattern: ...) }` correctly suppressed recursion sites, but did NOT suppress SLI bridging bodies in `extension UnsafeBufferPointer`, `extension Collection`, etc., where the `.underlying` unwrap is the legitimate direct-dispatch pattern. AST cannot mechanically discriminate "consumer call site (anti-pattern)" from "SLI bridging body (legitimate)" without type info. Outcome: rule file + test file deleted; outcome record at `swift-institute/Audits/PROMOTE-INFRA-020a-2026-05-22.md` (Audits commit `787086b`); `[INFRA-020]` annotated `Lint enforcement (DEFERRED, mechanization attempted 2026-05-22)` (Skills commit `72d63c1`).

**Test verification** (post-session, before push): `swift test` across 6 packages — cardinal (41/41), ordinal (58/58), affine (86/86), sequence (164/164), storage (202/202), hash-table (27/27). 578/578 tests pass across the work-touched packages. swift-buffer-primitives has 9 pre-existing `'buffer' used after consume` test compile errors in Buffer.Ring.Small / Buffer.Ring.Inline / Buffer.Linked.Inline — NOT caused by this session (verified via git blame: test files byte-identical to origin/main; my buffer commits only touch Buffer.Aligned + Buffer.Arena.Inline). Handed off to a fresh session via `HANDOFF.md` describing the 9 sites and the borrowing-accessor fix path.

**Memory note saved**: `feedback_check_package_resolved_before_compiler_bug_claim.md` — codifies the "check Package.resolved first before claiming compiler bug" diagnostic discipline.

## What Worked and What Didn't

**Worked**:
- The Tier 1 / Tier 2 / Tier 3 placement framework from the Cardinal arc transferred cleanly to Ordinal and Affine. Same shape, same decision tree, same commit boundaries.
- Parallel agent fan-out for bulk consumer migration was fast and reliable. The agents correctly applied the same mechanical transformation across 13 packages without conflicts, surfaced consistent SLI gaps (UInt32 from Ordinal; stride-aware pointer + count), and respected parallel-work guardrails (Agent C correctly skipped pre-existing WIP in dictionary/heap packages without prompting).
- The `/experiment-process` skill's iteration loop bounded the misdiagnosis investigation — without it, the "build minimal reproducer, see if it reproduces" cycle could have run indefinitely. The negative result (refuted) had to be documented as a result, not hidden, per `[EXP-011a]`.
- User redirected the investigation in one prompt ("is it perhaps resolving against main/origin for cardinal? is this an issue with our swift package mirror setup?") after watching the investigation hit dead ends. Externalizing the "what dep state is the consumer actually building against?" question caught the misdiagnosis in seconds.
- The `lint-rule-promotion` pipeline's Phase 6 validation ladder did its job — REVERT was the right outcome, surfaced cleanly via "findings concentrated on specific packages AND all on intra-module patterns the rule was not meant to catch" (branch 3 signal). Skill says: "Don't treat a REVERT outcome as a failed promotion. A REVERT under branch 3 of the iteration loop means the validation ladder caught a wrong-shaped rule before it shipped — exactly what the ladder exists for."
- Confidence calibration during investigation: I was high-confidence the bug was a real Swift compiler issue based on the handoff's framing; that confidence collapsed only when the user externalized the alternative hypothesis. The collapse was correct (the alternative was right) and fast (one prompt). Lesson: when high-confidence on "I know what the bug is" + multiple investigation paths exhaust without reproduction, the bug-identification itself is the load-bearing claim to re-check.

**Didn't work**:
- Misdiagnosis cost: ~2 hours building a multi-variant reproducer that could never reproduce, because the reproducer was being built against current local cardinal-primitives (with the SLI overloads) while the production failure was against pinned old cardinal-primitives (without them). Should have checked `Package.resolved` BEFORE writing the first reproducer variant. The reproducer-vs-production divergence is exactly the case `[EXP-011]`'s "workaround validation trap" warns about, applied to bug-reproduction in reverse: the reproducer was VALIDATING the bug doesn't exist in the current SLI, while production was running against an OLD SLI.
- The `[INFRA-020a]` lint rule promotion got to Phase 6 validation before discovering the carve-out problem. The Pass C(2) "discrimination tightness" check identified the *known* false-positive shapes (Int.init recursion; custom-type accessor) but did NOT anticipate the much-larger false-positive class (SLI bridging bodies — 82 sites vs the carve-out's 3). Earlier inspection of the AST findings against a representative SLI package (cardinal-primitives) in Phase 1 would have caught the issue before writing 120 lines of visitor code + 10 tests.
- The handoff's "Dead Ends" framing of "protocol-level placement sidesteps the resolution failure" was an over-confident causal claim from the original consolidation arc (commit `3ffa3cd`). The actual cause of the original failure was almost certainly the same Package.resolved staleness issue. The consolidation is still correct on its own merits (broader reach, single overload covers Array/ContiguousArray/ArraySlice/String/Substring), but the rationale-as-recorded was wrong. Research doc updated.

## Patterns and Root Causes

Three reusable patterns surfaced.

### Pattern 1: Stale Package.resolved as a "Swift compiler bug" disguise

When a consumer package fails to find a typed overload from an upstream SLI, the symptoms read identically to "Swift compiler overload resolution failure":
- Compiler picks stdlib int form, complains `cannot convert Cardinal to Int`.
- Warning: `public import of <SLI> was not used in public declarations or inlinable code`.
- Symptom persists across clean rebuilds (`rm -rf .build`).
- Symptom is context-specific (only fires in `~Copyable Self` extension context, etc.).

All four indicators ARE consistent with a Swift compiler bug. They are ALSO consistent with the SLI module not actually containing the typed overload (which is the case when Package.resolved pins to an older upstream revision). The two hypotheses are observationally indistinguishable until the dependency-resolved-revision is inspected.

**The cost asymmetry**: Inspecting `Package.resolved` against `<upstream>/git rev-parse main` is one shell command, ~1 second. Building a multi-variant minimal reproducer to characterize a Swift compiler bug is hours. The asymmetry is decisive — Package.resolved inspection should be the FIRST step whenever an upstream SLI overload "silently doesn't resolve" in a consumer. Memory entry codified; skill rule candidate for `existing-infrastructure` or `swift-package-build`.

### Pattern 2: Generic protocol overload's primary value is NOT bulk cleanup

The three `Int.init(bitPattern: some Carrier.Protocol<X>)` overloads landed expecting to clean up ~100 sites of `.underlying` / `.cardinal` / `.ordinal` / `.vector` accessor chains workspace-wide. Per-package inspection found: 9 chained-accessor sites total across the entire workspace (subtracting tests, SLI internals, intentional bridge bodies).

The actual value was different: existing call sites of shape `Int(bitPattern: typedValue)` (already in the codebase, written when the Cardinal was the only conformer and the per-type `Int.init(bitPattern: Cardinal)` existed) suddenly started RESOLVING cleanly with Tagged values too. The new generic overload caught a category of "would have to be written awkwardly" that callers had been writing as `Int(bitPattern: tagged.underlying)`.

This is a general pattern for SLI generic overloads: **the migration count understates the value because it counts only the CLEANUP**. The bigger value is the "calls that now type-check that didn't before" — which by definition can't be migrated because they didn't exist as call sites until the overload landed.

### Pattern 3: AST-based lint rules struggle with "legitimate bridging body" discrimination

`[INFRA-020a]`'s REVERT highlights a recurring class: lint rules that detect a pattern (`Int(bitPattern: X.<accessor>)`) cannot always distinguish:
- **Consumer call site (anti-pattern)**: the accessor is unwrapping a typed value to call a sibling stdlib API. Stripping = cleanup.
- **SLI bridging body (legitimate)**: the function IS the bridge from typed-Carrier to bare-type stdlib API; the accessor is the load-bearing unwrap.

The discrimination requires type info (does the receiver conform to the relevant Carrier.Protocol?) AND module/file context (is the file an SLI integration?). AST alone has neither.

Re-promotion criteria for `[INFRA-020a]`: (a) semantic-aware linting infrastructure, OR (b) explicit `@_sliBridge` annotation pattern on SLI bridging bodies, OR (c) refactor SLI bodies to typed-direct dispatch (two-hop, compiler-inlined) — making the SLI bodies themselves match the rule's intent. Option (c) is the cleanest path; it makes the bridging bodies consistent with consumer-facing usage, at the cost of one extra inlined dispatch hop. Re-promotion of `[INFRA-020a]` becomes viable after that refactor.

## Action Items

- [ ] **[research]** swift-cardinal-primitives or new doc — "SLI overload body dispatch shape": typed-direct (two-hop, compiler-inlined) vs unwrapped-direct (one-hop, explicit `.underlying`). Includes empirical benchmark (release-mode) on a hot-path SLI call, and the implication for `[INFRA-020a]` re-promotion. Resolution unlocks the lint rule.
- [ ] **[skill]** existing-infrastructure or swift-package-build — codify the "check Package.resolved revision against upstream local HEAD before claiming a Swift compiler overload-resolution bug" diagnostic as a `[PREFIX-NNN]` rule (currently only in memory `feedback_check_package_resolved_before_compiler_bug_claim`). The promotion gives the rule a durable IDed home and lets a future `/promote-rule` invocation consider it for mechanization (workflow-validator candidate: a script that diffs consumer Package.resolved against upstream HEAD on workspace-resolution-stress symptoms).
- [ ] **[skill]** lint-rule-promotion — extend Phase 1 Pass C(2) discrimination check with a "validation-spot-check on a representative SLI module BEFORE Phase 3 implementation" sub-step. The check would catch SLI-bridging-body false positives at triage rather than at Phase 6 validation (saves ~120 lines of visitor + ~10 tests + ~30 minutes of validation work per REVERT). Provenance: this session's `[INFRA-020a]` pilot.

## Handoff Cleanup (per [REFL-009])

Workspace handoff scan:

| File | Triage outcome |
|------|----------------|
| `/Users/coen/Developer/HANDOFF.md` (new — buffer-primitives test fix) | Annotated as ACTIVE in-flight; leave for the resumption-prompt fresh-session dispatch |
| `/Users/coen/Developer/HANDOFF-cardinal-sli-overload-expansion.md` (renamed from this session's source HANDOFF.md) | All work complete (verified via git log + tests + research DECISION update); deleting per [REFL-009] |
| ~33 other `HANDOFF-*.md` files at workspace root | Out of this session's cleanup authority (not authored or actively worked this session); leave unchanged |

The Cardinal SLI handoff is deleted (work complete, supervisor ground-rules block was absent so no [SUPER-011] gate applies). Git preserves history if needed.
