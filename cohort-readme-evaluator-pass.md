---
date: 2026-05-01
status: RECOMMENDATION
tier: 2
scope: cross-package
---

# Cohort README Evaluator Pass — swift-primitives 0.1.0

## Issue

The four swift-primitives 0.1.0 cohort READMEs (`swift-carrier-primitives`, `swift-tagged-primitives`, `swift-ownership-primitives`, `swift-property-primitives`) share a recurring failure mode named **audience inversion**: author-side context (release-process state, design rationale for rejected alternatives, future-proposal speculation, internal workaround reasoning, ecosystem-convention framing) leaks into prose meant for evaluators answering *"do I want to use this?"*

Carrier (the pilot, post-cleanup 2026-04-29) demonstrates the right discipline; the other three drifted in different specific instantiations. The principal flagged this as a recurring pattern after the per-paragraph removal of ownership's `## Design choices` section on 2026-05-01.

## Provenance

- **Discussion artifact**: `/tmp/cohort-readme-pattern-converged.md` (3-round Claude/ChatGPT collaborative discussion, 2026-05-01).
- **Discussion transcript**: `/tmp/cohort-readme-pattern-transcript.md`.
- **Memory**: `feedback_readme_evaluator_audience.md` — durable rule for future README authoring.

## Verdict taxonomy

Per-paragraph verdicts for the cleanup pass:

| Verdict | Meaning |
|---|---|
| **KEEP** | Directly answers what it does, why to use it vs alternatives, or how usage looks. |
| **COMPRESS** | Contains evaluator value but is mixed with author reasoning; rewrite to canonical form. |
| **RELOCATE** | Useful for contributors / research traceability / DocC deep dives, but not for README adoption — move to Research/ or DocC. |
| **DELETE** | Obsolete, duplicative, speculative, or non-load-bearing for adoption. |

## Six surface patterns

The audience-inversion failure expresses through six distinct surface patterns enumerated in this audit:

1. Pre-tag interim / release-process notes
2. Sibling-package taxonomy paragraphs (rationale-shaped, not decision-aid-shaped)
3. Stability sections mixing evaluator SemVer with internal workaround rationale
4. Exhaustive negative documentation (enumerative absences with research citations in README prose)
5. Ecosystem-convention framing in feature bullets ("matching the convention where…")
6. Quick Start examples using unreleased downstream packages or contributor-provenance signals

## Canonical rewrites

| Pattern | Bad shape | Good shape |
|---|---|---|
| Peer comparison | "two-class taxonomy and the reasons for keeping them separate are documented at..." | "Use Property<Tag, Base> for accessor namespaces on a base value. Use Tagged<Tag, RawValue> for domain-typed raw values." |
| Stability | "Migration to stdlib SE-0519 will proceed through a four-step deprecation plan…" | 3-row table: Public type names / Documented initializers / Internal strategy not-committed |
| Deliberate absences | 200-word enumeration with 20 research/experiment links | 1 sentence + link to single catalogue |
| Feature bullet | "matching the ecosystem convention where conformances live with the protocol's home package" | "Capability-protocol conformances are supplied by the packages that define those protocols." |
| Quick Start | `import Buffer_Ring_Inline_Primitives` (unreleased) + "verbatim from a downstream consumer" | Self-contained example using only the package + stdlib (or minimal local declaration) |

---

## swift-carrier-primitives (control — audited, no edits)

**Public commit**: `d54cf79`. **README**: 126 lines.

| # | Section / Paragraph | Verdict | Rationale | Action |
|---|---|---|---|---|
| 1 | Title + status badge | KEEP | Required inventory per [README-001]. | None |
| 2 | One-liner ("Unified super-protocol for phantom-typed value wrappers — `Carrier<Underlying>` spans Cardinal, Ordinal, Hash.Value, Tagged, and move-only resource wrappers across all four `Copyable × Escapable` quadrants.") | KEEP | Answers "what does this do?" precisely; compact; named the four-quadrant scope. | None |
| 3 | Quick Start: User.ID example | KEEP | Self-contained, runnable, motivated per [README-024]. Demonstrates Carrier conformance shape. | None |
| 4 | Quick Start: File.Handle ~Copyable example | KEEP | Demonstrates a shape `RawRepresentable` cannot express — earns its complexity. | None |
| 5 | Quick Start closing: "Both `User.ID` and `File.Handle` reach `some Carrier<UInt64>` …" + DocC pointers | KEEP | Reader-intent DocC pointers (Conformance Recipes, Carrier vs RawRepresentable). | None |
| 6 | Installation | KEEP | Standard inventory item. | None |
| 7 | Architecture (3-product table + Foundation-free) | KEEP | All three rows answer a consumer import question per [README-010] sub-rule. | None |
| 8 | Platform Support | KEEP | Standard inventory item. | None |
| 9 | License | KEEP | Required inventory item. | None |

