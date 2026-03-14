# String_Primitives.String Shadowing Swift.String

<!--
---
version: 2.0.0
last_updated: 2026-03-14
status: RECOMMENDATION
tier: 2
---
-->

## Context

### Trigger

While adding parallel execution to `swift-dependency-analysis` using `IO.Blocking.Threads` from `swift-io`, we discovered that `import IO_Blocking_Threads` causes `withTaskGroup` (and `withThrowingTaskGroup`) to fail compilation with "type of expression is ambiguous without a type annotation." The root cause: `String_Primitives.String` shadows `Swift.String`, and the compiler cannot resolve type inference in generic contexts.

The failure is **not fixable** by qualifying `Swift.String` at the call site — the ambiguity is in the compiler's generic type inference for `withTaskGroup`'s closure parameter. The only workaround was splitting code into separate files: one that imports `IO_Blocking_Threads` and one that doesn't.

**Trigger file**: `/Users/coen/Developer/swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis CLI/parallel.swift` — uses `IO.Blocking.Lane.threads()` for concurrent analysis.

**Workaround file**: `/Users/coen/Developer/swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis CLI/CLI.swift` — contains `withTaskGroup` calls, does NOT import `IO_Blocking_Threads`.

### The @_exported Chain

The transitive `@_exported` chain that brings `String_Primitives.String` into scope:

```
import IO_Blocking_Threads
  → @_exported IO_Blocking                           (swift-io)
    → @_exported Kernel                              (swift-kernel, foundations)
      → @_exported Kernel_Primitives                 (swift-kernel-primitives, umbrella)
        → @_exported Kernel_Primitives_Core
          → @_exported String_Primitives             ← ROOT CAUSE
        → @_exported Kernel_String_Primitives
          → @_exported Kernel_Primitives_Core
            → @_exported String_Primitives           ← REDUNDANT PATH
        → @_exported Kernel_Environment_Primitives
          → @_exported Kernel_String_Primitives
            → (same as above)                        ← REDUNDANT PATH
```

Every module that touches `Kernel` — most of swift-io, swift-file, swift-async — transitively imports `String_Primitives` and gets `Swift.String` shadowed.

### The withTaskGroup Failure

```swift
import IO_Blocking_Threads  // brings String_Primitives.String into scope

await withTaskGroup(of: IndexedOutput.self) { group in  // ← COMPILER ERROR
    // "type of expression is ambiguous without a type annotation"
}
```

This fails even when `IndexedOutput` is a fully-specified custom struct. Multiple approaches were tried and all fail:
- `withThrowingTaskGroup` — same failure
- Explicit closure type annotation — same failure
- `returning: [Swift.String].self` explicit parameter — same failure
- `Swift.withTaskGroup` — doesn't exist (`withTaskGroup` is in `_Concurrency`, not `Swift`)

The ONLY workaround is moving `withTaskGroup` to a file without the problematic import.

### Ecosystem-Wide Pattern

This is NOT unique to `String`. The primitives ecosystem deliberately defines types that share names with Swift stdlib types — the module IS the namespace:

| Primitives Module | Type | Shadows |
|-------------------|------|---------|
| `String_Primitives` | `String` | `Swift.String` |
| `Array_Primitives` | `Array` | `Swift.Array` |
| `Dictionary_Primitives` | `Dictionary` | `Swift.Dictionary` |
| `Set_Primitives` | `Set` | `Swift.Set` |
| `Sequence_Primitives` | `Sequence` | `Swift.Sequence` |
| `Collection_Primitives` | `Collection` | `Swift.Collection` |
| `Error_Primitives` | `Error` | `Swift.Error` |

These bare names are intentional — the primitives layer provides its own implementations of these fundamental concepts with different ownership semantics (~Copyable), platform characteristics, or design constraints (no Foundation). The problem is not the naming. The problem is that `@_exported` propagates these modules far beyond their intended scope, poisoning the namespace of modules that never use them.

## Question

How should the ecosystem's `@_exported` chain be restructured to prevent primitives modules from shadowing stdlib types in unrelated downstream consumers?

## Analysis

### Part 1: String_Primitives.String Is Legitimate

`String_Primitives.String` is defined at `/Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String Primitives/String.swift`:

1. **Null-terminated, platform-native string** — `typealias Char = UInt8` on POSIX, `typealias Char = UInt16` on Windows
2. **Unique ownership via `~Copyable`** — prevents double-free of the underlying `Memory.Contiguous<Char>` allocation
3. **Lifetime-safe views via `~Escapable`** — `String.View` uses `@_lifetime(borrow pointer)` to prevent use-after-free
4. **Foundation-independent** — required at Layer 1 per [PRIM-FOUND-001]
5. **Zero-overhead** — all methods `@inlinable`, direct pointer access
6. **Tagged integration** — `Tagged<String, Tag>` extensions for domain-specific strings

