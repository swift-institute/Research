# swift-linter Per-Finding Disable Mechanism — Design Proposal

<!--
---
version: 1.0.0
last_updated: 2026-05-11
status: RECOMMENDATION
---
-->

## Context

The current swift-linter engine has no per-finding suppression
mechanism. When a rule fires on a code shape that is a genuine
institute escape hatch (the rule's premise applies to most consumer
code, but the specific site has a documented reason to deviate), the
consumer has two options:

- Live with the noise — the finding stays in every aggregate report.
- Wait for a rule amendment — the rule itself grows an exemption
  carve-out, eventually closing the case as a false-positive.

Both options are insufficient for the canonical case surfaced by
HANDOFF Wave 3 Open Q2:

- `Ownership.Slot.Move.swift:51` and `Ownership.Slot.Move.swift:59`
  fire `unchecked_call_site`. These are the `Slot.Move.in` /
  `Slot.Move.out` trapping-form public APIs that delegate to the
  `__unchecked:` overloads per [CONV-016] / [CONV-001] same-package
  use. The pattern is the canonical bottom-out: the trapping form's
  ENTIRE purpose is to call the unchecked overload after validating
  the precondition. A rule amendment carving the entire pattern is
  the wrong shape (the rule is correct for consumer-facing code;
  only specific same-package bottom-out delegators are exempt).

The current rule's message references `// swiftlint:disable:next`,
but this is SwiftLint syntax — swift-linter doesn't recognize it.
The message is therefore misleading: it tells consumers how to
suppress that doesn't work.

Empirical context: 40 packages across the swift-primitives ecosystem
use `// swiftlint:disable:next` comments today, against the SwiftLint
custom rules layer (`.swiftlint.yml` in `swift-institute/.github/`).
These work because SwiftLint's engine recognizes its own syntax. The
AST-rule layer (swift-linter / Lint.Rule.*) does NOT recognize any
disable mechanism today.

## Question

**What protocol should swift-linter use for per-finding disable
directives — line-comment, attribute, config entry, or some hybrid?**

Sub-questions:

1. What is the suppression *scope* — single-line, single-finding-id,
   block, file, package?
2. Where does the directive *live* — inline next to the suppressed
   line, in a separate config file, both?
3. What is the *recognition discipline* — must the directive name the
   exact rule ID? Must it justify the suppression with prose?
4. How does the engine *audit* suppressions to prevent silent drift
   (e.g., a disable that no longer fires)?

## Analysis

### Option A — Line-comment protocol (mirror SwiftLint syntax)

The engine recognizes `// swift-linter:disable:next <rule-id>` (and
`// swift-linter:disable:line <rule-id>`) inline comments. The
comment SHOULD include a `// REASON: ...` continuation line citing
the institute-side justification.

Example:
```swift
// swift-linter:disable:next unchecked_call_site
// REASON: Slot.Move.in is the trapping public API delegating to the
//   __unchecked: overload after precondition check ([CONV-016]).
public func in(_ value: consuming Value) {
    self.__unchecked.in(value)
}
```

**Pros**:
- Mirrors SwiftLint's `// swiftlint:disable:next` syntax — minimal
  cognitive load for consumers already familiar with SwiftLint
  conventions. The 40 packages with existing `// swiftlint:disable`
  comments would adopt the new directive via mechanical search-replace.
- Inline-with-code: the justification lives where the suppression
  applies. Reviewers see both at once.
- The `// REASON:` continuation naturally supports skill-rule
  citation and prose justification.
- Engine implementation is straightforward — the lexer-level
  TriviaSyntax already carries `LineComment` tokens; the engine
  parses these for `swift-linter:disable*` directives.

**Cons**:
- Yet another comment syntax. Mixed-engine projects (SwiftLint
  custom rules + swift-linter AST rules) now have two parallel
  systems: `// swiftlint:disable:next foo` for SwiftLint rules and
  `// swift-linter:disable:next foo` for swift-linter rules. The
  asymmetry is jarring; consumers need to know which engine governs
  a given rule.
- Inline comments are mutable text. Renaming a rule ID requires
  ecosystem-wide search-replace; missing one leaves an orphan
  disable that no longer suppresses anything (silent failure mode).

### Option B — Attribute-based protocol (`@swiftLinterDisable`)

The engine recognizes a custom attribute (e.g.,
`@swiftLinterDisable(rule: "unchecked_call_site", reason: "...")`)
on the disabled declaration.

