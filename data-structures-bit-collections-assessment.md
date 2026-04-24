# Bit Collections — Post-Refactor Assessment

<!--
---
version: 2.0.0
last_updated: 2026-02-12
status: RECOMMENDATION
predecessor: v1.0.0 (Stack Migration Assessment)
---
-->

## Context

Buffer-primitives, storage-primitives, and memory-primitives were refactored. This assessment audits the bit collection data structures for correctness, convention compliance, and integration with the refactored stack. Five packages are audited: swift-bitset-primitives, swift-bit-vector-primitives, swift-bit-primitives, swift-bit-index-primitives, and swift-bit-pack-primitives.

## Summary

The five Bit Collections packages exhibit a clear maturity gradient. **swift-bit-primitives**, **swift-bit-index-primitives**, and **swift-bit-pack-primitives** form a clean foundational layer with excellent naming, typed indexing, and zero Foundation imports. **swift-bit-vector-primitives** builds on these with deep primitives integration (`Bit.Pack`, `Bit.Index`, `Property`, typed arithmetic), but retains raw `UnsafeMutablePointer<UInt>` management in the base `Bit.Vector` type and uses `ContiguousArray<UInt>` in Copyable variants instead of the refactored buffer/storage stack. **swift-bitset-primitives** is the least integrated: it has zero primitives dependencies, uses raw `Int` arithmetic for all bit addressing, and does not use `Bit.Pack`, `Bit.Index`, or any typed indexing whatsoever. No package imports Foundation. All throwing methods use typed throws. Naming is excellent across all packages (proper `Nest.Name` pattern). The primary findings are: (1) one type per file violation in `Bit.Vector.Error.swift`, (2) multiple tag types per file in Statistic files, (3) `Bit.Vector.Static.isFull` has a semantic bug, (4) duplicate `init(normalizing:)` definition in bit-primitives, (5) bitset-primitives has zero integration with the primitives ecosystem, and (6) no package has migrated to the refactored buffer/storage/memory stack.

---

## Bitset Primitives (swift-bitset-primitives)

### Current State

Single module: `Bitset Primitives`. Contains 22 source files providing four variants of a packed-bit set-of-integers type:

| Type | Purpose |
|------|---------|
| `Bitset` | Dynamically-growing bitset, `ContiguousArray<UInt>` storage |
| `Bitset.Fixed` | Fixed-capacity bitset, throws on overflow |
| `Bitset.Static<let wordCount: Int>` | Compile-time capacity, `InlineArray` storage |
| `Bitset.Small<let inlineWordCount: Int>` | Small-buffer optimization with heap spill |
| `Bitset.Algebra` / `.Fixed.Algebra` / `.Static.Algebra` / `.Small.Algebra` | Set algebra namespace types |
| `Bitset.Algebra.Symmetric` (and variants) | Symmetric difference sub-namespace |
| `Bitset.Relation` (and variants) | Set relation namespace types (subset, superset, disjoint) |
| `Bitset.Iterator` | Wegner/Kernighan sparse iterator for `Bitset` |
| `Bitset.Small.Iterator` | Wegner/Kernighan sparse iterator for `Bitset.Small` |
| `__BitsetError` / `__BitsetFixedError` / `__BitsetStaticError` / `__BitsetSmallError` | Hoisted error types with canonical typealiases |

### Dependencies

```swift
// Package.swift: zero external dependencies
// No imports in any source file beyond implicit Swift standard library
```

The package is entirely self-contained. It does not import any primitives package.

### Storage Mechanism

- `Bitset`: `ContiguousArray<UInt>` with `storedCapacity: Int` tracking. Growth via appending zero words.
- `Bitset.Fixed`: `ContiguousArray<UInt>` allocated at init with `let capacity: Int`. Never resized.
- `Bitset.Static<N>`: `InlineArray<wordCount, UInt>`. Zero allocation. Compile-time capacity = `wordCount * UInt.bitWidth`.
- `Bitset.Small<N>`: Dual-mode: `InlineArray<inlineWordCount, UInt>` (inline) + optional `ContiguousArray<UInt>?` (heap). `spillToHeap(toInclude:)` copies inline to heap and grows.

