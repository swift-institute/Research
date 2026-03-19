# swift-file-system Deep Audit

**Date**: 2026-03-19 (updated after upstream refactor)
**Package**: swift-file-system (Layer 3 — Foundations)
**Location**: `/Users/coen/Developer/swift-foundations/swift-file-system/`
**Scope**: 59 source files in File System Primitives, 33 in File System, 71 test files
**Dependencies**: swift-kernel, swift-io, swift-environment, swift-paths, swift-strings, swift-ascii, swift-binary-primitives, swift-time-primitives, swift-rfc-4648

---

## Executive Summary

swift-file-system is the oldest package in the ecosystem. It **works** — the architecture is sound, typed throws are used pervasively, and Kernel delegation is clean.

**Recent upstream changes** (2026-03-19): swift-paths replaced `withKernelPath` closures with direct `path.kernelPath` property access. All 45 call sites in swift-file-system were migrated, eliminating the primary root cause of several typed-throws workarounds. This was a **net 87-line reduction**.

**Remaining issues after upstream migration**:

- **5 CRITICAL findings**: Untyped throws on closure APIs (7 sites), fatalError workarounds (6 sites — 2 now trivially fixable), Result workarounds (8 sites — 4 now trivially fixable), Handle.write mechanism, duplicated Walk traversal (3 copies)
- **6 HIGH findings**: Single-case error wrappers (remove 4), 14 hand-rolled accessor structs (unify via Property), duplicated type mappings (unify), glob duplication (6→1), IO.Closable gap, fully-qualified module name collision
- **12 MEDIUM findings**: Naming violations, code-organization violations, raw Int arithmetic, 6 remaining `Kernel.Path.scope` closures, unused types, excessive re-exports
- **7 LOW findings**: 6 stub TODO types, style issues, minor duplication

**The governing principle is subtraction**: unify duplicated code, remove redundant wrappers, delete dead code. New dependencies only when they produce net line reduction (Property adoption).

---

## Findings by Category

---

### CRITICAL — C-1: Untyped throws on closure-accepting APIs [API-ERR-001]

**Statement**: Seven public/internal APIs accept `throws` closures without typed error parameters.

| File | Line | Signature |
|------|------|-----------|
| `Sources/File System/File.Read.swift` | 78 | `func full<R>(_ body: (Span<UInt8>) throws -> R) throws -> R` |
| `Sources/File System Primitives/File.System.Read.Full.swift` | 231–232 | `static func read<R>(from:, body: (Span<UInt8>) throws -> R) throws -> R` |
| `Sources/File System Primitives/File.Directory.Walk.swift` | 149 | `func iterate(options:, body: (Entry) throws -> Control) throws` |
| `Sources/File System Primitives/File.Directory.Walk.swift` | 335 | `static func _walkCallbackThrowing(... body: (Entry) throws -> Control) throws` |
| `Sources/File System Primitives/File.Directory.Contents.swift` | 169 | `static func iterate(at:, body: (Entry) throws -> Control) throws` |
| `Sources/File System Primitives/File.System.Write.Streaming.swift` | 194 | `fill: (inout [UInt8]) throws -> Int` |

**Recommendation**: Convert to `throws(E)` closures where `E` is generic, per [API-ERR-004]. Known limitation: Swift 6.2 `rethrows` erases typed throws, so these need explicit `<E: Error>` generic parameter.

---

### CRITICAL — C-2: fatalError("unreachable") typed throws workarounds

**Statement**: Six locations use `catch let error as T` + `fatalError("unreachable")`. Post-migration status:

| File | Line | Root Cause | Fix Difficulty |
|------|------|------------|----------------|
| `File.System.Move.swift` | 153 | **Top-level do/catch** — no closure boundary | **Trivial**: use `do throws(Kernel.File.Move.Error)` |
| `File.System.Move.swift` | 196 | **Top-level do/catch** — no closure boundary | **Trivial**: use `do throws(Kernel.File.Delete.Error)` |
| `File.Handle.swift` | 146 | Inside `Span.withUnsafeBytes` closure | Needs restructure: extract `_writeAll(descriptor:buffer:)` |
| `File.System.Write.Append.swift` | 150 | Inside `Span.withUnsafeBufferPointer` closure | Needs restructure: similar extraction |
| `File.System.Read.Full.swift` | 205 | Inside `[UInt8](unsafeUninitializedCapacity:)` | Needs restructure: non-throwing init closure |
| `File.System.Read.Full.swift` | 307 | Inside `[UInt8](unsafeUninitializedCapacity:)` | Needs restructure: non-throwing init closure |

