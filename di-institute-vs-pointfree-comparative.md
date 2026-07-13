# Comparative analysis: the institute DI idiom vs Point-Free's swift-dependencies

**Status**: analysis, 2026-07-13; amended same day after the independent blind assessment
(`di-comparative-fable-assessment.md`) — its R2/R3/R4/R4b/R5/R6 corrections are incorporated at
their sections, and the two verdicts CONVERGED blind. Written for the principal's own question — *"is our approach
actually better?"* — while the institute idiom (`di-composition-root-design.md`, RATIFIED
2026-07-13) was being executed in the E-2 arc.
**Verdict in one line**: **the two designs are not competing implementations of the same idea —
they resolve dependencies by opposite mechanisms, and each is correct for its own constraint set.
Ours is better for the institute's constraints and would be worse for a typical app team.**
Both claims below are verified at primary source, not recalled.

---

## 0. The single fact everything follows from

Point-Free's resolver finds the live implementation **at runtime, by casting the key's metatype**
(`Sources/Dependencies/DependencyValues.swift`, upstream `main`):

```swift
value = (key as? any DependencyKey.Type)?.liveValue as? Key.Value
```

The institute's resolver finds it **at compile time, by static overload resolution** — two
subscript overloads, one constrained to `Witness.Key` (has `liveValue`), one to
`Witness.Key.Test` (test-only); which overload binds is decided **in the accessor's own module,
at its own compile time** (`Witness.Values.value(for:mode:)`).

Everything else — the composition root, the boundary re-application, the tripwire, the
co-location rule — is downstream of that one difference.

**Consequence.** A runtime metatype cast is *context-free*: code running in a severed task (a
queue worker, a scheduled job, a detached `Task`) still resolves the live value, because the value
is reachable *from the key itself*, not from the surrounding scope. Static resolution is not
context-free: the live value must be **carried into** the context. That is precisely why the
institute needs a composition root re-applied at every execution boundary, and Point-Free does
not.

---

## 1. What each design actually is

| | **Point-Free swift-dependencies** | **Institute (swift-witnesses / swift-dependencies)** |
|---|---|---|
| Live value lives on… | the **key** (`static var liveValue`) | the **app's composition root** (keys need no liveValue at all) |
| Resolution | runtime metatype cast → `liveValue` | static overload resolution → registered value or key default |
| Production graph is… | **implicit** — scattered across every module's `liveValue` | **explicit** — one closure, readable in one file |
| Severed boundaries (jobs/workers) | a non-issue (context-free resolution) | must have the root **re-applied**; boiler owns that list |
| Test-default-served-in-live | diagnosed in DEBUG only; **silent in RELEASE** (see §2) | named report in RELEASE, trap in DEBUG (W1.3 tripwire, 2026-07-13) |
| Runtime requirements | existential + metatype casts, a global cache | none — no runtime metadata needed |
| Interface/Live module split | interface declares `TestDependencyKey`; Live module adds a **retroactive** `DependencyKey` (liveValue), found by the runtime cast | interface declares the key; **nothing** declares liveValue; the app root supplies the value |

The institute implementation is **not a fork** of Point-Free's — it is an independent clean-room
implementation (57 commits from "Initial implementation of swift-dependencies"). The API rhymes;
the machinery does not.

---

## 2. The uncomfortable finding, stated plainly

Two properties the institute spent 2026-07-13 building have upstream antecedents — but the
independent assessment (`di-comparative-fable-assessment.md`, R2/R3) corrected this section's
first framing, and the corrected reading follows:

1. **The test-default diagnostic exists upstream — in DEBUG only.** Upstream reports:
   > `@Dependency(…) has no live implementation, but was accessed from a live context.`
   …but that reporting is debug-configuration-only; **upstream's RELEASE behavior is the silent
   masquerade itself** (the test default is served with no report). The institute's W1.3 tripwire
   reports-once-per-key *in release* (and traps in debug). So the honest framing is not "parity
   restored" (this document's first draft) — the release-mode loudness is a **genuine advance**
   over upstream, and it is exactly the configuration where production runs.

