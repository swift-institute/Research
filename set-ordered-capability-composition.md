# Set.Ordered Capability Composition — the ×16 Fan-Out Template

<!--
---
version: 1.1.0
last_updated: 2026-05-31
status: RECOMMENDATION
tier: 2
scope: swift-set-ordered-primitives (exemplar); generalizes to the ×16 buffer-backed ADT fan-out
type: execution-record / template
toolchain: Apple Swift 6.3.2, arm64-apple-macosx26.0
---
-->

> **RECOMMENDATION (Tier 2).** The realized inherits-vs-writes shape of the `Set.Ordered` ×4 exemplar after
> the 2026-05-31 capability-composition cleanup — the **pristine template** the gated ×16 fan-out replicates.
> Records what each variant *writes* vs *inherits*, the `with*`-elimination principle, the explicitly
> **deferred** axes, and the design-doc reconciliations the cleanup surfaced. All work landed LOCAL/unpushed.

## 1. Inherits-vs-writes inventory (Set.Ordered ×4)

A set variant **writes** only its irreducible surface and **inherits** everything a `where Self: Core`
default (or an orthogonal-concern bridge) can provide.

### Writes (irreducible / concrete)

| Surface | Rung | Why concrete |
|---|---|---|
| `count` | `Set.Protocol` core requirement | hot O(1), 1-line (`buffer.count`) |
| `contains` | `Set.Protocol` core requirement | hot O(1) membership; body delegates over `Hash.Table.Protocol.contains` terminal |
| `index(_:)` | (delegates `Hash.Table.Protocol.position`) | hot; the index-returning sibling of `contains` |
| `insert` / `remove` / `clear` / `drain` | concrete-Base hot mutating | specialization boundary — protocol-Base `Property.Inout` doesn't specialize; **②** dedup blocked on a missing buffer-mutable protocol |
| `var span` | `Memory.Contiguous.Protocol` witness (the one requirement) | `@_lifetime(borrow self) borrowing get { buffer.span }` |
| `var mutableSpan` | direct mutable accessor | `@_lifetime(&self) mutating get` (base/Fixed CoW, Small direct; Static read-only) |
| `Sequenceable.makeIterator()` | concrete scalar (`Buffer.Linear.Scalar`) | the demangle-safe choice; generic `Memory.Cursor` crashes the inline family |
| conformance decls (`: Set.Protocol`, `: Memory.Contiguous.Protocol`, `: Iterable`, `: Sequenceable`, `: Hash.Protocol`) | per-variant | each variant declares its own |

### Inherits (free)

| Surface | Provider (edge) |
|---|---|
| `isEmpty` | `Set.Protocol` (D) — `count == .zero` |
| **`forEach`** + the borrowing terminal suite | **`Iterable` floor (C)** — span-loop over `span`; **NEW this cleanup** (see §2) |
| `Iterable.makeIterator()` | memory→Iterable bridge over `span` (C) — no hand-written iterator |
| `==` / `hash` | `Span: Equation.Protocol` / `Span: Hash.Protocol` (SLI) |
| union / intersection / subtracting / symmetricDifference / isSubset / isSuperset / isDisjoint / isStrict* / isEqual | `set-algebra` `where Self: Set.Protocol & Buildable & Iterable` (C) |
| `init(@Set.Builder)` DSL | `Buildable` non-throwing default |
| `consume(_:)` consuming drain | `Sequenceable.consume(_:)` |

**The forEach headline.** The SE-0516 cascade had to retain base `Set.Ordered`'s per-type `forEach` as the
Iterable-vs-Sequenceable disambiguator. Landing `@_disfavoredOverload` on the non-bridge `Sequenceable.forEach`
surfaces (sequence-primitives `dcd748a`) makes the `Iterable.forEach` span-loop floor win for every
Iterable+Sequenceable dual-conformer, so the last per-type `forEach` dies. Spike-validated debug+release,
cross-module `-O` **0 `witness_method`**; the `@inline(always)` `Swift.Sequence` crash-dodge bridge stays
favored. **Fan-out:** every dual-conformer (Array×4, Buffer.Linear×4, future ADTs) inherits the floor.

