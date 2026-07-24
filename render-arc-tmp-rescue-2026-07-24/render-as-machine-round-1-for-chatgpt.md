You are entering a collaborative design discussion with Claude (Anthropic).

## Protocol
- Be COOPERATIVE where possible — seek common ground first
- Be CRITICAL where necessary — challenge weak reasoning directly
- Address ALL issues before declaring convergence
- Use the structured round format provided below

## Your Strengths
You bring broad knowledge across domains and different training perspectives.
Claude brings deep code analysis and Swift ecosystem expertise.

## Goal
Converge on a decision for: **Should `swift-render-primitives`'s bespoke execution machinery dissolve into `swift-machine-primitives` (with `swift-effect-primitives` supplying naming), each render domain supplying its own Leaf set — the way the Parsing and Binary packages already do?**

Three sub-questions must be answered with evidence:

- **(a) MISSION.** `Machine`'s documentation is parsing-flavoured, though `Machine.Node<Leaf, Failure, Mode>` is generic. Does Machine's mission genuinely generalize to "defunctionalized program over an arbitrary leaf set" — docs merely lagging the type — or does Render need a sibling rather than a merge?
- **(b) SHAPE FIT.** `Machine.Node` is an arena-backed graph built for programs that are re-executed. A document render is a one-shot tree walk over a flat LIFO with raw-pointer thunks. Do the cost profiles reconcile, or does hosting Render on Machine impose overhead on the one-shot case?
- **(c) EFFECT'S RUNTIME.** `Effect.perform` is deferred to a runtime layer and is async/continuation-shaped. Rendering is synchronous. Can Effect supply the protocol vocabulary (operation symbol / handler / outcome) without dragging in continuation machinery — or is borrowing only the naming a misuse of the package?

And a naming question: if neither Machine nor Effect fits and a *signature* concept really is needed, what is the non-invented name? Universal algebra supplies signature Σ, Σ-algebra (the handler), term/free algebra (the action stream), and the interpreter as the unique homomorphism. Is that the right Layer-1 framing, or over-abstraction for what four packages need?

## Ecosystem rules that bind this decision

You do not need to memorise these, but arguments that violate them will be rejected:

- **[ARCH-LAYER-008]** Correctness and architectural merit are the SOLE drivers of split/reshape/extraction decisions. Consumer count, adoption, and "only one user" are NEVER decision drivers, in either direction.
- **[ARCH-LAYER-010]** Package scope follows strict-mission rules; mission-boundary fixes are made early, not deferred on cost grounds.
- **[ARCH-LAYER-014]** A package's layer follows its ESSENCE (the question it answers). When dependencies violate the layer, the *dependencies* are refactored — the package is never re-homed to match them.
- **[ARCH-LAYER-009]** Removal/dissolution is permitted but gated on two guards: the code must be **committed first** (git-recoverable) and **verified dead** by a clean build after removal.
- **[MOD-DOMAIN]** A target must represent a coherent semantic domain. Targets are never created for "shared code" or "helpers". The question at every decomposition is: *is this a concept, or just code?*
- **[API-NAME-001]** `Nest.Name` throughout; compound type names forbidden. **[API-NAME-001a]** a namespace holding exactly one type is a *variant label*, not a namespace.
- **No invented concepts at Layer 1.** Prefer an existing ecosystem name, then established mathematics, then — only if both fail — a new concept with an explicit argument for why nothing existing covers it.

## Response Format
Respond using this EXACT structure:

## Round {N} - ChatGPT

### Position
{Your current stance}

### Agreements
{Where you align with Claude}

