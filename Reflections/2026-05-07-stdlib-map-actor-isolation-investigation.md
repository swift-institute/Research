---
date: 2026-05-07
session_objective: Conduct Tier 2/3 literature study on the residual "stdlib Collection.map specialization gap" framing left by result-builder-performance-optimization.md v2.1.0; characterize the cause precisely, recommend remediation, write the research doc and update cross-references.
packages:
  - swift-institute
status: pending
---

# stdlib Collection map "specialization gap" refuted as SE-0423 actor-isolation overhead

## What Happened

Session was driven by `swift-institute/HANDOFF-stdlib-map-specialization-gap.md`. The handoff brief framed the residual cost in v2.1.0's Residual section as a stdlib `Collection.map` "specialization gap — closure dispatch goes through a generic boundary, adding ~40 ns/element of indirect-call + protocol-dispatch overhead." Three remediation paths were enumerated: (A) report upstream, (B) ship workaround helpers (`Collection.fastMap` etc.), (C) accept and document.

Investigation followed the research-process skill's tiering ([RES-020]). Step-0 internal grep ([RES-019]) found `lazy-pipeline-release-mode/` as the closest corpus neighbour (institute-defined `@inlinable` lazy types match hand-rolled within 2% in -O at N=10M; stdlib `.map`/`.filter` materialised to intermediate arrays is 7× slower) — partial-truth pre-existing framing.

Compiler source reading (local clone at `/Users/coen/Developer/swiftlang/swift/`): `Collection.map` and `Sequence.map` both `@inlinable @_alwaysEmitIntoClient` with typed throws. Nothing in the attributes themselves would defeat specialization.

Empirical triangulation in `/tmp` pivoted the diagnosis fast:

| Configuration | V8/V14 ratio | Verdict |
|---------------|--------------|---------|
| Existing experiment in SwiftPM target (Swift 6 mode) | **20.8×** | Reproduces published gap |
| Single-file `swiftc -O bench.swift` (no SwiftPM) | **1.07×** | Gap **doesn't reproduce** |
| SwiftPM target, call wrapped in `nonisolated func` | **0.98×** | Gap **vanishes** |

The single-file/SwiftPM divergence broke the handoff's framing. Stdlib `Collection.map` is not intrinsically slow; the gap is build-context-conditioned.

SIL inspection (`/tmp/map-spm-spike/main.sil`) confirmed the mechanism: V8's specialized closure body emits per-element `apply @swift_task_isCurrentExecutor` + conditional `apply @swift_task_reportUnexpectedExecutor`. V14's same-module map body has neither. Both fully specialize the multiply (`smul_with_overflow_Int64` for `$0 * 2`). Generic specialization is not failing; what V8 adds is the runtime executor check.

Prior-art search hit immediately: SE-0423 *Dynamic actor isolation enforcement from non-strict-concurrency contexts* (Implemented Swift 6.0), and PR swiftlang/swift#82795 (closed without merge 2025-07-24). harlanhaskins's closing comment on #82795 was the smoking gun: "in the `.swiftinterface` for Swift it's still built with `-swift-version 5`... the stdlib comes in with `isConcurrencyChecked` false." That gates SE-0423's check-insertion rule on every isolated-closure call into stdlib HOFs.

Causal chain established:

1. Top-level `main.swift` in Swift 6 SwiftPM target is implicitly `@MainActor`.
2. Closure literal `{ $0 * 2 }` inherits `@MainActor` isolation.
3. Closure passes to `Collection.map`, imported from stdlib's `.swiftinterface` (Swift 5 mode → `isConcurrencyChecked() == false`).
4. SE-0423 mandates a runtime executor check at every invocation.
5. For a higher-order function called per element, "every invocation" is per element. Per-element overhead measured at 44.7 ns.

Wrote `swift-institute/Research/stdlib-collection-map-actor-isolation-overhead.md` v1.0.0 (Tier 2, ecosystem-wide, DECISION) — refutes the v2.1.0 specialization-gap framing on primary-source evidence, recommends path (C) accept and document. Why-not for (A) and (B) explicit: (A) the cause is known and tracked upstream, a Forums report would re-litigate harlanhaskins's already-correct diagnosis; (B) `Collection.fastMap` would be redundant with the structural `nonisolated` workaround and become a deprecation cost when stdlib's `.swiftinterface` migrates.

Cross-reference updates:
- `swift-institute/Research/_index.json` — new entry added; parent doc's `statusDetail` refined.
- `swift-institute/Research/result-builder-performance-optimization.md` v2.1.0 → v2.2.0 — top banner records the further refinement; Residual section's Root cause + Implications rewritten in SE-0423 framing.

User then pushed back: "is there nothing we can do?" Empirically tested mitigation candidates in a fresh SPM spike:

| Mitigation | Result |
|-----------|--------|
| `MainActor.assumeIsolated { (0..<n).map { ... } }` wrapping the call | No improvement (≈ V8) |
| `(0..<n).map { x in MainActor.assumeIsolated { x*2 } }` wrapping the body | 2–30× *worse* |
| `nonisolated func`-wrapped call | Equivalent to V14 (no overhead) |
| Hand-rolled institute `@inlinable` helper | Equivalent to V14, identical to nonisolated-wrap |

