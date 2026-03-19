# swift-file-system Deep Audit

**Date**: 2026-03-19
**Package**: swift-file-system (Layer 3 — Foundations)
**Location**: `/Users/coen/Developer/swift-foundations/swift-file-system/`
**Scope**: 59 source files in File System Primitives, 33 in File System, 71 test files
**Dependencies**: swift-kernel, swift-io, swift-environment, swift-paths, swift-strings, swift-ascii, swift-binary-primitives, swift-time-primitives, swift-rfc-4648

---

## Executive Summary

swift-file-system is the oldest package in the ecosystem and predates many conventions. It **works** — the architecture is sound (Primitives provides low-level ops, File System provides ergonomic API), typed throws are used pervasively, and Kernel delegation is clean. However, it has significant compliance gaps:

- **5 CRITICAL findings**: Untyped throws on closure-accepting APIs, fatalError workarounds for typed throws limitations, Result workarounds, File.Handle.write error capture mechanism, and duplicated traversal logic
- **6 HIGH findings**: Redundant single-case error wrappers (remove), duplicated type mappings (unify), glob code duplication (consolidate), 14 hand-rolled accessor structs (unify via Property), missing IO.Closable conformance (one-line fix), fully-qualified module name collision (fix)
- **12 MEDIUM findings**: Naming violations, code-organization violations, raw Int arithmetic, unused utility types, excessive re-exports, etc.
- **7 LOW findings**: Stub implementations, style issues, minor duplication

The package needs a systematic modernization pass. **The governing principle is subtraction**: unify duplicated code, remove redundant wrappers, delete dead code. New dependencies and patterns are deferred until the package is clean. Do not add infrastructure to fix what removal can solve.

---

## Findings by Category

---

### CRITICAL — C-1: Untyped throws on closure-accepting APIs [API-ERR-001]

**Statement**: Five public APIs accept `throws` closures without typed error parameters, erasing error type information at the API boundary.

| File | Line | Signature |
|------|------|-----------|
| `Sources/File System/File.Read.swift` | 78 | `func full<R>(_ body: (Span<UInt8>) throws -> R) throws -> R` |
| `Sources/File System Primitives/File.System.Read.Full.swift` | 233 | `static func read<R>(from:, body: (Span<UInt8>) throws -> R) throws -> R` |
| `Sources/File System Primitives/File.Directory.Walk.swift` | 149 | `func iterate(options:, body: (Entry) throws -> Control) throws` |
| `Sources/File System Primitives/File.Directory.Walk.swift` | 335 | `static func _walkCallbackThrowing(... body: (Entry) throws -> Control) throws` |
| `Sources/File System Primitives/File.Directory.Contents.swift` | 169 | `static func iterate(at:, body: (Entry) throws -> Control) throws` |

**Impact**: Callers cannot use typed error handling. The non-throwing variants on the same types already use typed throws correctly — the throwing variants should too. Known limitation: Swift 6.2 `rethrows` erases typed throws (see [API-ERR-005]), so these may need `<E: Error>` generic parameter on the closure.

**Recommendation**: Convert to `throws(E)` closures where `E` is generic, per [API-ERR-004]. For the walk/iterate APIs where the body error must compose with the walk error, consider a union error type or `throws` with documented limitation.

---

### CRITICAL — C-2: fatalError("unreachable") typed throws workarounds

**Statement**: Six locations use `catch let error as T` + `fatalError("unreachable: typed throws guarantees T")` to work around the compiler's inability to infer exhaustive typed error catching inside closures.

| File | Line |
|------|------|
| `Sources/File System Primitives/File.Handle.swift` | 146 |
| `Sources/File System Primitives/File.System.Write.Append.swift` | 152 |
| `Sources/File System Primitives/File.System.Read.Full.swift` | 207 |
| `Sources/File System Primitives/File.System.Read.Full.swift` | 311 |
| `Sources/File System Primitives/File.System.Move.swift` | 156 |
| `Sources/File System Primitives/File.System.Move.swift` | 201 |

**Pattern**:
```swift
do {
    let written = try Kernel.IO.Write.write(descriptor, from: remaining)
} catch let error as Kernel.IO.Write.Error {
    writeError = error
    return
} catch {
    fatalError("unreachable: typed throws guarantees Kernel.IO.Write.Error")
}
```

**Root cause**: These occur inside closures (`withUnsafeBytes`, `withKernelPath`) that don't propagate typed throws. The compiler requires an exhaustive catch-all even though the callee guarantees a specific error type.

**Recommendation**: Restructure to avoid needing a catch-all. Where possible, use `Result<T, E>` to carry the typed error out of the closure, or restructure the code to avoid the closure boundary entirely (e.g., get the pointer/path first, then call the throwing function outside the closure).

---

### CRITICAL — C-3: Result<T,E> workarounds for typed throws in closures

**Statement**: Eight locations use `Result<T, E>` to escape closure typing constraints, adding mechanism at the expense of readability.

