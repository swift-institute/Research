---
date: 2026-04-17
session_objective: Split swift-institute into focused org repos, trim the website, and exercise the /handoff + /supervise composition on the Whitepaper task
packages:
  - swift-institute.org
  - swift-institute-Research
  - swift-institute-Experiments
  - swift-institute-Skills
  - swift-institute-Blog
  - swift-institute-Audits
  - swift-institute-Swift-Evolution
  - swift-institute-Scripts
  - swift-institute-.github
status: pending
---

# Institute Repo Split and Supervise-in-Absentia Review Cycle

## What Happened

Session had two major operational arcs and one process arc.

**Arc 1 — Splitting `swift-institute/swift-institute` into focused repos.** Started with a mono-repo holding DocC site, blog, research, experiments, skills, audits, Swift Evolution drafts, scripts, and deferred articles. Executed in two rounds via `git subtree split`. Round one: Research and Experiments. Round two (later in the same session): Audits, Blog, Skills, Swift-Evolution, Scripts. The website repo was also renamed `swift-institute/swift-institute` → `swift-institute/swift-institute.org` on GitHub. Local layout was restructured from flat (`Developer/swift-institute/` = repo) to org-mirror (`Developer/swift-institute/` = directory holding sub-repos as siblings: `swift-institute.org/`, `Research/`, `Experiments/`, `Skills/`, `Blog/`, `Audits/`, `Swift-Evolution/`, `Scripts/`, `.github/`). `Scripts/sync-skills.sh`, `sync-gitignore.sh`, and `sync-swift-settings.sh` were updated to account for the extra parent directory. `.claude/skills/` symlinks were regenerated to point at the new `swift-institute/Skills/` source. Deferred articles were moved from a `Deferred/` directory to per-article branches on the website repo (`deferred/architecture`, `deferred/embedded-swift`, `deferred/getting-started`, `deferred/platform`, `deferred/principles`). Five of the new repos (Audits, Blog, Skills, Swift-Evolution, Scripts) were set private; the other three (swift-institute.org, Research, Experiments) and `.github` are public. Public-facing docs (website README, CONTRIBUTING, org profile README) were scrubbed of links to private repos.

**Arc 2 — Trimming the website and squashing history.** The website repo was reviewed file-by-file; `HANDOFF.md` (never tracked), `.github/workflows/ci.yml` (validated `Experiments/` which no longer existed), and `.github/pull_request_template.md` (referenced workflows from other repos) were removed. `Swift Institute.docc/FAQ.md` had a broken `../CONTRIBUTING.md` link updated to the `.github` repo. Root `CONTRIBUTING.md` was moved out to `swift-institute/.github` so it becomes the org-wide default. DocC catalog was reorganized: eight card SVGs and the hero icon moved from `Swift Institute.docc/` root into `Swift Institute.docc/Resources/` (DocC resolves images by basename, so `@PageImage(source: "card-X")` references kept working). The root `index.html` redirect was changed from a visible `<body>` meta-refresh to `window.location.replace()` in `<head>` + empty body, eliminating the "Redirecting to..." flash. Finally the entire repo was force-squashed to a single `Initial release` commit via orphan branch. `main` was reset to this commit and force-pushed. 364 historical commits containing references to private code were removed from the public history. Live site at swift-institute.org verified up after each force-push.

**Arc 3 — Whitepaper task via /handoff + /supervise.** User asked to author a "Whitepaper" page under the homepage's "Go deeper" topic group that names the loop (design question → research → experiment → code → blog post). Authored `HANDOFF.md` with pre-staged recommendations (600–900 words, four sections, institutional voice). Invoked `/supervise` and embedded a 6-entry ground-rules block in HANDOFF.md Constraints. Subordinate ran in a new session in absentia per [SUPER-014a]; the user (re-engaging as live principal) revised the plan substantially — length grew to 2,500–4,000 words, a fifth "layered ecosystem" section was added, a sixth "Relationship to other artifacts" section was approved, and the amend-on-main pattern was replaced with a branch strategy. When the subordinate returned for review, the produced draft (6 sections, ~2,928 words) was reviewed against the *original* pre-staged plan, not the live-revised plan. The subordinate correctly flagged this per [HANDOFF-016] Proposal Staleness. Principal (this session) acknowledged the staleness, withdrew four critiques (delete §2, cut to 700–900, delete §6, amend+force-push), retained two (swap the closing paragraphs of "Why this shape", tighten §6 by ~20 words), and updated HANDOFF.md to reflect current state: resolved open questions, revised ground rules (branch-strategy entry #1 replacing amend-on-main), updated acceptance criteria.

Deploy workflow was also tightened during the session: `if: github.ref == 'refs/heads/main'` was added as a defense-in-depth gate against `workflow_dispatch` from non-main branches deploying the site, and the macOS runner was bumped from `macos-15` to `macos-26`.

## What Worked and What Didn't

**Worked:**

