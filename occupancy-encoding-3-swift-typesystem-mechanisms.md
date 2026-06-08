# Occupancy Encoding (3) — The Swift 6.3.2 Mechanism Frontier (incl. Macros)

<!--
---
version: 1.0.0
last_updated: 2026-06-08
status: DECISION
tier: 3
scope: ecosystem-wide
type: investigation/compiler-mechanism
toolchain_of_record: Apple Swift 6.3.2 (swift-6.3.2-RELEASE, TOOLCHAINS=org.swift.632202605101a), arm64-apple-macosx26.0
companion_to: angle 3 of the multi-angle occupancy-encoding study (shared 2026-06-08 dispatch)
builds_on:
  - occupancy-lives-in-the-leaf.md                          # the placement LAW (AX: occupancy in the leaf) — consumed
  - conditional-deinit-conditionally-copyable-generics.md   # the SE-0427 Wall-1 proof + S1–S8 matrix — extended, not repeated
  - occupancy-encoding-4-placement-proof.md                 # the information floor + satisfiability matrix (cell 14) — cross-referenced; my mechanism map is its mechanism-axis companion
  - storage-small-substrate.md                              # the Storage.Small enum-arm seam reconciliation (v1.0.1) — RECONCILED here (N14)
  - macro-composition-architecture.md                       # the "macros cannot see each other's expansions / no macro-applies-macro" constraint — consumed
sibling_angles:
  - occupancy-encoding-2-category-theory-composition.md     # category theory (composition over refinement)
  - occupancy-encoding-4-placement-proof.md                 # placement proof + information-theoretic lower bound
  - occupancy-encoding-5-prior-art-and-vacuity.md           # cross-language prior art + vacuity census
---
-->

**Coen ten Thije Boonkkamp · Swift Institute · June 2026**

> **RESEARCH ONLY** — no tower edits. Every load-bearing compile/diagnostic claim was produced on
> **Apple Swift 6.3.2** (`TOOLCHAINS=org.swift.632202605101a` → `swift-6.3.2-RELEASE`,
> `arm64-apple-macosx26.0`); sources + binaries at `/tmp/occ3-mechanisms/` (the `N`/`M` spikes) and
> `/tmp/occ3-mechanisms/SparseMacro/` (a *working* macro package). Each such claim carries
> `[Verified: 2026-06-08]`. No wall is claimed without a minimal repro on 6.3.2.

## Abstract

The shared problem asks how far Swift's type system can encode an occupancy-bearing container that
*simultaneously* achieves all of **(A)** one `Store.`Protocol`` (no refinement); **(B)** ≤1 bit/slot
bit-density; **(C)** value-semantics / conditional `Copyable` with the `.Inline`/`.Small` carve-out
*types* dissolved into one generic `Buffer<S>`; **(D)** self-cleaning teardown (no buffer `deinit`;
SE-0427 Wall-1 avoided); **(E)** maximal decomposition + clean composition.

The companion notes settle the *placement* (occupancy → leaf — `occupancy-lives-in-the-leaf.md`), the
*soundness law and S1–S8 probe matrix* (`conditional-deinit-conditionally-copyable-generics.md`), the
*information floor + satisfiability grid* (`occupancy-encoding-4-placement-proof.md`, which proves the
unique excluded cell), and the *category theory* (`occupancy-encoding-2`). **This note is the mechanism
axis**: a complete map of *which Swift 6.3.2 language and metaprogramming mechanisms can — and cannot —
move the frontier*, with the central question being **macros**: can a `@Sparse` / `@Occupancy` attached
macro *synthesize at source level* the pieces the language will not express directly — emit both a
conditionally-`Copyable` (no-`deinit`) and an unconditionally-`~Copyable` (with-`deinit`) specialization
from one author-written type, dissolving the carve-out at SOURCE level?

**Headline results, all reproduced on 6.3.2:**

1. **The inline corner is blocked by *two* independent compiler facts, not one.** Beyond Wall-1
   (`deinit ⟹ unconditionally ~Copyable`, S1), `@_rawLayout` *independently* forbids conditional
   copyability: *"type with `@_rawLayout` cannot be copied and must be declared `~Copyable`"* (N4),
   even with **no `deinit` anywhere**. The inline move-only-ness is over-determined.
2. **`InlineArray` (SE-0453) is the conditional-`Copyable` inline leaf that `@_rawLayout` cannot be.**
   `InlineArray<n, T>` propagates copyability conditionally, has automatic per-element teardown (no
   user `deinit`), is inline (zero-heap), and witnesses a `~Copyable`-element `_read`/`_modify` seam —
   all on 6.3.2 (N5, N7, N13). The dense-inline-value-semantics path ("`InlineArray` + count", doc #4
   cell 10) and the niche tombstone path (cells 13/5) are *empirically realized* here.
3. **The `InlineArray` win does NOT contradict `storage-small-substrate.md` v1.0.1.** That note's
   blocker was the *pointer-stable* `Store.`Protocol`` seam (raw-pointer `Offset` arithmetic) through an
   **enum** `_Representation` arm; `InlineArray` gives *value-semantics* unpack/repack mutation, not a
   stable element pointer (N14). The two are reconciled, not in conflict — a fourth facet of the
   residual.
4. **Macros mechanize the leaf but cannot dissolve the carve-out.** A `@SparseLeaf` attached
   member+extension macro *does* synthesize a complete tombstone sparse leaf — storage, seam, AND the
   conditional-`Copyable` conformance — from a one-line annotation, building and running on 6.3.2
   (`/tmp/occ3-mechanisms/SparseMacro/`). But the *language-level* impossibility survives macro
   expansion: two same-named specializations are an `invalid redeclaration` (M0), there is **no
   type-level predicate on element layout/spare-bits** for a macro (or anything) to branch on (M3), and
   macros are purely syntactic — they never see `T`'s layout (`macro-composition-architecture.md`). The
   most a macro can legally emit is **two distinctly-named** types (M2) — it *re-manufactures* the
   carve-out under macro-chosen names; it does not *dissolve* it.

**The mechanism verdict in one sentence.** Every Swift 6.3.2 mechanism — conditional conformances,
`~Copyable`/`~Escapable`, `@_rawLayout`, move-only classes, `borrowing`/`consuming`/`consume`/`discard`,
`@_specialize`, suppressed-protocol generics, `InlineArray`, and attached macros — either *composes the
existing leaf lattice* (and so reaches all of (A)+(D)+(E) plus (B)/(C) outside the single excluded
cell) or *fails to move the excluded cell*; **no mechanism, macros included, collapses the
{inline × sparse × value-semantics × no-niche} cell** — that requires the one language feature the
companion notes name: a conditional `deinit`.

---

## Context

The MSB buffer tower converged on the placement law (`occupancy-lives-in-the-leaf.md`, DECISION
2026-06-07): liveness + teardown live in a single-allocation *leaf*, never in the buffer; the buffer is
one `deinit`-free generic over `S: Store.`Protocol``, so its copyability *flows from the leaf*. That
law dissolved the `.Inline`/`.Small` *buffer* carve-out *types*; the residual is the trilemma
*bit-density + value-semantics + inline, simultaneously*, of which one corner must yield.

