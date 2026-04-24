# Layer-Container Orphan Triage

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: DECISION
tier: 2
scope: ecosystem-wide
---
-->

## Context

On 2026-04-23 the three superrepos (`swift-primitives`, `swift-standards`, `swift-foundations`) were dismantled via `rm -rf .git` per user direction — converting each from a git-tracked umbrella monorepo holding sibling sub-repos via submodules into a plain directory holding standalone sibling sub-repos. The dismantle preserved all 297+ sub-package repos (each with its own `.git/`), archived the umbrella GitHub repos where applicable, and stood up `.org` stubs for the public-facing layer descriptions.

The dismantle left **orphan content** at each layer-container root: files and directories previously tracked by the container's own `.git/` that no longer had a version-control home. Pre-dismantle Phase 0.5a triage relocated items that were *already untracked* in the container's git (3 Experiments + 5 Research `.md` files from swift-primitives). Everything that had been *tracked* in the container's git was now orphan on disk — no remote, no history, no place to commit changes against.

The orphan inventory at triage time (2026-04-24):

| Container | Experiments/ | Research/ | Audits/ | DocC | CLAUDE.md | HANDOFF-*.md |
|---|---:|---:|---:|---:|---:|---:|
| `swift-primitives/` | 31 | 61 .md + data subdir + aggregate | 5 + 2 subdirs | 5 + 2 subdirs | 1 | 5 + 1 |
| `swift-standards/` | 2 | 1 | 1 (empty template) | 1 | 1 | 0 |
| `swift-foundations/` | 13 | 16 + Reflections/ | 1 (empty template) | 0 | 1 | 2 |

Plus layer-container-level superrepo infrastructure (`Package.swift`, `Sources/Primitives/`, `Scripts/`, `Skills/`, IDE workspace files) that has no equivalent in the sibling-packages model — flagged out-of-scope for a dedicated infrastructure-cleanup session.

## Question

How should the orphan artifact-container content (`Experiments/`, `Research/`, `Audits/`, `Documentation.docc/`) at each dismantled layer-container be relocated — and how should the convention be codified so the anti-pattern doesn't accrete again if umbrellas are ever reintroduced?

## Analysis

### Option A: Retain layer-level containers as local-only directories

Leave each layer-level `Experiments/`, `Research/`, `Audits/`, and `Documentation.docc/` in place as local-only directories, not tracked by any git repo. Accept that the content has no remote, no history, and no canonical home.

**Advantages**: zero migration cost; pre-existing structure preserved; agents cd'ing into the layer-container still see familiar layout.

**Disadvantages**: orphan content is invisible to the ecosystem's index mechanisms (`_index.json` dashboards); no collaborator sees updates; content accretes without review; the next dismantle-equivalent (e.g., someone deletes the layer directory) irrecoverably loses work; the shape silently contradicts the dismantle's stated goal (siblings as first-class repos).

**Rejected**: the "local-only" state is structurally unstable. Either the content matters (in which case it needs a canonical home with a remote) or it doesn't (in which case it should be deleted). A persistent "local-only artifact container" is neither.

### Option B: Restore superrepo git tracking for the layer-level containers only

Re-init `.git/` at each layer-container root solely to track `Experiments/`, `Research/`, `Audits/`, `Documentation.docc/`, and CLAUDE.md. The sub-package sibling repos remain standalone; the layer container's git tracks only meta-content.

**Advantages**: preserves pre-dismantle layer-level organization; artifact containers get a canonical remote and history; pre-dismantle workflow is essentially recreated.

**Disadvantages**: contradicts the dismantle's stated goal (siblings as first-class, no umbrella); re-establishes the same risk that motivated the dismantle (when the meta-repo's layout changes, the layer-level git needs updates); concentrates orphan risk — every future dismantle-equivalent re-orphans everything in the layer-level git at once.

**Rejected**: re-creating the umbrella in a narrower scope just re-concentrates the fragility. The correct answer is to put artifacts where they're durably owned, not to preserve the historical layout.

### Option C: Relocate per highest-layer dep + ecosystem-wide split; forbid layer-level containers going forward

Route each artifact to its canonical home based on its dependency graph ownership:

- **Per-package artifacts** (one clear owning package) → `<pkg>/<Experiments|Research|Audits>/`
- **Cross-cutting / standalone / ecosystem-wide artifacts** → `swift-institute/<Experiments|Research|Audits>/`

Codify the rule in the three artifact skills (`experiment-process`, `research-process`, `audit`) so future sessions cannot reintroduce the anti-pattern: layer-level `<layer>/Experiments/` etc. are forbidden.

