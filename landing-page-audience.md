# Audience Research for the swift-institute.org Landing Page

<!--
---
version: 1.0.0
last_updated: 2026-04-16
status: IN_PROGRESS
---
-->

## Context

Three prior landing-page research documents exist:

| Doc | Status | Role |
|---|---|---|
| `landing-page-marketing-perspective.md` | IN_PROGRESS | Identified 3 personas, no primary |
| `landing-page-docc-capabilities.md` | RECOMMENDATION | DocC 6.3 directive matrix |
| `landing-page-comparative-study.md` | IN_PROGRESS | 14 comparator sites, Apple precedent |
| `landing-page-user-journey.md` | RECOMMENDATION | Synthesis, 11 decisions |

All four documents reason about STRUCTURE within DocC. None identifies THE primary reader of `swift-institute.org`. Marketing-perspective §1 enumerates three personas — (a) evaluator, (b) early adopter, (c) curious developer — and notes the current page optimizes implicitly for (c). The synthesis implements 11 decisions without naming a primary persona. Result: the page serves three readers averaged, which is why it serves none.

This document locks the primary reader and the reader's mental model so downstream design can be evaluator-targeted rather than consensus-targeted. User has confirmed four inputs:

1. **Primary persona**: evaluator (audience (a) from marketing-perspective)
2. **Default mental frame**: iOS-centric Swift developer — Foundation assumed, cross-platform novel
3. **Cultural analog**: early-Point-Free follower (2017–2019 era subscribers)
4. **Design referent**: `https://www.swift.org` as structural model

These four inputs are assumed given; this document grounds them, tests them against known signal, and derives requirements.

## Question

Who is the typical reader of `swift-institute.org`, what mental model do they arrive with, what concrete claims and signals will make them bookmark / star / return — and what specific things fail them? The answer converts the abstract 3-persona model into a single focal reader whose needs the landing page must meet.

## Analysis

### 1. The primary reader: evaluator from HN or Swift Forums

From marketing-perspective §1 persona (a), confirmed by user:

- **Motivation**: saw this project mentioned in a forum/HN thread they were already skimming; clicked because the claim sounded interesting or implausible.
- **Goal**: decide in under a minute whether this belongs in their mental map of the Swift ecosystem. Not looking to adopt — looking to classify.
- **Time budget**: 15–30 seconds for the opening viewport to prove the claim; up to 1 minute if hooked.
- **Failure mode**: scrolls, sees text that looks like generic architecture documentation, pattern-matches to "another layered Swift thing," closes the tab. Does NOT click Topics, does NOT scroll far below the fold. The hero carries everything.
- **Conversion states** (ordered by ambition): close-tab → bookmark → star the GitHub org → read the blog post → share in a thread → try a package.

The evaluator is a judge, not a learner. They are measuring the project against everything else they've seen in Swift. Generic claims lose; specific claims with visible proof win. The 30-second bar is real — if the hero doesn't carry, the rest of the page is unread.

### 2. The default mental frame: iOS-centric Swift developer

Most working Swift developers write for Apple platforms. Their defaults shape what the landing page can assume, and what it must provoke carefully.

**Defaults this reader brings:**

- **Foundation is invisible and universal.** Every iOS project imports Foundation. `Date`, `URL`, `Data`, `FileManager`, `JSONDecoder`, `NSError` are part of the ambient toolkit. This reader has never opened a Swift project that does NOT use Foundation, and likely has never asked whether Swift could work without it.
- **Xcode is the IDE.** They assume SwiftPM works through Xcode, DocC previews in Xcode, and playgrounds are the tutorial medium.
- **UIKit / SwiftUI** is the UI framework lens. "Framework" means Apple framework.
- **Cross-platform Swift is novel.** Linux, Embedded, server-side Swift are categories they have heard of but haven't touched. Some of this reader subset writes Vapor or Hummingbird for side projects; the majority does not.
- **Native Swift ≡ Apple Swift** in their mental model. The distinction between "Swift-the-language" and "Apple's framework libraries" is abstract, not operational.
- **Prior Swift projects they've evaluated**: Point-Free (episodes, `swift-composable-architecture`), Apple's open-source work (`swift-algorithms`, `swift-collections`, `swift-foundation` rewrite, `swift-log`), Vapor, Hummingbird, Apollo, SwiftNIO, stdlib itself, community libraries (Alamofire, SnapKit, PromiseKit, etc.).