| File | Line | Result Type |
|------|------|-------------|
| `Sources/File System Primitives/File.Directory.Contents.Iterator.swift` | 74 | `Result<(Iterator, IteratorHandle), Error>` |
| `Sources/File System Primitives/File.System.Parent.Check.swift` | 33 | `Result<Kernel.File.Stats, Kernel.File.Stats.Error>` |
| `Sources/File System Primitives/File.System.Write.Append.swift` | 140 | `Result<Int, Kernel.IO.Write.Error>` |
| `Sources/File System Primitives/File.System.Move.swift` | 148 | `Result<Void, Kernel.File.Move.Error>` |
| `Sources/File System Primitives/File.System.Move.swift` | 194 | `Result<Void, Kernel.File.Delete.Error>` |
| `Sources/File System Primitives/File.System.Delete.swift` | 201 | `Result<Kernel.Directory.Entry?, Kernel.Directory.Error>` |
| `Sources/File System Primitives/File.System.Read.Full.swift` | 143 | `Result<Kernel.File.Stats, Kernel.File.Stats.Error>` |

**Impact**: These are [IMPL-INTENT] violations — the Result wrapping is mechanism, not intent. The code should read as "get stats" or "rename file", not "construct a result, switch on it, unwrap success or throw failure."

**Recommendation**: Where the Result exists only to escape a `withKernelPath` closure, restructure so the throwing operation happens outside the closure. If `withKernelPath` must wrap the entire operation, consider adding a typed-throws variant of `withKernelPath` that propagates `throws(E)`.

---

### CRITICAL — C-4: File.Handle.write error capture mechanism [IMPL-INTENT]

**Statement**: `File.Handle.write(_: Span<UInt8>)` (File.Handle.swift:92–143) uses a 50-line imperative pattern: mutable `writeError` capture, `withUnsafeBytes` closure, manual loop, `catch let error as`, fatalError, and post-closure rethrow. This is the densest mechanism-over-intent violation in the package.

**Current** (abridged):
```swift
var writeError: Kernel.IO.Write.Error? = nil
bytes.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
    var totalWritten = 0
    while totalWritten < count {
        let remaining = UnsafeRawBufferPointer(...)
        do {
            let written = try Kernel.IO.Write.write(descriptor, from: remaining)
            totalWritten += written
        } catch let error as Kernel.IO.Write.Error {
            writeError = error
            return
        } catch {
            fatalError("unreachable")
        }
    }
}
if let error = writeError { throw error }
```

**Recommendation**: Extract a `_writeAll(descriptor:, buffer: UnsafeRawBufferPointer)` method that takes the raw buffer directly, avoiding the `withUnsafeBytes` closure boundary and enabling direct typed throws propagation. The `Span` → `UnsafeRawBufferPointer` conversion can happen at the call site.

---

### CRITICAL — C-5: Duplicated traversal logic in Walk [IMPL-033]

**Statement**: `File.Directory.Walk` contains two parallel implementations of the same traversal algorithm:
- `_walk()` (line ~415): Array-collecting variant
- `_walkCallback()` (line ~217): Callback-based variant

Both implement identical depth checking, cycle detection, hidden file filtering, undecodable entry handling, and symlink following. The array variant should delegate to the callback variant.

**Recommendation**: Remove `_walk()` and implement `callAsFunction()` in terms of `_walkCallback()`:
```swift
public func callAsFunction(options: Options) throws(Error) -> [Entry] {
    var entries: [Entry] = []
    try iterate(options: options) { entry in
        entries.append(entry)
        return .continue
    }
    return entries
}
```

---

### HIGH — H-1: File.Descriptor does not conform to IO.Closable

**Statement**: `File.Descriptor` has `consuming func close() throws(Kernel.Close.Error)` which exactly matches `IO.Closable`'s signature, but does not declare conformance. This prevents File.Descriptor from being used with `IO.Lane.open` patterns.

**File**: `Sources/File System Primitives/File.Descriptor.swift`

**Fix**: Add conformance declaration:
```swift
extension File.Descriptor: IO.Closable {
    public typealias CloseError = Kernel.Close.Error
}
```

---

### HIGH — H-2: Redundant type mappings between Kernel and File.System layers

**Statement**: Three separate enum types represent file types with overlapping semantics, requiring two mapping functions:

| Type | Location | Cases |
|------|----------|-------|
| `Kernel.File.Stats.Kind` | swift-kernel | `regular, directory, link(Link), device(Device), fifo, socket, unknown` |
| `File.System.Metadata.Kind` | `File.System.Metadata.Type.swift` | `regular, directory, symbolicLink, blockDevice, characterDevice, fifo, socket` |
| `File.Directory.Entry.Kind` | `File.Directory.Entry.Type.swift` | `file, directory, symbolicLink, other` |

Mapping functions:
- `File.Directory.Contents._mapEntryType()` (Contents.swift:247)
- `File.System.Stat._makeInfo()` (Stat.swift:93)

**Impact**: Every stat/readdir call goes through a mapping layer. The flat enums discard information (device subtypes in Entry.Kind, link subtypes in Metadata.Kind).

**Recommendation**: Consider using `Kernel.File.Stats.Kind` directly in `File.System.Metadata.Info`. Entry.Kind is a valid simplification for directory iteration but should be documented as a deliberate narrowing.

---

### HIGH — H-3: Single-case error wrappers add indirection without value

**Statement**: Several error types wrap a single Kernel error case, adding an indirection layer without semantic benefit:

