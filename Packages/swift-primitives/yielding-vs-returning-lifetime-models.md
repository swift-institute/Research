# Yielding vs Returning: Lifetime Models for Borrowed Access in Swift Primitives

<!--
---
version: 2.0.0
last_updated: 2026-02-10
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-primitives]
normative: false
changelog:
  - "2.0.0 (2026-02-10): Phase 2 systematic literature review added (Part VII). Status promoted to RECOMMENDATION."
  - "1.0.0 (2026-02-10): Phase 1 document with empirical analysis and trade-off assessment."
---
-->

@Metadata {
    @TitleHeading("Swift Primitives Research")
}

Architectural rationale for the primitives' dual-model approach to lifetime-safe borrowed access: yielding accessors as the primary mechanism, returning `~Escapable` values for stdlib Span interop.

## Abstract

This document establishes the architectural rationale for how swift-primitives handles borrowed access to values. Two competing models exist in the Swift ecosystem for lifetime-safe borrowed access:

1. **The Yielding Model**: Lifetime is a property of the *binding*, enforced by control flow (the structural scope of a yielded accessor). No type-level escapability annotation needed.
2. **The Returning Model**: Lifetime is a property of the *type* (`~Escapable`), reconstructed via `@_lifetime` annotations after the value leaves the returning function's stack frame.

The primitives use **both models** — yielding as the dominant pattern (599 yield sites) and returning exclusively for stdlib `Span`/`MutableSpan` interop (28 `_overrideLifetime` sites). This document explains why, quantifies the trade-offs, and establishes a watch list for language evolution that could simplify the architecture.

**Principal Findings**:

1. **The yielding model is the overwhelmingly dominant pattern** in swift-primitives. 599 yield statements, 279 `_read` accessors, 177 `_modify` accessors — covering all collection subscripts, the Property.View pattern, and most borrowed access paths.
2. **The returning model is used surgically** for stdlib Span properties. 28 `_overrideLifetime` calls, each an unsafe bridge required by the returning model. The yielding model does not need this unsafe code.
3. **The closure integration gap is real** and documented independently in package-specific research. Passing `~Escapable` values to closure parameters fails in Swift 6.2. The primitives solved this via protocol dispatch (non-closure runner surface), which is the correct approach under current language constraints.
4. **The dual-model position is pragmatically correct**. The yielding model is simpler and covers more use cases. The returning model is necessary for stdlib API compatibility. Neither model alone suffices.
5. **Borrow/inout bindings** are the language feature most likely to simplify the architecture. When available, they would provide named-variable access to yielded values, eliminating the closure-based workarounds and reducing the ergonomic gap between the two models.

---

## Part I: Context and Scope

### 1.1 Research Trigger

