---
date: 2026-04-21
session_objective: Execute the swift-property-primitives 0.1.0 documentation rewrite handoff under /supervise + /handoff composition; diagnose and resolve the rendering defect surfaced during the principal's render spot-check.
packages:
  - swift-property-primitives
  - swift-institute/Research
  - swift-institute/Skills/documentation
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# swift-property-primitives handoff execution and the DocC multi-target aggregation research

## What Happened

**Primary work**: execute the 7-phase documentation rewrite described in `swift-property-primitives/HANDOFF.md` (authored pre-session by the preceding `2026-04-21-property-primitives-release-polish-supervised.md` session). Handoff HEAD was `7b8adfc`; terminal HEAD is `794449e`.

Phases ran to completion in a single agent stretch under in-absentia supervision per `[SUPER-014a]`:

- **Phase 1** `08ace39` — inline `///` audit against refactored `[DOC-001]` / `[DOC-010]` across 10 source files (19 insertions, 46 deletions); surgical trim of rationale prose, kept canonical usage snippets.
- **Phase 2** `bac90a6` — strip 16 `.md` files across 6 `.docc/` directories (clean slate for rebuild); `.gitkeep` placeholders to preserve directory existence.
- **Phase 3** `f806f2e` — per-symbol articles (11 articles + 5 variant catalog roots + 1 umbrella baseline).
- **Phase 4** `8b23ef0` — 6 topical articles (Getting-Started, Choosing-A-Property-Variant, CoW-Safe-Mutation-Recipe, Phantom-Tag-Semantics, ~Copyable-Container-Patterns, Value-Generic-Verbosity-And-The-Tag-Enum-View-Pattern).
- **Phase 5** `941d89a` — GettingStarted.tutorial + Tutorials.tutorial TOC + 5 step source files in `Resources/` + new `"Property Primitives Tutorial Tests"` testTarget mirroring the final step.
- **Phase 6** structure `a3d4759` — umbrella landing page with `@Row`/`@Column` + `@CallToAction` + Topics hierarchy; visual identity (`@PageColor` / `@PageImage`) deferred pending user answer.
- **Phase 7** `0423d56` — `xcodebuild docbuild` ran clean across all 5 product schemes with zero warnings; required 148 → 0 warning sweep (cross-module `` ``Symbol`` `` refs replaced with code-spans; cross-catalog `<doc:>` refs removed; `@DisplayName` stripped from topical articles; init `Topics` groups trimmed to avoid overload ambiguity; chapter-hero placeholder PNG added for `@Chapter @Image`).

**Supervisor re-engagement and two ask-gated escalations**: after I reported verification status to the principal, they re-engaged live. Two supervisor `ask:` entries converted from in-absentia class (b)→(c) queues back to class (b) live answers:

- **Ground Rule #7** (six approved topical articles) — principal observed Getting-Started article and GettingStarted tutorial covered the same ground. Answer: drop the article, absorb its novel content (motivation + design-pattern framing + variants-at-a-glance table + call-site gallery) into `README.md`; tutorial keeps the hands-on slot. Committed `b016de0`. Set reduces 6 → 5 topical articles.
- **Ground Rule #8** (visual identity) — principal answered (A) `@PageColor(purple)` approved; (B) `@PageImage` hero skipped for 0.1.0; (C) placeholder `chapter-hero.png` accepted for 0.1.0. Committed `4392f9b`.

**init(_:) render defect + /research-process investigation**: during the principal's render spot-check, they surfaced that `Property/init(_:)` detail page rendered signature-only — no abstract, no parameter list. Investigation via symbol-graph JSON inspection:

```
Umbrella archive:  property_primitives/property/init(_:).json → abstract: None
Core archive:      property_primitives_core/property/init(_:).json → abstract: full
```

Confirmed across ALL re-exported symbols and member kinds. Root cause: DocC's `@_exported public import` re-exports the symbol but does not propagate its doc comments — a structural property of the archive-per-module extraction model, not a rendering quirk.

