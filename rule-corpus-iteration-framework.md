# Rule-Corpus Iteration Framework

<!--
---
version: 1.1.0
last_updated: 2026-05-11
status: RECOMMENDATION
research_tier: 2
applies_to: [Skills, Linter-rules]
scope: ecosystem-wide
criteria_version: 1.1
last_audit_pass: null
successor_audit_dispatch: null
---
-->

> **v1.1.0 changelog (same-session extension)**: scope expanded from
> *Skills* to *Skills + Linter-rules*. The lint-pass triage on the 72
> rules in `swift-foundations/swift-linter-rules` (running concurrently
> in another session, now unified here) applies the same E/V/C/G
> criteria. Disposition vocabulary gains **TIGHTEN** and **LOOSEN**
> (predicate-adjustment dispositions specific to mechanical-enforcement
> rules — narrow to reduce false positives, broaden to reduce false
> negatives). Lint-pass aggregate at
> `swift-foundations/swift-linter-rules/Research/lint-pass-2026-05-11-aggregate.md`
> is the input for Wave 1 of linter-rule application.

## Context

**Skill-rule corpus** across three skills (`code-surface`, `platform`,
`implementation`) — **205 rules** (verified 2026-05-11 against the
shipped `SKILL.md` files):

| Skill | Rules | Layer | File structure |
|---|---:|---|---|
| `code-surface` | 38 ([API-NAME-*], [API-ERR-*], [API-IMPL-*]) | implementation | single-file (1272 lines) |
| `platform` | 59 ([PLAT-ARCH-*], [PATTERN-001..009]) | architecture | single-file (2325 lines) |
| `implementation` | 108 ([IMPL-*], [IMPL-EXPR-*], [API-LAYER-*], [PATTERN-012..058], [SEM-DEP-*], [COPY-FIX-*], [COPY-REM-*]) | implementation | multi-file hub + 7 siblings |
| **Total** | **205** | | |

**Linter-rule corpus** (v1.1.0, added 2026-05-11) in
`swift-foundations/swift-linter-rules` — **72 rules across 13 packs**
(verified via the lint-pass-2026-05-11-aggregate against 11 public
primitives):

| Pack | Rules | Fired (real-corpus pass) | Silent |
|---|---:|---:|---:|
| Naming | 12 | 7 | 5 |
| Structure | 9 | 4 | 5 |
| Memory | 10 | 6 | 4 |
| Throws | 11 | 3 | 8 |
| Idiom | 5 | 1 | 4 |
| Closure | 4 | 0 | 4 |
| Cardinal | 2 | 0 | 2 |
| RawValue | 3 | 0 | 3 |
| ResultBuilder | 1 | 0 | 1 |
| Testing | 5 | 0 | 5 |
| Try | 1 | 0 | 1 |
| Unchecked | 2 | 1 | 1 |
| Platform | 9 | 1 | 8 |
| **Total** | **72** | **23** | **49** |

Real-corpus pass: 896 findings across 11 public primitives. Top 3
rules carry 80% of volume (compound_identifier 363 / minimal_type_body
252 / extension_noncopyable_constraint 108). swift-standard-library-extensions
alone produces 620 (69%) — empirical analysis shows a substantial
fraction are false positives on `@resultBuilder` protocol methods
(`buildExpression` etc.) that the spec-mirroring exception should
exempt. The linter-rule triage runs as Wave 1 of framework application
to this corpus per the per-pack alpha-pace below.

The 2026-05-11 mechanization-arc closeout reached ~40% machine-enforced
rules and surfaced 14 platform rules as structurally non-mechanizable.
The closing-pass review of that residual set identified 7 candidates
that read as **vestigial** rather than legitimately non-mechanizable
behavioral rules. The principal's lens — *"we don't specify layers —
except by organization"* — generalized the observation: the corpus
contains content the github org / Package.swift graph / linter
implementations already encode, plus content that read as load-bearing
in its origin session but doesn't survive a fresh-audience read.

The principal authorized a deliberation-first dispatch to design a
**framework** for distinguishing evergreen rules from vestigial-form
rules from consolidation-eligible pairs from gap-adjacent missing rules,
then validating the framework against the 7 seed candidates before any
corpus-wide sweep. This document is that framework at v1.0.0.

The framework's primary discipline: **"vestigial smell" does not imply
"delete the rule." It means "separate the reusable normative kernel
from registry, incident, permissive, or provenance material."** Most
flagged rules contain a surviving kernel; the framework rescues the
kernel via TRIM / SPLIT / REFRAME / ABSORB / REWRITE before reaching
for RETIRE.

### Deliberation provenance

This framework converged through a 3-round /collaborative-discussion
between Claude (Anthropic) and ChatGPT (OpenAI), relayed by the
principal. Full transcript at `/tmp/rule-corpus-iteration-transcript.md`;
converged plan at `/tmp/rule-corpus-iteration-converged.md`. Per
[COLLAB-004]: both parties marked CONVERGED at Round 3; Concerns and
Questions sections empty; position summaries aligned.

### Prior art (cite, don't duplicate)

- `Research/skill-shape-and-growth-evaluation.md` v1.1.0 (2026-04-24,
  DECISION) — multi-file navigation-hub exception for skills with ≥ 40
  rules + ≥ 3 clusters.
- `Research/skill-verification-taxonomy-{pilot,extension-tier-1,extension-tier-2,extension-tier-3}.md`
  — mechanical / hybrid / semantic verification classification and the
  `**Composite:**` annotation pattern for multi-mechanism rules.
- `Research/skills-condensation-triage-phase-1.md` (2026-05-05,
  RECOMMENDATION) — reflections-driven triage with destinations.
- `Research/mechanical-rule-tool-classification-swift-primitives.md` —
  tool-bucket mapping of rules to AST / WF / SwiftLint enforcement.