**Key insight**: The `withKernelPath` migration resolved the root cause for Move.swift — both instances can now trivially switch to `do throws(E)` syntax, eliminating the fatalError AND the associated Result workaround. The remaining 4 are in stdlib closure boundaries (`withUnsafeBytes`, `unsafeUninitializedCapacity`) that don't support typed throws.

---

### CRITICAL — C-3: Result<T,E> workarounds for typed throws

**Statement**: Eight locations use `Result<T, E>` to escape closure/error typing constraints. Post-migration status:

| File | Line | Root Cause | Fix Difficulty |
|------|------|------------|----------------|
| `File.System.Move.swift` | 146 | **No closure boundary** — Result wraps direct `path.kernelPath` call | **Trivial**: use `do throws(E)` directly |
| `File.System.Move.swift` | 189 | **No closure boundary** — Result wraps direct call | **Trivial**: use `do throws(E)` directly |
| `File.System.Parent.Check.swift` | 33 | **No closure boundary** — Result wraps `Kernel.File.Stats.get(path: path.kernelPath)` | **Trivial**: restructure to direct try |
| `File.System.Read.Full.swift` | 141 | **No closure boundary** — Result wraps stats call on descriptor | **Trivial**: restructure to direct try |
| `File.System.Write.Append.swift` | 138 | Inside `withUnsafeBufferPointer` closure | Needs restructure |
| `File.System.Delete.swift` | 193 | Inside while loop wrapping `stream.next()` | Can restructure to `do throws(E)` |
| `File.Directory.Contents.Iterator.swift` | 74 | Inside `Kernel.Path.scope` closure | Blocked until scope elimination |
| `File.Directory.Contents.Iterator.swift` | 76 | Inside `Kernel.Path.scope` closure | Blocked until scope elimination |

**Key insight**: 4 of 8 are now trivially fixable — the `withKernelPath` closure that forced the Result pattern is gone, but the Result was left behind. These are pure cleanup.

---

### CRITICAL — C-4: File.Handle.write error capture mechanism [IMPL-INTENT]

**Statement**: `File.Handle.write(_: Span<UInt8>)` (File.Handle.swift:92–143) still uses the 50-line imperative pattern with mutable `writeError` capture, `withUnsafeBytes` closure, `catch let error as`, and fatalError. **Unchanged by upstream migration** — the closure boundary here is `Span.withUnsafeBytes`, not `withKernelPath`.

**Recommendation**: Extract `_writeAll(descriptor: Kernel.Descriptor, buffer: UnsafeRawBufferPointer) throws(Kernel.IO.Write.Error)` that takes the raw buffer directly. Call `bytes.withUnsafeBytes` at the call site to get the pointer, then pass it to `_writeAll` outside the closure.

---

### CRITICAL — C-5: Duplicated traversal logic in Walk [IMPL-033]

**Statement**: `File.Directory.Walk` still contains **three** parallel implementations of the same traversal algorithm:
- `_walk()` (~line 415): Array-collecting variant
- `_walkCallback()` (~line 217): Callback-based, typed throws
- `_walkCallbackThrowing()` (~line 335): Callback-based, untyped throws

All implement identical depth checking, cycle detection, hidden file filtering, undecodable entry handling, and symlink following. **Unchanged by upstream migration.**

**Recommendation**: Delete `_walk()` and `_walkCallbackThrowing()`. Implement `callAsFunction()` via `iterate()`:
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

### CRITICAL — C-6: Kernel.Path.scope closures remain (NEW)

**Statement**: While `withKernelPath` is fully eliminated, 6 call sites still use `Kernel.Path.scope(pathString)` — a closure-based pattern that converts `String → kernel path`. These are the remaining source of `catch let error as` and Result workarounds in Contents and Iterator.

