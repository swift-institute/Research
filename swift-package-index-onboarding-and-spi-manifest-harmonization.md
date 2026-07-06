# Swift Package Index Onboarding: Collection Signing and .spi.yml Harmonization

<!--
---
version: 1.0.0
last_updated: 2026-07-03
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The Swift Institute ecosystem (~457 layered single-purpose packages across ~20 GitHub
orgs; ~371 public today, mostly untagged) is onboarding onto the Swift Package Index
(SPI) and publishing package collections. The first tagging wave targets ~2026-09-15.

Trigger: a research spike to resolve three onboarding questions before the tagging wave
so that the `.spi.yml` corpus and the collection-publication posture are correct
*before* tags exist (tags are the point at which SPI begins indexing and building docs,
so defects become externally visible then).

Established decisions (LOCKED before this spike, not re-derived here):
- SPI listing gate: public repo + ≥1 semver tag + valid manifest.
- SPI auto-generates ONE collection per GitHub **owner** at
  `swiftpackageindex.com/{owner}/collection.json` (single-owner-scoped). A unified
  whole-ecosystem collection spanning ~20 orgs must therefore be **self-hosted** (target
  host: swift-institute.org) via `swiftlang/swift-package-collection-generator`.
- Principal decisions: (i) do BOTH per-org auto-collections AND one self-hosted unified
  collection; (ii) SIGN the unified collection; (iii) complete index for discoverability
  PLUS a small curated "starter" collection; (iv) pilot = zero-external-dep primitive
  leaf cohort led by `swift-carrier-primitives`.

**This document treats cross-platform (Linux) trust as an explicit decision gate that
reopens decision (ii).**

Skills loaded (per [RES-033] dispatch-time skill-load gate): **research-process**
([RES-*]), **swift-institute-core** ([BET-*]), **ci-cd-workflows** ([CI-*]),
**github-repository** ([GH-REPO-*]; via prior-art extraction of
`github-metadata-harmonization.md`), plus consulted **readme**, **skill-lifecycle**,
**swift-institute**.

Rigor tier: **Tier 2** (cross-package, ecosystem-wide, RECOMMENDATION). The signing
sub-decision carries Tier-3-adjacent precedent weight (cert acquisition, CI-secret
custody, and consumer trust expectations are costly to reverse once consumers have added
the collection), so it is verified against primary SwiftPM source per
[RES-020]/[RES-032].

## Question

1. **Signing.** What certificate produces a collection SwiftPM trusts *without a
   warning*, and specifically does a standard Apple Developer code-signing certificate
   validate on **Linux** SPM using the default bundled trust store, or must end users
   install a root cert? Recommend signed vs unsigned.
2. **`.spi.yml` policy.** Harmonize the existing ad-hoc `.spi.yml` corpus into a
   canonical template with a per-package override model, appropriate for hundreds of
   tiny interdependent packages.
3. **Integration.** Where do the authoring + validation + propagation rules live (skill
   home), and how is the CI wiring shaped?

---

## Analysis — Part 1: Collection Signing

### 1.1 How SwiftPM decides trust for a package collection

Verified against primary SwiftPM source (`swiftlang/swift-package-manager@main`):

