# Numerics Linter Secondary Rule Defects

<!--
---
version: 1.1.0
last_updated: 2026-05-12
status: DECISION
---
-->

## Changelog

- **v1.1.0 (2026-05-12) — DECISION.** All four defects closed via the
  amendments outlined in v1.0.0's Summary Disposition Table.
  Per-defect closure SHAs:
  - PATTERN-019 (generic-Tag premise gap) — `swift-primitives-linter-rules` commit `c19f862` (recognizer + 4 tests, 18/18 pass)
  - PATTERN-020 (stdlib-bridge inversion) — `swift-linter-rules` commit `ba8b750` (lax-type allowlist + 3 tests, 6/6 pass)
  - IMPL-109 3a (typed-throws conflation) — `swift-linter-rules` commit `1e02181` (typed-throws-closure skip)
  - IMPL-109 3b (own-fix fires) — `swift-linter-rules` commit `1e02181` (reuse `throwsClosureTryIsInsideMaterializingDoCatch` helper)
  IMPL-109's 4 tests landed in the same commit (13/13 pass).
- **v1.0.0 (2026-05-12)** — RECOMMENDATION. Triage from Agent A
  SOURCE-WRONG sweep.

## Context

The numerics-rule-recognizer Tier-2 research at
[numerics-rule-recognizer-2026-05-12.md](numerics-rule-recognizer-2026-05-12.md)
covered four rules (PATTERN-017, CONV-016, IMPL-010, IMPL-011) whose
~189 hits in the numerics linter report stem from a single shared
defect class: the AST-only visitor cannot recognize "this code is
inside the brand-newtype's own implementing package" without engine
cooperation. Option 1 (package-scoped admission with brand-types
declared in `.swift-linter.json`) is currently being implemented.

A parallel SOURCE-WRONG sweep (Agent A dispatch, 2026-05-12) on the
remaining ~40 findings surfaced **three additional rule-defect classes**
that are NOT the same shape as the recognizer gap and therefore are
not closed by Option 1. Two cheap allowlist additions (API-NAME-002,
MEM-COPY-004 qualified-name lookup) were applied directly; the
remaining three need rule-amendment thought.

## The Three Defects

### Defect 1 — PATTERN-019: generic-Tag domain extension premise gap

**Rule body**: `[PATTERN-019]` (Tagged extension public init) requires
validation factories to live at the tag owner's type (i.e., on the
specific `Tag` whose invariants govern the construction). The rule's
"validation gate at tag owner" cure is the recommended remediation.

**Defect**: when the extension is generic over `Tag`
(`extension Tagged where Underlying == X`), the tag-owner cure is
*structurally inexpressible* — there's no specific tag whose type-scope
the factory can move into.

**Empirical signal**: 11 hits in the numerics packages, all on
generic-Tag domain extensions:

- swift-ordinal-primitives: `Tagged+Ordinal.swift:34`
- swift-cardinal-primitives: `Tagged+Cardinal.swift:22,31`
- swift-affine-primitives: `Tagged+Affine.swift:87,97,110,125,157,195,209`

**Source treatment options** (none are mechanical):

1. Move every typed-conversion factory to `Cardinal` / `Ordinal` /
   `Vector` themselves (cross-package API surgery — large refactor).
2. Accept the inversion: the rule has no principled cure for the
   generic-`Tag` shape, so the rule should not fire there. Amend
   PATTERN-019 to exclude `extension Tagged where Underlying == X`
   when the init constructs a `Tagged<Tag, X>` value generically over
   `Tag`.

(2) is structurally cleaner. The rule's intent (validation gate at
tag owner) presupposes a known tag; generic-`Tag` extensions are
outside the rule's principled scope.

**Recommended disposition**: rule amendment, Option (2). Adds an AST
recognizer: `extension Tagged where Underlying == <T>` with a generic
`Tag` parameter falls outside the rule.

---

