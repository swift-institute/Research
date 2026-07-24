# N6 — TLS 1.3 Engine over Apple Crypto Witnesses — Scoping Packet

**Stamp:** 2026-07-23 (from session context; no `Date.now` used — confirm/replace with lead-issued stamp)
**Status:** PREP-ONLY research. No package built, no source edited, no design committed.
**Author lane:** N6 scoping seat (research only). Reports to the team lead.
**Disposition:** Every design decision and the sequencing question are **HELD** for the Principal/Fable. This document is a plan and a decision-support brief, not code and not a decision.

**Scope guard:** In scope = swift-institute + sub-orgs (swift-foundations, swift-ietf, swift-iso) + repotraffic. `coenttb/*` is **out of scope** and was not considered (the old local `coenttb/swift-http`/`coenttb/swift-tls` checkouts are namespace shells, not heritage inputs — heritage record `:315`–`:317`).

---

## 0. Executive summary (what is already decided vs what is open)

N6 is the TLS 1.3 (RFC 8446) **client** engine — the next XL on the operative networking critical path (N1→N9; source: `Research/native-networking-wave-3-implementation-heritage-dependency-record.md:725-784`). It is **not started** and is **Fable-design-gated** (`Internal/handoffs/HANDOFF-team-lead-2026-07-23c.md:59-60,242`). Top goal: RepoTraffic on a Foundation-free, Institute-native networking stack proven by **release purity** (no Vapor/URLSession/PostgresNIO/NIO/BoringSSL in shipped products/manifest/lockfile).

**The architecture is already substantially specified** by the heritage record (v1.2.0). This packet builds on it; it does not re-decide it. The already-decided spine:

- **Two packages** (heritage record `:158`–`:159`, `:210`–`:214`):
  - `swift-transport-layer-security` (L3 / Foundations) — drives the TLS 1.3 connection state machine over an **injected byte duplex** using **injected** cryptographic, certificate, identity, and trust witnesses. No socket/HTTP/platform-trust import. **This package owns the witness protocols it needs and has no package edge to Apple Crypto, Certificates, sockets, or HTTP** (`:244`–`:247`).
  - `swift-transport-layer-security-crypto` (L3 integration) — binds the TLS-owned hash/HKDF/key-agreement/AEAD/signature witnesses to **official apple/swift-crypto**, translating all bytes/errors/ownership into Institute surfaces. Imports **only `Crypto` plus Institute modules**.
- **Apple Crypto is a sanctioned, unmodified, direct backend — NOT forked** ([HERITAGE-001] does not fire; `:326`–`:338`).
- **The engine composes over existing law** — it does not re-implement RFC 8446/6066/7301 wire models or the key schedule (`:431`).

**The five things this packet establishes (details below):**

1. **The Apple-Crypto witnesses N6 needs are all present in swift-crypto**, with exactly one primitive that swift-crypto stops short of — HKDF-Expand-Label — **and that gap is already filled by the RFC 8446 law package**, not by N6. (§2)
2. **The clean-room collision audit** (this also serves N5 as a standing publication STOP-condition) reduces to three SwiftPM identity collisions + one live heritage-state finding. (§3)
3. **The engine interface** is a sans-I/O state machine (rustls-shaped) over ~6 injected witnesses; the reuse surface from rfc-8446 is very large. (§4)
4. **Prior art** (rustls / swift-nio-ssl / BoringSSL) gives an architectural split to reference, with a hard clean-room boundary. (§5)
5. **Open questions for Principal/Fable**, led by the sequencing question. (§6)

---

## 1. What already exists (build-on-it inventory)

| Asset | Location | State |
|---|---|---|
| `swift-transport-layer-security` | `swift-foundations/swift-transport-layer-security` | **Empty scaffold.** No `Package.swift`, no `Sources/`. Only CI/metadata/license/lint. Last commit `cccd777` = "metadata: truthful reservation description (**scaffold, no implementation yet**)". Remote `swift-foundations/swift-transport-layer-security` exists. |
| RFC 8446 law | `swift-ietf/swift-rfc-8446` | **Rich, shippable, crypto-free.** Full handshake/record/extension wire models + the complete TLS 1.3 key-schedule ladder as pure functions + RFC 8448 vectors. Crypto edge is **test-only** (`Package.swift:16-19,43-46,66-72`; dep range `"3.0.0"..<"5.0.0"`, consumed only by "RFC 8446 Tests"). |
| RFC 6066 (SNI) | `swift-ietf/swift-rfc-6066` | `ServerNameList`/`ServerName`/`HostName` + `.Acknowledgement`; imports RFC 8446, lifts into `Extension.Data`. |
| RFC 7301 (ALPN) | `swift-ietf/swift-rfc-7301` | `Extension` + `ProtocolIdentifier.WellKnown` (`http1_1`, `h2`, `h3`, …); imports RFC 8446. |
| RFC 5280 (X.509 profile law) | `swift-ietf/swift-rfc-5280` | N5 lane; being authored (Institute-authored L2 profile law, no transplant). Consumed by the certificate verifier, **injected into N6 as a trust witness — no N6 package edge**. |
| ASN.1 law (X.680/X.690) | `swift-iso/swift-iso-8824`, `swift-iso/swift-iso-8825` | N5 lane; publication trees in flight. Not an N6 edge. |
| Certificate verifier | `swift-foundations/swift-certificates-n5` (fork, branch `publication`) | N5 lane; staged. **Injected into N6 as a certificate/trust witness — no N6 package edge.** |
| apple/swift-crypto | `swiftlang/swift-crypto` (mirror, tag 3.12.5) | The sanctioned direct backend for the `-crypto` integration target. |

