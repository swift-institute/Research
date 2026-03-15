# Feature Flags Assessment

<!--
---
version: 1.0.0
date: 2026-03-03
last_updated: 2026-03-15
status: RECOMMENDATION
tier: 2
consolidates:
  - feature-flags-compiler-source-analysis.md
  - feature-flags-coroutine-borrow-accessors.md
  - feature-flags-addressable-borrowinout.md
  - feature-flags-compiletime-struct-reparenting.md
scope: Nine experimental Swift feature flags relevant to ownership, accessors, and compile-time values
method: Static analysis of compiler source + ecosystem impact analysis
toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
---
-->

## 1. Summary

This document assesses nine experimental Swift feature flags for adoption in swift-primitives and swift-foundations. Each feature was analyzed from two angles: compiler implementation maturity (depth of implementation, test coverage, red flags) via static analysis of the compiler source at `/Users/coen/Developer/swiftlang/swift/`, and ecosystem impact (current usage patterns, migration scope, before/after examples) across both monorepos. The assessment was performed on 2026-03-03 and consolidates four prior research documents into a single recommendation.

None of the nine features are currently enabled in production. The overall recommendation is conservative: wait for proposal acceptance and graduation from experimental status before adopting, with one exception (Reparenting, which should be enabled as soon as it stabilizes).

| Feature | Maturity | Impl Files | Test Files | Stdlib | Ecosystem Impact | Verdict |
|---------|----------|-----------|------------|--------|-----------------|---------|
| CoroutineAccessors | Near-stable | 22 lib + 12 include | 42 | Yes | 394 sites (primitives) + 3 (foundations) | **WAIT** |
| BorrowAndMutateAccessors | Maturing | 4 lib (25+ via AccessorKind) | 23 | Yes | ~86 sites (borrow eligible) | **WAIT** |
| UnderscoreOwned | Nascent | 1 lib (3 via attr) | 1 | No | 0 sites (workarounds exist) | **SKIP** |
| AddressableParameters | Maturing | 3 lib | 23 | Yes | 15-20 files (closure removal) | **WAIT** |
| AddressableTypes | Maturing | 3 lib | 27 | Yes | 3-6 types (@_rawLayout) | **WAIT** |
| BorrowInout | Nascent | 2 lib | 2 | Gate only | 50+ files (Property.View) | **SKIP** (for now) |
| CompileTimeValues | Maturing | 43 lib | 41 | No | ~90 static let constants | **WAIT** |
| StructLetDestructuring | Nascent | 2 lib | 2 | No | ~38 files (~Copyable structs) | **WAIT** |
| Reparenting | Maturing | 9 lib + 3 include | 12 | No | Protocol hierarchy evolution | **Enable when stable** |

## 2. Current Feature Flag Baseline

Both repos use a standardized set of swift settings across all packages:

```swift
.strictMemorySafety(),
.enableUpcomingFeature("ExistentialAny"),
.enableUpcomingFeature("InternalImportsByDefault"),
.enableUpcomingFeature("MemberImportVisibility"),
.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
.enableExperimentalFeature("Lifetimes"),
.enableExperimentalFeature("SuppressedAssociatedTypes"),
.enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
```

Per-package additions: `BuiltinModule` + `RawLayout` in swift-buffer/storage/memory-primitives. None of the nine assessed features are currently enabled in production. `AddressableTypes` is enabled in six experiments.

## 3. Per-Feature Analysis

### 3.1 CoroutineAccessors

**Maturity: Near-stable**

#### Compiler Analysis

CoroutineAccessors renames `_read`/`_modify` to `yielding borrow`/`yielding mutate`, graduating the underscored syntax to a proper language feature. The implementation spans 22 library files and 12 include headers, with 42 test files covering parsing, SIL generation, serialization, and library evolution. The stdlib already uses it internally behind the feature gate.

The feature is suppressible (can be disabled without breakage). Availability is gated as `FUTURE` — no ABI deployment target yet, which means library evolution builds cannot expose coroutine accessors in public API until an OS version ships with runtime support. There are 12 TODOs remaining in the compiler source, mostly around availability and diagnostics polish.

No crash paths or `llvm_unreachable` calls in the coroutine accessor code path. The near-stable assessment reflects the breadth of test coverage and stdlib adoption, tempered by the lack of a concrete ABI target.

#### Ecosystem Impact

