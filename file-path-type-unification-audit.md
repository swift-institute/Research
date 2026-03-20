# File/Path Type Unification Audit

- **Date**: 2026-03-19
- **Status**: Complete
- **Packages**: swift-paths (L3), swift-file-system (L3)
- **Trigger**: Tension between `ExpressibleByStringLiteral` on `Path` and throwing init on `File.Directory`

---

## 1. Type Surface Inventory

### swift-paths (`Sources/Paths/`)

#### `Path`

**File**: `Path.swift`

```swift
public struct Path: Copyable, Sendable, Hashable {
    public init(_ string: Swift.String) throws(Error)
    public init(copying bytes: Span<Char>) throws(Error)
    internal init(storage: Storage)
}
```

**Conformances**: `Copyable`, `Sendable`, `Hashable`, `CustomStringConvertible`, `CustomDebugStringConvertible`, `ExpressibleByStringLiteral`, `ExpressibleByStringInterpolation`, `Binary.Serializable`

**Properties** (in `Path.Introspection.swift`):
- `string: String` — decode to String
- `isAbsolute: Bool` / `isRelative: Bool`
- `isEmpty: Bool`
- `extension: Component.Extension?` (get/set)
- `stem: Component.Stem?`
- `count: Int`
- `endsWithSeparator: Bool`
- `isRoot: Bool`

**Navigation** (in `Path.Navigation.swift`):
- `components: [Component]`
- `lastComponent: Component?`
- `parent: Path?`
- `appending(_ component: Component) -> Path`
- `appending(_ string: String) throws(Component.Error) -> Path`
- `appending(_ other: Path) -> Path`
- `hasPrefix(_ other: Path) -> Bool`
- `relative(to base: Path) -> Path?`

**Operators** (in `Path.Operators.swift`):
- `/ (lhs: Path, rhs: Component) -> Path`
- `/ (lhs: Path, rhs: Path) -> Path` (`@_disfavoredOverload`)

**Other**:
- `kernelPath: Kernel.Path.View` — zero-copy bridge
- `bytes: Span<Char>` — span access
- `withCString(_:)` — C interop
- `view: Path.View` — non-escapable view (`~Copyable`, `~Escapable`)

**Literal conformance** (`Path.Operators.swift:60`):
```swift
public init(stringLiteral value: Swift.String) {
    do {
        try self.init(value)
    } catch {
        fatalError("Invalid path literal: \(value) (\(error))")
    }
}
```

#### `Path.Component`

**File**: `Path.Component.swift`

```swift
public struct Component: Copyable, Sendable, Hashable {
    public init(_ string: Swift.String) throws(Error)
    internal init(storage: Path.Storage)
}
```

**Conformances**: `Copyable`, `Sendable`, `Hashable`, `CustomStringConvertible`, `CustomDebugStringConvertible`, `ExpressibleByStringLiteral`, `ExpressibleByStringInterpolation`, `Binary.Serializable`

**Properties**: `string`, `extension: Extension?`, `stem: Stem`

**Literal conformance** (`Path.Operators.swift:95`): same pattern as Path — `fatalError` on invalid.

#### `Path.Component.Extension`

**File**: `Path.Component.Extension.swift`

```swift
public struct Extension: Copyable, Sendable, Hashable {
    public init(_ string: Swift.String) throws(Error)
    internal init(unchecked value: Swift.String)
}
```

**Conformances**: same set + `ExpressibleByStringLiteral` (fatalError on invalid)

#### `Path.Component.Stem`

**File**: `Path.Component.Stem.swift`

```swift
public struct Stem: Copyable, Sendable, Hashable {
    public init(_ string: Swift.String) throws(Error)
    internal init(unchecked value: Swift.String)
}
```

**Conformances**: same set + `ExpressibleByStringLiteral` (fatalError on invalid)

#### `Path.View`

**File**: `Path.View.swift`

```swift
public struct View: ~Copyable, ~Escapable {
    public let pointer: UnsafePointer<Path.Char>
}
```

Non-owning borrowed view. Not relevant to the unification question.

---

### swift-file-system

#### File System Primitives (`Sources/File System Primitives/`)

##### `File`

**File**: `File.swift`

```swift
public struct File: Hashable, Sendable {
    public let path: File.Path
    public init(_ path: File.Path)
}
```

**Conformances**: `Hashable`, `Sendable`

**NO** `ExpressibleByStringLiteral`. **NO** throwing init from String.

Single init: takes a `File.Path` (which is `Paths.Path`).