**Provocations this reader WILL feel** (productive friction, belongs in hero):

- "No Foundation" → *"Wait, no Foundation? What about `Date` and `URL`? Why would I want this?"* — a rethink ask that either compels them to read or loses them. Must be framed.
- "Works wherever Swift compiles" → *"OK, but does it work where I ACTUALLY compile? Will my iOS app work?"* — needs to not close doors.
- "Typed throws everywhere" → *"Nice, typed throws landed in Swift 6. Where's the catch?"* — aligns with a recent Swift 6 feature they may be curious about.
- "Specifications as namespaces (`RFC_3986.URI`)" → *"That's different. Does that actually work ergonomically?"* — visibly not what Foundation or stdlib does.

**Provocations this reader WON'T feel** (cost without payoff, not hero material):

- "Linear algebra primitives" / "Kernel event drivers" / any L1-specific surface — reads as over-engineering for their consumer lens.
- "Long-term evolution" / "timeless infrastructure" / "architecturally sound" — platitude vocabulary that any Swift project uses.
- "Apache 2.0 for L1–L3" — license detail below their 30-second budget.
- "Layer 1, Layer 2, Layer 3" as a first-paint concept — requires explanation the hero can't afford.

### 3. Cultural analog: early-Point-Free follower

Point-Free's subscriber base, especially in its 2017–2019 window, is a useful reference class. That cohort:

- Swift developers who care about **correctness, composition, and FP-influenced patterns**.
- Willing to invest in hour-long technical videos and long-form writing.
- Has **taste**: responds to sharp technical claims, rejects marketing vocabulary.
- Paying for subscriptions because the thinking is worth the money.
- Known vocabulary: phantom types, algebra, composable architecture, parsing combinators, reducers, typed throws, `some` vs `any`, Tagged types.

Swift Institute's ideal audience is the subset of this cohort that would ALSO be interested in a layered, spec-based ecosystem — readers who understand that Point-Free's TCA, Tagged, and Parsing libraries all solve particular correctness problems, and who would appreciate a broader ecosystem built on similar principles.

**Voice implications from this reference class:**

- Technical register. Specific claims. Falsifiable statements.
- Does not reward marketing language ("robust," "seamless," "industry-leading," "correctness & composability").
- Rewards name-drops of specific techniques: "phantom types," "typed throws," "specification-mirroring," "~Copyable."
- Tolerates density. An evaluator-from-Point-Free will read a short paragraph if the paragraph earns it.
- Reads hero code carefully — will notice if a type is made up vs. real, if an identifier is idiomatic vs. forced.

### 4. Design referent: swift.org structural extract

Analysis of `https://www.swift.org` (fetched 2026-04-16):

**Hero**: "Swift is the powerful, flexible, multiplatform programming language." Four-word tagline beneath: **"Fast. Expressive. Safe."** — three falsifiable claims.

**Code density**: five substantive code examples (8–11 lines each), each PAIRED WITH a claim:

- "Fast" → SIMD vectorization snippet (8 lines)
- "Expressive" → CLI tool with ArgumentParser (11 lines)
- "Safe" → Type-safe C interop (9 lines)
- "Adaptable" → Firmware register manipulation (10 lines)
- "Interoperable" → C++ `std::string` usage (8 lines)

Pattern: **claim → code that proves the claim**. Not code for code's sake; every block is evidentiary.

**CTA**: `[Install (6.3)]` in both header and hero — a verb ("install"), not a passive label ("Documentation").

**Navigation**: by reader goal — `Docs | Community | Packages | Blog | Install`. Not by content type.

**Blog/news surface**: blog link exists in nav; no featured post surface on the landing. Swift.org is authoritative enough that it does NOT need to prove aliveness via recent writing — Swift shipping IS the aliveness proof.

**Visual identity**: wordmark, light/dark/auto toggle, typography-driven. "Technical, confident, industry-focused, no personality flourishes" (verbatim from analysis). Restraint, not minimalism.

