# DI Comparative: Independent Fable Assessment (institute idiom vs Point-Free swift-dependencies)

<!--
---
version: 1.0.0
last_updated: 2026-07-13
status: RECOMMENDATION
---
-->

> **Provenance & protocol**: Second, independent assessment ordered by the principal
> (`CHARTER-di-comparative-fable-assessment-2026-07-13.md`). Phase 1 was written BLIND:
> the prior Opus analysis (`di-institute-vs-pointfree-comparative.md`) was not opened,
> and `Research/` was not grepped, before this verdict was stamped. Every load-bearing
> claim cites primary source read TODAY: institute files at current local HEADs;
> upstream `pointfreeco/swift-dependencies` fetched from GitHub `main` (2026-07-13);
> upstream is read for analysis only, never consumed as a dependency. A RECONCILIATION
> section (Phase 2) follows the blind verdict.

## Context

The institute ratified a DI composition-root idiom on 2026-07-13
(`DECISIONS-pass2/di-composition-root-design.md`): one app-authored closure passed to
`Boiler.execute(dependencies:)`, re-applied by boiler at every execution boundary it
opens; a loud tripwire when a test default resolves in a live context; witness test
defaults authored `unimplemented()`; process-scoped resources constructed in the root.
The E-2 execution arc landed it today. The principal asks:

## Question

*"Is our approach better than pointfreeco's approach? I'm kind of in the middle."*

## The mechanism-level difference (one sentence)

**Upstream discovers `liveValue` at RUNTIME — a metatype existential cast
(`(key as? any DependencyKey.Type)?.liveValue as? Key.Value`,
`DependencyValues.swift:589`) against a process-global, lock-guarded default cache
(`CachedValues`, `:472-626`) — while the institute discovers it at COMPILE TIME via
generic overload resolution onto static protocol requirements
(`Witness.Values.swift:140-149`) over strictly task-local state; every observable
difference between the two designs — severance behavior, split-conformance behavior,
Embedded viability, diagnostic loudness — is a shadow of that one choice.**

## Analysis

### A. The two resolution pipelines, at source

**Upstream** (`pointfreeco/swift-dependencies@main`, fetched 2026-07-13):

1. Storage lookup on the value copy: `self.storage[ObjectIdentifier(key)]` with an
   existential downcast `base as? Key.Value` (`DependencyValues.swift:242`).
2. Miss → the process-global cache: `cached[cacheKey]?.base` + downcast (`:584`),
   keyed by (type, context, current-test-ID) (`:475-489`), guarded by an
   `NSRecursiveLock` (`:497`).
