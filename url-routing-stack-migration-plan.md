# URL-Routing Stack Migration Plan (Staged)

<!--
---
version: 1.6.0
last_updated: 2026-07-21
status: APPROVED
tier: 2
scope: cross-package
changelog:
  - 1.6.0 (2026-07-21): Post-B2 transition rulings (steering consolidation). B2-gate
    pause RELEASED (resume = B3). Arc build posture FINAL: scoped edit-mode through B8;
    fleet edit-all REFUTED on speed (path-semantics study v1.1.0 §E5); `swift package
    clean` replaces `rm -rf .build` (preserves edit state, verified); Scripts arming
    triple adopted. ARC CLOSE amended: B8 final pin-advance wave SUPERSEDED by
    unedit sweep + push + CI-green-on-committed-state per the ratified policy
    ("local = live trees, CI = resolved versions"). Execution model: agent-team
    session (lead = sole gatekeeper; teammate lanes; concurrency rules unchanged).
    Ecosystem decisions parked for Principal (xcworkspace rescope, CI never-live
    guard, SwiftPM feature request, batch-seed pilot). See §Post-B2 transition
    rulings (v1.6.0).
  - 1.5.0 (2026-07-21): Consolidation — Principal relays 4, 4-addendum, and 5 folded in
    as §Consolidated relay rulings (v1.5.0), the now-governing text superseding chat-only
    relay state: boiler corpus descope; minimum-viable rule for dissolution-bound
    components; design-sensitive lanes at raised effort; item-scoped STOPs + batched
    ratification queue; scoped corpus re-runs; EDIT-MODE build posture (arc-scoped,
    replaces per-gate pin advances) + bounded cross-repo parallelism; worker refresh
    protocol + successor bootstrap; swift-email-standard one-line fix authorized as a
    B1-gate unblocker. Advisory-session consolidation for the worker refresh.
  - 1.4.0 (2026-07-21): Stripe carve-out ratified (Principal relay 3) after the 6.4
    verification spike closed the snapshot route: stripe is doubly walled — §A9
    Tagged-metadata SIGSEGV at runtime on 6.3.3 (all 84 routers; production ships
    single-branch Compat_Swift_6_3 avoidance copies) AND a deterministic swift-frontend
    -Onone ICE compiling `Stripe Webhooks Types` on org.swift.64202607171a
    (swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a; provisional new catalog row,
    nearest §A24). Arc toolchain pin REMAINS org.swift.633202606251a. Spike keepers
    (permanent dual-toolchain value): swift-hash-primitives 7c66ee0 (macOS-27
    availability-gate exclusion — the gate is confirmed shipping 6.4-SDK behavior, not
    main-branch noise), swift-clock-primitives 50d2e0f (withTaskCancellationHandler
    overload disambiguation), coder-primitives stale-pin cure (SwiftPM update, no
    commit). §A16 did NOT fire on the 6.4.x +asserts snapshot (catalog-worthy).
    See §Stripe carve-out (v1.4.0) for the batch-level mechanics and the FLIP GATE
    definition; the annex's wall-budget concept is retired with the snapshot route.
  - 1.3.0 (2026-07-20): Overnight end-to-end execution annex added (Principal directive:
    whole plan in one unattended run). Every attended stop-point converted to a written
    auto-rule or completed prep input: B3/B4 delta-class auto-rules; wire canaries excluded
    per [TEST-040] (morning attended follow-up, non-blocking); GREEN-spike full unification
    IN scope backed by the 2026-07-20 L1-wide Printer/Bidirectional consumer census;
    verified-mechanism recipes for new-repo bootstrap and the B7 rename (global
    mirrors.json reality — the skill-cited sync scripts do NOT exist); preflight
    assertions; self-paced run protocol (no /goal skill exists on disk).
  - 1.2.0 (2026-07-20): Principal ratified the full gate adjudication → status APPROVED
    (approved to execute per the batch discipline; implementation NOT started). Router
    naming cascade folded in (swift-routers / Router / Routing alias / Routable; L4
    swift-routers-{vapor,http}); Coder-unification spike inserted as the Batch-2 entry
    gate; translating → DISSOLVE; DI deps default-drop; parity-corpus home and org
    swift-format canonical fixed; OPEN gate list reduced to execution-time sign-offs.
  - 1.1.0 (2026-07-20): Principal rulings folded in (see dossier §Principal rulings) —
    form-coder family named swift-html-form-coder with HTML.Form.Coder (default = urlencoded)
    + .Multipart; two L2 alias/re-export items added to Batch 2; approval-gate list split
    into RATIFIED vs OPEN; ratified final package roster + implementation dispatch preamble
    appended. Prep-only: no implementation started.
  - 1.0.0 (2026-07-20): initial staged plan.
---
-->

Companion to `url-routing-stack-first-principles-review.md` (the dossier — findings, ideal
map, dispositions, and the two Principal-rulings rounds). **Fully ratified 2026-07-20**: the
repo creations, dissolutions, behavior-change classes, naming cascade, deferrals, and batch
structure below are approved to execute in batch order. What remains execution-time: each
batch's own verification gate, the concrete-delta sign-offs at B3/B4, and the spike verdict
at the B2 entry gate. [ARCH-LAYER-009] guards still apply to every deletion (commit-first,
verify-dead), and dissolution commits carry an execution-time confirmation stamp per
workspace rules. Implementation has NOT started; this document is the standing work order.

## Invariants (all batches)

- **Every consumer compiles and stays green at every stage.** A batch that breaks a consumer
  is mis-scoped; split it. Consumer sweep in the same arc as any public-surface change
  ([PKG-DEP-012]).
