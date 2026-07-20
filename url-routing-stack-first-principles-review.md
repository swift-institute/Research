# URL-Routing Stack First-Principles Review

<!--
---
version: 1.2.0
last_updated: 2026-07-20
status: RECOMMENDATION
tier: 2
scope: cross-package
changelog:
  - 1.2.0 (2026-07-20): second ratification round — ALL open approval gates adjudicated and
    Principal-ratified (see §Principal rulings, round 2): swift-routers naming cascade
    (router over routing), router-primitives rejected, translating dissolution, deferrals
    countersigned, DI deps default-dropped, Bidirectional/Coder unification spike inserted
    as a B2 entry gate. Verified-at-source L1 shape record added (Printer ≅
    Serializer|Buffer==Input modulo prepend/append; Serializer HAS Body/Builder — the
    leaf-pin is on Coder only). Companion plan status → APPROVED.
  - 1.1.0 (2026-07-20): Principal rulings incorporated — HTML.Form.Data / HTML.Form.Coder
    spellings approved; Form.Coder.URLEncoded rejected, replaced by the enctype-default
    derivation (Coder default = urlencoded, .Multipart variant); package named
    swift-html-form-coder; entry-list⇆wire stays L3 (no parser/serializer deps added to
    WHATWG packages); uri-standard rejected as home. See §Principal rulings.
  - 1.0.0 (2026-07-20): initial three-track review.
---
-->

## Context

Principal-directed first-principles review (2026-07-20) of the L3 URL-routing stack:
`swift-url-routing`, `swift-url-form-coding`, `swift-url-routing-vapor`,
`swift-url-routing-authentication`, plus the six adjacent repos discovered in scope
(`swift-url-routing-form-coding`, `swift-url-routing-tagged`, `swift-url-routing-translating`,
`swift-form-coding`, `swift-multipart-form-coding`, `swift-urlrequest-handler`). Form
encoding and the coder family are first-class review subjects (Principal directive
2026-07-20), not satellites.

Skills loaded ([RES-033]): swift-institute-core, swift-institute, swift-institute-ecosystem,
modularization, code-surface, implementation, existing-infrastructure, swift-package, testing,
research-process.

Prior arcs this review builds on ([RES-019] step-0 grep):

- **Routing W2/W3 (2026-07-11/12)**: swift-url-routing is an institute-native rewrite —
  pointfree-compatible DSL over L1 `swift-parser-primitives`, zero pointfreeco identities in
  pins; ~10 consumers migrated onto it. The W2 close filed an unexecuted action item to record
  exactly the insights this review targets (Foundation in the L3 main target, per-combinator
  typed throws) — this dossier discharges it
  (`Research/Reflections/2026-07-11-routing-w2-dsl-restore-wave-close-and-sample-caught-doc-drift.md`).
- **Pure-Institute-Networking program** (`Research/Pure-Institute-Networking/`): ratified role
  for swift-url-routing — "URI parser-printer; retain engine-free core; remove HTTP carrier's
  RFC 7230/7231/`Data` coupling into integration"; `swift-url-routing-http` (L4) replaces
  `swift-url-routing-vapor` (target-package-and-layer-architecture.md §Retain table,
  §Dedicated integrations). This review's Track A independently re-derives and refines that
  shape; the migration plan sequences against the program's Wave 3/4.
- **RepoTraffic RT-030 arc (2026-07-19/20)**: the Track-B seed evidence — MeasurementFormatter
  Linux break (fixed point-wise), RT-030b Form-coder Bool-strategy asymmetry, RT-030c
  body-conversions-cannot-set-headers structural defect
  (`repotraffic/Reports/2026-07-20-repotraffic-day-report.md` §8, §10).

Layer-trust prior (Principal directive 2026-07-20): L1 assumed mostly correct; L2 assumed
correct in what exists but open to additions; **L3 mostly suspect — the burden of proof is on
KEEPING each L3 component** ([MOD-DOMAIN] concept test). Correctness-driven only; consumer
counts appear nowhere as keep/delete arguments ([ARCH-LAYER-006]/[ARCH-LAYER-008]).

## Question

Is the routing stack's suspected structural rot real — duplication of machinery that belongs
to (or exists at) L1/L2, poor decomposition, lack of re-use, residual Foundation binding —
and what is the correct end-state shape plus the staged path to it?

## Method

Three tracks. **Track A** derived the ideal shape BLIND — its agents never read routing-stack
sources; inputs were the L1/L2 inventories and the layer rules only. **Track B** audited what
exists (module map, duplication, Foundation binding, rule/lint status, consumer usage), every
claim cited to file:line. **Track C** (this document + the companion migration plan) diffs
them. Seven research agents executed A1/A2/A3 and B1–B5; all probes were read-only (no repo
mutation; builds/lint only in cold-room copies). Companion plan:
`url-routing-stack-migration-plan.md`.

---

## Track A — the ideal shape (derived blind)

### A1: L1 inventory (swift-primitives)

The L1 spine for this domain is real and mature:

