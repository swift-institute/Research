# Research + Experiment: Rendering.Context — Protocol vs Witness Performance

## Assignment

Conduct a Tier 2 research investigation ([RES-004]) with empirical validation ([EXP-017]) comparing two architectural approaches for `Rendering.Context`:

1. **Protocol** (current): `Rendering.Context` is a protocol with `_render<C: Rendering.Context>` generic specialization
2. **Witness** (proposed): `Rendering.Context` is a `@Witness`-style struct with closure properties

The research must answer: **Does the witness approach lose measurable performance compared to the protocol approach, and if so, how much?**

The experiment validates this empirically using `.timed()` performance tests in the swift-testing nested package pattern ([INST-TEST-001]).

### Deliverables

1. **Research document**: `swift-institute/Research/rendering-context-protocol-vs-witness.md` per [RES-003]
2. **Experiment package**: `swift-institute/Experiments/rendering-context-protocol-vs-witness/` per [EXP-002]
3. **Performance tests**: In a nested `Tests/Package.swift` using swift-testing `.timed()` per [INST-TEST-006]

### Quality bar

Academically rigorous. Empirical evidence required — no "it should be faster" without measurements. Both debug and release builds must be measured ([EXP-010d]).

---

## Context: Why This Question Matters

We are redesigning the markdown→HTML/PDF rendering pipeline to eliminate `HTML.AnyView` type erasure, which causes stack overflow in PDF rendering. The proposed architecture uses a `Rendering.Action` enum (command objects representing context operations) that markdown element renderers produce as data, which the converter then interprets against a concrete context.

The `Rendering.Action` enum is conceptually the Action enum that a `@Witness` macro would generate from `Rendering.Context`. This raises the question: should `Rendering.Context` itself be a witness instead of a protocol?

### Current architecture (protocol-based)

```swift
// Layer 1: swift-rendering-primitives
extension Rendering {
    public protocol Context: ~Copyable {
        mutating func text(_ content: borrowing String)
        mutating func lineBreak()
        mutating func thematicBreak()
        mutating func image(source: String, alt: String)
        mutating func pageBreak()
        mutating func set(attribute name: String, _ value: String?)
        mutating func add(`class` name: String)
        mutating func write(raw bytes: [UInt8])
        mutating func register(style declaration: String, atRule: String?, selector: String?, pseudo: String?) -> String?
        static func _pushBlock(_ context: inout Self, role: Semantic.Block?, style: Style)
        static func _popBlock(_ context: inout Self)
        static func _pushInline(_ context: inout Self, role: Semantic.Inline?, style: Style)
        static func _popInline(_ context: inout Self)
        static func _pushList(_ context: inout Self, kind: Semantic.List, start: Int?)
        static func _popList(_ context: inout Self)
        static func _pushItem(_ context: inout Self)
        static func _popItem(_ context: inout Self)
        static func _pushLink(_ context: inout Self, destination: borrowing String)
        static func _popLink(_ context: inout Self)
        static func _pushAttributes(_ context: inout Self)
        static func _popAttributes(_ context: inout Self)
        static func _pushElement(_ context: inout Self, tagName: String, isBlock: Bool, isVoid: Bool, isPreElement: Bool)
        static func _popElement(_ context: inout Self, isBlock: Bool)
        static func _pushStyle(_ context: inout Self)
        static func _popStyle(_ context: inout Self)
        mutating func apply(inlineStyle property: Any) -> Bool
    }
}
```

Every view type has `static func _render<C: Rendering.Context>(_ view: borrowing Self, context: inout C)`. The compiler specializes the entire rendering pipeline per context type (HTML vs PDF). There are 40+ locations with `C: Rendering.Context` constraints.

There are exactly **3 concrete conformers**:
- `HTML.Context` (swift-html-rendering) — writes HTML bytes to a `ContiguousArray<UInt8>`
- `PDF.Context` (swift-pdf-rendering) — produces PDF content stream operators
- `PDF.HTML.Context` (swift-pdf-html-rendering) — wraps PDF.Context with HTML semantic handling