- **Parity gates precede movement.** The Batch-0 wire-shape corpus is captured BEFORE any
  source moves; behavior-neutral batches must reproduce it bit-for-bit; behavior-CHANGING
  batches enumerate their intended differences and get those differences ratified (primary
  spec wins over the current baseline — but each intentional difference is logged, per the
  networking program's "external baseline treated as spec" risk row).
- Correctness-driven only; consumer counts sequence work, never justify shape
  ([ARCH-LAYER-006]/[ARCH-LAYER-008]).
- Toolchain: TOOLCHAINS=org.swift.633202606251a, assert 6.3.3-RELEASE. Live-mutating suites
  stay OUT of unattended gates ([TEST-040]); Mailgun/Stripe wire canaries are attended,
  credential-classified runs.

## Batch 0 — Parity capture (wire-shape tests; no source movement)

Capture, as committed snapshot tests in each consumer (or a dedicated parity package under
`Tests/`), the CURRENT wire shapes:

1. Router print corpus: for every router in swift-mailgun-types, swift-stripe-types,
   swift-identities-types, repotraffic (RepoTrafficRouter), swift-authentication, boiler —
   print representative routes and snapshot: method, path, query (order-sensitive), headers
   (INCLUDING the current absence of Content-Type where absent — parity captures what IS),
   body bytes.
2. Router parse round-trips: parse(print(route)) == route for the same corpus.
3. Form.Encoder/Decoder corpus: every strategy configuration in use (`.yesNo`,
   `.bracketsWithIndices`, `.brackets`/`.accumulateValues`) with representative values,
   snapshot the encoded pair strings both directions.
4. Multipart corpus: pinned boundary (inject, don't randomize) → snapshot full body bytes +
   the `contentType` value the encoder exposes.
5. The four unfixed query-param Bool yes/no fields recorded in the day report (§8:155) —
   capture current emission as-is.

Gate B0: corpus green on the current stack; committed. **Approval: none needed (additive
tests only), but the corpus files' home (per-consumer vs dedicated parity package) is a
Principal preference — default per-consumer `Tests/`.**

## Batch 1 — Mechanical hygiene (behavior-neutral, zero API change)

All items are drift fixes with existing-evidence citations in the dossier (§B1):

- Declare the undeclared: `Collection_Slice_Primitives`, `WHATWG_HTML_Shared` (+ the test
  target's `WHATWG_HTML_Forms`/`RFC_3986`/`RFC_7230` rides) — ADD-PRODUCT per [PKG-DEP-007].
- Remove dead deps/imports: RFC 6570 dep (Package.swift:27,66), dead Foundation import
  (HTTP.Header.Parser.swift:1), manifest-level `import Foundation` (translating,
  urlrequest-handler Package.swift:3), dead `>>>`/`|>` operators (B2-07).
- Fix the three silent no-op `target.swiftSettings?.append` sites (url-form-coding:50,
  form-coding:38, multipart-form-coding:61) — enabling MemberImportVisibility may surface
  latent missing imports; fix those in the same commit wave (still behavior-neutral).
- Fix swift-url-routing-translating's test-target/directory mismatch (Package.swift:54,65).
- swift-form-coding: delete the broken symlink to the retired coenttb path; remove the two
  declared-unused deps; drop the abandoned traits block. (Package DELETION itself is Batch 7.)
- README/DocC rebrand of swift-url-routing off the stale pointfree branding (README.md:3–6).
- Tooling: fix the swift-format config drift (align the four repos on the org config —
  pending a Principal choice of which variant is canonical); document the SwiftLint
  org-config false-green invocation in the lint runbook (`--config <path>` from another dir
  lints zero files); re-pin the swift-linter engine dep off `branch:"main"` per the
  versioning strategy.

Gate B1: all ten repos + all consumers build; Batch-0 corpus byte-identical. **Approval:
none (ordinary commits).**

## Batch 2 — L1/L2 gap fills (purely additive; no L3 reshape yet)

**Entry gate (ratified 2026-07-20): the Coder-unification spike.** Before the conformance
gap-fills land, run a ≤1-day experiment (per /experiment-process, sanctioned location):
implement forward-order APPEND emission (`serialize`) through the ~10 core parser
combinators and assert the round-trip laws — including printing into a non-empty rest and
the `Optionally`/`OneOf`/`Many`-with-separator/`Skip` cases. Context (verified shapes:
dossier §Principal rulings round 2): `Parser.Printer` ≅ `Serializer.Protocol where
Buffer == Input` modulo prepend-vs-append; L1 currently maintains two parallel combinator
algebras.
- **GREEN (default outcome)**: `Coder.Protocol` becomes the single canonical bidirectional
  conjunction; `Parser.Bidirectional` is redefined as the law-carrying
  `Coder where Buffer == Input`; `Parser.Printer` retires; the conformance rows below land
  **Serializer-side**; `Router.Protocol` (B7) refines the constrained form. The
  [PKG-DEP-012] consumer sweep for the retirement is PRE-ENUMERATED (census 2026-07-20,
  pruned workspace-wide grep): outside the in-plan repos, the only Printer/Bidirectional
  consumers are `swift-primitives/swift-byte-parser-primitives` (2 files) and
  `swift-ietf/swift-rfc-8259` (1 file) — both migrate in the same unification commit wave.
- **RED**: prepend is proven load-bearing; the dossier F1 role split stands; rows land
  Printer-side; the impossibility record is committed with the experiment.

| Item | Home | Retires |
|---|---|---|
| Bidirectional emission conformances for `Many` (separator round-trip), `Optionally`, `Rest`/`Prefix` — Serializer-side if spike GREEN, Printer-side if RED | L1 swift-parser-primitives | enables B5/B7 printer-side consolidation |
| Value-checkpoint backtracking for `OneOf`/`Optionally` (Copyable carriers) | L1 swift-parser-primitives | B2-16 combinator twins (retired in B7) |
| Four bidirectional refinement declarations (spelling per spike outcome) | L1 swift-parser-primitives | B2-17 retroactive patches |
| Case-path derivation macro (`Optic.Prism` per enum case) + Prism→`Parser.Conversion` bridge | L1 swift-optic-primitives (+ tiny swift-parser-optic-primitives) | per-case boilerplate in every consumer router |
| `RFC_2046.Boundary.random()` (validated generator) | L2 swift-rfc-2046 | B2-11 three hand-rolled `__unchecked` sites |
| RFC 7578 decode side (field/file projection, §5 charset) | L2 swift-rfc-7578 | B2-09's JSON-round-trip decode path |
| Media-type convergence `RFC_2045.ContentType ⇄ RFC_9110.MediaType` | L2 swift-standards/swift-media-type-standard (NEW package) — fallback: conversion inits in swift-http-body | B2-13 MIME-catalog duplication; enables the multipart coder's MediaType contract |
| uri-standard drift fix (delete reimplemented percent free functions; converge 3987) | L2 swift-uri-standard | A2 gap 5 |
| RFC 2822 §3.3 date-time machinery | L2 swift-rfc-2822 | mailgun preset's hand-rolled `rfc2822Formatter` (B2-19) |
| Cookie grammar (Set-Cookie/Cookie per RFC 6265) | L2 swift-rfc-6265 | prepares B6's cookie relocation (B2-04) |
| `WHATWG_HTML.Form` nest alias (one line; `Form` is module-top-level in `WHATWG_HTML_Forms` today) | L2 swift-whatwg-html | makes the RATIFIED `HTML.Form.*` spellings resolve; NO other whatwg change (ruling 4: no parser/serializer deps enter WHATWG packages) |
| Forms-product re-exports | L2 swift-html-standard | completes the converged `HTML.Form` path for consumers |

Gate B2: each addition lands with its own tests in its own repo; no L3/consumer change;
Batch-0 corpus untouched. **Approval: creation of `swift-media-type-standard` (new repo) —
everything else is ordinary additive work in existing repos.**

## Batch 3 — URI engine truth (behavior-changing, ratified-differences gate)

Replace the URLComponents parse/print fork (URIRequestData+RFC_3986.swift:25–27,91–128) and
the naive `/`-split (URI.Request.Data.swift:87) with the RFC_3986 engine, per fork F2:
split raw path on `/` BEFORE percent-decoding each segment; ordered query pairs from
`RFC_3986.URI.Query`; public API unchanged in this batch (the `Router.Input` reshape is B7).

Intended differences to enumerate and ratify (spec-correct where the fork was wrong):
`%2F`-in-segment no longer splits; percent-normalization edge cases; empty-vs-absent query
value fidelity. Every difference must be visible as a Batch-0 corpus delta with a one-line
justification; anything not enumerated is a regression.

Gate B3: corpus deltas == the ratified enumeration, byte-exact otherwise; all consumers
green; the day-report §8 Bool query-param cases re-checked. **Approval: Principal ratifies
the difference list (wire-visible behavior change).**

## Batch 4 — The body-coder contract (closes the RT-030 class)

1. Create `swift-http-body` (NEW L3 repo): `HTTP.Body.Coder` (refines `Coder.Protocol`;
   `static contentType: HTTP.MediaType`; `accepts(_:)`), `HTTP.Body.Coder.Witness`, coupled
   `HTTP.Request.body(set:using:)`/`body(decode:using:)` mutators; opt-in `HTTP Body JSON`
   target lifting swift-json.
2. swift-url-routing gains `Router Body`-shaped conversions that lift any `HTTP.Body.Coder`:
   print installs body bytes AND Content-Type in one operation; parse validates Content-Type
   (typed error) before decoding. Existing `.form`/`.multipart`/`.json` conversions remain
   temporarily as deprecated aliases that do NOT emit headers (bit-parity preserved until
   consumers opt in).
3. Consumer migration, per consumer, each with its own corpus delta: mailgun-types' 44
   headerless body routes (worst first: Lists.API.swift:298–315 cases.update — the unfixed
   RT-030b/c compound; then the 15 PUT + 1 PATCH silent-ignore set), stripe-types' 143
   `.form` routes (simultaneously retiring stripe-live's blanket-header compensation —
   AuthenticatedClient.swift:106–112 — so exactly ONE header convention remains),
   identities-types (30), repotraffic (7), boiler examples (14).

Gate B4: per-consumer corpus deltas show exactly "+ Content-Type: <expected>" and nothing
else; attended wire canaries against sandbox accounts for mailgun/stripe (credential
classification first; [TEST-040] mutation census on close). **Approval: new repo
`swift-http-body`; the header-emission behavior change per consumer batch.**

## Batch 5 — Form/multipart consolidation (the coder family reshape)

Names below are RATIFIED (dossier §Principal rulings): package `swift-html-form-coder`;
`HTML.Form.Coder` is the coder whose wire form is the HTML spec's DEFAULT enctype
(`application/x-www-form-urlencoded`, contentType `.formUrlEncoded`);
`HTML.Form.Coder.Multipart` is the marked variant (contentType `.formData`); `text/plain`
deliberately unimplemented (spec-marked lossy — typed error, not a variant).

1. Create `swift-html-form-coder` (NEW L3 repo): targets `HTML Form Coder` (typed ⇆
   `HTML.Form.Data` entry-list pivot + the default urlencoded wire via
   `WHATWG_Form_URL_Encoded`; conforms `HTTP.Body.Coder`), `HTML Form Coder Multipart`
   (⇆ wire via RFC 2046/7578 + Boundary.random(); conforms `HTTP.Body.Coder`),
   `HTML Form Coder Nested` (bracket-notation convention, relocated from rfc-2388),
   `HTML Form Coder Codable` (opt-in visitor bridge — the ONE place stdlib Codable
   witnesses live; resolves B4's Codable-wall finding structurally).
2. ONE strategy vocabulary (Bool/date/data/array/nesting) defined once at
   `HTML.Form.Coder.Strategy.*` and consumed by both wire forms — retires the RT-030b
   asymmetry class (B2-06). Parity: the union of both current vocabularies, each preset
   corpus-verified.
3. Extract the ~1,035-line in-router multipart machinery (Multipart.*, FileUpload.*) onto the
   new targets; wire format stays L2; `Multipart.File` unifies with `RFC_7578.Form.Data.File`
   (B2-10); decode drops the JSONSerialization round-trip for the RFC 7578 decode side
   (B2-09); the `RFC_2046` namespace injection ends.
4. swift-url-form-coding's Form.Encoder/Decoder become the `HTML.Form.Coder` (+ Codable
   leaf) surfaces (compat typealiases in place until consumers migrate); the hand-rolled
   pair split/serialize (B2-03) delegates to the WHATWG codec. swift-multipart-form-coding
   is absorbed. De-duplicate `.form` (keep exactly one conversion; B2-20).
5. rfc-2388 dissolution: content relocates to `HTML Form Coder Nested`; the L2 package
   retires ([ARCH-LAYER-009] guards).

Gate B5: Batch-0 form + multipart corpora byte-identical (boundary pinned) modulo the
Batch-4-ratified header additions; strategy-preset parity table complete; consumers green
(mailgun-types strategy configs, stripe `.bracketsWithIndices`, identities). **Approval: new
repo `swift-html-form-coder` (name ratified); dissolution of swift-rfc-2388; absorption of
swift-multipart-form-coding and (via compat shims) swift-url-form-coding.**

## Batch 6 — Placement and dependency truth

- Cookie relocation: HTTP.Cookie grammar (HTTP.Cookie.Parser.swift:53–64) → swift-rfc-6265
  (grammar landed in B2); router keeps a header-combinator lift only (B2-04).
- RFC 7230/7231 → RFC 9110: swap the dep + migrate the Method/Header/MediaType twins
  (B2-14); aligns with `HTTP = RFC_9110` and the ratified networking prior.
- Base64 (3 sites) → RFC_4648; Foundation JSON → swift-json where wire-equivalent (B2-12,
  B2-18) — each corpus-checked.
- URLRouting.Client split: URLRequest bridging → `URL Routing Foundation Integration` leaf;
  execution stays URLSession-backed in a clearly-marked Foundation-bound surface
  (urlrequest-handler consolidation target) until the networking program's swift-http lands
  (Wave 3) — an EXPLICITLY DEFERRED [ARCH-LAYER-007] exception, recorded here. Fix the
  DecodingError triple violation (URLRouting.Client.swift:64–67) in the move.
- Vapor bridge: drop the URL/URLComponents re-parse (…+Vapor.Request.swift:40–41), map
  Vapor's parsed components directly.
- swift-mailgun-types upward edge (L2-located package importing L3 URLFormCoding): re-point
  presets at the form-coder surfaces and adjudicate the package's layer location in its own
  right (out of this plan's scope to move the repo; the edge fix is in scope).

Gate B6: corpus parity (no wire change expected beyond B3/B4 ratified deltas); dep graphs
show zero 7230/7231, zero URLComponents in the routing core. **Approval: none beyond
ordinary commits, EXCEPT the deferred-exception record (Principal countersigns the two
[ARCH-LAYER-007] deferrals).**

## Batch 7 — Satellite dissolution + Foundation-free core

1. `Router.Input` reshape lands (method + decoded segments + ordered pairs + headers +
   `[Byte]` body — F2); `URI.Request.Data.body: Foundation.Data?` and the remaining
   Foundation types leave the core; URL/URLRequest/Data bridges move to the FI leaf
   (template: swift-url-routing-authentication's existing split).
2. Dissolutions (each: commit-first, verify-dead build-level, then delete —
   [ARCH-LAYER-009]): swift-form-coding (umbrella; its one W-3-STUB manifest edge in
   swift-types-foundation removed first), swift-url-routing-form-coding (after B5's `.form`
   de-dup; migrate its sole consumer swift-identities-types), swift-url-routing-tagged
   (Tagged support = a Router Core conformance, [MOD-020]), swift-url-routing-authentication
   (matching → Router Header over rfc-7617/6750; FI bridging → the routing FI leaf; compat
   spellings preserved as typealiases until the live consumers — mailgun-live BasicAuth,
   stripe-live BearerAuth, identities Bearer.Router — migrate).
3. swift-url-routing-translating: **DISSOLVE** (ratified 2026-07-20 — zero importers in the
   census, test target unbuildable as declared; the localized-routes concept re-enters, if
   ever ratified real, as the L4 reservation `swift-routers-translation`; no obligation to
   fill).
4. **The router rename (ratified)**: repo `swift-url-routing` → **`swift-routers`**;
   namespace root `Router` with `Router.Protocol`, `typealias Routing = Router.Protocol`
   ([PKG-NAME-002]), `Router.Witness`, `Router.Input`, attachment protocol `Routable`;
   `Router.Protocol` refines the spike-ratified canonical shape (`Coder where
   Buffer == Input` if B2's spike was GREEN). L4 cascade: `swift-url-routing-vapor` →
   `swift-routers-vapor`; the future HTTP bridge is minted as `swift-routers-http`
   (supersedes the networking program's reservation — pre-implementation rename licensed by
   that doc). Old module/package spellings ride the compat module until consumers migrate.
5. **DI dependency drop (ratified default)**: `swift-dual`, `swift-dependencies`,
   `swift-logger-dependencies` leave Router core; they may survive only in the FI leaf /
   Client surfaces on concrete evidence surfaced during this batch's Client split.
6. Naming/typed-throws remediation rides the reshape: builder-closure typed-throws cluster,
   compound-name renames with the PointFree.Compatibility shim carrying old spellings
   (deprecation period), multi-type file splits (12 files), Sendable fixes (BaseURLPrinter),
   and the Swift 6.3.x SIGSEGV workaround retirement IF the compiler issue is resolved by
   then (else keep workarounds and file the issue per issue-investigation).

Gate B7: full stack + all consumers green; `foundation_imports == 0` in every core target
(the two countersigned deferrals excepted); corpus parity modulo ratified deltas; compat
shims documented with retirement conditions. **Approval: each dissolution individually; the
breaking-rename set + compat policy; the translating disposition.**

## Batch 8 — Conformance sweep and close

- swift-linter (Bundle.institute), SwiftLint (org config, correct invocation), swift-format
  (canonical config) all green across the reshaped repos; B4 scorecard re-run to zero (or
  explicitly-exempted residue).
- README/DocC/[GH-REPO] metadata for the new and reshaped packages; research promotions per
  [RES-006a] (the body-coder contract and F1–F4 adjudications are skill-promotion
  candidates); reflect-session close.
- Final wire canary + parity report; archive the Batch-0 corpus as the permanent wire-shape
  regression suite.

Gate B8: scorecards attached; Principal acceptance ([SUPER]-style: the arc does not declare
itself done).

## Leverage ranking (why this order)

1. **Batch 4** — highest correctness leverage: closes the RT-030 structural class (44 live
   headerless routes in one consumer; silent-ignore PUT/PATCH failure mode on the wire).
2. **Batch 3** — the URI correctness fork sits under every route parse/print.
3. **Batch 5** — largest duplication mass (~1,035 LoC in-router coder + twice-defined
   strategy vocabulary + three multipart layers → one).
4. **Batch 7** — [ARCH-LAYER-007] end-state + the package-count collapse (10 repos → 3 L3 +
   2 L4 + FI leaves).
5. **Batches 1–2** — cheap enablers; front-loaded because everything later leans on them.

## Consumer-impact map (from the B5 census; sequencing only)

| Consumer | Files importing | Touched in batches | Highest-risk item |
|---|---|---|---|
| swift-stripe-types | 153 | B4 (143 `.form` routes), B5 (`.bracketsWithIndices`), B7 (bridge deletion — it consumes url-routing-form-coding heavily) | single-header-convention cutover with stripe-live |
| swift-identities-types | 78 | B4 (30 routes), B5, B7 (bridge + Bearer.Router) | bridge retirement |
| repotraffic | 51 | B3/B4 (print-side clients), B7 (SIGSEGV workaround retirement) | wire parity of href/remote clients |
| swift-authentication | 17 | B7 (auth dissolution; BaseURLPrinter Sendable) | compat spellings |
| swift-mailgun-types (+live, +mailgun) | 9/7/3 | B4 (44 routes, worst-first), B5 (strategy presets, rfc2822) | live-API canary discipline [TEST-040] |
| boiler | 6 | B4 (14 example routes), B6 (vapor bridge fix) | none (retiring per networking Wave 4) |
| github-types, favicon, github-live, stripe, types-foundation | 2 each | B4/B7 (types-foundation's FormCoding manifest edge removal) | trivial |

## Sequencing against the wider programs

- **Pure-Institute-Networking**: this plan is self-contained through Batch 8 and does NOT
  depend on Waves 2–3 (sockets/HTTP runtime). Two seams: (a) the execution-surface
  [ARCH-LAYER-007] deferral resolves when Wave 3's swift-http lands; (b) the L4
  `swift-url-routing-http` bridge is Wave 4's deliverable — this plan only guarantees the
  engine-free core it mounts. swift-url-routing-vapor survives until Wave 4 retires Vapor.
- **Foundation-removal arc**: Batches 6–7 deliver the routing stack's contribution; the two
  deferred exceptions (URLSession execution; information-storage quantity) are named,
  countersigned items on that arc's ledger, not silent residue.

## Deletions (named, per [ARCH-LAYER-009])

Packages: swift-form-coding, swift-url-routing-form-coding, swift-url-routing-tagged,
swift-url-routing-authentication (dissolved into L2 + core), swift-rfc-2388,
swift-multipart-form-coding (absorbed), swift-url-form-coding (absorbed into
swift-html-form-coder after the compat-shim period), swift-urlrequest-handler
(split/absorbed; execution successor lives with swift-http), swift-url-routing-translating
(dissolved; reservation `swift-routers-translation` recorded).
Code: the URLComponents façade, the in-router multipart coder + FileUpload MIME catalog,
the duplicate `.form` conversion, the hand-rolled pair codec, cookie grammar (moves), dead
operators, URLRouting.Client.DecodingError shape, RFC 7230/7231 composition.

## Approval gates

### RATIFIED (Principal, 2026-07-20 — dossier §Principal rulings)

- Type spellings `HTML.Form.Data` / `HTML.Form.Coder`; enctype-default variant structure
  (`HTML.Form.Coder` = urlencoded default; `.Multipart` marked variant; no `URLEncoded`
  token anywhere); strategy nest `HTML.Form.Coder.Strategy.*`.
- Package name `swift-html-form-coder`.
- Entry-list⇆wire step homed at L3 (no parser/serializer deps enter WHATWG packages;
  swift-uri-standard rejected as home). WHATWG changes limited to the `WHATWG_HTML.Form`
  nest alias + html-standard Forms re-exports (Batch 2).
- The final package roster below as the planning baseline.

### RATIFIED round 2 (Principal, 2026-07-20 — full gate adjudication)

- Repo creations approved: swift-http-body (B4), swift-html-form-coder (B5),
  swift-media-type-standard (B2), swift-parser-optic-primitives (B2).
- Behavior-change classes approved: B3 difference list (`%2F`-in-segment,
  percent-normalization, empty-vs-absent query); B4 per-consumer Content-Type emission.
- Dissolutions/deletions approved as staged: rfc-2388 (B5); the B7 satellite set incl.
  swift-url-routing-translating (DISSOLVE; reservation `swift-routers-translation`
  recorded); multipart-form-coding and url-form-coding absorptions; urlrequest-handler
  split.
- Naming cascade: **swift-routers** / `Router` / `Routing` alias / `Routable`; L4
  `swift-routers-{vapor,http}`; PointFree-heritage renames at B7 behind the compat module,
  compat retires at the Vapor-retirement boundary. `swift-router-primitives` REJECTED
  (dossier §rulings round 2 ¶6).
- [ARCH-LAYER-007] deferrals countersigned: URLSession execution until swift-http (Wave 3);
  information-storage quantity until its ISO/IEC 80000-13 home.
- Parity corpus: per-consumer `Tests/` + shared round-trip helpers in Router Test Support.
- swift-format: the strict variant becomes the org canonical at swift-institute/.github.
- DI deps (swift-dual / swift-dependencies / swift-logger-dependencies): default-DROP from
  Router core; FI-leaf/Client survival only on B7 evidence.
- The Coder-unification spike inserted as the B2 entry gate, GREEN outcome default.

### OPEN (execution-time only — auto-ruled for the overnight run, v1.3.0)

1. Spike verdict at the B2 entry gate (GREEN/RED — empirical; both outcomes fully scripted,
   GREEN's consumer sweep pre-enumerated by the 2026-07-20 census).
2. B3/B4 concrete-delta checks — delegated to the annex auto-rules (delta-class membership
   for B3; header-only deltas for B4); anything outside the rules is a STOP, not a
   judgment call.
3. Each batch's own verification gate; dissolution commits carry the execution stamp;
   morning items (wire canaries, repo archival, local dir renames, new-repo metadata/CI)
   are listed in the terminal report and block nothing overnight.

## Final package roster (ratified planning baseline, 2026-07-20)

Status legend: AS-IS (consumed unchanged) · MOD (in-place addition/fix) · NEW · RESHAPED ·
ABSORBED · DISSOLVED/DELETED · SPLIT · PENDING.

**L1 (swift-primitives)** — swift-parser-primitives MOD (printer conformances for
Many/Optionally/Rest/Prefix; value-checkpoint backtracking for OneOf/Optionally; 4
Bidirectional refinement declarations); swift-optic-primitives MOD (case-path derivation
macro); swift-parser-optic-primitives NEW-tiny (Prism → Parser.Conversion bridge); AS-IS:
swift-serializer-primitives, swift-coder-primitives, swift-either-primitives,
swift-tagged-primitives, swift-input-primitives, byte/ascii/binary-base families.

**L2 (swift-ietf)** — AS-IS: swift-rfc-3986, -3987, -6570 (expansion only), -9110, -9111,
-9112, -2045, -2183, -7617, -6750. MOD: swift-rfc-2046 (+`Boundary.random()`),
swift-rfc-7578 (+decode side), swift-rfc-6265 (+cookie grammar, relocated from the router),
swift-rfc-2822 (+§3.3 date-time). DISSOLVED: swift-rfc-2388.

**L2 (swift-whatwg)** — swift-whatwg-url AS-IS (Form URL Encoded pair codec);
swift-whatwg-html MOD-alias-only (`WHATWG_HTML.Form` nest; no dependency growth).

**L2 (swift-standards)** — swift-http-standard AS-IS; swift-uri-standard MOD (drift fix);
swift-html-standard MOD-re-export-only (Forms products); swift-media-type-standard NEW
(`RFC_2045.ContentType ⇄ RFC_9110.MediaType`).

**L3 (swift-foundations)** — swift-url-routing RESHAPED + RENAMED **swift-routers** at B7
(engine-free `Router` family over the spike-ratified canonical bidirectional shape;
`Routing` = `Router.Protocol` alias; `Routable`; RFC_3986-native `Router.Input`; targets
Core/Path/Query/Header/Body/Client/Handler/Template + Foundation Integration leaf + Test
Support; DI deps dropped from core); swift-http-body NEW (`HTTP.Body.Coder`
Content-Type-ownership contract + JSON lift); swift-html-form-coder NEW (`HTML.Form.Coder`
default + `.Multipart`; Strategy vocabulary; Nested keys; Codable leaf); swift-json AS-IS;
swift-http FUTURE (networking Wave 3 — receives execution).
ABSORBED: swift-url-form-coding, swift-multipart-form-coding. DELETED: swift-form-coding,
swift-url-routing-form-coding. DISSOLVED: swift-url-routing-tagged,
swift-url-routing-authentication, swift-url-routing-translating (reservation
`swift-routers-translation`). SPLIT: swift-urlrequest-handler.

**L4 (Components)** — swift-routers-http NEW (networking Wave 4 deliverable; supersedes the
`swift-url-routing-http` reservation); swift-url-routing-vapor → renamed
**swift-routers-vapor** at B7, then DELETED at Vapor retirement; vendor preset surfaces
stay in their existing `*-types` packages (content is L4-shaped; the mailgun-types upward
L3-import edge is fixed in B6; those packages' own layer location is a separate
adjudication).

Net: ten routing-stack repos → three L3 (swift-routers, swift-http-body,
swift-html-form-coder) + one terminal L4 bridge + one future L4 bridge, carried by two tiny
L1 additions, one new L2 converger, and in-place L2 additions.

## Implementation dispatch preamble (for the executing session — prep artifact, not started)

The implementation arc has NOT begun; nothing in any package repository has been modified by
the review sessions. A fresh implementation session should:

1. Load skills in order: swift-institute-core, swift-institute, swift-institute-ecosystem,
   modularization, code-surface, implementation, existing-infrastructure, swift-package,
   testing (+ swift-package-build for toolchain discipline; testing-institute before any
   snapshot corpus work).
2. Read the dossier (`url-routing-stack-first-principles-review.md`) then this plan; treat
   both as leads, not ground truth — re-verify every file:line anchor against live source
   before acting ([RES-013a]; all anchors date 2026-07-20).
3. Enter at Batch 0 (parity corpus). Do not reorder batches. The plan is fully ratified
   (v1.2.0); the only stop-points are the OPEN execution-time items: run the
   Coder-unification spike before any Batch-2 conformance work, and obtain the
   concrete-delta sign-offs at the B3/B4 gates.
4. Toolchain: TOOLCHAINS=org.swift.633202606251a, assert `swift-6.3.3-RELEASE` before any
   build ([PKG-BUILD]); one swift invocation at a time per repo; never delete or hand-edit
   Package.resolved (the mirror-corrupted-untracked-lockfile phenomenon is known and
   incidental — cold-room resolve for probes).
5. Honor [PKG-DEP-012] (consumer sweep in the same arc as any public-surface change) and
   [TEST-040] (live-mutating suites out of unattended gates; credential classification
   before any mailgun/stripe canary; mutation census on close).

## Stripe carve-out (v1.4.0 — Principal relay 3, 2026-07-21)

swift-stripe-types cannot execute its routers on the arc toolchain (§A9) and cannot
compile on the 6.4.x snapshot (Webhooks ICE), so its corpus-verified slices are
flip-deferred; the arc otherwise runs to completion on 6.3.3:

- **B0-stripe**: the fb60b1c Router Parity Tests scaffolding stands (fixtures
  auto-record at the flip). ADD a 6.3.3 micro-corpus of the two production compat
  branches (customers.create, checkoutSessions.create via the shipped
  `*.Router.Compat_Swift_6_3` single-branch routers — production prints them daily).
  Fallbacks in order: capture at repotraffic's HTTP boundary; else record the
  micro-corpus as unobtainable and stripe proceeds compile-only (reported, not
  stalling).
- **B3/B5/B7**: stripe migrations land COMPILE-GREEN on 6.3.3 behind compat
  typealiases; micro-corpus green required at each batch; full-corpus verification is
  flip-deferred.
- **B4**: the stripe slice becomes flip-gated mini-batch **B4-S** — the 143-route
  header cutover AND stripe-live's blanket-header retirement both wait; stripe wire
  behavior stays byte-unchanged until the gate. B4 completes ecosystem-wide otherwise.
- **B8 / FLIP GATE (named close-out gate)**: the first toolchain (6.4 RELEASE or
  Principal-ratified successor) on which swift-stripe-types COMPILES and the §A9
  Charges probe PASSES. At the gate: fixtures auto-record → full stripe corpus
  verifies → B4-S executes → stripe-live compensation retires → the 45 disabled
  suites re-enable → §A9's catalog row gets its empirical confirmation. Production-
  side retirement additionally waits for the production builder's (Heroku 6.3.3
  Jammy) ≥6.4 flip.

## Overnight end-to-end execution annex (v1.3.0 — Principal directive 2026-07-20)

The whole plan (B0→B8) executes in ONE unattended overnight run. Every formerly-attended
stop-point is replaced by the written auto-rules below; the run's only stop condition is a
red gate or an ambiguity not covered by a written rule (then: STOP + terminal report —
never improvise). Batches are strictly sequential; commit per logical unit; push per batch
after an abort-on-delta pre-verify (`git fetch` + rev-list 0 check); a stopped run resumes
from its last green checkpoint the next night.

### Delegated sign-off auto-rules (replace attended B3/B4 sign-offs)

- **B3 auto-rule**: proceed iff EVERY corpus delta falls in the three ratified classes
  (`%2F`-in-segment; percent-normalization edge cases; empty-vs-absent query fidelity).
  Any delta outside them → STOP, stage the annotated delta report, do not commit B3.
- **B4 auto-rule**: proceed iff each consumer's corpus delta is EXACTLY the addition of the
  expected `Content-Type` header (value per coder contract) and nothing else. Anything
  else → STOP for that consumer, stage evidence, continue only if remaining consumers are
  unaffected (else STOP the batch).
- **Wire canaries are OUT of the overnight run** ([TEST-040] standing rule; the 2026-07-12
  mailgun incident is the precedent). Overnight evidence = corpus + builds + provably-
  offline suites. The attended sandbox canaries are MORNING follow-ups and do NOT block
  B5–B8 (nothing downstream consumes canary results).
- **Spike GREEN**: full unification executes overnight, including the `Parser.Printer`
  retirement, using the pre-enumerated census sweep (B2 entry gate above). Spike RED: F1
  role split stands; commit the impossibility record; continue with Printer-side rows.

### Live-suite exclusion (hard)

Never execute: `swift-mailgun-live`, `swift-stripe-live`, `swift-github-live` test suites,
or any suite that reaches an external API with ambient credentials. Gate = build +
provably-offline suites. If any live call is discovered to have run: record it in the
mutation census section of the terminal report.

### New-repo bootstrap recipe (verified mechanism — the skill-cited sync scripts do NOT
exist; the mirror table is the GLOBAL `~/.swiftpm/configuration/mirrors.json`, 1,250
entries, per-arc backup convention)

For each ratified creation (swift-media-type-standard, swift-parser-optic-primitives,
swift-http-body, swift-html-form-coder), at the batch that needs it:
1. `cp ~/.swiftpm/configuration/mirrors.json ~/.swiftpm/configuration/mirrors.json.bak-routers-endstate-<UTC-ts>`
   (ONCE, at first creation).
2. Create the local package at its org-correct path (swift-standards/, swift-primitives/,
   swift-foundations/); nested `Tests/Package.swift` per [INST-TEST-001]; `Lint.swift` with
   `Bundle.institute` (L3) / `Bundle.primitives` (L1) / `Bundle.standards` (L2); tools
   6.3.3; platforms .v26.
3. `gh repo create <org>/<name> --private` + first push (creation is round-2-ratified;
   PRIVATE until release-readiness).
4. Append BOTH URL spellings (`.git` and bare) → local path to the global mirrors.json.
5. Consumers declare the canonical `.git` + `branch: "main"` spelling ([PKG-DEP-009]).
6. metadata.yaml / CI caller / social preview are morning items (non-blocking).

### B7 rename sequence (identity-safe, verified mechanism)

1. `gh repo rename swift-routers` on swift-url-routing (GitHub redirect persists); same for
   swift-url-routing-vapor → swift-routers-vapor.
2. mirrors.json: ADD new-spelling entries (both forms) pointing at the EXISTING local
   paths; KEEP the old-spelling entries. Do NOT rename the local directories overnight
   (1,250 mirror entries reference them; dir rename + workspace refs are a morning
   cosmetic item).
3. Normalize every consumer manifest to the new canonical spelling IN THE SAME WAVE, then
   sweep-assert zero old spellings remain in committed manifests:
   `/usr/bin/grep -rn "swift-url-routing" --include=Package.swift <all consumer roots>`
   (expected survivors: none, once the satellites are dissolved). One spelling per
   identity, everywhere, or the resolver's identity-conflict walk fires (catalog §A26).
4. GitHub-side ARCHIVAL/DELETION of dissolved repos is NOT an overnight action: overnight
   does content-level dissolution only (consumers migrated, deps removed, README tombstone
   commit); repo archival is a listed morning item for the Principal.

### B0 determinism rule

Pin the multipart boundary by injection where the encoder API allows; where it does not
(B0 forbids source changes), normalize the boundary token via regex before snapshot
comparison, and note each normalized site for B2's `Boundary.random()` work.

### Preflight assertions (run step 0; abort the run on any failure)

1. `date` (anchor all report timestamps from it).
2. `TOOLCHAINS=org.swift.633202606251a swift --version` → must report 6.3.3-RELEASE.
3. Clean-tree sweep: `git -C <repo> status --porcelain` across the 10 stack repos + the
   consumer set (stripe-types, identities-types, repotraffic, authentication,
   mailgun-types/-live/mailgun, boiler, github-types, favicon, types-foundation,
   stripe-live, github-live, dual) + swift-parser-primitives, swift-byte-parser-primitives,
   swift-rfc-8259 — empty, MODULO the "Preflight whitelist" section that the pre-overnight
   prep session appends to HANDOFF-routers-endstate-overnight-2026-07-20.md (known-class
   untracked files only, e.g. mirror-corrupted untracked Package.resolved). Any dirty
   TRACKED file, or any untracked file not on the whitelist → list it in the abort report;
   do NOT stash/clean ([workspace rule: protect user work]).
4. mirrors.json backup taken; `gh auth status` succeeds.
5. Confirm-by-absence: no other live session holds these repos (no foreign lock files, no
   in-flight rebase/merge state in any repo).

### Run protocol (no /goal skill exists on disk — self-paced)

- Completion condition: B8 gate evidence attached, OR first red gate/uncovered ambiguity.
- After each batch gate: append a checkpoint line (batch, gate result, commit SHAs, `date`)
  to the terminal report file.
- Terminal report: `swift-institute/Workspace/handoffs/REPORT-routers-endstate-overnight-<date>.md`
  — per-batch evidence, corpus-delta summaries, census of pushes, morning-items list
  (canaries, repo archival, dir renames, metadata/CI for new repos), mutation census
  (expected: none), and — on a stop — the exact resume point and why.
- Subagent lanes MAY parallelize within a batch (consumer sweeps, corpus capture); the
  coordinator itself follows this plan strictly and stays foreground-disciplined.

## Consolidated relay rulings (v1.5.0 — governing; supersedes chat-relay state)

Principal relays 4, 4-addendum, and 5 (2026-07-21), consolidated verbatim-in-substance so
the executing session needs no chat history. Where these conflict with earlier sections,
THESE govern.

### Ratifications

- **Boiler**: example-corpus DESCOPED. Boiler's parity obligation is compile-green only;
  its live mount path is covered via repotraffic's corpus. The rotted pre-W2 example
  packages are excluded from builds; their deletion rides the B7 dissolution wave.
- **swift-email-standard**: the missing `try` against rfc-5322's typed-throws
  `Message.init` (cross-repo compile break on main, boiler-lane discovery) — the minimal
  fix is AUTHORIZED as a B1-gate unblocker (one commit, ordinary push).
- **Minimum-viable rule** for dissolution-bound components (translating, form-coding,
  url-routing-form-coding, tagged, boiler examples): only work a batch gate strictly
  requires. No test repairs, no polish.

### Execution posture

- **Effort tiers**: design-sensitive lanes (B2 unification spike, B3 engine swap, B5
  extraction, B7 reshape) run at RAISED effort; mechanical lanes stay low.
- **Item-scoped STOPs**: stage the item's evidence, continue every lane the item does not
  block, accumulate non-blocking questions in the report's ratification queue; run-scoped
  STOP only when the item blocks the current batch's gate.
- **Scoped corpus re-runs**: re-run a consumer's corpus only when the batch touched a
  repo that consumer imports (engine changes = all; satellite changes = few).

### Build posture: EDIT MODE (arc-scoped; replaces per-gate pin advances)

Mirrors localize fetching, not revision selection — pinned lockfiles made every gate
re-test stale code until a per-consumer `swift package update`. Therefore, for the arc's
duration:

1. Spike on one consumer first (swift-mailgun-types): `swift package edit <dep> --path
   <local clone>` for each stack dep; verify a trivial local url-routing change is
   visible with no update step; then roll out to the whole gate set.
2. Gitignore `Packages/` in each consumer BEFORE the first edit command (the
   swift-form-coding fossil symlink is the precedent). Never commit edit-mode state.
   Package.resolved files stop churning; stale pins are inert while edited.
3. Gate discipline: at every batch gate, assert the stack repos' working trees are CLEAN
   and record their HEAD SHAs in the checkpoint line — edit-mode gates test those SHAs.
4. ARC CLOSE (B8): `swift package unedit` everywhere, then one final pin-advance wave +
   commit of tracked lockfiles — the shipping state is fully pinned at final SHAs.
5. Cross-repo parallelism: the one-swift-invocation rule is PER REPO; up to 4 concurrent
   consumer lanes across different repos. On SwiftPM shared-cache lock contention, drop
   to serial and note it.
6. The Principal may hold a scoped Xcode workspace open over the arc packages. If a gate
   finds a Package.resolved dirtied by Xcode auto-resolution (and nothing else): note it
   in the checkpoint, treat the pinned file as inert (edit-mode governs), continue.

### Worker refresh protocol

The executing session is retired and replaced at the next clean point (immediately, if the
Principal interrupts; otherwise at the current batch gate). Refresh handoff, in order:

a. Push sweep — every touched repo at rev-list 0 vs origin; no uncommitted work anywhere
   (lanes included; the coder-unification-spike experiment package committed as-is).
b. Terminal-report hygiene: append a REFRESH CHECKPOINT section (batch position, per-repo
   SHAs, spike-lane state, ratification queue, exact resume point) and mark the
   superseded stop-state sections as historical.
c. Mirror the resume point into the HANDOFF file. Then END the session — no new batch
   work after the checkpoint.

Successor bootstrap (Principal pastes into the fresh session): read, in order, (1) this
plan (v1.5.0 — this section governs), (2) the REFRESH CHECKPOINT in the terminal report,
(3) the HANDOFF file. Load the handoff's skill order. Verify the checkpoint's claims
against git before acting ([RES-013a]). Resume at the recorded point. All standing rules
apply: STOP-don't-improvise (item-scoped), live-suite exclusion, protect-user-work, push
discipline, checkpoint lines, effort tiers per this section.

## Post-B2 transition rulings (v1.6.0 — steering consolidation, 2026-07-21)

Consolidates the Principal's post-B2 rulings at the agent-team transition. Supersedes the
"edit-all switchover" advance notice (relay 7): that switchover is CANCELLED — fleet
edit-all was refuted on speed (swiftpm-path-semantics-with-url-manifests.md v1.1.0 §E5:
~33 s per warm edit, ~1.7 h to arm one mid-sized consumer). This section governs from B3.

### 1. B2-gate pause released

B0, B1, B2 are GREEN (Workspace terminal report, checkpoint `09ff86b7`). The pause at the
B2 gate is lifted; the arc resumes at **B3** (raised-effort lane, delta-class auto-rule
unchanged).

### 2. Arc build posture — FINAL

- **Scoped edit-mode stays through B8.** It is armed across the consumer set, probe-clean
  (17/17 at B2 close), and pin-ceremony-free. No posture change for the rest of the arc.
- **Never `rm -rf .build`.** Use `swift package clean` — verified to PRESERVE edit state
  (study v1.1.0). If `.build` removal ever genuinely happens, re-arm via the Scripts
  triple and re-run the probe before trusting any build.
- Arming/teardown/probe are script-owned: `edit-all.sh` / `unedit-all.sh` /
  `edit-status.sh` (swift-institute/Scripts `0a98201`; dep list derived from mirror
  table ∩ resolved graph). The empty edit-status probe remains a REQUIRED batch-gate item.
- Pin advances remain forbidden (item-scoped STOP), unchanged.

### 3. ARC CLOSE (B8) amended

§Consolidated relay rulings item 4 (unedit + final pin-advance wave + tracked-lockfile
commit) is SUPERSEDED. Under the ratified policy ("local = live trees, CI = resolved
versions"), local pins carry no evidence weight and `Package.resolved` is untracked in
the stack repos. B8 close is now:

a. `unedit-all` sweep across the consumer set (tree-preserving), empty-probe verified;
b. push sweep — every repo rev-list-0-verified, clean trees;
c. **CI green on committed state** for the stack + consumer set (CI resolves fresh from
   committed manifests) — this is the close evidence, strictly stronger than a local pin
   wave. No pin-advance wave; no lockfile commits.

### 4. Execution model — agent-team session

The arc's executor from B3 onward is a single agent-team session
(CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS). Rules:

- **The lead is the sole gatekeeper**: reads this plan, assigns lanes, verifies every
  lane's claimed exit status from logs before accepting it, writes all checkpoint lines
  and all pushes' pre-verification, adjudicates item-scoped STOPs (unresolvable →
  surface to Principal and hold that item only).
- Teammates run per-repo lanes (corpus re-runs, consumer sweeps, additive rows). All
  standing rules bind every teammate: toolchain assert before builds, one swift
  invocation per repo at a time, ≤4 concurrent build lanes across the team (shared-cache
  contention → drop to serial and note it), live-suite exclusion, protect-user-work,
  [RES-013a] verify-before-acting.
- Gates are SERIALIZED in the lead — no teammate declares or crosses a gate.

### 5. Immediate tasks at resume (before/alongside B3 entry)

1. Create GitHub remotes (PRIVATE, annex bootstrap recipe — already authorized) + first
   push for the two local-only repos: `swift-standards/swift-media-type-standard`
   (`86c7b9c`) and `swift-primitives/swift-parser-optic-primitives` (`34b18c3`); then
   metadata.yaml/CI/social-preview for both (parallel lane).
2. Enter B3 per §Batch 3 with scoped corpus re-runs (engine change ⇒ all consumers).

### 6. Parked for Principal (NOT arc blockers — do not act)

- Rescoping the Xcode-workspace rejection (local-iteration vehicle vs gate vehicle).
- Implementing the CI never-live/never-edited guard (spec in the path-semantics study).
- SwiftPM feature request (batch edit registration / first-class override file).
- Batch-seeded edit-state pilot (study recommends NO).
- Ratification queue items 1–8 in the terminal report (incl. the countersign placement
  deviation and the swift-ietf/ path-table correction).
