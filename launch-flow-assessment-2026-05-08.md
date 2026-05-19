# Data-Structure Launch Flow Assessment

<!--
---
version: 1.2.0
last_updated: 2026-05-13
status: DECISION
supersession_note: |
  v1.2.0 (2026-05-13): The ≥3-day inter-launch floor recommendation in §"Pacing"
  (lines ~183, 192–194; resolved-question row #3 at line ~252) is RETIRED per
  principal directive 2026-05-13 after Story 2 Wave 1+2 demonstrated the floor
  adds no detectable value and produces real friction. Original text retained
  below for historical record; operational pacing rule is now "per-package
  readiness only" — see `Blog/Series/data-structures-launch-2026.md` §Pacing.
status_note: |
  v1.0.0 (RECOMMENDATION) shipped with six open questions for orchestrator.
  v1.1.0 (DECISION) folds in orchestrator answers received 2026-05-08:
  hash-table relocated to Story 9, companion Pattern Doc posts captured now,
  pacing confirmed driven-by-readiness, cohort overview at Blog/Series/
  data-structures-launch-2026.md, finite→algebra-group prune deferred
  (chain stays at 42), `cohort:` frontmatter primary (`series:` also acceptable).
  v1.2.0 (2026-05-13) retires the ≥3-day inter-launch floor — see supersession_note above.
scope: cross-package
tier: 1
audience: orchestrator (data-structure publish-chain decision; storytelling axis only)
sources:
  - Blog/_index.json (BLOG-IDEA-086 through 095)
  - Blog/_Styleguide.md
  - Blog/Published/2026-05-07-introducing-{equation,comparison,hash}-primitives.md (voice baseline)
  - Blog/Published/2026-04-29-introducing-swift-carrier-primitives.md (single-launch precedent)
  - Blog/Series/typed-throws.md (formal-series shape, NOT this cohort's shape)
  - .claude/skills/blog-process/SKILL.md ([BLOG-008]/[BLOG-010]/[BLOG-011]/[BLOG-016]/[BLOG-020]/[BLOG-021])
  - .claude/skills/ecosystem-data-structures/SKILL.md ([DS-001]–[DS-010])
  - .claude/skills/swift-forums-review/SKILL.md (predicted critique angles)
  - swift-primitives/Research/tier-inventory-2026-05-08.md
  - swift-institute/Research/array-bounded-index-revisit-2026-05-08.md
  - swift-institute.org/Swift Institute.docc/{Swift Institute.md, Layers.md, Swift Primitives.md}
---
-->

## TL;DR

The 10-story segmentation is approximately right and the topological order is sound. Three changes tighten the launch arc materially: (1) **move `swift-hash-table-primitives` from Story 7 (Buffers) into Story 9 (Maps & Sets)**, where it sits with the user-facing types it backs rather than orphaned as "internal infrastructure" in a buffer-discipline post; (2) **treat the cohort as a named cross-referenced cohort, not a formal `[BLOG-008]` series** — formal series mode conflicts with `[BLOG-016]` release-post non-blending, but each post still needs explicit cohort orientation in its first paragraph and a "what's coming next" pointer in its last; (3) **commit to one through-line — "what L1 actually requires when you take typed primitives seriously"** — and have Story 1 set it explicitly and Story 10 close it with a short retrospective. Pacing should be **driven by per-package readiness with a ≥3-day inter-launch floor**, not a fixed weekly cadence; at the user's effectively-zero audience baseline ([BLOG-020]) the writer-side cost of a calendar-locked cadence outweighs the reader-side benefit. Five HIGH-priority companion Pattern Documentation posts are flagged (numbers taxonomy, carrier-home witness placement, typed `Memory.Address` arithmetic, six buffer disciplines, the variant pattern).

**v1.1.0 update (orchestrator decisions, 2026-05-08)**: hash-table relocation **confirmed**; companion Pattern Documentation posts **captured now** as `BLOG-IDEA-096` through `BLOG-IDEA-100`; pacing **confirmed**; cohort overview document created at `Blog/Series/data-structures-launch-2026.md`; `finite → algebra-group` prune **deferred** (chain remains at 42 packages, Story 3 keeps 7-package scope); frontmatter convention is `cohort: data-structures-launch-2026` with `series:` as an acceptable alternative. See § "Resolved decisions" and § "Implementation queue" for the full set of follow-on actions.

---

## Granularity verdict

The 10-story count is defensible. Per-story package distribution: 6 / 9 / 7 / 5 / 2 / 1 / 2 / 6 / 2 / 2 (median ≈ 2.5, max 9, min 1). Two granularity questions surface:

**Story 6 (Strings, 1 package) — defensible standalone.** A one-package story is unusual but `String` carries narrative weight disproportionate to package count: it is the most reader-recognizable type in the cohort, and the "owned, null-terminated, `~Copyable @unchecked Sendable`, no Foundation" framing is a launch hook in itself. Collapsing Story 6 into Story 5 (Memory) or Story 7 (Buffers) dilutes that hook by burying String in a multi-concept post. Per `[BLOG-008]` standalone criteria ("insight is complete in one post," "examples independent"), Story 6 fits standalone. **Keep as-is.**

**Story 7 (Buffers, 2 packages: buffer + hash-table) — re-cluster.** The current scaffold flags hash-table as "internal infrastructure for the upcoming Maps & Sets story." Per `[DS-003]` the catalog itself describes `Hash.Table<E>` as "Open-addressed hash table; backing for Dictionary/Set (not standalone)." Shipping a launch post about a "not standalone" infrastructure type alongside the user-facing buffer disciplines is awkward on two axes:

- *Reader-facing*: a Buffers launch reads as "here are six mutation disciplines you can compose," and bolting on "and also there's a hash table you shouldn't use directly" weakens the post's spine.
- *Forum-critique-facing*: a "ship the substrate now, the consumer next launch" framing invites the predictable "why launch infrastructure separately from its consumer?" critique.

**Recommendation: move `swift-hash-table-primitives` from Story 7 into Story 9 (Maps & Sets).** Story 7 becomes "Buffer disciplines" pure (six disciplines + byte-level `Buffer.Aligned` / `Buffer.Unbounded`). Story 9 becomes 3 packages (set + dictionary + hash-table) with hash-table framed as "the substrate beneath both" — same package, different narrative role. This does not re-arrange the dep chain (hash-table's tier doesn't change; both Story 7 and Story 9 sit downstream of Story 5/Memory).

**No splits recommended.** Story 2 (Indexing, 9 packages) and Story 8 (Linear, 6 packages) are large but coherent — the audience and concept are unified across each story's packages. Splitting either fragments the narrative without adding a wall worth dramatizing.

---

## Ordering verdict

The proposed sequence (Numbers → Indexing → Algebra → Bits → Memory → Strings → Buffers → Linear → Maps & Sets → Trees & Graphs) respects the dependency graph and places concrete user-facing payoff at the right beats.

**Where the dep graph allows alternatives:**

- **Stories 2 (Indexing) vs 3 (Algebra)** are parallel branches off Story 1. Current order fronts Indexing, which is the more recognizable territory for the average Swift developer (most readers use indices daily; fewer engage with algebraic structures explicitly). **Keep.**
- **Stories 6 (Strings) and 7 (Buffers)** are noted as parallel-launchable; both depend only on Story 5 (Memory). Current order ships Strings first. Pedagogically defensible: Strings is the more recognizable consumer of typed memory, and seeing it before the abstract Buffer disciplines primes the reader. **Keep**, with the caveat that if the per-package readiness brief for Story 7 finishes first the orchestrator may swap order without harm — neither order has narrative load-bearing weight.
- **Stories 8 → 9 → 10** is the only viable ordering for the consumer tier (linear collections demonstrate the variant system; maps & sets need hash-table; trees & graphs need buffer-arena). **Keep.**

**One framing observation about Story 1.** The story bundles 6 packages (algebra, sle, error, cardinal, ordinal, affine) under the spine "three kinds of 'number' (cardinal/ordinal/affine) the stdlib conflates." `algebra-primitives` (the namespace package, Tier 0, prerequisite for Story 3's algebra-X cluster) is in Story 1's package list as a supporting cast member, not as a third-spine equal. This is correct as the orchestrator scaffolded it — Story 1's spine should remain the cardinal/ordinal/affine taxonomy, with algebra/sle/error mentioned as substrate without competing for narrative airtime. The temptation to rebrand Story 1 as "Numbers, errors, and the algebra namespace" should be resisted; it dilutes the strongest available hook.

---

## Category-mix verdict (per-story Announcement vs +Pattern Documentation)

All 10 are correctly classified as Announcement under `[BLOG-016]` (release-post non-blending). Each has a *companion* Pattern Documentation candidate; per the handoff scope these should be flagged, not scaffolded.

| Story | Announcement | +Pattern Doc companion (FLAGGED, do not scaffold) | Priority |
|---|:---:|---|:---:|
| 1 Numbers | yes | "Cardinal, Ordinal, Affine: three kinds of number stdlib conflates" | **HIGH** |
| 2 Indexing | yes | Revive `BLOG-IDEA-010` "Phantom Types Meet Affine Geometry" as Story 2's companion | MEDIUM |
| 3 Algebra | yes | "The algebra hierarchy in code: from magma to field" | LOW (audience narrow) |
| 4 Bits | yes | "Carrier-home witness placement: where `Algebra.Field<Bit>` lives and why" — directly publishable from the 2026-05-08 bit-field-witness-home decision in `array-bounded-index-revisit-2026-05-08.md` §"Bit-Field Witness Home" | **HIGH** |
| 5 Memory | yes | "Typed `Memory.Address` arithmetic vs raw pointers" | **HIGH** |
| 6 Strings | yes | "Owned `~Copyable` strings: null-terminated and platform-native, without Foundation" | LOW |
| 7 Buffers | yes | "Six buffer disciplines: Linear, Ring, Slab, Linked, Slots, Arena" | **HIGH** |
| 8 Linear | yes | "The variant pattern: `.Static<N>`, `.Bounded`, `.Small<N>`, `.Fixed` across the ecosystem" | **HIGH** |
| 9 Maps & Sets | yes | "Slab-backed Dictionary vs linear-backed `Dictionary.Ordered`: when ordering costs you" | MEDIUM |
| 10 Trees & Graphs | yes | "`Graph` as algorithm namespace, not container" | LOW |

The five HIGH-priority candidates (Stories 1, 4, 5, 7, 8) are the launches where the conceptual framework is broader than the announcement and a teaching post adds standalone value to the audience the institute wants to reach. Capturing them as new `BLOG-IDEA-XXX` entries is out-of-scope per the handoff; the orchestrator should decide whether to scaffold them now (before per-package readiness work) or after launch.

**Pairing rhythm if companions ship**: per `[BLOG-016]` they MUST NOT blend — separate posts. Per `[BLOG-021]` paired-post URL handling, the companion's strip-and-restore option (b) is the right choice if the launch post forward-references the companion before the companion is published. At near-zero audience the cost of resolve-and-accept-404 (option a) is also fine; the orchestrator should pick a single convention and apply it consistently.

---

## Series-formalization verdict

**Not a formal `[BLOG-008]` series. Treat as a named cross-referenced cohort.**

Per `[BLOG-008]` series criteria — "topic requires layered understanding," "natural walls create dramatic pauses," "running example benefits from evolution," "3+ related ideas" — the 10 launches superficially qualify. But series mode collides with `[BLOG-016]` (release-post non-blending) on three concrete points:

| `[BLOG-008]` series property | Conflict with `[BLOG-016]` Announcement category |
|---|---|
| Cliffhanger endings between parts | Announcement closings are factual ("here's how to depend on it; here's what's next"); cliffhangers read as marketing manipulation on release posts |
| Shared *running example* that evolves | Each launch's audience action is "adopt this package"; an evolving example across launches dilutes the per-launch call-to-action |
| Each part *opens with a brief orientation* | Compatible with Announcement format and SHOULD be adopted (see below) |

**Recommendation: cohort-affordance without series-mode.** Concretely:

- **Frontmatter convention**: each post adds `cohort: data-structures-launch-2026` (new field, not `series:`) so the cohort is queryable but doesn't trigger series-mode rendering.
- **Opening orientation (1–2 sentences)**: each post's first paragraph names the cohort and the post's position in it. Worked example for Story 4: *"This is the fourth of ten launches in the data-structures cohort. The substrate is in place: Numbers (Story 1), typed Indexing (Story 2), and the Algebra hierarchy (Story 3). This launch ships the bit-level primitives that compose into the user-facing `Bitset`."*
- **Closing pointer**: each post (except Story 10) closes its "What's next" section with a one-line pointer to the next launch, link-deferred per `[BLOG-021]` until the next post is live.
- **Cohort overview**: a single document at `Blog/Series/data-structures-launch-2026.md` describes the arc and lists all 10 launches with one-sentence each. Naming the file under `Series/` is a mild inconsistency (it's not a formal series) but the directory is the natural home and avoids creating a new top-level convention; flag for orchestrator confirmation under "Open questions."

The 2026-05-07 `equation`/`comparison`/`hash` triple is the closest in-corpus precedent for this shape — three Announcement posts published the same day with explicit `[Companion: X]` cross-links and a shared SE-0499 framing. The 10-story cohort scales the same pattern across more posts and more weeks.

**[Orchestrator decision 2026-05-08]**: cohort overview document confirmed at `Blog/Series/data-structures-launch-2026.md` (created in v1.1.0 implementation). The `cohort:` frontmatter field is the recommended primary convention; using `series:` is also acceptable. Per-post writer chooses; both convey the same intent and the cohort overview document at `Blog/Series/data-structures-launch-2026.md` is the canonical anchor regardless of frontmatter field choice.

---

## Narrative arc recommendation

The cohort needs a single load-bearing through-line that survives 10 launches without becoming repetitive. Three candidates were considered:

| Through-line | What it asserts | Cost |
|---|---|---|
| (A) "Building Swift's L1 from scratch" | The institute is laying foundations; each launch is a chapter of foundation-laying | Inwardly-focused; readers expected to care about the institute's project |
| (B) "The case for typed primitives" | Each launch demonstrates that typed primitives outperform untyped equivalents | Concrete and verifiable; locks readers into a "typed-primitives advocate" frame |
| (C) "What stdlib left out" | Each launch fills a stdlib gap | Fight-picking; tone collides with `feedback_blog_voice` ("no whimsy," no jokey asides) and reads as marketing-confrontational on alpha launch |

**Recommended through-line — a hybrid of (A) and (B) without (C)'s posture:**

> *Most Swift developers experience L1 as `Int`, `Array`, `Dictionary`, `String`, and the standard library protocols. The institute's L1 is broader: typed indices that prevent collection mismatches, typed memory addresses that turn pointer arithmetic into compile-time-checked offsets, an algebraic hierarchy that classifies what a type's operations actually mean, and a variant system that lets every collection ship a fixed-capacity / static-N / SmallVec form. Each launch ships a slice of that L1 and shows what becomes possible.*

Properties this through-line satisfies:

- **Avoids fight-picking.** It frames the institute's L1 as *broader* without claiming *superior*; stdlib remains a respected reference.
- **Concrete per launch.** Each story can name its slice ("This launch ships typed indexing"; "This launch ships the bit-level primitives"; etc.) without straining the frame.
- **Earned across the cohort.** The full claim only becomes legible after multiple launches; Story 10's retrospective is where it resolves. Per `[BLOG-011]` first-principles arc, this is the cohort-level analogue of "let the reader discover" — the through-line is *exhibited* across the launches, not *declared* in Story 1.
- **Survives forum critique.** The "what stdlib left out" frame would invite "swift-collections already ships X" rebuttals; the "broader L1" frame admits stdlib-and-institute coexistence without comparing.

The through-line is set explicitly in Story 1's opening (see Hook recommendation below), reinforced softly in each launch's orientation paragraph, and resolved in Story 10's retrospective.

---

## Hook / resolution recommendation

### Story 1 hook (the cohort's opening)

Story 1 carries first-impression weight for the entire cohort. A weak hook here weakens 10 subsequent launches. Per `[BLOG-016]` Story 1 is conventional expository (not first-principles), so the hook is the first paragraph — what makes a reader keep reading instead of bouncing.

**Anti-pattern (announcement-shaped, generic, weak)**: *"Today we're launching six new Swift packages. They make numbers more typed."*

**Recommended shape (concrete + cohort-framed + through-line-set)**: open on the trichotomy concretely, then name the cohort and the through-line:

> Cardinal (count), ordinal (position), affine (offset). Three things stdlib calls `Int`. This launch ships them as separate types — and is the first of ten launches in the data-structures cohort. Each launch fills in a slice of L1 that takes typed primitives seriously.

This three-sentence opening:
1. States the concrete shift ([BLOG-styleguide] strong-openings: title plus first three sentences establish audience and benefit).
2. Names the cohort and the post's position (orientation per series-affordance recommendation above).
3. Sets the through-line in one sentence so subsequent launches can refer to "the through-line set in Story 1."

Story 1 is also the natural place to disclose pacing — a one-line note in "What's next" stating "the cohort launches over the coming weeks; pacing is driven by per-package readiness" sets reader expectations and pre-empts "is this still going?" questions if a pause hits.

### Story 10 resolution (the cohort's close)

Story 10 closes the launch arc. Per `[BLOG-016]` it remains an Announcement and MUST NOT blend into a Pattern Doc, but its "What's next" section can carry the cohort retrospective — a short synthesis that earns the through-line set in Story 1.

**Recommended Story 10 closing (300–400 words, inside "What's next" expanded into "What's next, and what the cohort built")**:

- A single concrete Swift example using types drawn from across the cohort. Worked example shape: a small config-parser that uses `Cardinal` for counts, `Index<E>` for positional access, `Array.Static<N>` for fixed-capacity buffering, `Dictionary.Ordered` for key preservation, `Tree.Keyed<K>` for nested hierarchical config — each from a different launch, shown working together in 20–30 lines.
- One paragraph naming what the cohort built, in the through-line's voice: *"Across ten launches, L1 is now: typed indices, typed memory addresses, an algebraic hierarchy, six buffer disciplines, four variants per collection family, and a String built without Foundation."* The list is concrete; the framing earns the abstraction.
- A pointer beyond the cohort: L2 (Standards) consumes L1; L3 (Foundations) composes them. No commitment to L2/L3 launch sequencing — only acknowledgement that the cohort closes a layer, not the project.
- A pointer back to the cohort overview document at `Blog/Series/data-structures-launch-2026.md` so a reader landing on Story 10 first can navigate the cohort backward.

Per `[BLOG-014]` and `[BLOG-019]` the Swift example MUST be a real, compiling experiment with a receipt link; do not author it inline-only.

---

## Pacing recommendation

Per `[BLOG-020]` audience-magnitude check, the user's audience baseline is effectively zero (corroborated by reflections through 2026-04-24 and downstream). Conventional engagement-timing heuristics (Tuesday newsletter window, peak forum-traffic hours) do not apply.

**Recommendation: driven by per-package readiness with a ≥3-day inter-launch floor.**

Rationale:

| Pacing option | Shape | Cost |
|---|---|---|
| (a) Linear weekly | 10 launches over 10 weeks | Locks calendar; one stalled readiness brief domino-stalls the cohort; reader-side benefit at 0 audience is zero |
| (b) Burst then trickle | Stories 1–3 quickly, then weekly 4–10 | Front-loads operational risk; uneven from reader perspective |
| (c) Same-day-all-10 | 1–3 days, all launches | High operational concentration; no time to absorb forum response between launches; high re-simulation cost per `[FREVIEW-019]` |
| (d) Driven by readiness, ≥3-day floor | Each launch ships when ready, minimum 3 days between | Lowest operational risk; uneven cadence that doesn't matter at 0 audience; allows parallel-launchable Stories (6/7) to ship same-day if ready together |

(d) wins at this audience baseline. The 3-day floor exists for two reasons: (1) indexing latency — each launch should land before the next so search results aren't competing for cohort attention; (2) writer-side recovery — per-package readiness is real work, and back-to-back launches without a buffer compress review quality. The 3 days is a soft minimum, not an upper bound; gaps of 1–2 weeks between launches are fine.

**Corollary — re-simulation budget**: per `[FREVIEW-019]` each major-tag launch needs a forums-review re-simulation if substantial changes have landed. With 10 launches, treat re-sim as part of the per-package readiness brief; per `[FREVIEW-020]` use delta-mode for low-change windows. The cumulative cost is manageable but should be planned as part of readiness, not added afterward.

**Estimated total cohort window**: 4–8 weeks elapsed time, depending on per-package readiness velocity. This is the *sprint* framing — front-loaded effort by the writer, freeze on unrelated content during the cohort window.

**[Orchestrator decision 2026-05-08]**: pacing recommendation confirmed.

---

## Risk surface

What could go wrong in the launch sequence, ordered by likelihood-times-impact:

| # | Risk | Mitigation |
|---|---|---|
| 1 | "42 packages for what stdlib offers in 5" — overengineering critique. The single most predictable forum response. | Hammer the through-line in EVERY launch's orientation paragraph. Each launch must be defensible as "ships a slice of L1 not present in stdlib," not as "yet another reimplementation." |
| 2 | "Why is X in package Y and not in package Z?" — layering questions are inevitable across 42 packages. Especially salient: why is `Algebra.Field<Bit>`'s witness in `bit-primitives` and not `algebra-field-primitives`? | Each launch with a non-obvious layering decision links the research doc as a `[BLOG-013]` receipt. Story 4 (Bits) MUST link `array-bounded-index-revisit-2026-05-08.md` §"Bit-Field Witness Home" because that exact question will land. |
| 3 | "How is this different from swift-collections (Apple)?" — direct comparison invited by Stories 8/9/10. | Stories 8/9/10 each include a "What this package is not" section per the 2026-04-29 carrier-primitives launch precedent. Distinguish on typed-indices / variant-system / `~Copyable` axes; do not claim superiority. |
| 4 | "Why fork stdlib protocols?" — partially mitigated for Equation/Comparison/Hash by SE-0499 dual-mode, unmitigated for cohort packages without an equivalent retirement plan. | Where retirement is planned (matches an SE proposal), state it explicitly as the 2026-05-07 trio does. Where there is no retirement plan, state the protocol's intentional permanence. |
| 5 | "Swift 6.3.1+ floor is too aggressive." | Each launch states the floor and rationale (typed throws, `~Copyable`, SE-XYZ). The floor is consistent across the cohort; there is no "creeping floor" risk. |
| 6 | Foundation independence — anyone forum-aware will probe the L1's Foundation-freeness claim. | Per `[PRIM-FOUND-001]` every L1 main target is Foundation-free; each launch states "imports no Foundation module" in the "What's new" section, matching the carrier-primitives launch precedent. |
| 7 | Performance claims — 42-package L1 with no benchmark numbers invites "how do you know this is fast?" | Make NO performance claims in the launches per `[BLOG-016]`. Performance posts are companion Pattern Documentation, not announcements. If pressed in forum threads, point to the benchmark infrastructure. |
| 8 | Re-simulation discipline — `[FREVIEW-019]` requires re-sim before major-version tags after substantial changes. | Bake re-sim into per-package readiness; use `[FREVIEW-020]` delta-mode for low-change windows; budget for full re-sim on Stories with substantial recent-state changes. |
| 9 | Internal launch fatigue — 10 launches is operationally heavy. | Treat the cohort as a sprint, not normal-cadence work. Freeze unrelated blog content during the launch window. |
| 10 | Forward-reference 404s — companion Pattern Doc posts (if scaffolded later) and inter-launch references will create lag-window 404s. | Apply `[BLOG-021]` consistently; option (b) strip-and-restore is the right default; option (a) resolve-and-accept-404 is acceptable at 0 audience; pick one and apply uniformly. |

Risks 1, 2, 3 are the highest-leverage to plan against; the rest are operational hygiene.

---

## Specific changes to the 10 BLOG-IDEAs

| ID | Title | Change verdict | Notes (post-orchestrator-decision) |
|---|---|---|---|
| BLOG-IDEA-086 | Numbers, by kind | KEEP | Companion `BLOG-IDEA-096` scaffolded (cardinal/ordinal/affine taxonomy). Story 1 carries the cohort's opening hook — Story 1 draft must set the through-line per § Hook/resolution recommendation. |
| BLOG-IDEA-087 | Typed indexing and sequences | KEEP | `BLOG-IDEA-010` "Phantom Types Meet Affine Geometry" (Ready for Drafting, stalled) remains the natural companion if revived; not duplicated as a new ID. |
| BLOG-IDEA-088 | Algebraic structures | KEEP | Companion Pattern Doc not captured (LOW priority — narrow audience). Chain stays at 7 packages; `finite → algebra-group` prune deferred per orchestrator decision. |
| BLOG-IDEA-089 | Bits, packed | KEEP | Companion `BLOG-IDEA-097` scaffolded (carrier-home witness placement). Launch post MUST link `array-bounded-index-revisit-2026-05-08.md` §"Bit-Field Witness Home" as `[BLOG-013]` receipt — placement decision will draw forum questions. |
| BLOG-IDEA-090 | Memory and storage | KEEP | Companion `BLOG-IDEA-098` scaffolded (typed `Memory.Address` arithmetic). |
| BLOG-IDEA-091 | Owned strings | KEEP | Single-package size acceptable; no companion captured (LOW priority). |
| BLOG-IDEA-092 | Buffer disciplines | **AMENDED** | `blocker` field updated: `swift-hash-table-primitives` removed from this story (moved to Story 9 per orchestrator decision). Companion `BLOG-IDEA-099` scaffolded (six buffer disciplines). |
| BLOG-IDEA-093 | Linear collections | KEEP | Companion `BLOG-IDEA-100` scaffolded (the variant pattern). |
| BLOG-IDEA-094 | Maps and sets | **AMENDED** | `blocker` field updated: `swift-hash-table-primitives` added (moved from Story 7). Story 9 now 3 packages (set + dictionary + hash-table). Launch post should add "What this package is not" section to address swift-collections comparison per § Risk surface. |
| BLOG-IDEA-095 | Trees and graphs | KEEP | Story 10's "What's next" section carries the cohort retrospective per § Hook/resolution recommendation. The retrospective's multi-cohort Swift example MUST be authored as a runnable experiment per `[BLOG-013]` / `[BLOG-019]`. |

**Two AMENDED entries** — `BLOG-IDEA-092` and `BLOG-IDEA-094` blockers — implementing the confirmed hash-table relocation. **Five new entries scaffolded** — `BLOG-IDEA-096` through `BLOG-IDEA-100` — implementing the confirmed companion-Pattern-Doc capture. All edits applied to `_index.json` in v1.1.0 implementation; see § Implementation queue.

---

## Resolved decisions

All six open questions from v1.0.0 received orchestrator answers on 2026-05-08. Resolutions below; concrete file-level edits in § Implementation queue.

1. **Hash-table relocation — RESOLVED: CONFIRMED.** `swift-hash-table-primitives` moves from Story 7 (BLOG-IDEA-092) to Story 9 (BLOG-IDEA-094). Implementation: `_index.json` blockers for both entries amended.

2. **Companion Pattern Documentation posts — RESOLVED: CAPTURE NOW.** Five new `BLOG-IDEA-XXX` entries scaffolded in `_index.json` Needs-More-Context section: `BLOG-IDEA-096` (numbers taxonomy), `BLOG-IDEA-097` (carrier-home witness placement), `BLOG-IDEA-098` (typed `Memory.Address` arithmetic), `BLOG-IDEA-099` (six buffer disciplines), `BLOG-IDEA-100` (the variant pattern). Each scaffold names its companion launch and notes that publication awaits the corresponding launch post per `[BLOG-016]`.

3. **Pacing — RESOLVED: CONFIRMED.** Driven by per-package readiness with a ≥3-day inter-launch floor. No fixed weekly cadence.

4. **Cohort overview document location — RESOLVED: `Blog/Series/data-structures-launch-2026.md`.** Created in v1.1.0 implementation per `[BLOG-009]` series-plan format, adapted with explicit notes that this is an Announcement-mode launch cohort (subject to `[BLOG-016]` non-blending) rather than a pedagogical first-principles series like `typed-throws.md`. The `Series/` directory is the home; the document is named with cohort semantics.

5. **`finite → algebra-group` prune — RESOLVED: DEFERRED.** Hard call; orchestrator opted to keep the chain at 42 packages for now. Story 3 (Algebra) retains 7-package scope (algebra-magma, algebra-monoid, algebra-semiring, algebra-group, algebra-ring, algebra-field, finite). The prune candidate from `tier-inventory-2026-05-08.md` §3 #1 remains structurally available as a future cleanup, separate from this launch cohort. No Story 3 re-frame required.

6. **Frontmatter convention — RESOLVED: `cohort:` PRIMARY, `series:` ACCEPTABLE.** The cohort overview document carries the canonical anchor regardless of which field individual launch posts use. Per-post writer chooses; both are valid. Recommendation is `cohort: data-structures-launch-2026` for new posts, but a writer may reuse `series: data-structures-launch-2026` if that maps better to existing tooling.

---

## Implementation queue

The orchestrator decisions translate to four concrete artifact changes, all applied in v1.1.0 of this document's implementation cycle:

| # | Artifact | Change | Status |
|---|---|---|---|
| 1 | `Blog/_index.json` — `BLOG-IDEA-092` (Buffer disciplines) | Amend `blocker` field to drop `swift-hash-table-primitives` and adjust the package count framing (Story 7 = "Buffer disciplines" pure) | applied 2026-05-08 |
| 2 | `Blog/_index.json` — `BLOG-IDEA-094` (Maps and sets) | Amend `blocker` field to add `swift-hash-table-primitives` (moved from Story 7); reframe Story 9 as 3 packages with hash-table as substrate | applied 2026-05-08 |
| 3 | `Blog/_index.json` — Needs-More-Context section | Append five new entries: `BLOG-IDEA-096` through `BLOG-IDEA-100` (Pattern Doc companions for Stories 1, 4, 5, 7, 8) | applied 2026-05-08 |
| 4 | `Blog/Series/data-structures-launch-2026.md` | Create new file per `[BLOG-009]` series-plan format, adapted with cohort-mode framing notes (Announcement category per `[BLOG-016]`, no cliffhangers, shared example optional) | applied 2026-05-08 |

**Out of scope for v1.1.0** (not orchestrator-authorized; remain orchestrator's decision):

- Per-package release-readiness briefs for Stories 1–10 — handed off as the orchestrator's next phase, not part of this assessment.
- Drafting any of the 10 launch posts or the 5 companion Pattern Doc posts — explicitly out of scope per original handoff "Do Not Touch" and per `[BLOG-016]` writing-mode boundaries.
- Editing source-tree packages (Package.swift, Sources/, Tests/) — explicitly out of scope; chain locked at 42.
- Reviving `BLOG-IDEA-010` "Phantom Types Meet Affine Geometry" as the Story 2 companion — flagged in the changes table as the natural candidate but not duplicated as a new ID; orchestrator's call whether to revive or capture as a fresh idea.

---

## References

- `swift-institute/Blog/_index.json` — source of `BLOG-IDEA-086` through `BLOG-IDEA-095`
- `swift-institute/Blog/_Styleguide.md` — voice, register, sentence-case, no-whimsy conventions
- `swift-institute/Blog/Published/2026-05-07-introducing-{equation,comparison,hash}-primitives.md` — closest in-corpus precedent for a sub-cohort-launch pattern (3 same-day Announcements, cross-linked, shared SE-0499 framing)
- `swift-institute/Blog/Published/2026-04-29-introducing-swift-carrier-primitives.md` — single-launch precedent including "What this package is not" section (forum-critique-anticipation)
- `swift-institute/Blog/Series/typed-throws.md` — formal `[BLOG-008]` series shape; useful as a contrast (this cohort is NOT this shape)
- `swift-institute/Blog/Review/introducing-property-primitives.md` — Announcement-with-fluent-API-emphasis precedent
- `.claude/skills/blog-process/SKILL.md` — `[BLOG-008]` series planning, `[BLOG-010]` writing modes, `[BLOG-011]` narrative arc, `[BLOG-013]` receipts, `[BLOG-014]` claim verification, `[BLOG-016]` release-post non-blending, `[BLOG-019]` companion-experiment parallel authoring, `[BLOG-020]` audience-magnitude check, `[BLOG-021]` paired-post URL handling
- `.claude/skills/ecosystem-data-structures/SKILL.md` — `[DS-001]` four-layer composition, `[DS-002]` variant pattern, `[DS-003]` container selection (especially the "Hash.Table not standalone" framing), `[DS-004]` buffer disciplines
- `.claude/skills/swift-forums-review/SKILL.md` — `[FREVIEW-019]` re-simulation cadence, `[FREVIEW-020]` delta-mode for low-change windows, predicted critique angles
- `swift-primitives/Research/tier-inventory-2026-05-08.md` — 42-package chain shape; `finite → algebra-group` prune candidate (open question #5)
- `swift-institute/Research/array-bounded-index-revisit-2026-05-08.md` §"Bit-Field Witness Home" — directly publishable as Story 4 companion; load-bearing for Story 4 launch as `[BLOG-013]` receipt
- `swift-institute.org/Swift Institute.docc/Swift Institute.md` / `Layers.md` / `Swift Primitives.md` — public-facing landing context; the cohort launches must align with the existing layer framing rather than introducing competing taxonomy
- `feedback_blog_voice.md` (memory) — no whimsy, no internal skill refs, reasoning sentences must follow logically
- `[PRIM-FOUND-001]` — Foundation independence; load-bearing for every launch's "What's new" claim
