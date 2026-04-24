# Networking RFC Implementation Plan
<!--
---
version: 1.0.0
last_updated: 2026-01-04
status: RECOMMENDATION
---
-->

> Implementation plan for 8 missing networking RFCs in swift-standards.

## Status Overview

| RFC | Name | Status | Dependencies | Priority |
|-----|------|--------|--------------|----------|
| swift-rfc-8200 | IPv6 Packet Format | MISSING | RFC 4291 (IPv6 Address) | 1 - High |
| swift-rfc-1034 | DNS Concepts | MISSING | RFC 1035 (DNS) | 2 - High |
| swift-rfc-6891 | EDNS | MISSING | RFC 1034, RFC 1035 | 3 - Medium |
| swift-rfc-3596 | DNS AAAA Records | MISSING | RFC 1035, RFC 4291 | 4 - Medium |
| swift-rfc-8446 | TLS 1.3 | MISSING | RFC 791, RFC 9293 | 5 - High |
| swift-rfc-7301 | ALPN | MISSING | RFC 8446 | 6 - Medium |
| swift-rfc-6455 | WebSocket | MISSING | RFC 3986, RFC 8446 (optional) | 7 - High |

---

## Dependency Graph

```
                    swift-standards (core)
                           │
                    swift-incits-4-1986
                           │
            ┌──────────────┴──────────────────┐
            │                                 │
       swift-rfc-791                    swift-rfc-4291
       (IPv4 Address)                   (IPv6 Address)
            │                                 │
            │    ┌────────────────────────────┤
            │    │                            │
            ▼    ▼                            ▼
      swift-rfc-768               ┌──► swift-rfc-8200 (NEW)
      swift-rfc-9293              │    (IPv6 Packet)
      (TCP, UDP)                  │
            │                     │
            └─────────────────────┤
                                  │
                           swift-rfc-1035
                           (DNS Domain)
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
            swift-rfc-1034   swift-rfc-3596   swift-rfc-6891
            (DNS Concepts)   (AAAA Records)   (EDNS)
            (NEW)            (NEW)            (NEW)
                                  │
                                  └──────► depends on RFC 4291

      swift-rfc-3986 ─────────────────────────────────────────┐
      (URI)                                                   │
            │                                                 │
            ▼                                                 │
      swift-rfc-8446 (NEW) ◄──────────────────────────────────┤
      (TLS 1.3)                                               │
            │                                                 │
            ▼                                                 │
      swift-rfc-7301 (NEW)                                    │
      (ALPN)                                                  │
                                                              │
      swift-rfc-6455 (NEW) ◄──────────────────────────────────┘
      (WebSocket)
```

---

## Phase 1: IPv6 Packet Format (RFC 8200)

### Overview
RFC 8200 defines the IPv6 packet format - the next generation Internet Protocol. It supersedes RFC 2460.

### Reusable Dependencies
- **RFC 4291** (IPv6 Addressing) - `RFC_4291.IPv6.Address` - ALREADY EXISTS
- **RFC 5952** (IPv6 Text Representation) - canonical format - ALREADY EXISTS
- **swift-standards** - `Binary.Serializable`, `UInt8.Serializable`

### Types to Implement

```
RFC_8200/
├── RFC_8200.swift                    # Namespace
├── RFC_8200.Packet.swift             # Main IPv6 packet
├── RFC_8200.Header.swift             # 40-byte fixed header
├── RFC_8200.Header.Error.swift
├── RFC_8200.Version.swift            # Always 6
├── RFC_8200.TrafficClass.swift       # 8-bit field (DSCP + ECN)
├── RFC_8200.FlowLabel.swift          # 20-bit field
├── RFC_8200.PayloadLength.swift      # 16-bit
├── RFC_8200.NextHeader.swift         # Protocol type (enum)
├── RFC_8200.HopLimit.swift           # 8-bit TTL equivalent
├── RFC_8200.Extension/               # Extension headers
│   ├── RFC_8200.Extension.Header.swift
│   ├── RFC_8200.Extension.HopByHop.swift
│   ├── RFC_8200.Extension.Routing.swift
│   ├── RFC_8200.Extension.Fragment.swift
│   ├── RFC_8200.Extension.Destination.swift
│   └── RFC_8200.Extension.Authentication.swift
└── exports.swift
```

