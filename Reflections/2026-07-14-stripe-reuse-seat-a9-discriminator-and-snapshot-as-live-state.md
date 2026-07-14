---
date: 2026-07-14
session_objective: Close goal 2 (Stripe) — a logged-in verified user subscribes to a paid plan in TEST mode from the browser, the webhook lands signature-verified, the account reflects it, and the paywall flips
packages:
  - swift-stripe
  - swift-stripe-types
  - swift-stripe-live
  - repotraffic-com-server
status: pending
---

# Stripe re-use seat: the §A9 discriminator, and "a snapshot treated as live state" at four levels

## What Happened

Seat: stripe-reuse orchestrator (L3 arc), supervised by L1 workspace over the
`CHARTER-stripe-reuse-2026-07-14.md` ledger channel. Goal 1 (auth) had closed earlier in the
session and was principal-attested in Safari; this arc was goal 2.

Delivered, in order:

1. **Pre-authorized zone fix** — `swift-stripe` `Sources/Stripe Shared/WebhookSignature.swift:5`
   imported `Crypto` with no manifest edge ([MOD-038]). Declared the `apple/swift-crypto` package
   edge + `Crypto` product on the `Stripe Shared` target. Gate green, pushed (`3e94f60`). The
   HTML-tower arc's Web Elements gate was parked on it.
2. **Caught a false green in Lane A's price-catalog fix.** The env-backed `STRIPE_PRICE_ID_*`
   mapping read variables that existed **nowhere persistent** — Lane A passed them inline at its own
   gate boot. Every stock boot still threw `noPriceForTier`. Persisted the 8 keys to
   `.env.app.development` (append-only, byte-for-byte backup, original bytes proven unmodified,
   values never printed) and discharged on a **stock boot**, which was the only evidence class that
   could discharge it.
3. **Discovered two Postgres servers contending for :5432** — a native one (specific bind on
   `127.0.0.1`/`[::1]`) and the `sprint-postgres` container (wildcard `0.0.0.0`). The specific bind
   wins, so **the app talks to the native server while everyone was inspecting the container**. Same
   db name, same user; only the *schema* distinguishes them (the container has no `identities`
   table). The 102 repos and the linked GitHub account from Pass-1 were stranded in the container.
   The app's real DB had 0 accounts, 0 repos — so the gated export route threw `accountNotFound` for
   *everyone* and there was nothing to flip.
4. **Ran the whole user journey on my own DoD identity** (supervisor ruling (iii), which took the
   principal off the critical path): register → verify via the real verify route → login (cookies) →
   link GitHub (PAT form, not OAuth) → bulk sync populated **100 repositories** → captured the ★
   **402** before-state.
5. **Ruling J compat path** (lane B): create-only `Compat_Swift_6_3` routers in swift-stripe-types
   whose route bodies are *verbatim copies* of the generated routers' `.create` branches, minus the
   `{id}` routes. `GET /checkout?tier=daily` went from exit-139 SIGSEGV to a real
   `cs_test_…` session. Metadata read **back from Stripe's API** (not assumed): `identity_id`
   present, `livemode=false`, $6.00 line item.
6. **Found the bug hiding behind the crash.** First post-compat run threw `noPriceForTier` despite
   the boot logging `tier_prices=3`. Root cause:
   `Billing.Stripe.PriceMapping.Client.liveValue` is a **computed property** allocating a fresh
   `MappingStorage` actor per evaluation, and boiler **re-applies the composition root on every
   request** (`Boiler.execute.swift:166-170` calls `dependencies(&values)` per request). The mapping
   loaded at boot was written into a scope discarded before the first request. Fixed by hoisting the
   storage process-wide (`2d0b002`).
7. **DoD met.** Test card `4242` on Stripe's real hosted page (Playwright) → webhook received and
   signature-verified → `subscriptions` row `tier=daily, status=active` → the same export route for
   the same user, same repo: **402 → 200** with real traffic data.
8. **Retracted my own escalation.** I had relayed lane B's inference that
   `billing.portal.createSession` would §A9-crash for paid subscribers, and sharpened it to the
   principal as a *live hazard* on his standing instance. I then tested it on a throwaway port: it
   does **not** crash (HTTP 303 to a real Stripe billing-portal session, process alive, zero
   `failed type lookup`). Amended catalog §A9 with the **discriminator** and three verified negative
   controls, and pushed it myself (`19ff374`).

