// SCRATCH-ONLY generator: freezes the N5 chain/policy/identity fixture corpus
// to DER using upstream issuance APIs (apple/swift-certificates 1.18.0 at
// 24ccdeeeed4dfaae7955fcac9dbf5489ed4f1a25). Output: Fixtures/*.der + MANIFEST.md.
//
// Coverage per Wave-3 record :795-:798 — roots/intermediates, expiry/
// not-yet-valid, signature mismatch, constraints/path length, unknown critical
// extension, keyUsage/serverAuth EKU, SAN DNS/IP, encoding/NUL rejection,
// IDNA policy, wildcard boundaries, CN fallback rejection.
import Crypto
import Foundation
import SwiftASN1
import X509

// MARK: deterministic keys (fixed raw representations; frozen once, committed)

func key(_ seed: UInt8) -> P256.Signing.PrivateKey {
    var raw = [UInt8](repeating: 0, count: 32)
    raw[31] = seed
    raw[0] = 0x0B
    return try! P256.Signing.PrivateKey(rawRepresentation: raw)
}

let rootKey = key(0x01)
let intermediateKey = key(0x02)
let leafKey = key(0x03)
let strangerKey = key(0x04)  // never part of any chain: wrong-key signatures
let ed25519Root = try! Curve25519.Signing.PrivateKey(
    rawRepresentation: (0..<32).map { UInt8(truncatingIfNeeded: $0 &+ 0x40) }
)

// MARK: frozen instants (far past/future so fixtures never age out)

let t2020 = Date(timeIntervalSince1970: 1_577_836_800)  // 2020-01-01
let t2025 = Date(timeIntervalSince1970: 1_735_689_600)  // 2025-01-01
let t2026 = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01
let t2035 = Date(timeIntervalSince1970: 2_051_222_400)  // 2035-01-01
let t2045 = Date(timeIntervalSince1970: 2_366_841_600)  // 2045-01-01

func name(_ cn: String, ou: String = "N5 Fixtures") -> DistinguishedName {
    try! DistinguishedName {
        CountryName("NL")
        OrganizationName("Swift Institute Test PKI")
        OrganizationalUnitName(ou)
        CommonName(cn)
    }
}

let rootName = name("N5 Test Root CA")
let intermediateName = name("N5 Test Intermediate CA")

struct Emitted {
    var file: String
    var role: String
    var notes: String
}
var manifest: [Emitted] = []
let outDirectory = URL(fileURLWithPath: "Fixtures", isDirectory: true)
try! FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)

@MainActor func emit(_ certificate: Certificate, as file: String, role: String, notes: String) {
    var serializer = DER.Serializer()
    try! serializer.serialize(certificate)
    let bytes = Data(serializer.serializedBytes)
    try! bytes.write(to: outDirectory.appendingPathComponent(file))
    manifest.append(Emitted(file: file, role: role, notes: notes))
}

@MainActor func emitRaw(_ bytes: [UInt8], as file: String, role: String, notes: String) {
    try! Data(bytes).write(to: outDirectory.appendingPathComponent(file))
    manifest.append(Emitted(file: file, role: role, notes: notes))
}

// MARK: CA scaffolding

func makeCA(
    subject: DistinguishedName,
    key subjectKey: P256.Signing.PrivateKey,
    issuer: DistinguishedName,
    issuerKey: P256.Signing.PrivateKey,
    notBefore: Date = t2025,
    notAfter: Date = t2045,
    maxPathLength: Int? = nil,
    markCA: Bool = true,
    serial: Int = 1
) -> Certificate {
    try! Certificate(
        version: .v3,
        serialNumber: .init(serial),
        publicKey: .init(subjectKey.publicKey),
        notValidBefore: notBefore,
        notValidAfter: notAfter,
        issuer: issuer,
        subject: subject,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
            if markCA {
                Critical(BasicConstraints.isCertificateAuthority(maxPathLength: maxPathLength))
            } else {
                Critical(BasicConstraints.notCertificateAuthority)
            }
            Critical(KeyUsage(keyCertSign: true, cRLSign: true))
        },
        issuerPrivateKey: .init(issuerKey)
    )
}

struct LeafOptions {
    var sans: [GeneralName]? = [.dnsName("example.com")]
    var eku: [ExtendedKeyUsage.Usage]? = [.serverAuth]
    var keyUsage: KeyUsage = .init(digitalSignature: true)
    var notBefore: Date = t2026
    var notAfter: Date = t2035
    var unknownCritical: Bool = false
    var subjectCN: String = "example.com"
    var serial: Int = 100
}

