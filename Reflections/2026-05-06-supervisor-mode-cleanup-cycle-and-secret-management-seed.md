---
date: 2026-05-06
session_objective: Continue the 2026-05-06 CI/CD security cohort under explicit supervisor-only mode; close G10 (bot install permissions audit + trim), publish uniformity audit, finalize D4 cohort (community-health sync + .swiftlint.yml thin pass-through), execute Option A (organization_secrets:read for verification), seed private-repo-secret-management-at-scale research, clean up working trees
packages:
  - swift-institute/.github
  - swift-institute/Skills
  - swift-institute/Research
  - swift-standards/.github
  - swift-foundations/.github
status: pending
---

# Supervisor-mode cleanup cycle, secret-management research seed, and the brief-vs-state staleness incident

## What Happened

This is the second reflection for 2026-05-06 — the first
(`2026-05-06-ci-reviewer-feedback-rollout-permissions-pitfall-and-doctrines.md`)
covered the morning's M2 / Cohort A1 / cross-ecosystem-reuse rollout. This
reflection covers the afternoon arc, distinguished by the principal's
mid-session directive *"this chat is supervisor only from now"* — fundamentally
shifting my role from author/executor to supervisor/relay.

**Supervisor-mode arc** (~6 hours wall-clock, multiple subordinate batches):

The principal established this chat as advise-and-relay. Subordinate(s) in
parallel chats executed implementation; I verified, advised, and authored
copy-pastable per-action authorizations the principal sent forward. This
required re-reading workspace state before each new directive — a discipline
that surfaced one breakdown (see Patterns).

**G10 cohort closure — bot installation permissions audit + trim:**

- Subordinate enumerated swift-primitives bot installation: 17 declared
  permissions vs 5 inferred-needed (catastrophic over-permissioning).
- Surfaced the load-bearing finding: `secrets: write` and `members: write`
  unexercised but high-blast-radius.
- Principal trimmed these two via App-owner edit
  (`https://github.com/settings/apps/swift-institute-bot/permissions`) —
  cascade propagated to all 17 installations immediately. Spot-check verified
  declared count went 17 → 15.
- Subordinate enumerated remaining 16 orgs via read-only `gh api` loop (after
  resolving a zsh paste-error via writing the script to `/tmp/g10-enumerate.sh`).
  All 17 orgs uniform post-trim.
- G10 manifest committed and pushed (`aafbe80 → 59c6723` chain) at
  `swift-institute/.github/.github/actions/read-orgs/bot-installations.yaml`
  with structured representation: `installations:` sequence + `inferred_min:` +
  `kept_over_inferred_min:` + `trimmed:` blocks. Subordinate caught the v1.0.0
  shape's invalid YAML mixing (top-level sequence + mapping keys); restructured
  to top-level mapping with `installations:` as sequence-valued key.

**Skill amendments published** (`796e510` in swift-institute/Skills):

