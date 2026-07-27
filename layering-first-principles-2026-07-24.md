# Layering — a first-principles review

**Date:** 2026-07-24
**Status:** in progress; written incrementally. Each section is durable as soon as it appears.
**Scope:** Swift Institute and its sub-orgs (primitives, standards, foundations, and the
aspirational components/applications), plus `repotraffic` and `swift-institute/Workspace`.
Legal packages and `coenttb/*` are out of the census.

> This is **not** a compliance audit. A separate lane measured conformance to the current
> five-layer model. This document asks whether the model is the right one.

---

## 0. Instrument and measured baseline

Every number below was produced with `<workspace>/swift-institute/Scripts/eco-probe.sh`, a
positive-controlled probe library. Its `selftest` was re-run at the start of this lane:
**9 passed, 0 failed**, with all six degenerate-case controls failing loud at exit 2.

Where a hand-written probe was unavoidable, its positive and negative controls are reported
beside the number. **A count with no stated control is not a finding in this document.**

### 0.1 Census — realised packages

Probe: `eco-probe.sh manifests` over 22 org roots (the 17 census orgs plus
`swift-components`, `swift-applications`, `swift-foundry`, `swift-nist`, `repotraffic`).
Control line emitted by the probe: *"481 (controls passed: roots exist, known-present found,
count>=floor, no `.build*` contamination)"*.

| Layer | Roots | Realised packages (top-level `Package.swift`) |
|---|---|---|
| L1 Primitives | `swift-primitives` | **204** |
| L2 Standards | `swift-standards` + 14 authority/vendor roots | **124** |
| L3 Foundations | `swift-foundations` | **146** |
| L4 Components | `swift-components` | **1** |
| L5 Applications | `swift-applications` | **0** |
| *unassigned* | `swift-foundry` (3), `swift-institute` (2), `repotraffic` (1) | **6** |
| | | **481** |

L2 breakdown: `swift-ietf` 64, `swift-standards` 28, `swift-iso` 12, `swift-w3c` 6,
`swift-whatwg` 2, `swift-ieee` 2, `swift-iec` 2, and one each in `swift-ecma`, `swift-incits`,
`swift-nist`, `swift-arm-ltd`, `swift-intel`, `swift-microsoft`, `swift-riscv`,
`swift-linux-foundation`.

**Realised vs reserved is kept separate throughout.** `swift-applications` contributes **zero**
manifests — it does not appear in the probe output at all — and `swift-components` contributes
exactly one. The 25 + 40 directories under those two roots are reservations. Positive control
for the same probe at its non-degenerate case: 204 manifests in `swift-primitives`.

### 0.2 Dependency graph

Probe: `eco-probe.sh deps <manifest>` over all 481 manifests. Probe failures: **0**.
Positive control: the known edge `swift-sql → swift-rfc-4122` is present (1 hit).
Negative control: a fabricated identity `swift-zzz-does-not-exist` returns 0 hits.

- Total `.package(…)` edges: **2 370** (comment-stripped, string-aware, multi-line aware).
- Internal (target resolves to a package in the census): **2 308**.
- External: **62**, dominated by `swift-syntax` (14), `swift-log` (12), `swift-crypto` (7),
  `vapor` (7), `swift-collections` (6).
- Packages with at least one edge: **442 / 481**.

Classified by layer relation (excluding the 55 edges touching an unassigned root):

| Relation | Edges | Share |
|---|---|---|
| same-layer (lateral) | **1 475** | **65.5 %** |
| downward | 764 | 33.9 % |
| **upward** | **14** | 0.6 % |

Lateral edges by layer: **L1 976**, **L2 174**, **L3 325**.

> **Correction to a figure in circulation — since settled jointly with the census lane.** The
> lead's brief states *"2 upward edges, 1 genuine"*. The measured count over all 481 manifests
> is **14**, and the census lane's independent raw count is **the same 14, package for
> package**. There was never a measurement disagreement: **14 is the raw measurement; 2 is the
> measurement plus two policy rulings** — reclassifying `swift-mailgun-types` /
> `swift-stripe-types` to L3 (removing 9) and placing lint-rule bundles outside the model
> (removing 3). **The agreed publication form is "14 raw measured / 2 post-ruling", never 2
> alone**, because the 9 became legal by *reclassification*, not by ceasing to exist. §0.3
> gives the attribution method; **§7.8 and §7.9 correct this section** — three edges asserted
> later in the day were withdrawn, and the figures below that were derived from source
> directories are superseded.

### 0.3 Target attribution — resolving the upward-edge discrepancy

A `.package(…)` declaration is not by itself a dependency of the *library*. It may be consumed
only by a `.testTarget`. A hand-written attributor was built for this (comment-stripping,
balanced-paren, and — critically — **alias-aware**: several manifests declare
`static var x: Self { .product(name:…, package:"…") }` and reference `.x` inside targets, which
a naive scan attributes to nothing).

Controls, run before any real manifest is touched, both **PASS**:
- direct/test/comment control: a lib-target dep, a test-target dep, and a commented-out
  `.package(` are classified `lib`, `test`, and *absent* respectively;
- alias-indirection control: a dep reachable only through a `static var` alias is classified
  `lib`.

Coverage over the real corpus: 2 370 declarations → **2 277 lib**, **51 test**,
**42 unattributed** (1.8 %; declared but referenced by no target — genuinely unused deps or
parser blind spots, reported rather than silently dropped).

**Upward edges: 14, of which 11 are library-target edges outside the linter-rules carve-out.**

| Source | Layer | Target | Layer | Attribution |
|---|---|---|---|---|
| `swift-mailgun-types` | L2 | `swift-dependencies`, `swift-dual`, `swift-url-routing`, `swift-html-form-coder`, `swift-emailaddress` | L3 | lib ×5 |
| `swift-stripe-types` | L2 | `swift-dependencies`, `swift-dual`, `swift-url-routing`, `swift-html-form-coder` | L3 | lib ×4 |
| `swift-rfc-2388` | L2 | `swift-html-form-coder` | L3 | lib |
| `swift-postgresql-standard` | L2 | `swift-tests` | L3 | lib (test-support target) |
| `swift-primitives-linter-rules` | L1 | `swift-institute-linter-rules` | L3 | lib — *carved out* |
| `swift-standards-linter-rules` | L2 | `swift-institute-linter-rules` | L3 | lib — *carved out* |
| `swift-primitives-linter-rules` | L1 | `swift-linter-rules` | L3 | test — *carved out* |

The brief's *"2 upward edges, 1 genuine"* understates this by roughly 5×. More important than
the count is that **the violations are not scattered — they are a coherent cluster.**
`swift-mailgun-types` and `swift-stripe-types` are vendor API bindings that happen to sit under
`swift-standards/`; they need URL routing, form coding and dependency injection, all of which
live at L3. `swift-rfc-2388` (multipart/form-data) depends on the *implementation* of the thing
it specifies. Three of the four are the same shape: **a package whose declared layer disagrees
with the layer its role requires.**

### 0.4 Acyclicity

Cycle detection over the full internal library graph (481 nodes) and over each same-layer
subgraph. **Injected-cycle control fires (PASS, 1 cycle detected)** when an artificial
`swift-sql ↔ swift-postgresql-standard` pair is added.

| Graph | Nodes | Distinct edges | Cycles |
|---|---|---|---|
| full internal | 481 | 2 277 (lib) | **0** |
| L1 same-layer subgraph | 204 | 946 | **0** |
| L2 same-layer subgraph | 124 | 173 | **0** |
| L3 same-layer subgraph | 146 | 316 | **0** |

(Distinct ordered pairs; the 1 475 lateral figure counts *declarations*, of which some are
duplicates across products of the same package.)

---

## 1. What is a layer FOR?

