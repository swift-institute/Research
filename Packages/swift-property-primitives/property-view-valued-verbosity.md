# Property View Valued Verbosity

<!--
---
version: 2.0.0
last_updated: 2026-02-12
status: DECISION
tier: 2
---
-->

## Context

Property Primitives (tier 0 in swift-primitives) provides `Property<Tag, Base>` and its nested types for verb-as-property accessors. The type hierarchy enables extension-level constraints for `~Copyable` containers with value generics:

```
Property<Tag, Base>                                   -- Copyable base
Property<Tag, Base>.Typed<Element>                     -- Copyable base + Element
Property<Tag, Base>.View                               -- ~Copyable base
Property<Tag, Base>.View.Typed<Element>                -- ~Copyable base + Element
Property<Tag, Base>.View.Typed<Element>.Valued<n>      -- ~Copyable base + Element + 1 value generic
Property<Tag, Base>.View.Typed<Element>.Valued<n>.Valued<m>  -- ~Copyable + Element + 2 value generics
```

The `Valued` types were added to solve a real compiler constraint: when extending `Property.View.Typed` for a `Base` type with value generics (`<let N: Int>`), putting the `Base ==` constraint at the method level causes the compiler to add an implicit `Base: Copyable` requirement, breaking `~Copyable` support. `Valued<n>` lifts the value generic to the type level, enabling extension-level `where` clauses.

### Trigger

The pattern works correctly (all 333 buffer-primitives tests pass), but declaration-site verbosity is becoming a maintenance concern, especially for types with two value generics. The `.Valued.Valued` chain is already unwieldy, and the question of scalability to 3+ value generics is pressing.

### Scope

This affects all swift-primitives packages that use value generics with `~Copyable` types. Current consumers of `Property.View.Typed.Valued`:

| Package | Types Using `.Valued` | Uses `.Valued.Valued` |
|---------|----------------------|----------------------|
| swift-buffer-primitives | `Buffer.Linked<N>`, `Buffer.Linked<N>.Inline<capacity>`, `Buffer.Linked<N>.Small<inlineCapacity>` | Yes (Inline, Small) |
| swift-array-primitives | `Array.Static<capacity>`, `Array.Small<inlineCapacity>` | No |
| swift-hash-table-primitives | `Hash.Table.Static<bucketCapacity>` | No |
| swift-heap-primitives | `Heap.Static<capacity>`, `Heap.Small<inlineCapacity>` | No |
| swift-bit-vector-primitives | `Bit.Vector.Inline<wordCount>` | No |
| swift-list-primitives | `List.Linked<N>`, `List.Linked.Bounded<N>` | No |

Total: 46 occurrences of `.Valued` across 19 files (source + experiments). 11 occurrences of `.Valued.Valued` across 4 files.

## Question

What alternatives exist to reduce the declaration-site verbosity of `Property.View.Typed.Valued.Valued...` chains, while preserving: (1) `~Copyable` support, (2) extension-level constraints, (3) the clean call-site pattern (`instance.verb.method()`)?

## Analysis

### Option A: Status Quo -- `.Valued<n>.Valued<m>` Chain

The current approach. Each value generic gets its own nested `Valued` type. The chain grows linearly with the number of value generics.

**Accessor return type (1 value generic):**
```swift
public var insert: Property<Insert, Self>.View.Typed<Element>.Valued<N>
```

**Accessor return type (2 value generics):**
```swift
public var insert: Property<Buffer<Element>.Linked<N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>
```

**Extension declaration (2 value generics):**
```swift
extension Property.View.Typed.Valued.Valued
where Tag == Buffer<Element>.Linked<n>.Insert,
      Base == Buffer<Element>.Linked<n>.Inline<m>,
      Element: ~Copyable
```

**Advantages:**
- Proven correct: all 333 tests pass, confirmed in experiments.
- Each `Valued` type is simple (single `UnsafeMutablePointer<Base>` field, ~Copyable, ~Escapable).
- Extension declarations are uniform: always `Property.View.Typed.Valued[.Valued]`.
- No macro dependencies, no protocol machinery, no additional indirection.
- The naming (`Typed`/`Valued`) is semantically clear: parameterized by type vs value.

