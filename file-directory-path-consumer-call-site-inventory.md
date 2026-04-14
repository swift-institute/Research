# File / Directory / Path Consumer Call-Site Inventory

**Date**: 2026-03-19
**Scope**: All repos in the workspace that import `File_System`, `File_System_Primitives`, `Paths`, or `Path_Primitives` — excluding `swift-file-system` and `swift-paths` source/test files.

---

## Consumer Repos Found

| Repo | Module/File | Imports |
|------|-------------|---------|
| swift-foundations/swift-tests | Tests Snapshot, Tests Performance, Tests Inline Snapshot | `File_System` |
| swift-foundations/swift-pdf | PDF (exports.swift) | `@_exported File_System` |
| swift-foundations/swift-pdf (tests) | PDF Tests | `File_System` (via PDF re-export) |
| swift-primitives/swift-kernel-primitives | Kernel Path Primitives | `Path_Primitives` |
| swift-iso/swift-iso-9945 | ISO 9945 Kernel | `Path_Primitives` |
| swift-foundations/swift-tests (tests) | Test.Snapshot.Storage Tests | `Paths` |

---

## 1. Construction Patterns

### 1a. `File.Path` from String Literal (via `ExpressibleByStringLiteral`)

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Tests.Baseline.Storage.swift | 42 | `File.Path(stringLiteral: value)` | Explicit `stringLiteral:` — could just be `File.Path(value)` or literal |
| swift-tests/.../Tests.Baseline.Storage.swift | 43 | `File.Path(stringLiteral: ".benchmarks")` | Same — explicit `stringLiteral:` on literal |
| swift-tests/.../Test.Snapshot.Storage.swift | 63 | `File.Path(stringLiteral: testFilePath)` | Converting `#filePath` String to `File.Path` — **must use `stringLiteral:` because the variable is a String, not a literal** |
| swift-tests/.../Test.Snapshot.Inline.Rewriter.swift | 52 | `File(File.Path(stringLiteral: filePath)).read.full { }` | Same pattern — String variable to File.Path |
| swift-tests/.../Test.Snapshot.Inline.Rewriter.swift | 82 | `File(File.Path(stringLiteral: filePath)).write.atomic(output)` | Same |

**Count**: 5 occurrences of `File.Path(stringLiteral:)` (all in swift-tests).

**Ergonomic assessment**: The `File.Path(stringLiteral: variable)` pattern is **clunky**. It is necessary because Swift's `ExpressibleByStringLiteral` only works for actual literals, not String variables. The `let x: File.Path = "/literal"` pattern is clean. A `File.Path(_ string:)` throwing init exists but requires `try`.

### 1b. `File.Path` from String Variable (via `try File.Path(_:)`)

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage Tests.swift | 29 | `File.Path("/custom/snapshots")` | Literal as argument |
| swift-tests/.../Test.Snapshot.Storage Tests.swift | 95 | `File.Path("/custom")` | Literal as argument |

**Count**: ~2 occurrences in swift-tests.

**Ergonomic assessment**: `try File.Path(string)` is fine for variables. The interpolation pattern `File.Path("\(base)/\(name).pdf")` is common and **somewhat clunky** — in many cases, the `/` operator would be more natural: `base / "\(name).pdf"`. However, some call sites must build an entire path string from a non-Path base.

### 1c. `File(path)` — File from File.Path

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 105 | `File(path)` | Clean, minimal |
| swift-tests/.../Test.Snapshot.Storage.swift | 122 | `File(path)` | Same |
| swift-tests/.../Tests.Baseline.Storage.swift | 90 | `File(path)` | Same |
| swift-tests/.../Tests.Baseline.Storage.swift | 128 | `File(path).write.atomic(contentsOf: bytes)` | Inline construction + chained operation |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 100 | `File(path)` | Same |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 133 | `File(path).write.atomic(contentsOf: bytes)` | Inline |
| swift-tests/.../Tests.History.Storage.swift | 123 | `File(filePath).write.append(line)` | Inline |
| swift-tests/.../Tests.History.Storage.swift | 169 | `File(path).write.atomic(content)` | Inline |
| swift-tests/.../Tests.History.Storage.swift | 181 | `File(path)` | Same |
| swift-tests/.../Test.Snapshot.Inline.Rewriter.swift | 52 | `File(File.Path(stringLiteral: filePath))` | **Double-wrapping** — String to Path to File |
| swift-tests/.../Test.Snapshot.Inline.Rewriter.swift | 82 | `File(File.Path(stringLiteral: filePath))` | Same |
| swift-pdf/.../PDF Tests.swift | 58 | `File("/tmp/swift-pdf/markdown-to-pdf-test.pdf")` | **Direct string literal to File** — very clean |
| swift-pdf/.../PDF Tests.swift | 97 | `File("/tmp/swift-pdf/markdown-table-to-pdf-test.pdf")` | Same |
| swift-pdf/.../PDF Tests.swift | 189 | `File("/tmp/swift-pdf/markdown-complex-to-pdf-test.pdf")` | Same |

