---
date: 2026-04-23
session_objective: Dismantle swift-primitives / swift-foundations / swift-standards superrepos (local + GitHub) and create 3 PUBLIC .org stub repos
packages:
  - swift-primitives
  - swift-foundations
  - swift-standards
  - swift-institute/Research
  - swift-institute/Experiments
  - handoff
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: handoff
    description: "[HANDOFF-036] Recipe-and-Path-Math Empirical Verification — codifies recipe-staleness under post-state (e.g., git config command failing after gitdir cp) + path-math verification via python3 os.path.normpath."
  - type: no_action
    description: "AI 2 (multi-repo-dismantle-recipes canonical-home decision) deferred — corrected recipe is now embedded in [HANDOFF-036] worked example and [RES-024] empirical-reproduction rule. Standalone playbook can be authored later if a third dismantle cycle surfaces."
  - type: no_action
    description: "AI 3 (_index.json updates for 5 relocated Research + 3 Experiments) — addressed by 2026-04-30 corpus-meta-analysis Phase 10 sweep that backfilled 46 missing reflection-index entries. Research/_index.json + Experiments/_index.json gaps for the specific files cited still pending; will be caught by future corpus sweep."
  - supervise
status: pending
---

# Superrepo dismantle + interposed Phase 0.5 remediation; supervisor pushback as load-bearing safeguard

## What Happened

Session dispatched via `HANDOFF-superrepo-dismantle.md` (2026-04-23). Target: dismantle the three remaining superrepo structures (`swift-primitives/swift-primitives`, `swift-foundations/swift-foundations`, `swift-standards/swift-standards` — the last preserved per 5★+1fork), and create three PUBLIC `.org` stub repos. 4 originally-planned phases: Phase 0 verification, Phase 1 local `rm -rf .git`, Phase 2 archive 2 of 3 GitHub superrepos, Phase 3 create 3 PUBLIC `.org` stubs.

Phase 0 surfaced three classes of work-loss-risk anomalies beyond the expected submodule drift:

1. **swift-primitives** held 8 substantive untracked superrepo-level items (5 Research `.md` files totaling 3286 lines; 3 Experiments packages with `Package.swift` + `Sources/main.swift`) — none duplicated in `swift-institute/Research/` or `swift-institute/Experiments/`.
2. **swift-standards** had NO git remote configured, yet 39 local commits (oldest `2c0426a Initialize swift-standards as git repo with 94 submodules`, 2026-03-12); local state was unverifiable against the GitHub repo.
3. **swift-foundations** had 120 sub-repos using submodule-style `.git` files (`.git` as a file pointing at `../.git/modules/<name>`) rather than standalone `.git/` directories — these would break on container `rm -rf .git` unless converted first.

Escalated via `ask:`. First attempt framed "Proceed as planned" as (Recommended); principal rejected. Principal's supervisor characterized that option as "too aggressive" and directed an interposed **Phase 0.5 — Remediate before destroy**. Ground Rules 7 and 8 appended to the handoff's Supervisor Ground Rules block. Re-asked with neutral options and a Remediate-first alternative — accepted.