The shared dispatch poses this as a *frontier* problem with five labelled properties (A)–(E) and asks
each angle to push the frontier with its own toolkit. **My toolkit is the compiler-mechanism frontier
itself, with macros as the central novel lever.** The honest mandate: find the maximal achievable
point, prove the boundary, and assess vacuity — and never claim a wall without a 6.3.2 repro.

### Why a separate mechanism note (not subsumed by doc #4)

Doc #4 (placement-proof) treats the arrangement *information-theoretically*: given the placement law,
what is the bit floor and which grid cell is excluded? It proves the *boundary* using the SE-0427 law
as a single consumed axiom (AX-1). **It does not enumerate the mechanism space** — it does not ask
*which of Swift's ~10 ownership/layout/metaprogramming mechanisms can each independently move that
boundary*, nor does it touch macros at all. That enumeration is this note's original content: it is the
*mechanism-axis dual* of doc #4's information-axis proof. Where doc #4 proves *"cell 14 is excluded
unless a conditional `deinit` arrives"*, this note proves *"and here is exactly why each candidate
mechanism — including a synthesizing macro — fails to be that conditional `deinit`."*

### Trigger

Shared 2026-06-08 dispatch, angle 3: "Attack Wall-1 and the refinement with EVERY mechanism, mapping
precisely what compiles on 6.3.2 (with repros)… CENTRAL: macros. Can a `@Sparse`/`@Occupancy` attached
macro SYNTHESIZE the pieces the language won't express directly… dissolving the carve-out at SOURCE
level?"

### Constraints

- **No wall claim without a 6.3.2 repro** (`TOOLCHAINS=org.swift.632202605101a`). All load-bearing
  diagnostics reproduced; artifacts `/tmp/occ3-mechanisms/`.
- Research only — no tower edits; `/tmp` scratch only.
- Tier-3 rigor per [RES-020]/[RES-022]/[RES-023]/[RES-024]/[RES-026]: formal semantics inline, prior-art
  contextualization, every empirical claim verified at write time, parallel-source-verified citations.
- Per [RES-019] internal-first: extends the four sibling/parent notes above rather than re-deriving
  them; the Wall-1 proof and S1–S8 matrix are *consumed*, not repeated.

---

## Question

Over the full set of Swift 6.3.2 mechanisms, for each mechanism `m`:

1. **Does `m` compile** in the configurations relevant to an occupancy-bearing leaf/buffer, and with
   what exact diagnostic when it does not?
2. **Does `m` move the frontier** — i.e. does it unlock a configuration of (A)–(E) that the existing
   leaf lattice cannot already reach, *specifically* the excluded {inline × sparse × value-semantics ×
   no-niche} cell?
3. **For macros specifically:** can an attached/freestanding macro synthesize, from one author-written
   type, *both* a conditionally-`Copyable` (no-`deinit`) and an unconditionally-`~Copyable`
   (with-`deinit`) specialization — dissolving the carve-out at source level — or emit the per-element
   spare-bit cell, or generate the allocation surface so the leaf stays a syntactically-4-op
   `Store.`Protocol``?

---

## Methodology

Two spike batteries, both on 6.3.2 (`swift-6.3.2-RELEASE`), extending the companion note's S1–S8 (which
I re-verified as my baseline before extending — all eight reproduce identically, [Verified: 2026-06-08]):

| Battery | Probes | What it maps |
|---------|--------|--------------|
| **N (non-macro mechanisms)** | N1–N14 | move-only classes; `@_rawLayout` under conditional `Copyable`; `InlineArray` conditional `Copyable` + seam; tombstone sparse; spare-bit density; `discard`/`~Escapable`/`@_specialize`; the enum-arm `_modify` reconciliation |
| **M (macros)** | M0–M3 + a built package | the language seam a macro could target; a working `@SparseLeaf` member+extension macro; the two-named-types limit; the no-type-level-layout-predicate limit |

Sources consulted directly (file:line, [Verified: 2026-06-08]): `Store.Protocol.swift:20-69`,
`Memory.Inline.swift:41-114`, `Storage.Arena.swift:75-278`, `Storage.Contiguous.swift:46-71`,
`Storage.Contiguous+Store.Protocol.swift:20-109`, `swift-dual/Package.swift` (the macro-plugin
template that builds on 6.3.2), `storage-small-substrate.md` §2.2 + the v1.0.1 revision,
`macro-composition-architecture.md` (the macro-composition constraints).

---

## Axioms consumed (proved elsewhere, re-verified here)

| # | Axiom | Source | Re-verified on 6.3.2 |
|---|-------|--------|----------------------|
| AX-1 (Wall-1) | `hasUserDeinit(W) ⟹ ¬∃(W : Copyable)` — value `deinit` ⟹ *unconditionally* `~Copyable`. | SE-0427; `copyable_illegal_deinit` (`DiagnosticsSema.def:8390`). | **S1**: `error: deinitializer cannot be declared in generic struct 'Wrapper' that conforms to 'Copyable'` |
| AX-2 (class exemption) | A class may carry a `deinit` + store `~Copyable` fields while staying a `Copyable`-layout reference. | `TypeCheckInvertible.cpp:221-223`. | **N2** (Box-relocation compiles); shipped `Storage.Arena.Backing`. |
| AX-3 (conditional auto-teardown) | `destroy-fields` is already per-slot liveness-conditional: a `~Copyable` field runs its `deinit`; a `Copyable` field is trivial. | Spike S7. | **S7** re-run: `MoveOnly(1) deinit fired` / `copied ok: 42, 42` |
| AX-4 (placement law) | Occupancy + teardown in the leaf; buffer is a `deinit`-free generic. | `occupancy-lives-in-the-leaf.md`. | `Storage.Contiguous.swift:68` ("No `deinit` anywhere"); `Storage.Arena` shipped. |
| AX-5 (`Store.Protocol` neutrality) | The 4-op seam (`capacity`, `subscript{get set}`, `initialize`, `move`) is pointer-free, copyability-agnostic (`associatedtype Element: ~Copyable`), cross-module-specializing. | `Store.Protocol.swift:20-69`. | Read directly. |

The S1–S8 baseline re-verification (the ground I extend) is captured at
`/tmp/cdspikes/` and re-run 2026-06-08: S1/S3/S4/S6/S8 fail with the documented diagnostics; S2/S5/S7
compile; S7 runs with conditional auto-teardown. **I add nothing to the S-series; the N/M series are new.**

---

## Part I — The non-macro mechanism frontier (N-series)

### I.1 Move-only classes — *do not exist* on 6.3.2 (N1)

The heap escape (AX-2) relies on a class being a `Copyable`-layout reference that can carry a `deinit`.
A *move-only* class — which might host a `deinit` while being itself `~Copyable` — is **rejected**:

```
// N1
final class Box<T: ~Copyable>: ~Copyable { var value: T; deinit {} }
//          ^ error: classes cannot be '~Copyable'
```

`error: classes cannot be '~Copyable'` [Verified: 2026-06-08]. **Consequence:** the only class-hosted
`deinit` is on a *Copyable-layout* class — i.e. a heap allocation. There is no "move-only class leaf"
that would let inline-sparse host its `deinit` on a reference without paying for the heap box. This
closes one imagined escape from the excluded cell at the *class* axis.

