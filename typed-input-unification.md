# Typed-Input Unification (D5 / HANDOFF.md Wave 1 Item 2)

<!--
---
version: 1.0.0
last_updated: 2026-05-18
status: DECISION
tier: 2
scope: cross-package
implementations:
  - swift-primitives/swift-input-primitives@450a77f (consumedCount on Input.Slice)
  - swift-primitives/swift-byte-parser-primitives@5fe4774 (exports re-export Input_Primitives + Array_Dynamic_Primitives)
  - swift-primitives/swift-binary-parser-primitives@bea39a47 (Binary.Bytes.Input → typealias for Byte.Input)
---
-->

> **DECISION 2026-05-18**: `Binary.Bytes.Input` collapses to `typealias Input = Byte.Input` in `swift-binary-parser-primitives`. The byte-domain owned-input identity lives in `swift-byte-parser-primitives` (canonical home). All 5 +extension files in binary-parser-primitives delete; the 2 inits and 1 helper that don't already exist on `Byte.Input` survive as extensions on the typealias (which bind through to the underlying `Input.Slice<Array<UInt8>.Indexed<UInt8>>`). 678 tests pass across the 4 most-affected packages; ecosystem build gate clean across 16 packages.

## Context

The byte-ecosystem finalization arc (HANDOFF.md) carried two parallel owned-Copyable byte inputs:

| Type | Package | Date | Shape |
|---|---|---|---|
| `Binary.Bytes.Input` | `swift-binary-parser-primitives` | 2026-02-24 | hand-written `struct` with `storage: [UInt8]` + `position: Index<UInt8>`; 5 `+ext` files duplicating Input.Slice's surface |
| `Byte.Input` | `swift-byte-parser-primitives` | 2026-05-15 | `public typealias Input = Input_Primitives.Input.Slice<Array<UInt8>.Indexed<UInt8>>` |

The two types are structurally interchangeable for binary-parser consumers: same element (UInt8), same checkpoint (`Index<UInt8>`), same Input.Protocol surface. The newer `Byte.Input` is the principled shape — pure typealias to the institute's `Input.Slice<...>`, which already provides `Input.Protocol` and `Input.Access.Random` conformances with matching shape.

D5 of `HANDOFF-byte-arc-followups.md` (Item 5) and Wave 1 Item 2 of `HANDOFF.md` queued this unification with the principal directive: *"we'll want to unify if principally correct - dont defer"*.

This DECISION lands the unification at the typealias layer — the principled minimum-change shape.

## Question

Should `Binary.Bytes.Input` be refactored to align with the newer `Byte.Input`, and if so, what is the principled shape?

## Decision

**Option A — `Binary.Bytes.Input = Byte.Input`** (the chosen option).

`Binary.Bytes.Input` becomes a typealias to `Byte.Input` (which itself is a typealias to `Input_Primitives.Input.Slice<Array<UInt8>.Indexed<UInt8>>`). The binary-domain *name* survives; the byte-domain *identity* is canonical.

```swift
// In swift-binary-parser-primitives/Sources/Binary Input Primitives/Binary.Bytes.Input.swift
extension Binary.Bytes {
    public typealias Input = Byte.Input
}
```

### Why Option A

1. **Source-transparency for downstream consumers**. `swift-binary-coder-primitives` and `swift-ascii` both reach `Binary.Bytes.Input` through method-call surface only (no `.storage` / `.position` field access — verified by workspace-wide grep). Replacing the struct with a typealias is invisible at call sites.