`Swift.String.withCString` provides null-terminated access but copies the string. `String_Primitives.String` IS a null-terminated string — no copy needed. The platform-native encoding (UTF-16 on Windows) is essential for Win32 API compatibility. The type serves a legitimate purpose. The name is correct.

#### Who Uses It

**Direct consumers** (code-level, verified by reading source):

| Consumer | Location | How Used |
|----------|----------|----------|
| `swift-path-primitives` | `Path.swift:40,48,51,70,81,85` | Core storage: `Memory.Contiguous<String_Primitives.String.Char>` |
| `Kernel String Primitives` | `Kernel.String.swift:32` | `typealias Kernel.String = Tagged<Kernel, String_Primitives.String>` |
| `Kernel Environment Primitives` | `Kernel.Environment.Entry.swift:24,28,40,41,55,65,79,85` | `UnsafePointer<String.Char>` for env var names/values, `Kernel.String.length(of:)` |
| `swift-loader-primitives` | `Loader.Error.swift:56,61,70,77,78` | `Ownership.Shared<String_Primitives.String>` for error messages |
| `swift-strings` (foundations) | `Swift.String+Primitives.swift` (10+ lines) | Bridge: `Swift.String` ↔ `String_Primitives.String` conversions |
| `swift-ascii` (foundations) | `String_Primitives.String+ASCII.swift:16,33,39,42` | ASCII encoding extensions |

**Transitive consumers** (via @_exported, do NOT use the type): swift-io, swift-file, swift-async, and everything importing Kernel. These get the shadowing without benefit.

#### ISO_9899.String Relationship

`ISO_9899.String` (at `/Users/coen/Developer/swift-iso/swift-iso-9899/`) is complementary, not redundant:
- `ISO_9899.String.Char = UInt8` always (ISO C byte strings)
- `String_Primitives.String.Char = UInt8` on POSIX, `UInt16` on Windows

The `swift-strings` bridge package (`ISO_9899.String+Primitives.swift`) provides direct conversion on POSIX (same encoding) and routed-through-Swift.String conversion on Windows (encoding change).

### Part 2: How to Fix the @_exported Chain

The root cause is structural: `Kernel_Primitives_Core` @_exports `String_Primitives` even though none of its own types use it. This propagates the shadowing to every module in the kernel chain.

#### Option A: Remove @_exported String_Primitives from Kernel_Primitives_Core

Remove `@_exported public import String_Primitives` from `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Primitives Core/exports.swift` (line 19).

**Why this is the critical change**: Kernel_Primitives_Core's own source files (`Kernel.swift`, `Kernel.File.swift`, `Kernel.File.Offset.swift`, `Kernel.File.Size.swift`, `Kernel.Memory.swift`) do NOT use `String_Primitives.String` in any type definition or public API. The @_exported is purely convenience — it makes String_Primitives available to ALL downstream modules, even those that don't need it.

**Required follow-up changes**:

1. `Kernel String Primitives` target needs its own `String_Primitives` dependency in Package.swift and a `public import String_Primitives` in its source
2. `Kernel Environment Primitives` uses `String.Char` and `Kernel.String.length(of:)` in its public API — it needs to import String_Primitives (or Kernel_String_Primitives) directly

**Remaining shadowing path**: Even after this change, the Kernel_Primitives umbrella @_exports Kernel_String_Primitives (line 11 of `Kernel Primitives/Exports.swift`), which in turn needs String_Primitives for its Tagged extensions to be visible to consumers. So the shadowing still propagates:

```
Kernel_Primitives → @_exported Kernel_String_Primitives → needs String_Primitives
```

To fully break this chain, must ALSO change the umbrella to NOT @_export Kernel_String_Primitives:

3. `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Primitives/Exports.swift` — change line 11 from `@_exported public import Kernel_String_Primitives` to `public import Kernel_String_Primitives`
4. `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Environment Primitives/exports.swift` (line 5) — change to non-exported

**Effect after all changes**:
- Consumers of `Kernel_Primitives_Core` (e.g., IO) do NOT get String_Primitives — no shadowing
- Consumers of `Kernel_Primitives` (umbrella) do NOT get String_Primitives — no shadowing
- Consumers of `Kernel_String_Primitives` (explicit import) DO get String_Primitives — shadowing is opt-in
- Consumers of `Kernel_Environment_Primitives` (explicit import) DO get String_Primitives — shadowing is opt-in

