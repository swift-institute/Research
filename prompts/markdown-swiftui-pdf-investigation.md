# Investigation: Markdown + SwiftUI Preview + PDF Pipeline

## Status

**Date**: 2026-03-13
**Priority**: HIGH — blocks all SwiftUI previews in swift-markdown-html-rendering and any package using `HTML.Document` in `#Preview`
**Packages affected**: swift-html-rendering, swift-markdown-html-rendering, swift-pdf, coenttb/swift-markdown-html-rendering

---

## Context

### What was accomplished

1. **`Markdown { ... }` syntax** — DONE, compiles, tested.
   `Markdown` was changed from `public enum` (caseless namespace) to `public struct` conforming to `HTML_Renderable.HTML.View`. This enables:
   ```swift
   // Before — verbose two-step
   Markdown.HTML { "# Hello" }

   // After — direct
   Markdown { "# Hello" }

   // With configuration
   Markdown(configuration: custom) { "# Hello" }

   // In PDF context — the goal
   PDF.Document(...) {
       Markdown { "# Hello World" }
   }
   ```
   The struct stores the markdown string and configuration, delegates to `Markdown.HTML.callAsFunction` in its `body`. All nested types (`Markdown.HTML`, `Markdown.HTML.Builder`, `Markdown.HTML.Configuration`, `Markdown.HTML.Section`) continue to work.

2. **swift-pdf tests pass** — 3/3 tests using the new `Markdown { ... }` syntax inside `PDF.Document { ... }` builders.

3. **Main module builds** — `swift build --target "Markdown HTML Rendering"` succeeds in foundations.

### What is blocked

**SwiftUI previews don't compile** in the `Markdown Previews` target. Every `#Preview` that uses `HTML.Document { ... }` fails with:
```
error: type of expression is ambiguous without a type annotation
```

The root cause: `HTML.Document` does not conform to `SwiftUI.View`. The `#Preview` macro requires the closure body to return a `SwiftUI.View`.

### The coenttb solution that works (without MemberImportVisibility)

The coenttb/swift-html-rendering donor repo has a file `Sources/HTML Renderable/HTML.Document+ViewRepresentable.swift` that adds SwiftUI conformance via `NSViewRepresentable`/`UIViewRepresentable` (WKWebView-based). This works in the coenttb repo because **it does NOT have `MemberImportVisibility` enabled**.

### Why it fails in foundations

The foundations version of swift-html-rendering has these ecosystem Swift settings applied to all non-test targets:
```swift
.enableUpcomingFeature("ExistentialAny"),
.enableUpcomingFeature("InternalImportsByDefault"),
.enableUpcomingFeature("MemberImportVisibility"),
.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
```

**MemberImportVisibility** (SE-0409) changes import scoping: `public import SwiftUI` in ANY file of a module makes SwiftUI symbols visible in ALL files of that module. This causes a fatal conflict:

`HTML.Document` (in `HTML.Document.swift`) has:
```swift
public struct Document<Body: HTML.View, Head: HTML.View>: HTML.DocumentProtocol {
    public let head: Head
    public let body: Body  // ← stored property, satisfies HTML.View.body
}
```

`SwiftUI.View` requires:
```swift
associatedtype Body: View
var body: Body { get }
```

When `public import SwiftUI` is visible module-wide, the compiler sees `HTML.Document.body` and tries to determine which protocol requirement it satisfies — `HTML.View.body` or `SwiftUI.View.body`. It can't resolve the ambiguity.

Specifically, the compiler error chain is:
```
HTML.Document.swift:30: error: type 'WHATWG_HTML.Document<Body, Head>' does not conform to protocol 'WHATWG_HTML.View'
```
And the notes reveal:
```
note: possibly intended match 'WHATWG_HTML.Document<Body, Head>.Body' (aka 'Body') does not conform to 'View'
note: protocol requires nested type 'Body'
```

The compiler is trying to use `HTML.Document`'s generic parameter `Body` (which conforms to `HTML.View`, not `SwiftUI.View`) to satisfy `SwiftUI.View.Body`. This fails, AND it prevents the stored property from satisfying `HTML.View.body` too — deadlock.

---

## Approaches Tried (All Failed)

