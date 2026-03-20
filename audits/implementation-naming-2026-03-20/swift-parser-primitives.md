# swift-parser-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: naming, implementation
**Scope**: All 107 `.swift` files across 36 modules in `Sources/`
**Status**: READ-ONLY audit

---

## Summary Table

| ID | Severity | Rule | File | Finding |
|----|----------|------|------|---------|
| PARSE-001 | HIGH | API-NAME-001 | Parser.ParserPrinter.swift | `ParserPrinter` is a compound type name |
| PARSE-002 | HIGH | API-NAME-001 | Parser.Either.swift:16 | `_EitherChain` is a compound type name (underscored public protocol) |
| PARSE-003 | HIGH | API-NAME-001 | Parser.Error.Located.swift:97 | `LocatedError` is a compound type name |
| PARSE-004 | HIGH | API-NAME-001 | Parser.Input.swift:80 | `CollectionInput` is a compound typealias name |
| PARSE-005 | HIGH | API-NAME-001 | Parser.Input.swift:92 | `ByteInput` is a compound typealias name |
| PARSE-006 | HIGH | API-NAME-001 | Parser.Input.swift:108 | `ByteStream` is a compound typealias name |
| PARSE-007 | HIGH | API-NAME-001 | Parser.EndOfInput.swift | `EndOfInput` is a compound type name |
| PARSE-008 | MEDIUM | PATTERN-021 | 15 call sites | `input.restore.to(__unchecked: (), checkpoint)` — unchecked restore bypasses validation |
| PARSE-009 | MEDIUM | API-NAME-002 | Parser.Parser.swift:157 | `remainingCount` is a compound property name |
| PARSE-010 | MEDIUM | API-NAME-001 | Parser.FlatMap.swift | `FlatMap` is a compound type name |
| PARSE-011 | MEDIUM | API-NAME-002 | Parser.Protocol+map.swift:23 | `tryMap` is a compound method name |
| PARSE-012 | MEDIUM | API-NAME-001 | Parser.Error.Located.swift:110 | Deprecated typealias `Parser.Located` preserves compound naming |
| PARSE-013 | LOW | API-IMPL-005 | Parser.Error.Located.swift | Two types in one file: `Located` struct + `LocatedError` protocol |
| PARSE-014 | LOW | API-IMPL-005 | Parser.Either.swift | Top-level protocol `_EitherChain` + extensions on external `Either` in one file |
| PARSE-015 | LOW | IMPL-INTENT | Parser.ByteInput.swift:11-15 | Manual byte-by-byte copy loop instead of passing array directly |
| PARSE-016 | INFO | PATTERN-017 | Parser.Error.Located.swift:59 | `Int(bitPattern: offset)` at boundary — correctly follows [IMPL-010] |
| PARSE-017 | INFO | PATTERN-017 | Parser.Spanned.swift:84 | `Int(bitPattern: start/end)` at boundary — correctly follows [IMPL-010] |
| PARSE-018 | INFO | IMPL-002 | Parser.Tracked.swift:144,150,174 | `offset += .one`, `.subtract.saturating` — correctly typed arithmetic |

**Totals**: 7 HIGH, 4 MEDIUM, 3 LOW, 3 INFO

---

## Detailed Findings

### PARSE-001 [HIGH] — `ParserPrinter` compound type name

**Rule**: [API-NAME-001] All types MUST use the `Nest.Name` pattern. Compound type names are forbidden.

**Location**: `Sources/Parser Primitives Core/Parser.ParserPrinter.swift:40`

**Current**: `Parser.ParserPrinter`

**Proposed**: This protocol combines `Parser.Protocol` and `Parser.Printer`. The compound name "ParserPrinter" fuses two domain nouns. Consider `Parser.Bidirectional` or nest `Printer.Bidirectional` under the existing `Parser.Printer` to express "a printer that is also a parser."

**Note**: The doc comment on line 26 has a typo: `Parser.\`Protocol\`Printer` — should be `Parser.ParserPrinter`.

---

### PARSE-002 [HIGH] — `_EitherChain` underscored public protocol with compound name

**Rule**: [API-NAME-001] Compound type names forbidden.

**Location**: `Sources/Parser Error Primitives/Parser.Either.swift:16`

**Current**:
```swift
public protocol _EitherChain {
    associatedtype _Left
    associatedtype _Right
    var _left: _Left? { get }
    var _right: _Right? { get }
}
```

