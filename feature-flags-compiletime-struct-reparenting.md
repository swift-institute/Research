# Feature Flags: CompileTimeValues, StructLetDestructuring, Reparenting

<!--
---
version: 1.0.0
date: 2026-03-03
applies_to: [swift-primitives, swift-foundations]
status: SUPERSEDED
superseded_by: feature-flags-assessment.md
---
-->

> **SUPERSEDED** by [feature-flags-assessment.md](feature-flags-assessment.md) (2026-03-15). Retained for detailed ecosystem usage counts and before/after examples.

## Summary

Investigation of three experimental Swift feature flags for potential adoption across
`swift-primitives` and `swift-foundations`. These features span compile-time computation,
ownership ergonomics, and protocol hierarchy evolution.

| Feature | SE Proposal | Status | Verdict |
|---------|------------|--------|---------|
| `CompileTimeValues` | SE-0359 (returned for revision), Pitch #3 | Experimental | **Wait** |
| `StructLetDestructuring` | Pre-proposal | Experimental | **Wait** |
| `Reparenting` | None (compiler-internal) | Experimental | **Enable when stable** |

---

## 1. CompileTimeValues

### What It Does

The `CompileTimeValues` feature flag enables the `@const` attribute on declarations,
marking values as compile-time knowable. The compiler verifies that the value is
deterministic at compile time. This is distinct from existing integer generics
(`let N: Int` in type signatures), which are already in heavy use across the ecosystem.

Compiler description: "Allow declaration of compile-time values"

Related: `CompileTimeValuesPreview` bypasses syntactic legality checking for
experimentation.

### Relationship to Value Generics

The ecosystem already uses value generics extensively. The `@const` attribute would
complement them by enabling:

1. **Compile-time validation of arguments passed to value-generic types** -- e.g.,
   ensuring a capacity argument is a compile-time literal
2. **Compile-time extraction of metadata** -- SwiftPM plugins could read `@const`
   values without executing code
3. **Protocol requirements with compile-time guarantees** -- e.g., `@const static let
   alignment: Int` in a protocol

### Current Value Generic Usage (swift-primitives, Sources only)

| Metric | Count |
|--------|-------|
| Files using `<let ...: Int>` | 58 |
| Total value generic occurrences | 133 |
| Distinct value generic names | `capacity`, `N`, `n`, `inlineCapacity`, `bucketCapacity`, `wordCount` |

Packages with heaviest value generic usage:

| Package | Files | Primary Usage |
|---------|-------|---------------|
| swift-storage-primitives | 6 | `Storage.Inline<let capacity: Int>`, `Storage.Pool.Inline<let capacity: Int>` |
| swift-geometry-primitives | 9 | `Geometry.Ngon<let N: Int>`, `Geometry.Ball<let N: Int>`, etc. |
| swift-buffer-primitives | 5 | `Buffer.Linear.Inline<capacity>`, `Buffer.Ring.Inline<capacity>` |
| swift-array-primitives | 3 | `Array.Static<let capacity: Int>`, `Array.Bounded<let N: Int>` |
| swift-bit-vector-primitives | 6 | `Bit.Vector.Static<let wordCount: Int>`, `Bit.Vector.Inline<let capacity: Int>` |
| swift-algebra-linear-primitives | 2 | `Linear.Vector<let N: Int>`, arithmetic operators |
| swift-finite-primitives | 4 | `Ordinal.Finite<let N: Int>`, `Index.Bounded<let N: Int>` |
| swift-cyclic-index-primitives | 1 | `Index.Cyclic<let N: Int>` |
| swift-heap-primitives | 3 | `Heap.Static<let capacity: Int>`, `Heap.MinMax.Static<let capacity: Int>` |
| swift-tree-primitives | 4 | `Tree.N<let n: Int>`, `Tree.N.Inline<let capacity: Int>` |
| swift-dictionary-primitives | 1 | `Dictionary.Ordered.Static<let capacity: Int>` |
| swift-set-primitives | 1 | `Set.Static<let capacity: Int>` |

### Candidates for `@const` Annotation

#### 1. ASCII Code Points (swift-ascii-primitives)

`https://github.com/swift-primitives/swift-ascii-primitives/blob/main/Sources/ASCII Primitives/ASCII.ControlCharacters.swift`