### Header Format (40 bytes fixed)
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version| Traffic Class |           Flow Label                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Payload Length        |  Next Header  |   Hop Limit   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
+                                                               +
|                                                               |
+                         Source Address                        +
|                                                               |
+                                                               +
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
+                                                               +
|                                                               |
+                      Destination Address                      +
|                                                               |
+                                                               +
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### Key Implementation Details

1. **Binary Serialization** (network byte order):
```swift
extension RFC_8200.Header: UInt8.Serializable {
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ header: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        // Version (4 bits) | Traffic Class (8 bits) | Flow Label (20 bits)
        let versionTrafficFlow: UInt32 =
            (6 << 28) |
            (UInt32(header.trafficClass.rawValue) << 20) |
            UInt32(header.flowLabel.rawValue)
        buffer.append(contentsOf: versionTrafficFlow.bigEndianBytes)

        // Payload Length (16 bits)
        buffer.append(contentsOf: header.payloadLength.rawValue.bigEndianBytes)

        // Next Header (8 bits)
        buffer.append(header.nextHeader.rawValue)

        // Hop Limit (8 bits)
        buffer.append(header.hopLimit.rawValue)

        // Source Address (128 bits)
        RFC_4291.IPv6.Address.serialize(header.source, into: &buffer)

        // Destination Address (128 bits)
        RFC_4291.IPv6.Address.serialize(header.destination, into: &buffer)
    }
}
```

2. **NextHeader enum** (reuse from RFC 791 where applicable):
```swift
extension RFC_8200 {
    public struct NextHeader: RawRepresentable, Sendable, Hashable {
        public let rawValue: UInt8

        // Extension headers
        public static let hopByHop = Self(__unchecked: (), rawValue: 0)
        public static let routing = Self(__unchecked: (), rawValue: 43)
        public static let fragment = Self(__unchecked: (), rawValue: 44)
        public static let destinationOptions = Self(__unchecked: (), rawValue: 60)

        // Upper layer protocols (shared with IPv4)
        public static let tcp = Self(__unchecked: (), rawValue: 6)
        public static let udp = Self(__unchecked: (), rawValue: 17)
        public static let icmpv6 = Self(__unchecked: (), rawValue: 58)
        public static let noNextHeader = Self(__unchecked: (), rawValue: 59)
    }
}
```

### Package.swift
```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-rfc-8200",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11)],
    products: [
        .library(name: "RFC 8200", targets: ["RFC 8200"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-standards/swift-incits-4-1986", from: "0.3.0"),
        .package(url: "https://github.com/swift-standards/swift-rfc-4291", from: "0.1.0"),
        .package(url: "https://github.com/swift-standards/swift-standards", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "RFC 8200",
            dependencies: [
                .product(name: "INCITS 4 1986", package: "swift-incits-4-1986"),
                .product(name: "RFC 4291", package: "swift-rfc-4291"),
                .product(name: "Standards", package: "swift-standards"),
            ]
        ),
        .testTarget(name: "RFC 8200 Tests", dependencies: ["RFC 8200"])
    ],
    swiftLanguageModes: [.v6]
)
```

---

## Phase 2: DNS Concepts (RFC 1034)

### Overview
RFC 1034 defines DNS concepts and facilities. It's primarily a conceptual RFC - types like `Domain` already exist in RFC 1035.

### Reusable Dependencies
- **RFC 1035** - `RFC_1035.Domain`, `RFC_1035.Label` - ALREADY EXISTS

### Types to Implement

RFC 1034 is mostly conceptual. Implement only:

```
RFC_1034/
├── RFC_1034.swift                    # Namespace with documentation
├── RFC_1034.Name.swift               # Type alias to RFC_1035.Domain
├── RFC_1034.Resource.swift           # Resource record concept
├── RFC_1034.Query.swift              # Query types
├── RFC_1034.Zone.swift               # Zone concept
└── exports.swift                     # Re-exports RFC 1035
```

### Key Implementation

