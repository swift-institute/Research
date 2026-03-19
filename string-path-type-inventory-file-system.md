# String and Path Type Inventory: swift-file-system and Upstream

<!--
---
version: 2.0.0
last_updated: 2026-03-19
status: DECISION
tier: 2
---
-->

## Context

The file system stack (swift-file-system, swift-kernel, swift-paths, swift-strings) uses multiple string and path types across API boundaries. The current inventory reveals potential semantic mismatches where `Swift.String` is used in positions that represent file system paths, glob patterns, or path components — domains where `Path`, `Path.View`, `Kernel.Path.View`, or `Path.Component` would be more appropriate.

**Trigger**: During review of `File.Directory.Glob`, observed that `Kernel.Glob.match(include:excluding:in:options:)` accepts `Swift.String` for the directory parameter and returns `[Swift.String]`, when these clearly represent file system paths. Similarly, the internal `_matchPaths` helper uses `[Swift.String]` for include/exclude patterns.

**Scope**: Cross-package (Paths, Strings, Kernel, File System, POSIX Kernel). Ecosystem-wide per [RES-002a].

**Method**: `swift package dump-symbol-graph` for public API surface across all four packages, supplemented with source-level grep for `@usableFromInline`/`internal` signatures.

## Question

Which uses of `Swift.String` across the file system stack are semantically incorrect — i.e., represent a path, path component, or glob pattern rather than arbitrary text?

## Type Hierarchy

The stack has a clear type chain that should govern which type appears where:

```
Layer 1 (Primitives)
  String_Primitives.String      (~Copyable, platform-encoded bytes)
  String_Primitives.String.View (~Copyable, ~Escapable, borrowed view)
  Path_Primitives.Path          (~Copyable, platform-encoded bytes)
  Path_Primitives.Path.View     (~Copyable, ~Escapable, borrowed view)

Layer 2 (Kernel namespace)
  Kernel.String = Tagged<Kernel, String_Primitives.String>
  Kernel.Path   = Tagged<Kernel, Path_Primitives.Path>
  Kernel.Path.View (non-escapable borrowed view)

Layer 3 (Foundations)
  Paths.Path                    (Copyable, owning, user-facing)
  Paths.Path.View               (~Copyable, ~Escapable, borrowed)
  Paths.Path.Component          (validated single component)
  File.Path = Paths.Path        (typealias in swift-file-system)

  Swift.String                  (used for display, serialization, user I/O)
```

**Principle**: APIs that semantically operate on file system paths should accept/return path types. `Swift.String` should appear only at display boundaries (description, debugDescription, formatted) and at explicit conversion points.

## Inventory

### Summary

| Category | Count | Description |
|----------|-------|-------------|
| A | 93 | `Swift.String` in non-display API signatures — potential path/component candidates |
| B | 15 | `Kernel.Path.View` / `Path.View` in API signatures — correct |
| C | 11 | Mixed String + Path at conversion boundaries |
| D | 48 | Display properties (description, debugDescription, formatted) — String correct |
| E | 28 | Error enum cases with String associated values |
| **Total** | **301** | Across 7 modules |

### By Module

| Module | Symbols |
|--------|---------|
| File_System | 73 |
| File_System_Primitives | 91 |
| File_System_Test_Support | 8 |
| Kernel | 62 |
| Kernel_Test_Support | 8 |
| Paths | 47 |
| Strings | 12 |

---

### Category A: `Swift.String` in API Signatures (Non-Display)

These are the highest-priority findings — places where `Swift.String` appears in an API position that semantically represents a path, path component, or glob pattern.

#### A1: Glob Pipeline — String Where Path Expected

The entire glob pipeline operates on `Swift.String`. Both the primitives-level API and the file-system-level API.

**Kernel.Glob (Primitives, swift-kernel-primitives)**:
- `Kernel.Glob.isPattern(_: Swift.String) -> Bool`
- `Kernel.Glob.Pattern.init(_: Swift.String) throws(Error)`
- `Kernel.Glob.Pattern.raw: Swift.String`
- `Kernel.Glob.Segment.literal(Swift.String)`
- `Kernel.Glob.Atom.literal(Swift.String)`