**Advantages**: matches the dismantle's siblings-as-first-class intent; per-package artifacts travel with their package's git (rename, fork, transfer all carry the artifacts); ecosystem-wide artifacts live in the one repo dedicated to ecosystem state; future umbrellas (if reintroduced) never gain an artifact-container role.

**Disadvantages**: per-package re-routing requires per-file classification (non-trivial for ~80 research docs of mixed scope); path-dep rewrites required for experiments with sibling-package deps (from `../../X` to `../../../X` — the depth changes); coordinating with pre-existing index WIP at swift-institute/Research/ and /Audits/ requires index updates to be deferred to a follow-up session; DocC migration substantial enough to warrant its own session.

**Chosen**.

### Decision rule

The relocation target for each artifact follows a four-question decision tree:

1. **Is it clearly scoped to one package?** → that package's `<Experiments|Research|Audits>/`.
2. **Does it exercise / analyze multiple packages at the same tier, with one clear domain owner?** → that owner's package.
3. **Does it span multiple tiers with a clear highest-layer owner?** → the highest-layer owner's package.
4. **Is it standalone, cross-cutting, or genuinely ecosystem-wide?** → `swift-institute/<Experiments|Research|Audits>/`.

Layer-level `<layer>/<Experiments|Research|Audits>/` is never a valid answer.

### Post-dismantle orphan classes

Three orphan classes emerge simultaneously when a superrepo is dismantled:

| Class | Source state | Disposition |
|---|---|---|
| (a) Artifacts tracked by the container's git | Listed in `_index.json`, have content history | Relocate per Option C; preserve via commit message provenance since cross-repo moves lose git history by definition |
| (b) Artifacts untracked in the working tree at dismantle time | Never in the container's git | Pre-dismantle Phase 0.5a relocates these |
| (c) Superrepo-level infrastructure | Umbrella `Package.swift`, umbrella `Sources/`, IDE workspace files, scripts tied to the umbrella build | Delete or relocate to `swift-institute/Scripts/` (for still-useful scripts); there is no natural artifact-level destination |

This triage covered class (a). Class (b) was handled pre-dismantle. Class (c) is flagged for a dedicated follow-up (no canonical home per the siblings-as-first-class model; each item decided on its own merits).

### Path-dep rewrite math (corrected)

Unix relative-path resolution from a moved experiment's `Package.swift`:

- Experiment at `swift-primitives/Experiments/E/Package.swift`:
  - `../..` → `swift-primitives/` (the dismantled umbrella — now defunct)
  - `../../swift-X-primitives` → `swift-primitives/swift-X-primitives/` (sibling package; correct)