394 sites across swift-primitives (225 `_read`, 169 `_modify`) and 3 in swift-foundations. Migration is purely mechanical: a sed replacement of `_read` to `yielding borrow` and `_modify` to `yielding mutate`. No semantic changes, no API surface change. The migration could be done in a single pass.

Before:
```swift
var storage: Storage {
    _read { yield _storage }
    _modify { yield &_storage }
}
```

After:
```swift
var storage: Storage {
    yielding borrow { yield _storage }
    yielding mutate { yield &_storage }
}
```

#### Verdict: WAIT

The feature is well-implemented but still experimental with no SE proposal number. The FUTURE availability gate means library evolution builds cannot use it in public API. Wait until it graduates from experimental; then execute the mechanical sed across all 394 sites.

---

### 3.2 BorrowAndMutateAccessors

**Maturity: Maturing**

#### Compiler Analysis

BorrowAndMutateAccessors introduces physical-address-returning `borrow` and `mutate` accessors (as opposed to the yielding coroutine variants). The direct implementation touches 4 library files, but the feature integrates deeply through `AccessorKind` (25+ files that switch on accessor kinds). 23 test files cover the basic paths.

**RED FLAG**: `llvm_unreachable("not implemented")` at `SILGenLValue.cpp:3656` for non-member variable borrow/mutate accessors. Applying borrow/mutate to module-level or local variables will crash the compiler. This limits the feature to member accessors only. The stdlib uses it behind the gate for a handful of types.

No SE proposal exists. The feature is not suppressible.

#### Ecosystem Impact

Approximately 86 sites are eligible: 56 `Property.View.Read` borrow accessors (currently using `_read` with yield) and 30 stored-property forwarding sites that could use direct borrow instead of coroutine yield. The benefit is eliminating coroutine overhead for simple forwarding accessors.

#### Verdict: WAIT

Too immature for production use. The crash path on non-member variables is a blocking red flag. No SE proposal means the API surface could change. Wait for a proposal and the crash path to be resolved.

---

### 3.3 UnderscoreOwned

**Maturity: Nascent**

#### Compiler Analysis

`@_owned` forces the compiler to use a `get` accessor instead of `_read` when accessing a property, ensuring the caller receives an owned copy. The implementation is minimal: 1 library file with 3 attribute-related touch points. A single test file covers the basic case. Not used in the stdlib.

#### Ecosystem Impact

Zero production usage. The need for `@_owned` is already addressed by existing patterns: `Property.View` and `Property.Consuming` provide explicit ownership transfer without needing a compiler attribute. There is no migration path because there are no sites that need it.

#### Verdict: SKIP

No production need, minimal implementation, existing workarounds are superior. This feature solves a problem we have already solved at the library level.

---

### 3.4 AddressableParameters

**Maturity: Maturing**

#### Compiler Analysis

`@_addressableSelf` (and future `@_addressable` on arbitrary parameters) guarantees that a borrowed parameter has a stable memory address for the duration of the call. 3 library files implement the attribute and SIL lowering, with 23 test files covering address stability, exclusivity, and interaction with other ownership features.

The attribute is `UserInaccessible` — it exists in the compiler but is not intended for end-user code yet. The stdlib uses it internally for types that need to pass `self` to C APIs or perform address-dependent operations.

#### Ecosystem Impact

15-20 files in primitives would benefit, primarily by removing `withUnsafePointer` closure indirection. The main beneficiaries are `Storage.Inline` types, `Property.View` accessors, and string primitive types that currently wrap operations in `withUnsafePointer(to: self)` closures to obtain a stable address.

Before:
```swift
func read<T>(_ body: (UnsafePointer<Element>) -> T) -> T {
    withUnsafePointer(to: _storage) { ptr in body(ptr) }
}
```

After (with @_addressableSelf):
```swift
@_addressableSelf
borrowing func read<T>(_ body: (UnsafePointer<Element>) -> T) -> T {
    body(UnsafePointer(Builtin.unprotectedAddressOfBorrow(self)))
}
```

#### Verdict: WAIT

Solid implementation with good test coverage, but `UserInaccessible` means it is not yet intended for external adoption. Adopt when it gets a proposal and the attribute becomes available to user code. Enable after AddressableTypes (which is a prerequisite for the full pattern).

---

### 3.5 AddressableTypes

**Maturity: Maturing**

#### Compiler Analysis

