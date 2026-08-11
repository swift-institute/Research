# Naming: `Ownership.Shared` / `Ownership.Mutable` symmetry

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: DEFERRED
tier: 2
scope: cross-package
---
-->

## Context

`Ownership.Shared` and `Ownership.Mutable` are paired ARC-shared
reference wrappers over `~Copyable` values:

| Type | Mutability | Sendable | Purpose |
|------|-----------|----------|---------|
| `Ownership.Shared<Value>` | Read-only (`let value: Value`) | Plain `Sendable` (v2.1.0) | Heap-owned immutable ARC-shared |
| `Ownership.Mutable<Value>` | Mutable (`var value: Value` via `update`) | NOT Sendable by design | Intra-isolation mutable ARC-shared |
| `Ownership.Mutable.Unchecked<Value>` | Mutable | `@unchecked Sendable` (caller-asserted) | Cross-isolation via caller synchronisation |

Both types are **shared**. Only **mutability** differs. The names do
not reflect that shared axiom — one is named for sharing, the other
for mutability.

## Question

Should the pair be renamed for symmetry? E.g.
`Ownership.Shared.Immutable` / `Ownership.Shared.Mutable` /
`Ownership.Shared.Mutable.Unchecked`.

## Prior Art — Shared / Mutable Naming

### Apple / Swift stdlib

- `let` vs `var` — the language-level distinction. No named pair of types.
- `ManagedBuffer` is always mutable at the reference level; no immutable
  sibling.
- SwiftUI: `@State` (local mutable), `@Binding` (shared mutable), no
  immutable shared ref type.
- Foundation: `NSArray` / `NSMutableArray`, `NSString` / `NSMutableString`
  — class-based mutability pair. The pattern is `Mutable`-prefix on
  the mutable variant, bare name on the immutable variant.

`NSArray` / `NSMutableArray` is the canonical Apple precedent:

| Apple | Immutable | Mutable |
|-------|-----------|---------|
| Array | `NSArray` | `NSMutableArray` |
| String | `NSString` | `NSMutableString` |
| Dictionary | `NSDictionary` | `NSMutableDictionary` |

The pattern: immutable is the bare name; mutable gets the `Mutable-`
prefix. **This is exactly the current scheme** — `Ownership.Shared`
is the bare name (immutable), `Ownership.Mutable` is the named variant.

However, Apple's pattern nests both under a shared *concept* name
(Array, String). Ours nests under `Ownership` but the concept name
(`Shared`) is only attached to the immutable sibling.

### Rust stdlib

- `Arc<T>` — atomically reference-counted, shared, immutable.
- `Rc<T>` — single-threaded reference-counted, shared, immutable.
- `Mutex<T>`, `RwLock<T>` — mutation is a capability layered ONTO
  `Arc<T>` via composition: `Arc<Mutex<T>>` is the idiomatic shared
  mutable.

Rust does NOT have `MutableArc<T>`. Mutability is orthogonal to
sharing, composed externally. This is a different model.

### C#, Java, Kotlin

- C# `List<T>` / `ReadOnlyCollection<T>` — read-only wrapper.
- Kotlin: `List<T>` (read-only interface) / `MutableList<T>` (mutable
  interface). Both can point at the same ArrayList.

### Academia

Ownership-type literature distinguishes **aliasing** (shared vs unique)
from **mutability** (read-only vs mutable) as orthogonal axes. See
Clarke et al. *Ownership Types for Flexible Alias Protection* (OOPSLA
'98) and Boyapati et al. *Ownership Types for Safe Programming* (POPL
2002).

The two axes are independent — a type can be any combination. The
naming should reveal both axes where both are relevant.

## Analysis

### Is the current asymmetry actually wrong?

Apple's `NSArray` / `NSMutableArray` scheme is asymmetric in the same
way: the bare name implies immutable; `Mutable*` names the mutable
variant. This is the dominant Apple convention, applied across
Foundation for 25+ years.

Our current names follow this convention:

- `Ownership.Shared` = the "immutable shared" reference (bare name,
  implied immutable).
- `Ownership.Mutable` = the "mutable shared" reference (named for
  mutation).
- `Ownership.Mutable.Unchecked` = the "mutable shared + caller-sync"
  variant.

The "Shared" in `Ownership.Shared` describes the *sharing* axis; the
"Mutable" in `Ownership.Mutable` describes the *mutability* axis.
Different axes named, but the *concept* they share (both ARC-shared)
isn't in `Mutable`'s name.

### Alternative: explicit-pair scheme

```swift
Ownership.Shared.Immutable    // (was Ownership.Shared)
Ownership.Shared.Mutable      // (was Ownership.Mutable)
Ownership.Shared.Mutable.Unchecked
```

