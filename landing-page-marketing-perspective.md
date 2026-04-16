# Marketing Perspective on Landing-Page UX

<!--
---
version: 1.0.0
last_updated: 2026-04-15
status: IN_PROGRESS
---
-->

## Context

The public alpha site at `swift-institute.org` is live. The handoff in `HANDOFF.md` identifies the initial user experience as subpar: "the first impression reads as API documentation, not as a project landing page. Progressive disclosure is weak, reader-intent routing is missing, and blog/latest-writing (the alpha's primary purpose) is buried."

The voice and content triage is already locked in by `Research/documentation-docc-alpha-launch.md` (status: DECISION): alpha-conservative tone, no exact package counts, no commercial-license commitments, no domain enumerations, no stewardship framing. That is not under discussion. What is under discussion is the **structure, sequencing, and reader journey** of the root page as presently shipped.

This document is one of three research inputs feeding a synthesis. The other two cover (a) DocC directive availability and (b) comparable technical-project landing pages. This one stays strictly in audience / journey / copy diagnosis, and deliberately does not propose implementations.

The analyzed artifact is `Swift Institute.docc/Swift Institute.md` as rendered by DocC in its current state (lines 1-105, final revision prior to this research pass). The HTTPS certificate is still provisioning, so the live site was not directly WebFetched; the analysis operates on the source-of-truth markdown, which DocC renders one-to-one for prose and Topics groups.

## Question

From a marketing and audience-journey perspective, does the current landing page at `Swift Institute.docc/Swift Institute.md` serve its three plausible audiences (evaluator, early adopter, curious developer) on their time budgets? What is wrong with the opening viewport, the click-through paths, and the visibility of the blog — which the handoff identifies as the alpha's primary purpose — and how do those problems compare when framed against what each audience actually needs?

## Analysis

### 1. Audiences

Three personas arrive at `swift-institute.org`. They do not overlap in motivation, time budget, or failure mode.

**(a) The Swift evaluator from a forum link or HN comment.**
Motivation: someone mentioned this project in a thread they were already skimming. They clicked because the claim sounded either interesting or implausible, and they want to know in under a minute whether it is worth a bookmark. They are not looking to adopt; they are looking to decide whether this belongs in their mental map of the Swift ecosystem.
Time budget: 15–30 seconds for the opening viewport to prove the claim; up to a minute if the opening hooks.
Failure mode: they scroll, see text that looks like generic architecture documentation, pattern-match to "another layered Swift thing," close the tab. They will not click to a sub-page. They will not read the Topics navigation. If the root page doesn't carry the pitch, the pitch never lands.

**(b) The early adopter referred by a colleague.**
Motivation: trusted human said "look at this." They want a signal that this is legitimate, active, and adoptable today — not vaporware, not a one-commit demo. They are willing to invest 5 minutes to form an opinion, and they will click if the clicks look rewarding.
Time budget: 5 minutes, distributed across ~3 page loads.
Failure mode: they arrive, see no dated artifact (no recent blog post, no "last updated," no commit badge), can't find a signal of aliveness, and come back "in a few weeks." The alpha never converts them.

**(c) The curious developer scanning the Swift ecosystem.**
Motivation: browsing, not goal-directed. They know the major players and want to see what else exists. They will read principles if principles are distinctive; they will skim philosophy if it's genuinely differentiated from what they've already seen.
Time budget: elastic — 2 minutes if bored, 20+ minutes if something catches.
Failure mode: the page reads as generic infrastructure marketing ("correctness, composability, long-term evolution" — Swift Institute.md line 8) that could apply to any library. They fail to form a memory; the next time someone mentions Swift Institute in a forum thread, they don't recognize it.

The landing page currently optimizes, implicitly, for (c) — it is a philosophy-first document. The handoff says the blog is the alpha's primary purpose, which points at (b) as the conversion target. And nothing on the page currently addresses (a)'s 15-second bar with any concrete differentiator.

### 2. The 15-second first-impression bar