```swift
// RFC_1034.swift

/// RFC 1034: Domain Names - Concepts and Facilities
///
/// This RFC introduces the domain name system and its concepts.
/// Implementation details are in RFC 1035.
///
/// ## Key Concepts
///
/// - **Domain Name**: Hierarchical identifier (see ``RFC_1035.Domain``)
/// - **Label**: Single component of a domain name
/// - **Zone**: Administrative boundary for DNS data
/// - **Resource Record**: Data associated with a domain name
///
/// ## See Also
///
/// - [RFC 1034](https://www.rfc-editor.org/rfc/rfc1034)
/// - ``RFC_1035`` for implementation types
public enum RFC_1034 {}

// Most types are re-exports or thin wrappers
extension RFC_1034 {
    /// Domain name type from RFC 1035
    public typealias Name = RFC_1035.Domain
}
```

### Package.swift
```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-rfc-1034",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11)],
    products: [
        .library(name: "RFC 1034", targets: ["RFC 1034"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-standards/swift-rfc-1035", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "RFC 1034",
            dependencies: [
                .product(name: "RFC 1035", package: "swift-rfc-1035"),
            ]
        ),
        .testTarget(name: "RFC 1034 Tests", dependencies: ["RFC 1034"])
    ],
    swiftLanguageModes: [.v6]
)
```

---

## Phase 3: EDNS (RFC 6891)

### Overview
Extension Mechanisms for DNS (EDNS). Extends the DNS message format with OPT pseudo-RR.

### Reusable Dependencies
- **RFC 1035** - DNS message format
- **RFC 1034** - DNS concepts

### Types to Implement

```
RFC_6891/
├── RFC_6891.swift                    # Namespace
├── RFC_6891.OPT.swift               # OPT pseudo-RR
├── RFC_6891.OPT.Error.swift
├── RFC_6891.Option.swift            # EDNS options
├── RFC_6891.Option.Code.swift       # Option codes
├── RFC_6891.ExtendedRcode.swift     # Extended RCODE
├── RFC_6891.Version.swift           # EDNS version
├── RFC_6891.UDPPayloadSize.swift    # Requestor's UDP payload size
└── exports.swift
```

### OPT Record Format
```
+------------+--------------+------------------------------+
| Field Name | Field Type   | Description                  |
+------------+--------------+------------------------------+
| NAME       | domain name  | MUST be 0 (root domain)      |
| TYPE       | u_int16_t    | OPT (41)                     |
| CLASS      | u_int16_t    | requestor's UDP payload size |
| TTL        | u_int32_t    | extended RCODE and flags     |
| RDLENGTH   | u_int16_t    | length of all RDATA          |
| RDATA      | octet stream | {attribute,value} pairs      |
+------------+--------------+------------------------------+
```

### Key Implementation

```swift
extension RFC_6891 {
    /// OPT pseudo-resource record for EDNS
    ///
    /// Per RFC 6891 Section 6.1.2
    public struct OPT: Sendable, Hashable {
        /// Maximum UDP payload size this sender can reassemble
        public let udpPayloadSize: UDPPayloadSize

        /// Extended RCODE (upper 8 bits)
        public let extendedRcode: ExtendedRcode

        /// EDNS version (currently 0)
        public let version: Version

        /// DNSSEC OK bit
        public let dnssecOK: Bool

        /// Options
        public let options: [Option]

        private init(
            __unchecked: Void,
            udpPayloadSize: UDPPayloadSize,
            extendedRcode: ExtendedRcode,
            version: Version,
            dnssecOK: Bool,
            options: [Option]
        ) {
            self.udpPayloadSize = udpPayloadSize
            self.extendedRcode = extendedRcode
            self.version = version
            self.dnssecOK = dnssecOK
            self.options = options
        }
    }
}

extension RFC_6891.OPT: UInt8.Serializable {
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ opt: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        // NAME = 0 (root)
        buffer.append(0)

        // TYPE = 41 (OPT)
        buffer.append(contentsOf: UInt16(41).bigEndianBytes)

        // CLASS = UDP payload size
        buffer.append(contentsOf: opt.udpPayloadSize.rawValue.bigEndianBytes)

        // TTL (extended RCODE + version + DO + Z)
        var ttl: UInt32 = 0
        ttl |= UInt32(opt.extendedRcode.rawValue) << 24
        ttl |= UInt32(opt.version.rawValue) << 16
        if opt.dnssecOK { ttl |= 0x8000 }
        buffer.append(contentsOf: ttl.bigEndianBytes)

        // RDLENGTH + RDATA (options)
        var optionData: [UInt8] = []
        for option in opt.options {
            RFC_6891.Option.serialize(option, into: &optionData)
        }
        buffer.append(contentsOf: UInt16(optionData.count).bigEndianBytes)
        buffer.append(contentsOf: optionData)
    }
}
```

