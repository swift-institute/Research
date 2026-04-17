# Swift Institute Whitepaper: Page Design Research

<!--
---
version: 1.0.0
last_updated: 2026-04-17
status: RECOMMENDATION
tier: 2
---
-->

## Context

The swift-institute.org DocC catalog plans to add a page called **Whitepaper** under the homepage's "Go deeper" topic group (currently containing `Research` and `Experiments`). Its intended purpose is to name the loop between the institute's four public artifact types — design question → research document → experiment → code → blog post — which `Research.md` and `Experiments.md` today only gesture at in their closing paragraphs.

Before drafting the page, three open questions needed resolution:

1. **Length / depth.** "Whitepaper" connotes genre weight. The institute's minimal-content philosophy argues for brevity. What does the genre itself demand?
2. **Sections.** Which skeleton best fits a page whose subject is a methodology loop rather than a product, protocol, or position?
3. **Voice.** First-person (matching the Blog namespace) or institutional third-person (matching `Research.md` / `Experiments.md` / `Layers.md`)?

Initial recommendations (600–900 words, four sections, institutional voice) were staged in the page's handoff document but held pending prior-art survey. This investigation grounds those recommendations in empirical data on the whitepaper genre and on comparable research-institute methodology pages.

**Trigger**: Design decision during implementation. [RES-001] Investigation, [RES-002a] ecosystem-wide scope.

**Scope and tier**: The page is single but externally visible and precedent-setting for future institutional pages. Per [RES-020], **Tier 2 (Standard)** — bounded scope, medium cost of error, expected lifetime of several years, precedent-setting but reversible. [RES-021] Prior Art Survey required; [RES-026] citations required.

---

## Question

What structure should the swift-institute.org Whitepaper page take — length, section skeleton, and voice — given the whitepaper genre's own conventions and the handful of research institutes that have published comparable methodology pages?

Sub-questions:

1. What sub-types does the "whitepaper" genre subdivide into, and which sub-type fits the Institute's page?
2. What sections are load-bearing across those sub-types?
3. What length does each sub-type occupy?
4. What reader expectations attach to the word "Whitepaper"?
5. How do comparable research institutes (AI labs, academic labs, industrial-research labs) present their methodology publicly?
6. Has any institute publicly named a four-node methodology loop (research → experiments → code → publication)?

---

## Prior Art Survey

### Genre taxonomy and reader expectations

