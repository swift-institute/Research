# Typed Throws Standards Inventory

> Generated: 2026-03-04
> Scope: `/Users/coen/Developer/swift-standards/`
> Excludes: test targets, macro conformances, already-typed functions
> Method: Exhaustive grep of all 2316 source files across 94 packages with Sources directories

## Summary

- Total untyped throws found: **124** (across 62 files in 24 packages)
- Ready for conversion: **0**
- Needs error type creation: **0**
- Mixed domain: **0**
- Blocked by stdlib: **0**
- Foreign type: **0**
- **Protocol-mandated (Codable): 122** -- cannot be typed; `Decodable.init(from:)` and `Encodable.encode(to:)` protocol requirements use untyped `throws`
- **Protocol-mandated (Clock): 2** -- cannot be typed; `_Concurrency.Clock.sleep(until:tolerance:)` protocol requirement uses untyped `async throws`
- Packages with zero untyped throws: **70**

### Key Finding

**Every remaining untyped `throws` in swift-standards is protocol-mandated.** There are zero non-protocol-mandated untyped throws remaining in any source file. The typed throws conversion for swift-standards is effectively **complete**.

All 124 instances fall into exactly two categories:
1. `Codable` conformances (`Decodable.init(from:)` / `Encodable.encode(to:)`) -- 122 instances
2. `_Concurrency.Clock` conformance (`Clock.sleep(until:tolerance:)`) -- 2 instances

Neither category can use typed throws because the Swift standard library protocols define these requirements with untyped `throws`. This would require upstream Swift evolution proposals to change.

---

## Previously Converted Packages (Verification)

All previously converted packages were verified. Their residual untyped throws are exclusively Codable/Clock protocol conformances:

| Package | Residual Untyped | Category | Status |
|---------|-----------------|----------|--------|
| swift-iso-32000 | 0 | -- | Clean |
| swift-rfc-4122 | 0 | -- | Clean |
| swift-ieee-754 | 0 | -- | Clean |
| swift-color-standard | 0 | -- | Clean |
| swift-iso-9945 | 2 | Clock.sleep (x2) | Protocol-mandated |
| swift-iso-14496-22 | 0 | -- | Clean |
| swift-rfc-6570 | 2 | Codable (x2) | Protocol-mandated |
| swift-rfc-9112 | 4 | Codable (x4) | Protocol-mandated |
| swift-iso-8601 | 10 | Codable (x10) | Protocol-mandated |

No regressions found. All non-Codable/non-Clock throwing functions in previously converted packages use typed throws correctly.

---

## Inventory by Package

### Package: swift-domain-standard (2 untyped)

#### File: `swift-domain-standard/Sources/Domain Standard/Domain.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 229 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via `container.encode()` | Codable protocol |
| 234 | `public init(from decoder: any Decoder) throws` | `DecodingError` via `container.decode()` | Codable protocol |

---

### Package: swift-email-standard (4 untyped)

#### File: `swift-email-standard/Sources/Email Standard/Email.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 447 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container methods | Codable protocol |
| 463 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via container methods | Codable protocol |
| 486 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container methods | Codable protocol |
| 507 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via container methods | Codable protocol |

---

### Package: swift-emailaddress-standard (2 untyped)

#### File: `swift-emailaddress-standard/Sources/EmailAddress Standard/EmailAddress.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 206 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via `container.encode()` | Codable protocol |
| 211 | `public init(from decoder: any Decoder) throws` | `DecodingError` via `container.decode()` | Codable protocol |

---

### Package: swift-iso-15924 (4 untyped)

#### File: `swift-iso-15924/Sources/ISO 15924/ISO_15924.Alpha4.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 87 | `public func encode(to encoder: Encoder) throws` | `EncodingError` via `container.encode()` | Codable protocol |
| 92 | `public init(from decoder: Decoder) throws` | `DecodingError` via `container.decode()` | Codable protocol |

#### File: `swift-iso-15924/Sources/ISO 15924/ISO_15924.Numeric.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 85 | `public func encode(to encoder: Encoder) throws` | `EncodingError` via `container.encode()` | Codable protocol |
| 90 | `public init(from decoder: Decoder) throws` | `DecodingError` via `container.decode()` | Codable protocol |

---

### Package: swift-iso-3166 (8 untyped)

#### File: `swift-iso-3166/Sources/ISO 3166/ISO_3166.Alpha2.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 86 | `public func encode(to encoder: Encoder) throws` | `EncodingError` | Codable protocol |
| 91 | `public init(from decoder: Decoder) throws` | `DecodingError` | Codable protocol |

