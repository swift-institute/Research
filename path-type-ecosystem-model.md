# Path Type Ecosystem — Top-to-Bottom Model

Pre-Phase-4b reference model for the path types that span swift-primitives (L1), swift-iso-9945 / swift-windows-standard (L2), and swift-foundations/swift-paths + swift-file-system (L3). Confirmed from source on 2026-04-18.

---

## 1. Overview

Four concrete path types coexist, plus two views, one protocol, one tagged wrapper, one component family, and one typealias chain. The L1 primitive (`Path_Primitives.Path`) owns a NUL-terminated allocation and is `~Copyable`. L2 attaches platform-specific decomposition via retroactive `Path.Protocol` conformance on `Path.View` (POSIX done; Windows absent). L3 (`Paths.Path`) owns a separate `[Char]` buffer, is `Copyable/Sendable/Hashable`, and currently reimplements decomposition through `Swift.String` round-trips — the target of Phase 4b.

```
L3 FOUNDATIONS
  ┌──────────────────────────────────────────────────────────────┐
  │ swift-file-system / File System Core                         │
  │   File.Path            typealias = Paths.Path                │
  │   File.Path.Component  typealias = Paths.Path.Component      │
  │   File.Path.Property<Value>   (modifier witness)             │
  ├──────────────────────────────────────────────────────────────┤
  │ swift-paths / Paths                                          │
  │   Paths.Path                     struct, Copyable, Sendable  │
  │     ._storage.buffer : [Char]    NUL-terminated              │
  │   Paths.Path.View                ~Copyable, ~Escapable       │
  │   Paths.Path.Storage             internal struct             │
  │   Paths.Path.Component           struct, Copyable            │
  │   Paths.Path.Component.Extension struct                      │
  │   Paths.Path.Component.Stem      struct                      │
  └──────────────────────────────────────────────────────────────┘
                          ↑ bridge via `.kernelPath`
L2 STANDARDS
  ┌──────────────────────────────────────────────────────────────┐
  │ swift-iso-9945 (POSIX)                                       │
  │   Path.View : @retroactive Path.Protocol   (separator 0x2F)  │
  │   ISO_9945.Kernel.Path.Canonical  (realpath(3))              │
  │ swift-windows-standard (Windows)                             │
  │   Windows.Kernel.Path.Canonical   (GetFullPathNameW)         │
  │   — NO Path.Protocol conformance exists (Phase 4a pending)   │
  └──────────────────────────────────────────────────────────────┘
                          ↑ retroactive on L1 type
L1 PRIMITIVES
  ┌──────────────────────────────────────────────────────────────┐
  │ swift-kernel-primitives / Kernel Path Primitives             │
  │   Kernel.Path           typealias = Tagged<Kernel, Path>     │
  │   Kernel.Path.View      = Tagged<…>.View = Path.View         │
  │                           (via Tagged: Viewable)             │
  ├──────────────────────────────────────────────────────────────┤
  │ swift-path-primitives / Path Primitives                      │
  │   Path_Primitives.Path                ~Copyable, Sendable    │
  │     ._storage: Memory.Contiguous<Char> (NUL-terminated)      │
  │   Path_Primitives.Path.View           ~Copyable, ~Escapable  │
  │   Path_Primitives.Path.Protocol       (Phase 4a; static reqs)│
  │   Path.Char                 = String_Primitives.String.Char  │
  │   Path.String, Path.String.Scope, Path.String.Error<Body>    │
  │   Path.Resolution (namespace), Path.Resolution.Error         │
  │   Path.Canonical  (namespace only)                           │
  │   Path.ConversionError                                       │
  │ swift-kernel-primitives / Kernel System Primitives           │
  │   Kernel.System.Path (namespace for .Length = Tagged<…>)     │
  └──────────────────────────────────────────────────────────────┘
```

---

## 2. Type Reference Table