**Control attestation**: Carrier's README is fully evaluator-shaped post 2026-04-29 cleanup. No section carries audience-inversion content; no [README-016]-prohibited material; no Stability section but the development-status badge is sufficient given the small surface and the package's lack of consumer-facing implementation gotchas. **No edits required.**

---

## swift-property-primitives

**Public commit**: `0d6b11b` (parentless single commit, 2026-05-01). **README**: 138 lines.

| # | Section / Paragraph | Lines | Verdict | Rationale | Action |
|---|---|---|---|---|---|
| 1 | Title + status + CI badges | 1–4 | KEEP | Required inventory. | None |
| 2 | One-liner ("Fluent accessor namespaces — `base.namespace.method(_:)` …") | 6 | KEEP | Answers "what does this do?"; lists scope (collections, parsers, I/O sessions, configuration contexts). | None |
| 3 | Property-vs-Tagged taxonomy paragraph ("`Property` is a **verb-namespace phantom wrapper** … the reasons for keeping them as separate primitives are documented in [Phantom-Tag-Semantics] and [property-tagged-semantic-roles]") | 8 | COMPRESS | Drifts from decision-aid into rationale-and-research-citations. The reader's adoption decision needs the disambiguation, not the taxonomy framing. | Rewrite as 1-sentence decision aid: "Use `Property<Tag, Base>` for accessor namespaces on a base value (this package); use `Tagged<Tag, RawValue>` for domain-typed raw values (sibling `swift-tagged-primitives`)." Drop the "two-class taxonomy" framing and the canonical-research link from README prose. |
| 4 | Key Features (4 bullets) | 12–17 | KEEP | All four bullets state capabilities; no ecosystem-convention framing; evaluator-shaped throughout. | None |
| 5 | Quick Start "Using Property on a downstream base type" — `import Buffer_Ring_Inline_Primitives` example | 23–42 | DELETE | `Buffer_Ring_Inline_Primitives` has no public release; the import will not compile for a reader copying the example. The framing "Call-sites verbatim from a downstream container package built on `Property.View`" is contributor provenance, not consumer guarantee. Per [README-024], examples must be runnable. | Delete entirely. The "Adopting Property" subsection (#6) becomes the Quick Start. |
| 6 | Quick Start "Adopting Property on your own base type" prose | 46–48 | KEEP | Names the adoption recipe (one phantom Tag, one accessor property, one extension block) in evaluator-shaped form. | Move up to lead Quick Start. |
| 7 | Quick Start Tutorial pointer ("The **Getting Started** tutorial walks through the declaration one tag at a time, builds a `Stack<Element>` …") | 50 | COMPRESS | Currently a tail sentence after #6. Promote to lead the worked example: a minimal Stack declaration excerpt + call-site, then the Tutorial pointer. | Replace #5's slot with a self-contained Stack<Element> excerpt (one accessor — `push.back` — plus the call-site shape) followed by "See the Getting Started tutorial for the full Stack with `peek` and `pop`." |
| 8 | Installation snippet (umbrella + narrow variant guidance) | 56–77 | KEEP | Standard inventory; the "narrow product for compile-time surface" guidance is an evaluator-shaped trade-off note. | None |
| 9 | Architecture ASCII diagram + 7-row product table | 81–106 | COMPRESS | Per [README-010] sub-rule, every row must answer a consumer dependency / import / capability / adoption question. Of the 7 rows: `Property Primitives Core` is internal-no-product (contributor info); `Property Primitives Test Support` is test-only (consumer-relevant but at lowest priority). The ASCII diagram itself shows the variant decomposition along an evaluator-relevant axis (~Copyable RO/RW, Copyable, etc.) and earns its place. | Trim table to 5 rows (umbrella + 4 variant products) + retain Test Support as a footnote. The ASCII diagram stays. The internal Core row moves to a footnote: "Internal `Property Primitives Core` target hosts the `Property` type; not a public product." |
| 10 | Platform Support table | 110–118 | KEEP | Standard inventory. | None |
| 11 | Documentation section (5 DocC article bullets) | 122–132 | COMPRESS | 5 articles is a TOC, not reader-intent links. Per [README-023] decision test: the reader picking between articles wants the two highest-leverage entry points. | Trim to 2 reader-intent links: "Getting Started" tutorial (the seven-minute walkthrough) and "Choosing a Property Variant" (the decision matrix). The other three articles (CoW-Safe Mutation Recipe, Phantom Tag Semantics, ~Copyable Base Patterns) reachable via the umbrella DocC landing page; the Quick Start already references them implicitly. |
| 12 | License | 136–138 | KEEP | Required inventory. | None |

**Property summary**: 1 DELETE (broken Quick Start), 4 COMPRESS (taxonomy paragraph + Quick Start restructure + Architecture trim + Documentation trim), 7 KEEP. Single follow-up commit on `0d6b11b`.

---

## swift-tagged-primitives

**Public commit**: `3686e7c`. **README**: 198 lines.

| # | Section / Paragraph | Lines | Verdict | Rationale | Action |
|---|---|---|---|---|---|
| 1 | Title + status badge | 1–3 | KEEP | Required inventory. | None |
| 2 | One-liner | 5 | KEEP | Answers "what does this do?"; quantifies scope (`Index<Element>`, `Cardinal`, `Ordinal`, `Hash.Value`); names the ~Copyable/~Escapable extension. | None |
| 3 | Fork-from blockquote (heritage note + "Forked from: what heritage means at the Swift Institute" link) | 7 | KEEP | Per [README-025], parent relationships with load-bearing comparison are permitted (swift-crypto / Apple CryptoKit precedent). The fork-as-heritage shape is genuinely consumer-relevant for evaluators choosing between this package and pointfreeco/swift-tagged. | None |
| 4 | Key Features bullets — 5 evaluator-shaped bullets | 12–18 (excl. line 17) | KEEP | Zero-cost phantom discrimination, operator non-forwarding, Universal `Tag: ~Copyable & ~Escapable`, ~Copyable RawValue, Carrier cascading conformance — all capability statements. | None |
| 5 | Key Features bullet 5 (`Ownership.Borrow.Protocol` conformance) ending: "matching the ecosystem convention where conformances of Tagged to non-stdlib capability protocols live with the protocol's home package (see `swift-ordinal-primitives` for the same pattern with `Ordinal.Protocol`)" | 17 | COMPRESS | The capability statement (Tagged is Ownership.Borrow.Protocol when RawValue is) is evaluator-shaped. The "matching the ecosystem convention" framing is contributor doctrine. | Rewrite as: "**`Ownership.Borrow.Protocol` conformance** — `Tagged<Tag, RawValue>` is `Ownership.Borrow.Protocol` when `RawValue` is; `Tagged.Borrowed` resolves to `RawValue.Borrowed`. The conformance is supplied by `swift-ownership-primitives` (the package that declares the protocol)." |
| 6 | Quick Start Domain-identity (User.ID / Order.ID) | 24–40 | KEEP | Self-contained, motivated, demonstrates phantom discrimination at compile time. | None |
| 7 | Quick Start ~Copyable indices example | 44–58 | KEEP | Self-contained, motivated, demonstrates the ~Copyable extension. | None |
| 8 | Quick Start `retag()` example + Property contrast paragraph | 64–74 | COMPRESS | The `map`/`retag` capability demonstration is evaluator-shaped. The trailing parenthetical "(Contrast: the sibling `Property<Tag, Base>` type … retagging `Push` to `Pop` would be semantically nonsensical. The `Phantom Tag Semantics` DocC article in this package's catalog details the two-role taxonomy.)" drifts from decision-aid into taxonomy. | Tighten the contrast to: "(Contrast: `Property<Tag, Base>` in `swift-property-primitives` uses the tag as a verb namespace, not a domain identity — retagging makes no sense there.)" — drop the "two-role taxonomy" reference. |
| 9 | Quick Start `Tagged.map` typed-throws example | 75–101 | KEEP | Demonstrates typed-throws shape; consumers who need Result wrap at call site. Self-contained. | None |
| 10 | Installation snippet | 106–124 | KEEP | Standard inventory. | None |
| 11 | Pre-tag note ("Pre-tag note: this package's Package.swift currently pins its single dependency `swift-carrier-primitives` to `branch: "main"`…") | 125–126 | DELETE | Author release-process residue. The release shipped 2026-04-30; the note is stale (carrier shipped 2026-04-29; tagged ships at 0.1.0 once the tag is cut, which is a separate principal-direction step). | Delete. The Installation snippet's `from: "0.1.0"` form already states the consumer-shaped expectation; the branch:"main" interim state belongs in commit messages and contributor docs, not consumer prose. |
| 12 | Architecture intro + Main target file table | 132–139 | KEEP | The 3-row file table answers "where do these capabilities come from?" — consumer-shaped. | None |
| 13 | SLI target file table (5 conformance rows) | 144–151 | KEEP | Each row answers "what conformance is in this product?" — consumer-shaped. | None |
| 14 | "Excluded from SLI" — 200-word enumeration of 18 absences with 10 research-doc + 10 experiment citations | 153–155 | COMPRESS+RELOCATE | The enumeration IS the catalogue — currently in the wrong location. Reader's adoption need is "is the absence deliberate?" + a pointer to the catalogue. Categorisation (Structural blockers / Foundation axiom / Policy trade-off) is evaluator-relevant and should survive in the catalogue, not the README. | **Precondition**: create `Research/sli-deliberate-absences.md` (one-page index, three-category table, one line per absence linking to `principled-absence-*.md`). README replacement: "**Deliberate absences**: some SLI conformances are deliberately absent where they would imply Foundation dependencies, invalid semantics, or unsupported forwarding. See [`Research/sli-deliberate-absences.md`](./Research/sli-deliberate-absences.md) for the catalogue." |
| 15 | "Dependencies" subsection | 159–161 | KEEP | Names `swift-carrier-primitives` and the cascade contract. Consumer-shaped. | None |
| 16 | "Versioning and stability" — 200+ word prose paragraph | 161–163 | COMPRESS | Mixes evaluator-shaped 0.1.x SemVer commitments with internal-implementation reasoning ("the unsafeBitCast carve-out's scope is bounded to its current two sites; widening … requires a minor-version bump and a new entry in the per-protocol absence catalog. The fork-as-heritage shape is structural and permanent…"). | Replace with [README-027] 3-row operational table:<br/><br/>\| Surface \| 0.1.x expectation \|<br/>\|---\|---\|<br/>\| Public type names | Stable within 0.1.x \|<br/>\| Documented initializers and conformance set | Stable within 0.1.x \|<br/>\| Internal storage shapes / implementation strategy | Not part of the source-stability commitment \|<br/><br/>The unsafeBitCast carve-out, additive-vs-removal SemVer rules, and fork-heritage permanence relocate to `Research/principled-absence-array-dict-literal.md` (carve-out) and `Research/external-upstream-fork-heritage.md` (heritage permanence). |
| 17 | Platform Support | 167–175 | KEEP | Standard inventory. | None |
| 18 | Related Packages (Used By + Dependencies) | 179–192 | KEEP | All linked repos are public + tagged or marked; consumer-shaped peer references. | None |
| 19 | License (combined Apache 2.0 + MIT attribution) | 196–198 | KEEP | Required inventory; the combined-license framing is load-bearing for adopters per [README-014]'s permitted parent-relationship pattern. | None |

**Tagged summary**: 1 DELETE (pre-tag note), 4 COMPRESS (Property contrast + ecosystem-convention bullet + SLI absences enumeration + Versioning and stability), 1 RELOCATE (absences enumeration → new catalogue). Plus 1 NEW Research file (`sli-deliberate-absences.md`). Single commit semantically (relocate-and-compress is one operation per [HANDOFF-014]-style scope discipline).

---

## swift-ownership-primitives

**Public commit**: `0d5b399` (parentless launch) + `9186f52` (today's `## Design choices` removal). **README**: 224 lines.

| # | Section / Paragraph | Lines | Verdict | Rationale | Action |
|---|---|---|---|---|---|
| 1 | Title + status badge | 1–3 | KEEP | Required inventory. | None |
| 2 | One-liner | 5 | KEEP | Answers "what does this do?"; quantifies scope (fifteen primitives across four categories); states 6.3.1 production status. | None |
| 3 | Key Features bullet 1 (Stdlib-parity borrows and inouts) | 11 | KEEP | Names the SE-0519 mirror, the @safe conformance, the 6.3.1 path via _read / _modify. Consumer-shaped. | None |
| 4 | Key Features bullet 2 (SE-0517 UniqueBox parity) | 12 | KEEP | Names the parity surface and the Nest.Name rendering choice. Consumer-shaped. | None |
| 5 | Key Features bullet 3 (CoW value cell) | 13 | KEEP | Demonstrates the analog with `indirect` keyword on enum cases. Consumer-shaped. | None |
| 6 | Key Features bullet 4 (Slot/Latch atomic cells) | 14 | KEEP | Capability statement; consumer-shaped. | None |
| 7 | Key Features bullet 5 (Cross-boundary transfer matrix) | 15 | KEEP | Names the matrix shape; consumer-shaped. | None |
| 8 | Key Features bullet 6 (Optional<~Copyable>.take) | 16 | KEEP | Compact capability statement with stdlib-gap framing. Consumer-shaped. | None |
| 9 | Quick Start: heap-owned ~Copyable cell | 22–42 | KEEP | Self-contained, motivated; demonstrates SE-0517 parity in action with a matched baseline-without-the-package counter-example. | None |
| 10 | Quick Start: scoped mutable reference | 46–63 | KEEP | Self-contained; demonstrates `~Copyable, ~Escapable` storability with `Ownership.Inout`. | None |
| 11 | Quick Start: Optional<~Copyable>.take | 67–75 | KEEP | Self-contained; demonstrates the stdlib-gap shape. | None |
| 12 | Installation snippet (primary decomposition + 11-row narrow variants list) | 79–116 | KEEP | The "primary decomposition" framing answers "what should I import?" The 11-product list is a consumer choice surface. | None |
| 13 | Adoption section ("Downstream packages store `Ownership.Inout<Base>` …" + Property.View code example) | 120–135 | RELOCATE | This is sibling-package usage demonstration, not Ownership-itself adoption. A reader of Ownership needs the Quick Start, not how Property uses Ownership. The example IS evaluator-relevant for someone designing their own ~Copyable, ~Escapable container — but in that context, it should be a DocC article on Ownership.Inout, not a README section. | Move the code example + framing to ownership's DocC under "Adoption Patterns" or similar. README replacement: nothing (the section deletes); the Quick Start examples already cover Ownership.Inout adoption shape directly. |
| 14 | Overview table (12 types) | 141–155 | KEEP | Each row answers "what is this type for?" — consumer-shaped. | None |
| 15 | Final paragraph after Overview ("`Ownership.Borrow.`Protocol`` is the canonical borrow-capability protocol; conform via `extension MyType: Ownership.Borrow.`Protocol` {}` to participate without a bespoke accessor.") | 157 | KEEP | Concise capability statement. Consumer-shaped. | None |
| 16 | Platform Support | 161–169 | KEEP | Standard inventory. | None |
| 17 | Stability section opener (~3 lines: pre-1.0 SemVer pre-release framing) | 173–178 | KEEP | Operational consumer-shaped statement. | None |
| 18 | Source-stability commitment for 0.x — 4-bullet sub-list (initializer surface, internal storage, capability typealias) | 180–194 | COMPRESS | Mostly evaluator-shaped (what's source-stable) but mixes in implementation specifics ("`__Ownership_Borrow_Protocol` backing exist to work around SE-0404") that are contributor-shaped. | Replace with [README-027] 3-row operational table:<br/><br/>\| Surface \| 0.1.x expectation \|<br/>\|---\|---\|<br/>\| Public type names + initializer surface | Stable within 0.1.x \|<br/>\| `Ownership.Borrow.\`Protocol\`` capability typealias contract | Stable within 0.1.x \|<br/>\| Internal storage shapes / hoisted helper modules | Not part of the source-stability commitment \|<br/><br/>SE-0404 workaround context relocates to inline `///` doc comment in `Ownership.Borrow` source. |
| 19 | Migration to stdlib SE-0519 — 4-step deprecation plan | 196–209 | RELOCATE | Future-migration choreography per [README-016] new prohibition. Asserts SE-0519 alignment as committed when SE-0519 is still in evolution. The reader's question "will my code break?" is answered by Stability table alone; the choreography is contributor-shaped speculation. | **Precondition**: create `Research/stdlib-interaction-notes.md` with the 4-step plan reframed as non-committed scenario notes. README replacement: "Notes on possible interaction with SE-0519 are tracked in [`Research/stdlib-interaction-notes.md`](./Research/stdlib-interaction-notes.md)." |
| 20 | "The owned-storage primitives (Unique, Shared, Mutable, Slot, Latch) and the Transfer family are NOT covered by SE-0519 and are not expected to be deprecated as part of this transition." | 211–213 | RELOCATE | Same destination as #19; this is part of the same SE-0519 framing. | Move to the same Research note. |
| 21 | "Known accepted-as-known constraints in 0.1.0" — 2 bullets (heap-alloc workaround for register-pass miscompile + non-@inlinable for ABI) | 215–223 | RELOCATE | Internal workaround rationale per [README-016] new prohibition. Consumer needs to know the cost (heap-alloc on `init(borrowing:)` for Copyable Value), not the WHY. | Move WHY to inline `///` doc comments at the call sites in the source (Ownership.Borrow.swift). README keeps a 1-line cost statement if at all: "`Ownership.Borrow.init(borrowing:)` for `Copyable Value` heap-allocates a class-owned copy; the cost is documented at the call site." (Optional — could also delete entirely if call-site docs are sufficient.) |
| 22 | Related Packages (Used By: property + buffer) | 241–247 | KEEP | Public+tagged peer references; consumer-shaped. | None |
| 23 | License | 250–252 | KEEP | Required inventory. | None |

**Ownership summary**: 0 DELETE, 1 COMPRESS (Stability commitment table), 3 RELOCATE (Adoption → DocC; SE-0519 migration choreography → Research; workaround rationale → inline doc comments). Plus 1 NEW Research file (`stdlib-interaction-notes.md`). Single follow-up commit.

---

## Summary

| Repo | DELETE | COMPRESS | RELOCATE | KEEP | New Research files |
|---|---|---|---|---|---|
| carrier (control) | 0 | 0 | 0 | 9 | 0 |
| property | 1 | 4 | 0 | 7 | 0 |
| tagged | 1 | 4 | 1 | 12 | 1 (sli-deliberate-absences.md) |
| ownership | 0 | 1 | 3 | 19 | 1 (stdlib-interaction-notes.md) |

Per-repo cleanup commits land on each repo's main as a single follow-up commit, no force-push. Cohort uniformly accepts ≤ 2 commits on main per repo (parentless launch + cleanup).

## Skill amendment as v2.1.0

The remediation grounds in three concurrent rule changes to the readme skill:

1. Extend [README-016] Prohibited Content with 4 new rows (pre-tag/process notes, future-migration choreography, internal workaround rationale, ecosystem-convention framing).
2. Add new conditional [README-027] Stability Section Operational Form (must be operational *if* present; SHOULD for infrastructure packages).
3. Extend [README-010] Architecture with the consumer-question earning sub-rule (every row answers a consumer dependency / import / capability / adoption question; "When to import" recommended for product tables).

See `/tmp/cohort-readme-pattern-converged.md` for the verbatim amendment text.

## Outcome

RECOMMENDATION — execute Phase 1 (skill amendment) followed by Phase 2 per-repo cleanups (Property → Tagged → Ownership → Carrier audit-only) per the converged plan; Phase 3 verification re-audits each README against v2.1.0.
