# Lexer Primitives Scope

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
tier: 2
---
-->

## Context

swift-lexer-primitives is a Layer 1 (Primitives) package positioned between
token-primitives/source-primitives (below) and parser-primitives/syntax (above).
The package exists as a stub with correct dependencies (token-primitives +
source-primitives) but zero implementation.

**Trigger**: token-primitives is complete. The compiler infrastructure needs the
lexing layer — types and logic that bridge source text to token streams.

**Ecosystem state**:

| Package | Status | Provides |
|---------|--------|----------|
| ascii-primitives | Complete | O(1) character classification (isDigit, isLetter, isWhitespace, etc.) |
| text-primitives | Complete | Text.Position, Text.Range, Text.Offset, Text.Count |
| source-primitives | Complete | Source.Location, Source.Manager, Source.Range, line maps |
| token-primitives | Complete | Token, Token.Kind (hybrid enum), Token.Keyword (UInt8-backed) |
| input-primitives | Complete | Input.Protocol (checkpoint/restore), Input.Buffer, Input.Slice |
| parser-primitives | Complete (58 files) | Parser.Protocol, combinators (generic over Input.Protocol) |
| lexer-primitives | **Empty stub** | — |

**Key architectural observation**: lexer-primitives and input/parser-primitives
are currently **separate branches** of the dependency tree. The existing
Package.swift does NOT depend on input-primitives or parser-primitives. This
appears intentional — the lexer operates on raw bytes, not on the generic
Input.Protocol abstraction.

## Question

What should swift-lexer-primitives uniquely provide, given the existing ecosystem?

## Analysis

### What Already Exists (Do Not Duplicate)

| Capability | Package | API |
|-----------|---------|-----|
| ASCII classification | ascii-primitives | `ASCII.Classification.isDigit(byte)`, `.isLetter`, etc. |
| Byte positions | text-primitives | `Text.Position`, `Text.Range` |
| File-qualified positions | source-primitives | `Source.Location`, `Source.Manager` |
| Token vocabulary | token-primitives | `Token`, `Token.Kind`, `Token.Keyword` |
| Cursor abstraction | input-primitives | `Input.Protocol` with checkpoint/restore |
| Parser combinators | parser-primitives | `Parser.Protocol`, combinators |

### What's Missing (Lexer-Primitives Candidates)

#### 1. Lexeme (Token + Trivia Metadata)

Token-primitives explicitly deferred trivia to the lexer layer. A `Lexer.Lexeme`
wraps a `Token` with trivia byte lengths:

```swift
extension Lexer {
    public struct Lexeme: Sendable, Equatable, Hashable {
        public let kind: Token.Kind
        public let range: Text.Range
        public let leadingTriviaLength: Text.Count
        public let trailingTriviaLength: Text.Count
    }
}
```

This is what a lexer produces and a parser consumes. The full source span is
`leadingTrivia + tokenText + trailingTrivia`.

**Precedent**: swift-syntax's `Lexeme` stores exactly this — kind, flags, trivia
byte lengths, and a text range.

#### 2. Trivia Representation

Structured classification of non-token content:

```swift
extension Lexer {
    public enum Trivia: Sendable, Equatable, Hashable {
        case space(Text.Count)
        case tab(Text.Count)
        case newline
        case carriageReturn
        case carriageReturnLineFeed
        case lineComment(Text.Range)
        case blockComment(Text.Range)
    }
}
```

**Precedent**: swift-syntax has `TriviaPiece` with similar cases. At primitives
level, we define the vocabulary; a full trivia parser would be higher-layer.

#### 3. Character Classification for Primitives Swift

ASCII-primitives has generic ASCII classification but NOT language-specific
predicates. Swift identifiers and operators have specific rules:

- Identifier start: `[a-zA-Z_]` (ASCII subset; full Unicode deferred)
- Identifier continuation: `[a-zA-Z0-9_]`
- Operator start: `[/=\-+!*%<>&|^~?]` plus `.` in some contexts
- Operator continuation: similar set
- Line terminator: `\n`, `\r`, `\r\n`

These could live in `Lexer.Classify` or as extensions on `ASCII.Classification`.

#### 4. Lexer Error

Typed error enum for lexing failures:

```swift
extension Lexer {
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        case invalidUTF8(at: Text.Position)
        case unterminatedBlockComment(start: Text.Position)
        case unterminatedStringLiteral(start: Text.Position)
        case invalidCharacter(at: Text.Position)
    }
}
```

#### 5. Keyword Lookup

Token.Keyword has 64 cases with a `.text` property (keyword → string), but no
reverse mapping (string → keyword). A lexer needs efficient keyword recognition.

Options:
- **A. Switch statement**: Simple, compiler-optimized, O(n) worst case
- **B. Length-partitioned switch**: Switch on length first, then compare — O(1)
  amortized for keywords (all keywords have known lengths)
- **C. Perfect hash**: Minimal perfect hash function for the keyword set

Recommendation: Length-partitioned switch. Matches swiftc's approach, zero
allocation, compiler can optimize the inner comparisons.

### Design Decisions

#### D1: Dependencies — Add ASCII-Primitives?

**Current**: token-primitives + source-primitives only.

