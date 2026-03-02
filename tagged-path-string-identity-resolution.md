# Tagged Path-String Identity Resolution

<!--
---
version: 2.0.0
last_updated: 2026-02-27
status: DECISION
tier: 2
---
-->

## Context

In the D' "always tagged" architecture, `String_Primitives.String` becomes a namespace enum (the concept), and concrete string values are `Tagged<Domain, Memory.Contiguous<Char>>`. For kernel:

```swift
Kernel.String = Tagged<Kernel, Memory.Contiguous<Char>>
```

The tag is `Kernel`. The RawValue is `Memory.Contiguous<Char>`.

**Problem**: `Kernel.Path` also wraps `Memory.Contiguous<Char>`. If it uses `Kernel` as the tag, then `Tagged<Kernel, Memory.Contiguous<Char>>` is one type — paths and strings are identical. They must differ on either Tag or RawValue.

### Trigger

[RES-001] — Structural conflict between naming convention and type identity. Blocks D' implementation.

### Constraint: No Artificial `*Tag` Types

The user requires that tags be real domain concepts (`Kernel`, `Kernel.Path`), not artificial phantom enums (`PathTag`, `StringTag`).

### Production Pattern (from kernel-primitives)

The established convention:

```
Namespace.Member = Tagged<Namespace, RawValue>
```

| Tag (namespace) | Typealias (member) | RawValue |
|---|---|---|
| `Kernel.User` | `Kernel.User.ID` | `UInt32` |
| `Kernel.Event` | `Kernel.Event.ID` | `UInt` |
| `Kernel.File.System` | `Kernel.File.System.ID` | `UInt64` |
| `Kernel.Memory.Page` | `Kernel.Memory.Page.Size` | `Cardinal` |
| `Kernel.Link` | `Kernel.Link.Count` | `Cardinal` |
| `Kernel` | `Kernel.Memory.Address` | `Memory.Address` |

**Key invariant**: The typealias name is always DIFFERENT from the tag name. `User` != `ID`. No collisions exist in production.

**Key observation**: When two types share the same domain (`Kernel`), they differ by RawValue: `Kernel.Memory.Address` (`Memory.Address`) vs. hypothetical `Kernel.Memory.Displacement` (`Memory.Address.Offset`). When RawValues are the same type, tags must differ: `Kernel.Memory.Page.Size` vs `Kernel.System.Processor.Count` (both `Cardinal`, different tags).

## Question

How should `Kernel.Path` be structured when both `Kernel.String` and `Kernel.Path` wrap `Memory.Contiguous<Char>` and the domain is `Kernel`?

## Analysis

### Option A: Path gets its own tag namespace — member name for value

`Kernel.Path` becomes an enum namespace (the tag). The owned Tagged value is a nested member.

```swift
extension Kernel {
    public enum Path: ~Copyable {}  // tag + namespace
}

extension Kernel.Path {
    public typealias Owned = Tagged<Kernel.Path, Memory.Contiguous<Char>>
    public typealias Char = String.Char
}

// Nested types in constrained extension:
extension Tagged where Tag == Kernel.Path, RawValue == Memory.Contiguous<Char> {
    public struct View: ~Copyable, ~Escapable { ... }
}
```

Call site: `let p: Kernel.Path.Owned = ...`

| Criterion | Assessment |
|-----------|------------|
| Follows production pattern | Exactly — namespace is tag, typealias is nested member |
| Call site ergonomics | Worse — `Kernel.Path.Owned` instead of `Kernel.Path` |
| Nested types | `Kernel.Path.Owned.View` — awkward (through typealias + extension) |
| No artificial tags | Yes — `Kernel.Path` is a real domain concept |
| Scales to other types | Yes — `Kernel.Environment.Entry.Name.Owned`, etc. |

**Problem**: Every type that wraps `Memory.Contiguous<Char>` needs `.Owned` suffix. Ergonomics degrade. And `Kernel.Path.Owned.View` is deeply nested.

### Option B: Plural tag, singular typealias

The tag uses the plural form. The typealias uses the singular.