- `swift-parser-primitives` (134 src / 33 test files): typed-throws `Parser.Protocol` with
  `@Parser.Builder` bodies, ~36 combinator micro-products, **plus the bidirectional half**:
  `Parser.Printer` (Parser.Printer.swift:46), `Parser.Bidirectional` with round-trip laws
  (Parser.Bidirectional.swift:40), `Parser.Conversion` apply/unapply
  (Parser.Conversion.Protocol.swift:60,70).
- `swift-serializer-primitives` (Serializer.Protocol, append-into-buffer), and the thin
  `swift-coder-primitives` spine link: `Coder.Protocol: Parser.Protocol & Serializer.Protocol`
  (Coder.Protocol.swift:48) — coders are deliberately leaves (no Body/Builder,
  Coder.Protocol.swift:29–31).
- Byte/ASCII/binary families incl. `Binary.Base.16/32/58/62/64/85` (the L1 base-N codec
  precedent), `Byte.Input` as the canonical parse input, `swift-optic-primitives`
  (hand-written prisms, no case-path macro), `swift-either-primitives`, `swift-tagged-primitives`.

L1 deliberately does NOT have: a percent-encoding codec (building blocks only; the RFC 4648
precedent routes spec-named codecs to L2 — Byte.swift:33–36), a query-pair vocabulary, or
Codable visitor machinery (the L1 `Codable` attachment protocol means explicit-canonical-coder
discovery, Codable.swift:29). Verified L1 gaps: no `Printer` conformances for `Many`, plain
`Map`, `Filter`, `FlatMap`, `Prefix`, `Rest`, `Optionally` — repeated structure does not yet
round-trip compositionally.

### A2: L2 inventory (standards)

The spec surfaces the routing domain needs largely already exist:

- **RFC_3986.URI** — mature (31 src files): component nests, typed throws, byte-level
  parse/serialize. **Percent-encoding lives here**: `String.percentEncoded(allowing:)` /
  `percentDecoded()` (String.swift:22,:39), byte parser `RFC_3986.Parse.PercentEncoded`
  (…:41), CharacterSet vocabulary (RFC_3986.CharacterSet.swift:92–176). Query already models
  ordered `[(key, value?)]` pairs. §5 reference resolution is present
  (RFC_3986.URI.swift:857–947).
- **WHATWG form-urlencoded exists at L2, spec-correctly homed**: swift-whatwg-url ships a
  dedicated product `WHATWG Form URL Encoded` (URL spec §5): `serialize`/`parse` pair codec
  (URLEncoding.swift:46,:69), form-flavored percent-encoding (space-as-plus), plus full
  `URL.Search.Params`. swift-whatwg-html holds the HTML-spec entry-list model
  (`Form.Data.Entry.List` + File/Value) whose doc comment explicitly delegates coding to L3.
- **RFC_2046.Multipart at L2 is NOT a stub**: generic `serialize<Buffer>` (Multipart.swift:199)
  AND a byte-level `Multipart.Parser` (Parser.swift:52). RFC_2183 ContentDisposition with
  validated Filename exists. `swift-rfc-7578` exists but is encode-only
  (`RFC_2046.Multipart.formData(fields:files:boundary:)` veneer; no decode/field-projection).
- **RFC_9110** is rich (48 src files): Method, Header.Field vocabulary, Request/Response with
  `body: [Byte]?`, typed `MediaType` with `.formUrlEncoded`/`.formData` statics; 9111/9112
  present; swift-http-standard pins `HTTP = RFC_9110`.
- **L2 defects found**: `swift-rfc-2388` carries misnamed content — a bracket-notation
  (`user[name]`, `tags[]`) urlencoded FormData tree (a PHP/Rack convention, in no spec) with an
  IETF→WHATWG cross-authority dep and a top-level `FormData` naming violation.
  `swift-uri-standard` is thin and REIMPLEMENTS percent-encode/decode as free functions
  (drift risk vs RFC_3986's own). No `RFC_2045.ContentType ⇄ RFC_9110.MediaType` bridge exists
  (two parallel media-type vocabularies). `swift-rfc-6265` (cookies) is an empty stub whose own
  doc delegates to url-routing (RFC_6265.swift:8–9) — inverted layering.
- Correction recorded post-blind ([RES-013a]): A3's probe missed `swift-rfc-7617` (7 src
  files, 2026-07-14) and `swift-rfc-6750` (3 src files, 2026-07-11) — both EXIST at L2 and are
  already consumed by swift-url-routing-authentication. A3's map row "NEW" for these becomes
  "consume as-is", which strengthens the auth-dissolution disposition below.

### A3: the theorized ideal map

Full derivation with the concern-by-concern [ECO-002]/[MOD-PLACE]/[MOD-DOMAIN] reasoning is
reproduced in the plan's appendix references; the result:

**The derived-minimal L3 set is exactly three packages.**

