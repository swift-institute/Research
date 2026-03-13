# Markdown Rendering Organization Audit

<!--
---
version: 1.1.0
last_updated: 2026-03-13
status: IN_PROGRESS
---
-->

## Context

Fresh-eyes audit of the markdown rendering pipeline across `swift-markdown-html-rendering`, `swift-html-rendering`, and `swift-pdf-html-rendering`. Focus: organizational clarity evaluated against [IMPL-INTENT], [API-IMPL-005], [MOD-*], and [API-NAME-*].

## Scope

| Package | Path | Role |
|---------|------|------|
| swift-markdown-html-rendering | `swift-foundations/swift-markdown-html-rendering/` | Markdown → HTML view tree |
| swift-html-rendering | `swift-foundations/swift-html-rendering/` | HTML view protocol + rendering |
| swift-pdf-html-rendering | `swift-foundations/swift-pdf-html-rendering/` | HTML view tree → PDF pages |

---

## Findings

### F-1. `Configuration.Elements` is 837 lines with 18+ types [HIGH]

**File**: `Sources/Markdown HTML Rendering/Markdown.HTML.Configuration.Elements.swift`

**Violation**: [API-IMPL-005] — one type per file. 18 element renderers (Heading, CodeBlock, BlockQuote, Paragraph, Image, Link, List, ListItem, Table, ThematicBreak, Emphasis, Strong, Strikethrough, InlineCode, Text, LineBreak, SoftBreak) plus 18 nested `Input` structs, all in a single 837-line file.

**Impact**: Hard to navigate, impossible to `git blame` individual elements, merge conflicts likely.

**Fix**: Split into per-element files:
```
Markdown.HTML.Configuration.Elements.Heading.swift
Markdown.HTML.Configuration.Elements.CodeBlock.swift
Markdown.HTML.Configuration.Elements.BlockQuote.swift
...
```

Each file: ~40 lines. The `Elements` aggregate struct stays in `Markdown.HTML.Configuration.Elements.swift` with just the stored properties and `default` static.

---

### F-2. `Markdown.HTML.swift` defines 3 types [MEDIUM]

**File**: `Sources/Markdown HTML Rendering/Markdown.HTML.swift`

**Violation**: [API-IMPL-005]. Contains `Markdown`, `Markdown.HTML`, and `Markdown.HTML.Section` in one file.

**Fix**: Split into:
- `Markdown.swift` — the `Markdown: HTML.View` struct
- `Markdown.HTML.swift` — the `Markdown.HTML` callable struct
- `Markdown.HTML.Section.swift` — the table-of-contents section type

---

### F-3. `HTMLConverter` is a compound name [MEDIUM]

**File**: `Sources/Markdown HTML Rendering/HTMLConverter.swift`

**Violation**: [API-NAME-001] / [API-NAME-002]. `HTMLConverter` is a compound identifier. Should be nested under the `Markdown` namespace.

**Fix**: Rename to `Markdown.HTML.Converter` in file `Markdown.HTML.Converter.swift`. The type is `internal`, so this has zero consumer impact.

---

### F-4. `nonisolated(unsafe)` boilerplate repeated 18x [MEDIUM]

**File**: `Markdown.HTML.Configuration.Elements.swift` — every element init contains:

```swift
nonisolated(unsafe) let unsafeRender = render
self.render = { input in HTML.AnyView(unsafeRender(input)) }
```

**Violation**: [IMPL-INTENT] — mechanism, not intent. The pattern is identical across all 18 elements.

**Fix**: Extract a shared initializer or factory method on a base type/protocol that handles the `nonisolated(unsafe)` wrapping once. For example:

```swift
extension Markdown.HTML.Configuration {
    struct ElementRenderer<Input>: Sendable {
        let render: @Sendable (Input) -> HTML.AnyView

        init(_ render: @escaping @Sendable (Input) -> some HTML.View) {
            nonisolated(unsafe) let unsafeRender = render
            self.render = { HTML.AnyView(unsafeRender($0)) }
        }
    }
}
```

Then each element becomes:
```swift
public var heading: ElementRenderer<Heading.Input> = .init { input in
    // heading-specific rendering
}
```

---

### F-5. `Markdown.HTML` struct existence is questionable [MEDIUM]

`Markdown` (the view) delegates to `Markdown.HTML` (a callable struct) in its `body`:

```swift
public var body: some HTML.View {
    HTML(configuration: configuration, previewOnly: previewOnly)
        .callAsFunction { markdownString }
}
```

Here `HTML` resolves to `Self.HTML` = `Markdown.HTML`. The `Markdown.HTML` struct exists as a separate callable entry point predating the `Markdown` struct. Now that `Markdown` IS the view, `Markdown.HTML` is an implementation detail that shouldn't need to be a separate public type. The parsing and visitor logic (`HTMLConverter`) could be called directly from `Markdown.body`.

**Question**: Is `Markdown.HTML` still used directly by consumers, or only through `Markdown`? If only through `Markdown`, it should become internal or merged.

---

### F-6. `HTML.AnyView` type erasure everywhere [LOW — DESIGN DISCUSSION]