**Disadvantages:**
- Verbosity grows linearly: 3 value generics would require `.Valued.Valued.Valued`.
- Accessor body repeats the full type path 2-3 times (`_read`, `_modify`, and the return type).
- Each new `Valued` level requires a new file in property-primitives (though the file is trivial).
- Reading the return type requires counting `.Valued` nesting to determine arity.

---

### Option B: Variadic Value Generics

A single `Valued` type that accepts multiple value generics, e.g., `Property.View.Typed.Valued<n, m>`.

**What it would look like:**
```swift
// Hypothetical
public var insert: Property<Insert, Self>.View.Typed<Element>.Valued<N, capacity>

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Linked<n>.Insert,
      Base == Buffer<Element>.Linked<n>.Inline<m>,
      Element: ~Copyable
```

**Swift language status:**
- SE-0452 (Integer Generic Parameters) explicitly lists "Integer parameter packs" as a **future direction**: "It would be natural to extend the feature to support variadic packs of integer parameters, similar to how variadic type parameter packs work."
- This is **not implemented** in Swift 6.0, 6.1, or 6.2. There is no timeline.
- Even if implemented, the compiler behavior with `~Copyable` constraints on variadic value generics would be untested territory.

**Advantages:**
- Most compact syntax: eliminates all `.Valued` chaining.
- Scales to arbitrary N value generics without nesting.
- Extension declarations are identical regardless of value generic count.

**Disadvantages:**
- **Does not exist.** Cannot be used today or in any foreseeable Swift release.
- Would require parameter pack syntax for value generics, which has not been pitched.
- How value parameter packs would interact with `where` clauses binding individual elements (e.g., mapping `n` to `N` in `Buffer.Linked<N>`) is entirely unspecified.

**Verdict: Not viable.** This is the ideal long-term solution but is blocked by Swift language evolution. Should be revisited when/if SE-0452 adds value parameter packs.

---

### Option C: Typealiases at the Consumer

Each consumer type defines a typealias that shortens the `Property` prefix. The heap-primitives package already uses this pattern:

```swift
// Already exists in Heap.Small:
public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap<Element>.Small<inlineCapacity>>

// Enables shorter accessor return types:
public var remove: Property<Remove>.View.Typed<Element>.Valued<inlineCapacity>
// vs:
public var remove: Property_Primitives.Property<Remove, Self>.View.Typed<Element>.Valued<inlineCapacity>
```

**What it would look like for buffer-primitives:**

For `Buffer.Linked<N>` (1 value generic):
```swift
extension Buffer.Linked where Element: ~Copyable {
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Buffer<Element>.Linked<N>>
}

// Accessor becomes:
public var insert: Property<Insert>.View.Typed<Element>.Valued<N>
// Instead of:
public var insert: Property<Insert, Self>.View.Typed<Element>.Valued<N>
```

For `Buffer.Linked<N>.Inline<capacity>` (2 value generics):
```swift
extension Buffer.Linked.Inline where Element: ~Copyable {
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Buffer<Element>.Linked<N>.Inline<capacity>>
}

// Accessor becomes:
public var insert: Property<Insert>.View.Typed<Element>.Valued<N>.Valued<capacity>
// Instead of:
public var insert: Property<Buffer<Element>.Linked<N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>
```

Note: This **only** shortens the `Property<Tag, Base>` prefix by fixing `Base`. The `.View.Typed<Element>.Valued<N>.Valued<capacity>` suffix remains unchanged.

**Advantages:**
- Already proven in heap-primitives (established pattern).
- No changes to property-primitives itself.
- Reduces repetition of the `Self` type in accessor bodies.
- Additive change: can be adopted incrementally per-package.

**Disadvantages:**
- Does not reduce the `.Valued` chain itself.
- Savings are modest: the `Tag` parameter often expands to a long type anyway (e.g., `Buffer<Element>.Linked<N>.Insert`).
- Each consumer type needs its own typealias extension.
- Extension declarations (`extension Property.View.Typed.Valued`) are unchanged -- they already use the short form.

---

### Option D: Single Generic `Valued` with Phantom Tuple

Instead of chaining `.Valued<n>.Valued<m>`, use a single `Valued` with a phantom marker type that carries multiple value generics.

