# Validation receipt: [CONV-015] `tagged unchecked with typed alternative`
Date: 2026-07-07
Rule: tagged unchecked with typed alternative (primitives tier, RawValue pack)
Task: item-4 resolution (a), principal ruling 2026-07-07 — promote swift-tagged-primitives' nested `Lint/` PoC rule (`Lint.Rule.TaggedDomainAudit`, architecture cohort Phase A) to the fleet; retire the nested `Lint/`.

## Port fidelity

- Rule id, predicate (FunctionCallExpr with callee `Tagged` bare / generic-specialized / member-accessed + `_unchecked` label), and the `map`/`retag`/`@Test` structural exemptions ported verbatim.
- The PoC's `Tagged_Primitives` import + `taggedDomainAuditAnchor` are intentionally DROPPED: they existed to prove the nested-package mechanism links a domain dep into the rule's compile graph. The predicate is purely syntactic; a shared-pack dependency on swift-tagged-primitives would invert the rules-repo dependency posture.
- Message re-cited from PoC prose to `[CONV-015]` (conversions skill — retag/map first, unchecked last resort; this rule enforces the tier-5 slice).

## Unit suite (16/16 pass, 6.3.2)

Fire (Unit, 5): generic-specialized; bare `Tagged(_unchecked:)`; module-qualified `Tagged_Primitives.Tagged`; multiple sites (3); non-exempt enclosing function.

No-fire (Edge Case, 11): no `_unchecked`; non-Tagged callee; `self.init(_unchecked:)` in Tagged extension; `__unchecked` (double underscore — the Index/Cyclic spelling, out of scope); empty file; string literal; **doc-comment call example (the fleet's only pre-promotion mention, `swift-linter-primitives Lint.Rule.Bundle.swift:45`, is trivia — coordinator validation warning #2)**; **`map` exemption (real Tagged.swift:238 shape)**; **`retag` exemption (real Tagged.swift:256 shape)**; `@Test`; `@Testing.Test`.

## Prebuilt-binary fleet validation (Bundle.primitives, eval pins verified)

Eval graph pinned: swift-primitives-linter-rules `1188993` (this rule), swift-institute-linter-rules `27aacc9` (incl. same-day phantom Shape-1 FP fix), swift-linter-rules `8caab56`.

| Target | Expectation | `tagged unchecked` findings | Verdict |
|--------|-------------|------------------------------|---------|
| swift-tagged-primitives | fire where genuine (Sources map/retag + literal-conformance `self.init` exempt/out-of-scope by design) | PENDING | PENDING |
| swift-linter-primitives | 0 — only mention is the Bundle.swift:45 doc example (trivia) | PENDING | PENDING |
| swift-cardinal-primitives | 0 — zero `_unchecked` call sites (grep census) | PENDING | PENDING |

## Side-finding fixed pre-run: phantom suppression Shape-1 FP class

Running Bundle.primitives on swift-tagged-primitives would have surfaced 3 `phantom suppression` FPs unrelated to this promotion (Tagged.swift:225/:262 `Underlying: ~Copyable`, :116 `Underlying: Escapable & ~Copyable` — STORED param, not phantom). Shape 1 now matches only the wrapper's phantom parameter name (Tagged/Property → `Tag`, Index → `Element`). Fixed + regression-tested in swift-institute-linter-rules `27aacc9` before this validation run, so the matrix below is uncontaminated.

## Disposition

PENDING binary matrix.
