# Validation receipt: [LINT-SUPPRESS-001]
Date: 2026-07-07
Rule: malformed suppression directive
Placement tier: universal
Detection method: regex pre-scan (future-prevention rule, expected count ~0 — [API-NAME-010a] precedent), plus unit-test firing-power proof.

## Validation ladder (graduated packages)

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 | clean |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | clean |
| Hard | swift-ordinal-primitives | 0 | clean |

## Evidence corpora + sampled drained repos

| Package | malformed `swift-linter:` count | Notes |
|---------|--------------------------------|-------|
| swift-spm-standard (285f46a^ + HEAD) | 0 | the 37 drained directives are `swiftlint:disable/enable` BLOCK form — out of this rule's scope (SwiftLint's `superfluous_disable_command`/`blanket_disable_command` own them; that is exactly how the drain found them). Zero `swift-linter:` directives, malformed or otherwise. |
| swift-ownership-primitives | 0 | 10 live `swift-linter:disable:next <id>` directives, ALL well-formed → correct no-fire. (Dispatch stated "2 malformed swift-linter:disable:next in tests" — NOT reproduced: all 10 are well-formed; the only `swiftlint:`-prefixed pair — workaround_marker_present, direct_return — is in Sources, legitimate SwiftLint directives.) |
| swift-rfc-4122 | 0 | sampled drained repo — clean |
| swift-linter (engine) | 0 | engine's own real directive at Lint.Suppression.swift:112 is well-formed; its test fixtures live in string literals (not comment trivia) → not scanned |
| swift-cardinal-primitives | 0 | sampled — clean |
| swift-linter-rules | 5* | *line-based scanner artifact: the 5 hits are THIS rule's own test fixtures — malformed directives inside Swift STRING LITERALS in the test file. The real rule scans comment trivia only (string-literal content is a string-literal token, never `.lineComment` trivia) → the engine rule does NOT fire on them. Confirmed by the passing edge tests. |

Fleet-wide (`swift-primitives` + `swift-standards` + `swift-foundations`, excluding this rule's own test fixtures): **0 malformed `swift-linter:` directives**.

## Firing power (unit tests — 12/12 pass)

Fire (Unit, 6): block form (no `:next`/`:line`); `enable` form; empty rule id after `:next`; whitespace-only rule id; wrong sub-token (`:this`); missing space after `//`.

No-fire (Edge Case, 6): well-formed `:next`; well-formed `:line` trailing; `swiftlint:`-prefixed directive (out of scope); `swiftlint:` block form (the swift-spm-standard shape — out of scope); prose mentioning the directive; `///` doc-comment mention (docLineComment, not scanned).

## Disposition

CLEAN — 0 across ladder + corpora + samples (future-prevention); firing power proven on synthetic malformed forms; no false positives on legitimate directives. Added to `Bundle.universal` per [PROMOTE-005].
