# Labeled Cross-Domain Init Convention for Tagged Types

<!--
---
version: 2.0.0
last_updated: 2026-03-04
status: DECISION
tier: 2
---
-->

## Context

The swift-primitives ecosystem uses `Tagged<Tag, RawValue>` pervasively for phantom-typed values. Cross-domain conversions — operations where a value in one semantic domain is transformed into a value in a different semantic domain — currently use unlabeled `init(_ : SourceType)` per [PATTERN-012] (Initializers as Canonical Implementation).

Same-domain transforms already use `.retag()` (change tag) and `.map()` (transform raw value) — NOT `init(_ :)`. Therefore, all `init(_ :)` patterns on Tagged types are cross-domain conversions.

This convention creates a structural conflict with production `ExpressibleByIntegerLiteral` on `Tagged`, which was blocked in `tagged-literal-conformances.md` v2.0 (DECISION, 2026-02-11) after a confirmed crash: `(0..<5).map(Bit.Index.init)` silently resolved to the byte-to-bit init (multiplying by 8), producing indices 0, 8, 16, 24, 32 instead of 0, 1, 2, 3, 4.

The `revisiting-tagged-production-literal-conformances.md` (DECISION, 2026-03-04) initially concluded that the unlabeled init convention and blanket literal conformance are "structurally incompatible." Deeper analysis (§5a of this document) showed the incompatibility applies only to non-identity-numeric inits — identity-numeric inits are value-safe under literal conformance.

This research examines whether the convention should change, and discovers a third option: keep identity-numeric inits unlabeled, label only non-identity inits, and enable production literal conformance.

## Question

Should the ecosystem convention change from unlabeled `init(_ : SourceType)` to labeled `init(label: SourceType)` for cross-domain conversions on Tagged types?

## Analysis

### 1. Inventory of `init(_ :)` Patterns on Tagged Types

A comprehensive search of `/Users/coen/Developer/swift-primitives/` across all `Sources/` directories identified the following `init(_ :)` patterns on Tagged types or their typealiases.

#### Category A: Same-Domain Identity Wrapping (no transformation)

These inits wrap a raw value into a Tagged type or lift an untagged value into a tagged one with identical numeric representation.

| Init | Source Type | Target Type | Transformation | File |
|------|------------|-------------|----------------|------|
| `Tagged<Tag, Cardinal>.init(_ count: Cardinal)` | `Cardinal` | `Tagged<Tag, Cardinal>` | Identity wrap | `Tagged+Cardinal.swift:25` |
| `Tagged<Tag, Cardinal>.init(_ uint: UInt)` | `UInt` | `Tagged<Tag, Cardinal>` | Wrap via `Cardinal(uint)` | `Tagged+Cardinal.swift:32` |
| `Ordinal.init(_ value: UInt)` | `UInt` | `Ordinal` | Identity wrap | `Ordinal.swift:49` |
| `Memory.Address.init(_ pointer: UnsafeRawPointer)` | `UnsafeRawPointer` | `Memory.Address` | Bit pattern extraction | `Memory.Address.swift:64` |
| `Memory.Address.init(_ pointer: UnsafeMutableRawPointer)` | `UnsafeMutableRawPointer` | `Memory.Address` | Bit pattern extraction | `Memory.Address.swift:82` |
| `Memory.Address.init<T>(_ pointer: UnsafePointer<T>)` | `UnsafePointer<T>` | `Memory.Address` | Pointer erase + bit pattern | `Memory.Address.swift:70` |
| `Memory.Address.init<T>(_ pointer: UnsafeMutablePointer<T>)` | `UnsafeMutablePointer<T>` | `Memory.Address` | Pointer erase + bit pattern | `Memory.Address.swift:76` |
| `UnsafeRawPointer.init(_ address: Memory.Address)` | `Memory.Address` | `UnsafeRawPointer` | Reverse bit pattern | `Memory.Address.swift:137` |
| `UnsafeMutableRawPointer.init(_ address: Memory.Address)` | `Memory.Address` | `UnsafeMutableRawPointer` | Reverse bit pattern | `Memory.Address.swift:145` |

**Count**: 9 production inits.

**Characteristic**: These do not perform semantic transformations. They wrap/unwrap the same numeric value into/out of a typed shell. They are analogous to Swift stdlib's `Int(someInt32)` — lossless, same-family conversions.

