# Token Representation Model

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: DECISION
tier: 2
---
-->

## Context

swift-token-primitives is a Layer 1 (Primitives) package that provides the lexical
vocabulary for a Swift compiler targeting the Primitives Swift subset (~35 language
features). It sits between swift-source-primitives (below) and both
swift-lexer-primitives and swift-syntax-primitives (above).

**Trigger**: Phase 0 (text + source primitives) is complete. The phased compiler
implementation plan identifies Phase 1 (Lexical Analysis) as the next step, with
swift-token-primitives as the first package to implement.

**Downstream consumers**:

| Package | Relationship | What it needs |
|---------|-------------|---------------|
| swift-lexer-primitives | Produces tokens | Token.Kind to tag lexed spans |
| swift-syntax-primitives | Stores tokens in trees | Token.Kind for leaf nodes |
| swift-diagnostic-primitives | References tokens | Token.Kind for "expected X" messages |
| swift-parser-primitives | Consumes token streams | Token.Kind for pattern matching |

**Constraints**:
- No Foundation imports [PRIM-FOUND-001]
- Nest.Name naming [API-NAME-001]
- One type per file [API-IMPL-005]
- Typed throws [API-ERR-001]
- Downward-only tier dependencies

**Existing infrastructure** (from Phase 0):
- `Text.Position` = `Tagged<Text, Ordinal>` — byte offset into UTF-8 text
- `Text.Range` — half-open `[start, end)` byte range
- `Source.Range` — file-qualified byte range `(file: File.ID, start, end)`
- `Source.Location` — file-qualified byte offset `(file: File.ID, offset)`

---

## Questions

This research addresses five design questions:

1. **Scope**: What does token-primitives define — just classification vocabulary, or also a token value type?
2. **Kind representation**: How should token kinds be represented?
3. **Keyword representation**: How should keywords be structured within the kind?
4. **Trivia**: Should token-primitives define trivia types?
5. **Dependencies**: Which packages should token-primitives depend on?

---

## Prior Art Survey

Five major compiler systems surveyed for token representation patterns.

### swiftc (C++ compiler)

**Token kind**: Flat `tok` enum via x-macro hierarchy (`uint8_t`). Each keyword is a
separate case: `kw_struct`, `kw_func`, `kw_if`, etc. Keywords subcategorized via macros:
`DECL_KEYWORD`, `STMT_KEYWORD`, `EXPR_KEYWORD`, `PAT_KEYWORD`.

**Token struct**: `Token { tok Kind; StringRef Text; unsigned CommentLength; ... }`.
Text is a pointer+length into the source buffer. No heap allocation.

**Trivia**: Minimal. Only `CommentLength` tracked. Whitespace not preserved. Not
lossless round-trip.

**Position**: Implicit via `StringRef` pointer arithmetic (pointer into source buffer
implies absolute offset).

### swift-syntax (Swift syntax library)

**Token kind**: `TokenKind` enum with two structural categories:
- **Fixed-text cases** (no associated value): `leftBrace`, `rightBrace`, `comma`,
  `arrow`, `equal`, etc. (~35 cases)
- **Variable-text cases** (carry `String`): `identifier(String)`,
  `integerLiteral(String)`, `binaryOperator(String)`, etc. (~13 cases)
- **Keyword case**: Single `.keyword(Keyword)` wrapping a separate `Keyword: UInt8`
  enum with ~180 cases (backtick-escaped: `` case `struct` ``, `` case `func` ``).

**Trivia**: Full model. `TriviaPiece` enum: counted whitespace (`spaces(Int)`,
`tabs(Int)`, `newlines(Int)`) + text comments (`lineComment(String)`,
`blockComment(String)`). `Trivia` = `[TriviaPiece]`. Attribution rule: trailing up to
first comment/newline, then leading of next token.

**Position**: `AbsolutePosition(utf8Offset: Int)` — NOT stored on tokens. Computed by
tree walk (sum of preceding sibling lengths). Converted to `SourceLocation(line, column,
offset, file)` via `SourceLocationConverter`.

**Raw layer**: Dual representation — `ParsedToken` (contiguous source slice, lazy trivia)
vs. `MaterializedToken` (explicit trivia arrays). Performance optimization: parsing path
avoids allocating trivia.

### rowan / rust-analyzer

