# swift-machine-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Scope**: 45 files across 10 modules
**Rules**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [IMPL-020], [IMPL-050], [PATTERN-017], [PATTERN-021], [API-IMPL-005]

---

## Summary Table

| ID | Severity | Rule | File | Line(s) | Description |
|----|----------|------|------|---------|-------------|
| MACH-001 | MEDIUM | [API-NAME-002] | Machine.Builder+Carriers.swift | 33 | Compound method `throwingTransform` |
| MACH-002 | LOW | [PATTERN-017] | Machine.Capture.Frozen+Reference.swift | 8, 19, 30 | `.rawValue` at call sites (`id.rawValue`, `raw.rawValue`) |
| MACH-003 | LOW | [PATTERN-017] | Machine.Capture.Frozen+Unchecked.swift | 8, 19, 30 | `.rawValue` at call sites (`id.rawValue`, `raw.rawValue`) |
| MACH-004 | LOW | [PATTERN-017] | Machine.Capture.Store+Reference.swift | 19, 31, 43 | `.rawValue` at call sites (`id.rawValue`, `raw.rawValue`) |
| MACH-005 | LOW | [PATTERN-017] | Machine.Capture.Store+Unchecked.swift | 18, 30, 42 | `.rawValue` at call sites (`id.rawValue`, `raw.rawValue`) |
| MACH-006 | LOW | [PATTERN-017] | Machine.Transform.Throwing.swift | 40-41, 57-58 | Direct slot access via `captures.slots[raw.rawValue]` (documented workaround) |
| MACH-007 | LOW | [IMPL-010] | Machine.Value.Arena.swift | 53, 56, 77-78, 92-93, 96, 106 | `Int(slot)` conversions scattered through Arena methods |
| MACH-008 | LOW | [IMPL-010] | Machine.Value.Handle.swift | 51, 60 | `Int(slot)` / `UInt32(handle.index)` conversions in handle helpers |
| MACH-009 | INFO | [API-IMPL-005] | Machine.Capture.Slot.swift | 37-56 | `_Storage` class nested inside `Slot` struct (same file) |
| MACH-010 | INFO | [API-IMPL-005] | Machine.Value.swift | 51-67, 76-89, 137-150 | `_Storage`, `_Table`, `Ref` nested inside `Value` struct |
| MACH-011 | INFO | [API-NAME-001] | Machine.Value.Handle.swift | 19 | `_MachineValueArenaTag` — compound name, but underscore-prefixed internal phantom type |

---

## Findings

### MACH-001 — Compound method `throwingTransform` [API-NAME-002]

**File**: `Machine Convenience Primitives/Machine.Builder+Carriers.swift`, line 33
**Code**: `public mutating func throwingTransform<In, Out: Sendable>(...)`

The method name `throwingTransform` is a compound identifier. Per [API-NAME-002], this should use a nested accessor pattern. However, since `Builder` is a construction-time API (not a consumer call-site API), and the method name parallels the type it creates (`Transform.Throwing`), this may be acceptable as conscious debt. A nested accessor `builder.transform.throwing(fn)` would be the ideal form.

### MACH-002 through MACH-005 — `.rawValue` at call sites [PATTERN-017]

**Files**: All Capture access methods (Frozen+Reference, Frozen+Unchecked, Store+Reference, Store+Unchecked)
**Code**: `let slot = slots[id.rawValue]` and `let slot = slots[raw.rawValue]`

Every `with()` and `withRaw()` method indexes into `slots` via `.rawValue`. This is `.rawValue` at a call site within the same package, which [PATTERN-017] permits ("same-package implementations"). These are low severity because the access is confined to the capture subsystem and does not leak to consumers.

### MACH-006 — Direct slot access workaround [PATTERN-017]

**File**: `Machine Transform Primitives/Machine.Transform.Throwing.swift`, lines 39-43 and 55-59
**Code**: `let slot = captures.slots[raw.rawValue]`

This bypasses `withRawThrowing` due to a documented compiler crash with nested typed throws closures. The workaround is properly documented per [PATTERN-016] with WHY, WHEN TO REMOVE, and TRACKING annotations.

### MACH-007 — `Int(slot)` conversions in Arena [IMPL-010]

**File**: `Machine Value Primitives/Machine.Value.Arena.swift`
**Code**: `Int(slot)` appears 6 times for array indexing.

The Arena stores `nextSlot` as `UInt32` and `values` as a standard `[T?]` array. Every array access requires `Int(slot)`. Per [IMPL-010], these conversions should live in a boundary overload (e.g., a subscript accepting `UInt32`). However, this is internal infrastructure code, not a consumer-facing call site.

### MACH-008 — Handle construction/extraction conversions [IMPL-010]

**File**: `Machine Value Primitives/Machine.Value.Handle.swift`, lines 51 and 60
**Code**: `Handle(index: Int(slot), generation: generation)` and `UInt32(handle.index)`

These are the boundary between Handle_Primitives (Int-based) and the arena's UInt32-based slots. The conversion is confined to two static methods, which is the correct boundary placement per [IMPL-010].

### MACH-009 and MACH-010 — Nested implementation types [API-IMPL-005]

**Files**: `Machine.Capture.Slot.swift` and `Machine.Value.swift`

Both files contain implementation-internal nested types (`_Storage`, `_Table`, `Ref`). These are underscored private types that serve as implementation details. [API-IMPL-005] primarily targets public type declarations. The `Ref` type in `Machine.Value` is public and could warrant its own file (`Machine.Value.Ref.swift`), but it is small (14 lines) and tightly coupled to `Value`.

### MACH-011 — `_MachineValueArenaTag` phantom type naming

**File**: `Machine Value Primitives/Machine.Value.Handle.swift`, line 19

The name `_MachineValueArenaTag` is a compound name, but it is an underscore-prefixed internal phantom type used solely for `Handle` specialization. The underscore prefix signals "do not use directly." This is informational only.

---

## Clean Areas

- **Namespace structure**: All types follow `Machine.X.Y` nesting. No compound public type names.
- **Typed throws**: All throwing operations use typed throws (`throws(Failure)`, `throws(E)`).
- **Property.View**: Not applicable — Machine types are Copyable reference-counted wrappers, not ~Copyable containers.
- **Bounded indices**: Not applicable — Machine does not have static-capacity collections.
- **One type per file**: All public namespace enums (`Machine`, `Machine.Capture`, `Machine.Transform`, etc.) each get their own file.
- **No Foundation**: No Foundation imports anywhere.
