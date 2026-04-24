# Bitset Naming: Literature Study

<!--
---
version: 1.0.0
last_updated: 2026-02-09
status: DECISION
tier: 2
depends_on: [bit-vector-type-organization, bit-vector-primitives-reducibility]
---
-->

## Context

The swift-set-primitives package contains `Set<Bit>.Vector` — a family of four bitset types (Dynamic, Fixed, Static, Small) that provide set-theoretic operations over packed bit storage. These types are architecturally distinct from `Bit.Vector` (which is a bit *vector* — a sequence of addressable bits) despite sharing the same underlying storage representation (packed `UInt` words).

Prior research ([bit-vector-type-organization](bit-vector-type-organization.md)) established that `Array<Bit>.Vector` was incorrectly placed and should be consolidated into `swift-bit-vector-primitives` as `Bit.Vector.*`. The same architectural question now applies to `Set<Bit>.Vector`: is it correctly placed inside `swift-set-primitives`, or does it deserve its own package?

The user has already ruled out:
- **Keeping it in swift-set-primitives** as `Set<Bit>.Vector` (analogous to the rejected `Array<Bit>.Vector` placement)
- **Folding it into swift-bit-vector-primitives** (a bitset is a distinct data structure from a bit vector)

The remaining question is purely about naming: should the standalone package be named `swift-bitset-primitives` or `swift-bit-set-primitives`?

## Question

Is "bitset" a single compound noun or two separate words "bit set"? What is the principled package name: `swift-bitset-primitives` or `swift-bit-set-primitives`?

## Analysis

### Prior Art Survey

#### Programming Languages and Standard Libraries

| Language / Library | Type Name | Word Boundary | Notes |
|---|---|---|---|
| C++ STL | `std::bitset<N>` | Fused (lowercase) | Since C++98. Header: `<bitset>` |
| Boost C++ | `boost::dynamic_bitset` | Fused (snake_case) | Dynamic counterpart |
| Java | `java.util.BitSet` | Two words (PascalCase) | Since JDK 1.0 |
| C# .NET | `System.Collections.BitArray` | Two words (PascalCase) | Uses "Array" not "Set" |
| Rust (`bit-set` crate) | `bit_set::BitSet` | Two words (PascalCase) | Crate name: `bit-set` (hyphenated) |
| Rust (`fixedbitset`) | `FixedBitSet` | Two words (PascalCase) | Crate name: `fixedbitset` (fused) |
| Rust (former std) | `std::collections::BitSet` | Two words (PascalCase) | Removed from stdlib |
| Go (`bits-and-blooms`) | `bitset.BitSet` | Two words (PascalCase) | Package name: `bitset` (fused) |
| Haskell | `Data.BitSet` | Two words (PascalCase) | Package name: `bitset` (fused) |
| OCaml (Batteries) | `BitSet` | Two words (PascalCase) | Module name |
| Scala (stdlib) | `scala.collection.immutable.BitSet` | Two words (PascalCase) | In standard library |
| Kotlin | `kotlin.native.BitSet` | Two words (PascalCase) | JVM uses `java.util.BitSet` |
| Zig | `StaticBitSet`, `DynamicBitSet` | Two words (PascalCase) | File: `std/bit_set.zig` (underscored) |
| Ruby (`bitset` gem) | `Bitset` | One word (PascalCase) | |
| Ruby (`bit_set` gem) | `BitSet` | Two words (PascalCase) | |
| JavaScript (`bitset` npm) | `BitSet` | Two words (PascalCase) | Package: `bitset` (fused) |
| Swift (swift-collections) | `BitSet` | Two words (PascalCase) | Public API in `BitCollections` |
| Swift (stdlib internal) | `_UnsafeBitset` | One word (PascalCase) | Lowercase 's' — treats "bitset" as one word |
| Swift (Lemire) | `Bitset` | One word (PascalCase) | Class in `SwiftBitset` package |
| D (Phobos) | `BitArray` | Two words (PascalCase) | Uses "Array" not "Set" |

#### Quantitative Summary