### I.2 The Box-relocation compiles (N2) — the heap escape, confirmed

```swift
// N2 — [MEM-COPY-016] Box-relocation, tested directly
final class Backing<T: ~Copyable> { var value: T; init(_ v: consuming T){value=v}; deinit {} }
struct Wrapper<T: ~Copyable>: ~Copyable { var backing: Backing<T>; init(_ v: consuming T){backing=Backing(v)} }
extension Wrapper: Copyable where T: Copyable {}        // compiles; conditional copy exercised
```

Compiles [Verified: 2026-06-08]. This is the heap-sparse optimum (doc #4 cell 6; shipped as
`Storage.Arena.Backing`). It is *not* available inline (N1 + the heap allocation it entails).

### I.3 `@_rawLayout` *independently* forbids conditional copyability (N3, N4) — the second wall

This is the note's first original finding. The companion notes attribute the inline move-only-ness to
Wall-1 (the `deinit`). But `@_rawLayout` forbids conditional copyability **independently of any
`deinit`**:

```swift
// N4 — @_rawLayout struct with NO deinit anywhere
struct Leaf<T: ~Copyable, let n: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: T, count: n)
    struct Raw { init() {} }                            // not declared ~Copyable
    var raw: Raw
}
extension Leaf: Copyable where T: Copyable {}
```

```
error: type with '@_rawLayout' cannot be copied and must be declared ~Copyable
```

[Verified: 2026-06-08, `-enable-experimental-feature RawLayout`]. The `@_rawLayout` attribute *forces*
`~Copyable` on its bearing type. Consequently (N3) the `@_rawLayout` `Raw` field is an *unconditionally*
`~Copyable` **struct** field, which poisons the conditional-`Copyable` wrapper by the *same* mechanism
as S8 — but now the root cause is the layout attribute, not a user `deinit`:

```
// N3
error: stored property 'raw' of 'Copyable'-conforming generic struct 'Leaf' has non-Copyable type 'Leaf<T, n>.Raw'
note: struct 'Raw' has '~Copyable' constraint preventing 'Copyable' conformance
```

> **Finding I.3 (the inline corner is over-determined).** An inline `@_rawLayout` leaf is move-only for
> **two** independent reasons on 6.3.2: (1) if it carries a `deinit` (which a separate-plane occupancy
> oracle requires), Wall-1/AX-1 fires (S1); and (2) *regardless of any `deinit`*, the `@_rawLayout`
> attribute itself forbids `Copyable` (N4). Removing Wall-1 alone (the conditional-`deinit` feature)
> would **not** suffice for the inline corner unless `@_rawLayout` is *also* taught conditional
> copyability. This sharpens doc #4's Theorem III.3: the inline-sparse-no-niche cell needs *either*
> conditional `deinit` *plus* conditional-`@_rawLayout`, *or* the `InlineArray` route (§I.4), which sheds
> `@_rawLayout` entirely.

This is why `DS-002`'s phrasing — *"`@_rawLayout` raw storage also cannot be auto-copied, **reinforcing**
the same outcome"* — is exactly right and load-bearing: it is a *second*, independent forcing function,
not a restatement of the deinit wall.

### I.4 `InlineArray` (SE-0453) IS the conditional-`Copyable` inline leaf (N5, N7, N13) — the key positive result

`InlineArray<n, T>` is the stdlib's compiler-managed inline buffer. Unlike `@_rawLayout`, it propagates
copyability conditionally and self-cleans automatically:

```swift
// N5 — InlineArray conditional Copyable
struct Leaf<T: ~Copyable, let n: Int>: ~Copyable { var slots: InlineArray<n, T>; … }
extension Leaf: Copyable where T: Copyable {}           // COMPILES (N4's @_rawLayout did not)
```

```swift
// N7 / N13 — the ~Copyable-element seam + full leaf, RUN on 6.3.2
struct DenseInline<T: ~Copyable, let n: Int>: ~Copyable {
    var slots: InlineArray<n, T>
    var initializedCount: Int                           // a range-ledger as ACCESS discipline (no teardown oracle needed)
    subscript(i: Int) -> T { _read { yield slots[i] }  _modify { yield &slots[i] } }   // ~Copyable element seam
}
extension DenseInline: Copyable where T: Copyable {}
```

Runtime [Verified: 2026-06-08]: the move-only instantiation (`T = MoveOnly`) fires per-element
`deinit`s on drop (`deinit 0 / deinit 1 / deinit 2`) with **no user `deinit` declared**; the `Copyable`
instantiation copies (`2 / 2`). So an `InlineArray`-backed leaf achieves, *simultaneously*:

- **(C)** conditional value-semantics (copyability flows from `T`, via N5),
- **(D)** self-cleaning with **no user `deinit`** (so Wall-1 *never applies* — AX-3 automatic field
  teardown does the work),
- inline (zero-heap, stack storage), and
- an element-level `_read`/`_modify` seam for `~Copyable T`.

> **Finding I.4 (the dense-inline-value-semantics path is real on 6.3.2).** Doc #4's cell 10
> resolution ("`InlineArray` + count") is empirically realized: a dense inline `Copyable`-element
> container needs *no teardown oracle* (a prefix `count` is pure access discipline; a fixed
> `Copyable` array auto-destroys), so it is conditionally `Copyable`, inline, self-cleaning, with no
> `deinit`. This is a genuine inline leaf the tower's current `@_rawLayout` `Memory.Inline` (move-only)
> does not provide — gained precisely because `InlineArray` propagates copyability where `@_rawLayout`
> forbids it (N4).

### I.5 The tombstone sparse leaf — sparse (B)/(C) coexist *under a niche* (N6b, N8, N9)

For the *sparse* case, `InlineArray<n, T?>` encodes occupancy in the slot itself (`.some` = occupied):

```swift
// N8 — tombstone sparse inline leaf, RUN on 6.3.2 (no user deinit)
struct SparseLeaf<T: ~Copyable, let n: Int>: ~Copyable {
    var slots: InlineArray<n, T?>
    mutating func insert(_ v: consuming T, at i: Int) { slots[i] = consume v }
    mutating func remove(at i: Int) -> T? { var t: T? = nil; swap(&t, &slots[i]); return t }
}
extension SparseLeaf: Copyable where T: Copyable {}
```

Runtime [Verified: 2026-06-08]: insert 0,2 into a move-only leaf → exactly two `deinit`s on drop (slots
1,3 are `nil`); the `Copyable` instantiation copies + isolates (`a.occupied=1 b.occupied=2`). Conditional
`Copyable`, inline, self-cleaning, **no user `deinit`** — for *sparse* liveness.

The cost is density, and it is **element-type-dependent** (the niche characterization, matching doc #4's
Theorem I.3 from an independent measurement — N9, `InlineArray<8, _>`, [Verified: 2026-06-08]):

