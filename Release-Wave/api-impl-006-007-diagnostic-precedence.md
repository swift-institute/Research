# API-IMPL-006 / API-IMPL-007 diagnostic precedence

Date: 2026-07-16

Status: evidence-backed design record for a separately reviewable clarifying amendment; no canonical Skill edit has been applied.

Work ID: `release-execution-preparation-r2`

## Question

The R1 adjudication left 510 `API-IMPL-006` diagnostics classified as same-file cascades of accepted `API-IMPL-007` roots. R2 asks whether these are duplicate normative requirements, one requirement implemented twice, independent requirements with overlapping symptoms, or primary/secondary diagnostics for the same concrete repair.

Diagnostic frequency is not evidence for any answer. Classification must follow the canonical obligations, the exact pinned declaration source, and a counterfactual repair: after applying the `API-IMPL-007` repair, does `API-IMPL-006` necessarily cease to be violated?

## Existing semantics

At Skills commit `19b4fa7546641e9733b43276f5fe4cb19bb085be`:

- `[API-IMPL-006]` requires a Swift filename to match the declared type's full nested path. Its documented enforcement excludes the `+` conformance and ` where ` discriminator shapes governed by `[API-IMPL-007]`.
- `[API-IMPL-007]` requires extension files to use the `+` suffix for added conformance or the where-clause filename shape for suppressed-protocol-constraint discrimination.

These are independent obligations. `API-IMPL-006` governs type-path filename parity; `API-IMPL-007` governs extension-discriminator filename shape. They are neither duplicate canon nor one normative rule implemented twice.

## Exact-source result

The reconciliation generator at Scripts commit `aa1fbaacc38a50601470551bb4f6c4e6aab610d8` read every candidate from its immutable repository HEAD and used the validator parser at `.github` commit `7f666a504cf8e517af996d34d4fcc7f1e71599c2`. The 510 records partition as follows:

- 497 member-only pure-extension files: `API-IMPL-006` remains independently visible. The canonical applicability of `API-IMPL-007` to member-only extensions is not settled by its conformance/where statement, so the existing `API-IMPL-007` findings remain in an explicit adjudication queue.
- 6 mixed files containing both discriminator-bearing and member-only top-level extensions: extracting or renaming the discriminator-bearing extensions does not necessarily correct the member-only filename/type-path mismatch, so both diagnostics remain.
- 7 files whose every top-level extension carries a conformance or where-clause discriminator: the canonical `API-IMPL-007` split/rename necessarily moves every file into an `API-IMPL-007` filename shape already excluded by the documented `API-IMPL-006` enforcement boundary. Here `API-IMPL-007` is the primary diagnostic and `API-IMPL-006` is a redundant cascade.

The validator therefore suppresses `API-IMPL-006` only for the proven seven-case predicate. It retains the other 503. Comments, strings, attributes, modifiers, nested paths, extension targets, mixed causes, independent member-only extensions, and specification-mirroring names are covered by fixtures or the complete fixture corpus.

## Proposed canonical clarification

Classification: **Clarifying** under `[SKILL-LIFE-003]`. The proposal does not change either requirement's statement, compliant source set, exemptions, severity, rule ID, bundle membership, or historical evidence. It documents the conditional diagnostic precedence already implied by the two independent obligations and their existing enforcement boundaries.

Proposed meaning:

1. `API-IMPL-006` and `API-IMPL-007` remain independent requirements.
2. A validator may omit an `API-IMPL-006` diagnostic as an `API-IMPL-007` cascade only when exact declaration parsing proves that every top-level extension carries a conformance or where-clause discriminator and the required `API-IMPL-007` filename repair necessarily enters the documented `API-IMPL-006` enforcement exclusion.
3. Member-only, mixed, incomplete, or unparsed extension shapes retain `API-IMPL-006`; co-firing count or fleet prevalence cannot select the precedence branch.

The separately reviewable patch is recorded under `Audits/Release-Wave/proposed-patches/` because `Skills/code-surface/SKILL.md` is pre-existing dirty and outside this seat's edit zone. Applying it later must preserve the existing R1 enforcement-boundary proposal, bump `last_reviewed` in the same canonical commit, run corpus checks, and receive fresh independent review.

## Promotion and severity guard

`[PROMOTE-004]` already states that count alone cannot distinguish real ecosystem gaps from validator defects and that branch choice always requires inspection regardless of count. No `lint-rule-promotion` amendment is needed for the Principal's frequency constraint.

The R2 mechanism changes diagnostic factoring only. It does not merge or retire a rule ID, transfer an obligation, alter severity, promote gating status, or authorize package remediation. Historical evidence remains traceable under both rule IDs.

## Evidence and unresolved decision

The generated reconciliation is `Audits/Release-Wave/release-execution-preparation-r2-validator-repair.json`. It records the exact source hashes, finding IDs, layer and dependency-position counts, A/B receipts, fixture receipt, focused-test receipt, and controls proving the R1 accepted violation and remediation-unit counts were not silently reduced.

One Principal decision remains specific to this relationship: clarify whether member-only pure-extension files are normatively in scope for `[API-IMPL-007]`. R2 preserves all 497 member-only and 6 mixed `API-IMPL-007` roots pending that decision; it does not infer an answer from current validator behavior or prevalence.
