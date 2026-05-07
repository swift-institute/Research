---
date: 2026-05-07
session_objective: Implement v1 finding #1 of swift-linter-consumer-syntax research — drop redundant Manifest declaration in the swift-tagged-primitives nested-package main.swift, keep only the typed Configuration DSL
packages:
  - swift-primitives/swift-tagged-primitives
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-primitives/swift-linter-primitives
status: processed
processed_date: 2026-05-07
triage_outcomes:
  - type: informational
    target: swift-institute/Research/2026-05-07-swift-linter-consumer-syntax.md
    description: "v1.0.0 → v1.0.1 patch already-captured during work session"
  - type: skill_update
    target: implementation
    description: "[IMPL-104] Leading-Dot Inference at Top-Level Multi-Overload Result-Builder Positions added to style.md"
---

# Lint PoC Manifest Drop and Array.Builder Leading-Dot Inference

## What Happened

This session executed the implementation dispatch for v1 finding #1 of
`swift-institute/Research/2026-05-07-swift-linter-consumer-syntax.md`
(authored earlier in the same conversation): drop the redundant
`Lint.Manifest` declaration in
`swift-tagged-primitives/Lint/Sources/Lint/main.swift`, keep only the
typed `Lint.Configuration` DSL with `Lint.Rule.Configuration.enable(R
.self)` factories.

Net diff to `main.swift`: −103 / +47 = ~56 fewer lines. Each rule is
named once instead of twice; the `if enabled.contains(R.id) {
.enable(R.self) }` gating, the `let enabled = Swift.Set(…)` derivation,
and the `let manifest = Lint.Manifest(…)` declaration are gone.

Verification chain:

- Clean rebuild: 225s after `rm -rf .build` (initial incremental build
  hit a stale-state linker failure with duplicate
  `Binary.Bytes._withBorrowedPrefixContiguous` symbols from
  `Binary_Borrowed_Primitives` — unrelated to the edit; resolved by the
  clean rebuild per `feedback_clean_build_first.md`).
- `swift run swift-linter swift-tagged-primitives`: 239 findings total.
  Per-rule: compound_identifier 175, unchecked_call_site 27 (R5),
  tagged_unchecked_with_typed_alternative 19 (custom), tag_suffix 10,
  chained_rawvalue_access 7, cardinal_count_minus_one 1. Identical to
  the pre-edit baseline asserted by the dispatching brief.
- Commit `4f5d467` landed locally; pushed to origin/main on explicit
  user "YES" per `feedback_no_public_or_tag_without_explicit_yes.md`.

In-flight discovery: the first edit attempt used bare `.enable(R.self)`
at the top-level position of `Lint.Configuration(rules: { … })`,
matching the research doc's §Outcome Q1b template. Build failed with
`error: type '[Lint.Rule.Configuration]' has no member 'enable'`.
Root cause: `Standard_Library_Extensions/Array.Builder` declares four
`buildExpression` overloads — `Element`, `[Element]`,
`<S: Sequence> S where S.Element == Element`, and `Element?` — so the
contextual type for leading-dot inference at the unconstrained
top-level position is ambiguous between `Element` and `[Element]`.
The compiler resolves to `[Element]` (the buildBlock parameter shape)
and looks for `.enable` on the array, not on `Lint.Rule.Configuration`.

Fix: fully-qualified `Lint.Rule.Configuration.enable(R.self)` at every
top-level call. The original `if enabled.contains(R.id) { Lint.Rule
.Configuration.enable(R.self) }` pattern always used fully-qualified
form — the leading-dot would have worked inside the `if` body (where
the contextual type narrows to `Element`), but the outer-scope call
site needs the qualification.

The research doc's §Outcome Q1b nested-package consumer template
(authored at status RECOMMENDATION earlier this session) uses the bare
`.enable(R.self)` form. That template is empirically wrong; it needs a
v1.0.0 → v1.0.1 patch.

