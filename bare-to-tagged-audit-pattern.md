# Bare-to-Tagged Audit Pattern

## Problem

A property uses a bare type (`Cardinal`, `Ordinal`) when the value is semantically scoped to a specific domain. This forces every consumer to construct a phantom-typed wrapper from scratch rather than transforming an already-typed value.

```swift
// Anti-pattern: bare Cardinal at the source
public let count: Cardinal

// Consumer must construct from scratch — domain information is lost
var count: Index<Element>.Count {
    Index<Element>.Count(_storage.count)    // wrapping bare value
}
```

The bare type erases domain information at the point of declaration. Every downstream consumer must independently re-introduce the domain via construction, and each such site is a potential source of tag mismatch.

This applies to **any API surface** — stored properties, computed properties, return types, and parameters — not only stored properties.

## Fix

Type the property with the narrowest correct phantom-tagged type. Consumers then use `.retag` to change domain, keeping the full chain typed.

```swift
// Fixed: typed at the source
public let count: Index<UInt8>.Count

// Consumer retags — zero-cost, typed transformation
var count: Index<Element>.Count {
    _storage.count.retag(Element.self)      // tag-to-tag, no bare value
}
```

## Why this matters

1. **Domain safety**: A bare `Cardinal` can be accidentally mixed with any other `Cardinal`. A `Tagged<UInt8, Cardinal>` can only combine with values in the same domain (enforced by `where O.Domain == C.Domain` on `Cardinal.Protocol` arithmetic).

2. **Typed chain preservation**: `.retag` is a typed transformation — it says "this was always a count, change which element it counts." Construction from a bare value says "here is an untyped number, trust me it's a count of X."

3. **Zero-cost**: `Tagged<Tag, Cardinal>` has identical layout to `Cardinal`. Retagging is a no-op at runtime.

4. **Boundary clarity**: The only place bare types should appear is at true system boundaries — `Int(bitPattern: count.cardinal)` at the stdlib/C interface. Interior code should never unwrap to bare types.

## Diagnostic

Grep for construction of `Tagged`/`Index<T>.Count`/`Index<T>.Offset` from bare values stored in the same module or a dependency:

```bash
# Find properties storing bare Cardinal that could be tagged
grep -rn 'let count: Cardinal\|var count: Cardinal' Sources/

# Broader: any bare Cardinal/Ordinal stored property
grep -rn 'let \w\+: Cardinal\b\|var \w\+: Cardinal\b' Sources/
grep -rn 'let \w\+: Ordinal\b\|var \w\+: Ordinal\b' Sources/

# Find construction-from-bare patterns (the consumer-side symptom)
grep -rn 'Index<.*>.Count(.*\.count)\|Index<.*>.Offset(.*\.offset)' Sources/

# Find .rawValue extraction used to pass to typed inits (another symptom)
grep -rn '\.rawValue,' Sources/ | grep -i 'byteCount\|count\|offset\|capacity'
```

## Mechanical fix

### Step 1: Change the property type

```swift
// Before
public let count: Cardinal

// After
public let count: Index<UInt8>.Count
```

The tag should reflect what the value counts. For byte-oriented storage, `UInt8`. For element-oriented storage, `Element`.

### Step 2: Update initializers

Upgrade the parameter type to match. This pushes the typed boundary outward to callers, which is the right direction — callers typically already have a typed value and were extracting `.rawValue` to satisfy the bare parameter.

```swift
// Before
public init(byteCount: Cardinal, ...) {
    self.count = byteCount
}

// After
public init(byteCount: Index<UInt8>.Count, ...) {
    self.count = byteCount
}
```

### Step 3: Update stdlib boundary conversions

At `Int(bitPattern:)` call sites, access `.cardinal` (the `Cardinal.Protocol` witness):

```swift
// Before (bare Cardinal)
Int(bitPattern: count)

// After (tagged Cardinal)
Int(bitPattern: count.cardinal)
```

These sites are justified per [CONV-001] — they are true system boundaries where typed values must cross into stdlib/C APIs.

### Step 4: Update consumers

Consumers that previously constructed from bare values now retag:

```swift
// Before: construction from bare
Index<Element>.Count(_storage.count)

// After: typed transformation
_storage.count.retag(Element.self)
```

Consumers that previously extracted `.rawValue` to pass to the init now retag:

```swift
// Before: unwrap to bare
Aligned(byteCount: capacity.rawValue, ...)

// After: retag to match
Aligned(byteCount: capacity.retag(UInt8.self), ...)
```

## Precedent

- **Buffer.Aligned.count** (`swift-buffer-primitives`): `Cardinal` → `Index<UInt8>.Count`. Commit `4167371`. Four files changed, zero downstream breakage across the full swift-primitives superrepo.

## Scope

This pattern applies wherever bare `Cardinal` or `Ordinal` appears but the value is semantically scoped:

| Bare type | Tagged replacement | When |
|-----------|-------------------|------|
| `Cardinal` | `Index<T>.Count` | Value counts elements of type `T` |
| `Cardinal` | `Tagged<Space, Cardinal>` | Value counts items in a named domain |
| `Ordinal` | `Index<T>.Ordinal` | Value is a 1-based position in `T`-space |
| `Ordinal` | `Index<T>` | Value is a 0-based index in `T`-space |

### When bare types are correct

Not every bare `Cardinal` or `Ordinal` is an anti-pattern. Bare types are correct when:

1. **Genuinely domain-free values** — a retry count, a generic "how many" that is not scoped to any element type.

2. **Mathematical primitives** — `Algebra.Modular.Modulus.cardinal` and `Cyclic.Group.Modulus.value` represent group orders as pure mathematical quantities. The modulus is the *definition* of the domain, not a value *within* a domain.

