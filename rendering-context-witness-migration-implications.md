# Rendering.Context Witness Migration — Implications

<!--
---
version: 1.2.0
last_updated: 2026-03-14
status: DECISION
tier: 2
---
-->

## Context

`Rendering.Context` is a protocol in swift-rendering-primitives (Layer 1) that defines the push/pop event sink for format-independent rendering. Three concrete types conform: `HTML.Context`, `PDF.Context`, `PDF.HTML.Context`. The protocol is consumed via `_render<C: Rendering.Context>` on every `Rendering.View` implementation.

Prior research (`rendering-context-protocol-vs-witness.md`) empirically demonstrated that witness closures perform identically to protocol dispatch in release builds (0.99–1.04x). The decision to keep the protocol was pragmatic (migration cost), not architectural. With migration cost accepted, the witness approach is architecturally superior: one source of truth for the Action enum, no generic parameter propagation, composability, Observe pattern, testability.

This document analyzes the implications of converting `Rendering.Context` from a protocol to a hand-written witness struct in Layer 1.

## Question

What is the concrete migration scope and design for converting `Rendering.Context` from a protocol to a witness struct, across all rendering packages?

---

## Migration Scope Audit

### Layer 1: swift-rendering-primitives

| Category | Count | Details |
|----------|-------|---------|
| Files referencing Rendering.Context | 12 | All in Rendering Primitives Core |
| `_render<C: Rendering.Context>` implementations | 9 | _Tuple, Conditional, ForEach, Pair, Empty, Array, Optional, Never, default |
| Property.View extensions (push/pop) | 2 | 16 methods total |
| Protocol requirements | 24 | 5 instance + 15 static + 1 apply + 3 optional |
| Test files | 2 | RecordingContext + NonCopyable tests |
| Cross-package references | 0 | Fully isolated |

**Migration**: Protocol definition → struct with 24 closures. 9 `_render<C>` signatures lose the generic. 2 Property.View extensions become methods on the struct. RecordingContext becomes a factory method.

### Layer 3: swift-html-rendering

| Category | Count | Details |
|----------|-------|---------|
| Files referencing Rendering.Context | 9 | HTML Renderable directory |
| `_render<C: Rendering.Context>` implementations | 8 | AnyView, Element.Tag, Styled, Text, Raw, _Attributes, Document.Protocol (2) |
| Property.View accessor calls | 12 | push.element, pop.element, push.attributes, etc. |
| HTML.Context conformance methods | 23 | 10 instance + 13 static |
| Element/attribute files (HTML.View) | ~300 | Use default _render — **UNAFFECTED** |
| Type checks on generic C | 0 | |

**Migration**: 8 `_render<C>` methods drop the generic. HTML.Context conformance → `Rendering.Context.html(...)` factory. 12 Property.View accessor calls → direct struct method calls. ~300 HTML element files are completely unaffected (they use the default body-based `_render`).

**Two-phase document rendering**: `HTML.Document.Protocol._renderHTMLDocument` already creates a concrete `HTML.Context` for body rendering. This becomes `Rendering.Context.html(configuration: ...)`. The two-phase pattern is preserved — the factory creates the witness, body renders into it, styles are extracted, document structure is written.

### Layer 3: swift-pdf-rendering

| Category | Count | Details |
|----------|-------|---------|
| Files referencing Rendering.Context | 3 | Conformance + scope + main type |
| `_render` methods using `inout PDF.Context` | 24 | PDF-specific view protocol, NOT generic C |
| `_render<C: Rendering.Context>` implementations | 0 | PDF uses concrete types |
| PDF.Context conformance methods | 15 | 6 instance + 10 static (push/pop) |
| Property.View accessor calls | 0 | Uses explicit static methods |

**Migration**: PDF.Context conformance (15 methods) → `Rendering.Context.pdf(...)` factory. The 24 PDF-specific `_render` methods using `inout PDF.Context` are **COMPLETELY UNAFFECTED** — they use their own view protocol, not `Rendering.View._render<C>`.

### Layer 3: swift-pdf-html-rendering

| Category | Count | Details |
|----------|-------|---------|
| Files referencing Rendering.Context | 2 | Conformance + main type |
| PDF.HTML.Context conformance methods | 15 | All delegate to PDF.Context |
| Additional non-protocol methods | ~30 | Element push/pop, attributes, styles, tables |