`@_addressableForDependencies` marks a type as requiring a stable address when borrowed, enabling lifetime-dependent results. 3 library files implement it, with 27 test files — the most of any feature in this assessment relative to implementation size. The feature is suppressible and `UserInaccessible`.

The stdlib uses it for types that vend dependent pointers (e.g., `Array`, `String` buffer access). The test coverage is thorough, including interaction with `~Copyable`, `~Escapable`, and lifetime annotations.

#### Ecosystem Impact

3 inline `_Raw` storage types and 3 wrapper types would benefit from the annotation. Six existing experiments in swift-primitives already use the feature successfully. The migration is minimal: add the attribute to type declarations.

#### Verdict: WAIT

The most mature of the addressable features. Enable first of the addressable pair (before AddressableParameters) when it gets a proposal. The existing experiments confirm it works correctly with our `@_rawLayout` types.

---

### 3.6 BorrowInout

**Maturity: Nascent**

#### Compiler Analysis

BorrowInout gates access to stdlib `Borrow<T>` and `Inout<T>` types for user code. The implementation is minimal: 2 library files that control the availability gate, 2 test files. The types themselves exist in the stdlib behind the gate. No SIL changes — this is purely an access control feature.

#### Ecosystem Impact

HIGH potential impact. The `Property.View` family is essentially a hand-rolled `Inout<Base>`, and `Property.View.Read` is a hand-rolled `Borrow<Base>`. Adopting stdlib `Borrow<T>`/`Inout<T>` would eliminate approximately 50 `base.pointee` sites and ~150 `unsafe` markers across the Property infrastructure.

However, the migration scope is massive: the entire Property.View type family would need redesign. Every consumer of Property.View across both repos would be affected.

#### Verdict: SKIP (for now)

The types are too experimental and the migration scope too large. When `Borrow<T>`/`Inout<T>` stabilize, they will be transformative for our ownership infrastructure, but premature adoption risks building on shifting foundations. Revisit when the types get a proposal.

---

### 3.7 CompileTimeValues

**Maturity: Maturing**

#### Compiler Analysis

`@const` and `@constInitialized` enable compile-time evaluation and constant folding. This feature has extraordinary implementation breadth: 43 library files spanning parsing, type-checking, SIL generation, serialization, demangling, and the driver. 41 test files cover the full pipeline.

A `CompileTimeValuesPreview` variant exists but is explicitly NOT marked `AvailableInProd`. The feature went through SE-0359, which was returned for revision; Pitch #3 is in progress. The breadth of the implementation suggests significant compiler team investment despite the proposal setback.

Not used in the stdlib. No crash paths identified.

#### Ecosystem Impact

Approximately 90 `static let` constants across both repos would benefit: ASCII code point tables, binary format markers, configuration constants. The annotation would enable the compiler to evaluate these at compile time rather than runtime initialization.

Before:
```swift
static let lineFeed: UInt8 = 0x0A
```

After:
```swift
@const static let lineFeed: UInt8 = 0x0A
```

Migration is mechanical but requires validating that each constant's initializer is compile-time evaluable.

#### Verdict: WAIT

Broad implementation and good test coverage, but the proposal has been returned for revision twice. Wait until SE-0359 (or its successor) is accepted. The migration is low-risk and can be done incrementally.

---

### 3.8 StructLetDestructuring

**Maturity: Nascent**

#### Compiler Analysis

StructLetDestructuring allows decomposing stored `let` properties in pattern matching. The implementation is minimal: 2 library files, 2 test files.

**RED FLAG**: The compiler source contains the comment "This hasn't ever been implemented properly" — the feature flag merely removes a diagnostic guard that prevents the syntax, without implementing proper semantic support. This is not a partially-implemented feature; it is an unimplemented feature behind a gate.

No SE proposal. Not used in the stdlib.

#### Ecosystem Impact

22 `~Copyable` structs in primitives and 18 in foundations have `let` fields that could benefit from destructuring. The pattern is common in our codebase: value types with immutable fields that currently require verbose property access.

#### Verdict: WAIT

Despite the ecosystem benefit, the compiler source explicitly states the implementation is incomplete. Do not enable — the diagnostic guard exists for a reason. Wait for a proper proposal and implementation.

---

### 3.9 Reparenting

**Maturity: Maturing**

#### Compiler Analysis

Reparenting enables retroactive protocol refinement: declaring that protocol A refines protocol B after both are defined, without an ABI break. The implementation is deep: 9 library files and 3 include headers, touching conformance lookup, generic signature building, and availability checking. 12 test files cover the core functionality.