3. **Stdlib entry points** — `Cardinal(UInt(span.count))` wrapping a stdlib `Int` into a bare `Cardinal` at a system boundary is not the anti-pattern. This is the *intake* boundary where untyped stdlib values enter the typed world. The anti-pattern is *storing* and *propagating* the bare value after intake instead of immediately tagging it.

### Protocol-level bare types

The anti-pattern is not limited to stored properties and concrete types. Protocols that require bare `Cardinal` or `Ordinal` when the value is semantically scoped to `Self` (or another domain parameter) erase domain information at the *interface* level. Every conformer is then forced to provide a bare type, and every consumer must re-introduce the domain via construction.

The diagnostic is the same: if a protocol requirement's value is always "a count of `Self`" or "a position in `Self`-space", the bare type is the anti-pattern.

```swift
// Anti-pattern: protocol erases domain at the interface level
protocol Foo {
    static var count: Cardinal { get }    // always counts Self
    var ordinal: Ordinal { get }          // always positions Self
}

// Fix: tag to the domain the protocol defines
protocol Foo {
    static var count: Index<Self>.Count { get }
    var ordinal: Index<Self> { get }
}
```

**Known instance: `Finite.Enumerable`**

```swift
// Current — bare
public protocol Enumerable: CaseIterable, Sendable {
    static var count: Cardinal { get }
    var ordinal: Ordinal { get }
    init(__unchecked: Void, ordinal: Ordinal)
}

// Fixed — tagged to Self
public protocol Enumerable: CaseIterable, Sendable {
    static var count: Index<Self>.Count { get }
    var ordinal: Index<Self> { get }
    init(__unchecked: Void, ordinal: Index<Self>)
}
```

The construction-from-bare symptom is already visible in `Finite.Enumeration`:

```swift
// wrapping bare count into tagged — the consumer-side symptom
public var endIndex: Index { Index.Count(Element.count).map(Ordinal.init) }
```

Blast radius: every conformer (`Bit`, `Ternary`, `Comparison`, `Parity`, `Bound`, `Sign`, `Polarity`, `Boundary`, `Gradient`, `Endpoint`, `Monotonicity`, `Theme`, `Rotation.Phase`, `Tagged where Tag: Finite.Capacity`) plus all consumer code in `Finite.Enumeration`, `Finite.Bounded`, `Cyclic.Group`, and downstream.

**Known instance: `Finite.Capacity`**

```swift
// Current — bare
static var capacity: Cardinal { get }

// Fixed — tagged to Self
static var capacity: Index<Self>.Count { get }
```

**Prerequisite for protocol-level fixes**: comparison operators between tagged types (e.g., `Index<T> < Index<T>.Count`) must exist for bounds checking. Currently `ordinal < Self.count` works via `Ordinal < Cardinal` (concrete). The tagged equivalent needs `Index<Self> < Index<Self>.Count` or access via `.cardinal`/`.ordinal` witnesses.

### Audit candidates by visibility

**Public API** (highest priority — consumers are forced to unwrap/rewrap):

| Location | Property | Candidate type |
|----------|----------|----------------|
| `Finite.Enumerable.count` | `Cardinal` | `Index<Self>.Count` |
| `Finite.Enumerable.ordinal` | `Ordinal` | `Index<Self>` |
| `Sequence.Difference.Hunk.oldCount` | `Cardinal` | `Index<Element>.Count` |
| `Sequence.Difference.Hunk.newCount` | `Cardinal` | `Index<Element>.Count` |
| `Sequence.Difference.Hunk.oldStart` | `Ordinal` | `Index<Element>.Ordinal` |
| `Sequence.Difference.Hunk.newStart` | `Ordinal` | `Index<Element>.Ordinal` |
| `Theme.ordinal` | `Ordinal` | `Index<Theme>` (via `Finite.Enumerable` fix) |

**Internal/iterator state** (lower priority — no public API impact, but domain info is still erased internally):

| Location | Property | Candidate type |
|----------|----------|----------------|
| `Swift.Span<Element>.Iterator._count` | `Cardinal` | `Index<Element>.Count` |
| `Swift.Span<Element>.Iterator._position` | `Ordinal` | `Index<Element>` |
| `Sequence.Drop.First._count` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Prefix.First._count` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Difference.Changes.Iterator._index` | `Ordinal` | domain-dependent |
| `Sequence.Difference.Steps.Iterator._index` | `Ordinal` | domain-dependent |

**Gray areas** (case-by-case):

| Location | Property | Analysis |
|----------|----------|----------|
| `Cyclic.Group.Static<N>.Element.position` | `Ordinal` | Position within cyclic group. The group modulus is compile-time (`N`), but position is not phantom-tagged to a specific domain — the group *is* the domain. Could remain bare. |
| `Cyclic.Group.Element.residue` | `Ordinal` | Dynamic group with externally-supplied modulus. The residue is domain-free by design (see doc comment). Bare is correct. |
| `Parser.Machine.Memoization.Key.node` | `Ordinal` | Node index in parser program. Could be tagged to the node type, but the parser machine is generic infrastructure — the "node" concept is internal. Low priority. |

### Double `.rawValue` code smell

When test code or consumer code uses `count.rawValue.rawValue`, this indicates double-wrapping — typically `Index<T>.Count` → `Cardinal` → `UInt`. This chain suggests the outer tagged layer is providing value, but the extraction API has friction. The fix is usually to provide a `.cardinal` accessor or use `Int(bitPattern: count.cardinal)` at the boundary.

Example from `swift-heap-primitives` tests:
```swift
// Smell: double unwrapping
Int(heap.count.rawValue.rawValue)

// Fix: use the Cardinal.Protocol witness
Int(bitPattern: heap.count.cardinal)
```