**Which policy applies.** `Sources/PackageCollections/PackageCollections+CertificatePolicy.swift`
selects the certificate policy by the collection URL's **host** (`certPolicyConfigKey =
self.url.host`). The `sourceCertPolicies` map contains exactly **one** hardcoded entry:
`developer.apple.com` → `.appleSwiftPackageCollection(subjectOrganizationalUnit:
"XLVRDL8TZV")`. `mustBeSigned` returns true *only* when the host maps to a policy — i.e.
only for `developer.apple.com`. [Verified: 2026-07-03]

**Consequence for a self-hosted collection.** A collection served from
`swift-institute.org` is **not** `developer.apple.com`, so: (a) it uses the `.default`
policy (`DefaultCertificatePolicy`), and (b) `mustBeSigned` is false — **signing is
optional**; an unsigned collection is permitted and simply prompts the user for
confirmation before it is added. [Verified: 2026-07-03; corroborated by
`swift.org/blog/package-collections` — "Signing the collection is optional and users can
use non-signed collections, but will be prompted for confirmation before doing so."]

**What `.default` requires.** `Sources/PackageCollectionsSigning/CertificatePolicy.swift`:
`DefaultCertificatePolicy` requires **no marker OID** (unlike the Apple policies, which
require `adpSwiftPackageCollectionMarker` / `adpSwiftPackageMarker` extension OIDs). It
accepts any cert chain that validates to a trusted root, applying `_CodeSigningPolicy`,
`RFC5280Policy`, `_OCSPVerifierPolicy`, and an optional `_SubjectNamePolicy`. The
verifier consumes embedded intermediates: `verifier.validate(leafCertificate:
certChain[0], intermediates: CertificateStore(certChain))`. [Verified: 2026-07-03]

### 1.2 The Linux trust gate (decision-critical)

Verified against SwiftPM's own documentation source
`Sources/PackageManagerDocs/Documentation.docc/PackageSecurity.md@main`, §"Trusted root
certificates" (lines 133–147). Verbatim, load-bearing:

> On Apple platforms, all root certificates that come preinstalled with the OS are
> automatically trusted. Users may include additional certificates to trust by placing
> them in the `~/.swiftpm/config/trust-root-certs` directory.
>
> On non-Apple platforms, there are no trusted root certificates by default other than
> those shipped with the certificate-pinning configuration. Only those found in
> `~/.swiftpm/config/trust-root-certs` are trusted. **This means that the signature
> check will always fail unless the `trust-root-certs` directory is set up.**
>
> … With the `package-collection-sign` tool, the root certificate provided as input for
> signing a collection is automatically trusted [for the publisher]. When a package
> manager user tries to add the collection, however, the root certificate must either be
> preinstalled with the OS (Apple platforms only) or found in the
> `~/.swiftpm/config/trust-root-certs` directory (all platforms) … otherwise the
> signature check fails.

[Verified: 2026-07-03, direct read of repo source via `gh api`]

The "certificate-pinning configuration" exception is precisely the hardcoded
`developer.apple.com` pin from §1.1 — it does not extend to third-party hosts.

**Reconciliation of the apparent contradiction.** SwiftPM *does* compile Apple root CAs
as bundled default trust roots (`CertificateStores.defaultTrustRoots =
Certificates.appleRoots`, from `AppleComputerRootCertificate.cer` / `AppleIncRootCertificate.cer`
/ `AppleRootCA-G2.cer` / `AppleRootCA-G3.cer`). Those bundled roots back the **pinned
`developer.apple.com` policy**, not the `.default` policy applied to a third-party
collection on a non-Apple platform. On Linux, a `swift-institute.org` collection has an
**empty default trust store**; only `~/.swiftpm/config/trust-root-certs` is consulted.
[Verified: 2026-07-03]

The real-world hands-on guide corroborates: signing with an Apple cert yields "trusted
when added via Xcode" on macOS with no user action, but a Linux consumer must
`wget https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer -O
~/.swiftpm/config/trust-root-certs/AppleWWDRCAG3.cer` first. [josephduffy.co.uk,
"Swift Package Collection Signing Using the Terminal"; Verified: 2026-07-03]

**Decision-gate finding.** There is **no certificate — Apple, public-CA, or self-signed
— that yields warning/failure-free, zero-setup trust on Linux** for a collection hosted
anywhere other than `developer.apple.com`. A public-CA cert only helps macOS (its root
is in the macOS OS store); a self-signed root is worse (macOS needs it too). On Linux,
every signed third-party collection requires the consumer to install the DER root into
`~/.swiftpm/config/trust-root-certs`, and if they have not, the signature check **hard-
fails** — which is *worse* than the unsigned path (a single confirmation prompt that
then proceeds). This is a fixed SwiftPM design property (PackageSecurity.md L138–140),
not a configuration we can influence from the publisher side.

### 1.3 Signing inputs, cert requirements, and the size caveat

- **Certificate (if signed).** The Apple "Swift Package Collection Certificate"
  (developer.apple.com → Certificates → add → "Swift Package Collection Certificate";
  2048-bit RSA; **one per paid developer account**) satisfies all SwiftPM requirements.
  Requirements (PackageSecurity.md L122–129): signing/verification timestamp within the
  cert validity period; "Code Signing" Extended Key Usage; **256-bit EC (recommended) or
  2048-bit RSA** key; valid chain to a trusted root. "Non-expired, non-revoked Swift
  Package Collection certificates from developer.apple.com satisfy all of the criteria."
  [Verified: 2026-07-03]
- **Signer invocation** (`package-collection-sign`, from
  `swiftlang/swift-package-collection-generator`):
  `package-collection-sign <input.json> <output.json> <private-key.pem> [<cert-chain.der>…]
  [--verbose]`. Private key is **PEM**; certificates are **DER**; **leaf first, root
  last**. If SwiftPM already knows the root+intermediates only the leaf is needed;
  otherwise provide the entire chain so all certs are embedded in the signature.
  [Verified: 2026-07-03 against PackageSecurity.md L87–94 + generator README]
- **Size caveat (#1365).** A signed collection embeds the full base64 payload, the
  public key, and the cert chain in the `signature` object → **>2× file size**. For a
  ~457-package complete index this is a material inflation of the file consumers
  download. [Established context #1365]

### 1.4 Recommendation — signed vs unsigned

| Criterion | Unsigned (Option A) | Signed w/ Apple SPC cert (Option B) |
|-----------|---------------------|-------------------------------------|
| macOS/Xcode add | One confirmation prompt | No prompt (clean) |
| **Linux add** | **One confirmation prompt, proceeds** | **Hard-fails unless consumer installs DER root first** |
| Windows add | Confirmation prompt | Same Linux-class trust store (non-Apple) → install root |
| Consumer setup | None | Linux/Windows: manual `trust-root-certs` step |
| Publisher burden | None | Apple paid acct cert; PEM key custody in CI; re-sign each regen; renew before expiry |
| File size | Baseline | >2× (#1365) |
| Tamper-evidence | HTTPS transport only | Cryptographic (only for consumers who installed the root) |
| Matches SPI-native UX | Yes (author collections served unsigned) | No |

The ecosystem is Linux-first (CI + servers). Signing optimizes the macOS/Xcode path but
*regresses* the majority Linux path from "prompt-and-proceed" to "hard-fail-without-
setup." HTTPS from swift-institute.org already provides transport authenticity +
integrity for the realistic threat model of a self-hosted index.

**Recommendation: ship the unified collection UNSIGNED for v1 (Option A), reversing the
locked decision (ii).** Rationale: identical zero-setup UX on macOS/Linux/Windows; no
cert/CI-secret/expiry burden; no >2× size penalty; matches the SPI-native author-
collection UX (unsigned, prompt-to-trust). File Option B as a documented future upgrade
if a threat model emerges (mirror redistribution, at-rest tamper concern) that justifies
imposing one-time consumer setup on Linux.

**This reopens and recommends reversing principal decision (ii); it requires explicit
principal ratification.** If the principal holds "signed" firm, §1.3 specifies the exact
cert, inputs, and custody; the publisher MUST additionally publish the DER root
(AppleRootCA-G3) plus a copy-paste `~/.swiftpm/config/trust-root-certs/` setup snippet on
the collection's landing page, and accept the Linux/Windows one-time-setup cost.

> Note (non-load-bearing, [RES-032]): SPI's own auto-generated per-owner collections
> appear to be served **unsigned** (the SPI author-collection consumer UX is the
> unsigned confirmation prompt); no source was found documenting SPI signing them. Not
> relied on for the recommendation.

---

## Analysis — Part 2: `.spi.yml` Harmonization

### 2.1 Current corpus (17 real files; verified inventory 2026-07-03)

The `.build-tsan/checkouts/**/swift-property-primitives/.spi.yml` hits are vendored
checkout copies, out of scope. The 17 authored files:

- **swift-primitives (1):** `swift-property-primitives`.
- **swift-foundations (6):** `swift-html-chart`, `swift-html-css-pointfree`,
  `swift-html-fontawesome`, `swift-html-prism`, `swift-password`,
  `swift-time-based-one-time-password`.
- **swift-standards (10):** `swift-color-standard`, `swift-css-standard`,
  `swift-domain-standard`, `swift-emailaddress-standard`, `swift-html-standard`,
  `swift-ipv4-standard`, `swift-ipv6-standard`, `swift-json-feed-standard`,
  `swift-locale-standard`, and the umbrella `swift-standards`.

**The schema is already uniform.** Every file is `version: 1` + `builder.configs[0].documentation_targets`.
No file carries a `platform`, `swift_version`, `image`, `scheme`, `target`,
`external_links`, `metadata`, or `custom_documentation_parameters` key. There is **no
platform/version matrix anywhere in the corpus.** The union of keys used is exactly four:
`version`, `builder`, `configs`, `documentation_targets`.

**The values are broken in 7 of 17.** SPI matches `documentation_targets` against the
**Package.swift target name** (space- and case-exact). Verified defects:

| Package | `.spi.yml` value | Actual target | Defect |
|---------|-----------------|---------------|--------|
| `swift-ipv4-standard` | `EmailAddress` | `IPv4 Standard` | copy-paste |
| `swift-ipv6-standard` | `EmailAddress` | `IPv6 Standard` | copy-paste |
| `swift-json-feed-standard` | `EmailAddress` | `JSON Feed Standard` | copy-paste |
| `swift-locale-standard` | `EmailAddress` | `Locale Standard` | copy-paste |
| `swift-css-standard` | `HTML Standard` | `CSS Standard` | copy-paste |
| `swift-domain-standard` | `Domain` | `Domain Standard` | truncated suffix |
| `swift-emailaddress-standard` | `EmailAddress` | `EmailAddress Standard` | truncated suffix |
| `swift-standards` | `MemoryAllocation` | *(no such target; no `.docc`)* | non-existent target |
| `swift-property-primitives` | `Property_Primitives` | `Property Primitives` | underscore-module vs target name; also inline+4-space style outlier |

Correct today: `swift-color-standard` (`Color Standard`), `swift-html-standard`
(`HTML Standard`), and the six foundations packages (single-token targets where
module == target: `HTMLChart`, `HTMLCSSPointFreeHTML`, `HTMLFontAwesome`, `HTMLPrism`,
`PasswordValidation`, and `TOTP`+`HOTP`). Note: `swift-color-standard` ships a second
library `Theme` that is not documented via SPI — confirm intentional.

**These defects are currently latent and uncaught.** `swift-institute/.github/.github/workflows/swift-docs.yml`
does **not** consume `.spi.yml` (verified: no `documentation_targets`/`.spi.yml`
reference). `.spi.yml` is consumed only by SPI's own builder, which does not run until a
package is public + tagged. Every broken target will surface as a failed/empty SPI doc
build on the package's first tagged release. [Verified: 2026-07-03]

### 2.2 Two SPI facts that constrain the design

- **#3197 (root-manifest / one-repo-per-package):** SPI indexes a package only from a
  root `Package.swift`; it will not index nested packages. The Institute's topology
  (one repo per package, root manifest, no nesting) is already SPI-native — validated
  independently in `Research/spm-nested-package-publication.md` (DECISION). The `.spi.yml`
  sits at repo root beside the root `Package.swift`; no structural change needed.
- **#3949 (Improving SPIManifest/docs/diagnostics/discoverability):** the current
  direction enriches `.spi.yml` and its diagnostics. A minimal-but-correct canonical
  template positions the ecosystem to adopt new keys centrally as they land, rather than
  hand-maintaining hundreds of divergent files.

Verified SPIManifest schema (`SwiftPackageIndex/SPIManifest@main`, `Manifest.swift`):
top-level `version` (default 1), `metadata` (→ `authors`), `builder` (→ `configs[]`),
`external_links` (→ `documentation`). Each `configs` entry: `platform`, `swift_version`,
`image`, `scheme`, `target`, `documentation_targets`, `custom_documentation_parameters`.
[Verified: 2026-07-03]

### 2.3 Canonical `.spi.yml` template

```yaml
version: 1
builder:
  configs:
    - documentation_targets:
        - <Exact Package.swift target name>
