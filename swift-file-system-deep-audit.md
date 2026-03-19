# swift-file-system Deep Audit

**Date**: 2026-03-19 (updated after Phase 4 + L-2 revert)
**Package**: swift-file-system (Layer 3 — Foundations)
**Location**: `/Users/coen/Developer/swift-foundations/swift-file-system/`
**Scope**: 54 source files in File System Primitives, 32 in File System, 65 test files
**Dependencies**: swift-kernel, swift-io, swift-environment, swift-paths, swift-strings, swift-ascii, swift-binary-primitives, swift-rfc-4648

---

## Executive Summary

swift-file-system is the oldest package in the ecosystem. It **works** — the architecture is sound, typed throws are used pervasively, and Kernel delegation is clean.

### Completed Work

**Phase 1 — Dead code removal** (committed as f2837b9, -1290 lines):
- Deleted 6 stubs, 2 dead utils, FTS walker, empty File.Path.swift (19 files removed)
- Removed swift-time-primitives dependency
- Removed `@_exported` for ASCII and RFC_4648
- Fixed H-6: fully-qualified module name collision resolved by deleting `File.System.Create.File` stub

**Phase 2 — Typed throws cleanup** (committed as f2837b9):
- fatalError("unreachable"): 6 → 0
- Result<> workarounds: 8 → 0
- Kernel.Path.scope closures: 6 → 0
- catch let error as: 14 → 5 (remaining are language limitations in Walk/Contents untyped throws callbacks)

**Upstream refactor** (committed as 299c7b8, dd4e4af):
- swift-paths replaced `withKernelPath` closures with direct `path.kernelPath` property access
- All 45 call sites migrated (-87 lines)

**Phase 3 — Consolidate duplicated code** (committed as e4f270c, -294 lines):
- Walk: 3 traversal implementations → 1. Deleted `_walk()` and `_walkCallbackThrowing()`. `callAsFunction` now delegates to `iterate()`. Throwing `iterate()` wraps non-throwing variant with error capture.
- Glob: 6 copy-pasted pattern construction blocks → 1 shared `_matchPaths`. All 6 variants (sync+async × 3) use the shared core. Async variants delegate to their sync counterpart via `IO.run`.
- Error mapping: Eliminated duplicate `_mapKernelOpenError` in Contents.Iterator by sharing `_mapKernelError` from Contents (made `internal`).
- IO.Closable: Added conformance to `File.Descriptor` (signature already matched).

**Phase 4 — File splits, naming compliance** (committed as 8642a53):
- M-2: Split 6 files with multiple type declarations into 13 files (7 new). All comply with [API-IMPL-005].
- M-1 (partial): Renamed `iterateFiles` → `files`, `iterateDirectories` → `directories` on Walk. Unified `info(at:)`/`lstatInfo(at:)` → `info(at:followSymlinks:)` on Stat.

**Phase 4 follow-up — String → Path.Component migration** (committed as ee38edc):
- File/Directory FS-layer APIs migrated from `String` to `Path.Component` (subscripts, appending, rename, `/` operator, name/extension/stem properties).
- `File.Path.Property` made generic over value type.

**L-2 revert — ExpressibleByStringLiteral removed** (committed as 2f0b526):
- `ExpressibleByStringLiteral` was added to `File` and `File.Directory` then reverted. The conformance silently overrides the throwing `init(_ string:) throws` for string literals — the compiler always selects the non-throwing `stringLiteral` path, turning validation errors into `fatalError` crashes. `@_disfavoredOverload` does not mitigate this; the protocol conformance path wins for literals unconditionally.
- Root cause: design tension between `ExpressibleByStringLiteral` (fatalError on invalid) and throwing init (recoverable). Needs broader design resolution — see `Research/prompts/file-path-type-unification-audit.md`.

### Remaining Issues

- **5 `catch let error as`**: All in Walk `_walkCallback` and Contents throwing `iterate`. Language limitation — the callback closures are untyped throws, so errors from recursive Walk calls or Contents iteration must be caught dynamically. Cannot be eliminated until Swift supports typed rethrows.
- **14 hand-rolled accessor structs**: Evaluated for Property<Tag, Base> migration. **Deferred** — these are clean Copyable structs wrapping `File.Path` with type-specific methods. Property migration would add a dependency for marginal savings (~5 lines per struct declaration) without structural improvement.
- **4 single-case error wrappers**: Evaluated for typealias replacement. **Deferred** — breaking public API change. The wrappers decouple the File System layer from Kernel error types, provide semantic accessors, and are extensively tested.

