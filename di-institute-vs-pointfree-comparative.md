# Comparative analysis: the institute DI idiom vs Point-Free's swift-dependencies

**Status**: analysis, 2026-07-13. Written for the principal's own question — *"is our approach
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
| Test-default-served-in-live | **already diagnosed upstream** (see §2) | diagnosed as of 2026-07-13 (W1.3 tripwire) |
| Runtime requirements | existential + metatype casts, a global cache | none — no runtime metadata needed |
| Interface/Live module split | interface declares `TestDependencyKey`; Live module adds a **retroactive** `DependencyKey` (liveValue), found by the runtime cast | interface declares the key; **nothing** declares liveValue; the app root supplies the value |

The institute implementation is **not a fork** of Point-Free's — it is an independent clean-room
implementation (57 commits from "Initial implementation of swift-dependencies"). The API rhymes;
the machinery does not.

---

## 2. The uncomfortable finding, stated plainly

Two properties the institute spent 2026-07-13 building **already exist upstream**:

1. **The loud test-default diagnostic.** Upstream reports:
   > `@Dependency(…) has no live implementation, but was accessed from a live context.`
   …and tells you to conform the key to `DependencyKey` or override with `withDependencies`.
   That is, message-for-message, what the W1.3 tripwire now emits. We re-derived it.

2. **Immunity to the split-conformance bug.** The institute's boot SIGSEGV (`\.mainEventLoopGroup`),
   the `\.router` boot fatal, and the `\.logger` silent channel are all instances of *one* class:
   an accessor compiled where it cannot see the key's widest conformance. Upstream's runtime cast
   **cannot have this bug** — it finds the liveValue wherever it was declared, including
   retroactively in a downstream Live module. The institute needs a co-location rule (§4.3 rule 2)
   plus a lint to hold the line.

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
The institute idiom does not need the trick at all: **no key ever names a live implementation**;
the app — the one place that legitimately knows every implementation — supplies them. This is the
cleaner answer to the very problem Point-Free's retroactive conformance is working around.

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
evidence rather than assertion.

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
- **"The tripwire is a novel safety feature."** It is a re-derivation of an upstream diagnostic.
  Its institute-specific value is real (it covers the split-conformance class, which upstream
  cannot have and therefore never needed to diagnose) — but the framing should be *parity
  restored*, not *ground broken*.

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