#### Category B: Cross-Domain Conversions (semantic transformation)

These inits convert between fundamentally different semantic domains. The numeric value may or may not change, but the domain meaning always changes.

| Init | Source Type | Target Type | Transformation | File |
|------|------------|-------------|----------------|------|
| `Ordinal.init(_ count: Cardinal)` | `Cardinal` | `Ordinal` | Quantity → position (identity numeric) | `Ordinal+Cardinal.Count.swift:15` |
| `Cardinal.init(_ position: Ordinal)` | `Ordinal` | `Cardinal` | Position → quantity (identity numeric) | `Cardinal+Ordinal.swift:15` |
| `Tagged<Tag, Cardinal>.init(_ index: Tagged<Tag, Ordinal>)` | `Tagged<Tag, Ordinal>` | `Tagged<Tag, Cardinal>` | Tagged position → tagged count | `Tagged+Ordinal.swift:34` |
| `Bit.Index.init(_ index: Index<UInt8>)` | `Index<UInt8>` | `Bit.Index` | Byte position → bit position (x8) | `Bit.Index+Byte.swift:29` |
| `Memory.Shift.init(_ cardinal: Cardinal)` | `Cardinal` | `Memory.Shift` | Count → shift (narrowing to UInt8) | `Memory.Shift+Cardinal.Protocol.swift:14` |
| `Affine.Discrete.Ratio.init(_ count: Tagged<To, Cardinal>)` | `Tagged<To, Cardinal>` | `Affine.Discrete.Ratio` | Count → ratio | `Affine.Discrete.Ratio+Tagged.swift:19` |
| `Algebra.Modular.Modulus.init(_ cardinal: Cardinal) throws` | `Cardinal` | `Algebra.Modular.Modulus` | Count → modulus (validated) | `Algebra.Modular.Modulus.swift:25` |
| `Cyclic.Group.Static.init(_ position: Ordinal) throws` | `Ordinal` | `Cyclic.Group.Static` | Position → group element (validated) | `Cyclic.Group.Static.swift:92` |
| `System.Processor.init(_ count: System.Processor.Count)` | `System.Processor.Count` | `System.Processor` | Count → processor set | `System.Processor.swift:96` |

**Count**: 9 production inits.

**Characteristic**: These cross a semantic boundary. `Ordinal.init(_ cardinal: Cardinal)` changes the meaning from "how many" to "which position." `Bit.Index.init(_ index: Index<UInt8>)` scales by 8. `Memory.Shift.init(_ cardinal: Cardinal)` narrows from arbitrary count to shift-sized UInt8.

#### Category C: Protocol-Required Same-Domain Inits

| Init | Protocol | Source | Target | File |
|------|----------|--------|--------|------|
| `Cardinal.Protocol.init(_ cardinal: Cardinal)` | `Cardinal.Protocol` | `Cardinal` | `Self` | `Cardinal.Protocol.swift:42` |
| `Ordinal.Protocol.init(_ ordinal: Ordinal)` | `Ordinal.Protocol` | `Ordinal` | `Self` | `Ordinal.Protocol.swift:54` |

These are protocol requirements with default implementations. They are same-domain by construction.

**Count**: 2 protocol requirements + 4 default implementations.

#### Category D: Non-Tagged Inits Using `init(_ :)`

The search also found ~80 `init(_ :)` patterns that are NOT on Tagged types: optic conversions (`Optic.Prism.init(_ iso:)`), predicate construction, parser construction, binary serialization, etc. These are out of scope for this analysis.

#### Summary

| Category | Count | Labeled? |
|----------|-------|----------|
| A: Identity wrapping | 9 | No — same family |
| B: Cross-domain conversion | 9 | **Question at hand** |
| C: Protocol-required | 6 | No — protocol contract |
| D: Non-Tagged | ~80 | N/A |

### 2. Call Site Audit

#### `.map(Ordinal.init)` Patterns

**199 occurrences** across 106 files in production code. These are overwhelmingly `count.map(Ordinal.init)` — converting a `Tagged<Tag, Cardinal>` (count) to a `Tagged<Tag, Ordinal>` (position/index). This is the single most common cross-domain conversion in the ecosystem.

