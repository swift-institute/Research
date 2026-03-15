# Implementation: Rendering.Context Witness Migration — Phase 2 (HTML Rendering)

## Assignment

Migrate swift-html-rendering from protocol-based `Rendering.Context` conformance to the witness-based architecture. Phase 1 (Layer 1) is complete — `Rendering.Context` is now a `~Copyable` witness struct with stored closures.

**This is Phase 2 of 4.** Only swift-html-rendering is modified.

**Quality bar**: Timeless infrastructure. Follow all Swift Institute conventions.

---

## What Changed in Phase 1

`Rendering.Context` is no longer a protocol. It's a `~Copyable` struct with 26 stored closures. The `_render` signature on `Rendering.View` is now:

```swift
static func _render(_ view: borrowing Self, context: inout Rendering.Context)
```

No generic `C` parameter. The concrete `Rendering.Context` struct carries its implementation as closures. Property.View push/pop accessors use `Base == Rendering.Context` constraint.

The new types are:
- `Rendering.Action` — enum with nested `Push`/`Pop`
- `Rendering.Context.interpret(_:)` — applies actions to the witness

**Read the Phase 1 code before starting**: `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/`

---

## What to Do

### 1. Remove `HTML.Context: Rendering.Context` conformance

**Current**: `HTML.Context.swift` has `extension HTML.Context: Rendering.Context { ... }` implementing ~23 protocol methods.

**New**: The conformance declaration is removed. The methods STAY on `HTML.Context` as regular methods (same implementations, just no protocol conformance). They're called by the factory closures.

### 2. Add `Rendering.Context.html(state:)` factory

The factory creates a `Rendering.Context` witness whose closures forward to `HTML.Context` methods. State is captured via `Ownership.Mutable<HTML.Context>` (from swift-ownership-primitives, Layer 1).

```swift
extension Rendering.Context {
    public static func html(state: Ownership.Mutable<HTML.Context>) -> Self {
        .init(
            text: { state.value.text($0) },
            lineBreak: { state.value.lineBreak() },
            // ... forward all 26 operations to HTML.Context methods
            pushBlock: { role, style in
                HTML.Context._pushBlock(&state.value, role: role, style: style)
            },
            popBlock: { HTML.Context._popBlock(&state.value) },
            // ...
        )
    }
}
```

Check if swift-html-rendering already depends on swift-ownership-primitives. If not, add the dependency in Package.swift.

**Important**: The current `HTML.Context` has methods that were protocol requirements AND additional methods that were NOT protocol requirements (like `writeOpeningTag`, `writeClosingTag`, `escapeAttributeValue`, `stylesheetBytes`). Only the 26 protocol-method closures go in the factory. The additional methods stay on `HTML.Context` as they are.

### 3. Update all `_render<C: Rendering.Context>` methods (8 files)

Each `_render` method drops its generic parameter:

```swift
// Before
public static func _render<C: Rendering.Context>(
    _ view: borrowing Self, context: inout C
) { ... }

// After
public static func _render(
    _ view: borrowing Self, context: inout Rendering.Context
) { ... }
```

Inside the methods, change any `C._pushBlock(&context, ...)` to `context.pushBlock(...)` (direct closure call instead of static protocol dispatch).

**Files with _render methods:**

| File | Type |
|------|------|
| `HTML.AnyView.swift` | `_render` + `_openAndRender` helper |
| `HTML.Document.Protocol.swift` | `_render` (generic) + `_renderHTMLDocument` (concrete) |
| `HTML.Element.swift` | `HTML.Element.Tag._render` |
| `HTML.Styled.swift` | `HTML.Styled._render` |
| `HTML.Text.swift` | `HTML.Text._render` |
| `HTML.Raw.swift` | `HTML.Raw._render` |
| `HTML._Attributes.swift` | `HTML._Attributes._render` |

**Special case — HTML.AnyView**:

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

The `V` existential opening stays — only `C` is removed.

**Special case — HTML.Document.Protocol**:

This has TWO render paths:
1. `_render<C: Rendering.Context>` — generic, for foreign contexts → becomes `_render(context: inout Rendering.Context)`
2. `_renderHTMLDocument` — concrete, for HTML output with two-phase style collection