| Error Type | File | Cases |
|------------|------|-------|
| `File.System.Link.Hard.Error` | `File.System.Link.Hard.swift` | `.link(Kernel.Link.Error)` |
| `File.System.Link.Symbolic.Error` | `File.System.Link.Symbolic.swift` | `.symlink(Kernel.Link.Symbolic.Error)` |
| `File.System.Create.Directory.Error` | `File.System.Create.Directory.swift` | `.mkdir(Kernel.Directory.Create.Error)` |
| `File.Directory.Iterator.Error` | `File.Directory.Iterator.swift` | `.directory(Kernel.Directory.Error)` |

**Impact**: Callers must unwrap through `case .link(let e)` to reach the actual error, then re-check semantic properties. The semantic accessor methods (`.isPermissionDenied`, etc.) on the wrapper type just delegate to the inner error.

**Recommendation**: Use `typealias Error = Kernel.Link.Error` (etc.) with extension-based semantic accessors, or use the Kernel error type directly. Multi-case union types (`File.System.Delete.Error`, `File.System.Move.Error`) are justified — they compose errors from multiple operations.

---

### HIGH — H-4: Hand-rolled accessor structs → migrate to Property<Tag, Base> [INFRA-106]

**Statement**: The File System module defines 14 hand-rolled accessor structs that are structurally identical:

| Type | Accessor | File |
|------|----------|------|
| `File.Copy` | `file.copy` | `File.Copy.swift` |
| `File.Create` | `file.create` | `File.Create.swift` |
| `File.Delete` | `file.delete` | `File.Delete.swift` |
| `File.Move` | `file.move` | `File.Move.swift` |
| `File.Read` | `file.read` | `File.Read.swift` |
| `File.Write` | `file.write` | `File.Write.swift` |
| `File.Stat` | `file.stat` | `File.Stat.swift` |
| `File.Open` | `file.open` | `File.Open.swift` |
| `File.Link` | `file.link` | `File.swift` (nested) |
| `File.Directory.Create` | `dir.create` | `File.Directory.Create.swift` |
| `File.Directory.Delete` | `dir.delete` | `File.Directory.Delete.swift` |
| `File.Directory.Copy` | `dir.copy` | `File.Directory.Copy.swift` |
| `File.Directory.Move` | `dir.move` | `File.Directory.Move.swift` |
| `File.Directory.Stat` | `dir.stat` | `File.Directory.Stat.swift` |

Every one is the same boilerplate:
```swift
public struct Verb: Sendable {
    public let path: File.Path
    internal init(_ path: File.Path) { self.path = path }
    // methods...
}
```

**Recommendation**: Add swift-property-primitives as a dependency and migrate to `Property<Tag, Base>`. This is a **net reduction** — 14 struct declarations, 14 init methods, and 14 accessor properties are replaced by tag enums + `Property<Tag, Self>` accessor properties with extensions. The pattern is already standardized across the ecosystem; using it here is unification, not addition. `File.Link.Target` (nested 2 levels) would need `Property.Typed` or remain as-is.

---

### HIGH — H-5: Glob pattern construction duplicated 6 times

**Statement**: The pattern `for pattern in include { includePatterns.append(try Kernel.Glob.Pattern.init(pattern)) }` appears verbatim 6 times across:
- `File.Directory.Glob+call.swift` (sync + async)
- `File.Directory.Glob+files.swift` (sync + async)
- `File.Directory.Glob+directories.swift` (sync + async)

Each variant also duplicates the match loop logic with only the filter condition differing.

**Recommendation**: Extract a private static method for pattern construction and a shared match method that accepts a filter predicate. All 6 variants should compose from this single implementation.

---

### HIGH — H-6: Fully-qualified module name references

**Statement**: `File.System.Create.swift` uses fully-qualified module names:
```swift
public var permissions: File_System_Primitives.File.System.Metadata.Permissions?
public init(permissions: File_System_Primitives.File.System.Metadata.Permissions? = nil)
```

**File**: `Sources/File System Primitives/File.System.Create.swift:15,17`

**Impact**: This suggests a naming collision (possibly `File.System.Create.File` shadowing `File`). The fix should resolve the collision rather than using fully-qualified names.

---

### MEDIUM — M-1: Compound method/property names [API-NAME-002]

| Identifier | File | Line | Should Be |
|------------|------|------|-----------|
| `iterateFiles(options:body:)` | `File.Directory.Walk.swift` | ~163 | `iterate.files(options:body:)` |
| `iterateDirectories(options:body:)` | `File.Directory.Walk.swift` | ~178 | `iterate.directories(options:body:)` |
| `isFile(at:)` | `File.System.Stat.swift` (FS module) | ~8 | `is.file(at:)` or nested pattern |
| `isDirectory(at:)` | `File.System.Stat.swift` (FS module) | ~15 | `is.directory(at:)` |
| `isSymlink(at:)` | `File.System.Stat.swift` (FS module) | ~22 | `is.symlink(at:)` |
| `lstatInfo(at:)` | `File.System.Stat.swift` (FSP) | ~46 | `lstat.info(at:)` or `info(at:followSymlinks:)` |
| `isHiddenByDotPrefix` | `File.Name.swift` | ~65 | Acceptable — semantic predicate, but `isHidden` would suffice |
| `isDotOrDotDot` | `File.Name.swift` | ~52 | Internal, acceptable |
| `seekToEnd()` | `File.Handle.swift` (FS) | — | `seek.toEnd()` |
| `pathIfValid` | `File.Directory.Entry.swift` | — | `path.ifValid` or keep as computed property |

---