All bit addressing uses hand-rolled `member / bitsPerWord` and `member % bitsPerWord` arithmetic. No `Bit.Pack`, `Bit.Index`, or typed indexing is used anywhere.

### Findings

| # | Severity | File:Line | Finding | Convention |
|---|----------|-----------|---------|------------|
| 1 | HIGH | All 22 files | Zero primitives integration. All bit addressing uses raw `Int` division/modulo rather than `Bit.Pack<UInt>.Location`. `bitsPerWord` is `UInt.bitWidth` rather than using the typed `Affine.Discrete.Ratio` system. | [IMPL-INTENT] |
| 2 | HIGH | All files using `Int` for member/capacity/count | Raw `Int` used for member indices, capacity, count, word indices, and bit indices. No typed `Index<T>`, `Ordinal`, `Cardinal`, or `Count` usage. | [IDX-*], [CONV-*] |
| 3 | MEDIUM | `Bitset.swift:29` | `bitsPerWord` is `static var bitsPerWord: Int { UInt.bitWidth }`. Same pattern repeated in `Fixed`, `Static`, `Small`. Should use `Bit.Pack<UInt>.bitWidth` or `Affine.Discrete.Ratio<UInt, Bit>.bitsPerWord`. | [IMPL-INTENT] |
| 4 | MEDIUM | `Bitset.swift:32`, `Bitset.Fixed.swift:25`, all variants | Storage is `ContiguousArray<UInt>` with no integration with buffer/storage/memory stack. `Bitset.Small` has hand-written spill logic. | Stack integration |
| 5 | MEDIUM | `Bitset.Algebra.swift:33-51` | `Bitset.Algebra` copies entire `ContiguousArray<UInt>` storage into a snapshot type for non-mutating operations. Same for `Relation`, `Algebra.Symmetric`, and all variant equivalents. A pointer-based view (like `Bit.Vector.Ones.View`) would avoid these copies. | Performance |
| 6 | MEDIUM | `Bitset.swift:214` | `try! insert(member)` in `init<S: Swift.Sequence>`. The `insert` method only throws for negative members, and the sequence is unconstrained, so a negative member will cause a runtime trap. The `try!` is technically safe for non-negative inputs but obscures the failure mode. | [API-ERR-001] |
| 7 | LOW | `Bitset.swift:242-244` | `description` uses `Swift.Array(self.prefix(10))` -- imports `Swift.Array` but the type could iterate directly. Minor. | -- |

### ~Copyable Status

Not applicable. All Bitset variants are `Copyable` and `Sendable`. The types store `UInt` words (value types). No `~Copyable` element support is needed. No constraint propagation issues.

---

## Bit Vector Primitives (swift-bit-vector-primitives)

### Current State

Single module: `Bit Vector Primitives`. Contains 49 source files providing five variants of packed bit storage plus supporting types:

| Type | Purpose |
|------|---------|
| `Bit.Vector` | Fixed-capacity ~Copyable bitmap with `UnsafeMutablePointer<UInt>` |
| `Bit.Vector.Static<let wordCount: Int>` | Fixed-capacity Copyable bitmap with `InlineArray` |
| `Bit.Vector.Dynamic` | Growable bit array with `ContiguousArray<UInt>` |
| `Bit.Vector.Bounded` | Fixed-capacity bit array with `ContiguousArray<UInt>` |
| `Bit.Vector.Inline<let wordCount: Int>` | Fixed-capacity bit array with `InlineArray` |
| `Bit.Vector.Set` / `.Clear` / `.Pop` / `.Ones` / `.Zeros` | Tag/namespace enums for property-based API |
| `Bit.Vector.Ones.View` | Pointer-based non-mutating view for iterating set bits |
| `Bit.Vector.Ones.View.Iterator` | Wegner/Kernighan sparse iterator |
| `Bit.Vector.Ones.Static<N>` | InlineArray-based set-bit sequence |
| `Bit.Vector.Zeros.View` / `.View.Iterator` / `.Static<N>` | Analogous for clear bits |
| `Bit.Vector.Dynamic.Iterator` / `Bounded.Iterator` / `Inline.Iterator` | Dense bit iterators |
| `Bit.Vector.Dynamic.Toggle` / `.Statistic` / `.All` | Property tag types |
| `Bit.Vector.Bounded.Statistic` / `.All` / `.Capacity` | Property tag types |
| `Bit.Vector.Inline.Statistic` / `.All` / `.Capacity` | Property tag types |
| `__BitVectorDynamicError` / `__BitVectorBoundedError` / `__BitVectorInlineError` | Hoisted error types |