**Hypothetical approach 1 -- Tuple of value generics:**
```swift
// This does NOT compile in Swift:
struct Valued<let values: (Int, Int)>: ~Copyable, ~Escapable { ... }
```
Swift's value generics (SE-0452) only support `let name: Int`. Tuple-valued generics are not supported.

**Hypothetical approach 2 -- Phantom struct:**
```swift
struct Values2<let n: Int, let m: Int> {}

struct Valued<V>: ~Copyable, ~Escapable {
    let _base: UnsafeMutablePointer<Base>
}

// Usage:
Property.View.Typed.Valued<Values2<N, capacity>>
```

This compiles structurally but the extension would need:
```swift
extension Property.View.Typed.Valued
where Tag == ..., Base == ..., V == Values2<n, m>
```

The problem: `V` is a type parameter, not a value generic. You cannot write `where V == Values2<n, m>` because `n` and `m` are not in scope at the extension level -- they would need to be value generics on the extension itself, which requires parameterized extensions (not yet in Swift).

**Advantages:**
- Eliminates nesting depth: always exactly `.View.Typed.Valued<...>`.
- Semantically clear: the phantom type carries the values.

**Disadvantages:**
- **Does not work with current Swift.** Cannot extract individual value generics from a phantom type in extension `where` clauses.
- Would require parameterized extensions or value parameter packs -- same blockers as Option B.
- Adds a phantom type (`Values2`) with no behavioral purpose, violating intent-over-mechanism.

**Verdict: Not viable.** Blocked by the same language limitations as Option B.

---

### Option E: Protocol-Based Approach

Define a protocol that value-generic types conform to, providing value generic metadata. Extensions constrain on the protocol instead of chaining `Valued` types.

**What it would look like:**
```swift
protocol ValueGenericContainer: ~Copyable {
    associatedtype Element: ~Copyable
    static var valueGeneric1: Int { get }
}

protocol ValueGenericContainer2: ValueGenericContainer {
    static var valueGeneric2: Int { get }
}

// Conformance:
extension Buffer.Linked: ValueGenericContainer {
    static var valueGeneric1: Int { N }
}

// Extension:
extension Property.View.Typed
where Base: ValueGenericContainer, Tag == Base.Insert, Element: ~Copyable
{
    // N available via Base.valueGeneric1
}
```

**Problem:** This replaces the compiler constraint that `.Valued` solves. The whole reason `.Valued` exists is that method-level constraints on `Base ==` for value-generic `~Copyable` types add an implicit `Base: Copyable`. A protocol-based approach would need to similarly avoid method-level `Base ==` constraints, but protocol constraints (`where Base: SomeProtocol`) also have `Copyable` requirements unless the protocol is marked `~Copyable`.

Even if the protocol is `~Copyable`, the associated type `Element: ~Copyable` creates additional constraint complexities. And fundamentally, the value generics are not accessible as associated types or static properties in extension `where` clauses -- they are compile-time constants that need to appear in type signatures.

**Advantages:**
- Conceptually clean: group value-generic types by protocol.
- Hides the number of value generics behind a protocol interface.

**Disadvantages:**
- **Does not solve the core problem.** The compiler's implicit `Copyable` constraint on method-level `Base ==` constraints would still apply.
- Protocols cannot carry value generics (no `associatedtype let N: Int`).
- Static properties are not available in `where` clauses.
- Adds protocol complexity without reducing the fundamental nesting.
- Untested: the interaction between `~Copyable` protocols, associated types, and value generics is fragile compiler territory.

**Verdict: Not viable.** Protocols cannot carry value generics, and the core `Copyable` constraint problem is not addressed.

---

### Option F: Macro-Generated Views

A Swift macro that generates the `Property.View` boilerplate. The macro reads the type's value generics and emits the correct `Valued` chain, accessor body, and extension declarations.

**What it would look like:**
```swift
@PropertyView(tag: Insert, element: Element, values: N, capacity)
extension Buffer.Linked.Inline where Element: ~Copyable {
    // Macro generates:
    // public var insert: Property<...>.View.Typed<Element>.Valued<N>.Valued<capacity> { ... }
}

@PropertyExtension(tag: Insert, base: Buffer<Element>.Linked<n>.Inline<m>)
extension Property.View.Typed.Valued.Valued where ... {
    // Developer writes only the method bodies
}
```

