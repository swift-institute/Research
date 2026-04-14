# Feature Flags Compiler Source Analysis

<!--
---
version: 1.0.0
date: 2026-03-03
source: https://github.com/swiftlang/swift
scope: Nine experimental feature flags relevant to ownership, accessors, and compile-time values
method: Static analysis of compiler source, test counts, implementation depth
status: SUPERSEDED
superseded_by: feature-flags-assessment.md
---
-->

> **SUPERSEDED** by [feature-flags-assessment.md](feature-flags-assessment.md) (2026-03-15). Retained for detailed compiler source references.

## Summary

Analysis of nine experimental Swift feature flags by examining the compiler source at
`https://github.com/swiftlang/swift`. Each feature is evaluated by its definition
in `Features.def`, implementation depth (file count across `lib/`, `include/`), test
coverage, known issues, and stdlib adoption.

All nine features are `EXPERIMENTAL_FEATURE` with `AvailableInProd = true`, meaning
the flag cannot be dropped in the future. None have an SE proposal number (SE = 0).

---

## Feature Definitions

Source: `https://github.com/swiftlang/swift/tree/main/include/swift/Basic/Features.def`

| Feature | Macro | AvailableInProd | Suppressible | Line |
|---------|-------|-----------------|--------------|------|
| CoroutineAccessors | `SUPPRESSIBLE_EXPERIMENTAL_FEATURE` | true | Yes | 528 |
| BorrowAndMutateAccessors | `EXPERIMENTAL_FEATURE` | true | No | 577 |
| UnderscoreOwned | `EXPERIMENTAL_FEATURE` | true | No | 621 |
| AddressableParameters | `EXPERIMENTAL_FEATURE` | true | No | 537 |
| AddressableTypes | `SUPPRESSIBLE_EXPERIMENTAL_FEATURE` | true | Yes | 538 |
| BorrowInout | `EXPERIMENTAL_FEATURE` | true | No | 624 |
| CompileTimeValues | `EXPERIMENTAL_FEATURE` | true | No | 547 |
| StructLetDestructuring | `EXPERIMENTAL_FEATURE` | true | No | 468 |
| Reparenting | `EXPERIMENTAL_FEATURE` | true | No | 615 |

---

## Per-Feature Analysis

### 1. CoroutineAccessors

**Maturity: MATURING (near-stable)**

Renames `_read`/`_modify` to `yielding borrow`/`yielding mutate`. This is the most
mature experimental feature in this set, with deep implementation across all compiler
layers.

**Definition**: `SUPPRESSIBLE_EXPERIMENTAL_FEATURE(CoroutineAccessors, true)` (line 528).
Suppressible means module interfaces emit dual declarations: one with the feature, one
without (falling back to `_read`/`_modify`).

**Implementation depth**: 22 files in `lib/` alone. Touches:
- Parse: `ParseDecl.cpp` (accessor keyword parsing, backward compat for `read`/`modify`)
- AST: `Decl.cpp`, `ASTPrinter.cpp`, `StorageImpl.cpp`, `FeatureSet.cpp`
- SIL: `SILFunctionType.cpp`, `SILDeclRef.cpp`, `SILSymbolVisitor.cpp`
- SILGen: `SILGenApply.cpp`
- IRGen: `GenCoro.cpp`, `GenCall.cpp`, `GenDecl.cpp`, `GenMeta.cpp`, `GenClass.cpp`,
  `IRGenModule.cpp`, `IRSymbolVisitor.cpp`, `TBDGen.cpp`, `Linking.cpp`
- Frontend: `CompilerInvocation.cpp`
- ASTGen: `SourceFile.swift`

Total files referencing feature (source + headers + tests): **70**.

**Include/Header depth**: `AccessorKinds.def` defines `YieldingBorrow` and `YieldingMutate`
as `YIELDING_ACCESSOR` gated on `CoroutineAccessors`. `StorageImpl.h` has
`requiresFeatureCoroutineAccessors()`. `FeatureAvailability.def` marks availability as
`FUTURE` with a TODO to change to a real version number. `PrintOptions.h` has
`SuppressCoroutineAccessors`. `SILOptions.h` has `CoroutineAccessorsUseYieldOnce2`.

