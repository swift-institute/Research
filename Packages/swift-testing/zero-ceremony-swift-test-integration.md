# Zero-Ceremony `swift test` Integration

<!--
---
version: 1.0.0
last_updated: 2026-03-01
status: DECISION
tier: 2
---
-->

## Context

The swift-testing framework defines a custom `@Test` macro that emits binary section records and a custom test runner. When consumers write `@Test` functions and run `swift test`, SwiftPM's test infrastructure discovers zero tests because:

1. SwiftPM's XCTest runner discovers `XCTestCase` subclasses — our `@Test` functions are invisible to it
2. SwiftPM's swift-testing integration calls Apple's `__swiftPMEntryPoint` — not ours
3. Our section records may not be emitted or discovered correctly

**Constraint**: Consumers must have zero ceremony beyond writing standard `@Test` functions. No bridges, no plugins, no extra files.

**Trigger**: `Experiments/syntax-showcase/` builds but executes 0 tests via `swift test`.

## Question

How should the Institute's swift-testing framework integrate with `swift test` to achieve zero-ceremony test execution for consumer packages?

## Prior Art: Apple's swift-testing

Source: `/Users/coen/Developer/swiftlang/swift-testing/`

Apple achieves zero ceremony through a three-stage pipeline:

### Stage 1: Compile-Time Record Emission

The `@Test` macro expands to:
1. **Thunk function** — wraps the test with normalized async/throws signature
2. **Generator function** — returns a `Test` instance wrapping the thunk
3. **Section record** — placed in `__swift5_tests` via `@used @section(...)`:

```swift
@used
@section("__DATA_CONST,__swift5_tests")
private let __record: Testing.__TestContentRecord = (
    kind: 0x74657374,  // 'test'
    reserved1: 0,
    accessor: { outValue, type, _, _ in
        Testing.Test.__store(__generator, into: outValue, asTypeAt: type)
    },
    context: 0,
    reserved2: 0
)
```

Key attributes:
- `@used` — prevents linker from stripping the unreferenced symbol
- `@section(...)` — places the variable in the named binary section

### Stage 2: SwiftPM Entry Point

SwiftPM discovers `__swiftPMEntryPoint` by symbol lookup in the test binary:

```swift
public func __swiftPMEntryPoint(
    passing args: __CommandLineArguments_v0? = nil
) async -> CInt
```

SwiftPM **does not link against swift-testing at build time**. It dynamically looks up this symbol at runtime. This means any library that exports `__swiftPMEntryPoint` can provide the entry point.

### Stage 3: Section Enumeration

`Test.all` scans binary sections:
- **Darwin**: `getsectiondata()` via dyld
- **Linux**: `swift_enumerateAllMetadataSections()`
- **Windows**: PE header walking

Each record's accessor is called to produce a `Test.Generator`, which is then called to produce the `Test` instance.

## Analysis

### Option A: XCTest Auto-Bridge (Current Approach)

Embed an `XCTestCase` subclass in the `Testing` library itself:

```swift
#if canImport(XCTest)
public import XCTest

public final class __TestingRunner: XCTestCase {
    public func testAll() async {
        let hasFailures = await Testing.runAll()
        XCTAssertFalse(hasFailures)
    }
}
#endif
```

**Status**: Implemented. XCTest discovers `__TestingRunner` automatically. The bridge calls `Testing.runAll()` which does section-based discovery.

**Current issue**: Section discovery finds 0 tests. Two potential causes:
1. `hasFeature(SymbolLinkageMarkers)` evaluates to `false` → records not placed in section
2. `@section` / `@used` (underscored) vs `@section` / `@used` (stable) — wrong attribute names
3. Our `Loader.Section.all(.swiftTestContent)` doesn't find the records

**Advantages**:
- Zero ceremony for consumers — just `import Testing` and write `@Test`
- Works with existing `swift test` infrastructure
- No dependency on SwiftPM internals
- Full trait support (snapshots, performance, etc.)

**Disadvantages**:
- XCTest sees 1 test (`testAll`), not individual tests
- Dual output (XCTest summary + our console reporter)
- `public import XCTest` in the library (acceptable at Layer 3)

### Option B: Custom Section Name + XCTest Bridge

Use a distinct section name (e.g., `__inst_tests`) to avoid collision with Apple's `__swift5_tests`. Combined with the XCTest bridge from Option A.

**Advantages**:
- No risk of Apple's runtime misinterpreting our records (crash prevention)
- Our section scanner finds only our records
- Compatible with Option A's bridge

**Disadvantages**:
- Requires updating the `@Test` macro to emit to the custom section
- Requires updating `Loader.Section.Name` to know the new section name
- More divergence from Apple's format

