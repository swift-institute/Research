# Thread B Rule-Pack Dogfeed Triage

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

Per `HANDOFF-thread-b-rule-pack-dogfeed.md`, the three rule-pack repos
each received their own `Lint.swift` self-lint (`Bundle.universal` /
`Bundle.institute` / `Bundle.primitives`) and were dogfed against
themselves. Phase 0 closed the deferred `path: "."` self-reference
thread via CLI-boundary canonicalization (see
`Research/2026-05-12-eval-path-self-reference.md` v2.0.0 DECISION).

**Aggregate finding counts** (initial; no mechanical sweep applied):

| Pack | Total | Top rule | Second | Third |
|------|------:|----------|--------|-------|
| swift-linter-rules | 363 | minimal type body (281) | usable from inline internal import (60) | single type per file (12) |
| swift-institute-linter-rules | 111 | minimal type body (45) | compound identifier (38) | usable from inline internal import + compound type name (13 each) |
| swift-primitives-linter-rules | 25 | minimal type body (10) | compound identifier (7) | compound type name (4) |

**Total: 499 findings.** A single dominant defect class — the
SwiftSyntax visitor pattern — drives ~70 % of the aggregate volume.
Surfacing it as a Thread A-style amendment (A4) is the
highest-leverage closure for any subsequent dispatch.

---

## Triage Taxonomy

Carried verbatim from
`swift-foundations/swift-linter/Research/2026-05-12-foundation-up-dogfeed-triage.md`
(carrying the v1.1.0 disposition labels):

- **SOURCE-WRONG** — the source genuinely violates the rule's
  principled scope; mechanical fix lands inline (this dispatch or a
  later sweep).
- **RULE-WRONG** — the rule's recognizer or message-frame fires
  outside its principled scope; rule amendment is the cure.
- **DEFER-FOR-CONSISTENCY** — SOURCE-WRONG by-rule but renaming
  cascades across consumers; carry to a consolidated review.

---

## RULE-WRONG amendment threads surfaced

### A4. API-IMPL-008 vs canonical SwiftSyntax visitor pattern (~336 findings)

**Sites**: every `internal final class XVisitor: SyntaxVisitor` file
in the rule packs:
- 281 in swift-linter-rules
- 45 in swift-institute-linter-rules
- 10 in swift-primitives-linter-rules

**Defect**: the SwiftSyntax visitor pattern colocates state, init, and
`override func visit(_:)` overrides inside a `final class X:
SyntaxVisitor` body. Each visit-override fires `[API-IMPL-008]`
(minimal type body) on the function declaration. A typical rule's
visitor has 1–10 such overrides — multiplied across ~70 rule files,
that's the ~336-finding dominant tail.

The visitor pattern is structurally fixed:
1. The override functions implement a SwiftSyntax-protocol-shaped
   contract (the `SyntaxVisitor` open class's per-syntax-kind
   visitation hook). Their NAMES (`visit`, `visitPost`) and SIGNATURES
   are dictated by the parent class.
2. The state (collected matches, source converter, severity) and the
   visit logic are inseparable — moving the overrides to extensions
   yields a `final class XVisitor { /* stored properties + init */ }`
   with an extension full of override implementations for zero
   semantic gain.
3. The same `[RULE-EXEMPT-4]` rationale that broadens the carve-out
   to `@resultBuilder` and `@Suite` applies: the parent type's
   contract dictates the member shape; the rule should not fire.

**Recommended amendment shape** (parallel to A1's
`hasExtensionPatternAttribute` broadening):

Add a new `[RULE-EXEMPT-7]` (`syntax-visitor-subclass`) shape to
`rule-exemptions/SKILL.md`. Helpers:

- `structureExtendsSyntaxVisitor(_:)` — true when the class declaration
  inherits from `SyntaxVisitor` (or `SyntaxAnyVisitor`, `SyntaxRewriter`,
  the SwiftSyntax visitor family). Pack-local in
  `Lint.Rule.Structure.Shared.swift`.

