# Ownership.Inout `~Escapable` Value Upgrade

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: CONVERGED
tier: 1
scope: per-package
preceded_by:
  - swift-institute/Research/property-ownership-escapable-base-upgrade.md (DECISION, 2026-05-09) — institute-wide rationale
  - swift-institute/Research/escapable-support-pair-either-product.md (DECISION v1.1.0, 2026-05-09) — canonical cohort pattern
  - swift-institute/Research/nonescapable-ecosystem-state.md (DECISION, 2026-04-02) — ecosystem readiness
relates_to:
  - swift-property-primitives/Research/escapable-base-upgrade.md (downstream consumer)
toolchains_verified:
  - Swift 6.3.1 (Xcode 26.4 default)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a (`org.swift.64202605071a`)
  - Swift 6.4-dev/Embedded
trigger: Property.Inout's `Tagged<Tag, Ownership.Inout<Base>>` private storage requires Ownership.Inout to admit `Value: ~Escapable` for `Property<Tag, Base>` to widen `Base` to `~Copyable & ~Escapable`. Cohort cascade Item B Candidate 2 blocker traces here.
---
-->

## Context

`Ownership.Inout<Value>` is currently declared as `public struct Inout<Value: ~Copyable>: ~Copyable, ~Escapable` (`Sources/Ownership Inout Primitives/Ownership.Inout.swift:36`). The `Value` parameter is `~Copyable` only, which leaves `Escapable` as the implicit constraint. Property.Inout in `swift-property-primitives` wraps `Ownership.Inout<Base>` in private Tagged storage; widening Property's `Base` to admit `~Escapable` instantiates Ownership.Inout's `Value` with a `~Escapable` type and currently fails to compile.

`Ownership.Borrow` already solved the same structural problem (`Borrow<Value: ~Copyable & ~Escapable>: ~Escapable`, `Ownership.Borrow.swift:69`). This upgrade mirrors the Borrow template, minus two pieces Inout doesn't need (`_owner` field, `init(borrowing:)` path).

Pre-flight (verified 2026-05-09 at HEAD `b8470fe`):

- Working tree clean.
- `swift test` baseline: **114 tests in 47 suites passed** in 0.213s.
- Single source file in scope: `Sources/Ownership Inout Primitives/Ownership.Inout.swift` (122 lines).
- Single test file: `Tests/Ownership Primitives Tests/Ownership.Inout Tests.swift`.
- 4 extension blocks in own file (3× `where Value: ~Copyable`, 1× `where Value: Copyable`); no Sendable / Codable / Equatable / Hashable conformances.
- Source-level downstream consumers: 4 files in `swift-property-primitives` (Property.Inout family); zero in `swift-standards`; zero in `swift-foundations`. All four wrap Inout in private storage; none expose Inout in their public API.

## Question

What is the file-level shape of the `Ownership.Inout` upgrade — type declaration, storage rewrite, init path split, accessor switch, test additions — that admits `Value: ~Copyable & ~Escapable` while preserving the existing `Value: Copyable` and `Value: ~Copyable` (Escapable-implicit) call-site contracts?

## Analysis

### A. Type declaration

| Current (line 36) | Proposed |
|-------------------|----------|
| `public struct Inout<Value: ~Copyable>: ~Copyable, ~Escapable {` | `public struct Inout<Value: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {` |

Inout itself remains `~Copyable, ~Escapable` (unconditional). `Value`'s constraint widens.

### B. Storage rewrite

| Current (line 39) | Proposed |
|-------------------|----------|
| `let _pointer: UnsafeMutablePointer<Value>` | `let _pointer: UnsafeMutableRawPointer` |

Rationale per Borrow (lines 36-67): `UnsafeMutablePointer<Value>` requires `Value: Escapable` (`nonescapable-ecosystem-state.md` §2 — "UnsafeMutablePointer declares Pointee: ~Copyable but NOT & ~Escapable"). `UnsafeMutableRawPointer` has no Escapable requirement on the pointee.

### C. Init path split

Three current inits gated `where Value: ~Copyable` (which implicitly requires `Value: Escapable` because they take or use `UnsafeMutablePointer<Value>`):

