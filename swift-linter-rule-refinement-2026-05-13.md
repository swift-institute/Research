# swift-linter rule refinement — Story 2 cohort 3-class triage (2026-05-13)

<!--
---
version: 1.0.0
status: DECISION
last_updated: 2026-05-13
predecessor_framework: rule-corpus-iteration-framework.md (v1.1.0, 2026-05-11)
predecessor_triage_memory: feedback_lint_triage_three_class.md (2026-05-13)
predecessor_aggregate: swift-foundations/swift-linter-rules/Research/lint-pass-2026-05-11-aggregate.md
dispatch_handoff: /Users/coen/Developer/HANDOFF-swift-linter-rule-refinement.md
triage_note: |
  Surfaced a fourth class shape during this dispatch: "built-in rule, can't refine, disable-with-reason is the
  only option" (force_try on the 4 cyclic sites). Distinct from class-1 "fix-source with disable annotation when
  source IS the fix" because the rule is non-customizable by predicate (SwiftLint built-in), not because the
  source-is-the-fix invariant applies. Recorded here for traceability; orchestrator folds into
  feedback_lint_triage_three_class post-dispatch.
---
-->

## Context

The Story 2 readiness chats (Wave 1+2, dispatched 2026-05-13) landed
16 `swiftlint:disable:next` annotations across 7 flipped packages
(cardinal, ordinal, affine, index, order, sequence, cyclic). The 2026-05-13
lint-triage memory [[feedback_lint_triage_three_class]] requires triaging
each disable into one of three classes — **fix-source**, **fix-rule**, or
**ambiguous** — rather than treating disable-with-reason as the only
non-source-fix option. The framework's TIGHTEN/LOOSEN dispositions for
mechanical-enforcement rules ([[rule-corpus-iteration-framework]] v1.1.0
§5.3) apply when a rule's false-positive rate against a real-corpus pass
reaches ≥ 20%.

This doc reports the triage of all 16 disables, the two TIGHTEN refinements
implemented this dispatch, the class-3 candidates surfaced for principal
triage, and the authorization gates required for downstream propagation.

### Transitional context (2026-05-13)

The institute is migrating from SwiftLint (and possibly swift-format) toward
the institute's own swift-linter (AST-based, in `swift-foundations/swift-linter`
+ `swift-linter-rules`). The two TIGHTENs landed this dispatch refine
SwiftLint custom-rule regexes — a transitional layer whose long-term
destination is AST-based equivalents in swift-linter. The refinements remain
valuable in the interim window because they close 11 of 16 current-state
false-positive disables across three flipped packages; they MAY be re-derived
as SwiftSyntax visitor exemptions ([[rule-exemptions]] / [RULE-EXEMPT-*])
when the rule pack migrates. The class-3 dispositions for `workaround_marker_present`
and `force_try` are unaffected by this migration (the F-rule for the former
is already deferred per Wave 2b decision 1; the latter is a SwiftLint built-in
without a swift-linter analog yet).

## Rule definitions located

| Rule | Type | Canonical home |
|------|------|----------------|
| `chained_rawvalue_access_anti_pattern` | SwiftLint custom rule (Tier 2) | `swift-primitives/.github/.swiftlint.yml:116` |
| `chained_rawvalue_access_paren_evasion` | SwiftLint custom rule (Tier 2, companion to canonical) | `swift-primitives/.github/.swiftlint.yml:125` |
| `bitpattern_rawvalue_chain_anti_pattern` | SwiftLint custom rule (Tier 2) | `swift-primitives/.github/.swiftlint.yml:130` |
| `workaround_marker_present` | SwiftLint custom rule (Tier 1) | `swift-institute/.github/.swiftlint.yml:229` |
| `force_try` | SwiftLint **built-in** rule | (not a custom rule; built into the SwiftLint binary) |

**AST-layer cross-reference**: the cohort packages cardinal/ordinal/affine
already exclude the corresponding AST-layer rules (`raw value access`,
`chained rawvalue access`, `int public parameter`, `pointer advanced by`) from
`Lint.Rule.Bundle.primitives` via the local `Lint.swift` `excluding(rules:)`
combinator (Phase 3.F, Row 25 — Lint.swift commits on those three repos are
in-flight Do-Not-Touch state). The 16 cohort disables are SwiftLint-layer,
not AST-layer.

## 3-class triage matrix

