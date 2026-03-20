# swift-kernel-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (Opus 4.6)
**Scope**: 248 source files across 23 modules + 4 C shim targets
**Skills**: /implementation, /naming

## Summary Table

| ID | Severity | Rule | File | Description |
|----|----------|------|------|-------------|
| [KER-001] | MEDIUM | [API-IMPL-005] | Kernel.Process.swift | 3 types in one file (Process, Process.Group, Process.ID) |
| [KER-002] | MEDIUM | [API-IMPL-005] | Kernel.Directory.swift | 3 types in one file (Directory, Directory.Entry, Directory.Error) |
| [KER-003] | MEDIUM | [API-IMPL-005] | Kernel.Outcome.swift | 3 types in one file (Outcome, Outcome.Value, Outcome.GetError x2) |
| [KER-004] | MEDIUM | [API-IMPL-005] | Kernel.File.swift (Core) | 2 types in one file (File, File.Space) |
| [KER-005] | MEDIUM | [API-IMPL-005] | Kernel.Termios.Attributes.swift | 2 types in one file (Attributes, Attributes.Storage) |
| [KER-006] | HIGH | [IMPL-040] | Kernel.Event.ID.swift:59 | fatalError() in public initializer |
| [KER-007] | MEDIUM | [API-NAME-002] | Kernel.Glob.Options.swift | Compound properties: caseInsensitive, followSymlinks, maxDepth, onError |
| [KER-008] | MEDIUM | [API-NAME-002] | Kernel.File.Copy.Options.swift | Compound properties: copyAttributes, followSymlinks |
| [KER-009] | LOW | [API-NAME-002] | Kernel.File.Copy.Error.swift | Compound accessors: isSourceNotFound, isDestinationExists, isPermissionDenied |
| [KER-010] | LOW | [API-NAME-002] | Kernel.Time.Deadline.swift | Compound methods: hasExpired, remainingNanoseconds |
| [KER-011] | LOW | [API-NAME-002] | Kernel.Glob.Pattern.swift | Compound methods: parseAtoms, parseScalarClass, flushLiteral (private) |
| [KER-012] | LOW | [API-NAME-002] | Kernel.File.Direct.Mode.swift | Compound methods: resolveMacOS, resolveLinuxWindows, resolveAutoLinuxWindows (private) |
| [KER-013] | LOW | [API-NAME-002] | Kernel.Error.Code.POSIX.swift | Compound functions: isELOOP, isENOTEMPTY, isENAMETOOLONG, isEAGAIN, isEDQUOT, isECONNRESET, isENOTSUP |
| [KER-014] | LOW | [API-NAME-002] | Kernel.Console.Mode.swift | Compound properties: processedInput, lineInput, echoInput, virtualTerminalInput, processedOutput, virtualTerminalProcessing, disableNewlineAutoReturn |
| [KER-015] | MEDIUM | [IMPL-002]/[PATTERN-017] | Kernel.File.Size.swift:102-103 | .rawValue in non-boundary code (Delta init) |
| [KER-016] | MEDIUM | [IMPL-002]/[PATTERN-017] | Kernel.File.Size.swift:113,119,132,141,150 | .rawValue in queries and alignment (internal typed arithmetic on dimension type) |
| [KER-017] | MEDIUM | [IMPL-002]/[PATTERN-017] | Kernel.File.Size.swift:162 | .rawValue at Int init boundary |
| [KER-018] | MEDIUM | [IMPL-002]/[PATTERN-017] | Kernel.File.Direct.Requirements.Alignment.swift:87 | fileOffset.rawValue passed as Int64 to error case |
| [KER-019] | MEDIUM | [IMPL-002]/[PATTERN-017] | Kernel.File.Direct.Requirements.Alignment.Offset.swift:27 | offset.rawValue & mask for alignment check |
| [KER-020] | MEDIUM | [IMPL-002]/[PATTERN-017] | Kernel.File.Direct.Requirements.Alignment.Length.swift:27 | length.rawValue & mask for alignment check |
| [KER-021] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.Memory.Address.swift:78,87 | Triple .rawValue.rawValue.rawValue unwrap for pointer conversion |
| [KER-022] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.File.Direct.Requirements.Alignment.Buffer.swift:26 | Triple .rawValue.rawValue.rawValue for buffer alignment check |
| [KER-023] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.Event.Counter.swift:75,98,107 | .rawValue for comparison and init (RawRepresentable boundary) |
| [KER-024] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.Event.ID.swift:74,76-77 | .rawValue for descriptor/id conversion |
| [KER-025] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.Lock.Range.swift:86 | granularity.rawValue used to call alignment |
| [KER-026] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.File.Handle.Error.swift:225,227 | operation.rawValue for string interpolation |
| [KER-027] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.File.Permissions.swift:129,141,147,170-172 | .rawValue in bitwise operators and description |
| [KER-028] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.Console.Mode.swift:105,110,115 | .rawValue in bitwise operators |
| [KER-029] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.Socket.Descriptor.swift:99 | socket.rawValue in descriptor init |
| [KER-030] | LOW | [IMPL-002]/[PATTERN-017] | Kernel.Event.ID+Socket.swift:23,25 | socket.rawValue in event ID init |
| [KER-031] | LOW | [API-NAME-002] | Kernel.File.Clone.swift:67 | Compound method: probeDefault |
| [KER-032] | LOW | [API-NAME-002] | Kernel.Thread.Affinity.swift:57 | Compound method: numaNode |
| [KER-033] | LOW | [API-NAME-002] | Kernel.Syscall.swift:110,172 | Compound properties: nonNegative, isTrue; compound method: notNil |
| [KER-034] | INFO | -- | Kernel.File.Offset.swift | Offset and Delta are two typealiases in one file -- acceptable (no struct declarations) |

