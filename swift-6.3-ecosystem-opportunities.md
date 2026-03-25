# Swift 6.3 Ecosystem Opportunities

<!--
---
version: 1.0.0
last_updated: 2026-03-25
status: IN_PROGRESS
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

**Ecosystem opportunity**: **HIGH**. Audit all uses of `@inline(__always)` across the ecosystem and replace with `@inline(always)`. This is a clean, non-functional breaking change that aligns with the official API.

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

## Outcome

**Status**: IN_PROGRESS

Phase 1 (this document): Catalog and prioritize — **COMPLETE**.

Phase 2 (next): `/audit` against ecosystem for Tier A and Tier B opportunities — grep for actual occurrences, quantify scope, produce actionable remediation plan.

## References

- Swift 6.3 release blog: https://www.swift.org/blog/swift-6.3-released/
- `swiftlang/swift` branch `release/6.3`, tag `swift-6.3-RELEASE`
- Features.def diff: `git diff swift-6.2.4-RELEASE..HEAD -- include/swift/Basic/Features.def`
- Memory: `noncopyable-deinit-workaround.md` — compiler bug #86652
- Memory: `property-view-noncopyable-pattern.md` — Property.View patterns affected by lifetime dependence promotion
- Memory: `copypropagation-nonescapable-fix.md` — CopyPropagation Bug 2
