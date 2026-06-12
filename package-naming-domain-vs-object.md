# Package Naming: Domain Nouns vs Object Nouns

<!--
---
version: 2.0.0
last_updated: 2026-06-12
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
builds_on:
  - "operation-domain-naming-and-organization.md (Tier 3, DECISION 2026-05-26) — the definitive operation-domain convention; this doc AFFIRMS it and extends it with an explicit per-layer register rule"
  - "transformation-domain-architecture.md (DECISION v3.4.0, 2026-05-13) — prescribes the agent-noun package set"
  - ".handoffs/HANDOFF-package-naming-direction.md — the commissioning brief (fresh take, licensed to disagree)"
  - ".handoffs/HANDOFF-se0516-iteration-rename.md — the suspended Part-B rename + W0 census"
changelog:
  - "2.0.0 (2026-06-12): Deep pass on principal direction (\"go deeper\"). ADDS: linguistic foundation (compound semantics — Levi 1978 FOR-relation, Downing 1977; nominal-kind theory — Grimshaw 1990 event/result ambiguity, Rappaport Hovav & Levin 1992 participant-denoting -er nominals, Baker & Vinokurova 2009); web-verified cross-ecosystem structural survey (Go, Python, Rust std::iter + serde, Java java.util.concurrent's Executor, Haskell, C++, Apple); per-layer register theory (L1 mirror / L2 authority / L3 field) FIXING a v1 defect ([PKG-NAME-017] had wrongly claimed L2); family-vacuum clause confronting dimension/symmetry/structured-queries head-on; diachronic-stability argument; the strongest construction of the domain proposal walked to its end state; quantitative surfaces (9,906 product/package pairing lines; clean per-candidate blast radius); Cognitive Dimensions pass; hardest-external-critiques section. CORRECTS v1: swift-parsing's central type is Parse/ParsePrint, not a Parser protocol. Recommendation UNCHANGED and now over-determined."
  - "1.0.0 (2026-06-12): Initial fresh take; recommends uniform namespace-mirror naming; CANCEL disposition; [PKG-NAME-017] draft."
---
-->

> **Commission.** Principal direction 2026-06-12 (late): before the suspended
> `swift-iterator-primitives` → `swift-iteration-primitives` rename executes, a fresh
> session reviews prior art and gives an independent take, licensed to agree or disagree
> with the original direction, the principal's examples, and the seat's two-test frame
> alike. v1 shipped same-day; the principal directed a deeper pass. v2 is that pass:
> the same ONE recommendation, re-derived from linguistics, cross-ecosystem structure,
> and quantified catalog surfaces — with one v1 defect fixed (§12 amendment scope).

---

## 0. TL;DR

**Keep object/namespace-mirrored package naming at L1. Cancel the iterator→iteration
rename. No rename class exists.** Five independent lines now converge on this:

1. **Compound semantics** (§5): package names are noun-noun compounds headed by
   `-primitives`. In modifier position a noun is classificatory, not referential —
   "iterator primitives" already means *primitives FOR the iterator domain* (Levi 1978's
   FOR-relation). The premise "iterator names the object, iteration names the domain" is
   linguistically false in compound position; the choice only selects the anchor word —
   and the agent noun is the unambiguous one (§5.2).
2. **Cross-ecosystem structure** (§6): every surveyed hierarchical ecosystem puts
   activity/field words at *grouping* nodes and object nouns at *cells* — Go
   `encoding/json`, Python `email.parser`, Rust `std::iter`→`Iterator`, Haskell
   `Control.Monad`, Java `java.util.concurrent`→`Executor`. No counterexample found.
   The proposal inverts the universal: a field word at a leaf.
3. **The register system already exists per layer** (§7): L1 names mirror namespaces;
   L2 names follow spec authority ([PKG-NAME-011]); L3 names are field/umbrella words
   (`swift-file-system`, `swift-executors`). The domain instinct is a correct perception
   of *L3 identity*, mis-located at L1 — and spending the field word at L1 forecloses
   the correctly-sized L3 name (§10).
4. **Diachronic stability** (§8): the content-character a domain-naming gate keys on
   (concern vs catalog) is a *phase property* that migrations change; the shipped root
   namespace is the package's only time-invariant property. Names key to invariants.
5. **Quantified cost** (§4.5): the stem-identity surface is 9,906 manifest pairing
   lines; even the strongest two-package version of the proposal buys a permanent
   two-vocabulary domain for ~39 consumer-manifest edits and forecloses (3).

The principal's serialization/execution instinct pair is fully explained: both are the
*same* granularity rule firing — `serde`, `Observation`, `Synchronization` are
field-sized units; the institute's L1 cells are not. Java keeps `Executor` at the unit
inside `java.util.concurrent`; nobody names that package `java.util.execution`.

---

## 1. Context

