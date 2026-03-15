# Research: Rendering Witness Architecture — Value Analysis

## Assignment

Conduct a Tier 2 comparative analysis ([RES-004]) of the **current protocol-based** rendering architecture vs the **proposed witness-based** architecture. Focus exclusively on architectural value — what the witness approach enables that the protocol cannot. Ignore migration effort entirely.

**Output**: Research document at `swift-institute/Research/rendering-witness-architecture-value-analysis.md` per [RES-003].

---

## The Two Architectures

### Status Quo: Protocol

```swift
// Layer 1: swift-rendering-primitives
extension Rendering {
    public protocol Context: ~Copyable {
        mutating func text(_ content: borrowing String)
        mutating func lineBreak()
        static func _pushBlock(_ context: inout Self, role: Semantic.Block?, style: Style)
        static func _popBlock(_ context: inout Self)
        // ... 24 total requirements
    }
}

// Every view type:
static func _render<C: Rendering.Context>(_ view: borrowing Self, context: inout C)

// 3 conformers:
extension HTML.Context: Rendering.Context { ... }
extension PDF.Context: Rendering.Context { ... }
extension PDF.HTML.Context: Rendering.Context { ... }
```

### Proposed: Witness + Transformer

```swift
// Layer 1: swift-rendering-primitives
extension Rendering {
    public struct Context: ~Copyable {
        public var text: (String) -> Void
        public var pushBlock: (_ role: Semantic.Block?, _ style: Style) -> Void
        public var popBlock: () -> Void
        // ... 24 stored closures
    }
}

// Every view type:
static func _render(_ view: borrowing Self, context: inout Rendering.Context)

// 2 base factories + 1 transformer:
Rendering.Context.html(state: Ownership.Mutable<HTML.Context>)
Rendering.Context.pdf(state: Ownership.Mutable<PDF.Context>)
consuming func pdfHTML(state: Ownership.Mutable<PDF.HTML.State>) -> Rendering.Context

// Composition:
var context = Rendering.Context.pdf(state: pdfState)
    .pdfHTML(state: htmlState)
    .observing(log: actionLog)
```

The witness captures state via `Ownership.Mutable<T>` from swift-ownership-primitives (heap-allocated mutable box, no unsafe pointers). Transformers are `consuming` methods that wrap closures — algebra endomorphisms on the Σ-algebra.

A `Rendering.Action` enum (nested `Push`/`Pop` per [API-NAME-002]) reifies operations as data. An `interpret(_:)` method on the witness applies actions.

---

## What to Analyze

### Part 1: Direct Comparison

For each dimension, compare protocol vs witness. Be concrete — cite specific code patterns, not abstract benefits.

| Dimension | Questions |
|-----------|-----------|
| **Composability** | Can you combine rendering behaviors without declaring new types? Can you add logging/tracing/profiling to any context without modifying the context type? |
| **Testability** | How do you mock a context for testing? How many lines of code? Can you stub individual operations? |
| **Action reification** | How do you represent "what operations were performed" as data? Can you record, replay, diff, serialize rendering operations? |
| **Generic parameter propagation** | How many type signatures carry `C: Rendering.Context`? What downstream complexity does this create? |
| **Middleware / instrumentation** | Can you add before/after hooks to all rendering operations? Can you add performance measurement per-operation? |
| **Format composition** | Can you compose HTML+PDF rendering without a dedicated bridging type? What about HTML+SVG? HTML+ePub? |
| **Partial override** | Can you change how one specific operation works (e.g., intercept all `text()` calls for i18n) without changing the full context? |
| **Dependency injection** | Can the rendering context be injected via the ecosystem's `Witness.Key` / `Dependency.Scope` pattern? |
| **Serialization** | Can rendering operations be serialized to disk and replayed? (Think: render server that pre-renders markdown to action sequences, then interprets on-demand.) |

### Part 2: What the Witness Architecture Unlocks

Theorize what becomes possible with the witness + transformer + action architecture that is impossible or impractical with the protocol. Think expansively. Consider:

1. **Rendering-as-data**: If rendering operations are `[Rendering.Action]`, what can you do with that data?
   - Diffing two renders (structural diff of action sequences)
   - Server-side pre-rendering (serialize actions, send to client, interpret locally)
   - Render caching (cache action sequences keyed by content hash)
   - Render streaming (produce actions incrementally, interpret on-the-fly)
   - Render transformation (map over actions — e.g., replace all heading levels)