The two-phase rendering changes:

```swift
// Before
var bodyContext = HTML.Context(configuration)
RenderBody._render(html.body, context: &bodyContext)

// After
let bodyState = Ownership.Mutable(HTML.Context(configuration))
var bodyContext = Rendering.Context.html(state: bodyState)
RenderBody._render(html.body, context: &bodyContext)
let bodyBytes = bodyState.value.bytes
// styles from bodyState.value.styles
```

### 4. Update Property.View accessor calls

Calls like `context.push.element(tagName:block:void:preformatted:)` should still work — the Property.View extensions are now on `Base == Rendering.Context` instead of `Base: Rendering.Context & ~Copyable`. The call-site syntax is identical. Verify they compile.

If any call uses `C._pushBlock` directly (static protocol dispatch), change to `context.pushBlock(...)`.

### 5. ~300 HTML element files — DO NOT MODIFY

The ~300 files in `HTML Attributes Rendering/` and `HTML Elements Rendering/` use `var body: some HTML.View` with the default `_render` implementation. They do NOT mention `Rendering.Context` directly. They should compile unchanged because:
- `HTML.View` still refines `Rendering.View`
- The default `_render` is now `_render(_ view: Self, context: inout Rendering.Context)` — provided by the protocol extension in L1
- Their `body` property type (`some HTML.View`) still satisfies `RenderBody: Rendering.View`

If any of these files fail to compile, investigate — it likely means they have an explicit `_render<C>` override that needs updating.

### 6. HTML.View protocol — check refinement

```swift
// Current (should still work)
public protocol View: Rendering.View where RenderBody: HTML.View {
    @HTML.Builder var body: RenderBody { get }
}
```

This should compile unchanged. `Rendering.View` now has `_render(_ view: Self, context: inout Rendering.Context)` instead of `_render<C>(...)`. The refinement relationship is unaffected. Verify.

---

## Files to Read Before Starting

| File | Why |
|------|-----|
| `swift-rendering-primitives/.../Rendering.Context.swift` | The new witness struct (Phase 1 output) |
| `swift-rendering-primitives/.../Rendering.View.swift` | The new _render signature |
| `swift-html-rendering/.../HTML.View.swift` | Refinement of Rendering.View |
| `swift-html-rendering/.../HTML.Context.swift` | The conformance to migrate (~633 lines) |
| `swift-html-rendering/.../HTML.AnyView.swift` | Existential opening pattern |
| `swift-html-rendering/.../HTML.Document.Protocol.swift` | Two-phase rendering |
| `swift-html-rendering/.../HTML.Element.swift` | Element tag rendering |
| `swift-html-rendering/.../HTML.Styled.swift` | CSS styled wrapper |
| `swift-html-rendering/Package.swift` | Dependencies |

---

## Validation

```bash
cd /Users/coen/Developer/swift-foundations/swift-html-rendering
swift build    # must succeed
swift test     # all tests must pass
```

Also verify that packages depending on swift-html-rendering can still resolve:

```bash
cd /Users/coen/Developer/swift-foundations/swift-markdown-html-rendering
swift package resolve
```

(It won't build yet — markdown has its own migration in Phase 4 — but resolution should work.)

---

## Constraints

- **Only modify swift-html-rendering** — do not touch swift-rendering-primitives or other packages
- **[API-IMPL-005]** one type per file — the factory extension can go in a new file `Rendering.Context+HTML.swift` or in `HTML.Context.swift`
- **[API-NAME-001]** `Rendering.Context.html(state:)` — correct namespace nesting
- Follow the exact patterns from the validated experiment: `/Users/coen/Developer/swift-institute/Experiments/rendering-witness-migration-blockers/`
- If `Ownership.Mutable` is needed, add swift-ownership-primitives as a dependency
- The `HTML.Context` type itself does NOT change shape — it keeps all its stored properties and methods. Only the protocol conformance is removed and a factory is added.

---

## What NOT to Do

- Do NOT modify any file outside swift-html-rendering
- Do NOT touch the ~300 HTML element/attribute files unless they fail to compile
- Do NOT remove methods from HTML.Context — they stay as regular methods
- Do NOT change HTML.Builder — it stays as-is
- Do NOT add `@Witness` macro usage