**Kernel.Glob.match (POSIX/Windows, swift-posix / swift-windows)**:
- `Kernel.Glob.match(pattern:in directory: Swift.String, options:) throws(Error) -> [Swift.String]`
- `Kernel.Glob.match(include:excluding:in directory: Swift.String, options:) throws(Error) -> [Swift.String]`

**File.Directory.Glob (File System)**:
- `_matchPaths(include: [Swift.String], excluding: [Swift.String], options:) throws -> [Swift.String]`
- `callAsFunction(include: [Swift.String], excluding: [Swift.String], ...) throws -> [Match]` (×2: sync + async)
- `directories(include: [Swift.String], excluding: [Swift.String], ...) throws -> [File.Directory]` (×2)
- `files(include: [Swift.String], excluding: [Swift.String], ...) throws -> [File]` (×2)

**Assessment**: The `in directory:` parameter clearly represents a path — should be `Kernel.Path.View` or `Path`. The `include`/`excluding` arrays are glob pattern strings, which are a distinct domain. The return `[Swift.String]` represents matched file paths — should be path types.

The patterns themselves (`"*.txt"`, `"src/**/*.swift"`) are arguably textual — they're pattern specifications, not paths. However, `Kernel.Glob.Pattern` already exists as a validated type. The question is whether the raw input should be `String` (for ergonomics) or a path-like type.

#### A2: File/Directory Navigation — String Where Component Expected

**File System module**:

| Symbol | Declaration | File |
|--------|-------------|------|
| `File./(_:_:)` | `static func / (lhs: File, rhs: String) -> File` | File.swift:44 |
| `File.Directory./(_:_:)` | `static func / (lhs: File.Directory, rhs: String) -> File.Directory` | File.Directory.swift:81 |
| `File.appending(_:)` | `func appending(_ component: String) -> File` | File.swift:34 |
| `File.Directory.appending(_:)` | `func appending(_ component: String) -> File.Directory` | File.Directory.swift:71 |
| `File.Directory.subdirectory(_:)` | `func subdirectory(_ name: String) -> File.Directory` | File.Directory.swift:49 |
| `File.Directory.subscript(_:)` | `subscript(name: String) -> File` | File.Directory.swift:14 |
| `File.Directory.subscript(file:)` | `subscript(file name: String) -> File` | File.Directory.swift:27 |
| `File.Directory.subscript(directory:)` | `subscript(directory name: String) -> File.Directory` | File.Directory.swift:41 |

**Assessment**: These all represent path component appending. The parameter labeled `component` or `name` is semantically a `Path.Component` (or at minimum a single-component string). Using `String` allows invalid inputs like `"foo/bar"` or `""`.

Note: `Paths.Path` already has both `Path / String -> Path` and `Path / Path.Component -> Path` operators, plus `Path.appending(_: String)` and `Path.appending(_: Path.Component)`. File System mirrors the String overloads but not the Component overloads.

#### A3: File Properties — String Where Component-Derived

| Symbol | Declaration | File |
|--------|-------------|------|
| `File.name` | `var name: String { get }` | File.swift:16 |
| `File.extension` | `var extension: String? { get }` | File.swift:21 |
| `File.stem` | `var stem: String? { get }` | File.swift:26 |
| `File.Directory.name` | `var name: String { get }` | File.Directory.swift:63 |

**Assessment**: These are derived from `Path.Component.string`, `.extension`, `.stem` — which are themselves `String`. These are display/introspection properties where `String` is defensible. `Path.Component` itself uses `String` for these. Lower priority.

#### A4: Rename Operations — String Where Component Expected

| Symbol | Declaration | File |
|--------|-------------|------|
| `File.Move.rename(to:options:)` | `rename(to newName: String, ...) -> File` | File.Move.swift:76 |
| `File.Move.rename(to:options:)` | `rename(to newName: String, ...) async -> File` | File.Move.swift:133 |
| `File.Directory.Move.rename(to:options:)` | `rename(to newName: String, ...) -> File.Directory` | File.Directory.Move.swift:76 |
| `File.Directory.Move.rename(to:options:)` | `rename(to newName: String, ...) async -> File.Directory` | File.Directory.Move.swift:133 |

**Assessment**: `newName` is a file/directory name — semantically a `Path.Component`. Using `String` allows invalid names (containing `/`, empty, etc.).

#### A5: Write Operations — String as Content (Correct)

