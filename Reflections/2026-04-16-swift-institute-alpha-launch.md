---
date: 2026-04-16
session_objective: Take swift-institute ecosystem from private to public alpha — DocC restructure, claim triage, GitHub Pages deployment, custom domain, launch content.
packages:
  - swift-institute
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: no_action
    description: Landing-page DocC skill note: low-priority, subsumed by existing documentation skill guidance and swift-institute.org source as de facto example
  - type: blog_idea
    description: "Alpha-launching a Swift ecosystem" — checklist-style post: claim-inventory, cert kick, DocC-native landing
---

# Swift Institute Alpha Launch — Claim Triage, HTTPS Kick, Landing-Page Constraints

## What Happened

Continued from a prior handoff that had already done DocC catalog renaming (`Documentation.docc` → `Swift Institute.docc`) and scaffolding. This session:

1. **Major content restructure** of the DocC catalog:
   - Rewrote the root page with identity + 5 principles + progressive-disclosure Topics.
   - Created Architecture (absorbing Identity content), Swift Primitives (replacing Mathematical Foundations), Swift Standards, Swift Foundations, Platform.
   - Deleted Glossary, Identity, Mathematical Foundations, Five Layer Architecture.
   - Added Research and Experiments articles later (promoted from FAQ entry).

2. **Multi-pass claim triage** ("inventory every claim we might not want to make at alpha"):
   - Categorized risk types: timeline commitments, license specifics, domain enumerations, unverified API claims, specific package URLs, stewardship framing, exact counts, compound identifiers.
   - Executed cuts across the root page, per-layer articles, Platform, FAQ, Getting Started, Embedded Swift, and the two READMEs.
   - Fixed compound-identifier violations against `[API-NAME-001]` that I had introduced (`TimerID`, `TreeID`, `EmailAddress`, `DateTime`) by switching to nested/single-identifier alternatives (`Tagged<Timer, UInt64>`, `RFC_3986.URI`, `RFC_4122.UUID`).

3. **GitHub Pages deployment infrastructure**:
   - Authored `.github/workflows/deploy-docs.yml` using `swift-actions/setup-swift@v3` + `xcrun docc convert --transform-for-static-hosting` + `actions/deploy-pages@v5`.
   - Made the repo public via `gh repo edit`. Enabled Pages with Actions source via API. Set custom domain `swift-institute.org`.
   - Configured DNS via DNSimple API (4 apex A records + `www` CNAME).
   - First workflow failed (Swift 6.1 runner vs Swift 6.2 tools-version). Lowered tools-version, deploy succeeded. User flagged "Swift 6.3 minimum everywhere," reverted to 6.3 + added setup-swift install step.

4. **HTTPS cert provisioning stall**:
   - Cert didn't issue for 10+ hours despite clean config (DNS resolving, no CAA, no `pending_domain_unverified_at`, empty health check).
   - Resolved via unset+reset of `cname` through the GitHub Pages API. State went `null → authorized → approved` within 30 seconds of the kick. Enabled `https_enforced: true`.

5. **Landing-page UX pass** (partial, then deferred):
   - User flagged the initial DocC-rendered page as subpar — progressive disclosure weak, blog buried, too much above-the-fold.
   - Made quick hits (removed redundancy, tightened Topics groups).
   - Wrote a handoff for a fresh agent to run `/research-process` across three perspectives (marketing, technical, comparative) before further implementation.
   - Added constraint: "work WITH DocC, not against it" — no bypassing DocC's chrome.

6. **Launch content** drafted for Swift Forums, Hacker News, r/swift, Twitter/Mastodon, LinkedIn, Medium (with canonical URL guidance).

7. **Artifact cleanup in-session**: deleted original `HANDOFF.md` after its Next Steps were done; wrote a new one for landing-page UX work. Moved `documentation-docc-alpha-launch.md` research status from IN_PROGRESS to DECISION.

## What Worked and What Didn't

**Worked well**:
- **Systematic claim inventory by risk category.** Categorizing every claim before cutting produced a much cleaner triage than ad-hoc editing would have. The user's feedback on each category (which to cut, which to soften, which to keep) was easy to apply once the inventory was structured.
- **Skills as tie-breakers.** When the user pointed at `/code-surface` and `/implementation`, I was able to correct compound-identifier violations I'd introduced. The skills carried authoritative rules that resolved design choices I'd been making ad-hoc.
- **Authoritative-source verification when challenged.** User asked "where did you get those IPs?" and I fetched GitHub's docs directly. User asked about action versions, I fetched each action's releases page. Every time I went to source, I found outdated memory.
- **The cert kick.** After 10 hours of passive waiting (against my own earlier "~4 hours is abnormal" advice), the unset+reset pattern resolved the stall in 30 seconds.
- **Progressive capture of the handoff.** Updating `HANDOFF.md` incrementally across the session meant the final version reflected current state accurately, not whatever I could remember at the end.