### Concerns
{Issues with Claude's proposals - be specific}

### Proposals
{Your concrete suggestions}

### Questions
{Clarifications needed from Claude}

### Status: {EXPLORING | NARROWING | NEAR_CONSENSUS | CONVERGED}

---

## Exports

Full-package exports were produced. Token counts (chars/4):

| Package | Full export | In bundle |
|---|---|---|
| `swift-render-primitives` | ~12,060 | subset |
| `swift-machine-primitives` | ~20,319 | subset |
| `swift-effect-primitives` | ~9,993 | subset |
| `swift-svg-render` | ~21,507 | subset |
| **Curated bundle below** | | **~19,100** |

The required three total ~42,400 tokens — over a 32K window — so the bundle below is a curated subset. Every dropped file is named inline at the end of its section, with what it contains. Nothing load-bearing to (a), (b) or (c) was dropped. `swift-graph-primitives` (60 files) was not exported; `Graph.Node<T>`'s role is quoted instead.

`swift-html-render` was added to the bundle beyond the requested four, because it turned out to be the decisive evidence on one of the prior session's claims.

---

## Context

# Context Bundle — Render / Machine / Effect

Curated subset of four packages. Full-export token counts and the complete dropped-file list are in Round 1 § "Exports".

**Reference (not exported — swift-graph-primitives is 60 files):**
```swift
// Graph.Node<T> is a typed arena index (a Tagged ordinal), NOT a node value.
// Graph.Sequential<Node, Payload> is the sequentially-allocated arena, built via
// Graph.Sequential<...>.Builder { mutating func allocate(_:) -> Graph.Node<...> }.
```

---

## A. swift-render-primitives (L1) — the render machine

One source target `Render Primitive`, zero package dependencies, 27 files / ~1069 LoC.

### File: Render Primitive/Render.swift

```swift
/// Namespace for rendering types and protocols.
///
/// The `Render` enum provides a namespace for all rendering-related types:
/// - `Render.View` -- Protocol for renderable content
/// - `Render.Context` -- Witness struct for rendering destinations
/// - `Render.Builder` -- Result builder for declarative composition
/// - `Render._Tuple`, `Render.Conditional`, `Render.Pair` -- Composition primitives
/// - `Render.Empty`, `Render.Group` -- Container types
/// - `Render.Semantic`, `Render.Style` -- Structured content metadata
public enum Render {}
```

### File: Render Primitive/Render.View.swift

```swift
extension Render {
    /// A type that represents part of a rendered document.
    ///
    /// Types conforming to `Render.View` describe their content either through
    /// a `body` property (composite views) or by implementing `_render` directly
    /// (leaf views with `Body == Never`).
    public protocol View: ~Copyable {
        associatedtype Body: View & ~Copyable
        @Builder var body: Body { get }

        static func _render(
            _ view: borrowing Self,
            context: inout Context
        )
    }
}

extension Render.View where Self: Copyable {
    /// Default rendering for composite views: schedules the view's `body` on the
    /// context's iterative work stack.
    @inlinable
    public static func _render(
        _ view: borrowing Self,
        context: inout Render.Context
    ) {
        let viewCopy = copy view
        let pointer = UnsafeMutablePointer<Self>.allocate(capacity: 1)
        unsafe pointer.initialize(to: viewCopy)
        unsafe context._stack.append(
            .render(
                pointer: UnsafeMutableRawPointer(pointer),
                thunk: Render.Thunk(view: Self.self)
            )
        )
    }
}

extension Never: Render.View {
    /// `Never` is its own body, terminating the recursive `Body` chain of leaf views.
    public typealias Body = Never

    /// Unreachable: a `Never` value cannot exist, so its body is never evaluated.
    public var body: Never { fatalError("Never has no body") }

    /// Renders nothing, since no `Never` value can be constructed.
    public static func _render(
        _ view: borrowing Self,
        context: inout Render.Context
    ) {}
}
```

### File: Render Primitive/Render.Context.swift

```swift
extension Render {
    /// A rendering destination that receives structured content events.
    ///
    /// Contexts are the bridge between format-independent views and format-specific
    /// output. An HTML context emits tags and bytes; a PDF context emits content
    /// stream operators. The same view tree renders to any context.
    ///
    /// ## Nested Accessor API
    ///
    ///     ctx.push.block(role: .paragraph, style: .empty)
    ///     ctx.text("Hello")
    ///     ctx.pop.block()
    ///     ctx.`break`.line()
    public struct Context: ~Copyable {
        // MARK: - Work Stack (Iterative Render)

        @usableFromInline var _stack: [Render.Work] = []

        // MARK: - Leaf Operations

        /// Emits a run of literal text.
        public var text: (String) -> Void

        /// Emits an image referenced by source with alternative text.
        public var image: (_ source: String, _ alt: String) -> Void

        // MARK: - Structured Operations

        /// Scope-opening operations that begin structured containers.
        public var push: Render.Push

        /// Scope-closing operations that end structured containers.
        public var pop: Render.Pop

        /// Break operations: line, thematic, and page breaks.
        public var `break`: Render.Break

        /// Speculative rendering: snapshot, tentative render, and rollback.
        public var speculative: Render.Speculative

        // MARK: - Attribute Operations

        @usableFromInline var _setAttribute: (_ name: String, _ value: String?) -> Void
        @usableFromInline var _addClass: (String) -> Void
        @usableFromInline var _writeRaw: ([UInt8]) -> Void
        @usableFromInline var _registerStyle: (_ declaration: String, _ atRule: String?, _ selector: String?, _ pseudo: String?) -> String?
        @usableFromInline var _applyInlineStyle: (Any) -> Bool

        // MARK: - Bulk Operations

        @usableFromInline var _spliceActions: ([Render.Action]) -> Void

        /// Creates a context by supplying a closure for each rendering operation.
        ///
        /// Each backend (HTML, PDF, recording) provides the closures that turn
        /// format-independent operations into format-specific output.
        public init(
            text: @escaping (String) -> Void,
            `break`: Render.Break,
            image: @escaping (_ source: String, _ alt: String) -> Void,
            push: Render.Push,
            pop: Render.Pop,
            setAttribute: @escaping (_ name: String, _ value: String?) -> Void = { _, _ in },
            addClass: @escaping (String) -> Void = { _ in },
            writeRaw: @escaping ([UInt8]) -> Void = { _ in },
            registerStyle: @escaping (_ declaration: String, _ atRule: String?, _ selector: String?, _ pseudo: String?) -> String? = { _, _, _, _ in nil },
            applyInlineStyle: @escaping (Any) -> Bool = { _ in false },
            speculative: Render.Speculative = .init(),
            spliceActions: @escaping ([Render.Action]) -> Void = { _ in }
        ) {
            self.text = text
            self.`break` = `break`
            self.image = image
            self.push = push
            self.pop = pop
            self._setAttribute = setAttribute
            self._addClass = addClass
            self._writeRaw = writeRaw
            self._registerStyle = registerStyle
            self._applyInlineStyle = applyInlineStyle
            self.speculative = speculative
            self._spliceActions = spliceActions
        }
    }
}

// MARK: - Labeled Convenience API

extension Render.Context {
    /// Sets an attribute on the current element to the given value, or removes it when `nil`.
    @inlinable
    public func set(attribute name: String, _ value: String?) {
        _setAttribute(name, value)
    }

    /// Adds a CSS class name to the current element.
    @inlinable
    public func add(`class` name: String) {
        _addClass(name)
    }

    /// Writes raw, already-encoded bytes directly to the output.
    @inlinable
    public func write(raw bytes: [UInt8]) {
        _writeRaw(bytes)
    }

    /// Registers a style declaration, returning a generated class name when the backend deduplicates it.
    @inlinable
    public func register(
        style declaration: String,
        atRule: String?,
        selector: String?,
        pseudo: String?
    ) -> String? {
        _registerStyle(declaration, atRule, selector, pseudo)
    }

    /// Applies a typed inline-style property, returning whether the backend handled it.
    @inlinable
    public func apply(inlineStyle property: Any) -> Bool {
        _applyInlineStyle(property)
    }

    /// Replays a batch of recorded actions into the output in order.
    @inlinable
    public func splice(_ actions: [Render.Action]) {
        _spliceActions(actions)
    }
}

// MARK: - Interpret

extension Render.Context {
    /// Applies a single recorded action to this context.
    @inlinable
    public mutating func interpret(_ action: Render.Action) {
        switch action {
        case .text(let content): text(content)

        case .break(let kind):
            switch kind {
            case .line: self.`break`.line()
            case .thematic: self.`break`.thematic()
            case .page: self.`break`.page()
            }

        case .image(let source, let alt): image(source, alt)
        case .attribute(let name, let value): _setAttribute(name, value)
        case .class(let name): _addClass(name)
        case .raw(let bytes): _writeRaw(bytes)

        case .style(let declaration, let atRule, let selector, let pseudo):
            _ = _registerStyle(declaration, atRule, selector, pseudo)

        case .push(let push):
            switch push {
            case .block(let role, let style): self.push.block(role: role, style: style)
            case .inline(let role, let style): self.push.inline(role: role, style: style)
            case .list(let kind, let start): self.push.list(kind: kind, start: start)
            case .item: self.push.item()
            case .link(let destination): self.push.link(destination)
            case .attributes: self.push.attributes()

            case .element(let tagName, let isBlock, let isVoid, let isPreElement):
                self.push.element(tagName: tagName, block: isBlock, void: isVoid, preformatted: isPreElement)

            case .style: self.push.style()
            }

        case .pop(let pop):
            switch pop {
            case .block: self.pop.block()
            case .inline: self.pop.inline()
            case .list: self.pop.list()
            case .item: self.pop.item()
            case .link: self.pop.link()
            case .attributes: self.pop.attributes()
            case .element(let isBlock): self.pop.element(block: isBlock)
            case .style: self.pop.style()
            }
        }
    }

    /// Applies a batch of recorded actions to this context, in order.
    @inlinable
    public mutating func interpret(_ actions: [Render.Action]) {
        for action in actions { interpret(action) }
    }
}

// MARK: - Iterative Render

extension Render.Context {
    /// Renders a view tree iteratively, avoiding recursive stack overflow.
    @inlinable
    public mutating func render<V: Render.View & ~Copyable>(_ view: borrowing V) {
        _stack.reserveCapacity(64)
        defer { _cleanupStack() }
        V._render(view, context: &self)
        _drain(above: 0)
    }

    /// Pops and dispatches work above `marker`, in LIFO order, until the
    /// stack returns to that depth.
    ///
    /// This is the same step the top-level `render(_:)` drain loop performs;
    /// it is also used by composition types (``Render/Pair``) that need one
    /// child's entire deferred subtree to fully complete — synchronous
    /// dispatch *and* whatever it deferred — before the next child begins,
    /// without needing ownership of that child beyond its own `_render` call.
    @usableFromInline
    mutating func _drain(above marker: Int) {
        while _stack.count > marker {
            let work = _stack.removeLast()
            switch work {
            case .render(let pointer, let thunk):
                unsafe thunk.dispatch(pointer, &self)
                unsafe thunk.destroy(pointer)

            case .action(let action):
                interpret(action)

            case .frame(let frame):
                switch frame {
                case .closeScope(let action):
                    interpret(action)
                }
            }
        }
    }

    /// Destroys any orphaned render allocations remaining on the stack.
    @usableFromInline
    mutating func _cleanupStack() {
        for work in _stack {
            if case .render(let pointer, let thunk) = work {
                unsafe thunk.destroy(pointer)
            }
        }
        _stack.removeAll(keepingCapacity: true)
    }

    /// Opens a push/pop bracket scope with deferred close.
    @inlinable
    public mutating func open(
        push: Render.Action.Push,
        pop: Render.Action.Pop
    ) {
        interpret(.push(push))
        _stack.append(.frame(.closeScope(.pop(pop))))
    }

    @usableFromInline
    var _stackDepth: Int { _stack.count }

    @usableFromInline
    mutating func _reverseAbove(_ marker: Int) {
        _stack[marker...].reverse()
    }
}
```

### File: Render Primitive/Render.Work.swift

```swift
extension Render {
    // SAFETY: Enum carries a raw pointer payload via the `.render` case; the
    // SAFETY: pointer is established by the construction site (Body's storage)
    // SAFETY: and is dispatched through a typed Thunk whose lifetime is bounded
    // SAFETY: by the same construction. The enum itself stores no mutable
    // SAFETY: state — case payloads are immutable after construction.
    // SAFETY: Encapsulation invariant per [MEM-SAFE-021]; raw-pointer dispatch
    // SAFETY: details belong to Render.Thunk.
    @usableFromInline
    enum Work {
        case render(pointer: UnsafeMutableRawPointer, thunk: Render.Thunk)
        case action(Render.Action)
        case frame(Render.Machine.Frame)
    }
}
```

### File: Render Primitive/Render.Thunk.swift

```swift
extension Render {
    // SAFETY: Encapsulates raw-pointer dispatch / destroy closures behind a
    // SAFETY: type-erased Thunk. Construction is the only entry point; the
    // SAFETY: stored closures are immutable post-init and the raw pointer
    // SAFETY: provenance is established by the caller (Body's storage). All
    // SAFETY: unsafe pointer operations are marked `unsafe` at the expression
    // SAFETY: level per [MEM-SAFE-002]. Encapsulation invariant per [MEM-SAFE-021].
    @usableFromInline
    struct Thunk {
        @usableFromInline
        let dispatch: (UnsafeMutableRawPointer, inout Render.Context) -> Void

        @usableFromInline
        let destroy: (UnsafeMutableRawPointer) -> Void

        @inlinable
        init<Body: Render.View & ~Copyable>(_: Body.Type) {
            unsafe self.dispatch = { pointer, context in
                Body._render(
                    unsafe pointer.assumingMemoryBound(to: Body.self).pointee,
                    context: &context
                )
            }
            unsafe self.destroy = { pointer in
                unsafe pointer.assumingMemoryBound(to: Body.self).deinitialize(count: 1)
                unsafe pointer.deallocate()
            }
        }

        /// Creates a composite thunk that stores a copyable view and dispatches through its body.
        ///
        /// The body is never stored: it is computed transiently via `view.body` and
        /// passed as a borrow into `_render`, which enables `~Copyable` body types.
        @inlinable
        init<V: Render.View & Copyable>(view _: V.Type) where V.Body: Render.View {
            unsafe self.dispatch = { pointer, context in
                let view = unsafe pointer.assumingMemoryBound(to: V.self).pointee
                V.Body._render(view.body, context: &context)
            }
            unsafe self.destroy = { pointer in
                unsafe pointer.assumingMemoryBound(to: V.self).deinitialize(count: 1)
                unsafe pointer.deallocate()
            }
        }
    }
}
```

### File: Render Primitive/Render.Machine.swift

```swift
extension Render {
    /// Namespace for machine-based rendering execution types.
    ///
    /// The rendering machine extends the iterative drain loop with typed
    /// continuation frames and speculative rendering support. Views push
    /// work onto the stack; the machine loop pops and dispatches. Frame
    /// continuations execute after child content renders, providing
    /// structured push/pop brackets and checkpoint/rollback.
    public enum Machine {}
}
```

### File: Render Primitive/Render.Machine.Frame.swift

```swift
extension Render.Machine {
    /// A continuation frame on the rendering machine's work stack.
    ///
    /// Frames execute after their associated child content has rendered.
    /// They provide structured control flow for bracket operations (push/pop
    /// scopes) where the close action must be deferred until all nested
    /// content has been processed.
    @usableFromInline
    enum Frame {
        /// Emits a deferred action after child content renders.
        ///
        /// Used by ``Render/Context/open(push:pop:)`` to defer the
        /// pop action until all bracketed content has been processed.
        case closeScope(Render.Action)
    }
}
```

### File: Render Primitive/Render.Action.swift

```swift
extension Render {
    /// A reified rendering operation that a `Render.Context` can interpret.
    ///
    /// Actions are the value form of the context's imperative API, letting a
    /// view record a sequence of operations and replay or splice them later.
    public enum Action: Sendable {
        case push(Push)
        case pop(Pop)
        case `break`(Break)
        case text(String)
        case image(source: String, alt: String)
        case attribute(set: String, value: String?)
        case `class`(add: String)
        case raw([UInt8])
        case style(register: String, atRule: String?, selector: String?, pseudo: String?)
    }
}
```

### File: Render Primitive/Render.Action.Push.swift

```swift
extension Render.Action {
    /// A reified scope-opening operation that begins a structured container.
    public enum Push: Sendable {
        case block(role: Render.Semantic.Block?, style: Render.Style)
        case inline(role: Render.Semantic.Inline?, style: Render.Style)
        case list(kind: Render.Semantic.List, start: Int?)
        case item
        case link(destination: String)
        case attributes
        case element(tagName: String, isBlock: Bool, isVoid: Bool, isPreElement: Bool)
        case style
    }
}
```

### File: Render Primitive/Render.Action.Pop.swift

```swift
extension Render.Action {
    /// A reified scope-closing operation that ends a structured container.
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

### File: Render Primitive/Render.Push.swift

```swift
extension Render {
    /// Push operations for structured rendering contexts.
    ///
    ///     ctx.push.block(role: .paragraph, style: .empty)
    ///     ctx.push.inline(role: .strong, style: .empty)
    ///     ctx.push.link("https://example.com")
    public struct Push {
        @usableFromInline var _block: (_ role: Render.Semantic.Block?, _ style: Render.Style) -> Void
        @usableFromInline var _inline: (_ role: Render.Semantic.Inline?, _ style: Render.Style) -> Void
        @usableFromInline var _list: (_ kind: Render.Semantic.List, _ start: Int?) -> Void
        @usableFromInline var _item: () -> Void
        @usableFromInline var _link: (_ destination: String) -> Void
        @usableFromInline var _attributes: () -> Void
        @usableFromInline var _element: (_ tagName: String, _ isBlock: Bool, _ isVoid: Bool, _ isPreElement: Bool) -> Void
        @usableFromInline var _style: () -> Void

        /// Creates a push handler from one closure per structured open operation.
        @inlinable
        public init(
            block: @escaping (_ role: Render.Semantic.Block?, _ style: Render.Style) -> Void,
            inline: @escaping (_ role: Render.Semantic.Inline?, _ style: Render.Style) -> Void,
            list: @escaping (_ kind: Render.Semantic.List, _ start: Int?) -> Void,
            item: @escaping () -> Void,
            link: @escaping (_ destination: String) -> Void,
            attributes: @escaping () -> Void = {},
            element: @escaping (_ tagName: String, _ isBlock: Bool, _ isVoid: Bool, _ isPreElement: Bool) -> Void = { _, _, _, _ in },
            style: @escaping () -> Void = {}
        ) {
            self._block = block
            self._inline = inline
            self._list = list
            self._item = item
            self._link = link
            self._attributes = attributes
            self._element = element
            self._style = style
        }

        /// Opens a block-level container with an optional semantic role and style.
        @inlinable public func block(role: Render.Semantic.Block?, style: Render.Style) { _block(role, style) }

        /// Opens an inline-level container with an optional semantic role and style.
        @inlinable public func inline(role: Render.Semantic.Inline?, style: Render.Style) { _inline(role, style) }

        /// Opens a list of the given kind, optionally starting at a specific number.
        @inlinable public func list(kind: Render.Semantic.List, start: Int?) { _list(kind, start) }

        /// Opens a list item.
        @inlinable public func item() { _item() }

        /// Opens a hyperlink to the given destination.
        @inlinable public func link(_ destination: String) { _link(destination) }

        /// Opens an attribute scope for the current element.
        @inlinable public func attributes() { _attributes() }

        /// Opens a raw element by tag name, with block, void, and preformatted flags.
        @inlinable public func element(tagName: String, block isBlock: Bool, void isVoid: Bool, preformatted: Bool) { _element(tagName, isBlock, isVoid, preformatted) }

        /// Opens a style scope.
        @inlinable public func style() { _style() }
    }
}
```

### File: Render Primitive/Render.Builder.swift

```swift
extension Render {
    /// Result builder for composing content.
    ///
    /// The builder is unconstrained — it works with any type. Domain packages
    /// add protocol conformances to the output types (`_Tuple`, `Conditional`,
    /// `Optional`, `Array`) via conditional extensions. This allows the same
    /// builder to serve document rendering (`Render.View`), graphics
    /// rendering (`SVG.View`), and any future rendering domain.
    ///
    /// Uses variadic `buildBlock` to produce flat `_Tuple` types with O(1)
    /// nesting depth. `buildPartialBlock(accumulated:next:)` is intentionally
    /// absent — binary nesting overflows at 70+ elements.
    @resultBuilder
    public enum Builder {
        /// Returns a single component unchanged.
        public static func buildBlock<V>(_ v: V) -> V { v }

        /// Combines a variadic block of components into a flat `Render._Tuple`.
        public static func buildBlock<each Content>(
            _ content: repeat each Content
        ) -> Render._Tuple<repeat each Content> {
            Render._Tuple(repeat each content)
        }

        /// Wraps an optional component, preserving its presence or absence.
        public static func buildOptional<V>(_ v: V?) -> V? { v }

        /// Builds the first branch of an `if`/`else` as a `Render.Conditional`.
        public static func buildEither<First, Second>(
            first: First
        ) -> Render.Conditional<First, Second> {
            .first(first)
        }

        /// Builds the second branch of an `if`/`else` as a `Render.Conditional`.
        public static func buildEither<First, Second>(
            second: Second
        ) -> Render.Conditional<First, Second> {
            .second(second)
        }

        /// Collects the components produced by a `for` loop into an array.
        public static func buildArray<V>(_ components: [V]) -> [V] {
            components
        }
    }
}
```

### File: Render Primitive/Render._Tuple.swift

```swift
extension Render {
    /// Flat variadic composition produced by `Render.Builder.buildBlock`.
    ///
    /// Each element is rendered in order. The flat structure avoids the
    /// O(N) nesting depth that causes stack overflows with binary composition.
    ///
    /// The type itself is unconstrained — domain packages add protocol
    /// conformances via conditional extensions. `Render.View` conformance
    /// is provided when all elements are `Render.View`.
    public struct _Tuple<each Content> {
        /// The packed tuple of composed elements.
        public let content: (repeat each Content)

        /// Creates a tuple from a variadic list of elements.
        public init(_ content: repeat each Content) {
            self.content = (repeat each content)
        }
    }
}

// MARK: - Render.View

extension Render._Tuple: Render.View where repeat each Content: Render.View {
    /// The body type of this leaf conformance, which never produces nested content.
    public typealias Body = Never

    /// Unreachable: each element is dispatched directly through `_render`.
    public var body: Never { fatalError("Render._Tuple has no body; rendering is performed by _render") }

    /// Renders each packed element in order.
    public static func _render(
        _ view: borrowing Self,
        context: inout Render.Context
    ) {
        let marker = context._stackDepth
        func push<V: Render.View>(_ v: V, _ ctx: inout Render.Context) {
            let pointer = UnsafeMutablePointer<V>.allocate(capacity: 1)
            unsafe pointer.initialize(to: v)
            unsafe ctx._stack.append(
                .render(
                    pointer: UnsafeMutableRawPointer(pointer),
                    thunk: Render.Thunk(V.self)
                )
            )
        }
        repeat push(each view.content, &context)
        context._reverseAbove(marker)
    }
}

extension Render._Tuple: Sendable where repeat each Content: Sendable {}
```

### File: Render Primitive/Render.Pair.swift

```swift
extension Render {
    /// A binary composition of two values.
    ///
    /// `Pair` is the manual composition type for `_render` implementations
    /// that need `~Copyable` support. The builder's `buildBlock` uses
    /// variadic `_Tuple` instead. The type itself is unconstrained —
    /// `Render.View` conformance is conditional.
    public struct Pair<First: ~Copyable, Second: ~Copyable>: ~Copyable {
        /// The first composed value.
        public let first: First

        /// The second composed value.
        public let second: Second

        /// Creates a pair by consuming both composed values.
        public init(first: consuming First, second: consuming Second) {
            self.first = first
            self.second = second
        }
    }
}

// MARK: - Render.View

extension Render.Pair: Render.View
where First: Render.View & ~Copyable, Second: Render.View & ~Copyable {
    /// The body type of this leaf conformance, which never produces nested content.
    public typealias Body = Never

    /// Unreachable: both elements are dispatched directly through `_render`.
    public var body: Never { fatalError("Render.Pair has no body; rendering is performed by _render") }

    /// Renders the first element followed by the second, in source order.
    ///
    /// `First`/`Second` may be `~Copyable`, and `view` is only `borrowing`,
    /// so neither child can be moved off the heap and deferred as its own
    /// work-stack thunk the way `Render._Tuple`'s (`Copyable`-constrained)
    /// elements are. Instead, each child's `_render` call is fully drained —
    /// its own synchronous actions *and* whatever it deferred (e.g. a
    /// bracket's close action) — before the next child starts. This keeps
    /// each child's contribution atomic on the stack, so their relative
    /// order never needs a combined reversal: reversing a range that already
    /// mixes multiple children's own (already internally-correct) deferred
    /// items double-scrambles nested structure whenever a child defers more
    /// than one item (e.g. a bracketed child, or a nested `Pair`) — see
    /// `Composition Tests.swift`'s F-001 regression tests.
    public static func _render(
        _ view: borrowing Self,
        context: inout Render.Context
    ) {
        let marker = context._stackDepth
        First._render(view.first, context: &context)
        context._drain(above: marker)
        Second._render(view.second, context: &context)
        context._drain(above: marker)
    }
}

extension Render.Pair: Copyable where First: Copyable, Second: Copyable {}
extension Render.Pair: Sendable where First: Sendable & Copyable, Second: Sendable & Copyable {}
```

### File: Render Primitive/Render.Conditional.swift

```swift
extension Render {
    /// A type that holds one of two alternatives.
    ///
    /// Produced by `Render.Builder.buildEither`. The type itself is
    /// unconstrained — `Render.View` conformance is conditional.
    public enum Conditional<First: ~Copyable, Second: ~Copyable>: ~Copyable {
        case first(First)
        case second(Second)
    }
}

// MARK: - Render.View

extension Render.Conditional: Render.View
where First: Render.View & ~Copyable, Second: Render.View & ~Copyable {
    /// The body type of this leaf conformance, which never produces nested content.
    public typealias Body = Never

    /// Unreachable: the chosen branch is dispatched directly through `_render`.
    public var body: Never { fatalError("Render.Conditional has no body; rendering is performed by _render") }

    /// Renders whichever branch the conditional currently holds.
    public static func _render(
        _ view: borrowing Self,
        context: inout Render.Context
    ) {
        switch view {
        case .first(let f): First._render(f, context: &context)
        case .second(let s): Second._render(s, context: &context)
        }
    }
}

extension Render.Conditional: Copyable where First: Copyable, Second: Copyable {}
extension Render.Conditional: Sendable where First: Sendable & Copyable, Second: Sendable & Copyable {}
```

### File: Render Primitive/Render.Group.swift

```swift
extension Render {
    /// Transparent grouping that delegates rendering to its content.
    ///
    /// The type itself is unconstrained — domain packages add protocol
    /// conformances via conditional extensions. `Render.View` conformance
    /// is provided when `Content` is `Render.View`.
    public struct Group<Content> {
        /// The grouped content.
        public let content: Content

        /// Creates a group from content assembled by a `Render.Builder` closure.
        public init(
            @Render.Builder content: () -> Content
        ) {
            self.content = content()
        }
    }
}

// MARK: - Render.View

extension Render.Group: Render.View where Content: Render.View {
    /// The grouped content, rendered transparently.
    public var body: Content { content }
}

extension Render.Group: Sendable where Content: Sendable {}
```

### File: Render Primitive/Render.Empty.swift

```swift
extension Render {
    /// A view that produces no output.
    public struct Empty: Render.View, Sendable {
        /// Creates an empty view.
        public init() {}

        /// The body type of a leaf view, which never produces nested content.
        public typealias Body = Never

        /// Unreachable: `Render.Empty` is a leaf view rendered through `_render`.
        public var body: Never { fatalError("Render.Empty has no body; it is a leaf view") }

        /// Renders nothing into the context.
        public static func _render(
            _ view: borrowing Self,
            context: inout Render.Context
        ) {}
    }
}
```

> Dropped (mechanical / no bearing): Render.Pop.swift (exact mirror of Render.Push.swift), Render.Break.swift, Render.Action.Break.swift, Render.Style.swift, Render.Semantic{,.Block,.Inline,.List}.swift, Render.Speculative.swift, Render.Indirect.swift (a `final class` heap box), Array+Render.swift and Optional+Render.swift (same shape as `Render._Tuple` / `Render.Conditional` above).

---

## B. swift-machine-primitives (L1) — the defunctionalized machine

12 source targets; depends on swift-graph-primitives. Live consumers supplying their own Leaf set:
```swift
// swift-parser-machine-primitives/Sources/Parser Machine Program Primitives/Parser.Machine.Node.swift:9
public typealias Node = Machine_Primitives.Machine.Node<Leaf<Input, Failure>, Failure, Mode>
// swift-binary-parser-primitives/Sources/Binary Machine Primitives/Binary.Machine.Node.swift:9
public typealias Node = Machine_Primitives.Machine.Node<Instruction, Fault, Mode>
```

### File: Machine Primitive/Machine.swift

```swift
/// A namespace for defunctionalized machine-based parsing infrastructure.
///
/// `Machine` provides the core building blocks for representing parsers as data
/// (programs) rather than closures, enabling zero-copy parsing with Swift 6's
/// `~Escapable` types where the lifetime checker rejects closures at abstraction
/// boundaries.
///
/// The Machine infrastructure is generic over:
/// - `Leaf`: The primitive operations (cursor-specific)
/// - `Failure`: The error type for fallible operations
///
/// Cursor-specific packages (Parsing, Binary) provide their own leaf types
/// and inlined interpreters while sharing this common infrastructure.
public enum Machine {}
```

### File: Machine Node Primitives/Machine.Node.swift

```swift
public import Graph_Sequential_Primitives

extension Machine {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A node in the machine's program graph.
    ///
    /// `Node` represents a single operation in a defunctionalized parser program.
    /// It is generic over:
    /// - `Leaf`: The primitive cursor operations (cursor-specific)
    /// - `Failure`: The error type for fallible operations
    /// - `Mode`: The capture mode (`Mode.Reference` or `Mode.Unchecked`)
    ///
    /// The machine interpreter traverses the node graph, executing leaf operations
    /// and combining results according to the combinator structure.
    @safe
    public enum Node<Leaf, Failure: Swift.Error, Mode> {

        /// A unique identifier for a node in the program.
        public typealias ID = Graph.Node<Self>

        /// A primitive cursor operation.
        case leaf(Leaf)

        /// A pure value (no cursor interaction).
        case pure(Value<Mode>)

        /// Transform the result of a child node.
        case map(child: ID, transform: Transform.Erased<Mode>)

        /// Transform the result of a child node, potentially failing.
        case tryMap(child: ID, transform: Transform.Throwing<Mode, Failure>)

        /// Execute a child, then select the next node based on its result.
        case flatMap(child: ID, next: Next.Erased<Mode, ID>)

        /// Execute two nodes in sequence, combining their results.
        case sequence(a: ID, b: ID, combine: Combine.Erased<Mode>)

        /// Try alternatives in order until one succeeds.
        case oneOf([ID])

        /// Execute a child zero or more times, collecting results.
        case many(child: ID, finalize: Finalize.Array<Mode>)

        /// Execute a child zero or more times, folding results without allocation.
        ///
        /// Unlike `many` which collects into an array, `fold` accumulates incrementally:
        /// 1. Start with `initial` as accumulator
        /// 2. Try to parse `child`
        /// 3. If success: `accumulator = combine(accumulator, childResult)`, repeat
        /// 4. If failure: return accumulator
        case fold(child: ID, initial: Value<Mode>, combine: Combine.Erased<Mode>)

        /// Execute a child optionally, wrapping success or returning none.
        case optional(child: ID, wrapSome: Transform.Erased<Mode>, noneValue: Value<Mode>)

        /// Reference to another node (for recursive grammars).
        case ref(ID)

        /// Placeholder for forward references during construction.
        case hole
    }
}

extension Machine.Node: Sendable
where Leaf: Sendable, Failure: Sendable, Mode: Sendable {}

// MARK: - Graph Adjacency

extension Machine.Node {
    /// The structurally adjacent node IDs.
    public var adjacent: [ID] {
        switch self {
        case .leaf, .pure, .hole: return []
        case .map(let child, _): return [child]
        case .tryMap(let child, _): return [child]
        case .flatMap(let child, _): return [child]
        case .sequence(let a, let b, _): return [a, b]
        case .oneOf(let ids): return ids
        case .many(let child, _): return [child]
        case .fold(let child, _, _): return [child]
        case .optional(let child, _, _): return [child]
        case .ref(let id): return [id]
        }
    }

    /// Extract closure for graph algorithms.
    public static var extract: Graph.Adjacency.Extract<Self, Self, [ID]> {
        Graph.Adjacency.Extract { $0.adjacent }
    }
}
```

### File: Machine Frame Primitives/Machine.Frame.swift

```swift
extension Machine {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A stack frame in the machine's execution.
    ///
    /// `Frame` represents the continuation state when the machine enters
    /// a child node. It is generic over:
    /// - `NodeID`: The node identifier type
    /// - `Checkpoint`: The cursor checkpoint type (varies by cursor)
    /// - `Mode`: The capture mode (`Mode.Reference` or `Mode.Unchecked`)
    /// - `Failure`: The error type for fallible operations
    /// - `Extra`: Extension point for façade-specific frame types (use `Never` if not needed)
    @safe
    public enum Frame<NodeID, Checkpoint, Mode, Failure: Swift.Error, Extra> {
        /// Apply a non-throwing transform to the result.
        case map(transform: Transform.Erased<Mode>)

        /// Apply a throwing transform to the result.
        case tryMap(transform: Transform.Throwing<Mode, Failure>)

        /// Select the next node based on the result.
        case flatMap(next: Next.Erased<Mode, NodeID>)

        /// Sequence continuation state.
        case sequence(Sequence)

        /// Backtracking frame for oneOf - stores checkpoint instead of full input copy.
        case oneOf(alternatives: [NodeID], index: Int, savedCheckpoint: Checkpoint)

        /// Accumulation frame for many - stores handles to accumulated results.
        case many(child: NodeID, savedCheckpoint: Checkpoint, resultHandles: [Value<Mode>.Handle], finalize: Finalize.Array<Mode>)

        /// Fold frame - accumulates without allocation using combine function.
        case fold(child: NodeID, savedCheckpoint: Checkpoint, accumulatorHandle: Value<Mode>.Handle, combine: Combine.Erased<Mode>)

        /// Optional frame - stores handle to none value for backtracking.
        case optional(savedCheckpoint: Checkpoint, wrapSome: Transform.Erased<Mode>, noneHandle: Value<Mode>.Handle)

        /// Marker for recursive call return.
        case recursiveExit

        /// Extension point for façade-specific frames.
        ///
        /// Use `Extra = Never` when no additional frame types are needed (the case becomes uninhabited).
        /// Parsing uses this for memoization: `Extra = Frame.Extra` with `.memoization(node:startPosition:)`.
        case extra(Extra)
    }
}
```

### File: Machine Program Primitives/Machine.Program.swift

```swift
// SDG(specializes): Machine.Program is a directed graph with Graph.Sequential storage
public import Graph_Sequential_Primitives

extension Machine {
    /// A program consisting of a graph of nodes.
    ///
    /// `Program` stores the node graph that represents a defunctionalized parser.
    /// Nodes are allocated sequentially and referenced by their IDs. The program
    /// is generic over:
    /// - `Leaf`: The primitive cursor operations
    /// - `Failure`: The error type for fallible operations
    /// - `Mode`: The capture mode (`Mode.Reference` or `Mode.Unchecked`)
    public struct Program<Leaf, Failure: Swift.Error, Mode> {
        /// The sequentially-allocated node graph.
        public let graph: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>

        /// The frozen capture snapshot the interpreter reads at run time.
        public let captures: Machine.Capture.Frozen<Mode>

        /// Optional maximum machine-stack depth enforced at run time.
        public let maxDepth: Int?

        @usableFromInline
        init(
            graph: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>,
            captures: Machine.Capture.Frozen<Mode>,
            maxDepth: Int?
        ) {
            self.graph = graph
            self.captures = captures
            self.maxDepth = maxDepth
        }

        /// Accesses a node by its ID.
        @inlinable
        public subscript(id: Node<Leaf, Failure, Mode>.ID) -> Node<Leaf, Failure, Mode> {
            graph[id]
        }

        /// Analysis accessor for graph algorithms.
        @inlinable
        public var analyze: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>.Analyze<[Node<Leaf, Failure, Mode>.ID]> {
            graph.analyze(using: Node.extract)
        }
    }
}

extension Machine.Program: Sendable where Leaf: Sendable, Mode: Sendable {}
```

### File: Machine Program Primitives/Machine.Program.Builder.swift

```swift
public import Graph_Sequential_Primitives

extension Machine {
    /// A mutable builder for constructing a `Program`.
    ///
    /// `Builder` accumulates nodes and captures during construction,
    /// then produces an immutable `Program` via `build()`.
    public struct Builder<Leaf, Failure: Swift.Error, Mode>: ~Copyable {
        @usableFromInline
        var storage: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>.Builder

        /// The mutable capture store accumulated alongside the node graph.
        public var captures: Capture.Store<Mode>

        /// Optional maximum machine-stack depth enforced at run time.
        public let maxDepth: Int?

        /// Creates an empty builder, optionally bounding the machine-stack depth.
        @inlinable
        public init(maxDepth: Int? = nil) {
            self.storage = .init()
            self.captures = Capture.Store<Mode>()
            self.maxDepth = maxDepth
        }

        /// The number of nodes allocated so far.
        @inlinable
        public var count: Node<Leaf, Failure, Mode>.ID.Count {
            storage.count
        }

        /// Appends a node to the program graph, returning its ID.
        @inlinable
        public mutating func allocate(_ node: Node<Leaf, Failure, Mode>) -> Node<Leaf, Failure, Mode>.ID {
            storage.allocate(node)
        }

        /// Access/patch a node by ID (for hole patching).
        @inlinable
        public subscript(id: Node<Leaf, Failure, Mode>.ID) -> Node<Leaf, Failure, Mode> {
            get { storage[id] }
            set { storage[id] = newValue }
        }

        /// Consumes the builder, producing the immutable program.
        @inlinable
        public consuming func build() -> Program<Leaf, Failure, Mode> {
            Program(
                graph: storage.build(),
                captures: captures.freeze(),
                maxDepth: maxDepth
            )
        }
    }
}
// Builder is NOT Sendable
```

### File: Machine Transform Primitives/Machine.Transform.Erased.swift

```swift
extension Machine.Transform {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased non-throwing transformation from one value to another.
    @safe
    public struct Erased<Mode>: Sendable {
        /// The capture slot holding the underlying typed transform.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _apply:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>
            ) -> Machine.Value<Mode>

        /// Applies the transform to the given value using the frozen captures.
        @inlinable
        public func apply(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ value: Machine.Value<Mode>
        ) -> Machine.Value<Mode> {
            _apply(captures, value)
        }
    }
}

