# ASCII Parsing Domain Ownership

<!--
---
version: 4.2.0
last_updated: 2026-03-04
status: RECOMMENDATION
tier: 2
---
-->

## Context

ASCII parsing exists in three places today, each with problems:

1. **parser-primitives** (Tier 17) defines `Parser.ASCII.Integer.Decimal` and
   `Parser.ASCII.Integer.Hexadecimal` — but `Parser.ASCII` is the wrong namespace owner
   (the parser doesn't own the ASCII domain), the parsers hardcode digit conversion
   instead of using `ASCII.Parsing.digit()`/`.hexDigit()`, and the umbrella
   `exports.swift` is missing the re-export (causing `Type 'Parser' has no member 'ASCII'`
   test failures).

2. **swift-ascii** (Layer 3, Foundations) defines `Binary.ASCII.Parsing.Machine.Decimal`
   — a Machine IR approach using `Binary.Bytes.Machine.build`. The entire package places
   ASCII under the `Binary` domain (`Binary.ASCII`), which is wrong: ASCII is an
   independent standard (INCITS 4-1986), not a sub-concern of Binary.

3. **ascii-primitives** (Tier 0) defines `ASCII.Parsing.digit()` and
   `ASCII.Parsing.hexDigit()` — pure conversion functions. These are the authoritative
   building blocks but cannot define `Parser.Protocol` conformers because Tier 0
   cannot depend on Tier 17.

### The `Binary.ASCII` Problem

swift-ascii (L3) creates a struct `Binary.ASCII { let byte: UInt8 }` that duplicates
ascii-primitives' (L1) `ASCII.Byte { let rawValue: UInt8 }`. Both provide instance-level
classification (`isDigit`, `isLetter`, etc.) — the L1 version via branchless arithmetic,
the L3 version delegating to INCITS 4-1986. Results are identical. Two UInt8 wrappers
representing the same domain.

A file-level audit of swift-ascii (34 files total) reveals a clean split:

| Category | Files | Needs binary-parser-primitives? |
|----------|------:|:------------------------------:|
| INCITS bridges, classification, serialization, utility | 17 | No |
| Parsing ergonomics + Machine IR parsers | 17 | Yes (hardwired to `Binary.Bytes.Input`) |

Zero files are parser-generic. Every parser-touching file is locked to
`Binary.Bytes.Input` specifically. The parsing ergonomics layer (`.ascii.whole()`,
`.ascii.prefix()`) provides similar functionality to `Binary.Parse.Access`
(`.parse.whole()`, `.parse.prefix()`), though the ASCII wrappers add
`StringProtocol` and `Memory.Contiguous.Protocol` overloads that
`Binary.Parse.Access` does not currently offer. Zero external consumers use the
`.ascii` wrappers — no usage found in swift-standards or swift-foundations outside
the ASCII module itself.

### Trigger

[RES-001] Three design questions intersect: (1) where should stateful `Parser.Protocol`
conformers for ASCII constructs live? (2) What namespace should they use? (3) Should
swift-ascii's `Binary.ASCII` domain placement be corrected?

### Constraints

- Tier 0 (ascii-primitives) CANNOT depend on Tier 17 (parser-primitives) — upward forbidden
- Tier 17 (parser-primitives) CAN depend on Tier 0 — but domain ownership principle says
  ASCII should own its namespace
- binary-parser-primitives (Tier 20) is the proven reference architecture: domain owns
  namespace, parser provides capability
- [API-NAME-001]: types use `Nest.Name` pattern
- [API-NAME-003]: types should mirror their domain
- Subject-first namespace ordering: `Binary.LEB128.Unsigned` (subject first), not
  `Binary.Parser.LEB128.Unsigned` (capability first)
- parser-primitives defines four capability protocols: `Parser.Protocol` (consuming),
  `Parser.Serializer` (appending), `Parser.Printer` (prepending). Domains with
  bidirectional concerns need room for all three.

### Stakeholders

All consumers of ASCII parsing across primitives, standards, and foundations.

## Question

**How should ASCII parsing be structured across the Swift Institute package ecosystem?**

Sub-questions:
1. Should there be a dedicated `swift-ascii-parser-primitives` package?
2. Or should parser-primitives host these types with an ascii-primitives dependency?
3. What namespace should the types use — subject-first or capability-first?
4. What happens to the existing `Parser.ASCII.*` types in parser-primitives?
5. What happens to `Binary.ASCII` and the `Binary.ASCII.Parsing.*` types in swift-ascii?
6. What is the migration path?

## Prior Art Survey

### binary-parser-primitives (Reference Architecture)

[RES-021] The binary-parser-primitives package (Tier 20) establishes the domain-owned
parser pattern:

| Aspect | Implementation |
|--------|---------------|
| Package | Separate: `swift-binary-parser-primitives` |
| Dependencies | `swift-binary-primitives` + `swift-parser-primitives` |
| Namespace | `Binary.*` — domain owns everything |
| Naming | Subject-first: `Binary.LEB128.Unsigned<T>`, not `Binary.Parser.LEB128.Unsigned` |
| Conformance | Types conform to `Parser.Protocol` |
| Error types | Domain-specific: `Binary.LEB128.Error`, `Binary.Bytes.Machine.Fault` |
| Execution | `Binary.Bytes.Input` (owned), `Binary.Bytes.withBorrowed` (zero-copy) |
| Ergonomics | `Binary.Parse.Access<P>` gives `.parse.whole()` / `.parse.prefix()` |
| Machine factories | On execution namespace: `Binary.Bytes.Machine.uleb128Parser()` |

**Key principles**:

1. **Domain ownership**: Binary owns its entire namespace. The parser capability comes
   from depending on parser-primitives — it doesn't change who owns the namespace.

2. **Subject-first naming**: `Binary.LEB128.Unsigned<T>` — you read the subject (LEB128
   unsigned encoding) before the capability (Parser.Protocol conformance is implicit).
   Not `Binary.Parser.LEB128.Unsigned`.

3. **Execution infrastructure**: Binary provides `Binary.Bytes.Input` and
   `Binary.Bytes.withBorrowed` as shared byte-cursor infrastructure. Any domain that
   parses bytes can use Binary's execution infrastructure without being namespaced under
   Binary.

### Existing ASCII Parser Naming in parser-primitives

The current types use **inverted** domain ownership:

```
Parser.ASCII.Integer.Decimal<Input, T>     — "Parser's ASCII integer (decimal)"
Parser.ASCII.Integer.Hexadecimal<Input, T> — "Parser's ASCII integer (hex)"
Parser.ASCII.Integer.Error                 — "Parser's ASCII integer error"
```

Reading direction: "Parser's ASCII" — puts the capability (Parser) as the owner and
the domain (ASCII) as the subject. This contradicts the binary-parser-primitives pattern.

### Standards Parser Naming Convention

[RES-021] Standards packages use nested parser types within domain namespaces:

| Type | Convention | Package |
|------|-----------|---------|
| `HTTP.MediaType.Parser<Input>` | `.Parser` (noun) | RFC 9110 |
| `ISO_8601.DateTime.Parse<Input>` | `.Parse` (verb) | ISO 8601 |
| `RFC_3986.URI.Scheme.Parse<Input>` | `.Parse` (verb) | RFC 3986 |

A full survey of 47 `Parser.Protocol` conformances across swift-standards reveals a
near-even split: 22 use `.Parse` (verb) and 25 use `.Parser` (noun). There is no
dominant convention. This document adopts `.Parser` (noun) on the grounds that type
names should describe what the type IS, not what it DOES — "ASCII Decimal Parser"
reads as a thing, "ASCII Decimal Parse" reads as an action. This is a design choice,
not an established convention.

### Three Capability Protocols

parser-primitives defines four protocols, each representing a distinct capability:

| Protocol | Semantics | Direction |
|----------|-----------|-----------|
| `Parser.Protocol` | Consume input → produce value | Reading |
| `Parser.Serializer` | Append value → buffer | Writing (one-way) |
| `Parser.Printer` | Prepend value → input | Writing (round-trip) |
| `Parser.ParserPrinter` | Bidirectional: parsing + printing | Both |

This four-protocol design means domains with bidirectional concerns need their domain
namespace to be open — not consumed by a single concrete parser struct.

## Analysis

### Part 1: Package Placement

#### Option A: New `swift-ascii-parser-primitives` Package

Create a dedicated bridge package, mirroring the binary-parser-primitives pattern.

- Dependencies: `swift-ascii-primitives` (Tier 0) + `swift-parser-primitives` (Tier 17)
- Tier: 18 (max(0, 17) + 1)
- Implementation delegates to `ASCII.Parsing.digit()` / `.hexDigit()`

**Advantages**:
- Follows the proven reference architecture
- Domain ownership: ASCII owns its parser namespace
- Clean dependency graph: no circular or upward dependencies
- Single source of truth for digit conversion
- Independent evolution: ASCII parsing can grow without modifying parser-primitives

**Disadvantages**:
- One more package in the ecosystem (127th)
- Currently only 2 leaf parsers — a thin package compared to the 8-target
  binary-parser-primitives reference. The package carries the full weight of a standalone
  SwiftPM package (manifest, CI, versioning) for what is initially 3-4 source files.
  This investment is justified if the domain grows (floating-point, octal, base-N parsers)
  or if the architecture principle is valued over package count minimization.

#### Option B: parser-primitives Adds ascii-primitives Dependency

parser-primitives (Tier 17) adds `swift-ascii-primitives` (Tier 0) as a dependency.

**Advantages**:
- No new package
- Implementation uses `ASCII.Parsing.digit()` (fixes hardcoding)
- ascii-primitives (Tier 0) adds negligible resolution weight

**Disadvantages**:
- Violates domain ownership: parser-primitives doesn't own the `ASCII` namespace
- If kept as `Parser.ASCII.*`, inconsistent with binary-parser-primitives pattern
- If changed to `ASCII.*`, parser-primitives extends a foreign namespace
- Couples a large (35+ target) package to ASCII concerns

**Note**: The domain ownership violation is a convention concern, not a technical
constraint. A dedicated target within parser-primitives with an ascii-primitives
dependency would produce identical runtime artifacts. However, the convention exists
for a reason: it prevents parser-primitives from accumulating domain-specific types
for every domain that needs parsing.

#### Option C: Target Within parser-primitives

Same as Option B but isolated to a specific target.

**Disadvantages**:
- Same domain ownership violation
- SwiftPM resolves dependencies at package level regardless

#### Option D: Extend ascii-primitives Directly

**Eliminated**: Tier 0 cannot depend on Tier 17. Upward dependency forbidden.

### Comparison (Package Placement)

| Criterion | A: New Package | B: In parser-prims | C: Conditional | D: In ascii-prims |
|-----------|:-:|:-:|:-:|:-:|
| Domain ownership | ASCII owns | Parser owns | Parser owns | ASCII owns |
| Reference architecture match | Exact | Partial | Partial | N/A |
| Uses `ASCII.Parsing.digit()` | Yes | Yes | Yes | Yes |
| Tier constraint | 18 | 17 | 17 | **Violated** |
| Independent evolution | Yes | No | Partial | No |
| Coupling | Minimal | High | Medium | N/A |

**Conclusion**: Option A (new package).

### Part 2: Namespace Design

#### Domains as Namespaces; Capabilities as Nested Types

The fundamental principle: **a domain namespace should not be consumed by a single
capability**. When a domain struct IS the parser, the domain name is locked to that
one capability — there is no room for `.Serializer`, `.Printer`, `.Error`, or `.Machine`
as siblings.

This distinguishes two patterns:

**Degenerate case** — the domain's serialization is simple enough to not need
namespace siblings:
```swift
Binary.LEB128.Unsigned<T>     // The encoding format IS the parser's subject
Binary.LEB128.Signed<T>       // Serialization exists but as simple initializers
```

LEB128 serialization exists at a lower layer (`[UInt8](leb128:)` and
`ContiguousArray<UInt8>(leb128:)` in binary-primitives), but it is expressed as
collection initializers — not as a structured `Parser.Serializer` conformer or a
protocol with many conformances. The encoding is simple enough that the domain type
can conflate domain and capability without sacrificing namespace capacity.

**General case** — the domain has multiple capabilities:
```swift
ASCII.Decimal.Parser<Input, T>       // Parser.Protocol conformer (consuming)
ASCII.Decimal.Serializer<T>          // Future: Parser.Serializer conformer (appending)
ASCII.Decimal.Error                  // Shared error type
ASCII.Decimal.Machine                // L3: Machine IR factories
```

ASCII decimal is inherently bidirectional — `Binary.ASCII.Serializable` already
defines both `init(ascii:)` (parsing) and `serialize(ascii:into:)` (serialization)
with 60+ active conformances. The domain namespace must remain open.

**Why `Binary.LEB128.Unsigned` is not a precedent for `ASCII.Decimal`**:

| Property | `Binary.LEB128.Unsigned` | `ASCII.Decimal` |
|----------|--------------------------|-----------------|
| Serialization complexity | Simple initializers (`[UInt8](leb128:)`) | Complex: protocol with 60+ conformances |
| Needs namespace siblings? | No — initializers suffice at lower layer | Yes — structured `.Serializer`, `.Error`, `.Machine` |
| Domain vs capability | Conflated — encoding IS the type | Distinct — radix is domain, parsing is capability |
| Variants | Unsigned / Signed (encoding variants) | None (generic `T` handles signedness) |
| What the name describes | Encoding variant | Radix system |

#### Subject-First Ordering

The subject-first principle still applies at the domain level:

```
// Subject-first (correct):
ASCII.Decimal.Parser<Input, T>

// Capability-first (wrong):
ASCII.Parser.Integer.Decimal<Input, T>
```

`ASCII.Decimal` reads: "ASCII's decimal representation." The `.Parser` nested type
adds the capability: "the parser for ASCII decimal representations."

#### No Intermediate `Integer` Level

"Decimal" and "Hexadecimal" describe radix systems, not subcategories of integers.
`ASCII.Integer.Decimal` implies there could be `ASCII.Float.Decimal` — but the radix
is orthogonal to the output type. If decimal floating-point parsing is needed, the
output type (`T: BinaryFloatingPoint`) or a separate type distinguishes it.

#### Structure

```
ASCII.Decimal                          — base-10 representation (empty enum namespace)
├── Parser<Input, T>                   — Parser.Protocol conformer
├── Serializer<T>                      — future: Parser.Serializer conformer
├── Error                              — error type (.noDigits, .overflow)
└── Machine                            — L3 extension: Machine IR factories

ASCII.Hexadecimal                      — base-16 representation (empty enum namespace)
├── Parser<Input, T>                   — Parser.Protocol conformer
├── Serializer<T>                      — future: Parser.Serializer conformer
└── Error                              — error type
```

#### `ASCII.Parsing` vs `ASCII.Decimal`

ascii-primitives defines `ASCII.Parsing` as a namespace for pure conversion functions.
The new `ASCII.Decimal` / `ASCII.Hexadecimal` namespaces are distinct:

| Namespace | Semantics | State | Package |
|-----------|-----------|-------|---------|
| `ASCII.Parsing` | Pure byte → value functions | Stateless | ascii-primitives (L1) |
| `ASCII.Decimal` | Decimal representation types | Stateful parsers | ascii-parser-primitives (L1) |
| `ASCII.Hexadecimal` | Hex representation types | Stateful parsers | ascii-parser-primitives (L1) |

`ASCII.Parsing.digit()` converts one byte. `ASCII.Decimal.Parser` consumes a stream of
bytes. The former is a building block; the latter composes it into a `Parser.Protocol`
conformer.

### Part 3: swift-ascii Restructuring

#### `Binary.ASCII` Struct Elimination

`Binary.ASCII` (struct wrapping UInt8 in swift-ascii, L3) is redundant with `ASCII.Byte`
(struct wrapping UInt8 in ascii-primitives, L1). Both provide identical classification
and conversion. The L3 version delegates to INCITS 4-1986; the L1 version uses branchless
arithmetic. Results are the same.

swift-ascii already re-exports ascii-primitives (`@_exported public import ASCII_Primitives`),
so consumers already have `byte.ascii.isDigit` via L1's `ASCII.Byte`. The `Binary.ASCII`
struct adds nothing for classification.

**Note**: `Binary.ASCII` also provides `Character`-level API (`Character.ASCII`,
`UInt8.init?(ascii:)`) and `String`/`Collection` bridges that ascii-primitives does not.
These are L3 concerns (stdlib extensions) that correctly live in swift-ascii — but they
are extensions on stdlib types, not on the `Binary.ASCII` struct itself. They survive
struct elimination.

**Action**: Eliminate `Binary.ASCII` struct for classification purposes. INCITS bridge
extensions operate on `ASCII.Byte`, `UInt8`, `Character`, `String` directly.

#### `Binary.ASCII` as Namespace — Serializable Migration

`Binary.ASCII` also serves as the namespace for `Binary.ASCII.Serializable`,
`Binary.ASCII.RawRepresentable`, and `Binary.ASCII.Wrapper`. These protocols are nested
inside the struct via `extension Binary.ASCII { protocol Serializable }`.

**Scale of active usage**:

| Metric | Count |
|--------|-------|
| Standards packages with conformances | ~30 |
| Individual type conformances | 60+ |
| `Binary.ASCII.RawRepresentable` conformances | ~25 |
| Default implementations provided | 15+ |

This migration is **explicitly out of scope** for this document. The serialization
concern is orthogonal to the parsing domain ownership question. The `Binary.ASCII`
struct and its nested protocols remain until a separate research document
(`ascii-serialization-migration.md`, scope: ecosystem-wide, ~30 standards packages)
addresses:
- What replaces `Binary.ASCII.Serializable` (witness-based? `ASCII.Serializable`?)
- Migration strategy for 60+ conformances across ~30 packages
- Timeline and phasing

Cross-reference: [RES-004b] scope escalation — serialization migration is a separate
ecosystem-wide concern.

#### Ergonomics Wrappers Elimination

swift-ascii's `.ascii` accessor provides similar functionality to Binary's `.parse`
accessor, with additional overloads:

```swift
// Binary's existing ergonomics (binary-parser-primitives):
parser.parse.whole(bytes)           // Binary.Parse.Access<P> — Collection<UInt8>
parser.parse.prefix(bytes)

// swift-ascii's wrapper adds:
parser.ascii.whole(bytes)           // Collection<UInt8>
parser.ascii.whole(string)          // + StringProtocol overload
parser.ascii.whole(contiguous)      // + Memory.Contiguous.Protocol overload
```

The `.ascii` wrappers are not strictly identical to `Binary.Parse.Access` — they add
`StringProtocol` and `Memory.Contiguous.Protocol & ~Copyable` input overloads, and throw
a different error type (`Binary.ASCII.Parsing.Error` vs `Binary.Parse.Error`).

However, zero external consumers use these wrappers (no usage in swift-standards or
swift-foundations outside the ASCII module). The additional overloads can be added to
`Binary.Parse.Access` itself if demand materializes.

**Action**: Eliminate `.ascii` accessor and all wrapper types. Use Binary's execution
infrastructure directly.

#### Machine IR — Retained in swift-ascii Under Corrected Namespace

`Binary.ASCII.Parsing.Machine.Decimal` builds compiled `Binary.Bytes.Machine.Parser<T>`
programs for decimal parsing. For simple digit accumulation, the leaf `Parser.Protocol`
conformer is superior:

| | Leaf Parser | Machine IR |
|---|---|---|
| Allocation | Zero | Closure boxing into value arena (one-time setup) |
| Dispatch | Direct (inlined) | Instruction enum switch |
| Code size | ~15 lines | ~40 lines of builder code |
| Embedded Swift | Likely compatible (unverified) | Likely incompatible (heap, closures — unverified) |
| Composability | Via `Parser.Protocol` combinators | Via `Machine.Builder.embed` |

The leaf parser is the **primary** implementation at L1. The Machine IR code is retained
in swift-ascii under a corrected namespace (`ASCII.Decimal.Machine` instead of
`Binary.ASCII.Parsing.Machine.Decimal`) for consumers composing larger Machine IR
programs. A dedicated L3 package (`swift-ascii-parser`) is deferred until an external
consumer needs Machine IR ASCII parsing independently of swift-ascii.

**Note on embedded Swift**: Neither the leaf parser's compatibility nor the Machine IR's
incompatibility with embedded Swift has been verified. An experiment (`[EXP-*]`) should
confirm this before treating embedded compatibility as a confirmed advantage. The leaf
parser is *likely* compatible (zero allocation, no existentials, no dynamic dispatch),
but this is currently an architectural expectation, not an empirical fact.

**Namespace correction in swift-ascii**:

```swift
// Current (wrong — capability-first, under Binary domain):
Binary.ASCII.Parsing.Machine.Decimal.unsigned(UInt16.self)

// Corrected (subject-first, under ASCII domain):
ASCII.Decimal.Machine.unsigned(UInt16.self)
```

**When to extract**: If an external consumer needs Machine IR ASCII parsing without
the rest of swift-ascii, create `swift-ascii-parser` (L3) at that time. Until then,
the 3 files do not justify a standalone package.

#### File-Level Impact on swift-ascii

**Namespace-corrected in swift-ascii (3 files — Machine IR):**

| Current | Corrected |
|---------|-----------|
| `Binary.ASCII.Parsing.Machine.Decimal.swift` | `ASCII.Decimal.Machine.swift` |
| `Binary.ASCII.Parsing.Machine+call.swift` | `ASCII.Decimal.Machine+convenience.swift` |
| `Binary.ASCII.Parsing.Machine.swift` | Namespace merged into above |

**Eliminated from swift-ascii (15 files — redundant or duplicate):**

| File | Reason |
|------|--------|
| `Binary.ASCII.swift` | `Binary.ASCII` struct redundant with `ASCII.Byte` (L1) |
| `Binary.ASCII.Access.swift` | Use `Binary.Parse.Access<P>` |
| `Binary.ASCII.Access+prefix.swift` | Same |
| `Binary.ASCII.Access+whole.swift` | Same |
| `Binary.ASCII.Parsing.Whole.swift` | Duplicate of `Binary.Parse.Access.whole` |
| `Binary.ASCII.Parsing.Whole+call.swift` | Same |
| `Binary.ASCII.Parsing.Prefix.swift` | Duplicate of `Binary.Parse.Access.prefix` |
| `Binary.ASCII.Parsing.Prefix+call.swift` | Same |
| `Binary.ASCII.Parsing.Error.swift` | `Binary.Parse.Error` handles leftover bytes |
| `Binary.ASCII.Parsing.swift` | Namespace only, children moved/eliminated |
| `Binary.ASCII.Parsing.Machine.Access.swift` | Use `Binary.Bytes.withBorrowed` directly |
| `Binary.ASCII.Parsing.Machine.Access.Prefix.swift` | Same |
| `Binary.ASCII.Parsing.Machine.Access.Whole.swift` | Same |
| `Binary.Bytes.Machine.Parser+ascii.swift` | `.ascii` accessor removed |
| `Parsing.Parser+ascii.swift` | `.ascii` accessor removed |

**Renamed in swift-ascii (2 files):**

| Current | Renamed |
|---------|---------|
| `Binary.ASCII.Equals` | `ASCII.Equals` |
| `Binary.ASCII.Equals+nulTerminated` | `ASCII.Equals+nulTerminated` |

**Retained in swift-ascii (namespace-corrected INCITS bridges, 11 files):**

All INCITS 4-1986 bridge extensions remain. References to `Binary.ASCII` change to
use `ASCII.Byte` from L1 or direct INCITS delegation. These are stdlib extensions
(`UInt8`, `Character`, `String`, `[UInt8]`, `Set`) — no namespace wrapper needed.

**Retained in swift-ascii (serialization protocols — NOT deprecated until migration):**

`Binary.ASCII.Serializable`, `Binary.ASCII.RawRepresentable`, `Binary.ASCII.Wrapper` —
retained with 60+ active conformances across ~30 standards packages. These protocols
remain until the serialization migration (separate research document) provides a
replacement. See "Binary.ASCII as Namespace — Serializable Migration" above.

## Outcome

**Status**: RECOMMENDATION

### Design Principle: Domains as Namespaces, Capabilities as Nested Types

**Statement**: Domain namespaces (empty enums) SHOULD NOT be consumed by a single
capability type. When a domain has — or may have — multiple capabilities (parsing,
serialization, printing), each capability SHOULD be a nested type within the domain
namespace.

**Degenerate exception**: When a domain's serialization is simple enough to not
require structured namespace siblings (e.g., expressed as collection initializers at
a lower layer), the domain type MAY directly conform to `Parser.Protocol`
(e.g., `Binary.LEB128.Unsigned<T>`).

**Capability type naming**: Nested capability types SHOULD use noun form (`.Parser`,
`.Serializer`, `.Printer`), not verb form (`.Parse`, `.Serialize`). Type names describe
what the type IS, not what it DOES.

### Package Structure

Create `swift-ascii-parser-primitives` at Tier 18:

```
swift-ascii-parser-primitives/
├── Package.swift
│   dependencies: [swift-ascii-primitives, swift-parser-primitives]
├── Sources/
│   ├── ASCII Decimal Primitives/
│   │   ├── ASCII.Decimal.swift               → extension ASCII { public enum Decimal {} }
│   │   ├── ASCII.Decimal.Parser.swift        → struct, Parser.Protocol conformer
│   │   ├── ASCII.Decimal.Error.swift
│   │   └── exports.swift
│   ├── ASCII Hexadecimal Primitives/
│   │   ├── ASCII.Hexadecimal.swift           → extension ASCII { public enum Hexadecimal {} }
│   │   ├── ASCII.Hexadecimal.Parser.swift    → struct, Parser.Protocol conformer
│   │   ├── ASCII.Hexadecimal.Error.swift
│   │   └── exports.swift
│   └── ASCII Parser Primitives/              → umbrella
│       └── exports.swift
```

### Namespace Design

Subject-first at every level, capabilities nested:

```swift
ASCII.Decimal.Parser<Input, T>           // "ASCII decimal's parser"
ASCII.Hexadecimal.Parser<Input, T>       // "ASCII hexadecimal's parser"
ASCII.Decimal.Error                      // "ASCII decimal's error"
```

### Consumer Call Sites

```swift
// One-shot from slice (any layer, likely embedded-compatible):
var slice = ArraySlice(bytes)
let port = try ASCII.Decimal.Parser<ArraySlice<UInt8>, UInt16>().parse(&slice)

// With Binary ergonomics (when Input == Binary.Bytes.Input):
let parser = ASCII.Decimal.Parser<Binary.Bytes.Input, UInt16>()
let port = try parser.parse.whole(bytes)     // via Binary.Parse.Access — already exists

// Embedded Swift (any Collection.Slice.Protocol — unverified):
var input = someEmbeddedSlice
let value = try ASCII.Decimal.Parser<SomeSlice, UInt32>().parse(&input)

// Machine IR composition (in swift-ascii, after namespace correction):
let compiled = ASCII.Decimal.Machine.unsigned(UInt16.self)
let value = try Binary.Bytes.withBorrowed(bytes, compiled)
```

### Package Ecosystem After Restructuring

```
L1: ascii-primitives (Tier 0)
    └── ASCII.Parsing, ASCII.Byte, ASCII.Classification, ...

L1: ascii-parser-primitives (Tier 18)                        ← NEW
    └── ASCII.Decimal.Parser, ASCII.Hexadecimal.Parser
    deps: ascii-primitives, parser-primitives

L2: INCITS-4-1986
    └── formal standard

L3: swift-ascii                                              ← RESTRUCTURED
    └── INCITS bridges, serialization (Binary.ASCII.Serializable retained),
        ASCII.Equals, ASCII.Decimal.Machine (namespace-corrected)
    deps: ascii-primitives, incits-4-1986, binary-primitives,
          serialization-primitives, standard-library-extensions, string-primitives,
          binary-parser-primitives (retained for Machine IR)
    DROPPED: parser-primitives

L3: swift-ascii-parser                                       ← DEFERRED
    └── Created when external consumer needs Machine IR independently
```

**Note**: swift-ascii retains `binary-parser-primitives` as a dependency because the
Machine IR code (`ASCII.Decimal.Machine`) remains in swift-ascii under its corrected
namespace. `parser-primitives` is dropped — the Machine IR code uses
`Binary.Bytes.Machine` (from binary-parser-primitives), not `Parser.Protocol` directly.
When Machine IR is eventually extracted to `swift-ascii-parser`, swift-ascii can then
also drop `binary-parser-primitives`.

### Migration Path

| Phase | Action | Blast Radius |
|-------|--------|--------------|
| 1 | Create `swift-ascii-parser-primitives` with `ASCII.Decimal.Parser`, `ASCII.Hexadecimal.Parser` | None (additive) |
| 2 | Deprecate `Parser.ASCII.*` in parser-primitives (do NOT fix missing umbrella re-export) | Minimal (never re-exported) |
| 3 | Update standards/foundations consumers to import `ASCII_Decimal_Primitives` | Per-consumer |
| 4 | Restructure swift-ascii: eliminate `Binary.ASCII` struct (classification only), eliminate `.ascii` wrappers, correct Machine IR namespace to `ASCII.Decimal.Machine`, drop parser-primitives dep | swift-ascii internal |
| 5 | *(Future, separate research)* Migrate `Binary.ASCII.Serializable` conformances (~30 packages, 60+ types) | Ecosystem-wide |
| 6 | *(Future, on demand)* Extract Machine IR to `swift-ascii-parser` (L3) when external consumer needs it; drop binary-parser-primitives from swift-ascii | None if additive |

### Open Items

| Item | Action | Tracking |
|------|--------|----------|
| Embedded Swift compatibility | Create experiment verifying leaf parser and Machine IR under embedded mode | `[EXP-*]` TODO |
| `Binary.ASCII.Serializable` migration | Separate ecosystem-wide research document | `ascii-serialization-migration.md` TODO |
| `.Parse` vs `.Parser` convention alignment | Standards packages use `.Parse` (verb); this document recommends `.Parser` (noun). Convention reconciliation deferred. | Discovery research candidate |
| `Binary.Parse.Access` overload gaps | StringProtocol and Memory.Contiguous.Protocol overloads exist in `.ascii` wrappers but not in `Binary.Parse.Access`. Add if demand materializes. | Monitor |

**Rationale**: The leaf parser at L1 is the primary implementation — `@inlinable`,
zero-allocation, fully specializable, likely embedded-compatible. Machine IR code is
preserved in swift-ascii under corrected namespace for composition use cases, with
extraction deferred until demand. Domain ownership is correct at every level: ASCII
owns its namespace, Binary provides execution infrastructure as a service.

The key design principle is that domains are namespaces and capabilities are nested
types: `ASCII.Decimal.Parser`, not `ASCII.Decimal` as a parser struct. This follows
from the four-protocol design in parser-primitives (`Parser.Protocol`, `.Serializer`,
`.Printer`, `.ParserPrinter`) and the complex serialization concerns of ASCII decimal
(60+ protocol conformances already exist). The `Binary.LEB128.Unsigned` pattern —
where the type IS the parser — is a degenerate case for domains whose serialization
is simple enough (collection initializers) to not need structured namespace siblings,
and should not be generalized.

`Binary.ASCII.Serializable` migration is the largest remaining risk and is explicitly
scoped out as a separate research effort.

## Adversarial Review Response

This section addresses findings from
[ascii-parsing-adversarial-review.md](ascii-parsing-adversarial-review.md) v1.0.0.

### Revision 1: Drop `.Parser` suffix → REJECTED

The adversarial review recommended `ASCII.Decimal<Input, T>` (no "Parser" suffix) to
match `Binary.LEB128.Unsigned`. This is rejected because the analogy is flawed:

- `Binary.LEB128.Unsigned` is a degenerate case: its serialization is simple enough
  (collection initializers at a lower layer) to not need structured namespace siblings.
  The encoding format IS the type.
- `ASCII.Decimal` has complex serialization concerns (protocol with 60+ conformances
  across ~30 packages). The domain namespace must remain open for `.Parser`,
  `.Serializer`, `.Error`, `.Machine`.
- Standards convention is split (22 `.Parse` / 25 `.Parser`) but nested parser types
  are the established pattern; `.Parser` (noun) is preferred as a design choice.
- The four-protocol design in parser-primitives (`Parser.Protocol`, `.Serializer`,
  `.Printer`, `.ParserPrinter`) requires domain namespaces that can host multiple
  capability types.

**v2.0.0 review correction applied**: LEB128 serialization exists (`[UInt8](leb128:)`
in binary-primitives). The degenerate exception criterion is refined from "no
serialization counterpart" to "no structured serialization concern requiring namespace
siblings."

### Revision 2: Address `Binary.ASCII.Serializable` → ACCEPTED

Explicitly scoped out with cross-reference. See "Binary.ASCII as Namespace —
Serializable Migration" section and Phase 5 in migration path.

### Revision 3: Defer `swift-ascii-parser` (L3) → ACCEPTED

Machine IR stays in swift-ascii under corrected namespace. L3 package created on demand.

### Revision 4: Add embedded Swift experiment → ACCEPTED

Embedded compatibility claims softened from "Compatible/Incompatible" to "Likely
compatible/incompatible (unverified)." Experiment reference added to Open Items.

### Additional: `.ascii` wrapper characterization → CORRECTED

v4.0.0 incorrectly characterized `.ascii` wrappers as "identical behavior under a
different accessor name." Corrected to acknowledge the StringProtocol and
Memory.Contiguous.Protocol overload differences, while noting zero external consumers.

## Changelog

- **v4.2.0** (2026-03-04): Post-adversarial review v2.0.0 corrections. Fixed LEB128
  characterization: serialization exists as collection initializers (`[UInt8](leb128:)`)
  — refined degenerate exception criterion from "no serialization counterpart" to "no
  structured serialization concern requiring namespace siblings." Corrected protocol
  count from three to four (`Parser.ParserPrinter`). Stated standards convention split
  (22 `.Parse` / 25 `.Parser`) in analysis body rather than only as open item.
- **v4.1.0** (2026-03-04): Post-adversarial review revision. Established design
  principle: domains as namespaces, capabilities as nested types — justifying
  `ASCII.Decimal.Parser` over `ASCII.Decimal` (LEB128 is degenerate, not general).
  Scoped out `Binary.ASCII.Serializable` migration (60+ conformances, separate research).
  Deferred `swift-ascii-parser` (L3) — Machine IR stays in swift-ascii under corrected
  namespace. Softened embedded Swift claims (unverified). Corrected `.ascii` wrapper
  characterization (not identical to `Binary.Parse.Access` — adds overloads). Added
  three-protocol evidence (`Parser.Protocol`, `.Serializer`, `.Printer`). Added
  standards prior art (`.Parser` vs `.Parse` convention). Revised dependency table
  (swift-ascii retains binary-parser-primitives until Machine IR extracted). Added
  Adversarial Review Response section. Added Open Items table.
- **v4.0.0** (2026-03-04): Machine IR moved to `swift-ascii-parser` (L3) instead of
  deleted. swift-ascii drops parser-primitives and binary-parser-primitives dependencies.
  Leaf parser at L1 is the primary path (embedded-compatible). Machine IR preserved at
  L3 for consumers composing Machine programs. 5-phase migration (up from 4). Added
  package ecosystem diagram.
- **v3.0.0** (2026-03-04): Eliminated Machine IR for ASCII parsing. Leaf parsers are
  simpler, faster, and embedded-compatible. Machine IR adds dispatch overhead, closure
  boxing, and heap allocation — all unnecessary for a tight digit accumulation loop and
  all incompatible with embedded Swift.
- **v2.0.0** (2026-03-04): Subject-first namespace design (`ASCII.Decimal.Parser` instead
  of `ASCII.Parser.Integer.Decimal`). Eliminated intermediate `Integer` namespace level.
  Added `Binary.ASCII` elimination analysis. Added ergonomics wrapper redundancy analysis.
  Added swift-ascii file-level restructuring plan. Expanded from package placement to
  full ecosystem restructuring.
- **v1.0.0** (2026-03-04): Initial analysis of package placement options.

## References

- binary-parser-primitives reference architecture: `/Users/coen/Developer/swift-primitives/swift-binary-parser-primitives/`
- ascii-primitives current API: `/Users/coen/Developer/swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/`
- parser-primitives ASCII target: `/Users/coen/Developer/swift-primitives/swift-parser-primitives/Sources/Parser ASCII Integer Primitives/`
- parser-primitives protocols: `/Users/coen/Developer/swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/`
- swift-ascii foundations: `/Users/coen/Developer/swift-foundations/swift-ascii/Sources/ASCII/`
- Primitives Tiers: `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Tiers.md`
- Adversarial review: [ascii-parsing-adversarial-review.md](ascii-parsing-adversarial-review.md)
- [API-NAME-001] Namespace Structure
- [API-NAME-003] Specification-Mirroring Names
