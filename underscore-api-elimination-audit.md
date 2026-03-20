# Underscore API Elimination Audit: swift-file-system

**Date**: 2026-03-19
**Scope**: `/Users/coen/Developer/swift-foundations/swift-file-system/` + upstream
**Skills**: implementation, naming, existing-infrastructure

---

## Executive Summary

41 underscore-prefixed identifiers across swift-file-system (8 stored properties, 6 init labels, 27 methods). **Zero public API gaps** — no underscore hides functionality consumers need. The codebase is clean: underscores are used consistently as a local convention for private/internal implementation details.

**Actionable findings**:
- 3 dead code items (delete)
- 2 `__unchecked` inits (rename to `trusted:`)
- 15+ internal methods with redundant underscore prefix (drop prefix)
- 1 upstream dependency (`Kernel.Descriptor._rawValue` — intentional SPI, no change)
- 1 upstream API gap (`POSIX.Kernel.IO.Read` missing)
- 1 MEDIUM naming violation (`seekToEnd`)
- 8 LOW naming violations

---

## 1. Full Inventory

### Stored Properties (8)

| # | Identifier | File:Line | Vis | Wraps | Classification |
|---|-----------|-----------|-----|-------|----------------|
| 1 | `_descriptor` | FSP/File.Descriptor.swift:33 | internal | `Kernel.Descriptor` | D — backing storage for ~Copyable wrapper |
| 2 | `_descriptor` | FSP/File.Handle.swift:33 | internal | `File.Descriptor` | D — backing storage |
| 3 | `_stream` | FSP/File.Directory.Iterator.swift:21 | private | `Kernel.Directory.Stream?` | D — owned resource |
| 4 | `_basePath` | FSP/File.Directory.Iterator.swift:22 | private | `File.Path` | D — iteration context |
| 5 | `_stream` | FSP/File.Directory.Contents.Iterator.swift:16 | internal | `Kernel.Directory.Stream` | D — IteratorProtocol state |
| 6 | `_finished` | FSP/File.Directory.Contents.Iterator.swift:17 | internal | `Bool` | D — IteratorProtocol state |
| 7 | `_lastError` | FSP/File.Directory.Contents.Iterator.swift:18 | internal | `Kernel.Directory.Error?` | D — IteratorProtocol state |
| 8 | `_open` | FS/File.Open.swift:36 | internal | `File.Handle.Open` | D — delegation target |

**Verdict**: All correct as internal. Standard Swift `_name` convention for backing storage. The underscore prevents confusion between the stored property and the public accessor / type name (e.g., `_open` vs the `open` verb).

### Init Labels (6)

| # | Identifier | File:Line | Vis | Classification |
|---|-----------|-----------|-----|----------------|
| 9 | `init(__unchecked:_:)` | FSP/File.Path.swift:39 | package | **E — rename** to `init(trusted:)` |
| 10 | `init(__unchecked:_:)` | FSP/File.Path.swift:45 | package | **E — rename** to `init(trusted:)` |
| 11 | `init(__unchecked:)` | FSP/File.Descriptor.swift:37 | internal | D — correct, single-use trusted constructor |
| 12 | `init(_resolving:)` | FSP/File.Path.swift:69 | package | **E — dead code, delete** |
| 13 | `init(_resolvingPOSIX:)` | FSP/File.Path.swift:89 | package | **E — dead code, delete** |
| 14 | `init(_normalizingWindows:)` | FSP/File.Path.swift:152 | package | **E — dead code, delete** |

### Methods (27)

