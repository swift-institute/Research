# Hashed-Container Substrate Archaeology (stdlib · swift-collections · the sparse hashed leaf)

<!--
---
version: 1.0.0
last_updated: 2026-06-10
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

R1 of the post-archaeology research arc (sequel to `stdlib-array-family-source-archaeology.md`, 17d8cad).
The ADT-families executor is dispatched per `.handoffs/GOAL-tower-adt-families.md` and must HALT for seat
ratification on exactly this design question (GOAL:50–51):

> **set/dictionary**: the hashing column discipline (which storage composes the buckets; where the hash
> policy lives). This is new design territory — surface the shape first.

This note is the source-grounded input to that ratification: how stdlib `Dictionary`/`Set` storage
actually works (pinned refs 632 = `swift-6.3.2-RELEASE` @ `cd8d8ad0019`, 64x =
`swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-06-07-a` @ `0b7717dc5b6`, main @ `6f5d855aedf`), what the only
move-only hashed precedent (swift-collections `BasicContainers`) does, and how both land on the tower's
ratified laws — `occupancy-lives-in-the-leaf.md` (Tier 3 DECISION), the W3b Slots **untracked-elements
ledger rule**, R-5/[MEM-SAFE-028] (drain-box), and the W4 Array playbook (gate + seam, S5 copyability,
`prepareForMutation()`).

Verification: all load-bearing claims below were re-derived by an independent [RES-020] verifier on
2026-06-10 (17/17 confirmed; two precision notes incorporated). Internal prior art per [RES-019]: the
hash/set/dictionary Research corpora were distilled and are cited as leads ([RES-013a] carried-forward
markers where not re-verified).

## Question

1. What is stdlib's hashed-storage shape — allocation, occupancy ledger, teardown, CoW, deletion, growth,
   seeding?
2. What does the move-only hashed precedent (swift-collections previews) do differently?
3. Where does that leave the tower: which storage composes the buckets, where does the hash policy live,
   and what answers the **non-prefix-ledger question** (scattered occupancy vs the seam's linear-prefix
   ledger)?
4. Does swiss-table-style control-byte probing have any Swift precedent, and does `Store.Split` fit?

## Headline answer (for the executor's halt)

**Two hashed families, two lawful compositions:**

**(A) Ordered family (existing `Set.Ordered`/`Dictionary.Ordered` shape) — dense elements + a POD
position index.** Elements live densely in a `Buffer.Linear` column; the hash side is a *position-index
engine* (`Hash.Table`) whose planes are plain `Int`s (hashes + positions). This is exactly
OrderedCollections' architecture (compressed bucket table storing offsets into a separate dense array
[Verified: 2026-06-10]). Because the index planes are POD and fully-initialized-for-life, the W3b Slots
untracked-elements rule is harmless here — there is nothing to tear down in the table. The W5 re-spell of
`Hash.Table` onto the new tower (`Buffer<Store.Split<…Contiguous<Int>, …Contiguous<Int>>>.Slots`) is a
namespace migration, not a redesign.

**(B) Unordered move-only-capable family (the new territory) — a SPARSE HASHED LEAF.** When the bucket
array IS the element storage (elements at scattered bucket offsets), the occupancy ledger and the
teardown must live in a **single-allocation sparse leaf** — per the ratified law, and now confirmed as
exactly what stdlib ships: `_DictionaryStorage` is one `Builtin.allocWithTailElems_3` allocation
`[bitmap words | keys | values]` whose **class deinit walks only the occupied bits**
[Verified: 2026-06-10]. The tower's leaf is the move-only struct analogue (the `Storage.Arena`
`[Meta | elements]` SoA precedent): one allocation, bitmap words + element slots (+ value slots for
Dictionary), occupancy as **concrete leaf state** (no occupancy protocol — the ratified
`Buffer.Arena` pattern), conforming `Store.Protocol`, with the leaf's own `deinit` draining via the
bitmap.

**Where the hash policy lives: above the leaf, never in it.** Both upstreams separate the table *math*
(probing, load factor, seeding) from the *storage*: stdlib's `_HashTable` is a thin struct over the
bitmap words with the storage class holding regions (`HashTable.swift:19–30`); swift-collections'
`_HTable` is the same split (`_HTable.swift:21–38`). Tower mapping: the leaf stores and tears down; the
probing/hashing/growth discipline is the table engine in the family's column module, pinning the concrete
leaf (`where S == <hashed leaf>`) exactly as `Buffer.Arena` pins `Storage.Arena` (the law's
"no occupancy protocol" composition, 53 shipping pinned call-sites).