| # | Site | Rule | Class | Disposition | Action |
|---|------|------|-------|-------------|--------|
| 1 | swift-cardinal-primitives/Sources/Cardinal Primitives Standard Library Integration/Int+Cardinal.swift:52 | bitpattern_rawvalue_chain_anti_pattern | **class-2 fix-rule** | TIGHTEN: path-exclude `Standard Library Integration` | ✓ Implemented (commit `9fe9b88`) |
| 2 | swift-ordinal-primitives/Sources/Ordinal Primitives Standard Library Integration/Int+Ordinal.swift:72 | bitpattern_rawvalue_chain_anti_pattern | **class-2 fix-rule** | TIGHTEN: same as #1 | ✓ Implemented (commit `9fe9b88`) |
| 3 | swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.swift:95 | chained_rawvalue_access_anti_pattern | **class-2 fix-rule** | TIGHTEN: method-allowlist | ✓ Implemented (commit `dc9e091`) |
| 4 | swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Add.swift:32 | chained_rawvalue_access_anti_pattern | **class-2 fix-rule** | TIGHTEN: same as #3 | ✓ Implemented (commit `dc9e091`) |
| 5 | swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Add.swift:50 | chained_rawvalue_access_anti_pattern | **class-2 fix-rule** | TIGHTEN: same as #3 | ✓ Implemented (commit `dc9e091`) |
| 6 | swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Advance.swift:41 | chained_rawvalue_access_anti_pattern | **class-2 fix-rule** | TIGHTEN: same as #3 | ✓ Implemented (commit `dc9e091`) |
| 7 | swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Advance.swift:62 | chained_rawvalue_access_anti_pattern | **class-2 fix-rule** | TIGHTEN: same as #3 | ✓ Implemented (commit `dc9e091`) |
| 8 | swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Advance.swift:88 | chained_rawvalue_access_anti_pattern | **class-2 fix-rule** | TIGHTEN: same as #3 | ✓ Implemented (commit `dc9e091`) |
| 9 | swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete+Arithmetic.swift:36 | chained_rawvalue_access_anti_pattern | **class-2 fix-rule** | TIGHTEN: same as #3 | ✓ Implemented (commit `dc9e091`) |
| 10 | swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete+Arithmetic.swift:51 | chained_rawvalue_access_anti_pattern | **class-2 fix-rule** | TIGHTEN: same as #3 | ✓ Implemented (commit `dc9e091`) |
| 11 | swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete+Arithmetic.swift:97 | chained_rawvalue_access_anti_pattern | **class-2 fix-rule** | TIGHTEN: same as #3 | ✓ Implemented (commit `dc9e091`) |
| 12 | swift-sequence-primitives/Sources/Sequence Difference Primitives/Sequence.Difference+core.swift:38 | workaround_marker_present | **class-3 ambiguous** | Defer to swift-linter F-rule per Wave 2b decision 1; OR optional TIGHTEN via multi-line negative-lookahead (surfaced below) | ✗ Surfaced for principal triage |
| 13 | swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group+Arithmetic.swift:128 | force_try (SwiftLint built-in) | **class-1 fix-source** | Keep disable-with-reason; built-in rule cannot be TIGHTEN'd in our config | (no rule action) |
| 14 | swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group.Static+Sequence.Protocol.swift:49 | force_try | **class-1 fix-source** | Same as #13 | (no rule action) |
| 15 | swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group.Static.Iterator.swift:41 | force_try | **class-1 fix-source** | Same as #13 | (no rule action) |
| 16 | swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group.Static.Element.swift:50 | force_try | **class-1 fix-source** | Same as #13 | (no rule action) |

**Totals**: 11 class-2 (TIGHTEN — both implemented this dispatch) / 1 class-3
ambiguous (workaround_marker_present, surfaced for principal triage) / 4
class-1 (force_try, built-in, intrinsically disable-with-reason).

### Out-of-brief observation: 7 `comment_spacing` disables in affine Tests

The brief's enumeration referenced 16 disables in Sources. The grep also
surfaced 7 additional `swiftlint:disable comment_spacing` disables in
`swift-affine-primitives/Tests/` (block-form, not `:next` form). These are
unrelated to the 4 firing rules and out of brief scope; flagged here for
follow-up triage. Likely class-1 if `comment_spacing` collides with the
test files' DocC comment shape, but warrants a separate look.

## Refinement details

### Refinement A — `bitpattern_rawvalue_chain_anti_pattern` (commit `9fe9b88`)

**Disposition**: TIGHTEN per framework v1.1.0 §5.3 (class-2 fix-rule).

**Change**: added `excluded:` block to the rule definition, mirroring the
`no_int_bitpattern_arithmetic` precedent at Tier 1 ([CI-054]-adjacent rule
at `swift-institute/.github/.swiftlint.yml:248`). The two exclude patterns
cover both spelling variants of [IMPL-010] Standard Library Integration
target paths:

```yaml
excluded:
  - 'Sources/.*Standard_Library_Integration.*'
  - 'Sources/.*Standard Library Integration.*'
```

**Rationale**: `[INFRA-002]` integration overloads — `Int.init(bitPattern: Cardinal)`,
`Int.init(bitPattern: Ordinal)`, etc. — live by convention in
`Sources/<Module> Standard Library Integration/` per `[IMPL-010]`. Those
sites ARE the typed-system bottom-out definitions themselves; the rule's
intent is to prevent consumer-side chaining, not to flag the bottom-out
definitions. Without the path-exclude, the rule's MESSAGE itself prescribes
disable-with-reason at every `[INFRA-002]` integration overload site — an
unnecessary noise generator if the rule's predicate can mechanically
distinguish definition from consumption.

**Predecessor precedent**: `no_int_bitpattern_arithmetic` in Tier 1 already
uses the exact same path-exclude pattern (with the same dual spelling for
underscored module-name paths vs spaced directory-name paths). The TIGHTEN
mirrors a proven shape.

**Closes**: 2 disable sites (`Int+Cardinal.swift:52`, `Int+Ordinal.swift:72`).

**Regression check**: 0 fires across the 11-package 2026-05-11 aggregate
(empirically verified — none of those packages use the `Int(bitPattern: x.rawValue)`
shape).

### Refinement B — `chained_rawvalue_access_anti_pattern` + companion (commit `dc9e091`)

**Disposition**: TIGHTEN per framework v1.1.0 §5.3 (class-2 fix-rule).

**Change**: replaced `regex: '\.rawValue\.\w+'` with a negative-lookahead
allowlist of the canonical stdlib overflow-aware arithmetic primitives +
`magnitude`:

```yaml
regex: '\.rawValue\.(?!(?:addingReportingOverflow|subtractingReportingOverflow|multipliedReportingOverflow|dividedReportingOverflow|remainderReportingOverflow|magnitude)\b)\w+'
```

The companion `chained_rawvalue_access_paren_evasion` rule receives the same
TIGHTEN in lockstep (preserving the canonical-vs-evasion symmetry).

**Rationale**: the 6 excluded methods ARE the typed system's bottom-out per
`[INFRA-103]` option (iv) — typed Cardinal/Ordinal/Affine.Discrete arithmetic
operators MUST call them to ground into stdlib UInt arithmetic. They have
NO typed-system equivalent (the stdlib's overflow-aware unsigned arithmetic
IS the bottom). The rule still fires on consumer chains (`.rawValue.method()`
for any method outside the allowlist) — only the structural bottom-out
methods are exempted.

