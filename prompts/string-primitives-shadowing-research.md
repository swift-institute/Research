# Research Handoff: String_Primitives.String Shadowing Swift.String

## Instructions

You are conducting a [RES-001] Investigation Research per the `research-process` skill. The question has two parts:

1. **Should `swift-string-primitives` exist at all?** — Analyze whether its `String` type serves a purpose that cannot be served by other means.
2. **If it should exist, how should the ecosystem handle `String` shadowing `Swift.String`?** — Propose concrete solutions.

Follow [RES-004] Investigation Methodology: enumerate options, identify evaluation criteria, systematically compare alternatives, and produce a DECISION or RECOMMENDATION outcome.

The research document MUST be created at:
```
Research/string-primitives-shadowing.md
```

Update the research index at:
```
Research/_index.md
```

Use the [RES-003] document structure (Title, Metadata, Context, Question, Analysis, Outcome, References).

This is Tier 2 (cross-package, reversible but affects many packages). Per [RES-020], include a Prior Art Survey [RES-021].

---

## The Problem

`swift-string-primitives` defines a top-level `public struct String: ~Copyable, @unchecked Sendable` in the `String_Primitives` module. This type shadows `Swift.String` — the most commonly used type in the Swift language — whenever `String_Primitives` is in scope.

The shadowing is not limited to direct imports. Because `String_Primitives` is transitively `@_exported` through the kernel primitives chain, ANY package that imports a module touching the kernel layer gets `String_Primitives.String` in scope, shadowing `Swift.String`.

### The Concrete Trigger

While adding parallel execution to `swift-dependency-analysis` using `IO.Blocking.Threads` from `swift-io`, we discovered that `import IO_Blocking_Threads` makes `withTaskGroup` (and `withThrowingTaskGroup`) fail to compile with "type of expression is ambiguous without a type annotation." The root cause: `String_Primitives.String` shadows `Swift.String`, and the compiler cannot resolve type inference in generic contexts where `String` appears.

The workaround required splitting the CLI into two files — one that imports `IO_Blocking_Threads` (and therefore has shadowed `String`), and one that doesn't (where `withTaskGroup` works). This is a significant ergonomic tax.

### The Export Chain

The transitive `@_exported` chain that brings `String_Primitives.String` into scope:

```
import IO_Blocking_Threads
  → @_exported IO_Blocking            (swift-io)
    → @_exported Kernel               (swift-kernel)
      → @_exported Kernel_Primitives  (swift-kernel-primitives)
        → Kernel Primitives Core target
          → @_exported String_Primitives   ← THE CULPRIT
```

Every module that touches `Kernel` (which is most of swift-io, swift-file, swift-async, etc.) transitively imports `String_Primitives` and gets `Swift.String` shadowed.

### Files to Examine

#### The String type definition
```
https://github.com/swift-primitives/swift-string-primitives/blob/main/Sources/String Primitives/String.swift
```
- `public struct String: ~Copyable, @unchecked Sendable`
- Owned, null-terminated platform string
- Platform-conditional character type: UTF-8 on POSIX, UTF-16 on Windows
- Uses `Memory.Contiguous<Char>` for storage
- `~Copyable` enforces unique ownership (prevents double-free)

#### The String.View type
```
https://github.com/swift-primitives/swift-string-primitives/blob/main/Sources/String Primitives/String.View.swift
```
- `public struct View: ~Copyable, ~Escapable`
- Borrowed, non-escapable view of a null-terminated string
- Lifetime-encoded via `@_lifetime(borrow pointer)`

#### Other files in the package
```
https://github.com/swift-primitives/swift-string-primitives/blob/main/Sources/String Primitives/String.Char.swift
https://github.com/swift-primitives/swift-string-primitives/blob/main/Sources/String Primitives/String.Length.swift
https://github.com/swift-primitives/swift-string-primitives/blob/main/Sources/String Primitives/Tagged+String.swift
https://github.com/swift-primitives/swift-string-primitives/blob/main/Sources/String Primitives/Tagged+String.View.swift
```