**Test coverage**: 42 test files reference the feature flag.
- Parse: `coroutine_accessors.swift`, `coroutine_accessors_2.swift`, `coroutine_accessors_3.swift`, `coroutine_accessors_ambiguity.swift`
- Sema: `coroutine_accessors.swift`, `read_requirements.swift`
- SILGen: `coroutine_accessors.swift`, `coroutine_accessors_availability.swift`, `coroutine_accessors_back_deployment_abi.swift`, `coroutine_accessors_exec.swift`, `coroutine_accessors_skip.swift`, `coroutine_accessors_new_abi.swift`, `coroutine_accessors_old_abi.swift`, `default_override.swift`
- IRGen: `coroutine_accessors.swift`, `coroutine_accessors_future.swift`, `coroutine_accessors_past.swift`, `coroutine_accessors_popless.swift`, `run-coroutine_accessors.swift`, `CoroutineAccessorsDebugLoc.swift`, `coroutine_accessors_backdeploy_async_56.swift`, `coroutine_accessors_backdeploy_async_57.swift`
- SILOptimizer: `devirtualize_coroutine_accessors.sil`
- SIL serialization: `default_override.sil`
- ModuleInterface: `coroutine_accessors.swift`
- TBD: `coroutine_accessors.swift`
- Interpreter: `coroutine_accessors_default_implementations.swift`, `coroutine_accessors_old_abi_nounwind.swift`
- DebugInfo: `yielding_mutate.swift`, `yielding_mutate_line_numbers.swift`
- Validation: `test_coroutine_accessors.swift`

**Stdlib adoption**: Enabled in `stdlib/public/core/CMakeLists.txt` (not via the flag
itself, but the stdlib does use the underlying accessors). One reference in
`stdlib/public/core/Misc.swift` with a TODO to migrate from `_read` to `read`.

**Known issues (12 TODOs)**:
1. `FeatureAvailability.def:90`: "TODO: CoroutineAccessors: Change to correct version number." -- availability is currently `FUTURE`.
2. `ParseDecl.cpp:8126`: "TODO: After CoroutineAccessors gets turned on by default, we should ONLY accept these [read/modify] in interface files."
3. `GenDecl.cpp:3290`: "TODO: CoroutineAccessors: Implement replaceable function prologs."
4. `GenCall.cpp:2829`: "TODO: CoroutineAccessors: Optimize allocator kind (e.g. async callers...)"
5. `IRGenModule.cpp:187`: "TODO: CoroutineAccessors: The one caller of this function should just be..."
6. `Misc.swift:177`: "TODO: CoroutineAccessors: Change to read from _read."
7. Multiple test files with "TODO: CoroutineAccessors: Change to %target-swift-x.y-abi-triple" or "Change to X.Y" -- deployment target placeholders.
8. `run-coroutine_accessors.swift:93`: "TODO: CoroutineAccessors: Enable on WASM."

**Suppressibility**: When suppressed in module interfaces, the printer falls back to
emitting `_read`/`_modify` accessor bodies. Controlled by `SuppressCoroutineAccessors`
in `PrintOptions`. The `suppressingFeatureCoroutineAccessors()` function in
`ASTPrinter.cpp` sets this flag.

**Red flags**: The `FUTURE` availability means this feature has no ABI deployment target
yet. All availability-gated test cases use `SwiftStdlib 9999` as placeholder. This is
normal for pre-stabilization but means enabling it in library-evolution mode requires
careful deployment target management.

---

### 2. BorrowAndMutateAccessors

**Maturity: MATURING (active development)**

Introduces `borrow` and `mutate` accessors (distinct from `yielding borrow`/`yielding mutate`).
These are physical-address-returning accessors, not coroutine-based.

**Definition**: `EXPERIMENTAL_FEATURE(BorrowAndMutateAccessors, true)` (line 577).

**Implementation depth**: 4 files in `lib/` reference the feature flag directly:
- Parse: `ParseDecl.cpp` (parsing `borrow`/`mutate` keywords in accessor blocks)
- AST: `FeatureSet.cpp`
- ASTGen: `Decls.swift`, `SourceFile.swift`