2. **Immunity to the compile-time split-conformance class.** The institute's boot SIGSEGV
   (`\.mainEventLoopGroup`), the `\.router` boot fatal, and the `\.logger` silent channel are all
   instances of *one* class: an accessor compiled where it cannot see the key's widest conformance.
   Upstream's runtime cast **cannot have this compile-time class** — it finds the liveValue wherever
   it was declared, including retroactively in a downstream Live module. (It has its own *runtime*
   failure analogues; the immunity is to this specific static-binding class.) The institute needs a
   co-location rule (§4.3 rule 2) plus a lint to hold the line.

3. **A deficit this analysis missed entirely** (found by the independent assessment, R4): the
   **get-modify-set accessor incoherence** — `$0.key = x` followed by `$0.key.property = y` inside
   one prepare-closure does not do what it reads like: the *get* misses the pending storage and
   resolves the key, so the mutation lands on a discarded default. This is a design-level deficit of
   the institute's resolution pipeline (upstream's getter consults in-flight storage first), it
   produced a real production bug (boiler's env-driven log level never worked), and its structural
   fix — pending-storage-first getters — is item 1 of the ratified follow-up agenda (§6).

An honest reading: **the institute's static-resolution choice bought a class of silent failure
that upstream does not have, and today's arc paid the bill.** Any defence of the institute idiom
must be worth that price. The rest of this document argues that it is — but the price is real and
should not be narrated away.

---

## 3. Where the institute design is genuinely better

**(a) The production graph is auditable.** With `liveValue` on the key, there is no place in a
Point-Free app where you can *read* what the app runs in production; the graph is the union of
every `liveValue` in every module, resolved by casts. In the institute idiom the whole graph is
one closure:

```swift
try await Boiler.execute(dependencies: { deps in
    deps.defaultDatabase = database
    deps.cache           = cache
    deps.logger          = logger
    deps.account         = .liveValue
    …
})
```

For infrastructure meant to be *timeless* and reviewable, "you can read the graph" is not a
nicety. It is the difference between a system you can audit and one you must archaeologise.

**(b) Interface/Live purity is structural, not conventional.** Point-Free's own recommended layout
(TestDependencyKey in the interface, retroactive DependencyKey in the Live module) exists to stop
interfaces depending on implementations — but the mechanism that makes it work is a *runtime cast*.
The institute idiom does not need the trick: in the pure §4.5 form, **no key names a live
implementation**; the app — the one place that legitimately knows every implementation — supplies
them. (Precision, per the assessment's R6: what actually LANDED is a deliberate hybrid — keys with a
sensible library-owned default are full `Dependency.Key`s co-located with their accessor (the ELG,
`\.logger`, `\.analytics`), and the root registers the app-decided rest. The hybrid is the right
design; the pure form describes the app-decided half, not the whole.) This remains the cleaner
answer to the very problem Point-Free's retroactive conformance is working around.

**(c) It is Embedded-viable — and the upstream mechanism is not. VERIFIED EMPIRICALLY, not assumed.**

The principal correctly challenged this claim ("Embedded has changed a lot lately — check"). It was
tested against the **6.3.3 release toolchain** (`swiftc -enable-experimental-feature Embedded -wmo
-Osize`) with a minimal reproduction of exactly the upstream resolution step:

```swift
protocol TestKey { static var testValue: Int { get } }
protocol LiveKey: TestKey { static var liveValue: Int { get } }
struct HasLive: LiveKey { static var testValue: Int { 1 }; static var liveValue: Int { 42 } }

func resolve(_ key: any TestKey.Type) -> Int {
    if let live = key as? any LiveKey.Type { return live.liveValue }  // the Point-Free step
    return key.testValue
}
resolve(HasLive.self)
```

**Normal Swift**: compiles, runs, prints `42` (the live value is found).
**Embedded Swift, same file, same compiler**:

```
warning: cannot perform a dynamic cast to a type involving protocol 'LiveKey'
         in Embedded Swift  [#EmbeddedRestrictions]
error:   cannot use metatype of type 'HasLive' in embedded Swift
         [#EmbeddedRestrictions]
```

Two independent blocks, and the finding is **stronger than "unsupported"**:

1. The **cast is diagnosed as un-performable** (warning) — it does not trap, it is *inert*. Had the
   metatype reached it, the live value would simply never be found and **every key would silently
   serve its testValue** — the exact silent-masquerade class that cost us a debug round today,
   promoted to a whole-program default.
2. Forming the concrete metatype at the call site is a **hard error** — so in practice the mechanism
   cannot even be reached.

Recent Embedded relaxations are real (existential *parameter* types like `any TestKey.Type` now
compile) but they **do not extend to metatype-based dynamic casts**, which is precisely the step
upstream depends on. Static overload resolution costs nothing at runtime and is unaffected.

**This forecloses the upstream mechanism for the institute's stated Embedded ambitions.** It is the
strongest single argument in the institute's favour, it is not a matter of taste, and it is now
evidence rather than assertion — double-verified: the independent assessment ran its own blind
probe (different probe shape, same toolchain family) and reproduced the foreclosure (R4b).
Two precision corrections from that adjudication, accepted: (1) the forcing chain has a middle
step — Embedded forecloses *runtime liveValue discovery*; the composition ROOT is forced by the
conjunction Embedded + the Interface/Live split + no global registration ([API-IMPL-010]) —
static resolution with liveValue ON the key is Embedded-viable, it just violates the split;
(2) the defence never rested on this leg alone — upstream's untyped rethrows ([API-ERR-001]),
Foundation/ObjC-runtime machinery in its resolver init path, and its process-global mutable cache
each independently block adoption.

**(d) Resource lifecycle has an owner.** "Process-scoped resources are constructed once in the
root and resolved — never constructed — at boundaries" (§4.4) is a rule the composition root makes
*expressible*. Upstream's equivalent is a `static let` inside a `liveValue` — a lazy global with no
declared owner and no lifecycle. The 13:00 Redis connection storm was exactly a per-operation
construction; the root makes that shape unwritable.

**(e) The boundary list has an owner.** Once boiler enumerates and re-applies at every boundary it
opens, **no app author can forget one** — they no longer wire anything. The failure mode that
killed the server at noon becomes structurally unavailable to every future app, not just this one.

---

## 4. Where Point-Free's design is genuinely better

**(a) Robustness to boundaries nobody enumerated.** Context-free resolution means a `Task {}` in a
third-party library, a future Vapor feature, a new queue driver — all just work. The institute
idiom is only as complete as boiler's boundary table (§2 of the design doc). Today that table is
verified (14 rows, two independent sweeps). It is a *maintained artifact*, and maintained artifacts
drift. The mitigation is the tripwire: an un-rooted boundary now fails loudly and names the key —
but it still fails.

**(b) Less ceremony.** No root to thread, no `Boiler.Job` protocol to adopt, no co-location rule to
obey. For an app team optimising time-to-feature over auditability, upstream is plainly the better
tool, and it would be dishonest to pretend otherwise.

**(c) Maturity.** Battle-tested, documented, widely used; its failure modes are known and written
down. The institute idiom is one day old and has exactly one consumer.

---

## 5. The honesty ledger (claims that do not survive scrutiny)

- **"We have no global state."** Not quite. `Boiler.Root` is a process-wide, set-once slot holding
  the composition closure. The design doc defends it as *boot configuration, morally equivalent to
  `@main`'s argv* — a fair distinction (it is write-once, never mutated, and holds no resolution
  state) — but "no globals" is the wrong flag to plant. The accurate claim is: **the resolution
  store stays task-local; the boot configuration is a set-once global.** Upstream also keeps a
  global cache, so on this axis the two are closer than the rhetoric suggests.