extension Machine.Transform.Erased where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased transform from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<In, Out: Sendable>(
        capture: Machine.Capture.ID<@Sendable (In) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._apply = { captures, value in
            captures.withRaw(raw, as: (@Sendable (In) -> Out).self) { transform in
                value.apply(transform)
            }
        }
    }
}

extension Machine.Transform.Erased where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased transform from a captured typed function (Unchecked mode).
    @inlinable
    public init<In, Out>(
        capture: Machine.Capture.ID<(In) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._apply = { captures, value in
            captures.withRaw(raw, as: ((In) -> Out).self) { transform in
                value.apply(transform)
            }
        }
    }
}
```

**`Machine.Value<Mode>` (dropped in full — 304 lines; the load-bearing surface):**
```swift
    @safe
    public struct Value<Mode> {
        @usableFromInline
        let type: ObjectIdentifier

        @usableFromInline
        let storage: _Storage

        @usableFromInline
        init(type: ObjectIdentifier, storage: _Storage) {
            self.type = type
            self.storage = storage
        }

        /// Single choke-point for payload projection.
        ///
        /// All `assumingMemoryBound` calls go through here, making the
        /// unsafe binding structurally tied to the stored type id.
        ///
        /// - Precondition: `T` must match the type used at construction.
        @usableFromInline
        func _project<T: ~Copyable>(_: T.Type) -> UnsafePointer<T> {
            unsafe UnsafePointer(storage.payload.assumingMemoryBound(to: T.self))
        }
        @inlinable
        public subscript<T: ~Copyable>(as type: T.Type) -> T {
            _read {
                precondition(
                    self.type == ObjectIdentifier(T.self),
                    "Machine.Value type mismatch: expected \(T.self), got type with id \(self.type)"
                )
                yield unsafe _project(type).pointee
            }
        }

// Reference mode requires Sendable; BOTH modes heap-allocate per value:
extension Machine.Value where Mode == Machine.Capture.Mode.Reference {
    /// Creates a type-erased value from a concrete Sendable value.
    ///
    /// This is the only construction path for `Value<Mode.Reference>`.
    /// The Sendable constraint ensures all values in Reference mode are safe
    /// to share across isolation domains.
    @inlinable
    public static func make<T: Sendable & ~Copyable>(_ value: consuming T) -> Machine.Value<Mode> {
        let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)
        unsafe payload.initialize(to: value)

        let table = _Table(T.self)
        let storage = unsafe _Storage(
            payload: UnsafeMutableRawPointer(payload),
            table: table
        )

        return Machine.Value<Mode>(
            type: ObjectIdentifier(T.self),
            storage: storage
        )
    }
}
```

> Dropped: Machine.Combine.Erased / Machine.Next.Erased / Machine.Finalize.Array (identical shape to Transform.Erased), Machine.Capture.* (the frozen capture store the Erased carriers index into), Machine.Value.Arena / .Handle, Machine.Builder+Carriers, Machine.Program+Apply.

---

## C. swift-effect-primitives (L1) — algebraic effects

### File: Effect Primitives/Effect.swift

```swift
/// Namespace for algebraic effect primitives.
///
/// Algebraic effects provide a way to define, perform, and handle
/// operations with resumable continuations. This namespace contains
/// the minimal building blocks required.
///
/// ## Core Concepts
///
/// - **Effects** are operations that a computation cannot handle directly
/// - **Perform** suspends the computation and yields to a handler
/// - **Handlers** interpret effects and resume the continuation
///
/// ## Example
///
/// ```swift
/// // Define an effect
/// struct ReadLine: Effect.Protocol {
///     typealias Value = String
///     typealias Failure = Never
/// }
///
/// // Perform effects in a handled context
/// try await Effect.Context.with { handlers in
///     handlers[ConsoleHandler.self] = .live
/// } operation: {
///     let line = try await Effect.perform(ReadLine())
///     print("Read: \(line)")
/// }
/// ```
public enum Effect {
    /// Protocol for types representing effect operations.
    ///
    /// Use `Effect.Protocol` to refer to this type.
    public typealias `Protocol` = __EffectProtocol
}
```

### File: Effect Primitives/Effect.Protocol.swift

```swift
/// Marker protocol for types representing effect operations.
///
/// An effect operation is a request to perform some action that
/// the current computation cannot handle directly. Effects are:
/// - **Declared** by conforming to this protocol
/// - **Performed** by yielding to a handler
/// - **Handled** by providing an implementation with access to the continuation
///
/// ## Conformance Requirements
///
/// Conforming types declare their argument and result types:
///
/// ```swift
/// struct ReadLine: Effect.Protocol {
///     typealias Arguments = Void
///     typealias Value = String
///     typealias Failure = Never
/// }
///
/// struct Fetch: Effect.Protocol {
///     typealias Arguments = URL
///     typealias Value = Data
///     typealias Failure = NetworkError
///
///     let url: URL
///     var arguments: URL { url }
/// }
/// ```
///
/// ## Design Rationale
///
/// Effects carry their arguments as instance data rather than method
/// parameters. This enables type-level dispatch and cleaner composition.
///
/// ## Noncopyable Support
///
/// `Arguments` and `Value` admit `~Copyable` types: an effect may carry
/// linear resources (owning file descriptors, unique tokens) as arguments
/// or deliver them as results. `arguments` is exposed through a
/// `borrowing get` so a `~Copyable` Arguments value can be observed
/// without being consumed.
///
/// - Note: This protocol is hoisted to module level due to Swift limitations.
///   Use `Effect.Protocol` to refer to this type.
public protocol __EffectProtocol: ~Copyable {
    /// The arguments provided when performing this effect.
    associatedtype Arguments: ~Copyable = Void