### MEDIUM — M-2: Multiple type declarations per file [API-IMPL-005]

| File | Types Declared | Should Split |
|------|----------------|--------------|
| `File.Name.swift` | `Name`, `RawEncoding` | `File.Name.RawEncoding.swift` |
| `File.Directory.Contents.swift` | `Contents`, `Control` | `File.Directory.Contents.Control.swift` |
| `File.Directory.Contents.Iterator.swift` | `Iterator`, `IteratorHandle` | `File.Directory.Contents.IteratorHandle.swift` |
| `File.Directory.Walk.swift` | `Walk`, `InodeKey` | `File.Directory.Walk.InodeKey.swift` (internal, lower priority) |
| `File.System.Create.swift` | `Create`, `Options` | `File.System.Create.Options.swift` |
| `File.System.Create.Directory.swift` | `Directory`, `Options`, `Error` | Split Options and Error to own files |
| `File.Directory.Glob.Match.swift` | `Match` + Equatable/Hashable extensions | OK (single type) |

---

### MEDIUM — M-3: Raw Int arithmetic where Kernel types exist [IMPL-002]

| File | Line | Expression | Should Be |
|------|------|------------|-----------|
| `File.Handle.swift` | ~103 | `totalWritten += written` | Use typed count |
| `File.Handle.swift` | ~100 | `count - totalWritten` | Use typed subtraction |
| `File.System.Read.Full.swift` | ~176 | `totalRead += bytesRead` | Use typed count |
| `File.System.Read.Full.swift` | ~169 | `fileSize - totalRead` | Use typed subtraction |
| `File.System.Stat.swift` | ~120 | `UInt32(stats.linkCount.rawValue.rawValue)` | rawValue chain — 2 levels |
| `File.System.Stat.swift` | ~104 | `stats.size.rawValue`, `stats.uid.rawValue`, etc. | rawValue extraction for mapping |
| `File.Watcher.Options.swift` | ~14 | `latency: Double` | Should use `Duration` or Kernel.Time |

**Note**: The rawValue chains in `_makeInfo()` are boundary conversions from Kernel types to File.System.Metadata.Info fields. If Info used Kernel types directly (see H-2), these would be unnecessary.

---

### MEDIUM — M-4: File.Unsafe.Sendable appears unused

**File**: `Sources/File System Primitives/File.Unsafe.Sendable.swift`

**Statement**: Defines `File.Unsafe.Sendable<T>: @unchecked Swift.Sendable` but no usage found in source files. This is dead code unless used by consumers.

**Recommendation**: Verify via `find_references`. If unused, remove.

---

### MEDIUM — M-5: Primitives exports.swift re-exports too many dependencies

**File**: `Sources/File System Primitives/exports.swift`

```swift
@_exported public import Binary_Primitives
@_exported public import ASCII
@_exported public import RFC_4648
@_exported public import Paths
@_exported public import Kernel_Primitives
```

**Impact**: Any consumer of File System Primitives transitively imports 5 additional modules. `ASCII` and `RFC_4648` are used only internally (hex encoding in File.Name.debugDescription). They should not be re-exported.

**Recommendation**: Remove `@_exported` from `ASCII` and `RFC_4648`. Keep `Paths` (File.Path is a typealias) and `Kernel_Primitives` (Kernel types appear in public API). Review whether `Binary_Primitives` needs re-export.

---

### MEDIUM — M-6: File.Path.Component byte-level init duplicates validation

**File**: `Sources/File System Primitives/File.Path.Component.swift`

Two nearly identical initializers (`init<Bytes: Sequence>(utf8:)` and `init(utf8: UnsafeBufferPointer<UInt8>)`) duplicate POSIX validation logic (checking for `/` and `NUL`). The UnsafeBufferPointer variant should delegate to the Sequence variant, or both should call a shared validation function.

---

### MEDIUM — M-7: Walk _walkCallbackThrowing duplicates _walkCallback

**File**: `Sources/File System Primitives/File.Directory.Walk.swift`

`_walkCallbackThrowing` (line ~335) is a near-copy of `_walkCallback` (line ~217) with the only difference being `throws` vs `throws(Error)` on the closure parameter. Combined with C-5, there are now **three** copies of the traversal algorithm.

**Recommendation**: Consolidate to one generic implementation per C-1 resolution.

---

### MEDIUM — M-8: File.System.Metadata.Info uses raw types

**File**: `Sources/File System Primitives/File.System.Metadata.Info.swift`

| Property | Current Type | Kernel Type |
|----------|-------------|-------------|
| `size` | `Int64` | `Kernel.File.Stats.Size` |
| `inode` | `UInt64` | `Kernel.File.Stats.Inode` |
| `deviceId` | `UInt64` | `Kernel.File.Stats.Device` |
| `linkCount` | `UInt32` | `Kernel.File.Stats.LinkCount` |

**Impact**: Type information is lost at the mapping boundary. Call sites that need to compare with Kernel values must convert back.

**Recommendation**: Use Kernel types directly, or define File.System.Metadata equivalents with typed wrappers.

---

### MEDIUM — M-9: File.Path._resolvingPOSIX does ad-hoc string manipulation

**File**: `Sources/File System Primitives/File.Path.swift:94–130`

