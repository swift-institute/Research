# ASCII Parsing Domain Ownership: Adversarial Review

<!--
---
version: 2.0.0
last_updated: 2026-03-04
status: RECOMMENDATION
tier: 2
---
-->

## Context

This document is a formal adversarial review of [ascii-parsing-domain-ownership.md](ascii-parsing-domain-ownership.md). v1.0.0 reviewed v4.0.0; this v2.0.0 reviews v4.1.0, which incorporated several revisions in response to the initial review.

### Methodology

[RES-004] Same as v1.0.0: each claim verified against source code. For v2.0.0, three additional verification passes were conducted:

1. **Three/four-protocol design**: Verified all parser-primitives capability protocols exist
2. **LEB128 serialization**: Verified whether LEB128 has a serialization counterpart
3. **Standards naming convention**: Verified all cited prior art types and surveyed naming patterns

### What v4.1.0 Changed

| v1.0.0 Recommendation | v4.1.0 Response |
|------------------------|-----------------|
| Drop `.Parser` suffix | REJECTED — new "domains as namespaces" principle |
| Address `Binary.ASCII.Serializable` | ACCEPTED — explicit scope-out with cross-reference |
| Defer `swift-ascii-parser` (L3) | ACCEPTED — Machine IR stays in swift-ascii |
| Add embedded Swift experiment | ACCEPTED — claims softened to "unverified" |
| Correct `.ascii` wrapper characterization | ACCEPTED — overload differences acknowledged |

The primary remaining disagreement is **Claim 3: naming**. v4.1.0 introduces new arguments that require independent verification.

---

## Claim 1: A New Package Is Necessary

### v4.1.0 Changes

- Acknowledged the package is thin (3-4 files) compared to the 8-target reference
- Added the caveat that it's "justified if the domain grows"
- Explicitly noted the convention/technical distinction for Option B

### Reassessment

v4.1.0 adequately addresses the original concerns. The trade-off is now honestly presented. No further challenge.

### Verdict: CONFIRMED (revised from QUALIFIED)

The revisions make a fair case. The new package is defensible on architectural grounds, and the trade-offs are honestly stated.

---

## Claim 2: Binary.ASCII Is Redundant with ASCII.Byte

### v4.1.0 Changes

- Acknowledged Character-level API gap
- Noted that stdlib extensions survive struct elimination
- Explicitly scoped out `Binary.ASCII.Serializable` migration with cross-reference to future `ascii-serialization-migration.md`
- Removed "deprecated" characterization for retained serialization protocols

### Reassessment

v4.1.0 adequately addresses the original concerns. The Serializable scope-out is explicit and honest. The Character-level API is acknowledged as surviving struct elimination. No further challenge.

### Verdict: CONFIRMED (revised from QUALIFIED)

The struct is redundant for classification. The namespace survives for serialization. The scope boundary is clear.

---

## Claim 3: Subject-First Naming — `ASCII.Decimal.Parser` Is Correct

This is the primary remaining disagreement. v4.1.0 introduces a new design principle and new evidence. Both require verification.

### v4.1.0's New Argument: "Domains as Namespaces, Capabilities as Nested Types"

The document argues:
1. Domain namespaces should not be consumed by a single capability type
2. When a domain has multiple capabilities (parsing, serialization, printing), each should be a nested type
3. `Binary.LEB128.Unsigned` is a "degenerate case" — LEB128 has "no serialization counterpart"
4. `ASCII.Decimal` is bidirectional (60+ serialization conformances) — therefore the namespace must stay open
5. The four-protocol design (`Parser.Protocol`, `.Serializer`, `.Printer`, `.ParserPrinter`) requires open namespaces

### Verification Results

#### Finding 1: parser-primitives has FOUR protocols, not three

The v4.1.0 document references three protocols. Verification reveals four:

| Protocol | File | Purpose |
|----------|------|---------|
| `Parser.Protocol` | `Parser.Parser.swift` | Consuming: input → value |
| `Parser.Serializer` | `Parser.Serializer.swift` | Appending: value → buffer |
| `Parser.Printer` | `Parser.Printer.swift` | Prepending: value → input |
| `Parser.ParserPrinter` | `Parser.ParserPrinter.swift` | Bidirectional: parsing + printing |

All four are confirmed real. The structural argument is stronger than stated — four protocols, not three.

#### Finding 2: Binary.LEB128 DOES have a serialization counterpart

The v4.1.0 document states: "No `Binary.LEB128.Serializer` exists. LEB128 is a one-directional encoding format."

This is **factually incorrect**. LEB128 serialization exists in `swift-binary-primitives`:

**File**: `/Users/coen/Developer/swift-primitives/swift-binary-primitives/Sources/Binary Primitives Core/Binary.LEB128.Serialize.swift`

```swift
extension [UInt8] {
    public init<T: UnsignedInteger>(leb128 value: T) { ... }
    public init<T: SignedInteger>(leb128 value: T) { ... }
}
extension ContiguousArray<UInt8> {
    public init<T: UnsignedInteger>(leb128 value: T) { ... }
    public init<T: SignedInteger>(leb128 value: T) { ... }
}
```

LEB128 is bidirectional:
- **Parsing**: `Binary.LEB128.Unsigned<T>` / `Binary.LEB128.Signed<T>` (in binary-parser-primitives)
- **Serialization**: `[UInt8](leb128: value)` (in binary-primitives)

The serialization is implemented as collection initializers rather than as a `Parser.Serializer` conformer, but the *capability* exists. The claim that LEB128 is a "one-directional encoding format" is wrong.

#### Finding 3: The "degenerate case" argument is weakened but not destroyed

While LEB128 serialization exists, there is a meaningful structural difference:

| Property | Binary.LEB128 | ASCII.Decimal |
|----------|---------------|---------------|
| Serialization exists? | Yes (`[UInt8](leb128:)`) | Yes (`ASCII.Serialization.serializeDecimal`) |
| Serialization location | Lower layer (binary-primitives, Tier 14) | Lower layer (ascii-primitives, Tier 0) |
| L3 serialization protocol? | No | Yes (`Binary.ASCII.Serializable`, 60+ conformances) |
| Would benefit from `.Serializer` sibling? | Unclear — initializers suffice | Plausible — protocol conformances suggest structured approach |

The real difference is not "unidirectional vs bidirectional" but "simple serialization via initializers vs complex serialization via protocol with 60+ conformances." This is a valid distinction, but the document's characterization of LEB128 as having "no serialization counterpart" is factually wrong and should be corrected.

#### Finding 4: Standards prior art is confirmed but reveals a convention split

All three cited types are real, production code:
- `HTTP.MediaType.Parser<Input>` — noun form
- `ISO_8601.DateTime.Parse<Input>` — verb form
- `RFC_3986.URI.Scheme.Parse<Input>` — verb form

A full survey of 47 `Parser.Protocol` conformances across swift-standards reveals:

| Convention | Count | Examples |
|------------|-------|---------|
| `.Parse` (verb) | 22 | `ISO_8601.DateTime.Parse`, `RFC_3986.URI.Scheme.Parse`, `RFC_5322.DateTime.Parse` |
| `.Parser` (noun) | 25 | `HTTP.MediaType.Parser`, `HTTP.Parse.Token`, `HTTP.Parse.OWS` |

The convention is split nearly 50/50. The v4.1.0 document claims `.Parser` (noun) is "the correct convention" but acknowledges the `.Parse` vs `.Parser` tension as an open item. This is honest, but the claim of correctness is weakened by the empirical split.

Additionally, the `.Parser` count of 25 is inflated by `HTTP.Parse.*` types (e.g., `HTTP.Parse.Token`, `HTTP.Parse.OWS`), which use a **capability-first** namespace (`HTTP.Parse`), not the **subject-first** pattern the document recommends. Excluding these capability-first types, the noun-form subject-first types number closer to 15 — fewer than the 22 verb-form instances.

