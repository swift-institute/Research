# Research Prompt: Array.Protocol forEach Redesign

## Task

Do `/research-process` — Tier 2 investigation: redesign `forEach` on `Array.Protocol` so that `forEach` operates on **elements** (matching stdlib semantics), and index-based iteration uses a separate API (e.g., `array.indices.forEach`).

## Context

`Array.Protocol` (in swift-array-primitives) currently provides:

```swift
// Array.Protocol+defaults.swift — method, non-mutating
extension Array.`Protocol` where Self: ~Copyable {
    public func forEach(_ body: (Index) -> Void) { ... }
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R { ... }
}
```

And separately, `Collection.Protocol` and `Array` provide property-based `forEach` via Property.View:

```swift
// Collection.Protocol+ForEach.swift — property, mutating _read
extension Collection.`Protocol` where Self: ~Copyable {
    public var forEach: Property<Collection.ForEach, Self>.View { mutating _read { ... } }
}

// Array.Dynamic ~Copyable.swift — property, mutating _read
extension Array where Element: ~Copyable {
    public var forEach: Property<Collection.ForEach, Self>.View.Typed<Element> { mutating _read { ... } }
}
```

The Property.View `callAsFunction` iterates **elements** via borrowing:
```swift
extension Property.View where Base: Collection.`Protocol` & ~Copyable, Tag == Collection.ForEach {
    public func callAsFunction(_ body: (borrowing Base.Element) -> Void) { ... }
}
```

### The Problem

Three candidates named `forEach` exist on every `Array` conformer:

| # | Source | Kind | Mutability | Closure parameter |
|---|--------|------|------------|-------------------|
| 1 | `Array.Protocol+defaults` | method | non-mutating | `(Index) -> Void` |
| 2 | `Collection.Protocol+ForEach` | property | `mutating _read` | `(borrowing Element) -> Void` |
| 3 | `Array.Dynamic ~Copyable` | property | `mutating _read` | `(borrowing Element) -> Void` |

In non-mutating contexts, only #1 is available. But when #1's `Void` constraint fails (because `withElement<R>` propagates a non-Void inner return like `Set.insert`'s tuple), the compiler evaluates all three, finds all failing for different reasons, and reports "ambiguous" instead of the real error.

**Reproducer** (in rule-burgerlijk-wetboek-2):
```swift
// FAILS — Set.insert returns (Bool, Element), withElement propagates it,
// outer forEach closure becomes non-Void, method #1 fails, ambiguity with #2/#3
inschrijvingen.forEach { idx in
    inschrijvingen.withElement(at: idx) { result.insert($0.registratie.houder.persoon) }
}

// WORKS — assignment returns Void
inschrijvingen.forEach { idx in
    inschrijvingen.withElement(at: idx) { total = total + $0.aandeel.`nominaal bedrag` }
}
```

**Current workaround**: Annotate inner closure `-> Void`:
```swift
inschrijvingen.withElement(at: idx) { (inschrijving: borrowing Inschrijving) -> Void in
    result.insert(inschrijving.registratie.houder.persoon)
}
```

### The Deeper Issue

The method `func forEach(_ body: (Index) -> Void)` iterates **indices**. But Swift stdlib's `Sequence.forEach` iterates **elements** with `_ body: (Element) throws -> Void`. Having `forEach` mean "iterate indices" on Array.Protocol contradicts both stdlib semantics and the Property.View forEach (which iterates elements). The Array.Protocol doc comment even says `forEachIndex` in its example but the method is named `forEach`.

## Question

What should the iteration API surface look like on `Array.Protocol` so that:
1. `forEach` means element iteration (matching stdlib, matching Property.View)
2. Index-based iteration has a separate, unambiguous name
3. The three-way ambiguity is eliminated
4. Existing `forEach + withElement` call sites migrate cleanly

## Evaluation Criteria

1. **Stdlib alignment** — `forEach` should mean the same thing as `Sequence.forEach`
2. **Name uniqueness** — no method/property name collision on `forEach`
3. **Composability with ~Copyable** — element forEach needs borrowing semantics; index forEach needs the index
4. **Migration cost** — how many call sites in the ecosystem use the index-yielding `forEach`?
5. **[IMPL-INTENT]** — call sites should read as intent, not mechanism

## Options to Consider

- **A**: Rename index-yielding method to `forEachIndex` (matches existing doc comment)
- **B**: Remove the method entirely; provide `array.indices.forEach { }` where `indices` is a range or collection
- **C**: Keep method as `forEach` but make it yield elements (like Property.View does), remove the index variant
- **D**: Something else

## Scope

### Files to Read

**Array iteration infrastructure**:
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Primitives Core/Array.Protocol.swift`
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Primitives Core/Array.Protocol+defaults.swift`
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Dynamic Primitives/Array.Dynamic ~Copyable.swift` (forEach property)

**Collection iteration infrastructure**:
- `/Users/coen/Developer/swift-primitives/swift-collection-primitives/Sources/Collection Primitives/Collection.Protocol+ForEach.swift`
- `/Users/coen/Developer/swift-primitives/swift-collection-primitives/Sources/Collection Primitives/Collection.ForEach+Property.View.swift`
- `/Users/coen/Developer/swift-primitives/swift-collection-primitives/Sources/Collection Primitives/Collection.ForEach.swift`

**Other Array variants** (also have forEach properties):
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Fixed Primitives/Array.Fixed ~Copyable.swift`
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Static Primitives/Array.Static ~Copyable.swift`
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Small Primitives/Array.Small ~Copyable.swift`

**Swift stdlib reference**:
- `/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Sequence.swift` (lines 850-858)

**Consumer showing the problem**:
- `/Users/coen/Developer/rule-law/rule-law-nl/rule-burgerlijk-wetboek-2/Sources/Rule Burgerlijk Wetboek 2/Besloten Vennootschap.Aandeelhoudersregister.swift`

**Ecosystem usage scan**: Grep for `.forEach { idx in` and `.withElement(at:` across swift-primitives, swift-standards, swift-foundations, rule-law to measure migration cost.

## Constraints

- `forEach` body MUST constrain to `-> Void` (matching stdlib)
- Property.View forEach MUST stay (it's the composable borrowing iteration pattern)
- `~Copyable` elements MUST be supported (borrowing access, no copies)
- Solution MUST follow [IMPL-000] call-site-first design

## Output

Write research document to `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-foreach-redesign.md`. Follow [RES-003] structure. Include ecosystem usage scan results and migration cost.

If a clear recommendation emerges, implement it. Run `swift build` and `swift test` on swift-array-primitives. Then grep for broken call sites across the workspace and fix them.