**Layer placement (confirmed by heritage record DAG `:210`–`:214`, consistent with `Applications → Components → Foundations → Standards → Primitives`):** the engine and its `-crypto` integration are **L3 / Foundations**; RFC 8446/6066/7301 are **L2 / Standards** (swift-ietf). This resolves agent open-question "Foundations vs Components": **Foundations**.

**Supersession note (build-on-it, not re-decide):** the earlier `Research/Pure-Institute-Networking/target-package-and-layer-architecture.md` (2026-07-16) sketched separate `-certificates` and `-sockets` integration packages hanging off the TLS engine. The heritage record (2026-07-22/23) **supersedes** that: certificate/trust/identity are **injected witnesses with no package edge**, and the socket is abstracted as an **injected byte duplex** handled by the L4 composer (`swift-http-client`). Use the heritage record as the current authority.

---

## 2. Deliverable 1 — Apple-Crypto witness inventory (RFC 8446 need → swift-crypto)

Inventory taken against the physical mirror `swiftlang/swift-crypto` at tag **3.12.5**. `Crypto` = stable product; `_CryptoExtras` = underscored/less-stable product.

> **Version reconciliation (open — feeds G0):** three sources cite three swift-crypto versions — checkout **3.12.5**; heritage record **4.3.0** (`:449`, commit `fa308c07`); gap-atlas **4.5.0**. The rfc-8446 test-dep range is `3.0.0..<5.0.0`, which admits 3.12.5. The mirrors are shallow depth-1 and match **no** reviewed pin. This is not a blocker for the *API mapping* (the surfaces below are stable across 3.x), but the **exact pin must be nailed by the G0 "refresh exact upstream fork points + Apple-Crypto resolved graph" audit** before any manifest lands. Do not treat "4.3.0"/"4.5.0" as verified until reconciled.

### 2.1 Mapping table (RFC 8446 requirement → API → status)

| RFC 8446 requirement | Module · Type · API | Status | Note |
|---|---|---|---|
| **AEAD** AES-128/256-GCM | `Crypto` · `AES.GCM.seal/open` | **PRESENT** | Explicit nonce + AAD both exposed; `SealedBox.ciphertext`/`.tag` split (TLSCiphertext omits nonce); 128 vs 256 via `SymmetricKey` length; 16-byte tag. `AES.GCM.Nonce(data:)` accepts ≥12 bytes — TLS 12-byte nonce valid. |
| **AEAD** CHACHA20_POLY1305 | `Crypto` · `ChaChaPoly.seal/open` | **PRESENT** | Nonce must be **exactly** 12 bytes (matches TLS; other lengths throw). |
| **HKDF-Extract** | `Crypto` · `HKDF<H>.extract(inputKeyMaterial:salt:)` | **PRESENT (public)** | Not only the one-shot `deriveKey`. |
| **HKDF-Expand** | `Crypto` · `HKDF<H>.expand(pseudoRandomKey:info:outputByteCount:)` | **PRESENT (public)** | Arbitrary `info` — the exact hook TLS needs. |
| **HKDF-Expand-Label / Derive-Secret** (RFC 8446 §7.1) | — | **swift-crypto stops here — but see §2.2: filled by rfc-8446, NOT by N6** | swift-crypto has no `tls13`/`expandLabel` helper (grep clean). |
| **Key share** x25519 | `Crypto` · `Curve25519.KeyAgreement` | **PRESENT** | `rawRepresentation` = 32-byte wire key_share. |
| **Key share** secp256r1/384/521 | `Crypto` · `P256/P384/P521.KeyAgreement` | **PRESENT** | `x963Representation` = uncompressed point. |
| **Raw ECDHE secret** for the schedule | `Crypto` · `SharedSecret: ContiguousBytes` `.withUnsafeBytes` | **PRESENT** | Raw shared secret extractable (feed as IKM into the schedule). Bypass the `hkdfDerivedSymmetricKey` convenience — it is not the TLS schedule. |
| **Sig** ecdsa_secp256r1_sha256 / ecdsa_secp384r1_sha384 | `Crypto` · `P256/P384.Signing` | **PRESENT** | Digest-level `signature<D: Digest>`; `ECDSASignature.derRepresentation` (TLS wire = DER) **and** `.rawRepresentation`. |
| **Sig** ed25519 | `Crypto` · `Curve25519.Signing` | **PRESENT** | 64-byte raw sig = TLS wire. |
| **Sig** rsa_pss_rsae_sha256/384/512 | `_CryptoExtras` · `_RSA.Signing` padding `.PSS` | **PRESENT — heritage flag** | PSS = MGF1 with same hash + salt = digest length. |
| **Sig** rsa_pkcs1_* (CA-chain legacy) | `_CryptoExtras` · `_RSA.Signing` padding `.insecurePKCS1v1_5` | **PRESENT — heritage flag** | Named "insecure" but required to verify PKCS#1 v1.5 signatures in CA chains. |
| **Sig** rsa_pss_pss_* (RSASSA-PSS-OID leaf keys) | `_CryptoExtras` | **PARTIAL** | `_RSA` strips PSS key parameters (treats keys as rsaEncryption) → *rsae* served cleanly; *pss_pss* not surfaced as a distinct key type. Flag if in scope. |
| **Transcript hash** SHA-256/384 (/512) | `Crypto` · `SHA256/SHA384/SHA512` | **PRESENT** | Incremental `update`/`finalize`; `Insecure.*` not needed. |

### 2.2 The one apparent gap is not an N6 gap — reconciliation

swift-crypto deliberately stops at the RFC-5869 primitives (`HKDF.extract`/`HKDF.expand`). It has **no** TLS 1.3 label wrapping or key-schedule ladder. **But the RFC 8446 law package already supplies the entire ladder** as crypto-free pure functions gated behind one witness:

- `RFC_8446.KeySchedule.Derivation.{extract, expandLabel [prepends "tls13 "], deriveSecret, zeros}`
- `RFC_8446.KeySchedule.Stages.{earlySecret, handshakeSecret(previousDerived:sharedSecret:), masterSecret, client/serverHandshake/ApplicationTrafficSecret, finishedKey, finishedVerifyData, writeKey, writeIV, nextApplicationTrafficSecret, exporter/resumptionMasterSecret, resumptionPSK}`
- `RFC_8446.KeySchedule.{HkdfLabel, Label (all 16), Transcript}`

These are validated against RFC 8448 logged values in the existing test suite. **Consequence:** N6 owns **no** key-schedule code. Its `-crypto` target only adapts swift-crypto `SHA*` + `HKDF.extract/expand` **into** rfc-8446's `KeySchedule.Witness` (the test-only `RFC_8446_CryptoWitness.swift` is the sanctioned one-way adapter template). This materially shrinks N6's crypto-owned surface: the only genuinely engine-owned crypto seams are **AEAD, key-agreement, and signature-verification** (rfc-8446 has no witness for those — §4).

### 2.3 Gaps / flags (what Apple Crypto does NOT cleanly give)

- **G-1 (not a gap; ownership note):** HKDF-Expand-Label ladder — owned by **rfc-8446**, not swift-crypto, not N6. Wire swift-crypto into `KeySchedule.Witness`.
- **G-2 (heritage flag) RSA is two-axis costly:** RSA lives only in `_CryptoExtras` (underscored, self-described "avoid RSA … legacy interop"), which (a) pulls the `apple/swift-asn1` dependency into the graph and (b) **on Darwin uses Security.framework `SecKey`, not CryptoKit** — a *second* Apple backend beside the CryptoKit shim used by AEAD/ECDH/ECDSA/hash. Keeping the `-crypto` target "CryptoKit-thin" argues for deferring RSA. **HOLD** (see Q-B).
- **G-3 (interop-set flag):** P-521 / SHA-512 are present but rarely negotiated; the three mandatory suites (`TLS_AES_128_GCM_SHA256`, `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256`) + x25519/P-256/P-384 cover the target endpoints. Negotiated-set breadth is a **HOLD** (Q-C).
- **G-4 (provenance, not a code gap):** on Linux, swift-crypto's `Crypto` is vendored **BoringSSL** (`CCryptoBoringSSL`, derived from BoringSSL rev `aefa5d24`); on Darwin it is a CryptoKit passthrough. This is used as a **sanctioned black box** — canonical Institute purity governs Institute main targets, not this external source (heritage record `:455`–`:457`). It is a provenance *note* for the SBOM/release-purity story, not a re-derivation risk (§3-C).

---

## 3. Deliverable 2 — Clean-room collision audit (also serves N5 as a standing STOP-condition)

This audit is one of the three named N5 publication STOP-conditions that stand even post-authorization (`HANDOFF-team-lead-2026-07-23c.md:66-67`: "HERITAGE-007 keystones, fork-point refresh, **Apple-Crypto clean-room collision audit**"). It is consumable as a checklist by the N5 certificates-fork publication and must be respected by N6's `-crypto` manifest landing (both add the `apple/swift-crypto` edge). Citations `record:` = heritage record; `adj:` = certificate/system-trust adjudication.

### 3.0 Provenance ledger (physical repo ancestry — raw git-state evidence, 2026-07-23)

Read-only `git log`/`remote` inspection of every reservation/fork/mirror the audit touches. This is the physical evidence the N5 publication gate must re-verify at fork-point-refresh time; ancestry shape is a G0 STOP dimension (`record:729`).

