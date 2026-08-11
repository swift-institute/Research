# Source Location Model

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: DECISION
tier: 2
---
-->

## Context

`swift-source-primitives` is a Layer 1 primitives package (tier 9) that provides source-file-specific abstractions for a Swift compiler. It sits in a precise position in the dependency chain:

```
ascii-primitives (tier 0)
    -> string-primitives (tier 1)
        -> text-primitives (tier 1)
            -> source-primitives (tier 9)   <-- THIS PACKAGE
                -> swift-source (Layer 3, foundations)
                    -> swift-compiler (Layer 3, foundations)
```

**Trigger**: Before any token can be lexed, any AST node constructed, or any diagnostic emitted, the compiler needs types that answer: "where in the source is this?" The design of these types is foundational -- every subsequent compiler phase depends on them. Getting this wrong is expensive to fix because every downstream consumer (tokens, AST nodes, diagnostics) carries source location types.

**Constraints**:
- [API-NAME-001]: All types use Nest.Name pattern (`Source.File.ID`, not `SourceFileID`)
- [API-IMPL-005]: One type per file
- [API-ERR-001]: Typed throws only
- [PRIM-FOUND-001]: No Foundation imports
- Package uses Swift 6.2, platforms macOS 26+, strict memory safety
- All types must be `Sendable`

**Relationship to text-primitives**: text-primitives (currently empty) is the direct dependency. The boundary question -- what belongs in text-primitives vs source-primitives -- is a key design decision in this document.

**Relationship to swift-source (foundations)**: swift-source already defines `Source` as a namespace enum and provides `Source.Loader`, `Source.Cache`, and `Source.Error` for file I/O. It re-exports `Source_Primitives` via `@_exported public import`. The primitives layer defines types; the foundations layer adds I/O.

## Question

What source location infrastructure does a compiler need at the primitives layer, and how should it be decomposed between text-primitives and source-primitives?

Specifically:
1. What is the primary position representation?
2. How are source files identified?
3. How are ranges represented?
4. How is line/column information resolved?
5. What manages the registry of source files?
6. Where is the boundary between text-primitives and source-primitives?
7. What types support diagnostic display?

## Literature Study

### 1. swiftc (Apple Swift Compiler)

Source: [`swift/include/swift/Basic/SourceLoc.h`](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/SourceLoc.h), [`SourceManager.h`](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/SourceManager.h)

| Type | Representation | Notes |
|------|---------------|-------|
| `SourceLoc` | Pointer into source buffer (wraps `llvm::SMLoc`) | Cheaply copyable, comparable. Single value. |
| `SourceRange` | Half-open `[Start, End)` of two `SourceLoc` values | Both endpoints in same buffer. |
| `CharSourceRange` | `SourceLoc` + byte length | For diagnostics (text underlining). |
| `SourceManager` | Owns all source buffers. Each buffer gets a `BufferID`. | Central registry. Array-backed. |

Key design properties:
- `SourceLoc` is a **byte offset** into a buffer (concretely, a pointer). Line/column is computed on demand via `SourceManager::getLineAndColumn()`.
- Line maps are **sorted arrays of line-start byte offsets**, built lazily on first query per buffer.
- `SourceManager` provides: `getLineAndColumn(SourceLoc)`, `getText(SourceRange) -> StringRef`, `findBufferContainingLoc(SourceLoc) -> BufferID`.

### 2. Clang (LLVM C/C++/ObjC Compiler)

