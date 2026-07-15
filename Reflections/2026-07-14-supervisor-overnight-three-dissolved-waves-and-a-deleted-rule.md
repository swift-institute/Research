---
date: 2026-07-14
session_objective: L1 workspace supervisor for an overnight run — verify a predecessor's claims, supervise three live seats (E-6 native review, HTML-tower wave 2, general orchestrator), and set up an overnight plan plus baton for review by a separate account.
packages:
  - swift-authentication
  - swift-dual
  - swift-favicon
  - swift-server-foundation-vapor
  - repotraffic-com-server
status: pending
---

# Three planned waves dissolved on contact with the disk — and the rule that caught the third was one hour old

## What Happened

I ran the L1 workspace supervisor seat overnight under the three-tier topology
([SUPER-070]/[SUPER-071]), holding the push grant and adjudicating for three live
subordinate seats over a ledger-channel bus. The night's arc was not the work I expected
to supervise; it was a sequence of planned work items evaporating when probed.

**The three dissolutions:**

1. **E-6 (the END-STATE program's final wave)** was chartered over 18 packages carrying
   six work items. Its seat walked all 18 against the disk and **all six dissolved**: the
   ELG split-conformance fix had landed a day *before* the charter was written
   (`swift-server-foundation` `26049fc`); `theme.css` churn was fixed-and-guarded;
   `swift-favicon` was CLEAN (the flagged "fix" would have broken a tested CDN contract on
   a public package and left the real bug — app-side DI — live); M-1 was sold as "4 files"
   and was 108, half of it in a forbidden repo, with the shells still standing afterwards;
   Foundation-in-L2 was already ruled deferred; the `@_exported` blast radius was ~5×
   over-stated *inside its own ASK*. True state: CLEAN 8 / MECHANICAL 0 / zero commits.

2. **The `swift-dual` `@Cases` arc — which I chartered myself** — was void on contact with
   source. The HTML-tower seat ran the research gate I ordered, refused to start the port,
   and refuted the premise: `.convert(apply:unapply:)` is backed by `Parser.Conversion.Case`,
   whose forward direction is the total embed; the call sites downcast, forcing a total
   forward `(A) -> B`; no key path can ever satisfy that because enum extraction is
   inherently partial. The task was additive, needed no Group-B change, would have gated
   `swift-identities-types` GREEN — and unblocked none of the 12 call sites.

3. **Lint wave-0** — the principal authorized "let's do the lint wave." Before chartering
   I ran [SUPER-072] (which I had written ~one hour earlier) and found it had been complete
   since 2026-07-07 (`995a237`). Disk census, positive-controlled: 128 repos / 8 orgs →
   106 already flipped, 22 without `Lint.swift`, **zero open**. `CLAUDE.md`'s "Project
   Status (live)" had described it as a pending dispatched arc for a week.

**What actually landed and shipped** (all guard-scanned, SHA-pinned): `swift-authentication`
`Identity Frontend` + `Consumer` GREEN (`76a27d6..2dbe7f2`, zero silencers verified against
a firing positive control, `Standalone` honestly red); a live favicon bug fixed in
`repotraffic-com-server` (`2d0b002..2d9cac2`, zero commercial-doc leak verified); `gate.sh`
+ `toolchain.sh`; two supervision rules ([SUPER-072]/[SUPER-073]); and six `CLAUDE.md`
gotcha rows. I also created a fresh-L1 baton, an overnight lint-wave-1 charter (gated on a
mandatory re-measurement), and a review baton for a separate Fable account.

**Handoff scan ([REFL-009])**: 4 `HANDOFF*` + 4 live `CHARTER*` at the store root.
`HANDOFF.md` (fresh L1 baton) and `HANDOFF-review-overnight-plan.md` — fresh dispatches,
no work yet → left, no annotation. `CHARTER-endstate-e6-…`, `CHARTER-html-tower-wave2-…`,
`CHARTER-general-orchestrator-…`, `CHARTER-lint-wave1-…` — all **live channels for
running seats** → no-touch per [REFL-009a] (in-flight wins over any annotation). Zero
deleted, correctly: nothing is complete-and-verified while the seats are mid-flight.

## What Worked and What Didn't

**Worked: the seats out-corrected the supervisor six times, and the topology let them.**
Every dissolution was surfaced by a subordinate probing the disk instead of trusting its
charter. The ledger-channel bus made those corrections cheap and auditable. The single
best act of the night — the HTML-tower seat refusing to build the cheap, additive,
plausible `@Cases` change I assigned and refuting it from source — is exactly the behavior
the research-gate-as-ground-rule-1 ([SUPER-025]) is meant to produce.

**Didn't (mine, in ascending cost):**

- **Dead watches.** I armed doorbell watches on two ledgers with a `grep -c … || echo 0`
  fallback. `grep -c` on an empty file prints `0` *and exits 1*, so the fallback fired *as
  well*, poisoning the baseline; both arcs held for rulings 25–40 min while I read silence
  as progress — having spent the same evening telling seats that watch-silence is unverified
  state.
- **Deleted a correct rule and pushed it.** An orchestrator refutation (a `CLAUDE.md`
  heuristic "false-positived on a healthy build") was well-argued, self-critical, and
  against the reporter's own interest — so I struck the rule and pushed. The refutation was
  a broken probe: `pgrep -c` does not exist on macOS, so its `|| echo 0` returned a constant
  zero it never actually observed. I restored the rule from primary source.
- **Chartered a void task on a frame I built myself.** I asked "is it additive?" and "does
  it need the read-only router?" — both had comfortable answers — and never asked "does it
  work." The regression control I *chose* would have passed on a green no-op.

Confidence was highest exactly where I was most wrong: I called the `pgrep` refutation "the
best instrument work of the night" moments before it turned out to be fabricated data.

## Patterns and Root Causes

**One root cause under all three dissolutions: a record is not a work item, and a stale
record is indistinguishable from a live one at read-time.** A work item is *recorded* in one
place (a carry-forward, a banked flag, a Project-Status bullet) and *closed* in another (a
commit) — and nothing connects them. Every dissolved item's source record was honest when
written and wrong when read. The worst carrier was `CLAUDE.md`'s "Project Status (live)",
because it is the one artifact every seat boots on: a stale line there is not a documentation
nit, it is a work-generator that manufactures charters and consumes seats. This became
[SUPER-072] (verify OPEN at dispatch; `git log -S<token>` finds the commit that already
closed your item) and [SUPER-073] (the commit that lands a fix stamps the flag; the status
file is stamped at every close; `.trash/` is a record, never a source).

**A second pattern cuts across the instrument failures: a status you did not compute is a
claim, not a measurement — and this extends to refutations and control choices.** The dead
watch, the `pgrep` fabrication, and the deleted rule are the same failure as the 702-roots
trap and the truncated pipe: a zero from an instrument that did not look. The novel
extensions this session: (a) **a refutation is itself a claim** requiring the same positive
control as the thing it refutes — and it is *most* seductive when well-argued, self-critical,
and against the reporter's interest, because those are the three properties that make a wrong
claim hardest to doubt; (b) **a control that cannot fail on the defect you are hunting is a
rubber stamp with a build log attached** — a regression control proves you didn't break the
old thing, and says nothing about whether you fixed the new one.

**The meta-pattern is the uncomfortable one.** I authored [SUPER-072] against exactly the
failure that, one hour later, I nearly committed by chartering lint wave-0. Knowing a rule
by name does not immunize you against violating it; the rule has to live in a *mechanical
gate at the moment of action*, not in recall. This is the same lesson as the zsh-trap
recurrence in [REFL-012] and the deleted-rule incident: guards belong in the check, not in
memory. The overnight plan going to independent review is the only reason the void `@Cases`
task got a research gate at all — external review functioned as the mechanical gate that
recall did not provide.

## Action Items

- [ ] **[skill]** supervise: extend [SUPER-009] (acceptance criteria) — a criterion MUST name
  the currently-failing case the change must make pass; a regression control that cannot fail
  on the target defect is not a control ("rubber stamp with a build log"). Currently only a
  `CLAUDE.md` gotcha row; belongs as a normative acceptance-criteria rule.
- [ ] **[skill]** supervise: a subordinate's refutation is a class-of-claim requiring the same
  positive-control ([SUPER-054] family) as the claim it refutes; strike a durable rule only on
  a re-run instrument, never on an argument — *especially* when the argument is self-critical
  and against the reporter's interest. Currently only a `CLAUDE.md` gotcha row.
- [ ] **[blog]** "Three waves dissolved in one night": stale records as work-generators in
  multi-agent supervision — the record/close disconnect, why the status file is the
  highest-leverage stale prescription, and why a supervisor authored the exact rule he then
  nearly violated.