```swift
// Current (35+ static let constants)
public static let nul: UInt8 = 0x00
public static let soh: UInt8 = 0x01
public static let lf: UInt8 = 0x0A
public static let cr: UInt8 = 0x0D
public static let esc: UInt8 = 0x1B
public static let del: UInt8 = 0x7F

// With @const
@const public static let nul: UInt8 = 0x00
@const public static let lf: UInt8 = 0x0A
```

Also: `ASCII.GraphicCharacters.swift` (50+ constants), `ASCII.Classification.swift`
(8 bit flags), `ASCII.CaseConversion.swift` (1 offset constant).

These are specification-mandated byte values. Marking them `@const` would:
- Enable the compiler to prove downstream usage is compile-time
- Allow future use in value generic positions (e.g., `Parser<@const ASCII.lf>`)

#### 2. Memory Constants (swift-memory-primitives)

`https://github.com/swift-primitives/swift-memory-primitives/blob/main/Sources/Memory Primitives Core/Memory.Shift.swift:42`

```swift
public static let maxValue: UInt8 = 63
```

#### 3. Binary Format Markers (swift-foundations/swift-plist)

`https://github.com/swift-foundations/swift-plist/blob/main/Sources/Plist Binary/Plist.Binary.Marker.swift`

```swift
static let null: UInt8 = 0x00
static let boolFalse: UInt8 = 0x08
static let boolTrue: UInt8 = 0x09
static let integerType: UInt8 = 0x10
static let real4: UInt8 = 0x22
static let dataType: UInt8 = 0x40
static let arrayType: UInt8 = 0xA0
static let dictType: UInt8 = 0xD0
// 14 constants total
```

#### 4. IO Configuration Constants (swift-foundations/swift-io)

`https://github.com/swift-foundations/swift-io/blob/main/Sources/IO Blocking Threads/IO.Blocking.Threads.Worker.swift:41`

```swift
static let drainLimit: Int = 16
```

`https://github.com/swift-foundations/swift-io/blob/main/Sources/IO/IO.Handle.Waiters.swift:51`

```swift
internal static let defaultCapacity: Int = 64
```

#### 5. Parser Whitespace Constants (swift-foundations/swift-parsers)

`https://github.com/swift-foundations/swift-parsers/blob/main/Sources/Parsers/Parsers.Whitespace.swift`

```swift
static let space: UInt8 = 0x20
static let tab: UInt8 = 0x09
static let lf: UInt8 = 0x0A
static let cr: UInt8 = 0x0D
// 6 constants total
```

### Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Feature returned for revision (SE-0359) | HIGH | Pitch #3 is in progress but not yet accepted |
| `@const` syntax may change | MEDIUM | Do not adopt until syntax stabilizes |
| Compile-time evaluation model unclear | MEDIUM | Pitch #3 scope is narrower than SE-0359 |
| `CompileTimeValuesPreview` is explicitly unstable | LOW | Never enable Preview variant |
| No ABI implications for `@const` on `static let` | LOW | Safe to adopt incrementally |

### Verdict: **Wait**

The feature's proposal (SE-0359) was returned for revision. Pitch #3 is a rewrite with
narrower scope. Until a proposal is accepted, do not enable `CompileTimeValues`.

When it stabilizes, the primary adoption path is:
1. Annotate ASCII code points and binary format markers with `@const`
2. Annotate configuration constants (`drainLimit`, `defaultCapacity`)
3. Explore `@const` protocol requirements for specification-mirroring types

The ~90 `static let` integer constants identified above are purely additive -- annotating
them with `@const` has no behavioral change and requires no API redesign.

---

## 2. StructLetDestructuring

### What It Does

Compiler description: "Allow destructuring stored `let` bindings in structs."

This feature enables decomposing a struct's stored `let` properties in pattern-matching
or assignment contexts, similar to tuple destructuring. For `~Copyable` structs, this is
particularly valuable because it enables consuming a struct by splitting it into its
constituent parts without requiring explicit `consuming func take()` methods.

### Current Pattern: Manual Decomposition

Throughout the codebase, `~Copyable` structs that need decomposition implement manual
`take()` or consume methods:

#### Example 1: Path.take() (swift-primitives)

`https://github.com/swift-primitives/swift-path-primitives/blob/main/Sources/Path Primitives/Path.swift:135`

```swift
public struct Path: ~Copyable, @unchecked Sendable {
    var pointer: UnsafeMutablePointer<Char>
    var count: Int
    // ...
    public consuming func take() -> (pointer: UnsafeMutablePointer<Char>, count: Int) {
        let p = pointer
        let c = count
        // ... prevent deinit cleanup ...
        return (pointer: p, count: c)
    }
}
```

