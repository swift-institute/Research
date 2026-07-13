---
date: 2026-07-13
session_objective: Execute end-state wave E-1 as single orchestrator seat — migrate consumers onto the four INT packages, thin donors, close FS-01, restore marketing, keep the running app as acceptance oracle
packages:
  - swift-url-routing
  - swift-url-routing-authentication
  - swift-url-routing-vapor
  - swift-html-vapor
  - swift-email-html
  - swift-stripe-types
  - swift-stripe
  - swift-stripe-live
  - swift-server-foundation-vapor
  - boiler
  - repotraffic-com-server
status: pending
---

# E-1 Integration Cutovers: Orchestration Under Live Oracle Pressure

## What Happened

Single-seat orchestration of the E-1 wave (charter
`Workspace/handoffs/CHARTER-endstate-e1-cutovers-2026-07-13.md`, closed
Success 14:52:56): all four integration-package cutovers landed (INT-1
Authenticating → 6 consumers re-pointed, donor thinned, FS-01 closed fully;
INT-2 boiler reword + boiler/ssf-vapor thinning; INT-4 email park handover;
INT-3 demand check, later amended when demand materialized), plus five
supervisor-injected or emergent rows: R-0 (redis connection storm — CacheLive
`liveValue` was a computed property constructing a store per scoped
re-resolution), R-5 (marketing restoration — 46-file pf-DSL conversion via a
delegated sonnet lane), R-6 (pages rendered without document structure or any
of their 156 collected style rules), R-7 (nav gated on a request-auth-backed
`identity.current` the dev stub never populated), and a harness-level kill
denial that resolved into a standing principal grant. Eleven repos pushed
under a mid-arc standing grant; three visual gates passed via
supervisor-side computer-use screenshots.

HANDOFF scan ([REFL-009]): guards run at session end. `check-handoffs.sh`:
0 loose `HANDOFF*.md` at the working-directory root; 5 store residents
flagged ([HANDOFF-008a], report-only) — CHARTER-endstate-e1-cutovers (mine:
arc CLOSED-accepted 14:52:56; left in store as the arc record and the
carrier of the delta-table errata future cutover waves inherit, per the
per-arc-drain ruling; closure is recorded in-file by the supervisor's
acceptance + my ACK, so nothing misleads) · CHARTER-endstate-e2-di-research,
CHARTER-endstate-e2-execution, CHARTER-endstate-e3-records-r2,
PROGRAM-repotraffic-endstate (all four in-flight, other seats'/supervisor's —
out of cleanup authority, no-touch per [REFL-009a]). `check-memory-corpus.sh`:
OK — zero topic files, inbox within cadence. No `/audit` invocation this
session, so no finding statuses to update.

## What Worked and What Didn't

Worked: the ledger channel carried five ASKs at minutes-latency, each with a
rendered fix attached — every grant came back scoped and immediate, vindicating
render-first-ask-once. Diagnosis-first on every injected row paid for itself
twice by *falsifying* the supervisor's hypothesis with primary-source evidence
(theme.css "clobber" was a whitespace-only diff; the render defect was
emission-path, not assets). Byte-level verification before every visual gate
meant zero visual-gate failures. The [HANDOFF-021] re-verify discipline caught
the reword order's stale scope (5 trailer-bearing commits, not 3).

Didn't: (1) I deleted BillingLive's `import Authenticating` as "vestigial" on
symbol-grep evidence — 104 MemberImportVisibility errors later, the lesson is
that member *access* (`.client`) doesn't grep as a symbol; grep is a
false-negative test for import vestigiality, only a compile gate decides.
(2) A gate command without an explicit `cd` built the wrong package
(background tasks snapshot launch-time cwd; foreground `cd` persists
invisibly) — one full build round wasted, and the mistake was only visible
because the errors named foreign paths. (3) The delegated conversion lane
copied the Response bridge from the app target — the pre-R-6 form I had fixed
40 minutes earlier — and only orchestrator review caught the known-defective
copy before first serve. (4) One foreground build was SIGTERM'd by the Bash
tool's 2-minute default timeout; background-with-notification was always the
right shape.

## Patterns and Root Causes

The arc's dominant pattern: **a component that IS an X but participates as a Y
silently loses X's machinery**. Three instances in one day: (a) HTML.Document
nested inside a view body renders through the generic `_render` path — no
doctype, no head/body wrappers, no collected-style splice, because the
two-phase style collection lives only in `_renderHTMLDocument`, reached only
via the document entry point; (b) `Cache.liveValue` as a computed property
participates in every scoped dependency re-resolution as a fresh
construction — the capture-once semantics everyone assumed live only in
`static let`; (c) `identity.current` as a request-auth-backed computed
property participates in the stub'd dependency graph but reads a store nobody
populates. In each case the type-level claim ("this is a document", "this is
the live value", "this is the current identity") was structurally true and
behaviorally false because the *path* through which it was consumed bypassed
the machinery that makes the claim good. The fix was always the same: route
consumption through the path that carries the machinery (document entry
point, `static let`, auth-store population).

Second pattern: **copies propagate the defect state at copy time, not at
review time**. The lane's bridge copy was correct methodology (mirror the
app-side precedent) executed against a precedent that had been fixed
mid-flight. Supervision implication: when a defect fix lands in file F during
an arc with active lanes, the orchestrator owns a copies-of-F sweep at lane
review — the lane cannot know its reference went stale.

Third: the harness kill-denial showed the two-tier authority model and the
harness permission model are distinct layers — a supervisor ledger grant is
not a principal grant to the harness. Routing it as a relay (ledger + push
notification) rather than working around it was correct and produced a
standing principal rule within 25 minutes.

## Action Items

- [ ] **[skill]** swift-package-build: add a rule (PKG-BUILD-021-class) requiring every gate invocation to pin its working directory explicitly (`cd <pkg> && …` in the same command, or absolute paths) — background tasks snapshot launch-time cwd while foreground `cd` persists silently across turns; a cwd-drifted gate builds the wrong package and its green/red is evidence about the wrong target (origin: stripe-live gate 5 built the app).
- [ ] **[skill]** supervise: add a lane-review obligation (SUPER-069-class) — when a defect fix lands mid-arc in a file that delegated lanes may use as a copy/reference precedent, the dispatching orchestrator sweeps lane output for copies of the pre-fix form at review (origin: marketing lane copied the pre-R-6 Response bridge; caught before first serve).
- [ ] **[research]** swift-html-render: should `HTML.Document` be renderable as a nested child view at all? The generic `_render` path silently drops doctype/wrappers/collected-styles — options: forbid the View conformance path, make nested render delegate to `_renderHTMLDocument`, or emit a loud diagnostic (origin: R-6, quirks-mode tag soup served with 0/156 style rules).
