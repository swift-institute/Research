# Principled Absence — `RawRepresentable`

<!--
---
version: 1.1.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

<!--
Changelog:
- v1.1.0 (2026-04-30, same-day correction): empirical experiment surfaced
  a STRUCTURAL blocker — `RawRepresentable` is not `~Escapable`-aware, so
  Tagged's structural `~Escapable` declaration propagates through the
  synthesized `rawValue` getter witness regardless of constraint shape.
  Reclassified from SOFT (SLI-eligible) to HARD (not authorable even on
  opt-in). Consumer alternative: domain-specific wrapper struct owning
  its own conformance + validation.
- v1.0.0 (2026-04-30): initial classification as SOFT — superseded
  in-day by v1.1.0 empirical finding.
-->

## Context

`pointfreeco/swift-tagged` declares `Tagged<Tag, RawValue>: RawRepresentable` unconditionally, with `RawValue.RawValue == RawValue` and the synthesized failable `init?(rawValue:)`. The fork-precedent package therefore sets the consumer expectation that `Tagged` is a stdlib raw-representable type.

Swift Institute's `swift-tagged-primitives` deliberately removes this conformance. The removal is non-obvious and hits consumers familiar with `pointfreeco/swift-tagged`; this document establishes the rationale, classifies the absence as **hard** (not authorable even on opt-in due to a structural Swift-level blocker), and points at the empirical demonstration in `Experiments/tagged-no-rawrepresentable/`.

**Trigger**: User direction 2026-04-30 — "fresh /research-process and /experiment-process for each of the protocol conformances we now 'Principled absence'." This is the per-protocol depth above the §3.1 entry in [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md).

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` conform to `RawRepresentable`? If absent by default, what is the legitimate opt-in path?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.1 — the original removal rationale (one paragraph).
- [`tagged-types-merits-completeness-and-naming.md`](./tagged-types-merits-completeness-and-naming.md) — establishes the design philosophy that informs this decision.
- [`external-upstream-fork-heritage.md`](../../../swift-institute/Research/external-upstream-fork-heritage.md) `[HERITAGE-006]` — codifies "principled absence" as a recognizable shape; this document is one instance.
- Swift Evolution [SE-0155](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0155-normalize-enum-case-representation.md) (synthesized `RawRepresentable` for raw-value enums) and the `RawRepresentable` declaration in the stdlib.

## Analysis

### Option A — Conform unconditionally (pointfreeco pattern)

```swift
extension Tagged: RawRepresentable {
    public typealias RawValue = Underlying        // aliases the generic parameter
    public init?(rawValue: Underlying) {          // failable init
        self.init(_unchecked: rawValue)
    }
}
```

**Pros**:
- Drop-in compatibility with stdlib `RawRepresentable` consumers — `EnumWithTag.init?(rawValue:)` patterns work immediately.
- Broad ecosystem familiarity — `RawRepresentable` is the canonical stdlib protocol for "wrapping a raw value."

**Cons**:

1. **Failable init implies failability semantics that don't apply.** `RawRepresentable.init?(rawValue:)` is failable because raw-representable enums constrain the raw value to a finite set (the enum's cases). `Tagged<Tag, Int>` does not constrain `Int` — every `Int` is a valid raw value. The failability is structurally vestigial; consumers calling `init?(rawValue:)` get an Optional that never returns `nil`, which is misleading API.

2. **`RawRepresentable` constrains `RawValue: Equatable & Hashable` (since Swift 5.5)**. Our `Tagged` admits `Underlying: ~Copyable & ~Escapable` — the `RawRepresentable` conformance would force `RawValue: Copyable` (and Equatable), defeating our `~Copyable` admission for the wide design space we admit.

3. **Conflates phantom-typing with raw-representation**. The phantom Tag is the discriminator; `RawRepresentable` implies the raw value IS the value (with a type alias for what it is "represented as"). The conformance suggests Tagged is "an enum-like wrapper," when it's actually a phantom-typed wrapper. Consumers reading the protocol-list see misleading framing.

### Option B — Conform via SLI opt-in (originally proposed; empirically blocked)

```swift
// In Sources/Tagged Primitives Standard Library Integration/Tagged+RawRepresentable.swift
import Tagged_Primitives

