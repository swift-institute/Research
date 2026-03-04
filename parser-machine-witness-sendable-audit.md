# Parser.Machine.Compile.Witness Sendable Audit

<!--
---
version: 1.0.0
last_updated: 2026-03-04
status: RECOMMENDATION
tier: 1
---
-->

## Context

`Parser.Machine.Compile.Witness<P>` is a struct-with-closure type in `swift-parser-machine-primitives` (tier 20) that encapsulates parser compilation logic. It stores a single `@escaping` closure (`_compile`) that transforms a parser value and a mutable builder reference into a `Machine.Expression`. The type is used exclusively within compilation pipelines -- passed to `Compiled.init` and `Prepared.init` to drive lazy or eager compilation of parsers into defunctionalized Machine programs.

During a broader witness infrastructure review, the question arose: should `Compile.Witness` conform to `Witness.Protocol` (the marker protocol from `swift-witness-primitives`, tier 2), and what Sendable implications exist?

**Trigger**: Design audit of witness-pattern types across primitives.

## Question

Should `Parser.Machine.Compile.Witness<P>` conform to `Witness.Protocol`, and what are the Sendable constraints and implications?

## Analysis

### Structure of `Compile.Witness`

File: `/Users/coen/Developer/swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Compile.Witness.swift`

```swift
public struct Witness<P: Parser.Protocol>
where P.Input: Parser.Input & Sendable,
      P.ParseOutput: Sendable,
      P.Failure: Sendable
{
    @usableFromInline
    let _compile: (P, inout Parser.Machine.Builder<P.Input, P.Failure>)
        -> Parser.Machine.Expression<P.Input, P.Failure, P.ParseOutput>

    @inlinable
    public init(
        compile: @escaping (P, inout Parser.Machine.Builder<P.Input, P.Failure>)
            -> Parser.Machine.Expression<P.Input, P.Failure, P.ParseOutput>
    ) {
        self._compile = compile
    }
}
```

Single stored property: one non-`@Sendable` closure. No mutable state. No reference-type storage.

### Sendable Analysis

1. **The closure is NOT `@Sendable`**: `_compile` has no `@Sendable` annotation. The type cannot structurally prove `Sendable` without either (a) marking the closure `@Sendable`, or (b) using `@unchecked Sendable`.

2. **The closure captures parser-related values**: Compilation witnesses typically capture nothing (e.g., the `.leaf` static factory creates the closure inline). Custom witnesses may capture parser-specific state.

3. **Usage is single-domain**: `Compile.Witness` is consumed during compilation:
   - `Compiled.init(source:witness:)` stores the witness for lazy compilation.
   - `Prepared.init(source:witness:)` calls `witness.compile` immediately and discards the witness.
   - Neither `Compiled` nor `Prepared` declares `Sendable` conformance.
   - No evidence of cross-task sharing, actor storage, or task-local usage.

4. **`Compiled` is explicitly NOT Sendable**: The `Compiled` wrapper documents: "NOT Sendable. Use within a single isolation domain." It stores a reference-type `Cache` with mutable state.

5. **`Prepared` is explicitly NOT Sendable**: Despite documentation suggesting conditional Sendable, the actual code comment at lines 91-95 says: "Prepared does NOT conform to Sendable because the underlying Machine.Program contains closures that may not be Sendable."

6. **The `.leaf` factory requires `P: Sendable`**: The only built-in witness factory is constrained to `where P: Sendable`, because `Machine.leaf` captures the parser value into a `@Sendable` closure for the Machine program's leaf nodes.

### Option A: Conform to `Witness.Protocol` Now

**Description**: Add `Witness.Protocol` conformance to `Parser.Machine.Compile.Witness`. This requires adding `swift-witness-primitives` as a dependency to `Parser Machine Compile Primitives`.

**Advantages**:
- Semantic accuracy: `Compile.Witness` IS a protocol witness (struct-with-closures representing a capability).
- Discoverability: tools and documentation can find all witness types via the marker protocol.
- Consistency: other witness types in the ecosystem conform.

**Disadvantages**:
- **New dependency**: `Parser Machine Compile Primitives` currently depends only on `Parser Machine Core Primitives` and `Machine Primitives`. Adding `swift-witness-primitives` (tier 2) introduces a new package dependency. While tier 2 is far below tier 20 (no tier violation), it adds a dependency to a currently self-contained compilation module.
- **Witness Primitives depends on Dependency Primitives**: The transitive closure includes `swift-dependency-primitives`, which is the DI infrastructure. This is conceptual weight for a compilation type that has no DI use case.
- **Low concrete benefit**: `Witness.Protocol` is a pure marker protocol with zero requirements. Conformance enables `any Witness.Protocol` existential usage and generic constraints, but there is no evidence anyone uses `Compile.Witness` in such contexts.