**Migration**: PDF.HTML.Context conformance (15 methods) → `Rendering.Context.pdfHTML(...)` factory. The factory closures wrap PDF.Context closures with additional logic (recording mode, heading tracking, table management). The delegation pattern is preserved — closures call through to the inner PDF context.

### Layer 3: swift-svg-rendering

| Category | Count | Details |
|----------|-------|---------|
| SVG.Context conformance to Rendering.Context | 0 | Does NOT conform |
| Own rendering protocol | Yes | `SVG.View._render` with `inout SVG.Context` |
| Files affected by migration | 0 | Completely independent |

**Migration**: None. SVG has its own view protocol and context type, entirely separate from `Rendering.Context`.

### Layer 3: swift-markdown-html-rendering

| Category | Count | Details |
|----------|-------|---------|
| Files referencing Rendering.Context | 0 | No direct references |
| Interaction with context | Indirect | Via HTML.View → Rendering.View |
| Files affected by migration | 0 | |

**Migration**: None. Markdown produces HTML.View types. The context is managed by the HTML layer. Markdown benefits indirectly — the `Rendering.Action` enum enables the direct-context rendering architecture proposed in `swift-foundations/swift-markdown-html-rendering/Research/markdown-direct-context-rendering.md`.

### Total Migration Blast Radius

| Package | Files modified | Files unaffected |
|---------|---------------|-----------------|
| swift-rendering-primitives | 12 + 2 test | 6 |
| swift-html-rendering | 10 | ~315 |
| swift-pdf-rendering | 1 (conformance) | ~46 |
| swift-pdf-html-rendering | 1 (conformance) | ~105 |
| swift-svg-rendering | 0 | 22 |
| swift-markdown-html-rendering | 0 | 39 |
| **Total** | **~26 files** | **~533 files** |

---

## Design Implications

### 1. The Rendering.Context witness struct

```swift
extension Rendering {
    public struct Context: ~Copyable {
        // --- Instance operations (5 required) ---
        public var text: (String) -> Void
        public var lineBreak: () -> Void
        public var thematicBreak: () -> Void
        public var image: (_ source: String, _ alt: String) -> Void
        public var pageBreak: () -> Void

        // --- Instance operations (5 optional, with defaults) ---
        public var setAttribute: (_ name: String, _ value: String?) -> Void
        public var addClass: (String) -> Void
        public var writeRaw: ([UInt8]) -> Void
        public var registerStyle: (_ declaration: String, _ atRule: String?, _ selector: String?, _ pseudo: String?) -> String?
        public var applyInlineStyle: (Any) -> Bool

        // --- Push/pop operations (15 static → closures) ---
        public var pushBlock: (_ role: Semantic.Block?, _ style: Style) -> Void
        public var popBlock: () -> Void
        public var pushInline: (_ role: Semantic.Inline?, _ style: Style) -> Void
        public var popInline: () -> Void
        public var pushList: (_ kind: Semantic.List, _ start: Int?) -> Void
        public var popList: () -> Void
        public var pushItem: () -> Void
        public var popItem: () -> Void
        public var pushLink: (_ destination: String) -> Void
        public var popLink: () -> Void
        public var pushAttributes: () -> Void
        public var popAttributes: () -> Void
        public var pushElement: (_ tagName: String, _ isBlock: Bool, _ isVoid: Bool, _ isPreElement: Bool) -> Void
        public var popElement: (_ isBlock: Bool) -> Void
        public var pushStyle: () -> Void
        public var popStyle: () -> Void
    }
}
```

**~Copyable**: The struct is `~Copyable` to prevent accidental copies of the closure table and to enforce exactly-one-context ownership. The `consuming` transformer pattern depends on this — the base context is moved into the new context, not copied alongside it.

**Closure captures via `Ownership.Mutable`**: Each factory method captures an `Ownership.Mutable<ConcreteContext>` from swift-ownership-primitives (Layer 1). This is a heap-allocated mutable box with `_read`/`_modify` on `.value` — providing reference semantics for closure capture without unsafe pointers. No `withUnsafeMutablePointer` scoping needed at call sites.

```swift
let html = Ownership.Mutable(HTML.Context(configuration))
var context = Rendering.Context.html(state: html)
// After rendering:
let bytes = html.value.bytes
let styles = html.value.styles
```

For `@Sendable` closure contexts (if the witness needs to cross isolation boundaries), `Ownership.Mutable.Unchecked` provides the opt-in escape hatch — same type, `@unchecked Sendable`, single-consumer contract. Rendering is single-consumer by construction.

### 2. Push/pop accessor API — Property.View preserved

