---
date: 2026-04-17
session_objective: Research, design, and draft the swift-institute.org Whitepaper page; handle a supervisor review cycle; add a workflow_dispatch ref-guard and bump the macOS runner on the deploy workflow
packages:
  - swift-institute.org
  - swift-institute-Research
status: pending
---

# Whitepaper page design under live-principal direction — handoff staleness and amend/branch rebase mechanics

## What Happened

Session picked up `swift-institute.org/HANDOFF.md` with supervisor ground rules directing creation of a new DocC article called **Whitepaper** (600–900 words, 4 sections, institutional voice, confirm-before-drafting gate per ground rule #1). Presented the pre-staged recommendation to the user as approve/redirect/amend.

The user redirected: run `/research-process` on whitepapers first. Dispatched three parallel background agents (genre taxonomy; canonical technical whitepapers; research-institute methodology pages). Synthesized into `swift-institute/Research/swift-institute-whitepaper-design.md` (Tier 2, committed on a new `whitepaper` branch in the Research repo, per user direction to "put the whitepaper and related research on a separate branch"). Key research finding: **no surveyed research institute publicly names a four-node methodology loop (research → experiment → code → publication)**; Anthropic's three-node "Safety Is a Science" is the single precedent, and it is one sentence on a sub-page. This reframed the Whitepaper as genuinely differentiated and justified more length.

Recommendation revised to 1,500–2,000 words / 5 sections. User asked about including the layered approach (primitives / standards-as-organization-of-organizations / foundations). Expanded to 6 sections / 2,000–2,500 words with substantive architecture content. After reading the 1,407-word first draft, user expanded again to 2,500–4,000. Expanded again to 2,928 words. User corrected primitives framing ("vocabulary, not behaviour" was wrong — primitives DO implement behaviour, just not policy; they are "atomic units that compose predictably and are independently verifiable"). Applied.

Committed the page + `card-whitepaper.svg` + homepage topic-group edit on the `whitepaper` branch (`694d03d`). The user relayed a supervisor review recommending reject-and-redo: cited 6 vs 4 sections, length vs 600–900, "The layered ecosystem" as duplicate of Layers.md, weak closing, redundant Relationship section. User flagged that the supervisor lacked live-conversation context and asked for my take.

Identified most critiques as context gap (supervisor reviewed against the pre-draft HANDOFF.md that had not been updated with in-conversation scope revisions). Two critiques held on their own terms: the "Why this shape" section closed on "discipline, not a proof" (a fatalistic beat), and "Relationship to other artifacts" was slightly over-elaborate. The supervisor conceded the context-gap reads, applied the two surviving critiques (paragraph swap + trim), and updated HANDOFF.md. Applied both edits (`18a7d34`).

Separately, the user directed two infrastructure changes on `main`: add `if: github.ref == 'refs/heads/main'` to the deploy workflow (limiting `workflow_dispatch` to main) and bump `runs-on: macos-15` → `macos-26`. I first proposed putting the guard on the whitepaper branch; the user correctly redirected: infrastructure belongs on main, other branches rebase. Amended `Initial release` on main with the guard; standard `git rebase main` on the whitepaper branch failed with an add/add conflict because amending changed main's SHA; resolved via `git rebase --onto main 23412b3`. User then directed `macos-26` and "latest of the latest only" — verified `macos-26` is a live GitHub runner via `gh api repos/actions/runner-images/releases` and confirmed all other action pins are already at latest majors. Second amend on main; second rebase on whitepaper. Saved `feedback_latest_versions_only.md` to memory.

Handoff cleanup: HANDOFF.md was already updated by the supervisor mid-session after the false-drift review; stamped verification for all six acceptance criteria and all six ground-rule entries (all verified); disposition per [REFL-009] is delete (gitignored, local-only, all work complete). Pending deletion after this entry lands.

## What Worked and What Didn't

**Worked.** Parallel background research agents produced 400–900 words of verified primary-source content each in 2–4 minutes, with URLs and verbatim headings rather than reconstructed-from-memory text. Research as a de-risking step genuinely changed my recommendation — without the prior-art survey, I would have committed to a thin recommendation anchored on intuition. The `git rebase --onto main 23412b3` form resolved the amend-changed-hash rebase cleanly and should be the standard move for this repo's amend-on-main pattern combined with feature branches. The supervisor cycle, even with mostly-stale critiques, surfaced two real improvements (paragraph swap + Relationship trim). `feedback_latest_versions_only.md` captures a proactive-habit lesson that closes the "lazy-carry old version pins on touched workflow files" gap.

**Didn't work.** I carried `macos-15` through the first workflow edit without checking whether it was still current — the user flagged it. I initially proposed putting the workflow ref-guard on the whitepaper branch (correct for *protecting* whitepaper from workflow_dispatch abuse, but wrong for ecosystem hygiene — infrastructure belongs on main). HANDOFF.md was not kept current as the user revised scope in live conversation; the supervisor review then fired against stale ground rules and produced a reject-and-redo that was correct against its inputs and wrong against actual state. The first `git rebase main` invocation failed on add/add conflict — I anticipated a conflict might happen but didn't pre-compute the correct `--onto` form before invoking the default.

## Patterns and Root Causes

**Handoff staleness under live-principal direction.** This is the session's highest-value pattern. `/supervise` and `/handoff` both assume HANDOFF.md encodes the principal's authoritative direction — the supervisor's review applies the constraints captured there. [SUPER-014a] handles the *subordinate in absentia* case (no live principal, ground-rules block is the only authority). It does not handle the COMPLEMENT: **live principal actively directing in chat**. In that mode, the user is revising scope conversationally, but HANDOFF.md reflects only the state at dispatch. A review fired against the un-updated doc correctly maps to the old constraints and incorrectly describes actual state — the "reject-and-redo" verdict was high-confidence and wrong.

Root cause: the protocol for propagating live-principal decisions to the durable doc is implicit. When the user says "expand to 2,500–4,000 words" in chat, that is a principal decision — it should land in HANDOFF.md before any review fires. Neither `/handoff` nor `/supervise` currently makes that propagation step explicit, so the subordinate (me) experiences the revisions as conversational updates and the supervisor experiences the doc as ground truth, and the two diverge silently until a review cycle exposes the gap.

**Research-as-de-risking against intuition anchoring.** I gave an initial recommendation based on my read of the handoff. It was wrong — substantially so. The user's "run `/research-process` first" intuition was valuable because it unhooked me from the anchor. The prior-art survey produced two load-bearing findings I could not have produced from intuition alone: the whitepaper-genre word-count floor (~2,000), and the "no institute publicly names a four-node method loop" differentiation. Both shifted the recommendation meaningfully. The pattern: **for design decisions on open-ended text artifacts, schedule research before recommending**, not as a verification step after.

**Amend-on-main + feature branches requires `--onto`.** The established single-commit amend pattern on `swift-institute.org` produces a clean main history. Feature branches rebase onto amended main — but only with `git rebase --onto main <old-base>`, because amending changes main's tip SHA and `git rebase main` from a branch that originated at the old SHA tries to re-apply the old Initial release commit and add/add-conflicts against its amended successor. This is a niche mechanic that's important for any repo following this amend pattern; right now it lives in session memory, not in any written rule.

**Adversarial review has value even when most critiques are stale.** The supervisor's reject-and-redo was mostly context gap. Two critiques held on their own terms. Without the cycle, the page would have shipped with a fatalistic section close and a slightly bloated Relationship paragraph. Adversarial review keeps catching real issues even through noise — the cost of cycling is low relative to the quality delta.

**Version-pin staleness is a habit problem, not a one-shot action.** Catching `macos-15` required the user's prompt. The feedback memory generalizes the lesson, but the deeper pattern is: **a touched file with N version pins is a prompt to check all N**. That's the habit the memory encodes, not just "don't be lazy about macos runners."

## Action Items

- [ ] **[skill]** handoff: Add a rule that live-principal scope revisions (via conversation rather than HANDOFF.md edits) MUST be propagated to HANDOFF.md before the session closes OR before invoking `/supervise` for a new review. Cross-reference [SUPER-014a] as the complement case ("no live principal" → ground rules binding; "live principal in chat" → ground rules updatable only by propagating conversation decisions). Proposed requirement ID: [HANDOFF-017] Live-Principal-Decision Propagation.

- [ ] **[skill]** supervise: Add guidance for the "live principal active in chat" case. Supervisor reviews under this condition MUST require a context refresh (either a fresh HANDOFF.md update from the subordinate OR an inline conversation summary) before firing, to avoid high-confidence reviews against stale principal decisions. Cross-reference [HANDOFF-017] once the handoff skill lands the propagation rule.

- [ ] **[blog]** The four-node methodology loop (research → experiment → code → blog) as *differentiated institutional positioning* — the prior-art survey in `swift-institute-whitepaper-design.md` found no surveyed research institute publicly names this loop as a standalone page. Anthropic's three-node "Safety Is a Science" is the only precedent, and it is one sub-page sentence. Worth a blog post once the Whitepaper page is live, citing the research doc as the survey source.
