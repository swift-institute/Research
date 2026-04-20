# `swift-text-primitives` + `swift-token-primitives` + `swift-lexer-primitives` Merge

**Status**: DEFERRED (out-of-scope for string-correction cycle)
**Decision context**: string-primitives correction cycle (2026-04-18), disagreement Δ4
**Revisit trigger**: a separate ecosystem-modularization-cycle dedicated to L1 lexing-family decomposition

---

## The proposal (modularization perspective)

Merge three single-target L1 packages into one `swift-lexing-primitives` package with three internal targets:
- `Text Primitives Core` — position/offset/range vocabulary (`Text.Position`, `Text.Line.Map`, etc.)
- `Token Primitives` — depends on Text Core; provides `Token`, `Token.Kind`, `Token.Keyword`
- `Lexer Primitives` — depends on Text Core + Token; provides `Lexer.Scanner`, `Lexer.Lexeme`, `Lexer.Trivia`

Rationale: the three packages share one semantic domain ("lexical analysis of byte streams") and their types always co-occur in production use:
- `Token` embeds `Text.Range`
- `Lexer.Scanner` operates over `Span<UInt8>` and tracks position via `Text.Location.Tracker`

Per `[MOD-008]` "concern SHOULD NOT be a separate target when it always co-occurs with another target" — and the criterion for separate *packages* is strictly more demanding than for separate *targets*.

## Why deferred

The merge is sound modularization but **tangential to the string family**:
- Per Q3/Q11 in the model, `swift-text-primitives` is "byte-position family" not "string family" — the rename of these packages doesn't change anything string-shaped
- Touching three L1 packages' SwiftPM identity (rename, dependency-chain rewrite) is a meaningful migration cost across consumers
- The string-correction cycle's goal is to fix string-type concerns; bundling a tangential modularization change risks scope creep

## Recommended path forward

If pursued, it should be its own ecosystem cycle ("L1 lexing-family modularization cycle") with:
1. Dedicated handoff (`HANDOFF-lexing-primitives-merge.md`)
2. Phase 1 model of all consumers
3. Wave 0 cross-package equivalence tests (lexer output before/after)
4. Phase 7 waves: dep-chain rewrite per consumer, package-identity rewrite, repo-rename, archive of old packages

Or simpler: don't merge. The three packages are tiny, build cleanly, and their separation reflects a real conceptual decomposition (positioning vs tokens vs scanning). Modularization rules permit but don't require the merge.

## Related

- Q3, Q8, Q11 in `string-type-ecosystem-model.md`
- Modularization perspective full position: synthesis output (in conversation history)
- Implementation perspective Q11: classifies `swift-text-primitives` as "byte-position family", not string family

## Files that would change if pursued

- New repo `swift-primitives/swift-lexing-primitives/` with `Package.swift` declaring 3 internal targets
- DELETE three repos: `swift-text-primitives`, `swift-token-primitives`, `swift-lexer-primitives`
- Every Package.swift across the ecosystem that depends on any of the three (~dozens; needs a grep audit)