| Symbol | Declaration | File |
|--------|-------------|------|
| `File.Write.atomic(_:options:)` | `func atomic(_ string: String, ...) throws` | File.Write.swift:68 |
| `File.Write.append(_:)` | `func append(_ string: String) throws` | File.Write.swift:107 |

**Assessment**: These write string content to files. `String` is semantically correct here — this is text content, not a path.

#### A6: Path.Property — Mixed

| Symbol | Declaration | File |
|--------|-------------|------|
| `Path.Property.set` | `let set: (File.Path, String) -> File.Path` | File.Path.Property.swift:32 |
| `Path.Property.init(set:remove:)` | `init(set: (File.Path, String) -> File.Path, ...)` | File.Path.Property.swift:38 |
| `Path.with(_:_:)` | `func with(_ property: Path.Property, _ value: String) -> Path` | File.Path.Property.swift:58 |

**Assessment**: Used for setting path properties like extension. The `value: String` is the new extension or stem value — this is a valid string (not a path).

#### A7: Kernel Error Cases — Path Stored as String

**Kernel.File.Write.Atomic.Error** (13 cases, all using `String`):
- `destinationExists(path: String)`
- `destinationStatFailed(path: String, ...)`
- `parentVerificationFailed(path: String, ...)`
- `tempFileCreationFailed(directory: String, ...)`
- `renameFailed(from: String, to: String, ...)`
- ...and 8 more with `message: String` (correct — human-readable text)

**Kernel.File.Write.Streaming.Error** (14 cases, same pattern):
- `parentVerificationFailed(path: String, ...)`
- `fileCreationFailed(path: String, ...)`
- `destinationExists(path: String)`
- ...and 11 more

**Kernel.File.Write.Streaming.Context** (stored properties):
- `tempPathString: String?`
- `resolvedPathString: String`
- `parentPathString: String`

**Assessment**: The `path:` associated values clearly represent file paths stored as `String`. At the Kernel layer, `Kernel.Path` is ~Copyable and cannot be stored in Sendable error enums — `String` is the pragmatic internal representation. However, `Paths.Path` (L3) IS `Copyable, Sendable, Hashable`. swift-kernel does not depend on swift-paths (by design — Kernel is a lower-level abstraction), so Kernel cannot use `Paths.Path` directly. **Resolution**: Kernel keeps `String` internally; File System wraps Kernel errors into its own error types using `File.Path` (= `Paths.Path`). Consumers never see `String`-as-path.

The `message:` parameters are human-readable error descriptions — `String` is correct.

#### A8: File System Primitives — String Where Path Expected

| Symbol | Declaration | File |
|--------|-------------|------|
| `File.Directory.init(_:)` | `init(_ string: String) throws(Path.Error)` | File.Directory.swift:40 |

**Assessment**: Convenience initializer from string. This is a conversion boundary — `String` is appropriate as input since it mirrors `Path.init(_: String)`.

#### A9: Kernel Test Support — String Paths

| Symbol | Declaration | File |
|--------|-------------|------|
| `Kernel.Temporary.directory` | `static var directory: String` | Kernel.Temporary.swift:38 |
| `Kernel.Temporary.filePath(prefix:)` | `static func filePath(prefix: String) -> String` | Kernel.Temporary.swift:59 |
| `KernelIOTest.createTempFile(prefix:)` | `static func createTempFile(...) -> (path: String, fd: ...)` | Kernel.IO.Test.Helpers.swift:26 |
| `KernelIOTest.cleanupTempFile(path:fd:)` | `static func cleanupTempFile(path: String, ...)` | Kernel.IO.Test.Helpers.swift:51 |

**Assessment**: Test helpers returning/accepting `String` for temp paths. Since swift-kernel does not depend on swift-paths, these stay as `String` at the Kernel layer. File System Test Support wraps with `File.Path`.

---

### Category B: Correct Path.View Usage (15 symbols)

These already use `Kernel.Path.View` correctly:

| Symbol | Module |
|--------|--------|
| `Kernel.File.open(_:configuration:)` | Kernel |
| `Kernel.File.Clone.clone(from:to:behavior:)` | Kernel |
| `Kernel.File.Copy.copy(from:to:options:)` | Kernel |
| `Kernel.File.Write.Atomic.write(_:to:options:)` | Kernel |
| `Kernel.File.Write.Streaming.open(path:options:)` | Kernel |
| `Kernel.File.Write.Streaming.write(_:to:options:)` | Kernel (×4 overloads) |
| `KernelIOTest.withTempFile(...)` | Kernel_Test_Support (×3, body param) |
| `Path.View.kernelPath` | Paths |
| `Path.kernelPath` | Paths |
| `Path.view` | Paths |

