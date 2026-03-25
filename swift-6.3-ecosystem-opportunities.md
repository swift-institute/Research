# Swift 6.3 Ecosystem Opportunities

<!--
---
version: 2.0.0
last_updated: 2026-03-25
status: RECOMMENDATION
tier: 2
workflow: Discovery [RES-012]
trigger: Swift 6.3 release (2026-03-20)
---
-->

## Context

Swift 6.3 was released on 2026-03-20. This document catalogs every change between Swift 6.2.4 and 6.3 that is relevant to the Swift Institute ecosystem, evaluates each for adoption opportunity, and identifies breaking changes worth making.

Source material:
- https://www.swift.org/blog/swift-6.3-released/
- `swiftlang/swift` branch `release/6.3`, diff `swift-6.2.4-RELEASE..HEAD`
- `include/swift/Basic/Features.def` diff

## Question

Which Swift 6.3 language and standard library changes create opportunities for the Swift Institute ecosystem — and which justify breaking changes?

---

## Analysis

### Category 1: Features Promoted to Baseline

These features were `LANGUAGE_FEATURE` or `SUPPRESSIBLE_LANGUAGE_FEATURE` in 6.2 and are now `BASELINE_LANGUAGE_FEATURE` in 6.3. Baseline means any Swift compiler that processes `.swiftinterface` files can assume them. This removes the need for `#if $FeatureName` guards.

| Feature | SE | 6.2 Status | 6.3 Status | Ecosystem Impact |
|---------|-----|------------|------------|-----------------|
| `ValueGenerics` | SE-0452 | `LANGUAGE_FEATURE` | `BASELINE` | Integer generics stable; `InlineArray` sugar unlocked |
| `ValueGenericsNameLookup` | SE-0452 | `LANGUAGE_FEATURE` | `BASELINE` | Static member lookup on value-generic types guaranteed |
| `NonescapableTypes` | SE-0446 | `LANGUAGE_FEATURE` | `BASELINE` | `~Escapable` in interfaces without guards |
| `MemorySafetyAttributes` (`@unsafe`) | SE-0458 | `SUPPRESSIBLE` | `BASELINE` | `@unsafe` always available |
| `IsolatedDeinit` | SE-0371 | `SUPPRESSIBLE` (experimental) | `BASELINE` | `isolated deinit` stable |
| `BitwiseCopyable2` | SE-0426 | `SUPPRESSIBLE` | `BASELINE` | `BitwiseCopyable` fully stable |
| `IsolatedAny` | SE-0431 | `CONDITIONALLY_SUPPRESSIBLE` | `BASELINE` | `@isolated(any)` always available |
| `BuiltinEmplaceTypedThrows` | — | `LANGUAGE_FEATURE` | `BASELINE` | Typed throws on `Builtin.emplace` stable |
| `LayoutPrespecialization` | — | Experimental | `BASELINE` | Layout pre-specialization available by default |

**Ecosystem opportunity**: Remove any `#if $ValueGenerics` or `#if $NonescapableTypes` guards. These features are now unconditional. Any `.swiftinterface` can use them freely.

---

### Category 2: Experimental → Language Feature Promotions

These moved from `-enable-experimental-feature` gating to always-on language features.

| Feature | 6.2 | 6.3 | Impact |
|---------|-----|-----|--------|
| `LifetimeDependenceMutableAccessors` | Experimental | `LANGUAGE_FEATURE` | Mutable accessors returning `~Escapable` — no flag needed |
| `InoutLifetimeDependence` | Experimental | `LANGUAGE_FEATURE` | `@_lifetime(&arg)` — no flag needed |
| `IsolatedDeinit` | `SUPPRESSIBLE` in experimental position | `BASELINE` | Now unconditional |
| `LayoutPrespecialization` | Experimental | `BASELINE` | Now unconditional |

**Ecosystem opportunity**:
- **`@_lifetime(&)` and mutable accessors**: The `Property.View` patterns and `MutableSpan`-style accessors no longer need experimental feature flags. Audit `Package.swift` for any `.enableExperimentalFeature("InoutLifetimeDependence")` or `"LifetimeDependenceMutableAccessors"` — these can be removed.
- **Isolated deinit**: Any actor types with cleanup logic can now use `isolated deinit` unconditionally.