### Option B: Do Not Conform

**Description**: Leave `Compile.Witness` as-is. It uses the witness pattern without formally conforming to `Witness.Protocol`.

**Advantages**:
- Zero dependency change.
- The type already follows the witness pattern; the marker adds no capability.
- Compilation module stays minimal and self-contained.

**Disadvantages**:
- Inconsistency with ecosystem convention if other witness types conform.
- Cannot be discovered via `Witness.Protocol` constraint.

### Option C: Conform When Dependency Already Exists

**Description**: Defer conformance until `swift-parser-machine-primitives` already depends on `swift-witness-primitives` for another reason (e.g., umbrella re-export, or another type needs it). At that point, conformance is free.

**Advantages**:
- Avoids premature dependency introduction.
- Gets the benefit when the cost is zero.
- Pragmatic and non-blocking.

**Disadvantages**:
- No timeline guarantee.

### Sendable Conformance Assessment

Regardless of `Witness.Protocol`, should `Compile.Witness` be `Sendable`?

| Factor | Assessment |
|--------|-----------|
| Stored closure is `@Sendable`? | No |
| Used across concurrency domains? | No evidence |
| Consumers (`Compiled`, `Prepared`) are `Sendable`? | No |
| Would adding `@Sendable` to closure break existing call sites? | Possibly -- custom witnesses with non-Sendable captures would fail |
| Is there demand for cross-task witness sharing? | No -- compilation is a setup-time operation |

**Conclusion on Sendable**: Adding `Sendable` to `Compile.Witness` is not justified. The type's entire lifecycle is within a single compilation pipeline. The `.leaf` factory already requires `P: Sendable` for the Machine leaf closure, but that is a downstream constraint of the Machine program, not of the witness itself.

### Comparison

| Criterion | Option A: Conform Now | Option B: No Conform | Option C: Deferred |
|-----------|-----------------------|----------------------|--------------------|
| Semantic accuracy | High | Medium (uses pattern, no marker) | High (eventual) |
| Dependency cost | New package dep + transitive | None | None (until triggered) |
| Concrete benefit | Marker only | N/A | Marker only |
| Risk | Low (marker protocol) | None | None |
| Consistency with ecosystem | High | Acceptable | High (eventual) |
| Implementation effort | Trivial (~5 lines) | None | Trivial (when triggered) |

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option C -- defer `Witness.Protocol` conformance until `swift-witness-primitives` is already a dependency for another reason.

**Rationale**:

1. `Compile.Witness` semantically IS a protocol witness and would benefit from the marker conformance for ecosystem consistency.
2. However, adding a new package dependency (`swift-witness-primitives` + transitive `swift-dependency-primitives`) solely for a marker protocol with zero requirements provides negligible concrete value.
3. `Sendable` conformance is NOT recommended. The stored closure is not `@Sendable`, the type is used only within single-domain compilation pipelines, and neither consumer (`Compiled`, `Prepared`) is `Sendable`.
4. No tests need modification -- the existing test suite at `/Users/coen/Developer/swift-primitives/swift-parser-machine-primitives/Tests/Parser Machine Compile Primitives Tests/` covers compilation and prepared parsing but does not test Sendable or cross-task behavior (correctly, since neither applies).

**Next steps**:
- No immediate action required.
- When `Parser Machine Compile Primitives` adds `swift-witness-primitives` as a dependency for another reason, add `: Witness.Protocol` to `Compile.Witness` at that time.
- Do not add `@Sendable` to the `_compile` closure or `Sendable` to `Compile.Witness` unless a concrete cross-task compilation use case emerges.
- If the ecosystem adopts a convention of auditing all witness-pattern types for `Witness.Protocol` conformance, revisit this document.

## References

- `Witness.Protocol` definition: `/Users/coen/Developer/swift-primitives/swift-witness-primitives/Sources/Witness Primitives/Witness.Protocol.swift`
- `Compile.Witness` source: `/Users/coen/Developer/swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Compile.Witness.swift`
- `Compiled` source: `/Users/coen/Developer/swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Compiled.swift`
- `Prepared` source: `/Users/coen/Developer/swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Prepared.swift`
- Related research: `/Users/coen/Developer/swift-institute/Research/witness-noncopyable-nonescapable-support.md`
- Primitives tier map: `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Tiers.md` (parser-machine at tier 20, witness at tier 2)