**Empirical FP rate driving TIGHTEN qualification**: 9 of 9 fires in the
Story 2 cohort were typed-system bottom-out sites (100% FP rate, easily
exceeds the framework's ≥ 20% threshold).

**Closes**: 9 disable sites across cardinal/ordinal/affine (all
`*Primitives Core/*` paths implementing typed-arithmetic operators).

**Risk: legitimate-FN concern**: a consumer outside the brand-newtype's Core
target writing `someTagged.rawValue.addingReportingOverflow(other)` would
silently bypass the rule under the TIGHTEN. The consumer SHOULD use
`.add.exact(...)` / `.add.saturating(...)` typed accessors per `[INFRA-103]`.
**Mitigation**: the rule's intent is to flag typed-system escapes; a
consumer chaining through `.rawValue.addingReportingOverflow` to redo
typed-arithmetic by hand is admittedly an escape, but a sufficiently
specific one that the manual nature is the violation, not the method choice.
A separate AST-layer rule (post-swift-linter migration) could distinguish
brand-newtype-implementation-internal call sites from consumer call sites
via scope analysis — that's the eventual destination per the transitional
context above.

**Regression check**: 0 fires across the 11-package 2026-05-11 aggregate
(empirically verified — the rule was added 2026-05-06 cohort-scoped and
hasn't fired in the broader corpus).

### Refinement C (NOT IMPLEMENTED) — `workaround_marker_present`

**Disposition**: class-3 ambiguous, surfaced for principal triage.

**Current state**: the rule's interim regex `//\s*WORKAROUND:` is
single-line by design (Wave 2b decision 1); the full four-part template
check (`// WORKAROUND:` paired with `// WHY:`, `// WHEN TO REMOVE:`,
`// TRACKING:` within ±5 lines) is deferred to a future swift-linter
F-rule. The Sequence.Difference+core.swift:38 site IS correctly using the
full template; the disable-with-reason annotation cites this fact and the
rule's interim nature.

**Optional TIGHTEN (proposal — NOT YET IMPLEMENTED)**: a multi-line
negative-lookahead regex could fire only when `// WORKAROUND:` is NOT
followed within 5 lines by a `// WHY:` marker:

```yaml
regex: '//\s*WORKAROUND:(?![\s\S]*?//\s*WHY:)'
```

This negative-lookahead spans an arbitrary distance, which over-shoots
the "±5 lines" rule body intent. A bounded form (`(?:[^\n]*\n){0,5}`) is
possible but adds regex complexity. SwiftLint accepts NSRegularExpression
lookahead; empirical feasibility is high.

**Why surfaced rather than implemented**:

1. The current site IS correctly using the full four-part template; the
   disable is intentional per [DOC-045] / [PATTERN-016] and the rule
   message acknowledges the interim regex's structural limit.
2. The principal previously authorized the Wave 2b interim shape with the
   F-rule scheduled as the long-term destination. A regex TIGHTEN may
   conflict with the F-rule's design space.
3. With the institute moving to swift-linter (transitional context above),
   the F-rule should be authored directly in swift-linter rather than the
   regex layer.

**Recommended principal disposition**: leave the rule unchanged; the
single class-1 disable-with-reason at Sequence.Difference+core.swift is
correct under the rule's current design. Move the multi-line check to
swift-linter F-rule scope (where AST-level WORKAROUND/WHY adjacency can
be verified properly).

### Refinement D (NOT APPLICABLE) — `force_try`

`force_try` is a SwiftLint **built-in** rule. The institute's
`.swiftlint.yml` files at Tier 1 and Tier 2 do not override its behavior,
and SwiftLint's built-in rules are not customizable by predicate (only
disable / opt-in). The 4 cyclic disables are intrinsically class-1
(fix-source-as-disable-with-reason); each carries a reason citation
documenting the typed-system bottom-out (`modulus > 0` is a generic
constraint guarantee; `Cardinal(Int)` only throws on negative input, which
the constraint precludes).

**Future eligibility for AST refinement**: when swift-linter ships a
`force_try`-equivalent AST rule, the rule's predicate COULD include
type-aware exclusions (e.g., exempt `try!` calls inside a `static let`
context where the throwing initializer's domain restriction is provably
satisfied). That's a swift-linter design-time decision beyond this
dispatch's scope.

## Empirical verification

| Check | Result |
|-------|--------|
| OLD rules + cohort sources with disables (baseline) | 0 fires (disables suppress) ✓ |
| OLD rules + cohort sources WITHOUT disables (synthetic disable-strip) | 11 fires across cardinal: 3 chained + 1 bitpattern (sampled — confirms disables were necessary) ✓ |
| TIGHTEN'd rules + cohort sources WITHOUT disables (synthetic disable-strip) | 0 fires at the 11 disable sites ✓ |
| TIGHTEN'd rules + 11-aggregate packages | 0 fires (regression check passes) ✓ |
| SwiftLint accepts negative-lookahead regex syntax | YES (synthetic test on `/tmp` config + `test.swift` passes) ✓ |
| SwiftLint accepts `excluded:` path-glob | YES (mirrors existing `no_int_bitpattern_arithmetic` precedent) ✓ |

The regex test for the negative-lookahead was run on a synthetic file
distinguishing allowlist methods (`addingReportingOverflow`, `magnitude`)
from consumer-method names (`method()`, `somethingElse`). The TIGHTEN'd
regex fired on the latter and not the former, confirming the predicate's
correctness.

## Outcome (commits staged locally, NOT pushed)

| Commit | Repo | Subject |
|--------|------|---------|
| `9fe9b88` | `swift-primitives/.github` | TIGHTEN bitpattern_rawvalue_chain_anti_pattern: path-exclude Standard Library Integration |
| `dc9e091` | `swift-primitives/.github` | TIGHTEN chained_rawvalue_access_anti_pattern + paren_evasion: method-allowlist for stdlib overflow-aware arithmetic |

Both commits are local-only (`git log @{u}..HEAD` confirms 2 unpushed).
Per the brief's "Stage but do not push" instruction.

## Authorization gates needed

The downstream propagation steps require explicit user authorization per
the institute's per-action discipline ([CI-050], [GIT-001],
`feedback_no_public_or_tag_without_explicit_yes.md`):