## 2. The `with*`-elimination principle (NEW — 2026-05-31, principal-articulated)

> **Container-level `with*`-closure accessors are FORBIDDEN where direct `~Escapable`/`~Copyable` member
> access exists.** They are a legacy pattern from before `~Escapable` borrowing properties worked. With
> `var span: Span { borrowing get }` and `var mutableSpan: MutableSpan { mutating get }`, a closure
> `withSpan { body($0) }` adds nothing over `let s = set.span`.

Realized on the exemplar:
- **Read** = `var span` (the Memory.Contiguous witness). **Mutable** = `var mutableSpan { mutating get }`.
- Raw C-interop = on the span/mutableSpan itself (`span.withUnsafeBufferPointer { … }`), **never** the
  container.
- **`Memory.Contiguous.Protocol` reduced to require only `span`** (memory-primitives `11e1611`); the
  container-level `withUnsafeBufferPointer` *requirement* is dropped (grep-verified zero generic callers;
  conformers' witnesses become ordinary, deletable methods). Verified across all 10 L1 conformers + foundations.
- All four container-level `with*` groups (`withSpan`, `withUnsafeBufferPointer`, `withMutableSpan`,
  `withUnsafeMutableBufferPointer`) deleted from Set.Ordered ×4 — all grep-verified dead.

**Fan-out:** apply the same to every buffer-backed ADT; drop their container-level `with*`; the
`Memory.Contiguous.Protocol` simplification is already ecosystem-wide.

## 3. Deferred axes (the template is HONEST about what it does NOT do)

| Axis | Status | Blocked on / reason |
|---|---|---|
| **Swift.Sequence interop (§2.8)** | **DEFERRED** | The migrated span-primitive exemplar has no Copyable iterator (deleted in the SE-0516 migration); re-adding bakes a per-type Copyable-iterator wart. array-primitives has **no** Swift.Sequence conformance (grep-verified — the prior "array keeps it" claim was stale). Eventual shape = one generic `Swift.Sequence` bridge `where Element: Copyable` (vended once, inherited), settled ecosystem-wide at/before the ×16 fan-out. |
| **`Indexed<Base,Tag>` + index/positional access (`first`/`last`/`subscript`) (④)** | **REMOVED / DEFERRED** | The `Indexed` wrapper was deleted (odd-one-out, principal). The generic-`Indexed` + `first`/`last`/`subscript` dedup lands on `Collection.Protocol`, which does **not** yet refine `Iterable` (verified) — a gated fan-out-phase cascade (design §2.2). |
| **Mutating-op body dedup (②)** | **DEFERRED-IRREDUCIBLE** | needs a buffer-mutable capability protocol (uniform `append`/`remove`/`count`) that doesn't exist; `Hash.Table.Protocol` is read-only. Hot mutating ops stay concrete-Base by the specialization boundary regardless. |
| **Small `hashTable` shape (§2.9)** | **Optional KEPT (sentinel-empty REJECTED)** | `Hash.Table(minimumCapacity: .zero)` allocates 8 buckets (Hash.Table.swift:118-119), so a non-Optional sentinel-empty regresses Small's no-hash-overhead-while-inline property. The `Optional` (`nil` = zero allocation + honest inline signal) + the documented A11 `DiagnoseStaticExclusivity` take-and-put-back workaround is correct until either a non-allocating zero-bucket `Hash.Table` empty state exists OR the A11 crash is fixed upstream. |

## 4. Design-doc reconciliations surfaced (propose; not applied here)

1. **`unified-iteration-design.md` §2.8** — Swift.Sequence is the **deferred ecosystem-wide axis**, not a
   per-type re-add; span-primitive types drop the per-type Copyable iterator; eventual shape = one generic
   bridge. ("array-primitives still keeps it" is grep-false.)
2. **`unified-iteration-design.md` §2.9** — the sentinel-empty prescription is **incorrect**: zero-capacity
   `Hash.Table` allocates 8 buckets, regressing Small. Keep `Optional` + the documented A11 workaround.
3. **iterator-borrow "parked"→"deleted"** — `swift-iterator-borrow-primitives` was DELETED 2026-05-31 (D6
   withdrawal, user-confirmed), not parked. `unified-iteration-design.md` §2.5/§3, `HANDOFF-data-structure-
   iteration-arc.md` §2/§3.2/§5, and `cross-layer-capability-protocol-model.md` References should read
   "deleted". (The 4 stale source doc-comments are already fixed: buffer/buffer-linear/sequence.)
4. **`cross-layer-capability-protocol-model.md` §3.4** — `Memory.Contiguous.Protocol` requires **only**
   `span` (the `withUnsafeBufferPointer` requirement is dropped per the `with*`-elimination principle).

## 5. Verification (LOCAL/unpushed)

- **forEach disambiguator**: sequence-primitives `dcd748a`; spike `/tmp/set-foreach-disambig-spike` PASS
  (dual→Iterable, seq-only/triple→bridge, cross-module `-O` 0 `witness_method`); 160 tests green debug+release.
- **Set.Ordered**: per-type forEach deleted (`ff73329`), with*-elimination (`8a7d7b8`+`44b36af`), §2.9 reverted
  (`f84450d`), §2.8 comment reconciled (`9881605`); **108 tests green debug AND release**, warning-clean.
- **Memory.Contiguous.Protocol** reduced (`11e1611`): all **10 L1 conformers build green**; array (173) +
  buffer-linear (184) tests pass the disambiguator. (swift-ascii fails on a pre-existing `Binary.Parse`
  baseline break — zero Memory.Contiguous errors.)
- **SIL**: hot ops (contains/insert/==/algebra) byte-unchanged from the prior 0-witness receipts; the real
  probe builds release `-O` green; the disambiguator's forEach path is formally 0-witness (spike). Direct
  `-emit-sil` on the real probe is SwiftPM-tooling-blocked (as the cascade documented).
- **Out of scope, untouched**: no ×16 fan-out; `iterator-borrow` stays deleted; nothing pushed.

## 6. File-Organization Template (companion to the composition template, added v1.1.0)

> The file-org pass (2026-05-31, LOCAL/unpushed) over set-ordered's dependency closure,
> **bottom-up**. **Behavior-preserving only** — renames / splits / witness relocation; no
> API, logic, or test-count change. This is the organization half of the ×16 template
> (composition = §1–4; organization = this section).

### The convention (one protocol per conformance file)

| Rule | Shape |
|---|---|
| Conformance-file naming | `Type+Protocol.swift` — named for the protocol it satisfies, never a concept (`+Iteration` ✗) nor the conforming type alone (`.Iterator.swift` for a non-iterator ✗) |
| One protocol per file | grab-bags (e.g. Iterable+Sequenceable in one file) split per protocol |
| Witness co-location | each witness sits with the conformance it satisfies (`span` in `+Memory.Contiguous.Protocol.swift`, not a concept file) |
| Type/ops split ([MOD-004]/[MOD-036]) | cold/Copyable-gated conformances (Iterable, Sequenceable, Sequence.Drain, Clearable) in the OPS module (PLURAL); the lean `~Copyable` type + its hot witnesses (refined-C: `makeIterator`, `span`) in the TYPE module (SINGULAR) |
| One type per file ([API-IMPL-005]) | hoisted error enums, nested helper types → one declaration per file |
| Import hygiene | per-file imports trimmed to what's used; dead imports dropped. The ACTIVE `Memory_Iterator_Primitives` bridge (vends `Iterable.makeIterator`) is load-bearing and STAYS — it is NOT the dormant `memory-sequence` bridge |

### Realized per-variant conformance-file layout (Set.Ordered ×4)

TYPE module `{Domain} {Variant} Primitive` (SINGULAR):
- `X+Set.Protocol.swift` — Set.Protocol conformance + count/contains/index witnesses
- `X+Memory.Contiguous.Protocol.swift` — conformance + the `span` witness (co-located)
- `X+Sequenceable.swift` — the consuming `makeIterator()` witness (refined-C hot member)
- `X+Hash.Protocol.swift` — Hash.Protocol conformance (`==`/`hash` over the span)

OPS module `{Domain} {Variant} Primitives` (PLURAL):
- `X+Iterable.swift` — Iterable conformance (bridge-vended `Iterator.Chunk`; imports the active memory→Iterable bridge)
- `X+Sequenceable.swift` — Sequenceable conformance (thin: `SequenceableIterator` typealias + `underestimatedCount`)
- `X+Sequence.Clearable.swift`, `X+Sequence.Drain.swift` — clear/drain conformances + the `.drain` accessor
- `X+ExpressibleByArrayLiteral.swift`, `X+Buildable.swift` (Buildable variants)

**Demangle constraint.** Where a Sequenceable witness is a HAND-WRITTEN scalar iterator
(`Buffer.Linear.*.Scalar` in buffer-linear; absent in set-ordered, which forwards), it is
IRREDUCIBLE — it stays in its `+Sequenceable.swift` / `.Scalar.swift` file and is NOT deduped
via the dormant `memory-sequence` bridge (the generic `Memory.Cursor` witness demangle-crashes,
Signal-6 `swift_getAssociatedTypeWitness`).

### Per-package inventory (bottom-up; the fan-out checklist)

| Package | File-org fixes applied | Tests (debug=release) |
|---|---|---|
| memory | misnamed `+Cardinal.Protocol` → `+Carrier.Protocol` (the conformed protocol); stale headers; **test target repaired**¹ | **46** |
| iterator | clean (0) | — |
| buffer | clean (0) | — |
| sequence | `Sequence.Drain.Protocol` extracted ([API-IMPL-005]); `Sequenceable+Swift.Sequence` → `+first` (no such conformance present) | 160 |
| collection | `Collection.Remove.View` + `Collection.Access` extracted ([API-IMPL-005]) | 21 |
| buffer-linear | grab-bag `+Sequence.Protocol` → `+Iterable` + `+Sequenceable` ×4; Drain/Clearable split ×4; dead Collection imports | 184 |
| set | clean (0) | — |
| hash-table | 3-conformance grab-bag `+Sequence.Protocol` → `+Iterator.Protocol` + `+Iterable` + `+Swift.Sequence` ×2; stale exports comments | 27 |
| memory-iterator | clean (0 — exemplary bridge) | — |
| **set-ordered** | the exemplar (above): iteration split ×4, Error 3-way split, Hash.Protocol extraction (base/Fixed), Small Drain import | **108** |

¹ memory's test target had a pre-existing break (its arithmetic tests used the extracted
`Memory.Arena`/`Buffer` as scratch-allocation scaffolding). Repaired 2026-05-31: re-pointed at
memory's own `Memory.Allocator` (re-adding the siblings would form a package cycle [MOD-032]); the
one test of the extracted `Buffer.Mutable` itself was removed (coverage lives in the sibling).
46 tests green debug+release. (The nested `Tests/Testing` perf package was already correct.)

Out-of-closure siblings audited for template completeness (NOT fixed, by direction): set-algebra
(a test-support fixture grab-bag), memory-sequence (dormant bridge — leave).

### Deliberately left (not file-org violations)
- `Set.Ordered.Variants+Builder.swift` — bundles the two bounded variants' throwing `@Builder`
  inits in the umbrella; NOT a strict [API-IMPL-005] violation (extensions, not type decls).
- Pre-existing warnings, out of file-org scope: hash-table `Hash.Occupied.View+Iterable`
  #StrictMemorySafety (byte-identical to its pre-split source); one set-ordered test-file `try`.