**Count**: ~14 occurrences.

**Ergonomic assessment**: `File(path)` is clean. `File("/literal")` is the most ergonomic form (File accepts string literals because File.Path does). `File(File.Path(stringLiteral: variable))` is the worst — needs a convenience `File(path: String)` or similar.

### 1d. `File.Directory(path)` — Directory from File.Path

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 162 | `File.Directory(path)` | Clean |
| swift-tests/.../Tests.Baseline.Storage.swift | 141 | `File.Directory(path)` | Clean |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 118 | `File.Directory(parent)` | Clean |
| swift-tests/.../Tests.History.Storage.swift | 140 | `File.Directory(path)` | Clean |

**Count**: 4 occurrences.

**Ergonomic assessment**: Always used as `File.Directory(path)` then immediately followed by `.stat.exists` or `.create.recursive()`. Clean pattern.

### 1e. `File.Path.Component` from String

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage Tests.swift | 43 | `try File.Path.Component("PDF.Test.Snapshot")` | Failable init |
| swift-tests/.../Test.Snapshot.Storage Tests.swift | 88 | `try File.Path.Component("MyType")` | Same |

**Count**: 2 occurrences.

**Ergonomic assessment**: Clean. The `try` is needed for validation.

---

## 2. Read/Write Patterns

### 2a. `file.read.full { span in ... }` — Full File Read

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 109 | `try file.read.full { span in span.withUnsafeBufferPointer { Array($0) } }` | Read to [UInt8] |
| swift-tests/.../Test.Snapshot.Inline.Rewriter.swift | 52 | `try File(...).read.full { span in ... String(decoding:) }` | Read to String |
| swift-tests/.../Tests.Baseline.Storage.swift | 94 | `try file.read.full { span in ... JSON.parse ... }` | Read + JSON parse |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 104 | `try file.read.full { span in ... }` | Read + JSON parse |
| swift-tests/.../Tests.History.Storage.swift | 185 | `try file.read.full { span in ... String(decoding:) }` | Read to String |

**Count**: 5 occurrences.

**Ergonomic assessment**: The `file.read.full { span in }` pattern is consistent but **verbose for common cases**. Every consumer does `span.withUnsafeBufferPointer { Array($0) }` or `span.withUnsafeBufferPointer { String(decoding:as:) }`. These are boilerplate-heavy for "just give me the bytes" or "just give me the string".

### 2b. `file.write.atomic(contentsOf:)` / `file.write.atomic(_:)` — Atomic Write

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 148 | `try File(path).write.atomic(contentsOf: bytes)` | [UInt8] |
| swift-tests/.../Tests.Baseline.Storage.swift | 128 | `try File(path).write.atomic(contentsOf: bytes)` | [UInt8] |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 133 | `try File(path).write.atomic(contentsOf: bytes)` | [UInt8] |
| swift-tests/.../Tests.History.Storage.swift | 169 | `try? File(path).write.atomic(content)` | String |
| swift-tests/.../Test.Snapshot.Inline.Rewriter.swift | 82 | `try File(...).write.atomic(output)` | String |

**Count**: 5 occurrences.

**Ergonomic assessment**: `.write.atomic(contentsOf: bytes)` and `.write.atomic(string)` are clean. The two-argument-label difference (`contentsOf:` for bytes, no label for String) is slightly inconsistent.

### 2c. `file.write.append(_:)` — Append Write

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Tests.History.Storage.swift | 123 | `try File(filePath).write.append(line)` | String |

**Count**: 1 occurrence.