---

## Remaining Findings

### MEDIUM — M-1: Compound method/property names [API-NAME-002] (Partially Resolved)

| Identifier | File | Status |
|------------|------|--------|
| `iterateFiles(options:body:)` | `Walk.swift` | **Resolved** → `files(options:body:)` |
| `iterateDirectories(options:body:)` | `Walk.swift` | **Resolved** → `directories(options:body:)` |
| `isFile(at:)` | `File.System.Stat.swift` (FS) | **Deferred** — standard Swift boolean predicate convention |
| `isDirectory(at:)` | `File.System.Stat.swift` (FS) | **Deferred** — standard Swift boolean predicate convention |
| `isSymlink(at:)` | `File.System.Stat.swift` (FS) | **Deferred** — standard Swift boolean predicate convention |
| `lstatInfo(at:)` | `File.System.Stat.swift` (FSP) | **Resolved** → `info(at:followSymlinks:)` |
| `seekToEnd()` | `File.Handle.swift` (FS) | **Deferred** — Seek namespace on ~Copyable Handle is over-engineering for one convenience method; `seek(to: 0, from: .end)` already available |

---

### MEDIUM — M-3: Raw Int arithmetic where Kernel types exist [IMPL-002]

**Deferred** — no typed count infrastructure exists in this package. Would require adding new types.

| File | Expression | Should Be |
|------|------------|-----------|
| `File.Handle.swift` | `totalWritten += written` | Use typed count |
| `File.System.Read.Full.swift` | `totalRead += bytesRead` | Use typed count |
| `File.System.Stat.swift` | `UInt32(stats.linkCount.rawValue.rawValue)` | rawValue chain — 2 levels |
| `File.System.Stat.swift` | `stats.size.rawValue`, `stats.uid.rawValue` | rawValue extraction for mapping |

---

### MEDIUM — M-9: File.Path._resolvingPOSIX does ad-hoc string manipulation

**Deferred** — would need Paths APIs for prefix checking, component splitting. Low priority.

---

### MEDIUM — M-10: File.Handle._pwrite/_pwriteAll are package-internal but substantial

**Deferred** — needs design discussion on whether to consolidate into atomic write.

---

### MEDIUM — M-12: Walk.Options.onUndecodable uses closure instead of enum

**Deferred** — the closure pattern works and provides maximum flexibility. Low priority.

---

### LOW — L-2: File/Directory ExpressibleByStringLiteral

**Reverted** — conformance is fundamentally incompatible with the existing throwing `init(_ string:)` on `File.Directory`. For string literals, the compiler always selects the `ExpressibleByStringLiteral` path (non-throwing, fatalError on invalid) over the throwing init, regardless of `@_disfavoredOverload`. Resolution requires a broader design decision about the File/Path type relationship. Research prompt: `Research/prompts/file-path-type-unification-audit.md`.

---

### LOW — L-3: File.Handle.Open and File.Descriptor.Open are near-identical

**Deferred** — ~70% structural overlap, but cleanup paths differ due to ownership semantics (Handle: Copyable `try? close()`, Descriptor: ~Copyable `consume`). A shared abstraction would add protocol + generic constraints + ownership bridging — more complexity than the duplication removes.

---

### LOW — L-5: Binary.Serializable conformances on enum types may be premature

**Deferred** — removing conformances is also a breaking change.

---

### LOW — L-6: Walk.Error and Contents.Error overlap

**Deferred** — unification would nest error cases (`catch .contents(.pathNotFound(let p))` instead of `catch .pathNotFound(let p)`), making error handling less ergonomic. The current flat cases with a 4-line switch mapping are simpler for consumers.

---

### LOW — L-7: File.Path.Property is a novel pattern not used elsewhere

**Deferred** — only 2 built-in properties. Not worth refactoring.

---

## Resolved Findings