```

Canonical rules:

1. **`version: 1`** always.
2. **Exactly one `configs` entry, with NO `platform` and NO `swift_version`.** SPI's doc
   build then uses its own default toolchain/platform. This is deliberate: pinning a
   platform/Swift version per-package across hundreds of interdependent packages would
   create drift, would need bumping on every toolchain move, and is unnecessary — SPI's
   job here is **docs hosting**, not build-matrix enforcement. Platform/toolchain
   coverage is owned by the ecosystem's own CI matrix ([CI-010]: macOS/Linux/Windows +
   6.3 stable + nightly), which `.spi.yml` must **not** mirror. Mirroring the CI matrix
   into `.spi.yml` is an explicit anti-pattern for this ecosystem.
3. **`documentation_targets` lists the EXACT Package.swift target name(s)** — space- and
   case-exact — one per public library doc target (multi-target packages list all, e.g.
   `TOTP` + `HOTP`). This is the single per-package variable and the rule that catches
   all seven current defects.
4. **2-space block style** (the 16-file majority). Retire the `swift-property-primitives`
   inline-flow + 4-space outlier.
5. **Omit `external_links.documentation`.** The ecosystem decision is that SPI hosts
   rendered docs (carrier-launch decision #1.9: "published rendered docs come from Swift
   Package Index on each tagged release"), so no external doc link is needed.
6. **Omit `metadata.authors`.** Authorship lives in GitHub-side metadata + LICENSE; keep
   `.spi.yml` minimal.
7. **`custom_documentation_parameters`** is the sanctioned per-package override knob
   (appended to `package generate-documentation`) for the rare package needing e.g.
   `--include-extended-types`. Opt-in, never mandated.

**Per-package override model:** the skeleton (rules 1–2, 4–6) is invariant; the only
per-package value is the `documentation_targets` list (rule 3), with
`custom_documentation_parameters` as an optional escape hatch. This mirrors the
`.github/metadata.yaml` model precisely (fixed schema, package-specific values).

### 2.4 Harmonization actions (ADVISORY — not executed here per guardrails)

- Correct the seven broken `documentation_targets` to the exact target names in §2.1.
- `swift-standards` umbrella: `MemoryAllocation` is non-existent and there is no `.docc`.
  Decide per-package: either add a `.docc` catalog and point at the real umbrella
  library target, or **remove `.spi.yml`** if the umbrella is not meant to host SPI docs.
- `swift-property-primitives`: `Property Primitives` (space form) + reflow to 2-space
  block style.
- Confirm `swift-color-standard`'s `Theme` library omission is intentional.
- Add `.spi.yml` to each package **as it enters the tagging wave** (opt-in by presence,
  mirroring the metadata.yaml rollout's safety property).

---

## Analysis — Part 3: Integration Design

### 3.1 Precedent to mirror: `github-metadata-harmonization`

`Research/github-metadata-harmonization.md` (RECOMMENDATION) established the pattern
`.spi.yml` should follow: a per-package declarative YAML at a conventional path
(`.github/metadata.yaml`), **opt-in by file presence** ("a repo without the file is
logged skipped and not touched — opt-in by presence is the rollout's safety property"),
propagated/validated by **centralized reusable workflows in `swift-institute/.github`**,
authored via PR and seeded by a generator. Authoring rules live under **`[GH-REPO-*]`**;
the CI mechanics defer to **`[CI-*]`**. The Institute homepage for a published package
already points at SPI (`https://swiftpackageindex.com/{org}/{repo}/documentation`,
`[GH-REPO-030/031]`) — SPI-onboarding metadata is already in `github-repository`'s
discoverability-lens territory.

