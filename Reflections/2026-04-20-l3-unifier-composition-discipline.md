---
date: 2026-04-20
session_objective: Audit swift-file-system against [PLAT-ARCH-008d], dispatch the ecosystem-gap findings as upstream handoffs, and close out the audit cycle.
packages:
  - swift-file-system
  - swift-iso-9945
  - swift-windows-standard
  - swift-strings
  - swift-paths
  - swift-posix
  - swift-kernel
  - swift-institute/Skills/platform
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: handoff
    description: [HANDOFF-017] Terminal Consumer Migration for Multi-Finding Audit Cycles
  - type: research_topic
    target: ecosystem
    description: Does L3 platform-policy tier exist for strings/paths/other unifiers — stub landed at Research/l3-platform-policy-tier-generalization.md (Tier 2, IN_PROGRESS)
  - type: skill_update
    target: platform
    description: [PLAT-ARCH-008e] provenance updated to cite execution reflection + first-application commit SHAs
---

# Codifying the L3 Unifier Composition Discipline from a flush-family vestige

## What Happened

Session objective was a routine `/audit` pass: run [PLAT-ARCH-008d] (syscall-vs-policy test) against swift-file-system's 45 `#if os(...)` conditionals, classify each, and dispatch the SYSCALL/ENCODING ones as upstream handoffs. Routine bookkeeping in scope; ecosystem-wide architectural rule codification was not.

The audit landed cleanly — 32 ecosystem gaps (71%) vs 13 legitimate POLICY sites, tighter than the in-session heuristic's ~50/50 estimate because the predicates I'd lumped under "permissions model differs" split into (init/set = POLICY) + (isNotFound/isPermissionDenied = SYSCALL, error-code taxonomy). Findings landed at `swift-foundations/swift-file-system/Audits/audit.md` §`Platform Compliance — 2026-04-20`.

Dispatching unfolded in three waves:

- **Finding #1** (17 sites, error-code predicates) — handoff to swift-kernel-primitives. Supervising agent retargeted to L2 (swift-iso-9945 + swift-windows-standard) per [PLAT-ARCH-008c]. Landed as `ISO 9945.Kernel.Error.Code+Predicates.swift` (2c24cc2) and `Windows.Kernel.Error.Code+Predicates.swift` (50462fb). I had misplaced the destination at L1; supervisor caught it.
- **Finding #2/#6** (File.Name encoding) — handoff landed as 3037d1c (swift-strings) + 7bf32a9 (swift-paths). Implementing agent made three sensible deviations: my `init(utf8:)` citation was wrong (lives in swift-file-system, not swift-paths); I'd proposed a lateral swift-paths→swift-strings dep that CLAUDE.md forbids; and RFC_4648 isn't a swift-strings dep so hex was inlined. I framed the lateral dep as absolutely forbidden; user corrected — L3→L3 is nuanced, not absolute.
- **Finding #3** (durability-sync) — handoff went through the session's deepest architectural revision. My first cut proposed `dataOnly(_:)` to dodge a naming collision with iso-9945's raw `data(_:)`. User pushed back: "we should own the `data` identifier." Digging into the actual collision revealed it wasn't a collision at all — iso-9945 and swift-posix live at different tiers, and the real defect was `Kernel.File.Flush.flush(_:)` inheriting raw fsync from iso-9945 via namespace alias, silently skipping the retry-wrapped `POSIX.Kernel.File.Flush.flush(_:)` in swift-posix. **swift-posix as an L3 platform-policy package had been invisible to the audit until this point.**

That surfacing drove the session's novel output. I codified [PLAT-ARCH-008e] "L3 Unifier Composition Discipline" at `swift-institute/Skills/platform/SKILL.md:547`: swift-kernel (L3 unifier) MUST compose over peer L3 platform-policy packages when those wrappers add behavior; MUST NOT inherit methods directly from L2 raw via namespace-alias extension when a policy wrapper exists. Finding #3's handoff was rewritten as a three-phase layering fix: (A) rename iso-9945's raw to spec-literal names, (B) extend swift-posix policy on Darwin + add directory sync, (C) explicit delegation files in swift-kernel.

Then an `/audit` pass against the freshly-codified rule, scoped to swift-kernel. The implementing agent enumerated 25 L3 platform-policy wrappers across swift-posix, confirmed Darwin/Linux/Windows L3 clean (novel APIs only), and found 17 HIGH violations in a single uniform pattern: every POSIX retry-wrapper is shadowed by its L2-raw inheritance through swift-kernel. Findings #3/#4 (Darwin `full`/`barrier`) transitioned to FALSE_POSITIVE — Phase A's rename removes the shadow outright. Connect (#17) flagged as semantically distinct: its EINTR policy is completion-await (poll POLLOUT + getsockopt SO_ERROR), not retry.

Three further handoffs drafted: Connect-focused (correctness, solo), bundled retry-wrappers for #5–#16 (five commits, mechanical), and a terminal consumer-migration closing both audits (six migration classes). Each carries "do not start until {prior} has landed" gates. Enumerated the single non-swift-file-system consumer (swift-sockets's TCP.Listener) via grep before closing.

## What Worked and What Didn't

**Worked**:

- The progressively-deeper user-nudge-then-investigate loop was load-bearing. User flagged `dataOnly` as a workaround → I investigated the collision → discovered swift-posix → realized layering vestige → codified as rule. Each push landed a sharper answer than the one before.
- Codification-before-audit produced cleaner findings. Running the second `/audit` against a specific requirement ID ([PLAT-ARCH-008e]) rather than against an implicit architectural principle gave the implementing agent a decision test to apply mechanically. The resulting 17-finding ledger has no classification ambiguity.
- The supervision loop worked: supervising agents caught my handoff errors repeatedly (L1 misplacement, `init(utf8:)` misattribution, over-absolute lateral-dep framing, `dataOnly` workaround). Handoff staleness-check per [HANDOFF-016] actually functioned; agents verified before acting.
- Severity-preserving audit ledger discipline held across multiple passes. FALSE_POSITIVE, OPEN-with-pending-SHA, and cross-audit references all worked as designed.

**Didn't work**:

- Multiple architectural-advice rounds were wrong before landing correct. I proposed `Kernel.Policy.*` as a nested namespace (user corrected: policy in domain packages) → then "policy in swift-file-system" (user corrected: L3 is nuanced — we found swift-posix) → then four-tier model. At each step my confidence was high; each step I was missing evidence I should have grepped for.
- swift-posix was invisible to my initial analysis despite being a ~14-target package with a `POSIX Kernel File/POSIX.Kernel.File.Flush.swift` right where the audit was poking. The iso-9945 doc comment said "use the policy-aware wrapper in POSIX_Kernel" — I read it as aspirational rather than grep-ing. The package sat unsearched through three handoff drafts.
- The initial `dataOnly(_:)` workaround proposed solving a collision that wasn't one. Had I grepped how `POSIX.Kernel.File.Flush.data` resolves before drafting, the collision would have dissolved immediately — different namespaces (`POSIX.Kernel` is a separate enum, not aliased to `Kernel`).

## Patterns and Root Causes

**Pattern 1 — Under-grepping the ecosystem before architectural advice.** Three distinct errors this session (L1 vs L2 destination; `init(utf8:)` location; swift-posix existence) all trace to the same mechanism: I trusted the in-memory architectural model over filesystem truth. The model was plausible, internally consistent, and wrong. Each correction required a grep I should have run before drafting. The fix is not "grep more carefully" — it's "treat every architectural claim in a handoff as a grep prompt, and run the grep before the claim ships." The handoff's own [HANDOFF-016] proposal-staleness clause caught the errors downstream, but the cost was reviewer cycles and drift files (the `+DataOnly*/+Directory` drift files at iso-9945 exist precisely because the architectural-placement question had been answered wrong once already before the audit).

**Pattern 2 — Architectural rules surface only under pressure.** [PLAT-ARCH-008e]'s three-check decision test wasn't controversial once written; it codifies a discipline that feels obvious on reading. But the rule wasn't written until Finding #3's layering vestige demanded it — and the audit run immediately after found 17 instances of the pattern lurking across swift-kernel. That's not a new violation class; it's a longstanding one that never had a requirement ID to check against. The action here is to distrust "we don't need to codify this; it's obvious from the existing rules" — if the pattern recurs across the ecosystem, it needs an audit-enforceable ID, obvious or not.

**Pattern 3 — Terminal consumer migration batching.** Twice this session (Platform Compliance produced 6 findings affecting swift-file-system; L3 Composition produced 13 open findings with the same primary consumer), the user had to specify "upstreams first, then one consumer pass." My default was per-finding consumer migration. The batched-terminal approach reduces file-touch count substantially when audits produce many findings affecting overlapping consumers (a single error enum's predicates span multiple findings — isNotFound + isPermissionDenied + isReadOnly + isNoSpace all touch the same accessor extension). Worth formalizing as handoff guidance so the next audit cycle doesn't rediscover it.

## Action Items

- [ ] **[skill]** handoff: Add [HANDOFF-017] "Terminal Consumer Migration for Multi-Finding Audit Cycles" — when an audit produces N ecosystem-gap findings whose consumer sites overlap in one or a few domain packages, the consumer migration SHOULD be bundled into a single terminal handoff dispatched after all upstreams land, not dispatched per-finding. Pattern emerged twice this session (Platform Compliance + L3 Composition audits) and was user-specified both times; add it as guidance so the next audit cycle doesn't rediscover it.
- [ ] **[research]** Does the L3 platform-policy tier exist for swift-strings / swift-paths / other L3 unifiers, or is it unique to swift-posix? The [PLAT-ARCH-008e] audit found swift-darwin / swift-linux / swift-windows host only novel APIs (zero L2-raw shadows). swift-posix is the sole L3 platform-policy package wrapping L2 raw with EINTR-retry. Investigate whether strings/paths analogous wrappers are missing-by-design (no platform policy to normalize there) or missing-by-gap; if gap, the rule as written generalizes weakly and may need extension.
- [ ] **[skill]** platform: Once Finding #3 Phase C lands, replace [PLAT-ARCH-008e]'s current Provenance line ("Reflection pending post-implementation") with a reference to this reflection + the Phase C SHA. The rule was codified during design; it needs the first real application as validation.