**Consequence**: `Kernel.String` is no longer visible through the umbrella. Consumers who need it must explicitly `import Kernel_String_Primitives`. Since no source file in swift-io references `Kernel.String` or `String_Primitives.String`, this is a no-impact change for the IO chain.

| Criterion | Rating |
|-----------|--------|
| Shadowing elimination | **Full for IO/File/Async chain** — the main consumers affected. Opt-in for string consumers |
| Type inference preservation | **Resolves for IO/File/Async** — `withTaskGroup` works again |
| Migration cost | **Low** — ~6 export/import changes + 1 Package.swift |
| Backward compatibility | **Minor** — consumers using `Kernel.String` through umbrella must add explicit import |
| Generalizability | **High** — same pattern applies to other shadowing primitives (Array, Error, etc.) |

#### Option B: Selective @_exported (Compiler-Supported)

The Swift compiler supports `@_exported import struct Module.Type` syntax for selectively re-exporting individual declarations. This is confirmed by:

- **Swift's `Modules.md` doc**: "Just as certain declarations can be selectively imported from a module, so too can they be selectively re-exported" — example: `@_exported import class AmericanCheckers.Board`
- **Compiler test suite** at `test/SymbolGraph/Module/ExportedImport.swift`: Tests `@_exported import struct B.StructOne` and verifies that only `StructOne` appears in the symbol graph — `StructTwo` is correctly excluded
- **`test/ImportResolution/Inputs/letters.swift`**: Uses `@_exported import struct aeiou.E` and `@_exported import struct asdf.D` demonstrating granular control

Instead of removing the entire `@_exported public import String_Primitives`, replace it with selective re-exports of only the types that Kernel_Primitives_Core consumers actually need (if any):

```swift
// Before (exports EVERYTHING from String_Primitives, including bare `String`)
@_exported public import String_Primitives

// After (export nothing — Kernel_Primitives_Core doesn't use String types)
// Line removed entirely
```

Or, if specific types from String_Primitives are needed by downstream targets through Core:

```swift
// Selective: only re-export specific types, NOT the bare `String`
@_exported import struct String_Primitives.Platform  // hypothetical
```

**Evaluation**: Since Kernel_Primitives_Core does NOT use ANY String_Primitives types in its own public API, selective re-export is moot — the correct action is to remove the @_exported entirely (same as Option A). However, this mechanism is valuable context: if other @_exported lines in the chain cause similar issues, selective re-export provides a surgical alternative to full removal.

**Caveat**: `@_exported` is an underscored attribute, not part of Swift's stable public API. The selective form (`@_exported import struct M.T`) is even less documented. However, it has been in the compiler since at least Swift 5.0 and is tested in the official test suite.

| Criterion | Rating |
|-----------|--------|
| Shadowing elimination | **Surgical** — can re-export specific types without the shadowing one |
| Migration cost | **Minimal** — change one line |
| Risk | **Medium** — relies on underscored, undocumented compiler feature |
| Generalizability | **High** — works for any module with mixed-value exports |

#### Option C: Module Aliasing (SE-0339)

SE-0339 introduced module aliasing in SwiftPM. Consumers could alias `String_Primitives`.

**Evaluation**: Module aliasing changes the module name, NOT the type name within it. The type would become `PlatformString_Primitives.String` — still a bare `String` that shadows `Swift.String` when imported.

**Verdict**: Not applicable.

#### Option D: Accept the Shadowing

Document that consumers of kernel-level modules must use `Swift.String` qualification everywhere.

**Current cost across the ecosystem**:
- **218+ files** in swift-primitives use `Swift.String` qualification
- **150+ files** in swift-foundations use `Swift.String` qualification
- `withTaskGroup` CANNOT be fixed by qualification — it requires file-level isolation
- Every new file touching the Kernel chain inherits this tax permanently

**Verdict**: Unacceptable. The `withTaskGroup` breakage is a hard blocker, not an ergonomic annoyance.

### Comparison

| Criterion | Weight | A (Remove @_exported) | B (Selective @_exported) | C (Module Alias) | D (Accept) |
|-----------|--------|----------------------|--------------------------|-------------------|------------|
| Shadowing elimination | Critical | Full (for non-string consumers) | Surgical | None | None |
| Type inference | Critical | Full (for IO chain) | Full | None | Broken |
| Migration cost | High | ~6 files | ~1 line | N/A | 0 |
| Generalizability | High | High (pattern for all primitives) | High | N/A | N/A |
| Stability | Medium | Stable (`public import`) | Underscored feature | Stable | N/A |
| Backward compat | Medium | Minor | None | N/A | N/A |

