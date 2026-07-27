# N5 Certificates — `Certificate.Verify` witness reshape (design, submitted to the team lead)

**Stamp:** 2026-07-24 · **Status:** DESIGN — nothing landed. Authored by the certificates lane on Opus 5 after the Fable gate was removed.
**Routing:** submitted to the team lead for adjudication; any escalation upward is the lead's to make.
**Purpose:** discharge the **D3 STOP** — *"Foundation/platform-C import in an Institute main target"* — which is the last lane-owned blocker on the N5 publication path.
**Supersedes nothing.** Refines `certificates-crypto-witness-design.md` (prior session) against the now-green tree.

---

## 1. Measured surface (not estimated — counted in the green tree at `7da9e4d`)

| Item | Count | Files |
|---|---|---|
| Main-target `import Foundation`/`FoundationEssentials` | **4** | `Signature`, `CertificatePublicKey`, `Digests`, `X509BaseTypes/ECDSASignature` |
| Main-target `import Crypto` | **5** | the four above + `Extension Types/SubjectKeyIdentifier` |
| Temporary `swift-crypto` bridge dep | **1** | `Package.swift` (added by me to reach green; marked *"remove at the witness reshape"*) |
| **Signature-verification call sites in the whole verifier** | **1** | `Verifier.swift:202` |

That last row is the finding that makes this tractable: chain verification funnels through a **single** call, so the witness has exactly one injection point.

## 2. What actually holds Crypto today

- `Certificate.PublicKey.BackingPublicKey` — 4 cases wrapping `Crypto.P256/P384/P521.Signing.PublicKey` and `Curve25519.Signing.PublicKey`. **This is the main Crypto anchor.**
- `Certificate.Signature.BackingSignature` — `.ecdsa(ECDSASignature)` + `.ed25519(Data)`. Note `ECDSASignature` is the **fork's own DER type**, not a Crypto type; the only impurities here are `Data` and the Crypto *conversions*.
- `Digest` (internal) — wraps `SHA256/384/512Digest` + `Insecure.SHA1Digest`.
- `SubjectKeyIdentifier.init(hash:)` — computes SHA-1 over SPKI bytes.

## 3. Design

### 3.1 Backing enums become algorithm + raw bytes

```swift
enum BackingPublicKey: Hashable, Sendable {
    case p256(x963: [Byte]); case p384(x963: [Byte]); case p521(x963: [Byte])
    case ed25519(raw: [Byte])
}
enum BackingSignature: Hashable, Sendable {
    case ecdsa(ECDSASignature)      // Institute DER type — stays
    case ed25519([Byte])            // was Foundation.Data
}
```
Algorithm identity and bytes are exactly what the SPKI/signature DER already carries, so decode/encode paths are unaffected. This is what removes `import Crypto` from the model.

### 3.2 The witness (Certificates-owned, per record `:163`)

```swift
extension Certificate {
    public struct Verify: Sendable {
        public var signature: @Sendable (SignatureAlgorithm, PublicKey, Signature, [Byte]) -> Bool
        public var digest: @Sendable (Digest.Algorithm, [Byte]) -> [Byte]
    }
}
```
Value-of-functions (the `HTTP.Client.Executor` shape), **not** a protocol: one production impl + test fakes. `Bool` return, not throws — verification failure is a domain outcome consumed by the policy/result path, matching upstream and the existing `VerificationResult` split.

**`[Byte]` over `Span` for slice 1 — DECIDED (lead-confirmed 2026-07-24), not deferred by omission.**
The prior design left this pending a `[MEM-SPAN-*]` probe. Ruling: use `[Byte]`.
Rationale of record: `@Sendable` combined with `~Escapable` is unproven on the pinned
toolchain, and this is the **STOP-clearing** change — the one place not to take unproven
risk. Adopting `Span` is a contained later optimisation, gated behind a `[MEM-SPAN-*]`
probe, and touches only the witness signature and its two call sites. Recorded here so a
later reader sees a decision with a reason, not an oversight.

### 3.3 Injection

`Verifier.init(rootCertificates:verify:policy:)` gains the witness; threaded to the single `Verifier.swift:202` call site. No other verifier surface changes.

### 3.4 What leaves the main target

