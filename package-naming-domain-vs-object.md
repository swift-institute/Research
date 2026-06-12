# Package Naming: Domain Nouns vs Object Nouns

<!--
---
version: 1.0.0
last_updated: 2026-06-12
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
builds_on:
  - "operation-domain-naming-and-organization.md (Tier 3, DECISION 2026-05-26) — the definitive operation-domain convention; this doc AFFIRMS it and extends it with an explicit package-mirror rule"
  - "transformation-domain-architecture.md (DECISION v3.4.0, 2026-05-13) — prescribes the agent-noun package set (parser/serializer/coder/formatter)"
  - ".handoffs/HANDOFF-package-naming-direction.md — the commissioning brief (fresh take, licensed to disagree)"
  - ".handoffs/HANDOFF-se0516-iteration-rename.md — the suspended Part-B rename + W0 census"
changelog:
  - "1.0.0 (2026-06-12): Initial. Fresh first-principles take on the 2026-06-12 domain-over-object package-naming direction; recommends uniform namespace-mirror naming; disposes the suspended iterator→iteration rename as CANCEL; drafts [PKG-NAME-017]."
---
-->

> **Commission.** Principal direction 2026-06-12 (late): before the suspended
> `swift-iterator-primitives` → `swift-iteration-primitives` rename executes, a fresh
> research session reviews the prior art and gives an independent take — explicitly
> licensed to agree or disagree with the original direction, the principal's examples,
> and the seat's interim two-test frame alike. This document is that take. It converges
> on ONE recommendation per the brief; the principal ratifies.

---

## 0. TL;DR

**Recommendation: keep object/namespace-mirrored package naming uniformly. Cancel the
iterator→iteration rename. No rename class exists.** The package level has no naming
vocabulary of its own: an L1/L2 package's name is the kebab-cased form of the surface it
ships — the namespace path (`swift-buffer-linear-primitives` ⇄ `Buffer.Linear`,
`swift-iterator-primitives` ⇄ `Iterator`), the recipient+provider pair for bridges, or
the family label for sibling-set packages. Domain/activity vocabulary (*iteration*,
*serialization*, *parsing*, *file-system*) is the **aggregation register**: it belongs to
L3+ units whose granularity matches a field — where the catalog already uses it
(`swift-file-system`, `swift-arguments`, `swift-executors`) and where Apple uses it
(`Observation`, `Synchronization`, `Testing`).

The principal's instinct that `swift-serialization-primitives` "sounds right" is the
sound of a *field-sized* name; the instinct that `swift-execution-primitives` is
"entirely wrong" is the same rule firing in reverse — the executor package is not
field-sized and (verified below) not even seam-shaped. Both instincts are correct, and
both are satisfied by keeping field names at the layer whose units are fields.

---

## 1. Context

**Trigger** ([RES-001] — naming ambiguity, precedent-setting). On 2026-06-12 the
principal directed a rename `swift-iterator-primitives` → `swift-iteration-primitives`
under a new principle: *"the package name emphasizes the DOMAIN (iteration), not the
object (iterator)"* — packages name domains; targets/modules/types keep object names.
The lane (lane-se0516-iteration Part B) ran its W0 census (seat-verified: 30 org
manifests = 27 live + 3 comment-only; zero docs/skills route on the package name;
package-name-only; mirror + redirect mechanics proven — *carried forward, seat-verified
2026-06-12*) and was blessed for W1. Later the same day the principal questioned the
direction with a counterexample — `swift-serialization-primitives` sounds right, but
`swift-execution-primitives` would be "entirely wrong" for the executor package — and
suspended the rename pending this fresh take.

**Why this is Tier 3**: the answer generalizes (or refuses to generalize) across every
operation-domain package at L1/L2, sets the naming register for all future packages, and
renames are expensive to undo post-publication. It amends-or-affirms a 17-day-old Tier-3
DECISION.