The current `context.push.block(role:style:)` API uses `Property<Rendering.Push, Self>.View` extensions. This pattern is **preserved** with the witness struct. The constraint changes from protocol conformance to concrete type:

```swift
// Before: constrained on protocol conformance
extension Property.View where Tag == Rendering.Push, Base: Rendering.Context & ~Copyable {
    @inlinable
    public func block(role: Rendering.Semantic.Block?, style: Rendering.Style) {
        unsafe Base._pushBlock(&base.pointee, role: role, style: style)
    }
}

// After: constrained on concrete type
extension Property.View where Tag == Rendering.Push, Base == Rendering.Context {
    @inlinable
    public func block(role: Rendering.Semantic.Block?, style: Rendering.Style) {
        unsafe base.pointee.pushBlock(role, style)
    }
}
```

Call-site syntax is identical: `context.push.block(role: .heading(level: 1), style: .empty)`.

The concrete type constraint (`Base == Rendering.Context`) is simpler than the protocol constraint (`Base: Rendering.Context & ~Copyable`) — no protocol conformance check, no `~Copyable` intersection. The `_read`/`_modify` coroutines on the context struct provide the `Property.View` with its mutable pointer, same as the current protocol extension.

### 3. Rendering.Action enum (derived from witness)

```swift
extension Rendering {
    public enum Action: Sendable {
        // Grouped operations (mirror push/pop accessors per [API-NAME-002])
        case push(Push)
        case pop(Pop)

        // Leaf operations
        case text(String)
        case lineBreak
        case thematicBreak
        case image(source: String, alt: String)
        case pageBreak

        // Attribute operations
        case attribute(set: String, value: String?)
        case `class`(add: String)
        case raw([UInt8])
        case style(register: String, atRule: String?, selector: String?, pseudo: String?)
    }
}

extension Rendering.Action {
    public enum Push: Sendable {
        case block(role: Rendering.Semantic.Block?, style: Rendering.Style)
        case inline(role: Rendering.Semantic.Inline?, style: Rendering.Style)
        case list(kind: Rendering.Semantic.List, start: Int?)
        case item
        case link(destination: String)
        case attributes
        case element(tagName: String, isBlock: Bool, isVoid: Bool, isPreElement: Bool)
        case style
    }

    public enum Pop: Sendable {
        case block
        case inline
        case list
        case item
        case link
        case attributes
        case element(isBlock: Bool)
        case style
    }
}
```

**Derivation rule**: One case per witness closure. `applyInlineStyle` excluded — it takes `Any` (not `Sendable`) and returns `Bool`, making it unsuitable for serializable actions. The `borrowing String` parameters become owned `String` (Action must own its data). Push/pop operations are nested per [API-NAME-002], mirroring the `context.push.block(...)` / `context.pop.block()` accessor structure.

**Interpret method**:

```swift
extension Rendering.Context {
    @inlinable
    public mutating func interpret(_ action: Rendering.Action) {
        switch action {
        case .text(let content): text(content)
        case .lineBreak: lineBreak()
        case .thematicBreak: thematicBreak()
        case .image(let source, let alt): image(source, alt)
        case .pageBreak: pageBreak()
        case .attribute(let name, let value): setAttribute(name, value)
        case .class(let name): addClass(name)
        case .raw(let bytes): writeRaw(bytes)
        case .style(let decl, let atRule, let sel, let pseudo):
            _ = registerStyle(decl, atRule, sel, pseudo)
        case .push(let push):
            switch push {
            case .block(let role, let style): pushBlock(role, style)
            case .inline(let role, let style): pushInline(role, style)
            case .list(let kind, let start): pushList(kind, start)
            case .item: pushItem()
            case .link(let dest): pushLink(dest)
            case .attributes: pushAttributes()
            case .element(let tag, let isBlock, let isVoid, let isPre):
                pushElement(tag, isBlock, isVoid, isPre)
            case .style: pushStyle()
            }
        case .pop(let pop):
            switch pop {
            case .block: popBlock()
            case .inline: popInline()
            case .list: popList()
            case .item: popItem()
            case .link: popLink()
            case .attributes: popAttributes()
            case .element(let isBlock): popElement(isBlock)
            case .style: popStyle()
            }
        }
    }

    @inlinable
    public mutating func interpret(_ actions: [Rendering.Action]) {
        for action in actions { interpret(action) }
    }
}
```

### 4. Factory methods and context transformers