### Dependencies

```swift
.package(path: "../swift-bit-primitives")       // Bit, Bit.Index
.package(path: "../swift-bit-pack-primitives")  // Bit.Pack<UInt>, Location
.package(path: "../swift-property-primitives")  // Property<Tag, Base>.View
.package(path: "../swift-vector-primitives")    // Vector namespace
.package(path: "../swift-sequence-primitives")  // Sequence.Protocol
```

Internal imports: `Affine_Primitives`, `Index_Primitives` (transitive through bit-index and bit-pack).

**Not imported**: `Memory_Primitives`, `Storage_Primitives`, `Buffer_Primitives`.

Re-exports via `exports.swift`: `Bit_Primitives`, `Bit_Index_Primitives`, `Bit_Pack_Primitives`, `Vector_Primitives`, `Sequence_Primitives`.

### Storage Mechanism

- `Bit.Vector`: `UnsafeMutablePointer<UInt>` with manual `allocate(capacity:)` and `deallocate()` in init/deinit. Word count: `Index<UInt>.Count`. ~Copyable with `@unchecked Sendable`.
- `Bit.Vector.Static<N>`: `InlineArray<wordCount, UInt>`. No allocation.
- `Bit.Vector.Dynamic`: `ContiguousArray<UInt>` with word-at-a-time append growth. Count: `Bit.Index.Count`.
- `Bit.Vector.Bounded`: `ContiguousArray<UInt>` allocated at init. Count: `Bit.Index.Count`. Capacity: `Bit.Index.Count`.
- `Bit.Vector.Inline<N>`: `InlineArray<wordCount, UInt>`. Count: `Bit.Index.Count`.

Bit addressing uses `Bit.Pack<UInt>.Location` throughout (correct typed indexing).

### Findings

