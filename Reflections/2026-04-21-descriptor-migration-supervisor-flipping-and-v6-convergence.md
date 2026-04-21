---
date: 2026-04-21
session_objective: Ecosystem platform compliance audit → Descriptor / Event / Completion L1→L2/L3 migration supervisor chair across six design revisions
packages:
  - swift-kernel-primitives
  - swift-iso-9945
  - swift-windows-standard
  - swift-darwin-standard
  - swift-linux-standard
  - swift-kernel
  - swift-posix
  - swift-darwin
  - swift-linux
  - swift-windows
  - swift-paths
  - swift-strings
  - swift-file-system
status: pending
---

# Descriptor migration: supervisor flipping and v6 convergence

## What Happened

**Phase 0 — Ecosystem platform audit.** Dispatched 13 parallel audit subagents to run `/audit regarding /platform` across kernel-primitives, iso-9945, linux-standard, darwin-standard, windows-standard, swift-posix, swift-linux, swift-darwin, swift-windows, swift-kernel, swift-paths, swift-strings, swift-file-system. Each wrote a Platform section into its package's `Audits/audit.md` (2026-04-21 dated). One synthesis agent then wrote `swift-institute/Audits/platform-compliance-2026-04-21.md` (415 lines, 9 systemic patterns, P0→P4 remediation plan, 89 findings — 10 CRITICAL, 36 HIGH, 18 MEDIUM, 23 LOW, 2 DEFERRED).

Top systemic patterns identified: (1) L1 syscall dispatch in Kernel.Descriptor/Close/Socket.Descriptor deinit — `[PLAT-ARCH-008c]` violation; (2) C-type leakage in public API — `[PLAT-ARCH-005a]` violations concentrated in windows-standard + darwin-standard; (3) L3-to-L2 bypass — platform L3 packages re-calling syscalls already wrapped at L2; (4) umbrella re-export gaps; (5) canImport-vs-os idiom drift. Clean exemplar: swift-paths (0 findings).

**Phase 1–3 — Descriptor per-L2 migration (executed on-disk in a subordinate session).** User authorized moving `Kernel.Descriptor` + `Kernel.Close` + `Kernel.Socket.Descriptor` per-L2 per `[PLAT-ARCH-015]`. Subordinate created `ISO 9945 Kernel Descriptor` + `ISO 9945 Kernel Socket Descriptor` targets in iso-9945 and mirror `Windows Kernel Descriptor Standard` + `Windows Kernel Socket Descriptor Standard` in windows-standard, populated 13 new files each, deleted the L1 `Kernel Descriptor Primitives` target + the single `Kernel.Socket.Descriptor.swift` file from Kernel Socket Primitives, edited Package.swift in kernel-primitives + iso-9945 + windows-standard. ~50 internal-import rewires in iso-9945 source files.

**Phase 3 blocker surfaced.** 22 L1 files across 4 sibling targets (Kernel Socket/File/Event/Completion Primitives) had type-level references to `Kernel.Descriptor`, `Kernel.Descriptor.Validity.Error`, `Kernel.Descriptor.Interest`. Once L1 Descriptor was deleted, these no longer compile. The handoff I'd written did not anticipate this — its "Pre-Existing Code in Scope" section under-classified the downstream coupling.

**Design-iteration cycle v1 → v6.** User invoked `/supervise` and I acted as supervisor mediating between the subordinate (who had discovered the blocker and paused) and the user (principal). Six design revisions:

- **v1** — original handoff scope. Under-scoped.
- **v2** — subordinate expansion after blocker: move L1 Event + Completion → L3 swift-kernel. 21 files.
- **v3** — supervisor review surfaced structural omission: Event/Completion are structs (not namespaces), their entire nested-type trees follow to L3. Correction: 26 files.
- **v4** — supervisor extension: identified that L2 Event extensions (Linux.Kernel.Event.Poll.*, Darwin.Kernel.Event.Queue.*, Windows IOCP) also cascade. ~50–70 files. Required L2-to-L3 relocations.
- **v5** — subordinate introduced "design-correction renames" as a permitted category (Linux.Kernel.Event.Poll → Linux.Kernel.Epoll; Darwin.Kernel.Event.Queue → Darwin.Kernel.Kqueue; IOCP platform-prefix). Scope 80–120 files. User retracted the renames and asked for an alternative.
- **v6** — subordinate ran empirical grep passes across the three L2 packages. Key finding: zero L2 files extend `Kernel.Completion` (Windows IOCP extends `Kernel.IO.Completion.Port`, a different namespace; linux-standard IO Uring content is self-contained under `Linux.Kernel.IO.Uring.*`). This collapsed Completion's L2 cascade to zero. Final v6 structure: Kernel.Event struct stays at L1 with `Kernel.Interest` introduced as standalone OptionSet at L1 (`Kernel.Descriptor.Interest` and `Kernel.Event.Interest` both become typealiases to it — path-preserved). Event.Driver / Source / Registration / bridge inits move to L3 swift-kernel as `extension Kernel.Event { ... }` declarations. Kernel.Completion moves wholly to L3. L2 paths preserved unchanged. Scope 60–80 files.