- **"The tripwire is a novel safety feature."** This draft first called it a re-derivation of an
  upstream diagnostic and framed it as *parity restored*. The independent assessment corrected
  that (R2, accepted): upstream's diagnostic is **debug-only** and its release behavior is the
  silent masquerade itself — so the institute's release-mode report-once is a genuine advance,
  not parity. The corrected §2 above is authoritative.
- **This analysis missed the get-modify-set incoherence** as a design-level deficit (§2 item 3,
  added post-assessment). An honesty ledger that itself needed a correction pass is the strongest
  argument for the two-seat blind protocol that produced it.

---

## 6. The open design question this analysis surfaces (NOT for mid-arc action)

`Boiler.Root` is already a process-global holding the materialised composition root. If the
**resolver** consulted it as the last fallback (task-local override → prepared → **root** → key
default), then:

- boundary enumeration would stop being load-bearing — B6/B7/B8 and every *unknown future*
  boundary would resolve correctly with no re-application at all;
- the explicit, auditable composition root — the institute's best property — would be **kept**;
- test isolation would be unaffected (tests never call `Boiler.execute`, so the slot is never set;
  `withDependencies` overrides still win at the innermost scope);
- Embedded-viability would be preserved (a global read, not a metatype cast).

This is, in effect, Point-Free's context-free resolution **without** the runtime cast, and with the
institute's explicit root retained. The ratified design rejected "global registration store" on the
grounds that it *"falsifies [API-IMPL-010]'s operation-scoped design [and] breaks test isolation
(parallel suites shadowing one global)"* — but that objection was aimed at a **mutable global
dictionary**, not at a **set-once boot slot consulted below every task-local scope**, which is what
`Boiler.Root` already is. The objection may therefore not bite against this narrower shape.