2. **Eliminates duplication, not divergence**. The 5 `+ext` files in `binary-parser-primitives` (`+init`, `+properties`, `+mutation`, `+subscript`, `+Input.Protocol`) duplicate what `Input.Slice` already provides via its `Input.Protocol` / `Input.Access.Random` conformances. Surface-mapping verdicts:

   | File | Verdict |
   |---|---|
   | `+init` `init(_ bytes: [UInt8])` | REDUNDANT (`Byte.Input` has it) |
   | `+init` `init<Bytes: Collection>` / `init(_ bytes: ArraySlice<UInt8>)` | KEEP as binary-domain extension on the typealias (delegates to `Byte.Input([UInt8])`) |
   | `+properties` `count` / `isEmpty` / `first` / `totalCount` | REDUNDANT (`Input.Slice`'s `Input.Protocol`) |
   | `+properties` `consumedCount` | LIFTED to `Input.Slice` in `input-primitives` (mirrors `Input.Buffer.consumedCount`) |
   | `+mutation` `advance()` / `advance(by:)` | REDUNDANT (`Input.Slice`'s `Input.Protocol`) |
   | `+subscript` `subscript(offset:)` | REDUNDANT (`Input.Slice`'s `Input.Access.Random`) |
   | `+subscript` `starts(with:)` | KEEP as binary-domain extension on the typealias (delegates to `input.access.starts(with:)`) |
   | `+Input.Protocol` | REDUNDANT (`Input.Slice<Array<UInt8>.Indexed<UInt8>>` conforms with matching `Element = UInt8`, `Checkpoint = Index<UInt8>`) |

3. **Aligns with [API-NAME-001b] LargerDomain.Subdomain**. The byte-extraction arc settled that `Byte.Parser`/`Byte.Input` is the principled shape — Byte is the *subject*, Input is the *role-within-byte-domain*. `Binary.Bytes.Input` was the older binary-domain-owned shape (binary as the broader namespace, Bytes.Input the binary-bytes specialization). With `Byte.Input` providing the canonical byte-domain owned input, `Binary.Bytes.Input` is best read as the binary-domain *alias* for the byte-domain canonical — exactly the typealias shape Option A lands.

4. **Per [API-IMPL-016] (Typealiases Allow Nested Type Extensions)**, `Binary.Bytes.Input.View` continues to resolve through `Binary.Bytes.Input` → `Byte.Input` → `Input.Slice<Array<UInt8>.Indexed<UInt8>>`; the `extension Binary.Bytes.Input { typealias View = Cursor<Byte> }` declaration binds through to the underlying type. View access at `Binary.Bytes.Input.View` works as before.

### Why NOT Option B

Option B — `Binary.Bytes.Input = Input_Primitives.Input.Slice<Array<UInt8>.Indexed<UInt8>>` (typealias direct to Input.Slice, bypassing Byte.Input) — was considered and rejected:

- Bypasses the byte-domain owned-input identity that `swift-byte-parser-primitives` established 2026-05-15.
- Each binary-parser-primitives consumer-call resolves through the structural `Input.Slice<...>` chain without crossing the byte-domain boundary, missing the LargerDomain.Subdomain framing.
- Adds no benefit over Option A; the typealias-chain depth is one indirection difference (chains optimize away regardless).

### Why NOT Option C (status quo)

Option C — preserve `Binary.Bytes.Input` as a hand-written struct — was rejected by the principal directive "we'll want to unify if principally correct - dont defer" combined with the structural-correctness finding that the struct duplicates `Input.Slice`'s surface without adding domain-specific behavior. Keeping parallel implementations of the same shape across two packages is the anti-pattern this DECISION corrects.

## Relationship to byte-cursor-primitive-unification.md

`byte-cursor-primitive-unification.md` v1.3.0 (IN_PROGRESS) and the successor `cursor-abstractions-l1-ecosystem.md` v1.6.0 (SUPERSEDED → `cursor-shape-a-vs-three-worlds.md` v1.2.0 IMPLEMENTED) address the *borrowed* `~Copyable & ~Escapable` Span-cursor layer (`Binary.Bytes.Input.View`, `Lexer.Scanner`). This DECISION addresses the *owned* Copyable Input layer (`Binary.Bytes.Input`, `Byte.Input`).

The cursor docs explicitly held off the owned-input question:

> "Item 1 (the Span-cursor layer) and the Input.Protocol-conforming Copyable layer (Item 2) are structurally distinct" — `byte-cursor-primitive-unification.md` v1.3.0 §"Item 1 vs Item 2"
>
> "Item 2 (D5 Binary.Bytes.Input vs Byte.Input unification) is a separate arc" — same doc, Outcome
>
> "World 3 (Owned Copyable input cluster) — `Binary.Bytes.Input` ... **No structural change recommended in this arc.** HANDOFF.md Wave 1 Item 2 ... is a separate arc focused on the *typed-input* unification at the owned-Copyable layer." — `cursor-abstractions-l1-ecosystem.md` v1.6.0 §"World 3"

This doc IS that separate arc. It composes with the cursor docs by:

1. **No conflict with the cursor IMPLEMENTED shape**. `Binary.Bytes.Input.View = Cursor<Byte>` (per the cursor arc's `cursor-shape-a-vs-three-worlds.md` v1.2.0 single-generic landing) and `Binary.Bytes.Input = Byte.Input` (this DECISION) are orthogonal extensions of the binary-domain typealias namespace. The View extension binds at one underlying type (Cursor<Byte>); the Input typealias binds at another (Input.Slice<Array<UInt8>.Indexed<UInt8>>). Both names resolve correctly per [API-IMPL-016].

2. **Dissolves the Phase 4 W3 centralization to cursor-primitives**. The cursor arc's Phase 4 follow-on contemplated migrating Binary.Bytes.Input to `swift-cursor-primitives` as part of a full ι-shape centralization. With Binary.Bytes.Input now a typealias chain leading to `Input.Slice<...>` (which lives in `swift-input-primitives`, not `swift-cursor-primitives`), the W3 centralization is dissolved: the owned-Copyable input identity now lives in the byte-parser-primitives canonical home, and the underlying `Input.Slice` substrate lives in input-primitives. No further W3 centralization is needed; Phase 4 dispatch reduces to addressing W1 only (Binary.Cursor + Binary.Reader).

## Phase 0 Verification (HARD GATE; PASSED)

Three checks, all passed before Phase 1 refactor landed:

1. **Surface mapping check**: each of the 5 +ext file surfaces mapped cleanly to one of REDUNDANT / LIFT-to-Input.Slice / KEEP-as-binary-domain. No binary-domain-specific surface that would require a wrapper-struct shape; typealias is sufficient.

2. **View nested-type behavior verification**: per [API-IMPL-016], `extension Binary.Bytes.Input { typealias View = Cursor<Byte> }` resolves through the typealias to bind on the underlying Input.Slice<...>. Workspace-wide grep confirms all `Binary.Bytes.Input.View(...)` call sites (18 in test files, 0 in source files outside the View declaration) work via the typealias-namespace lookup.

3. **binary-coder source-transparency check**: read `Binary.Coder.swift` + `Binary.Coder+Coder.Protocol.swift`. All `Binary.Bytes.Input` usages are method-call surface (`.first`, `.isEmpty`, `.count`, `input.advance()`); zero field access on `.storage` or `.position`. Same finding for `swift-ascii`'s 6 consumer files and binary-parser-primitives' 4 internal-consumer files (Binary.Parse.Access*, Binary.Bytes.Machine*).

## Implementation Summary

Three commits across three packages:

1. `swift-primitives/swift-input-primitives@450a77f` — adds `consumedCount: Index<Element>.Count` to `Input.Slice`'s `Input.Protocol` conformance (mirrors the parallel property on `Input.Buffer`). Enables binary-parser-primitives' refactor without breaking existing `input.consumedCount` call sites in `swift-binary-parser-primitives`, `swift-ascii`, `swift-console`.

2. `swift-primitives/swift-byte-parser-primitives@5fe4774` — exports.swift re-exports `Input_Primitives` + `Array_Dynamic_Primitives`. Consumers of `Byte.Input` need member-import visibility of `Input.Protocol` / `Collection.Protocol` conformances on the underlying types; re-exporting from the canonical home closes the import-burden gap for every downstream consumer.

3. `swift-primitives/swift-binary-parser-primitives@bea39a47` — refactors `Binary.Bytes.Input` from a hand-written struct to a typealias for `Byte.Input`. Adds the `Byte Parser Primitives` product dep to the `Binary Input Primitives` target. Deletes the 5 `+ext` files. Preserves the surviving 2 inits + `starts(with:)` as extensions on the typealiased name. Net diff: 90 insertions, 176 deletions (-86 lines).

## Termination Gate ([HANDOFF-035] / [HANDOFF-040])

Workspace-wide grep (literal + nested-type forms) for `Binary.Bytes.Input`: all residuals are expected sites — the typealias declaration, the View extension, downstream consumer sources, doc-comment references in other research / READMEs / DocC.

Ecosystem build gate across 16 packages — all green per `rm -rf .build && swift package update && swift build && swift test` serially per [PKG-BUILD-009]:

| Package | Build | Tests (where run) |
|---|---|---|
| swift-input-primitives | green | 44/44 PASS |
| swift-cursor-primitives | green | — |
| swift-byte-primitives | green | — |
| swift-byte-parser-primitives | green | 19/19 PASS |
| swift-binary-primitives | green | — |
| swift-binary-parser-primitives | green | 69/69 PASS |
| swift-binary-coder-primitives | green | 45/45 PASS |
| swift-lexer-primitives | green | — |
| swift-parser-primitives | green | — |
| swift-ascii-parser-primitives | green | — |
| swift-glob-primitives | green | — |
| swift-manifest-primitives | green | — |
| swift-version-primitives | green | — |
| swift-foundations/swift-ascii | green | 501/501 PASS |
| swift-foundations/swift-lexer | green | — |
| swift-foundations/swift-json | green | — |

## Out of Scope

- **Renaming `Byte.Input` to something else** — settled by the byte-extraction arc per [API-NAME-001b]; not revisited here.
- **Wave 1 Items 3, 4, 5** of HANDOFF.md — independent of this arc.
- **Phase 4 W1 expansion** (Binary.Cursor + Binary.Reader to cursor-primitives) — deferred per the cursor arc's Phase 4 framing; this DECISION only dissolves the W3 portion.
- **Ecosystem-wide `public var` storage perf audit** (surfaced by the cursor arc as the root cause of the 20-100× speedup in BENCH-011) — separate arc.
- **`throws(any Swift.Error)` in tests after input-primitives lint cleanup** — surfaced during the lint-cleanup subagent dispatch as a sub-class of multi-error tests that pure mechanical typed-throws cannot express without `Either_Primitives` dep or per-file `enum TestFailure: Swift.Error`. Documented as queued [API-ERR-006] refinement; not blocking.

## Cross-references

- `swift-institute/Research/byte-cursor-primitive-unification.md` v1.3.0 — antecedent (Item 1 / W2 borrowed Span-cursor layer)
- `swift-institute/Research/cursor-abstractions-l1-ecosystem.md` v1.7.0 — antecedent (Three-Worlds framing, SUPERSEDED → cursor-shape-a-vs-three-worlds.md); this DECISION dissolves the Phase 4 W3 portion
- `swift-institute/Research/cursor-shape-a-vs-three-worlds.md` v1.2.0 IMPLEMENTED — sibling DECISION for the borrowed cursor layer
- `swift-institute/Research/byte-primitive-extraction-and-domain-naming.md` v1.0.1 — establishes `Byte.Input` as canonical via [API-NAME-001b]
- `HANDOFF.md` Wave 1 Item 2 — closes here
- `HANDOFF-byte-arc-followups.md` Item 5 D5 — resolves here

## Provenance

Authored 2026-05-18 as Phase 3 doc back-port of HANDOFF-typed-input-unification.md. Implementation commits cited above.

## Changelog

- **v1.0.0** (2026-05-18): DECISION — Option A (`Binary.Bytes.Input = Byte.Input`) lands across three packages with the ecosystem build gate green at 16 packages and 678+ tests passing on the 4 most-affected packages. Dissolves the Phase 4 W3 centralization concern from `cursor-abstractions-l1-ecosystem.md`. Closes HANDOFF.md Wave 1 Item 2 and HANDOFF-byte-arc-followups.md Item 5 (D5).