    /// The success value type returned when the effect is handled.
    associatedtype Value: ~Copyable

    /// The error type that handling may produce.
    associatedtype Failure: Swift.Error = Never

    /// The arguments for this effect instance.
    var arguments: Arguments { borrowing get }
}

extension __EffectProtocol where Self: ~Copyable, Arguments == Void {
    /// Default implementation providing `()` for effects with no arguments.
    public var arguments: Void { () }
}
```

### File: Effect Primitives/Effect.Handler.swift

```swift
/// Protocol for types that can handle (interpret) effects.
///
/// A handler wraps an operation and intercepts effects performed
/// within it. When an effect is performed:
/// 1. The current continuation is captured
/// 2. Control transfers to the handler
/// 3. The handler can resume, transform, or abort
///
/// Handlers compose via nesting (inner handlers run first):
///
/// ```swift
/// try await Effect.Context.with { handlers in
///     handlers[OuterHandler.self] = outer
/// } operation: {
///     try await Effect.Context.with { handlers in
///         handlers[InnerHandler.self] = inner
///     } operation: {
///         perform(someEffect)  // innerHandler handles first
///     }
/// }
/// ```
///
/// ## Handler Semantics
///
/// Handlers receive ownership of a one-shot continuation and must
/// decide what to do:
///
/// - **Resume normally**: Call `continuation.resume(returning:)`
/// - **Resume with error**: Call `continuation.resume(throwing:)`
/// - **Abort**: Don't resume (continuation is dropped)
/// - **Defer**: Store continuation for later resumption
///
/// ## Type Safety
///
/// Handlers are parameterized by the effect type they handle,
/// ensuring type-safe interpretation of effect arguments and results.
///
/// ## Noncopyable Support
///
/// The handler itself admits `~Copyable` conformers: a handler may own
/// linear state (a descriptor, a connection, a pool token). The handled
/// effect also admits `~Copyable` types — the `handle` requirement takes
/// the effect by `borrowing`, allowing the handler to observe a linear
/// effect instance without consuming it.
///
/// - Note: This protocol is hoisted to module level due to Swift limitations.
///   Use `Effect.Handler.Protocol` to refer to this type.
public protocol __EffectHandler: ~Copyable {
    /// The effect type this handler interprets.
    associatedtype Handled: ~Copyable & __EffectProtocol

