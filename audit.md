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

### Execution Priority

```
Priority 1: Phase 1 — Finite.Capacity (finding #1)
    └── 2 conformers, smallest blast radius, validates protocol-level pattern
    └── Unblocks Phase 2

Priority 2: Phase 2 — Finite.Enumerable (finding #2)
    └── 16 conformers across 5 packages — keystone change
    └── Unlocks consumer improvements (tier 4→2)
    └── Unblocks Phases 3–6

Priority 3: Phase 3 — Sequence iterator internals (findings #7, #8)
    └── Mechanical, all @usableFromInline, no public API, no design decisions
    └── Independent of Phases 1–2 but benefits from validated pattern

Priority 4: Phase 5 — Sequence.Difference.Hunk (finding #6)
    └── Public API — last HIGH finding after Phases 1–2
    └── BLOCKED on design decision: phantom tag for old/new line positions

Priority 5: Phase 6 — Cyclic groups + parser (findings #10, #11)
    └── BLOCKED on design decision: cyclic group domain tagging strategy
    └── Parser.Machine.Memoization.Key is independent and trivial

Priority 6: Phase 4 — Sequence.Iterator.Protocol (finding #3)
    └── Currently DEFERRED — revisit after Phases 1–3 establish pattern
```

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
| 23 | MEDIUM | [MEM-SAFE-024] | swift-foundations `swift-file-system/.../File.Directory.Contents.IteratorHandle.swift:14` | `@unchecked Sendable` wrapping thread-confined `Kernel.Directory.Stream`. Tier 1 in `~Sendable` inventory. Replace `@unchecked Sendable` with `~Sendable`. | C | OPEN |

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

