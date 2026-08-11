# Token Foundations Literature Study

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: RECOMMENDATION
tier: 2
---
-->

## Context

swift-token-primitives (Layer 1) is being designed to define the token vocabulary:
`Token.Kind`, `Token.Keyword`, and a `Token` value type. The question is whether a
separate swift-token (Layer 3, Foundations) package is needed, and if so, what it
should provide beyond the primitives.

**Trigger**: Phase 1 planning. The five-layer architecture pattern creates a
primitives→foundations pair (e.g., source-primitives → swift-source). Does the same
pattern apply to tokens?

**Constraint**: The answer determines whether `swift-token` needs to be created in
swift-foundations, or whether token-level foundations functionality distributes across
swift-lexer and swift-diagnostic.

---

## Question

What token-level infrastructure do major compiler systems provide above the raw token
type definition? Is this infrastructure a cohesive package or does it distribute
across the lexer, parser, and diagnostic systems?

---

## Prior Art Survey

Eight compiler systems surveyed: swiftc, swift-syntax, rowan/rust-analyzer, rustc,
Clang, GCC, tree-sitter, and Roslyn.

### System-by-System Findings

#### swiftc

| Layer | Abstraction | Location |
|-------|-------------|----------|
| Token type | `Token` (kind + location + text + flags) | `Parse/Token.h` |
| Token provider | Direct `Lexer` call, pull model | `Parse/Lexer.h` |
| Lookahead | 1-token (`NextToken`), save/restore for deeper | `Parse/Lexer.h` |
| Buffer/cache | None — re-lex from saved `LexerState` | — |
| Printing | Via source text (location + length) | — |

**No separate token infrastructure package.** The `Token` class lives alongside the
Lexer. The Parser calls `Lexer::lex()` directly.

#### swift-syntax

| Layer | Abstraction | Location |
|-------|-------------|----------|
| Raw token | `RawTokenKind` | `SwiftSyntax` |
| Lex-time token | `Lexeme` (kind + trivia + text span) | `SwiftParser` |
| Lex sequence | `LexemeSequence` (lazy cursor) | `SwiftParser` |
| Tree token | `TokenSyntax` (trivia + presence) | `SwiftSyntax` |
| Post-parse iteration | `TokenSequence` via `tokens(viewMode:)` | `SwiftSyntax` |

**Split across two modules.** Raw token kinds and tree-level token wrappers are in
`SwiftSyntax`. The lex-time token (`Lexeme`) and its sequence are in `SwiftParser`.
There is no separate "SwiftToken" module.

#### rowan / rust-analyzer

| Layer | Abstraction | Location |
|-------|-------------|----------|
| Token kind | `SyntaxKind(u16)` | `parser` crate |
| Green token | `GreenToken` (kind + inline text) | `rowan` crate |
| Red token | `SyntaxToken<L>` (offset + parent) | `rowan` crate |
| Token source | `TokenSource` trait (`current`, `lookahead(n)`, `bump`) | `parser` crate |

**Split across two crates.** The tree-level token is in `rowan`. The parser-level
token source is in the `parser` crate. No separate token crate.

#### rustc

| Layer | Abstraction | Location |
|-------|-------------|----------|
| Token type | `Token` (kind + span) | `rustc_ast` |
| Token tree | `TokenTree` (token or delimited group) | `rustc_ast` |
| Token stream | `TokenStream` = `Arc<Vec<TokenTree>>` | `rustc_ast` |
| Token cursor | `TokenCursor` (tree-to-flat linearization) | `rustc_parse` |
| Spacing | `Spacing` enum (Joint/Alone/JointHidden) | `rustc_ast` |

**Closest to a separate token package.** `rustc_ast` defines `Token`, `TokenTree`,
`TokenStream`, and `Spacing` — a cohesive token infrastructure independent of the
lexer. But `rustc_ast` also defines the full AST, so tokens are co-located with the
syntax tree, not isolated.

#### Clang

| Layer | Abstraction | Location |
|-------|-------------|----------|
| Token type | `Token` (16 bytes: location, length, kind, flags) | `Lex/Token.h` |
| Token provider | `Preprocessor::Lex()` (unified dispatch) | `Lex/Preprocessor.h` |
| Token buffer | `CachedTokens` (vector for backtracking) | `Lex/Preprocessor.h` |
| Token injection | `TokenLexer` (replay from token list) | `Lex/TokenLexer.h` |
| Annotation tokens | `annot_typename`, `annot_cxxscope` | `Lex/Token.h` |

**Token type lives with the Lex infrastructure.** `Token.h` is in the `Lex` library.
`CachedTokens`, `TokenLexer`, and annotation tokens are all Lex-layer concepts.
No separate token package.