```swift
extension Kernel {
    public enum Paths: ~Copyable {}
    public typealias Path = Tagged<Kernel.Paths, Memory.Contiguous<Char>>
}

// Nested types resolve through the typealias:
extension Tagged where Tag == Kernel.Paths, RawValue == Memory.Contiguous<Char> {
    public struct View: ~Copyable, ~Escapable { ... }
    public typealias Char = String.Char
}
```

Call site: `let p: Kernel.Path = ...`
Nested access: `Kernel.Path.View` (resolves through typealias to constrained extension)

| Criterion | Assessment |
|-----------|------------|
| Follows production pattern | Partially — tag and typealias are siblings, not parent-child |
| Call site ergonomics | Clean — `Kernel.Path` is the value type directly |
| Nested types | `Kernel.Path.View` works (Swift resolves through typealias) |
| No artificial tags | Yes — `Paths` is a real concept (plural of Path) |
| Scales to other types | Debatable — `Kernel.Strings` / `Kernel.String`? Reads oddly |
| Naming convention | Unconventional — no existing precedent in production |

**Problem**: Plural/singular split has no precedent in the codebase. `Kernel.Strings` as a tag for `Kernel.String` reads strangely. The pattern doesn't generalize well.

### Option C: Distinct storage types

Make the RawValue nominally distinct. Both are structurally `Memory.Contiguous<Char>` but are different types.

```swift
// In String_Primitives:
public enum String: ~Copyable {
    public struct Storage: ~Copyable, @unchecked Sendable {
        public var buffer: Memory.Contiguous<Char>
        // init, span, view etc. forwarded from buffer
    }
}

// Path storage either in String_Primitives or Kernel_Primitives:
public enum Path: ~Copyable {
    public struct Storage: ~Copyable, @unchecked Sendable {
        public var buffer: Memory.Contiguous<Char>
    }
}

// Now Kernel can use the same tag for both:
extension Kernel {
    public typealias String = Tagged<Kernel, String_Primitives.String.Storage>
    public typealias Path = Tagged<Kernel, Path.Storage>
}
```

Call site: `let p: Kernel.Path = ...`

| Criterion | Assessment |
|-----------|------------|
| Follows production pattern | Yes — `Kernel` is tag, distinct RawValues differentiate |
| Call site ergonomics | Clean — `Kernel.Path` is the value type |
| Nested types | Through constrained extension on `Tagged where RawValue == Path.Storage` |
| No artificial tags | Yes — `Kernel` is the domain, storage type carries semantics |
| Triple wrapping | `Tagged` wrapping `Storage` wrapping `Memory.Contiguous` — three layers |
| Shared behavior | Harder — extensions on `String.Storage` don't apply to `Path.Storage` |

**Problem**: Three layers of wrapping. Shared behavior (span access, length, etc.) must be written separately for each Storage type, or `Memory.Contiguous<Char>` needs a protocol, or each Storage type must forward through `.buffer`. The storage wrapper exists purely for type-level differentiation — it carries no semantic information.

### Option D: Path is not Tagged

Strings use Tagged. Paths stay concrete. Exception to "always tagged."

```swift
extension Kernel {
    public typealias String = Tagged<Kernel, Memory.Contiguous<Char>>

    public struct Path: ~Copyable, @unchecked Sendable {
        public var rawValue: Memory.Contiguous<Char>  // stored property, matches Tagged shape
    }
}
```

| Criterion | Assessment |
|-----------|------------|
| Follows production pattern | No — Path is special-cased |
| Call site ergonomics | Best — `Kernel.Path` unchanged from today |
| Nested types | Unchanged — `Kernel.Path.View` stays nested in struct |
| Consistency | Bad — two patterns for the same concept |
| D' benefits for Path | None — no retag, map, Tagged infrastructure |

**Problem**: User explicitly said "always tagged." This violates the architectural direction.

### Option E: Tag encodes both domain and kind

The tag carries two pieces of information: domain and kind.

```swift
// Kind markers:
public enum Strings: ~Copyable {}
public enum Paths: ~Copyable {}

// Domain-qualified tags via nesting or parameterization:
extension Kernel {
    public typealias String = Tagged<Kernel.Strings, Memory.Contiguous<Char>>
    public typealias Path = Tagged<Kernel.Paths, Memory.Contiguous<Char>>
}
```

But `Kernel.Strings` and `Kernel.Paths` are namespace enums inside `Kernel` — essentially Option B.