**Issue**: Two problems. (1) `EitherChain` is a compound name. (2) Underscored public protocol is an API-surface smell — the comment says "should be considered an implementation detail" but it is `public` and unconstrained, meaning any consumer can conform.

**Proposed**: Nest under `Either` namespace (e.g., `Either.Chain` protocol) or make it internal/package-access if possible. If it must remain public for constrained extensions, at minimum rename to `Either.Chaining` and remove underscored associated types.

---

### PARSE-003 [HIGH] — `LocatedError` compound protocol name

**Rule**: [API-NAME-001] Compound type names forbidden.

**Location**: `Sources/Parser Error Primitives/Parser.Error.Located.swift:97`

**Current**: `Parser.Error.LocatedError`

**Issue**: `LocatedError` fuses "Located" + "Error." It is nested under `Parser.Error`, making the full path `Parser.Error.LocatedError` — doubly redundant with the parent namespace already being `Error`.

**Proposed**: `Parser.Error.Locating` (protocol that provides location) or `Parser.Error.Locatable` (a type that carries a location). Since the parent is already `Parser.Error`, a simple `Protocol` or `Located.Protocol` would also work if the language supported it.

---

### PARSE-004 [HIGH] — `CollectionInput` compound typealias

**Rule**: [API-NAME-001] Compound type names forbidden.

**Location**: `Sources/Parser Primitives Core/Parser.Input.swift:80`

**Current**:
```swift
public typealias CollectionInput<Base: Collection.`Protocol`> = Input_Primitives.Input.Slice<Base>
```

**Proposed**: `Parser.Input.Slice` or `Parser.Input.Collection` — one noun, properly nested.

---

### PARSE-005 [HIGH] — `ByteInput` compound typealias

**Rule**: [API-NAME-001] Compound type names forbidden.

**Location**: `Sources/Parser Primitives Core/Parser.Input.swift:92`

**Current**:
```swift
public typealias ByteInput = Input_Primitives.Input.Slice<Array<UInt8>.Indexed<UInt8>>
```

**Proposed**: `Parser.Bytes` or `Parser.Input.Bytes` — one noun, reflecting the domain concept. This alias is used extensively (`Parseable`, `ByteInput.init`, doc examples) so rename scope is significant.

---

### PARSE-006 [HIGH] — `ByteStream` compound typealias

**Rule**: [API-NAME-001] Compound type names forbidden.

**Location**: `Sources/Parser Primitives Core/Parser.Input.swift:108`

**Current**:
```swift
public typealias ByteStream = Collection.Slice.`Protocol` & Parser.Streaming & Sendable
```

**Proposed**: This bundles constraints, so a protocol alias is reasonable. Rename to `Parser.Stream` (singular) — the "byte" part is already enforced by `Element == UInt8` at call sites.

---

### PARSE-007 [HIGH] — `EndOfInput` compound namespace

**Rule**: [API-NAME-001] Compound type names forbidden.

**Location**: `Sources/Parser EndOfInput Primitives/Parser.EndOfInput.swift:10`

**Current**: `Parser.EndOfInput` (namespace enum containing `Error`)

**Proposed**: `Parser.End` already exists as a parser type (in Parser End Primitives). The two are closely related — `Parser.End` is the parser, `Parser.EndOfInput.Error` is the error. Consider merging `EndOfInput.Error` into `Parser.End.Error` and removing the `EndOfInput` namespace entirely, or rename to `Parser.Exhaustion` or `Parser.Depletion` for the error namespace.

---

### PARSE-008 [MEDIUM] — 15 `__unchecked` restore calls

**Rule**: [PATTERN-021] Prefer typed/validated operations over `__unchecked`.

**Locations** (15 call sites):
- `Parser.OneOf.Two.swift:41,63`
- `Parser.OneOf.Three.swift:43,45,67,72`
- `Parser.OneOf.Any.swift:73`
- `Parser.Many.Simple.swift:86`
- `Parser.Many.Separated.swift:116,125`
- `Parser.Peek.swift:55,58`
- `Parser.Not.swift:70,74`
- `Parser.Optionally.swift:41`

**Current pattern**:
```swift
let checkpoint = input.checkpoint
// ... try parse ...
input.restore.to(__unchecked: (), checkpoint)
```

