# Audit: Swift Primitives Ecosystem

## Conversions — 2026-03-24

### Scope

- **Target**: swift-primitives, swift-standards, swift-foundations (ecosystem-wide)
- **Skill**: conversions — [CONV-001], [CONV-016], [IDX-007]
- **Files**: All `Sources/` across three superrepos
- **Subject**: Bare `Cardinal`/`Ordinal` used where phantom-tagged `Index<T>.Count`/`Index<T>` is semantically correct

### Pattern

A property uses a bare type (`Cardinal`, `Ordinal`) when the value is semantically scoped to a specific domain. This forces every consumer to construct a phantom-typed wrapper from scratch rather than transforming an already-typed value.

```swift
// Anti-pattern: bare Cardinal at the source
public let count: Cardinal

// Consumer must construct from scratch — domain information is lost
var count: Index<Element>.Count {
    Index<Element>.Count(_storage.count)    // wrapping bare value
}
```

The fix: type the property with the narrowest correct phantom-tagged type. Consumers then use `.retag` to change domain, keeping the full chain typed.

```swift
// Fixed: typed at the source
public let count: Index<UInt8>.Count

// Consumer retags — zero-cost, typed transformation
var count: Index<Element>.Count {
    _storage.count.retag(Element.self)      // tag-to-tag, no bare value
}
```

**Why this matters**:

1. **Domain safety** — bare `Cardinal` mixes freely with any other `Cardinal`; `Tagged<UInt8, Cardinal>` is domain-locked (`where O.Domain == C.Domain` on arithmetic).
2. **Typed chain preservation** — `.retag` is a typed transformation; construction from bare is trust-me untyped.
3. **Zero-cost** — `Tagged<Tag, Cardinal>` has identical layout to `Cardinal`. Retagging is a no-op at runtime.
4. **Boundary clarity** — bare types belong only at true system boundaries (`Int(bitPattern: count.cardinal)` at stdlib/C interface).

**When bare types are correct**:

- **Abstraction-over-self** — `Cardinal.Protocol.cardinal` and `Ordinal.Protocol.ordinal` abstract over the bare type itself. Tagged would be circular.
- **Domain-defining values** — `Algebra.Modular.Modulus.cardinal` and `Cyclic.Group.Modulus.value` represent group orders as pure mathematical quantities. The modulus *defines* the domain, not a value *within* a domain.
- **Stdlib intake boundaries** — `Cardinal(UInt(span.count))` wrapping a stdlib `Int` into bare `Cardinal` at intake is correct. The anti-pattern is *storing* and *propagating* bare after intake.

**Diagnostic**:

```bash
# Bare Cardinal/Ordinal stored properties
grep -rn 'let \w\+: Cardinal\b\|var \w\+: Cardinal\b' Sources/
grep -rn 'let \w\+: Ordinal\b\|var \w\+: Ordinal\b' Sources/

# Construction-from-bare symptom (consumer side)
grep -rn 'Index<.*>.Count(.*\.count)\|Index<.*>.Offset(.*\.offset)' Sources/

# Double .rawValue code smell
grep -rn '\.rawValue\.rawValue' Sources/ Tests/
```

**Mechanical fix** (per instance):

1. Change the stored property / protocol requirement type
2. Update initializers (push typed boundary outward to callers)
3. Update stdlib boundary conversions: `Int(bitPattern: count)` → `Int(bitPattern: count.cardinal)`
4. Update consumers: construction from bare → `.retag(Element.self)`

### Findings — Protocol Requirements

5 protocols in swift-primitives declare bare `Cardinal`/`Ordinal` in requirements.

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [CONV-016] | `Finite.Capacity.swift:12` | `static var capacity: Cardinal` → `Index<Self>.Count`. 2 conformers (`Finite.Bound<let N>`, `Algebra.Residue<let n>`). | OPEN |
| 2 | HIGH | [CONV-016] | `Finite.Enumerable.swift:38,41,50` | 3 bare requirements: `count: Cardinal` → `Index<Self>.Count`, `ordinal: Ordinal` → `Index<Self>`, `init(__unchecked:ordinal: Ordinal)` → `Index<Self>`. 16 conformers. Largest blast radius in this audit. | OPEN |
| 3 | MEDIUM | [CONV-016] | `Sequence.Iterator.Protocol.swift:125` | `nextSpan(maximumCount: Cardinal)` — caller-supplied batch limit. Bare `Cardinal` here acts as universal "how many" without requiring callers to tag their batch size. If changed, `next()` default (line 142) and `skip(by:)` (line 160) also need updating. | DEFERRED — domain-free argument; caller rarely has a tagged count in scope |
| 4 | — | — | `Cardinal.Protocol.swift:39,42` | `cardinal: Cardinal` / `init(_ cardinal: Cardinal)` — abstraction-over-self. Bare type is the thing being abstracted. | FALSE_POSITIVE |
| 5 | — | — | `Ordinal.Protocol.swift:51,54` | `ordinal: Ordinal` / `init(_ ordinal: Ordinal)` — abstraction-over-self. Same rationale. | FALSE_POSITIVE |

