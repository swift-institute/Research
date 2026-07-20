# URL-Routing Stack Migration Plan (Staged)

<!--
---
version: 1.0.0
last_updated: 2026-07-20
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

Companion to `url-routing-stack-first-principles-review.md` (the dossier — findings, ideal
map, dispositions). This plan stages the migration; it authorizes nothing. Every batch names
its approval gate; repository creation, dissolution, visibility changes, and behavior-changing
wire output all require explicit Principal approval before execution (workspace rules;
[ARCH-LAYER-009] guards for every deletion: commit-first, verify-dead).

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

| Item | Home | Retires |
|---|---|---|
| `Parser.Printer` conformances for `Many` (separator round-trip), `Optionally`, `Rest`/`Prefix` | L1 swift-parser-primitives | enables B5/B7 printer-side consolidation |
| Value-checkpoint backtracking for `OneOf`/`Optionally` (Copyable carriers) | L1 swift-parser-primitives | B2-16 combinator twins (retired in B7) |
| Four `Parser.Bidirectional` refinement declarations | L1 swift-parser-primitives | B2-17 retroactive patches |
| Case-path derivation macro (`Optic.Prism` per enum case) + Prism→`Parser.Conversion` bridge | L1 swift-optic-primitives (+ tiny swift-parser-optic-primitives) | per-case boilerplate in every consumer router |
| `RFC_2046.Boundary.random()` (validated generator) | L2 swift-rfc-2046 | B2-11 three hand-rolled `__unchecked` sites |
| RFC 7578 decode side (field/file projection, §5 charset) | L2 swift-rfc-7578 | B2-09's JSON-round-trip decode path |
| Media-type convergence `RFC_2045.ContentType ⇄ RFC_9110.MediaType` | L2 swift-standards/swift-media-type-standard (NEW package) — fallback: conversion inits in swift-http-body | B2-13 MIME-catalog duplication; enables the multipart coder's MediaType contract |
| uri-standard drift fix (delete reimplemented percent free functions; converge 3987) | L2 swift-uri-standard | A2 gap 5 |
| RFC 2822 §3.3 date-time machinery | L2 swift-rfc-2822 | mailgun preset's hand-rolled `rfc2822Formatter` (B2-19) |
| Cookie grammar (Set-Cookie/Cookie per RFC 6265) | L2 swift-rfc-6265 | prepares B6's cookie relocation (B2-04) |

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

1. Create `swift-form-coder` (NEW L3 repo) per the ideal map: Form Coder (typed ⇆ WHATWG
   entry list), Form Coder URL Encoded (⇆ wire via `WHATWG_Form_URL_Encoded`; conforms
   `HTTP.Body.Coder`), Form Coder Multipart (⇆ wire via RFC 2046/7578 + Boundary.random();
   conforms `HTTP.Body.Coder`), Form Coder Nested (bracket-notation convention, relocated
   from rfc-2388), Form Coder Codable (opt-in visitor bridge — the ONE place stdlib Codable
   witnesses live; resolves B4's Codable-wall finding structurally).
2. ONE strategy vocabulary (Bool/date/data/array/nesting) defined once in Form Coder and
   consumed by both wire targets — retires the RT-030b asymmetry class (B2-06). Parity: the
   union of both current vocabularies, each preset corpus-verified.
3. Extract the ~1,035-line in-router multipart machinery (Multipart.*, FileUpload.*) onto the
   new targets; wire format stays L2; `Multipart.File` unifies with `RFC_7578.Form.Data.File`
   (B2-10); decode drops the JSONSerialization round-trip for the RFC 7578 decode side
   (B2-09); the `RFC_2046` namespace injection ends.
4. swift-url-form-coding's Form.Encoder/Decoder become the Form Coder URL Encoded + Codable
   surfaces (compat typealiases in place until consumers migrate); the hand-rolled pair
   split/serialize (B2-03) delegates to the WHATWG codec. swift-multipart-form-coding is
   absorbed. De-duplicate `.form` (keep exactly one conversion; B2-20).
5. rfc-2388 dissolution: content relocates to Form Coder Nested; the L2 package retires
   ([ARCH-LAYER-009] guards).

Gate B5: Batch-0 form + multipart corpora byte-identical (boundary pinned) modulo the
Batch-4-ratified header additions; strategy-preset parity table complete; consumers green
(mailgun-types strategy configs, stripe `.bracketsWithIndices`, identities). **Approval: new
repo `swift-form-coder`; dissolution of swift-rfc-2388; absorption of
swift-multipart-form-coding.**

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
3. swift-url-routing-translating: re-home as L4 adapter or dissolve — Principal call on
   whether the localized-routes concern is real ([MOD-DOMAIN]).
4. Naming/typed-throws remediation rides the reshape: builder-closure typed-throws cluster,
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
swift-multipart-form-coding (absorbed), swift-urlrequest-handler (split/absorbed; execution
successor lives with swift-http). Pending Principal call: swift-url-routing-translating.
Code: the URLComponents façade, the in-router multipart coder + FileUpload MIME catalog,
the duplicate `.form` conversion, the hand-rolled pair codec, cookie grammar (moves), dead
operators, URLRouting.Client.DecodingError shape, RFC 7230/7231 composition.

## Approval gates (consolidated for adjudication)

1. New repos: swift-http-body (B4), swift-form-coder (B5), swift-media-type-standard (B2).
2. Behavior changes: B3 difference list (percent-correct URI engine); B4 per-consumer
   Content-Type emission.
3. Dissolutions/deletions: rfc-2388 (B5); the Batch-7 satellite set; multipart-form-coding
   absorption; urlrequest-handler split.
4. Naming: `swift-url-routing` field-register reading vs `swift-url-router`
   ([PKG-NAME-017]); the breaking-rename + compat-shim policy for PointFree-heritage names.
5. [ARCH-LAYER-007] deferrals: URLSession execution until swift-http; Measurement
   information-storage quantity until its institute home exists (candidate: ISO/IEC 80000-13).
6. swift-url-routing-translating: real L4 concern or dissolve.
7. Parity-corpus home (B0) and the canonical swift-format config variant (B1).