**Analysis**: The checkpoint is always obtained from `input.checkpoint` immediately before use, and the input is never structurally modified between capture and restore — only advanced. In ring buffer terms, the checkpoint is always within the valid range. The `__unchecked` form avoids a redundant bounds check and a `throws` that would infect the error type. This is a defensible boundary-code pattern: the invariant (checkpoint freshness) is locally provable.

**Recommendation**: ACCEPTABLE as-is. The alternative `try input.restore.to(checkpoint)` would introduce `Input.Restore.Error` into every combinator's `Failure` type, which would be a significant API ergonomics regression. However, a doc comment on each usage explaining the invariant would strengthen the safety argument. Alternatively, a `restore.to(freshly: checkpoint)` overload with a more descriptive label than `__unchecked` would better communicate intent.

---

### PARSE-009 [MEDIUM] — `remainingCount` compound property name

**Rule**: [API-NAME-002] Properties MUST NOT use compound names.

**Location**: `Sources/Parser Primitives Core/Parser.Parser.swift:157`

**Current**:
```swift
extension Collection.Slice.`Protocol` {
    public var remainingCount: Int { ... }
}
```

**Proposed**: `remaining.count` via nested accessor, or `count.remaining` — reads as intent. The property is used in `Parser.End` and `Parser.Protocol+parse` for error reporting.

---

### PARSE-010 [MEDIUM] — `FlatMap` compound type name

**Rule**: [API-NAME-001] Compound type names forbidden.

**Location**: `Sources/Parser FlatMap Primitives/Parser.FlatMap.swift:14`

**Current**: `Parser.FlatMap`

**Issue**: "FlatMap" fuses "Flat" + "Map." This is a well-known Haskell/FP term (`bind`/`>>=`), but the naming rules are explicit: compound names are forbidden regardless of origin.

**Proposed**: `Parser.Bind` (the standard monad terminology) or `Parser.Chain` (more accessible). The method on `Parser.Protocol` is already `flatMap(_:)` — renaming the *type* to `Parser.Bind` while keeping the *method* as `.flatMap` is acceptable since method naming can mirror stdlib conventions per [API-NAME-003] specification-mirroring.

**Note**: This finding applies equally to `Parser.Map.Transform` vs just `Parser.Map.Pure`, though `Map.Transform` at least uses the nested pattern. The term "FlatMap" as a single namespace is the compound violation.

---

### PARSE-011 [MEDIUM] — `tryMap` compound method name

**Rule**: [API-NAME-002] Methods MUST NOT use compound names.

**Location**: `Sources/Parser Map Primitives/Parser.Protocol+map.swift:23`

**Current**:
```swift
public func tryMap<NewOutput, E: Swift.Error & Sendable>(
    _ transform: @escaping @Sendable (Output) throws(E) -> NewOutput
) -> Parser.Map.Throwing<Self, NewOutput, E>
```

**Proposed**: Could be accessed via nested pattern: `parser.map.throwing { ... }` using the existing `Parser.Map.Throwing` type name as a guide. Alternatively, since the Transform closure itself already uses `throws(E)`, the compiler could potentially unify via an overloaded `map` that accepts a throwing closure (but this clashes with rethrows semantics per the typed-throws memory).

---

### PARSE-012 [MEDIUM] — Deprecated `Parser.Located` typealias

**Rule**: [API-NAME-001] Compound naming.

**Location**: `Sources/Parser Error Primitives/Parser.Error.Located.swift:110`

**Current**:
```swift
@available(*, deprecated, renamed: "Error.Located")
public typealias Located<E: Swift.Error & Sendable> = Parser.Error.Located<E>
```

**Note**: This is already deprecated, which is correct. The migration path points to the properly-nested `Parser.Error.Located`. This is informational — no action needed beyond eventual removal.

---

### PARSE-013 [LOW] — Two types in `Parser.Error.Located.swift`

**Rule**: [API-IMPL-005] One type per file.

**Location**: `Sources/Parser Error Primitives/Parser.Error.Located.swift`

**Current**: This file declares both `Parser.Error.Located<E>` (struct, line 31) and `Parser.Error.LocatedError` (protocol, line 97). It also contains a deprecated backward-compatibility typealias `Parser.Located` (line 110).

**Proposed**: Extract `Parser.Error.LocatedError` protocol into its own file: `Parser.Error.LocatedError.swift` (or whatever it gets renamed to per PARSE-003). The deprecated typealias can stay with `Located` since it is just an alias.