### 3.2 Skill-home recommendation: EXTEND, don't create

The metadata doc chose a *new* skill because it spanned ~12+ IDs across a self-contained
domain. `.spi.yml` is a far smaller surface — one file, one live knob
(`documentation_targets`), one validation workflow — and is a natural discoverability-
metadata sibling to GitHub repo metadata (homepage already → SPI). A new skill is not
warranted.

**Recommendation: EXTEND `github-repository` (authoring rules) + `ci-cd-workflows`
(validation wiring), mirroring the metadata precedent.** All new `[PREFIX-NNN]` rules
below are **PROPOSALS to be run through the `skill-lifecycle` workflow — NOT
self-approved or landed here.**

Proposed authoring rules in **github-repository** `[GH-REPO-*]` (IDs indicative; final
numbering assigned by skill-lifecycle):

- **`[GH-REPO-1xx]` `.spi.yml` presence & location** — repo-root `.spi.yml`, opt-in by
  presence, added at tagging-wave entry (mirrors `[GH-REPO-060]` metadata.yaml
  opt-in-by-presence).
- **`[GH-REPO-1xx]` Canonical `.spi.yml` shape** — §2.3 rules 1–2, 4–6.
- **`[GH-REPO-1xx]` `documentation_targets` target-name fidelity** — §2.3 rule 3;
  space-and-case-exact match to Package.swift target names; every public library doc
  target listed. (The rule that would have prevented all 7 defects.)