Representative examples:
```swift
// Array endIndex computation
public var endIndex: Index { count.map(Ordinal.init) }

// Stack top index
let topIndex = _buffer.count.subtract.saturating(.one).map(Ordinal.init)

// Storage slot allocation
let slot = currentCount.map(Ordinal.init)

// Memory pool sentinel
internal var _sentinel: Index<Slot> { _capacity.map(Ordinal.init) }
```

Note: These use `.map(Ordinal.init)`, NOT `Ordinal.init(_:)` directly. The `.map()` is a Tagged functor operation that transforms the raw value while preserving the tag. The `Ordinal.init` here acts as the transformation function passed to `.map()`.

#### `.map(Cardinal.init)` Patterns

**5 occurrences** across 5 files. These convert tagged ordinals to tagged cardinals:
```swift
// Tagged ordinal → tagged cardinal
self = index.map(Cardinal.init)

// Memory buffer slicing
let remaining = _count.subtract.saturating(start.map(Cardinal.init))
```

#### `.map(Bit.Index.init)`, `.map(Index.init)`, `.map(Memory.Address.init)`

**0 occurrences each**. The dangerous patterns do not exist in production code today. The confirmed crash was in test code.

#### Migration Cost Assessment

If the `Ordinal.init(_ : Cardinal)` and `Cardinal.init(_ : Ordinal)` inits were labeled (e.g., `Ordinal.init(counting:)` or `Ordinal.init(cardinal:)`), the 199 `.map(Ordinal.init)` call sites would break. They would need to become either:
- `.map { Ordinal(cardinal: $0) }` — closure-based (loses point-free style)
- A new named method on Tagged, e.g., `.asIndex` or `.asOrdinal` — additional API surface

The `Bit.Index.init(_ : Index<UInt8>)` has **0** `.map(Type.init)` call sites and few direct call sites, making it cheap to label.

### 3. Swift Idiom Analysis

Swift stdlib uses unlabeled `init(_ :)` for:

| Pattern | Example | Characteristic |
|---------|---------|---------------|
| Lossless widening | `Int(someInt32)`, `Double(someFloat)` | Same family, no information loss |
| Exact conversion | `Int(exactly: someDouble)` | Cross-family, uses label |
| Lossy narrowing | `Int(truncatingIfNeeded: someUInt64)` | Cross-family, uses label |
| Reinterpretation | `Int(bitPattern: someUInt)` | Different meaning, uses label |
| String parsing | `Int("42")` | Cross-domain, returns optional |

**Swift's rule**: Unlabeled `init(_ :)` means "lossless, same-family conversion where the target type naturally subsumes the source type." When the conversion crosses a semantic boundary, changes meaning, or can lose information, Swift uses labels.

**Assessment of ecosystem cross-domain inits against this rule**:

| Init | Same family? | Lossless? | Information preserved? | Swift stdlib would label? |
|------|-------------|-----------|----------------------|--------------------------|
| `Ordinal(_ : Cardinal)` | No (quantity → position) | Yes | Numeric identity, semantic change | **Yes** — different domains |
| `Cardinal(_ : Ordinal)` | No (position → quantity) | Yes | Numeric identity, semantic change | **Yes** — different domains |
| `Bit.Index(_ : Index<UInt8>)` | No (byte → bit) | Yes | **No** — scales by 8 | **Yes** — transformation |
| `Memory.Shift(_ : Cardinal)` | No (count → shift) | No (narrows) | **No** — narrows to UInt8 | **Yes** — lossy |
| `Memory.Address(_ : UnsafeRawPointer)` | Analogous (pointer → address) | Yes | Bit pattern preserved | **Borderline** — stdlib uses unlabeled for this family |

By Swift stdlib convention, all Category B inits except possibly `Memory.Address(_ : UnsafeRawPointer)` should have labels. The ecosystem convention [PATTERN-012] diverges from stdlib practice.

### 4. Options

#### Option A: Change Convention — All Cross-Domain Inits Get Labels

**Approach**: Establish a new rule: "Cross-domain conversion inits on Tagged types MUST use argument labels describing the source domain or the transformation."

Proposed labels:

| Current | Proposed | Rationale |
|---------|----------|-----------|
| `Ordinal(_ count: Cardinal)` | `Ordinal(counting cardinal: Cardinal)` | "ordinal counting this many" |
| `Cardinal(_ position: Ordinal)` | `Cardinal(at position: Ordinal)` | "cardinal at this position" |
| `Tagged<Tag, Cardinal>(_ index: Tagged<Tag, Ordinal>)` | `Tagged<Tag, Cardinal>(at index: Tagged<Tag, Ordinal>)` | "count at this index" |
| `Bit.Index(_ index: Index<UInt8>)` | `Bit.Index(byte index: Index<UInt8>)` | "bit index at this byte" |
| `Memory.Shift(_ cardinal: Cardinal)` | `Memory.Shift(count cardinal: Cardinal)` | "shift of this count" |
| `Affine.Discrete.Ratio(_ count: Tagged<To, Cardinal>)` | `Affine.Discrete.Ratio(stride count: Tagged<To, Cardinal>)` | "ratio with this stride" |

**Consequence**: Enables safe production `ExpressibleByIntegerLiteral` on Tagged. The footgun chain breaks because `.map(Bit.Index.init)` no longer matches a labeled init.

#### Option B: Keep Current Convention — Unlabeled Cross-Domain Inits Stay

**Approach**: Maintain [PATTERN-012] as-is. Literal conformance stays test-only (per `revisiting-tagged-production-literal-conformances.md` DECISION).

**Consequence**: `Time.Offset(years: 2)` requires convenience wrapping. No migration cost. The existing 199 `.map(Ordinal.init)` call sites remain untouched.

#### Option C: Hybrid — Label Only Non-Identity Transformations

**Approach**: Label inits that perform non-identity transformations (scaling, narrowing). Keep identity-numeric inits unlabeled.

| Init | Numeric Change? | Label? |
|------|----------------|--------|
| `Ordinal(_ : Cardinal)` | No (identity) | **Keep unlabeled** |
| `Cardinal(_ : Ordinal)` | No (identity) | **Keep unlabeled** |
| `Tagged<Tag,Cardinal>(_ : Tagged<Tag,Ordinal>)` | No (identity) | **Keep unlabeled** |
| `Bit.Index(_ : Index<UInt8>)` | Yes (x8) | **Add label: `byte:`** |
| `Memory.Shift(_ : Cardinal)` | Yes (narrows) | **Add label: `count:`** |
| `Affine.Discrete.Ratio(_ : Tagged<To, Cardinal>)` | Yes (reinterprets) | **Add label: `stride:`** |

**Consequence**: The 199 `.map(Ordinal.init)` call sites are preserved. The `Bit.Index` footgun is eliminated. The identity-numeric crossings (`Ordinal(_ : Cardinal)`) remain unlabeled — Swift could infer `Range<Cardinal>` from `0..<5` and pass elements through `Ordinal.init` — but because identity-numeric conversions preserve the raw value, the resulting VALUES are correct. The type inference path is unexpected but harmless. See §5a (Safety Analysis) below.

### 5. Evaluation

#### [IMPL-INTENT] Alignment

| Option | Assessment |
|--------|-----------|
| **A: Label all** | **Strong alignment**. Labels express the domain crossing as intent: `Ordinal(counting: count)` reads "create a position by counting." The current `Ordinal(count)` hides the semantic shift — it reads as identity wrapping. |
| **B: Keep unlabeled** | **Weak alignment**. The unlabeled form `Ordinal(count)` looks like identity wrapping but is actually a domain crossing. This is mechanism masquerading as intent — the reader must know `Ordinal != Cardinal` to understand the code. |
| **C: Hybrid** | **Partial alignment**. Scaling/narrowing inits get intent-expressing labels. Identity-numeric crossings remain ambiguous. |

#### Migration Cost

| Option | Scope | Effort |
|--------|-------|--------|
| **A: Label all** | 199 `.map(Ordinal.init)` + 5 `.map(Cardinal.init)` + ~20 direct call sites = **~224 call sites** across 61+ packages | **Very high** — multi-day mechanical migration touching nearly every data structure package |
| **B: Keep unlabeled** | Zero migration | **Zero** |
| **C: Hybrid** | ~5 call sites for `Bit.Index`, ~3 for `Memory.Shift`, ~2 for `Affine.Discrete.Ratio` = **~10 call sites** | **Very low** |

#### Literal Conformance Safety