### Findings — Stored Properties

24 stored properties across swift-primitives use bare `Cardinal` or `Ordinal`. swift-standards and swift-foundations: zero hits.

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 6 | HIGH | [CONV-016] | `Sequence.Difference.Hunk.swift:26-32` | 4 public stored properties: `oldStart: Ordinal`, `oldCount: Cardinal`, `newStart: Ordinal`, `newCount: Cardinal`. All semantically scoped to diff line positions. Needs phantom tag design decision (`Sequence.Difference.Old`/`.New` or a single `Line` tag). | OPEN |
| 7 | MEDIUM | [CONV-016] | `Swift.Span.Iterator.swift:32,35` + `Batch.swift:33,36` | 4 `@usableFromInline` properties: `_position: Ordinal` → `Index<Element>`, `_count: Cardinal` → `Index<Element>.Count`. No public API impact. | OPEN |
| 8 | MEDIUM | [CONV-016] | `Sequence.Drop.First.swift:32` + `Iterator.swift:41` + `Prefix.First.swift:33` + `Iterator.swift:30` | 4 `@usableFromInline` properties: `_count`/`_remaining: Cardinal` → `Index<Base.Element>.Count`. No public API impact. | OPEN |
| 9 | MEDIUM | [CONV-016] | `Steps.Iterator.swift:15,18` + `Changes.Iterator.swift:15,18` | 4 `@usableFromInline` properties: `_index: Ordinal` → `Index<Step/Change>`, `_count: Cardinal` → `Index<Step/Change>.Count`. | OPEN |
| 10 | MEDIUM | [CONV-016] | `Cyclic.Group.Static.swift:80` + `Iterator.swift:28,31` + `Element.swift:43` | 4 properties: `position: Ordinal` (public), `current: Ordinal`, `bound: Cardinal` (internal), `residue: Ordinal` (public). Tagged replacements: `Ordinal.Finite<modulus>` or `Index<Element>`. Needs design decision for cyclic group domain tagging. | OPEN |
| 11 | LOW | [CONV-016] | `Parser.Machine.Memoization.Key.swift:18` | `node: Ordinal` (package let) → `Index<Parser.Machine.Node>`. Textbook case for phantom tagging but low priority (internal to parser machine). | OPEN |
| 12 | MEDIUM | [CONV-016] | `Theme.swift:30` | `ordinal: Ordinal` (public stored) → `Index<Theme>`. Depends on finding #2 (`Finite.Enumerable` protocol fix). Will resolve automatically when the protocol changes. | OPEN |
| 13 | — | [CONV-016] | `Buffer.Aligned.swift` | `count: Cardinal` → `Index<UInt8>.Count`. 4 files changed, zero downstream breakage. Commit `4167371`. | RESOLVED 2026-03-22 |
| 14 | — | — | `Cyclic.Group.Modulus.swift:26`, `Algebra.Modular.Modulus.swift:18` | `value: Cardinal` / `cardinal: Cardinal`. Modulus *defines* the domain — bare type is correct. Containing type provides semantic safety. | FALSE_POSITIVE |

### Remediation Plan

#### Prerequisites

| Prerequisite | Status | Notes |
|---|---|---|
| Cross-type comparison (`Index<T> < Index<T>.Count`) | DONE | Generic operators in `Ordinal+Cardinal.swift` with `where O.Domain == C.Domain`. [IDX-007]. |
| `Tagged: ExpressibleByIntegerLiteral` | DEFERRED | See `swift-identity-primitives/Research/tagged-literal-conformances.md` v3.0 DECISION. Conformers use tier 4 typed initializers: `Index<Self>.Count(2)` instead of bare `2`. Acceptable per [CONV-016]. |