- **`[GH-REPO-1xx]` DocC-hosting-is-SPI** — omit `external_links.documentation`;
  `custom_documentation_parameters` is the sanctioned override.

Proposed validation/propagation rule in **ci-cd-workflows** `[CI-*]`:

- **`[CI-1xx]` `.spi.yml` validation** — a centralized reusable
  `validate-spi-manifest.yml` in `swift-institute/.github`, described in §3.3.

The unified self-hosted **collection-generation pipeline** is a centralized cross-org
scheduled workflow → its home is `[CI-*]` (with a pointer from `github-repository`),
described in §3.4. Its signed/unsigned posture is set by Part 1.

### 3.3 `.spi.yml` validation wiring

Mirror `validate-github-metadata.yml` (the established precedent): a `workflow_call`
reusable in `swift-institute/.github` that enumerates non-archived public repos, fetches
each `.spi.yml` from `main` (cheaper than a full clone), and validates. Two check tiers:

1. **Schema check (cheap, PR-gateable).** Validate `.spi.yml` against the SPIManifest
   schema (§2.2 keys) — same JSON-Schema shape as `validate-github-metadata.yml`
   validating `metadata.yaml` against `metadata-schema.json`. Per [CI-108] partition
   (runs against PR diff → per-repo thin caller): can run as an advisory job in the
   consumer `ci.yml` chain when a package carries a `.spi.yml`.