### The @_exported Chain Design: Broader Implications

Beyond String_Primitives specifically, the "export everything" pattern in Kernel_Primitives_Core @_exports 9 modules:

```swift
@_exported public import Binary_Primitives
@_exported public import CPU_Primitives
@_exported public import Cardinal_Primitives
@_exported public import Dimension_Primitives
@_exported public import Time_Primitives
@_exported public import String_Primitives      ← shadows Swift.String
@_exported public import Error_Primitives       ← shadows Swift.Error
@_exported public import ASCII_Primitives
@_exported public import Memory_Primitives_Core
```

The `Error_Primitives` re-export shadows `Swift.Error` (protocol vs enum). This is less severe today because `Swift.Error` is less commonly referenced by bare name and no inference breakage has been reported. But the architectural pattern is the same: modules that don't need `Error_Primitives` get it anyway.

**Principle**: Kernel_Primitives_Core should only @_export modules whose types it uses in its own public API. Types from `Binary_Primitives` (used in `Kernel.File.Offset`, `Kernel.File.Size`), `Memory_Primitives_Core`, etc. are legitimately needed. `String_Primitives` and `Error_Primitives` are not.

This same audit should be applied to every @_exported chain in the ecosystem. The general rule: **@_export only what your own public API surface requires. Everything else is opt-in via explicit import.**

### Prior Art Survey

#### Swift Compiler: Shadowing Rules

When `Result` was added to Swift stdlib, existing user-defined `Result` types caused ambiguity. Doug Gregor's fix (PR #21370, backported to Swift 5.0 as PR #21378) established the rule: **names from any non-stdlib module shadow names in the `Swift` module**. The stdlib version remains accessible via `Swift.Result`. This is described as "a weak form of a more sensible, generalized rule." The implication: any type named `String` in any imported module *will* shadow `Swift.String` by design.

#### Swift Compiler: Selective @_exported

The Swift compiler supports `@_exported import struct Module.Type` for granular re-export control. Confirmed by:
- `swift/docs/Modules.md`: Documents the syntax with examples
- `test/SymbolGraph/Module/ExportedImport.swift`: Tests that only the selectively exported type appears in the symbol graph
- `test/ImportResolution/Inputs/letters.swift`: Tests granular `@_exported import struct` across multiple modules

This mechanism is functional but underscored and undocumented outside the compiler repo.

#### SE-0339 (Module Aliasing)

Addresses module NAME conflicts, not type NAME conflicts. Not applicable.

#### SE-0409 (Access Level on Imports)

Constrains `@_exported` to only work on `public` import declarations but provides no mechanism to control WHICH symbols `@_exported` re-exports. Explicitly defers the `@_exported` discussion to a future proposal.

#### SE-0444 (Member Import Visibility)

Requires explicit imports for using types from transitive dependencies — UNLESS they are `@_exported`. The ecosystem enables this feature, but `@_exported` bypasses it entirely. This is by design: `@_exported` creates "umbrella modules." The problem is that String_Primitives is swept into an umbrella it doesn't belong in.

#### Other Languages

**Rust**: `pub use` re-exports are granular by default (`pub use crate::string::PlatformString;`). Glob re-exports (`pub use module::*`) are strongly discouraged. RFC 0116 eliminated same-scope shadowing — items at the same scope level cannot shadow each other (compile-time error). Clippy lint `shadow_prelude` warns against shadowing prelude items. Key lesson: Rust's default is selective re-export; Swift's `@_exported` is all-or-nothing.

**Go**: Mandatory package qualification (`package.Identifier`) makes transitive shadowing structurally impossible. No re-export mechanism exists.

**C++**: `using namespace` is scoped and non-transitive. Swift's `@_exported` is the equivalent of if `using namespace std;` in a header automatically applied to all files that `#include` that header — which C++ explicitly prevents.

#### Swift Ecosystem Precedent

No popular Swift package defines a top-level type that shadows a Swift stdlib type:
- **swift-nio**: `Channel`, `EventLoop`, `ByteBuffer` — unique names
- **swift-protobuf**: When a `.proto` message is named `Int` or `String`, the code generator appends `Message` to avoid shadowing
- **swift-collections**: `OrderedDictionary`, `OrderedSet`, `Deque` — unique names, no bare `Array`/`Set`/`Dictionary`
- **swift-algorithms**: Extension methods only, no shadowing types

