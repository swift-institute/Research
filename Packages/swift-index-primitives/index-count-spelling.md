# Index Count Spelling

<!--
---
version: 1.0.0
last_updated: 2026-03-23
status: RECOMMENDATION
tier: 2
---
-->

## Context

The bare-to-tagged audit upgrades bare `Cardinal` and `Ordinal` stored properties and protocol requirements to phantom-tagged equivalents. The canonical upgrade for `Finite.Enumerable` would be:

```swift
// Current — bare
public protocol Enumerable: CaseIterable, Sendable {
    static var count: Cardinal { get }
    var ordinal: Ordinal { get }
    init(__unchecked: Void, ordinal: Ordinal)
}

// Upgraded — tagged
public protocol Enumerable: CaseIterable, Sendable {
    static var count: Index<Self>.Count { get }
    var ordinal: Index<Self> { get }
    init(__unchecked: Void, ordinal: Index<Self>)
}
```

The upgrade is semantically correct: `count` IS always "a count of Self," and `ordinal` IS always "a position in Self-space." But the spelling `Index<Self>.Count` raises a question: is this the best way to name the phantom-tagged cardinal type, or would an alternative spelling improve clarity and reduce verbosity?

### How the types resolve

The current type hierarchy:

```
Index<T>        = Tagged<T, Ordinal>                    (typealias in Index.swift)
Index<T>.Count  = Tagged<T, Cardinal>                   (via Ordinal.Protocol.Count)
Index<T>.Offset = Tagged<T, Affine.Discrete.Vector>     (via Ordinal.Protocol... TBD)
```

`Index<T>.Count` is NOT a nested struct. It resolves through `Ordinal.Protocol`:

```swift
// Ordinal.Protocol.swift:79-87
extension Tagged: Ordinal.`Protocol` where RawValue: Ordinal.`Protocol`, Tag: ~Copyable {
    public typealias Domain = Tag
    public typealias Count = Tagged<Tag, Cardinal>   // ← This is Index<T>.Count
}
```

So `Index<Element>.Count` = `Tagged<Element, Ordinal>.Count` = `Tagged<Element, Cardinal>`. The `Count` typealias is an associated type of `Ordinal.Protocol`, not a hardcoded nested type on Index.

## Question

Is `Index<T>.Count` the right spelling for the phantom-tagged cardinal type, or would an alternative improve call-site clarity, construction ergonomics, and API consistency?

## Options

### Option A: Status Quo — `Index<T>.Count`

Nested typealias resolved through `Ordinal.Protocol`. Position is the root concept; count and offset are derived.

```swift
// Protocol requirement
static var count: Index<Self>.Count { get }
var ordinal: Index<Self> { get }

// Conformer
public static var count: Index<Self>.Count { Index<Self>.Count(Cardinal(UInt(3))) }

// Generic code — short via associated type
func advance<O: Ordinal.Protocol>(position: O, by count: O.Count) -> O {
    position + count
}
```

### Option B: Top-Level Typealiases — `Count<T>`, `Offset<T>`

Flat namespace with three independent top-level generic typealiases sharing the phantom parameter:

```swift
public typealias Count<T: ~Copyable> = Tagged<T, Cardinal>
public typealias Offset<T: ~Copyable> = Tagged<T, Affine.Discrete.Vector>
// Index<T> already exists as Tagged<T, Ordinal>

// Protocol requirement
static var count: Count<Self> { get }
var ordinal: Index<Self> { get }

// Conformer
public static var count: Count<Self> { Count<Self>(Cardinal(UInt(3))) }
```

### Option C: Protocol Associated Type with Default

The Enumerable protocol defines its own `Count` associated type defaulting to `Index<Self>.Count`:

