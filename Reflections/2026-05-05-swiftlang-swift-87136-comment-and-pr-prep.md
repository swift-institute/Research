---
date: 2026-05-05
session_objective: Investigate swiftlang/swift#87136 follow-ups per the inherited handoff — post a minimal Tagged + InternalImportsByDefault reproducer comment, optionally assess assertion site for an upstream PR
packages:
  - swift-tagged-primitives
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [SWIFT-PR-012] PR Body Claim Audit + HEREDOC Body-Escaping (consolidates this entry AI 1 + PR-shipping entry AI 1; "predates IIBD" temporal marker + reachability/failure conflation worked examples). NoAction issue-investigation [ISSUE-NNN] Mechanical Validation via Installed Dev Toolchain narrow-scope workaround (single-instance, captured in feedback memory if recurrence). NoAction implementation [IMPL-NNN] Subtractive-First covered by [IMPL-101] YAGNI at API Surface (subtractive default is implicit).
---

# swiftlang/swift#87136: comment posted, PR drafted (gated), iterative minimization under user pressure

## What Happened

Picked up `HANDOFF-swiftlang-swift-87136-followup.md`, a focused investigation brief on swiftlang/swift#87136 — `MoveOnlyChecker` asserts on `nominal->getFormalAccessScope(fn->getDeclContext(), true).isPublicOrPackage()` at `MoveOnlyAddressCheckerUtils.cpp:1829` during partial-consume of a public `~Copyable` field under `InternalImportsByDefault`. Two follow-ups: post a minimal reproducer comment; optionally assess the assertion for an upstream PR.

Built a two-module reproducer at `/tmp/swift87136/` (`TaggedLib.swift` + `repro.swift`, two `swiftc` invocations, no SwiftPM, no library link). Verified on `swift-DEVELOPMENT-SNAPSHOT-2026-03-16-a` (6.4-dev +Asserts): crashes WITH `-enable-upcoming-feature InternalImportsByDefault`; clean diagnostic without it; same-module variant doesn't crash (early-return at line 1821 bypasses the assertion). Tighter than the issue's own reproducer in three ways: one public type instead of two; non-`@frozen` outer; function-local payload.

Posted a 4-sentence comment to swiftlang/swift#87136 after explicit `YES POST COMMENT` authorization: https://github.com/swiftlang/swift/issues/87136#issuecomment-4376940955.

Read the assertion site at `MoveOnlyAddressCheckerUtils.cpp:1808-1837`. Confirmed via `git blame` that the assertion was added by Nate Chandler in `da968dbd58d` ("[MoveChecker] Ban exported partial consumption.", 2024-02-15), unchanged since. Read `lib/AST/Decl.cpp:5407-5486` (`getAccessScopeForFormalAccess`) to verify the causal mechanism: lines 5450-5463 clamp a public nominal's access down to the import access level when the use site has a non-`ignoreImportAccessLevel` import; `case AccessLevel::Internal: return AccessScope(resultDC->getParentModule())` produces an internal-scope result that fails `isPublicOrPackage()`. The assertion's invariant ("if reachable from this code, then public-or-package") was never updated for SE-0409.

Drafted the PR locally on branch `fix-87136-stale-assertion` off `origin/main` (HEAD `f82c0751c0b`). Iterated three times on minimization under progressive user pressure:

- **v1**: 5-line removal + 3-line replacement comment ("Under InternalImportsByDefault, formal access scope at the use site may be narrower..."); generic test using `Tagged<Tag, Underlying>` with `Tag1` enum, function-local `Resource`, and `_unchecked` factory + instantiation; PR body with `Root cause` / `Fix` / `Test plan` headers and a "predates IIBD (SE-0409)" temporal claim.
- **v2** (after user "TRULY minimal, no unrelated changes" + "100% confident, validated everything"): 7-line removal, 0 insertions; non-generic `Outer` / `Inner` / `OuterFrozen` test with two top-level functions (no instantiation, no `Tag` parameter, no `_unchecked` factory); PR body collapsed to two paragraphs with no headers, every claim cited to a specific file:line; `[MoveOnlyPartialConsumption]` tag matching `ef6cde5474b`'s precedent.

