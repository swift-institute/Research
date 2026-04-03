# Foundations Pre-Publication Audit: swift-file-system Dependency Tree

**Date**: 2026-04-03
**Scope**: 17 packages, 605 source files in `/Users/coen/Developer/swift-foundations/`
**Packages**: swift-ascii, swift-async, swift-clocks, swift-darwin, swift-dependencies, swift-environment, swift-io, swift-kernel, swift-linux, swift-memory, swift-paths, swift-pools, swift-posix, swift-strings, swift-systems, swift-witnesses, swift-windows

## Summary

| Priority | Category | Findings | Verdict |
|----------|----------|----------|---------|
| P0 | Foundation imports | 0 | Clean |
| P1 | Multi-type files [API-IMPL-005] | 30 files | 3 severe, 10 moderate, 17 minor |
| P1 | Compound type names [API-NAME-001] | 5 names | 2 documented workarounds, 3 real |
| P1 | Untyped throws [API-ERR-001] | 3 functions | 1 real violation |
| P2 | Methods in type bodies [API-IMPL-008] | 35 types | Concentrated in swift-io |

---

## P0: Foundation Imports

**Result: CLEAN** -- Zero `import Foundation` across all 605 source files.

---

## P1: Multi-type Files [API-IMPL-005]

### Severe (5+ types in one file)

| Package | File | Types | Lines |
|---------|------|-------|-------|
| swift-witnesses | `Sources/Witnesses Macros Implementation/WitnessMacro.swift` | 13 | 1494 |
| swift-witnesses | `Sources/Witnesses Macros Implementation/EnumExpansion.swift` | 5 | 360 |
| swift-io | `Sources/IO Blocking Threads/IO.Blocking.Threads.Metrics.swift` | 7 | 134 |
| swift-io | `Sources/IO Blocking/IO.Backpressure.Policy.swift` | 6 | 173 |

**Note on WitnessMacro.swift**: This is a macro implementation file (1494 lines) containing `WitnessMacro`, `DeriveOptions`, `ClosureProperty`, `ClosureParameter`, `NonClosureProperty`, plus generated type templates (`Calls`, `Prisms`, `Outcome`, `Case`, `Result`). The generated templates are source-generation output embedded in the macro, not independent API types. The helper structs (`ClosureProperty`, `ClosureParameter`, `NonClosureProperty`, `DeriveOptions`) are private/internal to the macro implementation. Severity is structural rather than API-surface.

### Moderate (3 types in one file)

| Package | File | Types | Nature |
|---------|------|-------|--------|
| swift-async | `Sources/Async Stream/Async.Stream.Map.Flat.Latest.State.swift` | 3 | `Latest` namespace + `State` actor + `Transform` enum |
| swift-async | `Sources/Async Sequence/Async.FlatMap.swift` | 3 | `FlatMap` + `Transform` enum + `Iterator` |
| swift-async | `Sources/Async Sequence/Async.CompactMap.swift` | 3 | `CompactMap` + `Transform` enum + `Iterator` |
| swift-async | `Sources/Async Sequence/Async.Map.swift` | 3 | `Map` + `Transform` enum + `Iterator` |
| swift-async | `Sources/Async Sequence/Async.Filter.swift` | 3 | `Filter` + `Predicate` enum + `Iterator` |
| swift-io | `Sources/IO Events/IO.Event.Driver.Capabilities.swift` | 3 | `Capabilities` + `Triggering` enum + `Model` enum |
| swift-memory | `Sources/Memory/Memory.Shared.swift` | 3 | `Shared` namespace + `Mode` struct + `Create` enum |
| swift-memory | `Sources/Memory/Memory.Map+Safety.swift` | 3 | `Safety` enum + `Scope` enum + `Default` enum |
| swift-memory | `Sources/Memory/Memory.Page.Lock.swift` | 3 | `Page` namespace + `Lock` namespace + `All` enum |
| swift-memory | `Sources/Memory/Memory.Allocation.Statistics.swift` | 3 | `Statistics` + `Bytes` + `Net` |