### Approach 1: Bridge file in same module (HTML Renderable)

**File**: `Sources/HTML Renderable/HTML.Document+ViewRepresentable.swift`

```swift
#if canImport(SwiftUI)
@preconcurrency public import SwiftUI
public import WebKit

#if os(macOS)
extension HTML.Document: SwiftUI.View where Body: HTML.View, Head: HTML.View {}
extension HTML.Document: SwiftUI.NSViewRepresentable where Body: HTML.View, Head: HTML.View {
    public typealias NSViewType = WKWebView
    public func makeNSView(context: ...) -> WKWebView { ... }
    public func updateNSView(_ webView: ..., context: ...) { ... }
}
#endif
#endif
```

**Result**: FAILED — `public import SwiftUI` leaks `SwiftUI.View` to all files via MemberImportVisibility. The `body` property in `HTML.Document.swift` can no longer cleanly satisfy `HTML.View.body`.

**Variant — `internal import`**: Also fails because the conformance is `public` (it must be, since `HTML.Document` is public), and Swift requires the protocol to be at least as visible as the conformance: `"cannot use protocol 'View' in a public or '@usableFromInline' conformance; 'SwiftUICore' was not imported publicly"`.

### Approach 2: Separate target in same package (HTML SwiftUI)

**Structure**: New target `HTML SwiftUI` in swift-html-rendering with its own source directory. Depends on `HTML Renderable`. Has `public import SwiftUI`.

**Result**: FAILED — Two issues:
1. `@retroactive` can't be used: `"'retroactive' attribute does not apply; 'Document' is declared in the same package"`
2. Even without `@retroactive`, the same `body` conflict: `"type 'WHATWG_HTML.Document<Body, Head>' does not conform to protocol 'View'"`. The compiler evaluates ALL conformances of a type across all modules in the same package. The stored `body: Body` property interferes with `SwiftUI.View.Body` resolution.

### Approach 3: Wrapper view (HTMLPreview)

A `MarkdownPreview` or `HTMLPreview` SwiftUI view that wraps HTML rendering in a WKWebView, used in `#Preview` blocks instead of `HTML.Document`.

**Result**: Works technically, but the user rejected this approach — `HTML.Document` should work directly in previews, not through a wrapper.

---

## Approaches NOT Yet Tried

### Approach 4: Separate PACKAGE for the SwiftUI bridge

Put the bridge in a completely separate Swift package (not just a separate target). This creates a true module boundary. The package would depend on swift-html-rendering.

**Hypothesis**: A separate package means `HTML.Document` is a foreign type. The compiler processes conformances declared in separate packages independently. The `@retroactive` attribute would be valid (different package). The `body` property conflict might be resolved because the compiler knows the stored property satisfies the original module's `HTML.View.body`, and `NSViewRepresentable` provides the default `SwiftUI.View.body`.

**Risk**: Even across packages, the compiler may still see the same conflict when evaluating the retroactive conformance. Needs empirical verification.

**Suggested experiment**: `swift-institute/Experiments/html-document-swiftui-bridge/`

### Approach 5: Rename the stored `body` property

Change `HTML.Document`'s stored property from `body` to `content` or `htmlBody`, and provide a computed `body` that returns it for `HTML.View` conformance. This eliminates the name collision entirely.

```swift
public struct Document<Body: HTML.View, Head: HTML.View>: HTML.DocumentProtocol {
    public let head: Head
    public let content: Body  // renamed from 'body'

    public var body: Body { content }  // satisfies HTML.View.body
}
```

Then the SwiftUI bridge can live in the same module because `NSViewRepresentable` provides its own `body` for `SwiftUI.View`, and there's no stored property shadowing it.

**Risk**: Breaking change for any code that accesses `document.body` directly. Need to audit all consumers. Also, `Rendering.View` protocol requires `@Builder var body: Body { get }` — need to verify a computed property satisfies the builder attribute requirement.

**Suggested experiment**: `swift-institute/Experiments/rendering-view-body-rename/`

### Approach 6: Conditional conformance via `#if` per-file without MemberImportVisibility

Disable MemberImportVisibility for ONLY the `HTML Renderable` target (or the bridge file). This is the approach the coenttb version implicitly uses.