### Option C: Override SwiftPM Entry Point

Export `__swiftPMEntryPoint` from our `Testing` module with the same signature. SwiftPM discovers it via symbol lookup.

```swift
public func __swiftPMEntryPoint(
    passing args: __CommandLineArguments_v0? = nil
) async -> CInt
```

**Advantages**:
- SwiftPM would call our entry point directly
- Individual test reporting possible
- Full control over test execution

**Disadvantages**:
- Symbol collision with Apple's swift-testing if both are linked
- SwiftPM may prefer Apple's symbol (same module name, but Apple's is in the toolchain)
- Fragile — depends on SwiftPM's undocumented symbol lookup order
- `__CommandLineArguments_v0` is Apple's ABI, not ours

### Option D: SwiftPM Command Plugin

Provide a SwiftPM command plugin that consumers can invoke:

```bash
swift package plugin run-tests
```

**Advantages**:
- Full control over test execution
- No XCTest dependency

**Disadvantages**:
- Not `swift test` — different command
- Consumer must declare the plugin (ceremony)
- Plugin infrastructure is complex

### Comparison

| Criterion                    | A: XCTest Bridge | B: Custom Section | C: Override Entry | D: Plugin |
|------------------------------|------------------|-------------------|-------------------|-----------|
| Zero consumer ceremony       | Yes              | Yes               | Yes               | No        |
| Works with `swift test`      | Yes              | Yes               | Maybe             | No        |
| Individual test reporting    | No (1 XCTest)    | No (1 XCTest)     | Yes               | Yes       |
| Crash-safe (Apple coexist)   | Needs fix        | Yes               | No                | Yes       |
| Implementation complexity    | Low              | Medium            | High              | High      |
| Maintenance burden           | Low              | Low               | High (ABI)        | Medium    |

## Investigation: Why Section Discovery Finds 0 Tests

The macro expansion (from `TestMacro.swift`) emits:

```swift
#if hasFeature(SymbolLinkageMarkers)
@section("__DATA_CONST,__swift5_tests")
@used
#endif
```

### Experiment Results

See `Experiments/section-discovery-verification/` for full details.

**H1: `hasFeature(SymbolLinkageMarkers)` = `false` by default in Swift 6.2.**
- Evaluates to `true` only with explicit `.enableExperimentalFeature("SymbolLinkageMarkers")` in Package.swift
- Our macro gates section placement behind this → records are never placed → discovery finds nothing

**H1b: `compiler(>=6.3)` = `false`. Our toolchain is Swift 6.2.4.**
- Apple's `swift-testing` gates `@section`/`@used` behind `#if compiler(>=6.3)`
- The stable section placement attributes are a Swift 6.3 feature

**H2a: `@section`/`@used` (non-underscored, stable) — NOT AVAILABLE in Swift 6.2.**
- `@section` → `error: struct 'section' cannot be used as an attribute`
- `@used` → `error: unknown attribute 'used'`

**H2b: `@section`/`@used` (underscored, experimental) — RECOGNIZED but NON-FUNCTIONAL in Swift 6.2.**
- When `SymbolLinkageMarkers` is enabled, both attributes are recognized
- But **every** variable declaration fails: `error: global variable must be a compile-time constant to use @section attribute`
- Tested with: `UInt64` literals, tuples, struct initializers, `_const` modifier, `CompileTimeConst` feature
- The compile-time constant evaluator required for `@section` does not exist in Swift 6.2

### Root Cause

**Section-based test discovery is fundamentally impossible on Swift 6.2.** The `@section`/`@used` attributes and their compile-time constant support only ship in Swift 6.3+. Our `@Test` macro's section record emission is dead code on 6.2.

This is not a bug in our implementation — it's a toolchain limitation. Apple's own swift-testing gates the same feature behind `#if compiler(>=6.3)`.

## Outcome

**Status**: IMPLEMENTED (revised 2026-03-26)

**Decision**: Two-tier discovery: section-based (Swift 6.3+) as the principled long-term mechanism, with legacy type-metadata discovery (Swift 6.2) as a zero-cost bridge. SPM integration via `__swiftPMEntryPoint` as the sole entry point.

### XCTest Bridge Removed (2026-03-26)

The `__TestingRunner` XCTest bridge (`Testing.XCTestBridge.swift`) has been deleted. Root cause: SPM runs XCTest and Swift Testing as separate sequential passes using separate processes (`xctest` tool and `swiftpm-testing-helper` respectively). Both passes discovered entry points into the custom runner, causing double execution. The `xctest` process completed first; the `swiftpm-testing-helper` process hung.