| # | Identifier | File:Line | Vis | Classification |
|---|-----------|-----------|-----|----------------|
| 15 | `_writeAll(_:)` | FSP/File.Handle.swift:122 | internal | D — drop underscore |
| 16 | `_pwrite(_:at:)` | FSP/File.Handle.swift:156 | package | D — drop underscore |
| 17 | `_pwriteAll(_:at:)` | FSP/File.Handle.swift:186 | package | D — drop underscore |
| 18 | `_writeAll(_:from:)` | FSP/File.System.Write.Append.swift:141 | private | D — drop underscore |
| 19 | `_readAll(descriptor:size:)` | FSP/File.System.Read.Full.swift:211 | private | D — drop underscore |
| 20 | `_matchPaths(include:excluding:options:)` | FS/File.Directory.Glob.swift:66 | internal | D — drop underscore |
| 21 | `_walkCallback(at:options:depth:visited:body:)` | FSP/File.Directory.Walk.swift:201 | internal | D — drop underscore |
| 22 | `_statForType(name:)` | FSP/File.Directory.Iterator.swift:165 | private | D — drop underscore |
| 23 | `_copyRecursive(from:to:options:)` | FSP/File.System.Copy.Recursive.swift:49 | internal | D — drop underscore |
| 24 | `_copySymlinkTarget(from:to:options:)` | FSP/File.System.Copy.Recursive.swift:175 | private | D — drop underscore |
| 25 | `_copySymlinkRecursive(from:to:)` | FSP/File.System.Copy.Recursive.swift:203,230 | private | D — drop underscore |
| 26 | `_copyDirectoryAttributes(from:to:)` | FSP/File.System.Copy.Recursive.swift:249 | private | D — drop underscore |
| 27 | `_copyDirectoryTimestamps(from:to:)` | FSP/File.System.Copy.Recursive.swift:270 | private | D — drop underscore |
| 28 | `_mapContentsError(_:source:)` | FSP/File.System.Copy.Recursive.swift:298 | private | D — drop underscore |
| 29 | `_stat(_:)` | FSP/File.System.Delete.swift:153 | internal | D — drop underscore |
| 30 | `_unlink(at:)` | FSP/File.System.Delete.swift:159 | internal | D — drop underscore |
| 31 | `_rmdir(at:)` | FSP/File.System.Delete.swift:169 | internal | D — drop underscore |
| 32 | `_deleteDirectoryRecursive(at:)` | FSP/File.System.Delete.swift:179 | internal | D — drop underscore |
| 33 | `_mkdir(at:permissions:)` | FSP/File.System.Create.Directory.swift:42 | private | D — drop underscore |
| 34 | `_createIntermediates(at:permissions:)` | FSP/File.System.Create.Directory.swift:54 | private | D — drop underscore |
| 35 | `_mapKernelError(_:path:)` | FSP/File.Directory.Contents.swift:157 | internal | D — drop underscore |
| 36 | `_mapEntryType(_:name:parent:)` | FSP/File.Directory.Contents.swift:183 | private | D — drop underscore |
| 37 | `_lstatEntryType(name:parent:)` | FSP/File.Directory.Contents.swift:210 | private | D — drop underscore |
| 38 | `_makeInfo(from:)` | FSP/File.System.Stat.swift:57 | internal | D — drop underscore |
| 39 | `_copyAndDelete(from:to:options:)` | FSP/File.System.Move.swift:159 | private | D — drop underscore |
| 40 | `_createParent(at:)` | FSP/File.System.Parent.Check.swift:95 | private | D — drop underscore |
| 41 | `_mapKernelReadError(_:path:)` | FSP/File.Directory.Contents.Iterator.swift:100 | private | D — drop underscore |

---

## 2. Classification Summary

| Category | Count | Action |
|----------|-------|--------|
| **A. Should be public API** | 0 | — |
| **B. Should be Property accessor** | 0 | All internal — reclassified to D |
| **C. Upstream fix needed** | 1 | `_rawValue` (keep — intentional SPI) |
| **D. Correct as internal** | 35 | 27 methods can drop underscore prefix |
| **E. Delete / rename** | 5 | 3 dead code + 2 rename |

---

## 3. Upstream Dependency Analysis

### Only upstream underscore: `Kernel.Descriptor._rawValue`

**Chain**: `File.Descriptor.rawValue` → `_descriptor._rawValue` → `Kernel.Descriptor._raw`

`_rawValue` is `@_spi(Syscall) public` in swift-kernel-primitives. This is intentional — raw descriptor values should only be accessed at the syscall boundary. `File.Descriptor` IS the right layer to expose `rawValue` to consumers. **No change recommended.**

### API gap: Missing `POSIX.Kernel.IO.Read`

swift-file-system manually handles EINTR in two places:
- `File.System.Write.Append._writeAll` (FSP/File.System.Write.Append.swift:158)
- `File.System.Read.Full._readAll` (FSP/File.System.Read.Full.swift:233)

`POSIX.Kernel.IO.Write` exists in swift-posix with EINTR retry, but `POSIX.Kernel.IO.Read` does not. **Recommendation**: Add `POSIX.Kernel.IO.Read` to swift-posix, then replace manual EINTR loops.

### All other underscores are local

Every stored property, init, and method in swift-file-system calls clean upstream APIs. No upstream package forces underscore usage in swift-file-system beyond the single `_rawValue` SPI.

---

## 4. Replacement Designs

### E-class: Dead Code (DELETE)

```swift
// File.Path.swift:69 — 0 callers anywhere in swift-foundations
package init(_resolving string: Swift.String) { ... }

// File.Path.swift:89 — only called from _resolving
package init(_resolvingPOSIX string: Swift.String) { ... }

// File.Path.swift:152 — only called from _resolving
package init(_normalizingWindows string: Swift.String) { ... }
```

**Action**: Delete all three. If path resolution is needed later, add a public `init(resolving:)`.

### E-class: Rename `__unchecked` → `trusted`

**Current** (5 call sites):
```swift
File.Path(__unchecked: (), pathString)
File.Descriptor(__unchecked: descriptor)
```

