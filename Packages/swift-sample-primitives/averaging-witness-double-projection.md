# Averaging Witness Double Projection

<!--
---
version: 1.0.0
last_updated: 2026-02-28
status: DECISION
---
-->

## Context

`Sample.Averaging<Element>` currently captures three operations: `zero`, `adding`, `dividing`. APIs that require floating-point computation (`standardDeviation`, `Comparison.change`) take additional `toDouble`/`fromDouble` closure parameters at every call site.

**Trigger**: During implementation audit, the `toDouble: (Element) -> Double` parameter was identified as mechanism leaking into call sites, violating [IMPL-INTENT].

**Surface area of the problem** — 5 generic methods take `toDouble`/`fromDouble`:

| Method | Parameters |
|--------|-----------|
| `Batch.standardDeviation(using:toDouble:fromDouble:)` | Both closures |
| `Comparison.change(using:toDouble:)` | `toDouble` only |
| `Comparison.isRegression(using:toDouble:)` | `toDouble` only |
| `Comparison.isImprovement(using:toDouble:)` | `toDouble` only |
| `Comparison.exceedsTolerance(_:using:toDouble:)` | `toDouble` only |

10 convenience overloads exist solely to hide these closures for `Duration` and `Double`:

```swift
// Each repeats the SAME closure — { $0.inSeconds } appears 5 times
extension Sample.Comparison where Element == Duration {
    public var change: Double? {
        change(using: .duration, toDouble: { $0.inSeconds })
    }
    public var isRegression: Bool {
        isRegression(using: .duration, toDouble: { $0.inSeconds })
    }
    // ... 3 more
}
```

The static factories (`.duration`, `.real`, `.integer`, `.natural`) already know the element type — they could capture the projection once.

## Question

How should the Double projection be captured to eliminate `toDouble`/`fromDouble` from call sites?

## Analysis

### Option A: Enrich `Sample.Averaging` with projection properties

Add `toDouble` and `fromDouble` as stored properties on `Averaging`:

```swift
@frozen
public struct Averaging<Element: Sendable>: Sendable, Witness.Protocol {
    public var zero: Element
    public var adding: @Sendable (Element, Element) -> Element
    public var dividing: @Sendable (Element, Int) -> Element
    public var toDouble: @Sendable (Element) -> Double
    public var fromDouble: @Sendable (Double) -> Element
}
```

Static factories capture everything:

```swift
extension Sample.Averaging where Element == Duration {
    public static var duration: Self {
        .init(
            zero: .zero,
            adding: { $0 + $1 },
            dividing: { $0 / $1 },
            toDouble: { $0.inSeconds },
            fromDouble: { .seconds($0) }
        )
    }
}
```

Generic methods simplify:

```swift
// Before: 3 parameters
func standardDeviation(using:toDouble:fromDouble:) -> Element?

// After: 1 parameter
func standardDeviation(using averaging: Sample.Averaging<Element>) -> Element?
```

Call sites read as intent:

```swift
// Before
batch.standardDeviation(using: .duration, toDouble: { $0.inSeconds }, fromDouble: { .seconds($0) })
comparison.change(using: .duration, toDouble: { $0.inSeconds })

// After
batch.standardDeviation(using: .duration)
comparison.change(using: .duration)
```

**Advantages**:
- Single witness captures all operations — no split knowledge
- [IMPL-INTENT]: call sites read as intent, not mechanism
- [IMPL-EXPR-001]: single expression, no intermediate closures
- [IMPL-000]: the ideal call site compiles directly
- Every static factory already knows its conversion — zero new information needed
- Convenience overloads for `Duration`/`Double` become trivially thin

**Disadvantages**:
- `Averaging` init grows from 3 to 5 parameters
- `mean(using:)` and `sum(using:)` don't need `toDouble`/`fromDouble` — they carry unused closures
- `@frozen` struct gets 2 additional stored function pointers (16 bytes each)

### Option B: Create a separate `Sample.Projection` witness

A dedicated witness for the Double round-trip:

```swift
@frozen
public struct Projection<Element: Sendable>: Sendable, Witness.Protocol {
    public var toDouble: @Sendable (Element) -> Double
    public var fromDouble: @Sendable (Double) -> Element
}
```

Methods take both witnesses:

```swift
func standardDeviation(
    using averaging: Sample.Averaging<Element>,
    projecting: Sample.Projection<Element>
) -> Element?
```

Call site: `batch.standardDeviation(using: .duration, projecting: .durationSeconds)`.

**Advantages**:
- Separation of concerns — `Averaging` stays lean
- Only methods that need projection pay for it