**Pattern**: All kernel-level file operations (open, clone, copy, write) correctly accept `borrowing Kernel.Path.View`. The conversion to C strings happens inside these implementations. This is the correct design.

---

### Category C: Conversion Boundaries (11 symbols)

Places where both String and Path types appear — these are the explicit conversion points:

| Symbol | Declaration |
|--------|-------------|
| `Path.init(_: String)` | String → Path conversion (throws) |
| `Path.appending(_: String)` | String component appending (throws) |
| `Path / String` | String component operator |
| `Path.Component.init(_: String)` | String → Component conversion (throws) |
| `File.Directory.init(_: String)` | String → Directory conversion (throws) |
| `Path.Property.set` | `(File.Path, String) -> File.Path` |
| `KernelIOTest.withTempFile(...)` | String prefix + Path.View body |

These are appropriate conversion boundaries.

---

### Category D: Display Properties (48 symbols)

All `description`, `debugDescription`, and `formatted(_:)` properties/methods. `String` is semantically correct for display.

---

### Category E: Error Enum Cases (28 symbols)

See A7 above. Split into:
- `path:` labeled values: semantically paths, stored as String (constraint: ~Copyable Path in Sendable enum)
- `message:` labeled values: human-readable text, String correct
- `operation:` / `reason:` labeled values: descriptive text, String correct

## Analysis

### Governing Principle

Per [IMPL-INTENT] and [IMPL-000]: every API must read as intent. `Swift.String` at a call site where the value represents a path, component, extension, or stem is mechanism — it exposes a representation choice, not the domain concept. Per [IMPL-010]: push `String` to the edge, just like `Int(bitPattern:)`.

**Design approach**: Subtractive, not additive. Replace `String` with the domain type. Do not add typed overloads alongside existing String versions. String literals continue to work via `ExpressibleByStringLiteral` conformances already present on `Path` and `Path.Component`.

### Key Constraint Resolution

**`Paths.Path` is `Copyable, Sendable, Hashable`** (verified: `swift-paths/Sources/Paths/Path.swift:37`). The ~Copyable constraint applies only to `Path_Primitives.Path` (L1) and `Kernel.Path` (L1 tagged). The L3 `Paths.Path` can be stored in error enums, Sendable types, arrays, and all other contexts.

### Layering Decision

**swift-kernel does NOT depend on swift-paths** (by design). `Kernel.Path` / `Kernel.String` exist as L1 tagged ~Copyable types precisely because Kernel is a lower-level abstraction than Paths. This boundary is preserved.

Consequence: Kernel-layer code (swift-kernel, swift-posix, swift-windows) continues to use `Swift.String` for path representations in error types, stored properties, and glob results. This is an internal implementation detail. File System wraps all Kernel-facing APIs with its own domain-typed interfaces — consumers of File System never see `String`-as-path.

### New Types Required

Two types need to be introduced in swift-paths to complete the domain model:

| Type | Location | Validation | Conformances |
|------|----------|------------|--------------|
| `Path.Component.Extension` | swift-paths | No dots, no separators, non-empty | `Copyable, Sendable, Hashable, Equatable, ExpressibleByStringLiteral, CustomStringConvertible` |
| `Path.Component.Stem` | swift-paths | No separators, non-empty | Same |

These types close the domain model. Currently `Path.Component.extension` and `.stem` return `String` — a domain concept leaking into an untyped representation. With typed wrappers:
- Getters return the domain type
- Setters accept the domain type
- Literal call-site syntax is preserved via `ExpressibleByStringLiteral`
- Non-literal values go through validated construction

### Every Change, By Package

#### Phase 1: swift-paths (L3)

**New types**:
- `Path.Component.Extension` — validated extension type
- `Path.Component.Stem` — validated stem type