| File | Line | Context |
|------|------|---------|
| `File.Directory.Contents.swift` | 101 | `iterate(at:body:)` non-throwing variant |
| `File.Directory.Contents.swift` | 175 | `iterate(at:body:)` throwing variant |
| `File.Directory.Contents.swift` | 290 | `_lstatEntryType` fallback |
| `File.Directory.Contents.Iterator.swift` | 76 | `makeIterator(at:)` |
| `File.Directory.Iterator.swift` | 185 | `_statForType` comment reference |
| `File.Directory.Iterator.swift` | 205 | `_statForType` implementation |

**Root cause**: These files convert `File.Path` → `String` → `Kernel.Path.scope()` instead of using `path.kernelPath` directly. The `Kernel.Path.scope` pattern predates the `kernelPath` property.

**Recommendation**: Replace `Kernel.Path.scope(String(path))` with direct `path.kernelPath` access, matching the migration already done in 18 other files. This eliminates the String conversion AND the closure boundary.

---

### HIGH — H-1: File.Descriptor does not conform to IO.Closable

**Statement**: `File.Descriptor` has `consuming func close() throws(Kernel.Close.Error)` which exactly matches `IO.Closable`'s signature, but does not declare conformance.

**File**: `Sources/File System Primitives/File.Descriptor.swift`

**Fix**: One-line conformance declaration.

---

### HIGH — H-2: Redundant type mappings between Kernel and File.System layers

**Statement**: Three separate enum types represent file types with overlapping semantics:

| Type | Location | Cases |
|------|----------|-------|
| `Kernel.File.Stats.Kind` | swift-kernel | `regular, directory, link(Link), device(Device), fifo, socket, unknown` |
| `File.System.Metadata.Kind` | `File.System.Metadata.Type.swift` | `regular, directory, symbolicLink, blockDevice, characterDevice, fifo, socket` |
| `File.Directory.Entry.Kind` | `File.Directory.Entry.Type.swift` | `file, directory, symbolicLink, other` |

Two mapping functions (`_mapEntryType`, `_makeInfo`) convert between these. **Unchanged by upstream migration.**

**Recommendation**: Consider using `Kernel.File.Stats.Kind` directly in `File.System.Metadata.Info`, eliminating `File.System.Metadata.Kind` and its mapping function. `Entry.Kind` is a valid narrowing for directory iteration.

---

### HIGH — H-3: Single-case error wrappers add indirection without value

**Statement**: Four error types wrap a single Kernel error case. **Unchanged by upstream migration.**

| Error Type | File | Single Case |
|------------|------|-------------|
| `File.System.Link.Hard.Error` | `File.System.Link.Hard.swift` | `.link(Kernel.Link.Error)` |
| `File.System.Link.Symbolic.Error` | `File.System.Link.Symbolic.swift` | `.symlink(Kernel.Link.Symbolic.Error)` |
| `File.System.Create.Directory.Error` | `File.System.Create.Directory.swift` | `.mkdir(Kernel.Directory.Create.Error)` |
| `File.Directory.Iterator.Error` | `File.Directory.Iterator.swift` | `.directory(Kernel.Directory.Error)` |

**Recommendation**: Replace with typealiases. Move semantic accessors to extensions on the Kernel types.

---

### HIGH — H-4: Hand-rolled accessor structs → migrate to Property<Tag, Base> [INFRA-106]

**Statement**: 14 structurally identical hand-rolled accessor structs. **Unchanged by upstream migration.**

Each is the same boilerplate:
```swift
public struct Verb: Sendable {
    public let path: File.Path
    internal init(_ path: File.Path) { self.path = path }
}
```

Types: `File.Copy`, `File.Create`, `File.Delete`, `File.Move`, `File.Read`, `File.Write`, `File.Stat`, `File.Open`, `File.Link`, `File.Directory.Create`, `File.Directory.Delete`, `File.Directory.Copy`, `File.Directory.Move`, `File.Directory.Stat`.

**Recommendation**: Add swift-property-primitives as a dependency. Replace with `Property<Tag, Base>` + tag enums + extensions. **Net line reduction** — 14 struct declarations + 14 inits + 14 accessor properties → tag enums + Property accessors.

---

### HIGH — H-5: Glob pattern construction duplicated 6 times

**Statement**: The pattern construction loop appears verbatim 6 times (sync + async × 3 variants). **Unchanged by upstream migration.**

**Recommendation**: Extract shared core. All 6 variants compose from one implementation.

---

### HIGH — H-6: Fully-qualified module name references