**Totals**: 1 HIGH, 13 MEDIUM, 19 LOW, 1 INFO

---

## Detailed Findings

### [KER-001] MEDIUM -- Kernel.Process.swift contains 3 types

**Rule**: [API-IMPL-005] One type per file.
**File**: `Sources/Kernel Process Primitives/Kernel.Process.swift`
**Lines**: 22 (Process), 27 (Process.Group), 38 (Process.ID)

The file declares `Kernel.Process` (enum), `Kernel.Process.Group` (enum), and `Kernel.Process.ID` (struct). Per [API-IMPL-005], `Process.Group` should be in `Kernel.Process.Group.swift` and `Process.ID` should be in `Kernel.Process.ID.swift`.

---

### [KER-002] MEDIUM -- Kernel.Directory.swift contains 3 types

**Rule**: [API-IMPL-005] One type per file.
**File**: `Sources/Kernel File Primitives/Kernel.Directory.swift`
**Lines**: 24 (Directory), 34 (Directory.Entry), 111 (Directory.Error)

The file declares `Kernel.Directory` (enum), `Kernel.Directory.Entry` (struct), and `Kernel.Directory.Error` (enum). `Entry` should be in `Kernel.Directory.Entry.swift` and `Error` should be in `Kernel.Directory.Error.swift`.

---

### [KER-003] MEDIUM -- Kernel.Outcome.swift contains multiple types

**Rule**: [API-IMPL-005] One type per file.
**File**: `Sources/Kernel Outcome Primitives/Kernel.Outcome.swift`
**Lines**: 52 (Outcome), 86 (Outcome.Value), 118 (Outcome.GetError), 144 (Outcome.Value.GetError)

Four distinct type declarations. `Value` should be in `Kernel.Outcome.Value.swift`, `GetError` in `Kernel.Outcome.GetError.swift`, and `Value.GetError` in `Kernel.Outcome.Value.GetError.swift`.

---

### [KER-004] MEDIUM -- Kernel.File.swift (Core) contains 2 types

**Rule**: [API-IMPL-005] One type per file.
**File**: `Sources/Kernel Primitives Core/Kernel.File.swift`
**Lines**: 16 (File), 35 (File.Space)

`File.Space` should be in its own file `Kernel.File.Space.swift`.

---

### [KER-005] MEDIUM -- Kernel.Termios.Attributes.swift contains 2 types

**Rule**: [API-IMPL-005] One type per file.
**File**: `Sources/Kernel Terminal Primitives/Kernel.Termios.Attributes.swift`
**Lines**: 38 (Attributes), 46 (Attributes.Storage)