**Phase 0.5 execution**:
- **0.5a (Ground Rule 7)**: relocated the 8 items to `swift-institute/Research/` (commit `90ff193`, +3283 lines) and `swift-institute/Experiments/` (commit `880b516`, +1514 lines, with `.build/` stripped before move). Total 4797 lines preserved in canonical homes. Specific-file `git add` avoided sweeping in 5 pre-existing untracked Reflections.
- **0.5b (Ground Rule 8)**: added `origin` to swift-standards container (was no-remote), fetched, discovered **fully-disjoint histories** (no common ancestor): local 39 commits are container-bookkeeping; remote 240+ commits are the original monolithic swift-standards content (Collections/Binary/Geometry/Parser). Escalated via `ask:` with three neutral options (Discard / Preserve-by-push / Skip). Principal answered **Option 1: discard local**. Ground Rule 9 appended, grounded in the per-commit-class audit of the 39 local commits (submodule pointer bumps, "Save progress" snapshots, tools-version bumps, index schema — no production code; audit trail already in each sub-repo's own git).
- **0.5c**: 122/122 submodule-to-standalone conversions (120 foundations + 2 primitives, 5 with renamed module paths where subrepo directory name differs from modules/ entry name — e.g., `swift-pdf-render → modules/swift-pdf-rendering`). **Recipe deviation** from the handoff's prescription: `git config --file .git/config --unset core.worktree` fails because git resolves the now-broken worktree pointer before unsetting (`fatal: cannot chdir to '../../../<name>': No such file or directory`). Workaround: `sed -i.bak '/worktree =/d' .git/config && rm .git/config.bak`.

**Phases 1–3** proceeded as specified. Phase 1: three containers dismantled; sub-repos verified functional. Phase 2: `swift-primitives/swift-primitives` + `swift-foundations/swift-foundations` archived; `swift-standards/swift-standards` untouched (isArchived=false, 5★+1fork preserved). Phase 3: three PUBLIC stubs created via `gh repo create --public --source=. --push` at `swift-{primitives,foundations,standards}/swift-{primitives,foundations,standards}.org`, each with `README.md` (one-paragraph layer description + `swift-institute.org` pointer) + `LICENSE` (Apache 2.0, copied from `swift-institute/swift-institute.org/LICENSE.md`) + `.gitignore` (canonical block from `sync-gitignore.sh`, no overrides).

**Sanity build PASS** on 3 sub-packages: `swift-array-primitives` (47.52s), `swift-kernel` (33.87s, two pre-existing warnings unrelated to dismantle), `swift-html-standard` (80.67s).

**Supervisor verification**: All 6 Acceptance Criteria independently verified by the principal's supervisor. All 9 Ground Rules verified end-to-end per [SUPER-011]. Parent `HANDOFF.md` updated with completion status by the supervisor.

**HANDOFF scan**: 19 files at `/Users/coen/Developer/` root. Only `HANDOFF-superrepo-dismantle.md` in this session's cleanup authority (authored + actively worked); all others out-of-session-scope. Parent `HANDOFF.md` out-of-authority (supervisor updated it). Disposition of the in-scope file: all Next Steps complete + all 9 ground-rules entries verified + one escalation resolved → delete per [REFL-009].

## What Worked and What Didn't

**Worked**:

- **Parallel Phase 0 fact-gathering**: multiple Bash calls in one message (git status × 3 containers, `gh repo view` × 3 repos, consumer sweep, `.gitmodules` diff, sub-repo `.git` type enumeration) — efficient, comprehensive, surfaced all three anomaly classes in one round.
- **Test-on-one before batch**: swift-html conversion recipe validated as a single case before the 119-repo swift-foundations batch. The `core.worktree` failure surfaced in the test; the batch ran with the corrected recipe.
- **Specific-file `git add`** during relocation commits: prevented sweeping in the 5 pre-existing untracked Reflections in `swift-institute/Research/`. Respects CLAUDE.md's `git add -A` caution.
- **Background builds** for sanity verification: 3 `swift build` invocations in parallel via `run_in_background`; no context blocking; notifications on completion.
- **Escalation format, second attempt**: neutral options, no (Recommended), explicit Remediate-first alternative, concrete facts in the question body. Accepted without iteration.

**Didn't work (session-internal)**:

- **First `ask:` framing**: "Proceed as planned" labeled (Recommended). Principal rejected the question entirely. The correction was load-bearing: re-framing opened the path to Phase 0.5, which preserved 4797 lines of content that would otherwise have orphaned. New memory `feedback_destructive_workstream_escalation` written in-session to encode the lesson.
- **swift-foundations batch conversion, first attempt**: tool output was lost (`[Tool result missing due to internal error]`). State check showed `FILE=119` unchanged — the command had not actually run. Re-ran with a quieter variant (no per-line output, only totals + failures); succeeded.
- **`gh repo view` field**: first attempt used `watcherCount` (invalid); corrected to `watchers` (object with `totalCount`). Minor friction, immediate fix.

## Patterns and Root Causes

**Pattern 1: Destructive workstreams with uncatalogued substantive content.**
The 8 swift-primitives items were discovered only because Phase 0 enumerated untracked files. If the first-attempt "Proceed as planned" recommendation had been taken, those 4797 lines would have persisted on disk as untracked files in the resulting plain directory — outside any git tracking trail, discoverable only by manual `ls`, eventually lost to the author's mental index. The value of the Remediate-before-destroy rule is NOT that files stay on disk — they would have either way. The value is that they stay on disk *in a canonical tracked location*. The tracking trail is the asset, not the bytes.

The root cause of the uncatalogued content is the natural drift between "work-in-progress on a superrepo" and "work that belongs at a canonical ecosystem home." Research drafts and experiment packages start life in whatever superrepo the author is focused on, then accrue there unless someone explicitly relocates them. A dismantle is the forced moment of reckoning. Doing the reckoning properly requires treating Phase 0 as a full enumeration, not just a git-status spot-check — and treating `git status` output (even seemingly innocuous `??` entries) as candidates for substantive content that must be inspected.

**Pattern 2: Prescribed commands vs. the post-state they operate in.**
The handoff prescribed `git config --file .git/config --unset core.worktree` as the final step of the submodule-to-standalone recipe. The command is correct *in general* — git supports config unset via `--file`. But in the dismantle's specific post-state (gitdir has just been copied to a new location; `core.worktree = ../../../<name>` from the old location is now invalid), git's implementation dereferences the worktree before allowing unset, which fails with `fatal: cannot chdir`. The command's preconditions are not the post-state the recipe produces.

This is a specific instance of [HANDOFF-016]'s staleness axes — specifically *"proposal staleness"* expressed as a *recipe whose command is valid only under preconditions the handoff does not guarantee*. The handoff author likely knew the command in another context (where `core.worktree` was still valid or absent) and transplanted it without re-validating in the conversion context. The detection mechanism is test-on-one-before-batch: the recipe failed on the first sub-repo, surfacing the precondition gap before it caused 119 silent breakages.

Generalizable rule: when a handoff prescribes a command as part of a destructive-or-irreversible recipe, test on one instance first; when the command fails, root-cause the precondition mismatch before generalizing.

**Pattern 3: Supervisor pushback as load-bearing safeguard.**
The first `ask:` was structurally correct: options, context, clear question, sufficient facts. Framing was the flaw — "(Recommended)" on the destroy-path option. The supervisor's response characterized this as "too aggressive" and explicitly directed a hybrid path (Phase 0.5). The eventual 4797-line preservation validates the correction as substantive, not stylistic.

Why did the framing default to destroy-path-as-Recommended? Two contributors: (a) auto-mode favors action over asking, and I had internalized that as *"pick a reasonable default"* rather than *"present neutral options in destructive contexts"*; (b) the handoff itself was framed as a completion task ("dismantle + create stubs"), which biased toward proceed-style recommendations. The correction needed was to separate "I have a view on what's right" from "what I offer the principal as the headline option" — the former is fine; the latter must stay neutral when destruction is involved.

The new `feedback_destructive_workstream_escalation` memory captures this in rule form. The test of its value is whether a future dismantle-class session surfaces discovered anomalies with neutral options on the first `ask:`.

## Action Items

- [ ] **[skill]** handoff: Extend [HANDOFF-016] staleness axes with a "recipe/command staleness" clause — commands prescribed in handoffs may be correct in general but fail under the specific post-state the recipe produces. Concrete example for the skill: `git config --file .git/config --unset core.worktree` fails after a gitdir copy because git resolves the now-broken worktree before unsetting; alternative is `sed -i.bak '/worktree =/d' .git/config`. Cross-reference to the test-on-one-before-batch detection pattern.
- [ ] **[research]** Canonical home for multi-repo dismantle/conversion recipes: the submodule-to-standalone conversion pattern (parse `.git` file's gitdir target → `rm` → `cp -r` → sed-delete `worktree =` → verify with `git log -1`, handling renamed modules) came up in this dismantle and will recur for any future container-style superrepo. Candidate destinations: `swift-institute/Research/multi-repo-dismantle-recipes.md`, extension to the handoff skill, or issue-investigation skill. Decide and file.
- [ ] **[doc]** `swift-institute/Research/_index.json` and `swift-institute/Experiments/_index.json`: add entries for the 5 relocated Research `.md` files (commit `90ff193`) and 3 relocated Experiments packages (commit `880b516`). Without index entries, the relocated content is not discoverable per [RES-003c] (2+ docs in a directory require an index entry each).
