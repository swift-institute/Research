# Principled Absence — Foundation-Dependent Conformances (`LocalizedError`, `UUID` Convenience Inits)

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

## Context

`pointfreeco/swift-tagged` provides several conformances and convenience inits that require `import Foundation`:

```swift
#if canImport(Foundation)
import Foundation

extension Tagged: LocalizedError where Underlying: LocalizedError {
    public var errorDescription: String? { underlying.errorDescription }
    public var failureReason: String? { underlying.failureReason }
    // ...
}

extension Tagged where Underlying == UUID {
    public init() { self.init(underlying: UUID()) }
}
#endif
```

Swift Institute's `swift-tagged-primitives` deliberately removes both. The argument is **Foundation-independence**: per `[PRIM-FOUND-001]`, primitives-layer packages MUST NOT import Foundation. This is a structural axiom of the Institute primitives layer — Foundation is a Layer-3+ dependency, not a Layer-1 primitive.

`LocalizedError` is declared in `Foundation` (not stdlib). `UUID` is a `Foundation` type. Any conformance involving these requires `import Foundation`, which is structurally forbidden in this package.

This document treats both absences together because the rationale is identical: Foundation dependency at the type / protocol level.

**Trigger**: Per-protocol absence work directed by user 2026-04-30. Per [RES-001].

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` conform to `LocalizedError` (when `Underlying: LocalizedError`)? Should it have UUID convenience inits (when `Underlying == UUID`)? If absent by default, what is the legitimate opt-in path?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.7 (`Error` / `LocalizedError`) and §5 (UUID inits table row) — original removal rationale.
- `[PRIM-FOUND-001]` — Foundation-independence axiom for primitives. Verified at audit time: zero `import Foundation` in this package's `Sources/`, `Tests/`, or `Package.swift`.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) `#if canImport(Foundation)` block.

## Analysis

### Option A — Conform under `#if canImport(Foundation)` (pointfreeco pattern)

```swift
#if canImport(Foundation)
import Foundation

extension Tagged: LocalizedError where Underlying: LocalizedError { ... }
extension Tagged where Underlying == UUID { public init() { ... } }
#endif
```

**Pros**:
- Drop-in `LocalizedError` and `UUID()` convenience for environments that import Foundation.

**Cons**:
1. **Violates `[PRIM-FOUND-001]`**. The Institute primitives layer is Foundation-independent by axiom; even guarded-by-canImport conditional imports introduce a soft dependency on Foundation that downstream consumers may inherit through `@_exported`-adjacent module-graph effects.
2. **Couples the package's correctness to Foundation availability**. Embedded Swift environments (where Foundation is unavailable) may fail to compile; cross-platform stories diverge.
3. **The Foundation conformance is largely consumer-trivial**. If the consumer's environment has Foundation, they can author the conformance themselves with no boilerplate beyond what we'd ship.

### Option B — SLI opt-in with Foundation guard

The same `#if canImport(Foundation)` shape, but in the SLI module instead of main. Even this is rejected, because SLI is also part of the Institute primitives layer and inherits `[PRIM-FOUND-001]`. The Institute does NOT ship Foundation conformances at any layer below Foundations.

### Option C — Hard absence + consumer-side conformance

```swift
// Consumer's package imports Foundation for its own reasons:
import Foundation
import Tagged_Primitives

// Consumer authors per-domain conformance:
extension MyDomainError: LocalizedError where Storage: LocalizedError { ... }

// Consumer authors UUID convenience init:
extension Tagged where Underlying == UUID {
    public init() { self.init(_unchecked: UUID()) }
}
```

**Pros**:
- Foundation dependency lives at the consumer's package level, where it's appropriate (Foundations layer or Components layer or Application layer).
- Institute primitives stays Foundation-free.
- Consumer authoring is trivial — single-line extension.

**Cons**:
- Consumer must author the conformance themselves. (Mitigated: it's one-line, and the consumer's package already imports Foundation for its own reasons.)

## Empirical verification

[`Experiments/tagged-no-foundation-protocols/`](../Experiments/tagged-no-foundation-protocols/) verifies (a) the package is Foundation-free; (b) attempting to use LocalizedError requires `import Foundation`; (c) the consumer-side conformance pattern works when consumers import Foundation themselves.

## Outcome

**Status**: DECISION — Option C (hard absence; consumer-side conformance when desired).

`Tagged<Tag, Underlying>: LocalizedError` and `Tagged where Underlying == UUID` convenience inits are **absent from main AND from SLI**. The Institute primitives layer does not ship Foundation conformances at any layer.

**Soft / Hard classification**: **HARD-BY-AXIOM** — `[PRIM-FOUND-001]` forbids Foundation in primitives, regardless of consumer intent. Consumers who want these conformances author them at their own layer.

**Forward-compatibility note**: This rule is structural and toolchain-independent. As long as `[PRIM-FOUND-001]` holds for primitives-layer packages, this absence is permanent.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.7 + §5 (the seed paragraphs).
- `[PRIM-FOUND-001]` — Foundation-independence axiom (defined in `swift-institute/Skills/primitives/SKILL.md`).
- Apple Foundation [`LocalizedError`](https://developer.apple.com/documentation/foundation/localizederror) and [`UUID`](https://developer.apple.com/documentation/foundation/uuid).
- Pointfreeco swift-tagged source — `#if canImport(Foundation)` block in [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift).