---

### PARSE-014 [LOW] — Top-level protocol in `Parser.Either.swift`

**Rule**: [API-IMPL-005] One type per file.

**Location**: `Sources/Parser Error Primitives/Parser.Either.swift`

**Current**: This file declares `_EitherChain` (a new top-level public protocol) alongside extensions on the external `Either` type. The `_EitherChain` protocol should be in its own file.

---

### PARSE-015 [LOW] — Manual byte copy loop in `ByteInput.init`

**Rule**: [IMPL-INTENT] Code reads as intent, not mechanism.

**Location**: `Sources/Parser Primitives Core/Parser.ByteInput.swift:11-15`

**Current**:
```swift
public init(_ bytes: Swift.Array<UInt8>) {
    var storage = Array<UInt8>()
    for byte in bytes {
        storage.append(byte)
    }
    self = Input.Slice(Array<UInt8>.Indexed<UInt8>(storage))
}
```

**Issue**: The manual `for byte in bytes { storage.append(byte) }` loop is mechanism. The intent is "create indexed storage from bytes."

**Proposed**:
```swift
public init(_ bytes: Swift.Array<UInt8>) {
    self = Input.Slice(Array<UInt8>.Indexed<UInt8>(bytes))
}
```

If `Indexed.init` does not accept `[UInt8]` directly, the manual copy is a workaround that should be documented. Otherwise this is a needless copy.

---

### PARSE-016 [INFO] — Correct boundary overload for `Int(bitPattern:)`

**Rule**: [PATTERN-017] `.rawValue` confined to boundary code. [IMPL-010] Push conversions to the edge.

**Location**: `Sources/Parser Error Primitives/Parser.Error.Located.swift:57-59`

```swift
public init<Element: ~Copyable>(_ error: E, at offset: Index<Element>) {
    self.init(error, at: Int(bitPattern: offset))
}
```

**Assessment**: Correct. The `Int(bitPattern:)` conversion is at the boundary, exactly where it should be. The public API accepts `Index<Element>` (typed), and the conversion to `Int` is an implementation detail confined to the initializer edge.

---

### PARSE-017 [INFO] — Correct boundary overload for `Spanned`

**Rule**: [IMPL-010]

**Location**: `Sources/Parser Spanned Primitives/Parser.Spanned.swift:82-84`

**Assessment**: Same correct pattern as PARSE-016. `Int(bitPattern: start)` and `Int(bitPattern: end)` at the boundary initializer.

---

### PARSE-018 [INFO] — Correct typed arithmetic in `Tracked`

**Rule**: [IMPL-002] Typed arithmetic — no `.rawValue` at call sites.

**Location**: `Sources/Parser Tracked Primitives/Parser.Tracked.swift:144,150,174`

```swift
offset += .one                                           // line 144
offset += count                                          // line 150
offset += countBefore.subtract.saturating(base.count)    // line 174
```

**Assessment**: Exemplary. All arithmetic on `Index<Element>` uses typed operators (`.one`, `.subtract.saturating`). No `.rawValue` leakage. This is the target pattern for the entire codebase.

---

## Positive Observations

1. **Namespace discipline**: The package follows `Parser.X` nesting rigorously. Types like `Parser.OneOf.Two`, `Parser.Take.Sequence`, `Parser.Error.Located`, `Parser.Prefix.While` are all properly nested.

2. **One type per file**: The vast majority of files contain exactly one type. The violations (PARSE-013, PARSE-014) are minor and localized.

3. **Typed throws**: Every parser uses typed throws with explicit `Failure` associated types. No untyped `throws` anywhere.

4. **No Foundation imports**: Zero Foundation usage across all 107 files.

5. **No `.rawValue` leakage**: Zero `.rawValue` call sites found in the entire package. All typed index arithmetic goes through proper operators.

6. **Boundary overloads**: `Int(bitPattern:)` conversions are correctly placed at initializer boundaries, not scattered through implementation code.

7. **`__unchecked` usage is locally justified**: All 15 instances follow the same pattern (capture checkpoint, try parse, restore) where the invariant is locally provable. This is a reasonable boundary-code pattern despite the count.

8. **Combinator API surface**: `.map`, `.flatMap`, `.filter`, `.error.map`, `.error.replace`, `.peek()`, `.not()`, `.trace()`, `.located()`, `.spanned()` — clean, discoverable method chaining.