### 2d. `doc.write(to: File.Path)` — Binary.Serializable Write (PDF Documents)

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-pdf/.../PDF Tests.swift | 58 | `try doc.write(to: File("..."), createIntermediates: true)` | File literal |
| swift-pdf/.../PDF Tests.swift | 97, 189 | Same pattern | 2 more |

**Count**: 3 occurrences in swift-pdf tests.

**Ergonomic assessment**: The `doc.write(to: File.Path(...))` pattern is the dominant PDF output pattern. `doc.write(to: File("/tmp/file.pdf"), createIntermediates: true)` with a string literal is very clean.

---

## 3. Directory Patterns

### 3a. `dir.stat.exists` / `file.stat.exists` / `file.exists`

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 106 | `file.stat.exists` | |
| swift-tests/.../Test.Snapshot.Storage.swift | 122 | `File(path).stat.exists` | |
| swift-tests/.../Test.Snapshot.Storage.swift | 165 | `dir.stat.exists` | |
| swift-tests/.../Tests.Baseline.Storage.swift | 91 | `file.stat.exists` | |
| swift-tests/.../Tests.Baseline.Storage.swift | 142 | `dir.stat.exists` | |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 101 | `file.stat.exists` | |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 119 | `dir.stat.exists` | |
| swift-tests/.../Tests.History.Storage.swift | 141 | `dir.stat.exists` | |
| swift-tests/.../Tests.History.Storage.swift | 182 | `file.stat.exists` | |

**Count**: 9 occurrences of `.stat.exists`.

**Ergonomic assessment**: The swift-tests code consistently uses `.stat.exists`. A convenience `.exists` accessor would likely be more ergonomic for common existence checks.


### 3b. `dir.create.recursive()` — Directory Creation

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 171 | `try dir.create.recursive()` | |
| swift-tests/.../Tests.Baseline.Storage.swift | 145 | `try dir.create.recursive()` | |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 121 | `try dir.create.recursive()` | |
| swift-tests/.../Tests.History.Storage.swift | 144 | `try dir.create.recursive()` | |

**Count**: 4 occurrences.

**Ergonomic assessment**: `.create.recursive()` is clean and reads well.

---

## 4. Path Composition

### 4a. `/` Operator Chains

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 67 | `testDir / ".snapshots"` | Path / String literal |
| swift-tests/.../Test.Snapshot.Storage.swift | 69 | `snapshotDir / Swift.String(subdirectory)` | Path / String variable |
| swift-tests/.../Test.Snapshot.Storage.swift | 83 | `snapshotDir / filename` | Path / String |
| swift-tests/.../Tests.Baseline.Storage.swift | 65 | `result / testID.module` | Path / String |
| swift-tests/.../Tests.Baseline.Storage.swift | 69 | `result / Swift.String(component)` | Path / String (in loop) |
| swift-tests/.../Tests.Baseline.Storage.swift | 75 | `result / testID.name` | Path / String |
| swift-tests/.../Tests.Baseline.Storage.swift | 77 | `result / "\(fingerprint).json"` | Path / interpolated String |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 95 | `baseRoot / "complexity" / "\(key).json"` | **Chained `/`** |
| swift-tests/.../Tests.History.Storage.swift | 39-54 | Same pattern as Baseline.Storage | 5 uses |

**Count**: ~13 occurrences.

**Ergonomic assessment**: The `/` operator is the **most ergonomic path composition pattern**. `baseRoot / "complexity" / "\(key).json"` reads naturally. The pattern `output/"\(name).pdf"` without spaces is also used and reads like filesystem paths.

### 4b. `.parent` Access

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 64 | `testPath.parent ?? testPath` | With fallback |
| swift-tests/.../Test.Snapshot.Storage.swift | 142 | `path.parent` | In guard let |
| swift-tests/.../Tests.Baseline.Storage.swift | 121 | `path.parent` | In if let |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 117 | `path.parent` | In if let |
| swift-tests/.../Tests.History.Storage.swift | 112 | `filePath.parent` | In if let |
| swift-tests/.../Tests.History.Storage.swift | 154 | (implicit via path computation) | |

**Count**: 5 explicit occurrences.

**Ergonomic assessment**: `.parent` is clean and ergonomic.

---

## 5. Conversion Patterns