| Option | Safe for production `ExpressibleByIntegerLiteral` on Tagged? |
|--------|--------------------------------------------------------------|
| **A: Label all** | **Yes**. No unlabeled init can capture literal-inferred types in `.map(Type.init)` contexts. |
| **B: Keep unlabeled** | **No**. Literal conformance remains test-only. |
| **C: Hybrid** | **Yes**. The identity-numeric crossings (`Ordinal(_ : Cardinal)`) remain unlabeled, so Swift can infer `Range<Cardinal>` from `0..<5`. But identity-numeric conversions preserve the raw value — the resulting VALUES are correct. The type inference path is unexpected but the output is identical. The 3 non-identity inits (the only ones that produce WRONG values) are labeled. See §5a. |

#### Call Site Expressiveness

| Option | `.map` pattern | Direct construction |
|--------|---------------|-------------------|
| **A: Label all** | `.map { Ordinal(counting: $0) }` — verbose, loses point-free style | `Ordinal(counting: count)` — clearer intent |
| **B: Keep unlabeled** | `.map(Ordinal.init)` — clean, idiomatic | `Ordinal(count)` — concise but ambiguous |
| **C: Hybrid** | `.map(Ordinal.init)` preserved; `Bit.Index(byte: idx)` for scaling | Mixed — some clean, some labeled |

Note: The 199 `.map(Ordinal.init)` call sites could be preserved under Option A if a point-free accessor were added, such as `Cardinal.ordinal` (computed property) enabling `.map(\.ordinal)` or a dedicated `.asOrdinal` method. This would actually be more expressive than the current `.map(Ordinal.init)`.

#### Ecosystem Consistency

| Option | Assessment |
|--------|-----------|
| **A: Label all** | Fully consistent — all cross-domain conversions labeled, all identity wrapping unlabeled. Clear rule. |
| **B: Keep unlabeled** | Consistent with existing convention [PATTERN-012] but inconsistent with Swift stdlib idiom. |
| **C: Hybrid** | Introduces a second criterion (does the numeric value change?) that must be remembered. Less consistent. |

#### 5a. Safety Analysis: Identity-Numeric Inits Under Literal Conformance

The v2.0 decision (`tagged-literal-conformances.md`) and the initial Option C assessment assumed that ANY unlabeled cross-domain init + literal conformance = unsafe. This section demonstrates that assumption was too broad.

**The footgun requires a non-identity numeric transformation.** The confirmed crash (`Bit.Index ×8`) produced wrong VALUES — 0, 8, 16, 24, 32 instead of 0, 1, 2, 3, 4. This is what makes it dangerous. But identity-numeric inits (`Ordinal(_ : Cardinal)`, `Cardinal(_ : Ordinal)`, `Tagged<Tag,Cardinal>(_ : Tagged<Tag,Ordinal>)`) preserve the raw value — the output is numerically identical regardless of which type inference path Swift takes.

**Proof by example**:

```swift
// Programmer writes:
let counts = (0..<5).map(Index<Element>.Count.init)

// Path A (without Tagged literal conformance):
//   0..<5 → Range<UInt> → .map(Tagged<Tag,Cardinal>.init(_: UInt)) → [0, 1, 2, 3, 4]

// Path B (WITH Tagged literal conformance):
//   0..<5 → Range<Index<Element>> → .map(Tagged<Tag,Cardinal>.init(_: Tagged<Tag,Ordinal>))
//   → identity numeric → [0, 1, 2, 3, 4]

// Both paths produce IDENTICAL values.
```

**Exhaustive verification**: All 9 Category B cross-domain inits classified by safety under literal conformance:

| Init | Numeric change? | Values correct under wrong inference? | Footgun risk |
|------|----------------|--------------------------------------|--------------|
| `Ordinal(_ : Cardinal)` | No (identity) | **Yes** | None |
| `Cardinal(_ : Ordinal)` | No (identity) | **Yes** | None |
| `Tagged<Tag,Cardinal>(_ : Tagged<Tag,Ordinal>)` | No (identity) | **Yes** | None |
| `System.Processor(_ : Count)` | No (identity) | **Yes** | None |
| `Algebra.Modular.Modulus(_ : Cardinal) throws` | No (validated) | N/A — throwing, can't be matched by non-throwing `.map` | None |
| `Cyclic.Group.Static(_ : Ordinal) throws` | No (validated) | N/A — throwing, can't be matched by non-throwing `.map` | None |
| `Bit.Index(_ : Index<UInt8>)` | **Yes (×8)** | **No — WRONG values** | **Eliminated by label** |
| `Memory.Shift(_ : Cardinal)` | **Yes (narrows)** | **No — lossy** | **Eliminated by label** |
| `Affine.Discrete.Ratio(_ : Tagged<To,Cardinal>)` | **Yes (reinterprets)** | **No — wrong semantics** | **Eliminated by label** |

