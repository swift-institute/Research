# Binary Base-N / RFC 4648 Reconciliation

<!--
---
version: 1.0.0
last_updated: 2026-05-07
status: RECOMMENDATION
tier: 2
scope: cross-package
supersedes: binary-base-n-encoding-family-architecture.md (Phase 2 only)
---
-->

## Context

`binary-base-n-encoding-family-architecture.md` v1.0.0 (2026-05-07) shipped Phase 1 successfully — `swift-primitives/swift-binary-base-primitives` is now a private repo with closed-radix `Binary.Base.\`N\`` types, `Property<Tag, Base>` accessors, and v0.1.0 base62 alphabets. Phase 2 of that doc — "create `swift-ietf/swift-rfc-4648`" — turned out to rest on a wrong empirical premise.

**Two corrections drive this follow-up**:

### Correction 1 — `swift-ietf/swift-rfc-4648` already exists and is public

[Verified: 2026-05-07 via `gh api search/repositories?q=org:swift-ietf+rfc-4648`]

```
{
  "full_name": "swift-ietf/swift-rfc-4648",
  "pushed_at": "2026-05-06T08:43:10Z",
  "visibility": "public"
}
```

Local mirror at `~/Developer/swift-ietf/swift-rfc-4648/` shows recent active development:

```
3117583 ci: migrate to L1-uniform thin-caller shape via swift-standards layer wrapper
7b09c4d ci: pin reusable workflows to @main during active CI/CD development
8486d5e Tests: migrate @Test("DESC") func camelCase() to @Test func `DESC`() per /testing
4efed4b Split multi-type files into one-type-per-file [API-IMPL-005]
20b64d5 Replace swift-ascii (L3) with swift-ascii-primitives (L1)
```

The package implements RFC 4648 with a structurally different shape than the original Phase 2 plan:

| Existing public surface | Original Phase 2 plan |
|-------------------------|----------------------|
| `RFC_4648.Base16.encode(bytes, into: &buffer)` | `Binary.Base.\`16\`.encode(bytes)` |
| `RFC_4648.Base32.encode(bytes)` | `Binary.Base.\`32\`.encode(bytes)` |
| `RFC_4648.Base32.Hex.encode(bytes)` | `Binary.Base.\`32\`.encode.hex(bytes)` |
| `RFC_4648.Base64.encode(bytes)` | `Binary.Base.\`64\`.encode(bytes)` |
| `RFC_4648.Base64.URL.encode(bytes)` | `Binary.Base.\`64\`.encode.url(bytes)` |
| `String(base64Encoding: bytes)` (extension init) | not in plan |
| `String(hexEncoding: bytes)` (extension init) | not in plan |
| `Encoder` per radix supporting `String.hex(bytes)` syntax | not in plan |

The original v1.0.0 doc claimed `[Verified: 2026-05-07] No swift-ietf/swift-rfc-4648 repo exists` — that verification was unreliable. The follow-up rule for [RES-023] (Empirical-Claim Verification) applies: empirical claims about external state must be verified against primary sources at write time. The claim was wrong; the doc is amended below.

### Correction 2 — User-clarified architectural principle

> "Standards are encoded as literally to the spec as they are, and they use primitives as their building blocks. Primitives don't add to standards; primitives are USED to encode the standard. However, this does not preclude us from providing the envisioned base public API as well."

The original v1.0.0 doc inverted this — it had RFC alphabets as Property extensions ON the primitives package's `Binary.Base.\`N\`.Encode` tag. That's "RFC adds to primitives," which is the wrong direction. Per the institute's three-tier pattern (swift-ascii-primitives → swift-incits-4-1986 → swift-ascii), the correct flow is:

```
L1 primitives ────────► provides building blocks
                           │
                           │ used by
                           ▼
L2 standards     ──────► encodes the spec literally,
                          delegating algorithms to L1
                           │
                           │ composed by
                           ▼
L3 unifier (optional) ──► ergonomic envisioned API
                          composing L1 mechanism + L2 spec defaults
```

## Question

