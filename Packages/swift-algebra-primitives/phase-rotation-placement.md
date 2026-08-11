# Phase and Discrete Rotation Placement

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: RECOMMENDATION
---
-->

## Context

During integration of Cardinal/Ordinal primitives into `Finite.Enumerable`, we discovered that `Phase` (discrete Z₄ rotations) may be misplaced in algebra-primitives. The type has rotation-specific semantics (`.quarter`, `.half`, `.degrees`) that appear geometric rather than purely algebraic.

Investigation revealed multiple rotation-related types across the codebase with overlapping concerns.

## Question

Where should discrete rotation types (Z₄, Z₈, Z₁₂, etc.) live in the swift-primitives architecture? Specifically:
1. Is `Phase` purely algebraic or geometric?
2. How does it relate to other cyclic types (`Quadrant`, `Clock`, `Sextant`)?
3. Should it be a typealias to `Cyclic.Group<4>.Element` or remain an enum?

## Analysis

### Existing Rotation-Related Types

| Type | Package | Group | Domain Semantics |
|------|---------|-------|------------------|
| `Phase` | algebra-primitives | Z₄ | Rotation angles (0°, 90°, 180°, 270°) |
| `Region.Quadrant` | region-primitives | Z₄ | Cartesian plane regions (I, II, III, IV) |
| `Region.Clock` | region-primitives | Z₁₂ | Clock face positions (1-12) |
| `Region.Sextant` | region-primitives | Z₆ | Hexagonal sectors |
| `Region.Cardinal` | region-primitives | Z₄/Z₈ | Compass directions (N, E, S, W) |
| `Cyclic.Group<N>.Element` | cyclic-primitives | Zₙ | Abstract cyclic group element |
| `Index.Cyclic<N>` | cyclic-index-primitives | Zₙ | Ring buffer index |
| `Rotation<N, Scalar>` | symmetry-primitives | SO(n) | Continuous rotation matrix |
| `Collection.Rotated` | collection-primitives | — | Rotated view of collection |
| `Numeric.Integer.Rotation` | numeric-primitives | — | Bit rotation operations |

### Observations

1. **Three distinct "rotation" concepts exist:**
   - **Discrete cyclic groups** (Z₄, Z₁₂, etc.) — finite, algebraic
   - **Continuous rotations** (SO(2), SO(3)) — infinite, geometric/linear algebra
   - **Shift operations** (collection rotation, bit rotation) — computational/algorithmic

2. **`Phase` duplicates `Region.Quadrant`:**
   Both are Z₄ with rotation semantics. The difference is naming convention:
   - Phase: `.zero`, `.quarter`, `.half`, `.threeQuarter`
   - Quadrant: `.I`, `.II`, `.III`, `.IV`

3. **Region types are geometric interpretations of cyclic groups:**
   - `Quadrant` = Z₄ interpreted as Cartesian plane regions
   - `Clock` = Z₁₂ interpreted as clock positions
   - `Cardinal` = Z₄/Z₈ interpreted as compass directions

4. **`Cyclic.Group<N>.Element` is the pure algebraic form:**
   No domain semantics—just abstract modular arithmetic.

### Prior Art

