<!--
---
version: 0.1.0
last_updated: 2026-07-23
status: IN-PROGRESS
tier: 2
scope: N5 swift-certificates fork — test cases deferred at slice-1 (A+B+C ruling)
---
-->

# N5 swift-certificates — Deferred-Tests Ledger

Per the lead's A+B+C ruling (2026-07-23): slice-1 ships the verifier essence, so
test cases exercising **excluded surfaces** are DEFERRED (not lost). Git history
preserves the fully-converted swift-testing suite at `publication` HEAD; this
ledger makes each deferral auditable and reversible — every pruned case names the
excluded surface it needs and the future arc that reactivates it.

Disposition key:
- **A / prune** — tests an excluded surface directly; deferred to that surface's arc.
- **B / rewire** — verifier-essence test; issuance-generated cert → frozen DER fixture.
- **C / expand** — essence scenario lacking a fixture → new frozen DER vector added.

Reactivation arcs:
- `crypto-adapter` — future `swift-certificates-crypto` witness (RSA/_CryptoExtras verify).
- `darwin` — future `swift-certificates-darwin-standard` (SecKey / SecureEnclave bridge).
- `issuance` — future issuance package (Certificate.PrivateKey / CSR / builders as subject-under-test).

## Deferred (A / prune) — by file

<!-- Appended per file as the prune executes. Format:
| file | case (@Test name) | excluded surface | reactivation arc |
-->

### Certificate.Signature Tests.swift

Original: 104 @Test. Kept (essence, ECDSA P256/P384/P521 + Ed25519 via Crypto): 46.
Pruned: 58 — RSA 12, SecKey 36, SecureEnclave 10.

Also removed (helpers/fixtures used only by pruned cases): `Fixtures.rsaKey`
(`_RSA`), the entire `#if canImport(Darwin)` fixtures block (`secureEnclaveP256`,
`secKeyRSA/EC256/EC384/EC521/EnclaveEC256/EnclaveEC384`), and the `generateSecKey`
helper. Imports removed: `import _CryptoExtras`, `@preconcurrency import Security`
(+ its `#if canImport(Darwin)` wrapper).

| file | case (@Test name) | excluded surface | reactivation arc |
|---|---|---|---|
| Certificate.Signature Tests.swift | `rsa signature bytes match raw representation` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `map private key to supported signature algorithm rsa` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `hash function mismatch rsa ecdsa with sha256` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `hash function mismatch rsa ecdsa with sha384` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `hash function mismatch rsa ecdsa with sha512` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `hash function mismatch rsa ed25519` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `hash function mismatch rsa sha1 with rsa encryption` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `hash function mismatch rsa sha256 with rsa encryption` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `hash function mismatch rsa sha384 with rsa encryption` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `hash function mismatch rsa sha512 with rsa encryption` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `signature validation rsa` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `verify external signature rsa` | RSA | crypto-adapter |
| Certificate.Signature Tests.swift | `map private key to supported signature algorithm seckey rsa` | SecKey | darwin |
| Certificate.Signature Tests.swift | `map private key to supported signature algorithm seckey ec256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `map private key to supported signature algorithm seckey ec384` | SecKey | darwin |
| Certificate.Signature Tests.swift | `map private key to supported signature algorithm seckey ec521` | SecKey | darwin |
| Certificate.Signature Tests.swift | `map private key to supported signature algorithm seckey enclave ec256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `map private key to supported signature algorithm seckey enclave ec384` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey rsa sha1 with rsa encryption` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey rsa sha256 with rsa encryption` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey rsa sha384 with rsa encryption` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey rsa sha512 with rsa encryption` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey rsa ecdsa with sha256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec256 ecdsa with sha256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec256 ecdsa with sha384` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec256 ecdsa with sha512` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec384 ecdsa with sha256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec384 ecdsa with sha384` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec384 ecdsa with sha512` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec521 ecdsa with sha256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec521 ecdsa with sha384` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec521 ecdsa with sha512` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec521 sha512 with rsa encryption` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey ec521 ed25519` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey enclave ec256 ecdsa with sha256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey enclave ec256 ecdsa with sha384` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey enclave ec256 ecdsa with sha512` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey enclave ec384 ecdsa with sha256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey enclave ec384 ecdsa with sha384` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey enclave ec384 ecdsa with sha512` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey enclave ec384 sha512 with rsa encryption` | SecKey | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch seckey enclave ec384 ed25519` | SecKey | darwin |
| Certificate.Signature Tests.swift | `signature validation seckey rsa` | SecKey | darwin |
| Certificate.Signature Tests.swift | `signature validation seckey ec256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `signature validation seckey ec384` | SecKey | darwin |
| Certificate.Signature Tests.swift | `signature validation seckey ec521` | SecKey | darwin |
| Certificate.Signature Tests.swift | `signature validation seckey enclave ec256` | SecKey | darwin |
| Certificate.Signature Tests.swift | `signature validation seckey enclave ec384` | SecKey | darwin |
| Certificate.Signature Tests.swift | `map private key to supported signature algorithm secure enclave` | SecureEnclave | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch secure enclave p256 ecdsa with sha256` | SecureEnclave | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch secure enclave p256 ecdsa with sha384` | SecureEnclave | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch secure enclave p256 ecdsa with sha512` | SecureEnclave | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch secure enclave p256 sha1 with rsa encryption` | SecureEnclave | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch secure enclave p256 sha256 with rsa encryption` | SecureEnclave | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch secure enclave p256 sha384 with rsa encryption` | SecureEnclave | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch secure enclave p256 sha512 with rsa encryption` | SecureEnclave | darwin |
| Certificate.Signature Tests.swift | `hash function mismatch secure enclave p256 ed25519` | SecureEnclave | darwin |
| Certificate.Signature Tests.swift | `signature validation secure enclave` | SecureEnclave | darwin |