### Defect 2 — PATTERN-020: wrapper-stricter-invariant premise inversion

**Rule body**: `[PATTERN-020]` (throwing wrapper init) requires the
throwing init to live on the wrapper type that specializes the
stricter invariant. For example, `Cardinal.init(throwing: Int)`
should be on `Cardinal` (the stricter type), not on `Int` (the lax
type).

**Defect**: when the extension is on a stdlib type like `Int`
(specifically `Tagged+Ordinal.swift:50`, `Tagged+Cardinal.swift:41`),
`Int` is not a *wrapper* of `Tagged<Tag, X>` — the premise is inverted.
The author IS placing the factory on the appropriate stricter type
(the institute Tagged form); the rule misreads the relationship.

**Empirical signal**: 2 hits.

**Recommended disposition**: rule amendment. Add an AST recognizer:
when the extension is on a stdlib bridge type (Int, UInt, Float, etc.)
and the throwing init returns an institute Tagged form, the
wrapper-vs-source relationship is the institute side, not the stdlib
side. The rule should fire only when the extension is on the *lax*
type AND returns a *stricter* type within the same domain.

---

### Defect 3 — IMPL-109: rethrows-result-shim, two independent visitor bugs

**Rule body**: `[IMPL-109]` (result wrapper for rethrows shim) requires
that `try` inside stdlib `rethrows` higher-order methods is adapted
via the `Result<T, E>` shim. The prescribed fix shape: materialize
`Result` inside the closure, return it, `try result.get()` outside.

#### Bug 3a — name-based walker conflates typed-throws with rethrows

**Source**: `Lint.Rule.Throws.RethrowsResultShim.swift:84-86`:

```swift
override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    guard let name = calledMemberName(node.calledExpression) else { return .visitChildren }
    guard rethrowsMethodNames.contains(name) else { return .visitChildren }
    ...
}
```

The walker matches any function literally named `map` / `compactMap` /
`flatMap` / `filter` / `forEach` / `reduce` / etc. The institute's
`Tagged.map` uses typed throws (`func map<U>(_:) throws(E) -> Tagged<Tag, U>`),
not stdlib `rethrows`. The rule has no way to tell from the call site
which one is being invoked.

**Empirical signal**: 3 of 4 IMPL-109 hits fire on `Tagged.map`
(typed throws), not on stdlib `Array.map` (rethrows).

**Source treatment**: an AST-only fix is achievable. If the closure
argument has an explicit typed-throws clause (`throws(E)`) on its
effects specifier, the call site cannot be stdlib `rethrows` form
(stdlib `rethrows` accepts only untyped-throws closures). The visitor
can check the closure's `signature.effectSpecifiers.throwsClause`
syntax: if a typed-throws specifier is present, skip.

A fully-typed fix would require receiver-type resolution
(SourceKit-LSP), but the AST-only heuristic catches the dominant case.

#### Bug 3b — the rule's own prescribed fix shape still fires

**Source**: `Lint.Rule.Throws.RethrowsResultShim.swift:46-62`
(the `ThrowsRethrowsTryFinder`):

```swift
private final class ThrowsRethrowsTryFinder: SyntaxVisitor {
    var positions: [AbsolutePosition] = []
    var closureDepth: Swift.Int = -1
    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        if node.questionOrExclamationMark == nil {
            positions.append(node.tryKeyword.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }
    ...
}
```

