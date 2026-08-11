# Glob Layering Research: L1 Vocabulary, L2 Specification, L3 Composition

<!--
---
version: 2.0.0
last_updated: 2026-04-13
status: RECOMMENDATION
---
-->

## Context

During the Kernel Primitives umbrella removal (336 files, 14 repos, 3 layers), a clean build of `swift-file-system` revealed a type mismatch: `File.Directory.Glob.matchPaths()` passes `Swift.String` where `Kernel.Glob.match()` now requires `borrowing Kernel.Path.View`. The prior research (`glob-layering-investigation.md`, 2026-04-10) resolved L2 delegation for directory traversal (Option B adopted, implemented) and changed the public API to `Kernel.Path.View`.

This investigation resolves three questions:
1. Where does `String`-accepting convenience belong?
2. What is the correct layering for glob across L1--L3?
3. Should there be a `Kernel Glob` target in swift-kernel?

### Prior research carried forward

| Finding | Source | Verification |
|---------|--------|-------------|
| L2 delegation (Option B): L3 delegates to existing L2 directory/stat APIs | `glob-layering-investigation.md` | Verified: 2026-04-13 -- `Kernel.Glob+Match.swift` imports `ISO_9945_Kernel_Directory`, `ISO_9945_Kernel_File`; helpers use `ISO_9945.Kernel.Directory.open(at:)`, `stream.next()`, `Kernel.File.Stats.get(path:)` |
| Path type changed to `Kernel.Path.View` | `glob-layering-investigation.md` | Verified: 2026-04-13 -- all 4 public overloads take `borrowing Kernel.Path.View` |
| Error mapping from L2 to L1 | `glob-layering-investigation.md` | Verified: 2026-04-13 -- `Kernel.Glob.Error.init(from:pathView:)` maps `Kernel.Directory.Error` cases |

### Changelog

- **v2.0.0** (2026-04-13): Revised architecture. Added L2 `ISO_9945_Glob` for `fnmatch(3)` and `glob(3)` encoding. L3 delegates matching to L2 `fnmatch` instead of reimplementing. No swift-kernel `Kernel Glob` target needed -- re-export chain handles unification. Supersedes v1.0.0 analysis of Question 2 and layering summary.

## Questions

1. Should `Kernel.Glob.match` have `String`-accepting overloads? If so, at which layer?
2. What is the correct layering for glob across L1--L3? Should there be a `Kernel Glob` target in swift-kernel?
3. Should the return type change from `Swift.String` to `Kernel.Path` or `Kernel.Path.View`?

## Current State (Verified 2026-04-13)

### L1 -- `Kernel_Glob_Primitives` (swift-primitives/swift-kernel-primitives)

15 files: `Kernel.Glob` namespace, `Pattern`, `Segment`, `Atom`, `Options`, `Error`, `Scalar.Class`. Pure vocabulary types with no filesystem access. Re-exported by `Kernel_Core` via `@_exported public import Kernel_Glob_Primitives`.

**Status**: CORRECT. No changes needed.

### L2 -- `ISO_9945_Glob` DOES NOT EXIST

POSIX (IEEE 1003.1) specifies two glob-related C library functions:

| Function | Header | What it does | Syscall? |
|----------|--------|-------------|----------|
| `fnmatch(3)` | `<fnmatch.h>` | Matches a single filename against a pattern | No -- pure computation |
| `glob(3)` | `<glob.h>` | Expands a pattern into matching paths (walk + match) | No -- calls opendir/readdir/stat internally |
| `globfree(3)` | `<glob.h>` | Frees the `glob_t` result structure | No -- memory management |

Both are available on Darwin and Linux. Neither has a Windows equivalent.

Neither is currently encoded in `swift-iso-9945`. The POSIX glob specification is **unrepresented at L2**. This is the architectural gap.

**`fnmatch(3)` capabilities:**

| Feature | POSIX `fnmatch` | Ecosystem L1 Atom equivalent |
|---------|-----------------|------------------------------|
| `*` (any sequence) | Yes, `FNM_PATHNAME` controls `/` matching | `.star` |
| `?` (single char) | Yes | `.question` |
| `[abc]` character class | Yes | `.scalar(class)` |
| `[!abc]` negated class | Yes | `.scalar(class)` with negation |
| Case-insensitive | `FNM_CASEFOLD` (BSD/GNU extension) | `options.caseInsensitive` |
| Dotfile handling | `FNM_PERIOD` | `options.dotfiles` |
| `**` recursive | **Not in POSIX** | Handled by `matchSegments` at L3 |

