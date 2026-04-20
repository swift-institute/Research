# Rendering.View Associated Type Naming

<!--
---
version: 2.0.0
last_updated: 2026-04-20
status: SUPERSEDED
supersedes: 1.0.0 (2026-03-13 — chose RenderBody rename)
---
-->

> **SUPERSEDED 2026-04-20**: The v1 decision (rename `Body` → `RenderBody` at the `Rendering.View` protocol) has been walked back. `@_implements(Rendering.View, Body)` at the one bridge type (`HTML.Document`) is strictly better — it keeps the idiomatic `Body` name at L1 and concentrates the bridge cost at the site that actually bridges two frameworks. The v1 analysis below is preserved for historical context; the v2 decision is at the end of this document.

---

## v1 analysis (2026-03-13 — SUPERSEDED)

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

## Blog Post

This finding was published as:
- [The associated type trap, and the escape hatch I missed](../Blog/Published/2026-04-20-associated-type-trap.md) (2026-04-20)

---

## v2 decision (2026-04-20)

**Status**: CURRENT

**Choice**: Keep `associatedtype Body` at `Rendering.View`. Add `@_implements(Rendering.View, Body)` on `HTML.Document` — the one type that bridges `Rendering.View` to `SwiftUI.View`.

**What changed since v1**

The v1 analysis concluded "No experimental features address this" and "`@_implements` and `@_nonoverride` exist but operate on value witnesses and override chains respectively — neither splits a unified associated type." This was wrong. Direct experiment (see `Experiments/member-import-visibility-body-conflict/V11_Implements/`) shows that:

1. `@_implements(Protocol, Name)` **does** work on associated types. The attribute lets a typealias satisfy a specifically-named requirement of a specifically-named protocol, even when the type conforms to another protocol that declares an associated type with the same name.
2. `BASELINE_LANGUAGE_FEATURE(AssociatedTypeImplements, 0, "@_implements on associated types")` in `Features.def` confirms this is always-on baseline behavior — not experimental.
3. Release-mode verification (`-O`, `-O -whole-module-optimization`) shows witness tables dispatch correctly. The two `Self.Body` lookups return different concrete types per protocol, as expected.

**Why v2 is better than v1**

| Criterion | v1 (rename to `RenderBody`) | v2 (`@_implements`) |
|-----------|------------------------------|---------------------|
| L1 primitive API | Compound identifier `RenderBody` | Idiomatic `Body` |
| Blast radius | ~20 files across swift-rendering-primitives + swift-html-rendering | 1 line on `HTML.Document` |
| Cost paid at | Every conforming type, ecosystem-wide | One bridge site |
| Future-proof against further collisions | Yes (at the cost of every new conformer inheriting the compound name) | Yes (each new bridge type pays for itself) |
| Language stability | Non-underscored, Evolution-stable | Baseline feature, but underscored surface |
| Layer discipline | Violates ([API-NAME-002] — L1 shouldn't pre-optimize for L3) | Respects — idiomatic at L1, bridge cost at L3 |

v2 trades ecosystem-wide compound naming for one underscored attribute at one bridge type. Since `AssociatedTypeImplements` is a BASELINE language feature (not experimental), the stability trade-off is narrow: the attribute is always on and dispatches correctly, it's just not on the promoted API surface.

**Applied changes** (2026-04-20)

- `swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.View.swift` — `associatedtype RenderBody` → `associatedtype Body`
- 8 other source files in `swift-rendering-primitives` — `typealias RenderBody = Never` → `typealias Body = Never`
- 1 test support file in `swift-rendering-primitives`
- `swift-html-rendering/Sources/HTML Rendering Core/HTML.View.swift` — `where RenderBody: HTML.View` → `where Body: HTML.View`
- 7 other source/test files in `swift-html-rendering` — typealias renames
- `swift-html-rendering/Sources/HTML Rendering Core/HTML.Document.swift` — **added** `@_implements(Rendering.View, Body) public typealias _RenderingBody = Body`

**Verification**

- `swift-rendering-primitives`: clean build + 100/100 tests pass
- `swift-html-rendering`: full-workspace build blocked by pre-existing bugs in unrelated packages (`swift-algebra-linear-primitives` imports a module not declared in its manifest; `swift-incits-4-1986` references missing source files). Fix logic verified against standalone minimal test matching the exact refinement chain.

**Corollary: `@_implements` as a general tool**

The finding generalizes. Whenever a conforming type needs to satisfy two protocols that declare same-named associated types, `@_implements` on a differently-named typealias is the preferred fix over renaming either protocol. The rename-at-protocol approach only makes sense if you own the protocol AND the bridge case is dominant at its layer — rarely true at primitives layers.

**References**

- Experiment: [`member-import-visibility-body-conflict/V11_Implements`](../Experiments/member-import-visibility-body-conflict/Sources/V11_Implements/V11.swift) — CONFIRMED
- Blog: [`associated-type-trap-final.md`](../Blog/Draft/associated-type-trap-final.md) — "The associated type trap, and the escape hatch I missed"
- Swift compiler: `include/swift/Basic/Features.def` — `BASELINE_LANGUAGE_FEATURE(AssociatedTypeImplements, ...)`
- Swift compiler: `docs/ReferenceGuides/UnderscoredAttributes.md` — `@_implements(ProtocolName, Requirement)`