Plus 1 test mock in rendering primitives tests.

### Proposed alternative (witness-based)

```swift
// Rendering.Context as a witness struct instead of a protocol
extension Rendering {
    struct Context: ~Copyable {
        var text: (String) -> Void
        var lineBreak: () -> Void
        var thematicBreak: () -> Void
        var image: (String, String) -> Void
        var pageBreak: () -> Void
        var pushBlock: (Semantic.Block?, Style) -> Void
        var popBlock: () -> Void
        var pushInline: (Semantic.Inline?, Style) -> Void
        var popInline: () -> Void
        var pushList: (Semantic.List, Int?) -> Void
        var popList: () -> Void
        var pushItem: () -> Void
        var popItem: () -> Void
        var pushLink: (String) -> Void
        var popLink: () -> Void
        var pushElement: (String, Bool, Bool, Bool) -> Void
        var popElement: (Bool) -> Void
        var setAttribute: (String, String?) -> Void
        var addClass: (String) -> Void
        var registerStyle: (String, String?, String?, String?) -> String?
        var writeRaw: ([UInt8]) -> Void
        var pushStyle: () -> Void
        var popStyle: () -> Void
        var applyInlineStyle: (Any) -> Bool
    }
}
```

With the `@Witness` pattern, the Action enum falls out naturally — it's the reified operation set. Static factory methods provide concrete implementations:

```swift
extension Rendering.Context {
    static func html(buffer: UnsafeMutablePointer<ContiguousArray<UInt8>>) -> Self { ... }
    static func pdf(context: UnsafeMutablePointer<PDF.Context>) -> Self { ... }
}
```

### The trade-off

| Aspect | Protocol | Witness |
|--------|----------|---------|
| Dispatch | Static (compiler specializes per C) | Dynamic (closure indirection) |
| Inlining | Full (`@inlinable` + generic specialization) | None (closures are opaque to optimizer) |
| Action enum | Must be hand-derived separately | Falls out naturally from witness pattern |
| Composability | Requires protocol conformance declaration | Value composition (swap individual closures) |
| `_render<C>` pattern | Generic `C` parameter on every view | Concrete `Rendering.Context` parameter |
| Migration cost | None (current) | 40+ locations, every `_render<C>` method |
| Testability | Requires mock conformer | Trivial (override individual closures) |

---

## Experiment Design

### What to measure

The experiment compares the **rendering pipeline performance** of protocol-based vs witness-based context dispatch. The workload simulates what happens when rendering a markdown document to HTML or PDF.

### Variants

Design the experiment with these variants ([EXP-009]):

#### V1: Protocol-based rendering (baseline)

A minimal `Rendering.Context` protocol with the key methods. A concrete `HTMLContext` conformer that appends bytes to a buffer. A `_render<C>` generic function that calls context methods in a realistic pattern (push/pop blocks, text, attributes, styles). Measure rendering a simulated document of N elements.

```swift
// MARK: - V1: Protocol Baseline
protocol ContextProtocol {
    mutating func text(_ content: String)
    mutating func pushBlock(role: String?)
    mutating func popBlock()
    mutating func pushElement(tagName: String)
    mutating func popElement()
    mutating func setAttribute(name: String, value: String?)
    mutating func registerStyle(declaration: String) -> String?
}

struct HTMLContext: ContextProtocol {
    var bytes: ContiguousArray<UInt8> = []
    // ... implementations that append to bytes
}

@inline(never)  // prevent the optimizer from eliminating the work
func renderDocument<C: ContextProtocol>(elements: Int, context: inout C) {
    for i in 0..<elements {
        context.pushBlock(role: "paragraph")
        context.pushElement(tagName: "p")
        _ = context.registerStyle(declaration: "line-height: 1.5")
        context.text("Element \(i)")
        context.popElement()
        context.popBlock()
    }
}
```