**Advantages:**
- Declaration-site verbosity disappears from the source code the developer reads.
- Could encode best practices (correct `_read`/`_modify` patterns, `@_lifetime`, `@inlinable`).
- Scales to any number of value generics.

**Disadvantages:**
- **Significant infrastructure investment.** Requires creating a macro package, which property-primitives (tier 0) cannot depend on (macros are heavyweight, require SwiftSyntax).
- Macros cannot generate extensions on types from other modules. An attached macro on `Buffer.Linked.Inline` could generate the accessor, but not the `extension Property.View.Typed.Valued.Valued` -- that lives in a different type's namespace.
- Debugging becomes harder: the actual code is hidden behind macro expansion.
- Adds build complexity and compile time (SwiftSyntax dependency).
- The boilerplate is predictable but each instance has unique constraints and method signatures. A macro would need many parameters to capture the variability, potentially being as verbose as the code it generates.
- Tier 0 packages must have zero dependencies. A macro dependency violates [PRIM-ARCH-002].

**Verdict: Not viable for property-primitives itself.** Could theoretically be provided as a separate package for consumers, but the benefit/complexity ratio is poor given the small amount of boilerplate per accessor.

---

### Option G: Flattened View Hierarchy

Instead of nesting (`.View.Typed.Valued.Valued`), provide flat entry points like `Property.ViewTyped1<Tag, Base, Element, N>` (one value generic) and `Property.ViewTyped2<Tag, Base, Element, N, M>` (two value generics).

**What it would look like:**
```swift
// In property-primitives:
extension Property where Base: ~Copyable {
    struct ViewTyped1<Element: ~Copyable, let n: Int>: ~Copyable, ~Escapable {
        let _base: UnsafeMutablePointer<Base>
        // ...
    }

    struct ViewTyped2<Element: ~Copyable, let n: Int, let m: Int>: ~Copyable, ~Escapable {
        let _base: UnsafeMutablePointer<Base>
        // ...
    }
}

// Accessor:
public var insert: Property<Insert, Self>.ViewTyped2<Element, N, capacity>

// Extension:
extension Property.ViewTyped2
where Tag == Buffer<Element>.Linked<n>.Insert,
      Base == Buffer<Element>.Linked<n>.Inline<m>,
      Element: ~Copyable
```

**Advantages:**
- Shorter accessor return types: `.ViewTyped2<Element, N, capacity>` vs `.View.Typed<Element>.Valued<N>.Valued<capacity>`.
- Extension declarations have shallower nesting: `Property.ViewTyped2` vs `Property.View.Typed.Valued.Valued`.
- No language feature dependencies -- works today.
- Each flat type is self-contained and independently documented.

**Disadvantages:**
- **Violates [API-NAME-001] and [API-NAME-002].** `ViewTyped1` and `ViewTyped2` are compound identifiers. The numeric suffix is mechanism-oriented, not intent-oriented.
- Creates parallel type hierarchies: `View.Typed.Valued` and `ViewTyped1` serve the same purpose.
- Adding a new arity (3 value generics) requires a new type (`ViewTyped3`) rather than just nesting.
- Loses the compositional semantics: `.View.Typed.Valued` reads as "view, then typed, then valued" -- each layer adds one dimension. Flat types lose this narrative.
- Naming is poor: what do you call these? `View1`, `View2`? `ViewV`, `ViewVV`? None are good names.

**Verdict: Not recommended.** The naming problems are serious and violate established conventions. The verbosity savings are modest (depth 2 instead of 4-5) and come at the cost of compositional clarity.

---

### Option H: Hybrid Typealias Strategy (Consumer-Side + Accessor Shorthand)

Combine Option C (consumer typealiases) with a deeper typealias strategy that also aliases the `.View.Typed` suffix. Each consumer defines multiple typealiases covering the full chain.

**What it would look like:**
```swift
extension Buffer.Linked where Element: ~Copyable {
    // Full typealias chain:
    typealias Property<Tag> = Property_Primitives.Property<Tag, Buffer<Element>.Linked<N>>
    typealias PropertyView<Tag> = Property<Tag>.View.Typed<Element>.Valued<N>
}

// Accessor becomes very short:
public var insert: PropertyView<Insert> {
    mutating _read {
        yield unsafe PropertyView<Insert>(&self)
    }
    mutating _modify {
        var view = unsafe PropertyView<Insert>(&self)
        yield &view
    }
}
```