#### File: `swift-iso-3166/Sources/ISO 3166/ISO_3166.Alpha3.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 86 | `public func encode(to encoder: Encoder) throws` | `EncodingError` | Codable protocol |
| 91 | `public init(from decoder: Decoder) throws` | `DecodingError` | Codable protocol |

#### File: `swift-iso-3166/Sources/ISO 3166/ISO_3166.Code.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 127 | `public func encode(to encoder: Encoder) throws` | `EncodingError` | Codable protocol |
| 132 | `public init(from decoder: Decoder) throws` | `DecodingError` | Codable protocol |

#### File: `swift-iso-3166/Sources/ISO 3166/ISO_3166.Numeric.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 86 | `public func encode(to encoder: Encoder) throws` | `EncodingError` | Codable protocol |
| 91 | `public init(from decoder: Decoder) throws` | `DecodingError` | Codable protocol |

---

### Package: swift-iso-639 (6 untyped)

#### File: `swift-iso-639/Sources/ISO 639/ISO_639.Alpha2.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 86 | `public func encode(to encoder: Encoder) throws` | `EncodingError` | Codable protocol |
| 91 | `public init(from decoder: Decoder) throws` | `DecodingError` | Codable protocol |

#### File: `swift-iso-639/Sources/ISO 639/ISO_639.Alpha3.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 86 | `public func encode(to encoder: Encoder) throws` | `EncodingError` | Codable protocol |
| 91 | `public init(from decoder: Decoder) throws` | `DecodingError` | Codable protocol |

#### File: `swift-iso-639/Sources/ISO 639/ISO_639.LanguageCode.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 125 | `public func encode(to encoder: Encoder) throws` | `EncodingError` | Codable protocol |
| 130 | `public init(from decoder: Decoder) throws` | `DecodingError` | Codable protocol |

---

### Package: swift-iso-8601 (10 untyped) -- Previously Converted

#### File: `swift-iso-8601/Sources/ISO 8601/ISO_8601.DateTime.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 1055 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container, delegates to typed-throws parsing | Codable protocol |
| 1063 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via `container.encode()` | Codable protocol |

#### File: `swift-iso-8601/Sources/ISO 8601/ISO_8601.Duration.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 363 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 369 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-iso-8601/Sources/ISO 8601/ISO_8601.Interval.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 148 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 154 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-iso-8601/Sources/ISO 8601/ISO_8601.RecurringInterval.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 146 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 152 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-iso-8601/Sources/ISO 8601/ISO_8601.Time.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 440 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 446 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

---

### Package: swift-iso-9945 (2 untyped) -- Previously Converted

#### File: `swift-iso-9945/Sources/ISO 9945 Kernel/ISO 9945.Clock.Continuous.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 41 | `public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws` | `CancellationError` via `Task.checkCancellation()`, plus errors from `Task.sleep(for:)` | Clock protocol |
| 72 | `public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws` | `CancellationError` via `Task.checkCancellation()`, plus errors from `Task.sleep(for:)` | Clock protocol |

Note: These are `_Concurrency.Clock` protocol conformances for `Clock.Continuous` and `Clock.Suspending`. The protocol requirement `func sleep(until:tolerance:) async throws` cannot use typed throws.

---

### Package: swift-json-feed-standard (2 untyped)

#### File: `swift-json-feed-standard/Sources/JSON Feed Standard/Feed.swift`

| Line | Function Signature | Error Path | Category | Note |
|------|-------------------|------------|----------|------|
| 98 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container methods + custom `Error.invalidVersion` | Codable protocol | Mixed domain but protocol-mandated |

#### File: `swift-json-feed-standard/Sources/JSON Feed Standard/Item.swift`

| Line | Function Signature | Error Path | Category | Note |
|------|-------------------|------------|----------|------|
| 115 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container methods + custom `Error.itemRequiresContent` | Codable protocol | Mixed domain but protocol-mandated |

Note: These Codable decoders throw both `DecodingError` (from stdlib container methods) AND custom `Feed.Error`/`Item.Error` types for validation. Even if typed throws were available on the protocol, these would be mixed-domain. However, since the `Decodable` protocol mandates untyped `throws`, this is moot.

---

### Package: swift-locale-standard (4 untyped)

#### File: `swift-locale-standard/Sources/Locale Standard/Language.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 93 | `public func encode(to encoder: Encoder) throws` | `EncodingError` | Codable protocol |
| 98 | `public init(from decoder: Decoder) throws` | `DecodingError` | Codable protocol |

#### File: `swift-locale-standard/Sources/Locale Standard/Locale.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 158 | `public func encode(to encoder: Encoder) throws` | `EncodingError` | Codable protocol |
| 163 | `public init(from decoder: Decoder) throws` | `DecodingError` | Codable protocol |

