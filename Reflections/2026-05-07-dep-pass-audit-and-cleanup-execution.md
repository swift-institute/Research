---
date: 2026-05-07
session_objective: Execute the swift-primitives dependency-pass audit (UNUSED + REDUNDANT + SPLIT-candidate identification across 136 packages), then clean up the safest UNUSED dep declarations
packages:
  - swift-primitives/swift-region-primitives
  - swift-primitives/swift-affine-primitives
  - swift-primitives/swift-algebra-field-primitives
  - swift-primitives/swift-algebra-group-primitives
  - swift-primitives/swift-handle-primitives
  - swift-primitives/swift-affine-geometry-primitives
  - swift-primitives/swift-dimension-primitives
  - swift-primitives/swift-geometry-primitives
  - swift-primitives/swift-algebra-modular-primitives
  - swift-primitives/swift-cpu-primitives
  - swift-primitives/swift-dependency-primitives
  - swift-primitives/swift-index-primitives
  - swift-primitives/swift-io-primitives
  - swift-primitives/swift-layout-primitives
  - swift-primitives/swift-slab-primitives
  - swift-primitives/swift-string-primitives
status: processed
processed_date: 2026-05-07
triage_outcomes:
  - type: informational
    target: modularization
    description: "[MOD-025] Dep-Cleanup-Pass Audit Procedure already-captured during cohort"
  - type: informational
    target: swift-institute/Research
    description: "sub-product-split-decision-rubric.md already-captured during cohort"
  - type: informational
    target: modularization
    description: "[MOD-024] Test Support spine-completion gap already-captured in [MOD-025] (e) + Spine-completion gap section"
---

# Dep-Pass Audit and Cleanup Execution: Audit-Tool Bugs and Framework Corrections

## What Happened

Wrote a Python audit (`/tmp/dep_audit.py`) that parsed each Package.swift's `.product(...)` declarations, scanned source imports, computed @_exported chains, and classified each dep as UNUSED / REDUNDANT / SINGLE-MODULE-USE. Initial run produced 47 UNUSED findings, 50 REDUNDANT, 36 SPLIT candidates — the SPLIT candidates ranked by external-consumer count.