| Element | bare | `Optional` | density verdict |
|---------|------|-----------|-----------------|
| `class Ref` | 64 B | 64 B | **FREE** (niche/spare bit) |
| `UnsafeRawPointer` | 64 B | 64 B | **FREE** |
| `Bool` | 8 B | 8 B | **FREE** |
| `enum{a,b,c}` | 8 B | 8 B | **FREE** |
| `struct{ptr}` | 64 B | 64 B | **FREE** |
| `Int` | 64 B | 128 B | **COSTS** (2×, no spare bit) |
| `UInt8` | 8 B | 16 B | **COSTS** (2×, no spare bit) |

> **Finding I.5 (the residual is the *no-niche* sub-case only).** The tombstone leaf delivers all of
> (B)+(C)+(D)+inline *simultaneously* whenever the element exports ≥1 extra inhabitant — i.e. for
> classes, pointers, `Bool`, small enums, and any padded struct. The trilemma's "one honest residual"
> bites **only** for fully-packed scalar elements (`Int`, `Double`, full-domain integers). This is the
> mechanism-axis confirmation of doc #4's cell 14 ({inline × sparse × value-semantics × **no-niche**}):
> the excluded region is precisely the no-niche corner, reproduced here from `MemoryLayout` rather than
> from the information-theoretic floor.

### I.6 Reconciliation with `storage-small-substrate.md` v1.0.1 (N14) — the fourth facet

`storage-small-substrate.md` v1.0.1 (DECISION) *withdrew* the `InlineArray<n, T?>` route ("Route 2") for
`Storage.Small`, on the ground that the real `Store.`Protocol`` seam — typed `Index<Element>` +
**raw-pointer `Offset` arithmetic**, with `_modify` yielding a **stable element pointer** — cannot be
witnessed through an `InlineArray` arm inside the `_Representation` **enum**. My N7/N13 results
(`InlineArray` *does* witness a `_read`/`_modify` seam) appear to contradict that. They do not. The
distinction is precise:

```swift
// N14c — InlineArray held in an ENUM case: in-place mutation works via consume self → unpack → repack
enum Repr<T: ~Copyable, let n: Int>: ~Copyable {
    case inline(InlineArray<n, T>)
    mutating func set(_ v: consuming T, at i: Int) {
        switch consume self { case .inline(var a): a[i] = consume v; self = .inline(consume a) }
    }
}
extension Repr: Copyable where T: Copyable {}           // compiles + runs: slot2=7
```

Runtime [Verified: 2026-06-08]. This gives **value-semantics mutation** (unpack the inline arm, mutate,
repack) — but **not a stable mutable element pointer**: the whole inline arm is moved in and out. The
real `Store.`Protocol`` seam the tower uses needs pointer stability (`$0 + Index<Element>.Offset(...)`,
sound only because the backing is class/`@_rawLayout`).

> **Finding I.6 (the fourth facet of the residual — the *seam shape*, not just density).** The
> `InlineArray` leaf is conditionally `Copyable` + self-cleaning + inline for the **value-semantics
> seam** (whole-value `_read`/`_modify`, or unpack/repack through an enum arm) — N7/N8/N13/N14c. It is
> *not* a drop-in for the tower's **pointer-stable** `Store.`Protocol`` seam (stable element pointer via
> `Offset` arithmetic). So the choice at the inline-sparse-no-niche corner is *three*-way, not two-way:
> keep the pointer-stable seam (→ `@_rawLayout`, move-only); OR adopt value-semantics + conditional
> `Copyable` inline (→ `InlineArray`, *lose* the pointer-stable seam and, for no-niche elements, *also*
> lose (B)); OR relocate to a heap class (→ lose zero-heap). `storage-small-substrate.md` v1.0.1's
> withdrawal is correct *for `Storage.Small`'s pointer-stable seam*; this note's `InlineArray` results
> are correct *for the value-semantics seam* — they are complementary, and together they say the
> residual is a *seam-shape* trade as well as a density trade.

### I.7 The remaining mechanisms do not move the frontier (N10, N11, N12)

| Mechanism | Probe | Result on 6.3.2 | Verdict |
|-----------|-------|-----------------|---------|
| `discard self` (SE-0429) | N10 | `error: deinitializer cannot be declared in generic struct 'Leaf' that conforms to 'Copyable'` — Wall-1 fires on the `deinit` *before* `discard` is even relevant | Does not help: `discard` suppresses an *existing legal* `deinit` on a path; it cannot create the conditional-`deinit` seam. |
| `~Escapable` | N11/N11b | orthogonal (lifetime axis); the `deinit`/copyability coupling is unchanged (incidental init-lifetime errors aside) | No effect on the copyability/`deinit` interaction. |
| `@_specialize` | N12 | `error: '@_specialize' attribute cannot be applied to this declaration` | A perf hint, not a semantics lever; cannot give per-instantiation `deinit`. |
| `borrowing`/`consuming`/`consume` | used throughout (N8 `consume v`, N14c `consume self`) | compile + run | The *correct* ownership plumbing for the seam, but they move data, not the copyability law. |
| suppressed-protocol generics (`Element: ~Copyable`, `Store.Protocol: ~Copyable`) | the whole tower (AX-5) | compile | Necessary substrate; copyability-agnostic by design — they enable the leaf lattice but do not collapse cell 14. |

> **Finding I.7.** None of `discard`, `~Escapable`, `@_specialize`, the ownership specifiers, or
> suppressed-protocol generics move the excluded cell. Each either fires Wall-1 first (`discard`), is on
> an orthogonal axis (`~Escapable`), is a non-semantic hint (`@_specialize`), or is necessary-but-not-
> sufficient substrate (ownership specifiers, suppressed protocols).

---

## Part II — The macro frontier (M-series) — the central angle

The dispatch's central question: can a `@Sparse`/`@Occupancy` macro *synthesize* what the language will
not express — emit both copyability specializations from one author type, dissolving the carve-out at
source level? I answer with a **working macro** built and run on 6.3.2, plus the language-seam probes
that bound what any macro can do.

### II.1 Macros build and run on 6.3.2 (and the deployment-target caveat)

The ecosystem's macro packages (`swift-dual`, `swift-witnesses`, `swift-defunctionalize`) are L3/L4 and
build clean on 6.3.2 (`swift-dual` full build: `Build complete! (47.69s)` [Verified: 2026-06-08]). I
built a fresh minimal `SparseMacro` package (`SwiftSyntax` 602, the same pin) to test the occupancy
hypotheses directly.

**Caveat surfaced empirically:** `InlineArray`'s *mutable subscript setter* is annotated `macOS 26.0+`;
a SwiftPM package targeting `.macOS(.v15)` fails to expand a macro that mutates an `InlineArray`
(`error: cannot pass as inout because setter for 'subscript(_:)' is only available in macOS 26.0 or
newer`). Bumping the platform to `.macOS("26.0")` resolves it. This is a real deployment-floor
constraint on any `InlineArray`-based leaf, *independent of the macro* (my bare `swiftc` spikes hit
`macosx26.0` by default, which is why N7/N8 worked there).

### II.2 A `@SparseLeaf` macro CAN synthesize the whole leaf (the positive result)

`/tmp/occ3-mechanisms/SparseMacro/` declares:

```swift
@attached(member, names: named(slots), named(init()), named(occupiedCount), named(insert(_:at:)), named(remove(at:)))
@attached(extension, conformances: Copyable)
public macro SparseLeaf() = #externalMacro(module: "SparseMacros", type: "SparseLeafMacro")
```