The finder records *every* `try` keyword at `closureDepth == 0`
(the rethrows-closure's own scope). The prescribed remediation:

```swift
arr.map { element in
    do {
        return Result<T, E>.success(try typedFunc(element))  // try at closureDepth 0
    } catch let error as E {
        return .failure(error)
    }
}
```

The `try typedFunc(element)` is at the rethrows-closure's own scope
(the `do` block is not a closure, just a statement). The finder
reports it — the rule fires on its own prescribed fix.

**Source treatment**: the finder needs a `do/catch`-context check.
When walking inside the rethrows-closure body, descending into a
`DoStmtSyntax` whose `catchClauses` are non-empty AND whose try-target
error type matches the catch's pattern type should suppress the
`try` keyword. Simpler heuristic: any `try` inside `DoStmtSyntax.body`
where the parent has at least one `CatchClauseSyntax` is admitted.

The simpler heuristic over-admits (someone could write `do { try x() } catch {}`
that doesn't materialise to `Result`), but the over-admission is on the
remediation-shape side, not the bug-detection side — false negatives are
less harmful than the current self-defeating false positives.

**Empirical signal**: 1 hit on `Range.map` (true rethrows form) — the
prescribed fix was applied at the site and the rule still fires.

**Recommended disposition** (combined): both visitor bugs are rule-
implementation defects, not framing issues. Both have AST-only fixes
of <30 LOC each. Surface as separate fix dispatches; the simpler
remediation is Bug 3b's `do/catch` admit, since it unblocks the
existing rule-prescribed pattern. Bug 3a's typed-throws-closure
detection is the dominant volume cut.

---

## Summary Disposition Table

| Defect | Class | Hits | Disposition | Est. cost |
|--------|-------|-----:|-------------|-----------|
| PATTERN-019 generic-Tag | rule premise gap | 11 | Rule amendment: skip `extension Tagged where Underlying == X` with generic `Tag` | <50 LOC + ~5 tests |
| PATTERN-020 stdlib-bridge inversion | rule premise inversion | 2 | Rule amendment: fire only when extension target is the *lax* type | <30 LOC + ~3 tests |
| IMPL-109 (3a) typed-throws | visitor name-only | ~3 of 4 | Visitor amendment: skip when closure has typed-throws effect specifier | <20 LOC + ~3 tests |
| IMPL-109 (3b) own-fix-fires | visitor over-fires | ~1 of 4 | Visitor amendment: admit `try` inside `DoStmtSyntax` with catches | <20 LOC + ~3 tests |

**Total estimated work**: 4 rule-source amendments + ~14 tests +
empirical re-validation. None require Tier-2 research — all are
contained-scope rule amendments with clear remediation paths.

## Dispatch Recommendation

These four defects are independently dispatchable. Two reasonable
groupings:

**A. Single combined dispatch** (one agent, one ledger entry): all
four rule amendments in one pass, since they share AST-visitor
mechanics and would benefit from one re-validation run.

**B. Two dispatches**:

- IMPL-109 fix (3a + 3b): bug — the rule contradicts its own
  remediation. Fix first to unblock authors hitting the existing
  rule.
- PATTERN-019 + PATTERN-020: rule-amendment with mild rationale; can
  follow once the recognizer (Option 1) lands so the rule-pack is in
  one stable state per merge.

Grouping (B) is cleaner if Option 1's wave can land independently;
grouping (A) is cheaper if the four amendments can ride alongside
Option 1 in one ledger entry.

## Cross-references

- [numerics-rule-recognizer-2026-05-12.md](numerics-rule-recognizer-2026-05-12.md) — Tier 2 RECOMMENDATION for the recognizer gap (PATTERN-017 / CONV-016 / IMPL-010 / IMPL-011)
- [wave-3-aggregate-2026-05-11.md](wave-3-aggregate-2026-05-11.md) v1.5.0 — Wave 3/4 ledger
- Agent A dispatch report (2026-05-12) — SOURCE-WRONG sweep that surfaced these defect classes
- `Lint.Rule.Throws.RethrowsResultShim.swift` (IMPL-109 source)
- `Lint.Rule.Structure.ThrowingWrapperInit.swift` (PATTERN-020 source — needs verification of exact file)
- `Lint.Rule.Naming.Compound.swift` (API-NAME-002 source, allowlist edit landed 2026-05-12)
- `Lint.Rule.Memory.ExtensionNoncopyableConstraint.swift` (MEM-COPY-004 source, qualified-name edit landed 2026-05-12)