#### V2: Witness-based rendering

The same operations expressed as a witness struct with stored closures. A concrete `.html(...)` factory that provides the same implementations. A non-generic `renderDocument` function that calls through the closures.

```swift
// MARK: - V2: Witness
struct ContextWitness {
    var text: (String) -> Void
    var pushBlock: (String?) -> Void
    var popBlock: () -> Void
    var pushElement: (String) -> Void
    var popElement: () -> Void
    var setAttribute: (String, String?) -> Void
    var registerStyle: (String) -> String?
}

extension ContextWitness {
    static func html(buffer: UnsafeMutablePointer<ContiguousArray<UInt8>>) -> Self {
        .init(
            text: { buffer.pointee.append(contentsOf: $0.utf8) },
            pushBlock: { _ in buffer.pointee.append(contentsOf: "<div>".utf8) },
            // ...
        )
    }
}

@inline(never)
func renderDocument(elements: Int, witness: inout ContextWitness) {
    for i in 0..<elements {
        witness.pushBlock("paragraph")
        witness.pushElement("p")
        _ = witness.registerStyle("line-height: 1.5")
        witness.text("Element \(i)")
        witness.popElement()
        witness.popBlock()
    }
}
```

#### V3: Action-interpreted rendering (the actual proposed design)

The markdown witness produces `[Rendering.Action]` values. A converter interprets them against a protocol-based context. This is the hybrid: protocol for dispatch, actions for deferred rendering.

```swift
// MARK: - V3: Action + Protocol Interpreter
enum Action {
    case text(String)
    case pushBlock(role: String?)
    case popBlock
    case pushElement(tagName: String)
    case popElement
    case setAttribute(name: String, value: String?)
    case registerStyle(declaration: String)
}

@inline(never)
func interpretActions<C: ContextProtocol>(
    _ actions: [Action], context: inout C
) {
    for action in actions {
        switch action {
        case .text(let content): context.text(content)
        case .pushBlock(let role): context.pushBlock(role: role)
        case .popBlock: context.popBlock()
        case .pushElement(let tag): context.pushElement(tagName: tag)
        case .popElement: context.popElement()
        case .setAttribute(let name, let value): context.setAttribute(name: name, value: value)
        case .registerStyle(let decl): _ = context.registerStyle(declaration: decl)
        }
    }
}

@inline(never)
func renderViaActions(elements: Int, context: inout HTMLContext) {
    var actions: [Action] = []
    actions.reserveCapacity(elements * 6)
    for i in 0..<elements {
        actions.append(.pushBlock(role: "paragraph"))
        actions.append(.pushElement(tagName: "p"))
        actions.append(.registerStyle(declaration: "line-height: 1.5"))
        actions.append(.text("Element \(i)"))
        actions.append(.popElement)
        actions.append(.popBlock)
    }
    interpretActions(actions, context: &context)
}
```

#### V4: Action-interpreted with buffer reuse

Same as V3 but reuses a single action buffer across elements (the `removeAll(keepingCapacity: true)` pattern from the proposed markdown converter design).

```swift
// MARK: - V4: Action + Buffer Reuse
@inline(never)
func renderViaActionsReused(elements: Int, context: inout HTMLContext) {
    var actions: [Action] = []
    actions.reserveCapacity(16)  // typical element produces ~6-10 actions
    for i in 0..<elements {
        actions.removeAll(keepingCapacity: true)
        actions.append(.pushBlock(role: "paragraph"))
        actions.append(.pushElement(tagName: "p"))
        actions.append(.registerStyle(declaration: "line-height: 1.5"))
        actions.append(.text("Element \(i)"))
        actions.append(.popElement)
        actions.append(.popBlock)
        interpretActions(actions, context: &context)
    }
}
```

#### V5: View-tree rendering (current markdown path, for comparison)

Simulates the current AnyView-based path: each element creates a type-erased view that's rendered through existential dispatch.