How does `swift-binary-base-primitives` (L1, just shipped) relate to the existing `swift-ietf/swift-rfc-4648` (L2, public), and where does the "envisioned base public API" (`Binary.Base.\`N\`.encode(bytes)` style call sites with RFC defaults) live?

## Internal prior art — the swift-ascii three-tier model

[Verified: 2026-05-07 against package sources]

The institute already has the canonical example of this pattern at the ASCII layer:

### L1 — `swift-primitives/swift-ascii-primitives`

Atomic ASCII concepts: `ASCII.Byte`, `ASCII.Char`, `ASCII.Classification`, `ASCII.CaseConversion`, etc. Owned, defined, named by the institute. Foundation-free. Tier-0 leaf.

### L2 — `swift-incits/swift-incits-4-1986`

The INCITS 4-1986 spec (the formal authority for ASCII as a US standard) encoded literally:

```swift
// Spec-namespace
extension INCITS_4_1986 { /* spec-defined types */ }
extension INCITS_4_1986.ASCII where Source: Collection, Source.Element == UInt8 { /* methods */ }
extension INCITS_4_1986.ASCII where Source: StringProtocol { /* methods */ }
```

Implementation pattern observed in `INCITS_4_1986.ASCII.swift` and `Collection+INCITS_4_1986.ASCII.swift`:

```swift
// Standard delegates to L1 primitive for the algorithm:
ASCII_Primitives.ASCII.convert(bytes, to: `case`)
ASCII_Primitives.ASCII.convert(string, to: `case`)
ASCII.Classification.isAllWhitespace(source)
ASCII.Classification.isAllDigits(source)
```

The L2 spec package owns the spec-mirrored namespace (`INCITS_4_1986.ASCII`) and the spec-defined methods. The algorithms live at L1 (`ASCII_Primitives.ASCII.convert`, `ASCII.Classification.isAllWhitespace`); L2 delegates.

### L3 — `swift-foundations/swift-ascii`

Composes L1 + L2 into the ergonomic public API. Depends on `swift-incits-4-1986` (the standard) AND on multiple primitives (binary, parser, serializer, etc.). Provides `ASCII.Byte` extensions and a unified consumer surface that pulls from both layers.

This is the canonical pattern. Apply it to the binary base-N family.

## Mapping to binary-base-N

| Tier | Package | Role |
|------|---------|------|
| **L1** | `swift-primitives/swift-binary-base-primitives` (already shipped 2026-05-07) | Owns `Binary.Base.\`N\`` closed-radix types + Encode/Decode tags + parameterized algorithms (bit-pack for 16/32/64; integer for 58/62/85). Ships the convention base62 alphabets (no spec authority). |
| **L2** | `swift-ietf/swift-rfc-4648` (already public; refactor needed) | Owns `RFC_4648.Base16`, `RFC_4648.Base32`, `RFC_4648.Base32.Hex`, `RFC_4648.Base64`, `RFC_4648.Base64.URL` per spec terminology. Encoding methods take the RFC-defined alphabets. Algorithm execution DELEGATES to `Binary.Base.\`N\``. |
| **L2** (future) | `swift-bitcoin/swift-base58`, `swift-zmq/swift-z85`, etc. | Each non-RFC convention spec gets its own L2 package, delegating to L1's `Binary.Base.\`58\`` / `\`85\`` algorithms. |
| **L3** (future, optional) | `swift-foundations/swift-binary-base` (or similar) | Composes L1 + L2 specs into the "envisioned base public API" — `Binary.Base.\`16\`.encode(bytes)` style call sites with RFC defaults baked in via Property extensions. |

## What changes in `swift-ietf/swift-rfc-4648`

The current package has its own algorithm implementations duplicated per radix. Under the reconciled architecture:

### Add: dependency on `swift-binary-base-primitives`

Once `swift-binary-base-primitives` is public + tagged, swift-rfc-4648 adds it as a dependency.

### Refactor: each Encoder/decoder body delegates to L1

Current shape (algorithm inline in L2):