HANDOFF scan: 11 files at workspace root `/Users/coen/Developer/`. One
in this session's cleanup authority — `HANDOFF-research-consumer-syntax
.md` (the dispatching brief that became this session's research doc).
Disposition: annotate completion in-place; defer deletion to user
(non-git-tracked workspace root → unrecoverable rm; user YES required
per the unrecoverable-action discipline). The other 10 files
(swift-linter-rules-package-extraction, swiftsyntax-linter-phase-1
through phase-2-stream-c, swift-linter-ai-harness-mission, etc.) are
out-of-authority for this session — closure signals not determinable
from session context; left untouched per [REFL-009] conservative
default.

## What Worked and What Didn't

**Worked**:

- Empirical verification at every gate. Clean build, finding-count
  comparison against the user's stated baseline (239 / 27 / 19), commit
  message body itemising per-rule counts. No verification was deferred
  to the user.
- Diff is mechanically minimal — only `main.swift` changed; no
  collateral edits, no scope creep into the engine or rule packs.
- The push gate respected the per-action authorisation rule. Commit
  landed locally first; only after explicit "YES" did the push fire.
- The leading-dot inference defect surfaced in the *first* build cycle
  rather than after committing.

**Didn't work**:

- The research doc's nested-package consumer template at §Outcome Q1b
  was empirically wrong on a load-bearing detail. The doc was authored
  at RECOMMENDATION status earlier the same session without empirical
  compilation against the PoC. The research's confidence in the typed
  metatype DSL was directionally correct; the surface form had an
  undiscovered defect.
- The first build cycle hit a stale-`.build` linker failure that ate
  ~10 seconds of real time before I recognised the pattern. The
  `feedback_clean_build_first.md` rule applied; the rule itself paid
  for the time it cost.

## Patterns and Root Causes

**Pattern 1 — Research-doc syntax templates are theoretically grounded
but empirically untested until implementation runs them**.

The research doc's consumer template was authored as an idealised
syntax preview. In ordinary compilation, `.enable(R.self)` in a
result-builder body works fine — when the result builder is
*single-overload*. The institute's `Array<Element>.Builder` is
deliberately *multi-overload* (Element, [Element], Sequence, Optional)
because it serves many call-site shapes. The multi-overload design
serves the ecosystem at large; it costs leading-dot inference at the
unconstrained top-level position.

The pattern: research can verify *that the API exists*, *that it
type-checks in the trivial case*, *that the call-site reads cleanly in
prose*. Research cannot verify *that the call-site type-checks under
the specific result-builder's overload set in the actual ecosystem*.
Only implementation does that. Per [RES-021] Stdlib-Protocol
Conformance Verification Spike, the institute already has the practice
of "verify by minimal external test before promoting to DECISION." The
research doc was at RECOMMENDATION precisely to signal this gap, but
the gap should be patched once implementation surfaces an empirical
defect.

This is the inverse of [RES-013a] (synthesis of prior findings without
verification): instead of *carrying forward stale findings*, this is
*publishing a new finding without verification*. Same shape of fix —
the syntax template *must* be verified against an actual compile
before being shipped as RECOMMENDATION, or marked as
"syntax-uncompiled, pending implementation feedback."

**Pattern 2 — Pre-existing redundancy can hide load-bearing facts**.

The original `if enabled.contains(R.id) { Lint.Rule.Configuration
.enable(R.self) }` pattern always used fully-qualified factories.
That choice was probably accidental — the author wrote fully-qualified;
leading-dot would have worked equally inside the `if` body. When I
removed the redundancy, I removed the `if` blocks AND simultaneously
attempted to convert to leading-dot. The build failure surfaced the
inference ambiguity, but for one round the failure was attributable to
the wrong axis (was it the manifest drop? was it the typed DSL? was
it the leading-dot?).

Generalisable: when removing redundant code, *some* of the redundancy
may be load-bearing protection against a non-obvious failure mode. The
minimal-diff principle (change one axis at a time) applies — I should
have first removed the gating-with-fully-qualified pattern (producing
a flat list of fully-qualified `.enable` calls), built and verified,
*then* explored leading-dot as a follow-up cosmetic change.

**Pattern 3 — Research-doc patch is a v1.0.0 → v1.0.1 PATCH bump, not
a status downgrade**.

The empirical finding doesn't invalidate the research's recommendation
— it refines the surface form. The recommendation (typed metatype DSL,
drop redundant Manifest in nested-package) stands; only the consumer
template at §Outcome Q1b needs surface-form correction. Per [RES-008]
Research Document Lifecycle, this is a Patch (cosmetic), not Minor (new
analysis), not Major (status change). The status stays RECOMMENDATION;
the changelog records the empirical correction and the verification
context.

## Action Items

- [ ] **[research]** swift-institute/Research/2026-05-07-swift-linter-consumer-syntax.md: v1.0.0 → v1.0.1 patch the nested-package consumer templates at §Outcome Q1b "Q1b — Nested-package `Lint/Sources/Lint/main.swift`" and §Outcome "Nested-package consumer template (locked-in v1 shape)" — replace bare `.enable(R.self)` with fully-qualified `Lint.Rule.Configuration.enable(R.self)`. Add an empirical-finding footnote citing the four-overload `Array<Element>.Builder` ambiguity, verified 2026-05-07 against `swift-tagged-primitives/Lint/Sources/Lint/main.swift` (commit `4f5d467`). Capture the inside-`if`/`for`-body exception (leading-dot works there because the contextual type narrows to `Element`).

- [ ] **[skill]** implementation: Add a new rule under `style.md` (or `accessors.md` if Property.View pattern is the better neighbourhood) documenting that leading-dot inference at top-level positions of multi-overload `buildExpression` result-builders — specifically `Array<Element>.Builder` from Standard_Library_Extensions with four overloads (Element / [Element] / Sequence / Element?) — fails because the contextual type is ambiguous between `Element` and `[Element]`. Rule prescribes fully-qualified static factories at top-level; documents that leading-dot works inside `if`/`for` bodies where the contextual type narrows to `Element`. Companion to [IMPL-094] (Swift 6.3 chain-property `&&` rejection on `borrowing Self`) — both are Swift compiler ergonomics codified as institute rules.