Priority 3: Cat C — Thread-confined → replace @unchecked Sendable with ~Sendable (finding #23)
    └── File.Directory.Contents.IteratorHandle → ~Sendable
    └── Also: IO.Completion.IOUring.Ring, IO.Completion.IOCP.State (Tier 1 per ~Sendable inventory)

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

### Remediation Plan — Concrete Code Changes

Each fix maps to a finding above. Grouped by category with exact file, current code, and target change.

**Canonical references**:
- `swift-institute/Research/swift-safety-model-reference.md` — safety model semantics
- `swift-institute/Research/tilde-sendable-semantic-inventory.md` — Sendable category framework
- `memory-safety` skill — [MEM-SAFE-020–025], [MEM-SEND-001–003]

#### P1: Category B — `@unsafe @unchecked Sendable` + Pattern B doc (findings #15–18, #20)

**Pattern B safety invariant** (use verbatim for all 5 types):
```
/// @unchecked Sendable: Category B (ownership transfer).
/// ~Copyable unique ownership ensures only one thread can own the value
/// at a time. Transfer via `consuming` relinquishes the sender's access.
```

| # | File | Current | Target |
|---|------|---------|--------|
| F15 | `swift-handle-primitives/.../Generation.Tracker.swift:205` | `extension Generation.Tracker: @unchecked Sendable {}` | `extension Generation.Tracker: @unsafe @unchecked Sendable {}` + Pattern B doc. Also fix doc at line 40: "Not thread-safe. External synchronization required" → "Not concurrently mutable. Ownership transfer is safe via ~Copyable." |
| F16 | `swift-bit-vector-primitives/.../Bit.Vector.swift:146` | `extension Bit.Vector: @unchecked Sendable {}` | `extension Bit.Vector: @unsafe @unchecked Sendable {}` + Pattern B doc |
| F17 | `swift-memory-primitives/.../Memory.Arena.swift:125` | `extension Memory.Arena: @unchecked Sendable {}` | `extension Memory.Arena: @unsafe @unchecked Sendable {}` + Pattern B doc |
| F18 | `swift-memory-primitives/.../Memory.Pool.swift:370` | `extension Memory.Pool: @unchecked Sendable {}` | `extension Memory.Pool: @unsafe @unchecked Sendable {}` + Pattern B doc |
| F20 | `swift-lifetime-primitives/.../Lifetime.Lease.swift:74` | `extension Lifetime.Lease: @unchecked Sendable where Value: Sendable {}` | `extension Lifetime.Lease: @unsafe @unchecked Sendable where Value: Sendable {}` + Pattern B doc |

**Design rationale**: Cannot be made checked `Sendable` — `UnsafeMutablePointer` storage prevents it. `~Copyable` unique ownership provides the proof the compiler cannot verify. Type system gap, not a design problem.

#### P2: Category A — `@unsafe @unchecked Sendable` + sync doc (finding #21)

| # | File | Current | Target |
|---|------|---------|--------|
| F21 | `swift-machine-primitives/.../Machine.Capture.Slot.swift:17` | `public struct Slot: @unchecked Sendable {` | `public struct Slot: @unsafe @unchecked Sendable {` + doc: "Category A (synchronized). Inner `_Storage` uses atomic operations for thread-safe slot management." |

#### P3: Category C — Replace `@unchecked Sendable` with `~Sendable` (finding #23 + Tier 1 inventory)

Enable via `.enableExperimentalFeature("TildeSendable")` in Package.swift.

| # | File | Current | Target |
|---|------|---------|--------|
| F23 | `swift-file-system/.../File.Directory.Contents.IteratorHandle.swift:14` | `final class IteratorHandle: @unchecked Sendable` | `final class IteratorHandle: ~Sendable` — thread-confined directory stream. Transfer site uses explicit `unsafe`. |
| T1a | `swift-io/.../IO.Completion.IOUring.Ring` | `@unchecked Sendable` | `~Sendable` — confined to poll thread. Tier 1 per inventory. |
| T1b | `swift-io/.../IO.Completion.IOCP.State` | `@unchecked Sendable` | `~Sendable` — confined to completion port thread. Tier 1 per inventory. |

**Design rationale**: These types are NOT safe to send arbitrarily. `@unchecked Sendable` is a semantic lie. `~Sendable` expresses the truth: the type is non-Sendable, and the single transfer to the confined thread is an explicit unsafe boundary crossing.

#### P4: Pointer exposure — add `@unsafe` (finding #8)

| # | File | Current | Target |
|---|------|---------|--------|
| F8 | `swift-memory-primitives/.../Memory.Arena.swift:65` | `public var start: UnsafeMutableRawPointer { unsafe _storage }` | `@unsafe public var start: UnsafeMutableRawPointer { unsafe _storage }` |

**Design rationale**: Arena is `~Copyable` but NOT `~Escapable`. Pointer can outlive arena. Cannot eliminate — `Storage.Arena` requires mutable typed pointer computation. `@unsafe` is the correct end state.

#### P5: Property.View family — add `@unsafe` to base properties (finding #11)

7 variants, same pattern:

| # | File |
|---|------|
| F11a | `swift-property-primitives/.../Property.View.swift` |
| F11b | `swift-property-primitives/.../Property.View.Typed.swift` |
| F11c | `swift-property-primitives/.../Property.View.Read.swift` |
| F11d | `swift-property-primitives/.../Property.View.Read.Typed.swift` |
| F11e | `swift-property-primitives/.../Property.View.Typed.Valued.swift` |
| F11f | `swift-property-primitives/.../Property.View.Read.Typed.Valued.swift` |
| F11g | `swift-property-primitives/.../Property.View.Typed.Valued.Valued.swift` |

**Target**: Add `@unsafe` to each `public var base: UnsafeMutablePointer<Base>` property.

**Design rationale**: `~Copyable` but NOT `~Escapable` (omitted per [MEM-COPY-013]). Safe by coroutine scope, not type system. When the compiler bug is fixed and `~Escapable` is added, these downgrade to LOW.

#### P6: Sentinel globals — add `@safe` (findings #24–25)

| # | File | Global |
|---|------|--------|
| F24a | `swift-memory-primitives/.../Memory Buffer Primitives/Memory.Buffer.swift:29` | `_emptyBufferSentinelMutable` |
| F24b | `swift-memory-primitives/.../Memory Buffer Primitives/Memory.Buffer.swift:37` | `_emptyBufferSentinel` |
| F25 | `swift-memory-primitives/.../Memory Buffer Primitives/Memory.Buffer.Mutable.swift:19` | `_emptyMutableBufferSentinel` |
| F24a' | `swift-memory-primitives/.../Memory Primitives/Memory.Buffer.swift:29` | duplicate of F24a |
| F24b' | `swift-memory-primitives/.../Memory Primitives/Memory.Buffer.swift:37` | duplicate of F24b |
| F25' | `swift-memory-primitives/.../Memory Primitives/Memory.Buffer.Mutable.swift:19` | duplicate of F25 |

**Target**: Add `@safe` to each `nonisolated(unsafe) let` declaration.

**Design rationale**: Cannot eliminate `nonisolated(unsafe)` — Swift 6 requires it for lazy-initialized globals. Sentinels are `let`, allocated once, address-only comparisons. `@safe` asserts the invariant.

#### P7: `.strictMemorySafety()` gaps (finding #7)

Add `.strictMemorySafety()` to `swiftSettings` for 13 swift-foundations packages:

```
swift-copy-on-write          swift-html-rendering
swift-css                    swift-markdown-html-rendering
swift-css-html-rendering     swift-pdf-html-rendering
swift-dependency-analysis    swift-pdf-rendering
swift-html                   swift-svg
swift-svg-rendering          swift-svg-rendering-worktree
swift-translating
```

Plus 3 swift-standards test sub-packages and the stale `swift-rfc-template/Package.swift.template`.

#### P8: Needs analysis before fixing

| # | Type | Question | Options |
|---|------|----------|---------|
| F19 | `Predicate<T>: @unchecked Sendable` | Copyable type stores `(T) -> Bool` — not `@Sendable`. Neither synchronized (A) nor `~Copyable` (B). | (a) Make closure `@Sendable` in API, (b) Remove `Sendable` conformance, (c) Determine if type should be `~Copyable` |
| F22 | `Async.Filter/Map/CompactMap/FlatMap` (8 types) | Store non-`@Sendable` closures with `@unchecked Sendable`. | (a) Make closures `@Sendable`, (b) Category C → `~Sendable`, (c) Accept as Category A if async runtime provides confinement |

#### P9: Documentation improvements (LOW — optional)

| # | File | Change |
|---|------|--------|
| F9 | `swift-path-primitives/.../Path.View.swift:37` | Optionally add `@unsafe` to `pointer` (structurally safe via `~Escapable`) |
| F10 | `swift-string-primitives/.../String.View.swift:35` | Same as F9 |
| F12–14 | Various | Minor: `Memory.Buffer` properties, `File.Path.Component` init, `Memory.Map` addresses |
| F26 | `swift-css/.../Color.Theme.swift:13`, `Font.Theme.swift:13` | Mutable static with data race risk. Consider `Mutex` or `Atomic`. |
| F27 | `swift-file-system/.../File.Handle.swift:104,160,190` | Remove over-specified `unsafe` on `.isEmpty` |

## Variant Naming — 2026-03-25

### Scope

- **Target**: swift-primitives ecosystem (6 packages) + swift-foundations (2 source files)
- **Skill**: code-surface — [API-NAME-001], [API-NAME-003]; academic definitions from `variant-naming-audit.md`
- **Files**: ~50 source files, ~10 test files across 6 packages + 2 downstream files
- **Subject**: 7 types named "Fixed" with bounded-buffer semantics; 2 types named "Inline" at collection level where convention is "Static"

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [API-NAME-003] | swift-queue-primitives: `Queue.Fixed` | Bounded-buffer semantics (mutable count, capacity-limited) named "Fixed" instead of "Bounded" (Dijkstra 1965). `struct Fixed` declared in Queue.Fixed.swift:43. | OPEN |
| 2 | HIGH | [API-NAME-003] | swift-queue-primitives: `Queue.DoubleEnded.Fixed` | Same as #1. Declared in Queue.DoubleEnded.swift:47. | OPEN |
| 3 | HIGH | [API-NAME-003] | swift-queue-primitives: `Queue.Linked.Fixed` | Same as #1. Declared in Queue.Linked.swift:87. | OPEN |
| 4 | HIGH | [API-NAME-003] | swift-heap-primitives: `Heap.Fixed` | Same as #1. Declared in Heap.swift:103. `comparative-heap-primitives.md` line 154 already calls it "bounded capacity" in prose. | OPEN |
| 5 | HIGH | [API-NAME-003] | swift-heap-primitives: `Heap.MinMax.Fixed` | Same as #1. Declared in Heap.MinMax.Fixed.swift. | OPEN |
| 6 | HIGH | [API-NAME-003] | swift-set-primitives: `Set.Ordered.Fixed` | Same as #1. Declared in Set.swift:73. | OPEN |
| 7 | HIGH | [API-NAME-003] | swift-bitset-primitives: `Bitset.Fixed` | Same as #1. Declared in Bitset.Fixed.swift. | OPEN |
| 8 | MEDIUM | convention | swift-list-primitives: `List.Linked.Inline<N>` | Collection-level variant uses "Inline" (infrastructure name) instead of "Static" (collection convention). Declared in List.Linked.swift:146. | OPEN |
| 9 | MEDIUM | convention | swift-tree-primitives: `Tree.N.Inline<N>` | Same as #8. Declared in Tree.N.Inline.swift:37. | OPEN |

### Execution Plan

Each rename touches 5 layers: struct declarations, all type references, module/target names, file names, directory names. The replacement is mechanical and per-package safe (no "Fixed" variant in any affected package should remain "Fixed"). Full academic rationale in `variant-naming-audit.md`.

#### Reference Patterns (all must be caught)

| Pattern | Example | Replacement |
|---------|---------|-------------|
| `.Fixed` (type position) | `extension Queue.Fixed where...` | `.Bounded` |
| `struct Fixed` | `public struct Fixed: ~Copyable` | `struct Bounded` |
| `Queue<Element>.Fixed` | `throws(Queue<Element>.Fixed.Error)` | `Queue<Element>.Bounded` |
| `Queue<Int>.Fixed` | `Queue<Int>.Fixed(capacity: 10)` | `Queue<Int>.Bounded` |
| `Queue<ConcreteType>.*.Fixed` | `Queue<IO...>.DoubleEnded.Fixed(...)` | `...DoubleEnded.Bounded(...)` |
| `__*FixedError` | `__QueueDoubleEndedFixedError` | `__QueueDoubleEndedBoundedError` |
| `__*FixedError` | `__SetOrderedFixedError` | `__SetOrderedBoundedError` |
| `__*FixedError` | `__BitsetFixedError` | `__BitsetBoundedError` |
| `*FixedTests` | `QueueFixedTests` | `QueueBoundedTests` |
| `*_Fixed_Primitives` | `Queue_Fixed_Primitives` | `Queue_Bounded_Primitives` |
| `"* Fixed Primitives"` | `"Queue Fixed Primitives"` | `"Queue Bounded Primitives"` |
| `Queue/Fixed` (DocC) | DocC link syntax | `Queue/Bounded` |
| `"Queue.Fixed"` (strings) | test suite name | `"Queue.Bounded"` |
| File names | `Queue.Fixed.swift` | `Queue.Bounded.swift` |
| Directory names | `Queue Fixed Primitives/` | `Queue Bounded Primitives/` |
| `List.Linked.Inline` | `extension List.Linked.Inline where...` | `List.Linked.Static` |
| `Tree.N.Inline` | `extension Tree.N.Inline where...` | `Tree.N.Static` |
| `struct Inline<let capacity` | collection-level declaration | `struct Static<let capacity` |
| `__ListLinkedInlineError` | hoisted error | `__ListLinkedStaticError` |
| `__TreeNInlineError` | hoisted error | `__TreeNStaticError` |
| `Tree_N_Inline_Primitives` | module import | `Tree_N_Static_Primitives` |
| `Tree N Inline Primitives` | target name | `Tree N Static Primitives` |

#### Per-Package Content Replacement (sed)

**swift-queue-primitives** (3 Fixed types, 1 hoisted error, 1 module/target):

```bash
PKG="swift-queue-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/__QueueDoubleEndedFixedError/__QueueDoubleEndedBoundedError/g' \
  -e 's/QueueFixedTests/QueueBoundedTests/g' \
  -e 's/Queue_Fixed_Primitives/Queue_Bounded_Primitives/g' \
  -e 's/Queue Fixed Primitives/Queue Bounded Primitives/g'
```

**swift-heap-primitives** (2 Fixed types, 1 module/target):

```bash
PKG="swift-heap-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/Heap_Fixed_Primitives/Heap_Bounded_Primitives/g' \
  -e 's/Heap Fixed Primitives/Heap Bounded Primitives/g'
```

**swift-set-primitives** (1 Fixed type, 1 hoisted error, no separate module):

```bash
PKG="swift-set-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/__SetOrderedFixedError/__SetOrderedBoundedError/g'
```

**swift-bitset-primitives** (1 Fixed type, 1 hoisted error, no separate module):

```bash
PKG="swift-bitset-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/__BitsetFixedError/__BitsetBoundedError/g'
```

**swift-list-primitives** (1 Inline→Static, 1 hoisted error):

```bash
PKG="swift-list-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/List\.Linked\.Inline/List.Linked.Static/g' \
  -e 's/__ListLinkedInlineError/__ListLinkedStaticError/g'
# Declaration rename (only in the one file):
sed -i '' 's/public struct Inline<let capacity/public struct Static<let capacity/g' \
  "$PKG/Sources/List Primitives Core/List.Linked.swift"
```

**swift-tree-primitives** (1 Inline→Static, 1 hoisted error, 1 module/target):

```bash
PKG="swift-tree-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/Tree\.N\.Inline/Tree.N.Static/g' \
  -e 's/__TreeNInlineError/__TreeNStaticError/g' \
  -e 's/Tree_N_Inline_Primitives/Tree_N_Static_Primitives/g' \
  -e 's/Tree N Inline Primitives/Tree N Static Primitives/g'
# Declaration rename:
sed -i '' 's/public struct Inline<let capacity/public struct Static<let capacity/g' \
  "$PKG/Sources/Tree N Inline Primitives/Tree.N.Inline.swift"
```

**swift-foundations** (downstream, 3 references):

```bash
sed -i '' 's/\.Fixed/.Bounded/g' \
  "swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Worker.swift" \
  "swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Runtime.State.swift"
sed -i '' 's/Queue\.Fixed/Queue.Bounded/g; s/Heap\.Fixed/Heap.Bounded/g; s/DoubleEnded\.Fixed/DoubleEnded.Bounded/g' \
  "swift-io/Research/data-structure-ecosystem-triage.md"
```

#### File and Directory Renames (git mv)

**swift-queue-primitives:**

```bash
cd swift-queue-primitives
git mv "Sources/Queue Fixed Primitives" "Sources/Queue Bounded Primitives"
git mv "Sources/Queue Primitives Core/Queue.Fixed.swift" "Sources/Queue Primitives Core/Queue.Bounded.swift"
git mv "Sources/Queue Bounded Primitives/Queue.Fixed Copyable.swift" "Sources/Queue Bounded Primitives/Queue.Bounded Copyable.swift"
```

**swift-heap-primitives:**

```bash
cd swift-heap-primitives
git mv "Sources/Heap Fixed Primitives" "Sources/Heap Bounded Primitives"
git mv "Sources/Heap Primitives Core/Heap.Fixed.Error.swift" "Sources/Heap Primitives Core/Heap.Bounded.Error.swift"
git mv "Sources/Heap Bounded Primitives/Heap.Fixed ~Copyable.swift" "Sources/Heap Bounded Primitives/Heap.Bounded ~Copyable.swift"
git mv "Sources/Heap Bounded Primitives/Heap.Fixed Copyable.swift" "Sources/Heap Bounded Primitives/Heap.Bounded Copyable.swift"
git mv "Sources/Heap MinMax Primitives/Heap.MinMax.Fixed.swift" "Sources/Heap MinMax Primitives/Heap.MinMax.Bounded.swift"
git mv "Sources/Heap MinMax Primitives/Heap.MinMax.Fixed ~Copyable.swift" "Sources/Heap MinMax Primitives/Heap.MinMax.Bounded ~Copyable.swift"
git mv "Sources/Heap MinMax Primitives/Heap.MinMax.Fixed Copyable.swift" "Sources/Heap MinMax Primitives/Heap.MinMax.Bounded Copyable.swift"
git mv "Tests/Heap Primitives Tests/Heap.Fixed Tests.swift" "Tests/Heap Primitives Tests/Heap.Bounded Tests.swift"
```

**swift-set-primitives:**

```bash
cd swift-set-primitives
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed Copyable.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded Copyable.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed.Indexed.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded.Indexed.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Consume.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded+Sequence.Consume.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Drain.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded+Sequence.Drain.swift"
```

**swift-bitset-primitives:**

```bash
cd swift-bitset-primitives
git mv "Sources/Bitset Primitives/Bitset.Fixed.swift" "Sources/Bitset Primitives/Bitset.Bounded.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Error.swift" "Sources/Bitset Primitives/Bitset.Bounded.Error.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Algebra.swift" "Sources/Bitset Primitives/Bitset.Bounded.Algebra.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Algebra.Symmetric.swift" "Sources/Bitset Primitives/Bitset.Bounded.Algebra.Symmetric.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Relation.swift" "Sources/Bitset Primitives/Bitset.Bounded.Relation.swift"
```

**swift-list-primitives:**

```bash
cd swift-list-primitives
git mv "Sources/List Linked Primitives/List.Linked.Inline.swift" "Sources/List Linked Primitives/List.Linked.Static.swift"
```

**swift-tree-primitives:**

```bash
cd swift-tree-primitives
git mv "Sources/Tree N Inline Primitives" "Sources/Tree N Static Primitives"
git mv "Sources/Tree N Static Primitives/Tree.N.Inline.swift" "Sources/Tree N Static Primitives/Tree.N.Static.swift"
git mv "Sources/Tree N Static Primitives/Tree.N.Inline.Error.swift" "Sources/Tree N Static Primitives/Tree.N.Static.Error.swift"
```

#### Verification

```bash
# Per package:
cd {package} && swift build && swift test

# Downstream:
cd swift-foundations && swift build
```

#### Safety Constraints

1. **Never touch swift-array-primitives**: `Array.Fixed` is genuinely fixed (immutable count).
2. **Inline→Static must not touch buffer/storage layer**: `Buffer.Linked.Inline`, `Buffer.Arena.Inline`, `Storage.Inline` are correct. The sed patterns `List.Linked.Inline` and `Tree.N.Inline` are specific enough.
3. **`.Fixed` sed catches all nested Fixed types**: `Queue.Fixed`, `DoubleEnded.Fixed`, `Linked.Fixed`, `MinMax.Fixed` — all correct.
4. **Hoisted error renames are substring-safe**: `.FixedError` → `.BoundedError` via the `.Fixed` rule works correctly.
5. **`struct Inline<let capacity` in List/Tree**: Scoped to specific files to avoid touching buffer-layer declarations.
6. **Exclude `.build/` directories**: The `find` commands exclude build artifacts.

### Summary

9 findings: 0 critical, 7 high, 2 medium.

All 9 are naming violations where the code uses an academically incorrect term. The execution plan is fully mechanical: content sed, git mv, swift build/test verification. Cross-package impact is contained to 2 source files + 1 research doc in swift-foundations. Research document at `variant-naming-audit.md` provides the full academic rationale, cross-document contradiction analysis, and corrected variant system definition.

## ASCII Serialization Migration — 2026-03-25

### Scope

- **Target**: swift-ascii (L3) + 73 conformers across `swift-ietf/` and `swift-whatwg/`
- **Research**: [ascii-serialization-migration.md](ascii-serialization-migration.md) (v2.0.0, IN_PROGRESS)
- **Trigger**: 22 deprecation warnings in `swift-ascii` from `Binary.ASCII.Serializable`

### Phase Status

| Phase | Description | Types | Status |
|-------|-------------|-------|--------|
| 0 | Infrastructure (Parseable, Serializable, Codable, parsers, serializers) | — | **MOSTLY DONE** — 3 convenience extensions remain |
| 1 | Primitive integer types (Int, UInt, Int64, UInt64, etc.) | 4 | **L1 DONE** — L3 cleanup TODO |
| 2 | Simple formats (IPv4, IPv6, DNS) | 7 | TODO |
| 3 | URI (RFC 3986) | 9 | TODO |
| 4 | Date/Time (RFC 3339) | 2 | TODO |
| 5 | Email (RFC 2822, 5322, 5321, 6531, 6068) | 26 | TODO |
| 6 | MIME (RFC 2045, 2046, 2183, 2369, 2387) | 16 | TODO |
| 7 | Remaining (RFC 3987, 7519, 7617, 9557, WHATWG URL/Form) | 13 | TODO |
| 8 | Cleanup (delete protocol, Wrapper, RawRepresentable) | — | Blocked on Phases 2-7 |

### Findings

| # | Severity | Source | Location | Finding | Status |
|---|----------|--------|----------|---------|--------|
| 1 | MEDIUM | Phase 0 gap | swift-parser-primitives or swift-ascii | `Parseable.init(_: StringProtocol)` convenience missing — types cannot parse from strings via canonical protocol | OPEN |
| 2 | MEDIUM | Phase 0 gap | swift-serializer-primitives or swift-ascii | `Serializable` → String conversion missing — no `String.init` or `.asciiString` on Serializable | OPEN |
| 3 | MEDIUM | Phase 0 gap | swift-binary-primitives or swift-ascii | `Serializable` → `Binary.Serializable` bridge missing — types lose `.bytes` and `String(value)` | OPEN |
| 4 | HIGH | Phase 1 cleanup | `swift-ascii/.../Int+ASCII.Serializable.swift:103-183` | 4 redundant `Binary.ASCII.Serializable` conformances for Int/Int64/UInt/UInt64 — superseded by L1 `Parseable` + `Serializable` | OPEN |
| 5 | MEDIUM | Deprecation cascade | `swift-ascii/.../Binary.ASCII.Serializable.swift` (14 sites) | Extensions on deprecated protocol produce 14 warnings — required by 73 external conformers until Phases 2-7 complete | OPEN |
| 6 | MEDIUM | Deprecation cascade | `swift-ascii/.../Binary.ASCII.Wrapper.swift` (2 sites) | Wrapper struct and `.ascii` accessor reference deprecated protocol — 2 warnings | OPEN |
| 7 | MEDIUM | Deprecation cascade | `swift-ascii/.../Binary.ASCII.RawRepresentable.swift` (1 site) | Sub-protocol inherits from deprecated protocol — 1 warning | OPEN |
| 8 | MEDIUM | Deprecation cascade | `swift-ascii/.../StringProtocol+INCITS_4_1986.swift:221` | `init<T: Binary.ASCII.Serializable>` references deprecated protocol — 1 warning | OPEN |

### Next Actions

1. **Phase 1 cleanup** — Delete 4 integer `Binary.ASCII.Serializable` conformances (finding #4). Verify `Binary.ASCII.Decimal` namespace has no remaining consumers, or keep if needed. Eliminates 4 of 22 warnings.
2. **Deprecation cascade** — Add `@available(*, deprecated)` to findings #5-#8 (18 sites). This is the correct Swift pattern for protocol infrastructure that must stay for external conformers. Eliminates remaining 18 warnings.
3. **Phase 0 gaps** — Build findings #1-#3 (convenience extensions) to unblock Phase 2+ migration.
4. **Phases 2-7** — Migrate 73 conformers per [ascii-serialization-migration.md](ascii-serialization-migration.md) per-type checklist.

### Summary

8 findings: 0 critical, 1 high, 7 medium.

77 types across the ecosystem conform to the deprecated `Binary.ASCII.Serializable` protocol. The replacement infrastructure (`Parseable`, `Serializable`, `Serializer.Protocol`) is operational at L1. Phase 1 (integers) is done at L1 but the redundant L3 conformances remain. 22 deprecation warnings in swift-ascii: 4 from redundant conformances (deletable), 18 from protocol infrastructure (deprecation cascade). Three Phase 0 convenience extensions needed before Phases 2-7 can proceed at scale.

## Path Type Compliance — 2026-03-31

### Scope

- **Target**: swift-primitives, swift-standards (swift-iso-9945), swift-foundations (ecosystem-wide)
- **Principle**: [string-path-type-inventory-file-system.md](string-path-type-inventory-file-system.md) v3.0 — "APIs that semantically operate on file system paths should accept/return path types. `Swift.String` should appear only at display boundaries and at explicit conversion points."
- **Files**: Sources/ and Tests/ across three superrepos
- **Subject**: `Swift.String` used where `Kernel.Path`, `Path_Primitives.Path`, `Paths.Path`, or `Path.View` is semantically correct

### Type Hierarchy Reference

```
Layer 1 (Primitives)
  Path_Primitives.Path          (~Copyable, platform-encoded, owns memory)
  Path_Primitives.Path.View     (~Copyable, ~Escapable, borrowed view)
  Kernel.Path = Tagged<Kernel, Path_Primitives.Path>
  Kernel.Path.View              (non-escapable borrowed view)

Layer 3 (Foundations)
  Paths.Path                    (Copyable, Sendable, validated, user-facing)
  Paths.Path.View               (~Copyable, ~Escapable, borrowed)
  Paths.Path.Component          (validated single component)
  File.Path = Paths.Path        (typealias in swift-file-system)
```

**Conversion boundary**: `Kernel.Path.scope(_:)` bridges `Swift.String` → scoped `Kernel.Path.View` for syscall use. Code that calls `.scope()` internally is evidence that the parameter should have been typed at the API boundary instead.

### Per-Package Triage

| Superrepo | Package | Source Findings | Test Findings | Worst Severity | Notes |
|-----------|---------|-----------------|---------------|---------------|-------|
| swift-primitives | swift-windows-primitives | 2 | 0 | HIGH | `Windows.Loader.Library.open(path: String)` |
| swift-standards | swift-iso-9945 | 0 | 15 | HIGH | All test helpers: `KernelIOTest.*`, test-local `cleanup`, `makeTempPath` |
| swift-foundations | swift-kernel | 14 | 8 | HIGH | `Kernel.File.Write+Shared` internals, `Atomic.Error` cases, test helpers |
| swift-foundations | swift-posix | 6 | 4 | HIGH | POSIX Glob public API: `match(in: String)`, `body: (String) -> Void` |
| swift-foundations | swift-windows | 5 | 3 | HIGH | Windows Glob public API (mirrors POSIX) |
| swift-foundations | swift-tests | 4 | 0 | MEDIUM | `Test.Reporter.json(to:)`, `.structured(to:)` public APIs |
| swift-foundations | swift-source | 4 | 0 | MEDIUM | `Source.Cache` keyed by `[String: [UInt8]]` |
| swift-foundations | swift-file-system | 0 | 8 | MEDIUM | `File.Directory.Temporary`, `File.System Tests` helpers |
| **Total** | | **35** | **38** | | **73 findings** |

### Findings — Sources: Public API (Layer Boundary Violations)

These are public APIs that accept or return `Swift.String` where consumers must pass file system paths. Highest priority — these define the contract.

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 1 | HIGH | `swift-windows-primitives/.../Windows.Loader.Library.swift:39` | `open(path: String)` — DLL path as bare String. `Windows.Kernel.File.Open` already uses `borrowing Kernel.Path`. | OPEN |
| 2 | HIGH | `swift-windows-primitives/.../Windows.Loader.Library.swift:59` | `open(path: String, flags: DWORD)` — same, with flags variant. | OPEN |
| 3 | HIGH | `swift-posix/.../POSIX.Kernel.Glob.Match.swift:38` | `match(pattern:in directory: Swift.String, ...)` — directory parameter is a file system path. | OPEN |
| 4 | HIGH | `swift-posix/.../POSIX.Kernel.Glob.Match.swift:40` | `body: (Swift.String) -> Void` — yields matched file paths as String. | OPEN |
| 5 | HIGH | `swift-posix/.../POSIX.Kernel.Glob.Match.swift:82` | `match(include:excluding:in directory: Swift.String, ...)` — multi-pattern variant, same issue. | OPEN |
| 6 | HIGH | `swift-posix/.../POSIX.Kernel.Glob.Match.swift:84` | `body: (Swift.String) -> Void` — multi-pattern yields. | OPEN |
| 7 | HIGH | `swift-windows/.../Windows.Kernel.Glob.Match.swift:33` | Windows Glob `match(in directory: Swift.String)` — mirrors POSIX. | OPEN |
| 8 | HIGH | `swift-windows/.../Windows.Kernel.Glob.Match.swift:35` | Windows Glob return type `-> [Swift.String]`. | OPEN |
| 9 | MEDIUM | `swift-tests/.../Test.Reporter.JSON.swift:28` | `json(to path: Swift.String?)` — output file path as optional String. Should accept `File.Path?`. | OPEN |
| 10 | MEDIUM | `swift-tests/.../Test.Reporter.Structured.swift:21` | `structured(to path: Swift.String)` — output file path as String. Should accept `File.Path`. | OPEN |
| 11 | MEDIUM | `swift-source/.../Source.Cache.swift:36` | `_loaded: [Swift.String: [UInt8]]` — dictionary keyed by String file paths. Should be `[File.Path: [UInt8]]` or typed equivalent. | OPEN |
| 12 | MEDIUM | `swift-source/.../Source.Cache.swift:54` | `load(contentsOf path: Swift.String)` — file path parameter. | OPEN |
| 13 | MEDIUM | `swift-source/.../Source.Cache.swift:72` | `contains(path: Swift.String)` — file path parameter. | OPEN |
| 14 | MEDIUM | `swift-source/.../Source.Cache.swift:81` | `remove(path: Swift.String)` — file path parameter. | OPEN |

### Findings — Sources: Internal Implementation

These are `internal` functions inside `Kernel.File.Write` that operate on String paths. They use `Kernel.Path.scope()` at the syscall boundary, meaning the entire path-manipulation pipeline above that call is untyped.

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 15 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:17-19` | `resolvePaths(_ pathString: String) -> (resolved: String, parent: String)` — path resolution returning String tuple. | OPEN |
| 16 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:31` | `normalizeWindowsPath(_ path: String) -> String` — Windows path normalization on bare String. | OPEN |
| 17 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:47-49` | `windowsParentDirectory(of path: String) -> String` — parent extraction on String. | OPEN |
| 18 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:63` | `fileName(of path: String) -> String` — Windows filename extraction. | OPEN |
| 19 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:70-72` | `posixParentDirectory(of path: String) -> String` — POSIX parent extraction. | OPEN |
| 20 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:82` | `fileName(of path: String) -> String` — POSIX filename extraction. | OPEN |
| 21 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:94` | `fileExists(_ pathString: String) -> Bool` — wraps `.scope()` internally. | OPEN |
| 22 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:307-309` | `atomicRename(from source: String, to dest: String)` — wraps `.scope()` internally. | OPEN |
| 23 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:338-341` | `atomicRenameNoClobber(from source: String, to dest: String)` — wraps `.scope()` internally. | OPEN |
| 24 | MEDIUM | `swift-kernel/.../Kernel.File.Write+Shared.swift:371-373` | `syncDirectory(_ pathString: String)` — wraps `.scope()` internally. | OPEN |

### Findings — Sources: Error Types (Diagnostic Strings)

Error enum cases that store file paths as `Swift.String` for diagnostic/display purposes. These are borderline — the prior research ([string-path-type-inventory-file-system.md](string-path-type-inventory-file-system.md) Category E) identified 28 such cases and classified them as display-correct. However, the `Kernel.File.Write.Atomic.Error` cases propagate path values from the same internal String-pipeline (findings #15–24), meaning the String enters the error from an already-untyped source.

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 25 | LOW | `swift-kernel/.../Kernel.File.Write.Atomic.Error.swift:18` | `parentVerificationFailed(path: String, ...)` | DEFERRED — diagnostic display; resolve when internal pipeline is typed |
| 26 | LOW | `swift-kernel/.../Kernel.File.Write.Atomic.Error.swift:21` | `destinationStatFailed(path: String, ...)` | DEFERRED — same rationale |
| 27 | LOW | `swift-kernel/.../Kernel.File.Write.Atomic.Error.swift:24` | `tempFileCreationFailed(directory: String, ...)` | DEFERRED — same rationale |
| 28 | LOW | `swift-kernel/.../Kernel.File.Write.Atomic.Error.swift:42` | `renameFailed(from: String, to: String, ...)` | DEFERRED — same rationale |
| 29 | LOW | `swift-kernel/.../Kernel.File.Write.Atomic.Error.swift:45` | `destinationExists(path: String)` | DEFERRED — same rationale |
| 30 | LOW | `swift-kernel/.../Kernel.File.Write.Atomic.Error.swift:48` | `directorySyncFailed(path: String, ...)` | DEFERRED — same rationale |
| 31 | LOW | `swift-kernel/.../Kernel.File.Write.Atomic.Error.swift:55` | `directorySyncFailedAfterCommit(path: String, ...)` | DEFERRED — same rationale |

### Findings — Tests: swift-iso-9945 (Layer 2)

All test support code in the standards layer. These helpers wrap `Kernel.Path.scope()` internally — the `Swift.String` parameter forces every call site to traffic in bare strings. Layer 2 can use `Kernel.Path` (L1) but NOT `Paths.Path` (L3).

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 32 | HIGH | `swift-iso-9945/Tests/Support/Kernel.IO.Test.Helpers.swift:31` | `makeTempPath(prefix:) -> Swift.String` — returns temp path as String. | OPEN |
| 33 | HIGH | `swift-iso-9945/Tests/Support/Kernel.IO.Test.Helpers.swift:36` | `open(at path: Swift.String)` — wraps `.scope()` internally. | OPEN |
| 34 | HIGH | `swift-iso-9945/Tests/Support/Kernel.IO.Test.Helpers.swift:56` | `cleanup(path: Swift.String)` — the user's example violation. | OPEN |
| 35 | HIGH | `swift-iso-9945/Tests/Support/Kernel.Temporary.swift:30` | `directory: Swift.String` — temp directory property. | OPEN |
| 36 | HIGH | `swift-iso-9945/Tests/Support/Kernel.Temporary.swift:51` | `filePath(prefix:) -> Swift.String` — temp file path generation. | OPEN |
| 37 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.File.Handle Tests.swift:32` | `cleanup(path: Swift.String)` — test-local duplicate. | OPEN |
| 38 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.File.Clone Tests.swift:28` | `createTempFileWithContent(prefix:content:) -> Swift.String` | OPEN |
| 39 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.File.Clone Tests.swift:38` | `readFileContent(_ path: Swift.String) -> String?` | OPEN |
| 40 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.File.Clone Tests.swift:57` | `cleanup(_ path: Swift.String)` — another test-local duplicate. | OPEN |
| 41 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.Lock.Integration Tests.swift:62` | `isExecutable(_ path: Swift.String)` — uses `withCString`/`access()` directly. | OPEN |
| 42 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.Lock.Integration Tests.swift:74` | `spawn(lockingFile filePath: Swift.String, ...)` | OPEN |
| 43 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.Lock.Integration Tests.swift:120` | `makeLockTestFile(prefix:) -> (path: Swift.String, fd: ...)` — tuple return. | OPEN |
| 44 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.Process.Execute Tests.swift:39` | `findTruePath() -> Swift.String` — searches `/usr/bin/true`. | OPEN |
| 45 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.TestHelper.swift:92` | `isExecutable(_ path: Swift.String)` — duplicate of #41. | OPEN |
| 46 | MEDIUM | `swift-iso-9945/Tests/.../ISO 9945.Kernel.File.Open Tests.swift:130+` | Multiple test bodies using `let path = KernelIOTest.makeTempPath(...)` flowing String. | OPEN |

### Findings — Tests: swift-foundations (Layer 3)

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 47 | MEDIUM | `swift-kernel/Tests/Support/Kernel.Temporary.swift:39` | `directory: Swift.String` — duplicates iso-9945 pattern. | OPEN |
| 48 | MEDIUM | `swift-kernel/Tests/Support/Kernel.Temporary.swift:60` | `filePath(prefix:) -> Swift.String` — duplicates iso-9945 pattern. | OPEN |
| 49 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Open Tests.swift:27` | `makeTempFile(prefix:content:) -> String` — constructs path via string interpolation. | OPEN |
| 50 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Open Tests.swift:41` | `removeTempFile(_ path: String)` — calls `unlink` via `withCString`. | OPEN |
| 51 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Clone Tests.swift:28` | `createTempFile(prefix:content:) -> String` | OPEN |
| 52 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Clone Tests.swift:42` | `readFileContent(_ path: String) -> String?` — `open()` syscall via String. | OPEN |
| 53 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Clone Tests.swift:55` | `cleanup(_ path: String)` — `unlink` via `withCString`. | OPEN |
| 54 | MEDIUM | `swift-file-system/Tests/.../File.System Tests.swift:35` | `createTempPath() -> Swift.String` | OPEN |
| 55 | MEDIUM | `swift-file-system/Tests/.../File.System Tests.swift:39` | `cleanup(_ path: Swift.String)` — converts to `File.Path` internally. | OPEN |
| 56 | MEDIUM | `swift-file-system/Tests/Support/File.Directory.Temporary.swift:39` | `directory: Swift.String` — temp directory property. | OPEN |
| 57 | MEDIUM | `swift-posix/Tests/.../POSIX.Kernel.Glob Tests.swift:37+` | `removeDirectoryRecursively`, `parentDirectory(of:)`, `withTestDirectory`, `createTestFiles(in:)` — all use `String` for paths. | OPEN |
| 58 | MEDIUM | `swift-windows/Tests/.../Windows.Kernel.Glob Tests.swift:56+` | Windows mirror of #57. | OPEN |

### False Positives / Legitimate String Usage

The following were evaluated and determined to be correct uses of `Swift.String`:

| Location | Rationale |
|----------|-----------|
| `swift-source-primitives/.../Source.File.filePath: String` | Display metadata for diagnostics, not syscall-bound. L1 boundary — no file I/O. |
| `swift-source-primitives/.../Source.Location.filePath: String?` | Matches Swift `#filePath` semantics. Display-only. |
| `swift-kernel-primitives/.../Kernel.Glob.Error` path fields | Documented design decision: "Error paths are String by design — for diagnostics/logging, not further processing." |
| `swift-kernel-primitives/.../Kernel.Glob.Pattern.init(_ pattern: String)` | Glob patterns are text syntax, not file system paths. |
| `swift-test-primitives/.../Test.Snapshot.Result` path fields | Diagnostic reporting strings for test framework output. |
| `swift-test-primitives/.../Test.Snapshot.Diff.Result.StructuralOperation` | JSON/YAML structural paths (e.g., `"user.name"`), not file system paths. |
| `swift-darwin-primitives/.../Darwin.Loader.Image.pathString(at:)` | Diagnostic return with documented guidance toward scoped accessors. |
| `Kernel.File.Write.randomToken` / `hexEncode` | Generate opaque tokens, not path data. |

### Systemic Patterns

1. **`.scope()` as symptom**: 16 of the 24 source-level findings (findings #15–24, #21–24, #33–34) wrap `Kernel.Path.scope()` internally. Each `.scope()` call is a typed-path conversion that should have happened at the API boundary. The scope call is the conversion *escape hatch* — its presence inside a function body signals that the parameter type is too weak.

2. **Test helper duplication**: `Kernel.Temporary.directory`, `Kernel.Temporary.filePath(prefix:)`, and `cleanup(path:)` appear in three separate test support directories (swift-iso-9945, swift-kernel, swift-file-system) with identical String-based signatures. A single typed test helper would eliminate all three.

3. **Glob pipeline end-to-end**: The POSIX/Windows Glob APIs accept `directory: Swift.String` and yield `body: (Swift.String) -> Void`. The entire traversal pipeline — directory entry, path concatenation, match filtering — operates on `Swift.String`. The prior research inventory counted this as the largest single cluster of String-as-path usage.

4. **Error type coupling**: `Kernel.File.Write.Atomic.Error` stores paths as `Swift.String` because the internal functions that populate those errors (findings #15–24) traffic in String. Fixing the internal pipeline automatically enables typed error fields.

5. **Layer-correct types**: L2 (swift-iso-9945) should use `Kernel.Path` / `Kernel.Path.View`. L3 (swift-foundations) should use `Paths.Path` / `File.Path` at public boundaries and may use `Kernel.Path.View` at syscall boundaries. No L3 type should appear at L1 or L2.

6. **Missing L1 path decomposition**: `Kernel.File.Write` needs path decomposition (parent directory, filename extraction) but `path-primitives` (L1) only provides `Path`, `Path.View`, and `Path.String.Scope` — no `.parent`, `.lastComponent`, or `.appending`. This forces the internal pipeline to convert to `Swift.String` for manipulation, then convert back via `Kernel.Path.scope()` at each syscall. The decomposition primitives should exist at L1.

### Architectural Decision: Path Decomposition at L1

**Context**: swift-kernel depends on `swift-kernel-primitives` which re-exports `path-primitives` (L1). swift-kernel MUST NOT depend on `swift-paths` (L3) — it has 10 L3 dependents and the fan-out would be inappropriate. swift-kernel MUST NOT use `Swift.String` for internal path manipulation.

**Decision**: Add path decomposition primitives to `swift-path-primitives` (L1). Single implementation at L1; `Paths.Path` (L3) delegates to it — no double implementations.

**Design**: Following `string-primitives` pattern. `Path.View` is `pointer + count` (~Copyable, ~Escapable). Decomposition on View returns **sub-views** (different pointer+count over the same backing bytes) — zero allocation. Owned `Path` allocated only when ownership is needed.

**L1 primitives needed**:

| Primitive | On | Returns | Allocates? | Purpose |
|-----------|-----|---------|------------|---------|
| `parent` | `Path.View` | `Path.View` | No — sub-view | Parent directory (up to last separator) |
| `lastComponent` | `Path.View` | `Path.View` | No — sub-view | Filename (after last separator) |
| `appending(_: borrowing Path.View)` | `Path.View` | `Path` (owning) | Yes — new buffer | Joins with platform separator |

**Why sub-views**: `Path.View` is `pointer + count`, ~Escapable. `parent` returns a view with the same pointer but shorter count (up to the last separator). `lastComponent` returns a view with an advanced pointer and shorter count. Both borrow the same backing bytes — zero allocation. The caller explicitly opts into allocation when ownership is needed: `Path(copying: view.parent)`.

**Temp path construction**: Single allocation via `appending`. `parent.appending(tempComponent)` allocates one buffer: parent bytes + separator + component bytes + terminator. The random token in the component name is the only unavoidable String → bytes conversion.

**Error type path fields**: `Swift.Error` requires `Copyable`, so error enum cases cannot store ~Copyable `Path`. Error path fields remain `Swift.String` for display. This is consistent with `Kernel.Glob.Error` which documents the same design choice.

**Blast radius**: Zero direct consumers of `Kernel.File.Write.Atomic` / `Kernel.File.Write.Streaming` found outside swift-kernel. The `File.System.Write.Atomic` → `Kernel.File.Write.Atomic` delegation is the only call site. No consumer migration needed.

**Layer responsibilities**:

| Layer | Package | Responsibility | Path Type |
|-------|---------|---------------|-----------|
| L1 | path-primitives | Byte-level decomposition (sub-views) + construction (appending) | `Path` (~Copyable), `Path.View` (~Escapable) |
| L1 | kernel-primitives | Syscall wrappers, re-exports path-primitives | `Kernel.Path`, `Kernel.Path.View` |
| L3 | swift-kernel | Composed kernel operations (atomic write, streaming write) | `Kernel.Path.View` internally, no String |
| L3 | swift-paths | Copyable wrapper, delegates decomposition to L1 | `Paths.Path` (Copyable, Sendable) |
| L3 | swift-file-system | User-facing file API, delegates to swift-kernel | `File.Path` (= `Paths.Path`) |

**Consequence for `Kernel.File.Write`**: The internal String pipeline (`resolvePaths`, `posixParentDirectory`, `fileName(of:)`, etc.) is replaced by L1 path decomposition. `Kernel.Path.scope()` happens once at the public API boundary; the internal pipeline operates on `Kernel.Path` / `Kernel.Path.View` throughout. Parent extraction is zero-alloc (sub-view). Temp path construction is one allocation (appending).

**Consequence for `Paths.Path`**: Current `.parent`, `.lastComponent`, `.components`, `.appending()` in swift-paths are replaced with delegation to L1 primitives. `Paths.Path.parent` calls the L1 `Path.View.parent` on its internal storage, wraps the result in a new `Paths.Path`. No double implementations.

**Consequence for Glob pipeline**: swift-posix and swift-windows depend on `swift-kernel-primitives` (L1) which re-exports path-primitives. The Glob APIs can use `Kernel.Path.View` for the directory parameter and yield `Kernel.Path` for matched paths. L1 decomposition (parent, lastComponent, appending) is available for directory traversal.

### Relationship to Prior Research

This audit verifies the current state against the inventory and decisions in [string-path-type-inventory-file-system.md](string-path-type-inventory-file-system.md) v3.0 (2026-03-19). That research identified 93 Category A symbols (String in non-display API signatures). Since then, partial implementation has reduced the count:

| Already resolved (post-inventory) | Mechanism |
|-----------------------------------|-----------|
| `Path.Component` in navigation APIs | Replaced `String` parameters |
| `Path.Component.Extension` / `.Stem` | New validated types |
| `File.Directory.init(validating:)` | Explicit String→Path conversion point |
| `File.init(_ path: File.Path)` | Typed path in public API |
| Glob callback-based API | Internal refactor (String still in public API) |

**Remaining**: 35 source findings + 38 test findings = 73 total. The bulk of the remaining work is the Glob pipeline (findings #3–8), the `Kernel.File.Write` internals (#15–24), and the test helper unification (#32–58).

### Remediation Plan

#### Phase 1: Public API — Glob Pipeline (findings #3–8)

Highest impact. Depends on Phase 4a (L1 decomposition). swift-posix and swift-windows depend on `swift-kernel-primitives` which re-exports `path-primitives` — L1 path types are available.

```swift
// Before
public static func match(pattern: Pattern, in directory: Swift.String, ..., body: (Swift.String) -> Void)

// After
public static func match(pattern: Pattern, in directory: borrowing Kernel.Path.View, ..., body: (borrowing Kernel.Path.View) -> Void)
```

Internal helpers (`matchSegments`, `pathExists`, `isDirectory`) use L1 `Kernel.Path.View` for directory parameters and L1 `appending` for path construction during traversal.

**Blast radius**: `File.Directory.Glob` in swift-file-system is the primary consumer. Already callback-based internally per prior research implementation.

#### Phase 2: Public API — Windows.Loader (findings #1–2)

```swift
// Before
public static func open(path: String) throws(Loader.Error) -> Handle

// After
public static func open(path: borrowing Kernel.Path) throws(Loader.Error) -> Handle
```

Matches `Windows.Kernel.File.Open` which already uses `borrowing Kernel.Path`.

#### Phase 3: Public API — Test.Reporter + Source.Cache (findings #9–14)

```swift
// Test.Reporter: String → File.Path
public static func json(to path: File.Path? = nil) -> Test.Reporter
public static func structured(to path: File.Path) -> Test.Reporter

// Source.Cache: String → File.Path as key
internal var _loaded: [File.Path: [UInt8]]
```

#### Phase 4: L1 Path Decomposition + Kernel.File.Write Migration (findings #15–24, #25–31)

Three sub-phases, bottom-up:

**Phase 4a: Add path decomposition as platform extensions on `Path.View`**

Per [PLAT-ARCH-008c], decomposition methods live in platform packages — NOT in `swift-path-primitives` with `#if os()`. `Path.View` is visible in platform packages via the `Kernel_Primitives` re-export chain. Each platform package extends `Path.View` with `parentBytes`, `lastComponentBytes`, `appending`. No conditional compilation inside the implementations — the package boundary is the platform boundary.

| Platform | Package | File |
|----------|---------|------|
| POSIX | `swift-iso-9945` | `ISO 9945.Kernel.Path.Navigation.swift` |
| Windows | `swift-windows-primitives` | `Windows.Kernel.Path.Navigation.swift` |

`swift-path-primitives` adds only `Path.init(_ span: Span<Char>)` — platform-agnostic allocation from a `Span` sub-view.

`parentBytes` and `lastComponentBytes` return zero-alloc `Span<Char>` sub-views. `appending` returns owned `Path` (one allocation). Windows handles UNC paths (`\\server\share`), drive letters (`C:\`), and dual separators (`/` and `\`). Oracle: `Paths.Path.Navigation.swift` + `Kernel.File.Write+Shared.swift`.

**Phase 4b: Migrate `Paths.Path` decomposition to delegate to L1**

Current `Paths.Path.parent`, `.lastComponent`, `.components`, `.appending()` in swift-paths reimplement separator scanning on `Swift.String`. Replace with delegation to L1 primitives — `Paths.Path.parent` calls `Path.View.parent` on its internal storage, wraps the result in a new `Paths.Path`.

**Sequencing**: 4b should follow 4a after the L1 primitives are verified by tests and by Phase 4c. The existing swift-paths implementation is working and tested; replacement should be incremental.

**Phase 4c: Replace String pipeline in `Kernel.File.Write` with L1 path types**

`Kernel.File.Write.Atomic` and `Kernel.File.Write.Streaming` stay in swift-kernel. The delegation from `File.System.Write.Atomic` → `Kernel.File.Write.Atomic` stays. What changes is the **internal pipeline**:

```swift
// Before (String pipeline):
let (resolved, parent) = resolvePaths(pathString)           // String → String
let baseName = fileName(of: dest)                            // String → String
let tempPath = "\(parent)/.\(baseName).atomic.\(pid).tmp"   // String interpolation
try Kernel.Path.scope(tempPath) { ... }                      // String → Kernel.Path at each syscall

// After (L1 path pipeline):
let parent = path.parent                                     // Kernel.Path.View → Kernel.Path
let baseName = path.lastComponent                            // Kernel.Path.View → Kernel.Path
let tempPath = parent.view.appending(tempComponent.view)     // L1 path construction
try Kernel.File.Open.open(path: tempPath.view, ...)          // Kernel.Path.View at syscall — no .scope()
```

**Deletions from swift-kernel**:
- `resolvePaths`, `normalizeWindowsPath`, `posixParentDirectory`, `windowsParentDirectory`, `fileName(of:)` — replaced by L1 primitives
- `fileExists(_ pathString: String)` → `fileExists(_ path: borrowing Kernel.Path.View)`
- `atomicRename(from: String, to: String)` → uses `Kernel.Path.View` directly
- `syncDirectory(_ pathString: String)` → uses `Kernel.Path.View` directly
- All `Kernel.Path.scope()` calls inside function bodies — eliminated

**Error types**: `Kernel.File.Write.Atomic.Error` path fields change from `Swift.String` to `Kernel.Path` (or remain String for display — design decision at implementation time). The `File.System.Write.Atomic` type aliases continue to work.

This phase resolves all 17 findings (#15–31) by replacing the String pipeline with L1 typed paths.

#### Phase 5: Test Helpers (findings #32–58)

Test helpers at each layer should use the layer-appropriate path type:

- **L2 tests (swift-iso-9945)**: Use `Kernel.Path.View` with scoped patterns (`withTempFile { path, fd in }`). The existing scoped helpers in swift-kernel's test support already demonstrate this pattern.
- **L3 tests (swift-foundations)**: Use `File.Path` (= `Paths.Path`). `ExpressibleByStringLiteral` gives ergonomic literal syntax. Runtime-constructed paths use `File.Path(stringValue)` or string interpolation.

Unify duplicated helpers (3 copies of `Kernel.Temporary`) into layer-appropriate test support.

#### Phase 6: Error Types (findings #25–31)

Depends on Phase 4c. Once the internal pipeline uses `Kernel.Path` / `Kernel.Path.View`, error cases can store typed paths instead of `Swift.String`. Design decision at implementation time: typed path for programmatic access vs. `.string` for display ergonomics.

### Summary

58 findings: 0 critical, 10 high, 41 medium, 7 low (deferred).

**Systemic root cause**: Path decomposition was missing at L1. `path-primitives` provides `Path` and `Path.View` but no `.parent`, `.lastComponent`, or `.appending`. This forced `Kernel.File.Write` to convert to `Swift.String` for path manipulation, and forced `Paths.Path` (L3) to reimplement decomposition. The fix is bottom-up: add decomposition to L1, then both swift-kernel and swift-paths delegate to the single implementation.

**Key insight**: 16 of 24 source findings contain `Kernel.Path.scope()` calls inside function bodies. Each `.scope()` is a smoking gun: it proves the function receives a path-as-String and must convert before the syscall. The architectural decision to relocate composed write operations to swift-file-system eliminates the entire String pipeline — `Paths.Path` provides typed decomposition, and `.kernelPath` provides zero-alloc syscall access.

**Architectural principle**: Path decomposition is an L1 primitive. Single implementation in `swift-path-primitives`; `Paths.Path` (L3) delegates to it. swift-kernel uses L1 path types internally — no `Swift.String`, no L3 dependency. The delegation chain `File.System.Write.Atomic` → `Kernel.File.Write.Atomic` → kernel syscall primitives stays intact; what changes is that String exits the internal pipeline entirely.

## Pre-Publication — 2026-04-02

### Scope

- **Target**: Priority 1 packages (unpushed commits) from the GitHub organization migration plan
- **Skills**: code-surface, implementation, platform, modularization, documentation
- **Requirement IDs**: [API-NAME-001–004a], [API-ERR-001–005], [API-IMPL-003–011], [IMPL-002–060], [PLAT-ARCH-001–005], [MOD-001–014], [DOC-001–005]
- **Packages**: 7 (swift-rfc-4648, swift-rfc-9110, swift-iso-8601, swift-iso-32000, swift-iso-3166, swift-w3c-css, swift-base62-primitives)
- **Purpose**: Verify code quality before making all standards-body and primitives repos public

### Per-Package Triage

| Package | Findings | Worst | Blocker Summary |
|---------|----------|-------|-----------------|
| swift-rfc-4648 | 23 | HIGH | Multi-type files (6), compound convenience methods on String/Data/Collection extensions |
| swift-rfc-9110 | 65 (45 after spec-mirror exception) | CRITICAL | 5 compound type names, multi-type files (8), 20 bare-throws Codable (deferred), avoidable compound methods (~8) |
| swift-iso-8601 | 59 | CRITICAL | 4 top-level `__`-prefixed compound error types, multi-type files (17), methods in type bodies (5), compound property names (7) |
| swift-iso-32000 | 87 | CRITICAL | Foundation import (1), ContentStream compound methods (~37), multi-type files (~12), pervasive `.rawValue` extraction (~40 sites) |
| swift-iso-3166 | 22 | CRITICAL | Multi-type error file (4 types in 1 file), validation logic in type bodies (3), extension separation (6) |
| swift-w3c-css | 10 (systemic) | CRITICAL | **All ~724 types** use flat compound names (`BackgroundColor` not `CSS.Background.Color`). Entire package requires restructuring. |
| swift-base62-primitives | 11 | CRITICAL | Multi-type file (4 types in 1 file), methods in type bodies (4), compound method names (3) |

**Aggregate: 277 findings across 7 packages. 45 CRITICAL, 122 HIGH, 76 MEDIUM, 27 LOW, 7 informational.**

### Systemic Patterns

#### 1. [API-IMPL-005] One Type Per File — ALL 7 PACKAGES

The most pervasive violation. Every package bundles multiple type declarations into single files. Common patterns:
- Parser + Formatter + Output in one file (swift-iso-8601)
- Namespace enum + 4–15 concrete types in one file (swift-iso-32000 `7.3 Objects.swift`)
- Multiple error types in one file (swift-iso-3166, swift-iso-8601)
- Struct + Iterator in one file (swift-rfc-9110)

**Recommendation**: This is the highest-volume fix. Consider a script-assisted split: for each file with >1 type declaration, extract each type into `{Namespace}.{Type}.swift`.

#### 2. [API-NAME-002] Compound Identifiers — 5/7 PACKAGES

Compound method/property names are widespread, with two distinct categories:

**Spec-mirroring compounds** (EXCEPTED): HTTP status names (`notFound`, `badRequest`), header field names (`contentType`, `userAgent`), CSS property names. These mirror specification terminology. **Decision (2026-04-02): spec-mirroring static constants, enum cases, and type names that directly encode spec-defined terms are exempt from [API-NAME-002].** This exception covers identifiers whose compound form IS the specification's terminology.

**Avoidable compounds**: `saveGraphicsState()`, `setStrokeColorRGB()`, `headerValue`, `base64URLEncodedString()`, `formatHeader()`. These are NOT spec terms — they are implementation choices. They should use nested accessor patterns (`graphicsState.save()`, `stroke.color.rgb()`, `header.value`, etc.).

**Recommendation**: Fix avoidable compounds. Spec-mirroring compounds are now excepted.

#### 3. [API-IMPL-008] Minimal Type Body — 6/7 PACKAGES

Computed properties, validation logic, methods, and protocol conformance implementations inside type bodies instead of extensions. The most common violations:
- Computed properties (`isZero`, `description`, `headerValue`) in type body
- Init with validation logic (guard/throw) in type body
- `Equatable`/`Hashable` implementations in type body

**Recommendation**: Mechanical fix — move everything except stored properties and the canonical init into extensions.

#### 4. [API-ERR-001] Codable Bare Throws — SYSTEMIC (4 PACKAGES)

Every package with `Codable` conformance has bare `throws` on `init(from:)` and `encode(to:)`. This is a protocol-imposed limitation: Swift's `Codable` protocol declarations use untyped `throws`, and conformances cannot narrow to typed throws.

**Recommendation**: Mark as DEFERRED — known protocol limitation. Not fixable without custom coding patterns or Swift language changes.

#### 5. [API-NAME-001] Compound Type Names — 3 PACKAGES (1 SYSTEMIC)

- **swift-w3c-css**: ALL ~724 types use flat compound names. Entire package requires namespace restructuring.
- **swift-rfc-9110**: 5 types (`ContentNegotiation`, `ContentEncoding`, `ContentLanguage`, `EntityTag`, `MediaType`).
- **swift-iso-8601**: 5 top-level `__`-prefixed error types violate both naming and nesting conventions.

**Recommendation**: swift-w3c-css needs a dedicated restructuring pass. swift-rfc-9110 and swift-iso-8601 are localized fixes.

#### 6. [PRIM-FOUND-001] Foundation Import — 1 PACKAGE

swift-iso-32000 imports Foundation in `12.8 Digital signatures.swift`. Foundation is forbidden in L2 Standards packages.

**Recommendation**: Fix immediately — single file.

### Known Deviations

| Pattern | Packages | Status | Reason |
|---------|----------|--------|--------|
| Codable bare `throws` | swift-rfc-9110, swift-iso-8601, swift-iso-3166, swift-iso-32000 | DEFERRED | Protocol-imposed: `Codable` declares `throws`, not `throws(E)` |
| HTTP status/header compound names | swift-rfc-9110 | EXCEPTED | Spec-mirroring static constants are exempt from [API-NAME-002] per 2026-04-02 decision |
| Relative path dependencies in Package.swift | All 7 packages | DEFERRED | Required for local development; publication uses versioned URLs via subtree extraction |
| Platform minimum `.v26` | All 7 packages | DEFERRED | Matches current development toolchain; adjustable at publication time |

### Publication Blockers (Must Fix)

| Priority | Issue | Packages | Estimated Scope |
|----------|-------|----------|-----------------|
| P0 | Foundation import in L2 | swift-iso-32000 | 1 file |
| P0 | Top-level `__` compound error types | swift-iso-8601 | 4 types → nest as `.Parse.Error` |
| P1 | Compound type names | swift-rfc-9110 (5 types), swift-w3c-css (724 types) | swift-rfc-9110: localized; swift-w3c-css: full restructure |
| P1 | One-type-per-file | All 7 packages | ~80 files need splitting |
| P2 | Methods in type bodies | 6/7 packages | ~60 types need method extraction |
| P2 | Compound method/property names (avoidable) | 5/7 packages | ~50 identifiers |
| P3 | Missing doc comments | All 7 packages | ~70 declarations |

### Verdict

**Not ready for publication.** The P0 and P1 blockers must be resolved first. swift-w3c-css requires the most work (full namespace restructuring). The remaining 6 packages have localized issues that can be fixed incrementally. Recommend:

1. Fix P0 items (Foundation import, `__` error types) — immediate
2. Fix swift-rfc-9110 compound type names — localized rename
3. Make a decision on spec-mirroring compound identifiers (HTTP status/header names)
4. Script-assisted one-type-per-file split across all packages
5. Defer swift-w3c-css restructuring — flag as blocked on namespace design decision
6. After P0–P1 clean, proceed to Priority 2 packages (swift-file-system transitive closure)

### Summary

277 findings across 7 packages: 45 critical, 122 high, 76 medium, 27 low.
Dominant patterns: multi-type files (all 7), compound identifiers (5/7), methods in type bodies (6/7), Codable bare throws (systemic).