```swift
public protocol Enumerable: CaseIterable, Sendable {
    associatedtype Count: Cardinal.Protocol = Index<Self>.Count
    static var count: Count { get }
    var ordinal: Index<Self> { get }
    init(__unchecked: Void, ordinal: Index<Self>)
}

// Conformer — uses bare Count
public static var count: Count { Count(Cardinal(UInt(3))) }
```

### Option D: Index Namespace Enum

Make `Index<T>` a namespace enum instead of a type typealias, hosting `.Position`, `.Count`, `.Offset`:

```swift
public enum Index<Element: ~Copyable> {
    public typealias Position = Tagged<Element, Ordinal>
    public typealias Count = Tagged<Element, Cardinal>
    public typealias Offset = Tagged<Element, Affine.Discrete.Vector>
}

// Protocol requirement
static var count: Index<Self>.Count { get }
var ordinal: Index<Self>.Position { get }
```

## Evaluation Criteria

| Criterion | Weight | Rationale |
|-----------|--------|-----------|
| Call-site clarity | High | How readable is the type at protocol requirements and conformer sites |
| Construction ergonomics | Medium | How verbose is creating a value without `ExpressibleByIntegerLiteral` |
| Disambiguation | High | Risk of collision with existing types in the ecosystem |
| Consistency | High | Does the spelling work uniformly for position, count, and offset |
| Namespace pollution | High | Does the spelling occupy valuable top-level names |
| Import story | Medium | Does it require additional imports or module restructuring |
| Backward compatibility | Medium | How much existing code changes |
| Swift conventions | Low | What do stdlib and community packages do (informational, not binding) |

## Analysis

### Criterion 1: Call-Site Clarity

| Site | Option A | Option B | Option C | Option D |
|------|----------|----------|----------|----------|
| Protocol `count` type | `Index<Self>.Count` | `Count<Self>` | `Count` | `Index<Self>.Count` |
| Protocol `ordinal` type | `Index<Self>` | `Index<Self>` | `Index<Self>` | `Index<Self>.Position` |
| Conformer `count` type | `Index<Self>.Count` | `Count<Self>` | `Count` | `Index<Self>.Count` |
| Generic function | `O.Count` | `Count<O.Domain>` | `O.Count` | `O.Count` |

Option B is shortest at declaration sites. Option C is shortest at conformer sites (bare `Count`). Option A is moderate. Option D is the longest because `Index<T>` can no longer be used directly — everything needs a member access.

However, Option A's length is **informative**: `Index<Self>.Count` tells the reader "this is the cardinal counterpart of `Index<Self>`." Option B's `Count<Self>` tells the reader "this is a count tagged with Self" but loses the connection to indexing. Option C's bare `Count` within a conformer tells the reader nothing — you must find the protocol to understand the type.

**Verdict**: Option B wins on brevity. Option A wins on self-documentation. Option C wins on conformer ergonomics. Option D is strictly worse.

### Criterion 2: Construction Ergonomics

All options resolve to the same underlying type (`Tagged<T, Cardinal>`), so construction uses the same initializers:

```swift
// Non-throwing (from UInt)
Index<Self>.Count(UInt(3))     // A
Count<Self>(UInt(3))           // B
Count(UInt(3))                 // C (within conformer scope)

// Non-throwing (from Cardinal)
Index<Self>.Count(Cardinal(3)) // A — Cardinal(3) infers Cardinal.init(_ uint: UInt)
Count<Self>(Cardinal(3))       // B
Count(Cardinal(3))             // C

// Throwing (from Int)
try Index<Self>.Count(3)       // A
try Count<Self>(3)             // B
try Count(3)                   // C
```

Option C has the shortest construction. Option B saves 6 characters over A (`Count<Self>` vs `Index<Self>.Count`). Both B and C benefit from not needing the `.Count` member access, but the actual initializer call is identical.

**Verdict**: Option C > B > A > D. But the difference is small (6–16 characters).

### Criterion 3: Disambiguation

Existing `.Count` types in swift-primitives (current codebase):