```swift
// MARK: - V5: AnyView Existential (current path)
protocol AnyRenderable {
    func render<C: ContextProtocol>(context: inout C)
}

struct ParagraphView: AnyRenderable {
    let text: String
    let index: Int
    func render<C: ContextProtocol>(context: inout C) {
        context.pushBlock(role: "paragraph")
        context.pushElement(tagName: "p")
        _ = context.registerStyle(declaration: "line-height: 1.5")
        context.text(text)
        context.popElement()
        context.popBlock()
    }
}

@inline(never)
func renderViaAnyView(elements: Int, context: inout HTMLContext) {
    var views: [any AnyRenderable] = []
    for i in 0..<elements {
        views.append(ParagraphView(text: "Element \(i)", index: i))
    }
    for view in views {
        view.render(context: &context)
    }
}
```

### Test matrix

| Variant | Document sizes | Builds |
|---------|---------------|--------|
| V1: Protocol baseline | 10, 100, 1000, 10000 | debug + release |
| V2: Witness closures | 10, 100, 1000, 10000 | debug + release |
| V3: Action + interpret (batch) | 10, 100, 1000, 10000 | debug + release |
| V4: Action + interpret (reuse) | 10, 100, 1000, 10000 | debug + release |
| V5: AnyView existential | 10, 100, 1000, 10000 | debug + release |

That's 40 measurements total.

### Metrics

For each variant × size × build:
- Median time (from `.timed()`)
- Relative to V1 baseline (percentage overhead)

### Expected outcome hypotheses

- **V1 (protocol)**: Fastest. Full inlining in release.
- **V2 (witness)**: Slower than V1 due to closure indirection. Question is by how much.
- **V3 (action batch)**: Slower than V1 due to action array allocation + switch dispatch. But eliminates AnyView.
- **V4 (action reuse)**: Close to V3 but avoids repeated allocation. Should approach V1 for large documents.
- **V5 (AnyView)**: Slowest. Existential allocation + dispatch. This is the current path we're replacing.

The critical comparison is **V1 vs V2** (protocol vs witness for the context itself) and **V1 vs V4** (protocol vs the proposed action-based hybrid).

