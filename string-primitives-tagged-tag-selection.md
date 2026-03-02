# String Primitives Tagged Tag Selection

<!--
---
version: 2.0.0
last_updated: 2026-02-27
status: DECISION
tier: 2
---
-->

## Context

The D' migration wraps `Memory.Contiguous<Char>` in `Tagged<Tag, Memory.Contiguous<Char>>`. For domain types the tag is obvious:

- `Kernel.Path` = `Tagged<Kernel.Path.Tag, Memory.Contiguous<Char>>` (or similar)
- `Kernel.String` could become `Tagged<Kernel, Memory.Contiguous<Char>>`

For `String_Primitives.String` — the base primitive — the tag is not obvious. The primitive layer has no domain; it IS the substrate that domain types build on.

### Trigger

[RES-001] — Design decision cannot be made without systematic analysis. The tag choice affects all consumers across all three layers.

### Prior Experiments

| Experiment | Finding |
|-----------|---------|
| tagged-string-literal | D' works: Tagged wraps storage, extensions provide behavior |
| tagged-string-crossmodule | Cross-module works with package access |
| tagged-escapable-accessor | Cross-PACKAGE works with stored property rawValue (just confirmed) |
| phantom-tagged-string-unification | Phantom tags with conditional namespaces confirmed |

### Constraint: Production Tagged Updated

Tagged now has `public var rawValue: RawValue` (stored property, not `_read` coroutine). This enables `@_lifetime` propagation across package boundaries — the prerequisite for D'.

## Question

What should the `Tag` type be for `String_Primitives.String` when migrating to `Tagged<Tag, Memory.Contiguous<Char>>`?

## Consumer Inventory

### Layer 1: Primitives

| Package | File | Usage |
|---------|------|-------|
| swift-string-primitives | String.swift | Defines `String` — owns `Memory.Contiguous<Char>` |
| swift-string-primitives | String.Char.swift | `String.Char` — platform-conditional `UInt8`/`UInt16` |
| swift-string-primitives | String.View.swift | `String.View` — `~Escapable` borrowed view |
| swift-string-primitives | String.Length.swift | `String.length(of:)` — null-terminated length |
| swift-kernel-primitives | Kernel.String.swift | `Kernel.String = String_Primitives.String` (typealias) |
| swift-kernel-primitives | Kernel.Path.swift | `Kernel.Path` — separate struct, stores `Memory.Contiguous<String.Char>` |
| swift-kernel-primitives | Kernel.Environment.Entry.swift | Uses `Kernel.String.Char`, `Kernel.String.length()` |
| swift-loader-primitives | Loader.Error.swift | Stores `String_Primitives.String` for error messages |

### Layer 2: Standards

| Package | File | Usage |
|---------|------|-------|
| swift-iso-9945 | ISO 9945.Kernel.Environment.swift | Uses `Kernel.String.Char`, `Kernel.String.View` |
| swift-iso-9945 | ISO 9945.Loader.Error.swift | Uses `String_Primitives.String.View` |

### Layer 3: Foundations

| Package | File | Usage |
|---------|------|-------|
| swift-strings | Swift.String+Primitives.swift | Bridges `Swift.String` <-> `String_Primitives.String` |
| swift-strings | ISO_9899.String+Primitives.swift | Bridges `ISO_9899.String` <-> `String_Primitives.String` |
| swift-strings | exports.swift | `@_exported public import String_Primitives` |
| swift-ascii | String_Primitives.String+ASCII.swift | Extension adding ASCII literal init |

### Future Consumers (SDG edges)

From Semantic Dependencies documentation: formatting-primitives, diagnostics, serialization, and logging all produce strings. Unicode UAX #29 (text segmentation) listed as high priority future dependency.

### Existing Tagged Patterns in Production

All kernel Tagged types use namespace types as tags:

```
Tagged<Kernel.User, UInt32>              — Kernel.User.ID
Tagged<Kernel.Event, UInt>               — Kernel.Event.ID
Tagged<Kernel, Memory.Address>           — Kernel.Memory.Address
Tagged<Kernel.System.Processor, Cardinal> — Kernel.System.Processor.Count
Tagged<Kernel.File.System, UInt64>       — Kernel.File.System.ID
```

Pattern: **the tag is the domain namespace that gives the value its semantic identity**.

## Analysis

### Option A: String stays concrete — not Tagged

`String_Primitives.String` remains `struct String { _storage: Memory.Contiguous<Char> }`. Only domain types (Kernel.Path) use Tagged.

| Criterion | Assessment |
|-----------|------------|
| Simplicity | Best — no migration needed for String itself |
| D' benefits | None for String — no retag, map, unified infrastructure |
| `Kernel.String = String_Primitives.String` | Preserved — typealias continues to work |
| Nested types (Char, View) | Stay nested in struct String |
| Consumer impact | Zero |