In a cold scroll, the evaluator must learn three things above the fold: **what this is, why it's different, and whether it's alive.** The current root page answers one of those three.

Current opening (Swift Institute.md lines 1–26, as the visitor sees it after DocC chrome):

- Line 2: Page title `Swift_Institute` (DocC renders via `@DisplayName` as "Swift Institute" — line 5).
- Line 6: `@TitleHeading("A layered Swift package ecosystem")` — this is the subtitle DocC emits directly under the title.
- Line 8: "A layered Swift package ecosystem — primitives, standards implementations, and composed foundations — aimed at correctness, composability, and long-term evolution."
- Line 10: `> Important:` admonition about alpha status.
- Lines 12–26: The "Types encode meaning" section with the `Tagged<Timer, UInt64>` / `Tagged<Session, UInt64>` code block.

Diagnostic:

- **What this is**: answered by line 6 and line 8 combined. "Layered Swift package ecosystem" is accurate and clear. Grade: passing.
- **Why it's different**: line 8's second half, "aimed at correctness, composability, and long-term evolution," is the failure. Every Swift library claims those three things. Apollo, Vapor, SwiftNIO, Hummingbird, Point-Free's libraries, the stdlib itself — all three goals are table stakes. This sentence is indistinguishable from generic infrastructure marketing. Grade: failing.
- **Whether it's alive**: nothing above the fold signals recency, activity, or human presence. The alpha admonition (line 10) signals the opposite — it reads as "things might not work yet." No date, no "latest post," no recency cue. Grade: failing, and compounded by the admonition.

The "Types encode meaning" block (lines 12–26) is technically the strongest material on the page. The Tagged phantom-type example is concrete, distinctive, and verifiable — you can see the compile error and know exactly what you'd get. But it arrives **after** the generic sentence on line 8 and the alpha admonition on line 10. An evaluator who has already pattern-matched "generic architecture project" at line 8 may not reach line 14.

The more load-bearing question: is a code block the right opening hook? For audience (a) specifically, yes — Swift developers look at Swift code, and a phantom-type Tagged example is both distinctive and compact. But the code block does not by itself say *what problem this solves*. It says *this is the technique used*. Technique without problem is a craft demo, not a pitch.

**Recommendation for the synthesis**: the opening viewport needs one concrete, verifiable, distinctive claim before any code, before any admonition, before the principles sweep. A candidate shape (directional, not a rewrite): "Swift packages that compile without Foundation, express domain meaning in types, and can be adopted one at a time." That has three evaluator-grade hooks — no-Foundation, types-not-tests, package-granularity — each falsifiable on first read. The current line 8 has none.

### 3. The 5-minute path

For the early adopter (audience b), 5 minutes is roughly three page loads: landing → one article → one more article or one code sample. The optimal sequence is:

1. **Land**: confirm "this is a real, active project doing something specific."
2. **Click 1**: see the single most recent blog post or a dated artifact — confirms human-present-this-month.
3. **Click 2**: see either Getting Started (if they're ready to try) or Architecture (if they want one more round of "is this credible").

Current Topics sequence (Swift Institute.md lines 75–104):

- Start here: Getting Started, FAQ (line 79–80)
- Architecture: Architecture, Platform (line 84–85)
- Layers: Swift-Primitives, Swift-Standards, Swift-Foundations (line 89–91)
- How we work: Research, Experiments (line 95–96)
- Deep dives: Embedded-Swift (line 100)
- Blog: Blog (line 104)

Diagnosis:

- Blog is **sixth** in the Topics list. The handoff says the blog is the alpha's **primary purpose**. This is a direct contradiction between stated intent and information architecture.
- Under "Blog" there is only the umbrella link `<doc:Blog>`, which goes to an index page that itself contains only a single post (`<doc:Restarting-the-Blog>` per Blog.md line 13). That's two clicks from landing to the actual post. For an audience-(b) early adopter on a 5-minute budget, two clicks to see any dated content is one too many.
- "Start here" contains Getting Started and FAQ. That is correct for audience (b) *if* they've already been convinced. But the page doesn't convince them first — it presents principles, then a Topics menu. The convincing that should precede "Start here" is what's missing.
- "How we work" (Research, Experiments) is an unusual Topics group for a landing page. It signals process transparency — which is distinctive and matches the handoff's emphasis on research culture — but it's placed fourth, after Architecture and Layers. That ordering prioritizes self-referential architecture documentation over the evidence that the project is actively producing new thinking.
- The "Layers" group (Primitives, Standards, Foundations) is essentially the same information as "Architecture" with more clicks. It's redundant exposure of the same concept.

**The buried-blog problem is the central structural defect.** If the alpha's primary purpose is the blog, the primary path from landing must surface the blog. Currently it is last. Arguably worse: the Topics group is named "Blog" (singular concept), contains a single link, which resolves to an index with a single post. That's three levels of wrapping around what is effectively one article.

**Recommendation for the synthesis**: the 5-minute path wants the blog (or at minimum the latest post) surfaced at the top of Topics or — better — in the pre-Topics body of the root page, before the principles sweep. The question for the technical-perspective research is whether DocC supports embedding a featured article card on a module root page without bypassing DocC's chrome.

### 4. Reader-intent routing

Landing-page visitors typically arrive with one of three intents. Mapping them to the current page:

- **Intent 1: "I want to read the latest thinking."** Visible on first paint? No. The blog is sixth in Topics, and the Topics section is below the principles sweep and code blocks. Best case, it's ~6 scroll-screens down; worst case (long viewport with expanded principles), more.
- **Intent 2: "I want to understand the philosophy / why this exists."** Visible on first paint? Partially — lines 8, 12–26 deliver philosophy immediately. This intent is well-served.
- **Intent 3: "I want to try a package / see how to use this."** Visible on first paint? No. Getting Started is under "Start here" in Topics (line 79), which is below the fold for most viewports once the five principles and code blocks are rendered.

Of those three intents, **intent 1 matters most for an alpha launch where the blog IS the primary purpose.** The handoff is explicit about this. The current page buries intent 1 while serving intent 2 heavily. That is an alignment failure between stated mission and visible structure.

Intent 2 being well-served is not the problem — it's the *over-service* of intent 2 that is. The principles sweep runs from line 12 to line 72, which is five H3 sections, five code blocks or tables, and ~60 lines of prose. That is a philosophy article, not a landing-page introduction.

A defensible split: serve intent 1 in the first viewport via a visible latest-post surface, serve intent 2 via a compressed one-principle teaser that links to a full Principles article, and serve intent 3 via an obvious "Try a package" or Getting Started call-to-action near the top. The current page serves none of these three with visible priority — it serves intent 2 only, and does so at wall-of-text volume.

### 5. The principles question

The prior pass tried a 5-principles block and the handoff's "Dead Ends" section records that it was judged subpar ("too much content above the fold"). The current page *is* that same 5-principles block. It has not been revised down. Lines 12–72 are five H3s (Types encode meaning, Specifications as namespaces, Concrete errors, Foundation independence, Granular composition), each with prose + code/table.

From an audience-needs perspective, considering the four options:

**(a) Stay on root but compress.** Viable for audience (c) — the curious developer who likes principles — but still over-serves intent 2 at the cost of intents 1 and 3. Compressing helps, but it doesn't fix the allocation problem: even a compressed principles block still claims the above-the-fold real estate that the blog and recency signals need.

**(b) Move to a dedicated Principles article.** Best for audiences (a) and (b), who don't read principles lists on landing pages anyway. Audience (c) reaches the article in one click — acceptable for a 20-minute reader. The cost is that the root page loses its most concrete material (the Tagged code block is the single strongest hook on the page today). If the Principles article is moved, the root needs *something* equally concrete in its place. Moving principles without a replacement creates a hollow landing.

**(c) Replace with something else entirely.** Viable only if the replacement is as distinctive as the Tagged example. Candidates: a live latest-blog-post card, a single hero code example paired with one sentence, a "What's new" recency surface. This option is the most ambitious and the most correct for an alpha-launch prioritizing the blog.

**(d) Hybrid.** Keep *one* principle — the single strongest — on the root, and move the other four to a Principles article. The one that stays becomes the hero. My read: "Types encode meaning" with the Tagged example is the right one to keep, because it's the only one that can be demonstrated in six lines of code that compile-error visibly. "Specifications as namespaces" is close but less visceral. "Foundation independence" depends on prose and a table; it's abstract. "Concrete errors" is technical and niche. "Granular composition" is a Package.swift snippet that reads like any other Package.swift snippet.

**Recommendation from audience-needs reasoning**: option (d) is best served by the three audiences combined. Audience (a) gets one strong hook above the fold instead of five; audience (b) gets room for a recency signal in the reclaimed viewport space; audience (c) gets a dedicated Principles article they can read end-to-end if they want. The synthesis should decide between (d) and (c), with (c) being the more aggressive move and (d) the more conservative one that preserves the strongest current material. The one to reject outright is (a): compressing in place does not solve the buried-blog problem, it just takes slightly less space to cause the same problem.

### 6. Copy diagnosis

Reading the current root page critically, line by line. Sentences that earn their place versus sentences that are generic.

**Working (concrete, distinctive, falsifiable):**

- Line 14: *"The ecosystem encodes domain knowledge in the type system. Phantom types give zero-cost distinctions between values that share a representation but not a meaning; the compiler enforces constraints that tests can only approximate."*
  The phrase "constraints that tests can only approximate" is the single best sentence on the page. It's specific, it takes a position, and it implies a testable claim — you could write a Tagged example and verify it. This is the sentence the rest of the page should be measured against.

- Line 30: *"Types mirror the specifications that define them. The RFC or ISO identifier is the namespace. When you read a type name, you know which specification governs its behaviour."*
  Distinctive and concrete. Most Swift projects do not namespace by RFC/ISO identifier. This is a claim that differentiates the ecosystem from its neighbors and is verifiable in the `RFC_3986.URI` example that follows.

- Line 42: *"Throwing functions declare their error type. Callers get exhaustive switches, not catch-all blocks. The error type is part of the API contract, not an afterthought."*
  Strong. "Not an afterthought" is a deliberate jab at conventional `throws -> any Error`. Confident, specific, correct.

- Line 60: *"Resources with unique ownership — file descriptors, kernel handles, connection state — use `~Copyable` so the compiler tracks their lifecycle rather than deferring to runtime checks."*
  Concrete and distinctive. The list ("file descriptors, kernel handles, connection state") grounds the abstract claim; "rather than deferring to runtime checks" is a stance.

**Not working (abstract, generic, or self-referential):**

- Line 8: *"A layered Swift package ecosystem — primitives, standards implementations, and composed foundations — aimed at correctness, composability, and long-term evolution."*
  The subject is correct; the predicate is filler. "Correctness, composability, and long-term evolution" is the Swift package platitude trifecta. It applies verbatim to roughly every maintained Swift library. An evaluator reading this line has learned nothing distinctive.

- Line 10: *"This is an early public release. Packages are being published incrementally across three layers. Some package URLs in examples may not resolve until their release tags land."*
  Appropriate for a footer note, too defensive for above-the-fold. The second and third sentences are housekeeping that the casual visitor doesn't need in the first viewport. The `> Important:` admonition styling amplifies this — it reads as a warning, which primes distrust before the pitch has landed. Not a sentence that works well at line 10 specifically.

- Line 50: *"No Foundation import at any layer. The ecosystem provides its own timestamps, paths, buffers, and string processing, so the same types compile wherever Swift compiles."*
  The first sentence is strong. The second sentence ("provides its own ...") reads as a catalog that immediately feels long. "Wherever Swift compiles" is true but the following table (lines 53–58) then contradicts the implied breadth — it lists only two platforms as supported and two as coming-soon. Claim and evidence are in tension in consecutive paragraphs.

- Line 64: *"There is no umbrella import. Consumers depend on individual packages:"*
  The sentence is fine. The code block that follows (lines 66–71) uses `{concept}` and `{number}` template placeholders, which is the correct alpha-conservative choice given the voice-lock, but it makes the code block read as *unfinished* rather than *illustrative*. An evaluator may not parse the placeholder convention on a first pass.

- Line 73: *"The ecosystem spans three layers — [primitives, standards, and foundations](<doc:Architecture>) — each building only on layers below."*
  Fine as a pivot sentence. But it arrives after five H3 sections and is doing the work that line 8 should have been doing. The landing restates the layered claim three times (lines 6, 8, 73). Once is enough.

**Copy pattern worth calling out separately**: the page has no "why you should care" sentence. It has "what this is" (line 8), "what patterns are used" (the five principles), and "here's how to depend on it" (the final code block). It never says what happens to the reader if they adopt this. No benefit-to-the-reader sentence exists. The principles are framed as properties of the ecosystem, not as advantages to the consumer. A single "Adopting this means your Swift code X, Y, Z" sentence would shift the page from "here is a thing" to "here is what it does for you." That sentence is absent.

### 7. Blog visibility

**Confirmed: the blog is buried.** On the current root page:

- The word "Blog" appears **twice**: once in the Topics section heading at line 102 (`### Blog`) and once in the Topics item at line 104 (`- <doc:Blog>`).
- It is the **sixth and last** Topics group, below "Start here," "Architecture," "Layers," "How we work," and "Deep dives."
- There is no preview, no excerpt, no title of any post on the root page. The visitor must click into `<doc:Blog>`, land on Blog.md, see one additional link (`<doc:Restarting-the-Blog>` — Blog.md line 13), and click again to reach content.
- The Blog.md index page itself is minimal: lines 1–13, with "Technical writing from the Swift Institute ecosystem." as the only prose, and a single Topics item. This is a placeholder-shaped index.
- The actual post, `Restarting-the-Blog.md`, is strong material — a dated narrative account of the ecosystem build, an audit table, a methodology disclosure about AI-assisted writing. It's the single piece of content on the site that signals recency, human presence, and distinctive thinking. And it is three clicks and scrolls away from the landing experience.

From a marketing perspective, this is the single clearest defect. The handoff states the blog is the alpha's primary purpose, and the landing page treats it as the ecosystem's footer.

**What surfacing a latest blog post on the landing page itself would look like**, described as a user experience (not as an implementation):

- The visitor loads the root page. Above the fold, alongside or just below the identity statement, they see a compact card: the post title ("Restarting the blog: nine months, an ecosystem, and a way to write about it"), the date (or relative date — "posted 2 days ago"), and the first sentence or a one-line excerpt from the post.
- Clicking the card lands them on the post directly. One click, not three.
- The visual weight of the card is roughly equal to the identity statement — it signals that *new writing* is a first-class surface of this site, not a sub-sub-navigation destination.
- If multiple posts existed, the card would show the most recent and link to the Blog index for older posts. With one post, the card is the single post.

The synthesis needs to answer whether DocC's `@Links`, `@Row`/`@Column`, `@CallToAction`, or any combination of directives can produce a featured-post card on a module root page. That is a technical-perspective question. The marketing-perspective answer is unambiguous: **a featured post belongs above the fold on an alpha launch whose primary purpose is the blog**, and its current placement at position six of six Topics groups is the structural misalignment most worth fixing.

## Outcome

**Status**: RECOMMENDATION — this document is one input to a synthesis; final structural decisions await the other two research perspectives and explicit user resolution.

### Summary findings

1. **Three distinct audiences arrive at the landing page**; the current page optimizes implicitly for audience (c) — the curious developer scanning the ecosystem — and under-serves audiences (a) and (b), particularly the early-adopter (b) whose conversion depends on recency signals.
2. **The 15-second first-impression bar is not met** for audience (a). Line 8 is the hook, and line 8 is indistinguishable from generic Swift library marketing. The Tagged code block at lines 16–26 is the strongest concrete material on the page and arrives after the generic line 8 has already set expectations.
3. **The 5-minute path for audience (b) is blocked by the blog's position** as the sixth of six Topics groups, resolving to a near-empty index page. The handoff's statement that the blog is the alpha's primary purpose is directly contradicted by the information architecture.
4. **Three reader intents exist** — latest thinking, philosophy, try a package. The page over-serves philosophy and under-serves the other two. Of those, latest thinking is the most mission-critical for an alpha launch, and it is the least visible.
5. **The five-principles block is not right-sized for the root page.** The "Dead Ends" section of the handoff already recorded this judgment; the current page still carries the five-principles block. Of four placement options, either (c) replace with something else entirely or (d) keep one principle as hero + move rest to a Principles article is defensible. Option (a) compress-in-place is specifically rejected because it does not solve the buried-blog problem.
6. **Copy diagnosis identifies specific sentences worth preserving** (lines 14, 30, 42, 60) and specific sentences that are generic filler (line 8, line 10's second/third sentences, line 50's second sentence). There is no "benefit to the reader" sentence anywhere on the page.
7. **The blog is buried.** Sixth of six Topics groups, index is a placeholder, two clicks from landing to the only dated content on the site. A featured-post surface above the fold is the single highest-leverage structural change.

### Open questions for user resolution (beyond this research)

These are not answerable from marketing reasoning alone — they require either the technical-perspective research or explicit user direction:

1. **Principles placement — option (c) or (d)?** Both are defensible from audience needs. The choice turns on whether a dedicated Principles article is acceptable and whether the root page can sustain a single-principle hero without feeling thin. Recommend the user decide at synthesis time.
2. **Hero sentence above the fold — does the user want to replace line 8?** If yes, what concrete, distinctive, non-generic claim should it make? The alpha-voice lock constrains this (no counts, no stewardship framing, no license commitments), but a sharper differentiator is possible within those constraints. User input needed.
3. **Blog surfacing — depends on DocC capability.** Whether the blog can be featured above the fold via DocC's native directives is a technical-perspective question. If DocC cannot support it, the marketing priority (blog visibility) and the non-negotiable constraint (DocC as renderer) are in tension and require escalation, per the handoff's stated policy.
4. **Audience priority — is (b) the right primary target?** The handoff implies yes via the "blog is primary purpose" framing. This research treats that as given. If the primary audience is actually (a) the evaluator — someone who decides in 30 seconds whether this exists in their mental model — then the blog prioritization argument weakens and the hero-sentence argument strengthens. A brief user check would confirm.

### What this document does not claim

- No specific rewrite of line 8 is proposed; the "directional" shape in section 2 is an illustration, not a recommendation to adopt.
- No implementation (DocC directives, file changes, Topics reorganizations) is proposed. That is the synthesis document's job after all three perspectives arrive.
- No argument is made for bypassing DocC. The DocC constraint is accepted; the marketing argument is that *within* DocC, the current structure misallocates attention.

## References

- `/Users/coen/Developer/swift-institute/HANDOFF.md` — full task brief and constraints
- `/Users/coen/Developer/swift-institute/Research/documentation-docc-alpha-launch.md` — locked alpha voice (status: DECISION)
- `/Users/coen/Developer/swift-institute/Swift Institute.docc/Swift Institute.md` — root page under analysis (lines cited above)
- `/Users/coen/Developer/swift-institute/Swift Institute.docc/Blog/Blog.md` — blog index, currently a single-link placeholder
- `/Users/coen/Developer/swift-institute/Swift Institute.docc/Blog/Restarting-the-Blog.md` — the single existing blog post, the dated content the landing page should be surfacing