```swift
extension RFC_4648.Base16 {
    public static func encode<Bytes: Collection>(...) -> [UInt8]
    where Bytes.Element == UInt8 {
        // Bit-packing 4 bits/digit, alphabet "0123456789abcdef" inline
        var out: [UInt8] = []
        for byte in bytes {
            out.append(alphabet[Int(byte >> 4)])
            out.append(alphabet[Int(byte & 0x0F)])
        }
        return out
    }
}
```

Reconciled shape (algorithm delegated to L1):

```swift
extension RFC_4648.Base16 {
    /// RFC 4648 §8 alphabet — uppercase hex.
    public static let alphabet: [UInt8] = Array("0123456789ABCDEF".utf8)

    public static func encode<Bytes: Collection>(_ bytes: Bytes, uppercase: Bool = true) -> String
    where Bytes.Element == UInt8 {
        let alpha = uppercase ? alphabet : Array("0123456789abcdef".utf8)
        return Binary.Base.`16`.encode(Array(bytes), alphabet: alpha)
    }
}
```

The public API surface of swift-rfc-4648 stays the same; only the implementation changes. Existing consumers (`String(base64Encoding:)`, `RFC_4648.Base32.encode(...)`) keep working.

### Keep: extension inits + Encoder syntax

The String / Array extension inits (`String(base64Encoding:)`, `[UInt8](hexEncoded:)`) and the `Encoder` callable types stay — they're the consumer-facing ergonomics specific to RFC 4648's spec sections. They become thin wrappers over the delegated algorithm.

### Drop: duplicated algorithm code

The bit-packing and integer-encoding algorithms currently in L2 become dead code once delegation lands. Audit + remove.

## What changes in `swift-binary-base-primitives`

### v0.1.0 (already shipped) — no change

The L1 package as shipped is correct. It owns the mechanism, the radix vocabulary, the algorithms, and the convention alphabets (base62 standard/gmp/inverted).

### v0.2.0 (no urgency) — optional improvements

Considerations for a future revision:

| Question | Direction |
|----------|-----------|
| Should L1 ship a top-level encode/decode for base16/32/64 with NO RFC alphabet baked in? | Already done — the parameterized `(input, alphabet:)` overload is the L1 public surface; consumers either supply alphabet or use L2 for spec-default behavior. |
| Should L1 ship base58 / base85 default alphabets? | NO — defer to per-spec packages (Bitcoin / Z85 / Ascii85 / RFC 1924). Match the principle: spec-defined alphabets live with the spec. |
| Should L1 expose a Foundation-free String⇄Span byte path? | Defer — current `[UInt8]`/`String` interface is the v0.1.0 surface; revisit if downstream needs Span-level efficiency. |

## The "envisioned base public API"

The user's note explicitly preserved this: `Binary.Base.\`16\`.encode(bytes)` style call sites should still be available. Per the L1/L2/L3 pattern, this lives in **L3**, not L1 or L2.

### Where it would live

A future `swift-foundations/swift-binary-base` (the L3 unifier, analogous to `swift-foundations/swift-ascii`) would depend on:

- `swift-binary-base-primitives` (L1)
- `swift-rfc-4648` (L2 — RFC alphabets)
- `swift-bitcoin/swift-base58` (L2, when it exists)
- `swift-zmq/swift-z85` (L2, when it exists)
- … and other spec packages as they ship

And declare the Property extensions providing the envisioned call-site shape:

```swift
// In hypothetical swift-foundations/swift-binary-base
extension Property where Tag == Binary.Base.Encode, Base == Binary.Base.`16` {
    /// Default to RFC 4648 §8 (the only canonical base-16 alphabet).
    public func callAsFunction(_ bytes: borrowing [UInt8]) -> String {
        callAsFunction(bytes, alphabet: RFC_4648.Base16.alphabet)
    }
}

extension Property where Tag == Binary.Base.Encode, Base == Binary.Base.`32` {
    /// Default to RFC 4648 §6 standard.
    public func callAsFunction(_ bytes: borrowing [UInt8]) -> String {
        callAsFunction(bytes, alphabet: RFC_4648.Base32.alphabet, pad: 0x3D)
    }
    public func hex(_ bytes: borrowing [UInt8]) -> String {
        callAsFunction(bytes, alphabet: RFC_4648.Base32.Hex.alphabet, pad: 0x3D)
    }
    // future: .crockford, .zbase32 from their own packages
}

extension Property where Tag == Binary.Base.Encode, Base == Binary.Base.`64` {
    public func callAsFunction(_ bytes: borrowing [UInt8]) -> String {
        callAsFunction(bytes, alphabet: RFC_4648.Base64.alphabet, pad: 0x3D)
    }
    public func url(_ bytes: borrowing [UInt8]) -> String {
        callAsFunction(bytes, alphabet: RFC_4648.Base64.URL.alphabet)
    }
}
```

Consumer experience:

```swift
import Binary_Base                      // L3 — the envisioned API

Binary.Base.`16`.encode(bytes)          // → RFC 4648 §8 hex
Binary.Base.`32`.encode(bytes)          // → RFC 4648 §6 standard
Binary.Base.`32`.encode.hex(bytes)      // → RFC 4648 §7 extended hex
Binary.Base.`64`.encode(bytes)          // → RFC 4648 §4 standard
Binary.Base.`64`.encode.url(bytes)      // → RFC 4648 §5 URL-safe
Binary.Base.`62`.encode(value)          // → swift-binary-base-primitives standard alphabet
```

vs. consumers reaching for spec-literal:

```swift
import RFC_4648                         // L2 — the spec encoding

RFC_4648.Base16.encode(bytes)
RFC_4648.Base32.Hex.encode(bytes)
RFC_4648.Base64.URL.encode(bytes)
String(base64Encoding: bytes)           // extension init — consumer ergonomics
```

Both surfaces coexist. Consumers pick the one matching their mental model.

### Why L3, not L1 or L2

- **Not L1**: L1 must be Foundation-free AND spec-free. Hardcoding "base16 default alphabet is RFC 4648 §8" in L1 would couple L1 to a specific spec. L1 stays generic — it provides the mechanism; spec authorities provide the alphabets.
- **Not L2**: L2 (swift-rfc-4648) is the spec encoding. Adding `Property` extensions to L1's `Binary.Base.\`N\`.Encode` tag from L2 would be the wrong dependency direction (L2 adding to L1's Property surface = a primitives consumer extending the primitives namespace from outside, which works mechanically but breaks the "primitives are USED, not extended" rule).
- **L3 is the right home**: L3 unifiers' job IS composing multiple specs + primitives into ergonomic APIs. The "default RFC 4648 §6 for base32" decision lives at L3 because it's an opinionated composition decision, not a spec fact.

## Phase plan, revised

### Phase 1 ✓ COMPLETE

`swift-primitives/swift-binary-base-primitives` shipped 2026-05-07 (private; awaits visibility/tag authorization). v0.1.0 surface: closed-radix mechanism + base62 convention alphabets.

### Phase 2 — REVISED

**Was**: Create `swift-ietf/swift-rfc-4648` with Property-extension-based RFC alphabets.

**Now**: Refactor existing `swift-ietf/swift-rfc-4648` to delegate algorithms to `swift-binary-base-primitives`. Public API surface unchanged. Implementation switches from inline algorithms to L1 delegation. Requires per-package coordination since the repo is public — ABI compatibility must be preserved through the refactor.

Phase 2 sub-steps (proposed):

1. **2a — alphabet exposure**: add `public static let alphabet: [UInt8]` to each `RFC_4648.Base{16,32,64}`, `RFC_4648.Base32.Hex`, `RFC_4648.Base64.URL`. The L3 unifier (Phase 4) consumes these. No API break.
2. **2b — gate on swift-binary-base-primitives going public**: this Phase blocks until L1 ships at a public, tagged version that L2 can depend on.
3. **2c — internal-implementation delegation**: replace inline algorithms with `Binary.Base.\`N\`.encode(bytes, alphabet: Self.alphabet, …)` delegation. Verify byte-for-byte output equivalence with snapshot tests.
4. **2d — drop duplicated algorithm code**: post-delegation cleanup pass.