The Swift Institute ecosystem is unusual in deliberately defining types with stdlib-shadowing names. This is a conscious design choice — the module IS the namespace. The shadowing is acceptable within the module's own scope. It becomes problematic only when @_exported propagates the names beyond that scope.

## Outcome

**Status**: RECOMMENDATION

### Recommended Approach: Remove @_exported String_Primitives from Kernel_Primitives_Core

This is the single change with the highest impact-to-effort ratio. It eliminates shadowing for the vast majority of consumers (IO, File, Async, and everything downstream of Kernel) without renaming any types.

The bare name `String` in `String_Primitives` is correct and consistent with the ecosystem pattern (`Array` in `Array_Primitives`, `Dictionary` in `Dictionary_Primitives`, etc.). The problem is not the name — it's the @_exported propagation.

#### Changes Required

1. **`/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Primitives Core/exports.swift`** (line 19):
   Remove `@_exported public import String_Primitives`

2. **`/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel String Primitives/Kernel.String.swift`**:
   Add `public import String_Primitives` at top

3. **`/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Package.swift`**:
   Add `"String Primitives"` as a direct dependency of the `"Kernel String Primitives"` target

4. **`/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Primitives/Exports.swift`** (line 11):
   Change `@_exported public import Kernel_String_Primitives` to `public import Kernel_String_Primitives`

5. **`/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Environment Primitives/exports.swift`** (line 5):
   Change `@_exported public import Kernel_String_Primitives` to `public import Kernel_String_Primitives`.
   Add `public import String_Primitives` (for `String.Char` used in public API at `Kernel.Environment.Entry.swift:24,28,40,41`)

6. **Verify**: Any other targets in `swift-kernel-primitives` that depend on `Kernel Primitives Core` and use `String.Char` or `String` types must add their own `public import String_Primitives`. Check:
   - `Kernel Path Primitives` — likely uses String.Char (Path depends on String_Primitives)
   - `Kernel Glob Primitives` — uses `Swift.String` extensively (verified: `Kernel.Glob.Pattern.swift` lines 41,56,67,93,153,154)

#### Blast Radius Verification

- swift-io does NOT use `String_Primitives.String` or `Kernel.String` in any source file — the change is invisible to the IO chain
- swift-standards does NOT depend on String_Primitives — unaffected
- Direct consumers (swift-path-primitives, swift-loader-primitives, swift-strings, swift-ascii) import String_Primitives explicitly — unaffected

#### Post-Change Verification

1. `swift build` in `swift-primitives/swift-kernel-primitives/`
2. `swift build` in `swift-foundations/swift-kernel/`
3. `swift build` in `swift-foundations/swift-io/`
4. Verify `withTaskGroup` compiles in `swift-dependency-analysis` without file isolation
5. Grep for remaining `Swift.String` qualifications — many may now be unnecessary

#### Follow-Up: Audit All @_exported Chains

Apply the same principle ecosystem-wide: **@_export only what your own public API surface requires**. Audit candidates:

| Module | Currently @_exports | Uses in own public API? | Action |
|--------|--------------------|-----------------------|--------|
| Kernel Primitives Core | `String_Primitives` | No | **Remove** (this recommendation) |
| Kernel Primitives Core | `Error_Primitives` | No | Audit — may need same treatment |
| Kernel Primitives Core | `ASCII_Primitives` | No | Audit |
| Kernel Primitives (umbrella) | `Kernel_String_Primitives` | No | **Demote to `public import`** (this recommendation) |
| Kernel Environment Primitives | `Kernel_String_Primitives` | Yes (`String.Char`) | Keep import, demote @_exported |

### What NOT to Do

- **Do NOT rename the type** — bare names are the ecosystem pattern, consistent with Array/Dictionary/Set/etc.
- **Do NOT accept the shadowing** — `withTaskGroup` breakage is a hard blocker
- **Do NOT use module aliasing** (SE-0339) — it doesn't solve type-level shadowing
- **Do NOT add `Swift.String` qualifications everywhere** — permanent tax that grows with the codebase

## References

- [PRIM-FOUND-001] No Foundation — `/Users/coen/Developer/swift-institute/Skills/primitives/SKILL.md`
- SE-0339 Module Aliasing for Disambiguation — `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0339-module-aliasing-for-disambiguation.md`
- SE-0409 Access Level on Imports — `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md`
- SE-0444 Member Import Visibility — `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md`
- Swift PR #21370 (Doug Gregor) — Shadowing rules for stdlib types
- Swift `docs/Modules.md` — Selective `@_exported import` documentation
- OS Native Path String Semantics — `/Users/coen/Developer/swift-primitives/swift-string-primitives/Research/OS Native Path String Semantics.md`
