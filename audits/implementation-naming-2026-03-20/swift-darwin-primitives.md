# swift-darwin-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (Opus 4.6)
**Scope**: All 23 `.swift` files in `Sources/`
**Skills**: naming, implementation

## Summary

| Severity | Count |
|----------|-------|
| HIGH     | 2     |
| MEDIUM   | 6     |
| LOW      | 7     |
| OK       | —     |
| **Total**| **15**|

The package is well-structured overall. Namespace nesting follows [API-NAME-001] correctly (`Darwin.Kernel.Kqueue.Event.Data`, `Darwin.Loader.Image.Header`, etc.). The `.rawValue` usage is largely confined to boundary code (C struct conversion, syscall interfaces), which is appropriate for a kernel-wrapping primitives package. The main issues are compound property names, one file violating one-type-per-file, and some `.rawValue` usage that leaks into combining operators.

## Findings

### HIGH

#### [DAR-001] One-type-per-file violation in `Darwin.Identity.UUID.swift` — [API-IMPL-005]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Identity.UUID.swift`
**Lines**: 8–11 (enum Identity), 13–16 (enum UUID), 18+ (UUID extensions)

This file declares two namespace types (`Darwin.Identity` and `Darwin.Identity.UUID`) plus all UUID methods. Per [API-IMPL-005], `Darwin.Identity` should be in its own file `Darwin.Identity.swift`, and `Darwin.Identity.UUID` in `Darwin.Identity.UUID.swift`.

#### [DAR-002] One-type-per-file violation in `Darwin.File.Stats.swift` — [API-IMPL-005]

**File**: `Sources/Darwin Kernel Primitives/Darwin.File.Stats.swift`
**Lines**: 222–236 (`Kernel.File.Stats.Error` extension with `init(_posixErrno:)`), 240–263 (`Kernel.File.Stats.Kind` extension with `init(_mode:)`)

The `Stats.Error` and `Stats.Kind` extensions add new initializers to types defined in `Kernel_Primitives`. These are cross-module extension conformance helpers. While they serve `Darwin.File.Stats`, they extend foreign types and could live in separate files (`Darwin.File.Stats.Error+Posix.swift`, `Darwin.File.Stats.Kind+Mode.swift`). However, since they are `internal` and tightly coupled to `Stats` construction, this is borderline. Flagged HIGH because the same file contains `Darwin.File.Stats` (the primary type) plus substantive logic for two other types.

### MEDIUM

#### [DAR-003] Compound property name `bytesAllocated` — [API-NAME-002]

**File**: `Sources/Darwin Memory Primitives/Darwin.Memory.Allocation.Statistics.swift`
**Line**: 27

`bytesAllocated` is a compound name. Consider `bytes.allocated` or restructuring with a nested `Bytes` accessor namespace. However, this is a stored property in a plain data struct, so nested accessor syntax may be over-engineered here.

#### [DAR-004] Compound property name `filterData` — [API-NAME-002]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.Kqueue.Event.swift`
**Lines**: 67, 88, 95

`filterData` is a compound property name on `Kernel.Kqueue.Event`. The type is `Filter.Data`, so the property could simply be named `data` on the filter's namespace or accessed via `filter.data`. However, this conflicts with the existing `data` property (user-defined event data) on the same struct. The naming collision is real; `filterData` distinguishes kernel-returned filter data from user-defined event routing data. This is a pragmatic compromise.

#### [DAR-005] Compound property name `isInSharedCache` — [API-NAME-002]

**File**: `Sources/Darwin Loader Primitives/Darwin.Loader.Image.Header.swift`
**Line**: 44

`isInSharedCache` is a compound predicate. Could be `sharedCache.contains(self)` or a nested accessor, but this mirrors Darwin/dyld terminology and is a reasonable spec-mirroring exception per [API-NAME-003].

#### [DAR-006] Compound method name `parseNullSeparatedStrings` — [API-NAME-002]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.File.Attributes.Extended.swift`
**Line**: 327

`parseNullSeparatedStrings` is a private helper with a heavily compound name. Since it is private, the blast radius is contained, but it still violates [API-NAME-002]. Could be restructured as `parse(nullSeparated:count:)`.

#### [DAR-007] Compound parameter name `followSymlinks` — [API-NAME-002]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.File.Attributes.Extended.swift`
**Lines**: 66, 134, 205, 261

`followSymlinks` appears as a parameter in four methods. This mirrors POSIX/Darwin API naming (`XATTR_NOFOLLOW`) and is a reasonable spec-mirroring exception. Alternatively, could use a `Symlink.Resolution` enum or `follow symlinks:` label.

#### [DAR-008] Compound method name `copyAll` — [API-NAME-002]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.File.Attributes.Extended.swift`
**Line**: 297

`copyAll(from:to:)` is a compound method name. Could be `copy.all(from:to:)` with a nested accessor. Since this is a static method on `Extended`, it reads as `Extended.copyAll(from:to:)`, which is acceptable but does violate [API-NAME-002] strictly.

