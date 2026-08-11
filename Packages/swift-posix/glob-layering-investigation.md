# Glob Layering Investigation

Date: 2026-04-10

## Problem

`POSIX.Kernel.Glob.Match.swift` (L3) calls raw C functions (`opendir`, `readdir`, `closedir`, `stat`, `lstat`) via `import Darwin`/`import Glibc` instead of delegating to L2's typed wrappers. This violates the L3 policy design principle: "Policy must delegate to L2, never re-implement the syscall."

## Current Architecture

```
L1: Kernel_Glob_Primitives
    Pattern, Segment, Atom, Options, Error — pure type definitions

L3: POSIX Kernel Glob (POSIX.Kernel.Glob.Match.swift)
    match() implementation — 455 lines
    Calls C directly: opendir/readdir/closedir/stat/lstat
    
L2: ISO 9945 Kernel Directory + ISO 9945 Kernel File
    Directory.Stream (opendir/readdir/closedir wrapper) — EXISTS, UNUSED BY GLOB
    File.Stats.get/lget (stat/lstat wrapper) — EXISTS, UNUSED BY GLOB
```

L2 is skipped entirely. The glob implementation jumps from L1 types to raw C.

## What L2 Already Provides

### Directory Listing

`ISO_9945.Kernel.Directory.Stream`:
- `open(at path: Kernel.Path.View) throws(Directory.Error) -> Stream`
- `next() throws(Directory.Error) -> Kernel.Directory.Entry?`
- `close()`

`Kernel.Directory.Entry` (L1) provides:
- `.name: String?` — UTF-8 decoded name
- `.type: Kernel.File.Stats.Kind?` — file type **extracted from `d_type` at readdir time**
- `.isDotOrDotDot: Bool` — helper for `.`/`..` filtering

### File Stat

`ISO_9945.Kernel.File.Stats`:
- `.get(path: Kernel.Path.View) throws(File.Stats.Error) -> Kernel.File.Stats` — stat()
- `.lget(path: Kernel.Path.View) throws(File.Stats.Error) -> Kernel.File.Stats` — lstat()

`Kernel.File.Stats` (L1) provides:
- `.type: Kernel.File.Stats.Kind` — `.directory`, `.regular`, `.link(...)`, etc.
- No mode-bit manipulation needed — already typed

## Raw C Calls → L2 Equivalents

| Current (raw C) | L2 Equivalent | Notes |
|------------------|---------------|-------|
| `opendir(path)` | `Kernel.Directory.open(at: pathView)` | Returns typed `Stream`, not `OpaquePointer` |
| `readdir(dir)` | `stream.next()` | Returns `Directory.Entry?` with `.name` and `.type` |
| `closedir(dir)` | `stream.close()` | Or automatic via `defer` |
| `stat(path, &st)` | `Kernel.File.Stats.get(path: pathView)` | Returns typed `Stats`, not raw `stat` struct |
| `lstat(path, &st)` | `Kernel.File.Stats.lget(path: pathView)` | Same but for symlinks |
| `(st.st_mode & S_IFMT) == S_IFDIR` | `stats.type == .directory` | Typed enum instead of bitmask |

### Bonus: `d_type` Optimization

L2's `Directory.Entry` already extracts `.type` from the `dirent.d_type` field during `readdir`. The current glob code calls `stat()` separately to check `isDirectory` after readdir. Delegating to L2 may eliminate many stat calls — when `d_type` is available (Linux ext4, Darwin APFS), the directory check comes for free from the directory entry.

## Design Question: New L2 Target or Existing APIs?

The handoff suggests "extract directory traversal to `ISO_9945.Kernel.Glob` at L2." I investigated two options:

### Option A: New `ISO 9945 Kernel Glob` target at L2

Would contain glob-specific directory traversal: a walk-and-match primitive that takes patterns and yields matched paths.

**Against:**
- The directory traversal isn't glob-specific. opendir/readdir/stat are already fully wrapped.
- Would duplicate the existing `ISO 9945 Kernel Directory` and `ISO 9945 Kernel File` API surface.
- POSIX `glob(3)` is not purely a specification — the matching algorithm is a composed operation.
- L2 mirrors the specification faithfully. The POSIX glob specification defines the C `glob()` function, but our architecture decomposes it: L1 owns the type definitions, L3 owns the composed operation.