| Package | Layer | Mission |
|---|---|---|
| `swift-url-routing` (reshaped) | L3 | Bidirectional, engine-free mapping between HTTP requests and typed route values. Targets: Router Core (`Router.Input` = method + decoded `[String]` path segments + ordered query pairs + headers + `[Byte]` body; `Router.Protocol` = constrained refinement of `Parser.Bidirectional`), Router Path / Query / Header, Router Body, Router Client (print + §5 resolve → `HTTP.Request`; execution stays in swift-http), Router Handler (engine-free dispatch), Router Template (RFC 6570 → router compilation), Foundation Integration leaf, Test Support. |
| `swift-http-body` (new) | L3 | The media-typed body coding contract: **a coder that installs an HTTP body owns and enforces its Content-Type.** `HTTP.Body.Coder` refines `Coder.Protocol` with `static contentType: HTTP.MediaType` + `accepts(_:)`; coupled `HTTP.Request` mutators make header/body drift structurally impossible at every entry point. Opt-in `HTTP Body JSON` target lifts swift-json. |
| `swift-form-coder` (new) | L3 | Typed coding of HTML form payloads over the WHATWG entry-list pivot, in both wire formats. Targets: Form Coder (typed ⇆ entry list), Form Coder URL Encoded (⇆ wire via WHATWG pair codec; conforms `HTTP.Body.Coder`), Form Coder Multipart (⇆ wire via RFC 2046/7578; conforms `HTTP.Body.Coder`), Form Coder Nested (relocated ex-rfc-2388 bracket convention), Form Coder Codable (opt-in visitor bridge — never the spine). |

L2 additions/corrections: RFC 7578 decode side; `swift-media-type-standard` (converge
`RFC_2045.ContentType ⇄ RFC_9110.MediaType`, [ECO-005]); uri-standard drift fix; rfc-2388
dissolution (content → Form Coder Nested); rfc-6265 gains the cookie grammar (see B2-04).
L1 additions: printer conformances for Many/Optionally/Rest (mandatory once Bidirectional is
the spine); enum-case conversion derivation (optic macro + tiny Prism→Conversion bridge).

Dispositions derived blind: **auth-routing dissolves** (L2 credential grammars + Router
Header; no residual [MOD-DOMAIN] concept — fails [MOD-RENT]); per-feature satellites (tagged,
form-coding lifts) dissolve into core ([MOD-020]: zero-dep-delta satellites fail); server
adapters are L4 leaves (`swift-url-routing-http`, `-vapor`); URLRequest-handling splits
(bridging → Foundation Integration leaf; execution → swift-http); per-API preset kits are L4.

*Post-review naming rulings amend this map — the blind record above is preserved as derived;
see §Principal rulings for the ratified names (`swift-form-coder` → `swift-html-form-coder`,
variant structure, and the L2 alias mechanics).*

Design-fork adjudications (recommendations): **F1** `Parser.Bidirectional` is the routing
spine, `Coder.Protocol` is the body-codec shape — they meet at exactly one point (Router Body
lifts an `HTTP.Body.Coder`). **F2** the router consumes structured, per-component,
percent-DECODED values (split path on `/` BEFORE decoding — `%2F` never a separator); bodies
stay bytes. **F3** explicit typed coders are canonical; the Codable bridge is an opt-in leaf,
never a routing dependency. **F4** one matching spine; RFC 6570 stays expansion-only at L2,
`Router Template` compiles templates onto the combinator spine.

---

## Track B — what exists (audited)

### B1: module map

All ten repos: branch main, clean trees, tools 6.3.3, platforms .v26, zero path deps, zero
pointfreeco identities ([PKG-DEP-010] clean — pointfree survives only in README/DocC prose).
swift-url-routing is the hub: 1 product, 71 files / 7,906 LoC over 13 narrow parser-primitives
products + 8 RFC packages + WHATWG + the form/multipart codecs. Notable drift, all cited:

- Dead declared dep `RFC 6570` (swift-url-routing/Package.swift:27,66 — zero imports).
- Undeclared re-exported deps: `@_exported import Collection_Slice_Primitives`
  (exports.swift:20) and `@_exported import WHATWG_HTML_Shared` (exports.swift:38) — neither
  package/product declared; both leak downstream ([MOD-038], [PKG-DEP-007] ADD-PRODUCT class).
- Still composes over obsoleted RFC 7230/7231 while swift-http-standard pins `HTTP = RFC_9110`
  — exactly the coupling the networking program ratified for removal.
- `swift-url-routing-translating` declares test target `URLRoutingTranslating Tests`
  (Package.swift:54,65) vs on-disk `Tests/URLRouting+Translating Tests/` — unbuildable as
  declared.
- Silent no-op `target.swiftSettings?.append` (nil receiver) in url-form-coding:50,
  form-coding:38, multipart-form-coding:61 — MemberImportVisibility never actually enabled.
- `swift-form-coding` is a 6-LoC umbrella with two declared-unused deps (Package.swift:19–20),
  an abandoned traits block, and a git-tracked symlink to the retired
  `/Users/coen/Developer/coenttb/` org path.
- `swift-url-routing-form-coding` (2-file bridge, extracted 07-13) vends a
  `public static func form<Value>` **byte-identical** to swift-url-routing's own
  `URLRouting.Conversion+form.swift:59` — importing both risks extension ambiguity; the bridge
  is functionally redundant as shipped.
