# index-primitives — `.rawValue` → `.underlying` + Carrier.`Protocol` migration

**Date:** 2026-05-03
**Cycle:** Tier 5 downstream migration (carrier `2b57aac`, tagged `46ded75`, cardinal `ac7f308`, ordinal `e42df9f`, vector/affine `51fd126`)
**Scope:** `/Users/coen/Developer/swift-primitives/swift-index-primitives` only.

## Package surface (current state, pre-migration)

The package surface is intentionally tiny. The only public type declaration is a typealias:

```swift
// Sources/Index Primitives Core/Index.swift
public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>
```

There are three SwiftPM products / four targets:

| Product | Target | Files |
|---------|--------|-------|
| `Index Primitives` | `Index Primitives` (umbrella) | `exports.swift` (re-exports `Index_Primitives_Core`) |
| `Index Primitives` | `Index Primitives Core` | `Index.swift` (typealias), `exports.swift` (re-exports Ordinal/Cardinal/Affine/Comparison/Tagged) |
| `Index Primitives Test Support` | `Index Primitives Test Support` | `exports.swift` (re-exports Tagged/Ordinal/Cardinal/Affine test support) |
| (test) | `Index Primitives Tests` | `Index Tests.swift`, `Index.Offset Tests.swift`, `Index.Count.Tagged.Experiment.swift` |

There are **no** owned struct/class types, no own `let rawValue` storage, no own initializers, and no public methods declared in this package. All semantic surface comes from `Tagged`, `Ordinal`, `Cardinal`, and `Affine` upstream.

## Q1 — Own `public let rawValue` types?

**Answer: none.**

`grep -rn "rawValue\|RawValue" Sources/` returns only doc-comment occurrences in `Index.swift`. There is no struct in this package with own storage. The `.rawValue` callsites in tests are all reads against `Tagged` (i.e. `Index<T>`) or `Cardinal`/`Vector` instances — they migrate purely via the upstream Tagged/Ordinal/Cardinal/Affine renames.

No own-field cardinal/ordinal/vector-precedent rewrite applies here.

## Q2 — Editorial public surface

**Answer: none worth relocating.**

Sources contain a typealias (one line of public surface) and an `@_exported` re-export `exports.swift`. There is no impl-detail editorial sprawl, no helpers, no ad-hoc accessors. The `exports.swift` in `Index Primitives Core` even has a duplicate `@_exported public import Tagged_Primitives` (lines 8 and 9) — minor cleanup opportunity, but not migration-blocking. I will fix the duplicate as part of the mechanical pass since it sits in a touched file.

No SLI / sibling-target carve-out is justified.

## Q3 — Three-consumer rule

**Answer: trivially satisfied.**

The package's only owned public surface is the `Index<Element>` typealias. Every public init / accessor / method on `Index<Element>` is inherited from `Tagged<Tag, Underlying>` and `Tagged where Underlying == Ordinal` (defined in `swift-ordinal-primitives`'s `Tagged+Ordinal.swift`, e.g. `position`, `zero`). Those upstreams have already audited their own three-consumer compliance.

No new declarations are introduced here, so the rule has nothing to validate at this layer.

## Q4 — Compound identifiers / `*Tag` suffixes / code-surface violations

**Answer: tests use a tag named `IntTag`, but it is `private` test scaffolding.**

```swift
// Tests/Index Primitives Tests/Index.Offset Tests.swift:17
private enum IntTag {}
```

The `feedback_no_tag_suffix.md` rule ("Phantom type tags use concept name directly, never `*Tag` suffix") is a **public-surface** rule. `IntTag` is a `private enum` inside a test file used purely as a phantom-type sentinel for the `Index<IntTag>.Offset` arithmetic tests. Public consumers cannot see it. This is a routine test-fixture pattern, not a compound-identifier violation in the `[API-NAME-002]` sense.

That said, since the file is being touched, renaming `IntTag` → `IntTagged` would still be wrong (compound-with-Tagged is worse), and renaming to `Int` would shadow the stdlib type used elsewhere in the file. Leaving `IntTag` as private test scaffolding is the lowest-friction choice and does not introduce a public violation. **No change applied.**

The other two test files use `private enum Bit {}`, `private enum Byte {}` — both correct (no suffix).

`Sources/Index Primitives Core/Index.swift` doc comment refers to `Index<Bit>` and `Index<Byte>` — also correct.

No compound public identifiers present.

## Verdict

**Proceed with mechanical-only Phase 2.** No escalation needed:
- Q1: nothing to migrate beyond mechanical Tagged/Ordinal/Cardinal renames.
- Q2: no editorial surface to relocate.
- Q3: trivially satisfied (one-line typealias).
- Q4: only private test scaffolding uses a `*Tag` name, which is acceptable.

Mechanical migration sites:
- `Sources/Index Primitives Core/Index.swift` — doc comments mention `Index(__unchecked: (), Ordinal(...))`; update to `Index(_unchecked: Ordinal(...))`.
- `Sources/Index Primitives Core/exports.swift` — drop the duplicate `@_exported public import Tagged_Primitives` line.
- All three test files — `__unchecked: (), X` → `_unchecked: X`; `.rawValue` → `.underlying`; `RawValue ==` → `Underlying ==`.

The bare-type-vs-`Carrier.\`Protocol\`` overload split that ordinal/affine needed does **not** apply here — there is no arithmetic surface owned by this package.
