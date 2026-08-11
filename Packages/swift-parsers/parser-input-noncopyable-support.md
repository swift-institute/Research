# Parser Input ~Copyable and ~Escapable Support

<!--
---
version: 1.0.0
last_updated: 2026-03-16
status: DECISION
---
-->

## Context

**Trigger**: During the swift-parsers rewrite (aligning foundations-layer combinators with parser-primitives conventions), checkpoint/restore backtracking was replaced with copy-based backtracking (`let saved = input` / `input = saved`). This was questioned: the project intent is ~Copyable support as the *primary* design, with Copyable as secondary.

**Current state**:
- `Parser.Protocol.Input` is declared `associatedtype Input: ~Escapable` (implicitly Copyable)
- `Input.Protocol` (aliased as `Parser.Input`) IS `~Copyable` and provides checkpoint/restore API
- All 5 parser-primitives combinators (Peek, OneOf.Two, Many.Simple, Not, Optionally) use copy-based backtracking
- None use the checkpoint/restore API from `Input.Protocol`
- swift-parsers (foundations) generic combinators (Separated, Chain, Expression) were just converted to copy-based

**Experimental features available**:
- `SuppressedAssociatedTypes`: Enables `associatedtype Input: ~Copyable` — no defaulting (conformers must handle ~Copyable)
- `SuppressedAssociatedTypesWithDefaults` (SE-0503, accepted Feb 2026): Same, but primary associated types default to Copyable unless suppressed with `where Input: ~Copyable`

**Precedent**: sequence-primitives adopted `SuppressedAssociatedTypes` for `Element: ~Copyable` (DECISION, 2026-02-12)

## Question

How should `Parser.Protocol` and parser combinators (both primitives and foundations) support ~Copyable Input as the primary design, with Copyable as secondary?

Specifically:
1. Should `Parser.Protocol.Input` gain `~Copyable` (and if so, via which feature flag)?
2. What backtracking mechanism should combinators use?
3. How do Copyable input types (e.g., `Substring.UTF8View`) fit?

## Analysis

### Option A: Status Quo — Copyable Input Only

Keep `Parser.Protocol.Input: ~Escapable` (implicitly Copyable). All backtracking uses copy-based `let saved = input` / `input = saved`.

**Advantages**:
- Simplest implementation
- No feature flags required
- Works today, all tests pass
- `Substring.UTF8View` works directly

**Disadvantages**:
- Cannot support ~Copyable input types (e.g., `Input.Buffer`, linear cursors)
- `Input.Protocol` with its checkpoint/restore API exists but is architecturally disconnected from `Parser.Protocol`
- Contradicts the project intent of ~Copyable-first design

### Option B: SuppressedAssociatedTypes — ~Copyable Primary, Single Tier

Add `~Copyable & ~Escapable` to `Parser.Protocol.Input` using `SuppressedAssociatedTypes`. All combinators that need backtracking constrain `Input: Input.Protocol` and use checkpoint/restore exclusively.

```swift
// Parser.Protocol (primitives)
public protocol `Protocol`<Input, ParseOutput, Failure> {
    associatedtype Input: ~Copyable & ~Escapable
    // ...
}

// Backtracking combinator (example)
public struct Peek<Upstream: Parser.`Protocol`>
where Upstream.Input: Input.`Protocol` {
    // Uses: input.checkpoint / input.restore.to(checkpoint)
}
```

**Advantages**:
- ~Copyable-first: the protocol is designed around non-copyable input
- Consistent single mechanism: checkpoint/restore handles both Copyable and ~Copyable inputs
- Matches sequence-primitives precedent
- `Input.Protocol` is architecturally connected — checkpoint/restore is the backtracking API
- Migration to `WithDefaults` is additive (add Copyable-optimized overloads later)

**Disadvantages**:
- Requires `SuppressedAssociatedTypes` feature flag across all packages
- ALL backtracking combinators need `where Input: Input.Protocol`
- `Substring.UTF8View` needs an `Input.Protocol` conformance (via Standard Library Integration module) or wrapping in `Input.Slice`
- Known witness table SIGSEGV with cross-module ~Copyable types (test-level workaround exists)
- More constraints on generic combinators than Option A

### Option C: SuppressedAssociatedTypesWithDefaults — Tiered Approach

Add `~Copyable & ~Escapable` to `Parser.Protocol.Input` using `SuppressedAssociatedTypesWithDefaults` (SE-0503). Provide two tiers of combinators:

1. **Default (Copyable) tier**: copy-based backtracking, no extra constraints
2. **~Copyable tier**: checkpoint-based backtracking with `where Input: ~Copyable, Input: Input.Protocol`

