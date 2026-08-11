# Split Storage Naming

<!--
---
version: 1.2.0
last_updated: 2026-02-07
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-storage-primitives]
normative: false
upstream: split-storage-design.md (v3.0.0, type design)
changelog:
  - 1.2.0 (2026-02-07): Status promoted to RECOMMENDATION following collaborative
    discussion convergence on split-storage-design.md v3.0.0.
  - 1.1.0 (2026-02-07): Updated for N-ary anticipation and field handle terminology
    per nary-soa-feasibility experiment findings.
  - 1.0.0 (2026-02-07): Initial naming literature analysis.
---
-->

## Context

The `split-storage-design.md` research proposes `Storage<Element>.Split<Lane>` — a dual-lane heap storage type providing two typed arrays in a single allocation. The design is sound, but the name `Split` was chosen without literature analysis. This document investigates whether `Split` is the canonical term of art for this storage pattern.

**Trigger**: [RES-001] Investigation — naming affects the permanent API surface and should reflect established terminology.

**Scope**: Per [RES-002a], this is package-specific to storage-primitives (naming a type within the Storage namespace).

---

## Question

Is `Split` the canonical term of art for a dual-lane, co-indexed storage type? If not, what is the principled name?

---

## Prior Art Survey [RES-021]

### 1. Academic Database Literature

The foundational academic work on separating a record's fields into parallel arrays:

| Source | Year | Term | Description |
|--------|------|------|-------------|
| Copeland & Khoshafian | 1985 | **Decomposition Storage Model (DSM)** | N-ary records decomposed into binary relations (attribute, surrogate) stored column-wise |
| MonetDB (Boncz et al.) | 1999–2005 | **Binary Association Table (BAT)** | Two-column tables: `(oid, value)` pairs. Vertical fragmentation. |
| Stonebraker et al. (C-Store) | 2005 | **Column-oriented** | Projections, column groups, read-optimized stores |
| Abadi et al. | 2006 | **Column-store** | Distinction from row-store; term now standard in database literature |
| Apache Arrow | 2016– | **Columnar format** | In-memory columnar representation; individual arrays called "columns" |

**Key insight**: The database community uses **"columnar"** or **"column-oriented"** for the general pattern of storing each field as a separate contiguous array. Individual arrays are called **"columns"**. The term **"split"** does not appear in this literature.

### 2. Type Theory and Functional Programming

The SoA/AoS transformation has a type-theoretic characterization:

| Source | Year | Term | Description |
|--------|------|------|-------------|
| Hinze (2000), Gibbons (2017) | 2000, 2017 | **Distributive/Representable/Naperian functors** | `F(A × B) ≅ F(A) × F(B)` — the isomorphism that makes SoA/AoS interconversion type-safe |
| Bird & de Moor | 1997 | **`unzip`** | The transformation from `[(A, B)]` to `([A], [B])` |

**Key insight**: The type-theoretic name is **`distribute`** (or its inverse, `zip`). This is precise but too abstract for a storage type name. The isomorphism only holds for **fixed-shape** (Representable) containers — which is exactly our case (fixed-capacity storage).

### 3. Compiler Optimization Literature

Compilers transform AoS to SoA as an optimization:

| Source | Year | Term | Description |
|--------|------|------|-------------|
| LLVM | — | **Structure splitting** (DLO pass) | Splits global structs into per-field arrays for cache locality |
| GCC | — | **Structure reorganization** | Same optimization, different name |
| Chilimbi et al. (PLDI 1999) | 1999 | **Structure splitting** | Hot/cold field separation for cache optimization |
| Truong et al. | 1998 | **Data layout optimization** | Array-of-struct vs struct-of-array transformations |

**Key insight**: Compiler literature uses **"structure splitting"** — the verb "split" describing the transformation from one struct into parallel arrays. This is the strongest precedent for "split" as a term. However, it describes the **action**, not the **resulting layout**.

### 4. Systems Programming Languages

Languages and libraries providing SoA facilities:

| Language/Library | Name | Term for Individual Array | Notes |
|------------------|------|---------------------------|-------|
| Zig | `std.MultiArrayList` | **field** | "Also known as 'Struct-Of-Arrays' or 'SOA'" |
| Rust (soa-rs) | `Soa<T>` | **field** (via `Soars` derive) | Macro-generated per-field accessors |
| Rust (soak) | `RawTable` | **column** | Runtime column management |
| C++ (soagen) | `Table` | **column** | Template-based SoA table |
| Odin | `#soa [N]T` | (implicit) | Language keyword; no name for sub-arrays |
| Jai | `struct SOA` | (implicit) | Language keyword |
| ISPC | `soa<N> T` | (implicit) | SPMD-on-SIMD layout keyword |
| Bevy (ECS) | `Table` | **column** | Archetype-based entity storage |
| Flecs (ECS) | `ecs_table_t` | **column** (`ecs_column_t`) | C-based ECS |

**Key insight**: No language or library uses **"split"** as the type name. The dominant type-level names are **"SoA"**, **"MultiArrayList"**, and **"Table"**. Individual sub-arrays are called **"fields"** (Rust/Zig) or **"columns"** (databases/ECS).

### 5. Apple Ecosystem

Apple frameworks with parallel-array patterns:

| Framework | Term | Description |
|-----------|------|-------------|
| vImage | **Planar** (`vImage.PlanarF`, `vImage.Planar8`) | Image data where each channel is a separate contiguous buffer. Opposite: "interleaved" or "chunky". |
| CoreVideo | **Planar** / **BiPlanar** | `CVPixelBufferIsPlanar()`, `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`. Individual buffers called "planes". |
| BNNS | **Planar** | Tensor layout with per-plane data arrays |
| CoreAudio | **Non-interleaved** | Same pattern but explicitly NOT called "planar" in audio. Per-channel buffers in `AudioBufferList`. |
| Accelerate (vDSP) | **Split complex** (`DSPSplitComplex`) | Real and imaginary components in separate arrays. Uses "split" explicitly. |
| Swift Evolution (SE-0229) | **SoA** | Only mention of "SoA" in Swift Evolution |
| Swift Forums | — | Essentially no SoA discussion |

**Key insight**: Apple uses **"planar"** for separated-channel image/video storage. The exception is `DSPSplitComplex`, which uses **"split"** for a binary separation of real/imaginary components — structurally identical to our pattern. This is the closest Apple precedent.

### 6. "Split" in Computer Science

Surveying how "split" is used across CS:

| Context | Usage | Structural Analog |
|---------|-------|-------------------|
| CPython PEP 412 | **Split table** | Dict where keys and values are stored in separate arrays. **Strongest structural analog.** |
| Google Spanner | **Split** (noun) | A contiguous range of rows used as a data distribution unit. Different meaning. |
| B-tree | **Split** (verb) | Dividing an overfull node. Different meaning. |
| Buddy allocator | **Split** (verb) | Dividing a memory block. Different meaning. |
| Swift stdlib | `.split(separator:)` | String/Array partitioning. Different meaning. |
| Accelerate | `DSPSplitComplex` | Binary separation into parallel arrays. **Exact structural analog.** |

**Key insight**: "Split" as a storage layout descriptor (not a verb) appears in two relevant precedents: CPython's **split table** (PEP 412) and Apple's **`DSPSplitComplex`**. Both describe a structure where logically-paired data is physically separated into parallel arrays — exactly our pattern.

---

## Analysis

### What `Storage.Split` Actually Is

Before evaluating names, we must be precise about what the type represents. `Storage<Element>.Split<Lane>` is:

1. **Binary today, N-ary tomorrow** — currently two lanes, designed to generalize to `Split<each Lane: ~Copyable>` when parameter packs support `~Copyable` (see `nary-soa-feasibility` experiment)
2. **Co-indexed** — all lanes share the same index domain `Index<Element>`
3. **Heterogeneous** — lanes have different types (`Element` and `Lane`)
4. **Single-allocation** — one `ManagedBuffer` with computed offsets
5. **Asymmetric** — the primary lane (`Element`) defines the index domain; secondary lane(s) are annotation/metadata
6. **Field-handle-accessed** — access via `Storage.Field<Value>` handles, not named accessors (enables N-ary generalization)

The binary version is NOT a general N-ary SoA type, but its access pattern (field handles) is designed to generalize without call-site changes. Individual sub-arrays are called **"fields"** — aligning with Zig (`std.MultiArrayList`) and Rust (`soa-rs`) terminology.

### Candidate Evaluation

#### Candidate 1: `Split`