**Statement**: `File.System.Create.swift` uses `File_System_Primitives.File.System.Metadata.Permissions`. **Unchanged by upstream migration.** Likely caused by `File.System.Create.File` (L-1 stub) shadowing `File`.

**Recommendation**: Deleting the `File.System.Create.File` stub (Phase 1) may resolve this collision.

---

### MEDIUM — M-1: Compound method/property names [API-NAME-002]

| Identifier | File | Should Be |
|------------|------|-----------|
| `iterateFiles(options:body:)` | `Walk.swift` | `iterate.files(options:body:)` |
| `iterateDirectories(options:body:)` | `Walk.swift` | `iterate.directories(options:body:)` |
| `isFile(at:)` | `File.System.Stat.swift` (FS) | Evaluate — reads naturally as bool |
| `isDirectory(at:)` | `File.System.Stat.swift` (FS) | Evaluate |
| `isSymlink(at:)` | `File.System.Stat.swift` (FS) | Evaluate |
| `lstatInfo(at:)` | `File.System.Stat.swift` (FSP) | `info(at:followSymlinks:)` |
| `seekToEnd()` | `File.Handle.swift` (FS) | `seek.toEnd()` |

---

### MEDIUM — M-2: Multiple type declarations per file [API-IMPL-005]

| File | Types Declared | Should Split |
|------|----------------|--------------|
| `File.Name.swift` | `Name`, `RawEncoding` | `File.Name.RawEncoding.swift` |
| `File.Directory.Contents.swift` | `Contents`, `Control` | `File.Directory.Contents.Control.swift` |
| `File.Directory.Contents.Iterator.swift` | `Iterator`, `IteratorHandle` | `File.Directory.Contents.IteratorHandle.swift` |
| `File.Directory.Walk.swift` | `Walk`, `InodeKey` | `File.Directory.Walk.InodeKey.swift` (internal) |
| `File.System.Create.swift` | `Create`, `Options` | `File.System.Create.Options.swift` |
| `File.System.Create.Directory.swift` | `Directory`, `Options`, `Error` | Split Options and Error |

---

### MEDIUM — M-3: Raw Int arithmetic where Kernel types exist [IMPL-002]

| File | Expression | Should Be |
|------|------------|-----------|
| `File.Handle.swift` | `totalWritten += written` | Use typed count |
| `File.System.Read.Full.swift` | `totalRead += bytesRead` | Use typed count |
| `File.System.Stat.swift` | `UInt32(stats.linkCount.rawValue.rawValue)` | rawValue chain — 2 levels |
| `File.System.Stat.swift` | `stats.size.rawValue`, `stats.uid.rawValue` | rawValue extraction for mapping |
| `File.Watcher.Options.swift` | `latency: Double` | Use `Duration` |

---

### MEDIUM — M-4: File.Unsafe.Sendable appears unused

**File**: `Sources/File System Primitives/File.Unsafe.Sendable.swift`

Dead code unless used by external consumers. Verify and remove.

---

### MEDIUM — M-5: Primitives exports.swift re-exports too many dependencies

**File**: `Sources/File System Primitives/exports.swift`

`ASCII` and `RFC_4648` are used only internally. Remove `@_exported` from these.

---

### MEDIUM — M-6: File.Path.Component byte-level init duplicates validation

Two nearly identical initializers duplicate POSIX validation logic. Deduplicate.

---

### MEDIUM — M-7: Walk has three traversal implementations

See C-5. After consolidation, this finding is absorbed.

---

### MEDIUM — M-8: File.System.Metadata.Info uses raw types

See H-2. `size: Int64`, `inode: UInt64`, `deviceId: UInt64`, `linkCount: UInt32` should use Kernel types.

---

### MEDIUM — M-9: File.Path._resolvingPOSIX does ad-hoc string manipulation

Uses `hasPrefix`, `lastIndex(of: "/")`, `removeLast()` instead of Paths APIs.

---

### MEDIUM — M-10: File.Handle._pwrite/_pwriteAll are package-internal but substantial

Positional write methods with ESPIPE fallback. Evaluate whether they should be consolidated into atomic write.

---

### MEDIUM — M-11: Duplicated error mapping functions

Four Kernel→File error mapping functions do the same work across Contents, Contents.Iterator.

---