The `__swiftPMEntryPoint` path is now the sole integration mechanism, matching Apple's upstream model. SPM's generated runner already calls `Testing.__swiftPMEntryPoint()` via `#if canImport(Testing)` — zero consumer ceremony. See `HANDOFF-testing-double-run.md` in swift-io for the full investigation.

### The Correct Architecture (Swift 6.3+)

Section-based discovery is the principled solution because:

1. **It's the mechanism Apple standardized** — `@section`/`@used` with `#if compiler(>=6.3)`
2. **It's zero-ceremony by construction** — the macro emits section records, the runtime scans them, no manifest or registration
3. **It's linker-level** — records survive dead-code elimination via `@used`, placement is guaranteed via `@section`
4. **It's the same mechanism for all test frameworks** — any framework can place records in `__swift5_tests`

When Swift 6.3 is available:

1. Update the `@Test` macro to use `@section`/`@used` (non-underscored, stable) gated by `#if compiler(>=6.3)`
2. Adopt Apple's `#if objectFormat()` pattern for cross-platform section names (MachO, ELF, COFF, Wasm)
3. Remove the dead `#if hasFeature(SymbolLinkageMarkers)` / `@section` / `@used` code — it was never functional
4. The `#if compiler(<6.3)` container enums automatically stop being emitted — no code changes needed

### Legacy Discovery (Swift 6.2)

Apple's swift-testing has a legacy discovery mechanism that piggybacks on the `__swift5_types` section (type metadata), which the compiler always populates for every Swift type. We adopted this same approach.

**How it works**:

1. The `@Test` macro emits (in addition to the accessor + record) a container enum gated behind `#if compiler(<6.3)`:

```swift
#if compiler(<6.3)
private enum __🟡$_myTest: Testing.__TestContentRecordContainer {
    nonisolated static var __testContentRecord: Testing.__TestContentRecord {
        unsafe record_myTest
    }
}
#endif
```

2. The compiler places this enum's type metadata in `__swift5_types` (always, for every type)

3. At runtime, `Loader.types(named: "__🟡$")` walks `__swift5_types` via C++ ABI code (ported from Apple's `_TestingInternals/Discovery.cpp`), filtering by name substring

4. Matching types are cast to `Test.__TestContentRecordContainer`, their `__testContentRecord` property is read, and the accessor is called to produce a `Test.Registration`

5. `Testing.Discovery.discoverAll()` tries section-based first, falls back to type-metadata, then dlsym

**Key attribute**: `@_alwaysEmitConformanceMetadata` on the protocol ensures the optimizer doesn't strip conformance info.

**Implementation files**:

| File | Package | Purpose |
|------|---------|---------|
| `CTypeMetadata/TypeMetadata.cpp` | swift-loader | C++ ABI scanner (port of Apple's Discovery.cpp) |
| `CTypeMetadata/include/CTypeMetadata.h` | swift-loader | C header for Swift interop |
| `Loader/Loader.TypeMetadata.swift` | swift-loader | `Loader.types(named:)` Swift wrapper |
| `Tests Core/Test.Discovery.Legacy.swift` | swift-tests | `__TestContentRecordContainer` protocol |
| `Testing/Testing.MacroSupport.swift` | swift-testing | Typealias for macro expansions |
| `Testing/Testing.Discovery.swift` | swift-testing | `discoverFromTypeMetadata()` + updated `discoverAll()` |
| `Testing Macros Implementation/TestMacro.swift` | swift-testing | Container enum emission |
| `Testing Macros Implementation/SuiteMacro.swift` | swift-testing | Container enum emission |

**Self-removing**: When Swift 6.3 arrives, `#if compiler(<6.3)` evaluates to false. The container enums stop being emitted. Section-based discovery finds records. The legacy path in `discoverAll()` returns an empty registry (no `__🟡$` types exist). No code changes needed.

## References

- Apple's swift-testing: `/Users/coen/Developer/swiftlang/swift-testing/`
- SwiftPM entry point: `swiftlang/swift-testing/Sources/Testing/ABI/EntryPoints/SwiftPMEntryPoint.swift`
- Section discovery: `swiftlang/swift-testing/Sources/_TestDiscovery/SectionBounds.swift`
- Record structure: `swiftlang/swift-testing/Documentation/ABI/TestContent.md`
- Our macro: `swift-testing/Sources/Testing Macros Implementation/TestMacro.swift`
- Our discovery: `swift-testing/Sources/Testing/Testing.Discovery.swift`
- Our XCTest bridge: REMOVED (was `swift-testing/Sources/Testing Umbrella/Testing.XCTestBridge.swift`)
- Existing research: `swift-institute/Research/comparative-swift-testing-frameworks.md`