For 2 value generics:
```swift
extension Buffer.Linked.Inline where Element: ~Copyable {
    typealias PropertyView<Tag> = Property_Primitives.Property<Tag, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>
}

// Accessor:
public var insert: PropertyView<Buffer<Element>.Linked<N>.Insert> {
    mutating _read {
        yield unsafe PropertyView<Buffer<Element>.Linked<N>.Insert>(&self)
    }
}
```

**Critical compiler concern:** The `Tag` parameter in `PropertyView<Tag>` propagates through `.View.Typed.Valued`. If the typealias introduces an additional generic constraint layer, the compiler might re-introduce the implicit `Copyable` requirement -- the exact problem `Valued` was designed to solve. **This must be experimentally verified before adoption.**

**Advantages:**
- Dramatically shorter accessor declarations (return type is single word + angle bracket).
- Accessor bodies become readable.
- No changes to property-primitives.
- Typealiases are local to each consumer -- no cross-package impact.

**Disadvantages:**
- **Does not shorten extension declarations.** You cannot write `extension PropertyView` because typealiases cannot introduce new extension targets in Swift. Extensions must still use the fully qualified `extension Property.View.Typed.Valued`.
- Each consumer type needs its own typealias extension (2+ lines of boilerplate).
- The `Tag` in `PropertyView<Tag>` is often itself a long type (`Buffer<Element>.Linked<N>.Insert`).
- **Compiler risk:** untested whether typealiases through the `.Valued` chain preserve `~Copyable` correctness.
- Extension declarations -- which are the primary verbosity concern -- remain unchanged.

---

### Option I: Accept Verbosity, Standardize Formatting

Rather than changing the type hierarchy, establish formatting conventions that make the existing verbosity manageable.

**Formatting convention for accessors:**
```swift
// Multi-line return type for readability:
public var insert:
    Property<Buffer<Element>.Linked<N>.Insert, Self>
    .View.Typed<Element>.Valued<N>.Valued<capacity>
{
    mutating _read {
        yield unsafe .init(&self)
    }
    mutating _modify {
        var view = unsafe Self.PropertyView(&self)  // hypothetical shorthand
        yield &view
    }
}
```

**Use `.init` instead of repeating the type:**
```swift
mutating _read {
    yield unsafe .init(&self)  // type inferred from return type
}
```

**Formatting convention for extensions:**
```swift
// One constraint per line:
extension Property.View.Typed.Valued.Valued
where
    Tag == Buffer<Element>.Linked<n>.Insert,
    Base == Buffer<Element>.Linked<n>.Inline<m>,
    Element: ~Copyable
{
```

**Advantages:**
- Zero infrastructure changes.
- `.init` shorthand eliminates the repeated type in `_read` bodies (proven to work in experiments).
- Multi-line formatting makes the chain scannable.
- Can be adopted immediately, no migration.

**Disadvantages:**
- Does not actually reduce the character count -- just reformats it.
- Extension declarations remain long regardless of formatting.
- `.init` in `_modify` bodies may not work due to `var` binding requirements.

---

### Option J: Tag Enum Carries Its Own View Typealias

Instead of creating separate typealiases (`Prop<Tag>`, `PropertyView<Tag>`) that introduce indirection, place a `View` typealias directly on the tag enum. The tag enum already exists (e.g., `Insert`, `Remove`); it is the natural home for the type it expands to.

**What it looks like (1 value generic):**
```swift
extension Buffer.Linked where Element: ~Copyable {
    public enum Insert {
        public typealias View = Property<Insert, Buffer<Element>.Linked<N>>.View.Typed<Element>.Valued<N>
    }

    public enum Remove {
        public typealias View = Property<Remove, Buffer<Element>.Linked<N>>.View.Typed<Element>.Valued<N>
    }
}

// Accessor:
public var insert: Insert.View {
    mutating _read {
        yield unsafe .init(&self)
    }
    mutating _modify {
        var view: Insert.View = unsafe .init(&self)
        yield &view
    }
}
```

