---
date: 2026-04-26
session_objective: Run a compiler-verify probe gating the L1-types-only-no-exceptions migration in swift-kernel-primitives; report green/red with empirical evidence, append a §6.2 probe-result subsection, commit.
packages:
  - swift-primitives/swift-kernel-primitives
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: experiment-process
    description: "[EXP-017a] Matrix Disambiguation for #if-Gated Probes — generalizes leg-axis enumeration as third matrix dimension. Provenance-only ID-uniqueness work also resolved pre-existing duplicate [EXP-017]/[EXP-018] in same skill (older Improvement Discovery → [EXP-019]; newer Claim Validation Trap → [EXP-020]) per [REFL-PROC-016]."
---

# Typealias-via-#if probe — matrix disambiguation under supervisor pushback

## What Happened

Task scoped narrowly: run a compiler-verify probe at `/tmp/typealias-probe`
to gate the L1-types-only-no-exceptions migration in
`swift-kernel-primitives`. The probe verifies whether `~Copyable`
typealiases of distinct per-platform `~Copyable` types compose with
extension methods declared once on the typealias name. The migration's
mechanical viability (§6.2 of `Research/l1-types-only-no-exceptions.md`)
hinges on the answer; skill-cycle dispatch and migration execution are
both downstream of this gate.

**Initial probe (commit `f14cf8f`)**: single-module variant matching the
literal spec — two `~Copyable` structs `A` and `B` (each stored `Int` +
trivial `deinit`), `#if`-gated typealias `C = A` on
`os(macOS) || os(Linux)` else `C = B`, single
`extension C { public func ping() -> Int { value } }`. Ran debug + release
green for the literal-`#if` (A-leg) form; B-leg verified by inverting
the `#if` to force the else branch (debug only). Then added a cross-module
variant per [EXP-017] release-mode + cross-module gating: A in `ProbeA`,
B in `ProbeB`, typealias + extension in `ProbeUnifier`
(re-exporting both via `@_exported public import`), consumer
`typealias-probe-xmod` imports `ProbeUnifier` only. Cross-module ran
debug + release green. Appended `### 6.2.1 §6.2 Probe Result` to the
research doc; v1.0.0 → v1.1.0; status RECOMMENDATION preserved per
explicit instruction. Reported GREEN.

**Supervisor pushback**: three checks came back. Check (1) on matrix
coverage exposed an under-specification — the §6.2.1 table read "Cross-module
... debug + release" without disambiguating the `#if`-leg axis. The
supervisor's reading was "B-leg got SM debug + XM debug + XM release; one
SM-release gap". Re-deriving from the actual probe runs (per [REFL-011])
revealed three B-leg gaps, not one: the cross-module variant on macOS
selects `C = A` via the literal `#if`, so XM covered A-leg only. Actual
matrix at `f14cf8f`: A-leg 4/4, B-leg 1/4 (SM debug only).

Closed all three B-leg gaps in the recovery turn: inverted the `#if` in
both the single-module main and `ProbeUnifier/C.swift`, ran debug + release
for both single-module and cross-module B-leg targets (all four passes
green: `C.ping() = 42` / `xmod C.ping() = 42`). Restored the literal `#if`
in both files; re-verified the canonical state (literal-`#if` A-leg
single-module + cross-module green). Updated §6.2.1 table to reflect the
complete 8/8 matrix; bumped v1.1.0 → v1.1.1; committed at `acc42e5` with
message "Research: l1-types-only-no-exceptions §6.2.1 matrix completion
(B-leg release + cross-module)".

**Three checks confirmed by supervisor**:

1. Matrix gap correction acknowledged; 8/8 closed cleanly; v1.1.1
   evidence-only bump preserves RECOMMENDATION status. The chain
   `f14cf8f` → `acc42e5` stands.
2. Fallback-framing preservation — original §6.2 paragraph (the question
   with "if not, fallback" framing) preserved verbatim from v1.0.0;
   §6.2.1 (the answer: GREEN, fallback NOT required) anchored by date
   2026-04-26; commit hashes deliberately not embedded in doc body
   (would be self-referential to the introducing commits).
3. Implementation cost confirmation — read §§ 6.1 (Descriptor, the
   `~Copyable` case directly verified by the probe), 6.3 (Process.ID =
   `Tagged<…>`, Copyable storage, not gated by this probe), 6.4
   (Directory.Entry = `[UInt*]`, Copyable storage, not gated).
   Link-time clean cross-module both legs both modes. Optimizer quirks
   none surfaced; the structural reason — typealias resolution is
   type-checker work executed pre-SIL, so release passes don't see the
   typealias structurally — explains symmetry. SPI re-export friction
   explicitly NOT tested (probe used `@_exported public import` only);
   SPI friction is a §7 consumer-impact concern, not a §§ 6.1/6.3/6.4
   implementation-cost concern.

Skill cycle dispatch unblocked on supervisor side; migration execution
stays gated on skill-cycle close. `/tmp/typealias-probe` left in place
per supervisor instruction (throwaway sandbox, no cleanup needed).

**Handoff scan**: 0 files found at relevant working-directory roots
(`/Users/coen`, `/Users/coen/Developer`,
`/Users/coen/Developer/swift-primitives`,
`/Users/coen/Developer/swift-primitives/swift-kernel-primitives`).
Nothing to triage per [REFL-009]. No `/audit` was invoked this session,
so [REFL-010] is a no-op.

## What Worked and What Didn't

**Worked**:

- **Beyond-spec scope**: adding the cross-module variant per [EXP-017] was
  the right call even though the literal task spec was single-module
  only. The probe gates a production adoption; debug-only single-module
  would have been insufficient evidence per skill rule, and the
  supervisor would have asked for it anyway.