#### Package.swift
```
https://github.com/swift-primitives/swift-string-primitives/blob/main/Package.swift
```
- Dependencies: swift-ascii-primitives, swift-memory-primitives, swift-identity-primitives
- Experimental features: Lifetimes, SuppressedAssociatedTypes

#### The @_exported import that propagates it
```
https://github.com/swift-primitives/swift-kernel-primitives/blob/main/Sources/Kernel Primitives Core/exports.swift
```
- Contains `@_exported public import String_Primitives` (guarded by `#if KERNEL_AVAILABLE`)

#### Research on the String type's purpose
```
https://github.com/swift-primitives/swift-string-primitives/blob/main/Research/OS Native Path String Semantics.md
```
- ~359 lines covering POSIX vs Windows path encoding, ownership safety, lifetime safety

#### The dependency-analysis workaround (the trigger for this research)
```
https://github.com/swift-foundations/swift-dependency-analysis/blob/main/Sources/Dependency Analysis CLI/CLI.swift
https://github.com/swift-foundations/swift-dependency-analysis/blob/main/Sources/Dependency Analysis CLI/parallel.swift
```
- CLI.swift: no IO import, uses `Swift.String` naturally, has `withTaskGroup`
- parallel.swift: imports `IO_Blocking_Threads`, uses `Swift.String` qualification everywhere, avoids `withTaskGroup`

---

## Known Consumers of String_Primitives

You MUST verify these by reading the actual source files. Do not rely on this list alone.

### Direct dependents in swift-primitives
- `swift-kernel-primitives` — Has `Kernel String Primitives` target depending on `String Primitives`
- `swift-path-primitives` — Uses `String Primitives` for path representations
- `swift-loader-primitives` — Uses `String Primitives`

### Direct dependents in swift-foundations
- `swift-strings` — Primary consumer; bridges `String_Primitives.String` ↔ `Swift.String`
- `swift-kernel` — Re-exports via `Kernel_Primitives`

### swift-strings (MUST investigate thoroughly)

`swift-strings` at `https://github.com/swift-foundations/swift-strings` is the primary consumer of `String_Primitives`. You MUST:

1. Read its `Package.swift` to understand its targets and dependencies
2. Read its `exports.swift` — does it re-export `String_Primitives`?
3. Read ALL source files to understand:
   - How does it bridge `String_Primitives.String` ↔ `Swift.String`?
   - Does it wrap, extend, or replace `String_Primitives.String`?
   - Does it provide its own `String`-like type?
   - Does it itself suffer from the `Swift.String` shadowing problem internally?
4. Check if `swift-strings` is designed to be the "user-facing" string layer that consumers should use instead of `String_Primitives` directly. If so, the @_exported chain should arguably go through `swift-strings`, not through `Kernel_Primitives`.
5. Evaluate whether `swift-strings` makes `String_Primitives` unnecessary for most consumers.

The relationship between `String_Primitives` (Layer 1, ~Copyable, null-terminated, platform-native) and `swift-strings` (Layer 3, likely Copyable, likely Swift.String-compatible) is central to this research.

### Transitive dependents (via @_exported chain)
Every package that imports any of: `Kernel`, `IO_Blocking`, `IO_Blocking_Threads`, `IO_Primitives`, `IO`, or anything that re-exports `Kernel`. This includes most of swift-io, swift-file, swift-async, etc.

You should verify:
1. Which of these consumers actually USE the `String` type (vs just getting it transitively)?
2. How many files qualify `Swift.String` as a workaround?
3. Are there other instances of the shadowing causing compilation failures?

Search for:
```
grep -r "Swift\.String" across swift-primitives/ and swift-foundations/
grep -r "String_Primitives\.String" across both repos
grep -r "import String_Primitives" across both repos
```

---

## Part 1: Should swift-string-primitives Exist?

