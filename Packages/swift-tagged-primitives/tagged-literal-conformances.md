# Tagged Literal Conformances

<!--
---
version: 3.0.0
last_updated: 2026-03-04
status: DECISION
tier: 2
---
-->

## Context

During migration from the `swift-standards` monorepo to individual primitives packages, callsites that previously compiled now fail:

```swift
// W3C_SVG2.Types.ViewBox.swift — default argument
minX: W3C_SVG2.X = 0   // error: 'Int' cannot be converted to Tagged<Coordinate.X<Space>, Double>

// Affine.Continuous.Transform Tests.swift — test literals
Transform.rotation(Degree(90))   // works only because test support adds conformance
```

`Tagged` currently has `ExpressibleByIntegerLiteral` and `ExpressibleByFloatLiteral` conformances only in test support (`Tagged Primitives Test Support.swift`), not in production code. The question is whether this is an intentional restriction or an omission.

### v2.0 Update (2026-02-11)

A production test crash in `Bit.Vector.Dynamic Tests.swift` revealed that the blanket `ExpressibleByIntegerLiteral` conformance on `Tagged` creates a silent overload resolution footgun. This finding invalidated the v1.0 preliminary recommendation (Option A). See "Cross-Domain Init Overload Resolution Footgun" section below.

### v3.0 Update (2026-03-04)

Deeper analysis (`revisiting-tagged-production-literal-conformances.md`, `labeled-cross-domain-init-convention.md`) revealed that the v2.0 conclusion was overly broad. The footgun requires a **non-identity numeric transformation** — only 3 of 9 cross-domain inits qualify. Labeling these 3 inits eliminates the entire footgun class with near-zero migration cost, enabling safe production literal conformance. v3.0 supersedes v2.0 — see updated Outcome.

## Question

Should `Tagged<Tag, Underlying>` conform to `ExpressibleByIntegerLiteral` and `ExpressibleByFloatLiteral` in production code?

## Analysis

### Inventory of Tagged usage

83+ distinct `Tagged` typealiases exist across 30+ packages. They fall into these categories:

| Category | Examples | Underlying | Count | Wants literals? |
|----------|----------|----------|-------|-----------------|
| Coordinates | `Coordinate.X<Space>`, `.Y`, `.Z`, `.W` | `Double`, `Float`, generic `Scalar` | ~20 | Yes |
| Displacements | `Displacement.X<Space>`, `.Y`, `.Z` | `Double`, `Float`, generic `Scalar` | ~15 | Yes |
| Extents | `Extent.X<Space>`, `.Y`, `.Z` | `Double`, `Float`, generic `Scalar` | ~10 | Yes |
| Measures | `Measure<N, Space>` (Length, Radius, Area, ...) | `Double`, `Float`, generic `Scalar` | ~15 | Yes |
| Angles | `Angle.Radian`, `Angle.Degree` | `Double`, `Float` | 2 | Yes |
| Kernel IDs | `Kernel.User.ID`, `.Group.ID`, `.Event.ID` | `UInt32`, `UInt`, `Int32` | ~10 | Neutral |
| Kernel counts | `Kernel.File.System.File.Count`, etc. | `UInt64`, `Int` | ~8 | Neutral |
| Hash/test IDs | `Hash.Value`, `Test.Case.ID` | `Int`, `UInt64` | ~5 | Neutral |
| Time instants | `Time.Clock.Instant<Clock>` | `Int64` | 1 | Neutral |
| Ordinal/index | `Tagged<Tag, Ordinal>` | `Ordinal` (wraps `UInt`) | ~5 | **Dangerous** |
| Handles | `Handle<Phantom>` | `SlotAddress` (struct) | 1 | N/A |
| Polymorphic | `Binary.Endianness.Value<Payload>` | generic `Payload` | 2 | N/A |

**v1.0 claim (INCORRECT)**: The "N/A" categories were described as "automatically excluded" because `Ordinal` does not conform to `ExpressibleByIntegerLiteral`.

**v2.0 correction**: `Ordinal` **does** conform to `ExpressibleByIntegerLiteral` (in `Ordinal+ExpressibleByIntegerLiteral.swift`, production code). Therefore ALL `Tagged<_, Ordinal>` types — including `Index<UInt8>`, `Index<Element>`, `Bit.Index`, `Ordinal.Finite<N>`, `Algebra.Z<n>`, and `Memory.Address` — would gain literal conformance under a blanket approach. This is the root cause of the footgun.

### Cross-Domain Init Overload Resolution Footgun

**Discovered**: 2026-02-11. **Full analysis**: `swift-primitives/Research/cross-domain-init-overload-resolution-footgun.md`.

`Bit.Index` (= `Tagged<Bit, Ordinal>`) has a cross-domain conversion init:

```swift
// Bit.Index+Byte.swift — converts byte position to bit position (×8)
extension Bit.Index {
    public init(_ index: Index<UInt8>) {
        self = .zero + Index<UInt8>.Count(index) * .bitsPerByte
    }
}
```

When the blanket `ExpressibleByIntegerLiteral` conformance is available (currently test-only), this chain fires:

1. `(0..<5).map(Bit.Index.init)` — programmer intends direct bit index construction
2. Swift finds `init(_ index: Index<UInt8>)` on `Bit.Index`
3. `Index<UInt8>` (= `Tagged<UInt8, Ordinal>`) conforms to `ExpressibleByIntegerLiteral` via the blanket conformance
4. Swift infers `0..<5` as `Range<Index<UInt8>>`, not `Range<Int>`
5. Each value (0, 1, 2, 3, 4 as `Index<UInt8>`) passes through the byte-to-bit init
6. Result: bit indices 0, 8, 16, 24, 32 — out of bounds for a 5-bit vector — **runtime crash**

**This is silent**: no compiler warning, no type error. The code reads as "create bit indices 0-4" but produces "create bit indices 0, 8, 16, 24, 32".

**Impact of moving to production**: Currently this footgun only fires in test code (where test support is imported). Moving the conformance to production would make the footgun **permanent and inescapable** — any production code using `.map(Bit.Index.init)` on a range could silently produce wrong results.

### Option A: Add blanket conformance (matching test support)

```swift
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable, Underlying: ExpressibleByIntegerLiteral {
    @_disfavoredOverload
    @inlinable
    public init(integerLiteral value: Underlying.IntegerLiteralType) {
        self = .init(_unchecked: Underlying(integerLiteral: value))
    }
}

extension Tagged: ExpressibleByFloatLiteral
where Tag: ~Copyable, Underlying: ExpressibleByFloatLiteral {
    @_disfavoredOverload
    @inlinable
    public init(floatLiteral value: Underlying.FloatLiteralType) {
        self.init(_unchecked: Underlying(floatLiteral: value))
    }
}
```

**Advantages**:
- All dimensional types (`X`, `Y`, `Width`, `Height`, `Degree`, `Radian`, ...) gain natural literal syntax
- Default arguments work: `minX: W3C_SVG2.X = 0`
- Eliminates `_unchecked:` boilerplate for constant initialization
- Matches `Scale` and `Interval.Unit` which already have these conformances
- `@_disfavoredOverload` ensures explicit constructors are preferred when available

**Disadvantages**:
- Identity-typed values accept literals: `let uid: Kernel.User.ID = 0`
- Reduces explicitness at construction site
- **CRITICAL: Enables the cross-domain init overload resolution footgun in production code** — `Index<UInt8>` and all other `Tagged<_, Ordinal>` types gain literal conformance, allowing Swift to silently infer literal ranges as `Range<Index<UInt8>>` and resolve `.map(Bit.Index.init)` to the byte-to-bit conversion

**v1.0 risk assessment (INVALIDATED)**:

The v1.0 analysis claimed `Ordinal` does not conform to `ExpressibleByIntegerLiteral` and that ordinal/index types would be "automatically excluded." This is incorrect — `Ordinal` has a production `ExpressibleByIntegerLiteral` conformance (`@_disfavoredOverload`). All `Tagged<_, Ordinal>` types receive the blanket literal conformance, including types that participate in cross-domain conversion chains.

`@_disfavoredOverload` does NOT prevent the footgun. Disfavoring affects overload ranking between equally-applicable candidates, but when the byte-to-bit init is the **only** non-throwing init matching the function reference in `.map(Bit.Index.init)`, disfavoring has no alternative to prefer.

### Option B: Add conformance only for Spatial tags

```swift
extension Tagged: ExpressibleByIntegerLiteral
where Tag: Spatial, Underlying: ExpressibleByIntegerLiteral { ... }
```

**Advantages**:
- Narrower scope — only dimensional types get literals
- Identity types remain fully explicit
- Ordinal-based types excluded — footgun does not apply

**Disadvantages**:
- Angular types (`Angle.Radian`, `Angle.Degree`) are NOT `Spatial` and would be excluded
- Would need a second protocol or special-case conformances for angles
- Fragments the initialization story — some Tagged types have literals, others don't, based on tag protocol

### Option C: Keep current design (no production conformance)

Fix all callsites to use explicit construction:

```swift
minX: W3C_SVG2.X = .init(0)           // Spatial tags have init(_:)
let r = Radian(_unchecked: value) // Non-Spatial tags need _unchecked
```

**Advantages**:
- Maximum explicitness
- Every Tagged value construction is visible and intentional
- **Cross-domain footgun contained to test code only** — no production risk

