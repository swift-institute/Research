# Naming: `Ownership.Unique` vs `Ownership.Box`

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

`Ownership.Unique<Value: ~Copyable>` is the heap-owned, exclusive,
`~Copyable` cell — a named primitive for "own this value on the heap
with a deterministic deinit". Swift stdlib has no direct analog; the
closest shapes are:

- `ManagedBuffer<Header, Element>` — header + trailing elements, requires
  subclassing.
- SE-0437 noncopyable primitives (in-flight) — introduces stdlib-level
  `Cell<T>` but not specifically a heap-owned exclusive cell under a
  single name.

This primitive exists to fill the gap.

## Question

Should `Ownership.Unique` be renamed to `Ownership.Box`?

Pre-condition: the rename is only considered *after* `Ownership.Transfer.Box`
renames to `Ownership.Transfer.Erased` (see `naming-transfer-box-to-erased.md`);
otherwise two `Box` names would co-exist in `Ownership`, and the
qualified-path `Ownership.Box` / `Ownership.Transfer.Box` would be
ambiguous for humans even if the compiler resolves them.

## Prior Art — Heap-Owned Exclusive Cells

### Rust stdlib

`std::boxed::Box<T>` — *a pointer type that uniquely owns a heap
allocation of type T*. This is exactly the contract `Ownership.Unique`
implements:

| Contract fragment | Rust `Box<T>` | `Ownership.Unique<T>` |
|-------------------|---------------|------------------------|
| Heap allocation | Yes | Yes (via `UnsafeMutablePointer`) |
| Exclusive ownership | Yes (move-only) | Yes (`~Copyable` wrapper) |
| Deterministic drop | Yes | Yes (`deinit`) |
| Single owner | Yes | Yes |