##### `File.Directory`

**File**: `File.Directory.swift`

```swift
public struct Directory: Hashable, Sendable {
    public let path: File.Path
    public init(_ path: File.Path)
    public init(_ string: Swift.String) throws(Paths.Path.Error)
}
```

**Conformances**: `Hashable`, `Sendable`

**NO** `ExpressibleByStringLiteral`. **Has** throwing init from String.

Two inits: one from `File.Path`, one from `String` that delegates to `try File.Path(string)`.

**Key asymmetry**: `File` has NO string init. `File.Directory` has a throwing string init. Neither has `ExpressibleByStringLiteral`.

##### `File.Path`

**File**: `File.Path.swift`

```swift
public typealias Path = Paths.Path
```

Extensions add:
- `init(__unchecked:_:)` — package-internal non-throwing init
- `init(_resolving string:)` — resolves `~`, relative paths
- `init(cString:)` — from C string pointer
- `parentOrSelf` — internal helper

##### `File.Path.Component`

**File**: `File.Path.Component.swift`

```swift
public typealias Component = Paths.Path.Component
```

Extension adds byte-level init: `init(utf8:)` for POSIX.

##### Other types

| Type | Location | Relationship to Path |
|------|----------|---------------------|
| `File.Handle` | Primitives | `~Copyable`, stores `File.Descriptor` + `File.Path` |
| `File.Descriptor` | Primitives | `~Copyable`, owns `Kernel.Descriptor` |
| `File.Name` | Primitives | Raw filesystem encoding (separate from Path) |
| `File.Directory.Entry` | Primitives | Stores `File.Name` + parent `File.Path` |
| `File.System` | Primitives | Static namespace for operations |

#### File System (`Sources/File System/`)

##### `File` extensions

Adds rich API surface via namespace types:
- `file.read` — `File.Read` (span-based full read)
- `file.write` — `File.Write` (atomic, append, streaming)
- `file.open` — `File.Open` (scoped handle with auto-close)
- `file.stat` — `File.Stat` (exists, isFile, size, permissions)
- `file.copy` — `File.Copy`
- `file.move` — `File.Move`
- `file.delete` — `File.Delete`
- `file.create` — `File.Create`
- `file.link` — `File.Link`

Plus: `parent`, `name`, `extension`, `stem`, `/` operator, `appending(_:)`.

##### `File.Directory` extensions

Adds: subscripts (`dir[file:]`, `dir[directory:]`), `subdirectory(_:)`, `parent`, `name`, `/` operator, `appending(_:)`, plus `create`, `copy`, `move`, `delete`, `stat`, `glob`, `entries`, `files`, `directories`, `walk`.

##### `File.Path.Property<Value>`

**File**: `File.Path.Property.swift`

Generic property modification:
```swift
public struct Property<Value: Sendable>: Sendable {
    public let set: @Sendable (File.Path, Value) -> File.Path
    public let remove: @Sendable (File.Path) -> File.Path
}
```

Two built-in properties: `.extension`, `.lastComponent`.

API: `path.with(.extension, "txt")`, `path.removing(.extension)`.

---

## 2. Initialization Paths

### Creating a `File`

| Call site | Chain | Validation |
|-----------|-------|------------|
| `File(path)` | Stores `path` directly | None — Path already validated |
| `File("/tmp/x")` | String literal → `Path.init(stringLiteral:)` → `try Path.init(_:)` → fatalError if invalid | Path validates, crashes on failure |
| `File(try Path(str))` | Caller validates, File stores | Path validates, throws on failure |

**No** `File.init(_ string:) throws` exists. Users must create a `Path` first if they want safe construction from runtime strings.

### Creating a `File.Directory`

| Call site | Chain | Validation |
|-----------|-------|------------|
| `File.Directory(path)` | Stores `path` directly | None — Path already validated |
| `File.Directory("/tmp/x")` | String literal → `Path.init(stringLiteral:)` → passed to `File.Directory.init(_: File.Path)` | Path validates, crashes on failure |
| `try File.Directory(str)` | `File.Directory.init(_ string:) throws(Path.Error)` → `try File.Path(str)` → stores result | Path validates, throws on failure |

### Creating a `Path`

| Call site | Chain | Validation |
|-----------|-------|------------|
| `try Path(string)` | Validates: non-empty, no control chars, no interior NUL | Throws `Path.Error` |
| `Path("/tmp/x")` | `ExpressibleByStringLiteral` → `try Path(string)`, fatalError on failure | Crashes on invalid |
| `Path("\(name)")` | `ExpressibleByStringInterpolation` → same as literal | Crashes on invalid |