#### Phases

```
Phase 0: Prerequisites ─── DONE (comparison exists, literals deferred)
    │
Phase 1: Finite.Capacity ──── smallest protocol, 2 conformers (finding #1)
    │
Phase 2: Finite.Enumerable ── largest blast radius, 16 conformers (finding #2)
    │
    ├── Phase 3: Sequence iterator internals (findings #7, #8) — independent
    │
    ├── Phase 4: Sequence.Iterator.Protocol (finding #3) — depends on Phase 3
    │
    ├── Phase 5: Sequence.Difference.Hunk (finding #6) — needs design decision
    │
    └── Phase 6: Cyclic + parser (findings #10, #11) — independent
```

Phases 1→2 are sequential. Phases 3–6 are independent and can proceed in any order after Phase 2.

#### Phase 1: `Finite.Capacity` (finding #1)

**Package**: `swift-finite-primitives`
**Change**: `static var capacity: Cardinal` → `static var capacity: Index<Self>.Count`

| Conformer | File | Current | After |
|-----------|------|---------|-------|
| `Finite.Bound<let N: Int>` | `Finite.Capacity.swift:21` | `Cardinal(UInt(N))` | `Index<Self>.Count(Cardinal(UInt(N)))` |
| `Algebra.Residue<let n: Int>` | `Algebra.Residue.swift:11` | `.init(integerLiteral: UInt(n))` | `Index<Self>.Count(Cardinal(UInt(n)))` |

Downstream: `Tagged where Tag: Finite.Capacity` uses `Tag.capacity` to provide `Finite.Enumerable.count`.

#### Phase 2: `Finite.Enumerable` (finding #2)

**Package**: `swift-finite-primitives`
**Depends on**: Phase 1

Protocol change:

```swift
// Before
public protocol Enumerable: CaseIterable, Sendable {
    static var count: Cardinal { get }
    var ordinal: Ordinal { get }
    init(__unchecked: Void, ordinal: Ordinal)
}

// After
public protocol Enumerable: CaseIterable, Sendable {
    static var count: Index<Self>.Count { get }
    var ordinal: Index<Self> { get }
    init(__unchecked: Void, ordinal: Index<Self>)
}
```

**Conformer blast radius: `count`** (16 conformers)

| Conformer | Current | After |
|-----------|---------|-------|
| `Bit` | `Cardinal(2)` | `Index<Self>.Count(2)` |
| `Bit.Order` | `2` | `Index<Self>.Count(2)` |
| `Gradient` | `2` | `Index<Self>.Count(2)` |
| `Endpoint` | `2` | `Index<Self>.Count(2)` |
| `Boundary` | `2` | `Index<Self>.Count(2)` |
| `Bound` | `2` | `Index<Self>.Count(2)` |
| `Parity` | `2` | `Index<Self>.Count(2)` |
| `Comparison` | `3` | `Index<Self>.Count(3)` |
| `Monotonicity` | `3` | `Index<Self>.Count(3)` |
| `Ternary` | `3` | `Index<Self>.Count(3)` |
| `Polarity` | `3` | `Index<Self>.Count(3)` |
| `Sign` | `3` | `Index<Self>.Count(3)` |
| `Rotation.Phase` | `4` | `Index<Self>.Count(4)` |
| `Axis<N>` | `Cardinal.init(integerLiteral: UInt(N))` | `Index<Self>.Count(Cardinal(UInt(N)))` |
| `Theme` | `= 2` (stored let) | `= Index<Theme>.Count(2)` |
| `Tagged (conditional)` | `Tag.capacity` | `Tag.capacity.retag(Self.self)` (tier 1 retag) |

**Conformer blast radius: `ordinal`** (16 conformers)

| Conformer | Current | After |
|-----------|---------|-------|
| 11 enum conformers | switch returning `0`, `1`, `2` | switch returning `Index<Self>(0)`, `Index<Self>(1)`, `Index<Self>(2)` |
| `Bit` | `Ordinal(UInt(rawValue))` | `Index<Self>(Ordinal(UInt(rawValue)))` |
| `Rotation.Phase` | `Ordinal(UInt(rawValue))` | `Index<Self>(Ordinal(UInt(rawValue)))` |
| `Axis<N>` | `.init(UInt8(rawValue))` | `Index<Self>(Ordinal(UInt8(rawValue)))` |
| `Tagged (conditional)` | `rawValue` | `Index<Self>(rawValue)` |
| `Theme` | stored `let ordinal: Ordinal` | stored `let ordinal: Index<Theme>` |

