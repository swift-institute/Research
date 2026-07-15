# Release-Wave Contract Provenance

<!--
---
version: 0.1.0
last_updated: 2026-07-15
status: DRAFT
tier: 3
scope: September 1, 2026 Swift Institute release-wave meta program
---
-->

## Purpose

This record fixes the authority, evidence boundaries, and derivation rules for
the September 1, 2026 release-wave contract before any normative skill text is
changed. It is intentionally not yet the final contract: one issue-specific
part of the current START acceptance was lost from the model context during
compaction, and an ASK is outstanding for the literal five enforcement-issue
names and any issue-specific registry fields or severity requirements.

No missing clause is inferred from historical documents. Policy-independent
generator, registry-schema, and census-control work may proceed; issue-specific
contract text remains draft until the durable channel reply is processed.

## Authority order

1. The Principal-settled 2026-07-15 `/workspace-start` release policy, as
   relayed through current generation-5 START assignments, is authoritative.
2. The immutable generation-5 `general` charter defines scope, edit zones,
   prohibited actions, and acceptance posture.
3. Canonical skills define requirement IDs and implementation rules. Generated
   registry rows are evidence about those rules, never a second rule source.
4. Current disk, Git, authenticated read-only GitHub/API observations, and
   reproducible tool output establish measured state.
5. Historical Research and Audit documents are prior evidence. Their
   recommendations do not become release policy without an explicit current
   ruling.

The current charter file is
`Workspace/charters/active/general.md`, SHA-256
`a1b2fe66d9e69ec3e5866df5e12f3400312e9244634839a7473aeff67e35841b`.
The `workspace-control.py` runtime used to receive authority and report through
the seat channel has SHA-256
`c4ca7798315ddbe1c59314e7ec01f1bae80f8a69913b3fd3b128f933008710c0`.

## Authorized outputs and boundaries

The active START scope is limited to:

- a canonical release meta-contract and its provenance under
  `Research/Release-Wave/`;
- a generated enforcement registry and supporting evidence;
- a measured, reconciled baseline of exactly the authoritative 448-repository
  fleet; and
- the generic `release-wave` process skill plus only necessary clean-file
  amendments in the charter-listed skill directories.

`release-plan-inputs` remains HOLD until a later current-generation START.
Broad package remediation is outside scope. Package repositories are read-only.
No push, tag, GitHub Release, visibility change, deployment, external message,
history rewrite, CI-history deletion, backup-tag deletion, or package mutation
is authorized.

## Source snapshot

The four artifact repositories are independent Git repositories, not one
super-repository. Their starting commits are:

| Repository | Starting `main` commit | Relevant starting state |
|---|---|---|
| `Research` | `072047efd4d872bacf8fbc2ce07c0c3bbedfb62e` | `Release-Wave/` absent and clean |
| `Audits` | `ac7eb392293b1904131c9d80f8e2ff5cb7488861` | `Release-Wave/` absent and clean |
| `Scripts` | `49ca2396e172a958ce78d8e5d86cd55cce16a99c` | no `release-wave-*` path existed |
| `Skills` | `34b86fc7a9189d4ef6b4bbd49daad909fe9a5b38` | new `release-wave/` absent; permitted existing skill paths clean |

Pre-existing dirty paths remain excluded. At the start of this work they were:

- `Skills/code-surface/SKILL.md`;
- `Skills/conversions/SKILL.md`;
- `Skills/document-markup/SKILL.md`;
- `Skills/swift-package/SKILL.md`;
- `Research/Reflections/.cadence.log`, `Research/_index.json`,
  `Research/skill-corpus-holistic-review.md`, and three unrelated untracked
  Research documents;
- `Audits/AUDIT-swift-linter-closure-launch-readiness.md`,
  `Audits/_index.json`, and `Audits/audit.md`; and
- two unrelated deleted `Scripts/__pycache__/*.pyc` paths.

No excluded byte may be modified. If a required normative amendment overlaps a
dirty source, the work produces a reviewable patch under
`Audits/Release-Wave/proposed-patches/` instead.

## Canonical skill snapshot

The following Git blob IDs identify the exact working-tree bytes loaded for
this design pass. A blob ID is recorded instead of only the Skills repository
HEAD because `code-surface/SKILL.md` was already dirty and remains read-only.

| Skill source | Git blob ID |
|---|---|
| `skill-lifecycle/SKILL.md` | `675a9163c06f5816f0636ca3e17439fbc7c86114` |
| `release-readiness/SKILL.md` | `f10643b7ee2fdc664282983509d74aeb4e3e4ed7` |
| `lint-rule-promotion/SKILL.md` | `6f8f03192a34a3061ffa6341cfeff3ad3546cbf9` |
| `swift-linter/SKILL.md` | `f5a525c3be14f4d711d1f52768a9a8d7fdc5d5e8` |
| `code-surface/SKILL.md` | `50a87f969bb1cee5da307f70bc3f279b58a2163c` |
| `modularization/SKILL.md` | `f8ef1cb51bf56ad30cad5f0950e9bb256221cdcc` |
| `ci-cd-workflows/SKILL.md` | `917ca3dbbb407a700f19db794b2731c354fe6028` |
| `audit/SKILL.md` | `ef547fcc3f35c93b311124f1a0db83ed4a7b0ad9` |
| `github-repository/SKILL.md` | `88e34b160621c555b5fa5d024c93a4076d3d8eea` |
| `social-preview/SKILL.md` | `f538d58b4d2bc8793a3e4314787ecdfeaaa3511b` |
| `swift-package-heritage/SKILL.md` | `40aee493bc2ac3366b587407fc35e064e62e4672` |