The feature is `UserInaccessible`. The implementation handles the hard problems: conformance table updates, witness table thunking, and interaction with conditional conformances. This is one of the more carefully implemented features in the assessment.

#### Ecosystem Impact

18 protocols in swift-primitives and 4 in swift-foundations could benefit from reparenting. The key candidate is `Collection.Protocol : Sequence.Protocol` — currently impossible to express retroactively, forcing workarounds in our protocol hierarchy.

Unlike the other features, Reparenting has zero initial migration cost: enabling it adds a capability without requiring any code changes. Protocol refinements can be added incrementally as the hierarchy evolves.

#### Verdict: Enable when stable

This is the only feature that receives a positive recommendation. It addresses a documented stdlib limitation (inability to retroactively refine protocols), has deep implementation quality, zero initial migration cost, and enables protocol hierarchy evolution that is currently impossible. Enable as soon as it becomes available to user code.

## 4. Red Flags and Warnings

### DO NOT rely on

- **StructLetDestructuring**: The compiler source explicitly states "This hasn't ever been implemented properly." The flag removes a diagnostic guard without providing semantic support. Enabling it risks silent miscompilation.
- **BorrowAndMutateAccessors on non-member variables**: `llvm_unreachable` at `SILGenLValue.cpp:3656`. Applying borrow/mutate accessors to module-level or local variables will crash the compiler.

### Use with caution

- **CoroutineAccessors + library evolution**: The `FUTURE` availability gate means coroutine accessors in public API will not be available until an OS ships with runtime support. Internal-only usage is safe.
- **UnderscoreOwned**: A single test file provides minimal confidence. The feature could change or be removed without notice.
- **BorrowInout**: The stdlib types behind the gate are experimental and subject to redesign. Building infrastructure on them risks a large-scale rewrite.

### Safe to enable (when available to user code)

- **AddressableParameters/Types**: `UserInaccessible` indicates the compiler team considers them safe but not yet public. The stdlib uses them internally. Good test coverage.
- **CompileTimeValues**: Broad test suite (41 files) and deep implementation (43 files) indicate production quality, despite the proposal's revision history.
- **Reparenting**: Deep implementation across conformance, generics, and availability systems. 12 test files cover the core paths.

## 5. Adoption Priority Order

When features stabilize, adopt in this order (smallest risk/largest benefit first):

1. **AddressableTypes** — Annotate 3-6 `_Raw` types. Smallest diff, already validated in 6 experiments.
2. **AddressableParameters** — Remove `withUnsafePointer` closure indirection in 15-20 files. Requires AddressableTypes first.
3. **CoroutineAccessors** — Mechanical sed across 394 sites. Zero semantic risk, large cosmetic improvement.
4. **CompileTimeValues** — Annotate ~90 `static let` constants. Incremental, low-risk.
5. **Reparenting** — Protocol hierarchy evolution. Zero files initially; refinements added as needed.
6. **StructLetDestructuring** — When properly proposed and implemented. ~38 files benefit.
7. **BorrowAndMutateAccessors** — When proposed and the non-member crash path is fixed. ~86 sites.
8. **BorrowInout** — Requires full Property.View redesign. Largest migration (~50+ files, ~150 unsafe markers). Adopt last.

## 6. Method

Static analysis of the Swift compiler source at `/Users/coen/Developer/swiftlang/swift/` performed on 2026-03-03. File counts derived from grep across `lib/`, `include/`, `test/`, `stdlib/`, and `validation-test/` directories. Implementation maturity assessed by: number of files touched, presence in stdlib, test file count, presence of crash paths (`llvm_unreachable`, `fatalError`), TODO count, and suppressibility.

Ecosystem impact analysis performed across swift-primitives and swift-foundations on the same date. Site counts derived from grep for usage patterns (`_read`, `_modify`, `withUnsafePointer`, `static let`, `Property.View`, protocol declarations). Before/after examples verified against compiler behavior with each feature flag enabled.

Maturity tiers:
- **Nascent**: Minimal implementation (1-2 files), few tests, not in stdlib, no proposal.
- **Maturing**: Moderate implementation (3-10 files), good test coverage, may be in stdlib, may have a proposal.
- **Near-stable**: Broad implementation (10+ files), extensive tests, in stdlib, proposal in progress or accepted.
