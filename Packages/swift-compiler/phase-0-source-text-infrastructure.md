# Phase 0: Source and Text Infrastructure

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: RECOMMENDATION
tier: 3
---
-->

## Context

Phase 0 of the phased compiler implementation plan establishes the character-level and source-management infrastructure that every subsequent phase depends on. Before any token can be lexed, any AST node constructed, or any diagnostic emitted, the compiler must be able to load source files, track positions within them, and represent ranges of source text.

This document provides a detailed serial roadmap: which packages must be implemented or completed — and in what order — before Phase 0's deliverables are ready for Phase 1 (Lexical Analysis).

## Question

What is the exact implementation sequence for Phase 0, accounting for all package dependencies, their current state, and the types each must provide?

## Prior Art Survey

### swiftc Source Location Model

Apple's Swift compiler uses a layered source location model defined across `include/swift/Basic/` and `lib/Basic/`:

- **`SourceLoc`** — A single point in source text. Wrapper around `llvm::SMLoc` (an opaque pointer into a source buffer). Cheaply copyable, comparable.
- **`SourceRange`** — A half-open range `[Start, End)` of two `SourceLoc` values.
- **`SourceManager`** — Manages source buffers. Each buffer gets a `BufferID`. Provides `getLineAndColumn(SourceLoc) -> (line, column)`, `getText(SourceRange) -> StringRef`, and `findBufferContainingLoc(SourceLoc) -> BufferID`.
- **`CharSourceRange`** — Like `SourceRange` but with explicit character length (for diagnostics that need to underline text).

Key design properties:
1. `SourceLoc` is a **byte offset** into a buffer, not a line/column pair. Line/column is computed on demand.
2. Source buffers are **memory-mapped** or loaded into contiguous memory. `SourceLoc` is essentially a pointer.
3. Line/column computation uses a **line map** (sorted array of line-start offsets) built lazily on first query.

### swift-syntax Source Model

Apple's `swift-syntax` package uses a different, position-based model:

- **`AbsolutePosition`** — Byte offset from the start of the source file. Stored as `Int`.
- **`SourceLocation`** — `(line: Int, column: Int, offset: Int, file: String)`. Computed from `AbsolutePosition` by walking the source text.
- **`SourceRange`** — `(start: SourceLocation, end: SourceLocation)`.
- **`SyntaxArena`** — Arena allocator for syntax nodes. Source text is held in contiguous memory.

Key insight: swift-syntax separates the cheap representation (`AbsolutePosition` = byte offset) from the expensive representation (`SourceLocation` = line/column). Offset is stored; line/column is computed.

### Existing Swift Institute Infrastructure

The `swift-test-primitives` package already defines a `Test.Source.Location` type with `fileID`, `filePath`, `line`, `column`. This is test-specific but establishes the naming pattern.

## Analysis

### Current Package State (Dependency Order)

```
Layer          Package                    State              Files    Build
─────────────────────────────────────────────────────────────────────────────
Tier 0    ①  ascii-primitives            ✅ PRODUCTION       10       ✅
Tier 1    ②  string-primitives           ✅ PRODUCTION        4       ✅
Tier 1    ③  text-primitives             ❌ EMPTY SKELETON    0       ✅ (empty module)
Tier 9    ④  source-primitives           ❌ EMPTY SKELETON    0       ✅ (empty module)
Layer 3   ⑤  swift-source (foundations)  ❌ EMPTY + BROKEN    0       ❌ (wrong dep path)
```

### What Already Exists

#### ascii-primitives (10 files, zero dependencies)

Complete and production-ready. Provides:

| Type | API Surface |
|------|-------------|
| `ASCII` | Root namespace enum |
| `ASCII.Classification` | 10 predicates: `isWhitespace`, `isDigit`, `isLetter`, `isUppercase`, `isLowercase`, `isAlphanumeric`, `isHexDigit`, `isControl`, `isVisible`, `isPrintable` — all O(1) via 128-byte lookup table |
| `ASCII.Parsing` | `digit(_ byte:) -> UInt8?`, `hexDigit(_ byte:) -> UInt8?` |
| `ASCII.Serialization` | `digit`, `hexDigitUppercase`, `hexDigitLowercase`, `serializeDecimal` |
| `ASCII.Validation` | `isASCII(_ byte:)`, `isAllASCII(_:)` with SIMD fast path |
| `ASCII.GraphicCharacters` | 94 static `UInt8` constants for printable characters |
| `ASCII.ControlCharacters` | 33 static `UInt8` constants + `crlf` |
| `ASCII.SPACE` | `sp: UInt8` = 0x20 |
| `ASCII.CaseConversion` | `convert(_ byte:to:)`, branchless |
| `ASCII.LineEnding` | `.lf`, `.cr`, `.crlf` |
| `ASCII.Case` | `.upper`, `.lower` |

**Compiler relevance**: Directly used by the lexer for identifier/keyword classification, number literal parsing, whitespace skipping, and line ending detection.

#### string-primitives (4 files, depends on ascii-primitives)

Complete and production-ready. Provides:

| Type | Properties |
|------|------------|
| `String` | `~Copyable`, `@unchecked Sendable`. Owned null-terminated platform string. `pointer: UnsafePointer<Char>`, `count: Int`. Deallocates on deinit. |
| `String.Char` | `UInt8` on POSIX, `UInt16` on Windows |
| `String.CodeUnit` | Semantic alias for `Char` |
| `String.View` | `~Copyable`, `~Escapable`. Non-owning borrowed view with `@_lifetime` safety. `pointer`, `length`, `span`. |
| `String.terminator` | Static `Char` property (value 0) |
| `String.length(of:)` | Static method: compute length of null-terminated string |

Key initializers:
- `init(adopting:count:)` — adopt existing allocation
- `init(copying:)` — copy from View
- `init(ascii:)` — from StaticString literal

Key methods:
- `withUnsafePointer(_:)` — safe pointer access
- `consuming func take()` — ownership transfer
- `var view: String.View` — borrowed view
- `var span: Span<Char>` — span access

**Compiler relevance**: File path representation, identifier storage, string literal values. The `~Copyable` ownership model prevents accidental duplication of source buffers.

Has research document: `Research/OS Native Path String Semantics.md` (359 lines).

### What Must Be Built

#### Step 1: text-primitives

**Current state**: 1 empty file (`Text Primitives.swift`, 0 lines). Builds as empty module. Depends on string-primitives.

**Required for Phase 0**: text-primitives provides the text processing layer between raw strings and source-specific types. The source layer should not depend directly on string-primitives — text-primitives is the abstraction boundary.

**Proposed types**:

| Type | Purpose | Rationale |
|------|---------|-----------|
| `Text` | Namespace enum | Root namespace per [API-NAME-001] |
| `Text.Encoding` | Encoding enumeration | `.utf8`, `.utf16`, `.ascii`. Needed for source file encoding detection. |
| `Text.Position` | Offset within text | Byte offset into a text buffer. Lightweight (single `Int`). This is the cheap representation — equivalent to swiftc's `SourceLoc` and swift-syntax's `AbsolutePosition`. |
| `Text.Range` | Half-open range of positions | `start: Text.Position`, `end: Text.Position`. Equivalent to swiftc's `SourceRange`. |
| `Text.Line` | Line-tracking infrastructure | Maps byte offsets to line numbers. Lazily built sorted array of line-start offsets (swiftc's line map pattern). |
| `Text.Column` | Column within a line | 1-indexed column number. Computed from offset minus line start. |

**Design decisions**:

1. **`Text.Position` is a byte offset, not line/column.** This follows both swiftc and swift-syntax. Byte offsets are O(1) to create, O(1) to compare, and trivially serializable. Line/column is O(n) to compute (requires scanning for newlines) and should be deferred to demand.

2. **Line map is built lazily.** Most source positions never need line/column resolution (only diagnostics and error messages do). The line map is computed once per source buffer on first line/column query.

3. **`Text.Position` should be `Comparable`, `Hashable`, `Sendable`.** Positions are small values that get stored in tokens, AST nodes, and diagnostics.

**Estimated scale**: ~300–600 lines across 4–6 files.

**Depends on**: string-primitives (for `String.Char`, `Span<Char>`)

---

#### Step 2: source-primitives

**Current state**: 1 empty file (`Source Primitives.swift`, 0 lines). Builds as empty module. Depends on text-primitives.

**Required for Phase 0**: source-primitives specializes text infrastructure for source code. It adds the concept of a "source file" (named, loaded, identifiable) and source-specific location types.

**Proposed types**:

| Type | Purpose | Rationale |
|------|---------|-----------|
| `Source` | Namespace enum | Root namespace |
| `Source.File` | Loaded source file | Owns the text content of a single `.swift` file. Contains: `path` (file system path), `content` (the source text as bytes), `id` (unique identifier). Provides `span: Span<UInt8>` for zero-copy access. |
| `Source.File.ID` | Unique file identifier | Lightweight identifier for a source file within a compilation. Comparable, Hashable. Avoids passing full paths through the compiler pipeline. |
| `Source.Location` | Position within a source file | Combines `file: Source.File.ID` + `offset: Text.Position`. The fully-qualified "where" for any source entity. |
| `Source.Range` | Span within a source file | `file: Source.File.ID` + `range: Text.Range`. Represents a contiguous region of source text (for tokens, AST nodes, diagnostics). |
| `Source.Location.Resolved` | Human-readable location | `file: Source.File.ID` + `line: Int` + `column: Int`. Computed on demand from `Source.Location` + line map. Used only for diagnostics and error messages. |
| `Source.Manager` | Source file registry | Manages loaded source files. Assigns `Source.File.ID` values. Provides `load(path:) throws(Source.Error) -> Source.File.ID`, `text(for:) -> Span<UInt8>`, `resolve(_: Source.Location) -> Source.Location.Resolved`. |
| `Source.Error` | Typed error for source operations | `.fileNotFound(path:)`, `.encodingError(path:)`, `.readError(path:underlying:)` |
| `Source.Snippet` | Diagnostic source excerpt | Extracts a few lines of source text around a `Source.Location` for diagnostic display. Includes line numbers and column indicator. |

**Design decisions**:

1. **`Source.File` owns content as `[UInt8]` (UTF-8 bytes), not `String`.** Swift source files are always UTF-8 (per the Swift language specification). Storing as bytes avoids String's overhead and allows direct byte-level lexing. The `~Copyable` `String` from string-primitives is for OS path strings, not source content.

2. **`Source.File.ID` is an opaque index, not a path.** Following swiftc's `BufferID` pattern. Paths are stored once in the manager; everything else uses the lightweight ID.

3. **`Source.Manager` is the single owner of all source buffers.** This centralizes memory management and enables future memory-mapping.

4. **Line map lives in the manager, keyed by file ID.** Built lazily on first `resolve()` call per file.

5. **`Source.Location` stores `(fileID, offset)`, not `(fileID, line, column)`.** Following the swiftc/swift-syntax precedent. Offsets are cheap; line/column is derived.

**Estimated scale**: ~800–1,500 lines across 6–10 files.

**Depends on**: text-primitives (for `Text.Position`, `Text.Range`, `Text.Line`)

---

#### Step 3: swift-source (foundations)

**Current state**: 1 empty file (`Source.swift`, 0 lines). **BROKEN**: Package.swift has wrong dependency path (`../swift-primitives/swift-source-primitives` should be `../../swift-primitives/swift-source-primitives`).

**Required for Phase 0**: The foundations layer composes primitives into higher-level APIs. For source infrastructure, this means file loading (interacting with the OS), memory mapping, and potentially caching.

**Proposed types**:

| Type | Purpose | Rationale |
|------|---------|-----------|
| Re-exports `Source Primitives` | Make primitives available at foundations layer | Standard pattern: foundations re-export their primitives |
| `Source.Loader` | File system integration | Actually reads `.swift` files from disk. Uses platform-appropriate APIs. Returns `Source.File` instances. Handles encoding detection (BOM check). |
| `Source.Cache` | Compilation-scoped source cache | Prevents re-reading the same file. Maps paths to `Source.File.ID` values. Thread-safe for future parallel compilation. |

**Design decision**: The foundations layer adds OS interaction. Primitives define the types; foundations implement file I/O. This keeps primitives Foundation-free per [PRIM-FOUND-001].

**Bug fix required first**: Correct the dependency path in Package.swift.

**Estimated scale**: ~200–500 lines across 2–4 files.

**Depends on**: source-primitives

---

### Serial Roadmap

```
Step 0 ─── ascii-primitives ─────────────── ✅ DONE (10 files, production)
  │
Step 0 ─── string-primitives ────────────── ✅ DONE (4 files, production)
  │
Step 1 ─── text-primitives ──────────────── ❌ IMPLEMENT (~300–600 lines)
  │         Types: Text, Text.Position, Text.Range,
  │                Text.Line, Text.Column, Text.Encoding
  │
Step 2 ─── source-primitives ────────────── ❌ IMPLEMENT (~800–1,500 lines)
  │         Types: Source, Source.File, Source.File.ID,
  │                Source.Location, Source.Range,
  │                Source.Location.Resolved, Source.Manager,
  │                Source.Error, Source.Snippet
  │
Step 3 ─── swift-source (foundations) ───── ❌ IMPLEMENT (~200–500 lines)
  │         Fix: Correct dependency path in Package.swift
  │         Types: Source.Loader, Source.Cache
  │
  ╰─────── PHASE 0 COMPLETE ────────────── Feeds into Phase 1 (Lexer)
```

**Total new code**: ~1,300–2,600 lines across ~12–20 files.

### Dependency Graph Visualization

```
                    ┌─────────────────────────┐
                    │   swift-source (L3)      │
                    │   Source.Loader          │
                    │   Source.Cache           │
                    └────────┬────────────────┘
                             │ depends on
                    ┌────────▼────────────────┐
                    │   source-primitives      │
                    │   Source.File            │
                    │   Source.Location        │
                    │   Source.Range           │
                    │   Source.Manager         │
                    └────────┬────────────────┘
                             │ depends on
                    ┌────────▼────────────────┐
                    │   text-primitives        │
                    │   Text.Position          │
                    │   Text.Range             │
                    │   Text.Line              │
                    └────────┬────────────────┘
                             │ depends on
                    ┌────────▼────────────────┐
                    │   string-primitives  ✅  │
                    │   String (~Copyable)     │
                    │   String.View            │
                    │   String.Char            │
                    └────────┬────────────────┘
                             │ depends on
                    ┌────────▼────────────────┐
                    │   ascii-primitives   ✅  │
                    │   ASCII.Classification   │
                    │   ASCII.LineEnding       │
                    └──────────────────────────┘
```

### What Phase 0 Feeds Into

Once Phase 0 is complete, five downstream primitives packages and their foundations counterparts are unblocked:

| Downstream Package | What It Needs from Phase 0 |
|-------------------|---------------------------|
| `token-primitives` | `Source.Location` to attach positions to tokens; `Source.Range` for token spans |
| `diagnostic-primitives` | `Source.Location` for error positions; `Source.Range` for underlines; `Source.Snippet` for context display |
| `lexer-primitives` | `Source.Manager` to access source bytes; `Text.Position` to track lexer cursor; `ASCII.Classification` for character dispatch |
| `abstract-syntax-tree-primitives` | `Source.Range` to attach source spans to AST nodes |
| `module-primitives` | `Source.File.ID` to associate declarations with source files |

### Related Infrastructure (Available But Not Direct Dependencies)

The following populated packages exist in the primitives layer and may be useful during Phase 0 implementation, though they are NOT in the dependency chain:

| Package | Files | Relevance |
|---------|-------|-----------|
| `binary-primitives` | 54 | Endianness, byte-level operations — useful for BOM detection |
| `memory-primitives` | 38 | `Memory.Address`, alignment, contiguous access — could back `Source.File` storage |
| `buffer-primitives` | 119 | `Buffer.Linear` — could back growable source buffers |
| `input-primitives` | 19 | `Input.Protocol` with checkpoint/restore — could back lexer cursor |
| `index-primitives` | — | `Index<T>` phantom-typed indices — could type `Source.File.ID` |

These packages are NOT prerequisites. Phase 0 should use `[UInt8]` and `Span<UInt8>` directly for source content. Integrating with the broader primitives infrastructure can happen in a later refinement pass.

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| text-primitives scope creep (too many text processing features) | Medium | Delays Phase 0 | Implement ONLY what source-primitives needs. General text processing can be added later. |
| Source.Manager design doesn't scale to incremental compilation | Low | Requires redesign in Phase 7 | Design with extensibility in mind (opaque File.ID, lazy line maps) but don't implement incremental features yet. |
| `~Copyable` complications in source types | Medium | Debugging time | Source.File should be `~Copyable` (owns buffer). Source.Location and Source.Range should be plain Copyable value types (just integers). |
| Broken swift-source Package.swift path | Certain | Blocks foundations build | Fix before any foundations work. One-line change. |
| Text.Position vs existing Index<T> pattern tension | Low | Naming confusion | Text.Position is domain-specific (byte offset in text), not a generic index. Different concept, different type. |

## Outcome

**Status**: RECOMMENDATION

### Serial Implementation Order

1. **Fix `swift-source` Package.swift** — Change `../swift-primitives/swift-source-primitives` to `../../swift-primitives/swift-source-primitives`. One-line fix. Do this first so the foundations package can build.

2. **Implement `text-primitives`** (~300–600 lines) — `Text.Position`, `Text.Range`, `Text.Line`, `Text.Column`, `Text.Encoding`. Minimal: only what source-primitives needs. No general text processing.

3. **Implement `source-primitives`** (~800–1,500 lines) — `Source.File`, `Source.File.ID`, `Source.Location`, `Source.Range`, `Source.Location.Resolved`, `Source.Manager`, `Source.Error`, `Source.Snippet`. The core deliverable of Phase 0.

4. **Implement `swift-source` (foundations)** (~200–500 lines) — `Source.Loader`, `Source.Cache`. OS integration for file loading.

### Prerequisites Summary

| Package | Status | Action Needed |
|---------|--------|---------------|
| ascii-primitives | ✅ Production (10 files) | None |
| string-primitives | ✅ Production (4 files) | None |
| text-primitives | ❌ Empty | **Implement** (Step 1) |
| source-primitives | ❌ Empty | **Implement** (Step 2) |
| swift-source | ❌ Empty + broken path | **Fix path + implement** (Step 3) |

### Design Principles

1. **Byte offsets are the fundamental position representation.** Line/column is derived, never stored as primary.
2. **Source files own their content.** `Source.File` is `~Copyable`. Positions and ranges are plain `Copyable` value types.
3. **Lazy line maps.** Don't compute line/column until someone asks for it (diagnostics).
4. **UTF-8 assumption.** Swift source is always UTF-8. No need for multi-encoding support in source-primitives.
5. **Primitives don't do I/O.** File loading lives in `swift-source` (foundations). Primitives define types only.

## References

- swiftc `SourceLoc.h`: https://github.com/swiftlang/swift/blob/main/include/swift/Basic/SourceLoc.h
- swiftc `SourceManager.h`: https://github.com/swiftlang/swift/blob/main/include/swift/Basic/SourceManager.h
- swift-syntax `AbsolutePosition.swift`: https://github.com/swiftlang/swift-syntax/blob/main/Sources/SwiftSyntax/AbsolutePosition.swift
- Phased compiler implementation plan: `swift-compiler/Research/phased-compiler-implementation-plan.md`
- String primitives research: `swift-string-primitives/Research/OS Native Path String Semantics.md`
