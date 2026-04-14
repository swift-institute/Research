# Implementation: Rendering.Context Witness Migration — Phase 1 (Layer 1)

## Assignment

Convert `Rendering.Context` from a protocol to a hand-written witness struct in swift-rendering-primitives. Add `Rendering.Action` enum. Update all `_render` signatures. Update Property.View extensions. Update tests.

**This is Phase 1 of 4.** Only swift-rendering-primitives is modified. Downstream packages (HTML, PDF, etc.) are Phase 2–4.

**Quality bar**: This is timeless infrastructure. Every decision is permanent. Follow all Swift Institute conventions.

---

## What to Build

### 1. Replace `Rendering.Context` protocol with witness struct

**Current** (protocol, 262 lines): `https://github.com/swift-primitives/swift-rendering-primitives/blob/main/Sources/Rendering Primitives Core/Rendering.Context.swift`

**New** (witness struct with 24 stored closures):

```swift
extension Rendering {
    public struct Context: ~Copyable {
        // Leaf operations (5 required)
        public var text: (String) -> Void
        public var lineBreak: () -> Void
        public var thematicBreak: () -> Void
        public var image: (_ source: String, _ alt: String) -> Void
        public var pageBreak: () -> Void

        // Attribute operations (5, formerly optional with defaults)
        public var setAttribute: (_ name: String, _ value: String?) -> Void
        public var addClass: (String) -> Void
        public var writeRaw: ([UInt8]) -> Void
        public var registerStyle: (_ declaration: String, _ atRule: String?, _ selector: String?, _ pseudo: String?) -> String?
        public var applyInlineStyle: (Any) -> Bool

        // Push/pop operations (14 closures)
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
        public var pushElement: (_ tagName: String, _ isBlock: Bool, _ isVoid: Bool, _ isPreElement: Bool) -> Void
        public var popElement: (_ isBlock: Bool) -> Void
        public var pushStyle: () -> Void
        public var popStyle: () -> Void

        // Memberwise init (all 24 closures required)
    }
}
```

**Important**: The current protocol has `pushAttributes`/`popAttributes` and `_pushAttributes`/`_popAttributes`. Check the actual protocol for the complete list — don't miss any. Read the file first.

### 2. Property.View push/pop accessors

Replace the protocol-constrained extensions with concrete-type-constrained extensions:

```swift
// Before: protocol constraint
extension Property.View where Tag == Rendering.Push, Base: Rendering.Context & ~Copyable {
    public func block(role:style:) { unsafe Base._pushBlock(&base.pointee, role: role, style: style) }
}

// After: concrete type constraint
extension Property.View where Tag == Rendering.Push, Base == Rendering.Context {
    public func block(role:style:) { unsafe base.pointee.pushBlock(role, style) }
}
```

The `_read`/`_modify` coroutines on the Context struct:
```swift
extension Rendering.Context {
    public var push: Property<Rendering.Push, Rendering.Context>.View {
        mutating _read { yield unsafe Property<Rendering.Push, Rendering.Context>.View(&self) }
        mutating _modify {
            var view = unsafe Property<Rendering.Push, Rendering.Context>.View(&self)
            yield &view
        }
    }
    // Same for pop
}
```

Keep all existing push/pop method names exactly as they are. The validated experiment is at: `swift-institute/Experiments/rendering-witness-migration-blockers/Sources/Variants/Rendering.Context.swift`

### 3. Rendering.Action enum (nested Push/Pop)

New file: `Rendering.Action.swift`

```swift
extension Rendering {
    public enum Action: Sendable {
        case push(Push)
        case pop(Pop)
        case text(String)
        case lineBreak
        case thematicBreak
        case image(source: String, alt: String)
        case pageBreak
        case attribute(set: String, value: String?)
        case `class`(add: String)
        case raw([UInt8])
        case style(register: String, atRule: String?, selector: String?, pseudo: String?)
    }
}
```

