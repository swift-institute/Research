---
date: 2026-07-14
session_objective: As L2 general orchestrator, resolve the ecosystem-wide `\.request` dependency-key ambiguity (item 9) — probe the nested-key design, mint the `\.server`/`\.vapor` containers, and migrate the call sites.
packages:
  - swift-server
  - swift-server-foundation-vapor
  - boiler
  - swift-authentication
  - swift-nist-sp-800-63b
status: pending
---

# The `\.request` migration, and the six sites my probe could not see

## What Happened

**Objective**: two membranes vended an ambient request under the same name. `swift-server` vends
`Server.Request` as `\.request`; `swift-server-foundation-vapor` vends `Vapor.Request` as `\.request`.
Same spelling, different types. A module importing both would face two `Dependency.Values.request`
properties. The ruled fix: name the containers (`\.server.request`, `\.vapor.request`) and migrate the
call sites.

**P0 — probe before shape.** Built a throwaway package asserting, on *observed runtime values*, that
swift-dependencies keypath composition works through a nested container: read, `withDependencies`
override, scope non-leakage, whole-container read/write, inner-scope-wins nesting. 6/6 executed, green.

**P1 — the mint, and a deviation I fought for.** The supervisor ruled "two keys, additive: the flat
`\.request` STAYS." I minted the containers but made the flat key a **forwarding alias onto the same
storage slot** rather than an independent second key, and ledgered the deviation before touching a call
site. Reason: writers of this key live in repos I was forbidden to enter (the app's
`CookieSessionAuthenticator.swift:47`; four Identity Provider middleware overrides), and **both are
nested overrides**. With two independent keys, a nested `withDependencies { $0.request = X }` writes one
slot and leaves the container holding the **stale outer request** — so every site I migrated would read
the wrong request inside that scope, silently, while compiling. One slot makes that unrepresentable.
Ratified; the supervisor's own words: *"you caught a defect in my ruling that my ruling made structurally
invisible to you."* Proven by a four-case executed probe (write flat→read container; write container→read
flat; nested override on **either** spelling shadows **both**).

**P2 — call sites.** 9 Vapor-typed sites in `boiler` + `ssf-vapor`. Then, in a time-boxed exclusive
window between another arc's waves, 25 sites in `swift-authentication`.

**Shipped**: `swift-server` `1b3767f`, `swift-server-foundation-vapor` `7fd69ed` (public), `boiler`
`683a53d`, `swift-authentication` `76a27d6`. All pushed by the supervisor, `ahead=0`, trees clean. No
public surface removed (verified against the committed bytes: the only removed declaration anywhere is a
`private enum`).

**Also shipped**: `swift-nist/swift-nist-sp-800-63b` — NIST SP 800-63B-4 §3.1.1.2 password verifier,
Foundation-free core + Foundation Integration leaf, 19 tests green.

**Handoff scan** (per [REFL-009]): no loose root handoffs. `CHARTER-general-orchestrator-2026-07-14.md`
— retired to `handoffs/.trash/` by the supervisor at arc close (drain-per-arc, its owner's disposition,
not mine). `handoffs/HANDOFF.md` — dirty, another seat's file, **no-touch** per [REFL-009a].
`.handoffs/` WIP cap red (55 > 40) — the documented-by-design overage; the standing ruling is
drain-per-arc-at-close, never re-triage to force the number. Memory guard: **0 topic files** (target
zero), inbox within cadence.

## What Worked and What Didn't

**Worked — refusing to execute a partition that would have broken other seats.** The original spec was a
flag-day: remove both flat keys, migrate all 90 sites. 48 of those sites sat in two other arcs' live
repos. I refused, produced the inventory, and proposed a three-phase sequence. The alias then made even
that sequencing unnecessary — it bought *structurally* what the phasing was buying *procedurally*.

**Worked — probing before treating.** `boiler-example-database` died with `unable to read tree <sha>`,
which reads **exactly** like a corrupted SwiftPM cache. I was one command from purging the shared cache
(which other seats were building against). I checked first: the cached bare repos were healthy clones of
the URLs they were told to clone. The real defect was a **package-identity collision** — the example pins
`pointfreeco/swift-dependencies`, which has no mirrors.json entry, while the graph also carries the
mirrored institute fork; same identity, two URLs, so SwiftPM resolved pointfree's URL but carried the
fork's pin and tried to check out the fork's SHA *inside pointfree's clone*. Purging would have fixed
nothing and hit other seats. **The false neighbour was more plausible than the truth.**

**Worked — killing a false green.** `boiler`'s `Examples/` are **separate SwiftPM packages**; the root
manifest doesn't reference them. A root-only `swift test` would have reported GREEN while verifying
**6 of 9 migrated call sites with nothing**. Caught before claiming P2 closed.

**Didn't work — my probe found 19 of 25 sites.** The supervisor's order said "the 25 sites." My grep
found 19. The six invisible ones were `@Dependency(\.request?.realIP)` — the request read **through an
optional keypath**, which `@Dependency(\.request)` structurally cannot match. Had the order said "migrate
the sites," I would have migrated 19, gated them green, reported complete, and left six live reads on a
key scheduled for deletion. **A half-migration that compiles.** The only detector was the disagreement
between two counts — and it only worked because I went and looked instead of assuming the supervisor had
miscounted.