---

### Package: swift-rfc-2369 (2 untyped)

#### File: `swift-rfc-2369/Sources/RFC 2369/RFC_2369.List.Post.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 195 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container methods | Codable protocol |
| 208 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via container methods | Codable protocol |

---

### Package: swift-rfc-2822 (2 untyped)

#### File: `swift-rfc-2822/Sources/RFC 2822/RFC_2822.Message.Body.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 110 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |
| 116 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |

---

### Package: swift-rfc-3986 (18 untyped)

#### File: `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 968 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 975 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Authority.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 333 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 339 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Fragment.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 140 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + wraps parse errors | Codable protocol |
| 146 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Host.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 279 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 285 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Path.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 333 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + wraps `self.init()` errors | Codable protocol |
| 346 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Port.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 238 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 244 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Query.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 400 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + wraps `self.init()` errors | Codable protocol |
| 413 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Scheme.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 194 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 200 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Userinfo.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 197 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 203 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

---

### Package: swift-rfc-4287 (6 untyped)

#### File: `swift-rfc-4287/Sources/RFC 4287/RFC_4287.Content.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 35 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 41 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-4287/Sources/RFC 4287/RFC_4287.Link.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 172 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 178 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-4287/Sources/RFC 4287/RFC_4287.Person.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 120 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 148 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

---

### Package: swift-rfc-4291 (2 untyped)

#### File: `swift-rfc-4291/Sources/RFC 4291/RFC_4291.IPv6.Address.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 449 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + wraps `self.init(ascii:in:)` errors into `DecodingError.dataCorrupted` | Codable protocol |
| 464 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via `container.encode()` | Codable protocol |

---

### Package: swift-rfc-5322 (6 untyped)

#### File: `swift-rfc-5322/Sources/RFC 5322/RFC_5322.DateTime.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 571 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 578 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-5322/Sources/RFC 5322/RFC_5322.EmailAddress.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 230 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |
| 235 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |

#### File: `swift-rfc-5322/Sources/RFC 5322/RFC_5322.Message.ID.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 163 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |
| 170 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |

---

### Package: swift-rfc-5646 (2 untyped)

#### File: `swift-rfc-5646/Sources/RFC 5646/RFC_5646.LanguageTag.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 410 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |
| 415 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |

---

### Package: swift-rfc-6455 (2 untyped)

#### File: `swift-rfc-6455/Sources/RFC 6455/RFC_6455.MaskingKey.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 125 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 131 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

---

### Package: swift-rfc-6570 (2 untyped) -- Previously Converted

#### File: `swift-rfc-6570/Sources/RFC 6570/RFC_6570.Template.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 87 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 93 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

---

### Package: swift-rfc-7301 (2 untyped)

#### File: `swift-rfc-7301/Sources/RFC 7301/RFC_7301.ProtocolIdentifier.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 98 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + wraps `self.init()` errors into `DecodingError.dataCorrupted` | Codable protocol |
| 113 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via `container.encode()` | Codable protocol |

---

### Package: swift-rfc-8200 (2 untyped)

#### File: `swift-rfc-8200/Sources/RFC 8200/RFC_8200.Header.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 232 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container methods | Codable protocol |
| 243 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via container methods | Codable protocol |

---

### Package: swift-rfc-9110 (24 untyped)

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.Authentication.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 314 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 320 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.ContentEncoding.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 126 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 132 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.ContentLanguage.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 90 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 96 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.EntityTag.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 149 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + `DecodingError.dataCorruptedError` for invalid tag | Codable protocol |
| 163 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.Header.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 432 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 438 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.Headers.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 236 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 242 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.MediaType.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 198 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + `DecodingError.dataCorruptedError` for invalid type | Codable protocol |
| 212 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.Method.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 125 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 143 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.Request.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 561 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container methods | Codable protocol |
| 576 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via container methods | Codable protocol |
| 597 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + `DecodingError.dataCorruptedError` for unknown form; also calls `RFC_3986.URI(_:)` which may throw parse errors | Codable protocol |
| 628 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` via container methods | Codable protocol |

Note: Line 597 (`Request.Target.init(from:)`) calls `try RFC_3986.URI(uriString)` on line 609, which could throw a parse error that is NOT `DecodingError`. This is a mixed-domain Codable decoder, but since the protocol mandates untyped `throws`, it works correctly as-is.

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.Response.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 145 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 158 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9110/Sources/RFC 9110/HTTP.Status.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 94 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |
| 100 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

---

### Package: swift-rfc-9112 (4 untyped) -- Previously Converted

#### File: `swift-rfc-9112/Sources/RFC 9112/HTTP.Connection.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 190 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + `DecodingError.dataCorruptedError` for invalid connection | Codable protocol |
| 204 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rfc-9112/Sources/RFC 9112/HTTP.TransferEncoding.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 253 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container + `DecodingError.dataCorruptedError` for invalid encoding | Codable protocol |
| 267 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