**Provenance**: Compiler literature ("structure splitting"), PEP 412 ("split table"), Apple Accelerate (`DSPSplitComplex`).

| Criterion | Assessment |
|-----------|------------|
| Established in literature | Partial — verb form ("splitting") is canonical in compilers. Adjective/noun form ("split table", "split complex") has narrower but precise precedent. |
| Collision in Swift | None. `Swift.split()` is a method, not a type. No `Storage.Split` or `Split` type exists. |
| Describes the type | Describes the **transformation** (a structure was split into lanes). Does not directly describe the **layout**. |
| Self-documenting | Moderate. "Split storage" suggests "separated into parts" but doesn't say how many or what kind. |
| [API-NAME-001] compliant | Yes. `Storage.Split` is `Namespace.Name`. |
| Apple ecosystem alignment | `DSPSplitComplex` is exact precedent. Not a dominant Apple term but exists in Accelerate. |

**Strengths**: Clean, short, no collisions, Apple precedent in Accelerate, compiler literature connection.
**Weaknesses**: Primarily known as a verb. "Split" doesn't inherently communicate "two parallel arrays."

#### Candidate 2: `Planar`

**Provenance**: Apple vImage, CoreVideo, BNNS. Dominant Apple term for separated-channel storage.

| Criterion | Assessment |
|-----------|------------|
| Established in literature | Strong in Apple media frameworks. Essentially unknown outside Apple/media contexts. |
| Collision in Swift | None. No `Storage.Planar` type exists. |
| Describes the type | Describes the **layout** — data organized in separate "planes." Each plane is a contiguous array. |
| Self-documenting | Good within Apple context. "Planar storage" immediately evokes vImage/CoreVideo patterns for Apple developers. |
| [API-NAME-001] compliant | Yes. `Storage.Planar` is `Namespace.Name`. |
| Apple ecosystem alignment | Strong. This is Apple's own term. |

**Strengths**: Native Apple terminology, layout-descriptive, familiar to Apple developers.
**Weaknesses**: Domain-specific to media/signal processing. "Plane" implies spatial/geometric connotation. Sounds odd for storing `(UInt8, Index<Element>)` pairs. Not used in database, ECS, or general systems literature.

#### Candidate 3: `Columnar`

**Provenance**: Database literature (C-Store, Arrow, DuckDB), ECS (Bevy, Flecs).

| Criterion | Assessment |
|-----------|------------|
| Established in literature | Very strong in databases. The canonical term for the general pattern. |
| Collision in Swift | None. |
| Describes the type | Describes the **layout** — data organized in columns. |
| Self-documenting | Good. "Columnar storage" is widely understood. |
| [API-NAME-001] compliant | Yes. `Storage.Columnar` is `Namespace.Name`. |
| Apple ecosystem alignment | Weak. Apple does not use "columnar" in its frameworks. |

**Strengths**: Universal recognition in data engineering, precisely describes the layout.
**Weaknesses**: Implies N-ary (many columns), not binary. Heavy database connotation. Not a natural fit for "two arrays in one allocation" — feels overweight.

#### Candidate 4: `Paired`

**Provenance**: Mathematics (ordered pairs), Swift `Pair` types (various), functional programming.

| Criterion | Assessment |
|-----------|------------|
| Established in literature | "Paired" appears in some array/buffer contexts but has no strong singular precedent. |
| Collision in Swift | `Pair` types exist in many Swift packages. `Storage.Paired` would be novel. |
| Describes the type | Describes the **relationship** — two things that go together. |
| Self-documenting | Good. "Paired storage" suggests "two co-stored things." |
| [API-NAME-001] compliant | Yes. |
| Apple ecosystem alignment | None. |

**Strengths**: Correctly communicates binary nature, natural English.
**Weaknesses**: No established precedent as a storage pattern name. "Paired" suggests the elements are paired (like zip), not that the arrays are separated.

#### Candidate 5: `Dual`

**Provenance**: Mathematics (dual space, duality), some CS usage.

| Criterion | Assessment |
|-----------|------------|
| Established in literature | "Dual" has strong mathematical meaning (dual space, dual category) which is NOT what we mean. |
| Collision in Swift | Unlikely but "dual" is overloaded in mathematical Swift. |
| Describes the type | Ambiguous — "dual" in math means something specific and different. |
| Self-documenting | Poor for math-literate users. "Dual storage" suggests categorical duality. |
| [API-NAME-001] compliant | Yes. |

