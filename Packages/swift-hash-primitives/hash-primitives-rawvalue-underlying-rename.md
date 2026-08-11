# Hash Primitives — Tagged.underlying + Carrier.`Protocol` rename

**Date**: 2026-05-03
**Tier**: 1.5c (last serial sibling: equation -> comparison -> hash)
**Upstream HEADs**:
- swift-equation-primitives `065bae3`
- swift-comparison-primitives `e3c7d5e`
- swift-property-primitives `c4bce7f`
- swift-tagged-primitives `46ded75` (Tagged: drop cascade in Carrier conformance — unconditional + immediate)

## Phase 1 — Design Audit

### Q1. Own `public let rawValue` types?

**No.** The package contains zero own newtypes with a `public let rawValue` field.
The only public types in this package are:

- `Hash` (bare-namespace `enum`)
- `Hash.\`Protocol\`` (refines `Equation.\`Protocol\``)
- `Hash.Value` (typealias: `Tagged<Hash, Int>` — not an own newtype, gains
  `.underlying` from Tagged automatically)

The package exposes one Carrier-style member: `Hash.Value.underlying: Int`,
but that comes through Tagged itself, not from a hand-rolled `let rawValue`.

### Q2. Editorial public surface that could move to a sibling target / SLI?

**No relocation needed.** The package is already cleanly factored:

| Target | Role |
| --- | --- |
| Hash Primitives Core | Namespace + protocol + Hash.Value |
| Hash Primitives Standard Library Integration | Conformances for Swift.Array, Swift.Dictionary, Swift.Set, etc. |
| Hash Primitives | Umbrella: re-exports Core + Standard Library Integration |
| Hash Primitives Test Support | Test fixtures (currently just exports) |

The one cross-cutting file `Hash.Protocol+Identity.Tagged.swift` lives in the
umbrella target (Hash Primitives), where it has visibility over both Hash.Protocol
and Tagged_Primitives. That's the correct home — Tagged isn't part of Core, and
this conformance bridges identity primitives with the hash protocol.

### Q3. Three-consumer rule

| Public surface | Consumers (in tier 1.5c+) | Verdict |
| --- | --- | --- |
| `Hash.\`Protocol\`` | All hashing types (broad) | KEEP |
| `Hash.Value` (typealias) | `Hash.\`Protocol\`.hashValue` accessor; downstream Hashable bridges | KEEP |
| `Tagged: Hash.\`Protocol\`` extension | All Tagged values whose Underlying is hashable | KEEP |
| Hash conformances on Swift.{Array, Dictionary, Set, Optional, Range, ...} | Composite hashers across the ecosystem | KEEP |

All public surface meets the three-consumer rule (or has obvious near-term
demand from tier 2+ packages). Nothing recommended for removal/relocation.

### Q4. Compound identifiers / `*Tag` suffixes / code-surface violations?

**None.**

- File names: `Hash.swift`, `Hash.Value.swift`, `Hash.Protocol.swift`,
  `Hash.Protocol+Identity.Tagged.swift`, `Hash.Protocol+Swift.{Type}.swift` —
  all `Nest.Name` style, one type per file.
- No `*Tag` suffix usage (the namespace tag is just `Hash`).
- No compound type or method names.
- Typed throws not applicable: no throwing functions in this package.

### Verdict

**Trivial mechanical migration.** Q1 pre-authorized, Q2/Q3/Q4 surface no issues.
Proceed to Phase 2 cascade.

## Phase 2 — Migration Plan

Edits required (4 files):

1. `Sources/Hash Primitives Core/Hash.Value.swift`
   - DocC example: `let raw: Int = value.rawValue` -> `let raw: Int = value.underlying`

2. `Sources/Hash Primitives Core/Hash.Protocol.swift`
   - `Hash.Value(__unchecked: (), hasher.finalize())` -> `Hash.Value(_unchecked: hasher.finalize())`

3. `Sources/Hash Primitives/Hash.Protocol+Identity.Tagged.swift`
   - `where Tag: ~Copyable, RawValue: ~Copyable & Hash.\`Protocol\``
     -> `where Tag: ~Copyable, Underlying: ~Copyable & Hash.\`Protocol\``
   - DocC: "RawValue" -> "Underlying"
   - `rawValue.hash(into: &hasher)` -> `underlying.hash(into: &hasher)`

4. `Tests/Support/exports.swift` — no changes (only `@_exported import`s).

No Carrier protocol references to rewrite (Hash.Protocol does not extend Carrier
or take `some Carrier` parameters). No public-mutation sites. No stdlib
`RawRepresentable` enums.
