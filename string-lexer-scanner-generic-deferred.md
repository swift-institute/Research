# String / Lexer.Scanner — Generic-over-`Char` Decision

**Status**: DEFERRED
**Decision context**: string-primitives correction cycle (2026-04-18), disagreement Δ1
**Revisit trigger**: first concrete consumer that needs to lex a Windows-native `Primitives.String` (UTF-16) without round-tripping through `Swift.String`

---

## The disagreement

The ecosystem-correction-cycle Phase 2 surfaced two opposing positions on whether `Lexer.Scanner` should be generic over its element type:

- **Implementation perspective**: NO. `Lexer.Scanner` stays `Span<UInt8>`. UTF-8 lexing is the spec-grounded use case (config files, protocols, source code are all UTF-8). Bridging from a Windows-native UTF-16 `Primitives.String` is the caller's concern, performed via `Swift.String → utf8 → Span<UInt8>`. `[PATTERN-013]` (3+ conformer rule with no axis-divergent unification): UTF-8 and UTF-16 decoders are fundamentally different state machines, so a single generic `Scanner<Char>` would be a type-erasing shell with totally different bodies — textbook lossy unification.

- **Platform perspective**: YES. `Lexer.Scanner<Char>` generic, defaulting to `UInt8`. Otherwise lexers can't consume Windows-native `Primitives.String` without forced transcoding — leaks the UTF-8 assumption into the lexer's interface. The classification tables (`ASCII.Classification`) only work for 7-bit ASCII anyway, so lone `UInt16` code units ≥ 0x80 simply don't match ASCII predicates, exactly like lone `UInt8` bytes ≥ 0x80 don't match.

## Why deferred

Today, no production consumer needs to lex a Windows-native `Primitives.String` in-place. All known lexer call sites operate on:
- Source code text (UTF-8 by spec)
- Config files (UTF-8 by spec)
- Network protocols (ASCII or UTF-8 by spec)
- Unicode-normalized `Swift.String` content extracted via `.utf8` (UInt8)

The platform-perspective concern is real but not materialized. Until a real Windows-native lexer consumer appears, the engineering cost of generic-ifying `Lexer.Scanner` (and its sibling types `Token`, `Text.Position`, `Text.Location.Tracker`) outweighs the benefit.

## Recommended path forward

When the trigger condition fires (first real Windows-native lexer consumer):

1. Re-evaluate the implementation-perspective claim that the two state machines are fundamentally different. If the consumer's grammar is ASCII-restricted (e.g., a Windows registry key parser that only accepts ASCII identifiers), the "two state machines" objection collapses.
2. If still divergent, prefer a **sibling type** (`Lexer.UTF16Scanner`) over genericizing the existing one. This avoids the lossy-unification trap.
3. If unification is justified (one consumer doesn't validate the case), introduce `Lexer.Scanner<Char: UnsignedInteger & FixedWidthInteger>` with `UInt8` default, and provide UTF-16-specific overloads where ASCII tables don't translate.

## Related

- D12 in `string-type-ecosystem-model.md`
- Implementation perspective full position: synthesis output (in conversation history)
- Platform perspective full position: synthesis output

## Files that would change if implemented

- `swift-primitives/swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Scanner.swift` (generic over Char)
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Position.swift` (generic-friendly offset semantics)
- `swift-primitives/swift-token-primitives/Sources/Token Primitives/Token.swift` (Range over Char-typed offsets)
- All consumer call sites currently passing `Span<UInt8>` (would default; no change)
