# `String_Primitives.String<Char>` — Char-Generic Future Cycle

**Status**: NOT YET PROPOSED (option captured for future consideration)
**Surfaced in**: string-primitives correction cycle (2026-04-18), as alternative to Δ2 ISO_9899.String extraction
**Trigger**: durable maintenance burden from the parallel `String_Primitives.String` / `ISO_9899.String` shapes, OR an explicit need to type-distinguish UTF-8 vs UTF-16 strings at compile time

---

## The option

Today `String_Primitives.String` has a platform-conditional `Char`:
```swift
public typealias Char = UInt8  // POSIX
public typealias Char = UInt16  // Windows
```

The generic alternative parameterizes over Char:
```swift
public struct String<Char: UnsignedInteger & FixedWidthInteger>: ~Copyable { ... }

// Today's platform string (preserved as alias)
public typealias PlatformString = String<UInt8>   // POSIX
public typealias PlatformString = String<UInt16>  // Windows

// ISO 9899's UTF-8-always C string becomes:
extension ISO_9899 {
    public typealias String = String_Primitives.String<UInt8>
}

// Hypothetical UTF-16 cousin (rare; explicit):
public typealias UTF16OwnedString = String_Primitives.String<UInt16>
```

## Why it matters (when it does)

Today the platform-typealias design has these tensions:

1. **Apparent duplication with `ISO_9899.String`** — both are NUL-terminated UInt8 buffers on POSIX. Modularization perspective flagged this; user rejected extraction (see `string-iso-9899-extraction-rejected.md`).
2. **Compile-time distinction between UTF-8 and UTF-16 is impossible** — application authors who want a function "this only accepts UTF-8" can't express it with the current `Char` typealias because the Char itself is platform-conditional.
3. **Lexer.Scanner generic-over-Char** (see `string-lexer-scanner-generic-deferred.md`) becomes clean when the underlying string type is also Char-generic.

If the ecosystem ever needs to address (1) at the type level (rather than just at the algorithm level via D5), or address (2) for application API design, the Char-generic refactor is the structural answer.

## Why not now

Cost is large:
- Touches every consumer of `String_Primitives.String.Char` and every internal use of the conditional typealias
- Forces overload resolution decisions at every call site (which `Char` does the consumer mean?)
- Requires a parallel update to all Tagged forwarding (`Tagged<Domain, String_Primitives.String<Char>>`)
- Migration of `Kernel.String = Tagged<Kernel, String_Primitives.String>` to `Kernel.String = Tagged<Kernel, String_Primitives.PlatformString>` — most consumers unchanged but every `extension Kernel.String` may need re-typing

Benefit is hypothetical: no production consumer today needs the type-level encoding distinction. The current platform-typealias design works for OS-syscall use cases (the dominant consumer of `String_Primitives.String`).

## Recommended path forward

**Treat this as a one-way-door warning, not a backlog item.** The current platform-typealias design is correct for current needs. Should the trigger conditions materialize, this note is the starting point for a dedicated ecosystem-correction cycle.

Order of preference if/when pursued:
1. Stage 1: Introduce `String_Primitives.String<Char>` as a NEW type alongside the existing `String_Primitives.String`. No removal yet.
2. Stage 2: Migrate `ISO_9899.String` to alias `String_Primitives.String<UInt8>`. Verify byte-identical behavior.
3. Stage 3: Migrate `Kernel.String` to use the generic form via a typealias indirection (`PlatformString`).
4. Stage 4: Deprecate the original platform-typealias-`String_Primitives.String` after migration completes.

Each stage is its own wave with cross-layer equivalence tests preceding.

## Related

- D1 in `string-type-ecosystem-model.md` (three parallel owning types — protocol rejected)
- D4 (encoding marker on owned types — also rejected; this generic refactor would offer a partial answer)
- `string-iso-9899-extraction-rejected.md` (the question this option would close)
- `string-lexer-scanner-generic-deferred.md` (the option this enables cleanly)