**Conformer blast radius: `init(__unchecked:ordinal:)`** (16 conformers)

| Conformer | Current | After |
|-----------|---------|-------|
| 11 enum conformers | `[.cases][ordinal]` | `[.cases][ordinal.ordinal]` |
| `Bit` | `UInt8(truncatingIfNeeded: ordinal.rawValue)` | `UInt8(truncatingIfNeeded: ordinal.ordinal.rawValue)` |
| `Rotation.Phase` | `Int(ordinal.rawValue)` | `Int(ordinal.ordinal.rawValue)` |
| `Axis<N>` | `Int(bitPattern: ordinal)` | `Int(bitPattern: ordinal.ordinal)` |
| `Tagged (conditional)` | `self.init(__unchecked: (), ordinal)` | `self.init(__unchecked: (), ordinal.ordinal)` |
| `Theme` | `self.ordinal = ordinal` | `self.ordinal = ordinal` (types match) |

**Consumer improvements**:

| Consumer | Current | After | Tier |
|----------|---------|-------|------|
| `Finite.Enumeration.endIndex` | `Index.Count(Element.count).map(Ordinal.init)` | `Element.count.map(Ordinal.init)` | 4→2 |
| `Finite.Enumeration.Iterator.next()` | `index < Element.count` | `index < Element.count` (cross-type comparison) | unchanged |
| `Finite.Enumeration.count` | `Int(clamping: Element.count)` | `Int(clamping: Element.count.cardinal)` | boundary |

Files touched: `Finite.Enumerable.swift`, `Finite.Capacity.swift`, `Tagged+Finite.Enumerable.swift`, `Finite.Enumeration.swift`, `Finite.Bounded.swift` (swift-finite-primitives); `Bit+Finite.Enumerable.swift` (swift-bit-primitives); `Rotation.Phase.swift` (swift-symmetry-primitives); `Axis+CaseIterable.swift` (swift-dimension-primitives); `Theme.swift` (swift-color-standard).

#### Phase 3: Sequence iterator internals (findings #7, #8)

**Package**: `swift-sequence-primitives`
**Independent of Phases 1–2.** All `@usableFromInline` — no public API change.

| Type | Property | Current | After |
|------|----------|---------|-------|
| `Swift.Span<Element>.Iterator` | `_position` | `Ordinal` | `Index<Element>` |
| `Swift.Span<Element>.Iterator` | `_count` | `Cardinal` | `Index<Element>.Count` |
| `Swift.Span<Element>.Iterator.Batch` | `_position` | `Ordinal` | `Index<Element>` |
| `Swift.Span<Element>.Iterator.Batch` | `_count` | `Cardinal` | `Index<Element>.Count` |
| `Sequence.Drop.First` | `_count` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Drop.First.Iterator` | `_remaining` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Prefix.First` | `_count` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Prefix.First.Iterator` | `_remaining` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Difference.Steps.Iterator` | `_index` | `Ordinal` | domain-dependent |
| `Sequence.Difference.Steps.Iterator` | `_count` | `Cardinal` | domain-dependent |
| `Sequence.Difference.Changes.Iterator` | `_index` | `Ordinal` | domain-dependent |
| `Sequence.Difference.Changes.Iterator` | `_count` | `Cardinal` | domain-dependent |

#### Phase 4: `Sequence.Iterator.Protocol` (finding #3)

**Package**: `swift-sequence-primitives`
**Depends on**: Phase 3

```swift
// Before
mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element>

// After
mutating func nextSpan(maximumCount: Index<Element>.Count) -> Swift.Span<Element>
```

Update default implementations (`next()`, `skip(by:)`) and all conformers. Currently DEFERRED — `maximumCount` is a caller-supplied limit where callers rarely have a tagged count in scope.

#### Phase 5: `Sequence.Difference.Hunk` (finding #6)

**Package**: `swift-sequence-primitives`

