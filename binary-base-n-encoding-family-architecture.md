# Binary Base-N Encoding Family Architecture

<!--
---
version: 1.0.0
last_updated: 2026-05-07
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

> **Phase 2 superseded 2026-05-07** by [`binary-base-n-rfc-4648-reconciliation.md`](binary-base-n-rfc-4648-reconciliation.md).
> The original's `[Verified: 2026-05-07] no swift-ietf/swift-rfc-4648 repo` claim was wrong — the
> repo exists, is public, and is actively-developed with a different architecture. The reconciliation
> doc pivots Phase 2 to a refactor of the existing package (delegating its algorithms to swift-binary-base-primitives)
> and adds a Phase 4 for an L3 unifier (`swift-foundations/swift-binary-base`) that hosts the originally-envisioned
> `Binary.Base.`N`.encode(bytes)` ergonomic public API. Phase 1 (swift-binary-base-primitives shipped
> 2026-05-07) is unaffected.

## Context

The ecosystem ships exactly one binary→text encoding package — `swift-base62-primitives` — and no others. This single-package presence is a structural problem on three axes:

1. **Heritage drift.** `swift-base62-primitives` was authored before the swift-primitives org coalesced. Its source comment (`Sources/Base62 Primitives/Base62_Primitives.swift:48` [Verified: 2026-05-07]) reads `Created by Claude Code on behalf of the swift-standards project`. Its README hardcodes `swift-standards/swift-base62-primitives` URLs throughout, despite the repo currently living at `swift-primitives/swift-base62-primitives`. The package was renamed during the 2026-04-22 GitHub-org migration (`swift-base62-standard` → `swift-base62-primitives`) per `swift-institute/Audits/standards-org-migration-plan-audit.md`, but the API surface and README were not part of the modernization wave.

2. **Convention mismatch.** The package declares `public enum Base62_Primitives {}` as the type-level namespace — i.e., the module name (`Base62_Primitives`) and the type namespace are the same string. Compare the recently-published swift-primitives cohort (`carrier`, `tagged`, `property`, `ownership`, all 0.1.0 in 2026-04-30): `public enum Carrier`, `public struct Tagged`, etc. — clean Nest.Name per [API-NAME-001], not module-name-as-type. Files are inconsistently named (mix of `Base62_Primitives.X.swift`, `BinaryInteger+Base62.swift`, `String.Base62.swift`, `UInt8.Base62.swift`, three different conventions in one package).

3. **Tier mis-classification.** The compute-tiers script reports `swift-base62-primitives` at tier 0 (a leaf), but its Package.swift [Verified: 2026-05-07] declares `swift-binary-primitives` (tier 14) as a path dependency via `../../swift-primitives/swift-binary-primitives`. The actual package-level tier is 15. The `../../` path prefix is parsed but the dependency is missed by the script's classifier — a script bug whose effect is to conceal the package from upstream-leaf publication queues. Publishing base62 today implies publishing the entire binary-primitives subtree (tiers 0–14, dozens of packages).

4. **Family incompleteness.** Beyond base62, the ecosystem ships no other baseN encoding. RFC 4648 (base16, base32, base32hex, base64, base64url) is not implemented. Bitcoin base58, ZeroMQ Z85, RFC 1924 base85, Adobe Ascii85 — none. Shipping a single obscure URL-shortener encoding without hex or base64 is an actively bad first impression of the institute's encoding story.

The institute is preparing the next public-publish cohort after the 0.1.0 quartet (carrier → ownership → tagged → property). The leaf-first publish strategy needs a coherent answer for the binary→text encoding family.

**Trigger**: Pre-cohort architectural decision. The legacy package is unsuitable to publish as-is; the broader family is missing entirely; the namespace shape was challenged in-conversation as too lenient (V1 value-generic) and corrected (V6 closed-radix nested types) and then refined for call-site ergonomics (V7 Property<Tag, Base>).

**Constraints**:

- Closed-radix-set semantics must be enforced at compile time (the radix axis is closed by binary→text encoding mathematics; only ~6 radixes have semantic meaning).
- Open alphabet axis must be preserved (custom alphabets per domain; multiple alphabets per radix for base32/64/85; spec-defined alphabets for RFC variants).
- Multi-form operations under one root MUST use Property.View per [API-NAME-008].
- Non-RFC alphabets are convention-defined (Bitcoin base58, GMP base62) and live with the convention authority; RFC alphabets live with the RFC.
- The mechanism package must be a true tier-0 leaf (no path-dep on heavyweight upstream packages).

## Question

What is the architectural shape — namespace, package layering, type-system contract, call-site syntax — for a coherent binary↔text encoding family in the Swift Institute ecosystem, given that:

(a) the radix set is closed by encoding mathematics (~6 useful values) but
(b) the alphabet set per radix is open (RFC + de facto + custom), and
(c) the call site should read uniformly across single- and multi-alphabet radixes, and
(d) the legacy `swift-base62-primitives` should be replaced rather than modernized?

## Internal Research Survey [Step-0 grep per [RES-019]]

```bash
$ grep -rl -i "base16\|base32\|base58\|base62\|base64\|base85\|baseN\|RFC.*4648\|Crockford\|Z85\|Ascii85" \
    /Users/coen/Developer/swift-institute/Research \
    /Users/coen/Developer/swift-primitives/Documentation.docc/Research
```

[Verified: 2026-05-07] No prior internal research on base-N encoding family architecture. The grep matches in `claude-code-swift-rewrite-feasibility.md`, `pdf-standard-case-study.md`, `release-roadmap-swift-file-system.md`, and others are coincidental substring hits, not topical research. This is the first ecosystem-wide research document on the topic.

## Prior Art Survey [per [RES-021]]

[Verified: 2026-05-07 against primary source links]

| System | Surface | Pattern |
|--------|---------|---------|
| Apple Foundation | `Data.base64EncodedString(options:)`, `Data(base64Encoded:options:)` | Methods on Data; OptionSet for variant. **No base16/32/58/62/85 in Foundation.** |
| Python `base64` module | `b16encode`, `b32encode`, `b32hexencode`, `b64encode`, `urlsafe_b64encode`, `b85encode`, `a85encode` | Top-level functions per (radix, alphabet). One function per spec variant. |
| Rust `base64` crate | `Engine` trait + `STANDARD`, `STANDARD_NO_PAD`, `URL_SAFE` const Engine values; `engine.encode(input)` | Engine-as-witness. Each variant is a distinct const-Engine value. ([crates.io/crates/base64](https://crates.io/crates/base64)) |
| Rust `hex` crate | `hex::encode(data)`, `hex::decode(s)` | Top-level functions; no engine (only one base16 alphabet). |
| Rust `bs58` crate (Bitcoin) | `bs58::encode(data).into_string()`, builder pattern with `.with_alphabet(&Alphabet::BITCOIN)` | Builder pattern; `Alphabet` is a value, builder consumes it. |
| JavaScript / Node | `btoa(data)` / `atob(s)` (built-in base64 only); `Buffer.from(data, 'hex' \| 'base64' \| 'base64url')` | Variant-as-string-flag. No general baseN. |
| Erlang/Elixir `:base16`, `:base32`, `:base64` | Module per radix; functions per variant within module | Module-per-radix. |

Cross-system observations:

- **Python's per-variant functions** (one function per spec section: `b16encode` for §8, `b32encode` for §6, `b32hexencode` for §7, `b64encode` for §4, `urlsafe_b64encode` for §5, `b85encode` for RFC 1924) is the most explicit expression of "alphabet IS part of the API surface, not a parameter." This is closest to our V7 — except Python flattens all variants to module-scope functions, while our type system can nest them under `Binary.Base.\`N\`.encode.<variant>`.
- **Rust `base64::Engine`** is the witness pattern. `STANDARD`, `URL_SAFE`, `URL_SAFE_NO_PAD` are const Engine values; `encode` is a method on the Engine. This is structurally identical to our V1 / V6 witness shape (`.rfc4648.encode(...)`). Rust's hex crate sidesteps the witness because there's only one hex alphabet — same special-case observation that motivated this Doc's question.
- **Rust `bs58`** uses a builder, which is between Engine-witness and method-on-type — flexible but call-site-heavy.

[Contextualization step per [RES-021]]: The cross-system pattern is "alphabet is a value or a parameter." Universal adoption is real. Our deviation: leveraging `Property<Tag, Base>` from `swift-property-primitives` lets us have alphabet-as-value-but-erased-at-call-site, with each variant becoming a distinct method on the Property. The call site reads as method-on-type (Python's flat-function ergonomics) while the type system tracks alphabet via the Property's phantom Tag (Rust's Engine-as-value precision). This is the institute-specific optimization, not a gap relative to prior art.

## Premature Primitive Check [per [RES-018]]

### Why not compose existing primitives?

- **swift-base62-primitives** [Verified: 2026-05-07]: ships only base62, with stale `swift-standards` URLs, module-name-as-type-name namespace, mixed file naming, and a tier-15 dependency footprint (depends on swift-binary-primitives at tier 14 for `Binary Primitives Core` + `Binary Serializable Primitives`). Cannot be the substrate of a coherent baseN family without a wholesale rewrite that is indistinguishable from "ship a new package and archive base62."
- **swift-binary-primitives** [Verified: 2026-05-07]: ships `Binary` namespace (`Sources/Binary Namespace/Binary.swift`), `Binary.Cursor`, `Binary.LEB128`, `Binary.Format`, `Binary.Serializable` — byte-cursor / serialization machinery, not text encoding. Conceptually adjacent but algorithmically independent (encoding bytes-to-text doesn't need a Cursor). Adding baseN to this package would widen its mission from "binary data manipulation" to "...and text encodings."
- **No other package** in the ecosystem implements base16, base32, base58, base64, base85, RFC 4648, Bitcoin base58, Z85, or Ascii85. [Verified: 2026-05-07 via `find /Users/coen/Developer -maxdepth 3 -type d -iname "*base*"`].

The compose-existing-primitives path does not exist. This is a genuine gap.

### Second-consumer check

The proposed `Binary.Base.\`N\`` mechanism has multiple independent consumers:

| Consumer | Use |
|----------|-----|
| `swift-binary-base-primitives` itself | Hosts non-spec alphabets (base62 standard/gmp, base58, base85 z85) |
| `swift-ietf/swift-rfc-4648` (new, this Doc) | Hosts RFC 4648 §4/§5/§6/§7/§8 alphabets |
| `swift-bitcoin` org (future) | Hosts Bitcoin base58 alphabet — Bitcoin addresses, BIP-39 mnemonic encoding |
| `swift-zmq` org (future, hypothetical) | Hosts ZeroMQ Z85 base85 alphabet |
| Adobe / PostScript-related (future, hypothetical) | Hosts Ascii85 base85 alphabet for PDF |
| Legacy `swift-base62-primitives` consumers (during migration) | Replace `Base62_Primitives.<call>` with `Binary.Base.\`62\`.encode(...)` |

Three independent immediate consumers (the primitives package, the RFC-4648 package, and replacement of the legacy base62 package), plus three near-term consumers (Bitcoin, ZeroMQ, PDF). Far above the [RES-018] hurdle of "at least one independent consumer beyond the originating investigation."

## Analysis

### Options Enumerated

#### Option A — Value-generic `Binary.Base<let N: Int>` (REJECTED)

```swift
public struct Base<let N: Int>: Sendable, Hashable {
    public let codeUnits: [UInt8]
    public let pad: UInt8?
}
extension Binary.Base where N == 16 {
    public static let rfc4648: Binary.Base<16> = .init(codeUnits: ...)
    public func encode(_ bytes: borrowing [UInt8]) -> String { ... }
}
```

Use: `Binary.Base<16>.rfc4648.encode(bytes)`.

**Empirical:** [Verified: 2026-05-07] Confirmed mechanically in experiment `binary-base-n-poc/Sources/BinaryBase/BinaryBase.swift` (V1–V5).

**Refuted:**

- `Binary.Base<23456789>` compiles (no encode methods reachable, but the type instantiates). The radix axis is closed by binary→text encoding mathematics; allowing arbitrary `Int` values is the wrong type-system contract.
- `where N == 16 || N == 32 || N == 64` is rejected at parse time on Swift 6.3.1 (`error: expected '{' in extension` at `||`). Not `#if`-rescuable. Multi-radix shared API requires per-radix repetition or an algorithm-witness protocol.

#### Option B — Closed-radix `Binary.Base.\`N\`` nested types (FOUNDATION)

```swift
public enum Binary {}
extension Binary { public enum Base {} }
extension Binary.Base {
    public struct `16`: Sendable, Hashable {
        public let codeUnits: [UInt8]
        public let pad: UInt8?
    }
    public struct `32`: Sendable, Hashable { ... }
    public struct `62`: Sendable, Hashable { ... }
    // ... 58, 64, 85
}
extension Binary.Base.`16` {
    public static let rfc4648: Self = .init(codeUnits: ...)
    public func encode(_ bytes: borrowing [UInt8]) -> String { ... }
}
```

Use: `Binary.Base.\`16\`.rfc4648.encode(bytes)`.

**Empirical:** [Verified: 2026-05-07] Confirmed in experiment `binary-base-n-poc/Sources/BinaryBaseClosed/` (V6).

**Properties:**

- Closed radix axis: `Binary.Base.\`23456789\`` is a compile error.
- Each radix is a distinct nominal type per [API-NAME-001a]; `Binary.Base` is a multi-sibling-type namespace.
- Mirrors `Windows.\`32\`` precedent from [PLAT-ARCH-008k]: backticked-digit nested types are the institute's existing pattern for "spec-name-with-leading-digit" sub-namespaces.
- Algorithm dispatch lives on per-type extensions; no `||`-in-where-clause grammar problem.

**Limitation:** The witness step (`.rfc4648.encode`) is overhead for radixes with a single canonical alphabet (only base16). Asymmetric perception when reading the family side-by-side.

#### Option C — Static methods on type with sub-namespaces (REJECTED in pure form)

```swift
extension Binary.Base.`16` {
    public static func encode(_ bytes: ...) -> String { /* §8 */ }
}
extension Binary.Base.`32` {
    public static func encode(_ bytes: ...) -> String { /* §6 default */ }
    public enum Hex {}
}
extension Binary.Base.`32`.Hex {
    public static func encode(_ bytes: ...) -> String { /* §7 */ }
}
```

Use: `Binary.Base.\`16\`.encode(bytes)`, `Binary.Base.\`32\`.Hex.encode(bytes)`.

**Refuted as the primary design:**

- Alphabets stop being first-class values. Configuration patterns like `Logger(encoding: Binary.Base.\`64\`.rfc4648Url)` are not expressible — must layer an enum on top.
- Custom alphabets need a separate API path (no instance to construct).
- Each spec package writes its own encode method calling a shared internal algorithm — duplicate one-line wrappers per spec.
- Choosing the "default" alphabet at the type level (e.g., `Binary.Base.\`32\`.encode` defaults to RFC 4648 §6 over §7 over Crockford) is an institute opinion, not a derived choice — it's fine but the call-site asymmetry is structural.

Option C does, however, capture the *call-site target* — it's clean for base16. The challenge is to hit the same call-site shape *without* losing alphabet-as-value.

#### Option D — Closed-radix + `Property<Tag, Base>` from swift-property-primitives (RECOMMENDED)

```swift
// swift-binary-base-primitives
public import Property_Primitives_Core
extension Binary { public enum Base {} }
extension Binary.Base {
    public struct `16`: Sendable {
        public init() {}
        public enum Encode {}
        public enum Decode {}
    }
    public struct `32`: Sendable {
        public init() {}
        public enum Encode {}
        public enum Decode {}
    }
    // ... 58, 62, 64, 85
}
extension Binary.Base.`16` {
    public static var encode: Property<Encode, Self> { Property<Encode, Self>(.init()) }
    public static var decode: Property<Decode, Self> { Property<Decode, Self>(.init()) }
}

// swift-rfc-4648
extension Property where Tag == Binary.Base.`16`.Encode, Base == Binary.Base.`16` {
    public func callAsFunction(_ bytes: borrowing [UInt8]) -> String { /* RFC 4648 §8 */ }
}
extension Property where Tag == Binary.Base.`32`.Encode, Base == Binary.Base.`32` {
    public func callAsFunction(_ bytes: borrowing [UInt8]) -> String { /* §6 default */ }
    public func hex(_ bytes: borrowing [UInt8]) -> String { /* §7 */ }
}

// Hypothetical third-party swift-crockford-base32
extension Property where Tag == Binary.Base.`32`.Encode, Base == Binary.Base.`32` {
    public func crockford(_ bytes: borrowing [UInt8]) -> String { ... }
}
```

Use sites:
```swift
Binary.Base.`16`.encode(bytes)              // RFC 4648 §8 (callAsFunction)
Binary.Base.`32`.encode(bytes)              // §6 default
Binary.Base.`32`.encode.hex(bytes)          // §7 variant
Binary.Base.`32`.encode.crockford(bytes)    // third-party variant
Binary.Base.`62`.encode(value)              // standard default
Binary.Base.`62`.encode.gmp(value)          // GMP variant
```

**Empirical:** [Verified: 2026-05-07] Confirmed in experiment `binary-base-n-poc/Sources/BinaryBaseProperty/` (V7). Runtime preconditions pass for all six call sites above; cross-module debug + release green per [EXP-017].

**Properties:**

- Inherits all V6 (Option B) properties: closed radix, [API-NAME-001a]-aligned namespace, [PLAT-ARCH-008k] precedent, no grammar problems.
- Adds: cleanest possible call-site syntax via `Property.callAsFunction` for the default alphabet on each radix.
- Adds: open extension across packages via `extension Property where Tag == ..., Base == ...`. SwiftPM target visibility doesn't fragment the namespace; consumers see the union of all extensions of the same Tag.
- Aligns with [API-NAME-008]: multi-form operations under one root MUST use Property.View nested accessors. `encode` is the root; alphabets are sub-operations. This is the canonical institute pattern.
- Custom alphabets: any third-party package can extend `Property where Tag == Binary.Base.\`N\`.Encode` with a `.custom(alphabet:_:)` method or per-name static instance — first-class.

**Cost:**

- Adds a runtime dependency on swift-property-primitives (already a tier-0 package, already public). Acceptable per [PRIM-FOUND-001] — property-primitives is a Foundation-free leaf primitive.
- Each `Property<Encode, Binary.Base.\`16\`>` instance is constructed fresh on each call (`static var encode: Property` returns a new instance). The Property struct is `~Copyable` with `@inlinable` accessors; the optimizer eliminates the construction in release mode. [Verified: 2026-05-07] release build of the experiment passes per `Outputs/release-mode-pass.txt`.

### Comparison Table

| Criterion | A: value-generic | B: closed-radix | C: static-method | D: closed-radix + Property |
|-----------|:----------------:|:---------------:|:----------------:|:--------------------------:|
| Closed radix axis | ❌ accepts `<23456789>` | ✓ | ✓ | ✓ |
| Open alphabet axis (custom) | ✓ first-class | ✓ first-class | ✗ separate API | ✓ first-class |
| Cross-package alphabet ext | ✓ via static let | ✓ via static let | △ via sub-namespace | ✓ via Property tag-extension |
| Call-site for single-alphabet | `Binary.Base<16>.rfc4648.encode(b)` | `Binary.Base.\`16\`.rfc4648.encode(b)` | `Binary.Base.\`16\`.encode(b)` | `Binary.Base.\`16\`.encode(b)` |
| Call-site for multi-alphabet | `<32>.rfc4648Hex.encode(b)` | `\`32\`.rfc4648Hex.encode(b)` | `\`32\`.Hex.encode(b)` | `\`32\`.encode.hex(b)` |
| Multi-radix shared API | ❌ (V2b refuted) | per-radix repetition | per-radix repetition | per-Tag repetition |
| [API-NAME-001a] compliance | ✓ | ✓ | ✓ | ✓ |
| [API-NAME-008] (Property.View) | ✗ | ✗ | ✗ | **✓ canonical match** |
| [PLAT-ARCH-008k] precedent | ✗ | ✓ | ✓ | ✓ |
| Alphabet as first-class value | ✓ | ✓ | ✗ | ✓ |
| External dep | none | none | none | swift-property-primitives (tier-0 leaf, public) |

### Theoretical grounding [per [RES-022]]

The design's correctness rests on three structural axes:

1. **Closed-on-radix / open-on-alphabet** maps to the open-closed principle in OO design (Meyer 1988): packages are closed for modification of the radix set, open for extension along the alphabet axis. The radix axis closes because binary→text encoding has only ~6 mathematically meaningful values (powers of 2 for bit-packing: 2, 4, 8, 16, 32, 64; non-powers-of-2 with curated alphabets in printable ASCII: 58, 62, 85; ~95 printable ASCII characters cap the upper bound). Anything outside this curated set is meaningless. The alphabet axis opens because new conventions (Crockford, Bitcoin, GMP, Z85) emerge from independent communities and must be addable without modifying the mechanism package.

2. **Phantom-typed namespace dispatch** via `Property<Tag, Base>` follows from SE-0452 (Integer Generic Parameters) being the *wrong tool* and the witness pattern being the *right tool* for closed-discriminated-union dispatch. SE-0452 admits arbitrary integer values; the witness pattern admits only what's declared. The institute's `Property<Tag, Base>` is exactly the closed-discriminated-union substrate, with cross-package open extension as a designed feature.

3. **Call-site uniformity via `callAsFunction`** is the SE-0253 (`callAsFunction`) language feature applied to the Property witness. This collapses the "radix-with-default-alphabet" call from `Binary.Base.\`16\`.rfc4648.encode(b)` to `Binary.Base.\`16\`.encode(b)` without losing alphabet-as-value semantics — `encode` IS a Property value, and `callAsFunction` makes it directly callable.

References:

- Meyer, Bertrand. *Object-Oriented Software Construction*. Prentice Hall, 1988. (Open-closed principle.)
- [SE-0452 Integer Generic Parameters](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md).
- [SE-0253 Callable values of user-defined nominal types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0253-callable.md).

### Empirical validation [per [RES-025] cognitive-dimensions on the Recommendation]

| Dimension | Score | Notes |
|-----------|:-----:|-------|
| Visibility | high | Each variant is a distinct method on `Property`; autocomplete on `Binary.Base.\`32\`.encode.` enumerates all known alphabets. |
| Consistency | high | `<radix>.encode(...)` works uniformly for single- and multi-alphabet radixes. |
| Viscosity | low | Adding a new alphabet to an existing radix is one extension block; adding a new radix is one struct + two phantom tags + two static accessors. |
| Role-expressiveness | high | Reading `Binary.Base.\`32\`.encode.crockford(bytes)` immediately discloses domain (Binary), radix (32), operation (encode), variant (crockford). |
| Error-proneness | low | Compile-time radix discrimination (closed radix); compile-time alphabet discrimination (each variant is a distinct method); typed throws on encode/decode. |
| Abstraction | balanced | One mechanism (Property<Tag, Base>) reused across all radix×operation pairs. |

## Architecture

### Package layout

```
swift-binary-base-primitives                                  L1 Primitives
└── tier-0 leaf (deps: Property Primitives + Binary Namespace re-export)
    ├── Sources/Binary Base Primitives Core/
    │   ├── Binary.swift                       (re-export Binary Namespace product)
    │   ├── Binary.Base.swift                  (namespace enum)
    │   ├── Binary.Base.16.swift               (struct + Encode/Decode tags)
    │   ├── Binary.Base.32.swift
    │   ├── Binary.Base.58.swift
    │   ├── Binary.Base.62.swift
    │   ├── Binary.Base.64.swift
    │   ├── Binary.Base.85.swift
    │   ├── Binary.Base.16+Encode.swift        (static accessor)
    │   ├── Binary.Base.16+Decode.swift
    │   └── ... (per-radix accessor pairs)
    └── Sources/Binary Base Primitives/        (umbrella re-export)

swift-binary-base-de-facto-primitives                          L1 Primitives (or L2 if specs apply)
└── Convention-defined alphabets that don't have an RFC home:
    ├── Binary.Base.62.encode.standard         (digits → upper → lower)
    ├── Binary.Base.62.encode.gmp              (GMP convention)
    └── Binary.Base.62.encode.inverted         (lowercase before uppercase)

(Or these ship in swift-binary-base-primitives directly — see "Open question" below.)

swift-ietf/swift-rfc-4648                                      L2 Standards
└── RFC 4648 — The Base16, Base32, and Base64 Data Encodings:
    ├── Binary.Base.16.encode.callAsFunction       (§8 standard hex — only canonical)
    ├── Binary.Base.32.encode.callAsFunction       (§6 standard alphabet)
    ├── Binary.Base.32.encode.hex                  (§7 extended hex alphabet)
    ├── Binary.Base.64.encode.callAsFunction       (§4 standard alphabet)
    └── Binary.Base.64.encode.url                  (§5 URL-safe alphabet)
    + matching .decode extensions for each

swift-bitcoin/swift-base58 (future)                            L2 Standards
└── Binary.Base.58.encode.bitcoin                  (Bitcoin base58)
    Binary.Base.58.encode.ripple                   (Ripple base58)

swift-zmq/swift-z85 (hypothetical)                             L2 Standards
└── Binary.Base.85.encode.z85                      (ZeroMQ Z85)

swift-iso/swift-iso-32000 (existing) or swift-adobe/* (hypothetical)
└── Binary.Base.85.encode.ascii85                  (Adobe Ascii85 for PDF)
```

### Alphabet placement matrix

| Encoding | Alphabet | Authority | Home |
|----------|----------|-----------|------|
| Base16 §8 | `0-9A-F` (uppercase hex) | RFC 4648 | `swift-ietf/swift-rfc-4648` |
| Base32 §6 | `A-Z2-7` | RFC 4648 | `swift-ietf/swift-rfc-4648` |
| Base32 §7 | `0-9A-V` (extended hex) | RFC 4648 | `swift-ietf/swift-rfc-4648` |
| Base32 Crockford | `0123456789ABCDEFGHJKMNPQRSTVWXYZ` (no I L O U) | Crockford spec | `swift-binary-base-primitives` (de facto) OR future `swift-crockford-base32` |
| Base32 z-base-32 | `ybndrfg8ejkmcpqxot1uwisza345h769` | Phil Zimmermann | future `swift-z-base-32` (hypothetical) |
| Base32 Geohash | `0123456789bcdefghjkmnpqrstuvwxyz` | Geohash spec | future `swift-geohash` (hypothetical) |
| Base58 Bitcoin | `123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz` | Bitcoin (de facto) | future `swift-bitcoin/swift-base58` |
| Base58 Ripple | `rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz` | Ripple (de facto) | future Ripple package |
| Base58 Flickr | `123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ` | Flickr (de facto) | future Flickr package |
| Base62 standard | `0-9A-Za-z` | de facto convention | `swift-binary-base-primitives` |
| Base62 GMP | `A-Za-z0-9` | GMP convention | `swift-binary-base-primitives` |
| Base62 inverted | `0-9a-zA-Z` | de facto | `swift-binary-base-primitives` |
| Base64 §4 | `A-Za-z0-9+/` | RFC 4648 | `swift-ietf/swift-rfc-4648` |
| Base64 §5 | `A-Za-z0-9-_` (URL-safe) | RFC 4648 | `swift-ietf/swift-rfc-4648` |
| Base85 RFC 1924 | `0-9A-Za-z!#$%&()*+-;<=>?@^_\`{\|}~` | RFC 1924 | future `swift-ietf/swift-rfc-1924` |
| Base85 Z85 | `0-9a-zA-Z.-:+=^!/*?&<>()[]{}@%$#` | ZeroMQ Z85 | future `swift-zmq/swift-z85` |
| Base85 Ascii85 | `!"#$%&'()*+,-./0-9:;<=>?@A-Z[\]^_\`a-z{\|}~` | Adobe PostScript / PDF | future `swift-iso/swift-iso-32000` extension or own package |

The alphabet placement matrix is the design's open axis: each spec authority owns its alphabet declarations, and any third party can add new alphabets to the same Encode/Decode tag without coordination.

### Migration

#### Phase 1 — Author `swift-binary-base-primitives`

1. Create the new repo at `swift-primitives/swift-binary-base-primitives`.
2. Implement the closed-radix marker structs `Binary.Base.\`16\`` … `\`85\`` per Option D.
3. Implement Encode/Decode phantom tags + static accessors.
4. Implement the per-(radix, algorithm-class) encode/decode mechanism on `Property where Tag == ..., Base == ...`:
   - Bit-packing for radixes 16/32/64 (one shared internal helper).
   - Integer-arithmetic for radixes 58/62/85 (one shared internal helper).
5. Ship non-spec alphabets directly: `Binary.Base.\`62\`.encode.{standard, gmp, inverted}`, `Binary.Base.\`62\`.decode.{...}`.
6. Apply the institute publication checklist (README, CHANGELOG, CI, etc.). Cohort with [RELEASE-*] gates.

#### Phase 2 — Author `swift-ietf/swift-rfc-4648`

1. Create the new repo at `swift-ietf/swift-rfc-4648`.
2. Add path/URL dep on `swift-binary-base-primitives`.
3. Implement RFC 4648 §4/§5/§6/§7/§8 alphabets as `Property` extensions on the corresponding radix's Encode/Decode tags, with `callAsFunction` for the spec-default variant per radix.
4. Apply institute publication checklist.

#### Phase 3 — Archive `swift-base62-primitives`

1. Add a deprecation notice to the legacy package's README pointing at `swift-binary-base-primitives`.
2. Mark the GitHub repo archived. Do not delete (consumers may still resolve historical commits).
3. Remove from the workspace's `.gitmodules` if present.
4. Update the workspace's compute-tiers script to handle the `../../` path-prefix bug surfaced during this Doc's authoring.

#### Phase 4 — Future per-spec packages

Per the alphabet placement matrix, future per-spec packages (`swift-bitcoin/swift-base58`, `swift-zmq/swift-z85`, etc.) ship as independent repos with path/URL dep on `swift-binary-base-primitives` and Property-extension-only contributions. No changes to the mechanism package.

## Open Questions

| # | Question | Recommended resolution |
|---|---|---|
| OQ-1 | Where do non-RFC de-facto alphabets (base62 standard/gmp, base58 Bitcoin) live — in `swift-binary-base-primitives` or per-convention packages? | Ship inside `swift-binary-base-primitives` for the family launch. Migrate to per-convention packages (e.g., `swift-bitcoin/swift-base58`) if/when those orgs exist and want to own the alphabet. The Property-extension shape lets the mechanism package and per-convention packages co-exist on the same tag without conflict; relocation is a one-extension-block move. |
| OQ-2 | Should `Binary.Base.\`N\`` be marked `~Copyable`? | No. Each radix marker is empty (no fields), and consumers expect to treat them as value-typed namespaces, not resources. The `Property<Tag, Base>` instances ARE `~Copyable` but that's internal to the mechanism. |
| OQ-3 | Should the family include `Binary.Base.\`2\``, `\`4\``, `\`8\`` (binary, base4, octal)? | Out of scope for v0.1. These radixes encode at fixed bit boundaries (1/2/3 bits per digit) and are typically expressed via `String(_:radix:)` on integers rather than as multi-byte alphabet encodings. Revisit if a consumer surfaces a need. |
| OQ-4 | Should `decode` use typed throws per [API-ERR-001]? | Yes. `Binary.Base.\`N\`.Decode.Error` per radix (or shared if errors are uniform across radixes) — `.invalidCharacter(UInt8)`, `.invalidLength(Int)`, `.unexpectedPadding`, etc. Detailed error taxonomy deferred to implementation phase. |
| OQ-5 | Does the family handle streaming (encode chunks of N bytes → M chars over a stream)? | Out of scope for v0.1. Bulk byte-array → String / String → byte-array only. Streaming can be added later as additional Property extensions (`encode.streaming(_:into:)`) without breaking the bulk API. |
| OQ-6 | Custom alphabets — is a `Binary.Base.\`N\`(codeUnits:pad:)` initializer needed beyond the static-instance variants? | Yes for the closed-radix shape per V6/V7. Each `Binary.Base.\`N\`` is a struct with `init(codeUnits:pad:)`. The static-instance variants are convenience; custom alphabets are the open-axis path. |

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Adopt Option D — closed-radix `Binary.Base.\`N\`` nested types + `Property<Tag, Base>` from `swift-property-primitives` for call-site dispatch + per-spec packages owning their alphabet declarations.

**Architecture**:

- New: `swift-primitives/swift-binary-base-primitives` (L1 Primitives, tier-0 leaf except for the swift-property-primitives dep).
- New: `swift-ietf/swift-rfc-4648` (L2 Standards, depends on swift-binary-base-primitives).
- Archive: `swift-primitives/swift-base62-primitives` (legacy; replaced by `Binary.Base.\`62\`` in the new package).
- Future: per-spec packages for non-RFC variants (Bitcoin base58, Z85, Ascii85) as independent repos extending the same Encode/Decode tags.

**Empirical basis**: experiment `swift-institute/Experiments/binary-base-n-poc/` (CONFIRMED 2026-05-07; `_index.json` entry for full details).

**Conventions established**:

- `Property<Tag, Base>` from `swift-property-primitives` is the canonical mechanism for *multi-form operation namespaces under one root* per [API-NAME-008] in the institute's primitives layer. Future encoding / parsing / serialization families that share this shape SHOULD use the same pattern.
- Backticked-digit nested types (`Binary.Base.\`N\``, `Windows.\`32\``, future `IP.\`4\``/`IP.\`6\``) are the institute's pattern for *closed numeric variant sets where the variant identifier IS the spec-defined number*. This generalization is worth promoting to a code-surface skill amendment.

## Blog Potential

This research has been captured as blog ideas:
- [BLOG-IDEA-083: Closed by Nature: Why `Binary.Base.\`16\`` Beats `Binary.Base<N>`](../Blog/_index.json) — Technical Deep Dive sourced from V1 + V2b refutation + V6 closed-radix resolution.
- [BLOG-IDEA-084: Property<Tag, Base> at Type Level: Static-Method Witness Dispatch](../Blog/_index.json) — Pattern Documentation sourced from V7 + Option D.

## References

### Internal artifacts

- Experiment: `swift-institute/Experiments/binary-base-n-poc/` (V1–V7 multi-variant POC; CONFIRMED 2026-05-07).
- Skill: `swift-institute/Skills/code-surface/SKILL.md` — [API-NAME-001], [API-NAME-001a], [API-NAME-008].
- Skill: `swift-institute/Skills/platform/SKILL.md` — [PLAT-ARCH-008k] (`Windows.\`32\`` precedent).
- Audit: `swift-institute/Audits/standards-org-migration-plan-audit.md` (2026-04-22 base62 rename).
- Package: `swift-primitives/swift-property-primitives` v0.1.0 (the Property<Tag, Base> mechanism, public 2026-04-30).
- Package (legacy): `swift-primitives/swift-base62-primitives` (private; to be archived per Phase 3).

### External primary sources

- [RFC 4648 — The Base16, Base32, and Base64 Data Encodings](https://datatracker.ietf.org/doc/html/rfc4648)
- [RFC 1924 — A Compact Representation of IPv6 Addresses](https://datatracker.ietf.org/doc/html/rfc1924) (base85)
- [SE-0253 Callable values of user-defined nominal types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0253-callable.md)
- [SE-0452 Integer Generic Parameters](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md)
- [Crockford Base32 spec](https://www.crockford.com/base32.html)
- [ZeroMQ Z85 spec (RFC 32/Z85)](https://rfc.zeromq.org/spec/32/)
- [Bitcoin base58 (Bitcoin Wiki)](https://en.bitcoin.it/wiki/Base58Check_encoding)

### Comparative implementations

- [Rust base64 crate](https://docs.rs/base64/latest/base64/) (Engine-as-witness pattern, closest cross-language analog)
- [Rust hex crate](https://docs.rs/hex/latest/hex/) (top-level functions; single-alphabet special-case observation)
- [Rust bs58 crate](https://docs.rs/bs58/latest/bs58/) (builder pattern for Bitcoin base58)
- [Python `base64` module](https://docs.python.org/3/library/base64.html) (per-variant top-level functions; closest call-site analog)
- [Apple Foundation Data.base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) (base64 only; no broader baseN)
