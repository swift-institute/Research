# swift-io-primitives Research — Entry Point

**Read this first.** This document is the canonical entry point for any
agent (human or AI) working in `swift-io-primitives/Research/`. The
notes around this README are the algebra and shape-design exploration
that *justifies* the swift-io substrate without being constrained by
its downstream consumers.

---

## What this directory is for

This is the **upstream design playground** for IO algebra and witness
shape exploration. It exists so that:

- Algebraic theory of IO can be discussed without affecting downstream
  consumer-facing API stability.
- Alternative witness shapes (Shape F, the Tokio/ZIO/Eio/Monoio styles,
  generic-error/generic-ops/domain-via-map variants) can be modelled,
  experimented with, and compared in isolation.
- The result of that exploration informs `swift-io` (downstream L3
  package), but `swift-io` does not depend on `swift-io-primitives`
  for any of these notes — the notes are research artifacts, not API.

The downstream substrate (`swift-foundations/swift-io/`) is *deliberately
stable*. The 4-op witness, three handler families, swift-threads
boundary — those decisions are committed and have a real consumer
(swift-file-system) waiting to migrate. **Do not destabilise that
substrate from research notes here.** New shapes get experimented with;
they are adopted by swift-io only after a deliberate, separate decision.

## Layer position

| Layer | Package | Role |
|-------|---------|------|
| L1 Primitives | `swift-io-primitives/Research/` *(this directory)* | Vocabulary, algebra, shape design rationale |
| L1 Primitives | `swift-io-primitives/Experiments/` (sibling) | Concrete shape sketches and algebra experiments — 16 packages |
| L1 Primitives | `../../Research/effect-primitives-and-io-algebra-relation.md` (swift-primitives super-repo) | Cross-cutting positioning vs swift-effect-primitives |
| L3 Foundations | `../../../swift-foundations/swift-io/` | The actual IO substrate consumed by file-system / server |

Upstream-of-everything. No swift-io dependency here, by design.

## Source of truth

Two distinct source-of-truth domains for two distinct questions:

| Question | Source of truth |
|----------|----------------|
| "What does the IO substrate currently expose?" | `../../../swift-foundations/swift-io/Sources/` and `../../../swift-foundations/swift-io/Research/README.md` |
| "What does the algebra say? What shapes have we explored?" | This directory + `../Experiments/` (sibling — 16 packages, see below) |

A future agent answering an *implementation* question should consult
swift-io. An agent answering a *theory* or *shape-design* question
should consult here.

## Contents (post-2026-04-20 migration from swift-io)

| File | Purpose | Status |
|------|---------|--------|
| `io-algebraic-effects-foundation.md` | Full algebra grounding (Plotkin–Power–Pretnar; Σ_IO mapping; draft E_IO laws) | DRAFT |
| `algebraic-effects-cheatsheet.md` | Vocabulary distilled from Pretnar 2015, Swierstra 2008, Kiselyov-Ishii 2015 + supporting papers | REFERENCE |
| `io-witness-design-literature-study.md` | Design-space exploration; literature grounding for witness shapes | v4.0 |
| `io-witness-shape-selection.md` | Selection of Shape F from 10 candidates | DECISION (2026-04-17) |
| `io-witness-shape-zoo-addendum.md` | Update to the zoo analysis post-macro-convention change | RECOMMENDATION |
| `io-witness-capability-runner-split.md` | Capability/runner split rationale | RECOMMENDATION |
| `io-witness-borrowing-async-tension.md` | Witness/language interaction tension | OPEN |

These docs were originally written in `swift-foundations/swift-io/Research/`
and moved here on 2026-04-20 to enforce the upstream-of-substrate
separation. **Internal cross-references between these files remain
valid** (relative paths within this directory). **Cross-references *out*
to swift-io files (e.g., `io-architecture.md`, `perfect-api.md`) are now
cross-package paths**: `../../../swift-foundations/swift-io/Research/<file>`.
Some moved docs may have stale relative paths; treat as known maintenance
debt and fix on consultation.

## Sibling Experiments (`../Experiments/`)

Co-located with this Research/ directory. **13 standalone Swift packages,
zero external dependencies** — strict L1 isolation. Run any with
`cd ../Experiments/<name> && swift build && swift run`.

**Witness shape candidates** (9) — formal exploration of dictionary
encodings, written as hand-crafted struct-of-closures (no macro):

- `io-witness-shape-f` — selected shape (capability + runner split)
- `io-witness-domain-via-map` — domain mapping alternative
- `io-witness-domain-generic-substrate` — generic substrate
- `io-witness-eio-style` — Eio (OCaml) pattern
- `io-witness-generic-error` — generic error handling
- `io-witness-generic-ops` — generic operation types
- `io-witness-monoio-style` — Monoio (Rust) pattern
- `io-witness-tokio-style` — Tokio (Rust) pattern (split AsyncRead/AsyncWrite/Closer)
- `io-witness-zio-style` — ZIO (Scala) pattern