#### Example 2: String.take() (swift-primitives)

`https://github.com/swift-primitives/swift-string-primitives/blob/main/Sources/String Primitives/String.swift:158`

```swift
public struct String: ~Copyable, @unchecked Sendable {
    // ...
    public consuming func take() -> (pointer: UnsafeMutablePointer<String.Char>, count: Int) {
        let p = pointer
        let c = count
        return (pointer: p, count: c)
    }
}
```

#### Example 3: Continuation decomposition (swift-primitives)

`https://github.com/swift-primitives/swift-effect-primitives/blob/main/Sources/Effect Primitives/Effect.Continuation.One.swift:86`

```swift
public struct One<Value: Sendable, Failure: Error>: ~Copyable, Sendable {
    internal let _resume: @Sendable (sending Result<Value, Failure>) async -> Void

    public consuming func onResume(
        _ callback: @escaping @Sendable (sending Result<Value, Failure>) async -> Void
    ) -> One<Value, Failure> {
        let original = _resume  // Manual extraction of the stored let
        return One { result in
            await callback(result)
            await original(result)
        }
    }
}
```

### ~Copyable Structs with `let` Stored Properties

#### swift-primitives (Sources only, excluding Experiments)

| File | Struct | `let` Properties |
|------|--------|-----------------|
| `swift-sequence-primitives/.../Sequence.Map.swift:48` | `Sequence.Map` | `_base`, `_transform` |
| `swift-sequence-primitives/.../Sequence.Filter.swift:26` | `Sequence.Filter` | `_base`, `_predicate` |
| `swift-sequence-primitives/.../Sequence.Drop.While.swift:27` | `Sequence.Drop.While` | `_base`, `_predicate` |
| `swift-sequence-primitives/.../Sequence.Prefix.While.swift:27` | `Sequence.Prefix.While` | `_base`, `_predicate` |
| `swift-sequence-primitives/.../Sequence.CompactMap.swift:26` | `Sequence.CompactMap` | `_base`, `_transform` |
| `swift-sequence-primitives/.../Sequence.Prefix.First.swift:28` | `Sequence.Prefix.First` | `_base`, `_count` |
| `swift-sequence-primitives/.../Sequence.Drop.First.swift:27` | `Sequence.Drop.First` | `_base`, `_count` |
| `swift-sequence-primitives/.../Sequence.Consume.View.swift:37` | `Sequence.Consume.View` | `_next` |
| `swift-sequence-primitives/.../Sequence.Map.Iterator.swift:41` | `Sequence.Map.Iterator` | `_transform`, `_mutableBuffer` |
| `swift-sequence-primitives/.../Sequence.Filter.Iterator.swift:22` | `Sequence.Filter.Iterator` | `_predicate`, `_mutableBuffer` |
| `swift-sequence-primitives/.../Sequence.CompactMap.Iterator.swift:23` | `Sequence.CompactMap.Iterator` | `_transform`, `_mutableBuffer` |
| `swift-sequence-primitives/.../Sequence.Prefix.While.Iterator.swift:22` | `Sequence.Prefix.While.Iterator` | `_predicate` |
| `swift-sequence-primitives/.../Sequence.Drop.While.Iterator.swift:25` | `Sequence.Drop.While.Iterator` | `_predicate` |
| `swift-graph-primitives/.../Graph.Traversal.First.Breadth.swift:12` | `Graph.Traversal.First.Breadth` | `storage`, `extract` |
| `swift-graph-primitives/.../Graph.Traversal.First.Depth.swift:18` | `Graph.Traversal.First.Depth` | `storage`, `extract` |
| `swift-ordering-primitives/.../Ordering.Comparator.swift:62` | `Ordering.Comparator` | `compare` |
| `swift-ordering-primitives/.../Ordering.PartialComparator.swift:35` | `Ordering.PartialComparator` | `compare` |
| `swift-ordering-primitives/.../Ordering.Projection.swift:42` | `Ordering.Projection` | `extract`, `direction` |
| `swift-kernel-primitives/.../Kernel.File.Handle.swift:43` | `Kernel.File.Handle` | `descriptor`, `direct`, `requirements` |
| `swift-kernel-primitives/.../Kernel.Environment.Entry.swift:21` | `Kernel.Environment.Entry` | `_name`, `_value` |
| `swift-affine-primitives/.../Affine.Discrete.Ratio.swift:45` | `Affine.Discrete.Ratio` | `factor` |
| `swift-binary-parser-primitives/.../Binary.Bytes.Input.View.swift:47` | `Binary.Bytes.Input.View` | `span` |