`Storage` should be in `Kernel.Termios.Attributes.Storage.swift`.

---

### [KER-006] HIGH -- fatalError() in public initializer

**Rule**: [IMPL-040] Typed throws vs preconditions.
**File**: `Sources/Kernel Event Primitives/Kernel.Event.ID.swift`
**Line**: 59

```swift
public init(_ value: Int32) {
//  self.init(UInt(bitPattern: Int(value)))
    fatalError()
}
```

A public initializer unconditionally calls `fatalError()`. The commented-out implementation suggests this was a work-in-progress. This is a crash at runtime for any caller. Either implement the conversion or remove the initializer entirely.

---

### [KER-007] MEDIUM -- Compound properties in Kernel.Glob.Options

**Rule**: [API-NAME-002] No compound identifiers.
**File**: `Sources/Kernel Glob Primitives/Kernel.Glob.Options.swift`
**Lines**: 35, 43, 46, 54

Properties `caseInsensitive`, `followSymlinks`, `maxDepth`, `onError` are compound names. Per [API-NAME-002], these should use nested accessor patterns.

**Mitigation**: These are configuration properties on an options struct. The compound naming follows Swift API guidelines for Bool properties. The rule may not apply with equal force to configuration properties on options types. Assess whether options structs are exempt.

---

### [KER-008] MEDIUM -- Compound properties in Kernel.File.Copy.Options

**Rule**: [API-NAME-002] No compound identifiers.
**File**: `Sources/Kernel File Primitives/Kernel.File.Copy.Options.swift`
**Lines**: 27, 33

Properties `copyAttributes` and `followSymlinks` are compound names. Same pattern as [KER-007].

---

### [KER-009] LOW -- Compound Boolean accessors on error types

**Rule**: [API-NAME-002] No compound identifiers.
**File**: `Sources/Kernel File Primitives/Kernel.File.Copy.Error.swift`
**Lines**: 108, 114, 120, 126

Properties `isSourceNotFound`, `isDestinationExists`, `isPermissionDenied`. These are standard Swift `is`-prefixed query properties. The compound form is conventional for Boolean accessors on enum types.

---

### [KER-010] LOW -- Compound methods on Kernel.Time.Deadline

**Rule**: [API-NAME-002] No compound identifiers.
**File**: `Sources/Kernel Time Primitives/Kernel.Time.Deadline.swift`
**Lines**: 137, 148

Methods `hasExpired(at:)` and `remainingNanoseconds(at:)` are compound. Note: `remaining(at:)` already exists (line 159) returning `Duration`, which is the correct non-compound pattern. The `remainingNanoseconds` variant duplicates intent with a compound name.

---

### [KER-011] LOW -- Compound private methods in Kernel.Glob.Pattern

**Rule**: [API-NAME-002] No compound identifiers.
**File**: `Sources/Kernel Glob Primitives/Kernel.Glob.Pattern.swift`
**Lines**: 92, 101, 152

Private methods `parseAtoms`, `parseScalarClass`, `flushLiteral`. Internal implementation details. Lower priority since they are not public API.

---

### [KER-012] LOW -- Compound private methods in Direct.Mode resolution

**Rule**: [API-NAME-002] No compound identifiers.
**File**: `Sources/Kernel File Primitives/Kernel.File.Direct.Mode.swift`
**Lines**: 104, 126, 150

Private methods `resolveMacOS`, `resolveLinuxWindows`, `resolveAutoLinuxWindows`. Internal implementation details. Lower priority.

---

### [KER-013] LOW -- Compound static functions on POSIX error codes

**Rule**: [API-NAME-002] No compound identifiers.
**File**: `Sources/Kernel Error Primitives/Kernel.Error.Code.POSIX.swift`
**Lines**: 277, 290, 303, 316, 329, 342, 355

Functions `isELOOP`, `isENOTEMPTY`, `isENAMETOOLONG`, `isEAGAIN`, `isEDQUOT`, `isECONNRESET`, `isENOTSUP`. These mirror POSIX constants (uppercase errno names). [API-NAME-003] may provide defense since these mirror the specification.

---

### [KER-014] LOW -- Compound properties on Console.Mode