- **Skill-lifecycle policies**: [SKILL-LIFE-001] (minimal revision —
  Statements normative; bodies editable), [SKILL-LIFE-003] (amendment
  classes CLARIFYING / ADDITIVE / BREAKING), [SKILL-LIFE-006]
  (retirement procedure), [SKILL-LIFE-026] (one reference-package
  rewrite per BREAKING revision), [SKILL-CREATE-005] (catalogue-shaped
  table-row variant).

This framework EXTENDS — does not replace — those references.

---

## 1. Evergreen rule criteria

A rule **earns shelf space** in the canonical corpus when it passes
**ALL six** criteria.

| # | Criterion | Test |
|---|-----------|------|
| **E1** | Generative | The rule governs a class of *future* decisions, not a single historical case. Asked "does my situation match this rule?", a future reader can answer mechanically. |
| **E2** | Operational | The author knows *when* the rule fires during writing, reviewing, naming, layering, implementing, or auditing. |
| **E3** | Decidable | The rule gives a predicate, decision procedure, or objective review question. A rule can be Operational (fires at a recognizable moment) yet fail Decidable ("consider whether X is appropriate" with no test). |
| **E4** | Non-derivative | The rule is NOT merely restating github org membership, `Package.swift` dependencies, compiler diagnostics, generated registry data, or another rule. |
| **E5** | Bounded | The rule belongs to a recognizable domain and does not sprawl across unrelated concerns. |
| **E6** | Durable | The rule is not pinned to a one-time migration, one release cohort, or one fixed incident. |

**Decision rule**: pass ALL six → Evergreen. Failure on any single
criterion routes the rule to the V1–V6 test (Section 2).

**E2 vs E3 distinction**: E2 is *when* — the moment of choice the
author recognizes (writing a new type, classifying a placement,
reviewing a PR). E3 is *what* — the predicate / procedure / objective
test the rule offers at that moment. A rule with E2 but not E3 is
operationally addressable but undecidable; it produces bikeshed, not
verdicts.

---

## 2. Vestigiality criteria

A rule **loses its shelf space** when ANY failure mode below triggers.
**If a reusable normative kernel survives the failure mode, the first
remedy is REFRAME / SPLIT / ABSORB / REWRITE — not immediate RETIRE.**

| # | Failure mode | Symptom |
|---|--------------|---------|
| **V1** | Snapshot registry | Lists current packages, paths, repositories, owners, or versions that another source canonicalizes. Drifts with renames. |
| **V2** | Single-instance exception | Names a specific carve-out for one type/method/field with no general predicate that would generate a second instance. |
| **V3** | Post-mortem (split) | The rule's body cites incidents / commits / "the origin incident" language. Two sub-cases: |
| V3a | (...) predicate survives | Incident-heavy framing but the procedural kernel still applies. → REFRAME. |
| V3b | (...) no predicate survives | Incident-only; no future-facing decision procedure. → RETIRE or MOVE-TO-RESEARCH. |
| **V4** | Permission without criterion (split) | MAY / SHOULD consider X with no trigger, standard, or consequence. Two sub-cases: |
| V4-latent | (...) latent guidance exists | The ecosystem provides the answer to "when does this rule fire?" but the rule body doesn't state it. → REWRITE-AS-GUIDANCE. |
| V4-empty | (...) genuinely empty | No latent guidance exists. → RETIRE or MOVE-TO-RESEARCH. |
| **V5** | Self-superseded | The rule's own text acknowledges its triggering architecture or premise has been replaced. May retain a residual procedure (KEEP-WITH-TRIM) or be entirely obsolete (RETIRE). |
| **V6** | Duplicative derivative | Restates a fact already entailed by another rule, `Package.swift`, org placement, compiler behavior, or validator output. |

### V1 sub-cases

Registry-shaped content is not automatically vestigial. [SKILL-CREATE-005]
sanctions catalogue-shaped table-row rules when the table IS a decision
instrument. Four sub-cases:

| Sub-case | Pattern | Verdict |
|---|---|---|
| **V1a** | Snapshot of current packages / paths / versions; substrate canonicalizes elsewhere (`gh repo list`, `swift package dump-package`) | Vestigial → MOVE-TO-RESEARCH or generated index |
| **V1b** | Defines a finite canonical vocabulary used by downstream rules | KEEP (not vestigial) |
| **V1c** | Encodes a decision matrix with future applicability | KEEP, possibly REFRAME |
| **V1d** | Mirrors github org structure or `Package.swift` dependencies | RETIRE from normative rule body |

### Axiom exemption

Rules of the [IMPL-INTENT] / [IMPL-000] / [IMPL-001] / [IMPL-COMPILE]
shape (governing-principle scope-statements at the head of a skill)
are flagged `axiom` and **exempt from V1–V6**. Axioms pass E1–E6 by
construction — they ARE the governing principles other rules derive
from.

---

## 3. Consolidation criteria

Two rules **merge** when ALL five criteria hold.

| # | Criterion |
|---|-----------|
| **C1** | Same workflow moment |
| **C2** | Same author/reviewer question |
| **C3** | Same or nested predicate |
| **C4** | No distinct invariant is lost |
| **C5** | Inbound references can be redirected safely |