| Property | Current | After |
|----------|---------|-------|
| `oldStart` | `Ordinal` | needs phantom tag decision |
| `oldCount` | `Cardinal` | needs phantom tag decision |
| `newStart` | `Ordinal` | needs phantom tag decision |
| `newCount` | `Cardinal` | needs phantom tag decision |

**Open question**: what phantom tags represent "old line" vs "new line"? Options: `Sequence.Difference.Old`/`.New`, or a single `Line` tag with old/new as separate properties.

#### Phase 6: Cyclic groups + parser (findings #10, #11)

| Type | Property | Current | After |
|------|----------|---------|-------|
| `Cyclic.Group.Static<N>.Element` | `position` | `Ordinal` | `Ordinal.Finite<N>` |
| `Cyclic.Group.Static<N>.Iterator` | `current` | `Ordinal` | `Ordinal.Finite<N>` or `Index<Element>` |
| `Cyclic.Group.Static<N>.Iterator` | `bound` | `Cardinal` | `Cardinal.Finite<N>` or `Index<Element>.Count` |
| `Cyclic.Group.Element` | `residue` | `Ordinal` | case-by-case |
| `Parser.Machine.Memoization.Key` | `node` | `Ordinal` | `Index<Parser.Machine.Node>` |

### Precedent

**Buffer.Aligned.count** (`swift-buffer-primitives`): `Cardinal` → `Index<UInt8>.Count`. Commit `4167371`. Four files changed, zero downstream breakage across the full swift-primitives superrepo. This established the mechanical pattern used throughout this audit.

### Conversion Tier Reference

Per [CONV-016], conformer code uses tier 4 typed initializers (`Index<Self>.Count(2)`). Consumer code improves to tier 1–2 (retag/map). See `/conversions` skill for the full hierarchy.

### Summary

14 findings: 0 critical, 3 high, 7 medium, 1 low, 1 deferred, 2 false positives. 1 resolved (Buffer.Aligned.count).

**Systemic pattern**: All bare-type violations are in swift-primitives L1 (tiers 1–5). swift-standards and swift-foundations already use tagged types throughout — the anti-pattern exists only at the lowest infrastructure level where the typed index system was introduced after the original APIs were written.

**High-priority**: Findings #1–2 (`Finite.Capacity` + `Finite.Enumerable`) are the keystone — fixing the protocol requirements automatically propagates through all 16 conformers and unlocks consumer improvements. Finding #6 (`Sequence.Difference.Hunk`) is the only other public API violation.

**Design decisions needed**: Finding #6 (Hunk phantom tag: `Old`/`New` vs `Line`) and finding #10 (cyclic group domain tagging strategy).

## Memory Safety — 2026-03-25

### Scope

- **Target**: swift-primitives, swift-standards, swift-foundations (ecosystem-wide)
- **Skill**: memory — [MEM-SAFE-001], [MEM-SAFE-002], [MEM-SAFE-010], [MEM-SAFE-012], [MEM-SAFE-014], [MEM-SAFE-020–025], [MEM-UNSAFE-003], [MEM-SEND-001]
- **Reference**: `swift-institute/Research/swift-safety-model-reference.md`
- **Files**: All `Sources/` across three superrepos

### Per-Package Triage

| Superrepo | Findings | Worst Severity | Notes |
|-----------|----------|---------------|-------|
| swift-primitives | 19 actionable | HIGH | Bare `@unchecked Sendable` (4 types), Arena pointer exposure (1 HIGH), Property.View family (MEDIUM), ~Escapable views (LOW) |
| swift-standards | 4 | MEDIUM | Test sub-packages missing `.strictMemorySafety()`; zero unsafe code |
| swift-foundations | 26 actionable | MEDIUM | 13 packages missing `.strictMemorySafety()`, `Async.*` Sendable gaps |

