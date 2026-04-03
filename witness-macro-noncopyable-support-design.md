# @Witness Macro Support for ~Copyable Witnesses

<!--
---
version: 2.0.0
last_updated: 2026-03-04
status: SUPERSEDED
superseded_by: witness-ownership-integration.md
source: witness-macro-noncopyable-feasibility experiment (13 variants)
supersedes: witness-macro-io-drivers-assessment.md (partial — revises "DEFERRED" to "VIABLE")
tier: 2
---
-->

> **SUPERSEDED** (2026-04-02) by [witness-ownership-integration.md](witness-ownership-integration.md).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

The `@Witness` macro generates Action enums, Observe wrappers, and `unimplemented()` scaffolding for protocol witness structs. The prior assessment (`witness-macro-io-drivers-assessment.md`) concluded this was **DEFERRED** due to three blockers:

1. `~Copyable` types cannot appear as Copyable enum associated values
2. `borrowing`/`consuming` parameters cannot be forwarded through observation closures
3. The features that *could* be generated are the least valuable

Experiment `witness-macro-noncopyable-feasibility` (13 variants, all CONFIRMED) disproves blockers #2 and #3, and provides a design that resolves blocker #1 without new protocols.

## Question

Can the `@Witness` macro be extended to fully support witnesses with `~Copyable` parameters (`borrowing`/`consuming`), generating Action, Observe, and `unimplemented()` with the same quality as Copyable witnesses?

## Analysis

### Option A: Status Quo (No Support)

Keep the current limitation. ~Copyable witnesses use manual Witness.Protocol conformance and Witness.Key only.

- **Pros**: No macro changes needed.
- **Cons**: IO drivers — the most important witness pattern — get no macro benefits. Observation, recording, and test scaffolding must be hand-written.

### Option B: WitnessLite (Init + Forwarding Only)

Generate only the memberwise init and forwarding methods. Skip Action/Observe/unimplemented.

- **Pros**: Trivially implementable. No ~Copyable challenges.
- **Cons**: Provides almost no value for IO drivers (init already exists, closures are unlabeled so no methods generated). Does not solve the observation/testing problem.

### Option C: Projection Protocol

Introduce a `WitnessProjectable` protocol. The macro generates Action enums using `T.Projection` instead of `T` for ~Copyable parameters.

- **Pros**: Type-safe, rich information in Action cases.
- **Cons**: **Adds a new protocol.** Requires one conformance per ~Copyable type. Macros cannot detect protocol conformance at expansion time — needs a heuristic or annotation anyway.

### Option D: Omission Pattern (Recommended)

The macro detects `borrowing`/`consuming` ownership specifiers and **omits** those parameters from the Action enum. No new protocols, no annotations, fully automatic.

```swift
// Closure: (borrowing Handle, Int32, Interest) throws -> ID
// Action (current, broken): case register(Handle, Int32, Interest)
// Action (omission):        case register(descriptor: Int32, interest: Interest)
```

**How it works:**

| Closure Parameter | Action Associated Value | Observe Behavior |
|---|---|---|
| Copyable `T` | `T` (unchanged) | Forward directly |
| `borrowing T` | **omitted** | Forward borrow transparently |
| `consuming T` | **omitted** | Forward consume transparently |
| `inout T` | **omitted** | Forward `&` transparently |

**Rationale**: You cannot observe what has been consumed. The Action records the observable (Copyable) surface. The Observe wrapper still forwards *everything* — borrowing and consuming work natively (V2, V3: CONFIRMED).

**Design verified by experiment** (V13):

```swift
// User writes (unchanged from today):
struct EventDriver: Sendable {
    let _create: @Sendable () throws(DriverError) -> Handle
    let _register: @Sendable (borrowing Handle, Int32, Interest) throws(DriverError) -> RegistrationID
    let _close: @Sendable (consuming Handle) -> Void
}

// Macro generates:
extension EventDriver {
    enum Action: Sendable {
        case create
        case register(descriptor: Int32, interest: Interest)  // Handle omitted
        case close                                             // Handle omitted
    }
}
```

**For users who need to observe ~Copyable params**, they write per-closure observation callbacks manually (V13d: CONFIRMED). This is opt-in — most users only need Action-level observation:

```swift
let observed = driver.observingDetailed(
    beforeClose: { handle in  // borrowing access to ~Copyable
        print("closing fd=\(handle.fd)")
    }
)
```

## Detailed Design

### 1. Action Enum Generation

The macro already parses `borrowing`/`consuming` ownership specifiers (`ClosureParameter.ownership`). When generating the Action enum:

- **No ownership specifier**: include parameter type as associated value (existing behavior)
- **`borrowing` / `consuming` / `inout`**: **omit** from Action case

```swift
// Closure: (borrowing Handle, Int32, Interest) throws -> ID
// Generated: case register(descriptor: Int32, interest: Interest)

// Closure: (consuming Handle) -> Void
// Generated: case close  // no associated values
```

### 2. Observe Wrapper Generation

**Borrowing forwarding** (V2: CONFIRMED): Forward `borrowing` parameters directly through closure wrappers. The borrow lifetime spans the entire wrapper body.

```swift
_register: { (handle: borrowing Handle, descriptor: Int32, interest: Interest) throws(DriverError) -> RegistrationID in
    let action = Action.register(descriptor: descriptor, interest: interest)
    before(action)
    let result = try wrapped._register(handle, descriptor, interest)
    after(action)
    return result
}
```