**Strengths**: Short, communicates "two."
**Weaknesses**: Mathematical "dual" means something completely different. High confusion risk.

### Comparison Table

| Criterion | Split | Planar | Columnar | Paired | Dual |
|-----------|-------|--------|----------|--------|------|
| Literature precedent | Compiler, PEP 412, DSPSplitComplex | Apple media | Databases, ECS | Weak | Math (wrong meaning) |
| Describes layout | Partially (transformation → result) | Yes (planes) | Yes (columns) | No (relationship) | No (math overload) |
| Communicates binary | No (could be N-ary) | Partially (BiPlanar exists) | No (implies N-ary) | Yes | Yes |
| Apple alignment | `DSPSplitComplex` | vImage, CoreVideo | None | None | None |
| Collision risk | None | None | None | Low | Medium (math) |
| Domain-appropriateness | General | Media-specific | Database-specific | General | General |
| N-ary generalization | `Split<each Lane>` ✓ | `Planar<each Lane>` ? | `Columnar<each Lane>` ✓ | `Paired<each Lane>` ✗ | `Dual<each Lane>` ✗ |
| Reads well in context | `Storage.Split<Lane>` ✓ | `Storage.Planar<Lane>` ? | `Storage.Columnar<Lane>` ? | `Storage.Paired<Lane>` ? | `Storage.Dual<Lane>` ? |

### Key Observation: `DSPSplitComplex`

Apple's `DSPSplitComplex` is the most structurally precise precedent in the Apple ecosystem:

```c
typedef struct DSPSplitComplex {
    float *realp;  // Pointer to real part array
    float *imagp;  // Pointer to imaginary part array
} DSPSplitComplex;
```

This is exactly a binary dual-array: two typed arrays (`float` and `float`) co-indexed, stored separately. The name "split" describes the layout as "one logical entity (complex number) whose components are stored in separate arrays." This maps directly to `Storage.Split<Lane>`: one logical slot whose metadata and payload are stored in separate arrays.

The difference: `DSPSplitComplex` is homogeneous (both lanes are `float`), while `Storage.Split<Lane>` is heterogeneous. But the structural pattern — "separated into parallel contiguous arrays" — is identical.

### Why Not `SoA`?

"SoA" (Structure of Arrays) is the universal recognition term. But:

1. **Abbreviation**: `Storage.SoA<Lane>` reads as jargon, not English. Violates the spirit of clear naming.
2. **Implies N-ary generalization from a struct**: "Structure of Arrays" suggests decomposing an arbitrary struct into per-field arrays. Our type is always binary.
3. **Not Apple convention**: Apple never uses "SoA" in its APIs. `DSPSplitComplex` is called "split," not "SoA."
4. **Documentation, not naming**: "SoA" is the documentation term that explains the *pattern*. The *type name* should be a word, not an acronym.

---

## Theoretical Grounding [RES-022]

The SoA/AoS isomorphism for a fixed-size container `F` is:

```
F(A × B) ≅ F(A) × F(B)
```