Supervisor flipped recommendation three times across the session: α → ε → α → considered β → converged v6 (η variant). Each flip was triggered by (a) subordinate new information (grep passes), (b) user pushback, or (c) rediscovery of a fragment of `/platform` I had read at intake but forgotten at intervention time. User intervened at three key moments: rejected ε ("swift-kernel's mission IS unification"); corrected α-with-L2-relocation ("Darwin and linux standard SHOULD declare an Event type at either *-standard or swift-*"); pointed back to the skill text ("see also /platform (is the setup not clear enough from this skill?)"). The last intervention surfaced that `[PLAT-ARCH-003]`'s example contains BOTH `extension Kernel.Event { public enum Poll {} }` AND `extension Kernel { public enum Kqueue {} }` — I'd latched onto the second in memory and imputed the first was "debt".

**Final session state.** v6 approved architecturally by supervisor; gated on principal decision for `[ASK-v6-1]` (Interest typealias-collapse acceptability under "no rename" rule). User wrote a fresh verification handoff at `/Users/coen/Developer/HANDOFF.md` for an independent agent to verify v6 before Phase 4 unlocks. On-disk state remains paused mid-Phase-3 (L1 deletions landed; L2 new targets landed; consumer rewires pending).

**HANDOFF scan** (per [REFL-009]): 9 HANDOFF.md-pattern files found at working directory root + kernel-primitives. 1 active (`/HANDOFF.md` — fresh v6 verification, just written by user; ACTIVE, leave in place with verification pending per [HANDOFF-010]). 1 continuing (`swift-kernel-primitives/HANDOFF-descriptor-l2-migration.md` — the detailed v1–v6 design doc; ACTIVE, referenced by the active HANDOFF.md; leave in place). 7 out-of-authority (pre-existing workspace-level handoffs for other migrations: executor-main-platform-runloop, io-completion-migration, migration-audit, path-decomposition, primitive-protocol-audit, worker-id-typed-retype, kernel-primitives-umbrella-removal); session did not touch any and has no authority to triage them per [REFL-009]'s bounded-cleanup rule.

**Audit status update** (per [REFL-010]): swift-institute/Audits/platform-compliance-2026-04-21.md P0.1 remains OPEN — migration is mid-flight; fix not yet landed end-to-end. No status update possible. Other findings unchanged this session.

## What Worked and What Didn't

**Worked.** The parallel-agent audit (13 subagents + 1 synthesis) produced a coherent ecosystem view in one round-trip — efficient use of parallelism where the packages are independent. The synthesis agent correctly identified cross-package patterns (L2-bypass appears in swift-linux/darwin/windows; C-type leakage concentrated in windows-standard). Independent supervisor verification (running my own greps on claims the subordinate made, e.g., the Completion zero-L2-cascade grep; checking darwin-standard's Package.swift for iso-9945 dep) caught one subordinate factual error (subordinate asserted darwin-standard already depended on iso-9945 — it didn't). Subordinate escalation discipline was good throughout: [ASK-v6-1] and [ASK-v6-2] correctly distinguished class-(b) principal decisions from class-(a) rule lookups. [SUPER-009]'s "read the artifact, not the summary" applied repeatedly — every time I actually read the referenced file (Kernel.Event.swift, Completion.swift, specific L2 extension files) before responding, my supervision was accurate.

**Didn't.** My supervisory flipping was the central failure mode. α → ε → α → β in one session is three reversals. Each was defensible in isolation but the aggregate was noisy and cost the user multiple rounds of architectural re-statement. Root cause: I reasoned from remembered `/platform` content at intervention points rather than re-reading the skill text. Specifically, I missed that `[PLAT-ARCH-003]`'s example sanctions BOTH nested-under-Kernel.Event AND top-level-under-Kernel patterns at L2; I had internalized only the second fragment and classified the first as "debt". User's "see also /platform" pointer was a re-read prompt; when I actually re-read the skill I found the fragment I'd missed.

Scope-minimization over-weighting was the second failure mode. I recommended ε (smaller scope) over α (larger scope); user rejected — architectural coherence outweighs scope in this value system. Later I recommended β (revert and codify exception) over α; user rejected for the same reason. Twice in one session I proposed smaller-scope options and was corrected. The supervisor's objective isn't scope-minimum; it's architectural-coherence-maximum with scope as a tiebreaker.

The subordinate produced a v5 "design-correction rename" category that was inferred from user's architectural framing, not directly authorized. I caught this at v5 review and escalated before v5 executed. Earlier in the session (at v2), the subordinate extrapolated from "swift-kernel's mission is unification" to "therefore Event + Completion move to L3 wholesale" — a bigger inferential leap than the rename category. I accepted it without flagging. Inconsistent supervisor vigilance on subordinate-inferences-that-materially-change-scope.