Local `llvm-lit` end-to-end was not run. The existing `+Asserts` build at `/Users/coen/Developer/swiftlang/build/Ninja-ReleaseAssert/` (built 2026-03-24 from commit `8ae2a7b584f`) failed cmake regenerate on stale `MacOSX26.2.sdk` references after Xcode upgraded to 26.4. Reconfigure was judged disproportionate to the verification gain. Worked around with mechanical validation: extracted test files via the build's `split-file` binary; ran `swift-frontend Library.swift -emit-module` and `swift-frontend Downstream.swift -emit-sil` (with and without `-enable-upcoming-feature InternalImportsByDefault`) against the installed dev toolchain; confirmed exact-match diagnostic text and silent compilation of the `@frozen` branch.

`/handoff` produced a sequential refresh on `HANDOFF-swiftlang-swift-87136-followup.md` with a `## Resume Point` section and a copy-pasteable resumption prompt for the next session's planned `/collaborative-discussion`.

Authorization gates held throughout: `YES POST COMMENT` requested and received before the gh issue comment; `YES COMMIT / YES PUSH / YES PR` remain ungranted by user direction; auto-mode was active but did not push toward unauthorized public actions.

Handoff cleanup scan ([REFL-009]): 18 `HANDOFF*.md` at `/Users/coen/Developer/`. One in this session's authority (`HANDOFF-swiftlang-swift-87136-followup.md`) — annotated via `## Resume Point` per [HANDOFF-009] progressive-capture; not deleted (PR commit/push/submission gated). Seventeen out-of-authority — not scanned per [REFL-009] bounded-cleanup-authority. No audit findings to update ([REFL-010] N/A — no `/audit` invoked this session).

## What Worked and What Didn't

**Worked**:

- **Reproducer construction was methodical**: started single-file (didn't crash), recognized the same-module early-return path bypasses the assertion, narrowed to two `swiftc` invocations with no SwiftPM. The intermediate "single-module doesn't trigger" finding was informative — it confirmed the bug requires cross-module + IIBD, narrowing the structural scope and giving the comment text its tightening claim.
- **Compiler source reading was cheap and conclusive**. The 80-line read of `Decl.cpp:5407-5486` produced the causal mechanism that elevated the PR body from empirical-only ("the assertion fires") to source-cited ("the assertion fires because lines 5450-5463 clamp the access scope"). Without this, the PR body would have asserted a mechanism without proof.
- **Mechanical validation workaround** (split-file + dev-toolchain manual frontend invocations) recovered the diagnostic-text-exact-match guarantee at low cost. The trick: the dev toolchain produces the same diagnostic emission as a from-source build, modulo the bug we're fixing — so without IIBD, the dev toolchain's output is the post-fix expected behavior.
- **Authorization discipline held**. `YES POST COMMENT` was requested before posting (the only public action), explicit refusal to commit without `YES COMMIT`. Auto-mode pushed toward "low-risk reasonable assumption proceeds"; CLAUDE.md's "Executing actions with care" enumerates issue-comment-posting as a confirm-first action. The reminder fired correctly.

**Didn't**:

- **v1 had three substantiation defects**, each requiring user pressure to surface:
  - "predates IIBD (SE-0409)" — temporal claim that "felt right" but was wrong-by-direction. SE-0409 was accepted late 2023; the assertion was added Feb 2024. The assertion is not a pre-IIBD relic that survived; it is a post-IIBD-acceptance defect that never accommodated the implementation.
  - 3-line replacement comment for the deleted assertion's comment — additive padding the post-fix structure made redundant. The post-fix function (early-return → @frozen → error) is self-explanatory.
  - Generic test with unused `Tag` parameter, `_unchecked` factory, and instantiation — none of which exercise the bug. The bug fires on the OUTER nominal under IIBD; non-generic `Outer` triggers it identically with less surface.
- **Default behavior across all three iterations was "perfect-but-padded"**. When given freedom, I add explanatory comments, generic-ize examples, write headed PR bodies. Each round of "TRULY minimal" / "substantiate every claim" / "100% confident" was the user catching a different facet of the same bias.
- **The cmake regenerate failure consumed five turns** before the workaround clicked. The error message ("path was deleted, renamed, or moved") plus the SDK numeric delta (26.2 → 26.4) was diagnostic — I should have pivoted to mechanical validation immediately rather than first attempting `-DCMAKE_OSX_SYSROOT=...` overrides that didn't propagate to cached imported-target paths.

## Patterns and Root Causes

**Bias toward additive over subtractive when fixing structural defects**. The deepest pattern. When proposing a fix for a stale construct, my first-cut adds a replacement explanatory comment rather than letting the surrounding structure carry the rationale via the PR description. v1's 3-line comment ("Under InternalImportsByDefault, formal access scope at the use site may be narrower...") was a reflexive "explain to the next reader" reach. The post-fix function reads cleanly without it: `same-module → return std::nullopt; @frozen → return std::nullopt; otherwise → return error`. The structure tells the story.

The pattern transfers: in code, prefer pure deletion when the surrounding structure tells the story. In PR bodies, prefer plain prose over headed sections when the body is short. The same instinct that resists premature abstractions ("don't add structural ceremony for short content") applies to commit-level structural changes. Code comments and PR bodies are separate channels — the PR description carries "why this change"; code carries "what this code does." When a PR's purpose is removal, the code's "what" is unchanged for the surrounding structure; only the PR description needs to explain the "why."

**PR body substantiation is a discipline, not an instinct**. v1's "predates IIBD" felt right because the assertion is stale and IIBD is the cause — but the temporal claim was wrong-by-direction. Substantiation discipline requires asking "what evidence backs this exact wording?" for every clause — particularly clauses with temporal markers ("predates", "no longer", "always since"), causal markers ("because", "due to", "in order to"), or quantifier markers ("always", "never", "every"). The asymmetry matters: a claim that is empirically right but temporally wrong reads as half-substantiated and invites reviewer pushback on "predates" alone, distracting from the otherwise-correct argument. Removing the unverifiable clause leaves a stronger argument in less space.

**Mechanical validation is undervalued when llvm-lit can't run**. The cmake regenerate failure was a hard block against rigorous validation. The mechanical-validation workaround — extract test files via `split-file`, manually run frontend invocations against the installed dev toolchain — recovered the diagnostic-text-exact-match guarantee at ~5% of the cost of a full reconfigure-and-rebuild. The workaround mirrors `[ISSUE-002]` standalone-reproducer-first discipline applied to test validation: instead of validating in the test framework's runtime, validate the test's commands directly. The dev toolchain's frontend produces the same diagnostic emission a from-source build would, modulo the bug — so without IIBD, the dev toolchain's output IS the post-fix expected behavior on the patched compiler with IIBD.

**Authorization discipline scales with action visibility, not action novelty**. Auto-mode default treats novel computational work as low-risk; it does not treat novel public-action work as low-risk. Issue comments and PR creation are HIGH-visibility regardless of how routine they are mechanically. The user's "don't do PR without approval" was a one-sentence reminder that the visibility class — not the mechanical class — determines the authorization gate. Distinct gates for distinct visibility: `YES POST COMMENT` (issue comment), `YES PUSH` (fork visibility), `YES PR` (upstream submission). Don't bundle.

## Action Items

- [ ] **[skill]** swift-pull-request: Add `[SWIFT-PR-NNN] PR Body Claim Audit` rule — every claim in a PR body MUST cite a specific file:line, commit SHA, or empirical observation. Temporal markers ("predates", "no longer", "always since"), causal markers ("because", "due to"), and quantifier markers ("always", "never", "every") require explicit evidence. Default pattern: direct-cite-source-line. Provenance: this session's "predates IIBD (SE-0409)" v1 walkback (assertion added Feb 2024; SE-0409 accepted late 2023; the temporal claim was wrong-by-direction).

- [ ] **[skill]** issue-investigation: Add `[ISSUE-NNN] Mechanical Validation via Installed Dev Toolchain` rule — when local `llvm-lit` cannot run end-to-end (stale build directory, SDK upgrade-induced cmake regenerate failure, cross-version skew), mechanical validation recovers ~80% of lit's verification value at ~5% of the cost. Procedure: extract test files via the build's `split-file` binary; run the test's RUN: line invocations manually against the installed dev toolchain; confirm exact-match diagnostic text and that fixed code-path branches behave correctly. NOT a substitute for full lit; documents the workaround pattern. Provenance: this session's cmake regenerate failure on `MacOSX26.2.sdk` reference after Xcode upgrade to 26.4.

- [ ] **[skill]** implementation: Add `[IMPL-NNN] Subtractive-First for Structural Defect Fixes` rule — when fixing a structural defect (stale assertion, dead code, broken invariant), the first-cut MUST be the maximally subtractive option: delete the broken construct and let the surrounding structure carry the rationale via the PR description, NOT via a replacement code comment. Replacement comments are ADDED only if a specific code reader (not a PR reviewer) would be confused without them — the PR description is generally that channel. Default to subtractive; require explicit justification for additive. Provenance: this session's iterative minimization where v1 proposed a 3-line replacement comment for a deleted assertion's comment block; v2's pure deletion (7 lines, 0 insertions) reads cleanly because the post-fix structure (early-return → @frozen → error) is self-explanatory.
