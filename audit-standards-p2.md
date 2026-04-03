# Audit: Priority 2 Standards Packages

**Date**: 2026-04-03
**Scope**: Pre-publication code quality audit of 3 standards packages
**Auditor**: Claude (automated scan)

---

## Packages Audited

| Package | Path | Files |
|---------|------|-------|
| swift-iso-9899 (ISO C Standard Library) | `/Users/coen/Developer/swift-iso/swift-iso-9899/` | 38 |
| swift-iso-9945 (POSIX) | `/Users/coen/Developer/swift-iso/swift-iso-9945/` | 99 |
| swift-incits-4-1986 (US-ASCII) | `/Users/coen/Developer/swift-incits/swift-incits-4-1986/` | 16 |

---

## P0: Foundation Imports [PRIM-FOUND-001]

**Result: PASS -- No violations found.**

All three packages are Foundation-free. No `import Foundation` in any Sources/ directory.

---

## P1: Multi-Type Files [API-IMPL-005]

**Result: VIOLATIONS FOUND**

### swift-iso-9899

| File | Types | Names | Verdict |
|------|-------|-------|---------|
| `ISO_9899.Errno.swift` | 3 | `Errno`, `Code`, `Require` | `Code` is nested inside `Errno`; `Require` is a sibling namespace. **Split `Require` to `ISO_9899.Errno.Require.swift`** |
| `ISO_9899.String.Copy.swift` | 3 | `Copy`, `Concatenation`, `Length` | Three sibling namespaces in one file. **Split to `ISO_9899.String.Concatenation.swift` and move `Length` to its own file (partially done -- `ISO_9899.String.Length.swift` already exists, but the `Length` enum in Copy.swift declares the C-wrapper version)** |

**Path**: `/Users/coen/Developer/swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.Errno.swift`
- Line 37: `public enum Errno {}`
- Line 83: `public struct Code` (nested in Errno -- acceptable)
- Line 223: `public enum Require {}` (separate namespace -- should be its own file)

**Path**: `/Users/coen/Developer/swift-iso/swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.Copy.swift`
- Line 26: `public enum Copy {}`
- Line 104: `public enum Concatenation {}`
- Line 168: `public enum Length {}`

### swift-iso-9945

| File | Types | Names | Notes |
|------|-------|-------|-------|
| `ISO 9945.Kernel.File.Clone.swift` | 4 | `Clonefile`, `Copyfile`, `Ficlone`, `CopyRange` | Platform-conditional types, each behind `#if os(...)`. Borderline -- could split per-platform. |
| `ISO 9945.Kernel.Process.Status.swift` | 6 | `Status`, `Exit`, `Terminating`, `Stop`, `Core`, `Classification` | `Exit`/`Terminating`/`Stop`/`Core` are Nest.Name accessor types for `Status`. `Classification` is a pattern-match enum. All are semantically part of `Status`. **Borderline -- Nest.Name accessors are tightly coupled.** |
| `ISO 9945.Kernel.Process.Fork.swift` | 2 | `Fork`, `Result` | `Result` nested in `Fork`. Acceptable. |
| `ISO 9945.Kernel.Signal.Mask.How.swift` | 2 | `Mask`, `How` | `How` nested in `Mask`. Acceptable. |
| `ISO 9945.Kernel.Process.Error.swift` | 2 | `Error`, `Semantic` | `Semantic` nested in `Error`. Acceptable. |
| `ISO 9945.Kernel.Signal.Action.Handler.swift` | 2 | `Action`, `Handler` | `Handler` nested in `Action`. Acceptable. |
| `ISO 9945.Kernel.Process.Wait.Options.swift` | 2 | `Options`, `No` | `No` nested in `Options`. Acceptable. |
| `ISO 9945.Kernel.Lock.Token.swift` | 2 | `Token`, `WithLockError` | `WithLockError` is a generic error type for lock operations. **Should move to own file.** |
| `ISO 9945.Kernel.Thread.Mutex.swift` | 2 | `Lock`, `Error` | `Error` nested in `Lock`. Acceptable. |
| `ISO 9945.Kernel.Process.Group.swift` | 2 | `Process`, `Target` | Two sibling types. **Should split.** |
| `ISO 9945.Kernel.Signal.Error.swift` | 2 | `Error`, `Semantic` | Acceptable (nested). |
| `ISO 9945.Kernel.Device.swift` | 2 | `Major`, `Minor` | Both siblings under `Device`. **Should split to `ISO 9945.Kernel.Device.Major.swift` and `ISO 9945.Kernel.Device.Minor.swift`.** |
| `ISO 9945.Kernel.Socket.Pair.swift` | 3 | `Pair`, `Error`, `Platform` | `Error` and `Platform` nested. Acceptable. |
| `ISO 9945.Kernel.Process.Kill.swift` | 2 | `Kill`, `Signal` | `Signal` nested in `Kill`. Acceptable. |
| `ISO 9945.Kernel.Process.Wait.swift` | 3 | `Wait`, `Selector`, `Result` | `Selector` and `Result` are distinct types alongside `Wait`. **Should split `Selector` and `Result` to own files.** |