**Implementation**: Modify the Package.swift loop to skip `HTML Renderable`:
```swift
for target in package.targets where ... && target.name != .htmlRenderable {
```

**Risk**: Inconsistency — one target in the package doesn't follow ecosystem conventions. Also, if other targets depend on `HTML Renderable` and import it, they may have their own MemberImportVisibility interactions.

**Alternative**: Remove MemberImportVisibility from ALL targets in swift-html-rendering. This is pragmatic since the package is at Layer 3 (foundations) where it's "discouraged but not forbidden."

### Approach 7: Explicit protocol witness disambiguation

Add an explicit typealias or associated type binding to tell the compiler which `Body` and `body` satisfy which protocol.

```swift
extension HTML.Document: SwiftUI.View where Body: HTML.View, Head: HTML.View {
    // Explicitly bind SwiftUI.View.Body to the NSViewRepresentable-provided type
    // This may require a concrete Never-based type or _ViewRepresentableBody
}
```

**Risk**: SwiftUI's `NSViewRepresentable` provides the `Body` type internally. We may not be able to explicitly bind it. Needs investigation of SwiftUI's protocol witness table structure.

### Approach 8: Module selector (SE-0491)

The `SwiftMarkdown.swift` file already references SE-0491 (Module Selectors) as a future fix:
```swift
// TODO: Remove once SE-0491 (Module Selectors) lands
// https://forums.swift.org/t/se-0491-module-selectors-for-name-disambiguation/82124
```

If SE-0491 lands, it could help disambiguate `HTML.View` vs `SwiftUI.View` at the conformance site. But this is a future language feature and not available today.

### Approach 9: Intermediate wrapper type

Instead of conforming `HTML.Document` directly to `SwiftUI.View`, create a wrapper:
```swift
public struct HTMLDocumentView<Body: HTML.View, Head: HTML.View>: SwiftUI.View {
    let document: HTML.Document<Body, Head>

    public var body: some SwiftUI.View {
        WebViewRepresentable(document: document)
    }
}

extension HTML.Document where Body: HTML.View, Head: HTML.View {
    public var swiftUIView: HTMLDocumentView<Body, Head> {
        HTMLDocumentView(document: self)
    }
}
```

Usage: `#Preview { HTML.Document { ... }.swiftUIView }`

**Risk**: The user wanted `HTML.Document` to work directly. But `.swiftUIView` is a small ergonomic cost. This avoids the protocol conflict entirely.

---

## Experiment Plan

### Experiment 1: Cross-package retroactive SwiftUI conformance

**Location**: `swift-institute/Experiments/html-document-swiftui-bridge/`
**Hypothesis**: A retroactive `SwiftUI.View` conformance on `HTML.Document` from a SEPARATE package avoids the `body` property conflict that occurs within the same package.
**Method**: Create a minimal experiment with:
- Package A: defines `struct Foo<Body: SomeProtocol> { let body: Body }` with `SomeProtocol` having a `body` requirement (mirroring `HTML.View`)
- Package B: depends on Package A, adds `@retroactive SwiftUI.View` conformance to `Foo` via `NSViewRepresentable`
- Build with MemberImportVisibility enabled in both packages
**Variants**:
- V1: Minimal — stored `body` property + `NSViewRepresentable` conformance from separate package
- V2: With `Rendering.View` protocol chain (mirroring the actual `HTML.View: Rendering.View` hierarchy)
- V3: With `@Builder` attribute on the `body` requirement (mirroring `@HTML.Builder var body: Body { get }`)

### Experiment 2: Stored property rename feasibility

**Location**: `swift-institute/Experiments/rendering-view-body-rename/`
**Hypothesis**: Renaming `HTML.Document.body` to `HTML.Document.content` (with a computed `body` property) allows both `HTML.View` and `SwiftUI.View` conformances in the same module.
**Method**: Create a minimal experiment with:
- A type with stored `content` property and computed `body: Content { content }`
- Conform to both a custom `View` protocol (with `body` requirement) and `SwiftUI.View` (via `NSViewRepresentable`)
- Enable MemberImportVisibility
**Variants**:
- V1: Basic rename — does the computed property satisfy `@Builder var body: Body { get }`?
- V2: With result builder — does `@HTML.Builder var body: Body` work with a computed property forwarding to a stored property?
- V3: Full chain — `Rendering.View.body` → `HTML.View.body` → `SwiftUI.View.body`