_(execution in progress)_

## Whole-file deferrals to INCREMENT 2 (excluded from the increment-1 test build)

Increment 1 (lead ruling) greens the issuance-free verifier-essence tests. The
files below are excluded from the `Certificates Tests` target in `Package.swift`
(kept in-tree, git-preserved) and reactivate in increment 2 — the TestPKI
fixture-shim + N5-gate-vs-edge corpus work. Each depends on the deleted issuance
surface (`Certificate.PrivateKey` / the `TestPKI` helper) and/or an excluded crypto
backend.

| file | @Test | dependency forcing deferral | increment-2 disposition |
|---|---|---|---|
| Verifier Tests.swift | 37 | direct issuance inits (`Certificate(…issuerPrivateKey:)`) build custom PKI | B rewire → frozen chains + gate-scenario expansion |
| RFC5280Policy Tests.swift | 126 | `TestPKI.issueLeaf/issueIntermediate/…` (deleted helper) | B rewire (gate) + C-defer edge permutations |
| ServerIdentityPolicy Tests.swift | 56 | issuance-generated leaves for SAN/hostname matching | B rewire → identity fixtures (leaf-*-san, wildcard, IDNA, cn-only) |
| Certificate.Signature Tests.swift | 46 (kept) | essence kept but `hashFunctionMismatchTest` builds `Certificate(…issuerPrivateKey:)` + live signing | B rewire → frozen (tbsBytes, signature, publicKey) tuples |
| Certificate Tests.swift | 27 | issuance-based construction/round-trip | B rewire + C where gate |
| Certificate.DER Tests.swift | 17 | issuance + RSA + Security (SecKey bridge) | mixed: B rewire essence / A-defer RSA+SecKey |
| CertificateStore Tests.swift | 6 | issuance-generated store contents + trust-root loading | B rewire; trust-root-loading cases → darwin/linux arc |
| PolicyBuilder Tests.swift | 24 | issuance-generated policy inputs | B rewire (gate) + C-defer edge |

## Rewired (B) — essence tests restored

### Increment 2, batch 1 — builder-DSL decoupling (no fixtures required)

Both files were deferred at increment 1 because they referenced the deleted
`DistinguishedNameBuilder` DSL (`CountryName`/`OrganizationName`/…), not because
they needed issuance-generated PKI. Decoupling them from the DSL restores pure
DN/RDN essence coverage without touching the frozen corpus.

| file | restored | method |
|---|---|---|
| DistinguishedName Tests.swift | 17 of 19 | DSL was confined to the final 2 cases; remaining 17 are DN/RDN essence (sorting, remove, representation, attribute values, round-trip, serialization). Also renamed 10 stale `ASN1UTF8String`/`ASN1PrintableString`/`ASN1IA5String` tokens the Sources-only string-type pass had missed. |
| NameConstraints Tests.swift | 2 of 2 | The DSL appeared only in the `names` fixture-static; rewritten with the array-form `DistinguishedName([RelativeDistinguishedName.Attribute…])` initializer, preserving the DSL's attribute encodings (countryName → PrintableString, others → UTF8String) so the equality semantics under test are unchanged. |

Deferred from these files (A / prune — tests of the excluded surface itself):

