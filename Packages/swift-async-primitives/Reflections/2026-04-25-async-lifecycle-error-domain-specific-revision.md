---
date: 2026-04-25
session_objective: Refactor Async.Lifecycle.Error to non-generic Pool-style enum and adopt across per-primitive errors
packages:
  - swift-async-primitives
status: pending
---

# Async.Lifecycle.Error Refactor — Mid-Cycle Domain-Specific Revision

## What Happened

The session began with a focused refactor brief at `HANDOFF.md`: drop the `<E>`
generic parameter from `Async.Lifecycle.Error`, rename cases to Pool-style
spellings (`shutdown` / `cancelled` / `timeout`), drop `mapFailure`, and adopt
the new envelope across `Async.Semaphore`, `Async.Broadcast`, `Async.Channel`,
and `Async.Completion` via either a typealias (Semaphore, Broadcast) or an
`Either<Lifecycle.Error, DomainError>` wrap (Channel, Completion). The brief
carried a Supervisor Ground Rules block per `[SUPER-002]` and an Adoption
Mapping table marked "load-bearing — do not drift case-sets or scope."

Steps 1 and 2 landed cleanly. `Async.Lifecycle.Error` was redesigned as a
non-generic 3-case enum (commit `35c329d`); `Async.Semaphore.Error` became
`typealias Error = Async.Lifecycle.Error` (commit `0b1f79b`). All three
lifecycle cases (`shutdown` / `cancelled` / `timeout`) are produced by the
Semaphore surface, so the typealias was a clean fit.

Step 3 (Broadcast typealias, commit `bdd167d`) landed but the principal
flagged it on review: *"is that correct?"* — pointing out that
`Async.Broadcast.Error` only produces `.cancelled`; the `.shutdown` and
`.timeout` cases are unreachable. The principal then articulated the
revised principle: *"prefer Domain-specific Errors. in particular if other
Async.Lifecycle.Error cases don't apply."* I proposed reverting Step 3 and
skipping Steps 4–5 (Channel and Completion likewise have lifecycle cases
that don't all apply); the principal authorized with *"do as you advise."*

Step 3 was reverted (commit `eaeee25`) rather than reset, preserving the
bisectable trail. Steps 4–5 dropped from scope. The cumulative tracked diff
against `4d014e4` is 3 files (`Async.Lifecycle.Error.swift`,
`Async.Semaphore.Error.swift`, one case-spelling line in `Semantics.md`).
Tests stay 200/200 in 40 suites at every commit.

The revision was stamped into `HANDOFF.md` under `## Live Revisions` per
`[HANDOFF-016]` and supervisor entries verified end-to-end per
`[SUPER-011]`. Each typealias commit required `rm -rf .build` to clear a
stale `lazy protocol witness table accessor` symbol before tests would
link — caught and resolved per `feedback_clean_build_first`.

`HANDOFF.md` scan: 1 file found at the working directory root. All Next
Steps the principal authorized are complete, all 4 ground-rules entries
verified per `[SUPER-011]`, no pending escalation, the file is gitignored
locally per `[HANDOFF-015]`. Triage outcome: annotated-and-left until the
principal disposes of the unpushed commits; the file is not git-tracked
and its annotations are session-local.

No `/audit` was invoked this session, so `[REFL-010]` does not apply.

## What Worked and What Didn't

**Worked**: The per-enum bisectable commit plan held. Each commit compiled
and tested green in isolation; the revert preserved the trail rather than
rewriting history. `[HANDOFF-016]` Live Revisions and `[SUPER-021]`
mid-cycle revision composed cleanly — the original Adoption Mapping
remained published for traceability while the revised table superseded it.

**Worked**: The principal's review at the announcement of Step 3 (rather
than after all five steps) caught the design issue at the cheapest
moment. If the review had come after Step 5, the rework would have
included Channel migration (the heaviest, with 9+ throw sites and storage
continuation resumes touching the public Error type).

**Didn't work as well**: The brief's acceptance criterion #6 — "Per-enum
commit history: at least 5 commits between HEAD and `4d014e4`" — was
phrased as a count, not as the property the count was meant to encode
(bisectability). Under the revision, only 4 commits land. The
bisectability invariant the criterion encoded is still preserved, but
the literal criterion fails. I had to explicitly call out that the
criterion was "revised — 4 commits, bisectability invariant preserved"
rather than simply marking it green.