```swift
// Default tier (Copyable — inferred automatically)
extension Parser.`Protocol` where Self: Sendable {
    func peek() -> Parser.Peek<Self> { ... }  // Uses let saved = input
}

// ~Copyable tier (explicit constraint suppression)
extension Parser.`Protocol` where Self: Sendable, Input: ~Copyable, Input: Input.`Protocol` {
    func peek() -> Parser.Peek.NoncopyableInput<Self> { ... }  // Uses checkpoint/restore
}
```

**Advantages**:
- Both paths work cleanly
- Existing Copyable code continues unchanged
- Optimized path for Copyable inputs (copy is simpler than checkpoint)
- ~Copyable path available for move-only cursors

**Disadvantages**:
- Requires SE-0503 (accepted, but toolchain availability uncertain)
- Duplicated combinator logic: each backtracking combinator needs two implementations
- More complex API surface — users must understand which tier they're in
- Naming challenge: `Peek` vs `Peek.NoncopyableInput` (or similar)

### Option D: Checkpoint-Only, Retain Copyable Input

Keep `Parser.Protocol.Input: ~Escapable` (Copyable) but switch all backtracking to checkpoint/restore. Backtracking combinators add `where Input: Input.Protocol`.

```swift
// Parser.Protocol — Input stays implicitly Copyable
public protocol `Protocol`<Input, ParseOutput, Failure> {
    associatedtype Input: ~Escapable  // No change
    // ...
}

// Combinators require Input.Protocol for checkpoint/restore
public struct Peek<Upstream: Parser.`Protocol`>
where Upstream.Input: Input.`Protocol` {
    // Uses: input.checkpoint / input.restore.to(checkpoint)
}
```

**Advantages**:
- No feature flags required
- checkpoint/restore mechanism established for future ~Copyable transition
- When `SuppressedAssociatedTypes` is adopted later, only `Parser.Protocol` declaration changes — combinators already use checkpoint/restore

**Disadvantages**:
- Input is still implicitly Copyable — does not fulfill ~Copyable-primary intent
- All combinators need `where Input: Input.Protocol` even though Input is Copyable
- `Substring.UTF8View` needs `Input.Protocol` conformance
- Checkpoint/restore is more complex than copy for Copyable types
- Half-measure: protocol is Copyable but mechanism is ~Copyable

### Comparison

| Criterion | A: Status Quo | B: Suppressed Single | C: WithDefaults Tiered | D: Checkpoint Only |
|-----------|---------------|---------------------|----------------------|-------------------|
| ~Copyable-primary intent | No | **Yes** | Yes | No |
| Copyable support | **Native** | Via conformance | **Native + optimized** | Via conformance |
| Feature flag required | None | SuppressedAT | SE-0503 | None |
| Toolchain availability | **Today** | **Today** | Uncertain | **Today** |
| Backtracking mechanism | Copy | Checkpoint/restore | Both (tiered) | Checkpoint/restore |
| `Substring.UTF8View` | **Direct** | Needs SLI/wrapping | **Direct** (default tier) | Needs SLI/wrapping |
| Combinator complexity | **Minimal** | Moderate | High (dual logic) | Moderate |
| Migration cost | None | Medium | Low → additive | Low |
| Future-proof | No | **Yes** | **Yes** | Partial |
| Precedent alignment | — | sequence-primitives | — | — |
| SIGSEGV risk | None | **Known bug** | **Known bug** | None |

## Constraints

1. **Witness table SIGSEGV**: Cross-module ~Copyable witness tables crash at runtime in Swift 6.2.3. Workaround: local wrapper types in tests. This affects Options B and C when used with cross-module concrete types.

2. **SE-0503 availability**: `SuppressedAssociatedTypesWithDefaults` is accepted but may not be in current toolchains. `SuppressedAssociatedTypes` (without defaults) IS available today.

3. **Standard Library Integration**: `Substring.UTF8View` does not conform to `Input.Protocol`. Options B and D require either:
   - An SLI module providing `extension Substring.UTF8View: Input.Protocol`
   - Users wrapping in `Input.Slice` before parsing

4. **swift-parsers scope**: swift-parsers is at Layer 3 (Foundations). The `Parser.Protocol` change happens at Layer 1 (Primitives). These are coordinated but separate packages.

5. **Borrowing semantics**: With `SuppressedAssociatedTypes`, closure parameters accepting `Input` may need `borrowing` annotation (as sequence-primitives discovered). This is transparent at Copyable call sites.

## Prior Art