2. **Target-fidelity check (heavier, central sweep).** Verify each
   `documentation_targets` entry against the package's real target names via
   `swift package dump-package` (or `describe --type json`). This is the highest-value
   check — it is exactly what catches the seven §2.1 defects — but it requires resolving
   the manifest, so run it in a **weekly central sweep** (mirroring `sync-metadata-nightly.yml`:
   cross-org matrix, `swift-institute-bot` App token, tracking-issue-on-drift per
   `[README-167]`), not on every PR. [CI-092]: use `runs-on: ubuntu-latest` (or the
   `swift:6.3` container where `dump-package` needs the toolchain).

Auth + secrets: reuse the existing `swift-institute-bot` GitHub App + org-level secret
model ([CI-060]); no new credential class. No `.build/` cache ([CI-040]). Latest-version
action pins ([CI-107]). Follows mass-rollout discipline ([CI-050]/[CI-051]) when deployed.

### 3.4 Self-hosted unified collection generation

A centralized scheduled workflow in `swift-institute/.github` (running from the **public**
hub so Actions minutes are free per [CI-096]), shaped like the `sync-metadata-nightly`
orchestrator:

1. Enumerate all public + tagged repos across the ~20 orgs (reuse the org-enumeration the
   metadata sweep already uses; seed from `orgs.yaml`).
2. Run `package-collection-generate` over that input list → `collection.json` (the
   complete-index collection, decision iii) **and** a curated `starter.json` (the
   zero-external-dep primitive leaf cohort led by `swift-carrier-primitives`, decision iv).
3. **Signing step:** per Part 1 recommendation, **skip** (Option A/unsigned). If Option B
   is ratified, insert `package-collection-sign` consuming a PEM key from an org-level CI
   secret (e.g. `SPI_COLLECTION_SIGNING_KEY` at `swift-institute/.github`), embed the full
   chain, and publish the DER root on the landing page.
4. Deploy `collection.json` + `starter.json` to swift-institute.org (the site already has
   a DocC catalog + deploy workflow).
5. Cadence: regenerate on a schedule and/or on tag events; #3089 notes per-account SPI
   collections update asynchronously, so the self-hosted collection is the authoritative,
   promptly-updated whole-ecosystem surface.

Per-org auto-collections (decision i) require **no build** — they exist automatically at
`swiftpackageindex.com/{owner}/collection.json` once a package is indexed. The only
action is to surface their URLs on swift-institute.org alongside the unified collection.

---

## Outcome

**Status: RECOMMENDATION.** Analysis complete; three decisions staged for principal
ratification. Nothing implemented (no `.spi.yml` edits, no tags, no skill changes, no
commits — per spike guardrails).