#### swift-foundations (Sources only, excluding Experiments/.build)

| File | Struct | `let` Properties |
|------|--------|-----------------|
| `swift-io/.../IO.Event.Poll.Loop.Context.swift:13` | `IO.Event.Poll.Loop.Context` | `driver`, `eventBridge`, `replyBridge`, `registrationQueue`, `shutdownFlag`, `nextDeadline`, `eventBufferPool` (7) |
| `swift-io/.../IO.Completion.Poll.Context.swift:24` | `IO.Completion.Poll.Context` | `driver`, `submissions`, `wakeup`, `bridge`, `shutdownFlag` (5) |
| `swift-io/.../IO.Event.Channel.swift:53` | `IO.Event.Channel` | `selector`, `descriptor`, `id`, `lifecycle` (4) |
| `swift-io/.../IO.Completion.Channel.swift:40` | `IO.Completion.Channel` | `queue`, `descriptor` |
| `swift-io/.../IO.Completion.Driver.Handle.swift:30` | `IO.Completion.Driver.Handle` | `_raw`, `_descriptor`, `_ringPtr` |
| `swift-io/.../IO.Event.Driver.Handle.swift:27` | `IO.Event.Driver.Handle` | `_raw`, `_descriptor` |
| `swift-io/.../IO.Event.Channel.Shutdown.swift:15` | `IO.Event.Channel.Shutdown` | `lifecycle`, `descriptor` |
| `swift-io/.../IO.Event.Backoff.Exponential.swift:59` | `IO.Event.Backoff.Exponential` | `maxSpinIterations`, `yieldThreshold` |
| `swift-io/.../IO.Event.Token.swift:44` | `IO.Event.Token` | `id` |
| `swift-io/.../IO.Event.Arm.Request.swift:14` | `IO.Event.Arm.Request` | `interest`, `deadline` |
| `swift-io/.../IO.Event.Arm.Result.swift:14` | `IO.Event.Arm.Result` | `event` |
| `swift-io/.../IO.Event.Register.Result.swift:14` | `IO.Event.Register.Result` | `id` |
| `swift-io/.../IO.Blocking.Threads.Job.Instance.swift:37` | `IO.Blocking.Threads.Job.Instance` | `ticket`, `context`, `operation` |
| `swift-io/.../IO.Executor.Teardown.swift:30` | `IO.Executor.Teardown` | `action` |
| `swift-kernel/.../Kernel.Thread.Worker.swift:50` | `Kernel.Thread.Worker` | `token` |
| `swift-memory/.../Memory.Map.swift:72` | `Memory.Map` | `offsetDelta`, `userLength`, `sharing`, `safety` |
| `swift-tests/.../Test.Reporter.Sink.swift:33` | `Test.Reporter.Sink` | `_impl` |
| `swift-paths/.../Path.View.swift:33` | `Path.View` | `pointer` |

### What Destructuring Would Enable

With `StructLetDestructuring`, the manual `take()` pattern becomes unnecessary:

```swift
// Before: Manual decomposition
public consuming func take() -> (pointer: UnsafeMutablePointer<Char>, count: Int) {
    let p = pointer
    let c = count
    return (pointer: p, count: c)
}

// After: Compiler-supported destructuring (hypothetical syntax)
let path: Path = ...
let { pointer, count } = consume path
```

For the lazy sequence pipeline types, destructuring would enable cleaner consuming
`makeIterator()` implementations:

```swift
// Before: accessing stored lets in consuming context
public consuming func makeIterator() -> Iterator {
    Iterator(base: _base.makeIterator(), predicate: _predicate)
}

// After: destructuring could make the field moves explicit
let { _base, _predicate } = consume self
return Iterator(base: _base.makeIterator(), predicate: _predicate)
```

The primary benefit is **expressiveness** rather than capability -- the compiler already
allows field access in consuming contexts. The value is in making the ownership transfer
visually explicit and in enabling future pattern-matching on ~Copyable struct values.

### Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| No accepted SE proposal | HIGH | Feature may change or be removed |
| Syntax not finalized | HIGH | `let { ... } = value` is speculative |
| Interaction with `deinit` unclear | MEDIUM | Structs with deinit may not be destructurable |
| Limited immediate benefit | LOW | Current code works; improvement is ergonomic |