**Application**: when C1–C5 hold, disposition is **ABSORB** (one rule
survives; the other's ID becomes a redirect-anchor). When C1 fails
(adjacent operational moments but not the same), disposition is
**KEEP-WITH-CROSS-REFERENCE** (both rules survive; bodies add explicit
cross-reference).

---

## 4. Gap criteria

A rule is **missing** when ANY of five symptoms hold.

| # | Symptom |
|---|---------|
| **G1** | Enforced but unstated — a linter rule / validator implements a discipline the skill body does not name |
| **G2** | Practiced but unstated — convention exists in practice but never lands as a rule |
| **G3** | Repeatedly rediscovered in reviews |
| **G4** | Mentioned in tooling / scripts / provenance but absent from skill text |
| **G5** | Required for audit closure but not visible to future auditors |

---

## 5. Audit methodology

### 5.1 Verdict-decision flowchart

For each rule:

```
1. Apply E1–E6 (Section 1). Pass ALL six → Evergreen.
   Fail any → step 2.
2. Apply V1–V6 (Section 2). Failure mode identifies verdict.
3. For rules flagged V1, V2, or V6 → apply DERIVABILITY CHECK (5.2).
4. Apply C1–C5 (Section 3) against sibling rules. Match → ABSORB.
   Adjacent-but-not-same operational moment → CROSS-REFERENCE.
5. Apply G1–G5 (Section 4) to the surrounding corpus.
   Match → record as ADDITION-NEEDED (not on this rule; on an adjacent gap).
```

### 5.2 Derivability check (binding for V1/V2/V6)

For any rule flagged under V1, V2, or V6, the auditor MUST answer:

> *"What would be lost if this rule ID disappeared and its surviving
> predicate were absorbed into the nearest parent rule?"*

| Answer | Disposition |
|---|---|
| Only the historical incident, table, or example | ABSORB / REFRAME / MOVE-TO-RESEARCH (NOT KEEP) |
| A distinct normative predicate independent of any parent rule | KEEP (the V-flag was a smell, not a defect) |
| Predicates partially overlap with a parent rule | ABSORB the unique predicates as sub-clauses; redirect-anchor at the absorbed ID |

The derivability check is the protection against framework bias:
without it, the kernel-remains principle becomes a rescue device that
preserves every rule ID once any useful idea can be found in the body.

### 5.3 Verdict / Disposition orthogonal columns

Verdict and Disposition are independent dimensions:

- **Verdict** classifies the rule against the framework (which of E /
  V / C / G applies).
- **Disposition** is the action verb (what happens to the rule).

| Verdict | Possible dispositions |
|---|---|
| Evergreen | KEEP, KEEP-WITH-TRIM, KEEP-WITH-CROSS-REFERENCE |
| Evergreen (mechanical rule, FP rate ≥ 20% on real corpus) | **TIGHTEN** (narrow predicate; preserve rule ID and Statement intent) |
| Evergreen (mechanical rule, FN rate ≥ 20% on stated skill predicate) | **LOOSEN** (broaden predicate; preserve rule ID and Statement intent) |
| Vestigial-V1a/d | MOVE-TO-RESEARCH, RETIRE-WITH-REDIRECT |
| Vestigial-V1b/c | KEEP (per registry sub-case) |
| Vestigial-V2 | ABSORB (consolidate predicate into criteria-bearing rule), RETIRE-WITH-REDIRECT |
| Vestigial-V3a | REFRAME |
| Vestigial-V3b | RETIRE, MOVE-TO-RESEARCH |
| Vestigial-V4-latent | REWRITE-AS-GUIDANCE |
| Vestigial-V4-empty | RETIRE, MOVE-TO-RESEARCH |
| Vestigial-V5 (residual) | KEEP-WITH-TRIM, REFRAME |
| Vestigial-V5 (no residual) | RETIRE |
| Vestigial-V6 | ABSORB, RETIRE-WITH-REDIRECT |
| Consolidation-eligible (C1–C5) | ABSORB |
| Consolidation-adjacent (C1 fails) | KEEP-WITH-CROSS-REFERENCE |
| Gap | ADD-NEW-RULE (handled in Phase 4; not on existing rule) |

**TIGHTEN / LOOSEN scope** (linter-rule-specific, v1.1.0): these
dispositions apply to mechanical-enforcement rules (SwiftSyntax AST
modules, SwiftLint custom rules, reusable validator workflows) where
predicate width is empirically measurable via false-positive / false-negative
rates against a real-corpus pass. They do NOT apply to skill rules,
where the Statement is normative prose and predicate adjustment is
REWRITE-AS-GUIDANCE.

| Disposition | Skill rules | Linter rules |
|---|---|---|
| KEEP / KEEP-WITH-TRIM / KEEP-WITH-CROSS-REFERENCE | Yes | Yes |
| REFRAME / SPLIT / ABSORB / MOVE-TO-RESEARCH | Yes | Yes (rule body, not predicate) |
| REWRITE-AS-GUIDANCE | Yes (V4-latent) | N/A (use TIGHTEN/LOOSEN for predicate; KEEP-WITH-TRIM for body) |
| **TIGHTEN** | N/A | Yes (V-classification + FP rate ≥ 20%) |
| **LOOSEN** | N/A | Yes (V-classification + FN rate ≥ 20% against stated skill predicate) |
| RETIRE-WITH-REDIRECT / RETIRE-NO-REDIRECT | Yes | Yes |
| ADD-NEW-RULE | Yes (Phase 4 / A1–A4) | Yes (Phase 4 / gap-additions from triage) |

### 5.4 Audit table schema

The audit produces one row per action (not per rule). SPLIT/mixed-content
verdicts produce multiple rows for the same source rule.

| Column | Meaning |
|---|---|
| Rule ID | Source rule identifier |
| Scope | "whole rule" OR "section: <heading>" (for SPLIT cases) |
| Skill | code-surface / platform / implementation |
| Verdict | Evergreen / Vestigial-Vx / Consolidation-eligible / Gap |
| Trigger | E/V/C/G criterion code |
| Normative kernel | One-sentence statement of what survives |
| Disposition | KEEP / TRIM / REFRAME / SPLIT / ABSORB / CROSS-REFERENCE / REWRITE / MOVE / RETIRE / ADD |
| Amendment type | CLARIFYING / ADDITIVE / BREAKING per [SKILL-LIFE-003] |
| Target | Successor rule, absorbed-into rule, Research doc, or new-rule placeholder |
| Citation action | None / rewrite inbound refs / redirect anchor / provenance-only |
| Confidence | HIGH / MEDIUM / LOW |

**LOW-confidence verdicts do not authorize Phase 1/2 action.** They
are starting hypotheses for the next cluster review under A4.

### 5.5 RETIRE-NO-REDIRECT — narrow case

Most retirements take redirect-anchor or successor-citation form.
RETIRE-NO-REDIRECT is permitted only when ALL of:

1. No inbound citations exist anywhere in the workspace.
2. No successor rule exists.
3. No reusable normative kernel remains.
4. Historical material is not worth preserving in Research.
5. The retirement audit records the deletion rationale.

---

## 6. Worked examples

Five worked examples, one per major disposition family.

### 6.1 KEEP — [PLAT-ARCH-008b] Conditional Public API Surface in L3

**Surface symptom**: 1-row Accepted Instances table (only
`Kernel.Failure.signal`). Strong vestigial smell — looks like V2
(single-instance exception).

**E1–E6 walk**:

| Criterion | Verdict | Reasoning |
|---|---|---|
| E1 Generative | Pass | The 4-condition predicate describes a generative class — any future enum-case L3 conditional surface meeting the conditions qualifies. |
| E2 Operational | Pass | Fires when a new public enum in swift-kernel needs `#if os()` on a case. |
| E3 Decidable | Pass | The 4 conditions ARE the decision procedure. Each is testable. |
| E4 Non-derivative | **Test required** (V6 smell — check derivability) | See 5.2 below. |
| E5 Bounded | Pass | Bounded to L3-unified enum-case surface. |
| E6 Durable | Pass | `Revisit if:` clause names a future trigger (Swift `@nonExhaustive` semantics) — that's an explicit Durability statement, not a pin to current state. |

**Derivability check (V6, per 5.2)**:

| Sibling rule | Scope | Could 008b's predicate absorb here? |
|---|---|---|
| [PLAT-ARCH-008a] Domain Authority Exception | Non-platform-stack packages explicitly — swift-kernel is excluded | No (different scope) |
| [PLAT-ARCH-008c] L1 Primitives Are Platform-Agnostic | L1 layer only | No (different layer) |
| [PLAT-ARCH-005a] No Platform C Types in Public API | C-type leakage in public API; not enum-case `#if os()` | No (different concern) |

Conclusion: 008b's 4 conditions are NOT derivable from any sibling.
E4 passes.

**Verdict**: Evergreen.
**Disposition**: KEEP-WITH-TRIM (trim 1-row table to a single
illustrative example; preserve the 4 conditions and the `Revisit if:`
clause; move the `Kernel.Failure.signal` example to Provenance if it
adds incident-narrative weight).
**Confidence**: MEDIUM (the rule earns its standalone ID at the
current 1 instance; the next cluster review per A4 re-tests at the
platform corpus once additional instances surface).

**Lesson**: vestigial smell is necessary but not sufficient for
retirement. The derivability check is what converts smell to verdict.

### 6.2 SPLIT — [PLAT-ARCH-010] Platform Package Reference

**Surface symptom**: 3 large registry tables (L1 / L2 / L3 packages
with paths and spec authorities) plus a "namespace anchor packages
(L2 pattern, reserved)" sub-clause.

**E1–E6 walk**: mixed-content rule. The registry tables fail E4
(github org + Package.swift canonicalize); the architectural assertion
("these packages constitute the platform stack") passes E4 (no
substrate says "these are the platform stack and not these others");
the namespace-anchor sub-clause passes E1–E6 as its own generative
rule.

**V-criteria**: V1 fires for the registry sections (snapshot of
current packages, V1a/V1d). Assertion and namespace-anchor sections
do not trigger V-criteria.

**Section-level audit rows**:

| Scope | Verdict | Disposition | Target |
|---|---|---|---|
| Registry tables (L1/L2/L3) | Vestigial-V1a | MOVE-TO-RESEARCH | `Research/platform-package-reference.md` |
| "What constitutes the stack" assertion | Evergreen | KEEP-IN-BODY | self (stays at `[PLAT-ARCH-010]`) |
| Namespace-anchor sub-clause | Evergreen | ADD-NEW-RULE | new `[PLAT-ARCH-010a]` |

**Amendment**: CLARIFYING (registry move) + ADDITIVE (010a).
**Citation action**: cites to [PLAT-ARCH-010] stay (Statement preserved
for the assertion); [PLAT-ARCH-008k]'s body cross-reference to "namespace
anchor" updates to [PLAT-ARCH-010a] concurrently with 010a's creation.
**Confidence**: HIGH.

**Lesson**: a single rule can carry payloads of different framework
classes. Section-level rows preserve the kernel(s) while retiring the
snapshot substrate.

### 6.3 ABSORB — [PLAT-ARCH-014] ISA Standard Packages

**Surface symptom**: 3-row registry of `swift-x86-standard` /
`swift-arm-standard` / `swift-riscv-standard` mapped to their spec
authorities, plus a single declarative sentence asserting these are
L2 (not L1).

**V-criteria**: V1 fires for the registry portion (snapshot of current
ISA packages — github org canonicalizes). V6 fires for the layer
assertion: "ISA standards are L2" is a 1-sentence application of
[PLAT-ARCH-012] (Vocabulary / Spec / Composition Principle) to the CPU
domain.

**Derivability check (V6)**: the layer assertion IS derivable from
[PLAT-ARCH-012] — the principle says "encode external specs at L2,"
the CPU domain has external specs (Intel SDM, ARM ARM, RISC-V ISA
Spec), so ISA packages are L2 by [PLAT-ARCH-012]. The 1-sentence
assertion adds no independent normative content.

**Section-level audit rows**:

| Scope | Verdict | Disposition | Target |
|---|---|---|---|
| Registry table | Vestigial-V1a | MOVE-TO-RESEARCH | `Research/platform-package-reference.md` (same destination as 010's registry) |
| Layer assertion | Vestigial-V6 | ABSORB | [PLAT-ARCH-012] as a CPU-domain worked example |

**Amendment**: CLARIFYING (absorb).
**Citation action**: redirect-anchor at [PLAT-ARCH-014] pointing at
[PLAT-ARCH-012].
**Confidence**: MEDIUM-HIGH.

**Net rule-count effect**: −1 (014 ID becomes redirect-anchor; content
flows into 012).

**Lesson**: V6 is the cleanest retirement signal — a rule that says
nothing its parent doesn't say. Absorb into the parent, redirect the ID.

### 6.4 REFRAME — [PLAT-ARCH-020] L3-Unifier Shadow Pre-Flight Check

**Surface symptom**: extended "Worked example (the origin incident)"
section citing commit `26e8788` and the IO.Read / IO.Write
`@_disfavoredOverload` regression. Self-acknowledged "post-supersession
framing" note: the original framing assumed raw companions that were
later retired.

**E1–E6 walk**: E1 passes (the precondition check applies to any
typed-only L2 surface that swift-kernel might shadow). E2 passes
(fires when modifying typed forms at L2 paths). E3 passes (the
precondition table is the decision procedure). E4 passes. E5 passes.
E6 passes (no Swift-version pinning).

**V-criteria**: V3a fires (incident-heavy framing; predicate survives).
The "Worked example (the origin incident)" section is narrative; the
3-precondition check table is the rule's enduring value.

**Verdict**: Vestigial-V3a (kernel survives).
**Disposition**: REFRAME — move incident narrative to Provenance;
promote the precondition table + grep command + 3 concrete precondition
checks to the rule body.
**Amendment**: CLARIFYING.
**Citation action**: none (rule ID stays; only body reshapes).
**Confidence**: HIGH.

**Lesson**: V3 is about *form*, not *existence*. A rule's procedural
kernel can be load-bearing even when the incident narrative around it
is no longer relevant. REFRAME lifts the kernel; Provenance holds the
incident.

### 6.5 REWRITE-AS-GUIDANCE — [PATTERN-007] Experimental Feature Flags

**Surface symptom**: 5-line "MAY enable experimental features for
compile-time resource verification" with a code snippet. No predicate,
no decision criterion.

**E1–E6 walk**: E3 fails (no decision procedure). The rule offers
permission without prescription.

**V-criteria**: V4 fires. Sub-case test:

- Empirical: 235 packages across swift-primitives + swift-foundations +
  swift-standards have `enableExperimentalFeature(...)` calls in their
  Package.swift. Features in use: `Lifetimes`, `LifetimeDependence`,
  `BuiltinModule`, `RawLayout`, `SuppressedAssociatedTypes`.
- Each feature has a stable usage class:

| Feature | Stable usage class |
|---|---|
| Lifetimes / LifetimeDependence | Packages with `~Escapable` types or borrow-tracking refinement (ownership / typed-pointer primitives) |
| BuiltinModule | Packages calling Builtin intrinsics (low-level atomics, memory ops) |
| RawLayout | Packages with `@_rawLayout` storage types |
| SuppressedAssociatedTypes | `~Copyable`-aware protocol packages |

→ V4-latent (latent guidance exists).

**Verdict**: Vestigial-V4-latent.
**Disposition**: REWRITE-AS-GUIDANCE. Expand body to name (a) which
packages enable which features, (b) what guarantees each feature
provides, (c) what stability costs each carries across Swift toolchain
versions, (d) isolation / documentation requirements per [PATTERN-016].
**Amendment**: CLARIFYING (Statement may strengthen from MAY to SHOULD
for the named classes; tier-with-[PATTERN-006] preserved).
**Citation action**: none (rule ID stays).
**Confidence**: MEDIUM (depends on whether the per-feature predicates
correctly characterize all 235 packages — the rewrite handoff verifies
against current usage at write time).

**Lesson**: widespread use of a permissive rule does not automatically
validate the rule. The rewrite must produce stable per-feature
predicates. If the predicates can be written, REWRITE-AS-GUIDANCE
preserves the ID and adds the missing guidance. If they cannot, the
rule is V4-empty (RETIRE or MOVE-TO-RESEARCH).

---

## 7. Seed-rule verdict table (8 rules)

The original 7-seed list + `[PLAT-ARCH-025]` (surfaced via 024's
cross-reference revision):

| Rule ID | Scope | Verdict | Trigger | Normative kernel | Disposition | Amendment | Target | Citation action | Conf |
|---|---|---|---|---|---|---|---|---|---|
| `[PLAT-ARCH-008b]` | whole | Evergreen | E1–E6 pass; derivability check confirms E4 | "L3 unified packages MAY use `#if os()` on public enum cases when irreducible-platform-dep + no-consumer-impact + L3-internal-only + sole-instance-per-type all hold" | KEEP-WITH-TRIM | CLARIFYING | self | none | MEDIUM |
| `[PLAT-ARCH-010]` | registry tables | Vestigial-V1a | V1 | (snapshot of current packages) | MOVE-TO-RESEARCH | CLARIFYING | `Research/platform-package-reference.md` | none for surviving rule | HIGH |
| `[PLAT-ARCH-010]` | stack-assertion | Evergreen | E1–E6 pass | "These packages constitute the platform stack" | KEEP-IN-BODY | CLARIFYING | self | none | HIGH |
| `[PLAT-ARCH-010]` | namespace-anchor sub-clause | Evergreen | E1–E6 pass | "Namespace-anchor packages exist when a host platform needs multiple sibling L2 spec packages" | ADD-NEW-RULE | ADDITIVE | new `[PLAT-ARCH-010a]` | [PLAT-ARCH-008k]'s body cross-reference updates to 010a | HIGH |
| `[PLAT-ARCH-014]` | registry table | Vestigial-V1a | V1 | (snapshot of current ISA packages) | MOVE-TO-RESEARCH | CLARIFYING | `Research/platform-package-reference.md` | none | MEDIUM-HIGH |
| `[PLAT-ARCH-014]` | layer assertion | Vestigial-V6 | V6 (derivable from [PLAT-ARCH-012]) | "ISA standard packages are L2 — CPU-domain application of Vocabulary/Spec/Composition" | ABSORB into [PLAT-ARCH-012] | CLARIFYING | [PLAT-ARCH-012] | redirect-anchor at [PLAT-ARCH-014] | MEDIUM-HIGH |
| `[PLAT-ARCH-020]` | whole | Vestigial-V3a | V3a (incident-heavy, predicate survives) | "Before adding/modifying typed forms at L2 paths, grep L3-unifier sources for parallel extensions; if found, use `@_disfavoredOverload` on the L2 typed form" | REFRAME | CLARIFYING | self | none | HIGH |
| `[PLAT-ARCH-024]` | whole | Evergreen | E1–E6 pass | "Before classifying a cross-platform vocabulary type as L3-placed, grep L2 spec packages for `extension <Namespace>.<Type>` patterns" | KEEP-WITH-CROSS-REFERENCE to 025 | CLARIFYING | self | none | HIGH |
| `[PLAT-ARCH-025]` | whole | Evergreen | E1–E6 pass | "Class A vs Class B classification MUST be by declaration site, not usage site" | KEEP-WITH-CROSS-REFERENCE to 024 | CLARIFYING | self | none | HIGH |
| `[PLAT-ARCH-028]` | whole | Vestigial-V3a | V3a (incident-heavy, predicate survives) | "When platform L3 namespace is typealiased to Kernel_Primitives.Kernel, swift-kernel MUST NOT add unifier delegate at same name — the typealias collapses the slot" | REFRAME | CLARIFYING | self | none | HIGH |
| `[PATTERN-007]` | whole | Vestigial-V4-latent | V4-latent (235 packages use experimental features; per-feature usage classes derivable) | Per-feature predicates: Lifetimes/LifetimeDependence for ownership packages; BuiltinModule for intrinsics; RawLayout for storage-layout types; SuppressedAssociatedTypes for ~Copyable protocols | REWRITE-AS-GUIDANCE | CLARIFYING | self | none | MEDIUM |

**Net rule-count effect across the 8 seeds**:
- 014 absorbs into 012 → −1 ID
- 010a is added → +1 ID
- All other seeds keep their IDs (TRIM / SPLIT-with-id-preserved /
  REFRAME / KEEP-CROSS-REF / REWRITE)

Net change: ≈ 0 rule IDs across the seed set. **3 of 8 rules
materially restructure** (010 SPLIT / 014 ABSORB / 007 REWRITE);
**2 reframe** (020, 028); **3 keep with adjustments** (008b TRIM,
024+025 CROSS-REF).

The original seed framing's "7 vestigials" was right about **form
smell** in 5 of 7 (008b 1-row table; 010 registry; 014 mini-registry;
020 / 028 narrative form; PATTERN-007 permission). Only 1 of the 7
cleanly absorbs ([PLAT-ARCH-014]). The remainder have surviving
normative kernels rescued via TRIM / SPLIT / REFRAME / REWRITE —
exactly the kernel-remains principle in action.

**Sample-bias note**: the 7-seed list came from a closing-pass review
of platform/'s residual non-mechanizable set — already filtered for
borderline cases that survived 4 waves of mechanization. The framework
applies to the remaining ~198 rules through A4 (cluster reviews per
[SKILL-LIFE-031]), not via a standalone corpus-wide sweep — those
rules have already been examined through the mechanization waves,
verification-taxonomy pilot, doc-gap pass, and prior cluster audits.
The framework's job is to apply the criteria honestly when a cluster
review fires, not to hit a retirement rate.

---

## 8. Proposed additions (4 gap-additions)

### A1. Org-as-Layer Convention (reframed)

**Triggering criterion**: G1 + G3.

**Proposed Statement**: Layer assignment is determined by repository
placement in the relevant Swift Institute GitHub organization. The
mapping:

- **L1 layer**: `swift-primitives` org → L1 primitives.
- **L3 layer**: `swift-foundations` / `swift-linux` / `swift-darwin` /
  `swift-windows` orgs → L3 foundations.
- **L2 spec authority**: the org name names the *spec authority*, not
  the layer directly. `swift-iso` → IEEE 1003.1 specs; `swift-microsoft`
  → Windows API specs; `swift-arm-ltd` / `swift-intel` / `swift-riscv`
  → ISA specs; `swift-linux-foundation` → Linux-kernel specs. L2
  placement follows [PLAT-ARCH-012] (Vocabulary / Spec / Composition)
  — these orgs encode external specs, so their packages are L2 by
  virtue of that role.

**Anti-duplication clause**: Rule text MUST NOT duplicate package-level
layer registries unless the package is an exception or transition case.
The org-to-layer enumeration lives in Research / generated docs / a
dashboard, not in skill rule bodies.

**Belongs in**: `platform/` (new `[PLAT-ARCH-NNN]`).
**Amendment class**: ADDITIVE.

**Why reframed (not enumerated)**: the original Round-1 A1 included a
literal org-to-layer list inside the rule body. That risks recreating
[PLAT-ARCH-010] as a new registry rule (V1d — mirrors github org
structure). The evergreen payload is the CONVENTION + the
ANTI-DUPLICATION principle; the list is substrate that belongs
elsewhere.

### A2. `[VERIFICATION:]` Tag Convention

**Triggering criterion**: G1 + G3 + G4.

**Proposed Statement**: Substantive rule bodies SHOULD carry one or
more inline `[VERIFICATION:]` tags identifying the mechanical-enforcement
mechanism:

```
[VERIFICATION: AST <RuleName>]                     # swift-linter-rules AST module
[VERIFICATION: WF <validator>.py (<RULE-ID>)]     # reusable validator workflow
[VERIFICATION: SwiftLint <rule_name>]              # SwiftLint custom rule
[VERIFICATION NEEDED <date>: <reason>]             # version-pinned content; revalidate
```

The tag's location is the rule body (not the frontmatter), so
corpus-meta-analysis sweeps can count tagged vs untagged rules per
skill.

Tags are CLARIFYING per [SKILL-LIFE-003]. Absence of a `[VERIFICATION:]`
tag on a mechanically-enforced rule is a **doc-gap**, not a rule
violation.

**Belongs in**: `skill-lifecycle/` (new `[SKILL-CREATE-NNN]`). Cite the
verification taxonomy from `Research/skill-verification-taxonomy-pilot.md`
as the *semantic* layer; A2 itself is the *mechanical format* layer.

**Amendment class**: ADDITIVE.

### A3. Mechanical Enforcement Doc-Gap Discipline

**Triggering criterion**: G1 (canonical Wave 4 Bucket 1 signature — 22
untagged-but-enforced rules in one sweep).

**Proposed Statement**: When a lint rule (AST / SwiftLint) or validator
workflow enforces an existing skill rule, the rule's body MUST be
amended in the same commit (or closely-following commit) with:

1. A `**Lint enforcement**:` (or `**Validator enforcement**:`)
   sub-section describing what the tool checks and where it lives.
2. A `[VERIFICATION:]` tag per A2.

The amendment is CLARIFYING (no Statement change).

**Closing check**: a corpus-meta-analysis sweep that compares
`grep -l '\[VERIFICATION:'` against the swift-linter-rules catalog and
the validator workflows. Untagged rules surface as findings for next
routine cleanup.

**Belongs in**: `skill-lifecycle/` (new `[SKILL-LIFE-NNN]`). Mirrors
the [SKILL-LIFE-005] pattern (mechanical check complementing a prose
discipline rule).

**Amendment class**: ADDITIVE.

### A4. Rule Stewardship at Cluster Re-Review

**Triggering criterion**: G2 + G5 (rederived-every-session + required
for audit closure but not visible to future auditors — exactly this
framework's raison d'être).

**Proposed Statement**: When a cluster review per [SKILL-LIFE-031] runs
against a rule corpus, the audit MUST classify each in-scope rule
against the evergreen / vestigial / consolidation / gap framework
(`Research/rule-corpus-iteration-framework.md`) and record verdicts in
the audit doc per [AUDIT-019]. The verdict list is the Track-2 fix
input for [SKILL-LIFE-031]'s severity-batched remediation.

**Carries the framework's application discipline.** This framework does
NOT specify a standalone corpus-wide sweep — the corpus has already
been examined through complementary lenses (mechanization waves,
verification taxonomy, doc-gap pass, cluster audits). Instead, framework
verdicts are produced AT cluster reviews when they fire (per
[SKILL-LIFE-030] triggers: 180-day cadence for architecture/process
skills, 90 days for implementation skills, OR when a new skill joins a
cluster, OR when a composition defect surfaces). A4 makes that
application mandatory rather than optional.

**Belongs in**: `audit/` (new `[AUDIT-NNN]`) OR `skill-lifecycle/`
(new `[SKILL-LIFE-NNN]`). Placement decided at the additions handoff
(Phase 3 below).

**Amendment class**: ADDITIVE.

---

## 9. Execution plan

Four phases. Phase 0 (this document) is complete; Phases 1–4 are
future handoffs.

**Why no standalone corpus-wide audit phase**: a comprehensive 205-rule
sweep would be redundant with the recent complementary passes — the
2026-05-11 mechanization arc Waves 1–4 (every rule classified for
machine enforcement); the 2026-05-11 Wave 4 Bucket 1 doc-gap pass (22
`[VERIFICATION:]` tags added); the 2026-05-05 verification-taxonomy
pilot + 3 extensions (every rule classified mechanical / hybrid /
semantic); the 2026-04-24 cluster audit on 8 implementation-layer
skills > 600 lines (29 findings). The seed-rule verdicts in Section 7
plus the framework itself are the deliverables. Framework verdicts on
the remaining ~198 rules are produced AT cluster reviews per A4 — the
existing [SKILL-LIFE-031] cadence is the right driver, not a
standalone ecosystem-wide pass.

### Phase 1 — Non-breaking reframes (CLARIFYING)

Apply CLARIFYING dispositions in severity-batched order per
[SKILL-LIFE-031]:

| Batch | Disposition | Mechanical? |
|---|---|---|
| 1a | KEEP-WITH-TRIM (table trimming, version-pin maintenance) | Mechanical |
| 1b | REFRAME (procedure-lift, narrative-to-Provenance) | Author-judgment |
| 1c | KEEP-WITH-CROSS-REFERENCE (add explicit cross-refs to adjacent rules) | Mechanical |
| 1d | MOVE-TO-RESEARCH (registry portion of SPLIT cases) | Mechanical |
| 1e | REWRITE-AS-GUIDANCE (expand permissive bodies with predicates) | Author-judgment |

**Citation safety**: each batch validates intra- and cross-skill
cross-references resolve after the edit (`grep -rn '\[<RULE-ID>\]'`
across skills/Research/Audits).

**No user gate** beyond [SKILL-LIFE-031] severity batching.

### Phase 2 — Consolidations with redirect map (CLARIFYING)

Apply ABSORB dispositions: one rule absorbs another, the absorbed ID
becomes a redirect-anchor (short stub pointing to the surviving rule).
Per [SKILL-LIFE-026], one reference skill at a time when ABSORB crosses
skill boundaries; intra-skill absorbs are batched.

**Redirect map** must be drafted before any ABSORB lands. The map
enumerates: absorbed ID → surviving ID + body redirect text.

For the 8-seed verdicts: `[PLAT-ARCH-014]` absorbs into `[PLAT-ARCH-012]`
(the only ABSORB in the seed set).

### Phase 3 — Breaking retirements (BREAKING)

Apply RETIRE dispositions (if any surface from cluster reviews per A4).
The seed-rule verdicts produce **zero RETIREs**, so Phase 3 fires only
when a cluster review per A4 classifies a rule as Vestigial-V3b /
V4-empty / V5-no-residual / V6-no-application-value. Per the hard
execution criterion:

> A rule may not be retired until every inbound reference is either
> rewritten, redirected to a successor rule, or intentionally preserved
> as historical provenance.

**Citation rewrite enumeration** (workspace-wide):

```bash
grep -rln '\[<RETIRED-ID>\]' \
  swift-institute/Skills/ swift-primitives/Skills/ \
  swift-foundations/Skills/ swift-standards/Skills/ \
  swift-institute/Research/ swift-institute/Audits/ \
  rule-institute/Skills/
```

Each cite reviewed; choose rewrite (point at surviving rule) OR
redirect-anchor (stub at retired ID points at surviving rule) OR
provenance-only (cite preserved as historical reference).

**[SKILL-LIFE-003] class**: BREAKING. User gate required per the
investigator ground rules. Per [SKILL-LIFE-026], one reference
skill at a time.

### Phase 4 — Additions (ADDITIVE)

Add A1–A4 (plus any audit-surfaced gaps that future cluster reviews
report under A4). Per [SKILL-CREATE-006] / [SKILL-CREATE-006a]: each
new rule needs the standard structure (Statement / Procedure / Worked
example / Rationale / Provenance / Cross-references) and the
internal-consistency pass before integration.

**Suggested dispatch shape**: one handoff per skill that gains
additions (`platform/` for A1, `skill-lifecycle/` for A2/A3, `audit/`
or `skill-lifecycle/` for A4 — placement decision made at this phase).

**Phase ordering note**: Phases 1–3 act on the 8-seed verdicts in
Section 7 and can proceed independently of A4. A4 is the carrier for
*future* framework application — once landed, subsequent cluster
reviews per [SKILL-LIFE-031] produce framework verdicts on rules
beyond the seed set. The four phases can run in parallel where their
edit zones don't overlap.

---

## Out of Scope

- Phases 1–4 implementation (future handoffs).
- Standalone corpus-wide audit applying this framework to all 205 rules.
  The corpus has already been examined through the mechanization
  arc Waves 1–4, the verification-taxonomy pilot + 3 extensions,
  the Wave 4 Bucket 1 doc-gap pass, and the 2026-04-24 cluster audit
  on 8 implementation-layer skills > 600 lines. Framework verdicts on
  the remaining ~198 rules are produced AT cluster reviews per A4 (the
  existing [SKILL-LIFE-031] cadence), not via a separate sweep.
- Extending the framework to skills beyond `code-surface` / `platform`
  / `implementation`. The framework is generalizable but bounded to
  the three-skill scope of this dispatch.
- Mechanization decisions (the mechanization arc is complete per the
  2026-05-11 program closeout).

## References

### Skills

- `swift-institute/Skills/code-surface/SKILL.md` (38 rules)
- `swift-institute/Skills/platform/SKILL.md` (59 rules)
- `swift-institute/Skills/implementation/SKILL.md` + 7 siblings (108 rules)
- `swift-institute/Skills/skill-lifecycle/SKILL.md` — [SKILL-LIFE-001..031], [SKILL-CREATE-001..014]
- `swift-institute/Skills/audit/SKILL.md` — [AUDIT-019]
- `swift-institute/Skills/research-process/SKILL.md` — [RES-003a], [RES-020]
- `swift-institute/Skills/collaborative-discussion/SKILL.md` — [COLLAB-002..013]
- `swift-institute/Skills/handoff/SKILL.md` — [HANDOFF-001..037]

### Research

- `Research/skill-shape-and-growth-evaluation.md` v1.1.0 (2026-04-24, DECISION)
- `Research/skill-verification-taxonomy-{pilot,extension-tier-1,extension-tier-2,extension-tier-3}.md`
- `Research/skills-condensation-triage-phase-1.md` (2026-05-05, RECOMMENDATION)
- `Research/mechanical-rule-tool-classification-swift-primitives.md`

### Audits

- `Audits/_program-maximize-mechanical-enforcement-2026-05-11.md` (mechanization arc closeout)

### Deliberation transcript

- `/tmp/rule-corpus-iteration-round-1-for-chatgpt.md` — Round 1 combined file
- `/tmp/rule-corpus-iteration-round-2-claude.md` — Round 2 - Claude
- `/tmp/rule-corpus-iteration-round-3-claude.md` — Round 3 - Claude
- `/tmp/rule-corpus-iteration-transcript.md` — accumulated transcript
- `/tmp/rule-corpus-iteration-converged.md` — converged plan per [COLLAB-004]

### Originating handoff

- `HANDOFF-rule-corpus-iteration.md` (workspace root)
