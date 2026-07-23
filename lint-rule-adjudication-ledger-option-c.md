# Lint Rule Adjudication Ledger — #16 Option C

<!--
---
version: 0.1.0
last_updated: 2026-07-23
status: DRAFT-FOR-PRINCIPAL
tier: 2
---
-->

## I. Purpose and procedure

This ledger assembles the #16 Option C per-class adjudication entries for the
principal, from (1) the completed 712-repo ecosystem lint sweep
(`Audits/lint-sweep-2026-07-23.md` / `.json`, Audits `9b2a49f`), (2) the
2026-07-23 handoff seeds, and (3) the 2026-07-23 session seeds landed in
swift-github-http `759330b` and swift-identities-github `0205e7f`.

**Entry format.** Each entry carries:

- **Class** — rule ID and firing shape.
- **Evidence** — exact `repo file:line` samples and/or commits; sample size stated.
- **Options** — the viable dispositions.
- **RECOMMENDATION** — the drafter's recommended disposition. This is analysis,
  not a ruling.
- **Decision** — *blank; reserved for the principal.*

**Recalibration-class sampling procedure (Section II).** The sweep JSON stores
per-repo `rule_counts` only (no per-finding lines), so per-finding samples were
drawn from the retained per-repo lint logs of the 2026-07-23 sweep/gate
sessions (same coordinator invocation and rule corpus as the sweep), plus
direct read-only source probes of the flagged sites. Sample sizes are stated
per class; characterizations are sample-based, not exhaustive.

**Noted, not adjudicated here:** the 258 NO-LINT repos
(`Audits/lint-sweep-2026-07-23.md:33`) are a coverage class, not a rule class;
per the 2026-07-23 handoff they resolve via #19 layer-derived lint bundles.
No entry below adjudicates them.

Scope guard: `coenttb/*`, `rule-institute/`, `rule-law/`, and `repotraffic`
were excluded from the sweep per the principal's 2026-07-23 scope ruling
(`Audits/lint-sweep-2026-07-23.md:15-17`) and are not analyzed here.

---

## II. Recalibration classes (handoff-seeded)

### Entry II.1 — PATTERN-017 (raw value access): brand-owner rawValue