| # | Severity | File:Line | Finding | Convention |
|---|----------|-----------|---------|------------|
| 1 | CRITICAL | `Bit.Vector.Static+set.swift:30-34`, `Bit.Vector.Static+clear.swift:30-34` | `Property.View` extension uses method-level generic constraint `<let wordCount: Int>() where Base == Bit.Vector.Static<wordCount>` rather than extension-level constraint. While this works for Copyable types (UInt elements), it sets a pattern that would fail for `~Copyable` elements per the ~Copyable extension constraint propagation rule. Not currently broken, but a footgun pattern. | [MEM-COPY-*] |
| 2 | HIGH | `Bit.Vector.Error.swift:18-34` | Three hoisted error types (`__BitVectorDynamicError`, `__BitVectorBoundedError`, `__BitVectorInlineError`) defined in a single file. Violates one-type-per-file rule. | [API-IMPL-005] |
| 3 | HIGH | `Bit.Vector.Dynamic.Statistic.swift:17-22` | Two tag types (`Statistic`, `All`) declared in the same file. | [API-IMPL-005] |
| 4 | HIGH | `Bit.Vector.Bounded.Statistic.swift:17-25` | Three tag types (`Statistic`, `All`, `Capacity`) declared in the same file. | [API-IMPL-005] |
| 5 | HIGH | `Bit.Vector.Inline.Statistic.swift:17-25` | Three tag types (`Statistic`, `All`, `Capacity`) declared in the same file. | [API-IMPL-005] |
| 6 | HIGH | `Bit.Vector.Dynamic+returning.swift:18` | Tag type `Toggle` declared in a file that also contains `Property.View` extensions for `Set` and `Clear` tags. Multiple types and multi-tag operations in one file. | [API-IMPL-005] |
| 7 | HIGH | `Bit.Vector.swift:48` | `_words: UnsafeMutablePointer<UInt>` with manual `allocate`/`deallocate`. This is exactly the pattern the refactored `Storage.Heap<UInt>` is designed to replace. Raw pointer management bypasses the stack. | Stack integration |
| 8 | HIGH | `Bit.Vector.swift:73` | Non-null sentinel: `UnsafeMutablePointer(bitPattern: 0x1)!` for empty case. This is a low-level pointer trick that the storage stack should eliminate. | Stack integration |
| 9 | MEDIUM | `Bit.Vector.Static.swift:104-109` | `isFull` checks `_storage[i] != ~0` for every word. If capacity is not word-aligned (i.e., the last word has unused high bits), this will incorrectly report `false` for a vector that has all capacity bits set but whose last word has trailing zeros in the unused portion. The `popcount == capacity` check (line 134 in the non-static `Bit.Vector`) would be correct. Pre-existing bug. | Correctness |
| 10 | MEDIUM | `Bit.Vector.swift:46-82`, `Bit.Vector.Ones.View.swift:22-41`, `Bit.Vector.Ones.View.Iterator.swift:23-74`, `Bit.Vector.Zeros.View.swift:22-41`, `Bit.Vector.Zeros.View.Iterator.swift:23-74` | Raw `UnsafeMutablePointer<UInt>` captured and propagated through views and iterators. All sites use `unsafe` keyword correctly per Swift 6.2, but the pointer escape pattern is inherent to the ~Copyable + view design. Post-migration to `Storage.Heap`, these would capture the storage handle instead. | [MEM-SAFE-*] |
| 11 | MEDIUM | `Bit.Vector.Dynamic+Sequence.swift:22-27` | `Iterator` uses `count: Int` and `index: Int` (raw `Int`), not typed `Bit.Index.Count` / `Bit.Index`. The iterator was written against stdlib conventions (Int-based) rather than primitives conventions. Same issue in `Bounded+Sequence.swift:22-27` and `Inline+Sequence.swift:22-27`. | [IDX-*] |
| 12 | MEDIUM | `Bit.Vector.Dynamic+ones.swift:49` | Uses `Bit.Index(__unchecked: (), Ordinal(UInt(globalIndex)))` to construct a `Bit.Index` from a raw `Int`. The `__unchecked` initializer bypasses validation. This is an internal optimization but could mask bugs. Same at `Dynamic+zeros.swift:51`. | [MEM-SAFE-*] |
| 13 | MEDIUM | `Bit.Vector.Dynamic+growth.swift:22`, `Bit.Vector.Bounded+growth.swift:25` | `Int(bitPattern: loc.word)` casts typed `Index<UInt>` to raw `Int` for `ContiguousArray` subscripting. Same at `Dynamic+growth.swift:84,93`. This is necessary because `ContiguousArray` only accepts `Int` subscripts, but it punctures the typed indexing abstraction. A buffer that accepts typed indices would eliminate this. | [CONV-*] |
| 14 | LOW | `Bit.Vector.Ones.Static.Iterator.swift:23` | Uses `_wordIndex: Int` (raw `Int`) for iteration instead of `Index<UInt>`. The non-static `Ones.View.Iterator` uses `_wordIndex: Index<UInt>`. Inconsistency. Same in `Zeros.Static.Iterator.swift:23`. | [IDX-*] |
| 15 | LOW | `exports.swift:4-8` | Re-exports 5 dependency modules via `@_exported import`. This is correct and intentional for consumer convenience. No issue. | -- |

### ~Copyable Status

`Bit.Vector` is `~Copyable` with correct ownership: `deinit` deallocates the pointer, `take()` enables ownership transfer via pointer swap. The `@unchecked Sendable` conformance is necessary for the raw pointer but should be revisited after stack migration (where `Storage.Heap` may provide Sendable natively).

`Bit.Vector.Ones.View` and `Bit.Vector.Zeros.View` capture the raw pointer as `Copyable` views -- this is safe as long as the view does not outlive the vector. No lifetime annotation enforces this; it relies on API discipline.

The Copyable variants (Dynamic, Bounded, Inline, Static) have no `~Copyable` concerns. Elements are `UInt` (Copyable). Tag types are all empty enums (Sendable, Copyable).

---

## Bit Primitives (swift-bit-primitives)

### Current State

Four modules within a single package:

| Module | Files | Purpose |
|--------|-------|---------|
| `Bit Primitives Core` | 2 | `Bit` enum (`.zero`/`.one`) and `Bit.Order` (`.msb`/`.lsb`) |
| `Bit Boolean Primitives` | 4 | Boolean algebra operators (`&`, `\|`, `^`, `~`, NAND, NOR, XNOR, AND-NOT) |
| `Bit Field Primitives` | 3 | GF(2) field operations (adding = XOR, multiplying = AND), `Algebra.Field` witness |
| `Bit Primitives Standard Library Integration` | 11 | Conformances: `CaseIterable`, `Codable`, `Comparable`, `CustomStringConvertible`, `ExpressibleByBooleanLiteral`, `ExpressibleByIntegerLiteral`; `Bit.Mask<Word>`, `Bit.Set<Word>`, Cardinal shift operators |
| `Bit Primitives` (umbrella) | 7 | Re-exports + `Bit.Value<Payload>` typealias, `Bit.Order.Value<Payload>`, protocol conformances (`Comparison.Protocol`, `Equation.Protocol`, `Finite.Enumerable`, `Hash.Protocol`), normalizing init |

### Dependencies

```swift
.package(path: "../swift-algebra-field-primitives")
.package(path: "../swift-cardinal-primitives")
.package(path: "../swift-finite-primitives")
.package(path: "../swift-hash-primitives")
.package(path: "../swift-tagged-primitives")
```

Internal module dependencies: `Bit Primitives Core` has no deps. `Bit Boolean Primitives` depends on Core. `Bit Field Primitives` depends on Boolean + `Algebra_Field_Primitives`. `Bit Primitives Standard Library Integration` depends on Boolean + `Cardinal_Primitives`. `Bit Primitives` (umbrella) depends on everything.

### Storage Mechanism

No storage. `Bit` is a `@frozen public enum Bit: UInt8` with two cases. Pure value type with no allocation.

### Findings

| # | Severity | File:Line | Finding | Convention |
|---|----------|-----------|---------|------------|
| 1 | HIGH | `Bit Primitives/Bit.swift:16` and `Bit Primitives Standard Library Integration/Bit+Normalizing.swift:12` | Duplicate definition: `public init(normalizing value: UInt8)` appears in both the `Bit Primitives` umbrella module and the `Standard Library Integration` module. Since `Bit Primitives` imports `Standard Library Integration`, this will cause a compile-time ambiguity or redefinition error depending on how the modules are linked. | Correctness |
| 2 | MEDIUM | `Bit Primitives/Bit.swift:1-6`, `Bit.Value.swift:1-6`, `Bit.Order.Value.swift:1-6` | File headers use generic `File.swift` template instead of proper descriptive names. Not a naming convention issue per se (file names are correct), but the internal header comment is misleading. | Cosmetic |
| 3 | MEDIUM | `Bit Primitives/Bit+Finite.Enumerable.swift:31-53` | Two `Finite.Enumerable` conformances in one file: `Bit: Finite.Enumerable` and `Bit.Order: Finite.Enumerable`. While these are conformance extensions (not type declarations), mixing two distinct type conformances in one file blurs the one-type-per-file principle. | [API-IMPL-005] |
| 4 | MEDIUM | `Bit Primitives Standard Library Integration/Bit+Normalizing.swift:18-20` | `Bit ^ UInt8` operator extension. This operator allows `bit ^ 1` as an idiom, but it creates a mixed-type operator that may surprise users. The `UInt8` operand is masked to `& 1` internally. Questionable API surface. | [API-NAME-002] |
| 5 | LOW | `Bit Boolean Primitives/Bit Compound Operators.swift:79,85` | `andNot` is a compound identifier. Per [API-NAME-002], compound method names are discouraged. However, `and.not` as a nested accessor would be awkward for a binary operation. This may be an acceptable exception for hardware-primitive names (x86 ANDN, ARM BIC). | [API-NAME-002] |
| 6 | LOW | `Bit Primitives Standard Library Integration/Bit+Codable.swift:10-31` | `Bit.Order: Codable` uses `any Decoder` / `any Encoder` parameters in the protocol-required methods. These are existential types (`any`), which is correct per Swift protocol requirements but technically creates an existential. Not a violation since the protocol signature requires it. | -- |
| 7 | LOW | `Bit Primitives Standard Library Integration/FixedWidthInteger+Cardinal.swift:18-54` | Free-standing generic operators (`<<`, `>>`, `<<=`, `>>=`) for `FixedWidthInteger` x `Cardinal.Protocol`. These are defined as module-level functions, not extensions. This is correct for operators but means they are only available when `Bit_Primitives_Standard_Library_Integration` is imported. | -- |