Uses `hasPrefix("~/")`, `hasPrefix("/")`, `hasPrefix("./")`, `lastIndex(of: "/")`, `removeLast()` for path resolution. This duplicates logic that Paths.Path should provide (joining, component manipulation). The `~` expansion via `Environment.read("HOME")` is correct but the rest should use Paths APIs.

---

### MEDIUM — M-10: File.Handle._pwrite/_pwriteAll are package-internal but substantial

**File**: `Sources/File System Primitives/File.Handle.swift:157–210`

These positional write methods (`_pwrite`, `_pwriteAll`) are `package` visibility with substantial implementations including the ESPIPE fallback. They are used by atomic write but not exposed publicly. If atomic write is the only consumer, they could be consolidated into the atomic write implementation.

---

### MEDIUM — M-11: File.Directory.Contents.iterate has duplicated error mapping

**File**: `Sources/File System Primitives/File.Directory.Contents.swift`

Two private `_mapKernelError` methods and the Iterator has `_mapKernelOpenError` / `_mapKernelReadError` — four mapping functions doing essentially the same work.

---

### MEDIUM — M-12: Walk.Options.onUndecodable uses closure instead of enum

**File**: `Sources/File System Primitives/File.Directory.Walk.Options.swift`

```swift
public var onUndecodable: @Sendable (Undecodable.Context) -> Undecodable.Policy
```

A closure for a function that returns one of three enum values is over-engineered. A simple `Undecodable.Policy` property would suffice for 99% of use cases, with the closure reserved for context-dependent decisions (which are rare).

---

### LOW — L-1: Stub implementations (TODO markers)

| File | Type |
|------|------|
| `File.System.Read.Buffered.swift` | `enum Buffered { // TODO }` |
| `File.System.Read.Streaming.swift` | `enum Streaming { // TODO }` |
| `File.System.Create.File.swift` | `enum File { // TODO }` |
| `File.System.Metadata.ACL.swift` | `enum ACL { // TODO }` |
| `File.System.Metadata.Attributes.swift` | `enum Attributes { // TODO }` |
| `File.Watcher.swift` | `enum Watcher { // TODO }` |

These 6 stub types add no functionality. They should either be implemented or removed to reduce noise.

---

### LOW — L-2: File lacks ExpressibleByStringLiteral conformance

**File**: `Sources/File System Primitives/File.swift`

Doc comment mentions `ExpressibleByStringLiteral for ergonomic initialization` and shows `let file: File = "/tmp/data.txt"`, but no `ExpressibleByStringLiteral` conformance is defined. Same for `File.Directory`.

---

### LOW — L-3: File.Handle.Open and File.Descriptor.Open are near-identical

**Files**: `Sources/File System/File.Handle.Open.swift`, `Sources/File System/File.Descriptor.Open.swift`

Both implement the same scoped-open pattern with Error<E>, sync/async variants, and 5 access modes. ~70% of the code is structurally identical. Could share implementation via a generic scoped-open function.

---

### LOW — L-4: FTS walker is Darwin-only

**File**: `Sources/File System Primitives/File.Directory.Walk+FTS.swift`

Conditionally compiled `#if canImport(Darwin)` with no Linux equivalent. The FTS struct is `package` visibility and not used by any public API — it appears to be unused dead code.

---

### LOW — L-5: Binary.Serializable conformances on enum types may be premature

**Files**: `File.Directory.Entry.Type.swift`, `File.Watcher.Event.Kind.swift`, `File.System.Metadata.Type.swift`, `File.System.Metadata.Permissions.swift`, `File.System.Metadata.Ownership.swift`

These types have `Binary.Serializable` conformances but it's unclear if binary serialization of directory entries or file metadata is a real use case. These conformances add code without documented consumers.

---

### LOW — L-6: File.Directory.Walk.Error and File.Directory.Contents.Error overlap

Both define `.pathNotFound`, `.permissionDenied`, `.notADirectory` with identical semantics. Walk.Error could reuse Contents.Error as a case instead of duplicating.

---

### LOW — L-7: File.Path.Property is a novel pattern not used elsewhere

**File**: `Sources/File System/File.Path.Property.swift`

Defines a `Property` struct with `set` and `remove` closures for path modification. This is a unique pattern not seen in other ecosystem packages. Only two built-in properties (`.extension`, `.lastComponent`) are provided. Consider whether Paths.Path should provide this functionality natively.

---

## Per-File Inventory

### File System Primitives Module (59 files)

