# Rendering Witness Architecture — Value Analysis

<!--
---
version: 1.0.0
last_updated: 2026-03-14
status: RECOMMENDATION
tier: 2
---
-->

## Context

`Rendering.Context` is a protocol in swift-rendering-primitives (Layer 1) with 26 requirements (10 instance methods, 16 static push/pop methods) defining the abstract rendering destination. Three types conform: `HTML.Context` (633 lines), `PDF.Context`, and `PDF.HTML.Context` (1095 lines). Every `Rendering.View` implementation carries `static func _render<C: Rendering.Context>`, propagating the generic `C` across 40+ type signatures.

Prior research established:
- **Performance parity**: Witness closure dispatch costs 0.99–1.04x vs protocol dispatch in release builds (`rendering-context-protocol-vs-witness.md`, V2 vs V1). The performance question is settled.
- **Composability validation**: The experiment `rendering-context-algebra-composition` validated that `~Copyable` witness structs with `consuming` transformers compile, compose, and produce correct output (15 tests, all pass).
- **Migration feasibility**: ~26 files across 4 packages require changes; ~533 are unaffected (`rendering-context-witness-migration-implications.md`).
- **Motivating problem**: The markdown→HTML→PDF pipeline overflows the stack via deeply nested `HTML.AnyView` type erasure; the `Rendering.Action` enum (a natural product of the witness architecture) enables flat iterative rendering (`markdown-direct-context-rendering.md`).

The previous decision (`rendering-context-protocol-vs-witness.md`, Option C — hybrid) was explicitly pragmatic: *"The decision to keep the protocol was pragmatic (migration cost), not architectural."* This document analyzes the architectural delta with migration cost excluded.

### Related research

- `rendering-context-witness-migration-implications.md` — migration scope and design (RECOMMENDATION)
- `rendering-context-protocol-vs-witness.md` — performance experiment (DECISION: hybrid)
- `markdown-direct-context-rendering.md` — motivating architecture (RECOMMENDATION)
- `rendering-context-algebra-composition` — composition experiment (15 tests)
- `protocol-witness-effects-capability-abstraction.md` — general protocol vs witness analysis
- `witnesses-ecosystem-adoption-audit.md` — ecosystem witness adoption

---

## Question

What is the architectural value of the witness-based `Rendering.Context` compared to the protocol-based one? What capabilities does the witness + transformer + action architecture enable that the protocol cannot? What does the protocol retain?

---

## Analysis

### Part 1: Direct Comparison

#### 1. Composability

**Protocol**: Combining rendering behaviors requires declaring new types. `PDF.HTML.Context` is a 1095-line dedicated type that exists solely to compose PDF rendering with HTML-semantic understanding. Each new format combination (HTML+SVG, HTML+ePub, PDF+accessibility) requires another conformer. Adding logging to any context requires either modifying the conformer's source or creating a wrapper conformer that forwards all 26 requirements while inserting logging. With 3 conformers, 3 middleware needs (logging, profiling, validation) would require up to 9 additional types.

```swift
// Protocol: dedicated type per combination
struct LoggingHTMLContext: Rendering.Context {
    var inner: HTML.Context
    var log: [String]

    mutating func text(_ content: borrowing String) {
        log.append("text: \(content)")
        inner.text(content)
    }
    // ... 25 more requirements to forward
}
```

**Witness**: Transformers compose via `consuming` methods on the witness struct. `PDF.HTML.Context` dissolves into a `.pdfHTML(state:)` transformer — a single method that wraps the base context's closures. Adding logging is another transformer: `.observing(log:)`. These chain without declaring new types:

```swift
// Witness: composition chain, zero new types
var context = Rendering.Context.pdf(state: pdfState)
    .pdfHTML(state: htmlState)
    .observing(log: actionLog)
```

Each transformer is O(n) in the number of operations it wraps (typically all of them, ~30 lines for a pass-through that decorates). New combinations are methods, not types. The experiment (`V2_Transformer.swift`, `V3_ObservingTransformer.swift`) validates this compiles and produces correct output.

**Verdict**: The witness enables open-ended behavioral composition without type proliferation. The protocol requires O(n × m) types for n formats and m middleware; the witness requires O(n + m) methods.

---

#### 2. Testability

**Protocol**: Testing a view's rendering output requires a full mock conformer implementing all 26 requirements. The current `RecordingContext` in tests is ~50 lines. You cannot stub a single operation — the protocol requires all of them. To verify that a specific view emits the right `pushBlock` with the right role, you must construct a full mock that records everything, then search its output.

```swift
// Protocol: full mock conformer
struct RecordingContext: Rendering.Context {
    var actions: [String] = []
    mutating func text(_ content: borrowing String) { actions.append("text:\(content)") }
    mutating func lineBreak() { actions.append("lineBreak") }
    // ... 24 more method stubs
    static func _pushBlock(_ context: inout Self, role: Rendering.Semantic.Block?, style: Rendering.Style) {
        context.actions.append("pushBlock:\(role)")
    }
    // ... 15 more static stubs
}
```

**Witness**: A recording context is a factory method returning `Rendering.Context`. Individual closures can be stubbed:

```swift
// Witness: recording factory
extension Rendering.Context {
    static func recording(into log: Ownership.Mutable<[Rendering.Action]>) -> Self {
        .init(
            text: { log.value.append(.text($0)) },
            lineBreak: { log.value.append(.lineBreak) },
            pushBlock: { role, style in log.value.append(.push(.block(role: role, style: style))) },
            // ... naturally mirrors the Action enum
        )
    }
}
```

To stub a single operation (e.g., verify text escaping without caring about structure):

```swift
// Witness: single-operation stub
var texts: [String] = []
var context = Rendering.Context.recording(into: log)
context.text = { texts.append($0) }  // override just text
```

**Verdict**: The witness enables granular stubbing — test exactly the operation you care about. The protocol demands all-or-nothing mock conformers.

---

#### 3. Action Reification

**Protocol**: No natural path to representing "what operations were performed" as data. A `Rendering.Action` enum must be hand-derived separately from the protocol and kept in sync manually. The protocol and the enum are two abstractions representing the same 26 operations — a maintenance liability:

```swift
// Protocol + separate enum: dual-abstraction sync problem
protocol Context {
    mutating func text(_ content: borrowing String)  // → must stay in sync with
}
enum Action {
    case text(String)                                 // ← this case
}
// If a requirement is added to the protocol, the enum must be updated too.
// The compiler does not enforce this correspondence.
```

**Witness**: Each stored closure maps 1:1 to an enum case. The `interpret(_:)` method is the canonical bridge:

```swift
// Witness: one-to-one correspondence
public struct Context: ~Copyable {
    public var text: (String) -> Void      // ←→ case text(String)
    public var pushBlock: (...) -> Void    // ←→ case push(.block(...))
}

public mutating func interpret(_ action: Rendering.Action) {
    switch action {
    case .text(let content): text(content)
    case .push(.block(let role, let style)): pushBlock(role, style)
    // ...
    }
}
```

The `Action` enum is derived from the witness's closure signature — one source of truth. Adding a new operation means adding a closure AND a case; the `interpret` switch is exhaustive, so the compiler enforces completeness.

**Verdict**: The witness yields a naturally derived action enum with compiler-enforced correspondence. The protocol requires manual sync between two independent abstractions.

---

#### 4. Generic Parameter Propagation

**Protocol**: `C: Rendering.Context` appears on 40+ type signatures. Every view that overrides `_render` carries the generic:

```swift
// Protocol: generic infection
public protocol View: ~Copyable {
    static func _render<C: Context>(_ view: borrowing Self, context: inout C)
}

// Every override:
extension HTML.Element.Tag {
    public static func _render<C: Rendering.Context>(
        _ view: borrowing Self, context: inout C
    ) { ... }
}

// Constrained extensions need the generic too:
extension Property.View where Tag == Rendering.Push, Base: Rendering.Context & ~Copyable {
    public func block(role:style:) { ... }
}
```

Downstream effects: every function that calls `_render` must also be generic over `C`. Error messages include `C` in their types. Conditional conformances must account for `C`. IDE autocompletion shows `C` as a type parameter.

**Witness**: Zero generic parameter. Every `_render` takes the concrete type:

```swift
// Witness: no generics
public protocol View: ~Copyable {
    static func _render(_ view: borrowing Self, context: inout Context)
}

// Every override:
extension HTML.Element.Tag {
    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) { ... }
}

// Property.View: concrete constraint
extension Property.View where Tag == Rendering.Push, Base == Rendering.Context {
    public func block(role:style:) { ... }
}
```

**Verdict**: The witness eliminates an entire dimension of generic complexity. `C: Rendering.Context` disappears from 40+ signatures, simplifying call sites, error messages, and constrained extensions.

---

#### 5. Middleware / Instrumentation

**Protocol**: Adding before/after hooks to all rendering operations requires a wrapper conformer that implements all 26 requirements, forwarding each to the inner context with instrumentation:

```swift
// Protocol: full wrapper for instrumentation
struct ProfilingContext<C: Rendering.Context>: Rendering.Context {
    var inner: UnsafeMutablePointer<C>
    var durations: [String: Duration] = [:]

    mutating func text(_ content: borrowing String) {
        let start = ContinuousClock.now
        inner.pointee.text(content)
        durations["text", default: .zero] += ContinuousClock.now - start
    }
    // ... 25 more forwarding methods with timing
    static func _pushBlock(_ context: inout Self, role: ..., style: ...) {
        let start = ContinuousClock.now
        C._pushBlock(&context.inner.pointee, role: role, style: style)
        context.durations["pushBlock", default: .zero] += ContinuousClock.now - start
    }
    // ... 15 more static forwarders
}
```

This is ~100+ lines of boilerplate. Each new middleware (logging, validation, analytics) repeats the pattern. The wrapper is itself generic over `C`, further propagating the generic parameter.

**Witness**: A `consuming` transformer wraps all closures in a loop:

```swift
// Witness: observing transformer
extension Rendering.Context {
    public consuming func observing(
        log: Ownership.Mutable<[Rendering.Action]>
    ) -> Rendering.Context {
        let baseText = self.text
        let basePushBlock = self.pushBlock
        // ... capture all base closures

        return Rendering.Context(
            text: { content in
                log.value.append(.text(content))
                baseText(content)
            },
            pushBlock: { role, style in
                log.value.append(.push(.block(role: role, style: style)))
                basePushBlock(role, style)
            },
            // ...
        )
    }
}
```

The experiment (`V3_ObservingTransformer.swift`) validates this — 22 closures wrapped, all actions logged, composable with other transformers.

**Verdict**: The witness reduces middleware from ~100-line conformer types to ~50-line transformer methods, with no generic parameter overhead.

---

#### 6. Format Composition

**Protocol**: Each format combination requires a dedicated conformer type. The current three conformers represent three distinct combinations:
- `HTML.Context` — HTML output
- `PDF.Context` — PDF output
- `PDF.HTML.Context` — PDF output with HTML-semantic understanding

Adding HTML+SVG requires a fourth conformer. HTML+ePub a fifth. Each conformer must implement all 26 requirements, even if most delegate to an inner context. The relationship between conformers is opaque — there's no structural indication that `PDF.HTML.Context` wraps `PDF.Context`.

**Witness**: Format composition is explicit in the transformer chain:

```swift
// Two base factories:
Rendering.Context.html(state: htmlState)
Rendering.Context.pdf(state: pdfState)

// Composition via transformers:
Rendering.Context.pdf(state: pdfState).pdfHTML(state: htmlState)     // PDF + HTML semantics
Rendering.Context.html(state: htmlState).svgEmbed(state: svgState)   // HTML + SVG embedding
Rendering.Context.html(state: htmlState).epub(state: epubState)      // HTML + ePub metadata
```

The transformer chain reads as a composition pipeline. The relationship between formats is explicit — `.pdfHTML(state:)` visibly transforms the `.pdf(state:)` base. New combinations are new transformer methods, not new types.

**Verdict**: The witness makes format composition O(n + m) transformer methods instead of O(n × m) conformer types. The composition structure is visible in the code.