**Constraint**: research only. No package edits, no renames, no skill edits; the
[PKG-NAME] amendment below is a draft for ratification via skill-lifecycle.

---

## 2. Question

Should institute package names be **domain-named** (`swift-serialization-primitives`,
`swift-iteration-primitives`) or **object-named** (`swift-serializer-primitives`,
`swift-iterator-primitives`) — and by what rule? Does the answer generalize
ecosystem-wide, partially, or not at all?

Sharpened: for value domains the two coincide (`Buffer`, `Time`, `Observation` name both
the artifact and the field), so nothing is decidable there. The question only *exists*
for operation domains, where English splits the doer from the doing. It is therefore
precisely: **may a package's noun diverge from the noun of the surface it ships?**

---

## 3. Prior art reviewed ([RES-019] internal-first)

| Source | Status | Position on the question |
|---|---|---|
| `operation-domain-naming-and-organization.md` | Tier 3 **DECISION** 2026-05-26 | §3: package + namespace take the agent noun for machines; *"`Iteration` is not the iterator namespace"*; deverbal noun reserved for the witness alias (§5.2). Corpus survey ratified the live agent-noun package set. |
| `swift-package` skill [PKG-NAME-001] (+2026-05-26 clarification) | canonical | Noun form; machines → agent noun; gerunds forbidden at package/namespace level. |
| [PKG-NAME-015] | canonical | `typealias Iteration = Iterator.Witness`, `typealias Serialization = Serializer.Witness` — the deverbal result-nouns are **assigned to the witness role**. |
| [PKG-NAME-016] | canonical | "the package noun mirrors the namespace its surface occupies, owner-first" — the mirror invariant, stated in passing. |
| `transformation-domain-architecture.md` | DECISION v3.4.0 2026-05-13 | Prescribes `swift-parser-primitives` / `swift-serializer-primitives` / `swift-coder-primitives` / `swift-formatter-primitives` — agent-noun packages. |
| `package-namespace-noun-convention.md` | SUPERSEDED | The gerund→noun history; executed as the 2026-04-21 `Rendering`→`Render` cascade. |
| `domain-first-repository-organization.md` + `-prior-art.md` | RECOMMENDATION/DEFERRED 2026-02-23 | Different axis (org-level organization, `swift-` prefix). Registry survey notes Rust crates favor concept names (`uuid`, `http`) at *crate* granularity. |
| `ascii-parsing-domain-ownership.md` | SUPERSEDED (absorbed) | Subject-first exemplar: `swift-ascii-parser-primitives` = subject domain (ASCII) first, capability (Parser) second — [API-NAME-001b]. Not a domain-over-object precedent: both tokens mirror the shipped `ASCII.*.Parser` paths. |
| `stdlib-naming-beats-ecosystem-naming.md` | IN_PROGRESS | Different axis (shadowed member names). |
| Seat's interim two-test frame (HANDOFF-package-naming-direction.md) | input, not a ruling | SUBJECT test (concern → domain noun; artifact catalog → object noun) + LANGUAGE test (clean English noun). Inventory: ~12 strong, 4 census-needed, several withdrawn. |

Net: the *entire* normative corpus — two DECISION docs and three canonical rules, the
newest 17 days old — assigns the agent noun to the package level and the deverbal noun to
the witness alias. The 2026-06-12 direction proposes to override this. The override gets
a full first-principles hearing below; the prior corpus is an input, not a veto.

---

## 4. The name system as found (empirical ground, all `[Verified: 2026-06-12]`)

### 4.1 The mirror is the catalog's operating invariant

A census across the ~221 `swift-*-primitives` packages (file stems under `Sources/`,
one-type-per-file convention; spot-verified declarations) shows the package name is the
kebab-cased form of the shipped surface in the overwhelming majority of the catalog —
`swift-parser-primitives` ships 64 `Parser.*` files, `swift-iterator-primitives` ships
`Iterator.*`, `swift-tree-keyed-primitives` ships `Tree.Keyed.*`, `swift-cpu-primitives`
ships `CPU.*`, and so on across every tier. The exceptions are few and classifiable:

| Class | Instances found | Character |
|---|---|---|
| Vocabulary mismatch | `swift-linter-primitives` ships `Lint` (`Lint.swift:36`) | the one true divergence: agent-noun package over a shorter-noun namespace |
| Sibling-family packages | `swift-dimension-primitives` (Axis, Interval, Winding), `swift-symmetry-primitives` (Rotation, Symmetry, Shear), `swift-package-primitives` (Package, Target, Product), `swift-structured-queries-primitives` (CTE, WindowSpec, Where) | no single namespace dominates; the name is the family label |
| Integration bridges | `swift-empty-iterator-primitives`, `swift-single-iterator-primitives`, `swift-memory-iterator-primitives`, `swift-memory-sequence-primitives` — sources are exclusively `+conformance` files | name = recipient ⊗ provider tokens (see §4.3) |
| Compressed bridge path | `swift-cyclic-iterator-primitives` ships `Cyclic.Group.Static.Iterator` (`Cyclic.Group.Static.Iterator.swift:31`) | endpoints kept, middle path dropped |

Two properties this buys, used daily: **derivability** (know the type → know the
dependency; know the package → know the surface — load-bearing for the workspace's own
package-resolution tables and for every agent session navigating 221 cells) and **stem
identity** (`.package(url: …/swift-iterator-primitives)` + `.product(name: "Iterator
Primitives", package: "swift-iterator-primitives")` + `import Iterator_Primitives` share
one stem; manifests pair these strings line-adjacent).

### 4.2 The four grammatical forms already have one role each

In `swift-iterator-primitives`, all four forms exist with assigned roles:

| Form | Declaration | Role |
|---|---|---|
| agent noun | `enum Iterator` — `Iterator.swift:35` | namespace; hosts the protocol, witness, and combinators (7 nested public types; ~64% of the package's public surface) |
| gerund | `typealias Iterating = Iterator.Protocol` — `Iterating.swift:22` | active-capability reading |
| `-able` | `protocol Iterable` — `Iterable.swift:35` | passive attachment |
| deverbal result-noun | `typealias Iteration = Iterator.Witness` — `Iteration.swift:18` | the type-erased witness value |

A workspace-wide grep confirms `Iteration` is today the **only** result-noun witness
alias in existence (`typealias Serialization|Parsing|Rendering|Coding`: zero hits) —
i.e., the exact word the rename would put on the package is already a *type* the package
exports, in the role [PKG-NAME-015] gave it.

### 4.3 The operation token is also the bridge vocabulary

The iterator "variants" are not variants — they are **bridges** that confer the
capability on another domain's recipient, and their *only* iterator-vocabulary content is
the reference to the core seam:

- `swift-empty-iterator-primitives`: ships solely `extension Empty: @retroactive Iterator.Protocol` (`Empty+Iterator.Protocol.swift:20`) — `Empty` is deliberately cross-domain, not `Iterator.Empty`.
- `swift-single-iterator-primitives`: solely `extension Single: @retroactive Iterable` (`Single+Iterable.swift:19`).
- `swift-memory-iterator-primitives`: solely `extension Memory.Contiguous: @retroactive Iterable` (`Memory.Contiguous+Iterable.swift:54`).
- `swift-cyclic-iterator-primitives`: one concrete `Cyclic.Group.Static.Iterator` (`…Iterator.swift:31`) conforming to the core seam.

In these names the `-iterator` token names the **capability domain via its agent noun**,
exactly as `-parser` does in `swift-byte-parser-primitives` (ships `Byte.Parser`,
`Byte.Literal.Parser` conforming to `Parser.Protocol` — `Byte.Parser.swift:27`). The
seam itself is `Iterator.Protocol` and stays so under everyone's proposal (types are
agreed to keep object names — the Tier-3 doc's *Cursor proof* stands: the agent noun is
the only universally available machine form).