1. **`git push` of the 2 rules-repo commits** — required before cohort
   packages will see the refined rules (their `parent_config` fetches from
   the remote URL `https://raw.githubusercontent.com/swift-primitives/.github/main/.swiftlint.yml`).

2. **Disable-removal commits per affected package** — BLOCKED on Do-Not-Touch
   state. After (1) lands and the user has rebased their in-flight Phase 3.F
   (Row 25) commits in cardinal/ordinal/affine, a follow-up dispatch can
   remove 11 redundant disable annotations (one commit per package):
   - swift-cardinal-primitives: remove 4 disables (`Int+Cardinal.swift:52`,
     `Cardinal.swift:95`, `Cardinal.Add.swift:32`, `Cardinal.Add.swift:50`)
   - swift-ordinal-primitives: remove 4 disables (`Int+Ordinal.swift:72`,
     `Ordinal.Advance.swift:41`, `:62`, `:88`)
   - swift-affine-primitives: remove 3 disables
     (`Affine.Discrete+Arithmetic.swift:36`, `:51`, `:97`)

3. **No disable removals in this dispatch** for sequence/cyclic — the
   sequence disable is class-3 deferred; the cyclic disables are class-1
   built-in. Both correctly remain in place.

## Cross-references

- Predecessor framework: [[rule-corpus-iteration-framework]] v1.1.0 (2026-05-11) —
  E/V/C/G criteria + TIGHTEN/LOOSEN dispositions.
- Triage memory: `feedback_lint_triage_three_class.md` (2026-05-13).
- Disable-mechanism design: [[swift-linter-per-finding-disable-mechanism]]
  v1.1.0 (2026-05-11) — Option D hybrid decision for swift-linter.
- swift-linter transition: [[2026-05-07-swift-linter-consumer-syntax]],
  [[2026-05-12-swift-linter-unified-consumer-manifest]],
  [[three-tier-linter-rules-partition]], [[swift-linter-launch-skill-incorporation-backlog]].
- Related-not-predecessor: `HANDOFF-rule-corpus-iteration.md` (workspace
  root) — broader 205-skill-rule scope; this dispatch is a focused
  application of the same framework to the linter-rule corpus.
- Aggregate baseline: [[lint-pass-2026-05-11-aggregate]] — 73 rules × 11
  packages = 896 findings; the SwiftLint custom rules refined here were not
  measured (AST-layer aggregate).
- Skill: [[rule-exemptions]] — analogous concept at the AST layer (when
  the swift-linter rules ship, the seven `[RULE-EXEMPT-N]` shapes become
  the canonical home for what regex-allowlist + path-exclude express here).

## Provenance

- HANDOFF dispatch: `/Users/coen/Developer/HANDOFF-swift-linter-rule-refinement.md`
- Parent conversation: readiness orchestrator for `data-structures-launch-2026`
  Wave 1+2 (sequenced 2026-05-13).
- Rule definitions inspected at: `swift-primitives/.github/.swiftlint.yml`
  + `swift-institute/.github/.swiftlint.yml` (as of 2026-05-13).

---

## Wave 2 Sweep — 2026-05-13

**Status**: COMPLETE (4 local commits across 2 packages; no push). Sweep
+ triage + class-1 source fixes landed under orchestrator direction
(2026-05-13 post-pause). Findings stamp at
`HANDOFF-swift-linter-wave-2-sweep.md` (workspace root) records commit
SHAs + Q-disposition appendix + out-of-scope queue.

**Dispatch**: `HANDOFF-swift-linter-wave-2-sweep.md` (workspace root,
2026-05-13).

### Setup + premise-staleness

| Aspect | State at dispatch-write | State at execution-time | Disposition |
|---|---|---|---|
| Engine branch `lint-pass-audit-2026-05-11` | Cited as the canonical `--all` source | Not present locally; remote-only origin/main has the commit `17a9777 THROWAWAY: --all flag for lint-pass triage 2026-05-11` superseded by Threads C/D/E refactors. Current main's CLI has NO `--all` flag — Shape γ `Lint.swift` is the only consumer-shape on main | The brief's `(or current main if newer)` opt-out covers this. Substituted `Lint.Rule.Bundle.primitives` via a per-package Shape γ `Lint.swift` for full-corpus surface. |
| Engine SHA | not specified | `084347b0d7391eab1ac15c44982d8b42f8fc6293` (current main of `swift-foundations/swift-linter`) | recorded |
| Engine build state | brief says "verify buildable" | First build attempt failed at link time (`Binary_Machine_Primitives.Binary.Bytes.Machine.pure` undefined — workspace-wide parallel-migration transient; `feedback_parallel_workspace_no_build` fired). Second rebuild after engine working tree settled to clean: succeeded in 8.84s | unblocked |
| Wave 2 `Lint.swift` state | not specified | sequence + cyclic do NOT have a Lint.swift at the package root (gitignored at line 14: `/*` + no `!/Lint.swift` whitelist override). Their CI sees **zero swift-linter rules firing** by construction — the Wave 2 readiness chats' "0 violations" report on the cohort `.swiftlint.yml` config is technically true but does not exclude the swift-linter AST corpus, which is silent on these packages today. | **GAP identified**. The Lint.swift absence IS the structural cause of the missing measurement. |

**Canonical command used** (after temp Lint.swift placed at the package
root with `path: "../swift-primitives-linter-rules"`):

```bash
cd <wave-2-package> && \
SWIFT_LINTER_PATH=/Users/coen/Developer/swift-foundations/swift-linter \
/Users/coen/Developer/swift-foundations/swift-linter/.build/debug/swift-linter
```

### Brief-premise mismatch — class-2 TIGHTEN location

The brief says:

> class-2 (fix-rule): propose TIGHTEN/LOOSEN refinements at
> `swift-primitives/.github/.swiftlint.yml`