- Three multipart layers coexist: L2 RFC_2046 wire + swift-url-routing's 9 `Multipart.*` +
  6 `FileUpload*` files + the MultipartFormCoding veneer.
- README/DocC of swift-url-routing still fully pointfree-branded (README.md:3–6).

### B2: duplication inventory (21 findings, both sides cited)

**The rewrite's core claim holds**: the DSL genuinely delegates to the 13 L1 parser products
including printing — the routing engine is proper L3 composition (B2-15). The prior "almost
all L3 is replaceable" is REFUTED for the engine and CONFIRMED for much of what surrounds it:

| # | Finding | Class | Evidence anchor |
|---|---|---|---|
| B2-01 | URI parse/print via Foundation URLComponents, bypassing the RFC_3986 engine the file is named after — a correctness fork | DUP | URIRequestData+RFC_3986.swift:25–27,91–128 vs RFC_3986.URI.swift:183/262/394 |
| B2-02 | Naive `/`-split before decode (breaks `%2F`), untyped String components | DUP | URI.Request.Data.swift:87 |
| B2-03 | urlencoded pair split/serialize hand-rolled though `WHATWG_Form_URL_Encoded.parse/serialize` exist | DUP | WHATWG_HTML.FormData.Parser.swift:46–58,108–129 vs URLEncoding.swift:46,69 |
| B2-04 | Cookie-string grammar implemented at L3 while swift-rfc-6265 is an empty stub delegating to url-routing | BELONGS-LOWER | HTTP.Cookie.Parser.swift:53–64 vs RFC_6265.swift:8–9 |
| B2-05 | Codable plumbing (KeyedContainer etc.) in the coders | GENUINE (per F3: localize to opt-in leaf) | — |
| B2-06 | Body-coder strategy vocabulary defined twice with drift (RT-030b generalized): Multipart Bool.Encoder (.trueFalse/.yesNo/.numeric, shipped 2025-11-15, hosted as `extension Swift.Bool`) vs Form coder `.yesNo` only 2026-07-20 (commit 3547120); multipart lacks Data/decoder strategies, form lacks `.numeric`/fileExtractor | BELONGS-LOWER (one shared strategy target) | full side-by-side in Track B2 report |
| B2-07 | Dead `>>>`/`\|>` operators in URLFormCoding (zero uses) | DELETE | — |
| B2-08 | ~1,035-line Codable⇄multipart coder inside the router, injected into the L2 namespace `RFC_2046.Multipart` | DUP/misplaced | Multipart.{Encoder,Field.Encoder,KeyedContainer,SingleValueContainer,Conversion,Parser,File,Array.EncodingStrategy}.swift |
| B2-09 | Multipart decode via JSONSerialization/JSONDecoder round-trip, zero decoding-strategy surface | DUP+GAP | Multipart.Conversion.swift:145–155 |
| B2-10 | `Multipart.File` duplicates `RFC_7578.Form.Data.File` in the same pipeline | DUP | Multipart.Field.Encoder.swift:28 |
| B2-11 | Boundary generation hand-rolled at three L3 sites via `__unchecked`+UUID; RFC_2046.Boundary has no generator; FileUpload.swift:130–131 falsely claims RFC compliance while bypassing validation | GAP at L2 (`Boundary.random()`) | three sites cited in report |
| B2-12 | Foundation base64 at 3 sites vs RFC_4648.Base64 | DUP | — |
| B2-13 | FileUpload MIME catalog rebuilds RFC_2045.ContentType presets with `__unchecked` | DUP | — |
| B2-14 | RFC 7230/7231 composition vs the RFC 9110 twins (Method/Header.Field/MediaType) | DUP | — |
| B2-16 | Three combinator twins forced by verified L1 parity gaps: OneOf/Optionally need value-checkpoint backtracking (Parser.OneOf.Two.swift:19 cursor-only; Parser.Optionally.swift:39 Failure==Never); Parser.Rest parse-only | BELONGS-LOWER (L1 gaps) | self-documented in-source (F1/GAP-4) |
| B2-17 | Four missing L1 `Parser.Bidirectional` refinement declarations patched retroactively at L3 | BELONGS-LOWER (trivial L1 fix) | Parser.Take+Bidirectional.swift:17–25 |
| B2-18 | Foundation JSON coding vs institute swift-json | DUP | — |
| B2-19 | Mailgun presets are genuine vendor knowledge, but `rfc2822Formatter` hand-rolls RFC 2822 §3.3 date-time (swift-rfc-2822 has no date machinery — L2 gap); mailgun-types (L2 location) importing L3 URLFormCoding is an upward edge | GEN + GAP + layering | — |
| B2-20 | Verbatim-duplicate `.form` conversion in swift-url-routing AND the -form-coding bridge | DUP | URLRouting.Conversion+form.swift:59 |

### B3: Foundation binding