**Token kind**: `SyntaxKind(u16)` — flat integer tag shared between tokens AND nodes.
Language-agnostic via `Language` trait. In rust-analyzer: each keyword is its own variant
(`BREAK_KW`, `CONST_KW`, etc.).

**Trivia**: No trivia abstraction. Whitespace (`WHITESPACE`) and comments (`COMMENT`)
are regular tokens in the tree. Uniform — every piece of source text is a token child
of some node.

**Position**: Computed from tree walk (sum of child text lengths). Same as swift-syntax.

**Token storage**: `GreenToken = kind + inline [u8] text`. Immutable, reference-counted,
interned for deduplication.

### Clang

**Token kind**: `tok::TokenKind` enum. Keywords are individual cases: `kw_auto`,
`kw_break`, `kw_case`, etc. Includes C/C++/ObjC language flags per keyword.

**Token struct**: `Token { tok::TokenKind Kind; SourceLocation Loc; unsigned Length; ... }`.
Length stored explicitly (not end position).

**Trivia**: Not preserved. Preprocessor comments accessible separately.

### tree-sitter

**Token kind**: Integer ID (`TSSymbol = uint16_t`). Language-generated via grammar DSL.
IDs are stable per grammar version. Named (keywords, identifiers) and anonymous (punctuation)
symbols distinguished.

**Token struct**: `TSNode` stores start/end byte + start/end row/column. Positions stored
eagerly (not computed from tree walk).

**Trivia**: "Extra" nodes in grammar (whitespace, comments) — present in tree but skippable.

### Convergent Patterns

| Property | swiftc | swift-syntax | rowan | Clang | tree-sitter |
|----------|--------|-------------|-------|-------|-------------|
| Kind type | flat enum | hybrid enum | flat integer | flat enum | flat integer |
| Keywords | individual cases | collapsed (Keyword) | individual cases | individual cases | individual cases |
| Kind backing | UInt8 | enum (+ UInt8) | UInt16 | UInt8 | UInt16 |
| Token text | pointer into source | pointer or String | inline bytes | pointer + length | source slice |
| Trivia | minimal | full (attached) | as tokens | none | extra nodes |
| Position storage | implicit (pointer) | computed (tree walk) | computed | explicit (loc+len) | explicit (stored) |
| Heap allocation | none | String for variable | arena | none | none |

**Universal consensus**:
1. Token kind is a small integer or enum (1–2 bytes)
2. Token text comes from the source buffer (not duplicated)
3. Positions are byte offsets
4. The kind enum is the central abstraction — everything else is compositional

---

## Analysis

### Question 1: Scope — What does token-primitives define?

#### Option A: Vocabulary only

Token-primitives defines `Token.Kind`, `Token.Keyword`, and related classification
types. No token value type (struct). Higher layers compose kind with range.

**Advantages**:
- Zero dependencies (kind is just an enum)
- Maximum flexibility for consumers (each defines its own token representation)
- Matches how swift-syntax has different token representations at different layers

**Disadvantages**:
- No canonical "what is a token" definition
- Every consumer reinvents `(kind, range)` pairing
- Package name suggests it should define what a token IS

#### Option B: Vocabulary + token value type with Text.Range

Token-primitives defines classification types AND a `Token` struct pairing
`Token.Kind` with `Text.Range`.

**Advantages**:
- Complete definition of "token" at the primitives layer
- Single canonical type shared across all consumers
- Natural: a token IS a classified span of text

**Disadvantages**:
- Requires dependency on text-primitives
- Consumers needing file identity must wrap or augment externally
- Locks the representation (position stored as range, not start+length)

#### Option C: Vocabulary + token value type with Source.Range

Like Option B but tokens carry `Source.Range` (file-qualified).

**Advantages**:
- Self-contained: a token knows its file identity
- Diagnostics can reference tokens directly without recovery
- Matches the Phase 0 plan which assumed Source.Range

**Disadvantages**:
- Requires dependency on source-primitives (+ transitive text-primitives)
- Redundant: all tokens from one file share the same File.ID
- Couples token to file-management infrastructure

#### Comparison

| Criterion | A: Vocabulary | B: + Text.Range | C: + Source.Range |
|-----------|--------------|----------------|------------------|
| Dependency weight | None | text-primitives | source-primitives |
| Self-containment | Low | Medium | High |
| Redundancy per token | N/A | None | File.ID repeated |
| Consumer flexibility | High | Medium | Medium |
| Primitives philosophy | Good | Good | Acceptable |
| Package coherence | Weak | Strong | Strong |