I invoked `/research-process` and produced a Tier 2 ecosystem research document per `[RES-020]`: `swift-institute/Research/docc-multi-target-documentation-aggregation.md` (committed `b015b60` in the Research repo). Surveyed swiftlang/swift-docc issues #255 and #331, swift-docc-plugin 1.4.0–1.4.6 release notes, Swift Forums threads on combined documentation and `docc merge`, SE-0409 (public import). Cross-referenced prior internal research `docc-search-capabilities-and-merged-site-strategy.md`. Applied Cognitive Dimensions framework per `[RES-025]`. Six recommendations (R1–R6), status: RECOMMENDATION.

**Resolution via CI `xrcrun docc merge`**: principal accepted that `swift-docc-plugin` would be added to `Package.swift` if it solved the defect — but I surfaced that neither `swift-docc-plugin` nor `xcrun docc merge` fix the underlying `@_exported` limitation; they just stitch per-target archives (each retaining its own full docs) under a synthesized root. Verified locally: merged archive has the umbrella's landing + 6 catalog routes + tutorial preserved, and per-symbol full docs are reachable via variant catalog routes.

Chose `xcrun docc merge` over the SPM plugin to preserve `[MOD-002]` zero-external-dependencies invariant. CI updated `794449e`; README updated with a "Distribution: the combined archive" subsection per research Recommendation R2 documenting the umbrella-as-navigation-hub + variant-catalogs-as-per-symbol-reference pattern.

**Supervision terminated via `[SUPER-010]` Success**: 9 of 9 ground-rules entries verified end-to-end, 8 of 8 acceptance criteria verified. HANDOFF.md stamped with verification status per `[SUPER-011]` and deleted per `[HANDOFF-016]`.

**Total commits**: 12 on `swift-property-primitives/main` + 1 on `swift-institute/Research` (`b015b60`). No commits on swift-primitives superrepo.

**Handoff cleanup per `[REFL-009]`** — 11 files found across the Developer workspace; bounded cleanup authority produced this triage table:

| Handoff file | Triage outcome |
|--------------|----------------|
| `swift-property-primitives/HANDOFF.md` | **deleted** — this session's handoff; Success termination; all 9 supervisor ground-rules verified, all 8 acceptance criteria verified, stamped per `[SUPER-011]` before deletion |
| `/Users/coen/Developer/HANDOFF.md` | out-of-session-scope — not authored, not worked, not touched |
| `/Users/coen/Developer/HANDOFF-executor-main-platform-runloop.md` | out-of-session-scope |
| `/Users/coen/Developer/HANDOFF-io-completion-migration.md` | out-of-session-scope |
| `/Users/coen/Developer/HANDOFF-migration-audit.md` | out-of-session-scope |
| `/Users/coen/Developer/HANDOFF-path-decomposition.md` | out-of-session-scope |
| `/Users/coen/Developer/HANDOFF-primitive-protocol-audit.md` | out-of-session-scope |
| `/Users/coen/Developer/HANDOFF-worker-id-typed-retype.md` | out-of-session-scope |
| `/Users/coen/Developer/swift-institute/HANDOFF-string-correction-cycle.md` | out-of-session-scope |
| `/Users/coen/Developer/swift-institute/HANDOFF-typed-time-clock-cleanup.md` | out-of-session-scope |
| `/Users/coen/Developer/swift-institute/HANDOFF-windows-kernel-string-parity.md` | out-of-session-scope |

HANDOFF scan: 11 files found; 1 deleted, 0 annotated, 10 out-of-session-scope. No audit findings in this session, so `[REFL-010]` cleanup is a no-op.

**Concurrent user-authored changes** (taken into account via system-reminders): principal/linter split the test target into 5 per-variant targets (`swift-property-primitives/Package.swift`, commits `5ba78fe` / `30a8825` / `0e96b3c` / `6c2ac46`), relocating existing test files and adding smoke coverage for Typed + Consuming. Tests remained 16 passing through the Package.swift restructure.

## What Worked and What Didn't

### Worked

