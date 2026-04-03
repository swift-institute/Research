<!--
version: 1.0.0
last_updated: 2026-04-02
status: DECISION
tier: 2
consolidates:
  - witness-noncopyable-nonescapable-support.md (RECOMMENDATION, 2026-02-24)
  - witness-macro-noncopyable-support-design.md (RECOMMENDATION, 2026-03-04)
  - witness-protocol-sendable-requirement.md (DECISION, 2026-03-03)
-->

# Witness Framework Ownership Integration

## Question

How should the witness DI framework handle ~Copyable values, non-Sendable witnesses,
and ownership-annotated parameters in the @Witness macro?

## Context

Three research documents investigated overlapping aspects of witness framework
ownership. This consolidation unifies their findings: the Bifurcation Theorem
(service references are Copyable), the Sendable removal decision, and the macro
Omission Pattern for ~Copyable parameters.

---

## 1. Bifurcation Theorem

### Statement

There is a fundamental bifurcation in DI value flow:
1. **Service references** (the container's domain) — must be shared, duplicated,
   propagated → requires Copyable or reference-counted wrapper
2. **Resources vended by services** (the application's domain) — may be unique,
   move-only, scoped → may be ~Copyable and/or ~Escapable

Attempting to collapse this bifurcation contradicts the structural requirements of
environment passing.
(from witness-noncopyable-nonescapable-support.md, 2026-02-24)

### Cross-language evidence

| Language | Service references | Resources vended |
|----------|-------------------|-----------------|
| Rust (`shaku`, `coi`, `dilib`) | `Arc<dyn Trait>` (reference-counted) | `Connection`, `Handle` (move-only) |
| Haskell (`linear-base`, `dep-t`) | `Dupable r` (environments must be duplicable) | Linear resources via the environment |
| OCaml/OxCaml (Jane Street) | `shared many` records | `unique` mutable state |
| Swift (`swift-witnesses`) | `Witness.Key.Value: Copyable` | Resources returned by witness closures |

Every language enforces this bifurcation. No DI framework attempts to store truly
move-only values directly.
(from witness-noncopyable-nonescapable-support.md, 2026-02-24)

### Theoretical grounding

Swift's `~Copyable` corresponds to affine typing (discard but not duplicate).
Environment passing requires contraction for owned access. However, **borrowed access
does not require contraction** — multiple consumers can simultaneously borrow from a
heap-allocated value. `Ownership.Shared` (reference-counted wrapper) provides this.
(from witness-noncopyable-nonescapable-support.md, 2026-02-24)

### TaskLocal propagation is not a blocker

The `~Copyable` value never touches TaskLocal directly. Chain:
`TaskLocal<Context>` → `Values` → `_Storage` (class) → `dict: [OID: Ptr]` →
`Ownership.Shared` → `let value: T` (~Copyable lives here behind heap allocation).
(from witness-noncopyable-nonescapable-support.md, 2026-02-24)

### Recommendation

**Today**: Continue with Copyable witness values. The bifurcation is correct.
**When concrete use case emerges**: Option E (additive closure-based API) is
technically feasible — `withValue(for:mode:body:)` with `borrowing K.Value`.
(from witness-noncopyable-nonescapable-support.md, 2026-02-24)

---

## 2. Sendable Decision

### Decision: Remove Sendable from Witness.Protocol

`Witness.Protocol` becomes a pure semantic marker. Sendable is required where
isolation-crossing actually occurs (`Witness.Key`, `Witness.Values`,
`Witness.Context`), not on the marker protocol.

**Trigger**: `Parser.Machine.Compile.Witness<P>` wraps a single `_compile` closure
that operates synchronously via `inout Builder`. Neither the closure nor the struct
crosses isolation boundaries.
(from witness-protocol-sendable-requirement.md, 2026-03-03)

### Impact analysis

| Component | Effect |
|-----------|--------|
| `Witness.Key` | Unaffected — requires Sendable independently via `__WitnessKeyTest` |
| `Witness.Context` / `Witness.Values` | Unaffected — stores by Key conformance |
| `@Witness` macro output | Unaffected — all generated types already declare Sendable explicitly |
| Existing 13 conformances | Unaffected — all declare Sendable on the struct itself |

(from witness-protocol-sendable-requirement.md, 2026-03-03)

### Alignment

Aligns with the ecosystem principle: Sendable should be required at the points where
isolation-domain crossing occurs, not as a blanket constraint on semantic categories.
(from witness-protocol-sendable-requirement.md, 2026-03-03;
ownership-transfer-conventions.md)

---

## 3. Macro ~Copyable Support: Omission Pattern

### Supersedes prior assessment

`witness-macro-io-drivers-assessment.md` concluded DEFERRED due to three blockers.
The `witness-macro-noncopyable-feasibility` experiment (13 variants, all CONFIRMED)
disproves blockers 2 and 3, and resolves blocker 1.
(from witness-macro-noncopyable-support-design.md, 2026-03-04)

### Pattern

The macro detects ownership specifiers syntactically and **omits** those parameters
from the Action enum. 100% syntax-based, no conformance resolution needed.

| Parameter | Action Associated Value | Observe Behavior |
|-----------|----------------------|-----------------|
| Copyable `T` | `T` (unchanged) | Forward directly |
| `borrowing T` | **Omitted** | Forward borrow transparently |
| `consuming T` | **Omitted** | Forward consume transparently |
| `inout T` | **Omitted** | Forward `&` transparently |

Rationale: you cannot observe what has been consumed.
(from witness-macro-noncopyable-support-design.md, 2026-03-04)

### Code generation example

```swift
// User writes:
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

(from witness-macro-noncopyable-support-design.md, 2026-03-04)

### Unimplemented generation

- Throwing closures: `throw Witness.Unimplemented.Error(...)` before parameter use.
- Non-throwing consuming: `_ = consume handle; fatalError(...)`.
(from witness-macro-noncopyable-support-design.md, 2026-03-04)

### Typed throws requirement

Generated closures MUST include explicit `throws(E)` annotation. Without it, the
closure infers `throws` (any Error), failing typed throw conversion.
(from witness-macro-noncopyable-support-design.md, 2026-03-04)

---

## 4. End-State Design

### Current

`Witness.Context.current[K] : K.Value` where `K.Value : Copyable & Sendable`.
Lookup returns an owned Copyable value.

### Option E: Additive closure-based API (deferred)

`Witness.Context.withValue(K, body:)` where `body: (borrowing K.Value) -> R`.
Borrow scoped to closure. No lifetime annotation needed. Trigger: a real use case
where a witness value itself (not resources it vends) must be ~Copyable.
Infrastructure ready: `Ownership.Shared`, pointer storage, TaskLocal propagation,
experimental features enabled.
(from witness-noncopyable-nonescapable-support.md, 2026-02-24)

### Option B: ~Escapable scoped dependencies (future)

`Witness.Context.withBorrowed[K] : @lifetime(scope) borrowing K.Value` where
`K.Value: ~Escapable`. Returned reference cannot outlive scope. Strongest theoretical
fit — capability-passing style is the formalization of what `Witness.Context.with`
already enforces at runtime. Track `@lifetime` stabilization and SE-0446.
(from witness-noncopyable-nonescapable-support.md, 2026-02-24)

### Witness.Scope is correctly designed

`Witness.Scope: ~Copyable` uses ~Copyable for the scope token (exactly-once
consumption), not for witness values. Values remain Copyable for shared access.
(from witness-noncopyable-nonescapable-support.md, 2026-02-24)

---

## Cross-References

- **memory-safety** skill: [MEM-COPY-001] through [MEM-COPY-003]
- **ownership-transfer-conventions.md**: Sendable ecosystem principle
- **noncopyable-ecosystem-state.md**: ~Copyable compiler state
- Experiments: witness-macro-noncopyable-feasibility (13 variants),
  witness-noncopyable-default-forwarding, witness-noncopyable-value-feasibility
