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

## Accepted Compiler Warnings — 2026-03-25

### Scope

- **Target**: swift-primitives (swift-ordering-primitives, swift-buffer-primitives)
- **Trigger**: Build log warning triage from `swift test` on swift-foundations
- **Files**: Ordering comparator extensions, buffer inline primitives

### Context

During a full warning audit of the swift-foundations test build, two classes of warnings in swift-primitives were identified as **not fixable** without either restricting the public API surface or introducing incorrect code. Both are accepted as compiler limitations pending future Swift evolution.

### Findings

| # | Severity | Diagnostic | Location | Finding | Status |
|---|----------|------------|----------|---------|--------|
| 1 | — | `#SendableMetatypes` | `Ordering.Comparator+Swift.Comparable.swift:28,83` | "capture of non-Sendable type 'T.Type' / 'Value.Type' in an isolated closure." Metatypes are stateless global descriptors — inherently thread-safe. The `nonisolated(unsafe) let _: T.Type = T.self` workaround documents intent but does not suppress implicit metatype captures. Adding `& Sendable` to constraints was attempted and reverted: it caused cascade failures in downstream callers (`Ordering.Order+Swift.Comparable.swift`, etc.) where `Sendable` is not required. | ACCEPTED |
| 2 | — | `#SendableMetatypes` | `Ordering.Comparator+Comparable.swift:25` | Same diagnostic for `T: Comparison.Protocol & ~Copyable`. Adding `& Sendable` would exclude non-Sendable `~Copyable` comparable types — a legitimate use case. | ACCEPTED |
| 3 | — | `#SendableMetatypes` | `Ordering.Comparator+Projection.swift:35` | Same diagnostic for `Value: Comparison.Protocol & ~Copyable` in the `by` method. Same rationale as #2. | ACCEPTED |
| 4 | — | "variable was never mutated" | `Buffer.Arena.Small.swift`, `Buffer.Linear.Small.swift`, `Buffer.Linear.Small Copyable.swift`, `Buffer.Ring.Small Copyable.swift`, `Buffer.Linked.Small Copyable.swift` (17 sites) | All flagged `var buf` / `var inlineBuf` declarations use `consume buf` for ownership transfer. `consume` requires a `var` binding — `let` produces "'buf' is borrowed and cannot be consumed." The compiler's mutation analysis does not recognize `consume` as requiring mutability. | ACCEPTED |

### Rationale

**`#SendableMetatypes`**: Metatypes (`T.Type`) are pointers into read-only type metadata in the binary. They carry no mutable state and are inherently safe to share across concurrency boundaries. The Swift compiler's `#SendableMetatypes` diagnostic is conservative — it flags all metatype captures in `@Sendable` closures where the type itself is not `Sendable`. This is a known area where the type system lacks the expressivity to distinguish "the metatype of `T`" (always safe) from "a value of type `T`" (may not be safe). Future Swift evolution is expected to make metatypes unconditionally `Sendable`.

**`var` never mutated**: The `consume` keyword performs a move — transferring ownership out of a binding. This is semantically distinct from mutation, but syntactically requires `var` because the binding's value is invalidated after the consume. The compiler's "never mutated" analysis predates ownership annotations and does not account for `consume`. This is a known false positive that will be resolved when the warning analysis is updated to recognize ownership operations.

### Re-evaluation triggers

- **`#SendableMetatypes`**: Re-evaluate when Swift adds unconditional metatype Sendability (likely via SE proposal) or when `nonisolated(unsafe)` is extended to cover implicit metatype captures.
- **`var` never mutated**: Re-evaluate when the compiler's mutation analysis recognizes `consume` as requiring `var`.

## Prior Art Compliance — swift-io — 2026-03-25

### Scope

- **Target**: swift-io (Layer 3, swift-foundations) + IO types in swift-kernel-primitives (Layer 1, swift-primitives)
- **Method**: Design audit against external IO systems literature — 15 systems surveyed, 72 swift-io concepts evaluated
- **Files**: 279 source files across 7 targets
- **Research**: [io-prior-art-and-swift-io-design-audit.md](io-prior-art-and-swift-io-design-audit.md) (consolidated literature survey + concept-by-concept evaluation)

### Context