### The asymmetry

`File.Directory` has `init(_ string:) throws` but `File` does not. This means:
- `try File.Directory("/tmp/x")` — works, validates
- `try File("/tmp/x")` — does NOT compile (no throwing String init)
- `File("/tmp/x")` — works as a literal (Path's `ExpressibleByStringLiteral` kicks in, crashes on invalid)

When `ExpressibleByStringLiteral` is added to `File.Directory`, the call `File.Directory("/tmp/x")` becomes ambiguous: should it use the literal conformance (which crashes on invalid) or the throwing init (which surfaces errors)? In practice, Swift selects the literal conformance for string literals, silently overriding the throwing init at those call sites.

---

## 3. Analysis of `name` / `extension` / `stem`

### `File` (in `File.swift`, File System layer)

```swift
public var name: File.Path.Component {
    path.lastComponent ?? "."
}

public var `extension`: File.Path.Component.Extension? {
    path.extension
}

public var stem: File.Path.Component.Stem? {
    path.stem
}
```

### `File.Directory` (in `File.Directory.swift`, File System layer)

```swift
public var name: File.Path.Component {
    path.lastComponent ?? "."
}
```

No `extension` or `stem` properties (sensible — directories don't typically have extensions).

### Assessment

Every property is a **direct forward** to `Path`:
- `name` → `path.lastComponent ?? "."`
- `extension` → `path.extension`
- `stem` → `path.stem`

The wrappers add **zero** novel behavior for these properties. The only difference is the fallback to `"."` for `name` when `lastComponent` is nil (root paths). `Path.lastComponent` already returns `Component?` — the wrapper merely provides a non-optional default.

**Consumer impact of the previous String → Component migration**: These properties already return typed values (`Component`, `Extension?`, `Stem?`) inherited from Path. No workspace consumers depend on String return types — the migration happened at the Path layer.

---

## 4. The `/` Operator

### Path layer

```swift
// Path.Operators.swift
public static func / (lhs: Path, rhs: Component) -> Path { lhs.appending(rhs) }
public static func / (lhs: Path, rhs: Path) -> Path { lhs.appending(rhs) }  // @_disfavoredOverload
```

### File layer

```swift
// File.swift (File System)
public static func / (lhs: File, rhs: File.Path.Component) -> File {
    lhs.appending(rhs)
}

public func appending(_ component: File.Path.Component) -> File {
    File(path / component)
}
```

### File.Directory layer

```swift
// File.Directory.swift (File System)
public static func / (lhs: File.Directory, rhs: File.Path.Component) -> File.Directory {
    lhs.appending(rhs)
}

public func appending(_ component: File.Path.Component) -> File.Directory {
    File.Directory(path / component)
}
```

### Assessment

Both wrapper operators are exactly `WrapperType(path / component)`. They exist solely to preserve the wrapper type in expressions like `dir / "subdir" / "file.txt"`.

**Value of the wrapper operator**: Without it, `dir.path / "subdir"` returns `Path`, losing the `File.Directory` type. If the user wants to chain directory operations (`dir / "sub" |> .create()`), they need the typed operator. This is the **primary value** of the wrapper types.

---

## 5. File.Path.Property

### What it provides

```swift
path.with(.extension, "txt")      // → Path with new extension
path.removing(.extension)          // → Path without extension
path.with(.lastComponent, "new")   // → Path with replaced last component
```

### Does Path have similar mutation APIs?

`Path.extension` has a setter:
```swift
public var `extension`: Component.Extension? {
    get { lastComponent?.extension }
    set { /* rebuilds path with new extension */ }
}
```

So `var p = path; p.extension = ext` works. The Property pattern adds a **functional** (non-mutating) API: `path.with(.extension, "txt")` returns a new path without mutating.

### Is it used outside the two built-in properties?

No. Only `.extension` and `.lastComponent` are defined. No external consumers add new `Property<Value>` instances.

### Should it live in swift-paths?

It depends on Paths' stance on functional API. `Property<Value>` is generic, uses closures, and is higher-level than Path's current imperative API. It could live in either package. Currently it has no cross-package consumers, so the location in swift-file-system is fine. If more properties were added, moving it to swift-paths would be warranted.

---

## 6. Unification Options

### Consumer inventory

Consumers of `File(` across the workspace (excluding internal swift-file-system):

| Package | Usage pattern | Count |
|---------|--------------|-------|
| swift-tests | `File(path)`, `File(File.Path(stringLiteral: ...))` | ~12 |
| swift-pdf | `File("/tmp/...")` (literal via Path coercion) | 3 |

Consumers of `File.Directory(` outside swift-file-system:

| Package | Usage pattern | Count |
|---------|--------------|-------|
| swift-tests | `File.Directory(path)` | ~5 |

All consumers use either `File(path)` (with a pre-constructed Path) or `File("literal")` (relying on Path's `ExpressibleByStringLiteral`).

### Option A: Status Quo

**Keep File/Directory as thin wrappers. No ExpressibleByStringLiteral.**

- **Breaking changes**: None.
- **Pros**: No ambiguity. Throwing init on File.Directory works as expected for runtime strings.
- **Cons**: Doc comments show `let file: File = "/tmp/data.txt"` but this doesn't compile. The asymmetry between File (no string init) and File.Directory (has string init) is confusing.
- **Alignment**: The doc comments are aspirational lies.

### Option B: Remove throwing init from File.Directory

**Remove `File.Directory.init(_ string:) throws`. Users must construct a Path first.**

- **Breaking changes**: `try File.Directory(string)` no longer compiles. Must change to `File.Directory(try File.Path(string))`.
- **Impact**: 2 test call sites (`try File.Directory("/tmp/mydir")` and `try File.Directory("")`), plus 1 internal call site. Low impact.
- **Pros**: File and File.Directory become symmetric. Both only accept `File.Path`.
- **Cons**: Loses the convenience of `try File.Directory(string)`.

### Option C: Remove File/Directory wrappers entirely

**Users work with `Path` directly. Discard File, File.Directory as types.**

- **Breaking changes**: Massive. Every `File(path)`, `file.read`, `file.write`, `dir.create`, `dir[file:]`, `dir.walk` etc. breaks. All namespace types (File.Read, File.Write, File.Open, File.Stat, File.Copy, File.Move, File.Delete, File.Create, File.Directory.Create, etc.) need re-homing.
- **Impact**: ~100+ call sites across the workspace. All of swift-tests, swift-pdf consumers break.
- **Pros**: Eliminates all wrapper overhead and type duplication.
- **Cons**: Catastrophic API churn. Loses the typed `/` operator semantics. Loses the `File` vs `File.Directory` type distinction that enables targeted API (files have `read`/`write`, directories have `walk`/`glob`/`entries`). This distinction is genuinely valuable.
- **Assessment**: **Not recommended.** The wrappers carry real semantic value as API organization namespaces.

### Option D: Strengthen the wrappers

**Make File/Directory enforce invariants (e.g., File can only point to files, Directory to directories).**

- **Breaking changes**: Would require runtime validation on construction, changing all `File.init(_ path:)` to throw or be failable.
- **Impact**: Every `File(path)` becomes `try File(path)` or `File?(path)`.
- **Pros**: The types carry runtime meaning, not just API organization.
- **Cons**: Massive API churn. The types are used for intent, not verification — `File(path)` expresses "I intend to treat this as a file" which is valuable even if the file doesn't exist yet. Making it verify existence defeats patterns like `File(path).create.touch()`.
- **Assessment**: **Not recommended.** Intent-based wrappers are the right design for builder-style APIs.

### Option E: Hybrid — Add ExpressibleByStringLiteral, rename throwing init

**Add `ExpressibleByStringLiteral` to `File` and `File.Directory`. Rename `File.Directory.init(_ string:) throws` to `File.Directory.init(validating:) throws`.**

- **Breaking changes**: `try File.Directory(string)` must become `try File.Directory(validating: string)`. 2 test call sites + 1 internal.
- **Impact**: Low breakage. All existing `File(path)` and `File.Directory(path)` continue to work. `File("/tmp/x")` already works via Path coercion; literal conformance makes it explicit and documented.
- **Pros**:
  - Doc comments (`let file: File = "/tmp/data.txt"`) finally work.
  - Symmetric: both File and File.Directory support literals.
  - Runtime validation has explicit API: `try File.Directory(validating: string)`.
  - No ambiguity: `File.Directory("literal")` uses the literal conformance. `try File.Directory(validating: runtimeString)` throws.
  - Also add `File.init(validating:) throws` for symmetry.
- **Cons**: Adding fatalError paths to more types.
- **Alignment**: Matches the existing pattern in `Path`, `Path.Component`, `Path.Component.Extension`, `Path.Component.Stem` — all of which have both `ExpressibleByStringLiteral` (fatalError) and `init(_:) throws`.

### Option F: Wrapper as protocol

Not evaluated — would require existential types or generics, adding complexity without clear benefit.

---

## 7. Ecosystem Precedent

### Types with both `ExpressibleByStringLiteral` and throwing `init(_: String)`

| Type | Package | Literal | Throwing init | Pattern |
|------|---------|---------|--------------|---------|
| `Path` | swift-paths | `fatalError` on invalid | `throws(Path.Error)` | Same-name overload |
| `Path.Component` | swift-paths | `fatalError` on invalid | `throws(Component.Error)` | Same-name overload |
| `Path.Component.Extension` | swift-paths | `fatalError` on invalid | `throws(Extension.Error)` | Same-name overload |
| `Path.Component.Stem` | swift-paths | `fatalError` on invalid | `throws(Stem.Error)` | Same-name overload |
| `Locale` | swift-locale-standard | `try!` (force-try) | `init(BCP47.LanguageTag)` throws | Different parameter type |
| `Email.Body` | swift-email-standard | literal | N/A | No throwing init |
| `RSS.Category` | swift-rss-standard | literal | N/A | No throwing init |

The Path family uses the **exact same pattern**: `init(stringLiteral:)` calls `try self.init(value)` and wraps failure in `fatalError`. The throwing `init(_: String)` coexists because Swift distinguishes the two overloads:

- **Literal context**: `let p: Path = "/tmp"` — compiler selects `init(stringLiteral:)`
- **Variable context**: `let p = try Path(someString)` — compiler selects `init(_:) throws`
- **Ambiguous context**: `Path("/tmp")` — compiler selects the throwing init (more specific), but the literal can satisfy it

The tension the user encountered is specific to `File.Directory` because:
1. `File.Directory.init(_ string:) throws` is a **convenience init** (delegates to Path).
2. Adding `ExpressibleByStringLiteral` introduces `init(stringLiteral:)` which also accepts String.
3. When the user writes `File.Directory("/tmp")`, Swift may select the literal init instead of the throwing init, silently changing behavior.

**This is identical to what Path already does.** `Path("/tmp")` selects the literal init, not the throwing one, when used in a non-`try` context. The ecosystem has accepted this pattern.

### Does `Path.Component` have the same issue?

Yes. `Path.Component("readme.txt")` calls the literal init (which fatalErrors on failure), not the throwing init. This is the established pattern in the Path hierarchy.

---

## Recommendation

**Option E (Hybrid)** is the recommended approach.

### Actions

1. **Add `ExpressibleByStringLiteral` to `File`**:

```swift
extension File: ExpressibleByStringLiteral {
    public init(stringLiteral value: Swift.String) {
        self.init(File.Path(stringLiteral: value))
    }
}
```

2. **Add `ExpressibleByStringLiteral` to `File.Directory`**:

```swift
extension File.Directory: ExpressibleByStringLiteral {
    public init(stringLiteral value: Swift.String) {
        self.init(File.Path(stringLiteral: value))
    }
}
```

3. **Rename `File.Directory.init(_ string:) throws` to `init(validating:) throws`**:

```swift
// Before:
public init(_ string: Swift.String) throws(Paths.Path.Error)

// After:
public init(validating string: Swift.String) throws(Paths.Path.Error) {
    self.path = try File.Path(string)
}
```

4. **Add `File.init(validating:) throws` for symmetry**:

```swift
extension File {
    public init(validating string: Swift.String) throws(Paths.Path.Error) {
        self.path = try File.Path(string)
    }
}
```

5. **Update 2 test call sites** in `File.Directory Tests.swift`:

```swift
// Before:
let dir = try File.Directory("/tmp/mydir")
_ = try File.Directory("")

// After:
let dir = try File.Directory(validating: "/tmp/mydir")
_ = try File.Directory(validating: "")
```

### Rationale

- Follows the established pattern across `Path`, `Path.Component`, `Extension`, `Stem`.
- Makes doc comments truthful (`let file: File = "/tmp/data.txt"` compiles).
- The `validating:` label clearly communicates "this can fail" vs unlabeled literal "this crashes".
- Low breaking change surface (2 test sites + 1 internal).
- Preserves the wrapper types' value as API organization namespaces.

### Deferred

- `File.Path.Property` could move to swift-paths if functional Path APIs become a pattern. No urgency.
- Consider adding `ExpressibleByStringInterpolation` to `File` and `File.Directory` as well, matching Path's conformance. This enables `let file: File = "/tmp/\(name).txt"`.