---

## Phase 4: DNS AAAA Records (RFC 3596)

### Overview
Defines the AAAA DNS resource record for storing IPv6 addresses.

### Reusable Dependencies
- **RFC 1035** - DNS message format
- **RFC 4291** - IPv6 Address type

### Types to Implement

```
RFC_3596/
├── RFC_3596.swift                    # Namespace
├── RFC_3596.AAAA.swift              # AAAA record type
├── RFC_3596.AAAA.Error.swift
└── exports.swift
```

### Key Implementation

```swift
extension RFC_3596 {
    /// AAAA Resource Record for IPv6 addresses
    ///
    /// Per RFC 3596 Section 2.1
    ///
    /// ## Wire Format
    ///
    /// A 128-bit IPv6 address is encoded in network byte order.
    public struct AAAA: Sendable, Hashable {
        /// The IPv6 address
        public let address: RFC_4291.IPv6.Address

        private init(__unchecked: Void, address: RFC_4291.IPv6.Address) {
            self.address = address
        }

        public init(address: RFC_4291.IPv6.Address) {
            self.init(__unchecked: (), address: address)
        }
    }
}

// Record type constant
extension RFC_3596 {
    /// DNS record type for AAAA (28)
    public static let recordType: UInt16 = 28
}

extension RFC_3596.AAAA: UInt8.Serializable {
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ record: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        // Serialize 128-bit address in network byte order
        RFC_4291.IPv6.Address.serialize(record.address, into: &buffer)
    }

    public init<Bytes: Collection>(bytes: Bytes) throws(Error)
    where Bytes.Element == UInt8 {
        guard bytes.count == 16 else {
            throw Error.invalidLength(bytes.count)
        }
        let address = try RFC_4291.IPv6.Address(bytes: bytes)
        self.init(__unchecked: (), address: address)
    }
}
```

---

## Phase 5: TLS 1.3 (RFC 8446)

### Overview
Transport Layer Security 1.3 - major revision of the TLS protocol with improved security and reduced round trips.

### Reusable Dependencies
- **RFC 791** - IPv4 (connection context)
- **RFC 9293** - TCP (underlying transport)
- **swift-standards** - Binary serialization

### Types to Implement

```
RFC_8446/
├── RFC_8446.swift                    # Namespace
├── RFC_8446.ProtocolVersion.swift    # TLS versions
├── RFC_8446.ContentType.swift        # Record layer types
├── RFC_8446.Record.swift             # TLS record
├── RFC_8446.Record.Error.swift
├── RFC_8446.Handshake/
│   ├── RFC_8446.Handshake.swift      # Handshake layer
│   ├── RFC_8446.Handshake.Type.swift
│   ├── RFC_8446.Handshake.ClientHello.swift
│   ├── RFC_8446.Handshake.ServerHello.swift
│   ├── RFC_8446.Handshake.Certificate.swift
│   ├── RFC_8446.Handshake.CertificateVerify.swift
│   ├── RFC_8446.Handshake.Finished.swift
│   └── RFC_8446.Handshake.Error.swift
├── RFC_8446.Extension/
│   ├── RFC_8446.Extension.swift      # TLS extensions
│   ├── RFC_8446.Extension.Type.swift
│   ├── RFC_8446.Extension.SupportedVersions.swift
│   ├── RFC_8446.Extension.SupportedGroups.swift
│   ├── RFC_8446.Extension.KeyShare.swift
│   ├── RFC_8446.Extension.SignatureAlgorithms.swift
│   └── RFC_8446.Extension.ServerName.swift
├── RFC_8446.CipherSuite.swift        # Cipher suites
├── RFC_8446.Alert.swift              # Alert protocol
├── RFC_8446.Alert.Level.swift
├── RFC_8446.Alert.Description.swift
└── exports.swift
```