**Trigger** ([RES-001] — naming ambiguity, precedent-setting). On 2026-06-12 the
principal directed `swift-iterator-primitives` → `swift-iteration-primitives` under a
new principle: *"the package name emphasizes the DOMAIN (iteration), not the object
(iterator)"*. The lane ran its W0 census (seat-verified: 30 org manifests = 27 live + 3
comment-only; zero docs/skills route on the package name; package-name-only; mirror +
redirect proven — *carried forward, seat-verified 2026-06-12*) and was blessed for W1.
The principal then questioned the direction — `swift-serialization-primitives` sounds
right, `swift-execution-primitives` would be "entirely wrong" — and suspended the rename
pending this take. After v1.0.0, the principal directed a deeper analysis; v2 adds the
linguistic, structural, diachronic, and quantitative layers and fixes a v1 defect.

**Tier 3** because the answer sets the naming register for every operation-domain
package and amends-or-affirms a 17-day-old Tier-3 DECISION. **Constraint**: research
only; the amendment in §12 is a draft for skill-lifecycle after ratification.

---

## 2. Question

Should institute package names be **domain-named** (`swift-serialization-primitives`)
or **object-named** (`swift-serializer-primitives`) — by what rule, and does it
generalize? For value domains the two coincide (`Buffer`, `Time`, `Observation` name
both artifact and field), so the question only *exists* for operation domains, where
English splits the doer from the doing. Sharpened: **may a package's noun diverge from
the noun of the surface it ships — and if some names should carry field vocabulary,
at which layer does that vocabulary belong?**

---

## 3. Prior art reviewed ([RES-019] internal-first)

| Source | Status | Position |
|---|---|---|
| `operation-domain-naming-and-organization.md` | Tier 3 DECISION 2026-05-26 | §3: package + namespace take the agent noun for machines; *"`Iteration` is not the iterator namespace"*; deverbal noun reserved for the witness alias (§5.2). Live corpus ratified. |
| `swift-package` [PKG-NAME-001] (+2026-05-26 clar.) | canonical | Noun form; machines → agent noun; gerunds forbidden at package/namespace level. |
| [PKG-NAME-015] | canonical | `typealias Iteration = Iterator.Witness`; `Serialization` reserved for `Serializer.Witness`. |
| [PKG-NAME-016] | canonical | "the package noun mirrors the namespace its surface occupies, owner-first." |
| [PKG-NAME-011] | canonical | **L2 names follow specification authority, not the shipped surface** (`swift-ieee-1003`, `swift-rfc-*`). Load-bearing for §7. |
| `transformation-domain-architecture.md` | DECISION v3.4.0 | Prescribes the agent-noun package set (parser/serializer/coder/formatter). |
| `package-namespace-noun-convention.md` | SUPERSEDED | The gerund→noun history; executed as the 2026-04-21 `Rendering`→`Render` cascade. |
| `domain-first-repository-organization.md` (+ prior-art) | RECOMMENDATION/DEFERRED 2026-02 | Org-level axis; registry survey only. |
| `ascii-parsing-domain-ownership.md` | SUPERSEDED (absorbed) | Subject-first exemplar; both tokens mirror shipped paths — not a domain-over-object precedent. |
| Seat's two-test frame | input | SUBJECT test (concern vs catalog) + LANGUAGE test (clean English noun); ~12 strong, 4 census-needed. |

The entire normative corpus assigns the agent noun to the package level. The 2026-06-12
direction proposes an override; §§5–10 give it the deepest hearing the evidence permits.

---

## 4. Empirical ground (all local claims `[Verified: 2026-06-12]`, file:line)

### 4.1 The mirror is the catalog's operating invariant

Census across the ~221 `swift-*-primitives` packages (file stems under `Sources/`,
one-type-per-file; declarations spot-verified): the package name is the kebab-cased form
of the shipped surface in the overwhelming majority — `swift-parser-primitives` ships 75
root-stem files vs 1 other; `swift-render-primitives` 27 vs 0; `swift-machine-primitives`
33 vs 0; `swift-lexer-primitives` 13 vs 0; `swift-sequence-primitives` 54 vs 3;
`swift-serializer-primitives` 22 vs 1. Exceptions, classified:

| Class | Instances | Character |
|---|---|---|
| Vocabulary mismatch | `swift-linter-primitives` ships `Lint` (`Lint.swift:36`) | the one true divergence |
| Family-label (no root namespace) | `swift-dimension-primitives` (Axis, Interval, Winding), `swift-symmetry-primitives` (Rotation, Symmetry, Shear), `swift-package-primitives` (Package, Target, Product), `swift-structured-queries-primitives` (CTE, WindowSpec, Where) | the name fills a vocabulary **vacuum** — see §7.2 |
| Integration bridges | `swift-empty/single/memory-iterator-`, `swift-memory-sequence-primitives` — sources exclusively `+conformance` files | name = recipient ⊗ provider tokens (§4.3) |
| Compressed bridge path | `swift-cyclic-iterator-primitives` ships `Cyclic.Group.Static.Iterator` (`…Iterator.swift:31`) | endpoints kept, middle dropped |