### Experiment 3: MemberImportVisibility interaction deep-dive

**Location**: `swift-institute/Experiments/member-import-visibility-body-conflict/`
**Hypothesis**: The `body` conflict only occurs when `public import SwiftUI` makes `SwiftUI.View` visible in the file where the stored `body` property is declared. With `internal import`, the conflict doesn't occur — but `internal import` prevents public conformances.
**Method**: Systematically test every import visibility level:
- V1: `public import SwiftUI` in same file as stored property — expect conflict
- V2: `public import SwiftUI` in different file, same module, with MemberImportVisibility — expect conflict
- V3: `public import SwiftUI` in different file, same module, WITHOUT MemberImportVisibility — expect success (this is the coenttb case)
- V4: `internal import SwiftUI` in same file, conformance marked `package` instead of `public` — test if package visibility works
- V5: `package import SwiftUI` — test if package import avoids the leak while allowing conformance

### Experiment 4: Protocol witness table with NSViewRepresentable

**Location**: `swift-institute/Experiments/nsviewrepresentable-body-witness/`
**Hypothesis**: `NSViewRepresentable` provides a default `body` implementation for `SwiftUI.View`. When a type has a stored `body` property of a non-SwiftUI type AND conforms to `NSViewRepresentable`, the compiler should prefer the `NSViewRepresentable`-provided `body` for `SwiftUI.View` and the stored property for other protocols.
**Method**: Create a minimal experiment:
```swift
protocol CustomView {
    associatedtype Body: CustomView
    var body: Body { get }
}

struct MyDoc<B: CustomView>: CustomView {
    let body: B  // satisfies CustomView.body
}

// In a file with public import SwiftUI:
extension MyDoc: NSViewRepresentable where B: CustomView {
    typealias NSViewType = NSView
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
```
**Variants**:
- V1: Minimal — custom protocol + SwiftUI.View via NSViewRepresentable
- V2: With `associatedtype Body` name collision (both protocols use `Body`)
- V3: With generic parameter named `Body` (the actual HTML.Document case)
- V4: With `@resultBuilder` on the custom protocol's `body` requirement

---

## File Inventory

### Files already changed (uncommitted, working)

**swift-markdown-html-rendering (foundations)**:
- `Sources/Markdown HTML Rendering/Markdown.HTML.swift` — `enum Markdown` → `struct Markdown: HTML_Renderable.HTML.View`
- `Sources/Markdown Previews/MarkdownPreviews.swift` — `Markdown.HTML {` → `Markdown {`
- `Sources/Markdown Previews/MarkdownPreviews Configuration.swift` — `Markdown.HTML(configuration:` → `Markdown(configuration:`

**swift-pdf (foundations)**:
- `Tests/PDF Tests/PDF Tests.swift` — `Markdown.HTML {` → `Markdown {`, removed `let markdown = Markdown.HTML()` intermediary

**coenttb/swift-markdown-html-rendering (donor)**:
- `Sources/Markdown HTML Rendering/Markdown.HTML.swift` — same `enum` → `struct` change
- `Sources/Markdown Previews/MarkdownPreviews.swift` — same `Markdown.HTML {` → `Markdown {`
- `Sources/Markdown Previews/MarkdownPreviews Configuration.swift` — same config syntax update

### Files NOT changed (reference)

**coenttb/swift-html-rendering** (working SwiftUI bridge, no MemberImportVisibility):
- `Sources/HTML Renderable/HTML.Document+ViewRepresentable.swift` — the bridge that works without MemberImportVisibility

**foundations/swift-html-rendering** (clean, no changes):
- `Sources/HTML Renderable/HTML.Document.swift` — the `body: Body` stored property
- `Sources/HTML Renderable/HTML.View.swift` — `protocol View: Rendering.View where Body: HTML.View`
- `Package.swift` — has MemberImportVisibility enabled

### Key type definitions

**`Rendering.View`** (`swift-primitives/swift-rendering-primitives`):
```swift
public protocol View: ~Copyable {
    associatedtype Body: View & ~Copyable
    @Builder var body: Body { get }
    static func _render<C: Context>(_ view: borrowing Self, context: inout C)
}
```

