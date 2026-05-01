# Nested `.View` vs `.Borrowed` — Naming Taxonomy

<!--
---
version: 1.2.0
last_updated: 2026-05-01
status: DECISION
tier: 2
scope: cross-package
---
-->

## Revision History

- **1.2.0 (2026-05-01)** — Adopted semantic-invariant framework with
  governing-axis identification + axis-based decision table. Supersedes
  v1.1.0's Pattern 2 keep-`.View` ruling for the access-mode-discriminated
  property/accessor wrapper sub-class. The original ruling considered
  only `.Borrowed` as a rename target for Pattern 2 and explicitly
  rejected it; it did not consider `.Inout` as an alternative. The
  Property family rename surfaced the gap. Pattern 2 splits into
  (a) access-mode-discriminated wrappers (rename per axis-based table)
  and (b) verb-as-property domain-operation namespaces (no automatic
  rename; per-family audit). `Property.View` / `Property.View.Read`
  authorised for rename to `Property.Inout` / `Property.Borrow` plus
  full nested chain and `Property.Consuming → Property.Consume` for
  internal family consistency. `Collection.Count.View` and
  `Collection.Remove.View` remain in category (b) — preserved pending
  separate audit. Framework derived in collaborative discussion
  (Claude × ChatGPT, 3 rounds CONVERGED, transcript at
  `/tmp/property-naming-rename-transcript.md`).
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

## Outcome (v1.1.0 — Pattern 2 portion superseded by v1.2.0 framework below)

**Status**: DECISION

**Principle**: `.Borrowed` is reserved for types that are (or
structurally could be) `Ownership.Borrow.\`Protocol\`` conformers.
`.View` remains for Pattern 2, 3, and 4 uses.

> **v1.2.0 supersession note**: The Pattern 2 portion of the v1.1.0
> principle ("`.View` remains for Pattern 2") is superseded by the
> Framework v1.2.0 below for the access-mode-discriminated sub-class
> of Pattern 2. v1.1.0's binary framing (`.View` vs `.Borrowed`) did
> not consider `.Inout` as a rename target. The v1.2.0 framework
> splits Pattern 2 into (a) access-mode-discriminated property/accessor
> wrapper families (rename per axis-based table) and (b) verb-as-
> property domain-operation namespaces (no automatic rename; per-family
> audit). Pattern 1 (passive borrow-projections), Pattern 3 (stateful
> cursors), and Pattern 4 (UI views) are unchanged.

**Application to the current ecosystem (v1.1.0)**: exactly one outstanding
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

### What this v1.1.0 taxonomy does NOT prescribe

- **No retroactive renames of Pattern 3 / Pattern 4 types.**
  `Binary.Bytes.Input.View`, `Sequence.Consume.View`,
  `Bit.Vector.Ones.View`, `Bit.Vector.Zeros.View`, and all UI `.View`s
  stay as they are.
- **No conformance pressure on Pattern 3 cursors.** `Binary.Bytes.Input`
  and `Sequence.Consume` are not made Ownership.Borrow.`Protocol`
  conformers. Their role is stateful traversal; the protocol is for
  passive projections.

> **v1.2.0 update**: `Property.View`, `Collection.Count.View`, and
> `Collection.Remove.View` are removed from this list. The v1.2.0
> framework below splits Pattern 2 — `Property.View` (access-mode-
> discriminated) is renamed; `Collection.Count.View` and
> `Collection.Remove.View` (verb-as-property domain-operation
> namespaces) require per-family audit before any rename, default
> presumption keep `.View`.

---

## Framework v1.2.0

This section supersedes the Pattern 2 portion of v1.1.0's outcome.
v1.1.0 considered only `.Borrowed` as a rename target for Pattern 2
and explicitly rejected it; it did not consider `.Inout` as an
alternative. The Property family rename surfaced this gap. The
framework below is the principled extension.

### Meta-principle

Name low-level primitives by the semantic invariant clients must
preserve and readers must not misinfer.

### Governing-axis identification

A family is governed by axis X iff *existing public siblings differ
primarily along X*. Future-sibling pressure is secondary evidence —
it may justify reserving naming space, but does NOT by itself force
an X-based name unless the type's public invariant already centrally
depends on X. (The reverse failure mode — naming by imagined future
siblings rather than actual current ones — is *speculative
architecture laundering* and is forbidden.)

### Truthfulness at the governing axis

Once X is identified, name by the invariant at axis X. Six operational
corollaries check whether a candidate satisfies the meta-principle:

| # | Test | What it asks |
|---|------|--------------|
| T1 | Truthfulness | Does the name match what the type IS at the governing axis? |
| T2 | Compositional extensibility | Does the family extend cleanly? |
| T3 | Language alignment | Does it mirror Swift's vocabulary for the same concept? |
| T4 | Call-site clarity | Does it read right at the consumer's extension / use site? |
| T5 | Future-sibling extensibility | Does it leave room for the rest of the family? |
| T6 | Stability under language evolution | Will it still be right when stdlib lands adjacent shapes (e.g., SE-0519)? |

### Installed-convention rule

Mechanical refactor cost is ignored for evergreen primitive naming.
Installed semantic convention is weighed as evidence — normally a
tie-breaker, but may override local capability-truth where the local
name would fracture an existing convention without introducing a real
semantic distinction.

### Central normative paragraph