### TLS Record Format
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     Content Type (1 byte)     | Legacy Version (2 bytes) ...  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  ... Legacy Version           |        Length (2 bytes)       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
+                     Fragment (variable)                       +
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### Key Implementation

```swift
extension RFC_8446 {
    /// TLS 1.3 protocol version
    public struct ProtocolVersion: RawRepresentable, Sendable, Hashable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        /// TLS 1.3
        public static let tls1_3 = Self(rawValue: 0x0304)

        /// TLS 1.2 (for compatibility layer)
        public static let tls1_2 = Self(rawValue: 0x0303)

        /// Legacy version used in record layer (always 0x0303)
        public static let legacy = Self(rawValue: 0x0303)
    }
}

extension RFC_8446 {
    /// TLS record content types
    public struct ContentType: RawRepresentable, Sendable, Hashable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let invalid = Self(rawValue: 0)
        public static let changeCipherSpec = Self(rawValue: 20)
        public static let alert = Self(rawValue: 21)
        public static let handshake = Self(rawValue: 22)
        public static let applicationData = Self(rawValue: 23)
    }
}

extension RFC_8446 {
    /// TLS record layer
    ///
    /// Per RFC 8446 Section 5.1
    public struct Record: Sendable {
        public let contentType: ContentType
        public let legacyVersion: ProtocolVersion
        public let fragment: [UInt8]

        public enum Limits {
            /// Maximum fragment length (2^14 = 16384)
            public static let maxFragmentLength = 16384
            /// Maximum record size with overhead
            public static let maxRecordSize = 16384 + 256
        }

        private init(
            __unchecked: Void,
            contentType: ContentType,
            legacyVersion: ProtocolVersion,
            fragment: [UInt8]
        ) {
            self.contentType = contentType
            self.legacyVersion = legacyVersion
            self.fragment = fragment
        }

        public init(
            contentType: ContentType,
            fragment: [UInt8]
        ) throws(Error) {
            guard fragment.count <= Limits.maxFragmentLength else {
                throw Error.fragmentTooLarge(fragment.count)
            }
            self.init(
                __unchecked: (),
                contentType: contentType,
                legacyVersion: .legacy,
                fragment: fragment
            )
        }
    }
}

extension RFC_8446.Record: UInt8.Serializable {
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ record: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(record.contentType.rawValue)
        buffer.append(contentsOf: record.legacyVersion.rawValue.bigEndianBytes)
        buffer.append(contentsOf: UInt16(record.fragment.count).bigEndianBytes)
        buffer.append(contentsOf: record.fragment)
    }
}
```

### Cipher Suites (TLS 1.3 only)

```swift
extension RFC_8446 {
    /// TLS 1.3 Cipher Suite
    public struct CipherSuite: RawRepresentable, Sendable, Hashable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        // RFC 8446 mandatory cipher suites
        public static let aes128GcmSha256 = Self(rawValue: 0x1301)
        public static let aes256GcmSha384 = Self(rawValue: 0x1302)
        public static let chacha20Poly1305Sha256 = Self(rawValue: 0x1303)
    }
}
```

---

## Phase 6: ALPN (RFC 7301)

### Overview
Application-Layer Protocol Negotiation - TLS extension for negotiating application protocols.

### Reusable Dependencies
- **RFC 8446** - TLS 1.3

### Types to Implement

```
RFC_7301/
├── RFC_7301.swift                    # Namespace
├── RFC_7301.Protocol.swift           # Protocol identifier
├── RFC_7301.Protocol.Error.swift
├── RFC_7301.Extension.swift          # ALPN extension
└── exports.swift
```

### Key Implementation

