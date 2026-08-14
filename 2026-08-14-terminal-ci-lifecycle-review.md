> Commissioned exploratory research, delivered 2026-08-14. Committed to Research by the CI programme coordinator. Ratification and sequence: https://github.com/swift-institute/institute-continuous-integration/issues/35#issuecomment-5293015006

# Swift Institute terminal CI lifecycle — read-only design review

**Review date:** 14 August 2026  
**Terminal-cutover verdict:** **BLOCKED**  
**Implementation verdict:** **SAFE TO IMPLEMENT incrementally and reversibly**

The smallest maintainable terminal topology is:

> **fast exact-head PR tier → GitHub merge queue with one full exact-prospective matrix → protected-main provenance verification → separately authorized deterministic publication**

This should be implemented as a hybrid of options **D and E**, using option **B** as the prospective-merge mechanism:

- ordinary changes receive one fast PR run and one full `merge_group` run;
- CI-owner, dependency, toolchain, control-plane, and publisher changes receive stronger **planner-selected evidence in that same merge-group run**, not another identical full matrix;
- protected-main runs become cheap provenance verification, not a third compilation and test cycle;
- deterministic publisher retries, scheduled certification, failure controls, and migration waves remain separate from normal per-change CI.

The central reusable workflow already preserves most platform and fail-closed invariants: one reusable hop, event-derived tiers, exact workflow revision recording, gating Windows assertions, Apple coverage, pinned actions and containers, and a typed `ci-ok` aggregate that rejects missing selected evidence.    

The live lifecycle nevertheless is not terminally safe because:

- `institute-continuous-integration/main` has no effective branch rules or required statuses;
- its caller does not handle `merge_group`;
- `.github/main` requires a pull request but no CI status or merge queue;
- the private Control source branch is unprotected;
- publication starts directly from `push` and can finish before protected-main CI;
- at least two publishers permit contributor-originated code and later write credentials in the same runner lifetime.     

---

## 1. Precise live run and topology inventory

### 1.1 Live lifecycle

| Stage | Trigger and subject | Live behavior | Assessment |
|---|---|---|---|
| Pull-request tier | `pull_request` targeting `main`; exact PR head | One generated caller invokes `swift-ci.yml@main`. The planner selects the build tier. Linux release, Linux 6.4, formatting, SwiftLint, and `swift-linter` run; Windows and Apple are skipped. | Exact-head and unprivileged, but the two Linux jobs are presently duplicative. |
| Manually dispatched full tier | `workflow_dispatch`; dispatch branch SHA | Same caller and reusable workflow. The planner selects full Linux, Windows assertions, Apple, and quality coverage. No contributor-selectable tier input exists. | Full platform evidence, but only for the head SHA. It is not prospective-merge evidence. |
| Bot validation and review | Trusted control dispatch carrying expected head and observed base | Candidate material is processed without a write token, destroyed, and only then is a narrowed App token minted to publish `control / validate` and the review. | Strong exact-head/base design. The approval is explicitly not merge authorization. |
| Protected-main CI | `push` to `main`; final main SHA | The same reusable workflow selects another full matrix. | Exact final commit, but too late to prevent a bad merge and largely duplicative after a prospective full gate. |
| Repository Policy publication | Relevant `push` to main, schedule, or dispatch | Resolves the graph, builds and normalizes deterministic bytes, compares clean builds, uploads immutable assets, reads them back, and advances `CURRENT` last. | Strong reproducibility mechanics, but currently races main CI and executes source while the job has `contents: write`. |
| Private-repository verification | Trusted `repository_dispatch`; exact open-PR SHA | Read-only App token acquires the workspace, verifies the exact commit, revokes the token, runs Linux/Windows/Apple, and later publishes checks with a separate token. | Correct security direction. It must be extended to an exact merge-group subject where supported. |
| Scheduled certification | Publisher schedules and exact-source retries | Rebuilds or republishes deterministic binaries and exercises pointer-safety controls. | Certification, not normal per-change CI. |
| Migration-only operations | Terminal-caller waves and explicit failure controls | Bounded dispatch workflows with negative controls. | Migration-only. They must never become required merge evidence. |

The caller currently handles `push`, `pull_request`, and `workflow_dispatch`, but not `merge_group`; it contains exactly one reusable job and does not expose tier-selection inputs. 

The control path validates the claimed head against live state, preserves the observed base, destroys candidate material before obtaining write credentials, and publishes an exact-head receipt. Its package review profile currently consumes both check runs and workflow runs, which is why the manually dispatched full run forms part of the current review transaction.   

The private workspace path independently preserves the critical rule that candidate-controlled execution must occur only after narrowed read credentials have been revoked. 

### 1.2 Representative change: Institute CI PR #37

PR #37 changed only `.github/workflows/publish-repository-policy-binary.yml`. It added deterministic ELF normalization and corresponding negative assertions: disabling the ELF build ID, removing `.swift_modhash`, stripping debug sections, and verifying the normalized executable with `readelf`. 

The relevant identities were:

| Identity | Value |
|---|---|
| Reviewed head | `4833f0b0abff2ad200b611493cd255c6253fb3aa` |
| Reviewed head tree | `6241753f08d93dff9687a41019247163b7154d1e` |
| Base | `35600bb883f42c55a3e96033c4cf31911ff2a722` |
| Final main commit | `a10fd8b6fb31901a6faf6aa5ec176c12d3f99d98` |
| Final main tree | `6241753f08d93dff9687a41019247163b7154d1e` |

