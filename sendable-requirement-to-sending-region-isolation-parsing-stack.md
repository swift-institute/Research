# Sendable-Requirement to Sending / Region-Isolation in the Parsing/Routing/Conversion Stack

<!--
---
version: 1.0.0
last_updated: 2026-07-15
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

**Trigger**: Spun out of the HTML-tower W2 hold (2026-07-15) as a separate research arc. The
question: should the parsing/routing/conversion stack prefer **`sending` (SE-0430) +
region-based isolation (SE-0414)** over **`Sendable`/`@Sendable` *requirements*** — i.e. drop
`& Sendable` generic bounds and `@Sendable` closure *params* wherever `sending`/regions suffice?
Concrete-type `Sendable` *conformances* stay allowed; the target is the *requirement* at generic
slots and the type-erasure box, not the conformance on concrete router/parser types.

**Stack in scope** (institute-editable copies — verified on disk 2026-07-15, `pointfreeco/`
mirrors are reference-only): `swift-parser-primitives` (L1, `swift-primitives/`),
`swift-url-routing`, `swift-dual`, `swift-identities-types`, `swift-authentication`,
`swift-dependencies`, `swift-witnesses` (all `swift-foundations/`). **`swift-parsing`
(pointfreeco) is NOT in the stack** — see Deliverable 1, task #0.