### Option B: L3 delegates to existing L2 directory/stat APIs

Rewrite the three private helpers in `POSIX.Kernel.Glob.Match.swift` to use L2:

```swift
// Before (raw C):
private static func listDirectory(_ path: String, options: Options) throws(Error) -> [String] {
    guard let dir = unsafe opendir(path) else { ... }
    defer { unsafe closedir(dir) }
    while let entry = unsafe readdir(dir) { ... }
}

// After (L2 delegation):
private static func listDirectory(_ path: Kernel.Path.View, options: Options) throws(Error) -> [Directory.Entry] {
    let stream = try Kernel.Directory.open(at: path)  // L2
    defer { stream.close() }
    var entries: [Directory.Entry] = []
    while let entry = try stream.next() {              // L2
        guard !entry.isDotOrDotDot else { continue }
        entries.append(entry)
    }
    return entries
}
```

**For:**
- Uses existing L2 infrastructure — no new targets.
- Consistent with the L3 design principle: delegate, don't re-implement.
- Gets the `d_type` optimization for free.
- Error types align with L2's typed error hierarchy.

### Recommendation: Option B

No new L2 target needed. L3 should delegate to existing L2 APIs. The glob pattern matching algorithm (matchAtoms, matchAtomsRecursive, foldCase) is pure computation and correctly lives at L3. Only the filesystem helpers need rewiring.

## Path Type Conversion

The current glob API uses `Swift.String` for all paths:

```swift
public static func match(pattern: Pattern, in directory: Swift.String, ...) throws(Error)
```

L2 uses `Kernel.Path.View`:

```swift
Kernel.Directory.open(at path: Kernel.Path.View) throws(Directory.Error)
```

Three approaches:

1. **Change the public API to `Kernel.Path`** — most correct, but breaking change for any existing consumers.
2. **Keep `String` public API, convert internally** — `String → Kernel.Path → Kernel.Path.View` at each directory boundary. Allocates per-directory.
3. **Accept both** — provide overloads for `String` and `Kernel.Path.View`.

Recommendation: **Option 1** — change to `Kernel.Path`. The glob API is brand new (just modularized), no external consumers exist. Using `Kernel.Path` from the start is correct. `appendPath` becomes `Kernel.Path` appending, which L1 already supports via the tagged Path extensions.

## Error Mapping

The current glob code manually maps `errno` to `Kernel.Glob.Error`:

```swift
let err = errno
switch err {
case EACCES: throw .accessDenied(path: path)
case ENOENT: throw .notFound(path: path)
...
}
```

L2's `Directory.Error` and `File.Stats.Error` already do this mapping. The glob code should catch L2 errors and translate to `Kernel.Glob.Error`:

```swift
do {
    let stream = try Kernel.Directory.open(at: path)
} catch let error as Kernel.Directory.Error {
    switch error {
    case .permission: throw .accessDenied(path: ...)
    case .notFound: throw .notFound(path: ...)
    case .notDirectory: throw .notDirectory(path: ...)
    ...
    }
}
```

This eliminates raw errno handling from L3 entirely.

## Implementation Plan

1. Add `ISO_9945_Kernel_Directory` and `ISO_9945_Kernel_File` as dependencies of `POSIX Kernel Glob` in Package.swift (currently depends only on `Glob_Primitives` + `POSIX_Core`).
2. Remove `import Darwin` / `import Glibc` / `import Musl` from Match.swift.
3. Change public API parameter type from `Swift.String` to `Kernel.Path`.
4. Rewrite `listDirectory`, `pathExists`, `isDirectory` to delegate to L2.
5. Rewrite `appendPath` to use `Kernel.Path` appending.
6. Map L2 errors to `Kernel.Glob.Error` in catch blocks.
7. Test: the existing glob test suite (if any) should pass unchanged with the new L2 delegation.

Estimated scope: ~80 lines of filesystem helpers rewritten, public API signature change, Package.swift dependency update. Pattern matching code (~250 lines) untouched.

## Relation to Open Questions

This investigation resolves open question #1 from `l3-policy-design.md`: the directory traversal should NOT be extracted to a new L2 target. Instead, L3's glob implementation should delegate to existing L2 directory and stat APIs, consistent with the L3 policy principle.
