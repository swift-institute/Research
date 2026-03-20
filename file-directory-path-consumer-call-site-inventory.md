# File / Directory / Path Consumer Call-Site Inventory

**Date**: 2026-03-19
**Scope**: All repos under `/Users/coen/Developer/` that import `File_System`, `File_System_Primitives`, `Paths`, or `Path_Primitives` — excluding `swift-file-system` and `swift-paths` source/test files.

---

## Consumer Repos Found

| Repo | Module/File | Imports |
|------|-------------|---------|
| swift-foundations/swift-tests | Tests Snapshot, Tests Performance, Tests Inline Snapshot | `File_System` |
| swift-foundations/swift-pdf | PDF (exports.swift) | `@_exported File_System` |
| swift-foundations/swift-pdf (tests) | PDF Tests | `File_System` (via PDF re-export) |
| swift-primitives/swift-kernel-primitives | Kernel Path Primitives | `Path_Primitives` |
| swift-iso/swift-iso-9945 | ISO 9945 Kernel | `Path_Primitives` |
| rule-legal/rule-legal-demo | Tests (3 files) | `File_System` |
| rule-legal/rule-legal-us-nv-private-corporation | Tests (2 files) | `File_System` |
| rule-legal/rule-legal-nl/rule-besloten-vennootschap | Aandeelhoudersregister PDF (exports) | `@_exported File_System` |
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
| rule-legal-demo/.../IncorporationTests.swift | 19 | `let output: File.Path = "/tmp/rule-legal-demo/Swift Technologies Inc"` | **String literal assigned to File.Path type annotation — ergonomic** |

**Count**: 6 occurrences of `File.Path(stringLiteral:)`, 1 string literal with type annotation.

**Ergonomic assessment**: The `File.Path(stringLiteral: variable)` pattern is **clunky**. It is necessary because Swift's `ExpressibleByStringLiteral` only works for actual literals, not String variables. The `let x: File.Path = "/literal"` pattern is clean. A `File.Path(_ string:)` throwing init exists but requires `try`.

### 1b. `File.Path` from String Variable (via `try File.Path(_:)`)

| File | Line | Code | Notes |
|------|------|------|-------|
| rule-legal/.../StressTests.swift | 195 | `try File.Path("\(corpDir)/\(filename)")` | String interpolation, throwing |
| rule-legal/.../StressTests.swift | 233 | `try File.Path(basePath)` | Variable, throwing |
| rule-legal/.../StressTests.swift | 302 | `File.Path(corpDir)` | Non-try variant (string literal passed) |
| rule-legal/.../StressTests.swift | 370 | `try File.Path("\(basePath)/corp-0000/01-articles-of-incorporation.pdf")` | Interpolation |
| rule-legal/.../StressTests.swift | 373 | `try File.Path("\(basePath)/corp-\(...)/.../")` | Interpolation |
| rule-legal/.../IncorporationTests.swift | 932 | `File.Path("/tmp/.../articles-of-incorporation-simple.pdf")` | Literal as argument |
| rule-legal/.../IncorporationTests.swift | 1000, 1041, 1071, 1101 | `File.Path("/tmp/.../<name>.pdf")` | 4 more literal-as-argument |
| rule-legal/.../IncorporationTests.swift | 1192-1268 | `File.Path("\(basePath)/01-articles-of-incorporation.pdf")` | 10 interpolation paths |
| rule-legal/.../ScaleDemoTests.swift | 28 | `File.Path(output)` | Variable |
| rule-legal/.../ScaleDemoTests.swift | 54 | `File.Path(filePath)` | Variable |
| rule-legal/.../ScaleDemoTests.swift | 74-76 | `try File.Path("\(output)/0001-Apex Industries Inc.pdf")` | 3 interpolated |
| rule-legal/.../AnnualComplianceTests.swift | 22 | `File.Path(output)` | Variable |
| rule-legal/.../AnnualComplianceTests.swift | 34 | `File.Path("\(output)/Annual List of Officers.pdf")` | Interpolation |
| rule-legal/.../AnnualComplianceTests.swift | 37 | `try File.Path("\(output)/Annual List of Officers.pdf")` | Same with try |
| swift-tests/.../Test.Snapshot.Storage Tests.swift | 29 | `File.Path("/custom/snapshots")` | Literal as argument |
| swift-tests/.../Test.Snapshot.Storage Tests.swift | 95 | `File.Path("/custom")` | Literal as argument |
| rule-legal/.../Aandeelhoudersregister PDF Tests.swift | 146 | `document.write(to: "/tmp/aandeelhoudersregister-hakuna.pdf", ...)` | String literal directly to `write(to:)` — works via `ExpressibleByStringLiteral` on `File.Path` |