**Pattern**: Most 3-type files follow a parent + nested child pattern (namespace enum + content types, or type + Iterator + Transform). This is common in async sequence types where the `Iterator` and `Transform` are tightly coupled to the sequence type.

### Minor (2 types in one file -- 17 files)

| Package | File | Nature |
|---------|------|--------|
| swift-ascii | `Binary.ASCII.Parsing.Machine.Decimal.swift` | Namespace + `FoldState` helper |
| swift-ascii | `Int+ASCII.Serializable.swift` | `Decimal` namespace + `Error` enum |
| swift-async | `Async.Stream.Distinct.State.swift` | `Distinct` struct + `State` actor |
| swift-async | `Async.Stream.Map.Flat.State.swift` | `State` actor + `Transform` enum |
| swift-dependencies | `Dependency.swift` | `Dependency` struct + `_Accessor` internal enum |
| swift-io | `IO.Completion.Driver.Capabilities.swift` | `Capabilities` + `Features` OptionSet |
| swift-linux | `Linux.Thread.Affinity.swift` | Two `Affinity` enums (conditional compilation) |
| swift-linux | `Linux.System.Memory.swift` | Two `Memory` enums (conditional compilation) |
| swift-memory | `Memory.Allocation.Profiler.swift` | `ByteStats` + `AllocationStats` accessors |
| swift-memory | `Memory.Map+Access.swift` | `Access` OptionSet + `Allows` accessor |
| swift-memory | `Memory.swift` | Two `Align` enums (conditional compilation) |
| swift-memory | `Memory.Lock.Token.swift` | `Lock` namespace + `Token` struct |
| swift-memory | `Memory.Allocation.Histogram.swift` | `Histogram` + `Bucket` nested struct |
| swift-memory | `Memory.Allocation.Peak.Tracker.swift` | Private `State` + `PeakValues` accessor |
| swift-paths | `Path.Component.Extension.swift` | `Extension` struct + `Error` enum |
| swift-paths | `Path.swift` | `Path` struct + `Error` enum + `Storage` internal |
| swift-paths | `Path.Component.swift` | `Component` struct + `Error` enum |
| swift-paths | `Path.Component.Stem.swift` | `Stem` struct + `Error` enum |
| swift-posix | `POSIX.Kernel.IO.Write.swift` | `IO` namespace + `Write` namespace |
| swift-posix | `POSIX.Kernel.swift` | `POSIX` + `Kernel` + `File` namespaces |
| swift-witnesses | `Witness.Context.swift` | `Context` struct + `_ContextKey` internal |
| swift-witnesses | `Witness.Key.swift` | `__WitnessKeyTest` protocol + `Key` protocol |
| swift-witnesses | `WitnessAccessorsMacro.swift` | 4 types (macro + 2 helpers + diagnostic) |
| swift-windows | `Windows.Thread.Affinity.swift` | Two `Affinity` enums (conditional compilation) |

**Conditional compilation note**: Files in swift-linux, swift-windows, and swift-memory that contain duplicate type declarations under `#if` blocks are not true multi-type violations -- they define the same type for different platforms.

**Type + Error pattern**: swift-paths consistently places `Error` enums in the same file as the type they serve (`Path.swift`, `Path.Component.swift`, `Path.Component.Extension.swift`, `Path.Component.Stem.swift`). This is a systematic pattern that warrants a policy decision: split errors into separate files per [API-IMPL-005], or document an exception for co-located error types.

---

## P1: Compound Type Names [API-NAME-001]

### Documented Workarounds (no action needed)

| Package | Type | Comment |
|---------|------|---------|
| swift-async | `Async.FlatMap` | `// WORKAROUND: [API-NAME-001]` -- `Async.Map` is generic, nesting `Flat` inside it produces unusable type paths |
| swift-async | `Async.CompactMap` | `// WORKAROUND: [API-NAME-001]` -- same reason as FlatMap |

### Real Violations