This has never been written down, and every disagreement about placement traces back to that.
A purpose that cannot be wrong is worthless, so each candidate below is stated as a property
the model would guarantee, **paired with the observation that would refute it as the operative
purpose** — and then that observation is taken.

### P1 — "Layers guarantee acyclicity."

**Falsifier:** if the graph is already acyclic without the layer rule doing the work, layering
is not what buys acyclicity.

**Verdict: REFUTED.** The layer rule constrains *direction between* layers. It says nothing
about edges *within* a layer, and 1 475 of 2 253 edges are within a layer. Those 1 475 edges
are unconstrained by the model, and they are nevertheless acyclic (0 cycles in all three
same-layer subgraphs, injected-cycle control passing). Acyclicity is being maintained by
something other than the layer rule — ordinary design discipline. Meanwhile the layer rule's
own contribution is 14 detected violations. **Layering is not the reason this graph is a DAG.**

### P2 — "Layers enable independent releasability."

**Falsifier:** release cadence should track layer if this is the purpose.

**Verdict: NOT SUPPORTED — the model is not being used this way.** 2 277 of 2 328 attributed
edges resolve to sibling institute packages, and the sampled manifests pin them by
`branch: "main"` rather than by version (`swift-mailgun-types`, `swift-postgresql-standard`,
`swift-rfc-2388` all shown above). A branch-pinned graph has no release independence to protect
at any layer, so layers cannot currently be earning their keep this way. This is a statement
about present practice, not about whether P2 *could* become the purpose.

### P3 — "Layers bound what a consumer must reason about."

**Falsifier:** if transitive closure size does not stratify by layer, the model bounds nothing.

**Verdict: STRONGLY SUPPORTED — this is the operative purpose.** Transitive internal
dependency-closure size (lib edges only; recursion control on a synthetic `a→b→c` chain
passes):

| Layer | n | min | p25 | median | p75 | p95 | max | mean |
|---|---|---|---|---|---|---|---|---|
| L1 | 204 | 0 | 9 | **16** | 27 | 52 | 74 | 20.3 |
| L2 | 124 | 0 | 14 | **70** | 82 | 99 | 175 | 55.6 |
| L3 | 146 | 0 | 78 | **102** | 154 | 198 | 260 | 106.2 |

The medians separate cleanly and monotonically. **Zero of 204 L1 packages exceed the L3
median.** Only 6 of 124 L2 packages do (4.8 %).

And those six are: `swift-mailgun-types` (175), `swift-stripe-types` (170), `swift-rfc-2388`
(164), `swift-postgresql-standard` (151) — **the same packages that produce the upward edges in
§0.3**. Two independent tests, one on edge direction and one on closure size, flag the same
four packages. That convergence is the strongest single piece of evidence in this document:
the layer model has a real, measurable semantics, and it is *closure bounding*.

### P4 — "The rule is a review prompt, not a graph property."

**Falsifier:** essentially none — which is the finding.

**Verdict: TRUE OF THE RULE AS CURRENTLY WRITTEN, and this is a defect.**
`[ARCH-LAYER-001]` permits a same-layer edge when it is "an essential semantic prerequisite"
and does not "move higher-layer policy into the dependency". Neither condition is machine-
checkable. The consequence is measurable: the checkable half of the rule governs 14 edges; the
unheckable half governs 1 475. **98.4 % of the edges the rule nominally covers are adjudicated
by a criterion no probe can evaluate.**

### P5 — "Layers mark a purity boundary (Foundation-freedom)."

**Falsifier:** if Foundation use does not track layer, purity is not what layers encode.

**Verdict: SUPPORTED AS A GRADIENT, VIOLATED AS A RULE.** Sources under `Sources/`, comments
stripped, matching `import Foundation` / `FoundationEssentials` in all live spellings
(`public import`, `@_exported public import`, `@preconcurrency import`) — regex control matches
3 live forms and excludes the commented form:

| Layer | Packages importing Foundation | Import lines |
|---|---|---|
| L1 | 1 / 204 (**0.5 %**) | 11 |
| L2 | 11 / 124 (**8.9 %**) | 516 |
| L3 | 39 / 146 (**26.7 %**) | 520 |

A clean monotone gradient: layer predicts purity well. But `CLAUDE.md`'s `[ARCH-LAYER-007]`
states *no* main target imports Foundation at any layer, with a carve-out only for an opt-in
Foundation Integration target. Confining the check to Foundation-named target directories:
**13 packages keep it inside an integration target; 39 leak it into core** (L1 1, L2 4,
L3 33, unassigned 1). So P5 describes what the ecosystem actually *does* — but the rule as
written describes something the ecosystem does not do, and has not for 39 packages.

### 1.1 Conclusion of Section 1

**The operative purpose of a layer in this ecosystem is P3: to bound the transitive closure a
consumer takes on.** P5 is a real correlate. P1 is refuted. P2 is inactive under branch
pinning. P4 explains why the model feels weak in review: its enforceable part covers 0.6 % of
the edges it nominally governs.

This matters for everything downstream, because it says what a *correct* model must do: **make
closure size predictable from position.** Any alternative model must be scored on that, not on
elegance.

---

## 2. Role classification — testing the principal's hypothesis

The hypothesis: *decomposition-then-composition recurs at every layer*, so "layer" may be
conflating depth-of-abstraction with role-within-a-layer.

Roles are defined operationally. **Structural** roles are derived from the measured graph and
source; **nominal** roles are derived from naming and are labelled as such, because naming is
evidence about intent, not about structure.

### 2.1 Structural roles — these DO recur at every layer

**Leaf** (internal lib out-degree = 0) and **composer** (out-degree ≥ 1):

| Layer | Leaf | Composer | n |
|---|---|---|---|
| L1 | 16 (7.8 %) | 188 (92.2 %) | 204 |
| L2 | 13 (10.5 %) | 111 (89.5 %) | 124 |
| L3 | 11 (7.5 %) | 135 (92.5 %) | 146 |

The proportions are near-identical across three layers of very different content. **The
leaf/composer split is layer-invariant.** That is the principal's hypothesis, confirmed.

**Thin converger** (a re-export shell: ≥ 1 `@_exported import`, < 150 LOC, ≤ 10 files):
**34 at L1, 11 at L2, 28 at L3** — 73 packages, present at every layer.

Examples across all three: `swift-affine-algebra-primitives` (28 LOC, 2 re-exports, L1);
`swift-http-standard` (37 LOC — 3 `@_exported public import`s of `RFC_9110/9111/9112` plus
`public typealias HTTP = RFC_9110`, L2); `swift-clocks` (2 LOC, 1 re-export, L3);
`swift-types-foundation` (41 LOC, 10 re-exports, L3).

> A methodological note that changed this number: my first pass matched
> `^\s*@_exported\s+import` and reported `swift-http-standard` as having **zero** re-exports.
> The live spelling is `@_exported public import`. The corrected pattern returns 3. This was a
> silent zero in my own instrument, caught only because the brief asserted a value I could
> check against. Every count in this section uses the corrected pattern.

### 2.2 Nominal roles — these do NOT recur; they are layer-specific

| Role (nominal) | L1 | L2 | L3 |
|---|---|---|---|
| `-primitives` | 202 | 0 | 0 |
| specification (`swift-rfc-*`, `swift-iso-*`, …) | 0 | 90 | 0 |
| `-standard` convergence | 0 | 29 | 0 |
| `-dependencies` (DI integration) | 0 | 0 | **7** |
| `-live` (live vendor implementation) | 0 | 0 | 2 |
| backend variant (`-native`, `-provider`) | 0 | 0 | 2 |
| no suffix family | 1 | 2 | 126 |

**Suffix families are perfectly layer-segregated.** Not one crosses a layer boundary.

