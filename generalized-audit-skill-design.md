# Generalized Audit Skill Design

<!--
---
version: 1.1.0
last_updated: 2026-03-24
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The Swift Institute ecosystem produces audits frequently — 82 audit files currently exist across swift-primitives (27), swift-foundations (8), and swift-institute (45), plus 2 orphans at the workspace root. These audits are valuable: they systematically check code against skill requirements, catch convention violations, and track remediation. But they have no governing skill.

**The problem**: Without a skill enforcing structure, audits suffer from:

1. **No enforced output location** — files land in 4+ different locations (workspace root, package source trees, Research/, Research/prompts/). 6 confirmed orphans.
2. **Version proliferation without deprecation** — `swift-io-deep-audit.md` (v3.0.0, Feb 25) coexists with `swift-io-deep-audit-v2.md` (v2.0.0, Mar 19). Version numbering runs backwards. No supersession markers.
3. **Prompt/result intermingling** — 3+ audit pairs split across `Research/` and `Research/prompts/` with identical filenames.
4. **Naming inconsistency** — 7 distinct naming patterns: `{topic}-audit.md`, `audit-{topic}.md`, `{topic}-deep-audit.md`, `{topic}-audit-v{N}.md`, `audit.md`, `{topic}-audit-{variant}.md`, `{topic}-audit-{date}.md`.
5. **Orphaned delta reports** — Delta audits reference base audits via broken paths.
6. **Invisible status/lifecycle** — No way to distinguish active from stale audits without opening each file.

**What works well**: The `swift-file-system/Research/audit.md` demonstrates the single-file, update-in-place pattern — one predictable location per package. However, its structure is a refactoring journal (phases, pre/post metrics, narrative) rather than a compliance findings table. The proposed skill adopts its *location* model but not its *format*. The modularization ecosystem audit demonstrates effective severity classification (CRITICAL/HIGH/MEDIUM) and the findings-table format that this skill standardizes. Most audits already cite skill requirement IDs, making them directly actionable.

**Scope boundary**: Not everything called an "audit" today belongs in this skill. Investigative work — operations completeness inventories, ecosystem adoption surveys, dependency analysis — asks "what exists?" rather than "does code comply with rules?" Those are Discovery research ([RES-012]) and should continue using the research-process skill. The audit skill governs **compliance checks**: systematic evaluation of code against skill requirement IDs.

## Question

What structure, methodology, and lifecycle should a generalized `/audit` skill enforce to eliminate orphan files, standardize output, and integrate with the existing skill ecosystem?

## Analysis

### Dimension 1: Output Location

**Option A — Single `audit.md` per scope level (recommended)**

Each scope level has exactly one `audit.md`, with sections per target skill:

| Scope | Location |
|-------|----------|
| Single package | `{package}/Research/audit.md` |
| Superrepo-wide | `{superrepo}/Research/audit.md` |
| Ecosystem-wide (Swift) | `swift-institute/Research/audit.md` |
| Legislature-wide (legal) | `swift-nl-wetgever/Research/audit.md` |
| Ecosystem-wide (legal) | `rule-law/Research/audit.md` |

This mirrors [RES-002] triage exactly. Location is predictable and discoverable.

When re-running an audit against the same skill on the same scope, the section is **replaced** in place. Git preserves history. No version proliferation.

**Option B — Per-skill audit files**

`{package}/Research/audit-implementation.md`, `audit-naming.md`, etc.

Rejected: multiplies files, reintroduces the orphan problem, breaks the "one predictable place" property.

**Option C — Per-run timestamped files**

`{package}/Research/audit-2026-03-24.md`

Rejected: this is exactly the pattern that created the v1/v2/deep-audit proliferation problem.

**Decision**: Option A. One `audit.md` per scope level. Sections per target skill. Updated in place.

**Broad-then-narrow: two-level routing**

Superrepo-wide or ecosystem-wide audits (e.g., modularization compliance across 199 packages) produce two kinds of output:

1. **Synthesis** — systemic patterns, aggregate counts, top findings, cross-cutting recommendations. Written to the superrepo or ecosystem `Research/audit.md` in a section for the target skill. Includes a per-package triage table (package name, finding count, worst severity).
2. **Per-package detail** — specific violations in specific files. Written to each package's `Research/audit.md` when a follow-up audit is scoped to that package.