**What it looks like (2 value generics, child type reusing parent's tag):**
```swift
extension Buffer.Linked.Inline where Element: ~Copyable {
    public enum Insert {
        public typealias View = Property<Buffer<Element>.Linked<N>.Insert, Buffer<Element>.Linked<N>.Inline<capacity>>.View.Typed<Element>.Valued<N>.Valued<capacity>
    }

    public enum Remove {
        public typealias View = Property<Buffer<Element>.Linked<N>.Remove, Buffer<Element>.Linked<N>.Inline<capacity>>.View.Typed<Element>.Valued<N>.Valued<capacity>
    }
}

// Accessor — identical pattern:
public var insert: Insert.View {
    mutating _read { yield unsafe .init(&self) }
    mutating _modify { var v: Insert.View = unsafe .init(&self); yield &v }
}
```

**Key insight:** The verbose chain is written exactly once, at the one place it belongs — the tag enum definition. Every use site reads as `Insert.View` or `Remove.View`. The reader who wants to know what `Insert.View` expands to looks at the tag enum — the same place they already look to understand what `Insert` means.

**Why this is better than Option H (standalone typealiases):**
- No `Prop`/`PropertyView` names to invent — just `Insert.View` (immediately obvious).
- No separate typealias extensions cluttering the file — the tag enum was already there.
- No indirection: `Insert.View` is discoverable via "look at the tag."
- The typealias name (`View`) is semantically correct — it IS the Property View for this tag.

**Advantages:**
- Dramatically shorter accessor declarations: `Insert.View` replaces the full chain.
- Accessor bodies use `.init(&self)` shorthand — zero repetition of the type.
- No new infrastructure, no new types, no macros, no protocols.
- The verbose chain is written once per tag, read never (unless you go looking).
- Works today (Swift 6.2). Experimentally validated with all combinations.
- Additive, non-breaking change. Each type can be migrated independently.
- `Insert.View` reads as intent — "the view for insert operations."
- Convention-compliant: no compound identifiers, no naming violations.

**Disadvantages:**
- Does not shorten extension declarations. `extension Property.View.Typed.Valued` remains verbose.
- Child types that reuse a parent's tag must define local enums (e.g., `Buffer.Linked.Inline.Insert` carrying `View` for the Inline type, separate from `Buffer.Linked.Insert`). This is a one-time cost.
- The typealias is still a typealias — the verbose chain exists, it's just located at the tag definition.

**Experimentally validated:** Experiment `valued-verbosity-best-of-all-worlds` Variant 10: TagContainer (1 value generic, insert + remove), Copyable overload, TagContainer2 (2 value generics) — all 4 sub-variants CONFIRMED. Applied to buffer-primitives: all 333 tests pass.

### Comparison

| Criterion | A: Status Quo | B: Variadic | C: Typealias (Prefix) | D: Phantom Tuple | E: Protocol | F: Macro | G: Flat | H: Typealias (Full) | I: Formatting | **J: Tag Enum View** |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Accessor verbosity | Poor | Excellent | Moderate | Good | Poor | Excellent | Good | Good | Moderate | **Excellent** |
| Extension verbosity | Poor | Excellent | Poor | Good | Poor | Moderate | Good | Poor | Poor | Poor |
| Call-site clarity | Excellent | Excellent | Excellent | Excellent | Excellent | Excellent | Excellent | Excellent | Excellent | **Excellent** |
| ~Copyable correctness | Proven | Unknown | Proven | Unknown | Untested | Proven | Likely | Unknown | Proven | **Proven** |
| Scalability (N values) | Linear growth | Constant | Linear growth | N/A | N/A | Constant | Per-arity type | Linear growth | Linear growth | Linear growth |
| Compiler compatibility | Swift 6.2 | Future Swift | Swift 6.2 | Future Swift | Risky | Swift 6.2 | Swift 6.2 | Swift 6.2 | Swift 6.2 | **Swift 6.2** |
| Infrastructure impact | None | None | None | None | New protocols | New package | New types | None | None | **None** |
| Consumer migration | None | All consumers | Per-package | All consumers | All consumers | All consumers | All consumers | Per-package | Per-package | **Per-package** |
| Convention compliance | Yes | N/A | Yes | No | No | No (tier 0) | No ([API-NAME]) | Yes | Yes | **Yes** |
| Discoverability | N/A | N/A | Poor (name?) | N/A | N/A | N/A | N/A | Poor (name?) | N/A | **Excellent** |
| Works today | Yes | **No** | Yes | **No** | **No** | **No** (tier 0) | Yes | Yes | Yes | **Yes** |

### Constraint Analysis

The following constraints eliminate options:

1. **Swift language limitation** eliminates Options B and D. Value parameter packs and tuple-valued generics do not exist.
2. **`~Copyable` correctness** eliminates Option E. Protocols cannot carry value generics, and the implicit `Copyable` constraint problem is not addressed.
3. **Tier 0 dependency constraint** ([PRIM-ARCH-002]) eliminates Option F. Property-primitives cannot depend on a macro package.
4. **Naming conventions** ([API-NAME-001], [API-NAME-002]) eliminates Option G. Compound identifiers like `ViewTyped2` are forbidden.

This leaves Options A (status quo), C (prefix typealias), H (full typealias), and I (formatting) as viable.

## Outcome

**Status**: DECISION

### Decision: Option J (Tag Enum Carries View) + Option I (Formatting)

The chosen approach places a `View` typealias on each tag enum. The verbose `Property<Tag, Base>.View.Typed<Element>.Valued<N>` chain is written once at the tag definition. All accessor sites use `Insert.View` / `Remove.View`.

Combined with Option I (`.init(&self)` shorthand, multi-line extension formatting), this produces the cleanest viable result.

**Options C (prefix typealias) and H (full typealias) are superseded.** They introduce names (`Prop`, `PropertyView`) that are less discoverable than `Insert.View` and add indirection without a natural home. The tag enum is the natural home: the reader who wants to know what `Insert.View` is looks at `Insert` — the same place they already look to understand the tag.

### What the pattern looks like in practice

**Before (status quo):**
```swift
public var insert: Property<Insert, Self>.View.Typed<Element>.Valued<N> {
    mutating _read {
        yield unsafe Property<Insert, Self>.View.Typed<Element>.Valued<N>(&self)
    }
    mutating _modify {
        var view = unsafe Property<Insert, Self>.View.Typed<Element>.Valued<N>(&self)
        yield &view
    }
}
```

**After (tag-enum-carries-View):**
```swift
public enum Insert {
    public typealias View = Property<Insert, Buffer<Element>.Linked<N>>.View.Typed<Element>.Valued<N>
}

public var insert: Insert.View {
    mutating _read {
        yield unsafe .init(&self)
    }
    mutating _modify {
        var view: Insert.View = unsafe .init(&self)
        yield &view
    }
}
```

The accessor body went from 3 repetitions of the full chain to zero.

### Rationale

The core insight is that the verbosity problem has **two distinct dimensions**:

- **Accessor verbosity** (return type + body): Solved by Option J. `Insert.View` replaces the full chain in all three positions (return type, `_read` body, `_modify` body). `.init(&self)` eliminates the remaining repetition.
- **Extension verbosity** (the `extension Property.View.Typed.Valued where ...` header): Cannot be reduced by any viable option today. But this is written once per verb per type and read infrequently.

Options B, D, E, F, and G all attempt to reduce extension verbosity, but none are viable with current Swift. The extension declaration is inherently verbose because it must bind `Tag`, `Base`, and `Element` with specific types that include value generics — no amount of aliasing can shorten that binding without either (a) language features that do not exist, or (b) violating naming conventions.

Option J was chosen over Options C/H because:
1. **No naming problem.** `Insert.View` is self-evident. `Prop<Tag>` and `PropertyView<Tag>` are not.
2. **No indirection.** The typealias lives on the tag enum, which the reader already knows about.
3. **No separate declaration.** The tag enum was already there; adding `View` to it is a one-line change.
4. **Discoverable.** "What's the view type for Insert?" → look at `Insert.View`.

The verbosity is the honest cost of supporting `~Copyable` containers with value generics while maintaining clean call sites. Option J minimizes the cost at the accessor level, which is where developers spend most of their reading time.

### Validation

- **Experiment:** `valued-verbosity-best-of-all-worlds` — 13 variants (V1–V9 + V10a–V10d), all CONFIRMED.
  - V10a: 1 value generic, insert + remove with tag-enum-View
  - V10b: Remove operations
  - V10c: Copyable overload coexistence
  - V10d: 2 value generics (`.Valued.Valued`)
- **Production:** Applied to `buffer-primitives` — 3 files modified, all 333 tests pass.
  - `Buffer.Linked ~Copyable.swift`: Modified existing tag enums to include `View` typealias
  - `Buffer.Linked.Inline ~Copyable.swift`: Added local `Insert`/`Remove` enums with `View` typealiases
  - `Buffer.Linked.Small ~Copyable.swift`: Added local `Insert`/`Remove` enums with `View` typealiases

### Child type pattern

When a child type (e.g., `Buffer.Linked.Inline`) reuses a parent's tag (`Buffer.Linked.Insert`), define local enums that carry the View typealias for the child's specific Property type:

```swift
extension Buffer.Linked.Inline where Element: ~Copyable {
    public enum Insert {
        public typealias View = Property<Buffer<Element>.Linked<N>.Insert, Buffer<Element>.Linked<N>.Inline<capacity>>
            .View.Typed<Element>.Valued<N>.Valued<capacity>
    }
}
```

The local `Buffer.Linked.Inline.Insert` is distinct from `Buffer.Linked.Insert` — it exists solely to carry the View typealias. The actual tag type used in the Property is still the parent's `Buffer.Linked.Insert`.

### Future Direction

When Swift adds value parameter packs (a future direction explicitly mentioned in SE-0452), Option B should be re-evaluated. A single `Valued<each n: Int>` type could replace the entire chain:

```swift
// Future Swift (hypothetical):
Property.View.Typed.Valued<N, capacity>  // replaces .Valued<N>.Valued<capacity>
```

This would eliminate the need for `Property.View.Typed.Valued.Valued.swift` and all higher-arity files, and would make extension declarations uniform regardless of value generic count. The tag-enum-View pattern would still apply — `Insert.View` would simply expand to a shorter type. Monitor SE-0452 evolution for this capability.

### Implementation Steps

1. For each consumer type with tag enums and `Property.View.Typed.Valued` accessors:
   - Add `typealias View = ...` to each tag enum (or create local tag enums for child types).
   - Update accessor return types to use `TagEnum.View`.
   - Update `_read` bodies to `yield unsafe .init(&self)`.
   - Update `_modify` bodies to `var view: TagEnum.View = unsafe .init(&self); yield &view`.

2. Extension declarations (`extension Property.View.Typed.Valued where ...`) remain unchanged — they already use the short form and cannot be shortened.

3. These are non-breaking, additive changes. Each package can be migrated independently.

## Prior Art

### Swift Evolution

- **SE-0452** (Integer Generic Parameters): Introduces `let N: Int` value generics. Future directions include value parameter packs, which would directly address this verbosity.
- **SE-0393** (Value and Type Parameter Packs): Enables variadic type generics but does not cover value generics.
- **SE-0427** (Noncopyable Generics): Introduces `~Copyable` constraints. The implicit `Copyable` requirement on method-level constraints is the root cause of the `Valued` workaround.
- **SE-0361** (Extensions on Bound Generic Types): Enables `extension Array<String>` syntax. Does not provide parameterized extensions.
- **Parameterized Extensions pitch** (Swift Forums): Would allow `extension <T> Array<Optional<T>>`. Not yet proposed. Would help but not fully solve the problem.

### Related Languages

- **Rust const generics**: `impl<const N: usize, const M: usize> Foo<N, M>` -- Rust allows multiple const generic parameters on a single type, which is exactly the capability Swift lacks for this use case.
- **C++ non-type template parameters**: `template<int N, int M> class Foo` -- C++ has had this capability since templates were introduced. The Swift `Valued` chain is essentially manually encoding what C++ and Rust provide at the language level.

## References

- [SE-0452: Integer Generic Parameters](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md)
- [SE-0393: Value and Type Parameter Packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md)
- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0361: Extensions on Bound Generic Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0361-bound-generic-extensions.md)
- [Parameterized Extensions Pitch](https://forums.swift.org/t/parameterized-extensions/25563)
- Experiment: `swift-property-primitives/Experiments/view-typed-overload-coexistence/` (confirms `.Valued.Valued` compiles and runs)
- Experiment: `swift-property-primitives/Experiments/valued-verbosity-best-of-all-worlds/` (validates all 10 options including tag-enum-View)
- Experiment: `swift-array-primitives/Experiments/property-view-value-generics/` (confirms single `.Valued` pattern)