> Two false positives that naive suffix matching produced and structural inspection removed:
> `swift-time-to-live` is not a `-live` variant, and `swift-memory` is not a `-memory` backend.
> 2 of 6 initial matches were wrong. Reported because the same trap took out the `swift-jobs`
> precedent earlier today.

The `-dependencies` family, verified structurally rather than by name — every one depends on
`swift-dependencies`, and all but one pair with a realised core package:

| Package | LOC | consumers | core realised? |
|---|---|---|---|
| `swift-translating-dependencies` | 1 277 | 6 | yes |
| `swift-environment-dependencies` | 395 | 10 | yes |
| `swift-clocks-dependencies` | 221 | 5 | yes |
| `swift-sql-dependencies` | 113 | 0 | yes |
| `swift-throttling-dependencies` | 80 | 2 | yes |
| `swift-time-to-live-dependencies` | 67 | 0 | yes |
| `swift-logger-dependencies` | 37 | 7 | **no** — wraps external `swift-log` |

### 2.3 Why the nominal roles cannot recur — and what that proves

This is the decisive point, and it cuts *against* collapsing layer into role.

The `-dependencies` role requires `swift-dependencies`, which is an L3 package. **An L1 or L2
package cannot adopt this role without creating an upward edge.** The role is not absent from
L1/L2 by convention; it is *unavailable* there, because its enabling substrate sits above.
Identically, the specification role requires an issuing authority to mirror, which is what
defines L2; and the `-primitives` role requires having nothing beneath you, which is what
defines L1.

**So the answer to the principal's hypothesis is: half right, and the half that is wrong is the
load-bearing half.**

- The *structural* triple — leaf / composer / thin converger — **genuinely recurs at every
  layer**, in near-identical proportions, and **has never been named**. That is a real gap and
  the principal spotted it correctly.
- The *nominal* roles **do not recur, and provably cannot**, because role availability is gated
  by what exists below you. Layer therefore carries information that role does not.

If roles recurred completely, layer would be redundant with role and the model should collapse
to one axis. They do not. **Layer and role are genuinely two axes — but they are not
independent: role is a function of layer-depth, not a free coordinate.**

---

## 3. Explaining the 65 % lateral figure

*(This is Section 4 of the brief, taken early because Section 2's result makes it a one-line
consequence.)*

The headline — 1 475 of 2 253 layered edges (65.5 %) are same-layer — has been read as evidence
that the layer model fails to constrain anything. **That reading does not survive
decomposition.**

| Layer | lateral edges | downward edges | upward | Can this layer go downward at all? |
|---|---|---|---|---|
| L1 | **976** | 0 | 2 | **No — L1 is the bottom.** |
| L2 | 174 | 334 | 12 | yes |
| L3 | 325 | 430 | 0 | yes |

**L1 holds 976 of the 1 475 lateral edges — 66 % of them — and L1 has no layer beneath it.**
For an L1 package, every internal dependency is *necessarily* lateral. Counting those as
evidence of lateral sprawl is counting a tautology.

Corroborating: among L1 composers, **187 of 188 (99.5 %) are same-layer-only**, versus 19.8 % at
L2 and 23.0 % at L3. L1 is not behaving like L2 and L3 with more lateral edges; it is behaving
like the floor of a graph, which is what it is.

**Excluding the bottom layer, the lateral share is 499 / 1 275 = 39.1 %** — an ordinary figure
for a decomposed library ecosystem, and one that sits comfortably inside "essential semantic
prerequisite".

So: the 65 % figure is **not** the model failing to express a distinction. It is an artifact of
(a) L1 being the floor and (b) L1 holding 204 of 481 packages — 42 % of the ecosystem. The
sharper question the figure does raise is different and worth stating plainly: **L1 is not one
layer's worth of packages.** 204 packages with a median closure of 16 and a maximum of 74, all
mutually lateral, is a stratified structure being flattened into a single label. That is where
"we might need more layers" has actual evidence behind it — *at L1, not above it*.

---

## 4. The decisive evidence: L1 already replaced the layer model, and nobody said so

While measuring §3 I found that the primitives layer does not actually run on the five-layer
model at all. `<workspace>/swift-institute/Skills/primitives/SKILL.md` §"Tier Architecture",
`[PRIM-ARCH-001]` (line 99):

> *"The primitives layer is organized as a DAG of dependency tiers. Tier assignments are
> COMPUTED algorithmically from `Package.swift` dependencies … this skill deliberately carries
> no static tier table (a hand-maintained mirror of computed data drifts …)."*

and line 117:

> *"Circular dependencies are FORBIDDEN. Lateral (same-tier) dependencies are FORBIDDEN."*

Three things follow, and together they answer the principal's question.

**(1) One layer was not enough, and L1 solved it by adding an axis — a computed one.** My
independent longest-path measurement inside L1 (synthetic-chain control passes) finds **27
distinct depth levels across 204 packages**, maximum chain depth 26 (`swift-version-primitives`,
then `swift-binary-coder-primitives` and `swift-ascii-parser-primitives` at 25). The skill's
own generator reports 19 tiers. Either way: **the thing called "one layer" is internally a
19-to-27-level stratification.** "We might need more layers" is not speculative — L1 has had
them for months.

**(2) L1's lateral policy is the exact opposite of the ecosystem's, and neither document
acknowledges the other.** `[ARCH-LAYER-001]` permits same-layer edges; `[PRIM-ARCH-001]`
forbids same-tier edges. They do not actually conflict — but only because a *computed* tier
makes its own ordering rule vacuous: with `tier = max(tier[dep]) + 1`, a same-tier edge is
arithmetically impossible. **The tier rule cannot be violated, so it enforces nothing.** What
the tier model actually delivers is not a prohibition; it is *a depth number that is correct by
construction*. And a correct depth number is precisely P3 — closure bounding — made mechanical.