However, the `AccessorKind::Borrow` and `AccessorKind::Mutate` enum cases touch **25 files
in SILGen alone** plus additional files in IRGen, Sema, and AST. The accessor infrastructure
is well-integrated.

Key implementation files:
- `StorageImpl.h`: `requiresFeatureBorrowAndMutateAccessors()`
- `AccessorKinds.def`: `BORROW_ACCESSOR(Borrow, borrow)` and `MUTATE_ACCESSOR(Mutate, mutate)`
- `SILGenLValue.cpp`: `BorrowMutateAccessorComponent` class (lines 2308-2343) -- fully
  implemented for member access via `emitBorrowMutateAccessor`. **However**, the non-member
  var path at line 3656 contains `llvm_unreachable("borrow/mutate accessor is not implemented")`
  -- non-member variables with borrow/mutate accessors will crash the compiler.

**Test coverage**: 23 test files.
- Parse: `borrow_and_mutate_accessors.swift`
- Sema: `borrow_and_mutate_accessors.swift`, `builtin_borrow.swift`
- SILGen: `borrow_accessor.swift`, `borrow_accessor_container.swift`,
  `borrow_accessor_evolution.swift`, `borrow_accessor_failures.swift`,
  `borrow_accessor_opaque.swift`, `borrow_accessor_protocol.swift`,
  `borrow_accessor_reabstraction.swift`, `borrow_accessor_synthesis.swift`,
  `borrow_accessor_afd.swift`, `builtin_borrow.swift`
- SILOptimizer: `moveonly_borrow_accessors.swift`, `borrow_accessor_address_only_non_escapable.swift`
- IRGen: `borrow_accessor.swift`, `borrow_accessor_large.swift`, `builtin_borrow.swift`
- Serialization: `borrow_accessor_client.swift`, `borrow_accessor_protocol_client.swift`
- ModuleInterface: `borrow_accessor_test.swift`
- SIL: `borrow_accessor_e2e.swift`

**Stdlib adoption**: Enabled in `stdlib/public/core/CMakeLists.txt`.

**Known issues**:
1. `SILGenLValue.cpp:3656`: `llvm_unreachable("borrow/mutate accessor is not implemented")` for non-member variables -- this is a **crash path**.
2. No diagnostics file references beyond the parsing gate (`DiagnosticsParse.def:335`).

**Red flags**: The `llvm_unreachable` in the non-member path means borrow/mutate accessors
on top-level or local variables will abort the compiler. This feature is safe for struct/class
member properties and protocol requirements only.

---

### 3. UnderscoreOwned

**Maturity: NASCENT (minimal, targeted)**

The `@_owned` attribute on properties/subscripts forces the conservative access pattern to
use `get` instead of `_read`, yielding an owned value. Primary use case: noncopyable types
where `_read` (yielding a borrow) is the default but `get` (returning owned) is needed.

**Definition**: `EXPERIMENTAL_FEATURE(UnderscoreOwned, true)` (line 621).

**Implementation depth**: Minimal -- only **1 file** in `lib/` references the feature flag:
- `FeatureSet.cpp`: `usesFeatureUnderscoreOwned()` checks for `OwnedAttr`

The actual attribute (`@_owned`) is defined at `DeclAttr.def:611` as
`SIMPLE_DECL_ATTR(_owned, Owned, OnVar | OnSubscript, ...)` and is implemented in:
- `TypeCheckAttr.cpp`: `visitOwnedAttr()` validates that the storage has a `get` accessor
- `TypeCheckStorage.cpp`: `OwnedAttr` check in opaque read ownership computation (line 1079)

Total implementation surface is ~3 files in `lib/` for the attribute, plus the FeatureSet gate.

**Test coverage**: 1 test file.
- `test/SILGen/owned_attr.swift` -- tests SIL generation for `@_owned` properties in
  resilient structs and protocols, including module interface emission.

**Stdlib adoption**: None.

**Known issues**: None found (no TODO/FIXME).