Proactive Discovery audit ([RES-012]) to determine whether swift-io introduces unnecessary custom concepts or whether its design is justified by established IO systems practice. Conducted without internal requirement IDs — evaluation criteria are the 4-tier concept necessity spectrum derived from the literature:

| Tier | Definition | Expectation |
|------|-----------|-------------|
| 1 (Irreducible) | Every IO system has this | Must have |
| 2 (Expected) | Best-in-class systems have this | Should have |
| 3 (Valuable) | Present in many systems | May have |
| 4 (Paradigm-specific) | Justified only by language context | Requires justification |

### Systems Surveyed

Rust (std::io, tokio, mio, tokio-uring, monoio), Go (io, bufio, os, net), Java (java.io, java.nio, NIO.2, Loom), .NET (System.IO, Pipelines, Span/Memory), Zig (std.io pre-0.15, std.Io 0.15.1+), OCaml (classic IO, Eio), Haskell (System.IO, conduit, pipes), SwiftNIO, Swift System, epoll, kqueue, IOCP, io_uring, libuv.

### Findings

| # | Category | Concepts | Prior Art Tier | Verdict |
|---|----------|----------|---------------|---------|
| 1 | Kernel primitives (L1) | 12 (Descriptor, IO.Error, Event, Interest, Flags, Socket.*, File.Offset/Delta/Size) | All Tier 1-2 | CLEAN — direct mappings to POSIX/kernel structures |
| 2 | IO Core | 5 (IO namespace, Lifecycle, Lifecycle.Error, Closable, Backpressure.Strategy) | Tier 2-4 | CLEAN — Closable with `consuming close()` + `~Copyable` is well-precedented (Rust OwnedFd, Clean uniqueness types) |
| 3 | IO Events | ~18 (Selector, Driver, Channel, Poll, Registration, Token type-state, Waiter, Wakeup, Backoff, Deadline, Batch, etc.) | Tier 2-4 | CLEAN — all map to mio/NIO/libuv/Java NIO patterns; Token type-state is a justified Swift adaptation of known typestate technique |
| 4 | IO Completions | ~15 (Completion.ID, Operation, Event, Outcome, Queue, Submission, Driver, IOCP, IOUring, Read/Write/Accept/Connect) | All Tier 2 | CLEAN — direct typed Swift interface over io_uring SQ/CQ and IOCP |
| 5 | IO Blocking | ~10 (Lane, Capabilities, Deadline, Execution.Semantics, Ticket, Sharded, Abandoning, Threads) | Tier 2-3 | CLEAN — maps to tokio spawn_blocking, libuv thread pool, Java ExecutorService |
| 6 | IO Executor | ~12 (Executor, Handle, Registry, Waiter, Lane, Pool, Backend, Scope, Slot, Teardown, Ready/Pending) | Tier 2-4 | CLEAN — 1 truly novel concept (IO.Executor.Slot), justified by Swift's unique actor + ~Copyable combination |

### Summary

72 concepts audited. **0 findings.** Distribution:

| Prior Art Tier | Count | % |
|---------------|-------|---|
| Tier 1-2 (universal/expected) | ~56 | 78% |
| Tier 3 (valuable) | ~10 | 14% |
| Tier 4 (paradigm-specific) | ~5 | 7% |
| Truly novel | 1 | 1% |

**Verdict: CLEAN.** swift-io does not introduce unnecessary custom concepts. Every abstraction maps to recognized IO systems prior art or is a justified adaptation of Swift's type system (`~Copyable`, typed throws, token type-state, witness structs). The 279-file count reflects the ecosystem's namespace-first file organization ([API-IMPL-005], [API-NAME-001]), not conceptual bloat — the concept set is isomorphic to tokio/mio/libuv.

The single truly novel concept — `IO.Executor.Slot` (cross-actor `~Copyable` value transfer) — has no prior art because no other language combines actors with move-only types. Its existence is justified by the language constraint it addresses.

**Notable strengths relative to prior art**: dual-model IO (events + completions) as first-class peers (only Zig 0.15.1+ does this), compile-time resource safety via `~Copyable`, type-state enforcement for event registration, typed throws with composite errors matching Zig's precision.

---

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
PKG="/Users/coen/Developer/swift-primitives/swift-queue-primitives"
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
PKG="/Users/coen/Developer/swift-primitives/swift-heap-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/Heap_Fixed_Primitives/Heap_Bounded_Primitives/g' \
  -e 's/Heap Fixed Primitives/Heap Bounded Primitives/g'