`fnmatch(3)` covers all single-entry matching. The only ecosystem extension beyond POSIX is `**` recursive, which is a traversal concern handled by `matchSegments`, not a matching concern.

**Status**: MISSING. `fnmatch(3)` and `glob(3)` should be encoded at L2 per [PLAT-ARCH-012].

### L3 POSIX -- `POSIX_Kernel_Glob` (swift-foundations/swift-posix)

`Kernel.Glob+Match.swift`: 4 public overloads + private implementation (~530 lines).

Public API:

```swift
// Streaming (primary)
public static func match(
    pattern: Pattern,
    in directory: borrowing Kernel.Path.View,
    options: Options = .init(),
    body: (Swift.String) -> Void
) throws(Error)

// Multi-pattern, streaming, collecting, multi-pattern collecting — 4 overloads total
```

Delegates directory traversal to L2: `ISO_9945_Kernel_Directory` (listing), `ISO_9945_Kernel_File` (stat/lstat). Error mapping from L2 `Kernel.Directory.Error` to L1 `Kernel.Glob.Error`.

**Reimplements pattern matching in pure Swift** (~200 lines): `matchAtoms`, `matchBytesRecursive`, `shouldSkipEntry`, `utf8CharLength`, `decodeUTF8Scalar`. This duplicates what `fnmatch(3)` already provides.

Re-export chain: `POSIX_Kernel_Glob` -> `POSIX_Kernel` -> `Kernel_Core`. On POSIX, `import Kernel` makes `Kernel.Glob.match()` available.

**Status**: Traversal delegation is CORRECT. Matching reimplementation should delegate to L2 `fnmatch(3)` once encoded.

### L3 Windows -- `Windows_Kernel` (swift-foundations/swift-windows)

`Windows.Kernel.Glob.Match.swift`: 2 public overloads. Uses `FindFirstFileW`/`FindNextFileW` for directory traversal (passes `\*` wildcard -- lists ALL entries, matches each in pure Swift). Pattern matching reimplemented in Swift (~150 lines), structurally identical to POSIX version.

Windows has no `fnmatch` or `glob` equivalent. The entire implementation is pure-Swift pattern matching + Win32 directory listing.

**Status**: Old implementation; will be refactored when Windows platform stack matures. Not the focus of this investigation.

### L3 Unified -- `Kernel_Core` (swift-foundations/swift-kernel)

Re-exports `Kernel_Glob_Primitives` (L1) on all platforms. On POSIX, `POSIX_Kernel` re-export chain makes `Kernel.Glob.match()` available. No `Kernel Glob` target exists in swift-kernel.

**Status**: On POSIX, unification works via re-export chain. Windows gap exists but is deferred.

### Consumer -- `File_System` (swift-foundations/swift-file-system)

`File.Directory.Glob.matchPaths()` at `File.Directory.Glob.swift:82-87`:

```swift
try Kernel.Glob.match(
    include: includePatterns,
    excluding: excludePatterns,
    in: Swift.String(directory.path),   // ← BROKEN: wants Kernel.Path.View
    options: options
) { results.append($0) }
```

**Status**: BROKEN. Type mismatch since POSIX glob moved to `Kernel.Path.View`.

## Analysis

### The Architectural Gap: Missing L2 Encoding

Per [PLAT-ARCH-012]: "Did **they** define these types?" -- Yes. IEEE 1003.1 defines `fnmatch(3)` and `glob(3)`. They belong at L2.

The current architecture skips L2 for pattern matching. L3 `POSIX_Kernel_Glob` delegates directory traversal to L2 (`ISO_9945_Kernel_Directory`) but reimplements matching in pure Swift instead of delegating to L2 `fnmatch(3)`. This is the same violation the prior research identified for directory traversal ("L3 jumps to raw C instead of using L2") -- but for matching instead of I/O.

### Proposed L2: `ISO_9945_Glob`

A new target in `swift-iso-9945` encoding the POSIX glob specification:

```swift
// ISO_9945_Glob target
extension ISO_9945.Glob {
    /// Wraps fnmatch(3). Matches a single filename against a pattern.
    ///
    /// This is the POSIX specification for glob pattern matching.
    /// Supports *, ?, [...] character classes.
    public static func fnmatch(
        pattern: borrowing Kernel.Path.View,
        name: borrowing Kernel.Path.View,
        flags: Options
    ) -> Bool

    /// Wraps glob(3). Expands a pattern into matching paths.
    ///
    /// Allocates internally via glob_t. Prefer Kernel.Glob.match
    /// at L3 for streaming results and ** support.
    public static func expand(
        pattern: borrowing Kernel.Path.View,
        flags: Options
    ) throws(Error) -> [Swift.String]
}
```