Confirmed: only the structural fix works. The `nonisolated` boundary and the same-module helper are within noise of each other; the parallel API surface adds nothing the structural refactor doesn't.

User asked for `nonisolated` illustration. Explained the fix is consumer-side (the closure inherits isolation from its lexical enclosing function; the institute's builder API can't reach across the consumer's lexical scope to strip isolation from inner closure literals).

User: "cleanup + harmonize + update blog post such that we can return to it later." Updated:
- `Blog/Draft/result-builder-for-loop-performance.md` — added frontmatter `status: needs-revision-before-publish` + `revision_pending` block enumerating before-publish to-dos; rewrote "A note on `.map` and `.flatMap`" section's factual claims to SE-0423 framing; updated recommendations table and "Two distinct costs" summary; expanded References to include SE-0423, PR #82795, and the new research doc.
- `Blog/_index.json` — BLOG-IDEA-079 entry's `notes` field now flags revision-pending state and points at the draft frontmatter for the to-do.
- `Research/stdlib-collection-map-actor-isolation-overhead.md` — three small harmonization fixes (Documentation Updates table now records each downstream change as Applied/Pending; reference-list framing tightened; back-reference language no longer pins to a specific version of the parent doc).

HANDOFF scan at `swift-institute/` root: 9 files found.

| File | Authority | Disposition |
|------|-----------|-------------|
| HANDOFF-stdlib-map-specialization-gap.md | In-session (I worked it) | All Scope items (1–5) completed; Findings Destination honoured; no ground-rules block; no escalation. **Delete.** |
| HANDOFF.md | Out-of-scope (≥14d stale, no closure context) | Leave untouched per [REFL-009] conservative path |
| HANDOFF-blog-idea-078-init-overload-disambiguation.md | Out-of-scope (recent, not this session) | Leave untouched |
| HANDOFF-platform-audit-cycle-followup.md | Out-of-scope (recent-ish, not this session) | Leave untouched |
| HANDOFF-string-correction-cycle.md | Out-of-scope (≥14d stale, no closure context) | Leave untouched per conservative path |
| HANDOFF-swiftsyntax-linter-phase-2-stream-a.md | Out-of-scope (recent, not this session) | Leave untouched |
| HANDOFF-typed-time-clock-cleanup.md | Out-of-scope (≥14d stale, no closure context) | Leave untouched per conservative path |
| HANDOFF-unchecked-pattern-audit.md | Out-of-scope (recent, not this session) | Leave untouched |
| HANDOFF-windows-kernel-string-parity.md | Out-of-scope (≥14d stale, no closure context) | Leave untouched per conservative path |

Four files (HANDOFF.md, string-correction-cycle, typed-time-clock-cleanup, windows-kernel-string-parity) cross the 14-day stale-override threshold ([REFL-009] / [HANDOFF-038]) but I have no session context for their closure signals — never opened or worked them. Per the conservative path, leave untouched and note the ambiguity here. A future targeted bulk-triage cycle could revisit.

## What Worked and What Didn't

**Worked: empirical triangulation as the first move.** The single-file `swiftc -O` reproduction took ~30 seconds to set up and immediately broke the handoff's framing. Without that, I would have spent significant time spelunking `lib/SILOptimizer/` chasing a specialization mechanism that wasn't actually failing. Confidence shifted fast when the empirical mismatch surfaced — exactly the right direction.

**Worked: SIL grep as ironclad evidence.** `grep -c "apply.*swift_task_isCurrentExecutor"` returning 0 for V14 and 1 for V8 is the kind of binary mechanism evidence that doesn't admit handwaving. The diagnosis went from plausible to grounded in one command.

**Worked: web-search query specificity.** The query "Swift swift_task_isCurrentExecutor closure MainActor executor check overhead per element" hit PR #82795 and SE-0423 on the first search. Including the exact runtime-function name (which I had from the SIL output) targeted the search well.

**Didn't work initially: my first instinct was attribute spelunking.** I started by reading `@_alwaysEmitIntoClient` semantics in `lib/SIL/IR/SILFunction.cpp` because the handoff framed the issue as a specialization gap and I followed the framing. That reading was useful for *ruling out* "AEIC is broken" as a hypothesis, but it was a slower path than empirical reproduction. Should have started with the smaller isolation.

**Didn't work initially: I rejected option (B) on theoretical grounds.** When the user asked "is there nothing we can do?", my first response had dismissed shipping `Collection.fastMap` helpers based on reasoning about the deprecation cost. The user's pushback prompted the actual M3-vs-M4 empirical comparison, which confirmed (B) is redundant with the nonisolated structural fix — but the evidence is now empirical, not just argumentative. The reasoning was right; the rejection was made stronger by being empirical.

**Confidence calibration was healthy.** I was initially confident in the v2.1.0-style specialization-gap framing, in the sense of "this is what the handoff says and the empirical numbers fit." Confidence dropped fast when the single-file reproduction came back at 1.07×. No stickiness to the prior framing — empirical evidence dominated. Memory feedback `feedback_verify_prior_findings.md` paid off.

## Patterns and Root Causes

The handoff brief carried both empirical predictions ("19× slower at N=100, applies in/out of builder, ~40 ns/element") AND a causal explanation ("Collection.map's closure not specialized at the consumer call site... indirect-call + protocol-dispatch overhead"). The empirical predictions were all correct. The causal explanation was wrong. This is a subtle but consequential category: when symptoms agree but mechanism diverges, the *practical* recommendations can diverge meaningfully — wrong-mechanism in this case would have led to shipping `Collection.fastMap` workarounds, which empirically wouldn't help (the same SE-0423 mechanism applies whenever stdlib HOFs are called from `@MainActor` scope, regardless of what the institute ships in parallel).

The handoff's framing was the path of least resistance. I followed it into compiler-attribute reading before doing the cheap empirical check that broke it. Existing memory feedback covers *carried-forward findings* (`feedback_verify_prior_findings.md`) and existing research-process rules cover *empirical claims* ([RES-013a], [RES-023]), but neither explicitly addresses *causal-explanation claims*. A handoff specifying a mechanism is presenting a hypothesis disguised as a premise; the mechanism is in the verifiable-claims set, not the input set. The empirical numbers can fit a wrong mechanism if both predict the same magnitude (and a "specialization gap" and an "actor-isolation runtime check" both happen to predict ~40 ns/element on Apple Silicon — they're incidentally measurement-indistinguishable).