The natural workflow is: **broad audit for triage → narrow audit for detail → fix code → re-audit to confirm**. Per-package `audit.md` files are created by the narrow follow-up audit, not upfront for all packages.

This avoids creating hundreds of files upfront while preserving the single-file-per-scope property. The broad `audit.md` answers "where are the problems?" The package `audit.md` answers "what exactly needs fixing here?"

### Dimension 2: Document Structure

```markdown
# Audit: {scope-name}

## {Skill Name} — {YYYY-MM-DD}

### Scope

- **Target**: {package(s) audited}
- **Skill**: {skill name} — {requirement IDs checked}
- **Files**: {N source files, N test files}

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | CRITICAL | [IMPL-010] | Foo.swift:42 | Description | OPEN |
| 2 | HIGH | [API-NAME-001] | Bar.swift:15 | Description | RESOLVED 2026-03-25 |
| 3 | MEDIUM | [MEM-COPY-002] | Baz.swift:8 | Description | DEFERRED — compiler bug #86652 |
| 4 | LOW | [IMPL-020] | Qux.swift:30 | Description | FALSE_POSITIVE — intentional |

### Summary

{N} findings: {X} critical, {Y} high, {Z} medium, {W} low.
{Free-form notes on systemic patterns, overall assessment.}
```

**Severity levels** (from existing usage, formalized):

| Severity | Definition | Action |
|----------|-----------|--------|
| CRITICAL | Correctness or safety issue; code is wrong | Must fix before next release |
| HIGH | Convention violation with material impact on API consumers or maintainability | Should fix in current cycle |
| MEDIUM | Convention violation with minor impact | Fix when touching adjacent code |
| LOW | Style preference or minor inconsistency | Optional |

**Finding status** values:

| Status | Meaning |
|--------|---------|
| OPEN | Not yet addressed |
| RESOLVED {date} | Fixed |
| DEFERRED — {reason} | Known, intentionally postponed |
| FALSE_POSITIVE — {reason} | Not actually a violation |

### Dimension 3: Invocation and Skill Integration

**Invocation patterns**:

```
/audit regarding /implementation              → audit against implementation skill
/audit regarding /code-surface                → audit against code-surface skill
/audit regarding /code-surface /implementation → multi-skill audit (separate sections)
/audit                                         → general audit (all applicable skills)
```

**Multi-skill invocations** produce **separate sections per skill**, not a merged section. `/audit regarding /code-surface /implementation` writes a `## Code Surface — {date}` section and an `## Implementation — {date}` section. Each is independently replaceable on re-audit. The invocation is combined for convenience; the output is per-skill.

**Methodology** — the audit skill:

1. **Loads target skill(s)** — reads the skill's requirement IDs
2. **Determines scope** — from conversation context or explicit parameter (package name, "ecosystem-wide", etc.)
3. **Reads code** — systematically walks all source files in scope (see file scoping below)
4. **Checks each requirement** — evaluates code against each loaded requirement ID; reports only violations found
5. **Classifies findings** — assigns severity based on definitions above
6. **Writes to `audit.md`** — creates or updates the section for each target skill

**File scoping**:

| Target skill | Files audited |
|-------------|---------------|
| Any non-testing skill (`/implementation`, `/code-surface`, `/memory`, etc.) | Source files only (under `Sources/`) |
| `/testing` | Test files only (under `Tests/`) |
| `/audit` (general, no "regarding") | Source files for implementation/code-surface/memory; test files for testing |

This prevents cross-contamination: test code conventions differ from source code conventions. An implementation audit finding in a test helper is noise.

**General audit** (`/audit` without "regarding"): loads skills based on package layer:

| Layer | Default skills |
|-------|---------------|
| L1 Primitives | implementation, code-surface, memory |
| L2 Standards | implementation, code-surface |
| L3 Foundations | implementation, code-surface, modularization |
| L4 Components | implementation, code-surface, modularization |
| L5 Applications | implementation, code-surface |

Additional skills loaded when relevant code patterns detected:
- `memory` — when `~Copyable`, `consuming`, `borrowing`, `unsafe` present
- `platform` — when `#if os(...)`, platform conditionals present
- `testing` — when auditing test files

**Relationship to Discovery research** ([RES-012], [RES-013]):

