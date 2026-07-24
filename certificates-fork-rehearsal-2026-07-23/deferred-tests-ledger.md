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

## Rewired (B) — essence tests moved to frozen fixtures

_(execution in progress)_

## Corpus expansion (C) — new frozen DER vectors

_(execution in progress; each addition is additive to the original 28, re-frozen and documented)_
