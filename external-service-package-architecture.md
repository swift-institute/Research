# External-Service Package Architecture and Heritage

<!--
---
version: 1.5.1
last_updated: 2026-07-22
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
changelog:
  - 1.5.1 (2026-07-22): Marked the accepted endpoint report as a prepared
    local handoff pending tracked publication, and recorded the coordinated
    local-directory, mirror, consumer-reference, and navigation-index migration
    plan required after the two GitHub repository renames.
  - 1.5.0 (2026-07-22): Recorded canonical GitHub-family publication, the
    repository-content eligibility endpoint across Standard/Core/HTTP, anonymous
    isolated clean-room evidence, the URLRouting Wave 3 adjudication, and the exact
    Foundation-free HTTPS executor handoff that blocks Workspace composition.
  - 1.4.0 (2026-07-22): Established and implemented the RFC 8288 owner-package
    vertical slice for HTTP Link-field pagination, including its direct Byte/RFC
    3986/RFC 9110 graph, typed API boundary, lower-owner constraint, acceptance
    corpus, GitHub default witness, focused test evidence, and local-to-canonical
    dependency conversion gate.
  - 1.3.0 (2026-07-22): Recorded the authorized local GitHub pilot checkpoint,
    including real heritage commits, the corrected core R100/reshape split, final
    package surfaces, sequential SwiftPM evidence, and the RFC 8288 pagination gate.
  - 1.2.0 (2026-07-22): Added the GitHub client and HTTP history-transfer
    rehearsal, including exact source commits, path mappings, graph results, and
    implementation risks.
  - 1.1.0 (2026-07-22): Recorded the approved GitHub pilot architecture,
    package/product/module spellings, L2 contract boundary, B4 implementation gate,
    webhook rule, provider deferrals, breaking consumer migration, and no-L4 policy.
    Principal direction supersedes the initially reviewed one-major deprecated-product
    window: the new major retains no historical compatibility products.
  - 1.0.0 (2026-07-22): Initial live-source census, cross-provider architecture,
    GitHub pilot recommendation, Stripe/Mailgun pressure tests, owned-source
    heritage dispositions, consumer migration sequence, and review gates.
---
-->

## Context

The Swift Institute has three external-service families whose historical shape is
`swift-{provider}-types` + `swift-{provider}-live` + an unsuffixed wrapper:
GitHub, Stripe, and Mailgun. Workspace needs GitHub repository discovery, but
implementing that capability against the historical graph before deciding its
missions would make one application choose the ecosystem architecture by accident.

This record is therefore the design gate before broad package mutation. GitHub is
the pilot; Stripe and Mailgun remain read-only pressure tests in this wave. The
earlier suggestion to absorb `swift-github-live` into `swift-github` is treated here
as one hypothesis, not as an approved conclusion.

This is a **Tier 2 RECOMMENDATION**, not a timeless pattern. By itself it authorizes
no package mutation, repository transfer, rename, archive, push, tag, publication,
or visibility change. The subsequent, action-specific local GitHub pilot authorization
and its evidence are recorded below. Promotion to Tier 3 or a canonical skill rule
requires the GitHub pilot, Stripe/Mailgun revalidation, clean-room consumer evidence,
Principal review, and the `skill-lifecycle` workflow.

The supervisor approved the central mission-based standard/core/HTTP recommendation
and all nine heritage dispositions as the architecture candidate on 2026-07-22. The
adjudications below resolve the GitHub pilot shape; they do not convert this Tier 2
record into a canonical cross-provider rule. Later supervisor authorizations opened
the bounded local implementation and heritage operations described in the checkpoint.

### Skills loaded ([RES-033])

In dependency order: `swift-institute-core`, `swift-institute`, `swift-package`,
`code-surface`, `implementation`, `modularization` (including targets,
cross-package, imports, SPI, and package-decomposition companions),
`research-process`, `experiment-process`, `swift-package-heritage` and its
owned-source heritage references, `testing`, and `skill-lifecycle` for the
promotion gate only.

The load-bearing rules are:

- [ARCH-LAYER-001], [ARCH-LAYER-007], [ARCH-LAYER-013], and
  [ARCH-LAYER-014]: layer direction, Foundation-free main targets and standards,
  and essence-first placement;
- [ARCH-LAYER-008] and [ARCH-LAYER-010]: correctness-driven reshaping and one
  strict mission per package;
- [MOD-014], [MOD-029], and [MOD-041]: extract every cross-package integration,
  weight upstream dependency pruning, and reject coincidental cohesion;
- [MOD-005], [MOD-026], [MOD-038], and [MOD-040]: deliberate umbrellas,
  fine-grained L3 targets, declared imports, and no convenience leakage;
- [PKG-NAME-016], [PKG-DEP-003], [PKG-DEP-009], and [PKG-DEP-012]: owner-first
  integration names, used-only canonical dependencies, and same-arc consumer
  migration;
- [API-NAME-001], [API-ERR-001], and [API-IMPL-005]: nested semantic names,
  typed throws, and one type per file;
- [HERITAGE-005] and [HERITAGE-007]: owned-source transfer is distinct from an
  external fork, and every external mutation needs action-specific authorization;
- [RES-019], [RES-032], [RES-034], and [RES-037]: internal step-0 grep,
  primary-source citations, parallel verification, and live file:line evidence.

### Coordination and protected state

The B4 task owns `swift-http-body`, `swift-url-routing`, Mailgun and the active
consumer migrations, the shared graph, and the Xcode/build lane. It explicitly
authorized read-only GitHub/Stripe/Mailgun inspection and writes limited to this
Research record plus a surgical `_index.json` entry. No owned package, consumer,
shared graph, or Xcode lane was mutated or run by this investigation.

The Workspace milestone `566fe96cbca64e1f49603f5cdbe501978b4b7112` remains
unchanged. A source grep found no current `GitHub`/`swift-github` reference in
Workspace `Package.swift` or Swift sources, so the future integration has no
existing Workspace compatibility surface to preserve.

The Research worktree already contained unrelated tracked and untracked work. This
record does not read as ownership of those changes. During authorship,
`swift-mailgun-types` had 20 B4-owned modified `*.API.swift` files. B4 subsequently
committed and pushed that exact surface as
`2f6905740ab8503f767a4b4b512cb517c975c588`; local `HEAD` and `origin/main`
match and the worktree is clean. The commit changes 43 previously headerless
`URLRouting.Body` router call sites to `URLRouting.Body(coding: ...)`; five
already-headered Body sites and three FileUpload sites remain untouched. It adds 45
Content-Type parity-corpus lines (34 form, four JSON, seven multipart) with no corpus
removals. B4 reports its required non-live Internal oracle passed 58 tests in 29
suites with `** TEST SUCCEEDED **` and zero `error:`; this investigation did not
rerun that Xcode gate or any live suite. The post-commit recensus confirms unchanged
semantic size (109 Swift source files, 14,776 lines, 13 Foundation importers) and 43
explicit Body-coding sites. The mechanical change strengthens Content-Type coupling
evidence but does not change the Router-out architecture classification.

## Question

What reusable package architecture should external-service families use when the
historical suffixes no longer describe semantic responsibility, while preserving
layer legality, Foundation-free main targets, optional integrations, provider
differences, substantive git heritage, public URL continuity, and consumer migration
safety?

## Method

1. Inspect branch, status, remotes, commit roots, manifests, source targets, source
   imports, representative public declarations, tests, and direct consumers for all
   nine repositories.
2. Classify capability by semantic responsibility, never by the current suffix.
3. Run the [RES-019] internal-corpus grep. The controlling prior art is the July 12
   L2 vendor-purity census and its GitHub/Mailgun/Stripe lanes, plus the owned-source
   heritage transfer and git-history records.
4. Reverify current source and manifests at the exact commits below ([RES-037]).
5. Independently verify externally specified behavior against official GitHub,
   Stripe, and Mailgun documentation using one read-only reviewer per provider
   ([RES-034]).
6. Compare viable architectures, then pressure-test the candidate rather than
   forcing all providers into an identical repository count.

No experiment was required: the recommendation makes no new compiler/runtime
claim. Build and clean-room probes are implementation gates, not evidence this
design phase could collect while B4 owns the build lane.

## Live-source census

### Repository identity and size

Measured 2026-07-22. Lines count committed/current Swift source; source-tree meaning
was verified by manifest and file inspection, not inferred from the repository name.

| Repository | HEAD | Commits | Root | Swift files | Source lines | Foundation files | Mission actually present |
|---|---:|---:|---|---:|---:|---:|---|
| `swift-github-types` | `cb54d91` | 41 | 2025-09-01 | 27 | 2,710 | 6 | wire models + endpoint enums + routers + witness clients + DI re-exports |
| `swift-github-live` | `aafa320` | 47 | 2025-09-01 | 14 | 897 | 5 | concrete HTTP execution + auth + env policy + DI + throttling/retry |
| `swift-github` | `b3bca21` | 24 | 2025-09-01 | 8 | 81 | 3 | thin live/type re-export plus RepoTraffic-oriented traffic convenience |
| `swift-stripe-types` | `3db1452` | 58 | 2025-09-01 | 629 | 63,861 | 408 | provider models + 81 routers + 73 real witness clients + codec configuration |
| `swift-stripe-live` | `53ba2aa` | 53 | 2025-09-01 | 226 | 4,793 | 61 | concrete execution across many domains + auth/env/DI + retry/rate policy |
| `swift-stripe` | `5dbc364` | 45 | 2025-09-01 | 60 | 3,812 | 15 | re-exports plus webhook crypto/dispatch, typed events, HTML, and app-like helpers |
| `swift-mailgun-types` | `2f69057` | 120 | 2025-08-06 | 109 | 14,776 | 13 | models + 33 routers + 29 witness clients + aggregators + form/multipart codecs |
| `swift-mailgun-live` | `2944536` | 170 | 2024-12-28 | 43 | 3,075 | 40 | concrete execution + Basic auth + env/DI + decoder policy |
| `swift-mailgun` | `e3cea9c` | 154 | 2024-12-28 | 20 | 213 | mostly re-exports; one inactive `Email` alias; dependency/policy umbrella |

The current suffixes are not reliable mission labels. The largest repositories are
the alleged “types” packages; the concrete implementation histories live in `live`;
the unsuffixed GitHub and Mailgun packages are tiny present-day wrappers. Mailgun is
especially important: both `live` and the unsuffixed repository carry independent
2024 roots and long histories, while `types` begins in 2025. The thin current
wrapper is therefore not automatically the substantive-history owner.

### Product and target surfaces

| Family | `types` source-target directories | `live` source-target directories | unsuffixed source-target directories | Structural observation |
|---|---:|---:|---:|---|
| GitHub | 7 | 7 | 4 | Shared + Traffic + Repositories + Stargazers + OAuth + Collaborators; exact triplet mirroring |
| Stripe | 43 | 48 source directories / 41 manifest libraries | 46 source directories / 41 manifest libraries | enormous resource graph; v1/v2 and UI/webhook concerns are not one concern |
| Mailgun | 19 | 19 | 19 | broad API domains mirror one-for-one, but pagination/encoding differ by domain |

The GitHub manifests show the current dependency inversion directly:

- `swift-github-types/Package.swift:74-78` places L3
  `swift-dependencies`, `swift-emailaddress`, `swift-dual`, and
  `swift-url-routing` above an L2 package; every feature target repeats those edges
  at lines 81-151.
- `swift-github-live/Package.swift:85-92` combines types, URLRequest execution,
  environment, throttling, routing-authentication, DI, and clocks; its shared target
  combines those concerns at lines 95-104.
- `swift-github/Package.swift:40-41` depends on `swift-github-live` and DI, making
  the nominal core depend on an optional concrete implementation; targets at
  lines 44-71 re-export that implementation.

The same class scales up in Stripe and Mailgun. The current `types` manifests declare
43/19 library products and upward dependencies on routing, DI, dual/case machinery,
Foundation-layer email/form coding, or combinations of them. Current `live`
manifests centralize URLRequest execution, credentials, environment values,
authentication, clocks, throttling, and decoding. Unsuffixed manifests then depend
back on `live`, forcing all consumers to accept the concrete implementation.

### Exhaustive current target/product disposition