extension Tagged: RawRepresentable
where Tag: ~Copyable & ~Escapable, Underlying: Copyable & Equatable & Escapable {
    public typealias RawValue = Underlying
    public init?(rawValue: Underlying) {
        self.init(_unchecked: rawValue)
    }
}
```

**Empirical finding (2026-04-30, experiment `tagged-no-rawrepresentable`)**: this conformance does not compile. The diagnostic family on Swift 6.3.1:

```
<unknown>:0: error: the 'get' accessor cannot return a ~Escapable result
<unknown>:0: error: 'self' is borrowed and cannot be consumed
<unknown>:0: error: lifetime-dependent variable 'self' escapes its scope
```

Three constraint shapes were tried (see `Experiments/tagged-no-rawrepresentable/reject-test-conformance.swift.txt` for the empirical capture):

1. `Tag: ~Copyable & ~Escapable, Underlying: Copyable & Equatable`
2. `Tag: ~Copyable & ~Escapable, Underlying: Copyable & Equatable & Escapable`
3. `Tag: Copyable & Escapable, Underlying: Copyable & Equatable & Escapable`

All three produce the same diagnostic family. The structural blocker: `RawRepresentable` is not `~Escapable`-aware; its `var rawValue: RawValue { get }` requirement implicitly assumes a non-`~Escapable` accessor. Tagged's structural `~Escapable` declaration on the base struct (`public struct Tagged<...>: ~Copyable, ~Escapable`) propagates through the synthesized `rawValue` getter witness regardless of constraint shape on the conformance extension. The conformance is not authorable — not on the main target, not on SLI opt-in, not on any constraint refinement.

**Conclusion**: Option B is structurally infeasible on Swift 6.3.1.

### Option C — Hard absence + consumer wrapper alternative (DECISION)

**Pros**:
- Unambiguous default and opt-in semantics: Tagged is never a raw-representable wrapper.
- Avoids the failable-init misleadingness entirely.
- Honestly encodes the structural reality discovered in the experiment.
- Pushes domain validation (failable-init's legitimate role) to the consumer's domain wrapper, where it belongs.

**Cons**:
- Some consumer use cases legitimately want stdlib-protocol interop (decoder strategies, `OptionSet`-adjacent patterns). Consumers must roll their own conformance per domain — boilerplate per type.
- The interop loss is real: stdlib APIs that constrain `T: RawRepresentable` are unavailable to Tagged consumers without per-domain conformance.

**Consumer alternative (verified in experiment)**:

```swift
struct UserID: RawRepresentable, Equatable {
    private let storage: Tagged<User, Int>

    init?(rawValue: Int) {
        guard rawValue >= 0 else { return nil }     // domain validation here
        self.storage = Tagged<User, Int>(rawValue)
    }

    var rawValue: Int { storage.underlying }
}
```

The consumer wrapper:
1. Owns the `RawRepresentable` conformance on its own terms.
2. Implements meaningful failable-init validation (here: non-negative IDs).
3. Forwards storage to `Tagged` for the phantom-typing benefit.
4. Compiles cleanly because the wrapper itself is a regular Copyable+Escapable struct.

This is the canonical pattern — domain validation belongs at the wrapper level; Tagged is the storage substrate.

### Comparison

| Criterion | A. Unconditional | B. SLI opt-in | C. Hard absence + consumer wrapper |
|---|:---:|:---:|:---:|
| Default safety (avoids misleading semantics in main import) | ✗ | ✓ | ✓ |
| Stdlib RawRepresentable interop available | ✓ | (would be via SLI) | ✓ (via consumer wrapper) |
| Preserves `~Copyable` / `~Escapable` admission in main | ✗ | ✓ | ✓ |
| Avoids name collision between `Tagged.Underlying` (generic) and `RawRepresentable.RawValue` (associated) | ✓ (post-rename, no collision) | ✓ | ✓ |
| Failable-init meaningful (validates domain, not always-succeeds) | ✗ | ✗ | ✓ |
| **Compiles on Swift 6.3.1** | ✓ | **✗ (empirically blocked)** | ✓ |
| Consumer friction | None | (would be one import) | One wrapper struct per domain |

Option A's combined cost (semantic misleading × `~Copyable` blocker × name collision × phantom-vs-raw-representation conflation) is too high for the default. Option B was originally proposed but is structurally infeasible. Option C is the only authorable path that preserves the safety-first default; the consumer-wrapper friction is real but bounded (one struct per domain, with the bonus of meaningful domain validation).

## Outcome

**Status**: DECISION — Option C (Hard absence + consumer wrapper alternative).

`Tagged<Tag, Underlying>: RawRepresentable` is **absent from the main target**, **not authorable in any opt-in form** (including via SLI) due to a structural Swift-level blocker on Swift 6.3.1. Consumers who want stdlib-`RawRepresentable` interop author a domain-specific wrapper struct (canonical pattern verified in the experiment).

**Soft / Hard classification**: **HARD** absence — not eligible for SLI. The conformance is structurally infeasible regardless of consumer intent.

**Empirical verification**: [`Experiments/tagged-no-rawrepresentable/`](../Experiments/tagged-no-rawrepresentable/) demonstrates (a) the structural absence — three different conformance attempts (varying constraint shape on Tag and Underlying) all fail to compile with the same diagnostic family captured in `reject-test-conformance.swift.txt`; (b) the consumer alternative — a domain-specific `UserID` wrapper struct that owns its own `RawRepresentable` conformance, performs meaningful domain validation (non-negative IDs), forwards storage to `Tagged`, and round-trips through `init?(rawValue:) → rawValue → init?(rawValue:)` cleanly. Stdlib RawRepresentable-constrained APIs work on the consumer wrapper.

**Forward-compatibility note**: if a future Swift version makes `RawRepresentable` `~Escapable`-aware (or makes the synthesized witness for stored properties on `~Escapable` types compatible with non-`~`-aware protocols), this rule SHOULD be revisited. The structural blocker is empirically tied to the 6.3.1 toolchain; the rule's content should follow the language.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.1 (the seed paragraph).
- [`external-upstream-fork-heritage.md`](../../../swift-institute/Research/external-upstream-fork-heritage.md) `[HERITAGE-006]` (negative-space framing for principled absences).
- [Swift stdlib `RawRepresentable`](https://developer.apple.com/documentation/swift/rawrepresentable) — the conformance target.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) `extension Tagged: RawRepresentable`.