- `git subtree split --prefix=<dir> -b <branch>` cleanly produced publishable histories for seven directory moves across two rounds. The established pattern (split → push split branch to new repo → clone new repo → add LICENSE/README/.gitignore → commit → push) ran without incident each time.
- The org-as-directory mirror layout (Developer/swift-institute/ holding sub-repos as siblings) turned out to be a one-time script adjustment rather than a pervasive change. One extra `dirname` in each sync script plus a `get_repo_path` special case for "swift-institute" covered all three scripts.
- Per-article deferred branches (one article per branch, the other four deleted on each branch) cleanly solved the "remove from main but keep accessible" problem. Much cleaner than a `Deferred/` directory that lives alongside website content.
- Squashing to a single commit to discard 364 commits of private-code-referencing history was the correct move and worked exactly as `git checkout --orphan` advertises. Force-push-with-lease succeeded; deploy re-ran; live site was consistent within two minutes.
- `/supervise` composition with `/handoff` via an embedded ground-rules block in Constraints worked as designed — the block carried across the session boundary and the subordinate recognized and acted on it.

**Didn't work:**

- The supervisor review cycle applied the ORIGINAL HANDOFF.md's pre-staged recommendations to the produced draft, not the user-revised recommendations from live conversation with the subordinate. The subordinate had to push back with a structured list of what was live-revised. The principal-returning-to-review step is the exact failure mode [HANDOFF-016] describes as Proposal Staleness, but the specific sub-case (proposals revised via live-supervision while the block's author was offline) is not directly surfaced in the existing skill text.
- The subordinate produced a whitepaper ~3× the original budget and with two extra sections. Normally this would be drift per [SUPER-006]; in this case it was user-authorized in live conversation. The principal had no way to distinguish authorized scope expansion from drift without re-reading the subordinate's conversation transcript.
- The initial `/reflect-session` invocation would have mis-filed this reflection had memory `feedback_reflection_routing.md` not specified "Reflections go in relevant ecosystem's `Research/Reflections/`". The local layout change (Research as a separate repo) made the routing less obvious.

**Confidence assessments:**

- High confidence on the mechanical parts (subtree splits, squash, restructure, sync-script fixes, .github repo setup).
- Medium confidence on the supervisor-review cycle — the reject-and-redo was done per [SUPER-008], but the review's basis was stale, which is a worse failure than rejecting valid work.
- High confidence on the content triage (FAQ contradiction fix, Research/Experiments refactor to external-facing voice, removing dead CI, removing stale PR template).

## Patterns and Root Causes

**The supervisor's hardest job is distinguishing drift from user-authorized scope revision.** When the principal is in absentia and the user is live with the subordinate, every [SUPER-006] drift signal can be either *actual drift* or *live-authorized revision*. The ground-rules block can't carry revisions because there's no writer to append them. The subordinate can't append them either, per [SUPER-014a] — self-authoring in absentia is structurally indistinguishable from drift. The revision exists only in the live conversation transcript, which the returning principal does not read by default.

The mechanism that catches this is the subordinate's explicit surfacing — a structured "what the principal flagged, what was actually user-revised" response. That worked here because the subordinate pushed back articulately. If the subordinate had been less assertive, the principal's stale critique would have been acted on, and user-authorized content would have been deleted. The subordinate shouldered the cost of the failure; that's fragile.

Structural mitigations that would reduce the failure rate:

1. When the principal authors a HANDOFF.md with pre-staged recommendations under Open Questions, those recommendations should be flagged "PRE-STAGED — expect user revision" rather than embedded as if authoritative. The current handoff template doesn't distinguish pre-staged recommendations from resolved decisions.
2. When the principal returns for review, the first step should be "check for user revisions since the block was authored" — either via a prompt to the user ("has the plan changed since the handoff?") or via a structured update the subordinate stamps into HANDOFF.md before handing back for review. The latter is cleaner: a `## Live Revisions` section in HANDOFF.md that the subordinate maintains.
3. [SUPER-006] drift signals should carry a "check user-authorization" qualifier in the procedure — "signal #3 (scope expansion): before treating as drift, confirm with the subordinate whether the expansion was user-authorized."

**The org-as-directory pattern is a legitimate new layout convention, not a memory violation.** `feedback_flat_disk_layout.md` (memory) had "all orgs flat siblings under Developer/" as an absolute rule. Today's restructure violated the rule for exactly one org (swift-institute). The memory was updated to record the exception rather than hold the rule rigid. This is the healthy memory-update pattern: when a rule's "why" still applies to most cases but a well-motivated exception exists, the memory records the exception with its own rationale, rather than being either deleted or left in rigid contradiction with reality.

**Squashing to a single commit to discard history is an underused maintenance technique for repos transitioning private → public.** The website repo had 364 commits, many of which referenced packages (by name), files (by path), and processes (by workflow) that are now in private repos. Individually fixing each reference in each commit would have been impractical. A single orphan-branch commit preserves only the current state. The trade-off is loss of authored history; the gain is a clean public record with no backward leaks.

## Action Items

- [ ] **[skill]** handoff: extend [HANDOFF-016] with a sub-case for live-supervision revisions — when the principal authors pre-staged recommendations and the user takes over live-supervision, the subordinate should stamp a `## Live Revisions` section into HANDOFF.md before the principal returns for review. Returning principal's first action is to read this section, not apply the original block.
- [ ] **[skill]** supervise: add guidance under [SUPER-006] drift signals — before treating signal #3 (scope expansion) or signal #6 (silent decision) as drift, a returning principal MUST first check whether the expansion or decision was user-authorized during live supervision. Explicit subordinate-side surfacing (structured pushback) is the current mechanism; the skill should name it and give it a required form.
- [ ] **[research]** When should the org-as-directory mirror pattern be used vs. the flat layout? The swift-institute org now uses it; swift-primitives, swift-standards, swift-foundations don't. The decision rule isn't formalized. Write a short research note comparing the two structures and when each is appropriate.
