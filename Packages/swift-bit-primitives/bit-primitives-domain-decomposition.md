# Bit Primitives Domain Decomposition

<!--
---
version: 2.0.0
last_updated: 2026-06-01
status: DECISION
tier: 3
applies_to: [swift-bit-primitives, swift-binary-primitives]
supersedes: [bit-primitives-completeness-analysis.md]
extends: [bit-vector-zeros-infrastructure.md, bitset-architecture-ideal-model.md, byte-primitive-extraction-and-domain-naming.md]
changelog:
  - "2.0.0 (2026-06-01): Converged end-state ratified and IMPLEMENTED. Word-of-bits consolidated into Binary.Pattern (swift-binary-primitives), not extracted into bit-primitives targets as v1.0.0 §6.3/§6.5 recommended; Bit reduced to the atom. See §0."
  - "1.0.0 (2026-06-01): Initial RECOMMENDATION (extract word-kernels to Cardinal-typed targets within swift-bit-primitives)."
---
-->

**A Tier-3 Deep Research on the Primitive-Domain Decomposition of `swift-bit-primitives`: the single-bit / word-of-bits scale boundary, the `Bit.Ones`/`Bit.Zeros` asymmetry, and the sub-namespace + target structure.**

---

## Abstract

This document determines the *correct and complete primitive-domain decomposition* of `swift-bit-primitives`: which sub-namespaces are genuinely primitive versus derived/compositional, what each couples, and where each belongs across the package's targets. It is the consolidation target ([META-016]) for `bit-primitives-completeness-analysis.md` (v2.0.1, DEFERRED), which it **supersedes** on the decomposition axis while carrying forward every finding (§9).

The investigation establishes three results:

1. **The decomposition's organizing axis is a *scale boundary*** between the single-bit *atom* (the `Bit` value type and its Boolean/Z₂ algebra — irreducible, zero-dependency) and the *word-of-bits kernel* (`Bit.Mask`, `Bit.Ones`, and the missing `Bit.Zeros` — rank/select/scan/mask over the bits packed in one machine word, requiring typed-count infrastructure). Cross-ecosystem prior art shows this separation is the near-universal norm (C++, Go, Zig, RISC-V all separate single-bit from word-level by header/package/extension/ISA-extension; Haskell is the lone coupler).

2. **The `Bit.Ones`-without-`Bit.Zeros` asymmetry is a genuine incompleteness, not a deliberate design.** Set-bit/clear-bit symmetry is the rule for scanning across surveyed systems, is *fully* symmetric in succinct-data-structures theory (`rank_α`/`select_α` parameterized over the symbol α ∈ {0,1}), is already realized one layer up in `swift-bit-vector-primitives` (`Bit.Vector.Ones`/`.Zeros`), and the ones-only population-count bias is a hardware accident (POPCNT counts ones). **Recommendation: add `Bit.Zeros<Word>` as the dual word-kernel.** The completeness-analysis deferral of `rank0`/`select0` ("revisit if downstream usage shows demand") used adoption framing where lattice-merit framing applies ([RES-020a]).

3. **The word-kernels are mis-scoped in the zero-dependency root and mis-typed with raw `Int`.** They consolidate into **`Binary.Pattern`** (`swift-binary-primitives`) — the bits-as-representation domain that already hosted the *richer* duplicate of `Bit.Mask` — leaving the root `Bit Primitive` as the zero-dependency atom. **(Revised in v2.0.0 — see §0. v1.0.0 recommended extracting them into Cardinal-typed sub-namespace targets *within* `swift-bit-primitives`; the cross-package consolidation into `Binary.Pattern` is cleaner and was implemented 2026-06-01.)**

**Keywords**: primitive-domain decomposition, single-bit vs word-of-bits scale, rank/select symmetry, succinct data structures, zero-dependency root, Cardinal typing, sub-namespace targets, [MOD-031].

---

## 0. Revision 2.0.0 — Converged and Implemented End-State (2026-06-01)

> **This revision supersedes the Q-place verdict (§6.3) and target decomposition (§6.5).** v1.0.0 recommended extracting the word-kernels into Cardinal-typed sub-namespace *targets within* `swift-bit-primitives`. Examining `swift-binary-primitives` and `swift-byte-primitives` surfaced a cleaner **cross-package** end-state, ratified by the principal and **implemented** on 2026-06-01. §1–§5 (current-state inventory, cross-ecosystem survey, internal corpus, scale boundary, zeros adjudication) stand unchanged and motivate the converged decision.

### Converged decision — three orthogonal axes over the `Bit` atom

| Axis | Home | Haskell analog |
|------|------|----------------|
| **Atom** — `Bit` + Boolean/Z₂ algebra + `Bit.Order` | `swift-bit-primitives` (zero-dep) | `Bool` |
| **Word-of-bits** — masks, rank/select/scan, popcount over a fixed-width word in the ring Z/2^w | **`Binary.Pattern<Carrier>`** in `swift-binary-primitives` (zero-dep leaf target) | `Bits` / `FiniteBits` |
| **Cardinality** — value-count + ordinal bijection | `swift-bit-finite-primitives` (`Finite.Enumerable`) | `Bounded` / `Enum` |

The word-of-bits operations **relate to `Binary` (bits-as-representation), not to the `Bit` atom**. `Byte` confirms the shape: it is a *peer atom* (value + bitwise algebra + capability marker, **zero word-kernels**), so `Bit` mirrors it. `Byte` is not a sequence; "Bits" (plural — a word/sequence) is `Binary`. This also matches Haskell's own three-class split (`Bits`/`FiniteBits` operations vs `Bounded`/`Enum` cardinality), and the institute's foundational-identity-vs-enrichment line (Equation/Comparison/Hash bundle with the atom; Finite/Algebra extract — like `Bits` requiring `Eq` while `Bounded`/`Num` stay separate).

### Decisive evidence — a verified duplication

`Bit.Mask<Word>.prefix(count:)` was a **verbatim duplicate** of `Binary.Pattern<Carrier>.Mask.lowBits(_:)` (identical `(1 << n) - 1`), and `Binary.Pattern.Mask` was already the *richer* implementation (lowBits/highBits/bit + ring ops + popcount). The `bit-primitives` word-kernels had **zero external source consumers** — the downstream `.ones` calls (`header.bitmap.ones`, `_slots.ones`) are all on `Bit.Vector` *containers* (`Bit.Vector.Ones.View`), a different type in a different package. They were dead, duplicated, mis-scoped surface.

### Implemented 2026-06-01 (both packages build + test green)