`fnmatch(3)` is the critical encoding. It gives L3 the system's tested, optimized pattern matching. `glob(3)` is encoded for specification completeness but L3 may prefer its own traversal (using L2 directory APIs) for `**` support and streaming.

### How L3 Changes

With L2 `fnmatch` available, `POSIX_Kernel_Glob` becomes a proper L3 composition:

| Current L3 | Revised L3 |
|---|---|
| Reimplements `matchAtoms` + `matchBytesRecursive` (~200 lines) | Delegates to `ISO_9945.Glob.fnmatch` (L2) |
| Delegates directory traversal to `ISO_9945_Kernel_Directory` (L2) | Same |
| Adds `**` recursive on top | Same |
| Adds streaming/callback API | Same |
| Adds typed error mapping | Same |

The ~200 lines of pure-Swift matching algorithm (`matchAtoms`, `matchBytesRecursive`, `utf8CharLength`, `decodeUTF8Scalar`, case folding) are replaced by a single L2 `fnmatch` call per entry. L3 becomes genuinely thin: segment traversal + `**` recursion + `fnmatch` delegation.

### Should There Be a swift-kernel `Kernel Glob` Target?

**No.** The re-export chain already handles unification.

On POSIX: `POSIX_Kernel_Glob` extends `Kernel.Glob` (adds `match` methods) -> `POSIX_Kernel` re-exports it -> `Kernel_Core` re-exports `POSIX_Kernel`. Consumer writes `import Kernel; Kernel.Glob.match(...)` and it works.

On Windows (future): `Windows_Kernel` glob would extend `Kernel.Glob` (same namespace) -> `Kernel_Core` re-exports `Windows_Kernel`. Same consumer code works.

Unlike `Kernel Event` (which unifies genuinely different kernel mechanisms: kqueue/epoll/IOCP), glob has:
- Identical algorithm structure on all platforms
- Directory traversal already unified by `import Kernel` -> `Kernel.Directory.open`
- No platform-specific kernel glob mechanism to bridge

A `Kernel Glob` target would be an empty shell -- the re-export chain does its job automatically. The platform L3 packages (swift-posix, swift-windows) are the right home for the composed operation because:
- On POSIX: the composition uses `fnmatch(3)` (POSIX-specific L2 API)
- On Windows: the composition uses pure-Swift matching (no `fnmatch` available)
- The matching backend IS platform-specific, justifying platform L3 packages

### Question 1: `String`-Accepting Overloads

**No.** `Paths.Path` (= `File.Path`) has a zero-copy `kernelPath` bridge to `Kernel.Path.View`:

```swift
// swift-paths/Sources/Paths/Path.swift:247
extension Path {
    public var kernelPath: Kernel.Path.View {
        @_lifetime(borrow self) borrowing get { ... }
    }
}
```

This is the same bridge used by all 26+ file-system-to-kernel operations (`File.System.Stat`, `File.System.Create.Directory`, etc.). The consumer fix is `directory.path.kernelPath`.

Consumers with `Swift.String` use `Kernel.Path.scope(string) { pathView in ... }` -- the established scoped-conversion pattern.

Adding String overloads for glob alone would be inconsistent with every other kernel API.

### Question 3: Return Type

**Keep `Swift.String`.** `Kernel.Path.View` is `~Copyable` + `~Escapable` (cannot be collected). `Kernel.Path` would double-allocate. `Swift.String` is the Swift standard library's universal text type, not a C type leak per [PLAT-ARCH-005a]. The type-safety boundary is on the input side (`Kernel.Path.View`), not the output side.

## Outcome

**Status**: IMPLEMENTED (2026-04-13)

### Target Architecture

```
L1  Kernel_Glob_Primitives              Pattern, Segment, Atom, Options, Error
    (swift-kernel-primitives)            Our vocabulary. No matching algorithm.

L2  ISO_9945_Glob (NEW)                 fnmatch(3) — single-entry matching
    (swift-iso-9945)                     glob(3) — pattern expansion (for completeness)
                                         Faithful IEEE 1003.1 encoding. POSIX only.

L3  POSIX_Kernel_Glob                   Kernel.Glob.match(pattern:in:options:body:)
    (swift-posix)                        MATCHING: delegates to L2 ISO_9945.Glob.fnmatch
                                         TRAVERSAL: delegates to L2 ISO_9945_Kernel_Directory
                                         ADDS: ** recursive, streaming, typed errors
                                         Re-exported via POSIX_Kernel → Kernel_Core

L3  Windows glob (future)               Same Kernel.Glob.match API surface
    (swift-windows)                      MATCHING: pure-Swift (no fnmatch on Windows)
                                         TRAVERSAL: Windows directory listing
                                         Re-exported via Windows_Kernel → Kernel_Core

    File.Directory.Glob                  Thin wrapper over Kernel.Glob.match
    (swift-file-system)                  Converts File.Path → Kernel.Path.View via kernelPath
                                         Wraps results in File.Directory.Glob.Match types
```