**Red flags**: Very narrow scope. The attribute itself is straightforward. However, the single
test file suggests limited edge-case coverage. The attribute is `NotSerialized` which means
it does not persist in binary module files -- it only affects source compilation and
`.swiftinterface` files (guarded by `$UnderscoreOwned` feature check).

---

### 4. AddressableParameters

**Maturity: MATURING**

The `@_addressableSelf` attribute on functions/accessors/constructors/subscripts ensures
the `self` parameter is addressable (has a stable address in memory). Related to lifetime
dependence.

**Definition**: `EXPERIMENTAL_FEATURE(AddressableParameters, true)` (line 537).

**Implementation depth**: 3 files in `lib/` reference the feature flag:
- `Sema/TypeCheckType.cpp`
- `Sema/TypeCheckAttr.cpp`
- `AST/FeatureSet.cpp`

Plus the attribute definition at `DeclAttr.def:860`:
`SIMPLE_DECL_ATTR(_addressableSelf, AddressableSelf, ...)` -- `UserInaccessible`.

The feature also connects to `SILOptions.h` which has addressable parameter options.

**Test coverage**: 23 test files reference the feature flag.
- Attribute: `attr_addressable.swift`, `attr_abi.swift`
- SILGen: `addressable_params.swift`, `addressable_members.swift`,
  `addressable_read.swift`, `addressable_representation.swift`,
  `addressable_capture_2.swift`, `if_guard_addressable.swift`,
  `lifetime_dependence_lowering.swift`
- SILOptimizer: `addressable_move_only_checking.swift`, `moveonly_addressors.swift`,
  `lifetime_dependence/projections.swift`, `lifetime_dependence/semantics.swift`,
  `lifetime_dependence/verify_diagnostics.swift`, `lifetime_dependence/verify_library_diagnostics.swift`,
  `lifetime_dependence/dependence_insertion.swift`
- Serialization: `lifetime_dependence.swift`
- C++ interop: `methods-addressable-dependency.swift`, `methods-addressable-silgen.swift`,
  `use-std-optional.swift`
- Validation: `lots_of_vars_for_addressable.swift`

**Stdlib adoption**: Enabled in `stdlib/public/core/CMakeLists.txt`.

**Known issues**: None found (no TODO/FIXME specific to AddressableParameters).

**Red flags**: The attribute is `UserInaccessible`, meaning it cannot be written in user
source code directly -- it is inferred or applied by the compiler/stdlib. This limits
its utility in third-party code.

---

### 5. AddressableTypes

**Maturity: MATURING**

The `@_addressableForDependencies` attribute on nominal types marks them as needing a
stable address for lifetime dependency tracking.

**Definition**: `SUPPRESSIBLE_EXPERIMENTAL_FEATURE(AddressableTypes, true)` (line 538).
Suppressible: module interfaces can omit `@_addressableForDependencies` for older compilers.

**Implementation depth**: 3 files in `lib/`:
- `AST/FeatureSet.cpp`: `usesFeatureAddressableTypes()` checks for `AddressableForDependenciesAttr`
- `AST/ASTPrinter.cpp`: `suppressingFeatureAddressableTypes()` excludes the attribute
- `Sema/TypeCheckAttr.cpp`

Attribute defined at `DeclAttr.def:865`:
`SIMPLE_DECL_ATTR(_addressableForDependencies, AddressableForDependencies, OnNominalType, ...)` -- `UserInaccessible`.

**Test coverage**: 27 test files.
- Includes lifetime dependence tests, SILOptimizer tests for addressable dependency
  optimization, serialization tests, module interface tests, and IRGen tests.

**Stdlib adoption**: Enabled in `stdlib/public/core/CMakeLists.txt`.

**Known issues**: None found.

**Red flags**: Like AddressableParameters, this is `UserInaccessible`. The suppressibility
mechanism is straightforward -- just excludes the attribute from the declaration.

---

### 6. BorrowInout

**Maturity: NASCENT**

Gates access to the standard library `Borrow<T>` and `Inout<T>` types outside of the
stdlib itself. These types represent borrowed and mutably-borrowed references.

**Definition**: `EXPERIMENTAL_FEATURE(BorrowInout, true)` (line 624).