---

### Category 3: New Language Features

#### SE-0491: Module Selectors (`Module::name`)

Graduated from experimental to `LANGUAGE_FEATURE`. Syntax: `Module::name` for disambiguation.

```swift
// Before (6.2): ambiguous or requires full qualification
import ModuleA
import ModuleB
let x = ModuleA.SomeType() // still works

// After (6.3): new disambiguation syntax
let x = ModuleA::SomeType()
```

Also: `Swift.Task`, `Swift.Regex` now work — replacing `_Concurrency.Task`, `_StringProcessing.Regex`.

**Ecosystem opportunity**: Low. Our namespace conventions (`Nest.Name`) already avoid most disambiguation needs. However, `Swift::` prefix could clarify intent in code that shadows stdlib types. Not worth a breaking change.

#### SE-0495: `@c` Attribute

Replaces experimental `CImplementation`. Swift functions/enums exposed to C with `@c`.

**Ecosystem opportunity**: Potentially relevant for L1 primitives that need C interop (e.g., `Darwin_Kernel_Primitives`, platform layer). Not an immediate priority — our C interop layer is minimal.

#### SE-0496: `@inline(always)` Attribute

Now a `SUPPRESSIBLE_LANGUAGE_FEATURE`. Officially sanctioned replacement for `@inline(__always)`.

**Ecosystem opportunity**: **HIGH**. Audit all uses of `@inline(__always)` across the ecosystem and replace with `@inline(always)`.

**GOTCHA discovered during Wave 1**: `@inline(always)` (SE-0496) **forbids combining with `@usableFromInline`**. The old `@inline(__always)` was a permissive internal attribute that allowed this combination; the new official form does not. The mechanical `sed` replacement `@inline(__always)` → `@inline(always)` is therefore NOT fully safe — any site that also has `@usableFromInline` will error.

**Fix**: Replace `@usableFromInline` with `@inlinable` on affected declarations. The intent of `@usableFromInline @inline(__always)` was always "make this available and force inlining across modules" — `@inlinable @inline(always)` achieves the same.

**Affected sites found**: 11 total in swift-primitives (4 in `Logic.Ternary.swift`, 7 in `Token.Keyword+Lookup.swift`). Other repos (especially swift-iso with 181 `@inline(always)` occurrences) must be audited for the same conflict before building with Swift 6.3.

#### SE-0497: `@export` Attribute

Exposes function implementations for cross-module optimization in ABI-stable libraries.

**Ecosystem opportunity**: Low for now. Our packages are not ABI-stable (no library evolution). File for future reference when/if we enable library evolution.

#### SE-0492: `@section` / `@used` + `#objectFormat`

Stabilized from `@_section` / `@_used`. Places globals in specific object file sections.

**Ecosystem opportunity**: Niche. Could be relevant for embedded targets or legal encoding metadata tables. Not actionable now.

#### SE-0487: `@nonexhaustive` Attribute

Replaces removed `@preEnumExtensibility`. Supports `warn` argument.

**Ecosystem opportunity**: Low. Our enums are mostly exhaustive by design. Could be useful for error enums if we ever adopt library evolution.

#### SE-0483: `InlineArray` Type Sugar

Type sugar for `InlineArray<N, Element>` — e.g., `[3 x Int]` or similar shorthand.

**Ecosystem opportunity**: **MEDIUM**. Audit `InlineArray` usage across primitives for readability improvements with the new sugar syntax.

#### SE-0479: `@abi` Attribute

Stable ABI decoupled from implementation — on functions, initializers, properties, subscripts.

**Ecosystem opportunity**: Low. No library evolution, no ABI stability concerns currently.

#### SE-0474: Borrow/Mutate Accessors (Experimental)

`borrow` and `mutate` accessor keywords. Still experimental (`BorrowAndMutateAccessors`).