```swift
extension RFC_7301 {
    /// Application-Layer Protocol Negotiation identifier
    ///
    /// Per RFC 7301 Section 3.1
    ///
    /// ## Well-Known Protocols
    ///
    /// - HTTP/1.1: "http/1.1"
    /// - HTTP/2: "h2"
    /// - HTTP/3: "h3"
    public struct ProtocolIdentifier: Sendable, Hashable {
        /// The protocol identifier bytes (1-255 bytes)
        public let rawValue: [UInt8]

        private init(__unchecked: Void, rawValue: [UInt8]) {
            self.rawValue = rawValue
        }

        public init(rawValue: [UInt8]) throws(Error) {
            guard !rawValue.isEmpty else {
                throw Error.empty
            }
            guard rawValue.count <= 255 else {
                throw Error.tooLong(rawValue.count)
            }
            self.init(__unchecked: (), rawValue: rawValue)
        }

        // Well-known protocols
        public static let http1_1 = Self(__unchecked: (), rawValue: Array("http/1.1".utf8))
        public static let h2 = Self(__unchecked: (), rawValue: Array("h2".utf8))
        public static let h3 = Self(__unchecked: (), rawValue: Array("h3".utf8))
    }
}

extension RFC_7301 {
    /// ALPN TLS Extension
    ///
    /// Extension type: 16
    public struct Extension: Sendable, Hashable {
        /// List of supported protocols (in preference order)
        public let protocols: [ProtocolIdentifier]

        public init(protocols: [ProtocolIdentifier]) throws(Error) {
            guard !protocols.isEmpty else {
                throw Error.noProtocols
            }
            self.protocols = protocols
        }
    }
}

extension RFC_7301.Extension: UInt8.Serializable {
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ ext: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        // Calculate total length
        var protocolListData: [UInt8] = []
        for proto in ext.protocols {
            protocolListData.append(UInt8(proto.rawValue.count))
            protocolListData.append(contentsOf: proto.rawValue)
        }

        // Extension type (16)
        buffer.append(contentsOf: UInt16(16).bigEndianBytes)

        // Extension data length
        buffer.append(contentsOf: UInt16(2 + protocolListData.count).bigEndianBytes)

        // Protocol list length
        buffer.append(contentsOf: UInt16(protocolListData.count).bigEndianBytes)

        // Protocols
        buffer.append(contentsOf: protocolListData)
    }
}
```

---

## Phase 7: WebSocket (RFC 6455)

### Overview
The WebSocket Protocol - full-duplex communication over a single TCP connection.

### Reusable Dependencies
- **RFC 3986** - URI parsing (for WebSocket URLs)
- **RFC 8446** - TLS (optional, for WSS)

### Types to Implement

```
RFC_6455/
├── RFC_6455.swift                    # Namespace
├── RFC_6455.Frame.swift              # WebSocket frame
├── RFC_6455.Frame.Error.swift
├── RFC_6455.Opcode.swift             # Frame opcodes
├── RFC_6455.CloseCode.swift          # Close status codes
├── RFC_6455.Handshake/
│   ├── RFC_6455.Handshake.swift      # Opening handshake
│   ├── RFC_6455.Handshake.Request.swift
│   ├── RFC_6455.Handshake.Response.swift
│   └── RFC_6455.Handshake.Error.swift
├── RFC_6455.MaskingKey.swift         # 32-bit masking key
├── RFC_6455.Extension.swift          # WebSocket extensions
└── exports.swift
```

### Frame Format
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+-------------------------------+
|     Extended payload length continued, if payload len == 127  |
+-------------------------------+-------------------------------+
|                               |Masking-key, if MASK set to 1  |
+-------------------------------+-------------------------------+
| Masking-key (continued)       |          Payload Data         |
+-------------------------------+-------------------------------+
|                     Payload Data continued ...                |
+---------------------------------------------------------------+
```

### Key Implementation

```swift
extension RFC_6455 {
    /// WebSocket frame opcode
    public struct Opcode: RawRepresentable, Sendable, Hashable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        // Data frames
        public static let continuation = Self(rawValue: 0x0)
        public static let text = Self(rawValue: 0x1)
        public static let binary = Self(rawValue: 0x2)

        // Control frames
        public static let close = Self(rawValue: 0x8)
        public static let ping = Self(rawValue: 0x9)
        public static let pong = Self(rawValue: 0xA)

        public var isControl: Bool {
            rawValue >= 0x8
        }
    }
}