Sources: [Wikipedia — White paper](https://en.wikipedia.org/wiki/White_paper), [Wikipedia — Command paper](https://en.wikipedia.org/wiki/Command_paper), [Purdue OWL — White Papers](https://owl.purdue.edu/owl/subject_specific_writing/professional_technical_writing/white_papers/index.html), [Content Marketing Institute](https://contentmarketinginstitute.com/content-creation-distribution/how-to-write-an-exceptional-white-paper-for-your-b2b-brand-examples), [Uplift Content — length](https://www.upliftcontent.com/blog/white-paper-length/), [Klariti](https://klariti.com/2017/06/17/what-is-a-white-paper/), [Wikipedia — Position paper](https://en.wikipedia.org/wiki/Position_paper), [Wikipedia — Technical report](https://en.wikipedia.org/wiki/Technical_report).

The genre descends from UK government "command papers" — authoritative policy documents presented "by His Majesty's Command" and inviting opinion on announced positions (Doerr, 1971, via Wikipedia). Its modern usage fragments into sub-types:

| Sub-type | Purpose | Typical length | Voice | Canonical example |
|----------|---------|----------------|-------|-------------------|
| Government command paper | Announce policy, invite opinion | Book-length, Cmd./Cmnd./Cm./CP numbered | Formal, impersonal | Churchill White Paper 1922 |
| B2B marketing | Persuade buyer, generate leads | ~2,500–4,000 words / 6–12 pages | Formal, direct, pre-sales | Vendor content libraries |
| Technical (software/research) | Explain technology, document trade-offs | Avg 4,038 words (technical audience); range 840–8,120 (Uplift) | Technical, specification-like | Vendor engineering whitepapers |
| Protocol design (Nakamoto-style) | Specify protocol + argue correctness | Short (Bitcoin: 9 pages / ~3,500 words) | Academic "we" + formalism | Bitcoin (2008); Ethereum Yellow Paper |
| Position paper (academic) | Argue viewpoint without implementation | Workshop-scale, 2–6 pages | Scholarly | ACM/IEEE workshop position papers |

**Reader expectations** (Purdue OWL; Wikipedia; Klariti):

- **Authority.** "Authoritative and informative in nature" (Purdue OWL). The word is shorthand inherited from government provenance; readers expect institutional voice, not a personal post.
- **Substance, not brevity.** Genre norm is 2,000+ words minimum. Foleon gives 6–12 pages as default length. A reader who sees "Whitepaper" and lands on a 500-word page feels misled.
- **Thesis, not just description.** Purdue OWL: "to advocate that a certain position is the best way." Klariti: "formal, direct, business orientated."
- **Problem → solution arc.** The backgrounder / numbered-list / problem-solution trichotomy (Graham, *White Papers For Dummies*, via Wikipedia) is the canonical B2B sub-taxonomy; all three center a problem.
- **Sponsor-identified.** Readers expect to know whose paper it is (Wikipedia: "the sponsor's philosophy").
- **Evidence-backed.** CMI: "facts and evidence … data from credible sources, case studies, expert quotes."

### Technical whitepaper structural patterns

Sources: [Bitcoin whitepaper](https://bitcoin.org/bitcoin.pdf), [Ethereum Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf), [Ethereum Whitepaper](https://ethereum.org/en/whitepaper/), [CNCF Cloud Native AI](https://www.cncf.io/reports/cloud-native-artificial-intelligence-whitepaper/), [NIST CSWP 52](https://csrc.nist.gov/pubs/cswp/52/firmware-based-monitoring-for-bus-based-computer-s/final), [Zig — In-depth Overview](https://ziglang.org/learn/overview/), [Rust Foundation](https://rustfoundation.org/), [Apache Software Foundation](https://www.apache.org/foundation/).

Length clusters in the **3–10k word band**: Bitcoin ~3,500 words; CNCF AI ~28 pages; NIST CSWP 52 13 pages; Zig overview ~6,500 words; Ethereum Yellow Paper ~24 pages of dense formal notation. Foundation mission pages (Apache, Rust Foundation) are <1,000 words and **do not bear the "Whitepaper" name** — they are mission pages, a different genre.

**Load-bearing sections** (present in ≥4 of 5 technical/institutional whitepapers surveyed):

| Section | Present in | Absent in |
|---------|------------|-----------|
| Abstract / Executive Summary | Bitcoin, Ethereum Yellow, CNCF AI, NIST CSWP 52 | Zig overview, Rust / Apache pages |
| Numbered Introduction | Bitcoin, Ethereum Yellow, CNCF AI, NIST CSWP 52 | Zig, Rust, Apache |
| Conclusion | Bitcoin, Ethereum Yellow, Ethereum WP, CNCF AI, NIST CSWP 52 | Zig, Rust, Apache |
| References / Further Reading | Bitcoin, Ethereum Yellow, Ethereum WP, CNCF AI, NIST CSWP 52 | Zig, Rust, Apache |

**Structural signatures by sub-type**:

| Sub-type | Skeleton |
|----------|----------|
| Protocol / formal spec | Abstract → numbered narrative → conclusion → references (± lettered appendices) |
| Platform vision paper | Prior art → proposal → applications → open concerns → conclusion |
| Foundation / working-group | Exec summary → framing → challenges → recommendations → conclusion → references → glossary |
| Language overview | Feature catalogue, one design claim per heading, no fixtures |
| Foundation mission page | 4–6 pillars, aspirational, no fixtures |

**Surprising absences** in the technical-whitepaper survey:

- **No "Methodology" section** in Bitcoin, Ethereum Yellow, Ethereum WP, Zig, CNCF, or NIST. The label is an academic-paper convention that does not port to whitepapers.
- **No "Related Work" as a peer numbered section** — it appears at most as a sub-section of the Introduction (Ethereum Yellow §1.2).
- **No "Results" / "Evaluation" section** anywhere. Whitepapers are design documents, not experimental reports.
- **Language overviews (Zig, "Why Rust") omit the entire academic skeleton** — no abstract, no numbered sections, no conclusion, no references. They are thesis-arranged claim lists.

### Research-institute methodology pages

Sources: [Anthropic — Core Views on AI Safety](https://www.anthropic.com/news/core-views-on-ai-safety), [Anthropic — Company](https://www.anthropic.com/company), [OpenAI — Charter](https://openai.com/charter/), [DeepMind — About](https://deepmind.google/about/), [DeepMind — Research](https://deepmind.google/research/), [Microsoft Research — About](https://www.microsoft.com/en-us/research/about-microsoft-research/), [MIT CSAIL — About](https://www.csail.mit.edu/about), [CMU SCS — About](https://www.cs.cmu.edu/about), [Allen Institute for AI — About](https://allenai.org/about), [Meta FAIR — Research](https://ai.meta.com/research/), [Stanford HAI — About](https://hai.stanford.edu/about), [Simon Willison — About](https://simonwillison.net/about/).

Twelve public-facing methodology / about pages surveyed. Findings:

**Dominant voice**: First-person plural "we" on 10 of 12 pages. Institutional third-person on 1 (MIT CSAIL). First-person singular on 1 (Simon Willison, solo-researcher).

**Dominant skeleton**: mission / values / team / history / research areas. Methodology proper is usually a small block. Microsoft Research's five italicised culture clauses ("We are rigorous and objective" / "We take calculated risks" / "We show and share our work" / "We move the conversation forward" / "We engage with the entire research ecosystem") are the densest methodology surface in the survey.

**Cross-cutting sections** (3+ of 12):

| Section concept | Pages |
|------------------|-------|
| Mission / Purpose | Anthropic Company, OpenAI, DeepMind About, MSR About, AI2, HAI, CSAIL — 7/12 |
| Core values / principles list | Anthropic Company (7), OpenAI (4), AI2 (4), MSR (5) — 4/12 |
| Leadership / Team | Anthropic, DeepMind, CSAIL, CMU, AI2, HAI — 6/12 |
| History / timeline | DeepMind, CMU, CSAIL, HAI, AI2 — 5/12 |
| Research areas / focus list | DeepMind, MSR, HAI, FAIR, CMU — 5/12 |
| "Engage with us" / get-involved | MSR, CMU, HAI, Anthropic, DeepMind — 5/12 |

**The loop question — the survey's most important finding.** No surveyed institute publishes a **standalone page** naming a multi-node methodology loop. The closest statement — and the only one that names an explicit loop — is Anthropic's "Safety Is a Science" pillar on the Company page:

> "We treat AI safety as a systematic science, conducting research, applying it to our products, feeding those insights back into our research, and regularly sharing what we learn with the world along the way."

That is a **three-node loop** (research → product → publication-and-feedback), named in a single sentence on a sub-page, not a dedicated methodology page. Every other surveyed institute either enumerates **parallel culture clauses** (Microsoft Research's five; Allen Institute's four values) or presents **research as a portfolio** of topics without naming how topics become code, publications, or external artifacts. Anthropic's Core Views essay names a *research taxonomy* (Capabilities / Alignment Capabilities / Alignment Science) and a portfolio of bets, but not a production-to-publication loop.

**Implication for the Swift Institute**: a dedicated Whitepaper that names a **four-node loop** — research document → experiment → code → blog post — is, against this prior art, differentiated. No existing institute has raised a methodology-loop statement to a top-level page. The Whitepaper would be doing work the genre has not seen done.

---

## Contextualization for Swift Institute

Per [RES-021], prior-art consensus must be tested against the ecosystem's own constraints before being accepted as guidance. The swift-institute.org Whitepaper page operates under several constraints that shift the generic recommendations:

1. **Sibling pages fix the voice.** `Research.md`, `Experiments.md`, and `Layers.md` are written in institutional third-person. First-person plural "we" would be inconsistent — even though it dominates the comparable-institute corpus (10/12). The Blog namespace uses first-person singular, reserved for authored commentary. The Whitepaper sits under "Go deeper" with the institutional-voice pages; sibling consistency is load-bearing for the reader's sense of the site as a coherent catalog.

2. **Minimal-content philosophy.** The institute explicitly aims for minimal content at launch. This argues against the 3,500+ word technical-whitepaper centroid (Bitcoin, CNCF, NIST) and the 6,900-word essay scale (Anthropic Core Views).

3. **DocC is web, not PDF.** The prior-art length bands are PDF-oriented (Bitcoin 9 pp, CNCF 28 pp, NIST 13 pp). On the web, readers scroll; the "feels like a whitepaper" bar is partly visual, not purely word count — headings, tables, and code blocks pace the page. A 1,500-word DocC article with five sections, two tables, and a code example can carry the visual weight of a short PDF whitepaper.

4. **References are already linked.** Research documents and experiments live in separate public repositories. A trailing "References" section on the Whitepaper would re-list links the body already carries. This differs from Bitcoin / Ethereum, where the references section introduces new material.

5. **The loop is differentiated — but must not over-claim.** No other institute has published a four-node loop page. That is a differentiated position. But the institute is young, the artifact corpus is still filling out, and the voice of the other pages is restrained. A 6,900-word essay in the Anthropic Core Views register would overclaim against current ecosystem maturity; readers arrive for a one-paragraph ecosystem after clicking through from the homepage, not a research-program manifesto.

---

## Analysis

### Options

| Option | Length | Skeleton | Voice | Match to genre | Match to constraints |
|--------|--------|----------|-------|----------------|----------------------|
| A — Short mission page | <800 words | 4–6 pillars, no fixtures | Institutional | Foundation mission page (Apache, Rust Fdn) | Fits minimal-content, but fails the "Whitepaper" name; silent rename barred by handoff ground rule #6 |
| B — Medium essay | 1,500–2,000 words | Thesis → Loop → Receipts → Why this shape → Relationship to other artifacts | Institutional | Closest to Zig "In-depth Overview" + Anthropic "Safety Is a Science" sub-skeleton | Bears the name credibly; respects minimal-content; matches sibling voice |
| C — Long methodology manifesto | 3,000+ words | Exec Summary → Introduction → Method → Portfolio → Discussion → Conclusion → References | Institutional or "we" | Full technical-whitepaper centroid | Overclaims against ecosystem maturity; violates minimal-content philosophy |
| D — Protocol-style formal paper | 2,500+ words | Abstract → numbered sections → appendices | Academic "we" | Bitcoin / Ethereum skeleton | Mismatches subject (methodology is not a protocol); formal voice inconsistent with siblings |

### Comparison against criteria

| Criterion | A (Short) | B (Medium) | C (Long) | D (Protocol) |
|-----------|-----------|------------|----------|--------------|
| Honours the name "Whitepaper" | ✗ | ✓ | ✓ | ✓ |
| Respects minimal-content philosophy | ✓ | ✓ (borderline) | ✗ | ✗ |
| Matches sibling voice | ✓ | ✓ | ✓ | ✗ |
| Differentiates the institute (names the loop) | ✗ (too thin) | ✓ | ✓ | ✓ |
| Sits comfortably alongside `Research.md` / `Experiments.md` | ✗ (under-weight) | ✓ | ✗ (over-weight) | ✗ (wrong register) |

### Honest length caveat

Option B at 1,500–2,000 words is a **negotiated position, not a genre match**. The technical-whitepaper genre floor is ~2,000 words; the centroid is ~4,000. Option B sits at the genre floor, honouring the name while respecting the institute's minimal-content constraint. It is minimal *for a whitepaper*, not minimal *as a page*. This also allows growth: as the institute's method matures and additional artifact types accumulate, the Whitepaper can extend without a rename.

---

## Recommendation

**Option B — Medium essay, 1,500–2,000 words, five sections, institutional third-person voice.**

### Section skeleton (revised from pre-research proposal)

1. **Thesis** — a short opening paragraph stating what the integrated ecosystem is and what the document is. Serves as the whitepaper's abstract without the label. Establishes authority and voice.
2. **The Loop** — design question → research document → experiment → code → blog post. Named as a sequence, with one sentence per node tracing how evidence moves through the institute. This is the page's differentiated contribution; no other institute has published this as a standalone statement.
3. **Receipts** — the claim that every load-bearing technical claim in the corpus is either written down as research or executable as an experiment. Distinguishes the institute from typical open-source documentation and gives the loop its epistemic teeth.
4. **Why this shape** — the properties the loop produces: correctness (claims are verified), composability (artifacts cross-link), long-term evolution (the record survives refactors). Grounds the method in its consequences, not its aesthetics.
5. **Relationship to other artifacts** — short closing paragraph distinguishing the Whitepaper from `Research.md`, `Experiments.md`, and the Blog. Mirrors the closing pattern on `Research.md` and `Experiments.md` (both end with an artifact-relationship paragraph). Makes the Whitepaper's unique contribution — naming the loop — explicit rather than implicit.

### Delta from initial recommendation

| Field | Initial (pre-research) | Revised (post-research) | Reason |
|-------|------------------------|-------------------------|--------|
| Length | 600–900 words | 1,500–2,000 words | 600–900 is below the "Whitepaper" genre floor (2,000+ words by genre norm). DocC visual weight partly substitutes for word count, but 600–900 is still too thin for readers who click "Whitepaper" and expect substance. 1,500–2,000 is a negotiated band at the genre floor, respecting minimal-content. |
| Sections | 4 (Thesis / Loop / Receipts / Why this shape) | 5 (+ Relationship to other artifacts) | Mirrors the closing pattern on sibling pages (`Research.md` and `Experiments.md` both end with an artifact-relationship paragraph). Makes the Whitepaper's loop contribution explicit in context rather than implicit. |
| Voice | Institutional | Institutional | Confirmed — "we" would be inconsistent with `Research.md` / `Experiments.md` / `Layers.md`; sibling voice fixes this choice despite "we" dominating the research-institute corpus. |

### What this recommendation explicitly does not do

- **Does not prescribe prose.** Section headings and intent are fixed; prose is drafted and approved separately.
- **Does not claim Anthropic's "Safety Is a Science" framing as precedent that would justify "we"-voice.** The loop framing is differentiated; the voice question is settled independently by sibling-page consistency.
- **Does not propose a dedicated References section.** Prior art supports it, but the Whitepaper's natural citations are `Research.md`, `Experiments.md`, and the public Research/Experiments repositories — already linked in prose. A trailing references section would duplicate inline links.
- **Does not resolve whether to rename the page.** Handoff ground rule #6 forbids silent rename; any name change requires explicit user decision.

---

## Constraints

| Constraint | Source | Effect on design |
|------------|--------|------------------|
| Handoff ground rule #1 (user confirmation before drafting) | `HANDOFF.md` | Recommendation held until user approves |
| Handoff ground rule #4 (do not rewrite Research/Experiments) | `HANDOFF.md` | Whitepaper must not absorb their material |
| Handoff ground rule #6 (renaming escalation) | `HANDOFF.md` | Cannot shift to "Method" / "Process" without explicit user decision |
| Minimal-content philosophy | Handoff + user statement | Length held at 1,500–2,000 words (genre floor, not centroid) |
| External-facing voice | Handoff | Whitepaper addresses visitors from first sentence |
| Sibling-page voice consistency | Existing `Research.md` / `Experiments.md` / `Layers.md` | Institutional third-person fixed |

---

## Outcome

**Status**: RECOMMENDATION — pending user approval of the revised length / section list / voice before drafting, per handoff ground rule #1.

**Recommendation**: Option B — medium essay, 1,500–2,000 words, five sections (Thesis / The Loop / Receipts / Why this shape / Relationship to other artifacts), institutional third-person voice. Primary deltas from the pre-research recommendation:

1. Length increased from 600–900 to **1,500–2,000 words** to clear the whitepaper genre's credibility floor while respecting minimal-content philosophy.
2. A fifth section (**Relationship to other artifacts**) added to mirror the closing pattern on `Research.md` / `Experiments.md` and make the Whitepaper's loop contribution explicit in context.

**Implementation path**: Present revised recommendation to user as an approve / redirect / amend prompt; draft `Whitepaper.md` against the approved shape; generate `card-whitepaper.svg` by copying `card-research.svg` and retargeting the label; add `<doc:Whitepaper>` to the `### Go deeper` topic group on the homepage; verify locally with `rm -rf .build && ./build-docs.sh`; amend the single `Initial release` commit and force-push; verify deploy via `curl -sI`.

**Deferred**: Section-level prose, card SVG label coordinates, exact heading wording — all to be produced during the drafting phase after user approval of the shape.

---

## References

### Genre and reader expectations

- [Wikipedia — White paper](https://en.wikipedia.org/wiki/White_paper)
- [Wikipedia — Command paper](https://en.wikipedia.org/wiki/Command_paper)
- [Wikipedia — Position paper](https://en.wikipedia.org/wiki/Position_paper)
- [Wikipedia — Technical report](https://en.wikipedia.org/wiki/Technical_report)
- [Purdue OWL — White Papers](https://owl.purdue.edu/owl/subject_specific_writing/professional_technical_writing/white_papers/index.html)
- [Content Marketing Institute — How to Write an Exceptional White Paper](https://contentmarketinginstitute.com/content-creation-distribution/how-to-write-an-exceptional-white-paper-for-your-b2b-brand-examples)
- [Uplift Content — How Long Is a White Paper?](https://www.upliftcontent.com/blog/white-paper-length/)
- [Foleon — How Long Is a Whitepaper in Marketing?](https://www.foleon.com/answers/how-long-is-a-whitepaper)
- [Klariti — What is a B2B White Paper?](https://klariti.com/2017/06/17/what-is-a-white-paper/)

### Technical whitepapers surveyed

- [Nakamoto — Bitcoin: A Peer-to-Peer Electronic Cash System (2008)](https://bitcoin.org/bitcoin.pdf)
- [Wood — Ethereum Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf)
- [Buterin — Ethereum Whitepaper](https://ethereum.org/en/whitepaper/)
- [CNCF — Cloud Native Artificial Intelligence Whitepaper (March 2024)](https://www.cncf.io/reports/cloud-native-artificial-intelligence-whitepaper/)
- [NIST CSWP 52 — Firmware-Based Monitoring for Bus-Based Computer Systems](https://csrc.nist.gov/pubs/cswp/52/firmware-based-monitoring-for-bus-based-computer-s/final)
- [Zig — In-depth Overview](https://ziglang.org/learn/overview/)
- [Rust Foundation](https://rustfoundation.org/)
- [Apache Software Foundation — About](https://www.apache.org/foundation/)

### Research-institute methodology pages

- [Anthropic — Core Views on AI Safety](https://www.anthropic.com/news/core-views-on-ai-safety)
- [Anthropic — Company](https://www.anthropic.com/company)
- [OpenAI — Charter](https://openai.com/charter/)
- [Google DeepMind — About](https://deepmind.google/about/)
- [Google DeepMind — Research](https://deepmind.google/research/)
- [Microsoft Research — About](https://www.microsoft.com/en-us/research/about-microsoft-research/)
- [MIT CSAIL — About](https://www.csail.mit.edu/about)
- [CMU School of Computer Science — About](https://www.cs.cmu.edu/about)
- [Allen Institute for AI — About](https://allenai.org/about)
- [Meta FAIR — Research](https://ai.meta.com/research/)
- [Stanford HAI — About](https://hai.stanford.edu/about)
- [Simon Willison — About](https://simonwillison.net/about/)

### Internal context

- `/Users/coen/Developer/swift-institute/swift-institute.org/HANDOFF.md` — supervisor ground rules and handoff context
- `/Users/coen/Developer/swift-institute/swift-institute.org/Swift Institute.docc/Research.md`
- `/Users/coen/Developer/swift-institute/swift-institute.org/Swift Institute.docc/Experiments.md`
- `/Users/coen/Developer/swift-institute/swift-institute.org/Swift Institute.docc/Layers.md`