Each former protocol conformer becomes a factory method on `Rendering.Context`. Closure state is captured via `Ownership.Mutable<ConcreteContext>` from swift-ownership-primitives — no unsafe pointers needed.

**HTML factory** (in swift-html-rendering):

```swift
extension Rendering.Context {
    public static func html(state: Ownership.Mutable<HTML.Context>) -> Self {
        .init(
            text: { state.value.text($0) },
            lineBreak: { state.value.lineBreak() },
            // ... all 24 closures forwarding to HTML.Context methods
            pushBlock: { role, style in
                HTML.Context._pushBlock(&state.value, role: role, style: style)
            },
            popBlock: { HTML.Context._popBlock(&state.value) },
            // ...
        )
    }
}
```

`HTML.Context._pushBlock` was a protocol requirement; with the witness, these become regular methods on `HTML.Context` (same implementation, different declaration). The factory captures them as closures.

**PDF factory** (in swift-pdf-rendering):

Same pattern. `PDF.Context`'s methods remain; the conformance becomes a factory.

```swift
extension Rendering.Context {
    public static func pdf(state: Ownership.Mutable<PDF.Context>) -> Self {
        .init(
            text: { state.value.text($0) },
            pushBlock: { role, style in
                PDF.Context._pushBlock(&state.value, role: role, style: style)
            },
            // ...
        )
    }
}
```

**PDF.HTML — context transformer** (in swift-pdf-html-rendering):

`PDF.HTML.Context` is categorically an **algebra endomorphism** — it takes a PDF rendering context and decorates each operation with HTML-semantic understanding (heading tracking, table layout, margin collapsing). This is expressed as a `consuming` transformer method on `Rendering.Context`:

```swift
extension Rendering.Context {
    /// Algebra endomorphism: decorates a base context with HTML semantic understanding.
    /// The base context is consumed; its closures are moved into the new context's closures.
    public consuming func pdfHTML(
        state: Ownership.Mutable<PDF.HTML.State>
    ) -> Rendering.Context {
        let baseText = self.text
        let basePushBlock = self.pushBlock
        let basePopBlock = self.popBlock
        // ... capture all base closures

        return Rendering.Context(
            text: { content in
                // Stateful enrichment: track heading text
                if state.value.activeHeading != nil {
                    state.value.activeHeading!.text += content
                }
                baseText(content)
            },
            pushBlock: { role, style in
                // Stateful enrichment: start heading tracking
                if case .heading(let level) = role {
                    state.value.startHeading(level: level)
                }
                basePushBlock(role, style)
            },
            popBlock: {
                // Stateful enrichment: finalize heading for bookmarks
                if let heading = state.value.activeHeading {
                    state.value.headings.append(heading)
                    state.value.activeHeading = nil
                }
                basePopBlock()
            },
            // ... each closure wraps the base with HTML-specific logic
        )
    }
}
```

The rendering entry point composes naturally:

```swift
let pdfState = Ownership.Mutable(PDF.Context(configuration: config))
let htmlState = Ownership.Mutable(PDF.HTML.State())

var context = Rendering.Context.pdf(state: pdfState)
    .pdfHTML(state: htmlState)

// Render into composed context...
// After: pdfState.value has PDF pages, htmlState.value has heading bookmarks
```

The base context is `consuming` — its closures are moved into the transformed context. `~Copyable` enforces that only the composed context exists. The `Ownership.Mutable` captures provide shared mutable access without unsafe code.

This replaces the current `PDF.HTML.Context` type with:
1. **`PDF.HTML.State`** — the mutable state (heading tracking, table layout, element scopes, margin collapsing)
2. **A transformer method** `.pdfHTML(state:)` that wraps a base context with HTML-semantic logic

The 1095-line conformance extension becomes closure bodies in the transformer. The logic doesn't change — only the declaration form.

### 5. Rendering.View._render signature change

```swift
// Before
public protocol View: ~Copyable {
    associatedtype Body: View & ~Copyable
    @Builder var body: Body { get }
    static func _render<C: Context>(_ view: borrowing Self, context: inout C)
}

// After
public protocol View: ~Copyable {
    associatedtype Body: View & ~Copyable
    @Builder var body: Body { get }
    static func _render(_ view: borrowing Self, context: inout Context)
}
```

The default implementation changes from:
```swift
extension Rendering.View where Body: Rendering.View {
    public static func _render<C: Rendering.Context>(_ view: borrowing Self, context: inout C) {
        Body._render(view.body, context: &context)
    }
}
```