- Experiment moved to `swift-primitives/swift-Y-primitives/Experiments/E/Package.swift`:
  - `../..` → `swift-primitives/swift-Y-primitives/` (the new parent package; often the same package as the experiment's primary dep)
  - `../../swift-X-primitives` → `swift-primitives/swift-Y-primitives/swift-X-primitives/` (**non-existent subdirectory** — path-dep is broken)
  - Correct rewrite: `../../../swift-X-primitives` → `swift-primitives/swift-X-primitives/` (3 levels up to the layer-container root, then into the sibling package)

The precedent at `swift-primitives/swift-ownership-primitives/Experiments/*/Package.swift` (commit `992eb03`) uses `../../../swift-ownership-primitives` — confirming the 3-level form.

**Empirical verification** (2026-04-24): `python3 -c "import os; print(os.path.normpath('...'))"` on a constructed example confirmed the 3-level form. A prior handoff's Constraint 3 had claimed the 2-level form still resolved; that claim was wrong. Future dismantle-cycle handoffs SHOULD verify path-math claims with `python3 os.path.normpath` or equivalent before encoding as Constraints.

### Codification-first discipline

Executing the relocations before the rule lands in skills creates a silent re-introduction risk: the next session encounters the moved state but no rule text, and may reintroduce the layer-level container under its own logic. The remediation pattern is **Stage 2 MUST precede Stage 3**:

1. Inventory + classify (Stage 1) — capture what exists and where it should go
2. Codify the rule in the relevant skills + memory (Stage 2) — lock the convention before execution
3. Execute relocations citing the codified rule (Stage 3) — each commit references the skill requirement ID
4. Reflect + preserve findings (reflect-session) — capture reusable lessons for future dismantles

Stage 2 costs ~30 minutes of skill edits and pays repeatedly: future sessions read the skill text, not the ghost of a past session's choices.

### Index-vs-disk drift

At triage time, the source layer-level indexes contained both:
- **Orphan index entries**: entries referencing dirs that had already been moved to canonical homes elsewhere (e.g., `io-witness-*` entries in `swift-primitives/Experiments/_index.json` whose dirs live at `swift-io-primitives/Experiments/`).
- **Orphan disk dirs**: dirs that existed on disk but had no entry in the source index (e.g., `actor-var-polling-default-nil/` in swift-foundations/Experiments/ had the dir but no index entry).

Both conditions indicate prior sessions updated one but not the other. Future relocation sessions MUST update both index and disk in the same commit wave to avoid perpetuating drift. A detection pass — "every dir has an entry, every entry has a dir" — run at the start of each orphan-triage cycle would surface drift before it compounds.

### SUPERSEDED preservation pattern

Several experiments at `swift-primitives/Experiments/` carried SUPERSEDED status pointing to canonical consolidations already at `swift-institute/Experiments/` (e.g., `noncopyable-access-patterns`). Per [EXP-018] Experiment Consolidation, the originals are archived, not deleted — they serve as breadcrumbs pointing to the consolidated home. The orphan triage preserved this pattern: the 8 SUPERSEDED originals were moved to `swift-institute/Experiments/` alongside their consolidation targets, where they continue to point readers to the canonical artifact.

## Outcome

**Status**: DECISION

**Decision**: Relocate per Option C + codify the no-layer-level-containers rule.

**Execution** (2026-04-24):

- 46 experiment relocations (35 → `swift-institute/Experiments/`, 9 → per-package, 1 Research-routed, 1 parent-pre-moved).
- 88 research documents relocated (bulk from swift-primitives/Research/ → swift-institute/Research/; targeted per-package from swift-foundations/Research/).
- 16 audit artifacts relocated to `swift-institute/Audits/` with descriptive slugs.
- 7 HANDOFF-*.md triage decisions (3 deleted as landed, 4 relocated to owning sub-package repos).
- 3 layer-level `CLAUDE.md` + 2 empty audit.md templates deleted (redundant / no content).
- 11 commits across 10 git repos.

**Codified**:

- `experiment-process` [EXP-002], [EXP-002a], [EXP-002c], [EXP-003e] — layer-level `Experiments/` forbidden; two valid homes (`<pkg>/Experiments/` + `swift-institute/Experiments/`); worked-example table; valid-index-locations table.
- `research-process` [RES-002], [RES-002a], [RES-003c] — symmetric forbiddance for `Research/`; extended forbidden-subdirectory rule to cover non-underscore topical subdirs (`data structures/`).
- `audit` [AUDIT-002] — removed the "superrepo-wide" destination row; layer-level `Audits/` forbidden.
- Memory: updated `feedback_experiment_placement_by_dep_layer`; new `feedback_no_layer_level_artifact_containers` covering all four artifact domains uniformly.

**Deferred**:

- Documentation.docc/ migration from `swift-primitives/` + `swift-standards/` → `swift-institute/swift-institute.org/Swift Institute.docc/` (substantial content-migration scope; updates workspace-root CLAUDE.md Deep Links).
- `_index.json` rebuilds at `swift-institute/Research/` + `swift-institute/Audits/` (coordinate with prior-session WIP on those files).
- Per-file re-routing of 21+ package-named research docs currently bulk-moved to swift-institute/Research/ (each package's next audit/revision pass naturally does this).
- Layer-container superrepo-infrastructure cleanup (class-(c) orphans).

## References

- `HANDOFF-layer-container-orphan-triage.md` — the originating investigation brief (deleted post-preservation per handoff's own direction).
- `swift-institute/Research/Reflections/2026-04-24-layer-container-orphan-triage.md` — session reflection with action items.
- `swift-institute/Research/git-history-transfer-patterns.md` — heritage preservation via commit messages for cross-repo moves.
- `swift-institute/Research/coenttb-ecosystem-heritage-transfer-plan.md` — parallel heritage-transfer arc (different scope, shared dismantle context).
- Skill updates: `swift-institute/Skills/{experiment-process,research-process,audit}/SKILL.md` (commit history captures the rule additions).
- Memory: `~/.claude/projects/-Users-coen-Developer/memory/feedback_{experiment_placement_by_dep_layer,no_layer_level_artifact_containers}.md`.
- Path-dep rewrite precedent: `swift-primitives/swift-ownership-primitives/Experiments/*/Package.swift` at commit `992eb03`.