### 5a. `Swift.String(path)` / `Swift.String(describing: path)` — Path to String

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 151 | `Swift.String(path)` | For error message |
| swift-tests/.../Test.Snapshot.Storage.swift | 173 | `Swift.String(path)` | Same |
| swift-tests/.../Tests.Baseline.Storage.swift | 131 | `Swift.String(describing: path)` | **Different**: uses `describing:` |
| swift-tests/.../Tests.Baseline.Storage.swift | 148 | `Swift.String(describing: path)` | Same |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 124 | `Swift.String(describing: parent)` | Same |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 136 | `Swift.String(describing: path)` | Same |
| swift-tests/.../Tests.History.Storage.swift | 127 | `Swift.String(describing: filePath)` | Same |
| swift-tests/.../Tests.History.Storage.swift | 148 | `Swift.String(describing: path)` | Same |
| swift-tests/.../snapshot.swift | 349 | `Swift.String("\(snapshotPath)")` | **String interpolation** |
| swift-tests/.../Test.Snapshot.Storage Tests.swift | 23, 38, 52, 65, 78, 98 | `Swift.String(path)` | 6x in tests |
| swift-tests/.../Test.Trait.Scope.Provider.timed.swift | 99 | `Swift.String(baselinePath)` | |

**Count**: ~15 occurrences.

**Ergonomic assessment**: There is a **split between `Swift.String(path)`, `Swift.String(describing: path)`, and `"\(path)"`**. This inconsistency suggests the conversion API is unclear. Consumers don't know which to use.

### 5b. Path used as `String(subdirectory)` — Component to String

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 69 | `Swift.String(subdirectory)` where subdirectory is `File.Path.Component` | Component to String for `/` operator |

**Count**: 1 occurrence.

---

## 6. Type Annotation Patterns

### 6a. `File.Path` in Function Signatures

| File | Line | Code |
|------|------|------|
| swift-tests/.../Test.Snapshot.Storage.swift | 53 | `public static func path(...) -> File.Path` |
| swift-tests/.../Test.Snapshot.Storage.swift | 59 | `snapshotDirectory: File.Path? = nil` |
| swift-tests/.../Test.Snapshot.Storage.swift | 60 | `subdirectory: File.Path.Component? = nil` |
| swift-tests/.../Test.Snapshot.Storage.swift | 104 | `public static func reference(at path: File.Path) -> [UInt8]?` |
| swift-tests/.../Test.Snapshot.Storage.swift | 121 | `public static func exists(at path: File.Path) -> Bool` |
| swift-tests/.../Test.Snapshot.Storage.swift | 139 | `to path: File.Path` |
| swift-tests/.../Test.Snapshot.Storage.swift | 161 | `public static func ensure(directory path: File.Path)` |
| swift-tests/.../Test.Snapshot.Configuration.swift | 40 | `public var snapshotDirectory: File.Path?` |
| swift-tests/.../Test.Snapshot.Configuration.swift | 55 | `public var subdirectory: File.Path.Component?` |
| swift-tests/.../Tests.Baseline.Storage.swift | 39 | `public static func root() -> File.Path` |
| swift-tests/.../Tests.Baseline.Storage.swift | 58 | `root: File.Path` |
| swift-tests/.../Tests.Baseline.Storage.swift | 89 | `at path: File.Path` |
| swift-tests/.../Tests.Baseline.Storage.swift | 119 | `to path: File.Path` |
| swift-tests/.../Tests.Baseline.Storage.swift | 139 | `at path: File.Path` |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 91 | `root: File.Path? = nil` |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 99 | `at path: File.Path` |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 115 | `to path: File.Path` |
| swift-tests/.../Tests.History.Storage.swift | 35 | `root: File.Path` |
| swift-tests/.../Tests.History.Storage.swift | 103 | `root: File.Path` |
| swift-tests/.../Tests.History.Storage.swift | 138 | `at path: File.Path` |
| swift-tests/.../Tests.History.Storage.swift | 154 | `at path: File.Path` |
| swift-tests/.../Tests.History.Storage.swift | 180 | `at path: File.Path` |
| swift-tests/.../Tests.History.Storage.swift | 203 | `root: File.Path` |
| swift-tests/.../snapshot.swift | 335 | `snapshotDirectory: File.Path? = nil` |
| swift-tests/.../snapshot.swift | 336 | `subdirectory: File.Path.Component? = nil` |