#### Finding 5: The four-protocol argument IS structurally compelling

The existence of four capability protocols (`Protocol`, `Serializer`, `Printer`, `ParserPrinter`) means a domain namespace SHOULD be able to host multiple capability types. If `ASCII.Decimal` is the parser struct itself, there is no clean place for a future `ASCII.Decimal.Serializer` or `ASCII.Decimal.Printer` — you would need:

```swift
// Awkward: generic struct as both parser AND namespace for sibling capabilities
struct Decimal<Input, T> { } // IS the parser
extension ASCII.Decimal {
    struct Serializer<T> { } // Nested inside a generic parser struct?
}
```

While Swift allows this (SE-0404), it creates a conceptual asymmetry: the parser is the *parent* type, and the serializer is *nested inside the parser*. This implies a parser-centric hierarchy, which is backwards — the domain (decimal representation) should be the parent.

The empty enum namespace pattern avoids this:

```swift
enum Decimal { }
extension ASCII.Decimal {
    struct Parser<Input, T> { }   // sibling
    struct Serializer<T> { }      // sibling
    enum Error { }                // sibling
}
```

This is the stronger argument for the `.Parser` suffix, and it holds even though LEB128 has serialization — LEB128 simply hasn't needed the namespace capacity *yet*, and its serialization is simple enough to be expressed as collection initializers.

### Verdict: QUALIFIED → narrowed

The v4.1.0 naming argument is substantially stronger than v4.0.0's analogy-based argument. The four-protocol design and the structural need for sibling capabilities provide genuine justification for `ASCII.Decimal.Parser`.

However, two corrections are needed:

1. **LEB128 serialization exists.** The claim "No `Binary.LEB128.Serializer` exists. LEB128 is a one-directional encoding format" is factually wrong. It should say: "LEB128 serialization exists as collection initializers (`[UInt8](leb128:)`) at a lower layer, but does not use a `Parser.Serializer` conformer. The encoding is simple enough to not need the structured namespace capacity that ASCII decimal — with 60+ protocol-based serialization conformances — requires."

2. **Standards convention is split.** The document should acknowledge the 22/25 split between `.Parse` and `.Parser` rather than presenting `.Parser` as the settled convention. The open item already flags this, but the analysis body implies stronger consensus than exists.

With these corrections, the naming argument holds. The structural need for an open namespace (four capability protocols, bidirectional domain, future `.Serializer` possibility) is a genuine justification — not just an analogy.

---

## Claim 4: .ascii Wrappers Are Redundant

### v4.1.0 Changes

Corrected the characterization from "identical behavior" to "similar functionality" with explicit acknowledgment of StringProtocol and Memory.Contiguous.Protocol overloads.

### Reassessment

Adequately addressed. No further challenge.

### Verdict: CONFIRMED (revised from QUALIFIED)

---

## Claim 5: Machine IR Is Over-Engineering

### v4.1.0 Changes

- Corrected "closure boxing" to "one-time setup cost"
- Softened embedded Swift claims
- Machine IR retained in swift-ascii under corrected namespace

### Reassessment

Adequately addressed. No further challenge.

### Verdict: CONFIRMED (revised from QUALIFIED)

---

## Claim 6: Embedded Swift Compatibility Matters

### v4.1.0 Changes

Claims softened to "Likely compatible (unverified)" and "Likely incompatible (unverified)." Experiment added to Open Items.

### Reassessment

Adequately addressed. The document no longer uses unverified claims as decision criteria — they're architectural expectations, not assertions. No further challenge.

### Verdict: CONFIRMED (revised from INSUFFICIENT EVIDENCE)

The framing is now honest. Embedded compatibility is noted as unverified.

---

## Claim 7: Machine IR Stays in swift-ascii

### v4.1.0 Changes