Alternatively, the kind is global and the domain is encoded differently:

```swift
// Global kind markers:
public enum StringKind: ~Copyable {}
public enum PathKind: ~Copyable {}

// Domain-specific via extension constraint
extension Tagged where Tag == StringKind { /* string behavior */ }
extension Tagged where Tag == PathKind { /* path behavior */ }
```

But this loses the domain (Kernel vs. Loader vs. future). And `*Kind` has the same smell as `*Tag`.

## Comparison

| Criterion | A (nested member) | B (plural tag) | C (storage types) | D (concrete) | E (kind tags) |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Production pattern | Exact | Partial | Yes | No | No |
| Call site (`Kernel.Path`) | `Kernel.Path.Owned` | `Kernel.Path` | `Kernel.Path` | `Kernel.Path` | `Kernel.Path` |
| Nested types | Through .Owned | Through typealias | Through extension | In struct | Through typealias |
| No artificial tags | Yes | Yes | Yes | N/A | No (`*Kind`) |
| Wrapping layers | 1 (Tagged) | 1 (Tagged) | 2 (Tagged + Storage) | 0 | 1 (Tagged) |
| Always tagged | Yes | Yes | Yes | No | Yes |
| Shared behavior | Natural | Natural | Duplicated | N/A | Natural |
| Scales well | Verbose | Odd naming | Storage proliferation | N/A | Tag proliferation |

## The Core Tension

The conflict is between two desirable properties:

1. **`Kernel.Path` should be the value type** (ergonomics)
2. **`Kernel.Path` should be the tag** (principled — the concept IS the tag)

These are mutually exclusive. A name can be either a typealias (the value) or a namespace enum (the tag), not both. The production pattern resolves this by giving them different names: `Kernel.User` (tag) vs `Kernel.User.ID` (value). But that means the value name is always `Namespace.Member`, not just `Namespace`.

## Prior Art: How Kernel.Memory.Address Resolves This

`Kernel.Memory.Address` is the one case where the value typealias is at the "expected" path:

```swift
extension Kernel.Memory {
    public typealias Address = Tagged<Kernel, Memory_Primitives_Core.Memory.Address>
}
```

The tag is `Kernel` (parent), not `Kernel.Memory` (immediate namespace). The RawValue (`Memory.Address`) is distinct from other `Kernel`-tagged types. This works because `Memory.Address` is a unique type.

**Lesson**: When the RawValue is unique enough to differentiate, the tag can be the broader domain. When RawValues collide, the tag must be more specific.

## Option F: Domain-Parameterized Structs (The Reformulation)

Options A–E all accept the premise: "String and Path must be `Tagged<Tag, Memory.Contiguous<Char>>`." Option F questions the premise.

### The Splitting Heuristic