### Verdict: **Wait**

The feature has no accepted proposal and the syntax is not finalized. The existing
manual decomposition patterns work correctly. When the feature stabilizes:

1. **First candidates**: `Path.take()`, `String.take()`, `Tagged.take()` -- these
   manual tuple-returning consuming functions could be replaced
2. **Sequence pipeline types**: 13 ~Copyable lazy sequence wrappers with `let` fields
   would benefit from explicit destructuring in `consuming func` bodies
3. **IO context types**: `IO.Event.Poll.Loop.Context` (7 let fields) and
   `IO.Completion.Poll.Context` (5 let fields) are the largest candidates

---

## 3. Reparenting

### What It Does

Compiler description: "Allows an existing protocol to refine a new one, without ABI break."

This feature enables adding a new protocol inheritance relationship to an existing
protocol after the fact. Normally, adding `protocol A: B` changes the witness table
layout and breaks ABI. With `Reparenting`, the compiler generates the conformance
check at the call site rather than encoding it in the witness table, preserving ABI.

### Relevance to the Ecosystem

This feature is directly relevant to a documented challenge in the primitives. From
`https://github.com/swift-primitives/swift-sequence-primitives/blob/main/Research/sequence-iterator-protocol-architecture.md:604`:

> The Swift stdlib team attempted to reparent `Sequence` on `BorrowingSequence`:
>
> - **Pitch**: Borrowing Sequence (forums.swift.org/t/pitch-borrowing-sequence/84332)
> - **Implementation + revert**: Commit `de749cea18f` -- "Don't reparent Sequence with BorrowingSequence"
> - **Reasons**: Conditional conformance issues, source compatibility, Escapable conflicts

The `Reparenting` feature flag exists precisely to solve this class of problem.

### Protocol Hierarchies in swift-primitives (Sources only)

| Protocol | Refines | Package |
|----------|---------|---------|
| `Sequence.Protocol` | `~Copyable, ~Escapable` | swift-sequence-primitives |
| `Sequence.Iterator.Protocol` | `~Copyable, ~Escapable` | swift-sequence-primitives |
| `Sequence.Borrowing.Protocol` | (standalone) | swift-sequence-primitives |
| `Sequence.Clearable` | `Sequence.Protocol & ~Copyable` | swift-sequence-primitives |
| `Collection.Protocol` | `~Copyable` | swift-collection-primitives |
| `Collection.Bidirectional` | `Collection.Protocol & ~Copyable` | swift-collection-primitives |
| `Collection.Clearable` | `Collection.Protocol & ~Copyable` | swift-collection-primitives |
| `Collection.Slice.Protocol` | `Collection.Protocol & ~Copyable` | swift-collection-primitives |
| `Collection.Remove.Last` | `Collection.Protocol & ~Copyable` | swift-collection-primitives |
| `Comparison.Protocol` | `~Copyable` | swift-comparison-primitives |
| `Equation.Protocol` | `~Copyable` | swift-equation-primitives |
| `Hash.Protocol` | `~Copyable` | swift-hash-primitives |
| `Set.Protocol` | `~Copyable` | swift-set-primitives |
| `Array.Protocol` | `Collection.Bidirectional & ~Copyable` | swift-array-primitives |
| `Viewable` | `~Copyable` | swift-identity-primitives |
| `Effect.Protocol` | `Sendable` | swift-effect-primitives |
| `Effect.Handler` | `Sendable` | swift-effect-primitives |
| `Effect.Continuation` | `~Copyable, Sendable` | swift-effect-primitives |

### Protocol Hierarchies in swift-foundations (Sources only)

| Protocol | Refines | Package |
|----------|---------|---------|
| `EffectWithHandler` | `Effect.Protocol` | swift-effects |
| `Dependency.Key.Strict` | `Witness.Key` | swift-dependencies |
| `Witness.Key` | `Sendable` | swift-witnesses |
| `HTMLElementNoAttributes` | `HTML.Element.Protocol` | swift-html-rendering |

### Concrete Reparenting Candidates

#### Candidate 1: Collection.Protocol : Sequence.Protocol

Currently, `Collection.Protocol` deliberately does NOT refine `Sequence.Protocol`
(documented in `Collection.Protocol.swift:40`):