2. **Context composition algebra**: Transformers compose via function composition on closures.
   - What new output formats become trivially expressible?
   - Accessibility layer: transform that adds ARIA attributes to every element
   - Internationalization layer: transform that intercepts `text()` and applies translations
   - Theme layer: transform that overrides styles without changing content
   - Analytics layer: transform that counts elements, measures nesting depth, etc.
   - Validation layer: transform that verifies push/pop balance, warns on invalid nesting

3. **Testing infrastructure**:
   - Snapshot testing via action sequence comparison (not byte comparison)
   - Property-based testing: generate random action sequences, verify all contexts handle them
   - Regression detection: diff action sequences between versions

4. **Multi-format rendering**:
   - Tee transform: duplicate actions to two contexts simultaneously (HTML + PDF from one render pass)
   - Format negotiation: inspect actions, choose optimal format
   - Progressive enhancement: base render + optional enhancement layers

5. **Observe pattern** (from @Witness):
   - Before/after hooks on every operation
   - Performance profiling per-operation type
   - Debug rendering visualization

6. **Markdown rendering specifically**:
   - The `Markdown.Rendering` witness produces `[Rendering.Action]` — what does this unlock beyond the immediate stack overflow fix?
   - Can markdown rendering become lazy? (Produce actions on-demand instead of all at once)
   - Can markdown rendering be cached at the action level? (Same markdown → same actions, skip reparsing)

### Part 3: Category-Theoretic Framing

For the expert audience:

- The rendering operations form a **signature** Σ. A `Rendering.Context` witness is a **Σ-algebra**. `Rendering.Action` is the **free Σ-algebra** (initial object in **Alg(Σ)**).
- Transformers are **endofunctions on Alg(Σ)**. Composition is function composition. Identity transformer is the unit. This forms a **monoid**.
- The `interpret` method is the unique **catamorphism** from the free algebra to any target algebra.
- What algebraic laws should transformers satisfy? Are there natural associativity/commutativity properties?
- Is there a **monad** structure here? (Transformers with state form a monad transformer stack.)
- How does this relate to **free monads** in functional programming? Is `[Rendering.Action]` a free monad?

### Part 4: What the Protocol Can Do That the Witness Cannot

Be honest about any capabilities lost:

- Compile-time specialization (the compiler can inline protocol witnesses; it cannot inline through closure indirection — though the performance experiment showed this doesn't matter in practice)
- Static exhaustiveness (the protocol requires all methods; the witness struct init requires all closures — is there a difference in practice?)
- Anything else?

---

## Key Files to Read

| File | Contains |
|------|----------|
| `swift-institute/Research/rendering-context-witness-migration-implications.md` | Full migration analysis with factory + transformer design |
| `swift-institute/Research/rendering-context-protocol-vs-witness.md` | Performance experiment results |
| `swift-foundations/swift-markdown-html-rendering/Research/markdown-direct-context-rendering.md` | Motivating architecture (AnyView elimination) |
| `swift-institute/Experiments/rendering-context-algebra-composition/` | Working experiment (15 tests): witness, transformer, observer, action interpreter |
| `swift-rendering-primitives/.../Rendering.Context.swift` | Current protocol (262 lines) |
| `swift-html-rendering/.../HTML.Context.swift` | HTML conformer (633 lines) |
| `swift-pdf-html-rendering/.../PDF.HTML.Context+Rendering.swift` | PDF-HTML conformer (1095 lines) |
| `swift-ownership-primitives/.../Ownership.Mutable.swift` | Mutable state capture (replaces UnsafeMutablePointer) |
| `swift-witnesses/.../WitnessMacro.swift` | @Witness macro — Action enum generation pattern |

---

## Constraints

- **Ignore migration effort.** The question is not "is it worth migrating" but "what is the architectural delta."
- **Be concrete.** For every claimed benefit, show a code example of what becomes possible.
- **Be honest about losses.** If the protocol does something the witness cannot, say so.
- **Follow [RES-003] document structure**: Context, Question, Analysis, Comparison, Outcome.
- **Tier 2 rigor**: Include prior art survey ([RES-021]) — how do other rendering systems handle this? (React reconciler, Flutter rendering pipeline, browser rendering engine architecture, TeX's output routines.)

---

## Success Criteria

The research is complete when:

1. Every dimension in Part 1 has a concrete protocol-vs-witness comparison
2. At least 5 novel capabilities from Part 2 are explored with code examples
3. The category-theoretic framing is rigorous (not hand-wavy)
4. Honest assessment of what the protocol retains that the witness doesn't
5. A clear recommendation on architectural value (independent of migration cost)