### ~Copyable Status

Not applicable. `Bit` is `@frozen public enum Bit: UInt8` -- inherently Copyable. `Bit.Order` is an enum -- also Copyable. `Bit.Mask<Word>` and `Bit.Set<Word>` are `@frozen` value types with Copyable `Word` constraints. No `~Copyable` concerns.

---

## Bit Index Primitives (swift-bit-index-primitives)

### Current State

Single module: `Bit Index Primitives`. Contains 4 source files:

| File | Contents |
|------|----------|
| `Bit.Index.swift` | `Bit.Index` typealias to `Index_Primitives.Index<Bit>` |
| `Bit.Index+Byte.swift` | `Bit.Index.init(_ index: Index<UInt8>)` -- byte-to-bit conversion |
| `Bit+Affine.Discrete.Ratio.swift` | `Ratio<UInt, Bit>.bitsPerWord`, `Ratio<UInt8, Bit>.bitsPerByte`, generic `Ratio<From, Bit>.bitWidth` |
| `exports.swift` | Re-exports `Bit_Primitives`, `Index_Primitives`, `Affine_Primitives` |

### Dependencies

```swift
.package(path: "../swift-bit-primitives")
.package(path: "../swift-index-primitives")
.package(path: "../swift-affine-primitives")
```

### Storage Mechanism

No storage. This package provides typed indexing infrastructure only. `Bit.Index` is `Index<Bit>` which wraps an `Ordinal` (itself wrapping `UInt`).

### Findings

| # | Severity | File:Line | Finding | Convention |
|---|----------|-----------|---------|------------|
| 1 | -- | -- | No findings. This package is clean, minimal, and well-structured. Each file contains exactly one logical declaration. Naming follows `Nest.Name` pattern. No Foundation imports. All types use proper typed indexing. | -- |

### ~Copyable Status

Not applicable. `Index<Bit>` is a value type wrapper around `Ordinal`/`UInt`. Fully Copyable.

---

## Bit Pack Primitives (swift-bit-pack-primitives)

### Current State

Single module: `Bit Pack Primitives`. Contains 6 source files:

| File | Contents |
|------|----------|
| `Bit.Pack.swift` | `Bit.Pack<Word>` -- packing layout witness (word count, unused bits) |
| `Bit.Pack.Location.swift` | `Bit.Pack<Word>.Location` -- word index, bit offset, mask |
| `Bit.Pack.Words.swift` | `Bit.Pack<Word>.Words` -- word-domain metadata |
| `Bit.Pack.Bits.swift` | `Bit.Pack<Word>.Bits` -- bit-domain metadata (unused bit count) |
| `Bit.Index+Pack.swift` | `Bit.Index.location(bitsPerWord:)` convenience method |
| `exports.swift` | Re-exports `Bit_Primitives`, `Bit_Index_Primitives` |

### Dependencies

```swift
.package(path: "../swift-bit-primitives")
.package(path: "../swift-bit-index-primitives")
```

### Storage Mechanism

No storage. This package provides layout computation only. `Bit.Pack<Word>` is a witness that computes how many words are needed for N bits and where a given bit lives within word storage.

### Findings

| # | Severity | File:Line | Finding | Convention |
|---|----------|-----------|---------|------------|
| 1 | -- | -- | No findings. This package is clean, minimal, and well-structured. Each file contains exactly one logical type. Naming follows `Nest.Name` pattern. No Foundation imports. The `Bit.Pack<Word>` generic constraint `Word: FixedWidthInteger & UnsignedInteger & Sendable` is correct and minimal. | -- |

### ~Copyable Status

Not applicable. All types are simple value types (structs containing `Index` and `Count` values). Fully Copyable.

---

## Cross-Cutting Concerns