**Lower page**: use-case clusters (Cloud, CLI, Embedded) followed by platform clusters (iOS, Windows, ML/AI, Packages). Structure prioritizes "what you build" over "how you learn."

**Pattern summary for Swift Institute:**

| swift.org pattern | Adopt? | Notes |
|---|:---:|---|
| 3-word hero tagline + longer sentence | ✓ | Equivalent candidate: "Typed. Portable. Composable." or similar — three abstract claims |
| Each claim paired with ≤11-line code | ✓ | Highest-leverage adoption. Current page has only ONE code block proving ONE claim. |
| Verb-first CTA | ✓ | "View on GitHub" is passive. Swift Institute has no `swift-install` equivalent, but "Read the blog" or "Explore packages" are candidate verbs. |
| Nav by reader goal | ✓ | Already applied this session (Start reading / Start building / Understand the design / Go deeper). |
| No blog surface on landing | ✗ | **Diverge.** Swift.org doesn't need it; Swift Institute at alpha does. The blog is the aliveness signal. Keep "Latest writing" above Topics. |
| Wordmark + identity | (defer) | No asset exists. Revisit when ready. |
| Use-case / platform clusters below fold | — | Optional for Swift Institute. Would require named use cases — not yet clear what they are. |

### 5. What the evaluator must see in 15 seconds

Three questions the hero must answer, per marketing-perspective §2:

**Q1: What is this?** — must answer, not just sit there.
- Current root page partially answers via `@TitleHeading("A layered Swift package ecosystem")` and the abstract line.
- Must name SPECIFICS, not platitudes. "Correctness, composability, long-term evolution" are platitudes; every Swift library claims them.

**Q2: Why is this different?** — must name something the iOS-centric reader has NOT seen in their default frame.
- Strong candidates:
  - **Foundation-free** (a provocation that compels second-read)
  - **Spec-mirroring types** (`RFC_3986.URI` reads differently than `URL`)
  - **Typed throws everywhere** (recent Swift 6 feature, not yet default practice)
  - **Types encode meaning via phantom tags** (Tagged)
- The claim MUST be verifiable on the page. Swift.org pairs each claim with code. Swift Institute must too.

**Q3: Is it alive?** — recent writing, human presence, activity.
- Swift.org doesn't need to prove this; Swift Institute does.
- The "Latest writing" surface added this session targets this exactly.
- "Alpha" framing is acceptable IF paired with a dated recent artifact (a blog post from this month).

### 6. What fails the evaluator

Drawn from marketing-perspective §6 copy diagnosis and swift.org contrast:

| Failure | Why it loses the evaluator |
|---|---|
| Platitude abstract ("correctness, composability, long-term evolution") | Indistinguishable from any maintained Swift library. Zero differentiation. |
| Abstract architecture without code | "Layered architecture" without seeing what code looks like reads as over-engineering. |
| Defensive admonition first | Alpha warning before the pitch lands primes distrust. |
| Placeholder code in hero (`{concept}`, `{number}`) | Reads as unfinished, not illustrative. Drops credibility. |
| Claim contradicted by evidence | "Works wherever Swift compiles" then a table showing 2-of-4 platforms supported. |
| Made-up identifiers | Evaluators with taste spot `WidgetID`-style compound names instantly. Loses Point-Free-grade readers especially. |
| "Why this matters to me" absent | Principles framed as ecosystem properties, not reader benefits. Reader asks "so what?" and closes. |
| Over-serving intent 2 (philosophy) | Five principles inline crowd out intent 1 (latest) and intent 3 (try). |

### 7. What converts the evaluator

Conversion signals, ordered by reader investment:

- **Close tab** (failure): hero didn't prove anything; next time the project is mentioned in a thread, the reader doesn't recognize it.
- **Bookmark** (weakest conversion): hero carried a sharp claim; reader wants to come back but isn't ready to engage.
- **Star the GitHub repo**: either (a) the claim resonated enough to tag it for later, or (b) a social signal — reader is vouching for it to their circle.
- **Read the blog post**: reader invested a few minutes past the landing. The blog must then pay off — dated, specific, technical, human voice.
- **Share in a thread**: reader evangelizes on behalf of the project. Requires a sharp enough claim to carry across 1 sentence in a forum reply.
- **Try a package in a toy project**: full technical engagement. Far below the 30-second budget; requires Getting Started quality and demonstrable ergonomics.