### 4.4 The layers already stratify the registers

L3 foundations *already* name by field, decoupled from namespaces:
`swift-file-system` ships `File.*` (`File.Directory.Create.swift`, …);
`swift-arguments` ships `Command.*` (`Command.swift`, `Command.Help.swift`, …);
`swift-executors` is a plural catalog (`Executor.Cooperative.swift`,
`Kernel.Thread.Executor.Polling.*`); `swift-clocks` is a plural re-export umbrella.
Field vocabulary at the aggregation layer is the catalog's *existing practice*, not a
proposal.

And L1 *already* contains deverbal `-ation` packages — where the `-ation` word **is** the
namespace: `swift-observation-primitives` ships `Observation` (10 files) + `Observable`;
`swift-initialization-primitives` ships `Initialization` + `Initiable` + `Initializing`.
The system is not anti-domain-noun; it is pro-mirror. Domain nouns appear at L1 exactly
when the domain noun is the type vocabulary (relation-class domains per
[PKG-NAME-001]).

### 4.5 The principal's two examples, verified at source

**Executor** — `swift-executor-primitives` declares **no** `Executor` protocol, no
witness, no `-able`; `Executor` is a declaration-only namespace root (`Executor.swift:13`)
over concrete scheduling artifacts: `Executor.Job` + `Job.Queue` / `Job.Deque` /
`Job.Priority`, `Executor.Wait`, `Executor.Shutdown(.Flag)`. Nothing in the package
models execution-as-activity. The principal's "entirely wrong" verifies: *execution*
would misname a box of executor-infrastructure artifacts.

**Serializer** — `swift-serializer-primitives` ships the full capability family:
`Serializer.Protocol` (`Serializer.Protocol.swift:34`), `Serializable`
(`Serializable.swift:19`), `Serializer.Witness` (`Serializer.Witness+Protocol.swift:13`),
`Serializer.Builder`, plus combinators (18 `Serializer.*` files). *Serialization* would
honestly describe it.

So the asymmetry the principal sensed is real — but it is an asymmetry of **package
content**, not of the naming system. And content is a spectrum, not a bit:
`swift-parser-primitives` is seam **and** 64-file combinator algebra;
`swift-lexer-primitives` is half concrete artifacts (`Lexer.Lexeme`, `Lexer.Scanner`),
half protocol suite (`Lexer.Pull.Tokens`, `Lexer.Pull.Assemble.Strategy`);
`swift-formatter-primitives` is a pure seam (`Formatter.Protocol.swift:55`,
`Formattable.swift:28`, witness `Format.swift:48`); `swift-builder-primitives` is a pure
grammar (`Builder.swift:103`, `Buildable.swift:82`); `swift-loader-primitives` is pure
catalog (dlopen/dlsym surface); `swift-machine-primitives` is 45 files of
defunctionalized-parsing machinery with no concrete parsers;
`swift-cursor-primitives` is one concrete type (`Cursor.swift:72`);
`swift-driver-primitives` is an empty stub. Any rule keyed on this axis needs a source
census per package to apply — the seat's own "4 census-needed" line item is the proof.

---

## 5. Analysis

### Option A — uniform mirror (the current system, made explicit)

The package name is the kebab form of what the package ships; no second vocabulary at the
package level; field names reserved for L3+ aggregates.