Literature on phantom types (Haskell's `Data.Tagged`, Rust's newtype pattern, De Goes' critique, Sundell/Lokhorst in Swift) converges on a split:

| Criterion | External wrapper (`Tagged<D, V>`) | Internal parameter (`MyType<D>`) |
|-----------|:---:|:---:|
| Storage complexity | Scalar / single value | Structured / multi-field |
| Domain-specific methods | None or uniform | Varies by domain |
| Conformance surface | Uniform across all tags | Custom per domain |
| Semantic weight | Tag is an annotation on a value | Parameter is intrinsic to identity |

**Tagged is for scalars.** `Tagged<Kernel.User, UInt32>` — UInt32 has no inherent semantics, the tag gives it meaning. Operations are uniform: equality, hashing, comparison.

**Domain-parameterized structs are for rich types.** String and Path have deinit, span, view, ~Escapable accessors, domain-specific methods (path separators, string encoding). Their API varies by domain. They have semantic weight beyond "a value annotated with a domain."

### The Pattern

```swift
// String_Primitives:
public struct String<Domain: ~Copyable>: ~Copyable, @unchecked Sendable {
    public var storage: Memory.Contiguous<Char>
}

// Shared behavior — all domains:
extension String where Domain: ~Copyable {
    public var count: Int { storage.count }
    public var span: Span<Char> { ... }
    public var view: String.View { ... }
    public struct View: ~Copyable, ~Escapable { ... }
    public typealias Char = UInt8  // platform-conditional
    public consuming func retag<New: ~Copyable>(to: New.Type) -> String<New> { ... }
}

// Kernel_Primitives:
extension Kernel {
    public typealias String = String_Primitives.String<Kernel>
}
```

For Path (defined in kernel-primitives, since paths are a kernel concept):

```swift
// Kernel_Primitives:
public struct Path<Domain: ~Copyable>: ~Copyable, @unchecked Sendable {
    public var storage: Memory.Contiguous<String.Char>
}

extension Kernel {
    public typealias Path = Path<Kernel>
}

// Domain-specific:
extension Path where Domain == Kernel {
    public var isAbsolute: Bool { ... }
}
```

### Why This Dissolves the Problem

| Tension | Resolution |
|---------|-----------|
| `Kernel.Path` = value type | `typealias Path = Path<Kernel>` — clean |
| `Kernel.String` = value type | `typealias String = String<Kernel>` — clean |
| Path != String | Different generic structs — `Path<Kernel>` != `String<Kernel>` |
| Domain is `Kernel` for both | Yes — same domain, different kinds |
| No artificial tags | Kernel is the domain, not `PathTag` or `StringTag` |
| Always phantom-typed | Every value carries a domain parameter |
| Nested types | `String<Domain>.View`, `Path<Domain>.Char` — natural nesting |
| Domain-specific behavior | `extension Path where Domain == Kernel` — clean |
| retag | Method on the generic struct — `path.retag(to: NewDomain.self)` |

### Relationship to Tagged

This is NOT "abandoning Tagged." It's the **splitting heuristic**:

- **Scalars**: `Tagged<Kernel.User, UInt32>`, `Tagged<Kernel.Event, UInt>` — unchanged
- **Rich owned types**: `String<Domain>`, `Path<Domain>` — domain-parameterized structs

Tagged continues to serve its purpose for scalar wrappers. Rich types with deinit, span, view, and domain-specific methods get their own generic struct — which is more natural, more ergonomic, and avoids the naming collision entirely.

### Prior Validation

The `phantom-tagged-string-unification` experiment (2026-02-25) validated exactly this pattern:

- V1: ~Copyable generic with phantom tag + deinit — CONFIRMED
- V2: ~Escapable View with @_lifetime — CONFIRMED
- V3: _overrideLifetime + Span in generic context — CONFIRMED
- V4: @unchecked Sendable on generic ~Copyable — CONFIRMED
- V5: Conditional namespace extensions (`where Tag == PathDomain`) — CONFIRMED
- V7: Protocol `Domain: ~Copyable` + conformance — CONFIRMED
- V8: Typealiases carry conditional extensions — CONFIRMED
- V9: Cross-domain mixing rejected at compile time — CONFIRMED

All 9 variants confirmed (V6 needs `@_optimize(none)` for #87029, same workaround used elsewhere).

### The `tagged-escapable-accessor` Experiment Still Matters

The experiment we ran today proved that `_read` coroutine blocks `@_lifetime` cross-package. For Option F, this means:

- `String<Domain>.storage` must be a **public stored property** (not `_read`/`_modify`) for span/view accessors to work across packages
- This is the same finding — the stored property pattern works, the coroutine pattern doesn't
- The fix we applied to production Tagged (public `rawValue`) applies equally to the generic struct's `storage` property

## Comparison (All Options)

| Criterion | A (nested) | B (plural) | C (storage) | D (concrete) | E (kind) | **F (generic struct)** |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|
| Call site | `.Owned` | Clean | Clean | Clean | Clean | **Clean** |
| Nested types | Awkward | Through alias | Through ext | In struct | Through alias | **Natural** |
| No artificial tags | Yes | Yes | Yes | N/A | No | **Yes** |
| Wrapping layers | 1 | 1 | 2 | 0 | 1 | **0** |
| Always typed | Yes | Yes | Yes | No | Yes | **Yes** |
| Shared behavior | Via Tagged ext | Via Tagged ext | Duplicated | N/A | Via Tagged ext | **On struct** |
| Domain-specific | Via constraint | Via constraint | Via constraint | N/A | Via constraint | **Via constraint** |
| Follows precedent | Production | New | Production | N/A | New | **Experiment** |
| Scales | Verbose | Odd naming | Storage bloat | N/A | Tag bloat | **Natural** |

## Option G: Concrete Types as RawValue — Kind × Domain (The User's Architecture)

Options A–F all assume `Memory.Contiguous<Char>` is the direct RawValue. Option G questions that: **what if String and Path are concrete types that OWN `Memory.Contiguous<Char>`, and Tagged wraps those concrete types?**

### The Architecture

```swift
// String_Primitives — concrete struct, NOT generic, NOT Tagged:
public struct PlatformString: ~Copyable, @unchecked Sendable {
    internal let pointer: UnsafePointer<Char>
    public let count: Int

    public var span: Span<Char> {
        @_lifetime(borrow self) borrowing get { ... }
    }

    public struct View: ~Copyable, ~Escapable { ... }
    public var view: View {
        @_lifetime(borrow self) borrowing get { ... }
    }
}

// Concrete Path — nominally distinct from PlatformString:
public struct PlatformPath: ~Copyable, @unchecked Sendable {
    internal let pointer: UnsafePointer<Char>
    public let count: Int

    public var span: Span<Char> {
        @_lifetime(borrow self) borrowing get { ... }
    }

    public var isAbsolute: Bool { ... }
}

// Domain tag — real concept, not artificial:
public enum Kernel: ~Copyable {}

// Tagged wraps concrete types with domain identity:
extension Kernel {
    public typealias String = Tagged<Kernel, PlatformString>
    public typealias Path = Tagged<Kernel, PlatformPath>
}
```

### Why This Works

The key insight: **Kind is the RawValue, Domain is the Tag**. Two orthogonal axes:

| | PlatformString | PlatformPath |
|---|---|---|
| **Kernel** | `Tagged<Kernel, PlatformString>` | `Tagged<Kernel, PlatformPath>` |
| **Loader** | `Tagged<Loader, PlatformString>` | — |

`Tagged<Kernel, PlatformString>` != `Tagged<Kernel, PlatformPath>` because the RawValues are nominally distinct types. No tag collision.

### Two-Level @_lifetime Chain

The critical technical requirement: `@_lifetime` must propagate through two levels:

1. `Tagged.rawValue` (stored property) → borrow the concrete type
2. `ConcreteType.span` (`@_lifetime(borrow self)`) → create Span
3. `_overrideLifetime(s, borrowing: self)` → re-parent to Tagged self

Extensions on Tagged forward through rawValue:

```swift
extension Tagged where RawValue == PlatformString, Tag: ~Copyable {
    public var span: Span<Char> {
        @_lifetime(borrow self) borrowing get {
            let s = rawValue.span  // TWO-LEVEL: stored rawValue → .span (@_lifetime)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

extension Tagged where RawValue == PlatformString, Tag == Kernel {
    public var view: PlatformString.View {
        @_lifetime(borrow self) borrowing get {
            let v = rawValue.view
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}
```

### Experimental Validation

The `tagged-two-level-lifetime` experiment (2026-02-27) validated ALL 6 variants in both debug and release:

| Variant | Test | Result |
|---------|------|--------|
| V1 | Chained Span through `Tagged<Kernel, PlatformString>.span` | CONFIRMED |
| V2 | Chained Span through `Tagged<Kernel, PlatformPath>.span` | CONFIRMED |
| V3 | ~Escapable View through `Tagged<Kernel, PlatformString>.view` | CONFIRMED |
| V4 | Direct Span from rawValue.pointer/count (single-level control) | CONFIRMED |
| V5 | Domain-specific forwarding (isAbsolute) | CONFIRMED |
| V6 | Type distinctness: `Tagged<Kernel, String>` != `Tagged<Kernel, Path>` | CONFIRMED |

### Why This Dissolves the Problem

| Tension | Resolution |
|---------|-----------|
| `Kernel.Path` = value type | `typealias Path = Tagged<Kernel, PlatformPath>` — clean |
| `Kernel.String` = value type | `typealias String = Tagged<Kernel, PlatformString>` — clean |
| Path != String | Different RawValues — `PlatformString` != `PlatformPath` |
| Domain is `Kernel` for both | Yes — same Tag, different RawValues |
| No artificial tags | `Kernel` is the real domain concept |
| Always tagged | Every domain value is `Tagged<Domain, ConcreteType>` |
| Nested types | In the concrete struct — `PlatformString.View`, `PlatformString.Char` |
| Domain-specific behavior | `extension Tagged where RawValue == PlatformPath, Tag == Kernel` |
| Shared behavior | `extension Tagged where RawValue == PlatformString, Tag: ~Copyable` |
| @_lifetime propagation | Two-level chain works through stored property rawValue |

### Relationship to Tagged and Option F

**Option F** (domain-parameterized generics like `String<Domain>`) makes the generic struct carry both kind and domain. Option G keeps Tagged as the universal domain wrapper and makes concrete types carry the kind. The advantage: Tagged infrastructure (retag, map, protocol conformances) applies to all domain-wrapped types uniformly. No per-type generic duplication.

**The splitting heuristic still applies**, but the split point is different:

- **Scalars**: `Tagged<Kernel.User, UInt32>` — Tagged wraps a primitive value, Tag is the semantic identity
- **Rich owned types**: `Tagged<Kernel, PlatformString>` — Tagged wraps a concrete type, Tag is the domain, RawValue carries the kind

Both use Tagged. The difference is what the Tag represents: semantic identity (for scalars) vs domain membership (for rich types).

## Comparison (All Options Including G)

| Criterion | A | B | C | D | E | F | **G (concrete RawValue)** |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Call site | `.Owned` | Clean | Clean | Clean | Clean | Clean | **Clean** |
| Nested types | Awkward | Alias | Extension | Struct | Alias | Generic struct | **Concrete struct** |
| No artificial tags | Yes | Yes | Yes | N/A | No | Yes | **Yes** |
| Wrapping layers | 1 | 1 | 2 | 0 | 1 | 0 | **1 (Tagged)** |
| Always tagged | Yes | Yes | Yes | No | Yes | Yes (param) | **Yes** |
| Shared behavior | Tagged ext | Tagged ext | Duplicated | N/A | Tagged ext | Struct ext | **Tagged ext** |
| Tagged infrastructure | Full | Full | Full | None | Full | Custom | **Full** |
| @_lifetime validated | — | — | — | — | — | Experiment | **Experiment** |

## Outcome

**Status**: DECISION

**Option G (concrete types as RawValue)** is the confirmed architecture for D':

1. **Concrete types** (PlatformString, PlatformPath) own `Memory.Contiguous<Char>` and provide `@_lifetime` accessors
2. **Tagged wraps concrete types** with domain identity: `Tagged<Kernel, PlatformString>`
3. **Kind is the RawValue** (String vs Path), **Domain is the Tag** (Kernel) — two orthogonal axes
4. **Type distinctness** comes from nominal RawValue difference, not tag difference
5. **Two-level @_lifetime chain** validated experimentally (debug + release)

### Prerequisites (both complete)

1. Production Tagged: `public var rawValue` (stored property) — applied 2026-02-27
2. Two-level @_lifetime chain — validated by `tagged-two-level-lifetime` experiment

### Implementation Path

1. `PlatformString` — concrete struct owning `Memory.Contiguous<Char>` with span/view accessors
2. `PlatformPath` — concrete struct owning `Memory.Contiguous<Char>` with path-specific methods
3. `Tagged<Kernel, PlatformString>` = `Kernel.String` via typealias
4. `Tagged<Kernel, PlatformPath>` = `Kernel.Path` via typealias
5. Extensions on `Tagged where RawValue == PlatformString` forward through rawValue
6. Tagged continues unchanged for scalar wrappers

## References

- Production patterns: `swift-kernel-primitives/Sources/Kernel Primitives/` (18 Tagged typealiases)
- Experiment: `tagged-two-level-lifetime` (2026-02-27) — ALL 6 variants CONFIRMED (debug + release)
- Experiment: `tagged-escapable-accessor` (2026-02-27) — stored property enables @_lifetime cross-package
- Experiment: `phantom-tagged-string-unification` (2026-02-25) — all 9 variants confirmed
- Research: `string-path-type-unification.md` — Options A-E analysis
- Research: `string-primitives-tagged-tag-selection.md` — consumer inventory
- Literature: Haskell Data.Tagged, Rust newtype/PhantomData, De Goes' critique
- Sundell: "Phantom Types in Swift"
- Lokhorst: "Strongly Typed Identifiers in Swift"