The final squash commit therefore had a different commit identity but the same tree as the reviewed head. The bot approval was bound to the exact reviewed head and expressly stated that approval was not merge authorization.  

### 1.3 Measured runs

All times below are UTC on 14 August 2026. Runner-minutes are sums of observed job elapsed times, rather than GitHub’s billing API, which reports zero billable usage for this public repository.

| Run | Event and subject | Wall clock | Executed non-skipped jobs | Approx. runner-minutes | Highest-latency evidence |
|---|---|---:|---:|---:|---|
| `31782422607` | PR tier at exact head `4833f0b…` | 19m52s | 7 | 52.5 | Linux release, 18m53s |
| `31782443176` | Manual full at the same exact head and tree | 35m47s | 10 | 94.5 | Windows assertions, 34m50s |
| `31785055849` | Full push-main CI at final `a10fd8b…` | 33m35s | 10 | 96.5 | Windows assertions, 32m25s |
| `31785055503` | Repository Policy publication at final `a10fd8b…` | 14m18s | 1 | 14.3 | Deterministic build and publication |

The first two CI runs both resolved central workflow revision `e99999d…`; the main run resolved `96542247…`. The intervening central change affected a publisher workflow rather than package CI semantics, so the different central repository SHA did not itself justify another complete package matrix. 

The main CI run completed successfully at 09:16:40. The publisher completed at 08:57:22, **19m18s before main CI succeeded**. Publication was therefore not authorized by successful protected-main CI.  

### 1.4 Job-class timing and evidence value

| Job class | Observed duration | Evidence supplied | Failure-detection value |
|---|---:|---|---|
| Plan and package validation | 29–46s | Subject SHA, central workflow SHA, policy, tier and selected legs | Very early structural failure |
| `swift-format` | 39–46s | Canonical formatting | Under one minute |
| SwiftLint | 47–65s | Canonical SwiftLint policy and verified tool bytes | About one minute |
| `swift-linter` | 11m05s–12m29s | Institute semantic/source policy | Mid-run |
| Linux release | 18m53s–20m50s | Release compilation or release tests | Around 19–21 minutes |
| Linux 6.4 | 15m58s–18m49s | Advisory release-floor compilation | Around 16–19 minutes |
| Apple | 10m21s–10m39s | Debug tests under the pinned Xcode environment | Around 11 minutes |
| Windows assertions | 32m25s–34m50s | Assertions-enabled debug tests using the native build system | Critical path, around 33–35 minutes |
| `ci-ok` | 14–17s | Typed, fail-closed aggregate | Immediate after final selected gate |
| Repository Policy publisher | 14m18s | Deterministic executable and immutable release bundle | Currently first real execution of the changed publisher path |

The main run’s two Linux jobs each repeated approximately 4m16s of identical system-dependency provisioning before their separate build and test operations.  

Windows remains genuinely distinct and load-bearing: it uses the assertions-enabled compiler, runs debug tests, is not `continue-on-error`, and is selected as gating evidence. Apple likewise supplies genuinely separate platform evidence. 

Runner starts were generally only a few seconds after job creation in the examined runs. There is no evidence of material runner queueing in this sample. Fleet-wide queueing under sustained autonomous contribution volume is therefore **UNMEASURED**, not proven negligible.

---

## 2. Duplicated work ledger

| Repeated work | Why it happens now | Classification | Terminal treatment |
|---|---|---|---|
| PR Linux release and PR Linux 6.4 | Both use the planner-provided Linux image and both execute `swift build -c release` on the same SHA. | **Avoidable** | When toolchain/image and operation identities are equal, execute once and emit both typed evidence facts. Keep separate only when identities actually differ. |
| Linux release and Linux 6.4 setup in a full run | Both independently check out the same subject, initialize the same container, install the same system dependencies, and materialize dependencies. One then tests; the other builds. | **Partly avoidable** | Preserve both build and test predicates, but run them sequentially in one Linux workspace when their immutable toolchain identity is equal. |
| PR quality checks repeated in manual full | The manual run re-evaluates the same head and central revision. | **Avoidable in the present topology** | In the terminal topology, PR and merge-group checks evaluate different authorities: head feedback versus prospective merge. That repetition is then correctness-required. |
| PR Linux build repeated in manual full | Build-tier feedback is followed by full-tier tests on the same head. | **Migration/topology artifact** | Move full certification to `merge_group`. Repetition then occurs only if the prospective tree differs or if the same operation is intentionally retained for early feedback. |
| Full Linux, Windows, Apple, and quality work repeated after merge | `push main` currently selects the same full tier as the manual dispatch. | **Avoidable after merge queue** | Replace with an exact-main provenance verifier and commit-sensitive smoke only. |
| Dependency materialization in every job | GitHub-hosted jobs are isolated, and the workflow does not pass a trusted per-platform resolution receipt between them. | **Necessary across platform classes; avoidable within identical Linux jobs** | Record a per-job resolution/closure digest. Share a workspace only where platform, toolchain, and operation identity permit. |
| Plan and policy resolution in every run | Each event has a different subject and authority. | **Necessary and cheap** | Retain. Include all planner inputs, policy digest, UTC policy date, and exact reusable workflow SHA in the receipt. |
| Publisher build after package CI | Published bytes use distinct flags, normalization, static linking, and immutable provenance. | **Necessary** | Never promote ordinary CI build output. Build exact protected main again in a credential-free publisher-build phase. |
| Two clean publisher builds and byte comparison | Establishes first-publication reproducibility. | **Necessary** | Retain and standardize across all publisher families. |
| Release readback and advancing `CURRENT` last | Prevents incomplete or mismatched bundles becoming current. | **Necessary** | Retain. |
| Same-source scheduled rebuilds | Detect nondeterminism or environment drift after publication. | **Certification-only** | Keep outside per-change CI and outside required merge statuses. |
| `failure_control` executions | Prove that mismatch and readback failures leave `CURRENT` unchanged. | **Negative-control-only** | Dispatch or schedule only. An intentionally failing control is not a failed ordinary CI run. |
| `terminal-caller-wave` and fleet mutation retries | Support bounded migration and convergence. | **Migration-only** | Keep out of the normal lifecycle and dashboards. |

