# Skill Shape and Growth Evaluation

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

During the 2026-04-24 `/corpus-meta-analysis` sweep, the Skills corpus
surfaced two linked concerns that a single-skill review could not resolve:

1. **Asymmetric skill growth.** Four skills now exceed 1000 lines —
   `documentation` (1840 lines, 61 rules), `platform` (1396 lines, 40
   rules), `memory-safety` (1194 lines, 57 rules), and
   `existing-infrastructure` (1173 lines, 25 rules). `documentation`
   grew by 25 rules in the six days preceding this investigation and
   now stands 32% larger than the next-biggest skill. The ecosystem has
   one precedent for decomposing a large skill into a routed multi-file
   structure: `implementation/` — a navigation-hub `SKILL.md` plus
   seven thematic sibling files (`accessors.md`, `concurrency.md`,
   `errors.md`, `infrastructure.md`, `ownership.md`, `patterns.md`,
   `style.md`). No other large skill uses this pattern. [SKILL-CREATE-005]
   currently mandates *"A skill MUST be a single `SKILL.md` file"*,
   which `implementation/` violates by construction.
2. **Cluster-audit gap.** Per [SKILL-LIFE-031], cluster reviews MUST be
   run by an agent independent of the authors. The parent session on
   2026-04-24 authored or substantially modified nearly all 
   implementation-layer skills in a single `/reflections-processing`
   pass, making an independent cluster audit required before a further
   restructuring proposal can land.

This document addresses both concerns: a per-skill classification for
multi-file splitting, a draft update to [SKILL-CREATE-005], and a
summary of the independent cluster audit whose detailed findings are
recorded in `Audits/audit.md` under `## Cluster:
implementation-layer-skills-2026-04-24`.

## Inventory (Verified)

Re-run of the skill-size inventory per the investigation brief
(`for s in Skills/*/SKILL.md; do wc -l "$s"; done | sort -rn`), taken
2026-04-24:

| Skill | Lines | Rules | ID Prefixes | Layer |
|------|------|------|------|------|
| documentation | 1840 | 61 (3 duplicate-IDs) | `DOC-*` only; 8 numeric bands | implementation |
| platform | 1396 | 40 | `PLAT-ARCH-*`, `PATTERN-001..009` | architecture |
| memory-safety | 1194 | 57 (1 duplicate-ID) | `MEM-SAFE`, `MEM-UNSAFE`, `MEM-COPY`, `MEM-OWN`, `MEM-LIFE`, `MEM-SEND`, `MEM-LINEAR`, `MEM-SPAN`, `MEM-REF` (9 clusters) | implementation |
| existing-infrastructure | 1173 | 25 | `INFRA-*` only; 4 numeric bands (001–005, 020–025, 050, 100–110, 200) | implementation |
| readme | 977 | 25 | `README-*` only | implementation |
| conversions | 944 | 33 | `IDX-*` + `CONV-*` (two clusters) | implementation |
| modularization | 896 | 24 | `MOD-*` + `MOD-EXCEPT-*` + `MOD-DOMAIN` (one major) | implementation |
| testing | 884 | 18 (3 duplicate-IDs) | `TEST-*` only | implementation |
| handoff | 818 | 30 | `HANDOFF-*` only | process |
| code-surface | 774 | 25 (1 duplicate-ID) | `API-NAME-*` + `API-ERR-*` + `API-IMPL-*` (three clusters) | implementation |
| corpus-meta-analysis | 760 | — | `META-*` only | process |
| document-markup | 723 | — | `DOC-MARKUP-*` only | implementation |
| issue-investigation | 718 | — | `ISSUE-*` only | process |
| experiment-process | 690 | — | `EXP-*` only | process |
| supervise | 687 | 17 | `SUPER-*` only | process |
| research-process | 677 | ~26 | `RES-*` only | process |
| audit | 649 | 23 | `AUDIT-*` only | process |
| blog-process | 640 | — | `BLOG-*` only | process |
| testing-swiftlang | 622 | — | `SWIFT-TEST-*` only | implementation |
| skill-lifecycle | 617 | ~20 | `SKILL-CREATE-*` + `SKILL-LIFE-*` | process |