The empirical-grep-first discipline that resolved v6 was the subordinate's move, not mine. v2 → v5 reasoned about scope by imputing cascade size. v6 ran the greps and the imputed scope collapsed (zero L2 Completion cascade, not the assumed substantial one). As supervisor I should have driven empirical grep at v2 rather than letting it emerge at v6.

## Patterns and Root Causes

**Pattern: supervisor re-reads skill at intervention points, not just at dispatch.** `[SUPER-009]` is explicit about "read the artifact, not the summary" — but the artifact in question includes skill text, not just subordinate output. Internalized-at-intake ≠ internalized-at-intervention. The `[PLAT-ARCH-003]` fragment I missed was in the skill from session start; I had loaded `/platform` via Skill and read the rule; at intervention time I reasoned from remembered principles rather than re-reading. When the user said "see also /platform", the instruction was implicit: re-load the relevant section. This pattern — skill loaded once at session start, then reasoned-from-memory at later decisions — is how supervisor flipping compounds across turns. The fix is mechanical: any scope-ambiguity or architectural-interpretation question at an intervention point triggers a re-read of the relevant skill section.

**Pattern: supervisor objective hierarchy = architectural-coherence > scope-minimization > speed.** Three times this session I optimized for scope and was corrected toward architectural coherence (ε rejected on "L2 unification violates [PLAT-ARCH-012]"; β rejected on "layering purity higher priority than scope"; v5 rename retraction on "L2 paths per /platform [PLAT-ARCH-003] are fine"). The user is consistent: principle-purity beats migration cost. Supervisor skill text doesn't name this ordering explicitly; without the naming, supervisor defaults-to-scope-minimization unless principal corrects. A named rule would prevent future flipping.

**Pattern: empirical grep > architectural imputation for scope-expansion analysis.** v2–v5 reasoned about cascade scope. v6 measured it. The measurement found 0 files where 5 iterations had assumed substantial. The imputed-then-revised iteration pattern burned 3 design rounds (v3 expanded to ~30 files; v4 added L2 cascade to ~50; v5 added renames to 80–120) that empirical grep would have bypassed. The rule: at any Phase-N blocker that surfaces "more files affected than anticipated", the FIRST response is a grep pass enumerating the true scope, BEFORE proposing architectural resolutions. Proposing architecture against imputed scope is compounding guesswork; proposing against measured scope converges.

**Pattern: subordinate-inference-that-materially-changes-scope requires flagging, regardless of how reasonable.** v5's "design-correction rename" category was a subordinate-introduced concept framed as "permitted because it aligns with /platform". The inference was architecturally reasonable but category-authorization is principal's call. Earlier (at v2) the subordinate inferred "Event + Completion both move to L3 wholesale" from "swift-kernel owns unification" — a bigger inferential leap, which I accepted without flagging. My supervisor vigilance was inconsistent on the same class of question. The rule: any subordinate inference that (a) introduces a new authorization category OR (b) materially changes scope from what principal last ratified MUST be flagged for principal confirmation, regardless of defensibility.

**Pattern: three-way principle tension needs first-principles analysis, not option-shopping.** The session ran 8 option-labels (α, β, γ, δ, ε, ζ, η, ι) before converging. The root tension — `[PLAT-ARCH-008c]` (L1 platform-agnostic) ⊥ `[PLAT-ARCH-012]` (L1 owns vocabulary) ⊥ no-renames — doesn't cohere under simple moves. v6 resolved by asking "what part of each principle is actually load-bearing here?": Event's struct shape is vocabulary (L1-correct); Event's Driver machinery is unification (L3-correct); Interest is the typealias bridge (needs un-nesting). First-principles analysis from turn 1 would have produced v6 directly. Option-shopping was wasted work — each option tested a different combination of principle-bending without decomposing the principles themselves.

## Action Items

- [ ] **[skill]** supervise: add rule "supervisor re-reads skill at intervention points". Concrete: at any intervention point where a scope-ambiguity or architectural-interpretation decision is pending, the supervisor MUST re-load the relevant skill section (via Skill tool invocation or direct file read) before authorizing subordinate action. Reasoning-from-memorized-skill is the dominant cause of supervisor flipping across turns. Provenance: 2026-04-21 missed `[PLAT-ARCH-003]`'s dual-pattern example after reading it at session start.
- [ ] **[skill]** supervise: add rule codifying supervisor objective hierarchy — architectural coherence > scope minimization > speed. Supervisor defaults to scope-minimization unless principal corrects; an explicit hierarchy rule would prevent the 2026-04-21 pattern of three corrections within one session. Provenance: ε/β/v5-rename recommendations all reversed on coherence grounds.
- [ ] **[skill]** handoff: add "empirical-grep-first" rule for multi-phase migrations hitting scope-expansion blockers. Concrete: at any Phase-N blocker that surfaces "more files affected than anticipated", the next session response MUST be a grep pass enumerating the true scope before architectural proposals. Imputed-cascade reasoning converged in 5 iterations where a single grep pass at v2 would have resolved it. Provenance: 2026-04-21 v2→v5 imputed cascade sizes; v6's greps collapsed Completion cascade to zero.