### MEDIUM — M-12: Walk.Options.onUndecodable uses closure instead of enum

Over-engineered. A `Undecodable.Policy` property would suffice for 99% of use cases.

---

### LOW — L-1: 6 stub implementations (TODO markers)

`File.System.Read.Buffered`, `File.System.Read.Streaming`, `File.System.Create.File`, `File.System.Metadata.ACL`, `File.System.Metadata.Attributes`, `File.Watcher`. Delete.

---

### LOW — L-2: File lacks ExpressibleByStringLiteral conformance

Doc comment claims it; conformance missing.

---

### LOW — L-3: File.Handle.Open and File.Descriptor.Open are near-identical

~70% structural duplication. Could share implementation.

---

### LOW — L-4: FTS walker is Darwin-only and likely unused

`package` visibility, no public API usage found. Verify and remove.

---

### LOW — L-5: Binary.Serializable conformances on enum types may be premature

On 5 types without documented consumers.

---

### LOW — L-6: Walk.Error and Contents.Error overlap

Both define `.pathNotFound`, `.permissionDenied`, `.notADirectory`. Unify.

---

### LOW — L-7: File.Path.Property is a novel pattern not used elsewhere

Only 2 built-in properties. Consider moving to Paths.

---

## Dependency Utilization Matrix

| Dependency | Module Used | Utilization | Assessment |
|------------|-------------|-------------|------------|
| **swift-kernel** | `Kernel` | **Heavy** | Core. Fully justified. |
| **swift-io** | `IO`, `IO Primitives` | **Moderate** | `IO.run` for async, `IO.Closable` NOT used (H-1). |
| **swift-paths** | `Paths` | **Heavy** | `File.Path = Paths.Path`. Core. **Recently refactored** — `kernelPath` property replaces closures. |
| **swift-strings** | `Strings` | **Light** | `String.strictUTF8()` in File.Name. Justified. |
| **swift-environment** | `Environment` | **Very light** | Single call site: `Environment.read("HOME")`. |
| **swift-ascii** | `ASCII` | **Marginal** | Re-exported but unclear direct usage. Verify necessity. |
| **swift-binary-primitives** | `Binary Primitives` | **Moderate** | `Binary.Serializable` conformances on 6 types. |
| **swift-time-primitives** | `Time Primitives` | **Unused** | Zero source imports. `Kernel.Time` comes through `Kernel`. **Remove.** |
| **swift-rfc-4648** | `RFC 4648` | **Very light** | Hex encoding in File.Name debug only. Re-exported despite internal-only usage. |

**Recommendations** (subtract first):
1. **Remove** swift-time-primitives (zero source imports)
2. **Stop re-exporting** ASCII and RFC_4648
3. **Verify** swift-ascii necessity; remove if transitive-only
4. **Add** swift-property-primitives (net reduction: replaces 14 hand-rolled accessor structs)

---

## Recommended Migration Order

**Governing principle**: Subtract before adding. Unify before extending. Remove before replacing.

### Phase 1: Remove Dead Code and Unused Dependencies

**Priority**: Highest — pure subtraction, zero risk, immediate cleanup.

1. **Remove** swift-time-primitives from Package.swift (zero source imports)
2. **Remove** `@_exported` from ASCII and RFC_4648 in exports.swift (M-5)
3. **Delete** 6 stub types: `File.System.Read.Buffered`, `File.System.Read.Streaming`, `File.System.Create.File`, `File.System.Metadata.ACL`, `File.System.Metadata.Attributes`, `File.Watcher` + associated files (L-1)
4. **Delete** `File.Unsafe.swift` and `File.Unsafe.Sendable.swift` if unused (M-4 — verify first)
5. **Delete** `File.Directory.Walk+FTS.swift` if unused by public API (L-4 — verify first)
6. **Delete** `File.Path.swift` in File System module if truly empty
7. **Verify** swift-ascii necessity; remove from direct dependencies if transitive-only

**Note**: Deleting `File.System.Create.File` may resolve the H-6 fully-qualified module name collision — verify.

### Phase 2: Eliminate Remaining Closure Workarounds (C-2, C-3, C-6)

**Priority**: High — the upstream `withKernelPath` migration removed the primary cause; this phase completes the cleanup.