**Unique pattern: annotation tokens.** The parser writes semantically-enriched tokens
back into the stream, preventing re-analysis after backtracking. Specific to C++'s
parsing complexity.

#### GCC (C++ parser)

| Layer | Abstraction | Location |
|-------|-------------|----------|
| Token type | `cp_token` (kind, keyword ID, location, value) | `cp/parser.h` |
| Token buffer | `cp_lexer.buffer` (pre-materialized `Vec<cp_token>`) | `cp/parser.h` |
| Token cache | `cp_token_cache` (range reference into buffer) | `cp/parser.h` |
| Tentative parse | `saved_tokens` stack + `cp_parser_context` | `cp/parser.h` |

**All token infrastructure lives in the parser.** GCC pre-lexes ALL tokens into a
flat array. The `cp_lexer` is not a lexer — it's a token cursor over the
pre-materialized array. The actual lexing is done by the C preprocessor (`libcpp`).

**Key design: pre-materialization.** "Tokens are never added to the cp_lexer after it
is created." O(1) indexed lookahead everywhere.

#### tree-sitter

**Scannerless architecture.** No separate token layer. The parser drives character-level
lexing inline. Token types (`TSSymbol`) are just integer IDs generated from the grammar.

#### Roslyn

| Layer | Abstraction | Location |
|-------|-------------|----------|
| Green token | `GreenNode` (internal, interned) | `Compilers/Core` |
| Red token | `SyntaxToken` (value type, position + parent) | `Compilers/Core` |
| Trivia | `SyntaxTrivia` (value type) | `Compilers/Core` |
| Token iteration | `DescendantTokens()`, `GetNextToken()` | `Compilers/Core` |

**Token types are part of the syntax tree library**, not a separate package.

---

## Cross-System Analysis

### Where does token infrastructure live?

| System | Separate token package? | Token type location | Token provider location |
|--------|------------------------|--------------------|-----------------------|
| swiftc | No | Lex (with lexer) | Parser pulls from lexer |
| swift-syntax | No | SwiftSyntax (tree) + SwiftParser (lexeme) | SwiftParser |
| rowan | No | rowan (tree) + parser (source) | parser crate |
| rustc | Partial — in `rustc_ast` | rustc_ast (with AST) | rustc_parse |
| Clang | No | Lex (with lexer) | Lex (preprocessor) |
| GCC | No | cp/parser (with parser) | cp/parser |
| tree-sitter | No | N/A (scannerless) | N/A |
| Roslyn | No | Compilers/Core (with tree) | Compilers/Core |

**Consensus: No compiler system has a standalone token package at the foundations level.**

Token infrastructure consistently distributes across:
1. **The syntax tree library** — tree-level token wrapper (`TokenSyntax`, `SyntaxToken<L>`)
2. **The lexer/parser** — lex-time token, cursor, buffering, lookahead

### What "token foundations" functionality exists?

| Capability | Where it lives (consensus) | Standalone? |
|------------|--------------------------|-------------|
| Token kind enum | Token primitives / syntax lib | Yes — already in token-primitives |
| Token value type (kind + range) | Token primitives / syntax lib | Yes — already in token-primitives |
| Token text access | Source manager (via range) | No — part of source infrastructure |
| Token printing for diagnostics | Diagnostic system | No — part of diagnostics |
| Token stream / sequence | Lexer or parser | No — coupled to consumption model |
| Token buffering / caching | Parser (for backtracking) | No — coupled to parse strategy |
| Lookahead | Lexer or parser | No — coupled to parse strategy |
| Token trivia | Syntax tree library | No — coupled to tree model |
| Token iteration (post-parse) | Syntax tree library | No — coupled to tree model |

### Lookahead strategies

| Strategy | Systems | Implications |
|----------|---------|-------------|
| On-demand (1-token + save/restore) | swiftc, Roslyn | Simplest. Re-lex on backtrack. |
| Lazy sequence with peek | swift-syntax | Good for modern Swift. `LexemeSequence`. |
| Pre-materialized array | GCC, rust-analyzer | O(1) lookahead. Higher memory. |
| Demand-cached | Clang | On-demand + cache when backtracking enabled. |
| Tree cursor | rustc | TokenTree hierarchy linearized by cursor. |

**For Primitives Swift**: The language has limited ambiguity compared to C++ (no
declaration/expression ambiguity, no preprocessor). A lazy sequence with peek
(swift-syntax model) or on-demand with save/restore (swiftc model) is sufficient.
Pre-materialization (GCC model) is overkill.

---

## Recommendation

### swift-token as a standalone foundations package is NOT warranted.