**Pros**: zero-gate, mechanical, lintable (name tokens ⊆ shipped stem vocabulary —
greppable, unlike the gerund/noun boundary that blocked [PKG-NAME-001]'s mechanization);
preserves derivability and stem identity across manifests/modules/types; produces zero
wrong outputs on the executor-class cases *by construction*; consistent with both
DECISION docs and the executed April cascade; bridge names stay coherent with the seam
they reference. **Cons**: core packages read as artifact-homes to readers arriving with
field-library expectations ("serializer primitives" vs "serialization primitives") — a
real but small register difference, and the `-primitives` suffix already marks the unit
as a vocabulary cell rather than a product.

### Option B — domain-named packages, ecosystem-wide (the 2026-06-12 direction)

Packages name the activity; modules/types keep object names.

**Pros**: core operation packages' names describe their full four-form surface;
matches the field-library register of `serde` and Apple's newest modules.
**Cons**: refuted by its own cleanest instance — the principal's executor
counterexample — so it cannot ship without a content gate (becoming Option C);
breaks stem identity (`Iterator_Primitives` module inside `swift-iteration-primitives`;
note every cited external precedent has *matched* stems: package `swift-testing` ⇄ module
`Testing` — `swift-testing/Package.swift:40,73`); names the package after its witness
alias rather than its namespace root (§4.2); for verb-only domains the activity noun is a
gerund (`parsing`, `coding`, `building`, `rendering`), re-importing the gerund register
the 2026-04-21 cascade removed — including reversing `render→rendering` seven weeks
after the ecosystem executed the opposite rename.

### Option C — gated rename class (the seat's two-test frame)

Concern-packages with a clean activity noun rename; artifact catalogs keep object names.

**Pros**: formalizes the real content asymmetry of §4.5; semantically defensible
case-by-case. **Cons**: the gate requires a per-package source census (lexer MIXED,
formatter pure-seam, parser both — the line cuts *within* packages); the language gate is
a judgment call of exactly the kind [PKG-NAME-001] was written to abolish; and the output
is a **two-name domain**: after iterator→iteration, the word *iterator* persists in the
namespace, the module names, the seam every consumer constrains against, and every bridge
package name (`swift-empty-iterator-primitives`, …), while *iteration* appears in the
core package name and a witness alias. The rename does not move the package onto the
domain's name; it moves it **off the family's name**. Multiplied across domains
(`parsing` + `byte-parser` bridges, `serialization` + `coder` sibling, formatter
undecidable) the catalog becomes patchwork precisely where it is today systematic.

### Comparison

| Criterion | A: uniform mirror | B: domain everywhere | C: gated class |
|---|---|---|---|
| Mechanical (no judgment per package) | ✓ | ✓ (but wrong outputs) | ✗ (source census + English ruling) |
| Survives the executor case | ✓ | ✗ (principal's own counterexample) | ✓ (by gating) |
| Stem identity package/module/types | ✓ | ✗ | ✗ for the renamed class |
| Family coherence (core + bridges + seam share vocabulary) | ✓ | ✗ | ✗ |
| Role-uniqueness of the four forms ([PKG-NAME-015]) | ✓ | ✗ (result-noun gets two roles) | ✗ |
| Gerund register stays retired at package level | ✓ | ✗ | ✗ (parsing/rendering/sequencing) |
| Reads as field-library to external browsers | partially (via L3) | ✓ | mixed |
| Churn vs 2026-05-26 DECISION + 2026-04-21 cascade | none | high | medium, open-ended |
| Lint-enforceable ([BET-HOOK]/P3 program) | ✓ | ✓ | ✗ |

### Contextualization of the external precedent ([RES-021])

The strongest evidence *for* domain naming is real and verified: Apple's newest
distribution units are activity-named — `Observation` ships `@Observable` +
`ObservationRegistrar` (`stdlib/public/Observation/Sources/Observation/Observable.swift:45`,
`ObservationRegistrar.swift:17`), `Synchronization` ships `Mutex` + `Atomic`
(`stdlib/public/Synchronization/Mutex/Mutex.swift`, `Atomics/Atomic.swift:20`),
alongside `Distributed`, `StringProcessing`, `Concurrency`; `swift-testing` pairs a
gerund package with a gerund module; Rust's `serde` is the serializer case exactly
(domain-contraction crate, agent-noun `Serializer`/`Deserializer` traits). But adoption
elsewhere is not necessity here: every one of those units is **field-sized** — one module
*is* the whole field, and its name has no sibling cells, no bridge names, and no
namespace-mirror invariant to break (and stems match wherever both exist). The
institute's iteration field is a six-package lattice neighborhood (core + four bridges +
sequence sibling); its serialization field spans serializer + coder + the
binary/ascii/byte spine. Field names attach to field-sized units. The institute's
field-sized units are its L3 aggregates — which is where the catalog already puts field
names (§4.4).

---

## 6. Outcome

**Status: RECOMMENDATION** (principal ratifies; on ratification this and the [PKG-NAME]
amendment go DECISION via skill-lifecycle).

**Adopt Option A — one invariant, stated as [PKG-NAME-017] (draft in §9):** the package
name mirrors the shipped surface at L1/L2; the package level introduces no independent
vocabulary; field/activity names are the L3+ aggregation register. Consequences:

1. `swift-iterator-primitives`, `swift-serializer-primitives`, `swift-parser-primitives`,
   `swift-coder-primitives`, `swift-formatter-primitives`, `swift-render-primitives` and
   the whole spine keep their names. The April gerund cascade stands.
2. The deverbal nouns keep their single [PKG-NAME-015] role (`Iteration` =
   `Iterator.Witness`; `Serialization` reserved for `Serializer.Witness`).
3. The principal's field-name instinct is honored at the right granularity: a future
   L3 `swift-serialization` (umbrella over the serializer/coder spine) or `swift-iteration`
   would be *correctly* named — same register as `swift-file-system` and Apple's
   `Observation`/`Synchronization`.

### Where this disagrees with the 2026-06-12 direction — plainly

The direction "packages name domains, types name objects" is rejected **as an L1/L2
rule**, for four verified reasons: (a) its own cleanest instance refutes it (the executor
package, §4.5) — so it can only ship with a per-package content gate, which makes naming
non-mechanical; (b) it assigns the deverbal noun a second role the convention already
spent on the witness alias (§4.2); (c) it splits one domain into two package-level
vocabularies, because bridges and modules necessarily keep the agent noun (§4.3, §5C);
(d) the register it reaches for is an aggregation-unit register, already correctly in use
at L3 (§4.4, [RES-021] contextualization). The instinct behind the direction is sound —
it is a granularity observation, not a cell-naming rule.

The seat's two-test frame is acknowledged as the best formalization the direction admits
— its SUBJECT test tracks a real content axis — but it fails as a naming rule on
census-cost, on the two-name-domain outcome, and on re-importing package-level gerunds.

---

## 7. Disposition of the suspended rename

**lane-se0516-iteration Part B: CANCEL.** Not retarget: there is no variant of the
rename consistent with this recommendation. Specifics:

- The W0 census (30 manifests; mirror mechanics; dual-entry rulings) stays **banked** as
  a consumer-map artifact of `swift-iterator-primitives`; nothing about it is invalidated
  — it simply has no W1 to feed. The seat's W1 sweep, riders (tree-keyed local-only,
  buffer-ring deferral), and the ζ/γ re-sequencing item "rename runs after γ" all
  dissolve with the cancellation.