Reference implementation (post-split): `implementation/` is 290 lines
in SKILL.md plus seven sibling files summing ~92K bytes, ~60 rules.

## Question

> When should a skill be permitted to span multiple files, and how
> should its sibling files be organized? Specifically: should the
> `implementation/` multi-file pattern generalize to some subset of the
> skills above, or should it remain a single-skill exception?

## Analysis

### Option Space — How a Skill Can Grow

Three shapes are distinguishable for a large skill:

| Shape | Example | Navigation cost | Cohesion cost |
|-------|---------|-----------------|--------------|
| Single file, sequential | `readme` (977 lines, one narrative arc) | Linear scan of one file; cheap for single-topic skills | None when narrative is coherent |
| Single file, clustered by ID prefix | `memory-safety` (1194 lines, 9 prefix clusters all in one file) | Must scan mixed-prefix text to locate a rule by prefix | Mixed-prefix text forces the reader to hold multiple mental contexts |
| Multi-file navigation hub | `implementation/` (SKILL.md + 7 topic files) | Navigation table in SKILL.md routes by topic; detail loads on demand | Each file coherent on its own |

The implementation/ precedent was adopted when the skill reached ~60
rules across ~8 semantic clusters (ownership / concurrency /
accessors / errors / style / infrastructure / patterns). The
restructure commit (`ac6ae2b Split implementation SKILL.md into
topic-sibling files`) landed without a corresponding update to
[SKILL-CREATE-005], leaving the skill in a de facto exception state.

### Classification — Per-Skill Recommendation

Applying the implementation/ criteria (rule count ≥ 40, ≥ 3 semantic
clusters, per-file independent loadability) to each skill above 600
lines:

| Skill | Classification | Rationale |
|-------|---------------|-----------|
| **documentation** | **SPLIT — thematic** | 58 unique rules in 8 numeric bands (inline `///` 001–010 / catalogue 020–033 / topical 060–064 / tutorial 070–074 / landing 080–084 / visual 090–093 / style 040–053 / currency embedded). Single `DOC-*` prefix so band-by-band thematic split mirrors `implementation/` more than prefix-based split. Growth rate (+25 rules in 6 days) signals the navigation-cost threshold is crossed. |
| **platform** | **DEFER** | 40 rules but one semantic domain (platform stack L1–L3). The embedded `PATTERN-001..009` subrange is actually platform-scoped; platform doesn't split into ≥ 3 independent topics. Below the 1500-line tipping point that would compel a split; architecture-layer skills change less frequently than implementation-layer. Revisit only if it exceeds ~1800 lines. |
| **memory-safety** | **SPLIT — by ID prefix** | Textbook case: 9 clean semantic clusters already encoded as ID prefixes (MEM-SAFE, -UNSAFE, -COPY, -OWN, -LIFE, -SEND, -LINEAR, -SPAN, -REF). Single skill at 1194 lines forces readers to scan across unrelated prefixes to find a rule by topic. `swift-institute-core`'s Skill Index already enumerates these prefixes separately (Skills/swift-institute-core/SKILL.md:44), treating them as semantic clusters that happen to share a SKILL.md. Prefix-based split matches the index. |
| **existing-infrastructure** | **DEFER** (thematic when grown) | 25 rules across 4 bands (integration modules 001–005 + 200, "before writing X" 020–025 + 050, protocol-lifting 100–110). Bands are thematically clean and would support a thematic split, but rule count (25) is well below the 40-rule threshold. Current discovery cost is dominated by scroll position within one file; sibling-file routing would add overhead without clear payoff. Revisit when rule count crosses 40 or file crosses 1500 lines. |
| **readme** | **KEEP** | Single cohesive narrative (README.md structure → badges → sections → monorepo patterns). V2.0.0 restructure on 2026-04-21 was recent and deliberate. Homogeneous topic; no sub-clusters. |
| **conversions** | **DEFER** (two-prefix when grown) | 33 rules across `IDX-*` (13) + `CONV-*` (20). Clean bimodal split available but below the 40-rule threshold. Index work and conversion API work are genuinely distinct audiences, so a prefix split would be clean — but at 944 lines the single-file cost is still manageable. Revisit when the sum crosses 40 rules. |
| **modularization** | **KEEP** | 24 rules with one dominant prefix (`MOD-*`) and a coherent decomposition-first narrative. The exception rules (`MOD-EXCEPT-*`) are explicitly named as exceptions and belong in the main flow. Would fragment poorly. |
| **testing** | **DEFER** (pending internal cleanup) | 15 unique rules but chaotic numbering (duplicate IDs TEST-019/020/021, wide numeric gaps). Structural cleanup — renumbering and de-duplication — must land before re-evaluating whether to split. No clean sub-prefix is available; a split would require thematic bands (routing vs support vs factories vs gates) that aren't yet reflected in the numbering. |
| **handoff** | **KEEP** | Workflow skill with a strictly sequential narrative (triggers → templates → procedure → post-handoff → supervisor-block composition). Deliberately self-contained. |
| **code-surface** | **DEFER** (three-prefix when grown) | 24 unique rules across `API-NAME-*` (7) + `API-ERR-*` (5) + `API-IMPL-*` (12). Under 800 lines; file remains browsable. Strong candidate for a future split when rule count crosses 40. |
| Other skills 600–760 lines | **KEEP** | Single-topic workflow or reference skills; narrative arcs are coherent end-to-end. |

