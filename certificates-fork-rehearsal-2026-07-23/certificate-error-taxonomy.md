# N5 typed-error taxonomy design — Certificate.Error nest

Status: stage-4 design deliverable (released). Implementation lands with the
ASN.1-retargeting batch, because most throwing sites are DER-parsing inits whose
error type is the ISO_8825 owner's (spelling held until the ISO trees are green).

## Survey (post-exclusion tree)

- 122 untyped `throws` sites remain (283 pre-exclusion; the rest were in
  excluded files). Two error currencies today: `CertificateError`
  (struct + ErrorCode: unsupportedSignatureAlgorithm,
  unsupportedPublicKeyAlgorithm, invalidSignatureForCertificate,
  incorrectOIDForExtension, unsupportedDigestAlgorithm, duplicateOID survive in
  live use) and upstream `ASN1Error` (all DER decode paths).
- Verification failures are RESULT-shaped upstream (`VerificationResult`,
  `PolicyEvaluationResult`, `PolicyFailureReason`) — not thrown. This split is
  correct and kept: policy rejection is a domain outcome, not an error.

## Design

### 1. Certificate.Error — model-domain enum ([API-ERR-002], [API-ERR-003])

Replaces the `CertificateError` struct+code shape with a nested enum describing
failure conditions (cases carry the evidence, not recovery advice):

```swift
extension Certificate {
    public enum Error: Swift.Error, Hashable, Sendable {
        case algorithm(Algorithm)          // Certificate.Error.Algorithm nest
        case signature(Signature)          // encoding/verification-shape failures
        case extension(Extension)          // OID/criticality/duplicate failures
    }
}

extension Certificate.Error {
    public enum Algorithm: Hashable, Sendable {
        case unsupportedSignature(AlgorithmIdentifier)
        case unsupportedPublicKey(AlgorithmIdentifier)
        case unsupportedDigest(AlgorithmIdentifier)
    }
    public enum Signature: Hashable, Sendable {
        case invalidForCertificate         // evidence payload TBD at impl
        case invalidEncoding(reason: …)    // e.g. Ed25519 padding bits
    }
    public enum Extension: Hashable, Sendable {
        case incorrectOID(expected: …, found: …)
        case duplicateOID(…)
    }
}
```

Upstream's `fileprivate` file/line diagnostic payload is dropped: Institute
errors are value-descriptive, and source location belongs to the debugger.
Dropped codes (excluded surfaces): unsupportedPrivateKey, invalidCSRAttribute,
failedToLoadSystemTrustStore.

### 2. Parse/decode paths — the ASN.1 owner's error, not ours

Every `init(derEncoded:)` / `serialize(into:)` conformance currently `throws`
untyped and actually propagates `ASN1Error`. After retargeting these become
`throws(<ISO_8825 error spelling>)` per the protocol requirements the ISO tree
publishes. Where a site can fail BOTH ways (decode + domain validation), the
domain error wraps: `Certificate.Error` gains a
`case der(<ISO_8825 error>)` bridge case ONLY if the ISO protocols pin the
thrown type to their own error (decision point at retargeting; prefer
propagating the ISO error type unwrapped when the function's only failure
domain is decoding, per [IMPL-112]'s no-pollution rule).

### 3. Verifier seams — typed without converting outcomes to errors

- `Verifier.validate(...)` keeps returning `VerificationResult` (no throw).
- `CustomCertificateStore` requirements: `async throws` →
  `async throws(Certificate.Store.Error)`; the store abstraction owns exactly
  one error domain:
  ```swift
  extension Certificate.Store {   // reshaped name of CertificateStore
      public enum Error: Swift.Error, Hashable, Sendable {
          case unavailable(reason: …)   // e.g. injected system-trust witness failure
      }
  }
  ```
  The future swift-certificates-system witness surfaces its Darwin/Linux
  acquisition failures through this case — fail-closed at the verifier
  (missing/empty roots = terminal, record :443–:445).
- `VerifierPolicy.chainMeetsPolicyRequirements` is non-throwing upstream
  (returns `PolicyEvaluationResult`) — unchanged.

### 4. Signing seams

Gone from slice 1 (issuance excluded). The verify half throws nothing — it
returns Bool today; reshape converts `isValidSignature` Bool returns into the
policy result path unchanged (no new error domain needed).

### 5. Typed-throws mechanics ([API-ERR-004], [IMPL-075], [IMPL-092])

- All closures crossing rethrows boundaries get explicit `throws(E)`
  annotations; `do throws(E)` for catch-site preservation.
- No `try?` ([IMPL-108]) — upstream has several in decode fallbacks
  (`try? ECDSASignature(...)` probe patterns); each converts to
  `do throws(…) { } catch { return false }` with the intent stated.
- `Self.Error` never appears in throws clauses ([API-ERR-002] reference-site
  rule); extension sites spell `Certificate.Error` fully.

## Site inventory by target error domain (implementation checklist)

| Domain | Sites (approx.) | Files |
|---|---|---|
| ISO_8825 decode propagation | ~95 | all DERImplicitlyTaggable conformances (base types, extensions, DN, GeneralName, Time, Signature init, PublicKey spki init) |
| Certificate.Error.Algorithm | ~8 | Signature.swift, CertificatePublicKey.swift, Digests.swift, SignatureAlgorithm.swift |
| Certificate.Error.Extension | ~12 | Extensions.swift, Extension Types/* |
| Certificate.Error.Signature | ~3 | Signature.swift, ECDSASignature.swift |
| Certificate.Store.Error | ~4 | CertificateStore.swift, CustomCertificateStore.swift |

Open item for the lead at retargeting go: whether ISO_8825's serializer
protocols pin `throws(ASN1.Error-equivalent)` in requirements (then our
conformances inherit it) or stay generic — determines whether the `der` bridge
case in §2 exists at all.
