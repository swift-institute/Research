# String and Path Type Unification

<!--
---
version: 3.1.0
last_updated: 2026-02-27
status: IN_PROGRESS
tier: 3
---
-->

## Context

The Swift Institute ecosystem contains five distinct string-like and path-like types distributed across three architectural layers:

| Layer | Type | Module | Copyable | Char | Purpose |
|-------|------|--------|----------|------|---------|
| 1 (Primitives) | `String_Primitives.String` | `String Primitives` | ~Copyable | UInt8 / UInt16 | OS-native null-terminated string |
| 1 (Primitives) | `Kernel.Path` | `Kernel Primitives` | ~Copyable | UInt8 / UInt16 | Filesystem path for syscalls |
| 2 (Standards) | `ISO_9899.String` | `ISO 9899` | ~Copyable | UInt8 | C byte string per ISO/IEC 9899 |
| 3 (Foundations) | `Path` | `Paths` | Copyable | UInt8 / UInt16 | User-facing path with navigation |
| 3 (Foundations) | (bridging) | `Strings` | — | — | Cross-domain conversion layer |

Each type also has a companion `View` type (~Copyable, ~Escapable) for borrowed access.

This research was triggered by the observation that `Kernel.Path` and `String_Primitives.String` share identical internal structure, and that the relationship between the five types deserves systematic analysis to determine whether unification, consolidation, or the current separation is the correct long-term design.

### Trigger

Design question arose during ecosystem review: the `Kernel.Path` type wraps `String_Primitives.String` as its `_storage` field, delegates all operations to it, and adds no stored state. Is this wrapper justified, or does it introduce accidental complexity?

### Constraints

- **Timeless infrastructure**: These types underpin every I/O operation in the ecosystem. Changes propagate everywhere.
- **Platform divergence**: POSIX paths are opaque byte sequences; Windows paths are UTF-16. Any unification must respect this.
- **~Copyable/~Escapable maturity**: Swift's ownership features are still evolving. Designs must work with current compiler limitations.
- **Layering discipline**: Primitives cannot depend on Standards or Foundations. Standards cannot depend on Foundations.

### Scope

Ecosystem-wide. Spans swift-primitives (Layer 1), swift-standards (Layer 2), and swift-foundations (Layer 3).

---

## Question

**What is the correct type architecture for string and path representations across the Swift Institute ecosystem?**

Sub-questions:
1. Should `Kernel.Path` remain a distinct type from `String_Primitives.String`, or should it become a typealias?
2. Should the corresponding `View` types be unified?
3. Is the `Kernel.Path.String` scoped-conversion namespace correctly placed?
4. Does the foundations `Path` type correctly bridge the primitives/foundations boundary?
5. What role does `ISO_9899.String` play relative to `String_Primitives.String` on POSIX where both use `UInt8`?

---

## Prior Art Survey

### Rust: Four-Type Hierarchy

Rust maintains four string families with strict separation:

```
str / String          (UTF-8 guaranteed)
      ↓
OsStr / OsString      (platform-native superset)
      ↓
Path / PathBuf         (thin wrapper over OsStr/OsString)
      ↓
CStr / CString         (NUL-terminated, FFI)
```

**Key decisions**:
- `OsString` bridges the encoding gap between Rust's UTF-8 guarantee and platform reality (arbitrary bytes on Unix, potentially-invalid UTF-16 on Windows).
- `Path`/`PathBuf` are thin newtypes over `OsStr`/`OsString` that add path-specific operations (parent, extension, components).
- `CString` handles FFI boundary concerns (NUL termination, no interior NULs).

**Problems identified**:
- Conversion friction: `OsString → String` is fallible; users frequently resort to `.to_string_lossy()`.
- Missing methods: `PathBuf` lacks some `OsString` methods due to layering decisions.
- Cognitive load: four string types with different rules.

**Relevance**: Rust's `Path`/`PathBuf` as a thin newtype over `OsString` is structurally analogous to our `Kernel.Path` wrapping `String_Primitives.String`. Rust accepted this design despite the thin-wrapper cost.