**Implementation depth**: 2 files in `lib/`:
- `Sema/TypeCheckType.cpp`: `diagnoseBorrowInoutType()` -- emits a diagnostic if `Borrow`
  or `Inout` types are used without the feature flag (exempts stdlib and `_Concurrency`)
- `AST/FeatureSet.cpp`: marked as `UNINTERESTING_FEATURE` (never triggers interface emission)

**Test coverage**: 2 test files.
- `test/stdlib/Noncopyables/BorrowInout.swift`
- `test/stdlib/borrow_inout_requires_feature.swift`

**Stdlib adoption**: None (the feature gates *user* access to stdlib-defined types).

**Known issues**: None found.

**Red flags**: This is purely a gate -- the types exist in the stdlib already. The feature
just controls whether non-stdlib code can reference them. With only 2 test files and a
single diagnostic check, the scope is minimal but well-defined. The types themselves
(`Borrow<T>`, `Inout<T>`) are the complex part, and they live in the stdlib.

---

### 7. CompileTimeValues

**Maturity: MATURING (broad implementation)**

Enables the `@const` and `@constInitialized` attributes for compile-time value declarations.
Supports constant folding, extraction, and verification.

**Definition**: `EXPERIMENTAL_FEATURE(CompileTimeValues, true)` (line 547).
Also: `EXPERIMENTAL_FEATURE(CompileTimeValuesPreview, false)` (line 551) -- a preview variant
that bypasses syntactic legality checking. `CompileTimeValuesPreview` is **not** `AvailableInProd`.

**Implementation depth**: **43 files** in `lib/` reference `ConstVal`, `ConstInitialized`,
or `CompileTimeValues`:
- Sema: `TypeCheckType.cpp`, `TypeCheckAttr.cpp`, `TypeCheckDeclOverride.cpp`,
  `TypeCheckConstraints.cpp`, `LegalLiteralExprVerifier.cpp`, `LiteralExpressionFolding.cpp`
- AST: `Decl.cpp`, `ASTPrinter.cpp`, `FeatureSet.cpp`, `NameLookup.cpp`, `TypeRepr.cpp`,
  `ASTWalker.cpp`, `ASTDumper.cpp`, `ASTMangler.cpp`
- SIL: `SILFunctionType.cpp`, `SILGlobalVariable.cpp`, `SILBridging.cpp`
- SILOptimizer: `ConstExpr.cpp`, `OSLogOptimization.cpp`, `PassPipeline.cpp`,
  `ConstantEvaluatorTester.cpp`
- IRGen: `section.swift`-related files for `@_section` attribute
- Parse: `ParseDecl.cpp`, `ParsePattern.cpp`
- Serialization: `Serialization.cpp`, `Deserialization.cpp`
- Frontend: `CompilerInvocation.cpp`, `FrontendOptions.cpp`, `Frontend.cpp`,
  `FrontendTool.cpp`, `ArgsToFrontendOptionsConverter.cpp`, `ArgsToFrontendOutputsConverter.cpp`
- Driver: `Driver.cpp`, `ToolChains.cpp`
- Demangling: `Demangler.cpp`, `NodePrinter.cpp`, `OldRemangler.cpp`, `Remangler.cpp`
- ConstExtract: `ConstExtract.cpp`
- ClangImporter: `ImportDecl.cpp`
- ASTGen: `DeclAttrs.swift`, `Decls.swift`
- APIDigester: `ModuleAnalyzerNodes.cpp`
- Basic: `FileTypes.cpp`

Attributes defined at `DeclAttr.def:885-894`:
- `SIMPLE_DECL_ATTR(const, ConstVal, OnParam | OnVar | OnFunc, ...)`
- `SIMPLE_DECL_ATTR(constInitialized, ConstInitialized, OnVar, ...)`

**Test coverage**: 41 test files reference the feature flag.
- Dedicated `test/ConstValues/` directory with **30 test files** covering: integers,
  strings, tuples, floating point, inline arrays, optionals, conditions, references,
  modules, parameters, function types, diagnostics, binary expressions, arithmetic,
  WMO/non-WMO, C imports.
- Parse tests: `const.swift`, `const_no_feature.swift`, `constinitialized.swift`,
  `constinitialized_no_feature.swift`