Phase 2's blocking dependency is L1's public release. Cannot proceed while L1 is private.

### Phase 3 — Archive `swift-base62-primitives`

Unchanged. Awaits per-action authorization.

### Phase 4 — NEW: L3 unifier `swift-foundations/swift-binary-base`

The "envisioned base public API" lives here. Depends on swift-binary-base-primitives + swift-rfc-4648 (+ future swift-base58, swift-z85, etc.). Provides `Binary.Base.\`N\`.encode(bytes)` style call sites with spec-default alphabets.

Defer until at least swift-rfc-4648 (post-Phase-2 refactor) is the substrate to compose against. Optional package — consumers who want spec-literal use L2 directly; consumers who want the unified API use L3.

## Outcome

**Status**: RECOMMENDATION

**Action items**:

1. **Amend `binary-base-n-encoding-family-architecture.md`** with a status note pointing at this follow-up. The original's Phase 2 section is superseded; Phase 1 stands; Phases 3+ revised below.
2. **Phase 2 stays gated** on swift-binary-base-primitives public release. No code changes to swift-ietf/swift-rfc-4648 until L1 is public + tagged + the L2 dependency is mechanically resolvable.
3. **Phase 4 (L3 unifier) added** as a future package, scope-deferred. The "envisioned base public API" plan is preserved but relocated.

**No new code lands in this Doc's scope** — this is a reconciliation analysis. Implementation phases 2 / 3 / 4 each require separate per-action authorization.

## Blog Potential

This research has been captured as a blog idea:
- [BLOG-IDEA-085: Standards Delegate to Primitives, Not the Other Way Around](../Blog/_index.json) — Pattern Documentation sourced from this reconciliation. The directional discipline (specs use primitives, not vice versa) generalizes the no-upward-dependencies layer rule to per-feature design.

## References

### Internal artifacts

- Primary: `swift-institute/Research/binary-base-n-encoding-family-architecture.md` (v1.0.0, 2026-05-07) — the original research doc this supersedes the Phase 2 section of.
- Experiment: `swift-institute/Experiments/binary-base-n-poc/` (V1–V7 CONFIRMED 2026-05-07).
- Phase 1 implementation: `swift-primitives/swift-binary-base-primitives` (private, 2026-05-07).
- Pattern reference (L1): `swift-primitives/swift-ascii-primitives` (`ASCII` namespace + `ASCII.Classification`, `ASCII.CaseConversion` algorithms).
- Pattern reference (L2): `swift-incits/swift-incits-4-1986` (`INCITS_4_1986.ASCII` spec namespace + `ASCII_Primitives.ASCII.convert(...)` delegation).
- Pattern reference (L3): `swift-foundations/swift-ascii` (composes both into ergonomic API).
- Existing L2 (the subject): `swift-ietf/swift-rfc-4648` — public, recently refactored for [API-IMPL-005] one-type-per-file split, ASCII-primitives integration, `[Verified: 2026-05-07 last push 2026-05-06T08:43:10Z]`.

### Skills + conventions

- [API-NAME-003] Specification-Mirroring Names — `RFC_4648.Base{16,32,64}` mirrors RFC terminology directly.
- [PLAT-ARCH-001] / [PLAT-ARCH-012] — five-layer architecture; "vocabulary / spec / composition" principle.
- [API-NAME-008] — multi-form operations under one root MUST use Property.View nested accessors. The L3 unifier (Phase 4) IS the Property.View surface.
- [RES-023] Empirical-Claim Verification — drove the original v1.0.0 doc's "no rfc-4648 repo" claim being caught and corrected here.

### External

- [RFC 4648 — The Base16, Base32, and Base64 Data Encodings](https://datatracker.ietf.org/doc/html/rfc4648).
- [INCITS 4-1986 — ASCII (American Standard Code for Information Interchange)](https://www.incits.org/) — precedent for the spec-literal L2 pattern.
