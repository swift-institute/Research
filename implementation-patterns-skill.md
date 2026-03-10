# Implementation Patterns Skill

<!--
---
version: 1.2.0
last_updated: 2026-03-10
status: SUPERSEDED
tier: 2
---
-->

## Context

The `e54c6b6` refactor of storage-primitives demonstrates a mature implementation style that has emerged organically across the Swift Institute ecosystem. The key insight is not which infrastructure exists — it's what **perfect code looks like at the call site**.

The existing `conversions` and `anti-patterns` skills capture _what to avoid_ and _how conversions work mechanically_, but they don't capture the fundamental design principle: **write the ideal expression first, then make the infrastructure serve it**. When the infrastructure doesn't exist yet, that's not a reason to write ugly code — it's a reason to improve the infrastructure.

This research investigates a new **implementation** skill built around that principle.

## Question

Should we create a new skill (working name: "implementation") that captures the ideal call-site-first design philosophy? What should it contain, what should it supersede, and what requirement IDs should it use?

## Core Principle: Call-Site-First Design

**Every line of implementation code should be locally perfect.** When you write a function body, write the ideal expression — the one that reads like intent, not mechanism. Then:

1. **If the infrastructure supports it** → you're done.
2. **If the infrastructure doesn't support it** → improve the infrastructure until it does.

This means:
- You never accept `.rawValue.rawValue` because "that's how the types work." You add an operator or overload so the call site doesn't need it.
- You never accept `Int(range.count.rawValue.rawValue)` because "stdlib needs Int." You add a boundary overload that accepts the typed count.
- You never accept a 6-line `withUnsafe*` closure because "that's the only way to get a pointer." You add a `pointer(at:)` method.
- You never accept a manual `switch` over enum cases because "that's how enums work." You add `.forEach` so the intent is clear.

The infrastructure serves the expression. Not the other way around.

## Analysis

### Option A: New "implementation" Skill That Supersedes Both

Create a single `implementation` skill that absorbs all of `conversions` and `anti-patterns`, plus adds new rules for expression design and call-site patterns.

**Advantages**: Single source of truth. No routing ambiguity.
**Disadvantages**: Very large skill. Naming/errors/code-org are already separate — this would create a super-skill. Blurs the line between "rules" and "style".

### Option B: New "implementation" Skill That Complements (Not Supersedes)

Create a new `implementation` skill focused on **how to write expressions and compose operations**, while `conversions` remains the reference for type aliases, conversion APIs, and rawValue rules. `anti-patterns` remains the reference for what to avoid.

**Advantages**: Each skill has a clear focus. `implementation` teaches style; `conversions` defines the type system; `anti-patterns` defines the negative space.
**Disadvantages**: Three skills to consult for related concerns. Overlap on rawValue rules.

### Option C: Merge Anti-Patterns Into Implementation, Keep Conversions

Anti-patterns are inherently "implementation guidance" (what not to do). Merge them into the new skill. Keep `conversions` as the mechanical reference for type aliases, conversion APIs, and domain rules.

**Advantages**: Clean separation — `conversions` = "what types exist and how they convert", `implementation` = "how to write code using them (dos and don'ts)". Two skills instead of three. The anti-patterns naturally fit as "incorrect" examples paired with "correct" implementations.
**Disadvantages**: `anti-patterns` skill goes away, references need updating.

### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Single source for "how to write code" | Yes | Partial | Yes |
| Conversions reference intact | No | Yes | Yes |
| Anti-patterns preserved | Absorbed | Separate | Absorbed |
| Skill count change | 2→1 | 2→3 | 2→2 |
| Routing clarity | Simple | Ambiguous edges | Clear |
| Size of new skill | Very large | Focused | Moderate |

## What Perfect Code Looks Like

Each pattern below shows the **ideal expression** — what the call site should look like. The infrastructure that makes it possible is secondary. If the infrastructure doesn't exist, the instruction is: **build it**.

---

### Pattern 1: Typed Arithmetic — Write the Math, Not the Mechanism

**Perfect code** — the expression reads as intent:
```swift
let slot = currentCount.map(Ordinal.init)
base.initialization = .linear(count: currentCount + .one)
let remaining = count.subtract.saturating(.one)
let bitCount = _slots.popcount.retag(Element.self)
```

**Imperfect code** — mechanism leaks into the expression:
```swift
let slot = Index<Element>(__unchecked: (), Ordinal(currentCount.rawValue.rawValue + UInt(spanCount)))
let newCount = Index<Element>.Count(currentCount.rawValue + 1)
let count = Int(range.count.rawValue.rawValue)
```