`[CI-080]` block-mode-flip protocol expanded from 6-step sketch to 7-step
protocol with allowlists. Three new rules: `[CI-081]` audit-step shell-input
trust-boundary pattern (generalized to "callers in any branch-protected
layer-wrapper repo" so it survives L2/L3 wrapper rollout), `[CI-082]`
binary-install version-bump protocol (re-lock SHA-256 in same PR; CI fails
closed on mismatch), `[CI-090]` reusable-vs-standalone permissions-shape rule
(codifying the M2 incident lesson), `[CI-091]` uniform-platform-matrix doctrine
(matrix is canonical platform contract; M4 REJECT as worked example).

**Security review v1.1.0 published** (~1133 lines, Tier 2 RECOMMENDATION) at
`swift-institute/Research/ci-cd-security-review.md`. v1.0.0 → v1.1.0 in
response to my independent supervisor assessment (8 surgical revisions, no
restructuring): enforce_admins trade-off paragraph, Wave-1 verification
extended with `gh api GET + diff`, NEW G10 / Cohort F (bot installation
permissions audit), `[CI-082]` proposal, `[CI-081]` generalization, T4a
Dependabot addendum, audit-log review cadence, L2/L3 layer-wrapper Wave-1
forward-reference. Authorization-gate count 12 → 13.

**Cross-ecosystem-reuse v1.1.1 rollout** (parallel subordinate, ~265 commits in
50 minutes): Phase 1 (layer-wrapper authoring at swift-{standards,foundations}/.github)
+ Phases 2-5 (caller migration across L2 / 11 L2 sub-orgs / L3 / 2 L3 sub-orgs).
Verified on disk: L2 wrapper at `079fefb`, L3 wrapper on remote (local was a
flat dir, since cleaned). All 258 callers route through layer wrappers; 0
stragglers. Per-package CI broadly red post-migration as expected (latent
build/test issues exposed; not regression).

**Uniformity audit** (`7b6c964 ci-uniformity-audit.md` v1.0.0 INVENTORY)
- D1 (wrapper-file content): DELIBERATE-DIVERGENCE (5 layer-specific jobs at L1)
- D2 (caller routing): UNIFORM (390/390)
- D3 (metadata.yaml schema): UNIFORM (390/390)
- D4 (host-repo health files): UNINTENTIONAL-DRIFT — L2/L3 missing
  ISSUE_TEMPLATE/config.yml + .swiftlint.yml + SECURITY.md; L3 also missing
  profile/README.md
- D5 (PRIVATE_REPO_TOKEN coverage): VERIFICATION-BLOCKED at audit time
- D6 (sub-org wrappers): UNIFORM (per [CI-004b])

**D4 cohort execution** (4 commits across L2 + L3; subordinate caught the
.swiftlint.yml content-judgment issue):

- ISSUE_TEMPLATE/config.yml + SECURITY.md verbatim copies (with sed
  substitutions for org names + URL paths) — 4 commits across 2 host repos.
- .swiftlint.yml: subordinate stop-conditioned correctly. L1's
  `.swiftlint.yml` carries L1-only rules (no Foundation, no platform
  conditionals, Cardinal/Ordinal/Vector enforcement) that would mis-fire on
  L2/L3. Authorized Option A (thin pass-through with parent_config to Tier 1,
  zero custom rules). Landed at `665e6be` (L2) + `bfd5524` (L3).
- L3 profile/README.md: principal-deferred per "lower priority, revisited
  later" — but actually was committed and pushed in an earlier cleanup batch
  (`32bb1ef`) under prior brief framing. Surfaced as brief-vs-state staleness
  (see Patterns).

**Option A executed — bot-driven secret coverage verification:**

Principal granted `organization_secrets:read` to swift-institute-bot via
App-owner web UI edit. Cascaded to all 17 installations. G10 manifest's
`inferred_min` extended to 6 entries. Sunday 2026-05-10 06:30 UTC cron-fire
(`lint-org-bot-coverage-weekly`) will be the first end-to-end verification of
Axis-2 (PRIVATE_REPO_TOKEN org-secret coverage). Closes the D5
VERIFICATION-BLOCKED finding.

**Private-repo-secret-management-at-scale research seed authored**
(`7db0bb3 private-repo-secret-management-at-scale.md` v0.1.0 IN_PROGRESS):

Principal raised the scaling concern: 17 orgs growing to 1000+ in short
horizon makes manual PRIVATE_REPO_TOKEN provisioning untenable (~120 hours/year
rotation alone at N=1000). I sketched four options (B: distribute App
credentials, C: bot writes secrets, C-split: two-App separation, E: OIDC +
external secret manager), with common-worst-case App-key-leak baseline framing
and decision criteria. Tier 2 seed; full investigation deferred to a separate
chat per principal direction.

**Working-tree cleanup** (5 commits across 2 host repos):

swift-standards/.github: pre-existing M profile/README.md improvement +
untracked dependabot.yml + untracked .github/. Stash + pull + restore +
commit + push as `5c662f6` (preserve) + `665e6be` (.swiftlint.yml).

swift-foundations/.github: was a flat directory (not a git checkout) with
local artifacts (dependabot.yml, profile/README.md draft, wrapper-file copy).
Backup to `/Users/coen/Developer/_backups/2026-05-06-swift-foundations-flat/`,
re-clone, restore dependabot.yml + L3 README from backup, commit + push as
`32bb1ef` (preserve) + `bfd5524` (.swiftlint.yml). Backup retained per directive.

**Branch protection education + decision:** principal asked *"What is branch
protection anyway?"* mid-supervisory-flow. Plain-language explanation produced
(server-side gate with checklist; specific knobs; chokepoint reasoning;
enforce_admins trade-off; reversibility). Principal then chose: **defer
branch protection — optimize for development velocity right now.**

**HANDOFF scan**: 30+ HANDOFF-*.md files at `/Users/coen/Developer/`. 2
authored or actively-worked by this session: `HANDOFF-ci-cd-security-review.md`
(deleted by subordinate after Findings appended + RECOMMENDATION promoted) and
`HANDOFF-ci-cd-cross-ecosystem-reuse.md` (deleted by me earlier today —
prematurely, before subordinate's v1.1.1 revision; no information loss because
Research doc carries content). 1 in-flight from parallel SwiftLint-rollout
supervisor (`HANDOFF-r1r4-cleanup-wave-1.md` and ~3 r1r4-* siblings; no-touch
per [REFL-009a]). Remaining ~26 are out-of-session-scope from earlier sessions.

## What Worked and What Didn't

**Worked:**

- **Subordinate discipline at content-judgment boundaries.** The .swiftlint.yml
  stop-condition was textbook: subordinate caught that verbatim copy of L1
  rules to L2/L3 would impose Foundation-import bans on layers expected to
  have Foundation-Integration subtargets. Stopped, surfaced three options,
  awaited authorization. This is exactly the [SUPER-024] pattern working as
  designed — content-judgment gates trigger principal arbitration rather than
  silent execution.

- **Read-only verification as architectural-leverage primitive.** G10's read-only
  enumeration plus Option A's `organization_secrets:read` give the bot
  visibility-without-authority across the ecosystem. This pattern composes
  cleanly: low blast radius, principal-rule-compatible (admin via web UI;
  read-only gh CLI for the rest), and produces empirically-grounded provisioning
  manifests as durable artifacts. Sunday cron's first fire will exercise the
  full chain.

- **Threat-model analysis under common-baseline framing.** When evaluating
  PRIVATE_REPO_TOKEN options, the observation that "the bot already has
  contents:write everywhere → App-key leak is already catastrophic baseline"
  reframed the decision. Marginal increase from `secrets:write` is small
  relative to the existing surface, which made Option C tractable to discuss
  honestly. The framing shifted the conversation from "secrets:write is scary"
  to "what bounded incremental risk does each option add over the existing
  baseline." Higher-quality research seed as a result.

- **Educational pause when the principal asked.** *"What is branch protection
  anyway?"* mid-supervisory-flow could have been answered briefly. Slowing for
  a complete plain-language explanation (the checklist analogy, specific knobs,
  chokepoint reasoning, trade-offs) preserved decision quality. Principal then
  decided informedly: defer. The decision was different from my recommendation,
  but it was an informed decision.

**Didn't work:**

- **Brief-vs-state staleness in the second cleanup brief.** I authored a second
  cleanup brief without re-reading current state from the first cleanup brief's
  execution. The second brief said "DO NOT push L3 profile/README.md
  (preserved in backup only)" — but the FIRST brief had ALREADY committed and
  pushed it (`32bb1ef`). Subordinate caught the conflict, surfaced it, refused
  destructive revert without YES, and asked. Cost: one round-trip of
  clarification + supervisor self-correction. The subordinate's discipline was
  exemplary; the brief was the defect. Root cause: I held a mental model of
  "fresh state" rather than "post-prior-batch state" when authoring the second
  brief.

- **Authorization-trail uncertainty around 5044547 + 8cbe5c0.** Two commits
  landed on swift-institute/.github main earlier today (Q4 disclaimer +
  lint-org-bot-coverage advisory linter from cross-ecosystem-reuse v1.1.0/v1.1.1).
  Author identity = principal directly. Subordinate could not reconstruct an
  explicit `YES DO NOW <name>` per-action gate from session transcript. I
  flagged it as a discipline question; principal acknowledged ("per-action gate
  framework violations are fine") — closing the trail but exposing that the
  framework's per-action gate model doesn't fully account for principal
  direct-edits or rapid-wave authorizations. The 265-commit rollout in 50
  minutes was a similar case: framework expects per-phase gates, principal
  authorized a wave. Not wrong; under-codified.

- **Premature deletion of the cross-ecosystem-reuse handoff.** Earlier in the
  day during the morning's `/reflect-session`, I deleted
  `HANDOFF-ci-cd-cross-ecosystem-reuse.md` based on v1.0.0 Findings I'd seen,
  without knowing v1.1.1 was actively in flight. The Research doc carries
  forward the canonical content so no information was lost — but the audit
  trail is muddied. I should have respected the bounded-cleanup-authority rule
  more carefully ([REFL-009]'s rule about not deleting in-flight or
  actively-worked handoffs).

**Mixed:**

- **Multi-subordinate parallelism.** The principal had at least two parallel
  subordinate chats running (one for security-review work I supervised, one
  for cross-ecosystem-reuse rollout). Most of the time the supervision worked
  cleanly because the work was orthogonal; occasionally the trails crossed
  (e.g., the rollout's 5044547+8cbe5c0 landed on a repo I was concurrently
  supervising). The framework benefits from knowing about parallel dispatches
  but doesn't strictly require it; supervisor mode tolerates mild parallelism
  but not unbounded.

## Patterns and Root Causes

**Pattern 1: Brief-vs-state staleness when authoring follow-up briefs in the
same scope.** This is the day's most concrete supervisor-discipline gap. The
defect mechanism: when authoring a second brief in a scope where the first
brief already executed, the supervisor is tempted to re-author from a "clean
slate" mental model rather than re-read the post-first-brief state. The clean-slate
model is faster but produces acceptance criteria that don't match observed
reality. The cost is a forced clarification round-trip when the subordinate
catches the conflict (cheap, ~1 message), or — worse — a destructive action if
the subordinate doesn't catch it. The subordinate caught it cleanly today;
that's a live success but not an architectural one.

The fix is mechanical: before authoring a follow-up brief in a scope that's
seen earlier execution, re-read the affected workspace state (git log, file
contents, remote heads) and validate that proposed acceptance criteria match
observed reality. ~30 seconds of read-only work to avoid the staleness defect.
This generalizes [REFL-006]'s "re-verify after edit" rule from intra-edit
verification to inter-brief verification — same discipline, different temporal
scope.

**Pattern 2: The per-action-gate framework strains at velocity.** [CI-052]'s
per-action-gate model assumes "principal authorizes one thing, subordinate
executes one thing, repeat." Today's rapid-wave authorizations (Phases 1-5 in
50 minutes; principal direct-edits 5044547+8cbe5c0; wave-style trim of
secrets:write+members:write across 17 orgs in one App-owner edit) all worked
operationally but didn't fit the strict per-action-gate model. The principal's
acknowledgment ("per-action gate framework violations are fine") closes the
trail but doesn't resolve the structural question: how should the framework
handle (a) principal direct-edits, (b) rapid waves, (c) cascade actions like
App-owner edits that propagate to N installations.

The pragmatic resolution today: violations were tolerated because the actions
were correct and reversible. The architectural answer requires either a typed
"wave authorization" rule alongside `[CI-050]` / `[CI-052]`, OR explicit
acknowledgement that the framework is permissive for principal direct-action
and strict only for subordinate dispatch. Worth codifying so future sessions
don't re-rasie the question.

**Pattern 3: Read-only verification as architectural primitive at ecosystem
scale.** G10 + Option A together establish a pattern: the bot acquires
read-only permissions to verify state across orgs, but write/distribution
remains principal-mediated via web UI. This composes with the "admin via web
UI, never gh CLI admin" standing rule (principal-only write paths) and with
existing [CI-058]–[CI-060] free-plan-visibility framework. The pattern scales
naturally — adding a new org to the verification surface = installing the bot
+ secret(s) provisioned by principal, with no architectural change to the
verification layer.

This is a good architectural primitive worth naming. Proposed: "Read-only
verification with principal-mediated write" or similar. Distinct from the
"separation of duties" pattern (Option C-split) because it doesn't introduce
a second App; the bot's existing privileges are extended in the read direction
only.

**Pattern 4: Scaling pressure changes which option-tradeoff curve the decision
sits on.** The PRIVATE_REPO_TOKEN management discussion showed how the
"right" answer depends sharply on N. At N=17, Option A (verification + manual
provisioning) is adequate; ~2 hours/year operational cost. At N=1000+, A's
~120 hours/year is untenable, B's per-org provisioning burden dominates, and
C (or E) become the realistic terminal states. The decision is not about
which option is "better in absolute" — it's about which option's cost curve
is appropriate for the scale projection. Explicitly stating the scale
projection ("17 → 1000+ short horizon") changed the recommendation from
"keep current + verify" to "needs migration path." A general lesson: when
recommending architectural options, always state the scale assumption
explicitly so the recommendation is auditable when scale assumptions change.

**Pattern 5: Supervisor-mode is a load-shedding pattern, not a slowdown.** The
principal's "this chat is supervisor only" directive could be read as adding
indirection. In practice it accelerated the day: the parallel subordinate
chats executed implementation while this chat focused on verification +
authorization. The principal acted as router between chats. The bandwidth
multiplier was real.

The pattern works because the supervisor's role is well-scoped: read state,
verify subordinate claims, issue per-action gates, surface discipline
breakdowns. None of those require execution privileges; all require fast
read access to state. When the supervisor's role drifts toward
"co-executor" (e.g., authoring research files directly per /research-process),
the boundary needs explicit principal direction — which today's session got
("write the remainder as /research-process seed"). That's the exception that
proves the rule: supervisor authorship is gated on explicit principal
direction.

## Action Items

- [ ] **[skill]** supervise: codify the brief-vs-state-staleness rule as a
  typed [SUPER-*] requirement. Statement: when authoring a follow-up brief
  in a scope that has seen execution since the prior brief, the supervisor
  MUST re-read the post-execution state (git log, file contents, remote
  heads) and validate proposed acceptance criteria against observed reality
  before sending. Provenance: today's L3 profile/README.md acceptance-criterion
  conflict (the second brief said "DO NOT push" while the first brief had
  already committed + pushed).
- [ ] **[research]** expand `swift-institute/Research/private-repo-secret-management-at-scale.md`
  v0.1.0 IN_PROGRESS in a dedicated session per principal direction. Verify
  empirical sub-questions (workflow_call secrets-inheritance, gh-api
  404-vs-403 distinction, web-UI provisioning timing); conduct prior-art
  survey per [RES-021] (Apple swiftlang, Microsoft azure-sdk-for-*,
  HashiCorp terraform-providers, Rust rust-lang, Apache, sigstore docs);
  produce per-option operational + threat-model analyses; land terminal-state
  recommendation with phased migration path. Bump to v1.0.0 RECOMMENDATION.
- [ ] **[skill]** ci-cd-workflows: codify the "centralized-infra single-repo
  edit" rule-coverage gap as proposed `[CI-053]` or sibling. Statement:
  workflow-file edits to centralized-infrastructure repos
  (swift-institute/.github + per-layer wrapper repos) require explicit
  per-action authorization despite [CI-050]'s ≥3-consumer threshold not
  triggering — because the @main pinning of those workflows means a single
  push has fleet-wide blast radius. Provenance: today's 5044547+8cbe5c0
  authorization-trail discussion + the broader [CI-052] discipline conversation.