| ID | Finding | Resolution | Phase |
|----|---------|------------|-------|
| C-2 | fatalError("unreachable") workarounds (6 sites) | All eliminated | Phase 2 |
| C-3 | Result<T,E> workarounds (8 sites) | All eliminated | Phase 2 |
| C-4 | File.Handle.write error capture | Restructured in Phase 2 | Phase 2 |
| C-5 | Walk: 3 traversal implementations | Consolidated to 1 | Phase 3 |
| C-6 | Kernel.Path.scope closures (6 sites) | All replaced with `path.kernelPath` | Phase 2 |
| H-1 | File.Descriptor missing IO.Closable | Conformance added | Phase 3 |
| H-3 | Single-case error wrappers (4 types) | **Deferred** — breaking API change | — |
| H-4 | 14 hand-rolled accessor structs | **Deferred** — marginal benefit | — |
| H-5 | Glob: 6 copy-pasted implementations | Consolidated via shared `_matchPaths` | Phase 3 |
| H-6 | Fully-qualified module name collision | Resolved by deleting File.System.Create.File stub | Phase 1 |
| M-1a | `iterateFiles` / `iterateDirectories` | Renamed to `files` / `directories` | Phase 4 |
| M-1b | `lstatInfo(at:)` | Unified into `info(at:followSymlinks:)` | Phase 4 |
| M-2 | Multiple types per file (6 files) | Split into 13 files (7 new) | Phase 4 |
| M-4 | File.Unsafe.Sendable unused | Deleted | Phase 1 |
| M-5 | Excessive re-exports (ASCII, RFC_4648) | Removed `@_exported` | Phase 1 |
| M-6 | Path.Component byte-level init duplication | Low priority, deferred | — |
| M-7 | Walk has three traversal implementations | Absorbed into C-5 | Phase 3 |
| M-11 | Duplicated error mapping (4→3) | Shared `_mapKernelError`, eliminated duplicate | Phase 3 |
| L-1 | 6 stub implementations | Deleted | Phase 1 |
| L-2 | File/Directory missing ExpressibleByStringLiteral | **Reverted** — incompatible with throwing init | Phase 4 |
| L-4 | FTS walker Darwin-only | Deleted | Phase 1 |

---

## Dependency Utilization Matrix (Current)

| Dependency | Module Used | Utilization | Assessment |
|------------|-------------|-------------|------------|
| **swift-kernel** | `Kernel` | **Heavy** | Core. Fully justified. |
| **swift-io** | `IO`, `IO Primitives` | **Moderate** | `IO.run` for async, `IO.Closable` now used by File.Descriptor. |
| **swift-paths** | `Paths` | **Heavy** | `File.Path = Paths.Path`. Core. `kernelPath` property. |
| **swift-strings** | `Strings` | **Light** | `String.strictUTF8()` in File.Name. Justified. |
| **swift-environment** | `Environment` | **Very light** | Single call site: `Environment.read("HOME")`. |
| **swift-ascii** | `ASCII` | **Marginal** | Verify necessity; may be transitive-only. |
| **swift-binary-primitives** | `Binary Primitives` | **Moderate** | `Binary.Serializable` conformances on 6 types. |
| **swift-rfc-4648** | `RFC 4648` | **Very light** | Hex encoding in File.Name debug only. |

---

## Statistics

| Metric | Pre-Audit | Post-Phase-1-2 | Post-Phase-3 | Post-Phase-4 |
|--------|-----------|----------------|--------------|--------------|
| Source files (FSP) | 59 | 47 | 47 | 54 |
| Source files (FS) | 33 | 31 | 32 | 32 |
| Total source files | 92 | 78 | 79 | 86 |
| Total source lines | ~11,400 | ~9,600 | ~9,300 | ~9,300 |
| fatalError("unreachable") | 6 | 0 | 0 | 0 |
| Result<> workarounds | 8 | 0 | 0 | 0 |
| Kernel.Path.scope calls | 6 | 0 | 0 | 0 |
| catch let error as | 14 | 5 | 5 | 5 |
| Tests passing | 709 | 709 | 709 | 1039 |

Note: FSP file count increased from 47→54 due to 7 new files from M-2 file splits. Total line count is approximately unchanged (type declarations moved, not added). Test count increased from 709 to 1039 due to tests added in intervening commits and the String → Path.Component migration fixing previously-broken test paths.