- IRGen: `section.swift`, `section_structs.swift`, `section_errors.swift`, etc.

**Stdlib adoption**: None (the attributes are for user and library code).

**Known issues**: None found (no TODO/FIXME).

**Red flags**: This is a large feature with deep implementation across the compiler pipeline
including demangling, serialization, and the driver. The breadth suggests it is being
actively developed toward stabilization. The `CompileTimeValuesPreview` variant being
`AvailableInProd = false` suggests the full feature is not yet finalized.

---

### 8. StructLetDestructuring

**Maturity: NASCENT (minimal, single check)**

Allows stored `let` bindings in structs to use destructuring patterns (e.g.,
`let (x, y) = someValue`). This was never properly implemented and was previously
diagnosed as unsupported.

**Definition**: `EXPERIMENTAL_FEATURE(StructLetDestructuring, true)` (line 468).

**Implementation depth**: 2 files in `lib/`:
- `Sema/TypeCheckStorage.cpp`: Single gate at line 748 -- when the feature is disabled,
  compound stored `let` properties in structs with initializers are diagnosed as unsupported.
  When enabled, the diagnostic is suppressed.
- `AST/FeatureSet.cpp`: Marked as `UNINTERESTING_FEATURE` (no interface impact).

**Test coverage**: 2 test files.
- `test/ModuleInterface/stored-properties.swift`
- `test/ModuleInterface/stored-properties-client.swift`

**Stdlib adoption**: None.

**Known issues**: The comment at TypeCheckStorage.cpp:747 says "This hasn't ever been
implemented properly." The feature flag simply removes the diagnostic guard -- it does not
add new implementation logic.

**Red flags**: Enabling this feature removes a diagnostic that previously prevented use
of a feature that "hasn't ever been implemented properly." The fact that only the diagnostic
guard is removed, with no additional implementation, suggests this may rely on existing
codegen paths that happen to work but were never validated. The minimal test coverage
(2 files, both ModuleInterface-focused) reinforces this concern. Proceed with caution --
test thoroughly before relying on this in production.

---

### 9. Reparenting

**Maturity: MATURING**

Allows an existing protocol to retroactively refine a new protocol without breaking ABI.
Uses `@reparentable` on the new parent protocol and `extension ExistingProto: @reparented NewParent`
syntax.

**Definition**: `EXPERIMENTAL_FEATURE(Reparenting, true)` (line 615).

**Implementation depth**: 9 files in `lib/`:
- `Sema/TypeCheckAccess.cpp`: Availability checking for reparented extensions
- `Sema/TypeCheckAttr.cpp`: `visitReparentableAttr()` -- feature gate
- `Sema/TypeCheckStmt.cpp`
- `Sema/AssociatedTypeInference.cpp`: `ReparentingAssocTypeWitness` walker -- validates
  that type witnesses refer only to the reparented protocol
- `AST/Decl.cpp`: `isForReparenting()`, `getReparentingProtocols()`, protocol comparison
- `AST/NameLookup.cpp`: Associated type override handling for `@reparentable` protocols,
  `diagnoseDuplicateReparenting()`, `ReparentingProtocolsRequest` evaluation
- `AST/ProtocolConformance.cpp`: Creates protocol-to-protocol conformances for reparenting
- `AST/FeatureSet.cpp`: `usesFeatureReparenting()`
- `AST/RequirementMachine/RequirementLowering.cpp`: Skips reparenting extensions in
  requirement lowering

Headers:
- `Decl.h`: `isForReparenting()`, `getReparentingProtocols()`
- `NameLookupRequests.h`: `ReparentingProtocolsRequest`

Attribute at `DeclAttr.def:880`:
`SIMPLE_DECL_ATTR(reparentable, Reparentable, OnProtocol, ...)` -- `UserInaccessible`.

**Test coverage**: 10 test files + 2 validation tests.
- Sema: `reparenting.swift`
- ModuleInterface: `reparenting.swift`
- Availability: `availability_reparenting.swift`, `availability_reparenting_errors.swift`,
  `availability_reparenting_namelookup.swift`
