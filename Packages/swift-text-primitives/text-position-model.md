# Text Position Model

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: DECISION
---
-->

## Context

swift-text-primitives sits at Layer 1 (Primitives) in the Swift Institute five-layer architecture, between swift-string-primitives (below) and swift-source-primitives (above). The dependency chain for building a Swift compiler is:

```
ascii-primitives --> string-primitives --> text-primitives --> source-primitives --> swift-source
```

string-primitives provides `String` (~Copyable, owned, null-terminated platform string), `String.View` (~Copyable, ~Escapable, borrowed view), `String.Char` (platform code unit typealias), and `String.Length` (strlen-equivalent). These are byte-level abstractions with no notion of lines, columns, or positions within structured text.

source-primitives depends on text-primitives and will add source-file-specific concepts: file identity, diagnostic locations, `#sourceLocation` directives, and edit/patch operations.

text-primitives must provide the general-purpose text position and range abstractions that source-primitives (and any other structured-text consumer) builds upon. The design decisions made here establish the semantic contract for all text positioning throughout the ecosystem.

This is a **Tier 2 (Standard)** research document per [RES-020]: it affects multiple packages (text-primitives, source-primitives, and all downstream consumers), establishes a precedent for position representation, but is not as sweeping as a Tier 3 ecosystem-wide decision since the concepts are well-understood in prior art.

### Trigger

Implementation of text-primitives is blocked by six interdependent design questions about how to represent positions, ranges, and line structure in text. These cannot be answered by existing conventions alone -- they require analysis of prior art and careful boundary-drawing between text-primitives and source-primitives. Per [RES-011], this research document resolves the questions before implementation begins.

### Constraints

- [API-NAME-001]: All types use `Nest.Name` pattern. No compound type names.
- [API-NAME-003]: Types implementing specifications must mirror specification terminology.
- [API-IMPL-005]: One type per file.
- [API-ERR-001]: All throwing functions use typed throws.
- [PRIM-FOUND-001]: No Foundation imports.
- Swift 6.2, platforms macOS 26+.
- Package depends on swift-string-primitives (which depends on swift-ascii-primitives).
- Types should be Sendable. Text positions are small value types -- Copyable is appropriate.

---

## Question

What types should swift-text-primitives provide, and how should they represent positions, ranges, and line structure in text?

This decomposes into six sub-questions:

1. **Boundary**: What belongs in text-primitives vs source-primitives?
2. **Position model**: How to represent a position in text?
3. **Range model**: How to represent a span of text?
4. **Line tracking**: How to map byte offsets to line numbers?
5. **Column representation**: What unit for column offsets?
6. **Encoding awareness**: Should text-primitives assume UTF-8?

---

## Analysis

### Prior Art Survey

Every major compiler and editor infrastructure uses byte offsets as the primary internal representation, with line/column derived lazily via a line map. The following table summarizes the prior art:

| System | Primary Position | Line/Column | Line Map | Range | Storage |
|--------|-----------------|-------------|----------|-------|---------|
| **Clang/LLVM** | `SourceLocation` (32-bit encoded FileID + offset) | Derived via `SourceManager` | Lazily computed sorted array of line-start offsets | `SourceRange` (pair of `SourceLocation`) | `u32` |
| **rust-analyzer / rowan** | `TextSize` (u32 byte offset) | `LineCol` via `LineIndex` | Sorted `Vec<TextSize>` of newline positions | `TextRange` (pair of `TextSize`) | `u32` |
| **Roslyn (C#)** | `TextSpan` (int start + int length, character offset) | `LinePosition` (line + character) | `TextLineCollection` | `TextSpan` / `LinePositionSpan` | `int` (32-bit) |
| **tree-sitter** | `TSPoint` (row + column as u32) + byte offset | `TSPoint.row` / `TSPoint.column` | Maintained incrementally during parsing | `TSRange` (start/end point + start/end byte) | `u32` |
| **Swift compiler** | `SourceLoc` (pointer into buffer) | Derived via `SourceManager` | Lazily computed | `SourceRange` (pair of `SourceLoc`) | pointer |
| **swift-syntax** | `AbsolutePosition` (UTF-8 byte offset as Int) | `SourceLocation` (line + column + offset) | `SourceLocationConverter` with sorted newline array | `SourceRange` (start + end `SourceLocation`) | `Int` |
| **LSP** | N/A (wire protocol) | `Position` (line + character, 0-based) | Client/server responsibility | `Range` (start + end `Position`) | varies; character = UTF-16 code unit by default, UTF-8/UTF-32 negotiable since 3.17 |

**Key insight**: All production compilers store positions as byte offsets internally. Line/column is always a derived view, computed lazily through a line map (sorted array of line-start byte offsets). The Casey Muratori article "Byte Positions Are Better Than Line Numbers" articulates the performance rationale: jumping to a byte offset is O(1), while resolving a line:column to a byte position requires O(n) scanning or O(log n) binary search through a line map.

**Second insight**: The line map itself is a simple, universal data structure -- a sorted array of byte offsets where each entry marks the start of a new line. Binary search on this array converts byte offset to line number in O(log L) where L is the number of lines. This structure is the same across Clang, rust-analyzer, swift-syntax, and every other system surveyed.

**Third insight**: Column representation varies by protocol but not by compiler internals. LSP historically uses UTF-16 code units (a historical artifact of VS Code's JavaScript runtime). Clang and rust-analyzer use byte offsets within the line. swift-syntax uses UTF-8 byte offsets. For a primitives package that assumes UTF-8, byte offset within the line is the natural and correct choice. Protocol-specific column encodings (UTF-16 for LSP) belong at the integration boundary, not in primitives.

### UAX #29 and Grapheme Clusters

Unicode Text Segmentation (UAX #29) defines grapheme cluster boundaries -- what users perceive as "characters." This is relevant for cursor movement in editors but irrelevant for compiler position tracking. No production compiler uses grapheme clusters as position units. Grapheme cluster segmentation requires stateful iteration over Unicode properties and is far too expensive for position arithmetic. Text-primitives should not concern itself with grapheme clusters. If needed, grapheme-aware cursor logic belongs in a higher layer (editor components).

---

### Decision 1: Boundary Between text-primitives and source-primitives

#### Option A: Everything in text-primitives

Put positions, ranges, line maps, file identity, and diagnostics all in text-primitives.

- **Pro**: Single package for all text concepts.
- **Con**: Violates separation of concerns. File identity and diagnostics are source-specific. A JSON parser needs text positions but not source file identity.

#### Option B: General text abstractions in text-primitives, source-specific concepts in source-primitives

text-primitives provides: positions, ranges, line maps, line/column resolution.
source-primitives adds: file identity, diagnostic locations, `#sourceLocation` directive support, edit/patch operations.

- **Pro**: Clean separation. text-primitives is reusable for any structured text (JSON, TOML, XML, log files), not just source code.
- **Con**: Two packages to depend on for full source tooling. (Acceptable -- this is the normal primitives layering pattern.)

#### Option C: Minimal text-primitives (positions and ranges only), line maps in source-primitives

- **Pro**: Extremely minimal text-primitives.
- **Con**: Line maps are general-purpose. A Markdown parser needs line numbers. Pushing line maps to source-primitives forces non-source consumers to depend on a source-specific package.

| Criterion | A: Everything | B: Split at file identity | C: Minimal |
|-----------|:---:|:---:|:---:|
| Reusability for non-source consumers | Poor | Good | Poor (line maps inaccessible) |
| Separation of concerns | Poor | Good | Moderate |
| Primitives layering compliance | Violates | Compliant | Compliant |
| Ergonomics for source tooling | Best (one import) | Good (two imports) | Good (two imports) |

**Decision**: **Option B**. text-primitives provides positions, ranges, and line maps. source-primitives adds file identity, diagnostic context, and edit operations.

---

### Decision 2: Text Position Model

#### Option A: Bare byte offset (UInt / Int)

Store position as a plain integer.

- **Pro**: Simple, zero overhead.
- **Con**: No type safety. A byte offset can be confused with a line number, a character count, or any other integer. Violates [IMPL-002] (typed quantities).

#### Option B: Newtype over UInt (like `TextSize` in rust-analyzer)

Dedicated wrapper type: `Text.Offset` backed by `UInt`.

- **Pro**: Type safety. Cannot accidentally mix with other integers. Follows the ecosystem pattern (`Cardinal` wraps `UInt`, `Ordinal` wraps `UInt`).
- **Con**: Slight API surface. But this is exactly the pattern used throughout primitives.

#### Option C: Tagged<Text, Ordinal> (reuse Index<T> pattern)

Use the existing `Tagged` + `Ordinal` infrastructure: `typealias Text.Position = Tagged<Text, Ordinal>`.

- **Pro**: Inherits all `Ordinal.Protocol` operations (`.successor`, `.predecessor`, `.advance`, `.retreat`, `.distance`). Follows ecosystem conventions perfectly. Zero new operation code.
- **Con**: Requires dependency on ordinal-primitives and identity-primitives. But text-primitives already sits high enough in the tier chain to afford this, and string-primitives does not currently depend on these. **However**: the current Package.swift for text-primitives depends only on string-primitives. Adding ordinal-primitives + identity-primitives as dependencies is a dependency chain decision.

#### Option D: Dedicated struct `Text.Offset` with custom operations

Like Option B but with hand-rolled arithmetic instead of protocol inheritance.

- **Pro**: No dependency on ordinal/cardinal primitives.
- **Con**: Duplicates infrastructure that already exists. Violates DRY. If we later want typed operations (`.advance`, `.distance`), we reinvent Ordinal.Protocol.

| Criterion | A: Bare Int | B: Newtype | C: Tagged<Text, Ordinal> | D: Dedicated struct |
|-----------|:---:|:---:|:---:|:---:|
| Type safety | None | Good | Excellent | Good |
| Ecosystem consistency | Poor | Moderate | Excellent | Moderate |
| Operations inherited | None | None | All ordinal ops | Manual |
| Dependency cost | None | Minimal | ordinal + identity | Minimal |
| Migration to Tagged later | Breaking | Breaking | N/A | Breaking |

**Decision**: **Option C** -- `Text.Offset` as `Tagged<Text, Ordinal>` -- contingent on adding ordinal-primitives and identity-primitives as dependencies. If the dependency chain is unacceptable (to be validated), fall back to **Option B** with a migration path.

**Rationale**: The ecosystem already solved typed positions with `Tagged<Tag, Ordinal>`. A text byte offset IS an ordinal -- it answers "which byte?" in a well-ordered sequence. Using the existing infrastructure means `Text.Offset` immediately gets `.successor`, `.predecessor`, `.advance(by:)`, `.retreat(by:)`, `.distance(to:)`, comparison operators, and `Sendable` conformance -- all without writing a single line of operation code. The phantom tag `Text` prevents mixing text offsets with memory addresses or element indices.

Similarly, `Text.Offset.Count` (which would be `Tagged<Text, Cardinal>`) represents "how many bytes" in text, inheriting all cardinal operations.

**Naming note**: We use `Text.Offset` rather than `Text.Position` because in the primitives ecosystem, `Ordinal`-backed types represent offsets (zero-based byte distances from start). The name `Offset` is consistent with `Memory.Address` (also `Tagged<Memory, Ordinal>`) representing a byte offset. The count type is `Text.Offset.Count` (= `Index<Text>.Count` = `Tagged<Text, Cardinal>`).

---

### Decision 3: Text Range Model

#### Option A: Pair of Text.Offset (start, end) -- half-open

```swift
extension Text {
    struct Range: Sendable {
        let start: Text.Offset
        let end: Text.Offset   // exclusive
    }
}
```

- **Pro**: Universal compiler convention. Clang, rust-analyzer, swift-syntax, tree-sitter all use half-open `[start, end)`.
- **Pro**: Empty ranges are natural: `start == end`.
- **Pro**: Composable: adjacent ranges share boundary (`range1.end == range2.start`).

#### Option B: Start + length

```swift
extension Text {
    struct Range: Sendable {
        let start: Text.Offset
        let length: Text.Offset.Count
    }
}
```

- **Pro**: Length is always non-negative (Cardinal). Cannot construct inverted ranges.
- **Con**: Requires addition to compute end. Less conventional for compilers.

#### Option C: Closed range (start, end inclusive)

- **Pro**: None for this domain.
- **Con**: Empty ranges are unrepresentable. Off-by-one errors. No prior art in compilers.

| Criterion | A: Half-open pair | B: Start + length | C: Closed |
|-----------|:---:|:---:|:---:|
| Prior art alignment | Universal | Roslyn `TextSpan` | None |
| Empty range support | Natural | Natural | Impossible |
| Composability | Excellent | Moderate | Poor |
| Negative length prevention | Requires `end >= start` invariant | By construction | N/A |
| End computation | Direct field access | Addition required | Direct |

**Decision**: **Option A** -- half-open `[start, end)` with a stored pair. The `Text.Range` type stores `start: Text.Offset` and `end: Text.Offset` where `end >= start` is an invariant. A computed `count` property returns `end - start` as `Text.Offset.Count`.

We also provide a factory `Text.Range(start:count:)` for construction from start + length, which internally computes end.

---

### Decision 4: Line Tracking

#### Option A: Eager line map (compute on construction)

Build the sorted array of line-start byte offsets when the text is first loaded.

- **Pro**: All subsequent line lookups are O(log L). No lazy state to manage.
- **Con**: Pays full O(n) scan cost upfront even if line numbers are never needed. For a compiler that always emits diagnostics, this cost is paid regardless.

#### Option B: Lazy line map (compute on first access)

Defer construction until the first line-number query.

- **Pro**: Zero cost if line numbers are never needed (e.g., a validator that only reports byte offsets).
- **Con**: Requires interior mutability or explicit construction step. Complicates Sendable conformance.

#### Option C: No line map in text-primitives (push to consumer)

Provide only the line map data structure; let the consumer decide when to build it.

- **Pro**: Maximum flexibility. text-primitives stays pure-value.
- **Con**: Every consumer reimplements the "build line map from text" step.

| Criterion | A: Eager | B: Lazy | C: Consumer-driven |
|-----------|:---:|:---:|:---:|
| Zero-cost if unused | No | Yes | Yes |
| API simplicity | Simple | Complex (mutability) | Simple |
| Sendable | Trivial | Requires care | Trivial |
| Reuse across consumers | Full | Full | Partial |

**Decision**: **Option C with a builder function**. text-primitives provides:

1. `Text.Line.Map` -- a value type holding the sorted array of line-start offsets.
2. `Text.Line.Map.init(scanning:)` -- a static builder that scans a byte sequence and returns the line map.
3. `Text.Line.Map.line(containing:)` -- O(log L) binary search returning a `Text.Line.Number`.
4. `Text.Line.Map.column(for:in:)` -- computes byte-offset column within a line.

The line map is a plain `Sendable` value type. The consumer decides when to construct it. This keeps text-primitives pure-value with no lazy state, while providing the complete line-resolution algorithm.

**Implementation**: The line map is a sorted array of `Text.Offset` values, where each entry is the byte offset of the first byte of a line. Line 1 always starts at offset 0. The array is constructed by scanning for line endings (LF, CR, CRLF) using `ASCII.LineEnding` definitions from ascii-primitives (available transitively through string-primitives).

---

### Decision 5: Column Representation

#### Option A: UTF-8 byte offset within line

Column = number of bytes from the start of the line to the position.

- **Pro**: Consistent with the primary position model (byte offsets everywhere). O(1) computation from byte offset and line-start offset.
- **Pro**: Used by Clang, rust-analyzer, swift-syntax.
- **Con**: Does not correspond to visual column for multi-byte characters. But visual column is not the job of a primitives package.

#### Option B: UTF-16 code unit offset

Column = number of UTF-16 code units from line start.

- **Pro**: Matches LSP default encoding.
- **Con**: Requires UTF-8 to UTF-16 transcoding. Unnatural for a UTF-8-native system. LSP 3.17+ allows negotiating UTF-8 encoding.

#### Option C: Unicode scalar offset

Column = number of Unicode scalar values from line start.

- **Pro**: Language-meaningful unit.
- **Con**: Requires scanning the line for multi-byte sequences. Not what any major compiler uses.

#### Option D: Grapheme cluster offset

- **Pro**: Most "correct" for user-visible columns.
- **Con**: Requires full UAX #29 segmentation. No compiler uses this. Extremely expensive.

| Criterion | A: UTF-8 byte | B: UTF-16 cu | C: Scalar | D: Grapheme |
|-----------|:---:|:---:|:---:|:---:|
| Computation cost | O(1) | O(n) | O(n) | O(n) + tables |
| Prior art | Clang, rust-analyzer, swift-syntax | LSP default | None | None |
| Consistency with position model | Perfect | Mismatch | Mismatch | Mismatch |
| User-visible accuracy | Poor for CJK/emoji | Moderate | Good | Best |
| Appropriate for primitives | Yes | No (protocol concern) | No | No |

**Decision**: **Option A** -- UTF-8 byte offset within line. Column is simply `position - lineStartPosition`, yielding a `Text.Offset.Count` (cardinal). This is O(1), consistent with the byte-offset position model, and matches Clang/rust-analyzer/swift-syntax. Protocol-specific column encodings (UTF-16 for LSP) are computed at integration boundaries, not stored in primitives.

---

### Decision 6: Encoding Awareness

#### Option A: Encoding-agnostic (parametric over encoding)

Generic over encoding type. Position types work with UTF-8, UTF-16, ASCII, etc.

- **Pro**: Maximum generality.
- **Con**: Enormous complexity for no practical benefit. All modern source files are UTF-8. All modern compilers assume UTF-8. Generic encoding support is YAGNI at the primitives layer.

#### Option B: UTF-8 assumed (the only encoding)

All positions, ranges, and line maps assume UTF-8 byte sequences.

- **Pro**: Simple. Matches reality -- UTF-8 is the universal encoding for source code, configuration files, and structured text.
- **Pro**: string-primitives already uses `UInt8` as the code unit on POSIX (the primary platform). Windows UTF-16 handling is a platform shim concern, not a text-position concern.
- **Con**: Cannot directly represent positions in UTF-16 encoded text. (Not needed at Layer 1.)

#### Option C: UTF-8 primary, with conversion hooks for other encodings

- **Pro**: Primary path is simple; escape hatches exist.
- **Con**: "Conversion hooks" at the primitives layer is premature abstraction.

| Criterion | A: Parametric | B: UTF-8 only | C: UTF-8 + hooks |
|-----------|:---:|:---:|:---:|
| Complexity | Very high | Minimal | Moderate |
| Practical utility | Low (all sources are UTF-8) | Full | Full |
| Consistency with ecosystem | Poor (no other primitives are encoding-generic) | Perfect | Moderate |

**Decision**: **Option B** -- UTF-8 assumed. All byte offsets are UTF-8 byte offsets. This matches the reality that UTF-8 is the universal encoding for all text that text-primitives will process. The `Text` namespace documentation states this assumption explicitly.

---

## Existing Infrastructure Analysis

### What text-primitives reuses from below

| Package | What it provides | How text-primitives uses it |
|---------|------------------|-----------------------------|
| ascii-primitives | `ASCII.LineEnding` (`.lf`, `.cr`, `.crlf`), `ASCII.ControlCharacters.lf` / `.cr` | Line map construction: scanning for line endings |
| ascii-primitives | `ASCII.Classification.isWhitespace()` | Potentially useful for whitespace-aware operations (future) |
| string-primitives | `String` (~Copyable, owned), `String.View` (~Copyable, ~Escapable), `String.Char` | The text that positions refer into |
| identity-primitives | `Tagged<Tag, RawValue>` | `Text.Offset = Tagged<Text, Ordinal>` |
| ordinal-primitives | `Ordinal`, `Ordinal.Protocol` | Position operations: `.successor`, `.predecessor`, `.advance`, `.distance` |
| cardinal-primitives | `Cardinal`, `Cardinal.Protocol` | Count operations: `.zero`, `.one`, `+`, `.subtract` |

### What text-primitives does NOT reuse

| Concept | Why not |
|---------|---------|
| `Index<T>` | `Index<T>` = `Tagged<T, Ordinal>` for element indexing. `Text.Offset` = `Tagged<Text, Ordinal>` for byte positioning. Same pattern, different tag. No reuse needed -- just the same infrastructure. |
| `Memory.Address` | `Memory.Address` = `Tagged<Memory, Ordinal>` for raw memory. Different domain, same pattern. |
| `Finite.Bound` / bounded ordinals | Text offsets are not statically bounded. File sizes are runtime-determined. |
| `Property.View` | Text positions are simple Copyable value types. No ~Copyable view machinery needed. |

### What source-primitives adds on top

| Concept | Why it belongs in source-primitives, not text-primitives |
|---------|----------------------------------------------------------|
| File identity (`Source.File`, file path, buffer ID) | Source-code-specific. A JSON parser does not need file identity. |
| Diagnostic locations (file + position + severity) | Compiler-specific aggregation of file identity + text position. |
| `#sourceLocation` directive support (virtual files, presumed locations) | Swift-language-specific feature. |
| Edit/patch operations (text replacement with position remapping) | Incremental compilation concern, not text positioning. |
| Multi-file position (position qualified by file) | Requires file identity, which is source-specific. |

---

## Outcome

**Status**: DECISION

### Summary of Decisions

| # | Question | Decision |
|---|----------|----------|
| 1 | Boundary | text-primitives: positions, ranges, line maps. source-primitives: file identity, diagnostics, edits. |
| 2 | Position model | `Text.Offset` = `Tagged<Text, Ordinal>` (UTF-8 byte offset). Inherits all ordinal operations. |
| 3 | Range model | `Text.Range` = half-open `[start, end)` pair of `Text.Offset`. |
| 4 | Line tracking | `Text.Line.Map` value type with builder + O(log L) binary search. Consumer decides when to construct. |
| 5 | Column | UTF-8 byte offset within line. Column = `position - lineStart`, yielding `Text.Offset.Count`. |
| 6 | Encoding | UTF-8 assumed. No encoding parameterization. |

### Proposed Type Inventory

| Type | Definition | File | Description |
|------|-----------|------|-------------|
| `Text` | `public enum Text {}` | `Text.swift` | Namespace for all text abstractions |
| `Text.Offset` | `public typealias Offset = Tagged<Text, Ordinal>` | `Text.Offset.swift` | UTF-8 byte offset into text (position) |
| `Text.Offset.Count` | inherited: `Tagged<Text, Cardinal>` | (inherited from Tagged) | Byte count / distance in text |
| `Text.Range` | `public struct Range: Sendable { let start, end: Text.Offset }` | `Text.Range.swift` | Half-open byte range `[start, end)` |
| `Text.Line` | `public enum Line {}` | `Text.Line.swift` | Namespace for line-related types |
| `Text.Line.Number` | `public struct Number: Sendable { let rawValue: UInt }` | `Text.Line.Number.swift` | 1-based line number |
| `Text.Line.Map` | `public struct Map: Sendable { ... }` | `Text.Line.Map.swift` | Sorted array of line-start offsets; provides O(log L) line resolution |
| `Text.Line.Column` | `public typealias Column = Text.Offset.Count` | `Text.Line.Column.swift` | UTF-8 byte offset within a line (alias for clarity) |
| `Text.Location` | `public struct Location: Sendable { let line: Text.Line.Number; let column: Text.Line.Column }` | `Text.Location.swift` | Derived line:column pair for human-readable display |

### Dependency Changes Required

The current `Package.swift` depends only on `swift-string-primitives`. To use `Tagged<Text, Ordinal>`, the following dependencies must be added:

```
swift-tagged-primitives    (tier 0, provides Tagged)
swift-ordinal-primitives     (tier 4, provides Ordinal, Ordinal.Protocol)
swift-cardinal-primitives    (tier 3, provides Cardinal, Cardinal.Protocol)
```

These are all lower-tier packages within swift-primitives. The dependency is downward-only and compliant with the tier architecture.

**Fallback**: If these dependencies are deemed too heavy for text-primitives' position in the tier chain, fall back to a dedicated `Text.Offset` struct wrapping `UInt` with hand-rolled operations. This loses ecosystem interop but preserves independence. The `Tagged` approach is strongly preferred.

### File Organization

Per [API-IMPL-005], one type per file:

```
Sources/Text Primitives/
    Text.swift                  -- enum Text {}
    Text.Offset.swift           -- typealias Text.Offset = Tagged<Text, Ordinal>
    Text.Range.swift            -- struct Text.Range
    Text.Line.swift             -- enum Text.Line {}
    Text.Line.Number.swift      -- struct Text.Line.Number
    Text.Line.Map.swift         -- struct Text.Line.Map
    Text.Line.Column.swift      -- typealias Text.Line.Column
    Text.Location.swift         -- struct Text.Location
```

### Usage Examples

```swift
import Text_Primitives

// Create positions
let start = Text.Offset.zero
let end = try start.advance.exact(by: Text.Offset.Count(42))

// Create a range
let range = Text.Range(start: start, end: end)
assert(range.count == Text.Offset.Count(42))

// Build a line map from UTF-8 bytes
let lineMap = Text.Line.Map(scanning: utf8Bytes)

// Resolve byte offset to line:column
let location = lineMap.location(for: someOffset)
// location.line == Text.Line.Number(7)
// location.column == Text.Offset.Count(14)

// Resolve back
let offset = lineMap.offset(for: location)
```

---

## References

### Compiler Position Models

- Clang `SourceLocation`: [llvm-mirror/clang SourceLocation.h](https://github.com/llvm-mirror/clang/blob/master/include/clang/Basic/SourceLocation.h)
- Clang `SourceManager`: [llvm-mirror/clang SourceManager.h](https://github.com/llvm-mirror/clang/blob/master/include/clang/Basic/SourceManager.h)
- rust-analyzer `text-size` crate: [github.com/rust-analyzer/text-size](https://github.com/rust-analyzer/text-size)
- rust-analyzer `TextRange`: [docs.rs/text-size TextRange](https://docs.rs/text-size/latest/text_size/struct.TextRange.html)
- rust-analyzer `LineIndex`: [rust-lang.github.io/rust-analyzer LineIndex](https://rust-lang.github.io/rust-analyzer/line_index/struct.LineIndex.html)
- rowan line/column discussion: [rowan issue #17](https://github.com/rust-analyzer/rowan/issues/17)
- Roslyn `TextSpan`: [dotnet/roslyn TextSpan.cs](https://github.com/dotnet/roslyn/blob/main/src/Compilers/Core/Portable/Text/TextSpan.cs)
- Roslyn `LinePosition`: [dotnet/roslyn LinePosition.cs](https://github.com/dotnet/roslyn/blob/main/src/Compilers/Core/Portable/Text/LinePosition.cs)
- swift-syntax `SourceLocation`: [swiftlang/swift-syntax SourceLocation.swift](https://github.com/swiftlang/swift-syntax/blob/main/Sources/SwiftSyntax/SourceLocation.swift)

### Tree-sitter

- tree-sitter `TSPoint` column is byte-based: [tree-sitter issue #397](https://github.com/tree-sitter/tree-sitter/issues/397)
- tree-sitter edit requires both byte offset and row/column: [tree-sitter discussion #1793](https://github.com/tree-sitter/tree-sitter/discussions/1793)
- tree-sitter API header: [tree-sitter/api.h](https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h)

### Position Representation

- Casey Muratori, "Byte Positions Are Better Than Line Numbers": [computerenhance.com](https://www.computerenhance.com/p/byte-positions-are-better-than-line)
- Hacker News discussion: [news.ycombinator.com](https://news.ycombinator.com/item?id=38922775)
- Red Hat, "Optimizing the Clang compiler's line-to-offset mapping": [developers.redhat.com](https://developers.redhat.com/blog/2021/05/04/optimizing-the-clang-compilers-line-to-offset-mapping)

### Protocol Standards

- LSP Specification 3.17: [microsoft.github.io](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/)
- LSP position encoding discussion: [LSP issue #872](https://github.com/microsoft/language-server-protocol/issues/872)
- Unicode UAX #29 Text Segmentation: [unicode.org](https://www.unicode.org/reports/tr29/)

### Swift Institute Infrastructure

- `Tagged<Tag, RawValue>`: `/Users/coen/Developer/swift-primitives/swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift`
- `Ordinal`: `/Users/coen/Developer/swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.swift`
- `Cardinal`: `/Users/coen/Developer/swift-primitives/swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.swift`
- `Index<T>`: `/Users/coen/Developer/swift-primitives/swift-index-primitives/Sources/Index Primitives Core/Index.swift`
- `ASCII.LineEnding`: `/Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.LineEnding.swift`
- Existing Infrastructure skill: `/Users/coen/Developer/.claude/skills/existing-infrastructure/SKILL.md`