- **`[SUPER-014a]` in-absentia model held**. I queued two class (b)→(c) escalations while the principal was away; they re-engaged live and answered both. Verification table in HANDOFF.md carried the queued escalations without drift.
- **Empirical symbol-graph JSON inspection** was the right next step when the init-empty symptom persisted after doc enrichment. Opening `property_primitives/property/init(_:).json` and comparing against `property_primitives_core/property/init(_:).json` gave a clean root cause in two reads — one archive has `abstract: null`, the sibling has `abstract: "Creates a..."`. Better than any amount of enriched prose would have diagnosed.
- **`/research-process` invocation at the right moment**. The principal's question "can you do /research-process on the latest for docc, and how to idiomatically do this?" was the right time — the diagnostic had found the structural issue, external prior art was needed to confirm the ecosystem-idiomatic response. Tier 2 (cross-package, reversible, no semantic commitment) was the right classification.
- **`xrcrun docc merge` local verification BEFORE committing CI**. Ran the full recipe locally against the 6 archives already in DerivedData; inspected the merged archive's symbol-graph JSON and sidebar structure; confirmed preserved tutorial + preserved per-catalog abstracts — THEN committed the CI change. Caught the "merge doesn't fix the umbrella stub" finding before writing README claims about it.
- **Zero-external-dependencies invariant preserved** by recognizing `xcrun docc merge` as the underlying mechanism the SPM plugin wraps. The principal explicitly said plugin-adoption was acceptable; I surfaced that it wasn't required for our use case. Honest trade-off analysis over reflexive acceptance.

### Didn't work

- **Phase 1 audit missed the `_modify`-without-`_read` compile error** in canonical usage examples across inline docs and Phase 3/4 articles. Only caught at Phase 5 when `swift test` compiled the tutorial verification file. Swept and fixed at `941d89a`, but should have been caught at Phase 1 — the audit inspected prose-content compliance but not example-code compilation.
- **First attempt at fixing init-empty was symptom-patching, not diagnosis**. I enriched `Property.init(_:)` with a Discussion paragraph + Example snippet + richer Parameter doc — hypothesis: minimal-abstract rendering quirk. When the principal's re-check showed still-empty, THEN I ran symbol-graph inspection. The ordering should be inverse: diagnose the data path first, then decide whether to enrich. Pattern: enrichment-before-diagnosis.
- **Initial prior-art survey missed the internal Research corpus**. My `/research-process` run started with WebSearch + WebFetch for external DocC commentary. Only after appending the new research entry to `_index.json` did I notice the prior doc `docc-search-capabilities-and-merged-site-strategy.md` in the file listing — directly adjacent prior art that had already validated `docc merge` at the institute-site level. `[RES-004a]` says "existing conventions MUST be consulted"; I interpreted that as "external conventions" but the rule's intent is broader.
- **Getting-Started article and GettingStarted tutorial were authored without a duplicate-detection pass**. I produced both in Phase 4 and Phase 5 respectively, with materially the same Stack-with-push-and-peek worked example. The duplication was visible to any reader doing a side-by-side compare, but I didn't look. Principal caught it at render time; class (c) re-handoff-back-to-live-supervision turned a structural defect into a committed fix but cost one extra iteration.
- **`_index.json` Python rewrite introduced ASCII-escape noise** on unchanged entries (— became `—`, etc.), producing a 191-line deletions diff for what should have been a 1-entry addition. Fixed by re-running with `ensure_ascii=False`. Minor — amended into the commit — but the initial dump made the diff unreadable for review.

## Patterns and Root Causes

### The "enrichment before diagnosis" anti-pattern

When a rendering defect surfaces — an empty page, a missing section, a broken link — the instinct is to add more content to the source. Make the doc comment longer. Add an example. Write a Discussion paragraph. The hypothesis underlying each of these is "DocC stripped the content because it was too thin; make it substantive and DocC will render it."

That hypothesis is sometimes right (some tools do skip whitespace-only sections). It is mostly wrong. The correct first step is to inspect the data path — open the symbol-graph JSON, diff it against a known-working sibling, locate where the data drops out. **Source → extraction → data → render**; the defect can live at any of four stages. Adding source is only the right fix if stage 1 is the defect.

In this session, the init-empty defect was at stage 2 (extraction via `@_exported`, docs are stripped). Enriching source (stage 1) had zero effect. The 2-minute JSON inspection would have given the answer before the 10-minute enrichment pass.

This pattern has a corollary: **the enrichment pass is measurable effort that produces zero diagnostic signal**. If the enrichment doesn't fix the symptom, you have *not* learned anything about where the defect is; you've just eliminated one hypothesis with a slow experiment. Symbol-graph JSON inspection is faster and strictly more informative.

### Archive-per-module vs archive-per-distribution — the load-bearing mental model

