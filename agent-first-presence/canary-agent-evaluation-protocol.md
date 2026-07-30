# Canary agent-evaluation protocol (pre-registered, v1)

    record-kind: pre-registered-evaluation-protocol
    protocol-version: 1
    owner-issue: https://github.com/swift-institute/.github/issues/134
    governing-goal: https://github.com/swift-institute/.github/issues/126
    status: pre-registered, no trial has run
    grammar-version: staged-text/1

This document fixes, before any conversion or trial, the instrumented agent
evaluation that Goal
https://github.com/swift-institute/.github/issues/126 (agent-first authoring
standard) requires inside its canary gate. The Goal's abort path — "If the
evaluation shows no benefit, this Goal closes `not planned` with a linked,
separately assessed successor" — is honest only if the decision rule exists
before the measurement does. This protocol is that rule. It is authored under
https://github.com/swift-institute/.github/issues/134 and placed in the same
immutable evidence store as the frozen measurement receipt (commit
`cccc44417100dfcdadee652b17cb44060c573fd5` of
https://github.com/swift-institute/Research, directory
`agent-first-presence/`), which this protocol builds on and does not restate.

What the prior programme established, and this protocol therefore assumes
rather than re-argues: derivation without regeneration is the dominant defect
engine (23–61% rot per hand-restated fact class, with zero renames involved);
the page-content contract is deletion-first (derived facts are deleted, the
evaluated manifest is the projection); and no controlled study links page
format to agent task success — the benefit claim gets its first measurement
here (accepted dedicated assessment,
https://github.com/swift-institute/.github/issues/126#issuecomment-5132657767,
§1, §3, §9).

## 0. Pre-registration discipline

- Every design degree of freedom that could favor one arm, or that could be
  selected after seeing results, is fixed in this document: arm definitions,
  task templates and their verbatim prompts, ground-truth derivation, the
  scoring rules, trial volume, the extension rule, and the numeric decision
  rule. None of these may be changed by the executor.
- Two bindings are deferred to the instantiation appendix (§7) because their
  inputs do not exist yet — the sealed canary cohort and the executor's exact
  model configuration. Both are arm-symmetric (identical across arms by
  construction) and both must be committed to this document before the first
  trial, so neither can be tuned toward a conclusion. Their derivation rules
  are fixed here and leave no discretion.
- Amendments to this document are dated in-place amendment blocks, permitted
  only before the first trial. The canary receipt records this document's git
  blob digest at freeze; the freeze digest is the protocol the run executed.
  Any change after the first trial invalidates the run: the run's outcome is
  then `invalid`, which maps to the inconclusive path of §6, never to
  proceed.
- The executor of the trials makes no measurement design decisions. Where
  this document is silent, the answer is "the run stops and the gap is fixed
  by pre-trial amendment", not executor judgment.

## 1. Arms

The unit of evaluation is a repository page pair. The evaluated page for each
canary repository is its root `README.md`. (DocC catalogues and organization
profiles are converted under the same canary but are not evaluated by this
protocol; §8 records the limit.)

- **Arm L (legacy).** The byte content of the repository's root `README.md`
  at its pre-conversion revision — the exact blob whose digest the canary
  receipt records as that file's per-file pre-conversion blob digest.
- **Arm C (converted).** The byte content of the same file at the
  post-conversion revision the canary receipt records for that repository
  (the deletion commit of the two-commit discipline, or the second commit
  where a marker block was injected).

Assignment is within-subject and exhaustive: every repository in the sealed
canary cohort contributes exactly one page to both arms. There is no
selection step and no randomization to game; arm membership is reproducible
by anyone from the receipt's blob digests alone (`git cat-file blob <digest>`
against the repository).

Deterministic exclusion, decided before any trial by digest comparison only:
a repository whose pre-conversion and post-conversion README blob digests are
equal is excluded (the arms would be identical) and recorded as excluded in
the instantiation appendix. No other exclusion exists.