extension RFC_6455 {
    /// 32-bit masking key
    public struct MaskingKey: Sendable, Hashable {
        public let bytes: (UInt8, UInt8, UInt8, UInt8)

        public init(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) {
            self.bytes = (b0, b1, b2, b3)
        }

        /// Apply mask to data (XOR)
        public func apply(to data: inout [UInt8]) {
            for i in data.indices {
                switch i % 4 {
                case 0: data[i] ^= bytes.0
                case 1: data[i] ^= bytes.1
                case 2: data[i] ^= bytes.2
                case 3: data[i] ^= bytes.3
                default: fatalError()
                }
            }
        }
    }
}

extension RFC_6455 {
    /// WebSocket frame
    ///
    /// Per RFC 6455 Section 5.2
    public struct Frame: Sendable {
        /// Final fragment flag
        public let fin: Bool

        /// Reserved bits (must be 0 unless extension defines them)
        public let rsv1: Bool
        public let rsv2: Bool
        public let rsv3: Bool

        /// Frame opcode
        public let opcode: Opcode

        /// Masking key (required for client-to-server)
        public let mask: MaskingKey?

        /// Payload data (unmasked)
        public let payload: [UInt8]

        public enum Limits {
            /// Maximum control frame payload (125 bytes)
            public static let maxControlPayload = 125
            /// Maximum frame payload (practical limit)
            public static let maxPayload = Int(Int32.max)
        }

        private init(
            __unchecked: Void,
            fin: Bool,
            rsv1: Bool,
            rsv2: Bool,
            rsv3: Bool,
            opcode: Opcode,
            mask: MaskingKey?,
            payload: [UInt8]
        ) {
            self.fin = fin
            self.rsv1 = rsv1
            self.rsv2 = rsv2
            self.rsv3 = rsv3
            self.opcode = opcode
            self.mask = mask
            self.payload = payload
        }

        public init(
            fin: Bool = true,
            opcode: Opcode,
            mask: MaskingKey? = nil,
            payload: [UInt8]
        ) throws(Error) {
            // Control frames must have FIN set
            if opcode.isControl && !fin {
                throw Error.controlFrameMustBeFinal
            }
            // Control frames limited to 125 bytes
            if opcode.isControl && payload.count > Limits.maxControlPayload {
                throw Error.controlPayloadTooLarge(payload.count)
            }
            self.init(
                __unchecked: (),
                fin: fin,
                rsv1: false,
                rsv2: false,
                rsv3: false,
                opcode: opcode,
                mask: mask,
                payload: payload
            )
        }
    }
}

extension RFC_6455.Frame: UInt8.Serializable {
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ frame: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        // First byte: FIN + RSV + Opcode
        var byte0: UInt8 = frame.opcode.rawValue
        if frame.fin { byte0 |= 0x80 }
        if frame.rsv1 { byte0 |= 0x40 }
        if frame.rsv2 { byte0 |= 0x20 }
        if frame.rsv3 { byte0 |= 0x10 }
        buffer.append(byte0)

        // Second byte: MASK + Payload length
        let masked = frame.mask != nil
        var byte1: UInt8 = masked ? 0x80 : 0

        if frame.payload.count < 126 {
            byte1 |= UInt8(frame.payload.count)
            buffer.append(byte1)
        } else if frame.payload.count <= 65535 {
            byte1 |= 126
            buffer.append(byte1)
            buffer.append(contentsOf: UInt16(frame.payload.count).bigEndianBytes)
        } else {
            byte1 |= 127
            buffer.append(byte1)
            buffer.append(contentsOf: UInt64(frame.payload.count).bigEndianBytes)
        }

