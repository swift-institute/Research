# Package and Namespace Noun Convention

<!--
---
version: 1.0.0
last_updated: 2026-04-21
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

Package names and Swift namespaces in the Swift Institute ecosystem have so
far drifted between **noun** form and **gerund** form without a governing
rule. Most primitive packages use the noun (`Graph`, `Buffer`, `Machine`,
`Layout`, `Property`), a handful use the gerund (`Rendering`, `Positioning`,
`Formatting`, `Ordering`), and the renderer-family Layer 3 foundations use
the gerund as a suffix (`swift-html-rendering`, `swift-pdf-rendering`,
`swift-svg-rendering`, …).

Separately, the ecosystem already contains a stable **protocol-naming
pattern**: the canonical capability protocol of a namespace is declared as
`Namespace.\`Protocol\`` (backtick-escaped because `Protocol` is reserved).
This pattern is in active use across `swift-parser-primitives`
(`Parser.\`Protocol\``), `swift-array-primitives` (`Array.\`Protocol\``),
`swift-algebra-*-primitives`, `swift-affine-primitives`, and several other
primitive packages.

A rename discussion for `swift-rendering-primitives` (as part of the UI
framework research) surfaced a broader rule: the **gerund form is most
naturally the *protocol* name**, not the namespace name. A conformance reads
grammatically as "X is rendering / positioning / formatting / ordering" —
which is exactly the role the gerund plays in English. If the gerund names
the protocol, the package and namespace are free to take the noun form,
which reads as the domain ("the domain of Render / Position / Format /
Order"). This reframes the existing `Namespace.\`Protocol\`` pattern into
a general **noun/gerund duality** that applies ecosystem-wide.

**Trigger**: the `swift-rendering-primitives` split into core / markup /
image variants (per
`swift-foundations/Research/swift-user-interface-package-decomposition.md`)
surfaced the inconsistency. Executing that split without first settling
the naming rule would lock in precedent that later contradicts the rule
when applied elsewhere.

**Constraints**:
- Swift Institute primitive packages use the `-primitives` suffix.
- Swift Institute types use Nest.Name ([API-NAME-001]); no compound names.
- `Protocol` is a reserved keyword; the backtick-escaped form is already
  ratified ecosystem practice.
- External-compatibility packages (e.g. `swift-testing` shadowing Apple's
  `swift-testing`) may have binding reasons to retain the external name.

**Stakeholders**: every primitive package author; every consumer updating
imports; skill authors writing or updating naming conventions.

## Question

1. What is the ecosystem-wide rule for package and namespace naming
   (noun vs gerund vs verb-root)?
2. What is the companion rule for the capability-protocol name (how the
   gerund form is expressed within a namespace)?
3. Which existing packages and namespaces violate the rule?
4. How are the violations renamed (what is the target form for each)?
5. What special cases (external-compat, domain conflicts) justify
   deviating from the rule?

## Analysis

### Existing `Namespace.\`Protocol\`` pattern

The backtick-escaped `Protocol` name for a namespace's canonical capability
protocol is already in use. Examples:

| Package                         | Namespace       | Protocol                          |
|---------------------------------|-----------------|-----------------------------------|
| `swift-parser-primitives`       | `Parser`         | `Parser.\`Protocol\``              |
| `swift-array-primitives`        | `Array`          | `Array.\`Protocol\`` (via hoisted `__ArrayProtocol`) |
| `swift-algebra-field-primitives` | `Algebra.Field`  | `Algebra.Field.\`Protocol\``       |
| `swift-algebra-group-primitives` | `Algebra.Group`  | `Algebra.Group.\`Protocol\``       |
| `swift-algebra-monoid-primitives`| `Algebra.Monoid` | `Algebra.Monoid.\`Protocol\``      |
| `swift-algebra-magma-primitives` | `Algebra.Magma`  | `Algebra.Magma.\`Protocol\``       |
| `swift-affine-primitives`        | `Affine.Discrete.Vector` | `Affine.Discrete.Vector.\`Protocol\`` |

All of these use a **noun** namespace and expose the canonical capability
protocol as `\`Protocol\``. The pattern is load-bearing for generic
constraints like `where V: Array.\`Protocol\``.

Swift syntax limitation: a protocol cannot be nested inside a generic type.
Packages whose namespace is a generic type declare the protocol at module
scope (e.g. `__ArrayProtocol`) and re-export it via `extension Nest {
public typealias \`Protocol\` = …}`. This is the pattern used by
`swift-array-primitives`.

### Current violations (gerund as namespace)

Primitive packages with gerund-form namespace:

| Package                          | Current namespace | Target noun form |
|----------------------------------|-------------------|------------------|
| `swift-formatting-primitives`     | `Formatting`       | `Format`          |
| `swift-ordering-primitives`       | `Ordering`         | `Order`           |
| `swift-positioning-primitives`    | `Positioning`      | `Position`        |
| `swift-rendering-primitives`      | `Rendering`        | `Render`          |

Layer 3 foundations with gerund-form suffix (`-rendering`):

| Package                             | Proposed L1 relocation + rename       |
|-------------------------------------|----------------------------------------|
| `swift-html-rendering`              | `swift-render-html-primitives`         |
| `swift-pdf-rendering`                | `swift-render-pdf-primitives`          |
| `swift-svg-rendering`                | `swift-render-svg-primitives`          |
| `swift-markdown-html-rendering`      | `swift-render-markdown-html-primitives`|
| `swift-css-html-rendering`           | `swift-render-css-html-primitives`     |
| `swift-pdf-html-rendering`           | `swift-render-pdf-html-primitives`     |
| `swift-user-interface-rendering`     | (keep at L3; the namespace is `User Interface`, not `Rendering`) |

Layer 3 foundations with other gerund-form names:

| Package                  | Gerund                                      |
|--------------------------|---------------------------------------------|
| `swift-http-routing`      | routing → router (noun) or route (noun)    |
| `swift-testing`           | testing → test (noun) — **SPECIAL CASE** — external compat with Apple's `swift-testing` |
| `swift-tracing`           | tracing → trace (noun) — **SPECIAL CASE** — external compat with `swift-distributed-tracing` |
| `swift-translating`       | translating → translation (noun)            |

### Proposed convention

1. **Package and namespace take the noun form.** Prefer the shortest noun
   that names the domain. `Render`, not `Rendering`. `Format`, not
   `Formatting`. `Order`, not `Ordering`. `Position`, not `Positioning`.

2. **The gerund names the canonical capability protocol**, exposed as
   `Namespace.\`Protocol\``, with a grammatical typealias:

   ```swift
   public enum Render {}

   extension Render {
       public protocol \`Protocol\`<...>: ~Copyable { ... }
   }

   public typealias Rendering = Render.\`Protocol\`

   // Usage
   struct MyView: Rendering { ... }         // reads as English
   struct MyView: Render.\`Protocol\` { ... } // equivalent; preferred in code
   ```

   The typealias is exported alongside the namespace (top-level, not nested,
   so it reads naturally as `Rendering` not `Render.Rendering`).

3. **Multiple protocols per namespace**: `\`Protocol\`` names the
   *canonical* / *central* capability. Other protocols in the namespace
   use their own role names (`Render.View`, `Parser.Taking`,
   `Array.Mutable`). Only the canonical protocol is aliased to a gerund.

4. **External-compatibility packages may deviate** where the external
   name is already established (e.g. `swift-testing` is Apple's name;
   renaming would break compat). In those cases the external name is
   retained and the internal namespace still uses the noun form
   (`Test` enum, `Test.\`Protocol\``, `typealias Testing = Test.\`Protocol\``).

5. **Foundations cascade**: Layer 3 foundations that are primitive
   vocabularies (renderers, formatters, routers, …) relocate to Layer 1
   under the noun-convention names. Foundations that compose multiple
   concerns (like `swift-user-interface`, whose namespace is the compound
   noun `User Interface`) stay at L3 with a noun-form name.

### Prior art survey

**Swift Evolution and Apple guidelines.** The [Swift API Design
Guidelines](https://swift.org/documentation/api-design-guidelines/) direct:
*"Those without side-effects should read as noun phrases … Those with
side-effects should read as imperative verb phrases."* This is a
method-naming rule, not a package rule, but it establishes that Apple's
naming aesthetic ties gerund/verb forms to *behavior*, not *domain*. Domain
names (modules, types) in Apple frameworks are consistently nouns:
`Foundation`, `UIKit`, `AppKit`, `SwiftUI`, `Combine`, `Network`,
`CoreGraphics`, `CoreData`, `MapKit`. No Apple framework uses a gerund as
its module name.

**Swift standard library.** Modules: `Swift`, `Foundation`. Types:
`Sequence`, `Collection`, `Array`, `Dictionary`, `String`, `Int`, `Bool` —
all nouns. Protocols: `Sequence`, `Collection`, `Equatable`, `Hashable`,
`Comparable`, `Sendable`, `Encodable`, `Decodable` — either nouns or
`-able` adjectives. The protocol-naming pattern in the Swift stdlib uses
**adjectival** forms (`-able` / `-ible`) rather than gerunds, but the
semantic intent is the same: "a type that IS ...". Our `Rendering =
Render.\`Protocol\`` treats the gerund grammatically the same way:
`struct MyView: Rendering` reads as "MyView is rendering [capable]".

**Rust stdlib and community.** Crate names: `std`, `core`, `alloc`,
`serde`, `tokio`, `hyper`, `rayon`, `futures` — predominantly nouns.
Some gerund/adjectival exceptions exist (`futures`, `pinning`) but the
bias is toward nouns. Trait naming commonly uses agent nouns
(`Iterator`, `Read`, `Write`) or `-able`/`-ing` forms
(`IntoIterator`, `AsRef`).

**Haskell standard libraries.** Hackage packages: `base`, `containers`,
`bytestring`, `text`, `mtl`, `lens` — all nouns. Modules inside: `Data.List`,
`Data.Map`, `Data.Set`, `Data.Text` — nouns. Type classes use agent-noun
(`Functor`, `Monad`, `Traversable`) or adjectival forms. No gerund
packages.

**Go standard library.** Packages: `fmt`, `io`, `os`, `net`, `sort`
(note: noun/verb-root, not `sorting`), `context`, `encoding`, `time`,
`sync`, `runtime`. Strong bias toward short nouns or verb-roots; no
gerund packages.

**Contextualization** (per [RES-021]): every surveyed language ecosystem
— Swift, Rust, Haskell, Go — uses nouns (or occasionally adjectival
`-able`) for package and module names. None uses gerunds as the primary
form. The Swift Institute's current drift toward gerund names for some
primitives (Rendering, Positioning, Formatting, Ordering) is **out of
step with every adjacent ecosystem**. Adopting the proposed noun/gerund
duality brings us back into line.

The concretization of the gerund-as-protocol rule in our type system:

- `protocol \`Protocol\` <...>` inside a namespace enum is already a
  working pattern (Parser, Array, Algebra.*, Affine.Discrete.Vector).
- `typealias Rendering = Render.\`Protocol\`` is the extension: the
  gerund-reading of a capability is a first-class English surface on top
  of a noun-form type system. It costs nothing (just a typealias), adds
  a natural reading, and scales to every namespace identically.
- No loss of expressiveness: generic constraints
  (`where T: Render.\`Protocol\``) and grammar-oriented sites
  (`struct MyView: Rendering`) both work.

### Alternative conventions considered

**Option A — retain status quo** (mixed noun/gerund, no rule).
- Pros: zero migration cost.
- Cons: newcomers cannot predict whether a new primitive should be
  `swift-foo-primitives` or `swift-foo-ing-primitives`; the decision is
  ad hoc per primitive; drift continues. Inconsistency compounds when
  L3 foundations mirror primitive naming (six renderer foundations all
  use the `-rendering` suffix, inheriting the gerund drift).

**Option B — gerund everywhere** (rename noun-form primitives to
gerund).
- Pros: uniform within the Institute.
- Cons: out of step with every surveyed language ecosystem; breaks the
  existing `Namespace.\`Protocol\`` pattern (which assumes the namespace
  is a domain noun, not a process gerund); forces unnatural names like
  `Graphing`, `Buffering`, `Machining`, `Layouting` (all either
  unidiomatic or wrong-meaning). Rejected.

**Option C — noun everywhere; gerund reserved for protocol typealias**
(proposed).
- Pros: aligns with Apple / Rust / Haskell / Go practice; reuses the
  already-established `Namespace.\`Protocol\`` pattern with a
  grammatical enhancement; gerund stays useful as an English-reading
  of conformance; migration cost is bounded and one-time.
- Cons: migration cost is non-trivial (four primitive packages plus six
  L3 foundations plus every downstream consumer).

**Option D — noun everywhere; no gerund typealias at all**.
- Pros: simpler rule.
- Cons: loses the English-reading convenience (`struct MyView:
  Rendering`). The typealias is cheap; keeping it is strictly additive.

### Special cases

Cases where the noun rule may yield to external concerns:

| Package            | Reason                                                  | Resolution                                  |
|--------------------|----------------------------------------------------------|---------------------------------------------|
| `swift-testing`     | Apple's `swift-testing` is the canonical name            | Keep the external name; internal namespace `Test` with `typealias Testing = Test.\`Protocol\`` |
| `swift-tracing`     | `swift-distributed-tracing` convention                   | Keep; internal namespace `Trace`             |
| `swift-http-routing`| Popular `*-routing` naming in HTTP frameworks            | Rename to `swift-http-router-primitives` or `swift-http-route-primitives` (external-compat not binding). Defer to HTTP-package author |

In general: the rule applies unless an external-compat constraint binds.
External-compat must be *named* (a specific package we must interop with)
not *aesthetic*.

### Affected packages (full mapping)

**Primitives (Layer 1) — rename required**:

| Current                          | Rename to                        | Namespace migration        |
|----------------------------------|----------------------------------|----------------------------|
| `swift-formatting-primitives`    | `swift-format-primitives`        | `Formatting` → `Format`     |
| `swift-ordering-primitives`       | `swift-order-primitives`         | `Ordering` → `Order`         |
| `swift-positioning-primitives`    | `swift-position-primitives`      | `Positioning` → `Position`   |
| `swift-rendering-primitives`      | `swift-render-primitives`        | `Rendering` → `Render`       |

**Primitives (Layer 1) — new (already proposed in UI research)**:

| New package                          | Namespace            |
|--------------------------------------|----------------------|
| `swift-render-markup-primitives`      | `Render.Markup`       |
| `swift-render-image-primitives`       | `Render.Image`        |

**Foundations (Layer 3) — rename outcomes** (2026-04-21 execution):

Foundation-independence audit per `[PKG-NAME-004]` disqualified all six
renderers from L1 relocation — each has either L2 standards deps, L3
deps, or Foundation source imports. They all stayed at L3 with noun
renames:

| Current                             | Renamed to (L3 in place)         | L1 blocker                                         |
|-------------------------------------|-----------------------------------|-----------------------------------------------------|
| `swift-html-rendering`               | `swift-html-render`               | L2 deps (html-standard, w3c-css, iso-9899)           |
| `swift-pdf-rendering`                | `swift-pdf-render`                | L2 dep (pdf-standard) + L3 (copy-on-write)           |
| `swift-svg-rendering`                | `swift-svg-render`                | L2 dep (svg-standard)                                |
| `swift-markdown-html-rendering`      | `swift-markdown-html-render`      | Foundation source import + L3 deps                   |
| `swift-css-html-rendering`           | `swift-css-html-render`           | L3 dep (html-render)                                 |
| `swift-pdf-html-rendering`           | `swift-pdf-html-render`           | L3 deps (html-render, pdf-render)                    |

Each rename is strictly at the package identity layer: package `name:`
field and consumer `.package(path:)` / `package:` refs. Module /
product / target names (`HTML Rendering`, `PDF Rendering`, etc.) and
source directories are preserved. The namespace-level rename at L1
(`Rendering` → `Render`) propagates transparently.

**Foundations (Layer 3) — stub rename**:

| Current                             | Rename to                       |
|-------------------------------------|----------------------------------|
| `swift-user-interface-rendering`     | keep name as-is at L3 — `User Interface` namespace is unaffected; `-rendering` here is a descriptive suffix, not the primary namespace. Alternatively `swift-user-interface-render` for consistency. |

This research recommends `swift-user-interface-render` (noun form) for
internal consistency, but flags it as the least-important rename since
the stub has no content yet.

### Migration sequencing

When execution is authorized, the sequence is:

1. **Ratify the convention.** Promote this research to a skill
   (`swift-package` or extension of `code-surface`) with requirement IDs.
2. **Rename primitives first** (L1 has the fewest downstream consumers
   per package).
3. **Rename foundations second.** For foundations relocating to L1,
   verify Foundation-independence before the move; otherwise rename in
   place at L3.
4. **Update consumers in one sweep per rename.** Use grep + scripted
   substitution for target names; manual review for namespace refs.
5. **Record each rename in a migration log** so downstream users can
   track the breaking changes.

## Outcome

**Status**: EXECUTED 2026-04-21.

**Migration log** (per sub-repo, chronological):

- L1 primitives: `swift-rendering-primitives` → `swift-render-primitives`
  (`ddb69f2`); `swift-positioning-primitives` → `swift-position-primitives`
  (`c87ad22`); `swift-ordering-primitives` → `swift-order-primitives`
  (`1292f1c`); `swift-formatting-primitives` → `swift-format-primitives`
  (`d1ec621`).
- L1 umbrella (swift-primitives): `bd05065` (render), `ef2bf08` (position),
  `8d9b902` (order), `a0d8366` (format). `.gitmodules` section names and
  `Package.swift` regenerated; remote URLs unchanged (GitHub redirects).
- L3 renderers (6 renames at L3, no relocation): `3cb1621`
  (swift-html-render), `f988b430` (pdf), `d0557ee` (svg), `985e5ed`
  (css-html), `18bbc6a` (markdown-html), `ef8737d` (pdf-html).
- L3 umbrella (swift-foundations): `89bbefe` (renderer submodule renames
  + sibling foundation pointer bumps).
- L3 stub: `1d0afa2` + `2283084` (swift-user-interface-rendering →
  swift-user-interface-render).

**Decision** (ratified in swift-package skill):

1. **Noun rule**: packages and namespaces take the noun form. The shortest
   natural noun wins. Gerund forms are forbidden for packages and
   namespaces.
2. **Protocol rule**: the canonical capability protocol of a namespace is
   declared as `Namespace.\`Protocol\`` (backtick-escaped). A top-level
   gerund typealias (`typealias Rendering = Render.\`Protocol\``) is
   exported so conformance sites can read as English.
3. **Special-case clause**: external-compat with a named external package
   may override the noun rule. The internal namespace still follows the
   rule.
4. **Foundations cascade**: L3 foundations that are purely primitive
   vocabularies (renderers, formatters, routers) relocate to L1 under
   the noun-convention names. L3 foundations that compose multiple
   concerns stay at L3 with a noun-form name.

### Promotion to skill

The convention should be captured as a new **`swift-package`** skill,
sibling to `primitives` and `code-surface`, with requirement IDs. The
skill documents:

- `[PKG-NAME-001]` — noun rule
- `[PKG-NAME-002]` — `\`Protocol\`` + gerund-typealias pattern
- `[PKG-NAME-003]` — external-compat exception
- `[PKG-NAME-004]` — foundations cascade (L3 → L1 under this rule)
- `[PKG-NAME-005]` — shortest-noun guideline (tie-breaking)
- `[PKG-NAME-006]` — hoisted-protocol pattern for generic namespaces (already in use by `swift-array-primitives`; documented so future generic-type namespaces reach for it consistently)

Any future package proposal must cite compliance with these requirements.

### Next actions

1. Write `swift-institute/Skills/swift-package/SKILL.md` encoding the
   above as requirement IDs. This research doc remains the authoritative
   analysis; the skill is the normative rule.
2. Update `code-surface` skill's `last_reviewed` if the new skill
   absorbs any of its naming content.
3. Do **not** rename any existing packages yet. Execution sequencing is
   a separate authorization.

## References

- `swift-foundations/Research/swift-user-interface-package-decomposition.md` — trigger
- `swift-foundations/Research/danceui-architectural-analysis.md` — upstream context
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- `/Users/coen/Developer/swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift` — Parser.\`Protocol\` pattern
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Primitives Core/Array.Protocol.swift` — hoisted-protocol variant
- `/Users/coen/Developer/swift-primitives/swift-algebra-group-primitives/Sources/Algebra Group Primitives/` — Algebra.Group.\`Protocol\`
- `/Users/coen/Developer/swift-institute/Skills/code-surface/SKILL.md` — existing naming conventions (Nest.Name, compound-identifier prohibition)
- `/Users/coen/Developer/swift-institute/Skills/primitives/SKILL.md` — primitives-specific conventions