Because the make-safe pre-pass corrects provably-false statements before the
canary, Arm L pages are expected to be largely true-but-restated at trial
time. The arms therefore primarily test whether agents retain task success
when restatement is deleted and derivation is forced; §8 states this limit
honestly.

## 2. Task set

Four task templates, instantiated once per included repository. The
instantiation appendix records, per (repository, template): the fully
substituted prompt text and the ground-truth answer, both committed before
any trial. Ground truth is derived mechanically by the rules below; the
derivation uses only the canonical sources the programme already ratified
(the evaluated manifest via the Workspace evaluated-manifest route, and the
pinned remote-state snapshot of §4), never the page under test.

Placeholders: `{PACKAGE}` is the package name from the evaluated manifest;
`{PRODUCT}` is the first product of the manifest's product list in manifest
order (a deterministic pick; no executor choice).

- **T1 — product enumeration.**
  Prompt: "List every product this Swift package declares. Answer with a
  fenced JSON array of product name strings and nothing else after it."
  Ground truth: the set of product names from the evaluated manifest at the
  receipt's pinned revision.
  Scoring: set equality (order-insensitive, exact strings). Pass/fail.
- **T2 — dependency declaration.**
  Prompt: "Write the exact `Package.swift` code to depend on this package
  and use its product `{PRODUCT}` in a target: give the entry for the
  `dependencies:` array of the package and the entry for the target's
  `dependencies:` array. Answer with a fenced JSON object with keys
  `package_dependency` and `target_dependency`, each a single Swift
  expression string, and nothing else after it."
  Ground truth: the package-dependency clause whose URL is the repository's
  canonical clone URL and whose pin follows the ratified branch-until-tag
  rule evaluated against the remote-state snapshot (branch pin if the
  snapshot lists zero tags; `from:` at the highest snapshot tag otherwise),
  plus the `.product(name:package:)` clause with the correct product and
  package names.
  Scoring: both expressions must match ground truth after whitespace
  normalization, with the pin judged on (URL host+path, pin kind, pin
  value) and the product clause on (product name, package name). Pass/fail.
- **T3 — floors.**
  Prompt: "State the minimum Swift tools version and the declared platform
  minimums of this package. Answer with a fenced JSON object with keys
  `swift_tools_version` and `platforms` (an object mapping platform name to
  minimum version; empty object if the manifest declares none) and nothing
  else after it."
  Ground truth: the `swift-tools-version` and `platforms` values from the
  evaluated manifest at the pinned revision.
  Scoring: exact equality after canonicalizing version spellings (e.g.
  `.v26` and its numeric form are one value; the canonical spelling table is
  fixed in the instantiation appendix from the manifest model's own
  rendering). Pass/fail.
- **T4 — build-and-test routing.**
  Prompt: "You are working inside the Swift Institute checkout hierarchy.
  Give the exact command an Institute agent runs to build this package and
  the exact command to test it. Answer with a fenced JSON object with keys
  `build` and `test` and nothing else after it."
  Ground truth: the `workspace package build` and `workspace package test`
  routing (the sanctioned coordinator route; raw `swift build`/`swift test`
  is a fail).
  Scoring: each command string must invoke the coordinator route; flags
  beyond the routing are ignored. Pass/fail.

The four templates are chosen against the measured defect classes of the
frozen receipt — product tables (D1), install pins (D2), floor prose (D1),
and operational routing — so that each task is answerable in Arm C only by
derivation from canonical sources and in Arm L either by derivation or by
trusting the page's restatement. A task instance whose prompt or ground
truth cannot be derived mechanically for some repository (e.g. a manifest
with zero products makes T2 undefined) is recorded `not-applicable` for that
repository in the appendix, before any trial, and contributes no pairs.

## 3. Primary outcome

**Trial success**: the trial's final answer block, scored against the task's
recorded ground truth by the template's scoring rule. Binary per trial.

