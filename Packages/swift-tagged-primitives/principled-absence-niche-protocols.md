# Principled Absence — Niche / Edge-Case Conformances (`CustomPlaygroundDisplayConvertible`, `CodingKeyRepresentable`, Decodable Double-Try Fallback)

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

## Context

`pointfreeco/swift-tagged` carries three additional conformances / patterns that Swift Institute's `swift-tagged-primitives` deliberately omits, each with a distinct but short rationale:

1. **`CustomPlaygroundDisplayConvertible`** — playground-specific debugging hook. Not relevant to production primitives infrastructure.
2. **`CodingKeyRepresentable`** — niche protocol for using non-stdlib types as keys in encoded dictionaries. The use case is covered by the simpler conditional `Codable` we already main-ship.
3. **Decodable double-try fallback** — pointfree's `Decodable` init first tries `Underlying(from: decoder)`, then falls back to decoding the underlying value as a single-field container. The fallback path masks decoding errors and adds complexity for edge cases that rarely warrant it.

This document treats the three together because each rationale is short and they share a "niche / not-worth-the-complexity" classification.

**Trigger**: Per-protocol absence work directed by user 2026-04-30. Per [RES-001].

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` carry these niche conformances? If absent by default, what is the consumer alternative for each?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.10 (CodingKeyRepresentable), §3.12 (CustomPlaygroundDisplayConvertible), §5 table row "Decodable fallback" — original removal rationales (one paragraph each).
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) for each conformance.

## Analysis

### A. `CustomPlaygroundDisplayConvertible`

**Pointfree pattern**:
```swift
extension Tagged: CustomPlaygroundDisplayConvertible {
    public var playgroundDescription: Any { underlying }
}
```

**Rationale for absence**:
1. **Playground-specific**. Xcode Playgrounds use this protocol to format value displays in the playground sidebar. Production code paths never invoke `playgroundDescription`. The protocol's surface area is zero outside Playgrounds.
2. **Deprecated direction**. Xcode Playgrounds' role has narrowed; Swift Playgrounds (the iPad app) and Xcode Previews are the live demonstration surfaces, neither of which uses this protocol.
3. **CustomStringConvertible already covers the use case**. Tagged main ships `CustomStringConvertible`, which playgrounds and previews use when `CustomPlaygroundDisplayConvertible` is absent.

**Consumer alternative**: none needed — `CustomStringConvertible` (already in main) covers the reasonable use case.

**Classification**: HARD absence by lack of demand. Not in SLI; consumer-side conformance possible if a specific playground use case warrants it.

### B. `CodingKeyRepresentable`

**Pointfree pattern**:
```swift
extension Tagged: CodingKeyRepresentable where Underlying: CodingKeyRepresentable {
    public init?<T: CodingKey>(codingKey: T) {
        guard let raw = Underlying(codingKey: codingKey) else { return nil }
        self.init(_unchecked: raw)
    }
    public var codingKey: CodingKey { underlying.codingKey }
}
```

**Rationale for absence**:
1. **Niche use case**. `CodingKeyRepresentable` lets non-`String` / non-`Int` types serve as keys in encoded `[T: Value]` dictionaries. Production codecs (JSON, plist) generally use `String` keys; the protocol is rarely the right tool.
2. **Already covered by the simpler conformance**. Tagged main ships `Codable` conditionally on `Underlying: Codable`. This handles the legitimate case (Tagged-as-value); the `CodingKeyRepresentable` extension would handle Tagged-as-dictionary-key, which is unusual.
3. **Implementation complexity outweighs demand**. The `init?(codingKey:)` failable-init pattern + the `codingKey` getter would require careful design to handle the parametric Tag; no clear consumer demand surfaced in the Institute primitives ecosystem.

**Consumer alternative**: per-domain wrapper struct that conforms to `CodingKeyRepresentable` itself if the consumer genuinely needs Tagged-as-dictionary-key. Or use String / Int directly as the key type.

**Classification**: HARD absence by demand. Not in SLI.

### C. Decodable Double-Try Fallback

**Pointfree pattern**:
```swift
extension Tagged: Decodable where Underlying: Decodable {
    public init(from decoder: Decoder) throws {
        do {
            // First try: decode Underlying directly from a single-value container
            let raw = try Underlying(from: decoder)
            self.init(_unchecked: raw)
        } catch {
            // Fallback: decode as a struct with a single `underlying` field
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let raw = try container.decode(Underlying.self, forKey: .underlying)
            self.init(_unchecked: raw)
        }
    }
    private enum CodingKeys: String, CodingKey { case underlying }
}
```

**Rationale for absence**:
1. **Masks decoding errors**. The `do { … } catch { … }` pattern swallows the original `Underlying(from:)` decoding error and reports the fallback's error instead. Consumers receive misleading error messages — the real decoding failure is hidden behind the fallback's keyed-container failure.
2. **Two valid wire formats for the same logical type**. The double-try means `Tagged<Tag, Int>` accepts both `42` (single value) and `{"underlying": 42}` (keyed) on decode. This is "lenient" but creates encode-decode asymmetry — encoding produces one shape, decoding accepts two.
3. **Our simpler conditional is correct**. `extension Tagged: Codable where Underlying: Codable {}` lets Swift synthesize encode/decode from the struct's stored property `underlying`. The synthesizer produces a *keyed* container `{"underlying": N}` — empirically verified in the experiment, contrary to the initial expectation that it would be single-value. This shape is symmetric (encode and decode agree on the keyed shape) and produces single informative errors on decode failure. No fallback, no error masking.

   **Note**: Consumers who need a *single-value* wire shape (e.g., to interop with non-Tagged systems that expect just the underlying value) author a custom `Codable` conformance on a per-domain wrapper struct. The Tagged-level conditional doesn't try to bridge both shapes — that bridging is what the pointfree double-try did, at the cost of error-masking on the failure path.

**Consumer alternative**: if a consumer really needs the fallback behavior (e.g., for backward compatibility with a wire format that previously used `{"underlying": …}`), they can author a custom `Decodable` extension on their domain wrapper.

**Classification**: HARD absence — the fallback is an anti-pattern (masks errors). Not in SLI.

## Empirical verification

[`Experiments/tagged-no-niche-protocols/`](../Experiments/tagged-no-niche-protocols/) verifies each rationale empirically:
- (A) `CustomStringConvertible` covers the playground-style display use case.
- (B) `Codable` conditional handles the Tagged-as-value case.
- (C) Round-trip Encode→Decode on a single-value-container Tagged works without the double-try fallback.

## Outcome

**Status**: DECISION — All three are HARD absences. Not in SLI.

**Soft / Hard classification**: All three are **HARD absences** for distinct reasons:
- `CustomPlaygroundDisplayConvertible` — niche/deprecated; covered by `CustomStringConvertible`.
- `CodingKeyRepresentable` — niche; covered by `Codable`.
- Decodable double-try — anti-pattern (masks errors); covered by symmetric `Codable`.

**Forward-compatibility note**: These rules are policy/anti-pattern based, not toolchain-dependent. They survive Swift toolchain updates.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.10, §3.12, §5 — original removal rationales.
- Apple [`CustomPlaygroundDisplayConvertible`](https://developer.apple.com/documentation/swift/customplaygrounddisplayconvertible).
- Swift stdlib `CodingKeyRepresentable` (Swift 5.6+).
- Swift Evolution [SE-0320 — Coding of non-`String` / non-`Int`-keyed `Dictionary` into a `KeyedContainer`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0320-codingkeyrepresentable.md).
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) for each conformance.