**Disadvantages**:
- Ergonomic burden on the most common use case (dimensional types)
- `.init(0)` in default arguments is awkward
- `_unchecked:` for angles is both verbose and misleading (the value isn't "unchecked" in any meaningful sense)
- Diverges from `Scale` and `Interval.Unit` which already have literal conformances
- Test code requires a separate support module just for literals

### Option D: Protocol-gated conformance (Spatial + Angular)

Add a new protocol `Tagged.LiteralInitializable` or extend `Spatial` to cover angles.

**Advantages**:
- Precise control over which tags get literals
- Ordinal-based types excluded — footgun does not apply

**Disadvantages**:
- Adds protocol complexity for marginal benefit over Option A
- ~~The `Underlying: ExpressibleByIntegerLiteral` constraint already provides natural gating~~ (v2.0: this claim was incorrect — Ordinal satisfies the constraint)

### Comparison

| Criterion | A: Blanket | B: Spatial-only | C: No conformance | D: Protocol-gated |
|-----------|-----------|-----------------|-------------------|-------------------|
| Dimensional ergonomics | Excellent | Excellent | Poor | Excellent |
| Angular ergonomics | Excellent | Poor | Poor | Excellent |
| Identity type safety | Good (literals only) | Excellent | Excellent | Excellent |
| Ordinal footgun safety | **UNSAFE** | Safe | Safe | Safe |
| Simplicity | Excellent | Good | Good | Poor |
| Consistency with Scale/Unit | Excellent | Partial | Poor | Partial |
| Non-numeric exclusion | ~~Automatic~~ Incomplete | Automatic | N/A | Automatic |
| Migration cost | Zero | Medium | High | High |

## Constraints

1. `Tagged` is `~Copyable` — conformances must use `where Tag: ~Copyable`
2. `@_disfavoredOverload` should be applied so explicit constructors take priority in overload resolution
3. Must not break existing callsites that use `_unchecked:` or `init(_:)` for Spatial tags
4. The conformance already exists in test support and has been validated across the test suite
5. **NEW (v2.0)**: The conformance MUST NOT enable literal type inference on `Tagged<_, Ordinal>` types, because cross-domain conversion inits (like byte-to-bit) create silent overload resolution footguns

## Outcome

**Status**: DECISION

**Decision**: Option A (blanket conformance) — move to production, contingent on labeling 3 non-identity cross-domain inits.

**v3.0 rationale** (supersedes v2.0):

1. **The v2.0 conclusion was overly broad.** The footgun requires a non-identity numeric transformation — the confirmed crash (`Bit.Index ×8`) produced wrong VALUES. But most unlabeled cross-domain inits (6 of 9) are identity-numeric — they preserve the underlying value and produce correct results even under unexpected type inference paths.

2. **Only 3 non-identity inits exist** (exhaustively verified across 61+ packages): `Bit.Index.init(_ : Index<UInt8>)` (×8 scaling), `Memory.Shift.init(_ : Cardinal)` (narrowing to UInt8), `Affine.Discrete.Ratio.init(_ : Tagged<To, Cardinal>)` (reinterpretation). All have 0 `.map(Type.init)` call sites, making labeling cost-free.

3. **Labeling these 3 inits eliminates the entire footgun class.** Labeled inits cannot be matched by `.map(Type.init)` function references. The remaining unlabeled inits are identity-numeric and value-safe.

4. **The v2.0 findings remain valid but are addressed**:
   - "Natural gating" was incorrect → still true, but irrelevant — identity-numeric inits are safe
   - `@_disfavoredOverload` doesn't mitigate → still true, but no mitigation needed for identity-numeric inits
   - `Tagged<_, Ordinal>` gains literal conformance → correct, but identity-numeric inference produces correct values

5. **Convention rule prevents future regressions**: "Unlabeled `init(_ :)` on Tagged types MUST preserve numeric identity. Non-identity transformations MUST use argument labels."

**Required implementation**:
1. Label `Bit.Index.init(byte index: Index<UInt8>)` — ×8 scaling
2. Label `Memory.Shift.init(count cardinal: Cardinal)` — narrowing
3. Label `Affine.Discrete.Ratio.init(stride count: Tagged<To, Cardinal>)` — reinterpretation
4. Move `ExpressibleByIntegerLiteral` and `ExpressibleByFloatLiteral` from test support to production

**Answered open question** (from v1.0): "Are there any Tagged types where accepting a literal would be actively harmful?" **No** — with the 3 non-identity inits labeled, no Tagged type is actively harmed. `Tagged<_, Ordinal>` types accept literals, but identity-numeric inference produces correct values. The harm was not from literal conformance but from non-identity unlabeled inits.

## References

- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift` — core definition
- `swift-tagged-primitives/Tests/Support/Tagged Primitives Test Support.swift:16-28` — existing conformance
- `swift-tagged-primitives/Research/revisiting-tagged-production-literal-conformances.md` — v3.0 safety analysis (2026-03-04)
- `swift-primitives/Research/labeled-cross-domain-init-convention.md` — cross-domain init inventory and labeling decision (2026-03-04)
- `swift-primitives/Research/cross-domain-init-overload-resolution-footgun.md` — original footgun analysis (2026-02-11)
- `swift-dimension-primitives/Sources/Dimension Primitives/Tagged+Dimension.swift:88-110` — Spatial init
- `swift-dimension-primitives/Sources/Dimension Primitives/Scale.swift:256-273` — Scale literal conformances
- `swift-dimension-primitives/Sources/Dimension Primitives/Interval.Unit.swift:226-265` — Unit literal conformances
- `swift-ordinal-primitives/Sources/Ordinal Primitives Standard Library Integration/Ordinal+ExpressibleByIntegerLiteral.swift` — Ordinal literal conformance (production)
- `swift-bit-index-primitives/Sources/Bit Index Primitives/Bit.Index+Byte.swift:28-32` — cross-domain init (footgun trigger, to be labeled)