| file | case (@Test name) | excluded surface | reactivation arc |
|---|---|---|---|
| DistinguishedName Tests.swift | `distinguished name builder` | DistinguishedNameBuilder DSL | issuance |
| DistinguishedName Tests.swift | `distinguished name builder flow` | DistinguishedNameBuilder DSL (result-builder control flow) | issuance |

### Increment 2, batch 2 — PolicyBuilder restored; CertificateStore fully deferred

| file | disposition | detail |
|---|---|---|
| PolicyBuilder Tests.swift | 24 of 24 RESTORED | A single issuance-built self-signed cert served all 24 cases purely as a vehicle for exercising policy composition — the policies under test never inspect it. Rebound to the frozen `root-ca` fixture; the Crypto/Date/DN-DSL dependencies fell away with it. Separately, `RFC5280Policy()` now requires `validationTime:` (Q4 injected-time ruling removed the system-clock default), so the compile-time composition check supplies the corpus's frozen 2026-01-01 instant. |
| CertificateStore Tests.swift | 6 of 6 DEFERRED | See split below. |

CertificateStore splits into two deferral causes, neither rewireable in slice 1:

| case (@Test name) | cause | reactivation arc |
|---|---|---|
| `loading fails gracefully if files do not exist` | `CertificateStore.loadTrustRoots` — system-trust acquisition | linux (swift-certificates-linux) |
| `loading fails gracefully if first file does not exist` | `loadTrustRoots` + the deleted `ca-certificates.crt` PEM trust bundle | linux |
| `loading default trust roots` (os(Linux) variant) | `CertificateStore.systemTrustRoots` | linux |
| `loading default trust roots` (non-Linux variant) | `CertificateStore.systemTrustRoots` | darwin |
| `custom certificate store` | **C-EXPAND CANDIDATE — needs lead confirm.** Not rewireable onto the current corpus: the test deliberately encodes the CA's DN as PrintableString and the leaf's *issuer* DN as UTF8String, and exercises the store's DN normalization across that mismatch. Every frozen fixture uses consistent encodings, so rewiring would silently delete the assertion rather than preserve it. | comprehensive verifier coverage — OR a targeted 2-fixture add (a CA/leaf pair with deliberately mismatched DN string encodings) if the lead judges CustomCertificateStore normalization worth a corpus slot. Note it is **not** one of the enumerated N5 gate rows, which is why I did not add it unilaterally. |
| `custom certificate store deprecated` | as above (deprecated-API twin) | as above |

### Increment 2, batch 3 — ServerIdentityPolicy restored on 5 new frozen vectors

| file | restored | method |
|---|---|---|
| ServerIdentityPolicy Tests.swift | 56 of 56 | Its 5 in-test issued certificates replaced by 5 lead-confirmed additive fixtures (see §Corpus expansion). Every assertion preserved verbatim — no hostname, SAN or expectation was rewritten. |

## Corpus expansion (C) — new frozen DER vectors

**Increment 2, batch 3 (lead-confirmed 2026-07-24): 28 → 33, additive.** The original
28 are byte-identical and untouched — ECDSA signing uses randomized nonces, so a
wholesale regeneration would rewrite every fixture's bytes for no semantic gain.

| fixture | gate row(s) served |
|---|---|
| `leaf-weirdo-sans` | wildcard boundaries · IDNA policy · encoding/NUL rejection |
| `leaf-multi-san-hosts` | SAN DNS/IP |
| `leaf-multi-cn` | CN-fallback rejection |
| `leaf-no-cn` | CN-fallback rejection |
| `leaf-unicode-cn` | IDNA policy · CN-fallback |

**Two fidelity defects caught by gating on `package test` rather than the build** —
recorded because both are the silent-coverage-loss class:

1. **Critical basicConstraints.** The generator helper emitted `Critical(BasicConstraints…)`,
   copied from the leaf helper; the suite's originals leave it **non-critical**.
   `ServerIdentityPolicy` declares no `verifyingCriticalExtensions`, so the verifier
   rejected every leaf as carrying an *unhandled critical extension* before any policy
   ran — 30 failures whose reason was an **empty** policy-failure list. The 26 cases that
   appeared to pass were the failure-expecting ones, passing for the wrong reason: a
   build-only gate, or a pass-count glance, would have certified this as working.
2. **Dropped `rfc822Name` SAN.** Initially omitted from `leaf-multi-san-hosts`. No case
   asserts on it, so it was behaviourally inert — but it is retained anyway, both to avoid
   silent divergence from the original and because it keeps the policy's
   ignore-non-DNS/IP-SAN path exercised.

_(execution in progress; each addition is additive to the original 28, re-frozen and documented)_