| Package | File | Type | Suggested Fix |
|---------|------|------|---------------|
| swift-memory | `Memory.Allocation.Profiler.swift:121` | `ByteStats` | `Bytes` (nested in `Profiler`) |
| swift-memory | `Memory.Allocation.Profiler.swift:160` | `AllocationStats` | `Allocations` (nested in `Profiler`) |
| swift-memory | `Memory.Allocation.Peak.Tracker.swift:99` | `PeakValues` | `Values` or `Peaks` (nested in `Tracker`) |

### Macro Types (exempt -- SwiftSyntax convention)

| Package | Type | Reason |
|---------|------|--------|
| swift-witnesses | `WitnessAccessorsMacro` | SwiftSyntax macro naming convention requires `*Macro` suffix |
| swift-witnesses | `WitnessScopeMacro` | Same -- required by `@_CompilerPlugin` |
| swift-witnesses | `WitnessMacro` | Same |

---

## P1: Untyped Throws [API-ERR-001]

### Real Violation

| Package | File | Line | Signature | Underlying Error Type |
|---------|------|------|-----------|----------------------|
| swift-environment | `Environment.Write.swift` | 38 | `public func callAsFunction(...) throws` | `Kernel.Environment.Error` |
| swift-environment | `Environment.Write.swift` | 49 | `public func set(...) throws` | `Kernel.Environment.Error` |
| swift-environment | `Environment.Write.swift` | 59 | `public func unset(...) throws` | `Kernel.Environment.Error` |

The underlying `Kernel.Environment.set` (in `ISO_9945.Kernel.Environment`) uses typed throws `throws(Kernel.Environment.Error)`. The swift-environment wrapper erases this to untyped `throws`. All three should be `throws(Kernel.Environment.Error)`.

### Not Violations (SwiftSyntax protocol requirement)

Macro implementations in swift-witnesses use untyped `throws` because the `MemberMacro`, `PeerMacro`, `MemberAttributeMacro`, and `ExtensionMacro` protocols from SwiftSyntax require `throws -> [DeclSyntax]`. These cannot use typed throws.

---

## P1: Compound Method Names [API-NAME-002]

### Assessed -- No Violations Found

- `stream.distinct.untilChanged()` -- uses nested accessor pattern (`distinct` accessor + `untilChanged` method). Compliant.
- `driver.wakeupChannel(handle)` -- compound method returning `Wakeup.Channel`. Could theoretically be `driver.wakeup.channel(handle)` but `wakeupChannel` is a factory method, not a property accessor chain. Borderline; current form is acceptable for a factory that takes parameters.
- Standard Swift protocol methods (`makeAsyncIterator`, `callAsFunction`, etc.) -- required by language/protocol.
- `is*` / `has*` predicates -- single-concept boolean properties, compliant.
- `withUnsafe*`, `withCString`, etc. -- stdlib-mirroring patterns, compliant.

---

## P2: Methods in Type Bodies [API-IMPL-008]

### Worst Offenders (8+ members in type body)

| Package | File:Line | Type | Members |
|---------|-----------|------|---------|
| swift-io | `IO.Event.Channel.swift:54` | `Channel` | 12 |
| swift-witnesses | `WitnessMacro.swift:498` | `ClosureProperty` | 10 |
| swift-io | `IO.Event.Driver.swift:42` | `Driver` | 9 |
| swift-pools | `Pool.Blocking.Metrics.swift:2` | `Metrics` | 9 |
| swift-kernel | `Kernel.File.Write.Streaming.Context.swift:37` | `Context` | 8 |

### Moderate (5-7 members in type body)