**The principle**: If you find yourself chaining `.rawValue.rawValue`, that's not a call-site problem — it's a missing operator or overload. Add `Count + Count → Count`. Add `.map(Ordinal.init)` for `Count → Index`. Add `.retag()` for zero-cost domain crossing. The typed arithmetic vocabulary should be rich enough that raw extraction never appears in implementation code.

If you need an operator that doesn't exist, **add it to the infrastructure**.

---

### Pattern 2: Boundary Overloads — Push Int to the Edge

**Perfect code** — stdlib boundary is invisible:
```swift
unsafe destination.pointer(at: offset)
    .initialize(from: base.pointer(at: range.lowerBound), count: range.count)
```

**Imperfect code** — boundary conversion pollutes the call site:
```swift
let count = Int(range.count.rawValue.rawValue)
_ = unsafe withUnsafeMutablePointerToElements { src in
    let srcOffset = Index<Element>.Offset(fromZero: range.lowerBound)
    let srcStart = unsafe UnsafePointer(src + srcOffset)
    unsafe destination.withUnsafeMutablePointerToElements { dst in
        let dstOffset = Index<Element>.Offset(fromZero: dstStart)
        unsafe (dst + dstOffset).initialize(from: srcStart, count: count)
    }
}
```

**The principle**: `Int(bitPattern:)` is an implementation detail of the boundary between your type system and stdlib. It belongs inside an overload, never at the call site. If `UnsafeMutablePointer.initialize(from:count:)` only takes `Int`, write an overload that accepts `Index<Element>.Count`:

```swift
extension UnsafeMutablePointer {
    public func initialize(
        from source: UnsafePointer<Pointee>,
        count: Tagged<Pointee, Ordinal>.Count
    ) {
        self.initialize(from: source, count: Int(bitPattern: count))
    }
}
```

Now the call site is perfect. The `Int` conversion lives in one place, once, forever.

If the overload doesn't exist, **add it to the infrastructure** (e.g., affine-primitives stdlib integration).

---

### Pattern 3: Property Accessors — Express the Verb

**Perfect code** — the property IS the verb, methods qualify it:
```swift
heap.initialize(to: element, at: slot)     // direct operation
heap.initialize.next(to: element)          // tracked variant

heap.move(at: slot)                         // direct operation
heap.move.last()                            // tracked variant

heap.deinitialize(at: slot)                 // direct operation
heap.deinitialize.all()                     // tracked variant

heap.copy(range: range, to: dest)           // parameterized
heap.copy(to: dest)                         // all elements
heap.copy()                                 // clone
```

**Imperfect code** — hand-rolled accessor structs with boilerplate:
```swift
public struct Initialize: ~Copyable, ~Escapable {
    @usableFromInline let heap: Storage.Heap
    @inlinable @_lifetime(borrow heap)
    init(heap: borrowing Storage.Heap) { self.heap = copy heap }
    // ... methods
}
```

**The principle**: Use `Property<Tag, Base>` with `callAsFunction` so the accessor IS the verb. The tag type is an empty enum (`public enum Move {}`). Extensions on `Property` constrained by `where Tag == ..., Base == ...` provide the methods. `Property.View` handles `~Copyable` bases.

If `Property<Tag, Base>` doesn't support your use case, **extend the Property infrastructure**.

---

### Pattern 4: Expression-Oriented Construction — No Intermediate Variables

**Perfect code** — construct inline:
```swift
return try body(unsafe Span(
    _unsafeStart: pointer(at: range.lowerBound),
    count: Int(bitPattern: range.count)
))
```

**Imperfect code** — unnecessary intermediates:
```swift
try unsafe withUnsafeMutablePointerToElements { base throws(E) in
    let startOffset = Index<Element>.Offset(fromZero: range.lowerBound)
    let count = Int(bitPattern: range.count)
    let span = unsafe Span(
        _unsafeStart: UnsafePointer(base + startOffset),
        count: count
    )
    return try body(span)
}
```

**The principle**: When a `withUnsafe*` closure exists only to compute an offset and immediately pass it out, that's a missing `pointer(at:)` primitive. Add the primitive. Then the expression becomes a single construction.

If the primitive doesn't exist, **add it to the infrastructure**.

---

### Pattern 5: Enum Iteration — Express the Operation, Not the Structure

**Perfect code** — intent is clear:
```swift
header.initialization.forEach { range in
    deinitialize(range: range)
}

// With linear offset tracking:
base.initialization.linearize { range, offset in
    self(range: range, to: destination, at: offset)
}
```