All declared dependencies were loaded recursively. The rules most directly
constraining this program are:

- provenance before normative skill edits and minimal, classified amendments;
- explicit mechanical, hybrid, and human verification classes;
- source-backed enforcement annotations and a generated registry subordinate to
  canonical rule text;
- width-checked negative queries and executable evidence for positive claims;
- census-by-manifest-or-`Sources/`, never repository-directory presence; and
- explicit placeholder state rather than clean-by-absence classification.

## Prior evidence and its disposition

The following prior documents are inputs, not silently-ratified policy:

| Document | Git blob ID | Disposition for this program |
|---|---|---|
| `versioning-and-release-strategy.md` | `99a64a1833c2c4dbed8866e8b8129146f522f3fa` | Tier-3 RECOMMENDATION; use its empirical and architectural findings only after current-state re-verification. Its independent-versioning and bottom-up campaign recommendations require current-policy confirmation before becoming contract text. |
| `skill-verification-taxonomy-extension-tier-1.md` | `1ae2c078b07580db1f5cacd0b2f1cf48fc7deef2` | Prior classification evidence; useful for schema vocabulary, not authoritative for current enforcement coverage. |
| `mechanical-rule-tool-classification-swift-primitives.md` | `5c659e6bae53aa18f50f42aa8a68a7a4d84cdb4b` | Historical tool-fit inventory; every carried row must be re-verified against current skill and validator sources. |
| `swift-64-dev-compatibility-catalog.md` | `a60a8f86c68c9e75c4c4804340c56638423761a4` | Pointer catalog; positive Swift 6.4 compatibility claims still require a current executable probe or CI receipt. |
| `swift-compiler-bug-catalog.md` | `10d9e6f430cec09bc7e4b7e8377a07b2829fd6d4` | Candidate issue evidence; no issue becomes a release blocker merely by appearing in the catalog. |

## Policy-independent registry invariants

The registry generator may implement these invariants before the outstanding
issue-name reply because they follow from the charter and canonical skills, not
from an unsettled policy choice:

1. One row is keyed by canonical requirement ID plus canonical source location.
2. Every row records the source repository commit and exact source blob.
3. Enforcement is classified as `mechanical`, `hybrid`, or `human`.
4. Mechanical and hybrid rows identify the validator, bundle or workflow
   membership, execution surface, CI gating status, exceptions, and verification
   evidence when those facts exist.
5. Missing, contradictory, aspirational, or stale enforcement metadata remains
   an explicit non-clean state; it never collapses to `none found`.
6. A zero-result query carries its walked paths, include/exclude filters, pattern
   or parser version, and a positive control that proves the query can match.
7. Generated outputs are deterministic for fixed source bytes and record their
   generator SHA and command line.
8. A second equivalent run must produce byte-identical normalized output, apart
   from explicitly separated run metadata.

## Policy-independent fleet invariants

The baseline must enumerate the authoritative fleet exactly once per repository.
Directory presence is insufficient. Each row must distinguish at least:

- implemented package (`Package.swift` and source-bearing package shape);
- manifest-bearing scaffold;
- namespace reservation or empty placeholder;
- archived or otherwise explicitly excluded repository; and
- missing/unavailable repository, if the authoritative inventory names one that
  cannot be observed.

The run must prove both completeness and uniqueness against the authoritative
448-repository inventory, preserve placeholders as explicit rows, record local
Git and read-only GitHub observations separately, and reconcile two equivalent
runs. Any count other than 448 is a failed baseline, not a near-success.

## Outstanding current-policy input

The only known context loss is the literal list of five named enforcement
issues and any issue-specific registry fields or severity requirements from the
current START acceptance. ASK command
`general-release-wave-ask-five-20260715-1` requests that exact information.
Until its reply is processed:

- the five issue rows are not invented from corpus search;
- no historical severity becomes current release severity by implication;
- issue-specific skill amendments do not begin; and
- policy-independent schema, provenance, source discovery, and census controls
  continue.

## Tool snapshot

The provenance pass ran at `2026-07-15T21:32:00Z`
(`2026-07-15T23:32:00+0200`) with:

- Apple Swift `6.3.3` (`swift-driver 1.148.6`), target
  `arm64-apple-macosx26.0`;
- Python `3.14.2`; and
- GitHub CLI `2.92.0`.

Tool versions do not establish compatibility by themselves. Commands and
positive controls belong in the generated evidence for the claims they support.

## Amendment discipline

This document remains `DRAFT` until the current-policy gap is closed and the
full contract receives independent review. Moving it to a decision state
requires:

1. processing the durable channel reply;
2. recording every accepted current-policy clause without inference;
3. reconciling prior recommendations against current measured state;
4. identifying any genuinely unresolved decision as an ASK;
5. completing an independent review; and
6. recording exact verification commands and artifact SHAs.