```

**swift-set-primitives** (1 Fixed type, 1 hoisted error, no separate module):

```bash
PKG="/Users/coen/Developer/swift-primitives/swift-set-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/__SetOrderedFixedError/__SetOrderedBoundedError/g'
```

**swift-bitset-primitives** (1 Fixed type, 1 hoisted error, no separate module):

```bash
PKG="/Users/coen/Developer/swift-primitives/swift-bitset-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/__BitsetFixedError/__BitsetBoundedError/g'
```

**swift-list-primitives** (1 Inline→Static, 1 hoisted error):

```bash
PKG="/Users/coen/Developer/swift-primitives/swift-list-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/List\.Linked\.Inline/List.Linked.Static/g' \
  -e 's/__ListLinkedInlineError/__ListLinkedStaticError/g'
# Declaration rename (only in the one file):
sed -i '' 's/public struct Inline<let capacity/public struct Static<let capacity/g' \
  "$PKG/Sources/List Primitives Core/List.Linked.swift"
```

**swift-tree-primitives** (1 Inline→Static, 1 hoisted error, 1 module/target):

```bash
PKG="/Users/coen/Developer/swift-primitives/swift-tree-primitives"
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
  "/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Worker.swift" \
  "/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Runtime.State.swift"
sed -i '' 's/Queue\.Fixed/Queue.Bounded/g; s/Heap\.Fixed/Heap.Bounded/g; s/DoubleEnded\.Fixed/DoubleEnded.Bounded/g' \
  "/Users/coen/Developer/swift-foundations/swift-io/Research/data-structure-ecosystem-triage.md"
```

#### File and Directory Renames (git mv)

**swift-queue-primitives:**

```bash
cd /Users/coen/Developer/swift-primitives/swift-queue-primitives
git mv "Sources/Queue Fixed Primitives" "Sources/Queue Bounded Primitives"
git mv "Sources/Queue Primitives Core/Queue.Fixed.swift" "Sources/Queue Primitives Core/Queue.Bounded.swift"
git mv "Sources/Queue Bounded Primitives/Queue.Fixed Copyable.swift" "Sources/Queue Bounded Primitives/Queue.Bounded Copyable.swift"
```

**swift-heap-primitives:**

```bash
cd /Users/coen/Developer/swift-primitives/swift-heap-primitives
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
cd /Users/coen/Developer/swift-primitives/swift-set-primitives
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed Copyable.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded Copyable.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed.Indexed.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded.Indexed.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Consume.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded+Sequence.Consume.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Drain.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded+Sequence.Drain.swift"
```

**swift-bitset-primitives:**

```bash
cd /Users/coen/Developer/swift-primitives/swift-bitset-primitives
git mv "Sources/Bitset Primitives/Bitset.Fixed.swift" "Sources/Bitset Primitives/Bitset.Bounded.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Error.swift" "Sources/Bitset Primitives/Bitset.Bounded.Error.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Algebra.swift" "Sources/Bitset Primitives/Bitset.Bounded.Algebra.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Algebra.Symmetric.swift" "Sources/Bitset Primitives/Bitset.Bounded.Algebra.Symmetric.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Relation.swift" "Sources/Bitset Primitives/Bitset.Bounded.Relation.swift"
```

**swift-list-primitives:**

```bash
cd /Users/coen/Developer/swift-primitives/swift-list-primitives
git mv "Sources/List Linked Primitives/List.Linked.Inline.swift" "Sources/List Linked Primitives/List.Linked.Static.swift"
```

**swift-tree-primitives:**

```bash
cd /Users/coen/Developer/swift-primitives/swift-tree-primitives
git mv "Sources/Tree N Inline Primitives" "Sources/Tree N Static Primitives"
git mv "Sources/Tree N Static Primitives/Tree.N.Inline.swift" "Sources/Tree N Static Primitives/Tree.N.Static.swift"
git mv "Sources/Tree N Static Primitives/Tree.N.Inline.Error.swift" "Sources/Tree N Static Primitives/Tree.N.Static.Error.swift"
```

#### Verification

```bash
# Per package:
cd /Users/coen/Developer/swift-primitives/{package} && swift build && swift test

# Downstream:
cd /Users/coen/Developer/swift-foundations && swift build
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