| # | Qualified Name | Layer | Source | Storage | Own. | NUL-term? | Copyable | Escapable | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `Path_Primitives.Path` | L1 | `swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.swift:45` | `Memory.Contiguous<Char>` (heap, adopts raw buffer) | owned value | yes, excluded from `count` | `~Copyable` | Escapable (default) | `@unsafe @unchecked Sendable`. Public API: `init(adopting:count:)`, `init(copying: String.View)`, `init(_ span: Span<Char>)`, `count`, `bytes: Span<Char>`, `view: View`, `take()`. |
| 2 | `Path_Primitives.Path.View` | L1 | `swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.View.swift:35` | `UnsafePointer<Char>` + `count: Int` | borrowed view | yes, excluded from `count` | `~Copyable` | `~Escapable` | `@safe`. API: `pointer`, `count`, `init(_:count:)`, `withUnsafePointer(_:)`, `span: Span<Char>`. Debug-validated NUL in DEBUG only. |
| 3 | `Path_Primitives.Path.Protocol` | L1 | `swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.Protocol.swift:50` | n/a | protocol | — | `~Copyable, ~Escapable` | `~Escapable` | Static requirements: `parent(of:) -> Span<Char>?`, `component(of:) -> Span<Char>`, `appending(_:_:) -> Path`. Protocol-ext instance defaults: `parent`, `component`, `appending(_:)`. |
| 4 | `Path_Primitives.Path.Char` | L1 | same, line 59 | typealias | — | — | — | — | `= String_Primitives.String.Char` → `UInt8` POSIX, `UInt16` Windows. |
| 5 | `Path_Primitives.Path.ConversionError` | L1 | `Path.swift:157` | enum | — | — | `Sendable, Equatable` | — | Single case: `.interiorNUL`. |
| 6 | `Path_Primitives.Path.String.Scope` | L1 | `Path.String.swift:119` | struct | value | — | Copyable | Escapable | `callAsFunction(_ string:_ body:)` overloads: 1/2/3 path, throwing/non-throwing; plus `.array(_:_:)` for `UnsafePointer<UnsafePointer<Char>?>`. |
| 7 | `Path_Primitives.Path.String.Error<Body>` | L1 | `Path.String.swift:43` | enum | — | — | `Sendable where Body: Sendable` | — | `.conversion(Conversion.Error)` / `.body(Body)`. |
| 8 | `Path_Primitives.Path.Resolution.Error` | L1 | `Path.Resolution.Error.swift:16` | enum | — | — | `Sendable, Equatable, Hashable` | — | 8 cases: notFound, exists, isDirectory, notDirectory, notEmpty, loop, crossDevice, nameTooLong. |
| 9 | `Kernel.Path` | L2-leaning L1 | `swift-primitives/swift-kernel-primitives/Sources/Kernel Path Primitives/Kernel.Path.swift:36` | typealias → `Tagged<Kernel, Path_Primitives.Path>` | owned (tagged) | yes | `~Copyable` (via RawValue) | Escapable | Zero-cost phantom wrapper. All Path methods forwarded via `Tagged+Path.swift`. |
| 10 | `Kernel.Path.View` | L2-leaning L1 | resolves via `Tagged: Viewable` — `swift-primitives/swift-identity-primitives/Sources/Identity Primitives/Tagged+Viewable.swift:20` | `= Path.View` | borrowed | yes | `~Copyable` | `~Escapable` | **Type identity preserved**: `Kernel.Path.View` IS `Path_Primitives.Path.View`, not a wrapper. |
| 11 | `Kernel.System.Path` (namespace) | L1 | `swift-primitives/swift-kernel-primitives/Sources/Kernel System Primitives/Kernel.System.Path.swift:17` | enum namespace only | — | — | — | — | Nests `Length = Tagged<Kernel.System.Path, Cardinal>`. Unrelated to `Kernel.Path`. Shared `Path` ident at a different scope. |
| 12 | POSIX: `Path.View : @retroactive Path.Protocol` | L2 | `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Path.View+Path.Protocol.swift:20` | — | — | — | — | — | Separator hard-coded `0x2F`. `parent` returns sub-span up to last `/` (returns `nil` for `/` root or no-separator case; returns the 1-byte "/" when separator at index 0 with content after). `component` returns from last `/+1` to end (full view if no separator). `appending` inserts a single `/` (dedupes trailing). |
| 13 | Windows: `Path.View : Path.Protocol` | **absent** | — | — | — | — | — | — | **Phase 4a Windows NOT DONE.** No file `Windows.Kernel.Path.View+Path.Protocol.swift` exists in swift-windows-standard. |
| 14 | `ISO_9945.Kernel.Path.Canonical` (namespace fns) | L2 | `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Path.Canonical.swift:25` | — | — | — | — | — | `withCanonicalBytes(_:_:)`, `withCanonical(_:_:)`, `canonicalize(_:) -> Kernel.String`. Uses `realpath(3)`. |
| 15 | `Windows.Kernel.Path.Canonical` | L2 | `swift-microsoft/swift-windows-standard/Sources/Windows Kernel File Standard/Windows.Kernel.Path.Canonical.swift:17` | — | — | — | — | — | `resolve(path:into:)`, `resolve(unsafePath:into:)` using `GetFullPathNameW`. |
| 16 | `Paths.Path` | L3 | `swift-foundations/swift-paths/Sources/Paths/Path.swift:37` | `_storage: Storage` holding `buffer: [Char]` | owned value | **yes** (explicit append of 0) | **Copyable** | Escapable | `Sendable, Hashable`. Validated on construction: non-empty, no control chars (0x00–0x1F, 0x7F), no interior NUL. Public API: `init(_ string:)`, `init(copying bytes: Span<Char>)`, `string: String`, `bytes: Span<Char>` (**includes NUL** per doc), `kernelPath: Kernel.Path.View`, `withCString(_:)`, `view: View`. |
| 17 | `Paths.Path.Char` | L3 | `Path.swift:100` | typealias | — | — | — | — | `= Path_Primitives.Path.Char` → UInt8 POSIX, UInt16 Windows. |
| 18 | `Paths.Path.Storage` | L3 | `Path.swift:119` | `buffer: [Char]` | `@usableFromInline internal` struct | yes | `Copyable, Sendable, Hashable` | Escapable | `count = buffer.count - 1` (excludes NUL). `isEmpty = count == 0`. `init(_ string:) throws(Path.Error)`, `init(buffer:) (unchecked)`. |
| 19 | `Paths.Path.separator` (static let) | L3 | `Path.swift:105/110` | `@usableFromInline internal static let separator: Char` | — | — | — | — | **POSIX**: `0x2F`. **Windows**: `0x5C` (`\`). |
| 20 | `Paths.Path.altSeparator` (static let) | L3 | `Path.swift:107` | `@usableFromInline internal static let altSeparator: Char` | — | — | — | — | **Windows only**: `0x2F`. Does NOT exist on POSIX. |
| 21 | `Paths.Path.View` | L3 | `swift-foundations/swift-paths/Sources/Paths/Path.View.swift:33` | `UnsafePointer<Path.Char>` (no stored count) | borrowed view | yes (assumed) | `~Copyable` | `~Escapable` | **Distinct from L1 `Path.View`**: L3 View does NOT store count — computes via `length` (strlen-style scan). API: `pointer`, `length` (computed), `span`, `spanWithTerminator`, `init(_:)`, `init(borrowing path:)`, `kernelPath: Kernel.Path.View`. |
| 22 | `Paths.Path.Error` | L3 | `Path.Error.swift:16` | enum | — | — | `Sendable, Equatable` | — | `.empty`, `.containsControlCharacters`, `.containsInteriorNUL`. |
| 23 | `Paths.Path.Component` | L3 | `swift-foundations/swift-paths/Sources/Paths/Path.Component.swift:24` | `_storage: Path.Storage` | owned value | yes | `Copyable, Sendable, Hashable` | Escapable | Validated: no `/` (POSIX) or `/`+`\` (Windows), no control chars, non-empty. API: `init(_ string:)`, `string`, `extension`, `stem`. Conforms `Binary.Serializable`. |
| 24 | `Paths.Path.Component.Extension` | L3 | `Path.Component.Extension.swift:26` | `_value: Swift.String` | owned value | — | `Copyable, Sendable, Hashable` | Escapable | Forbids dots and separators. `ExpressibleByStringLiteral`. |
| 25 | `Paths.Path.Component.Stem` | L3 | `Path.Component.Stem.swift:27` | `_value: Swift.String` | owned value | — | `Copyable, Sendable, Hashable` | Escapable | Allows interior dots (e.g. `archive.tar`). |
| 26 | `Paths.Path.Component.Error` | L3 | `Path.Component.Error.swift:16` | enum | — | — | `Sendable, Equatable` | — | `.empty`, `.containsPathSeparator`, `.containsControlCharacters`, `.containsInteriorNUL`, `.invalidUTF8`. |
| 27 | `File.Path` | L3 | `swift-foundations/swift-file-system/Sources/File System Core/File.Path.swift:28` | typealias = `Paths.Path` | — | — | — | — | Adds `package init(__unchecked:)`, `parentOrSelf`. POSIX-only `internal init(cString:)`. |
| 28 | `File.Path.Component` | L3 | `swift-foundations/swift-file-system/Sources/File System Core/File.Path.Component.swift:19` | typealias = `Paths.Path.Component` | — | — | — | — | POSIX-only `init(utf8:)` from `Sequence<UInt8>` and `UnsafeBufferPointer<UInt8>`. |
| 29 | `File.Path.Property<Value>` | L3 | `swift-foundations/swift-file-system/Sources/File System/File.Path.Property.swift:20` | struct holding two `@Sendable` closures | value | — | `Sendable` | Escapable | Witness for `path.with(.extension, …)` / `path.removing(.lastComponent)`. Built-ins: `.extension`, `.lastComponent`. |

### Storage invariants summary

| Type | Allocation | NUL terminator? | Count excludes NUL? | Owner |
|---|---|---|---|---|
| `Path_Primitives.Path` | single heap block via `Memory.Contiguous` | **yes** (required; precondition in adopting init) | **yes** (`count = storage.count`, NUL not counted) | value (consumed on destruction) |
| `Paths.Path` | `[Char]` via `Array` | **yes** (explicit `buffer.append(0)`) | **yes** (`Storage.count = buffer.count - 1`) | value (Copyable, Hashable) |
| `Paths.Path.bytes` span | `_storage.buffer.span` | **INCLUDES NUL** per `Path.swift:277` doc + implementation | n/a | borrowed |
| `Paths.Path.View` | pointer to existing path's buffer | yes (assumed invariant; no stored count) | — | borrowed (`~Escapable`) |
| `Path_Primitives.Path.View.span` | pointer+count | — | **yes** (`count` excludes NUL) | borrowed |

**Asymmetry flag (M1)**: `Path_Primitives.Path.bytes` returns `Span<Char>` of the **content only** (via `_storage.span`, which uses `_storage.count` excluding NUL). `Paths.Path.bytes` returns `Span<Char>` of the **full `[Char]` including NUL**. This is an inconsistency across layers; downstream consumers of `.bytes` must know which convention applies. See divergence flag §6/D1.

### Separator sourcing summary

| Type | `/` | `\` | Source |
|---|---|---|---|
| L1 `Path.Protocol` | requirements agnostic to separator | agnostic | Conformance chooses |
| L2 POSIX `Path.View+Path.Protocol` | **hard-coded `0x2F`** at lines 28, 48, 81 | — | Literal magic number in conformance |
| L2 Windows `Path.View+Path.Protocol` | — | — | **does not exist** |
| L3 `Paths.Path.separator` | `0x2F` (POSIX) | `0x5C` (Windows) | `#if os(Windows)` + `static let` |
| L3 `Paths.Path.altSeparator` | `0x2F` (Windows) | — | Windows-only `static let` |
| L3 `Paths.Path.Navigation` | **String-level `/` and `"\\"` literals** | `"\\"` | `#if os(Windows)`, no reference to `Self.separator` |
| L3 `Paths.Path.Component` validator | rejects `/` (POSIX) | rejects both `/` and `\` (Windows) | `UInt8(ascii:)`/`UInt16(ascii:)` |

**Flag (M2)**: L3 `Path.Navigation` does NOT use `Self.separator`/`altSeparator`. It operates on `Swift.String` and uses literal characters. Phase 4b must either (a) rescan `_storage.buffer` using the `static let separator`, or (b) introduce byte-level equivalents for Windows alt-separator handling.

---

## 3. Conversion Graph

```
                    ┌─────────────────┐
                    │ Swift.String    │
                    └───┬──────────┬──┘
                        │          │
        validate+copy   │          │ validate+copy
        alloc           ▼          ▼ alloc
               ┌─────────────┐   ┌──────────────┐
               │ Paths.Path  │   │ Path_Prim.   │
               │   (L3)      │   │   .Path (L1) │
               └──┬─┬─┬─┬────┘   └──┬──┬───┬────┘
       .string    │ │ │ │           │  │   │
       (decode)  ─┘ │ │ │  .bytes   │  │   │  .view
       .bytes ─────-┘ │ │  (Span<Char>  │   │  (Path.View,
       (Span, +NUL)   │ │ excl NUL)────┘   │  ~Escapable)
       .view ─────────┘ │                   │
       (L3 View)        │.kernelPath        │
                        │(= Kernel.Path.View│
                        │ = L1 Path.View)   │
                        ▼                   │
               ┌──────────────────┐         │
               │ Kernel.Path.View │◄────────┘
               │ = Path_Prim.     │
               │   .Path.View (L1)│
               └──┬───────────────┘
         static   │ L1 protocol entry points (L2 POSIX conformance)
         requires │   parent(of:) → Span<Char>?
         @_life-  │   component(of:) → Span<Char>
         time     │   appending(_:_:) → Path_Primitives.Path
                  ▼
             ┌──────────────────┐
             │ Path_Primitives. │  (owned, 1 alloc, NUL-terminated)
             │   .Path          │
             └──────────────────┘
```

### Edge list (public, verified)

| # | From | To | Mechanism | Alloc? | Layer | Source |
|---|---|---|---|---|---|---|
| E1 | `Swift.String` | `Paths.Path` | `init(_ string:) throws(Error)` | yes (`[Char]` copy, UTF-8/16 validate) | L3 | `Path.swift:47` |
| E2 | `Swift.String` | `Path_Primitives.Path` | `Path.scope(_ string:_ body:)` (closure) | yes, scoped | L1 | `Path.String.swift:140` |
| E3 | `Span<Char>` | `Path_Primitives.Path` | `init(_ span:)` | yes (1 alloc, +NUL) | L1 | `Path.swift:107` |
| E4 | `String_Primitives.String.View` | `Path_Primitives.Path` | `init(copying:)` | yes | L1 | `Path.swift:89` |
| E5 | `UnsafeMutablePointer<Char>` + count | `Path_Primitives.Path` | `init(adopting:count:)` | adopts | L1 | `Path.swift:76` |
| E6 | `Span<Char>` | `Paths.Path` | `init(copying bytes:) throws(Error)` | yes (validate + copy + NUL) | L3 | `Path.swift:58` |
| E7 | `Paths.Path` | `Swift.String` | `.string` (property) | yes (decode UTF) | L3 | `Path.swift:199` |
| E8 | `Paths.Path` | `Span<Char>` (incl NUL) | `.bytes` | no (borrow) | L3 | `Path.swift:287` |
| E9 | `Paths.Path` | `Paths.Path.View` | `.view` | no (borrow) | L3 | `Path.View.swift:118` |
| E10 | `Paths.Path` | `Kernel.Path.View` (= L1 View) | `.kernelPath` | no (borrow; shared UTF-8 on POSIX) | L3 | `Path.swift:247` |
| E11 | `Paths.Path.View` | `Kernel.Path.View` | `.kernelPath` | no | L3 | `Path.View.swift:132` |
| E12 | `Paths.Path` | `UnsafePointer<Char>` | `.withCString(_:)` (scoped) | no, scoped | L3 | `Path.swift:228` |
| E13 | `Path_Primitives.Path` | `Span<Char>` (excl NUL) | `.bytes` | no | L1 | `Path.swift:131` |
| E14 | `Path_Primitives.Path` | `Path_Primitives.Path.View` | `.view` | no | L1 | `Path.View.swift:113` |
| E15 | `Path_Primitives.Path.View` | `Span<Char>` (excl NUL) | `.span` | no | L1 | `Path.View.swift:98` |
| E16 | `Path_Primitives.Path` | raw pointer + count | `take()` (consuming) | no | L1 | `Path.swift:148` |
| E17 | `Path_Primitives.Path.View` | parent span | via `Path.Protocol` | no (sub-view) | L2 POSIX | `ISO 9945.Kernel.Path.View+Path.Protocol.swift:25` |
| E18 | `Path_Primitives.Path.View` | component span | via `Path.Protocol` | no (sub-view) | L2 POSIX | same file:45 |
| E19 | two `Path.View` | owned `Path_Primitives.Path` | `Path.Protocol.appending` | yes (1 alloc) | L2 POSIX | same file:65 |
| E20 | `Path_Primitives.Path` via realpath(3) | `Kernel.String` (bytes buffer from libc) | `Canonical.canonicalize(_:)` | yes (libc free'd) | L2 POSIX | `ISO 9945.Kernel.Path.Canonical.swift:127` |
| E21 | `UnsafePointer<CChar>` (POSIX) | `File.Path` | `init(cString:)` internal, goes through `Swift.String` | yes | L3 | `File.Path.swift:71` |
| E22 | `UnsafeBufferPointer<UInt8>` | `File.Path.Component` | `init(utf8:)` (POSIX) | yes | L3 | `File.Path.Component.swift:66` |
| E23 | `Swift.String` literal | `Paths.Path` | `ExpressibleByStringLiteral` (fatalError on invalid) | yes | L3 | `Path.Operators.swift:60` |
| E24 | `Paths.Path` | `File.Path` | typealias — identity | — | L3 | `File.Path.swift:28` |
| E25 | `Paths.Path.Component` | `File.Path.Component` | typealias — identity | — | L3 | `File.Path.Component.swift:19` |

### Conversion asymmetries

- `Paths.Path` ↔ `Path_Primitives.Path`: **no direct bridge**. Round-trip requires Path_Primitives.Path `init(_ span:)` + `Paths.Path.init(copying:)`; both allocate. There is no zero-copy bridge L3↔L1 because storage types differ (`Memory.Contiguous<Char>` vs `[Char]`).
- The **view layer bridges zero-alloc**: `Paths.Path.kernelPath` hands out an `UnsafePointer<Char>` + `length` as a `Kernel.Path.View` (= L1 `Path.View`) without copying. This is the intended Phase 4b anchor: scan `_storage.buffer` directly (or go via `view.kernelPath` into L1 protocol methods).

---

## 4. Phase 4a Boundary Summary

### Protocol location and shape

- **Declared**: `/Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.Protocol.swift:50` — nested as `Path.Protocol` (backtick-escaped keyword).
- **Requirements (static)**:
  - `static func parent(of view: borrowing Self) -> Span<Char>?` with `@_lifetime(copy view)` (line 64-65)
  - `static func component(of view: borrowing Self) -> Span<Char>` with `@_lifetime(copy view)` (line 74-75)
  - `static func appending(_ view: borrowing Self, _ other: borrowing Self) -> Path` (line 81)
- **Instance defaults** (protocol extension, `where Self: ~Copyable, Self: ~Escapable`):
  - `var parent: Span<Char>?` with `@_lifetime(copy self)` (line 92)
  - `var component: Span<Char>` with `@_lifetime(copy self)` (line 101)
  - `borrowing func appending(_ other: borrowing Self) -> Path` (line 110)
- **Null-termination doctrine** (from doc comment at line 38-49): `parent` span is NOT NUL-terminated (separator at boundary excluded, so caller must `Path(span)` if syscall use); `component` span IS NUL-terminated (shares the original path's terminator byte).

### Conformers

| Conformer | Location | Status |
|---|---|---|
| `Path_Primitives.Path.View` via POSIX retroactive | `/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Path.View+Path.Protocol.swift:20` (`extension Path.View: @retroactive Path.Protocol`) | **DONE** (commit `a90491b`, 2026-04-07) |
| `Path_Primitives.Path.View` via Windows retroactive | (not present) | **MISSING — Phase 4a Windows pending** |
| `Paths.Path` (L3) | — | **Does NOT conform.** No `extension Paths.Path: Path.Protocol` anywhere in swift-paths. |
| `Paths.Path.View` (L3) | — | **Does NOT conform.** L3 `Path.View` has its own `pointer` + `length`-computed API, incompatible shape with the protocol. |

### Why `Paths.Path` does not conform (hypothesis confirmed in source)

1. **swift-paths depends on**: `swift-kernel-primitives` (Kernel Path Primitives) and `swift-binary-primitives` only (Package.swift:17-20). It does NOT depend on `swift-iso-9945`.
2. The **retroactive POSIX conformance of `Path.View: Path.Protocol` lives in swift-iso-9945**. Because of Swift's module-scoped retroactive-conformance visibility (and the `@retroactive` attribute that demands it), swift-paths cannot observe that `Path.View` conforms.
3. Even if swift-paths added the L2 dep (L3→L2 is legal per five-layer architecture), adding `extension Paths.Path: Path.Protocol` would be a second, separate conformance — and `Paths.Path` is Copyable, Escapable, so it could not satisfy the protocol (which requires `Self: ~Copyable, ~Escapable` for the instance defaults to type-check under `@_lifetime(copy self)`).
4. The intended Phase 4b path: **keep `Paths.Path` non-conforming; route L3 navigation through `Paths.Path.kernelPath` (which IS L1 `Path.View`) and call the L1 `Path.Protocol` members on that view**. swift-paths already depends on Kernel Path Primitives, and the POSIX conformance ships via it transitively — **but only if swift-paths also imports the conformance-providing module**. This is the subtle visibility issue Phase 4b must resolve; see Open Question §7/Q1.

### What the handoff says about Phase 4b constraints

From `/Users/coen/Developer/HANDOFF-path-decomposition.md` line 74:
- Migrate `parent`, `lastComponent`, `appending` to delegate to `Path.View.parent` / `.component` / `.appending`.
- Migration should be incremental; existing tests must keep passing.
- Note `lastComponent` is compound — [API-NAME-002] flag pending.

---

## 5. Phase 4b Input Surface — Method-by-Method

The four target methods all live in `/Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.Navigation.swift`. Verified against source.

### 5.1 `var parent: Path?` — lines 78-117

**Current implementation (POSIX branch)** `let s = string → s.lastIndex(of: "/") → Swift.String(s[..<lastSep]) → try? Path.init(parentStr)`.

**Allocation profile (POSIX)**:
1. `string` property → 1 decode (creates `Swift.String` from `buffer.dropLast()` via `String(decoding:as:)`) — allocates UTF-8 string object.
2. `Swift.String(s[..<lastSep])` → 1 string copy.
3. `Path.init(parentStr)` → full re-validation, 1 more `[Char]` allocation.
4. For root-reconstruction path (`Path.init("/")`) → additional allocation.
**Total POSIX parent(): 3 allocations in the common case.**

**Allocation profile (Windows)**:
1. `string` → 1 decode (UTF-16).
2. `s[..<lastSep]` → 1 copy.
3. For drive-letter path, `Swift.String(beforeSep) + "\\"` → 1 concatenation.
4. `Path.init(parentStr)` → 1 validation + `[Char]` allocation.
**Total Windows parent(): 3-4 allocations.**

**Semantics / edge cases**:
- POSIX: no `/` → `nil`. Separator at start AND `count == 1` (just `/`) → `nil`. Separator at start with more content (e.g. `/foo`) → returns `Path("/")`. Empty parent string (e.g. `foo/`) → returns `Path("/")`.
- Windows: drive letter detection `beforeSep.count == 2 && beforeSep.last == ":"` → returns `drive + "\\"` (e.g. `C:\Users` parent → `C:\`). UNC: `lastSep == startIndex` → `nil` (ambiguous; see divergence D2).

### 5.2 `func appending(_ component: Component) -> Path` — lines 131-146

**Current implementation**: `let s = string → hasSuffix("/") check → s + "/" + component.string → try? Path.init(newPath)`.

**Allocation profile (POSIX)**: `string` decode (1) + `+` concatenation (1, may be 2 if separator inserted) + `Path.init` buffer (1) = **2-3 allocations**.
**Allocation profile (Windows)**: same count, plus double-separator-check (`hasSuffix("/") || hasSuffix("\\")`).

**Semantics / edge cases**:
- Empty path (`s.isEmpty`) → `needsSep = false` → result is just `component.string` — this bypasses the empty-path invariant that `Paths.Path.init(_ string:)` would reject. However `appending` on an empty path is unreachable: `Paths.Path` rejects empty strings at construction, so `self` is never empty at call time. Still, the branch exists.
- Trailing separator on `self` → skip inserting a new one (POSIX: just `/`; Windows: either `/` or `\\`).
- Fallback `?? self` on construction failure (component already validated, so in practice unreachable).

### 5.3 `func appending(_ string: Swift.String) throws(Component.Error) -> Path` — lines 158-161

Trivial: `let c = try Component(string); return appending(c)`. One `Component` allocation + whatever `appending(Component)` does. **3-4 allocations total**. No byte-level work to do; Phase 4b can leave the delegation OR inline the validation.

### 5.4 `func appending(_ other: Path) -> Path` — lines 175-192

**Current implementation**: check `other.isAbsolute` → if so return `other`. Otherwise: `string + separator + other.string → Path.init(newPath)`.

**Allocation profile (POSIX)**: `self.string` (1) + `other.string` (1) + concat (1) + `Path.init` (1) = **4 allocations**. Windows same plus `.hasSuffix("\\")` check.

**Semantics / edge cases**:
- `other.isAbsolute` short-circuits (`other` returned as-is, Copyable so cheap).
- Empty `s` branch unreachable (see 5.2).
- `isAbsolute` itself (see `Path.Introspection.swift:28`) allocates via `string` AND scans for drive letters / UNC on Windows.

### Ancillary navigation members (not on the Phase 4b list, for context)

- `var components: [Component]` (lines 29-48) — allocates the `String`, splits via `Collection.split`, creates `Component` per part.
- `var lastComponent: Component?` (lines 62-64) — delegates to `components.last`. This calls **the whole O(n) components generator** just to grab the tail.
- `func hasPrefix(_ other: Path) -> Bool` (lines 206-221) — both `.components` arrays allocated then compared.
- `func relative(to base: Path) -> Path?` (lines 234-256) — components × 2 + `map(\.string).joined()` + `Path.init`.

### Constructor Phase 4b will use

Per handoff line 19, `Paths.Path` has `Storage.init(buffer: [Char])` (non-throwing) — `Path.swift:173-176`. Together with `init(storage:)` (`Path.swift:84-87`, `@usableFromInline internal`), this is the chosen entry point for byte-level construction without re-validation. Phase 4b calls will look like:

```swift
// scan _storage.buffer, find lastSep, build new [Char] with NUL,
let newBuffer: [Char] = …
return Path(storage: Storage(buffer: newBuffer))
```

---

## 6. Divergence Flags — Byte-vs-String Semantic Differences

Each flag below is a **candidate risk**: a place where naive byte scanning (replacing `Swift.String`) could produce a different answer than the current implementation. Listed in order of stakes.

### D1 — `bytes` convention inconsistency (**highest stakes**)

- `Paths.Path.bytes` (L3) returns `_storage.buffer.span` → **includes the NUL terminator**. Documented at `Path.swift:277`.
- `Path_Primitives.Path.bytes` (L1) returns `_storage.span` → **excludes NUL** (since `Memory.Contiguous.count` excludes it).
- `Path_Primitives.Path.View.span` (L1) excludes NUL (uses the stored `count`).

If Phase 4b byte-scans using `_storage.buffer`, the implementer must **remember to scan only `buffer[0..<count]` = `buffer[0..<buffer.count-1]`** to skip the trailing `0`. Otherwise `lastSep` of the NUL byte (which is not 0x2F, so fine) is a non-issue, but iteration length matters for correctness of `count` in the resulting path. **Escalate to user if unclear which convention downstream code expects.**

### D2 — Windows UNC parent semantics

`Path.Introspection.swift:34` treats `//server/…` (forward slashes) AND `\\server\…` (backslashes) as absolute UNC. But `Path.Navigation.swift:83-101` `parent` logic does not special-case UNC — it only special-cases drive letters (`X:\`). So for input `\\server\share\dir`:

- Current String-based `parent`: `lastIndex(where: { $0 == "/" || $0 == "\\" })` finds the `\` before `dir` → returns `Path("\\server\share")`. Then parent of **that** is `\\server` (which is `lastSep == startIndex` branch → returns `nil`).
- A byte-scan fix should replicate this exactly. In particular: the `lastSep == s.startIndex → nil` clause is the only barrier preventing us from returning `\\` alone, which would be invalid (fails `Path.init`).

**Risk**: Any byte-level rewrite must reproduce the "separator-at-start → nil" semantics on Windows, AND must decide whether to treat UNC-double-separator (`\\server`) as a unit. Current code does not — the implementer must verify whether that's intentional or latent.

### D3 — Windows drive-letter reconstruction

`Path.Navigation.swift:93-97` reconstructs `C:\` by taking `beforeSep` (the 2-char `C:`) and appending `\`. A byte-scan equivalent must hard-code `Self.separator` (0x5C) here, since the input might have used `/` but the output canonicalizes to `\`. Current implementation: **normalizes** to backslash. Byte-scan risk: accidentally preserving the original `/`.

### D4 — String splitting with `omittingEmptySubsequences: true`

`var components` uses `s.split(separator: "/", omittingEmptySubsequences: true)` (POSIX) and `s.split(omittingEmptySubsequences: true) { char in char == "/" || char == "\\" }` (Windows). The "omitting empty" collapses runs (`//a` → `["a"]`, not `["", "a"]`). A byte-scan re-implementation must either mirror this or accept a known divergence (noting that `lastComponent` depends on it: for `/` (root), components = [], lastComponent = nil — required).

### D5 — `ExpressibleByStringLiteral` path on concat-failure

`Path.Navigation.swift:145,191` swallow construction failure via `?? self`. If the concatenated string contains control chars (e.g., `path + "\u{01}"` if `other` somehow contains one — but validators should prevent this), the current code silently returns `self`. Byte-scan rewrite has two choices: preserve this swallow, or make the internal API non-throwing because bytes are already valid. The latter is cleaner; the former preserves surface compatibility.

### D6 — `hasSuffix("/")` on Unicode strings vs byte scan

`s.hasSuffix("/")` on a `Swift.String` is Unicode-aware. The current implementation treats this as byte-equivalent because paths are validated to be UTF-8/UTF-16 and `/` = `0x2F` (POSIX) / `0x002F` (Windows UTF-16) is ASCII-safe. **No divergence risk** — but documenting it here to avoid re-investigation.

### D7 — Empty-path safety

`appending` branches on `!s.isEmpty`. Although `Paths.Path` rejects empty on construction, `Paths.Path.Storage` has an internal unchecked `init(buffer:)` that could hypothetically produce an empty-bytes path. **Risk**: byte-scan rewrite should explicitly reject empty or preserve the existing branch. Recommend: assert `count > 0` and drop the dead branch.

### D8 — Control characters post-construction

`Paths.Path.init(_ string:)` rejects control chars. Byte-scan `appending` DOES NOT re-check control chars — it trusts components and paths both were validated. This is **safe today** because all constructors validate. Any future byte-adopting init that skips validation would break this invariant. Recommend: document `Storage.init(buffer:)`'s trust boundary.

### No hard divergence found

Under current invariants (all paths validated at construction, ASCII-only separators, UTF-8/UTF-16 encoding), a byte-level rewrite **can match Swift.String semantics exactly**. The stakes are reproducing the branching carefully (D2, D3) and settling the `.bytes` convention (D1).

---

## 7. Open Questions / Uncertainties

### Q1 — Will L3 Phase 4b *call* L2 protocol members, or duplicate the logic at L3?

Two paths:
- **(a) Delegate**: `Paths.Path.parent` calls `self.kernelPath.parent` (via `Path.Protocol` instance default). Requires swift-paths to depend on swift-iso-9945 (POSIX) AND a future swift-windows-standard (Windows conformance) — **no Windows conformance exists yet**. So (a) is blocked on Phase 4a Windows.
- **(b) Duplicate**: `Paths.Path` does its own byte scan on `_storage.buffer`, using `Self.separator` / `Self.altSeparator`. No L2 dep required. But the L1 `Path.Protocol` contract (which D1/D2/D3 encode) must be reproduced line-for-line to keep the test surface compatible.

The handoff (line 74) implies (a) via "delegate to `Path.View.parent`". But the L2 conformance is only visible if swift-paths adds the dep — and for Windows, the file doesn't exist yet. **Escalate**: which way does Phase 4b cut?

### Q2 — `component` return type (IMPL-081 deviation)

Handoff open question 1 (line 68): `component` returns `Span<Char>` but [IMPL-081] requires NUL-termination awareness in the return type. Three proposals on the table. Affects whether Phase 4b introduces a new sub-view type or ships with the current deviation.

### Q3 — Windows conformance absence

`Windows.Kernel.Path.View+Path.Protocol.swift` does NOT exist. Phase 4a Windows was explicitly queued (handoff line 77). Phase 4b on Windows is blocked unless (b) duplicate-at-L3 is chosen, OR Phase 4a Windows lands first.

### Q4 — `.bytes` convention

`Paths.Path.bytes` includes NUL; `Path_Primitives.Path.bytes` does not (D1). Which one do file-system syscall consumers (`Kernel.File.Stats.get(path:)` etc.) actually want? The L3 doc comment at `Path.swift:283-285` says "Kernel APIs that expect NUL-terminated paths". Syscalls need a `char*` that IS NUL-terminated, but the `count`/`Span` representation — excluding vs including NUL — depends on the callee. Needs cross-check before Phase 4b consumers multiply.

### Q5 — `lastComponent` naming

[API-NAME-002] compound-identifier violation (handoff line 74). `Paths.Path.lastComponent`, `Paths.Path.Component` accessor. Rename to `path.component.last` nested accessor? Separate clean-up from Phase 4b core — but touches the same file.

### Q6 — `Kernel.System.Path` identifier collision

`Kernel.System.Path` (L1, `Kernel System Primitives`) is a namespace that hosts `Length`. Meanwhile `Kernel.Path` (L1, `Kernel Path Primitives`) is a typealias to `Tagged<Kernel, Path>`. Both share the `Path` identifier under different parent namespaces. Not a divergence risk, but a readability concern when both modules are imported.

### Q7 — `Paths.Path.View` vs `Path_Primitives.Path.View` — are they different types?

**Yes, different types.** L3 `Paths.Path.View` has `pointer` only (no stored count; `length` is a scan). L1 `Path.View` has `pointer` + `count`. The bridge is `Paths.Path.View.kernelPath` which constructs an L1 `Path.View` using the scanned length. This is a real cost: every `kernelPath` call on an L3 view walks the bytes to find the NUL. L3 `Path` with stored count avoids this. **Implication for Phase 4b**: if navigation goes through `self.view.kernelPath`, you pay an O(n) strlen per call; prefer `self.kernelPath` directly from `Paths.Path` (`Path.swift:247`) which uses the pre-stored `buffer.count - 1`.

---

## Appendix A — Canonical file paths for agents

```
L1 primitive:
  /Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.swift
  /Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.View.swift
  /Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.Protocol.swift
  /Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.String.swift
  /Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.Resolution.Error.swift
  /Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.Canonical.swift
  /Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/Tagged+Path.swift

L1 tagged:
  /Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Path Primitives/Kernel.Path.swift
  /Users/coen/Developer/swift-primitives/swift-identity-primitives/Sources/Identity Primitives/Tagged+Viewable.swift

L2 POSIX conformance:
  /Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Path.View+Path.Protocol.swift
  /Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Path.Canonical.swift

L2 Windows (Path.Protocol missing):
  /Users/coen/Developer/swift-microsoft/swift-windows-standard/Sources/Windows Kernel File Standard/Windows.Kernel.Path.Canonical.swift

L3 paths:
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.View.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.Component.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.Component.Extension.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.Component.Stem.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.Navigation.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.Introspection.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.Operators.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.Binary.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Sources/Paths/Path.Error.swift
  /Users/coen/Developer/swift-foundations/swift-paths/Package.swift

L3 file-system typealiases:
  /Users/coen/Developer/swift-foundations/swift-file-system/Sources/File System Core/File.Path.swift
  /Users/coen/Developer/swift-foundations/swift-file-system/Sources/File System Core/File.Path.Component.swift
  /Users/coen/Developer/swift-foundations/swift-file-system/Sources/File System/File.Path.Property.swift
```

## Appendix B — Phase 4a evidence

- swift-path-primitives commit `a96dddf`: "Add Path.Protocol decomposition API [IMPL-023] [IMPL-081]"
- swift-iso-9945 commit `a90491b`: "Add POSIX Path.Protocol conformance on Path.View [API-IMPL-007]"
- HANDOFF: `/Users/coen/Developer/HANDOFF-path-decomposition.md`
- Ecosystem audit: `/Users/coen/Developer/swift-institute/Audits/audit.md` lines 914-915, 1066, 1073.
- Confirmed: **no Windows Path.Protocol file** (`Grep 'Path\.`?Protocol`?' swift-microsoft/swift-windows-standard` — zero matches).

---

*Model complete. Verified by reading each cited source file. No code changes made; no builds run.*