Accepted the deferral recommendation. Machine IR stays in swift-ascii under corrected namespace. L3 package created on demand.

### Reassessment

This is exactly what v1.0.0 recommended. No further challenge.

### Verdict: CONFIRMED (revised from QUALIFIED)

---

## Claim 8: Drop parser-primitives from swift-ascii

### v4.1.0 Changes

Revised to: drop `parser-primitives`, *retain* `binary-parser-primitives` (for Machine IR). The original v4.0.0 dropped both.

### Reassessment

This is a pragmatic change. swift-ascii retains `binary-parser-primitives` because the Machine IR code (now kept in swift-ascii) needs `Binary.Bytes.Machine`. The dep drops only when Machine IR is eventually extracted.

One note: the package ecosystem diagram shows `binary-parser-primitives` retained, but the v4.0.0 version showed it dropped. The dependency table in v4.1.0 is consistent with the Machine IR retention decision. No concern.

### Verdict: CONFIRMED (unchanged)

---

## New Claim (v4.1.0): "Domains as Namespaces, Capabilities as Nested Types" as Design Principle

### Statement

v4.1.0 introduces a new formalized principle:

> Domain namespaces (empty enums) SHOULD NOT be consumed by a single capability type. When a domain has — or may have — multiple capabilities (parsing, serialization, printing), each capability SHOULD be a nested type within the domain namespace.

With a degenerate exception for parsing-only domains.

### Evidence For

- Four capability protocols exist (`Parser.Protocol`, `.Serializer`, `.Printer`, `.ParserPrinter`), confirming that domains may need to host multiple capability types.
- ASCII decimal IS bidirectional — serialization exists at L0 (`ASCII.Serialization.serializeDecimal`), at L3 (`Binary.ASCII.Serializable` with 60+ conformances), and a `Binary.ASCII.Decimal` namespace already contains both parsing functions and error types.
- The empty enum pattern (`ASCII.Decimal { }` with nested `.Parser`, `.Serializer`, `.Error`) provides symmetric sibling access.
- 47 standards Parser.Protocol conformances demonstrate the nested-capability pattern in production.

### Evidence Against

1. **The "degenerate exception" is poorly defined.** What makes a domain "purely a single capability"? LEB128 has serialization, yet the document calls it "one-directional." The criterion should be: "the domain does not require a structured sibling serializer type" — not "the domain has no serialization." The distinction is about namespace *capacity need*, not about whether serialization exists at all.

2. **The principle is stated as SHOULD, not MUST.** This appropriately leaves room for judgment. But it means the principle alone doesn't mandate `.Parser` — it recommends it. The degenerate exception is also SHOULD-level, meaning even parsing-only domains *could* use the nested pattern if preferred for consistency.

3. **No prior art survey for the principle itself.** The principle is introduced as a novel design guideline. [RES-021] requires Tier 2+ documents to include prior art. While the standards naming survey serves as partial prior art, no survey of how other parser combinator ecosystems (Rust nom, Haskell parsec/megaparsec, Scala fastparse) handle domain-capability naming was conducted.

### Verdict: QUALIFIED

The principle is architecturally sound and well-motivated by the four-protocol design. However:

- The LEB128 "degenerate case" characterization must be corrected (serialization exists)
- The degenerate exception criterion should be refined from "no serialization counterpart" to "no structured serialization concern requiring namespace siblings"
- The principle would benefit from brief external prior art (how do other ecosystems handle this?)

---

## Cross-Cutting: Binary.ASCII.Serializable

v4.1.0 explicitly scopes this out with a cross-reference to future `ascii-serialization-migration.md`. This is the correct treatment — the serialization concern is orthogonal to parsing domain ownership. No further challenge on scoping.

One observation: the v4.1.0 migration plan now has Phase 5 (serialization migration) and Phase 6 (Machine IR extraction), both marked "future." This honestly represents the work remaining without pretending it's addressed.

---

## Overall Assessment

