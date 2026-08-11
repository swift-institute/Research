# swift-ownership-primitives — RawValue → Underlying rename audit

**Date**: 2026-05-03
**Trigger**: Three breaking renames landed upstream:
1. `swift-carrier-primitives` `99ad46e` — `Carrier` is now a bare-namespace `enum`; protocol moved to `` Carrier.`Protocol` ``; accessor `raw` → `underlying`.
2. `swift-tagged-primitives` `96f2a76` — `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`; `tagged.rawValue` → `tagged.underlying`; `init(rawValue:)` → `init(_:)`; `init(_unchecked: (), rawValue: x)` → `init(_unchecked: x)`.
3. `swift-tagged-primitives` `73020e6` — `init(_unchecked:)` is now `public`.

## Phase 1 design audit — four questions

### 1. Does this package declare types with their own `public let rawValue`?

**No.** A search across `Sources/` for `rawValue` finds zero hits. The only `raw` accessor on the package's public surface is `public let raw: UnsafeMutableRawPointer` on `Ownership.Transfer.Erased.Outgoing.Pointer`, which is the actual raw pointer field of an erased outgoing transfer — a stable `UnsafeMutableRawPointer`-typed value, not a Tagged- or Carrier-style underlying accessor. It is correctly named `raw` for an actual raw pointer and is unrelated to the upstream rename. Nothing to migrate here.

### 2. Is anything on the package's public surface editorial that could move to a sibling target / SLI?

**No.** The package is already finely decomposed under [MOD-015] into eleven variant targets (Borrow, Inout, Unique, Shared, Mutable, Slot, Latch, Indirect, Transfer, Transfer.Erased) plus a Standard Library Integration sibling target (`Optional+take`). Every public type is a foundational ownership-vocabulary primitive. No editorial surface candidates surfaced.

### 3. Public consumer set ≥3 for each member?

**Yes.** This is L1 ownership vocabulary that downstream layers (kernel, executors, IO, file, …) consume widely. The Tagged conformance specifically lifts `Ownership.Borrow.\`Protocol\`` through `Tagged`, which lets every Tagged-wrapped resource type in the ecosystem participate transparently — that is the consumer set itself.

### 4. Compound identifiers, `*Tag` suffixes, code-surface violations?

**No.** Public types use proper `Ownership.X` nesting. No compound identifiers (`OwnershipBorrow`, etc.), no `*Tag` suffix anywhere on the public surface, no methods like `.openWrite`. The hoisted `__Ownership_Borrow_Protocol` is a documented Swift 6.3.1 workaround for SE-0404's prohibition on protocol nesting inside generic structs (`Ownership.Borrow<Value>`); it follows the precedent of `swift-tree-primitives` `__TreeNChildSlot<n>` and is consumed solely via the canonical spelling `` Ownership.Borrow.`Protocol` ``. Not a violation.

## Migration scope

Mechanical scope is small:

- `Sources/Ownership Borrow Primitives/Tagged+Ownership.Borrow.Protocol.swift` — `where RawValue: ...` → `where Underlying: ...`; doc-comment `Tagged<Tag, RawValue>.Borrowed` → `Tagged<Tag, Underlying>.Borrowed`; `RawValue.Borrowed` → `Underlying.Borrowed`.
- `Tests/Ownership Primitives Tests/Tagged+Ownership.Borrow.Protocol Tests.swift` — test name and doc comments referring to `RawValue does` and `Tagged.Borrowed == RawValue.Borrowed`.

There is **no Carrier dependency** in this package — `swift-carrier-primitives` is not a dependency in `Package.swift` and `Carrier` does not appear in `Sources/` or `Tests/`. The Carrier rename is irrelevant here.

There are no `Ownership.Inout`-as-Tagged-Underlying construction sites in this package either — the `73020e6` public `init(_unchecked:)` is needed by downstream consumers, not by this package.

## Verdict

All four audit questions are trivial. Proceeding to Phase 2 mechanical migration.