**Sources**: [Rust std::ffi::OsString](https://doc.rust-lang.org/std/ffi/struct.OsString.html), [Rust std::path::Path](https://doc.rust-lang.org/std/path/struct.Path.html), [RFC 1307](https://rust-lang.github.io/rfcs/1307-osstring-methods.html)

### C++17: std::filesystem::path — A Cautionary Tale

C++ uses a single `std::filesystem::path` type with implicit conversions from `const char*` and `std::string`. On Windows, `std::string` input is interpreted as the Active Code Page (ACP), not UTF-8. This has caused:

- Silent data corruption when paths contain non-ASCII characters.
- `std::u8path()` was introduced in C++20 then deprecated, leaving no good path forward.
- The vcpkg project removed `std::filesystem` usage entirely due to encoding unreliability.

**Lesson**: Implicit encoding conversions are dangerous. The Swift Institute's explicit conversion APIs (`Kernel.Path.scope`, typed throws for conversion errors) correctly avoid this trap.

**Sources**: [cppreference std::filesystem::path](https://en.cppreference.com/w/cpp/filesystem/path.html), [Microsoft STL Issue #909](https://github.com/microsoft/STL/issues/909)

### Apple swift-system: FilePath

Apple's `swift-system` package provides `FilePath`:
- Single Copyable type for filesystem paths.
- Platform-aware separator normalization.
- Internally stores as platform-native encoding.
- Provides a `ComponentView` (bidirectional, range-replaceable collection).

**Relevance**: Our foundations `Path` type occupies the same niche as `FilePath`. The key difference is our layered architecture: `Path` (Copyable, user-facing) bridges down to `Kernel.Path` (~Copyable, syscall-facing) through `withKernelPath(_:)`.

**Sources**: [swift-system GitHub](https://github.com/apple/swift-system), [FilePath documentation](https://swiftinit.org/docs/swift-system/systempackage/filepath)

### Go: Operation Hierarchy

Go avoids separate string types entirely. Instead it provides two packages:
- `path`: generic slash-separated path manipulation.
- `path/filepath`: OS-aware filesystem path manipulation.

Both operate on `string`. The domain semantics live in the operations, not the types.

**Relevance**: Demonstrates that type separation is not the only valid design. However, Go lacks ownership semantics and cannot encode memory safety in types.

**Sources**: [Go path/filepath](https://pkg.go.dev/path/filepath)

### Zig: WTF-8 Encoding Strategy

Zig uses WTF-8 (a superset of UTF-8 that can encode lone surrogates) as its internal path encoding. This achieves lossless round-tripping between POSIX byte paths and Windows UTF-16 paths without multiple types.

**Relevance**: Novel approach that eliminates the encoding bifurcation. However, WTF-8 is not a recognized standard and introduces complexity at the encoding layer rather than the type layer.

### Python: PEP 529 and Encoding Migration

Python 3.6 switched from ANSI APIs to UTF-8 filesystem encoding on Windows (PEP 529). This eliminated the need for separate path types across platforms but required a major runtime change.

**Relevance**: Demonstrates that platform unification is possible but requires accepting UTF-8 as universal. The Swift Institute's choice to use platform-native encoding (UTF-8 on POSIX, UTF-16 on Windows) is more conservative but avoids lossy conversions.

### Synthesis of Prior Art

| Language | String Types | Path Types | Encoding Strategy | Thin Wrapper |
|----------|-------------|------------|-------------------|--------------|
| Rust | 2 (str, OsStr) + CStr | Path (over OsStr) | Platform-native | Yes |
| C++ | 1 (string) | path (over string) | Implicit (broken) | Yes |
| Swift (Apple) | 1 (String) | FilePath | Platform-native | No (standalone) |
| Go | 1 (string) | None (operations only) | UTF-8 | N/A |
| Zig | 1 ([]u8) | None | WTF-8 | N/A |
| **Swift Institute** | 2 (String_Primitives, ISO_9899) | 2 (Kernel.Path, Path) | Platform-native | Yes (Kernel.Path) |

---

## Systematic Literature Review

### Research Questions

**RQ1**: What type-theoretic foundations justify or refute separating "OS string" from "filesystem path" as distinct types?

**RQ2**: What are the empirically validated trade-offs between thin-wrapper newtype patterns versus type aliases in systems programming?

**RQ3**: How do substructural type systems (linear, affine) interact with string/path domain separation?

### Search Strategy

Databases: ACM Digital Library, arXiv, Swift Evolution proposals, Rust RFCs, POPL/ICFP/OOPSLA proceedings.

Search terms: "path type safety", "newtype pattern systems programming", "string type separation", "phantom type file path", "substructural string types", "linear type string", "affine type ownership".

### Inclusion/Exclusion Criteria

**Included**: Peer-reviewed publications and accepted language proposals addressing type-level separation of string domains, ownership-based string safety, or path type design.

**Excluded**: Tutorial content, language documentation (used in prior art survey instead), unpublished manuscripts.

### Key Findings

#### F1: Newtype Pattern as Semantic Differentiation (Yallop & White, 2014; Eisenberg et al., 2020)

The newtype pattern — wrapping a type in a zero-cost abstraction to create a distinct type — is well-established in Haskell (`newtype`) and Rust (`struct Wrapper(Inner)`). The theoretical justification is **nominal typing**: two types with identical representation may have different semantics and should be distinguished in the type system.

Applied to our context: `Kernel.Path` and `String_Primitives.String` have identical representation but different **semantic contracts**:
- `String_Primitives.String`: arbitrary OS-native null-terminated string.
- `Kernel.Path`: a string that represents a filesystem path, with additional invariants (no interior NULs when created from Swift.String, valid for use with path syscalls).

The newtype pattern makes these contracts distinguishable at the type level.

#### F2: Substructural Types and Ownership (Walker, 2005; Tov & Pucella, 2011)

Linear and affine type systems provide the theoretical foundation for ~Copyable semantics. In the context of string types:

- **Linearity** ensures each string buffer has exactly one owner (preventing double-free).
- **Non-escapability** (~Escapable) ensures borrowed views cannot outlive their backing storage (preventing use-after-free).

These properties are orthogonal to domain separation. Both `Kernel.Path` and `String_Primitives.String` correctly apply substructural constraints regardless of whether they are unified.

#### F3: Phantom Types for Domain Tagging (Leijen & Meijer, 1999; Fluet & Pucella, 2006)

An alternative to newtypes is phantom type parameters: `String<Domain>` where `Domain` is `PathDomain`, `CStringDomain`, etc. This achieves type-level separation without runtime cost and allows generic programming over all string domains.

**Trade-off**: Phantom types require the base type to be generic, which interacts poorly with ~Copyable in current Swift (generic types with ~Copyable constraints have limited compiler support).

#### F4: Cognitive Dimensions of API Design (Green & Petre, 1996; Clarke, 2004)

The Cognitive Dimensions Framework identifies relevant trade-offs:

| Dimension | Fewer Types (unify) | More Types (separate) |
|-----------|--------------------|-----------------------|
| **Viscosity** (cost of change) | Lower: fewer conversions | Higher: must convert at boundaries |
| **Visibility** (what can be seen) | Lower: domain implicit | Higher: domain in the type |
| **Error-proneness** | Higher: wrong domain undetected | Lower: type system catches misuse |
| **Abstraction** | Lower: one concept | Higher: multiple concepts to learn |
| **Role-expressiveness** | Lower: string could be anything | Higher: type reveals intent |

For infrastructure code where correctness is paramount and the audience is experienced, the literature favors **more types** (higher role-expressiveness, lower error-proneness) over fewer types (lower viscosity, lower abstraction barrier).

### Screening Summary

| Source Category | Found | Screened | Included |
|----------------|-------|----------|----------|
| Type theory (newtypes, phantom types) | 12 | 8 | 4 |
| Substructural types (linear, affine) | 9 | 6 | 3 |
| API usability (cognitive dimensions) | 7 | 5 | 2 |
| Language design (Rust RFCs, Swift Evolution) | 15 | 10 | 5 |
| Systems programming paths | 8 | 5 | 2 |
| **Total** | **51** | **34** | **16** |

---

## Formal Semantics

### Type Definitions

We model the string/path type family using a stratified type system with ownership annotations.

#### Base Types

Let `Char_posix = UInt8` and `Char_windows = UInt16`. Define the platform-conditional character type:

```
Char ≜ Char_posix     if POSIX
      | Char_windows   if Windows
```

#### Owned Types (Affine)

An affine type can be used at most once (consumed or dropped, never duplicated):

```
τ_owned ::= String_Prim    : Affine(Ptr<Char> × Nat)
           | ISO_9899_Str   : Affine(Ptr<UInt8> × Nat)
           | Kernel_Path    : Affine(String_Prim)
```

Type formation rules:

```
                  Γ ⊢ ptr : Ptr<Char>    Γ ⊢ n : Nat
[String-Form]    ─────────────────────────────────────
                  Γ ⊢ String_Prim(ptr, n) : String_Prim

                  Γ ⊢ s : String_Prim
[Path-Form]      ─────────────────────
                  Γ ⊢ Kernel_Path(s) : Kernel_Path
```

The critical question: **is [Path-Form] justified?** Since `Kernel_Path` wraps `String_Prim` with no additional stored state, type-theoretically this is a **newtype** — isomorphic to `String_Prim` at the value level but distinct at the type level.

#### View Types (Affine + Non-Escapable)

View types are both affine (no duplication) and region-bounded (cannot outlive their origin):

```
τ_view ::= String_Prim_View  : Affine ∩ Regional(Ptr<Char>)
          | ISO_9899_View     : Affine ∩ Regional(Ptr<UInt8>)
          | Kernel_Path_View  : Affine ∩ Regional(Ptr<Char>)
          | Path_View         : Affine ∩ Regional(Ptr<Char>)
```

Region constraint:

```
                  Γ ⊢ v : τ_view    lifetime(v) ⊆ lifetime(origin(v))
[Region-Sound]   ──────────────────────────────────────────────────
                  Γ ⊢ use(v) : R
```

#### Foundations Type (Copyable)

```
τ_path ::= Path : Copy(Array<Char>)
```

The foundations `Path` escapes the affine discipline by using a Copyable array buffer instead of a unique pointer. This is the **layer boundary crossing**: affine primitives → copyable foundations.

### Subtyping / Conversion Relations

Define conversion relations (not subtyping — these allocate or borrow):

```
                                allocates
String_Prim ────────────────────────────→ Path
     ↑                                      │
     │ wraps (zero-cost)                     │ borrows (zero-cost)
     │                                       ↓
Kernel_Path ←───────────────────────────── Path_View
                   via withKernelPath

            encoding-dependent
ISO_9899_Str ←─────────────────→ String_Prim
              POSIX: byte copy
              Windows: via Swift.String (lossy boundary)
```

### Soundness Argument

**Claim**: The current type architecture is sound — no operation can violate memory safety.

**Proof sketch**:

1. **No double-free**: All owned types (`String_Prim`, `ISO_9899_Str`, `Kernel_Path`) are affine (~Copyable). The compiler ensures at most one consumption. `deinit` deallocates exactly once.

2. **No use-after-free**: All view types are both affine and regionally bounded (~Escapable). The compiler ensures views cannot outlive their backing storage. `withView`/`withKernelPath` closure patterns enforce lexical scoping.

3. **No dangling pointer**: The `take()` operation consumes the owned type and transfers the pointer, preventing subsequent access through the original binding. The `adopting:` initializer documents the ownership transfer.

4. **Conversion safety**: `String → Kernel.Path.View` conversion through `Kernel.Path.scope` validates for interior NULs (throws `Conversion.Error`) before creating a temporary buffer. The buffer is deallocated in `defer` even if the body throws.

5. **Layer boundary**: `Path` (Copyable) → `Kernel.Path.View` (~Copyable, ~Escapable) via `withKernelPath` correctly scopes the non-escapable view within the closure. The Copyable `Path` cannot be invalidated during the borrow because `withKernelPath` borrows `self`.

**The newtype wrapping is sound**: `Kernel_Path(s)` for `s : String_Prim` introduces no new unsafe operations. It restricts the interface (removes `init(ascii:)`, renames `withUnsafePointer` to `withUnsafeCString`) to match the path domain.

---

## Analysis

### Current State Inventory

#### Layer 1: String_Primitives.String

**Role**: OS-native null-terminated string. The foundational allocation unit.

**Structure**:
```swift
public struct String: ~Copyable, @unchecked Sendable {
    let pointer: UnsafePointer<Char>  // UInt8 on POSIX, UInt16 on Windows
    public let count: Int
}
```

**View**: `String.View` (~Copyable, ~Escapable) — borrowed access with compile-time lifetime bounds.

**Operations**: `withUnsafePointer`, `view`, `span`, `take()`, `init(adopting:count:)`, `init(copying:)`, `init(ascii:)`.

#### Layer 1: Kernel.Path

**Role**: Filesystem path for kernel syscall interop.

**Structure**:
```swift
public struct Path: ~Copyable, @unchecked Sendable {
    var _storage: String_Primitives.String  // ← wraps String_Primitives.String
}
```

**View**: `Kernel.Path.View` (~Copyable, ~Escapable) — separate implementation from `String_Primitives.String.View` but structurally identical.

**Additional namespaces on Kernel.Path**:
- `.String.Scope` — scoped Swift.String → Kernel.Path.View conversion with `callAsFunction` pattern.
- `.Canonical` — path canonicalization (delegates to ISO 9945 on POSIX, Windows primitives on Windows).
- `.Resolution` — path resolution error domain.

**Delegated operations**: `count`, `bytes` (→ `span`), `withUnsafeCString` (→ `withUnsafePointer`), `take()`.

**Added operations**: `withView(_:)` (scoped View access), `init(copying view: String_Primitives.String.View)`.

#### Layer 2: ISO_9899.String

**Role**: C byte string per ISO/IEC 9899.

**Structure**:
```swift
public struct String: ~Copyable {
    let pointer: UnsafeMutablePointer<Char>  // Always UInt8
    public let count: Int
}
```

**Key difference from String_Primitives.String**: `Char` is always `UInt8` regardless of platform. On Windows, `ISO_9899.String` and `String_Primitives.String` have different `Char` types (`UInt8` vs `UInt16`), making them non-interchangeable. On POSIX, both are `UInt8` and direct byte-copy conversion is available.

#### Layer 3: Path (Foundations)

**Role**: User-facing Copyable path with high-level navigation.

**Structure**:
```swift
public struct Path: Copyable, Sendable, Hashable {
    var _storage: Storage  // wraps [Char] array
}
```

**Operations**: `components`, `parent`, `lastComponent`, `extension` (get/set), `stem`, `isAbsolute`, `isRoot`, `appending(_:)`, `/` operator, `hasPrefix(_:)`, `relative(to:)`, `withKernelPath(_:)`, `withView(_:)`.

**Bridge to Layer 1**: `withKernelPath` creates a `Kernel.Path.View` from the internal buffer pointer — zero allocation on POSIX.

#### Layer 3: Strings (Bridging)

**Role**: Cross-domain conversion between Swift.String, ISO_9899.String, and String_Primitives.String.

**Conversions provided**:
- `Swift.String` ↔ `String_Primitives.String` (all platforms)
- `Swift.String` ↔ `ISO_9899.String` (all platforms)
- `ISO_9899.String` ↔ `String_Primitives.String` (POSIX only; Windows requires transit through `Swift.String`)

---

### Option A: Status Quo — Keep All Five Types

Maintain the current architecture: `String_Primitives.String`, `Kernel.Path`, `ISO_9899.String`, `Path`, and `Strings` bridging.

**Advantages**:
- Maximum type-level domain separation. A `Kernel.Path` cannot be accidentally used where a `ISO_9899.String` is expected.
- Follows Rust's precedent of thin-wrapper newtypes for paths.
- Each type has a clear semantic role documented in existing research.
- `Kernel.Path.View` as a syscall parameter type communicates intent: "this is a path for the kernel."
- The `Kernel.Path.String.Scope` namespace is well-placed on the path type, not on `String_Primitives.String`.

**Disadvantages**:
- `Kernel.Path` adds ~150 lines of delegation code with no stored state beyond `String_Primitives.String`.
- Two nearly identical View types (`String_Primitives.String.View` and `Kernel.Path.View`) with duplicated debug validation logic.
- Users must understand the difference between `Kernel.Path` and `String_Primitives.String` even though they have identical runtime representation.
- The `Kernel.Path.View` vs `String_Primitives.String.View` distinction provides no compile-time safety benefit — both accept raw `UnsafePointer<Char>` and no syscall signature distinguishes between them.

### Option B: Merge Kernel.Path into String_Primitives.String

Make `Kernel.Path` a typealias for `String_Primitives.String`. Move the `Canonical`, `Resolution`, and `String.Scope` namespaces to either `Kernel` directly or to `String_Primitives.String` extensions.

**Advantages**:
- Eliminates ~150 lines of pure delegation.
- Single View type reduces maintenance burden.
- Simpler mental model: one OS-native string type, one C string type.

**Disadvantages**:
- Loses type-level distinction between "arbitrary OS string" and "filesystem path". A function accepting `String_Primitives.String` cannot signal that it specifically expects a path.
- The `Kernel.Path.String.Scope` (callAsFunction for scoped conversion) makes semantic sense on a `Path` type but less on a generic `String` type.
- The `Canonical` and `Resolution` namespaces are path-specific concepts. Attaching them to a generic string type violates the principle that types should have cohesive responsibilities.
- Breaks existing API contracts. Every syscall wrapper currently typed as `borrowing Kernel.Path.View` would need signature changes.

### Option C: Unify View Types, Keep Owned Types Separate

Keep `Kernel.Path` and `String_Primitives.String` as distinct owned types, but unify their View types into a single `String_Primitives.String.View` (or introduce a shared base view).

**Advantages**:
- Eliminates the duplicated View implementation (~80 lines including debug validation).
- Owned types retain domain separation.
- Syscall signatures can accept `String_Primitives.String.View` (the view doesn't carry path semantics — it's just borrowed bytes).

**Disadvantages**:
- Syscall signatures lose the documentation benefit of `Kernel.Path.View` — readers must infer from context that the parameter is a path.
- `Kernel.Path.withView` would return a `String_Primitives.String.View`, which is semantically confusing (you borrow a path, get back a generic string view?).
- Minor: `Kernel.Path.View` currently lives in the Kernel module; sharing `String_Primitives.String.View` means all kernel consumers must import String_Primitives.

### Option D: Phantom-Tagged String Type

Replace both `String_Primitives.String` and `Kernel.Path` with `String_Primitives.String<Tag>` where `Tag` distinguishes domains:

```swift
public struct String<Tag: ~Copyable>: ~Copyable, @unchecked Sendable { ... }
```

**Advantages**:
- Single implementation, multiple type-level identities.
- Generic operations on `String<Tag>` work for all domains.
- Zero runtime cost (phantom type erased at compile time).

**Disadvantages** (revised per experiment `phantom-tagged-string-unification`, 2026-02-25):
- ~~Blocked by compiler constraint C2~~: **REFUTED**. Experiment V1 confirms `deinit` in `PlatformString<Tag: ~Copyable>` works correctly. The C2 constraint (InlineArray + value generic deinit, [COPY-FIX-009]) applies only to InlineArray storage, not pointer-based deinit. V3 confirms `_overrideLifetime` works in generic context. V2 confirms `@_lifetime(borrow)` propagates through generic parameters.
- **[COPY-FIX-003] tax**: Every extension must carry `where Tag: ~Copyable`. Initial build failed with 13 errors from implicit Copyable leakage; all resolved by adding the constraint. This is a maintenance burden but not a blocker — the ecosystem already applies this pattern in 278 packages.
- Potential premature abstraction: `String_Primitives.String` currently has exactly one other user (`Kernel.Path`). However, the experiment confirms the pattern has zero runtime cost and the `where Tag == PathDomain` conditional extensions (V5) cleanly gate path-specific APIs.
- The `Canonical`, `Resolution`, and `String.Scope` namespaces work with `where Tag == PathDomain` gating (V5, V6 confirmed).
- ~~No prior art~~: This experiment IS the prior art. All 9 variants confirmed.

#### Convention-Compliant Naming (v3.0)

The experiment used ad hoc names (`PlatformString`, `PathDomain`, `GenericDomain`). Adjusted per [API-NAME-001], [API-NAME-002], [IMPL-INTENT], and the Tagged conventions from `swift-identity-primitives`:

**Type**: Within the `String Primitives` module, the type is `String<Tag>` — single name, no compound. The existing `String_Primitives.String` gains a phantom parameter. Per [API-NAME-001], the type MUST remain `String`, not `PlatformString` or any compound variant. Experiments used `PlatformString` as an ad hoc name; the convention-compliant name is simply `String<Tag>` (qualified as `String_Primitives.String<Tag>` or `Kernel.String<Tag>` from downstream).

**Domain tags**: Follow the `Memory`/`Memory.Address` pattern — the tag IS the namespace:

```swift
// In kernel-primitives — Kernel.Path is the domain tag (empty ~Copyable enum)
extension Kernel {
    public enum Path: ~Copyable {}
}

// In string-primitives — generic OS string domain
extension String where Tag: ~Copyable {
    public enum Generic: ~Copyable {}
}
```

Usage mirrors `Index<Element>` and `Memory.Address`:

| Ecosystem Pattern | String Equivalent |
|-------------------|-------------------|
| `Index<Element>` — Element is the tag | `String<Kernel.Path>` — `Kernel.Path` is the tag |
| `Memory.Address` = `Tagged<Memory, Ordinal>` | `String<Kernel.Path>` — same phantom discrimination |

**Naming map** (experiment → convention):

| Experiment Name | Convention-Compliant | Rule |
|-----------------|---------------------|------|
| `PlatformString<Tag>` | `String<Tag>` (within module) | [API-NAME-001] — single name |
| `PathDomain` | `Kernel.Path` | [API-NAME-001] — Nest.Name |
| `GenericDomain` | `String.Generic` | [API-NAME-001] — Nest.Name |
| `PlatformStringProtocol` | `String.Protocol` (hoisted) | [API-NAME-001] — Nest.Name |

**Protocol hoisting**: Per `protocol-typealias-hoisting` experiment (protocols cannot nest in generic types — confirmed blocked):

```swift
// Hoisted to module scope
public protocol _StringProtocol: ~Copyable {
    associatedtype Domain: ~Copyable
    var count: Int { get }
}

// Typealiased back
extension String where Tag: ~Copyable {
    public typealias `Protocol` = _StringProtocol
}

// Conformance — mirrors Cardinal.Protocol pattern
extension String: _StringProtocol where Tag: ~Copyable {
    public typealias Domain = Tag
}
```

**Conditional namespaces**: Path-specific operations gated by `where Tag == Kernel.Path`:

```swift
extension String where Tag == Kernel.Path {
    public enum Canonical {}
    public enum Resolution {}
    public var isAbsolute: Bool { ... }
}
```

**View type**: `String<Tag>.View: ~Copyable, ~Escapable` — nested in extension with `where Tag: ~Copyable`. Unchanged from experiment; `@_lifetime` and `_overrideLifetime` confirmed working.

**Property.View**: Verb-like path operations use `Property<Tag, Base>.View` per [IMPL-020]. Data access (`count`, `span`, `withView`) are direct properties — they are not verb operations.

**Not literally Tagged**: `String<Tag>` is a custom struct, not `Tagged<Tag, Storage>`. This mirrors `Property<Tag, Base>` — follows Tagged's phantom-parameter convention but needs its own type because of custom `deinit`, nested `View`, and `@_lifetime` annotations. See Option D' below for the literally-Tagged analysis.

### Option D': Literally `Tagged<Domain, String.Storage>`

An alternative to Option D that makes the string type literally `Tagged<Domain, StringStorage>` rather than a custom struct.

**Structure**:

```swift
// In String Primitives — the raw storage (manages pointer lifecycle)
extension String_Primitives {
    @safe
    public struct StringStorage: ~Copyable, @unchecked Sendable {
        @usableFromInline
        internal let pointer: UnsafePointer<Char>
        public let count: Int

        @inlinable
        deinit {
            unsafe UnsafeMutablePointer(mutating: pointer).deallocate()
        }
    }
}

// The phantom-tagged string IS Tagged
typealias PlatformString<Domain: ~Copyable> = Tagged<Domain, StringStorage>
```

**Feasibility evidence**:

1. **Deinit**: Tagged has no custom `deinit`. Swift's automatic member-wise destruction calls `StringStorage.deinit` when `Tagged<Domain, StringStorage>` is destroyed. Verified: `tagged-noncopyable-rawvalue` experiment confirms `Tagged<Tag, Resource>` where Resource has `deinit`.

2. **Nested types**: Extensions constrained on `RawValue` can define nested types. `extension Tagged where RawValue == StringStorage { struct View: ~Copyable, ~Escapable { ... } }` is valid Swift (nested types in constrained extensions are supported).

3. **Property forwarding**: The ecosystem has 180+ `extension Tagged where RawValue == ...` patterns. `Handle.swift` demonstrates multi-field forwarding (`var index: Int { rawValue.index }`, `var generation: UInt32 { rawValue.generation }`). String properties follow the same pattern:
   ```swift
   extension Tagged where RawValue == StringStorage, Tag: ~Copyable {
       public var count: Int { rawValue.count }
   }
   ```

4. **Free functors**: `.retag()` provides zero-cost domain migration (e.g., demoting a path string to a generic string). `.map()` provides value transformation. Neither needs to be reimplemented.

5. **Free conditional conformances**: `Sendable` (from Tagged line 77, requires `RawValue: Sendable` — `StringStorage` would need `@unchecked Sendable`), `Equatable`, `Hashable` if desired.

**Advantages over Option D**:

| Capability | Option D (Custom Struct) | Option D' (Literally Tagged) |
|-----------|-------------------------|------------------------------|
| `.retag()` domain migration | Must implement manually | Free from Tagged |
| `.map()` value transformation | Must implement manually | Free from Tagged |
| Conditional conformances | Must declare each one | Inherited from Tagged |
| Ecosystem consistency | Follows Tagged pattern | IS Tagged |
| `rawValue` escape hatch | N/A | Available for implementation code |

**Disadvantages**:

1. **`rawValue.` indirection**: Implementation code writes `tagged.rawValue.pointer` instead of `string.pointer`. Mitigated by forwarding extensions, but adds ~5 lines per forwarded property (count, pointer, withView, etc.).

2. **Tagged namespace pollution**: `extension Tagged where RawValue == StringStorage` extensions appear in autocomplete for ALL `Tagged<_, _>` types, even though they only resolve when `RawValue == StringStorage`. This is cosmetic but real.

3. **Init ergonomics**: Tagged's only public init is `init(__unchecked:_:)`. Domain-specific inits like `init(adopting:count:)` must be added as extension methods that construct `StringStorage` internally then wrap in `Tagged`:
   ```swift
   extension Tagged where RawValue == StringStorage, Tag: ~Copyable {
       public init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
           self.init(__unchecked: (), StringStorage(adopting: pointer, count: count))
       }
   }
   ```

4. **View naming**: `Tagged<Kernel.Path, StringStorage>.View` is less readable than `String<Kernel.Path>.View`. Typealiases mitigate but don't eliminate.

5. **Protocol conformance**: `Tagged: _StringProtocol where RawValue == StringStorage` adds a protocol conformance to Tagged itself, which may be surprising — Tagged is a generic infrastructure type gaining domain-specific protocol conformance.

6. **`_storage` access requirement**: Tagged's `rawValue` accessor uses a `_read { yield _storage }` coroutine. This creates a temporary scope boundary that blocks `@_lifetime` propagation for `~Escapable` types. When creating a `View` (which has `@_lifetime(borrow pointer)` on its init), `rawValue.pointer` cannot propagate the lifetime to the outer `body` closure — the `_read` coroutine's yield scope is too narrow. **Must access `_storage` directly**. In production, this means the string module would need either: (a) `_storage` accessible via `@usableFromInline` or same-package placement, (b) a new `withRawValue(_:)` closure-based accessor on Tagged that yields `_storage` with proper lifetime, or (c) a `borrowing` accessor that avoids the `_read` scope boundary.

**Required Tagged improvements for D' to be clean**:

| Improvement | Purpose | Feasibility |
|-------------|---------|-------------|
| `@dynamicMemberLookup` for Copyable properties | Auto-forward `rawValue.count` as `tagged.count` | **Blocked**: `KeyPath<Root, Value>` requires `Root: Copyable` in Swift 6.2. Does not work for `RawValue: ~Copyable`. |
| Macro-generated forwarding | Generate property forwarders from a list | **Possible** but outside current tooling |
| Accept manual forwarding | Write ~5 forwarding computed properties | **Works today** — Handle.swift precedent |
| Lifetime-safe `_storage` access | Enable `~Escapable` View creation without `rawValue._read` scope boundary | **Required**: Same-package placement (string module inside identity-primitives) OR `@usableFromInline _storage` OR new `withRawValue` closure accessor on Tagged |

**Assessment**: D' is technically feasible today. The main friction is the `rawValue.` indirection and the need for forwarding properties. If Swift gains `@dynamicMemberLookup` support for `~Copyable` roots (via non-Copyable KeyPaths), D' becomes strictly superior to D. Until then, the manual forwarding pattern (Handle.swift precedent, ~5 properties) is acceptable but adds boilerplate that Option D avoids.

### Option E: Refine Status Quo — Deduplicate Internals

Keep all five types with their current public APIs, but refactor internal implementation to reduce duplication:
1. Have `Kernel.Path.View` delegate to `String_Primitives.String.View` internally (or vice versa).
2. Extract shared debug validation into a single internal function.
3. Document the intentional structural duplication in code comments.

**Advantages**:
- No public API changes.
- Reduces internal maintenance burden (shared debug validation, shared length calculation).
- Preserves all type-level domain separation benefits.
- Minimal risk — internal refactoring only.

**Disadvantages**:
- Still maintains two View types publicly, which may confuse contributors.
- Doesn't address the fundamental question of whether the separation is justified.

---

### Import-Level Shadowing: The MemberImportVisibility Constraint (v3.1)

A sixth cross-cutting concern applies to ALL options: `String_Primitives.String` shadows `Swift.String` throughout the ecosystem because `Kernel_Primitives/Exports.swift` uses `@_exported public import String_Primitives`. Any module importing `Kernel_Primitives` (directly or transitively via `Kernel`) resolves bare `String` to `String_Primitives.String` (~Copyable), not `Swift.String`.

**The naive fix — stop re-exporting** was tested empirically:

**Experiment**: `typealias-without-reexport` (2026-02-27). Three modules simulating the ecosystem: `StringLike` (String_Primitives), `KernelLike` (Kernel_Primitives with `public import` instead of `@_exported`), `Consumer` (downstream).

**Hypothesis**: Removing `@_exported` from `String_Primitives` while retaining a `Kernel.String` typealias would allow bare `String` to resolve to `Swift.String` in downstream modules while preserving access through the namespace.

**Result**: PARTIALLY REFUTED. MemberImportVisibility (SE-0444) creates an inescapable tension:

| Variant | Configuration | Bare `String` | Member Access | Verdict |
|---------|--------------|---------------|---------------|---------|
| V1 | No `StringLike` import | `Swift.String` | N/A | CONFIRMED |
| V2 | Typealias `Kernel.String` only | `Swift.String` | **ALL blocked** — init, properties, methods | REFUTED |
| V3 | `Kernel.String.Char` nested type | — | **Blocked** | REFUTED |
| V5 | Extension methods through alias | — | **Blocked** | REFUTED |
| V7 | Function signatures only | `Swift.String` | Type-level only, no members | CONFIRMED |

**The structural impossibility**: MemberImportVisibility requires that the *defining module* be imported (directly or via `@_exported`) for ANY member access — initializers, properties, methods, nested types. A typealias alone provides type-level visibility but zero member access. Adding `internal import StringLike` restores member access but re-introduces shadowing (bare `String` resolves to `StringLike.String` again).

**Why this matters for the Option analysis**:

- **Options A/E (Status Quo / Refine)**: The shadowing problem cannot be solved at the import level. Downstream modules that import `Kernel` will always have `String_Primitives.String` shadow `Swift.String`. This is an inherent cost of using `String` as the type name — every call site must use `Swift.String` qualification.

- **Options D/D' (Phantom-Tagged)**: If the type is `String<Tag>`, bare `String` without a generic parameter is ambiguous and the compiler prompts for disambiguation. The phantom parameter provides a natural syntactic boundary: `String<Kernel.Path>` is visually and semantically distinct from `Swift.String`. Shadowing becomes a *feature* of the design — the generic parameter IS the disambiguation.

- **This strengthens the case for D/D'**: Shadowing is not merely an aesthetic annoyance but a structural property of the current architecture that cannot be solved with import-level mechanisms. A phantom-tagged type resolves it by construction.

### Comparison

| Criterion | A: Status Quo | B: Merge | C: Unify Views | D: Phantom | D': Tagged | E: Refine |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|
| **Type safety** (domain separation) | ++ | - | + | ++ | ++ | ++ |
| **Simplicity** (fewer concepts) | - | ++ | + | - | - | - |
| **Maintenance** (code duplication) | -- | ++ | + | ++ | ++ | + |
| **API stability** (no breaking changes) | ++ | -- | - | -- | -- | ++ |
| **Compiler compatibility** (C1–C5) | ++ | ++ | ++ | + | + | ++ |
| **Namespace cohesion** (Canonical on Path) | ++ | - | ++ | + | ± | ++ |
| **Syscall readability** (View parameter names) | ++ | + | - | ++ | + | ++ |
| **Documentation clarity** | + | + | - | - | - | + |
| **Precedent alignment** (Rust, etc.) | ++ | - | ± | ± | ± | ++ |
| **Ecosystem consistency** (uses Tagged) | - | - | - | ± | ++ | - |
| **Free functors** (.retag, .map) | - | - | - | - | ++ | - |
| **Property access ergonomics** | ++ | ++ | ++ | ++ | - | ++ |
| **Shadowing resolution** (v3.1) | -- | -- | -- | ++ | ++ | -- |

### Evaluation Criteria Weights

For timeless infrastructure:
1. **Type safety** — highest. A misused path is a security vulnerability.
2. **API stability** — very high. Breaking changes propagate across the entire ecosystem.
3. **Namespace cohesion** — high. Path-specific operations should live on path types.
4. **Compiler compatibility** — high. Must work today.
5. **Shadowing resolution** — high (v3.1). Bare `String` resolving to ~Copyable `String_Primitives.String` instead of `Swift.String` causes downstream compilation failures. Import-level fixes are structurally impossible (MemberImportVisibility). Only phantom-tagged options resolve this by construction.
6. **Maintenance** — medium. Internal duplication is manageable.
7. **Simplicity** — medium. The audience is experienced systems programmers.

---

## Empirical Validation (Cognitive Dimensions)

Evaluating against the Cognitive Dimensions Framework (Green & Petre, 1996):

| Dimension | A/E (Separate) | B (Merge) |
|-----------|:-:|:-:|
| **Visibility** | High: `Kernel.Path.View` in a signature tells you "this is a path" | Low: `String_Primitives.String.View` could be anything |
| **Role-expressiveness** | High: type name encodes domain | Low: must read docs/context |
| **Consistency** | High: mirrors Rust's Path/OsStr pattern | Medium: fewer types but mixed responsibilities |
| **Error-proneness** | Low: compiler catches domain misuse | Higher: nothing prevents passing arbitrary string as path |
| **Viscosity** | Higher: conversions needed at boundaries | Lower: fewer conversions |
| **Abstraction barrier** | Higher: more concepts | Lower: fewer concepts |

For infrastructure code with experienced audience, **visibility** and **role-expressiveness** dominate. The literature (Clarke, 2004) confirms that role-expressiveness is the strongest predictor of API usability for expert users.

---

## Cross-Reference: ~Copyable Ecosystem and Experimental Features

The string/path type architecture depends on three experimental Swift features that are enabled across 278 Package.swift files in the ecosystem. This section analyzes how these features interact with the unification question and what constraints they impose.

### Feature Dependencies

All string and path types depend on these experimental features:

| Feature | Purpose | Packages Enabled |
|---------|---------|-----------------|
| `Lifetimes` | `@_lifetime` annotations for ~Escapable types | 303 targets |
| `SuppressedAssociatedTypes` | `associatedtype X: ~Copyable` in protocols | 278 targets |
| `SuppressedAssociatedTypesWithDefaults` | Default associated types with ~Copyable | 278 targets (always paired) |

The ecosystem embraces `SuppressedAssociatedTypes` as a production pattern. It is not experimental in intent — it is foundational infrastructure that 100% of packages depend on.

### How Lifetimes Shapes the View Architecture

Every View type in the string/path family uses `@_lifetime` annotations:

```swift
// String_Primitives.String.View — init binds to pointer lifetime
@_lifetime(borrow pointer)
public init(_ pointer: UnsafePointer<String.Char>)

// String_Primitives.String.View — span copies view lifetime
public var span: Span<String.Char> {
    @_lifetime(copy self) borrowing get { ... }
}

// Kernel.Path.View — identical pattern
@_lifetime(borrow pointer)
public init(_ pointer: UnsafePointer<Kernel.Path.Char>)

// Path.View (Foundations) — extended with owned-Path init
@_lifetime(borrow path)
public init(borrowing path: borrowing Path)
```

**Three `@_lifetime` patterns emerge**:

| Pattern | Usage | Count (ecosystem-wide) |
|---------|-------|----------------------|
| `@_lifetime(&self)` | Mutating accessors returning borrowed views | 206 |
| `@_lifetime(borrow X)` | Constructor lifetime from parameter | 100+ |
| `@_lifetime(copy self)` | Span property getters | 9 |

The View duplication between `String_Primitives.String.View` and `Kernel.Path.View` is not just structural — both apply identical `@_lifetime(borrow pointer)` annotations. This strengthens the case for deduplication (Action 1 in Outcome), since the lifetime semantics are identical.

### How SuppressedAssociatedTypes Enables the Domain Pattern

The ecosystem's phantom-typed protocol abstraction pattern — proven in Cardinal.Protocol, Ordinal.Protocol, and Affine.Discrete.Vector.Protocol — uses `SuppressedAssociatedTypes` to declare `associatedtype Domain: ~Copyable`. This pattern is directly relevant to Option D (phantom-tagged string):

```swift
// Existing production pattern (cardinal-primitives):
extension Cardinal {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable  // ← requires SuppressedAssociatedTypes
        var cardinal: Cardinal { get }
    }
}

// Hypothetical string/path analog:
extension String_Primitives {
    public protocol StringProtocol: ~Copyable {
        associatedtype Domain: ~Copyable  // PathDomain, GenericDomain, etc.
        var count: Int { get }
    }
}
```

**However**, applying this pattern to string/path types faces compiler limitations that the arithmetic types do not:

1. **`deinit` in generic ~Copyable types**: Cardinal/Ordinal are value types without custom `deinit`. String types require `deinit` to deallocate their pointer. Generic `String<Tag: ~Copyable>` with `deinit` triggers issues when `Tag` is ~Copyable (InlineArray + value generic deinit bug, [COPY-FIX-009]).

2. **`_overrideLifetime` in generic contexts**: The 28 `_overrideLifetime` call sites that enable Span interop have not been tested with phantom-tagged generic types. The `@_lifetime` annotation system may not propagate correctly through generic parameters.

3. **Conditional namespace extensions**: `Kernel.Path.Canonical` would need `where Domain == PathDomain` gating, which adds complexity without clear benefit for exactly two clients.

**Assessment**: SuppressedAssociatedTypes enables the Domain pattern in principle, but the string/path types have `deinit`, `@_lifetime`, and `_overrideLifetime` requirements that make phantom-tagging fragile under current compiler constraints. The Domain pattern works for "data carrier" types (Cardinal, Ordinal) but not for "resource owner" types (String, Path) — yet.

### Active Compiler Constraints on String/Path Design

Five documented compiler limitations directly constrain the string/path architecture:

#### C1: Closure Integration Gap

`~Escapable` values cannot be passed to closure parameters (Swift 6.2). This is why the ecosystem uses the yielding model (599 sites) rather than the returning model (28 sites) at a 21:1 ratio.

**Impact on string/path**: The `withView`, `withKernelPath`, and `withUnsafeCString` closure-scoped APIs are the *only* way to expose `~Escapable` views. A more ergonomic API — returning a `~Escapable` view directly — is blocked.

**If lifted**: View types could be returned directly from properties rather than requiring closure wrappers. This would eliminate the need for separate `withView` methods on both `Kernel.Path` and `String_Primitives.String`, reducing the delegation surface.

#### C2: `~Escapable` in `deinit`

Cannot use `~Escapable` values in `deinit` except through the `@_unsafeNonescapableResult get` workaround. The natural `_read` accessor pattern crashes the compiler (`LifetimeDependenceUtils.swift:173` assertion).

**Impact on string/path**: String types that use inline storage cannot safely deinitialize elements through `~Escapable` view types. Not currently a constraint for the null-terminated string types (which deallocate a single buffer), but would constrain future string types with element-level cleanup.

#### C3: SIL Verifier Double-Consume (#87029)

`_read` accessors that yield `~Escapable` values with `@_lifetime(borrow)` trigger a double-consume crash in the SIL verifier on open-source toolchains.

**Impact on string/path**: Cannot use `_read` accessors for View properties. Must use `get` (which returns an owned copy) or closure-based `withView` patterns. This forces the existing closure-scoped API design.

#### C4: DiagnoseStaticExclusivity Crash Through Enum Payloads

Borrowing through `@frozen ~Copyable` enum case to a property with `_overrideLifetime` causes null pointer or out-of-bounds access in the SIL pass.

**Impact on string/path**: If string types ever adopt small-string optimization (inline enum + heap pointer), `Span` access through enum payloads requires manual pointer extraction — cannot delegate through enum cases. The workaround adds ~15 lines of unsafe pointer arithmetic per accessor.

#### C5: Multi-File Emit-Module Bug (#86669)

Compound ~Copyable constraints + `UnsafeMutablePointer` + Sequence conformance + borrowing closure in separate file + library target + Lifetimes flag causes emit-module failure.

**Impact on string/path**: String types that conform to Sequence with ~Copyable elements may need source consolidation (single-file workaround). This could constrain the one-type-per-file requirement [API-IMPL-005].

### Constraints Table Summary

| Constraint | Blocks Option | Removal Trigger |
|-----------|--------------|-----------------|
| C1: Closure gap | All options equally (forces withView pattern) | ~Escapable closure parameter support |
| ~~C2: ~Escapable in deinit~~ | ~~D (phantom generic deinit)~~ | **REFUTED** — V1 confirms pointer-based deinit works in generic ~Copyable. C2 applies only to InlineArray + value generic, not phantom-tagged pointers. |
| C3: SIL verifier #87029 | View property return (all options) | SIL fix for double-consume |
| C4: Enum exclusivity | Small-string optimization (future) | DiagnoseStaticExclusivity fix |
| C5: Multi-file emit | Sequence conformance (all options) | Emit-module fix |

### Reassessment of Option D in Light of SuppressedAssociatedTypes

The `protocol-abstraction-for-phantom-typed-wrappers.md` research (IMPLEMENTED, v1.4.0) demonstrates that `associatedtype Domain: ~Copyable` works in production for arithmetic types. The `witness-noncopyable-nonescapable-support.md` research (v2.0.0) establishes the **bifurcation theorem**: service references must be Copyable; resources vended by services may be ~Copyable.

Applied to strings/paths, this bifurcation maps naturally:

| Role | Copyability | Example |
|------|-------------|---------|
| Container reference | Copyable | `Path` (foundations), `Swift.String` |
| Owned resource | ~Copyable | `String_Primitives.String`, `Kernel.Path`, `ISO_9899.String` |
| Borrowed view | ~Copyable, ~Escapable | All `.View` types |

The Domain pattern would need to cross the bifurcation boundary: a `StringProtocol` with `Domain: ~Copyable` would need to accommodate both Copyable containers (`Path`) and ~Copyable resources (`Kernel.Path`). This is the **Cardinal/Ordinal pattern exactly** — bare type (Copyable, Domain = Never) and Tagged type (~Copyable tag, Domain = Tag).

**Revised assessment (v2.0, post-experiment)**: Option D is not just theoretically sound — it is **empirically validated**. The `phantom-tagged-string-unification` experiment (2026-02-25) confirmed all 9 variants including `deinit`, `@_lifetime`, `_overrideLifetime`, `~Escapable` View, conditional namespaces, `callAsFunction` scope, and protocol Domain conformance. Constraint C2 was **incorrectly assessed** as blocking pointer-based deinit — it only blocks InlineArray + value generic deinit ([COPY-FIX-009]). The remaining question is not technical feasibility but design judgment: is phantom-tagging justified for 2 clients, or should it wait for a third/fourth domain?

### Yielding vs Returning: Implications for View Deduplication

The `yielding-vs-returning-lifetime-models.md` research (v2.0.0) documents two coexisting lifetime models:

| Model | Sites | Unsafe | Used By |
|-------|-------|--------|---------|
| Yielding (`_read`/`_modify`) | 599 | 0 | Property.View, collection accessors |
| Returning (`@_lifetime` + `_overrideLifetime`) | 28 | 28 | Span/MutableSpan interop |

String and path View types use the **returning model** for their `span` properties (which return `Span<Char>` via `_overrideLifetime`), but the **yielding model** for their `withView`/`withUnsafePointer` closures.

**For deduplication (Action 1)**: Both `String_Primitives.String.View` and `Kernel.Path.View` use identical returning-model patterns for `span`. The `_overrideLifetime` calls are structurally identical:

```swift
// String_Primitives.String.View:
@_lifetime(copy self) borrowing get {
    let span = unsafe Span(_unsafeStart: pointer, count: length)
    return unsafe _overrideLifetime(span, copying: self)
}

// Kernel.Path.View:
// Same pattern, same unsafe surface
```

This confirms that internal deduplication is safe — the lifetime semantics are identical, not merely similar. A shared internal function for both debug validation and span construction would reduce the 28 `_overrideLifetime` sites by 2 (minor but directionally correct).

---

## Outcome

**Status**: IN_PROGRESS

### Revised Recommendation (v3.1): Option D' Preferred Direction

The `phantom-tagged-string-unification` experiment (2026-02-25) **refuted** the primary technical objection to Option D. All 9 variants confirmed:

| Variant | Capability | Result |
|---------|-----------|--------|
| V1 | ~Copyable generic + phantom tag + `deinit` | CONFIRMED |
| V2 | ~Escapable View + `@_lifetime` in generic context | CONFIRMED |
| V3 | `_overrideLifetime` + Span in generic context | CONFIRMED |
| V4 | `@unchecked Sendable` on generic ~Copyable | CONFIRMED |
| V5 | Conditional namespace extensions (`where Tag == PathDomain`) | CONFIRMED |
| V6 | Scoped `callAsFunction` conversion with phantom tag | CONFIRMED |
| V7 | Protocol `Domain: ~Copyable` + PlatformString conformance | CONFIRMED |
| V8 | Typealiases carrying conditional extensions | CONFIRMED |
| V9 | Cross-domain mixing rejected at compile time | CONFIRMED |

This means the ecosystem has **two viable paths forward**, both technically sound:

### Option E — Refine Status Quo (Conservative)

**Rationale**:

1. **The newtype wrapping is theoretically justified** (F1, formal semantics). `Kernel.Path` and `String_Primitives.String` have identical representation but different semantic contracts. The type system should distinguish them.

2. **No breaking changes**. Options B, C, and D all require changing public API signatures that propagate across the ecosystem. For timeless infrastructure, stability is paramount.

3. **Namespace cohesion is preserved**. `Kernel.Path.Canonical`, `Kernel.Path.Resolution`, and `Kernel.Path.String.Scope` are path-specific concepts that belong on a path type, not a generic string type.

4. **Prior art supports it**. Rust's `Path`/`PathBuf` as a thin wrapper over `OsStr`/`OsString` is the closest analog and has been successful in practice despite similar "thin wrapper" concerns.

5. **Internal deduplication is achievable** without public API changes. The View types can share validation logic through internal helper functions.

### Option D — Phantom-Tagged Unification (Progressive)

**Rationale**:

1. **Empirically validated**. All compiler features work today: `deinit`, `@_lifetime`, `_overrideLifetime`, `~Escapable` views, `@unchecked Sendable`, conditional namespaces, `callAsFunction` scope, protocol Domain conformance, and typealiases.

2. **Eliminates all code duplication**. Single `PlatformString<Tag>` implementation replaces both `String_Primitives.String` and `Kernel.Path`. Single `View` type replaces both `String_Primitives.String.View` and `Kernel.Path.View`. Zero delegation code.

3. **Preserves all type safety**. `PlatformString<PathDomain>` and `PlatformString<GenericDomain>` are distinct types. Cross-domain mixing is rejected at compile time with clear diagnostics. Path-specific APIs (`Canonical`, `Resolution`, `scope`) are gated by `where Tag == PathDomain`.

4. **Follows ecosystem precedent**. The Domain pattern is production-proven in Cardinal.Protocol, Ordinal.Protocol, and Affine.Discrete.Vector.Protocol. This extends it from data carriers to resource owners.

5. **Typealiases preserve ergonomics**. `typealias KernelPath = PlatformString<PathDomain>` makes call sites identical to the current API.

**Costs**:

1. **Breaking change**. Every consumer of `Kernel.Path` and `String_Primitives.String` must update. This is a significant migration.

2. **[COPY-FIX-003] maintenance tax**. Every extension requires `where Tag: ~Copyable`. The ecosystem already bears this cost in 278 packages, but string types have many extensions.

3. **Premature for 2 clients**. The phantom-tagged pattern shines when there are many domain variants. With exactly 2 (`PathDomain`, `GenericDomain`), the newtype approach is simpler.

4. **Release-mode CopyPropagation crash (#87029)**. V6 (scoped `callAsFunction` creating ~Escapable View from locally-allocated buffer) crashes in the CopyPropagation SIL pass during release builds. The `mark_dependence [nonescaping]` + `destroy_value` double-consume triggers "Found over consume?!" in `LinearLifetimeChecker`. Workaround: `@_optimize(none)` on affected methods — same workaround already applied to 6 functions in the primitives ecosystem. Documented removal trigger: when Swift fixes the SIL verifier for `~Escapable` values with `mark_dependence [nonescaping]`.

### Option D' — Literally Tagged (v3.1)

**Rationale**: If the ecosystem already uses `Tagged<Tag, RawValue>` as the universal phantom-typed wrapper (278 packages), using it literally for strings would maximize consistency and provide `.retag()` / `.map()` for free.

**Status**: **VALIDATED**. Experiment `tagged-string-literal` (2026-02-25) confirms all 10 variants in both debug and release modes. All capabilities from the original `phantom-tagged-string-unification` experiment transfer to literal `Tagged<Domain, StringStorage>`, plus V8 (.retag) and V9 (.map) are free from Tagged infrastructure. V6 (callAsFunction with ~Escapable View) requires `@_optimize(none)` workaround for CopyPropagation #87029 in release mode — same workaround already applied across 6 functions in the primitives ecosystem.

**Critical finding**: Tagged's `rawValue` `_read` coroutine creates a lifetime scope boundary that blocks `@_lifetime` propagation for `~Escapable` types. Implementation code must access `_storage` directly (not through `rawValue`). This requires either same-package placement or `@usableFromInline` access to Tagged's internal `_storage` field. **Status (2026-02-27)**: Unresolved. Tagged's `_storage` remains `internal`, and `rawValue` still uses `_read { yield _storage }`. `Memory.Contiguous` demonstrates the correct pattern (direct `@_lifetime(borrow self)` property access), but this pattern has not been applied to Tagged.

**Naming (v3.1)**: Per [API-NAME-001], the type MUST be `String<Tag>` — not `PlatformString<Tag>` as used in experiments. The `String` name is intentionally retained: it IS a string, and the phantom parameter IS the disambiguation mechanism. This directly resolves the shadowing problem documented in the MemberImportVisibility analysis: bare `String` without a generic parameter triggers compiler disambiguation, while `String<Kernel.Path>` and `Swift.String` are syntactically unambiguous.

**Strengthened case (v3.1)**: The `typealias-without-reexport` experiment (2026-02-27) proved that import-level solutions to `Swift.String` shadowing are structurally impossible under MemberImportVisibility. This eliminates the "just fix the imports" alternative and makes D/D' the only paths that resolve shadowing by construction.

**D vs D' decision matrix**:

| Factor | D (Custom Struct) | D' (Literally Tagged) | Winner |
|--------|-------------------|----------------------|--------|
| `.retag()` for domain migration | Must implement | Free | D' |
| `.map()` for value transformation | Must implement | Free | D' |
| Conditional conformances | Must declare | Inherited | D' |
| Property access (`string.count`) | Direct | Via forwarding extension | D |
| Nested View ergonomics | `String<Tag>.View` | `Tagged<Tag, Storage>.View` | D |
| Init ergonomics | Custom init | Wraps `__unchecked` init | D |
| Autocomplete noise | None | String extensions visible on all Tagged | D |
| Ecosystem consistency | Follows pattern | IS the pattern | D' |

**Validated**: Experiment `tagged-string-literal` (2026-02-25) confirms all 10 variants (9 from original + 2 new Tagged-free capabilities: .retag domain migration, .map value transformation). Debug and release both pass. Release requires `@_optimize(none)` on V6 (CopyPropagation #87029). Additional constraint discovered: `rawValue` `_read` accessor blocks `@_lifetime` propagation — must access `_storage` directly for `~Escapable` View creation.

### Decision Framework

The choice between E, D, and D' depends on three questions:

1. **How many string domains will the ecosystem eventually have?**
2. **Is ecosystem consistency (literally Tagged) worth the forwarding boilerplate?**
3. **Is the `Swift.String` shadowing cost acceptable?** (v3.1 — empirically shown to be structurally unsolvable at the import level)

| If... | Then... |
|-------|---------|
| Only 2 domains (path, generic) for the foreseeable future | Option E — newtype is simpler |
| 3+ domains expected (path, URL, env, SQL, ...) | Option D or D' — phantom tag prevents combinatorial explosion |
| `.retag()` domain migration is valuable | Option D' — free from Tagged |
| Forwarding boilerplate is unacceptable | Option D — custom struct, direct properties |
| Ecosystem consistency is paramount | Option D' — IS Tagged, not just follows Tagged |
| Migration cost is too high right now | Option E — defer, upgrade path is clear |
| `Swift.String` shadowing must be resolved | Option D or D' — phantom parameter provides natural disambiguation |

### Specific Actions

#### Action 1: Deduplicate View debug validation

Extract the shared `debugValidateTermination` logic into a single internal function in `String_Primitives`, and have `Kernel.Path.View` call it.

**Current duplication**:
- `String_Primitives.String.View.debugValidateTermination(_:)` — `swift-string-primitives/Sources/String Primitives/String.View.swift`
- `Kernel.Path.View.debugValidateTermination(_:)` — `swift-kernel-primitives/Sources/Kernel Primitives/Kernel.Path.View.swift`

Both are identical: scan up to 16 MiB for null terminator, `preconditionFailure` if not found.

#### Action 2: Document the intentional structural parallel

Add a design comment to `Kernel.Path.swift` explaining that the thin wrapper over `String_Primitives.String` is intentional and references this research document.

#### Action 3: Verify ISO_9899.String remains separate

The separation between `ISO_9899.String` (Char = UInt8 always) and `String_Primitives.String` (Char = platform-dependent) is **non-negotiable**. On Windows they have different `Char` types. On POSIX they share `UInt8` but serve different domains (C library interop vs OS path interop). The existing `swift-strings` bridging layer correctly handles this.

#### Action 4: Verify foundations Path correctly bridges

The foundations `Path` type correctly:
- Uses `Copyable` storage (`[Char]` array) — appropriate for a user-facing type.
- Provides `withKernelPath(_:)` for zero-allocation bridge to syscalls.
- Validates input (rejects empty, control characters, interior NUL) — appropriate for a higher-layer type.
- Adds high-level operations (components, parent, extension) — the correct layer for this complexity.

No changes recommended to the foundations `Path` type.

### Future Considerations

1. **Options D and D' are both validated** (2026-02-25). Both experiments (`phantom-tagged-string-unification` for D, `tagged-string-literal` for D') confirm all capabilities in debug and release. The decision is now design judgment, not compiler limitation. If a third string domain emerges (URL strings, environment variable strings, SQL strings), Option D/D' should be adopted immediately. D' requires resolving the `_storage` access constraint (same-package placement, `@usableFromInline`, or new Tagged accessor). **Status (2026-02-27)**: Tagged's `rawValue` still uses `_read { yield _storage }` — unchanged since 2026-02-25. The lifetime scope boundary remains. `Memory.Contiguous.span` correctly uses `@_lifetime(borrow self)` with direct property access (not through `_read`), demonstrating the correct pattern, but Tagged itself has not been updated. Required fix: make `Tagged._storage` `@usableFromInline`, add a lifetime-safe borrowing accessor, or add a `withRawValue(_:)` closure-based accessor. If `@dynamicMemberLookup` gains support for `~Copyable` roots (non-Copyable KeyPaths), D' becomes strictly superior to D.

2. **If the closure integration gap closes**: The `withView`/`withKernelPath` closure-scoped APIs could be supplemented with direct property returns of `~Escapable` views. This would reduce the delegation surface between `Kernel.Path` and `String_Primitives.String` but does not change the fundamental type separation question.

3. **If ~Escapable stabilizes further**: Consider whether `Path.View` (foundations) should delegate to `Kernel.Path.View` directly rather than maintaining a separate implementation. Currently blocked by C3 (SIL verifier crash on `_read` + `~Escapable`).

4. **If `SuppressedAssociatedTypes` is stabilized**: No action needed — the ecosystem already treats it as production infrastructure (278 packages). Stabilization would reduce risk but not change the architecture.

5. **If borrow bindings ship (SE-0507)**: Named access to yielded `~Escapable` values (`borrow v = path.view`) would make the View types more ergonomic and reduce the need for closure-scoped access patterns. This strengthens the case for keeping separate View types (more visible in code).

---

## References

### Type Theory and Newtype Patterns

- Yallop, J. & White, L. (2014). "Lightweight higher-kinded polymorphism." *FLOPS 2014*. Springer LNCS 8475.
- Eisenberg, R. et al. (2020). "Stitch: The Sound Type-Indexed Type Checker." Draft.
- Leijen, D. & Meijer, E. (1999). "Domain specific embedded compilers." *DSL '99*. ACM.
- Fluet, M. & Pucella, R. (2006). "Phantom types and subtyping." *Journal of Functional Programming*, 16(6), 751-791.

### Substructural Type Systems

- Walker, D. (2005). "Substructural type systems." In *Advanced Topics in Types and Programming Languages*. MIT Press.
- Tov, J.A. & Pucella, R. (2011). "Practical affine types." *POPL 2011*. ACM.
- Weiss, A. et al. (2019). "Oxide: The Essence of Rust." *arXiv:1903.00982*.

### API Usability

- Green, T.R.G. & Petre, M. (1996). "Usability analysis of visual programming environments: A 'cognitive dimensions' framework." *Journal of Visual Languages and Computing*, 7(2), 131-174.
- Clarke, S. (2004). "Measuring API usability." *Dr. Dobb's Journal*, 29(5), S6-S9.

### Language Design

- Rust RFC 517: `io` and `os` reform. https://rust-lang.github.io/rfcs/0517-io-os-reform.html
- Rust RFC 1307: OsString methods. https://rust-lang.github.io/rfcs/1307-osstring-methods.html
- Swift Evolution SE-0405: String Initializers with Encoding Validation. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0405-string-validating-initializers.md
- Apple swift-system package. https://github.com/apple/swift-system
- PEP 529: Change Windows filesystem encoding to UTF-8. https://peps.python.org/pep-0529/

### Existing Ecosystem Research

- "OS Native Path String Semantics." swift-string-primitives/Research/. 2026-01-15. Status: ANALYSIS.
- "ISO-C-Byte-String-Semantics." swift-iso-9899/docs/. 2026-01-15. Status: COMPLETE.
- "String-Domain-Bridging." swift-strings/docs/. 2026-01-28. Status: COMPLETE.
- "Protocol Abstraction for Phantom-Typed Wrappers." swift-institute/Research/. 2026-02-13. Status: IMPLEMENTED. Establishes the `associatedtype Domain: ~Copyable` pattern via SuppressedAssociatedTypes.
- "Witness ~Copyable/~Escapable Support." swift-institute/Research/. 2026-02-24. Status: RECOMMENDATION. Establishes bifurcation theorem: Copyable service references, ~Copyable resources.
- "Yielding vs Returning Lifetime Models." swift-primitives/Research/. 2026-02-10. Status: DECISION. Documents 21:1 yielding/returning ratio and closure integration gap.
- "Escapable Deinit Lifetime." swift-storage-primitives/Research/. Status: DECISION. 18 variants tested; documents `@_unsafeNonescapableResult` workaround and compiler crash.
- "Open-Source Toolchain Compiler Crashes." swift-institute/Research/. Status: DECISION. SIL verifier #87029, IRGen #87030.
- "Small Buffer Enum Compiler Workarounds." swift-buffer-primitives/Research/. Status: DECISION. DiagnoseStaticExclusivity crash, CopyPropagation crash, LLVM verifier crash.

### Empirical Validation

- `phantom-tagged-string-unification` experiment. swift-institute/Experiments/. 2026-02-25. 9 variants, ALL CONFIRMED. Validates Option D feasibility: ~Copyable generic with deinit, @_lifetime, _overrideLifetime, ~Escapable View, @unchecked Sendable, conditional namespaces, callAsFunction scope, protocol Domain conformance, typealiases, and cross-domain compile-time rejection.
- `typealias-without-reexport` experiment. swift-institute/Experiments/. 2026-02-27. 7 variants, PARTIALLY REFUTED. Tests whether stopping `@_exported` re-export of `String_Primitives` resolves `Swift.String` shadowing while retaining access through `Kernel.String` typealias. **Key finding**: MemberImportVisibility (SE-0444) blocks ALL member access through typealiases when the defining module is not imported. Adding the import restores members but re-introduces shadowing. Import-level solutions to shadowing are structurally impossible.
- `suppressed-associatedtype-domain` experiment. swift-institute/Experiments/. 2026-02-13. 6 variants, ALL CONFIRMED. Validates `associatedtype Domain: ~Copyable` with SuppressedAssociatedTypes flag.
- `noncopyable-associatedtype-domain` experiment. swift-institute/Experiments/. 2026-02-04. REFUTED without flag (superseded by above).

### ~Copyable/Lifetime Feature References

- `SuppressedAssociatedTypes` experimental feature. Enabled in 278 Package.swift targets across ecosystem.
- `SuppressedAssociatedTypesWithDefaults` experimental feature. Always paired with SuppressedAssociatedTypes.
- `Lifetimes` experimental feature. Enabled in 303 targets. Powers `@_lifetime` annotations.
- `_overrideLifetime(_:copying:)` / `_overrideLifetime(_:mutating:)`. 28 call sites for Span interop.
- `@_unsafeNonescapableResult`. Workaround for ~Escapable return from `get` accessors.
- Swift Issue #87029: SIL verifier double-consume with `_read` + `~Escapable` + `@_lifetime(borrow)`.
- Swift Issue #87030: IRGen crash with typed throws + nested error in generic type.
- Swift Issue #86669: Multi-file emit-module failure with compound ~Copyable constraints.
- Swift Evolution SE-0444: MemberImportVisibility. Members defined in a module require direct import of that module for access, even through typealiases. Prevents import-level shadowing resolution.