| Type | Kind | What it is |
|------|------|------------|
| `Binary.Count<Scalar, Space>` | struct | Bit/byte count with scalar parameterization |
| `Predicate.Count` | struct | Predicate match count |
| `Collection.Count` | enum | Count-related collection namespace |
| `Sequence.Count` | enum | Count-related sequence namespace |
| `Bool.Builder.Count` | enum | Count predicates in bool builder |
| `Text.Count` | typealias | `Tagged<Text, Cardinal>` |
| `System.Processor.Count` | typealias | `Tagged<System.Processor, Cardinal>` |
| `Kernel.File.System.File.Count` | typealias | `Tagged<Kernel.File.System.File, Cardinal>` |
| `Kernel.File.System.Block.Count` | typealias | `Tagged<Kernel.File.System.Block, Cardinal>` |
| `Kernel.Link.Count` | typealias | `Tagged<Kernel.Link, Cardinal>` |
| Tree packages (5 types) | typealias | `Index<Node>.Count` |

A top-level `Count<T>` would **shadow or collide** with `Collection.Count`, `Sequence.Count`, `Binary.Count`, and `Predicate.Count`. These are different concepts — `Binary.Count<Scalar, Space>` has two generic parameters and is a struct, not a typealias to `Tagged`. Even though import qualification would resolve the ambiguity, the cognitive load of "which `Count`?" is significant.

`Index<T>.Count` avoids all collision because it is scoped to the `Index<T>` namespace. No ambiguity is possible.

Note that the existing pattern of `Text.Count = Tagged<Text, Cardinal>` and `System.Processor.Count = Tagged<System.Processor, Cardinal>` proves that domain-scoped `.Count` typealiases to `Tagged<_, Cardinal>` is the established convention. These are literally the same type as `Index<Text>.Count` and `Index<System.Processor>.Count` — all resolve to `Tagged<DomainType, Cardinal>`. The ecosystem has already converged on nested `.Count` as the spelling.

**Verdict**: Option A (and D) have zero collision risk. Option B has high collision risk. Option C inherits collision risk from whichever type it defaults to.

### Criterion 4: Consistency

The position/count/offset triad:

| Concept | Option A | Option B | Option C | Option D |
|---------|----------|----------|----------|----------|
| Position | `Index<T>` | `Index<T>` | `Index<Self>` | `Index<T>.Position` |
| Count | `Index<T>.Count` | `Count<T>` | `Count` (associated) | `Index<T>.Count` |
| Offset | `Index<T>.Offset` | `Offset<T>` | needs another assoctype | `Index<T>.Offset` |

Option A: Count and Offset are derived from Index. The derivation is clear — all three are aspects of an indexed space. Consistent.

Option B: Three independent top-level generics. No derivation visible. You must know that `Count<T>` and `Index<T>` share the same phantom parameter. This is less discoverable — autocomplete on `Index<T>.` reveals `.Count` and `.Offset`; there is no equivalent discoverability for `Count<T>`.

Option C: The protocol owns `Count`, but `Offset` either needs its own associated type (fragmenting the triad further) or stays as `Index<Self>.Offset` (inconsistent — why is Count an associated type but Offset is not?).

Option D: All three are nested in `Index<T>`, but position becomes `Index<T>.Position` instead of `Index<T>` itself. This is semantically cleaner (the namespace vs. the type) but makes the most common case longer.

**Verdict**: Option A > D > B > C. The triad nesting under Index is the most coherent.

### Criterion 5: Namespace Pollution

| Option | Top-level names added |
|--------|-----------------------|
| A | None (status quo) |
| B | `Count<T>`, `Offset<T>` — two extremely common English words |
| C | None (associated types are scoped to protocols) |
| D | None (enum namespace, no new top-level names) |

`Count` is the single most overloaded concept in the codebase. It appears as a type, property, method, and label in dozens of contexts. Claiming it as a top-level generic typealias would create widespread cognitive interference.