### 4.2 The four grammatical forms have one role each

`swift-iterator-primitives` ships all four, with assigned roles: `enum Iterator`
(`Iterator.swift:35`, the nest holding protocol + witness + chunk tier — 7 nested public
types); `typealias Iterating = Iterator.Protocol` (`Iterating.swift:22`); `protocol
Iterable` (`Iterable.swift:35`); `typealias Iteration = Iterator.Witness`
(`Iteration.swift:18`). A workspace grep confirms `Iteration` is the **only** result-noun
witness alias in existence (`typealias Serialization|Parsing|Rendering|Coding`: zero
hits): the word the rename would put on the package is already a *type* the package
exports, in the role [PKG-NAME-015] assigned it.

### 4.3 The operation token is also the bridge vocabulary

The iterator "variants" are bridges conferring the capability on another domain's
recipient: `swift-empty-iterator-primitives` ships solely `extension Empty: @retroactive
Iterator.Protocol` (`Empty+Iterator.Protocol.swift:20`); single → `extension Single:
@retroactive Iterable` (`Single+Iterable.swift:19`); memory-iterator → `extension
Memory.Contiguous: @retroactive Iterable` (`Memory.Contiguous+Iterable.swift:54`);
cyclic → one concrete conformer. In these names `-iterator` names the **capability
domain via its agent noun**, exactly as `-parser` does in `swift-byte-parser-primitives`
(ships `Byte.Parser`, `Byte.Literal.Parser` conforming to `Parser.Protocol` —
`Byte.Parser.swift:27`). The seam stays `Iterator.Protocol` under every proposal.

### 4.4 The principal's two examples, verified at source

**Executor**: `swift-executor-primitives` declares **no** `Executor` protocol, witness,
or `-able` — `Executor` is a declaration-only namespace root (`Executor.swift:13`) over
concrete scheduling artifacts (`Job` + `Job.Queue/Deque/Priority`, `Wait`,
`Shutdown(.Flag)`). Nothing models execution-as-activity. **Serializer**: the full
capability family — `Serializer.Protocol` (`Serializer.Protocol.swift:34`),
`Serializable` (`Serializable.swift:19`), `Serializer.Witness`
(`Serializer.Witness+Protocol.swift:13`), `Serializer.Builder`, combinators.

The asymmetry is real — but it is a **content** asymmetry, and content is a spectrum the
line cuts *within* packages: parser is seam **and** 75-file combinator algebra; lexer is
half concrete (`Lexer.Lexeme`, `Lexer.Scanner`), half protocol suite (`Lexer.Pull.Tokens`,
`Lexer.Pull.Assemble.Strategy`); formatter is a pure seam whose surface is split 2/2
*today only because* its witness still sits top-level pre-[PKG-NAME-015]
(`Format.swift:48`); builder is pure grammar (`Builder.swift:103`, `Buildable.swift:82`);
loader is pure catalog; machine is 33 files of machinery with no concrete parsers;
cursor is one concrete type; driver is an empty stub. Any rule keyed on this axis needs
a source census per package — the seat's own "4 census-needed" item is the proof — and
§8 shows the axis is unstable in time as well.

### 4.5 Quantified surfaces

- **Stem-identity surface**: 333 workspace manifests; **9,906** `.product(name:…,
  package:…)` pairing lines — the surface where module stem and package stem sit
  line-adjacent and would permanently mismatch for renamed packages.
- **Clean per-candidate consumer counts** (top-level manifests only, `.build/`
  excluded; iterator's 32 agrees with the seat's census 30): parser 19, serializer 7,
  coder 3, formatter 3, iterator 32, lexer 3, render 6, builder 3, machine 3, cursor 5,
  executor 2, loader 4, linter 6, byte-parser 6, memory-cursor 6, sequence 26.
- The seat's ~12-strong class ≈ **100+ consumer-manifest edits** plus mirrors.json,
  re-gates ×2 configs, and GitHub redirects; the strongest 2-package construction (§10)
  still ≈ 39.

---

## 5. Linguistic foundation (new in v2; sources web-verified 2026-06-12)

### 5.1 Package names are compounds, and compounds already supply the domain reading

Institute package names are noun-noun compounds headed by `-primitives`
(`<modifier> primitives`). Two robust findings about English N-N compounds:

- **Levi 1978** (*The Syntax and Semantics of Complex Nominals*): complex nominals are
  formed over a small set of recoverably deletable predicates — CAUSE, HAVE, MAKE, USE,
  BE, IN, **FOR**, FROM, ABOUT. "Iterator primitives" parses as *primitives FOR
  iterators* — the purposive relation is supplied by the compound itself.
- **Downing 1977** (*Language* 53): the modifier in a compound serves a
  **classificatory** function — it names a category, it does not refer to an instance
  (a "truck driver" involves no particular truck; general attributive non-referentiality
  per Huddleston & Pullum 2002, ch. on attributive modification — principle cited, no
  verbatim quote extracted).