**Mathematical foundations:**
- [Cyclic groups](https://en.wikipedia.org/wiki/Cyclic_group) are fundamental in abstract algebra
- Z₄ is isomorphic to the [rotational symmetries of a square](https://groupprops.subwiki.org/wiki/Cyclic_group:Z4)
- The [4th roots of unity](https://crypto.stanford.edu/pbc/notes/numbertheory/cyclic.html) {1, i, -1, -i} form Z₄

**Computer science applications:**
- [Ring buffers](https://sites.google.com/view/algobytheroyakash/data-structures/ring-buffer) use modular arithmetic for index wrapping
- [Quantum cyclic rotation gates](https://link.springer.com/article/10.1007/s42979-024-03141-4) apply position shifts mod n
- Image processing uses 90° rotations (Z₄ action) extensively
- [Cyclic redundancy checks](https://www.devx.com/terms/modular-arithmetic/) rely on polynomial division mod 2

### Option Analysis

#### Option A: Phase = `Cyclic.Group<4>.Element` (typealias)

```swift
// In algebra-primitives or cyclic-primitives
public typealias Phase = Cyclic.Group<4>.Element

extension Phase {
    public static var quarter: Self { .one }
    public static var half: Self { .one + .one }
    public static var threeQuarter: Self { .one + .one + .one }
    public var degrees: Int { Int(position.rawValue) * 90 }
}
```

**Pros:**
- Zero code duplication
- Inherits all cyclic arithmetic
- Semantically correct: Phase IS Z₄

**Cons:**
- Loses enum pattern matching
- Domain-specific naming (.quarter) on generic type
- algebra-primitives has no custom Tag types (code smell)

#### Option B: Delete Phase, use `Region.Quadrant` or `Cyclic.Group<4>.Element`

**Rationale:** Phase adds no value over existing types:
- For rotation semantics → use `Region.Quadrant` (already in region-primitives)
- For pure algebra → use `Cyclic.Group<4>.Element`

**Pros:**
- Eliminates duplication
- Clearer separation of concerns

**Cons:**
- Breaking change if Phase is used externally
- Quadrant has Roman numeral naming, not angle naming

#### Option C: Keep Phase as enum, delegate to Cyclic

```swift
public enum Phase: Sendable, Hashable {
    case zero, quarter, half, threeQuarter

    public var cyclic: Cyclic.Group<4>.Element { ... }
    public static func + (lhs: Phase, rhs: Phase) -> Phase { ... }
}
```

**Pros:**
- Preserves enum pattern matching
- Domain-specific naming

**Cons:**
- Code duplication
- Must manually implement arithmetic

#### Option D: `Tagged<Rotation, Cyclic.Group<4>.Element>` pattern

```swift
public enum RotationTag {}
public typealias Phase = Tagged<RotationTag, Cyclic.Group<4>.Element>
```

**Pros:**
- Type-safe distinction from other Z₄ uses
- Inherits arithmetic via `Tagged+Cyclic.Group.Element.swift`

**Cons:**
- No other type in the ecosystem uses a custom Tag (code smell)
- Adds complexity without clear benefit over Option A

### Layering Analysis

Per the five-layer architecture:

| Concept | Layer | Package |
|---------|-------|---------|
| `Cyclic.Group<N>.Element` | Primitives | cyclic-primitives |
| `Index.Cyclic<N>` | Primitives | cyclic-index-primitives |
| Domain interpretations (Quadrant, Clock, Phase) | ? | ? |

**Key insight:** Domain-specific interpretations of cyclic groups belong in domain-specific packages:
- `Region.Quadrant`, `Region.Clock` → region-primitives (spatial regions)
- `Phase` (rotations) → geometry-primitives or symmetry-primitives?

### Comparison Table

| Criterion | Option A (typealias) | Option B (delete) | Option C (enum) | Option D (Tagged) |
|-----------|---------------------|-------------------|-----------------|-------------------|
| Code duplication | None | None | High | None |
| Pattern matching | No | No (Quadrant has it) | Yes | No |
| Type safety | Medium | High (use appropriate type) | High | High |
| Ecosystem consistency | Good | Best | Poor | Poor (no precedent) |
| Migration effort | Medium | High | Low | Medium |

## Constraints

1. **No Foundation** — all primitives packages must remain Foundation-free
2. **Downward dependencies only** — no lateral or upward dependencies
3. **One type per file** — [API-IMPL-005]
4. **Namespace pattern** — [API-NAME-001] Nest.Name required

## Recommendation

**Option B (modified): Delete `Phase` from algebra-primitives, consolidate rotation concepts.**

**Rationale:**
1. `Phase` duplicates `Region.Quadrant` semantically (both are Z₄ with rotation operations)
2. The angle-specific naming (`.quarter`, `.degrees`) belongs in geometry/symmetry, not algebra
3. Literature confirms "phase" in signal processing IS geometric rotation—they're mathematically equivalent
4. No custom Tag types exist elsewhere in the ecosystem (code smell confirmed)

**Callers should use:**
- `Cyclic.Group<4>.Element` — for pure algebraic Z₄
- `Region.Quadrant` — for Cartesian plane quadrants
- `Rotation<2, Scalar>.quarterTurn` etc. — for continuous rotations (already in symmetry-primitives)

**If discrete rotation naming is needed**, add to symmetry-primitives:

```swift
// symmetry-primitives
extension Rotation where N == 2, Scalar: BinaryFloatingPoint & Numeric.Transcendental {
    /// Discrete rotation group: typealias for callers who need Z₄ rotation vocabulary.
    public typealias Discrete = Cyclic.Group<4>.Element
}

// Or as a namespace extension
extension Cyclic.Group where N == 4 {
    /// Convenience accessors with rotation vocabulary.
    public enum Rotation {
        public static var quarter: Element { .one }
        public static var half: Element { .one + .one }
        public static var threeQuarter: Element { .one + .one + .one }
    }
}
```

**Final architecture:**
- **cyclic-primitives** — pure algebraic cyclic groups (`Cyclic.Group<N>.Element`)
- **region-primitives** — spatial region interpretations (`Quadrant`, `Clock`, `Cardinal`)
- **symmetry-primitives** — continuous rotations (`Rotation<N, Scalar>`) + discrete rotation vocabulary if needed

## Next Steps

1. Audit usage of `Phase` across the ecosystem
2. Determine if any code depends on enum pattern matching
3. Decide between deletion or relocation to symmetry-primitives
4. Update `Tagged+Cyclic.Group.Element.swift` in cyclic-primitives for reuse

## Additional Literature Findings

### Phase in Signal Processing IS Geometric Rotation

From [SEG Wiki on Phase Rotation](https://wiki.seg.org/wiki/Phase_rotation):
> "Phase rotation refers to rotation of the complex-trace vector."

From [ScienceDirect on Phase Rotation](https://www.sciencedirect.com/topics/engineering/phase-rotation):
> "A desired phase shift will cause a fixed rotation around the origin (in a constellation, or I vs Q plot)."

**Key insight:** In signal processing, "phase" and "geometric rotation" are mathematically equivalent—both represent rotation of a phasor in the complex plane. This suggests `Phase` naming is appropriate for rotation concepts.

### D₄ vs C₄: Rotation vs Dihedral Symmetry

From [Wikipedia on Dihedral Group D₄](https://en.wikipedia.org/wiki/Dihedral_group_of_order_8):
> "D₄ is the symmetry group of a square... consists of the rotations in C₄ together with reflections."

- **C₄ (cyclic)** = pure rotations only (0°, 90°, 180°, 270°)
- **D₄ (dihedral)** = rotations + reflections (8 elements total)

`Phase` and `Cyclic.Group<4>` model **C₄**, not D₄. If reflection symmetry is ever needed, that's a different type.

### Type Safety Patterns: Newtype vs Enum

From [Rust API Guidelines on Type Safety](https://rust-lang.github.io/api-guidelines/type-safety.html):
> "Using newtypes, we can keep track of the intended interpretation... allowing static type-checking to ensure they aren't confused."

From ["Names are not type safety" by Alexis King](https://lexi-lambda.github.io/blog/2020/11/01/names-are-not-type-safety/):
> "The constructive datatype (enum) captures its invariants in such a way that they are accessible to downstream consumers."

**Implication for Phase:**
- **Newtype/typealias** (`Phase = Cyclic.Group<4>.Element`): Good for units/dimensions, but loses pattern matching
- **Enum**: Captures domain invariants, enables exhaustive matching, but requires manual arithmetic
- **Tagged newtype**: Combines both but adds complexity

### Cyclic Groups in Software

From [Python Abstract Algebra Implementation](https://johnkerl.org/doc/kerl-pyaa.pdf):
> "The data type represents elements of a cyclic group on n elements... The author chose to make the cyclic group concrete by doing addition mod n, taking Cₙ ≅ Z/nZ."

This validates our `Cyclic.Group<N>.Element` approach—abstract cyclic groups are typically implemented as integers mod N.

## References

### Cyclic Groups & Algebra
- [Cyclic group - Wikipedia](https://en.wikipedia.org/wiki/Cyclic_group)
- [Cyclic group:Z4 - Groupprops](https://groupprops.subwiki.org/wiki/Cyclic_group:Z4)
- [Cyclic Groups - Stanford Crypto](https://crypto.stanford.edu/pbc/notes/numbertheory/cyclic.html)
- [Cyclic Groups - Mathematics LibreTexts](https://math.libretexts.org/Bookshelves/Combinatorics_and_Discrete_Mathematics/Applied_Discrete_Structures_(Doerr_and_Levasseur)/15:_Group_Theory_and_Applications/15.01:_Cyclic_Groups)
- [Dihedral Group D₄ - Wikipedia](https://en.wikipedia.org/wiki/Dihedral_group_of_order_8)
- [Dihedral Symmetry D₄: Structure & Applications](https://www.emergentmind.com/topics/dihedral-symmetry-d_4)

### Signal Processing & Phase
- [Phase Rotation - ScienceDirect](https://www.sciencedirect.com/topics/engineering/phase-rotation)
- [Phase Rotation - SEG Wiki](https://wiki.seg.org/wiki/Phase_rotation)
- [Phase (waves) - Wikipedia](https://en.wikipedia.org/wiki/Phase_(waves))
- [I/Q Rotation - Analog Devices Wiki](https://wiki.analog.com/resources/eval/user-guides/ad-fmcomms2-ebz/iq_rotation)

### Data Structures & Algorithms
- [Ring Buffer Data Structure](https://sites.google.com/view/algobytheroyakash/data-structures/ring-buffer)
- [Circular Buffer - Grokipedia](https://grokipedia.com/page/Circular_buffer)
- [Quantum Cyclic Rotation Gate (2024)](https://link.springer.com/article/10.1007/s42979-024-03141-4)

### Type Safety & Language Design
- [Rust API Guidelines - Type Safety](https://rust-lang.github.io/api-guidelines/type-safety.html)
- [Names are not type safety - Alexis King](https://lexi-lambda.github.io/blog/2020/11/01/names-are-not-type-safety/)
- [NewTypes in Rust](https://colinsblog.net/2022-01-29-newtypes/)
- [Rust and Swift Comparison](https://v4.chriskrycho.com/2015/rust-and-swift-ix.html)
- [Concrete Abstract Algebra in Python](https://johnkerl.org/doc/kerl-pyaa.pdf)
