---
date: 2026-06-12
session_objective: Compare apple/swift-network-evolution against the institute IO stack; the comparison's gap finding grew into the full Memory.Foreign arc — research, package, probes, seat lanes, and three landed L1 changes
packages:
  - swift-memory-foreign-primitives
  - swift-memory-map-primitives
  - swift-async-primitives
  - swift-buffer-ring-primitives
  - swift-span-primitives
  - swift-sockets
status: pending
---

# The Memory.Foreign Arc: From Apple Comparison to Shipped Regime in One Session

## What Happened

The session began as a comparison of `apple/swift-network-evolution` (Apple's Network.framework extraction: 66k LOC, full QUIC, callback/Dispatch concurrency) against the institute stack. The comparison's load-bearing finding: both codebases independently converged on the same memory ideology (typed throws, ~Copyable datapaths, span-based buffers), but Apple has a third ownership regime the institute lacked — memory the process did not allocate, owned past the lending scope, released by provider callback (Apple's `Frame.customFinalizer`).

That gap became the arc. A research brief dispatched to a separate research session produced `memory-foreign-and-memory-protocol.md` (v1.0.0 → v1.1.2 over three review rounds); the principal overrode the creation gate and `swift-primitives/swift-memory-foreign-primitives` shipped same-day (4 commits, private, pushed): a `@frozen ~Copyable` owning envelope over `Span.Raw.Mutable` + a plain finalizer closure, non-Sendable by design, `Memory.Region` conformance as its entire tower integration. Two experiment packages back it (foreign-region-tower-instantiation V1–V5; foreign-recycle-channel). Two seat lanes were admitted (the Ring-generality widening spike as the ring-window item; lane-μ for Memory.Map). Three further L1 changes landed: lane-μ itself (Memory.Map gains a `Span.Protocol` read surface over the user window; required-`@Sendable` witness and `@unchecked Sendable` conformance removed), and `sending` results on `Async.Channel` `receive()`/`poll()` (zero body changes; 184/184 tests). The Memory.Protocol question dissolved: `Memory.Region` already IS the memory-tier protocol; a sixth protocol would have been a rename, not a discovery.

Mid-arc the principal issued two binding rulings that reshaped the design — (P1) Sendable must never be load-bearing; region-based `sending` instead ([MEM-SEND-010/012/013]); (P2) Span types over `Unsafe*` pointer surfaces — plus a later standing direction that existing `@Sendable` sites are never presumed correct. A scouting inventory killed a tempting manufactured consumer (swift-file-system does not need Foreign; its zero-copy case needs read-only mappings, which resolved to Memory.Map + the lane-μ span surface instead). The swift-sockets repair session — the critical path to Foreign's first real consumer — launched in parallel near session end.

HANDOFF scan: 7 files found at workspace root (bit-primitives-domain-decomposition, derive-for-free, 3× parser-release-sil-crash, post-cascade-cleanup, set-ordered-tagged-insert-crash); all 7 out of this session's cleanup authority (not written/worked/verified here; all ~11 days old, under the [HANDOFF-038] 14-day threshold) — 0 deleted, 0 annotated, 7 out-of-scope. `post-cascade-cleanup` carries a "Superseded by" header and will clear the staleness threshold ~2026-06-15; a future session may triage it then. No `/audit` ran; no finding statuses to update.

## What Worked and What Didn't

**Worked.** The relay-orchestration shape — principal as hub between this executor session, the research session, and the tower seat, with every hop carrying file:line receipts and every deliverable re-verified first-hand (probes re-run, citations re-read, commits checked) — caught real defects at every hop: the executor caught the research doc's refcount overclaim ("nothing is lost in translation" — wrong: refcounts also fund N-references sharing); the researcher caught that overclaim regressing into the shipped README; the seat caught a mis-scoped op in the widening proposal (the "non-allocating" public Bounded init in fact allocates); the executor caught the seat's own records lagging its landed source (the ASK-A citation — nit retracted). Nobody was the sole verifier; everybody got caught once.

**Worked.** The empirical probe-before-recommendation discipline. The tower-instantiation probe split the payoff thesis precisely (storage tier zero-change CONFIRMED; buffer tier REFUTED with diagnostics captured), and the recycle-channel prototype produced the round's best finding: the channel's missing `sending` annotation retrofits additively (a wrapper over the real Receiver), so nothing ever blocked on the canonical landing.

**Didn't.** The research session's v1.0.0 violated already-ratified skill law — it designed a required-`@Sendable` finalizer and an `@unchecked Sendable` absorber, billing them as improvements over Apple, when [MEM-SEND-012] (2026-05-13) had already established region-based `sending` supersedes Sendable constraints. The rules existed in the memory-safety skill; the dispatch didn't load it. Same class: this executor's first package draft violated [API-IMPL-022] (`@frozen` from birth) and [API-IMPL-008] (method in type body) and shipped three compound identifiers in Test Support — caught only when the principal pointed at /code-surface and /modularization *after* the first commit.

**Didn't.** The first attempt at Test Support shipped a `Law` namespace with vacuous runtime checks (`base == base`) for properties the type system already proves. The principal's challenge ("isn't that enforceable through ~Copyable/~Escapable?") collapsed it in one round.

## Patterns and Root Causes

**Skill-consultation gaps are the dominant defect class, and they fire at authoring time, not review time.** Every substantive defect this session — the Sendable posture, the pointer vocabulary, the @frozen omission, the compound identifiers — was a violation of *already-ratified, written* law that the author simply hadn't loaded. This is the post-commit memory scan problem ([REFL-006]) generalized to skills: the routing table maps rule prefixes to owning skills, but nothing forces a dispatch touching memory/concurrency/naming territory to load those skills before drafting. The fix is a load-gate at dispatch time, not better review (review caught everything, but each catch cost a full revision round).

**Test what the type system cannot prove; name fixtures for what they are.** The Law episode generalizes: for a ~Copyable type, exactly-once-on-drop is a theorem — a runtime self-check is ceremony. What genuinely needs tests: (a) workaround seams where a toolchain wall turned a theorem back into an implementation invariant (the `discard self` wall forcing Optional-finalizer + guarded-deinit — the Completion.Entry shape, now used twice); (b) the caller's half of `@unsafe` contracts, which no type system checks (hence `Census` + `fixture`, named per the Model.Census precedent, not "Witness" — [PKG-NAME-015] reserves that word). Corollary discoveries that will recur for every closure-bearing ~Copyable type: `discard self` requires trivially-destroyed stored properties; `sending` alone doesn't satisfy ~Copyable parameter ownership — the spelling is `consuming sending`.

**Infrastructure ahead of its consumer is fine if and only if the consumer chain is real and the temptation to manufacture one is resisted.** swift-network-primitives ("Unnecessary — candidate for removal") was the cautionary precedent; the arc honored it twice — package creation was gated until the principal overrode with a named consumer chain (sockets 2B+/proactor), and the file-system scouting question was answered honestly (NOT a Foreign consumer; the real unblock was 15 lines on Memory.Map). The additive-retrofit proof (wrapper before canonical annotation) is the same principle at API granularity: prove nothing blocks before asking upstream to move.

**Doctrine applied late costs a round per artifact.** P1/P2 arrived after v1.1.0 and had to be retrofitted through the doc, the index entry, the sketch, the probe, and (twice) the shipped prose — the refcount overclaim regressed once and the @Sendable framing inverted once. Standing rulings of this kind belong in skills the moment they're issued; the principal's third ruling (@Sendable legacy posture) went straight to a memory entry + a seat skills-batch rider within the hour, which is the corrected workflow.

## Action Items

- [ ] **[skill]** research-process: add a dispatch-time load gate — before drafting, map the topic's rule-prefix territory (MEM-SEND, API-NAME, MOD, …) via the skill-routing table and LOAD the owning skills; cite the loaded set in the doc's Constraints. The v1.0.0 [MEM-SEND-012] violation and this executor's [API-IMPL-022]/[API-IMPL-008] misses were all retrieval failures of written law.
- [ ] **[skill]** testing: codify "structural-law vs fixture" — do not write runtime checks for type-system theorems (~Copyable exactly-once, etc.); test workaround seams and the caller's half of `@unsafe` contracts; lifecycle-counting fixtures are named Census (Model.Census precedent), never Witness ([PKG-NAME-015] reservation).
- [ ] **[skill]** memory-safety: record the closure-bearing-~Copyable shape as a pattern — `discard self` wall (trivially-destroyed stored properties "at this time") → Optional-field + guarded-deinit (Completion.Entry, Memory.Foreign); boundary spelling `consuming sending`; additive `sending`-retrofit wrapper as the proof step before canonical annotation. (The @Sendable-legacy amendment itself is already routed via the seat's round-end skills batch — not duplicated here.)