Example:
```swift
@swiftLinterDisable(rule: "unchecked_call_site",
                    reason: "Slot.Move.in is the trapping public API delegating to __unchecked: per [CONV-016]")
public func in(_ value: consuming Value) {
    self.__unchecked.in(value)
}
```

**Pros**:
- First-class language object — the attribute is structured,
  machine-parseable, queryable via SwiftSyntax.
- Naturally attaches to declarations (function, property, type) —
  matches the scope of a per-decl finding.
- The `rule:` and `reason:` parameters are mandatory; consumers
  cannot disable without citing a reason.

**Cons**:
- Custom attributes in Swift require either compiler-level support
  (macro / runtime metadata) or community convention. The
  `@swiftLinterDisable` would be a community-convention attribute
  the compiler doesn't understand — Swift emits a warning ("unknown
  attribute"), which can be suppressed with `@_silgen_name`-style
  hacks but is generally fragile.
- Attribute can only attach to declarations (or expressions, with
  expression-attribute syntax that's still experimental). Fine-
  grained line-level suppression (a single offending statement
  inside a function body) requires either restructuring the code or
  scoping the attribute to the enclosing decl.
- More verbose than line comments — and the verbosity scales with
  reason length.

### Option C — Config-file protocol (`.swift-linter.yml` entries)

The engine reads a project-level config file (e.g.,
`.swift-linter.yml`) with a `disabled_findings:` section listing
per-finding suppressions by file path + line.

Example (`.swift-linter.yml`):
```yaml
disabled_findings:
  - file: swift-ownership-primitives/Sources/.../Slot.Move.swift
    line: 51
    rule: unchecked_call_site
    reason: |
      Slot.Move.in is the trapping public API delegating to the
      __unchecked: overload after precondition check ([CONV-016]).
  - file: swift-ownership-primitives/Sources/.../Slot.Move.swift
    line: 59
    rule: unchecked_call_site
    reason: |
      Slot.Move.out — same delegation pattern.
```

**Pros**:
- All disables enumerated in one place — easy to audit, easy to grep
  for "what's currently suppressed?"
- Separation of concerns: source code stays clean, suppression
  policy lives in config.
- Config-as-code: the suppression list is version-controlled with the
  project, reviewable via PRs that touch the config file specifically.

**Cons**:
- Suppression location drifts from the suppressed line as the file
  changes — a refactor that moves the trapping `Slot.Move.in` from
  line 51 to line 53 silently breaks the disable. The mechanism
  needs file:line-anchor maintenance.
- The reason lives away from the suppressed code; reviewers reading
  the source don't see the justification without flipping to the
  config file.
- Project-level config doesn't compose well across vendored packages
  — a primitives package's `.swift-linter.yml` doesn't apply when
  the package is consumed downstream.

### Option D — Hybrid (Option A primary; Option C for project-level overrides)

Adopt line-comment protocol (Option A) as the primary per-finding
mechanism; allow config-file overrides (Option C) for project-level
rule disables (entire rule disabled for a target/package, not per-
line). The two layers serve different needs:

- Per-line: inline comment with reason.
- Per-target / per-package: config entry that disables a rule
  entirely for a scoped target.

The config entry mechanism is already present (the engine has rule
configuration scaffolding for severity, includes/excludes); per-
target rule disable extends it.

**Pros**:
- Composable: each layer addresses a different scope (line vs. rule-
  wide).
- Migration-friendly: the 40 existing `// swiftlint:disable:next`
  sites adopt the new line-comment syntax mechanically; project-
  level rule disables move to the config file.
- The reason discipline ([RES-022]-style) is anchored at the line-
  comment layer (`// REASON: ...`); the config-file layer doesn't
  need it because rule-wide disables are policy decisions, not
  pointed escape hatches.

**Cons**:
- Two mechanisms = two places to look when investigating a missing
  finding. The audit/observability tooling has to consult both.
- More implementation surface than a single-mechanism choice.

### Comparison Matrix

| Criterion | A: line-comment | B: attribute | C: config-file | D: hybrid (A + C) |
|-----------|-----------------|--------------|----------------|-------------------|
| Inline with code | Yes | Yes | No | Yes (line) / No (config) |
| Mirrors SwiftLint syntax | Yes | No | No | Yes |
| Mandatory reason | Convention | Yes (param) | Convention | Convention (line) |
| Engine implementation surface | Small (lexer trivia) | Large (attribute parsing + warnings) | Medium (YAML reader) | Medium |
| Fine-grained scope | Yes (line) | Decl-level | File:line | Yes |
| Auditable suppression list | Distributed | Distributed | Centralized | Both |
| Drift resilience (line/file changes) | Comment moves with code | Attribute moves with decl | Brittle (file:line anchor) | Mixed |
| Mixed-engine cognitive load | High (vs. SwiftLint) | High | High | High |

## Outcome

**Status**: RECOMMENDATION — four options surfaced; decision pending.

Provisional lean: **Option D — hybrid (line-comment primary +
config-file for rule-wide)**.

The argument is composability: per-line escape hatches and per-
target rule disables are categorically different problems. Option A
alone solves the canonical case (HANDOFF Open Q2's two
`unchecked_call_site` sites on Slot.Move) but doesn't address the
project-level case ("disable rule X entirely for benchmarks/"). Option
C alone forces every per-line escape hatch into a config file far
from the source. Option D admits both, with the line-comment as the
primary path consumers see most often.

Option B (custom attribute) is rejected: the compiler-warning
friction outweighs the structured-parameter benefits, and the decl-
level scope is wrong for line-level findings inside function bodies.

If Option D is approved, the implementation plan is:

1. **Engine update** (swift-foundations/swift-linter Sources):
   - Lexer-level scan of `TriviaSyntax` for `swift-linter:disable*`
     directives.
   - Recognized forms:
     - `// swift-linter:disable:next <rule-id>` — next non-blank line.
     - `// swift-linter:disable:line <rule-id>` — same line (trailing
       comment).
     - Optional `// REASON: <prose>` continuation; recommended but
       not required at engine level (a separate audit rule could
       require it).
   - Engine maintains a suppression map: `(filepath, line, rule-id) → reason`.
   - When a finding fires, the engine consults the map and elides
     suppressed findings.
   - Suppressed findings are logged separately (for the meta-audit
     that detects orphan suppressions).

2. **Config-file update** (`.swift-linter.yml` reader):
   - `disabled_rules:` section listing rule IDs disabled for a
     target/package.
   - Optional per-target overrides via target-scoped config (already
     scaffolded in the engine's existing rule-config plumbing).

3. **Rule message update**:
   - Update the `unchecked_call_site` rule's message to reference
     `// swift-linter:disable:next unchecked_call_site` (not
     `// swiftlint:disable:next`).
   - Audit all rule messages for stale `// swiftlint:` references
     and update.

4. **Migration** (per-package commits, only when the rule fires on
   a legitimate escape hatch):
   - swift-ownership-primitives: 2 `unchecked_call_site` sites on
     Slot.Move.swift:51, :59 — add `// swift-linter:disable:next
     unchecked_call_site` with REASON citing [CONV-016].
   - Other packages: as findings surface and turn out to be genuine
     escape hatches.

5. **Meta-audit rule** (future, separate dispatch):
   - A rule that scans for `// swift-linter:disable:*` directives that
     no longer suppress anything (the underlying rule didn't fire
     during the most recent lint run on that line). Surfaces orphan
     suppressions as warnings to clean up.

## Empirical Notes

The 40 existing `// swiftlint:disable:next` sites in
swift-primitives are all on legitimate institute exceptions (force_try
on AsciiSerializable bottom-out parsers, chained_rawvalue_access on
typed-Ordinal-arithmetic primitives, etc.). Adopting Option D would
mechanically migrate these via search-replace, with the engine then
recognizing the new directive form.

The Option D engine implementation surface is roughly:

- ~100 lines of lexer-trivia scanning + suppression-map maintenance.
- ~50 lines of YAML config-file `disabled_rules:` section reader.
- ~10 lines of message text updates per rule that references the
  disable syntax (mostly `unchecked_call_site`,
  `unsafe_assignment_granularity`, others as catalogued).

A pilot can implement just Option A (line-comment) first; Option C
config layer can be a follow-up addition without breaking compatibility.

## References

- HANDOFF.md Wave 3 §8 + Open Q2 (the surfacing dispatch)
- `swift-primitives/swift-ownership-primitives` commit b475d6f body, "2 unchecked call site" residual (Slot.Move.swift:51, :59)
- `swift-foundations/swift-linter-rules/Sources/Linter Rule Unchecked/Lint.Rule.Unchecked.swift` (the rule whose message references the missing syntax)
- SwiftLint syntax reference (existing 40-site precedent): `// swiftlint:disable:next` semantics
- `swift-institute/Skills/conversions/SKILL.md` [CONV-016] / [CONV-001] (the institute-side same-package-use convention motivating the canonical escape hatch)
