# Source File Loading Design
<!--
---
version: 1.0.0
last_updated: 2026-03-16
status: DECISION
---
-->

## Status: DECISION

## Problem Statement

swift-source needs to load source files from disk into memory for lexing and parsing.
Three questions:

1. **I/O mechanism**: Foundation (`Data(contentsOf:)`), POSIX syscalls (`open`/`read`/`close`), or `mmap`?
2. **Caching model**: How to avoid re-reading the same file?
3. **Content representation**: `String`, `[UInt8]`, or something else?

---

## Decision: POSIX System Calls

### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| Foundation `Data(contentsOf:)` | Simple, cross-platform | Violates [PRIM-FOUND-001] spirit; untyped throws; pulls in large dependency |
| POSIX `open`/`read`/`close` | No Foundation dependency; typed error handling; direct control | Platform conditionals needed; more code |
| `mmap` | Zero-copy for large files; lazy page faults | Complex lifetime management; platform differences; overkill for source files |

### Decision

**POSIX `open`/`read`/`close`** via `#if canImport(Darwin)` / `#if canImport(Glibc)` / `#if canImport(Musl)` conditionals.

Rationale:
- Foundations packages discourage Foundation imports (Layer 3 should minimize external surface)
- Source files are typically small (< 1 MB); `read()` into a contiguous buffer is efficient
- `mmap` adds complexity without proportional benefit for source files; can be added later as an optimization
- POSIX gives us `errno`-level control for typed throws

### Platform Support

```
#if canImport(Darwin)    // macOS, iOS, etc.
#elseif canImport(Glibc) // Linux (glibc)
#elseif canImport(Musl)  // Linux (musl, e.g. Alpine)
#elseif os(Windows)      // Windows (deferred — stub only)
#endif
```

Windows support is deferred. The initial implementation covers Darwin and Linux.

---

## Decision: Simple Dictionary Cache

### Design

`Source.Cache` wraps `Dictionary<String, [UInt8]>`.

- Key: file path as `String`
- Value: loaded content as `[UInt8]`
- Lookup is O(1) amortized
- Single-threaded initially (no locking)
- `Sendable` because the struct is value-typed

### Future Evolution

- Actor-based cache for concurrent access
- LRU eviction for memory pressure
- Integration with `Source.File.ID` from source-primitives when that stabilizes

---

## Decision: `[UInt8]` Content Representation

### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| `String` | Familiar; Unicode-correct | Copies on bridging; validation overhead; not what lexers want |
| `[UInt8]` | Direct UTF-8 bytes; zero-copy from `read()`; lexer-friendly | Caller must handle encoding |
| `UnsafeBufferPointer<UInt8>` | Zero-copy; minimal overhead | Ownership complexity; unsafe |

### Decision

**`[UInt8]`** — raw UTF-8 bytes.

Rationale:
- Lexers and parsers operate on byte streams, not `String`
- `read()` fills a `[UInt8]` directly — no transcoding
- Consistent with the byte-oriented design of source-primitives and text-primitives
- Higher-level `String` views can be constructed on demand by consumers

---

## UTF-8 BOM Handling

Source files may start with a UTF-8 Byte Order Mark: `[0xEF, 0xBB, 0xBF]`.

The loader strips this prefix if present. The BOM has no semantic meaning in UTF-8 and
would confuse byte-offset calculations in the lexer.

---

## Existing Infrastructure Analysis

### Source Primitives (`swift-source-primitives`)

Currently empty (stub only). Depends on `swift-text-primitives` (also empty).
When populated, expected to define:
- `Source` namespace enum
- `Source.Location` (line/column)
- `Source.Range` (span within a file)
- `Source.File.ID` (file identity)

### Relationship to swift-source

swift-source (this package) re-exports `Source_Primitives` and adds I/O:
- `Source.Loader` — POSIX file loading
- `Source.Cache` — path-to-content caching
- `Source.Error` — typed error for I/O failures

The loader is intentionally decoupled from source-primitives types. It takes a path,
returns bytes. Integration with `Source.File.ID` and `Source.Manager` will happen
when source-primitives stabilizes.
