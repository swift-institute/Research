# Implementation: Rendering.Context Witness Migration — Phase 3 (PDF Rendering)

## Assignment

Migrate swift-pdf-rendering and swift-pdf-html-rendering from protocol-based `Rendering.Context` conformance to the witness-based architecture. Phase 1 (L1 witness struct) and Phase 2 (HTML rendering) are complete.

**This is Phase 3 of 4.** Two packages are modified: swift-pdf-rendering and swift-pdf-html-rendering.

**Quality bar**: Timeless infrastructure. Follow all Swift Institute conventions.

---

## What Changed in Phases 1–2

- `Rendering.Context` is a `~Copyable` struct with 26 stored closures (not a protocol)
- `_render` on `Rendering.View` takes `context: inout Rendering.Context` (no generic `C`)
- `Rendering.Action` enum with nested `Push`/`Pop` for deferred rendering
- `Rendering.Context.html(state: Ownership.Mutable<HTML.Context>)` factory exists
- L1 has labeled convenience methods: `context.set(attribute:_:)`, `context.add(class:)`, `context.write(raw:)`, `context.register(style:atRule:selector:pseudo:)`, `context.apply(inlineStyle:)`
- Property.View push/pop accessors use `Base == Rendering.Context`

**Read the Phase 1–2 code before starting:**
- `https://github.com/swift-primitives/swift-rendering-primitives/blob/main/Sources/Rendering Primitives Core/Rendering.Context.swift`
- `https://github.com/swift-foundations/swift-html-rendering/blob/main/Sources/HTML Renderable/Rendering.Context +HTML.swift`

---

## Package 1: swift-pdf-rendering

### Key finding from audit

swift-pdf-rendering has **24 `_render` methods** but they use `context: inout PDF.Context` directly — NOT the generic `C: Rendering.Context`. These are PDF-specific view types with their own rendering path. They are **UNAFFECTED** by the migration.

The only change is the conformance:

### 1. Remove `PDF.Context: Rendering.Context` conformance

**File**: `https://github.com/swift-foundations/swift-pdf-rendering/blob/main/Sources/PDF Rendering/PDF.Context+Rendering.swift`

This file has `extension PDF.Context: Rendering.Context { ... }` with 15 protocol method implementations. Remove the conformance. The methods STAY as regular methods on `PDF.Context`.

### 2. Add `Rendering.Context.pdf(state:)` factory

New file (or extension in existing file):

```swift
extension Rendering.Context {
    public static func pdf(state: Ownership.Mutable<PDF.Context>) -> Self {
        .init(
            text: { state.value.text($0) },
            lineBreak: { state.value.lineBreak() },
            thematicBreak: { state.value.thematicBreak() },
            image: { source, alt in state.value.image(source: source, alt: alt) },
            pageBreak: { state.value.pageBreak() },
            pushBlock: { role, style in
                PDF.Context._pushBlock(&state.value, role: role, style: style)
            },
            popBlock: { PDF.Context._popBlock(&state.value) },
            pushInline: { role, style in
                PDF.Context._pushInline(&state.value, role: role, style: style)
            },
            popInline: { PDF.Context._popInline(&state.value) },
            pushList: { kind, start in
                PDF.Context._pushList(&state.value, kind: kind, start: start)
            },
            popList: { PDF.Context._popList(&state.value) },
            pushItem: { PDF.Context._pushItem(&state.value) },
            popItem: { PDF.Context._popItem(&state.value) },
            pushLink: { destination in
                PDF.Context._pushLink(&state.value, destination: destination)
            },
            popLink: { PDF.Context._popLink(&state.value) },
            // ... remaining operations (check what the conformance actually implements)
        )
    }
}
```