Per [RES-012], this is a **Discovery** research document. The trigger is a Swift Forums discussion ([~Escapable, Span, Ownership Annotations, etc.](https://forums.swift.org/t/escapable-span-ownership-annotations-etc/84566), 32 posts, Feb 4–10 2026) in which Dave Abrahams (former Swift core team, Hylo co-creator) and Dimi Racordon (Hylo co-creator) argued that Swift's trajectory toward a Rust-like lifetime system is unnecessary, and that yielding accessors combined with borrow bindings cover the overwhelming majority of use cases.

The primitives already use the yielding model as their primary approach, but this architectural position has never been explicitly documented. Per [RES-016], design decisions that affect multiple packages and establish precedent MUST have documented rationale.

### 1.2 Scope

Per [RES-002a], this research is **primitives-wide**.

| Criterion | Assessment |
|-----------|------------|
| Packages directly affected | All 125 primitives packages with borrowed access patterns |
| Key packages | property-primitives (Property.View), memory-primitives (Span interop), storage-primitives, buffer-primitives, all collection primitives |
| Tiers spanned | 0 (property, ownership, lifetime) through 19 (cache, pool) |
| Precedent-setting | Yes — documents the lifetime access model for the entire primitives layer |
| Research tier | Tier 2 (cross-package, precedent-setting, but documenting existing practice) |

### 1.3 Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| No Foundation | [PRIM-FOUND-001] | Cannot use Foundation memory management abstractions |
| Swift 6.2 target | Platform skill | Must work within current `@_lifetime` / `~Escapable` capabilities |
| ~Copyable support | Memory skill | All access patterns must handle non-copyable elements |
| Stdlib Span API | SE-0447, SE-0456 | Must expose `.span` / `.mutableSpan` properties matching stdlib convention |
| Downward-only deps | Primitives Tiers | Tier structure cannot change to accommodate model choice |

### 1.4 Methodology

Per [RES-004] and [RES-016]:

| Step | Action | Output |
|------|--------|--------|
| 1 | Characterize the two models | Formal distinction (Section 2) |
| 2 | Quantify codebase usage | Empirical evidence (Section 3) |
| 3 | Analyze the forum thread arguments | External validation (Section 4) |
| 4 | Identify trade-offs of dual approach | Trade-off matrix (Section 5) |
| 5 | Establish watch list | Future evolution guidance (Section 6) |
| 6 | Document rationale | Outcome (Section 7) |

**Phase 2** (complete): Systematic literature review covering academic treatments of substructural type systems, region-based memory, borrowed reference models in Rust, Hylo, and Cyclone, and the full Swift Evolution ownership/lifetime roadmap. See Part VII.

---

## Part II: The Two Models

### 2.1 The Yielding Model

In the yielding model, a coroutine-like accessor suspends execution and exposes a value to a caller-controlled scope. When the scope ends, execution resumes in the accessor and the value is invalidated.

```swift
public subscript(index: Index) -> Element {
    _read {
        yield storage[index]
    }
    _modify {
        yield &storage[index]
    }
}
```

**Lifetime mechanism**: The stack frame of the suspended accessor implies the lifetime. The yielded binding cannot outlive the accessor's scope because control must return through it. No type-level annotation is needed — safety is a structural consequence of the coroutine protocol.

**Formalized** (following dmt, Swift Forums post #23):

```
Given accessor A yielding binding b from arguments (x₁, x₂, ..., xₙ):
  L(b) ⊆ L(A) ⊆ min(L(x₁), L(x₂), ..., L(xₙ))
```

The lifetime of `b` is bounded by the accessor's scope, which is bounded by the shortest-lived argument. This is enforced by control flow, not the type system.

### 2.2 The Returning Model

In the returning model, a function returns a value whose type carries a non-escapability constraint (`~Escapable`), and an explicit annotation (`@_lifetime`) declares which argument's lifetime bounds the return value.

```swift
public var span: Span<Element> {
    @_lifetime(borrow self)
    borrowing get {
        let span = unsafe Span(_unsafeStart: ptr, count: count)
        return unsafe _overrideLifetime(span, borrowing: self)
    }
}
```

**Lifetime mechanism**: The `~Escapable` marker on `Span` prevents the returned value from being stored, returned, or captured by escaping closures. The `@_lifetime(borrow self)` annotation tells the compiler the span borrows from `self`. The compiler must verify at every use site that the span does not outlive the borrowed source.

**Formalized**:

```
Given function f(x₁, ..., xₙ) -> R where R: ~Escapable, @_lifetime(borrow xᵢ):
  L(result) ⊆ L(xᵢ)
```

The lifetime of the result is bounded by the annotated argument. This is enforced by the type system via `~Escapable` and `@_lifetime`.

### 2.3 Key Distinction

The distinction, as articulated by dmt (Swift Forums post #23):

> "In the yielding model, we get safety 'for free' because the stack frame implies the lifetime. In the returning model, we lose that stack context the moment we return a value, so we must reconstruct that safety using a more complex type system."

| Property | Yielding Model | Returning Model |
|----------|---------------|-----------------|
| Lifetime location | Binding (control flow) | Type (`~Escapable` + `@_lifetime`) |
| Safety mechanism | Stack frame containment | Type system reconstruction |
| Unsafe code needed | No | Yes (`_overrideLifetime`) |
| Closure composability | Natural (no capture boundary) | Blocked (closure integration gap in Swift 6.2) |
| Named variable access | Requires borrow bindings (not yet in Swift) | Available today via `let`/`var` |
| Scope-locking | All arguments locked for yield duration | Only annotated arguments locked |

### 2.4 The Scope-Locking Trade-off

When a yielding accessor suspends, *all* arguments are locked (borrowed or exclusively accessed) for the yield's duration. In the returning model, only the argument named in `@_lifetime` is locked.

Example (dmt, post #23):

```swift
subscript sorted<T>(
    x: inout T, y: inout T,
    by comp: borrowing (T, T) -> Bool
) inout -> (T, T) {
    if comp(x, y) { yield (&x, &y) }
    else           { yield (&y, &x) }
}

// While yielded bindings are alive, `comp` is also locked —
// even though the projected tuple doesn't depend on it.
```

In the returning model with named lifetimes, the compiler could see that the result depends on `x` and `y` but not `comp`, allowing `comp` to be released earlier.

**Mitigation** (Alvae, post #24): If scope-locking becomes problematic, `@transient` parameter annotations — marking parameters *not* part of the projection — would be explored before type-level lifetime threading. This is "lifetimes inverted": declaring what's *not* entangled rather than what *is*.

---

## Part III: Empirical Evidence from Swift Primitives

### 3.1 Quantitative Survey

Comprehensive search across all 3,420 Swift source files in swift-primitives:

| Pattern | Occurrences | Model | Notes |
|---------|------------:|-------|-------|
| `yield` keyword | **599** | Yielding | In `_read`, `_modify`, subscripts |
| `_read` accessor | **279** | Yielding | Read-only yielding |
| `_modify` accessor | **177** | Yielding | Read-write yielding |
| `@_lifetime` annotation | **135** | Returning | On span properties, initializers |
| `~Escapable` constraint | **189** (43 files) | Both | Property.View, iterators, Span types |
| `_overrideLifetime` calls | **28** | Returning | Unsafe bridge, each is returning-model debt |

**Ratio**: Yielding model sites outnumber returning model unsafe bridges **21:1**.

### 3.2 The Property.View Pattern: Yielding Model at Scale

The most pervasive pattern in the primitives — appearing **150+ times** — is the `Property.View` pattern, which combines `~Copyable & ~Escapable` view types with yielding accessors:

```swift
// property-primitives (Tier 0)
public struct View: ~Copyable & ~Escapable {
    @usableFromInline
    let base: UnsafeMutablePointer<Base>
}

// Usage across all collection primitives:
public var forEach: Property<Sequence.ForEach>.View {
    mutating _read {
        yield unsafe Property<Sequence.ForEach>.View(&self)
    }
    mutating _modify {
        var view = unsafe Property<Sequence.ForEach>.View(&self)
        yield &view
    }
}
```

This pattern enables fluent APIs like `heap.forEach { }` and `stack.reduce.into(0) { }` while maintaining zero-copy semantics for `~Copyable` elements.

**Observation on `~Escapable`**: Property.View is marked `~Escapable` but is *always* yielded — never returned from a function. The `~Escapable` annotation is defense-in-depth: the yield already scope-locks, and `~Copyable` prevents copying out. The annotation prevents future refactoring from accidentally changing the access pattern to returning without maintaining the lifetime guarantee.

### 3.3 Span Properties: The Returning Model in Practice

The returning model appears exclusively in Span-providing properties:

```swift
// buffer-primitives (Tier 15)
public var span: Span<Element> {
    @_lifetime(borrow self)
    @inlinable
    borrowing get {
        let span = unsafe Span(
            _unsafeStart: storage.pointer(at: .zero),
            count: count
        )
        return unsafe _overrideLifetime(span, borrowing: self)
    }
}
```

Each of the 28 `_overrideLifetime` calls is unsafe code that exists solely because the returning model requires manual lifetime relationship establishment. The yielding model's `_read` accessors handle this automatically.

**Dual accessor pattern**: Several types provide *both* a returning `get` and a yielding `_modify` for `mutableSpan`:

```swift
public var mutableSpan: MutableSpan<Element> {
    @_lifetime(&self)
    mutating get {
        // Returning model: needs _overrideLifetime (unsafe)
        return unsafe _overrideLifetime(span, mutating: &self)
    }
    _modify {
        // Yielding model: direct yield (no unsafe)
        var span = unsafe MutableSpan(
            _unsafeStart: unsafe storage.pointer(at: .zero),
            count: count
        )
        yield &span
    }
}
```

The `get` enables `var s = buffer.mutableSpan` (assignment). The `_modify` enables `buffer.mutableSpan[0] = 42` (in-place mutation). The `_modify` path requires no `_overrideLifetime` — the yield handles lifetime naturally.

### 3.4 The Closure Integration Gap

Package-specific research in swift-memory-primitives (`lifetime-dependent-borrowed-cursors.md`) independently discovered and documented that `~Escapable` values cannot be passed to closure parameters in Swift 6.2:

```swift
// FAILS in Swift 6.2:
func withBorrowed<T>(_ bytes: [UInt8], _ body: (inout Input.View) -> T) -> T {
    var view = Input.View(bytes.span)
    return body(&view)  // ERROR: lifetime-dependent variable escapes
}

// WORKS: protocol dispatch (method call, no capture boundary)
protocol Parser { mutating func parse(_ input: inout Input.View) -> Output }
func withBorrowed<P: Parser>(_ bytes: [UInt8], _ parser: inout P) -> P.Output {
    var view = Input.View(bytes.span)
    return parser.parse(&view)  // OK
}
```

This is the returning model's composability cost — the type system doesn't yet integrate `~Escapable` with closure parameter types. The yielding model avoids this entirely because yielded values never appear in closure parameter positions.

### 3.5 Tier Distribution

The two models concentrate at different tiers:

| Tier Range | Dominant Model | Evidence |
|:----------:|----------------|----------|
| 0–6 | Yielding only | Property.View, ownership closure APIs, subscripts |
| 7–12 | Yielding dominant, some `~Escapable` types | Collection subscripts, iterators, views |
| 13–15 | Both models | Memory/Storage/Buffer: yielding for element access, returning for Span |
| 16–19 | Yielding dominant | Higher-level data structures use lower-tier patterns |

The returning model's complexity (`@_lifetime`, `_overrideLifetime`, closure integration gap) concentrates in **tiers 13–15** where Span interop is implemented. Lower tiers are almost purely yielding.

---

## Part IV: Forum Thread Analysis

### 4.1 Thread Overview

**Thread**: [~Escapable, Span, Ownership Annotations, etc.](https://forums.swift.org/t/escapable-span-ownership-annotations-etc/84566)
**Duration**: February 4–10, 2026 (32 posts)
**Key participants**: Dave Abrahams, Dimi Racordon (Alvae), Dima Galimzianov (dmt), Dmitriy Ignatyev, Filip Sakel, Jon Shier, Keith Bauer (OneSadCookie)

### 4.2 Arguments and Primitives Alignment

| Thread Argument | Source | Primitives Alignment |
|----------------|--------|---------------------|
| "99.9% of uses of ownership can be expressed by yielding subscripts" | Abrahams #1 | **Confirmed**: 599 yield sites vs 28 returning-model sites (95.5% yielding) |
| "Non-escapability is a property of particular values not of types" | Abrahams #29 | **Partially aligned**: Property.View uses type-level `~Escapable` but always yields. Belt-and-suspenders. |
| Yielding accessors are MORE expressive than references in some cases | Alvae #5 (UInt32 MutableCollection) | **Confirmed**: `_modify` accessors synthesize mutable access to computed properties (heap.forEach, stack.reduce) — impossible with returning references |
| Closure integration gap blocks `~Escapable` composability | OneSadCookie #31 | **Independently discovered**: `lifetime-dependent-borrowed-cursors.md` documents this exact problem and solves it via protocol dispatch |
| Scope-locking is acceptable in practice | Abrahams #20, Alvae #24 | **Confirmed**: 599 yield sites with no workarounds for scope-locking, no comments requesting finer-grained unlocking |
| `@transient` parameter annotations could solve scope-locking | Alvae #24, #27 | **Not yet relevant**: No evidence of scope-locking problems in the primitives codebase |
| Borrow/inout bindings would eliminate need for closure-based patterns | Abrahams #4, Alvae #9 | **Applicable**: `Ownership.Unique.withValue { }` and `Lifetime.Lease.value` could use borrow bindings when available |
| Complexity leaks into error messages | Alvae #10 | **Not yet observed**: Primitives targets Swift 6.2+ developers who accept ownership complexity |
| The returning model's unsafe bridges (`_overrideLifetime`) are avoidable | Implicit in yielding advocacy | **Quantified**: 28 unsafe `_overrideLifetime` sites are returning-model-specific. Yielding paths have zero. |

### 4.3 Arguments the Thread Does Not Address

| Aspect | Primitives Reality | Thread Gap |
|--------|-------------------|-----------|
| Property.View pattern | `~Escapable` + `~Copyable` types that are always yielded, never returned | Thread discusses yielding OR returning, not the combination |
| Phantom type tag dispatch | Property.View uses type tags to select API methods on yielded views | Not discussed — a novel application of yielding |
| Unsafe code in yielded view construction | Property.View internally uses `UnsafeMutablePointer` to capture `inout` | Thread focuses on Span; the pointer-in-view pattern has its own trade-offs |
| Stdlib Span API compatibility pressure | Primitives MUST expose `.span`/`.mutableSpan` to follow stdlib convention | Thread treats stdlib direction as changeable; for libraries, it's a constraint |

---

## Part V: Trade-off Analysis

### 5.1 Evaluation Criteria

| Criterion | Weight | Rationale |
|-----------|:------:|-----------|
| Safety (compile-time guarantees) | High | Core goal of the primitives layer |
| Unsafe code surface area | High | Each `unsafe` site is audit burden |
| API ergonomics | Medium | Affects all consumers of primitives types |
| Stdlib compatibility | High | Primitives must interoperate with Swift stdlib |
| Composability | Medium | Closure, async, throws, sending integration |
| Future-proofness | Medium | Resilience to Swift language evolution |
| Implementation simplicity | Medium | Maintenance cost across 125 packages |

### 5.2 Model Comparison

| Criterion | Yielding Model | Returning Model | Dual Model (Current) |
|-----------|---------------|-----------------|---------------------|
| Safety | Structural (control flow) | Type system (`~Escapable` + `@_lifetime`) | Both mechanisms available |
| Unsafe surface | **0** `_overrideLifetime` calls | **28** `_overrideLifetime` calls | 28 calls, all in Span interop |
| API ergonomics | Scope-locked access only; no named variables yet | Named variable assignment (`let s = x.span`) | Best of both per use case |
| Stdlib compatibility | Cannot expose `var span: Span<E>` (stdlib API is property, not accessor) | Full compatibility | Full compatibility |
| Composability | Closures compose naturally; but scope-locking locks all args | Blocked by closure integration gap in 6.2 | Protocol dispatch workaround documented |
| Future-proofness | Borrow bindings add named access. `@transient` solves scope-locking. | Full lifetime system adds power but complexity. | Positioned for either outcome |
| Implementation simplicity | Simple: yield, done | Complex: `@_lifetime` + `_overrideLifetime` + `unsafe` | Concentrated complexity in tiers 13–15 |

### 5.3 The Dual Model as Optimal Position

The primitives cannot use the yielding model exclusively because the Swift stdlib exposes Span via returning properties, and the primitives must match this API surface for interoperability. The primitives cannot use the returning model exclusively because:

1. It requires 28 unsafe bridges that the yielding model avoids
2. The closure integration gap blocks composability for `~Escapable` parameters
3. The Property.View pattern (150+ sites) achieves zero-copy access elegantly via yielding

The dual model minimizes total complexity:
- **Yielding** handles 95.5% of borrowed access paths with zero unsafe code
- **Returning** handles the remaining 4.5% (Span properties) where stdlib compatibility requires it
- If the returning model's limitations are resolved in future Swift, the yielding sites remain correct
- If the yielding model is enhanced (borrow bindings, `@transient`), the returning sites can optionally migrate

---

## Part VI: Watch List

### 6.1 Language Features to Track

| Feature | Status | Impact on Primitives |
|---------|--------|---------------------|
| **Borrow/inout bindings** | Pitched (Feb 2026) | Enables named variables from yielded access: `borrow v = collection[i]`. Would make yielding model fully ergonomic. `Ownership.Unique.withValue { }` gets property equivalent. |
| **`@transient` parameter annotations** | Discussed (Hylo team, not pitched for Swift) | Solves scope-locking without type-level lifetimes. "Lifetimes inverted" — declare what's *not* entangled. |
| **Closure parameter lifetime annotations** | Deferred in SE-0446 | Would close the closure integration gap. `~Escapable` values could be passed to closure parameters. Parser protocol workaround becomes optional. |
| **First-class subscripts** | Discussed in Hylo; not pitched for Swift | Would enable subscript values as parameters, replacing higher-order function patterns. |
| **Yielding accessors (SE-0474)** | Accepted (Swift 6.2) | Already used extensively. Formal standardization of `_read`/`_modify`. |
| **Borrow/mutate accessors (SE-0507)** | Under review (Feb 2026) | Non-coroutine borrowing. Could replace `get` + `@_lifetime` + `_overrideLifetime` for simple Span properties if semantics align. Eliminates coroutine overhead. |

### 6.2 Decision Points

| Trigger | Action |
|---------|--------|
| Borrow bindings accepted into Swift | Add yielding property accessors alongside closure-based APIs in ownership-primitives and lifetime-primitives |
| Closure lifetime annotations land | Re-evaluate Parser protocol workaround; may become unnecessary |
| `@transient` pitched for Swift | Evaluate for Property.View's pointer-based pattern |
| Swift deprecates `_overrideLifetime` | Replace with whatever safe alternative is provided |
| SE-0507 borrow accessors accepted | Evaluate `borrow` as replacement for `get` + `@_lifetime` + `_overrideLifetime` on Span properties |
| Swift team signals yielding-first direction | Audit `~Escapable` on yielded-only types for removal |

### 6.3 Metrics to Track

| Metric | Current | Threshold | Action |
|--------|--------:|-----------|--------|
| `_overrideLifetime` count | 28 | Growth > 50 | Investigate whether returning model is expanding beyond Span interop |
| `~Escapable` on yielded-only types | ~43 files | — | Audit if Swift evolves yielding model |
| Scope-locking workarounds | 0 | Any occurrence | Investigate `@transient` or returning model for that case |

---

## Part VII: Systematic Literature Review

### 7.1 Search Strategy

Per [RES-021], Tier 2+ research MUST include a prior art survey. The search covered:

| Domain | Sources | Key Terms |
|--------|---------|-----------|
| Academic (PL theory) | ACM DL, arXiv, POPL, ICFP, PLDI, OOPSLA, SLE | Region-based memory, substructural types, linear logic, ownership types, borrow checking |
| Language design | Rust RFCs, Hylo spec, Cyclone papers, Swift Evolution | Lifetime parameters, non-escapable, yielding accessors, coroutine accessors |
| Swift ecosystem | Swift Forums, SE proposals, Ownership Manifesto, Accessors Vision | ~Escapable, ~Copyable, Span, borrow bindings, accessor design |

### 7.2 Region-Based Memory Management

The yielding model's intellectual heritage traces to region-based memory management, where allocation scope determines lifetime without type-level annotations.

**Tofte & Talpin (1997)**. "Implementation of the Typed Call-by-Value λ-calculus using a Stack of Regions." *Information and Computation*, 132(2). The foundational work on region inference: the compiler infers allocation regions from program structure, and deallocation follows stack discipline. No programmer annotations needed. This is the theoretical ancestor of Swift's yielding model — lifetime is a structural consequence of scope, not a type property.

**Gay & Aiken (1998)**. "Memory Management with Explicit Regions." *PLDI 1998*. Extended Tofte-Talpin to explicit programmer-controlled regions. Showed regions are competitive with malloc/free and sometimes substantially faster. Established that region-based approaches are practical, not just theoretical.

**Tofte et al. (2004)**. "A Retrospective on Region-Based Memory Management." *Higher-Order and Symbolic Computation*, 17(3). Retrospective showing the region model scales to real programs (ML Kit compiler, 100K+ LOC). Key insight: most allocations have stack-like lifetimes, validating the yielding model's assumption that scope-bounded access covers the common case.

**Grossman et al. (2002)**. "Region-Based Memory Management in Cyclone." *PLDI 2002*. Cyclone is the bridge between Tofte-Talpin and modern ownership systems. It introduced *existential region types* — lifetime variables that appear in types — enabling values to carry region information across function boundaries. This is the earliest ancestor of Swift's `@_lifetime` returning model: when scope alone is insufficient, the type system reconstructs lifetime information.

| System | Model | Annotation Burden | Safety Guarantee |
|--------|-------|-------------------|------------------|
| Tofte-Talpin | Yielding (scope-inferred) | None | Sound region inference |
| Gay-Aiken | Yielding (explicit) | Region names at allocation | Programmer-verified |
| Cyclone | Both (regions + existentials) | Region annotations on types | Type-checked |

**Relevance to primitives**: The primitives' dual model recapitulates this evolution. The yielding model (599 sites) corresponds to Tofte-Talpin's scope-based approach. The returning model (28 sites) corresponds to Cyclone's existential region types. The 21:1 ratio confirms Tofte et al.'s retrospective finding that scope-bounded access dominates.

### 7.3 Substructural Type Systems

`~Copyable` and `~Escapable` are instances of *substructural type systems*, which restrict the structural rules of classical logic.

**Girard (1987)**. "Linear Logic." *Theoretical Computer Science*, 50(1). Introduced linear logic, where each value must be used exactly once. Linear logic provides the theoretical foundation for move semantics: suppressing the contraction rule (no implicit duplication) yields linear types; suppressing weakening (no implicit discard) yields affine types.

**Wadler (1990)**. "Linear Types Can Change the World!" In *Programming Concepts and Methods*. Connected linear logic to programming language design. Demonstrated that linear types enable safe in-place update, deterministic resource management, and uniqueness guarantees — exactly the properties Swift's `~Copyable` provides.

| Structural Rule | Classical | Suppressed | Swift Equivalent |
|-----------------|-----------|------------|------------------|
| Contraction (copy) | `Γ, A, A ⊢ B` implies `Γ, A ⊢ B` | Linear/Affine types | `~Copyable` |
| Weakening (discard) | `Γ ⊢ B` implies `Γ, A ⊢ B` | Relevant types | `~Escapable` (partial) |
| Exchange (reorder) | `Γ, A, B ⊢ C` implies `Γ, B, A ⊢ C` | Ordered types | Not suppressed in Swift |

**Relevance to primitives**: Property.View is `~Copyable & ~Escapable` — simultaneously suppressing contraction and weakening. This makes it a *relevant* type in the substructural hierarchy: it must be used exactly within its scope, cannot be copied, and cannot escape. The yielding model enforces these properties structurally; the type annotations provide redundant defense-in-depth.

### 7.4 Ownership and Borrowing in Rust

Rust's ownership system is the most prominent deployment of the returning model and the primary comparand for Swift's approach.

**Jung et al. (2018)**. "RustBelt: Securing the Foundations of the Rust Programming Language." *POPL 2018*. Formalized Rust's ownership and borrowing in Iris (a higher-order concurrent separation logic framework) and verified in Coq. Proved that Rust's type system is sound — well-typed programs cannot exhibit undefined behavior. Key contribution: formalized the semantic notion of *lifetime* as a token in separation logic, establishing that Rust's lifetime parameters have rigorous theoretical grounding.

**Weiss et al. (2019)**. "Oxide: The Essence of Rust." *arXiv:1903.00982*. Provided a minimal formal operational semantics for Rust's borrow checker. Showed that Rust's safety guarantees can be expressed as a small set of typing rules. This formalization reveals that Rust's system is fundamentally a *returning model*: every reference carries a lifetime parameter, and the borrow checker verifies that references don't outlive their sources.

**Jung et al. (2020)**. "Stacked Borrows: An Aliasing Model for Rust." *POPL 2020*. Formalized Rust's aliasing rules using a per-location stack of permission tags. Each borrow pushes a tag; popping invalidates the borrow. This per-access-site tracking is the operational counterpart of lifetime parameters.

**Villani et al. (2025)**. "Tree Borrows." *PLDI 2025*. Distinguished Paper Award. Replaced Stacked Borrows' stack with a tree structure, reducing false rejections by 54% on 30,000 crates. Formalized in Rocq with proofs that the model enables key compiler optimizations. Demonstrates that the returning model's aliasing semantics remain under active refinement — the rules are not settled.

**Relevance to primitives**: Rust demonstrates the returning model at ecosystem scale. The RustBelt formalization confirms it is sound. However, Tree Borrows' ongoing refinement shows the model's complexity: even after years of production use, the aliasing rules are being revised. Swift's primitives avoid this complexity for 95.5% of access paths by using the yielding model, where aliasing rules are trivially satisfied (the coroutine holds exclusive access).

### 7.5 Hylo: Mutable Value Semantics Without Lifetime Parameters

Hylo (formerly Val), co-designed by Dave Abrahams and Dimi Racordon, is the most direct advocate for the yielding model. The thread participants' arguments are grounded in this body of work.

**Racordon et al. (2021)**. "Native Implementation of Mutable Value Semantics." *ICOOOLPS 2021* (arXiv:2106.12678). Demonstrated that mutable value semantics can compile to efficient native code using stack allocation for static garbage collection. Key insight: if references are second-class (cannot be stored), lifetime analysis is purely flow-sensitive and requires no type-level annotations.

**Racordon et al. (2022)**. "Mutable Value Semantics." *Journal of Object Technology*, 21(2). Full treatment of the programming discipline. References are created only implicitly at function boundaries and cannot be stored in variables or fields. This eliminates the need for Rust-style lifetime parameters. The discipline enables part-wise in-place mutation while maintaining local reasoning.

**Racordon et al. (2022)**. "Implementation Strategies for Mutable Value Semantics." *Journal of Object Technology*, 21(2). Details strategies: stack allocation for fixed-size values, copy-on-write for dynamically-sized containers. Explicit `.copy()` required — no implicit duplication. Demonstrates the ergonomic trade-off: simpler lifetime model requires more explicit copying.

**Racordon & Abrahams (2023)**. "Borrow checking Hylo." *IWACO 2023 (at SPLASH 2023)*. Presents Hylo's borrow checker as an abstract interpreter processing IR with *ghost instructions* (`borrow`, `end_borrow`). No lifetime parameters anywhere. Safety verified by flow-sensitive analysis of live ranges. The paper argues this achieves equivalent safety guarantees to Rust's borrow checker with dramatically simpler programmer-facing model.

**Racordon & Abrahams (2024)**. "Method Bundles." *SLE 2024*. Proposes bundling `let`, `inout`, `sink`, and `set` accessor variants under a single name. This is the generalization of Swift's yielding accessor model: a single subscript definition produces multiple accessor coroutines for different ownership modes. The compiler selects the appropriate variant at each call site.

**Hylo's Four Parameter Conventions**:

| Convention | Swift Equivalent | Ownership |
|------------|-----------------|-----------|
| `let` | `borrowing` | Shared, immutable borrow |
| `inout` | `inout` | Exclusive, mutable borrow |
| `sink` | `consuming` | Ownership transfer |
| `set` | (no equivalent) | Initialization of uninitialized memory |

**Remote parts**: Hylo's experimental mechanism for closure captures. Captured `let` and `inout` bindings function as "remote parts" of the closure type — second-class references stored within the closure's representation. The type system prevents closures with remote parts from escaping their declaring scope. This mirrors the primitives' closure integration gap, but Hylo addresses it at the language level rather than requiring protocol-dispatch workarounds.

**Relevance to primitives**: Hylo's research validates the yielding model's theoretical soundness *and* practical sufficiency. The key papers demonstrate that second-class references + flow-sensitive analysis achieve the same safety guarantees as lifetime parameters. The primitives' 599 yield sites are an independent empirical confirmation of this claim in a production Swift codebase. Hylo's "remote parts" for closures suggests that Swift's closure integration gap is a solvable language design problem, not a fundamental limitation.

### 7.6 Swift Evolution Ownership Roadmap

The Swift Evolution proposals form a coherent multi-year roadmap that the primitives must track.

**Ownership Manifesto (2017)**. Abrahams, Lattner, McCall. Three pillars: Law of Exclusivity (mandatory), shared values (opt-in), non-copyable types (opt-in). The manifesto establishes that Swift's ownership model should be opt-in and backwards-compatible — programmers who ignore ownership should not suffer. This is the philosophical basis for Swift's gradual approach versus Hylo's all-in commitment.

**SE-0377: Parameter Ownership Modifiers (2022)**. Adds `borrowing` and `consuming` keywords for function parameters. Enables ARC optimization by making ownership explicit at API boundaries. Critical for `~Copyable` types where the distinction between borrow and consume is mandatory.

**SE-0390: Noncopyable Structs and Enums (2023)**. Introduces `~Copyable` — suppression of implicit `Copyable` conformance. Move-only types with unique ownership, deterministic cleanup via `deinit`. The foundation that Property.View, Span, and all the primitives' `~Copyable` types build upon.

**SE-0446: Nonescapable Types (2024)**. Introduces `~Escapable` — types that cannot escape their defining scope. Accepted with modifications. *Deferred* lifetime dependency annotations, standard library expansion, and closure integration. The deferral of lifetime annotations is exactly why the primitives use yielding as primary — the returning model requires annotations that weren't available at SE-0446's acceptance.

**SE-0447: Span (2024)**. `Span<Element>`: a `~Escapable`, `Copyable` view of contiguous memory. The canonical returning-model type in the stdlib. Zero-copy, bounds-checked access. This is why the primitives *must* implement Span properties using the returning model.

**SE-0456: Span-Providing Properties (2025)**. Adds `.span` properties to stdlib types. Key insight: when an `Escapable` type returns a `~Escapable & Copyable` value from a computed property getter, the compiler *automatically infers* the borrowing lifetime relationship. No `@_lifetime` annotation required in this common case.

**SE-0474: Yielding Accessors (2025, Swift 6.2)**. Formalizes `_read` and `_modify` as `yielding borrow` and `yielding mutate`. Accepted for Swift 6.2. The primitives use the underscore-prefixed forms; migration to the official syntax is a future task.

**SE-0465: Nonescapable Standard Library Primitives (2025)**. Generalizes `Optional` and `Result` for `~Escapable` wrapped types. `Optional<~Escapable>` becomes itself `~Escapable`. Key limitation: higher-order functions (`map`, `flatMap`) deferred pending lifetime annotation mechanisms.

**SE-0507: Borrow and Mutate Accessors (2026, under review)**. Non-coroutine alternatives to yielding accessors. `borrow` returns a borrowed reference; `mutate` returns a mutable reference — both without coroutine overhead. Completes the Accessors Vision's 6-accessor model:

| Access Kind | Routine (non-coroutine) | Coroutine |
|-------------|------------------------|-----------|
| Copying read | `get` | — |
| Borrowing read | `borrow` (SE-0507) | `yielding borrow` (SE-0474) |
| Modification | `mutate` (SE-0507) | `yielding mutate` (SE-0474) |
| Assignment | `set` | — |

**Lifetime Dependencies (Experimental, Swift 6.2)**. The `@lifetime(borrow x)` / `@lifetime(copy x)` / `@lifetime(immortal)` annotation system. Available behind `-enable-experimental-feature LifetimeDependence`. Not yet formally proposed. This is the missing piece that SE-0446 deferred — once stabilized, it completes the returning model.

**Relevance to primitives**: The roadmap confirms the dual model is the *intended* Swift direction. The yielding model (SE-0474) and returning model (SE-0446 + lifetime dependencies) are both being advanced. SE-0507 adds a third variant (non-coroutine borrowing) that could replace some yielding sites where coroutine overhead matters but finalization is unnecessary.

### 7.7 Cross-System Comparison

Mapping all surveyed systems to the yielding/returning distinction:

| System | Primary Model | Annotations | Safety Mechanism | Closure Support |
|--------|--------------|-------------|------------------|-----------------|
| Tofte-Talpin | Yielding (inferred) | None | Region inference | N/A (ML) |
| Cyclone | Both | Region annotations on types | Type-checked regions | Region-polymorphic closures |
| Rust | Returning | Lifetime parameters (`'a`) | Borrow checker | Lifetime elision; `Fn`/`FnMut`/`FnOnce` |
| Hylo | Yielding | None | Abstract interpretation + ghost IR | Remote parts (experimental) |
| Swift (stdlib) | Returning | `~Escapable`, `@_lifetime` | Borrow checker + lifetime deps | Blocked for `~Escapable` (as of 6.2) |
| **Swift primitives** | **Both (21:1 yielding)** | `~Escapable` on types, `yield` in accessors | Structural (yielding) + type system (returning) | Protocol dispatch workaround |

**Key finding**: No other system deploys both models simultaneously at the scale the primitives do. Cyclone had regions + existentials but in a research language. The primitives demonstrate the dual approach in a production Swift codebase across 125 packages.

### 7.8 Synthesis

The literature review strengthens the Phase 1 findings:

1. **The yielding model has deep theoretical roots**. Tofte-Talpin (1997), Hylo (2021–2024), and the primitives' 599 yield sites all demonstrate that scope-based lifetime management handles the common case without type-level annotations. This is not a pragmatic shortcut — it is a well-studied approach with formal soundness results.

2. **The returning model is the established approach for escaping references**. Cyclone (2002), Rust (2018+), and Swift's `~Escapable` all address the same problem: when a value must leave the scope that created it, the type system must carry lifetime information. RustBelt proves this is sound. The primitives' 28 Span sites are instances of this pattern.

3. **The dual model is novel but well-motivated**. No prior system has deployed both at scale. The primitives' approach is closest to Cyclone's (scope-based + existential), but with a far more favorable ratio (21:1 vs roughly equal in Cyclone). The literature suggests this ratio reflects the true distribution of access patterns.

4. **SE-0507 introduces a third access mode** (non-coroutine borrowing) that could eliminate coroutine overhead for simple property access while preserving borrowing semantics. The primitives should evaluate SE-0507 `borrow` accessors for Span properties as a potential replacement for `get` + `@_lifetime` + `_overrideLifetime`, if the semantics align.

5. **Hylo's remote parts suggest the closure integration gap is solvable**. The gap is a current Swift limitation, not a fundamental impossibility. Hylo's approach (second-class references as closure fields) provides a concrete design that Swift could adopt.

6. **The yielding/returning distinction is formally the CPS transformation**. Yielding accessors are the continuation-passing-style encoding of borrowed references: instead of `func borrow() -> &T` (returning), Swift uses `func borrow(_ body: (borrowing T) -> R) -> R` (yielding). The CPS transformation is well-understood (Sussman & Steele, 1975; Danvy & Filinski, 1992) and preserves semantics while making scope containment syntactically explicit. This is not a workaround — it is a principled encoding with equivalent expressiveness within a bounded scope.

7. **The `~Escapable` / ST monad correspondence is exact**. Launchbury & Peyton Jones (1994) showed that rank-2 polymorphism in the ST monad (`runST :: (forall s. ST s a) -> a`) prevents mutable references from escaping. Swift's `~Escapable` achieves the same via protocol suppression rather than rank-2 types: the caller cannot satisfy `Escapable` for `~Escapable` types, just as the caller cannot name `s` in `runST`. Yielding accessors are the "runST" — they encapsulate the scope where non-escapable values are available.

---

## Part VIII: Outcome

### Status: RECOMMENDATION

Phase 1 (empirical analysis) and Phase 2 (systematic literature review) complete.

### Rationale

The primitives' dual-model approach is the correct architectural position for Swift 6.2:

1. **Yielding is primary**: 599 yield sites, zero unsafe bridges, natural composability. The Property.View pattern is a novel contribution that the broader Swift community has not yet fully explored.

2. **Returning is surgical**: 28 `_overrideLifetime` sites, all in Span interop at tiers 13–15. This is the minimum returning-model surface area required for stdlib compatibility.

3. **The bet is hedged**: If Swift evolves toward the yielding model (borrow bindings, `@transient`), the 28 returning-model sites become simplifiable debt. If Swift evolves toward the returning model (full lifetime system), the yielding sites remain correct and gain additional type-level guarantees.

4. **`~Escapable` on yielded-only types is justified as defense-in-depth**: The annotation is technically redundant when combined with yielding + `~Copyable`, but it prevents future refactoring from accidentally changing access patterns without maintaining lifetime guarantees.

### Recommendations

| Priority | Recommendation | Rationale |
|----------|---------------|-----------|
| **Immediate** | Cross-reference this document in `swift-memory-primitives/Research/lifetime-dependent-borrowed-cursors.md` | The cursor research found the closure integration gap empirically; this document provides the theoretical framework |
| **Immediate** | Track `_overrideLifetime` count as a health metric | Growth indicates returning model expanding beyond Span interop |
| **When available** | Add yielding property accessors when borrow bindings ship | `Ownership.Unique.withValue { }` gains `borrow v = unique.value` equivalent |
| **Do not do** | Do not switch Span properties from returning to yielding | Stdlib API compatibility is a hard constraint |
| **When available** | Evaluate SE-0507 `borrow` accessors for Span properties | Could eliminate `_overrideLifetime` if `borrow` accessor semantics subsume the returning model's annotation overhead |
| **Do not do** | Do not remove `~Escapable` from Property.View | Defense-in-depth is cheap and protects against refactoring accidents |

---

## References

### Swift Forums

1. Abrahams, D. et al. (2026). "~Escapable, Span, Ownership Annotations, etc." Swift Forums. https://forums.swift.org/t/escapable-span-ownership-annotations-etc/84566

### Swift Evolution Proposals

2. SE-0446: Nonescapable Types. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md
3. SE-0447: Span — Safe Access to Contiguous Storage. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md
4. SE-0456: Add Span-providing Properties to Standard Library Types. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md
5. SE-0474: Yielding Accessors. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0474-yielding-accessors.md
6. SE-0377: Parameter Ownership Modifiers. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0377-parameter-ownership-modifiers.md
7. "Borrow and Inout types for safe, first-class references." Swift Forums pitch. https://forums.swift.org/t/borrow-and-inout-types-for-safe-first-class-references/84181

### Swift Primitives Internal Research

8. "Lifetime-Dependent Borrowed Cursors in Swift." swift-memory-primitives/Research/lifetime-dependent-borrowed-cursors.md
9. "Span Access Abstraction." swift-memory-primitives/Research/span-access-abstraction.md
10. "Contiguous Memory Access Standardization." swift-memory-primitives/Research/contiguous-memory-access-standardization.md
11. "Lifetime and Memory Safety: Experiment Results." swift-memory-primitives/Research/Lifetime-Memory-Safety-Plan.md

### Swift Evolution (Additional)

12. SE-0390: Noncopyable Structs and Enums. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md
13. SE-0465: Standard Library Primitives for Nonescapable Types. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md
14. SE-0507: Borrow and Mutate Accessors. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md
15. Abrahams, D. et al. "Ownership Manifesto." https://github.com/swiftlang/swift/blob/main/docs/OwnershipManifesto.md
16. McCall, J. "A Prospective Vision for Accessors in Swift." https://github.com/rjmccall/swift-evolution/blob/accessors-vision/visions/accessors.md
17. "Pitch #2: Lifetime Dependencies for Non-Escapable Values." Swift Forums. https://forums.swift.org/t/pitch-2-lifetime-dependencies-for-non-escapable-values/78821

### Academic Literature

18. Tofte, M. & Talpin, J.-P. (1997). "Implementation of the Typed Call-by-Value λ-calculus using a Stack of Regions." *Information and Computation*, 132(2), 109–161.
19. Gay, D. & Aiken, A. (1998). "Memory Management with Explicit Regions." *PLDI 1998*. https://dl.acm.org/doi/abs/10.1145/277650.277748
20. Tofte, M. et al. (2004). "A Retrospective on Region-Based Memory Management." *Higher-Order and Symbolic Computation*, 17(3). https://link.springer.com/article/10.1023/B:LISP.0000029446.78563.a4
21. Grossman, D. et al. (2002). "Region-Based Memory Management in Cyclone." *PLDI 2002*. https://www.cs.umd.edu/projects/cyclone/papers/cyclone-regions.pdf
22. Girard, J.-Y. (1987). "Linear Logic." *Theoretical Computer Science*, 50(1), 1–102.
23. Wadler, P. (1990). "Linear Types Can Change the World!" In *Programming Concepts and Methods*.
24. Jung, R. et al. (2018). "RustBelt: Securing the Foundations of the Rust Programming Language." *POPL 2018*. https://dl.acm.org/doi/10.1145/3158154
25. Weiss, A. et al. (2019). "Oxide: The Essence of Rust." *arXiv:1903.00982*. https://arxiv.org/abs/1903.00982
26. Jung, R. et al. (2020). "Stacked Borrows: An Aliasing Model for Rust." *POPL 2020*. https://dl.acm.org/doi/10.1145/3371109
27. Villani, N. et al. (2025). "Tree Borrows." *PLDI 2025*. Distinguished Paper. https://iris-project.org/pdfs/2025-pldi-treeborrows.pdf

### Hylo / Val

28. Racordon, D. et al. (2021). "Native Implementation of Mutable Value Semantics." *ICOOOLPS 2021*. arXiv:2106.12678.
29. Racordon, D. et al. (2022). "Mutable Value Semantics." *Journal of Object Technology*, 21(2).
30. Racordon, D. et al. (2022). "Implementation Strategies for Mutable Value Semantics." *Journal of Object Technology*, 21(2).
31. Racordon, D. & Abrahams, D. (2023). "Borrow checking Hylo." *IWACO 2023 at SPLASH 2023*.
32. Racordon, D. & Abrahams, D. (2024). "Method Bundles." *SLE 2024*. https://dl.acm.org/doi/10.1145/3687997.3695633
33. Abrahams, D. et al. (2022). "The Val Object Model." C++ Standards Proposal P2676R0. https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2022/p2676r0.pdf

### Type Theory and CPS

34. Launchbury, J. & Peyton Jones, S. (1994). "Lazy Functional State Threads." *PLDI 1994*. https://homepages.dcc.ufmg.br/~camarao/fp/articles/lazy-state.pdf
35. Fluet, M. & Morrisett, J.G. (2006). "Monadic Regions." *Journal of Functional Programming*, 16(4–5), 485–545. (Conference: ICFP 2004.)
36. Crary, K., Walker, D. & Morrisett, G. (1999). "Typed Memory Management in a Calculus of Capabilities." *POPL 1999*. https://www.cs.cornell.edu/talc/papers/capabilities.pdf
37. Ahmed, A. (2004). "Semantics of Types for Mutable State." PhD thesis, Princeton University.
38. Danvy, O. & Filinski, A. (1992). "Representing Control: A Study of the CPS Transformation." *Mathematical Structures in Computer Science*, 2(4), 361–391.
39. Borretti, F. (2021). "Introducing Austral: A Systems Language with Linear Types and Capabilities." https://austral-lang.org/

### External

40. Abrahams, D. "Efficient Yielding Accessor ABI." Swift Forums. https://forums.swift.org/t/efficient-yielding-accessor-abi/82891/5