- Part A (SE-0516 review feedback) closed independently (pass, banked) — unaffected.
- The "at-birth `swift-sequencing-primitives`" idea for a future Sequenceable sibling is
  rejected with the class: any future split out of `swift-sequence-primitives`
  (which today ships `struct Sequence` — `Sequence.swift:98`, `Sequenceable` —
  `Sequenceable.swift:90`, `Sequence.Iterator` — `Sequence.Iterator.swift:36`) is named
  by mirror at birth.

## 8. Candidate list under the recommendation

**No rename class survives.** For the record, the would-have-been candidates with their
source-verified classifications — all dispositions KEEP:

| Package | Shipped surface (verified) | Content character | Disposition |
|---|---|---|---|
| swift-parser-primitives | `Parser` nest: Protocol:90, Witness, Builder + 64 files; `Parseable`:26 | seam + combinator algebra | KEEP |
| swift-serializer-primitives | `Serializer` nest: Protocol:34, Witness, Builder; `Serializable`:19 | seam + combinators | KEEP |
| swift-coder-primitives | `Coder.Protocol`:48 refining Parser+Serializer; `Codable`:29; leaf | unifying seam | KEEP |
| swift-formatter-primitives | `Formatter.Protocol`:55; `Formattable`:28; top-level `Format` witness:48 (pre-015 shape) | pure seam | KEEP |
| swift-iterator-primitives | four forms (§4.2); 7 nested types, ~64% under `Iterator` | seam + witness + chunk tier | KEEP |
| swift-render-primitives | `Render.View`:7, Context, Builder, Machine — 27 files | concern (relation-class; `Render` already the [PKG-NAME-005] noun) | KEEP |
| swift-lexer-primitives | `Lexer` nest: Lexeme:38, Scanner, Pull.Tokens/Assemble.Strategy protocols | mixed | KEEP |
| swift-builder-primitives | `Builder`:103 result-builder grammar; `Buildable`:82 | concern; *building* fails language anyway | KEEP |
| swift-machine-primitives | `Machine` nest, 45 files of program/frame/capture machinery | concern; no activity noun exists | KEEP |
| swift-executor-primitives | `Executor` namespace:13 over Job/Queue/Deque/Priority/Wait/Shutdown; **no protocol** | catalog — the refuting instance | KEEP |
| swift-loader-primitives | `Loader.Library`/`Symbol`/`Section` dlopen-dlsym surface | catalog | KEEP |
| swift-linter-primitives | ships `Lint`:36 (Rule, Finding, Configuration) | concern; *pre-existing mirror mismatch, see Residual* | KEEP (name question is separate) |
| swift-cursor-primitives | one concrete `Cursor<DomainTag>`:72 | single artifact; no activity noun | KEEP |
| swift-driver-primitives | empty stub (0-byte source) | — | KEEP (nothing to name) |
| spine ×8 (ascii/binary/byte/leb128 parser/serializer/coder) | concrete conformers to the core seams (e.g. `Byte.Parser`:27 → `Parser.Protocol`) | catalogs/bridges | KEEP |
| iterator bridges ×4 + memory-sequence | `+conformance`-only bridges (§4.3) | bridges | KEEP |
| binary-cursor, memory-cursor | `Binary.*` / `Memory.*` stems (census) — subject-first homes | subject-first | KEEP |
| swift-sequence-primitives | `Sequence` + `Sequenceable` + `Sequence.Iterator` (§7) | deferred protocol-architecture axis | KEEP (out of scope here) |