In `Lint.Rule.Structure.MinimalTypeBody.visit(_ node: ClassDeclSyntax)`:

```swift
override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    if hasExtensionPatternAttribute(node.attributes) {
        return .visitChildren
    }
    if structureExtendsSyntaxVisitor(node.inheritanceClause) {
        return .visitChildren  // [RULE-EXEMPT-7]
    }
    checkMembers(node.memberBlock.members)
    return .visitChildren
}
```

**Cross-references**: [API-IMPL-008], [RULE-EXEMPT-4] (A1 precedent).

**Empirical signal**: dominates this dispatch's finding distribution.
Closing A4 cuts the rule-pack noise floor by ~70 %.

### A5. API-NAME-001 vs canonical SwiftSyntax visitor class names (17 findings)

**Sites**: visitor class names like `CardinalConstructorVisitor`,
`BitPatternVisitor`, `ChainVisitor`, `BoolParameterVisitor`,
`BoxClassVisitor`, `CompoundVisitor`, etc. — 17 sites total across
institute (13) + primitives (4) packs.

**Defect**: the canonical SwiftSyntax visitor naming convention is
`<RuleName>Visitor`. These are compound names per `[API-NAME-001]`
(`Cardinal` + `Constructor` + `Visitor`). The rule's
`package`-scope carve-out doesn't apply — these are `internal final
class` declarations, and the [API-NAME-002] visibility-scope amendment
only carves out `fileprivate` / `private`.

Two readings:

1. **SOURCE-WRONG**: rename to nested form
   (`Cardinal.Constructor.Visitor`, etc.). Heavy refactor across ~70
   rule-pack files; visitor classes are pack-internal so cascade is
   contained, but the noise-to-signal ratio is poor.
2. **RULE-WRONG**: visitor classes are pack-internal infrastructure
   (never consumer-observable). Pair with A4 to extend
   `[RULE-EXEMPT-7]` to also carve out `[API-NAME-001]` for
   SyntaxVisitor subclasses.

Recommended: amendment along with A4. The same carve-out predicate
serves both rules.

### A6. PATTERN-055 vs `internal import` of SwiftSyntax in pack files (76 findings)

**Sites**: 60 in swift-linter-rules, 13 in swift-institute-linter-rules,
3 in swift-primitives-linter-rules. Rule files that pair
`@usableFromInline internal let <messageConstant>: Swift.String` with
`internal import SwiftSyntax`.

**Defect (recognizer over-firing)**: the rule message says "file pairs
`@usableFromInline` with `internal import` of a referenced module" —
but the recognizer only checks for the presence of both, not whether
the `@usableFromInline` body actually references the
internally-imported module. In every flagged rule-pack file, the
`@usableFromInline` decl is a `Swift.String` constant (the rule's
message) that does NOT reference SwiftSyntax. The visitor class that
DOES reference SwiftSyntax is plain `internal final class`, no
`@usableFromInline`.

**Recommended amendment**: tighten the recognizer to require the
`@usableFromInline` body actually reach into the internally-imported
module. Until that lands, the alternative SOURCE-WRONG path
(`internal import SwiftSyntax` → `package import SwiftSyntax` for
each rule-pack file) is mechanical but a) increases the per-file diff
volume by ~76 lines and b) couples access semantics to a rule-recognizer
gap rather than to a real visibility need.

### A7. API-IMPL-008 vs case-only enums with raw value (1 finding from prior session, 1 here)

**Sites**: limited evidence in this dispatch (a couple of `enum X:
Swift.String` cases that fire on the case-decl line via a different
code path). Not material at this scale; carry to A2-style amendment
review.

### A8. Existing A1/A2 deferred shapes resurface here

Counted in the totals but already characterized in the prior triage:

- `compound suite name` (4 in linter-rules) — likely SOURCE-WRONG via
  inner-name nested-extension restructure (Thread A's A3 disposition).
- `raw value access` (1 each in linter-rules + institute) — same
  shapes as Thread A's A2 deferred items (local-var enum receivers
  and SwiftSyntax `.position` false-positives). Sample sizes too
  small to justify Thread B-specific re-triage.
- `single type per file` (12 in linter-rules, 1 each in institute +
  primitives) — SOURCE-WRONG via file split (mechanical but each
  site needs inspection). Carry to consolidated structure-pack
  cleanup.

---

## SOURCE-WRONG categories landed inline

**None this dispatch.** The dominant defect classes (A4, A5, A6) are
all RULE-WRONG; the remaining tail is single-digit-finding categories
that benefit from per-site inspection rather than mechanical sweep.
Per the brief's "no source-surface API renames inline beyond safe
mechanical shapes" constraint and the "single commit per pack" rule,
no Phase 4 commit lands per pack.

---

## DEFER-FOR-CONSISTENCY

- **`compound identifier` on `naming*Helper` prefix-disambiguation
  helpers** (38 in institute-pack `Naming.Shared.swift` and
  per-naming-rule files; ~7 in primitives pack `RawValue.Shared.swift`).
  These are pack-internal helpers prefixed with the pack name
  (`naming...`, `structureXxx`, `rawValue...`) for cross-rule
  disambiguation. The compound-name carve-out for `package`-scope
  declarations doesn't apply (they're internal). Renaming would push
  toward an enum-namespaced shape (`Naming.Shared.isInsideExtensionPatternType`)
  — significant refactor, deferred to consolidated naming-helper
  review.

- **`compound type name` on visitor class names** (already covered by
  A5 above; also classifies as DEFER-FOR-CONSISTENCY pending the A4/A5
  amendment outcome).

- **`compound identifier` on rule pack public API** (limited
  occurrences) — fold into the swift-linter compound-identifier sweep
  (Thread D candidate).

---

## Recommended Disposition Sequence

### Next dispatch (Thread C — high-leverage rule amendments)

1. **A4 + A5 combined amendment** — add `[RULE-EXEMPT-7]`
   (`syntax-visitor-subclass`) to `rule-exemptions/SKILL.md`. Implement
   the carve-out predicate in `Lint.Rule.Structure.Shared.swift` and
   `Lint.Rule.Naming.Shared.swift`. Wire into
   `MinimalTypeBody.visit(_ node: ClassDeclSyntax)` and
   `[API-NAME-001]`'s class-decl visitor. Closes ~353 findings
   (A4 ~336 + A5 17).
2. **A6 amendment** — tighten `PATTERN-055` recognizer to require
   actual reference from the `@usableFromInline` body to the
   internally-imported module. Closes ~76 findings.

After landing Thread C, re-run rule-pack dogfeed. Expected residue:
~70 findings split across the smaller categories (compound suite
name, single type per file, sparse compound identifier on public
API). That tail is small enough for in-place mechanical sweep per
pack.

### Subsequent dispatches

- **Thread D**: typed-throws sweep on swift-linter (carries the
  `untyped throws` + `do throws for typed catch` + `try optional`
  bulk surfaced in the foundation-up dogfeed; matches the existing
  cross-repo `typed-throws-conversion.md` arc).
- **Thread E**: consolidated compound-identifier sweep across rule
  packs + swift-linter (after A4/A5 amendments shrink the
  noise floor).

---

## Cross-references

- `swift-foundations/swift-linter/Research/2026-05-12-foundation-up-dogfeed-triage.md`
  v1.0.0 — Thread A precedent and taxonomy source.
- `swift-foundations/swift-linter/Research/2026-05-12-eval-path-self-reference.md`
  v2.0.0 DECISION — Phase 0 self-reference fix that unblocked this
  dispatch.
- `swift-institute/Skills/rule-exemptions/SKILL.md` —
  `[RULE-EXEMPT-4]` (Thread A's broadening) is the precedent for the
  new `[RULE-EXEMPT-7]` shape recommended in A4.
- HANDOFF-thread-b-rule-pack-dogfeed.md — this dispatch's brief.
