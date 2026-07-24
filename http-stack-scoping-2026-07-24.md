# HTTP stack — scoping decision packet (BOARD #32)

**Status:** Phase 1, SCOPE ONLY. No source edits, no commits, no gates run.
**Lane:** HTTP stack. **Date opened:** 2026-07-24.
**Path of record:** N7 (HTTP/1.1 law) → N8 (client).

> ⚠️ **This document is written incrementally, section by section, as evidence lands.**
> A prior attempt at this task ran as an inline subagent, was believed to be writing this
> file, and produced nothing recoverable. Every section below is committed to disk at the
> moment its evidence is verified, not at the end. Sections marked `[PENDING]` have not
> been investigated yet; sections with content are backed by cited paths and line numbers.

---

## 0. Provenance of the brief, and two discrepancies found on intake

Recorded here first because they affect how this packet's own premises should be read.

### 0.1 Priority rank of #32 — BOARD is self-inconsistent

- `Internal/BOARD.md:22` (standing ruling, principal, direct) lists the goal's priorities in
  order: **"HTTP stack · repotraffic as thin a layer as possible · render duplication
  (deferred behind workspace tooling)"** — HTTP stack is **first**.
- `Internal/BOARD.md:150` (the #32 row) says **"HTTP stack — priority #2"**.

These cannot both be right. The ruling row (line 22) is the principal's direct words and
enumerates all three in order; the task row is a summary. **Reading: #32 is priority #1**,
and `BOARD.md:150` carries a stale rank. This matches the lane brief. Recommend the Lead
correct line 150 rather than line 22.

### 0.2 The Fable gate removal names N5/N6, not N7/N8

- `Internal/BOARD.md:19`: **"Fable gate on N5/N6 REMOVED — Opus 5 satisfies the
  design-authority review."**
- `Internal/BOARD.md:150` (#32): "Path is N7 HTTP/1.1 law → N8 client. **Unblocked** by the
  Fable-gate removal."

The ruling as recorded is scoped to **N5/N6**; #32 claims the same removal unblocks
**N7/N8**. The lane brief also states the removal covered the HTTP stack. Most likely the
ruling row is under-transcribed (the gate was a design-authority review over the N-series,
not over two specific numbers), but **as written, the durable record does not license the
#32 unblock**. This is not a blocker for Phase 1 — scoping is not gated work — but the Lead
should get the ruling row's wording confirmed before N7 implementation begins, since that
is the point at which a design-authority gate would actually bite.

### 0.3 Toolchain instruction in the brief is consistent with the record

`CLAUDE.md:133-142` and `BOARD.md:21` both carry the Xcode-bundled-toolchain ruling with no
`TOOLCHAINS`. No document consulted for this packet so far instructs otherwise. Any that do
will be named in §6.

### 0.4 ⚠️ NEW INSTRUMENT DEFECT — `git log --since=<bare ISO date>` returns a silent zero

Found while investigating §1.3. Proposed for `BOARD.md` standing method rules; it is the same
family as the `timeout(1)` and `${PIPESTATUS[0]}` entries already there.

Measured on `swift-foundations/swift-authentication`, which holds two commits timestamped
`2026-07-24T13:43:55+02:00` and `2026-07-24T15:09:44+02:00`:

| probe | commits returned |
|---|---|
| `--since=2026-07-24` | **0** |
| `--since='2026-07-24 00:00'` | 2 |
| `--since=2026-07-23` | 2 |
| `--since='36 hours ago'` | 2 |

**A bare `YYYY-MM-DD` passed to `--since` silently excludes that entire day.** Swept across
every package root this produces a uniform negative that reads exactly like "nothing happened
today" — which is precisely the wrong conclusion on the busiest day in the register. **Always
pass an explicit time (`'YYYY-MM-DD 00:00'`) or a relative window.** This packet's first sweep
hit it and was discarded.

### 0.5 Lane split on N7 (Lead ruling, 2026-07-24 evening)

N7 Phase 1 is split across two lanes:

| Owner | Scope | Deliverable |
|---|---|---|
| **This lane** | Layer placement · build-vs-adopt · package topology · **N8 client** · repotraffic networking holdouts | this file |
| **`local_4b4d0360-…`** (RFC 5280 profile-law lane; 173 tests / 115 suites green, pushed and `ls-remote`-verified) | **Specification inventory** — clause-by-clause, what RFC 9110 and RFC 9112 *require* of an implementation | `Research/rfc-9110-9112-law-inventory-2026-07-24.md` |

**Placement is this lane's**; the inventory lane may not create packages, choose a layer, or
author source until this packet lands. Its half is placement-independent by construction.

**Dependency this creates on §4:** the Lead has ruled the inventory the **requirements input
to the build-vs-adopt call**. *"If an adopt candidate cannot satisfy the MUST clauses it
enumerates — particularly message-body length determination (9112 §6.3) and request-smuggling
resistance — that is a disqualifier, not a caveat."*

§4's verdict is **BUILD**, and that verdict does not depend on the inventory: `[HERITAGE-001]`
fails at the *material lineage* condition for every candidate, before conformance is reached.
The inventory therefore **cannot overturn §4** — it can only add independent grounds for the
same conclusion. Recorded so a later reader does not treat §4 as provisional on a document
that had not yet been written. What the inventory **will** change is §5's Step 3/4 sizing, and
it is the right input for that.

I have briefed that lane directly on the survey findings bearing on its half — that 9110/9112
already exist and at what size, the `HTTP.MessageBodyLength.swift` file that lands on §6.3,
the `Deserializer.swift:119` self-admitted inexact consumed count, the whole-buffer structural
constraint, the `Method`-rendering hazard with its corrected cause, and the possible salvage
from the obsoleted `swift-rfc-7230`. I asked it to mark MUST clauses that a whole-buffer API
**cannot structurally satisfy** distinctly from ones merely missing a check — that distinction
is what sizes N7, and a flat present/absent verdict would hide it.

---

## 1. What exists today — the HTTP surface census

### 1.0 Headline: **N7 is not greenfield — but the part N7 actually asks for is missing.**

> **Self-correction, recorded rather than quietly edited.** I first wrote this section as
> "N7 is ~80% built." That was wrong in a way worth preserving, because it is the error a
> file-count census invites. The *declarative* HTTP/1.1 law is largely present; the
> **bounded incremental framing that N7 is defined by is not present at all**, and N7's L3
> half is an empty scaffold. Sizing N7 by counting `swift-rfc-9112`'s 3,002 lines would
> underestimate it badly. Both halves of the picture are below.

The brief's path of record — "N7 (HTTP/1.1 law) → N8 (client)" — reads as two things to
build. **It is not.** `swift-ietf/swift-rfc-9112` already exists at **17 source files / 3,002
lines / 13 test files**, and what it implements is exactly HTTP/1.1 message law:

```
HTTP.Message.Parser.swift        HTTP.Message.Serializer.swift    HTTP.Message.Deserializer.swift
HTTP.ChunkedEncoding.swift       HTTP.TransferEncoding.swift      HTTP.MessageBodyLength.swift
HTTP.Request.Line.swift          HTTP.Response.Line.swift         HTTP.Version.swift
HTTP.Request.Validator.swift     HTTP.Response.Validator.swift    HTTP.Host.swift
HTTP.Connection.swift            HTTP.Connection.State.swift      HTTP.Pipeline.swift
HTTP.Field.swift                 RFC_9112.swift
```

with a matching 12-suite test corpus (`Tests/RFC 9112 Tests/`).

I flag the existing code loudly because the brief describes #32 as having "had no lane at all
until now" — true of the *lane*, demonstrably false of the *code*. Anyone starting from the
brief alone would plausibly rebuild 3,000 lines that already pass their own tests.

**But the API shape is whole-buffer, and N7 needs incremental.** The heritage record asserts
this (`:119`: *"RFC 9112 is whole-buffer only and is not safe as a bounded reusable socket
drive"*). I verified it independently rather than inheriting the claim:

- `HTTP.Message.Parser.swift:20` — `public static func parseLines(from data: [Byte]) throws(ParsingError) -> [Line]`.
  Takes the entire buffer, returns every line. **No resumable state, no "need more bytes"
  signal, no consumed count.**
- `HTTP.Message.Deserializer.swift:17` and `:207` — `public static func deserialize(…)`,
  likewise whole-buffer and static.
- `HTTP.Message.Deserializer.swift:119` carries this comment in shipped source:

  ```swift
  // Calculate chunked bytes consumed (this is approximate - should track precisely)
  ```

**"Inexact consumed count" is a named N7 STOP condition** (record `:769`). The source
therefore contains, in a comment, an admission of one of the exact conditions that must be
cleared before N7 can pass its gate. That is a gift — it is a precise, pre-localised starting
point — but it means the existing parser cannot simply be wrapped.

**So the honest sizing of N7 is:**

| N7 component | Layer | State | Work |
|---|---|---|---|
| HTTP/1.1 *declarative* law (lines, versions, validators, chunked/transfer encodings) | L2 | **Present**, 3,002 lines, 13 test files | Audit + retain |
| **Bounded incremental framing** (resumable parse, exact consumed count, limits) | L2 | **Absent** — whole-buffer static API only | **Build** |
| **`swift-http` drive** (exchange, backpressure, reuse eligibility, shutdown over an injected duplex) | **L3** | **Empty scaffold** (`LICENSE.md` only) | **Build** |

The lane's first deliverable should be a differential audit of RFC 9112 §§2–11 against the
existing files **plus an incremental-API design**, not a from-scratch design and not a
wrapper.

### 1.1 The layer map, measured

Counts are `Sources/**/*.swift` file count and total line count, `.build*` excluded.
`SCAFFOLD` = repository directory containing `LICENSE.md` and nothing else — a reserved name,
**not** an implementation. The scaffold/real distinction is the single most misleading thing
about this surface: by directory listing alone the ecosystem appears to have a complete HTTP
stack, and about half of it is empty.

**L2 — Standards / IETF spec packages** (`swift-ietf/`)

| Package | Files | Lines | Tests | Verdict |
|---|---|---|---|---|
| `swift-rfc-9110` (HTTP Semantics) | 48 | 5,916 | 12 | **Real, load-bearing.** Method, Status, Headers, MediaType, Content Negotiation, Auth, Precondition, Entity Tag, Date, and a `HTTP.Parse.*` combinator family. |
| `swift-rfc-9112` (HTTP/1.1) | 17 | 3,002 | 13 | **Real — this is N7.** See §1.0. |
| `swift-rfc-9111` (Caching) | 12 | 2,187 | 8 | Real. Freshness, Age, CacheControl, Vary, Validation, StorageEligibility. |
| `swift-rfc-3986` (URI) | 31 | 5,877 | 9 | Real. |
| `swift-rfc-6455` (WebSocket) | 9 | 924 | 2 | Real. |
| `swift-rfc-7617` (Basic auth) | 7 | 849 | 5 | Real. |
| `swift-rfc-6570` (URI Template) | 12 | 960 | 5 | Real. |
| `swift-rfc-6265` (Cookies) | 7 | 379 | 2 | Real. |
| `swift-rfc-8288` (Web Linking) | 8 | 291 | 1 | Real. |
| `swift-rfc-6750` (Bearer) | 3 | 449 | 3 | Real. |
| `swift-rfc-6797` (HSTS) | 3 | 97 | 1 | Thin. |
| `swift-rfc-7230` (HTTP/1.1, **obsoleted**) | 6 | 1,370 | 1 | **Real but superseded — see §1.4.** |
| `swift-rfc-7231` (obsoleted) | 1 | 245 | 1 | Fragment. |
| `swift-rfc-7232/7233/7234/7235` (obsoleted) | 1 each | **11 each** | 1 each | Empty stubs. |
| `swift-rfc-9113` (HTTP/2) | — | — | — | **SCAFFOLD** |
| `swift-rfc-9114` (HTTP/3) | — | — | — | **SCAFFOLD** |
| `swift-rfc-9457` (Problem Details) | — | — | — | **SCAFFOLD** |
| `swift-rfc-6585` (Additional status codes) | — | — | — | **SCAFFOLD** |
| `swift-rfc-7616` (Digest auth) | — | — | — | **SCAFFOLD** |

**L2 — `-standard` convergers** (`swift-standards/`)

| Package | Files | Lines | Verdict |
|---|---|---|---|
| `swift-http-standard` | 2 | **35** | **Pure re-export. Implements nothing.** |
| `swift-uri-standard` | 7 | 287 | Thin, but holds real canonicalization law (see §1.5). |

`swift-http-standard` in full is `@_exported public import` of RFC 9110/9111/9112
(`Sources/HTTP Standard/exports.swift:13-15`) plus `public typealias HTTP = RFC_9110`
(`Sources/HTTP Standard/HTTP.swift:20`). It is the friendly-vocabulary front door and nothing
else. **Every line of HTTP law in this ecosystem lives in an `swift-rfc-*` package.**

**L3 — Foundations** (`swift-foundations/`)

| Package | Files | Lines | Tests | Verdict |
|---|---|---|---|---|
| `swift-url-routing` | 72 | 6,895 | 23 | Real, and the busiest HTTP-adjacent package in the ecosystem. |
| `swift-github-http` | 56 | 2,115 | 15 | Real — but domain-specific (GitHub), not general HTTP. |
| `swift-http-body` | 15 | 693 | 3 | Real. |
| `swift-http-session` | 19 | 194 | 1 | Real but **10 lines/file average** — near-vacuous. |
| `swift-urlrequest-handler` | 4 | 441 | 2 | Real. **Prime N8 quarantine candidate — see §3.** |
| `swift-http-cookies` | 7 | 201 | 1 | Thin. |
| `swift-http-redirect` | 3 | 148 | 1 | Thin. |
| `swift-http-host` | 4 | 108 | 1 | Thin. |
| `swift-uri` | 1 | **12** | 1 | Gutted on 2026-07-24 — see §1.5. |
| `swift-http` | — | — | — | **SCAFFOLD** ← the obvious N8/aggregate name, and it is empty |
| `swift-http2`, `swift-http3` | — | — | — | **SCAFFOLD** |
| `swift-http-compression` | — | — | — | **SCAFFOLD** |
| `swift-http-content-negotiation` | — | — | — | **SCAFFOLD** |
| `swift-http-cors`, `swift-http-etag` | — | — | — | **SCAFFOLD** |
| `swift-http-range`, `swift-http-routing` | — | — | — | **SCAFFOLD** |
| `swift-transport-layer-security` | — | — | — | **SCAFFOLD** (N6's landing site) |

**L4 — Components** (`swift-components/`)

**24 of 25 directories are scaffolds.** The only one with a `Package.swift` is
`swift-server-static`. `swift-http-cache`, `swift-http-middleware`, `swift-server`,
`swift-session`, `swift-rate-limit`, `swift-server-proxy`, `swift-server-sent-events` — all
`LICENSE.md` only. **L4 is a naming reservation, not a populated layer.** Any plan that
places N8 at L4 is placing it in an empty layer with no neighbours and no precedent.

**L5 — Applications.** `swift-applications/` contains **no
`Package.swift` at depth ≤3**; its children (`Auth`, `Gateway`, `Net`, `JSON`, …) are not
packages. `repotraffic` has exactly one git root and one package:
`repotraffic/repotraffic-com-server/`.

### 1.2 What genuinely implements vs. merely re-exports — summary

- **Implements HTTP law:** `swift-rfc-9110` (semantics), `swift-rfc-9112` (HTTP/1.1 syntax),
  `swift-rfc-9111` (caching). All at L2, all under `swift-ietf/`.
- **Re-exports only:** `swift-http-standard` (35 lines).
- **Implements HTTP *policy/transport*, at L3:** `swift-url-routing`, `swift-http-body`,
  `swift-urlrequest-handler`, `swift-github-http`.
- **Reserved but empty:** the entire `swift-http-*` L3 family bar four, all of L4, both
  HTTP/2 and HTTP/3.

### 1.3 ⚠️ The `Method` corpus incident — the brief's account is wrong on cause

The brief states: *"HTTP Standard's `Method` is live and load-bearing: a
`CustomStringConvertible` change on it silently invalidated recorded corpora in three
packages today."* **The effect is real and the count of three is right. Both attributions are
wrong, and the correction matters more than the original claim.**

**What is actually true, with evidence:**

1. `Method` is **not** declared in HTTP Standard. It is
   `swift-ietf/swift-rfc-9110/Sources/RFC 9110/HTTP.Method.swift:32`,
   as `RFC_9110.Method`. HTTP Standard only aliases it (`HTTP.swift:20`).
2. The `CustomStringConvertible` conformance is at `HTTP.Method.swift:214-218`. `git log -S`
   dates it to **`bba4de9`, 2025-11-16, "feat: initial implementation of RFC 9110"**. It is
   **eight months old**.
3. `swift-rfc-9110` has **no commit on 2026-07-24 at all**. Its HEAD last moved
   **2026-07-10** (`7f79077`). **Nothing changed on `Method` today.**
4. The three packages that re-recorded are confirmed:
   - `swift-foundations/swift-authentication` `dd15c63` — 6 corpus files, 129 lines each way
   - `swift-standards/swift-stripe-types` `45a0bb3` — 2 fixtures
   - `swift-foundations/swift-identities-types` — per ledger `0d05df33`, "64/64 matches
     pre-clearance, method-only"
5. The diff is uniformly
   `- method: Method(rawValue: "POST", isSafe: false, isIdempotent: false, isCacheable: true)`
   → `+ method: POST`. That is the **default reflection dump giving way to a
   `CustomStringConvertible` that was already there** — the consumers had been compiling
   against an *older resolved* `swift-rfc-9110`.
6. Resolution is by **local mirror**: the user-level SwiftPM `configuration/mirrors.json` (1,256 entries)
   maps `https://github.com/swift-ietf/swift-rfc-9110` → the local working directory
   `swift-ietf/swift-rfc-9110`. **None of the three consumers has a
   package-scoped `mirrors.json`**, so the global map is in force for all of them.

**Correct causal account:** this was **not a source change. It was a resolution-front
movement.** Stale pins advanced onto an eight-month-old L2 conformance, and three corpora
that had recorded the pre-advance rendering went red hours apart. (BOARD closed item 2 is
"swift-favicon **pin refresh** + re-gate"; the ledger records "stale-pin masking methodology
finding, 3rd occurrence".)

**Why this is the single most important operational fact in this packet:**

> Every HTTP consumer in the ecosystem resolves the L2 HTTP law at the **local repository's
> committed HEAD**, with **no version gate whatsoever**. A commit in `swift-rfc-9110` or
> `swift-rfc-9112` is not released — it is *already live* for every consumer at their next
> resolve. And ecosystem pins are known-stale (BOARD #8 is an open staleness sweep), so the
> blast radius of an N7 edit is **deferred and invisible**, landing on each consumer whenever
> that consumer's pin next happens to move.

N7 modifies exactly these two packages. **The plan in §5 is built around this constraint**,
and it is why every step there carries a consumer-corpus gate rather than only a package gate.

### 1.3a Stated explicitly, as the Lead directed — and the corrected version is worse

The Lead (2026-07-24) directed: *"Anything you propose that touches `Method`'s rendering is a
fixture-invalidating ecosystem event. Say so explicitly in the packet."*

**Stated explicitly, and endorsed without reservation:**

> **Any change to `RFC_9110.Method`'s rendering — its `CustomStringConvertible.description`,
> its `LosslessStringConvertible`/`ExpressibleByStringLiteral` round-trip, or its
> `Codable` encoding — is a fixture-invalidating ecosystem event.** It silently invalidates
> every recorded corpus that interpolates a `Method`, across every consuming package, with no
> compile error and no test failure until each consumer's corpus is next executed. At least
> three packages hold such corpora today: `swift-authentication` (6 files, 129 lines each
> way), `swift-stripe-types` (2 fixtures), `swift-identities-types` (64 fixtures).
> **No N7 proposal may touch `Method`'s rendering without a pre-declared, all-consumer
> corpus re-record plan.**

**But the mechanism in the standing account is wrong, and correcting it strengthens the
warning rather than weakening it.** Per the evidence in §1.3: the conformance is eight months
old, `swift-rfc-9110` had no commit on 2026-07-24, and the trigger was **stale pins advancing**
onto law that had been at HEAD since 2025-11-16.

The consequence of the corrected mechanism:

> **You do not have to change `Method` to detonate this.** Because consumers resolve L2 HTTP
> law at the local repository's committed HEAD with no version gate, *any* already-committed
> difference between a consumer's resolved pin and L2 HEAD is a latent, undated fixture
> invalidation — armed the moment that consumer's pin next moves, for reasons that need have
> nothing to do with HTTP. The three packages that broke today were not hit by an action; they
> were hit by **the absence of a version gate plus the passage of time.**

**Adopting the Lead's framing verbatim, because it is better than mine** (2026-07-24):

> **`CustomStringConvertible` on a spec type is load-bearing, wire-adjacent API — not a
> debugging affordance.** Anything recording or replaying HTTP binds to `description`, so
> changing it is corpus-invalidating and must be treated like changing an encoder.

That is the right generalisation and it should become a durable ecosystem rule, not an
HTTP-lane note. It extends cleanly: `RFC_9110.Method` also conforms to
`LosslessStringConvertible` (`:222`), `ExpressibleByStringLiteral` (`:241`) and `Codable`
(`:109`, `:147`) — **four** rendering/parsing surfaces on one spec type, every one of them
a fixture contract. `CaseIterable` (`:249`) is a fifth if any corpus enumerates it.

So the Lead's operational directive stands and is if anything under-stated. The change-control
discipline it implies must cover **not only edits to `Method`, but the entire delta between
each consumer's currently-resolved `swift-rfc-9110`/`9112` and those packages' HEADs** — which
today is unmeasured, and which BOARD #8 (workspace-wide pin staleness sweep) is the open item
for. **Recommend the Lead treat #8 as a prerequisite of N7 Step 4, not an unrelated chore.**

### 1.4 Duplicate HTTP/1.1 law: `swift-rfc-7230` vs `swift-rfc-9112`

`swift-rfc-7230` (1,370 lines, 6 files) implements HTTP/1.1 message syntax — **the same
subject as `swift-rfc-9112`**, from the RFC series that 9110–9112 *obsoleted* in June 2022.
Its companions `swift-rfc-7231/7232/7233/7234/7235` are 245-line and 11-line stubs.

This is a live decomposition finding in the programme's own terms and it belongs to this
lane: **six packages of obsoleted duplicate law, one of them substantial.**

#### 1.4a Census ANSWERED — disposition is (b) retirable, sequenced behind BOARD #30

The Lead assigned this decision to this lane on 2026-07-24 and required a census covering
`Tests/` as well as `Sources/`. Run, positive-controlled, and answered.

**Controls (all must be nonzero for the zeros to mean anything):** rfc-7230 self-hit **21**
files · manifests depending on `swift-rfc-9110` **8** · files naming product `"RFC 9110"`
**8**. ⚠️ My first two attempts at this census were **both invalid** — see D13/D14 in §6; the
controls are what caught them, and the uncorrected answers pointed in **opposite** directions.

**Result — exactly one apparent consumer, and it is not authoritative:**

| Consumer | Manifest dep | Source/Test refs | Status |
|---|---|---|---|
| `swift-institute/Workspace/Packages/swift-url-routing` | **Yes** — `swift-rfc-7230` + `swift-rfc-7231` (`Package.swift:33-34,75-76,100`) | **19 files** (Sources + Tests) | ⚠️ **stale duplicate checkout — BOARD #30** |
| `swift-foundations/swift-url-routing` (**canonical**) | **None** | **0** | ✅ already migrated |
| `repotraffic` `Tests/WaitingListRemote Tests/WaitingListRemoteTests.swift:19` | No | 1 — **a comment**: `// members and re-exports RFC_7231 (.post) / RFC_3986.` | stale prose, not a dependency |

**The canonical `swift-url-routing` has already migrated off the obsoleted family.** It
depends on `swift-http-standard` (`Package.swift:41`) and references `RFC_9110` in 3 files;
it names no 723x package anywhere. The only manifest still binding 7230/7231 is the
**duplicate checkout that BOARD #30 already flags** — *"a duplicate checkout shadowing the
canonical repo, 1 commit behind, reporting itself in sync."* Confirmed here: same origin URL,
HEAD `6c64489f` (2026-07-21) versus the canonical's `a9a29b2f` (2026-07-24) — **three days
stale, not one commit.**

**Disposition: (b) retirable duplicate of 9112 — but the retirement is *sequenced*, not
immediate.**

1. Resolve **BOARD #30** (remove the duplicate checkout). Until then a live manifest edge to
   7230/7231 exists on disk and a retirement would break a resolvable graph.
2. Re-run this census. With #30 gone, expected live consumers = **zero**.
3. Retire `swift-rfc-7230` and the five stubs, or archive with a redirect note to 9110/9112.

#### 1.4b BOARD #30's premise was wrong — retirement unblocked, but it is NOT one action

**#30 dissolved rather than resolved.** The control-plane lane established that
`swift-institute/Workspace/Packages/swift-url-routing` is **gitignored** (`.gitignore:4`, zero
tracked files), **inert** (no manifest references it; all 18 global mirror entries resolve to
the canonical `swift-foundations` path), and **declared** in `Workspace.json` with
`"scope": "proof"` — not a stray. Its generalisation is worth keeping:
***a `Package.swift` sitting in a gitignored scratch clone is not a dependency edge.***

So its 5 references to `swift-rfc-7230/7231` are **a stale clone's text, not a live edge**,
and my pre-#30 / post-#30 framing collapses: **there was only ever the post-#30 state.** Zero
external consumers is now confirmed three independent ways — my source census, the census
lane's manifest census on the widened population, and the control-plane lane's source-side
sweep positive-controlled against the `@_exported` chains.

**⚠️ But "retire six packages" is four coupled actions, two outward-facing. Measured:**

| Fact | Value | Consequence |
|---|---|---|
| `swift-rfc-7230`, `swift-rfc-7231` | **PUBLIC**, not archived | Archiving/deleting is outward-facing and effectively irreversible on repos the world can already see |
| `swift-rfc-7232/7233/7234/7235` | PRIVATE, not archived | Lower stakes |
| Mirror-map entries | **36** (6 per package) | Machine-wide. Remove repos without cleaning these → dangling entries; clean without removing → resolution breaks for anything naming those URLs |
| `institute.xcworkspace` FileRefs | **6** | Shared integration workspace; stale FileRefs break it for every lane |
| Internal edge | `swift-rfc-7230` → `swift-rfc-7231` (`Package.swift:23,31`) | They must retire together, or in order |

**Only the first action is what "~1,650 lines" measures.** The decomposition benefit needs all
four.

**This lane is not choosing the mechanism.** `BOARD.md:20` reserves *"archival and destructive
ops"* for explicit approval; two of the six are **PUBLIC**; and the mirror-map and workspace
edits are **machine-wide state with seven lanes live**. Recommendation put to the Lead:
**archive rather than delete** — 1,370 lines of real RFC 7230 implementation exist nowhere
else — sequence mirror-map and workspace cleanup **before** any repo state change, and
approve the two public repos specifically rather than "six packages" collectively.

**This is a genuinely clean decomposition win — six packages, ~1,650 lines of obsoleted law —
and it is blocked on one duplicate-checkout cleanup, not on any HTTP work.** It can proceed
independently of G0.

**Salvage question CLOSED NEGATIVE.** I had asked whether `swift-rfc-7230` might hold a
*working* byte-level line parse predating the Foundation strip — which would have been the
cheapest possible source for the `[Byte]` path Finding F leaves empty. The inventory lane ran
it, positive-controlled against 7230's own sources: **7230 has no byte-level parse entry point
at all.** Across its six source files `[Byte]` appears **only as a `body` payload type**.
**No lines move from rewrite to retain. Retire on the existing schedule and spend no further
time on it.**

The census lane independently reached the same disposition from the other side (its
zero-consumer set contains 7230 and 7235 but **not** 9110/9111/9112/`swift-http-standard`,
which all have consumers) — so the live law and the dead law are cleanly separated in two
independent datasets.

⚠️ **Do not shortcut step 1.** The `Tests/`-inclusive requirement earned its keep here: 7 of
the 19 consuming files are test files, and a `Sources/`-only census would have under-reported
the duplicate's binding by more than a third.

### 1.5 `swift-uri` was gutted today — an in-flight L3→L2 law migration

`swift-foundations/swift-uri` is down to **1 file / 12 lines**. Today's commits:

- `ba7cd73` — "Remove URI canonicalization; **the law now lives in swift-uri-standard (L2)**"
- `5f780d6` — "Assert `canonical(host:)` is reachable through the `URI_Standard` re-export"

**This is the exact move N7 contemplates, executed this week on the neighbouring package**:
law demoted from an L3 Foundations package into an L2 Standard, with the L3 package surviving
as a re-export seam. It is the closest available precedent and the lane should read
`swift-uri-standard`'s shape before designing N7's. Note also `a246401` in
`swift-uri-standard`: *"Fit canonicalization test signatures to the **L2 100-column format
budget**"* — a live instance of the BOARD's standing rule that cross-package moves change the
lint budget and neither build nor test can see it.

### 1.5a Inventory-lane findings that change this packet's plan

The inventory lane's §3 is DONE on disk at
`Research/rfc-9110-9112-law-inventory-2026-07-24.md`. Not duplicated here; two of its five
findings change **this** document and are recorded for that reason.

- **Finding A `[WRONG DISPOSITION]` — `MessageBodyLength.calculate` detects invalid
  Content-Length (multiple differing values; unparseable/negative) and returns `.none` for
  each — the same value as a legitimately body-less message.** RFC 9112 §6.3 Rule 5 makes
  invalid CL an unrecoverable error. So invalid framing is reported as *valid, empty body*
  and the trailing bytes become "the next message". **That is the Content-Length desync
  primitive, reached through the very clause meant to prevent it.** Root cause is type-level:
  the enum has no case for invalid framing and `calculate` is non-throwing, so bad input has
  nowhere to go but `.none`.
- **Finding B `[MISSING CHECK]` — chunked-not-final is undetected, and the correct predicate
  already ships unused.** `calculate` gates on membership (`encodings.contains { $0.isChunked }`,
  `:189`) so `Transfer-Encoding: chunked, gzip` frames as chunked. The finality-aware
  accessor sits **in the same file at `:198-200`**, documented as *"Returns true if chunked is
  the final encoding … MUST be the final encoding when present"* — right predicate beside the
  wrong one, uncalled. Request/response dispositions also differ (400+close vs
  read-until-close), so one shared path cannot be correct for both.

**Consequences for this packet:**

1. **Finding A is API-breaking to fix** (the enum gains a case; `calculate` becomes throwing).
   Per §1.3 that lands ecosystem-wide at each consumer's next resolve with no version gate.
   **It therefore belongs in §5 Step 4 and inherits Step 4's consumer-corpus gate** — it must
   not be done as a quiet correctness patch.
2. **Finding B is the cheapest real security win in the arc** — a call-site change to an
   already-shipped, already-documented predicate. It is a candidate for sequencing *ahead* of
   the Step 4 redesign, since it is narrow and does not change any type.
3. Both are **security findings, not conformance nits.** §5 Steps 3–4 should be gated against
   them explicitly rather than against RFC section coverage alone.

The lane also confirmed §1.0's `Deserializer.swift:119` as `[STRUCTURAL]` with a sharper
diagnosis than mine: `bytesConsumed += chunkedData.count` uses **decoded** size for
**consumed** size, and decoded ≠ consumed because chunked adds size lines, CRLFs, the zero
chunk and trailers — so after a chunked message the deserializer's idea of where the next
message begins is wrong. Same desync primitive as Finding A, from the chunked side.

Its fifth point is worth carrying into the N7 design: a whole-buffer parser **has already
accepted the bytes before it can object to a limit**, so bounded field/line/body limits are a
**DoS surface**, not merely a conformance gap.

### 1.5b ⚠️ FINDING F — two public entry points are `fatalError` in shipped RFC 9112 source

Reported by the inventory lane; **verified here at source, then extended in two directions
that change its disposition.**

**Confirmed verbatim.** `swift-rfc-9112/Sources/RFC 9112/`:

```swift
// HTTP.Request.Line.swift:73
public static func parse(_ data: [Byte]) -> Self { fatalError("Not implemented") }

// HTTP.Response.Line.swift:85
public static func parse(_ data: [Byte]) -> Self { fatalError("Not implemented") }
```

Real bodies are present but commented out, referencing `String(data:encoding:)` — a Foundation
API removed by the Foundation strip. The signature is **total and non-throwing** (`-> Self`),
so nothing at a call site suggests the call cannot return. **The trapping overload is the
`[Byte]` one — precisely what a socket-driven parser calls**, since bytes are what arrive from
a socket.

#### Extension 1 — caller census: **zero callers.** This is a landmine, not a live crash.

Censused across `swift-foundations`, `swift-standards`, `swift-ietf`, `repotraffic`
(`.build`/`checkouts` excluded). **24 call sites of `Request.Line.parse` /
`Response.Line.parse`, and every one passes a `String`:**

- 22 in `Tests/RFC 9112 Tests/` — all string literals.
- 2 internal, in the deserializer itself: `HTTP.Message.Deserializer.swift:42`
  (`try RFC_9110.Request.Line.parse(requestLineString)`) and `:233`
  (`…parse(statusLineString)`).

(One apparent hit, `swift-diagnostics/Diagnostics.Parser.swift:46`, is an unrelated `Line`
type returning an optional. Not a consumer.)

**Disposition consequence: deleting the two `[Byte]` overloads breaks nothing.** There is no
live caller to migrate, and any future caller is currently guaranteed to crash. This upgrades
the inventory lane's "I'd delete" from a judgement call to a **no-cost** change — and it is
the only item in this packet that is both zero-risk and worth doing before anything else.

⚠️ **But it does not become urgent.** With zero callers it is **not** a live remote-DoS today;
it becomes one the moment N7's redesigned socket-driven parser calls the byte-level entry
point, which is exactly what N7 is *for*. **Correct framing: a trap laid directly across N7's
path, disarmable now at zero cost.**

#### Extension 2 — the trap census the `fatalError`-only probe missed

The inventory lane reported `swift-rfc-9110` as having **zero** such sites. That is true for
`fatalError` and **not true** for the trap family. Sweeping
`fatalError|preconditionFailure|try!|as!|.unsafelyUnwrapped` across the whole N7 chain:

| Package | Site | Assessment |
|---|---|---|
| `swift-rfc-9112` | `HTTP.Request.Line.swift:73`, `HTTP.Response.Line.swift:85` | **Finding F** — delete |
| `swift-rfc-9110` | `HTTP.Request.swift:148` — `let effectivePath = path ?? (try! RFC_3986.URI.Path("/"))` | **Low risk, real defect** — see below |
| `swift-rfc-9111` | none | ✅ clean |
| `swift-http-standard` | none | ✅ clean |
| `swift-rfc-7230` | `HTTP.Version.swift:159` — `fatalError("Invalid HTTP version literal…")` | ⚠️ **NOT the Finding F class** — see below |

⚠️ **A bare `grep fatalError` conflates two unrelated things, and my own table above did it.**
`swift-rfc-7230/HTTP.Version.swift:159` sits inside the `ExpressibleByStringLiteral`
conformance opened at `:145`. Trapping on an invalid **literal** is the conventional Swift
idiom — the compiler supplies the literal, so it is a programmer error, not attacker input.
That is categorically different from Finding F, where a **runtime `[Byte]` buffer** reaches a
trap. (Caught by the inventory lane; confirmed against my own earlier read of that file.)

**Consequence for the Step 3 audit predicate:** trap-family sweeps must be filtered by
*where the input comes from*, not just by keyword. Literal-initializer traps are expected and
should not be counted; only traps reachable from parsed or received data belong in the finding
set. Unfiltered, the predicate generates false positives that will train readers to ignore it.

#### Extension 4 — the generalisation, promoted to a Step 3 search predicate

The single cause underneath Findings A and F, and the most useful output of the two lanes'
exchange:

> **A total signature over a partial operation.**
>
> - Finding A — `calculate(…) -> MessageBodyLength`, non-throwing over a failable
>   operation ⇒ failure collapses into `.none`, **a valid-looking wrong answer**.
> - Finding F — `parse(_ data: [Byte]) -> Self`, non-throwing over a failable
>   operation ⇒ failure becomes **a crash**.
>
> Same cause, two symptoms. Neither is discoverable from the call site, because in both cases
> the signature promises totality.

**Step 3 should run this as a search, not read it as an explanation:** *which non-throwing,
non-`Optional` public functions in the N7 chain can actually fail?* That question would have
found A and F before either was reported, and it catches the `try!` site in the same pass.
Recorded as the audit's primary predicate ahead of RFC-section coverage, because section
coverage cannot see any of the three.

**On the 9110 site, characterised honestly rather than inflated:** it sits in a **non-throwing
public initializer** of `RFC_9110.Request`, and the argument is the constant `"/"`.
`RFC_3986.URI.Path.init(_:)` is `throws(Error)` (`RFC_3986.URI.Path.swift:280`), but `"/"` is
a valid path, so this will not trap in practice — and the source already carries
`// swiftlint:disable:next force_try`, i.e. it was a known, accepted shortcut.

**It is therefore a robustness/quality item, not a security finding, and I am not going to
dress it up as one.** It matters only because it is a crash channel in a non-throwing public
initializer in **the most-consumed package in the HTTP chain** (131 files reference
`RFC_9110`). The correct fix is a validated `static let` constructed once, not a `try!` at
each call. Filed for the Step 3 audit, not escalated.

#### Extension 3 — salvage-boundary corrections (inventory lane, accepted)

I proposed a retain/replace boundary for `swift-rfc-9112` and asked for early warning where
declarative law is entangled with the whole-buffer assumption. **Two points are, and both
move to the replace side:**

1. **`ChunkedEncoding` — grammar retainable, API not.**
   `decode(_ data: [Byte]) throws -> DecodeResult` (`:177`), and `DecodeResult` (`:80`) carries
   `data` / `chunkExtensions` / `trailers` — **no consumed count.** This is the *cause* of
   Finding D: `Deserializer.swift:119` estimates from decoded size **because the type it calls
   gives it nothing better.** So D is not local sloppiness that could be tightened in place —
   fixing it **requires changing `DecodeResult`**, which sat on my retain side. Neither of us
   had this: I had the line, the inventory lane had the reason, the cause was one level down.
   **`decode`/`DecodeResult` move to replace; the chunked grammar stays.**
2. **`Request.Line` / `Response.Line` — half-retainable.** `String` overloads are genuinely
   declarative: keep. `[Byte]` overloads are Finding F *and* conceptually framing rather than
   parsing (given raw bytes they must locate the line delimiter, which the redesigned layer
   owns). **Keep `String`, delete `[Byte]`.**

**Confirmed retainable, no entanglement:** `Version.parse(String)`,
`TransferEncoding.parse(String)`, both validators.

⚠️ One caveat carried forward: `Request.Line.validate(maxLength: 8000)` (`:91`) is a
**separate call after** parsing, operating on the re-`formatted` line — so it cannot prevent
over-long input from being accepted first. **A limit checkable only post hoc is not a limit**,
which is Finding E's DoS point in miniature and confirms it is not an isolated slip.

**Net sizing effect: the rewrite grows, but narrowly and specifically** — one result type and
two dead overloads, not a category. The large declarative surfaces survive the cut, so §1.0's
retain/replace split holds with these two amendments.

### 1.6 Answers to the inventory lane's three open verification items

Closed here because this lane had already surveyed the files; recorded so the answers survive
the message channel.

**(1) Type-level overlap between 9110 and 9112 — there is NO duplication; 9112 re-exports.**

```
swift-rfc-9112/Sources/RFC 9112/RFC_9112.swift:10   @_exported import RFC_9110
swift-rfc-9112/Sources/RFC 9112/HTTP.Host.swift:4   @_exported import RFC_3986
swift-rfc-9111/Sources/RFC 9111/RFC_9111.swift:10   @_exported import RFC_9110
```

Importing `RFC 9112` transitively yields **all of RFC 9110 and RFC 3986**; importing
`RFC 9111` yields RFC 9110. The types are re-exported, not redeclared — so no conformance
collision and no duplicate declaration. **Two consequences worth carrying:**

- `swift-http-standard`'s umbrella is **partly redundant**: `@_exported import RFC_9112`
  alone would already supply 9110. Not a defect, but the converger is thinner than it looks.
- Because these are `@_exported`, a consumer can bind to 9110 types **without naming
  `swift-rfc-9110` in its manifest**. Any consumer census on the HTTP law must therefore
  search **transitively re-exported symbols, not manifest edges** — a manifest-only census
  will under-report. This is a live trap for §1.4a-style work.

**(2) Range requests (RFC 9110 §14) — genuinely ABSENT, in all three candidate homes.**

- `swift-rfc-9110`: **no `HTTP.Range*` file.** The only `Range` matches are incidental —
  `HTTP.Precondition.swift` (`If-Range`), `HTTP.Header.Field.Name.swift` (field names),
  `HTTP.Status.swift` (206/416).
- `swift-rfc-7233` (the obsoleted Range RFC): **11 lines**, one stub file.
- `swift-foundations/swift-http-range` (L3): **empty scaffold**, `LICENSE.md` only.

**Range is a true, three-way gap** and one of the larger conformance holes in the 9110
surface. Worth a prominent entry in the inventory.

**(3) `HTTP.Cache` — not an overlap. It is an empty namespace, and it is an API trap.**

`swift-rfc-9110/Sources/RFC 9110/HTTP.Cache.swift` in full is:

```swift
extension RFC_9110 {
    /// HTTP caching types and utilities
    /// Primarily implemented in RFC 9111
    public enum Cache {}
}
```

An empty namespace with a doc comment pointing elsewhere. The actual caching law lives under
a **different** namespace — `RFC_9111.CacheControl` (`HTTP.CacheControl.swift:53`), plus
`Freshness`, `Age`, `Vary`, `Validation`, `StorageEligibility`.

⚠️ **The trap:** `HTTP` is `typealias HTTP = RFC_9110`, so a consumer writing `HTTP.Cache.…`
reaches the **empty enum** and finds nothing, while the law they want is at
`RFC_9111.CacheControl` — not reachable through the `HTTP.` alias at all. So: no duplication,
but a discoverability defect that a conformance reader will hit. Recommend the inventory flag
it as a **namespace/vocabulary defect** rather than a missing-law finding.

---

## 2. Layer placement for N7 and N8 vs `[ARCH-LAYER-001]`

### 2.0 ⚠️ This question is already answered, by a document my brief did not name

**Before arguing placement I have to report a scoping problem.** The brief gives the path of
record as "N7 (HTTP/1.1 law) → N8 (client)" and nothing else. There exists an authoritative,
line-cited record that specifies both in detail:

**`Research/native-networking-wave-3-implementation-heritage-dependency-record.md`** (894
lines), the **N1→N9 operative networking critical path**. The N6 lane's own packet
(`Research/n6-tls-engine-scoping-2026-07-23.md:14`) treats it as authority — *"The
architecture is already substantially specified by the heritage record (v1.2.0). This packet
builds on it; it does not re-decide it."*

It supersedes an earlier architecture doc
(`Research/Pure-Institute-Networking/target-package-and-layer-architecture.md`, 2026-07-16),
which the N6 packet explicitly flags as superseded. **A lane starting from the brief alone
would re-derive the layer decision and would very likely land on the superseded shape.**

Its verbatim N7/N8 entries (`:768-779`):

> 8. **N7 — HTTP/1.1 law and drive.** Add bounded incremental RFC 9112 framing, then fill
>    `swift-http` over an injected duplex. **STOP** on smuggling ambiguity, inexact consumed
>    count, post-limit append, byte loss, incorrect Host/target form, or ambiguous reuse;
>    **GO** on split-at-every-byte, 1xx/chunk/trailer/pipeline/EOF, partial IO, cancellation,
>    and terminal-disposition gates.
> 9. **N8 — L4 HTTP client.** Create `swift-components/swift-http-client`; compose absolute
>    HTTPS URI, system DNS, sockets, TLS/WebPKI, HTTP, deadlines, `Pool.Bounded`, typed
>    errors, finite bounds, the injected trust witness, and structured shutdown. **STOP** on a
>    Router/provider dependency, redirect/stream/cache/wire-DNS scope creep, lifecycle
>    authority leak, or API seam deviation; **GO** on the accepted executor contract and all
>    local deterministic gates.

**Three corrections to the brief follow immediately.**

1. **N7 is two packages at two layers, not one.** Half is L2 (`swift-rfc-9112` bounded
   incremental framing); half is **L3** (`swift-foundations/swift-http`, currently a
   scaffold — "fill `swift-http` over an injected duplex"). The brief's "N7 (HTTP/1.1 law)"
   names only the L2 half.
2. **N8's layer is already decided: L4**, `swift-components/swift-http-client`, with written
   rationale. It is not an open question.
3. **"N7 → N8" is not the dependency structure.** N8 composes **N1–N7**: sockets (N2), system
   DNS (N3), `Pool.Bounded` (N4), certificates/WebPKI (N5), TLS (N6), HTTP (N7). Reading the
   path as a two-step chain understates the prerequisite set by five phases.

### 2.1 N7-L2 — `swift-rfc-9112` stays at L2 Standards. Settled by essence.

`[ARCH-LAYER-001]`'s layer table (`Skills/swift-institute/SKILL.md:~55`) answers this
directly: **Standards = "What is specified externally?", examples "ISO 32000, RFC 3986."**
`swift-rfc-9112` *is* an externally-specified wire grammar. It is already at L2 and must not
move. No argument needed beyond the definition.

Its existing edges, tested against `[ARCH-LAYER-001]`:

| Edge | Layers | Verdict |
|---|---|---|
| `swift-rfc-9112` → `Byte Primitives` | L2 → L1 | ✅ downward |
| `swift-rfc-9112` → `Standard Library Extensions` | L2 → L1 | ✅ downward |
| `swift-rfc-9112` → `swift-rfc-9110` | **L2 → L2** | ✅ **legal same-layer** |

The same-layer edge passes all three conjuncts of `[ARCH-LAYER-001]`, and is worth spelling
out because it is the textbook case the "blanket lateral ban" misreading would have killed:

- **Essential semantic prerequisite?** Yes, definitionally. RFC 9112 *is* the HTTP/1.1
  message syntax **for the semantics defined in RFC 9110**; the IETF published them as one
  set in June 2022. 9112 cannot express its own subject without 9110's `Method`, `Status`,
  `Headers`, `Request`, `Response`. This is not reuse-for-convenience.
- **Acyclic?** Yes. `swift-rfc-9110`'s manifest does not name 9112. The edge is one-way.
- **No higher-layer policy pushed down?** Correct — 9112 sends nothing into 9110; it consumes
  9110's vocabulary.

`swift-http-standard` → {9110, 9111, 9112} are likewise L2→L2 and likewise legal: a converger
whose entire declared essence is convergence has convergence as an essential prerequisite.

### 2.2 N7-L3 — `swift-foundations/swift-http` at L3 Foundations

The record assigns it (`:167`): *"`swift-http` | L3 | Incrementally drive HTTP/1.1
request/response exchange, framing, body backpressure, reuse eligibility, and protocol
shutdown over an injected byte duplex. | Product/target `HTTP`; it depends on HTTP
Standard/RFC 9112 and IO vocabulary, **never DNS/TLS/sockets/routing**."*

This is right under `[ARCH-LAYER-001]`. L3 answers **"What can be composed safely?"** —
examples "File I/O, JSON, TLS". A protocol *drive* — a state machine over an injected
duplex — is composition over spec law, not spec law itself. It cannot be L2, because
"incrementally drive an exchange with backpressure and reuse eligibility" is nowhere in RFC
9112; that is policy the Institute chooses.

Its permitted edges are all downward (L3→L2 `HTTP Standard`/`RFC 9112`, L3→L1 IO vocabulary).
**The `never DNS/TLS/sockets/routing` clause is the load-bearing constraint** and is
precisely the "does not move higher-layer policy into the dependency" conjunct read forwards:
if `swift-http` acquired a socket edge it would stop being a drive and become a client,
duplicating N8 one layer down. The injected-duplex shape is what keeps the layer honest.

⚠️ Note the mission-drift hazard the record already flags (`:107`): `swift-http`'s current
repository metadata advertises a **"core HTTP types" mission**, which is **obsolete** — RFC
9110 and HTTP Standard own the model. **The stale mission must be corrected before the
package is filled**, or the fill will be pulled toward re-declaring types that already exist
at L2.

### 2.3 N8 — `swift-components/swift-http-client` at L4 Components

Two independent authorities agree, which is why I am not reopening it:

1. **`[ARCH-LAYER-001]`'s own table names HTTP as the L4 example.** *Components — "What is
   reusable with defaults?" — **"PDF rendering, HTTP"**.* The canonical rule text nominates
   an HTTP assembly as the archetypal Component.
2. **The heritage record's rationale** (`:170-173`, `:277-278`): *"The concrete client belongs
   in `swift-components` at L4 because it selects a reusable assembly with
   URI-to-DNS-to-socket-to-TLS/trust-to-HTTP/pool defaults. … `HTTP Client` is intentionally
   L4. Every L3 edge it crosses is the package's defining composition mission; **none may be
   smuggled into `swift-http`**."*

The `[ARCH-LAYER-001]` test for N8 is trivial in one direction and instructive in the other:

- **All of N8's edges are downward** (L4 → L3 `swift-http`, `swift-sockets`,
  `swift-transport-layer-security`, `swift-certificates*`, DNS; L4 → L2 `HTTP Standard`,
  `RFC 3986`; L4 → L1 `Pool.Bounded`). **Zero same-layer edges** — L4 has no populated
  neighbours to have edges with. So `[ARCH-LAYER-001]` is satisfied trivially.
- **The real constraint is the reverse direction**: the client is *defined* by being the only
  place allowed to hold all those edges at once. Every one of them, pushed down into L3
  `swift-http`, would be an `[ARCH-LAYER-001]` violation of the "policy pushdown" conjunct.
  **N8's layer is what protects N7's.**

### 2.3a ⚠️ N8's placement is UNDER REVIEW (principal clarification, 2026-07-24 evening)

**The §2.3 conclusion below stands as written but is not final.** Flagged rather than edited,
at the Lead's instruction.

**Principal, verbatim:** *"swift-applications and swift-components is almost entirely
aspirational from months ago. The layers are currently L1 – primitives, L2 – standards,
L3 – foundations, and then we have repotraffic and swift-institute/Workspace."*

This puts a fact under §2.3's second authority (the `[ARCH-LAYER-001]` layer table naming
"HTTP" as the Components example) — that table may describe the same aspiration as the
record. Measured: `swift-components` = 25 directories, **1** `Package.swift`;
`swift-applications` = 40 directories, **0**.

**This lane's reading, on the three questions put to it:**

**(1) Does the record argue L4 on taxonomy, or merely assign it? — Taxonomy, decisively.**

- `:173-176`: *"The concrete client belongs in `swift-components` at L4 **because** it selects
  a reusable assembly with URI-to-DNS-to-socket-to-TLS/trust-to-HTTP/pool defaults. The
  extracted DNS and certificate providers **remain L3**: an adapter between essential L3/L2
  services **does not become L4 merely because it composes packages**."*
  A criterion, then the same criterion applied **in the negative** to deny L4 to neighbouring
  packages. That is a taxonomy being reasoned with, not a label being stuck on.
- `:93` states it as general doctrine **before any package is named**: *"L3 owns one domain's
  runtime policy; **cross-domain execution composition is L4**."*
- `:277-278`: *"`HTTP Client` is **intentionally** L4. Every L3 edge it crosses is the
  package's defining composition mission; **none may be smuggled into `swift-http`**."*

**(2) Does the record acknowledge Components is unrealised? — About the package, explicitly
yes; about the layer, it never assumes otherwise.**

- `:108`: *"**No local checkout and no GitHub repository existed** on 2026-07-22. This is a
  **new L4 repository** using the roadmap's trigger name, **not a reserved-repository fill**."*
  The record knows the package does not exist and distinguishes creation from filling.
- `:95-96`, in the controlling rules: *"a **reserved repository name does not oblige the
  Institute to fill it**."* The record is explicitly aware of the aspirational-reservation
  problem ecosystem-wide.
- It then **declines to fill** two reserved names on the merits — `swift-pool-connections`
  *"Do not fill now"* (`:169`), `swift-dns-cache` *"Keep empty in slice 1"* (`:306`).
- **Its own DAG gives `HTTP Client` zero L4 peers** (`:227-233`): every edge goes to L3, L2 or
  L1. The record is therefore *consistent with* Components being empty — it never relies on an
  L4 neighbour existing.

**So this was not a placement made in ignorance of occupancy.** It reads as a placement made
with intent to realise Components, by a document that elsewhere refuses to fill reservations
it cannot justify.

**(3) Recommendation: keep N8 at L4 as recorded — and route any change to the principal.**

1. **The placement is load-bearing, not decorative.** `swift-http`'s L3 row (`:167`) says it
   depends on HTTP Standard/RFC 9112 and IO vocabulary *"**never DNS/TLS/sockets/routing**"*,
   and `:277-278` says N8's L4 siting is what keeps those edges out of it. **Move N8 to L3 and
   that exclusion stops being a layer boundary and becomes a convention between peers** —
   N8→`swift-http`, N8→sockets, N8→TLS all become same-layer edges, and the structural barrier
   against smuggling is gone.
2. **Standing up L4 costs far less here than it sounds.** N8 has **zero L4 peers by design**,
   so there is no L4 ecosystem to coordinate with — only this package's own CI/lint/README.
   And L4 is **not literally empty**: `swift-components/swift-server-static` is real
   (`Package.swift`, `Sources`, `Tests`, 10 swift files). N8 would be the **second** real L4
   package, not the first.
3. **The repotraffic precedent does not transfer, and the Lead said so first.** That ruling
   turned on not proving an extraction pattern and standing up a layer simultaneously, where
   a failure in either is indistinguishable. **N8 is not an extraction** — it is a new package
   with no extraction pattern to prove, so the confound does not arise.
4. **The cost asymmetry runs the other way from repotraffic.** "L3→L4 later is a rename; a
   wrong layer boundary is not" — and for N8, **L4 is the boundary-preserving choice.** Siting
   it at L3 *is* the wrong-boundary risk, and the later correction would not be a rename but a
   boundary restoration, re-litigated after `swift-http`'s edges may already have drifted into
   exactly what `:277-278` forbids.

⚠️ **The one thing that would change this answer, and it is the principal's to say.** The
clarification is a statement about **current occupancy**, which the record already
accommodates. If it is instead meant as a **forward-looking change to the layer model** — that
the ecosystem is henceforth L1/L2/L3 plus concrete applications, with L4 retired rather than
merely unpopulated — **that supersedes the record and N8 goes to L3.** Those are different
claims and only the principal can say which was meant. **This lane's reading is that the
record intended to realise Components and that N8 is plausibly the package meant to do it**,
so the question should be routed as a decision rather than settled by inference.

⚠️ **Caveat retained from the original analysis: L4 is a near-empty layer.** As measured in §1.1, **24 of 25**
`swift-components` directories are `LICENSE.md`-only scaffolds; only `swift-server-static`
has a `Package.swift`. `swift-http-client` would be the second populated package at L4 and
the first non-trivial one. That is not an argument against the placement — the reasoning
above is sound and doubly-sourced — but it means N8 will be **establishing** L4's conventions
(CI, lint bundle, README family, metadata) rather than following them, and the plan should
budget for that rather than discover it. Note also that `swift-components/swift-http-cache`
and `swift-http-middleware` are *reserved names at L4* whose missions will need reconciling
against N8's scope boundary (the record's STOP list already forbids cache scope creep in N8).

## 3. Foundation-freedom `[ARCH-LAYER-007]` — what N7/N8 must not import

### 3.1 Probe validity

Every count below is from `/usr/bin/grep -rn 'import Foundation' <pkg>/Sources`,
positive-controlled against the violation BOARD #24 already names —
`swift-standards/swift-github-standard/Sources/GitHub Types Shared/exports.swift:2:
@_exported import Foundation`. The probe returns that line, so a zero elsewhere is a real
zero and not a mis-anchored root.

### 3.2 N7's chain is **already Foundation-free**. This is the good news.

| Package | `Sources` | `Tests` |
|---|---|---|
| `swift-rfc-9110` | **0** | 11 |
| `swift-rfc-9112` | **0** | 2 |
| `swift-rfc-9111` | **0** | 4 |
| `swift-rfc-7230` | **0** | 0 |
| `swift-http-standard` | **0** | 0 |

N7 therefore has **no `[ARCH-LAYER-007]` debt to pay** — it only has an invariant to hold.
`swift-rfc-9112`'s declared dependencies are `Byte Primitives` (L1), `Standard Library
Extensions` (L1) and `RFC 9110` (L2) — nothing that could drag Foundation in.

**N7 must not import:** `Foundation`, `FoundationNetworking`, `FoundationEssentials`, and by
extension anything transitively exporting them. Concretely this means the parser and
serializer must keep operating on `[Byte]`/`Byte Primitives` (which they already do — see
rfc-9110 `e643720` "migrate HTTP message body to `[Byte]`" and `abffb6b` "byte-domain repair")
rather than reaching for `Data`, and must not adopt `Foundation.Date`, `URL`, `URLComponents`,
`JSONDecoder`, or `CharacterSet`. `HTTP.Date` at rfc-9110 already implements IMF-fixdate
generation and 3-format parsing natively (`31b5c3c`), so the tempting Foundation shortcut is
already closed.

⚠️ **Caveat on the test columns.** 17 test files across the N7 chain import Foundation.
`[ARCH-LAYER-007]` as written in `CLAUDE.md:43-48` binds *main targets*, so these are not
violations of the letter. But the BOARD's standing rule is **"the test target is a consumer
too"**, and a Foundation-dependent test corpus is exactly what makes a later Foundation-free
claim unverifiable on Linux/Embedded. **Recommend the Lead treat this as in-scope debt for
N7's gate, and I flag it rather than assume it.**

### 3.3 The URLSession surface is **six sites**, and only one is a true holdout

Swept across `swift-foundations`, `swift-standards`, `swift-ietf`, `swift-primitives`,
`swift-components` and `repotraffic` (`Sources` only, `.build*` excluded). Two further hits
were `.docc` markdown and are excluded as prose.

| # | Site | Status |
|---|---|---|
| 1 | `swift-foundations/swift-url-routing/Sources/`**`URL Routing Foundation Integration`**`/URLRouting.Client.swift` | ✅ **Already correctly quarantined** in a Foundation Integration target |
| 2 | `swift-foundations/swift-urlrequest-handler/Sources/URLRequestHandler/DefaultSessionKey.swift:9` | ❌ **Foundation in the core target** — 4 of its 4 source files import Foundation/FoundationNetworking, incl. `exports.swift:4: @_exported import FoundationNetworking` |
| 3 | `swift-foundations/swift-github-http/Sources/GitHub Live Shared/URLRequest.Handler.GitHub.swift` | ❌ core target |
| 4 | `swift-foundations/swift-stripe-live/Sources/Stripe Live Shared/URLRequest.Handler.Stripe.swift` | ❌ core target |
| 5 | `repotraffic/…/Sources/Syncing/Syncing.swift:147` | ❌ **`validateToken` — the named holdout** |
| 6 | `repotraffic/…/Sources/SyncingLive/Syncing.Fetch.Execution+Dependencies.swift:9` | ⚠️ the `.networkingUnavailable` stub — **no URLSession at all**, see §3.5 |

**`swift-urlrequest-handler` is the concentrated quarantine problem.** Its entire 4-file,
441-line core target is a Foundation/URLSession dependency-injection shim, and it
`@_exported import FoundationNetworking` — meaning **every consumer inherits Foundation
whether it wants it or not.** It is not a package with a Foundation leak; it is a package
whose whole purpose is the leak. §5 sequences its disposition.

### 3.4 The quarantine pattern already exists — and its known failure mode is already filed

Site 1 is the precedent: `swift-url-routing` carries a target literally named
**`URL Routing Foundation Integration`** holding the URLSession client, separate from the
core target. This is `[ARCH-LAYER-007]`'s "dedicated, opt-in Foundation Integration target",
in production, in the busiest HTTP-adjacent package in the ecosystem.

**N8's URLSession-shaped API belongs in exactly this shape**, and the lane should copy it
rather than invent one. Two live warnings attach:

- **BOARD #11** — *"Lint rule for the URL Routing FI-product omission (3 instances in one
  day)"*. The FI pattern's failure mode is **forgetting to declare the FI product** on a
  consuming target. It bit three times on 2026-07-24 alone (`swift-favicon` `38f3be2` and
  `0aee526`, `swift-stripe-types` `9be95c7`). N8 will multiply the opportunities.
- **BOARD `a75ecdbb`/#24** — Foundation-freedom is at 61 packages / 1,307 import lines
  against a tracked "4".

### 3.4a ⚠️ The `[ARCH-LAYER-007]` lint rule has a hole exactly the shape of N8's payload

A mechanical guard **does** exist — `Lint.Rule.Foundation.Import`, in
`swift-foundations/swift-institute-linter-rules/Sources/Institute Linter Rule Foundation`,
carried by `Lint.Rule.Bundle.institute`. (I initially wrote that no such rule existed; that
was wrong, and checking it produced a worse finding than the one I withdrew.)

Its predicate, at `.../Institute Linter Rule Foundation/…:82-85`:

```swift
private func foundationImportIsFoundationModule(_ pathText: Swift.String) -> Swift.Bool {
  let firstComponent = pathText.split(separator: ".").first.map(Swift.String.init) ?? pathText
  return firstComponent == "Foundation" || firstComponent == "FoundationEssentials"
}
```

**`FoundationNetworking` matches neither branch.** Its first dot-component is
`"FoundationNetworking"`, equal to neither `"Foundation"` nor `"FoundationEssentials"`.

`FoundationNetworking` is **the module that carries `URLSession` on Linux.** So a package can
write `@_exported import FoundationNetworking` — re-exporting URLSession to every
consumer — and pass the ecosystem's Foundation-freedom lint clean. That is not a hypothetical:
`swift-urlrequest-handler/Sources/URLRequestHandler/exports.swift:4` is exactly that line, in
a package whose `Lint.swift` activates `Lint.Rule.Bundle.institute` with **no exclusions**.

Two distinct defects fall out, and they should be filed separately:

1. **Rule gap** — the predicate should also match `FoundationNetworking` (and plausibly
   `FoundationXML`, `FoundationNetworking.*` submodules). Until it does, the guard is blind on
   precisely the axis N8 travels.
2. **Enforcement gap** — the same package's `DefaultSessionKey.swift:9`,
   `DefaultRequestHandlerKey.swift:2` and `Envelope.swift:1` are *bare* `import Foundation`,
   which the rule **does** match, in a package that activates the bundle with no exclusions.
   So either its lint is not being run, or it is red and unattended. **This needs a lint run
   to distinguish — which is a gate, and I am not running one in Phase 1 without the Lead's
   go-ahead.** Flagged as §5 step 0.

### 3.4b ⚠️ CORRECTION TO MY OWN CLAIM — the hole is real but is NOT the mechanism behind #24

I originally wrote that §3.4a was *"the concrete mechanism behind BOARD #24's 61 packages /
1,307 lines against a tracked 4."* **That was an overclaim and the layering-census lane
refuted it with a measurement I did not have.** Its module split across all **1,334**
core-target Foundation-family import lines ecosystem-wide:

| Module | Lines | Share | Rule matches it? |
|---|---|---|---|
| `Foundation` | 1,283 | **96.2%** | ✅ yes |
| `FoundationNetworking` | 48 | 3.6% | ❌ **no — the hole** |
| `FoundationEssentials` | 3 | 0.2% | ✅ yes |
| `FoundationXML` | 0 | 0% | ❌ no |

**The hole explains 3.6%, not the magnitude.** 96.2% of the violation mass is plain
`Foundation`, which the rule matches correctly. My hypothesis is withdrawn: a guard-blindness
story cannot account for a 1,334-vs-4 gap when the guard sees 96% of it.

The correction sharpens the question rather than closing it — and Step 0 answered it.

### 3.4c STEP 0 RESULT — the guard **runs**, is **red**, is **unattended**, and is **blind**

Run 2026-07-24 through the coordinator, one slot (2 available, 0 occupied; no `.build`
contention — the only live processes were Raycast, not SwiftPM):

```
swift-build lint --package-path swift-foundations/swift-urlrequest-handler
```

**Exit status (bare `$?`): 0.** Per the standing rule that an exit status is a claim until
the log is read, the evidence the run actually happened:

```
· 92 active rules · 8 files linted · 72 violations
```

with findings citing real files (`DefaultRequestHandlerKey.swift` ×36,
`URLRequestHandler Tests.swift` ×13, `DefaultSessionKey.swift` ×10, …). **It ran.**

**Foundation-import findings: 5** — 3 in `Sources`, 2 in `Tests`:

| Site | Fired? |
|---|---|
| `Sources/URLRequestHandler/DefaultRequestHandlerKey.swift:2` `import Foundation` | ✅ |
| `Sources/URLRequestHandler/DefaultSessionKey.swift:9` `import Foundation` | ✅ |
| `Sources/URLRequestHandler/Envelope.swift:1` `import Foundation` | ✅ |
| `Tests/…/ReadmeVerificationTests.swift:2` | ✅ |
| `Tests/…/URLRequestHandler Tests.swift:2` | ✅ |
| `Sources/URLRequestHandler/DefaultSessionKey.swift:12` `import FoundationNetworking` | ❌ **silent** |
| `Sources/URLRequestHandler/DefaultRequestHandlerKey.swift:7` `import FoundationNetworking` | ❌ **silent** |
| `Sources/URLRequestHandler/exports.swift:4` `@_exported import FoundationNetworking` | ❌ **silent** |

**The census lane pre-registered a prediction — 3 core-target findings if the rule runs as
written — and it is exactly right.** (5 total; the extra 2 are test files, which its
core-target census scope excludes by design. No disagreement.)

**The hole is now demonstrated at line granularity inside a single file.**
`DefaultSessionKey.swift` line **9** (`import Foundation`) fires; line **12**
(`import FoundationNetworking`) does not. Same file, same import family, 3 lines apart.
And `exports.swift` — whose entire content is two imports, one of them
`@_exported import FoundationNetworking` — **produced zero findings and does not appear in
the linted-file findings at all.**

**Four conclusions, all now measured rather than inferred:**

1. The lint **is running.** Not-running is eliminated.
2. It is **red** — 5 Foundation findings, 72 violations total.
3. It **does not bind**: severity is `default: .warning`
   (`Lint.Rule.Foundation.Import.swift:22`), so **exit status is 0 with 72 violations
   outstanding.** Red-and-unattended is the steady state, not an anomaly. Nothing escalates
   it to `error`.
4. It is **blind to `FoundationNetworking`**, confirmed end-to-end.

**What this means for N7/N8:** Foundation-freedom **cannot be asserted from a green lint** —
a package can be lint-green at exit 0 while importing Foundation on five lines, and can
`@_exported import FoundationNetworking` with no finding at all. Every Foundation-freedom
claim in this arc must come from a direct positive-controlled `grep` over the Foundation
*family*, as §3.1/§3.2 do. **The N7 chain's zeros stand** — they were measured that way, not
read off a lint.

**Secondary defect confirmed at source** (found by the census lane, verified here): the
diagnostic text at `Lint.Rule.Foundation.Import.swift:37` reads *"[PRIM-FOUND-001]:
primitives source MUST NOT import…"* while the rule ships at institute tier for all five
layers under `[ARCH-LAYER-007]`. An L3 or L4 engineer who trips it is told it is a primitives
rule about a layer they are not in — which invites dismissal. Step 1 should fix the message
alongside the predicate.

### 3.5 Where N8's contract already is — the seam is cut and typed

The brief calls `Syncing.Fetch.Execution.liveValue` a "deliberate `.networkingUnavailable`
stub" and rules it ACCEPT-NOT-WORKING. Reading it confirms that and shows something more
useful. `Sources/SyncingLive/Syncing.Fetch.Execution+Dependencies.swift:7-10`:

```swift
package static let liveValue = Self {
    (_: HTTP.Request) async throws(Syncing.Fetch.Execution.Error) -> HTTP.Response in
    throw .networkingUnavailable
}
```

Tracing `HTTP` through the imports: the file imports `GitHub_HTTP`, whose
`Sources/GitHub HTTP/exports.swift:2` is `@_exported public import HTTP_Standard`, whose
`HTTP.swift:20` is `public typealias HTTP = RFC_9110`. So this stub's type is exactly:

```
(RFC_9110.Request) async throws(Error) -> RFC_9110.Response
```

— `RFC_9110.Request` at `HTTP.Request.swift:62`, `RFC_9110.Response` at
`HTTP.Response.swift:57`.

**N8's entire obligation at this site is to supply one honest value for one already-declared
function type, written in L2 spec vocabulary, with typed throws already in place.** There is
no API design to do here and no consumer to migrate. It is the cleanest possible landing
site, and it confirms the brief's framing: this stub is the arc's destination, not a defect.

**`validateToken` is the opposite shape and is the harder of the two.**
`Sources/Syncing/Syncing.swift:140-174` is raw and unabstracted: `URLRequest` +
`URL(string:)!` **force-unwrap** (line 142), `URLSession.shared.data(for:)` (line 147),
`HTTPURLResponse` downcast, a local `JSONDecoder` with `.convertFromSnakeCase`, a nested
`GitHubUser: Decodable`, and `allHeaderFields["X-OAuth-Scopes"]` string-splitting. It has
**no dependency seam at all** — no `Dependency.Key`, no injected execution. Migrating it is
three separable changes (introduce a seam · move to `RFC_9110` types · replace the JSON
decode), and it additionally carries a `!` force-unwrap on a literal URL that will need to
become a typed `RFC_3986.URI`. Three of its four callers are already known
(`SyncingLive/Syncing.Token+Live.swift:24`, `AccountLive/Account.GitHub+Live.swift:46`,
plus the comment reference at `SyncingLive/Syncing+Composable+Live.swift:21`).

## 4. Build vs. adopt, and the ancestry question

Assessed with the `swift-package-heritage` skill, as the brief directs.

### 4.1 Verdict: **BUILD. `[HERITAGE-001]` does not fire for any part of N7 or N8.**

`[HERITAGE-001]` fires **iff all four** conditions hold: material lineage · community/consumer
overlap · license compatibility · upstream is non-owned. Applied to each candidate:

| Candidate upstream | Material lineage? | Verdict |
|---|---|---|
| `apple/swift-http-api-proposal` | **No** — concept/pattern level only | `[HERITAGE-006]` independent |
| `apple/swift-nio` (+ NIO HTTP1) | **No** — and its presence is disqualifying, see §4.3 | independent |
| `swift-server/async-http-client` | **No** — not present in the workspace at all | independent |
| `curl` (`swiftlang/curl` checkout) | **No** — C, not a Swift package family | independent |
| `coenttb/swift-http`, `coenttb/swift-tls` | **Out of scope**, and no longer on disk | n/a |

**The heritage record already ruled this, and my independent application of the skill agrees**
(`native-networking-…-record.md:308`):

> `swift-components/swift-http-client` and independent integration packages | **Create only
> after review as independent Institute implementations. No prior repository or external
> source lineage exists.**

and for the N7 half (`:305`):

> Empty `swift-http`, `swift-transport-layer-security`, `swift-domain-name-system`
> reservations | **Fill in place from new Institute-authored implementations** after review;
> update stale repository missions first. **No claim of inherited source.**

So both N7 halves and N8 are **orphan publication, no shared git ancestry, no fork badge**,
with attribution — if any — in the `[HERITAGE-006]` independent shape: README "Related
Packages"/"inspired by" bullet, Apache-2.0-only LICENSE with **no** upstream license text
(because no derivative-works claim is made), and a `Research/comparative-analysis-*.md`
framed as *comparison*, not *fork rationale*.

`swift-rfc-9112` needs no heritage assessment at all: it is an existing Institute-authored L2
package being improved in place — the record's *"Improve in place with ordinary Institute
history. No source transfer."* disposition (`:304`).

### 4.2 The one real ancestry hazard, flagged as the brief asks

**`apple/swift-http-api-proposal` is the live risk**, because it is Apache-2.0 (compatible),
architecturally close to what N7/N8 want, **and physically checked out at
`apple/swift-http-api-proposal`.** Four Research notes already mine it
for patterns (`Research/apple-http-{api-proposal-patterns,middleware-chain-isolation,
outputspan-writer-pattern,withclient-scoped-pattern}.md`), and the heritage record devotes a
full Adopt/Adapt/Reject table to it (`:685-710`).

Its disposition is unambiguous (`:317`):

> `apple/swift-http-api-proposal` | **Comparative prior art only: no dependency, copied
> source, compatibility target, or reconstructed history.**

`[HERITAGE-001]` confirms this independently. **Material lineage fails**: the record's own
table adopts *separations and ownership disciplines* — semantic/execution split, move-only
`~Copyable` leases, explicit region transfer, scoped drain-before-cleanup — while explicitly
**rejecting** upstream's concrete shapes (the `nonisolated(unsafe)` test bridge; helpers that
discard surplus or bounds-check after append). That is `[HERITAGE-006]`'s "we read it and got
an idea" case, which the skill names as **concept-level, not implementation-level** and for
which "the fork badge would imply implementation derivation". Institute semantics stay
`HTTP Standard`/`RFC 9110`.

⚠️ **A concrete trap for whoever executes this.** The local checkout is **not** the tree the
record reviewed:

- Record's line-citations are all against `10db597e0adaeba2b84fd23688cd1b02d7644793`
  (authored 2026-07-21).
- `git cat-file -t 10db597e…` in the local checkout: **`could not get object info`** — the
  commit **is not present locally**.
- Local working branch HEAD is `8636308` (2026-04-01); `git status -sb` reports
  **`main…origin/main [behind 22]`**, and local `origin/main` is at 2026-07-02.

**Every line-number citation in the record's Adopt/Adapt/Reject table is unverifiable from
the local checkout**, and a lane re-reading prior art locally would read a ~4-month-older
tree while believing it matched the record. Anyone re-reviewing must fetch first and pin the
exact SHA. Filed in §6.

### 4.3 Adopting NIO/AHC would defeat the programme's stated goal

Worth stating plainly since "adopt" is on the table. The N6 packet records the top goal
(`n6-tls-engine-scoping-2026-07-23.md:~30`):

> RepoTraffic on a Foundation-free, Institute-native networking stack proven by **release
> purity** (**no Vapor/URLSession/PostgresNIO/NIO/BoringSSL in shipped products/manifest/
> lockfile**).

`swift-nio` is a declared dependency of exactly three in-scope manifests —
`swift-server-foundation`, `swift-server-foundation-vapor`, `swift-server-vapor` — and of
`repotraffic-com-server/Package.swift:166`. **Adopting NIO for N8 would make the release-purity
criterion unreachable by construction.** Build is not merely preferred here; adopt is
excluded by the goal.

### 4.4 What is genuinely *adopted*, and it is already settled

One real adopt decision exists on this path and it belongs to N6, not N7/N8:
**`apple/swift-crypto` used directly at an official version as a sanctioned backend — not
forked** (`:318`, N6 packet `:~20`). `[HERITAGE-001]` does not fire because there is no
derivation at all: it is a dependency. N7 and N8 inherit nothing from this decision except
the precedent that *direct sanctioned dependency* is a legitimate third option beside
fork-heritage and re-implementation.

⚠️ Unresolved and inherited: the N6 packet flags a **swift-crypto version reconciliation**
open item (three sources cite 3.12.5 / 4.3.0 / 4.5.0; mirrors are shallow depth-1 matching
**no** reviewed pin). That is BOARD #16 and is N6's to close at its G0 audit, but N8 sits
downstream of it and should not assume it is settled.

## 5. Sequenced plan with a gate per step

### 5.0 Two blockers that sit above every step below

Neither is mine to clear. Both must be resolved by the Lead/Principal **before any source
mutation**, and I record them first so they are not discovered mid-flight.

- **G0 has not been released.** The heritage record's phase 1 is an
  architecture/repository gate, and it states plainly (`:893`): *"**No mutation is safe until
  the lead releases G0**; the first released runtime milestone will be the existing
  `Event.Actor` lifecycle repair, followed by event-backed sockets."* G0 requires re-review of
  the record, separate authorization for any new repository, and a refreshed upstream/identity
  collision audit.
- **N8 is formally blocked on a verbatim four-criterion confirmation.** Record `:281-283`:
  *"It remains provisional and **N5/N8 remain blocked until the user confirms all four
  [PLAT-ARCH-008a] criteria verbatim**"* — (a) Certificates is domain authority for
  trust-provider selection; (b) only typed Institute modules imported, never platform C;
  (c) the conditional selects trust domain strategy, not a syscall; (d) pushing it into
  Kernel would contaminate Kernel with certificate semantics. **This is a principal decision
  and it gates N8 outright.**

⚠️ **The brief's premise needs adjusting here.** It says the Fable-gate removal "is what
unblocked this critical path." The Fable design-authority gate is indeed gone, but **N8
remains blocked by `[PLAT-ARCH-008a]` and everything remains blocked by G0.** Removing the
Fable gate unblocked *scoping and design*; it did not unblock *execution*. I would not want
the Lead to report #32 as executable on the strength of that removal alone.

### 5.0a G0 release criteria — verbatim, with this lane's assessment

Requested by the Lead 2026-07-24: *"Send me G0's release criteria verbatim from the record,
with line citations, plus your assessment of which are met, which are not, and which are
unmeasurable right now."*

**Verbatim, `native-networking-wave-3-implementation-heritage-dependency-record.md:725-730`:**

> 1. **G0 — architecture/repository gate.** Re-review this record, then separately
>    authorize any new repository, reservation rename, fork, or publication. Refresh
>    official upstream points and audit the complete Apple Crypto resolved graph for
>    every local/remote SwiftPM identity collision, including `swift-asn1`.
>    **STOP** on an unapproved operation, unresolved identity/consumer/redirect, or
>    ancestry shape; **GO** only with line-cited lead approval.

Reinforced at `:892`: *"No mutation is safe until the lead releases G0."*

**Decomposed into six discrete criteria:**

| # | Criterion | Status | Whose |
|---|---|---|---|
| G0-1 | Re-review this record | ⬜ **Lead action — cannot self-assess** | Lead |
| G0-2 | Separately authorize any new repository / reservation rename / fork / publication | ❌ **NOT MET** | Lead + principal |
| G0-3 | Refresh official upstream points | ❌ **NOT MET — measured** | mine (partly) |
| G0-4 | Audit complete Apple Crypto resolved graph for every local/remote SwiftPM identity collision, incl. `swift-asn1` | ⬛ **UNMEASURABLE BY THIS LANE** | N5/N6 |
| G0-5 | No unresolved identity / consumer / **redirect** | ❌ **NOT MET — a named STOP is live** | N5 |
| G0-6 | Line-cited lead approval | ⬜ pending, and is the output of G0-1..5 | Lead |

**Detail on what I can actually evidence:**

- **G0-2 — NOT MET.** N8 requires creating `swift-components/swift-http-client`. The record
  is explicit that this is *"a new L4 repository using the roadmap's trigger name, **not a
  reserved-repository fill**"* (`:108`) and that it must be *"create[d] only after review as
  [an] independent Institute implementation[]"* (`:308`). BOARD's 2026-07-24 ruling grants
  repository creation **in principle**; G0-2 additionally requires **separate, per-repository
  authorization**. That authorization does not exist for `swift-http-client`. **This is the
  cleanest single blocker on N8 and it is a one-decision fix.**
- **G0-3 — NOT MET, with measurement.** Two upstream points are stale:
  - `apple/swift-http-api-proposal`: the record's cited commit `10db597e…` is **absent from
    the local checkout** (`git cat-file -t` → *could not get object info*), branch is **22
    behind**, local HEAD 2026-04-01 vs cited 2026-07-21. Every line-citation in the record's
    Adopt/Adapt/Reject table is currently unverifiable. (§4.2, D6.)
  - `apple/swift-crypto`: three sources cite **3.12.5 / 4.3.0 / 4.5.0**, mirrors are shallow
    depth-1 matching **no** reviewed pin (N6 packet; BOARD #16). Not mine to close, but it is
    squarely a G0-3 item.
- **G0-5 — NOT MET.** *"Unresolved … redirect"* is a named STOP condition, and BOARD #20 is a
  live redirect hazard: `swift-foundations/swift-certificates` **redirects by GitHub rename**
  to `swift-certificates-reservation-2026` (PUBLIC), and #20 is marked **IN FLIGHT** with
  *"Successor: verify the push landed."* **G0 cannot be released while #20 is unresolved**,
  because #20 *is* an instance of a G0 STOP condition. I am not adjudicating #20 — it belongs
  to the certificates lane — only observing that G0-5 depends on it.
- **G0-4 — UNMEASURABLE BY THIS LANE.** The Apple Crypto resolved graph and `swift-asn1`
  identity collisions belong to N5/N6. ⚠️ One structural note the audit will need from my
  side: the user-level SwiftPM mirror map has **1,256 entries** redirecting GitHub URLs to
  local working directories, and per BOARD's standing rule **mirror target *spelling* changes
  the resolved `PackageReference.Kind`** (bare path → `localSourceControl`; `file:///…` for
  the *same* directory → `remoteSourceControl`). So a collision audit that infers locality
  from `Kind` alone is unsound and must read the location too. That map is also the mechanism
  behind §1.3's no-version-gate finding.

**This lane's recommendation:** G0's blocking set is **not** in HTTP. It is (G0-2) one
authorization decision, (G0-3) two upstream refreshes, and (G0-5) the certificates redirect —
none of which N7 work can advance. **Steps 0–2 correctly sit outside G0** (read-only,
lint-rule, documentation), which is why they were sequenced there. **Steps 3–8 should not
start until G0-2/3/5 close**, and G0-4 needs an owner named who is not this lane.

### 5.1 Coordinator discipline binding every gate below

- **2 slots, lanes serialized.** No step below runs a gate without the Lead's explicit
  go-ahead; I have run none in Phase 1.
- **Syntax:** `swift-build package --package-path <p> <subcommand>` — **flag before
  subcommand**.
- ⚠️ **SwiftPM takes an exclusive `.build` lock and waits *indefinitely*.** If a gate hangs
  rather than fails, that is the first suspect, not the compiler. Cost 1,002 seconds of a
  2-slot coordinator on 2026-07-24. **Never gate a package while anything else touches its
  `.build`** — including an editor, an index build, or a second lane.
- **Toolchain: Xcode's bundled toolchain. No `TOOLCHAINS`.** No document consulted for this
  packet instructs otherwise; see §6.
- ⚠️ **`exit 0` is not evidence of compilation.** Confirm a `Compiling <Module>` line and a
  plausible module count in the log before reading any zero as a pass. The ssf lane received
  `exit 0` on a build on 2026-07-24 and **refused to count it** — `[0/2]` tasks, no
  `Compiling` line, a warm cache inherited from an archived session. Per the Lead
  (2026-07-24), this is **the single most repeated failure in this workspace's record**.
  Every gate in §5.2 is subject to it: report the module count, not the exit status.
- **Lint is a gate, not a nicety.** Every step that moves a file across a package boundary
  must lint **both** the losing and the gaining package — `.swift-format` column budgets
  differ per repo and **neither build nor test can see the difference**. Live proof from
  today: `swift-uri-standard` `a246401`, *"Fit canonicalization test signatures to the L2
  100-column format budget."*

### 5.2 The step sequence

Steps 0–2 are safe to run before G0 (read-only or documentation-only). **Steps 3 onward
require G0 released.**

---

**Step 0 — Establish whether the Foundation lint is actually binding.** *(pre-G0, cheap,
highest information-per-second in the plan)*

Run lint on `swift-urlrequest-handler` and on the N7 chain. §3.4a shows a package that
activates `Lint.Rule.Bundle.institute` with no exclusions while containing three bare
`import Foundation` lines the rule *does* match. Either the lint is not running or it is red
and unattended — and which one it is changes how much N7/N8 can rely on the guard.

> **Gate:** lint runs to completion on `swift-urlrequest-handler` and the exit status is
> captured directly (bare `$?` — **not** `${PIPESTATUS[0]}`, which is empty in zsh). Report
> the finding count, not "clean". A zero here is only evidence if the log shows the rule set
> loaded.

---

**Step 1 — Close the `FoundationNetworking` hole in `Lint.Rule.Foundation.Import`.** *(pre-G0)*

Extend the predicate at `Institute Linter Rule Foundation/…:82-85` to match
`FoundationNetworking` (and consider `FoundationXML`). Until this lands, N8's central
invariant is unguarded on exactly the axis N8 travels. Pairs naturally with BOARD #11's
FI-product-omission rule.

> **Gate:** a new rule test asserting `@_exported import FoundationNetworking` **fires**, and
> `import HTML_Foundation` **does not** (the documented non-leading-component exemption).
> Positive control mandatory — a rule test that passes because it never ran is the failure
> mode this whole register is about. Then: the linter-rules package's own build + test + lint.

---

**Step 2 — Correct the two stale repository missions.** *(pre-G0, documentation only)*

The record requires this *before* filling (`:305`, "update stale repository missions first"):

- `swift-foundations/swift-http` — metadata advertises a **"core HTTP types"** mission that
  is obsolete; RFC 9110 / HTTP Standard own the model (`:107`). Left uncorrected it will pull
  the fill toward re-declaring L2 types at L3.
- `swift-components/swift-http-cache` / `swift-http-middleware` — L4 reserved names whose
  missions must be reconciled against N8's scope boundary, since the record's N8 STOP list
  forbids cache scope creep.

> **Gate:** no build. Metadata diff reviewed by the Lead; each repository description states
> what the package will own and explicitly disclaims what it will not.

---

**Step 2a — ✅ DONE: the two dead `[Byte]` overloads are deleted.** *(Lead-authorised
2026-07-24, folded into Step 2)*

`swift-rfc-9112` `9ccfb80` — removes `HTTP.Request.Line.parse(_: [Byte])` (was `:73`) and
`HTTP.Response.Line.parse(_: [Byte])` (was `:85`), plus the `public import Byte_Primitives`
each file no longer needed. 21 lines deleted.

**Deleted rather than implemented**, on the Lead's ruling and for the reason in Extension 4:
the intended non-throwing `-> Self` shape is *the same* total-signature-over-a-partial-
operation defect that makes `MessageBodyLength.calculate` collapse invalid framing to
`.none`. **Filling the bodies would move the trap, not close it.** The byte-level entry
belongs to the incremental framing layer, which must own locating the line delimiter.

> **Gate — all three run, evidence not exit status:**
> - **build GREEN** — exit 0, **0 errors**, `Build complete! (250.00s)`, **freshly compiled**
>   (1,832 compile steps; coordinator cross-check: *"every instrument agrees … freshly
>   compiled"*). Not a cache read.
> - **test GREEN** — exit 0, **237 tests in 12 suites passed**, 0 errors, **0 warnings**.
> - **lint** — exit 0, 90 active rules, 32 files linted, **118 violations, all pre-existing**:
>   `API-IMPL-005/006`, `PLAT-ARCH-022`, single-type-per-file, none import-related in
>   `Sources`, and all at lines never edited (the change is deletion-only, which cannot
>   create those rule classes).
>
> ⚠️ **Labelled honestly: I did not capture a numeric pre-change lint baseline.** "118, all
> pre-existing" rests on rule-class reasoning and on the build's zero warnings, not on a
> before/after count. Unmeasured, not zero.

**The gate earned its keep on a point I declined to guess.** After the deletion both files
still carried `public import Byte_Primitives` with no remaining `Byte` use. I chose not to
remove it on inspection — a `public import` participates in the module's re-export surface —
and let the build answer. It did, precisely: *"warning: public import of 'Byte_Primitives' was
not used in public declarations or inlinable code"* at both sites, and **only** those two
warnings across the whole build. Removed; the follow-up build/test came back at zero warnings.
`import INCITS_4_1986` was never warned, so it is still in use and stayed.

⚠️ **Push blocked, and the distinction matters here.** `git push` was denied by the
environment's permission classifier; **the commit is local and unpushed.** Under this
ecosystem's resolution model that is *not* the same as unreleased: consumers resolve
`swift-rfc-9112` through the mirror map **at the local repository's committed HEAD** (§1.3),
so **the local commit is already the propagating act** and the push only updates the remote of
record. Flagged for the Lead; needs operator approval to complete.

**Incidental corroboration of §3.2:** the lint's 2 `PRIM-FOUND-001`/`ARCH-LAYER-007` findings
are both in `Tests/` (`HTTP.Connection.Tests.swift:4`, `HTTP.TransferEncoding.Tests.swift:4`).
The Foundation-in-tests caveat is now confirmed by an independent instrument.

---

**Step 2b — ✅ DONE: the stale repository mission is corrected.** `swift-http` `7d5aaf2`.

`.github/metadata.yaml` read *"Core HTTP protocol types (methods, headers, status codes) for
Swift."* — the obsolete mission the record flags at `:107`. Replaced with the drive mission
from `:167`, plus an in-file comment recording why, so the next reader does not restore it.

**Two corrections to my own §1.1 and §2.3 fell out of doing it:**

1. **The remote description was already harmless** — `gh repo view` returns *"HTTP for
   Swift."*, not the stale claim. **The obsolete mission lived only in the local
   `metadata.yaml`, which is the propagating source of truth.** So this change *prevents an
   obsolete mission being published*; it does not retract a published one. Worth stating
   because the two are easy to conflate and only one is outward-facing.
2. ⚠️ **`swift-components/swift-http-cache` and `swift-http-middleware` do not exist.** Not
   merely unpopulated — **not git repositories locally, and `gh repo view` returns *"Could not
   resolve to a Repository"* for both.** §2.3 called them "reserved names at L4 whose missions
   need reconciling against N8's scope boundary." **There is nothing to reconcile: they are
   local directories holding `LICENSE.md` and `.github/`, and no reservation exists.** That
   removes the second half of Step 2 entirely, and it sharpens the principal's *"almost
   entirely aspirational"* — at L4 the names are not even reserved remotely.

`swift-foundations/swift-http` is **PRIVATE**, so the corrected mission is not public either.

---

**Step 3 — RFC 9112 differential audit + incremental-framing design.** *(needs G0; no source
edits in this step)*

Audit RFC 9112 §§2–11 against the 17 existing files; produce the incremental API design
(resumable state, exact consumed count, bounded limits) that replaces the whole-buffer
statics. Anchor on the already-localised defect at `HTTP.Message.Deserializer.swift:119`.

> **Gate:** a written differential with a per-section verdict (present / partial / absent),
> plus a design reviewed against the six N7 STOP conditions: smuggling ambiguity · inexact
> consumed count · post-limit append · byte loss · incorrect Host/target form · ambiguous
> reuse. **Design approval, not a build.**

#### 3.1 Incremental framing — design proposal (Step 3 deliverable, FOR REVIEW)

The conformance half of Step 3 is the inventory lane's
`Research/rfc-9110-9112-law-inventory-2026-07-24.md`; this is the API half, which is this
lane's. **Proposed, not settled** — design approval is a gate, and this is what goes into it.

**The central decision: the framer owns the buffer.**

Every one of the four framing defects found today is a *consumed-count* defect in disguise.
`Deserializer.swift:119` estimates consumed bytes from decoded size; `ChunkedEncoding.DecodeResult`
cannot express a consumed count at all; and a caller reusing a socket connection must know
where the next message begins. **If the framer owns the byte buffer and retains the remainder
itself, there is no consumed count to return and therefore none to get wrong.** The caller
never computes an offset into its own buffer, so the entire defect class is structurally
unreachable rather than merely fixed.

That is the difference between correcting Finding D and eliminating the conditions that
produced it — and it is why this is a redesign rather than a repair.

```swift
extension RFC_9112 {
    /// Incremental HTTP/1.1 message framer over a caller-supplied byte stream.
    /// Sans-I/O: it never reads a socket, it is fed by one.
    public struct Framer: ~Copyable {
        public init(role: Role, limits: Limits)

        /// Appends received bytes. Enforces `limits` DURING the append and
        /// throws before retaining anything over budget.
        public mutating func append(_ bytes: borrowing [Byte]) throws(Error)

        /// Yields the next complete message, or nil when more bytes are needed.
        /// The unconsumed remainder stays owned by the framer.
        public mutating func next() throws(Error) -> Frame?

        /// End-of-stream disposition. Distinguishes a clean close from a
        /// truncated message, which a `nil` from `next()` cannot.
        public consuming func finish() throws(Error) -> Terminal
    }
}

extension RFC_9112.Framer {
    public enum Role: Sendable { case request, response }
    public struct Limits: Sendable { /* line, field-section, body, chunk-extension */ }
    public enum Terminal: Sendable { case clean, truncated(Error) }
}
```

**How each defect and STOP condition is addressed structurally, not by discipline:**

| Defect / STOP | Mechanism |
|---|---|
| **Finding A** — invalid framing collapses to `.none` | `Frame` has **no case that doubles as both "no body" and "malformed"**. Invalid framing is `throws(Error)`, so it cannot be returned as a valid-looking value. This is the direct fix for *a total signature over a partial operation*. |
| **Finding B** — chunked-not-final undetected; request/response dispositions differ | `Role` is a **construction parameter**, so a single shared code path that is wrong for one of them cannot be written. Chunked finality is checked with the already-shipped finality accessor (`ChunkedEncoding` `:198-200`), not membership. |
| **Finding C** — TE+CL coexistence unreported | The coexistence is a **typed error case**, not a silent preference for `.chunked`. An intermediary can then comply with the MUST to strip `Content-Length`. |
| **Finding D** — inexact consumed count | **Eliminated by construction** — no consumed count crosses the API boundary. |
| **Finding E / D16** — limits checkable only post hoc | `limits` are enforced **inside `append`**, which throws *before retaining* over-budget bytes. A limit that can only be checked after acceptance is not a limit; this one is checked before. |
| **STOP: byte loss** · **ambiguous reuse** | The framer retains the remainder across messages, so pipelined messages and connection reuse are the same code path as the first message — nothing is discarded between them. |
| **GO: split-at-every-byte** | `append` accepts any chunking including one byte at a time; `next()` returning `nil` is the normal path, not an error. |
| **GO: EOF / terminal disposition** | `finish()` is `consuming` and distinguishes **clean close from truncation**, which `next() == nil` cannot. Making it consuming means a framer cannot be used after its stream ends. |

**Open questions for the design gate — flagged rather than silently decided:**

1. **`~Copyable` vs a class.** `~Copyable` matches the record's ownership discipline (`:695-700`
   adopts move-only leases from the Apple prior art) and prevents accidental framer duplication
   mid-stream. It also makes the type awkward to hold in an actor's storage. **Recommend
   `~Copyable`; flagging that N8 will feel the cost first.**
2. **Where `Role` lives.** Request and response framing share the field-section and chunked
   grammar but differ in start-line and in body-length disposition. One type with a `Role`, or
   two types? **Recommend one type** — two types duplicate the grammar and re-open the
   possibility of them drifting apart, which is how B happened.
3. **Whether `Frame` carries the body or streams it.** Carrying it is simpler and matches
   today's `[Byte]?` bodies; streaming is required eventually for backpressure. The record
   says *"keep this internal foundation and later expose a streaming API"* (`:699`).
   **Recommend body-carrying now with the streaming seam internal**, per that instruction.
4. **Placement.** This is L2 wire law and belongs in `swift-rfc-9112`. The *drive* — exchange
   sequencing, reuse eligibility, shutdown — is L3 `swift-http` over an injected duplex.
   **The boundary is: the framer knows about messages; the drive knows about connections.**

---

**Step 4 — Implement bounded incremental framing in `swift-rfc-9112` (L2).**

⚠️ **This is the step with ecosystem blast radius, per §1.3.** `swift-rfc-9112` resolves to
every consumer at local committed HEAD with **no version gate**, and pins across the
ecosystem are known-stale (BOARD #8). A change here is live for every consumer at their next
resolve, whenever that happens to be.

> **Gate (three parts, all required):**
> 1. `swift-rfc-9112` build + test + **lint**, exit status captured directly.
> 2. **Consumer corpus gate** — re-gate the known downstream corpus holders *before* the
>    change is called done, not after they go red hours apart: `swift-http-standard`,
>    `swift-github-http`, and the three packages burned today (`swift-authentication`,
>    `swift-stripe-types`, `swift-identities-types`). §1.3 is the precedent; this is the step
>    that would repeat it.
> 3. Foundation-freedom re-checked at **0** for `Sources` (positive-controlled per §3.1).
>
> Serialize parts 1 and 2 across the 2 coordinator slots — do **not** launch them
> concurrently against packages that share a `.build`.

---

**Step 5 — Fill `swift-foundations/swift-http` (L3) over an injected duplex.**

The drive: exchange, framing, body backpressure, reuse eligibility, protocol shutdown.
**Depends on HTTP Standard / RFC 9112 and IO vocabulary — never DNS, TLS, sockets, or
routing.** That exclusion is the whole reason the package can be L3 (§2.2).

> **Gate:** build + test + lint, plus the N7 **GO** conditions from the record —
> **split-at-every-byte**, 1xx / chunk / trailer / pipeline / EOF, partial IO, cancellation,
> terminal disposition. Plus an explicit manifest assertion that no DNS/TLS/socket/routing
> dependency has appeared. Plus `Sources` Foundation imports = 0.

---

**Step 6 — N8 `swift-components/swift-http-client` (L4).** *(blocked on `[PLAT-ARCH-008a]`
per §5.0, and on N1–N6, which are other lanes' work)*

New repository — creation is granted in principle (BOARD ruling 2026-07-24) but the record
requires **separate per-repository authorization at G0**. First non-trivial package at L4, so
it establishes L4's CI/lint/README/metadata conventions (§2.3).

> **Gate:** the accepted executor contract + all local deterministic gates; N8 **STOP** list
> explicitly checked — no Router/provider dependency · no redirect/stream/cache/wire-DNS
> scope creep · no lifecycle authority leak · no API seam deviation. Foundation-freedom in
> the core target with any URLSession-shaped surface quarantined in a
> `* Foundation Integration` target per §3.4 — **and the FI *product* declared on consumers**
> (BOARD #11's failure mode, three instances in one day).

---

**Step 7 — Retire the repotraffic holdouts.** *(the payoff for priority #2)*

- `Syncing.Fetch.Execution.liveValue` — replace the `.networkingUnavailable` stub with a real
  value. §3.5 shows the seam is already cut and typed as
  `(RFC_9110.Request) async throws(Error) -> RFC_9110.Response`; **no API design, no consumer
  migration.** This is the easy one and it is the arc's designated destination.
- `validateToken` (`Syncing.swift:140-174`) — the hard one. No dependency seam at all, a `!`
  force-unwrap on a literal URL (`:142`), a local `JSONDecoder`, and a `HTTPURLResponse`
  downcast. Three separable changes: introduce a seam · move to `RFC_9110` types + a typed
  `RFC_3986.URI` · replace the Foundation JSON decode. Known callers:
  `SyncingLive/Syncing.Token+Live.swift:24`, `AccountLive/Account.GitHub+Live.swift:46`.

> **Gate:** repotraffic build + test, **and** an app-boot check — repotraffic's history today
> shows compile-green preceding boot-crash more than once. Then the release-purity assertion
> that motivates the whole arc: **no URLSession/NIO/Vapor in the shipped product graph** for
> the paths touched.

---

**Step 8 — Reconcile the obsoleted RFC 7230–7235 family.** *(independent leaf; any time after
Step 3)*

Six packages of superseded HTTP/1.1 law, one substantial (`swift-rfc-7230`, 1,370 lines),
five near-empty stubs (§1.4). Pure decomposition work in the programme's own terms.

> **Gate:** a **consumer census first** — "obsoleted by the IETF" says nothing about what this
> workspace imports. Positive-control the census (a scan that finds zero because it was rooted
> wrong is indistinguishable from a true zero). Only then propose retire / merge / keep, per
> package, to the Lead. **No deletion without an adjudicated census.**

### 5.3 What I recommend the Lead do first

Steps 0, 1 and 2 are pre-G0, cheap, and each closes a real defect. **Step 0 in particular
costs one lint run and determines whether `[ARCH-LAYER-007]` is enforced at all** — which is
load-bearing for how much of N7/N8's Foundation-freedom can be asserted versus must be
manually audited. I am holding on all of them pending the Lead's go-ahead, because they are
gates and there are 2 slots.

## 6. Stale documents and defects found

Filed for the Lead. Each is independent of the N7/N8 recommendation and none was assumed —
every one carries the evidence that established it.

| # | Defect | Evidence | Severity |
|---|---|---|---|
| D1 | **`git log --since=<bare ISO date>` silently returns zero for that day.** Swept across roots it manufactures a uniform "nothing happened" negative. | §0.4 — table of four probe variants on a repo with two same-day commits | **High** — instrument defect, same family as `timeout(1)`/`${PIPESTATUS[0]}` already in the BOARD |
| D2 | **`Lint.Rule.Foundation.Import` does not match `FoundationNetworking`** — the module carrying URLSession on Linux. A package can `@_exported import FoundationNetworking` and pass Foundation-freedom lint. | §3.4a — predicate at `Institute Linter Rule Foundation/…:82-85`; live instance at `swift-urlrequest-handler/Sources/URLRequestHandler/exports.swift:4` | **High** — the guard is blind on exactly N8's axis |
| D3 | **`swift-urlrequest-handler` has 3 bare `import Foundation` lines the rule *does* match, while activating `Lint.Rule.Bundle.institute` with no exclusions.** Either its lint is not running or it is red and unattended. | §3.4a; `Lint.swift` full text has no `excluding(rules:)` | **High** — plausible mechanism behind BOARD #24's 61 packages / 1,307 lines vs a tracked "4" |
| D4 | **BOARD is self-inconsistent on #32's priority** — ruling `BOARD.md:22` ranks HTTP stack **first**; the task row `BOARD.md:150` says "priority #2". | §0.1 | Medium — recommend correcting line 150 |
| D5 | **The Fable-gate removal is recorded as covering N5/N6** (`BOARD.md:19`), but #32 claims it unblocks **N7/N8** (`BOARD.md:150`). As written the durable record does not license the #32 unblock. | §0.2 | Medium — confirm wording before N7 implementation |
| D6 | **`apple/swift-http-api-proposal` local checkout does not contain the commit the heritage record cites.** `git cat-file -t 10db597e…` → *could not get object info*; branch is **22 behind** origin/main; local HEAD `8636308` (2026-04-01) vs cited commit authored 2026-07-21. Every line-citation in the record's Adopt/Adapt/Reject table is unverifiable locally. | §4.2 | Medium — a re-reviewer reads a ~4-month-older tree while believing it matches |
| D7 | **`swift-foundations/swift-http`'s repository mission is obsolete** — advertises "core HTTP types", which RFC 9110 / HTTP Standard own. The record requires correcting it *before* the fill. | §2.2; record `:107`, `:305` | Medium — will misdirect N7's L3 half |
| D8 | **Six obsoleted RFC packages duplicate live HTTP/1.1 law** — `swift-rfc-7230` (1,370 lines) overlaps `swift-rfc-9112`; `7231`–`7235` are 245- and 11-line stubs. | §1.4 | Medium — decomposition debt, needs a census before any retirement |
| D9 | ✅ **CLOSED during this session.** `CLAUDE.md`'s package-location table omitted `swift-components/` (L4) and `swift-applications/` (L5) — it mapped "Foundations — everything else Swift" to `swift-foundations/`, misrouting a lookup for `swift-http-client`, **N8's own package**. The table has since been amended to name Components (25 packages), Applications (40 entries) **and** a third undocumented root, `swift-foundry/`. | §1.1; verified fixed in the live `CLAUDE.md` | ~~Medium~~ **resolved** |
| D10 | **Public docs contradict the architecture.** `swift-institute.org/Swift Institute.docc/Layers.md:8` states *"The ecosystem spans **three** layers"* and tables only Primitives/Standards/Foundations. `CLAUDE.md` and `[ARCH-LAYER-001]` specify **five**, and N8 lands at L4 — a layer the public documentation does not acknowledge. | §2.3; `Layers.md` is 14 lines total | Medium — N8 is the first substantive L4 package; the docs deny L4 exists |
| D11 | **`swift-components` is 24/25 empty scaffolds; `swift-applications` has no `Package.swift` at depth ≤3.** Directory listings imply a populated L4/L5 that does not exist. | §1.1 | Low-Medium — sizing hazard, not a correctness defect |
| D13 | ⚠️ **zsh does NOT word-split unquoted parameter expansions — multi-path probes silently search NOTHING and exit 0.** `ROOTS="/a /b"; grep -r … $ROOTS` passes one non-existent path, prints **no stderr**, and returns a clean zero. Measured: unquoted `$R` → **0**; `${=R}` → **7**; literal paths → **7**, same query. **This invalidated my entire first RFC-7230 census.** Fix: use an array `("${ROOTS[@]}")`, `${=VAR}`, or literal paths. | §1.4a; diagnosis run three ways on one query | **High** — sibling of the `${PIPESTATUS[0]}` rule already in the BOARD; produces confident false absences with no error |
| D14 | **`grep -r` without `--exclude-dir` descends into `.build` and can exceed the timeout, yielding partial or empty output that reads as a zero.** My second census attempt died at **exit 143 (SIGTERM)** after 2 min having printed only a header. A timeout is not a result. Fix: `--exclude-dir='.build' --include='*.swift'`, and check the exit status. | §1.4a | Medium |
| D15 | **`swift-institute/Research` is a PUBLIC repository** (`gh repo view` → `"visibility":"PUBLIC"`, `isPrivate:false`), and the fleet had been treating it as internal scratch space. | verified by resolving the remote, not by reading `.git/config` | **High** — governance; see §6.2 |
| D16 | **`Request.Line.validate(maxLength: 8000)` is a POST-parse call on the re-`formatted` line** (`HTTP.Request.Line.swift:91`), so it cannot prevent over-long input from being accepted first. **A limit checkable only post hoc is not a limit.** Second instance of the shape (with Finding E's whole-buffer limits), which makes it structural rather than a slip. | §1.5b; inventory lane, confirmed here | **High** — DoS surface, and RFC 9112 §3 is the clause it purports to implement |
| D12 | **The heritage record's own self-description is stale.** `:881-884` says *"Both Research records remain untracked … No commit or push is authorized."* It is now **tracked** (`git ls-files --error-unmatch` succeeds). | this section | Low — but it is the authority document for N7/N8; its status line should not mislead |

### 6.2 ⚠️ This document lives in a PUBLIC repository

Flagged by the Lead 2026-07-24 and **verified here rather than accepted** — the BOARD's own
standing rule is that a configured remote URL is not evidence of remote identity. Resolving
the remote (`gh repo view`, not `.git/config`) returns:

```
{"isPrivate":false,"nameWithOwner":"swift-institute/Research","visibility":"PUBLIC"}
```

**The caution is correct.** Consequences applied to this file:

- **All machine paths have been scrubbed.** 10 occurrences of the operator's home-directory
  prefix were removed; every path in this packet is now workspace-relative. Verified: zero
  remaining. (`coenttb/…` survives as a public GitHub org name, not a filesystem path.)
- **This file is untracked (`??`) and has never been committed or pushed.** Nothing here has
  been published.
- **No credentials, tokens, or private-repository internals** appear in this packet. Its
  content is architecture, public RFC numbers, public package names, and line references.
- **Not committing.** Phase 1 is scope-only and the Lead has signalled a fleet-wide siting
  ruling is pending. This packet stays untracked until that ruling lands.

⚠️ **Successor note:** every other lane's Research output is under the same exposure. This is
a fleet-wide governance item, not an HTTP-lane item, and it is filed as D15 rather than
handled here.

### 6.1 On `TOOLCHAINS` — checked, and clean on this path

The brief instructs me to report any document telling me to set a `TOOLCHAINS` identifier.
**Neither authoritative N7/N8 document contains one**:
`/usr/bin/grep -rn 'TOOLCHAINS'` over
`native-networking-wave-3-implementation-heritage-dependency-record.md` and
`n6-tls-engine-scoping-2026-07-23.md` returns **nothing**, and the same grep over `Research/`
returns 5 other files — so the probe works and the zero is real, not a mis-anchored scan.

The N6 packet does mention toolchain handling in passing but issues no `TOOLCHAINS` pin. **No
stale toolchain instruction stands in N7/N8's way.** The ruling in force —
Xcode's bundled toolchain, no `TOOLCHAINS`, no carve-outs — is what §5.1 binds every gate to.

---

## 7. Summary for the Lead

**One-line answer:** #32 is in better shape than the brief implies on *law* and worse on
*readiness* — RFC 9112 already carries 3,000 lines of HTTP/1.1 law, but the incremental
framing N7 is defined by is absent, N7's L3 half is an empty scaffold, N8's layer was already
decided at L4 by a document the brief did not name, and **execution is blocked by G0 and by a
`[PLAT-ARCH-008a]` confirmation the Fable-gate removal did not touch.**

**The five things I would put in front of the principal:**

1. **N7 is half-built and its missing half is precisely specified** — bounded incremental
   framing (§1.0), with one N7 STOP condition already admitted in a source comment at
   `HTTP.Message.Deserializer.swift:119`.
2. **There is no version gate on L2 HTTP law.** Consumers resolve `swift-rfc-9110`/`9112` at
   the local repo's committed HEAD via a 1,256-entry mirror map. Today's three-corpus
   breakage was **not** a change — it was stale pins advancing onto an eight-month-old
   conformance (§1.3). Every N7 step inherits this.
3. **The Foundation-freedom guard has a hole shaped like N8** (§3.4a, D2/D3).
4. **Build, not adopt** — `[HERITAGE-001]` does not fire anywhere on this path, and adopting
   NIO would make the release-purity goal unreachable by construction (§4).
5. **#32 is not executable yet.** G0 unreleased; N8 blocked on a verbatim four-criterion
   confirmation (§5.0). Steps 0–2 are pre-G0 and each closes a real defect — **Step 0 is one
   lint run and tells us whether `[ARCH-LAYER-007]` is enforced at all.**

**What I have not done, deliberately:** no source edits, no commits, no gates. Three gates are
proposed as Steps 0–2 and **I am holding all of them for the Lead's go-ahead**, per the 2-slot
serialization rule.