| Directory | Remote / branch | Root | HEAD | Shape |
|---|---|---|---|---|
| `swift-foundations/swift-crypto` | origin `swift-foundations/swift-crypto` · main | `0b437a9` | `1a4b60b` | **Empty Institute reservation** on the canonical name; Institute-only history, **no apple ancestry** (`record:110`). |
| `swift-foundations/swift-crypto-reservation-2026` | origin `…-reservation-2026` · main | `0b437a9` (same root) | `d96ccdd` | **Renamed/re-described empty reservation** — the rename target (`record:377`). |
| `swift-foundations/swift-certificates` | origin `swift-foundations/swift-certificates` · main | `e4cf4f0` | `c3ae2ec` | **Empty Institute reservation**, no apple ancestry (`record:110`). |
| `swift-foundations/swift-certificates-reservation-2026` | origin `…-reservation-2026` · main | `e4cf4f0` (same root) | `a3504eb` | **Renamed/re-described empty reservation** — rename target (`record:378`). |
| `swift-foundations/swift-certificates-n5` | **upstream = apple/swift-certificates** · branch `publication` | `42be250` (apple's) | **`24ccdee` = reviewed 1.18.0 fork point** | **FORK-WITH-APPLE-ANCESTRY**, correctly pinned. **No Institute publication commit atop; only remote is `upstream`=apple; top commits all apple-authored** → [HERITAGE-002] unmet (D7). |
| `swift-foundations/swift-certificates-n5-artifacts` | **not a git repo** | — | — | Plain dir of N5 prep artifacts (deletions manifest, error taxonomy, crypto-witness design, fixture-corpus draft + generator, q4 time proposal). |
| `swiftlang/swift-crypto` | origin apple/swift-crypto · detached | `d79c573` | `d79c573` | **Apple mirror (shallow depth-1)**, tag 3.12.5; **≠ reviewed 4.3.0 `fa308c07`** (R-1). |
| `swiftlang/swift-asn1` | origin apple/swift-asn1 · detached | `a54383a` | `a54383a` | **Apple mirror (shallow)**; **≠ reviewed 1.6.0 `9f542610`**. |
| `swiftlang/swift-certificates` | origin apple/swift-certificates · detached | `386001a` (1.10.x) | `386001a` | **Apple mirror (shallow)**; **≠ reviewed 1.18.0 `24ccdee`**. |

**Two takeaways for N5:** (i) the reservation renames (`…-reservation-2026`) already exist locally as empty, apple-ancestry-free repos — the rename mechanics are staged, not yet published; (ii) the mirrors are shallow and match **no** reviewed pin, so the G0 "refresh exact upstream fork points + Apple-Crypto resolved graph" step is mandatory before any fork-point citation is trusted.

### 3.A Identity collisions (SwiftPM identity = last URL path component)

- [ ] **A1 — `swift-crypto` (Institute reservation) × `apple/swift-crypto`.** Both would resolve if the canonical Institute reservation stays named `swift-crypto` while the `-crypto` adapters add a direct edge to official apple/swift-crypto. **Decided disposition:** rename the empty reservation → `swift-crypto-reservation-2026`; depend directly on official; create no Institute fork; **never publish two `swift-crypto` identities** (`record:310-311,377`). *Live state:* both `swift-foundations/swift-crypto` (HEAD `1a4b60b`) and `…-reservation-2026` (HEAD `d96ccdd`) exist as empty Institute reservations sharing root `0b437a9` — no apple ancestry.
- [ ] **A2 — Institute ASN.1 authority × `apple/swift-asn1` (transitive).** apple/swift-crypto **unconditionally declares** `apple/swift-asn1` (`record:250-253`; `Package.swift:200-209`, `from: 1.2.0`), though **only `_CryptoExtras` imports it** (Crypto target does not). Sanctioning the unmodified backend sanctions *resolving/fetching* swift-asn1; it does **not** create a direct Institute `SwiftASN1` import or make it API authority. **Decided disposition:** the Institute ASN.1 fork **must adopt an authority-bearing identity distinct from `swift-asn1`** (X.680/X.690 · 8824/8825) — identity avoidance alone cannot select the L2 name (`record:256-257,379`; `adj:23-28`). **N6 relevance:** if slice-1 N6 excludes RSA/`_CryptoExtras`, the swift-asn1 transitive fetch **may be prunable** — but pruning is **unproven** and must be recorded by the clean-room gate, not assumed (`record:386,498-499,830-832`).
- [ ] **A3 — `swift-certificates` (Institute reservation) × `apple/swift-certificates`.** Two identities cannot both publish; the N5 product is a *fork of* apple/swift-certificates. **Decided disposition:** rename reservation → `swift-certificates-reservation-2026`; publish the true fork with one Institute publication commit atop the pinned fork point (`record:310,378`).
- [ ] **A4 — Audit obligation.** G0 requires auditing the **complete Apple-Crypto resolved graph for every local *and remote* SwiftPM identity collision, including `swift-asn1`**; the clean room **fails on every duplicate identity** (`record:728-730,830-832`). Local absence proves nothing.

### 3.B Heritage dispositions ([HERITAGE-001] four-condition results)

- [ ] **B1 — apple/swift-crypto → DOES NOT FIRE.** Condition 1 (material lineage) FAILS — no adapted lineage. Use official directly; create no Institute crypto fork/implementation (`record:328-338`). **This is why N6's crypto side carries no heritage gate** (only the deferred `_CryptoExtras`/RSA sub-gate).
- [ ] **B2 — apple/swift-asn1 → FIRES.** All four conditions PASS → true fork mandatory (N5); [HERITAGE-002] one-publication-commit-atop-fork-point applies; package cut PROVISIONAL (`record:356-366,312,379`; §3.E).
- [ ] **B3 — apple/swift-certificates → FIRES.** All four PASS → true fork mandatory (N5); sole L3 essence = certificate verification; RFC 5280 wire/profile law lives in the independent L2 owner; system-root acquisition in dedicated integrations (`record:342-352`).
- [ ] **B4 — Institute reservations are NOT forks.** Never merge Apple history into them or label them forks (`record:110,310`).

### 3.C Provenance / re-derivation contact points (where N6/N5 touch Apple-Crypto / nio-ssl / BoringSSL-derived code)

**N6 — the boundary is clean by construction (risk is *leakage*, not *lineage*):**
- [ ] **C1 — TLS 1.3 state machine:** Institute-authored over rfc-8446/6066/7301 models. **No swift-nio-ssl / BoringSSL lineage.** No edge from NIO/curl/Process/Vapor (`record:259`). ([HERITAGE-001]-Cond-1-FAIL for swift-crypto confirms there is no fork lineage to inherit anyway.)
- [ ] **C2 — record protection / AEAD / KEX / signature:** bound to `Crypto` **only** through `swift-transport-layer-security-crypto` (imports only `Crypto` + Institute; translates all bytes/errors/ownership; exposes no Foundation/`Data`/`[UInt8]`/Crypto key/error/untyped-throw) (`record:159,213,268-270,472-480`).
- [ ] **C3 — the backend boundary is the load-bearing seam:** the engine "owns the witness protocols it needs and therefore has no package edge to Apple Crypto, Certificates, sockets, or HTTP" (`record:245-247`). N6 STOP conditions explicitly include **backend type/error leakage** (`record:764-766`).

**N5 — lineage obligation (recorded here because this checklist serves N5; not N6-owned):**
- [ ] **C4** X.509 chain/signature/policy = true fork of apple/swift-certificates `24ccdee` — preserve ancestry/license/NOTICE + one publication commit (`record:344,312,833-834`).
- [ ] **C5** ASN.1 DER model/codec = true fork of apple/swift-asn1 `9f542610` under a distinct authority identity; Foundation/PEM excluded (`record:358,379`).
- [ ] **C6** certificate→Crypto binding via `swift-certificates-crypto` (only `Crypto` + Institute; separate from the TLS-Crypto adapter) (`record:163,217,268-270`).
- [ ] **C7** `TrustRootLoading`/`systemTrustRoots` **not carried as-is** (upstream uses Foundation + Darwin/Glibc/Musl, Linux-only, can reduce failure to empty store) — replaced by typed `swift-certificates-darwin-standard`/`-linux`/`-system`; missing/empty roots fatal, fail-closed (`record:442-445,458-461,488-489`).
- [ ] **C8** RFC 5280 profile law stays in the L2 owner; verifier lineage stays in the fork; add WebPKI TLS keyUsage/EKU (`record:307,461-464`).
- [ ] **C9** `_CryptoExtras`/RSA absent from slice 1; separate STOP/GO on certificate-fixture algorithm evidence (`record:254-255,499-501,760-761,877-878`).

### 3.D G0 / N5 publication gate — STOP conditions (checklist for the fork publication)

- [ ] **D1 — G0 gate** (`record:725-730`): re-review the record; separately authorize any repo/rename/fork/publication; refresh upstream points; audit the complete resolved graph for every local/remote identity collision incl swift-asn1. STOP on unapproved op / unresolved identity-consumer-redirect / ancestry shape. GO only with **line-cited lead approval**.
- [ ] **D2 — N5 leaf gate** (`record:754-761`): STOP on wrong ancestry · direct current Apple product use · Foundation/platform-C in an Institute main target · missing typed errors · incomplete roots · any failing chain/hostname/policy fixture.
- [ ] **D3 — First-leaf ASN.1 gate** (`adj:81-93`): GO requires isolated SwiftPM naming/normalization probe · refreshed fork point + one-publication-commit ancestry · complete identity-collision audit · Foundation/PEM/platform-import removal · Byte/bounded-cursor APIs + typed Sendable errors · DER positive + malformed/truncation/non-canonical vectors · strict memory gates · anonymous canonical-URL clean-room resolution.
- [ ] **D4 — Clean-room / release-readiness** (`record:826-840`): fresh anonymous clones from canonical remotes build/test bottom-up; the clean room **records Apple-Crypto's exact resolved identities/revisions/fetched products — including SwiftASN1 unless pruning is actually proved — and fails on every duplicate identity.**
- [ ] **D5 — Non-destructive fork/rename/transfer STOP rules** (`record:368-386`): "no operation in this table is authorized by this record"; any material consumer of an empty reservation stops the plan; reservation history stays public with verified redirect; never publish two `swift-crypto` identities.
- [ ] **D6 — Remaining gates before ANY package mutation** (`record:861-884`): content approval releases no mutation; separately authorize fork/rename/creation/publication after fork-point + resolved-graph + collision/consumer/redirect probes refresh; release `_CryptoExtras`/RSA only on fixture proof; coordinate the `swift-kernel` and one-Xcode lanes. **Master STOP: no mutation is safe until the lead releases G0** (`record:892`).
- [ ] **D7 — LIVE STOP EVIDENCE (this audit).** `swift-certificates-n5` branch `publication` HEAD = `24ccdee` is the **raw apple fork point with no Institute publication commit atop it and no Institute `origin` remote** (top commits all apple-authored). The [HERITAGE-002] one-publication-commit + acceptance artifacts (`record:381-383`) do **not yet exist** — so D2/D3/D5 are unmet **by construction** until the publication commit is created. Consistent with the handoff's "HOLD publication/HERITAGE-002 for lead check-in."

### 3.E Provisional / still-open (surface for principal)

- [ ] **E1** ASN.1 authority owner identity/cut is **PROVISIONAL** — "one cohesive authority-bearing standards-family fork with separate notation/encoding products is *preferred*; exact spellings await the isolated SwiftPM normalization probe + user confirmation" (`record:160,195,257,312`).
- [ ] **E2** The probe may refine spelling but **may not reopen** the approved one-family/two-product cut (`adj:23-25`).
- [ ] **E3** Two-repository (separate X.680 + X.690) decomposition **rejected** unless a later heritage review proves a mechanically truthful split (`record:379`; `adj:60-62`).
- [ ] **E4** Load-bearing identity constraint still to prove: a canonical Institute identity that cannot collide with transitive `apple/swift-asn1`; no duplicate identity, no direct SwiftASN1 import (`adj:26-28`).
- [ ] **E5** `swift-certificates-system` [PLAT-ARCH-008a] exception is PROVISIONAL; **N5/N8 blocked** until the user confirms four criteria verbatim (`record:280-298`).
- [ ] **E6** Apple-Crypto SwiftASN1 **pruning is UNPROVEN/open** — until the clean-room gate proves it, assume the graph includes/fetches swift-asn1 (A2).
- [ ] **E7** Out-of-scope cross-reference to flag: `record:23` notes GATE A/GATE B of `certificates-n5-decision-packet.md` v1.0.0 are ADJUDICATED with a **pre-execution checklist** — not read in this lane; it may add/supersede STOP conditions here. **Principal should confirm whether that checklist is the controlling N5 gate.**

---

## 4. Deliverable 3 — Engine interface scoping (sketch, NOT implementation)

**All shapes below are illustrative sketches to frame the design questions. No API is committed — see §6 (HELD for Fable).**

### 4.1 Shape: a sans-I/O state machine over an injected byte duplex

Consistent with N7's injected-duplex pattern (`swift-http` drives HTTP/1.1 "over an injected byte duplex", `record:167`) and the rustls sans-I/O model (§5): the engine **does no socket I/O**. The caller pumps ciphertext bytes in and drains bytes the engine wants to send; the engine advances TLS state and surfaces decrypted application bytes and lifecycle events. This keeps sockets, HTTP, and platform trust entirely out of the engine (`record:158`).

Illustrative driver surface (sketch):

```
// NAMES ILLUSTRATIVE ONLY — Nest.Name pattern, typed throws, Foundation-free.
enum TLS { /* namespace */ }

// The engine is fed ciphertext and produces (a) records to send, (b) decrypted app bytes,
// (c) lifecycle transitions. It never touches a socket.
struct TLS.Client.Connection: ~Copyable {          // move-only; owns secret material
    init(configuration: TLS.Client.Configuration, witnesses: TLS.Witnesses)
    mutating func receivedCiphertext(_ bytes: Span<Byte>) throws(TLS.Error) -> TLS.Event
    mutating func sendApplication(_ plaintext: Span<Byte>) throws(TLS.Error)  // -> queues records
    mutating func pullOutgoing(into: inout OutputBuffer<Byte>)                // records to write
    consuming func closeNotify() throws(TLS.Error)
}
```

### 4.2 Reuse obligations (compose over; do NOT re-implement)

- **RFC 8446 wire models** — every `RFC_8446.Handshake.*`, `RFC_8446.Record` (framing + `Record.Limits`), all enums (`CipherSuite`, `Extension.NamedGroup`, `Extension.SignatureScheme`, `ProtocolVersion`, `Extension.ExtensionType` incl `.serverName=0`/`.alpn=16`, `Alert*`), and all extension payload models (`KeyShare`, `SupportedVersions`, `SupportedGroups`, `SignatureAlgorithms`, `PreSharedKey`, …).
- **RFC 8446 key schedule** — `KeySchedule.{Derivation, Stages, Transcript, HkdfLabel, Label}` (§2.2). N6 wires these; owns none of them.
- **RFC 6066** SNI (`ServerNameList`) and **RFC 7301** ALPN (`Extension` + `ProtocolIdentifier.WellKnown.http1_1`) — emit/parse via `Extension.Data`.
- **RFC 5280 / ASN.1 / certificate verifier (N5)** — consumed **only** through an injected certificate/trust witness; **no N6 package edge** (`record:245`).

### 4.3 Injected witnesses (the engine's public seam — it OWNS these protocols)

| # | Witness | Provides | Bound by | rfc-8446 status |
|---|---|---|---|---|
| W1 | **Byte duplex (transport)** | abstract read/write of ciphertext bytes | L4 composer (`swift-http-client`) over `swift-sockets` | n/a (engine-defined) |
| W2 | **Hash + HKDF** | `hashLength`, `hash`, `extract`, `expand` | `-crypto` → swift-crypto `SHA*`/`HKDF` | **already exists** as `RFC_8446.KeySchedule.Witness` |
| W3 | **AEAD** | seal/open with explicit nonce + AAD | `-crypto` → `AES.GCM`/`ChaChaPoly` | **must define** (no rfc-8446 witness) |
| W4 | **Key agreement (ECDHE)** | keypair gen + raw shared secret | `-crypto` → `Curve25519/P256/P384.KeyAgreement` | **must define** |
| W5 | **Signature verification** | verify CertificateVerify over transcript | `-crypto` → `P256/P384/Curve25519.Signing` (+ `_RSA` if in scope) | **must define** |
| W6 | **Certificate + trust** | DER parse, chain-build to system anchor, validity/constraints/EKU, hostname/IP identity, bind CertificateVerify | **N5** verifier + system-trust witness (injected) | n/a (injected, no edge) |
| (W7) | **Secure random** | ClientHello.random, ephemeral key gen | swift-crypto (via W4 or standalone) | n/a |

**Witness-shape / placement question (HELD, Q-A):** rfc-8446 established the seam as a **struct-of-closures, not Sendable, not a behavioral protocol** (`KeySchedule.Witness`). W3–W5 could (a) follow that idiom inside `swift-transport-layer-security`, or (b) be contributed back into rfc-8446 alongside `KeySchedule.Witness` (**modifying rfc-8446 is gated** — its core is deliberately crypto-free). The heritage record says the **engine** owns the witnesses it needs (`:244`), which argues for (a); the coherent principle is *each package owns the witnesses its own logic consumes* (rfc-8446 owns W2 because the ladder lives there; the engine owns W3–W5 because record-protection/handshake-auth live there). **Fable-reserved.**

### 4.4 Engine-owned responsibilities (the build surface — verified absent from rfc-8446)

Client handshake + record state machine (`record:425-431`), all Institute-authored over the law models:

- **Handshake drive (client):** ClientHello (SNI, ALPN `http/1.1`, supported_versions=1.3, supported_groups, signature_algorithms, key_share) → HelloRetryRequest handling → ServerHello (parse, select suite, derive handshake secrets) → EncryptedExtensions → [CertificateRequest] → Certificate → **CertificateVerify** (W5 verify over transcript + `"TLS 1.3, server CertificateVerify"` context, §4.4.3) → server **Finished** (verify MAC via `finishedVerifyData` + W2) → send client Finished → application traffic keys.
- **Record protection:** `TLSInnerPlaintext` build/strip (content-type append + padding), per-record nonce = static_iv ⊕ seq_num, W3 seal/open, sequence-number management, reuse `Record.Limits`. (rfc-8446 has neither the InnerPlaintext transform nor sequence handling.)
- **Transcript orchestration:** feed the running transcript into `KeySchedule.Transcript`/`Stages` via W2.
- **Trust gate (mandatory, fail-closed):** call W6 to verify chain + hostname **before** accepting any application byte (N6 STOP: "trust before application-data failure", `record:766`); SNI uses the same normalized DNS name; ALPN absent or exactly `http/1.1` (HTTP/2 not silently accepted, `record:439-440`).
- **Lifecycle:** alerts, close_notify, key_update policy; explicit rejection of renegotiation/downgrade/unexpected messages; cancellation-safe; deterministic terminal disposition of secret material (move-only, zeroizable).

### 4.5 Conventions (from CLAUDE.md / heritage record — FACTS, not choices)

Foundation-free main targets; typed throws (`throws(TLS.Error)`); `Nest.Name` (e.g. `TLS.Client.Connection`, mirroring RFC terminology as `RFC_8446.*` where lifting law); one type per file; `Byte`/`Span` at boundaries — **no `Data`/`DataProtocol`/`[UInt8]`/Crypto key/error type/untyped throw in any public surface** (`record:474-480`); move-only secret/resource values with one terminal disposition.

### 4.6 Scope boundary — CLIENT, TLS 1.3 only (this slice)

RepoTraffic's TLS need is **outbound**: HTTPS client + PostgreSQL client (inbound is plaintext HTTP/1.1 behind Heroku's router TLS — `Pure-Institute-Networking/README.md:9`, gap-atlas `:76`). The heritage runtime contract scopes the engine to the **client** handshake/record state machine (`record:425`). Server-side TLS and TLS 1.2 fallback are **not** in this slice (TLS 1.2 only if measured endpoints demand it — migration-waves Q6). Both are **HELD** (Q-D).