**Recommendation: Option B.** A token is fundamentally a classified span within a single
text buffer. File identity is a compositional concern — the lexer operates on one file
at a time, and all tokens from that invocation share the same `Source.File.ID`. Storing
file identity per token is redundant at the primitives layer. Higher layers (e.g.,
`Source.Token` or AST nodes) can pair tokens with file identity when needed.

This also aligns with the layer separation: text-primitives provides the position model,
token-primitives provides the classified-span model, source-primitives provides the
file-qualified model.

---

### Question 2: Token kind representation

#### Option A: Flat enum — every token gets its own case

```swift
public enum Token.Kind: UInt8, Sendable, Equatable, Hashable {
    case `struct`, `enum`, `func`, `var`, `let`, ...  // keywords
    case leftBrace, rightBrace, leftParen, ...         // punctuation
    case binaryOperator, prefixOperator, ...           // operators
    case integerLiteral, floatingLiteral, ...          // literals
    case identifier                                     // identifiers
    case endOfFile                                      // special
}
```

**Advantages**:
- Single-level pattern matching
- `RawRepresentable` as `UInt8` — constant-size, trivially copyable
- Direct: what you see is what you match
- Precedent: swiftc, Clang, rowan

**Disadvantages**:
- ~152 cases in one enum is large
- No sub-classification without computed properties
- Keywords require backtick escaping, cluttering the main enum
- Adding keywords means modifying the main Kind enum
- Exceeds UInt8 range (max 255, but fragile)

#### Option B: Hybrid enum — keywords collapsed, rest flat

```swift
public enum Token.Kind: Sendable, Equatable, Hashable {
    case keyword(Token.Keyword)
    // Punctuation
    case leftBrace, rightBrace, leftParen, rightParen, ...
    // Operators
    case binaryOperator, prefixOperator, postfixOperator
    // Literals
    case integerLiteral, floatingLiteral, stringLiteral, ...
    // Identifiers
    case identifier, dollarIdentifier
    // Conditional compilation
    case poundIf, poundElse, poundElseif, poundEndif
    // Special
    case endOfFile, unknown
}
```

**Advantages**:
- Keywords separated into their own enum (~68 cases with backtick escaping)
- Main Kind enum stays small (~30–35 cases)
- Easy "is keyword?" check: `if case .keyword = kind`
- Keyword sub-classification easy: `keyword.isDeclaration`, `keyword.isStatement`
- Precedent: swift-syntax (production-proven)

**Disadvantages**:
- Two-level matching for keyword tokens: `case .keyword(let kw) where kw == .struct`
- Not `RawRepresentable` as UInt8 (associated value prevents it)
- Slightly larger memory footprint than flat UInt8

#### Option C: Struct with raw value — integer-tagged

```swift
public struct Token.Kind: Sendable, Equatable, Hashable, RawRepresentable {
    public let rawValue: UInt16
    public static let `struct` = Self(rawValue: 0)
    public static let `enum` = Self(rawValue: 1)
    ...
}
```

**Advantages**:
- Constant-size (2 bytes)
- Open for extension (downstream can add custom token kinds)
- RawRepresentable
- Precedent: rowan

**Disadvantages**:
- No exhaustive switch checking
- No associated values
- Loses Swift enum ergonomics
- Must manually maintain uniqueness of raw values

#### Comparison

| Criterion | A: Flat enum | B: Hybrid enum | C: Struct tag |
|-----------|-------------|---------------|--------------|
| Pattern matching | Single level | Two levels for keywords | No exhaustiveness |
| Memory per token kind | 1 byte (UInt8) | 2 bytes (discriminator + UInt8) | 2 bytes (UInt16) |
| Keyword isolation | None | Clean separation | None |
| Extensibility | Closed (no additions) | Closed | Open |
| Swift idiom fit | Good | Best | Acceptable |
| Sub-classification | Computed properties | Natural (keyword enum) | Manual sets |

**Recommendation: Option B.** The hybrid approach is the production-proven pattern
(swift-syntax) and provides the best ergonomics for our primary consumer (the parser).
Keywords are the largest and most structured subcategory — collapsing them into
`Token.Keyword` keeps the main `Token.Kind` enum focused on structural token
categories. Two-level matching for keywords is a minor cost for significant gains in
organization and sub-classification.