### Cross-Reference Integrity Under Proposed Splits

The investigator-ground-rules check (*"flag any rule in the
recommended-SPLIT set that would lose cross-references if moved"*)
returns clean results for both SPLIT recommendations:

**memory-safety (SPLIT by prefix)** — all intra-skill cross-references
either stay within a single prefix cluster or cite an ID via the
skill's rule-index table. Example: `[MEM-COPY-001]` cites
`[API-NAME-002]` (code-surface, external) and `[MEM-SAFE-020]`
(same skill, different prefix). Moving MEM-COPY to its own file
and MEM-SAFE to another does not break the citation — the reader
navigates via the hub `SKILL.md`'s rule-index table.

**documentation (SPLIT thematic)** — all thematic bands reference
other bands internally (`[DOC-010]` cites `[DOC-027]`, `[DOC-028]`,
`[DOC-029]` — three different bands). A thematic split preserves
these by keeping all DOC-* IDs globally unique; the hub SKILL.md
carries the rule index mapping each ID to its file.

No rule would become a ghost reference under either recommended
split. The hub-file pattern is structurally lossless for
cross-references.

### Sync Infrastructure Impact

Verified 2026-04-24:
`.claude/skills/implementation → /Users/coen/Developer/swift-institute/Skills/implementation`
is a directory-level symlink. All sibling files (`accessors.md`,
`concurrency.md`, etc.) are reachable through the symlink. The
`Scripts/sync-skills.sh` script discovers skills by checking for
`SKILL.md` and symlinks the whole skill directory — no per-file
handling is required. Multi-file skills work with the current sync
infrastructure without modification.

No [SUPER-012] class-(c) escalation to the sync layer is needed.

## Proposed Update to [SKILL-CREATE-005]

**Status flag**: this proposal is a **Breaking** revision per
[SKILL-LIFE-003] (the current rule is absolute; the proposed form
carves a permitted exception). It MUST NOT be applied without
explicit user approval per the investigator ground rules.

### Current text

> **Statement**: A skill MUST be a single `SKILL.md` file in a
> directory matching the skill name. The file MUST contain YAML
> frontmatter followed by Markdown content.

### Proposed text

> **Statement**: A skill MUST be a single `SKILL.md` file in a
> directory matching the skill name, UNLESS the multi-file
> navigation-hub exception in [SKILL-CREATE-005a] applies.

### Proposed new rule [SKILL-CREATE-005a] Multi-File Navigation-Hub Exception

> **Statement**: A skill MAY use a multi-file structure (a
> navigation-hub `SKILL.md` plus topic-sibling files) when ALL of:
>
> 1. **Rule count ≥ 40** — the skill carries enough rules that
>    single-file discovery cost is material.
> 2. **≥ 3 semantic clusters** — clusters partition cleanly by
>    ID prefix OR by thematic band (consecutive numeric range with a
>    topical label).
> 3. **Independent loadability** — each sibling file MUST read
>    coherently on its own, not as a fragment of a parent narrative.
> 4. **Hub structure** — `SKILL.md` MUST contain:
>    (a) `## Files` navigation table (topic → file → rule IDs);
>    (b) foundational axioms that govern the whole skill (if any);
>    (c) `## Rule Index` mapping each rule ID to its sibling file;
>    (d) cross-skill references.
>    `SKILL.md` MUST NOT carry detailed rule bodies — those live in
>    the siblings.
> 5. **File header** — each sibling file MUST declare its scope and
>    list its rule IDs at the top (`**Rules in this file**: ...`).
> 6. **Breaking revision** — splitting an established skill is a
>    breaking restructure and follows [SKILL-LIFE-003] protocol; the
>    splitting commit is the evidence of validity.
>
> Sibling files MAY be grouped by ID prefix (`memory-safety/MEM-COPY.md`,
> `memory-safety/MEM-SAFE.md`, ...) or by thematic band
> (`documentation/inline.md`, `documentation/catalogue.md`, ...). The
> choice SHOULD mirror the clustering already present in the rule
> numbering.
>
> **Reference implementation**: `Skills/implementation/` — hub
> `SKILL.md` (290 lines, 4 foundational axioms, navigation table,
> rule index) plus 7 siblings (`ownership`, `concurrency`, `accessors`,
> `errors`, `style`, `infrastructure`, `patterns`).
>
> **Rationale**: Single-file is the default because it minimizes
> routing complexity. Multi-file becomes valuable when a single
> `SKILL.md` exceeds ~1000 lines or ~40 rules with clean
> partitioning — below that threshold, the navigation-hub structure
> adds routing overhead without reducing discovery cost enough to
> justify it. The criteria preserve single-file-first while recognizing
> the structural pattern that `implementation/` validated.
>
> **Cross-references**: [SKILL-CREATE-005], [SKILL-CREATE-006],
> [SKILL-LIFE-003]

### Application Matrix (under proposed rule)

| Skill | Qualifies under [SKILL-CREATE-005a]? | Proposed Action |
|-------|--------------------------------------|-----------------|
| implementation | Yes (already split, grandfathered) | Keep |
| memory-safety | Yes (57 rules ≥ 40, 9 clusters ≥ 3, independently loadable) | Execute SPLIT in a follow-on dispatch |
| documentation | Yes (58 unique rules ≥ 40, 8 thematic bands ≥ 3, independently loadable) | Execute SPLIT in a follow-on dispatch |
| platform | Borderline (40 rules, 1 domain) | KEEP; revisit at 50+ rules |
| existing-infrastructure | No (25 rules < 40) | KEEP; revisit at 40+ rules |
| conversions | No (33 rules < 40) | KEEP; revisit at 40+ rules |
| readme | No (25 rules; single cohesive narrative) | KEEP |
| testing | No (18 rules; cleanup needed first) | KEEP + cleanup |
| code-surface | No (24 unique rules < 40) | KEEP; revisit at 40+ rules |
| All other 600–760 line skills | No | KEEP |

## Alternative — Keep [SKILL-CREATE-005] As-Is

The alternative is to treat `implementation/` as a pre-existing
exception, update the rule text to acknowledge it (narrow
grandfathering), and prohibit further multi-file skills going forward.

Argument for: the navigation cost of the current large skills is
tolerable; adding a second multi-file pattern multiplies the
cognitive model consumers must hold.

Argument against: `documentation` at 1840 lines and `memory-safety` at
1194 lines already exceed the navigation-cost threshold where
`implementation/` was split; keeping the rule strict forces these
skills to carry the known cost without the known remedy. This path
locks the ecosystem into "one-off exception" territory and creates
pressure to retroactively absorb implementation/ back into a single
file to preserve the rule's literal truth — an undesirable regression.

The recommended path is the proposed [SKILL-CREATE-005a] exception
with criteria — it preserves single-file default while making the
implementation/ structure transparent and applicable.

## Cluster Audit Summary

An independent cluster audit per [SKILL-LIFE-031] / [AUDIT-019] was
run against the 8 implementation-layer skills over 600 lines
(excluding `implementation/` which just got restructured):
**documentation, memory-safety, existing-infrastructure, readme,
conversions, modularization, testing, code-surface**.

Findings are recorded in `swift-institute/Audits/audit.md` under
`## Cluster: implementation-layer-skills-2026-04-24`.

Summary counts:

| Category | Count | Worst severity |
|----------|-------|----------------|
| A. Duplicate rule IDs ([SKILL-CREATE-003] violations) | 8 | CRITICAL |
| B. Broken / ghost cross-references | 9 | HIGH |
| C. Stale `last_reviewed` per [SKILL-LIFE-004] | 5 | HIGH |
| D. Composition gaps ([SKILL-CREATE-004] under-declared `requires:`) | 2 | HIGH |
| E. swift-institute-core Skill Index staleness | 2 | MEDIUM |
| F. Chaotic numeric ordering (navigation cost) | 2 | MEDIUM |
| G. Terminology polish ("umbrella" polysemy) | 1 | LOW |

Total: 29 findings, of which 8 CRITICAL, 14 HIGH, 5 MEDIUM, 2 LOW.
See `Audits/audit.md` for per-finding detail with severity, location,
description, and status columns.

Key patterns:

1. **Systematic ID collision from append-only reflection processing.**
   Four of the eight skills have duplicate rule IDs. In every case the
   duplicate is appended at the END of the file — after rules with the
   same number already existed earlier. The pattern traces to the
   2026-04-24 `c687dd1 Process 51 reflections` commit (and its
   predecessors) which appended new rules without scanning for
   collisions. This is a process defect in `/reflections-processing`:
   the skill update flow should verify ID uniqueness before committing.
2. **Cross-reference rot concentrated in `PATTERN-*` citations.** Six
   of the nine broken references are to `[PATTERN-XXX]` IDs that never
   existed or were renumbered. The [PATTERN-*] namespace is shared
   between `platform/` (001–009) and `implementation/patterns.md`
   (012–058 with gaps); citing an ID outside both defined ranges
   produces a silent ghost reference. No tooling catches this today.
3. **`last_reviewed` lag tracks the append-only-without-bump pattern
   from (1).** Five of the eight skills received substantive
   content edits after their `last_reviewed` date; [SKILL-LIFE-004]
   (added today, 2026-04-24) codifies the requirement to bump
   concurrently. The five violations pre-date the rule but remain open
   findings because the content is strictly newer than the metadata.

### Batched Remediation Order

Per [SKILL-LIFE-031] ("Work findings in severity-batched order:
trivial → terminology canonicalization → design → edge-case procedural
→ remaining polish"), the natural batches are:

1. **Trivial / mechanical (LOW + MEDIUM-E, MEDIUM-F):**
   (a) update `swift-institute-core`'s Skill Index ID ranges for
   `documentation` (→ DOC-093) and `readme` (→ README-025);
   (b) renumber `testing` and `documentation` to close numeric gaps
   (optional — may defer as purely cosmetic).
2. **Terminology polish (LOW):** decide whether "umbrella" deserves
   disambiguation across `modularization` / `documentation` / `testing`.
3. **Cross-reference rot (HIGH-B):** fix 9 ghost references — either
   remove citation, point to the intended surviving ID, or promote a
   missing rule.
4. **Composition gaps (HIGH-D):** add missing `requires:` entries
   (memory-safety → code-surface, implementation); add Test-Support
   cross-references between `conversions` / `testing` / `modularization`.
5. **Lifecycle drift (HIGH-C):** bump `last_reviewed` on 5 skills
   concurrent with their next substantive edit per [SKILL-LIFE-004] —
   if the skills are reviewed now as part of this cleanup, set all 5
   to 2026-04-24.
6. **Design-level — ID collisions (CRITICAL-A):** the 8 duplicate IDs
   require user-gated decision: either (i) renumber the second
   occurrence to a fresh ID in the same prefix's unused range (simplest,
   no consumer impact), or (ii) remove the duplicate if the content is
   absorbed elsewhere. Option (i) is recommended. This is the only
   batch that requires user judgment; everything else is mechanical.
7. **Design-level — [SKILL-CREATE-005a]:** if user approves the
   proposed update above, execute SPLIT for `memory-safety` and
   `documentation` in a follow-on dispatch (both qualify under the
   proposed rule). If user rejects, re-read findings (A) through (G)
   as the complete change set.

No cross-skill semantic contradictions were found — the cluster's
rules compose consistently where they overlap (e.g., [CONV-007] and
[TEST-018] agree on Test Support literal conformances; [DOC-010]
and [README-016] agree on what to exclude from their respective
surfaces even without a cross-reference).

## Outcome

**Status**: RECOMMENDATION

The recommended path has two independent tracks:

**Track 1 — Skill-shape rule (BREAKING — requires user approval per
[SKILL-LIFE-003]):** update [SKILL-CREATE-005] and add
[SKILL-CREATE-005a] as drafted above. This grandfathers
`implementation/` and permits `memory-safety` and `documentation`
SPLITs in follow-on dispatches.

**Track 2 — Cluster audit remediation:** work the 29 findings in
`Audits/audit.md` using the batched order above. Only Batch 6
(duplicate-ID renumber) requires a user gate; Batches 1–5 are
mechanical fixes safe to land together.

Tracks 1 and 2 are mostly orthogonal. The one interaction: if
Track 1 lands and SPLITs are executed, Track-2 fixes SHOULD land
BEFORE the SPLIT so the split-inheriting sibling files start clean.

## Out of Scope

- Executing any split (this is investigation; execution is a
  follow-on dispatch per [SKILL-LIFE-031]).
- Re-evaluating the 2026-04-24 `[META-005]` deprecation (already
  landed).
- Re-evaluating the 2026-04-24 reflection → SkillUpdate/NoAction
  routing (already processed).
- Updating `Research/_index.json` to list this document — deferred
  because `Research/` has in-flight uncommitted changes from the
  parent session (per the investigation brief's "Do Not Touch"). The
  parent session or next session SHOULD add:
  ```json
  { "file": "skill-shape-and-growth-evaluation.md",
    "displayName": "skill-shape-and-growth-evaluation.md",
    "topic": "Per-skill classification of which large skills qualify for the implementation/ multi-file pattern, proposed [SKILL-CREATE-005a] exception criteria, and summary of the 2026-04-24 cluster audit across 8 implementation-layer skills over 600 lines.",
    "date": "2026-04-24",
    "status": "RECOMMENDATION",
    "statusDetail": "awaiting user decision on proposed [SKILL-CREATE-005] breaking revision",
    "statusRaw": "RECOMMENDATION",
    "tier": 2,
    "scope": "ecosystem-wide" }
  ```

## References

- Investigation brief: `swift-institute/HANDOFF-skill-growth-and-cluster-audit.md` (2026-04-24)
- Precedent: `Research/agent-workflow-skill-consistency-audit.md` (cluster-audit shape, 2026-04-15)
- Precedent: `Research/skill-creation-process.md` v1.1.0 (skill creation protocol, SUPERSEDED)
- Precedent: `Research/skill-loading-reliability.md` v1.1.0 (loading-order design, SUPERSEDED)
- Precedent: `Research/skill-based-documentation-architecture.md` v1.1.0 (skill vs .docc, SUPERSEDED by documentation skill)
- Related: `Research/skill-as-input-composition-pattern.md` (IN_PROGRESS)
- Related: `Research/compose-then-trace-skill-design-phase.md` (IN_PROGRESS)
- Rule: [SKILL-CREATE-003] (unique prefix mandate) — Skills/skill-lifecycle/SKILL.md
- Rule: [SKILL-CREATE-004] (requires: must list dependencies)
- Rule: [SKILL-CREATE-005] (single-file mandate — proposed revision)
- Rule: [SKILL-LIFE-003] (breaking-revision classification)
- Rule: [SKILL-LIFE-004] (last_reviewed bump requirement)
- Rule: [SKILL-LIFE-031] (cluster review procedure + batched remediation)
- Rule: [AUDIT-019] (cluster audit mode — `/audit cluster`)
- Findings detail: `Audits/audit.md` → `## Cluster: implementation-layer-skills-2026-04-24`