**(3) Declared layer is a lossy proxy for that number.** Extending the longest-path computation
to the whole internal graph (control: 0 of 2 205 edges have a consumer whose computed depth
fails to exceed its dependency's — the invariant a longest-path assignment must satisfy):

| Declared layer | n | min | p25 | median | p75 | max |
|---|---|---|---|---|---|---|
| L1 | 204 | 0 | 7 | 11 | 17 | 26 |
| L2 | 124 | 0 | 10 | 26 | 30 | 37 |
| L3 | 146 | 0 | 25 | 31 | 35 | 41 |

Global depth range 0–41. The bands are ordered but they overlap heavily: **55.6 % of L2
packages and 28.1 % of L3 packages have a computed depth that falls inside L1's range.** For
those 110 packages the declared layer conveys no depth information that the graph does not
already carry more precisely.

> Secondary defect, reported for the record rather than pursued: `[PRIM-ARCH-001]` calls the
> computed table "canonical, always-current" and cites *"19 tiers / 134 packages as of
> 2026-07"*. The file `<workspace>/swift-primitives/Documentation.docc/Computed Primitives
> Tiers.md` carries `generated: 2026-05-08`, `total_packages: 134`. There are **204** realised
> L1 packages today. The always-current table is 70 packages stale and two and a half months
> old — the identical failure mode the skill retired the previous static table to avoid.

---

## 5. Alternative models, scored against the measured graph

Scoring criteria follow from §1.1. A model is good insofar as it (i) makes closure size
predictable from position — the operative purpose; (ii) makes something *illegal* that is
currently common, because a model that legalises everything explains nothing; and (iii)
legalises something currently awkward.

### (a) The current five-layer model

- **Delivers P3?** Coarsely. Medians separate (16 / 70 / 102) but ranges overlap on 110 of 270
  L2+L3 packages (§4).
- **Makes illegal:** 14 edges of 2 253 — **0.6 %**. Its enforceable content is almost nil, and
  §0.3 shows the 11 genuine ones are all the same misplacement shape, not 11 independent
  mistakes.
- **Makes awkward:** L4 and L5 are 1 realised package and 0. The model's top 40 % is
  reservation. It also has no answer for `swift-foundry` (3 realised packages, unassigned) or
  for `repotraffic`.
- **Verdict:** it is not *wrong*, it is *mostly inert*. Its two live claims — layer orders
  closure size, and downward-only — are true and worth keeping. Everything else is unenforced.

### (b) Three realised layers (drop L4/L5 until built)

- **Delivers P3?** Identically to (a) — nothing changes about the measured graph.
- **Makes illegal:** the same 14 edges. No gain in discriminating power.
- **Makes legal:** nothing new, but it stops L4/L5 names being cited as evidence of existence —
  a documented failure mode (the `swift-jobs` withdrawal; the "65 packages" that were 4).
- **Verdict:** an honest bookkeeping correction, not a model change. **Do it, but do not
  mistake it for an answer.** Note that the reservations are not noise: the 40
  `swift-applications` READMEs describe *executables* (`Doctor` — "Diagnoses development
  environment issues (like flutter doctor)", with a `## Commands` section; `Gateway` — "API
  gateway and edge proxy"). **L5 is not a deeper library layer; it is a different kind of
  artifact.** That distinction is real and should survive whatever happens to the numbering.

### (c) Layer × role as two independent axes — the principal's hypothesis

- **Delivers P3?** No, and this is the objection that sinks it in its strong form. §2.3
  established that role availability is *gated by layer depth*: the `-dependencies` role
  requires `swift-dependencies` (L3), so no L1 or L2 package can take that role without an
  upward edge. Role is **a function of depth, not a free coordinate**. Two axes that are not
  independent are not two axes.
- **Makes illegal:** the structural triple (leaf / composer / thin converger) recurs at every
  layer in near-identical proportions — L1 7.8/92.2, L2 10.5/89.5, L3 7.5/92.5; convergers 34 /
  11 / 28. A rule keyed on those categories therefore forbids nothing anywhere, because they
  are universal.
- **Makes legal:** genuinely a lot — it would name 73 thin convergers and 7 DI-integration
  packages that currently have no vocabulary at all, and it would explain why
  `swift-http-standard` (37 LOC) and `swift-mailgun` (208-package closure) sit at the same
  "layer" without either being a defect.
- **Verdict: half right, and the productive half is real.** Role is not a second *ordering*
  axis. It is a **kind tag** — orthogonal to ordering, and worth having for exactly the reason
  the principal suspected: without it, placement arguments have no vocabulary and get resolved
  by analogy. But it will not carry the layering rules.

### (d) More layers

- **Delivers P3?** Yes — strictly better, since finer bands mean tighter closure prediction.
- **Makes illegal:** a great deal more, by construction.
- **The problem is where to add them.** The evidence says the pressure is *below*, not above:
  L1 holds 204 of 481 packages (42 %) and is internally 19–27 levels deep, while L4+L5 hold one
  realised package between them. Any proposal that adds layers above L3 is adding bands to the
  sparse end of the distribution.
- **Verdict:** correct instinct, wrong direction — and **L1 already did it**, which is the
  finding of §4. The open question is not "should we add layers" but "should the mechanism L1
  invented be generalised".

### (e) Computed depth + declared kind — recommended

Generalise what L1 already proved works, and keep declared labels only where they encode
something depth cannot.

1. **Ordering becomes computed, not declared.** `depth(p) = 0` if no internal deps, else
   `max(depth(d)) + 1`, over library-target edges. Already implemented for L1
   (`validate-package-graph.py`); the extension to 481 packages is arithmetic on data this
   document already produced. Depth is correct by construction, cannot go stale, and *is* the
   closure bound that §1.1 identified as the real purpose.
2. **Declared labels keep only what depth cannot express — kind, not order:**
   - `specification` — mirrors an external issuing authority (90 packages). This is a
     *provenance* claim, not a depth claim, which is why `swift-rfc-2388` at depth 30-something
     is not an anomaly under this model.
   - `vendor-binding` — tracks a third-party API (`swift-stripe*`, `swift-mailgun*`,
     `swift-postgresql-standard`). This is the category that produces 10 of the 11 genuine
     upward edges; naming it dissolves them.
   - `deliverable` — an executable, not a library (the 40 `swift-applications` reservations).
   - `unassigned/tooling` — `swift-foundry`, `repotraffic`, linter-rule bundles. **A model must
     state what it does not govern**; the current one is silent, which is why 3 realised
     packages have no home.
3. **The lateral rule is deleted, not relaxed.** Under computed depth "lateral" is
   arithmetically impossible (§4(2)), so `[ARCH-LAYER-001]`'s unjudgeable clause —
   "essential semantic prerequisite" — stops adjudicating 1 475 edges by vibes.

**What it makes illegal that is currently common:** an edge whose consumer does not strictly
exceed its dependency in computed depth — mechanically checkable, no judgement — plus a
`specification` package depending on a non-`specification` package, which is exactly and only
the `swift-rfc-2388 → swift-html-form-coder` inversion and the two `*-types` clusters. That is
a *smaller* illegal set than (d) but every member is machine-decidable, versus the current
model's 0.6 % enforceable / 65.5 % unenforceable split.

**What it makes legal that is currently awkward:** `swift-mailgun-types` and
`swift-stripe-types` stop being violations and become `vendor-binding` packages at their true
computed depth; `swift-foundry` gets a home; the 73 thin convergers get a name.

### Migration cost

Deliberately low, because most of it is relabelling rather than moving code.

| Step | Cost | Reversible? |
|---|---|---|
| Generalise `validate-package-graph.py` from L1 to all 481 packages | ~1 lane-day; the graph extraction is done and in this document's artefacts | yes |
| Regenerate the stale computed-tiers table and put it in CI (§4 defect) | hours | yes |
| Add a `kind:` field to per-package metadata; backfill 90 specification + ~8 vendor-binding + 40 deliverable | ~1 lane-day, mechanical | yes |
| Rewrite `[ARCH-LAYER-001]` / `[ARCH-LAYER-007]` and the layer sections of `CLAUDE.md` | ~half a lane-day | yes |
| **Package moves required** | **0** | — |

No package changes root. The 11 upward edges are resolved by *labelling*
`swift-mailgun-types` / `swift-stripe-types` as vendor bindings, not by moving them — though
moving them to `swift-foundations/` would also work and is the alternative if a
provenance-based root layout is preferred over a metadata field.

### What would falsify this recommendation

Stated so it can be checked rather than argued:

1. **If computed depth turns out to be unstable** — if adding one ordinary dependency shifts
   many packages' depth — then depth is too brittle to be the public contract. **Check:**
   perturb the measured graph with each of ~50 plausible new edges and measure how many
   packages' depth changes. If the median blast radius exceeds ~5 packages, prefer declared
   bands. *I did not run this; it is the first thing to run before adopting.*
2. **If the purpose is actually P2 (independent releasability)** rather than P3, this
   recommendation is wrong — release boundaries want stable declared names, not a number that
   moves with the graph. **Check:** the ecosystem is branch-pinned today (§1 P2), so this is
   currently unfalsifiable; if version pinning is adopted, re-run §1.
3. **If the 39 Foundation-in-core packages are deliberate**, then P5 is not a layer property at
   all and the purity gradient in §1 is coincidence, weakening the claim that layer position
   carries semantics.
4. **If `kind` labels drift** the way the tier table did (§4 defect), a metadata field is no
   better than the prose it replaces. **Check:** `kind` must be CI-validated against something
   observable (root path, presence of an executable product), not hand-maintained.

---

## 6. Answer to the question as asked

**Is the five-layer model the right one?** It is right about one thing and inert about the
rest. Layer position does predict closure size (medians 16 / 70 / 102, no L1 package above the
L3 median) — that is real and worth preserving. But it enforces 0.6 % of the edges it nominally
governs, its top two layers are 1 realised package and 0, and it has no vocabulary for the
three roles that recur at every layer or for the 3 realised packages it does not cover.

**Does decomposition-then-composition recur at every layer?** **Yes for the structural triple
— leaf, composer, thin converger — measured at all three layers in near-identical proportions,
and currently unnamed.** **No for the specific roles** (`-primitives`, specification,
`-dependencies`, backend variant): those are perfectly layer-segregated and *cannot* recur,
because role availability is gated by what exists beneath you.

**So does that mean more layers?** The pressure is downward, not upward — and **L1 already
built them**, as a computed 19-to-27-level tier DAG that has been running for months without
the ecosystem model acknowledging it. The recommendation is to generalise that mechanism rather
than invent a new one: **compute the ordering, declare only the kind.**

---

## 7. Two late inputs, tested — and one of them changes the recommendation

Both arrived after §1–§6 were written. Both were tested rather than assumed. **The first
bounds my evidence less than feared; the second adds a purpose I missed and revises §5(c).**

### 7.1 The `@_exported` hazard — real, quantified, and it *strengthens* the P3 metric

The concern: a consumer can bind a package's types without naming it in any manifest, so
manifest-derived edge counts are a lower bound on real coupling. Confirmed present at scale —
**3 132 `@_exported` edges across 1 119 re-exporting modules.**

To measure the gap I built a module-ownership map from `Sources/<Target>/` directory names
(**1 592 modules**), collected every `import` in every source file, and classified each
cross-package module import by how the manifest graph accounts for its owner. Regex controls
for both `import` and `@_exported import` spellings PASS.

| Classification | Count | Share |
|---|---|---|
| owner is a **direct** manifest dependency | 2 657 | **94.25 %** |
| owner appears **only in the transitive closure** (the `@_exported` effect) | 149 | 5.29 % |
| owner **not in the closure at all** — a genuine hole | **13** | **0.46 %** |

**The conclusion is sharper than "everything is a lower bound".** `@_exported` inflates
*direct* coupling by ~5.3 %: 149 imports bind types the consumer never named. But
`@_exported` requires a real manifest edge *in the re-exporting package*, so the owner still
lands inside the consumer's transitive closure. **The transitive closure accounts for 99.54 %
of all cross-package module coupling; direct manifest edges account for only 94.25 %.**

This matters directly for §1: **closure size (P3's metric) is nearly immune to the hazard;
direct-edge counting is not.** The instrument this document's central result rests on is the
robust one, and that is an additional argument for it over any model scored by counting edges.

**The 13 holes are real defects, verified individually rather than reported as a number.**

- **3 are undeclared upward edges.** `swift-github-standard` (L2) declares exactly four
  dependencies — `swift-tagged-primitives`, `swift-rfc-3339`, `swift-rfc-3986`,
  `swift-emailaddress-standard` — yet its sources `import Dependencies`, `Dual` and
  `URLRouting`, all owned by L3 packages. **These are L2→L3 upward edges invisible to every
  manifest-derived census, including §0.3's.** So the true genuine upward count is **14, not
  11**: eleven declared, three undeclared.
- **2 are a quarantine artifact, correctly detected.** `swift-executor-primitives` has its
  `swift-heap-primitives` and (for the library target) `swift-clock-primitives` product
  dependencies commented out under a `W5 QUARANTINE (2026-06-11)` marker at
  `Package.swift:66,135`, while `Sources/Executor Job Priority Primitives/` still imports
  `Clock_Primitives` and `Heap_Primitives`. The library target cannot compile as written; only
  a test target retains the dependency.
- The remaining 8 are lateral L3 (`swift-github`, `swift-github-http`, `swift-tests`).

> Instrument caveat, reported rather than buried: Swift's `import typealias Foo.Bar` form
> causes an import-kind keyword to be captured as a module name — **20 occurrences across 13
> packages, 0.49 % of pairs.** None resolve to a module owner, so none produce false holes, but
> the raw import count is polluted by that much.

### 7.2 P6 — "the layer marks who OWNS a semantic domain." **SURVIVES, and it is the second axis**

The maximal-reuse ruling predicts something P1–P5 do not: reuse edges should point at *domain
owners* rather than merely downward, and **lateral edges are expected wherever the correct
owner is a peer.**

**Falsifier:** if the same semantic domain is implemented in more than one package, ownership
is not being enforced and cannot be the operative purpose.

**Verdict: STRONGLY SUPPORTED.** Of **1 592 modules across 481 packages, exactly 2 are claimed
by more than one package — 0.13 %.** Ownership is enforced at a level nothing else in this
document approaches.

And the two collisions are not scattered:

| Colliding module | Claimants | Layers |
|---|---|---|
| `GitHub_OAuth_Types` | `swift-github`, `swift-github-standard` | **L3, L2** |
| `Server_Vapor` | `swift-server-foundation-vapor`, `swift-server-vapor` | L3, L3 |

The first is an **L2/L3 vendor-binding duplication** — the *same cluster* that produced the
upward edges (§0.3), the closure-stratification outliers (§1 P3), and the undeclared upward
edges (§7.1). **Four independent tests now converge on one group of packages.** That is no
longer a coincidence; it is a diagnosis: **vendor bindings have no correct home in this model,
and every instrument aimed at the graph finds them.**

**P6 also gives a better diagnosis of `swift-rfc-2388` than P3 does — and this is the part that
changes my conclusion.** Under P3 the edge `swift-rfc-2388 → swift-html-form-coder` is a
violation because it inflates a closure to 164. Under P6 the fault is named precisely:
`swift-rfc-2388` owns module `RFC_2388` and imports `HTML_Form_Coder`, `HTML_Form_Coder_Nested`
— but **RFC 2388 *is* the owner of `multipart/form-data` semantics**, and `swift-html-form-coder`
is an implementation of them. The dependency runs from owner to consumer. **The arrow is
backwards, not merely long.** P6 diagnoses direction-of-ownership; P3 only measures size. That
is a strictly more useful finding, and it is what a reviewer actually needs to be told.

Note also that L2 owners of form semantics *do* exist — `swift-whatwg-html` owns
`WHATWG_HTML_FormData`, `swift-whatwg-url` owns `WHATWG_Form_URL_Encoded` — so the upward edge
is not forced by absence of a peer owner.

### 7.3 What this does to §5(c) — the principal's two-axis hypothesis, revised

**§2.3 rejected *role* as a second axis, and that rejection stands** — role availability is
gated by depth, so role is a function of depth, not a free coordinate.

**But the principal was right that there is a second axis. It is ownership, not role.**

- **Ownership is genuinely independent of depth.** Who owns `multipart/form-data` is not a
  function of how deep the owner sits. Two packages at the same depth can own different
  domains; one package can own a domain whose consumers span every layer
  (`swift-index-primitives`: 62 consumers).
- **Ownership explains what depth cannot: the lateral edges.** §3 showed 39.1 % lateral outside
  the floor and offered no positive account of *why* those edges are legitimate.
  P6 supplies it: **reuse-the-correct-owner-per-domain produces peer edges by construction.**
  A lateral edge is not a tolerated compromise — under P6 it is the *expected* shape whenever
  the correct owner is a peer, which is exactly what `[ARCH-LAYER-001]`'s unjudgeable
  "essential semantic prerequisite" clause was groping toward.
- **The two axes answer different questions.** Depth answers *how much must I take on?*
  (P3, closure bound). Ownership answers *am I depending on the right thing?* (P6, correctness
  of the target). The current model conflates them into one word — which is precisely the
  principal's suspicion, arriving at a different second axis than the one hypothesised.

**Revised recommendation — §5(e) amended.** "Compute the ordering, declare only the kind"
becomes:

1. **Compute the ordering** (depth, from the graph) — unchanged, delivers P3.
2. **Declare the ownership** — each package declares the semantic domain(s) it owns. This is
   *already de facto true and 99.87 % enforced*; it is simply not written down anywhere or
   checked. Making it explicit turns the maximal-reuse ruling from a prose obligation into a
   machine-checkable one: **a module may be declared by exactly one package**, and **a
   specification package may not depend on an implementation of the domain it owns.**
3. **Declare the kind** (specification / vendor-binding / deliverable / tooling) — unchanged,
   but now demoted to a *tag*, because ownership does the work I had assigned to kind.

The added enforceable content is significant and needs no judgement: **module-ownership
uniqueness catches 2 live collisions**, and **owner-to-implementation inversion catches
`swift-rfc-2388`** — neither of which the depth rule can see, and neither of which the current
model expresses at all.

**Additional falsifier for P6**, in the same form as §5's: if the 2 collisions turn out to be
deliberate (a sanctioned shim or migration shadow rather than duplicated ownership), then
ownership uniqueness is a convention nobody is actually enforcing, and P6 degrades from an
invariant to a habit. **Check:** ask the principal whether `GitHub_OAuth_Types` in both
`swift-github` and `swift-github-standard` is intentional. I did not resolve this and it should
not be assumed either way.

### 7.4 On the lead's question: is "outside the model" one category or several?

It is **at least two, and they differ on the property that matters**.

- **`swift-foundry`** (3 realised packages: `swift-control-plane`, `control`, `foundry`) is
  control-plane tooling that **participates in the dependency graph** — it is a consumer of
  ecosystem packages, so depth and ownership both apply to it. It is unassigned because the
  model has no *kind* for it, not because it is outside the graph.
- **Lint-rule bundles** are build-time tooling that **inverts the graph on purpose**:
  `swift-primitives-linter-rules` (L1) and `swift-standards-linter-rules` (L2) both depend on
  `swift-institute-linter-rules` (L3), producing 3 of the 14 upward edges. The
  `primitives/SKILL.md` note is explicit that the Foundation rule is *"placed at institute tier
  rather than primitives tier so `Bundle.institute` consumers at L2/L3 also receive the rule"*
  — the inversion is the design.

So: `swift-foundry` needs a **kind** and is otherwise fully governed. Lint bundles need a
genuine **scope boundary**, because they deliberately violate the ordering the model exists to
enforce. Collapsing the two would either wrongly exempt `swift-foundry` from rules it should
obey, or wrongly subject lint bundles to an ordering they are designed to invert. **A model
that says what it does not govern needs at least these two doors, and they are different
doors.**

### 7.5 A worked example that validates §2.1 and §7.2 — the IP-address "two owners" question

The certificates lane asked which family canonically owns IP addresses —
`swift-rfc-791`/`swift-rfc-4291`, or `swift-ipv4-standard`/`swift-ipv6-standard` — on the
premise that consuming `swift-rfc-5280` (which uses the `-standard` family) alongside a fork
that uses the spec family would put **two IPv4 and two IPv6 owners in one graph**.

**The premise is false, and the taxonomy in §2.1 is why.** Both `-standard` packages are single
file and were read in full:

- `swift-ipv4-standard` (59 LOC): `@_exported import RFC_791` plus
  `public typealias IPv4 = RFC_791.IPv4`.
- `swift-ipv6-standard` (68 LOC): `@_exported import RFC_4007 / RFC_4291 / RFC_5952` plus
  `public typealias IPv6 = RFC_4291.IPv6`.

**`IPv4.Address` and `RFC_791.IPv4.Address` are the same nominal type.** The `-standard`
packages are **thin convergers** — the role measured at all three layers (73 packages, §2.1) —
and they own nothing. §7.2's ownership measurement agrees: 1 592 modules, 2 collisions, and IP
is not among them. **Owners: `swift-rfc-791` owns IPv4, `swift-rfc-4291` owns IPv6.** One owner
per domain, exactly as P6 predicts.

An asymmetry worth recording: **IPv4 is an alias, IPv6 is a superset bundle.**
`swift-ipv4-standard` re-exports one package; `swift-ipv6-standard` re-exports three, adding
RFC 4007 scoped addresses and RFC 5952 canonical text representation on top of the RFC 4291
address type. Depending on the converger is therefore not capability-neutral in the IPv6 case.

**Neither family carries prefix/CIDR/subnet containment, and no package in the census does.** A
symbol sweep across all five candidate packages returns zero declarations matching
`Prefix|CIDR|Subnet|Mask|contains` (positive control: the same sweep finds `enum IPv4` and
`struct Address` in `swift-rfc-791`). The only textual hits are comments —
`swift-ipv4-standard` lists *"RFC 4632: CIDR"* under "Future extensions", and one RFC 791 doc
comment mentions CIDR historically. `swift-rfc-4632`, `swift-rfc-6890` and `swift-rfc-4193` do
not exist as packages.

Two consequences: **RFC 5280 §4.2.1.10 name-constraint ranges have no owner to delegate to**,
and the `-standard` family cannot have been chosen for a prefix capability it does not have.

This is also a live instance of the §7.1 hazard, and the only one among the six packages
examined: `swift-rfc-4291` has manifest in-degree **5** but by-import in-degree **6** —
`swift-whatwg-url` binds `RFC_4291` types through the closure without naming the package.

### 7.6 The 2 ownership collisions, resolved by reading the source — P6 is *stronger* than §7.2 reported

Both were checked in source rather than escalated. **One is an artifact of my instrument; one is
a real, live defect.**

**`GitHub_OAuth_Types` — my instrument's error.** `swift-github/Sources/GitHub OAuth Types/` is
an **empty directory**: 0 files of any type, and no matching target in `Package.swift`. My
ownership map was built from `Sources/<dir>` names and counted it as a module claim. It is not a
module. The real `GitHub_OAuth_Types` (2 files, 51 LOC) exists only in `swift-github-standard`.
**No collision.**

Re-running the map with directories containing zero `.swift` files excluded (injected-duplicate
control PASSES): **1 554 modules, 39 excluded directories** — most of which are legitimate C
shim targets carrying headers rather than Swift (`CISO9899Ctype`, `CIEEE754`, `CARMShim`, …),
the rest genuinely empty.

**Corrected ownership figure: 1 collision in 1 554 modules — 0.064 %, i.e. 99.936 % enforced.**
P6 holds harder than §7.2 claimed, not less hard.

**`Server_Vapor` — a real collision, and a live defect rather than a modelling problem.**
`swift-server-foundation-vapor` and `swift-server-vapor` (both L3) each ship a directory
literally named `Server_Vapor`, each with **20 `.swift` files**, and `diff -rq` reports **0
differing files** — the module is byte-identical in both. Both manifests bind the same target
name (`static let serverVapor: Self = "Server_Vapor"`), and both repositories carry the same
last commit, same date (2026-07-20), same message. This has the shape of a **package rename that
was started and never finished**, leaving two publishers of one module. If both ever enter one
dependency graph the build breaks on a duplicate module name.

**Verdict: P6 is not degraded.** The one true collision is not a case of the ecosystem tolerating
divided ownership — it is one package duplicated, which is a defect the *proposed* uniqueness
rule would have caught at the moment it was created. That is an argument for the rule, not
against it.

### 7.7 Depth blast-radius — the falsifier I named, now run. **Depth survives.**

**Method.** Perturb the measured graph with one plausible new edge at a time; recompute every
package's depth; count how many changed. "Plausible" = consumer already has dependencies, target
already has consumers, the pair is not already an edge, and the edge would not create a cycle.
Seeded (`20260724`) and reproducible.

Controls, both **PASS**: depth recomputation on the unperturbed graph is deterministic; and an
edge to a strictly-shallower target (`Issues` d=8 → `control` d=1) has blast radius **0**, as the
arithmetic requires.

**Headline, 50 mixed samples: median 0, p25 0, p75 1, max 278; 60 % of edges change nothing.**
Against the stated falsifier — *median > ~5 means depth is too brittle to be a public contract* —
**median 0. Not falsified.**

Decomposing by the kind of edge added (n=60 each) makes the result much sharper:

| Kind of added edge | median | p75 | p90 | max | zero-blast |
|---|---|---|---|---|---|
| target **shallower** than consumer — ordinary reuse | **0** | 0 | 0 | **0** | **100 %** |
| target at **equal** depth — peer/lateral addition | 1 | 3 | 26 | 425 | 0 % |
| target **deeper** than consumer — inversion | 2 | 4 | 35 | 278 | 0 % |

**Depth is perfectly stable under the edges people actually add.** Reusing something below you —
which is what the ecosystem does 764 times downward and, per §7.3, what reuse-the-correct-owner
produces — moves nothing, in 60 of 60 samples. Instability appears *only* for lateral and
inverted additions: precisely the edges the model exists to scrutinise. **The metric is quiet
exactly where the ecosystem is healthy and noisy exactly where it is not**, which is the
behaviour you want from a diagnostic.

**But the tail is heavy and must be stated.** A single lateral edge reached **425 of 481
packages** (88 %); the worst inversion, `swift-span-primitives` (d=10, 23 consumers) →
`swift-bit-vector-primitives` (d=12), shifted **278**. High-fan-in shallow packages are the
amplifiers — `swift-standard-library-extensions` (65 consumers, depth 0), `swift-index-primitives`
(62, depth 9), `swift-byte-primitives` (60, depth 7).

**Amendment to §5(e), which the data forces.** Distinguish two uses of depth that §5(e)
conflated:

- **Depth as a *check*** — "does the consumer's depth strictly exceed its dependency's?" — is
  robust by construction and cannot fail spuriously; blast radius is irrelevant to it. **This is
  what §5(e) should say, and it is what the recommendation rests on.**
- **Depth as a *published label*** — "this package is level 12" — is **not** safe. One ordinary
  lateral addition can renumber most of the ecosystem. **Do not publish depth numbers as stable
  identifiers**, and do not let consumers pin against them.

So the recommendation stands, with its scope narrowed: **compute depth and check against it;
declare ownership and kind as the stable, publishable facts.** Ownership is the right thing to
publish precisely because it does not move when the graph does.

### 7.8 Correction — orphaned source. §7.1's holes were mostly my instrument, and two of my findings are withdrawn

The census lane refuted my three "undeclared upward edges" and was right. **The cause was a
systematic error in my instrument, and correcting it changes several numbers in §7.1 and §7.6 —
all in the direction of *fewer* findings.**

**The error.** I built the module-ownership map and the import scan from `Sources/<dir>` **directory
names**. SwiftPM compiles **targets**, not directories. A directory that no declared target claims
is source that ships in no product and compiles nowhere. **Attributing imports to a directory
counts dead source as a dependency edge.**

**Verified independently of my parser**, in `swift-standards/swift-github-standard`:
`Package.swift:39-56` declares exactly **two** targets (`GitHub Standard`, `GitHub Standard Tests`);
`Sources/` holds **eight** directories. The `Dependencies` / `Dual` / `URLRouting` imports live in
three undeclared ones. Inside the declared target: **zero** such imports — with the control firing
at **24** import lines across its 91 files. Manifest and compiled reality agree; only dead source
disagreed.

**Instrument rebuilt to be target-aware** (declared-target parser, controls PASS on direct names,
`static let` alias names, orphan directories, and commented-out target declarations). One further
false-positive class had to be fixed first: `swift-mailgun-types` and `swift-mailgun-live` name
targets by **suffix chain** — `static let reporting: Self = "Mailgun Reporting".types`, with
`var types: Self { self + " Types" }` at `Package.swift:399-402`. My first pass read those 19
directories as orphaned. Only 2 of 481 manifests use the form; both are now resolved (control:
`Mailgun Reporting Types` resolves to a declared target, PASS). **Cross-checked by a second
probe of different scope** — a sweep of six org roots at any depth, `.build*` filtered —
returning the same **2**.

**Corrected figures — declared targets only:**

| Measure | by directory (§7.1/§7.6) | **by declared target** |
|---|---|---|
| modules | 1 554 | **1 528** |
| ownership collisions | 1 | **1** (`Server_Vapor`, unchanged) |
| imports: owner is a direct dep | 2 657 (94.25 %) | 2 652 (**94.68 %**) |
| imports: owner only in closure | 149 (5.29 %) | 147 (**5.25 %**) |
| imports: owner **not** in closure | **13 (0.46 %)** | **2 (0.07 %)** |
| closure accounts for | 99.54 % | **99.93 %** |

**The `@_exported` result gets stronger, not weaker.** Eleven of thirteen holes were dead source.
The two survivors are both the module name `Testing` (`swift-tests`, `swift-testing-performance`)
— and `swift-foundations/swift-testing` vends `.library(name: "Testing")`, the same module name the
toolchain-bundled `apple/swift-testing` vends. **My owner map cannot distinguish an institute
module from a toolchain module of the same name, so these are unresolved, not confirmed holes.**
The defensible statement is: **the transitive closure accounts for between 99.93 % and 100 % of
attributable cross-package coupling.**

**Two findings withdrawn.**

1. **The three undeclared L2→L3 upward edges in `swift-github-standard` are withdrawn.** They are
   dead source. **The genuine upward count is 11 declared, not 14** — and §7.2's "four converging
   instruments" is really three, since this was one of them. The remaining three (upward edges,
   closure outliers, ownership) still converge on the same vendor-binding cluster.
2. **The `swift-executor-primitives` "live build defect" reported to the lead is withdrawn — it was
   my error and the opposite of what I claimed.** `Executor Job Priority Primitives` is **not a
   declared target**; it is the package's single orphaned directory. The `W5 QUARANTINE
   (2026-06-11)` treatment is *internally consistent*: the target declaration and its product
   dependencies were both removed together, leaving only source on disk. Nothing fails to compile.

**Orphaned directories ecosystem-wide: 43, of which 26 contain Swift files** (target-aware,
suffix-chains resolved). The census lane reports 154 / 109; we differ by roughly 4×, most likely in
target-name resolution, and that discrepancy is unresolved.

**Shared rule adopted, in the census lane's words: attribute imports to a target, never to a
directory. A file in no target is not a dependency edge.** Every by-directory figure earlier in
this document should be read as superseded by this section.

**What survives unchanged:** P6 (1 collision in 1 528 declared modules — 0.065 %), the depth
blast-radius result (§7.7, which uses manifest edges only and never touched source directories),
and the closure-over-direct-edges argument, which this correction strengthens.

### 7.9 Two further corrections: a third alias form, and a stale premise in §7.5

**(a) The 42 unattributed declarations, audited — and a third alias spelling found.**

The audit answers the open question from §0.3 cleanly: **none of the 42 is an upward edge.** 35 of
42 carried a `package: "…"` product reference elsewhere in their manifest, meaning the attributor
saw the product but could not tie it to a target.

Root cause, found in `swift-ietf/swift-rfc-791/Package.swift:10-16`: a **third alias spelling** my
parser did not recognise —

```swift
static let byteSLI = Self.product(name: "…", package: "swift-byte-primitives")
```

`static let`, no `: Self` annotation, assignment rather than a computed `{ … }` body. This is the
same *family* of defect as the census lane's `_const_map()` bug (which skipped constants containing
`(`), in a different spelling. Parser extended; control PASSES on both `static let x = Self.product(…)`
and `static let x: Self = .product(…)`.

**Result: unattributed 42 → 9. The upward set is unchanged — still the same 14, still 11 outside the
lint carve-out.** So my 11 was not an undercount, and the instrument is now confirmed stable against
its own known blind spots.

The residual **9 are genuine declared-but-unused dependencies** — declared in the top-level
`dependencies:` array and referenced by no target (e.g. `swift-async` declares `swift-dependencies`
at `Package.swift:41`; no target consumes it). That is manifest hygiene, not a parser gap.

**(b) §7.5's premise was stale — and the workspace moved under the snapshot.**

§7.5 accepted, from the question as posed, that `swift-rfc-5280` uses the `-standard` family. **It no
longer does, and the conclusion §7.5 reached had already been reached independently by the rfc-5280
lane.** Its manifest now reads:

```
//    The IP address owners are the RFC packages themselves; the
//    `-standard` umbrellas over them are re-export shims, so depending
//    on them would be an edge to a re-export rather than to the owner.
.package(url: "…/swift-rfc-791.git", branch: "main"),
.package(url: "…/swift-rfc-4291.git", branch: "main"),
```

Its target consumes `RFC 791` and `RFC 4291` directly, and its sources carry exactly one
`import RFC_791` and one `import RFC_4291` and no import of either `-standard` module. **Two lanes
reached the same owner conclusion by different routes, and the manifest comment states §7.5's
finding in the manifest itself.**

**Snapshot drift, measured rather than assumed:** comparing manifest mtimes against the snapshot
time (22:04:56), **exactly 1 of 481 manifests changed** — `swift-rfc-5280`, at 22:30:58. The change
swaps two L2→L2 lateral edges for two others, so no headline figure moves (lateral stays 1 475,
upward stays 14). **But the general hazard is real and worth stating: every graph figure in this
document is a snapshot of a live workspace, and one manifest did change beneath it.** The
`swift-rfc-5280 → swift-ipv4-standard / swift-ipv6-standard` edges in the edge table are stale.

**A correction to §7.5's CIDR claim.** §7.5 stated that §4.2.1.10 name-constraint ranges "have no
owner to delegate to". That over-reached: the sweep covered the five *candidate address* packages
but not `swift-rfc-5280` itself, which **implements the containment law directly** —
`RFC_5280.NameConstraints.IPAddress` declares `case v4(base:mask:)` / `case v6(base:mask:)` and
`public func contains(_:) -> Bool` for both families. The accurate statement is narrower and
unchanged in its practical effect: **no *general-purpose* CIDR/prefix package exists** (`swift-rfc-4632`,
`swift-rfc-6890`, `swift-rfc-4193` are absent), and RFC 5280 owns its own base+mask constraint form
rather than delegating it — which under P6 is correct, since §4.2.1.10 *is* RFC 5280's semantics.

### 7.10 Orphan count reconciled — the last open discrepancy, closed

§7.8 left one figure disputed: I counted **43** orphaned directories (26 with Swift files), the
census lane **154** (108). Reconciled by comparing denominators:

| Scope | census lane | this lane |
|---|---|---|
| under `Sources/` | 44 dirs / 25 with `.swift` | **43 / 26** |
| under `Tests/` | 110 / 83 | *not measured* |
| total | 154 / 108 | — |

**The entire ~4× gap was `Tests/`.** Restricted to `Sources/`, two independently written probes
agree to **within one directory in each direction** — a residual worth neither lane's time to
chase. Depth was not a factor: both take immediate children only. The census lane's brief
mandates censusing `Tests/` alongside `Sources/`; **both figures are correct for their scope and
neither should be quoted without it.** For the shared orphan-exclusion rule, the `Sources/`
figure is the relevant one.

(The census lane also corrected its own 109 → **108** in the process: a raw `os.walk` that did
not prune `.build*` had admitted one directory.)

**The suffix-chain trap was hit by both lanes from opposite ends.** Their first parser captured
the leading literal of `static let mailgun: Self = "Mailgun".types` and produced `"Mailgun"` — a
plausible name pointing at a directory that does not exist, caught by a residual check. Mine
resolved the constant but not the suffix, so it read 19 real directories as orphans. **Same
defect, one at parse time and one at ownership time, found independently.**

### 7.11 What this document's errors have in common

Four false findings were produced today across two lanes from **one root cause**, and all four
came from the same single file:

| Finding | Lane | Cause |
|---|---|---|
| 3 undeclared L2→L3 upward edges | this lane | source attributed by directory |
| `swift-executor-primitives` "cannot compile" | this lane | source attributed by directory |
| `@_exported import Foundation` shipping to consumers | census lane | source attributed by directory |
| (all three sites) | both | a file in no target treated as live code |

**The adopted rule, in the census lane's words: *attribute imports to a target, never to a
directory. A file in no target is not a dependency edge.*** SwiftPM compiles targets. A
directory that no target claims is dead source: it ships in no product, it binds no types, and
it constrains nothing. **This is the single most transferable output of this review**, and it
generalises past layering to every census this workspace runs.

A second, narrower lesson worth carrying: **three distinct alias spellings for manifest
dependencies exist in this ecosystem**, and each one silently attributes to nothing in a probe
that does not know it —

```swift
static var dual: Self { .product(name: "Dual", package: "swift-dual") }     // computed body
static let byteSLI = Self.product(name: "…", package: "swift-byte-…")      // assignment, no annotation
static let reporting: Self = "Mailgun Reporting".types                      // suffix chain (target names)
```

Between the two lanes these three forms accounted for a 5× error in one probe (36 → 176 core
targets in a Foundation-integration closure), a 19-directory false-orphan set in another, and 42
unattributed declarations in a third. **A manifest probe that has not been tested against all
three should be assumed wrong.**

---

## Appendix — provenance

All figures produced 2026-07-24 by this lane. Primary instrument:
`<workspace>/swift-institute/Scripts/eco-probe.sh` (`selftest` 9 passed / 0 failed, six
degenerate-case controls failing loud at exit 2). Hand-written instruments — target attributor,
closure/depth calculator, cycle detector, Foundation scanner — each carry their own positive
and negative controls, reported inline beside the numbers they produce.

Two errors caught *in this lane's own instruments* and corrected before publication, recorded
because the correction is part of the evidence: (1) `^\s*@_exported\s+import` silently missed
the live `@_exported public import` spelling and reported 0 re-exports for a package that has
3; (2) naive suffix matching classified `swift-time-to-live` as a `-live` variant and
`swift-memory` as a `-memory` backend — 2 false positives in 6 matches.

A third instrument caveat, from §7: Swift's `import typealias Foo.Bar` form causes an
import-kind keyword to be captured as a module name — 20 occurrences, 0.49 % of pairs, none
resolving to an owner and so producing no false findings.

Figures corrected relative to the brief that commissioned this lane: **genuine upward edges
14 — eleven declared in manifests, three (`swift-github-standard` → `swift-dependencies`,
`swift-dual`, `swift-url-routing`) undeclared and invisible to any manifest-derived census —
against a brief figure of "2, of which 1 genuine"**; census 481 realised packages over 22
roots (639 directories, 158 reserved).

**Section 7 was added after §1–§6 and revises §5(c).** Both late inputs were tested rather than
accepted: the `@_exported` hazard is real but bounds direct-edge counting, not the closure
metric this document's central result rests on; and P6 (ownership) survives its falsifier at
0.13 % violation across 1 592 modules, supplying the second axis the principal suspected — an
axis of *ownership*, not of *role*.