The literature study shows zero precedent for a standalone token foundations package
in any major compiler system. Token-level functionality above the raw type definitions
distributes naturally across:

| Functionality | Natural home | Layer |
|---------------|-------------|-------|
| Token.Kind, Token.Keyword, Token struct | **swift-token-primitives** | Primitives |
| Token text access (via range into source buffer) | **swift-source** | Foundations |
| Token stream / lex-time cursor | **swift-lexer** | Foundations |
| Token printing for diagnostics | **swift-diagnostic** | Foundations |
| Token trivia model | **swift-syntax-primitives** or **swift-lexer-primitives** | Primitives |
| Token buffering / lookahead | **swift-parser** or **swift-lexer** | Foundations |
| Post-parse token iteration | **swift-syntax** | Foundations |

### ASCII primitives reuse

The lexer (swift-lexer-primitives and swift-lexer) should depend on swift-ascii-primitives
for character classification during lexing. Relevant existing infrastructure:

| ASCII type | Lexer use |
|------------|-----------|
| `ASCII.Classification` (10 predicates) | Character dispatch: `isWhitespace`, `isDigit`, `isLetter`, etc. |
| `ASCII.GraphicCharacters` | Byte constants: `lessThanSign` (0x3C), `greaterThanSign` (0x3E), `leftBrace` (0x7B), etc. |
| `ASCII.LineEnding` (.lf, .cr, .crlf) | Line ending detection for line maps |
| `ASCII.CaseConversion` | Case-insensitive keyword matching |
| `ASCII.Validation` (SIMD fast path) | Source file ASCII validation |
| `ASCII.Parsing` (digit, hexDigit) | Number literal lexing |

This infrastructure is already production-ready (10 files). The lexer should import
`ASCII_Primitives` rather than reimplementing character classification.

### Revised dependency graph for Phase 1

```
                     swift-lexer (L3)
                     ├── swift-lexer-primitives (L1)
                     │   ├── swift-token-primitives (L1)
                     │   │   └── swift-text-primitives (L1)
                     │   ├── swift-source-primitives (L1)
                     │   │   └── swift-text-primitives (L1)
                     │   └── swift-ascii-primitives (L1)
                     └── swift-source (L3)
                         └── swift-source-primitives (L1)

                     swift-diagnostic (L3)
                     ├── swift-diagnostic-primitives (L1)
                     │   └── swift-source-primitives (L1)
                     └── swift-source (L3)
```

No `swift-token` package appears anywhere in this graph.

---

## Outcome

**Status**: RECOMMENDATION

**Decision**: Do NOT create a `swift-token` foundations package. The token foundations
functionality distributes across `swift-lexer`, `swift-diagnostic`, and `swift-syntax`
per established compiler architecture patterns.

**Implication for swift-token-primitives**: The primitives package is the complete
token abstraction. There is no foundations-layer counterpart. This is similar to how
not every primitives package needs a foundations pair — some are self-contained.

**Implication for Phase 1**: The implementation plan should route token-related
foundations work to:
- Token stream → `swift-lexer`
- Token diagnostics → `swift-diagnostic`
- Token trivia → `swift-lexer-primitives` or `swift-syntax-primitives`

---

## References

1. swiftc `Token.h` — `include/swift/Parse/Token.h`
2. swiftc `Lexer.h` — `include/swift/Parse/Lexer.h`
3. swift-syntax `TokenSyntax.swift` — `Sources/SwiftSyntax/TokenSyntax.swift`
4. swift-syntax `SwiftParser` — `Sources/SwiftParser/`
5. rowan `SyntaxToken` — https://docs.rs/rowan/latest/rowan/api/struct.SyntaxToken.html
6. rust-analyzer parser `TokenSource` — `crates/parser/src/token_set.rs`
7. rustc `tokenstream.rs` — `compiler/rustc_ast/src/tokenstream.rs`
8. Rustc Dev Guide: The Parser — https://rustc-dev-guide.rust-lang.org/the-parser.html
9. Clang `Preprocessor.h` — `include/clang/Lex/Preprocessor.h`
10. Clang `Token.h` — `include/clang/Lex/Token.h`
11. GCC `cp/parser.h` — `gcc/cp/parser.h`
12. Tree-sitter `lexer.h` — `lib/src/lexer.h`
13. Roslyn `SyntaxToken.cs` — `src/Compilers/Core/Portable/Syntax/SyntaxToken.cs`
14. Willspeak, Red-Green Syntax Trees Overview — https://willspeak.me/2021/11/24/red-green-syntax-trees-an-overview.html
15. Modocache, Getting Started with the Swift Frontend — https://modocache.io/the-swift-frontend-lexing-and-parsing