This destination is correct for **SwiftLint custom rules** (the prior
dispatch's 11 TIGHTENs at `9fe9b88` + `dc9e091`). It is NOT the correct
destination for **swift-linter AST rules** — those live in:

- `swift-foundations/swift-linter-rules/Sources/Linter Rules/` (universal pack)
- `swift-foundations/swift-institute-linter-rules/Sources/Linter Institute Rules/` (institute pack)
- `swift-primitives/swift-primitives-linter-rules/Sources/Linter Primitives Rules/` (primitives pack)

The Wave 2 sweep findings are **entirely swift-linter AST rules** — no
SwiftLint custom rules fired on Wave 2 sources (consistent with the
Wave 2 readiness chats' "0 SwiftLint violations" report). Class-2
TIGHTENs from this sweep would therefore land in the AST rule-pack
repos, not at `swift-primitives/.github/.swiftlint.yml`. The
swift-linter-rules engine repos are partly Do-Not-Touch in this brief
(`swift-foundations/swift-linter` + `swift-foundations/swift-institute-linter-rules`
+ `swift-primitives/swift-linter-primitives` all carry uncommitted work
or unpushed commits per the brief's table).

### Sweep results — by package + scope

Brief scope is `Sources/` + `Tests/`. Experiments are out-of-brief and
excluded from the tables below. Sweep output retained at
`/tmp/sequence-sweep.log` + `/tmp/cyclic-sweep.log`; filtered findings
at `/tmp/sequence-findings.log` + `/tmp/cyclic-findings.log`.

#### swift-sequence-primitives — 228 findings (110 Sources + 118 Tests)

| Rule | Sources | Tests | Predominant pattern |
|------|---------|-------|---------------------|
| minimal type body | 39 | 6 | `Sequence.Difference.*Iterator` types co-locating storage + `next()` (also Tests Support stored-property suites) |
| compound identifier | 30 | 2 | DocC step files + Difference Hunk fields (`equalRangeA`/`equalRangeB` etc.) |
| compound type name | 3 | 49 | Tests: `<Suite>Tests` legacy compound-name pattern per `[SWIFT-TEST-002]` migration backlog |
| compound suite name | 0 | 47 | Tests: same legacy pattern; rule explicitly cites `[SWIFT-TEST-002]` extension-pattern |
| inlinable internal access | 21 | 1 | Difference iterators' `@inlinable init` with implicit-internal visibility — `[PATTERN-052]` prescribes `package init` |
| typealiased namespace bridge | 6 | 5 | Tests: `Sequence.Protocol` bridge typealiases |
| extension noncopyable constraint | 5 | 0 | `[MEM-COPY-004]` — extensions on `~Copyable`-aware generics missing explicit `~Copyable` constraint |
| namespace adoption typealias | 0 | 5 | Tests |
| callback result over throws thunk | 4 | 0 | `Sequence.Span+Property.Inout`, `Sequence.Reduce+Property.Inout` — closures take `Result<T, E>` instead of `() throws(E) -> T` per `[IMPL-092]` |
| unification typealias | 0 | 2 | Tests |
| unchecked sendable categorization | 1 | 0 | 1 site |
| raw value access | 0 | 1 | Tests — 1 site |
| counter loop iteration | 1 | 0 | 1 site |

#### swift-cyclic-primitives — 119 findings (57 Sources + 62 Tests)

| Rule | Sources | Tests | Predominant pattern |
|------|---------|-------|---------------------|
| raw value access | 19 | 25 | Brand-newtype-owner same-package `.position` access (`Cyclic.Group.Static.Element` is Tagged-Ordinal); `[PATTERN-017]` cites this case |
| unchecked call site | 17 | 26 | Brand-newtype-owner `Element(__unchecked: ordinal)` constructions — `[CONV-016]` rule message prescribes `// swift-linter:disable:next unchecked call site` at the bottom-out site |
| minimal type body | 14 | 0 | Sources only |
| compound type name | 0 | 4 | Tests: `[SWIFT-TEST-002]` backlog |
| compound suite name | 0 | 4 | Tests: same |
| tagged extension public init | 3 | 0 | `Tagged+Cyclic.Group.Static.Element.swift` — domain-extending Tagged init that does not satisfy `[INFRA-103]` (per the protocol-witness-citation-dict `[RULE-EXEMPT-2]`) |
| compound identifier | 3 | 0 | Sources |
| inlinable internal access | 1 | 0 | 1 site |
| test function naming | 0 | 1 | Tests |
| int public parameter | 0 | 1 | Tests |
| do throws for typed catch | 0 | 1 | Tests |

### Structural direction questions — orchestrator review needed

The user halted execution on the cyclic Lint.swift draft (mirroring
cardinal's `excluding(rules:)` precedent) with two distinct concerns.
Both compose into a single direction question for the orchestrator:

#### Q1 — Typed `Lint.Rule.ID` accessor vs `String` literals

The Wave 1 precedent `swift-cardinal-primitives/Lint.swift` uses bare
string literals:

```swift
Lint.Rule.Bundle.primitives.excluding(rules: [
    "raw value access",
    "chained rawvalue access",
    "int public parameter",
    "pointer advanced by",
])
```

`Lint.Rule.Bundle+Excluding.swift:36` signature:

```swift
public func excluding(rules excluded: Set<Lint.Rule.ID>) -> [Lint.Rule.Configuration]
```

`Lint.Rule.ID` is `Tagged<Lint.Rule, Swift.String>` with
`ExpressibleByStringLiteral` conformance — that's why the bare string
form compiles. But the **typed-accessor form** referencing the rule's
own static-let identifier (`Lint.Rule.Structure.\`raw value access\`.id`,
or equivalent typed access) is the canonical form per the typed-system
philosophy. The string literal is a `[INFRA-103]`-style typed-system
bottom-out at the consumer call site; the rule registry already provides
the typed accessor.

**Decision needed**:

- (a) **Mirror precedent exactly**: copy cardinal's string-literal form to
  cyclic. Risk: propagates the typed-bottom-out across Wave 2.
- (b) **Use the typed accessor form**: cite the rule's typed identifier
  directly (form to be confirmed — `Lint.Rule.<Pack>.\`<rule name>\`.id`
  or a sibling accessor). Risk: requires verifying the typed surface is
  accessible from the consumer (cross-pack imports). Likely warrants a
  retro-update of cardinal/ordinal/affine.
- (c) **Defer both**: surface the precedent's typed-bottom-out as a
  separate finding against cardinal/ordinal/affine (their existing
  Lint.swift files); Wave 2 inherits the chosen form once decided.

#### Q2 — Rule-silencing (`excluding`) vs rule-refinement (smarter rule)

The cardinal precedent **silences entire rules** for the package — once
in the `excluding(rules:)` set, the rule doesn't fire anywhere in
sequence/cyclic, including future code that may genuinely violate the
typed-conversion-ladder convention. This loses cross-cutting safety in
the same package.

The prior dispatch (refinements A/B at `9fe9b88` + `dc9e091`) took the
**smarter-rule** direction for SwiftLint custom rules:

- Refinement A added a path-exclude for `Sources/.*Standard Library Integration.*`
  to `bitpattern_rawvalue_chain_anti_pattern` — the rule continues firing
  outside that path
- Refinement B replaced `\.rawValue\.\w+` with a negative-lookahead
  allowlist of the stdlib overflow-aware arithmetic primitives — the rule
  continues firing on consumer chains outside the allowlist

The same direction applied at the swift-linter AST layer would address
the brand-newtype-owner same-package access as a **rule-level**
exemption (file-path or package-context predicate, or a `[RULE-EXEMPT-N]`
shape registered in the rule's lookup helpers), preserving cross-package
firing AND in-package cross-cutting safety, ecosystem-wide.

The cardinal precedent's `excluding(rules:)` was authored on 2026-05-12
per the numerics-rule-recognizer doc Option 7 ("rule decomposition via
bundle composition") — the historical answer at the time. The smarter-
rule alternative (Option N — predicate-refined rule) was not pursued
then; the user is now asking whether it should be pursued now.

**Decision needed**:

- (a) **Continue cardinal precedent**: per-package `excluding(rules:)`
  with package-author's exclusion list. Wave 2's cyclic Lint.swift mirrors
  cardinal's exclusion list verbatim (plus likely `unchecked call site`
  and `tagged extension public init` additions for cyclic's specific
  pattern). Closes 44 + 43 + 3 = 90 cyclic findings as class-1
  fix-source-via-Lint.swift.
- (b) **Pivot to rule-refinement**: refine the four recognizer rules
  (`raw value access`, `chained rawvalue access`, `int public parameter`,
  `pointer advanced by`) plus `unchecked call site` + `tagged extension
  public init` in `swift-foundations/swift-linter-rules` and
  `swift-primitives/swift-primitives-linter-rules` to detect brand-newtype-
  owner same-package context (file-path predicate or `[RULE-EXEMPT-N]`
  registry). On landing, cardinal/ordinal/affine's `excluding(rules:)`
  becomes redundant and can be retired. Wave 2 inherits the smarter
  rules with no Lint.swift exclusion needed beyond the bare
  `Bundle.primitives`. Touches engine-rule repos (currently Do-Not-Touch
  in this brief, would need scope expansion).
- (c) **Hybrid**: ship cardinal-precedent for Wave 2 NOW (preserving CI
  green on the public flip 2026-05-13), with a follow-on rule-refinement
  dispatch on a known schedule that retires the per-package `excluding`
  ecosystem-wide.

#### Q3 — Lint.swift adoption gap on Wave 2 (independent of Q1/Q2)

`sequence-primitives/.gitignore:14` `/*` + no `!/Lint.swift` whitelist
means **sequence + cyclic do not currently have Lint.swift at all**. The
swift-linter AST corpus is silent on them by construction. Adoption
requires:

- Add `!/Lint.swift` to LOCAL OVERRIDES in each package's `.gitignore`
  (sync-script convention per `[CI-043]`)
- OR add `Lint.swift` to the canonical sync-gitignore.sh template's
  whitelist (would ripple ecosystem-wide; appropriate if every primitive
  should run the swift-linter — which the Wave 1 precedent suggests is
  the intended end state)

Wave 1 packages cardinal/ordinal/affine have Lint.swift tracked
(confirmed via `git ls-files` on cardinal). They must have the
`!/Lint.swift` LOCAL OVERRIDE already; the Wave 2 adoption is the
mechanical follow-on.

**Decision needed**:

- (a) **Per-package override**: add `!/Lint.swift` to LOCAL OVERRIDES
  in sequence + cyclic's `.gitignore`. Two-line change per package.
- (b) **Ecosystem-wide canonical whitelist**: update
  `swift-institute/Scripts/sync-gitignore.sh` to include `!/Lint.swift`
  in the canonical block. All ~131 swift-primitives packages get
  whitelist on next sync. Appropriate if every primitive is expected to
  carry a Lint.swift.

### Triage table — pending Q1/Q2/Q3 dispositions

Each row carries its disposition under (a) cardinal-precedent direction
(Q2(a)) and (b) rule-refinement direction (Q2(b)). The class-1/2/3
column is the eventual class once direction is chosen.

| # | Rule | Sequence | Cyclic | Under Q2(a) cardinal-precedent | Under Q2(b) rule-refinement | Eventual class |
|---|------|---------|-------|---|---|---|
| 1 | raw value access | 0 / 1 | 19 / 25 | cyclic: class-1 Lint.swift `excluding`; sequence: 1 Tests site → class-1 inspect | class-2 fix-rule (same-package + brand-newtype-owner predicate) | class-1 OR class-2 per Q2 |
| 2 | unchecked call site | 0 / 0 | 17 / 26 | cyclic: class-1 Lint.swift `excluding` (NEW addition to cardinal pattern) OR class-1 disable-with-reason at each of 43 sites per `[CONV-016]` rule message | class-2 fix-rule (`[CONV-001]` same-package use predicate); `[RULE-EXEMPT-N]`-shape candidate | class-1 OR class-2 |
| 3 | tagged extension public init | 0 / 0 | 3 / 0 | cyclic: class-1 Lint.swift `excluding` OR class-1 disable-with-reason | class-2 fix-rule (extend protocol-witness-citation-dict per `[RULE-EXEMPT-2]` to include `Tagged.init(_: Cyclic.Group.Static<N>.Element)` shape, OR add brand-newtype-owner same-package predicate) | class-1 OR class-2 |
| 4 | minimal type body | 39 / 6 | 14 / 0 | class-1 fix-source: refactor `Iterator` types to extension-pattern OR class-1 disable-with-reason at SwiftSyntax-visitor-style bottom-outs OR `[RULE-EXEMPT-7]` extension candidate for non-visitor cases | class-1 fix-source (same) — rule shape is already correct | class-1 fix-source (refactor or per-site disable) |
| 5 | compound identifier | 30 / 2 | 3 / 0 | class-1 fix-source: review per-site (Difference Hunk field names + DocC steps + cyclic-specific) | same | class-1 fix-source |
| 6 | compound type name | 3 / 49 | 0 / 4 | class-3 ambiguous: Tests `<X>Tests` pattern is ecosystem-wide test-migration backlog per `[SWIFT-TEST-002]`; 56 Tests-side sites in Wave 2 cohort | same — rule shape is correct, source is the migration backlog | class-3 (defer to test-migration sweep) |
| 7 | compound suite name | 0 / 47 | 0 / 4 | class-3 ambiguous: same as #6 | same | class-3 |
| 8 | inlinable internal access | 21 / 1 | 1 / 0 | class-1 fix-source: change to `package init` per `[PATTERN-052]` rule message | same | class-1 fix-source |
| 9 | typealiased namespace bridge | 6 / 5 | 0 / 0 | class-2 candidate per `[RULE-EXEMPT-3]` conformance-context + `[RULE-EXEMPT-5]` Protocol-sentinel — needs per-site inspection to confirm; otherwise class-1 source-rename | same | class-1 or class-2 per inspection |
| 10 | extension noncopyable constraint | 5 / 0 | 0 / 0 | class-1 fix-source: add `where Element: ~Copyable` per `[MEM-COPY-004]` rule message; OR `[RULE-EXEMPT-1]` positive-Copyable if the source has explicit `where Element: Copyable` | same | class-1 fix-source or exempt |
| 11 | callback result over throws thunk | 4 / 0 | 0 / 0 | class-1 fix-source: refactor callbacks per `[IMPL-092]` rule message (`Result<T, E>` → `() throws(E) -> T` thunk) | same | class-1 fix-source |
| 12 | namespace adoption typealias | 0 / 5 | 0 / 0 | class-1 fix-source: Tests-side bridge typealiases — review per-site | same | class-1 fix-source (Tests) |
| 13 | unification typealias | 0 / 2 | 0 / 0 | class-1 or `[RULE-EXEMPT-3]` conformance-context candidate — inspect | same | class-1 or class-2 |
| 14 | unchecked sendable categorization | 1 / 0 | 0 / 0 | class-1 fix-source: inspect site | same | class-1 fix-source |
| 15 | counter loop iteration | 1 / 0 | 0 / 0 | class-1 fix-source | same | class-1 fix-source |
| 16 | int public parameter | 0 / 0 | 0 / 1 | class-1 fix-source (Tests) | same | class-1 fix-source |
| 17 | test function naming | 0 / 0 | 0 / 1 | class-1 fix-source (Tests) | same | class-1 fix-source |
| 18 | do throws for typed catch | 0 / 0 | 0 / 1 | class-1 fix-source (Tests) | same | class-1 fix-source |

### Recommended next steps (pending orchestrator instructions)

Given the user's interruption explicitly named both the typed-accessor
and the rule-refinement direction, the conservative answer is:

1. **Q1 → option (b) typed accessor form**: the canonical form when
   typed `Lint.Rule.ID` accessors exist; retro-update cardinal/ordinal/affine
   in the same pass so the typed-bottom-out doesn't propagate. Trivial
   change once the exact accessor surface is confirmed (likely
   `Lint.Rule.<Pack>.\`<rule name>\`.id` or a typed `.rule(.\`<id>\`)`
   factory — needs one read of the rule-pack source to nail down).

2. **Q2 → option (c) hybrid**: ship cardinal-precedent for Wave 2 NOW
   (CI green on public-flipped Wave 2 unblocks downstream work), with
   a follow-on rule-refinement dispatch scheduled for Wave 3 prep.
   The refinement work itself is a separate Research → Implementation
   cycle in `swift-foundations/swift-linter-rules`. Cardinal/ordinal/affine's
   `excluding` retires when the refined rules land.

3. **Q3 → option (a) per-package override** for Wave 2 now; defer
   ecosystem-wide whitelist (Q3(b)) to the same dispatch that retires
   `excluding` ecosystem-wide.

If the orchestrator prefers Q2(b) immediately (rule-refinement now, no
cardinal-precedent shipping on Wave 2), the consequence is:

- Cyclic ships with **89 swift-linter findings still firing** on
  legitimate-by-construction sites until the rule refinement lands
- Sequence ships with **~110 sources + 56 Tests-naming findings**
- Wave 2 public-flipped CI is **red** until the rule refinement lands

If the orchestrator prefers Q2(a) cardinal-precedent only (no follow-on
refinement), the typed-bottom-out at the consumer (Q1) persists
indefinitely.

### Q-dispositions received from orchestrator (2026-05-13)

- **Q1 → typed `Lint.Rule.ID` accessors**. "Compile-enforced >
  convention-enforced. A string-literal typo silently no-ops". Retro-update
  of cardinal/ordinal/affine OUT of this dispatch's scope (queued).
- **Q2 → ship cardinal-precedent as stopgap, queue rule refinement**.
  Per-package `.excluding(rules:)` ships now to unblock the cohort; AST-
  layer rule refinement at `swift-foundations/swift-linter-rules` /
  `swift-primitives/swift-primitives-linter-rules` is the eventual
  destination, queued for follow-on. Lint.swift header explicitly notes
  the stopgap status so future readers know the trade-off.
- **Q3 → per-package `!/Lint.swift` override** matching Wave 1
  precedent. Ecosystem-wide canonical `.gitignore` template update is
  OUT of scope.
- **Brief-premise**: no SwiftLint TIGHTENs at `swift-primitives/.github`
  this dispatch (AST-rule findings only; no SwiftLint custom-rule
  fires). Nothing lands at `.github`.

### Commits landed (local; no push)

| Commit | Repo | Subject | Effect |
|---|---|---|---|
| `63561f7` | swift-sequence-primitives | `chore(lint): add Shape γ Lint.swift + .gitignore override` | Closes the swift-linter measurement gap on sequence; no rule exclusions (sequence is not a brand-newtype owner). |
| `2231766` | swift-sequence-primitives | `chore(lint): inlinable internal init → package init per [PATTERN-052]` | 22 mechanical class-1 source fixes (21 init + 1 static func backtrack) across Difference iterators, Lazy primitives, Tests Support. Closes 22/22 `inlinable internal access` findings. |
| `ed7deb7` | swift-cyclic-primitives | `chore(lint): add Shape γ Lint.swift + .gitignore override` | Brand-newtype-owner exclusion set: `raw value access`, `unchecked call site`, `tagged extension public init` via typed `Lint.Rule.<id>.id` references. Closes 90/119 findings (75.6%). Stopgap-status documented in Lint.swift header. |
| `f53bd77` | swift-cyclic-primitives | `chore(lint): fix inlinable internal init + disable int public parameter` | 2 class-1 source fixes: `package init()` on Iterator + `// swift-linter:disable:next int public parameter` on `ExpressibleByIntegerLiteral` protocol witness in Tests Support. |

Both packages: 2 commits ahead of origin. Build clean
(`swift build --build-tests`). No push (per brief's "stage but do not
push" + `[GIT-001]` private-repo authorization).

### Residual after fixes

| Package | Pre-Lint.swift | Post-Lint.swift | Post-source-fixes | Disposition of residual |
|---|---|---|---|---|
| swift-sequence-primitives | 228 (110 Sources + 118 Tests) | 228 (no exclusion applied) | **206** (closed 22 inlinable) | 49+47 = 96 test-naming class-3 (test-migration backlog); 39+6 minimal type body, 30+2 compound identifier, 4 callback Result, 5 extension noncopyable, 11 typealiased namespace bridge, etc. — class-1 fix-source items deferred (substantial refactor) and class-2 candidates per `[RULE-EXEMPT-*]` deferred for AST-rule refinement queue. |
| swift-cyclic-primitives | 119 (57 Sources + 62 Tests) | **29** (closed 90 via brand-newtype-owner exclusion) | **27** (closed 2 source-fixes) | 14 minimal type body (class-1 refactor — deferred), 4+4 compound type/suite name (test-migration class-3), 3 compound identifier, 1 test function naming, 1 do throws — deferred. |

### Out-of-scope queue (follow-on dispatches)

1. **AST-layer rule refinement at `swift-foundations/swift-linter-rules`
   + `swift-primitives/swift-primitives-linter-rules`** — refine `raw
   value access`, `unchecked call site`, `tagged extension public init`,
   `chained rawvalue access`, `int public parameter`, `pointer advanced
   by` to recognize brand-newtype-owner same-package context (likely as
   `[RULE-EXEMPT-N]` shapes per `rule-exemptions`). On landing, the
   per-package `.excluding(rules:)` in
   cardinal/ordinal/affine/cyclic Lint.swift retires ecosystem-wide.
   Blocker: linter-related repos carry uncommitted/unpushed state
   (`institute-linter-rules` 1 unpushed; `swift-linter-primitives` 5
   unpushed); AST-layer refinement is heavier than this brief's scope.
2. **Retro-update cardinal/ordinal/affine Lint.swift** from string-literal
   `excluding(rules: ["..."])` to typed `Lint.Rule.<id>.id` form
   (mirrors cyclic precedent). Small mechanical dispatch.
3. **Ecosystem-wide canonical `.gitignore` template** to whitelist
   `!/Lint.swift` (instead of per-package `LOCAL OVERRIDES`). Touches
   `swift-institute/Scripts/sync-gitignore.sh` and ripples to ~131
   primitives packages.
4. **Sequence class-1 source-fix sweep** — 39+6 minimal type body
   refactors (extension-pattern conversion), 4 callback `Result<T,E>`
   → `() throws(E) -> T` thunk migrations, 30+2 compound identifier
   review, 5 extension noncopyable constraint inspection (some likely
   false-positive per `[RULE-EXEMPT-1]` positive-Copyable shape), 11
   typealiased namespace bridge inspection (some likely
   `[RULE-EXEMPT-3]` / `[RULE-EXEMPT-5]` candidates).
5. **Cyclic class-1 source-fix sweep** — 14 minimal type body refactors,
   3 compound identifier review, 1 test function naming, 1 do throws
   for typed catch.
6. **Ecosystem-wide `[SWIFT-TEST-002]` test-naming migration** — the
   compound type name / compound suite name findings (49+47 sequence
   Tests, 4+4 cyclic Tests, plus the same pattern in cardinal/ordinal/
   affine and likely every other primitives package) reflect a
   pre-`[SWIFT-TEST-002]` test-naming convention not yet migrated. This
   is an ecosystem-wide test-migration backlog, not a per-package fix.

Sweep output logs retained at `/tmp/sequence-sweep.log`,
`/tmp/cyclic-sweep.log`, `/tmp/sequence-findings.log`,
`/tmp/cyclic-findings.log`, `/tmp/sequence-residual.log`,
`/tmp/cyclic-residual2.log` for re-examination.