| Option | Pro | Con |
|--------|-----|-----|
| **A. Add ascii-primitives** | Reuse existing classification; character predicates compose naturally | Adds dependency |
| **B. Keep current** | Minimal dependencies | Must redefine character classification from scratch |

**Recommendation**: **A — add ascii-primitives.** Character classification is the
lexer's core operation. Duplicating ASCII.Classification would violate DRY.
ASCII-primitives is tier 0 (zero dependencies), so it adds no transitive weight.

#### D2: Dependencies — Add Input-Primitives?

| Option | Pro | Con |
|--------|-----|-----|
| **A. Add input-primitives** | Lexer cursor composes with Input.Protocol | Large transitive dependency tree; couples lexer to input abstraction |
| **B. Keep separate** | Lexer operates directly on byte buffers; simpler | Cannot reuse Input.Protocol's checkpoint/restore |

**Recommendation**: **B — keep separate.** The lexer operates on a contiguous
byte buffer (source file content). It doesn't need the generic cursor
abstraction. swiftc and swift-syntax lexers work with buffer pointers directly.
A bridge between lexer output and parser Input can exist at a higher layer.

#### D3: Trivia Depth

| Option | Pro | Con |
|--------|-----|-----|
| **A. Structured trivia enum** | Rich representation; enables source reconstruction | More types to maintain |
| **B. Byte lengths only** | Minimal; just leadingTriviaLength + trailingTriviaLength on Lexeme | Cannot distinguish trivia kinds without re-scanning |
| **C. Both** | Lexeme carries byte lengths; separate Trivia enum for detailed scanning | Most flexible; slightly more API surface |

**Recommendation**: **C — both.** Lexeme carries byte lengths (cheap, always
available). Trivia enum exists for when detailed trivia analysis is needed. This
matches swift-syntax where Lexeme stores byte lengths and TriviaPiece stores
structured trivia.

#### D4: Concrete Lexer Implementation?

| Option | Pro | Con |
|--------|-----|-----|
| **A. Types only** | Clean separation; implementation at higher layer | Lexer-primitives is just types, no logic |
| **B. Types + concrete lexer** | Complete package; usable standalone | Larger scope; language-specific logic in primitives |
| **C. Types + lexer protocol** | Defines interface; implementations elsewhere | Protocol without concrete types is premature |

**Recommendation**: **B — types + concrete lexer.** Other primitives packages
(buffer, parser, hash-table) include concrete implementations. A lexer for the
Primitives Swift subset (~35 features, ~64 keywords) is well-scoped. The
concrete lexer type would be `Lexer.Scanner` or similar, taking a byte buffer
and producing lexemes.

#### D5: Character Classification Location

| Option | Pro | Con |
|--------|-----|-----|
| **A. In lexer-primitives as Lexer.Classify** | Co-located with consumer; clear ownership | Not reusable outside lexer context |
| **B. In ascii-primitives as extensions** | Reusable by other packages | Puts language-specific logic in a generic package |
| **C. Separate swift-swift-primitives package** | Clean separation of "Swift language rules" | Over-engineering for ~10 predicates |

**Recommendation**: **A — Lexer.Classify.** These are Primitives Swift-specific
predicates. They belong with the lexer that uses them. Generic ASCII
classification stays in ascii-primitives; Swift identifier/operator rules live
here.

## Outcome

**Status**: IN_PROGRESS — awaiting decision on D1-D5 before implementation.

### Proposed Package Structure

```
Sources/Lexer Primitives/
├── exports.swift              (@_exported Token + Source + ASCII)
├── Lexer.swift                (namespace)
├── Lexer.Lexeme.swift         (Token + trivia metadata)
├── Lexer.Trivia.swift         (structured trivia enum)
├── Lexer.Error.swift          (typed throws)
├── Lexer.Classify.swift       (Swift character predicates)
├── Lexer.Keyword.swift        (string → Token.Keyword lookup)
└── Lexer.Scanner.swift        (concrete lexer: bytes → lexemes)
```

### Proposed Dependency Changes

```
dependencies: [
    .package(path: "../swift-token-primitives"),
    .package(path: "../swift-source-primitives"),
    .package(path: "../swift-ascii-primitives"),    // NEW
]
```

## References

- swift-syntax `Lexer/Cursor.swift`, `Lexer/Lexeme.swift`
- swiftc `lib/Parse/Lexer.cpp`
- Token-primitives research: `token-representation-model.md` (DECISION)
- Token foundations literature study (RECOMMENDATION — no swift-token needed)

---

## Deferral

**Date**: 2026-03-15
**Previous status**: IN_PROGRESS (since 2026-02-13)
**New status**: DEFERRED

**Blocker/Reason**: Document defines the complete scope for lexer-primitives: Lexeme, Trivia, character classification, keyword lookup, error types, and concrete Scanner. Five design decisions (D1-D5) have recommendations but await formal approval. The package remains an empty stub. Deferred because the compiler infrastructure (lexer/parser) is not on the active roadmap -- current focus is on data structure primitives, typed throws, and rendering architecture.

**Resumption trigger**: When the Primitives Swift compiler infrastructure becomes active, or when a consumer needs lexeme/trivia types.
