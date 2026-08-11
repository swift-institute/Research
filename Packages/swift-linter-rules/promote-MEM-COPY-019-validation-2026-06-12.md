# Validation receipt: [MEM-COPY-019]
Date: 2026-06-12
Rule: clone-less box
Placement tier: primitives (pack: Primitives Linter Rule Tower)
Detection method: test-target validation harness (.docc-excluded per the pilot-1 lesson) +
HISTORICAL ground-truth calibration (the pre-fix shape from git history).

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged/carrier/pair-primitives | 0/0/0 | clean |
| Medium | swift-property/cardinal-primitives | 0/0 | clean |
| Hard | swift-affine/ordinal-primitives | 0/0 | clean |
| Tower probe | all 27 tower packages | 0 | the c51d879/d1e3110 fixes hold; no other clone-less-box site exists |

Hard-level budget ([PROMOTE-004]): 0 ≤ 10 ✓. Zero-count is the expected steady state
(future-prevention; the regression class is fix-locked) — per the skill's anti-pattern note,
not a weak-rule signal.

## Historical calibration (live FAIL ground truth)

The REAL pre-fix `Dictionary+Columns.swift` (extracted from `c51d879^`) fires **exactly 1
finding at line 239** — the precise line the rule body's defect-class paragraph cites. The
post-fix tree is silent. Detection note of record: raw (unfolded) parse trees carry `a = b`
as `SequenceExprSyntax`; the finder matches BOTH the folded `InfixOperatorExprSyntax` shape
and the raw 3-element sequence shape (the initial folded-only finder detected nothing — the
fixture suite caught it).