**Didn't work — four gate attempts against the wrong package.** I re-ran a gate four times without a `cd`,
so each ran against the previously-cd'd package while I believed it was gating another. Every one was
killed before reporting, so no false green entered the record — but it would have, and a log titled
"ssf-vapor" that gated `swift-server` is precisely the lying instrument the workspace rules exist to
prevent.

**Didn't work — I read my own truncation as a zero.** Auditing whether the supervisor had written a
BACKLOG row it claimed to have written, I grepped, piped through `head -8`, and the output was cut off
*before* reaching the line. I concluded the row was absent and was one step from filing a duplicate and
an accusation. The row was at line 150.

**Didn't work — my T6 diagnosis earlier in the day.** I reported that `.dependency(\.context, .test)`
"compiles and then fatals at runtime." Both halves false: `\.context` doesn't exist in the institute fork
(so it never compiled), and the "runtime fatal" was SwiftPM's **build-failure** line, `error: fatalError`,
because `swift build` does not build test targets. Retracted; the supervisor withdrew its endorsement and
corrected the principal.

## Patterns and Root Causes

**The defects were real and small. The day went to errors of measurement.** Nearly every failure above is
the same shape: *a probe whose reach was narrower than the claim I made from it*, producing a zero
indistinguishable from a real zero.

- `@Dependency(\.request)` → cannot see `\.request?.realIP`. **An anchored pattern is a claim about FORM,
  and form varies.**
- `head -8` → cannot see line 150. **A truncated pipe returns a zero indistinguishable from a real one.**
- `swift build` → cannot see test targets. **"It compiles" is not a claim you have tested.**
- boiler root gate → cannot see `Examples/`. **A gate that reaches less than it claims is a lying
  instrument.**
- `git -C <wrong-path>` (earlier) → errors, and empty output reads as clean.
- the cwd-less gate → measures a package it was never pointed at.

This is exactly [REFL-011]'s tool-reach extension, and it fired **six times in one session** despite the
rule existing. The rule is right; recall is not the mechanism. **Reach-alignment has to live in the
instrument, not in the operator's memory.** The two mitigations that actually worked were both
*structural*: (a) I moved gating into a script that takes the package as an **argument**, stamps
`GATED PACKAGE:` as line 1 of the log, and exits non-zero if it ever reports exit 0 over a log containing
`error:` lines — after that, the cwd class could not recur; (b) the **count disagreement** with the
supervisor, which is a cross-check by an independent instrument.

**The single most valuable thing in the session was a number I did not compute.** "25" came from the
supervisor. My probe said 19. Two independent measurements disagreeing is the only reason the optional-
keypath sites were found. This generalizes: for a convert-all-X task, **the completeness check must come
from a different instrument than the one that enumerated the work** — [REFL-006]'s re-verify-after-edit
re-runs *the same* detection pass, which would have re-confirmed 19 and called it done. Re-running a
blind probe does not cure its blindness.

**The alias is the design lesson.** Two independent keys would have made a wrong state *representable*
and forbidden it by convention — "every writer must set both," including writers in repos I cannot enter.
One storage slot makes the wrong state **unrepresentable**. The cost of the two-key design would have
been paid by whoever debugged a request that was silently the wrong request, in a scope they didn't own.
That is the institute's own doctrine ([API-NAME-001] nests vocabulary so a collision *cannot* occur
rather than being merely *detectable*) applied to dependency storage instead of names. Same move, different
axis.

**A population, not three coincidences.** `DependenciesMacros` (boiler example-server), the
`pointfreeco/swift-dependencies` identity collision (example-database), and `.incrementing` in
`swift-authentication`'s tests are three exhibits of one disease: **test targets and example packages
across the tower are stale pointfree-era consumers that no gate has looked at in months.** That is the
CI-health census's abstraction made concrete. They are invisible precisely because they are the targets
nothing gates — which is why all three surfaced only when something *else* forced a build of them.

## Action Items

- [ ] **[skill]** audit: extend [AUDIT-036] (gate-grep width-check) with the *independent-instrument*
      corollary — for a convert-all-X task, the completeness check MUST come from a different instrument
      than the one that enumerated the work (re-running a blind probe re-confirms its blindness). Cite the
      optional-keypath incident: `@Dependency(\.request)` found 19 of 25; the six invisible sites were
      `\.request?.realIP`, and only a *count disagreement with an independent source* detected them.
- [ ] **[skill]** testing-institute: `@Suite(.dependencies)` requires a SECOND product dependency —
      the trait ships in `Dependencies Test Support` (module `Dependencies_Test_Support`), NOT in the
      `Dependencies` library. Omitting it fails at `emit-module` and presents as a bare
      `error: fatalError`, which reads exactly like a runtime trap and is not one.
- [ ] **[skill]** swift-package-build: `unable to read tree <sha>` at resolve is a PACKAGE-IDENTITY
      COLLISION (an unmirrored upstream URL colliding on identity with a mirrored fork — SwiftPM resolves
      one URL and carries the other's pin), **not** cache corruption. Do NOT purge the shared SwiftPM
      cache; fix the manifest's URL. Verify by checking whether the cached bare repo is a healthy clone of
      the URL it was told to clone.