**Ecosystem opportunity**: **VERY HIGH** but premature. These are the "yielding accessors" that would replace `_read`/`_modify`. When stabilized, this will be a massive migration across all `~Copyable` property access patterns. **Track but do not adopt yet** — still behind experimental flag.

---

### Category 4: Standard Library Changes

| Change | SE | Ecosystem Impact |
|--------|-----|-----------------|
| `Array.append` / `ContiguousArray.append` with `OutputSpan` | SE-0485 | Could improve buffer-building patterns in foundations |
| `Dictionary.Keys: Hashable`, `CollectionOfOne: Hashable`, `EmptyCollection: Hashable` | SE-0514 | Minor — unlocks `Set<Dictionary<K,V>.Keys>` patterns |
| `Mutex.withLockIfAvailable()` | SE-0512 | Relevant for async-primitives lock patterns |
| `isTriviallyIdentical(to:)` | SE-0494 | Memory region identity — relevant for buffer/storage layer |
| `EncodingError`/`DecodingError` `debugDescription` | SE-0489 | Nice-to-have, no action needed |
| `ExcludePrivateFromMemberwiseInit` default | SE-0502 | **BREAKING**: Private stored properties now excluded from memberwise init by default |

**SE-0502 warning**: `ExcludePrivateFromMemberwiseInit` is now enabled by default. Any struct with `private` stored properties that relied on the compiler-synthesized memberwise init including those properties will break. **Must audit.**

---

### Category 5: Concurrency Model Changes

#### SE-0466: Default Main Actor Isolation (Hardened)

Extensive work on default isolation semantics. Key behavioral changes:
- Extensions and members can apply default isolation
- Nested types of `nonisolated` types don't infer `@MainActor`
- Types conforming to `Sendable` prohibit `@MainActor` inference
- `isolated deinit` inferred in main-actor-by-default mode

**Ecosystem opportunity**: **LOW** for L1-L2 (no actors). **MEDIUM** for L3+ components with concurrency.

#### SE-0505: Task Local Values — REMOVED

The SE-0505 APIs were removed. Protocol requirements weak-linked.

**Ecosystem opportunity**: Verify no usage exists. If we adopted SE-0505 task-local scoping in async-primitives or pool-primitives, it's gone.

#### SE-0518: `~Sendable` (Experimental)

Opt-out of `Sendable` via `~Sendable`, mirroring `~Copyable`/`~Escapable`.

**Ecosystem opportunity**: **HIGH when stabilized**. This aligns with our inverse constraint philosophy. Track for adoption — would allow generic types to be explicitly non-`Sendable` without workarounds. Still experimental.

---

### Category 6: Experimental Features Added

| Feature | Description | Relevance |
|---------|-------------|-----------|
| `ForExpressions` | `for` as expression | Not yet enabled; track |
| `ManualOwnership` | Diagnostic groups for semantic copies | **HIGH** — `-Wwarning SemanticCopies` could catch unintended copies in `~Copyable` code |
| `BorrowAndMutateAccessors` | `borrow`/`mutate` keywords | Track for stabilization |
| `TildeSendable` | `~Sendable` | Track for stabilization |
| `EmbeddedExistentials` | `Any` in Embedded mode | Track for embedded targets |
| `ImportMacroAliases` | C macro alias imports | Low |
| `CompileTimeValuesPreview` | Compile-time values | **MEDIUM** — could enable compile-time legal statute validation |
| `DeferredCodeGen` | Embedded deferred codegen | Low |

---

### Category 7: Experimental Features Removed

| Removed | Replacement | Action Needed |
|---------|-------------|---------------|
| `SymbolLinkageMarkers` | `@section`/`@used` (SE-0492) | Replace any `@_section`/`@_used` usage |
| `CImplementation` | `@c` (SE-0495) | Replace any `@_cdecl` + `@implementation` usage |
| `ImportSymbolicCXXDecls` | Dropped | None — we don't use C++ interop in primitives |
| `SuppressCXXForeignReferenceTypeInitializers` | Dropped | None |
| `CopyBlockOptimization` | Integrated into default | None — optimizer does this automatically |