**Imperfect code** — structure dominates:
```swift
switch header.initialization {
case .empty:
    return
case .one(let range):
    deinitialize(range: range)
case .two(let first, let second):
    deinitialize(range: first)
    deinitialize(range: second)
}
```

**The principle**: If you apply the same operation uniformly across enum cases, the `switch` is noise. Add `.forEach` to the enum. If you need offset tracking, add `.linearize`. The call site should express _what_ happens, not _how many variants exist_.

If the iteration method doesn't exist on the enum, **add it**.

---

### Pattern 6: Range Transformation — One Expression, Not a Loop

**Perfect code** — one expression:
```swift
_slots.set.range(range.map.bounds { $0.retag(Bit.self) })
```

**Imperfect code** — manual loop:
```swift
var slot = range.lowerBound
while slot < range.upperBound {
    _slots[Bit.Index(slot.rawValue)] = true
    slot = slot.successor.saturating()
}
```

**The principle**: `range.map.bounds { }` transforms both bounds in one expression. `.retag()` handles the phantom type change. `set.range()` handles the bulk operation. Each piece is reusable. The composition expresses intent.

If `range.map.bounds` doesn't exist, **add it to range-primitives**. If `set.range()` doesn't exist, **add it to bit-vector-primitives**.

---

### Pattern 7: Typed Throws Over Preconditions

**Perfect code** — recoverable:
```swift
guard slot < base.slotCapacity else { throw .capacityExceeded }
guard currentCount > .zero else { throw .empty }
```

**Imperfect code** — crashes:
```swift
precondition(slot.rawValue < heap.slotCapacity.rawValue, "Storage capacity exceeded")
precondition(currentCount > .zero, "Cannot move.last() from empty storage")
```

**The principle**: The boundary is clear — can the caller reasonably check the condition before calling? If yes → typed throw. If it's a pure programming error (violated invariant) → precondition. High-level tracked operations (`initialize.next`, `move.last`) throw. Low-level primitives (`pointer(at:)`, `initialize(to:at:)`) precondition.

Note the comparison itself: `slot < base.slotCapacity` compares typed values directly. No `.rawValue` extraction. If `<` doesn't exist between `Index` and `Count`, **add the operator**.

---

### Pattern 8: Comparison Uses Typed Values

**Perfect code**:
```swift
guard slot < base.slotCapacity else { throw .capacityExceeded }
guard currentCount > .zero else { throw .empty }
guard !range.isEmpty else { return }
```

**Imperfect code**:
```swift
precondition(slot.rawValue < heap.slotCapacity.rawValue, "...")
precondition(currentCount.rawValue.rawValue > 0, "...")
guard range.count.rawValue.rawValue > 0 else { return }
```

**The principle**: Typed values compare with typed values. `Index < Count`, `Count > .zero`, `Range.isEmpty`. If a comparison operator doesn't exist between two related types, **add it**. The call site should never extract raw values just to compare.

---

## The Infrastructure Improvement Loop

The skill should encode this workflow explicitly:

```
1. Write the ideal expression at the call site
2. Does it compile?
   ├─ Yes → done
   └─ No → what's missing?
       ├─ Is the absence principled?
       │   ├─ Yes → rethink the expression (see "Principled Absences" below)
       │   └─ No → add to the infrastructure:
       │       ├─ Missing operator (e.g., Count + Count)     → add to arithmetic primitives
       │       ├─ Missing overload (e.g., initialize(count:)) → add to stdlib integration
       │       ├─ Missing accessor (e.g., pointer(at:))       → add to the type
       │       ├─ Missing iteration (e.g., .forEach)           → add to the enum
       │       └─ Missing transformation (e.g., .map.bounds)   → add to range-primitives
3. After improving infrastructure, the ideal expression compiles
4. All other call sites also benefit from the improvement
```

This is the opposite of "work around what exists." Every call site should look like it was written against a perfect API. When it can't, that's *either* a gap in the infrastructure *or* a signal that your expression violates a design principle. Learning to distinguish the two is essential.

### Principled Absences

Not every missing operator or overload is a gap. Some things are intentionally absent because adding them would violate mathematical or type-theoretic foundations. When the ideal expression you imagined doesn't compile, ask: **is the type system telling me something?**

**Absence is principled when it prevents a mathematical error:**