**Count**: ~30+ occurrences.

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
| rule-legal/.../StressTests.swift | 234 | `File(basePathObj).exists` | Construction + property access |
| rule-legal/.../StressTests.swift | 371 | `File(samplePath).exists` | Same |
| rule-legal/.../StressTests.swift | 374 | `File(lastPath).exists` | Same |
| rule-legal/.../ScaleDemoTests.swift | 74-76 | `File(try File.Path("...")).exists` | **Triple nesting**: `File(try File.Path(...)).exists` |
| rule-legal/.../IncorporationTests.swift (demo) | 36 | `File(output/"Articles of Incorporation.pdf").exists` | Clean — path composition inside File() |
| rule-legal/.../AnnualComplianceTests.swift | 37 | `File(try File.Path("...")).exists` | Same double-wrapping |
| swift-pdf/.../PDF Tests.swift | 58 | `File("/tmp/swift-pdf/markdown-to-pdf-test.pdf")` | **Direct string literal to File** — very clean |
| swift-pdf/.../PDF Tests.swift | 97 | `File("/tmp/swift-pdf/markdown-table-to-pdf-test.pdf")` | Same |
| swift-pdf/.../PDF Tests.swift | 189 | `File("/tmp/swift-pdf/markdown-complex-to-pdf-test.pdf")` | Same |

**Count**: ~20 occurrences.

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
| rule-legal/.../IncorporationTests.swift | 932 | `try doc.write(to: File.Path("..."))` | PDF via Binary.Serializable |
| rule-legal/.../IncorporationTests.swift | 1000, 1041, 1071, 1101 | `try doc.write(to: File.Path("..."))` | 4 more |
| rule-legal/.../IncorporationTests.swift | 1192-1268 | `try ...Doc.write(to: File.Path("\(basePath)/..."))` | 10 more |
| rule-legal/.../Aandeelhoudersregister PDF Tests.swift | 146 | `try document.write(to: "/tmp/...", createIntermediates: true)` | String literal — **most ergonomic** |
| rule-legal/.../ScaleDemoTests.swift | 54 | `.write(to: File.Path(filePath))` | Via File.Path |
| rule-legal/.../AnnualComplianceTests.swift | 34 | `.write(to: File.Path("\(output)/..."))` | Interpolation |
| rule-legal/.../IncorporationTests.swift (demo) | 33 | `.write(to: output/"\(name).pdf")` | **`/` operator composition** — most ergonomic |
| swift-pdf/.../PDF Tests.swift | 58 | `try doc.write(to: File("..."), createIntermediates: true)` | File literal |
| swift-pdf/.../PDF Tests.swift | 97, 189 | Same pattern | 2 more |

**Count**: ~25 occurrences.

**Ergonomic assessment**: The `doc.write(to: File.Path(...))` pattern is the **dominant PDF output pattern**. The `doc.write(to: output/"\(name).pdf")` variant using the `/` operator is the most ergonomic form. `doc.write(to: "/tmp/file.pdf", createIntermediates: true)` with a string literal is also very clean.

### 2e. `File.System.Write.Atomic.write(bytes, to: path)` — Static Atomic Write

| File | Line | Code | Notes |
|------|------|------|-------|
| rule-legal/.../StressTests.swift | 309 | `try await File.System.Write.Atomic.write(pdf.bytes, to: pdf.path, options: .init(durability: .dataOnly))` | Async, with options |