| File | Types | Issues | Recommendation |
|------|-------|--------|----------------|
| `File.swift` | `File` | — | OK |
| `File.Descriptor.swift` | `File.Descriptor` | H-1 | Add IO.Closable conformance |
| `File.Handle.swift` | `File.Handle` | C-2, C-4, M-3, M-10 | Restructure write(), add typed throws |
| `File.Name.swift` | `File.Name`, `RawEncoding` | M-2, M-1 | Split RawEncoding to own file |
| `File.Name.Decode.swift` | `File.Name.Decode` | — | OK (namespace) |
| `File.Name.Decode.Error.swift` | `File.Name.Decode.Error` | — | OK |
| `File.Path.swift` | (extensions on typealias) | M-9 | Use Paths APIs for resolution |
| `File.Path.Component.swift` | (extensions) | M-6 | Deduplicate validation |
| `File.Unsafe.swift` | `File.Unsafe` | M-4 | Verify usage, possibly remove |
| `File.Unsafe.Sendable.swift` | `File.Unsafe.Sendable` | M-4 | Verify usage, possibly remove |
| `exports.swift` | — | M-5 | Remove ASCII, RFC_4648 re-exports |
| `File.Directory.swift` | `File.Directory` | — | OK |
| `File.Directory.Contents.swift` | `Contents`, `Control` | C-1, C-2, C-3, M-2, M-11 | Split Control; fix typed throws |
| `File.Directory.Contents.Error.swift` | `Contents.Error` | — | OK |
| `File.Directory.Contents.Iterator.swift` | `Iterator`, `IteratorHandle` | C-3, M-2, M-11 | Split IteratorHandle |
| `File.Directory.Entry.swift` | `File.Directory.Entry` | — | OK |
| `File.Directory.Entry.Type.swift` | `Entry.Kind` | H-2, L-5 | Review Binary.Serializable need |
| `File.Directory.Iterator.swift` | `Iterator`, `Error` | H-3 | Simplify Error type |
| `File.Directory.Walk.swift` | `Walk`, `InodeKey` | C-1, C-5, M-1, M-2, M-7 | Major refactor: consolidate traversal |
| `File.Directory.Walk+FTS.swift` | `FTS` | L-4 | Verify usage or remove |
| `File.Directory.Walk.Error.swift` | `Walk.Error` | L-6 | Consider reusing Contents.Error |
| `File.Directory.Walk.Options.swift` | `Walk.Options` | M-12 | Simplify onUndecodable |
| `File.Directory.Walk.Undecodable.swift` | `Undecodable` | — | OK (namespace) |
| `File.Directory.Walk.Undecodable.Context.swift` | `Undecodable.Context` | — | OK |
| `File.Directory.Walk.Undecodable.Policy.swift` | `Undecodable.Policy` | — | OK |
| `File.System.swift` | `File.System`, `Error` | — | OK (namespace) |
| `File.System.Copy.swift` | `Copy`, `Options`, `Error` | — | OK (typealias to Kernel) |
| `File.System.Copy.Recursive.swift` | (extension) | — | OK |
| `File.System.Create.swift` | `Create`, `Options` | H-6, M-2 | Split Options; fix module reference |
| `File.System.Create.Directory.swift` | `Directory`, `Options`, `Error` | H-3, M-2 | Split types; simplify Error |
| `File.System.Create.File.swift` | `File`, `Error` | L-1 | Implement or remove |
| `File.System.Delete.swift` | `Delete`, `Options`, `Error` | C-3 | Fix Result workaround |
| `File.System.Link.swift` | `Link` | — | OK (namespace) |
| `File.System.Link.Hard.swift` | `Hard`, `Error` | H-3 | Simplify Error to typealias |
| `File.System.Link.Read.swift` | `Read` | — | OK (namespace) |
| `File.System.Link.Read.Target.swift` | `Target`, `Error` | — | OK (multi-case error justified) |
| `File.System.Link.Symbolic.swift` | `Symbolic`, `Error` | H-3 | Simplify Error to typealias |
| `File.System.Metadata.swift` | `Metadata` | — | OK (namespace) |
| `File.System.Metadata.ACL.swift` | `ACL` | L-1 | Implement or remove |
| `File.System.Metadata.Attributes.swift` | `Attributes`, `Error` | L-1 | Implement or remove |
| `File.System.Metadata.Info.swift` | `Info` | M-8 | Use Kernel types |
| `File.System.Metadata.Ownership.swift` | `Ownership`, `Error` | — | OK |
| `File.System.Metadata.Permissions.swift` | `Permissions`, `Error` | — | OK |
| `File.System.Metadata.Type.swift` | `Kind` | H-2, L-5 | Consider using Kernel.File.Stats.Kind |
| `File.System.Move.swift` | `Move`, `Options`, `Error` | C-2, C-3 | Fix Result/fatalError workarounds |
| `File.System.Parent.Check.swift` | `Check`, `Operation`, `Error` | C-3 | Fix Result workaround |
| `File.System.Read.swift` | `Read` | — | OK (namespace) |
| `File.System.Read.Buffered.swift` | `Buffered` | L-1 | Implement or remove |
| `File.System.Read.Full.swift` | `Full`, `Error` | C-1, C-2, C-3 | Fix typed throws, Result, fatalError |
| `File.System.Read.Streaming.swift` | `Streaming` | L-1 | Implement or remove |
| `File.System.Stat.swift` | `Stat` | H-2, M-3 | Simplify type mapping |
| `File.System.Write.swift` | `Write` | — | OK (namespace) |
| `File.System.Write.Append.swift` | `Append`, `Error` | C-2, C-3 | Fix fatalError/Result |
| `File.System.Write.Atomic.swift` | `Atomic` + typealiases | — | OK (clean Kernel delegation) |
| `File.System.Write.Streaming.swift` | `Streaming` + typealiases | — | OK (clean Kernel delegation) |
| `File.Watcher.swift` | `Watcher` | L-1 | Implement or remove |
| `File.Watcher.Event.swift` | `Event` | L-5 | Review Binary.Serializable |
| `File.Watcher.Event.Kind.swift` | `Kind` | L-5 | Review Binary.Serializable |
| `File.Watcher.Options.swift` | `Options` | M-3 | Use Duration, not Double |

### File System Module (33 files)

