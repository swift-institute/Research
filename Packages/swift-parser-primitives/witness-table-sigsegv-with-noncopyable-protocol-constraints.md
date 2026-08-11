# Witness Table SIGSEGV with ~Copyable Protocol Constraints

<!--
---
version: 1.0.0
last_updated: 2026-02-14
status: DECISION
---
-->

## Context

While enabling tests for swift-parser-primitives with `Input.Slice<Buffer<UInt8>.Linear>` as the concrete `ByteInput` type, all composed parser types (wrappers around leaf parsers) crashed with SIGSEGV (signal 11) at runtime. The crash occurred during Swift runtime witness table instantiation.

### Crash Details

- **Signal**: SIGSEGV (EXC_BAD_ACCESS, KERN_INVALID_ADDRESS at 0x0000000000000000)
- **Swift version**: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
- **Platform**: arm64-apple-macosx26.0

**Stack trace**:
```
swift::TargetMetadata<swift::InProcess>::getTypeContextDescriptor() const + 4
swift::TargetMetadata<swift::InProcess>::getGenericArgs() const + 24
instantiateWitnessTable(...) + 260
swift::_getWitnessTable(...) + 4528
lazy protocol witness table accessor for type Parser.First.Element<Input.Slice<Buffer<UInt8>.Linear>>
  and conformance Parser.First.Element<A>: Parser.Protocol
```

**Pattern**: Null pointer dereference during `getTypeContextDescriptor()` inside `instantiateWitnessTable()`, triggered by the lazy protocol witness table accessor for composed generic types.

## Question

How to resolve the runtime SIGSEGV in swift-parser-primitives tests when using `Input.Slice<Buffer<UInt8>.Linear>` as the concrete input type for composed parser types?

## Analysis

### Required Conditions for Crash

All of the following must be present simultaneously:

1. **~Copyable protocol constraint**: A leaf parser type constrained to `Input: Parser.Streaming` (which is `Input.Stream.Protocol: ~Copyable`)
2. **Protocol composition**: A wrapper type `Wrapper<Upstream: Parser.Protocol>: Parser.Protocol` that wraps the constrained leaf
3. **Cross-module concrete type**: `Input.Slice<Buffer<UInt8>.Linear>` from swift-input-primitives/swift-buffer-primitives used as the concrete type parameter
4. **Cross-module instantiation**: The concrete type is instantiated in the test module, not the defining module

### What Does NOT Crash

- Leaf parsers alone (no wrapper) with `Input.Slice<Buffer<UInt8>.Linear>` -- PASSES
- Composed parsers with `[UInt8]` (stdlib Copyable type) -- PASSES
- Composed parsers with standalone mimicked ~Copyable types (defined in same test package) -- PASSES
- Everything in the same module -- PASSES

### Hypotheses Tested and Disproved

| Hypothesis | Test | Result |
|-----------|------|--------|
| `~Escapable` on `associatedtype Input` causes crash | Removed from `Parser.Protocol` and `Parser.Printer` | Still crashes |
| Experimental features (`Lifetimes`, `SuppressedAssociatedTypes`) cause crash | Removed from parser-primitives Package.swift | Still crashes (deps retain their features) |
| Specific to `Buffer<UInt8>.Linear` | Tested with `Array<UInt8>.Dynamic` (from array-primitives) | Also crashes |

### Root Cause

The crash is a **Swift runtime bug** in cross-module witness table instantiation for generic types with `~Copyable` protocol constraints. The runtime attempts to resolve the type context descriptor for a composed generic type (e.g., `Parser.First.Element<Input.Slice<Buffer<UInt8>.Linear>>`) during witness table instantiation and encounters a null pointer.

The crash correlates with **metadata complexity** of the concrete Base type:
- Types defined locally in the same package (e.g., `TestBytes`) -- no crash
- Types from external packages with deep conformance chains (e.g., `Buffer<UInt8>.Linear`, `Array<UInt8>.Dynamic`) -- crash

### Known Related Swift Issues