Commits: 6 (swift-stripe `3e94f60`; swift-stripe-types `fdb024b`; swift-stripe-live `2c5e62b`;
repotraffic `7a71a98` + `2d0b002`; Research `13bdb0c` + `19ff374`).

**Handoff triage** ([REFL-009]): `check-handoffs.sh` → **VIOLATION, 55 live > 40 cap**, plus 1
filename-terminal resident (`PROGRAM-repotraffic-endstate-2026-07-13.md`). Files scanned in my
authority: `CHARTER-stripe-reuse-2026-07-14.md` (DoD closed, seat stood down — **left, no-touch**),
`CHARTER-identity-reuse-2026-07-14.md` + `LANE-cookie-session-2026-07-14.md` +
`CHARTER-identity-html-2026-07-14.md` + `CHARTER-auth-products-2026-07-14.md` (all closed —
**left, no-touch**). **Disposition: no-touch on all five, per [REFL-009a].** These are not inert
handoff records — they are **live ledger channels with L1's session-lifetime count-based watch armed
on the file paths**. Moving them to `Audits/` (the [HANDOFF-008a] disposition) or deleting them would
break a live supervisor's watch mid-flight. The per-arc drain is L1's to run as the channel hub under
the three-tier topology, not the arc seat's. `PROGRAM-repotraffic-endstate-2026-07-13.md` is
out-of-authority (not my arc). The 55>40 overage is the documented-red state
(CLAUDE.md: "hold 40 as the target; drain per-arc at each close"), and this arc's close is exactly
the drain trigger — but the drain must be executed by the seat that owns the channel, after the
watches are released. **Surfaced, not silently absorbed.**
`check-memory-corpus.sh` → **OK** (zero topic files, inbox within cadence).

## What Worked and What Didn't

**Worked — and the through-line is that each one was a refusal to believe something convenient:**

- **Refusing to fabricate a `github_accounts` row.** It would have unblocked the paywall-flip leg in
  thirty seconds and produced a green DoD for a journey no user ever took. Running the real link path
  instead surfaced that the whole chain works against the native DB and *re-proved Pass-1's stranded
  done-definition* as a side effect.
- **The schema diff that caught the two-Postgres mirage.** The container's numbers (1 linked account,
  102 repos, 0 subscriptions) looked *exactly* like the before-state I expected. I only caught it
  because a lookup failed against rows I could see, and I chased the contradiction instead of
  explaining it away. Confirmation would have been silent; the contradiction was the gift.
- **Positive-controlled probes.** A `grep -c 'error:'` on a green build returned 24 — it was matching
  `Underlying error:` inside build-tool noise. A positive control against a known-bad string proved
  the real pattern matched zero. A zero without a passing positive control is a broken probe.
- **Testing the portal crash on a throwaway port** rather than the principal's instance. The one thing
  I did right in that episode.
- **Tightening a guard that fired instead of deleting it.** The Playwright card-entry guard refused to
  type a card because it looked for "TEST MODE" and Stripe now renders "Sandbox". The convenient move
  was to drop the check. I added an *authoritative* one (`cs_test_` session id) alongside.

**Didn't — all mine:**

- **I relayed a subordinate's structural inference as a live hazard without reproducing it.** Lane B
  reasoned that `billing.portal.createSession` "is a separate Stripe client with its own generated
  router, so it would §A9-crash." Plausible, structurally argued, **untested**. I amplified it to the
  supervisor *and* to the principal, and sharpened it ("now reachable, highest-value next fix"). It
  took ninety seconds to refute. L1 amplified it upward too — two seats, one failure.
- **My lock-contention diagnosis was wrong.** Two gates at 0.0% CPU with zero `.build` writes: I
  concluded "starved behind another seat's build holding the shared SwiftPM lock." Nothing held
  `manifest.db`; the machine was idle; both gates completed on their own. A single sample of a moving
  system, read as a steady state.
- **I never relayed the one-gate-per-seat cap to an in-flight lane.** The cap landed at 18:03; lane B's
  brief was written at 17:47. It started two gates and did exactly what it was told. The violation was
  mine, not its.
- **Three lanes died to the 600s watchdog** while blocked on healthy builds. Backgrounding gates was
  necessary but not sufficient — the coordinator has to own the long gates.

## Patterns and Root Causes

**One pattern accounts for nearly every failure in this session, and — this is the part worth
keeping — it also accounts for the production bug I fixed.** The pattern is: **a snapshot was treated
as live state.** It appeared at four levels, and I did not notice the isomorphism until I wrote this.