| Pros | Cons |
|------|------|
| Explicitly symmetric | Extra nesting layer |
| Both ARC-shared is visible | 32+ external call sites |
| Aligns with Clarke/Boyapati orthogonal axes | Diverges from Apple's `NSArray`/`NSMutableArray` pattern |
| Matches Kotlin `List` / `MutableList` | Higher migration cost |

### Alternative: orthogonal composition (Rust-style)

```swift
Ownership.Shared<T>               // always immutable
Ownership.Shared<Mutex<T>>        // mutable via composition
```

This is a redesign, not a rename. It changes the contract (composition
instead of native mutability). Out of scope for a rename discussion.

### Blast radius

From v2.1.0 inventory:

| Type | File count (non-own-package) |
|------|------------------------------|
| `Ownership.Shared` | 13 files |
| `Ownership.Mutable` | 19 files (14 in swift-pool-primitives) |
| `Ownership.Mutable.Unchecked` | 0 |

Total: ~32 external sites, distributed across:

- `swift-async-primitives` — channel infrastructure.
- `swift-pool-primitives` — 14 sites in connection pooling.
- `swift-cache-primitives` — cache state.
- `swift-foundations/swift-markdown-html-render` — render state.
- Others.

This is the highest blast radius of any rename under consideration.

## Weighing the evidence

### Arguments FOR the rename

1. Explicitly signals "both are ARC-shared, differing only in mutability".
2. Aligns with orthogonal-axis naming (academic precedent).
3. Makes it natural to add `Ownership.Shared.Atomic`, `Ownership.Shared.Mutex`
   etc. under the same roof later.

### Arguments AGAINST the rename

1. **Apple precedent is unambiguous**: `NSArray`/`NSMutableArray` is
   the 25-year-established pattern. The current scheme IS that pattern.
   The rename moves *away from* the dominant Apple convention.
2. **32+ call sites** across 5 packages is the highest blast of any
   rename considered.
3. The asymmetry is a *readability wart*, not a *correctness* or
   *discoverability* issue. Engineers find `Mutable` when they want
   mutation; they find `Shared` when they want immutable sharing.
4. The `Shared.Immutable` path adds a nesting level that most call
   sites never needed.

### The "what would a seasoned Swift engineer expect" test

A Swift engineer coming to this package:

- Wants *immutable, shareable reference* → reaches for `Ownership.Shared`
  (matches "Shared" as the ARC-shared sibling of `let`).
- Wants *mutable, shareable reference* → reaches for `Ownership.Mutable`
  (matches "Mutable" as the obvious name).

Both intuitions land on the current names. The engineer does not have
to think "which side of the symmetry lattice am I on" — the names are
directly reachable.

Under `Shared.Immutable` / `Shared.Mutable`, the engineer types
`Ownership.Shared.` and gets autocomplete for `Immutable` / `Mutable`
/ `Atomic` / … — two steps to find the type instead of one.

## Outcome

**Status**: DEFERRED (recommend: DO NOT RENAME for 0.1.0).

**Decision basis**:

1. The current scheme is the dominant Apple convention
   (`NSArray`/`NSMutableArray` lineage).
2. Blast radius is 32+ sites — by far the largest of any rename
   candidate.
3. The asymmetry is cosmetic, not functional.
4. The seasoned-Swift-engineer reachability is BETTER under the
   current names (one step vs two).

**Action**: keep `Ownership.Shared` / `Ownership.Mutable` /
`Ownership.Mutable.Unchecked` as-is. Revisit only if:

- An `Ownership.Shared.Atomic` sibling is added, AND
- The nesting demand hits critical mass (3+ mutability variants).

If either condition materialises, the rename cost is the same at that
point as it would have been now (no API-compat reason to do it sooner).

**Alternative (if principal prefers symmetry)**: the rename can be
taken at any subsequent revision; downstream packages migrate in
lock-step. The argument is aesthetic; the cost is real.

## References

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — Apple
- Foundation: `NSArray`/`NSMutableArray`, `NSString`/`NSMutableString` —
  canonical Apple mutability-pair pattern
- [Rust std::sync::Arc](https://doc.rust-lang.org/std/sync/struct.Arc.html) — orthogonal composition
- Clarke, D. G., Potter, J. M., Noble, J. (1998). *Ownership Types for
  Flexible Alias Protection*. OOPSLA.
- Boyapati, C., Liskov, B., Shrira, L. (2003). *Ownership Types for
  Object Encapsulation*. POPL.
- v2.1.0 `ownership-types-usage-and-justification.md` — Cluster D

## Provenance

Per-module naming research requested 2026-04-24. Recommendation is
to DEFER — the current scheme is Apple-idiomatic.