**Count**: 1 occurrence.

**Ergonomic assessment**: The fully qualified `File.System.Write.Atomic.write(...)` is verbose but necessary for the async variant with explicit options.

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
| rule-legal/.../StressTests.swift | 234 | `File(basePathObj).exists` | **Note**: `.exists` not `.stat.exists` |
| rule-legal/.../StressTests.swift | 371, 374 | `File(samplePath).exists` | Same |
| rule-legal/.../ScaleDemoTests.swift | 74-76 | `File(try File.Path("...")).exists` | 3x, uses `.exists` |
| rule-legal/.../IncorporationTests.swift (demo) | 36 | `File(output/"...").exists` | `.exists` |
| rule-legal/.../AnnualComplianceTests.swift | 37 | `File(try File.Path("...")).exists` | `.exists` |

**Count**: 14 occurrences (9 `.stat.exists`, 5 `.exists`).

**Ergonomic assessment**: There is a **split between `.stat.exists` and `.exists`**. The swift-tests code consistently uses `.stat.exists` while rule-legal code uses `.exists` directly. This suggests either a convenience accessor was added or the APIs differ between contexts.

### 3b. `dir.create.recursive()` — Directory Creation

| File | Line | Code | Notes |
|------|------|------|-------|
| swift-tests/.../Test.Snapshot.Storage.swift | 171 | `try dir.create.recursive()` | |
| swift-tests/.../Tests.Baseline.Storage.swift | 145 | `try dir.create.recursive()` | |
| swift-tests/.../Tests.Complexity.Baseline+Storage.swift | 121 | `try dir.create.recursive()` | |
| swift-tests/.../Tests.History.Storage.swift | 144 | `try dir.create.recursive()` | |

**Count**: 4 occurrences.

**Ergonomic assessment**: `.create.recursive()` is clean and reads well.

### 3c. `File.System.Create.Directory.create(at:)` — Static Directory Creation

| File | Line | Code | Notes |
|------|------|------|-------|
| rule-legal/.../StressTests.swift | 237 | `try await File.System.Create.Directory.create(at: basePathObj)` | Async |
| rule-legal/.../StressTests.swift | 302 | `try await File.System.Create.Directory.create(at: File.Path(corpDir))` | Async |
| rule-legal/.../ScaleDemoTests.swift | 27-29 | `try File.System.Create.Directory.create(at: File.Path(output), options: .init(createIntermediates: true))` | With options |
| rule-legal/.../IncorporationTests.swift (demo) | 20-22 | `try File.System.Create.Directory.create(at: output, options: .init(createIntermediates: true))` | With options |
| rule-legal/.../AnnualComplianceTests.swift | 21-23 | `try File.System.Create.Directory.create(at: File.Path(output), options: .init(createIntermediates: true))` | With options |

**Count**: 5 occurrences.

**Ergonomic assessment**: `File.System.Create.Directory.create(at:options:)` is **very verbose**. Compare with the instance method `dir.create.recursive()` which is much more readable. The static form is used in async contexts where the instance method may not be available.

### 3d. `File.System.Delete.delete(at:options:)` — Static Delete

| File | Line | Code | Notes |
|------|------|------|-------|
| rule-legal/.../StressTests.swift | 235 | `try await File.System.Delete.delete(at: basePathObj, options: .init(recursive: true))` | Async recursive delete |

**Count**: 1 occurrence.

**Ergonomic assessment**: Verbose but clear.

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
| rule-legal/.../IncorporationTests.swift (demo) | 33 | `output/"\(name).pdf"` | **No spaces around `/`** — infix operator |
| rule-legal/.../IncorporationTests.swift (demo) | 36 | `output/"Articles of Incorporation.pdf"` | Same |

**Count**: ~15 occurrences.

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
| rule-legal/.../StressTests.swift | 176 | `let path: File.Path` (struct property) |

**Count**: ~25 function parameter annotations + 2 stored property annotations.

**Ergonomic assessment**: `File.Path` is used consistently in APIs. `File.Path.Component` is used for subdirectory names. Both are clean.