If V2 is within 2x of V1 in release, the witness approach may be acceptable. If V4 is within 1.5x of V1, the action-based hybrid is clearly the right design (since it's also dramatically better than V5).

---

## Performance Test Structure

Use the nested testing package pattern per [INST-TEST-001]:

```
swift-institute/Experiments/rendering-context-protocol-vs-witness/
├── Package.swift                    # Main package with variant implementations
├── Sources/
│   └── Variants/
│       ├── V1_Protocol.swift
│       ├── V2_Witness.swift
│       ├── V3_ActionBatch.swift
│       ├── V4_ActionReuse.swift
│       └── V5_AnyView.swift
├── Tests/
│   ├── Package.swift                # Nested testing package
│   └── Performance Tests/
│       └── RenderingDispatchPerformanceTests.swift
└── README.md                        # Results summary
```

Performance tests use `.timed()` per [INST-TEST-007]:

```swift
import Testing
@testable import Variants

@Suite(.serialized)
struct `Rendering Dispatch - Performance` {

    // --- V1: Protocol baseline ---

    @Test(.timed(iterations: 20, warmup: 3, threshold: .milliseconds(50)))
    func `V1 protocol - 100 elements`() {
        var context = HTMLContext()
        renderDocument(elements: 100, context: &context)
    }

    @Test(.timed(iterations: 20, warmup: 3, threshold: .milliseconds(200)))
    func `V1 protocol - 1000 elements`() {
        var context = HTMLContext()
        renderDocument(elements: 1000, context: &context)
    }

    @Test(.timed(iterations: 20, warmup: 3))
    func `V1 protocol - 10000 elements`() {
        var context = HTMLContext()
        renderDocument(elements: 10000, context: &context)
    }

    // --- V2: Witness closures ---

    @Test(.timed(iterations: 20, warmup: 3, threshold: .milliseconds(50)))
    func `V2 witness - 100 elements`() {
        var buffer: ContiguousArray<UInt8> = []
        withUnsafeMutablePointer(to: &buffer) { ptr in
            var witness = ContextWitness.html(buffer: ptr)
            renderDocument(elements: 100, witness: &witness)
        }
    }

    // ... same pattern for 1000, 10000

    // --- V3, V4, V5 follow the same pattern ---
}
```

Run both debug and release:

```bash
cd swift-institute/Experiments/rendering-context-protocol-vs-witness/Tests
swift test                              # debug
swift test -c release                   # release
```

---

## Research Document Structure

The research document at `swift-institute/Research/rendering-context-protocol-vs-witness.md` should follow [RES-003]:

```markdown
# Rendering.Context — Protocol vs Witness

<!--
---
version: 1.0.0
last_updated: 2026-03-14
status: DECISION
tier: 2
---
-->

## Context
{Link to swift-foundations/swift-markdown-html-rendering/Research/markdown-direct-context-rendering.md and the witness discussion}

## Question
Should Rendering.Context be expressed as a protocol (current) or a witness struct?

## Analysis

### Option A: Protocol (current)
{Static dispatch advantages, 40+ constraint locations, zero-cost}

### Option B: Witness struct
{Action enum falls out naturally, composable, testable, closure overhead}

### Option C: Hybrid — protocol with derived Action enum
{Protocol stays for dispatch, Action derived for deferred rendering}

### Empirical Results
{Table from experiment with all 40 measurements}

### Comparison
| Criterion | Protocol | Witness | Hybrid |
|-----------|----------|---------|--------|

## Outcome
**Status**: DECISION
{Based on empirical evidence}

## References
- Experiment: `swift-institute/Experiments/rendering-context-protocol-vs-witness/`
- Prior research: `swift-foundations/swift-markdown-html-rendering/Research/markdown-direct-context-rendering.md`
```

---

## Key Constraints

1. **Layer 1 primitives**: `Rendering.Context` is in `swift-rendering-primitives` (Layer 1). No Foundation. No macro dependencies (the `@Witness` macro is Layer 3). If the witness approach wins, the struct and Action enum are hand-written following the macro's derivation rules.

2. **`~Copyable` support**: The current protocol is `~Copyable`. The witness struct would also need to be `~Copyable` if it stores non-escaping closures. Verify this compiles.

3. **`borrowing` parameters**: The protocol has `text(_ content: borrowing String)` and `_pushLink(destination: borrowing String)`. If the witness uses stored closures, these become `(String) -> Void` (owned). If the Action enum stores the data, it also owns it. This is acceptable — the borrowing annotation is an optimization hint for the protocol path, not a semantic requirement.

4. **Static method pattern**: The protocol uses `static func _pushBlock(_ context: inout Self, ...)`. The witness equivalent is a closure `var pushBlock: (Semantic.Block?, Style) -> Void` that captures the mutable state. The `inout Self` pattern doesn't exist in a witness — the closures mutate captured state directly.

5. **Property.View accessors**: The current fluent API (`context.push.block(...)`, `context.pop.block()`) depends on `Property.View` extensions constrained to `Rendering.Context`. If the witness replaces the protocol, these extensions need redesign. Measure whether this is feasible.

6. **3 concrete conformers**: HTML.Context, PDF.Context, PDF.HTML.Context. The witness approach would replace 3 conformances with 3 factory methods (`.html(...)`, `.pdf(...)`, `.pdfHTML(...)`).

7. **Performance in release builds**: The critical comparison. Debug builds will show closure overhead more dramatically (no inlining). Release builds may close the gap if the optimizer can see through the closures. Measure both.

8. **`@Witness` Action enum derivation rules**: The macro excludes `inout`, `borrowing`, and `consuming` parameters from Action cases. Apply the same rules when hand-writing the Action enum. The `inout Self` (context) parameter is always excluded — it's what you interpret against.

---

## Package Locations

| Package | Path |
|---------|------|
| swift-rendering-primitives | `https://github.com/swift-primitives/swift-rendering-primitives` |
| swift-html-rendering | `https://github.com/swift-foundations/swift-html-rendering` |
| swift-pdf-html-rendering | `https://github.com/swift-foundations/swift-pdf-html-rendering` |
| swift-witnesses | `https://github.com/swift-foundations/swift-witnesses` |
| swift-testing | `https://github.com/swift-foundations/swift-testing` |
| swift-institute | `./` |

### Key files to study

| File | Contains |
|------|----------|
| `swift-rendering-primitives/.../Rendering.Context.swift` | Current protocol definition (262 lines) |
| `swift-rendering-primitives/.../Rendering.View.swift` | `_render<C>` pattern |
| `swift-rendering-primitives/.../Rendering.Semantic.Block.swift` | Block role enum |
| `swift-rendering-primitives/.../Rendering.Style.swift` | Style type |
| `swift-html-rendering/.../HTML.Context.swift` | HTML conformer (633 lines) |
| `swift-pdf-html-rendering/.../PDF.HTML.Context+Rendering.swift` | PDF conformer (1095 lines) |
| `swift-witnesses/.../WitnessMacro.swift` | Action enum generation (lines 879–959) |
| `swift-foundations/swift-markdown-html-rendering/Research/markdown-direct-context-rendering.md` | Prior research |

### Prior research to reference

| Document | Path |
|----------|------|
| Direct context rendering | `swift-foundations/swift-markdown-html-rendering/Research/markdown-direct-context-rendering.md` |
| Markdown rendering audit | `swift-foundations/swift-markdown-html-rendering/Research/markdown-rendering-organization-audit.md` |
| Stack overflow handoff | `swift-foundations/swift-pdf/Research/sigbus-stack-overflow-handoff.md` |
| Witness ecosystem adoption | `swift-institute/Research/witnesses-ecosystem-adoption-audit.md` |
| Protocol-witness-effects | `swift-institute/Research/protocol-witness-effects-capability-abstraction.md` |

---

## Success Criteria

The research + experiment is complete when:

1. All 5 variants (V1–V5) compile and produce correct output (same HTML bytes)
2. All 40 measurements are collected (5 variants × 4 sizes × 2 build configs)
3. Results are presented in a comparison table with relative percentages
4. The research document makes a DECISION based on empirical evidence
5. If the hybrid approach (Option C) wins, the `Rendering.Action` enum is fully specified
6. If the witness approach (Option B) wins, the migration path from protocol to witness is described
7. The experiment follows [EXP-003b] header format with toolchain, results, and evidence
8. Performance tests use `.timed()` per [INST-TEST-007] with appropriate thresholds

---

## Important Notes

- **Do NOT modify any existing package code.** This is a research experiment only. All code goes in the experiment package.
- **Do NOT use the `@Witness` macro** in the experiment. Hand-write the witness struct and Action enum following the same derivation rules. The macro lives in Layer 3; we need to understand if this pattern works at Layer 1.
- **Measure BOTH debug and release builds.** The debug/release gap matters — if closures are 10x slower in debug but equal in release, that's a very different conclusion than if they're 2x slower in both.
- **Use `@inline(never)` on the render functions** to prevent the optimizer from eliminating the work entirely. But do NOT use it on the context method implementations — let the optimizer inline those as it would in production.
- **The experiment is self-contained.** It does not depend on swift-rendering-primitives, swift-html-rendering, or any other ecosystem package. It recreates minimal versions of the types for isolated measurement.
- **Follow all Swift Institute conventions**: [API-NAME-001] namespace nesting, [API-IMPL-005] one type per file, [API-ERR-001] typed throws where applicable.