**Proposed**:
```swift
package init(trusted path: Paths.Path) {
    self = path
}

package init(trusted string: Swift.String) {
    self = Paths.Path(stringLiteral: string)
}
```

**Call site becomes**:
```swift
File.Path(trusted: pathString)
```

### D-class: Drop Redundant Underscores

For all 27 internal/private methods, the underscore prefix is redundant since visibility already restricts access. Example:

**Current**:
```swift
internal static func _stat(_ path: File.Path) throws(Kernel.File.Stats.Error) -> Kernel.File.Stats
internal static func _unlink(at path: File.Path) throws(Error)
internal static func _rmdir(at path: File.Path) throws(Error)
internal static func _deleteDirectoryRecursive(at path: File.Path) throws(Error)
```

**Proposed**:
```swift
internal static func stat(_ path: File.Path) throws(Kernel.File.Stats.Error) -> Kernel.File.Stats
internal static func unlink(at path: File.Path) throws(Error)
internal static func rmdir(at path: File.Path) throws(Error)
internal static func deleteRecursive(at path: File.Path) throws(Error)
```

Note: stored properties (#1–8) should KEEP underscores — they disambiguate backing storage from public accessors / type names (e.g., `_open` vs the `open` verb, `_descriptor` vs the type `Descriptor`).

---

## 5. Priority Ranking

| Priority | Item | Impact | Effort |
|----------|------|--------|--------|
| **P1** | Delete dead code (#12–14) | Eliminates 3 unused inits + ~90 lines | Trivial |
| **P2** | Rename `__unchecked` → `trusted` (#9–10) | 5 call sites, clearer API contract | Low |
| **P3** | Drop underscore from internal methods (#15–41) | 27 renames, pure style improvement | Medium (mechanical) |
| **P4** | Add `POSIX.Kernel.IO.Read` (upstream) | Eliminates manual EINTR handling in 2 places | Medium (upstream) |
| **P5** | Fix `seekToEnd` naming (see Section 6) | 1 public method rename | Low |
| — | `Kernel.Descriptor._rawValue` SPI | Intentional design — no change | — |

---

## 6. Non-Underscore Naming Violations

### MEDIUM

| Identifier | File:Line | Current | Proposed |
|-----------|-----------|---------|----------|
| `seekToEnd` | FS/File.Handle.swift:55 | `handle.seekToEnd()` | Remove — callers have `seek(to: 0, from: .end)` |

### LOW

| Identifier | File:Line | Current | Assessment |
|-----------|-----------|---------|------------|
| `readWrite` | FS/File.Open.swift:139 + 5 | `file.open.readWrite { }` | Keep — mirrors `Mode.readWrite`, decomposition creates ambiguity |
| `pathIfValid` | FSP/File.Directory.Entry.swift:71 | `entry.pathIfValid` | Remove — `try? entry.path()` is equivalent |
| `kernelDescriptor` | FSP/File.Descriptor.swift:58 | `descriptor.kernelDescriptor` | Consider `descriptor.kernel` returning `Kernel.Descriptor` |
| `posixBytes` | FSP/File.Name.swift:329 | `name.posixBytes` | Consider `name.posix.bytes` via platform namespace |
| `windowsCodeUnits` | FSP/File.Name.swift:342 | `name.windowsCodeUnits` | Consider `name.windows.codeUnits` |
| `debugRawBytes` | FSP/File.Name.Decode.Error.swift:42 | `error.debugRawBytes` | Idiomatic `debug`-prefix — borderline |
| `iteratorError` | FSP/File.Directory.Contents.Iterator.swift:85 | static method | Restructure to `error(for:directory:)` |
| `closeIterator` | FSP/File.Directory.Contents.Iterator.swift:73 | static method | Remove — `IteratorHandle.deinit` handles cleanup |

### Previously Reported — Now Fixed

- `iterateFiles` — now `dir.walk.files()` / `dir.files()`
- `iterateDirectories` — now `dir.walk.directories()` / `dir.directories()`
- `lstatInfo` — now `File.System.Stat.info(at:)`

### Zero [API-NAME-001] Violations

All types follow the `Nest.Name` pattern correctly.

---

## 7. Governing Principles Applied

1. **"Underscores are debt, not design"** — In this codebase, underscores are used consistently as a LOCAL convention, not as design debt. The 3 dead code items are the only true debt. The 27 redundant-underscore methods are a style choice, not a missing abstraction.

2. **"If it's called from outside the type, it's API"** — Checked. All cross-file internal callers use methods that already have appropriate visibility. No hidden public API surfaces.

3. **"Follow the chain"** — Traced all chains into upstream. Only `_rawValue` crosses the boundary, and that's intentional SPI.

4. **"Breaking changes are fine"** — The `__unchecked` → `trusted` rename and `seekToEnd` removal are breaking. Both are improvements worth making.

5. **"Read before proposing"** — Every classification was made after reading the surrounding code.
