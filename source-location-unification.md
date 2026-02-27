# Source Location Unification

<!--
---
version: 3.0.0
last_updated: 2026-02-27
status: DECISION
tier: 2
---
-->

## Context

The Swift Institute ecosystem contains two independent source location types that represent the same concept — "a position in a source file identified by file, line, and column":

| Package | Type | Tier | Stored Properties | Conformances |
|---------|------|------|-------------------|--------------|
| swift-source-primitives | `Source.Location.Resolved` | 7 | `file: Source.File.ID`, `line: Int`, `column: Int`, `offset: Text.Position` | Sendable, Equatable, CustomStringConvertible |
| swift-test-primitives | `Test.Source.Location` | 20 | `fileID: String`, `filePath: String?`, `line: Int`, `column: Int` | Sendable, Hashable, Codable, Comparable, CustomStringConvertible |

Both types carry line and column (1-based). They differ in how they identify the file: an opaque integer handle vs self-contained strings.

Additionally, `Source.Location.Resolved` is structurally a product of `Source.Location` (file handle + byte offset) and a `(line, column)` pair. That `(line, column)` pair is an independently meaningful primitive — it appears in editors, LSP, diagnostics, and test reporting — but has no dedicated type today.

### Trigger

Design question arose during review of swift-source-primitives reusability. The hypothesis: these SHOULD be unified, and the unification produces a better type for both domains. The deeper insight: both types contain a shared substructure `(line, column)` that should be factored into a reusable primitive, then composed with domain-specific file identity.

### Prior Research

The `text-position-model.md` research (DECISION, Tier 2) in swift-text-primitives already defines this decomposition:

| Planned Type | Definition | Purpose |
|---|---|---|
| `Text.Line.Number` | `struct { let rawValue: UInt }` | 1-based line number |
| `Text.Line.Column` | `typealias = Text.Count` | UTF-8 byte offset within line |
| `Text.Location` | `struct { let line: Text.Line.Number; let column: Text.Line.Column }` | Human-readable line:column pair |
| `Text.Line.Map` | sorted `[Text.Position]` | Resolves `Text.Position` → `Text.Location` via O(log L) binary search |

These types are designed but **not yet implemented** in text-primitives.

### Constraints

- **Tier direction**: test-primitives (tier 20) CAN depend on source-primitives (tier 7) and text-primitives (tier 6). The reverse is impossible.
- **~Copyable cascade**: `String_Primitives.String` is ~Copyable. If a location type stores it, every container (Test.Event, Test.Issue, etc.) becomes ~Copyable. Not viable.
- **Codable requirement**: Test locations must serialize to JSON for cross-process interchange.
- **Self-containment**: Test locations currently carry all display information. Compiler locations defer display to Source.Manager.
- **Existing research**: `string-path-type-unification.md` (Tier 3, IN_PROGRESS) covers the broader string/path type architecture.
- **Existing research**: `text-position-model.md` (Tier 2, DECISION) defines Text.Location as the line:column primitive.

### Scope

Ecosystem-wide. Affects swift-text-primitives (Layer 1, Tier 6), swift-source-primitives (Layer 1, Tier 7), and swift-test-primitives (Layer 1, Tier 20), with implications for any future consumer of source locations (diagnostics, LSP, logging, debugging).

---

## Question

**What is the correct type decomposition for source location representation, and how should the shared `(line, column)` structure be factored into reusable primitives?**

Sub-questions:
1. Should the `(line, column)` pair live in text-primitives as `Text.Location` (per the existing research design)?
2. What is the correct naming for compact (byte offset) vs human-readable (line:column) source positions?
3. How should file identity compose with text location for the Source domain?
4. Can the "Resolved" concept be eliminated in favor of existing naming conventions?
5. Where does the self-contained display form (with file strings) live?

---

## Analysis

### Structural Observation

`Source.Location.Resolved` is a product type:

```
Source.Location.Resolved  ≅  Source.File.ID × Text.Position × Int × Int
                          ≅  Source.Location × (line: Int, column: Int)
```

The `(line, column)` component is independently useful and appears everywhere text positions are displayed. It deserves to be its own primitive: `Text.Location` (per `text-position-model.md`).

### Existing Naming Pattern: Position vs Location

