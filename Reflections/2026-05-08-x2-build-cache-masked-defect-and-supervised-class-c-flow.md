---
date: 2026-05-08
session_objective: X2 pre-tag remediation for swift-linter (10 forums-review-derived items A–J) — uncovered class-(c) escalation when clean-build gate exposed pre-existing upstream-state divergence.
packages:
  - swift-foundations/swift-linter
  - swift-foundations/swift-posix
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [RELEASE-001c] Phase 0 Baseline Build MUST Use rm -rf .build Clean State (entry 7 AI 1; Memory.Page to System.Page upstream-state divergence worked example; closes the gap symmetrically with [RELEASE-001a]/[RELEASE-001b]). SkillUpdate [SUPER-039] Class-(c) Trigger for Build-Gate Failure from Upstream-Package State Divergence (entry 7 AI 2; codifies the trigger so subordinate routes directly to escalation). NoAction SwiftPM incremental cache invalidation research deferred (research candidate; useful but not blocking).
---

# X2 — Build-Cache-Masked Defect and the Class-(c) Escalation Flow

## What Happened

The dispatched task was bundled remediation of 10 forums-review-derived items (A–J) for swift-linter at HEAD `a55c7f0`. Phase A was 5 real defects (README worked-example reconciliation, silent-fallback CLI diagnostic, single-file `Lint.swift` inert framing, `nonUTF8` declared-but-never-thrown resolution, comparison-table rewrite); Phase B was 5 defensive-or-additive items (wire-key stability paragraph, SemVer commitment, cohort-shape rationale, `Source.Manager` retain-all doc-comment, `Lint.Manifest: Hashable`).

Items D and E required verify-before-write per Constraint #6. Item D's verification (`grep -rn "throw .nonUTF8"` across `Sources/` and `Tests/`) returned exactly one match — the case declaration itself. Zero throw sites confirmed; the case was unreachable. I converted the lossy decode at `Lint.Run.swift:137` to `String(validating: bytes, as: UTF8.self)` (Swift 6.3.1 stdlib; type-checked clean via a `swiftc -typecheck` spike) and made `Lint.Run.Error.nonUTF8(path:)` reachable on invalid UTF-8 input.

Item E's verification used `gh` CLI (per the WebFetch skill's "prefer gh for GitHub URLs" guidance) against `swiftlang/swift-format` and `realm/SwiftLint`. Both upstream claims confirmed substantively: swift-format has a `lint` subcommand (not a `--lint` flag — minor wording correction) and 43 entries in `Sources/SwiftFormat/Rules/`; SwiftLint's README states "rules are predominantly based on SwiftSyntax" with `analyzer_rules` "an entirely separate list ... only run by the `analyze` command. All analyzer rules are opt-in." The forums-review's framing of SwiftLint as "regex / token patterns over source text" was an under-description of upstream's primary mode, but the substance (AST coverage exists, posture differs from swift-linter) was correct. No class-(c) escalation triggered for E.

All 10 items were applied. Item J's hypothesized location (swift-linter-primitives per `Audits/audit.md:231` reference) turned out stale — `Lint.Manifest` actually lives in `swift-linter/Sources/Linter Core/Lint.Manifest.swift`. Bundle stayed within swift-linter scope; no swift-linter-primitives edit needed. Hashable was auto-synthesized.

**The class-(c) escalation surfaced at the clean-build gate**. Constraint #2 mandated `rm -rf .build && swift build && swift test` before commit. The fresh clean-build hit:

```
swift-posix/Sources/POSIX Kernel Memory/POSIX.Kernel.Memory.Page.swift:22:36:
error: 'Page' is not a member type of enum 'Memory_Namespace.Memory'
```

This was unexpected — the D5 release-readiness brief (authored 2026-05-08, same day) explicitly stated "Build complete! (152.65s); zero errors; warnings only" at HEAD `a55c7f0`. To distinguish "X2 introduced this" from "pre-existing", I ran the verification methodology of `git stash push` of the X2 changes followed by another `rm -rf .build && swift build`. The same failure reproduced at clean baseline. **The defect predated X2.**

Sibling reflection (`2026-05-08-two-l1-layer-reversals-system-and-iso.md`, also written today) documents that `Memory.Page` had been deliberately removed from swift-memory-primitives as part of the Memory ⇄ System layering reversal (relocation to `swift-system-primitives` as `System.Page`). swift-posix's `POSIX.Kernel.Memory.Page = Memory.Page` typealias still pointed at the removed home — fallout from the upstream layering reversal that swift-posix had not yet caught up to.

Per Ground Rule #6 (and per `feedback_escalate_inline_not_askuserquestion` — supervisor escalations are inline markdown text the user forwards, not AskUserQuestion), I surfaced an inline class-(c) escalation enumerating three options: scope expansion to fix swift-posix, accept-as-known with skip, or alternative direction. The principal authorized scope expansion to **swift-posix only** with strict mechanical-fix bounds and STOP-and-surface conditions for any further fallout.

Execution of the authorized procedure:

1. Located `System.Page` at `swift-system-primitives/Sources/System Primitives/System.Page.swift:30` and confirmed `extension System.Page { public typealias Size = Tagged<System.Page, Cardinal> }` at line 45.
2. Grepped swift-posix for `Memory.Page` references — exactly 3 matches, all in the same file (`POSIX.Kernel.Memory.Page.swift`), one substantive line plus two comment lines. Grepped the workspace for downstream consumers of `POSIX.Kernel.Memory.Page` — zero matches outside the declaration itself. The typealias was effectively unconsumed.
3. Edited that one file: target retargeted from `Memory.Page` → `System.Page`; comment block updated to reflect the new canonical home (System.Page in swift-system-primitives) and the layering-reversal context. `System_Primitives` was already in scope transitively via the existing `public import ISO_9945_Kernel_Memory` (which re-exports `ISO_9945_Core` which re-exports `System_Primitives`); no new imports needed.
4. swift-posix isolated clean-build: green (50.92s, 20 tests in 6 suites pass).
5. swift-linter clean-build via the fixed transitive dep: green (196.84s, 10 tests in 7 suites pass).
6. Resumed X2 cascade: 4 commits in swift-linter (README polish bundled per the brief's explicit OK; item B; items D+I co-edit on `Lint.Run.swift`; item J), 1 separate commit in swift-posix.
7. After both per-action authorizations (`YES PUSH WAVE X2` for swift-linter, `YES PUSH swift-posix-page-fallout` for swift-posix), pushed both repos. Both confirmed in-sync with origin/main.

Total: 10 X2 items + 1 swift-posix fallout fix = 5 commits; 11 acceptance criteria verified; one principal-authorized scope expansion executed within strict bounds.

## What Worked and What Didn't

**Worked**:

- **Stash-test as escalation-evidence**: `git stash push` + clean rebuild reproduced the failure without my changes. This converted "I think the defect is pre-existing" into "I have a verifiable demonstration." The principal's three-option enumeration could be authoritative because the evidence was concrete.
- **Inline escalation in markdown** (per `feedback_escalate_inline_not_askuserquestion`): the principal-relay flow read the escalation, forwarded it to the principal, and returned a clean authorized procedure. No AskUserQuestion ceremony; no premature decision; the question reached the right authority with the right framing.
- **Verify-before-write discipline for items D and E**: both verifications produced concrete evidence I could cite in commit messages and Implementation Notes. Item D's grep confirmed PR15's audit finding. Item E's `gh` substitution turned the forums-review's UNVERIFIED claims into substantively-confirmed facts before the README rewrite went in.
- **Same-file commit bundling per the brief's allowance**: items D and I both touched `Lint.Run.swift` (decode + retain-all doc-comment), so they shared a commit. The brief's explicit OK for README bundling let me consolidate items A, C, E, F, G, H into one commit, keeping the swift-linter ahead-count to 4 instead of 9.
- **Bounded mechanical fix in swift-posix**: the principal's procedure constrained the fix to one substantive line + comment refresh. Zero downstream consumers (verified via grep), zero upstream-definition edits, zero further fallout-sweep beyond swift-posix. The fix did exactly what was authorized; nothing more.

**Didn't work — process friction**:

- **Build-output exit-code interpretation**: my first clean-build attempt (with `2>&1 | tail -25` truncating output) made it hard to distinguish "build cancelled by some external interrupt" from "build failed with compile errors." Several follow-up attempts were needed before I separated the streams cleanly and saw the actual error. Lesson: when verifying a clean-build green/red signal, capture the FULL log to a known path (`> /tmp/foo.log`) and inspect with `grep` — never `tail -N` away from the error.
- **Background-process residue**: an initial `swift build` running in the background interfered with my synchronous clean-build re-run. Required `pkill -9 -f "swift build"` to clear before the verification pass became reliable. Lesson: when a verification pass requires a clean state, kill any prior background swift builds first.

**Didn't work — premise-staleness in the brief**:

- The brief hypothesized `Lint.Manifest` lived in swift-linter-primitives (per `Audits/audit.md:231` reference). Verified false — `Lint.Manifest` lives in swift-linter itself. The brief's premise was carried forward without verification; I caught it via grep before touching the wrong package. The audit.md reference was either captured before a relocation or always pointed at the swift-linter Linter Core target. **Lesson**: every "MUST verify-before-write" item in a brief should be verified, including the premises about WHERE the type lives.
- The D5 release-readiness brief stated "Build complete!" 2026-05-08 morning. That verification used the existing `.build/` cache — incremental SwiftPM build that retained Memory.Page resolution from before its removal. The X2 dispatch's `rm -rf .build` requirement is what surfaced the divergence. The brief's "clean-build" verification, in retrospect, was not a clean build.

## Patterns and Root Causes

**Pattern 1: Build-cache state divergence as a release-readiness anti-pattern.** The D5 brief and the X2 dispatch ran the same `swift build` command on the same HEAD against the same dep graph but produced different results — green vs red. The difference was `rm -rf .build`. SwiftPM's incremental build cache evidently retained Memory_Namespace's symbol table from before Memory.Page was removed; the consumer site (swift-posix's typealias) compiled against the stale cached symbol table without re-resolving against current upstream state. A pre-tag readiness brief that doesn't `rm -rf .build` is verifying against a moment-in-time cache that may pre-date upstream changes the consumer hasn't caught up to.

The supervised-dispatch model surfaced this because Constraint #2 mandated the clean-build. The brief's own self-verification did not. **The cohort missed a class of pre-tag defects between brief-write and dispatch-execute.** Codifying `rm -rf .build` in the brief's own Phase 0 baseline closes the gap symmetrically.

**Pattern 2: Class-(c) escalation triggers should enumerate gate-blocking, not just item-scope-expansion.** The X2 brief's class-(c) trigger list named:
1. Item D verification reveals `nonUTF8` IS thrown somewhere.
2. Item E verification reveals upstream claims wrong.
3. Items J or I require changes BEYOND swift-linter and swift-linter-primitives.
4. Item B's silent-fallback fix requires a public-API change beyond the institute-internal layer.

None of these literally fired for the build-gate failure. The defect was in swift-posix (a transitive dep, not an item J/I site); the fix would expand scope, but not as an item-shape change — as a gate-blocking-from-upstream pattern. **The SPIRIT of "scope expansion is principal-territory" applied** even though the LETTER didn't.

This is the [SUPER-027] discipline (pre-dispatch ecosystem-constraint scan) operating in reverse: at execution time, a constraint the brief didn't enumerate surfaces, and the subordinate must derive the spirit-vs-letter call. Codifying "build-gate failure due to upstream-package state divergence" as an explicit class-(c) trigger removes the derivation from the next subordinate's path. The pattern WILL recur — multi-package cohorts have continuous upstream churn; cache-masked divergence is the natural failure mode at clean-build verification time.

**Pattern 3: Unconsumed typealias as a low-cost-to-fix failure shape.** The swift-posix fallout was minimal because:
- The typealias `POSIX.Kernel.Memory.Page` had zero downstream consumers (verified by grep across the workspace).
- The typealias's name (`POSIX.Kernel.Memory.Page`) didn't change — only its resolution target.
- The L1 layer move from swift-memory-primitives to swift-system-primitives was fully accommodated by the new home being a drop-in replacement (`System.Page` namespace + `System.Page.Size` Tagged).
- `System_Primitives` was already in transitive scope via existing imports; no new dep needed.

These four properties together explain why the fix was one substantive line. If any one were different — say, downstream consumers existed, or the new home had a different shape, or a new dep was needed — the fallout would have cascaded across multiple files or packages. The minimal-mechanical-fix bound the principal authorized was correct precisely because the underlying property landscape supported it.

**The lesson for similar future cascades**: before authorizing scope expansion, the principal (or the subordinate surfacing the escalation) should enumerate the four properties — consumer count, name continuity, shape compatibility, transitive-dep visibility. When all four favor a minimal fix, mechanical-bound expansion is safe. When any are unfavorable, the fix is larger and the authorization should reflect that.

## Action Items

- [ ] **[skill]** release-readiness: Add a `[RELEASE-*]` sub-rule requiring `rm -rf .build` in the Phase 0 baseline build-verification of release-readiness briefs ([RELEASE-001]). The D5 brief reported "Build complete!" 2026-05-08 against an incremental cache that masked the Memory.Page → System.Page upstream-state divergence; the X2 dispatch's clean-build requirement surfaced it pre-tag. Codifying `rm -rf .build` in the brief's own self-verification closes the gap symmetrically — without it, a brief can carry stale-cache risk into per-action authorization. Cite the X2 swift-posix fallout as the worked example.

- [ ] **[skill]** supervise: Codify a class-(c) trigger sub-rule extending [SUPER-005] / Ground Rule #6: "build-gate failure due to upstream-package state divergence (a transitive-dep defect outside the subordinate's authorized package set, surfaced during clean-build verification) MUST be treated as class-(c) escalation even when no item-scope-expansion trigger fires literally." Currently the trigger list enumerates item-shape changes; gate-blocking-from-upstream is a different shape and the spirit-vs-letter derivation is on the subordinate. Codifying the trigger removes the derivation — the next subordinate hitting this pattern can route directly to escalation. Cite the X2 swift-posix fallout as the worked example.

- [ ] **[research]** Investigate SwiftPM's incremental build cache invalidation boundary across cross-package dep changes. Specifically: at what events does the cache invalidate downstream resolution when an upstream package removes or relocates a public type? The D5 brief's `swift build` (without `rm -rf .build`) did not re-resolve `Memory_Namespace.Memory.Page` after the upstream removal; the failure surfaced only on clean rebuild. Worth understanding the cache's behavior at: (a) Package.swift changes vs source-only changes upstream; (b) `.swiftinterface` regeneration triggers; (c) whether `swift package resolve` followed by `swift build` would have caught it without nuking `.build/` entirely. Cheaper-than-clean-build verification options would benefit both release-readiness briefs and CI.