**`HTML.View`** (`swift-html-rendering/Sources/HTML Renderable/HTML.View.swift`):
```swift
extension HTML {
    public protocol View: Rendering.View where Body: HTML.View {
        @HTML.Builder var body: Body { get }
    }
}
```

**`HTML.Document`** (`swift-html-rendering/Sources/HTML Renderable/HTML.Document.swift`):
```swift
extension HTML {
    public struct Document<Body: HTML.View, Head: HTML.View>: HTML.DocumentProtocol {
        public let head: Head
        public let body: Body

        public init(
            @HTML.Builder body: () -> Body,
            @HTML.Builder head: () -> Head = { HTML.Empty() }
        ) {
            self.body = body()
            self.head = head()
        }
    }
}
```

**`Markdown`** (NEW — `swift-markdown-html-rendering/Sources/Markdown HTML Rendering/Markdown.HTML.swift`):
```swift
public struct Markdown: HTML_Renderable.HTML.View {
    let markdownString: String
    let configuration: HTML.Configuration
    let previewOnly: Bool

    public init(
        configuration: HTML.Configuration = .default,
        previewOnly: Bool = false,
        @HTML.Builder _ markdown: () -> String
    ) {
        self.configuration = configuration
        self.previewOnly = previewOnly
        self.markdownString = markdown()
    }

    public var body: some HTML_Renderable.HTML.View {
        HTML(configuration: configuration, previewOnly: previewOnly)
            .callAsFunction { markdownString }
    }
}
```

Note: Inside the `Markdown` struct, `HTML` resolves to `Self.HTML` = `Markdown.HTML` (the nested struct). `HTML.Configuration` = `Markdown.HTML.Configuration`. `@HTML.Builder` = `@Markdown.HTML.Builder` (the markdown string result builder). `HTML_Renderable.HTML.View` uses the fully qualified protocol name to avoid the collision.

**SwiftUI bridge** (coenttb version, works without MemberImportVisibility):
```swift
#if canImport(SwiftUI)
@preconcurrency public import SwiftUI
public import WebKit

private extension HTML.Document where Body: HTML.View, Head: HTML.View {
    @MainActor
    func makeWebView() -> WKWebView { ... }
    @MainActor
    func loadHTML(into webView: WKWebView) { ... }
}

#if os(macOS)
extension HTML.Document: SwiftUI.View where Body: HTML.View, Head: HTML.View {}
extension HTML.Document: SwiftUI.NSViewRepresentable where Body: HTML.View, Head: HTML.View {
    public typealias NSViewType = WKWebView
    public func makeNSView(context: ...) -> WKWebView { makeWebView() }
    public func updateNSView(_ webView: ..., context: ...) { loadHTML(into: webView) }
}
#elseif os(iOS)
// UIViewRepresentable equivalent
#endif
#endif
```

---

## Package dependency graph (relevant subset)

```
swift-rendering-primitives (Layer 1)
    └── Rendering.View, Rendering.Builder
         │
swift-html-rendering (Layer 3)
    ├── HTML Renderable
    │   ├── HTML.View (refines Rendering.View)
    │   ├── HTML.Document (conforms to HTML.DocumentProtocol : HTML.View)
    │   └── HTML.Builder (= Rendering.Builder)
    └── HTML Rendering (re-exports everything)
         │
swift-markdown-html-rendering (Layer 3)
    ├── SwiftMarkdown (re-exports apple/swift-markdown under collision-free name)
    ├── Markdown HTML Rendering
    │   ├── Markdown (struct, conforms to HTML.View)
    │   ├── Markdown.HTML (struct, callAsFunction → some HTML.View)
    │   └── Markdown.HTML.Builder, .Configuration, .Section
    └── Markdown Previews (#Preview using HTML.Document — BROKEN)
         │
swift-pdf (Layer 3)
    └── PDF (uses HTML.View types in its document builder)

swift-pdf-html-rendering (Layer 3)
    └── PDF HTML Rendering (bridges HTML.View → PDF.View)
```

---

## SwiftMarkdown namespace collision context

Apple's swift-markdown package claims the module name `Markdown`. The package needs its own `Markdown` namespace. The workaround:

1. A separate `SwiftMarkdown` module re-exports apple/swift-markdown under a collision-free name
2. The main module claims `Markdown` as its own type (was `enum`, now `struct`)
3. `SwiftMarkdown.swift` has a TODO: "Remove once SE-0491 (Module Selectors) lands"

This is relevant because `Markdown` can't be renamed without considering the collision. The `SwiftMarkdown` wrapper module must continue to exist until SE-0491.

---

## Key constraints

1. **MemberImportVisibility is enabled** in foundations packages and should remain so (ecosystem convention)
2. **`HTML.Document` should work directly in `#Preview`** — no wrapper types at the call site
3. **`Markdown { ... }` syntax is done** — the `struct` change works, just needs the preview fix
4. **No Foundation in primitives/standards** — but foundations layer allows it
5. **The coenttb version works** as-is (no MemberImportVisibility) — the foundations version needs a compatible solution
6. **[API-IMPL-005] One type per file** — the bridge should be in its own file

---

## Recommended investigation order

1. **Experiment 3** (MemberImportVisibility deep-dive) — understand exactly which import visibility levels cause the conflict and which don't. This narrows the solution space.

2. **Experiment 4** (NSViewRepresentable body witness) — understand whether the compiler CAN disambiguate a stored `body` property from `NSViewRepresentable`'s default `body`, and under what conditions.

3. **Experiment 1** (Cross-package retroactive conformance) — test whether full package isolation resolves the conflict.

4. **Experiment 2** (Stored property rename) — last resort if the above don't work, but cleanest long-term fix.

5. **Approach 6** (disable MemberImportVisibility for html-rendering) — pragmatic fallback if experiments show no clean solution exists today.

---

## Decision criteria

| Approach | Ergonomics | Architectural cleanliness | Risk | Recommendation |
|----------|------------|--------------------------|------|----------------|
| Separate package bridge | Good (just add import) | Good (clean boundary) | Medium (may still conflict) | Try first |
| Rename `body` → `content` | Perfect (no extra imports) | Best (no name collision) | High (breaking change audit) | Try if others fail |
| Disable MemberImportVisibility | Perfect (no code changes) | Poor (ecosystem inconsistency) | Low | Pragmatic fallback |
| `.swiftUIView` wrapper property | Acceptable | Good | Low | Quick win if needed |
| Wait for SE-0491 | N/A | Perfect | N/A | Not actionable today |

---

## Success criteria

The investigation is complete when:

1. `swift build` succeeds for ALL targets in swift-markdown-html-rendering (including `Markdown Previews`)
2. `swift test` passes in swift-markdown-html-rendering and swift-pdf
3. `#Preview { HTML.Document { Markdown { "# Hello" } } }` compiles
4. MemberImportVisibility remains enabled (or there's a documented reason to disable it)
5. The solution is applied to both foundations and coenttb versions
6. Findings are documented as experiments per [EXP-003b] with CONFIRMED/REFUTED results

---

## How to commit the current work

The `Markdown { ... }` syntax change is complete and tested independently of the preview issue. It can be committed now:

```bash
# swift-markdown-html-rendering (foundations)
cd swift-markdown-html-rendering
git add Sources/Markdown\ HTML\ Rendering/Markdown.HTML.swift
git add Sources/Markdown\ Previews/MarkdownPreviews.swift
git add Sources/Markdown\ Previews/MarkdownPreviews\ Configuration.swift
git commit -m "Change Markdown from enum to struct, enabling Markdown { ... } syntax"

# swift-pdf
cd swift-pdf
git add Tests/PDF\ Tests/PDF\ Tests.swift
git commit -m "Use simplified Markdown { ... } syntax in tests"

# coenttb donor
cd swift-markdown-html-rendering
git add Sources/Markdown\ HTML\ Rendering/Markdown.HTML.swift
git add Sources/Markdown\ Previews/MarkdownPreviews.swift
git add Sources/Markdown\ Previews/MarkdownPreviews\ Configuration.swift
git commit -m "Change Markdown from enum to struct, enabling Markdown { ... } syntax"
```

The preview fix should be a separate commit once the investigation resolves the SwiftUI bridge approach.