**API changes**:
| Current | Replace with |
|---------|-------------|
| `Path.Component.extension: String?` | `Path.Component.extension: Path.Component.Extension?` |
| `Path.Component.stem: String` | `Path.Component.stem: Path.Component.Stem` |
| `Path.Component.string: String` | Keep — explicit conversion boundary |
| `Path.extension: String? { get set }` | `Path.extension: Path.Component.Extension? { get set }` |
| `Path.stem: String?` | `Path.stem: Path.Component.Stem?` |
| `Path.string: String` | Keep — explicit conversion boundary |
| `Path / String → Path` | `Path / Path.Component → Path` (replace, not add) |
| `Path.appending(_: String)` | `Path.appending(_: Path.Component)` (replace) |
| `Path.init(_: String)` | Keep — String→Path conversion boundary |
| `Path.Component.init(_: String)` | Keep — String→Component conversion boundary |

**Conversion boundary principle**: `Path.init(_: String)` and `Path.Component.init(_: String)` stay — they ARE the boundary where untyped text enters the domain. Everything downstream speaks domain types.

#### Phase 2: swift-kernel, swift-posix, swift-windows (L3) — No Changes

These packages do not depend on swift-paths. Their internal use of `Swift.String` for path values in error types, Context properties, glob results, and test helpers stays as-is. This `String` usage is an implementation detail encapsulated behind the File System layer.

**Rationale**: `Kernel.Path` (~Copyable) exists for zero-copy syscall interfacing. `Paths.Path` (Copyable) exists for user-facing path manipulation. Kernel should not see Paths — the abstraction boundary is intentional.

The `Kernel.Glob.match(in: Swift.String) → [Swift.String]` signature stays. File System wraps it:
- Input: converts `File.Path` → `String` at the call site into Kernel.Glob (this conversion is internal to File System, invisible to consumers)
- Output: wraps `[String]` results into `[File]` / `[File.Directory]` / `[File.Directory.Glob.Match]`

#### Phase 3: swift-file-system (L3)

**Navigation — replace String with Path.Component**:
| Current | Replace with |
|---------|-------------|
| `File / String → File` | `File / Path.Component → File` |
| `File.Directory / String → File.Directory` | `File.Directory / Path.Component → File.Directory` |
| `File.appending(_: String) → File` | `File.appending(_: Path.Component) → File` |
| `File.Directory.appending(_: String)` | `File.Directory.appending(_: Path.Component)` |
| `File.Directory.subdirectory(_: String)` | `File.Directory.subdirectory(_: Path.Component)` |
| `File.Directory.subscript(_: String) → File` | `File.Directory.subscript(_: Path.Component) → File` |
| `File.Directory.subscript(file: String)` | `File.Directory.subscript(file: Path.Component)` |
| `File.Directory.subscript(directory: String)` | `File.Directory.subscript(directory: Path.Component)` |
| `File.Move.rename(to: String)` | `File.Move.rename(to: Path.Component)` |
| `File.Directory.Move.rename(to: String)` | `File.Directory.Move.rename(to: Path.Component)` |

All literal call sites (`directory / "Sources"`, `file.rename(to: "new.txt")`) continue to compile — `Path.Component` is `ExpressibleByStringLiteral`.

**Identity properties — return domain types**:
| Current | Replace with |
|---------|-------------|
| `File.name: String` | `File.name: Path.Component` |
| `File.extension: String?` | `File.extension: Path.Component.Extension?` |
| `File.stem: String?` | `File.stem: Path.Component.Stem?` |
| `File.Directory.name: String` | `File.Directory.name: Path.Component` |

**Glob — internal plumbing stays String, consumer API already typed**:

The consumer-facing glob API already returns `[File]`, `[File.Directory]`, `[Match]` — consumers never see `String`. Internally, `_matchPaths` delegates to `Kernel.Glob.match` which returns `[String]`; File System wraps results. The `include`/`excluding` parameters stay `[String]` — glob patterns are text specifications, not paths.

| Current | Verdict |
|---------|---------|
| `callAsFunction(include: [String], ...)` | Keep — patterns are text |
| `_matchPaths(...) → [String]` | Keep as internal — wraps Kernel.Glob |
| `Kernel.Glob.match(in: Swift.String(directory.path))` | Keep — internal conversion at File System boundary |

**Path.Property — accept domain types**:
| Current | Replace with |
|---------|-------------|
| `Path.Property.set: (File.Path, String) → File.Path` | Typed per property: `(File.Path, Path.Component.Extension) → File.Path` for extension; `(File.Path, Path.Component.Stem) → File.Path` for stem |
| `Path.with(_: Property, _: String)` | Typed per property |