1. **Signing — REOPENS locked decision (ii).** Verified against SwiftPM primary source:
   no certificate yields zero-setup, warning/failure-free trust on **Linux** for a
   self-hosted collection; every signed third-party collection **hard-fails** on Linux
   until the consumer installs the DER root into `~/.swiftpm/config/trust-root-certs`
   (PackageSecurity.md L138–140). Since the ecosystem is Linux-first and HTTPS already
   covers the realistic threat model, **recommend UNSIGNED for v1** (Option A). If the
   principal holds "signed": use the Apple "Swift Package Collection Certificate"
   (2048-bit RSA), custody the PEM key as an org CI secret, embed the full chain, publish
   the DER root + consumer setup snippet, and re-sign/renew before expiry. **Requires
   explicit principal ratification.**

2. **`.spi.yml` — canonical template (§2.3).** Schema is already uniform; the work is
   correctness: `documentation_targets` must be the exact Package.swift target name(s),
   no platform/swift_version pin, 2-space block style, SPI-hosts-docs (omit external
   link). **Seven of 17 files point at non-existent targets today** and are latent
   because `swift-docs.yml` doesn't consume `.spi.yml` — they surface on first tagged SPI
   doc build. Harmonization actions listed in §2.4 (advisory; not executed).

3. **Integration — EXTEND, don't create (§3.2).** Put ~4 authoring rules in
   **github-repository** `[GH-REPO-*]` and one validation rule in **ci-cd-workflows**
   `[CI-*]`; add a centralized `validate-spi-manifest.yml` (schema PR-gate + weekly
   target-fidelity sweep) mirroring `validate-github-metadata.yml`, and a centralized
   collection-generation workflow mirroring `sync-metadata-nightly`. All new
   `[PREFIX-NNN]` rules are **proposals to route through `skill-lifecycle`** — not
   self-approved.

**Blockers / reopened decisions:**
- Decision (ii) "sign the unified collection" is **reopened** and recommended reversed;
  awaits principal ratification.
- `swift-standards` umbrella `.spi.yml` needs a per-package decision (add `.docc` +
  real target, or remove `.spi.yml`).
- Final `[GH-REPO-*]` / `[CI-*]` rule numbering assigned by the `skill-lifecycle` run.

## Prior Art Survey (per [RES-021])

- **Internal (governs):** `Research/github-metadata-harmonization.md` (the per-package-
  YAML + centralized-reusable-propagation pattern mirrored here); `Research/spm-nested-package-publication.md`
  (DECISION — one-repo-per-package is SPI-native, validates #3197);
  `Research/carrier-launch-skill-incorporation-backlog.md` + `Research/Reflections/2026-04-29-carrier-launch-arc-and-centralized-workflow-trim.md`
  (why only the carrier/ownership/tagged/property cohort is tagged; DocC-hosting → SPI
  decision #1.9); `Research/ai-discoverability-llms-txt-placement.md` (curated-index-over-
  per-repo-proliferation placement doctrine).
- **External (verified primary):** SwiftPM `Sources/PackageCollections/PackageCollections+CertificatePolicy.swift`,
  `Sources/PackageCollectionsSigning/CertificatePolicy.swift`,
  `Sources/PackageManagerDocs/Documentation.docc/PackageSecurity.md`;
  `SwiftPackageIndex/SPIManifest` `Manifest.swift`; `swiftlang/swift-package-collection-generator`
  README; `swift.org/blog/package-collections`; SPI Discussions #3197, #3089, #1365,
  #3949.

## References

- SwiftPM PackageSecurity doc: https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/packagesecurity/ (source: `swiftlang/swift-package-manager/Sources/PackageManagerDocs/Documentation.docc/PackageSecurity.md`)
- SwiftPM cert policy: `swiftlang/swift-package-manager/Sources/PackageCollectionsSigning/CertificatePolicy.swift`, `Sources/PackageCollections/PackageCollections+CertificatePolicy.swift`
- Signer: `swiftlang/swift-package-collection-generator/Sources/PackageCollectionSigner`
- swift.org: https://www.swift.org/blog/package-collections/
- SPIManifest schema: `SwiftPackageIndex/SPIManifest/Sources/SPIManifest/Manifest.swift`
- Hands-on Linux trust: https://josephduffy.co.uk/posts/swift-package-collection-signing-using-the-terminal
- SPI Discussions: #3197 (root manifest), #3089 (async collection update), #1365 (signature size), #3949 (SPIManifest/discoverability direction)