| You want to write | Why it doesn't exist | What to write instead |
|---|---|---|
| `count - count` with `-` | Subtraction on naturals isn't total. `Cardinal - Cardinal` can underflow. No `-` operator exists because it would lie about totality. | `count.subtract.saturating(other)` or `try count.subtract.exact(other)` |
| `index * 2` | Indices are ordinals (positions in an affine space). Scaling a position is meaningless — you can only displace it. No `*` on `Index`. | Rethink: do you mean `offset * 2`? Or a stride? Express the actual operation. |
| `count * count` | Cardinals measure quantity. Multiplying two quantities of the same dimension produces a different dimension (area, not length). Dimensionless scaling uses `Ratio`. | `count.scale(by: ratio)` or use the appropriate cross-domain operation. |
| `pointer + count` | Pointers live in an affine space. You add *vectors* (offsets) to points, not scalars (counts). | `pointer + offset` where offset is computed from the count via the appropriate conversion. |
| `Index(rawValue: 5)` as public API | Bypasses the type's invariants. Public `init(rawValue:)` on phantom-typed wrappers would let anyone construct invalid states. | Use the designated constructor, literal conformance (in tests), or `__unchecked` (in same-package implementation). |

**Absence is a gap when the operation is mathematically sound but not yet provided:**

| You want to write | Why it should exist | Where to add it |
|---|---|---|
| `count + .one` | `Cardinal + Cardinal → Cardinal` is total and well-defined. | cardinal-primitives |
| `pointer.initialize(from:count: typedCount)` | The operation is valid; only the `Int` bridge is missing. | affine-primitives stdlib integration |
| `range.map.bounds { transform }` | Mapping both bounds preserves range semantics. | range-primitives |
| `bitVector.popcount.retag(Element.self)` | Retag is zero-cost phantom type change — always valid. | Already exists (identity-primitives) |

**The test**: Does the operation preserve the mathematical properties of the types involved? If adding the operator would make a partial operation look total, or mix dimensions, or violate affine space rules — the absence is a feature, not a bug. Rethink the expression.

## Outcome

**Status**: SUPERSEDED (2026-03-10)
**Superseded by**: **implementation** skill [IMPL-*]
This research was absorbed into the implementation skill. It remains as historical rationale.

**Previous Status**: IN_PROGRESS

**Recommendation**: Option C — merge anti-patterns into a new `implementation` skill, keep `conversions` as the mechanical type reference.

**Rationale**:
1. `conversions` answers "what types exist, how do they convert?" — a reference document.
2. `implementation` answers "how do I write perfect code?" — a design philosophy with concrete patterns.
3. Anti-patterns are naturally the "imperfect" side of each pattern.
4. The core principle (call-site-first, improve infrastructure) unifies all 8 patterns under one idea.

**Proposed Structure for Implementation Skill**:

| Section | IDs | Content |
|---------|-----|---------|
| Core Principle | IMPL-000 | Call-site-first design, infrastructure improvement loop |
| Typed Arithmetic | IMPL-001–004 | .map, .retag, Count+Count, subtract.saturating, comparisons |
| Boundary Overloads | IMPL-010–013 | pointer(at:), typed initialize/deinitialize/allocate, Int absorption |
| Property Accessors | IMPL-020–023 | Property\<Tag,Base\>, Property.View, callAsFunction, verb-as-property |
| Expression Style | IMPL-030–033 | Inline construction, intermediate elimination, withUnsafe replacement |
| Enum Iteration | IMPL-040–041 | .forEach, .linearize, uniform-operation-over-cases |
| Error Strategy | IMPL-050–051 | Typed throws vs preconditions boundary |
| Absorbed Anti-Patterns | PATTERN-009–021 | All current anti-patterns, reframed as "imperfect" examples |

**Proposed ID Prefix**: `IMPL-` (distinct from `API-IMPL-` used by code-organization).

**Supersedes**: `anti-patterns` skill (PATTERN-009–021 absorbed into implementation).

**Complements**: `conversions` skill (remains canonical for IDX-*, CONV-* rules).

**Next Steps**:
1. Review this research with the architect
2. If approved, create the skill per [SKILL-CREATE-*] process
3. Mark `anti-patterns` as SUPERSEDED, pointing to the new skill
4. Update CLAUDE.md skill routing table

## References

- Commit `e54c6b6` in swift-storage-primitives — exemplar refactor
- `Property_Primitives` package — Property\<Tag, Base\>, Property.View types
- `UnsafeMutablePointer+Tagged.Ordinal.swift` in swift-affine-primitives — boundary overloads
- `conversions` skill — IDX-*, CONV-* requirement IDs
- `anti-patterns` skill — PATTERN-009–021 requirement IDs
- `errors` skill — API-ERR-001 typed throws
- `naming` skill — API-NAME-001 namespace structure