---

#### 7. Partial Override

**Protocol**: Changing a single operation requires creating a new conformer or modifying the existing one. There is no mechanism to override `text()` on an `HTML.Context` instance without subclassing (which `~Copyable` disallows) or creating a wrapper.

```swift
// Protocol: full wrapper for one override
struct TranslatingHTMLContext: Rendering.Context {
    var inner: UnsafeMutablePointer<HTML.Context>
    let locale: Locale

    mutating func text(_ content: borrowing String) {
        let translated = translate(content, locale: locale)
        inner.pointee.text(translated)
    }
    // ... 25 more forwarding methods, identical to inner
    static func _pushBlock(_ context: inout Self, role: ..., style: ...) {
        HTML.Context._pushBlock(&context.inner.pointee, role: role, style: style)
    }
    // ...
}
```

**Witness**: Replace one closure on the struct:

```swift
// Witness: single-closure override
var context = Rendering.Context.html(state: htmlState)
let originalText = context.text
context.text = { content in
    originalText(translate(content, locale: locale))
}
```

Or as a named transformer:

```swift
extension Rendering.Context {
    public consuming func translating(locale: Locale) -> Rendering.Context {
        let baseText = self.text
        var copy = self
        copy.text = { baseText(translate($0, locale: locale)) }
        return copy
    }
}
```

Wait — `~Copyable` prevents `var copy = self`. The `consuming` pattern captures individual closures:

```swift
extension Rendering.Context {
    public consuming func translating(locale: Locale) -> Rendering.Context {
        let baseText = self.text
        let baseLB = self.lineBreak
        let baseTB = self.thematicBreak
        // ... capture all closures
        return .init(
            text: { baseText(translate($0, locale: locale)) },
            lineBreak: baseLB,          // pass-through
            thematicBreak: baseTB,      // pass-through
            // ... all others pass-through
        )
    }
}
```

**Verdict**: The witness enables per-operation override — either by mutating a single closure field or via a focused transformer. The protocol requires a full 26-method wrapper.

---

#### 8. Dependency Injection

**Protocol**: `Rendering.Context` is a protocol, not a type. It cannot be stored directly — only as a constrained generic or via type erasure. The ecosystem's `Witness.Key` / `Dependency.Scope` pattern requires a concrete type for the stored value:

```swift
// Protocol: cannot store directly
struct RenderingKey: Witness.Key {
    typealias Value = ???  // Cannot write `any Rendering.Context` (it's ~Copyable)
                           // Cannot write `Rendering.Context` (it's a protocol)
}
```

You must either make the dependency itself generic (`struct RenderingDependency<C: Rendering.Context>`) or erase to a concrete type — which is exactly what the witness provides.

**Witness**: `Rendering.Context` is a concrete `~Copyable` struct. It stores directly:

```swift
// Witness: concrete type, stores directly
struct RenderingKey: Witness.Key {
    typealias Value = Rendering.Context  // concrete struct
}

// In dependency scope:
scope.set(RenderingKey.self, to: .html(state: htmlState))
// Or:
scope.set(RenderingKey.self, to: .pdf(state: pdfState).pdfHTML(state: htmlState))
```

Different environments inject different factory configurations. Test environments inject recording contexts. The type is always `Rendering.Context` — the factory determines behavior.

**Verdict**: The witness is a concrete type that integrates with dependency injection. The protocol requires generic indirection or manual type erasure.

---

#### 9. Serialization

**Protocol**: Protocol dispatch is ephemeral. When `context.text("hello")` executes, the operation happens and no record exists unless the conformer explicitly logs it. There is no standard way to serialize "what a render did" without modifying every conformer.

**Witness**: `Rendering.Action` is `Sendable` and can be made `Codable`:

```swift
// Witness: rendering as serializable data
let log = Ownership.Mutable<[Rendering.Action]>([])
var context = Rendering.Context.recording(into: log)
SomeView._render(view, context: &context)

// Serialize to disk:
let data = try JSONEncoder().encode(log.value)
try data.write(to: url)

// Deserialize and replay:
let actions = try JSONDecoder().decode([Rendering.Action].self, from: data)
var htmlContext = Rendering.Context.html(state: htmlState)
htmlContext.interpret(actions)
```

This enables render servers that pre-render markdown to action sequences, cache them, and interpret on-demand in the target format.

**Verdict**: The witness + action architecture makes rendering operations first-class data that can be serialized, transmitted, cached, and replayed. The protocol provides no path to this without bolting on a separate recording layer.

---

### Part 2: What the Witness Architecture Unlocks

#### 1. Rendering-as-Data

With `[Rendering.Action]` as the intermediate representation, rendering operations become inspectable, transformable data.

**Structural diffing** — compare two renders to find what changed:

```swift
func diff(
    _ lhs: [Rendering.Action],
    _ rhs: [Rendering.Action]
) -> [Change<Rendering.Action>] {
    // Standard sequence diff on action arrays
    // Detects inserted/removed/modified rendering operations
    // Semantic diff: "heading level changed from 2 to 3"
    //   not byte diff: "changed <h2> to <h3>"
}
```

A byte diff on HTML output conflates structural changes with formatting artifacts (whitespace, attribute order). An action diff captures structural intent: "a `.push(.block(role: .heading(level: 2)))` became `.push(.block(role: .heading(level: 3)))`."

**Server-side pre-rendering** — serialize actions from a render server, interpret locally:

```swift
// Server:
let actions = renderMarkdownToActions(document)
let data = encode(actions)
respond(with: data)

// Client:
let actions = decode(data)
var context = Rendering.Context.html(state: htmlState)
context.interpret(actions)
// HTML output is identical to server-rendered, but generated client-side
```

This separates the rendering computation (walking the view tree) from the format-specific interpretation (emitting bytes). The action sequence is a portable intermediate representation.

**Action-level caching** — cache the action sequence keyed by content hash:

```swift
func render(markdown: String, into context: inout Rendering.Context) {
    let hash = markdown.hashValue
    if let cached = actionCache[hash] {
        context.interpret(cached)
        return
    }
    let log = Ownership.Mutable<[Rendering.Action]>([])
    var recording = Rendering.Context.recording(into: log)
    Markdown._render(markdown, context: &recording)
    actionCache[hash] = log.value
    context.interpret(log.value)
}
```

Same markdown → same action sequence → skip the entire AST walk and view traversal.

**Action transformation** — map over actions to modify rendering post-hoc:

```swift
func demoteHeadings(_ actions: [Rendering.Action]) -> [Rendering.Action] {
    actions.map { action in
        guard case .push(.block(role: .heading(let level), let style)) = action else {
            return action
        }
        return .push(.block(role: .heading(level: min(level + 1, 6)), style: style))
    }
}
```

This is impossible with the protocol — by the time the heading is pushed, the concrete context has already emitted its format-specific bytes.

**Render streaming** — produce and interpret actions incrementally:

```swift
func streamRender(
    document: Markdown.Document,
    context: inout Rendering.Context
) {
    for node in document.children {
        let actions = renderNode(node)
        context.interpret(actions)
        // Each node's actions are interpreted immediately
        // No need to buffer the entire action sequence
    }
}
```

---

#### 2. Context Composition Algebra

Transformers are endomorphisms on the Σ-algebra. Since they compose via function composition, they form a monoid. Novel transformers become trivially expressible:

**Accessibility layer** — adds ARIA semantics to every element push:

```swift
extension Rendering.Context {
    public consuming func accessible() -> Rendering.Context {
        let basePushBlock = self.pushBlock
        let basePushList = self.pushList
        let baseSetAttr = self.setAttribute
        // ... capture all

        return .init(
            // ...
            pushBlock: { role, style in
                basePushBlock(role, style)
                if let role {
                    switch role {
                    case .heading(let level):
                        baseSetAttr("role", "heading")
                        baseSetAttr("aria-level", "\(level)")
                    case .blockquote:
                        baseSetAttr("role", "blockquote")
                    case .paragraph:
                        baseSetAttr("role", "paragraph")
                    // ...
                    }
                }
            },
            pushList: { kind, start in
                basePushList(kind, start)
                switch kind {
                case .ordered: baseSetAttr("role", "list")
                case .unordered: baseSetAttr("role", "list")
                }
            },
            // ... other operations pass through
        )
    }
}

// Usage:
var context = Rendering.Context.html(state: htmlState).accessible()
```

**Validation layer** — verifies push/pop balance at runtime:

```swift
extension Rendering.Context {
    public consuming func validating(
        state: Ownership.Mutable<ValidationState>
    ) -> Rendering.Context {
        let basePushBlock = self.pushBlock
        let basePopBlock = self.popBlock
        // ...

        return .init(
            // ...
            pushBlock: { role, style in
                state.value.stack.append(.block)
                basePushBlock(role, style)
            },
            popBlock: {
                precondition(state.value.stack.last == .block, "Unbalanced pop.block()")
                state.value.stack.removeLast()
                basePopBlock()
            },
            // ... same for inline, list, item, link, element, style
        )
    }
}
```

**Theme layer** — overrides styles without changing content:

```swift
extension Rendering.Context {
    public consuming func themed(palette: Theme.Palette) -> Rendering.Context {
        let basePushBlock = self.pushBlock
        let basePushInline = self.pushInline
        // ...

        return .init(
            // ...
            pushBlock: { role, style in
                let themedStyle = palette.apply(to: style, role: role)
                basePushBlock(role, themedStyle)
            },
            pushInline: { role, style in
                let themedStyle = palette.apply(to: style, role: role)
                basePushInline(role, themedStyle)
            },
            // ... all other operations pass through
        )
    }
}
```

**Analytics layer** — counts elements and measures nesting depth:

```swift
extension Rendering.Context {
    public consuming func counting(
        stats: Ownership.Mutable<RenderingStats>
    ) -> Rendering.Context {
        let baseText = self.text
        let basePushBlock = self.pushBlock
        let basePopBlock = self.popBlock
        // ...

        return .init(
            text: { content in
                stats.value.textCount += 1
                stats.value.characterCount += content.count
                baseText(content)
            },
            pushBlock: { role, style in
                stats.value.depth += 1
                stats.value.maxDepth = max(stats.value.maxDepth, stats.value.depth)
                if case .heading = role { stats.value.headingCount += 1 }
                basePushBlock(role, style)
            },
            popBlock: {
                stats.value.depth -= 1
                basePopBlock()
            },
            // ...
        )
    }
}
```

All four transformers compose freely:

```swift
var context = Rendering.Context.html(state: htmlState)
    .accessible()
    .themed(palette: darkMode)
    .counting(stats: renderStats)
    .validating(state: validationState)
```

---

#### 3. Testing Infrastructure

**Snapshot testing via action comparison**:

```swift
@Test func headingRendersCorrectActions() {
    let log = Ownership.Mutable<[Rendering.Action]>([])
    var context = Rendering.Context.recording(into: log)
    Heading(level: 2) { Text("Hello") }._render(context: &context)

    #expect(log.value == [
        .push(.block(role: .heading(level: 2), style: .empty)),
        .text("Hello"),
        .pop(.block)
    ])
}
```

This tests the structural rendering intent, not the byte output. A change in HTML indentation or attribute ordering doesn't break the test. A change in heading level does.

**Property-based testing** — generate random action sequences, verify all contexts handle them:

```swift
@Test(arguments: ActionGenerator.samples(count: 1000))
func allContextsHandleArbitraryActions(actions: [Rendering.Action]) {
    // HTML context doesn't crash:
    let htmlState = Ownership.Mutable(HTML.Context(.default))
    var html = Rendering.Context.html(state: htmlState)
    html.interpret(actions)

    // PDF context doesn't crash:
    let pdfState = Ownership.Mutable(PDF.Context(.default))
    var pdf = Rendering.Context.pdf(state: pdfState)
    pdf.interpret(actions)
}
```

**Regression detection** — diff action sequences between versions:

```swift
@Test func markdownRenderingIsStable() throws {
    let markdown = loadFixture("complex-document.md")
    let log = Ownership.Mutable<[Rendering.Action]>([])
    var context = Rendering.Context.recording(into: log)
    Markdown(markdown)._render(context: &context)

    let baseline = try loadBaseline("complex-document.actions")
    let changes = diff(baseline, log.value)
    #expect(changes.isEmpty, "Rendering changed: \(changes)")
}
```

---

#### 4. Multi-Format Rendering

**Tee transform** — duplicate operations to two contexts simultaneously:

```swift
extension Rendering.Context {
    public static func tee(
        _ a: consuming Rendering.Context,
        _ b: consuming Rendering.Context
    ) -> Rendering.Context {
        let aText = a.text, bText = b.text
        let aPushBlock = a.pushBlock, bPushBlock = b.pushBlock
        // ... capture all closures from both

        return .init(
            text: { content in aText(content); bText(content) },
            pushBlock: { role, style in aPushBlock(role, style); bPushBlock(role, style) },
            // ...
        )
    }
}

// One render pass → HTML + PDF:
let htmlState = Ownership.Mutable(HTML.Context(.default))
let pdfState = Ownership.Mutable(PDF.Context(.default))
var context = Rendering.Context.tee(
    .html(state: htmlState),
    .pdf(state: pdfState).pdfHTML(state: htmlState)
)
SomeView._render(view, context: &context)
// htmlState.value.bytes → HTML output
// pdfState.value.pages → PDF output
```

This is structurally impossible with the protocol — `_render<C: Rendering.Context>` is monomorphic in `C`. You cannot pass two different conformers to one render call.

**Format negotiation** — inspect actions before choosing format:

```swift
func negotiateFormat(actions: [Rendering.Action]) -> Format {
    let hasImages = actions.contains { if case .image = $0 { return true }; return false }
    let hasPageBreaks = actions.contains { if case .pageBreak = $0 { return true }; return false }

    if hasPageBreaks { return .pdf }
    if hasImages { return .html }
    return .plainText
}
```

---

#### 5. Observe Pattern

The `@Witness` macro's generated `Observe` struct provides before/after hooks. The hand-written equivalent:

```swift
extension Rendering.Context {
    public consuming func observed(
        before: @escaping (Rendering.Action) -> Void = { _ in },
        after: @escaping (Rendering.Action) -> Void = { _ in }
    ) -> Rendering.Context {
        let baseText = self.text
        // ...

        return .init(
            text: { content in
                before(.text(content))
                baseText(content)
                after(.text(content))
            },
            // ...
        )
    }
}

// Performance profiling per-operation:
var timings: [String: [Duration]] = [:]
var context = Rendering.Context.html(state: htmlState)
    .observed(
        before: { action in timings[action.name, default: []].append(.now) },
        after: { action in
            timings[action.name]![timings[action.name]!.count - 1] =
                .now - timings[action.name]!.last!
        }
    )
```

---

#### 6. Markdown Rendering

The `Rendering.Action` enum is the key enabler for the direct-context markdown rendering architecture (`markdown-direct-context-rendering.md`). But it unlocks more than the immediate stack overflow fix:

**Lazy rendering** — produce actions on-demand via a sequence:

```swift
struct MarkdownActionSequence: Sequence {
    let document: Markdown.Document

    func makeIterator() -> Iterator { ... }

    struct Iterator: IteratorProtocol {
        var nodeStack: [Markup.ChildIterator]

        mutating func next() -> Rendering.Action? {
            // Walk AST nodes lazily, yielding actions one at a time
            // Memory: O(AST depth), not O(document size)
        }
    }
}
```

**Action-level deduplication** — identical markdown fragments produce identical action subsequences:

```swift
// Blog post with repeated callout boxes:
// Each callout produces the same action prefix
// Cache and share the prefix across instances
```

**Markdown → markdown transformation** — action sequences can be filtered or transformed between production and interpretation:

```swift
// Strip code blocks for a "prose only" view:
let proseActions = allActions.filter { action in
    if case .push(.block(role: .pre, _)) = action { return false }
    // ... filter pre content
    return true
}
```

---

### Part 3: Category-Theoretic Framing

#### The Rendering Signature Σ

The rendering operations form a many-sorted algebraic signature:

```
Σ = { text      : String → (),
      lineBreak  : () → (),
      pushBlock  : Block? × Style → (),
      popBlock   : () → (),
      pushInline : Inline? × Style → (),
      popInline  : () → (),
      pushList   : List × Int? → (),
      popList    : () → (),
      ...  }
```

Each operation symbol σ ∈ Σ has an arity (its parameter types) and sort `()` (all operations return `Void`). The carrier sorts are `String`, `Block?`, `Style`, `List`, `Int?`, `Bool`, `[UInt8]`.

#### Σ-Algebras

A **Σ-algebra** is a set A (the carrier) together with an interpretation function for each operation symbol:

```
⟦σ⟧_A : arity(σ) → A → A
```

Since all operations mutate state and return `Void`, each interpretation is an endofunction on the carrier. A `Rendering.Context` witness is precisely a Σ-algebra: the carrier is the mutable state captured by `Ownership.Mutable<T>`, and each closure is the interpretation of one operation symbol.

- `HTML.Context` is a Σ-algebra with carrier `HTML.Context` state (bytes buffer, style map, tag stack)
- `PDF.Context` is a Σ-algebra with carrier `PDF.Context` state (page list, content stream, font metrics)
- A recording context is a Σ-algebra with carrier `[Rendering.Action]`

#### The Free Σ-Algebra

`[Rendering.Action]` is the **free Σ-algebra** over Σ — the initial object in the category **Alg(Σ)** of Σ-algebras and Σ-homomorphisms.

**Construction**: The free algebra is the term algebra — all finite sequences of operation applications. Since all operations return `Void` (no operation's output feeds into another's input), the term algebra degenerates from a tree to a list. Each `Rendering.Action` is a ground term (a fully-applied operation symbol with concrete arguments).

**Initiality**: For any Σ-algebra `A`, there exists a **unique** Σ-homomorphism `fold_A : [Rendering.Action] → A`. This is the `interpret(_:)` method:

```swift
// The unique catamorphism (fold) from the free algebra to any target algebra
public mutating func interpret(_ actions: [Rendering.Action]) {
    for action in actions {
        interpret(action)  // dispatch to the closure for this operation symbol
    }
}
```

Uniqueness is guaranteed because the homomorphism must commute with each operation symbol — `fold_A(.text(s))` = `⟦text⟧_A(s)`, and since these equations determine `fold_A` on every generator, the homomorphism is uniquely determined.

#### The Transformer Monoid

A **context transformer** is an endofunction `T : Alg(Σ) → Alg(Σ)`. It takes a Σ-algebra (a `Rendering.Context` witness) and returns a Σ-algebra (a new `Rendering.Context` witness). In Swift:

```swift
consuming func someTransformer(state: Ownership.Mutable<S>) -> Rendering.Context
```

Transformers compose via function composition:

```
(T₁ ∘ T₂)(ctx) = T₁(T₂(ctx))
```

In Swift, this is the method chaining:

```swift
.pdf(state: s).pdfHTML(state: h).observing(log: l)
// = observing(pdfHTML(pdf(s), h), l)
// = T_observe ∘ T_pdfHTML ∘ factory_pdf
```

The identity transformer `id(ctx) = ctx` is the unit. Composition is associative (function composition is always associative). Therefore **(End(Alg(Σ)), ∘, id)** is a **monoid**.

#### Algebraic Laws

**Push/pop balance preservation**: The push/pop operations form matched pairs. Define the **balance invariant**: for any well-formed action sequence, every push has a matching pop, and pops never exceed pushes at any prefix. A transformer **must preserve the balance invariant** — if the input sequence is balanced, the output sequence must be balanced. Formally: the balanced sequences form a sub-algebra, and well-behaved transformers restrict to endofunctions on this sub-algebra.

**Commutativity**: Transformers that affect disjoint operation subsets commute:

```
T_theme ∘ T_accessible = T_accessible ∘ T_theme
```

if `T_theme` only modifies `pushBlock`/`pushInline` styles and `T_accessible` only adds attributes via `setAttribute`. In general, transformers that touch the same closures do **not** commute — the monoid is non-abelian. For example, `T_observe ∘ T_theme ≠ T_theme ∘ T_observe` because observation records the themed styles in one order but the unthemed styles in the other.

**Idempotence**: A pure observation transformer `T_obs` is not idempotent on the output (applying it twice produces doubled log entries), but is idempotent on the rendering behavior — `T_obs(T_obs(ctx))` produces the same bytes/pages as `T_obs(ctx)`. The observation is a **side-effect** of the transformer, not a modification of the rendering semantics. Formally, if `π : Alg(Σ) → Output` is the projection to rendered output, then `π ∘ T_obs = π ∘ T_obs ∘ T_obs`.

#### Free Monad Comparison

`[Rendering.Action]` is **not** a free monad. The distinction:

- **Free monad** over a functor `F`: `Free F a = Pure a | Impure (F (Free F a))` — a tree where each node can bind the result of an operation to a continuation. This models sequenced computations where each step's result influences the next.
- **Free algebra** over a signature `Σ`: a list (or more generally, term algebra) of fully-applied operation symbols. No continuations, no binding.

The reason `[Rendering.Action]` is a list rather than a tree: every rendering operation returns `Void`. There are no result values to bind. The "program" is a flat sequence of effects, not a tree of dependent computations. In Haskell terms, this is the degenerate case where `Free F ()` collapses to `[F ()]` because the continuation never inspects the result.

If operations had return values (e.g., `registerStyle` returns `String?`), the free structure would need continuations:

```
data RenderingF next
    = Text String next
    | RegisterStyle String (String? -> next)  -- continuation depends on result
    | ...
```

The current design sidesteps this by making `registerStyle` return `String?` in the witness but omitting it from the `Action` enum (the action representation drops the return). This is a deliberate design choice — the action enum captures what operations were *requested*, not what they *returned*. A full free monad would capture both, at the cost of requiring `Codable` instances for return types and preventing simple `[Action]` representation.

#### Stateful Transformers and Monad Transformer Stacks

Each stateful transformer carries state of type `S` via `Ownership.Mutable<S>`. The composition of stateful transformers:

```
T₁ : (Ownership.Mutable<S₁>, Alg(Σ)) → Alg(Σ)
T₂ : (Ownership.Mutable<S₂>, Alg(Σ)) → Alg(Σ)
T₁ ∘ T₂ : (Ownership.Mutable<S₁>, Ownership.Mutable<S₂>, Alg(Σ)) → Alg(Σ)
```

This is the **product state** pattern. In the monad transformer vocabulary:

```
StateT S₁ (StateT S₂ Identity) ≅ StateT (S₁, S₂) Identity
```

The `Ownership.Mutable` boxes make this explicit — each transformer has its own heap-allocated state, and the composed state is the collection of all boxes. The analogy to monad transformer stacks is structural, not behavioral: there's no `bind`/`return` because the operations are `Void`-returning effects, not computations.

In practice, the product state is accessible after rendering:

```swift
let pdfState = Ownership.Mutable(PDF.Context(config))
let htmlState = Ownership.Mutable(PDF.HTML.State())
let stats = Ownership.Mutable(RenderingStats())

var context = Rendering.Context.pdf(state: pdfState)
    .pdfHTML(state: htmlState)
    .counting(stats: stats)

SomeView._render(view, context: &context)

// All state accessible:
let pages = pdfState.value.pages
let headings = htmlState.value.headings
let wordCount = stats.value.characterCount
```

---

### Part 4: What the Protocol Retains

#### 1. Compile-Time Specialization

The Swift compiler can fully specialize and inline protocol witness tables when the concrete type is known at compile time. With `_render<C: Rendering.Context>` where `C` is monomorphized to `HTML.Context`, the compiler can:
- Inline the protocol witness call → direct method call → inlined body
- Eliminate the witness table indirection entirely
- Apply cross-function optimizations across the render tree

With the witness struct, all dispatch goes through closure fields. The optimizer can sometimes devirtualize known closures (especially when the factory is visible), but the guarantee is weaker. The closure may capture complex state (`Ownership.Mutable`), and the optimizer cannot generally see through heap-allocated reference-counted captures.