---

### Question 3: Keyword representation

Given the recommendation for a separate `Token.Keyword`, how should it be structured?

#### Option A: Flat enum backed by UInt8

```swift
extension Token {
    public enum Keyword: UInt8, Sendable, Equatable, Hashable, Comparable {
        case `struct` = 0
        case `enum` = 1
        case `func` = 2
        ...
        case consuming = 60
        case borrowing = 61
        ...
    }
}
```

**Advantages**:
- 1 byte per keyword — maximally compact
- Comparable (raw value ordering enables efficient sets)
- `switch` is exhaustive
- Precedent: swift-syntax `Keyword: UInt8`

**Disadvantages**:
- Raw values are arbitrary (no semantic grouping)
- Must backtick-escape Swift reserved words
- Adding a keyword requires choosing a new raw value

#### Option B: Grouped by syntactic role via nested enums

```swift
extension Token {
    public enum Keyword: Sendable, Equatable, Hashable {
        case declaration(Declaration)
        case statement(Statement)
        case expression(Expression)
        case ownership(Ownership)
        case access(Access)
        case accessor(Accessor)
        ...

        public enum Declaration: UInt8 { case `struct`, `enum`, `func`, ... }
        public enum Statement: UInt8 { case `if`, `guard`, `for`, ... }
        ...
    }
}
```

**Advantages**:
- Semantic grouping at the type level
- Parser can match on category: `case .declaration(let d)`
- Sub-enums backed by UInt8

**Disadvantages**:
- Three-level matching for specific keywords: `case .keyword(.declaration(.struct))`
- Contextual keywords span categories (some keywords are both statement and expression)
- More complex, harder to maintain
- No compiler precedent uses this pattern

#### Comparison

| Criterion | A: Flat UInt8 | B: Grouped |
|-----------|-------------|-----------|
| Memory per keyword | 1 byte | 2+ bytes |
| Pattern matching depth | 2 levels (kind + keyword) | 3 levels |
| Semantic grouping | Computed properties | Type-level |
| Ambiguous keywords | One location | Must choose one group |
| Maintenance burden | Low | High |

**Recommendation: Option A.** Flat `UInt8`-backed enum with computed properties for
classification. This matches the swift-syntax precedent, keeps matching simple, and
handles contextual keywords (which resist rigid categorization) cleanly. Classification
via computed properties (`isDeclaration`, `isStatement`, etc.) provides the same
query capability without structural overhead.

---

### Question 4: Trivia at the primitives layer

#### Option A: No trivia types

Token-primitives defines only token classification. Trivia (whitespace, comments) is
deferred entirely to higher layers (syntax-primitives or lexer-primitives).

**Advantages**:
- Maximally primitive — tokens are classified text spans, nothing more
- No design commitment on trivia attachment strategy (attached vs. separate tokens)
- Simpler package, fewer types

**Disadvantages**:
- Lexer-primitives will need to define trivia types independently
- No shared trivia vocabulary across consumers

#### Option B: Trivia kind vocabulary (no attachment model)

Token-primitives defines `Token.Trivia.Kind` — an enum classifying trivia pieces
(spaces, tabs, newlines, line comments, block comments, doc comments). No storage,
no attachment model. Just the vocabulary.

**Advantages**:
- Shared vocabulary used by lexer-primitives AND syntax-primitives
- No commitment on attachment strategy
- Small addition (one enum)

**Disadvantages**:
- Trivia kinds are straightforward — may not need shared definition
- Blurs the boundary between "token" and "non-token"

#### Option C: Full trivia model (swift-syntax style)

Define `Token.Trivia.Kind`, `Token.Trivia.Piece` (kind + count/text), and
`Token.Trivia` (collection of pieces) at the primitives layer.

**Advantages**:
- Complete trivia infrastructure shared across all consumers
- Matches swift-syntax's proven model

**Disadvantages**:
- Substantial commitment before lexer design is settled
- Trivia storage strategy (counted vs. text) depends on lexer/parser needs
- Over-specifies at the primitives layer

**Recommendation: Option A.** Trivia is a compositional concern that depends on the
lexer's output strategy and the syntax tree's storage model. Defining trivia types
before those layers are designed risks premature commitment. The lexer-primitives
package (which depends on token-primitives) is the natural home for trivia vocabulary,
since it's the producer that must classify non-token text.

