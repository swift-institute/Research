# swift-rendering-primitives Audit: Implementation + Naming

Date: 2026-03-13

## Summary
- Total files audited: 28 (18 source + 6 test + 4 exports/Package.swift)
- Total violations found: 11
- Critical (naming/compound types): 2
- Implementation style: 9

## Violations

### [API-NAME-002] Compound method names `lineBreak`, `thematicBreak`, `pageBreak`
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:33-34,36`
- **Issue**: Three protocol requirements use compound method names. Under API-NAME-002, methods MUST NOT use compound names; nested accessors should be used instead.
- **Current**:
```swift
mutating func lineBreak()
mutating func thematicBreak()
mutating func pageBreak()
```
- **Expected**: These should use nested accessors, e.g. `line.break()`, `thematic.break()`, `page.break()`, or be exposed through a Property.View tag like the push/pop pattern already in place. Alternatively, single-word names like `break(line:)` or semantic enum cases could be used. The `break` keyword collision makes this non-trivial; consider `insert.lineBreak()` via a Property.View `Insert` tag, mirroring push/pop.

---

### [API-NAME-002] Compound method name `flushFullChunks`
- **File**: `Sources/Rendering Async Primitives/Rendering.Async.Sink.Buffered.swift:75`
- **Issue**: `flushFullChunks()` is a compound method name. Should use nested accessor or single-word intent.
- **Current**: `private func flushFullChunks() async`
- **Expected**: Since this is `private`, the impact is contained. Possible alternatives: `flush.full()` via a Property.View tag, or simply `flush()` since the "full chunks" behavior is implicit from context. Low severity given private scope.

---

### [API-NAME-002] Compound method name `flushFullChunks` (Chunked)
- **File**: `Sources/Rendering Async Primitives/Rendering.Async.Sink.Chunked.swift:63`
- **Issue**: Same compound name pattern as Buffered.
- **Current**: `func flushFullChunks() async`
- **Expected**: Same as above. `@usableFromInline` makes this slightly more visible than pure private, but still internal to the module.

---

### [IMPL-EXPR-001] Unnecessary intermediate variable in `flushFullChunks`
- **File**: `Sources/Rendering Async Primitives/Rendering.Async.Sink.Buffered.swift:75-86`
- **Issue**: The `offset` variable is used as manual iteration state. While this is justified for the O(n^2) avoidance comment, the pattern reads as mechanism (manual offset tracking) rather than intent.
- **Current**:
```swift
private func flushFullChunks() async {
    var offset = 0
    while buffer.count - offset >= chunkSize {
        let end = offset + chunkSize
        try? await sender.send(ArraySlice(buffer[offset..<end]))
        offset = end
    }
    if offset > 0 {
        buffer.removeFirst(offset)
    }
}
```
- **Expected**: This is a pragmatic trade-off documented in the comment. The mechanism is justified by the O(n^2) avoidance. Marking as LOW severity since the comment explains the rationale. A `drain`-style abstraction could make this read more as intent if the pattern recurs.

---

### [IMPL-EXPR-001] Duplicate `flushFullChunks` mechanism in Chunked
- **File**: `Sources/Rendering Async Primitives/Rendering.Async.Sink.Chunked.swift:63-79`
- **Issue**: Nearly identical implementation to `Buffered.flushFullChunks()`. The offset-based iteration mechanism is duplicated rather than abstracted.
- **Current**: Same offset-tracking loop as Buffered, plus a yield-interval check.
- **Expected**: A shared abstraction (e.g., a `flush(from buffer: inout [UInt8], chunkSize: Int, emit:)` utility) would eliminate duplication and make the intent clearer. LOW severity given the two implementations have slightly different emit paths (channel send vs continuation yield).

---

### [IMPL-033] Iteration mechanism over intent in `Array+Rendering.swift`
- **File**: `Sources/Rendering Primitives Core/Array+Rendering.swift:8-10`
- **Issue**: Uses `let copy = copy view` followed by `for element in copy` rather than expressing iteration intent directly. The explicit `copy` is forced by the `borrowing` parameter, but the two-step pattern reads as mechanism.
- **Current**:
```swift
let copy = copy view
for element in copy {
    Element._render(element, context: &context)
}
```
- **Expected**: This is a known Swift compiler limitation with `borrowing` and iteration. The `copy` is necessary. LOW severity -- the mechanism is forced by language constraints, not design choice.

---

### [IMPL-033] Iteration mechanism over intent in `Optional+Rendering.swift`
- **File**: `Sources/Rendering Primitives Core/Optional+Rendering.swift:8-10`
- **Issue**: Same pattern as Array -- `let copy = copy view` then `switch copy`. The two-step is forced by `borrowing`.
- **Current**:
```swift
let copy = copy view
switch copy {
case .some(let wrapped): Wrapped._render(wrapped, context: &context)
case .none: break
}
```
- **Expected**: Same as Array -- forced by language constraints. LOW severity.

---

### [API-IMPL-005] Multiple types in `Rendering.Style.swift`
- **File**: `Sources/Rendering Primitives Core/Rendering.Style.swift:1-34`
- **Issue**: This file contains `Rendering.Style`, `Rendering.Style.Font`, `Rendering.Style.Font.Weight`, and `Rendering.Style.Color` -- four type declarations in one file. Under [API-IMPL-005] (one type per file), each should be in its own file. However, `Weight` and `Color` are simple enums nested inside their parent, which is a common exception for leaf enums with no logic.
- **Current**: All four types in `Rendering.Style.swift`.
- **Expected**: Strictly, separate files: `Rendering.Style.swift`, `Rendering.Style.Font.swift`, `Rendering.Style.Font.Weight.swift`, `Rendering.Style.Color.swift`. Pragmatically, the leaf enums (`Weight`, `Color`) could stay since they have no methods or stored properties beyond cases. MEDIUM severity for `Font` (it has stored properties and an init), LOW for the leaf enums.

---

### [IMPL-010] `Int` usage in semantic API
- **File**: `Sources/Rendering Primitives Core/Rendering.Semantic.Block.swift:4`
- **Issue**: `case heading(level: Int)` uses bare `Int` for the heading level. Under [IMPL-010] (push Int to the edge), a typed wrapper would be more appropriate for a primitives package. Heading levels are bounded (1-6 in HTML, for example), so a typed value would enforce that constraint.
- **Current**: `case heading(level: Int)`
- **Expected**: A typed wrapper like `Rendering.Semantic.Block.Level` or use of an existing bounded integer type. MEDIUM severity -- this is a primitives package, and `Int` in the domain model pushes untyped arithmetic into consumer code.

---

### [IMPL-010] `Int` usage in list start parameter
- **File**: `Sources/Rendering Primitives Core/Rendering.Context.swift:62`
- **Issue**: `start: Int?` parameter in `_pushList` uses bare `Int`. Same concern as heading level.
- **Current**: `static func _pushList(_ context: inout Self, kind: Semantic.List, start: Int?)`
- **Expected**: A typed wrapper for list start values. LOW severity -- this is more of a pass-through value (the context just records it), and list start values have no bounded domain.

---

### [IMPL-010] `Int` in `Rendering.Async.Sink.Buffered` and `Chunked`
- **File**: `Sources/Rendering Async Primitives/Rendering.Async.Sink.Buffered.swift:35-36,42`
- **File**: `Sources/Rendering Async Primitives/Rendering.Async.Sink.Chunked.swift:15,26,31`
- **Issue**: `chunkSize: Int`, `yieldInterval: Int`, and `bytesSinceYield: Int` all use bare `Int`. These are byte counts/sizes that could benefit from typed wrappers (e.g., `Count<UInt8>` or `Byte.Count`).
- **Current**: `private let chunkSize: Int`
- **Expected**: Typed byte count. LOW severity -- these are internal implementation details, not public API surface exposed to consumers. The `chunkSize` parameter in `init` is public, but since this is an async infrastructure type (not a domain model), bare `Int` is more pragmatic here.

## Non-Violations (Verified Clean)

| Rule | Status | Notes |
|------|--------|-------|
| [API-NAME-001] Nest.Name | CLEAN | All types properly nested: `Rendering.View`, `Rendering.Context`, `Rendering.Builder`, `Rendering.Semantic.Block`, `Rendering.Async.Sink.Buffered`, etc. |
| [API-NAME-003] Spec-mirroring | N/A | No specification implementations in this package. |
| [API-NAME-004] No typealiases | CLEAN | No typealiases for type unification found. |
| [API-ERR-001] Typed throws | N/A | No throwing functions in the package. |
| [IMPL-000] Call-site-first | CLEAN | The push/pop Property.View pattern enables `context.push.block()` call-site ergonomics. |
| [IMPL-002] Typed arithmetic | N/A | No arithmetic operations in this package. |
| [IMPL-003] Functor operations | N/A | No domain-crossing transformations. |
| [IMPL-004] Typed comparisons | N/A | No comparisons on typed values. |
| [IMPL-006] Zero-cost typed properties | CLEAN | Property.View used correctly for push/pop. |
| [IMPL-020] Verb-as-property | CLEAN | `push` and `pop` are verb-as-property with Property.View. |
| [IMPL-021] Property vs Property.View | CLEAN | Uses `Property.View` (not `Property`) for the non-owning accessor pattern. |
| [IMPL-030] Inline construction | CLEAN | No unnecessary intermediate construction. |
| [IMPL-031] Enum iteration | N/A | No manual switch over all enum cases. |
| [IMPL-032] Bulk operations | N/A | No per-element loops where bulk would apply. |
| [IMPL-034] unsafe placement | CLEAN | `unsafe` placed at narrowest scope (Property.View init). |
| [IMPL-040] Typed throws vs preconditions | N/A | No throws or preconditions. |
| [IMPL-041] Error type nesting | N/A | No error types. |
| [IMPL-050-053] Bounded indexing | N/A | No static-capacity types. |
| [PATTERN-009] No Foundation | CLEAN | No Foundation imports anywhere. |
| [PATTERN-017] rawValue confinement | N/A | No rawValue access. |
| [PATTERN-018] No escaping to Int | N/A | No Int-escaping arithmetic. |
| [PATTERN-022] ~Copyable in separate files | CLEAN | `Rendering.Conditional` and `Rendering.Pair` are ~Copyable and each has its own file. |

## Summary by Severity

| Severity | Count | Violations |
|----------|-------|------------|
| HIGH | 1 | [API-NAME-002] `lineBreak`/`thematicBreak`/`pageBreak` compound names on public protocol |
| MEDIUM | 2 | [API-IMPL-005] Multiple types in Style.swift; [IMPL-010] `Int` heading level |
| LOW | 8 | [API-NAME-002] private `flushFullChunks` x2; [IMPL-EXPR-001] offset mechanism x2; [IMPL-033] forced copy x2; [IMPL-010] list start Int; [IMPL-010] chunk/yield Int |

## Architecture Observations (Non-Violation)

1. **Property.View pattern is exemplary**: The push/pop accessor design via `Property<Rendering.Push, Self>.View` is a textbook application of [IMPL-020] and [IMPL-021]. Call sites read as `context.push.block(role:style:)` / `context.pop.block()` -- pure intent.

2. **~Copyable support is thorough**: `Conditional`, `Pair`, and `View` all support `~Copyable` with conditional `Copyable` conformance. The `_render` uses `borrowing` throughout.

3. **Builder uses variadic `_Tuple`**: The flat variadic approach (not binary `buildPartialBlock`) avoids the stack overflow documented in experiments. Good design decision.

4. **Unconstrained composition types**: `_Tuple`, `Conditional`, `Pair`, `ForEach`, `Group` are all unconstrained with conditional `Rendering.View` conformance. This enables domain packages to add their own protocol conformances. Clean separation of concerns.

5. **Static `_render` pattern**: Using `static func _render(_ view: borrowing Self, context: inout C)` instead of instance methods avoids ownership issues with `~Copyable` types. Well-motivated by borrowing semantics.