The scoring rules above are mechanical over the transcript's final fenced
answer block: any party who did not run the trials can re-score every trial
from the archived transcripts and the appendix alone, and the receipt must
make that possible (§5). A trial with no parseable final answer block scores
fail. Malformed-but-recoverable answers are not repaired by the scorer.

Secondary outcomes, labelled secondary, recorded per trial, and unable to
move the decision under any circumstance: total tokens consumed,
assistant-turn count, wall-clock duration, and stale-adoption rate (the
fraction of Arm L failures whose answer equals a value stated on the Arm L
page but contradicting ground truth — the mechanism signature the prior
programme predicts).

## 4. Execution and volume

- **Harness.** Each trial is one fresh, stateless agent session with no
  memory of any other trial. The session receives: a fixed system prompt
  (verbatim in the instantiation appendix, identical for every trial in both
  arms); read-only file access to the repository checkout at the receipt's
  pinned pre-conversion source revision, with exactly one modification — the
  root `README.md` content replaced by the assigned arm's blob; the ability
  to run the Workspace evaluated-manifest command against that checkout; and
  read access to the remote-state snapshot file. No network access.
- **Remote-state snapshot.** One file per repository, captured once at
  instantiation time (tag list and default-branch name from the remote),
  identical across arms, committed in the appendix by digest. Ground truth
  for T2 is defined against this snapshot, so the offline harness and the
  scoring can never disagree about remote state.
- **Executor binding.** The exact model identifier, sampling and effort
  parameters, context ceiling, and tool definitions are recorded in the
  appendix before any trial and are identical for every trial in both arms.
  One binding serves the whole run; a mid-run change invalidates the run.
- **Volume.** Let R be the number of included repositories (cohort of ten to
  twenty, minus digest-equal exclusions and per-template
  `not-applicable` gaps). Repetitions: k = 3 trials per (repository,
  template, arm). Pairs are formed by repetition index: pair i of a
  (repository, template) cell is (Arm L trial i, Arm C trial i). Expected
  pair count: between roughly 120 (R = 10, all templates applicable) and 240
  (R = 20). Trial order within the run is interleaved by cell and arm
  (L,C,L,C…) so drift in the executing service, if any, loads both arms
  equally.
- **Failed trials.** A trial that terminates for harness reasons (transport
  error, context overflow, timeout at the appendix-fixed ceiling) is rerun
  once with the same inputs; a second harness failure records the pair
  `unmeasured` — never a pass, never silently dropped from the receipt. If
  more than 10% of pairs end `unmeasured`, the run is `invalid` and maps to
  the inconclusive path of §6.

## 5. Per-trial record and receipt

The canary receipt's evaluation section records, per trial: trial identifier;
repository canonical coordinate; template identifier; arm; the README blob
digest the session was given; the full transcript's content digest, with the
transcript archived in the evidence store the receipt names; token count;
turn count; wall-clock duration; the final answer block verbatim; the score
and the scoring-rule identifier. It also records: this protocol's freeze
blob digest, the instantiation appendix's blob digest, the executor binding,
every exclusion and `not-applicable` and `unmeasured` entry, and the
computed decision-rule quantities of §6. The run is auditable from the
receipt alone; a reviewer needs no access to the party who ran it.

## 6. Decision rule

For every scored pair i, the paired difference is
d_i = success(C, i) − success(L, i) ∈ {−1, 0, +1}. Over n scored pairs:

- Δ̂ = (Σ d_i) / n — the primary statistic.
- CI = the two-sided 95% confidence interval for the paired difference of
  proportions by Newcombe's paired hybrid-score method (method 10 of
  Newcombe 1998, "Improved confidence intervals for the difference between
  binomial proportions based on paired data"). This is the only interval
  method; no alternative analysis may substitute for it.
- Non-inferiority margin: 0.05 (five percentage points), fixed here.

Mapping, applied in order, first match wins:

1. **Abort** — if CI's upper bound < 0: conversion measurably degrades task
   success. Goal #126 closes `not planned` through its canary abort path,
   with a linked, separately assessed successor; landed doctrine and
   predicates survive as ordinary exact-owner work.
2. **Proceed** — if Δ̂ ≥ 0 and CI's lower bound > −0.05: converted pages do
   not degrade agent task success beyond the margin, and the point estimate
   does not favor legacy. Under the deletion-first contract this is the
   benefit the evaluation exists to test: the measured rot engine is removed
   (prior evidence, frozen receipt) while agent task success is retained or
   improved (this measurement). The layer sweeps may start, subject to the
   Goal's other gates.
3. **Inconclusive** — any other result. Inconclusive is not proceed. Exactly
   one pre-declared extension is permitted: repetitions double (k = 3 → 6)
   with the same appendix, binding, and interleaving; the rule then
   re-applies once over all pooled pairs. A second result in this branch, or
   an `invalid` run (§0 post-freeze change, §4 unmeasured overrun), maps to
   **abort**: an evaluation that cannot show the retained-success benefit
   within twice its planned volume has not shown benefit, and the Goal's
   abort clause reads "shows no benefit", not "shows harm".

No quantity other than the primary statistic and its interval enters this
mapping. Secondary outcomes, however striking, change nothing here; they are
input to the successor assessment the abort path files, or to ordinary
exact-owner follow-up on proceed.

## 7. Instantiation appendix (reserved)

Appended to this document by dated amendment after the canary cohort is
sealed and before the first trial, containing exactly: the included
repository list with per-file pre- and post-conversion README blob digests
copied from the receipt; digest-equal exclusions; per-(repository, template)
substituted prompts, ground truths, `not-applicable` entries, and the T3
canonical version-spelling table; per-repository remote-state snapshot
digests; the verbatim system prompt; and the executor binding. Every entry
is a mechanical consequence of rules fixed above; the appendix adds data,
never design. Sealing the cohort, converting pages, and running trials are
not authorized by this document and remain the Goal's own gated work.

## 8. Limits

Stated in the honest voice the enforceability taxonomy requires of a
judgement-bearing instrument:

- **Single estate, single binding.** One package fleet, one harness, one
  model configuration. The result cannot generalise to agent readers in
  general, to other estates, or to other harnesses; the proceed/abort
  decision it feeds is an Institute decision about Institute pages, nothing
  wider.
- **It measures retention, not the rot mechanism.** The make-safe pre-pass
  corrects provably-false statements before the canary, so Arm L pages at
  trial time are mostly true-but-restated. The design therefore has real
  power for "deletion does not degrade task success" and only weak,
  opportunistic power for "restatement actively misleads" (visible only via
  the stale-adoption secondary where residual drift happens to exist). The
  active-misleading claim rests on the frozen receipt's measured rot rates,
  not on this evaluation.
- **Decidable tasks only.** The four templates score manifest-derivable
  facts and routing. The reader value of authored judgment prose — the
  content the deletion-first contract keeps — is not measured here; the
  five-disposition judgment wave owns that question.
- **README only.** DocC catalogues, organization profiles, and record trees
  are converted under the same programme but not evaluated by this protocol.
- **Offline snapshot.** Trials run against a pinned checkout and a frozen
  remote-state snapshot; live-remote behaviors (redirects, tag races) are
  out of frame by design.
- **Resolution floor.** At 120–240 pairs the rule reliably detects arm
  differences of roughly five to ten percentage points and cannot resolve
  smaller effects; the 0.05 margin is chosen at that floor, and effects
  smaller than the margin are declared operationally irrelevant to the
  sweep decision rather than nonexistent.
- **Trial dependence.** Pairs sharing a repository or template are not
  independent; the interval method assumes independent pairs, so the CI is
  approximate. The margin and the abort-on-double-inconclusive rule are the
  guard: no reading of this protocol lets a marginal, assumption-sensitive
  result map to proceed.