**Didn't work**:
- **Initial claim population was unverified.** I asserted specific type names (`RFC_5322.EmailAddress`, `ISO_8601.DateTime`), specific package URLs (`swift-clock-primitives`, `swift-json`), and specific APIs (`Clock.Continuous().now`, `Kernel.File.open(path, .read)`) without checking whether they were real. All had to be triaged or abstracted later.
- **Compound-identifier violations.** `TimerID`, `TreeID`, `EmailAddress`, `DateTime` went into documentation before I loaded `/code-surface`. The rules were available; I didn't consult them until the user pointed at them.
- **Passive advice on the cert stall.** After saying "~4h is abnormal," at 10h I was still suggesting "wait more." User had to push me toward the kick.
- **Under-anticipated the marketing-surface shape.** The user had to push multiple times ("subpar", "progressive disclosure", "work WITH DocC") to get me past a documentation-shaped approach to the landing page. I kept proposing API-doc-style structures instead of landing-page-shaped structures.
- **Over-thought DNSimple token security.** Offered three elaborate file/env-var paths before the user called it out: the trust surface is the same whether the token is pasted or exported. Pragmatic answer was paste-and-revoke. My initial framing implied a security difference that was narrower than the setup suggested.
- **The first content pass enumerated domains too aggressively.** Listed specific packages in Swift Foundations (15 HTTP packages, 15 security packages, etc.), specific ISO/RFC types, specific kernel features per platform. User had to flag "secret until launch" for domain coverage. The default voice I reached for was marketing-catalog; the user wanted alpha-conservative.

## Patterns and Root Causes

### Pattern 1: Verify against source, proactively, not when challenged

My memory is unreliable for:
- Specific action version tags (GitHub Actions moves fast)
- Specific IP addresses (can change — though these haven't)
- Specific DocC flags (toolchain-dependent)
- Specific API names/shapes in rapidly-evolving ecosystems

Every time the user asked "where did you get that?" I went to source and found my memory was stale by a major version or a factual error. The right move is to verify *before* stating, especially for alpha/launch-sensitive content where errors are expensive to fix post-publication. This is true even when the verification is trivially fast (a single `WebFetch`). The cost of verification is much lower than the cost of wrong content on a public site.

### Pattern 2: Load skills before producing content they govern

I wrote documentation examples that violated `[API-NAME-001]` without consulting `/code-surface`. The skill was available; I didn't load it because I was focused on content. But content intended to illustrate the ecosystem's conventions MUST follow those conventions — otherwise the examples teach the wrong patterns. Lesson: when writing public-facing content that demonstrates a rule-bearing domain, load the rule-bearing skill first, not after the fact. This is consistent with the user's previously-stated preference for me to follow the canonical skills.

### Pattern 3: "Alpha" and "marketing catalog" are different voices

The default voice I reach for when introducing an ecosystem is the marketing-catalog voice: list domains, enumerate packages, describe features. The alpha-conservative voice is different: "evolve into your position, don't claim it at present." Every claim is a future commitment.

This is the frame the user had to articulate multiple times before I internalized it. It bears on launch documentation, README files, and landing pages for any project in an early-public state. The catalog-urge is strong because it signals scope; the alpha-urge is to signal credibility without over-scoping. The test is "can we deliver this without retroactive disappointment?"

### Pattern 4: Stalled external systems need active probing past the normal window

For systems with known completion windows (Let's Encrypt cert issuance, CI builds, deploys), "just wait" is the right advice inside the window and wrong advice outside it. My default was to keep waiting; the user's instinct to act at 10h was correct. Pattern: when a window is 2–3× exceeded, switch from passive waiting to active probing (kick, reset, restart). The cost of a kick is small; the cost of another night of waiting is another night.

### Pattern 5: Documentation ≠ landing page, even when same tool renders both

DocC conflates the module root with the landing page. For an API reference project, this is fine — visitors are there to browse symbols. For a public-facing ecosystem alpha, the landing is the first impression and needs different content shape: stronger hook, featured content, reader-intent routing. "Use DocC's features better" is different from "use DocC as intended." The distinction took multiple exchanges to get right and now lives as a constraint in the handoff for the next agent.

### Root cause linking all five

When I'm generating content, my default is to reach for patterns that produce dense, complete, reference-style text. Alpha-launch work requires restraint — verification, skill-adherence, conservative framing, active intervention, and marketing-shaped composition — all of which pull against the "more text, more features, more enumerations" default. The session was effectively a multi-pass correction from the default to the discipline the situation needed. A better version of me would reach for the discipline upfront.

## Action Items

- [ ] **[skill]** documentation: Add a "Landing-page use of DocC" note covering the module-root/landing-page conflation, verified-working directives for landing UX (`@TopicsVisualStyle(detailedGrid)`, `@Links(visualStyle: detailedGrid)`, `@CallToAction`, `@Small`), and DocC's URL-structure quirk (module path uses `snake_case`, article paths use `kebab-case` — e.g. `/documentation/swift_institute/` vs `/documentation/swift-institute/restarting-the-blog/`). This may also warrant a new `docc-landing` or `public-docc` skill per the current HANDOFF.md Open Question — the handoff's next agent will decide placement.
- [ ] **[blog]** Alpha-launching a Swift ecosystem — a checklist-style post covering three reusable patterns surfaced in this session: (1) systematic claim-risk inventory across public surfaces before launch, (2) the GitHub Pages + Let's Encrypt unset-and-reset-cname kick for stalled cert issuance, (3) working WITH DocC vs against it for landing pages. Each pattern stands alone and each is reusable across Swift open-source projects.