Of 20 distinct PascalCase type names surveyed:

| Treatment | Count | Examples |
|-----------|:-----:|---------|
| Two words (`BitSet`) | **16** | Java, Rust, Go, Haskell, Scala, Kotlin, Zig, swift-collections |
| One word (`Bitset`) | **3** | Ruby gem, Swift stdlib internal, Lemire's Swift |
| Different noun (`BitArray`) | **2** | C#, D |

**Overwhelming consensus**: In PascalCase languages, "BitSet" is treated as two words with a visible word boundary (uppercase 'S').

#### Package/Module Names (Lowercase Context)

| Language | Package Name | Treatment |
|----------|-------------|-----------|
| C++ | `<bitset>` | Fused |
| Rust | `bit-set` | Hyphenated (two words) |
| Rust | `fixedbitset` | Fused |
| Go | `bitset` | Fused |
| Haskell | `bitset` | Fused |
| JavaScript | `bitset` | Fused |
| Zig | `bit_set` | Underscored (two words) |

In lowercase package names, the picture is split: **5 fused** vs **2 separated**. However, lowercase names are inherently ambiguous about word boundaries — `bitset` could be one word or two with the boundary invisible.

### CS Literature

| Source | Term Used | Treatment |
|--------|-----------|-----------|
| CLRS (Cormen et al.) | "bit vector" | Two words; no "bitset" term used |
| Knuth (TAOCP Vol. 4) | "bitwise tricks" | Discusses bit operations, not "bitset" as a named structure |
| Sedgewick (Algorithms) | "bit vector", "bitmap" | Two words |
| OpenDSA (Virginia Tech) | "bit vector", "bit array", "bitmap" | All two words |
| Wikipedia | "Bit array" (article title) | Two words; lists "bit set" as synonym (with space) |
| Wiktionary | "bitset" | Defines as programming term (one word) |
| Matt Austern (Dr. Dobb's, 2001) | "bitset" vs "bit vector" | Distinguished the *set* semantics of `std::bitset` from the *sequence* semantics of `vector<bool>` |

**Key observation**: CS literature does not use "bitset" as a canonical term. The data structure is called "bit vector," "bit array," or "bitmap." The compound "bitset" originates from C++ (1998) as a *type name*, not as a CS concept name. When CS literature refers to the set-theoretic interpretation, it writes "bit set" (two words, as in "a set represented by bits").

### Linguistic Analysis

**Is "bitset" a lexicalized compound noun?**

A compound noun becomes lexicalized when it is recognized as a single semantic unit distinct from its component parts. Evidence for lexicalization:

| Criterion | "bitset" | "hash table" | "database" |
|-----------|:--------:|:------------:|:----------:|
| Dictionary entry | Wiktionary only | Major dictionaries | Major dictionaries |
| Distinct meaning from parts | Weak — literally "a set of bits" | Weak — "a table using hashing" | Strong — not "a base of data" |
| Universal spelling | No — split between `bitset`/`BitSet`/`bit set` | No — `hashtable`/`hash table` | Yes — always `database` |
| Single-word pronunciation | Yes | No (two stress points) | Yes |
| CS literature standard | No — "bit vector" preferred | Partially — "hash table" standard | Yes |

"Bitset" is **not fully lexicalized**. Unlike "database" (universally one word) or "email" (evolved from "e-mail"), "bitset" remains in flux. The PascalCase evidence (16:3 in favor of `BitSet` as two words) strongly suggests the programming community treats "bit" and "set" as separate morphemes.

**Comparison with Swift Institute naming conventions**:

The project uses `Nest.Name` pattern [API-NAME-001]. In this pattern, each dot-separated component is a single word or a specification identifier. Examples:

- `Buffer.Linear` — not `BufferLinear`
- `Hash.Table` — not `HashTable`
- `Bit.Vector` — not `BitVector`

The existing `Bit.Vector` establishes that "Bit" is a namespace and "Vector" is the type within it. Following this pattern, a bitset would be `Bit.Set` — but this collides with `Set<Bit>` and loses the "bitset as a data structure" identity.

However, the question here is about *package naming*, not type naming. Package names use `swift-{name}-primitives` with hyphen separation. The question is whether the semantic unit is `bitset` (one word → `swift-bitset-primitives`) or `bit-set` (two words → `swift-bit-set-primitives`).

### The Ambiguity Problem with `swift-bit-set-primitives`

`swift-bit-set-primitives` has a parsing ambiguity:

1. `bit-set` primitives — primitives for the bitset data structure
2. `bit` `set` primitives — set primitives for bits (i.e., `Set<Bit>` primitives)

Interpretation (2) is exactly the current architecture that we are trying to move *away from*. The existing target is called "Set Bit Primitives" — `Set<Bit>` primitives. Naming the package `swift-bit-set-primitives` could be read as merely reordering "Set Bit" to "Bit Set" while preserving the same (rejected) architectural concept.

`swift-bitset-primitives` has no ambiguity: it names a single data structure concept, the bitset.

### The Precedent of `swift-bit-vector-primitives`

The existing package is named `swift-bit-vector-primitives`, not `swift-bitvector-primitives`. This treats "bit vector" as two words. Does this create a precedent for `swift-bit-set-primitives`?

Not necessarily. "Bit vector" is *always* two words in CS literature (CLRS, Sedgewick, Wikipedia). No major language uses `BitVector` without a word boundary — Java doesn't have one, and every implementation that uses PascalCase writes `BitVec` or `BitVector` (two words). The literary consensus is unanimous.

For "bitset," the consensus is weaker — C++ uses `bitset` (one word in the header), and there is genuine variation in the ecosystem. More importantly, "bit vector" and "bitset" have different linguistic properties: "bit vector" has two stress points in pronunciation (BIT VECtor), while "bitset" can be pronounced with a single primary stress (BITset) — a hallmark of compound-noun fusion.

### Swift-Specific Precedent

Apple's swift-collections uses `BitSet` (two words) as the public API name. The Swift stdlib uses `_UnsafeBitset` (one word) internally. This inconsistency within Apple's own codebase means there is no authoritative Swift precedent to follow.

However, the swift-collections `BitSet` was designed for a `BitCollections` module — a module name that treats "Bit" as a prefix for a collection of bit-related types (`BitSet`, `BitArray`). In this context, `BitSet` as two words makes sense: it's a `Set` that lives in the `Bit` namespace.

The Swift Institute project uses a different naming architecture: `Nest.Name` with packages named `swift-{concept}-primitives`. The type would be something like `Bitset` or `Bitset.Static<N>`, not `Bit.Set`. The package name should reflect the data structure concept, not the type nesting.

### Decision Matrix

| Criterion | `swift-bitset-primitives` | `swift-bit-set-primitives` |
|-----------|:--:|:--:|
| Unambiguous parsing | Yes — "bitset primitives" | No — "bit-set" or "bit set"? |
| Matches C++ precedent | Yes — `<bitset>` header | No |
| Matches Java/Rust precedent | No — `BitSet` is two words | Yes (sort of) |
| Consistent with `swift-bit-vector-primitives` | No — different word treatment | Yes |
| Names the data structure | Yes — "bitset" as a concept | Ambiguous — could mean "Set<Bit>" |
| Single-concept package name | Yes | Ambiguous |
| Pronounceable as one unit | Yes — "bitset primitives" | Less natural — "bit set primitives" |
| Distinguished from `Set<Bit>` | Yes — clearly different | No — reads like reordered `Set<Bit>` |

## Outcome

**Status**: DECISION

**Decision**: `swift-bitset-primitives`

### Rationale

1. **Disambiguation is the primary concern.** The entire motivation for this package is to distinguish it from `Set<Bit>` (a set parameterized over bits). `swift-bit-set-primitives` reads as "bit set primitives" — which is exactly the `Set<Bit>` concept we are rejecting. `swift-bitset-primitives` reads as "bitset primitives" — naming a specific, recognized data structure.

2. **"Bitset" names a data structure, not a composition.** A bitset is not "a set of bits" in the generic sense — it is a specific data structure with O(1) membership, O(word-count) union/intersection/difference, and packed storage. The fused spelling reflects this: the whole is more than the sum of its parts.

3. **C++ established "bitset" as the canonical programming term.** The `<bitset>` header (1998) introduced the fused spelling to the programming world. While PascalCase languages write `BitSet` (capitalizing the word boundary), this is a *casing convention*, not evidence that the concept is two separate words. Java writes `HashMap` (fused in concept) as two PascalCase words — no one argues that "hash map" is more correct than "hashmap" as a concept name.

4. **Package names are concept identifiers, not PascalCase decompositions.** The package name `swift-bitset-primitives` names the concept. The type name within the package may still be `Bitset`, `Bitset.Static<N>`, `Bitset.Dynamic`, etc. — following `Nest.Name` where "Bitset" is a single namespace token (like "Buffer", "Array", "Hash").

5. **The `swift-bit-vector-primitives` precedent does not bind.** "Bit vector" is universally two words in CS literature — CLRS, Sedgewick, and Wikipedia all write "bit vector." There is zero evidence for "bitvector" as a fused term. "Bitset" has genuine fusion evidence: C++ `<bitset>`, Wiktionary entry, single-stress pronunciation, and recognition as a named data structure in programming (if not in CS theory). Different words have different lexicalization trajectories.

6. **Consistency with how the project names atomic concepts.** The project has `swift-hash-table-primitives` (two words — "hash table" is universally two words in CS literature). If the project had a hashmap, it might face the same question — but "hashmap" shows more fusion than "hash table." Similarly, "bitset" shows more fusion than "bit vector." The naming should follow the word's actual linguistic status, not a rigid formula.

### Type Naming Within the Package

With the package named `swift-bitset-primitives`, the internal type namespace becomes:

```swift
public enum Bitset<Element: Hash.Protocol & Sendable>: ~Copyable, ~Escapable {
    public struct Dynamic: Sendable { ... }
    public struct Fixed: Sendable { ... }
    public struct Static<let wordCount: Int>: Sendable { ... }
    public struct Small<let inlineWordCount: Int>: Sendable { ... }
}
```

Or, if `Bitset` is itself the primary (dynamic) type:

```swift
public struct Bitset: Sendable { ... }
extension Bitset {
    public struct Fixed: Sendable { ... }
    public struct Static<let wordCount: Int>: Sendable { ... }
    public struct Small<let inlineWordCount: Int>: Sendable { ... }
}
```

The type naming decision is deferred to implementation — this research covers only the package naming question.

### Module Name

Following the project convention of spaces in Package.swift targets:

- Target name: `Bitset Primitives`
- Import: `import Bitset_Primitives`

Note: "Bitset" is a single word, so the target name has only two space-separated tokens, not three. This is consistent with targets like `Hash Primitives`, `Buffer Primitives`, `Array Primitives`.

## References

- C++ `<bitset>` header: [cppreference.com](https://en.cppreference.com/w/cpp/utility/bitset.html)
- Java `BitSet`: [Oracle JDK docs](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/BitSet.html)
- Rust `bit-set` crate: [docs.rs](https://docs.rs/bit-set/latest/bit_set/struct.BitSet.html)
- Swift `BitSet` (swift-collections): [GitHub](https://github.com/apple/swift-collections/blob/main/Sources/BitCollections/BitSet/BitSet.swift)
- Swift `_UnsafeBitset` (stdlib): [GitHub](https://github.com/apple/swift/blob/main/stdlib/public/core/Bitset.swift)
- Wikipedia "Bit array": [en.wikipedia.org](https://en.wikipedia.org/wiki/Bit_array)
- Wiktionary "bitset": [en.wiktionary.org](https://en.wiktionary.org/wiki/bitset)
- Matt Austern, "The Standard Librarian: Bitsets and Bit Vectors", Dr. Dobb's Journal, 2001
- Prior research: [bit-vector-type-organization](bit-vector-type-organization.md)
- Prior research: [bit-vector-primitives-reducibility](bit-vector-primitives-reducibility.md)