| Issue | Title | Relevance |
|-------|-------|-----------|
| [#85441](https://github.com/swiftlang/swift/issues/85441) | Runtime crash in getTypeContextDescriptor for property wrapper | **Identical stack trace pattern** (getTypeContextDescriptor -> getGenericArgs -> instantiateWitnessTable). Cross-module. Open. |
| [#74333](https://github.com/swiftlang/swift/issues/74333) | Runtime crash compiling with Swift 6 running on Swift 5.X runtime | **Identical stack trace**. Closed (fixed for same-version runtime). |
| [#84315](https://github.com/swiftlang/swift/issues/84315) | Crash in performOnMetadataCache / checkTransitiveCompleteness | Related metadata crash in Swift 6.2. Closed. |
| [#75172](https://github.com/swiftlang/swift/issues/75172) | Double deinit for ~Copyable type crossing module boundary | Cross-module ~Copyable miscompilation. Closed. |
| [#85275](https://github.com/swiftlang/swift/issues/85275) | ~Copyable/~Escapable crash with final vs non-final class | Runtime crash with ~Copyable + ~Escapable. Open. |

The specific combination of ~Copyable protocol constraints + cross-module witness tables + external package types **has not been reported** as a distinct issue.

### Options Evaluated

#### Option A: Revert ByteInput to `Input.Slice<TestBytes>` (local Copyable wrapper)

**Description**: Define `TestBytes` as a minimal `Collection.Protocol` conformer wrapping `[UInt8]` in the test support module. This was the original approach.

- **Pros**: Completely avoids the crash. Simple, self-contained. No external type dependencies for test backing store.
- **Cons**: `TestBytes` is a custom wrapper that doesn't exercise the real `Buffer.Linear` code path. More boilerplate (ByteIterator + TestBytes + convenience initializers).
- **Risk**: Low -- this was the original tested approach.

#### Option B: Use `Array<UInt8>.Dynamic` from array-primitives

**Description**: Switch from `Buffer<UInt8>.Linear` to `Array<UInt8>.Dynamic` as the backing collection.

- **Pros**: Conforms to `Collection.Protocol` and `Sendable`. Closer to production types.
- **Cons**: **Also crashes** -- same SIGSEGV. External module type with same metadata complexity.
- **Risk**: Does not solve the problem.

#### Option C: Restructure conformances to avoid ~Copyable protocol chain

**Description**: Remove `~Copyable` from `Input.Stream.Protocol`, making `Parser.Streaming` a Copyable-only protocol.

- **Pros**: Would likely eliminate the crash.
- **Cons**: Fundamentally changes the design. `Input.Stream.Protocol: ~Copyable` is intentional -- it enables streaming over non-copyable buffers. Would break the entire input primitives architecture.
- **Risk**: Unacceptable architectural regression.

#### Option D: Wait for Swift runtime fix

**Description**: Keep the crashing code and wait for Apple to fix the underlying runtime bug.

- **Pros**: No workarounds needed. Tests with real types.
- **Cons**: Tests remain broken indefinitely. No known timeline for fix. The issue may not even be reported upstream yet.
- **Risk**: High -- blocks all parser development.

### Comparison

| Criterion | A: TestBytes | B: Array.Dynamic | C: Remove ~Copyable | D: Wait |
|-----------|-------------|-------------------|---------------------|---------|
| Fixes crash | Yes | No | Likely | No |
| Preserves architecture | Yes | Yes | No | Yes |
| Test coverage quality | Good (exercises all parser logic) | N/A | Good | None |
| Implementation effort | Low (restore original code) | Minimal | High | None |
| Maintenance burden | Low | N/A | High | High |

## Outcome

**Status**: DECISION

**Chosen approach**: **Option A -- Revert ByteInput to `Input.Slice<TestBytes>`**.

### Rationale

1. TestBytes was the original, working approach. It exercises all parser combinator logic without triggering the runtime bug.
2. The crash is a Swift runtime bug, not a design flaw in our code. Working around it at the test level is appropriate.
3. The workaround is isolated to the test support module and does not affect the production API.
4. When the Swift runtime bug is fixed (targeted follow-up: file an issue), we can switch back to `Input.Slice<Buffer<UInt8>.Linear>` for more realistic test coverage.

### Implementation

The fix involves:
1. Restoring `TestBytes` struct (minimal `Collection.Protocol` conformer wrapping `[UInt8]`) in `Tests/Support/Parser Primitives Test Support.swift`
2. Changing `ByteInput` typealias from `Input.Slice<Buffer<UInt8>.Linear>` to `Input.Slice<TestBytes>`
3. Restoring `ByteIterator` (wraps `Swift.Array<UInt8>.Iterator`, conforms to `Sequence.Iterator.Protocol`)
4. Updating Package.swift test support dependencies (Array Primitives instead of Buffer Linear Primitives)

### Verification

After implementing Option A:
- 98 tests run successfully (0 crashes)
- 2 pre-existing logic failures in `Parser.FlatMap` and `Parser.Peek` (unrelated to ByteInput type)

### Future Work

1. **File Swift compiler bug**: The `getTypeContextDescriptor` null pointer in `instantiateWitnessTable` for cross-module ~Copyable protocol witness tables should be reported to swiftlang/swift. Issue #85441 has the closest match but involves property wrappers, not generic protocols.
2. **Re-test with future Swift releases**: When Swift 6.3+ is available, test whether `Input.Slice<Buffer<UInt8>.Linear>` works without crashing.

## References

- Crash report: `DiagnosticReports/swiftpm-testing-helper-2026-02-14-151724.ips`
- Bisection experiment: `Experiments/metadata-crash-bisection/`
- [swiftlang/swift#85441](https://github.com/swiftlang/swift/issues/85441) -- Identical stack trace pattern
- [swiftlang/swift#74333](https://github.com/swiftlang/swift/issues/74333) -- Identical stack trace (fixed for same-version)
- [swiftlang/swift#75172](https://github.com/swiftlang/swift/issues/75172) -- Cross-module ~Copyable miscompilation
