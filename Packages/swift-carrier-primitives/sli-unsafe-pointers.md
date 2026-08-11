# SLI — Unsafe pointer family (`UnsafePointer`, `UnsafeMutablePointer`, `UnsafeRawPointer`, `UnsafeMutableRawPointer`, `UnsafeBufferPointer`, `UnsafeMutableBufferPointer`, `OpaquePointer`): Skip

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: DECISION
tier: 1
scope: swift-carrier-primitives SLI target
---
-->

## Context

Swift's unsafe pointer family — seven types covering typed / raw, mutable / immutable, and buffer variants — represents raw memory addresses. Should any conform to `Carrier`?

## Analysis

### Structural match

Each is `Copyable & Escapable` (pointers are bit-copyable scalars). Trivial self-carriage would compile structurally. For the generic pointer types (`UnsafePointer<Pointee>`, etc.), the default extension handles the mechanics.

### Semantic fit — fundamental mismatch

Pointers are REFERENCES, not values. They describe "where memory lives" rather than "what value is carried." The Carrier abstraction assumes the conformer WRAPS a value; pointers DON'T wrap — they point. Using a pointer through `.underlying` access implies "here's the carried value," but the pointer hasn't been dereferenced; the caller gets the pointer itself back, not its pointee.

Making pointers conform to Carrier would make pointer-valued APIs look like value-carrying APIs, which is a category error. The abstraction says something untrue: "this pointer is a carrier of a pointer" — trivially correct at the type level, semantically incoherent at the domain level.

### Analogous reasoning

Related ecosystem-level thinking: `swift-memory-primitives/Research/` and the strict memory safety skill ([MEM-SAFE-*]) draw sharp lines between value types (what Carrier is about) and pointer types (what unsafe APIs are about). Conflating the two in a Carrier conformance would blur the boundary the ecosystem works to maintain.

### Could-it-be-done verdict

| Form | Viable? |
|------|---------|
| Trivial self-carrier | Structurally yes |
| Semantic coherence | No — category error |

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: Pointers are reference types in the memory-address sense, not value-carrier types. The Carrier abstraction is about value wrapping; including pointers would make the abstraction lie. Consumers writing generic pointer-handling code should use the existing unsafe-pointer APIs, not Carrier.

Applies identically to:

- `UnsafePointer<Pointee>`
- `UnsafeMutablePointer<Pointee>`
- `UnsafeRawPointer`
- `UnsafeMutableRawPointer`
- `UnsafeBufferPointer<Element>`
- `UnsafeMutableBufferPointer<Element>`
- `OpaquePointer`

## References

- Swift stdlib pointer types.
- `[MEM-SAFE-*]` — safety isolation rules separating value and pointer concerns.