### Findings — Strict Memory Safety Enablement [MEM-SAFE-001]

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | — | [MEM-SAFE-001] | swift-primitives `Package.swift:537-552` | `.strictMemorySafety()` enabled globally via loop over all targets. Every sub-package also has it. | CLEAN |
| 2 | — | [MEM-SAFE-001] | swift-standards — all 17 active packages | `.strictMemorySafety()` enabled in all main packages. | CLEAN |
| 3 | MEDIUM | [MEM-SAFE-001] | swift-standards `swift-html-standard/Tests/Package.swift:36` | Test sub-package missing `.strictMemorySafety()`. Main package has it. | OPEN |
| 4 | LOW | [MEM-SAFE-001] | swift-standards `swift-pdf-standard/Tests/Package.swift:49` | Test sub-package missing `.strictMemorySafety()`. | OPEN |
| 5 | LOW | [MEM-SAFE-001] | swift-standards `swift-svg-standard/Tests/Package.swift:35` | Test sub-package missing `.strictMemorySafety()`. | OPEN |
| 6 | LOW | [MEM-SAFE-001] | swift-standards `swift-rfc-template/Package.swift.template` | Template stale: lacks `.strictMemorySafety()`, still on tools-version 6.0, imports Foundation. New packages scaffolded from this will not have strict safety. | OPEN |
| 7 | MEDIUM | [MEM-SAFE-001] | swift-foundations — 13 packages | `swift-copy-on-write`, `swift-css`, `swift-css-html-rendering`, `swift-dependency-analysis`, `swift-html`, `swift-html-rendering`, `swift-markdown-html-rendering`, `swift-pdf-html-rendering`, `swift-pdf-rendering`, `swift-svg`, `swift-svg-rendering`, `swift-svg-rendering-worktree`, `swift-translating` — all missing `.strictMemorySafety()`. Entire rendering/HTML/CSS cluster. | OPEN |

### Findings — Unsafe Pointer Exposure [MEM-SAFE-023], [MEM-SAFE-012], [MEM-SAFE-014]

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 8 | HIGH | [MEM-SAFE-023] | `swift-memory-primitives/.../Memory.Arena.swift:65` | `@safe` Escapable struct exposes `public var start: UnsafeMutableRawPointer` without `@unsafe`. Arena is `~Copyable` but NOT `~Escapable` — pointer can outlive arena if extracted. Genuinely dangerous. | OPEN |
| 9 | LOW | [MEM-SAFE-023] | `swift-path-primitives/.../Path.View.swift:37` | `public let pointer: UnsafePointer<Char>` on `@safe ~Escapable` type. **Structurally safe** — type system prevents pointer from outliving source. `@unsafe` recommended for documentation but not a safety issue. | OPEN |
| 10 | LOW | [MEM-SAFE-023] | `swift-string-primitives/.../String.View.swift:35` | `public let pointer: UnsafePointer<Char>` on `@safe ~Escapable` type. Same analysis as Path.View — structurally safe. | OPEN |
| 11 | MEDIUM | [MEM-SAFE-023] | `swift-property-primitives/.../Property.View.swift:150` | `public var base: UnsafeMutablePointer<Base>` — Property.View is `~Copyable` but NOT `~Escapable` (omitted per [MEM-COPY-013] compiler bug). Safe by coroutine scope convention, not by type system. 7 variants affected. | OPEN |
| 12 | MEDIUM | [MEM-SAFE-012] | `swift-memory-primitives/.../Memory.Buffer.Base.swift:37,52` | `public var nullable/nonNull: UnsafeRawBufferPointer` on Property extensions — stdlib bridge properties without `@unsafe`. Mutable variant at `Memory.Buffer.Mutable.Base.swift` has same issue. | OPEN |
| 13 | MEDIUM | [MEM-SAFE-014] | swift-foundations `swift-memory/.../Memory.Map.swift:149,155` | `public var baseAddress: UnsafeRawPointer?` and `mutableBaseAddress: UnsafeMutableRawPointer?` — no Span normative accessor alongside these pointer properties. | OPEN |
| 14 | MEDIUM | [MEM-SAFE-012] | swift-foundations `swift-file-system/.../File.Path.Component.swift:66` | `public init(utf8 buffer: UnsafeBufferPointer<UInt8>)` — should have a `Span<UInt8>` overload as normative interface. | OPEN |

### Findings — Sendable Safety [MEM-SAFE-024], [MEM-SEND-001]

Per [MEM-SAFE-024], each `@unchecked Sendable` is classified into a semantic category:
- **Cat A**: Synchronized (mutex/atomic) — add `@unsafe` + doc
- **Cat B**: Ownership transfer (`~Copyable`) — add `@unsafe` + doc
- **Cat C**: Thread-confined — DEFER for `~Sendable` (SE-0518)