**Error wrapping** — File System SHOULD define its own error types that wrap Kernel errors with `File.Path` instead of `String`:

Currently, File System surfaces Kernel error types directly (e.g., `throws(Kernel.File.Write.Atomic.Error)`). These contain `path: String`. The consumer sees `String` where they should see `File.Path`. File System should introduce wrapper error types that convert Kernel's `path: String` into `File.Path` at the boundary.

**Write operations — keep String**:
| Current | Verdict |
|---------|---------|
| `File.Write.atomic(_: String)` | Keep — file content, not path |
| `File.Write.append(_: String)` | Keep — file content, not path |

**File.Directory.init(_: String)** — keep as conversion boundary, mirrors `Path.init(_: String)`.

### String Remains Correct At

| Usage | Why |
|-------|-----|
| `description`, `debugDescription`, `formatted()` | Display output |
| `Path.init(_: String)`, `Path.Component.init(_: String)` | Conversion boundaries — where untyped text enters the domain |
| `Path.string`, `Path.Component.string` | Conversion boundaries — where domain types exit to text |
| `File.Write.atomic(_: String)`, `.append(_: String)` | File content, not paths |
| Glob `include`/`excluding` patterns (`[String]`) | Pattern specifications, not paths |
| Error `message: String`, `operation: String`, `reason: String` | Human-readable text |
| Test helper `prefix: String` | Arbitrary text for naming |
| All Kernel-internal `path: String` | Encapsulated behind File System — consumers don't see it |

## Outcome

**Status**: DECISION

**Decision**: Replace all consumer-visible `Swift.String`-as-path usage with domain types. Subtractive approach — replace, do not add alongside. Introduce `Path.Component.Extension` and `Path.Component.Stem` in swift-paths to complete the domain model. Kernel layer keeps `String` internally (does not depend on swift-paths); File System wraps at the boundary.

### Implementation Order

1. **swift-paths**: Create `Path.Component.Extension` and `Path.Component.Stem`. Update `Path.Component.extension`, `.stem`, `Path.extension`, `Path.stem` return types. Replace `Path / String` and `Path.appending(_: String)` with `Path.Component` parameter.
2. **swift-file-system**: Replace all navigation/identity APIs with `Path.Component`. Replace extension/stem properties with typed returns. Introduce wrapper error types. Path.Property becomes typed per property.

Phase 1 is the foundation. Phase 2 depends on it. Kernel/POSIX/Windows are unchanged.

### Consumer Call-Site Before/After

```swift
// Navigation — identical syntax, stronger types:
directory / "Sources"                     // ✅ Path.Component literal
directory["file.txt"]                     // ✅ Path.Component literal
file.rename(to: "newname.txt")            // ✅ Path.Component literal

// Identity — domain types, not String:
file.name                                 // Path.Component (was String)
file.extension                            // Path.Component.Extension? (was String?)
file.stem                                 // Path.Component.Stem? (was String?)

// Composition — type-safe round-tripping:
let ext = file.extension                  // Path.Component.Extension?
let newFile = file.path.with(.extension, ext!)  // same type in, same type out

// Non-literal input — validation at boundary:
let name = getUserInput()
directory / try Path.Component(name)      // validated (was: silently accepted any String)

// Glob — patterns stay String, results already typed:
directory.glob.files(include: ["*.swift"])  // returns [File], unchanged

// Write — content stays String:
file.write.atomic("hello world")          // unchanged, correct
```

## References

- Symbol graphs generated via `swift package dump-symbol-graph` from swift-paths, swift-strings, swift-kernel, swift-file-system (2026-03-19)
- Source-level analysis of swift-file-system `Sources/`, swift-kernel `Sources/`, swift-kernel-primitives `Sources/Kernel Glob Primitives/`
- `Kernel.Glob.match` implementations in `swift-posix/Sources/POSIX Kernel/POSIX.Kernel.Glob.Match.swift` and `swift-windows/Sources/Windows Kernel/Windows.Kernel.Glob.Match.swift`
- `Paths.Path` is `Copyable, Sendable, Hashable` — verified at `swift-paths/Sources/Paths/Path.swift:37`
- swift-kernel does NOT depend on swift-paths — layering decision preserved
- [IMPL-INTENT], [IMPL-000], [IMPL-010] from the implementation skill