**Consuming forwarding** (V3: CONFIRMED): The macro generates borrow-then-consume for the real call. The Action case has no ~Copyable values to populate:

```swift
_close: { (handle: consuming Handle) -> Void in
    before(.close)
    wrapped._close(consume handle)
    after(.close)
}
```

**inout forwarding** (V12: CONFIRMED): Forward `&` directly. Before/after callbacks receive the Action without the inout parameter.

### 3. Typed Throws in Generated Closures

**Critical**: Generated closures MUST include explicit `throws(E)` annotation. Without it, the closure infers `throws` (any Error), which fails typed throw conversion:

```swift
// WRONG — infers throws(any Error):
{ [wrapped] in try wrapped._create() }

// CORRECT — explicit annotation:
{ [wrapped] () throws(DriverError) -> Handle in try wrapped._create() }
```

The macro already has access to the closure's error type from parsing the property declaration. It must emit this in the generated closure signature.

### 4. Unimplemented Generation

**Throwing closures** (V8a: CONFIRMED): Generate `throw Witness.Unimplemented.Error(...)` — works regardless of parameter ownership because the error is thrown before any parameter use.

**Non-throwing consuming closures** (V8b/V8c: CONFIRMED): Must consume the parameter, then `fatalError`. Cannot throw from a non-throwing closure.

```swift
_close: { (handle: consuming Handle) in
    _ = consume handle
    fatalError("EventDriver._close is unimplemented")
}
```

### 5. Detection Strategy

The macro uses **ownership specifiers as the signal**:

- `borrowing` → omit from Action, forward borrow in Observe
- `consuming` → omit from Action, forward consume in Observe, consume-then-fatalError in unimplemented
- `inout` → omit from Action, forward `&` in Observe
- No specifier → include in Action (existing behavior)

This is 100% syntax-based. No conformance resolution needed. No user annotation needed. No new protocols.

## Comparison

| Criterion | A: Status Quo | B: WitnessLite | C: Projection | **D: Omission** |
|---|---|---|---|---|
| Action enum | ✗ | ✗ | ✓ (projected) | **✓ (Copyable subset)** |
| Observe wrapper | ✗ | ✗ | ✓ | **✓** |
| unimplemented() | ✗ | ✗ | ✓ | **✓** |
| Forwarding methods | ✗ | ✓ | ✓ | **✓** |
| New protocols | 0 | 0 | 1 | **0** |
| User annotation | None | None | 1 conformance/type | **None** |
| Macro changes | None | Minimal | Moderate | **Moderate** |
| ~Copyable info in Action | n/a | n/a | Projected Copyable summary | **Omitted** |
| Opt-in detailed observation | n/a | n/a | Built-in | **Manual (V13d)** |
| Works with borrowing | n/a | ✓ | ✓ | **✓** |
| Works with consuming | n/a | ✓ | ✓ | **✓** |
| Works with inout | n/a | ✓ | ✓ | **✓** |
| Works with typed throws | n/a | ✓ | ✓ | **✓** |

### Trade-off: Omission vs Projection

Option D loses information in the Action enum — `case close` instead of `case close(fd: Int32)`. But:

1. The macro cannot know which Copyable fields to extract (it sees syntax, not type members)
2. A protocol adds ecosystem burden for marginal value
3. The Observe wrapper still forwards everything — full observability is available via per-closure callbacks
4. Action cases like `case close` still tell you *what* happened — just not *on what*

If richer Action cases are later desired, Option C can be added as an opt-in enhancement on top of Option D, without breaking anything.

## Macro Implementation Changes Required

1. **Parse**: Already parses ownership specifiers.
2. **Action enum**: When generating enum cases, skip parameters that have `borrowing`, `consuming`, or `inout` ownership. If all parameters are skipped, emit a case with no associated values.
3. **Observe closures**: Emit ownership annotations on closure parameter bindings. Emit explicit `throws(E)` on closure signatures. Forward all parameters including owned ones.
4. **Unimplemented closures**: For non-throwing consuming closures, emit `_ = consume param; fatalError(...)` instead of `throw`.
5. **Typed throws**: Emit explicit `throws(E)` annotation on every generated closure. The error type is available from the parsed closure property type.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Implement Option D (Omission Pattern).

**Implementation plan**:

1. Update `@Witness` macro to detect `borrowing`/`consuming`/`inout` parameters
2. Omit those parameters from Action enum associated values
3. Generate Observe wrappers that forward ownership correctly
4. Generate explicit `throws(E)` in all generated closure signatures
5. Generate `_ = consume param; fatalError(...)` for non-throwing consuming closures in unimplemented
6. Test with `@Witness` on IO.Event.Driver

**Future enhancement** (not required for v1): Add optional `WitnessProjectable` protocol for users who want projected Copyable summaries in Action cases. This layers on top of the omission pattern — the macro checks for conformance and uses `.Projection` if available, falls back to omission otherwise.

**Experiment**: `swift-institute/Experiments/witness-macro-noncopyable-feasibility/` (13 variants, all CONFIRMED)

## References

- `witness-macro-io-drivers-assessment.md` — prior assessment (DEFERRED, now partially superseded)
- `witness-noncopyable-nonescapable-support.md` — bifurcation theorem
- `copyable-remediation` skill — constraint cascade patterns
- `memory` skill — [MEM-COPY-001] through [MEM-COPY-003]