Only `swift-url-routing-authentication` implements the [ARCH-LAYER-007] pattern (main target
0/7 Foundation files; URL/URLRequest quarantined in `Authentication Foundation Integration`).
Every other repo binds Foundation in its main target; headline metrics: swift-url-routing
34/71 files; url-form-coding 5/5; urlrequest-handler 4/4 with `@_exported import
FoundationNetworking` (exports.swift:3–4).

Engine-level (structural) bindings, worst first:

1. The request model itself: `URI.Request.Data.body: Foundation.Data?`
   (URI.Request.Data.swift:60) — ~30 public sites inherit it.
2. The "RFC-first" façade parses via URLComponents (URIRequestData+RFC_3986.swift:27,:91)
   despite native RFC_3986 parsers — the URI engine is Foundation-bound even on its
   non-Foundation path (same defect as B2-01).
3. The Vapor bridge re-parses through URL/URLComponents (…+Vapor.Request.swift:40–41) instead
   of using Vapor's parsed components.
4. Live client transport: URLRouting.Client (URLSession/HTTPURLResponse,
   URLRouting.Client.swift:39–224) + all of swift-urlrequest-handler — no institute
   alternative exists yet (`swift-foundations/swift-http` is an empty shell).

Classification: nearly everything is REPLACEABLE-NOW with verified ecosystem types
(RFC_3986.URI, RFC_4122.UUID, ISO_8601/time-standard, swift-json, RFC_4648/Binary.Base.64,
[Byte] for Data); URL/URLRequest bridges are RELOCATABLE (FI-target material, auth is the
template). Genuine gap-fills: an information-storage quantity (replaces
`Measurement<UnitInformationStorage>`, 8 public sites; home: ISO/IEC 80000-13 territory) and
the institute HTTP client/transport (networking-program Wave 3 dependency). The 2026-07-20
MeasurementFormatter point-fix is verified in place (Measurement+InformationStorage.swift:18).

### B4: rule findings + lint status

Scorecard (routing / url-form-coding / vapor / auth): untyped throws 80/119/4/3 (+16 rethrows
in routing); `try?` 4/0/0/1; public compound types 14/8/0/0; public compound members
65/35/0/4; multi-type files 12/0/0/0; dotless basenames 3/2/0/0. Zero XCTest. SwiftLint
0.63.3 totals 143/134/5/4 warnings (dominated by `typed_throws_required`); swift-format
538/0/0/0 (routing runs a stricter config — config drift, two variants across the four
repos); swift-linter configs are [LINT-SETUP]-conformant (`Bundle.institute`, no exclusions)
but the engine dep is pinned `branch:"main"` and a cold-room run exceeded a 10-minute budget
(pure SwiftPM resolution, visibly progressing — needs 30+ min headroom; not reproducible
under a branch pin).

Top structural readings: (1) routing's typed-throws CORE is done — 23/23 parse/print typed,
61 sites throw `RFC_3986.URI.Routing.Error`; residue is the builder-closure cluster, Client,
and FileUpload closures. (2) form-coding's 119 untyped throws are a **Codable wall** — stdlib
Encoder/Decoder witnesses cannot satisfy [API-ERR-001]; under F3 this localizes to the opt-in
Codable leaf rather than the spine, resolving the wall structurally. (3)
`URLRouting.Client.DecodingError` (URLRouting.Client.swift:64–67) is a triple violation
(compound name + bare `: Error` + `underlyingError: Error` existential). (4) Compound-name
mass is PointFree-heritage compat surface (ParserPrinter, FileUpload, OneOf …) — renames are
breaking; the compat locus exists (PointFree.Compatibility.swift). (5) The org SwiftLint
config false-greens when invoked via `--config <absolute path>` (SwiftLint ≥0.55 resolves
`included:` relative to the config dir — it lints ZERO files); any runbook using that
invocation reports clean without scanning.

### B5: consumer usage (sequencing evidence only)