---

## 5. Deliverable 4 — Prior-art survey (read-only reference; CLEAN-ROOM boundary)

**Hard clean-room rule for this deliverable:** the items below are referenced for **architectural shape only**. N6 is Institute-authored over RFC 8446 models with swift-crypto as a black-box backend. **Do not read, port, adapt, or transcribe source** from any OpenSSL/BoringSSL-lineage implementation. Provenance tiers:

| Reference | What to take | Provenance disposition |
|---|---|---|
| **rustls** (Rust, from-scratch clean-room TLS) | The **sans-I/O architecture**: `read_tls()`/`write_tls()` do raw I/O only; `process_new_packets()` parses + advances the state machine; an outgoing buffer holds records to send; `ConnectionCommon` is the shared client/server core. This is exactly N6's injected-duplex/pump model (W1 + §4.1). | **Architecture-safe touchstone** for the *protocol/state-machine split*. BUT rustls's crypto backends (`ring`/`aws-lc-rs`) are BoringSSL-derived → the **crypto layer is NOT a clean reference**; take only the state-machine/record-layer *shape*, and do not copy code (rustls is Apache/MIT/ISC — attribution/licensing would apply to any copy; N6 copies none). |
| **swift-nio-ssl** (Swift, "TLS based on BoringSSL") | The **handler↔engine split** concept: a thin driver (`NIOSSLClientHandler`) pumps a connection object (`SSLConnection` wrapping BoringSSL's `SSL *`) that does crypto + record framing together. | **OpenSSL-lineage hazard.** `SSLConnection` delegates crypto+framing to BoringSSL — the opposite of N6 (which injects crypto witnesses and owns framing in Swift). Reference the *conceptual* driver/engine split only; **do not read the BoringSSL-bound source**. No NIO edge is permitted in the graph (`record:259`). |
| **BoringSSL / OpenSSL** (`SSL_do_handshake`, BIO record layer) | Conceptual landmark for where handshake vs record responsibilities sit. | **Provenance hazard — the thing N6 replaces.** swift-crypto vendors BoringSSL-derived C on Linux as a *sanctioned black box* (§2 G-4); N6 does not re-derive it. Reference the *concept* of the handshake/record split at most; read no source. |

**Design cue N6 should take (safe):** rustls's discipline that *the library never owns the socket* — the caller drives bytes and the engine is a pure state transducer — is the single most load-bearing architectural idea, and it aligns 1:1 with the heritage record's "injected byte duplex" and N7's pattern. Everything crypto-shaped should come from swift-crypto via witnesses, never from a TLS-stack's own crypto.

Sources (reference only): [rustls ConnectionCommon docs](https://docs.rs/rustls/latest/rustls/struct.ConnectionCommon.html), [rustls.dev](https://rustls.dev/docs/index.html), [swift-nio-ssl README](https://github.com/apple/swift-nio-ssl), [swift-nio-ssl SSLConnection.swift](https://github.com/apple/swift-nio-ssl/blob/main/Sources/NIOSSL/SSLConnection.swift).

---

## 6. Deliverable 5 — Open questions for Principal / Fable (all design + sequencing HELD)

### 6.1 The sequencing question (Principal Q — this packet's primary decision input)

**Q-SEQ (verbatim from `HANDOFF-team-lead-2026-07-23c.md:65-66`):** *Is N6 TLS-engine design cleared to start in parallel with N5 publication mechanics, or does it wait behind the N5 heritage gate?*

**Architectural facts bearing on the answer (offered as input; the decision is HELD):**

1. **The engine has no package edge to Certificates/ASN.1.** Certificate verification is an **injected witness (W6)** with an abstract protocol the engine owns (`record:245`). So the engine's **interface + state machine + record layer + crypto witnesses (W2–W5)** can be *designed and specified* against an abstract trust witness **without the N5 fork being published**.
2. **The crypto side carries no heritage gate.** apple/swift-crypto [HERITAGE-001] does not fire (§3-B1); it is used directly. The only crypto sub-gate (`_CryptoExtras`/RSA) is already deferred out of slice 1 — and N6 can be scoped ECDSA/Ed25519-first to avoid it entirely (Q-B).
3. **But N6 *manifest mutation* shares N5's G0 audit.** Landing `swift-transport-layer-security-crypto` adds the **same `apple/swift-crypto` edge** that N5's `swift-certificates-crypto` adds, and both must pass the identical "no duplicate `swift-crypto` identity" + resolved-graph clean-room audit (§3-A/D). So *manifest landing* is not independent of N5's G0; *paper design* is.
4. **N6 design is Fable-reserved regardless** (`:242`), and **all** mutation waits on G0 release with the leaf-first runtime order placing N5 before N6 as *runtime* milestones (`record:754-767,892`).

**Framing for the decision (HELD):** the cleanest reading is a **split answer** — N6 *interface/design* (witness protocol shapes, state-machine spec, record-layer spec, test-vector plan, this packet's §4) is architecturally decoupled from the N5 heritage gate and could proceed in parallel *if Fable opens the design*, while N6 *manifest/source mutation* stays behind G0 (shared clean-room audit) and behind N5 in the runtime sequence. The Principal/Fable should rule whether to (a) open N6 paper-design now in parallel, (b) hold all N6 work behind the N5 heritage gate, or (c) open a bounded interface-only spike. **Not decided here.**

### 6.2 Design decisions reserved for Fable (HELD — options framed, none chosen)

- **Q-A — Witness seam placement + shape.** W3–W5 in `swift-transport-layer-security` (heritage-consistent; each package owns the witnesses its logic consumes) vs contributed into rfc-8446 (gated modification of a crypto-free core). And: struct-of-closures (matching `KeySchedule.Witness`, non-Sendable) vs Swift `protocol` witnesses (Sendable, move-only secret handling). (§4.3)
- **Q-B — RSA in the N6 MVP?** Accepting RSA server certs pulls `_CryptoExtras` (underscored/less-stable) + `apple/swift-asn1` into the `-crypto` target and adds Darwin Security.framework as a **second** Apple backend beside CryptoKit (§2 G-2). ECDSA/Ed25519-only first cut keeps the target CryptoKit-thin and keeps swift-asn1 prunable (A2/E6). Which is the MVP?
- **Q-C — Negotiated set breadth.** The three mandatory suites + x25519/P-256/P-384 only, or also P-521/SHA-512 and `rsa_pss_pss_*` (the latter is only PARTIAL in `_RSA`, §2 G-3/table)?
- **Q-D — TLS version + role scope.** Confirm **TLS 1.3 client only** for this slice (TLS 1.2 only if measured endpoints prove demand — migration-waves Q6; server-side deferred since Heroku terminates inbound). (§4.6)
- **Q-E — Secret-material ownership model.** Move-only secrets with deterministic zeroization and one terminal disposition — confirm the ownership discipline and whether the `-crypto` boundary returns Institute-owned move-only secret values (`record:475`).
- **Q-F — Byte-duplex abstraction coordination with N7.** W1 must match the injected-duplex shape N7's `swift-http` uses, so the L4 composer can drive both over one transport. Confirm the shared duplex contract is co-designed with N7 (`record:167,210`).
- **Q-G — Test-vector strategy.** rfc-8446 currently exercises message round-trip + key-schedule KATs (RFC 8448 §3). N6 must **extend** to full record-protection, nonce/sequence, CertificateVerify, Finished, alert/close-notify, tamper/truncation vectors, and a local in-process fixture peer + read-only interop (N6 GO gates, `record:767,793-813`). Confirm the RFC 8448 vector suite is the KAT baseline and the fixture-oracle approach.

### 6.3 Items to reconcile before any manifest lands (feeds G0)

- **R-1 — swift-crypto version.** Reconcile 3.12.5 (checkout) vs 4.3.0 (record) vs 4.5.0 (gap-atlas); pin the exact commit in the G0 resolved-graph audit (§2).
- **R-2 — swift-asn1 pruning.** Prove (not assume) whether excluding `_CryptoExtras` prunes `apple/swift-asn1` from the N6 slice-1 graph; record the actual resolved graph (A2/E6/D4).
- **R-3 — N5 live heritage state.** N5's publication commit atop `24ccdee` does not yet exist (D7); N6 manifest landing that shares the resolved-graph audit should not precede N5's fork-point/identity resolution.

---

## 7. Sources

- `Research/native-networking-wave-3-implementation-heritage-dependency-record.md` (v1.2.0) — primary architecture/heritage authority. Key loci: package table `:158-166`; DAG `:210-234`; witness ownership `:244-248`; heritage `:300-386`; TLS runtime contract `:423-506`; leaf plan (N5/N6) `:754-767`; acceptance gates `:786-840`; remaining gates `:861-892`.
- `Research/native-networking-wave-3-certificate-system-trust-adjudication.md` — ASN.1 identity + [PLAT-ARCH-008a].
- `Internal/handoffs/HANDOFF-team-lead-2026-07-23c.md` — current critical-path state; N6 not-started/Fable-gated; the sequencing question `:65-66`; N5 in-flight state `:36-37,148-200`; Fable-reserved list `:242`.
- `Research/Pure-Institute-Networking/{README,institute-capability-and-gap-atlas,migration-waves,replacement-matrix,target-package-and-layer-architecture}.md` — prior networking research (build-on; note 2026-07-16 target-package decomposition superseded by the heritage record).
- Package inspections (read-only): `swift-foundations/swift-transport-layer-security` (empty scaffold, `cccd777`); `swift-ietf/swift-rfc-8446`, `-6066`, `-7301` (law surface); `swiftlang/swift-crypto` @3.12.5 (backend surface); N5 physical repo ancestry.
- Prior art (reference only, clean-room): rustls, swift-nio-ssl, BoringSSL (§5).

**END — PREP-ONLY. No design decision or sequencing call is made in this document; all are HELD for Principal/Fable.**