Source: [`clang/include/clang/Basic/SourceLocation.h`](https://github.com/llvm-mirror/clang/blob/master/include/clang/Basic/SourceLocation.h), [`SourceManager.h`](https://github.com/llvm/llvm-project/blob/main/clang/include/clang/Basic/SourceManager.h)

| Type | Representation | Notes |
|------|---------------|-------|
| `SourceLocation` | 32-bit offset into `SourceManager` encoding space | `FileID` + offset pair, packed. |
| `FileID` | Opaque integer. 0 = invalid, >0 = this module, <-1 = loaded from another module. | Lightweight handle. |
| `SourceRange` | Half-open pair of `SourceLocation` | Same file constraint implicit. |
| `PresumedLoc` | File + line + column after `#line` directive processing | Resolved representation. |
| `FullSourceLoc` | `SourceLocation` + `SourceManager*` | Self-contained (carries its resolver). |
| `SourceManager` | Central registry. Owns `MemoryBuffer` objects. Assigns `FileID`. | Array-backed mapping. |

Key design properties:
- `SourceLocation` is a **packed `FileID` + byte offset** in a single 32-bit integer. This enables a single value to encode both the file and the position.
- `SourceManager` can decompose a location into a raw `FileID + Offset` pair, where offset is from the start of the file's buffer.
- Max offset is 2^32-1 (2^63-1 for 64-bit source locations).
- Supports spelling locations (where bytes come from) vs expansion locations (where macro expansions appear to the user).

### 3. rust-analyzer (text-size crate)

Source: [`rust-analyzer/text-size`](https://github.com/rust-analyzer/text-size), [docs.rs/text-size](https://docs.rs/text-size/latest/text_size/struct.TextSize.html)

| Type | Representation | Notes |
|------|---------------|-------|
| `TextSize` | Newtype wrapper around `u32` | Byte offset. Copy, Clone, Eq, Ord, Hash. |
| `TextRange` | Pair of `TextSize` (start, end) | Half-open. Invariant: start <= end. |

Key design properties:
- **Extremely minimal**. Two types. No file identity. No line/column.
- `TextSize` supports arithmetic: `Add`, `Sub`, `checked_add`, `checked_sub`.
- `TextSize::of(text)` measures the UTF-8 byte length of a string.
- `TextRange` implements `RangeBounds<TextSize>`, can be shifted by adding/subtracting `TextSize`.
- Line indexing is handled separately by a `LineIndex` type that maps byte offsets to lines via a sorted array of newline positions.
- Design goal: "reducing storage requirements for offsets and ranges, under the assumption that 32 bits is enough."

### 4. Roslyn (C# Compiler)

| Type | Representation | Notes |
|------|---------------|-------|
| `TextSpan` | `start: int` + `length: int` | Not end offset -- uses length. |
| `LinePosition` | `line: int` + `character: int` | Resolved position. |
| `LinePositionSpan` | Pair of `LinePosition` | Resolved range. |
| `SourceText` | Owns content. Provides line mapping. | Per-file. |

Key design properties:
- Uses **start + length** rather than start + end for ranges. Unique among the surveyed compilers.
- `SourceText` owns content and provides line/character resolution.
- `LinePosition` is the resolved form; `TextSpan` is the cheap form.

### 5. swift-syntax (Apple SwiftSyntax Library)

Source: [`SwiftSyntax/SourceLocation.swift`](https://github.com/swiftlang/swift-syntax/blob/main/Sources/SwiftSyntax/SourceLocation.swift)

| Type | Representation | Notes |
|------|---------------|-------|
| `AbsolutePosition` | `Int` (UTF-8 byte offset from file start) | The cheap representation. |
| `SourceLocation` | `line: Int`, `column: Int`, `offset: Int`, `file: String` | The expensive representation. Has both offset and line/column. |
| `SourceRange` | `start: SourceLocation`, `end: SourceLocation` | Half-open. |
| `SourceLocationConverter` | Stores `[UInt8]` source + `SourceLineTable` | Converts `AbsolutePosition` <-> `SourceLocation`. |

Key design properties:
- Clean separation: `AbsolutePosition` (cheap, stored in nodes) vs `SourceLocation` (expensive, computed for display).
- `SourceLineTable` stores `lineEnds: SortedArray<AbsolutePosition>` and processes `#sourceLocation` directives.
- Line map built by scanning source text for `\n` (0x0A), `\r` (0x0D), and `\r\n` (0x0D 0x0A).
- `SourceLocationConverter` handles invalid UTF-8 (stores source as `[UInt8]`, not `String`).
- Binary search through line table for offset-to-line conversion.

### 6. tree-sitter

Source: [tree-sitter API documentation](https://tree-sitter.github.io/tree-sitter/using-parsers/2-basic-parsing.html)

| Type | Representation | Notes |
|------|---------------|-------|
| `TSPoint` | `row: uint32_t`, `column: uint32_t` | 0-indexed row/column. |
| `TSRange` | `start_point: TSPoint`, `end_point: TSPoint`, `start_byte: uint32_t`, `end_byte: uint32_t` | **Dual representation**: both byte offsets and row/column. |

Key design properties:
- **Stores both byte offsets AND row/column** in every node. This is unique among the surveyed systems.
- Justification: tree-sitter is incremental -- when text changes, both byte ranges and point ranges need updating, and having both avoids recomputation.
- Nodes expose: `ts_node_start_byte()`, `ts_node_end_byte()`, `ts_node_start_point()`, `ts_node_end_point()`.

### 7. Language Server Protocol (LSP)

Source: [LSP Specification 3.17](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/)

| Type | Representation | Notes |
|------|---------------|-------|
| `Position` | `line: uinteger`, `character: uinteger` | 0-based line, 0-based character offset within line. |
| `Range` | `start: Position`, `end: Position` | Half-open. |
| `TextDocumentPositionParams` | `textDocument: TextDocumentIdentifier`, `position: Position` | File + position. |

Key design properties:
- Character offset was historically **UTF-16 code units** (for historical compatibility with VS Code/JavaScript).
- Since LSP 3.17: server and client negotiate encoding (UTF-8, UTF-16, or UTF-32) via `positionEncodings` capability.
- LSP uses line/character as the primary representation (opposite of compiler internals). This is because editors think in lines.
- Conversion between LSP `Position` and byte offsets requires knowing the file content.

### Cross-Compiler Synthesis

| Property | swiftc | Clang | rust-analyzer | Roslyn | swift-syntax | tree-sitter | LSP |
|----------|--------|-------|---------------|--------|--------------|-------------|-----|
| Primary position | byte offset | packed ID+offset | u32 byte offset | int offset | int byte offset | dual (byte + row/col) | line + character |
| Range model | half-open (start, end) | half-open | half-open | start + length | half-open | half-open | half-open |
| File identity | BufferID (int) | FileID (int) | none | SourceText ref | file string | none | URI string |
| Line/column | lazy, on demand | lazy, on demand | separate LineIndex | SourceText methods | SourceLocationConverter | stored in nodes | primary repr |
| Line map | sorted array | sorted array | sorted array | internal | SortedArray | maintained incrementally | N/A |

**Universal consensus**:
1. **Byte offset** is the fundamental representation in all compiler implementations (5/5 compilers).
2. **Half-open ranges** (start..<end) in all implementations except Roslyn (start+length).
3. **Line maps as sorted arrays** of line-start offsets in all implementations that do lazy resolution (4/4).
4. **File identity as lightweight integer** in all multi-file compilers (swiftc, Clang).
5. **Lazy line/column resolution** in all compilers -- only computed for diagnostics.

## Existing Infrastructure Analysis

### ascii-primitives (Tier 0) -- Available

**Critical for line maps**: `ASCII.ControlCharacters.lf` (0x0A), `ASCII.ControlCharacters.cr` (0x0D), and `ASCII.LineEnding` (`.lf`, `.cr`, `.crlf`) define the line ending vocabulary. The line map builder in source-primitives will need to recognize all three forms.

`ASCII.Classification` provides O(1) byte classification via lookup table, useful for the lexer but not directly needed in source-primitives.

### string-primitives (Tier 1) -- Available

Provides `String` (`~Copyable`, `@unchecked Sendable`), `String.View` (`~Copyable`, `~Escapable`), `String.Char` (platform-native code unit), and `String.Length`. These are for OS path strings, not source content. Source content is `[UInt8]` (UTF-8 bytes).

### text-primitives (Tier 1) -- Empty

Currently a stub: 1 empty file, builds as empty module. Depends on string-primitives. Will provide the general text position/range types that source-primitives builds upon.

### index-primitives (Tier 7) -- Available

Provides `Index<Element>` as `Tagged<Element, Ordinal>` -- phantom-typed indices. Source.File.ID could potentially follow the `Tagged` pattern, but the simplicity of a plain `Int` wrapper may be more appropriate for a file ID that does not represent a collection position.

### swift-source (Layer 3) -- Partially Implemented

Already defines:
- `Source` namespace enum with doc comment
- `Source.Loader` -- POSIX `open`/`read`/`close` file loading, BOM stripping
- `Source.Cache` -- `Dictionary<String, [UInt8]>` path-to-content cache
- `Source.Error` -- `.fileNotFound`, `.openFailed`, `.readFailed` with errno
- `@_exported public import Source_Primitives`

The foundations layer is the consumer of source-primitives. It already references future integration with `Source.File.ID` and `Source.Manager` in its doc comments and research.

### swift-compiler (Layer 3) -- Research Only

Has `Research/phase-0-source-text-infrastructure.md` that proposes the same types being designed here, confirming the downstream need. Key extract:

> "Before any token can be lexed, any AST node constructed, or any diagnostic emitted, the compiler must be able to load source files, track positions within them, and represent ranges of source text."

### Namespace Ownership

`Source` is already defined as `public enum Source {}` in `swift-source` (foundations). Since source-primitives is re-exported by swift-source, the `Source` namespace enum must be defined in source-primitives and re-exported upward. This is the standard pattern: primitives define the namespace, foundations extend it.

## Design Decisions

### Decision 1: Boundary Between text-primitives and source-primitives

**Question**: What belongs in text-primitives (general text) vs source-primitives (source-file-specific)?

#### Option A: text-primitives provides positions and ranges

text-primitives defines `Text.Position` (byte offset) and `Text.Range` (half-open pair of offsets). source-primitives adds file identity, file-qualified locations, the manager, and diagnostic support.

**Pros**: Clean separation. Text position/range are general concepts usable beyond compilers. Follows the dependency chain's intent (text is general, source is specific).

**Cons**: Creates a coupling where source-primitives must compose Text types. If text-primitives defines line maps, source-primitives depends on that implementation.

#### Option B: text-primitives is minimal; source-primitives provides everything

text-primitives provides only `Text` namespace and encoding. source-primitives defines its own position, range, and line map types under the `Source` namespace.

**Pros**: source-primitives is self-contained. No coordination needed with text-primitives design. Can optimize for compiler use case.

**Cons**: Duplicates concepts. If text-primitives later adds positions/ranges, there are two competing representations.

#### Option C: text-primitives provides positions, ranges, AND line maps

text-primitives is the home for all text position infrastructure. source-primitives layers file identity on top.

**Pros**: Maximally reusable. Any text-processing package can use positions and line maps.

**Cons**: Line map is a compiler-specific concern (general text processing rarely needs line maps). Overloads text-primitives with compiler infrastructure.

#### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Separation of concerns | Good | Poor | Fair |
| Reusability of position/range | High | Low | High |
| source-primitives simplicity | Medium | High | High |
| text-primitives scope | Appropriate | Minimal | Overloaded |
| Alignment with Phase 0 plan | Yes | No | Partial |

**Decision: Option A** -- text-primitives provides `Text.Position` (byte offset) and `Text.Range` (half-open range). source-primitives adds file identity, file-qualified locations, the source manager, and line maps.

**Rationale**: Byte offsets and ranges are general text concepts. Line maps are compiler-specific (most text processing does not need them). The Phase 0 plan already proposes this split. The dependency chain is clean: source-primitives composes text-primitives types with file identity.

**Line maps**: Live in source-primitives, not text-primitives. They are tightly coupled to source file management (lazy computation per file, keyed by File.ID).

---

### Decision 2: Source.File.ID Design

**Question**: How should source files be identified within a compilation?

All multi-file compilers use lightweight integer handles: swiftc's `BufferID`, Clang's `FileID`. The alternative is passing file paths (strings), which is expensive for comparison and storage.

#### Option A: Plain Int wrapper

```swift
extension Source.File {
    public struct ID: Sendable, Equatable, Hashable, Comparable {
        public let rawValue: Int
    }
}
```

**Pros**: Zero overhead. Trivially copyable. Fast comparison. Simple.

**Cons**: No connection to the existing `Tagged`/`Index` infrastructure. No built-in arithmetic constraints.

#### Option B: Tagged<Source.File, Ordinal>

Use the index-primitives pattern: `typealias Source.File.ID = Tagged<Source.File, Ordinal>`.

**Pros**: Consistent with the ecosystem. Gets `Ordinal.Protocol` operations for free.

**Cons**: File IDs are not collection indices. They do not support arithmetic (you never compute `fileID + 1`). Bringing in the ordinal-primitives dependency chain (ordinal -> cardinal -> affine -> comparison -> identity -> property) for a simple integer wrapper is disproportionate.

#### Option C: Int-based struct with custom conformances

```swift
extension Source.File {
    public struct ID: Sendable, Equatable, Hashable, Comparable {
        @usableFromInline
        internal let rawValue: Int

        @inlinable
        internal init(_ rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}
```

**Pros**: Type-safe. No dependency on index-primitives. Internal-only raw value (cannot be constructed outside the module). Comparable for sorted storage.

**Cons**: Manual conformances (though trivial).

#### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Type safety | Good | Excellent | Excellent |
| Dependency cost | None | Heavy (6 packages) | None |
| Arithmetic prevention | No (rawValue is public) | No (ordinal has arithmetic) | Yes (rawValue is internal) |
| Ecosystem alignment | Fair | Excellent | Good |
| Simplicity | Excellent | Poor | Good |

**Decision: Option C** -- `Source.File.ID` as a struct with internal raw value. The file ID is a simple opaque handle, not a position in a collection. It must be `Equatable`, `Hashable`, `Comparable`, and `Sendable`, but it must NOT support arithmetic. Making `rawValue` internal prevents callers from constructing arbitrary IDs or performing meaningless arithmetic on them. Only `Source.Manager` creates IDs.

---

### Decision 3: Source.Location Design

**Question**: What is the fully-qualified "where" for any source entity?

A source location must answer: "which file, and where in that file?"

#### Option A: File.ID + byte offset (compact)

```swift
extension Source {
    public struct Location: Sendable, Equatable, Hashable {
        public let file: Source.File.ID
        public let offset: Text.Position
    }
}
```

**Pros**: Minimal. Two values. Cheap to copy and store. Follows swiftc/Clang pattern where line/column is resolved on demand.

**Cons**: Requires the manager to resolve line/column. Cannot display to user without resolution.

#### Option B: File.ID + line + column (resolved)

```swift
extension Source {
    public struct Location: Sendable, Equatable, Hashable {
        public let file: Source.File.ID
        public let line: Int
        public let column: Int
    }
}
```

**Pros**: Self-contained for display. No manager needed to render diagnostics.

**Cons**: Expensive to compute (requires line map). Larger storage. Every token and AST node carries extra data. Violates universal compiler convention (5/5 surveyed compilers use offset as primary).

#### Option C: File.ID + byte offset + separate Resolved type

```swift
extension Source {
    public struct Location: Sendable, Equatable, Hashable {
        public let file: Source.File.ID
        public let offset: Text.Position
    }
}

extension Source.Location {
    public struct Resolved: Sendable, Equatable {
        public let file: Source.File.ID
        public let line: Int
        public let column: Int
        public let offset: Text.Position
    }
}
```

**Pros**: Best of both worlds. Cheap primary representation. Resolved variant for diagnostics. Clear semantic distinction.

**Cons**: Two types to learn. But the naming makes the relationship clear.

**Decision: Option C** -- `Source.Location` stores `(file, offset)`. `Source.Location.Resolved` stores `(file, line, column, offset)`. This follows the universal compiler pattern of cheap primary representation with on-demand resolution.

**Rationale**: Every token and AST node will store a `Source.Location`. Storing line/column in every location would waste memory and require line maps to be computed eagerly. Line/column is only needed for diagnostics, error messages, and LSP integration -- a tiny fraction of all locations.

---

### Decision 4: Source.Range Design

**Question**: How should contiguous regions of source text be represented?

#### Option A: File.ID + Text.Range (half-open)

```swift
extension Source {
    public struct Range: Sendable, Equatable, Hashable {
        public let file: Source.File.ID
        public let start: Text.Position
        public let end: Text.Position
    }
}
```

**Pros**: Consistent with 6/7 surveyed systems (all except Roslyn). File.ID enforces same-file constraint. Start and end are both byte offsets.

**Cons**: Slightly more storage than start+length.

#### Option B: File.ID + start + length (Roslyn style)

```swift
extension Source {
    public struct Range: Sendable, Equatable, Hashable {
        public let file: Source.File.ID
        public let start: Text.Position
        public let length: Int
    }
}
```

**Pros**: Cannot have invalid ranges (end < start). Length is always non-negative.

**Cons**: Computing end requires addition. Does not match the dominant convention. Slicing requires converting back to start+end.

#### Option C: Two Source.Location values

```swift
extension Source {
    public struct Range: Sendable, Equatable, Hashable {
        public let start: Source.Location
        public let end: Source.Location
    }
}
```

**Pros**: Each endpoint is a full location (file + offset). Could support cross-file ranges.

**Cons**: Redundant file ID (stored twice). Cross-file ranges are not meaningful for compiler use. Wastes memory.

#### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Convention alignment | 6/7 compilers | 1/7 (Roslyn) | Novel |
| Storage efficiency | Good (3 values) | Good (3 values) | Poor (4 values) |
| Invariant safety | Needs start <= end | Length >= 0 natural | Needs same file |
| Slicing ergonomics | Direct | Needs addition | Direct but redundant |

**Decision: Option A** -- `Source.Range` stores `(file, start, end)` as a half-open range. This follows the dominant convention across swiftc, Clang, rust-analyzer, swift-syntax, tree-sitter, and LSP.

**Invariant**: `start <= end` and both offsets refer to positions within the file identified by `file`. This is enforced by construction (the manager produces valid ranges) rather than runtime checks in release builds.

---

### Decision 5: Source.Manager Design

**Question**: How should the central registry of source files be organized?

All multi-file compilers have a central manager: swiftc's `SourceManager`, Clang's `SourceManager`. It serves three roles: (1) file registration and ID assignment, (2) content access, and (3) line/column resolution.

#### Option A: Array-backed struct

```swift
extension Source {
    public struct Manager: Sendable {
        internal var files: [File]
        internal var lineMaps: [File.ID: LineMap]
    }
}
```

Files are stored in an array. `File.ID` is the array index. Line maps are computed lazily and cached.

**Pros**: O(1) file lookup by ID. Simple. Efficient. IDs are sequential integers.

**Cons**: Cannot remove files (array indices are permanent). Not concurrent.

#### Option B: Dictionary-backed struct

```swift
extension Source {
    public struct Manager: Sendable {
        internal var files: [File.ID: File]
        internal var nextID: Int
    }
}
```

**Pros**: Can remove files. Flexible.

**Cons**: O(1) amortized but more overhead than array. File.ID is not simply an index.

#### Comparison

| Criterion | Option A | Option B |
|-----------|----------|----------|
| Lookup speed | O(1) exact | O(1) amortized |
| Memory | Compact | Hash table overhead |
| File removal | Not supported | Supported |
| ID assignment | Sequential (index) | Sequential (counter) |
| Simplicity | Higher | Lower |

**Decision: Option A** -- Array-backed. `Source.File.ID` is the array index. Files are never removed during compilation (this matches every surveyed compiler). Line maps are stored in a parallel array, lazily computed.

**Concurrency**: The initial design is not internally synchronized. The struct is `Sendable` as a value type. For concurrent compilation in the future, wrap in an actor or use `Mutex`. This is consistent with `Source.Cache` in swift-source, which takes the same approach.

**Layer boundary**: `Source.Manager` lives in source-primitives and handles file registration, content access, and line/column resolution. It does NOT perform file I/O. Loading files from disk is the responsibility of `Source.Loader` in swift-source (foundations). The manager accepts pre-loaded content.

---

### Decision 6: Source.File Design

**Question**: What metadata does a source file entry contain?

#### Option A: Copyable struct (lightweight handle)

```swift
extension Source {
    public struct File: Sendable {
        public let id: File.ID
        public let path: Swift.String
        public let content: [UInt8]
    }
}
```

**Pros**: Simple. Contains everything needed. Copyable by default (String and [UInt8] are value types with COW).

**Cons**: Copying a file copies its content array (COW, but still). Large logical size.

#### Option B: ~Copyable struct (unique ownership)

```swift
extension Source {
    public struct File: ~Copyable, Sendable {
        public let id: File.ID
        public let path: Swift.String
        public let content: [UInt8]
    }
}
```

**Pros**: Prevents accidental duplication of potentially large content arrays. Ownership is clear.

**Cons**: Cannot store in multiple places. Manager would need to expose content via borrowing/Span rather than returning File values.

#### Option C: ID-only reference (content lives in manager)

The `Source.File` struct stores only metadata. Content lives exclusively in `Source.Manager` and is accessed via `manager.content(for: fileID)`.

```swift
extension Source {
    public struct File: Sendable, Equatable {
        public let id: File.ID
        public let path: Swift.String
    }
}
```

**Pros**: File is small and trivially copyable. Content is not duplicated. Clean separation of identity from storage.

**Cons**: Always need the manager to access content.

**Decision: Option C** -- `Source.File` is a lightweight metadata struct (ID + path). Content is owned by `Source.Manager` and accessed via the manager. This keeps `Source.File` small (it gets passed around and stored in various places) while keeping content in a single location.

**Rationale**: Following Clang's model where `FileID` is a lightweight handle and the `SourceManager` owns buffers. The file struct is Copyable because it contains only an Int-wrapper and a String (both COW value types). Content duplication is avoided because the `[UInt8]` lives only in the manager.

---

### Decision 7: Source.Snippet Design

**Question**: What type supports diagnostic display?

Diagnostics need to show a few lines of source text around an error location, with line numbers and a column indicator (caret). This is a presentation concern, but the primitives layer should provide the data extraction.

#### Option A: Dedicated Snippet type

```swift
extension Source {
    public struct Snippet: Sendable {
        public let lines: [(number: Int, text: [UInt8])]
        public let highlightLine: Int
        public let highlightColumn: Int
    }
}
```

**Pros**: Self-contained. Can be constructed once and passed to renderers.

**Cons**: Allocates arrays. More complex than needed at the primitives layer.

#### Option B: Manager method returning context lines

Rather than a dedicated type, `Source.Manager` provides a method that extracts context around a location. The diagnostic layer constructs its own display format.

**Pros**: Simpler. No new type. Diagnostic formatting is a higher-layer concern.

**Cons**: Less structured output.

#### Option C: Defer to foundations/components layer

Source.Snippet is not a primitives concern. The primitives layer provides the building blocks (locations, ranges, content access, line resolution). Snippet extraction is a composed operation that belongs in swift-source or diagnostic-primitives.

**Pros**: Keeps primitives minimal. Avoids premature design of diagnostic display.

**Cons**: Downstream must implement snippet extraction.

**Decision: Option C** -- Defer `Source.Snippet` to a higher layer. source-primitives provides `Source.Location`, `Source.Range`, `Source.Location.Resolved`, and content access via `Source.Manager`. This is sufficient for any higher layer to extract snippets. Diagnostic display is a presentation concern that does not belong in atomic building blocks.

**Rationale**: Layer 1 packages should be atomic. Snippet extraction involves policy decisions (how many context lines, how to handle tab expansion, how to render the caret) that are better made at the foundations or components layer.

## Proposed Type Inventory

### text-primitives Types

| Type | File | Description |
|------|------|-------------|
| `Text` | `Text.swift` | Namespace enum |
| `Text.Position` | `Text.Position.swift` | Byte offset into text (`Int` wrapper). `Sendable`, `Equatable`, `Hashable`, `Comparable`. |
| `Text.Range` | `Text.Range.swift` | Half-open `(start: Text.Position, end: Text.Position)`. `Sendable`, `Equatable`, `Hashable`. |

### source-primitives Types

| Type | File | Description |
|------|------|-------------|
| `Source` | `Source.swift` | Namespace enum |
| `Source.File` | `Source.File.swift` | Metadata: `id: File.ID`, `path: String`. Copyable, Sendable. |
| `Source.File.ID` | `Source.File.ID.swift` | Opaque file handle. Internal `rawValue: Int`. Sendable, Equatable, Hashable, Comparable. |
| `Source.Location` | `Source.Location.swift` | `file: File.ID`, `offset: Text.Position`. Sendable, Equatable, Hashable. |
| `Source.Location.Resolved` | `Source.Location.Resolved.swift` | `file: File.ID`, `line: Int`, `column: Int`, `offset: Text.Position`. Sendable, Equatable. |
| `Source.Range` | `Source.Range.swift` | `file: File.ID`, `start: Text.Position`, `end: Text.Position`. Sendable, Equatable, Hashable. |
| `Source.Manager` | `Source.Manager.swift` | Array-backed file registry. Assigns File.IDs. Owns content as `[UInt8]`. Lazy line maps. |
| `Source.Manager.LineMap` | `Source.Manager.LineMap.swift` | Sorted array of line-start byte offsets. Built lazily. Binary search for offset-to-line. |

### File Count

- text-primitives: 3 files (namespace + 2 types)
- source-primitives: 8 files (namespace + 7 types)
- Total: 11 new files

### Dependency Visualization

```
Source.Manager
    |-- owns --> [Source.File] (array of metadata)
    |-- owns --> [[UInt8]] (array of content, indexed by File.ID)
    |-- owns --> [Source.Manager.LineMap?] (lazy, per file)
    |
    |-- produces --> Source.File.ID (on register)
    |-- produces --> Source.Location.Resolved (on resolve)
    |-- accepts --> Source.Location, Source.Range (for queries)

Source.Location
    |-- contains --> Source.File.ID
    |-- contains --> Text.Position

Source.Range
    |-- contains --> Source.File.ID
    |-- contains --> Text.Position (start)
    |-- contains --> Text.Position (end)

Source.Manager.LineMap
    |-- contains --> [Text.Position] (sorted line-start offsets)
    |-- uses --> ASCII.ControlCharacters.lf, .cr (line detection)
```

## Outcome

**Status**: DECISION

Seven design decisions have been made:

1. **text-primitives provides `Text.Position` and `Text.Range`; source-primitives adds file identity and management.** Line maps live in source-primitives.

2. **`Source.File.ID` is an opaque struct with internal `rawValue: Int`.** Only `Source.Manager` creates IDs. No arithmetic. Sendable, Equatable, Hashable, Comparable.

3. **`Source.Location` stores `(file: File.ID, offset: Text.Position)`.** Line/column is NOT stored -- it is resolved on demand via `Source.Location.Resolved`.

4. **`Source.Range` is a half-open range `(file: File.ID, start: Text.Position, end: Text.Position)`.** Consistent with 6/7 surveyed systems.

5. **`Source.Manager` is array-backed.** `File.ID` is the array index. Owns content and line maps. Line maps computed lazily. No file I/O (loading is the foundations layer's job).

6. **`Source.File` is a lightweight Copyable metadata struct** (ID + path). Content lives in the manager.

7. **`Source.Snippet` is deferred** to a higher layer. Primitives provide the building blocks; diagnostic display is a composed concern.

### Implementation Sequence

1. Implement `Text`, `Text.Position`, `Text.Range` in text-primitives
2. Implement `Source`, `Source.File`, `Source.File.ID` in source-primitives
3. Implement `Source.Location`, `Source.Location.Resolved`, `Source.Range`
4. Implement `Source.Manager` and `Source.Manager.LineMap`
5. Update swift-source (foundations) to integrate with the new types

## References

- swiftc `SourceLoc.h`: https://github.com/swiftlang/swift/blob/main/include/swift/Basic/SourceLoc.h
- swiftc `SourceManager.h`: https://github.com/swiftlang/swift/blob/main/include/swift/Basic/SourceManager.h
- Clang `SourceLocation.h`: https://github.com/llvm-mirror/clang/blob/master/include/clang/Basic/SourceLocation.h
- Clang `SourceManager.h`: https://github.com/llvm/llvm-project/blob/main/clang/include/clang/Basic/SourceManager.h
- rust-analyzer `text-size` crate: https://github.com/rust-analyzer/text-size
- `TextSize` documentation: https://docs.rs/text-size/latest/text_size/struct.TextSize.html
- `TextRange` documentation: https://docs.rs/text-size/latest/text_size/struct.TextRange.html
- swift-syntax `SourceLocation.swift`: https://github.com/swiftlang/swift-syntax/blob/main/Sources/SwiftSyntax/SourceLocation.swift
- swift-syntax `SourceLocationConverter`: https://swiftpackageindex.com/swiftlang/swift-syntax/602.0.0/documentation/swiftsyntax/sourcelocationconverter
- tree-sitter basic parsing: https://tree-sitter.github.io/tree-sitter/using-parsers/2-basic-parsing.html
- LSP Specification 3.17: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
- Phase 0 plan: `swift-compiler/Research/phase-0-source-text-infrastructure.md`
- swift-source file loading design: `swift-source/Research/source-file-loading-design.md`