| Current (file:line) | Proposed (where-clause) | Storage assignment |
|---------------------|-------------------------|--------------------|
| `init(_ pointer: UnsafeMutablePointer<Value>)` (line 48) | `where Value: ~Copyable` (Escapable implicit, unchanged) | `_pointer = unsafe UnsafeMutableRawPointer(pointer)` |
| `init(mutating value: inout Value)` (line 65) | `where Value: ~Copyable` (Escapable implicit; `withUnsafeMutablePointer(to:)` requires it) | `_pointer = unsafe withUnsafeMutablePointer(to: &value) { unsafe UnsafeMutableRawPointer($0) }` |
| `init<Owner: ~Copyable & ~Escapable>(unsafeAddress: UnsafeMutablePointer<Value>, mutating owner: inout Owner)` (line 85) | `where Value: ~Copyable` (Escapable implicit, typed pointer parameter) | `_pointer = unsafe UnsafeMutableRawPointer(pointer)` |

**New init for `~Escapable` Value** (mirrors `Ownership.Borrow.swift:259-283`):

```swift
extension Ownership.Inout where Value: ~Copyable & ~Escapable {
    @unsafe
    @inlinable
    @_lifetime(&owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeMutableRawPointer,
        mutating owner: inout Owner
    ) {
        unsafe (self._pointer = pointer)
    }
}
```

This is the only construction path available for `~Escapable` Value, mirroring Borrow's raw-address init at line 259.

### D. Value access switch

Two current accessors:

| Current (file:line) | Body | Proposed |
|---------------------|------|----------|
| `var value: Value { _read; nonmutating _modify }` `where Value: ~Copyable` (line 95-106) | `yield unsafe _pointer.pointee` / `yield unsafe &_pointer.pointee` | `_read { yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee }` / `nonmutating _modify { yield unsafe &_pointer.assumingMemoryBound(to: Value.self).pointee }` |
| `var value: Value { get; nonmutating _modify }` `where Value: Copyable` (line 108-122) | `unsafe _pointer.pointee` / `yield unsafe &_pointer.pointee` | `get { unsafe _pointer.assumingMemoryBound(to: Value.self).pointee }` / `nonmutating _modify { yield unsafe &_pointer.assumingMemoryBound(to: Value.self).pointee }` |

Both stay gated on `where Value: ~Copyable` / `where Value: Copyable` (Escapable implicit) because `assumingMemoryBound(to:)` returns `UnsafeMutablePointer<Value>` which requires `Value: Escapable`. Mirror of Borrow line 288.

### E. Conditional conformances on Inout

Inout currently has none. Per the cohort canonical pattern's conditional-conformance discipline (`escapable-support-pair-either-product.md` v1.1.0 Empirical finding 1: "every conditional conformance MUST be explicit on the orthogonal axis"):

Inout itself remains unconditionally `~Copyable, ~Escapable` (it is a scope-bound mutable reference; copy and escape are both forbidden). No conditional `Copyable` / `Escapable` / `Sendable` extensions are added — Inout has none today and none is structurally appropriate.

### F. Lifetime annotations (unchanged shape)

Existing annotations:

| Init | Annotation (current) |
|------|----------------------|
| `init(_ pointer:)` (line 47) | `@_lifetime(borrow pointer)` |
| `init(mutating value:)` (line 64) | `@_lifetime(&value)` |
| `init(unsafeAddress:, mutating owner:)` (line 84) | `@_lifetime(&owner)` |
| (new) `init(unsafeRawAddress:, mutating owner:)` | `@_lifetime(&owner)` |

All existing annotations carry forward unchanged. The new raw-address init mirrors Borrow's `@_lifetime(borrow owner)` annotation pattern (Borrow.swift:276) but uses `@_lifetime(&owner)` for the `mutating` case, consistent with the existing `unsafeAddress` init at Inout line 84.

### G. Per-toolchain expectations

`Lifetimes` and `LifetimeDependence` features are already enabled in `Package.swift`. No `Package.swift` changes required.

`@_lifetime` annotations are stable on Swift 6.3.1 + Swift 6.4-dev nightly per `nonescapable-ecosystem-state.md` §1 ("@_lifetime annotations: Stable (underscored, experimental)").