| File | Types | Issues | Recommendation |
|------|-------|--------|----------------|
| `File.swift` | (extensions) | M-1, L-2 | Fix compound names in Link |
| `File.Copy.swift` | `File.Copy` | H-4 | Migrate to Property |
| `File.Create.swift` | `File.Create` | H-4 | Migrate to Property |
| `File.Delete.swift` | `File.Delete` | H-4 | Migrate to Property |
| `File.Move.swift` | `File.Move` | H-4 | Migrate to Property |
| `File.Read.swift` | `File.Read` | C-1, H-4 | Fix untyped throws; migrate to Property |
| `File.Write.swift` | `File.Write` | H-4 | Migrate to Property |
| `File.Stat.swift` | `File.Stat` | H-4 | Migrate to Property |
| `File.Open.swift` | `File.Open` | H-4 | Migrate to Property |
| `File.Handle.swift` | (extensions) | M-1 | Fix seekToEnd compound name |
| `File.Handle.Open.swift` | `File.Handle.Open`, `Error` | L-3 | Consider shared scoped-open |
| `File.Descriptor.Open.swift` | `File.Descriptor.Open`, `Error` | L-3 | Consider shared scoped-open |
| `File.Path.swift` | (empty/compat) | — | Remove if truly empty |
| `File.Path.Property.swift` | `File.Path.Property` | L-7 | Review necessity |
| `File.System.Stat.swift` | (extensions) | M-1 | Fix compound isFile/isDirectory/isSymlink |
| `File.Name+Convenience.swift` | (extensions) | — | OK |
| `File.Directory.swift` | (extensions) | — | OK |
| `File.Directory.Create.swift` | `File.Directory.Create` | H-4 | Migrate to Property |
| `File.Directory.Delete.swift` | `File.Directory.Delete` | H-4 | Migrate to Property |
| `File.Directory.Copy.swift` | `File.Directory.Copy` | H-4 | Migrate to Property |
| `File.Directory.Move.swift` | `File.Directory.Move` | H-4 | Migrate to Property |
| `File.Directory.Stat.swift` | `File.Directory.Stat` | H-4 | Migrate to Property |
| `File.Directory.Entries.swift` | `File.Directory.Entries` | — | OK (callable namespace) |
| `File.Directory.Files.swift` | `File.Directory.Files` | — | OK |
| `File.Directory.Directories.swift` | `File.Directory.Directories` | — | OK |
| `File.Directory.Contents+Convenience.swift` | (extensions) | — | OK |
| `File.Directory.Glob.swift` | `File.Directory.Glob` | — | OK |
| `File.Directory.Glob+call.swift` | (extensions) | H-5 | Deduplicate |
| `File.Directory.Glob+files.swift` | (extensions) | H-5 | Deduplicate |
| `File.Directory.Glob+directories.swift` | (extensions) | H-5 | Deduplicate |
| `File.Directory.Glob.Match.swift` | `Match` | — | OK |
| `Binary.Serializable.swift` | (extensions) | — | OK |
| `exports.swift` | — | — | OK (`@_exported File_System_Primitives`) |

---

## Dependency Utilization Matrix

| Dependency | Module Used | Utilization | Assessment |
|------------|-------------|-------------|------------|
| **swift-kernel** | `Kernel` | **Heavy** | Core dependency. File.Descriptor, File.Handle, all System ops delegate to Kernel. Fully justified. |
| **swift-io** | `IO`, `IO Primitives` | **Moderate** | Used in File System module for `IO.run` async wrappers and `IO.Failure.Work` error types. `IO.Closable` NOT used (gap — H-1). `IO Primitives` imported by File.Descriptor but conformance missing. |
| **swift-paths** | `Paths` | **Heavy** | `File.Path` is `typealias Paths.Path`. Core dependency. |
| **swift-strings** | `Strings` | **Light** | Used for `String.strictUTF8()` in File.Name. Justified but light. |
| **swift-environment** | `Environment` | **Very light** | Used only in `File.Path._resolvingPOSIX` for `Environment.read("HOME")`. Single call site. |
| **swift-ascii** | `ASCII` | **Marginal** | Imported and re-exported but no direct usage found in source files. May be needed transitively by File.Path.Component validation. |
| **swift-binary-primitives** | `Binary Primitives` | **Moderate** | Used for `Binary.Serializable` conformances on 6 types. Also re-exported. |
| **swift-time-primitives** | `Time Primitives` | **Unused** | Listed in Package.swift dependencies but `Kernel.Time` comes through `Kernel`, not through direct import. **Candidate for removal.** |
| **swift-rfc-4648** | `RFC 4648` | **Very light** | Used only for hex encoding in `File.Name.debugDescription` and `File.Name.Decode.Error.debugRawBytes`. Re-exported despite internal-only usage. |

**Recommendations** (subtract first):
1. **Remove** swift-time-primitives dependency (unused — zero imports in source)
2. **Stop re-exporting** ASCII and RFC_4648 (internal-only usage, leaks to consumers)
3. **Verify** swift-ascii necessity — if only needed transitively, remove from direct dependencies
4. **Add** swift-property-primitives (net reduction: replaces 14 hand-rolled accessor structs with shared ecosystem pattern)

---

## Recommended Migration Order

**Governing principle**: Subtract before adding. Unify before extending. Remove before replacing.

### Phase 1: Remove Dead Code and Unused Dependencies