If shared vocabulary proves necessary later, trivia types can be promoted to
token-primitives in a backward-compatible manner.

---

### Question 5: Dependencies

#### Option A: No dependencies

Token-primitives defines only enums (Token.Kind, Token.Keyword). No Token struct,
no range types. Zero external dependencies.

**Rationale**: Vocabulary packages need no infrastructure.

**Impact**: No Token value type. Every consumer defines its own `(kind, range)` pairing.

#### Option B: Depend on text-primitives only

Token-primitives defines Token struct with `Text.Range`. Depends on text-primitives
(which transitively provides the affine infrastructure).

**Rationale**: A token is a classified text span. Text-primitives provides the span.

**Impact**: Shared Token type with file-agnostic range. Current Package.swift needs
updating (remove source-primitives).

#### Option C: Depend on source-primitives (current Package.swift)

Token-primitives defines Token struct with `Source.Range`. Depends on source-primitives
(which transitively includes text-primitives).

**Rationale**: Tokens are file-qualified. Self-contained for diagnostics.

**Impact**: Every token carries a File.ID. Redundant within a single file's token stream.

**Recommendation: Option B.** Aligns with Q1 recommendation. The current Package.swift's
source-primitives dependency should be removed. If a file-qualified token type is
needed, it belongs at a higher layer (e.g., `Source.Token` in source-primitives or
a lexer output type).

---

## Proposed Type Inventory

Based on the recommendations above:

### Token (namespace → struct, 1 file)

```
Token.swift
```

```swift
extension Token: Sendable, Equatable, Hashable {}

public struct Token {
    /// The lexical classification of this token.
    public let kind: Kind

    /// The byte range of this token within its source text.
    public let range: Text.Range
}
```

Lightweight value type. 2 fields. No heap allocation. The token text is derived by
slicing the source buffer at `range`.

### Token.Kind (enum, 1 file)

```
Token.Kind.swift
```

Hybrid enum. Non-keyword cases are flat. Keywords collapsed into single case.

**Punctuation/delimiter cases** (~23):

| Case | Text | Notes |
|------|------|-------|
| `leftBrace` | `{` | |
| `rightBrace` | `}` | |
| `leftParen` | `(` | |
| `rightParen` | `)` | |
| `leftBracket` | `[` | |
| `rightBracket` | `]` | |
| `leftAngle` | `<` | Generic delimiter (ambiguous with operator) |
| `rightAngle` | `>` | Generic delimiter (ambiguous with operator) |
| `colon` | `:` | |
| `semicolon` | `;` | |
| `comma` | `,` | |
| `period` | `.` | |
| `arrow` | `->` | |
| `atSign` | `@` | Attribute prefix |
| `pound` | `#` | Special literal prefix |
| `ampersand` | `&` | inout marker / protocol composition |
| `equal` | `=` | Assignment (not overloadable) |
| `exclamationMark` | `!` | Force unwrap |
| `questionMark` | `?` | Optional type / optional chaining |
| `backslash` | `\` | Key path / string interpolation |
| `ellipsis` | `...` | Variadic / closed range |
| `tilde` | `~` | Inverse constraint (~Copyable, ~Escapable) |
| `backtick` | `` ` `` | Escaped identifier delimiter |

**Operator cases** (3):

| Case | Notes |
|------|-------|
| `binaryOperator` | `+`, `-`, `==`, `!=`, `<<`, `??`, etc. |
| `prefixOperator` | Prefix `!`, prefix `-`, etc. |
| `postfixOperator` | Rare in Primitives Swift |

Actual operator text derived from token range. The parser checks text when
distinguishing specific operators.

**Literal cases** (3):

| Case | Covers |
|------|--------|
| `integerLiteral` | Decimal, `0x` hex, `0b` binary, `0o` octal, `_` separators |
| `floatingLiteral` | Decimal float, hex float, exponents |
| `stringLiteral` | Start of string literal (encompasses all string forms) |

String interpolation tokens:

| Case | Notes |
|------|-------|
| `stringSegment` | Text segment within a string literal |
| `stringInterpolationStart` | `\(` — switches to expression parsing |

**Identifier cases** (2):

| Case | Notes |
|------|-------|
| `identifier` | User identifiers, contextual keywords in identifier position |
| `dollarIdentifier` | `$0`, `$1`, etc. — closure shorthand arguments |