User rejected the SPLIT framework. All five top candidates (Buffer Linear, Binary Serializable, Memory Pool, Async Channel, Ownership Borrow) were sibling variants of their parent packages, not separate domains. The framework was downstream-driven (consumer count) where the LEB128 precedent it claimed to follow is upstream-pruning-driven (would the candidate's transitive dep tree shrink dramatically if extracted, AND would the surviving deps be in a different domain?). For LEB128 the answer was yes — pre-split it sat under Binary Primitives Core's 7-dep substrate, post-split it needs only Binary Namespace. For Buffer Linear / Memory Pool / Async Channel / Ownership Borrow / Binary Serializable, the answer was no — each still needs its parent package's Core. Saved `feedback_split_upstream_not_downstream.md`.

User added a hard rule: NO packages or modules may be removed during pre-1.0 dev; "no consumers" is a worthless removal metric. Saved `feedback_no_removal_during_development.md`. Cleanup scope narrowed to Package.swift dep DECLARATIONS only — line-item edits, not package or target removal.

Started cleanup with swift-region-primitives (1 module, single UNUSED finding for Position Primitives). Edit + clean build + 98 tests passed. Approach validated.

Continued in three batches across 16 packages total:

| Round | Packages | UNUSED removed |
|-------|----------|----------------|
| 1 | swift-region, swift-affine, swift-algebra-field, swift-algebra-group, swift-handle | Position, Property, Algebra, Algebra, Ownership |
| Batch A | swift-affine-geometry, swift-dimension, swift-geometry | Format Primitives ×3 |
| Batch B | swift-algebra-modular, swift-cpu, swift-dependency, swift-index, swift-io, swift-layout, swift-slab, swift-string | Tagged, Bit+Dimension, StdLibExt, Property, StdLibExt, Position, StdLibExt+Ownership, ASCII |

Each verified by clean `.build` + `swift build` + `swift test`. Two had pre-existing test failures unrelated to the dep edits, confirmed by stash-and-rerun on `main`: swift-handle (~Copyable + #expect macro), swift-geometry (Tagged Strideable / Area).

**Four audit-tool bugs caught mid-flight, each via individual case verification:**

1. **Regex matched commented-out `// .product(...)` lines** — caught at swift-locale-primitives, where the "UNUSED" `ASCII Primitives` was already commented out as a TODO marker. Fix: skip lines whose first non-whitespace is `//`. 5 false positives eliminated.
2. **UNUSED check didn't follow @_exported chains** — caught at swift-binary-base-primitives, which declares `Property Primitives` umbrella, but source imports `Property_Primitives_Core` via the umbrella's @_exported chain. Fix: a dep is USED if any module in its `provides_per[i]` set appears in `all_imports`.
3. **`.package(url: ...)` deps weren't resolved** — compounded with #2; binary-base uses url-form for swift-property-primitives. Fix: extract repo basename from URL and look up in workspace package map.
4. **`Tests/<TargetName>/` directories weren't scanned for imports** — caught at swift-array-primitives (Tagged SLI imported in `Array.Small Tests.swift` testTarget). Fix: scan all subdirectories of `Tests/` recursively, not just `Tests/Support/`. Several SLI false positives eliminated.

After fixes, the audit produced 19 strict-UNUSED findings across 14 packages. User then noted that 6 of those were TS-spine deps (Token TS in lexer, 4 TS deps in memory, Array TS in parser) that must stay per [MOD-024] Test Support spine discipline. Spine deps may legitimately not appear in literal imports because the `@_exported public import` re-export from exports.swift may simply be missing — that's a spine-completion gap (FIX by adding the re-export), not a removal candidate. Saved `feedback_test_support_spine_keep.md`. Final cleanup target: 13 findings across 11 packages, all completed in batches A+B.

Tightened the audit's "uniquely-providing-dep" check (a dep is REQUIRED iff some imported module's coverage set is exactly `{i}` — i.e., it's the unique provider). REDUNDANT was split out as a separate class for findings where a dep reaches imports but every reach is covered by another declared dep. Per the user's policy, REDUNDANT findings stay under the new used-only rule.

Three feedback memories saved this session: `feedback_split_upstream_not_downstream.md`, `feedback_no_removal_during_development.md`, `feedback_test_support_spine_keep.md`. Plus `feedback_dep_declarations_used_only.md` saved earlier in the session.

**Artifacts triaged**:
- `/Users/coen/Developer/AUDIT-dependency-pass.md`: in-session-scope. Annotated with the framework-correction reframing section and the "Single-module-use reframing — upstream-pruning categorization" section. The audit's findings are durable knowledge (the structural-pattern categorization of the 48 single-module-use cases under the corrected framework). Left in place at workspace root; promotion to `swift-institute/Audits/` is plausible but out-of-session — no instruction from the user to relocate.
- `/Users/coen/Developer/HANDOFF*.md`: 38 files at workspace root, all out-of-session-scope (none authored or worked this session, no completion signals encountered via incidental work). Per [REFL-009] bounded-cleanup-authority, left untouched.

## What Worked and What Didn't

**Worked**:
- Empirical "edit + clean build + test" pattern validated each cleanup at the cheapest point. Two pre-existing test failures surfaced as on-`main` via `git stash`, not caused by my edits.
- The user's rejection of the initial SPLIT framework was load-bearing. Without it the published recommendations would have violated [MOD-003] variant-decomposition. The correction was both spec-gap (downstream vs upstream signal) and tool-bug (audit's strength signal was wrong).
- Per-case verification (greping for the imported module BEFORE editing) caught audit bugs incrementally. The @_exported chain bug surfaced at swift-binary-base-primitives because the grep returned hits for `Property_Primitives_Core` even though the audit said "UNUSED Property Primitives." The grep is the bug-detector; the audit is the candidate-generator.

**Didn't work**:
- Published the SPLIT-candidates ranked list before internal sanity-check. Should have surfaced "these are all sibling variants in their parent packages along the same decomposition axis" as a self-critique before recommending. The "domain-coherence" heuristic in the audit was named correctly but used too loosely — checking only that the consumer module isn't `Core/Umbrella/SLI/Namespace/TestSupport` is far weaker than checking semantic-domain orthogonality. Per [REFL-006], the analysis stayed at Bloom's Apply level ("would this split work mechanically?") instead of pushing to Analyze ("what pattern do these all share?").
- Audit-tool bugs surfaced one at a time across hours. Each fix invalidated a chunk of prior findings. A more robust sequence: write the audit → run on 5 hand-verified packages → fix all detected bugs → run at scale. The "scale-first, debug-as-user-pushes-back" path cost extra cycles and shifted bug-detection burden to the user.
- I asked permission for each Bash invocation (rm -rf .build && swift build && swift test pattern). The user flagged the friction explicitly. Settings-side fix (out-of-scope for this reflection per the user's `/reflect-session` argument).

**Confidence calibration**: high confidence on UNUSED detection, low on SPLIT framework. Should have inverted — SPLIT recommendations are higher-stakes (multi-package coordination, IETF/ISO consumer impact, irreversible) and warrant a higher confidence bar. I treated SPLIT as a mechanical inventory output when it should have been a high-confidence-bar narrative recommendation with internal critique.

## Patterns and Root Causes

**Audit tools need empirical-state checks, not literal-name-match.** Three of the four bugs collapse to one root cause: my audit asked "does this exact name appear in source imports?" when the correct question is "would removing this dep break the build?" The build is the empirical state; literal-name-match is a brittle proxy. Each bug-case (commented-out lines, @_exported chains, url-form deps, testTarget directories) was a place where the proxy diverged from the state. The corrected check (uniquely-providing-dep) is closer to build-correctness but still an approximation. The truly correct check is the build itself, used as a verification gate per cleanup. The pattern generalizes: any "static analysis as cleanup gatekeeper" tool is a build-substitute that will have empirical-state divergences; the divergences must be caught either by the tool's logic or by post-hoc build verification, but cheap analysis MUST NOT be deployed as authority without the build-verification gate. This is [REFL-012]'s loop-counter principle (verify state, not the tool's claim) generalized to static-analysis output.

**Downstream signals do not decide domain splits.** The LEB128 precedent's recommendation was based on upstream-pruning (LEB128's algorithm needs only stdlib + bit arithmetic, not byte cursors → would survive as a tier-0 leaf with just Binary Namespace). My initial framework picked up "external consumer count" as the strength signal because it was tractable to compute. The user corrected: external-consumer count tells you about adoption-of-current-shape, not about whether the candidate-extracted package is a separate semantic domain. Buffer Linear has 15 external consumers but is still a sibling variant of Buffer Ring/Slab/Linked along the [MOD-003] storage-strategy axis. Its unique Collection Primitives dep is [MOD-004] Constraint Isolation, not a domain-split signal. Generalization: when a framework can pick from multiple signals (downstream count, upstream pruning, structural axis, capability-rent), the decisive signal is the one that maps onto the design question (what makes a separate domain?), not the one that's easiest to compute.

**Test Support spine deps look "unused" because @_exported chains may be incomplete.** [MOD-024] requires TS shells to `@_exported public import` upstream TS. When the re-export is missing from a TS shell's exports.swift, the dep declaration in Package.swift stands alone — no literal import, no @_exported reference. My audit flagged these as UNUSED. The user corrected: this is a spine-completion gap (FIX by adding the re-export), not a cleanup target (DROP the dep). The asymmetry is structural — TS spine is a positive-construction discipline (deps exist for the spine to function as upstream-fixture conduit) where my literal-import scan is a negative-cleanup discipline (deps without imports are removable). Negative-cleanup tools must be aware of positive-construction patterns they may misclassify; otherwise they cause regressions when applied.

**User correction signal is high-credence on framework AND on individual findings.** Three rejections this session: the SPLIT framework, the locale dep ("already commented out"), and the lexer Test Support dep ("spine stays"). Each caught a real bug or framing error. Pattern: when the user pushes back on a specific case, re-examine the tool/framework FIRST, not the case. The tool is more likely wrong than the user's intuition about a familiar package. This extends `feedback_user_intent_over_principal_tangents.md` to framework critique: user feedback on the framework supersedes mechanical-tool output, and should trigger tool-bug investigation before per-case argument.

**Iterative bug-finding via per-case verification was structurally enforced by the cleanup workflow.** The session shape — pick candidate → grep for module → edit → build → test → next — used the grep step as a bug-detector. Three bugs surfaced one at a time, each via the next case. If I had skipped per-case verification ("audit said X, edit X"), each bug would have been a build failure (catchable but more expensive than grep). If I had front-loaded verification on 5 hand-picked packages before scale, the bugs would have surfaced in 30 minutes instead of distributed across the session. The workflow's "verify-then-edit-then-build" pattern is the right shape, but the audit-tool development sequence ("scale-first") was wrong.

## Action Items

- [ ] **[skill]** modularization: Add a `Dep-Cleanup-Pass Audit Procedure` requirement codifying (a) UNUSED check uses uniquely-providing-dep logic (a dep is REQUIRED iff some imported module's coverage set is exactly `{i}`), not literal-name-match; (b) regex must skip commented `// .product(...)` lines; (c) `.package(url: ...)` deps are resolved by repo-basename → workspace package map lookup; (d) `Tests/<TargetName>/` AND `Tests/Support/` are both scanned recursively; (e) `* Test Support` deps on `* Test Support` targets are excluded per [MOD-024] spine; (f) every cleanup is gated by `rm -rf .build && swift build && swift test` per [REFL-012] state-verification.

- [ ] **[research]** Sub-product split-decision rubric for swift-primitives: a written rubric resolving three competing signals (upstream-pruning, structural axis [MOD-003], capability rent [MOD-RENT]) with explicit priority order. Should answer: when does a sibling variant become a split candidate? The Buffer Linear / Memory Pool / Async Channel cases each pass at least one signal but fail on the prioritized one — codifying the priority would have prevented this session's misframing. Output: `swift-institute/Research/sub-product-split-decision-rubric.md`.

- [ ] **[skill]** modularization: Document the [MOD-024] Test Support spine-completion gap pattern. When a `* Test Support` target declares a dep on `* Test Support` from a sibling package but the shell's `exports.swift` does NOT have a corresponding `@_exported public import`, that's a spine gap to FIX (add the re-export), not a UNUSED candidate. Add detection grep heuristic and the FIX-not-DROP disposition rule.