**Problem**: D' was motivated by unifying domain types through Tagged. If String stays concrete, it's a special case. Kernel.Path would be Tagged, Kernel.String wouldn't. Two different patterns in the same layer.

### Option B: String gets a dedicated tag

```swift
// In String_Primitives:
extension String_Primitives {
    public enum StringTag: ~Copyable {}
}
public typealias String = Tagged<StringTag, Memory.Contiguous<Char>>
```

Domain variants get their own tags:
```swift
// In Kernel_Primitives:
extension Kernel {
    public typealias String = Tagged<Kernel.StringTag, Memory.Contiguous<Char>>
}
```

| Criterion | Assessment |
|-----------|------------|
| Simplicity | Moderate — one new phantom type |
| D' benefits | Full — retag, map, Tagged infrastructure |
| `Kernel.String = String_Primitives.String` | **BREAKS** — different tags, different types |
| Nested types (Char, View) | Need new home (see below) |
| Consumer impact | All consumers need updating |
| Shared behavior | Extensions on `Tag: ~Copyable` work for all domain strings |
| Domain-specific behavior | Extensions on `Tag == SpecificTag` isolate domain logic |

**Problem**: `Kernel.String` can no longer be a typealias to `String_Primitives.String`. They become different types because they have different tags. Conversion requires `retag`.

### Option C: No default String — always domain-tagged

Every string must have a domain: `Kernel.String`, `Loader.String`, etc. No untagged `String_Primitives.String` exists.

| Criterion | Assessment |
|-----------|------------|
| Simplicity | Worst — forces every consumer to pick a domain |
| D' benefits | Full |
| Type safety | Maximum — every string carries its domain |
| Ergonomics | Poor — what domain does a temporary string have? |

**Problem**: What tag does `Loader.Error` use for its message string? What does `swift-ascii` use? Not every string belongs to a domain. This forces artificial domain assignment.

### Option D: String_Primitives provides extensions, not a type

String_Primitives defines no `String` type. Instead it provides extensions on `Tagged where RawValue == Memory.Contiguous<Char>`:

```swift
// String_Primitives provides behavior, not identity:
extension Tagged where RawValue == Memory.Contiguous<Char>, Tag: ~Copyable {
    public var count: Int { rawValue.count }
    public var span: Span<Char> { ... }
    public var view: View { ... }
    public init(ascii: StaticString) { ... }
}
```

Each consumer defines their own concrete type:
```swift
// Kernel defines:
extension Kernel { typealias Path = Tagged<Kernel.Path.Domain, Memory.Contiguous<Char>> }
extension Kernel { typealias String = Tagged<Kernel.String.Domain, Memory.Contiguous<Char>> }

// Loader defines:
extension Loader.Error { typealias Message = Tagged<Loader.Error.MessageTag, Memory.Contiguous<Char>> }
```

| Criterion | Assessment |
|-----------|------------|
| Simplicity | Moderate — behavior is shared, identity is per-domain |
| D' benefits | Full |
| `Kernel.String` | First-class Tagged type, not a typealias to another type |
| Nested types | Char becomes top-level in String_Primitives. View is per-tag or shared. |
| Consumer impact | Large — every consumer defines their own string typealias |
| Shared behavior | Natural — `Tag: ~Copyable` extensions apply to all |
| No artificial tags | Consumers who need a string define a tag. No "default" needed. |
| Conceptual clarity | String_Primitives is a behavior library, not a type library |

**Problem**: `swift-ascii` extends "String_Primitives.String" — but there is no such type. It would need to extend `Tagged where RawValue == Memory.Contiguous<Char>` generically. And `swift-strings` bridges "a string" to Swift.String — which concrete Tagged type does it bridge?

### Option E: String is Tagged with a tag, but shared extensions use `Tag: ~Copyable`

Like Option B, but with a clear separation:

```swift
// String_Primitives:
public enum String: ~Copyable {}  // String IS the tag (namespace enum)

// String's storage type:
extension String {
    public typealias Storage = Tagged<String, Memory.Contiguous<Char>>
}

// Shared behavior on ALL strings regardless of domain:
extension Tagged where RawValue == Memory.Contiguous<Char>, Tag: ~Copyable {
    public var count: Int { rawValue.count }
    public var span: Span<Char> { ... }
}

// String-specific nested types:
extension Tagged where RawValue == Memory.Contiguous<Char>, Tag == String {
    public typealias Char = UInt8  // or platform-conditional
    public struct View: ~Copyable, ~Escapable { ... }
}
```

Wait — this makes `String` the tag and `String.Storage` the actual value type. This inverts the nesting. `Kernel.String` would then be... `Tagged<Kernel, Memory.Contiguous<Char>>`? That doesn't relate to `String.Storage` at all.

This option has the same fundamental tension as B: `String_Primitives.String.Storage` and `Kernel.String` (= `Tagged<Kernel, ...>`) are different types.

## Key Tension

The core tension is:

1. **Tagged requires distinct types per domain** — that's the whole point. `Tagged<A, X>` != `Tagged<B, X>`.
2. **`Kernel.String = String_Primitives.String`** — today this is a typealias, meaning they're the same type.
3. **D' makes (1) and (2) incompatible** — if both are Tagged with different tags, they can't be the same type.

This means D' forces a decision: either `Kernel.String` stops being a typealias for `String_Primitives.String` (accepting they're different types connected by `retag`), or String stays concrete (not Tagged).

## Comparison

| Criterion | A (concrete) | B (dedicated tag) | C (always tagged) | D (extensions only) |
|-----------|:---:|:---:|:---:|:---:|
| Migration effort | None | Moderate | High | High |
| D' benefits for String | None | Full | Full | Full |
| Kernel.String = String typealias | Preserved | Breaks | N/A | N/A |
| Nested types (Char, View) | Stay put | Need rehoming | Need rehoming | Need rehoming |
| Artificial domain assignment | No | No (has default) | Yes | No |
| Conceptual consistency | Two patterns | One pattern | One pattern | One pattern |
| Shared behavior across domains | N/A | Via `Tag: ~Copyable` | Via `Tag: ~Copyable` | Via `Tag: ~Copyable` |

## Open Questions

1. **Is `Kernel.String = String_Primitives.String` essential?** If Kernel.String gets its own tag, conversion is `retag` (zero-cost phantom coercion). Is the type-level distinction a feature or a burden?

2. **Where do Char, View, terminator, length live?** These are currently nested in `String`. With D', String becomes a typealias — you can't nest types in a typealias. Options:
   - Top-level in the module (e.g., `public typealias Char = UInt8`)
   - In a namespace enum that doubles as the tag (Option E approach)
   - In the tag enum itself (`extension StringTag { public typealias Char = ... }`)

3. **Does `Loader.Error` need a domain-specific string?** Today it stores `String_Primitives.String`. If String is Tagged, it uses whatever tag String_Primitives picks. With Option D, it needs its own tag — unnecessary complexity.

4. **What does `swift-ascii` extend?** Today: `extension String_Primitives.String`. With D': either `extension Tagged where Tag == StringTag, RawValue == Memory.Contiguous<Char>` (tag-specific) or `extension Tagged where Tag: ~Copyable, RawValue == Memory.Contiguous<Char>` (all strings get ASCII).

## Outcome

**Status**: DECISION

**Resolved by Option G** from `tagged-path-string-identity-resolution.md`: the Tag is the **domain** (Kernel, Loader, etc.), and String/Path are **concrete types** used as the RawValue.

The question "what Tag for String?" is answered: **the Tag is always the consumer's domain**. `String_Primitives` does NOT define a Tagged string type. It defines a concrete `PlatformString` struct that owns `Memory.Contiguous<Char>` and provides `@_lifetime` accessors. Domain consumers wrap it:

```swift
// String_Primitives defines the concrete type:
public struct PlatformString: ~Copyable, @unchecked Sendable { ... }

// Each domain wraps it with Tagged:
extension Kernel {
    public typealias String = Tagged<Kernel, PlatformString>
}
```

### Resolution of Open Questions

1. **`Kernel.String = String_Primitives.String` essential?** — No longer relevant. `Kernel.String = Tagged<Kernel, PlatformString>`. The primitive type IS the RawValue, the domain IS the Tag.

2. **Where do Char, View, terminator, length live?** — Nested in the concrete `PlatformString` struct, exactly as today. No rehoming needed.

3. **Does Loader.Error need a domain-specific string?** — Yes: `Tagged<Loader, PlatformString>`. Or it can store `PlatformString` directly if no domain tagging is needed.

4. **What does `swift-ascii` extend?** — `extension Tagged where RawValue == PlatformString, Tag: ~Copyable` (all domain strings get ASCII), or `extension PlatformString` (the concrete type directly).

### Validated By

Experiment `tagged-two-level-lifetime` (2026-02-27) — ALL 6 variants CONFIRMED (debug + release). Two-level @_lifetime chain works: `Tagged.rawValue` (stored) → `PlatformString.span` (@_lifetime) → `_overrideLifetime`.

## References

- **Decision**: `tagged-path-string-identity-resolution.md` — Option G (concrete RawValue architecture)
- Experiment: `tagged-two-level-lifetime` (2026-02-27) — ALL 6 variants CONFIRMED
- Experiment: `tagged-escapable-accessor` (2026-02-27) — stored property rawValue enables @_lifetime cross-package
- Experiment: `tagged-string-crossmodule` (2026-02-27) — D' confirmed cross-module
- Experiment: `tagged-string-literal` (2026-02-25) — D' design validated
- Documentation: `swift-institute/Documentation.docc/Semantic Dependencies.md` — SDG analysis of string-primitives
- Production: `swift-identity-primitives/Sources/Identity Primitives/Tagged.swift` — public stored rawValue
