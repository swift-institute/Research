# Certificates ↔ Crypto witness-seam design (N5)

Charter item: "Crypto boundary isolated behind the future swift-certificates-crypto
adapter seam; Certificates owns its witnesses" (record :163, :472 item 2, :474;
Certificates and TLS each own their OWN witnesses — never shared, record :268-:270).
Design only; implementation batches with the reshape.

## Needed capability surface (inventory §3, post-exclusion)

Verify-only: ECDSA P-256/P-384/P-521 verify, Ed25519 verify, SHA-256/384/512
digests, SHA-1 (legacy digest + SKI computation). Nothing RSA (CryptoExtras
gate closed). No signing.

## Witness shapes (Certificates-owned, [API-NAME-001] nests)

```swift
extension Certificate {
    /// Concrete verification capability injected into the verifier.
    /// Sendable value-of-functions witness (the HTTP.Client.Executor shape,
    /// record :634-:638), NOT a protocol: exactly one production impl
    /// (the swift-certificates-crypto adapter) + test fakes.
    public struct Verify: Sendable {
        public var signature: @Sendable (
            _ algorithm: SignatureAlgorithm,
            _ publicKey: PublicKey,          // SPKI-derived, backend-free model
            _ signature: Signature,          // parsed signature model
            _ signed: borrowing Span<Byte>   // TBS bytes (span, zero-copy)
        ) -> Bool

        public var digest: @Sendable (
            _ algorithm: Digest.Algorithm,
            _ message: borrowing Span<Byte>
        ) -> [Byte]                          // for SKI / CertID-style digests
    }
}
```

Notes:
- `PublicKey`/`Signature` backing enums lose their Crypto payload types at
  reshape: they carry ALGORITHM + RAW BYTES (`[Byte]`/spans) only. Today's
  `backing: BackingPublicKey` wraps `P256.Signing.PublicKey` etc. — that
  moves across the seam into the adapter; the model keeps
  `case p256(x963: [Byte])`-shaped payloads. This is what actually removes
  `import Crypto` from the main target.
- Bool return (not throws): signature verification failure is a domain
  outcome consumed by the policy/result path, mirroring upstream; malformed
  algorithm/key mismatches surface earlier as typed model errors
  (certificate-error-taxonomy.md).
- Span choice pends the [MEM-SPAN-*] probe at implementation; fallback
  spelling is `[Byte]` if `@Sendable` + `~Escapable` interact badly on the
  pinned toolchain — flag at batch time.

## Adapter package (future, lead-owned creation)

`swift-certificates-crypto`, L3 integration, product `Certificates Crypto`:
imports ONLY `Crypto` + Institute modules (record :472 item 2); exposes

```swift
extension Certificate.Verify {
    /// Production witness backed by sanctioned apple/swift-crypto 4.3.0.
    public static var crypto: Certificate.Verify
}
```

translating bytes/errors/ownership at the boundary; no Crypto type or error
escapes ([record :474] item 3). RSA arms appear HERE (and a `.serialNumber`
random init could return via an issuance package) only after their gates open.

## Injection path

`Verifier.init(...)` gains a `verify: Certificate.Verify` parameter (explicit
injection for tests; the future swift-certificates-system + HTTP.Client
compose production defaults). Slice-1 test targets may bind a test-only
witness built on apple/swift-crypto inside Tests/ (sanctioned backend;
main-target purity rules govern main targets only).
