# Nested `.View` vs `.Borrowed` — Naming Taxonomy

<!--
---
version: 1.1.0
last_updated: 2026-04-23
status: DECISION
tier: 2
scope: cross-package
---
-->

## Revision History

- **1.1.0 (2026-04-23)** — ISO_9899.String.View cascade executed per this
  taxonomy's recommendation. Two commits:
  - `df80861` in swift-iso-9899: file rename + type rename + conformance adoption (`extension ISO_9899.String: Ownership.Borrow.\`Protocol\` {}`) + Package.swift dep on swift-ownership-primitives
  - `f6810c3` in swift-foundations/swift-strings: 5 consumer-site renames across 2 files
  - Workspace-wide grep post-execution: zero residual `ISO_9899.String.View` references
  - Pattern-1 catalog below updated: ISO_9899.String.Borrowed moved from "Candidate" to "Renamed"
- **1.0.0 (2026-04-23)** — Initial taxonomy. Identified ISO_9899.String.View
  as the single outstanding Pattern-1 cascade candidate.

## Context

The `Ownership.Borrow.\`Protocol\`` unification DECISION
(`ownership-borrow-protocol-unification.md`, v1.0.0, 2026-04-22, tier 2)
renamed three nested types:

- `Path.View` → `Path.Borrowed`
- `String.View` → `String.Borrowed`
- `Tagged.View` → `Tagged.Borrowed` (via parametric forwarding)

The rename was protocol-driven: conformers of
`Ownership.Borrow.\`Protocol\`` expose a nested `Borrowed` that satisfies
the protocol's `associatedtype Borrowed`. The Phase 1–9 execution
migrated 17 commits across 16 sub-repos and is IMPLEMENTED.

A question surfaced during Phase 9 verification: **the ecosystem still
contains other nested `.View` types. Which of them should cascade to
`.Borrowed`? None? All structurally similar ones? Only Ownership.Borrow
conformers?**

An initial read suggested ecosystem-wide consistency favors cascading
`ISO_9899.String.View`. On closer inspection the ecosystem hosts at least
four distinct patterns all using the name `View`. Treating them uniformly
would mis-classify the majority.

**Trigger**: [RES-012] Discovery — proactive audit during Phase 9
reflection. [RES-001a]-principled: the decision would otherwise be
re-derived case-by-case for each future borrow-view candidate.

**Scope**: cross-package (swift-iso-9899, swift-primitives, potentially
future primitives). [RES-020] Tier 2 — affects multiple packages,
establishes a naming principle for future borrow-like types.

## Question

Of the ~30 nested types named `View` across the ecosystem workspace,
which should be renamed to `Borrowed` for consistency with the
Ownership.Borrow.`Protocol` unification, and what principle decides?

## Analysis

### Inventory (workspace-wide grep, production only)

Filter: `public struct View:` declarations across
`/Users/coen/Developer/` excluding `.build/`, `Experiments/`,
compiler test inputs, issue-reproduction packages. 12 production
matches, separable into four patterns:

#### Pattern 1 — Borrow-view (`~Copyable, ~Escapable` passive projection)

Stores a pointer / span over owned storage. Carries a type-level
invariant (null-termination, alignment, etc.). IS a conformer of
`Ownership.Borrow.\`Protocol\`` or structurally could be.

| Type | Package | Status |
|---|---|---|
| `Path.Borrowed` | swift-primitives (path-primitives) | Renamed in Phase 4 |
| `String.Borrowed` | swift-primitives (string-primitives) | Renamed in Phase 3 |
| `Path.Borrowed` (foundations mirror) | swift-foundations/swift-paths | Renamed in Phase 7b |
| `ISO_9899.String.Borrowed` | swift-iso-9899 | Renamed (commit `df80861` 2026-04-23) |

#### Pattern 2 — Verb-as-property (mutation namespace over `UnsafeMutablePointer<Base>`)

Per [IMPL-020]. Storage is a mutable pointer; the `.View` exists to namespace
methods on a domain verb (`push`, `pop`, `count`, `remove`). NOT a passive
projection — every method mutates. The DocC catalog for
`property-view-protocol-delegation.md` (DECISION, tier 2, 2026-02-12)
documents the shape.

| Type | Package |
|---|---|
| `Property.View` | swift-property-primitives |
| `Collection.Count.View` | swift-collection-primitives |
| `Collection.Remove.View` | swift-collection-primitives |

Renaming this family would mis-suggest they are borrow-projections. They
are not — they are write-enabled accessor namespaces. Keep `.View`.

#### Pattern 3 — Stateful cursor / iterator (`~Copyable` with mutable state)

Tracks position, step, or consumed-element state. NOT a passive view —
clients mutate the cursor as they consume. Structurally may overlap with
Pattern 1's `~Copyable, ~Escapable` annotations, but semantically is a
different thing (state machine, not projection).

| Type | Package | Shape |
|---|---|---|
| `Binary.Bytes.Input.View` | swift-binary-parser-primitives | Borrowed `Span<UInt8>` + mutable `position: Int` |
| `Sequence.Consume.View` | swift-sequence-primitives | `<Element, State>` consumption state |
| `Bit.Vector.Ones.View` | swift-bit-vector-primitives | `Copyable, @unchecked Sendable` iterator |
| `Bit.Vector.Zeros.View` | swift-bit-vector-primitives | Same |

These are NOT conformers of `Ownership.Borrow.\`Protocol\``. Their role
is stateful traversal, not passive projection. Keep `.View`.

#### Pattern 4 — UI / rendering (`HTML.View`, `SwiftUI.View`, etc.)