The PR #37 case shows why evidence must be selected according to the changed semantic surface. Three generic CI matrices repeatedly compiled and tested the Swift package, but the changed `objcopy`, `readelf`, normalization, and release-pointer path was first exercised by the post-merge publisher. The correct stronger gate for this class of change is a credential-free publisher dry run on the prospective merge, not another identical package matrix.  

The package manifest also declares several dependencies against `main`, making the tracked resolution and exact dependency revisions load-bearing evidence. Per-platform receipts should record the actual resolved revisions rather than treating the manifest’s branch names as sufficient provenance. 

---

## 3. Evaluation of options A–E

| Option | Correctness and TOCTOU | Security and ruleset feasibility | Cost and latency | Operational complexity | Disposition |
|---|---|---|---|---|---|
| **A. Current PR + manual full + post-main full** | PR and manual runs are exact-head, not exact-prospective. Main is exact final but too late. Base movement can invalidate the relevance of head evidence. | Fork-safe CI, but live branch rules are missing and publication races CI. Manual dispatch is an operational dependency. | Three heavy CI runs; 243.6 runner-minutes for PR #37. Current sample achieved a 38m31s merge only because the manual full run was started 19 seconds after the PR run. | High: manual dispatch, run polling, bot consumption of multiple run classes, and post-merge recovery. | **Reject as terminal.** |
| **B. Merge queue; `merge_group` is sole full gate** | Strong prospective-merge correctness. GitHub creates and tests a synthetic commit against the current base; base movement creates new queue evidence. | GitHub-native and compatible with required statuses. The workflow must subscribe to `merge_group`, or the queue cannot receive its checks. | Removes manual full and post-main full duplication, but a main-to-publication binding is still required. | Low. GitHub owns queue construction, staleness, and sequencing. | **Use as the core gate, but not alone.** |
| **C. Reuse PR tree/resolution/plan evidence on main** | Safe only when a complete identity tuple matches. Tree equality alone is insufficient where commit identity, base, workflow, policy, dependency closure, toolchain, runner image, or operation can affect behavior. | Cross-workflow artifacts and caches cannot be trusted as authorization. A trusted App would need to re-attest inert receipts. | Can reduce latency when the PR and prospective trees are identical, but planning itself is cheap; most savings require reusing platform evidence. | High: receipt storage, equivalence laws, revocation, stale-evidence handling, and artifact trust. | **Do not use as the initial authority model.** Retain as a future optimization for pure evidence. |
| **D. Full prospective certification; post-main smoke/provenance only** | Full matrix executes before merge on the exact merge-group commit. Main verifier proves the relationship between that commit and the final main tree before publication. | Strong, provided there are no ruleset bypasses and publication consumes only the trusted main receipt. | One full matrix instead of two. Main verification is estimated at 1–3 minutes. | Moderate and durable. The provenance verifier is much smaller than another matrix. | **Recommended baseline.** |
| **E. Hybrid stronger gates for high-risk changes** | Same prospective authority as D. Central planner adds evidence relevant to CI-owner, dependency, toolchain, or publisher changes. | Contributors cannot self-classify or suppress the stronger tier. Code-owner review and control validation remain independent. | Ordinary changes stay at D’s cost. High-risk changes add targeted canaries or deterministic dry runs, not a duplicate full matrix. | Moderate because the existing canonical planner owns classification and selection. | **Recommended terminal topology.** |

GitHub’s merge queue is expressly designed to test a prospective merge through the `merge_group` event and to recreate queue groups when their composition or base changes. Required checks must run for that event, not merely for `pull_request`. 

### Why option C is not the terminal shortcut

A reusable receipt should still be designed, but its first use should be **post-main provenance**, not skipping the prospective full matrix.

A lawful receipt needs at least:

- repository identity and exact PR head;
- reviewed base and prospective merge-group SHA;
- subject tree and final main tree;
- exact reusable workflow revision and relevant workflow/action/policy blob digests;
- planner binary digest and complete planner inputs;
- per-platform toolchain, container, action, and runner-image identities;
- `Package.resolved` and resolved dependency-closure digest;
- exact operation identity: build, tests, linter, formatting, or publisher dry run;
- run ID, attempt, expected check source App, conclusion, and selected/gating classification.

Even then, final squash commit identity can differ from the merge-group commit. The correct proof is a GitHub-backed merge relationship plus exact tree and base-parent correspondence, not an assertion that the two SHAs are equal.

---

## 4. Recommended event, check, and publication sequence

The same generated package caller can continue to contain exactly one reusable workflow hop. Its event set should become:

```yaml
pull_request:
merge_group:
  types: [checks_requested]
push:
  branches: [main]
workflow_dispatch:
```

The tier remains derived entirely from the trusted event and canonical planner. No tier input should be introduced.

### 4.1 Event-to-tier contract

| Event | Planner tier | Exact subject | Required work | Privilege |
|---|---|---|---|---|
| `pull_request` | `pullRequest` | `pull_request.head.sha` | Structural validation, quality checks, one nonduplicated Linux release build, `ci-ok` | Read-only |
| `merge_group` | `prospectiveMerge` | `merge_group.head_sha` | Full selected Linux tests/build proof, Windows assertions, Apple tests, quality, high-risk additions, `ci-ok` | Read-only |
| `push` to `main` | `postMerge` | `github.sha` | Receipt and provenance verification; only explicitly commit-sensitive smoke | Read-only |
| `workflow_dispatch` | `fullDiagnostic` | Exact dispatch SHA | Full diagnostics or infrastructure recovery | Read-only; never merge-authorizing |
| `schedule` | Not package CI | Exact current published source | Reproducibility and extended certification | Separate trusted publisher/control path |

### 4.2 Normal change sequence

1. **PR feedback**

   The exact PR head runs the fast tier. The workflow remains unprivileged, all actions and containers remain immutable, and `ci / matrix / ci-ok` fails closed if any selected gating evidence is absent.

2. **Exact-head bot review**

   The control application confirms the expected head, observed base, canonical caller, risk class, required evidence, and review policy. It publishes `control / validate` and an approval bound to that exact head. Approval remains review evidence rather than merge authorization.

3. **Merge-queue admission**

   Once PR requirements are met, GitHub places the PR in the queue. Initially, one PR should be built and merged per group. This makes the prospective-to-final relationship simple and auditable.

4. **Full prospective certification**

   `merge_group: checks_requested` invokes the same one-hop caller. The canonical planner selects full Linux, Windows assertions, Apple, and quality evidence. High-risk classes add relevant canaries or deterministic dry runs.

5. **Queue-controlled merge**

   GitHub merges only the queue candidate for which both required contexts succeeded on the exact merge-group SHA. No actor or App may bypass the queue.

6. **Exact-main provenance**

   The push-main tier performs no ordinary package compilation, testing, or dependency resolution. It verifies:

   - the final main SHA and tree;
   - the immediately preceding protected-main base;
   - the associated PR and approved head;
   - the exact merge-group SHA and tree;
   - successful `ci-ok` and `control / validate` from their expected Apps;
   - the exact central workflow, planner, policy, toolchain, action, container, and resolution identities;
   - that the central workflow revision was a certified protected-main revision at execution time;
   - that no required evidence has been revoked.

   Missing, ambiguous, or stale evidence fails closed.

7. **Publication authorization**

   A publisher may start only after successful exact-main provenance. For same-repository publication, a tightly validated `workflow_run` trigger is GitHub-native:

   - triggering workflow is the expected CI workflow;
   - event is `push`;
   - branch is `main`;
   - conclusion is success;
   - head SHA equals current protected main;
   - the exact receipt is accepted.

   A cross-repository publisher should receive an equivalent trusted control dispatch containing the exact source and receipt identity.

8. **Credential-free build, credentialed inert publication**

   Publication is split across runner boundaries:

   - **build A and build B:** exact protected-main source, no publisher credential, isolated clean directories, deterministic normalization, complete manifest;
   - **comparison:** hashes and bytes must match;
   - **publish:** no source checkout and no executable invocation; consume only inert hash-verified bytes and manifests, mint a narrowed write token, upload immutable digest-named assets, read them back, and advance `CURRENT` last;
   - revoke the write token.

GitHub warns that a privileged `workflow_run` must not execute or trust artifacts originating from untrusted code without verification. The proposed publication job therefore treats transferred bytes as inert input and never executes them. 

### 4.3 High-risk planner classes

The canonical planner, not a label, contributor, caller input, or workflow-dispatch option, should classify:

| Risk class | Examples | Additional prospective evidence |
|---|---|---|
| CI owner | Central reusable workflow, composite actions, planner contract, policy inventory, CI binary pin | Candidate-host canary over canonical package fixtures; workflow inventory and fail-closed aggregate tests |
| Dependency | `Package.swift`, `Package.resolved`, dependency-source or resolver logic | Exact closure diff, source/revision proof, all required platform classes |
| Toolchain | Swift/Xcode versions, containers, setup actions, checksums, system-dependency installers | Immutable acquisition proof, version assertions, Windows assertions, Apple and Linux canaries |
| Publisher | Publisher workflows, build flags, normalization, manifests, release-pointer logic, App permissions | Two clean credential-free builds, deterministic byte comparison, readback dry run, mismatch and failed-readback controls without release mutation |
| Privilege/control | App-token issuance, receipt validation, ruleset generation, private workspace acquisition | Independent control validation, code-owner approval, positive and negative receipt tests |

PR #37 should have selected the publisher class automatically. `.github` PR #586, which changed the private Control publisher and merged with only `control / validate`, should likewise have received a deterministic publisher dry run before merge.   

---

## 5. Exact required-status and ruleset changes

### 5.1 Live protection gaps

The live `institute-continuous-integration` repository reports:

- `main` unprotected;
- no repository rulesets;
- no effective rules.   

A desired ruleset document already exists in the repository, but it is not applied. It contains required-review and required-status concepts that should be updated for merge queue rather than discarded. 

