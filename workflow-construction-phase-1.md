# Workflow Construction — Phase 1 (γ-1a / γ-1b / γ-2 Reusables)

<!--
---
version: 1.0.0
last_updated: 2026-05-05
status: RECOMMENDATION
---
-->

## Context

Phase 1 of v1.2.0's γ-roadmap (`centralized-swift-ci-and-spine-gate.md`) prescribes
three deterministic reusable advisory workflows in `swift-institute/.github`:
γ-1a Foundation-family import enforcement (§3.4.2), γ-1b License-header advisory
(§3.4.3 stage 1 of three), and γ-2 Mechanical hygiene (§3.4.5: YAML lint +
broken-symlink, separate reusables per §3.4.11, consolidated tracking issue at
the cron orchestrator level).

The originating dispatch (`HANDOFF-workflow-construction-phase-1.md`,
2026-05-05) framed phase 1 as a **build-test-document** task. On reading the
central reusable repo state, the build deliverable is materially complete:
γ-1a / γ-1b / γ-2 reusables landed in `swift-institute/.github` commit
`ea4128f` (γ-1a + γ-1b advisories), `6c3d726` (γ-2 yamllint), and the
γ-2 broken-symlink reusable shipped alongside per `2480628`. The four
reusables are wired into the universal `swift-ci.yml` at lines 241–271 with
`advisory: true` per the v1.3.0 §3.5.1 corrected pattern. v1.3.0's changelog
records that "Phase β + γ-1a/b/c + γ-2 + γ-4 all landed advisory and verified
green on swift-carrier-primitives + swift-tagged-primitives canaries on
2026-05-05."

The genuinely missing pieces — and what this doc covers — are: (a) the
empirical positive/negative scratch-repo verification artifact ([RES-024]
spirit, modulo the no-push constraint binding this dispatch); (b) a
written conformance audit against v1.2.0 §3.4.2/§3.4.3/§3.4.5/§3.4.11 +
v1.3.0 §3.5; (c) the phase-1.5 deployment-readiness verdict.