- Generics: `reparenting_associated_types1-4.swift`, `conditional_conformances_reparenting.swift`
- Validation/Evolution: `test_protocol_add_reparented.swift`,
  `test_protocol_add_reparented_seq.swift` (with matching Inputs/)

**Stdlib adoption**: None.

**Known issues**: None found (no TODO/FIXME specific to Reparenting).

**Red flags**: The `@reparentable` attribute is `UserInaccessible`, so this is an
internal/stdlib-facing feature. The implementation is deep and well-tested across Sema,
AST, generics, and availability domains, with evolution/validation tests confirming ABI
compatibility. This appears well-designed for its intended use case (stdlib protocol
hierarchy evolution).

---

## Maturity Ranking

Ranked from most mature to least mature:

| Rank | Feature | Maturity | Impl Files | Test Files | Stdlib | Suppressible |
|------|---------|----------|-----------|------------|--------|-------------|
| 1 | **CoroutineAccessors** | Near-stable | 22 lib + 12 include | 42 | Yes | Yes |
| 2 | **CompileTimeValues** | Maturing | 43 lib | 41 | No | No |
| 3 | **Reparenting** | Maturing | 9 lib + 3 include | 12 | No | No |
| 4 | **AddressableTypes** | Maturing | 3 lib | 27 | Yes | Yes |
| 5 | **AddressableParameters** | Maturing | 3 lib | 23 | Yes | No |
| 6 | **BorrowAndMutateAccessors** | Maturing | 4 lib (25+ via AccessorKind) | 23 | Yes | No |
| 7 | **BorrowInout** | Nascent | 2 lib | 2 | Gate only | No |
| 8 | **UnderscoreOwned** | Nascent | 1 lib (3 via attr) | 1 | No | No |
| 9 | **StructLetDestructuring** | Nascent | 2 lib | 2 | No | No |

Notes on ranking:
- CoroutineAccessors leads because it has full-stack implementation (Parse through IRGen),
  extensive test coverage including evolution/interpreter tests, and suppressible interface
  support. The only thing preventing stabilization is the `FUTURE` availability target.
- CompileTimeValues ranks second due to extraordinary breadth (43 files including demangling,
  driver, serialization) and 30 dedicated ConstValues test files.
- Reparenting ranks third due to deep implementation across conformance, generics, name
  lookup, and availability, plus evolution validation tests.
- BorrowAndMutateAccessors has good test coverage but contains a `llvm_unreachable` crash
  path for non-member variables.

---

## Red Flags and Warnings

### DO NOT rely on (in production):

1. **StructLetDestructuring**: Removes a diagnostic guard for a feature the compiler source
   itself says "hasn't ever been implemented properly." Only 2 test files. High risk of
   subtle codegen bugs.

2. **BorrowAndMutateAccessors on non-member variables**: The SILGen path at
   `SILGenLValue.cpp:3656` contains `llvm_unreachable("borrow/mutate accessor is not implemented")`.
   Using `borrow`/`mutate` accessors on **member** properties is implemented; using them on
   top-level or local computed variables will crash the compiler.

### Use with caution:

3. **CoroutineAccessors + library evolution**: The availability is `FUTURE` (placeholder).
   All deployment-target-gated paths use `SwiftStdlib 9999`. This means ABI-stable libraries
   cannot yet deploy `yielding borrow`/`yielding mutate` to older runtimes. The suppressible
   interface mechanism mitigates this for API but not ABI.

4. **UnderscoreOwned**: Single test file. The attribute itself is simple and unlikely to
   break, but edge cases (generic contexts, protocol witnesses, distributed actors) are
   untested.

5. **BorrowInout**: The types exist in stdlib; the feature just gates user access. Safe to
   enable, but the types themselves are experimental stdlib API that may change.

### Safe to enable:

6. **AddressableParameters/AddressableTypes**: Both are `UserInaccessible` (compiler-internal).
   Well-tested through lifetime dependence test suite. Stdlib already uses them.

7. **CompileTimeValues**: Broad implementation, extensive test suite. The `@const` attribute
   is well-validated.

8. **Reparenting**: Deep implementation with evolution tests. `UserInaccessible` attribute
   limits exposure.