**However**: The empirical evidence is unambiguous. The performance experiment measured V2 (witness closures) at 0.99–1.04x of V1 (protocol) in release builds across four orders of magnitude (10 to 10000 elements). The theoretical specialization advantage does not manifest as a measurable difference in this workload. Rendering is dominated by string allocation, byte buffer operations, and style computation — not dispatch overhead.

**Assessment**: Real in theory, immeasurable in practice. Not a meaningful differentiator.

#### 2. Static Exhaustiveness

Both the protocol and the witness struct require all operations to be provided. The protocol enforces this via conformance — the compiler emits an error if a required method is missing. The witness struct enforces this via the initializer — the compiler emits an error if a closure parameter is missing.

The protocol has a subtle advantage: protocol extensions can provide default implementations, and new requirements with defaults don't break existing conformers. The witness struct's init has no concept of "default" — every closure must be explicitly provided (though a convenience init or factory can supply defaults).

**Assessment**: Equivalent in practice. Both catch missing operations at compile time. The protocol's extension-based defaults are more ergonomic for optional operations; the witness struct can simulate this via convenience inits.

#### 3. Conditional Conformance

The protocol supports conditional conformances:

```swift
extension Array: Rendering.Context where Element: Rendering.Context { ... }
```

The witness struct, being a concrete type, cannot have conditional conformances to itself (it doesn't make sense). However, there is no current use case for conditional conformance on `Rendering.Context` — the three conformers are concrete types, not generic types. This capability is theoretical.

**Assessment**: Lost capability, but no current or foreseeable use case. Not a practical differentiator.

#### 4. Self-Referential Requirements

Protocol methods can reference `Self`:

```swift
protocol Context {
    static func _pushBlock(_ context: inout Self, role: ..., style: ...)
}
```

The static methods take `inout Self`, which is why the current protocol uses static methods for push/pop. With the witness struct, these become closures that capture the state externally — `Self` becomes the concrete state type inside `Ownership.Mutable<T>`.

The current protocol uses `Self` in the 16 static requirements. Converting to closures replaces `inout Self` with captured `Ownership.Mutable<T>` — a structural transformation, not a loss of capability. The closure can do everything the static method can.

**Assessment**: Not a loss. The closure-capture pattern is isomorphic to the static-method-with-Self pattern.

#### 5. Compiler Diagnostics

Protocol conformance errors are clear: "Type 'X' does not conform to protocol 'Rendering.Context'; missing method 'text(_:)'." Witness struct init errors are: "Missing argument for parameter 'text' in call."

Both are clear. The protocol error names the protocol and the missing method. The init error names the missing parameter. For developers familiar with both patterns, neither is notably worse.

**Assessment**: Roughly equivalent. Protocol errors are slightly more descriptive for complex conformance failures.

#### 6. Summary of Losses

| Capability | Protocol | Witness | Practical Impact |
|-----------|----------|---------|-----------------|
| Full specialization + inlining | Guaranteed | Optimizer-dependent | **None** (measured 0.99–1.04x) |
| Extension-based defaults | Native | Convenience init | **Minimal** (different syntax, same effect) |
| Conditional conformance | Supported | Not applicable | **None** (no use case) |
| Self-referential methods | Native via `inout Self` | Closure capture | **None** (isomorphic) |
| Conformance diagnostics | Protocol-specific | Init parameter errors | **Minimal** |

No capability lost by the witness approach has practical impact on the rendering architecture.

---

### Prior Art Survey

#### React Reconciler (Host Config Pattern)

React's architecture is already witness-based. The reconciler receives a "host config" — a plain JavaScript object with methods like `createInstance`, `appendChild`, `commitUpdate`, `removeChild`. Each rendering target (DOM, Native, Test) provides a different host config. This is exactly a Σ-algebra over the reconciliation signature.

React 16's Fiber architecture made this explicit: the reconciler is parametric over the host config, and the host config is a runtime value (not a compile-time type parameter). React Native and React DOM share the same reconciler code — the host config determines the output. The `react-test-renderer` provides a recording host config that captures operations as data — the same pattern as a recording `Rendering.Context` witness.

React's approach validates: (a) runtime dispatch via closures/methods has no meaningful performance impact vs compile-time specialization, and (b) the witness pattern enables multi-target rendering from a single reconciliation codebase.

#### Flutter Rendering Pipeline

Flutter uses a class hierarchy (`RenderObject` → `RenderBox` → concrete types) with virtual method dispatch for rendering. The `Layer` tree is a serializable intermediate representation — analogous to `[Rendering.Action]`. Layers are composed, culled, and rasterized by the engine.

Flutter's `CustomPaint` widget accepts a `CustomPainter` — a delegate (witness) with `paint(Canvas, Size)`. The `Canvas` is a protocol-like API backed by Skia. This is a two-level witness: the painter witnesses the paint behavior, and the canvas witnesses the drawing primitives.

Flutter's approach validates: (a) the intermediate representation (Layer tree / display list) enables caching, compositing, and platform-specific interpretation, and (b) rendering pipelines naturally stratify into witness-based patterns even in class-oriented languages.

#### Browser Display Lists

The CSS → layout → paint → composite pipeline produces **display lists** — ordered sequences of paint operations (`DrawRect`, `DrawText`, `PushClip`, `PopClip`, `DrawImage`). This is the free Σ-algebra over the painting signature. Display lists are:

- **Cached**: Unchanged subtrees retain their display lists across frames
- **Tiled**: Display lists are split into tiles for parallel GPU composition
- **Layered**: Compositing layers have independent display lists, enabling hardware acceleration
- **Diffed**: Chrome's paint invalidation compares display lists to determine what to repaint

The browser's display list architecture is the most mature validation of "rendering as data." It has been optimized for decades and remains the foundation of all modern rendering engines. The key insight — separating the production of rendering operations (layout/paint) from their interpretation (GPU rasterization) — is exactly the `[Rendering.Action]` → `interpret` separation.

#### TeX DVI Instructions

TeX's `\shipout` produces DVI (DeVice Independent) instructions — a serialized sequence of typesetting operations (`set_char`, `put_rule`, `push`, `pop`, `set_font`). DVI is the free algebra over the typesetting signature. DVI drivers (`dvips`, `dvipdfm`, `xdvi`) are target algebras that interpret the instruction sequence into PostScript, PDF, or screen display.

Properties of the DVI architecture:
- **Serializable**: DVI is a binary format; instructions are written to `.dvi` files
- **Portable**: The same DVI file renders on any driver
- **Toolable**: `dvitype` inspects DVI files; `dvicopy` transforms them; `dviselect` extracts pages
- **Composable**: DVI files can be concatenated (with appropriate preamble adjustments)

TeX has operated with this architecture since 1982 — 44 years of validation that separating rendering into a free algebra + interpretation catamorphism is a sound and durable design.

#### SwiftUI Attribute Graph

SwiftUI's `View` protocol is the user-facing API, but the rendering pipeline builds an **attribute graph** — an internal data structure representing the view hierarchy, dependencies, and update propagation. The attribute graph is the "real" rendering representation; `View.body` is compiled into graph operations.

SwiftUI's `_ViewDebug.data` exposes the attribute graph as serializable data for debugging tools like Instruments. The graph is diffed between updates to determine which views need re-rendering. This is analogous to diffing `[Rendering.Action]` sequences.

SwiftUI validates: (a) the user-facing API (protocol-based `View`) can coexist with an internal data representation, and (b) reifying rendering operations as data enables sophisticated update propagation and debugging.

#### Elm Virtual DOM

Elm's `view` function returns `Html msg` — an algebraic data type representing HTML structure. The runtime diffs the old and new `Html` values and applies patches to the real DOM. The `Html` type is the free algebra over the HTML signature; the DOM update is the catamorphism.

Elm validates: (a) representing UI as data (free algebra) enables efficient diffing, and (b) the catamorphism (virtual DOM → real DOM reconciliation) can be optimized separately from the view logic.

---

## Outcome

**Status**: RECOMMENDATION

**Assessment**: The witness architecture is categorically superior to the protocol for `Rendering.Context`. Every dimension analyzed favors the witness, with no practically meaningful capabilities lost.

### Capabilities Exclusive to the Witness Architecture

| Capability | Enabled By | Protocol Alternative |
|-----------|-----------|---------------------|
| Behavioral composition without new types | `consuming` transformers | Wrapper conformers (O(n×m) types) |
| Granular test stubbing | Closure field replacement | Full mock conformer (all 26 methods) |
| Naturally derived Action enum | 1:1 closure-to-case mapping | Hand-derived, manually synced |
| Generic parameter elimination | Concrete type | 40+ signatures carry `C` |
| Middleware as transformer methods | Closure wrapping | Wrapper conformers (~100 lines each) |
| Multi-format tee (one render → two outputs) | Compose two witness closures | Impossible (monomorphic `C`) |
| Per-operation override | Mutate one closure | Full wrapper type |
| Dependency injection | Concrete type in `Witness.Key` | Generic indirection |
| Render serialization/replay | `Rendering.Action` Sendable/Codable | External recording layer |
| Action diffing, caching, transformation | Operations are data | Operations are ephemeral |
| Tee transform (simultaneous multi-format) | Closure duplication | Structurally impossible |

### What the Protocol Retains

Compile-time specialization (unmeasurable), conditional conformance (unused), and marginally better conformance diagnostics. None of these have practical impact.

### Architectural Classification

The witness `Rendering.Context` is a Σ-algebra. `Rendering.Action` is the free Σ-algebra (initial object in **Alg(Σ)**). `interpret(_:)` is the unique catamorphism. Transformers form a monoid under composition. This algebraic structure is validated by 44 years of prior art (TeX DVI), mature browser rendering engines (display lists), and modern frameworks (React host configs, Flutter layers, Elm virtual DOM).

The protocol-based approach is a degenerate case — it provides a single fixed interpretation with no reification, no composition, and no transformation. The witness approach exposes the full algebraic structure that the protocol hides.

### Recommendation

The witness architecture should be adopted. The architectural value is not marginal — it is a qualitative shift from "rendering is an opaque effect" to "rendering is composable, inspectable data." Every capability analysis (composability, testability, middleware, format composition, serialization, dependency injection) favors the witness, and no meaningful capability is lost.

This recommendation is independent of migration cost. The architectural delta is unambiguous.

## References

- `swift-institute/Research/rendering-context-witness-migration-implications.md` — migration scope and design (RECOMMENDATION)
- `swift-institute/Research/rendering-context-protocol-vs-witness.md` — performance experiment: V2 ≈ V1 (DECISION: hybrid)
- `swift-institute/Research/markdown-direct-context-rendering.md` — motivating architecture (RECOMMENDATION)
- `swift-institute/Experiments/rendering-context-algebra-composition/` — composition experiment (15 tests)
- `swift-rendering-primitives/.../Rendering.Context.swift` — current protocol (262 lines)
- `swift-html-rendering/.../HTML.Context.swift` — HTML conformer (633 lines)
- `swift-pdf-html-rendering/.../PDF.HTML.Context+Rendering.swift` — PDF-HTML conformer (1095 lines)
- `swift-ownership-primitives/.../Ownership.Mutable.swift` — mutable state capture
- `swift-witnesses/.../WitnessMacro.swift` — @Witness macro (Action enum pattern)
- React Reconciler: host config pattern (facebook/react, `react-reconciler/src/forks/ReactFiberHostConfig.custom.js`)
- Flutter: `Layer` tree and `CustomPainter` delegate (`flutter/engine/lib/ui/painting.dart`)
- Browser display lists: Chromium `cc::DisplayItemList`, WebKit `DisplayList::Recorder`
- TeX DVI: Knuth, D.E. (1986). *TeX: The Program*, §585–642 (DVI output routines)
- SwiftUI attribute graph: WWDC 2023 "Demystify SwiftUI performance"
- Elm virtual DOM: Czaplicki, E. (2012). *Elm: Concurrent FRP for Functional GUIs*