### Claims Summary (v2.0.0)

| # | Claim | v1.0.0 Verdict | v2.0.0 Verdict | Change |
|---|-------|----------------|----------------|--------|
| 1 | New package necessary | QUALIFIED | CONFIRMED | Trade-offs honestly presented |
| 2 | Binary.ASCII redundant | QUALIFIED | CONFIRMED | Serializable scoped out |
| 3 | `ASCII.Decimal.Parser` naming | QUALIFIED | QUALIFIED (narrowed) | LEB128 has serialization; convention split 22/25 |
| 4 | .ascii wrappers redundant | QUALIFIED | CONFIRMED | Overload differences acknowledged |
| 5 | Machine IR over-engineering | QUALIFIED | CONFIRMED | Costs corrected, claims softened |
| 6 | Embedded Swift matters | INSUFFICIENT EVIDENCE | CONFIRMED | Framing now honest |
| 7 | Machine IR home | QUALIFIED | CONFIRMED | Stays in swift-ascii |
| 8 | Drop parser deps | CONFIRMED | CONFIRMED | Unchanged |
| NEW | Domains/capabilities principle | — | QUALIFIED | LEB128 correction needed |

### Does v4.1.0 Hold?

**Yes, with two factual corrections needed:**

1. **LEB128 serialization exists.** Replace "No `Binary.LEB128.Serializer` exists. LEB128 is a one-directional encoding format" with an accurate characterization: LEB128 serialization exists as collection initializers at a lower layer, but doesn't require the structured namespace capacity that ASCII decimal's 60+ protocol conformances warrant. The "degenerate exception" criterion should be: "no structured serialization concern requiring namespace siblings" — not "no serialization counterpart."

2. **Standards naming convention is split.** The 22/25 `.Parse`/`.Parser` split should be stated in the analysis, not just flagged as an open item. The `.Parser` recommendation is defensible on the grounds that nouns are better type names than verbs — but it's a design choice, not an established convention.

Neither correction changes the recommendation. The architectural direction — domain-owned namespace, nested capability types, leaf parser primary, Machine IR deferred — is sound. v4.1.0 is implementable after these two corrections.

---

## Changelog

- **v2.0.0** (2026-03-04): Follow-up review of v4.1.0. Verified four-protocol design
  (confirmed — four protocols, not three). Discovered LEB128 serialization exists
  (`[UInt8](leb128:)` in binary-primitives) — refutes "one-directional" characterization.
  Verified all standards prior art (confirmed real; 22/25 Parse/Parser split). Revised 6
  verdicts from QUALIFIED to CONFIRMED. Narrowed Claim 3 to two factual corrections. Added
  new-claim analysis for "domains as namespaces" principle. Overall: v4.1.0 holds with
  corrections.
- **v1.0.0** (2026-03-04): Initial adversarial review of v4.0.0. 8 claims evaluated:
  1 CONFIRMED, 6 QUALIFIED, 1 INSUFFICIENT EVIDENCE. Four revisions recommended.

## References

- ascii-parsing-domain-ownership.md v4.1.0 (document under review)
- ascii-parsing-domain-ownership.md v4.0.0 (previously reviewed)
- binary-parser-primitives: `/Users/coen/Developer/swift-primitives/swift-binary-parser-primitives/`
- binary-primitives LEB128 serialization: `/Users/coen/Developer/swift-primitives/swift-binary-primitives/Sources/Binary Primitives Core/Binary.LEB128.Serialize.swift`
- parser-primitives protocols: `/Users/coen/Developer/swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/`
- ascii-primitives: `/Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/`
- swift-ascii: `/Users/coen/Developer/swift-foundations/swift-ascii/Sources/ASCII/`
- Standards Parser.Protocol conformances: 47 types across swift-standards (22 `.Parse`, 25 `.Parser`)
- [API-NAME-001] Namespace Structure
- [RES-004] Investigation Methodology
- [RES-021] Prior Art Survey