    /// Handle an effect, resuming the continuation.
    ///
    /// - Parameters:
    ///   - effect: The effect being performed
    ///   - continuation: The continuation to resume (consumed)
    func handle(
        _ effect: borrowing Handled,
        continuation: consuming Effect.Continuation.One<Handled.Value, Handled.Failure>
    ) async
}

extension Effect {
    /// Namespace for handler-related types.
    public enum Handler {
        /// Protocol for types that can handle (interpret) effects.
        ///
        /// Use `Effect.Handler.Protocol` to refer to this type.
        public typealias `Protocol` = __EffectHandler
    }
}
```

### File: Effect Primitives/Effect.Handler.Sync.swift

```swift
extension Effect.Handler {
    /// Protocol for handlers that can operate synchronously.
    ///
    /// Synchronous handlers don't require `async` context in their
    /// implementation, though they still use the async continuation
    /// interface for consistency.
    ///
    /// ## When to Use
    ///
    /// Use synchronous handlers when:
    /// - The effect can be handled immediately without async work
    /// - You need deterministic, predictable behavior for testing
    /// - Performance is critical and async overhead matters
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct PureRandomHandler: Effect.Handler.Sync {
    ///     typealias Handled = RandomInt
    ///
    ///     let seed: UInt64
    ///
    ///     func handle(
    ///         _ effect: RandomInt,
    ///         continuation: consuming Effect.Continuation.One<Int, Never>
    ///     ) async {
    ///         // Pure deterministic "random" for testing
    ///         let value = Int(seed % UInt64(effect.range.count))
    ///         await continuation.resume(returning: effect.range.lowerBound + value)
    ///     }
    /// }
    /// ```
    public typealias Sync = __EffectHandler
}
```

### File: Effect Primitives/Effect.perform.swift

```swift
// Note: The actual perform implementation requires integration with a runtime layer
// that provides the suspension/resumption coordination. This file defines the shape
// and documents the intended semantics. The swift-effects package builds on these
// primitives to provide the full implementation.

extension Effect {
    /// Marker type for perform operations.
    ///
    /// The actual `perform` functions are defined as extensions on `Effect`
    /// in the runtime layer (swift-effects), which provides:
    /// - Handler dispatch via `Effect.Context`
    /// - Continuation capture and management
    /// - Integration with Swift's async/await
    ///
    /// ## Expected Signature
    ///
    /// The runtime layer provides:
    ///
    /// ```swift
    /// extension Effect {
    ///     static func perform<E: Effect.Protocol>(
    ///         _ effect: E
    ///     ) async throws(E.Failure) -> E.Value
    /// }
    /// ```
    ///
    /// ## Semantics
    ///
    /// When `perform` is called:
    /// 1. The current continuation is captured
    /// 2. The handler for `E` is looked up in `Effect.Context.current`
    /// 3. The handler's `handle(_:continuation:)` is called
    /// 4. The caller suspends until the handler resumes
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Define an effect
    /// struct ReadLine: Effect.Protocol {
    ///     typealias Value = String
    ///     typealias Failure = Never
    /// }
    ///
    /// // Perform it (with handler in scope)
    /// let line = await Effect.perform(ReadLine())
    /// ```
    public enum Perform {}
}

// MARK: - Continuation Factory

extension Effect.Continuation {
    /// Creates a one-shot continuation from a `Result`-delivering closure.
    ///
    /// Available when `Value` is `Copyable` because stdlib's
    /// `Result<Value, Failure>` requires a copyable value.
    ///
    /// - Parameter resume: The closure invoked when the handler resumes.
    /// - Returns: A one-shot continuation.
    public static func one<Value, Failure: Swift.Error>(
        _ resume: @escaping @Sendable (sending Result<Value, Failure>) async -> Void
    ) -> One<Value, Failure> {
        One(
            onValue: { value in await resume(.success(value)) },
            onError: { error in await resume(.failure(error)) }
        )
    }

    /// Creates a one-shot continuation from explicit value and error callbacks.
    ///
    /// Handlers invoke exactly one of the two callbacks via
    /// `resume(returning:)` or `resume(throwing:)`. This form supports
    /// `~Copyable` `Value` types where stdlib's `Result` cannot be used.
    ///
    /// - Parameters:
    ///   - onValue: Invoked when the handler resumes with a value.
    ///   - onError: Invoked when the handler resumes with an error.
    /// - Returns: A one-shot continuation.
    public static func one<Value: ~Copyable, Failure: Swift.Error>(
        onValue: @escaping @Sendable (consuming sending Value) async -> Void,
        onError: @escaping @Sendable (Failure) async -> Void
    ) -> One<Value, Failure> {
        One(onValue: onValue, onError: onError)
    }

    /// Creates a multi-shot continuation from a resume closure.
    ///
    /// Multi-shot continuations can be resumed multiple times,
    /// creating multiple branches of computation.
    ///
    /// - Parameter resume: The closure to call when resuming.
    /// - Returns: A multi-shot continuation.
    public static func multi<Value, Failure: Swift.Error>(
        _ resume: @escaping @Sendable (sending Result<Value, Failure>) async -> Void
    ) -> Multi<Value, Failure> {
        Multi(resume)
    }
}
```

### File: Effect Primitives/Effect.Continuation.swift

```swift
/// Protocol for continuation types that can resume suspended computations.
///
/// Continuations represent "the rest of the computation" after an
/// effect is performed. Handlers receive a continuation and can:
/// - Resume with a value (success)
/// - Resume with an error (failure)
/// - Never resume (abort)
/// - Resume multiple times (multi-shot, requires copying)
///
/// ## One-Shot vs Multi-Shot
///
/// One-shot continuations can be resumed at most once. They are
/// more efficient because the stack doesn't need to be copied.
/// Multi-shot continuations can be resumed multiple times, enabling
/// patterns like backtracking or probabilistic programming.
///
/// The `~Copyable` constraint on ``Effect.Continuation.One`` enforces one-shot semantics
/// at compile time, preventing double-resume bugs.
///
/// ## Noncopyable Value Support
///
/// The `Value` associated type admits `~Copyable` types so a handler may
/// resume with a linear resource. `resume(with:)` (which takes a stdlib
/// `Result`) is provided as an extension where `Value: Copyable`; it is
/// intentionally absent from the protocol requirement because stdlib's
/// `Result<Value, Failure>` requires `Value: Copyable`.
///
/// ## See Also
///
/// - ``Effect.Continuation.One``: One-shot continuation (move-only, enforced)
/// - ``Effect.Continuation.Multi``: Multi-shot continuation (copyable)
///
/// - Note: This protocol is hoisted to module level due to Swift limitations.
///   Use `Effect.Continuation.Protocol` to refer to this type.
public protocol __EffectContinuation<Value, Failure>: ~Copyable {
    /// The success value type this continuation accepts.
    associatedtype Value: ~Copyable

    /// The error type this continuation accepts.
    associatedtype Failure: Swift.Error

    /// Resume the continuation with a successful value.
    ///
    /// - Parameter value: The value to resume with.
    consuming func resume(returning value: consuming sending Value) async

    /// Resume the continuation with an error.
    ///
    /// - Parameter error: The error to resume with.
    consuming func resume(throwing error: Failure) async
}

extension Effect {
    /// Namespace for continuation types.
    public enum Continuation {
        /// Protocol for continuation types.
        ///
        /// Use `Effect.Continuation.Protocol` to refer to this type.
        public typealias `Protocol` = __EffectContinuation
    }
}
```

**`Effect.Outcome` (head only) and `Effect.Context` (signatures only):**
```swift
    public enum Outcome<Value: ~Copyable, Failure: Swift.Error>: ~Copyable {
        /// The effect was handled and computation resumed with a value.
        case resumed(Value)

        /// The effect was handled and computation resumed with an error.
        case threw(Failure)

        /// The effect was handled but computation was aborted (not resumed).
        case aborted
    }
}

// MARK: - Conditional Conformances