func makeLeaf(
    _ options: LeafOptions,
    issuer: DistinguishedName = intermediateName,
    issuerKey: P256.Signing.PrivateKey = intermediateKey
) -> Certificate {
    try! Certificate(
        version: .v3,
        serialNumber: .init(options.serial),
        publicKey: .init(leafKey.publicKey),
        notValidBefore: options.notBefore,
        notValidAfter: options.notAfter,
        issuer: issuer,
        subject: name(options.subjectCN, ou: "N5 Leaves"),
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            Critical(options.keyUsage)
            if let sans = options.sans {
                SubjectAlternativeNames(sans)
            }
            if let eku = options.eku {
                try ExtendedKeyUsage(eku)
            }
            if options.unknownCritical {
                // Private-arc OID, deliberately unrecognized, critical.
                Certificate.Extension(
                    oid: [1, 3, 6, 1, 4, 1, 99999, 99],
                    critical: true,
                    value: [0x04, 0x02, 0xDE, 0xAD]
                )
            }
        },
        issuerPrivateKey: .init(issuerKey)
    )
}

// MARK: 1. happy-path chain

let root = makeCA(subject: rootName, key: rootKey, issuer: rootName, issuerKey: rootKey)
let intermediate = makeCA(
    subject: intermediateName,
    key: intermediateKey,
    issuer: rootName,
    issuerKey: rootKey,
    serial: 2
)
emit(root, as: "root-ca.der", role: "anchor", notes: "P256 self-signed root, cA, 2025-2045")
emit(intermediate, as: "intermediate-ca.der", role: "intermediate", notes: "signed by root, cA, no pathLen")
emit(
    makeLeaf(.init()),
    as: "leaf-valid.der",
    role: "leaf PASS",
    notes: "SAN dns:example.com, serverAuth EKU, digitalSignature, 2026-2035"
)

// MARK: 2. validity

emit(
    makeLeaf(.init(notBefore: t2020, notAfter: t2025, serial: 101)),
    as: "leaf-expired.der",
    role: "leaf FAIL expiry",
    notes: "expired 2025-01-01"
)
emit(
    makeLeaf(.init(notBefore: t2035, notAfter: t2045, serial: 102)),
    as: "leaf-not-yet-valid.der",
    role: "leaf FAIL expiry",
    notes: "notBefore 2035-01-01"
)
emit(
    makeCA(
        subject: intermediateName,
        key: intermediateKey,
        issuer: rootName,
        issuerKey: rootKey,
        notBefore: t2020,
        notAfter: t2025,
        serial: 3
    ),
    as: "intermediate-expired.der",
    role: "intermediate FAIL expiry",
    notes: "expired intermediate for mid-chain validity fixtures"
)

// MARK: 3. signature mismatch

emit(
    makeLeaf(.init(serial: 103), issuer: intermediateName, issuerKey: strangerKey),
    as: "leaf-wrong-key-signature.der",
    role: "leaf FAIL signature",
    notes: "claims intermediate as issuer but signed by an unrelated key"
)
do {
    var serializer = DER.Serializer()
    try! serializer.serialize(makeLeaf(.init(serial: 104)))
    var bytes = serializer.serializedBytes
    // Flip one byte inside the TBS (serial-number content region) so the
    // encoded signature no longer covers the tree it claims to.
    bytes[20] ^= 0xFF
    emitRaw(
        bytes,
        as: "leaf-tampered-tbs.der",
        role: "leaf FAIL signature",
        notes: "valid leaf with one TBS byte flipped post-signing (offset 20)"
    )
}

// MARK: 4. constraints / path length

emit(
    makeCA(
        subject: intermediateName,
        key: intermediateKey,
        issuer: rootName,
        issuerKey: rootKey,
        markCA: false,
        serial: 4
    ),
    as: "intermediate-not-ca.der",
    role: "intermediate FAIL constraints",
    notes: "basicConstraints cA=false on the issuing intermediate"
)
let pathLenZeroIntermediate = makeCA(
    subject: intermediateName,
    key: intermediateKey,
    issuer: rootName,
    issuerKey: rootKey,
    maxPathLength: 0,
    serial: 5
)
let secondIntermediateName = name("N5 Test Second Intermediate CA")
emit(pathLenZeroIntermediate, as: "intermediate-pathlen0.der", role: "intermediate", notes: "pathLen 0")
emit(
    makeCA(
        subject: secondIntermediateName,
        key: strangerKey,
        issuer: intermediateName,
        issuerKey: intermediateKey,
        serial: 6
    ),
    as: "second-intermediate.der",
    role: "intermediate FAIL pathlen",
    notes: "child CA under the pathLen-0 intermediate; leaf-under-it violates path length"
)
emit(
    makeLeaf(.init(serial: 105), issuer: secondIntermediateName, issuerKey: strangerKey),
    as: "leaf-under-second-intermediate.der",
    role: "leaf",
    notes: "leaf issued by second-intermediate (pathlen violation when chained via pathlen0)"
)
emit(
    makeLeaf(.init(unknownCritical: true, serial: 106)),
    as: "leaf-unknown-critical.der",
    role: "leaf FAIL constraints",
    notes: "unrecognized critical extension OID 1.3.6.1.4.1.99999.99"
)