---

### Package: swift-rss-standard (6 untyped)

#### File: `swift-rss-standard/Sources/RSS Standard/CloudProtocol.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 29 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |
| 34 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |

#### File: `swift-rss-standard/Sources/RSS Standard/GUID.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 56 | `public init(from decoder: any Decoder) throws` | `DecodingError` via container methods (uses `makeUnchecked`, no custom throws) | Codable protocol |
| 65 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |

#### File: `swift-rss-standard/Sources/RSS Standard/Hour.swift`

| Line | Function Signature | Error Path | Category |
|------|-------------------|------------|----------|
| 20 | `public func encode(to encoder: any Encoder) throws` | `EncodingError` | Codable protocol |
| 25 | `public init(from decoder: any Decoder) throws` | `DecodingError` | Codable protocol |

---

## Blocked Items Detail

### Codable Protocol (`Decodable` / `Encodable`) -- 122 instances

**Why blocked**: The Swift standard library defines the `Decodable` and `Encodable` protocols with untyped `throws`:

```swift
// Swift stdlib definition
public protocol Decodable {
    init(from decoder: any Decoder) throws  // No typed throws
}

public protocol Encodable {
    func encode(to encoder: any Encoder) throws  // No typed throws
}
```

Conforming types MUST match the protocol signature. Using `throws(DecodingError)` or `throws(EncodingError)` would not satisfy the protocol requirement.

**What would unblock**: A Swift Evolution proposal to add typed throws to `Codable` protocols, e.g.:
```swift
public protocol Decodable {
    init(from decoder: any Decoder) throws(DecodingError)
}
```

**Likelihood**: Low-medium. This would be a source-breaking change unless done with careful migration. SE-0413 (typed throws) was accepted but the stdlib has not been updated to use it for Codable.

### Clock Protocol (`_Concurrency.Clock`) -- 2 instances

**Why blocked**: The `Clock` protocol in `_Concurrency` defines:

```swift
public protocol Clock {
    func sleep(until deadline: Instant, tolerance: Duration?) async throws
}
```

**What would unblock**: A Swift Evolution proposal to add typed throws to `Clock.sleep`, e.g., `async throws(CancellationError)`.

**Likelihood**: Medium. `CancellationError` is the only error type thrown by the standard implementation, so this is a natural fit.

---

## Recommendations

### 1. No action needed for swift-standards

The typed throws conversion for swift-standards is **complete**. Every convertible function has already been converted. The 124 remaining instances are all protocol-mandated and cannot be changed without upstream Swift evolution changes.

### 2. Track upstream Swift evolution

Monitor these potential proposals:
- **Typed throws for Codable**: Would allow `throws(DecodingError)` / `throws(EncodingError)` on protocol conformances
- **Typed throws for Clock**: Would allow `async throws(CancellationError)` on clock sleep methods

### 3. Quality observation: mixed-domain Codable decoders

Three Codable decoders throw non-`DecodingError` types:
- `Feed.init(from:)` in swift-json-feed-standard -- throws custom `Feed.Error.invalidVersion`
- `Item.init(from:)` in swift-json-feed-standard -- throws custom `Item.Error.itemRequiresContent`
- `Request.Target.init(from:)` in swift-rfc-9110 -- calls `RFC_3986.URI(_:)` which throws parse errors

If Codable ever gains typed throws, these three would need error wrapping into `DecodingError.dataCorrupted` to satisfy a hypothetical `throws(DecodingError)` requirement. Consider preemptively wrapping these for consistency:

```swift
// Current (json-feed Feed.init(from:))
throw Error.invalidVersion(description: "...")

// Suggested (wraps in DecodingError for Codable consistency)
throw DecodingError.dataCorruptedError(
    forKey: .version,
    in: container,
    debugDescription: "Expected version 1.1 or 1, got: \(version)"
)
```

### 4. Priority for other repos

Since swift-standards is complete, focus typed throws efforts on:
1. **swift-foundations** -- 17 closure parameters (blocked by stdlib rethrows or mixed domains)
2. **swift-primitives** -- 11 async throws (Cache, Pool, Clock design decisions)
3. **swift-standards remaining** from previous inventory: 2 mixed deserializers in rfc-9112, 1 mixed init in iso-8601 (already noted as intentionally left untyped)