**Rule**: [API-NAME-002] No compound identifiers.
**File**: `Sources/Kernel Terminal Primitives/Kernel.Console.Mode.swift`
**Lines**: 33, 42, 51, 60, 73, 82, 91

Properties `processedInput`, `lineInput`, `echoInput`, `virtualTerminalInput`, `processedOutput`, `virtualTerminalProcessing`, `disableNewlineAutoReturn`. These mirror Windows console mode flag names from the Win32 API. [API-NAME-003] may apply since these mirror the specification.

---

### [KER-015] MEDIUM -- .rawValue in non-boundary code (Size from Delta)

**Rule**: [IMPL-002], [PATTERN-017] .rawValue confined to boundary code.
**File**: `Sources/Kernel Primitives Core/Kernel.File.Size.swift`
**Lines**: 102-103

```swift
public init(_ delta: Kernel.File.Delta) {
    precondition(delta.rawValue >= 0, "Delta must be non-negative to convert to Size")
    self.init(delta.rawValue)
}
```

The `delta.rawValue` access is used for both the precondition check and the init. This is a cross-domain conversion (Delta -> Size) that should use typed comparison and a typed conversion path rather than dropping to raw values.

---

### [KER-016] MEDIUM -- .rawValue in Size queries and alignment

**Rule**: [IMPL-002], [PATTERN-017]
**File**: `Sources/Kernel Primitives Core/Kernel.File.Size.swift`
**Lines**: 113, 119, 132, 141, 150

```swift
public var isZero: Bool { rawValue == 0 }
public var isPositive: Bool { rawValue > 0 }
// alignment:
return rawValue & mask == 0
return Self(rawValue & ~mask)
return Self((rawValue &+ mask) & ~mask)
```

The `isZero` and `isPositive` could use typed comparison against `.zero`. The alignment methods operate at the raw level because `mask()` returns `Int64`. This is a dimensional-type boundary that ideally would have typed mask operations. The `isZero`/`isPositive` cases are more clearly improvable.

---

### [KER-017] MEDIUM -- .rawValue at Int init boundary

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel Primitives Core/Kernel.File.Size.swift`
**Line**: 162

```swift
extension Int {
    public init(_ size: Kernel.File.Size) {
        self = Int(size.rawValue)
    }
}
```

This IS a boundary overload (converting typed Size to Int for syscall arguments), so this usage is defensible per [IMPL-010]. However, `size.rawValue` is still exposed rather than using a `_rawValue` SPI pattern like `Kernel.Descriptor` does.

---

### [KER-018] MEDIUM -- fileOffset.rawValue in validation error

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel File Primitives/Kernel.File.Direct.Requirements.Alignment.swift`
**Line**: 87

```swift
return .misalignedOffset(
    offset: fileOffset.rawValue,
    required: offsetAlignment
)
```

The error case takes `Int64` instead of `Kernel.File.Offset`. This forces `.rawValue` at the call site. The `Kernel.File.Direct.Error.misalignedOffset` should accept `Kernel.File.Offset` directly.

---

### [KER-019] MEDIUM -- offset.rawValue for alignment check

**Rule**: [IMPL-002], [PATTERN-017]
**File**: `Sources/Kernel File Primitives/Kernel.File.Direct.Requirements.Alignment.Offset.swift`
**Line**: 27

```swift
return offset.rawValue & mask == 0
```

Bitwise operation on raw value for alignment check. This is an alignment-boundary operation that inherently requires bit manipulation. Could benefit from a typed `isAligned` overload on `Coordinate` types.

---

### [KER-020] MEDIUM -- length.rawValue for alignment check

**Rule**: [IMPL-002], [PATTERN-017]
**File**: `Sources/Kernel File Primitives/Kernel.File.Direct.Requirements.Alignment.Length.swift`
**Line**: 27

Same pattern as [KER-019] but for Size. The alignment check `length.rawValue & mask == 0` drops to raw for bit manipulation.

---