| Package | File:Line | Type | Members |
|---------|-----------|------|---------|
| swift-async | `Async.Stream.Map.Flat.Latest.State.swift:23` | `State` | 7 |
| swift-async | `Async.Stream.Combine.Latest.State.swift:17` | `State` | 7 |
| swift-io | `IO.Event.Selector.Topology.swift:25` | `Topology` | 7 |
| swift-io | `IO.Completion.Poll.Context.swift:24` | `Context` | 7 |
| swift-io | `IO.Completion.Driver.swift:46` | `Driver` | 7 |
| swift-io | `IO.Handle.Registry.swift:51` | `Registry` | 7 |
| swift-async | `Async.Stream.Buffer.Window.State.swift:20` | `State` | 6 |
| swift-async | `Async.Stream.Sample.State.swift:18` | `State` | 6 |
| swift-async | `Async.Stream.Transducer.State.swift:14` | `Run` | 6 |
| swift-io | `IO.Completion.Queue.swift:66` | `Queue` | 6 |
| swift-io | `IO.Completion.Entry.swift:28` | `Entry` | 6 |
| swift-io | `IO.Completion.Event.swift:20` | `Event` | 6 |
| swift-io | `IO.Blocking.Threads.Metrics.swift:25` | `Metrics` | 6 |
| swift-io | `IO.Blocking.Threads.Options.swift:14` | `Options` | 6 |
| swift-io | `IO.Blocking.Threads.Acceptance.Queue.swift:56` | `Queue` | 6 |
| swift-memory | `Memory.Map.swift:72` | `Map` | 6 |
| swift-witnesses | `WitnessAccessorsMacro.swift:70` | `AccessorClosureProperty` | 6 |
| swift-async | `Async.Stream.Merge.State.swift:17` | `State` | 5 |
| swift-async | `Async.Stream.Latest.From.State.swift:18` | `State` | 5 |
| swift-io | `IO.Event.Channel.Writer.swift:24` | `Writer` | 5 |
| swift-io | `IO.Event.Channel.Reader.swift:24` | `Reader` | 5 |
| swift-io | `IO.Event.Driver.Handle.swift:35` | `Handle` | 5 |
| swift-io | `IO.Completion.Driver.Capabilities.swift:25` | `Capabilities` | 5 |
| swift-io | `IO.Blocking.Lane.Abandoning.Options.swift:18` | `Options` | 5 |
| swift-io | `IO.Backpressure.Policy.swift:21` | `Policy` | 5 |
| swift-io | `IO.Blocking.Threads.Acceptance.Waiter.Coordination.swift:18` | `Coordination` | 5 |
| swift-io | `IO.Blocking.Threads.Debug.Snapshot.swift:10` | `Snapshot` | 5 |
| swift-kernel | `Kernel.File.Write.Atomic.Options.swift:16` | `Options` | 5 |
| swift-pools | `Pool.Blocking.State.swift:5` | `State` | 5 |
| swift-witnesses | `WitnessMacro.swift:653` | `ClosureParameter` | 5 |

**Pattern**: The majority of P2 violations (20 of 35) are in swift-io, which has many `struct` types holding stored properties for IO driver/channel/queue state. Most of these are stored property declarations (`let`/`var`), not computed properties or methods. Actors in swift-async similarly hold stored state. These are less concerning than computed properties or methods in type bodies, since stored properties must be in the type body.

---

## Recommended Actions

### Must Fix Before Publication

1. **swift-environment**: Add typed throws to `Environment.Write` -- change `throws` to `throws(Kernel.Environment.Error)` on all three public functions (lines 38, 49, 59).

### Should Fix

2. **swift-memory**: Rename compound accessor types:
   - `ByteStats` to `Bytes` (in `Memory.Allocation.Profiler`)
   - `AllocationStats` to `Allocations` (in `Memory.Allocation.Profiler`)
   - `PeakValues` to `Values` or `Peaks` (in `Memory.Allocation.Peak.Tracker`)

3. **swift-paths**: Split co-located `Error` enums into separate files:
   - `Path.Error.swift`
   - `Path.Component.Error.swift`
   - `Path.Component.Extension.Error.swift`
   - `Path.Component.Stem.Error.swift`

### Consider

4. **swift-witnesses macro implementation**: `WitnessMacro.swift` (1494 lines, 13 types) could benefit from extracting helper types into separate files. Not blocking since these are `private`/`internal` macro-implementation types, not public API.

5. **swift-io methods-in-body**: Many IO types have 5-7 stored properties in their bodies. Most are stored property declarations which must be in the type body. Review whether any computed properties or methods can be moved to extensions.
