# DRAFT — Certificates N5 Fixture Corpus Structure

Status: pre-inventory holding draft (satellite session, 2026-07-23). Not authorized
for Research/ or the publication tree until the lead releases the go. Anchors:
Wave-3 record v1.2.0 §"Format and deterministic fixtures" (RFC 5280 rows, :795–:798),
§"TLS 1.3, certificates, and system trust" (:423–:445), fail-closed items 1–9
(:470–:492), N5 STOP list (:757–:761).

## 1. Scope

Fixtures gate the L3 `Certificates` publication tree ONLY (chain construction,
signature verification via injected witnesses, policy, TLS server identity).
Explicitly out of scope here, per the partition: RFC 5280 profile-law fixtures
(L2 owner's suite), trust ACQUISITION (Darwin/Linux integration gates, N5 later
sub-lanes), PEM, RSA/CryptoExtras (separate STOP/GO), TLS transcript binding
(N6/RFC 8448).

## 2. Suite topology (testing / testing-swiftlang skills)

Test target `Certificates Tests`, nested-package snapshot pattern per
testing-institute if snapshot assertions are needed (error descriptions).
Suites mirror the verifier's domain nests ([API-NAME-001]):

| Suite | Covers | Record anchor |
|---|---|---|
| `Certificates.Chain Tests` | path building: root/intermediate/leaf, multiple candidate paths, missing intermediate, self-issued, cross-signed | :795 |
| `Certificates.Validity Tests` | expiry, not-yet-valid, boundary instants (at/minus/plus one second of notBefore/notAfter) | :795 |
| `Certificates.Signature Tests` | signature mismatch (tampered TBS, wrong key, wrong algorithm identifier), witness-injected verification | :796 |
| `Certificates.Constraints Tests` | basicConstraints cA, path-length at/over limit, unknown critical extension rejection, name constraints if in essence | :796–:797 |
| `Certificates.Policy.TLS Tests` | keyUsage digitalSignature, serverAuth EKU present/absent/other, CA without keyCertSign | :797 |
| `Certificates.Identity Tests` | SAN DNS exact match, SAN IP (v4/v6), CN fallback REJECTION, empty SAN | :797–:798 |
| `Certificates.Identity.Wildcard Tests` | `*.example.com` boundaries: single-label only, no partial-label, no `*.` matching bare domain, no wildcard in public-suffix position per policy, no `f*o` forms unless policy admits | :798 |
| `Certificates.Identity.Encoding Tests` | embedded NUL in SAN/CN, invalid UTF-8/IA5, case normalization, trailing dot, IDNA policy (A-label only; U-label rejection or normalization per adopted policy) | :797–:798 |

Every suite is deterministic and offline; no network, no system trust store
(system-trust gates live in the Darwin/Linux integration lanes).

## 3. Fixture material strategy

Two complementary tiers:

- **Tier A — static DER vectors** (`Tests/.../Fixtures/*.der` byte arrays or
  generated `.swift` byte tables): pre-generated certificate chains checked in
  as `[Byte]` literals/resources. Generated ONCE by a reviewed script (may use
  OpenSSL or upstream swift-certificates at generation time — generation
  tooling is not a package dependency and never ships). Each vector carries a
  provenance header: generator command, key algorithm, validity window
  (frozen absolute dates far in the future/past so tests never age out).
- **Tier B — programmatic assembly**: for encoding-edge cases (NUL injection,
  malformed lengths) that generators refuse to emit, hand-assembled DER via the
  ISO_8825 serializer with deliberate corruption applied at the byte level.

Verification time is INJECTED (typed clock/instant parameter), never read from
a system clock — validity fixtures pin the evaluation instant explicitly.
Signature verification uses the Certificates-owned witness protocol; tests bind
a test-only witness (backed by apple/swift-crypto in the TEST target only —
sanctioned backend; main targets stay Crypto-free pending the future
swift-certificates-crypto adapter). Algorithms limited to what the essence
needs (ECDSA P-256/P-384, Ed25519 if in the extracted essence); RSA vectors
deliberately ABSENT (their necessity is the CryptoExtras STOP/GO evidence).

## 4. Case matrix skeleton (per record's enumerated rows)

1. Chain: leaf→intermediate→root PASS; missing intermediate FAIL(typed
   `.chain(.incomplete…)`); untrusted root FAIL; leaf-only with root-as-anchor
   PASS; two viable paths (prefer valid one) PASS.
2. Validity: each of {leaf, intermediate, root} × {expired, not-yet-valid}
   FAIL; boundary instants exact.
3. Signature: tampered leaf TBS FAIL; intermediate signed by wrong key FAIL;
   algorithm/parameter mismatch FAIL.
4. Constraints: intermediate without cA FAIL; pathLen 0 with extra
   intermediate FAIL; unknown critical extension in leaf and in intermediate
   both FAIL; same extension non-critical PASS.
5. TLS policy: EKU absent→FAIL (fail-closed), EKU clientAuth-only FAIL,
   serverAuth PASS; keyUsage incompatible FAIL.
6. Identity: exact DNS PASS; case-insensitive PASS; IP SAN v4/v6 PASS against
   IP target; DNS name against IP-only SAN FAIL; CN-only match FAIL (CN
   fallback rejected, record :798); NUL-embedded SAN FAIL; wildcard rows per
   suite above.

Every FAIL row asserts the TYPED error case, not just `throws` — typed-throws
surface is itself under test ([API-ERR-001]; STOP condition "missing typed
errors").

## 5. Open items pending inventory

- Exact Nest.Name spellings of verifier types/errors (partition table decides
  what survives and under which nests).
- Whether upstream's own test fixtures fall inside the fork's imported paths
  (if so, Tier A may adapt them with heritage intact instead of regenerating).
- Witness protocol shapes (signature/hash) — record says Certificates owns its
  witnesses; exact protocol spelling comes from the reshape.
- ISO_8825 API surface for Tier B assembly (blocked on 8825 green).