**Conclusion**: With the 3 non-identity inits labeled, ALL remaining unlabeled cross-domain inits are identity-numeric. Production `ExpressibleByIntegerLiteral` on `Tagged` is safe under Option C.

**Convention rule for future-proofing**: "Unlabeled `init(_ :)` on Tagged types MUST preserve numeric identity. Non-identity transformations (scaling, narrowing, reinterpretation) MUST use argument labels." This is enforceable during code review.

### Comparison Table

| Criterion | A: Label All | B: Keep Unlabeled | C: Hybrid |
|-----------|-------------|-------------------|-----------|
| [IMPL-INTENT] alignment | **Strong** | Weak | Partial |
| Migration cost | Very high (~224 sites) | Zero | Very low (~10 sites) |
| Literal conformance safety | **Safe** | Unsafe (test-only) | **Safe** (§5a) |
| Call site expressiveness | Verbose (mitigable) | Clean point-free | Mixed |
| Ecosystem consistency | **Full** | Existing convention | Fragmented |
| Swift stdlib idiom match | **Yes** | No | Partial |
| Prevents confirmed footgun | **Yes** | No (contained to tests) | **Yes** |
| Prevents future footgun class | **Yes** | No | **Yes** (convention rule) |
| Rule simplicity | One rule: cross-domain = labeled | One rule: all inits unlabeled | Two rules: depends on numeric change |

## Constraints

1. **[PATTERN-012] is load-bearing**: The unlabeled convention is not accidental — it is codified in the implementation skill as a normative rule. Changing it requires a formal convention amendment, not just a code change.

2. **199 `.map(Ordinal.init)` call sites dominate**: The Cardinal-to-Ordinal conversion is by far the most common cross-domain init. Any labeling strategy must address this migration cost or provide a zero-cost alternative (property, method).

3. **`.map(Type.init)` point-free style is valued**: The ecosystem uses the functor `.map()` pattern extensively. Losing point-free style for the most common conversion would be a significant ergonomic regression.

4. **The Bit.Index fix is independent**: Regardless of the convention decision, the `byte:` label on `Bit.Index+Byte.swift` should be applied. This was recommended in `cross-domain-init-overload-resolution-footgun.md` (2026-02-11) and has not been implemented. It has ~0 call sites to migrate.

5. **Production literal conformance is blocked until this is resolved**: The `revisiting-tagged-production-literal-conformances.md` DECISION explicitly stated that unlabeled inits foreclose blanket literals. If the convention changes, that decision can be revisited.

6. **A property-based alternative could preserve point-free style**: Instead of `count.map(Ordinal.init)`, the ecosystem could provide `count.ordinal` (a computed property on `Tagged<Tag, Cardinal>` returning `Tagged<Tag, Ordinal>`). This would be more expressive than the current pattern while eliminating the unlabeled init dependency. However, this requires designing and implementing a new family of properties.

## Outcome

**Status**: DECISION

### Decision: Option C (Hybrid) — Label Non-Identity Inits + Production Literal Conformance

**The unlabeled `init(_ :)` convention is correct for identity-numeric conversions.** The `.map(Type.init)` pattern was deliberately designed to avoid conversion property explosion. The alternative — adding `.ordinal`, `.cardinal`, etc. as properties — would require each type to know about every type it can convert to. This violates separation of concerns and leads to quadratic API surface growth.

The `.map(Type.init)` pattern is superior because:
1. **No property explosion**: The conversion knowledge lives in the target type's init (one place). The source type doesn't need properties for every possible target.
2. **Generic composition**: `.map()` is a functor operation on Tagged. It works with ANY init, not just pre-declared conversions.
3. **Point-free style**: `count.map(Ordinal.init)` is clean and composable.
4. **[PATTERN-012] alignment**: The init IS the canonical conversion. `.map()` is just the application mechanism.

**The tradeoff is resolved, not principled:**

The v1.0 analysis presented this as a forced choice:

| Choice | Enables | Costs |
|--------|---------|-------|
| Unlabeled `init(_ :)` + `.map(Type.init)` | Clean point-free cross-domain conversion, no property explosion | Production literal conformance blocked |
| Labeled inits + conversion properties | Production literal conformance | Property explosion, loses point-free style |

The §5a safety analysis shows the first row's "cost" column was overstated. Production literal conformance is NOT blocked by identity-numeric unlabeled inits — only by non-identity ones. Labeling only the 3 non-identity inits gives us both: `.map(Type.init)` point-free style AND production literal conformance.

**Label the 3 non-identity-numeric inits:**
- Label `Bit.Index.init(_ index: Index<UInt8>)` → `Bit.Index.init(byte index: Index<UInt8>)` — scaling transformation (×8), 0 `.map` call sites
- Label `Memory.Shift.init(_ cardinal: Cardinal)` → `Memory.Shift.init(count cardinal: Cardinal)` — narrowing conversion
- Label `Affine.Discrete.Ratio.init(_ count: Tagged<To, Cardinal>)` → `Affine.Discrete.Ratio.init(stride count: Tagged<To, Cardinal>)` — reinterpretation

These are non-controversial because they perform actual numeric transformations AND have zero `.map(Type.init)` call sites. They don't break the point-free pattern.

**Enable production `ExpressibleByIntegerLiteral` on `Tagged`:**
- Move blanket conformance from test support to production in identity-primitives
- Safe because all remaining unlabeled cross-domain inits are identity-numeric (§5a)
- Restores ergonomic construction for 83+ Tagged typealiases
- Consistent with `Scale` and `Interval.Unit` which already have production literal conformances

**Convention rule**: "Unlabeled `init(_ :)` on Tagged types MUST preserve numeric identity. Non-identity transformations (scaling, narrowing, reinterpretation) MUST use argument labels."

**Implication for `Time.Offset`**: With production literal conformance, `Tagged<Time.Year, Int>` accepts literals directly. A convenience init accepting `Int` parameters is still good API design per [IMPL-010], but default parameter values and inline construction work without wrapping.

## References

### Primary Sources
- `swift-tagged-primitives/Research/tagged-literal-conformances.md` v2.0 — DECISION blocking production literal conformances
- `swift-primitives/Research/cross-domain-init-overload-resolution-footgun.md` — confirmed crash analysis and labeling recommendation
- `swift-tagged-primitives/Research/revisiting-tagged-production-literal-conformances.md` — analysis of convention vs. literal conformance structural incompatibility

### Convention References
- [PATTERN-012] — Initializers as Canonical Implementation (current convention)
- [IMPL-INTENT] — Code Reads as Intent, Not Mechanism (foundational axiom)
- [IMPL-010] — Push Int to the Edge (boundary overload principle)
- [PATTERN-017] — rawValue and Property Access Location
- [PATTERN-019] — No Blanket Tagged Init Constructors

### Inventory Data
- 199 `.map(Ordinal.init)` occurrences across 106 files (production code)
- 5 `.map(Cardinal.init)` occurrences across 5 files (production code)
- 0 `.map(Bit.Index.init)`, `.map(Index.init)`, `.map(Memory.Address.init)` occurrences
- 9 Category A (identity wrapping) inits
- 9 Category B (cross-domain conversion) inits
- 6 Category C (protocol-required) inits

### Code Locations
- `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal+Cardinal.Count.swift` — `Ordinal.init(_ count: Cardinal)`
- `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Cardinal+Ordinal.swift` — `Cardinal.init(_ position: Ordinal)`
- `swift-ordinal-primitives/Sources/Ordinal Primitives/Tagged+Ordinal.swift` — `Tagged<Tag,Cardinal>.init(_ index: Tagged<Tag,Ordinal>)`
- `swift-bit-index-primitives/Sources/Bit Index Primitives/Bit.Index+Byte.swift` — `Bit.Index.init(_ index: Index<UInt8>)` (unfixed as of 2026-03-04)
- `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Shift+Cardinal.Protocol.swift` — `Memory.Shift.init(_ cardinal: Cardinal)`
- `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Address.swift` — pointer-to-address inits
- `swift-cardinal-primitives/Sources/Cardinal Primitives/Tagged+Cardinal.swift` — `Tagged<Tag,Cardinal>.init(_ count: Cardinal)`
- `swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete.Ratio+Tagged.swift` — `Ratio.init(_ count: Tagged<To, Cardinal>)`