The central `.github` repository has an active ruleset requiring a pull request, one approval, stale-review dismissal, last-push approval, thread resolution, and squash merge. It has no required CI statuses, no code-owner requirement, and no merge queue.  

The private Control source repository reports `main` unprotected. Until a supported protection mechanism is enabled for that private repository, its source cannot lawfully be treated as protected-main publication input.  

### 5.2 Required rule values

For each active public package repository, `institute-continuous-integration`, and `.github`:

| Rule | Exact terminal value |
|---|---|
| Target | `refs/heads/main` |
| Enforcement | Active |
| Bypass actors | None |
| Branch deletion | Prohibited |
| Non-fast-forward/force push | Prohibited |
| Linear history | Required |
| Pull request | Required |
| Merge method | Squash only |
| Approving reviews | At least 1 |
| Stale reviews | Dismiss on push |
| Last push approval | Required |
| Review threads | Must be resolved |
| Code-owner review | Required where changed paths have a CODEOWNER |
| Required check 1 | `ci / matrix / ci-ok` |
| Expected source for public check 1 | GitHub Actions |
| Required check 2 | `control / validate` |
| Expected source for check 2 | Swift Institute Bot |
| Required workflows | None; do not add a second fleet workflow hop |
| Strict up-to-date PR branch policy | `false` after merge queue is active |
| Merge queue | Required |

GitHub rules can bind required statuses to an expected integration, reducing the risk that another workflow merely emits the same textual check name. 

For private repositories, `ci / matrix / ci-ok` should instead be expected from the trusted Swift Institute verification App, because the public reusable caller intentionally skips private repositories.

### 5.3 Initial merge-queue parameters

| Parameter | Initial value |
|---|---:|
| Check response timeout | 60 minutes |
| Grouping strategy | All entries must be green |
| Maximum entries to build | 1 |
| Maximum entries to merge | 1 |
| Minimum entries to merge | 1 |
| Minimum wait | 0 minutes |
| Merge method | Squash |

One-entry groups minimize proof complexity:

- one reviewed head;
- one observed base;
- one prospective tree;
- one final squash tree;
- one unambiguous provenance receipt.

GitHub exposes these merge-queue controls in repository rulesets. 

Once operational evidence demonstrates that multi-entry groups can be mapped without ambiguity, throughput can be increased deliberately. It should not be increased during the first cutover.

### 5.4 Why strict branch updating should be disabled

With no merge queue, strict status checks can require a PR branch to be updated against the latest base before merge. With merge queue, the synthetic `merge_group` commit is the latest-base authority. Retaining strict branch updating would force extra head rebuilds before GitHub performs the real prospective merge build.

This is safe only after:

- merge queue is mandatory;
- there are no bypass actors;
- both required checks run on `merge_group`;
- direct pushes are prohibited.

### 5.5 Special requirements for `.github`

Because all package callers request the central workflow at `@main`, `.github/main` is a fleet-wide semantic authority. Before it changes:

- `control / validate` must run on the candidate and the merge-group SHA;
- a candidate-host certification must exercise the candidate reusable workflow against canonical package fixtures;
- the resulting aggregate must be `ci / matrix / ci-ok`;
- CI host, toolchain, policy, and publisher paths must have CODEOWNERS;
- the ruleset must require both statuses and merge queue.

The current one-approval-only ruleset is insufficient for a repository whose main branch instantly changes fleet CI semantics.  

### 5.6 Publisher environment rules

The Repository Policy publisher environment currently restricts deployments to the branch name `main` and disables administrator bypass. It does not require the branch itself to be protected. Since the source repository’s main branch is presently unprotected, this is not yet a protected-main boundary.  

Terminal environment settings should be:

- deployment branches: **protected branches only**;
- administrator bypass: disabled;
- publisher workflow must separately verify exact current main and the accepted provenance receipt;
- environment secrets or App credentials available only in the inert publication job;
- no candidate source checkout in the publication job.

### 5.7 Concurrency and cancellation

| Run class | Concurrency policy |
|---|---|
| PR | Key by repository and PR number; `cancel-in-progress: true` |
| Merge group | Native merge queue, initially one group at a time; stale group runs may be cancelled |
| Push-main provenance | Key by exact main SHA; never cancelled by a later PR or dispatch |
| Manual diagnostic | Key separately from PR, merge-group, and main events; no merge authority |
| Publisher family | One global family key; `cancel-in-progress: false`; revalidate current source immediately before pointer mutation |
| Scheduled certification | Must serialize with the corresponding publisher, but a dropped scheduled retry must not affect ordinary CI |

The current caller uses a ref-derived concurrency group. A dispatch on `main` can therefore share a group with a main push. Event class and exact subject should be part of the key.

GitHub concurrency permits at most one running and one pending member of a group and can replace a pending run. It is not a general FIFO publication queue. Publisher semantics must therefore be explicitly “publish the latest still-authorized protected main” or use trusted control sequencing where every source revision must be retained. 

---

## 6. Required changes by canonical owner

