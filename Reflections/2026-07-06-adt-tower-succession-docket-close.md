---
date: 2026-07-06
session_objective: ADT tower seat succession — adjudicate the parked docket at fable tier, execute the W4 residuals and W5 re-stage to project finish
packages:
  - swift-tree-primitives
  - swift-tree-keyed-primitives
  - swift-graph-primitives
  - swift-io
  - swift-cache-primitives
  - swift-primitives-linter-rules
status: pending
---

# ADT Tower Succession: Docket Adjudication, W4/W5 Close, and a Compiler-Refuted Ruling

## What Happened

Successor seat booted from `HANDOFF-adt-tower-seat-succession.md`; [HANDOFF-016]
re-verification green (census 15/0/2/5, 28 tower repos clean, P5 artifact intact). Adjudicated
the six-item docket: P1+P2+P3+DS-024 → defer-to-pull as one chartered generational/pool leg;
P4 → per-instantiation disjoint `Error` aliases; P5 → defer-to-pull with the bounded route
recorded; Bucket-C KEEP ratified; io crash → issue-investigation dispatched. The P4 ruling was
then **compiler-refuted** by its executor's probe matrix (member-type lookup offers all
same-named conditional typealiases regardless of where-clause disjointness — even concrete
disjoint `S == A` / `S == B` pins collide); re-ruled to the S.Error flow-through
(error-flows-from-the-column, D6/D9 pattern) and landed (tree `ea60802`+`9deca7d`, tree-keyed
`e33e743`+`913dab6`, 89/8 fresh-chain green). En route: an M1-class `~Copyable` restatement
defect on both tree storage conformances (move-only doors untypecheckable on main) found by
the trees-SIL probe leg and fixed in the lockstep; the keyed-specific wrapper surface ratified
Copyable-only (documented-deliberate posture; move-only flows via the shared surface —
receipt-proven). W4 residuals all landed: skill-rider pass (4 Skills commits + new [DS-030]),
Tracked-comment sweep (2 files; audit-F7 item moot — host file deleted 2026-06-23), g2
manifest repair, graph import repair (7 files, not the recorded 4) + §A9 unguard probe (still
crashes on 6.3.3; guards stay), DS-026 partial lint promotion (`Lint.Rule.Tower.
CarrierColumnBound`; 0 FPs across 3,235 files), trees SIL 0-witness receipt incl. the
move-only door. io crash investigated to closure: **catalog §A9 same-class** (site 3
re-surfaced; Tagged key load-bearing; crashes with Copyable values AND in release —
two priors refuted); Issues dossier `afeabd7` + io guard `90abb792` landed; a committed
MemberImportVisibility drift in cache-primitives (blocking the io/kernel graph) seat-fixed
(`d216bf3`). W5 staged as ONE consolidated brief (46 reshaped / 161 untouched / NO-GO list).
Catalog: §A9 new-site addendum + B3 generalization (Research `dd78805`). The principal flagged
publication-arc contamination (rider-3 scan tooling occupying the tower chat) and directed a
close-adjudication handoff: `HANDOFF-adt-tower-arc-close.md` authored (Workspace `094a2ea1`);
this seat stood down.

HANDOFF scan ([REFL-009]): guard RED at 85/40 — by design until arc close; do-not-retriage
stands (BACKLOG tower-cluster drain). Session-authority files: seat-succession handoff —
annotated CONSUMED, left for the post-close drain; arc-close handoff — fresh dispatch, left
(`pending verification — fresh dispatch, no work yet`); BRIEF-adt-tower-w5-restage.md — live
W5 deliverable, left; PROMPT log + overnight REPORT + DOSSIER-w3 — live records until the
close session's drain, left. Remaining ~78 store files out of session authority, untouched.
No /audit invoked; no audit.md status updates owed (the DS-026 PROMOTE record landed via its
own leg, Audits `ecc111b`).

## What Worked and What Didn't

**Worked.** The STOP discipline again functioned as design-surface detection: the P4 executor
refused to improvise, produced a decisive probe matrix, and the refutation IMPROVED the design
(flow-through beats disjoint aliases on the algebra's own philosophy). Repo-disjoint parallel
legs with seat-FF landing scaled cleanly (9 legs, ~35 commits, zero worktree collisions);
twice-racing the parallel /promote-rule arc on Skills/Audits resolved by trivial rebases.
Cross-session artifact survival paid twice (predecessor's reducer + probe-trees recovered from
its scratchpad). Probes kept beating priors: §A9's "DEBUG-only" prior and the ~Copyable-value
prior both refuted by the reducer.

**Didn't.** (1) The seat's original P4 ruling prescribed a type-system mechanism from
precedent analogy (the M10 Bounded per-instantiation shape) without noticing the precedent's
hidden cardinality: those carriers have exactly ONE `Error` alias; the tree case needed TWO.
An executor probe caught it, but a ten-line write-time compile probe would have caught it
before dispatch. Confidence was misplaced precisely where the ruling felt best-grounded.
(2) Recorded scope counts drifted low twice (graph 4→7 files; comment sweep 3→2+moot) —
honest disclosure absorbed it, but both were knowable at write time by enumeration.
(3) The tower chat adjudicated a publication-arc question (rider-3 secrets-scan tooling) far
past the point it should have been routed out; the principal had to push back. The handoff
instructed the seat to get it ruled, but composition-with-another-arc's-gate should have been
read as "surface a pointer," not "carry the adjudication."

## Patterns and Root Causes

**A landed precedent is evidence for its own configuration only.** The P4 failure is the
[REFL-011] tool-reach class transposed to design rulings: the precedent's *reach* (one
conditional alias per carrier) was narrower than the ruling's claim (two disjoint aliases
coexisting), and the delta was invisible because the analogy felt strong. The compiler is the
only authority on type-system mechanisms; a config delta between precedent and proposal —
here, candidate multiplicity — is exactly the place a 30-second probe pays. This is now the
second seat-prescription refutation of the arc caught by executor discipline (List.Linked
doc-vs-dispatch was the first): dispatches should state MECHANISM as hypothesis-to-probe,
gates as facts.

**Cross-arc preconditions leak into whichever chat carries them.** Rider 3 composes the tower
flip with the ecosystem publication gate; the succession handoff turned that composition into
an in-lane ruling item ("pick the scan tooling"), and the seat dutifully escalated a
non-tower decision in the tower lane until the principal objected. Root cause: no routing
convention distinguishes "this arc must SATISFY gate G" from "this arc must DECIDE gate G's
parameters." The fix is a handoff-authoring discipline, not seat vigilance.

## Action Items

- [ ] **[skill]** handoff: add a writer-side rule — a handoff/dispatch that prescribes a
  type-system MECHANISM (alias topology, conformance shape, constraint trick) MUST either cite
  a compile probe of that exact configuration or mark the mechanism hypothesis-probe-first;
  precedent citations must name config deltas (origin: P4 disjoint-alias refutation,
  2026-07-06; catalog B3 generalization).
- [ ] **[skill]** handoff: add a cross-arc precondition routing rule — when a dispatched arc
  carries a precondition that COMPOSES with another arc's gate, the handoff phrases it as
  "satisfy + pointer to the owning arc," never as an in-lane adjudication item (origin:
  rider-3 scan-tooling contamination of the tower chat, principal pushback 2026-07-06).