**Didn't work as well**: I followed the brief's Adoption Mapping table
literally for Broadcast (`typealias Error = Async.Lifecycle.Error`) even
though the case-applicability mismatch was visible in the brief itself
(*"Gains `.shutdown` and `.timeout` as available cases"*). The brief
authorized the typealias; my docstring even noted the unreachable cases
("`.shutdown` and `.timeout` are reachable in principle but not produced
by the current Broadcast surface"). The mismatch was visible to me but I
did not surface it as a design concern — I accepted the brief's
authorization. The principal's review caught it.

## Patterns and Root Causes

**Pattern 1 — Canonical-envelope adoption tests case applicability, not
just structural shape.** When a primitive adopts a shared error envelope
(here `Async.Lifecycle.Error`), the right test is *do all envelope cases
apply meaningfully?*, not *does the typealias compile?*. Adopting an
envelope where some cases are unreachable adds dead vocabulary at the
public API surface — readers of `Async.Broadcast.Error.shutdown` would
reasonably expect a Broadcast `shutdown()` method that doesn't exist.
This is a corollary of `[IMPL-INTENT]` (code reads as intent): the
typealias declares an intent the implementation doesn't carry. The
Pool–Lifecycle–Async parallel that motivated the brief is a partial
parallel — Pool produces all three, Async-as-a-namespace produces all
three across primitives, but no single Async primitive other than
Semaphore does. The right unit of "does the envelope apply" is the
primitive, not the namespace.

**Pattern 2 — "Load-bearing" markers on a brief constrain the
subordinate, not the principal.** The Adoption Mapping table was marked
"load-bearing — do not drift case-sets or scope" precisely so the
subordinate would not silently change it. But the principal can always
revise — the brief's prohibition is a one-way constraint. `[SUPER-021]`
codifies this for weakening revisions (which is what this was — narrowing
adoption from 4 primitives to 1). The "load-bearing" stamp was honored:
I did not drift, I asked when the principal raised the question, and the
revision was processed via the proper channel. The marker did its job.

**Pattern 3 — Visible-but-unsurfaced mismatches.** I noticed during
Step 3 that the Adoption Mapping itself acknowledged Broadcast would
"gain `.shutdown` and `.timeout` as available cases" — i.e., cases that
don't apply. I encoded the mismatch in the docstring rather than
escalating. The right move per `[SUPER-005]` would have been class (b):
*"Brief authorizes typealias for Broadcast, but `.shutdown` and
`.timeout` are unreachable on the Broadcast surface — confirm before
proceeding?"* The principal would have caught it at zero cost. Instead,
the mismatch was caught after the commit landed. The cost was small
(one revert) but the discipline is general.

**Pattern 4 — Acceptance criteria that quantify instrumental goals
become brittle under revision.** *"At least 5 commits"* encoded
bisectability, but bisectability is the property and 5 is the
instrument. Phrasing the criterion as *"every commit between
`4d014e4` and HEAD compiles and tests green"* would have survived the
revision unchanged. Instrument-shaped criteria break on weakening
revisions even when the encoded property holds.

**Pattern 5 — Stale linker symbol after `enum → typealias` swap.**
Replacing `public enum Error { ... }` with
`public typealias Error = Already_Conforming_Type` produces a stale
`lazy protocol witness table accessor` linker symbol from the
pre-typealias build. Tests fail to link until `.build` is cleared. This
is a build-artifact hygiene issue, not a code issue. `feedback_clean_build_first`
covers the general "rm -rf .build before debugging unexpected failures"
case; the specific signature ("lazy protocol witness table accessor for
type ... and conformance ... : Swift.Error") is a tell that the symbol
predates the current source state.

## Action Items

- [ ] **[skill] code-surface**: Add a rule on canonical-envelope adoption — when typealiasing a primitive's error to a shared envelope, all envelope cases MUST apply meaningfully to the primitive's surface; otherwise prefer a domain-specific enum. Cross-reference `[API-NAME-004a]` (namespace adoption typealiases) which has an analogous "domain behavior built on top" test for namespace adoption.
- [ ] **[skill] handoff**: Acceptance criteria SHOULD be phrased as the property the criterion encodes, not as the instrument that produces the property. Examples: prefer "every commit compiles and tests green" over "at least N commits"; prefer "no diffs to sibling packages" over "exactly M files changed". Instrument-shaped criteria become stale on `[SUPER-021]` weakening revisions.
- [ ] **[package] swift-async-primitives**: Note in `Research/_Package-Insights.md` that replacing `public enum Error` with `public typealias Error = Async.Lifecycle.Error` (or any pre-conforming type) produces a stale `lazy protocol witness table accessor` symbol; `rm -rf .build` is required before tests will link. Pattern occurs once per typealias commit.