// MARK: 5. TLS policy (EKU / keyUsage)

emit(
    makeLeaf(.init(eku: nil, serial: 107)),
    as: "leaf-no-eku.der",
    role: "leaf policy",
    notes: "EKU absent (policy decides; Institute WebPKI gate treats serverAuth as required)"
)
emit(
    makeLeaf(.init(eku: [.clientAuth], serial: 108)),
    as: "leaf-clientauth-only.der",
    role: "leaf FAIL policy",
    notes: "EKU clientAuth only — serverAuth required"
)
emit(
    makeLeaf(.init(eku: [.ocspSigning], serial: 109)),
    as: "leaf-other-eku.der",
    role: "leaf FAIL policy",
    notes: "EKU ocspSigning only"
)
emit(
    makeLeaf(.init(keyUsage: .init(keyCertSign: true), serial: 110)),
    as: "leaf-keyusage-certsign.der",
    role: "leaf FAIL policy",
    notes: "keyUsage keyCertSign without digitalSignature on an end-entity"
)

// MARK: 6. identity (SAN / CN fallback / encoding / IDNA / wildcard)

emit(
    makeLeaf(.init(sans: [.dnsName("example.com"), .dnsName("alt.example.com")], serial: 120)),
    as: "leaf-multi-san.der",
    role: "leaf identity PASS",
    notes: "two DNS SANs"
)
emit(
    makeLeaf(
        .init(
            sans: [
                .ipAddress(ASN1OctetString(contentBytes: [192, 0, 2, 1])),
                .ipAddress(
                    ASN1OctetString(contentBytes: [
                        0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01,
                    ])
                ),
            ],
            serial: 121,
            )
    ),
    as: "leaf-ip-san.der",
    role: "leaf identity",
    notes: "IPv4 192.0.2.1 + IPv6 2001:db8::1 SANs, no DNS SAN"
)
emit(
    makeLeaf(.init(sans: nil, serial: 122, )),
    as: "leaf-cn-only.der",
    role: "leaf identity FAIL",
    notes: "no SAN extension; CN=example.com — CN fallback must be REJECTED"
)
// SwiftASN1's IA5String validator refuses a NUL at issuance, so the NUL fixture
// is byte-patched after serialization: issue with a one-byte marker (0x7F DEL,
// valid IA5, occurs nowhere else in the DER) and replace it with 0x00. Lengths
// are unchanged; the signature no longer verifies, which is irrelevant to the
// identity-policy fixtures (evaluated by hostname matching, not chain verify).
do {
    let markeredName = "examZple.com"
    let markered = makeLeaf(.init(sans: [.dnsName(markeredName)], serial: 123))
    var serializer = DER.Serializer()
    try! serializer.serialize(markered)
    var patched = serializer.serializedBytes
    let pattern = [UInt8](markeredName.utf8)
    let sites = patched.indices.dropLast(pattern.count - 1).filter { start in
        patched[start..<(start + pattern.count)].elementsEqual(pattern)
    }
    precondition(sites.count == 1, "expected exactly one SAN pattern site, found \(sites.count)")
    patched[sites[0] + 4] = 0x00  // the 'Z' between "exam" and "ple.com"
    emitRaw(
        patched,
        as: "leaf-nul-san.der",
        role: "leaf identity FAIL",
        notes: "embedded NUL in DNS SAN (issued as examZple.com, Z byte-patched to 0x00; signature not valid)"
    )
}
emit(
    makeLeaf(.init(sans: [.dnsName("xn--bcher-kva.example")], serial: 124)),
    as: "leaf-idna-alabel.der",
    role: "leaf identity",
    notes: "IDNA A-label SAN (buecher.example); matches A-label query only"
)
// Raw U-label is invalid IA5, so SwiftASN1 refuses it at issuance; byte-patch
// like the NUL fixture. "bZZcher.example" (15 bytes) is issued, then "ZZ" is
// replaced by the UTF-8 encoding of U+00FC (0xC3 0xBC), yielding the 15-byte
// UTF-8 form of "bücher.example" inside the IA5String slot. Lengths unchanged;
// signature invalidity is irrelevant to identity-policy fixtures.
do {
    let markeredName = "bZZcher.example"
    let markered = makeLeaf(.init(sans: [.dnsName(markeredName)], serial: 125))
    var serializer = DER.Serializer()
    try! serializer.serialize(markered)
    var patched = serializer.serializedBytes
    let pattern = [UInt8](markeredName.utf8)
    let sites = patched.indices.dropLast(pattern.count - 1).filter { start in
        patched[start..<(start + pattern.count)].elementsEqual(pattern)
    }
    precondition(sites.count == 1, "expected exactly one SAN pattern site, found \(sites.count)")
    patched[sites[0] + 1] = 0xC3
    patched[sites[0] + 2] = 0xBC
    emitRaw(
        patched,
        as: "leaf-idna-ulabel.der",
        role: "leaf identity FAIL",
        notes:
            "raw U-label bücher.example in SAN (issued as bZZcher.example, ZZ patched to UTF-8 U+00FC; signature not valid) — Institute policy rejects non-A-label presentation"
    )
}
emit(
    makeLeaf(.init(sans: [.dnsName("*.example.com")], serial: 126)),
    as: "leaf-wildcard.der",
    role: "leaf identity",
    notes: "single-label wildcard: matches a.example.com; must NOT match example.com or a.b.example.com"
)
emit(
    makeLeaf(.init(sans: [.dnsName("*.com")], serial: 127)),
    as: "leaf-wildcard-broad.der",
    role: "leaf identity FAIL",
    notes: "wildcard in registrable-domain position"
)
emit(
    makeLeaf(.init(sans: [.dnsName("f*o.example.com")], serial: 128)),
    as: "leaf-wildcard-partial.der",
    role: "leaf identity FAIL",
    notes: "partial-label wildcard"
)