Every `visit*` method in `HTMLConverter` returns `HTML.AnyView`. The configuration closures all return `HTML.AnyView`. This means the entire markdown view tree is type-erased at every node.

**Consequences**:
- Stack overflow in PDF rendering with deep nesting (documented in `swift-pdf/Research/sigbus-stack-overflow-handoff.md`)
- Loss of semantic identity — a heading becomes a generic view, losing its "heading" nature
- Existential dispatch overhead at every render node

**Not a quick fix** — this is an architectural pattern inherited from the coenttb design. The `MarkupVisitor` protocol requires a single `Result` type across all visit methods, forcing type erasure. A principled alternative would require a different visitor design or a format-agnostic markdown view protocol (not HTML-mediated).

**Note**: This finding is observational. The current design works and has been validated. A redesign would be a separate investigation.

---

### F-7. Configuration closure pattern lacks type safety [LOW]

Each element renderer is a stored closure:

```swift
public var heading: Heading
// where Heading stores: render: @Sendable (Input) -> HTML.AnyView
```

There's no protocol constraining what a "renderer" is. Each element type is a standalone struct with its own `Input` and `render` closure. The pattern is consistent but not enforced by the type system.

**Potential improvement**: A protocol or generic type for element renderers would:
- Enforce the pattern at compile time
- Enable default implementations
- Reduce per-element boilerplate (see F-4)

This connects to F-4 — `ElementRenderer<Input>` would serve both purposes.

---

### F-8. `HTML.Builder.swift` extends a foreign type [LOW]

**File**: `Sources/Markdown HTML Rendering/HTML.Builder.swift`

This file extends `HTML.Builder` (from swift-html-rendering) with `buildExpression(HTML.AnyView)` and `buildFinalResult` overloads. Extending a foreign type's result builder with new `buildExpression` methods can cause surprising overload resolution in downstream code.

**Assessment**: Acceptable at Layer 3 (foundations), but worth noting. The extension is small and targeted.

---

### F-9. `Configuration.Style` has 3 types in one file [LOW]

**File**: `Sources/Markdown HTML Rendering/Markdown.HTML.Configuration.Style.swift` (162 lines)

Contains `Style`, `DiagnosticStyle`, `BlockQuoteStyle`, and `Icons`. Per [API-IMPL-005], each should be its own file. Low priority since the file is only 162 lines.

---

### F-10. Diagnostic types are not namespaced under Markdown [LOW]

`Diagnostic`, `Diagnostic.Level`, `Diagnostic.Icon`, `Diagnostic.Inline` are top-level in the module namespace. They should be `Markdown.HTML.Diagnostic` to follow [API-NAME-001].

**Current**: `Diagnostic.swift`, `Diagnostic.Level.swift`
**Expected**: `Markdown.HTML.Diagnostic.swift`, `Markdown.HTML.Diagnostic.Level.swift`

---

## Modularization Assessment

**Current state**: Single `Markdown HTML Rendering` target with 19 files. No Core/Variant decomposition.

**Assessment**: At 19 files, this package does NOT warrant MOD-001 multi-product decomposition. The semantic domain is singular — markdown→HTML conversion. There's no axis along which consumers would want selective imports.

**However**, if the package grows (e.g., adding markdown→PDF direct rendering, or markdown→attributed-string), then decomposition along the "output format" axis would be appropriate:
- `Markdown Rendering Core` — AST processing, configuration
- `Markdown HTML Rendering` — HTML-specific output
- `Markdown PDF Rendering` — PDF-specific output (future)

For now, the single-target structure is correct.

---

## Priority Summary

| ID | Finding | Severity | Effort |
|----|---------|----------|--------|
| F-1 | Elements.swift: 18 types in one file | HIGH | Low — mechanical split |
| F-2 | Markdown.HTML.swift: 3 types in one file | MEDIUM | Low — mechanical split |
| F-3 | HTMLConverter compound name | MEDIUM | Low — rename |
| F-4 | nonisolated(unsafe) repeated 18x | MEDIUM | Medium — extract shared type |
| F-5 | Markdown.HTML struct justification | MEDIUM | Medium — needs consumer audit |
| F-6 | HTML.AnyView everywhere | LOW | High — architectural |
| F-7 | No protocol for element renderers | LOW | Medium |
| F-8 | Foreign type extension | LOW | None (acceptable) |
| F-9 | Style types in one file | LOW | Low — mechanical split |
| F-10 | Diagnostic not namespaced | LOW | Low — rename |

## Recommended Action

Start with F-1 (split Elements.swift) and F-2 (split Markdown.HTML.swift) — these are mechanical, low-risk, and directly address the most visible [API-IMPL-005] violations. F-4 (shared ElementRenderer type) can be done alongside F-1 for compound value.

F-5 and F-6 require design discussion before acting.

## References

- Investigation prompt: `swift-institute/Research/prompts/markdown-swiftui-pdf-investigation.md`
- Stack overflow research: `swift-pdf/Research/sigbus-stack-overflow-handoff.md`
- Iterative tuple rendering memory: see MEMORY.md entry