| Document | Key Finding |
|----------|------------|
| [sequence-primitives: ~Copyable elements](../../swift-primitives/swift-sequence-primitives/Research/sequence-protocol-noncopyable-elements.md) | DECISION: Adopt `SuppressedAssociatedTypes` now. `borrowing` closures transparent for Copyable callers. |
| [parser-primitives: witness table SIGSEGV](../../swift-primitives/swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md) | DECISION: Use local wrapper types in tests to avoid cross-module crash. |
| [suppressed-associatedtype domain unification](../../swift-institute/Research/Reflections/2026-02-13-suppressed-associatedtype-domain-unification.md) | `SuppressedAssociatedTypes` confirmed working. Unblocked Phase 2 domain unification. |
| [input-stream ~Copyable element](../../swift-institute/Research/Reflections/2026-02-13-input-stream-noncopyable-element.md) | Documents constraint cascade when `Input.Stream.Protocol.Element: ~Copyable`. |
| [parser-primitives: suppressed ~Escapable experiment](../../swift-primitives/swift-parser-primitives/Experiments/suppressed-escapable-associated-types/) | V1-V5,V7 confirmed: `associatedtype Input: ~Escapable` and `~Copyable & ~Escapable` compile. V6 refuted: cannot return ~Escapable from protocol method. |

## Outcome

**Status**: DECISION

**Decision** (2026-03-16): **Option B — SuppressedAssociatedTypes, ~Copyable primary, single tier** chosen, with a phased rollout.

### Rationale

1. **Intent alignment**: The project explicitly wants ~Copyable as primary. Option B is the only option that fulfills this intent immediately.

2. **Precedent**: sequence-primitives already adopted the same approach for `Element: ~Copyable`. The pattern is proven.

3. **Architectural coherence**: `Input.Protocol` exists specifically to provide checkpoint/restore for ~Copyable inputs. Making `Parser.Protocol.Input: ~Copyable` and using checkpoint/restore as THE backtracking mechanism connects these two protocols architecturally.

4. **Single mechanism**: One backtracking mechanism (checkpoint/restore) is simpler than two (checkpoint + copy). The `Input.Protocol` checkpoint API works for both Copyable and ~Copyable inputs — Copyable inputs still have checkpoints.

5. **Migration path**: When `SuppressedAssociatedTypesWithDefaults` ships, the migration is additive: add copy-based Copyable-optimized overloads as a second tier. No breaking changes required.

6. **Option C rejected**: SE-0503 toolchain availability is uncertain. Option B works today with the available feature flag. The tiered approach also doubles combinator implementation effort for marginal benefit (checkpoint/restore is O(1) for both Copyable and ~Copyable `Input.Slice`/`Input.Buffer`).

7. **Option D rejected**: Half-measure. If we're switching to checkpoint/restore anyway, making Input ~Copyable at the same time is the consistent choice. The `SuppressedAssociatedTypes` flag is already proven in sequence-primitives.

### Implementation Plan

#### Phase 1: Primitives (`swift-parser-primitives`)

1. Add `SuppressedAssociatedTypes` to Package.swift swift settings
2. Change `Parser.Protocol.Input` from `~Escapable` to `~Copyable & ~Escapable`
3. Convert all 5 backtracking combinators (Peek, OneOf.Two, Many.Simple, Not, Optionally) from copy-based to checkpoint/restore
4. Add `where Input: Input.Protocol` constraint to combinators that need backtracking
5. Non-backtracking parsers (Map, Filter, FlatMap, etc.) need no constraint changes
6. Update test support: verify local `TestBytes` wrapper still works (SIGSEGV workaround)

#### Phase 2: Foundations (`swift-parsers`)

1. Add `SuppressedAssociatedTypes` to Package.swift swift settings
2. Revert copy-based backtracking in Separated, Chain, Expression to checkpoint/restore
3. Add `where Input: Parser.Input` constraint to these combinators
4. Concrete parsers (Comment, Integer) keep `Input = Substring.UTF8View` — no change needed (Substring.UTF8View is Copyable, conforms to `Input.Protocol` via SLI or wrapping)

#### Phase 3: Standard Library Integration

1. Provide `Substring.UTF8View: Input.Protocol` conformance in an SLI module (or document `Input.Slice` wrapping as the canonical approach)

#### Phase 4: WithDefaults Migration (future, when SE-0503 ships)

1. Switch feature flag from `SuppressedAssociatedTypes` to `SuppressedAssociatedTypesWithDefaults`
2. Optionally add copy-based Copyable tier overloads for performance-critical combinators
3. Remove `borrowing` annotations from Copyable-tier closures (if any were added)

### Open Questions

1. **SLI vs wrapping**: Should `Substring.UTF8View` get a full `Input.Protocol` conformance, or should the canonical approach be wrapping in `Input.Slice`?
2. **Phase 1 timing**: Should the primitives change land first, or should primitives and foundations be coordinated?
3. **`borrowing` impact**: Which combinator closures need `borrowing` annotation when Input is ~Copyable?

## References

- SE-0503: Suppressed Associated Types with Defaults
- `SuppressedAssociatedTypes` experimental feature flag (Swift 6.2.3)
- `Input.Protocol` — `/Users/coen/Developer/swift-primitives/swift-input-primitives/Sources/Input Primitives/Input.Protocol.swift`
- `Parser.Protocol` — `/Users/coen/Developer/swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift`