The following ledger covers every current source target. Manifest library products
mirror all or a subset of these target names; internal targets receive the same
disposition as their owning source target. Every test target follows the declaration
under test to Standard Tests, Core Tests, HTTP Tests, integration tests, or Test
Support—never the repository suffix.

#### GitHub

- **Types targets:** `GitHub Types Shared`, `GitHub Types`, `GitHub Traffic Types`,
  `GitHub Repositories Types`, `GitHub Stargazers Types`, `GitHub OAuth Types`, and
  `GitHub Collaborators Types`. In each domain, provider models and pure endpoint
  operation representations go to the corresponding Standard target; `Router` halves,
  witness `Client` declarations, DI/case/routing re-exports, and convenience workflows
  go to Core or a relevant integration. The new major publishes `GitHub Standard`,
  not a `GitHub Types` compatibility product; Shared is dissolved into the narrow
  targets that use each declaration.
- **Live targets:** `GitHub Live Shared`, `GitHub Live`, `GitHub Traffic Live`,
  `GitHub Repositories Live`, `GitHub Stargazers Live`, `GitHub OAuth Live`, and
  `GitHub Collaborators Live`. Per-domain route-to-request/response execution goes to
  GitHub HTTP; Shared is split into HTTP execution, auth integration, DI integration,
  environment policy, rate/retry policy, and test support. The new major publishes
  `GitHub HTTP`, not a `GitHub Live` compatibility product, and core never depends on
  HTTP.
- **Unsuffixed targets:** `GitHub Shared`, `GitHub`, `GitHub Traffic`, and
  `GitHub Repositories`. They become transport-neutral Core/umbrella targets after
  removing all `Live` re-exports; RepoTraffic-specific `fetchAll` convenience is L5 or
  a separately justified component, not provider core.

#### Stripe

- **Types targets (all 43):** `Stripe Types Shared`, `Stripe Types Models`,
  `Stripe Types`, `Stripe Balance Transactions Types`, `Stripe Balance Types`,
  `Stripe Billing Types`, `Stripe Capital Types`, `Stripe Charges Types`,
  `Stripe Checkout Types`, `Stripe Climate Types`, `Stripe Confirmation Token Types`,
  `Stripe Connect Types`, `Stripe Crypto Types`, `Stripe Customer Session Types`,
  `Stripe Customers Types`, `Stripe Disputes Types`, `Stripe Entitlements Types`,
  `Stripe Event Destinations Types`, `Stripe Events Types`, `Stripe File Links Types`,
  `Stripe Files Types`, `Stripe Financial Connections Types`, `Stripe Forwarding Types`,
  `Stripe Fraud Types`, `Stripe Identity Types`, `Stripe Issuing Types`,
  `Stripe Mandates Types`, `Stripe Payment Intents Types`, `Stripe Payment Link Types`,
  `Stripe Payment Methods Types`, `Stripe Payouts Types`, `Stripe Products Types`,
  `Stripe Refunds Types`, `Stripe Reporting Types`, `Stripe Setup Attempts Types`,
  `Stripe Setup Intents Types`, `Stripe Sigma Types`, `Stripe Tax Types`,
  `Stripe Terminal Types`, `Stripe Tokens Types`, `Stripe Treasury Types`,
  `Stripe Web Elements Types`, and `Stripe Webhooks Types`. For every named domain,
  provider models and pure operation representations stay Standard; all Router halves,
  real witness Clients, client aggregators, empty client stubs, DI exports, and form
  codec configuration leave L2. Shared/Models/umbrella are decomposed into explicit
  version/domain ownership. Web Elements’ provider-published configuration can remain
  Standard, but HTML rendering cannot.
- **Live source targets (all 48):** `Stripe Live Shared`, `Stripe Live`,
  `Stripe Balance Live`, `Stripe Balance Transactions Live`, `Stripe Billing Live`,
  `Stripe Capital Live`, `Stripe Charges Live`, `Stripe Checkout Live`,
  `Stripe Climate Live`, `Stripe Confirmation Token Live`, `Stripe Connect Live`,
  `Stripe Core Resources Live`, `Stripe Crypto Live`, `Stripe Customer Session Live`,
  `Stripe Customers Live`, `Stripe Disputes Live`, `Stripe Entitlements Live`,
  `Stripe Event Destinations Live`, `Stripe Events Live`, `Stripe File Links Live`,
  `Stripe Files Live`, `Stripe Financial Connections Live`, `Stripe Forwarding Live`,
  `Stripe Fraud Live`, `Stripe Identity Live`, `Stripe Issuing Live`,
  `Stripe Mandates Live`, `Stripe Payment Intents Live`, `Stripe Payment Link Live`,
  `Stripe Payment Methods Live`, `Stripe Payouts Live`, `Stripe Products Live`,
  `Stripe Products Coupons Live`, `Stripe Products Promotion Code Live`,
  `Stripe Products Shipping Rates Live`, `Stripe Products Tax Rate Live`,
  `Stripe Refunds Live`, `Stripe Reporting Live`, `Stripe Setup Attempts Live`,
  `Stripe Setup Intents Live`, `Stripe Sigma Live`,
  `Stripe Sigma Scheduled Queries Live`, `Stripe Tax Live`,
  `Stripe Tax Calculations Live`, `Stripe Terminal Live`, `Stripe Tokens Live`,
  `Stripe Treasury Live`, and `Stripe Webhooks Live`. Their per-domain concrete
  request/response adapters go to version/domain Stripe HTTP targets; Shared is split
  into HTTP, auth, environment, DI, rate/retry, and test responsibilities. Internal
  nested resource clients inherit the parent domain disposition.
- **Unsuffixed source targets (all 46):** `Stripe Shared`, `Stripe Models`, `Stripe`,
  `Stripe Balance`, `Stripe Balance Transactions`, `Stripe Billing`, `Stripe Capital`,
  `Stripe Charges`, `Stripe Checkout`, `Stripe Checkout Sessions`, `Stripe Climate`,
  `Stripe Confirmation Token`, `Stripe Connect`, `Stripe Core Resources`,
  `Stripe Crypto`, `Stripe Customer Session`, `Stripe Customers`, `Stripe Disputes`,
  `Stripe Entitlements`, `Stripe Event Destinations`, `Stripe Events`,
  `Stripe File Links`, `Stripe Files`, `Stripe Financial Connections`,
  `Stripe Forwarding`, `Stripe Fraud`, `Stripe Identity`, `Stripe Issuing`,
  `Stripe Mandates`, `Stripe Payment Intents`, `Stripe Payment Link`,
  `Stripe Payment Methods`, `Stripe Payouts`, `Stripe Products`, `Stripe Refunds`,
  `Stripe Reporting`, `Stripe Setup Attempts`, `Stripe Setup Intents`, `Stripe Sigma`,
  `Stripe Tax`, `Stripe Terminal`, `Stripe Tokens`, `Stripe Treasury`,
  `Stripe Webhooks`, `Stripe Web Elements`, and `Stripe Web Components`. Domain
  client composition becomes Core; Shared webhook parsing/crypto/server behavior is
  split by owner; Web Elements/Components move to HTML/browser integrations or L4;
  product-sync/application helpers do not remain in provider core.

#### Mailgun

- **Types targets (all 19):** `Mailgun Types Shared`, `Mailgun Types`,
  `Mailgun AccountManagement Types`, `Mailgun Credentials Types`,
  `Mailgun CustomMessageLimit Types`, `Mailgun Domains Types`,
  `Mailgun IPAllowlist Types`, `Mailgun IPPools Types`, `Mailgun IPs Types`,
  `Mailgun Keys Types`, `Mailgun Lists Types`, `Mailgun Messages Types`,
  `Mailgun Reporting Types`, `Mailgun Routes Types`, `Mailgun Subaccounts Types`,
  `Mailgun Suppressions Types`, `Mailgun Templates Types`, `Mailgun Users Types`, and
  `Mailgun Webhooks Types`. Provider models and pure endpoint representations stay in
  domain Standard targets; 33 Router halves, 29 witness clients, four client
  aggregators, `Form.Coder`, Unix-epoch routing conversion, and multipart machinery
  leave L2. The 43 committed `URLRouting.Body(coding:)` sites are all router
  machinery in that move-out set; their new explicit Content-Type coupling does not
  make the machinery L2. Shared’s Foundation/DI/routing re-export barrel is dissolved.
- **Live targets (all 19):** `Mailgun Shared Live`, `Mailgun Live`,
  `Mailgun AccountManagement Live`, `Mailgun Credentials Live`,
  `Mailgun CustomMessageLimit Live`, `Mailgun Domains Live`,
  `Mailgun IPAllowlist Live`, `Mailgun IPPools Live`, `Mailgun IPs Live`,
  `Mailgun Keys Live`, `Mailgun Lists Live`, `Mailgun Messages Live`,
  `Mailgun Reporting Live`, `Mailgun Routes Live`, `Mailgun Subaccounts Live`,
  `Mailgun Suppressions Live`, `Mailgun Templates Live`, `Mailgun Users Live`, and
  `Mailgun Webhooks Live`. Per-domain concrete execution becomes Mailgun HTTP;
  Shared is split into Basic-auth adaptation, HTTP decode, environment/region policy,
  DI, and test support.
- **Unsuffixed targets (all 19):** `Mailgun Shared`, `Mailgun`,
  `Mailgun AccountManagement`, `Mailgun Credentials`, `Mailgun CustomMessageLimit`,
  `Mailgun Domains`, `Mailgun IPAllowlist`, `Mailgun IPPools`, `Mailgun IPs`,
  `Mailgun Keys`, `Mailgun Lists`, `Mailgun Messages`, `Mailgun Reporting`,
  `Mailgun Routes`, `Mailgun Subaccounts`, `Mailgun Suppressions`,
  `Mailgun Templates`, `Mailgun Users`, and `Mailgun Webhooks`. They become Core
  domain/umbrella targets only where they contain transport-neutral capability;
  current Live/environment/email re-exports are removed or routed to dedicated
  integrations. The inactive `Mailgun.Email` alias creates no independent mission.

### Source responsibility census

The prior L2-purity census remains directionally correct and was rechecked against
the current trees:

| Family | Provider vocabulary retained at L2 | Mixed API files to split | client/DI files out | codec/routing leaves out |
|---|---:|---:|---:|---:|
| GitHub | 11 files | 9 | 5 | 0 standalone codecs |
| Stripe | 382 files | 81 | 163 inventoried (73 real, 81 empty stubs, 9 aggregators) | one shared form codec |
| Mailgun | 39 files | 34 | 34 | `Form.Coder`, `Date.UnixEpoch`, multipart conversions |

Representative current evidence:

- GitHub repository request/response vocabulary and provider enum values live in
  `GitHub.Repositories.swift:17-95`; raw repository creation/update representations
  continue from lines 97-304.
- The same GitHub file uses Foundation `Date` at lines 30-42, and
  `Pagination.swift:10-45` uses Foundation `URL` and raw `Int` page values through
  an ambient Foundation re-export.
- `GitHub.Repositories.API.swift:10-27` defines the provider operation enum, while
  lines 30 onward define an L3 `ParserPrinter` router in the same file.
- `GitHub.Repositories.Client.swift:10-38` defines outbound async operations with
  existential `throws(any Swift.Error)` and raw owner/repository `String` values.
- `swift-github-live/.../URLRequest.Handler.GitHub.swift:20-49` hard-codes rate and
  pacing windows; lines 81-173 own URLSession execution and recursive retry; those
  are policy and execution, not provider wire vocabulary.
- `swift-github-live/.../EnvironmentVariables+GitHub.swift:8-26` hard-codes env keys,
  base URL, token, and API-version defaults; credential sourcing is installation
  policy.
- `swift-github-live/.../GitHub.Repositories.Client.live.swift:11-67` adapts endpoint
  routes to concrete URLRequest execution, while lines 69-85 add DI and environment
  defaults. Those are two distinct integrations.
- `swift-stripe-live/.../AuthenticatedClient.swift:12-50` combines route/auth
  integration with environment lookup and even constructs `NSError`; lines 94-130
  hard-code one Stripe version and request content type. It composes `BearerAuth` at
  lines 17-18 and injects a token at line 45, while the official API-key contract
  below specifies HTTP Basic Auth with the key as username; that apparent wire
  mismatch requires correction or a documented endpoint-specific exception, not
  preservation by inertia.