**Conditional compilation cases** (4):

| Case | Notes |
|------|-------|
| `poundIf` | `#if` |
| `poundElse` | `#else` |
| `poundElseif` | `#elseif` |
| `poundEndif` | `#endif` |

**Special cases** (2):

| Case | Notes |
|------|-------|
| `endOfFile` | Sentinel — end of token stream |
| `unknown` | Unrecognized character (error recovery) |

**Keyword case** (1):

| Case | Notes |
|------|-------|
| `keyword(Token.Keyword)` | All Swift keywords |

**Total: ~39 cases** in Token.Kind (plus the collapsed keyword case).

### Token.Kind — computed properties (1 file)

```
Token.Kind+Classification.swift
```

```swift
extension Token.Kind {
    public var isKeyword: Bool { ... }
    public var isPunctuation: Bool { ... }
    public var isOperator: Bool { ... }
    public var isLiteral: Bool { ... }
    public var isIdentifier: Bool { ... }

    /// The fixed text for this token kind, if deterministic.
    /// Returns nil for variable-text kinds (operators, identifiers, literals).
    public var fixedText: Swift.String? { ... }
}
```

### Token.Keyword (enum, 1 file)

```
Token.Keyword.swift
```

`UInt8`-backed enum. ~68 cases for Primitives Swift. Cases grouped logically
(declaration, control flow, ownership, access, etc.) but all in one flat enum.

**Declaration keywords** (17):
`` `struct` ``, `` `enum` ``, `` `func` ``, `` `var` ``, `` `let` ``,
`` `typealias` ``, `` `init` ``, `` `deinit` ``, `` `subscript` ``,
`` `protocol` ``, `` `extension` ``, `` `import` ``, `` `static` ``,
`` `associatedtype` ``, `` `operator` ``, `` `precedencegroup` ``,
`` `case` ``

**Control flow keywords** (13):
`` `if` ``, `` `else` ``, `` `guard` ``, `` `switch` ``, `` `default` ``,
`` `for` ``, `` `in` ``, `` `while` ``, `` `return` ``, `` `break` ``,
`` `continue` ``, `` `fallthrough` ``, `` `defer` ``

**Error handling keywords** (5):
`` `throw` ``, `` `throws` ``, `` `try` ``, `` `do` ``, `` `catch` ``

**Ownership keywords** (5):
`consuming`, `borrowing`, `` `inout` ``, `mutating`, `nonmutating`

**Access control keywords** (5):
`` `public` ``, `` `internal` ``, `` `private` ``, `` `fileprivate` ``,
`package`

**Accessor keywords** (4):
`get`, `set`, `_read`, `_modify`

**Type keywords** (7):
`some`, `any`, `` `self` ``, `` `Self` ``, `` `nil` ``, `` `true` ``,
`` `false` ``

**Expression keywords** (3):
`` `as` ``, `` `is` ``, `` `where` ``

**Variadic generics keywords** (2):
`each`, `` `repeat` ``

**Other keywords** (3):
`yield`, `discard`, `` `indirect` ``

**Total: ~64 keyword cases.**

Note: Contextual keywords (`consuming`, `borrowing`, `some`, `any`, `get`, `set`,
`each`, `yield`, `discard`, `package`, `_read`, `_modify`, `mutating`, `nonmutating`)
do not require backtick escaping in the enum definition since they are not Swift
reserved words.

### Token.Keyword — computed properties (1 file)

```
Token.Keyword+Classification.swift
```

```swift
extension Token.Keyword {
    public var isDeclaration: Bool { ... }
    public var isStatement: Bool { ... }
    public var isExpression: Bool { ... }
    public var isOwnership: Bool { ... }
    public var isAccessControl: Bool { ... }
    public var isAccessor: Bool { ... }
    public var isContextual: Bool { ... }

    /// The canonical text of this keyword.
    public var text: Swift.String { ... }
}
```

### File Organization

Per [API-IMPL-005] (one type per file):

| File | Type | Lines (est.) |
|------|------|-------------|
| `Token.swift` | `Token` struct | 30–40 |
| `Token.Kind.swift` | `Token.Kind` enum | 80–120 |
| `Token.Kind+Classification.swift` | Classification properties | 50–80 |
| `Token.Keyword.swift` | `Token.Keyword` enum | 100–140 |
| `Token.Keyword+Classification.swift` | Keyword classification | 60–80 |
| `exports.swift` | Module re-exports | 10 |