**Trivial fixes** (no closure boundary — `withKernelPath` removal left stale Result/fatalError code):
1. `File.System.Move.swift`: Replace `Result<Void, Kernel.File.Move.Error>` + fatalError with `do throws(Kernel.File.Move.Error)` (lines 146–156)
2. `File.System.Move.swift`: Replace `Result<Void, Kernel.File.Delete.Error>` + fatalError with `do throws(Kernel.File.Delete.Error)` (lines 189–201)
3. `File.System.Parent.Check.swift`: Replace `Result<Kernel.File.Stats, ...>` with direct try/catch (line 33)
4. `File.System.Read.Full.swift`: Replace `Result<Kernel.File.Stats, ...>` with direct try/catch (line 141)
5. `File.System.Delete.swift`: Restructure `Result<Entry?, Error>` in while loop to `do throws(E)` (line 193)

**`Kernel.Path.scope` elimination** (C-6):
6. `File.Directory.Contents.swift`: Replace 3 `Kernel.Path.scope(String(path))` calls with `path.kernelPath` (lines 101, 175, 290)
7. `File.Directory.Contents.Iterator.swift`: Replace `Kernel.Path.scope` with `path.kernelPath` (line 76)
8. `File.Directory.Iterator.swift`: Replace `Kernel.Path.scope` in `_statForType` (line 205)

**Closure-boundary restructures** (requires code changes):
9. `File.Handle.write`: Extract `_writeAll(descriptor:buffer:)` taking `UnsafeRawBufferPointer` directly (C-4, eliminates Handle.swift:146 fatalError)
10. `File.System.Write.Append.append`: Similar extraction (eliminates Append.swift:150 fatalError)
11. `File.System.Read.Full.read`: Restructure pread loop outside `unsafeUninitializedCapacity` closure (eliminates Read.Full.swift:205,307 fatalErrors)

### Phase 3: Consolidate Duplicated Code (C-5, H-3, H-4, H-5, M-7, M-11, M-6)

**Priority**: High — reduces code volume.

1. **Walk**: Delete `_walk()` and `_walkCallbackThrowing()`. Three implementations → one. (C-5, M-7)
2. **Glob**: Extract shared pattern-construction + match. Six implementations → one core + thin filters. (H-5)
3. **Accessor structs**: Add swift-property-primitives. Replace 14 hand-rolled structs with `Property<Tag, Base>`. (H-4)
4. **Error wrappers**: Replace 4 single-case types with typealiases to Kernel errors. Move semantic accessors. (H-3)
5. **Error mapping**: Consolidate 4 Kernel→File mapping functions into 1. (M-11)
6. **Path.Component validation**: Deduplicate 2 init methods. (M-6)
7. **Walk.Error / Contents.Error**: Unify overlapping cases. (L-6)
8. **Handle.Open / Descriptor.Open**: Extract shared scoped-open pattern. (L-3)

### Phase 4: Unify Type Mappings (H-2, M-8, H-6)

**Priority**: Medium.

1. Evaluate replacing `File.System.Metadata.Kind` with `Kernel.File.Stats.Kind` directly
2. Replace raw types in `File.System.Metadata.Info` with Kernel types
3. Resolve fully-qualified module name collision (may already be resolved by Phase 1 stub deletion)

### Phase 5: Code Organization (M-2)

**Priority**: Medium — file splitting per [API-IMPL-005].

1. Split `File.Name.RawEncoding`, `Contents.Control`, `Contents.IteratorHandle`, Create nested types to own files

### Phase 6: Naming Compliance (M-1)

**Priority**: Lower — breaking API changes.

1. `iterateFiles` → `iterate.files`, `iterateDirectories` → `iterate.directories`
2. `lstatInfo` → `info(at:followSymlinks:)`
3. `seekToEnd` → `seek.toEnd`
4. Evaluate `isFile`/`isDirectory`/`isSymlink` — may be acceptable as-is

### Phase 7: Typed Throws on Closure APIs (C-1)

**Priority**: Lower — blocked by Swift 6.2 `rethrows` limitations.

1. Convert closure-accepting APIs to `throws(E)` where feasible
2. Document any that must remain untyped due to stdlib constraints

### Phase 8: Ecosystem Conformances (H-1)

**Priority**: Lowest.

1. Add `IO.Closable` conformance to `File.Descriptor` (one declaration, zero new code)
