# swift-render-primitives

## Package Manifest

// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "swift-render-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        // MARK: - Namespace
        .library(
            name: "Render Primitive",
            targets: ["Render Primitive"]
        ),
        // MARK: - Umbrella
        .library(
            name: "Render Primitives",
            targets: ["Render Primitives"]
        ),
        .library(
            name: "Render Primitives Test Support",
            targets: ["Render Primitives Test Support"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        // MARK: - Namespace
        .target(
            name: "Render Primitive",
            dependencies: []
        ),

        // MARK: - Umbrella
        .target(
            name: "Render Primitives",
            dependencies: [
                "Render Primitive",
            ]
        ),
        .target(
            name: "Render Primitives Test Support",
            dependencies: [
                "Render Primitives",
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Render Primitives Tests",
            dependencies: [
                "Render Primitives",
                "Render Primitives Test Support",
            ],
            path: "Tests/Render Primitives Tests"
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}

## File Structure

~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Array+Render.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Optional+Render.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Action.Break.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Action.Pop.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Action.Push.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Action.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Break.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Builder.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Conditional.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Context.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Empty.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Group.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Indirect.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Machine.Frame.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Machine.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Pair.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Pop.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Push.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Semantic.Block.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Semantic.Inline.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Semantic.List.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Semantic.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Speculative.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Style.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Thunk.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.View.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.Work.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render._Tuple.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitive/Render.swift
~/Developer/swift-primitives/swift-render-primitives/Sources/Render Primitives/exports.swift

## Source Files

### File: Sources/Render Primitive/Array+Render.swift

extension Array: Render.View where Element: Render.View {
    /// The body type of this leaf conformance, which never produces nested content.
    public typealias Body = Never

    /// Unreachable: rendering of an array is dispatched through `_render`.
    public var body: Never { fatalError("Array has no body; rendering is performed by _render") }

    /// Renders each element in order.
    public static func _render(
        _ view: borrowing Self,
        context: inout Render.Context
    ) {
        let marker = context._stackDepth
        let copy = copy view
        for element in copy {
            let pointer = UnsafeMutablePointer<Element>.allocate(capacity: 1)
            unsafe pointer.initialize(to: element)
            unsafe context._stack.append(
                .render(
                    pointer: UnsafeMutableRawPointer(pointer),
                    thunk: Render.Thunk(Element.self)
                )
            )
        }
        context._reverseAbove(marker)
    }
}

### File: Sources/Render Primitive/Optional+Render.swift

extension Optional: Render.View where Wrapped: Render.View {
    /// The body type of this leaf conformance, which never produces nested content.
    public typealias Body = Never

    /// Unreachable: rendering of an optional is dispatched through `_render`.
    public var body: Never { fatalError("Optional has no body; rendering is performed by _render") }

    /// Renders the wrapped view when present, or nothing when `nil`.
    public static func _render(
        _ view: borrowing Self,
        context: inout Render.Context
    ) {
        let copy = copy view
        switch copy {
        case .some(let wrapped): Wrapped._render(wrapped, context: &context)
        case .none: break
        }
    }
}

### File: Sources/Render Primitive/Render.Action.Break.swift

extension Render.Action {
    /// Break action variants.
    public enum Break: Sendable {
        case line
        case thematic
        case page
    }
}

### File: Sources/Render Primitive/Render.Action.Pop.swift

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

### File: Sources/Render Primitive/Render.Action.Push.swift

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

### File: Sources/Render Primitive/Render.Action.swift

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

### File: Sources/Render Primitive/Render.Break.swift

extension Render {
    /// Break operations for rendering contexts.
    ///
    ///     ctx.`break`.line()
    ///     ctx.`break`.thematic()
    ///     ctx.`break`.page()
    public struct Break {
        @usableFromInline var _line: () -> Void
        @usableFromInline var _thematic: () -> Void
        @usableFromInline var _page: () -> Void

        /// Creates a break handler from one closure per break kind.
        @inlinable
        public init(
            line: @escaping () -> Void,
            thematic: @escaping () -> Void,
            page: @escaping () -> Void
        ) {
            self._line = line
            self._thematic = thematic
            self._page = page
        }

        /// Emits a line break.
        @inlinable public func line() { _line() }

        /// Emits a thematic break (a horizontal divider between sections).
        @inlinable public func thematic() { _thematic() }

        /// Emits a page break.
        @inlinable public func page() { _page() }
    }
}

### File: Sources/Render Primitive/Render.Builder.swift

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

### File: Sources/Render Primitive/Render.Conditional.swift

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

### File: Sources/Render Primitive/Render.Context.swift

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

### File: Sources/Render Primitive/Render.Empty.swift

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

### File: Sources/Render Primitive/Render.Group.swift

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

### File: Sources/Render Primitive/Render.Indirect.swift

extension Render {
    /// Heap-allocated content wrapper that keeps structural view types at
    /// constant size regardless of content complexity.
    ///
    /// Prevents stack overflow during `body.getter` evaluation on the
    /// cooperative thread pool (544 KB) by breaking quadratic type-size
    /// growth in nested modifier chains. Each `Indirect` reference is
    /// 8 bytes on the stack; the wrapped value lives on the heap.
    ///
    /// ## Usage
    ///
    /// Structural views that wrap content (modifiers, attribute containers)
    /// store their content via `Indirect` instead of inline:
    ///
    ///     struct Styled<Content: Render.View> {
    ///         let content: Render.Indirect<Content>  // 8 bytes, always
    ///         // ... modifier properties ...
    ///     }
    ///
    /// This bounds per-level type size to a constant, regardless of how
    /// deeply views are nested. ARC handles lifetime automatically.
    /// ## Safety Invariant
    ///
    /// `Render.Indirect` holds an immutable `let value: Content`.
    /// `~Copyable` generic in class storage blocks structural Sendable inference.
    /// The value is immutable after construction — no shared mutation risk
    /// *when `Content` is itself `Sendable`* — see ``Non-Goals``.
    ///
    /// ## Intended Use
    ///
    /// - Heap-indirecting a rendering view to bound per-level type size.
    ///
    /// ## Non-Goals
    ///
    /// - Does not support mutation after construction.
    /// - `Indirect<Content>` is **not** `Sendable` when `Content` is not
    ///   `Sendable`. The conformance below is conditional precisely so that
    ///   wrapping a non-`Sendable` (e.g. mutable-reference-holding) value in
    ///   `Indirect` cannot be used to smuggle it across an isolation boundary.
    ///   An unconditional `@unchecked Sendable` here would defeat the
    ///   compiler's data-race checking for every `Content` type, checked or
    ///   not — that was the bug this conditional conformance fixes.
    public final class Indirect<Content: ~Copyable> {
        /// The heap-stored content value, immutable after construction.
        public let value: Content

        /// Creates an indirection by moving `value` onto the heap.
        @inlinable
        public init(_ value: consuming Content) { self.value = value }
    }
}

// MARK: - Sendable

extension Render.Indirect: @unsafe @unchecked Sendable where Content: Sendable & ~Copyable {}

### File: Sources/Render Primitive/Render.Machine.Frame.swift

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

### File: Sources/Render Primitive/Render.Machine.swift

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

### File: Sources/Render Primitive/Render.Pair.swift

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

### File: Sources/Render Primitive/Render.Pop.swift

extension Render {
    /// Pop operations for structured rendering contexts.
    ///
    ///     ctx.pop.block()
    ///     ctx.pop.inline()
    ///     ctx.pop.link()
    public struct Pop {
        @usableFromInline var _block: () -> Void
        @usableFromInline var _inline: () -> Void
        @usableFromInline var _list: () -> Void
        @usableFromInline var _item: () -> Void
        @usableFromInline var _link: () -> Void
        @usableFromInline var _attributes: () -> Void
        @usableFromInline var _element: (_ isBlock: Bool) -> Void
        @usableFromInline var _style: () -> Void

        /// Creates a pop handler from one closure per structured close operation.
        @inlinable
        public init(
            block: @escaping () -> Void,
            inline: @escaping () -> Void,
            list: @escaping () -> Void,
            item: @escaping () -> Void,
            link: @escaping () -> Void,
            attributes: @escaping () -> Void = {},
            element: @escaping (_ isBlock: Bool) -> Void = { _ in },
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

        /// Closes the current block-level container.
        @inlinable public func block() { _block() }

        /// Closes the current inline-level container.
        @inlinable public func inline() { _inline() }

        /// Closes the current list.
        @inlinable public func list() { _list() }

        /// Closes the current list item.
        @inlinable public func item() { _item() }

        /// Closes the current hyperlink.
        @inlinable public func link() { _link() }

        /// Closes the current attribute scope.
        @inlinable public func attributes() { _attributes() }

        /// Closes the current raw element, indicating whether it was block-level.
        @inlinable public func element(block isBlock: Bool) { _element(isBlock) }

        /// Closes the current style scope.
        @inlinable public func style() { _style() }
    }
}

### File: Sources/Render Primitive/Render.Push.swift

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

### File: Sources/Render Primitive/Render.Semantic.Block.swift

extension Render.Semantic {
    /// Block-level semantic roles.
    public enum Block: Sendable {
        case heading(level: Int)
        case paragraph
        case blockquote
        case section
        case pre
        case table
        case row
        case cell(header: Bool)
    }
}

### File: Sources/Render Primitive/Render.Semantic.Inline.swift

extension Render.Semantic {
    /// Inline semantic roles.
    public enum Inline: Sendable {
        case emphasis
        case strong
        case code
    }
}

### File: Sources/Render Primitive/Render.Semantic.List.swift

extension Render.Semantic {
    /// List kind indicators.
    public enum List: Sendable {
        case ordered
        case unordered
    }
}

### File: Sources/Render Primitive/Render.Semantic.swift

extension Render {
    /// Namespace for semantic role types used by `Render.Context`.
    public enum Semantic {}
}

### File: Sources/Render Primitive/Render.Speculative.swift

extension Render {
    /// Speculative rendering operations.
    ///
    /// Speculative rendering allows backends to snapshot state, render
    /// content tentatively, and roll back if it doesn't fit (e.g., keeping
    /// a heading with its following paragraph on the same page).
    ///
    ///     ctx.speculative.begin()
    ///     ctx.speculative.check(fit: 100)
    public struct Speculative {
        @usableFromInline var _begin: () -> Void
        @usableFromInline var _check: (_ minimumRequired: Int) -> Void

        /// Creates a speculative handler from snapshot and fit-check closures.
        @inlinable
        public init(
            begin: @escaping () -> Void = {},
            check: @escaping (_ minimumRequired: Int) -> Void = { _ in }
        ) {
            self._begin = begin
            self._check = check
        }

        /// Snapshots the current backend state so it can be rolled back later.
        @inlinable public func begin() { _begin() }

        /// Checks whether at least `minimumRequired` space remains, rolling back if not.
        @inlinable public func check(fit minimumRequired: Int) { _check(minimumRequired) }
    }
}

### File: Sources/Render Primitive/Render.Style.swift

extension Render {
    /// Format-independent style hints for rendered content.
    public struct Style: Sendable {
        /// The font hints applied to the content.
        public var font: Font

        /// The foreground color hint, or `nil` to inherit.
        public var color: Color?

        /// The outer margin hint in points, or `nil` to inherit.
        public var margin: Float?

        /// Typeface hints: size and weight.
        public struct Font: Sendable {
            /// The font size hint in points, or `nil` to inherit.
            public var size: Float?

            /// The font weight hint, or `nil` to inherit.
            public var weight: Weight?

            /// The boldness of a font.
            public enum Weight: Sendable { case normal, bold }

            /// Creates font hints from an optional size and weight.
            public init(size: Float? = nil, weight: Weight? = nil) {
                self.size = size
                self.weight = weight
            }
        }

        /// A small palette of foreground colors.
        public enum Color: Sendable { case black, red, blue, gray }

        /// A style carrying no hints, leaving every attribute to be inherited.
        public static let empty = Self()

        /// Creates a style from optional font, color, and margin hints.
        public init(
            font: Font = Font(),
            color: Color? = nil,
            margin: Float? = nil
        ) {
            self.font = font
            self.color = color
            self.margin = margin
        }
    }
}

### File: Sources/Render Primitive/Render.Thunk.swift

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

### File: Sources/Render Primitive/Render.View.swift

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

### File: Sources/Render Primitive/Render.Work.swift

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

### File: Sources/Render Primitive/Render._Tuple.swift

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

### File: Sources/Render Primitive/Render.swift

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

### File: Sources/Render Primitives/exports.swift

@_exported public import Render_Primitive