- **Structural mirror, not synthetic**: the cross-module shape (A in
  `ProbeA`, B in `ProbeB`, typealias + extension in `ProbeUnifier` with
  `@_exported public import` re-exports, consumer imports unifier only)
  matches the production swift-kernel/Exports.swift pattern. The
  cross-module pass is therefore evidence about the production shape, not
  a degenerate isolated case.
- **Restoration discipline**: after each B-leg verification round (with
  inverted `#if`), restored the literal `#if` and re-verified the
  canonical state before reporting closure. The probe sandbox was never
  left in a non-canonical state, and the doc never described a state the
  files weren't in.
- **[REFL-011] applied correctly**: when supervisor's check (1) arrived,
  re-derived the actual matrix from the executed probe runs (primary
  source) rather than transcribing from my own §6.2.1 table (the artifact
  being implicitly corrected). This caught the two additional B-leg gaps
  the supervisor had not flagged. The post-correction reply was honest
  about both the user's correctly-spotted gap AND the additional gaps
  they hadn't seen.
- **Version bump grain**: v1.1.0 → v1.1.1 (not 1.2.0, not no-bump) signals
  "evidence-only amendment, recommendation unchanged" — semantic-versioning
  alignment with [RES-008] research lifecycle.

**Didn't work initially**:

- The first §6.2.1 table understated the matrix. Row "Cross-module ...
  debug + release" reads as "the cross-module variant was exercised in
  debug + release" — true but misleading when the matrix has another
  orthogonal axis (A-leg vs B-leg) that the row didn't break out. On a
  single host the literal `#if` selects exactly one leg cross-module, so
  the row implicitly conflated "covered" with "covered for the selected
  leg only".
- The reported GREEN verdict at `f14cf8f` was substantively correct (the
  typealias-resolution mechanism works) but the matrix backing it was
  5/8, not 8/8. The supervisor's check (1) caught this; absent the
  check, I would have shipped a verdict on weaker evidence than the
  matrix could have supported with three more passes.

## Patterns and Root Causes

The pattern is **matrix axes vs verdict scope**: when the empirical
matrix has more axes than the result-table breaks out, the table
understates gaps. Specifically — a probe that gates a `#if`-conditional
production mechanism inherently has a `{selected-leg, else-leg}` axis. On
a single host the literal `#if` exercises one leg only; the else leg
requires inverting the `#if` to force on-host. Treating "selected-leg"
and "else-leg" as a first-class matrix axis (alongside
`{single-module, cross-module}` and `{debug, release}`) makes
gap-detection structural rather than retrospective.

**Root cause**: I added the cross-module variant per [EXP-017]'s
release-mode + cross-module gating but didn't extend the leg-axis
discipline (which I had applied for single-module via the inverted-`#if`
B-leg pass) to the cross-module variant. The single-module form had
explicit B-leg coverage; the cross-module form did not. The result-table's
"debug + release" cell for cross-module was a partial truth that the
supervisor's frame ("covers both legs") read past.

**Connection to existing rules**:

- **[EXP-017]** (release-mode + cross-module gating) is the high-level
  discipline. It mandates two axes (mode, module). It does NOT enumerate
  the third axis (`{selected-leg, else-leg}`) for `#if`-gated probes.
  The current rule can be silently followed and still leave the
  leg-axis gap.
- **[REFL-006]**'s re-verify-after-edit rule is the broader principle:
  after any "convert-all-X" task, re-grep the full scope. Adapted to
  `#if`-gated probes: after verifying the selected leg in mode M and
  module form K, also verify the else leg in mode M and module form K.
  The leg-axis is the analogue of "all instances of X".
- **[REFL-011]**'s correction-from-primary-source rule was load-bearing
  in the recovery: re-deriving the matrix from the actual probe runs
  rather than from the §6.2.1 table caught the two additional B-leg
  gaps. Without [REFL-011] discipline, the correction would have
  transcribed the supervisor's "one B-leg gap" framing and left the
  other two.

The deeper insight: **a result table is a claim about the experimental
evidence, not the evidence itself.** Verifying claims against primary
sources (the actual run output) is the [REFL-011] move. Detecting
under-specified claims at the table-design phase — *before* publication —
requires explicit matrix-axis enumeration, which is the skill-update
target below.

A second-order observation: the supervisor's check (1) was framed as
"confirm I'm reading the matrix right" — a question implicitly trusting
my §6.2.1 table over the underlying evidence. Re-deriving from primary
source meant correcting the supervisor's reading too (one gap → three
gaps), not just confirming or denying it. Honesty here is the [REFL-011]
discipline carried to its conclusion: the artifact may understate even
when the supervisor's frame reads it generously.

## Action Items

- [ ] **[skill]** experiment-process: Add a matrix-disambiguation
  requirement to [EXP-017] (or as a sibling rule [EXP-017a]) for
  `#if`-gated probes. When an experiment involves `#if` branches
  selecting different underlying types or behaviors, the empirical
  result-table MUST enumerate `{selected-leg, else-leg}` as a first-class
  axis alongside `{build mode}` and `{module shape}`. A row reading
  "cross-module debug + release" without leg-disambiguation understates
  coverage when the cross-module variant on a single host only exercises
  whichever leg the literal `#if` selects. Procedure: invert the `#if`
  in each module form to force the else branch; re-run the same matrix;
  capture both legs in the result-table as separate rows. Provenance:
  2026-04-26-typealias-probe-matrix-disambiguation.md;
  `swift-kernel-primitives/Research/l1-types-only-no-exceptions.md` v1.1.1
  §6.2.1.