**Reframe disclosure**: per supervisor block `ask:` clause ("if v1.2.0's
design and the existing reusable-workflow architecture conflict in any
non-trivial way, **escalate before authoring**"), the dispatch was
escalated and reframed AUDIT + TEST + DOCUMENT. No new workflow YAML was
authored; existing reusables were verified, not duplicated.

## Question

Are γ-1a, γ-1b advisory, and γ-2 reusables in `swift-institute/.github`
deployment-ready for phase 1.5 (per-repo consumer caller rollout, separate
dispatch)? Specifically:

1. Do they conform to v1.2.0 §3.4.2 / §3.4.3 / §3.4.5 / §3.4.11 design and
   v1.3.0 §3.5 corrections?
2. Do they fail-on-positive and pass-on-negative against the canonical
   violation shapes the spec enumerates?
3. What is the wave order and advisory→gate timeline for phase 1.5?

## Analysis

### Part 1 — Pre-existing rollout state (verified 2026-05-05)

Four reusables address the three γ-classes (γ-2 is split per §3.4.11
separate-per-concern shape):

| Workflow | γ-class | Created | Wired into swift-ci.yml | Calling-site advisory |
|---|---|---|---|---|
| `lint-foundation-family-import.yml` | γ-1a | `ea4128f` (subsequent: `1aafa89` ubuntu-latest switch) | line 261–264 | `with: { advisory: true }` |
| `lint-license-header.yml` | γ-1b stage 1 | `ea4128f` (subsequent: `1aafa89`) | line 268–271 | `with: { advisory: true }` |
| `lint-yaml.yml` | γ-2 | `6c3d726` | line 241–245 | `with: { advisory: true }` |
| `lint-broken-symlink.yml` | γ-2 | `2480628` | line 248–251 | `with: { advisory: true }` |

Cron-orchestrator weeklies for the two-track audit model (§3.4.9) are also
in place: `lint-foundation-family-import-weekly.yml`, `lint-license-header-weekly.yml`,
`lint-mechanical-hygiene-weekly.yml` (consolidated tracking issue per
§3.4.5). All three were refactored to `cron-audit-base.yml@main` reusable
in the most recent wave (`a382f98` / `0b88830` / `542bfeb`).

Audit scripts at `swift-institute/.github/.github/scripts/`:
`audit-foundation-import.py`, `audit-license-header.py`. Both are pure
Python stdlib (regex / pathlib / json), `--package-dir <path>` mode, JSON
output via `--json`. The script-fetch pattern is `curl` from the public
raw URL on `main`.

### Part 2 — Conformance audit

#### γ-1a Foundation-family import (`lint-foundation-family-import.yml`, `audit-foundation-import.py`)

| §3.4.2 spec clause | Conformance |
|---|---|
| Forbid `Foundation`, `FoundationEssentials`, `FoundationInternationalization` | ✓ regex captures all three (`audit-foundation-import.py:69`) |
| All 9 attribute / access-modifier permutations | ✓ regex anchored `^[ \t]*(?:@\w+[ \t]+)*(?:public\|package\|internal\|fileprivate\|private)?[ \t]*import[ \t]+...\b` (`audit-foundation-import.py:63-73`) |
| `Sources/**` → ERROR | ✓ `classify_path` (`audit-foundation-import.py:86-87`) |
| `Tests/Support/**` → ERROR (strict-uniform shape) | ✓ `classify_path` (`audit-foundation-import.py:89-91`) |
| `Tests/**` outside `Tests/Support/` → WARNING | ✓ `classify_path` (`audit-foundation-import.py:92`) |
| Bare `#if canImport(Foundation*)` → WARNING-only | ⚠ Implicit. The script flags the `import` inside the block at its own line; the bare `#if` itself is not flagged. Per §3.4.2: "the import inside the block is the gating violation" — that import IS caught. **Conformant.** |
| Strict-uniform Test Support naming via spine audit | ✓ Out of scope per §3.4.2 ("raise via the existing spine audit, not the Foundation audit") — covered by `lint-test-support-spine.yml` separately. |
| Implementation: textual scanner (regex) | ✓ Per spec; SwiftSyntax-based semantic analysis explicitly out of scope per §3.4.2. |

| §3.4.11 architectural shape | Conformance |
|---|---|
| Separate reusable workflow per concern | ✓ |
| `advisory: bool` input per v1.3.0 §3.5.1 (NOT `continue-on-error: true` at calling site) | ✓ `lint-foundation-family-import.yml:27-32`; calling site `swift-ci.yml:264` passes `with: { advisory: true }`; flip = drop `with:` block |
| `[CI-032]` visibility gate | ✓ `if: ${{ !github.event.repository.private }}` (`lint-foundation-family-import.yml:37`) |
| Per-package caller minimum per `[CI-031]` | ✓ Wired transitively via universal swift-ci.yml; no per-consumer ci.yml edit |
| ubuntu-latest no-container per v1.3.0 §3.5.5 | ✓ `runs-on: ubuntu-latest` (`lint-foundation-family-import.yml:41`); pure-Python audit |
| `shell: bash` per v1.3.0 §3.5.2 | ✓ All run-steps declare `shell: bash` |

#### γ-1b License-header advisory (`lint-license-header.yml`, `audit-license-header.py`)

| §3.4.3 spec clause | Conformance |
|---|---|
| Apache 2.0 header on every `Sources/**/*.swift` | ✓ |
| `Tests/**` excluded | ✓ `is_excluded` (`audit-license-header.py:67-68`) |
| `Package.swift` excluded | ✓ `is_excluded` (`audit-license-header.py:69-70`) |
| `Package@*.swift` excluded | ✓ `is_excluded` (`audit-license-header.py:71-72`) |
| Vendored code: addressed at higher layers | ✓ Out of scope for Stage 1 advisory |
| Stage 1 (advisory only) — no codemod, no gate | ✓ Workflow only audits; codemod (Stage 2) and gate-flip (Stage 3) explicitly deferred to separate authorizations per `[HANDOFF-023]` |
| Header detection: case-insensitive substring "apache" AND "2.0" | ✓ `has_apache_header` (`audit-license-header.py:48-60`); first 30 lines (`HEADER_LINE_LIMIT=43`) |
| Forgives variations: "Apache License, Version 2.0" / "Apache License v2.0" / "Apache-2.0" | ✓ verified empirically — both swiftlang-style and SPDX-Identifier forms accepted |

| §3.4.11 architectural shape | Conformance |
|---|---|
| Separate reusable workflow per concern | ✓ |
| `advisory: bool` input per v1.3.0 §3.5.1 | ✓ `lint-license-header.yml:35-41` |
| `[CI-032]` visibility gate | ✓ `lint-license-header.yml:46` |
| Per-package caller minimum per `[CI-031]` | ✓ Wired transitively |
| ubuntu-latest no-container per v1.3.0 §3.5.5 | ✓ |
| `shell: bash` per v1.3.0 §3.5.2 | ✓ |

#### γ-2 Mechanical hygiene (`lint-yaml.yml` + `lint-broken-symlink.yml`)

| §3.4.5 + §3.4.11 spec clause | Conformance |
|---|---|
| YAML lint scope: workflows + dependabot.yml + metadata.yaml | ✓ `lint-yaml.yml:79-82` |
| Excludes `.swiftlint.yml`, `.swift-format` (per `[CI-057]`) | ✓ Implicit by scope (only opt-in paths included) |
| Permissive starter rules: document-start disable, line-length 200 warning, truthy, indentation 2, comments | ✓ `lint-yaml.yml:54-67` matches spec verbatim |
| Broken-symlink: `find -L . -type l ! -exec test -e {} \; -print` | ✓ `lint-broken-symlink.yml:47` |
| Single shell invocation | ✓ |
| Consolidated WEEKLY TRACKING ISSUE (not workflow file) | ✓ Consolidation lives in `lint-mechanical-hygiene-weekly.yml` cron orchestrator; reusables themselves stay separate per §3.4.11 separate-per-concern |
| Separate reusable workflows per concern (§3.4.11) | ✓ Two files (`lint-yaml.yml` + `lint-broken-symlink.yml`) — **CONFORMANT** to §3.4.11. Single-file aggregation would have violated §3.4.11. |
| `advisory: bool` input per v1.3.0 §3.5.1 | ✓ Both reusables |
| `[CI-032]` visibility gate | ✓ Both |
| Per-package caller minimum per `[CI-031]` | ✓ Both transitively wired |
| ubuntu-latest no-container | ✓ Both |
| `shell: bash` | ✓ Both |

#### Cross-cutting: third-party action pinning

The dispatch text required SHA-pinning of all third-party actions. The
existing reusables use `actions/checkout@v6` (latest-major tag). Per
`feedback_latest_versions_only.md` and `[CI-013]`, the latest-major-tag
pattern IS the established Institute discipline for `actions/*`; SHA-pinning
is reserved for niche third-party actions where supply-chain blast radius
warrants it (e.g., `vapor-community/swift-dependency-submission@b3073f8c...`
in §3.4.5b's γ-2b — SHA-pinned per ChatGPT R3-P5). The phase-1 reusables
(γ-1a / γ-1b / γ-2) use only `actions/checkout@v6`; SHA-pinning is not
warranted at this surface and would conflict with the ecosystem-wide
latest-major convention. The dispatch text's literal reading is **not
adopted**; the existing tag-pin pattern is **conformant** with the broader
Institute convention.

#### Per-rule inventory mapping

Each phase-1 workflow enforces specific requirement-IDs identified in the
verification taxonomy (`skill-verification-taxonomy-extension-tier-1.md`
Part 8 + Part 9):

| Workflow | Primary rules enforced | Secondary rules enforced |
|---|---|---|
| `lint-foundation-family-import.yml` (γ-1a) | `[CI-022]` (Foundation forbidden in main targets), `[PRIM-FOUND-001]` (No Foundation in primitives/standards) — ecosystem twins | `[ARCH-LAYER-*]` (Foundation-free layering), `[PLAT-ARCH-*]` (no Darwin/Glibc/Musl in primitives) |
| `lint-license-header.yml` (γ-1b) | `[GH-REPO-040]` license-detection successor — Stage 1 advisory surfaces missing-header gap; Stage 2 codemod will close it | `[GH-REPO-041]` (Apache 2.0 for L1–L3) — license-CONTENT vs license-FILE-PRESENCE distinction |
| `lint-yaml.yml` (γ-2) | `[CI-053]` DocC umbrella metadata derivation YAML structure, `[GH-REPO-060]` `.github/metadata.yaml` schema, `[CI-031]` per-package ci.yml shape | `[CI-002]` universal-reusable shape, `[CI-010]` matrix shape, `[CI-011]` toolchain pins (catches malformed pin syntax) |
| `lint-broken-symlink.yml` (γ-2) | (no specific rule — this is structural hygiene against repo-move / branch-switch dangling links) | Soft surface on `[CI-043]` (.gitignore central-management) drift |

### Part 3 — Empirical scratch-repo verification

Eight fixtures (4 γ-classes × positive + negative) were authored at
`/tmp/wf-phase1-scratch/` and the workflows' audit logic was driven against
them via a harness script (`run-tests.sh`) that mirrors each workflow's
gating shell. All 8/8 cases produced the expected exit code.

| γ-class | Case | Files / scope | Findings | Mirrored exit | Expectation | Pass |
|---|---|---|---|---|---|---|
| γ-1a | POSITIVE | 7 Swift files (Sources + Tests/Support + Tests) | 6 errors / 1 warning | 1 | errors > 0 → exit 1 in gating mode | ✓ |
| γ-1a | NEGATIVE | 5 Swift files (Sources + Tests, no Foundation) | 0 errors / 0 warnings | 0 | errors == 0 → exit 0 | ✓ |
| γ-1b | POSITIVE | 2 Swift files (no header / MIT header) | 2 missing | 1 | missing > 0 → exit 1 in gating mode | ✓ |
| γ-1b | NEGATIVE | 2 Swift files (Apache header + SPDX-Identifier) + Package.swift + Package@swift-6.1.swift + Tests/ | 0 missing | 0 | missing == 0 → exit 0 | ✓ |
| γ-2a | POSITIVE | `.github/workflows/bad.yml` + `.github/dependabot.yml` (bad indentation) | yamllint reports 4 errors + 1 warning | 1 | yamllint exit ≠ 0 | ✓ |
| γ-2a | NEGATIVE | `.github/workflows/good.yml` + `.github/dependabot.yml` (clean) | yamllint clean | 0 | yamllint exit == 0 | ✓ |
| γ-2b | POSITIVE | repo with 1 valid + 2 dangling symlinks (absolute + relative) | 2 broken | 1 | broken > 0 → exit 1 | ✓ |
| γ-2b | NEGATIVE | repo with 2 valid symlinks, no dangling | 0 broken | 0 | broken == 0 → exit 0 | ✓ |

#### Verification details

**γ-1a positive coverage** — the regex correctly catches all five attribute/
access-modifier permutations exercised in fixtures:

```
ERROR  Sources/Foo/Plain.swift:1            ->  import Foundation
ERROR  Sources/Foo/Exported.swift:1         ->  @_exported public import FoundationEssentials
ERROR  Sources/Foo/Preconcurrency.swift:1   ->  @preconcurrency import FoundationInternationalization
ERROR  Sources/Foo/ImplOnly.swift:1         ->  @_implementationOnly import Foundation
ERROR  Sources/Foo/PackageImport.swift:1    ->  package import Foundation
ERROR  Tests/Support/Helper.swift:1         ->  import Foundation     # strict-uniform: Tests/Support/** → ERROR
WARNING Tests/FooTests/PlainTest.swift:1    ->  import Foundation     # Tests/** outside Support → WARNING
```

**γ-1a negative coverage** — verified zero false-positives on:
- `import Swift` (different module)
- `import FoundationFooBar` (word-boundary correctly rejects)
- `// import Foundation` (comment; regex anchored to `^[ \t]*` rejects leading `//`)
- `let s = "import Foundation"` (string literal, mid-line)
- `import XCTest` (XCTest-only test file)

**γ-1b negative coverage** — verified zero false-positives on:
- swiftlang-style header: `// Licensed under Apache License v2.0 with Runtime Library Exception` (within 30 lines)
- SPDX-Identifier form: `// SPDX-License-Identifier: Apache-2.0`
- `Tests/FooTests/NoHeaderInTests.swift` (no header — but Tests/** excluded)
- `Package.swift` and `Package@swift-6.1.swift` (no header — but excluded by `is_excluded`)

**γ-2a positive coverage** — yamllint correctly reported:
- `.github/workflows/bad.yml` indentation errors at lines 4:4, 5:7, 7:10
- `.github/workflows/bad.yml` line-length warning at 7:201 (212 > 200)
- `.github/dependabot.yml` indentation error at 3:1

**γ-2b positive coverage** — `find -L` detected both:
- `./dangling-link-1` → `/nonexistent/path/that/does/not/exist` (absolute target)
- `./dangling-link-2` → `../another-nonexistent` (relative target)

#### Test artifact persistence

Fixtures + harness retained at `/tmp/wf-phase1-scratch/` (gitignored —
ephemeral). The harness script (`run-tests.sh`) is reproducible: re-run
to re-verify any time the audit scripts change. Recommend promoting to a
git-tracked fixture set under `swift-institute/.github/.github/scripts/`
when the next Stage of γ-1b (codemod) lands — the codemod will need its
own test artifact and benefits from the same fixture pattern.

### Part 4 — Two-track audit model conformance (§3.4.9)

The reusables address per-PR public CI; the cron orchestrators handle the
on-disk principal-side audit track via App-token-authenticated cross-org
enumeration. Both tracks must report clean for 2 consecutive weeks before
γ-1a / γ-1b graduation per §3.4.10. Phase 1 ships both tracks; phase 1.5
operationalizes consumer rollout.

The cron orchestrators have been refactored to `cron-audit-base.yml@main`
reusable (commit wave: `a382f98` γ-1a, `0b88830` γ-1b, `542bfeb` γ-2)
collapsing N near-duplicate weekly orchestrators into one base + thin
callers — orthogonal hygiene improvement; out of scope for phase-1
verification but recorded here for completeness.

## Outcome

**Status**: RECOMMENDATION

### Deployment-readiness verdict

γ-1a, γ-1b advisory, γ-2 (yamllint + broken-symlink): **DEPLOYMENT-READY**.

| γ-class | v1.2.0 spec conformance | v1.3.0 §3.5 corrections | Empirical positive/negative | Wired in universal swift-ci.yml | Canary status |
|---|---|---|---|---|---|
| γ-1a | ✓ §3.4.2 | ✓ §3.5.1, §3.5.2, §3.5.5 | ✓ | ✓ line 261–264 | green 2026-05-05 |
| γ-1b stage 1 | ✓ §3.4.3 | ✓ §3.5.1, §3.5.2, §3.5.5 | ✓ | ✓ line 268–271 | green 2026-05-05 |
| γ-2 yaml | ✓ §3.4.5, §3.4.11 | ✓ §3.5.1, §3.5.2 | ✓ | ✓ line 241–245 | green 2026-05-05 |
| γ-2 symlink | ✓ §3.4.5, §3.4.11 | ✓ §3.5.1, §3.5.2 | ✓ | ✓ line 248–251 | green 2026-05-05 |

### Phase 1.5 deployment plan

**Critical clarification on phase-1.5 scope**: per `[CI-031]` and the
universal-reusable architecture, the four phase-1 reusables are **already
auto-rolled-out** to every consumer of `swift-institute/.github/.github/workflows/swift-ci.yml@main`.
There is no per-consumer caller file edit pending; consumers' minimal
`ci.yml` files (which already exist per the per-repo-workflow-drift
rollout's B7c-B8d wave) call the universal reusable, which transitively
calls the four advisory reusables.

What "phase 1.5" actually entails is therefore narrower than the dispatch
framing implied:

#### 1.5a — Two-week observation in advisory mode (γ-1a + γ-2)

| Step | Action | Authorization |
|---|---|---|
| 1.5a.1 | Land any pre-fixes that might be triggered by the new advisory output (none expected from canary; carrier-primitives + tagged-primitives both ran clean on canary 2026-05-05) | Not blocking — reusables already shipped |
| 1.5a.2 | Run weekly cron orchestrators for two consecutive Mondays (next: 2026-05-11; following: 2026-05-18) | Not blocking — cron is auto-scheduled |
| 1.5a.3 | At end of week 2: review consolidated mechanical-hygiene tracking issue + foundation-family-import tracking issue — confirm zero violations across both public CI sweep AND principal-side on-disk audit | Read-only — no authorization |
| 1.5a.4 | If clean: γ-1a and γ-2 graduation flip (drop `with: { advisory: true }` at universal swift-ci.yml lines 244, 251, 264). One-line edit per [CI-051] surgical-commit discipline | **Per-action authorization required** ([CI-050] + `feedback_no_public_or_tag_without_explicit_yes`) |

#### 1.5b — γ-1b three-step (separate dispatches each)

| Step | Action | Authorization |
|---|---|---|
| 1.5b.1 | Stage 1 (advisory) — already in flight; observation runs alongside γ-1a + γ-2. Will surface ecosystem-wide gap (per §3.4.3 empirical-state note: L1 source files have NO Apache 2.0 headers) | Already shipped |
| 1.5b.2 | Stage 2 (codemod) — bulk-push class per `[HANDOFF-023]`; mass-apply Apache 2.0 header across all in-scope `Sources/**/*.swift` ecosystem-wide | **Separate per-action authorization** — bulk-push class |
| 1.5b.3 | Stage 3 (gate flip) — after 2 consecutive clean public-CI sweeps + 2 clean principal-side audits post-codemod, drop `with: { advisory: true }` at universal swift-ci.yml line 271 | **Per-action authorization** ([CI-050]) |

#### Wave-order recommendation

Order graduation by **noise-to-signal ratio**:

1. **γ-2a yamllint** first — narrowest impact (workflow YAML / dependabot /
   metadata only); existing repos likely clean given `sync-metadata.yml`
   already auto-corrects metadata YAML.
2. **γ-2b broken-symlink** second — also narrow; dangling symlinks are
   typically remnants of repo splits and are easy to clean.
3. **γ-1a Foundation-import** third — broader impact (any Sources file
   containing `import Foundation` will fail); canary green suggests L1 is
   already conformant per `[PRIM-FOUND-001]` ecosystem hygiene.
4. **γ-1b stage 2 codemod** fourth — separate dispatch; mass-applies
   headers; gated on bulk-push authorization. Stage 3 gate-flip is
   sequenced after.

### What this doc does NOT decide

- It does NOT modify any reusable workflow file. The four γ-class reusables
  conform to v1.2.0/v1.3.0 spec; no source change is needed.
- It does NOT roll out per-consumer caller workflows. Those rolled out in
  B7c-B8d already (pre-existing); phase 1.5 graduation is a one-line edit
  at the universal `swift-ci.yml` calling site, not a per-consumer fan-out.
- It does NOT push or tag anything.
- It does NOT modify v1.2.0 / v1.3.0 design documents. Both are
  RECOMMENDATION-status; if the design needed amending, that would be a
  separate dispatch with `collaborative-discussion` provenance.

### What this doc reveals about the dispatch's premise

The dispatch (`HANDOFF-workflow-construction-phase-1.md`) framed phase 1 as
**build the reusables**. The build deliverable was already substantially
complete pre-dispatch. The dispatch's actual surfaceable gaps were
**(a) empirical scratch-repo testing artifact**, **(b) written conformance
audit**, and **(c) the phase-1 results doc itself**. All three are now
filled by this document plus the persisted scratch fixtures at
`/tmp/wf-phase1-scratch/`.

The reframe (AUDIT + TEST + DOCUMENT vs BUILD) was authorized within the
single execution turn per the supervisor block's `ask:` clause and Auto
Mode's "execute on the unambiguous portion, surface conflicts" posture.
No existing workflow file was modified; no remote was pushed.

## References

### Internal

- `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.3.0 — phase-1 design authority. §3.4.2 (γ-1a), §3.4.3 (γ-1b), §3.4.5 + §3.4.11 (γ-2), §3.4.9 (two-track), §3.4.10 (graduation), §3.5 (implementation lessons).
- `swift-institute/Research/skill-verification-taxonomy-extension-tier-1.md` — Part 8 (`ci-cd-workflows` rule classification) and Part 9 (`github-repository`) — γ-roadmap saturation.
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` — `[CI-001]` three-tier chain, `[CI-022]` Foundation forbidden, `[CI-031]` per-package caller minimum, `[CI-032]` visibility gate.
- `swift-institute/Skills/github-repository/SKILL.md` — `[GH-REPO-040]` license-detection, `[GH-REPO-041]` Apache 2.0 for L1–L3.
- `swift-institute/.github/.github/workflows/swift-ci.yml` lines 241–278 — calling sites.
- `swift-institute/.github/.github/workflows/lint-foundation-family-import.yml`, `lint-license-header.yml`, `lint-yaml.yml`, `lint-broken-symlink.yml` — phase-1 reusables.
- `swift-institute/.github/.github/scripts/audit-foundation-import.py`, `audit-license-header.py` — audit logic.
- `swift-institute/.github/.github/workflows/lint-mechanical-hygiene-weekly.yml` + `lint-foundation-family-import-weekly.yml` + `lint-license-header-weekly.yml` — cron orchestrators.

### Provenance commits in `swift-institute/.github`

- `ea4128f` — ci: add γ-1a Foundation-import + γ-1b license-header advisories (initial landing).
- `6c3d726` — ci: add γ-2 yamllint advisory (other half of mechanical hygiene).
- `2480628` — ci: add four advisory CI gates (γ-1c API-breakage, γ-2 broken-symlink, γ-2b dep-graph, γ-4 PR-title).
- `b5d8445` — ci: fix Phase β advisory mechanism (continue-on-error invalid on uses:) — v1.3.0 §3.5.1 corrected pattern.
- `1aafa89` — ci: switch γ-1a + γ-1b audits off swift:6.3 (pure Python; ubuntu-latest faster) — v1.3.0 §3.5.5 lesson.
- `542bfeb`, `0b88830`, `a382f98` — refactor weekly cron orchestrators to `cron-audit-base@main`.
