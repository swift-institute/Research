---
date: 2026-04-22
session_objective: Advise sibling agent through /supervise invocation, ground-rules drafting, and three-document investigation-only cycle producing decision-ready options-matrices for the audit's remaining design-blocked findings.
packages:
  - swift-iso-9945
  - swift-posix
  - swift-kernel
  - swift-kernel-primitives
  - swift-institute
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Investigation-only supervise cycle — three-doc pattern + principal-as-decider enforcement

## What Happened

This is the second phase of the session captured earlier at `2026-04-22-platform-audit-remediation-cycle-and-advisory-pivot.md` (direct remediation 9→30/89 + initial advisory). This phase: the sibling agent carrying the remediation forward hit the "no more mechanical macOS work" ceiling, invoked `/supervise`, and ran an investigation-only cycle producing three decision-ready research docs for the audit's design-blocked findings.

**Timeline of this phase:**

1. Sibling agent shipped **P4.1** (`do throws(E)` explicit form in swift-posix, 18 catch sites) then **P3.2 item 2** (Linux.Thread.Affinity stub removal) then **P4.2** (Exports.swift capitalization), advancing 30→33/89.
2. Discovered **P3.3 #10** (Socket.Address.Storage SPI demote) balloons to 13-files-across-4-packages; I recommended Split B (typed-throws half only), agent shipped that + three more small items + **P3.4 swift-darwin Darwin System role-split doc**, advancing to 38/89.
3. Agent invoked `/supervise` at the autonomous-work boundary. I advised on scope-boundary questions (authorized Interpretation A — investigation-only docs for the 3 design-blocked findings: P2.2 #1/#11, P2.3 #3, P2.4 #8) and ground-rules block structure.
4. Ground-rules block approved with 6 typed entries (MUST/MUST NOT/fact/ask) + mandatory fields + acceptance criteria + per-artifact approval cadence + SUPER-015 appendix for tactical decisions.
5. Agent produced three docs in concrete→open order:
   - **Doc 1** — `swift-institute/Research/file-handle-writeall-l2-l3-layering.md` (218 lines). Headline: File.Handle is L1, not L2 as the parent handoff assumed — reframes option space. Recommendation: Option 5 method-level split. Approved with Option 5 selected.
   - **Doc 2** — `swift-iso-9945/Research/socket-message-header-typed-pointer-fields.md` (258 lines). Headline: Vector.Segment precedent establishes the ecosystem's descriptor-style typed-wrapper pattern; `UnsafeMutableRawPointer?` inside a typed struct is compliant per [PLAT-ARCH-005a] when the struct is ecosystem-typed. Recommendation: Refined Option 1' — type Vectors only, keep Name+Control raw under "struct IS the typing." Approved; tracker now carries a [PLAT-ARCH-005a] Pattern 2 clarifying sub-rule codifying the Q2 ruling.
   - **Doc 3** — `swift-iso-9945/Research/signal-action-siginfo-l2-wrapper-design.md` (287 lines). Headline: async-signal-safety constraint genuinely conflicts with "modern Swift" enum+associated-values direction; Option 3 allocation risk in signal-handler context is unverified. Recommendation: Option 1 (layout-compatible typed wrapper) as foundation, Option 3 as verification-gated follow-up. Principal approval pending.
6. Session closed investigation cycle in SUCCESS termination per [SUPER-010] at `swift-institute/Audits` commit `f6c2a44`. All 6 acceptance criteria met; 6 ground-rules entries verified.
7. User (principal) signaled "I also want to proceed with implementing." I advised: close investigation cycle cleanly, answer open questions across all 3 docs (I gave defensible defaults), open 3 sequential implementation cycles — Doc 2 first (simplest, iso-9945-local), Doc 3 second (still iso-9945-local but with async-signal-safety verification), Doc 1 last (cross-package + `@inlinable` cascade risk + mandatory Docker Linux verification). No implementation cycles opened yet in this session — that's the next action.

## Handoff triage report ([REFL-009] enumerative form)

2 handoff files in session cleanup authority:

| File | Status observed | Disposition |
|------|----------------|-------------|
| `swift-institute/Audits/HANDOFF-layer-perfection-investigation.md` | SUCCESS TERMINATED at commit `f6c2a44`; all 6 ground-rules entries verified end-to-end; acceptance criteria 1–7 passed | Annotated-and-left (file is its own archival record of the investigation cycle; future implementation cycles may cite as precedent; deletion can happen when all 3 implementation cycles complete) |
| `swift-institute/Audits/HANDOFF-platform-audit-remediation.md` | Previously annotated in prior 2026-04-22 reflection as SUPERSEDED IN PART | No further action (companion to above; documents the pre-investigation-cycle remediation state) |

All other `HANDOFF-*.md` files workspace-wide: out-of-session cleanup authority per [REFL-009] bounded-authority rule.

No `/audit` invoked this phase; tracker status updates already happened per-finding in prior phase and via tracker commits during investigation cycle. [REFL-010] no-op.

## What Worked and What Didn't

**Worked:**

- **Three-doc sequential ordering (concrete→open) paid off structurally.** Each doc's findings informed the next. Doc 1 established the L1-vs-L2 diagnostic pattern; Doc 2 applied it to Header (confirmed L2-exclusive) and added layout-soundness checking after catching its own Option 1 UB; Doc 3 inherited both diagnostics and applied them to siginfo_t (confirmed layout-sound because kernel always allocates full siginfo_t). Cross-doc learning was material — not just stylistic carry-forward.
- **The [PLAT-ARCH-005a] Q2 ruling was the session's highest-leverage decision.** Doc 2 escalated "does `UnsafeMutableRawPointer?` count as a C type?" as Open Question #2. Principal ruling — compliant when wrapped in an ecosystem-typed struct with `@unsafe init`, non-compliant as a direct function parameter — was codified as a [PLAT-ARCH-005a] Pattern 2 clarifying sub-rule in the same commit. This ruling THEN applied as a constraint in Doc 3's analysis (Options 2 and 5 rejected on the same grounds). A single ruling retired an entire class of future audit ambiguity.
- **Principal-as-decider invariant held.** Docs 1, 2, 3 each produced options matrices + recommendations + escalating open questions (6, 6, 7 respectively) — 19 questions across the three docs, all escalated, none pre-committed. Ground-rule #4 "no pre-commit a decision" enforced structurally. Every "we've decided X" tempting phrase in draft got reshaped to "here are options, here is evidence, here is my recommendation, the decision escalates to you."
- **Per-artifact approval cadence caught issues before they compounded.** Each doc reviewed before the next started. Doc 2 carried Doc 1's lessons; Doc 3 carried Doc 1's and Doc 2's. If the agent had produced all 3 at once and only reviewed at end, Doc 2's Refined Option 1' realization (Name pointer is layout-unsound) would not have been cross-referenced as a constraint in Doc 3.
- **Success termination happened cleanly.** All 7 acceptance criteria objectively met. No ambiguity about whether the cycle is done. The `f6c2a44` commit's amendment section provides a durable record of the termination.
- **Advisory-agent workflow was distinct but productive.** I reviewed each doc, answered each question-batch, caught issues (Doc 2's `UnsafeRawBufferPointer?` alternative for Control that the doc didn't surface; Doc 3's un-costed Option 3 scope; async-signal-safety verification acceptance criteria not specified). Review is a different mode from execution; the 6-section template made reviews mechanical-to-perform.

**Didn't work:**

- **Chain-authorization drift re-surfaced.** Before the sibling agent invoked `/supervise`, they had been shipping 2–4 findings per "proceed" token — same drift I had in direct-remediation phase. The `/supervise` invocation was the correction. The recurrence confirms the drift is structural, not educational.
- **Scope expansions were attempted despite ground-rule #3.** Doc 2 briefly considered proposing a typed cmsghdr wrapper design as part of Option 3. I flagged this mid-review; agent correctly pulled back and flagged it as Open Question #3 (defer to dedicated cycle). The ground-rules block's explicit MUST NOT prevented a quiet expansion from committing.
- **`UnsafeRawBufferPointer?` for Control was missed in Doc 2 until my review.** Stdlib-typed buffer descriptor is a valid middle ground between `UnsafeMutableRawPointer? + separate length: Int` and a full typed cmsghdr wrapper. Doc 2 jumped from "untyped" to "no typed partner exists" without considering `UnsafeMutableRawBufferPointer?`. Review caught it; author pattern missed it. Hints at a diagnostic: when a finding says "wrap pointer+length," always ask "is there a `UnsafeRaw[Mutable]BufferPointer?` option before inventing a new ecosystem type?"
- **Async-signal-safety verification spec was under-specified.** Doc 3 flagged "verify no allocation" as a required gate for Option 3 but didn't specify acceptance criteria (malloc-wrapper + SIGSEGV trigger? code-gen inspection? formal proof?). Future implementation cycle starting Option 3 would need this pinned. Caught in my review; future `[research]` action item.

## Patterns and Root Causes

**The three-doc investigation-only cycle is a distinct process pattern worth naming.** It's not a single-doc investigation (too narrow for the design-blocked findings that share a class); it's not a multi-session design cycle (each doc fits in ~4–6 hours, not weeks); it's a structured one-session advance-three-decisions pattern. The structural elements that made it work:

1. **Single ground-rules block governs multiple docs.** One `/supervise` invocation, one block, N docs — not N blocks. Shared MUST/MUST NOT/fact/ask entries.
2. **Concrete→open ordering.** The first doc is the most-bounded problem; the last is the most-open. Each later doc benefits from patterns the earlier docs surfaced.
3. **Per-artifact approval gate.** Review after each, not after all three. Lets cross-doc learnings propagate and redirects effort before errors compound.
4. **Each doc is self-contained.** The 6-section template (problem / constraints / options matrix / evidence / recommendation / open questions + [SUPER-015] appendix) ensures any doc stands alone if extracted.
5. **Structural enforcement of principal-as-decider.** MUST NOT pre-commit; every recommendation paired with escalating open question. Removes the "agent makes decisions that accrete into architectural commitments" failure mode.

The pattern is worth `[skill] handoff` codification because it's distinct from both sequential and branching handoffs — it's a *multi-doc sequential investigation with shared ground rules and per-artifact gates*. The handoff skill currently names sequential and branching modes but not this third shape.

**The Q2 ruling pattern (single escalation retires a class of ambiguity) is worth noting.** Doc 2's Open Question #2 asked a general interpretive question about [PLAT-ARCH-005a] — not "what's the fix for this finding" but "what does the rule mean for an entire class of cases." Principal's ruling + codification in the audit tracker's Pattern 2 as a clarifying sub-rule retired future audit ambiguity. The meta-lesson: **when an investigation reveals that a rule's interpretation is ambiguous, escalate the interpretation first**. Implementation of the specific finding is then mechanical application of the ruling. This is a higher-leverage move than escalating the finding's fix per se.

**The layout-soundness diagnostic deserves promotion to a reusable pattern.** Doc 2 caught Option 1's Name pointer as UB because `UnsafeMutablePointer<Storage>` over a 16-byte `sockaddr_in` allocation violates Swift's typed-pointer stride contract. Doc 3 applied the same diagnostic to siginfo_t and confirmed SOUND (kernel always allocates full 104/128-byte siginfo_t). The asymmetry is structural: typed-pointer wraps are sound iff the allocated memory is always at least `MemoryLayout<Wrapper>.stride` bytes. This diagnostic applies to any "type an `UnsafeMutablePointer<T>` over C memory" decision, which is an increasingly common pattern in the ecosystem. The ground-rules for future typed-wrapper work should include a mandatory layout-soundness check.

**The "modern Swift" direction runs into C-ABI constraints at handler-context boundaries.** Doc 3 surfaced this as its load-bearing tension. Enum-with-associated-values is more modern-Swift than raw-pointer + discriminated accessors, but enum construction may heap-allocate, and allocation is async-signal-unsafe. This isn't specific to signal handlers — any interrupt/exception/handler-context where the kernel calls INTO Swift code via a C function pointer has the same constraint (signal handlers, IOKit callbacks, kqueue event callbacks on Darwin). The pattern is general; the implication is that the ecosystem needs a verified understanding of when Swift enum construction does/doesn't allocate before committing modern-Swift designs to handler-context code. This is a `[research]`-tagged gap that would inform multiple future efforts.

**Sibling-agent advisory is a distinct mode of contribution worth recognizing in reflection practice.** My role in this session's second phase was review + recommendation + scope-boundary advising — not direct implementation. The rhythms differ (per-artifact review, question-batch answers, scope-gate decisions) but the learning surface is rich: every doc I reviewed, every decision I advised on, every escalation I helped structure yielded cross-doc patterns I wouldn't have seen from inside execution. The REFL-001 triggers table doesn't name "advisory session" explicitly, but the triggers (design decisions with non-obvious trade-offs, patterns recognized across sessions, plan deviating from reality) all fired — just from the observer seat rather than the driver seat.

## Action Items

- [ ] **[skill]** handoff: Formalize the "investigation-only cycle" pattern as a third handoff mode (alongside sequential and branching). Key elements: one supervise block governs N docs, concrete→open ordering, per-artifact approval gates, each doc self-contained under a shared 6-section template, structural enforcement of principal-as-decider via MUST-NOT-pre-commit. Provenance: 2026-04-22 three-doc cycle producing decision-ready artifacts for P2.2 #1/#11, P2.3 #3, P2.4 #8.

- [ ] **[skill]** implementation: Add layout-soundness as a formal pre-check for typed-pointer wrapper design — when declaring `UnsafeMutablePointer<Wrapper>?` over C-allocated memory, verify `MemoryLayout<Wrapper>.stride <= minimum allocation size` (not just equal-to one specific case). Kernel-always-full-allocates types (siginfo_t) pass; family-dispatched types (sockaddr_storage over sockaddr_in) fail. Provenance: 2026-04-22 Doc 2 caught Name-pointer UB; Doc 3 confirmed siginfo_t sound via the same diagnostic.

- [ ] **[research]** Investigate Swift enum construction's async-signal-safety across Swift 6.3 compiler versions — when does `.case(AssociatedValue)` construction heap-allocate vs stack-only? This gates any "modern Swift" enum dispatch adoption in signal-handler or interrupt-context code (signal handlers, kqueue callbacks, etc.). Research destination: `swift-institute/Research/async-signal-safe-swift-enum-construction.md`. Needs empirical test harness (malloc-wrapper + handler-context instrumentation) + code-gen inspection across compiler versions.