1. **In my reasoning about data.** The container DB was a *snapshot* of 07-13 state. I read it as the
   app's live state because it was plausible and because nothing in the environment said otherwise.
2. **In my reasoning about processes.** `0.0% CPU` was a *sample*. I read it as a steady state
   ("blocked") rather than an instant in a moving system. The supervisor made the identical error in
   the same minute and had to retract it too.
3. **In the supervision protocol.** A lane brief is a *snapshot of the rules at briefing time*. A
   ruling issued after it does not exist for that lane. "I issued it" is not delivery. L1 codified
   the converse of [SUPER-061]: don't infer a seat is *current* from having briefed it, just as you
   can't infer it's *dark* from silence.
4. **In the code itself.** `Billing.Stripe.PriceMapping.Client.liveValue` captured state in a
   dependency scope that boiler **discards and re-creates on every request**. The boot-time mapping
   was a snapshot written into a scope that was gone before the first request arrived. **The bug is
   the same epistemic error, expressed in Swift.** A composition root re-applied per request means
   *every* boot-scope value is a snapshot, and any `liveValue` closing over mutable state silently
   loses it.

That fourth instance is the highest-value finding of the day, and it generalizes: **any
`Dependency.Key.liveValue` that closes over mutable state (an actor, a cache, a pool, an in-memory
registry) is broken under a per-request-reapplied root.** The price mapping is unlikely to be the only
one.

**Second pattern: bugs hide behind crashes, and fixing a crash does not reveal correctness — it
reveals the next layer.** The price-mapping bug was *unreachable* for as long as checkout SIGSEGV'd at
`customers.create`. Lane A's gate could not have caught it; the code path did not exist yet. This is
the same shape as the durable lesson already in CLAUDE.md — *"a build that aborts at the first missing
import proves nothing about the bodies."* Generalized: **a verification that stops at the first failure
proves nothing about what is behind it.** Every crash fix should be assumed to expose new, never-run
code, and gated accordingly — not treated as the last blocker.

**Third pattern: an over-broad crash predicate manufactures phantom hazards.** "It is a generated
router, therefore it §A9-crashes" is not the rule; the rule is "it has a `{id}` path component whose
parser closes over `Tagged<…, String>`." The coarse version already produced one false escalation, and
left in the catalog it would have had the September 6.4 sweep grepping for "generated routers" and
finding a hundred. The fix was to write the **discriminator** — what makes a router crash *versus not*
— with negative controls, not just positive ones. **A catalog entry with only positive instances is a
heuristic; with negative controls it is a predicate.**

**Meta-pattern on inheritance.** L1 filed a `[SUPER-*]` candidate at 17:50 on the supervisor side:
*before relaying a subordinate's finding, state what instrument produced it and whether that
instrument can distinguish the claim from its most likely false neighbour.* My portal escalation is
the **seat-side instance of the identical rule**, and it is the one I most need: I spent this arc
demanding primary-source verification of everything — and then forwarded an inherited inference
untested. **A finding I inherit is not more trustworthy than one I make; it is less, because I did not
watch it being made.** Probe-before-shape applies to what I *relay*, not only to what I *build*.

## Action Items

- [ ] **[skill]** supervise: extend the 17:50 `[SUPER-*]` evidence-class candidate to the SEAT side —
      before a seat relays a subordinate/lane finding upward (to L1 or the principal), it MUST state
      the instrument that produced the claim and reproduce it if the claim is load-bearing. An
      inherited finding gets the same probe as an authored one. Sibling of [SUPER-054]/[SUPER-058].
- [ ] **[package]** repotraffic-com-server: sweep every `Dependency.Key.liveValue` in the `*Live`
      modules for closures over mutable state (actors, caches, pools, in-memory registries) — under
      boiler's per-request-reapplied composition root (`Boiler.execute.swift:166-170`) each one
      silently loses its state, as `Billing.Stripe.PriceMapping` did (`2d0b002`).
- [ ] **[research]** Does respelling the generated Stripe routers' `{id}` path parsers off
      `.string.representing(...)`/`Parser.Conversion.RawValue` onto `.convert(apply:unapply:)` retire
      §A9 on 6.3.x? The app's Int-backed `GitHub.Repository.ID.pathParser` uses `.convert` and does
      not crash. If it holds for `Tagged<…, String>`, it fixes every Stripe endpoint rather than the
      two `Compat_Swift_6_3` covers — evaluate FIRST at the September 6.4 sweep.