3. Cache miss in `.live` context → **runtime metatype cast**:
   `value = (key as? any DependencyKey.Type)?.liveValue as? Key.Value` (`:589`).
   The subscript is generic over the BASE protocol (`TestDependencyKey`); whether a
   live implementation exists is discovered by dynamic cast at the moment of first
   resolution. Whatever module declared the `DependencyKey` conformance wins —
   provided it is **linked** (upstream's own diagnostic: "make sure that the
   conformance is linked with this current application", `:568-569`).
4. Cast fails (test-only key in live context): DEBUG-only `reportIssue`
   (`#if DEBUG`, `:520-582`); then — in every configuration —
   `let cacheableValue = value ?? Key.testValue` (`:615`): **in RELEASE the test
   default is served silently and cached**.
5. `prepareDependencies` writes into the same process-global cache with a
   once-per-process discipline (`preparationID` gating, `:298-371`; "A dependency
   key can only be prepared a single time", `WithDependencies.swift:46-48`).
6. Context (`live`/`preview`/`test`) is inferred at process level from
   `ProcessInfo.processInfo.environment` + `isTesting` (`DependencyValues.swift:436-469`);
   per-test cache isolation hooks into XCTest via ObjC runtime
   (`objc_getProtocol`/`class_addMethod`/`imp_implementationWithBlock`, `:142-167`)
   or `dlopen`/`dlsym`/`unsafeBitCast` on Linux/Windows (`:177-197`).

**Institute** (local HEADs, 2026-07-13):

1. One `@TaskLocal` for everything: `Dependency.Scope._current`
   (`Dependency.Scope.swift:67-68`); `Witness.Context` rides it under an internal
   key (`Witness.Context.swift:81-87, 214-225`) — values, mode, and the prepared
   store are all task-tree-scoped.
2. Resolution order: explicit override (COW pointer-boxed storage,
   `Witness.Values.swift:127-132`) → prepared store (`:135-137`; the store itself is
   `@TaskLocal`, `Witness.Preparation.swift:52-53`) → **static mode-based default**:
   `switch mode { case .live: return K.liveValue ... }` (`:140-149`). No casts;
   the compiler monomorphizes per key.
3. Test-only keys (`Witness.Key.Test`) have a SEPARATE generic overload; its `.live`
   arm is the tripwire: `Witness.Diagnostics.testDefaultServedInLive(K.self)` then
   serves `testValue` (`Witness.Values.swift:180-195`). The diagnostic **traps in
   DEBUG, reports once per key to stderr in RELEASE, and traps in release under
   `DEPENDENCIES_STRICT=1`** (`Witness.Diagnostics.swift:44-66`).
4. Which overload a `Dependency.Values` accessor binds to is decided by **overload
   resolution at the accessor's compile time** — the module that declares the
   accessor sees whatever conformances are visible to IT
   (`Dependency.Values.swift:59-82`).
5. Typed throws are preserved through every scope
   (`withDependencies<T, E: Error> ... throws(E)`, `withDependencies.swift:65-68`;
   `Dependency.Scope.swift:97-117` Result-wraps around the stdlib's rethrowing
   `TaskLocal.withValue`).
6. Mode is explicit scope state (default `.live`), not process-inferred
   (`Witness.Context._ContextKey`, `Witness.Context.swift:89-97`).

### B. What upstream's choice buys it (where theirs is genuinely better)

1. **No severance class.** Prepared values and cached live defaults live in a
   process-global reference (`public var cachedValues = CachedValues()` — a final
   class shared by every `DependencyValues` copy, `DependencyValues.swift:133`).
   A queue worker, a detached task, a NIO responder task — none of them can "lose"
   the prepared graph, because the graph isn't task-local. The institute's I1 class
   (the 12:00 scheduled poll resolving Records' unconfigured `\.defaultDatabase` →
   `fatalError` → dead serve process; STAB ledger 12:05:20) is structurally
   impossible upstream for prepared keys. The entire §2 boundary-enumeration table,
   `Boiler.Root`, and the `Boiler.Job`/`Boiler.ScheduledJob` re-application
   protocols (`Boiler.Job.swift:26-32`, `Boiler.ScheduledJob.swift:24-30`) exist to
   compensate for what upstream gets from one global cache.
2. **No accessor-binding split-conformance class.** Upstream's liveValue discovery
   is runtime: an interface module conforms to `TestDependencyKey`, a Live module
   retroactively upgrades to `DependencyKey`, and the cast finds it as long as the
   module is linked. The institute's compile-time binding produced four incidents
   of one family in a single day: `\.mainEventLoopGroup` (Test-only
   `EmbeddedEventLoop` default → boot SIGSEGV; design doc §1 I2),
   `\.accountGitHub` (interface-module default's `connect` unconditionally throwing
   `invalidToken`, masquerading as domain behavior; BOOT ledger 10:23:27),
   `\.favicon` (liveValue in an executable unreachable through the accessor —
   trapped at marketing's first request; E-2 ledger 18:05:46/18:09:58), and
   `\.envVars` (the app's `.env`-loading retroactive conformance was **dead code
   all along** — ssf's accessor had already bound; E-2 ledger 18:09:58).
3. **Get-modify-set coherence.** Upstream's subscript getter reads the value copy's
   own storage FIRST (`self.storage[ObjectIdentifier(key)]`,
   `DependencyValues.swift:242`), so `$0.x = v; $0.x.y = w` inside a modify closure
   behaves like normal value semantics. The institute's accessors read the STATIC
   task-local context (`get { Witness.Context[key] }`,
   `Dependency.Values.swift:60,79`) — a GET inside the modify closure does NOT see
   the preceding SET on the same `$0`. This is not theoretical: boiler's
   envVars-driven log level had **never** been applied (`$0.logger.logLevel = …`
   modified a discarded test default; E-2 ledger 17:05:31 finding 2, fixed
   `907cf36`), and the app root carries two defensive comments steering authors
   away from reads of `$0` (`Application.swift` favicon + logger notes). Upstream
   does not have this footgun.
4. **Maturity surface.** Battle-tested across a large ecosystem; preview-context
   inference; per-test cache isolation integrated with both XCTest and
   swift-testing; class-model-scoped dependency propagation
   (`WithDependencies.swift:256-441`). The institute stack is a young clean-room
   with a same-day defect discovery rate that reflects it.

### C. What the institute's choice buys it (where ours is genuinely better)

1. **The tripwire is loud where upstream is silent — and it has a same-day catch
   tally.** Upstream's live-context diagnostic is compiled out of RELEASE
   (`#if DEBUG`, `DependencyValues.swift:520-582`), after which `value ??
   Key.testValue` (`:615`) serves the test default silently, forever. The
   institute traps in DEBUG, reports-once in RELEASE, traps under
   `DEPENDENCIES_STRICT=1` (`Witness.Diagnostics.swift:53-64`). Empirically, on its
   FIRST live boots it caught: the `\.logger` silent channel (a Test-only key with
   no live half anywhere; its testValue was a *working* logger with the wrong
   label/level — the perfect masquerade; E-2 17:05:31), boiler's get-modify-set
   bug (surfaced by the same trap), and `\.favicon` at marketing's first request
   (E-2 18:05:46). Under upstream semantics all three would have shipped silent.
   The logger label/level had been wrong for the program's entire history —
   upstream-style silence is exactly how it stayed wrong.
2. **Embedded viability — probe-verified today, not assumed.** A minimal
   reproduction of upstream's mechanism (metatype cast + existential storage +
   downcast-on-read) fails to compile under
   `swiftc -enable-experimental-feature Embedded -wmo` (6.4-dev
   `org.swift.64202605271a`): warning `cannot perform a dynamic cast to a type
   involving protocol 'LiveKey' in Embedded Swift` + hard error `cannot do dynamic
   casting in embedded Swift [#EmbeddedRestrictions]`, both on the liveValue-discovery
   line; the same file compiles and runs under normal swiftc (probe A,
   scratchpad `embedded-probe/upstream-mechanism.swift`). The institute-shaped
   probe (static generic dispatch) compiles and runs clean under Embedded (probe
   B). Beyond the cast, upstream's `DependencyValues.init()` is ObjC-runtime and
   `dlopen`-dependent (`:142-198`) and its context inference requires Foundation
   `ProcessInfo` (`:437`) — the mechanism is unavailable in Embedded several times
   over. The institute pipeline (TaskLocal + static generics + `Mutex` +
   `Unmanaged`) has no such dependence.
3. **Typed throws end-to-end.** `withDependencies`/`Witness.Context.with`/`Dependency.Scope.with`
   all preserve `throws(E)` (institute `withDependencies.swift:65-68`;
   `Dependency.Scope.swift:97-117`). Upstream is untyped `rethrows` throughout
   (`WithDependencies.swift:122-125`). For an ecosystem with [API-ERR-001] typed
   throws as law, upstream's shape is not adoptable as-is.
4. **No global mutable resolution state; test isolation is structural.** Upstream's
   correctness under parallel tests depends on runtime test-context detection
   (test-ID-keyed cache entries, `DependencyValues.swift:475-489`) plus XCTest
   observer machinery installed via ObjC/dlopen from a value type's `init`; its
   `prepareDependencies` is once-per-process and documented incompatible with
   repeated/parameterized tests (`WithDependencies.swift:72-76`). The institute's
   isolation is the task tree itself: scopes nest, prepared stores nest, parallel
   suites cannot observe each other by construction ([API-IMPL-010]). The one
   process-global the institute design does add — `Boiler.Root` — holds the boot
   *closure*, not resolution state, is set-once with a trap
   (`Boiler.Root.swift:35-48`), and tests never call `Boiler.execute`.
5. **Composition auditability.** There is exactly one place where the live graph is
   defined (the root closure, `Application.swift`), and §5's grep gate — zero
   `withDependencies` in app code outside the root and sanctioned inner scopes —
   held at the E-2 gate (E-2 ledger 16:55:36, GATE-1 clean). Upstream's
   morally-equivalent state (which keys resolve to what, in which context) is
   distributed across conformance sites, link decisions, cache warm-up order, and
   environment variables; it is not greppable.
6. **Performance shape** (secondary, source-verified only as shape, not measured):
   upstream takes a process-wide recursive lock on every default resolution
   (`CachedValues.value`, `:515-516`) and boxes into existentials; the institute's
   store is COW + 8-byte raw-pointer entries (`Witness.Values.swift:78-96`) with
   no lock on the resolution path (the only Mutex sits in the prepared store,
   consulted on storage miss; `Witness.Preparation.Store.swift:48-56`).

### D. Honest costs (both sides)

**Institute — real, production-demonstrated:**

1. **The boundary tax does not close; it relocates.** Every severed boundary must
   be found and wired — the design's §2 table is empirically calibrated, but the
   noon fatal happened precisely because a boundary (B7) wasn't on anyone's list.
   Making boiler own the list (correct: only boiler knows what it opens) converts
   an unbounded app-side tax into a bounded framework contract — but any NEW
   execution context (a new queue driver, WebSockets, NIO scheduled tasks) MUST
   join the table or reproduce I1. This is a standing engineering discipline,
   not a solved problem. Upstream simply does not have the class.
2. **Get-modify-set incoherence is an unfixed defect of the accessor layer, not a
   discipline issue.** `Dependency.Values.swift:60,79` getters ignoring the
   in-flight copy violates the value semantics every Swift user expects of an
   `inout` parameter. Today it is mitigated by comments and code review. It
   should be fixed structurally (getters consult `_witnessValues` pending
   storage first, then fall through to context) — until then it will keep
   biting authors exactly the way it bit boiler.
3. **RELEASE-mode report-once is still a silent-after-first-line channel.** The
   availability trade is deliberate and defensible (one forgotten key must not
   kill a serving process), but be honest: in release, an unregistered Test-only
   key still serves its test default after one stderr line — behaviorally the
   same masquerade as upstream, minus discoverability. The DEBUG-trap +
   `DEPENDENCIES_STRICT=1` smoke-run pattern (E-2 ran the gate on a DEBUG binary
   deliberately for this reason, ledger 16:55:36) is the actual enforcement; it
   must stay part of the release process, or the tripwire's release value decays
   to a log line nobody greps.
4. **Root-registration is itself an enumeration.** Forgetting `deps.logger` would
   have trapped the 18:00 tick (E-2 17:05:31 finding 3). The tripwire converts
   forgotten registrations from silent to loud — the failure mode is now
   detection-at-boundary-crossing rather than wrong-behavior, which is the right
   trade, but the list still has to be maintained by hand.
5. **Clean-room maintenance.** The fork + witnesses + primitives stack is
   institute-maintained; four same-day incident classes are the cost signature of
   young infrastructure. Upstream amortizes its edge cases across thousands of
   consumers.

**Upstream — structural, not fixable by discipline:**

1. Release-mode silence on the masquerade class (compiled out, `:520` `#if DEBUG`).
2. liveValue discovery depends on *linking* — the same split-conformance problem
   the institute has at compile time, moved to link time, with a warning only in
   DEBUG. Their own diagnostic text concedes it.
3. Process-global cache semantics: first-access caching (a computed `liveValue`
   is evaluated once and cached; `DependencyKey.swift:39-50`), once-per-process
   `prepareDependencies`, global recursive lock, ObjC/dlopen test machinery.
4. Untyped errors; Foundation dependence; no `~Copyable` values; existential
   boxing (40-byte entries vs 8).
5. Embedded: mechanism unavailable (probe-verified above).

### E. The empirical record cuts both ways — read it honestly

All three incident classes (I1 severance, I2 masquerade, I3 resource scope)
happened on the INSTITUTE stack. I1 could not have happened upstream (global
cache); I2's accessor-binding half could not have happened upstream (runtime
discovery) — though its no-liveValue-anywhere half (`\.logger`) would have
shipped silently upstream instead of trapping, which is worse; I3 (per-op Redis
connections) is DI-agnostic resource mismanagement upstream would not have
prevented either. Conversely, the tripwire caught three real defects in ONE DAY
that upstream's release builds would have swallowed permanently, and the B7/B8
spike's negative control (plain `AsyncJob` observing `TEST-DEFAULT` on a real
worker; E-2 ledger 15:17:22) demonstrates the severance class and its fix in one
experiment. The institute design's costs are mostly *loud* (traps, enumerations,
discipline); upstream's costs are mostly *silent* (release fallbacks, link-time
dependence, cache staleness). For infrastructure, loud costs are the ones you
want.