This holds when `F` is a **Representable functor** (Naperian functor in Gibbons' terminology) — i.e., `F` has a fixed shape determined by its index type. Fixed-capacity storage is representable: `Storage<capacity>` is isomorphic to `Index<capacity> → Element`.

The "split" operation is the left-to-right direction of this isomorphism:

```
distribute : F(A × B) → F(A) × F(B)
```

The inverse ("zip" or "interleave") is:

```
undistribute : F(A) × F(B) → F(A × B)
```

"Split" names the **distribute** direction: taking an interleaved structure and separating it into parallel arrays. This is type-theoretically precise — `Storage.Split<Lane>` is the `F(A) × F(B)` side of the isomorphism, where `Storage.Heap` would be the `F(A × B)` side (if `A × B` were a single interleaved record).

---

## Outcome

**Status**: RECOMMENDATION

### Assessment

**`Storage.Split` is defensible but not a dominant term of art.**

The name finds support in:
1. **Apple Accelerate**: `DSPSplitComplex` — exact structural analog, Apple-native
2. **Compiler literature**: "structure splitting" — the transformation that produces this layout
3. **CPython PEP 412**: "split table" — binary key/value separation, close structural analog
4. **Type theory**: `distribute` — "split" is the colloquial name for this operation

The name's weakness:
1. **"Split" is primarily a verb** — using it as an adjective/noun requires context
2. **Not the dominant term in any single community** — databases say "columnar," Apple media says "planar," systems say "SoA"

However, no alternative is strictly better:
- **`Planar`** is Apple-native but domain-specific to media — calling `(UInt8, Index<Element>)` storage "planar" is a stretch
- **`Columnar`** implies N-ary database semantics — overweight for a binary type
- **`Paired`** suggests element pairing (like zip), not array separation
- **`Dual`** collides with mathematical duality
- **`SoA`** is an acronym, not a name

### Recommendation

**Retain `Storage<Element>.Split<Lane>`** with the following documentation:

1. The doc comment should reference `DSPSplitComplex` as the structural analog
2. The module documentation should explain the SoA/AoS context
3. Individual sub-arrays are called **"fields"** — accessed via `Storage<Element>.Field<Value>` handles (see `split-storage-design.md` v3.0.0, SQ3)
4. The N-ary generalization `Storage<Element>.Split<each Lane>` reads naturally

The name `Split` correctly describes what the type *is*: a storage whose logical slots have been **split** into co-indexed, physically-separated fields. It reads naturally in both binary and N-ary forms:

```swift
// Binary (today):
var storage: Storage<Index<Element>>.Split<UInt8>
// "Storage of element-indices, split with a byte field."

// N-ary (future):
var storage: Storage<KeyValue>.Split<UInt8, Int>
// "Storage of key-values, split with byte and int fields."
```

### N-ary Naming Compatibility

"Split" generalizes well to N-ary because it describes the **transformation** (splitting a record into parallel arrays), not the **arity** (binary). Unlike "Paired" or "Dual" which bake in binary semantics, "Split" is arity-agnostic — you can split into 2, 3, or N fields.

The strongest alternatives for N-ary also work: "Columnar" is arity-agnostic but carries database connotation. "Planar" is arity-agnostic (Apple has `BiPlanar` for two planes) but carries media connotation. "Split" remains the best balance of generality, Apple precedent (`DSPSplitComplex`), and domain-appropriateness.

### Contingent On

This recommendation is contingent on review of the upstream `split-storage-design.md`. If that document's naming analysis (SQ1) arrives at a different conclusion, this document should be updated to reflect the converged decision.

---

## References

### Internal
- `split-storage-design.md` v3.0.0 (storage-primitives) — type design, SQ1 naming analysis, SQ3 field handle access
- `metadata-parametric-slots.md` (buffer-primitives) — downstream consumer

### Experiments
- `nary-soa-feasibility` (storage-primitives) — validates N-ary SoA patterns; C7 field handle pattern establishes "field" as the sub-array term

### Academic
- Copeland, G. P. & Khoshafian, S. N. (1985). "A decomposition storage model." SIGMOD.
- Boncz, P., Zukowski, M., & Nes, N. (2005). "MonetDB/X100: Hyper-Pipelining Query Execution." CIDR.
- Stonebraker, M. et al. (2005). "C-Store: A Column-oriented DBMS." VLDB.
- Gibbons, J. (2017). "APLicative Programming with Naperian Functors." ESOP.
- Chilimbi, T. M., Hill, M. D., & Larus, J. R. (1999). "Cache-Conscious Structure Layout." PLDI.
- Truong, D., Bodin, F., & Seznec, A. (1998). "Improving Cache Behavior of Dynamically Allocated Data Structures." PACT.

### Language/Library
- Zig: `std.MultiArrayList` — https://ziglang.org/documentation/master/std/#std.MultiArrayList
- Rust soa-rs: `Soa<T>` — https://crates.io/crates/soa-rs
- C++ soagen — https://github.com/marzer/soagen
- Python PEP 412 — https://peps.python.org/pep-0412/

### Apple
- `DSPSplitComplex` — Accelerate framework
- `vImage.PlanarF`, `vImage.Planar8` — vImage framework
- `CVPixelBufferIsPlanar()` — CoreVideo framework
- SE-0229 — SIMD Vectors (only Swift Evolution mention of SoA)

### Patterns
- [API-NAME-001] Nest.Name — namespace compliance
- [RES-021] Prior Art Survey — methodology
- [RES-022] Theoretical Grounding — type-theoretic justification
