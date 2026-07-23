# Native Networking Wave 3 — Certificate and System-Trust Adjudication

**Status:** ACCEPTED ARCHITECTURE CONTENT; final ratification of the provisional
`swift-certificates-system` [PLAT-ARCH-008a] exception requires explicit principal
confirmation; heritage and external-operation gates remain controlling

**Date:** 2026-07-22

**Scope:** Certificate, ASN.1/DER, cryptographic binding, and system-trust owner
selection only; no runtime, manifest, repository, or dependency mutation

## Recommended choice

Adopt one Institute-owned, Foundation-free WebPKI path: truthfully adapt the
reviewed Apple SwiftASN1 lineage into one cohesive L2 ITU-T X.680/X.690 standards
family owner with separate notation and BER/CER/DER products; improve existing
`swift-rfc-5280` for X.509 profile law; truthfully adapt the reviewed Apple
Certificates lineage into the L3 `swift-certificates` chain/policy runtime; bind
its cryptographic witnesses through separate L3 `swift-certificates-crypto`; and
acquire production anchors through independent L3 Darwin and Linux integrations
selected behind one L3 `swift-certificates-system` witness.

The exact ASN.1 repository/product punctuation remains mechanically gated by the
already-required isolated SwiftPM normalization probe. That probe may refine the
spelling but may not reopen the approved one-family/two-product authority cut.
Its load-bearing result must be a canonical Institute package identity that cannot
collide with Apple Crypto's transitive `apple/swift-asn1`: no duplicate SwiftPM
identity and no direct Institute import of SwiftASN1 or Apple Certificates products.
True fork ancestry, per-upstream [HERITAGE-001], remote identity audits, and
non-destructive reservation migration remain preconditions to any external
operation.

## Exact owner graph

| Owner / integration | Layer | Exact responsibility |
|---|---:|---|
| one authority-bearing ITU-T X.680/X.690 family fork | L2 | ASN.1 notation plus bounded BER/CER/DER law; no PEM, files, crypto, certificate policy, Foundation, or platform C. |
| existing `swift-rfc-5280` | L2 | X.509 certificate/profile wire and validation law; no chain search, anchors, or concrete crypto. |
| truthful `swift-certificates` fork | L3 | Chain construction and injected policy, including fail-closed TLS server authentication: signature/time, constraints/path length, critical extensions, key usage, `serverAuth` EKU, SAN DNS/IP identity, and wildcard/encoding rejection. |
| `swift-certificates-crypto` | L3 integration | Bind certificate-owned hash/signature witnesses to official Apple Crypto without exposing backend types. |
| `swift-certificates-darwin-standard` | L3 integration | Acquire system anchors through typed L2 Security.framework surfaces in `swift-darwin-standard`; import no platform C. |
| `swift-certificates-linux` | L3 provider/integration | Discover bounded distribution trust stores through typed Kernel/File/Path APIs; own Linux trust-path policy without Glibc/Musl imports. |
| `swift-certificates-system` | L3 integration/unifier | Select the typed Darwin or Linux trust strategy and expose one system-trust witness to L4 while preserving explicit witness injection for tests. |

The `swift-certificates-system` domain conditional is the recommended provisional
[PLAT-ARCH-008a] exception because: Certificates is the authority for trust-
provider selection; it imports only typed Institute integrations, never platform
C; it selects domain strategy rather than a syscall; and moving the choice into
Kernel would contaminate Kernel with certificate semantics. `HTTP.Client` consumes
this common L3 witness for production defaults; Workspace does not choose a
platform provider.

## Rejected alternatives

- Direct Institute use of Apple SwiftASN1 or Apple Certificates products: rejected
  because their package/API/platform cut is not the Institute architecture and
  would bypass truthful adaptation and owner separation.
- Clean-room DER, chain-builder, or certificate-verifier security rewrite:
  rejected because it needlessly recreates subtle security lineage.
- Two independently published X.680 and X.690 repositories derived from one Apple
  upstream history: rejected unless a later heritage review proves a mechanically
  truthful split; identity avoidance is not decomposition evidence.
- Security.framework/system-TLS as the cross-platform TLS implementation, guessed
  anchors, incomplete hard-coded Linux root paths, or disabled verification:
  rejected as non-portable or fail-open.
- Combining TLS-to-Crypto and Certificates-to-Crypto, importing platform C in a
  semantic owner, or making L4/L5 choose Darwin versus Linux: rejected as mixed
  integration ownership and upward policy leakage.

## Apple Crypto exception boundary

Use official `apple/swift-crypto` 4.3.0 only as the sanctioned primitive backend.
Every Institute main target and public/domain API remains Foundation-free and
platform-C-free; each adapter imports only `Crypto` plus Institute modules and
exports no `Data`, `DataProtocol`, `[UInt8]`, backend key/error, or untyped-throws
surface. This is not a transitively Foundation-free or Embedded-compatible product
claim. Resolving Apple Crypto's pinned graph necessarily sanctions fetching
`apple/swift-asn1`, but does not authorize any Institute target to import or treat
SwiftASN1 as architecture authority. `CryptoExtras`/RSA remain separately gated.

## First leaf package gate

After program-lead approval, explicit fork/name-migration authority, and the fresh
implementation-task handoff, the certificate arc begins with the single cohesive
L2 ITU-T X.680/X.690 family fork. **GO** requires: the isolated SwiftPM naming and
module-normalization probe; refreshed upstream fork point and one-publication-
commit ancestry; complete identity-collision audit; Foundation/PEM/platform-import
removal; Institute `Byte`/bounded cursor APIs with typed Sendable errors; official
DER positive and malformed/truncation/non-canonical vectors; strict memory and
ownership gates; direct package tests; and anonymous canonical-URL clean-room
resolution. **STOP** on any unresolved name, ancestry, identity, bounds, import,
or vector failure. Only then may `swift-rfc-5280` and the L3 certificate runtime
advance leaf-first.