## Outcome

**Status**: RECOMMENDATION (independent assessment; input to the principal's decision)

**Answer to the principal**: **Yes — for this ecosystem, the institute approach is
better, and not marginally.** The decision is not close once you weight the
constraints the institute has actually committed to: typed throws as law
([API-ERR-001]), no-Foundation layers, Embedded as a real target (probe: upstream's
mechanism is a hard compile error there), no hidden global mutable state
([API-IMPL-010]), and infrastructure-grade diagnosability (release-mode loudness).
Point-Free's design is excellent FOR ITS ecosystem — Apple-platform apps, XCTest,
Foundation everywhere, Embedded irrelevant — and on two axes it is genuinely
superior engineering: severance simply doesn't exist for it, and its value
semantics are coherent. Those two axes are precisely where the institute paid
today: one production process kill (I1) and one never-worked log-level (get-modify-set).

But the comparison is not symmetric. Upstream's advantages come from mechanisms the
institute CANNOT adopt (runtime metatype casts — Embedded-fatal; process-global
caches — [API-IMPL-010]-fatal; ObjC observers — everything-fatal), while the
institute's two real deficits are both addressable WITHIN its own mechanism:

1. **Fix get-modify-set structurally** — `__DependencyValues` getters should
   consult the in-flight `_witnessValues` storage before falling through to the
   static context (upstream's `:242` ordering, transplanted). This deletes the
   whole "never read `$0` back" discipline class.
2. **Keep shrinking the boundary tax** — the composition root as a consultable
   fallback in the resolver (task-local → prepared → root-slot → mode default)
   would delete most per-boundary re-application fragility while keeping the
   auditable root; it deserves a design round. (Noted blind; I am aware Phase 2
   may reconcile against an existing proposal in this direction.)

Neither fix requires abandoning the idiom; both strengthen it. The ratified design
is the right architecture for this ecosystem's constraints, its costs are the loud
kind, and its strongest empirical argument is one day old: three silent production
defects — one of them as old as the program itself — became findable the first time
the tripwire booted.

## References

- Institute: `swift-witnesses/Sources/Witnesses/Witness.Values.swift` (:124-196),
  `Witness.Context.swift` (:81-97, :209-257), `Witness.Diagnostics.swift` (:44-66),
  `Witness.Preparation.swift` (:52-53), `Witness.Key.swift` (:24-90);
  `swift-dependency-primitives/Sources/Dependency Primitives/Dependency.Scope.swift`
  (:67-68, :97-117), `Dependency.Key.swift` (:55-73);
  `swift-dependencies/Sources/Dependencies/Dependency.Values.swift` (:59-99),
  `withDependencies.swift` (:65-112), `prepareDependencies.swift` (:49-69);
  `boiler/Sources/Boiler/Boiler.execute.swift`, `Boiler.Root.swift` (:35-58),
  `Boiler.Job.swift` (:26-32), `Boiler.ScheduledJob.swift` (:24-30);
  app `Sources/com_repotraffic_app/Application.swift` (read under standing override).
- Upstream (fetched from GitHub `pointfreeco/swift-dependencies@main`, 2026-07-13):
  `Sources/Dependencies/DependencyValues.swift` (:122-134, :142-198, :233-296,
  :298-371, :436-469, :471-626 — esp. :589, :615), `DependencyKey.swift` (:63-140),
  `WithDependencies.swift` (:46-48, :72-76, :82-150, :256-441).
- Spec: `Workspace/handoffs/DECISIONS-pass2/di-composition-root-design.md` (audited
  against the sources above; its §1 resolution-order and silent-channel claims
  verified accurate).
- Empirical ledgers: `CHARTER-repotraffic-boot-2026-07-13.md` (10:23:27),
  `CHARTER-repotraffic-stabilization-2026-07-13.md` (12:05:20, 12:06:16),
  `CHARTER-endstate-e1-cutovers-2026-07-13.md` (R-0 Redis storm rows),
  `CHARTER-endstate-e2-execution-2026-07-13.md` (15:17:22 spike + negative control;
  16:55:36 gates; 17:05:31 logger + get-modify-set; 17:29:52; 18:05:46/18:09:58
  favicon + envVars).
- Embedded probes (this assessment, scratchpad `embedded-probe/`):
  `upstream-mechanism.swift` (Embedded: hard error `cannot do dynamic casting in
  embedded Swift`; normal 6.4-dev: compiles+runs), `institute-mechanism.swift`
  (Embedded: compiles+runs), `root-slot.swift` (normal: compiles+runs; Embedded:
  `cannot find 'Mutex' in scope` — see Reconciliation §R4b). Toolchain
  `org.swift.64202605271a`.

---

# RECONCILIATION (Phase 2 — written after reading `di-institute-vs-pointfree-comparative.md`)

The Opus analysis was opened only after the Phase-1 verdict above was stamped
(ledger 18:21:21). Its author supervised the design round; this section is
deliberately adversarial toward it.

## R1. Agreements (briefly — the convergence is itself evidence)

Two seats, blind to each other, converged on: (1) the same single load-bearing
fact, in nearly the same words — runtime metatype cast vs compile-time overload
resolution, everything else downstream (its §0 ≡ my one-sentence mechanism); (2)
the same verdict direction — better for the institute's constraints, worse for a
typical app team; (3) the same two upstream superiorities (severance immunity,
and — partially, see R3 — split-conformance immunity); (4) the same honesty item
on `Boiler.Root` (a set-once process global; "no globals" is the wrong flag); (5)
independent empirical Embedded verification, on different toolchains (its probe:
6.3.3; mine: 6.4-dev snapshot) with different probe shapes, both foreclosing the
upstream mechanism. Blind convergence this tight means the principal can treat
the shared core as settled, not as one seat's taste. Its §3(e) ("the boundary
list has an owner… no app author can forget one") states the delivery-mechanism
value more crisply than my §C; adopted. Its clean-room claim (57 commits from
"Initial implementation") verifies: `git log --oneline | wc -l` = 57.

## R2. DELTA — its §2.1/"parity restored" materially UNDERSELLS the tripwire

The Opus doc says the loud test-default diagnostic "already exists upstream…
message-for-message… We re-derived it," and its §1 table rows "already diagnosed
upstream." **Verified at source, this is wrong in the configuration that
matters**: upstream's diagnostic is `#if DEBUG` only
(`DependencyValues.swift:520-582`); in RELEASE the entire check is compiled out
and `value ?? Key.testValue` (`:615`) serves the test default **silently,
permanently, uncached-warning-free**. Upstream DEBUG emits a non-fatal
`reportIssue`; institute DEBUG **traps**. Institute RELEASE reports once per key
to stderr and offers `DEPENDENCIES_STRICT=1` to trap
(`Witness.Diagnostics.swift:53-64`). So the honest framing is not "parity
restored": in DEBUG the institute is stricter, and in RELEASE the institute has
a diagnostic where upstream has *nothing*. The Opus honesty-ledger entry
("re-derivation of an upstream diagnostic") should be corrected before the
principal internalizes it.

## R3. DELTA — its §2.2 "upstream cannot have this bug" overclaims by one word

Upstream cannot have the *compile-time* accessor-binding class. It has the same
class at **link time**: the runtime cast finds a `DependencyKey` conformance only
if the declaring module is linked — upstream's own diagnostic instructs "make
sure that the conformance is linked with this current application"
(`DependencyValues.swift:568-569`). Statically-linked app targets rarely hit it,
so the practical claim survives; "immune by construction" does not.

## R4. DELTA — the Opus analysis MISSED the get-modify-set incoherence entirely

Nowhere in its document: the institute accessor getters read the static
task-local context, not the in-flight copy being modified
(`Dependency.Values.swift:60,79` vs upstream's storage-first read at
`DependencyValues.swift:242`). `$0.logger = X; $0.logger.logLevel = Y` silently
modifies a discarded default — which is exactly how boiler's envVars-driven log
level was never applied for the program's entire history (E-2 ledger 17:05:31
finding 2, fixed `907cf36`/`22f33cb`). This belongs on any honest "where theirs
is genuinely better" list, it is the second production-proven institute deficit,
and — important for its §6 — **the root-slot refinement does not fix it**. It
needs its own structural fix (pending-storage-first getters). Its omission is
the largest single gap in the Opus analysis.

## R4b. Adjudication of claim (a) — the Embedded foreclosure

**Claim**: *"Embedded Swift cannot do runtime metatype casts, therefore the
upstream mechanism is unavailable to the institute and a composition-root shape
is FORCED, not chosen."*

**Verdict: TRUE at its mechanism core — independently re-verified — with two
precision corrections.**

- My own probe (blind, before reading its §3(c)): a faithful reproduction of
  upstream's *generic* resolver shape fails under
  `-enable-experimental-feature Embedded -wmo` with warning `cannot perform a
  dynamic cast to a type involving protocol 'LiveKey'` + hard error `cannot do
  dynamic casting in embedded Swift`, on the exact liveValue-discovery line;
  the same file compiles and runs under normal swiftc. The Opus probe (6.3.3,
  existential-parameter shape) hit the same warning plus a different hard error
  (`cannot use metatype of type 'HasLive'`). Two toolchains, two probe shapes,
  one conclusion — the foreclosure is now double-verified. Its sharpest probe
  reading (the cast is *inert*, so every key would silently serve testValue —
  whole-program masquerade) is correct and worth keeping.
- **Correction 1 — the forcing chain has a middle step.** What Embedded
  forecloses is *runtime liveValue discovery*. Static resolution with
  `liveValue` ON THE KEY is perfectly Embedded-viable (my probe B is literally
  `K.liveValue` via static generics). The composition root is forced only by
  the CONJUNCTION: Embedded (no runtime discovery) + the Interface/Live split
  (interface-module keys must not name live implementations) + no global
  registration ([API-IMPL-010]). State the chain; "Embedded ⇒ root" alone
  overshoots, and a critic would catch it.
- **Correction 2 — the defence does not rest on one leg.** Even if Embedded
  were abandoned tomorrow, upstream remains unadoptable here: untyped
  `rethrows` vs [API-ERR-001], Foundation/ObjC-runtime/dlopen in the resolver's
  init path (`DependencyValues.swift:142-198`), process-global mutable cache vs
  [API-IMPL-010]. Its §7 "if it is false, the institute's design loses its
  strongest justification" concedes too much: Embedded is the most *dramatic*
  foreclosure, not the only one.

## R5. Adjudication of claim (b) — the root-slot resolver fallback

**Claim**: *the resolver could consult `Boiler.Root` as a last fallback
(task-local → prepared → root → key default), keeping the auditable root,
preserving Embedded-viability and test isolation, and deleting the
boundary-enumeration fragility entirely.*

**Verdict: SOUND IN ESSENCE — it is the sharpest available refinement and
deserves the design round — but NOT as literally specified. Three defects in
the sketch, two of them fixable amendments, one a real cost to price in:**

1. **The resolution order as written breaks test/preview semantics
   (mandatory amendment: mode-gate the root arm).** As sketched
   ("task-local → prepared → root → key default"), the root arm outranks the
   MODE-BASED default. In any process where the slot is set and a `.test` or
   `.preview` scope is opened (integration tests that boot the app; preview
   hosts; `Witness.Context.with(mode: .test)` anywhere post-boot), unset keys
   would resolve the LIVE root instead of `testValue` — inverting the mode
   contract (`Witness.Values.swift:140-149`). Its "test isolation would be
   unaffected (tests never call `Boiler.execute`)" holds only for unit-test
   processes. The fix is one clause: **consult the root only in `.live` mode**
   (override → prepared → *live-mode-only* root → mode default). With the
   gate, isolation is genuinely preserved; without it, the refinement is
   unsound.
2. **The slot cannot stay in boiler (mandatory amendment: the slot moves to
   the witnesses layer).** The resolver (`Witness.Values`,
   swift-foundations/swift-witnesses) cannot consult `Boiler.Root` — that
   dependency points upward. The mechanism requires witnesses to vend the
   set-once slot (say `Witness.Root`), with `Boiler.execute` setting it. That
   is a REAL scope change: the witness system itself — not the app framework —
   acquires a process-global fallback arm, and every witnesses consumer
   inherits its existence. The [API-IMPL-010] defence ("a set-once boot slot
   consulted below every task-local scope is not the mutable global dictionary
   the rejection aimed at") survives, in my judgment — set-once + trap-on-reset
   + mode-gated + overridable at every scope is auditably NOT a registration
   store — but the honest statement becomes "one mode-gated process floor,"
   not "no process-global resolution state." The slot should hold materialized
   `Witness.Values` (built once at set time), not the closure (re-running an
   app closure per resolution miss is not a resolver's business), and the
   prepared-vs-root precedence needs an explicit decision (its sketch puts
   prepared above root; defensible — task-scoped setup over process floor —
   but it must be *decided*, not inherited from a sketch).
3. **Priced cost, not amendment: what the root arm does NOT deliver.**
   (i) Per-boundary values (`\.request`, `\.application`) are inherently
   boundary-scoped — B2/B5-class seams survive; what the refinement deletes is
   the *fragility* (a missed boundary loses per-boundary values loudly, not the
   boot graph fatally), not the seams. (ii) It does not touch get-modify-set
   (R4). (iii) Embedded: the arm's *read* is cast-free, but the guard needs an
   Embedded-available primitive — probe C: `Synchronization.Mutex` is
   **unavailable under Embedded on the same snapshot where the static-resolution
   probe passes** (`cannot find 'Mutex' in scope`; compiles+runs under normal
   swiftc). Solvable (atomic once-slot, platform primitive, conditional
   compilation) — and in fairness the shipped witnesses stack (Diagnostics'
   Mutex/getenv, the box machinery) needs the same Embedded conditioning — but
   its "Embedded-viability would be preserved (a global read)" line needed
   this asterisk.

Its own "do not touch this now" recommendation is correct and I second it: the
E-2 arc is one gate from closing, and this is a witnesses-layer design round
([SUPER-057]-shaped), not a patch.

## R6. Minor deltas, for completeness

- Its §3(b) purity framing ("**nothing** declares liveValue; the app supplies
  values") describes the §4.5 ideal, not the landed hybrid: the arc itself
  co-located full-`Key` liveValues where a sensible library default exists
  (ssf `MainEventLoopGroup` W1.4; LoggingExtras `\.logger` [C], E-2 17:07:07;
  `\.analytics`/`\.waitingList` per E-2 16:55:36) and root-registers where the
  app decides. The hybrid is the right design; the purity sentence oversells.
- Additive facts from my Phase 1 it lacks (no conflict): upstream's
  once-per-process `prepareDependencies` (documented incompatible with
  repeated/parameterized tests, `WithDependencies.swift:72-76`) vs the
  institute's nestable task-scoped preparation; upstream's global recursive
  lock on every default resolution; typed-throws preservation as an adoption
  blocker in its own right.

## R7. Final call (after reconciliation)

**Unchanged from Phase 1, now with two-seat blind convergence behind it: yes —
the institute approach is better for this ecosystem, decisively, and it would be
the wrong choice for a typical Apple-platform app team.** Where the two analyses
differ, the differences sharpen rather than soften the verdict: the tripwire is
a genuine advance over upstream in RELEASE (not "parity restored" — R2), and the
institute's true outstanding deficits are exactly two, both production-proven
today, both fixable inside the mechanism — (1) get-modify-set accessor
incoherence (missed by the Opus analysis; fix: pending-storage-first getters),
and (2) the boundary tax, for which the root-slot fallback is the right
refinement **as amended** (mode-gated, witnesses-layer slot, materialized
values; R5) in a post-arc design round. I recommend the principal treat the
Opus doc's §2 "uncomfortable finding" as 50% correct (split-conformance: yes,
compile-time class is institute-specific; loud diagnostic: no — upstream's is
DEBUG-only and its RELEASE behavior is the silent masquerade itself), and its
§6 as the agenda for the next DI design round with this section's amendments
attached.