New file: `Rendering.Action.Push.swift`

```swift
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
}
```

New file: `Rendering.Action.Pop.swift`

```swift
extension Rendering.Action {
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

### 4. Interpret method

On `Rendering.Context`:

```swift
extension Rendering.Context {
    @inlinable
    public mutating func interpret(_ action: Rendering.Action) {
        switch action {
        case .text(let content): text(content)
        case .lineBreak: lineBreak()
        // ... one case per action, dispatching to the corresponding closure
        case .push(let push):
            switch push {
            case .block(let role, let style): pushBlock(role, style)
            // ...
            }
        case .pop(let pop):
            switch pop {
            case .block: popBlock()
            // ...
            }
        }
    }

    @inlinable
    public mutating func interpret(_ actions: [Rendering.Action]) {
        for action in actions { interpret(action) }
    }
}
```

### 5. Update Rendering.View protocol

**Current**:
```swift
public protocol View: ~Copyable {
    associatedtype RenderBody: View & ~Copyable
    @Builder var body: RenderBody { get }
    static func _render<C: Context>(_ view: borrowing Self, context: inout C)
}
```

**New**:
```swift
public protocol View: ~Copyable {
    associatedtype RenderBody: View & ~Copyable
    @Builder var body: RenderBody { get }
    static func _render(_ view: borrowing Self, context: inout Context)
}
```

The generic `C` is gone. `Context` is the concrete witness struct.

**Default implementation**:
```swift
extension Rendering.View where RenderBody: Rendering.View {
    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) {
        RenderBody._render(view.body, context: &context)
    }
}
```

### 6. Update all L1 _render implementations

These files have `_render<C: Rendering.Context>` that must become `_render(context: inout Rendering.Context)`:

| File | Type |
|------|------|
| `Rendering.View.swift` | Default impl + Never conformance |
| `Rendering._Tuple.swift` | Variadic tuple |
| `Rendering.Conditional.swift` | If/else |
| `Rendering.Pair.swift` | Binary pair |
| `Rendering.ForEach.swift` | Collection iteration |
| `Rendering.Empty.swift` | No-op |
| `Array+Rendering.swift` | Array extension |
| `Optional+Rendering.swift` | Optional extension |

For each: change `<C: Rendering.Context>` → remove generic, change `context: inout C` → `context: inout Rendering.Context`, change any `C._pushBlock(&context, ...)` → `context.pushBlock(...)`.

### 7. Remove protocol default implementations

The current protocol has default implementations for optional methods (`set(attribute:)`, `add(class:)`, etc.). These become default parameter values or a convenience init on the struct. Provide a static `.noop` or similar for the operations that default to no-op.

### 8. Update test support

**Current**: `Tests/Support/Rendering Primitives Test Support.swift` has `RecordingContext: Rendering.Context` (protocol conformer).

**New**: Replace with a `Rendering.Context.recording(into:)` factory method:

```swift
extension Rendering.Context {
    public static func recording(into events: Ownership.Mutable<[Event]>) -> Self {
        // ... closures append Event cases to events.value
    }
}
```

Note: swift-rendering-primitives MAY NOT depend on swift-ownership-primitives currently. Check the Package.swift. If not, either add the dependency or use a local `final class` for the recording state. The actual production factories (in L3) will use `Ownership.Mutable`.

Also update the test leaf views (`TextLeaf`, `LineBreakLeaf`, `BlockWrapper`) and the `render()` helper function.

### 9. Update all tests

`Tests/Rendering Primitives Tests/` — update all test files to use the new API. The tests should validate:
- Leaf view _render
- Composite view body-based _render
- _Tuple rendering
- Optional rendering
- Array rendering
- Conditional rendering
- ForEach rendering
- Push/pop via Property.View accessors
- Action interpret

---

## Files to Modify

**Read ALL of these before making any changes:**

| File | Change |
|------|--------|
| `Sources/Rendering Primitives Core/Rendering.Context.swift` | Protocol → struct + Property.View accessors |
| `Sources/Rendering Primitives Core/Rendering.View.swift` | Remove `<C>` from _render |
| `Sources/Rendering Primitives Core/Rendering._Tuple.swift` | Remove `<C>` |
| `Sources/Rendering Primitives Core/Rendering.Conditional.swift` | Remove `<C>` |
| `Sources/Rendering Primitives Core/Rendering.Pair.swift` | Remove `<C>` |
| `Sources/Rendering Primitives Core/Rendering.ForEach.swift` | Remove `<C>` |
| `Sources/Rendering Primitives Core/Rendering.Empty.swift` | Remove `<C>` |
| `Sources/Rendering Primitives Core/Array+Rendering.swift` | Remove `<C>` |
| `Sources/Rendering Primitives Core/Optional+Rendering.swift` | Remove `<C>` |
| `Tests/Support/Rendering Primitives Test Support.swift` | RecordingContext → factory |
| `Tests/Rendering Primitives Tests/*.swift` | Update all tests |

**New files:**

| File | Contains |
|------|----------|
| `Sources/Rendering Primitives Core/Rendering.Action.swift` | Action enum |
| `Sources/Rendering Primitives Core/Rendering.Action.Push.swift` | Push cases |
| `Sources/Rendering Primitives Core/Rendering.Action.Pop.swift` | Pop cases |

---

## Constraints

1. **No Foundation** — this is Layer 1 primitives. [PRIM-FOUND-001]
2. **One type per file** — [API-IMPL-005]. The Action enum, Push, Pop each get their own file.
3. **Nested names** — [API-NAME-001]. `Rendering.Action.Push`, not `RenderingActionPush`.
4. **No compound identifiers** — [API-NAME-002]. Push/Pop cases use single words.
5. **Experimental features** — the package uses `Lifetimes`, `SuppressedAssociatedTypes`, `SuppressedAssociatedTypesWithDefaults`. Keep these.
6. **`~Copyable`** — the witness struct MUST be `~Copyable`.
7. **Property.View** — use `Property<Tag, Base>.View` from swift-property-primitives. Don't hand-roll accessor structs.
8. **`@inlinable`** — match the current inlining annotations. Property.View methods are `@inlinable`.
9. **`unsafe`** — Property.View accessors use `unsafe` for the pointer operations. Keep this.

---

## Validation

After all changes:

```bash
cd swift-rendering-primitives
swift build    # must succeed
swift test     # all tests must pass
```

**Also verify downstream packages still resolve** (they won't BUILD because their conformances are now invalid, but they should resolve dependencies):

```bash
cd swift-foundations
swift package resolve   # should not error on dependency resolution
```

---

## Reference: Validated Experiment

The exact pattern to follow is validated in:
`Experiments/rendering-witness-migration-blockers/`

This experiment has 24 passing tests covering: non-generic `_render` protocol requirement, Property.View with `Base == Rendering.Context`, AnyView existential opening, and tee transform. Use it as a reference for the exact syntax and patterns.

---

## Reference: Package.swift

The current Package.swift is at:
`https://github.com/swift-primitives/swift-rendering-primitives/blob/main/Package.swift`

Read it to understand dependencies, targets, and Swift settings before making changes.

---

## What NOT to Do

- Do NOT modify any file outside swift-rendering-primitives
- Do NOT add dependencies unless absolutely necessary (check if Ownership.Mutable is needed — if so, add swift-ownership-primitives dependency)
- Do NOT change the Rendering.Semantic types (Block, Inline, List) — they stay as-is
- Do NOT change the Rendering.Style type — it stays as-is
- Do NOT change the Rendering.Builder — it stays as-is
- Do NOT remove Rendering.Push and Rendering.Pop tag enums — they're used by Property.View
- Do NOT add the `@Witness` macro — this is hand-written Layer 1 code
- Do NOT create documentation files unless explicitly needed