See `swift-institute/Research/tilde-sendable-semantic-inventory.md` for the full framework.

| # | Severity | Rule | Location | Finding | Cat | Status |
|---|----------|------|----------|---------|-----|--------|
| 15 | HIGH | [MEM-SAFE-024] | `swift-handle-primitives/.../Generation.Tracker.swift:205` | `@unchecked Sendable` without `@unsafe`. `~Copyable` ownership transfer pattern. Doc comment "Not thread-safe" refers to concurrent mutation, not transfer safety — but wording is misleading and should be clarified. | B | OPEN |
| 16 | HIGH | [MEM-SAFE-024] | `swift-bit-vector-primitives/.../Bit.Vector.swift:146` | `@unchecked Sendable` without `@unsafe`. `~Copyable` unique ownership makes transfer sound. Lacks safety invariant doc. | B | OPEN |
| 17 | HIGH | [MEM-SAFE-024] | `swift-memory-primitives/.../Memory.Arena.swift:125` | `@unchecked Sendable` without `@unsafe`. `~Copyable` ownership transfer. Required by `Storage.Arena`. | B | OPEN |
| 18 | HIGH | [MEM-SAFE-024] | `swift-memory-primitives/.../Memory.Pool.swift:370` | `@unchecked Sendable` without `@unsafe`. `~Copyable` ownership transfer. No current cross-layer consumers but consistent with Arena. | B | OPEN |
| 19 | MEDIUM | [MEM-SAFE-024] | `swift-predicate-primitives/.../Predicate.swift:29` | `@unchecked Sendable` on Copyable type storing `(T) -> Bool` closure. Closures are not `@Sendable` by default. Neither synchronized (A) nor `~Copyable` (B). Potentially unsound. | — | OPEN |
| 20 | MEDIUM | [MEM-SAFE-024] | `swift-lifetime-primitives/.../Lifetime.Lease.swift:74` | `@unchecked Sendable where Value: Sendable` — `~Copyable` conditional ownership transfer. Sound, lacks `@unsafe`. | B | OPEN |
| 21 | MEDIUM | [MEM-SAFE-024] | `swift-machine-primitives/.../Machine.Capture.Slot.swift:17` | `@unchecked Sendable` on outer `Slot` struct — inner `_Storage` is synchronized (atomic). | A | OPEN |
| 22 | MEDIUM | [MEM-SAFE-024] | swift-foundations `swift-async/.../Async.Filter.swift:88` | `Async.Filter: @unchecked Sendable` — stores non-`@Sendable` closures. 8 types (Filter/Map/CompactMap/FlatMap + iterators). Needs analysis: are closures captured once and confined, or potentially shared? | — | OPEN |
| 23 | LOW | [MEM-SAFE-024] | swift-foundations `swift-file-system/.../File.Directory.Contents.IteratorHandle.swift:14` | `@unchecked Sendable` wrapping thread-confined `Kernel.Directory.Stream`. Tier 1 candidate for `~Sendable` (SE-0518). | C | DEFERRED — awaiting SE-0518 (`~Sendable`) stabilization |

### Findings — `nonisolated(unsafe)` Without Safety Annotation [MEM-SAFE-025]

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 24 | MEDIUM | [MEM-SAFE-025] | `swift-memory-primitives/.../Memory.Buffer.swift:29,37` | `nonisolated(unsafe) let _emptyBufferSentinelMutable` and `_emptyBufferSentinel` — allocated-once globals safely encapsulated; should have `@safe`. Duplicate at `Memory Primitives/Memory.Buffer.swift`. | OPEN |
| 25 | MEDIUM | [MEM-SAFE-025] | `swift-memory-primitives/.../Memory.Buffer.Mutable.swift:19` | `nonisolated(unsafe) let _emptyMutableBufferSentinel` — same pattern, lacks `@safe`. Duplicate at `Memory Primitives/Memory.Buffer.Mutable.swift`. | OPEN |
| 26 | LOW | [MEM-SAFE-025] | swift-foundations `swift-css/.../Color.Theme.swift:13` + `Font.Theme.swift:13` | `nonisolated(unsafe) private static var _prepared` — mutable static with public `_prepare()` mutator. Data race possible if called concurrently. Consider `Mutex` or `Atomic`. | OPEN |