- `swift-stripe-live/.../URLRequest.Handler.Stripe.swift:21-191` owns rate windows,
  pacing, URLSession, status interpretation, retry, jitter, and backoff in one type.
- `swift-stripe/.../WebhookSignature.swift:5-88` mixes Apple Crypto, Foundation
  `Data`/`Date`, signature wire parsing, clock tolerance, and verification policy.
- `swift-mailgun-live/.../AuthenticatedClient.swift:17-98` combines Basic auth,
  environment lookup, URLRequest construction, and DI.
- `swift-mailgun-live/.../EnvironmentVariables.swift:12-62` force-unwraps credential,
  region/base URL, domain, and test recipient policy from process environment.
- `swift-mailgun-live/.../URLRequest.Handler.Mailgun.swift:15-32` is a Foundation
  JSON/Date decoder configuration, not Mailgun standard vocabulary.

### Layer, dependency, and API audit

1. **L2 layer legality fails today.** All three `types` packages have upward L3
   dependencies. The repair is to decompose routers, clients, DI, and codecs out;
   [ARCH-LAYER-014] forbids laundering the defect by relabeling the whole package L3.
2. **Foundation-free main targets fail today.** The nine repositories contain
   553 source files importing or re-exporting Foundation. Stripe has 408 in `types`
   alone; the prior audit found most to be import-only, but provider models also use
   `Date`, `URL`, `Data`, and `Decimal`. Mailgun’s shared L2 barrel propagates
   Foundation to all 19 targets. Interop must be leaf-isolated or replaced with
   Institute standards/primitives.
3. **Same-layer edges have the wrong direction.** The nominal L3 core depends on
   `live`. The implementation integration must depend on core; core must not know
   the integration exists.
4. **Wrong-owner dependencies are structural, not cosmetic.** Routing, form/multipart
   coding, auth adapters, DI, clocks, throttling, environment values, HTML, and
   Apple Crypto occur in provider packages even where they are optional cross-domain
   integrations. [MOD-014] requires dedicated integration packages.
5. **Target cohesion fails.** A recurring feature target contains provider models,
   an endpoint enum plus router, a witness client, and exported dependency leakage.
   Those compile together but answer different layer questions.
6. **Typed throws fail.** Current source contains 11/10/1 untyped or existential
   throwing surfaces in the GitHub triplet, 58/61/13 in Stripe, and 170/39/0 in
   Mailgun. The new public surfaces require domain-specific typed errors.
7. **Semantic representation is inconsistent.** Provider IDs, owner/repository
   names, URLs, tokens, domains, addresses, page controls, and timestamps frequently
   use raw `String`/`Int`/Foundation values. This is not a blanket ban on `String`:
   open provider text remains text, while values with identity, validation, secrecy,
   encoding, units, or protocol semantics need semantic types. No candidate should
   introduce `[UInt8]` as another raw escape hatch; use the ecosystem byte/body
   vocabulary at transport boundaries.
8. **Tests mirror the mixed architecture.** Router/client tests reside in L2 packages,
   and live-mutating tests rely on environment credentials. Tests must move with
   their owner, preserve layer legality, and separate deterministic contract,
   integration, and live-service suites.

### Direct consumers and compatibility boundary

The bounded manifest census found these direct consumers outside the nine packages:

- `swift-identities-github/Package.swift:21-33` directly requests GitHub Types,
  GitHub Live, OAuth Types, and OAuth Live products;
- `swift-identities-mailgun/Package.swift:19,48` requests the unsuffixed Mailgun
  Messages product;
- Boiler’s Stripe and Mailgun examples request the unsuffixed products
  (`boiler-example-stripe/Package.swift:12,30` and
  `boiler-example-mailgun/Package.swift:16,31`);
- `swift-institute/Internal/institute-all/Package.swift:143-145,398-400` registers
  the GitHub and Stripe triplets and lines 222-224 register Mailgun; its product
  matrix explicitly asks for every historical product.

`swift-identities-github`, `swift-identities-mailgun`, and Boiler were clean at
census time. `Internal` was dirty with B4-owned workspace/handoff changes and is
read-only here. An ecosystem-wide source-import census also found the expected
subject-family imports and Boiler/identity sources; it does not prove that no
external GitHub consumer exists. Public migration must therefore preserve redirects
and test old URL/product fixtures rather than infer safety from local consumer count.

## Externally specified facts

Every bullet in this section was independently checked against the linked official
provider source on 2026-07-22. Provider wire facts constrain L2; client guidance does
not automatically become fixed L2 or L3 policy.

### GitHub [Verified: 2026-07-22]