**Signals that produce these states** (from the hero alone):

1. **A concrete technical claim not seen elsewhere.** "Specifications as namespaces" (`RFC_3986.URI`) is one. "No Foundation at any layer" is another. Tagged-as-hero is a third. Each is one sharp thought, not a menu of five.
2. **Code that makes the reader think "huh, nice."** Small, real, idiomatic, produces a visible compile-error or visible type refinement. The current Tagged / `timer == session → compile error` block does exactly this.
3. **Dated recent writing.** A blog post from this month, with a title, a date, and a first sentence visible on the landing. Converts "mostly a README" into "someone is building this now."
4. **A name or a voice.** Evaluators convert higher when they can place a person behind the work. Point-Free is Brandon + Stephen. Swift Institute is Coen. The blog post carries the voice; the landing does not currently.
5. **GitHub org link.** `View on GitHub` is passive, but it is the evaluator's fastest verification path for aliveness (commit history, issue activity, star count). The CTA exists; the label could be verb-ed ("Browse packages").

## Outcome

**Status: IN_PROGRESS** — pending user confirmation and review. Will advance to RECOMMENDATION once requirements below are confirmed; to DECISION once a new landing-page implementation derived from this doc has shipped and verified.

### Summary findings

1. **Primary reader: evaluator from HN / Swift Forums**, 15–30 second budget on the opening viewport, will not click Topics if the hero fails, converts via bookmark → star → blog read.

2. **Default frame: iOS-centric Swift developer.** Foundation assumed. Cross-platform Swift is novel. "No Foundation" is a provocation that compels second-read or loses them entirely — needs careful framing.

3. **Cultural analog: early-Point-Free follower.** Taste-oriented, correctness-interested, rewards sharp technical claims, punishes marketing vocabulary. Will spot made-up types instantly.

4. **Design referent: swift.org structural pattern applies selectively.**
   - Adopt: 3-claim tagline + paired code proving each claim; verb-first CTA; reader-goal nav.
   - Diverge: keep the blog surface on the landing (Swift Institute at alpha needs the aliveness signal that swift.org does not).
   - Defer: visual identity asset (no artifact exists yet).