| Canonical owner | Required terminal responsibility |
|---|---|
| `swift-continuous-integration` | Own provider-neutral tier, event, selected-leg, evidence, subsumption, and fail-closed aggregation types. Define when one operation lawfully satisfies two evidence predicates. |
| `swift-github-continuous-integration` | Own GitHub `merge_group` event decoding, prospective-subject identity, required-check source identity, ruleset/merge-queue representations, and GitHub receipt mapping. |
| `institute-continuous-integration` | Own Institute tier policy, high-risk path classification, platform requirements, toolchain exceptions, post-merge provenance plan, per-platform resolution receipts, and Linux operation coalescing. |
| `Repository Policy` | Render and validate the exact protected-main rulesets, expected status sources, no-bypass policy, environments, and merge-queue configuration. |
| `swift-institute/.github` | Remain a thin GitHub host: triggers, permissions, environment wiring, exact invocation of the canonical planner, candidate-host canaries, and generated caller distribution. |
| `institute-continuous-integration-control` | Acquire live GitHub state; validate expected head/base/group; publish checks and reviews; map merge-group evidence to final main; authorize trusted dispatches; perform privileged effects only after inert receipt acceptance. |
| Package repositories | Contain only the byte-identical one-job caller. No local matrix, tier input, secrets, policy registry, or evidence-selection logic. |
| Private workspace verifier | Accept and validate an exact PR or merge-group subject, revoke source credentials before execution, run all required platform classes, and publish exact-subject checks afterward. |
| Publisher workflows | Build exact protected main without write credentials; publish only inert verified bytes in a separate job; preserve immutable assets, provenance, readback, and pointer-last semantics. |

The current Institute CI package is already decomposed into contract, application, command, validation, inventory, and Repository Policy targets. The lifecycle changes should be expressed through those owners rather than by adding shell-based tier or risk logic to the GitHub host. 

---

## 7. Security and failure-mode analysis

| Threat or failure | Required terminal behavior |
|---|---|
| Base moves after PR approval | Existing PR-head evidence remains feedback only. GitHub creates a new merge-group subject against the new base. Old prospective evidence cannot authorize the new group. |
| PR head changes after bot review | Stale approval is dismissed; expected-head validation fails; previous checks and review cannot authorize the new head. |
| Merge-group composition changes | The old run is stale or cancelled. Only checks attached to the current group SHA count. |
| Fork attempts to obtain credentials | PR and merge-group execution has read-only permissions and receives no publisher/private-source credentials. |
| Contributor edits the caller to weaken CI | Independent `control / validate` rejects any noncanonical caller. Required check sources are fixed. The contributor cannot select a weaker tier. |
| Contributor edits central CI to manufacture `ci-ok` | `.github` requires independent control validation, code-owner approval, merge queue, and candidate-host certification. `ci-ok` alone is insufficient. |
| Central `@main` advances while a package queue run is in flight | The package receipt records the exact resolved central SHA. It remains admissible only if that SHA was a certified protected-main revision and has not been revoked. No per-package rerun is required merely because a later certified central revision exists. |
| Dependency branch advances | The receipt records exact resolved revisions and closure hash. A branch name such as `main` is not evidence. |
| Selected Windows job skips or fails | `ci-ok` fails. Windows remains gating and is never `continue-on-error`. |
| Selected evidence is absent | The typed aggregate fails closed rather than interpreting a missing job as success. The current aggregate already implements this posture.  |
| Cache poisoning | Caches are performance hints only. They do not satisfy checks or publication provenance. Tool bytes remain checksum-verified. Ordinary SwiftPM `.build` is not shared as authoritative evidence. |
| PR artifact reaches a privileged workflow | The privileged job treats it as inert, validates an expected digest and receipt, and never executes it. Prefer rebuilding exact protected main rather than promoting PR binaries. |
| Main is merged without queue evidence | No publication occurs. The provenance verifier fails, and the change must be reverted or corrected through the same queue. |
| Publisher begins before main verification | Forbidden. Publication is triggered only by accepted exact-main provenance or an equivalent trusted control dispatch. |
| Candidate code leaves a process to capture a later token | Build and publish occur on separate runners. No publisher token is minted in a runner that executed source code. |
| Deterministic build A and B differ | No asset is uploaded and `CURRENT` remains unchanged. |
| Immutable asset already exists with different bytes | Fail closed; do not overwrite or advance the pointer. |
| Upload or readback fails | Leave `CURRENT` unchanged. Exact-source retry is safe and idempotent. |
| Scheduled reproducibility check fails | Report certification failure and block relevant publication. Do not describe it as ordinary per-change CI failure. |
| Private trusted evidence is unavailable | The merge remains blocked. There is no fallback to public CI, PATs, inherited secrets, or head-only evidence. |
| Private repository cannot support native merge queue/protection on the current plan | Autonomous prospective-merge cutover remains blocked for that repository. Do not replace it with a weaker custom head gate. |

The current private Control publisher revokes its source token before building and mints a narrowed write token only after build proof, which is directionally strong. It nevertheless executes source and later obtains the publisher token in the same job and runner. A separate publication job is needed to eliminate persistent-process and workspace contamination risk. 

The Repository Policy publisher is more exposed: the job is granted `contents: write` while checking out and building contributor-originated source. Its reproducibility and pointer-safety mechanics should be retained, but the privilege envelope must be split. 

---

## 8. Incremental and reversible transition plan

### Phase 0 — Establish enforceable current protection

Before removing any existing run:

1. Apply no-bypass pull-request protection to `institute-continuous-integration/main`.
2. Require the currently available `ci / matrix / ci-ok` and `control / validate`.
3. Add equivalent required statuses to `.github/main`.
4. Protect the private Control source through a supported classic protection or ruleset mechanism.
5. Preserve the existing post-main full matrix during this phase.

This closes the live direct-push and status-free merge gaps independently of the optimization.