- **`swift-binary-primitives`** — added `Binary.Pattern<Carrier>.Ones` and `.Zeros` (`first`/`last`/`rank(below:)`/`select(_:)`/`forEach`), **symmetric from inception** (resolves §6.2 / Q-zeros); `Ones.rank` routes through the canonical `Binary.Pattern.Mask.lowBits` (single source of mask truth). New `Binary Pattern Ones/Zeros Tests`; full suite **265 tests green**.
- **`swift-bit-primitives`** — deleted `Bit.Mask`, `Bit.Ones`, and their `FixedWidthInteger` accessors; relocated `Bit Z₂ Field` into the zero-dep root (it needed none of the umbrella's deps). The root is now the pure atom. **42 tests green**.

### Residual follow-ups (not done today)

1. **Cardinal-typing** — `Binary.Pattern`'s positions/counts (Mask/Ones/Zeros) remain `Int`, which is also `binary-primitives`' *existing* `Binary.Pattern.Mask` convention. Applying the institute typed-index discipline (counts → `Cardinal`, positions → `Ordinal` per the **conversions** skill) is a **breaking** change to that existing API and adds a `Cardinal` dep to the zero-dep `Binary Pattern Primitives` leaf — so whether to impose it (vs. keep raw `Int` for a low-level Z/2^w ring) is a decision to confirm before applying, then do as a uniform sweep across Mask/Ones/Zeros.
2. **Umbrella purity (§8.3) — WITHDRAWN 2026-06-01.** The `Comparison`/`Equation`/`Hash.Protocol` conformances correctly live in the `Bit Primitives` module. There is **no `Bit.\`Protocol\``** (Bit is a plain enum — §7), so — unlike `byte-primitives`' `Byte Protocol Primitives` target, which is anchored on the `Byte.Protocol` capability marker — there is no protocol-marker to anchor a separate conformances target, and a pure-re-export umbrella is *not* a goal here. An attempt to mirror the byte target (a "Bit Protocol Primitives" target) was made and reverted. The foundational-identity conformances belong in the umbrella module.
3. **`Bit.Vector` delegation** — `Bit.Vector.Ones`/`.Zeros` (swift-bit-vector-primitives) still re-implement the inline complement-scan; they can now delegate to `Binary.Pattern.Ones`/`.Zeros`, eliminating that duplication.
4. **Cardinal-shift operators (§8.6)** — still in `bit-primitives`' SLI (the remaining out-of-scope item); candidate for relocation to a `cardinal`⊗word bridge.

---

## 1. Context

### 1.1 Trigger

A focused Tier-3 investigation brief (`HANDOFF-bit-primitives-domain-decomposition.md`) reports that `swift-bit-primitives`' decomposition into primitive sub-domains is "not yet complete or correct," with three tells: (a) `Bit.Ones` exists but there is **no `Bit.Zeros`** — an unexplained asymmetry; (b) which sub-namespaces are genuinely *primitive* vs derived (`Bit`, `Bit.Order`, the word-kernels `Bit.Mask`/`Bit.Ones`) is undecided; (c) the word-kernel placement + typing is "stuck precisely because the underlying decomposition isn't settled." A /modularization step is deferred to this research: type `Bit.Mask.prefix(count:)` as `some Carrier.\`Protocol\`<Cardinal>` and move the word-kernels out of the zero-dependency root into their own Cardinal/Carrier-depending sub-namespace targets.

### 1.2 Repository state at investigation time

Verified 2026-06-01: `swift-bit-primitives` HEAD `c413b5d` ("WIP"), working tree clean. Targets: `Bit Primitive` (root), `Bit Primitives` (umbrella), `Bit Primitives Standard Library Integration` (SLI), `Bit Primitives Test Support`. The package's `Package.swift` declares the root with `dependencies: []` (the [MOD-017] zero-dependency invariant is honored), and pulls `swift-cardinal-primitives`, `swift-carrier-primitives`, `swift-comparison-primitives`, `swift-equation-primitives`, `swift-hash-primitives` for the non-root targets. [Verified: 2026-06-01, `Package.swift:32-61`]

### 1.3 Prior research and its disposition

| Document | Status (as found) | Relationship to this doc |
|----------|-------------------|--------------------------|
| `bit-primitives-completeness-analysis.md` (v2.0.1, tier 3) | DEFERRED | **Superseded** on the decomposition axis (§9); its single-bit-operation findings are RESOLVED (implemented). |
| `bit-vector-zeros-infrastructure.md` (v1.0.0, tier 2) | RECOMMENDATION | **Extended** — establishes the container-level ones/zeros symmetry precedent (§4.2, §6.2). |
| `bitset-architecture-ideal-model.md` (v1.0.0, DECISION, tier 2) | DECISION | Anchors the realized tier layering (§5). |
| `comparative-bitset-bitvector-primitives.md` (DECISION) | DECISION | Source of the six-package inventory (§5); its `Bit.Set`/`Bit.Value` listing is **stale** (see §1.4). |
| `bitset-naming-literature-study.md` (v1.0.0, DECISION, tier 2) | DECISION | Anchors the `Bitset` ≠ `Bit.Set` naming (§4.3). |
| `bit-vector-type-organization.md`, `bit-vector-primitives-reducibility.md` (RECOMMENDATION) | RECOMMENDATION | Anchor the reducibility verdicts (§4.4). |
| `data-structures-bit-collections-assessment.md` (v2.0.0, RECOMMENDATION) | RECOMMENDATION | Classifies `swift-bit-primitives` as "domain foundation … no containers" (§5). |
| `byte-primitive-extraction-and-domain-naming.md` (v1.1.1, SUPERSEDED→[API-NAME-001b]), `byte-protocol-capability-marker.md` (v1.1.0, tier 3), `binary-byte-namespace-domain-foundations.md` (v3.1.0, IMPLEMENTED, tier 3) | mixed | **Precedent** — the byte-domain decomposition is the most recent analogous primitive-domain split (§7). |
| `Bit Primitives Extension Patterns Analysis.md` (v1.0.0, RECOMMENDATION) | RECOMMENDATION | The package's own extension-pattern record; [BIT-001]'s source. |

### 1.4 Staleness flags ([RES-013a], [RES-023], [META-008])

Two corpus-state corrections that downstream readers must respect:

- **`comparative-bitset-bitvector-primitives.md` and `bit-primitives-rawvalue-underlying-rename.md` describe a stale package shape.** They reference `Bit.Set`, `Bit.Value`, `Bit Boolean Primitives`, `Bit Field Primitives`, `Bit Primitives Core` — all since reshaped per the brief's parent context (folded `Bit Boolean Primitives` into the root; deleted `Bit.Value`/`Bit.Order.Value`; renamed `Bit.Set` → `Bit.Ones`; extracted the `Algebra.Field<Bit>` witness to `swift-bit-algebra-primitives`; merged Core into the singular `Bit Primitive` per [MOD-017]). This document uses **current source** (verified 2026-06-01), not the stale inventories.
- **`bit-primitives-completeness-analysis.md`'s `_index.json` entry is stale** ([META-008]): the index lists it `RECOMMENDATION`/`2026-02-03`; the document header says `DEFERRED`/`2026-03-15`/`v2.0.1`. The index is corrected as part of registering this document (§ corpus actions).

---

## 2. Question

> What is the complete and correct primitive-domain decomposition of `swift-bit-primitives` — which sub-namespaces are *primitive* versus *derived*, what does each couple, and what target structure realizes the decomposition — honoring the zero-dependency-root invariant, the Carrier-blessed / Cardinal-heavy dependency constraints, and the single-bit ↔ word-of-bits scale boundary?

Sub-questions:
- **Q-scale**: Where is the boundary between the single-bit atom and word-of-bits kernels, and should it be a *target* boundary?
- **Q-zeros**: Is the `Bit.Ones`-without-`Bit.Zeros` asymmetry correct, or should `Bit.Zeros` be added?
- **Q-place**: Where do the word-kernels (`Bit.Mask`, `Bit.Ones`, `Bit.Zeros`) belong, and how should their positions/counts be typed?
- **Q-classify**: Which sub-namespaces are primitive vs derived?

---

## 3. Verified current-state inventory

All claims in this section verified against source on 2026-06-01.

### 3.1 Root target `Bit Primitive` (`dependencies: []`)

| Sub-namespace / surface | File | Scale | Notes |
|---|---|---|---|
| `Bit` — `@frozen enum Bit: UInt8 { case zero, one }` + `init?(_:UInt8)` | `Bit.swift:18-32` | single-bit atom | Z₂/Boolean two-element enum; stdlib `RawRepresentable`. |
| `Bit.Order` — `enum Order { msb, lsb }` + `.opposite`, prefix `!`, spelled-out aliases | `Bit.Order.swift:18-71` | bit-significance (interpretation) | zero-dep. |
| Bitwise operators `^ & \| ~` | `Bitwise Operators.swift:8-32` | single-bit atom | via `rawValue`. |
| Method-style `and/or/xor`, `flipped/toggled`, prefix `!` | `Bit Boolean Operations.swift:6-76` | single-bit atom | |
| Compound `nand/nor/xnor/andNot` (static + instance) | `Bit Compound Operators.swift:14-88` | single-bit atom | **The completeness-analysis Part A additions — implemented.** [Verified: 2026-06-01] |
| `Bit.Mask<Word: FixedWidthInteger & UnsignedInteger & Sendable>` — empty phantom struct; `prefix(count: Int) -> Word` | `Bit.Mask.swift:5-39` | **word-of-bits** | **Mis-scoped: word-kernel in the zero-dep root; `count` is raw `Int`.** |
| `Bit.Ones<Word: …>` — stores `word: Word`; `first`, `last`, `rank(below: Int) -> Int`, `select(_: Int) -> Int?`, `forEach((Int)->Void)` | `Bit.Ones.swift:24-141` | **word-of-bits** | **Mis-scoped; raw `Int` positions/counts; no `Bit.Zeros` dual.** Internally calls `Bit.Mask<Word>().prefix(count:)`. |

### 3.2 Umbrella target `Bit Primitives` (deps: Comparison, Equation, Hash + root + SLI)

| Surface | File | Disposition |
|---|---|---|
| Native Z₂ field ops `Bit.adding`/`Bit.multiplying` (= `^`/`&`) | `Bit Z₂ Field.swift:8-32` | **zero-dependency single-bit ops mis-placed in the umbrella** — belong in the root (§8.6). |
| `Bit: Comparison.\`Protocol\`` (guarded `#if swift(<6.4)`) | `Bit+Comparison.Protocol.swift` | institute-protocol conformance; needs `Comparison_Primitives`. |
| `Bit: Equation.\`Protocol\`` | `Bit+Equation.Protocol.swift` | needs `Equation_Primitives`. |
| `Bit: Hash.\`Protocol\`` | `Bit+Hash.Protocol.swift` | needs `Hash_Primitives`. |
| `exports.swift` re-exports `Bit_Primitive`, SLI, `Hash_Primitives` | `Bit Primitives/exports.swift` | **Not a pure re-export** — carries the four implementation files above ([MOD-005] tension, §8.6). |

### 3.3 SLI target `Bit Primitives Standard Library Integration` (deps: Cardinal, Carrier)

| Surface | File | Disposition |
|---|---|---|
| `FixedWidthInteger.ones: Bit.Ones<Self>` accessor (needs only `Bit_Primitive`) | `FixedWidthInteger+Bit.Ones.swift:8-20` | stdlib-extension accessor — correct in SLI per [MOD-010]/[API-BYTE-007]. |
| `FixedWidthInteger.mask: Bit.Mask<Self>` accessor | `FixedWidthInteger+Bit.Mask.swift:8-18` | same. |
| Cardinal-shift operators `<< >> <<= >>=` by `some Carrier.\`Protocol\`<Cardinal>` (on bare `FixedWidthInteger` and on `Carrier`-wrapped) | `FixedWidthInteger+Cardinal.swift`, `Carrier+Cardinal.swift` | **The SLI's entire Cardinal/Carrier dependency originates here, not from the word-kernels.** Out of scope per brief; flagged §8.6. |
| `Bit` stdlib conformances: `Comparable`, `Codable`, `CaseIterable`, `CustomStringConvertible`, `ExpressibleByBooleanLiteral`, `ExpressibleByIntegerLiteral`, `Normalizing`; `Bit.Order: CaseIterable`; `Carrier+Cardinal`, `FixedWidthInteger+Cardinal` | (multiple) | stdlib integration — correct in SLI. |

**Critical observation**: the word-kernels (`Bit.Ones`, `Bit.Mask`) currently use **raw `Int`** and live in the **zero-dependency root**. The SLI's Cardinal dependency is owed entirely to the (out-of-scope) Cardinal-shift operators. So the package already *has* Cardinal available at the SLI level — but the word-kernels are on the wrong side of the dependency boundary to use it.

---

## 4. Internal corpus synthesis

Per [RES-019], the internal corpus governs; it is summarized here before the external survey (§6) which *confirms* rather than overrides it.

### 4.1 The realized six-package bit ecosystem (supersedes the completeness-analysis's two-package plan)

The completeness-analysis §12.5 proposed retiring `bit-storage-primitives` and splitting into an *enhanced* `bit-primitives` (with word-kernels **and** packing folded in) plus `bit-vector-primitives`. The ecosystem went **finer**. Verified on disk 2026-06-01 and against `bitset-architecture-ideal-model.md` / `comparative-bitset-bitvector-primitives.md`:

```
  swift-bit-primitives        — the Bit atom: Bit, Bit.Order, Boolean/Z₂ algebra        (lowest)
  swift-bit-index-primitives  — Bit.Index, Bit.Index.Count (typed positions/counts)
  swift-bit-pack-primitives   — Bit.Pack<Word>.{Location, Words, Bits} (word/bit addressing)
        ╱                          ╲
  swift-bit-vector-primitives    swift-bitset-primitives   — containers (consume the above)
  (sequence of bits)             (set of integers)
  swift-bit-algebra-primitives — Algebra.Field<Bit> (Z₂) and algebraic structure witnesses
```

`swift-bit-storage-primitives` is **absent** on disk — the §12.5 retirement was executed. [Verified: 2026-06-01] `swift-bit-algebra-primitives` **exists** — the [MOD-014] Bit⊗Algebra-Field extraction (2026-05-28) landed. The realized decomposition demonstrates the ecosystem's **standing preference for fine-grained, scale-separated bit packages** — exactly the [MOD-031] / [MOD-030] convergence ("Option A maximum-granular is always preferable").

> **Consequence for this investigation**: the completeness-analysis's "no better home, so put word-kernels in bit-primitives" rationale (§10.2 Option A) is weakened. There is now a whole sibling stratum (`bit-pack`, `bit-vector`, `bitset`) that consumes the kernels, and the ecosystem has shown it prefers per-concern decomposition over folding concerns into the atom package.

### 4.2 Container-level ones/zeros symmetry already exists

`bit-vector-zeros-infrastructure.md` (RECOMMENDATION) records that `swift-bit-vector-primitives` carries **both** `.ones` (`Bit.Vector.Ones.View`) **and** `.zeros` (`Bit.Vector.Zeros.View`) — symmetric set-bit and clear-bit iteration. The doc's own framing names the defect this investigation echoes: *"The asymmetry is clear: set-bit scanning has infrastructure; zero-bit scanning does not."* It chose **Option A — full `.zeros` mirroring `.ones`** with the rationale that *"the file count (8 files) is a feature, not a cost."* The `Zeros` iterator is structurally identical to `Ones` except it complements the word (`~word`) before the Wegner/Kernighan scan. [Verified: 2026-06-01, doc §"Outcome", §"Implementation Plan"]

> **Consequence**: the institute has already ruled, at the container layer, that ones/zeros symmetry is the correct shape and that the extra files are a feature. The word-kernel layer (`Bit.Ones` in `swift-bit-primitives`) is simply *behind* the container layer on this decision. Moreover, `Bit.Vector.Zeros.View` re-implements the `~word` complement-scan *inline* — a word-level `Bit.Zeros<Word>` kernel would let it delegate, eliminating the duplication (the same reuse argument the completeness-analysis §10.2 made for `Bit.Ones`).

### 4.3 Naming: `Bitset` (container) ≠ `Bit.Set` ≠ word-kernel

`bitset-naming-literature-study.md` (DECISION) rejected `Bit.Set` because it *"collides with `Set<Bit>` and loses the 'bitset as a data structure' identity,"* landing on the package `swift-bitset-primitives` with type `Bitset`. The brief's parent context records the corresponding rename inside `swift-bit-primitives`: `Bit.Set` (the word-level set-bit kernel) → **`Bit.Ones`** to avoid colliding with the `Bitset` container. This is the right call and is preserved: `Bit.Ones`/`Bit.Zeros` name the *symbol* (set/clear bits) and read naturally at the call site (`word.ones.rank(below:)`, `word.zeros.first`), matching Rust's `count_ones`/`count_zeros` and `bitvec`'s `iter_ones`/`iter_zeros` vocabulary (§6).

### 4.4 Reducibility verdicts and the primitive boundary

`bit-vector-primitives-reducibility.md` and `bitset-architecture-ideal-model.md` (DECISION) fix the irreducible kernel and the primitive boundary:

- The **irreducible word-level kernel** is *"word masking, Wegner/Kernighan iteration, popcount … `Bit.Pack<UInt>.Location`"* — shared by `Bit.Vector` and `Bitset`, *"neither subordinate, both compose `Bit.Pack` … both own their storage."* [Verified: 2026-06-01]
- **PRIMITIVE**: `Bit`, `Bit.Order`, `Bit.Index`, `Bit.Pack<Word>` (the addressing witness). **DERIVED/COMPOSITIONAL**: `Bit.Vector.*`, `Bitset.*` (compose `Bit.Pack` + below).
- `data-structures-bit-collections-assessment.md` classifies `swift-bit-primitives` as *"Domain foundation: `Bit` enum, `Bit.Order`, boolean/field ops; **no containers**"* — the emerging identity of the atom package.

> **Consequence**: the institute's own reducibility analysis treats the *addressing/query* kernel as a distinct primitive stratum from the `Bit` atom — `Bit.Pack` is its own package, not folded into `swift-bit-primitives`. The rank/select/mask word-kernels are the same *kind* of thing (word-level bit queries) and should sit in the same stratum, not in the atom root.

---

## 5. Systematic literature review — decomposition lens

This SLR **extends** `bit-primitives-completeness-analysis.md` §2, which surveyed *which operations* are primitive (hardware ISAs, language stdlibs, SMT-LIB QF_BV, Hacker's Delight) and concluded the single-bit operation set {AND, OR, XOR, NOT, NAND, NOR, XNOR, AND-NOT} is functionally complete (now implemented — §9). The lens *here* is **domain decomposition**: does each ecosystem declare a single-bit *type*, what subdomains does it declare, does it *couple* single-bit algebra with word-level kernels, and is the ones/zeros treatment *symmetric*?

External claims below were verified against primary sources by parallel subagent survey ([RES-020], [RES-021]); each load-bearing row carries the primary URL. The x86/ARM ISA specifics were **not** re-fetched this pass and are deferred to the completeness-analysis's already-cited ISA references (Intel SDM Vol. 2; ARM ARM DDI 0487) rather than re-asserted here ([RES-032]).

| Ecosystem | Single-bit *type*? | Subdomains declared | Single-bit ↔ word-kernel | Ones/zeros symmetric? |
|---|---|---|---|---|
| **Rust std** | No (`bool`; integers carry the ops) | word-level methods on each integer type | n/a (no single-bit algebra type) | **Yes (counting)**: `count_ones`/`count_zeros`, `leading_ones`/`leading_zeros`, `trailing_ones`/`trailing_zeros` [Verified: https://doc.rust-lang.org/std/primitive.u32.html] |
| **Rust `bitvec`** | No (uses `bool` + proxy) | `BitSlice`/`BitVec` containers | container delegates to integer ops | **Yes**: `count_ones`/`count_zeros`, `iter_ones`/`iter_zeros` [Verified: https://docs.rs/bitvec/latest/bitvec/slice/struct.BitSlice.html] |
| **C++20** | No (`bool`; `bitset::reference` proxy, `element_type = bool`) | `<bit>` = word-level free functions; `<bitset>` = container | **Separated by header** (`<bit>` ≠ `<bitset>`) | scanning symmetric (`countl_zero`/`countl_one`, `countr_zero`/`countr_one`); **`popcount` ones-only** [Verified: https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0553r4.html] |
| **Go** | No | `math/bits` free functions on `uint`; "Types: this section is empty" | **Separated** (stand-alone package) | ones-biased: `OnesCount` only; `LeadingZeros`/`TrailingZeros` only [Verified: https://pkg.go.dev/math/bits] |
| **Zig** | **Yes — `u1`** (arbitrary-width native ints) | `u1` is a type-system citizen; kernels are builtins (`@popCount`, `@clz`, `@ctz`) | **Separated by mechanism** (type vs builtin) | asymmetric (`@clz`/`@ctz` zeros-only; `@popCount` ones-only) [Verified: https://ziglang.org/documentation/master/] |
| **Haskell** | **Yes — `Bool`** (`instance Bits Bool`, `FiniteBits Bool`, `finiteBitSize = 1`, since base-4.7.0.0) | one `Bits`/`FiniteBits` hierarchy + And/Ior/Xor/Iff monoids | **COUPLED — the lone counter-example** (same typeclass spans width-1 `Bool` … `Word64`) | `popCount` ones-only; scanning via `countLeading/TrailingZeros`; per-bit `setBit`/`clearBit` symmetric [Verified: https://hackage.haskell.org/package/base-4.11.0.0/docs/src/Data.Bits.html] |
| **RISC-V Bitmanip** | n/a | **Zbb** (count/scan: clz/ctz/cpop) vs **Zbs** (single-bit: bset/bclr/binv/bext) | **Separated into distinct ratified ISA extensions** | Zbs `bset`/`bclr` symmetric; Zbb counting ones-biased (`cpop` ones; `clz`/`ctz` zeros) [Verified: https://github.com/riscv/riscv-bitmanip/blob/main/bitmanip/bitmanip.adoc] |
| **Succinct DS theory** | the symbol α (abstract) | `rank_α`, `select_α` over a bitvector | one ADT (it is mathematics) | **Fully symmetric by definition**: `rank_α(i)`, `select_α(i)`, with `rank_0(i) = i − rank_1(i)` [Verified: https://arxiv.org/pdf/2206.01149] |

### 5.1 Cross-ecosystem patterns

- **Pattern 1 — a dedicated single-bit *type* is the minority choice.** Only Zig (`u1`) and Haskell (`Bool` with `Bits`) treat one bit as a first-class typed value carrying operations; Rust, C++, Go route through `bool`/proxy and put the operations on words. Swift Institute's `Bit` type is a deliberate, defensible minority choice (Zig + Haskell precedent), not the universal default. *(Contextualization per [RES-021]: rarity of a `Bit` type is not an argument against it — but it means the package must justify the type on its own algebraic-completeness grounds, which the completeness-analysis already did.)*
- **Pattern 2 — single-bit algebra is SEPARATED from word-level kernels by a *structural* boundary almost everywhere; Haskell alone couples them.** C++ separates by *header* (`<bit>`≠`<bitset>`); Go by *package* (`math/bits`); Zig by *mechanism* (type vs builtin); RISC-V by *ISA extension* (Zbs≠Zbb). This is the dominant signal for the scale-boundary question (Q-scale).
- **Pattern 3 — ones/zeros symmetry is the rule for scanning and set/clear; population count is ones-biased nearly everywhere; Rust is the strongest symmetric-population precedent.** The ones-only bias of `popcount`/`OnesCount`/`@popCount`/`cpop`/POPCNT is a hardware accident, not a design principle — zeros are derivable as `width − popcount`.
- **Pattern 4 — theory is fully symmetric, by definition.** `rank_α`/`select_α` are co-equal first-class operations; the practical ones-bias is purely an artifact of hardware history.

---

## 6. Analysis

### 6.1 Q-scale — the single-bit / word-of-bits scale boundary is a *target* boundary

**Formal grounding.** The bit domain is layered by *cardinality of the operand* (`binary-byte-namespace-domain-foundations.md` §"three categorical layers" supplies the analogous byte layering):

```
  Bit          — the atom: the two-element structure {0,1} with Boolean algebra + GF(2) field.  |operand| = 1
       │  "w of"
  Bit^w (Word) — a word of bits: rank/select/scan/mask query the bit-sequence packed in one machine word.  |operand| = w
       │  "many words of"
  Bit^*  — multi-word containers (Bit.Vector, Bitset).  |operand| = unbounded
```

The atom layer (`Bit`, its Boolean/Z₂ algebra, `Bit.Order`) answers *"what is a bit?"* It is irreducible and **zero-dependency**. The word-of-bits layer answers *"how do I query the bits of a word?"* — `rank`, `select`, `scan`, `mask`. Its operations are over `Word: FixedWidthInteger`; their natural *positions and counts* are ℕ-valued (Cardinal), which requires typed-count infrastructure. **These are different scales answering different questions, and every surveyed system except Haskell separates them by a structural boundary (Pattern 2).** The institute's own ecosystem already separates them: `Bit.Pack` (word-level addressing) is a *separate package* from the `Bit` atom (§4.4).

> **Verdict (Q-scale)**: the single-bit / word-of-bits boundary MUST be a target boundary. The zero-dependency root `Bit Primitive` owns the atom; the word-kernels move out. This is mandated independently by: (a) the cross-ecosystem separation norm (Pattern 2); (b) the institute's realized fine-grained ecosystem (§4.1); (c) the [MOD-017] zero-dependency-root invariant (the word-kernels' Cardinal typing — §6.3 — cannot live in the zero-dep root); and (d) [MOD-DOMAIN] (the atom and the word-query are distinct semantic domains, not "just code").

### 6.2 Q-zeros — add `Bit.Zeros<Word>` (the asymmetry is an incompleteness)

The `Bit.Ones`-without-`Bit.Zeros` asymmetry is adjudicated under four independent lines of evidence, all pointing the same way:

1. **Theory (decisive)**: succinct-data-structures literature defines rank/select *parametrically over the symbol* — `rank_0`/`rank_1` and `select_0`/`select_1` are co-equal, with the identity `rank_0(i) = i − rank_1(i)` [Verified: arXiv 2206.01149]. A word-kernel that provides only the α=1 case is *definitionally* half a kernel.
2. **Cross-ecosystem**: Rust provides `count_ones`/`count_zeros`, `leading_ones`/`leading_zeros`, `trailing_ones`/`trailing_zeros` — full counting symmetry [Verified: doc.rust-lang.org]; `bitvec` provides `iter_ones`/`iter_zeros`. The ones-only population bias elsewhere is a hardware accident (Pattern 3), not a design principle to imitate.
3. **Internal precedent (already decided one layer up)**: `swift-bit-vector-primitives` already ships symmetric `Bit.Vector.Ones`/`Bit.Vector.Zeros` (§4.2). The institute *already ruled* that ones/zeros symmetry is the correct shape and that the extra files are "a feature, not a cost." The word-kernel layer is simply behind on the same decision.
4. **Merit framing, not adoption ([RES-020a])**: `swift-bit-primitives`' word-kernel is a *total taxonomy* of single-word bit queries. `Bit.Zeros` fills the empty lattice cell (the α=0 column). The completeness-analysis §12.6 deferred `rank0`/`select0` as *"trivially derivable from rank1/select1 + complement … revisit if downstream usage shows demand"* — this is **adoption framing applied where lattice-merit framing governs**. [RES-020a] is explicit: total-taxonomy packages justify types by lattice-cell merit, not consumer-demand count; "deprecation by adoption count is forbidden," and by symmetry, *deferral* by adoption count is the same error.

**The "trivially derivable" objection fails on its own terms.** (a) `select` is itself "derivable" from `forEach`, yet both exist — derivability does not disqualify a primitive operation in a total taxonomy. (b) `Bit.Zeros` is *not* a pure alias: `select0(n)` over a fixed-width word is `(~word).ones.select(n)` only with care for the high padding zeros beyond meaningful bits (the exact "trailing-zeros-beyond-capacity invariant" `bit-vector-zeros-infrastructure.md` §"Invariant" had to reason about at the container layer). There is genuine implementation content. (c) Symmetry *eliminates* the consumer-side error of re-deriving the complement-scan inline (which `Bit.Vector.Zeros.View` currently does).

> **Verdict (Q-zeros)**: ADD `Bit.Zeros<Word>` as the dual word-kernel, mirroring `Bit.Ones`: `word.zeros.{first, last, rank(below:), select(_:), forEach}`. This completes the symbol-parameterized lattice and lets `Bit.Vector.Zeros` delegate rather than re-implement.

### 6.3 Q-place — extract the word-kernels into Cardinal-typed sub-namespace targets

**Typing.** The word-kernels currently use raw `Int` (`rank(below position: Int) -> Int`, `prefix(count: Int)`, `first/last: Int?`). This is inconsistent with the layer directly above: `Bit.Vector` already types its positions/counts as `Bit.Index`/`Bit.Index.Count` (`bit-vector-zeros-infrastructure.md` shows `Zeros.View` returning `Bit.Index` and computing with `Bit.Index.Count`). Raw `Int` at the kernel level forces a typed→raw→typed round-trip at the container boundary — the very [IMPL-002] violation the zeros-infrastructure doc set out to fix (it replaced a `try! Index<Element>.Count(i)` raw loop with typed `.zeros.first`).

The correct typing is **Cardinal for counts and ℕ-positions** (the brief's `some Carrier.\`Protocol\`<Cardinal>`):
- `rank(below:) -> Cardinal` (a population count), `prefix(count: some Carrier.\`Protocol\`<Cardinal>)` (a count), `select`/`first`/`last` returning ℕ-positions as Cardinal.
- **Cardinal, not `Bit.Index`**: the word-kernel operates on a *generic* `Word` (any `FixedWidthInteger`), so its positions are "bit positions within an arbitrary word" — plain naturals — not `Bit.Index` (which is tied to the bit-vector/bit-domain addressing in `swift-bit-index-primitives`, tier 10). Speaking Cardinal keeps the kernel light and general; the container layer converts Cardinal → `Bit.Index` at *its* boundary. This is clean layering and matches the brief's `<Cardinal>` choice.

**[ARCH-LAYER-004] does not apply.** That rule keeps *kernel-ABI* values (io_uring head/tail counters with 2³² wrapping semantics) as raw `UInt32`. Bit positions/counts in `[0, bitWidth]` are not a C-ABI surface, carry no wrapping protocol, and are used as genuine ℕ quantities — the institute's typed-arithmetic discipline ([IMPL-002]) applies, not the kernel-ABI carve-out. [Verified: 2026-06-01 against [ARCH-LAYER-004]'s scope statement]

**Placement.** Cardinal pulls six transitive packages (Tagged/Property/Equation/Hash/Comparison + Cardinal) and is **not root-eligible** (brief constraint; [MOD-017] zero-dep invariant). Therefore Cardinal-typed kernels cannot remain in `Bit Primitive`. They extract into their own targets. **Within a package vs a new sibling package**:

- **[MOD-020] (dep-delta before new package)**: the nearest existing package (`swift-bit-primitives`) *already* declares `swift-cardinal-primitives` + `swift-carrier-primitives` (for the SLI shift operators). The dep-delta for adding Cardinal-typed word-kernel *targets* is therefore **zero new package-level deps** → [MOD-020] prefers a **target-split inside the existing package** over a new package.
- **[MOD-029] (split weights upstream dep tree)**: extracting the kernels to a *new package* would not prune `swift-bit-primitives`' tree (it keeps Cardinal for shifts), so there is no strong new-package signal.
- The brief's framing ("their own … sub-namespace targets", plural) matches [MOD-031]'s per-sub-namespace target default.

> **Verdict (Q-place)** — ⚠️ **SUPERSEDED by §0 (v2.0.0)**: the word-kernels consolidate into `Binary.Pattern` (`swift-binary-primitives`), *not* into targets within `swift-bit-primitives`. The verdict below was v1.0.0's within-package answer; it is retained for the reasoning ([MOD-020] dep-delta, [ARCH-LAYER-004] non-applicability, Cardinal typing) which still holds for the typing dimension.
>
> *(v1.0.0)* extract `Bit.Mask`, `Bit.Ones`, and the new `Bit.Zeros` into **Cardinal-typed sub-namespace targets within `swift-bit-primitives`** (per [MOD-031]), not a new package. Type positions/counts as Cardinal. Keep the `FixedWidthInteger` `.ones`/`.zeros`/`.mask` accessors in SLI ([MOD-010]/[API-BYTE-007]), importing the new kernel targets.

*Escalation note ([RES-004b])*: if the out-of-scope Cardinal-shift operators (§8.6) are later relocated out of `swift-bit-primitives`, the package's Cardinal dependency disappears, and the [MOD-020] dep-delta for the word-kernels becomes non-zero — at which point the byte-precedent (atom package = atom only; §7) and the ecosystem's fine-grained pattern (§4.1) would favor a **sibling package `swift-bit-word-primitives`** parallel to `swift-bit-pack-primitives`. This package-vs-target decision should be fixed by a written **[MOD-035] scope statement** for `swift-bit-primitives` (does its identity include the word-of-bits scale, or only the atom?). Recommended scope statement in §8.5.

### 6.4 Q-classify — primitive vs derived sub-namespaces

| Sub-namespace / surface | Scale | Primitive or Derived? | Coupling (external deps) | Target |
|---|---|---|---|---|
| `Bit` (type, Boolean ops, bitwise, compound) | single-bit atom | **PRIMITIVE** (irreducible foundation) | none | root `Bit Primitive` |
| `Bit` native Z₂ field ops (`adding`/`multiplying`) | single-bit atom | **PRIMITIVE** (Bit's field structure) | none | root (move from umbrella — §8.6) |
| `Bit.Order` (msb/lsb) | bit-significance / interpretation | **PRIMITIVE-adjacent** (zero-dep interpretation atom) | none | root (zero-dep; alt: word stratum — §8.5) |
| `Bit.Mask<Word>` (prefix + future suffix/range) | word-of-bits | **PRIMITIVE** (word-kernel) | Cardinal, Carrier | `Bit Mask Primitives` (extract) |
| `Bit.Ones<Word>` (rank/select/scan over set bits) | word-of-bits | **PRIMITIVE** (word-kernel) | Cardinal, Carrier | `Bit Ones Primitives` (extract) |
| `Bit.Zeros<Word>` (dual — **NEW**) | word-of-bits | **PRIMITIVE** (word-kernel; symmetry) | Cardinal, Carrier | `Bit Zeros Primitives` (add) |
| `Bit` stdlib conformances (Comparable, Codable, …) | integration | **DERIVED** (stdlib integration) | (stdlib) | SLI |
| `Bit: Comparison/Equation/Hash.\`Protocol\`` | integration | **DERIVED** (institute-protocol integration) | Comparison, Equation, Hash | conformances target (§8.5) |
| Cardinal-shift operators | word-level arithmetic bridge | **DERIVED** (out of scope; arguably mis-homed — §8.6) | Cardinal, Carrier | SLI (flagged for relocation) |
| `Algebra.Field<Bit>` Z₂ witness | algebraic structure | **DERIVED** (already extracted) | algebra-field | `swift-bit-algebra-primitives` ✓ |

### 6.5 The target decomposition recommendation (the answer)

> ⚠️ **SUPERSEDED by §0 (v2.0.0)** — the converged end-state keeps `swift-bit-primitives` as the `Bit` atom only and consolidates the word-kernels into `Binary.Pattern` (`swift-binary-primitives`). The within-package target table below was v1.0.0's recommendation; it is retained as the analysis of *how* a within-package extraction would have looked.

A [MOD-031]-conformant shape for `swift-bit-primitives`:

| Role | Target | Deps | Contents |
|---|---|---|---|
| Root (atom) | **`Bit Primitive`** (singular, [MOD-017]) | `[]` | `Bit`, `Bit.Order`, bitwise `^ & \| ~`, method-style and/or/xor, compound nand/nor/xnor/andNot, **native Z₂ `adding`/`multiplying` (moved in)** |
| Word-kernel | **`Bit Mask Primitives`** | Cardinal, Carrier | `Bit.Mask<Word>` — `prefix(count:)` + (future) `suffix`/`range`, Cardinal-typed |
| Word-kernel | **`Bit Ones Primitives`** | Cardinal, Carrier (+ `Bit Mask Primitives`) | `Bit.Ones<Word>` — first/last/rank/select/forEach, Cardinal-typed |
| Word-kernel | **`Bit Zeros Primitives`** (**NEW**) | Cardinal, Carrier (+ `Bit Mask Primitives`) | `Bit.Zeros<Word>` — dual of Ones |
| Institute-protocol conformances | **`Bit Primitives Comparison/Equation/Hash` conformances** (own target, or retain in a non-umbrella target) | Comparison, Equation, Hash | `Bit: Comparison/Equation/Hash.\`Protocol\`` |
| StdLib integration | **`Bit Primitives Standard Library Integration`** | Cardinal, Carrier | `.ones`/`.zeros`/`.mask` accessors; `Bit` stdlib conformances; (Cardinal-shift operators — flagged §8.6) |
| Umbrella | **`Bit Primitives`** (plural, [MOD-005]) | all sub-targets | **pure `@_exported` re-export** (the four implementation files move out — §8.6) |
| Test support | `Bit Primitives Test Support` | umbrella | unchanged |

Intra-package dependency depth from the root: `Bit Primitive` → `Bit Mask Primitives` → `Bit Ones Primitives`/`Bit Zeros Primitives` = depth 2 (within [MOD-007]'s ≤ 3). Consumers import per [MOD-015]: a caller needing only set-bit rank/select imports `Bit_Ones_Primitives`; the umbrella surfaces the union.

**Coarser alternative** (acknowledged, not recommended): a single `Bit Word Primitives` target holding Mask + Ones + Zeros. Rejected as the default because [MOD-031]/[MOD-030] make per-sub-namespace the institute's converged shape and the brief itself says "targets" (plural). The coarser shape is acceptable only if the principal prefers fewer targets for a small package.

---

## 7. Byte-domain decomposition precedent

The byte-extraction arc (2026-05) is the most recent analogous primitive-domain split and supplies four transferable precedents (`byte-primitive-extraction-and-domain-naming.md`, `byte-protocol-capability-marker.md`, `binary-byte-namespace-domain-foundations.md`):

1. **Atom-package isolation by dependency**: `Byte` (zero parser deps) and `Byte.Parser` (needs the parser stack) are *separate L1 packages* "because consumers of the atomic type do not need the parser stack." → The atom package should carry only the atom + zero-dep algebra; anything needing a heavy dependency (here: Cardinal) extracts. This *supports* §6.3's extraction; it leans toward a sibling package in the limit (the §6.3 escalation).
2. **Subject-first naming [API-NAME-001b]**: `Byte.Parser` not `Parser.Byte` — "byte is the subject, parsing is the role." → `Bit.Ones`/`Bit.Zeros`/`Bit.Mask` correctly nest the word-kernels under the `Bit` domain (the bit domain owns "the one/zero bits of a word"); `Word` is the generic carrier, not a namespace.
3. **Typed positions/counts, not raw integers**: byte positions use `Tagged<Byte, Ordinal>` / counts use Cardinal-shaped types, never raw `UInt`. → Confirms §6.3's Cardinal typing of word-kernel positions/counts.
4. **Capability-marker recipe is for *arithmetic-carrier twins* — and `Bit` is not one**: `byte-protocol-capability-marker.md` [API-NAME-001c] defines the `X.\`Protocol\`` recipe for "domain-identity value types that are the institute twin of a stdlib *arithmetic* carrier — `Cardinal`/UInt, `Ordinal`/UInt, `Byte`/UInt8, future `Char`/`Codepoint`/`Word`/`Line`." `Bit` is **not** in that family: it is a two-element Z₂/Boolean algebra, not an arithmetic-carrier twin (it deliberately has *no* arithmetic, only field ops over GF(2)). The recipe's whole point is separating an arithmetic carrier (UInt8) from a domain twin (Byte) — a separation `Bit` does not need, because `Bit` carries no arithmetic to separate.

> **Out-of-scope determination ([RES-021] contextualization)**: a subagent applying the byte precedent mechanically recommended migrating `Bit` from `@frozen enum Bit: UInt8` to a `struct Bit { underlying: UInt8 }` with a sibling `Bit.\`Protocol\``. **This investigation does not adopt that.** The capability-marker recipe is for arithmetic-carrier twins; `Bit`'s enum form correctly models a two-element algebra (cardinality 2, `CaseIterable`, `Finite.Enumerable`), and there is no arithmetic carrier to hold at arm's length. Whether `Bit` should ever gain a `Bit.\`Protocol\`` (e.g. for `Tagged<Tag, Bit>` phantom composition) is a *separate* question about the atom's representation, orthogonal to the decomposition this brief asks about. Flagged as a follow-up (§10), with the prior leaning toward "keep `Bit` as an enum."

---

## 8. Secondary findings and observations

### 8.1 Completeness-analysis Part A is implemented
NAND/NOR/XNOR/AND-NOT landed in `Bit Compound Operators.swift` (§3.1). The single-bit operation set is functionally and operationally complete. RESOLVED.

### 8.2 Part B landed in a *better* shape than the doc recommended
The completeness-analysis §10.4 recommended bare `extension FixedWidthInteger` methods (`rank1`, `select1`, `prefixMask`, `forEachSetBit`). The implementation chose the **accessor-namespace types** `Bit.Ones`/`Bit.Mask` reached via `word.ones`/`UInt64.mask`. The implemented shape is **superior** per [API-NAME-002] (nested accessors over compound `rank1`/`select1` identifiers) and [API-NAME-008] (Property-View-style nested accessors for multi-form operations — rank/select/first/last/forEach under one `.ones` root). This doc affirms the accessor-type shape and supersedes the bare-method recommendation.

### 8.3 The umbrella is not a pure re-export ([MOD-005])
`Bit Primitives` carries four implementation files (`Bit Z₂ Field.swift`, the three `Bit+*.Protocol.swift` conformances). [MOD-005] requires the umbrella's sole content to be `@_exported public import`. Recommendation: move the native Z₂ ops to the root (§8.4) and the institute-protocol conformances to a dedicated conformances target (§6.5), leaving `Bit Primitives` a pure umbrella.

### 8.4 Native Z₂ field ops are mis-placed
`Bit.adding`/`Bit.multiplying` (`Bit Z₂ Field.swift`) are `lhs ^ rhs` / `lhs & rhs` — **zero-dependency single-bit operations** that only need `Bit_Primitive`, yet sit in the umbrella (which pulls Comparison/Equation/Hash). They belong in the root `Bit Primitive`. (These are the "Z₂ Field native aliases" the brief lists as out-of-scope; the analysis flags the placement but does not require acting on it within this investigation — see §10.)

### 8.5 Recommended [MOD-035] scope statement for `swift-bit-primitives`
To fix the package-vs-target question durably:
> *`swift-bit-primitives` provides the single **bit** as an atomic value (the two-element Boolean algebra / GF(2) field) **and** the word-of-bits kernels that query the bits packed in one machine word (mask construction; rank/select/scan over set and clear bits). It does **not** provide bit indexing (→ `swift-bit-index-primitives`), bit/word addressing (→ `swift-bit-pack-primitives`), multi-word containers (→ `swift-bit-vector-primitives`, `swift-bitset-primitives`), or algebraic-structure witnesses (→ `swift-bit-algebra-primitives`).*

`Bit.Order` is retained in the root as a zero-dependency interpretation atom (it answers "which bit is first," a fundamental bit-significance concept); the alternative (grouping it with the word stratum, since significance only matters across multiple bits) is noted but not preferred — it carries no Cardinal dependency, so the zero-dep root is the cheaper home.

### 8.6 Out-of-scope items observed (flagged, not actioned)
- **Cardinal-shift operators** (`FixedWidthInteger+Cardinal.swift`, `Carrier+Cardinal.swift`): "shift a `FixedWidthInteger`/`Carrier` by a `Cardinal` amount." These are a Cardinal⊗FixedWidthInteger *arithmetic bridge*, not a bit-domain operation; per [PKG-NAME-016]/[MOD-014] they are candidates for a `cardinal`⊗word integration site rather than `swift-bit-primitives`' SLI. They are the *sole* source of the package's Cardinal dependency today, so their relocation interacts with §6.3's escalation note. Out of scope per the brief; flagged for a follow-up.
- **`Bit Z₂ Field.swift` placement** (§8.4): the "Z₂ Field native aliases" the brief lists as out-of-scope. Placement observation recorded; not actioned.

---

## 9. Disposition of the superseded `bit-primitives-completeness-analysis.md` ([META-016])

Per [META-016], consolidation must not discard findings; every finding of the superseded document is carried forward here as active, resolved, or explicitly re-scoped.

| Completeness-analysis finding | Disposition here |
|---|---|
| §2 SLR (ISAs, stdlibs, SMT-LIB, Hacker's Delight) — operation primitivity | **Carried forward** as historical rationale; extended with the decomposition-lens SLR (§5). |
| §3–§4 16 Boolean functions, functional completeness, formal semantics | **Carried forward** (unchanged; still the algebraic foundation). |
| §5/§9 Part A: add NAND, NOR, XNOR, AND-NOT | **RESOLVED** — implemented (`Bit Compound Operators.swift`, §3.1, §8.1). |
| §10.4/§12 Part B: word-kernels as bare `FixedWidthInteger` methods (rank1/select1/prefixMask/forEachSetBit/first/last) | **SUPERSEDED** — implemented instead as `Bit.Ones`/`Bit.Mask` accessor-namespace types, which this doc affirms as superior (§8.2) and extends with `Bit.Zeros` (§6.2) + Cardinal typing + target extraction (§6.3). |
| §10.2 word-kernels belong in bit-primitives (Option A) | **Re-scoped** — affirmed that the kernels stay *in the package*, but in extracted sub-namespace **targets**, not the zero-dep root (§6.1, §6.3); the §10.2 "no better home" rationale is weakened by the realized six-package ecosystem (§4.1). |
| §12.5 retire `bit-storage-primitives`; split into enhanced bit-primitives + bit-vector-primitives; fold packing into bit-primitives | **Partially SUPERSEDED** — `bit-storage` retired ✓ and `bit-vector` created ✓ (verified §4.1), but packing was **extracted to its own `swift-bit-pack-primitives`** (finer than "fold in"), and `bit-index` was also split out. The realized decomposition is the six-package family (§4.1). |
| §12.6 defer `rank0`/`select0` ("revisit if downstream usage shows demand") | **RESOLVED — reversed** under merit framing ([RES-020a]): add `Bit.Zeros<Word>` (§6.2). The adoption-deferral was the wrong framing for a total-taxonomy word-kernel. |
| §12.6 defer `Bit.Mask` type (prefer `prefixMask` function) | **RESOLVED** — the `Bit.Mask` *type* was adopted and is affirmed (§6.5, §8.2); recommend populating the mask vocabulary (prefix + suffix/range) over time. |
| §12.6 defer `Bit.Word` protocol; defer rotation (→ numeric-primitives) | **Carried forward** as deferred; rotation remains out of bit-primitives' scope (§8.5 scope statement). |

**Corpus actions** (research metadata only — *not* the reshape, which is gated on this recommendation): register this document in `Research/_index.json`; correct the stale completeness-analysis index entry ([META-008]); mark `bit-primitives-completeness-analysis.md` **SUPERSEDED** with a pointer here ([META-003]/[META-004]).

---

## 10. Out of scope / follow-ups

- **Implementing the reshape** (editing `Sources/`, `Package.swift`): a follow-up, gated on acceptance of this recommendation (brief "Do Not Touch").
- **Cardinal-shift operator relocation** (§8.6): a Cardinal⊗word bridge question; interacts with the package-vs-target escalation (§6.3).
- **`Bit Z₂ Field.swift` → root move** (§8.4): the out-of-scope "Z₂ native aliases."
- **`Bit.\`Protocol\`` capability marker / `Bit` enum-vs-struct** (§7): a separate representation question; prior leaning is to keep `Bit` an enum (it is not an arithmetic-carrier twin). Revisit only if `Tagged<Tag, Bit>` phantom composition is required by a real consumer.
- **`Bit.Vector.Zeros` delegation to a word-level `Bit.Zeros`** kernel: a `swift-bit-vector-primitives` refactor enabled once `Bit.Zeros<Word>` exists (eliminates the inline complement-scan duplication, §4.2).

---

## 11. Outcome

**Status**: RECOMMENDATION.

The complete and correct primitive-domain decomposition of `swift-bit-primitives`:

1. **Scale boundary as a target boundary** (§6.1): the zero-dependency root `Bit Primitive` owns the single-bit *atom* (`Bit`, `Bit.Order`, Boolean/Z₂ algebra); the *word-of-bits* kernels move out.
2. **Add `Bit.Zeros<Word>`** (§6.2): complete the symbol-parameterized rank/select/scan lattice; the asymmetry was an incompleteness, decided against by theory, Rust, the container layer's existing symmetry, and [RES-020a] merit framing.
3. **Extract word-kernels into Cardinal-typed sub-namespace targets** (§6.3, §6.5): `Bit Mask Primitives`, `Bit Ones Primitives`, `Bit Zeros Primitives` (Cardinal + Carrier), per [MOD-031]; positions/counts typed `Cardinal` (the brief's `some Carrier.\`Protocol\`<Cardinal>`); [ARCH-LAYER-004] does not apply. This subsumes the deferred /modularization step.
4. **Primitive vs derived** (§6.4): atom + native Z₂ ops + `Bit.Order` are PRIMITIVE (root); the word-kernels are PRIMITIVE (extracted targets); stdlib + institute-protocol conformances are DERIVED (SLI / conformances target); the `Algebra.Field<Bit>` witness is DERIVED and already correctly extracted to `swift-bit-algebra-primitives`.
5. **Restore umbrella purity** (§8.3) and **relocate native Z₂ ops to the root** (§8.4).

This document **supersedes** `bit-primitives-completeness-analysis.md` on the decomposition axis and carries forward all of its findings (§9). The reshape is a gated follow-up.

---

## 12. References

### Internal corpus (governing per [RES-019])
- `swift-bit-primitives/Research/bit-primitives-completeness-analysis.md` v2.0.1 (superseded by this doc).
- `swift-institute/Research/bit-vector-zeros-infrastructure.md` v1.0.0 — container-level ones/zeros symmetry precedent.
- `swift-institute/Research/bitset-architecture-ideal-model.md` v1.0.0; `comparative-bitset-bitvector-primitives.md`; `bitset-naming-literature-study.md` v1.0.0 — bit ecosystem layering + naming.
- `swift-institute/Research/bit-vector-type-organization.md`; `bit-vector-primitives-reducibility.md`; `data-structures-bit-collections-assessment.md` v2.0.0 — reducibility + primitive boundary.
- `swift-institute/Research/byte-primitive-extraction-and-domain-naming.md` v1.1.1; `byte-protocol-capability-marker.md` v1.1.0; `binary-byte-namespace-domain-foundations.md` v3.1.0 — byte-domain decomposition precedent.
- `swift-bit-primitives/Research/Bit Primitives Extension Patterns Analysis.md` v1.0.0 — [BIT-001] source.

### Governing skill requirements
- [MOD-DOMAIN], [MOD-005], [MOD-008], [MOD-010], [MOD-015], [MOD-017], [MOD-020], [MOD-026], [MOD-029], [MOD-030], [MOD-031], [MOD-035] (modularization).
- [API-NAME-001b], [API-NAME-001c], [API-NAME-002], [API-NAME-008] (code-surface); [BIT-001] (bit-primitives); [PKG-NAME-016] (swift-package).
- [ARCH-LAYER-004], [ARCH-LAYER-008] (swift-institute); [PRIM-FOUND-004] (primitives); [IMPL-002] (implementation).
- [RES-019], [RES-020], [RES-020a], [RES-021], [RES-022], [RES-024], [RES-032] (research-process); [META-003], [META-004], [META-008], [META-016] (corpus-meta-analysis).

### External primary sources (verified 2026-06-01 via parallel subagent survey, [RES-020]/[RES-032])
- Rust `u32` (count_ones/zeros, leading/trailing ones/zeros): https://doc.rust-lang.org/std/primitive.u32.html
- Rust `bitvec` `BitSlice` (count_ones/zeros, iter_ones/iter_zeros): https://docs.rs/bitvec/latest/bitvec/slice/struct.BitSlice.html
- C++ WG21 P0553R4 "Bit operations" (`<bit>` free templates; no zero-population analog): https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0553r4.html
- C++ `<bit>` / `std::bitset` (Microsoft Learn): https://learn.microsoft.com/en-us/cpp/standard-library/bit-functions / https://learn.microsoft.com/en-us/cpp/standard-library/bitset-class
- Go `math/bits` (free funcs on uint; OnesCount only): https://pkg.go.dev/math/bits
- Zig language reference (`u1` native; @popCount/@clz/@ctz): https://ziglang.org/documentation/master/
- Haskell `Data.Bits` (Bits/FiniteBits, `instance Bits Bool`): https://hackage.haskell.org/package/base-4.21.0.0/docs/Data-Bits.html ; source: https://hackage.haskell.org/package/base-4.11.0.0/docs/src/Data.Bits.html
- RISC-V Bitmanip (Zbb vs Zbs): https://github.com/riscv/riscv-bitmanip/blob/main/bitmanip/bitmanip.adoc
- Succinct structures, symmetric rank/select (rank_0 = i − rank_1): https://arxiv.org/pdf/2206.01149 ; https://arxiv.org/pdf/2405.15088 (Navarro, *Compact Data Structures*, is the canonical textbook).
- ISA specifics for x86 (POPCNT/LZCNT/TZCNT) and ARM (RBIT/CLZ/CNT): per `bit-primitives-completeness-analysis.md` §2.2 citations (Intel SDM Vol. 2; ARM ARM DDI 0487) — **not** re-fetched this pass ([RES-032]).