5. **The current root page (as of this session's edits) serves the evaluator POORLY.**
   - The layers-composition code block I added this session is weaker for the evaluator than the Tagged compile-error block it replaced. The evaluator gets a 6-line visceral demo from Tagged; the 12-line layers demo is longer, more abstract, no visible compile error. The marketing doc's original recommendation to keep Tagged was correct for this audience.
   - The abstract ("types encode meaning, errors declare their shape, no layer depends on Foundation") is already in swift.org's 3-claim style — but the page provides only ONE paired code block, not three. That is the missing evidentiary pattern.

### Hard requirements for the landing page (for evaluator)

Derived from §1–§7, ordered by priority:

1. **Hero abstract must name ≥1 concrete, falsifiable, non-platitudinal claim.** The current 3-claim abstract ("types encode meaning, errors declare their shape, no layer depends on Foundation") already meets this. KEEP.

2. **Hero must include code proving ≥1 of the 3 claims in the abstract.** Candidate: the Tagged phantom-type example (proves "types encode meaning" via visible compile error).

3. **"Latest writing" surface stays above `## Topics`.** Diverges from swift.org but required by Swift Institute's alpha status: the evaluator needs an aliveness signal, and the blog is the only dated artifact.

4. **CTA label should be verb-first.** Current: "View on GitHub" (passive). Candidate improvements: "Browse packages" / "Read the blog" / (retain "View on GitHub" if no better verb presents). Low-priority; replace only if a better verb lands.

5. **Topics grouping by reader goal** (Start reading / Start building / Understand the design / Go deeper) — already implemented; KEEP.

6. **No platitudes.** Specific instances flagged in marketing-perspective §6 — do not reintroduce. "Correctness, composability, long-term evolution" is specifically off-limits.

7. **No hero-level architecture abstraction.** "Layered architecture" without code is too abstract for the evaluator's 15-second bar. The architecture page can explain layers; the hero cannot lead with them. (This invalidates my replacement this session — the layers-composition block leads with architecture abstraction instead of a falsifiable claim + proof.)

8. **Alpha admonition stays small and low.** Already moved to `@Small {}` at page end this session; KEEP.

### Open questions for user resolution

1. **Hero code — one block or three?**
   - Option **A (one block, conservative)**: keep the Tagged phantom-type block as the sole hero code. Matches marketing-perspective §5 (d) "hybrid" recommendation. Lighter above the fold, leaves room for the Latest writing surface.
   - Option **B (three blocks, swift.org-style)**: pair each claim in the abstract with a code block — types-encode-meaning (Tagged), errors-declare-their-shape (typed throws example), no-Foundation (specification-mirroring or similar). Heavier above the fold, stronger evidentiary pattern.
   - Option **C (two blocks)**: Tagged + one other. Compromise.
   - **Recommendation**: **A** for the first cut — the evaluator's 30-second budget favors compression, and the existing Latest writing surface adds weight to the opening viewport. Option **B** can follow once the structure is proven. Decision pending.

2. **Which code proves each claim if Option B is chosen?**
   - "Types encode meaning" → Tagged / phantom type compile-error (verified)
   - "Errors declare their shape" → a typed throws signature, e.g. `func parse(_ input: Input) throws(Parse.Error) -> Output` + a call site showing exhaustive switch — needs a real example with a real type
   - "No layer depends on Foundation" → a `Package.swift` dependency list + `import` statement showing absence of Foundation — code-flavored but less visceral; alternative is a claim + link to platform page

3. **CTA — is there a verb better than "View on GitHub"?**
   - "Browse packages" if a packages index page exists.
   - "Read the blog" directly points at the one dated artifact.
   - Keep "View on GitHub" if no better fits.

4. **Visual identity — when does this become a priority?**
   - Currently defaulted to DocC chrome. No wordmark, no identity asset.
   - Not blocking the evaluator, but adds polish once the hero copy settles.

5. **What about audiences (b) and (c)?**
   - Marketing-perspective identified (b) early adopter and (c) curious developer. This document prioritizes (a) evaluator per user input.
   - Open question: do (b) and (c) get served by the evaluator-optimized page, or are they actively UNDER-served?
   - Hypothesis: serving (a) well does not block (b) and (c). The Latest writing surface serves (b). The Principles article serves (c). The evaluator-first hero doesn't prevent (b) and (c) from finding what they need one click down.

### What this document does not claim

- **Does not propose a final landing-page copy rewrite.** That's the downstream implementation task.
- **Does not prescribe specific code blocks.** Options exist for the hero code; user picks.
- **Does not invalidate the other three research docs.** They describe WHAT DocC allows and WHAT comparable sites do; this doc answers WHO the page is for and derives hard requirements from that.
- **Does not make the current landing page wrong in its entirety.** Structural decisions from the synthesis (Topics groups, Latest writing, Principles article, `@CallToAction`) remain correct. The specific hero-code swap I made this session (Tagged → layers-composition) is the mistake to revert.

## References

- `/Users/coen/Developer/swift-institute/Research/landing-page-marketing-perspective.md` — 3-persona analysis; §5 recommended keeping Tagged as hero
- `/Users/coen/Developer/swift-institute/Research/landing-page-user-journey.md` — synthesis with 11 decisions
- `/Users/coen/Developer/swift-institute/Research/landing-page-docc-capabilities.md` — DocC 6.3 directive matrix
- `/Users/coen/Developer/swift-institute/Research/landing-page-comparative-study.md` — 14 comparator sites (to be re-integrated in v1.1)
- `/Users/coen/Developer/swift-institute/Research/documentation-docc-alpha-launch.md` — DECISION status, alpha voice lock
- `/Users/coen/Developer/swift-institute/HANDOFF.md` — task brief
- `https://www.swift.org` — design referent, fetched 2026-04-16
- `https://www.pointfree.co` — cultural analog reference class