The text-primitives research already establishes a naming distinction:

| Name | Meaning | Coordinate System | Example |
|------|---------|-------------------|---------|
| **Position** | Byte offset in a 1D stream | Linear (O(1) access) | `Text.Position` = byte 42 |
| **Location** | Line + column in a 2D grid | Grid (human-readable) | `Text.Location` = line 3, column 7 |

"Position" is machine-oriented (compact, efficient). "Location" is human-oriented (readable, displayable). The line map is the transformation between them.

This distinction exists implicitly in every compiler:
- swiftc: `SourceLoc` (byte offset) vs diagnostic display (file:line:column)
- Clang: `SourceLocation` (encoded offset) vs `PresumedLoc` (filename, line, column)
- LSP: `Position` (line, character within a document) vs `Location` (URI + range)

### Option A: Flat Unification (v1.0 approach)

Replace both types with a single self-contained struct in source-primitives:

```swift
extension Source.Location {
    public struct Resolved: Sendable, Hashable, Codable, Comparable {
        public let fileID: String
        public let filePath: String?
        public let line: Int
        public let column: Int
    }
}
```

**Assessment**: Works, but introduces the custom concept "Resolved" which has no precedent beyond this single type. Stores raw `Int` for line and column rather than composing from typed primitives. Misses the opportunity to factor `(line, column)` into a reusable type that editors, LSP, and other tools can share independently.

### Option B: Primitive Decomposition

Factor `(line, column)` into `Text.Location` (per the existing research design), then compose:

**Layer 1: Text primitives (tier 6)** — implement the already-designed types:

```swift
// text-primitives — already designed in text-position-model.md

extension Text.Line {
    /// A 1-based line number.
    public struct Number: Sendable, Hashable, Codable, Comparable {
        public let rawValue: UInt
    }
}

extension Text.Line {
    /// UTF-8 byte offset within a line (1-based).
    public typealias Column = Text.Count
}

extension Text {
    /// A human-readable position in text, expressed as line and column.
    public struct Location: Sendable, Hashable, Codable, Comparable {
        public let line: Text.Line.Number
        public let column: Text.Line.Column
    }
}
```

`Text.Line.Map` gains a natural composition method:

```swift
extension Text.Line.Map {
    /// Resolves a byte offset to a line:column location.
    public func location(for offset: Text.Position) -> Text.Location
}
```

**Layer 2: Source primitives (tier 7)** — rename and restructure:

The current `Source.Location` (file handle + byte offset) becomes `Source.Position`:

```swift
extension Source {
    /// A compact position in a source file: file handle + byte offset.
    /// Stored in tokens and AST nodes.
    public struct Position: Sendable, Equatable, Hashable {
        public let file: Source.File.ID
        public let offset: Text.Position
    }
}
```

The current `Source.Location.Resolved` becomes `Source.Location`, composing file identity with `Text.Location`:

```swift
extension Source {
    /// A human-readable location in a source file: file identity + line:column.
    /// Self-contained — carries all information needed for display.
    public struct Location: Sendable, Hashable, Codable, Comparable,
                            CustomStringConvertible {
        public let fileID: String
        public let filePath: String?
        public let position: Text.Location

        public init(
            fileID: String,
            filePath: String? = nil,
            position: Text.Location
        ) { ... }

        // Convenience for call-site capture
        public init(
            fileID: String,
            filePath: String? = nil,
            line: Int,
            column: Int
        ) { ... }
    }
}
```

**Composition**: `Source.Location ≅ FileIdentity × Text.Location`

`Source.Manager` transforms between the two forms:

```swift
extension Source.Manager {
    /// Resolves a compact source position to a human-readable source location.
    public mutating func location(
        for position: Source.Position
    ) -> Source.Location {
        let file = file(for: position.file)
        let map = lineMap(for: position.file)
        let textLocation = map.location(for: position.offset)
        return Source.Location(
            fileID: file.fileID,
            filePath: file.filePath,
            position: textLocation
        )
    }
}
```

**Layer 3: Test primitives (tier 20)** — typealias:

```swift
extension Test.Source {
    public typealias Location = Source.Location
}
```

### Option C: Primitive Decomposition, Source.Location in Separate Module