**Action**: Grep for `enableExperimentalFeature("SymbolLinkageMarkers")` and `enableExperimentalFeature("CImplementation")` in any `Package.swift`.

---

### Category 8: Compiler/Optimizer Improvements

| Change | Impact |
|--------|--------|
| `@_rawLayout` deinit requirement removed | May resolve compiler bug #86652 workaround |
| `@_rawLayout` in static globals (e.g., `Atomic`) | Enables `static let` with `Atomic` types |
| Enum tag comparison optimization | Performance improvement for heavy enum matching |
| Copy propagation non-escapable fixes | Correctness for `~Escapable` code paths |
| Typed throws constraint solving improvements | Fewer false positives in typed throws inference |

**`@_rawLayout` deinit**: Our `noncopyable-deinit-workaround.md` memory documents a workaround for compiler bug #86652 affecting value-generic deinit. The 6.3 changes to `@_rawLayout` destruction (removed deinit requirement, VWT-based destruction) may resolve this. **Must verify.**

---

### Category 9: Build & Tooling

| Change | Impact |
|--------|--------|
| Swift Build preview in SPM | Unified cross-platform build engine |
| `swift package show-traits` | Trait discovery for packages |
| `LibraryEvolution` as `OPTIONAL_LANGUAGE_FEATURE` | Can be enabled per-package independently |
| Prebuilt Swift Syntax for macros | Faster macro builds |

---

## Prioritized Opportunity Inventory

### Tier A: Immediate (Non-breaking or Low-risk Breaking)