---

## Cross-Reference Table

| Feature | SE Proposal | Key Compiler Files |
|---------|------------|-------------------|
| CoroutineAccessors | None (SE=0) | `include/swift/AST/AccessorKinds.def`, `include/swift/AST/StorageImpl.h`, `include/swift/AST/FeatureAvailability.def`, `lib/Parse/ParseDecl.cpp`, `lib/AST/Decl.cpp`, `lib/AST/ASTPrinter.cpp`, `lib/SIL/IR/SILFunctionType.cpp`, `lib/IRGen/GenCoro.cpp`, `lib/IRGen/GenCall.cpp`, `lib/IRGen/GenDecl.cpp` |
| BorrowAndMutateAccessors | None (SE=0) | `include/swift/AST/AccessorKinds.def` (`BORROW_ACCESSOR`, `MUTATE_ACCESSOR`), `include/swift/AST/StorageImpl.h`, `include/swift/AST/DiagnosticsParse.def`, `lib/Parse/ParseDecl.cpp`, `lib/SILGen/SILGenLValue.cpp` (line 2308: `BorrowMutateAccessorComponent`; line 3656: **crash path**) |
| UnderscoreOwned | None (SE=0) | `include/swift/AST/DeclAttr.def` (line 611), `lib/Sema/TypeCheckAttr.cpp` (`visitOwnedAttr`), `lib/Sema/TypeCheckStorage.cpp` (line 1079), `lib/AST/FeatureSet.cpp`, `docs/ReferenceGuides/UnderscoredAttributes.md` |
| AddressableParameters | None (SE=0) | `include/swift/AST/DeclAttr.def` (line 860: `_addressableSelf`), `lib/Sema/TypeCheckType.cpp`, `lib/Sema/TypeCheckAttr.cpp`, `lib/AST/FeatureSet.cpp` |
| AddressableTypes | None (SE=0) | `include/swift/AST/DeclAttr.def` (line 865: `_addressableForDependencies`), `lib/AST/ASTPrinter.cpp` (`suppressingFeatureAddressableTypes`), `lib/Sema/TypeCheckAttr.cpp`, `lib/AST/FeatureSet.cpp` |
| BorrowInout | None (SE=0) | `lib/Sema/TypeCheckType.cpp` (`diagnoseBorrowInoutType`), `lib/AST/FeatureSet.cpp` |
| CompileTimeValues | None (SE=0) | `include/swift/AST/DeclAttr.def` (lines 885-894: `const`, `constInitialized`), `lib/Sema/TypeCheckAttr.cpp`, `lib/Sema/LegalLiteralExprVerifier.cpp`, `lib/Sema/LiteralExpressionFolding.cpp`, `lib/SILOptimizer/Utils/ConstExpr.cpp`, `lib/ConstExtract/ConstExtract.cpp`, `lib/Serialization/Serialization.cpp`, `lib/Demangling/Demangler.cpp` |
| StructLetDestructuring | None (SE=0) | `lib/Sema/TypeCheckStorage.cpp` (line 748: single gate), `lib/AST/FeatureSet.cpp` |
| Reparenting | None (SE=0) | `include/swift/AST/DeclAttr.def` (line 880: `reparentable`), `include/swift/AST/Decl.h`, `include/swift/AST/NameLookupRequests.h`, `lib/AST/Decl.cpp`, `lib/AST/NameLookup.cpp`, `lib/AST/ProtocolConformance.cpp`, `lib/AST/RequirementMachine/RequirementLowering.cpp`, `lib/Sema/TypeCheckAttr.cpp`, `lib/Sema/TypeCheckAccess.cpp`, `lib/Sema/AssociatedTypeInference.cpp` |

---

## Method

All data collected by static analysis of the compiler source tree at
`https://github.com/swiftlang/swift` on 2026-03-03. File counts are based on
`grep -r` for feature flag names across `lib/`, `include/`, `test/`, `stdlib/`, and
`validation-test/` directories. "Implementation files" count only `lib/` and `include/`
(excluding test and Features.def itself). "Test files" count files in `test/` and
`validation-test/` that reference the feature flag.