### Findings — Expression Placement [MEM-SAFE-002]

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 27 | LOW | [MEM-SAFE-002] | swift-foundations `swift-file-system/.../File.Handle.swift:104,160,190` | `guard unsafe !buffer.isEmpty` — `.isEmpty` on `UnsafeMutableRawBufferPointer` is a safe property. `unsafe` is over-specified here. Harmless but noisy. | OPEN |

### Findings — Annotation Correctness [MEM-UNSAFE-003]

No violations found. All three superrepos correctly avoid `@unsafe struct` on encapsulating types. All `@safe` annotations are on types with genuine unsafe internal storage.

One exemplary pattern worth noting: `Loader.Section.Bounds` (`swift-loader-primitives`) uses `@safe` struct with `@unsafe public nonisolated(unsafe) let` on individual escape-hatch properties — the canonical pattern per the research document.

### Summary

27 findings: 0 critical, 5 high, 14 medium, 8 low. (Revised 2026-03-25: findings #9, #10 downgraded HIGH→LOW per `~Escapable` structural safety analysis.)

**Systemic patterns**:

1. **`@unchecked Sendable` without `@unsafe`** (findings #15–23): The most widespread issue. 13 types across primitives and foundations use bare `@unchecked Sendable`. Most are sound due to `~Copyable` unique ownership, but all lack the `@unsafe` annotation required by SE-0458 and safety invariant documentation. The `Async.*` sequence cluster in swift-foundations is the largest group (8 types).

2. **Pointer property exposure without `@unsafe`** (findings #8–14): Public properties returning unsafe pointer types on `@safe` types. Severity depends on escapability of the containing type:
   - `~Escapable` types (Path.View, String.View): **structurally safe** — pointer cannot outlive source. LOW severity.
   - Coroutine-scoped types (Property.View family): safe by convention but not type system. MEDIUM severity.
   - Escapable types (Memory.Arena): **genuinely dangerous** — pointer can outlive container. HIGH severity.

3. **`.strictMemorySafety()` gaps** (finding #7): 13 swift-foundations packages in the rendering/HTML/CSS cluster lack the flag. These packages contain no unsafe code, so the risk is low, but the gap prevents compile-time enforcement.

4. **`nonisolated(unsafe)` sentinel globals** (findings #24–25): Safely encapsulated globals that should have `@safe` annotation for SE-0458 compliance.

**Positive observations**:

- swift-primitives has 100% `.strictMemorySafety()` coverage
- swift-standards has zero unsafe code — architecturally clean Layer 2
- All `@safe`/`@unsafe` type-level annotations are correct across the ecosystem
- The IO subsystem in swift-foundations has exemplary safety documentation on every `@unchecked Sendable`
- No anti-patterns from research document Section 14 detected (no wrong-side assignment, no double unsafe, no unsafe on allocate)
- `~Escapable` types (Path.View, String.View) achieve structural pointer safety through the type system — the strongest form of isolation

### Remediation Priority

```
Priority 1: Cat B — @unchecked Sendable → add @unsafe + Pattern B doc (findings #15–18, #20)
    └── 5 ~Copyable types: Bit.Vector, Generation.Tracker, Memory.Arena, Memory.Pool, Lifetime.Lease

Priority 2: Cat A — @unchecked Sendable → add @unsafe + sync doc (finding #21)
    └── Machine.Capture.Slot (synchronized via atomic)

Priority 3: Cat C — Thread-confined → adopt ~Sendable (finding #23)
    └── File.Directory.Contents.IteratorHandle → ~Sendable (SE-0518)

Priority 4: Memory.Arena.start → add @unsafe (finding #8)
    └── Only HIGH pointer exposure finding after ~Escapable reassessment

Priority 5: Property.View family → add @unsafe to base properties (finding #11)
    └── 7 variants, MEDIUM (coroutine-scoped but not ~Escapable)

Priority 6: Sentinel globals → add @safe (findings #24–25)
    └── 4 globals in swift-memory-primitives

Priority 7: .strictMemorySafety() gaps (finding #7)
    └── 13 swift-foundations rendering packages

Priority 8: Needs analysis (findings #19, #22)
    └── Predicate closure soundness, Async.* category determination

Priority 9: Documentation improvements (findings #9, #10, #12–14, #26, #27)
    └── @unsafe on ~Escapable pointer properties (optional), CSS theming, over-specified unsafe
```