### [KER-021] LOW -- Triple .rawValue unwrap for pointer conversion

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel Memory Primitives/Kernel.Memory.Address.swift`
**Lines**: 78, 87

```swift
unsafe UnsafeRawPointer(bitPattern: rawValue.rawValue.rawValue)
unsafe UnsafeMutableRawPointer(bitPattern: rawValue.rawValue.rawValue)
```

Three layers of `.rawValue`: `Tagged<Kernel, Memory.Address>` -> `Memory.Address` (which is `Ordinal<...>`) -> `UInt`. This is a boundary conversion to unsafe pointers. The depth of unwrapping suggests a missing convenience on the inner types.

---

### [KER-022] LOW -- Triple .rawValue for buffer alignment check

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel File Primitives/Kernel.File.Direct.Requirements.Alignment.Buffer.swift`
**Line**: 26

```swift
alignment.bufferAlignment.isAligned(address.rawValue.rawValue.rawValue)
```

Same triple unwrap as [KER-021]. `Memory.Alignment.isAligned` expects `UInt`, forcing the caller to unwrap through three layers. A typed `isAligned(_: Kernel.Memory.Address)` overload would eliminate this.

---

### [KER-023] LOW -- .rawValue in Event.Counter (RawRepresentable boundary)

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel Event Primitives/Kernel.Event.Counter.swift`
**Lines**: 42, 50, 60, 75, 98, 107

The `Counter` type is `RawRepresentable`. Internal uses of `.rawValue` for init, comparison, and conversion are standard `RawRepresentable` boundary code. Acceptable per [PATTERN-017] since these are within the type's own implementation.

---

### [KER-024] LOW -- .rawValue in Event.ID conversions

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel Event Primitives/Kernel.Event.ID.swift`
**Lines**: 74, 76-77

Boundary code for converting between `Event.ID` and `Descriptor`. Both types are opaque wrappers, so raw access is necessary at their interop boundary. Acceptable.

---

### [KER-025] LOW -- granularity.rawValue in Lock.Range

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel File Primitives/Kernel.Lock.Range.swift`
**Line**: 86

```swift
let roundedEnd = Kernel.System.alignUp(endOffset, to: granularity.rawValue)
```

`Kernel.System.alignUp` accepts `Memory.Alignment`, and `granularity.rawValue` unwraps `Granularity` to `Memory.Alignment`. This is a typed boundary. Acceptable if `Granularity` is a wrapper.

---

### [KER-026] LOW -- operation.rawValue for string interpolation

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel File Primitives/Kernel.File.Handle.Error.swift`
**Lines**: 225, 227

```swift
return "Alignment violation ... during \(operation.rawValue)"
return "Platform error \(code) during \(operation.rawValue)"
```

`Operation` is a `RawValue == String` enum. Using `.rawValue` in string interpolation is the boundary to `String`. Could conform to `CustomStringConvertible` instead.

---

### [KER-027] LOW -- .rawValue in Permissions bitwise operators

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel File Primitives/Kernel.File.Permissions.swift`
**Lines**: 129, 141, 147, 170-172

Standard `RawRepresentable` bit-flag operations. Within the type's own operator implementations. Acceptable boundary code.

---

### [KER-028] LOW -- .rawValue in Console.Mode bitwise operators

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel Terminal Primitives/Kernel.Console.Mode.swift`
**Lines**: 105, 110, 115

Same pattern as [KER-027]. Internal bitwise operations on a `RawRepresentable` flag type. Acceptable.

---

### [KER-029] LOW -- socket.rawValue in Descriptor init

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel Socket Primitives/Kernel.Socket.Descriptor.swift`
**Line**: 99

Boundary conversion between `Socket.Descriptor` and `Kernel.Descriptor`. Acceptable.

---

### [KER-030] LOW -- socket.rawValue in Event.ID+Socket bridge

**Rule**: [PATTERN-017]
**File**: `Sources/Kernel Primitives/Kernel.Event.ID+Socket.swift`
**Lines**: 23, 25

Cross-domain boundary conversion. Acceptable. Note: the `#if os(Windows) / #else` branches are identical, which is a minor code duplication.

---

### [KER-031] LOW -- Compound method: probeDefault

**Rule**: [API-NAME-002]
**File**: `Sources/Kernel File Primitives/Kernel.File.Clone.swift`
**Line**: 67

`probeDefault` is compound. Could be `probe.default` via nested accessor.

---