Consequence: **the rename's premise is linguistically false.** "`iterator` names the
object, `iteration` names the domain" holds for the words in *referential* position; in
*modifier* position both classify the domain. `swift-iterator-primitives` already
denotes the iteration domain. What the choice actually selects is the **anchor word**
for the classifier slot.

### 5.2 The two anchor candidates are different kinds, and only one is unambiguous

- **Agent nominals (-er/-or)** denote the base verb's external argument — a
  *participant* (agent or instrument), never the event (Rappaport Hovav & Levin 1992,
  *-Er Nominals*; cross-linguistically corroborated by Baker & Vinokurova 2009,
  *Language* 85(3): agent nominalizations are "more constrained and nominally
  oriented" while event nominalizations retain verbal properties). `Iterator`,
  `Serializer`, `Executor` are reference-stable: they name the machine, full stop.
- **Deverbal -ation/-ing nominals** are systematically **ambiguous** between
  complex-event, simple-event, and result readings (Grimshaw 1990, *Argument
  Structure*): "the serialization took 5 ms" (event) vs "the serialization is 40 bytes"
  (result). `Iteration` and `Serialization` carry this three-way ambiguity wherever
  they appear.

For a 221-cell catalog whose names function as coordinates, the participant-denoting
form is the better anchor *on linguistic grounds alone* — and (the Tier-3 doc's Cursor
proof, retained) it is the **only universally available** form for the machine class.
The institute's own convention already instantiates the ambiguity cost: [PKG-NAME-015]
binds `Iteration` to the *witness machine value* — a participant — so the rename would
have one word denote a field at the package level, a machine value at the type level,
and an event/result in plain English. (`serde` pointedly ships no type named `Serde`.)

### 5.3 What the principal's ear is detecting

"Serialization primitives" and "serializer primitives" are both well-formed compounds;
the first anchors on the event noun (field register — the register of *book titles and
umbrella libraries*), the second on the participant noun (catalog register — the
register of *parts lists*). The instinct that the first "sounds right" is a register
perception, and it is correct — **for field-sized units** (§6). The instinct that
"execution primitives" is wrong is the same perception: the executor package is
audibly a parts list. Both ears are right; neither is a cell-naming rule.

---

## 6. Where field words live: the cross-ecosystem structure (web-verified 2026-06-12)

Surveyed against primary sources (subagent-verified; URLs in §16):

| Ecosystem | Grouping node (field/activity word) | Cell/leaf (object word) |
|---|---|---|
| Go stdlib | `encoding/`, `crypto/`, `container/` directories | `encoding/json`, `crypto/sha256`, `container/list`; guidance: short, clear, lowercase leaf names (go.dev/blog/package-names) |
| Python stdlib | `email`, `html` packages | `email.parser`, `html.parser` — **the leaf module is the agent noun** |
| Rust stdlib | `std::iter` ("Composable external iteration."), `std::fmt`, `std::io` | trait `Iterator`, `Formatter`, `Read`/`Write` inside |
| Rust ecosystem | crate `serde` — portmanteau of **ser**ialize/**de**serialize, field-sized | traits `Serializer`/`Deserializer`; **no type named `Serde`** |
| Java | package `java.util.concurrent` | interfaces `Executor`, `ExecutorService`, `ThreadPoolExecutor` — **industry's canonical executor framework keeps the agent noun at the unit; the package is not `java.util.execution`** |
| Haskell base | `Control.*`, `Data.*` roots | `Control.Monad`, `Data.List` |
| C++ stdlib | (flat headers) | `<iterator>`, `<algorithm>`, `<memory>` — object nouns at the cell (cppreference; 403 on fetch, structurally uncontroversial) |
| Apple stdlib-adjacent | modules `Observation` (ships `@Observable` — `Observable.swift:45`, `ObservationRegistrar` — `ObservationRegistrar.swift:17`), `Synchronization` (ships `Mutex`, `Atomic` — `Mutex/Mutex.swift`, `Atomics/Atomic.swift:20`), `Distributed`, `StringProcessing` — **one module = one whole field** | object-noun types inside |
| Apple packages | repos `swift-collections`/`-algorithms`/`-numerics` (plural aggregates) | modules `Collections`/`DequeModule`/`Algorithms`/`RealModule` |
| pointfree | package `swift-parsing`, module `Parsing` (the prominent gerund-unit example; field-sized) | central types `Parse`/`ParsePrint` *(v1 of this doc wrongly said "protocol `Parser`" — corrected)* |

**The pattern is universal across the survey: activity/field vocabulary names grouping
or field-sized units; object vocabulary names cells.** No surveyed ecosystem names a
fine-grained cell with the field word while reserving object words elsewhere. The
2026-06-12 direction, applied at L1, would be that inversion. Apple's `Observation` and
`Synchronization` — the strongest apparent precedent *for* the direction — are
field-sized single modules: the granularity at which field naming is exactly right, and
which the institute's L1 cells do not have (the iteration field spans core + 4 bridges +
the sequence sibling; the serialization field spans serializer + coder + the
binary/ascii/byte spine).

**Contextualization ([RES-021])**: adoption elsewhere is not necessity here — and here
even the adopters' own structure routes the field word to a unit shaped like the
institute's L3, not its L1.

---

## 7. The register system the catalog already runs (new in v2; fixes a v1 defect)

### 7.1 One principle, three layers

The package name keys to the **layer's identity-giving property**:

| Layer | Unit identity | Name register | Canonical rule | Verified instances |
|---|---|---|---|---|
| L1 primitives | a vocabulary cell — the shipped namespace/family | **mirror** (object noun) | [PKG-NAME-001/-016], §12 draft | the 221-package census, §4.1 |
| L2 standards | an external specification | **authority/spec ID** | [PKG-NAME-011] (already canonical) | `swift-ieee-1003`, `swift-rfc-*`, `swift-html-standard` |
| L3 foundations | a composed capability — a field | **field/umbrella/plural** | existing practice; worth one skill line | `swift-file-system` ships `File.*`; `swift-arguments` ships `Command.*`; `swift-executors` (plural catalog: `Executor.Cooperative`, `Kernel.Thread.Executor.Polling.*`); `swift-clocks` |

v1's [PKG-NAME-017] draft claimed "L1/L2" for the mirror rule — **wrong for L2**, whose
names follow the spec, not the surface ([PKG-NAME-011]). v2 rescopes the amendment to L1
(§12). This table is also the deep answer to the commissioning question "does the answer
generalize ecosystem-wide, partially, or not at all": **the mirror generalizes across
L1; the field register generalizes across L3; neither belongs at the other's layer.**

### 7.2 The family-vacuum clause (confronting the catalog's own field-labeled L1 packages)

The strongest internal objection to the mirror rule: L1 *already* contains
field-labeled packages — `dimension`, `symmetry`, `package`, `structured-queries`
(§4.1). If Axis+Interval+Winding may be called "dimension", why may
Iterator+Iterable+Iterating+Iteration not be called "iteration"?

Resolution, structural not numeric: those packages have **no root namespace** — no
shipped type's name can serve as the mirror, so the family label fills a vacuum. The
iterator package **has** a root: it declares `enum Iterator` hosting the seam and the
witness (`Iterator.Protocol`, `Iterator.Witness`), with 8 root-stem files to 3
satellites; parser 75:1, serializer 22:1, render 27:0, machine 33:0, lexer 13:0,
sequence 54:3. **Dominance criterion** (binary, greppable): a root exists iff the
package declares `enum X` and at least one of `X.Protocol` / `X.Witness` nests under
it. Root exists → mirror; no root → family label. No vacuum → no field word. (Formatter
passes via `Formatter.Protocol` — `Formatter.Protocol.swift:55` — despite its 2/2 file
split, which is a pre-[PKG-NAME-015] migration artifact, §8.)

### 7.3 Why coordinates at L1 (restated from v1, now downstream of §5–§6)

Derivability (type ⇄ dependency across 221 cells without lookup tables — load-bearing
for the workspace's own resolution rules and every agent session); stem identity across
9,906 pairing lines; family coherence (core, bridges, modules, seam share one
vocabulary, §4.3); zero-gate mechanizability (name tokens ⊆ shipped stems — greppable;
a P3-lint candidate, unlike gerund detection, whose fuzziness blocked [PKG-NAME-001]'s
mechanization and would return at package level under any domain rule).

---

## 8. Diachronic stability (new in v2)

A naming rule keyed to **content character** (concern vs catalog) keys to a *phase
property*: packages accrete combinators, grow or migrate seams, and shed witnesses
without changing identity. Verified instances of the phase-ness:

- `swift-formatter-primitives` reads "50% concern" today *solely because* its witness
  still sits top-level pre-[PKG-NAME-015] (`Format.swift:48`); after migration it is
  ~100%. A content-keyed name flips with migration state.
- `swift-parser-primitives` grew a 75-file combinator algebra around its seam; its
  content ratio moved continuously; its root did not.
- `swift-executor-primitives` could acquire a seam in a future arc (the L3 toolkit
  already ships `Kernel.Thread.Executor.*` shapes); under the two-test frame its name
  would then need to *flip* to "execution" — the name the principal called entirely
  wrong — or the rule admits it was never about content.

The shipped root namespace is the package's only **time-invariant** property; the
mirror keys the name to it. This is the structural refutation of the two-test frame
independent of census cost: it is not just expensive to apply — it is keyed to the
wrong variable.

---

## 9. Analysis

### Options

- **A — uniform mirror at L1** (per-layer registers per §7). As v1, now grounded in
  §§5–8.
- **B — domain names ecosystem-wide** (the original direction). Refuted by its own
  cleanest instance (executor, §4.4) → collapses into C.
- **C — gated rename class** (the seat's two-test frame). Census-cost (§4.4), keyed to
  a phase property (§8), re-imports package-level gerunds (parsing/coding/building/
  rendering — reversing the executed 2026-04-21 cascade for render), and yields a
  two-vocabulary domain (§4.3: bridges and modules keep the agent noun; the seam is
  `Iterator.Protocol` forever).
- **D — rename the namespace itself** (`enum Iteration`; full-stack domain vocabulary).
  Enumerated for completeness; killed by the Cursor proof (machines reliably have only
  the agent noun — `Cursor` has no deverbal form), by Grimshaw ambiguity at the type
  level, by [PKG-NAME-015] (the deverbal noun is the witness alias — `Iteration` cannot
  be both the namespace and the witness it nests), and by every consumer constraint
  site reading `T: Iterating` against a namespace that is no longer the machine.

### Cognitive Dimensions pass ([RES-025], both schemes at L1)

| Dimension | A: mirror | C: gated domain class |
|---|---|---|
| Consistency | one rule, no exceptions beyond the vacuum clause | three name registers at one layer; per-package gate |
| Role-expressiveness | name = shipped root; `-primitives` head supplies the FOR-domain reading (§5.1) | name = field word for *some* seams; role recoverable only with the gate's census in hand |
| Error-proneness | stem identity across 9,906 pairing lines | permanent module/package stem mismatch per renamed package; morphological mapping at every dependency declaration |
| Viscosity | renames never required by content drift | content drift (§8) pressures renames |
| Visibility | type → package derivable; org listing groups by family stem | field word visible at the renamed cores only; family scattered across two vocabularies |

### Hardest external critiques (pressure-test, [FREVIEW]-style)

1. *"Why `swift-serializer-primitives` when the ecosystem standard is `serde`-style
   field naming?"* — Because `serde` is the whole field in one crate; the institute's
   serialization field is a multi-package spine whose field name belongs to the L3
   aggregate (§6, §7). The cell answer is Python's: `email.parser`.
2. *"Apple names modules `Observation`/`Synchronization` — you're out of step."* — Those
   are field-sized single modules; at that granularity the institute uses the same
   register (L3 `swift-file-system`, `swift-executors`). Matching Apple's *words* at the
   wrong granularity would un-match Apple's *structure*.
3. *"Agent-noun catalogs read like internals."* — The `-primitives` head already marks
   the register (parts list by design); the field-facing surface is the org README,
   tiers docs, and L3 umbrellas — the artifacts a newcomer actually lands on. Search
   stemming conflates iterator/iteration regardless.

---

## 10. The strongest construction of the domain proposal, walked to its end state (new in v2)

Steelman, constructed to survive every objection above as far as possible: rename
**only** `iterator→iteration` and `serializer→serialization` (the only machine domains
with clean, non-gerund, ecosystem-free deverbal nouns — parser/coder/builder/lexer/
cursor fail language; executor/loader fail content; render is already the
[PKG-NAME-005] noun), **and** rename their modules (`Iteration_Primitives`) to preserve
stem identity. End state:

1. The domain still speaks two vocabularies: the seam (`Iterator.Protocol`), the active
   alias (`Iterating`), the passive (`Iterable`), all five bridge/subject packages
   (`-iterator-`/`-parser-` tokens), and every constraint site keep the agent noun.
   Only the core's distribution shell switches. The family's one systematic property —
   shared stem — is spent to relabel one node out of six.
2. `Iteration`/`Serialization` each become package + module + *type* (the witness alias,
   `Iteration.swift:18` and [PKG-NAME-015]-planned) — the Grimshaw ambiguity (§5.2)
   instantiated three ways in-catalog, where `serde` ships no `Serde`.
3. The field words are spent at cells, foreclosing the correctly-sized L3 names
   (`swift-iteration`, `swift-serialization`) that would complete the §7 register
   system — i.e., the proposal does not import Apple's system; it **prevents** it.
4. The class has two members, by a gate that is part source-census, part English
   ruling — a register island bought with ~39 consumer-manifest edits, mirror surgery,
   and ×2-config re-gates, recurring at every future operation domain's birth.
5. Module renames (added for stem identity) force `import` edits in every consumer
   source file — strictly more breakage than the suspended package-name-only plan,
   which itself was already 30 manifests.

Even maximally steelmanned, the end state is strictly worse than uniform mirror + L3
field register on every axis except the euphony of two org-listing lines.

---

## 11. Outcome

**Status: RECOMMENDATION** (principal ratifies; then DECISION + [PKG-NAME] amendment
via skill-lifecycle).

**Adopt the per-layer register system (§7) with the mirror rule at L1 ([PKG-NAME-017],
§12): cancel the iterator→iteration rename; no rename class; field vocabulary is the
L3+ register; the April gerund cascade stands; [PKG-NAME-015]'s witness aliases keep
sole ownership of the deverbal nouns.** A future L3 `swift-serialization` /
`swift-iteration` umbrella is the legitimate home of the field instinct.

### Where this disagrees with the 2026-06-12 direction — plainly

The direction "packages name domains, types name objects" is rejected as an L1 rule
because: (a) its premise fails linguistically — in compound position the object noun
already names the domain (§5.1); (b) its cleanest instance refutes it at source —
executor (§4.4) — forcing a content gate that is keyed to a phase property (§8) and a
per-package census; (c) it splits each domain into two package vocabularies because
bridges, modules, and the seam keep the agent noun (§4.3, §10); (d) the register it
reaches for is real but belongs to field-sized units — the universal cross-ecosystem
structure (§6) and the institute's own L2/L3 registers (§7) both already place it
there; (e) the deverbal nouns are spoken for at type level ([PKG-NAME-015], §4.2). The
instinct is a correct granularity perception, mis-located by one layer.

### What the deep pass changed vs v1

The recommendation **held**; the derivation changed materially: the compound-semantics
argument (§5.1) replaces "derivability" as the primary ground — the rename's premise is
false before its costs are even counted; the per-layer register table (§7.1) fixes v1's
amendment mis-scoping L2; the family-vacuum clause (§7.2) closes the
dimension/symmetry objection v1 waved at; the diachronic argument (§8) refutes the
two-test frame independently of census cost; the steelman (§10) proves CANCEL against
the proposal's best version, not its weakest; one v1 citation corrected (swift-parsing:
`Parse`/`ParsePrint`, not a central `Parser` protocol).

---

## 12. Draft [PKG-NAME] amendment v2 (delivery only — lands via skill-lifecycle after ratification)

> ### [PKG-NAME-017] L1 Package Name Mirrors the Shipped Surface (Per-Layer Register Rule)
>
> **Statement**: An L1 package's name MUST be the layer-affixed kebab form of the
> surface it ships: (a) the **root namespace path** when a root exists — the package
> declares `enum X` (or struct-namespace) with `X.Protocol` and/or `X.Witness` nested
> (`swift-buffer-linear-primitives` ⇄ `Buffer.Linear`, `swift-iterator-primitives` ⇄
> `Iterator`); (b) the **recipient ⊗ provider token pair** for integration bridges per
> [PKG-NAME-016] (`swift-empty-iterator-primitives` ⇄ `Empty: Iterator.Protocol`); (c)
> the **family label** ONLY in a root vacuum — no shipped type's name can serve as the
> mirror (`swift-dimension-primitives` ⇄ Axis/Interval/Winding); (d) the **protocol
> name** for pure-capability packages per [PKG-NAME-009] (`swift-carrier-primitives` ⇄
> `Carrier`). The L1 package level introduces NO independent vocabulary: deverbal
> activity nouns (*iteration*, *serialization*, *parsing*) MUST NOT name a
> machine-domain package whose root exists — the agent-noun namespace names it
> ([PKG-NAME-001]) and the deverbal noun stays reserved for the witness alias
> ([PKG-NAME-015]).
>
> **Register table (normative cross-reference)**: L2 names follow specification
> authority per [PKG-NAME-011], NOT this rule. L3+ aggregation packages take
> field/umbrella/plural names (`swift-file-system`, `swift-executors`); a field word
> (`serialization`, `iteration`) is *reserved for* that layer and MUST NOT be spent on
> an L1 cell.
>
> **Rationale**: package names are `-primitives`-headed compounds whose modifier is
> classificatory — the object noun already supplies the domain reading (Levi 1978
> FOR-relation); agent nominals are participant-denoting and unambiguous where deverbal
> nominals are event/result-ambiguous (Rappaport Hovav & Levin 1992; Grimshaw 1990);
> every surveyed ecosystem places field words at grouping nodes and object nouns at
> cells (Go `encoding/json`, Python `email.parser`, Rust `std::iter`→`Iterator`, Java
> `java.util.concurrent`→`Executor`); the root namespace is the package's only
> time-invariant property — content character is a phase; 221-cell derivability and the
> 9,906-line stem-identity surface. Domain-naming at L1 evaluated and REJECTED
> 2026-06-12: `package-naming-domain-vs-object.md` v2.
>
> **Enforcement**: mechanizable — root-existence is greppable (`enum X` +
> `X.Protocol|X.Witness`), and name tokens ⊆ shipped stems; P3-lint candidate.
>
> **Cross-references**: [PKG-NAME-001/-005/-009/-011/-015/-016].

Plus the one-sentence [PKG-NAME-001] addendum (unchanged from v1): the machine package
takes the same agent noun as its namespace; the 2026-06-12 domain-over-object proposal
was evaluated and rejected — see [PKG-NAME-017] and this doc.

---

## 13. Disposition of the suspended rename

**lane-se0516-iteration Part B: CANCEL** (not retarget — §10 shows no surviving
variant). The W0 census stays banked as the package's consumer-map artifact; the seat's
W1 sweep, riders, and "rename after γ" sequencing item dissolve; Part A remains closed
(pass, banked). The at-birth `swift-sequencing-primitives` idea is rejected with the
class; any future split from `swift-sequence-primitives` (ships `struct Sequence` —
`Sequence.swift:98`, `Sequenceable` — `Sequenceable.swift:90`, `Sequence.Iterator` —
`Sequence.Iterator.swift:36`) is named by mirror at birth.

## 14. Candidate list under the recommendation

**No rename class survives.** All ~30 would-have-been candidates: KEEP (full
source-verified classifications in §4 and v1 §8 — parser, serializer, coder, formatter,
iterator + 4 bridges, lexer, render(+async), builder, machine, executor, loader,
linter, cursor, driver(stub), sequence(+memory-sequence), the 8-package
ascii/binary/byte/leb128 spine, binary-cursor, memory-cursor).

## 15. Residual ([RES-027]: all directions, no load-bearing unverified premises)

1. **`swift-linter-primitives` ⇄ `Lint`** (`Lint.swift:36`) — the catalog's one true
   vocabulary mismatch; micro-arc candidate ([PKG-NAME-005] favors `Lint` →
   `swift-lint-primitives`); deliberately not bundled here.
2. **L3 `swift-serialization` / `swift-iteration` umbrellas** — the field register's
   correct landing place when/if L3 aggregation over those spines is wanted.
3. **Formatter's pre-[PKG-NAME-015] witness** (`Format.swift:48`) — pending migration
   per the Tier-3 doc §5.1; also the live demonstration of §8's phase-property point.
4. **Witness-alias register note** (observation only, for the protocol-architecture
   piece): [PKG-NAME-015]'s result-noun alias names a participant (the witness machine)
   with an event/result-ambiguous nominal (Grimshaw, §5.2) — the convention is ratified
   and unchallenged here; noted so the ambiguity is a known property, not a discovery.
5. **Family-label clause skill line** — §7.2's vacuum rule is one sentence in the
   amendment; dimension/symmetry/package/structured-queries need no action.

## 16. References

**Internal**: `operation-domain-naming-and-organization.md` (Tier 3, DECISION);
`transformation-domain-architecture.md` (v3.4.0); `swift-package` skill
[PKG-NAME-001/-005/-009/-011/-015/-016]; the two handoffs; seat census 2026-06-12;
local file:line cites inline.

**Apple primary (local clone `~/Developer/swiftlang/`)**: `swift/stdlib/public/
{Observation,Synchronization,Distributed,StringProcessing}`;
`Observation/Sources/Observation/Observable.swift:45`, `ObservationRegistrar.swift:17`;
`Synchronization/Mutex/Mutex.swift`, `Atomics/Atomic.swift:20`;
`swift-testing/Package.swift:40,73`.

**External, subagent-verified vs primary URLs 2026-06-12**:
[Go blog — Package names](https://go.dev/blog/package-names) (+ [pkg.go.dev/std](https://pkg.go.dev/std));
[Rust std::iter](https://doc.rust-lang.org/std/iter/) ("Composable external iteration.");
[serde](https://docs.rs/serde/latest/serde/) (portmanteau; no `Serde` type);
[Python email.parser](https://docs.python.org/3/library/email.parser.html);
[Java java.util.concurrent](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/package-summary.html) (`Executor` interface);
[Haskell Control.Monad](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Control-Monad.html);
[cppreference](https://en.cppreference.com) (`<iterator>`; fetch 403'd — structural claim only);
[apple/swift-collections](https://github.com/apple/swift-collections), [-algorithms](https://github.com/apple/swift-algorithms), [-numerics](https://github.com/apple/swift-numerics);
[pointfreeco/swift-parsing](https://github.com/pointfreeco/swift-parsing);
[Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) (verified: no module/package-naming guidance).

**Linguistics (subagent-verified bibliographic anchors)**:
Levi, J. N. 1978. *The Syntax and Semantics of Complex Nominals*. Academic Press ([archive](https://archive.org/details/syntaxsemanticso0000levi));
Downing, P. 1977. "On the Creation and Use of English Compound Nouns." *Language* 53(4): 810–842;
Grimshaw, J. 1990. *Argument Structure*. MIT Press (LI Monograph 18);
Rappaport Hovav, M. & B. Levin. 1992. "-Er Nominals." *Syntax and Semantics* 26: 127–153;
Baker, M. & N. Vinokurova. 2009. "On Agent Nominalizations…" *Language* 85(3): 517–556 ([JSTOR](https://www.jstor.org/stable/40492892));
Comrie, B. & S. Thompson. 1985. "Lexical Nominalization." In Shopen (ed.), *Language Typology and Syntactic Description* 3;
Huddleston, R. & G. Pullum. 2002. *The Cambridge Grammar of the English Language*. CUP (attributive non-referentiality — principle, no verbatim quote extracted);
Parnas, D. L. 1972. "On the Criteria…" *CACM* 15(12) (verified: silent on naming).