**Skills loaded** ([RES-033] dispatch-time skill-load gate): **research-process** ([RES-*]),
**memory-safety** ([MEM-SEND/…]), **supervise** ([SUPER-*], the arc's channel discipline). The
territory is concurrency/isolation semantics + type-erasure API surface.

**Constraints**: Research only (no source edits; throwaway compile-probes then discarded).
Standing toolchain **swift-6.3.3-RELEASE** (`org.swift.633202606251a`); version-sensitive
probes run on both 6.3.3 and the only installed "future" toolchain, **6.5-dev**
(DEVELOPMENT-SNAPSHOT-2026-05-27-a; **no 6.4-RELEASE is installed** — see Deliverable 5). All
`swiftc` probes were invoked by absolute toolchain path with the version **tag** asserted
(`swift-6.3.3-RELEASE` / `6.5-dev`), sidestepping the `TOOLCHAINS` silent-fallback trap
([PKG-BUILD-022]).

## Question

Across every `Sendable`/`@Sendable`/`sending` occurrence in the stack, is each one **(a)**
genuine concurrent *sharing* (needs an honest conformance), **(b)** a one-time *transfer*
(`sending`/regions can carry it), or **(c)** *gratuitous* (removable outright)? And specifically:
does `sending`/region isolation flow through the `@Dependency` storage-and-sharing model at all,
or must that model change — given that the crux router is **built once, stored in a
`@Dependency`, and read by many concurrent request handlers (sharing, not transfer)**?

---

## Recommendation (lead with the outcome)

**DEFER — and, for the routing/conversion surface, treat as effectively already-done. Keep the
one honest erasure requirement. Do not change the `@Dependency` model.**

The premise that there is a population of removable `Sendable` *requirements* in this stack to
migrate onto `sending`/regions **does not hold on the disk**. The ecosystem's ratified
"prefer `sending` over `Sendable`" policy was already applied here by *removing* requirements,
not by adding `sending`: the composition layer stores deliberately non-`@Sendable` closures and
carries zero `Sendable` bounds; the combinators expose only conditional `Sendable`
*conformances* (allowed); and the whole stack contains **exactly one live `& Sendable`
requirement relevant to routing** — the type-erasure boundary `AnyParserPrinter.init` — which is
a genuine **(a) sharing** requirement that `sending` **cannot** replace (proven below on both
toolchains). The large `@Sendable`/`@unchecked` counts in the consumers are the DI-client/config
*sharing* surface, a separate `@DependencyClient`→`@Witness` concern, not a `sending` opportunity.

**The make-or-break, stated plainly (as the charter invited): the shared router still needs a
real `Sendable` conformance.** That bounds the refactor to zero for the routing surface.

---

## Deliverable 1 — Authoritative violator inventory

### Task #0 — is `swift-parsing` (pointfreeco) even in the stack? **No.** [Verified: 2026-07-15]

Zero `import Parsing` and zero manifest references to `swift-parsing` across all 7 packages
(positive-controlled: the `import Parsing` regex matches `import Parsing` but not
`import Parser_*_Primitives`). The parser substrate is entirely the institute's decomposed
`swift-parser-primitives` (`Parser_*_Primitives` modules) + `URLRouting`. `swift-parsing`
resolves only to `pointfreeco/swift-parsing` and is **out of scope**. The other six seed packages
all exist at their pinned institute paths, and all five §4 charter facts verified verbatim on
disk (including `Case.Path` storing plain, non-`@Sendable` `let embed/extract` closures at
`Case.Path.swift:12-13`).

### Token census (Sources/ lines, `.build*`/`checkouts` excluded, positive-controlled) [Verified: 2026-07-15]

| Package | `Sendable`¹ | `@Sendable` | `sending` | `nonsending` | `@unchecked` |
|---|---:|---:|---:|---:|---:|
| swift-parser-primitives | 23 | 2² | 0 | 0 | 1 |
| swift-url-routing | 74 | 19 | 0 | 0 | 13 |
| swift-dual | 17 | 3 | 0 | 0 | 0 |
| swift-identities-types | 180 | 2 | 0 | 0 | 38 |
| swift-authentication | 247 | 142 | 0 | 0 | 6 |
| swift-dependencies | 9 | 1 | 0 | 6 | 1 |
| swift-witnesses | 71 | 18 | 0 | 29 | 5 |

¹ `Sendable`-mentioning lines (umbrella token; catches conformances, bounds, `@Sendable`,
`@unchecked Sendable`, `~Sendable`). **A floor on symptoms, not a cost** — most are concrete
conditional *conformances* (allowed), not *requirements*. ² Both are in *comments* explaining
the closures are deliberately non-`@Sendable`.

**`sending` = 0 everywhere.** The relaxation the arc contemplates was accomplished by *removing*
requirements, not by adopting `sending`. `nonsending` appears only in the DI substrate
(`swift-dependencies` 6, `swift-witnesses` 29) — the operation-scoping `nonisolated(nonsending)`
double-pattern, already adopted.

### The actual `& Sendable` *requirements* in the entire stack (the real target) [Verified: 2026-07-15]

Exhaustive `& Sendable` grep across all 7 packages returns **four** lines, of which **one** is a
live routing requirement:

| Site | Kind | Disposition |
|---|---|---|
| `swift-url-routing/…/PointFree.AnyParserPrinter.swift:72` `init<P: Parser.Bidirectional & Sendable>` | **live routing requirement** | (a) sharing — **keep** |
| `swift-url-routing/…/PointFree.AnyParserPrinter.swift:89` `where Self: Sendable` (`eraseToAnyParserPrinter`) | sibling of the above | (a) sharing — **keep** |
| `swift-witnesses/…/Witness.Key.swift:26` `associatedtype Value: ~Copyable & Sendable` | genuine crossing point | keep (per `witness-ownership-integration.md` §2) |
| `swift-authentication/…/Identity.View.Logo.swift:15` | a **comment** (`// NOT any HTML.View & Sendable`) | n/a — not live code |

`swift-parser-primitives`, `swift-dual`, `swift-identities-types`, `swift-dependencies`: **zero**
`& Sendable`.

### Routing-core `Sendable` surface, categorised [Verified: 2026-07-15]

- **Composition layer already relaxed** (`swift-parser-primitives`): `Parser.Conversion.Witness`
  *deliberately* stores non-`@Sendable` closures — the in-file comment
  (`Parser.Conversion.Witness.swift:34,37`) states that making them `@Sendable` "is a
  source-breaking signature change to these `public`" APIs. `Parser.Bidirectional` carries **no**
  `Sendable` refinement (`Parser.Bidirectional.swift:40`). Conformances are conditional
  (`Fail: Sendable`; `Spanned: Sendable where T: Sendable`; `Tracked.Checkpoint: Sendable
  where …`). This is exactly the ratified "isolation-preserving concrete composition" side of the
  Two-Tier pattern.
- **Combinators expose conditional `Sendable` conformances only** (`swift-url-routing`):
  `Map: Sendable where Upstream, Downstream: Sendable` (`:77`); `OneOf` (`:52`), `OrderedChoice.Of`
  (`:112`), `Optionally` (`:94`), `Parse` (`:93`) — all `where …: Sendable`. The RFC URI
  parser/builder families use `@unchecked Sendable where …: Sendable` (family-4 structural
  workaround: the compiler can't derive structural `Sendable` through the parser generics).
  **All of these are concrete-type conformances — allowed by the goal.**
- **Every `@Sendable` in `swift-url-routing` is on a *stored closure*** (backing a concrete box's
  conformance): `AnyParserPrinter._parse/_print` (`:39,42`), `URLRouting.Value._parse/_print`
  (`:28,31`), `Multipart.Encoder.encode` (`:17,39`), `FileUpload.FileType.validate`
  (`:44`, `ImageType:41`). **Zero viral `@Sendable`-closure-*parameter* requirements on
  combinators.**

### Consumer-side surface = the DI-client concern, not routing [Verified: 2026-07-15]

- `swift-authentication`'s 142 `@Sendable` are configuration/effect closures
  (`Identity.Frontend.Configuration.swift:32-34`: `currentUserName: @Sendable () async throws ->
  String?`, `canonicalHref`, `hreflang`) stored on shared config/client structs.
- `swift-identities-types`' 38 `@unchecked` are all `struct Client: @unchecked Sendable` / domain
  structs (`Identity`, `Password`, `…Client`) — the `@DependencyClient` pattern.
- These are `(a)` sharing (injected operations shared via `@Dependency`), owned by the
  `@DependencyClient`→`@Witness` migration, **not** this arc.

---

## Deliverable 2 — Per-occurrence share / transfer / gratuitous classification

| Class | Population in this stack | Can `sending`/regions carry it? | Disposition |
|---|---|---|---|
| **(a) genuine SHARING** | The erasure-box requirement (`AnyParserPrinter.init:72` + `eraseTo where Self: Sendable:89`); the `@Dependency`-stored router; the DI-client/config `@Sendable` closures (authentication 142); the `@unchecked Sendable` domain/client structs (identities-types 38); `Witness.Key`/`Witness.Context` requirements. | **No** — sharing is permanent multi-reader access, not a one-time transfer; and stored closures cannot take `sending` at all (P1). | **Keep** the conformances/requirements. |
| **(b) one-time TRANSFER** | **Effectively none in-stack.** No site erases/stores a router via a single transfer rather than shared storage. (The `withDependencies`/`withWitnesses` operation scope already uses `nonisolated(nonsending)` regions — `withDependencies.swift:94-97`, `withWitnesses.swift:64-67`.) | n/a | Already region-isolated where applicable. |
| **(c) GRATUITOUS** | **Effectively none remaining.** The composition layer already dropped its `@Sendable`/bound requirements; combinators carry only conditional conformances. | n/a | Nothing to remove. |

**Conclusion**: the stack's `Sendable`/`@Sendable` surface is overwhelmingly **(a) sharing of
values stored in `@Dependency`/`@Witness` and read concurrently** — the one case `sending`
structurally cannot address. The (c) population that a `sending` migration would target was
already eliminated.

---

## Make-or-break — the `@Dependency` sharing verdict (Deliverable 4)

**The `@Dependency` storage-and-sharing model *requires* `Sendable`, and `sending`/region
isolation does NOT flow through it as a substitute. The model does not need to change; the shared
router must keep a real `Sendable` conformance.** [Verified: 2026-07-15]

Grounded in source:

- **`public struct Dependency<Value: Sendable>: Sendable`** (`Dependency.swift:54`) — the property
  wrapper constrains `Value: Sendable` at the type level. Both initialisers (KeyPath and Key)
  carry it; there is **no non-`Sendable` `@Dependency` variant**.
- **`public struct __DependencyValues: Sendable`** (`Dependency.Values.swift:20`) — the storage
  container is itself `Sendable`; access is via `@Sendable` closures
  (`_Accessor.closure(@Sendable (__DependencyValues) -> Value)`, `Dependency.swift:124`).
- **Thread-safety is via TaskLocal storage** (`Dependency.swift:52`; value resolved from
  `__DependencyContext.current`, `:110`) — i.e. one stored value **read concurrently by every
  handler**. This is **sharing**, not transfer.
- The `_Accessor: @unchecked Sendable` (`Dependency.swift:122`) is a *structural KeyPath
  workaround* (documented Category D: the compiler can't derive structural `Sendable` for an enum
  holding `KeyPath` even when Root/Value are `Sendable`) — its `Value` is **still**
  `Sendable`-constrained. It is not an escape hatch from the requirement.

Because a `@Dependency` value is stored once and read from many isolation domains simultaneously,
there is no single "transfer" event for `sending` to govern. `sending` moves a value *into* a
domain; it does not make a value safe to *share across* domains. Therefore any value transitively
stored in a `@Dependency` — including `Identity.Authentication` (`@unchecked Sendable`,
`Identity.Authentication.swift:19`) and its `router: AnyParserPrinter<…>` (`:21`) — **must be
`Sendable`**. `AnyParserPrinter` being unconditionally `Sendable` (`PointFree.AnyParserPrinter.swift:34`)
is load-bearing, not gratuitous.

*(Note: `Identity.Authentication` is `@unchecked` because two of its three members are
`@DependencyClient` clients holding `async throws` closures — not because of the router, which is
honestly `Sendable`. The `@unchecked` is the DI-client story, separate from routing.)*

---

## Deliverable 3 — Target design for the erasure boundary + combinators

**The target design is the current design.** The stack already implements the ecosystem's ratified
**Two-Tier** shape: a concrete, isolation-preserving, non-`@Sendable` composition layer
(`swift-parser-primitives`) + **one explicit `Sendable` erasure boundary** (`AnyParserPrinter`)
that keeps its `Sendable` requirement *at the boundary only*. No combinator redesign is warranted.

### Why a `sending`-based erasure box is structurally impossible — compile-probe evidence

Minimal single-file `swiftc -typecheck -swift-version 6` probes (RES-028 smallest-isolation-first),
each `swiftc` invoked by absolute path with the version tag asserted. **Results identical on
`swift-6.3.3-RELEASE` and `6.5-dev`:**

| Probe | Both toolchains | What it proves |
|---|---|---|
| **P1** — `let f: sending (Int) -> Int` (stored) | **ERROR**: `'sending' may only be used on parameters and results` | `sending` cannot annotate a **stored closure type** — the erasure box stores closures, so it cannot be built on `sending`. |
| P2 — `init(f: sending @escaping (Int)->Int)` | compiles | `sending` is valid on a *parameter* (transfer into the init), but the resulting box (plain stored closure) is **not** `Sendable`. |
| P4 — `struct EBox: Sendable { let _run: @Sendable …; init<R: Router>(_ r: R) { _run = { r.run($0) } } }` | **ERROR**: `capture of 'r' with non-Sendable type 'R' in a '@Sendable' closure [#SendableClosureCaptures]` | The `& Sendable` requirement is **load-bearing** — you cannot store a `@Sendable` closure capturing a non-`Sendable` router. |
| P5 — same, `init<R: Router & Sendable>` | compiles | The current `AnyParserPrinter.init<P: … & Sendable>` is the **minimal honest shape**. |
| **P6 (decisive)** — `init<R: Router>(_ r: sending R) { _run = { r.run($0) } }` | **ERROR**: `#SendableClosureCaptures` | **`sending` cannot drop the requirement**: the `@Sendable` stored closure escapes the init's region into shared storage, so the captured value must be `Sendable` regardless of `sending`. |

**"More or less honest than `@unchecked`?"** (the charter's §4 framing). The only way to drop the
`& Sendable` requirement is to make the box `@unchecked Sendable` storing **non-`@Sendable`**
closures. That is **less** honest and, per policy, **wrong** here: a box storing arbitrary
non-`@Sendable` closures capturing non-`Sendable` routers is not genuinely thread-safe (the
closures could capture mutable non-`Sendable` state and be called concurrently), so the
`@unchecked` would be "a lie" (`modern-concurrency-conventions.md` §Key Principle 4;
`safe-unsafe-attribute-and-unchecked-sendable-best-practices.md` §Deterministic rule). Moreover
the routers are already immutable value-type `ParserPrinter` structs that conform to `Sendable`
(`Identity.…Route.Router: ParserPrinter, Sendable`), so the requirement costs the callers
**nothing**. The compiler-verified `& Sendable` is strictly more honest than an `@unchecked`
attestation, and free. **Keep it.**

---

## Prior Art Survey ([RES-021])

### Internal corpus (the [RES-019] step-0 grep governs)

The 14 highest-relevance docs consolidated into **three live docs** (supersession verified against
`_index.json` + each successor's `consolidates:` frontmatter):

- **`ownership-transfer-conventions.md`** (RECOMMENDATION) — the live home for the
  `sending`/`Sendable`/`nonsending`/`~Sendable` cluster. Thesis: *"Prefer `sending` over
  `Sendable`. Prefer isolation over sendability … require `Sendable` only where values actually
  cross isolation domains."*
- **`modern-concurrency-conventions.md`** (RECOMMENDATION) — the umbrella policy. **Convention 2
  "Minimize Sendable Surface"**; **Key Principle 4**: *"`@unchecked Sendable` on a thread-confined
  type is a lie. `~Sendable` tells the truth."*
- **`witness-ownership-integration.md`** (DECISION) — `Sendable` was **removed** from
  `Witness.Protocol` (pure marker) and required only at genuine crossing points
  (`Witness.Key`/`Values`/`Context`). Precedent already shipped for the synchronous parse/compile
  witness case.

Plus two live standalone references: **`async-stream-sendable-requirement.md`** (DEFERRED — the
"should X *require* `Sendable`?" template: Options A status-quo / B non-Sendable / C two-tier /
D dual; preliminary rec = **Option C two-tier**, with the "Key Insight" that *`@Sendable` on the
stored closure type is the sole isolation gatekeeper, not `@unchecked Sendable` on the concrete
box*), and **`tca26-isolation-patterns-investigation.md`** (RECOMMENDATION — TCA26's `Store` tree
has zero `Sendable` constraint on State/Action; isolation via an `isolation: (any Actor)?` field;
only *boundary* closures carry `@Sendable`).

**1:1 precedent already shipped**: `Async.Channel<Element>` dropped its `& Sendable` requirement in
favour of `sending` region-transfer, while the type-erased `Async.Stream` **kept** `Element:
Sendable` as structurally correct for a shared boundary
(`async-stream-sendable-requirement.md` §Immediate Decision). This is the exact split the routing
stack faces — and the routing stack already sits on the correct side of it.

### External anchors (SE proposals)

- **SE-0430 `sending`** — a *one-time ownership transfer across an isolation boundary*; a
  calling-convention annotation on function decls, **not** applicable to stored closure types.
  Probe P1 confirms the compiler enforces this verbatim.
- **SE-0414 Region-based isolation** — lets non-`Sendable` values cross a boundary once when the
  compiler proves the region is disconnected. It does not make a value safe for *repeated
  concurrent reads from shared storage*, which is why P6 still errors.
- **SE-0302 `Sendable`** — the permanent type-level "safe to share across concurrency domains"
  constraint that `@Dependency<Value: Sendable>` depends on.

### Contextualization step ([RES-021]) — is the "absence of `sending` here" a gap or a design decision?

Universal ecosystem adoption of "prefer `sending`" does **not** imply this stack should adopt
`sending` at the erasure boundary. Concretised in this stack's type system, a `sending`-based
erasure box is **not expressible** (P1) and a `sending`-based requirement-drop is **unsound for
sharing** (P6). The absence of `sending` in the routing core is therefore a **correct design
outcome**, not a gap: the relaxation was already taken by *removing* the requirements that could
be removed (composition layer), leaving only the honest sharing requirement that must remain.

---

## Deliverable 5 — Blast radius, migration sequencing, wait-for-6.4, recommendation

### Blast radius of a *forced* migration (if one were attempted anyway)

Net-negative and large. Dropping the erasure-box requirement forces `AnyParserPrinter` to
`@unchecked Sendable` over non-`@Sendable` closures — a policy violation (a "lie" per Key
Principle 4) that would have to propagate an unchecked attestation across every erased-router
storage site (`Identity.*` domain structs, all `@Dependency`-stored routers). It buys nothing:
the routers are already `Sendable`. There is no removable-`(c)` population to justify any churn.

### Migration sequencing

None required for the routing/conversion/erasure surface — it is at the end-state. The only live
concurrency-idiom work adjacent to this stack is the **`@DependencyClient`→`@Witness` migration**
of the DI-client surface (the 142 `@Sendable` config closures + 38 `@unchecked` client structs).
That is a *DI-idiom* change (already tracked under the repotraffic END-STATE program), **not** a
`sending`/region relaxation, and is out of this arc's scope.

### Wait for the 6.4 toolchain flip? **No.**

The decisive behaviors (P1, P4, P6) are **identical on `swift-6.3.3-RELEASE` and `6.5-dev`**.
`sending` cannot annotate a stored closure, and a `sending` param captured into a `@Sendable`
stored closure still requires `Sendable`, in **both** toolchains. The recommendation does not turn
on the toolchain version, so there is nothing to wait for.

> **Caveat (assert the resolved version, never mislabel — [PKG-BUILD-022]):** no `6.4-RELEASE`
> toolchain is installed on this machine. "Future" was probed on `6.5-dev`
> (DEVELOPMENT-SNAPSHOT-2026-05-27-a, whose bundle id `org.swift.64202605271a` *looks* like 6.4
> but reports `Apple Swift version 6.5-dev`). 6.4 sits between two agreeing versions (6.3.3 and
> 6.5-dev); the region-isolation semantics exercised here are stable across that range, so 6.4 is
> overwhelmingly expected to agree, but this specific claim is *inferred*, not measured on a
> 6.4-RELEASE binary. If a genuine 6.4-RELEASE probe is later required, re-run P1/P4/P6.

### Recommendation

- **DEFER / already-done** for the routing/conversion/erasure surface. Keep `AnyParserPrinter`'s
  `& Sendable` requirement and unconditional `Sendable` conformance. Do not convert to
  `@unchecked`. Do not change the `@Dependency` model.
- **No action** on the combinators (conditional conformances are correct) or the composition layer
  (already non-`@Sendable`).
- **Out of scope / separate arc**: the DI-client `@DependencyClient`→`@Witness` migration.

---

## Outcome

**Status: RECOMMENDATION — DEFER (routing surface already at the ratified end-state).**

The make-or-break resolves as a bounded honest answer, exactly as the charter anticipated: **the
shared router still needs a real `Sendable` conformance.** The `@Dependency` model requires
`Sendable` for shared storage and is correct as-is; `sending`/region isolation neither substitutes
for that requirement (P6) nor can even be expressed at the erasure boundary (P1). The one live
`& Sendable` requirement in the routing stack is genuine `(a)` sharing and is the minimal honest
design; the `(c)` gratuitous population a `sending` migration would target was already removed.
This arc **applies** the ecosystem's ratified "prefer `sending` over `Sendable`" policy to this
stack and finds the stack already compliant — it does not set new precedent (Tier 2).

## References

**Source (institute-editable copies, verified 2026-07-15):**
- `swift-foundations/swift-url-routing/Sources/URLRouting/PointFree.AnyParserPrinter.swift` — erasure box (`:34` conformance, `:39,42` stored `@Sendable` closures, `:72` `& Sendable` init, `:89` `where Self: Sendable`).
- `swift-foundations/swift-dependencies/Sources/Dependencies/Dependency.swift` — `Dependency<Value: Sendable>` (`:54`), TaskLocal thread-safety (`:52`), `_Accessor` (`:122-124`); `Dependency.Values.swift:20` (`__DependencyValues: Sendable`).
- `swift-foundations/swift-identities-types/…/Identity.Authentication.swift` — `@unchecked Sendable` (`:19`), `router` member (`:21`).
- `swift-primitives/swift-parser-primitives/…/Parser.Conversion.Witness.swift:34,37` (deliberately non-`@Sendable` closures); `Parser.Bidirectional.swift:40` (no `Sendable` refinement).
- `swift-foundations/swift-dual/Sources/Case Paths/Case.Path.swift:12-13` (plain `let embed/extract`).
- `swift-foundations/swift-witnesses/…/Witness.Key.swift:26`, `Witness.Context.swift:51`, `withWitnesses.swift:64-67` (nonsending operation scope).

**Internal research (built on, [RES-019]):** `ownership-transfer-conventions.md`,
`modern-concurrency-conventions.md`, `witness-ownership-integration.md`,
`async-stream-sendable-requirement.md`, `safe-unsafe-attribute-and-unchecked-sendable-best-practices.md`,
`tca26-isolation-patterns-investigation.md`.

**Swift Evolution:** SE-0430 (`sending`), SE-0414 (region-based isolation), SE-0302 (`Sendable`),
SE-0518 (`~Sendable`).

**Compile-probe evidence:** P1–P6, `swiftc -typecheck -swift-version 6`, on `swift-6.3.3-RELEASE`
(`org.swift.633202606251a`) and `6.5-dev` (DEVELOPMENT-SNAPSHOT-2026-05-27-a). Probes were
throwaway (scratch location) and discarded per the arc's research-only constraint; the salient
diagnostics (`'sending' may only be used on parameters and results`;
`capture of 'r' … in a '@Sendable' closure [#SendableClosureCaptures]`) are quoted inline in
Deliverable 3.