**Disadvantages**:
- Two witness parameters at every call site — still noisy
- Two static factories to maintain per element type
- Naming the projection factories is awkward (`.durationSeconds`? `.durationProjection`?)
- [IMPL-INTENT]: "projecting: .durationSeconds" is still mechanism — it describes HOW to convert, not WHAT you want

### Option C: Protocol-based approach (e.g., `SampleNumeric`)

Define a protocol that types conform to:

```swift
protocol SampleNumeric: Comparable, Sendable {
    static var averagingWitness: Sample.Averaging<Self> { get }
    var asDouble: Double { get }
    init(fromDouble: Double)
}
```

Call site: `batch.standardDeviation` — no parameter needed.

**Advantages**:
- Cleanest call sites — no witness parameter at all
- Works for types you control (Duration via extension, Double, Int)

**Disadvantages**:
- Protocols impose `Copyable` — can't extend to `~Copyable` types
- Retroactive conformances can conflict across modules
- Goes against the ecosystem's witness-based design philosophy
- Can't have multiple projection strategies for the same type
- `Duration` conformance would depend on `time-primitives` for `inSeconds` — coupling

### Option D: Enrich `Averaging`, keep generic `toDouble` overload

Enrich per Option A, but also keep the current generic `standardDeviation(using:toDouble:fromDouble:)` as an overload for custom element types whose factory might not exist yet.

Call sites for known types use the witness: `batch.standardDeviation(using: .duration)`.
Custom types can still pass explicit closures: `batch.standardDeviation(using: myWitness, toDouble: { ... }, fromDouble: { ... })`.

**Advantages**:
- All of Option A's benefits
- No API breakage for custom types
- Progressive disclosure: simple case is simple, custom case is possible

**Disadvantages**:
- Two overloads per method increases API surface
- Custom types should just create their own `Averaging` factory instead

### Comparison

| Criterion | A: Enrich | B: Separate | C: Protocol | D: Enrich + overload |
|-----------|-----------|-------------|-------------|---------------------|
| [IMPL-INTENT] call site clarity | Excellent | Fair | Excellent | Excellent |
| [IMPL-EXPR-001] expression count | 1 param | 2 params | 0 params | 1 param |
| [IMPL-000] ideal expression | Yes | No | Yes | Yes |
| Witness count per call | 1 | 2 | 0 | 1 |
| ~Copyable compatible | Yes | Yes | No | Yes |
| Multiple strategies per type | Yes | Yes | No | Yes |
| API surface growth | None | +1 type | +1 protocol | +5 overloads |
| Unused data in witness | 2 closures for mean/sum | None | N/A | 2 closures for mean/sum |
| [API-NAME-002] naming | N/A (witness props) | Awkward factory names | N/A | N/A |

### Constraints

- `Sample.Averaging` is `@frozen` — adding stored properties is an ABI change, but the package is pre-1.0 so this is acceptable
- The `toDouble`/`fromDouble` properties are witness-internal (compound names acceptable per [IMPL-024])
- `fromDouble` is only used by `standardDeviation`; `toDouble` is used by stddev and all `Comparison` methods
- All 4 static factories (`.duration`, `.real`, `.integer`, `.natural`) trivially know their projection

## Outcome

**Status**: DECISION

**Decision**: **Option A — Enrich `Sample.Averaging`** with `project` and `embed` stored properties.

**Rationale**:
1. The static factories already know the conversion — they should capture it. Asking every call site to re-supply the same closure is a witness that's incomplete.
2. Per [IMPL-INTENT], the ideal call site is `batch.standardDeviation(using: .duration)`. Option A makes this compile directly.
3. The 2 unused closures for `mean`/`sum` are a negligible cost (32 bytes per witness value, typically constructed once and passed through). The cognitive simplicity of "one witness = everything you need" far outweighs it.
4. Option D's explicit-closure overload is unnecessary — custom types should define their own `Averaging` factory with the projection baked in. That's the whole point of the witness pattern.
5. Option B creates more ceremony (two witnesses) without reducing it.
6. Option C violates the ecosystem's witness-over-protocol design and breaks `~Copyable` compatibility.

**Naming**: `project` / `embed` — single words (non-compound per [API-NAME-002]), mathematically precise (projection-embedding pair). Factories use init references where possible per [PATTERN-012]: `project: Double.init`, `embed: Int.init`.

**Implementation** (completed):
1. Added `project` and `embed` to `Sample.Averaging` init and stored properties
2. Updated all 4 static factories — using `Double.init` / `Int.init` init references for Int/UInt64
3. Simplified `standardDeviation(using:)` to use `averaging.project`/`averaging.embed`
4. Simplified all `Comparison` methods to use `averaging.project`
5. Removed `toDouble`/`fromDouble` parameters from all 5 generic methods
6. Convenience overloads remain (computed property ergonomics for `Duration`/`Double`)
7. Tests updated