### 6b. Local Variable Type Annotations

| File | Line | Code |
|------|------|------|
| swift-tests/.../Test.Snapshot.Storage.swift | 63 | `let testPath: File.Path = File.Path(stringLiteral: testFilePath)` |
| rule-legal/.../IncorporationTests.swift (demo) | 19 | `let output: File.Path = "/tmp/rule-legal-demo/Swift Technologies Inc"` |

**Count**: 2 explicit type annotations. Most other variables infer the type.

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
| `File(path)` | ~20 | Good | Clean construction |
| `File("/literal")` | 3 | Excellent | String literal directly to File |
| `File.Path(stringLiteral: variable)` | 6 | Poor | Needed for String variables when ExpressibleByStringLiteral doesn't apply |
| `try File.Path(string)` | ~30 | OK | Correct but verbose for known-good paths |
| `File.Path("/literal")` | ~15 | Good | Literal as argument |
| `let x: File.Path = "/literal"` | 1 | Excellent | Type annotation + literal |
| `file.read.full { span in ... }` | 5 | Verbose | Always requires unsafe buffer pointer dance |
| `file.write.atomic(...)` | 5 | Good | Clean chained API |
| `file.write.append(...)` | 1 | Good | |
| `doc.write(to: File.Path(...))` | ~25 | OK | Binary.Serializable convenience |
| `doc.write(to: path / "name.pdf")` | 1 | Excellent | / operator composition into write |
| `file.stat.exists` | 9 | OK | Somewhat verbose for a common check |
| `file.exists` | 5 | Good | Convenience shorthand |
| `dir.create.recursive()` | 4 | Good | Instance method |
| `File.System.Create.Directory.create(at:)` | 5 | Poor | Very verbose static form |
| `File.System.Write.Atomic.write(...)` | 1 | Poor | Very verbose static form |
| `File.System.Delete.delete(at:)` | 1 | Poor | Very verbose static form |
| `path / "component"` | ~15 | Excellent | Natural path composition |
| `path.parent` | 5 | Excellent | |
| `Swift.String(path)` vs `Swift.String(describing: path)` | ~15 | Inconsistent | No clear canonical conversion |

---

## 9. Key Findings

### Pain Points

1. **String-to-Path conversion**: `File.Path(stringLiteral: variable)` is the worst pattern, used 6 times. There is no clean `File.Path(string: someString)` non-throwing convenience for known-good paths from `#filePath`.

2. **`file.read.full` boilerplate**: Every consumer does `span.withUnsafeBufferPointer { Array($0) }` or the String equivalent. A convenience `file.read.bytes()` or `file.read.string()` would eliminate this.

3. **Static `File.System.*` verbosity**: `File.System.Create.Directory.create(at:options:)` and `File.System.Write.Atomic.write(...)` are used 6 times total. These are **extremely verbose** compared to the instance methods `dir.create.recursive()` and `file.write.atomic(...)`. The static forms are needed for async contexts.

4. **Path-to-String inconsistency**: Consumers use `Swift.String(path)`, `Swift.String(describing: path)`, and `"\(path)"` interchangeably. Need one canonical conversion.

5. **`.stat.exists` vs `.exists` split**: swift-tests uses `.stat.exists` (9 times), rule-legal uses `.exists` (5 times). If `.exists` is a convenience over `.stat.exists`, the older code should be updated.

### Strengths

1. **`/` operator**: The most natural and ergonomic API. `path / "component" / "file.json"` reads cleanly. Used ~15 times.

2. **`File(path)` and `File("/literal")`**: Clean construction. `File("/tmp/output.pdf")` is the most ergonomic file construction pattern.

3. **Instance-method chains**: `file.read.full { }`, `file.write.atomic()`, `dir.create.recursive()` form a consistent, discoverable API.

4. **`File.Path` as typealias for `Paths.Path`**: Clean integration between layers. `File.Path.Component` for validated single-component names works well.

5. **`doc.write(to: path, createIntermediates: true)`**: The Binary.Serializable convenience is well-used (~25 times for PDF output).