No `Kernel Glob` target in swift-kernel. The re-export chain handles unification.

### Phase 1: Fix the Consumer (Immediate)

`File.Directory.Glob.matchPaths()` at `File.Directory.Glob.swift:82-87`:

```swift
// Fix: use the zero-copy kernelPath bridge
try Kernel.Glob.match(
    include: includePatterns,
    excluding: excludePatterns,
    in: directory.path.kernelPath,
    options: options
) { results.append($0) }
```

### Phase 2: Encode `fnmatch(3)` and `glob(3)` at L2

Add `ISO_9945_Glob` target to `swift-iso-9945` wrapping:
- `fnmatch(3)` -- single-entry pattern matching
- `glob(3)` -- pattern expansion (for specification completeness)

This is the missing L2 encoding per [PLAT-ARCH-012].

### Phase 3: Refactor L3 to Delegate Matching to L2

DONE (2026-04-13). L3 delegates matching to `ISO_9945.Glob.fnmatch` via `entry.nameView` (zero-allocation `@_lifetime(borrow self)` property on `Kernel.Directory.Entry`, same pattern as `Paths.Path.kernelPath`). Pattern segments use `Kernel.Path.scope` (one allocation per segment for String→Path bridge). ~200 lines of pure-Swift matching deleted (`matchAtoms`, `matchBytesRecursive`, `utf8CharLength`, `decodeUTF8Scalar`).

Data plumbing changes that enabled zero-allocation delegation:
- L2 `ISO_9945_Kernel_Directory`: preserved NUL in `rawName` (`count: length + 1`)
- L1 `Kernel.Directory.Entry`: added `nameView` property, updated `isDotOrDotDot` and `name` for NUL-inclusive rawName

L3 retains:
- `matchSegments` -- recursive directory walk with `**` support
- `listDirectory`, `pathExists`, `isDirectory` -- L2 directory/stat delegation (already done)
- `shouldSkipEntry` -- dotfile policy (maps to `fnmatch` `FNM_PERIOD` flag)
- Error mapping from L2 to L1
- Streaming/callback API and result collection

### Requirement ID Justification

| Decision | Requirement | Rationale |
|----------|-------------|-----------|
| L1 vocabulary stays unchanged | [PLAT-ARCH-012] | "Did **we** define these types?" -- yes, L1 |
| L2 `ISO_9945_Glob` for fnmatch/glob | [PLAT-ARCH-012] | "Did **they** define these?" -- yes, IEEE 1003.1, L2 |
| L2 safe API only, no `@unsafe` overloads | [PLAT-ARCH-005a] | All unsafe is internal to implementation body |
| L3 POSIX delegates matching to L2 fnmatch | [PLAT-ARCH-009], L3 policy principle | L3 composes L2 APIs via `nameView` + `Path.scope` |
| `entry.nameView` zero-allocation property | `@_lifetime(borrow self)` | Same pattern as `Paths.Path.kernelPath` |
| No swift-kernel `Kernel Glob` target | [PLAT-ARCH-006] | Re-export chain handles unification; no platform divergence to bridge |
| Consumer uses `path.kernelPath` | [PLAT-ARCH-008] | Established bridge pattern for File.Path → Kernel.Path.View |
| No String overloads | Consistency | No kernel API takes Swift.String; Path.scope is the conversion mechanism |
| `Swift.String` return type | [PLAT-ARCH-005a] | Not a C type leak; ~Copyable constraints prevent Path.View return |

## References

- `glob-layering-investigation.md` (2026-04-10) -- L2 delegation analysis for directory traversal
- `l3-policy-design.md` -- L3 POSIX policy principles
- IEEE 1003.1 `<fnmatch.h>` -- `fnmatch(3)` specification
- IEEE 1003.1 `<glob.h>` -- `glob(3)` specification
- `swift-paths/Sources/Paths/Path.swift:247` -- `kernelPath` bridge
- `swift-path-primitives/Sources/Path Primitives/Path.String.swift` -- `Path.scope` conversion
- [PLAT-ARCH-001] through [PLAT-ARCH-014] -- Platform skill requirements
- [PRIM-ARCH-001], [PRIM-ARCH-002] -- Primitives tier rules