| Aspect | /audit | Discovery research |
|--------|--------|--------------------|
| Purpose | Does code comply with rules? | Why were decisions made? |
| Output | Findings table with severity | Prose analysis with options |
| Methodology | Checklist against requirement IDs | Open-ended investigation |
| Trigger | Periodic or on-demand | Milestone or convention evolution |
| Location | `Research/audit.md` | `Research/{topic}.md` |

Discovery research may **trigger** an audit (e.g., "this pattern looks inconsistent, let's audit systematically"). An audit may **trigger** research (e.g., "12 findings against [IMPL-010] — should we revisit this requirement?"). But they are distinct workflows.

**Scope boundary**: The audit skill requires a target skill with requirement IDs. If there is no skill to audit against, use Discovery research instead. Specifically:

| Work type | Workflow | Example |
|-----------|----------|---------|
| Does code comply with [IMPL-*] rules? | `/audit regarding /implementation` | "Are there compound identifiers in swift-buffer-primitives?" |
| What operations does this data structure provide? | Discovery research ([RES-012]) | "Does swift-array-primitives cover all canonical Array ADT ops?" |
| Who in the ecosystem uses this pattern? | Discovery research ([RES-012]) | "Which packages have adopted the witness pattern?" |
| Is this dependency being reused optimally? | Discovery research ([RES-012]) | "Is swift-buffer-primitives using all its declared dependencies?" |

The distinguishing criterion: audits produce a **findings table with violations against requirement IDs**. If the output is an inventory, a survey, or an analysis without requirement IDs to check against, it is research.

### Dimension 4: Lifecycle and Corpus Health

**Update-in-place semantics**:

When `/audit regarding /implementation` runs on a package that already has an "Implementation" section in `audit.md`:
1. The existing section is **replaced** entirely with fresh findings
2. Previously RESOLVED findings do not carry forward (they're in git history)
3. Previously DEFERRED findings carry forward with their original reason
4. The section date updates to today

This eliminates version proliferation. There is never a v1/v2 problem because there is only one section per skill.

**Delta audits**: Eliminated as a concept. The new run *is* the delta — `git diff` on `audit.md` shows exactly what changed.

**Prompt documents**: Eliminated. The audit skill's invocation *is* the prompt. No separate prompt files needed.

**Staleness detection** (for research-meta-analysis [META-*]):

An audit section is **stale** when:
- The section date is older than 60 days, AND
- Source files in scope have been modified since the audit date (`git log --since`)

Meta-analysis should flag stale sections and recommend re-audit.

**Remediation tracking**:

OPEN findings in the table are the remediation backlog. When code is fixed, re-running the audit naturally marks findings as no longer present (they disappear from the fresh findings). DEFERRED findings persist across runs until the reason is resolved.

For tracking remediation *between* audit runs, findings can be manually updated:
```
| 2 | HIGH | [API-NAME-001] | Bar.swift:15 | Compound name | RESOLVED 2026-03-25 |
```

**Index integration** ([RES-003c]):

`audit.md` is listed in `Research/_index.md` like any other research document:

```markdown
| audit.md | Systematic code audit against skill requirements | 2026-03-24 | ACTIVE |
```

Status values for the index entry:
- ACTIVE — has OPEN findings
- CLEAN — all findings resolved or no findings
- STALE — needs re-audit (flagged by meta-analysis)

### Dimension 5: Handling Existing Audit Files

**Migration strategy** for the 82 existing files:

| Current pattern | Action |
|----------------|--------|
| `{package}/Research/audit.md` (1 file) | Keep as-is — already canonical |
| `{package}/Research/{topic}-audit.md` | Keep for now; new audits go to `audit.md` |
| `swift-institute/Research/{topic}-audit.md` | Keep for now; new ecosystem audits go to `audit.md` |
| Orphans at workspace root (3 files) | Delete or relocate to appropriate `Research/` |
| `Research/prompts/{topic}-audit.md` | Archive or delete — prompts unnecessary with skill |
| `Research/_scratch/{topic}-audit.md` | Archive or delete |
| Version pairs (v1/v2/deep) | Mark older as SUPERSEDED; newest becomes reference |

Full migration is NOT required. The skill governs **new** audit output. Existing files remain as historical artifacts, naturally superseded as packages get re-audited under the new system.

## Comparison

| Dimension | Current state | Proposed |
|-----------|--------------|----------|
| Location | 4+ locations, 7 naming patterns | One `audit.md` per scope level |
| Structure | Ad-hoc (prose, tables, mixed) | Standardized findings table |
| Versioning | v1/v2/deep file proliferation | Update in place, git for history |
| Integration | Implicit (cites IDs manually) | Explicit (loads target skill) |
| Lifecycle | None (files accumulate) | Replace section on re-audit, meta-analysis flags staleness |
| Prompts | Separate files in prompts/ | Eliminated (skill invocation is the prompt) |
| Deltas | Separate delta files | Eliminated (git diff is the delta) |
| Discoverability | Grep for "audit" across workspace | `find */Research/audit.md` |

## Outcome

**Status**: RECOMMENDATION

The generalized audit skill should enforce:

1. **[AUDIT-001] Single Output File** — All audit output for a given scope MUST be written to `Research/audit.md`. No other filenames permitted for audit output.

2. **[AUDIT-002] Location Triage** — Audit location follows [RES-002]: package-specific → `{package}/Research/audit.md`, superrepo-wide → `{superrepo}/Research/audit.md`, ecosystem-wide → `swift-institute/Research/audit.md`.

3. **[AUDIT-003] Section-Per-Skill Structure** — Each target skill gets one section in `audit.md`, headed `## {Skill Name} — {YYYY-MM-DD}`. Section contains: Scope, Findings table, Summary.

4. **[AUDIT-004] Findings Table Format** — Findings MUST use the standardized table: `| # | Severity | Rule | Location | Finding | Status |`. Severity: CRITICAL, HIGH, MEDIUM, LOW. Status: OPEN, RESOLVED {date}, DEFERRED — {reason}, FALSE_POSITIVE — {reason}.

5. **[AUDIT-005] Update In Place** — Re-auditing the same skill on the same scope MUST replace the existing section. DEFERRED findings carry forward. All others are fresh. Git preserves history.

6. **[AUDIT-006] Skill Loading** — `/audit regarding /{skill}` MUST load the target skill's requirement IDs and check code systematically against each. `/audit` without "regarding" loads default skills for the package's architecture layer.

7. **[AUDIT-007] No Version Files** — Version-suffixed filenames (`-v2`, `-deep`) are forbidden. No delta files. The single `audit.md` section is always current.

8. **[AUDIT-008] No Prompt Files** — Separate audit prompt documents are forbidden. The skill invocation is self-documenting.

9. **[AUDIT-009] Index Entry** — `audit.md` MUST be listed in `Research/_index.md` with status: ACTIVE (has OPEN findings), CLEAN (no findings), or STALE (needs re-audit).

10. **[AUDIT-010] Staleness** — An audit section is stale when its date is >60 days old AND source files in scope have been modified since. Meta-analysis ([META-*]) SHOULD flag stale sections.

11. **[AUDIT-011] Scope Boundary** — The audit skill MUST target a skill with requirement IDs. Work without requirement IDs to check against (inventories, adoption surveys, dependency analysis) is Discovery research ([RES-012]), not an audit.

12. **[AUDIT-012] File Scoping** — Non-testing skill audits MUST audit source files only. `/testing` audits MUST audit test files only. General `/audit` invocations audit source files for implementation skills and test files for the testing skill.

13. **[AUDIT-013] Multi-Skill Output** — Multi-skill invocations (`/audit regarding /X /Y`) MUST produce separate sections per skill, each independently replaceable on re-audit.

14. **[AUDIT-014] Broad-Then-Narrow Routing** — Superrepo-wide or ecosystem-wide audits MUST write synthesis (systemic patterns, aggregate counts, triage table) to the appropriate scope-level `audit.md`. Per-package detail MUST be written to each package's `Research/audit.md` when a follow-up audit is scoped to that package, not upfront.

**Next step**: Create the skill via `/skill-creation` using this specification.

## References

- [RES-002] Document Location Convention
- [RES-003] Document Structure
- [RES-012] Discovery Triggers — boundary between audit and investigative research
- [RES-013] Design Audit Methodology
- [RES-015] Convention Compliance Verification
- `swift-file-system/Research/audit.md` — exemplar of single-file location pattern (note: its refactoring-journal format differs from the proposed findings-table format)
- `swift-institute/Research/modularization-audit-ecosystem-summary.md` — exemplar of severity classification and ecosystem-wide triage table