The author writes only:

```swift
@SparseLeaf
struct Leaf<T: ~Copyable, let n: Int>: ~Copyable {}     // ← one line; the macro fills the body
```

The `MemberMacro` half emits the tombstone storage + the sparse seam (`slots: InlineArray<n, T?>`,
`init`, `occupiedCount`, `insert`, `remove`); the `ExtensionMacro` half emits
`extension Leaf: Copyable where T: Copyable {}`. Build + run [Verified: 2026-06-08]:

```
A) move-only: insert 0,2; per-occupied teardown:
  deinit MoveOnly(0)
  deinit MoveOnly(2)
B) copyable instantiation copies + isolates (uses macro-emitted conditional Copyable):
  a.occupied=1 b.occupied=2
```

> **Finding II.2 (macros mechanize the leaf and the conformance).** An attached member+extension macro
> *does* synthesize the complete tombstone sparse leaf — storage, the full insert/remove/occupiedCount
> seam, AND the conditional-`Copyable` conformance — from a one-line annotation, producing a working,
> conditionally-`Copyable`, inline, self-cleaning (no user `deinit`) sparse leaf on Swift 6.3.2. *Two of
> the three things the dispatch asked a macro to do are achievable:* (a) emit the per-element occupancy
> cell (the `InlineArray<n, T?>` tombstone *is* the per-element occupancy mechanization), and (c) keep
> the leaf's surface a clean seam while the macro wires occupancy. The macro is legitimate leverage for
> *boilerplate elimination* — it turns a ~40-line hand-written leaf into one annotation.

But note **why** this works: the macro is conditionally `Copyable` *because the tombstone representation
it emits is* (N6b), not because the macro did anything the language forbids. The macro is a *source
expander*; it cannot grant a representation a copyability the representation does not have.

### II.3 A macro CANNOT dissolve the carve-out (the boundary)

The dispatch's hardest ask — emit *both* a conditionally-`Copyable` (no-`deinit`) **and** an
unconditionally-`~Copyable` (with-`deinit`) specialization from one author type, *under one name* — is
foreclosed at three independent points, all on 6.3.2:

**(1) Two same-named specializations are an `invalid redeclaration` (M0).** The "one type, two
copyability modes" dream requires either a `deinit` gated by `T` (S1 — illegal) or two declarations
sharing a name:

```swift
// M0
struct Foo<T: ~Copyable>: ~Copyable { var v: T; … deinit {} }
struct Foo<T> { var v: T; … }                           // error: invalid redeclaration of 'Foo'
```

`error: invalid redeclaration of 'Foo'` [Verified: 2026-06-08]. A macro emits *source*; emitting two
same-named types yields the same error. **The carve-out cannot be unified under one name even by a
macro**, independent of Wall-1.

**(2) The most a macro can legally emit is two *distinctly-named* types (M2).** The legal shape is:

```swift
// M2 — what a macro is limited to
extension Sparse {
    struct Move<T: ~Copyable>: ~Copyable { var v: T; … deinit {} }          // uncond ~Copyable
    struct Value<T: ~Copyable>: ~Copyable { var v: T?; … }                   // cond Copyable
}
extension Sparse.Value: Copyable where T: Copyable {}
```

Compiles [Verified: 2026-06-08] — but a consumer must *choose* `Sparse.Move` vs `Sparse.Value`. **The
macro re-manufactures the carve-out under macro-chosen names; it does not dissolve it.** This is exactly
the carve-out `occupancy-lives-in-the-leaf.md` dissolved at the *buffer* level by moving occupancy to
the leaf — a macro at the *leaf* level would *reintroduce* a two-type choice the placement law removed.

**(3) There is no type-level predicate on element layout for a macro (or anything) to branch on (M3).**
Even auto-*selecting* tombstone-vs-`@_rawLayout` based on the element's spare-bit budget is impossible:

```swift
// M3
typealias Storage = (MemoryLayout<T?>.size == MemoryLayout<T>.size) ? T? : T   // error: expected ',' separator
```

`error: expected ',' separator` [Verified: 2026-06-08] — there is no `?:`-on-types, and `MemoryLayout<T>`
is a *runtime value*, not a type-level predicate. There is no `where T: HasSpareBits`. **A macro is
purely syntactic — it never sees `T`'s layout** (it operates on the *unexpanded source*;
`macro-composition-architecture.md`: "Macros cannot see other macros' expansions… A macro implementation
CAN check whether `@Dual` is present… but cannot access what `@Dual` would generate"). So a macro cannot
even *read* whether the element has a niche, let alone branch the type definition on it.

> **Finding II.3 (the macro boundary, precisely).** A macro can (i) mechanize a leaf whose copyability
> the *representation* already grants (II.2), and (ii) emit a hand-written choice as two distinctly-named
> types (M2). A macro **cannot**: unify two copyability modes under one name (M0 — `invalid
> redeclaration`); branch a type definition on element layout/spare-bits (M3 — no type-level layout
> predicate); or grant a `@_rawLayout`/`deinit` representation a conditional copyability the language
> forbids (N4/S1 survive expansion — the macro emits source, and the *expanded source* hits the same
> walls). Macros move *boilerplate*, not the *copyability law*. The carve-out is a property of the
> language's copyability predicate, which is downstream of macro expansion, not upstream of it.

### II.4 Why the macro cannot be the conditional `deinit`

Doc #4's Theorem III.3 proves cell 14 collapses *iff* the language admits a conditional `deinit`. A
macro cannot be that feature: the conditional `deinit` requires the *compiler* to emit drop-glue into
the value-witness *only for the `~Copyable` specializations* — a code-generation decision keyed on the
generic instantiation's copyability, made *after* type-checking. A macro produces source *before*
type-checking; the source it produces is then subject to AX-1 (S1) and the `@_rawLayout` rule (N4) like
any other source. There is no macro phase that runs per-instantiation at IRGen. **The conditional
`deinit` is irreducibly a compiler feature; no source-level synthesis substitutes for it.**

---

## Part III — The consolidated mechanism map

Every mechanism in the dispatch's enumeration, mapped against the two questions {compiles on 6.3.2?
moves the excluded cell?}:

| Mechanism | Compiles on 6.3.2? | Probe | Moves cell 14 ({inline×sparse×VS×no-niche})? | Role in the achievable region |
|-----------|--------------------|-------|---------------------------------------------|-------------------------------|
| Conditional conformances | ✓ | S5/N5 | No | The mechanism that makes the buffer conditional `Copyable` over a leaf (AX-4). Foundational. |
| `~Copyable` generics | ✓ | S2/S5 | No | The whole tower's substrate; copyability-agnostic seam (AX-5). |
| `~Escapable` | ✓ (orthogonal) | N11 | No | Lifetime axis; no copyability/`deinit` interaction. |
| `@_rawLayout` | ✓ but **forces `~Copyable`** | N4 | No (it is *part of* the obstruction) | The move-only inline leaf (`Memory.Inline`); pointer-stable seam; **independently** forbids (C) (N4). |
| move-only classes | ✗ `classes cannot be '~Copyable'` | N1 | No | Do not exist; the heap escape is a *Copyable* class only. |
| Box-relocation (Copyable class) | ✓ | N2 | No (heap, not inline) | The heap-sparse optimum (cell 6; `Storage.Arena`). |
| `borrowing`/`consuming`/`consume` | ✓ | N8/N14c | No | Correct ownership plumbing for the seam; moves data, not the law. |
| `discard self` (SE-0429) | ✗ (Wall-1 fires first) | N10 | No | Suppresses an existing `deinit` on a path; cannot create conditional `deinit`. |
| `@_specialize` | ✗ on the decl | N12 | No | Perf hint, not a semantics lever. |
| suppressed-protocol generics | ✓ | AX-5 | No | Necessary substrate; copyability-agnostic. |
| **`InlineArray` (SE-0453)** | ✓ **conditional `Copyable`, no `deinit`** | N5/N7/N8/N13 | **Partially** — collapses the *value-semantics* sub-case for niche elements (cells 5/10/13) and the dense-inline path; **does not** collapse no-niche cell 14 (tombstone spends (B)), and gives up the pointer-stable seam (N14) | The conditional-`Copyable` inline leaf `@_rawLayout` cannot be; the realized cell-10/13 optimum. |
| **attached macros** | ✓ **build+run** | M-series + `SparseMacro/` | **No** — mechanize the leaf + conformance (II.2) but cannot unify two copyability modes (M0), branch on layout (M3), or beat AX-1/N4 (II.3/II.4) | Boilerplate elimination over the *existing* leaf lattice; not a frontier-mover. |
| conditional `deinit` (the missing feature) | ✗ not in the language | doc #4 Thm III.3 | **Yes (uniquely)** — *plus* conditional-`@_rawLayout` for the pointer-stable inline seam (Finding I.3) | The one feature that collapses cell 14; Evolution-scale; PITCH-0003 (held). |

---

## Formal note ([RES-024]) — what a macro is, relative to the copyability predicate