**Witness language interactions** (1) — specific Swift-feature edge
cases for shape design:

- `witness-noncopyable-parameter` — `~Copyable` parameter shapes (V1–V5)

**Removed (2026-04-20)**:

- `witness-over-actor` — was a placeholder; the witness-vs-actor question
  is covered more rigorously by `io-witness-shape-f` and the `Witness.V*`
  variants in `witness-noncopyable-parameter`. Deleted rather than fixed
  because it had not progressed beyond skeleton.

**Algebra encoding tracks** (3):

- `io-algebra` — `IO<Env, LeafError, Value>` monad-transformer encoding (ReaderT · ExceptT · IO)
- `io-free-encoding` — Free<Σ_IO> freer-monad encoding (Kiselyov-Ishii 2015); program-as-data with two-interpreter equivalence demo
- `witness-maperror-sending-return` — error-mapping return-type shapes

### What was moved out (and why)

Three experiments specifically tested the `@Witness` macro itself
(rather than IO algebra/shape). They were relocated to
`../../../swift-foundations/swift-witnesses/Experiments/` on
2026-04-20 because the macro is a foundations-layer tool and L1
experiments must not depend on L3:

- `io-witness-macro-generic-compat` — macro generic-parameter compat
- `witness-mock-borrowing` — `@Witness(.mock)` borrowing semantics
- `witness-recording-against-properties` — `Witness.Recording` infra

### Isolation invariant

Every experiment in this directory must build with **no external
package dependencies**. If you add a new shape candidate that needs
the `@Witness` macro for its core hypothesis, place it in
`swift-witnesses/Experiments/` instead. If you need a shape
experiment here, hand-write the struct-of-closures pattern — the
shape-test value is in the struct, not the macro convenience.

### Single-file V1–V5 exception to [API-IMPL-005]

Two experiments deliberately use a single `main.swift` containing
multiple types (`witness-noncopyable-parameter` and
`witness-maperror-sending-return`). Each file demonstrates an
incremental V1→V5 hypothesis sequence — the side-by-side narrative
is the experiment. Splitting into 5 files would destroy the
comparison.

All other code-surface conventions still apply: Nest.Name
(`Witness.V1`, `Witness.V2`, …; `IO.Plain`, `IO.Sendable`), no
compound identifiers, typed throws, minimal type bodies. The
multi-type-per-file exception is documented at the top of each
affected file.

## Cross-package references

- Substrate documentation: `../../../swift-foundations/swift-io/Research/README.md`
- Substrate source of truth: `../../../swift-foundations/swift-io/Sources/IO Core/IO.swift`
- Effect-primitives positioning: `../../Research/effect-primitives-and-io-algebra-relation.md`

## Anti-patterns inherited from `swift-io/Research/README.md`

The same anti-patterns apply here. Three are worth restating in
this context:

1. **Do not destabilise swift-io from research here.** This directory
   exists to *explore*; swift-io exists to *ship*. New shapes proposed
   here become swift-io adoptions only via deliberate cross-package
   decisions, not by docs claiming "we should switch to Shape X".

2. **Do not elaborate handler-internal operations into "the public
   algebra".** The public Σ_IO is the four operations on the `IO`
   witness in swift-io. Algebra notes here may discuss richer internal
   signatures, but must explicitly mark them as *internal to a handler*,
   not as the public consumer-facing surface.

3. **Do not propose adding an "effect system" dependency to swift-io.**
   swift-io is the algebraic effect substrate; it stands alone. Algebra
   notes here are *vocabulary for thinking*, not infrastructure to
   import.

## Reading order

1. `io-algebraic-effects-foundation.md` — read for full theoretical context
2. `algebraic-effects-cheatsheet.md` — read for fast vocabulary lookup
3. `io-witness-design-literature-study.md` — read for shape design space
4. `io-witness-shape-selection.md` — read for the Shape F choice
5. The remaining `io-witness-*` notes — read for specific design tensions

## Conventions for adding new research notes

1. Frontmatter must declare `status: DRAFT|RECOMMENDATION|DECISION|HISTORICAL`.
2. State whether the note is pure exploration vs. proposes a swift-io change.
3. Any "we should change swift-io to X" claim must explicitly call out
   which file in `swift-foundations/swift-io/Sources/` would be touched
   and what the migration cost is.
4. Cross-reference this README from any new top-level note.
5. If a new shape candidate is proposed, add a corresponding experiment
   under `../Experiments/io-witness-<name>/` (sibling directory) rather
   than inlining lengthy code in research notes.