> `Collection.Protocol` does not inherit from `Sequence.Protocol`. Collections iterate
> via index traversal (`startIndex`, `index(after:)`), not via `makeIterator()` / `next()`.

This is a design decision, not a limitation. However, if the team later decides that
collections should provide sequence-compatible iteration, `Reparenting` would enable
adding `protocol Collection.Protocol: Sequence.Protocol` without breaking existing
compiled modules.

#### Candidate 2: Sequence.Protocol : Sequence.Borrowing.Protocol

The stdlib tried and reverted exactly this pattern. If `Reparenting` matures, making
all sequences also borrowing-capable becomes viable without the ABI break that forced
the stdlib revert.

#### Candidate 3: Hash.Protocol : Equation.Protocol

Logically, anything hashable should be equatable. Adding `Hash.Protocol: Equation.Protocol`
would be a sound refinement that currently cannot be done post-hoc.

#### Candidate 4: Cross-Layer Protocol Evolution

As the five-layer architecture grows, Layer 2 (Standards) and Layer 3 (Foundations)
protocols may need to refine Layer 1 (Primitives) protocols. `Reparenting` would
enable this evolution without coordinated major version bumps.

### Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| No SE proposal | HIGH | Feature may change or be removed |
| ABI interaction with ~Copyable witness tables | MEDIUM | Unclear if ~Copyable protocols are supported |
| Feature may be stdlib-only | MEDIUM | May require resilience features not available to packages |
| Premature reparenting locks in hierarchy decisions | LOW | Only reparent when the relationship is proven sound |

### Verdict: **Enable when stable**

`Reparenting` addresses a real, documented limitation in the ecosystem. The stdlib
sequence reparenting revert demonstrates the need. The protocol hierarchies in
swift-primitives (18 protocols) and swift-foundations (4 protocols) are young enough
that reparenting decisions can be deferred, but when the feature is production-ready,
it removes a major barrier to protocol hierarchy evolution.

Do NOT enable now -- the feature has no proposal and the interaction with `~Copyable`
witness tables is unverified. Monitor for:
1. An SE proposal covering `Reparenting`
2. Test results with `~Copyable` protocol hierarchies
3. Confirmation it works for non-resilient (package) modules

---

## 4. Current Feature Flag Baseline

### Ecosystem-Wide (applied via `for target in package.targets` loop)

All packages in both repos apply these flags uniformly:

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

### Per-Package Additions (swift-primitives)

| Package | Additional Experimental Flags |
|---------|------------------------------|
| swift-buffer-primitives | `BuiltinModule`, `RawLayout` |
| swift-storage-primitives | `BuiltinModule`, `RawLayout` |
| swift-memory-primitives | `BuiltinModule`, `RawLayout` |
| swift-path-primitives | (none beyond ecosystem) |
| swift-ownership-primitives | (none beyond ecosystem) |

### Per-Package Additions (swift-foundations)

No packages in swift-foundations add experimental flags beyond the ecosystem baseline.

### Absent from Both Repos

None of the three investigated features are currently enabled:
- `CompileTimeValues` -- not enabled anywhere
- `StructLetDestructuring` -- not enabled anywhere
- `Reparenting` -- not enabled anywhere

---

## 5. Adoption Roadmap

### Phase 1: Monitor (Now)

- Track SE proposal status for all three features
- Run `swift -print-supported-features` on each toolchain update to verify availability
- Create an experiment package to test `StructLetDestructuring` with existing
  ~Copyable structs (particularly `Sequence.Map`, `Sequence.Filter`)

### Phase 2: Experimental Validation (When proposals advance)

- **CompileTimeValues**: Add `@const` to ASCII constants in an experiment. Verify
  no compile-time errors and no runtime behavior change.
- **StructLetDestructuring**: Test destructuring `Path`, `String`, `Effect.Continuation.One`
  in an experiment. Verify `deinit` interaction.
- **Reparenting**: Test adding `Hash.Protocol: Equation.Protocol` in an isolated
  experiment. Verify witness table generation with `~Copyable` protocols.

### Phase 3: Ecosystem Adoption (When features are accepted)

| Feature | Scope | Estimated Files |
|---------|-------|-----------------|
| `CompileTimeValues` | ASCII constants, binary markers, config constants | ~8 files, ~90 `static let` |
| `StructLetDestructuring` | ~Copyable consuming functions | ~20 files in primitives, ~18 in foundations |
| `Reparenting` | Protocol hierarchy evolution | 0 files initially (enables future changes) |