The "smallest isolation first" pattern is general, not specific to compiler issues. When investigating a build-target-scoped phenomenon, the question "does this reproduce in the smallest possible build artefact?" is the same kind of cheap-bisection move as "does this reproduce in the smallest possible source?" Compiler/runtime issues are no exception. SwiftPM's release build adds many things over `swiftc -O` — concurrency-mode default, `-entry-point-function-name` wrapping, cross-module-optimization enablement, library-evolution flags. Any of these could be the differentiator. Trying both up-front bisects the search space in seconds.

The structural-vs-API-surface tension came up again. The user's instinct "let's not do `Collection.map`" tracked the institute's broader bias toward fixing structure rather than adding parallel APIs, and was empirically validated by M3 ≈ M4. Memory feedback reinforces this in adjacent shapes (`feedback_no_gratuitous_l3_delegation.md`, `feedback_no_unsafe_api_surface.md`, `feedback_no_existential_throws.md`). The pattern: when faced with a transitional mechanism that will resolve upstream, prefer documenting the structural workaround over shipping a parallel API surface that needs deprecating later.

Documentation propagation was incomplete in one direction. I updated the new research doc, the parent research doc, the index, the blog draft, and the blog index — five artefacts. Two more carry the partial-truth framing and were not updated: `sequence-operator-unification.md` cites the lazy-pipeline-release-mode "intermediate arrays is 7× slower" data which is now narrower than the truth (the SE-0423 check is also a contributor at small N); the experiment headers in `Experiments/result-builder-map-investigation/` and `Experiments/lazy-pipeline-release-mode/` carry the specialization-gap and intermediate-arrays framings respectively. The experiment files are in the unpushed-batch declared "Do Not Touch" by the handoff's parent context. Not a defect of this session, but a propagation tail that needs follow-up authorization.

## Action Items

- [ ] **[skill]** research-process: extend [RES-013a] (Synthesis Verification) and [RES-023] (Empirical-Claim Verification for Dependent-Package State) to explicitly cover **mechanism / causal-explanation claims** in inputs to investigations. Statement direction: when a prior artefact (handoff brief, research doc, experiment header) specifies BOTH measured values AND a causal explanation, the explanation is part of the verifiable-claims set, not the premise set. Same-magnitude predictions can fit different mechanisms, and the recommended remediation diverges by mechanism. Provenance: this session.

- [ ] **[skill]** research-process or benchmark: codify the **"smallest isolation first" heuristic** for build-target-scoped performance investigations. Before accepting a build target's measurements as evidence about a code construct's intrinsic cost, attempt to reproduce in single-file `swiftc -O` (or the smallest equivalent isolation). If the gap doesn't reproduce, the cause is build-context-conditioned (concurrency mode, library evolution, entry-point wrapping, CMO state) and the investigation should pivot to the build configuration, not the source. Provenance: this session, where 1.07× isolated vs 22.9× SwiftPM was the breadcrumb that broke the handoff's framing.

- [ ] **[doc]** sequence-operator-unification.md: cross-reference Research/stdlib-collection-map-actor-isolation-overhead.md from the section that cites lazy-pipeline-release-mode's "stdlib eager `.map`/`.filter` with intermediate arrays is 7× slower" data. The framing "intermediate arrays cause the overhead" is partial-truth post-2026-05-07 — the SE-0423 actor-isolation check is also a contributor and dominates at small N. (Companion update to `Experiments/result-builder-map-investigation/Sources/main.swift` and `Experiments/lazy-pipeline-release-mode/Sources/main.swift` headers is blocked on user authorization for the unpushed Experiments batch.)