        // Masking key
        if let mask = frame.mask {
            buffer.append(mask.bytes.0)
            buffer.append(mask.bytes.1)
            buffer.append(mask.bytes.2)
            buffer.append(mask.bytes.3)

            // Masked payload
            var maskedPayload = frame.payload
            mask.apply(to: &maskedPayload)
            buffer.append(contentsOf: maskedPayload)
        } else {
            buffer.append(contentsOf: frame.payload)
        }
    }
}
```

### Close Codes

```swift
extension RFC_6455 {
    /// WebSocket close status codes
    ///
    /// Per RFC 6455 Section 7.4.1
    public struct CloseCode: RawRepresentable, Sendable, Hashable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public static let normalClosure = Self(rawValue: 1000)
        public static let goingAway = Self(rawValue: 1001)
        public static let protocolError = Self(rawValue: 1002)
        public static let unsupportedData = Self(rawValue: 1003)
        public static let noStatusReceived = Self(rawValue: 1005)
        public static let abnormalClosure = Self(rawValue: 1006)
        public static let invalidPayloadData = Self(rawValue: 1007)
        public static let policyViolation = Self(rawValue: 1008)
        public static let messageTooLarge = Self(rawValue: 1009)
        public static let mandatoryExtension = Self(rawValue: 1010)
        public static let internalError = Self(rawValue: 1011)
        public static let tlsHandshakeFailed = Self(rawValue: 1015)
    }
}
```

---

## Implementation Order

Based on dependencies:

1. **swift-rfc-8200** (IPv6 Packet) - Depends on RFC 4291 (exists)
2. **swift-rfc-1034** (DNS Concepts) - Depends on RFC 1035 (exists)
3. **swift-rfc-3596** (DNS AAAA) - Depends on RFC 1035, RFC 4291 (both exist)
4. **swift-rfc-6891** (EDNS) - Depends on RFC 1035 (exists)
5. **swift-rfc-8446** (TLS 1.3) - Foundational, no swift-standards deps beyond core
6. **swift-rfc-7301** (ALPN) - Depends on RFC 8446 (implement after)
7. **swift-rfc-6455** (WebSocket) - Depends on RFC 3986 (exists), RFC 8446 (optional)

---

## Testing Strategy

### Unit Tests per Package

1. **Serialization round-trip**: `Type → bytes → Type`
2. **Parse valid inputs**: Known-good wire formats
3. **Reject invalid inputs**: Truncated, malformed, out-of-range
4. **Constants verification**: Well-known values match RFC
5. **Limits enforcement**: Maximum sizes respected

### Example Test Pattern

```swift
import Testing
@testable import RFC_8200

@Suite("RFC 8200 IPv6 Packet Tests")
struct IPv6Tests {
    @Test("Header serializes to 40 bytes")
    func headerSize() throws {
        let header = try RFC_8200.Header(
            trafficClass: .init(rawValue: 0),
            flowLabel: .init(rawValue: 0),
            payloadLength: .init(rawValue: 0),
            nextHeader: .tcp,
            hopLimit: .init(rawValue: 64),
            source: try .loopback,
            destination: try .loopback
        )

        var buffer: [UInt8] = []
        RFC_8200.Header.serialize(header, into: &buffer)

        #expect(buffer.count == 40)
    }

    @Test("Version field is always 6")
    func versionIs6() throws {
        let header = try RFC_8200.Header(/* ... */)
        var buffer: [UInt8] = []
        RFC_8200.Header.serialize(header, into: &buffer)

        // First 4 bits
        let version = (buffer[0] >> 4) & 0x0F
        #expect(version == 6)
    }
}
```

---

## Workspace Integration

All packages should be added to `Standards.xcworkspace` for unified development:

1. Create each package directory
2. Add to workspace file
3. Create schemes for each target
4. Verify local dependency resolution

---

## Checklist Template

For each package:

- [ ] Create package directory `swift-rfc-XXXX`
- [ ] Write `Package.swift` with correct dependencies
- [ ] Create `Sources/RFC XXXX/` directory structure
- [ ] Implement namespace enum (`RFC_XXXX.swift`)
- [ ] Implement core types with validation
- [ ] Implement error types
- [ ] Implement `UInt8.Serializable` / `Binary.ASCII.Serializable`
- [ ] Add `exports.swift`
- [ ] Create test target
- [ ] Write unit tests (serialization round-trip, parsing, validation)
- [ ] Add to `Standards.xcworkspace`
- [ ] Verify builds in workspace
- [ ] Run tests via workspace scheme

---

**Validation**: See `Experiments/rfc-4291-ipv6-address-poc/`

*Last updated: 2026-01-04*