### 1. No Package Uses the Refactored Buffer/Storage/Memory Stack

None of the five audited packages import `Memory_Primitives`, `Storage_Primitives`, or `Buffer_Primitives`. The refactored stack is not yet integrated into any bit collection type. The storage landscape is:

| Storage Pattern | Used By | Stack Replacement |
|----------------|---------|-------------------|
| `UnsafeMutablePointer<UInt>` + manual alloc/dealloc | `Bit.Vector` | `Storage.Heap<UInt>` |
| `ContiguousArray<UInt>` | `Bit.Vector.Dynamic`, `.Bounded`, `Bitset`, `Bitset.Fixed` | `Buffer.Linear<UInt>` or keep `ContiguousArray` |
| `InlineArray<N, UInt>` | `Bit.Vector.Static<N>`, `.Inline<N>`, `Bitset.Static<N>` | No migration needed (inline is correct) |
| `InlineArray` + optional `ContiguousArray` | `Bitset.Small<N>` | Potentially `Buffer.Linear.Small<UInt>` if it exists |

### 2. Bitset Has Zero Primitives Integration

The `swift-bitset-primitives` package predates the current primitives ecosystem. Every bit-addressing operation uses raw `Int` division and modulo. It does not import `Bit_Primitives`, `Bit_Pack_Primitives`, `Index_Primitives`, or any other primitives package. This is the single largest convention gap across all five packages. Before any stack migration, bitset-primitives needs a prerequisite step: adopt `Bit.Pack<UInt>.Location` for word/bit addressing and typed indexing for internal operations.

### 3. One-Type-Per-File Violations

The most frequent convention violation across the packages is [API-IMPL-005]:

- `Bit.Vector.Error.swift` -- 3 error types in one file
- `Bit.Vector.Dynamic.Statistic.swift` -- 2 tag types (Statistic, All)
- `Bit.Vector.Bounded.Statistic.swift` -- 3 tag types (Statistic, All, Capacity)
- `Bit.Vector.Inline.Statistic.swift` -- 3 tag types (Statistic, All, Capacity)
- `Bit.Vector.Dynamic+returning.swift` -- Toggle tag type + Property.View extensions for 3 different tags
- `Bit+Finite.Enumerable.swift` -- 2 type conformances (Bit and Bit.Order)

These are all in the "tag types are small empty enums" category, where the one-type-per-file rule creates many tiny files. The tradeoff is real, but the convention is clear.

### 4. Raw `Int` Usage in Bitset and Bit Vector Iterators

Two distinct patterns of raw `Int` usage exist:

**Bitset** (all variants): All member indices, capacity, count, word indices, and bit indices are `Int`. This is the user-facing API (set-of-integers), so `Int` for member values is semantically correct. But the internal word/bit decomposition should use typed indexing.

**Bit Vector iterators** (Dynamic, Bounded, Inline): The dense iterators (`Bit.Vector.Dynamic.Iterator`, etc.) use `count: Int` and `index: Int` internally, even though the parent types use `Bit.Index.Count` and `Bit.Index`. This inconsistency means the iterators bypass the typed indexing that the rest of the package uses. The sparse iterators (`Ones.View.Iterator`, etc.) correctly use typed `Index<UInt>`.

### 5. `try!` Usage

`try!` appears in 10 locations across bitset-primitives and bit-vector-primitives. In all cases, the forced try is used with affine arithmetic operations (`.predecessor.exact()`, `.subtract.exact()`) where the preconditions are guaranteed by prior range checks. These are safe but cannot be statically verified by the compiler.

### 6. Bit.Vector.Static.isFull Bug

`Bit.Vector.Static.isFull` (line 104-109 of `Bit.Vector.Static.swift`) checks `_storage[i] != ~0` for every word. If capacity is not a multiple of `UInt.bitWidth` (64 on 64-bit platforms), the last word will have unused high bits that are zero. The `isFull` check will incorrectly return `false` for a vector that has all capacity-range bits set. The fix is either to mask the last word or to use `popcount == capacity`.

Note: `Bit.Vector` (the ~Copyable base type) at line 134 uses `popcount == capacity`, which is correct. The Static variant diverges.

### 7. Duplicate `init(normalizing:)` in Bit Primitives