Recall doc #4 / the companion note's copyability predicate: a generic value type `W<T>` with stored
fields `f̄` admits `W<T> : Copyable` iff `(¬ hasUserDeinit(W)) ∧ (∀ f. type(f)[T] : Copyable)`, and the
`@_rawLayout` rule adds the conjunct `(¬ hasRawLayout(W))` (N4: a `@_rawLayout` type is unconditionally
`~Copyable`, so it can never be a `Copyable` field's type conditionally). A **macro** is a function
`μ : Source → Source` applied *before* this predicate is evaluated. Therefore for any macro `μ` and
author type `A`, the copyability of `μ(A)` is exactly the predicate applied to the *expanded* source —
the macro has **no privileged access** to relax `hasUserDeinit`, `hasRawLayout`, or the field-Copyable
conjunct. Formally:

```
Copyable(μ(A))  ⟺  Copyable(expand(μ, A))           -- the macro is transparent to the predicate
```

The conditional-`deinit` feature, by contrast, *changes the predicate itself* (it replaces the
constant conjunct `¬hasUserDeinit` with the constraint-gated `¬hasUserDeinit ∨ (instantiation is
~Copyable)`). A `Source → Source` function cannot change a predicate that is evaluated on its output.
**This is the formal reason no macro substitutes for the conditional `deinit`.**

---

## Prior art ([RES-021]) — the macro contextualization step

Universal practice is to use metaprogramming for *boilerplate*, not for *type-system relaxation*. The
ecosystem's own macro corpus confirms the limit: `macro-composition-architecture.md` records that
PointFree's `@DependencyClient` and `@CasePathable` "accepted the duplication" — each generates what it
needs independently, with "no macro composition" and "no macro-applies-macro." Rust's procedural macros
(`#[derive]`) are the closest analog: `#[derive(Clone)]` *emits* a `Clone` impl but cannot make a type
`Clone` that the language forbids (e.g. one containing a non-`Clone` field) — the derive is transparent
to the trait-resolution predicate, exactly as Swift macros are transparent to the copyability predicate
(formal note above). **No surveyed metaprogramming system lets a macro relax the host language's
copyability/cloneability law**; the universal role is synthesis-of-the-permitted, which is precisely
what Finding II.2 achieves and Finding II.3 bounds. ([RES-021] contextualization: the *absence* of a
macro that dissolves the carve-out is not a Swift gap — it is the universal shape of macros as
source-to-source functions.)

---

## Macro-generated-code drawbacks (honest assessment, as mandated)

Even where a macro *can* mechanize a leaf (Finding II.2), the costs are real and argue against using one
for the occupancy leaf specifically:

| Drawback | Severity for an occupancy leaf | Evidence |
|----------|-------------------------------|----------|
| **Debuggability** | Medium-High | The expanded body (storage, `_modify` seam, `deinit`-adjacent teardown) is what the author debugs through "Expand Macro," not their source. For a leaf whose correctness *is* its teardown + seam (the hardest code to get right — cf. the `@_rawLayout` field-ordering LLVM-domination crash, `Memory.Inline.swift:69-74`), the indirection hides exactly the load-bearing lines. A hand-written leaf keeps the teardown in view. |
| **`~Copyable` interaction** | High | The macro must emit the conditional-`Copyable` conformance as a *separate* extension (the `ExtensionMacro` half) — but per [MEM-COPY-004]/[COPY-FIX-004] the conformance must be co-located and the suppression restated, and a macro-emitted extension is harder to audit for the `where Element: ~Copyable` leak ([swift-compiler-bug-catalog §A10], Workaround D). A subtly-wrong macro-emitted extension reintroduces the implicit-`Copyable` leak across every consumer at once. |
| **Build cost** | Medium | A macro plugin pulls `SwiftSyntax` (602) into the build graph; the `swift-dual` build is `47.69s` even cached. A *primitives* leaf cannot pay this: primitives are **Embedded-compatible** ([PRIM-FOUND-002]) and Embedded forbids the macro-plugin/runtime surface. **A macro-synthesized leaf cannot live at L1 at all** — disqualifying for the occupancy leaf, which is an L1 `swift-memory-*`/`swift-store-*` concern. |
| **Genericity ceiling** | Inherent | Per Finding II.3, the macro cannot select representation by element layout (M3), so it would still need the author to pick `@SparseTombstone` vs `@SparseRawLayout` — i.e. it re-exposes the carve-out as a *macro-name* choice, no better than the placement law's leaf choice, with all the above costs added. |

> **Drawback verdict.** The single decisive one is **Embedded-incompatibility** ([PRIM-FOUND-002]): the
> occupancy leaf is an L1 primitive, L1 must be Embedded-deployable, and Embedded forbids macro plugins.
> A `@SparseLeaf` macro is a legitimate *L3/L4 convenience* but is **structurally barred from the leaf
> tier where the occupancy lives** (AX-4). This is independent of — and stronger than — the
> debuggability/`~Copyable`-audit costs.

---

## Outcome

**Status: DECISION.** The Swift 6.3.2 mechanism frontier for the occupancy leaf is mapped exactly, and
the macro question is answered with a working artifact:

1. **The inline corner is over-determined (Finding I.3).** It is move-only for *two* independent reasons
   on 6.3.2 — Wall-1/AX-1 (the `deinit`, S1) *and* `@_rawLayout`-forces-`~Copyable` (N4, no `deinit`
   needed). Collapsing it requires *both* a conditional `deinit` *and* conditional-`@_rawLayout`, **or**
   the `InlineArray` route (which sheds `@_rawLayout`).

2. **`InlineArray` is the conditional-`Copyable` inline leaf (Findings I.4, I.5).** On 6.3.2 it delivers
   (C)+(D)+inline with no user `deinit`, for the *value-semantics* seam — realizing doc #4's cell-10
   ("`InlineArray`+count") and cell-13 (niche tombstone) optima empirically. For sparse liveness it
   delivers (B)+(C)+(D)+inline *simultaneously whenever the element has a niche* (classes, pointers,
   `Bool`, small enums, padded structs); the residual is the *no-niche scalar* sub-case only — the
   mechanism-axis confirmation of doc #4's cell 14.

3. **The `InlineArray` win is reconciled with `storage-small-substrate.md` v1.0.1 (Finding I.6).** It
   serves the *value-semantics* seam, not the *pointer-stable* `Store.`Protocol`` seam (stable element
   pointer via `Offset` arithmetic) the tower currently uses. The residual is therefore a *seam-shape*
   trade as well as a density trade — a fourth facet.

4. **No other non-macro mechanism moves the frontier (Finding I.7).** `discard` (Wall-1 fires first),
   `~Escapable` (orthogonal), `@_specialize` (non-semantic), ownership specifiers (move data, not the
   law), suppressed-protocol generics (necessary substrate) — none collapses cell 14.

5. **Macros mechanize the leaf but cannot dissolve the carve-out (Findings II.2–II.4, formal note).** A
   `@SparseLeaf` member+extension macro *does* synthesize a complete conditionally-`Copyable` tombstone
   sparse leaf from one annotation, built+run on 6.3.2 (`/tmp/occ3-mechanisms/SparseMacro/`). But (a)
   two same-named copyability modes are an `invalid redeclaration` (M0); (b) there is no type-level
   layout predicate for a macro to branch on (M3); (c) a macro is transparent to the copyability
   predicate (formal note) — the expanded source hits AX-1 (S1) and the `@_rawLayout` rule (N4) like any
   source; and (d) the conditional `deinit` is an IRGen-phase per-instantiation decision a
   source-to-source function structurally cannot make (II.4). The most a macro emits is **two
   distinctly-named** types (M2) — re-manufacturing the carve-out, not dissolving it. And the macro is
   **Embedded-barred from the leaf tier** ([PRIM-FOUND-002]) where the occupancy lives — disqualifying
   for L1 regardless of the other limits.

**The most powerful synthesis this note reaches, and its exact residual.** The maximal achievable point
is: **one generic `Buffer<S: Store.`Protocol``>` (E)(A) over a small leaf lattice, where the leaf is
chosen — not macro-synthesized — per (backing × occupancy × seam-shape × element-niche).** For *every*
configuration except {inline × sparse × value-semantics-via-pointer-stable-seam × no-niche scalar}, all
of (A)–(E) hold simultaneously on 6.3.2 — including, newly, the inline conditionally-`Copyable`
value-semantics leaf via `InlineArray` (cells 10/13). **The exact residual** is the *intersection* of
three sub-conditions, each independently forced on 6.3.2: (i) no-niche element (N9 — forces a separate
plane for (B)), (ii) inline backing (N4 — `@_rawLayout` forbids (C); and N1 — no move-only class to host
the `deinit` without a heap box), and (iii) the pointer-stable seam (N14 — `InlineArray`'s
value-semantics seam is the only conditional-`Copyable` inline option and it is *not* pointer-stable).
Drop *any one* of the three and the residual dissolves (niche → tombstone; heap → class; value-semantics
seam → `InlineArray`).

**The precise language feature that lifts the boundary.** Doc #4 proves it is a **conditional `deinit`**
(SE-0427's deliberately-excluded generalization; PITCH-0003, held). This note adds the mechanism-axis
refinement: for the *pointer-stable inline* seam specifically, the conditional `deinit` must be
accompanied by **conditional `@_rawLayout` copyability** (Finding I.3 — N4 is a *second*, independent
obstruction the conditional-`deinit` feature alone does not remove). A single feature suffices only for
the *value-semantics* inline seam (where `InlineArray` already provides conditional copyability and only
the no-niche-density corner remains — and even there `InlineArray` needs no `deinit`, so it is doc #4's
cell 10/13 story, already resolved). **The genuinely irreducible corner — pointer-stable + inline +
sparse + value-semantics + no-niche — needs two coordinated language changes, not one.**

### Relationship to the sibling/parent corpus (this note EXTENDS)

- **`occupancy-encoding-4-placement-proof.md`** (the information/satisfiability proof): this note is its
  *mechanism-axis companion*. Doc #4 proves *which cell* is excluded and *that a conditional `deinit`
  collapses it*; this note proves *why each candidate mechanism (incl. macros) is or is not that
  feature*, adds the second `@_rawLayout` obstruction (Finding I.3, sharpening Thm III.3 for the
  pointer-stable seam), and *empirically realizes* doc #4's cell-10/13 `InlineArray` optima (N7/N8/N13).
  No contradiction; strict extension.
- **`occupancy-lives-in-the-leaf.md`** (AX-4): consumed wholesale. This note confirms that a macro at
  the *leaf* tier would *reintroduce* a two-type carve-out (M2) the law dissolved at the buffer tier —
  reinforcing the law from the macro direction.
- **`conditional-deinit-conditionally-copyable-generics.md`** (Wall-1, S1–S8): consumed as axioms;
  S1/S2/S5/S7 re-reproduced on 6.3.2 as the baseline I extend. The N/M series are entirely additive.
- **`storage-small-substrate.md`** (v1.0.1): **reconciled** (Finding I.6). Its `InlineArray`-route
  withdrawal (pointer-stable seam) and this note's `InlineArray` results (value-semantics seam) are
  complementary, not contradictory.
- **`macro-composition-architecture.md`**: consumed — its "macros are source-to-source, cannot see
  expansions, no macro-applies-macro" constraints are the upstream of this note's formal transparency
  argument (Part II formal note).

### Promotion candidates ([RES-006a]) — proposed, not applied (research only)

- **`[DS-002]`** (ecosystem-data-structures): the `@_rawLayout`-forces-`~Copyable` clause is already
  present ("`@_rawLayout` raw storage also cannot be auto-copied, reinforcing the same outcome") and is
  *confirmed correct and load-bearing* by N4 — it is a *second independent* obstruction, not a
  restatement of the deinit wall. Suggest a one-line cross-reference to this note's Finding I.3 so the
  two-obstruction structure is explicit.
- **`[MEM-COPY-016]`**: add a cross-reference noting that (1) `InlineArray` is the conditional-`Copyable`
  inline leaf for the *value-semantics* seam (the `@_rawLayout` leaf is move-only for *two* reasons), and
  (2) a synthesizing macro cannot dissolve the carve-out (transparent to the copyability predicate;
  Embedded-barred from L1). No rule-text change required; the triangle and one-truth-holder invariant are
  unchanged.
- No new disposition for the tower; this note supplies the *mechanism map* backing the existing
  placement law and doc #4's satisfiability proof.

---

## References

### Internal ([RES-019] — grepped `swift-institute/Research/` for occupancy/conditional-copyable/deinit/rawLayout/macro/InlineArray before drafting; the occupancy-encoding-{2,4,5} siblings + the four parents below were read in full)
- `occupancy-lives-in-the-leaf.md` (DECISION, tier-3, 2026-06-07) — the placement law (AX-4); parent.
- `occupancy-encoding-4-placement-proof.md` (DECISION, tier-3, 2026-06-08) — information floor + satisfiability matrix (cell 14); this note's information-axis companion.
- `occupancy-encoding-2-category-theory-composition.md` (RECOMMENDATION, tier-3, 2026-06-08) — sibling (category-theory angle).
- `occupancy-encoding-5-prior-art-and-vacuity.md` (DECISION, tier-3, 2026-06-08) — sibling (prior-art + vacuity census).
- `conditional-deinit-conditionally-copyable-generics.md` (tier-3, 2026-06-06) — Wall-1 proof + S1–S8 matrix + SE-0427 formal model (AX-1/AX-3); the conditional-`deinit` collapsing feature.
- `storage-small-substrate.md` (DECISION, tier-3, 2026-06-05, v1.0.1) — the `Storage.Small` enum-arm pointer-stable seam; the `InlineArray`-route withdrawal reconciled here (Finding I.6).
- `macro-composition-architecture.md` (RECOMMENDATION, tier-2, 2026-03-16) — "macros cannot see expansions / no macro-applies-macro" (Part II formal note).
- `buffer-arena-conditional-copyable.md` (IMPLEMENTED, tier-2) — shipped heap sparse class-leaf (N2 / AX-2 / cell 6).
- `swift-compiler-bug-catalog.md` §A10 (constrained-extension `~Copyable` leak, Workaround D), §A14 (`swift#86652` cross-package `@_rawLayout` deinit-skip, Wall-2 — orthogonal, [MEM-SAFE-027]).

### Primary — source (read directly, file:line cited) [Verified: 2026-06-08]
- `swift-store-primitives/Sources/Store Protocol Primitives/Store.Protocol.swift:20-69` — the 4-op neutral seam (AX-5); the documented cross-module `_read`/`_modify` specialization.
- `swift-memory-inline-primitives/Sources/Memory Inline Primitives/Memory.Inline.swift:41-114` — dense inline `@_rawLayout` leaf; `_deinitWorkaround` (Wall-2); the field-ordering LLVM-domination note (`:69-74`).
- `swift-storage-arena-primitives/Sources/Storage Arena Primitives/Storage.Arena.swift:75-278` — heap sparse class-leaf; `Backing.deinit`; `extension Storage.Arena: Copyable where Element: Copyable` (AX-2).
- `swift-storage-primitives/Sources/Storage Contiguous Primitives/Storage.Contiguous.swift:46-71` — `Contiguous<Substrate: Store.Protocol & ~Copyable>`; `: Copyable where Substrate: Copyable`; "No `deinit` anywhere" (AX-4, S5 shape).
- `swift-foundations/swift-dual/Package.swift:45-51` — the `.macro` plugin template (SwiftSyntax 602) that builds on 6.3.2.

### Primary — Swift Evolution / compiler (consumed from the companion note, AX-1/AX-2)
- SE-0427 Noncopyable Generics, § "Conformance to `Copyable`" — the controlling prohibition (AX-1).
- SE-0390 Noncopyable Structs and Enums — `deinit ⟹ ~Copyable`.
- SE-0453 `InlineArray` — the compiler-managed inline buffer (conditional-`Copyable`; N5/N7/N13).
- SE-0429 Partial Consumption / `discard` — N10.
- `DiagnosticsSema.def:8390` (`copyable_illegal_deinit`); `TypeCheckInvertible.cpp:221-233` (emission + class exemption AX-2).

### Prior art ([RES-021] — macro contextualization)
- Rust procedural/`#[derive]` macros — transparent to trait resolution (`#[derive(Clone)]` cannot make a non-`Clone`-fielded type `Clone`); the cross-language confirmation that macros synthesize-the-permitted, never relax the host law.
- `macro-composition-architecture.md`'s PointFree survey (`@CasePathable`, `@DependencyClient`) — "accepted the duplication; no macro composition."

### Empirical artifacts ([RES-023] — every load-bearing compile/diagnostic claim produced on Swift 6.3.2, `swift-6.3.2-RELEASE`, `TOOLCHAINS=org.swift.632202605101a`, `arm64-apple-macosx26.0`, 2026-06-08)
- `/tmp/cdspikes/` — S1–S8 baseline (companion note's), re-verified 2026-06-08 (S1/S3/S4/S6/S8 fail as documented; S2/S5/S7 compile; S7 runs).
- `/tmp/occ3-mechanisms/n1_moveonly_class.swift` — `error: classes cannot be '~Copyable'`.
- `/tmp/occ3-mechanisms/n2_conditional_class_field.swift` — Box-relocation compiles (AX-2).
- `/tmp/occ3-mechanisms/n3_…`, `n4_rawlayout_copyable_inner.swift` — `error: type with '@_rawLayout' cannot be copied and must be declared ~Copyable` (Finding I.3).
- `/tmp/occ3-mechanisms/n5_…`, `n7_…`, `n7b_…`, `n13_…` — `InlineArray` conditional `Copyable` + `~Copyable`-element `_read`/`_modify` seam; runtime: conditional auto-teardown fires, copies succeed (Findings I.4).
- `/tmp/occ3-mechanisms/n6b_…`, `n8_tombstone_sparse_run.swift`, `n9_sparebit_density.swift` — tombstone sparse leaf (run) + spare-bit density survey (Findings I.5).
- `/tmp/occ3-mechanisms/n10_discard.swift`, `n11_…`, `n12_specialize.swift` — `discard`/`~Escapable`/`@_specialize` all fail to move the frontier (Finding I.7).
- `/tmp/occ3-mechanisms/n14c_enum_inplace.swift` — enum-held `InlineArray` value-semantics mutation (run: `slot2=7`); the `storage-small-substrate.md` v1.0.1 reconciliation (Finding I.6).
- `/tmp/occ3-mechanisms/m0_two_specializations_one_name.swift` — `error: invalid redeclaration of 'Foo'` (M0).
- `/tmp/occ3-mechanisms/m2_macro_would_emit_two_named.swift` — two distinctly-named types compile (the macro's legal limit; M2).
- `/tmp/occ3-mechanisms/m3_no_typelevel_layout_branch.swift` — `error: expected ',' separator` (no type-level layout predicate; M3).
- `/tmp/occ3-mechanisms/SparseMacro/` — the **working** `@SparseLeaf` member+extension macro; `swift run SparseClient` on 6.3.2 (platform `.macOS("26.0")`) prints the conditional-teardown + conditional-copy output (Finding II.2). The `macOS 26.0` `InlineArray`-setter availability caveat surfaced here (§II.1).