Entirely unrelated — the name `View` comes from the GUI tradition, not
the borrow tradition. Excluded from this analysis (~20 matches across
coenttb-*, swift-stripe, rule-legal, swift-identities, Vapor, etc.).

### Why the ecosystem-consistency argument doesn't extend beyond Pattern 1

Ecosystem consistency of the form *"all nested `.View` types should
match"* assumes the name `View` denotes a single concept. It doesn't.
The four patterns above encode four different things using the same
English word — a pre-existing ambiguity the borrow-unification exposes
but does not create.

Renaming Pattern 2 / Pattern 3 would:
- Mis-label verb-property accessors as borrow-projections
- Mis-label stateful cursors as passive views
- Push the "but now none of our `.View` types are consistent with each
  other either" problem sideways without resolving it

The correct response is to recognize the patterns are different and to
reserve `.Borrowed` as a more specific name for the one pattern it
actually applies to.

### The principle

**`.Borrowed`** — the nested type that satisfies (or structurally could
satisfy) `Ownership.Borrow.\`Protocol\`.Borrowed`. A passive borrow
projection over owned storage with a type-level invariant. `~Copyable,
~Escapable` by construction. Protocol-driven.

**`.View`** — everything else. Verb-as-property mutation namespaces,
stateful cursors, consumption state, UI views. Each of these has its
own design pattern with existing convention support ([IMPL-020] for
verb-property, etc.).

The distinguishing test: **does the nested type's role, purpose, and
storage match what `Ownership.Borrow.\`Protocol\``'s associatedtype
`Borrowed` describes — a passive borrowed projection of the parent
type's content?** If yes → `.Borrowed`. If no → `.View` (or whatever
else-specific name fits).

## Outcome

**Status**: DECISION

**Principle**: `.Borrowed` is reserved for types that are (or
structurally could be) `Ownership.Borrow.\`Protocol\`` conformers.
`.View` remains for Pattern 2, 3, and 4 uses.

**Application to the current ecosystem**: exactly one outstanding
cascade candidate — `ISO_9899.String.View`.

### `ISO_9899.String.View` — recommendation

Structurally identical to primitives' renamed `String.Borrowed`:
`~Copyable, ~Escapable`, stores `UnsafePointer<Char>`, null-terminated
invariant, passive projection of an owned `ISO_9899.String`.
`ISO_9899.String` does not currently conform to
`Ownership.Borrow.\`Protocol\`` — but under the principle above it
should.

**Scope of the follow-up cascade** (verified via workspace grep):

| File | Sites |
|---|---|
| `swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.View.swift` | Defining file, ~115 lines. Rename to `ISO_9899.String.Borrowed.swift`. |
| `swift-iso-9899/Sources/ISO 9899 Core/ISO_9899.String.swift` | Internal consumer. |
| `swift-foundations/swift-strings/Sources/Strings/Swift.String+ISO_9899.swift` | 3 × `borrowing ISO_9899.String.View` call sites. |
| `swift-foundations/swift-strings/Sources/Strings/ISO_9899.String+Primitives.POSIX.swift` | 1 × `borrowing ISO_9899.String.View` call site. |

Additionally, if conformance is adopted (recommended):
- Add `extension ISO_9899.String: Ownership.Borrow.\`Protocol\` {}` in the defining file
- Package.swift gains a dep on `swift-ownership-primitives`

**Recommended dispatch**: a micro-cascade as a follow-on to Phase 9 with
its own minimal DECISION doc or a simple forward-reference to this
taxonomy. Execution is mechanical — similar scope to Phase 9g.

### What this taxonomy does NOT prescribe

- **No retroactive renames of Pattern 2 / Pattern 3 / Pattern 4 types.**
  `Property.View`, `Collection.Count.View`, `Collection.Remove.View`,
  `Binary.Bytes.Input.View`, `Sequence.Consume.View`,
  `Bit.Vector.Ones.View`, `Bit.Vector.Zeros.View`, and all UI `.View`s
  stay as they are.
- **No conformance pressure on Pattern 3 cursors.** `Binary.Bytes.Input`
  and `Sequence.Consume` are not made Ownership.Borrow.`Protocol`
  conformers. Their role is stateful traversal; the protocol is for
  passive projections.
- **No convention change to [IMPL-020] Property.View pattern.**
  Verb-as-property accessors continue to use `.View` as their canonical
  nested-type name.

## References

### Primary

- `ownership-borrow-protocol-unification.md` (DECISION, v1.0.0, 2026-04-22)
  — establishes the protocol and the `.Borrowed` name for its conformers.
- `ownership-borrow-protocol-unification-implementation-plan.md`
  (IMPLEMENTED, v1.4.0, 2026-04-23) — the 17-commit execution.

### Pattern-specific prior art

- `property-view-protocol-delegation.md` (DECISION, tier 2, 2026-02-12) —
  establishes the Pattern 2 shape. Confirms `Property.View` is a
  verb-property namespace, distinct from borrow-projection.
- `view-vs-span-borrowed-access-types.md` (DECISION, tier 2, 2026-02-28)
  — establishes that null-terminated borrowed access is an irreducible
  concept distinct from Span. Pattern 1 lives here.
- [IMPL-020] (implementation skill) — verb-as-property pattern.

### Workspace inventory tool

Reproducible census:

```bash
grep -rn -E "^\s*(@safe\s+)?public\s+struct\s+View\b" \
  /Users/coen/Developer/ --include="*.swift" 2>/dev/null \
  | grep -v ".build/" | grep -v "Experiments/" | grep -v ".git/" \
  | sort
```

### Convention sources

- `Naming.md` / code-surface skill — [API-NAME-001] Nest.Name pattern.
- `implementation` skill — [IMPL-020] verb-as-property with Property.View.
