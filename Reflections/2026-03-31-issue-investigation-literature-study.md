---
date: 2026-03-31
session_objective: Research best practices for the issue-investigation skill via literature study and comparative analysis across Rust, LLVM, GCC, and GHC ecosystems
packages:
  - swift-institute
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: research_topic
    target: treereduce-swift-feasibility.md
    description: Feasibility of tree-sitter-based automated test case reduction for Swift
  - type: skill_update
    target: reflect-session
    description: Added pre-edit checkpoint to [REFL-003] — load skill-lifecycle before direct skill edits
  - type: package_insight
    target: swift-institute
    description: Glacier-style persistent regression corpus for compiler bug tracking
---

# Issue Investigation Literature Study and Skill Strengthening

## What Happened

Received a handoff document (`HANDOFF-issue-investigation-research.md`) requesting a literature study to strengthen the `issue-investigation` skill with evidence-based practices. The skill had been created from five empirical investigations but might be missing practices used by experienced compiler contributors or established in other ecosystems.

Launched five parallel research agents covering: (1) compiler bug investigation processes across Rust/LLVM/GCC/GHC, (2) reduction tooling and Swift equivalents, (3) bug report quality academic literature plus ownership debugging, (4) Swift compiler debugging tools and flags, (5) swiftlang/swift community triage patterns. Meanwhile, synthesized ecosystem-specific patterns (questions 8-9) from six existing reflection entries.

Wrote the research document at `Research/issue-investigation-best-practices.md` (~700 lines) covering all nine questions from the handoff scope. Then updated the skill with 10 new rules (ISSUE-010 through ISSUE-019): bug classification taxonomy, pass bisection with sub-pass notation, compiler source reading, variable isolation, file-level elimination, superrepo validation, reduction tooling, issue filing format, diagnostic investigation tools, and SIL pipeline stages.

Checked skill-lifecycle compliance when prompted. Found and fixed three gaps: update classification not stated (Additive), `issue-investigation` missing from swift-institute-core Skill Index (pre-existing gap from original creation), and the skill lacked the local Swift clone path for [ISSUE-012] compiler source reading.

## What Worked and What Didn't

**Worked well:**
- Five parallel research agents compressed what would have been hours of serial web searching into ~5 minutes of wall-clock time. Each agent returned focused, detailed findings because the prompts were specific and scoped.
- The handoff document was well-structured. The nine-question scope with clear category divisions (literature, Swift-specific, ecosystem-specific) mapped cleanly onto parallel agent assignments.
- Synthesizing ecosystem-specific patterns (questions 8-9) from existing reflections was possible without web research because the five prior investigation sessions had been thoroughly reflected upon.

**What didn't work:**
- The skill-lifecycle checklist was not consulted before making changes. The update classification (Additive), the swift-institute-core index check, and the local clone path were all caught only when prompted. Should have loaded the skill-lifecycle skill proactively and walked the "Updating an Existing Skill" checklist before starting edits.
- The swift-institute-core index gap was inherited from the original skill creation (also didn't follow the lifecycle). This means any skill created without the lifecycle checklist may have similar gaps.

## Patterns and Root Causes

**The lifecycle-first principle**: The skill-lifecycle exists precisely to catch integration gaps. Skipping it when "the content is the hard part" causes exactly the kind of metadata debt (missing index entries, missing classification) that the lifecycle was designed to prevent. The content was not the hard part this time -- the research agents handled it. The integration steps were the hard part because they were not front-loaded.

**Parallel research agents are a force multiplier for literature studies**: The five-agent pattern worked because each agent had a distinct, non-overlapping scope with clear deliverables. The prompts explicitly said "do NOT write or edit any files -- just return your findings as text," which kept them from interfering with each other or with the main thread's file writes. This pattern should be reused for future research handoffs.

**Swift's reduction tooling gap is real and significant**: The comparative analysis revealed that Swift is the weakest of the four ecosystems in automated test case reduction. C/C++ has C-Reduce (25x better than generic delta debugging), Rust has treereduce/icemelter/cargo-bisect-rustc, GHC has manual-only (known gap). Swift has no source-level reducer, an alpha-quality SIL-level reducer (`bug_reducer`), and no toolchain bisection tool. The practical implication: our manual reduction protocol ([ISSUE-003], [EXP-004]) is not just a methodology choice -- it's the only option.

## Action Items

- [ ] **[research]** Investigate feasibility of building `treereduce-swift` using the existing `tree-sitter-swift` grammar. The tree-sitter grammar exists; `treereduce` is language-generic given a grammar. If viable, this would close the most critical tooling gap identified in the comparative analysis.
- [ ] **[skill]** reflect-session: Consider adding a pre-edit checkpoint to [REFL-008] or a cross-reference to skill-lifecycle when the session involves skill updates. The pattern of "update skill content, forget integration steps" recurred here and could recur in any reflect-session that produces skill action items.
- [ ] **[package]** swift-institute: Consider creating a `glacier`-style persistent regression corpus (per Rust's `rust-lang/glacier`) -- a directory of minimal reproducers for known compiler bugs, run against each new toolchain to detect fixes and regressions automatically.