To:
```swift
extension Rendering.View where Body: Rendering.View {
    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) {
        Body._render(view.body, context: &context)
    }
}
```

Every downstream view type that overrides `_render` changes its signature identically. The ~300 HTML element files that use the DEFAULT implementation (via `body`) need NO changes.

### 6. HTML.AnyView existential opening

```swift
// Before
public static func _render<C: Rendering.Context>(_ view: borrowing HTML.AnyView, context: inout C) {
    _openAndRender(view.base, context: &context)
}
private static func _openAndRender<V: HTML.View, C: Rendering.Context>(_ base: V, context: inout C) {
    V._render(base, context: &context)
}

// After
public static func _render(_ view: borrowing HTML.AnyView, context: inout Rendering.Context) {
    _openAndRender(view.base, context: &context)
}
private static func _openAndRender<V: HTML.View>(_ base: V, context: inout Rendering.Context) {
    V._render(base, context: &context)
}
```

The existential opening on `V: HTML.View` still works — it's the VIEW that's type-erased, not the context. Only the `C` parameter disappears.

### 7. HTML.Document two-phase rendering

```swift
// Before
var bodyContext = HTML.Context(configuration)
Body._render(html.body, context: &bodyContext)

// After
let bodyState = Ownership.Mutable(HTML.Context(configuration))
var bodyContext = Rendering.Context.html(state: bodyState)
Body._render(html.body, context: &bodyContext)
let bodyBytes = bodyState.value.bytes
let collectedStyles = bodyState.value.styles
```

The two-phase pattern is preserved. The concrete `HTML.Context` is created inside an `Ownership.Mutable`, a witness wraps it, body renders into the witness, then styles and bytes are extracted from the `Ownership.Mutable`'s value. No unsafe pointers. The state is accessible after rendering via `bodyState.value`.

---

## Risk Assessment

### Low risk

- **~300 HTML element files**: Unaffected. Use default `_render` via `body`.
- **24 PDF _render methods**: Unaffected. Use concrete `inout PDF.Context`, not generic.
- **SVG rendering**: Unaffected. Independent pipeline.
- **Markdown rendering**: Unaffected. Indirect via HTML.View.

### Medium risk

- **Push/Pop accessor constraint change**: The `Property.View` pattern is preserved but the constraint changes from `Base: Rendering.Context & ~Copyable` (protocol) to `Base == Rendering.Context` (concrete type). Call-site syntax is identical. The implementation changes from calling static protocol methods to calling witness closures.
- **`~Copyable` witness struct**: Closures are Copyable by default. A `~Copyable` struct containing closures compiles (validated by experiment `rendering-context-algebra-composition`). The `consuming` transformer pattern depends on `~Copyable` — the base context is moved into the new context, enforcing exactly-one-context ownership.
- **`Ownership.Mutable` capture**: Each factory creates closures capturing `Ownership.Mutable<ConcreteContext>`. This is reference-counted shared mutable access — no unsafe code, no pointer scoping. The `Ownership.Mutable` value is accessible after rendering for state extraction (bytes, styles, pages). Validated by experiment V1b and V2.

### High risk

- **PDF.HTML.Context → transformer decomposition**: The most complex conformer (1095 lines). Currently a single type with protocol conformance + additional methods. Becomes: (1) `PDF.HTML.State` struct holding the mutable state, and (2) a `.pdfHTML(state:)` consuming transformer on `Rendering.Context`. The logic doesn't change — closure bodies contain the same code. But extracting the state into a separate type and expressing the delegation as closure wrapping requires careful porting. The experiment (`rendering-context-algebra-composition` V2) validated the transformer pattern compiles and composes correctly.
- **HTML.Context two-phase rendering**: The body render creates a separate `Ownership.Mutable(HTML.Context(...))` and witness for the body pass. Styles collected during body rendering are extracted from `bodyState.value.styles` and injected into the head. The pattern is validated by experiment V1b (state accessible after rendering via `Ownership.Mutable`).

---

## Migration Plan

### Phase 1: L1 witness struct + Action enum

1. Replace `Rendering.Context` protocol with witness struct (24 closures)
2. Add `Rendering.Action` enum (derived from closures)
3. Add `interpret(_:)` and `interpret(_:)` methods
4. Add Push/Pop nested accessor structs
5. Update `Rendering.View._render` signature (remove generic C)
6. Update 9 L1 `_render` implementations
7. Update RecordingContext → `Rendering.Context.recording(...)` factory
8. Update L1 tests

**Scope**: 14 files. Self-contained within swift-rendering-primitives.