Source: [Rust std::boxed::Box](https://doc.rust-lang.org/std/boxed/struct.Box.html).

### C++ stdlib

`std::unique_ptr<T>` — exclusive-owner smart pointer. The C++ name
"unique_ptr" is the ancestor of the concept under discussion; "box" is
the Rust-era refinement of the same contract under a shorter name.

### Swift Evolution / Apple direction

- SE-0390 (noncopyable structs/enums), SE-0427 (noncopyable generics),
  SE-0437 (noncopyable stdlib primitives), SE-0519 (Borrow / Inout
  types) — Apple is building the vocabulary around ownership but has
  not taken a name for "heap-owned exclusive cell". The space is open
  in Swift.
- Swift stdlib has no `Box` type anywhere. The token is unused.

### Academia

Wadler's *Linear types can change the world!* (1990), Walker's
*Substructural Type Systems* (2005 in *Advanced Topics in Types and
Programming Languages*), and the Rust ownership papers all agree:
the canonical primitive for "linearly-owned heap value" is the one
Rust ships as `Box<T>`. The name "Unique" appears in Rust's
**unstable** `core::ptr::Unique` (an internal pointer type used
by the implementation of `Box`, not the public face). Rust does not
surface "Unique" to users.

## Analysis

### Recognition curve

| Name | Swift reader's first guess | Rust reader's first guess | C++ reader's first guess |
|------|---------------------------|---------------------------|--------------------------|
| `Ownership.Unique` | "uniqueness" (vague); maybe Rust's internal `Unique` | Internal pointer plumbing | — |
| `Ownership.Box` | (Swift stdlib: no precedent; reader reaches for Rust) | Rust `Box<T>` — heap-owned exclusive cell | C++ `unique_ptr` analogue |

`Box` is the name the largest cohort of Swift-adjacent engineers will
reach for. `Unique` requires a docstring read to confirm the same
thing.

### Apple alignment

No direct Apple-stdlib name exists; the slot is open. However, Apple's
naming culture (`ManagedBuffer`, `Unmanaged`, `Never`, `Result`) prefers
short, descriptive nouns. `Box` fits that register better than `Unique`
(which is closer to an adjective than a noun).

### Academic alignment

The linear-types literature does not prescribe a name. Rust's choice
of `Box` is the de-facto standard for public-facing APIs.

### Blast radius

From the v2.1.0 usage inventory (2026-04-23):

| Type | File count (non-own-package) |
|------|------------------------------|
| `Ownership.Unique` | 1 (backward-compat doc) |

Near-zero direct consumers. The rename is mechanical.

### The Rust-`Box` semantic match

Rust's `Box<T>` IS the exclusive-owner heap cell. That is the single
best meaning-fit in cross-language literature. Choosing `Box` for
`Ownership.Unique` aligns the Swift ecosystem with the dominant prior
art at the point where both languages converge (both support move
semantics + exclusive ownership).

## Counter-arguments

1. **Clarity at the type level**. "Unique" is *specific* (single owner);
   "Box" is *structural* (boxed up). A pedant might argue we are naming
   the storage shape, not the ownership contract. Counter: Rust's Box
   *is* the name for exclusive ownership; usage drives semantics.

2. **Consistency with Rust's internal `Unique`**. Rust's `core::ptr::Unique`
   is a non-public internal. Most Swift engineers won't encounter it.
   The public Rust name is `Box`; that is what adoption optimises for.

3. **Risk of confusion with "boxed value" (existential-like wrapper)**.
   Swift has no `Box` at module scope, so there is no existing confusion.
   In the `Ownership` namespace, the contract is exclusive ownership —
   the docstring makes the contract crisp.

## Outcome

**Status**: RECOMMENDATION (conditional).

**Decision basis**:
1. `Box` is the dominant name for "heap-owned exclusive cell" in
   Rust/C++ literature.
2. `Box` aligns with Apple's short-noun naming register.
3. Near-zero blast radius.
4. Precondition — `Transfer.Box` → `Transfer.Erased` (see the companion
   research) must land first.

**Action** (conditional on A1 landing):

1. Land A1 (`Transfer.Box` → `Transfer.Erased`).
2. Rename `Ownership.Unique` → `Ownership.Box`.
3. Update the `Ownership Unique Primitives` product target to
   `Ownership Box Primitives`.
4. Update `swift-reference-primitives`'s Reference.swift doc table
   (G1 in the audit) — single line change.
5. Update 1 consumer site + 1 docstring carryover.

**Alternative (keep `Unique`)**: if the principal values "describes the
contract" over "matches prior-art adoption", `Unique` stays. The
argument for staying is: `Unique` is semantically more precise; `Box`
is adoption-optimised.

The recommendation is to rename, because (a) the ecosystem's
spec-mirroring rule ([API-NAME-003]) does not apply (no spec defines
this), (b) [API-NAME-001a] prefers the shortest natural noun that
engineers will recognise, and (c) aligning with Rust's public `Box`
compounds the ecosystem's readability for the cross-language engineer
cohort.

## References

- [Rust std::boxed::Box](https://doc.rust-lang.org/std/boxed/struct.Box.html)
- Rust `core::ptr::Unique` (unstable internal API; no stable doc URL)
- [C++ std::unique_ptr](https://en.cppreference.com/w/cpp/memory/unique_ptr)
- [SE-0437: Noncopyable stdlib primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)
- [SE-0519: Borrow and Inout](https://forums.swift.org/t/se-0519-borrow-and-inout-types-for-safe-first-class-references/85151)
- Wadler, P. (1990). *Linear types can change the world!*
- Walker, D. (2005). *Substructural Type Systems*, in B. C. Pierce (ed.)
  *Advanced Topics in Types and Programming Languages*
- `swift-reference-primitives/Sources/Reference Primitives/Reference.swift` —
  current doc table
- v2.1.0 `ownership-types-usage-and-justification.md` — Cluster C
- `naming-transfer-box-to-erased.md` — precondition

## Provenance

Per-module naming research requested 2026-04-24. This is the second
step in the two-step rename sequence (A1 then A3).