`Bit.init(normalizing value: UInt8)` is defined in both:
- `/Users/coen/Developer/swift-primitives/swift-bit-primitives/Sources/Bit Primitives/Bit.swift:16`
- `/Users/coen/Developer/swift-primitives/swift-bit-primitives/Sources/Bit Primitives Standard Library Integration/Bit+Normalizing.swift:12`

Since `Bit Primitives` imports `Bit Primitives Standard Library Integration` (transitively through the umbrella), this creates a duplicate definition. The implementation is identical in both files. One should be removed.

---

## Recommendations

### Priority 1 (Critical / Correctness)

1. **Remove duplicate `init(normalizing:)` in bit-primitives.** Delete the definition in `Bit Primitives/Bit.swift:12-18`. Keep the one in `Bit Primitives Standard Library Integration/Bit+Normalizing.swift`.

2. **Fix `Bit.Vector.Static.isFull` bug.** Replace the word-by-word `~0` check with `popcount == Self.capacity` to correctly handle non-word-aligned capacities.

### Priority 2 (High / Convention Compliance)

3. **Split `Bit.Vector.Error.swift` into three files.** Create `Bit.Vector.Dynamic.Error.swift`, `Bit.Vector.Bounded.Error.swift`, `Bit.Vector.Inline.Error.swift`, each containing one hoisted error type with its canonical typealias.

4. **Split Statistic/All/Capacity tag types into separate files.** For each of `Dynamic.Statistic.swift`, `Bounded.Statistic.swift`, `Inline.Statistic.swift`: extract each tag type and its property extension into its own file. E.g., `Bit.Vector.Dynamic.Statistic.swift`, `Bit.Vector.Dynamic.All.swift`.

5. **Split `Bit.Vector.Dynamic+returning.swift`.** Extract `Toggle` tag type into `Bit.Vector.Dynamic.Toggle.swift`. Keep the three `Property.View` returning extensions in appropriately named files (or consolidate each tag's property extensions with its tag type file).

### Priority 3 (Medium / Improvement)

6. **Adopt `Bit.Pack` addressing in bitset-primitives.** Add `swift-bit-pack-primitives` as a dependency. Replace all `member / bitsPerWord` / `member % bitsPerWord` patterns with `Bit.Pack<UInt>.Location(index:bitsPerWord:)`. This is a prerequisite for any future stack migration.

7. **Migrate `Bit.Vector` to Storage.Heap.** Replace `UnsafeMutablePointer<UInt>` with the refactored storage stack. Eliminate the non-null sentinel pattern. Update `Ones.View` and `Zeros.View` to capture the storage handle.

8. **Use typed indexing in dense iterators.** Replace `count: Int` / `index: Int` in `Bit.Vector.Dynamic.Iterator`, `Bounded.Iterator`, and `Inline.Iterator` with `Bit.Index.Count` / `Bit.Index` to align with the rest of the package.

9. **Split `Bit+Finite.Enumerable.swift`.** Extract `Bit.Order: Finite.Enumerable` into `Bit.Order+Finite.Enumerable.swift`.

### Priority 4 (Low / Future)

10. **Evaluate Bitset composing Bit.Vector.** Per the existing [bitset-architecture-ideal-model](../bitset-architecture-ideal-model.md) research, Bitset should compose Bit.Vector for storage rather than managing its own `ContiguousArray<UInt>`. This would eliminate the duplication of growth logic, word addressing, and algebra operations. This is a larger architectural change that depends on items 6 and 7 being completed first.

11. **Consider stack migration for Copyable variants.** `Bit.Vector.Dynamic` and `Bit.Vector.Bounded` use `ContiguousArray<UInt>` which works correctly. Migration to `Buffer.Linear<UInt>` would provide typed subscripting (eliminating `Int(bitPattern: loc.word)` casts) and geometric growth policies but is not strictly necessary for correctness.

12. **Evaluate `Bitset.Algebra`/`Relation` snapshot copies.** The current design copies storage into namespace types for each algebra/relation operation. A pointer-based view design (like `Bit.Vector.Ones.View`) would avoid allocations but changes the API ergonomics. This is a design tradeoff, not a bug.