**Priority**: Highest — pure subtraction, zero risk, immediate cleanup.

1. **Remove** swift-time-primitives from Package.swift (zero source imports)
2. **Remove** `@_exported` from ASCII and RFC_4648 in exports.swift (M-5)
3. **Delete** 6 stub types that contain only `// TODO` (L-1): `File.System.Read.Buffered`, `File.System.Read.Streaming`, `File.System.Create.File`, `File.System.Metadata.ACL`, `File.System.Metadata.Attributes`, `File.Watcher`
4. **Delete** `File.Unsafe.swift` and `File.Unsafe.Sendable.swift` if unused (M-4 — verify first)
5. **Delete** `File.Directory.Walk+FTS.swift` if unused by public API (L-4 — verify first)
6. **Delete** `File.Path.swift` in File System module if truly empty (backwards compat stub)
7. **Verify** swift-ascii necessity; remove from direct dependencies if transitive-only

### Phase 2: Consolidate Duplicated Code (C-5, H-3, H-4, H-5, M-7, M-11, M-6)

**Priority**: High — reduces code volume without changing behavior.

1. **Walk**: Delete `_walk()` (array-collecting) and `_walkCallbackThrowing()`. Implement `callAsFunction()` via `iterate()`. Three implementations → one. (C-5, M-7)
2. **Glob**: Extract shared pattern-construction + match method. Six copy-pasted implementations → one shared core + three thin filters. (H-5)
3. **Accessor structs**: Add swift-property-primitives dependency. Replace 14 hand-rolled accessor structs with `Property<Tag, Base>` + tag enums + extensions. Net line reduction. (H-4)
4. **Error wrappers**: Replace single-case error types with typealiases to Kernel errors (H-3):
   - `File.System.Link.Hard.Error` → `typealias Error = Kernel.Link.Error`
   - `File.System.Link.Symbolic.Error` → `typealias Error = Kernel.Link.Symbolic.Error`
   - `File.System.Create.Directory.Error` → `typealias Error = Kernel.Directory.Create.Error`
   - `File.Directory.Iterator.Error` → `typealias Error = Kernel.Directory.Error`
   - Move semantic accessors to extensions on the Kernel types
5. **Error mapping**: Consolidate 4 Kernel→File error mapping functions into 1 shared mapper (M-11)
6. **Path.Component validation**: Deduplicate the two init methods (M-6)
7. **Walk.Error / Contents.Error**: Unify overlapping cases (L-6)
8. **Handle.Open / Descriptor.Open**: Extract shared scoped-open pattern (L-3)

### Phase 3: Typed Throws Cleanup (C-1, C-2, C-3, C-4)

**Priority**: High — fundamental convention compliance.

1. Check whether `Paths.Path.withKernelPath` already has a typed-throws variant. If not, add `throws(E)` overload in swift-paths (one change, unblocks ~15 call sites)
2. Restructure `File.Handle.write` to avoid `withUnsafeBytes` closure boundary — extract `_writeAll(descriptor:buffer:)` that takes raw pointer directly (C-4)
3. Remove all `fatalError("unreachable")` catch blocks by restructuring to avoid closure boundaries (C-2)
4. Remove all `Result<T,E>` workarounds by restructuring operations outside `withKernelPath` closures (C-3)
5. Convert closure-accepting APIs to `throws(E)` where feasible (C-1) — this may be blocked by stdlib `rethrows` limitations; document any that must remain untyped

### Phase 4: Unify Type Mappings (H-2, M-8, H-6)

**Priority**: Medium — reduces indirection layers.

1. **File.System.Metadata.Kind**: Evaluate replacing with `Kernel.File.Stats.Kind` directly, or making it a typealias. The flat enum loses device/link subtypes — document whether that loss is acceptable.
2. **File.System.Metadata.Info**: Replace raw types (`Int64`, `UInt64`, `UInt32`) with Kernel types (`Kernel.File.Stats.Size`, etc.) to eliminate rawValue chains in `_makeInfo()` (M-8)
3. **Fully-qualified module names**: Resolve the `File_System_Primitives.File.System.Metadata.Permissions` collision in `File.System.Create.swift` — likely caused by `File.System.Create.File` shadowing `File` (H-6)

### Phase 5: Code Organization (M-2)

**Priority**: Medium — file splitting per [API-IMPL-005].

1. Split `File.Name.RawEncoding` to own file
2. Split `File.Directory.Contents.Control` to own file
3. Split `File.Directory.Contents.IteratorHandle` to own file
4. Split nested Options/Error types in Create files to own files
5. Split `File.Directory.Walk.InodeKey` if public (skip if internal-only)

### Phase 6: Naming Compliance (M-1)

**Priority**: Lower — breaking API changes, coordinate with consumers.

1. `iterateFiles` → `iterate.files`, `iterateDirectories` → `iterate.directories`
2. `lstatInfo` → parameter-based: `info(at:followSymlinks:)` or nested `lstat.info`
3. `seekToEnd` → `seek.toEnd`
4. `isFile`/`isDirectory`/`isSymlink` — evaluate whether compound predicates are acceptable at this layer (they read naturally as boolean properties)

### Phase 7: Ecosystem Conformances (H-1)

**Priority**: Lowest — adding, not subtracting. Only if IO.Lane integration is needed.

1. Add `IO.Closable` conformance to `File.Descriptor` (one declaration, zero new code)