- GitHub REST token auth uses the `Authorization` header; most tokens accept
  `Bearer` or `token`, while JWTs require `Bearer`. `X-GitHub-Api-Version` selects
  a version. Header/scheme/version representations are contract; secret storage and
  version selection are policy. [Authentication](https://docs.github.com/en/rest/authentication/authenticating-to-the-rest-api),
  [versions](https://docs.github.com/en/rest/about-the-rest-api/api-versions).
- `GET /orgs/{org}/repos` supports `type=public`, returns `archived` and
  `visibility`, and can be unauthenticated for public-only resources. It has no
  `archived` filter: public/non-archived discovery is a public request followed by
  client-side `archived == false`. [List organization repositories](https://docs.github.com/en/rest/repos/repos#list-organization-repositories).
- The endpoint uses `per_page` (maximum 100) and `page`; navigation URLs appear in
  `Link` relations such as `next`. Accumulation, page caps, deduplication, and local
  deterministic sorting are client policy. [Pagination](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api).
- Rate metadata is carried by `x-ratelimit-*` headers; limit responses can be 403 or
  429 and secondary limiting can include `retry-after`. Header parsing belongs with
  contract representations; sleep, jitter, clocks, concurrency, and retry ceilings
  are higher policy. [Rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api).
- Webhook signatures use `X-Hub-Signature-256` with `sha256=` + HMAC-SHA256 of the
  unmodified payload and require timing-safe comparison. Signature grammar and pure
  verification inputs are provider contract; secret sourcing, server response,
  replay handling, and dispatch are integrations/policy. [Webhook validation](https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries).

### Stripe [Verified: 2026-07-22]

- Stripe API-key authentication is HTTPS + HTTP Basic Auth with the key as username
  and an empty password for the documented v1 surface. Credential sourcing is not
  wire contract. [Authentication](https://docs.stripe.com/api/authentication).
- Stripe is not one encoding/version contract: v1 requests are form encoded with
  JSON responses, while v2 requests and responses are JSON and direct v2 calls use
  explicit versioning. [API v2 overview](https://docs.stripe.com/api-v2-overview),
  [versioning](https://docs.stripe.com/api/versioning).
- v1 lists use mutually exclusive `starting_after`/`ending_before` object cursors,
  `limit`, and `has_more`; v2 uses page URLs/tokens and freezes filters after the
  first request. Auto-pagination is client behavior. [v1 pagination](https://docs.stripe.com/api/pagination),
  [v2 pagination](https://docs.stripe.com/api-v2-overview#list-pagination).
- Idempotency header semantics are provider contract, but key generation and deciding
  which attempts reuse a key are client/application policy. v1 and v2 semantics
  differ. [v1 idempotency](https://docs.stripe.com/api/idempotent_requests),
  [v2 differences](https://docs.stripe.com/api-v2-overview#idempotency).
- Rate limiting is signaled by 429 and `Stripe-Rate-Limited-Reason`; the official
  source does not make `Retry-After` a universal Stripe response contract. Exponential
  backoff and randomness are recommendations, not one fixed reusable strategy.
  [Rate limits](https://docs.stripe.com/rate-limits).
- `Stripe-Signature` verification signs `timestamp + "." + exact raw body` using
  HMAC-SHA256. Raw-body preservation is mandatory. Clock tolerance, replay storage,
  server integration, and business dispatch remain higher-layer concerns.
  [Webhook verification](https://docs.stripe.com/webhooks#verify-manually).

### Mailgun [Verified: 2026-07-22]

- Mailgun uses HTTP Basic Auth with username `api` and the API key as password;
  primary and domain-sending keys have different capabilities. [Authentication](https://documentation.mailgun.com/docs/mailgun/api-reference/mg-auth).
- US and EU domains use different base URLs, and endpoint URI versions can differ.
  Region/base representations are contract; selecting and validating installation
  configuration is policy. [API overview](https://documentation.mailgun.com/docs/mailgun/api-reference/api-overview).
- Messages and MIME uploads use multipart form data with repeatable binary fields,
  while Metrics includes JSON-body APIs. Mailgun therefore has no provider-wide
  request encoder. [Messages](https://documentation.mailgun.com/docs/mailgun/api-reference/send/mailgun/messages),
  [Metrics](https://documentation.mailgun.com/docs/mailgun/api-reference/send/mailgun/metrics/pagination).
- Pagination differs by domain: Metrics uses `skip`/`limit`, Events returns opaque
  `paging.next`/`previous` URLs, and Mailing Lists expose more than one form. There
  is no honest provider-wide `Pagination` type. [Metrics pagination](https://documentation.mailgun.com/docs/mailgun/api-reference/send/mailgun/metrics/pagination),
  [Events pagination](https://documentation.mailgun.com/docs/mailgun/api-reference/send/mailgun/events/get-v3-domain_name-events),
  [Mailing Lists](https://documentation.mailgun.com/docs/mailgun/api-reference/send/mailgun/mailing-lists).
- `X-RateLimit-*` fields and 429/500 classifications are contract. Mailgun recommends
  header-guided retry and exponential backoff, but does not specify a universal
  attempt count or jitter rule. Automatic replay of mutating sends cannot be assumed
  safe without operation-specific idempotency evidence. [API overview](https://documentation.mailgun.com/docs/mailgun/api-reference/api-overview).
- Webhook signatures are `token` + `timestamp` with HMAC-SHA256 and a hexadecimal
  signature. Event-webhook retry schedules and inbound-forward schedules differ;
  replay cache/tolerance and idempotent handling are application policy.
  [Webhook security](https://documentation.mailgun.com/docs/mailgun/user-manual/webhooks/securing-webhooks),
  [webhook retries](https://documentation.mailgun.com/docs/mailgun/user-manual/webhooks/webhook-retries),
  [inbound forwarding](https://documentation.mailgun.com/docs/mailgun/user-manual/receive-forward-store/receive-http).

## Viable architectures

### Option A — retain `types` + `live` + unsuffixed wrapper

**Shape:** L2-ish models/clients/routers, L3 concrete implementation, and an
unsuffixed convenience re-export.

**Advantages:** minimal product-name churn; current direct consumers mostly continue
to compile.

**Defects:** suffixes describe implementation technique rather than mission; L2 has
upward dependencies and Foundation; the core depends on its optional implementation;
`live` combines HTTP, environment, DI, authentication, retries, and test policy; the
wrapper adds a third mandatory hop without a stable semantic role. It fails
[ARCH-LAYER-014], [MOD-014], and [MOD-041].

**Disposition:** reject as end state. It may exist only in preserved historical
releases while known consumers migrate before the breaking major cut.

### Option B — two packages: standard + foundation/core

**Shape:** `swift-{provider}-standard` (L2) and `swift-{provider}` (L3), with HTTP,
auth injection, pagination, DI, and defaults all absorbed into the L3 package.

**Advantages:** simple discovery; removes “types/live”; attractive for a small API.

**Defects:** concrete HTTP and every optional integration become unavoidable; DI and
environment choices pollute the provider graph; configured retries become indistinct
from provider contract; absorbing `live` into the wrapper discards or obscures the
substantive implementation repository’s independent heritage. It also cannot explain
Stripe web UI/webhooks or Mailgun’s multiple inbound/encoding contracts without
turning the core into a grab-bag.

**Disposition:** viable only when HTTP is the sole universal mechanism, adds no
optional integration concern, and the heritage graph has a single substantive owner.
The three pilot families do not satisfy that test. Specifically, “absorb
`swift-github-live` into `swift-github`” is rejected as the default hypothesis.

### Option C — mission triplet: standard + core + HTTP integration

**Shape:** `swift-{provider}-standard` (L2), unsuffixed `swift-{provider}` (L3), and
`swift-{provider}-http` (L3 integration). DI, environment, server-framework, and
other integrations are separate packages when present.

**Advantages:** layer-correct dependency direction; Foundation-free standard and core;
HTTP consumers opt in; core test doubles do not need a framework; existing `types`,
unsuffixed, and substantive `live` histories each receive a coherent successor mission.

**Defects:** more packages and a coordinated breaking graph reversal. The old
unsuffixed “preconfigured live” semantics cannot coexist with a transport-neutral
core under the same product without a cycle, so the pilot requires a deliberate major
break rather than a compatibility layer.

**Disposition:** **recommended default**, subject to the decision procedure and
provider pressure tests below. “Triplet” here is mission-based, not a renamed version
of the suffix pattern.

### Option D — finer provider-domain decomposition

**Shape:** version/domain standard and core packages (for example Stripe v1 vs v2 or
Mailgun Messages vs Reporting) plus integrations at the same semantic cuts.

**Advantages:** preserves real authority, version, encoding, auth, and dependency
boundaries; avoids a 600-file provider package forcing every dependency on every user.

**Defects:** a forced one-package-per-endpoint explosion would replace one bad rule
with another; shared provider identity and genuine domain coupling can be lost.

**Disposition:** required when the procedure finds distinct upstream dependency trees,
version authorities, wire mechanisms, or release compatibility. Prefer domain/version
targets inside one repository when they remain one package-level concern with the same
allowed dependencies; use separate packages when package-level dependencies or
version/release compatibility differ.

### Option E — optional integration targets or traits inside core

**Shape:** retain HTTP/DI integration targets in `swift-{provider}`, optionally behind
SwiftPM traits.

**Advantages:** fewer repositories; can access package/internal implementation.

**Defects:** the dependency still appears in the core manifest, so graph coupling
remains. [MOD-014] permits traits only when extraction cannot access required
non-public symbols or would create a cycle that cannot otherwise be removed.

**Disposition:** structural fallback only, decided integration-by-integration and
recorded explicitly. It is not the pilot default.

## Supervisor adjudications

The following decisions approve the GitHub architecture candidate. They resolve the
pilot questions without approving package mutation or generalizing the result beyond
the Tier 2 evidence.

1. **Breaking GitHub major and coordinated consumers.** The unsuffixed package changes
   mission in a deliberate breaking major release after every known direct consumer is
   migrated in the same arc. Existing releases and tags remain intact. There is no L4
   compatibility package, parallel compatibility branch, deprecated compatibility
   product, or retention of the old configured-live semantic surface.
2. **Final pilot spelling.** The exact package/product/module triples are
   `swift-github-standard` / `GitHub Standard` / `GitHub_Standard`, `swift-github` /
   `GitHub` / `GitHub`, and `swift-github-http` / `GitHub HTTP` / `GitHub_HTTP`.
   Narrow core products such as `GitHub Repositories` exist only when semantically
   cohesive. HTTP is a GitHub-recipient integration under [PKG-NAME-016], so its
   surface is `GitHub.HTTP`.
3. **L2 endpoint surface.** L2 retains only pure declarative provider-contract values
   and operations. Enum versus struct is not prescribed ecosystem-wide. The
   organization-repositories pilot uses the smallest semantic request, response, and
   operation values that require no parser, router, or case-path machinery. Client
   witnesses and traversal belong to L3.
4. **Institute transport types.** Selection of B4-owned HTTP, URI, and body types is
   an implementation entry gate after B4 releases the shared graph, not an unresolved
   architecture choice. The pilot uses the stable Institute owner types available at
   that gate and introduces no raw `[UInt8]` transport boundary.
5. **Webhook verification.** No webhook-signature work is in the GitHub Workspace
   pilot. In general, a provider standard may own a pure externally specified verifier
   only when it depends exclusively downward on an established L1/L2 cryptographic
   primitive or standard owner. Otherwise a dedicated provider-crypto integration
   owns it; L3 crypto never enters L2.
6. **Provider-specific cuts.** Stripe v1/v2 and Mailgun domain package cuts remain
   deferred to their evidence gates. Neither blocks the GitHub pilot.
7. **No compatibility window.** Principal direction after the initial supervisor
   review supersedes the proposed first-major deprecation window for historical
   `GitHub Types` and `GitHub Live` products. They are absent from the new major; the
   previous release/tag is the preserved compatibility boundary, and the known
   consumer sweep precedes the cut.
8. **No GitHub L4 service.** The pilot creates no configured GitHub service. Workspace
   owns token versus no-token selection, page/item bounds, ordering, filtering, and
   inventory policy.

**Contradiction resolved:** adjudications 1 and 7 originally permitted one new-major
deprecation window, while the later Principal direction requires an immediate major
break. The later direction controls. No other adjudication contradicts the mission,
layer, or heritage recommendation.

## Recommended package missions and dependency map

### Required semantic packages

| Package | Layer | One-sentence mission | Owns | Must not own |
|---|---|---|---|---|
| `swift-{provider}-standard` | L2 | Foundation-free representations of the provider’s externally published protocols, declarative endpoint inputs/outputs/operations, wire metadata, and inbound event/signature contract. | semantic IDs and wire values; request/response/event models; pure declarative endpoint operations; auth requirement metadata; pagination envelopes/tokens/links per domain; rate-limit/idempotency headers; pure webhook verification only when an established L1/L2 crypto owner permits a downward-only edge | callable clients; parsers/routers/case paths; URLSession/Foundation; environment; DI framework; L3 crypto; clocks/sleep; retry traversal; server adapters; app filters |
| `swift-{provider}` | L3 | Transport-neutral provider capabilities and workflows composed over the standard contract. | typed client witnesses/protocols; typed provider errors; one-page operations; provider-specific client-side pagination traversal; capability composition; explicit auth/configuration inputs; deterministic test seams | concrete HTTP engine; process environment; DI framework adapters; fixed global retry/rate defaults; Vapor/server/HTML; product policy |
| `swift-{provider}-http` | L3 integration | Adapt provider endpoint representations and injected authentication to the Institute HTTP client/executor. | route-to-request mapping; content negotiation; status/body decoding; response metadata; credential injection seam; HTTP-specific error mapping | credential discovery/storage; DI registration; global retry policy; environment defaults; webhook server handling; business dispatch |

The core graph is acyclic and points downward or across only at an essential join:

```text
L5 application
  ├─> optional L4 configured service (not in the GitHub pilot)
  ├─> swift-{provider}-dependencies ──> swift-{provider}
  ├─> swift-{provider}-http-server ───> swift-{provider}-standard + server
  └─> swift-{provider}-http ──────────> swift-{provider} + HTTP
                                           │
                                           v
                                swift-{provider}-standard
                                           │
                                           v
                                      L1/L2 substrate
```

The unsuffixed package never imports or re-exports `swift-{provider}-http`; the HTTP
integration depends on core. This reverses the historical core-to-live edge.

### GitHub pilot spellings

| Layer/role | Package | Product | Module / namespace |
|---|---|---|---|
| L2 provider contract | `swift-github-standard` | `GitHub Standard` | `GitHub_Standard` |
| L3 transport-neutral core | `swift-github` | `GitHub` | `GitHub` |
| L3 HTTP integration | `swift-github-http` | `GitHub HTTP` | `GitHub_HTTP`; recipient-owned `GitHub.HTTP` surface |

`GitHub Repositories` and similarly narrow products are allowed only when each is a
semantically cohesive core product. The historical `GitHub Types`, `GitHub Live`, and
configured-live unsuffixed surfaces are not products of the new major.

### Optional integration packages

These are generic working labels for providers that need them; the three GitHub pilot
package spellings above are final. Mission and dependency direction remain controlling.

| Package | Layer | One-sentence mission | Creation rule |
|---|---|---|---|
| `swift-{provider}-dependencies` | L3 integration | Register transport-neutral provider capabilities with the Institute DI system without making DI a core dependency. | Create when a DI adapter is vended; never put test doubles here merely because DI can store them. |
| `swift-{provider}-http-server` | L3 integration | Adapt generic raw inbound HTTP bytes/headers to standard webhook/event verification inputs and typed events without choosing an application server. | Separate from outbound HTTP; a framework-specific adapter such as `swift-{provider}-vapor` is a distinct L4 integration. |
| `swift-{provider}-environment` | L4 component | Map an explicit installation’s environment keys into provider configuration/credential values. | Create only for an intentionally documented default convention; no force unwraps; applications may instead compose directly. |
| `swift-{provider}-service` | L4 component | Assemble provider HTTP, credentials, clocks, and a documented retry/rate policy into an opinionated ready-to-run service. | Optional for a future provider only when the policy is independently coherent; explicitly excluded from the GitHub pilot. |

Per-package `{Module} Test Support` targets are not separate service packages by
default. They own deterministic fixtures, recorders, scripted clients, fake clocks,
and provider response samples appropriate to that package’s layer. Main client types
remain directly constructible without Test Support or DI.

### Exact responsibility decisions

#### Foundation-free transport

- L2 request/response/body fields use Institute byte, HTTP, URI, time, decimal, and
  semantic provider types; no Foundation types or imports.
- L3 core describes operations over provider representations; it does not know
  URLSession/URLRequest/Data.
- Concrete execution is `swift-{provider}-http`, built over the Institute HTTP stack.
- For GitHub, the exact B4-owned HTTP/URI/body types are selected only after the shared
  graph is released. The implementation must use the then-stable Institute owner
  types; raw `[UInt8]` is not an alternative.
- Foundation interoperability, if still needed for Apple callers, is an explicit leaf
  target/integration and never ambiently re-exported.

#### Authentication injection

- L2 models the provider’s declared auth schemes, requirement metadata, and semantic
  credential kinds without acquiring secrets.
- `swift-{provider}-http` accepts a credential/auth-header provider explicitly at
  initialization or call scope. It does not read process environment.
- Environment, vault, rotation, account/region selection, and redaction are L4/L5.
- DI registration is a separate integration. Tests inject credentials/client closures
  directly and never inherit a production token through a “testValue = liveValue”.

#### Pagination

- L2 owns endpoint-specific page request fields and response/link/token envelopes.
- L3 owns traversal as a cancellation-aware, typed-throws workflow over a one-page
  client. It does not pretend every provider has one pagination model.
- Collection vs streaming, maximum pages/items, duplicate handling, consistency
  expectations, and final sorting are caller-visible policy inputs.
- Workspace’s GitHub inventory explicitly follows `Link rel=next`, filters
  `archived == false`, and sorts deterministically. Workspace owns token/no-token
  selection, page/item bounds, ordering, and inventory policy; documentation does not
  promise a snapshot across pages, so duplicate/missing risk remains explicit.

#### Retry and rate limiting

- L2 owns response classifications and provider-defined headers/reasons.
- L3 HTTP surfaces retry-relevant metadata and idempotency characteristics but does
  not silently replay mutating operations.
- A generic retry executor belongs to the generic resilience/HTTP owner. Provider
  adapters translate metadata into that executor’s inputs.
- Attempt ceilings, clocks, jitter, concurrency, token buckets, wait budgets, mutation
  eligibility, and shutdown/cancellation are explicit L4/L5 policy. Provider guidance
  constrains defaults but does not justify hard-coded universal windows.

#### Webhooks and other inbound delivery

- L2 owns event payloads, signature-header/body representations, and provider
  status/retry contract. It owns a pure externally specified verifier only when the
  implementation depends exclusively downward on an established L1/L2 crypto owner.
- Otherwise verification belongs to a dedicated provider-crypto integration; an L2
  standard never imports L3 crypto.
- Raw-body preservation and an HTTP-server adapter are dedicated integration concerns.
- Secret lookup, timestamp tolerance, replay cache, persistence, idempotency, response
  status, event routing, and business handling are explicit integration/application
  policy.
- Outbound API “webhook endpoint management” remains an outbound endpoint domain; it
  is not the same concern as receiving deliveries.
- The GitHub Workspace pilot includes no webhook-signature or delivery-receiving work.

#### DI adapters and test doubles

- Core clients are ordinary values with typed closure/capability members or protocols
  and explicit initializers.
- DI adapters only register those values. Core never imports the DI framework.
- Test doubles and fixtures live in the owner’s Test Support target and are usable
  without DI. Live credential tests are separately gated, opt-in, and non-default.

#### Application/component policy

- L4 may provide an opinionated reusable configured service for a future provider when
  the policy itself is a coherent product. The GitHub pilot does not.
- L5 chooses organizations/accounts/domains, public/non-archived filtering, inventory
  ordering, secret source, budgets, observability, deployment, and business event
  handling.
- A convenience umbrella does not earn L3 placement by re-exporting lower packages;
  it needs a mission and a legal dependency direction.

## Repeatable decision procedure

Apply this per provider and repeat it whenever an API version/domain changes:

1. **Inventory authorities and versions.** List provider API versions, regions,
   protocol authorities, inbound/outbound families, and independently versioned
   domains. Do not start from existing targets.
2. **Classify each declaration.** Assign exactly one of: provider wire value;
   endpoint representation; outbound capability; inbound event; concrete execution;
   auth mechanism; credential policy; pagination traversal; retry/rate policy; DI;
   test support; L4 assembly; L5 policy.
3. **Fix the layer by essence.** Provider-published protocol is L2; composed capability
   or cross-domain adapter is L3; opinionated assembly is L4; product choice is L5.
   Refactor dependencies to that layer—never move the essence to match bad edges.
4. **Split every cross-package integration.** HTTP, DI, environment, crypto framework,
   HTML, and server-framework joins get dedicated packages unless the documented
   [MOD-014] trait fallback applies.
5. **Choose target versus package.** Keep domain targets in one package only when they
   share authority/version compatibility and their package-level dependency set is
   still honest. Split packages when dependency trees, version/release compatibility,
   licensing, auth/base URL, or wire mechanisms make the package manifest lie.
6. **Check semantic cohesion.** A provider-wide repository is acceptable; a
   provider-wide undifferentiated target is not. Use domain/version targets and a
   deliberate umbrella only when the umbrella is acyclic.
7. **Eliminate ambient interop.** Main targets are Foundation-free. Put required
   interoperability in explicit leaves and replace convenience re-exports with direct
   imports/dependencies.
8. **Type boundaries.** Give identity/validation/secrecy/unit/encoding concepts
   semantic types and typed errors. Preserve open-ended provider text as text; avoid
   ceremonial wrappers without a law.
9. **Assign heritage before moving files.** For every destination mission, identify
   the repository containing its substantive implementation history. URL popularity or
   an unsuffixed name does not override substantive ownership.
10. **Prove consumers and old URLs.** Sweep local consumers in the same arc, then run
    clean-room fixtures using both new and historical URLs/product names. Redirects
    are tested, not assumed.
11. **Stop at every external mutation.** Transfer, rename, archive, replacement-repo
    creation, push, tag, and publish each require action-specific authorization.

This procedure intentionally does **not** conclude that every provider has exactly two
or three repositories.

## Provider pressure tests

### GitHub — fits the mission triplet, with a pilot-sized domain

GitHub’s REST contract can support a provider-wide L2 repository with narrow domain
targets. The pilot should implement only, using the adjudicated
package/product/module spellings above:

- `GitHub.Organization.ID`/name and repository semantic identity needed by Workspace;
- `GET /orgs/{org}/repos` request/response representation with `type=public`,
  `per_page`, `page`, `archived`, `visibility`, and `Link` navigation;
- one-page transport-neutral client capability with typed errors;
- cancellation-aware pagination in L3;
- an HTTP adapter with optional auth injection (public-only operation may use none);
- deterministic Workspace projection: remove archived entries, sort by stable semantic
  key, and retain the documented cross-page consistency limitation.
- no webhook-signature, delivery-receiving, or configured-service surface.

The existing `GitHub.Repositories.List` models the authenticated-user endpoint, not
the required organization endpoint (`GitHub.Repositories.API.swift:37-40` routes
`/user/repos`). It cannot simply be wired into Workspace. The current repository model
already contains `archived` and `visibility`
(`GitHub Types Shared/Common.swift:16-49`) but uses broad Foundation/raw fields and
must be narrowed or semantically repaired for the pilot.

**No fit:** GitHub API-version values are time-sensitive, so “latest” is not a timeless
standard default. Public/non-archived is not one server predicate, and pagination has
no documented snapshot guarantee. Those remain explicit configuration/client policy.

### Stripe — no fit for one undifferentiated standard

Stripe validates the layer split but rejects uniform provider-wide mechanisms:

- v1 and v2 differ in request encoding, pagination, versioning, and idempotency;
- resources span Billing, Connect, Issuing, Treasury, Identity, Tax, Web Elements,
  Events, and webhook endpoint management;
- the unsuffixed package currently combines event typing, webhook verification,
  environment, HTML components, and commented application sync policy;
- the current live auth router hard-codes v1 form content and one dated version, while
  official docs now require explicit v1/v2 distinctions.

**Disposition:** retain a provider-wide repository only with explicit version/domain
targets and no dependency pollution. If v1/v2 compatibility or dependencies diverge
at package level, split standard/core packages by version. Web Elements becomes an
HTML integration/component; inbound webhook verification/server handling is separate;
Apple Crypto is not a core-provider dependency. The package-versus-target cut is
deferred to Stripe’s evidence gate and does not block GitHub. No Stripe mutation is
approved here.

### Mailgun — no fit for provider-wide pagination, encoding, or inbound retry

Mailgun validates domain-oriented targets and rejects a universal mechanism:

- Messages/MIME use multipart; Metrics can use JSON;
- Metrics, Events, and Mailing Lists use different pagination contracts;
- event webhooks and inbound message forwarding use different encodings and retry
  schedules;
- region and endpoint versions vary;
- the current L2 package’s form/multipart/router code is machinery that belongs out,
  while domain models remain L2.

**Disposition:** a Mailgun standard repository may remain provider-wide only as a
collection of honest domain targets. Messages, Reporting/Events, Receiving/Routes,
and Account Administration are candidate package cuts when their dependency/version
graphs differ. The package-versus-target cut and parallel-root reconciliation are
deferred to Mailgun’s evidence gates and do not block GitHub. The B4 types recensus is
complete at `2f69057`; no Mailgun mutation is approved here.

## Owned-source heritage disposition

### Principles

1. Preserve each repository’s full existing history unless a separately reviewed
   history operation is authorized. No squash is proposed.
2. Repository transfer/rename is preferred to copy-and-recreate because it preserves
   git data, issues/PRs/stars, and redirects. It remains an external mutation requiring
   explicit authorization.
3. Assign the closest successor mission to the repository whose current and historical
   source substantively implements it.
4. When files cross repositories, preserve their relevant path history using a reviewed
   history-filter/import procedure in clean-room clones; do not use a plain copy as the
   default. The exact filter/merge mechanics require a dedicated rehearsal because
   merging histories can duplicate unrelated trees or create confusing roots.
5. A reconciliation commit may reshape the preserved history into the approved current
   architecture. It must name source commits and moved paths.
6. Old URL redirects and SwiftPM package identity/product compatibility are separate
   claims; both require clean-room tests.

### Per-repository disposition

| Existing repository | Substantive heritage | Candidate successor | Disposition before authorization |
|---|---|---|---|
| `swift-github-types` | 41 commits since 2025; provider models plus routers/clients | `swift-github-standard` | Preserve repository and history; rename only after authorization; retain L2 model/endpoint history, export L3 path history to core/HTTP destinations. |
| `swift-github-live` | 47 commits; concrete auth, URLRequest, throttling, retry | `swift-github-http` | Preserve as HTTP-integration history owner; extract env/DI/retry policy rather than absorb repository into wrapper. |
| `swift-github` | 24 commits; public unsuffixed URL, thin wrapper/current convenience | `swift-github` L3 core | Preserve URL and history; replace wrapper mission only in the coordinated graph cut; import relevant client history from `types`. Thinness does not let it consume `live` history. |
| `swift-stripe-types` | 58 commits; 63k-line model/router/client corpus | `swift-stripe-standard` or version/domain standards | Preserve; split mixed file histories by semantic range/path; no whole-repo “types = standard” claim until v1/v2 decomposition is approved. |
| `swift-stripe-live` | 53 commits; broad concrete execution | `swift-stripe-http` or version/domain HTTP integrations | Preserve as execution-history owner; do not fold into unsuffixed package. |
| `swift-stripe` | 45 commits; public URL plus webhook/HTML/event composition | `swift-stripe` L3 core, with extra concerns extracted | Preserve; route webhook, Crypto, HTML, environment, and app-policy history to their semantic owners through rehearsed history extraction. |
| `swift-mailgun-types` | 120 commits since 2025; split-out model/router/client corpus; clean `2f69057` adds 43 explicit Body-coding sites plus parity evidence | `swift-mailgun-standard` or domain standards | Preserve; post-B4 recensus complete at the committed SHA. The coding migration is router machinery and therefore remains in the move-out history set. |
| `swift-mailgun-live` | 170 commits since 2024; concrete HTTP/auth/decoder implementations | `swift-mailgun-http` or domain HTTP integrations | Preserve as a substantive implementation owner; never treat the current thin wrapper as sole owner. |
| `swift-mailgun` | 154 independent commits since 2024; canonical public wrapper lineage | `swift-mailgun` L3 core | Preserve independently. The parallel 2024 roots are a heritage conflict requiring Principal adjudication before any cross-history import; neither history may overwrite the other. |

The recommended GitHub outcome therefore uses all three histories rather than
“absorbing live.” Stripe follows the same default subject to version/domain splits.
All nine successor dispositions are approved as architecture candidates. Mailgun’s
exact cross-history import remains deferred until the two parallel 2024 lineages are
compared commit-by-commit; that provider-specific evidence gate does not block GitHub.

### GitHub history-transfer rehearsal (2026-07-22)

This rehearsal ran only in local clones under
`/private/tmp/github-heritage-rehearsal.DBKrgL`. It changed no real repository history,
remote, manifest, product, or release. The source repositories were clean on `main`
and matched their `origin/main` branches at:

| Mission route | Source head | Source path | Destination head/path |
|---|---|---|---|
| types → core client | `cb54d913409678d188db3d4feb8bcafbc2eec21d` | `Sources/GitHub Repositories Types/GitHub.Repositories.Client.swift` | `b3bca21978f3fd82aaf0eea7e9c6a739672bf5ba` / `Sources/GitHub Repositories/GitHub.Repositories.Client.swift` |
| live → HTTP execution | `aafa320fa77e8ce51f37ae83d83df2092a187d3e` | `Sources/GitHub Repositories Live/GitHub.Repositories.Client.live.swift` | same repository / `Sources/GitHub Repositories HTTP/GitHub.Repositories.Client.live.swift` |

The types-to-core rehearsal used a path-limited rewritten branch and an explicit
unrelated-history merge:

```sh
git clone --no-local /Users/coen/Developer/swift-standards/swift-github-types types-client-filter
git filter-repo --force \
  --path 'Sources/GitHub Repositories Types/GitHub.Repositories.Client.swift' \
  --path-rename 'Sources/GitHub Repositories Types/:Sources/GitHub Repositories/'
git clone --no-local /Users/coen/Developer/swift-foundations/swift-github core-import
git remote add types-client ../types-client-filter
git fetch types-client main
git merge --allow-unrelated-histories --no-ff types-client/main \
  -m 'Rehearsal: import GitHub repositories client history'
```

`git filter-repo` parsed all 41 source commits but retained exactly the five commits
that changed the client path. Its original-to-filtered commit map was:

| Original commit | Filtered commit |
|---|---|
| `63b64124e79519e9da8f457c1429753b542dc0cc` | `ff428d4916439be27127325389b0131f288895a3` |
| `3d66b879a36a4d71ad5817e8100b0c8c892e7601` | `9a1e060a0e9a89853fc802f0bd3bade65eb1a00c` |
| `17d5dde174308b5dce9e4b695fbfb57735e7ced2` | `607a6dc76f026fa0e99496eddb2ed83d1c2d9aa4` |
| `a8266d9c6bc47e8567511bf43c7107e6418f80ab` | `df3ebe43f75d1a0dbe20fe15e5b6449c143ba7e0` |
| `7055b52273d9c74ab138ff1fb36580b2228c5843` | `e02155e2dd04e110d51e1a8fca423d17cc14a7ae` |

The clean merge completed without a conflict at rehearsal commit
`4ba294787d3ad5a2d000c40db17dd40319d07573`. Its parents were the unchanged core
head `b3bca21978f3fd82aaf0eea7e9c6a739672bf5ba` and the filtered client head
`e02155e2dd04e110d51e1a8fca423d17cc14a7ae`. `git log --follow` on the destination
path reported all five retained client commits back to the original file-creation
change.

The live-to-HTTP rehearsal required no history filtering or cross-repository merge.
The substantive execution repository is already the approved HTTP successor, so a
same-repository path move is sufficient:

```sh
git clone --no-local /Users/coen/Developer/swift-foundations/swift-github-live http-successor
git mv 'Sources/GitHub Repositories Live' 'Sources/GitHub Repositories HTTP'
git commit -m 'Rehearsal: route repository execution source to HTTP target'
```

Git recorded the source as a 100% rename at rehearsal commit
`2dd7997eb25de34f00e02ff882b13bcb9df53395`, whose sole parent was the unchanged
live head `aafa320fa77e8ce51f37ae83d83df2092a187d3e`. `git log --follow` reached the
execution file’s initial commit `93ac4ff78bc9938bd5a52eedbbc79be403b55ae9`.

Risks and required controls for the authorized real operation are:

1. Filtering necessarily rewrites the five client-path commit identifiers and strips
   their signatures; the reconciliation record must retain the original-to-filtered
   map above.
2. The import creates an intentional second root in core. Review must compare the
   filtered tree before merge so unrelated types history cannot enter by accident.
3. `git filter-repo` removes the filtered clone’s `origin` as a safety measure. The
   real procedure must fetch the reviewed local filtered branch into core and must
   never force-push a rewritten types branch.
4. The imported client still contains historical untyped errors and legacy
   dependencies. Preserve its history first, then reshape it in a named reconciliation
   commit; do not plain-copy a corrected replacement into core.
5. Git’s rename detection is similarity-based rather than stored metadata. Keep the
   live-to-HTTP move content-neutral, commit it separately, and verify with
   `git log --follow` before changing implementation.
6. Repository renames, remote changes, tags, publication, and pushes remain separate
   external mutations requiring action-specific authorization.

### Authorized local GitHub pilot checkpoint (2026-07-22)

The supervisor subsequently authorized the reviewed real local heritage operations,
manifest cut, and smallest source/test wave. No remote URL, repository name, tag,
release, visibility, Workspace, consumer, or external state changed. The repository
directories and remotes retain their historical names until separately authorized;
therefore local path dependency identities still use `swift-github-types` and
`swift-github-live` even though their manifests expose the final package missions.

The final local package surfaces are:

| Existing local repository | Final manifest/product/module | Local checkpoint |
|---|---|---|
| `swift-github-types` | `swift-github-standard` / `GitHub Standard` / `GitHub_Standard` | `93f12e81c7fe1604a99ac240628d44982dc5a849` |
| `swift-github` | `swift-github` / `GitHub` / `GitHub` | `74ecfc43172ff54eda3afa2143712fd529933963` |
| `swift-github-live` | `swift-github-http` / `GitHub HTTP` / `GitHub_HTTP` | `98b2ca40b5a1c07833855554b547f9c4a1b79197` |

The real types-to-core import preserved the reviewed graph exactly. Merge
`fd1bb7383e2deb368be27fbfa6da0397c1e9be85` has parents
`b3bca21978f3fd82aaf0eea7e9c6a739672bf5ba` and
`e02155e2dd04e110d51e1a8fca423d17cc14a7ae`, and its first-parent diff adds only
the reviewed 38-line client file. The temporary import remote was removed.

The first core reshape commit, `f831284b9c198f693b6233579c4482bb3886c9fc`,
combined its final path move with substantial content changes, which caused ordinary
`git log --follow` to stop before the five imported commits. Before external use, the
supervisor authorized a heritage-only correction. A recoverable local backup ref
`heritage/core-before-follow-split` still points exactly to `f831284`. The corrected
chain is:

1. `0e6c0d87d0ed68c56665daa7d5ed52386576b2a2`, parent `fd1bb738`, is a content-neutral
   R100 rename from `Sources/GitHub Repositories/GitHub.Repositories.Client.swift`
   to `Sources/GitHub/GitHub.Organization.Repositories.Client.swift`.
2. `74ecfc43172ff54eda3afa2143712fd529933963`, parent `0e6c0d87`, applies the identical
   manifest, source, and test reshape formerly held by `f831284`.

Both `f831284` and `74ecfc4` have tree
`66ae5b97b66e7273be0b3a1caa587762357590d4`; `git diff --exit-code` reported no
difference. Ordinary `git log --follow` from the final client path reaches `0e6c0d8`
and all five filtered commits from `e02155e2` through `ff428d49`.

The HTTP execution lineage is similarly explicit:

1. `7bc5e7cc01260cdc184507a45d91b181d1d81156` is the approved R100 move from
   `Sources/GitHub Repositories Live` to `Sources/GitHub Repositories HTTP`.
2. `ff1185678e3ac54fae5f836963f18c1eaee726cd` is a second content-neutral R100 move
   of the repository client to `Sources/GitHub HTTP/GitHub.HTTP.Client.swift`.
3. `b0db31c5a761286cc04190018908c221b3e7716e` applies the final HTTP reshape.
4. `98b2ca40b5a1c07833855554b547f9c4a1b79197` adds the RFC 8288 dependency and
   typed default pagination witness without changing the preserved execution path.

Ordinary `git log --follow` reaches the original execution commit
`93ac4ff78bc9938bd5a52eedbbc79be403b55ae9`. Standard, core, and HTTP main targets
are Foundation-free. Core owns the typed one-page capability plus cancellation-aware,
bounded traversal and explicit duplicate/ordering inputs. HTTP uses Institute
`HTTP.Request`/`HTTP.Response`, RFC 3986 URI values, `Byte`, and `JSON`; authentication,
execution, and pagination are injected, with no environment, DI, retry, or configured
service policy.

Sequential focused SwiftPM gates passed under Swift 6.3.3:

- Standard: 3 tests in 4 suites;
- Core after the heritage correction: 4 tests in 4 suites;
- HTTP against the corrected core chain before the RFC owner slice: 2 tests in 3
  suites; after the RFC owner slice: 6 tests in 5 suites.

**Implementation no-fit at the prior checkpoint:** the local `swift-rfc-8288`
repository had no implemented package or source surface, so GitHub HTTP correctly did
not guess or own generic Link-header parsing. The owner-package slice below resolves
that no-fit locally. Workspace and consumer integration remain separately gated.

### RFC 8288 owner-package vertical slice (2026-07-22)

The authorized local vertical slice resolved that no-fit in the existing clean
`swift-ietf/swift-rfc-8288` owner repository at
`d15922e7540f6bdabe81f564d1bf616953b22c59`. RFC 8288 remains a current Proposed
Standard that obsoletes RFC 5988. Its normative model makes the link target a URI
reference and its HTTP serialization defines `Link = #link-value`, where each
`link-value` contains an angle-bracketed URI reference and semicolon-delimited link
parameters. Verified errata 5878 corrects the Appendix B algorithm to update
`target_attributes`; verified editorial erratum 5319 supplies the omitted `LOALPHA`
production. The implementation follows the normative body and incorporates those
errata rather than copying the advisory Appendix B pseudocode literally.

**Mission:** L2 `swift-rfc-8288` / `RFC 8288` / `RFC_8288` implements the RFC 8288
Web Linking model and its HTTP `Link` field representation and parsing.

**Dependency decision:** use one RFC 8288 target with downward L1 `Byte`/byte-parser
dependencies and direct, essential, acyclic L2 dependencies on `RFC 3986` for
`URI-reference` and `RFC 9110` for HTTP header-field, token, optional-whitespace,
quoted-string, and comma-list semantics. Do not add a
separate `HTTP RFC 8288` integration target: HTTP field serialization is part of RFC
8288's own normative scope, not an optional recipient adaptation, and a second target
would divide one specification without changing dependency legality. Do not depend
on the `HTTP Standard` convenience converger when the authority package can depend on
the underlying `RFC 9110` owner directly.

The minimum public surface is:

- `RFC_8288.Link`, containing a typed `RFC_3986.URI` reference and ordered,
  loss-preserving parameters;
- `RFC_8288.Link.Relation`, including semantic `.next` matching and support for
  registered and extension relation types;
- `RFC_8288.Link.Parameter` with a case-insensitive semantic name, optional decoded
  token/quoted value, and retention of unknown parameters;
- `RFC_8288.Link.Parse`, accepting one field value, multiple field values, or
  `RFC_9110.Headers`, and throwing only its typed parse error.

The parser owns delimiter state because commas and semicolons inside quoted strings
are data, not separators. It uses the established RFC 9110 token/quoted-string/OWS
parsers and the ecosystem `Byte` boundary; it does not scan a `String` as raw
`UInt8`, import Foundation, or recover malformed input by guessing. Multiple field
instances are accumulated in order. Only the first `rel` parameter contributes
relation types as required by RFC 8288; later duplicate `rel` parameters remain in
the loss-preserving parameter list but do not alter semantic relation lookup.

RFC 3986 currently exposes typed URI-reference parsing and query access, which are
the capabilities required here. Its general `URI.resolve` implementation still
contains an explicit full-section-5 TODO and therefore is not used or wrapped by
this slice. RFC 8288 preserves the URI reference; it does not claim that the parsed
value is already resolved against representation context. GitHub's default
pagination mapper reads an explicit `page` parameter from the `rel=next` target's
query and otherwise fails with a typed error. It neither increments the current page
nor implements a local URI resolver.

Acceptance requires focused tests for: a single link; multiple comma-separated
link-values; multiple `Link` field instances; `rel=next` among multiple relation
types; token and quoted parameter values; quoted comma, semicolon, and backslash
escape handling; relative and absolute URI references; unknown and valueless
parameters; duplicate `rel` first-value semantics; empty-list members allowed by
HTTP list syntax; and typed failures for missing brackets, invalid URI references,
invalid parameter names/values, unterminated quoted strings, and trailing junk.
GitHub HTTP adds exact success, multi-link, no-next, and malformed-Link tests while
retaining its injectable pagination witness for deterministic callers.

Local verification deliberately uses path dependencies. Before publication every
such edge must become canonical and versioned in one reviewed release arc:

| Manifest | Local verification edge | Required publication edge |
|---|---|---|
| `swift-rfc-8288/Package.swift` | `../../swift-primitives/swift-byte-primitives` | `https://github.com/swift-primitives/swift-byte-primitives.git` |
| `swift-rfc-8288/Package.swift` | `../../swift-primitives/swift-byte-parser-primitives` | `https://github.com/swift-primitives/swift-byte-parser-primitives.git` |
| `swift-rfc-8288/Package.swift` | `../swift-rfc-3986` | `https://github.com/swift-ietf/swift-rfc-3986.git` |
| `swift-rfc-8288/Package.swift` | `../swift-rfc-9110` | `https://github.com/swift-ietf/swift-rfc-9110.git` |
| `swift-github-http/Package.swift` | `../../swift-ietf/swift-rfc-8288` | `https://github.com/swift-ietf/swift-rfc-8288.git` |

The local owner-package commit must cite RFC 8288 plus verified errata 5878/5319;
the separate GitHub HTTP commit must cite GitHub's REST pagination contract and map
only the RFC-owned semantic result. No repository rename, remote change, push, tag,
release, Workspace, Internal, or consumer mutation is authorized by this entry.

The implemented owner checkpoint is
`99ceca3769af5024c5d69b46fa276e43bc97e154` in `swift-rfc-8288`, parented directly
by the previously clean `d15922e7540f6bdabe81f564d1bf616953b22c59`. It creates
the `RFC 8288` product and ten manifest/source/test files. The main target imports no
Foundation and exposes no raw-`UInt8` boundary. Its focused SwiftPM gate passes seven
tests in one suite, including seven malformed-field arguments.

The separate recipient commit is
`98b2ca40b5a1c07833855554b547f9c4a1b79197` in `swift-github-http`, parented by
`b0db31c5a761286cc04190018908c221b3e7716e`. It retains explicit
`Pagination.Witness<Failure>` injection, adds a typed RFC-backed witness and
specialized default client initializer, and maps only one unambiguous `rel=next`
target with exactly one explicit positive `page` query value. The post-format focused
SwiftPM gate passes six tests in five suites: the two prior adapter/authentication
tests plus exact success, multi-link, no-next, and malformed-Link cases. Both package
worktrees are clean; neither commit is pushed.

### URL and product continuity

- Proposed repository renames should use GitHub’s rename/transfer mechanism, not
  replacement repos, so old repository URLs redirect.
- Preserve every previous release and tag. They remain the compatibility and recovery
  boundary for consumers that cannot yet adopt the new major.
- The unsuffixed product’s old “configured implementation” semantics conflict with
  the new transport-neutral core because core cannot depend back on HTTP. This is a
  deliberate breaking major change, not something a re-export can hide. Migrate every
  known direct consumer in the same arc before the cut. Do not publish historical
  `GitHub Types` or `GitHub Live` compatibility products in the new major, create an
  L4 compatibility package, maintain a parallel branch, or create a core↔HTTP cycle.
- Test a fixture that declares each historical URL and `package:` identity. GitHub
  redirect behavior alone does not prove SwiftPM identity compatibility. Historical
  product resolution is verified against its preserved release, not promised by the
  new major.

### Local topology follow-up after repository rename

The public repository identities are canonical, but the two clean local clones still use
their historical directory basenames:

| Canonical repository | Current local path | Intended local path |
|---|---|---|
| `swift-standards/swift-github-standard` | `/Users/coen/Developer/swift-standards/swift-github-types` | `/Users/coen/Developer/swift-standards/swift-github-standard` |
| `swift-foundations/swift-github-http` | `/Users/coen/Developer/swift-foundations/swift-github-live` | `/Users/coen/Developer/swift-foundations/swift-github-http` |

This does not weaken the anonymous canonical clean-room evidence, but it is local
topology debt. It can reintroduce identity confusion into mirror-backed builds,
navigation, and path-based consumers. The 2026-07-22 read-only preflight found:

- both historical-path clones clean on `main`, with neither intended destination path
  present;
- no process command line using either historical or canonical GitHub basename, but
  multiple active cclsp servers whose generated compilation database contains the
  historical absolute paths;
- eight current global SwiftPM mirror entries: bare and `.git` spellings for the
  historical `coenttb` and Institute URLs, all pointing at the two historical local
  paths; no canonical `swift-github-standard` or `swift-github-http` mirror key;
- active path/product references in the protected `Internal/institute-all` manifest,
  Internal workspaces and schemes, `swift-identities-github`, and `repotraffic`;
  historical audits, reports, and captured results that must remain historical; and
- no live mirror-regeneration command in the current durable Scripts checkout: the
  former `sync-mirrors` implementation and alias ledger were deliberately removed by
  Scripts commit `f74e673`. Therefore the global mirror JSON must not be hand-edited
  or regenerated through a retired tool without an explicit current owner decision.

The migration is a separate coordinated maintenance step, not part of Research
durability and not licensed by repository-rename authorization alone:

1. obtain ownership clearance from the lead, networking task, B5, Internal, navigation,
   and the owners of every active consumer reference; require no build, resolve, editor,
   or navigation-index refresh to be using either clone;
2. snapshot the two clean SHAs/origins and the global mirror configuration, then decide
   the current authoritative mirror-management mechanism and the retention/removal rule
   for historical redirect keys;
3. move only the two clean directories to their canonical basenames; do not reclone,
   delete, rewrite history, or change their already-canonical origins;
4. update canonical and intentionally retained historical mirror keys atomically to the
   new paths, validate JSON and identity uniqueness, and prove both mirror-backed local
   resolution and mirror-bypassed anonymous canonical resolution;
5. migrate active path/product consumers only in their owning tasks. Do not rewrite
   historical evidence. Regenerate the navigation compilation database/index and
   restart cclsp after the paths move;
6. verify both repositories remain clean at the accepted public SHAs, all active path
   references use the canonical basenames, mirror keys resolve to existing directories,
   and the GitHub family tests remain green. If any check fails, restore the mirror
   snapshot and move both directories back before releasing the maintenance window.

Until those gates are scheduled and owned, do not rename either local directory.

### Publication and Workspace inventory checkpoint (2026-07-22)

#### Publication evidence

The canonical publication graph is now live, bottom-up:

| Package | Canonical public `main` | Publication action |
|---|---|---|
| `swift-rfc-8288` | `a57596f70961a0603b68931c18ce7afcd5420c2d` | changed from private to public, then pushed |
| `swift-github-standard` | `368f548deac189ce37510ceea40daf417e4a1dbe` | renamed in place from `swift-github-types`; content contract and eligibility fields published |
| `swift-github` | `a248823bf423c61fc8d48fee201fd012d7203fe6` | transport-neutral content capability published at its existing canonical URL |
| `swift-github-http` | `0bdcd45774112bca53042bc3463c81b5089a8970` | renamed in place from `swift-github-live`; content HTTP adapter published |

All four repositories are public, use `main`, and resolve at the named canonical URLs.
Both historical GitHub repository URLs redirect to their renamed successors. No
replacement repository, force push, tag, release, archive, delete, or published-history
rewrite occurred.

The controlling clean-room evidence uses Swift 6.3.3 with isolated SwiftPM
configuration, security, and cache directories plus `--disable-netrc`. Every observed
fetch used a canonical `https://github.com/...` URL:

| Package | Result |
|---|---|
| RFC 8288 | 7 tests / 1 suite passed |
| GitHub Standard | 6 tests / 7 suites passed at `368f548deac189ce37510ceea40daf417e4a1dbe` |
| GitHub core | 6 tests / 7 suites passed at `a248823bf423c61fc8d48fee201fd012d7203fe6` |
| GitHub HTTP | 9 tests / 6 suites passed at `0bdcd45774112bca53042bc3463c81b5089a8970` |

An earlier apparent pass is explicitly **not evidence**: user-level SwiftPM mirrors
silently redirected canonical URLs to local working repositories. That run was rejected,
the final HTTP process was stopped, and every package was rerun with isolated anonymous
SwiftPM state. Publication claims above rely only on the isolated rerun.

The final HTTP command ran from the fresh anonymous clone
`/private/tmp/github-content-cleanroom.wIPZOB/http` and exited zero:

```sh
env TOOLCHAINS=org.swift.633202606251a swift test --disable-netrc --disable-keychain \
  --config-path ../config --security-path ../security --cache-path ../cache \
  --scratch-path ../scratch-http
```

Its resolved direct identities and canonical URLs were `swift-github` at
`https://github.com/swift-foundations/swift-github.git` (`a248823`),
`swift-github-standard` at
`https://github.com/swift-standards/swift-github-standard.git` (`368f548`),
`swift-json` at `https://github.com/swift-foundations/swift-json.git` (`400a67c`),
`swift-rfc-3986` at `https://github.com/swift-ietf/swift-rfc-3986.git`
(`0987b9a`), `swift-rfc-8288` at
`https://github.com/swift-ietf/swift-rfc-8288.git` (`a57596f`), and
`swift-http-standard` at
`https://github.com/swift-standards/swift-http-standard.git` (`d5f3982`).
The isolated configuration contained no mirrors, and both netrc and keychain credential
loading were disabled; neither global mirrors nor credentials affected this result.

#### Configured organizations and layer annotations

Workspace inventory discovery is bounded to these public GitHub organizations:

| Layer | Organizations |
|---|---|
| L1 Primitives | `swift-primitives` |
| L2 Standards convergence | `swift-standards` |
| L2 Standards authorities | `swift-ietf`, `swift-iso`, `swift-w3c`, `swift-whatwg`, `swift-ieee`, `swift-iec`, `swift-ecma`, `swift-incits`, `swift-nist`, `swift-linux-foundation`, `swift-microsoft`, `swift-arm-ltd`, `swift-intel`, `swift-riscv` |
| L3 Foundations | `swift-foundations` |
| L4 Components | `swift-components` |
| L5 Applications | `swift-applications` |

The organization table supplies the default layer for newly discovered repositories.
The inventory generator must preserve the existing `Workspace.json` annotation for a
repository matched by canonical owner/name; it must never recalculate and overwrite an
existing manual layer annotation silently. A transfer that makes the retained annotation
disagree with the organization default is a review error, not an automatic rewrite.
Unknown future application-owned annotation fields must likewise round-trip or block
regeneration until the schema owns them. Stable output order is layer, organization, then
repository name, using exact scalar ordering and deterministic JSON serialization.

The `swift-institute` meta organization is deliberately outside automatic package
discovery: it contains governance, research, skills, and applications whose repository
root is not necessarily a Swift package. A future explicit entry may include a package
there, but meta-org membership alone never grants eligibility.

#### Eligibility decision

A repository is eligible only when all of the following hold:

1. it belongs to a configured organization and the list response reports public
   visibility, not archived, not disabled, and not a fork;
2. `GET /repos/{owner}/{repo}/contents/Package.swift` reports a root entry whose provider
   kind is `file` on the default branch;
3. its canonical owner/name is not in the application deny set; and
4. its existing manual annotation is valid for the current Workspace schema.

The organization-repositories endpoint is therefore necessary but insufficient. Its
response exposes repository metadata, while package eligibility depends on a separate
repository-content lookup. GitHub documents that public repository content can be read
without authentication, that the path is required, that the default branch is used when
`ref` is omitted, and that absence is reported as `404` [Verified: 2026-07-22, GitHub REST
repository contents documentation]. The smallest legal owner extension is:

- L2 `GitHub.Repository.Content`: declarative owner/repository/path request, provider
  content-kind response, and operation value;
- L3 `GitHub.Repository.Content.Client`: one transport-neutral optional lookup, where
  provider absence is `nil` and other failures remain typed;
- L3 `GitHub.HTTP`: exact GET/path/header mapping, JSON response decoding, and `404` to
  absence mapping.

That extension is published in the three commits named above. Its exact contracts are:

- `GitHub Standard` owns the provider-declared organization/repository identity,
  nonempty relative content path, content kinds (`dir`, `file`, `submodule`, `symlink`),
  request, response, and operation values. Repository summaries now retain provider
  `archived`, `disabled`, `fork`, and `visibility` fields; they do not decide Workspace
  eligibility.
- GitHub core owns `GitHub.Repository.Content.Client<Failure>`, whose injected
  `@Sendable` lookup returns an optional response. `nil` means only provider-declared
  absence; a generic typed `Failure` preserves all other transport-neutral failures.
- GitHub HTTP owns request construction and wire decoding. It maps provider `404` to
  `nil`; maps any other unsuccessful status to `.status`; and keeps request-path,
  scheme, header, execution, and JSON/content-kind failures distinct in
  `GitHub.HTTP.Error`. No authentication discovery, retry policy, executor, or
  application eligibility rule enters these packages.

Workspace owns the configured organizations, deny set, bounds, stable ordering,
eligibility conjunction, annotation merge/review behavior, and deterministic file write.
It does not own GitHub request construction, JSON wire decoding, pagination, or transport.

#### Concrete HTTP execution entry gate

The required existing Foundation-free concrete executor does not currently exist.
`swift-foundations/swift-http` is a clean repository reservation at
`4db12c23334d1aa7ee2eea0980c87c8b6c7982e8` with no `Package.swift` or source. The accepted
native-networking record explicitly defers the HTTP client target and DNS connector, and
the current capability inventory says a native outbound client is still required. The
live `swift-urlrequest-handler` implementation at
`d72134b875a0fb153811a8ce635f8a5491ab02c3` executes through
`URLSession.shared.data(for:)` and imports Foundation/FoundationNetworking; it cannot
satisfy the Foundation-free gate. `swift-sockets` supplies byte transport, not HTTP,
DNS, TLS, certificate validation, or HTTPS connection composition.

This is not a newly discovered architecture choice. The accepted URLRouting migration
plan assigns URLRequest bridging to a Foundation Integration leaf and records its
URLSession execution as an explicitly deferred `[ARCH-LAYER-007]` exception only until
networking Wave 3 lands (`url-routing-stack-migration-plan.md`, lines 263–267). Its
ratified end state reserves the future HTTP router integration for Wave 4 (lines
297–304). The accompanying first-principles dossier says routing prints/maps an
`HTTP.Request` while execution belongs to `swift-http` (lines 148–166), records that
`swift-http` is presently an empty shell and the Institute HTTP transport is a Wave 3
gap (lines 258–267), splits URLRequest bridging from deferred execution (lines 365–374),
and permits URLSession only as the temporary exception (lines 393–403). Workspace's
accepted no-Foundation main-target gate is stricter and does not consume that exception.

Consequently the provider-owned content endpoint can proceed and be published, but
Workspace execution must stop before manifest or source mutation. Process/curl,
URLSession, AsyncHTTPClient, and an application-local socket/TLS client are rejected as
workarounds. The entry gate reopens only when the canonical outbound HTTP owner supplies
a Foundation-free `HTTP.Request -> HTTP.Response` execution composition for HTTPS with
DNS, TLS, system trust, bounded bodies, cancellation, and typed errors.

Networking Wave 3 task `019f8a65-6f68-7dd1-8d42-285908449687` owns that generic
composition. The GitHub/Workspace integration boundary is the already-public injected
executor shape `@Sendable (HTTP.Request) async throws(ExecutionFailure) -> HTTP.Response`.
The minimum handoff must resolve `api.github.com`, establish TCP and TLS with hostname
verification and system trust, preserve status and repeated response fields (including
`Link`), return a bounded `Byte`-owned body, observe cancellation, expose typed Sendable
failures, and define explicit connection/executor lifecycle and shutdown. Existing
lower-layer assets are RFC 3986 URIs, HTTP Standard/RFC 9110 representations, RFC 8288
Link parsing, `Byte`, and socket transport. Missing assets are the `swift-http` client
target/composition, DNS connection path, TLS client implementation, and system-trust
integration. GitHub remains responsible for provider headers, pagination, JSON, and
content semantics; Workspace remains responsible for configuration and policy.

## Phased implementation plan

### Phase 0 — review gate (completed for the local GitHub pilot)

1. Supervisor approval of the architecture candidate, GitHub pilot shape, and all nine
   heritage dispositions is recorded above; Principal direction supplies the final
   no-compatibility-window breaking-major ruling.
2. Use the completed `swift-mailgun-types` recensus at `2f69057`; B4 released the
   shared graph/build lane before the bounded GitHub package implementation began.
3. Treat Stripe v1/v2 and Mailgun domain/history questions as deferred provider gates,
   not GitHub blockers.
4. Authorize only a specific local GitHub package wave after the record review.
   External mutations remain separately gated.

### Phase 1 — GitHub clean-room graph prototype

1. Rehearse history-preserving path extraction in temporary clones; record source and
   destination commit graphs and verify no unrelated history pollution.
2. Create the final-mission products/targets inside the three existing local
   repositories without renaming remotes; do not add compatibility products.
3. Split GitHub standard vocabulary/endpoint representation from routers and clients;
   remove L3/Foundation dependencies from L2.
4. Establish transport-neutral `swift-github` core and reverse the edge so GitHub HTTP
   depends on core + standard.
5. Extract DI/environment/retry concerns from HTTP or leave them absent; no default L4
   service in the pilot.
6. Add owner-layer tests and historical consumer fixtures.

### Phase 2 — smallest complete Workspace vertical slice

1. Add the smallest pure declarative organization-repository request, response, and
   operation values to `GitHub Standard`, with no parser/router/case-path machinery.
2. Add one-page typed client, Link traversal, cancellation, bounds, typed errors, and
   an HTTP adapter.
3. After B4 releases the graph, select stable Institute HTTP/URI/body owner types and
   verify public-only/no-token and injected-token behavior without reading environment.
4. Return all public repositories, filter archived client-side, deduplicate only under
   an explicit rule, and sort deterministically for Workspace.
5. Integrate Workspace while preserving its existing safety invariants and deterministic
   inventory. No GitHub write operations enter the Workspace dependency surface.

### Phase 3 — coordinated consumer cutover

1. Enumerate and migrate every known direct consumer, including
   `swift-identities-github`, before the breaking product cut in the same arc.
2. After B4 coordination, update `Internal/institute-all` and its product inventory.
3. Run local and clean-room new-major fixtures plus historical URL/product fixtures at
   the preserved prior release/tag.
4. Cut the new major without `GitHub Types`, `GitHub Live`, the old configured-live
   semantic surface, a compatibility package, or a parallel branch.

### Phase 4 — publication checkpoint

The two approved in-place renames, RFC 8288 visibility change, and bottom-up normal
pushes are complete at the exact commits recorded above. Redirects, owners, visibility,
default branches, local origins, remote `main` commits, and anonymous canonical
resolution are verified. Tags/releases, archives/deletes, replacement repositories,
force pushes, and published-history rewrites remain outside this checkpoint.

### Phase 5 — pressure-test and promotion

1. Re-run the procedure on clean Stripe and Mailgun trees when their deferred evidence
   gates open; report all deviations.
2. Implement at least one non-GitHub domain/version slice or prove why the target map
   suffices without mutation.
3. Reassess this record as Tier 3 only after empirical gates pass.
4. If a reusable rule is promoted, update the owning canonical skill through
   `skill-lifecycle`; do not store it as a memory convention.

## Acceptance and release gates

### Architecture gates

- Every package has one written mission and every source declaration maps to it.
- Dependency graph is acyclic; standard depends only downward/essentially at L2;
  core does not depend on HTTP, DI, environment, HTML, server, Crypto adapter, or L4.
- Every cross-package integration is extracted unless a written [MOD-014] fallback
  proves why extraction is impossible.
- Main standard/core/HTTP targets are Foundation-free; any interop leaf is explicit
  and not re-exported as ambient convenience.
- All direct imports are declared; no transitive build-order accidents.

### API gates

- Nested semantic names, one type per file, typed throws, domain-specific errors.
- No `throws`, `throws(any Error)`, `NSError`, `URLError`, `try!`, force-unwrapped
  environment credentials, or production `testValue = liveValue` in new public paths.
- Provider IDs, versions, page tokens, signature values, credentials, and rate metadata
  have semantic types where they carry laws; open text remains text.
- No raw `[UInt8]` transport surface when an Institute byte/body type owns the concept.
- GitHub L2 operation values contain no parser, router, or case-path machinery; client
  witnesses and traversal remain L3.

### Test gates

- Standard: encode/decode, pure operation representation, unknown-value,
  malformed-wire, and Foundation-import tests; signature vectors only for a future
  provider slice that satisfies the downward-only crypto rule.
- Core: scripted one-page client, pagination termination, cancellation, page/item cap,
  duplicate policy, typed error propagation, and deterministic ordering.
- HTTP: exact method/path/query/header/body fixtures, auth/no-auth, status/error decode,
  pagination headers, rate metadata, and raw webhook-body preservation where applicable.
- DI/Test Support: direct construction works without DI; DI adapter registration is
  tested in its own package; fixtures contain no secrets.
- Live-service tests are opt-in, credential-gated, non-mutating by default, and never
  the only proof of behavior.

### Clean-room and heritage gates

- Clean clones build/test each final package independently and in the coordinated
  consumer graph after B4 releases the lane.
- Historical URL + package identity + product fixtures resolve at the preserved prior
  release/tag. New-major fixtures prove the approved breaking absence of historical
  products and configured-live semantics.
- `git log --follow`/commit-graph inspection demonstrates substantive path heritage at
  each successor; source commits are named in reconciliation commits.
- Repository redirects, default branch, tags, issues/PRs, and remote URLs are verified
  after—never assumed before—an authorized rename/transfer.
- No unreviewed history rewrite or force push; no archive/delete/replacement.

### Release gates

- All local direct consumers migrate in the same arc and pass their relevant tests.
- Public API/docs name the new mission rather than the historical suffix.
- A release note explains the breaking package/product surface, preserved historical
  release/tag, same-arc consumer migration, URL behavior, and policy relocation.
- GitHub pilot lands before Workspace depends on it; Stripe/Mailgun remain read-only
  until separately approved.

## Deferred provider-specific questions

These questions do not block the GitHub pilot:

1. For Stripe, are v1 and v2 separate packages or versioned targets in one package?
   The answer depends on package-level dependency and release-compatibility evidence
   gathered at the Stripe evidence gate.
2. For Mailgun, what is the commit-by-commit relationship between the two independent
   2024 roots, and which paths are authoritative in each? The successor dispositions
   are approved, but no cross-history import proceeds before this is answered.
3. Which Mailgun domains cross the package threshold: Messages, Reporting/Events,
   Receiving/Routes, and Account Administration are candidates, not approved packages.
   The `2f69057` recensus confirms the existing router split but does not by itself
   decide repository granularity.

## Outcome

**Status: RECOMMENDATION — architecture candidate approved; implementation entry
gates remain.**

Adopt a semantic architecture, not a suffix recipe. The default is:

1. Foundation-free L2 `swift-{provider}-standard` for provider-published wire and
   endpoint/inbound contract;
2. transport-neutral L3 `swift-{provider}` for typed capabilities and provider
   workflows;
3. extracted L3 `swift-{provider}-http` for concrete HTTP adaptation;
4. separate DI/server/environment/HTML/crypto integrations only when those concerns
   exist, with no configured L4 service in the GitHub pilot;
5. finer version/domain packages whenever the decision procedure finds a real no-fit.

GitHub fits the mission triplet for the narrow Workspace pilot. Stripe explicitly
does not fit an undifferentiated standard because v1/v2 mechanisms differ. Mailgun
explicitly does not fit provider-wide pagination, encoding, or inbound retry. All
nine histories receive successor dispositions; none is silently absorbed or discarded.

The GitHub major is deliberately breaking: known direct consumers migrate in the same
arc; historical releases and tags remain; no historical product or configured-live
compatibility surface is published in the new major. The package family, RFC 8288, and
provider-owned repository-content capability are now published. Workspace composition
remains blocked solely on the missing Foundation-free HTTPS executor and its clean
handoff from networking Wave 3; no Workspace source was changed at this gate. Stripe and
Mailgun package cuts remain deferred, non-blocking evidence questions.

## References

### Canonical skills

- [Swift Institute core](../Skills/swift-institute-core/SKILL.md)
- [Swift Institute architecture](../Skills/swift-institute/SKILL.md)
- [Swift package](../Skills/swift-package/SKILL.md)
- [Code surface](../Skills/code-surface/SKILL.md)
- [Implementation](../Skills/implementation/SKILL.md)
- [Modularization](../Skills/modularization/SKILL.md)
- [Research process](../Skills/research-process/SKILL.md)
- [Experiment process](../Skills/experiment-process/SKILL.md)
- [Swift package heritage](../Skills/swift-package-heritage/SKILL.md)
- [Testing](../Skills/testing/SKILL.md)
- [Skill lifecycle](../Skills/skill-lifecycle/SKILL.md)

### Internal prior art ([RES-019])

- [L2 vendor-purity pre-audit](../Audits/fable-farewell-2026-07-12/02-l2-purity-vendor-types.md)
- [GitHub types census](../Audits/fable-farewell-2026-07-12/lanes/L2a-github-types.md)
- [Mailgun types census](../Audits/fable-farewell-2026-07-12/lanes/L2b-mailgun-types.md)
- [Stripe types census](../Audits/fable-farewell-2026-07-12/lanes/L2c-stripe-types.md)
- [Owned-source heritage transfer plan](coenttb-ecosystem-heritage-transfer-plan.md)
- [Git history and repository transfer patterns](git-history-transfer-patterns.md)
- [URL-routing first-principles review](url-routing-stack-first-principles-review.md)
- [URL-routing migration plan](url-routing-stack-migration-plan.md)
- [Pure Institute networking target/package architecture](Pure-Institute-Networking/target-package-and-layer-architecture.md)
- [Pure Institute networking capability inventory](Pure-Institute-Networking/current-dependency-and-capability-inventory.md)
- [GitHub REST repository endpoints](https://docs.github.com/en/rest/repos/repos)
- [GitHub REST repository contents endpoint](https://docs.github.com/en/rest/repos/contents)

### Live source roots

- `/Users/coen/Developer/swift-standards/swift-github-types`
- `/Users/coen/Developer/swift-foundations/swift-github-live`
- `/Users/coen/Developer/swift-foundations/swift-github`
- `/Users/coen/Developer/swift-standards/swift-stripe-types`
- `/Users/coen/Developer/swift-foundations/swift-stripe-live`
- `/Users/coen/Developer/swift-foundations/swift-stripe`
- `/Users/coen/Developer/swift-standards/swift-mailgun-types`
- `/Users/coen/Developer/swift-foundations/swift-mailgun-live`
- `/Users/coen/Developer/swift-foundations/swift-mailgun`