Same as Option B, but factor `Source.Location` into its own module within source-primitives that depends only on text-primitives (for `Text.Location`), not on the full Source Primitives module:

```
source-primitives/
  Sources/
    Source Location/              ← depends on Text Primitives only
      Source.swift                   (namespace shell)
      Source.Location.swift          (the unified type)
    Source Primitives/             ← depends on Text Primitives + Source Location
      Source.Position.swift          (was: Source.Location)
      Source.File.swift
      Source.File.ID.swift
      Source.Range.swift
      Source.Manager.swift
```

test-primitives depends on `Source Location` (not `Source Primitives`). Transitive dependency: only text-primitives (tier 6).

**Assessment**: Adds a module but gives test-primitives the narrowest possible dependency. Whether this granularity is worth it depends on how heavy the Source Primitives module is.

### Comparison

| Criterion | A: Flat (Resolved) | B: Decomposed | C: Decomposed + Factored |
|-----------|-------------------|---------------|--------------------------|
| Reusable (line, column) primitive | No | Yes (`Text.Location`) | Yes (`Text.Location`) |
| New concepts introduced | "Resolved" | None (Position/Location already in ecosystem) | None |
| Consistent with text-position-model.md | No | Yes (implements planned types) | Yes |
| Product structure explicit | No (flat Int fields) | Yes (`position: Text.Location`) | Yes |
| Deps added to test-primitives | source-primitives (tier 7) | source-primitives (tier 7) | Source Location module (tier 7, narrow) |
| Transitive deps for test-primitives | text(6)→affine(5) | text(6)→affine(5) | text(6)→affine(5) |
| Module count impact | +1 | 0 (rename only) | +1 |
| Naming consistency | "Resolved" is ad-hoc | Position/Location mirrors Text domain | Same as B |

### Naming Analysis

The rename `Source.Location` → `Source.Position` and `Source.Location.Resolved` → `Source.Location` follows the existing convention:

| Domain | Compact (machine) | Human-readable (display) |
|--------|--------------------|-----------------------|
| Text | `Text.Position` (byte offset) | `Text.Location` (line:column) |
| Source | `Source.Position` (file + byte offset) | `Source.Location` (file + line:column) |

No new concepts. "Position" and "Location" are already in the ecosystem. The rename makes them consistent across domains.

### Source.Range Implications