**The non-prefix-ledger question, answered:** scattered occupancy must NOT be routed through the seam's
linear-prefix ledger — the W3b ring rule already established the seam ledger is prefix-shaped, and the
Slots rule shows what happens when a plane's occupancy is consumer-defined: the plane's oracle must be
held inert and "consumer must deinitialize before drop" — a contract an S5 conditionally-Copyable ADT
**cannot honor with a deinit (Wall 1)**. Composing `Buffer.Slots` over `Store.Split` for *owned* elements
is therefore leak-by-construction for the direct move-only column; the sparse hashed leaf — which owns a
bitmap ledger and its own deinit — is forced. That is the composition check: existing pieces cannot cover
the unordered case; the law already mandates the leaf.

**Per-column teardown (the Array template carries over):** direct move-only column → the leaf's struct
`deinit` (bitmap walk; stdlib's `!_isPOD` skip is a free optimization to copy); `Shared` column → the Box
drain through public `removeAll` (R-5/[MEM-SAFE-028]) with the leaf oracle count-driven-inert behind it;
`ensureUnique()` before any mutable vend; CoW `copy()` preserves seed+scale (no rehash), `resize()`
re-seeds and rehashes (stdlib's quadratic-copy defense [Verified: 2026-06-10]).

## Q1 — Stdlib hashed storage, verified

All on main; **byte-identical on 632** (whole-file `diff -q` silent for DictionaryStorage.swift and
SetStorage.swift; only typed-throws API commits touched NativeDictionary across 632→main).
[Verified: 2026-06-10]

**Single allocation, three tail regions** (`DictionaryStorage.swift:475–479`):

```swift
let storage = unsafe Builtin.allocWithTailElems_3(
  _DictionaryStorage<Key, Value>.self,
  wordCount._builtinWordValue, _HashTable.Word.self,
  bucketCount._builtinWordValue, Key.self,
  bucketCount._builtinWordValue, Value.self)
```

with region projection via `projectTailElems` + `getTailAddr_Word` chains (:481–487) and cached region
pointers in the header (`_rawKeys`/`_rawValues`, alongside `_count`, `_capacity`, `_scale`,
`_reservedScale`, `_age`, `_seed` — `DictionaryStorage.swift:22–111`). `Set` is the arity-2 twin
(`SetStorage.swift:367–370`: bitmap words + elements).

**Occupancy = an out-of-band bitmap in-band with the allocation** — one bit per bucket, stored as the
first tail region; `_HashTable` is a thin view (`words: UnsafeMutablePointer<Word>` + `bucketMask: Int`,
`HashTable.swift:19–30`) that conforms `Sequence` by walking set bits.

**Probing = linear, first-come-first-served** (`HashTable.swift:353–364`): `idealBucket =
hashValue & bucketMask`; `wrappedAfter = (offset &+ 1) & bucketMask`. The header comment at
`Dictionary.swift:130–134` explicitly flags Robin Hood as "the most obvious alternative" (citing Rust's
implementation) — i.e. upstream's own contemplated upgrade is Robin Hood, not swiss-table.

**Deletion = backward-shift chain repair, NO tombstones** (`HashTable.swift:467–508`): "If we've put a
hole in a chain of contiguous elements, some element after the hole may belong where the new hole is" —
the walk relocates out-of-place entries into the hole via the `_HashTableDelegate`
(`moveEntry(from:to:)` = paired `moveInitialize` of key+value, `NativeDictionary.swift`), then clears the
final hole's bit. No sentinel values exist anywhere in the scheme.

**Teardown = the sparse drain, on the storage class** (`DictionaryStorage.swift:268–284`):

```swift
deinit {
  guard unsafe _count > 0 else { return }
  if !_isPOD(Key.self) {
    let keys = unsafe self._keys
    for unsafe bucket in unsafe _hashTable {
      unsafe (keys + bucket.offset).deinitialize(count: 1)
    }
  }
  if !_isPOD(Value.self) { /* same walk over values */ }
  unsafe _count = 0
  unsafe _fixLifetime(self)
}
```

Only occupied buckets are touched; POD planes are skipped wholesale; the drain closes with
`_fixLifetime(self)` — the same idiom the Array archaeology found on `_ContiguousArrayStorage` and that
[MEM-SAFE-028] now mandates on the tower's Box drain. `Set`'s deinit is the single-plane twin
(`SetStorage.swift:219–228`). **This is `occupancy-lives-in-the-leaf` shipped at industrial scale: one
allocation, SoA occupancy + payload, teardown driven by the leaf's own ledger, on the refcounted leaf.**

**CoW** (`NativeDictionary.swift:263–277`): `ensureUnique(isUnique:capacity:)` — fast path
(fits ∧ unique) / `resize` (unique, grow in place by rehash-move) / `copy()` (shared, fits — bulk
bitmap copy + per-bucket reinit, **seed and scale preserved, no rehash**) / `copyAndResize`. The
uniqueness bit is `isUniquelyReferencedUnflaggedNative()` → `Builtin.isUnique_native`
(`DictionaryVariant.swift:78–80` → `BridgeStorage.swift:137–139`) — the same primitive family as the
tower's gate.

**Growth**: `maxLoadFactor = 3/4`, power-of-two bucket counts, "`capacity + 1` … ensures that we always
leave at least one hole" (`HashTable.swift:73–100`). **Seeding**: per-instance seed = the storage
object's address (deterministic mode: the scale), **regenerated on every allocation and resize** — "so
that we avoid certain copy operations becoming quadratic" (`HashTable.swift:108–132`) — over the
process-wide 128-bit SipHash execution seed.

**Annotations**: `@unsafe` on `_HashTable` + storage classes, `@safe` on `_NativeDictionary`;
`@_semantics("optimize.sil.specialize.generic.size.never")` on `copy`/`ensureUnique`/`_delete`;
`@frozen @_eagerMove` on public `Dictionary`/`Set`. No `array.*`-style COW semantics machinery exists for
dictionaries — the hashed CoW path is ordinary inlinable Swift, which means **the tower can replicate this
factoring fully** (unlike Array's COWArrayOpt machinery).

## Q2 — The move-only precedent: swift-collections `BasicContainers` previews

Pinned @ `af174fe4476842b2558069e64feae8ddc2e665ff` (main HEAD 2026-06-09). The four types behind the
`UnstableHashedContainers` trait (NOT in default traits) are the **only move-only hashed containers in the
ecosystem** [Verified: 2026-06-10]:

```swift
public struct RigidSet<Element: Hashable & ~Copyable>: ~Copyable {       // RigidSet.swift:34
  package var _members: UnsafeMutablePointer<Element>?
  package var _table: _HTable
}
public struct RigidDictionary<Key: Hashable & ~Copyable, Value: ~Copyable>: ~Copyable { // :35–46
  package var _keys: RigidSet<Key>
  package var _values: UnsafeMutablePointer<Value>?                      // separate parallel allocation
}
// UniqueSet/UniqueDictionary wrap the Rigid twin and add the growth policy; no own deinit.
```

- **Table core**: `package struct _HTable: ~Copyable` — `_bitmap: UnsafeMutablePointer<Word>?`,
  `_maxProbeLength`, `scale: UInt8` (`_HTable.swift:21–38`); its own deinit frees the bitmap. So Rigid =
  **multi-allocation parallel arrays** (bitmap + members [+ values]) with **struct** deinits, vs stdlib's
  one tail-allocated class.
- **Probing**: linear + **Robin Hood displacement ON by default** (`#if COLLECTIONS_NO_ROBIN_HOOD_HASHING`
  selects the naive path; displacement core `if probeLength > oldProbeLength { swapper(b) }`,
  `_HTable+Insert.swift:41–84`), lookups bounded by `_maxProbeLength`.
- **No tombstones** — `_HTable+Removal.swift:44–50`: "Our hash table does not have tombstones … the holes
  … need to be immediately filled by the next item in the same chain … This is only possible because
  we're using linear probing."
- **Teardown**: `RigidSet.deinit` walks occupied **regions** (`makeBucketIterator()` /
  `nextOccupiedRegion()` → bulk `deinitialize()`, `RigidSet.swift:58–73`) — a bulk-range refinement of
  stdlib's per-bucket walk. `RigidDictionary.deinit` carries a live FIXME ("iterates over the bitmap
  twice … `self` not being mutable really hurts us") — evidence the parallel-allocation shape pays a
  structural tax the single-allocation shape doesn't.
- **Key bound**: plain `Hashable & ~Copyable`, riding SE-0499; hashing via the seeded entry point
  `item._rawHashValue(seed: _seed)`, seed = members-pointer address (deterministic under a flag) —
  per-instance, same posture as stdlib.
- **Maturity**: the trait description says the required generalized `Equatable`/`Hashable` "has not
  shipped in a stable compiler version yet"; release 1.5.0: the four types "remain source-unstable for
  now"; every file carries a `#if compiler(<6.4)` unavailable-stub. **SE-0527's Future directions names
  `RigidSet`/`UniqueSet`/`RigidDictionary`/`UniqueDictionary` (and the Deques) as "potential future
  additions to the Swift Standard Library"** — this design is the upstream trajectory.

OrderedCollections' `_HashTable` (the copyable ordered design): scale-bit compressed buckets storing
*offsets into a separate dense `ContiguousArray`*, in-band zero = empty (no bitmap, no tombstones,
backward-shift, bias word for O(1) front insertion, brute-force linear search under 16 elements) — the
structural twin of the institute's ordered family. HashTreeCollections (CHAMP) is a persistent-sharing
family, orthogonal to this question.

## Q3 — The key bound on Swift 6.3.2 (load-bearing gate fact)

SE-0499 ("Support ~Copyable, ~Escapable in simple standard library protocols") generalizes `Equatable`,
`Comparable`, **`Hashable`** (+ the string-convertible/TextOutputStream protocols) to
`~Copyable & ~Escapable` — **status: Implemented (Swift 6.4)** [Verified: 2026-06-10]. On the institute's
6.3.2 build gate, stdlib `Hashable` therefore **cannot** bound a `~Copyable` key — which is precisely why
swift-collections stubs its previews out below 6.4. Consequence for the tower:

- Until the gate bump: the institute's own borrowing `Hash.Protocol` (per `swift-set-primitives`
  `Noncopyable Hashable Architecture.md`, carried forward) remains the move-only key bound.
- At the gate bump (a gate-bump-dossier item, R-arc rider): plan the convergence — `Hashable & ~Copyable`
  becomes expressible; decide alias/bridge vs migration then. New family surfaces should keep the key
  bound in ONE place so the swap is mechanical.

## Q4 — `Store.Split`/Slots fit, and swiss-table

**`Store.Split` is the right tool for the ordered family's index engine and the wrong tool for the
unordered family's element storage.** Split composes two *pre-built* stores and allocates nothing (W2d
STATUS, a7c536d plane windows); Slots' occupancy is consumer-defined with the elements-plane ledger held
inert and a consumer-must-deinitialize-before-drop contract (W3b 1b34d72). For POD `Int` planes
(hashes/positions) that contract is trivially satisfied — nothing to destroy. For *owned scattered
elements* it is unsatisfiable by an S5 ADT (no deinit — Wall 1), so the element plane of the unordered
family must be inside the sparse leaf that owns the bitmap and the drain. (Whether the leaf internally
uses a Split-like SoA view over its one allocation is an implementation detail of the leaf — the
`Storage.Arena` `[Meta | elements]` precedent — not a composition of two heap stores.)

**Swiss-table: zero Swift precedent.** `git grep -niE 'swiss'` over `stdlib/public/core` on all three
refs → empty; zero hits in swift-collections and swift-evolution; no forums thread proposes it; the only
Swift implementations are two small third-party projects (one x86-AVX2-only, dormant since 2023; one
app-internal ID-map) [Verified: 2026-06-10]. Both upstream lineages chose **bitmap + linear probing**
(stdlib FCFS; s-c + Robin Hood). Architecture note: control bytes would *replace* the bit-plane with a
byte-plane inside the same sparse-leaf shape (empty/deleted/full+H2 fragments enabling SIMD group
probes), so adopting swiss later is a leaf-internal change, not an architectural one. Recommendation: do
not pioneer it now — no precedent, portability cost (SIMD width dispatch), and the Robin-Hood-on-linear
upgrade path is the one both upstreams actually point at.

**Tombstone divergence (flag for W5):** the institute's current `Hash.Table` uses sentinel tombstones —
`empty = 0`, `deleted = Int.min`, `self[hash: index] = Self.deleted` on removal, with `rehash()`
compaction ("Call this after many deletions to reclaim tombstone slots") — `Hash.Table.swift:69–90`,
`Hash.Table+Removal.swift:41,109–111` [Verified: 2026-06-10]. Both upstreams reject tombstones in favor
of backward-shift chain repair. Not a blocker (the ordered engine's positions complicate shifting, and
`rehash()` is a workable half-measure), but the W5 re-spell should evaluate backward-shift against the
upstream consensus rather than carry the sentinels forward silently.

## Trajectory note

The stdlib hashed mechanism is **stable across 632 → 64x → main** (storage files byte-identical; only
typed-throws API adoption on NativeDictionary). The moving front is entirely in swift-collections'
preview family plus SE-0499 landing at 6.4 — i.e. the move-only hashed story arrives ecosystem-wide
exactly when the institute's gate bump makes stdlib `Hashable & ~Copyable` available.

## Tower impact

| # | Finding | Tower element | Verdict |
|---|---|---|---|
| 1 | Stdlib hashed storage = single-allocation SoA leaf (bitmap+planes) with ledger-driven class-deinit drain | `occupancy-lives-in-the-leaf` (Tier 3) | **CONFIRMED at industrial scale** — the law's sparse-leaf prescription is stdlib's shipped shape |
| 2 | Dictionary/Set deinit walks only occupied bits, POD-skips planes, closes with `_fixLifetime(self)` | R-5 / [MEM-SAFE-028] drain | CONFIRMED for the hashed substrate; adopt the `!_isPOD` skip in the leaf drain |
| 3 | s-c move-only family = struct-deinit parallel arrays; RigidDictionary's two-pass-bitmap FIXME | The new sparse hashed leaf | Prefer the **single-allocation** stdlib shape over s-c's parallel allocations (the FIXME is the cost of splitting) |
| 4 | Slots untracked-elements contract is unsatisfiable by S5 ADTs for owned elements | Unordered family composition | **Sparse hashed leaf is forced** for unordered; Slots/Split stay correct for the POD index engine |
| 5 | Hash policy lives above storage in both upstreams | "Where does the hash policy live" (executor halt) | In the family's table engine, pinning the concrete leaf (`Buffer.Arena` pattern); never in the leaf, never in the seam |
| 6 | No tombstones upstream (both lineages); Robin Hood = the named upgrade path; swiss-table = no precedent | Current `Hash.Table` sentinels; probing choice | Linear+bitmap now; evaluate backward-shift at the W5 re-spell; Robin Hood optional later; no swiss |
| 7 | SE-0499 (Hashable & ~Copyable) is 6.4-only | 6.3.2 key bound | `Hash.Protocol` remains the bound; single-point key-bound for a mechanical gate-bump swap |
| 8 | Per-instance address seed, re-seed on resize, copy() preserves seed+scale | CoW ops on the Shared hashed column | Adopt all three (the no-rehash `copy()` and the quadratic-copy defense are easy to miss) |

## Outcome

**Status: RECOMMENDATION** (research only; no package edited). For the executor's halt:

1. **Ordered family**: keep the dense-elements + POD-position-index composition; `Hash.Table` re-spells
   onto `Buffer<Store.Split<…>>.Slots` at W5 (namespace migration); evaluate backward-shift vs sentinels
   there.
2. **Unordered family**: build the **sparse hashed leaf** — one allocation, `[bitmap words | element
   slots]` (+ `[value slots]` interleaved for Dictionary, stdlib-shape), occupancy as concrete leaf
   state, `Store.Protocol` conformance, leaf-owned `deinit` drain (bitmap walk, POD-skip), move-only
   struct per the leaf law. Hash policy (linear probing, 3/4-or-7/8 load factor, per-instance
   address-derived seed + deterministic flag, re-seed on resize) lives in the family's table engine with
   concrete-leaf pins. Shared column wraps it for CoW with the Box drain (R-5), `ensureUnique()` before
   any mutable vend, `copy()` seed/scale-preserving.
3. **Key bound**: `Hash.Protocol` on 6.3.2; isolate it for the SE-0499 swap at the gate bump.
4. **Do not** pursue swiss-table control bytes now; note Robin Hood as the sanctioned later upgrade
   (flag-gated, per the s-c precedent).

## Residual (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| The sparse hashed leaf compiles + tears down cross-module on 6.3.2 in the tower's composed shape (incl. [MEM-SAFE-027]/#86652 exposure for any inline variant) | **premise** for the executor's build | The executor's own gated build IS the verification (HALT-on-wall with repro per its GOAL); the heap-leaf shape additionally has the shipping `Storage.Arena` existence proof and `/tmp/tower-cow-spike`→`Experiments` lineage. No design reliance precedes that build. |
| Backward-shift vs sentinels for the position-index engine (positions must be updated when buckets move) | direction | Evaluate at the W5 `Hash.Table` re-spell; `rehash()` compaction is the extant fallback |
| Robin Hood displacement for the new leaf's engine | direction | Optional later; flag-gated precedent in s-c |
| Seed plumbing through the institute `Hash.Protocol` (seeded `_rawHashValue` analogue) | direction | Surface when the executor builds the engine; both upstreams are seed-parametric |

## References

- **stdlib (pinned 632 `cd8d8ad0019` · 64x `0b7717dc5b6` · main `6f5d855aedf`)**:
  `stdlib/public/core/DictionaryStorage.swift` :22–111 (header), :268–284 (deinit), :464–510 (allocate,
  `allocWithTailElems_3` :475–479); `SetStorage.swift` :219–228, :367–370; `HashTable.swift` :19–30,
  :73–100, :108–132, :353–364, :467–508; `NativeDictionary.swift` :263–277; `DictionaryVariant.swift`
  :78–80, :124; `BridgeStorage.swift` :137–139; `Dictionary.swift` :130–134 (Robin Hood FIXME).
- **swift-collections @ `af174fe4476842b2558069e64feae8ddc2e665ff`**:
  `Sources/BasicContainers/RigidSet/RigidSet.swift` :34, :58–73; `RigidDictionary/RigidDictionary.swift`
  :32–46, :54, :67; `HashTable/_HTable.swift` :21–38, `+Removal.swift` :44–50, :70–76, `+Insert.swift`
  :41–84; `Package.swift` :18–23, :40–47 (trait); OrderedCollections `_HashTable.swift` :14–35 +
  `+UnsafeHandle.swift` (compressed design); releases 1.3.0/1.4.0/1.5.0/1.6.0.
- **Swift Evolution**: SE-0499 (Implemented, Swift 6.4 — the protocol list); SE-0527 Future directions
  (the Rigid/Unique hashed-family sentence).
- **Internal ([RES-019])**: `occupancy-lives-in-the-leaf.md` (the law; sparse-leaf prescription);
  `.handoffs/HANDOFF-tower-flag-day-migration.md` STATUS (W3b ring ledger rule 6bb2685; Slots
  untracked-elements rule 1b34d72; W4 gate/seam playbook 98ed3fb/60361b0); `GOAL-tower-adt-families.md`
  :50–51 (the halt this answers); `swift-hash-table-primitives` `Hash.Table.swift` :69–90 +
  `+Removal.swift` :41,:109–111 (current sentinels); prior-art distill ledger over
  `data-structures-associative-hashing-assessment.md`, `value-storage-buffer-layering.md`,
  `dictionary-removal-strategies.md`, `hash-table-storage-buffer-layering.md` (v3.0.0 — Buffer.Slots
  migration), `Noncopyable Hashable Architecture.md` (Hash.Protocol), `inline-hash-table.md`,
  `api-surface-catalog.md` (all carried forward per [RES-013a] except where re-verified above);
  `stdlib-array-family-source-archaeology.md` (the parent doc; `_fixLifetime` idiom, gate parity).

### Verification

[RES-020] parallel verification 2026-06-10: 17 load-bearing claims re-derived against the pinned
worktrees, swift-collections raw files at the pinned commit, swift-evolution raw files, and the local
hash-table-primitives source — 17/17 CONFIRMED (two precision notes folded in: the deinit also zeroes
`_count` before `_fixLifetime`; Robin Hood is the `#else` of the disable-flag, i.e. default-on).
