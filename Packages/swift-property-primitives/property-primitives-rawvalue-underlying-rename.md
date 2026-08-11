# Property Primitives — `rawValue`/`RawValue` → `underlying`/`Underlying` rename

**Date**: 2026-05-03
**Trigger**: upstream renames in `swift-tagged-primitives` (`96f2a76`, `73020e6`) and `swift-carrier-primitives` (`99ad46e`).
**Verdict**: **trivial — mechanical rename only**.

## Four-question audit

### 1. Does this package declare types with their own `public let rawValue`?

**No.** The Property type-family does not own a `rawValue` field. Each variant exposes a `var base` accessor:

- `Property<Tag, Base>` and `Property.Typed<Element>` use `_read`/`_modify` over an internal `_base: Base` field — there is no `rawValue` member to rename.
- `Property.View`, `Property.View.Typed`, `Property.View.Typed.Valued`, `Property.View.Typed.Valued.Valued`, `Property.View.Read`, `Property.View.Read.Typed`, `Property.View.Read.Typed.Valued` wrap `Tagged<Tag, Ownership.Inout<Base>>` (or `Ownership.Borrow<Base>`) and expose `var base: Ownership.Inout<Base>` whose body reads `_storage.rawValue`. Those `_storage.rawValue` access sites are the only sites that change — they become `_storage.underlying`.
- `Property+Carrier.swift` already conforms `Property` to `Carrier` with `Underlying = Base`, `Domain = Tag`, and a `var underlying` accessor. The extension target updates from `Carrier` to `Carrier.\`Protocol\`` per `99ad46e`.

Property's `var base` accessor is the canonical public surface; renaming it to `underlying` would be wrong (mixes storage-coroutine identity with Carrier-value-extraction identity). Keep `base`.

### 2. Is anything on the package's public surface editorial that could move to a sibling target / SLI?

**No new movement justified.** The five-target decomposition (Core / Typed / Consuming / View / View.Read) was vetted at the 0.1.0 release-readiness scan. Test Support is already isolated. The two static `pointer(to:_:)` helpers on `Property` exist as deliberate escape hatches for non-mutating pointer access from `borrowing` contexts; they have ecosystem consumers. No relocation triggered by this rename cycle.

### 3. What's the consumer set for each `public` member?

All public API is canonical type-family surface used by container packages across `swift-primitives` (Stack, Buffer, Array.Inline, List.Linked, etc.). No demotion candidates surfaced; consumer audit is unchanged from 0.1.0.

### 4. Are there compound identifiers, `*Tag` suffixes, or other code-surface violations?

**No.** The phantom-tag generic parameter is named `Tag` (not `FooTag`). The Carrier `Domain` typealias maps `Tag = Domain` correctly. No compound identifiers in the public surface. DocC catalog references to `Tagged<Tag, RawValue>` and `rawValue` (in `Property.md` and `Phantom-Tag-Semantics.md`) are documentation-vocabulary updates, not API changes.

## Mechanical edits planned (Phase 2)

1. `_storage.rawValue` → `_storage.underlying` in 7 view files.
2. `Tagged<Tag, ...>(__unchecked: (), ...)` → `Tagged<Tag, ...>(_unchecked: ...)` in 7 view files (per `73020e6` `init(_unchecked:)` is now public).
3. `extension Property: Carrier where ...` → `extension Property: Carrier.\`Protocol\` where ...` in `Property+Carrier.swift`.
4. DocC vocabulary update in `Property.md` and `Phantom-Tag-Semantics.md`: `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`, `rawValue` → `underlying`, `RawValue` → `Underlying` (preserving the conceptual analogy text).
5. Outdated Carrier comment vocabulary in `Property+Carrier.swift` source comments: `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`.

No public type signatures change. No backward-compat typealiases.