**Verdict**: A = C = D > B. Option B is disqualifying on this criterion alone.

### Criterion 6: Import Story

| Option | Required imports |
|--------|-----------------|
| A | `Index_Primitives` — already imported by any consumer of indices |
| B | Where do `Count<T>` and `Offset<T>` live? In `Cardinal_Primitives`? In `Index_Primitives`? In a new module? Any choice has trade-offs. |
| C | No new imports, but protocol must be modified |
| D | `Index_Primitives` — same as A |

Option B creates a placement problem. `Count<T>` is semantically "phantom-tagged cardinal," so it could live in `Cardinal_Primitives` or `Tagged_Primitives`. But users would expect to find it alongside `Index<T>` in `Index_Primitives`. Wherever it goes, discoverability suffers.

**Verdict**: A = D > C > B.

### Criterion 7: Backward Compatibility

| Option | Code changes |
|--------|-------------|
| A | None — this IS the current design |
| B | Additive (new typealiases); old `Index<T>.Count` still works since both resolve to `Tagged<T, Cardinal>` |
| C | Protocol signature change; all conformers must update |
| D | Breaking — `Index<T>` changes from type to namespace; every use of `Index<T>` as a value type breaks |

Option D is immediately disqualified — it would break every existing use of `Index<T>`.

**Verdict**: A > B > C > D.

### Criterion 8: Swift Conventions (Prior Art)

**Swift Standard Library**: Uses protocol associated types (`Collection.Index`, `Strideable.Stride`). Deprecated `IndexDistance` (SE-0191) because all collections used `Int` — the abstraction wasn't earning its keep.

**Point-Free swift-tagged**: Single generic struct, no companion types. Users create domain typealiases. No nesting.