**Important**: Read the actual conformance file first. Check which of the 26 operations are explicitly implemented vs using defaults. For operations that used protocol defaults (no-ops), pass the default no-op closures in the factory (they're default parameters in the Rendering.Context init).

### 3. Add swift-ownership-primitives dependency

Check Package.swift — if it doesn't already depend on swift-ownership-primitives, add it.

### 4. Verify the 24 PDF-specific _render methods are untouched

These use `inout PDF.Context` and are NOT `_render<C: Rendering.Context>`. They should compile unchanged. Verify with `swift build`.

---

## Package 2: swift-pdf-html-rendering

### Key finding from audit

`PDF.HTML.Context` conforms to `Rendering.Context` and delegates most operations to `PDF.Context`. It has additional logic for heading tracking, table layout, element scopes, margin collapsing.

The research recommends expressing this as a **context transformer** — a `consuming` method on `Rendering.Context` that wraps a PDF base context with HTML-semantic understanding. However, this is a significant refactor of the 1095-line conformance file.

**For Phase 3, take the simpler path**: create a factory method (like HTML and PDF), not a transformer. The transformer pattern can be adopted later as an optimization. The priority is getting the migration to compile.

### 1. Remove `PDF.HTML.Context: Rendering.Context` conformance

**File**: `https://github.com/swift-foundations/swift-pdf-html-rendering/blob/main/Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift`

This file has `extension PDF.HTML.Context: Rendering.Context { ... }` with many methods. Remove the conformance. The methods STAY as regular methods.

### 2. Add `Rendering.Context.pdfHTML(state:)` factory

```swift
extension Rendering.Context {
    public static func pdfHTML(state: Ownership.Mutable<PDF.HTML.Context>) -> Self {
        .init(
            text: { state.value.text($0) },
            lineBreak: { state.value.lineBreak() },
            // ... forward all 26 operations to PDF.HTML.Context methods
            pushBlock: { role, style in
                PDF.HTML.Context._pushBlock(&state.value, role: role, style: style)
            },
            popBlock: { PDF.HTML.Context._popBlock(&state.value) },
            // ...
        )
    }
}
```

Read the conformance file carefully. `PDF.HTML.Context` implements MORE than just the 26 Rendering.Context requirements — it has additional methods for element push/pop, attributes, styles, table management. Only the 26 that were protocol requirements go in the factory. The rest stay as methods on `PDF.HTML.Context`.

### 3. Update any `_render<C: Rendering.Context>` methods

Check if swift-pdf-html-rendering has any `_render<C>` methods. The audit found NONE that use the generic `C` — all use concrete `PDF.HTML.Context`. But verify by searching.

### 4. Update rendering entry points

Search for places where `PDF.HTML.Context` is created and used for rendering. These are the entry points that create the context and call `_render`. They need to create `Ownership.Mutable(PDF.HTML.Context(...))` and the factory.

Look for patterns like:
```swift
var context = PDF.HTML.Context(...)
SomeView._render(view, context: &context)
```

These become:
```swift
let state = Ownership.Mutable(PDF.HTML.Context(...))
var context = Rendering.Context.pdfHTML(state: state)
SomeView._render(view, context: &context)
// After: state.value has the PDF pages, headings, etc.
```

### 5. Add swift-ownership-primitives dependency if needed

Check Package.swift.

---

## Files to Read Before Starting

| File | Why |
|------|-----|
| Phase 1 Rendering.Context | `https://github.com/swift-primitives/swift-rendering-primitives/blob/main/Sources/Rendering Primitives Core/Rendering.Context.swift` |
| Phase 2 HTML factory | `https://github.com/swift-foundations/swift-html-rendering/blob/main/Sources/HTML Renderable/Rendering.Context +HTML.swift` |
| PDF.Context conformance | `https://github.com/swift-foundations/swift-pdf-rendering/blob/main/Sources/PDF Rendering/PDF.Context+Rendering.swift` |
| PDF.HTML.Context conformance | `https://github.com/swift-foundations/swift-pdf-html-rendering/blob/main/Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift` |
| PDF.HTML.Context main type | `https://github.com/swift-foundations/swift-pdf-html-rendering/blob/main/Sources/PDF HTML Rendering/PDF.HTML.Context.swift` |
| PDF rendering Package.swift | `https://github.com/swift-foundations/swift-pdf-rendering/blob/main/Package.swift` |
| PDF HTML rendering Package.swift | `https://github.com/swift-foundations/swift-pdf-html-rendering/blob/main/Package.swift` |

---

## Validation

```bash
# Package 1
cd swift-pdf-rendering
swift build
swift test

# Package 2
cd swift-pdf-html-rendering
swift build
swift test
```

Also check that the PDF end-to-end package still resolves:
```bash
cd swift-pdf
swift package resolve
```

---

## Constraints

- **Only modify swift-pdf-rendering and swift-pdf-html-rendering**
- The 24 PDF-specific `_render(context: inout PDF.Context)` methods should NOT change
- `PDF.Context` and `PDF.HTML.Context` types keep all their stored properties and methods
- Only the protocol conformance is removed and a factory is added
- Follow the Phase 2 factory pattern exactly (see `Rendering.Context +HTML.swift`)
- New factory files: `Rendering.Context +PDF.swift` and `Rendering.Context +PDF.HTML.swift`
- Add swift-ownership-primitives dependency if needed
- [API-IMPL-005] factory extensions in their own files

## What NOT to Do

- Do NOT attempt the transformer pattern (`consuming func pdfHTML(state:)`) in this phase — it's a future optimization. Use a simple factory method like HTML and PDF.
- Do NOT modify swift-rendering-primitives or swift-html-rendering
- Do NOT modify PDF.Context or PDF.HTML.Context internal structure
- Do NOT remove any methods from the context types — they stay as regular methods
- Do NOT touch the PDF-specific view types and their `_render(context: inout PDF.Context)` methods