Parameter-pack expansion bugs (`swiftlang/swift#88985`, `#88987` per memory `pack-expand-on-consuming-param-property.md`) do NOT apply — Inout uses no parameter packs.

Release-mode `withUnsafePointer(to: borrowing _)` miscompile (documented at `swift-institute/Experiments/borrow-pointer-storage-release-miscompile/`) does NOT apply — Inout has no `init(borrowing:)` analog (`init(mutating: inout Value)` uses `inout` which is always indirect).

### H. Test additions

Existing test file: `Tests/Ownership Primitives Tests/Ownership.Inout Tests.swift`. Existing tests cover Copyable + ~Copyable Value paths.

New test fixture (mirroring the cohort pattern in `escapable-support-pair-either-product.md` v1.1.0):

```swift
struct NEResource: ~Escapable {
    let id: Int
    @_lifetime(immortal)
    init(_ id: Int) { self.id = id }
}
```

New test cases admitting the new `Value: ~Copyable & ~Escapable` path (each test exercises the new `init(unsafeRawAddress:, mutating owner:)` and verifies the value can be observed via the pointer storage). Coverage targets:

| Test name (proposed) | What it verifies |
|----------------------|------------------|
| `NEResource_init_unsafeRawAddress_mutating_owner` | New raw-address init compiles and stores |
| `NEResource_value_access_via_assumingMemoryBound` | `var value` accessor returns the borrowed `~Escapable` value |
| `NEResource_modify_writes_back` | `nonmutating _modify` accessor writes back through the raw pointer |
| `Copyable_path_unchanged` | Existing `Value: Copyable` accessor pattern still works (regression guard) |
| `~Copyable_path_unchanged` | Existing `Value: ~Copyable` (Escapable-implicit) accessor pattern still works (regression guard) |

Existing 114 tests must all continue to pass.

### I. File-modification summary

| File | Change kind | Lines (estimate) |
|------|-------------|------------------|
| `Sources/Ownership Inout Primitives/Ownership.Inout.swift` | Rewrite within bounds | 122 → ~145 (storage type, type-decl widening, accessor body change, +1 new init extension) |
| `Tests/Ownership Primitives Tests/Ownership.Inout Tests.swift` | Add ~5 tests + NEResource fixture | +~50 lines |
| `Sources/Ownership Inout Primitives/exports.swift` | Unchanged (no new public symbols beyond Inout itself) | 0 |
| `Package.swift` | Unchanged (Lifetimes already enabled) | 0 |

**Total: 1 source file rewrite (~25 net new lines), 1 test file addition (~50 lines).**

## Outcome

**Status**: CONVERGED. Implementation deferred to Phase 2, gated on per-action user authorization for the public-repo push.

**Cascade-execution-order rationale**: Ownership.Inout lands FIRST. Property.Inout's storage instantiates `Ownership.Inout<Base>` with `~Escapable` Base; the Property-side widening cannot compile until Ownership.Inout admits `~Escapable` Value.

Per [RELEASE-013] First-Publication Clean-History and the 2026-05-09 cohort precedent, the change lands as a single amended commit per package via amend + force-push.

Triple-toolchain verification (Swift 6.3.1 + 6.4-dev nightly 2026-05-07-a + 6.4-dev/Embedded) before push, per existing cohort discipline.

## References

- Institute-wide DECISION: `swift-institute/Research/property-ownership-escapable-base-upgrade.md`
- Cohort canonical pattern: `swift-institute/Research/escapable-support-pair-either-product.md` v1.1.0
- Borrow template: `Sources/Ownership Borrow Primitives/Ownership.Borrow.swift` lines 36-67, 69-119, 257-284, 288-303
- Inout current: `Sources/Ownership Inout Primitives/Ownership.Inout.swift:36, 39, 48, 65, 85, 95, 108`
- Ecosystem state: `swift-institute/Research/nonescapable-ecosystem-state.md` §1, §2 (UnsafeMutablePointer Escapable constraint)
- Memory: `pack-expand-on-consuming-param-property.md` (no application here), `feedback_escapable_over_with_closures.md`
- Active dispatch: `HANDOFF-property-primitives-escapable-upgrade.md`