DocC's design treats each Swift module as the unit of documentation. Each target's `.doccarchive` is scoped to the symbols the target declares; re-exports are cross-references, not declarations. This is the **archive-per-module** mental model.

Consumers live in a different model — they `import Property_Primitives` (the umbrella) and expect "Property Primitives" documentation to be a single coherent artifact. This is the **archive-per-distribution** mental model.

The two don't compose automatically. `@_exported` re-exports symbols into the consumer's namespace, but the umbrella's archive doesn't inherit the re-exported symbols' docs — because those docs belong to the module that declared them, not to the umbrella. `docc merge` and `--enable-experimental-combined-documentation` both bridge the two models by stitching per-module archives under a synthesized root, preserving each archive's data.

Once this mental model is in place, every symptom in this class predicts correctly: init-empty in umbrella, cross-module `` ``Symbol`` `` ref failures at docbuild time, cross-catalog `<doc:>` link failures, "Mentioned in" backlinks auto-generating but forward links to sibling modules not. All four are the archive-per-module model surfacing. All four have the same fix-shape (navigate via the declaring archive's route; don't try to fix DocC to aggregate docs on re-export).

The research doc captured this framing in the "theoretical grounding" section. That framing generalizes beyond property-primitives to every Swift Institute package using the Core + variants + umbrella shape — which is most of them.

### Convention consultation applies to the internal corpus, not just external prior art

`[RES-004a]` says "existing conventions MUST be consulted" before creating research. I read "conventions" as "naming rules, design guidelines, etc." — external-authoritative sources. The rule's intent is broader: the ecosystem's own Research/ corpus is the first stop, because prior research about the same topic often already exists.

In this session, `docc-search-capabilities-and-merged-site-strategy.md` (RECOMMENDATION, prior Tier 2 research) had already validated `docc merge` at the swift-institute.org site level. That validation was directly applicable to my research's Option D. I missed it during the initial survey and found it only after appending to `_index.json` — pure luck that `git diff _index.json` showed adjacent entries.

The gap: `[RES-004a]` doesn't explicitly call out "grep the Research/ corpus" as step 0. In practice, prior internal research is often stronger than external prior art (same team, same ecosystem, resolved decisions) and should be the first thing consulted. A one-line extension to `[RES-004a]` would close this.

### Duplicate-content detection at authoring time vs spot-check time

The Getting-Started article and GettingStarted tutorial were authored independently in Phase 4 and Phase 5 using the same canonical `Stack<Element>` example with `push.back(x)` / `peek.back`. I didn't diff them. The principal diffed them at render-check time and caught the duplication.

The fix (drop article, absorb into README) was mechanical once the duplicate was surfaced. But the authoring-time omission was: **when two artifacts cover "getting started," the content-overlap check is not optional**. The four-layer audience model in the `/documentation` skill explicitly differentiates tutorial (Layer 4, learners) from article (Layer 3, concept readers). If both layers describe the same Stack build, that's a failure mode — the article should cover a different axis (motivation + design pattern + variants) and the tutorial should carry the hands-on build.

The catch pattern is: when Phase 4 authors a topical article named "Getting-Started" and Phase 5 authors a tutorial named "GettingStarted," the author MUST compare the bodies before committing. A one-line check in `/documentation` skill's authoring guidance ("if an article and a tutorial cover the same material, collapse to tutorial-only and move supplementary content to README") would make this mechanical.

## Action Items

- [ ] **[skill]** modularization: Add a new rule — `[MOD-020]` Documentation-Fidelity Consequences of Multi-Target + Umbrella Shape. Document that `@_exported public import` re-exports symbols but strips doc comments; the ecosystem mitigation is `xrcrun docc merge` distribution builds; per-symbol docs live in the declaring module's archive. Reference `swift-institute/Research/docc-multi-target-documentation-aggregation.md`.
- [ ] **[skill]** research-process: Extend `[RES-004a]` Convention Consultation with an explicit "step 0" — grep the internal `Research/` corpus for topic keywords before starting external prior-art survey. Internal prior research is often stronger than external commentary and often already answers the question.
- [ ] **[blog]** "DocC archive-per-module vs archive-per-distribution: what `@_exported` does to your umbrella's docs." Publication candidate grounded in the property-primitives case study; aligns with the Swift-DocC team's open call for real-world multi-target usage feedback on swiftlang/swift-docc#255.