extension Effect.Outcome: Copyable where Value: Copyable {}
extension Effect.Outcome: Sendable where Value: Sendable & ~Copyable, Failure: Sendable {}

// Effect.Context is a thin wrapper over Dependency.Scope (task-local storage):
    public struct Context: Sendable {
        private init() {}
    }
    public typealias Key = Dependency.Key

    /// Storage for registered handlers.
    ///
    /// This is an alias for ``Dependency/Values``.
    public typealias Handlers = Dependency.Values
    public static var current: Handlers {
        Dependency.Scope.current
    }
    public static func with<T, E: Swift.Error>(
        _ modify: (inout Handlers) -> Void,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        try Dependency.Scope.with(modify, operation: operation)
```

> Dropped: Effect.Continuation.One.swift / .Multi.swift (concrete one-shot / multi-shot continuations), the Equation/Hash conformances and Result bridges on Effect.Outcome.

---

## D. swift-svg-render (L3) — the claimed duplication witness (complete, not excerpted)

### File: SVG Rendering/SVG.View.swift

```swift
//
//  SVG.View.swift
//  swift-svg-rendering
//

public import Dictionary_Ordered_Primitives
import Dimension_Primitives
import Format_Primitives
public import Render_Primitives

/// A namespace for SVG-related types.
public enum SVG {}

extension SVG {
    public protocol View {
        associatedtype Content: SVG.View
        @SVG.Builder var body: Content { get }

        static func _render<Buffer: RangeReplaceableCollection>(
            _ svg: Self,
            into buffer: inout Buffer,
            context: inout SVG.Context
        ) where Buffer.Element == UInt8
    }
}

// reason: `Content: Self` here is not valid Swift in this where-clause
// conformance position ("type 'Self.Content' constrained to non-protocol,
// non-class type 'Self'") — confirmed by CI breakage across this package
// and downstream swift-pdf when swiftlint --fix applied it (commit 60e00fd).
// swiftlint:disable:next prefer_self_in_static_references
extension SVG.View where Content: SVG.View {
    @inlinable
    @_disfavoredOverload
    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        Content._render(svg.body, into: &buffer, context: &context)
    }
}

extension SVG.View {
    public func attribute(_ name: String, _ value: String? = "") -> SVG._Attributes<Self> {
        var attrs = SVG.Context.Attributes()
        if let value {
            attrs.set(name, value)
        }
        return SVG._Attributes(content: self, attributes: attrs)
    }

    public func attribute(_ name: String, _ value: Double?) -> SVG._Attributes<Self> {
        attribute(name, value?.formatted(.number))
    }

    public func attribute<Tag>(
        _ name: String,
        _ value: Tagged<Tag, Double>?
    ) -> SVG._Attributes<Self> {
        attribute(name, value?.formatted(.number))
    }
}

extension CustomStringConvertible where Self: SVG.View {
    public var description: String {
        String(self)
    }
}
```

### File: SVG Rendering/SVG.Context.swift

```swift
//
//  SVG.Context.swift
//  swift-svg-rendering
//
//  Rendering context for SVG streaming.
//  Holds state (attributes, indentation) separate from the output buffer.
//

public import Dictionary_Ordered_Primitives
public import Render_Primitives

extension SVG {
    public struct Context: Sendable {
        /// The current set of attributes to apply to the next SVG element.
        public var attributes: Attributes

        /// Configuration for rendering, including formatting options.
        public let configuration: SVG.Context.Configuration

        /// The current indentation level for pretty-printing.
        public var currentIndentation: [UInt8]
    }
}

extension SVG.Context {
    public init(_ configuration: Configuration = .default) {
        self.attributes = .init()
        self.configuration = configuration
        self.currentIndentation = []
    }
}

extension SVG.Context {
    public struct Configuration: Sendable {
        public var indentation: [UInt8]
        public var newline: [UInt8]

        public init(indentation: String = "", newline: String = "") {
            self.indentation = Array(indentation.utf8)
            self.newline = Array(newline.utf8)
        }
    }
}

extension SVG.Context.Configuration {
    public static let `default` = Self()
    public static let pretty = Self(indentation: "  ", newline: "\n")
}

extension SVG.Context {
    @inlinable
    public func appendNewline<Buffer: RangeReplaceableCollection>(
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        if !configuration.newline.isEmpty {
            buffer.append(contentsOf: configuration.newline)
        }
    }

    @inlinable
    public func indented() -> SVG.Context {
        var copy = self
        copy.currentIndentation.append(contentsOf: configuration.indentation)
        return copy
    }

    @inlinable
    public func outdented() -> SVG.Context {
        var copy = self
        if copy.currentIndentation.count >= configuration.indentation.count {
            copy.currentIndentation.removeLast(configuration.indentation.count)
        }
        return copy
    }

    @inlinable
    public func appendIndentation<Buffer: RangeReplaceableCollection>(
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        if !configuration.indentation.isEmpty && !currentIndentation.isEmpty {
            buffer.append(contentsOf: currentIndentation)
        }
    }
}
```

### File: SVG Rendering/SVG.Builder.swift

```swift
//
//  SVG.Builder.swift
//  swift-svg-rendering
//

public import Render_Primitives

extension SVG {
    public typealias Builder = Render.Builder
}
```

### File: SVG Rendering/SVG._Tuple.swift

```swift
//
//  SVG._Tuple.swift
//  swift-svg-rendering
//

public import Render_Primitives

extension Render._Tuple: SVG.View where repeat each Content: SVG.View {
    public var body: Never { fatalError("body should not be called") }

    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        func render<T: SVG.View>(_ element: T) {
            let oldAttributes = context.attributes
            defer { context.attributes = oldAttributes }
            T._render(element, into: &buffer, context: &context)
        }
        repeat render(each svg.content)
    }
}
```

### File: SVG Rendering/SVG._Conditional.swift

```swift
//
//  SVG._Conditional.swift
//  swift-svg-rendering
//

public import Render_Primitives

extension Render.Conditional: SVG.View where First: SVG.View, Second: SVG.View {
    public var body: Never { fatalError("body should not be called") }

    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        switch svg {
        case .first(let first): First._render(first, into: &buffer, context: &context)
        case .second(let second): Second._render(second, into: &buffer, context: &context)
        }
    }
}
```

### File: SVG Rendering/SVG.Empty.swift

```swift
//
//  SVG.Empty.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

/// An empty SVG element that renders nothing.
///
/// This type is useful as a placeholder or when conditionally
/// rendering content that might be empty.
extension SVG {
    public struct Empty: SVG.View {
        /// Creates an empty SVG element.
        public init() {}
    }
}

extension SVG.Empty {
    /// Renders nothing into the buffer.
    public static func _render<Buffer: RangeReplaceableCollection>(
        _ svg: Self,
        into buffer: inout Buffer,
        context: inout SVG.Context
    ) where Buffer.Element == UInt8 {
        // Intentionally empty
    }

    public var body: Never { fatalError("body should not be called") }
}
```

### File: SVG Rendering/SVG.Group.swift

```swift
//
//  SVG.Group.swift
//  swift-svg-renderable
//
//  Created by Coen ten Thije Boonkkamp on 26/11/2025.
//

/// A container that groups multiple SVG elements together.
///
/// `SVG.Group` allows you to compose multiple SVG elements without
/// adding any additional rendering structure. It's useful for
/// returning multiple elements from computed properties or functions.
///
/// Example:
/// ```swift
/// var icons: some SVG.View {
///     SVG.Group {
///         circle(cx: 10, cy: 10, r: 5)
///         rect(x: 20, y: 20, width: 10, height: 10)
///     }
/// }
/// ```
extension SVG {
    public struct Group<Content: SVG.View>: SVG.View {
        /// The content of the group.
        let content: Content

        /// Creates a group with the given content.
        ///
        /// - Parameter content: A closure that returns the SVG content.
        public init(@SVG.Builder _ content: () -> Content) {
            self.content = content()
        }

        /// The body of the group is its content.
        public var body: some SVG.View {
            content
        }
    }
}
```

> Also present and dropped for brevity, all the same shape: `SVG._Array.swift` (`extension Array: SVG.View where Element: SVG.View`), `Optional+SVG.swift`, `Never+SVG.swift` — each a stdlib type conformed to `SVG.View` with a 3-line `_render`.

---

## E. swift-html-render (L3) — the OTHER render consumer (complete files)

### File: HTML Rendering Core/HTML.View.swift

```swift
//
//  HTML.View.swift
//  swift-html-rendering
//
//  Created by Point-Free, Inc
//

import Dictionary_Ordered_Primitives
public import Render_Primitives
public import WHATWG_HTML_Shared

/// A protocol representing an HTML element or component that can be rendered.
///
/// `HTML.View` refines `Render.View`, enabling the same view tree to render
/// to both HTML and PDF through format-specific `Render.Context` implementations.
/// All rendering goes through the single `_render(_ view:context:)` method.
///
/// Example:
/// ```swift
/// struct MyView: HTML.View {
///     var body: some HTML.View {
///         div {
///             h1 { "Hello, World!" }
///             p { "This is a paragraph." }
///         }
///     }
/// }
/// ```
extension HTML {
    public protocol View: Render.View where Body: HTML.View {
        @HTML.Builder var body: Body { get }
    }
}

/// Extension to add attribute capabilities to all HTML elements.
extension HTML.View {
    /// Adds a custom attribute to an HTML element.
    ///
    /// - Parameters:
    ///   - name: The name of the attribute.
    ///   - value: The optional value of the attribute. If nil, the attribute is omitted.
    ///            If an empty string, the attribute is included without a value.
    /// - Returns: An HTML element with the attribute applied.
    public func attribute(_ name: String, _ value: String? = "") -> HTML._Attributes<Self> {
        var attributes = HTML.Context.Attributes()
        if let value {
            attributes[name] = value
        }
        return HTML._Attributes(content: self, attributes: attributes)
    }
}

/// Provides a default `description` implementation for HTML types that also conform to `CustomStringConvertible`.
extension CustomStringConvertible where Self: HTML.View {
    public var description: String {
        do throws(HTML.Context.Configuration.Error) {
            return try String(self)
        } catch {
            return ""
        }
    }
}
```

### File: HTML Rendering Core/_Tuple+HTML.swift

```swift
//
//  _Tuple+HTML.swift
//  swift-html-rendering
//
//  Created by Coen ten Thije Boonkkamp on 25/11/2025.
//

public import Render_Primitives
public import WHATWG_HTML_Shared

/// _Tuple already conforms to Render.View when all elements conform to Render.View (from L1).
///
/// Add HTML.View conformance so it works in HTML builder blocks.
extension Render._Tuple: HTML.View where repeat each Content: HTML.View {}
```

### File: HTML Rendering Core/_Conditional+HTML.swift

```swift
//
//  _Conditional+HTML.swift
//  swift-html-rendering
//
//  Created by Coen ten Thije Boonkkamp on 25/11/2025.
//

public import Render_Primitives
public import WHATWG_HTML_Shared

/// Conditional already conforms to Render.View when both branches conform (from L1).
///
/// Add HTML.View conformance.
extension Render.Conditional: HTML.View where First: HTML.View, Second: HTML.View {}
```

### File: HTML Rendering Core/Never+HTML.swift

```swift
//
//  Never+HTML.swift
//  swift-html-rendering
//
//  Created by Coen ten Thije Boonkkamp on 25/11/2025.
//

public import Render_Primitives
public import WHATWG_HTML_Shared

/// Never already conforms to Render.View (from L1).
///
/// Add HTML.View conformance for the type system.
extension Never: HTML.View {}
```

### File: HTML Rendering Core/HTML.Empty.swift

```swift
//
//  HTML.Empty.swift
//  swift-html-rendering
//
//  Created by Point-Free, Inc
//

public import Render_Primitives
public import WHATWG_HTML_Shared