**Community patterns**: Top-level generics sharing a phantom parameter (e.g., Grammarly's `IndexOffset<Collection>`). Nobody in the surveyed ecosystem nests companion types inside the phantom wrapper.

**Rust**: Separate concrete newtypes, no phantom parameter sharing. Trait associated types for companion relationships.

**Haskell Data.Tagged**: Single wrapper, no companions.

The ecosystem precedent slightly favors flat top-level generics (Option B) or protocol associated types (Option C). However, this must be weighed against the specific constraints of the swift-primitives ecosystem, where `.Count` is already used as a nested type in 15+ locations.

**Verdict**: B ≈ C > A (on external convention alone). But this criterion has low weight because swift-primitives intentionally departs from stdlib patterns for domain-safety reasons that stdlib does not need.

## Comparison Matrix

| Criterion | Weight | A: Index\<T\>.Count | B: Count\<T\> | C: Protocol assoctype | D: Index enum |
|-----------|--------|-----|-----|-----|-----|
| Call-site clarity | High | Good — self-documenting | Good — shortest | Mixed — bare but opaque | Poor |
| Construction | Medium | Moderate | Moderate | Best (shortest) | Moderate |
| Disambiguation | High | **Excellent** — zero collision | **Poor** — collides with 10+ types | Good | Excellent |
| Consistency | High | **Excellent** — coherent triad | Good — flat but discoverable | Poor — fragments triad | Good |
| Namespace pollution | High | **None** | **High** — claims `Count` | None | None |
| Import story | Medium | **Clean** | Problematic | Clean | Clean |
| Backward compat | Medium | **None needed** | Additive | Protocol change | **Breaking** |
| Swift conventions | Low | Non-standard | Matches ecosystem | Matches stdlib | Non-standard |

## Constraints

1. `Tagged<Tag, RawValue>` is the underlying mechanism and must remain unchanged.
2. `Ordinal.Protocol.Count` associated type already resolves `Index<T>.Count` — any change must either use or replace this mechanism.
3. 15+ existing types already use nested `.Count` typealiases to `Tagged<DomainType, Cardinal>` — consistency requires matching this convention or refactoring all of them.
4. `Binary.Count<Scalar, Space>`, `Predicate.Count`, `Collection.Count`, `Sequence.Count` are established non-tagged uses of the name `Count` — a top-level `Count<T>` would conflict.

## Outcome

**Status**: RECOMMENDATION

**Recommendation: Option A (status quo) — `Index<T>.Count` is the right spelling.**

### Rationale

1. **The verbosity is load-bearing.** `Index<Self>.Count` communicates the relationship between position and count. It tells the reader "this is the cardinal counterpart of a position in Self-space." The 19 characters carry semantic information that shorter spellings lose.

2. **Namespace safety rules out Option B.** With 10+ existing types named `.Count` in different namespaces (including non-tagged types like `Binary.Count<Scalar, Space>`), a top-level `Count<T>` would create pervasive ambiguity. This is not a theoretical risk — it is an existing collision surface.

3. **The triad coherence rules out Option C.** Making `Count` a protocol associated type but not `Offset` fragments the position/count/offset triad. Making both associated types adds complexity without reducing the fundamental verbosity at the protocol definition site.

4. **Option D is breaking.** Changing `Index<T>` from a type to a namespace would break every use of `Index<T>` as a value type.

5. **The codebase has already converged.** Domains throughout swift-primitives define `.Count` as a nested typealias to `Tagged<DomainType, Cardinal>`:
   - `Text.Count = Tagged<Text, Cardinal>`
   - `System.Processor.Count = Tagged<System.Processor, Cardinal>`
   - `Kernel.File.System.File.Count = Tagged<Kernel.File.System.File, Cardinal>`
   - Tree packages: `typealias Count = Index<Node>.Count`

   `Index<T>.Count` matches this established convention exactly.

6. **Verbosity is already mitigated in the right places.**
   - **Generic code**: `O.Count` (via `Ordinal.Protocol` associated type) — short.
   - **Tests**: `let count: Index<T>.Count = 10` (via `ExpressibleByIntegerLiteral` from Test Support) — ergonomic.
   - **Domain types**: `typealias Count = Index<Node>.Count` (as tree packages already do) — short within scope.
   - **Conformers**: Can use local typealias for body scope.

### The construction verbosity

The real friction is not the type spelling but the construction path:

```swift
// Current — verbose
Index<Self>.Count(Cardinal(UInt(3)))

// Available — throwing from Int
try Index<Self>.Count(3)

// Available — from Cardinal
Index<Self>.Count(Cardinal(3))    // Cardinal.init(_ uint: UInt) infers UInt from literal
```

The `init(_ int: Int) throws(Cardinal.Error)` on `Tagged where RawValue == Cardinal` means `try Index<Self>.Count(3)` works. For compile-time-known constants in protocol conformers, `try!` is justified:

```swift
extension Bit: Finite.Enumerable {
    public static var count: Index<Self>.Count { try! .init(2) }
}
```

This construction pattern is short enough for conformer implementations.

### Conformer-side shortening

Conformers MAY define a local typealias for readability:

```swift
extension Tree.N.Small {
    public typealias Count = Index<Node>.Count   // already done in tree packages
}
```

This is a per-domain choice, not a language-level change. It preserves the canonical `Index<T>.Count` spelling at the protocol level while allowing concision in implementation scopes.

## References

- `Ordinal.Protocol.swift` (lines 35–54, 79–97) — defines `Count` associated type
- `Tagged+Cardinal.swift` (lines 22–44) — `Tagged where RawValue == Cardinal` construction
- `bare-to-tagged-audit-pattern.md` — audit pattern motivating this question
- `index-count-offset-as-tagged.md` — prior research validating Tagged-based Count
- SE-0191 (Eliminate IndexDistance) — prior art: removing a companion associated type that didn't earn its keep
- Point-Free swift-tagged — prior art: single wrapper, no companions
- Grammarly IndexOffset — prior art: top-level generic wrapper for offsets
