---
date: 2026-02-12
session_objective: Complete all remaining remedies from the swift-storage-primitives implementation skill audit
packages:
  - swift-storage-primitives
  - swift-bit-vector-primitives
  - swift-buffer-primitives
status: processed
processed_date: 2026-02-13
triage_outcomes:
  - type: skill_update
    target: existing-infrastructure
    description: Add Tagged<Tag, Cardinal>.init(_ int: Int) throws(Cardinal.Error) to [INFRA-002] catalog
  - type: skill_update
    target: implementation
    description: Add [IMPL-034] unsafe keyword placement constraint
  - type: no_action
    description: Ones.Static var first superseded by Entry 2 integration-layer fix (Sequence.Protocol extension)
---

# Storage Primitives Audit Completion — Infrastructure Discovery as Force Multiplier

## What Happened

Continued the swift-storage-primitives audit (started 2026-02-06) from Remedy 5 onward. Applied Remedies 5, 6, 7, 8, and 9. Assessed and deferred Remedies 10-11 (SHOULD-severity). Closed the audit with all MUST-severity items resolved.

Key changes:
- **Remedy 5**: Added `package func _pointer(at:)` to `Storage.Pool` in the core module, eliminating a raw `UnsafeMutableRawPointer(...).assumingMemoryBound(...)` chain in the deinit. This mirrored the existing `_pointer(at:)` pattern on `Pool.Inline` and `Arena.Inline`.
- **Remedy 7**: Discovered `Tagged<Tag, Cardinal>.init(_ int: Int) throws(Cardinal.Error)` which collapsed a three-step `Index<Element>.Count(Cardinal(UInt(capacity)))` chain to `try! Index<Element>.Count(capacity)` at 4 sites.
- **Remedy 6**: Initially marked as conscious debt (no `zeros.first` infrastructure in Bit.Vector). User commissioned a research prompt, implemented `zeros` infrastructure in swift-bit-vector-primitives, then replaced the raw `for i in 0..<capacity` loop with `_slots.zeros.first!`. Build error from `.first` resolving to `Sequence.first(where:)` method reference instead of a property required adding a `var first: Bit.Index?` computed property to `Zeros.Static`.
- **Remedies 8-9**: Inlined single-use variables, factored redundant computation in `unallocate`.

## What Worked and What Didn't

**Worked well**:
- The existing-infrastructure skill was essential. The `Tagged+Cardinal.swift` throwing init was the key discovery for Remedy 7 — without it, the remedy would have stayed at two steps (`UInt` intermediate) instead of collapsing to one.
- The `_pointer(at:)` pattern for cross-module encapsulation was already established by Pool.Inline and Arena.Inline. Applying it to Pool itself was mechanical.
- Deferred remedies were correctly assessed: converting Arena's one-liner methods to Property accessors and wrapping Inline copy in Property.View would change zero call sites.

**Didn't work**:
- The `unsafe` keyword placement constraint was unexpected: `guard slot < unsafe base.pointee.slotCapacity` fails because `unsafe` cannot appear to the right of a non-assignment operator. Had to restructure to `guard unsafe slot < base.pointee.slotCapacity`. This is a compiler rule worth documenting.
- The `zeros.first` gap was real: identifying it as "conscious debt" was premature. The user immediately saw it as a gap worth filling, commissioned the infrastructure addition, and closed the loop in-session. The lesson: when an infrastructure gap blocks a MUST-severity remedy, escalate to filling the gap rather than accepting debt.

## Patterns and Root Causes

**Pattern: Infrastructure discovery eliminates entire categories of mechanism.** Remedy 7 exemplifies this. The three-step chain `Index<Element>.Count(Cardinal(UInt(capacity)))` existed at 4 sites because nobody had traced the init path through `Tagged+Cardinal.swift`. The throwing init `Tagged<Tag, Cardinal>.init(_ int: Int)` was designed for exactly this use case — bridging from stdlib `Int` to the typed domain — but was invisible until someone searched for it. This is the same pattern seen earlier in the audit where `Int(bitPattern:)` wrappers were removed because cardinal/ordinal integration overloads already existed.

**Pattern: Cross-module boundaries create structural technical debt.** Remedy 5 existed because `Storage.Pool.pointer(at:)` lives in `Storage_Pool_Primitives` (tier 14 public API) while the deinit lives in `Storage_Primitives_Core` (tier 14 core). The solution — a `package`-scoped `_pointer(at:)` duplicate in core — is the established pattern (Pool.Inline and Arena.Inline already use it). But it means the pointer computation is written twice. This is a consequence of Swift's module system not supporting "internal to a package group" access (only `package` across modules in the same package, which works here, but the API surface split forces the duplication).

**Pattern: Sequence.first is a method, not a property.** `Swift.Sequence` provides `first(where:)` as a method. Only `Swift.Collection` provides `var first: Element?` as a property. When a custom sequence type needs `.first` as a property (for natural syntax like `zeros.first!`), it must be added explicitly. This will recur for any Sequence.Protocol conformer that doesn't also conform to Collection.

## Action Items

- [ ] **[skill]** existing-infrastructure: Add `Tagged<Tag, Cardinal>.init(_ int: Int) throws(Cardinal.Error)` to [INFRA-002] catalog — it's the missing "Int value-generic to typed Count" bridge
- [ ] **[skill]** implementation: Document `unsafe` placement constraint — cannot appear to the right of a non-assignment operator; must wrap the full expression
- [ ] **[package]** swift-bit-vector-primitives: Consider adding `var first: Element?` to `Ones.Static` for symmetry with the new `Zeros.Static.first`