extension HTML {
    /// A view that produces no output. Alias to `Render.Empty`.
    public typealias Empty = Render.Empty
}

/// Render.Empty already conforms to Render.View (from L1).
///
/// Add HTML.View conformance so it can appear in HTML builder blocks.
extension Render.Empty: HTML.View {}
```

### File: HTML Rendering Core/HTML.Group.swift

```swift
//
//  HTML.Group.swift
//  swift-html-rendering
//
//  Created by Point-Free, Inc
//

public import Render_Primitives
public import WHATWG_HTML_Shared

extension HTML {
    public typealias Group = Render.Group
}

/// Group already conforms to Render.View when Content conforms (from L1).
///
/// Add HTML.View conformance.
extension Render.Group: HTML.View where Content: HTML.View {}
```

> `_Array+HTML.swift` and `Optional+HTML.swift` are the same one-line shape: `extension Array: HTML.View where Element: HTML.View {}` / `extension Optional: HTML.View where Wrapped: HTML.View {}`.

> `swift-pdf-render` has the same shape again: `Render.Context +PDF.swift`, `PDF.Context+Rendering.swift`, plus `_Tuple+PDF.View.swift`, `Conditional+PDF.View.swift`, `Array+PDF.View.swift`, `Pair+PDF.View.swift`, `Never+PDF.View.swift`, `Optional+PDF.View.swift`, `Empty+PDF.View.swift`.


---

## Round 1 - Claude

### Position

**No merge. No Effect naming borrow. No new signature concept. The real defect is a target boundary, not a missing abstraction.**

#### Round-1 binding constraint ([COLLAB-002])

My position rests on two ratified constraints. If either is up for revision, my answer changes:

1. **The render path's governing constraint set R1–R10**, from `swift-render-primitives/Research/cooperative-pool-stack-overflow.md:518-527`. Load-bearing here:
   - **R1 — static dispatch (100%)**: *"No dynamic dispatch, no vtable lookups. Every `_render` call resolves at compile time. This is the foundation of the rendering architecture's performance model."*
   - **R2 — no existentials**: *"No `any View`, no `Any`, no protocol-typed storage. Existentials erase type information and introduce heap allocation + witness table indirection. Contradicts R1."*
   - **R3 — `~Copyable` support**, **R7 — arbitrary depth AND width** on a 544 KB cooperative pool stack.
2. **The 2026-03-12 DECISION** in `swift-render-primitives/Research/unified-rendering-context-architecture.md` (status: DECISION, tier 2): composition types (`Builder`, `_Tuple`, `Conditional`, `Pair`) are *unconstrained*, with per-domain conformances added conditionally; each render domain owns its own `View`/`Context`. That decision was reached through a prior collaborative discussion and validated by six experiments (`generic-rendering-context`, `borrowing-pattern-matching`, `embedded-rendering-context`, `embedded-style-extensions`, `conditional-copyable-conformance`, `vertical-slice-rendering`).

I am *not* treating either as unchallengeable — R1/R2 in particular are the crux, and if you think they are the wrong constraints, say so directly. But they are the base rate my cost calculus uses.

#### First: three of the four premises I was handed do not survive source

I verified every claim in my brief against source before it entered this position. Two survive, two do not.

**Claim 1 — Machine is defunctionalization generic over its operation set. VERIFIED, with a material correction.**

`Machine.swift:1-14` says exactly what was reported. Two live, independent instantiations exist:

```swift
// swift-parser-machine-primitives/.../Parser.Machine.Node.swift:9
public typealias Node = Machine_Primitives.Machine.Node<Leaf<Input, Failure>, Failure, Mode>
// swift-binary-parser-primitives/.../Binary.Machine.Node.swift:9
public typealias Node = Machine_Primitives.Machine.Node<Instruction, Fault, Mode>
```

The correction: the case list I was given (`.leaf/.pure/.map/.tryMap/.flatMap/.sequence/.oneOf/.many`) is **incomplete**. `Machine.Node` also has `.fold`, `.optional`, `.ref`, `.hole` (`Machine.Node.swift:44-63`). Those four are not incidental — see (a) below.

**Claim 2 — Effect is algebraic effects. VERIFIED, with a material correction.**

`Effect.Protocol` is an operation symbol with `Arguments`/`Value`/`Failure` (`Effect.Protocol.swift:45-57`). `Effect.Handler` is the interpretation (`Effect.Handler.swift:48-61`). `Effect.Outcome` is `resumed`/`threw`/`aborted` (`Effect.Outcome.swift:44-53`). `Effect.Context` is scoped registration over `Dependency.Scope` (`Effect.Context.swift:46-83`).

The correction: **`Effect.Handler.Sync` is not a synchronous handler.** It is `public typealias Sync = __EffectHandler` (`Effect.Handler.Sync.swift:33`) — literally the same async protocol under a second name, with a doc comment claiming synchronous applicability. There is no sync handler shape anywhere in the package. This is decisive for (c).

**Claim 3 — Render "independently reinvented" a narrower Machine. REFUTED as to independence.**

`swift-render-primitives/Research/rendering-machine-handoff.md:127` lists, under "Key files in other packages":

> `swift-parser-machine-primitives/Sources/Parser Machine Core Primitives/Parser.Machine.Run.swift` | Reference: the parser machine execution loop **this is adapted from**

The resemblance is genealogical and documented, not accidental convergence. That reframes the question: it is not "two teams built the same thing twice," it is "one team deliberately borrowed a loop shape and then narrowed it." The right question about a deliberate narrowing is whether the narrowing was correct — not whether the duplication was an accident.

The structural mapping is also looser than reported. `Render.Action` is *not* "the leaf set" in Machine's sense: a `Machine` Leaf **produces a value** that flows through `map`/`combine`/`finalize`; a `Render.Action` **produces a side effect** on a context and returns `Void`. That is not a narrower leaf set — it is a different kind of thing.

**Claim 4 — "the same composition types are hand-re-conformed in every render consumer." LARGELY REFUTED. This one matters most.**

I was told the duplication tell is `SVG._Tuple`, `SVG.AnyView`, `SVG.Empty`, `Never+SVG`, `Optional+SVG`, `HTML.AnyView`, `HTML.Empty`, `Never+HTML`, `_Array+HTML`. Source says:

- `swift-html-render/.../HTML.Empty.swift:13` — `public typealias Empty = Render.Empty`
- `swift-html-render/.../HTML.Group.swift:13` — `public typealias Group = Render.Group`
- `_Tuple+HTML.swift:14` — `extension Render._Tuple: HTML.View where repeat each Content: HTML.View {}` — **empty body**
- `_Conditional+HTML.swift:14`, `_Array+HTML.swift:14`, `Never+HTML.swift:14`, `Optional+HTML.swift:14` — all **one-line, empty-bodied marker conformances**

There is **zero re-implementation** in `swift-html-render`. `HTML.View: Render.View` (`HTML.View.swift:30`), so every `_render` is inherited. `swift-pdf-render` has the same shape. These files are the *sharing already working*, not evidence of its absence.

In `swift-svg-render`:
- `SVG.Builder.swift:9` — `public typealias Builder = Render.Builder`
- `SVG._Tuple.swift:8` — `extension Render._Tuple: SVG.View where ...` — a conformance on the **shared** type, not a redeclaration
- `SVG._Conditional.swift:8` — same, on shared `Render.Conditional`

Only `SVG.Empty`, `SVG.Group`, and `SVG.AnyView` are genuinely SVG-owned declarations. `Never+SVG`, `Optional+SVG`, `SVG._Array` are conformances of *stdlib* types, which Swift's nominal conformance system requires per protocol, per module, forever — no amount of Leaf-genericity removes them.

**So the duplication that motivated this entire investigation is about three small types in one package.** `Render.Builder`'s doc comment ("This allows the same builder to serve document rendering (`Render.View`), graphics rendering (`SVG.View`), and any future rendering domain") is not an unmet aspiration. It is a description of shipping code.

### (a) MISSION — Machine does not generalize; its *name* overreaches its essence

The framing I was given ("the docs lag the type") assumes the type is neutral and only the prose is parochial. Source says the **type** is parochial too.

**Evidence 1 — `Checkpoint` is a mandatory generic parameter of the frame type.**

```swift
public enum Frame<NodeID, Checkpoint, Mode, Failure: Swift.Error, Extra> {
    case oneOf(alternatives: [NodeID], index: Int, savedCheckpoint: Checkpoint)
    case many(child: NodeID, savedCheckpoint: Checkpoint, resultHandles: [Value<Mode>.Handle], finalize: Finalize.Array<Mode>)
    case fold(child: NodeID, savedCheckpoint: Checkpoint, accumulatorHandle: Value<Mode>.Handle, combine: Combine.Erased<Mode>)
    case optional(savedCheckpoint: Checkpoint, wrapSome: Transform.Erased<Mode>, noneHandle: Value<Mode>.Handle)
    // ...
}
```

Four of ten cases store a `savedCheckpoint`. A checkpoint is a *rewindable cursor position*. Machine does not merely permit backtracking — backtracking is in its frame vocabulary as a structural requirement.

**Evidence 2 — the node algebra is a parser-combinator algebra.** `.oneOf` is *"try alternatives in order until one succeeds"* — ordered choice, which presupposes failure and rewind. `.many` is Kleene star. `.fold` is star-with-accumulator. `.ref` and `.hole` are recursive-grammar reference and forward-reference patching. That is PEG, spelled as an enum.

**Evidence 3 — Machine's own doc names its domain.** `Machine.swift:1` — *"A namespace for defunctionalized machine-based **parsing** infrastructure."* The doc does not lag the type; it agrees with it. What overreaches is the *package and namespace name*, `Machine`, which promises generality the type does not deliver.

**Answer to (a):** Machine's essence is *"a backtracking, value-producing recognizer over a rewindable cursor, represented as data."* Render's essence is *"a single LIFO walk of a statically-typed view tree emitting bracketed side effects, without recursion."* Those are different questions, so under [ARCH-LAYER-014] (layer/identity follows essence) and [ARCH-LAYER-010] (strict mission) they are different packages. **Render needs no sibling and no merge — it already is the sibling.**

A secondary finding, which I raise because consistency demands it: by the same test I just applied to Render, **`swift-machine-primitives` has a mission-boundary defect of its own.** It is named for a general concept and delivers a specific one. That is a separate dispatch, not this session's question — but I will not argue "Machine is parochial" as a defence of Render and then decline to say so about Machine.

### (b) SHAPE FIT — the profiles do not reconcile; three structural mismatches, each independently fatal

**Mismatch 1: Machine requires a build phase. Render has no program to build.**

`Machine.Program.Builder` accumulates nodes into a `Graph.Sequential<...>.Builder` and `consuming func build()` produces the immutable `Program`. Interpretation runs *afterwards*, over node IDs. Render has no such artifact: the view tree **is** the program, and `_render` consumes it during the walk. Hosting Render on Machine means materialising every document as a node graph before emitting a single byte — a whole extra pass, with allocation proportional to document size, plus `Machine.Value` boxes for what is currently pure control flow.

Machine's arena design *amortises*: build one grammar, run it against many inputs. That is the correct trade for parsing. A document renders **once**. The amortisation denominator is 1, so the build cost is pure loss.

**Mismatch 2: `Machine.Value` is a type-erased heap box. R1 and R2 forbid exactly that.**

```swift
public struct Value<Mode> {
    let type: ObjectIdentifier
    let storage: _Storage          // final class holding UnsafeMutableRawPointer
}
public static func make<T: Sendable & ~Copyable>(_ value: consuming T) -> Machine.Value<Mode> {
    let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)   // heap alloc per value
    ...
}
public subscript<T: ~Copyable>(as type: T.Type) -> T {
    _read {
        precondition(self.type == ObjectIdentifier(T.self), ...)   // runtime type check
        yield unsafe _project(type).pointee                        // assumingMemoryBound
    }
}
```

This is an existential in all but spelling: erased type identity, heap allocation, runtime-checked projection. R2 forbids it by name (*"Existentials erase type information and introduce heap allocation + witness table indirection"*). Render's `Render.Thunk` is the opposite construction — its `dispatch`/`destroy` closures are **monomorphised at construction** per concrete view type (`Render.Thunk.swift:17-28`), so every dispatch is a static call through a known function. That is R1 satisfied by design.

Note also `Machine.Value<Mode.Reference>.make<T: Sendable>` — Reference mode **requires Sendable payloads**. `Render.View` types carry no such constraint. `Mode.Unchecked` escapes it, at the price of surrendering the Sendable guarantee wholesale.

**Mismatch 3: Render produces no values at all.**

Machine's entire middle layer — `Transform.Erased`, `Combine.Erased`, `Next.Erased`, `Finalize.Array`, the `Value.Arena` and its ABA-guarded handles — exists to move **result values** between frames. Render's drain loop moves nothing:

```swift
mutating func _drain(above marker: Int) {
    while _stack.count > marker {
        let work = _stack.removeLast()
        switch work {
        case .render(let pointer, let thunk):
            unsafe thunk.dispatch(pointer, &self)
            unsafe thunk.destroy(pointer)
        case .action(let action):    interpret(action)
        case .frame(let frame):
            switch frame { case .closeScope(let action): interpret(action) }
        }
    }
}
```

Three cases, no value plumbing, no failure path, no checkpoint. Hosting this on Machine means instantiating `Failure = Never`, `Checkpoint = Never`, `Mode = Unchecked`, and leaving `.oneOf`/`.many`/`.fold`/`.optional`/`.ref`/`.hole` present-but-unreachable in a hot switch.

**Answer to (b):** the profiles do not reconcile. Hosting Render on Machine imposes a materialisation pass, per-value heap boxing, and runtime type checks on a path whose three governing constraints (R1, R2, R3) each independently forbid one of them. I did not measure, because the argument is structural and measurement would only price a change that is already ruled out on correctness grounds ([ARCH-LAYER-008]).

### (c) EFFECT — borrowing only the naming is a misuse; the answer is no

`Effect.perform.swift:1-4` is explicit that the implementation *"requires integration with a runtime layer that provides the suspension/resumption coordination"*; `Effect.Perform` is an empty marker enum. `Effect.Handler.Protocol.handle` is `async` and takes `consuming Effect.Continuation.One`. And as noted above, `Effect.Handler.Sync` is a typealias to that same async protocol — the package ships no synchronous handler shape.

So there are exactly two options, and both fail:

1. **Use the real protocols.** Every render backend becomes an `async` handler consuming a one-shot continuation. Rendering is synchronous; this is a non-starter.
2. **Borrow only the words.** Rename `Render.Action` → an "Effect", `Render.Context` → a "Handler". But a reader who knows `Effect.Handler` expects `handle(_:continuation:) async` and resumable control flow, and will find neither. Borrowing a vocabulary while discarding its semantics is *worse* than an honest new name, because it actively misleads. The scoping model differs too: `Effect.Context` is task-local storage over `Dependency.Scope`; `Render.Context` is a value threaded `inout` through a synchronous call tree. Same word, opposite mechanism.

**Answer to (c):** No. Effect cannot supply the vocabulary without the continuation machinery, and taking the vocabulary alone is a misuse.

### The naming question — the concept exists, it is called a **witness**, and Render.Context already is one

I claim no signature concept is needed. But the question deserves a direct answer rather than a dodge, so: **if one were needed, the non-invented name is not from universal algebra. It is `Witness`, and the ecosystem already owns it.**

`swift-witness-primitives` (L1) and `swift-witnesses` (L3) both exist. A "signature reified as a value — one operation per field, supplied by the domain" is precisely what the ecosystem calls a witness. And `Render.Context` **is** one: [API-IMPL-017] describes the migration that produced it as *"converting a protocol to a witness struct with stored closures,"* citing `Rendering.Context` by name.

So the universal-algebra framing would be both **over-abstraction** and **a synonym**: `Σ` for something already called a witness, `Σ-algebra` for something already called a witness *instance*, and "the unique homomorphism from the free algebra" for `_drain(above:)`. Under "no invented concepts at L1 — prefer an existing ecosystem name first," `Witness` wins outright and `Σ` never gets its turn. Introducing `Render.Signature` or `Render.Algebra` would also collide with [API-NAME-001a]: whatever nest held it would hold one type.

### The real defect: `swift-render-primitives` is one target fusing two semantic domains

Having refuted the merge, I owe a positive finding, and there is one — just not where I was pointed.

`Render Primitive` is a **single target** containing both:

| Domain-neutral composition | Document interpretation |
|---|---|
| `Render.Builder` | `Render.View`, `Render.Context` |
| `Render._Tuple`, `Render.Pair`, `Render.Conditional` | `Render.Action{,.Push,.Pop,.Break}` |
| `Render.Group`, `Render.Empty` | `Render.Push`, `Render.Pop`, `Render.Break` |
| `Render.Indirect` | `Render.Style`, `Render.Semantic.{Block,Inline,List}` |
| | `Render.Work`, `Render.Thunk`, `Render.Machine.Frame`, `Render.Speculative` |

The left column serves every render domain. The right column is one domain's vocabulary. They are two concepts in one target, which is exactly what [MOD-DOMAIN] asks about: *"Is this a concept, or just code?"* — and here there are two concepts.

The consequence is concrete and already being paid: `swift-svg-render` imports `Render_Primitives` to reach `Render.Builder` and `Render._Tuple`, and thereby links the entire document machine — `Render.Context`'s twelve stored closures, `Render.Action`, `Render.Thunk`, the LIFO drain loop — none of which it calls. Any future non-document domain (raster/video is the live motivating case) pays the same toll.

**Proposed split** — target boundaries only, no type renames:

- `Render Primitive` — `Render` namespace + composition: `Builder`, `_Tuple`, `Pair`, `Conditional`, `Group`, `Empty`, `Indirect`. Zero dependencies. This is the [MOD-017] singular root target holding namespace + foundational types.
- `Render Document Primitives` — `View`, `Context`, `Work`, `Thunk`, `Machine.Frame`, `Action.*`, `Push`, `Pop`, `Break`, `Style`, `Semantic.*`, `Speculative`, plus the `Render.View` conditional conformances on the composition types and on `Array`/`Optional`.
- `Render Primitives` — umbrella re-exporting both ([MOD-005]).

The `Render.View` conformances move to the document target. That is [MOD-004] constraint isolation working as intended, and needs no `@retroactive` since it is same-package ([API-IMPL-018]).

This is the [ARCH-LAYER-008] answer: the split is right because the target currently spans two domains, independent of how many consumers would benefit.

### On the motivating case (CoreImage-based declarative video)

The port does not need a Vocabulary parameter, a Leaf set, or a signature concept. It needs what SVG already does: its own `Raster.View` and `Raster.Context`, plus `typealias Builder = Render.Builder` and conditional conformances on the shared `Render._Tuple` / `Render.Conditional` / `Render.Pair`. That is the 2026-03-12 decision applied to a third domain. The target split above is what makes it cost one dependency instead of the whole document machine.

### On [ARCH-LAYER-009]'s two guards

My answer is **not** dissolution, so the committed-first and verified-dead guards are **not engaged** for `swift-render-primitives`. I state this explicitly because my brief asked me to name them if the answer were dissolution. They *would* apply to the target split only in the trivial sense that files move between targets within one package — no code is removed, so nothing needs to be proven dead.

### Agreements

(First round — none yet.)

### Concerns

1. **My own strongest counter-argument, which I want you to press.** The 2026-03-12 rationale for keeping SVG separate says forcing SVG through document methods *"would produce a meaningless mapping (what is `pushBlock(role: .paragraph)` for a circle?)"* — but that was written when `Rendering.Context` was a **15-method protocol**. It is now a **witness struct whose closures are almost all defaulted** (`Render.Context.swift:57-83`). Under a defaulted-closure witness, SVG would supply only `push.element(tagName:block:void:preformatted:)`, `set(attribute:)`, `text`, `write(raw:)` and leave the document closures as no-ops — and `<circle cx="10"/>` maps onto exactly that. **The old rationale may not survive the protocol→witness migration.** I now think SVG's real reason for separateness is different and narrower: `SVG.View._render` is generic over the output buffer (`into buffer: inout Buffer where Buffer.Element == UInt8`), whereas `Render.View._render` captures the buffer inside the context's closures. That is a genuine incompatibility, but it is a *plumbing* incompatibility, not a *vocabulary* one. If you think that is surmountable, the SVG-migration question is live and I want to hear it.

2. **The document types arguably overclaim the `Render` namespace**, by the same test I applied to `Machine`. `Render.Context`'s vocabulary is document structure; SVG and raster get their own. Should the right column become `Render.Document.View`, `Render.Document.Context`, and so on — leaving `Render.*` for what is genuinely shared? It passes [API-NAME-001a] (many types). It is a large rename across three L3 packages. Under [ARCH-LAYER-008] cost is not a reason to decline, but I am genuinely unsure whether it is *correct* or merely *symmetric*, and I have deliberately not asserted it.

3. **I have not measured anything.** My (b) argument is entirely structural. I judged measurement not worth its cost because the change is already excluded on correctness grounds, but if you think a measurement would change the answer rather than just price it, name the specific measurement.

4. **`Render.Context.apply(inlineStyle property: Any) -> Bool`** (`Render.Context.swift:121`) takes `Any`, in a package whose R2 forbids `Any`. It is a pre-existing escape hatch unrelated to this question, but I am flagging it rather than pretending the constraint set is perfectly upheld.

### Proposals

1. **Reject the merge.** `swift-render-primitives` does not dissolve into `swift-machine-primitives`. Grounds: (a) different essence, (b) three independently fatal shape mismatches.
2. **Reject the Effect naming borrow.** Grounds: (c) — the package ships no synchronous handler shape, and taking the words without the semantics misleads.
3. **Introduce no signature concept.** If one were ever needed the ecosystem name is `Witness`, not `Σ`; and `Render.Context` already is one.
4. **Split `Render Primitive` into a composition target and a document target**, with `Render Primitives` as umbrella. This is the actual correctness finding.
5. **Record separately** that `swift-machine-primitives`' name overclaims its essence ([ARCH-LAYER-010]). Not this session's decision to make, but it should not go unrecorded.
6. **Leave SVG alone pending Concern 1.** If the witness-struct migration really does dissolve the old rationale, that is a separate investigation with its own evidence bar.

### Questions

1. Do you accept that `Checkpoint` as a mandatory `Machine.Frame` parameter, plus `.oneOf`/`.many`/`.fold`/`.optional`/`.ref`/`.hole`, make Machine's node algebra a *parser* algebra rather than a neutral program algebra? If not, what would a genuinely neutral defunctionalized-program algebra look like, and how would it differ from what Machine has?
2. Is there a formulation of "host Render on Machine" that avoids `Machine.Value` entirely — i.e. a `Leaf` whose result type is `Void` and a `Mode` that skips the arena? If so, what would remain of Machine that Render would actually be *using*, beyond the node-graph storage it does not want?
3. On Concern 1: does the protocol→witness-struct migration invalidate the 2026-03-12 "SVG cannot use Rendering.Context" rationale? Is the buffer-genericity difference decisive, or is it plumbing?
4. On Concern 2: is `Render.Document.*` correct, or merely symmetric with my critique of `Machine`?
5. Have I mis-weighted anything by treating the R1/R2 constraint set as binding? Those constraints are the reason Machine's design is disqualified. If you think R2 in particular is over-strict for a rendering path, that is the single argument most likely to move my position.

### Status: EXPLORING