**Count**: ~25 function parameter annotations + 2 stored property annotations.

**Ergonomic assessment**: `File.Path` is used consistently in APIs. `File.Path.Component` is used for subdirectory names. Both are clean.

### 6b. Local Variable Type Annotations

| File | Line | Code |
|------|------|------|
| swift-tests/.../Test.Snapshot.Storage.swift | 63 | `let testPath: File.Path = File.Path(stringLiteral: testFilePath)` |

**Count**: 1 explicit type annotation. Most other variables infer the type.

---

## 7. Kernel `Path_Primitives` Consumers (L1/L2)

These are not `File_System` consumers but use the lower-level `Path_Primitives` directly:

### 7a. swift-kernel-primitives (Kernel Path Primitives)

- **Kernel.Path.swift**: `public typealias Path = Tagged<Kernel, Path_Primitives.Path>` — wraps `Path_Primitives.Path` as a phantom-typed kernel-domain path.
- **Kernel.Path.Resolution.Error.swift**: Extends `Path.Resolution.Error` with `init?(code: Kernel.Error.Code)` — maps POSIX/Windows error codes to semantic path resolution errors.
- **Kernel.Path.Canonical.Error.swift**: `Path.Canonical.Error` enum wrapping resolution, permission, and platform errors.

**Pattern**: Pure type-level reuse — no file I/O call sites.

### 7b. swift-iso-9945 (ISO 9945 Kernel)

- **exports.swift**: `public import Path_Primitives` — re-exports so `Path.Char` is visible at ISO 9945 call sites.

**Pattern**: Export-only — no call sites.

---

## 8. Pattern Summary Table

| Pattern | Count | Ergonomic? | Notes |
|---------|-------|------------|-------|
| `File(path)` | ~14 | Good | Clean construction |
| `File("/literal")` | 3 | Excellent | String literal directly to File |
| `File.Path(stringLiteral: variable)` | 5 | Poor | Needed for String variables when ExpressibleByStringLiteral doesn't apply |
| `File.Path("/literal")` | 2 | Good | Literal as argument |
| `file.read.full { span in ... }` | 5 | Verbose | Always requires unsafe buffer pointer dance |
| `file.write.atomic(...)` | 5 | Good | Clean chained API |
| `file.write.append(...)` | 1 | Good | |
| `doc.write(to: File(...))` | 3 | OK | Binary.Serializable convenience |
| `file.stat.exists` | 9 | OK | Somewhat verbose for a common check |
| `dir.create.recursive()` | 4 | Good | Instance method |
| `path / "component"` | ~13 | Excellent | Natural path composition |
| `path.parent` | 5 | Excellent | |
| `Swift.String(path)` vs `Swift.String(describing: path)` | ~15 | Inconsistent | No clear canonical conversion |

---

## 9. Key Findings

### Pain Points

1. **String-to-Path conversion**: `File.Path(stringLiteral: variable)` is the worst pattern, used 5 times. There is no clean `File.Path(string: someString)` non-throwing convenience for known-good paths from `#filePath`.

2. **`file.read.full` boilerplate**: Every consumer does `span.withUnsafeBufferPointer { Array($0) }` or the String equivalent. A convenience `file.read.bytes()` or `file.read.string()` would eliminate this.

3. **Path-to-String inconsistency**: Consumers use `Swift.String(path)`, `Swift.String(describing: path)`, and `"\(path)"` interchangeably. Need one canonical conversion.

4. **`.stat.exists` verbosity**: The `.stat.exists` pattern is used 9 times for what is often a simple existence check. A convenience `.exists` accessor would reduce boilerplate.


### Strengths

1. **`/` operator**: The most natural and ergonomic API. `path / "component" / "file.json"` reads cleanly. Used ~13 times.

2. **`File(path)` and `File("/literal")`**: Clean construction. `File("/tmp/output.pdf")` is the most ergonomic file construction pattern.

3. **Instance-method chains**: `file.read.full { }`, `file.write.atomic()`, `dir.create.recursive()` form a consistent, discoverable API.

4. **`File.Path` as typealias for `Paths.Path`**: Clean integration between layers. `File.Path.Component` for validated single-component names works well.

5. **`doc.write(to: path, createIntermediates: true)`**: The Binary.Serializable convenience is well-used for PDF output in swift-pdf tests.