### swift-incits-4-1986

**No violations.** Each file declares exactly one type (or one extension with no new type declarations).

### Summary -- Actionable Multi-Type Violations

| Severity | Package | File | Action |
|----------|---------|------|--------|
| P1 | ISO 9899 | `ISO_9899.Errno.swift` | Extract `Require` to `ISO_9899.Errno.Require.swift` |
| P1 | ISO 9899 | `ISO_9899.String.Copy.swift` | Extract `Concatenation` and `Length` to own files |
| P1 | ISO 9945 | `ISO 9945.Kernel.Lock.Token.swift` | Extract `WithLockError` to own file |
| P1 | ISO 9945 | `ISO 9945.Kernel.Process.Group.swift` | Split `Process` and `Target` |
| P1 | ISO 9945 | `ISO 9945.Kernel.Device.swift` | Split `Major` and `Minor` |
| P1 | ISO 9945 | `ISO 9945.Kernel.Process.Wait.swift` | Extract `Selector` and `Result` |
| P1 | ISO 9945 | `ISO 9945.Kernel.File.Clone.swift` | Consider per-platform splitting (4 types) |

---

## P1: Compound Type Names [API-NAME-001]

**Result: VIOLATIONS FOUND in swift-incits-4-1986 and swift-iso-9899**

### swift-incits-4-1986

| File | Line | Current Name | Suggested Fix |
|------|------|-------------|---------------|
| `INCITS_4_1986.ByteArrayClassification.swift` | 26 | `ByteArrayClassification` | `Byte.Array.Classification` or `Byte.Classification` |
| `INCITS_4_1986.StringClassification.swift` | 17 | `StringClassification` | `String.Classification` |
| `INCITS_4_1986.LineEndingDetection.swift` | 19 | `LineEndingDetection` | `Line.Ending.Detection` or defer to `FormatEffectors.Line.Ending.Detection` |
| `INCITS_4_1986.FormatEffectors.swift` | 12 | `FormatEffectors` | `Format.Effectors` (matches spec section name "Format Effectors") |
| `INCITS_4_1986.NumericParsing.swift` | 11 | `NumericParsing` (typealias) | `Numeric.Parsing` |
| `INCITS_4_1986.NumericSerialization.swift` | 11 | `NumericSerialization` (typealias) | `Numeric.Serialization` |
| `INCITS_4_1986.CharacterClassification.swift` | 11 | `CharacterClassification` (typealias) | `Character.Classification` (but note `Character` is already a typealias -- may conflict) |

**Note**: Several of these are typealiases to `ASCII_Primitives.ASCII.*`. The compound naming issue originates upstream in the primitives layer for some cases. For the 3 locally-declared enums (`ByteArrayClassification`, `StringClassification`, `LineEndingDetection`), the fix is straightforward.

### swift-iso-9899

| File | Line | Current Name | Suggested Fix |
|------|------|-------------|---------------|
| `ISO_9899.Math.Classification.swift` | 19 | `FloatingPointClass` | `FloatingPoint.Class` or just `Class` (nested under `Math`) |

### swift-iso-9945

**No compound type name violations found.** All types use the Nest.Name pattern correctly (e.g., `Signal.Number`, `Process.Status`, `File.Clone`).

---

## P2: Methods in Type Bodies [API-IMPL-008]

**Result: VIOLATIONS FOUND in swift-iso-9945**

The convention requires type bodies to contain only stored properties and deinit. Computed properties and methods should be in extensions.

### swift-iso-9899

**PASS.** Types like `Errno.Code`, `ISO_9899.String`, and `Math.FloatingPointClass` contain only stored properties, enum cases, or deinit in their bodies. Methods and computed properties are defined in extensions.

### swift-iso-9945

| File | Line | Type | Violation |
|------|------|------|-----------|
| `ISO 9945.Kernel.Process.Status.swift` | 80-92 | `Exit` | Computed property `code` inside struct body |
| `ISO 9945.Kernel.Process.Status.swift` | 98-109 | `Terminating` | Computed property `signal` inside struct body |
| `ISO 9945.Kernel.Process.Status.swift` | 116-128 | `Stop` | Computed property `signal` inside struct body |
| `ISO 9945.Kernel.Process.Status.swift` | 134-158 | `Core` | Computed property `dumped` inside struct body |

**Path**: `/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel/ISO 9945.Kernel.Process.Status.swift`

All four are Nest.Name accessor types. Each should have their stored property + init in the body, with the computed property moved to an extension.