### [KER-032] LOW -- Compound method: numaNode

**Rule**: [API-NAME-002]
**File**: `Sources/Kernel Thread Primitives/Kernel.Thread.Affinity.swift`
**Line**: 57

`numaNode(_ id:)` is compound. The NUMA terminology is spec-derived, so [API-NAME-003] may apply.

---

### [KER-033] LOW -- Compound names in Syscall.Rule

**Rule**: [API-NAME-002]
**File**: `Sources/Kernel Syscall Primitives/Kernel.Syscall.swift`
**Lines**: 110, 172, 194

Properties `nonNegative`, `isTrue` and method `notNil()` are compound. These are DSL-like rule predicates where the compound form reads naturally at the call site: `.nonNegative`, `.isTrue`, `.notNil()`.

---

### [KER-034] INFO -- Two typealiases in Kernel.File.Offset.swift

**File**: `Sources/Kernel Primitives Core/Kernel.File.Offset.swift`
**Lines**: 31, 36

The file declares both `typealias Offset` and `typealias Delta`. These are typealiases, not struct/enum/class declarations, so they are arguably exempt from [API-IMPL-005]. Noted for completeness.

---

## Observations

### What the package does well

1. **Naming structure is excellent**. All types follow `Kernel.Noun.Verb` or `Kernel.Domain.Type` nesting. No compound type names found. The `Kernel.File.Direct.Requirements.Alignment.Buffer` hierarchy demonstrates exemplary depth-over-breadth naming.

2. **Typed throws used consistently**. Zero instances of untyped `throws`. Every throwing function uses `throws(SomeError)`. This is complete compliance with [API-ERR-001].

3. **No Foundation imports**. Complete compliance with [PRIM-FOUND-001].

4. **SPI pattern for raw access**. `Kernel.Descriptor` uses `@_spi(Syscall)` to gate raw value access (`_rawValue`), keeping the public API opaque. This is the gold standard for [PATTERN-017].

5. **File naming convention**. Files are named `Kernel.Type.Subtype.swift` matching the type hierarchy exactly, with `+Extension` suffix for extension files. This is textbook [API-IMPL-005].

6. **Dimensional types for file coordinates**. `Offset`, `Delta`, `Size` use Binary_Primitives `Coordinate`, `Displacement`, `Magnitude` types for type-safe dimensional arithmetic. Excellent [IMPL-002] implementation.

### Systematic patterns requiring attention

1. **Multi-type files (5 instances)**. The most consistent violation is [API-IMPL-005]. Files like `Kernel.Process.swift`, `Kernel.Directory.swift`, and `Kernel.Outcome.swift` each contain multiple type declarations. The fix is mechanical: split each nested type into its own file.

2. **`.rawValue` in alignment code**. The alignment-checking code (`isAligned`, `alignedDown`, `alignedUp`) consistently drops to `.rawValue` for bitwise operations. This is a fundamental tension: alignment is defined in terms of bit patterns, but the typed wrappers do not expose bitwise operations. A typed `isAligned(to:)` method on the dimension types would eliminate most of these (already exists on `Size` but calls `.rawValue` internally).

3. **Triple `.rawValue` unwrapping**. `Kernel.Memory.Address` wraps `Tagged<Kernel, Memory.Address>` which wraps `Ordinal<UInt>`. Getting to the `UInt` for pointer conversion requires `.rawValue.rawValue.rawValue`. An `isAligned` overload or a direct `pointer` conversion on the intermediate types would reduce this.

4. **Compound properties on options types**. `caseInsensitive`, `followSymlinks`, `copyAttributes` follow standard Swift API guidelines for Boolean configuration properties. Whether [API-NAME-002] applies to options-struct properties needs a policy decision.

### Risk assessment

- **[KER-006] is a production crash**. The `fatalError()` in `Kernel.Event.ID.init(_ value: Int32)` will crash any caller. This should be fixed immediately.
- The multi-type file violations are mechanical to fix and carry no risk.
- The `.rawValue` findings are concentrated in boundary and alignment code. Most are defensible. The highest-value fixes are [KER-015] (typed Delta comparison), [KER-018] (error case accepting typed Offset), and [KER-021]/[KER-022] (typed isAligned overloads).