### Phase 1 — Add event support without changing authority

1. Add `merge_group: checks_requested` to the canonical generated caller.
2. Teach the canonical GitHub event model and planner to resolve an exact merge-group subject.
3. Initially execute the same full plan on merge-group and retain the post-main full run.
4. Add fixture tests proving PR, merge-group, push-main, dispatch, and private event classification.

This phase is additive and reversible.

### Phase 2 — Extend independent control validation

1. Extend `control / validate` to the exact merge-group SHA.
2. Verify group membership, approved PR head, observed base, and expected check source.
3. Preserve candidate-destruction-before-write-token behavior.
4. Add positive and negative receipt fixtures.

### Phase 3 — Canary GitHub merge queue

1. Enable the queue for `institute-continuous-integration` and one ordinary public package.
2. Use one-entry groups.
3. Keep post-main full CI.
4. Exercise base movement, PR synchronization, queue removal, rerun, and stale-group cancellation.
5. Confirm that neither manual full runs nor bot approval can substitute for merge-group status.

### Phase 4 — Add post-main provenance in shadow mode

1. Add the `postMerge` tier in the existing central reusable workflow.
2. Run it alongside full main CI.
3. Compare its accepted merge-group/main mappings with the completed full main runs.
4. Require zero ambiguous mappings and zero false acceptances.

No publication should rely exclusively on it yet.

### Phase 5 — Split and gate publishers

1. Separate credential-free build/proof jobs from inert publication jobs.
2. Require two clean first-publication builds.
3. Require accepted main provenance before minting write credentials.
4. Standardize immutable digest assets, complete manifests, readback, and pointer-last behavior across Repository Policy, CI binaries, and private Control.
5. Run mismatch and failed-readback negative controls.

### Phase 6 — Move full certification earlier

After the canary acceptance window:

1. Make merge-group `ci-ok` the sole full matrix gate.
2. Stop treating manually dispatched full runs as review evidence.
3. Change push-main from full to post-merge provenance centrally.
4. Keep `workflow_dispatch` full diagnostics available.
5. Retain the ability to re-enable post-main full centrally as an emergency policy switch.

### Phase 7 — Fleet rollout

Use the existing generated caller and Repository Policy/convergence owners:

1. distribute the caller containing `merge_group`;
2. apply the canonical ruleset;
3. verify required status sources;
4. verify queue eligibility;
5. verify private-repository exceptions;
6. roll out in bounded waves with receipts.

Do not introduce a new migration-specific CI orchestrator.

### Phase 8 — Separate certification and migration telemetry

Normal per-change CI dashboards should exclude:

- same-source deterministic retries;
- scheduled publisher certifications;
- requested mismatch/readback controls;
- terminal-caller fleet waves;
- migration recovery retries.

Those runs remain durable evidence, but they are different evidence classes.

---

## 9. Acceptance criteria and positive/negative controls

### 9.1 Positive controls

The transition is acceptable only when all of the following are demonstrated:

1. A public PR produces `ci / matrix / ci-ok` on the exact PR head with no privileged credential.
2. Bot validation and approval are bound to that same head and the observed base.
3. Queue admission produces a new `merge_group` SHA.
4. Linux, Windows assertions, and Apple all succeed on that exact SHA.
5. The aggregate records Windows as gating and not `continue-on-error`.
6. `control / validate` succeeds on the exact group SHA.
7. Moving the base produces a different group SHA and new required checks.
8. The final squash commit maps uniquely to the accepted group through tree, base-parent, PR, and GitHub queue evidence.
9. Push-main provenance completes without ordinary build, test, or dependency-resolution work.
10. Publication remains blocked until that exact-main receipt is accepted.
11. Two clean publication builds produce identical bytes and manifests.
12. The publication job has no source checkout and executes no candidate-produced binary.
13. Readback succeeds before `CURRENT` advances.
14. A private workspace test runs on the exact trusted subject only after read credentials are revoked.
15. A publisher or CI-owner change automatically selects stronger evidence without any contributor-provided tier input.

### 9.2 Negative controls

Each of these must fail closed:

1. Selected Windows job is skipped.
2. Windows job fails.
3. A selected Linux or Apple result is absent.
4. A caller adds a tier input or weakens the private-repository guard.
5. A caller adds another reusable workflow hop.
6. The expected PR head differs from live head.
7. The approved head differs from the merge-group member.
8. The observed base differs from the group base.
9. A stale merge-group receipt is supplied after base movement.
10. The main tree does not equal the accepted prospective tree.
11. More than one receipt could authorize the same main commit.
12. `ci-ok` or `control / validate` comes from an unexpected App.
13. A floating action, floating container, unverified tool byte, PAT fallback, or `secrets: inherit` is introduced.
14. A privileged job attempts to execute a PR or merge-group artifact.
15. The publisher source differs from current protected main.
16. Build A and build B differ.
17. An existing immutable asset differs.
18. Upload/readback is deliberately corrupted.
19. A failure control changes `CURRENT`.
20. A PR synchronization cancels main provenance or publication.
21. A manual diagnostic run is presented as merge-group authorization.
22. Private required evidence is missing and the public caller is skipped.
23. A direct push or bypassed merge is attempted.

---

## 10. Estimated run-count, latency, and cost reduction