**Total: 6 files, ~330–470 lines.**

---

## Decisions Not Made Here (Deferred)

| Topic | Why deferred | Where it belongs |
|-------|-------------|-----------------|
| Trivia representation | Depends on lexer output strategy | lexer-primitives or syntax-primitives |
| String literal internals | Multi-line, interpolation segments, raw strings | lexer-primitives (lexing concern) |
| Operator precedence | Parser concern, not lexical | parser or operator-precedence package |
| Keyword lookup (text → Keyword) | Lexer concern (hash function design) | lexer-primitives |
| Token ↔ AST node relationship | Syntax tree design | syntax-primitives |

---

## Open Questions for Discussion

### Q1: Should `leftAngle`/`rightAngle` exist separately from operators?

In Swift, `<` and `>` are ambiguous between generic delimiters and comparison
operators. swift-syntax has both `.leftAngle` (punctuation) and `.binaryOperator("<")`
as separate token kinds, with the lexer choosing based on context (spacing rules).

If we follow this pattern, the lexer must disambiguate at lex time. If we use only
`.binaryOperator` for both, disambiguation moves to the parser. The former is the
established Swift convention.

**Recommendation**: Keep `leftAngle`/`rightAngle` as separate punctuation cases.
Matches swift-syntax and swiftc.

### Q2: How many string-related token kinds?

The inventory above has `stringLiteral`, `stringSegment`, and
`stringInterpolationStart`. swift-syntax also has `stringQuote`,
`multilineStringQuote`, `rawStringPoundDelimiter`. The full set matters for the lexer
but may be over-specified at the primitives layer.

**Recommendation**: Start minimal (`stringLiteral`, `stringSegment`,
`stringInterpolationStart`). Expand when lexer implementation reveals needs.

### Q3: `wildcard` as separate case or identifier?

swift-syntax has `.wildcard` for `_`. swiftc treats `_` as the `kw__` keyword.
Semantically `_` is special (discard pattern, anonymous argument label) but lexically
it's an identifier character.

**Recommendation**: Separate `.wildcard` case, following swift-syntax. This simplifies
parser matching — `_` is structurally distinct from identifiers.

### Q4: Package.swift dependency change

The current Package.swift declares dependencies on both source-primitives and
text-primitives. The recommendation is to depend only on text-primitives. This
changes the declared dependency graph. Confirm this is acceptable before implementation.

---

## Outcome

**Status**: IN_PROGRESS — awaiting review of recommendations.

### Summary of Recommendations

| Question | Recommendation | Precedent |
|----------|---------------|-----------|
| Q1: Scope | Vocabulary + Token struct with Text.Range | swiftc (kind + pointer) |
| Q2: Kind | Hybrid enum (keyword case + flat rest) | swift-syntax |
| Q3: Keyword | Flat UInt8-backed enum | swift-syntax |
| Q4: Trivia | Not at primitives layer | Deferred |
| Q5: Dependencies | text-primitives only (remove source-primitives) | New |

### Dependency Change

```
Current:  token-primitives → source-primitives → text-primitives
                           → text-primitives

Proposed: token-primitives → text-primitives
```

### Estimated Scale

~330–470 lines across 6 files. Straightforward implementation once design is approved.

---

## References

1. swift-syntax `TokenKind.swift` — https://github.com/swiftlang/swift-syntax
2. swift-syntax `Keyword.swift` — `Sources/SwiftSyntax/generated/Keyword.swift`
3. swift-syntax `Trivia.swift` — `Sources/SwiftSyntax/Trivia.swift`
4. swiftc `Token.h` — `include/swift/Parse/Token.h`
5. swiftc `TokenKinds.def` — `include/swift/AST/TokenKinds.def`
6. rowan `SyntaxKind` — https://docs.rs/rowan/latest/rowan/struct.SyntaxKind.html
7. rust-analyzer syntax_kind — `crates/parser/src/syntax_kind/generated.rs`
8. Phased Compiler Implementation Plan — `swift-compiler/Research/phased-compiler-implementation-plan.md`
9. Phase 0 Source Text Infrastructure — `swift-compiler/Research/phase-0-source-text-infrastructure.md`
10. Text Position Model — `swift-text-primitives/Research/text-position-model.md`
11. Source Location Model — `swift-source-primitives/Research/source-location-model.md`
