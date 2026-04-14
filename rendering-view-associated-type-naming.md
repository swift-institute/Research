# Rendering.View Associated Type Naming

<!--
---
version: 1.0.0
last_updated: 2026-03-13
status: DECISION
---
-->

## Context

SwiftUI previews in `swift-markdown-html-rendering` and any package using `HTML.Document` in `#Preview` fail to compile. The goal: `HTML.Document` must conform to `SwiftUI.View` (via `NSViewRepresentable`) so that `#Preview { HTML.Document { Markdown { "# Hello" } } }` works directly.

Three failed approaches preceded this investigation:
1. Bridge file in same module — `public import SwiftUI` leaks `SwiftUI.View` to all files via MemberImportVisibility
2. Separate target in same package — `@retroactive` rejected ("same package"), `body` conflict persists
3. Wrapper view — rejected on ergonomic grounds (`HTML.Document` must work directly in `#Preview`)

## Question

Why does adding `NSViewRepresentable` conformance to `HTML.Document` fail, and what is the principled fix?

## Analysis

### Root Cause

Swift unconditionally unifies same-named associated types across all protocol conformances of a type. `Rendering.View` declares `associatedtype Body`, and `SwiftUI.View` declares `associatedtype Body`. When `HTML.Document` conforms to both (via `HTML.View` and `NSViewRepresentable`), the compiler merges them into a single `Body`.

`NSViewRepresentable` constrains `Self.Body == Never`. This forces the unified `Body` to be `Never`. But `Rendering.View` requires `Body: Rendering.View`, and `Never` does not conform to `Rendering.View`. Deadlock.

**This is not a MemberImportVisibility issue.** Experiment `member-import-visibility-body-conflict` V1–V5 all fail regardless of MIV settings. V3 (MIV disabled) fails identically to V2 (MIV enabled).

### Compiler Evidence

Investigation of the Swift compiler source (`https://github.com/swiftlang/swift`) confirms:

1. **Associated type anchor system** (`lib/AST/Decl.cpp:6458–6487`): Same-named associated types are unified through a hierarchy-based override system. No mechanism exists to keep them separate.

2. **SE-0491 (Module Selectors) explicitly cannot help** (`CHANGELOG.md:76–77`): *"module selector is not allowed on generic member type; associated types with the same name are merged instead of shadowing one another"*

3. **No experimental features address this** (`include/swift/Basic/Features.def`): `SuppressedAssociatedTypes` and `SuppressedAssociatedTypesWithDefaults` handle `~Copyable`/`~Escapable`, not cross-protocol disambiguation.

4. **`@_implements` and `@_nonoverride`** exist but operate on value witnesses and override chains respectively — neither splits a unified associated type.

### Why the coenttb Version Works

The coenttb `Renderable` protocol uses `associatedtype Content`, not `associatedtype Body`:

```swift
public protocol Renderable {
    associatedtype Content
    var body: Content { get }
}
```

When `HTML.Document` conforms to both `Renderable` (via `HTML.View`) and `SwiftUI.View` (via `NSViewRepresentable`):
- `Renderable.Content = Body` (the generic parameter) — resolved from stored property
- `SwiftUI.View.Body = Never` — from NSViewRepresentable constraint
- **Different names. No unification. No collision.**

### Experimental Verification

**Experiment**: `swift-institute/Experiments/member-import-visibility-body-conflict/`

| Variant | Associated Type Name | MIV | Result |
|---------|---------------------|-----|--------|
| V1 | `Body` (same file) | ON | **FAIL** — `Body` doesn't conform to `SwiftUI.View` |
| V2 | `Body` (different file) | ON | **FAIL** — `Body` resolved to `Never`, doesn't conform to `CustomView` |
| V3 | `Body` (different file) | OFF | **FAIL** — identical to V2 |
| V4 | `Body` (internal import) | ON | **FAIL** — visibility + `@retroactive` errors |
| V5 | `Body` (package import) | ON | **FAIL** — visibility errors |
| **V6** | **`Content`** | **ON** | **SUCCESS** — no collision |

V6 proves that renaming the associated type eliminates the conflict entirely, even with MemberImportVisibility enabled.

### Option A: Rename to `Content`

Matches the coenttb `Renderable` protocol. Semantically accurate (the body property returns the view's content). Short and clean.

**Risk**: `Content` is a common word. A future protocol with `associatedtype Content` would trigger the same deadlock. The fix would not be principled — it would rely on `Content` happening not to collide.

### Option B: Rename to `RenderBody`

Distinctive name that virtually eliminates future collision risk. No Apple framework protocol uses `RenderBody` as an associated type. The property name stays `body` — only the type alias changes.

**Trade-off**: Compound identifier. `[API-NAME-002]` bans compound names for methods and properties, not associated types. The ergonomic cost is minimal — `typealias RenderBody = Never` appears ~14 times; `where RenderBody: HTML.View` appears ~3 times.

### Option C: Wrapper property (`.swiftUIView`)

Avoids the protocol conflict entirely by not conforming `HTML.Document` to `SwiftUI.View`. Ergonomic cost at every preview call site.

**Rejected**: User requirement is that `HTML.Document` works directly in `#Preview`.

### Comparison

| Criterion | `Content` | `RenderBody` | `.swiftUIView` |
|-----------|-----------|--------------|----------------|
| Collision risk | Low but nonzero | ~Zero | N/A |
| Ergonomics | Best | Best | Unacceptable |
| [API-NAME-002] | Compliant | N/A (assoc types) | N/A |
| Blast radius | 27 files | 27 files | 1 file |
| Principled | Partially | Yes | Yes |
| Future-proof | No | Yes | Yes |

## Outcome

**Status**: DECISION

**Choice**: Rename `Rendering.View`'s `associatedtype Body` to `associatedtype RenderBody`.

**Rationale**: The name collision between `Rendering.View.Body` and `SwiftUI.View.Body` is a fundamental Swift language limitation with no compiler-level workaround. The fix must be at the protocol level. `RenderBody` is distinctive enough to prevent future collisions while remaining ergonomic. The property name `body` is unchanged — only the associated type alias changes.

**Blast radius**: 27 files across swift-primitives and swift-foundations. 128+ HTML element files are unaffected (they use `var body: some HTML.View` which doesn't reference the associated type name).

**Key invariant**: `HTML.Document<Body, Head>` keeps its generic parameter named `Body`. The compiler infers `RenderBody = Body` (the generic param) from the stored property. `SwiftUI.View.Body = Never` resolves independently.

## References

- Experiment: `swift-institute/Experiments/member-import-visibility-body-conflict/` (V1–V6)
- Experiment: `swift-institute/Experiments/nsviewrepresentable-body-witness/` (V1–V4)
- Swift compiler: `lib/AST/Decl.cpp:6458–6487` (associated type anchor)
- Swift compiler: `lib/Sema/TypeCheckDeclOverride.cpp:2308–2352` (override detection)
- SE-0491: Module Selectors — cannot disambiguate associated types
- Investigation prompt: `swift-institute/Research/prompts/markdown-swiftui-pdf-investigation.md`

## Blog potential

This finding has been captured as a blog idea:
- [BLOG-IDEA-031: The associated type trap](../Blog/_index.md) — [Draft](../Blog/Draft/associated-type-trap.md)