GitHub currently does not charge standard hosted-runner usage for public repositories. The figures below use current standard private-repository rates—Linux `$0.006`/minute, Windows `$0.010`/minute, and macOS `$0.062`/minute—as a normalizing equivalent. The actual `xcode-27` SKU may differ, so these are comparison figures rather than an invoice forecast. 

### 10.1 Ordinary change

| Measure | Current topology | Recommended ordinary topology | Reduction |
|---|---:|---:|---:|
| Heavy CI workflow runs | 3 | 2 | 33% |
| Full matrices | 2 | 1 | 50% |
| Cheap post-main verifier | 0 | 1 | Added intentionally |
| Total CI workflow runs | 3 | 3 | No count change; one run becomes cheap |
| Executed non-skipped CI jobs | 27 | Approximately 18 | About 33% |
| Windows full jobs | 2 | 1 | 50% |
| Apple full jobs | 2 | 1 | 50% |
| Runner-minutes | 243.6 | Approximately 148–150 | 93.5–95.5 minutes; **38–39%** |
| Private-rate equivalent | About `$3.04` | About `$1.69–$1.70` | About `$1.34`; **44%** |

The recommended estimate consists of:

- existing PR tier: approximately 52.5 runner-minutes;
- one merge-group full tier: approximately 94.5 runner-minutes;
- post-main verifier: estimated 1–3 Linux minutes.

### 10.2 Safe Linux identity coalescing

Eliminating the exact PR Linux duplicate would save another approximately 18.7 runner-minutes in the representative run. Combining the same-image full Linux build and test operations in one workspace should also remove duplicate checkout, container initialization, system dependency installation, dependency materialization, and overlapping compilation.

After only the exact PR duplicate is removed:

| Measure | Estimate |
|---|---:|
| Runner-minutes per ordinary change | Approximately 129–131 |
| Reduction from current | Approximately 46–47% |
| Private-rate equivalent | Approximately `$1.58–$1.59` |

The full Linux coalescing saving should be measured before being included in the terminal budget because `swift test -c release` and `swift build -c release` are distinct predicates and may cover different products.

### 10.3 PR #37-like publisher change

A publisher change should add a targeted credential-free deterministic dry run, estimated from the observed publisher at about 14 minutes. Including the final publisher:

| Lifecycle | Approx. runner-minutes |
|---|---:|
| Current three CI runs plus publisher | 257.9 |
| Recommended PR + merge group + provenance + dry run + publisher | 176–179 |
| Reduction | Approximately 79–82 minutes; **about 31%** |

This is a smaller percentage than an ordinary change because the additional publisher dry run is valuable, change-specific evidence rather than duplication.

### 10.4 Latency

The present PR #37 merged 38m31s after the first PR run started because the manual full run was dispatched almost immediately and ran concurrently. That result is fast but operator-dependent and still does not validate a prospective merge commit.

Using the observed durations and no queue wait, a strictly sequential PR-then-merge-group lifecycle would take approximately:

- PR feedback: 19m52s;
- full merge group: 35m47s;
- estimated merge eligibility: about 55m39s after PR start.

That is approximately 17 minutes slower than this unusually well-timed manual sample. The trade is:

- no human dispatch dependency;
- exact prospective-base correctness;
- deterministic stale-group handling;
- no 33m35s post-merge matrix;
- no chance that publication completes before successful full certification.

Failure-detection latency becomes:

- formatting and SwiftLint: about 1 minute after PR start;
- semantic linter: about 11–13 minutes;
- Linux build: about 19–21 minutes;
- Apple prospective failure: about 11 minutes after queue execution begins;
- Windows prospective failure: about 33–35 minutes after queue execution begins;
- publication-path failure: detected by the prospective publisher dry run instead of first being discovered after merge.

Post-merge publication authorization would add only the estimated 1–3 minute provenance verifier before the existing approximately 14-minute publisher. The current publisher is one to three minutes faster only because it is not waiting for a valid protected-main authorization boundary.

At 1,000 ordinary changes, the topology-only saving is approximately:

- **1,558–1,592 runner-hours**;
- approximately **$1,336–$1,348** at the private-rate equivalent;
- 1,000 fewer Windows jobs;
- 1,000 fewer Apple jobs;
- 1,000 fewer complete post-main matrices.

---

# Final verdict

## Safe to implement

**Yes.** The recommended topology is implementable through the existing canonical planner, one-hop caller, GitHub merge queue, control receipts, Repository Policy ruleset owner, and existing publisher architecture. It does not require a new migration-specific orchestration layer.

## Blocked from terminal cutover

**Yes.** The system must not yet be declared terminal, and the post-main full matrix must not yet be removed.

The blocking conditions are:

1. Apply enforceable no-bypass branch rules and required statuses to `institute-continuous-integration/main`.
2. Add required CI statuses and merge queue to `.github/main`.
3. Add `merge_group` handling to the canonical caller and planner.
4. Produce `control / validate` on the exact merge-group SHA.
5. Protect the private Control source branch through a supported mechanism before treating it as protected-main publication input.
6. Prove the post-main provenance mapping in shadow mode.
7. Gate every publisher on that exact-main receipt.
8. Separate source execution from publisher credentials by runner boundary.
9. Standardize first-publication reproducibility and immutable provenance across publisher families.
10. Pass the listed positive and negative controls in canary repositories.

Once those conditions are met, the full post-main matrix becomes both unnecessary and undesirable: it adds substantial Windows, Apple, Linux, and quality work after the only point at which that evidence could prevent the merge, while publication is the operation that actually requires exact protected-main reconstruction and provenance.