A nested type is not renamed by matching English words across the
ecosystem. It is named by the governing semantic axis of its family.
Where existing public siblings differ primarily by ownership, access,
or reference capability, the family should mirror the underlying
capability primitive. Where a type is instead a passive borrowed
projection of an owned domain value, the established `.Borrowed`
convention remains correct. Where a type is a domain-operation
namespace, traversal object, or UI/rendering abstraction, `.View`
may remain correct depending on that domain's governing axis.

### Decision table

| Governing axis | Naming convention |
|----------------|-------------------|
| Passive borrow-projection of an owned domain value | `.Borrowed` (e.g., `String.Borrowed`, `Path.Borrowed`, `ISO_9899.String.Borrowed`) |
| Access/ownership/reference-capability-discriminated property/accessor wrapper family mirroring the underlying primitive layer | Mirror the underlying primitive: `.Inout`, `.Borrow`, `.Owned`, `.Shared`, `.Weak`, `.Unowned`, etc. |
| Stateful traversal / cursor / consumption-state | `.View`, `.Cursor`, or `.Iterator` per semantics |
| UI / rendering abstraction | `.View` (different domain) |

### Pattern 2 split

v1.1.0's Pattern 2 ("verb-as-property mutation namespace") is
subdivided in v1.2.0:

- **Access-mode-discriminated property/accessor wrapper families** →
  rename to mirror the underlying ownership/access/reference primitive.
  These families' existing public siblings differ primarily by access
  capability.
- **Verb-as-property domain-operation namespaces** → no automatic
  rename. Decide by per-family audit. Default presumption: keep
  `.View`.

### Application to the Property family (DECISION)

The Property family is access-mode-discriminated. Existing public
siblings (View / View.Read) differ primarily by access capability
(Inout vs Borrow). The framework prescribes the following rename:

| Today | Renamed | Reasoning |
|-------|---------|-----------|
| `Property` | `Property` (unchanged) | Unmarked default for Copyable case; no access-mode discrimination needed |
| `Property.Typed<E>` | `Property.Typed<E>` (unchanged) | `.Typed` is descriptive at the generics-exposure axis; orthogonal to access mode |
| `Property.Consuming<E>` | `Property.Consume<E>` | Family-internal consistency: parallels `.Inout` / `.Borrow` short noun forms (same logic that produced `.Borrow` over `.Borrowing`) |
| `Property.View` | `Property.Inout` | Mutating ~Copyable wrapper over `Ownership.Inout`; family-symmetric naming |
| `Property.View.Typed<E>` | `Property.Inout.Typed<E>` | Mechanical replacement |
| `Property.View.Typed.Valued<n>` | `Property.Inout.Typed.Valued<n>` | Mechanical replacement |
| `Property.View.Typed.Valued.Valued<m>` | `Property.Inout.Typed.Valued.Valued<m>` | Mechanical replacement |
| `Property.View.Read` | `Property.Borrow` | Read-only ~Copyable wrapper over `Ownership.Borrow`; family-symmetric naming |
| `Property.View.Read.Typed<E>` | `Property.Borrow.Typed<E>` | Mechanical replacement |
| `Property.View.Read.Typed.Valued<n>` | `Property.Borrow.Typed.Valued<n>` | Mechanical replacement |

Module/target/product renames:

| Today | Renamed |
|-------|---------|
| `Property View Primitives` | `Property Inout Primitives` |
| `Property View Read Primitives` | `Property Borrow Primitives` |
| `Property Consuming Primitives` | `Property Consume Primitives` |

Declaration-site documentation MUST distinguish `Property.Borrow` from
`String.Borrowed` / `Path.Borrowed` explicitly: the former is a
tag-indexed access-mode wrapper mirroring `Ownership.Borrow`; the
latter are passive borrow-projections of owned domain values. Without
this, ecosystem readers will experience the apparent inconsistency as
defect rather than principled distinction.

### What this v1.2.0 framework does NOT prescribe

- **No retroactive rename of `Collection.Count.View` /
  `Collection.Remove.View`** without per-family framework application.
  Default presumption: keep `.View` pending separate audit. The audit
  asks: do existing public siblings of these types differ primarily
  along access mode? If yes, rename per the table; if no (single-mode
  verb namespaces with no read/write siblings), keep `.View`.
- **No retroactive rename of Pattern 3 / Pattern 4 types** (unchanged
  from v1.1.0).
- **No retroactive rename of types outside the access-mode-discriminated
  property/accessor wrapper category.** The framework applies forward;
  it does not force renames on already-shipped types in unrelated
  categories.
- **No protocol promotion or capability-typealias creation.** The
  rename is mechanical at the type-name level. Existing protocols
  (e.g., `Ownership.Borrow.\`Protocol\``) are unaffected.

### Provenance

Framework derived 2026-05-01 in collaborative discussion between
Claude (Anthropic) and ChatGPT (OpenAI) — 3 rounds, CONVERGED.
Transcript: `/tmp/property-naming-rename-transcript.md`. Converged
plan: `/tmp/property-naming-rename-converged.md`. User confirmed
framework adoption and authorised rename execution scoped to the
Property family + `Property.Consuming → Property.Consume` for
internal consistency. Rename execution itself (the ~183-consumer-file
sweep) requires explicit per-action authorisation; the framework
amendment authorises the design, not the dispatch.

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