### Phase 2: HTML rendering migration

1. Remove `HTML.Context: Rendering.Context` conformance
2. Add `Rendering.Context.html(context:)` factory
3. Update 8 `_render<C>` methods (drop generic)
4. Update 12 Property.View accessor calls → struct methods
5. Update `HTML.Document.Protocol._renderHTMLDocument`
6. Verify ~300 element files compile unchanged

**Scope**: 10 files in swift-html-rendering.

### Phase 3: PDF rendering migration

1. Remove `PDF.Context: Rendering.Context` conformance
2. Add `Rendering.Context.pdf(state:)` factory using `Ownership.Mutable<PDF.Context>`
3. Verify 24 PDF-specific _render methods unchanged
4. Extract `PDF.HTML.State` from `PDF.HTML.Context` (heading tracking, table layout, element scopes, margin collapsing)
5. Add `consuming func pdfHTML(state: Ownership.Mutable<PDF.HTML.State>) -> Rendering.Context` transformer
6. Remove `PDF.HTML.Context: Rendering.Context` conformance

**Scope**: 2 conformance files + 1 new `PDF.HTML.State` type. The 1095-line conformance logic moves into transformer closure bodies.

### Phase 4: Markdown direct rendering

With the witness + Action enum in place:
1. `Markdown.Rendering` witness produces `[Rendering.Action]`
2. `Markdown` becomes leaf view (`Body = Never`)
3. `DirectConverter` interprets actions against the concrete context
4. Stack overflow resolved

**Scope**: swift-markdown-html-rendering (new architecture).

---

## Outcome

**Status**: DECISION

**Choice**: Option A — hand-written witness struct in Layer 1.

**Validated by experiments**:
- `rendering-context-algebra-composition` (15 tests): witness struct, consuming transformer, observer, action interpreter, `Ownership.Mutable` capture — all CONFIRMED
- `rendering-witness-migration-blockers` (24 tests): non-generic `_render` protocol requirement, `Property.View` with `Base == Rendering.Context`, AnyView existential opening without generic C, tee transform — all CONFIRMED
- `rendering-context-protocol-vs-witness` (performance): witness 0.99–1.04x of protocol in release — CONFIRMED

**Rationale**: The migration blast radius is **~26 files** across 4 packages, with **~533 files completely unaffected**. The PDF-specific view types (24 files), SVG rendering (22 files), HTML element types (~300 files), and markdown rendering (39 files) require zero changes. The witness struct provides: one source of truth for the Action enum, no generic parameter propagation on `_render`, composable closures, and the foundation for the markdown direct-context rendering architecture.

**Phased execution**: L1 first (self-contained), then HTML, then PDF, then markdown. Each phase is independently testable and committable.

**Key infrastructure**: `Ownership.Mutable<T>` from swift-ownership-primitives (Layer 1) provides heap-allocated mutable state capture for closures — no unsafe pointers at call sites. `Ownership.Mutable.Unchecked` for `@Sendable` closure contexts if needed.

**Context transformer pattern**: `PDF.HTML.Context` dissolves into `PDF.HTML.State` + a `consuming` transformer method on `Rendering.Context`. Transformers are algebra endomorphisms — they compose via function composition on the witness's closures. Validated by experiment `rendering-context-algebra-composition` (V2, V3).

## References

- `swift-institute/Research/rendering-context-protocol-vs-witness.md` — performance experiment (V2 witness ≈ V1 protocol)
- `swift-foundations/swift-markdown-html-rendering/Research/markdown-direct-context-rendering.md` — motivating architecture
- `swift-foundations/swift-markdown-html-rendering/Research/markdown-rendering-organization-audit.md` — F-6 AnyView finding
- `swift-pdf/Research/sigbus-stack-overflow-handoff.md` — stack overflow root cause
- `swift-institute/Experiments/rendering-context-algebra-composition/` — transformer pattern validation (15 tests, all pass)
- `swift-institute/Research/prompts/rendering-context-protocol-vs-witness-experiment.md` — performance experiment prompt
- `swift-rendering-primitives/.../Rendering.Context.swift` — current protocol (262 lines)
- `swift-html-rendering/.../HTML.Context.swift` — HTML conformer (633 lines)
- `swift-pdf-html-rendering/.../PDF.HTML.Context+Rendering.swift` — PDF-HTML conformer (1095 lines)
- `swift-ownership-primitives/.../Ownership.Mutable.swift` — mutable state capture infrastructure