`Source.Range` currently stores `file: Source.File.ID, start: Text.Position, end: Text.Position`. Under Option B, this would become `Source.Range` containing `Source.Position` values or remaining as-is (it's already essentially a pair of Source.Positions sharing a file ID). No forced change.

### File Identity: fileID vs filePath

Swift provides two file identification mechanisms at the call site:
- `#fileID` → `"Module/File.swift"` (stable, short, module-relative)
- `#filePath` → `"/absolute/path/to/File.swift"` (full path, platform-specific)

The current Test.Source.Location stores both. Source.File stores only a `path` field.

For Source.Manager, `register()` would gain a `fileID` parameter:

```swift
public mutating func register(
    fileID: String,
    filePath: String,
    content: [UInt8]
) -> Source.File.ID
```

This lets the compiler provide a module-relative identifier alongside the full path. The manager doesn't guess.

### Swift.String in Primitives

`Source.Location` stores `fileID: String` and `filePath: String?` using `Swift.String` (standard library). This is correct because:

- `#fileID` and `#filePath` produce `Swift.String`
- These are symbolic identifiers for human display, not OS-native byte buffers for syscalls
- `String_Primitives.String` (~Copyable) would cascade non-copyability through every container
- `string-path-type-unification.md` identifies this as the boundary between OS-native strings (primitives) and display strings (foundations and above)

---

## Prior Art Survey

### Swift Testing Framework (apple/swift-testing)

`SourceLocation` carries `fileID: String`, `_filePath: String`, `line: Int`, `column: Int`. Conforms to `Sendable, Codable, Equatable, Hashable`. Our Test.Source.Location mirrors this. Note: swift-testing stores `(line, column)` as flat `Int` fields — no separate line:column type.

### Swift Compiler (swiftc)

`SourceLoc` is a single `const char*` pointer into a source buffer (equivalent to byte offset). `SourceManager` resolves to line:column for diagnostic display. Two-level compact/display pattern.

### Clang

`SourceLocation` is a 32-bit encoded offset. `SourceManager` resolves to `PresumedLoc` (filename, line, column). `PresumedLoc` is self-contained — carries `const char*` filename. The naming: SourceLocation = compact position, PresumedLoc = display location.

### Rust (codespan)

`codespan-reporting` uses `Files` trait (file database) with `line_index()` and `column_number()` methods. Locations are `FileId + byte range`. Display resolution produces self-contained `Location { file_id, line_number, column_number }`.

### LSP (Language Server Protocol)

LSP defines:
- `Position` = `{ line: uint, character: uint }` — a point in a document (line:column)
- `Location` = `{ uri: string, range: Range }` — a location in a document (file + range)

Note: LSP uses "Position" for line:character within a document and "Location" for file-qualified position. This exactly parallels our decomposition: `Text.Location` ≈ LSP `Position`, `Source.Location` ≈ LSP `Location`.

### Pattern

Every mature system:
1. Stores compact handles/offsets internally
2. Resolves to self-contained file + line:column at display/serialization boundaries
3. The `(line, column)` pair is always a distinct concept, whether named explicitly or not

---

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: **Option B** — Primitive Decomposition.

### Summary

Implement the types already designed in `text-position-model.md` (`Text.Location`, `Text.Line.Number`, `Text.Line.Column`, `Text.Line.Map`), then restructure source-primitives to compose from them:

| Current | Proposed | Change |
|---------|----------|--------|
| — | `Text.Location` | New (implement planned type from text-position-model.md) |
| — | `Text.Line.Number` | New (implement planned type) |
| — | `Text.Line.Column` | New (implement planned typealias) |
| `Source.Location` | `Source.Position` | Rename (file handle + byte offset) |
| `Source.Location.Resolved` | `Source.Location` | Rename + restructure (file strings + `Text.Location`) |
| `Test.Source.Location` | `typealias = Source.Location` | Replace with typealias |
| `Source.Manager.resolve(_:)` | `Source.Manager.location(for:)` | Rename (no "resolve" concept) |
| `Source.Manager.LineMap` | Move to `Text.Line.Map` | Move (line map is a Text concept, not Source) |

### Full Type Decomposition

```
Text.Line.Number        — primitive (1-based line number, UInt)
Text.Line.Column        — primitive (1-based column, typealias for Text.Count)
Text.Location           — Text.Line.Number × Text.Line.Column
Text.Line.Map           — resolves Text.Position → Text.Location

Source.File.ID          — primitive (opaque file handle, Int)
Source.Position         — Source.File.ID × Text.Position        (compact, machine)
Source.Location         — String × String? × Text.Location      (display, self-contained)
Source.Manager          — transforms Source.Position → Source.Location

Test.Source.Location    — typealias for Source.Location
```

### Resolved Questions

#### Q1: Text.Line.Map Placement

**DECISION**: Move to text-primitives as `Text.Line.Map`.

The `text-position-model.md` DECISION explicitly places it there: *"The line map is a plain Sendable value type. The consumer decides when to construct it. This keeps text-primitives pure-value with no lazy state."*

The current `Source.Manager.LineMap` is a reference implementation. Under this change:
- `Text.Line.Map` lives in text-primitives with the same data structure (sorted `[Text.Position]`, binary search)
- `Text.Line.Map.init(scanning:)` scans `[UInt8]` for line endings (LF, CR, CRLF)
- `Text.Line.Map.location(for:)` returns `Text.Location` (the new composition method)
- `Source.Manager` stores `[Text.Line.Map?]` and delegates to it
- `Source.Manager.LineMap` is removed (replaced by `Text.Line.Map`)

text-primitives owning line map state is fine — it's a plain `Sendable` value type (a sorted array), not lazy or mutable state. The consumer explicitly constructs it via `init(scanning:)`.

#### Q2: Separate Module for Source.Location

**DECISION**: No. test-primitives depends on Source Primitives directly.

Source Primitives transitively pulls in 9 packages (text → affine → ordinal, cardinal, equation, comparison, property, hash, identity). These are all tier 0-5 structural primitives with zero external dependencies. test-primitives at tier 20 already depends on heavier packages (async at tier 19). The dependency weight is negligible.

test-primitives seeing compiler types (Source.Position, Source.File.ID, Source.Manager) in the namespace is harmless — unused types have no cost. Factoring Source.Location into its own module would require declaring `enum Source {}` as a namespace shell in a separate module, adding complexity for no practical benefit.

#### Q3: Source.Range

**DECISION**: No change. Current design is correct.

`Source.Range` stores `file: Source.File.ID, start: Text.Position, end: Text.Position`. Storing two `Source.Position` values would duplicate the file ID. The current design correctly factors out the shared file identity. The rename `Source.Location` → `Source.Position` does not affect `Source.Range`.

#### Q4: Convenience Init on Source.Location

**DECISION**: Both forms exist.

```swift
extension Source {
    public struct Location: Sendable, Hashable, Codable, Comparable,
                            CustomStringConvertible {
        public let fileID: String
        public let filePath: String?
        public let position: Text.Location

        /// Memberwise init — exposes the product structure.
        public init(
            fileID: String,
            filePath: String? = nil,
            position: Text.Location
        )

        /// Convenience init — preserves call-site ergonomics.
        /// Wraps line and column into a Text.Location internally.
        public init(
            fileID: String,
            filePath: String? = nil,
            line: Int,
            column: Int
        )
    }
}
```

The convenience init preserves current test call sites unchanged:
```swift
Source.Location(fileID: #fileID, filePath: #filePath, line: #line, column: #column)
```

The memberwise init exposes the composition for consumers that already have a `Text.Location`:
```swift
let textLoc = lineMap.location(for: offset)
Source.Location(fileID: file.fileID, filePath: file.filePath, position: textLoc)
```

#### Q5: Text.Line.Number from Int

**DECISION**: Follow the established Ordinal/Cardinal pattern exactly.

| Constructor | Signature | Behavior |
|---|---|---|
| Primary | `init(_ value: UInt)` | Non-failing. Line numbers are non-negative. |
| Validated | `init(_ value: Int) throws(Error)` | Throws typed error if negative. For untrusted runtime data. |
| Failable | `init?(exactly value: Int)` | Returns nil if negative. |
| Literal | `ExpressibleByIntegerLiteral` | Compile-time safety for literals. |

The convenience init on `Source.Location` takes `line: Int` and converts via `UInt(line)`, which traps on negative — matching Swift's standard integer conversion behavior. Since `#line` always produces a positive value, this is safe at all call sites. No special-casing needed.

---

## Implementation Record (v3.0.0)

All phases implemented and committed on 2026-02-27.

### Phase 1: text-primitives (`c905995`)
- Created `Text.Line.Number`, `Text.Line.Column`, `Text.Location`, `Text.Line.Map`
- 58 tests pass

### Phase 2: source-primitives (`ed4d986`)
- Renamed `Source.Location` → `Source.Position`
- Replaced `Source.Location.Resolved` with new self-contained `Source.Location`
- Deleted `Source.Manager.LineMap` (moved to `Text.Line.Map`)
- 32 tests pass

### Phase 3: test-primitives (`c901576`)
- Deleted `Test.Source.Location` typealias and `Test.Source` namespace
- All source and test code uses `Source.Location` directly
- 142 tests pass

### Phase 4: Downstream unification

| Package | Commit | Type eliminated | Replacement |
|---------|--------|-----------------|-------------|
| swift-witnesses | `b8f19ca` | `Witness.Unimplemented.Location` | `Source.Location` directly |
| swift-parsers | `9615226` | `Parser.Diagnostic.Location` | `Source.Location` directly |

**Design decision**: Typealiases were rejected in favor of using `Source.Location` directly everywhere. This avoids namespace pollution and makes the canonical type visible at all call sites.

---

## References

- `text-position-model.md` (swift-text-primitives) — Text.Location design (DECISION)
- `string-path-type-unification.md` (swift-institute) — string/path type architecture (IN_PROGRESS)
- Swift Testing `SourceLocation`: [apple/swift-testing](https://github.com/swiftlang/swift-testing)
- Clang `PresumedLoc`: [clang/include/clang/Basic/SourceLocation.h](https://github.com/llvm/llvm-project/blob/main/clang/include/clang/Basic/SourceLocation.h)
- LSP Specification: [Position](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#position) and [Location](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#location)