### swift-incits-4-1986

**PASS.** No violations.

---

## P3: Missing Doc Comments [DOC-001]

**Result: MOSTLY CLEAN -- Minor violations**

### swift-iso-9899

| File | Line | Declaration |
|------|------|------------|
| `ISO_9899.Errno.swift` | 84 | `public let rawValue: Int32` |
| `ISO_9899.Errno.swift` | 87 | `public init(rawValue: Int32)` |

### swift-iso-9945

Systematic gaps in RawRepresentable boilerplate (`rawValue`, `init(rawValue:)`) and some typealiases across multiple files. Representative sample:

| File | Line | Declaration |
|------|------|------------|
| `ISO 9945.Kernel.File.Seek.swift` | 597 | `public let rawValue: Int32` |
| `ISO 9945.Kernel.Signal.Mask.How.swift` | 972 | `public let rawValue: Int32` |
| `ISO 9945.Kernel.Signal.Number.swift` | 4700 | `public let rawValue: Int32` |
| `ISO 9945.Kernel.Pipe.swift` | 2745 | `public let rawValue: Int32` |
| `ISO 9945.Kernel.Device.swift` | 8772, 8784 | `public let rawValue: UInt32` |
| `ISO 9945.Kernel.Process.Status.swift` | 5743 | `public let rawValue: Int32` |
| `ISO 9945.Kernel.Process.Kill.swift` | 9642 | `public let rawValue: Int32` |
| `ISO 9945.Kernel.Memory.Lock.All.Flags.swift` | 10712 | `public let rawValue: Int32` |
| Various files | Various | ~10 `public typealias Error = ...` missing doc comments |

**Pattern**: The undocumented declarations are overwhelmingly `RawRepresentable` boilerplate (`rawValue`, `init(rawValue:)`). This is a systemic pattern, not individual omissions.

### swift-incits-4-1986

**PASS.** All public declarations have doc comments.

---

## Additional Observations

### Filename Inconsistency (swift-incits-4-1986)

The file `NCITS_4_1986.FormatEffectors.LineEnding.swift` uses the prefix `NCITS` instead of `INCITS`. The type inside correctly uses the `INCITS_4_1986` namespace. This is likely a historical artifact (NCITS was the previous name of the standards body before it became INCITS).

**Path**: `/Users/coen/Developer/swift-incits/swift-incits-4-1986/Sources/INCITS_4_1986/NCITS_4_1986.FormatEffectors.LineEnding.swift`

### ISO 9899: `public typealias C = ISO_9899`

File `ISO_9899.swift` (line 66) declares `public typealias C = ISO_9899` at module scope. This is a convenience alias that may shadow in consumer code. Not a convention violation but worth noting.

---

## Summary by Package

### swift-iso-9899 (ISO C Standard Library)

| Check | Result | Count |
|-------|--------|-------|
| P0: Foundation imports | PASS | 0 |
| P1: Multi-type files | FAIL | 2 files |
| P1: Compound type names | FAIL | 1 type (`FloatingPointClass`) |
| P2: Methods in type bodies | PASS | 0 |
| P3: Missing doc comments | FAIL | 2 declarations (RawRepresentable boilerplate) |

### swift-iso-9945 (POSIX)

| Check | Result | Count |
|-------|--------|-------|
| P0: Foundation imports | PASS | 0 |
| P1: Multi-type files | FAIL | 7 files (4 actionable, 3 borderline) |
| P1: Compound type names | PASS | 0 |
| P2: Methods in type bodies | FAIL | 4 Nest.Name accessor types with computed properties in body |
| P3: Missing doc comments | FAIL | ~20 declarations (systemic RawRepresentable boilerplate pattern) |

### swift-incits-4-1986 (US-ASCII)

| Check | Result | Count |
|-------|--------|-------|
| P0: Foundation imports | PASS | 0 |
| P1: Multi-type files | PASS | 0 |
| P1: Compound type names | FAIL | 7 types (3 local enums + 4 typealiases to upstream compounds) |
| P2: Methods in type bodies | PASS | 0 |
| P3: Missing doc comments | PASS | 0 |

---

## Recommended Fix Priority

1. **INCITS compound names** (7 types) -- Highest impact on API surface consistency
2. **ISO 9899 multi-type files** (2 files) -- Straightforward mechanical split
3. **ISO 9945 multi-type files** (4-7 files) -- Larger scope, some borderline
4. **ISO 9899 `FloatingPointClass`** -- Single rename
5. **ISO 9945 Nest.Name accessor bodies** (4 types) -- Move computed properties to extensions
6. **NCITS filename** -- Rename to `INCITS_4_1986.FormatEffectors.Line.swift`
7. **RawRepresentable doc comments** -- Systemic; consider a macro or template approach