// MARK: 7. ed25519 chain (algorithm diversity for the verify witness)

let edRootName = name("N5 Test Ed25519 Root CA")
let edRoot = try! Certificate(
    version: .v3,
    serialNumber: .init(200),
    publicKey: .init(ed25519Root.publicKey),
    notValidBefore: t2025,
    notValidAfter: t2045,
    issuer: edRootName,
    subject: edRootName,
    signatureAlgorithm: .ed25519,
    extensions: try Certificate.Extensions {
        Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
        Critical(KeyUsage(keyCertSign: true))
    },
    issuerPrivateKey: .init(ed25519Root)
)
emit(edRoot, as: "ed25519-root-ca.der", role: "anchor", notes: "Ed25519 self-signed root")
emit(
    try! Certificate(
        version: .v3,
        serialNumber: .init(201),
        publicKey: .init(leafKey.publicKey),
        notValidBefore: t2026,
        notValidAfter: t2035,
        issuer: edRootName,
        subject: name("ed.example.com", ou: "N5 Leaves"),
        signatureAlgorithm: .ed25519,
        extensions: try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            Critical(KeyUsage(digitalSignature: true))
            SubjectAlternativeNames([.dnsName("ed.example.com")])
            try ExtendedKeyUsage([.serverAuth])
        },
        issuerPrivateKey: .init(ed25519Root)
    ),
    as: "leaf-ed25519.der",
    role: "leaf PASS",
    notes: "P256 leaf key, Ed25519 issuer signature"
)

// MARK: manifest

var lines = [
    "# N5 fixture corpus — generation manifest",
    "",
    "Generated ONCE in a scratch context and frozen; the publication tree never",
    "contains issuance code. Regeneration requires re-running this scratch tool.",
    "",
    "- Generator: fixture-gen (session scratchpad), swift run via coordinator",
    "- Upstream issuance source: apple/swift-certificates @ 24ccdeeeed4dfaae7955fcac9dbf5489ed4f1a25 (1.18.0)",
    "- Crypto backend: apple/swift-crypto @ exact 4.3.0",
    "- Keys: deterministic P256 raw representations (seeds 0x01 root, 0x02 intermediate, 0x03 leaf, 0x04 stranger); Ed25519 root from fixed 32-byte pattern 0x40...",
    "- Validity instants (Unix): 2020=1577836800, 2025=1735689600, 2026=1767225600, 2035=2051222400, 2045=2366841600",
    "- ECDSA signatures use randomized nonces: byte-identical regeneration is NOT expected; semantic content is deterministic",
    "",
    "| file | role | notes |",
    "|---|---|---|",
]
for e in manifest {
    lines.append("| \(e.file) | \(e.role) | \(e.notes) |")
}
try! lines.joined(separator: "\n").appending("\n")
    .write(to: outDirectory.appendingPathComponent("MANIFEST.md"), atomically: true, encoding: .utf8)

print("emitted \(manifest.count) fixtures + MANIFEST.md into \(outDirectory.path)")