Importer census (files importing routing modules): swift-stripe-types 153, swift-identities-types
78, repotraffic 51, swift-authentication 17, swift-mailgun-types 9 (+live 7, +mailgun 3),
boiler 6, stripe-live 4, github-types/favicon/github-live/stripe/types-foundation 2 each.
Zero importers: all of swift-ietf, swift-server-foundation(+vapor). `MultipartFormCoding` has
zero direct importers (reaches consumers only via URLRouting's re-export); `FormCoding`
umbrella has zero import statements anywhere (one manifest edge, marked "W-3-STUB … die at the
APP CUTOVER"); plain `Authentication` is imported only inside its own package.

Hot surfaces: router `var body` definitions (mailgun 33, stripe 83, identities 49, repotraffic
37, boiler 34); Path/Method/Query/Field/Optionally builders; `.form` conversions — **vended
twice and consumed split** (stripe 143 via the bridge; mailgun 36 via URLRouting's own);
Form.Encoder strategy configuration (`.yesNo` Lists.API.swift:404–418, `.bracketsWithIndices`
stripe FormCoding.swift:24 + identities Form.Coding.identities.swift:19); `.baseURL` (auth 80,
repotraffic 46); print-side clients (repotraffic `router.print → URLRequest(data:)`,
WaitingList.Client+Remote.swift:22); the Vapor bridge's sole source consumer is boiler
(Vapor.Application.mount.swift:32); Authentication compat spellings carry ALL live API traffic
(mailgun-live BasicAuth, stripe-live BearerAuth, identities RFC_6750.Bearer.Router:132).

**RT-030c residual class (verified at source)**: HTTP.Body.Parser never touches headers;
`Multipart.Conversion.swift:123` exposes `contentType` for MANUAL emission; the ContentType
combinator exists (HTTP.Header.Field.swift:168/214). Messages routes emit headers
(Messages.API.swift:37–39,55–57); the Lists fix landed (Lists.API.swift:140–146, 242–246).
残: **44 of 49 mailgun-types body routes still lack Content-Type**, including 15 PUTs + 1
PATCH in the documented silent-ignore failure mode — worst: `Lists.API.swift:298–315
cases.update` (PUT + multipart + no header = the exact RT-030b/c compound, unfixed). stripe's
143 headerless `.form` routes are compensated by a blanket header in stripe-live's auth
router (AuthenticatedClient.swift:106–112) — two coexisting header conventions is itself a
parity-gate item. Zero-reference surfaces (sweep-evidenced): URLRouting.Client, the
HTTP.Cookie parser family, URI.Fragment.Parser, WHATWG_HTML.FormData, `.host(`/`.scheme(`/
`.port(` combinators, FormCoding umbrella, direct MultipartFormCoding imports.

Consumer-pain ledger: Swift 6.3.x router SIGSEGV workarounds (repotraffic
App.run.swift:190–199; 2 stripe-types Compat_Swift_6_3 files; stripe-live compat);
BaseURLPrinter non-Sendable (swift-authentication Identity.Provider.Configuration.swift:133);
MemberImportVisibility annotations (repotraffic ×4).

---

## Track C — synthesis

### Verdict on the working hypothesis

**Confirmed with one decisive refinement.** The hypothesis "almost all current L3 code is
replaceable by composition over L1/L2 — or removable" is:

- **REFUTED for the routing engine**: the post-W2 DSL is genuine L3 composition over the L1
  bidirectional parser spine ([MOD-DOMAIN] passes: the Router/Route/Input concept). Track A,
  derived blind, independently lands on a `swift-url-routing` L3 package whose spine is
  exactly the machinery the rewrite already uses.
- **CONFIRMED for most of what surrounds the engine**: the URI engine fork (URLComponents vs
  RFC_3986), the in-router multipart Codable coder, the twice-defined strategy vocabulary,
  the cookie grammar, base64/JSON/MIME-catalog duplication, boundary generation, the
  RFC 7230/7231 composition, the redundant bridge/umbrella/satellite packages, and the
  Foundation-bound request model are all replaceable by (or relocatable to) L1/L2 —
  or deletable.
- **CONFIRMED as structural, not incidental**: RT-030b and RT-030c are both symptoms of the
  same missing abstraction — the media-typed body-coder contract (`swift-http-body` in the
  ideal map). No point fix closes the class; B5 shows 44 unfixed routes in one consumer alone.

### Ideal-vs-actual diff — component dispositions

| Existing component | Disposition | Ideal-map home | Driving findings |
|---|---|---|---|
| swift-url-routing: DSL core (parsers/builders/conversions) | **KEEP** (reshape targets; fix L1 twins upstream) | swift-url-routing Router Core/Path/Query/Header | B2-15, B2-16, B2-17 |
| swift-url-routing: URI.Request.Data + URLComponents façade | **REPLACE** with RFC_3986-native `Router.Input` (F2) | Router Core | B2-01, B2-02, B3-1/2 |
| swift-url-routing: Multipart.* + FileUpload.* (~1,035 LoC + files) | **EXTRACT/REPLACE**: wire stays L2; typed coding → form-coder family; contract → http-body | swift-html-form-coder (`.Multipart`) / swift-http-body | B2-08…B2-13 |
| swift-url-routing: HTTP.Cookie parser family | **MOVE to L2** swift-rfc-6265 (grammar); router keeps only a header-combinator lift | rfc-6265 + Router Header | B2-04 |
| swift-url-routing: RFC 7230/7231 composition | **REPLACE** with RFC 9110 via http-standard | Router Core deps | B2-14, B1 |
| swift-url-routing: URLRouting.Client | **SPLIT**: URLRequest bridging → Foundation Integration leaf; execution → swift-http (deferred on networking Wave 3) | FI leaf / swift-http | B3-4, B4-3/5 |
| swift-url-form-coding (Form.Encoder/Decoder) | **KEEP the concept, reshape**: explicit coders canonical over the WHATWG pair codec + entry-list pivot; Codable machinery → opt-in leaf; strategies unify into ONE vocabulary shared with multipart | swift-html-form-coder (`HTML.Form.Coder` default + Codable leaf) | B2-03, B2-05, B2-06, B4-1 |
| swift-multipart-form-coding | **ABSORB** into the form coder's Multipart variant | swift-html-form-coder (`HTML.Form.Coder.Multipart`) | B1, B2-10 |
| swift-form-coding (umbrella) | **DELETE** ([ARCH-LAYER-009] guards) | — | B1 (6 LoC, broken symlink, unused deps; sole manifest edge self-labeled to die) |
| swift-url-routing-form-coding (bridge) | **DELETE** after de-duplicating `.form` (keep exactly one conversion) | Router Body | B2-20, B1 |
| swift-url-routing-tagged | **DISSOLVE** into Router Core (a conformance, not a package — [MOD-020]) | Router Core | B1 |
| swift-url-routing-translating | **RE-HOME as L4 adapter** (only if the localized-routes concern is ratified as real); fix its broken test target either way | L4 | B1, A3 C-map |
| swift-url-routing-authentication | **DISSOLVE**: grammars already at L2 (rfc-7617/6750 exist); matching → Router Header; URL bridging → FI leaf. Its FI-split pattern is the template for the whole stack | rfc-7617/6750 + Router Header | A3 C15, B3, B4-8 |
| swift-url-routing-vapor | **KEEP as L4 leaf** until the networking program retires Vapor (Wave 4); fix its double-parse (B3-3) opportunistically | L4 | ratified prior |
| swift-urlrequest-handler | **SPLIT**: bridging → FI leaf; execution semantics → swift-http when it exists (explicitly deferred Foundation exception until then) | FI leaf / swift-http | B3, A3 |
| swift-rfc-2388 (L2) | **DISSOLVE**: bracket-notation content → the form coder's nested-keys target; retire the misnamed package | swift-html-form-coder (nested keys) | A2, A3 §2.2 |
| swift-mailgun-types Form.Coder presets | **KEEP** (genuine vendor knowledge; L4-shaped); fix the upward L2→L3 edge when the coder reshape lands; rfc-2822 date-time → L2 gap-fill | per-API preset layer | B2-19 |

### New capabilities required below L3 (endorsed set)

L1: printer conformances for Many/Optionally/Rest; value-checkpoint backtracking for
OneOf/Optionally (retires B2-16 twins); four trivial Bidirectional refinement declarations
(B2-17); case-path derivation macro (optic) + Prism→Conversion bridge.
L2: RFC 7578 decode side; `RFC_2046.Boundary.random()`; swift-media-type-standard;
uri-standard drift fix; rfc-6265 cookie grammar; rfc-2822 date-time; (exists already:
rfc-7617/6750).
L3: swift-http-body; swift-html-form-coder (both new packages — repo creation requires
Principal approval). Plus the two L2 alias/re-export mechanics for the ratified `HTML.Form`
spelling (whatwg-html nest alias; html-standard Forms re-export).
Rejected (with A3's reasoning): L1 percent codec; L1 query-pair vocabulary; §5 resolution
(exists); URI-template matching at L2; L1 Codable visitor machinery; a standalone L3
auth-routing package; printers for closure Map/FlatMap.

### End-state conformance check (the mission's bar)

Maximal re-use ✓ (three L3 packages, everything else consumed from L1/L2); [MOD-*]/[API-*]/
[IMPL-*]/[ARCH-LAYER-*] conformance is reachable — the naming/typed-throws remediation folds
into the reshape (B4 items 1–4; the Codable wall dissolves under F3); Foundation-free per
[ARCH-LAYER-007] ✓ for every core target, with two EXPLICITLY DEFERRED exceptions: (1)
URLSession-backed execution (URLRouting.Client / urlrequest-handler successors) until the
networking program's swift-http lands (Wave 3), and (2) the
`Measurement<UnitInformationStorage>` replacement until an information-storage quantity gains
its institute home. Lint-clean is reachable; note the two tooling defects found (SwiftLint
org-config false-green invocation; swift-format config drift).

## Principal rulings (2026-07-20, post-review)

Adjudicated in the review session after v1.0.0; these amend the ideal map's names, not its
structure.

1. **Type spellings APPROVED**: `HTML.Form.Data`, `HTML.Form.Coder` — the converged `HTML`
   nest (via swift-html-standard's existing `typealias HTML = WHATWG_HTML`,
   exports.swift:20) adopting the L2-owned `Form` type (the WHATWG `<form>` element,
   `WHATWG HTML Forms/form Form.swift:60`). Answers the "what kind of Form?" distinctiveness
   concern without minting a new top-level token: `Form` is the spec package's own type;
   other form domains (e.g. PDF) live under their own spec namespaces per [API-NAME-003]/
   [API-NAME-014]. Mechanics required: a `WHATWG_HTML.Form` nest alias in swift-whatwg-html
   (today `Form` is module-top-level in `WHATWG_HTML_Forms`) and Forms-product re-exports in
   swift-html-standard.
2. **`Form.Coder.URLEncoded` REJECTED** (compound token; participle-not-noun; any repair via
   `URL`/`Query` reuses a subject word as a manner label, [API-NAME-001b]). First-principles
   replacement — the variant axis is the HTML spec's own **enctype axis**, whose default IS
   the urlencoded state: **`HTML.Form.Coder`** (default; contentType `.formUrlEncoded`) and
   **`HTML.Form.Coder.Multipart`** (marked variant; contentType `.formData`; `Multipart` is
   the established spec-mirrored noun). `text/plain` deliberately unimplemented (spec-marked
   lossy). One strategy vocabulary at `HTML.Form.Coder.Strategy.*` shared by both wire forms.
3. **Package name**: `swift-html-form-coder` ([PKG-NAME-016] recipient-then-provider;
   agent-noun per [PKG-NAME-001]; no bare `Form` package token).
4. **WHATWG dependency posture**: NO parser/serializer deps are added to WHATWG packages —
   the entry-list⇆wire step stays L3 inside the coder (reverting the v1.0-era L2-move idea;
   matches the L2 authors' documented intent at Form.Data.swift:18–24). swift-uri-standard
   REJECTED as a home ([ECO-005] convergers are policy-free; wrong authority). The
   strict-authority alternative (an L2 Form Submission target) remains recorded with its
   named cost (package-closure growth for every HTML consumer) and is NOT taken.

The ratified end-state package roster, complete and by layer, is
`url-routing-stack-migration-plan.md` §Final package roster.

### Round 2 (2026-07-20, gate adjudication — Principal-ratified in full)

5. **Router naming cascade**: L3 package is **`swift-routers`** (plural-field register, the
   `swift-executors`/`swift-clocks` precedent — the package vends a family of routers);
   namespace root `Router` (agent noun), `Router.Protocol` + **`typealias Routing =
   Router.Protocol`** ([PKG-NAME-002] — the gerund lands exactly where conventions put it),
   `Router.Witness`, `Router.Input`, attachment protocol `Routable`. L4 cascade:
   `swift-routers-vapor`, `swift-routers-http` (supersedes the networking program's
   `swift-url-routing-http` reservation — that doc licenses pre-implementation renames).
   Repo rename executes at B7 behind the compat module. `url` was inaccurate anyway: the
   router routes requests, not URLs.
6. **`swift-router-primitives` REJECTED**: the spec-free router concept IS the L1 parser
   spine (`Coder where Buffer == Input` after unification); the concrete Router's
   domain-bound Input requires L2 vocabulary → [MOD-PLACE-FLOOR] pins it at L3. An L1
   router package would duplicate parser-primitives ([MOD-RENT] criterion 2 fails) or
   import L2 (illegal).
7. **Bidirectional/Coder unification** (verified shapes recorded in §Track A/A1 and the
   plan's spike gate): `Parser.Printer` is `Serializer.Protocol` with `Buffer == Input`,
   differing only in emission discipline (prepend vs append) and traversal order — two
   contracts invisible to the type system, maintained as two parallel combinator algebras.
   Target end-state: **`Coder.Protocol` is the single canonical bidirectional conjunction**;
   the law-carrying constrained form (`Coder where Buffer == Input`) replaces
   `Parser.Bidirectional`; `Parser.Printer` retires; `Router.Protocol` refines the
   constrained form. Gated on a ≤1-day forward-append round-trip spike (plan §Batch 2 entry
   gate); if the spike proves prepend load-bearing, the F1 role split stands with the
   impossibility record.
8. **Remaining gate dispositions**: all four repo creations approved; both
   behavior-change classes approved (concrete-delta sign-off stays at the B3/B4 gates);
   all dissolutions approved as staged; both [ARCH-LAYER-007] deferrals countersigned;
   `swift-url-routing-translating` DISSOLVES at B7 (reservation name
   `swift-routers-translation` recorded, no obligation to fill); parity corpus lives
   per-consumer + shared helpers in Router Test Support; the strict swift-format variant
   becomes the org canonical; `swift-dual`/`swift-dependencies`/`swift-logger-dependencies`
   default-DROP from Router core (FI-leaf/Client survival only on evidence at B7).

## Outcome

**Status: RECOMMENDATION, fully ratified 2026-07-20** (both rulings rounds — see §Principal
rulings). The companion `url-routing-stack-migration-plan.md` (status APPROVED) stages the
path; implementation has NOT started. The only items left open are execution-time:
concrete-delta sign-offs at the B3/B4 gates, the spike verdict at the B2 entry gate, and
each batch's own verification gate.

## References

- Prior art: `Research/Pure-Institute-Networking/` (target-package-and-layer-architecture.md,
  institute-capability-and-gap-atlas.md, migration-waves.md, replacement-matrix.md)
- Arc records: `Research/Reflections/2026-07-11-routing-w2-dsl-restore-wave-close-and-sample-caught-doc-drift.md`,
  `Research/Reflections/2026-07-12-overnight-routing-arc-close-and-unattended-gate-lessons.md`
- Evidence seeds: `repotraffic/Reports/2026-07-20-repotraffic-day-report.md` (§8, §10 —
  RT-030b/c), `repotraffic/Reports/2026-07-20-url-routing-review-start-prompt.md`
- All file:line citations in this dossier were produced against live source on 2026-07-20
  ([RES-037]); re-verify against `git log` of the cited paths before acting on any of them
  ([RES-013a]).