## 9. Draft [PKG-NAME] amendment (delivery only — lands via skill-lifecycle after ratification)

> ### [PKG-NAME-017] Package Name Mirrors the Shipped Surface (No Package-Level Vocabulary)
>
> **Statement**: An L1/L2 package's name MUST be the layer-affixed kebab form of the
> surface it ships: (a) the top-level namespace path when one namespace dominates
> (`swift-buffer-linear-primitives` ⇄ `Buffer.Linear`); (b) the recipient+provider token
> pair for integration bridges per [PKG-NAME-016] (`swift-empty-iterator-primitives` ⇄
> `Empty: Iterator.Protocol`); (c) the family label when a sibling set ships together
> with no dominant root (`swift-dimension-primitives` ⇄ Axis/Interval/Winding); (d) the
> protocol name for pure-capability packages per [PKG-NAME-009]
> (`swift-carrier-primitives` ⇄ `Carrier`). The package level introduces NO independent
> vocabulary: in particular, deverbal activity nouns (*iteration*, *serialization*,
> *parsing*) MUST NOT name a machine-domain package — the agent-noun namespace names it
> ([PKG-NAME-001]), and the deverbal noun stays reserved for the witness alias
> ([PKG-NAME-015]). Field/activity vocabulary is the L3+ aggregation register
> (`swift-file-system`, `swift-executors`; a future `swift-serialization` umbrella).
>
> **Rationale**: 221-cell derivability (type ⇄ dependency without lookup tables); stem
> identity across `.package`/`.product`/`import`; role-uniqueness of the four
> grammatical forms; family coherence (core, bridges, modules, and the seam share one
> vocabulary); the executor test — a naming rule that needs a per-package content census
> to avoid wrong outputs loses to one with no gate. Domain-naming at L1 was evaluated
> and REJECTED 2026-06-12; provenance: `package-naming-domain-vs-object.md`.
>
> **Enforcement note**: mechanically checkable — package-name tokens ⊆ vocabulary of
> shipped file stems (one-type-per-file makes the surface greppable); candidate for the
> P3 lint program, unlike gerund-detection ([PKG-NAME-001]'s deferred mechanization).
>
> **Cross-references**: [PKG-NAME-001], [PKG-NAME-005], [PKG-NAME-009], [PKG-NAME-015],
> [PKG-NAME-016].

Plus one clarifying sentence appended to [PKG-NAME-001]'s "Which noun" block:

> The machine package takes the same agent noun as its namespace; the 2026-06-12
> domain-over-object proposal (`swift-iteration-primitives` for the `Iterator` package)
> was evaluated and rejected — see [PKG-NAME-017] and
> `Research/package-naming-domain-vs-object.md`.

## 10. Residual ([RES-027]: premises vs directions)

All items below are **directions** (no downstream design currently reasons from them);
none is a load-bearing unverified premise, so no verification spike is owed:

1. **`swift-linter-primitives` ⇄ `Lint`** — the catalog's one true vocabulary mismatch
   (§4.1). Under [PKG-NAME-017] the mirror name would be `swift-lint-primitives`
   ([PKG-NAME-005] shortest natural noun favors `Lint`). Micro-arc candidate for the
   principal to scope; deliberately NOT bundled into this ruling.
2. **L3 `swift-serialization` umbrella** — the legitimate home for the field-name
   register over the serializer/coder/spine neighborhood, if and when an L3 aggregate is
   wanted. Direction only.
3. **`swift-formatter-primitives` pre-015 witness shape** — top-level `Format<I,O,F>`
   (`Format.swift:48`) predates [PKG-NAME-015]'s `Formatter.Witness` rule; the Tier-3
   doc's §5.1 collision note applies. Migration is that convention's pending execution,
   not this doc's scope.
4. **Sibling-family naming (class (c) of [PKG-NAME-017])** — dimension/symmetry/package/
   structured-queries name a family, not a namespace; fine as-is, worth one line in the
   skill so future family packages don't re-derive.

## 11. References

- `operation-domain-naming-and-organization.md` (Tier 3, DECISION 2026-05-26)
- `transformation-domain-architecture.md` (DECISION v3.4.0)
- `swift-package` skill — [PKG-NAME-001/-005/-009/-015/-016]
- `.handoffs/HANDOFF-package-naming-direction.md`, `.handoffs/HANDOFF-se0516-iteration-rename.md`, seat census (2026-06-12)
- Local source verification 2026-06-12: `swift-primitives/*` file:line cites inline above
- Apple primary sources (local clone `~/Developer/swiftlang/swift`):
  `stdlib/public/{Observation,Synchronization,Distributed,StringProcessing}`;
  `Observation/Sources/Observation/Observable.swift:45`, `ObservationRegistrar.swift:17`;
  `Synchronization/Mutex/Mutex.swift`, `Atomics/Atomic.swift:20`;
  `~/Developer/swiftlang/swift-testing/Package.swift:40,73`
- Rust `serde` — https://serde.rs (crate name vs `Serializer`/`Deserializer` traits; well-known, not re-fetched this session)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
