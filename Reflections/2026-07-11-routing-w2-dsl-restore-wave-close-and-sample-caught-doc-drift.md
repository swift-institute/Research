---
date: 2026-07-11
session_objective: Fresh W2 orchestrator — execute the ratified Option-A compat-DSL restore in swift-url-routing, re-gate, and close the wave with the consolidated 4-repo push
packages:
  - swift-url-routing
  - swift-parser-primitives
  - swift-rfc-6750
  - swift-rfc-7617
status: pending
---

# Routing W2 close: DSL restore, a sample-caught doc drift, and resume-over-redispatch

## What Happened

Fresh orchestrator (coordinator seat, Fable; prior orchestrator session ended)
picked up W2 from the ledger's last ANSWER(supervisor) — Option A RATIFIED:
build the institute-backed pointfree-compatible DSL in swift-url-routing
Sources, then rewrite the 12 red test files onto it. Resume protocol: all four
held repos re-verified from git and matched the asserted tips exactly
(url-routing 30855674/19 · parser-primitives 0e81436e/4 · rfc-6750 4263f2a5/1
· rfc-7617 2ac9c6ed/1); nothing redone.

Pre-dispatch recon verified every load-bearing anchor at source:
`URLRouting.Router.swift:10` (existential typealias), `exports.swift` (OneOf/
Rest not re-exported; Parse not a dep), `PointFree.Compatibility.swift`
(existing alias seed), and — decisive — institute `Parser.Protocol` ALREADY
carries the body-authoring machinery (`var body: Body { borrowing get }` at
Parser.Parser.swift:113, `body: Never` leaf default, result-builders). That
re-classified item 1 from "possible new L1 authoring type" (escalation-shaped)
to "Sources-side protocol refinement" before dispatch.

One opus Sources lane executed the whole 4-point order: 3 commits (409004c4
DSL / 0859a170 test rewrite / 941d57ae pins), 188 tests / 18 suites green,
parser-primitives untouched, ask-clause never fired (`AnyParserPrinter` landed
consumer-side). Coordinator re-gate: update/build/test/dump/resolve all EXIT 0;
zero pointfreeco in 164 pins; no `swift-parsing` identity; no `Parsing` module.

The wave-gate sample of the two S1 judgment calls caught one real defect:
`FileUpload+ParserPrinter.swift:70-75` doc comment still described the RETIRED
Content-Type re-validation that judgment call (b) had narrowed away (behavior
itself was correct at :80-83). Routed back to the completed lane via message-
resume; one comment-only commit (010bfeb3, re-verified by diff + rebuild)
closed it. Supervisor endorsed the gate and enumerated the push window;
consolidated 4-repo push executed with a literal abort-on-delta pre-verify —
all rows rev-list 0 post-push. W2 closed Success [SUPER-010]; supervisor
stamped acceptance (ground rules 1–6 verified) and cut W3.

HANDOFF scan (cleanup, [REFL-009]): store guard reads 84 live files > cap 40 —
red by the documented per-arc-drain ruling; no force-drain (routing arc live).
1 file in session authority: `HANDOFF-routing-w2-2026-07-11.md` — left in
place; the supervisor's acceptance stamp already carries the [SUPER-011]
verification line and designates it the W2 terminal record, draining at
routing-arc close. `HANDOFF-routing-w3-2026-07-11.md` is a fresh out-of-
authority dispatch (not started). Remaining ~82 files out-of-session-scope.
Memory-corpus guard: OK (zero topic files, inbox within cadence).

## What Worked and What Didn't

**Worked — recon converts escalation risk into dispatch precision.** The
principal had flagged type-erasure as the likely STOP trigger. Twenty minutes
of pre-dispatch grep/read over parser-primitives showed the L1 engine already
had the body-protocol machinery, so the dispatch could state "item 1 is a
refinement, not a new type" with file:line anchors. The lane never stalled,
never escalated, and landed erasure consumer-side — the risk dissolved at
recon time, not at execution time.

**Worked — the sample earned its keep.** All three shells (lane, coordinator,
supervisor) independently reproduced 188/18 green; the mechanical gate was
never in doubt. The only defect the wave still carried was PROSE: a doc
comment contradicting an adjudicated behavior change. Only the judgment-call
sample looked there.

**Worked — message-resume for the fix round-trip.** The completed lane was
resumed with a surgical work order (one doc comment, one commit, reply with
SHA) instead of a fresh dispatch or a coordinator self-fix. Full context was
already loaded lane-side; the coordinator charter (gates+git+ledgers only)
stayed intact; cost was one round-trip.

**Friction — commit-as-you-go didn't happen inside the lane's first unit.**
At the mid-lane health check: 21 dirty files, zero commits. Defensible (the
DSL surface is one interdependent logical unit until first green), but a
lane death would have re-run the 626d974e checkpoint dance. The dispatch said
"commit per logical unit"; the lane read the whole DSL as one unit.

**Confidence** was high throughout — a ratified spec plus pre-verified anchors
leaves little ambiguity. The one moment of genuine uncertainty (is the stale
doc a blocker or noise?) resolved by asking what the artifact would mean
post-push: public docs claiming retired behavior on exactly the disputed
judgment call.

## Patterns and Root Causes

**Doc drift concentrates on adjudicated behavior changes.** When a judgment
call NARROWS behavior, the code is reviewed against tests (behavior), but the
doc comment describing the old behavior is reviewed against nothing — it
survives by default. The S1 lane changed the parse body and left the parse
doc. Generalization: for every adjudicated behavior change in a wave-gate
sample, grep the changed symbol's doc surface for the retired behavior. The
check is mechanical and cheap; the failure mode (shipping docs that contradict
the adjudication) is precisely the thing the sample exists to prevent.

**[SUPER-035] recon is risk re-classification, not just premise-checking.**
The rule is framed as "verify load-bearing claims before the block lands."
This session shows the stronger effect: empirical recon MOVES items between
risk classes. "New L1 type needed?" was an ask-clause trigger; after recon it
was a refinement over an existing protocol. The dispatch that names the
existing machinery (file:line) doesn't just avoid a false premise — it removes
the subordinate's justification for stalling or over-escalating.

**Resumable lanes flip the fix-routing default.** Historically a trivial
post-gate defect tempted either a charter breach (coordinator edits "just a
comment") or an expensive fresh dispatch. With message-resume, the original
lane — context loaded, [SUPER-043]-clean — is the cheapest correct route.
"Return to the originating lane" should be the default disposition for sample
findings, with coordinator self-fix remaining forbidden even for trivia.

## Action Items

- [ ] **[skill]** supervise: termination.md, [SUPER-009]-adjacent — wave-gate
  samples of adjudicated behavior-changing judgment calls MUST include the doc
  surface of the changed symbols (grep doc comments for the retired behavior);
  provenance: FileUpload+ParserPrinter.swift:70-75 catch, this session.
- [ ] **[skill]** supervise: conduct.md, [SUPER-043]-adjacent — codify
  resume-over-redispatch: verification-sample findings route back to the
  originating (completed) lane via message-resume; coordinator self-fix stays
  forbidden even for comment-only edits.
- [ ] **[package]** swift-url-routing: record Pass-2 insights in the package's
  Research notes — Foundation in the L3 main target ([ARCH-LAYER-007]),
  per-combinator typed-throws refinement, and the ParserPrinter
  Failure-pinning rationale (associated-type inference vs the Never default)
  so the Pass-2 brief doesn't re-derive them from the drained W2 ledger.
