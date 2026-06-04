---
date: 2026-06-04
session_objective: Teach the centralized reusable CI chain to resolve private org dependencies via swift-institute-bot App tokens, fixing the public-cohort dep-resolution redness generically (Porter arc, principal option (b))
packages:
  - swift-institute/.github
  - swift-primitives/.github
  - swift-standards/.github
  - swift-foundations/.github
  - swift-institute/Skills
status: pending
---

# Porter arc: private-dep CI resolution, the cross-org secret-transport discovery, and the silent startup-failure class

## What Happened

Single-day supervised arc (subordinate seat "Porter"; seat + principal via relay). Delivered, in order: (1) the App-token resolution design (Research Option B) — `configure-private-repos` mints per-job contents:read installation tokens for the three layer orgs with env-scoped org-prefixed insteadOf rules, legacy `PRIVATE_REPO_TOKEN` as fallback, dual ID-name contract (`_APP_CLIENT_ID` preferred, legacy `_APP_ID`); (2) the **[CI-109] discovery**: `secrets: inherit` delivers no org secrets across an org boundary — proven by paired in-run evidence ("Configured 0" cross-org-inherit vs "Configured 4" same-org-inherit→explicit, byte-primitives run 26959288611) — which flipped [CI-004a] (docs wrappers now REQUIRED for secret transport) and spawned the [CI-059] sub-org caveat (pattern (ii): explicit-forward at sub-org thin callers); (3) three layer docs-wrappers + 436/440 consumer repoints across 16 orgs (332+102 wave + canaries; 4 parallel-WIP-gated leftovers); (4) the validator-flood kill: ONE defect — bare `${{ inputs.dry-run }}` into a typed-boolean input startup-fails on inputs-less events (push/PR) with zero jobs and **no logs** — explained every red since Phase B-1; fixed across 18 callers (now **[CI-110]** with its diagnosis signature `failure + njobs=0 + no fetchable logs`); plus a validator bug (MOD-005 read dump-package's `sources: null` as `[]` → 20 false positives); (5) both May batch-fixes found ALREADY LANDED → double [SUPER-024] no-op against stale records; (6) the provisioning runbook (Research v0.2.0) incl. the **Configured 0/1/3/4 verification ladder** — 3-vs-4 distinguishes dead-legacy orgs from healthy-legacy, confirmed on two freshly-provisioned orgs; (7) the **two-org legacy degradation finding**: `PRIVATE_REPO_TOKEN` exists-but-doesn't-deliver on swift-primitives AND swift-ietf — the axis-2 existence check cannot see delivery.

HANDOFF scan ([REFL-009]): `HANDOFF-ci-private-dep-access.md` — consumed, seat-authorized retirement to `.handoffs/.trash/` after the [SUPER-011] stamp (verification line present at rev 12). No other handoffs in this session's cleanup authority (others at `.handoffs/` left untouched, out-of-scope). No /audit invoked.

## What Worked and What Didn't

**Worked**: probe-before-design ([SUPER-009] named-blocker verification) paid out repeatedly — the bot-installation probe, the secrets-state inference, the sub-org public-repo probe, and the [HANDOFF-045]-style empirical-state checks that converted both May batch-fixes into honest no-ops. The paired in-run evidence design (same run, same org, same secrets, two paths) made [CI-109] undeniable in one observation. The mechanized [SUPER-052] window check produced two correct refusals (storage-primitives, a wave-d hold) after being adopted from deviation (i). Dry-running the wave-d transform on a /tmp copy + the amended validator before release meant zero mechanics risk at fire time.

**Didn't**: (i) the byte-primitives canary push over-carried Unify's `b03dbd9` — I compared intent, not `rev-list origin/main..main`; (ii) I cited Research as *private* under a visibility-scoped grant — it is PUBLIC per CLAUDE.md (the push-delta accusation was later corrected by reflog evidence, but the visibility misread was mine and real); (iii) BSD-grep's brace/`$` quoting bit me TWICE — including once *after* I had diagnosed it — producing false "0 matches" on `${{ … }}` literals; (iv) zsh non-word-splitting voided a whole local sweep silently; (v) a 6-line grep window made me misread CI-080's state as "missing" when the step sat at line 7; (vi) one walrus-in-comprehension syntax error shipped to 29 invocations before the parse check.

## Patterns and Root Causes

**Tool reach vs claim scope (the session's master pattern, three instances)**: startup_failure has *no logs* — so `--log-failed` greps return empty and even the seat's first-hand log read came back blank; the gate then mis-attributes silence. My truncated grep windows (CI-080 "missing" harden-runner) and the BSD-grep brace trap are the same epistemic class: **the tool's reach was narrower than the claim I derived from it** ([REFL-011] tool-reach extension, already codified — this arc adds the *Actions-workflow* instances: expression literals need `grep -F`; startup_failure needs the jobs-API signature, not logs). The [CI-110] diagnosis signature is the productized form.

**Silent-when-masked defects surface in pairs**: the original redness (empty legacy token, masked pre-MSB by all-public graphs) and the validator flood (boolean type-error, masked by dispatch-only validation) share one shape — *the failure path was never exercised by the validation path*. May's Phase-6 probes used dispatch (inputs exist); production used push (inputs don't). The α-fix's no-regression property (all-empty → anonymous) is the deliberate inverse: design the degraded path to equal the status quo, then staged rollouts can't break anyone.

**Existence checks are not delivery checks**: axis-2 verifies the org secret EXISTS; two orgs now show existence with zero delivery. Any future "secret present" assertion needs a delivery-side probe (the Configured-N echo is exactly that — an in-band delivery oracle, which is why the runbook's verification ladder is built on it rather than on settings pages).

**Records age; state doesn't**: the May batch-fix records, the seat's "institute-org-only App secrets" framing, my own rev-8 "held 33ddef6" line, and the (b)-canary's window all drifted from live state within days or minutes. Every divergence this arc was resolved the same way: re-derive from the primary source at the moment of action ([REFL-011]); the reflog-forensics method (refs/remotes/origin/main reflog distinguishing *which push event* moved the remote, with timestamps and "update by push" provenance) extends this to push-attribution disputes and corrected the seat's own ledger.

## Action Items

- [ ] **[skill]** supervise: [SUPER-052]-family amendment — before citing any visibility-scoped grant, verify the target repo's visibility class from the primary source (CLAUDE.md table or `gh repo view --json visibility`), not from memory; and add the reflog-forensics method (refs/remotes reflog, "update by push" events with timestamps) as the [SUPER-031]-family evidence form for push-attribution questions.
- [ ] **[skill]** ci-cd-workflows: workflow-grep discipline note — matching GitHub Actions expression literals (`${{ … }}`) MUST use `grep -F` (BSD grep parses `{`/`$` as pattern syntax and silently returns 0 matches); pairs with [CI-110]'s diagnosis signature as the "tooling traps when auditing workflows" cluster.
- [ ] **[research]** Delivery-side secret auditing: can the weekly coverage lint gain a Configured-N-style delivery oracle (a dispatchable no-op job per org that echoes which credential names resolved), replacing existence-only axis-2 — closing the exists-but-doesn't-deliver class the legacy token showed on two orgs?