### LOW

#### [DAR-009] `.rawValue` in combining operators — [PATTERN-017]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.Kqueue.Filter.Flags.swift`
**Lines**: 61, 66
**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.Kqueue.Flags.swift`
**Lines**: 142, 147

The `|` operator and `contains(_:)` method use `.rawValue` directly:
```swift
Self(rawValue: lhs.rawValue | rhs.rawValue)
(rawValue & other.rawValue) == other.rawValue
```
These are boundary code (bitwise flag manipulation) and are appropriate for a flag type that wraps raw kernel constants. These types do not conform to `OptionSet` (which would handle this automatically). Acceptable as boundary code per [PATTERN-017].

#### [DAR-010] `.rawValue` in `cValue` conversion — [PATTERN-017]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.Kqueue.Event.swift`
**Lines**: 119–124

The `cValue` computed property accesses `.rawValue` on five fields to convert back to a C `kevent` struct. This is the definition of boundary code — converting from typed Swift domain to C ABI. Correct placement per [PATTERN-017].

#### [DAR-011] `.rawValue` in `UnsafeMutableRawPointer` init — [PATTERN-017]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.Kqueue.Event.Data.swift`
**Line**: 81

`UInt(data.rawValue)` in the `UnsafeMutableRawPointer` extension. This is pointer-boundary code. Correct per [PATTERN-017].

#### [DAR-012] `_rawValue` access on `Kernel.Descriptor` — [PATTERN-017]

**Files**: `Darwin.Kernel.Kqueue.swift` (lines 76, 104, 243), `Darwin.File.Stats.swift` (line 169), `Darwin.Kernel.File.Attributes.Extended.swift` (lines 100, 111, 170, 181, 235, 281)

10 total `_rawValue` accesses on `Kernel.Descriptor` to pass the raw file descriptor to syscalls. All are in syscall-wrapping functions — this is the intended boundary usage. Correct per [PATTERN-017].

#### [DAR-013] `__unchecked` usage in construction from C structs — [IMPL-002]

**Files**: `Darwin.File.Stats.swift` (lines 182–210), `Darwin.Kernel.Kqueue.Event.swift` (lines 107–111), `Darwin.Kernel.Kqueue.Event.Data.swift` (lines 43–89), `Darwin.Kernel.Kqueue.Filter.Data.swift` (line 58)

15 total `__unchecked` usages. All are in boundary code where values come from the kernel (C struct fields, pointer bit patterns) and are known-valid by construction. This is the canonical use case for `__unchecked`. Correct.

#### [DAR-014] `Int(bitPattern:)` in pointer conversion — [IMPL-010]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.Kqueue.Event.Data.swift`
**Lines**: 43, 53, 60, 67

Four uses of `UInt(bitPattern: pointer)` inside `Event.Data` initializers that convert pointers to `UInt64` event data. These are boundary overloads converting between pointer and integer domains. Correct per [IMPL-010].

#### [DAR-015] Compound property names forwarded from `Kernel.File.Stats` — [API-NAME-002]

**File**: `Sources/Darwin Kernel Primitives/Darwin.File.Stats.swift`
**Lines**: 93 (`linkCount`), 97 (`accessTime`), 101 (`modificationTime`), 105 (`changeTime`)

These are convenience accessors that forward to `base.linkCount`, `base.accessTime`, etc. The compound names originate from `Kernel.File.Stats` (defined in `Kernel_Primitives`). Changing them here would create inconsistency with the upstream type. This is inherited naming, not a local design choice.

## Spec-Mirroring Exceptions Applied

The following identifiers mirror Darwin/BSD API names and fall under [API-NAME-003]:

- `isInSharedCache` — mirrors `MH_DYLIB_IN_CACHE` flag semantics
- `followSymlinks` — mirrors `XATTR_NOFOLLOW` semantics
- `filterData` — mirrors `kevent.data` field (filter-specific data)
- Filter/Flag static constants (`.read`, `.write`, `.add`, `.delete`, `.eof`, etc.) — mirror `EVFILT_*` / `EV_*` constants

## Structural Assessment

**Namespace nesting**: Exemplary. All types follow `Nest.Name` pattern:
- `Darwin` > `Kernel` > `Kqueue` > `Event` > `Data`
- `Darwin` > `Loader` > `Image` > `Header`
- `Darwin` > `Memory` > `Allocation` > `Statistics`
- `Darwin` > `File` > `Stats`
- `Darwin` > `Kernel` > `File` > `Attributes` > `Extended`

**File naming**: Consistent. Each file named after its primary type.

**`.rawValue` confinement**: Well-disciplined. All 19 `.rawValue` usages are in boundary code (C struct conversion, flag operations, pointer extraction). No `.rawValue` leaks into call-site logic.

**`__unchecked` confinement**: All 15 uses are in boundary construction from kernel data. Correct.

**Typed throws**: All throwing functions use typed throws (`throws(Error)`, `throws(Kernel.Kqueue.Error)`). Compliant with [API-ERR-001].