| # | Opportunity | Scope | Breaking? | Effort |
|---|-------------|-------|-----------|--------|
| A1 | Remove `#if $ValueGenerics`, `#if $NonescapableTypes` guards | All repos | No | Low |
| A2 | Remove `.enableExperimentalFeature("InoutLifetimeDependence")` | Package.swift files | No | Low |
| A3 | Remove `.enableExperimentalFeature("LifetimeDependenceMutableAccessors")` | Package.swift files | No | Low |
| A4 | Remove `.enableExperimentalFeature("SymbolLinkageMarkers")` if present | Package.swift files | No | Low |
| A5 | Remove `.enableExperimentalFeature("CImplementation")` if present | Package.swift files | No | Low |
| A6 | Replace `@inline(__always)` → `@inline(always)` | All repos | Source-only | Low |
| A7 | Verify no SE-0505 task-local usage | async/pool primitives | N/A | Low |
| A8 | Test `@_rawLayout` deinit workaround (bug #86652) | primitives | Potential fix | Medium |

### Tier B: Strategic (Breaking, High Value)

| # | Opportunity | Scope | Breaking? | Effort |
|---|-------------|-------|-----------|--------|
| B1 | SE-0502 `ExcludePrivateFromMemberwiseInit` audit | All repos | Yes (behavioral) | Medium |
| B2 | `InlineArray` type sugar adoption | primitives | Source-breaking | Medium |
| B3 | Enable `-Wwarning SemanticCopies` (ManualOwnership) | All repos | Warning-breaking | Medium |
| B4 | `isTriviallyIdentical(to:)` for buffer identity | storage/buffer layer | API addition | Low |
| B5 | `Mutex.withLockIfAvailable()` adoption | async-primitives | API addition | Low |

### Tier C: Track for Stabilization

| # | Feature | Gate |
|---|---------|------|
| C1 | `borrow`/`mutate` accessors (SE-0474) | Experimental → Language Feature |
| C2 | `~Sendable` (SE-0518) | Experimental → Accepted |
| C3 | `ForExpressions` | Experimental → Accepted |
| C4 | `CompileTimeValues` (preview) | Experimental → Stable |

---

## Phase 2: Ecosystem Audit Results

Exhaustive grep of all ecosystem repositories on 2026-03-25. Scope: swift-primitives, swift-standards (including swift-ietf, swift-iso, swift-ieee, swift-ecma, swift-iec, swift-w3c, swift-whatwg, swift-incits), swift-foundations, rule-law, swift-law, swift-nl-wetgever. Excluded: `.build/`, `swiftlang/`, third-party forks.

---

### A1: Feature Guard Removal (`#if $BaselineFeature`)

**Result: NO ACTION NEEDED.**

Only 1 hit ecosystem-wide: `#if $IsolatedAny` in `swiftlang/swift` stdlib (not our code). Zero `#if $ValueGenerics`, `#if $NonescapableTypes`, or any other now-baseline feature guards in any ecosystem package.

---

### A2+A3: Experimental Feature Flags in Package.swift

#### Scale

| Repository | Package.swift files with `enableExperimentalFeature` |
|------------|------------------------------------------------------|
| swift-primitives | 133 |
| swift-foundations | 56 |
| swift-standards | 17 |
| swift-nl-wetgever | 1,057 |
| rule-law | 3 |
| swift-ietf | (counted in standards org) |
| swift-iso | (counted in standards org) |
| **Total** | **~1,390** |

#### Feature Flags in Use (our repos, excluding third-party)

| Flag | Count | Still Experimental in 6.3? | Action |
|------|-------|---------------------------|--------|
| `Lifetimes` | 210 | YES (`SUPPRESSIBLE_EXPERIMENTAL_FEATURE`) | Keep |
| `SuppressedAssociatedTypes` | 209 | YES (`EXPERIMENTAL_FEATURE`) | Keep |
| `SuppressedAssociatedTypesWithDefaults` | 209 | **NO — NOT IN FEATURES.DEF** | **REMOVE** |
| `RawLayout` | 7 | YES (`EXPERIMENTAL_FEATURE`) | Keep |
| `BuiltinModule` | 3 | YES (`EXPERIMENTAL_FEATURE`) | Keep |

#### CRITICAL FINDING: Ghost Feature Flag

**`SuppressedAssociatedTypesWithDefaults` does not exist in `Features.def` in either Swift 6.2.4 or 6.3.** All 209 Package.swift files pass a flag the compiler silently ignores. This is a no-op across the entire ecosystem that should be cleaned up.

#### Promoted Features (Experimental → Language Feature)

| Feature | Occurrences | Action |
|---------|-------------|--------|
| `InoutLifetimeDependence` | 2 (1 in apple/swift-collections, 1 in an experiment) | Remove from experiment Package.swift |
| `LifetimeDependenceMutableAccessors` | 0 | No action |
| `SymbolLinkageMarkers` | 1 (swift-testing experiment) | Remove from experiment Package.swift |
| `CImplementation` | 0 | No action |
| `LayoutPrespecialization` | 0 | No action |

#### Upcoming Feature Flags in Use

| Flag | Count | Swift Version | Status |
|------|-------|---------------|--------|
| `MemberImportVisibility` | 1,399 | Swift 7 | Valid — keep |
| `InternalImportsByDefault` | 1,392 | Swift 7 | Valid — keep |
| `NonisolatedNonsendingByDefault` | 1,380 | Swift 7 | Valid — keep |
| `ExistentialAny` | 1,376 | Swift 7 | Valid — keep |
| `InferSendableFromCaptures` | 1 | Swift 6 | **Redundant** — already on in Swift 6 mode |
| `GlobalActorIsolatedTypesUsability` | 1 | Swift 6 | **Redundant** — already on in Swift 6 mode |

---

### A6: `@inline(__always)` → `@inline(always)` Migration

**Total: 320 occurrences across ~83 files.**

| Repository | Occurrences | Files |
|------------|-------------|-------|
| swift-primitives | 87 | 37 |
| swift-iso (swift-iso-9899) | 181 | 23 |
| swift-foundations | 41 | 18 |
| swift-ietf | 10 | 4 |
| swift-whatwg | 1 | 1 |
| swift-standards (direct) | 0 | 0 |
| swift-nl-wetgever | 0 | 0 |
| rule-law | 0 | 0 |

**Dominant location**: swift-iso-9899 (ISO C standard library bindings) accounts for 57% of all occurrences. swift-primitives accounts for 27%.

**Key files in primitives** (by occurrence count):
- `swift-sequence-primitives`: `Sequence.Protocol+ForEach.swift` (4 occurrences)
- `swift-logic-primitives`: `Logic.Ternary.swift` (4 occurrences)
- `swift-cpu-primitives`: `CPU.Barrier.Hardware.swift` (3), `CPU.Cache.Prefetch.swift` (2)
- `swift-x86-primitives`: platform intrinsics (5 total)
- `swift-arm-primitives`: platform intrinsics (8 total)
- `swift-kernel-primitives`: `Kernel.Atomic.*` (3 total)
- `swift-windows-primitives`: `Windows.Interop.swift` (6)

**Key files in foundations**:
- `swift-io`: 32 occurrences across IO blocking/sharded/executor code
- `swift-ascii`: `UInt8+INCITS_4_1986.swift` (3)
- `swift-systems`: `System.topology.swift` (1)

**Remediation**: Global find-and-replace `@inline(__always)` → `@inline(always)`. Purely mechanical, zero semantic change. Can be done with `sed` across all repos in one pass.

---

### A7: SE-0505 Task Local Values (REMOVED)

**Result: NO DIRECT SE-0505 API USAGE.**

However, `TaskLocal` / `@TaskLocal` is used extensively for other purposes:

| Repository | Usage |
|------------|-------|
| swift-primitives | `Dependency.Scope.swift` (3 references) |
| swift-foundations | Heavy usage in swift-dependencies, swift-environment, swift-html-rendering, swift-css, swift-witnesses, swift-testing (30+ files) |

These are **not** SE-0505 "task local value scoping" APIs. They are standard `TaskLocal` property wrappers. No action needed.

**`import _Concurrency`**: Zero occurrences in any ecosystem source file. No migration to `Swift.Task` needed.

**`@_cdecl`**: 1 occurrence in ecosystem code: `swift-foundations/swift-tests/Sources/Tests Apple Testing Bridge/Test.Expectation.AppleBridge.swift:51`. Consider migrating to `@c` (SE-0495) when appropriate.

---

### A8: `@_rawLayout` Deinit Workaround (Bug #86652)

**MOST SIGNIFICANT FINDING.**

#### Current State

`@_rawLayout` is used in **7 production packages** (24 Package.swift files including experiments):
- `swift-storage-primitives` — `Storage.Inline`, `Storage.Pool.Inline`, `Storage.Arena.Inline`
- `swift-memory-primitives` — `Memory.Inline`
- `swift-buffer-primitives` / `swift-buffer-primitives-modularization` — `Buffer.Linked.Inline`
- `swift-dictionary-primitives` — dictionary inline storage
- `swift-list-primitives` — list inline storage
- `swift-tree-primitives` — tree inline storage

#### The `_deinitWorkaround` Pattern — 36 Instances

Every data structure type containing `Storage.Inline` uses:

```swift
private let _deinitWorkaround: AnyObject? = nil
```

This 8-byte-per-instance field forces the implicit destructor to treat the type as reference-bearing, allowing `deinit` bodies to execute. Without it, the compiler crashes on release builds.

**Affected packages** (36 sites total):
- `swift-queue-primitives` — Queue.Static, Queue.Small, Queue.DoubleEnded.Small, Queue.DoubleEnded.Static
- `swift-set-primitives` — Set.Ordered.Static, Set.Ordered.Small
- `swift-tree-primitives` — Tree.N.Inline, Tree.N.Small
- `swift-list-primitives` — List.Linked
- `swift-heap-primitives` — Heap.MinMax.Small, Heap.MinMax.Static
- `swift-array-primitives` — Array.Small, Array.Static
- `swift-stack-primitives` — Stack.Small, Stack.Static
- `swift-dictionary-primitives` — Dictionary.Ordered.Small, Dictionary.Ordered.Static
- `swift-buffer-primitives` / modularization — Buffer.Slab.Inline, Buffer.Ring.Small, etc.

#### Swift 6.3 Relevance

The 6.3 compiler changes:
1. **Removed deinit requirement** for `@_rawLayout` types (`8ae2a7b584f`, 2026-03-24)
2. **Force VWT-based destruction** (`3a8a19ad7d0`, 2026-03-24)
3. New SIL property `isOrContainsRawLayout` for correct destruction routing

**Verified 2026-03-25: BUG NOT FIXED.** The LLVM verifier crash persists in Swift 6.3 (Xcode 26.4). The minimal reproducer (`rawlayout-minimal-reproducer/Bug1Consumer`, release mode) still crashes with `"Instruction does not dominate all uses!"` on the LLVM `verify` pass.

The 6.3 `@_rawLayout` changes address a different aspect (removing the deinit *requirement*) — they do not fix the cross-module LLVM IR domination bug triggered by 2+ `@_rawLayout`+deinit fields from a generic enum.

**Result**: All 36 `_deinitWorkaround` fields must remain. Field-ordering constraint stays. No action possible until the upstream fix lands.

#### CopyPropagation Workaround (Property.View)

**Verified 2026-03-25: BUG FIXED in Swift 6.3.** The standalone reproducer (`swift-issue-copypropagation-nonescapable-mark-dependence`) builds and runs clean in release mode. The 6.3 copy propagation non-escapable fixes resolve `swiftlang/swift#88022`.

**Action**: Re-add `~Escapable` and `@_lifetime(borrow base)` annotations to all 7 Property.View types:
- `Property.View`
- `Property.View.Read`
- `Property.View.Typed<E>`
- `Property.View.Read.Typed<E>`
- `Property.View.Typed<E>.Valued<V>`
- `Property.View.Read.Typed<E>.Valued<V>`
- (Plus any `Valued.Valued` variants)

---

### B1: SE-0502 `ExcludePrivateFromMemberwiseInit`

**Result: NO ACTION NEEDED.**

Exhaustive audit of all structs with `private var`/`private let` stored properties across swift-primitives, swift-standards, and swift-foundations: every single one has an explicit `init()`. No struct relies on the compiler-synthesized memberwise init including private properties.

The ecosystem is already fully compliant with SE-0502.

---

### B2: `InlineArray` Type Sugar

**Scale**:
- swift-primitives: **503 occurrences** across 104 files
- swift-foundations: 5 occurrences across 1 file
- swift-standards: 0

`InlineArray` is a core building block in primitives — `Buffer.Linked.Inline`, `Bit.Vector.Static`, `Storage.Inline`, `Geometry.Ngon`, `Linear.Matrix`, `Linear.Vector`, `Hash.Table.Static`, and dozens more.

**Assessment**: Type sugar (SE-0483, `InlineArrayTypeSugar` feature) is a `LANGUAGE_FEATURE` in 6.3. However, the sugar syntax isn't documented in the blog post with concrete examples. Need to verify the exact syntax before planning migration. The sheer scale (503 occurrences) makes this a significant source-level change if pursued.

**Recommendation**: DEFERRED until sugar syntax is documented and verified working in 6.3 release toolchain.

---

### B3: `-Wwarning SemanticCopies` (ManualOwnership)

**Assessment**: The `ManualOwnership` experimental feature (`-enable-experimental-feature ManualOwnership`) gates two diagnostic groups: `SemanticCopies` and `DynamicExclusivity`. These are warning-level diagnostics that could catch unintended copies in `~Copyable` code.

**Recommendation**: Enable in swift-primitives only as a pilot. Add `.enableExperimentalFeature("ManualOwnership")` to packages with heavy `~Copyable` usage (buffer-primitives, storage-primitives, array-primitives, etc.) and evaluate diagnostic output.

---

### B4: `isTriviallyIdentical(to:)` (SE-0494)

**Assessment**: Useful for buffer/storage identity comparison. Not yet critical — current patterns use pointer equality. Track for adoption when buffer identity becomes a first-class API concern.

---

### B5: `Mutex.withLockIfAvailable()` (SE-0512)

**Mutex usage is extensive**:
- swift-primitives: 25+ files (async-primitives, pool-primitives, kernel-primitives, cache-primitives, etc.)
- swift-foundations: 30+ files (swift-io, swift-tests, swift-witnesses, swift-kernel, swift-effects, etc.)
- swift-iso: 8 files (POSIX thread bindings)

`withLockIfAvailable()` returns `nil` on contention instead of blocking. Useful for try-lock patterns.

**Assessment**: Audit existing code for try-lock patterns or lock-with-timeout patterns that could benefit. Not a blanket replacement — `withLockIfAvailable()` is for specific use cases where lock contention should be handled gracefully.

---

## Remediation Plan

### Wave 1: Mechanical (Zero Risk) — DONE 2026-03-25

| Task | Files | Method | Status |
|------|-------|--------|--------|
| Remove `SuppressedAssociatedTypesWithDefaults` from all Package.swift | 1,359 | sync script + `sed` | **DONE** |
| Replace `@inline(__always)` → `@inline(always)` | ~83 | `sed` across repos | **DONE** |
| Fix `@usableFromInline @inline(always)` → `@inlinable @inline(always)` | 11 | Manual (Logic.Ternary, Token.Keyword) | **DONE** (primitives only — audit other repos) |
| Update `sync-swift-settings.sh` canonical source | 1 | Manual edit | **DONE** |
| Update `generate-package-swift.py` canonical source | 1 | Manual edit | **DONE** |
| Remove redundant Swift 6 upcoming features | 2 | In third-party repos only — no action | N/A |

### Wave 2: Verify & Remove Workarounds — PARTIALLY DONE 2026-03-25

| Task | Prerequisite | Status |
|------|-------------|--------|
| Build `@_rawLayout` reproducer with Swift 6.3 `-c release` | Install 6.3 toolchain | **DONE — BUG NOT FIXED** |
| ~~Remove all `_deinitWorkaround` fields~~ | ~~Verified fix~~ | **BLOCKED** — bug #86652 persists |
| ~~Remove field-ordering constraint~~ | ~~Verified fix~~ | **BLOCKED** |
| Test Property.View with `~Escapable` re-added under 6.3 | Copy propagation fix verification | **DONE — BUG FIXED** |
| Remove `InoutLifetimeDependence` from experiment Package.swift | Already promoted | **DONE** |
| Update `SymbolLinkageMarkers` comment in experiment Package.swift | Replaced by SE-0492 | **DONE** |

### Wave 3: Strategic Adoption

| Task | Prerequisite | Scope |
|------|-------------|-------|
| `ManualOwnership` pilot in primitives | Decision | 5–10 packages |
| `InlineArray` type sugar adoption | Verify syntax, decide on readability | 104 files |
| `@c` migration for `@_cdecl` | Low priority, 1 file | swift-tests |
| `Mutex.withLockIfAvailable()` review | Identify try-lock patterns | ~55 files |

---

## Outcome

**Status**: RECOMMENDATION

### Phase 1: Catalog — COMPLETE (v1.0.0)
### Phase 2: Ecosystem Audit — COMPLETE (v2.0.0)

**Summary**: Wave 1 executed — 1,359 Package.swift cleaned of ghost flag, ~83 files migrated to `@inline(always)`, canonical scripts updated. Wave 2 partially complete — bug #86652 **NOT fixed** in Swift 6.3, `_deinitWorkaround` fields must remain. Property.View `~Escapable` re-addition and minor experiment cleanups still pending.

**Highest-value remaining action**: File upstream bug report with the minimal reproducer to get #86652 prioritized for Swift 6.4.

## References

- Swift 6.3 release blog: https://www.swift.org/blog/swift-6.3-released/
- `swiftlang/swift` branch `release/6.3`, tag `swift-6.3-RELEASE`
- Features.def diff: `git diff swift-6.2.4-RELEASE..HEAD -- include/swift/Basic/Features.def`
- Memory: `noncopyable-deinit-workaround.md` — compiler bug #86652
- Memory: `property-view-noncopyable-pattern.md` — Property.View patterns affected by lifetime dependence promotion
- Memory: `copypropagation-nonescapable-fix.md` — CopyPropagation Bug 2
- `swift-primitives/swift-buffer-primitives/Research/compiler-fix-86652.md` — full bug analysis
- `swift-primitives/swift-buffer-primitives/Research/compiler-fix-86652-consequences.md` — consequence analysis