**Class**: `[PATTERN-017]` — "`.rawValue` / `.position` at a consumer call
site bypasses the typed-conversion ladder. These accessors are reserved for
extension initializers (the brand-newtype's own boundary) and same-package
implementations." (rule message text, as emitted at every sampled site).

**Sweep footprint**: 3,153 findings / 158 repos (`Audits/lint-sweep-2026-07-23.md:69`).
Top repos (from sweep `results.jsonl` rule_counts): swift-whatwg-html 364,
swift-w3c-css 294, swift-iso-9945 276, swift-html-render 180, swift-rfc-791 106.

**Evidence — sample: 6 repos, 26 finding lines examined, 3 flagged sites
read in source.**

| # | Repo | Site | Shape |
|---|---|---|---|
| 1 | swift-iso/swift-iso-9945 | `Sources/ISO 9945 Core/ISO 9945.Kernel.Process.ID.swift:23` | Fires on `self.rawValue = rawValue` **inside the newtype's own `init(rawValue:)`** (source verified, lines 20-28) — a site the rule message itself reserves as allowed. |
| 2 | swift-standards/swift-github-standard | `Sources/GitHub Standard/GitHub.Owner.ID.swift:6-9` | Same shape; drained only by per-site disable + `REASON: brand owner boundary, [LINT-EXCLUDE-001]` (source verified). ghstd lint went 26 → 12 firings across the drain. |
| 3 | swift-standards/swift-mailgun-types | `Sources/Mailgun Messages Types/Messages.API.swift:174,179,206` | Consumer `.rawValue` in wire/API request construction — wire-boundary use. |
| 4 | swift-foundations/swift-url-routing | `Sources/URLRouting/HTTP.Method.swift:68-69,122`; `URIRequestData+RFC_3986.swift:24-25` | `.rawValue` in parser/printer wire boundary. |
| 5 | swift-foundations/swift-identities-github | `GitHubOAuthProvider+data.swift:9-10`, `+getUserInfo.swift:48,50,54` (sweep-time paths; files renamed `Identity.OAuth.GitHub+*` at `0205e7f`) | OAuth wire-boundary extraction; ruled class 3 and disabled per-site in `0205e7f`. |
| 6 | swift-foundations/swift-posix | `Sources/POSIX Kernel Descriptor/POSIX.Kernel.Descriptor.Interest.swift:50` | Same-package kernel-boundary use. |

**Characterization (sample-based)**: the firings cluster in two sanctioned
shapes — (i) the brand-newtype's **own declaration boundary** (samples 1-2),
which the rule's message text explicitly reserves as legitimate yet the
implementation still fires on, forcing per-site disables inside the declaring
init; and (ii) **wire boundaries** (samples 3-5: HTTP/OAuth/parser-printer
extraction), the shape commit `759330b` adjudicated as "ruling class 3,
[PATTERN-017] boundary use" (67 per-finding disables in gh-http alone).
No sampled firing was an unambiguous ladder-bypass violation; genuine
violations presumably exist in the 3,153 but did not surface in this sample.

**Options**:
1. Recalibrate the implementation to actually implement its stated reserve:
   do not fire inside the declaring type's / brand-owner extension's own
   initializers and same-module implementations.
2. Additionally define a wire-boundary carve-out (adapter/integration targets)
   instead of per-site disables.
3. Keep as-is; continue per-site disable + REASON drains.

**RECOMMENDATION**: Option 1 (mandatory — the rule currently contradicts its
own message text; samples 1-2 are implementation false positives), plus keep
wire-boundary firings as accept-as-warning/per-site-disable rather than a
blanket carve-out, since the wire boundary is exactly where a human REASON is
worth its cost. Expected effect: large reduction of the 3,153 without losing
the consumer-call-site signal.

**Decision (principal)**: ____________________

### Entry II.2 — PATTERN-004a (canimport conditional): platform trellis

**Class**: `[PATTERN-004a]` — "platform identity check uses
`#if canImport(...)` on a platform-prefixed module … platform identity is what
`#if os(...)` is for". Skill statement: "For platform identity checks,
`#if os()` MUST be used instead of `#if canImport()`. `canImport` is
appropriate only for optional module availability"
(`Skills/platform/compilation.md:77-79`).

**Sweep footprint**: 926 findings / 25 repos (`Audits/lint-sweep-2026-07-23.md:79`).
Distribution is extremely concentrated: swift-iso-9945 759 (82%), swift-kernel
39, swift-file-system 19, swift-darwin-standard 18, swift-source 12 — the top
firers are all platform/kernel-domain packages.

**Evidence — sample: 4 repos (2 from lint logs with file:line, 2 by direct
source probe of the firing shape), 11 finding lines examined, 3 sites read.**

| # | Repo | Site | Shape |
|---|---|---|---|
| 1 | swift-iso/swift-iso-9945 | `Sources/ISO 9945 Core/ISO 9945.ABI.CChar.swift:25` (3 firings on one line) | `#if canImport(Darwin) \|\| canImport(Glibc) \|\| canImport(Musl)` — the libc-import trellis (source verified). |
| 2 | swift-foundations/swift-posix | `Tests/POSIX Kernel Tests/POSIX.Kernel.Poll Tests.swift:18,20,41,80,152,186`; `Glob Tests.swift:19,21` | Same trellis in test files. |
| 3 | swift-foundations/swift-kernel | `Sources/Kernel Core/Kernel.Failure.swift:18`; `Kernel Thread/Kernel.Thread.Local.swift:78,110`; `Kernel Completion/Kernel.Completion.Driver.swift:10` (source probe) | Same three-way libc trellis. |
| 4 | swift-standards/swift-darwin-standard | `Sources/Darwin Kernel Standard/Darwin.Kernel.File.Seek.swift:12`; `Darwin.Identity.UUID.swift:4` (source probe) | `#if canImport(Darwin)` guarding a Darwin-only file in a single-platform standard. |

**Characterization (sample-based)**: every sampled firing is the sanctioned
**platform trellis** — `canImport` gating the import/availability of the raw
C-library module itself (`Darwin`/`Glibc`/`Musl`), not a platform-identity
branch on Institute platform-prefixed modules (the shape in the skill's
INCORRECT example, `compilation.md:91-95`). Note `#if os(Linux)` cannot
distinguish Glibc from Musl, so the libc trellis *cannot* be expressed with
`os()` without losing the Musl arm; here `canImport` genuinely is module
availability. No sampled firing matched the skill's forbidden shape.

**Options**:
1. Recalibrate: exempt `canImport` of the raw C-library modules
   (`Darwin`, `Glibc`, `Musl`, `WinSDK`, `Android`, …) when the condition
   gates the libc import trellis; keep firing on Institute platform-prefixed
   modules (`Darwin_Kernel_Standard` etc.), which is the shape
   [PATTERN-004a] actually forbids.
2. Amend [PATTERN-004a] skill text instead, requiring `os()` everywhere and
   mandating a shim for Glibc/Musl discrimination.
3. Keep as-is with per-site disables (759 in iso-9945 alone).

**RECOMMENDATION**: Option 1. The rule as implemented flags the ecosystem's
canonical libc trellis, which the skill's own determinism table
(`compilation.md:96-101`) does not condemn — the trellis *is* module
availability. Option 2 is a real architecture change and would need its own
proposal; Option 3 is 926 disables of a pattern the skill sanctions.

**Decision (principal)**: ____________________

### Entry II.3 — API-IMPL-003 (bool public parameter): wire bools

**Class**: `[API-IMPL-003]` — "public function/initializer signature has a
`Bool` parameter. Use an enum (or named-options struct) …
`package`-scope and non-public declarations are exempt; closure-typed
parameters with internal Bool arguments are exempt." (rule message text).

**Sweep footprint**: 1,189 findings / 98 repos (`Audits/lint-sweep-2026-07-23.md:75`).
Top repos: swift-stripe-types 450, swift-mailgun-types 90, swift-html-chart 68,
swift-rfc-4648 60, swift-iso-32000 51 — dominated by wire-schema `*-types`
packages (stripe + mailgun alone = 45% of all firings).

**Evidence — sample: 5 repos, 12 finding lines examined, 3 flagged sites read
in source.**

| # | Repo | Site | Shape |
|---|---|---|---|
| 1 | swift-standards/swift-mailgun-types | `Sources/Mailgun AccountManagement Types/AccountManagement.swift:121` | `Recipient: Decodable` wire struct; memberwise init takes `activated: Bool` mirroring the provider JSON field (source verified, lines 115-124). |
| 2 | swift-standards/swift-github-standard | `Sources/GitHub Collaborators Types/GitHub.Collaborators.swift:130,340,412` | Invitation wire struct; `expired: Bool?` mirrors the GitHub REST schema (source verified, lines 126-133). |
| 3 | swift-iso/swift-iso-9945 | `Sources/ISO 9945 Core/Kernel.File.Copy.Options.swift:40,41,42` | Fires on the memberwise init of the **named-options struct itself** (`overwrite:`/`copyAttributes:`/`followSymlinks:`, source verified, lines 36-44) — the exact remedy the rule prescribes. |
| 4 | swift-foundations/swift-url-routing | `Sources/URLRouting/URI.Request.Data.swift:147,164` | Public init/API Bool. |
| 5 | swift-primitives/swift-pool-primitives | `Sources/Pool Lifecycle Primitives/Pool.Lifecycle.Precedence.swift:32` | Public API Bool (candidate genuine finding; not source-adjudicated here). |

**Characterization (sample-based)**: the mass of the class sits in
**wire-schema types packages** (samples 1-2 and the stripe/mailgun repo
concentration), where the Bool field is dictated by the remote provider's
schema and an enum remedy would misrepresent the wire contract — the
handoff's "wire-bools" shape. A second false-positive shape is the rule
firing on the memberwise init of a named-options struct (sample 3), i.e., on
its own prescribed remedy. Behavioral API bools (samples 4-5) remain
plausibly genuine.

**Options**:
1. Recalibrate: exempt (a) memberwise inits of `Codable`/`Decodable`
   wire-schema types whose stored properties are the Bool source, and (b)
   inits of `*.Options` named-options structs assigning `self.<param> = <param>`.
2. Exempt entire `*-types` wire packages by manifest classification.
3. Keep as-is; per-site disables.

**RECOMMENDATION**: Option 1. It removes the two demonstrated false-positive
shapes structurally while keeping the rule live on behavioral API surface
(sample 5's shape) — Option 2 would also silence genuine API-design findings
inside types packages.

**Decision (principal)**: ____________________

---

## III. Session-seeded false positives and rule-scope questions

### Entry III.a — Compound-type-name false positive on nested Nest.Name declaration

**Class**: compound type name (fires under the [API-NAME-*] family corpus).

**Evidence**: `swift-github-http` commit `759330b` ("3 compound type name:
GitHub.HTTP.OAuth = rule-corpus false positive (disabled; seeded for the #16
Option C ledger)"). Live site:
`/Users/coen/Developer/swift-foundations/swift-github-http/Sources/GitHub HTTP/GitHub.HTTP.OAuth.swift:1-4`
— `extension GitHub.HTTP { public enum OAuth … }` is a textbook `Nest.Name`
declaration (workspace rule: "Types use the `Nest.Name` pattern"), flagged as
compound and suppressed with disable + REASON.

**Options**: (1) fix the rule's declaration-shape detection so a type
declared inside an `extension Outer.Inner` block is evaluated by its nested
path, not its flat spelling; (2) keep per-site disables.

**RECOMMENDATION**: Option 1 — this is a pure implementation false positive
against the workspace's mandated naming pattern; disables here train people
to suppress the rule.

**Decision (principal)**: ____________________

### Entry III.b — Brand token "GitHub" flagged as compound type name

**Class**: compound type name on brand tokens (internal capitals: "GitHub",
"OAuth", …).

**Evidence**: `swift-identities-github` commit `0205e7f` — "2 brand-name
'GitHub' compound-type false positives (seeded for #16 Option C: brand-token
allowlist)"; accepted as warnings at HEAD. The ecosystem's own canonical
naming uses the token throughout (e.g.
`swift-standards/swift-github-standard/Sources/GitHub Standard/GitHub.Owner.ID.swift:1`).

**Options**: (1) add a brand-token allowlist ("GitHub", "OAuth", "IPv4",
"PostgreSQL", …) consulted by the compound-name detector, with citations, in
the style of the existing `namingCompoundSwiftNativeIdiomCitations` mechanism
(see rule message quoted at III.d); (2) accept-as-warning per site forever.

**RECOMMENDATION**: Option 1 — a small, citable allowlist mirrors the rule's
existing stdlib-vocabulary mechanism and ends a permanent warning class.

**Decision (principal)**: ____________________

### Entry III.c — Untyped throws in `@Test` function bodies (rule-scope)

**Class**: typed-throws enforcement ([API-ERR-001] family) firing on `@Test`
declarations.

**Evidence**:
- 17 accepted in swift-github-http (`759330b`: "Accepted as warnings pending
  #16 rule-scope adjudication: 17 untyped throws (@Test bodies;
  published-precedent class)").
- 19 live at published swift-sockets HEAD `ca79bb8` (probe:
  `/usr/bin/grep` for untyped `throws` in
  `/Users/coen/Developer/swift-foundations/swift-sockets/Tests`, 19 sites;
  narrow single-line probe undercounts at 4 — broad probe positive-controlled
  against the seed count).
- 1 in swift-identities-github (`0205e7f`: "1 test untyped throws").
- The SWIFT-TEST corpus nowhere requires typed test throws:
  `[SWIFT-TEST-005]` governs naming only
  (`Skills/testing-swiftlang/SKILL.md:210-212`); no SWIFT-TEST rule states a
  throws-typing requirement. The workspace typed-throws rule is an API-surface
  rule ("Throwing functions use typed throws" — API quality section).

**Options**: (1) exempt `@Test` (and `@Suite`-member) declarations from
typed-throws enforcement — a test body rethrows arbitrary harness/SUT errors
to the runner and has no API surface; (2) require typed throws in tests and
migrate the published precedent (36+ sites across three published repos).

**RECOMMENDATION**: Option 1 — published precedent is uniform, the runner is
the only consumer, and no skill rule requires the contrary.

**Decision (principal)**: ____________________

### Entry III.d — Protocol-witness compound identifiers: witness allowlist mechanism

**Class**: `[API-NAME-002]` compound identifier, firing on names forced by a
protocol requirement.

**Evidence**: 7 accepted-as-warning sites in swift-identities-github
(`0205e7f`: "7 protocol-witness compound identifiers") — names forced by
`Identity.OAuth.Provider` requirements (witness file:
`Sources/IdentitiesGitHub/Identity.OAuth.GitHub+Identity.OAuth.Provider.swift`).
The rule's own message already contains the arm: "**Accept-as-warning**
disposition … a protocol this extension conforms to requires this exact name
but isn't yet in the witness allowlist. The warning IS the intended signal"
(rule text as emitted, e.g. in the swift-domain-name-system gate log,
`DNS.Resolver.System Tests.swift:122` firing).

**Open question (the actual adjudication)**: formalize the "witness
allowlist" the rule text alludes to — who may add an entry, what citation is
required (protocol + requirement), and whether allowlisted witnesses stop
firing entirely or fire at a lower severity.

**Options**: (1) implement the witness allowlist keyed on
`Protocol.requirement` with a mandatory citation, entries proposed in lint
drains and ratified by the principal; (2) leave as permanent
accept-as-warning canaries.

**RECOMMENDATION**: Option 1, with the allowlist stored in the rule source
next to `namingCompoundSwiftNativeIdiomCitations` so the mechanism and review
path match the existing stdlib-vocabulary precedent. Until then the 7 sites
stay warnings by the rule's own arm.

**Decision (principal)**: ____________________

### Entry III.e — Upstream-forced existential throws

**Class**: typed-throws / existential-error enforcement firing where an
upstream API's closure type dictates `any Swift.Error`.

**Evidence**: 5 accepted-as-warning sites in swift-identities-github
(`0205e7f`: "5 upstream-forced existential throws (registerProvider closure
type)") — call shape at
`Sources/IdentitiesGitHub/Identity.OAuth.Client.GitHub+register.swift:11`;
the closure type is owned by `Identity.OAuth.Client.registerProvider`
(`throws(any Swift.Error)`), upstream of this package.

**Options**: (1) accept-as-warning class (status quo) until the upstream
`Identity.OAuth.Client` API adopts a typed error, then drain; (2) exempt
call sites whose throws type is fixed by a non-local declaration; (3) file
the upstream typed-error change as the real fix.

**RECOMMENDATION**: Options 1+3 together: keep the warnings as the signal and
queue the upstream `registerProvider` typed-error change; option 2 would
permanently hide the pressure that motivates the upstream fix.

**Decision (principal)**: ____________________

### Entry III.f — IPv4 adapter rawValue disable at the RFC 791 / ISO network-order boundary

**Class**: `[PATTERN-017]` justified per-site disable; question is whether an
upstream API addition should replace it.

**Evidence**:
`/Users/coen/Developer/swift-foundations/swift-sockets-ip-address/Sources/Sockets IP Address/Kernel.Socket.Address.IPv4+IP.swift:13-17`
— disable + REASON: "this extension initializer IS the typed-conversion
boundary between the RFC 791 host-order arithmetic form and ISO 9945's
network-order storage; `IPv4.Address` exposes no network-order accessor, so
the brand's rawValue is consumed exactly here." (Sockets lane close, handoff
2026-07-23 §Late lane finals, as relayed by the lead.)

**Options**: (1) accept the disable as the permanent, correctly-REASONed
boundary form (it matches the rule's "extension initializers (the
brand-newtype's own boundary)" reserve — and becomes moot lint-wise if
Entry II.1 Option 1 lands); (2) add a typed network-order accessor upstream
on `IPv4.Address` (e.g. a `bigEndian`/network-order projection in
swift-rfc-791) and drop the rawValue consumption here.

**RECOMMENDATION**: Option 2 as the durable fix — a network-order accessor is
RFC 791 vocabulary and removes the raw consumption from the adapter — with
Option 1 acceptable in the interim. Flagged because the principal signaled
possible preference for the upstream accessor; this is exactly the choice to
rule on.

**Decision (principal)**: ____________________

### Entry III.g — Lint-drift ruling: accepted warnings vs the changed-files-lint-clean gate

**Class**: gate-vocabulary gap, not a rule defect.

**Evidence**: the gate says changed-files-lint-clean, but published repos
carry accepted warnings at HEAD: swift-sockets 54 (HEAD `ca79bb8`),
swift-github-http 22 (`759330b`: "117 -> 22 accepted"),
swift-identities-github 20 (`0205e7f`: "Accepted-as-warning residual (20)" —
itemized as 7 witness + 5 Foundation-imports (identities family arc) + 5
existential throws + 1 test untyped throws + 2 brand-token). Both commit
messages already itemize their residue by class; the gate has no vocabulary
to say so, so every re-lint re-litigates the same residue
(gh-http/ghstd rerun logs show identical residue across runs).

**Options**: (1) codify the accepted-warning classes as explicit gate
vocabulary: a per-repo (or corpus-level) accepted-classes declaration
(class ID + count ceiling + adjudication citation, e.g. `0205e7f`/#16 entry),
so "clean" means "no findings outside declared accepted classes"; (2) keep
narrating residue in commit messages only.

**RECOMMENDATION**: Option 1. It makes the drift auditable (a count above
ceiling or an undeclared class fails the gate) and each declaration cites its
adjudication — this ledger's entries III.b-III.e would be the first citations.
Note interaction: if II.1-II.3 recalibrations land, several accepted classes
shrink or vanish; the declarations should be re-derived after recalibration,
not frozen at today's counts.

**Decision (principal)**: ____________________

---

## IV. Appendix — histogram reference

Full per-rule histogram (69 rule classes, 712 repos, 447 FAST / 258 NO-LINT /
7 EVAL-FALLBACK, 0 lint errors):
`/Users/coen/Developer/swift-institute/Audits/lint-sweep-2026-07-23.md:61-133`,
machine-readable in `/Users/coen/Developer/swift-institute/Audits/lint-sweep-2026-07-23.json`
(`completed_results[].rule_counts`), committed at Audits `9b2a49f`.

Top-20 classes for orientation (total / repos): API-ERR-001 9650/238,
API-NAME-002 6918/218, API-IMPL-008 4312/177, API-IMPL-005 4300/177,
PATTERN-017 3153/158, TEST-005 2865/293, IMPL-010 2144/149,
API-NAME-001 1558/179, SWIFT-TEST-005 1448/44, PRIM-FOUND-001 1298/102,
API-IMPL-003 1189/98, CONV-016 1164/77, IMPL-033 1073/145,
API-NAME-004a 932/103, PATTERN-004a 926/25, SWIFT-TEST-002 823/136,
PLAT-ARCH-018 743/86, IMPL-075 567/94, API-NAME-004 462/83,
PLAT-ARCH-022 411/69.

Classes not entered in this ledger (including the four largest: API-ERR-001,
API-NAME-002, API-IMPL-008, API-IMPL-005) await their own evidence passes;
this draft covers the three handoff-seeded recalibration classes and the
seven session seeds only. Entry III.c bears on the API-ERR-001 total (test-
body firings are a subset of it); Entries III.a/III.b/III.d bear on the
API-NAME-002 total.