**Recommendation: do not touch this now.** The ratified design is landing, it works, and its arc is
one gate from closing. But this is the sharpest available refinement, it would delete the design's
one genuine fragility (boundary-list drift), and it belongs on the table the next time the DI idiom
is opened — most naturally alongside the de-Vapor / de-NIO arc, where boiler's boundary set is
being rewritten anyway.

**STATUS UPDATE (2026-07-13, post-assessment): RATIFIED AS AGENDA (principal YES).** The
independent assessment (R5) adjudicated this refinement **sound in essence, unsound as literally
sketched here**, with three amendments that are now part of the agenda item: (1) the root arm is
consulted **in `.live` mode only** (as sketched it would outrank mode defaults and invert
test/preview semantics in any post-boot test scope — a real hole); (2) the slot must live in the
**witnesses layer** (`Witness.Root`), not boiler — the resolver cannot depend upward; boiler
*sets* it; (3) the slot holds **materialized `Witness.Values`**, not the app's closure, and the
prepared-vs-root precedence must be decided explicitly. Alongside it, agenda item 1: the
pending-storage-first getter fix for the get-modify-set class (§2 item 3). Also priced there:
per-boundary values (`\.request`) keep their seams — the refinement deletes the *fragility*, not
the seams — and `Synchronization.Mutex` is unavailable under Embedded, so the slot's guard needs
an Embedded-conditioned primitive. Both items ride the next DI design round, dispatched by the
principal ([SUPER-057]).

---

## 7. Bottom line for the principal

**Is ours better? For the institute: yes — and for one reason that is not a matter of taste.**
Upstream's mechanism is a runtime metatype cast, which Embedded Swift cannot do. If the institute
means what it says about Embedded and about zero-runtime-metadata infrastructure, the upstream
design is simply unavailable, and something in the shape of the composition root is *forced*, not
chosen. Everything else — the auditable graph, the clean Interface/Live split, the owned resource
lifecycle — is genuine additional upside on top of a forced move.

**Would ours be better for a typical app team? No.** More ceremony, a maintained boundary list, and
a class of silent failure (split conformance) that upstream is immune to by construction. That we
had to build a tripwire today to catch what upstream already caught is the honest evidence.

**What would make ours unambiguously better:** close the one fragility (§6) so that a missed
boundary is impossible rather than merely loud. Until then, the tripwire is what stands between us
and the next noon fatal — which is an argument for keeping it strict, not for relaxing it.