### What String_Primitives.String Provides

1. **Null-terminated, platform-native string** — UTF-8 on POSIX, UTF-16 on Windows
2. **Unique ownership via `~Copyable`** — Prevents double-free of the underlying allocation
3. **Lifetime-safe views via `~Escapable`** — `String.View` cannot escape the scope of the owning `String`
4. **Foundation-independent** — No Foundation import (required for primitives layer)
5. **Zero-overhead** — All methods `@inlinable`, direct pointer access
6. **Typed safety** — `Tagged<String, Tag>` for domain-specific string types

### Questions to Investigate

#### Q1: Is there a real use case for a ~Copyable null-terminated string?

Examine the actual consumers:
- Does `swift-path-primitives` use it for OS path operations? Could it use `Swift.String` or `UnsafePointer<CChar>` instead?
- Does `swift-kernel-primitives` use it for syscall string arguments?
- Does `swift-loader-primitives` use it for dynamic library paths?
- What does `swift-strings` do with it? Is it just a bridge, or does it add value?

#### Q2: Does `Swift.String` already serve these needs?

`Swift.String` is:
- UTF-8 internally (since Swift 5)
- Has `withCString { }` for null-terminated access
- Has `String(cString:)` for creating from C strings
- Copyable (COW semantics)
- Foundation-independent (it's in the stdlib)

The key difference is ownership: `Swift.String` uses COW (copy-on-write), while `String_Primitives.String` is `~Copyable` (unique ownership). Is unique ownership actually needed for the use cases?

#### Q3: Could a nested type avoid the shadowing?

Per [API-NAME-001], types must use the `Nest.Name` pattern. A top-level `String` violates this — it should arguably be something like:
- `Platform.String`
- `OS.String`
- `CString` (but this is a compound name)
- `Native.String`
- Something nested under an appropriate namespace

Read the existing research at:
```
https://github.com/swift-primitives/swift-string-primitives/blob/main/Research/OS Native Path String Semantics.md
```
This document likely explains the naming rationale. Evaluate whether that rationale still holds given the shadowing consequences.

#### Q4: Is the naming even correct per ecosystem conventions?

The ecosystem uses [API-NAME-001] `Nest.Name`. A bare `String` at module scope with no namespace nesting is unusual. Check:
- Are there other primitives packages that define top-level types that shadow stdlib types?
- Is `String` the only one, or is this a pattern (e.g., does any package define a top-level `Array`, `Dictionary`, `Int`, etc.)?

Search for top-level type definitions across swift-primitives:
```
grep -rn "^public struct " across all Sources/ directories
grep -rn "^public enum " across all Sources/ directories
```

Filter for names that match Swift stdlib types.

#### Q5: What is the relationship with ISO_9899.String (C standard string)?

The research document mentions `ISO_9899.String`. Check:
```
https://github.com/swift-standards
```
Is there an ISO 9899 (C standard) implementation? How does it relate to `String_Primitives.String`? Is one redundant?

---

## Part 2: If It Should Exist, How to Fix the Shadowing

If the research concludes that `String_Primitives.String` serves a legitimate purpose, enumerate and evaluate these options for eliminating the shadowing problem:

### Option A: Rename/Namespace the Type

Rename `String` to a nested type that doesn't shadow `Swift.String`.

Candidates:
- `Platform.String` — Clear, descriptive, follows Nest.Name
- `OS.String` — Short, but `OS` might be too broad
- `Native.String` — Implies platform-native encoding
- `CString.Owned` — Describes what it is (owned C string), but "CString" is a compound name

**Evaluation criteria:**
- Does the new name accurately describe the type's purpose?
- Does it follow [API-NAME-001]?
- How many call sites need updating?
- Does the new namespace already exist or need creation?

### Option B: Remove @_exported import String_Primitives from the Chain

This is the simplest possible fix. Stop re-exporting `String_Primitives` from `Kernel_Primitives_Core`. Consumers that need it would import it explicitly.

This option MUST be investigated thoroughly. It may be the correct fix if few consumers actually need `String_Primitives.String` transitively.

**Investigation steps:**
1. Read the exports.swift at:
   ```
   https://github.com/swift-primitives/swift-kernel-primitives/blob/main/Sources/Kernel Primitives Core/exports.swift
   ```
2. Remove `@_exported public import String_Primitives` mentally and trace the impact:
   - Which targets in `swift-kernel-primitives` have `String_Primitives` as a dependency?
   - Do any of those targets expose `String_Primitives.String` in their PUBLIC API signatures?
   - Or is it only used internally?
3. Check every file in `Kernel_Primitives_Core` sources — does any public type or method use `String` from `String_Primitives` in its signature?
4. Check `Kernel String Primitives` target — this is likely where all `String_Primitives` usage lives. If so, removing the re-export from `Kernel Primitives Core` and keeping it only in `Kernel String Primitives` would isolate the shadowing.
5. Check the Kernel target in swift-kernel (foundations layer):
   ```
   https://github.com/swift-foundations/swift-kernel/blob/main/Sources/Kernel/exports.swift
   ```
   Does it re-export `Kernel_String_Primitives`? If not, the shadowing is already not propagating through that path.
6. Trace which targets in swift-io actually use any type from `String_Primitives`. If none do, the re-export is pure waste.

**Key question:** Can you remove `@_exported public import String_Primitives` from `Kernel_Primitives_Core/exports.swift` WITHOUT breaking any downstream compilation? If yes, this is the fix. Build-test it mentally by checking every consumer.

### Option C: Use @_implementationOnly import

Change the kernel primitives to use `@_implementationOnly import String_Primitives` so the type is available internally but not re-exported.

**Evaluate:**
- Does kernel primitives expose `String_Primitives.String` in its public API?
- If so, `@_implementationOnly` won't work (the type would be in public signatures)
- If not, this is a clean fix

### Option D: Separate Kernel String Target

`swift-kernel-primitives` already has a `Kernel String Primitives` target. Check:
```
https://github.com/swift-primitives/swift-kernel-primitives/blob/main/Package.swift
```
- Is `String_Primitives` only re-exported from `Kernel Primitives Core`, or also from `Kernel String Primitives`?
- Could the re-export be moved to ONLY `Kernel String Primitives` (which wouldn't be @_exported from the main chain)?
- Consumers that need kernel + string would import `Kernel_String_Primitives` explicitly

### Option E: Module Aliasing (Swift 5.7+)

SwiftPM supports module aliasing. Could consumers alias `String_Primitives` to avoid the shadowing?

**Evaluate:**
- Does module aliasing work with `@_exported`?
- Is this a per-consumer workaround or a systemic fix?
- What's the SwiftPM syntax?

### Option F: Accept the Shadowing

Document that consumers of kernel-level modules must use `Swift.String` qualification.

**Evaluate:**
- How many files across the ecosystem currently need `Swift.String` qualification?
- What's the ergonomic cost?
- Does it break generic type inference (as seen with `withTaskGroup`)?
- Is this a permanent tax on every consumer?

---

## Evaluation Criteria

For each option, evaluate against:

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Shadowing elimination | Critical | Does it fully resolve `Swift.String` shadowing? |
| Type inference preservation | Critical | Does `withTaskGroup`, `map`, etc. work without explicit type annotations? |
| API clarity | High | Does the type name clearly communicate what it is? |
| Migration cost | High | How many files/packages need changes? |
| Convention compliance | High | Does it follow [API-NAME-001] and ecosystem conventions? |
| Backward compatibility | Medium | Can existing code keep working during migration? |
| Future-proofing | Medium | Does the solution scale as the ecosystem grows? |

---

## Prior Art Survey [RES-021]

You MUST investigate:

### Swift Evolution and Forums
- SE-0339 (Module Aliasing For Disambiguation) — SwiftPM module aliasing. Does it solve this?
- SE-0394 and other macro/module proposals
- Any proposals related to module name conflicts or type shadowing
- Swift forums discussions about `@_exported` and transitive import pollution
- Search forums.swift.org for "type shadowing", "module name conflict", "@_exported pollution"
- Check if there are any open Swift compiler bugs about type inference failures caused by shadowed types

### Other Languages
- **Rust**: `use` aliasing and `as` keyword for import disambiguation (`use std::string::String as StdString`). Rust also has crate-level visibility — does this prevent transitive shadowing?
- **Go**: Package aliasing (`import alias "package/path"`). Go's flat namespace means shadowing is common — how do large Go projects handle it?
- **Haskell**: Qualified imports (`import qualified Data.Map as Map`). Haskell's module system makes shadowing explicit. What design lessons apply?
- **C++**: Namespace aliasing (`namespace fs = std::filesystem`). C++ namespaces prevent shadowing by design.
- **Kotlin**: Import aliasing (`import foo.Bar as FooBar`). Kotlin allows per-file renaming.

### Swift Ecosystem Precedent
- Does any popular Swift package define a top-level type that shadows a stdlib type? Check:
  - swift-nio — does it define `Channel`, `EventLoop`, or anything stdlib-adjacent?
  - swift-protobuf — does it define types that shadow stdlib names?
  - swift-collections — does it define `Deque`, `OrderedSet`, etc. that could shadow?
  - swift-algorithms — any shadowing issues?
  - Vapor — does it define `Request`, `Response` that shadow Foundation types?
- How do large Swift projects handle module name conflicts in practice?
- Are there well-known blog posts or conference talks about Swift module design and naming?

### Academic / Design Literature
- Research on module systems and name resolution (Cardelli, Leroy, Harper)
- The "diamond dependency problem" in module systems — how does `@_exported` create it?
- Cognitive load research on name disambiguation (how much does `Swift.String` qualification cost developers mentally?)

---

## Scope and Constraints

### In Scope
- Whether `String_Primitives.String` should exist
- If it should exist, what it should be named
- How the `@_exported` chain should be structured
- Impact on all consuming packages

### Out of Scope
- Redesigning the `@_exported` system broadly (that's a separate investigation)
- Modifying `Swift.String` in the stdlib
- Swift compiler changes to fix type inference with shadowed types

### Constraints
- [PRIM-FOUND-001]: No Foundation imports in primitives
- [API-NAME-001]: Nest.Name pattern required
- The type serves a real purpose for kernel/path/loader operations (verify this)
- Any rename must be applied across all consumers
- The ecosystem uses Swift 6.2 with MemberImportVisibility

---

## Expected Deliverables

1. A research document at `Research/string-primitives-shadowing.md` following [RES-003] structure
2. Updated `_index.md` at `Research/_index.md`
3. Clear DECISION or RECOMMENDATION outcome
4. If recommending a rename: the exact new name, with rationale
5. If recommending export chain changes: the exact files and changes needed
6. Migration checklist: every file that would need updating

---

## How to Start

1. Invoke the `research-process` skill to confirm methodology
2. Read all files listed in "Files to Examine" above
3. Search for all consumers of `String_Primitives` across the workspace
4. Search for all `Swift.String` qualifications (shadowing workarounds)
5. Read the existing research document on OS Native Path String Semantics
6. Check if other primitives packages shadow stdlib types
7. Enumerate options per [RES-004]
8. Compare against evaluation criteria
9. Write the research document
10. Update the index

---

## Key Skill References

Before starting, invoke these skills:
- `research-process` — for methodology ([RES-001] through [RES-026])
- `naming` — for [API-NAME-001] Nest.Name pattern evaluation
- `primitives` — for primitives layer conventions
- `modularization` — for export chain and target decomposition rules
- `swift-institute-core` — for five-layer architecture context

---

## Repository Paths

| Repository | Path |
|------------|------|
| swift-primitives | `https://github.com/swift-primitives` |
| swift-foundations | `https://github.com/swift-foundations` |
| swift-standards | `https://github.com/swift-standards` |
| swift-institute | `./` |
| swift-string-primitives | `https://github.com/swift-primitives/swift-string-primitives` |
| swift-kernel-primitives | `https://github.com/swift-primitives/swift-kernel-primitives` |
| swift-path-primitives | `https://github.com/swift-primitives/swift-path-primitives` |
| swift-loader-primitives | `https://github.com/swift-primitives/swift-loader-primitives` |
| swift-kernel (foundations) | `https://github.com/swift-foundations/swift-kernel` |
| swift-strings (foundations) | `https://github.com/swift-foundations/swift-strings` |
| swift-io (foundations) | `https://github.com/swift-foundations/swift-io` |
| swift-dependency-analysis | `https://github.com/swift-foundations/swift-dependency-analysis` |

---

## Non-Obvious Context

### MemberImportVisibility (Swift 6.2)
The ecosystem enables `MemberImportVisibility` as an upcoming feature. This means transitive imports are NOT automatically visible — UNLESS they are `@_exported`. The `String_Primitives` chain uses `@_exported` at every hop, which is why the shadowing propagates despite `MemberImportVisibility`.

### The ~Copyable Angle
`String_Primitives.String` is `~Copyable`. `Swift.String` is `Copyable`. These are fundamentally different ownership models. The `~Copyable` design ensures:
- No implicit copies of the underlying allocation
- Deterministic deallocation (no ARC overhead for the buffer)
- Unique ownership (no aliasing bugs)

This is valuable for OS-level string handling where you want to guarantee the string is freed exactly once. But it also means `String_Primitives.String` and `Swift.String` are not interchangeable — they serve different purposes. The question is whether those different purposes justify a name collision with the most common type in Swift.

### The withTaskGroup Failure
The specific compilation failure that triggered this research:
```swift
import IO_Blocking_Threads  // brings String_Primitives.String into scope

await withTaskGroup(of: IndexedOutput.self) { group in  // ← "type of expression is ambiguous"
    // ...
}
```

This fails even when:
- `IndexedOutput` is a custom struct (not using `String` in its type name)
- The closure body uses `Swift.String` explicitly
- The `of:` parameter is fully specified

The ambiguity appears to stem from `withTaskGroup`'s generic signature interacting with the shadowed `String` type during closure type inference. This is not a case where `Swift.String` qualification fixes the problem — the inference failure is deeper.

Multiple approaches were tried:
- `withThrowingTaskGroup` — same failure
- Explicit closure type annotation `(group: inout TaskGroup<IndexedOutput>)` — same failure
- `returning: [Swift.String].self` explicit parameter — same failure
- `Swift.withTaskGroup` — `Swift` module has no `withTaskGroup` (it's in `_Concurrency`)

The ONLY workaround was to move `withTaskGroup` to a different file that does NOT import `IO_Blocking_Threads`.

### Tagged<String, Tag>
The package also provides `Tagged<String, Tag>` extensions and `Tagged<String, Tag>.View`. If `String` is renamed, these extensions need updating too. Check:
```
https://github.com/swift-primitives/swift-string-primitives/blob/main/Sources/String Primitives/Tagged+String.swift
https://github.com/swift-primitives/swift-string-primitives/blob/main/Sources/String Primitives/Tagged+String.View.swift
```

### The Platform.String Angle
The type already has a platform-conditional `Char` type:
- POSIX: `typealias Char = UInt8` (UTF-8)
- Windows: `typealias Char = UInt16` (UTF-16)

This suggests the type's identity is fundamentally about platform-native encoding. A name like `Platform.String` or `OS.String` would capture this better than bare `String`.

### Formatting Primitives
`swift-formatting-primitives` has a commented-out dependency on `String_Primitives`. Check:
```
https://github.com/swift-primitives/swift-formatting-primitives/blob/main/Package.swift
```
This might indicate the type was considered for formatting but not yet integrated.

---

## Additional Investigation: The @_exported Chain Design

Beyond the `String` shadowing specifically, this research should briefly assess whether the `@_exported` chain design is sound. The current pattern is:

```
Leaf module (e.g., String_Primitives)
  ← @_exported by intermediate (Kernel_Primitives_Core)
    ← @_exported by higher layer (Kernel)
      ← @_exported by consumer (IO_Blocking)
        ← @_exported by consumer (IO_Blocking_Threads)
```

Every hop re-exports everything from below. This means importing ANY module near the top of the chain brings in EVERY module below it. For `IO_Blocking_Threads`, that includes:
- `String_Primitives` (the problem)
- `Binary_Primitives`
- `CPU_Primitives`
- `Cardinal_Primitives`
- `Dimension_Primitives`
- `Time_Primitives`
- `Error_Primitives`
- `ASCII_Primitives`
- `Memory_Primitives_Core`
- Architecture-specific primitives (ARM or x86)
- And everything THOSE re-export

Questions for the research:
1. Is this "export everything" pattern intentional and justified?
2. Are there other types in this chain that could cause shadowing (check for top-level names)?
3. Should `Kernel_Primitives_Core` be more selective about what it re-exports?
4. Is the `#if KERNEL_AVAILABLE` guard on the exports sufficient, or does it always evaluate to true on supported platforms?

Check the guard condition:
```
https://github.com/swift-primitives/swift-kernel-primitives/blob/main/Sources/Kernel Primitives Core/exports.swift
```

And verify what `KERNEL_AVAILABLE` is defined as:
```
grep -r "KERNEL_AVAILABLE" https://github.com/swift-primitives/swift-kernel-primitives
```

---

## Naming Deep Dive

If the research recommends renaming, conduct a thorough naming analysis per [RES-010a]:

### Candidate Names with Rationale

| Candidate | Nesting | Reads as | Concern |
|-----------|---------|----------|---------|
| `Platform.String` | `Platform` enum → `String` struct | "A string for the platform" | `Platform` may conflict with other uses |
| `OS.String` | `OS` enum → `String` struct | "An OS string" | Very short namespace |
| `Native.String` | `Native` enum → `String` struct | "A native string" | "Native" is overloaded (Swift Native?) |
| `CString.Owned` | `CString` enum → `Owned` struct | "An owned C string" | `CString` is compound per [API-NAME-001] |
| `System.String` | `System` enum → `String` struct | "A system string" | `System` may conflict with Swift System |
| `Kernel.String` | `Kernel` enum → `String` struct | "A kernel string" | Already in kernel-primitives, but Kernel is a foundations concept |
| `Terminal.String` | — | "A null-terminated string" | Misleading (terminal = console?) |
| `Foreign.String` | `Foreign` enum → `String` struct | "A foreign string" | FFI connotation |

For each candidate:
- Does the namespace enum already exist? If so, where?
- Would it conflict with anything in the ecosystem?
- Does it accurately describe the type's semantics (null-terminated, platform-encoded, uniquely-owned)?
- How does it read at call sites?

```swift
// Current
let path = String(ascii: "/usr/bin")

// Candidates
let path = Platform.String(ascii: "/usr/bin")
let path = OS.String(ascii: "/usr/bin")
let path = Native.String(ascii: "/usr/bin")
```

### Module Name Implications

If the type is renamed to `Platform.String`, should the module also be renamed?
- Current: `String Primitives` module, `String_Primitives` import
- Possible: `Platform String Primitives` module, `Platform_String_Primitives` import
- Or keep the module name and just rename the type within it?

---

## Output Format

Write the research document. Do NOT write code. Do NOT modify any source files. This is pure analysis and recommendation.

The document should be thorough enough that a decision can be made and an implementation plan derived from it. Include concrete file paths and line numbers for every finding.