| Surface | Disposition |
|---|---|
| `PublicKey.init(_ p256:)` ×4 (public, Crypto-typed) | → adapter (`swift-certificates-crypto`) |
| `Certificate.Verify.crypto` (production witness) | → adapter |
| `Digest` internals (Crypto digest types) | → behind the witness `digest` closure |
| `SubjectKeyIdentifier.init(hash:)` (SHA-1 of SPKI) | → adapter (Q1, confirmed) |

### 3.5 Siting of the moved Crypto API — PARKED, not designed (lead ruling, 2026-07-24)

The relocated Crypto-typed API lands **in the test target** for now. This is a
**deliberate parking place, not an architectural decision**, and is recorded as such so
a later reader does not mistake temporary siting for intent.

Reason it is parked there: it is what discharges the D3 STOP *without* requiring the
`swift-certificates-crypto` repository to exist, since repository creation is a
principal-gated act and the STOP should not wait on it. The compiled tests were verified
Crypto-free beforehand, so the move costs the regression net nothing.

Its real home is the `swift-certificates-crypto` adapter (C3: imports only Crypto +
Institute modules; D6: never merged with the TLS-Crypto adapter). When that package is
created, this code moves **unchanged** — it was written as the adapter's prototype, not
as test scaffolding.

### 3.6 Structural key-length validation at parse — KEEP (lead ruling, 2026-07-24)

`init(spki:)` retains a per-algorithm **length** check on the key bytes (e.g. P-256
x963 = 65 bytes) even though the backing no longer parses the key with Crypto.

Rationale: fail-closed at *parse* is stronger than deferring every malformed key to
verify time, it costs no Crypto dependency (a length is not cryptography), and it stops
malformed keys travelling deeper into the system where the eventual failure is harder to
attribute. Each constant is documented with the source that fixes it, so a later reader
does not "simplify" a spec-derived length into a magic number.

## 4. ★ Sequencing finding: this lands WITHOUT repository creation

The obvious reading is "witness reshape ⇒ create `swift-certificates-crypto` ⇒ blocked, repository creation is principal-gated." **It is not blocked**, because the adapter is only needed for the *production* witness:

- **Main target** becomes Crypto-free and Foundation-free — D3 discharged, bridge dep removed, transitively-fetched `swift-asn1` leaves the main graph.
- **Test target** binds a Crypto-backed witness *inside `Tests/`* — explicitly sanctioned ("main-target purity rules govern main targets only"), and the test target already depends on swift-crypto.
- **The adapter package** is then a pure lift-and-shift of already-written code, whenever repo creation happens.

So the STOP clears now; the adapter is follow-on packaging, not a prerequisite. This also keeps **C3** (adapter imports only Crypto + Institute modules) and **D6** (Certificates-Crypto and TLS-Crypto adapters stay separate — never combined) satisfied by construction, since nothing TLS-shaped enters this seam.

## 5. Decisions needed

- **Q1 — `SubjectKeyIdentifier.init(hash:)`.** Move to the adapter, or take a digest witness parameter? **Recommend: adapter.** It is a *construction* convenience (computing an SKI to put *into* a cert — issuance-adjacent); verification only ever *reads* SKI. Keeping it in the model would drag a hashing capability into a type that otherwise needs none.
- **Q2 — Public API relocation.** The 4 Crypto-typed `PublicKey` inits become adapter API. Pre-publication, so no consumer breakage — confirm acceptable as the intended slice-1 shape.
- **Q3 — `[Byte]` vs `Span`** in the witness signature (§3.2). Recommend `[Byte]` for slice 1.
- **Q4 — Landing shape.** Land §3.1–3.3 + the test-only witness now (clears D3), adapter later? **Recommend yes**, per §4.

## 6. Blast radius / risk

Contained but real: the backing-enum change touches every construction and comparison site in `CertificatePublicKey`, `Signature`, `ECDSASignature`, `Digests`, `SubjectKeyIdentifier`, plus the single verifier call site — and the **70 currently-green tests** are the regression net. Gate is `package test` with true exit status, per standing directive. Committed granularly to `n5-green-checkpoint` (repo still has **no Institute remote**).

**Not landing anything until Q1–Q4 are answered.**
