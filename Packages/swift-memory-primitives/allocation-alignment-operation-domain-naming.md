# Allocation & Alignment — Operation-Domain Naming

<!--
---
version: 1.0.0
last_updated: 2026-06-03
status: DECISION
tier: 3
scope: swift-memory-primitives (allocation + alignment surface)
applies: operation-domain-naming-and-organization.md (DECISION, Tier 3, ecosystem-wide)
reconciles: allocation-substrate-first-principles.md (DECISION, this package)
coordinates_with: GAP-O buffer/storage relocation (HANDOFF-derive-for-free-gap-o-relocation.md)
---
-->

> **Tier 3** (applies the ecosystem-wide operation-domain naming model to this
> package's allocation + alignment surface; timeless). This note records a
> design **converged with the principal** and **re-verified on disk** ([RES-023],
> 2026-06-03 — the `memory-primitives` skill is stale and was *not* trusted).
> **Execution is class-(c)** — dispatched by the principal via `/goal`. The
> **alignment rename landed 2026-06-03** (`Aligned` → `Memory.Alignable`); the
> allocation additions remain pending the allocation-substrate implementation pass.

## Context

`swift-memory-primitives` carries two operation-shaped subdomains — **allocation**
(`Memory.Allocator` / `Memory.Allocation`) and **alignment** (`Memory.Alignment` /
`Memory.Alignable`, formerly `Aligned`). The ecosystem's definitive naming model,
`operation-domain-naming-and-organization.md` (DECISION, 2026-05-26), gives every
operation domain four grammatical forms bound to roles (namespace · active protocol ·
passive protocol · witness) and a classification that selects which forms apply.
This note applies that model to the two subdomains.

**Governing directive** (principal): judge on the **evergreen / semantically-correct
shape** aligned with current best understanding; do **not** reason from the existing
(partly-mistaken) layering or the stale skill. The design below was re-derived from
the model + the on-disk surface, not from the skill's Module Structure table.

**The model is real and fully realized** for the iterator domain (`enum Iterator` /
`Iterator.\`Protocol\`` / `typealias Iterating` / `protocol Iterable` /
`Iterator.Witness` / `typealias Iteration`; manner-variants as their own packages),
so this is application of a proven shape, not speculative design.

## The decisive move: classify first — the shape is asymmetric on purpose

The model's §3 discriminator — *does the type carry mutable per-step state you drive?* —
splits operation domains into **machines** (stateful stream processors: `Parser`,
`Iterator`, `Serializer`) and **relations / values** (stateless: `Hash`, `Comparison`).
The classification, not aesthetics, decides which of the four forms exist.

| Subdomain | Carries per-step state? | Class | Evidence (verified 2026-06-03) |
|-----------|-------------------------|-------|--------------------------------|
| **Allocation** | **Yes** — an allocator advances a bump pointer / mutates a free list across calls; `allocate`/`deallocate` are `mutating` | **Machine** | `Memory.Allocator.\`Protocol\``: `mutating func allocate / deallocate` (`Memory.Allocator.Protocol.swift:34,45`) |
| **Alignment** | **No** — `alignUp(x)` / `alignDown(x)` / `isAligned(x)` are stateless one-shots; alignment is a *parameter* of `allocate(…, alignment:)`, not a thing that runs | **Relation / value** | `Memory.Alignment` is an immutable `struct { let shift }` (`Memory.Alignment.swift:33`); **zero** `mutating` anywhere in `Memory Alignment Primitives` (grep, 2026-06-03) |

A machine takes the full four-form treatment; a relation/value takes only the namespace
+ passive protocol (no active protocol, no gerund alias, no witness, no aligner). Inventing
a machine where there is only a relation is the exact "machine for a relation" mismatch the
model warns against (§2, §3) — so **no `Aligner` / `Aligning`**.

---

## Allocation — complete the machine model (riding the allocation-substrate pass)

### Current on-disk surface (verified 2026-06-03, [RES-023])

| Symbol | Shape | File:line |
|--------|-------|-----------|
| `Memory.Allocator` | `struct … : Memory.Allocator.\`Protocol\`, Sendable` — the **system malloc/free** conformer, fused with the namespace | `Memory.Allocator.swift:14` |
| `Memory.Allocator.\`Protocol\`` | active protocol: `~Copyable`, `associatedtype Error`, `mutating allocate(count:alignment:) -> Memory.Address`, `mutating deallocate(_:count:alignment:)` | `Memory.Allocator.Protocol.swift:23` |
| `Memory.Allocation` | namespace `enum` holding `Granularity = Tagged<Memory.Allocation, Memory.Alignment>` | `Memory.Allocation.swift:22,34` |
| `Memory.Allocation.Error` | `.exhausted` | `Memory.Allocation.Error.swift:14` |

So the active protocol **already exists** — the machine model is partly realized. Three
naming-model forms are absent today (verified absent ecosystem-wide, 0 hits each):
`Allocating`, `Allocator.Witness`, `Allocatable`.

### Four-form map (machine)

| Role | Form | Disposition |
|------|------|-------------|
| Namespace | `Memory.Allocator` (non-generic **enum**) | **Convert** struct→enum (see reconciliation below) |
| Active protocol | `Memory.Allocator.\`Protocol\`` | **Keep** (exists) |
| Active gerund alias | `typealias Memory.Allocating = Memory.Allocator.\`Protocol\`` | **Add** |
| Witness | `Memory.Allocator.Witness` (type-erased, closure-backed) | **Add** |
| Witness result-noun alias | — | **None** — `Memory.Allocation` is **taken** (§5.2 gate 3 "free" fails: it is both a namespace *and* the phantom tag of `Tagged<Memory.Allocation, Memory.Alignment>`) |
| Passive protocol | `Memory.Allocatable` | **Defer** — no data type meaningfully "declares its canonical allocator" (allocators are injected by context, not intrinsic like `Date`'s parser); add only if a real conformer appears |

Nesting note: the gerund alias is written `Memory.Allocating` (sibling of `Memory.Allocator`
under the `Memory` umbrella), not bare top-level `Allocating` — the `Memory.` qualifier is
the faithful analog of the model's top-level `Iterating` for a domain that lives under a
larger umbrella namespace, and it disambiguates ("allocating *what*"). Same reasoning the
passive alignment protocol stays `Memory.Alignable` (below).

Witness sketch (shape only; signatures track the allocation-substrate contract, not the
current one — see reconciliation):

```swift
extension Memory.Allocator {                       // enum namespace
    public struct Witness<Failure: Swift.Error>: Memory.Allocator.`Protocol`, ~Copyable {
        public typealias Error = Failure
        @usableFromInline var _allocate:  (Memory.Allocation.Request) throws(Failure) -> Memory.Allocation.Block
        @usableFromInline var _deallocate:(Memory.Allocation.Block) -> Void
        // init + mutating allocate/deallocate forwarding to the closures
    }
}
```

### Reconciliation with `allocation-substrate-first-principles.md` (DECISION) — load-bearing

The allocation surface is **not** independent of an existing converged DECISION. The
allocator *contract* is being redesigned by `allocation-substrate-first-principles.md`
v1.1.0 (converged 2026-05-25 via `/collaborative-discussion` + binding principal
refinements). That plan and this naming model **agree** and must execute **together**:

| Question | allocation-substrate (DECISION) | operation-domain model | Converged result |
|----------|--------------------------------|------------------------|------------------|
| `Memory.Allocator` host shape | "most naturally a caseless-`enum` namespace … Recommended; confirm" (open impl sub-decision) | §3: machine namespace **MUST** be a non-generic `enum` | **enum namespace** — both point here; not "optional," it is the convergent direction |
| Active protocol | `Memory.Allocator.\`Protocol\`` = `allocate(Request) throws(Error) -> Block` + `deallocate(Block)` | `Namespace.\`Protocol\`` | same protocol; the model adds the **gerund alias** on top |
| Concrete system conformer | **L2** (`Memory.Allocator.system`, *no public type*) | model is silent on conformer placement | system conformer leaves L1; today's `struct Memory.Allocator` (system malloc) dissolves into the enum namespace + the L2 accessor |
| Currency | new `Memory.Allocation.{Region, Block, Request}` | — | the witness's closures are typed over `Request → Block` |
| Witness | **not mentioned** | §5: every machine has a `Namespace.Witness` | **`Memory.Allocator.Witness` is a genuine addition** to the allocation-substrate plan — it completes the machine model |

**Consequence — bundle, don't precede.** The current on-disk protocol still has the *old*
signature (`allocate(count:alignment:) -> Address`). Adding `Memory.Allocator.Witness` or
`typealias Memory.Allocating` *before* the allocation-substrate implementation would (a)
write a witness against a signature about to change to `Request → Block`, and (b) alias a
namespace about to convert struct→enum — pure churn. Therefore the allocation-side naming
additions (`Allocating` alias, `Allocator.Witness`) MUST **merge into the allocation-substrate
implementation pass** (its action items already list: add `Region`/`Block`/`Request`, change
the protocol signature, L2 `Memory.Allocator.system`, struct→enum). This upgrades the
handoff's framing: the enum-namespace is **not** an "optional finer tidy to flag" — it is
the already-converged direction of *both* documents, and the two naming additions are the
naming-model layer of the same pass.

> This reconciliation is the prior-art-grep payoff ([HANDOFF-013a]/[RES-019]): the handoff
> treated the allocator surface as independent; the package's own DECISION doc shows it is
> the same surface, already mid-redesign.

---

## Alignment — value/relation, NOT a machine (independent, ready now)

### Current on-disk surface (verified 2026-06-03, [RES-023])

| Symbol | Shape | File:line |
|--------|-------|-----------|
| `Memory.Alignment` | value `struct { let shift: Memory.Shift }` + stateless ops `isAligned` / `alignUp` / `alignDown` / `magnitude` / `mask` / `validated` + `Comparable` | `Memory.Alignment.swift:33` |
| `Memory.Alignment.Align` | Property.View **accessor** tag (`enum Align {}` → `.align.up/.down`) — a stateless accessor over the immutable value, **not** a machine | `Memory.Alignment.Align.swift:8` |
| `Memory.Aligned` | passive protocol: `protocol Aligned { static var alignment: Memory.Alignment }` — **zero conformers** | `Memory.Aligned.swift:33` |
| `Memory.Alignment.Error` | `.notPowerOfTwo` / `.shiftExceedsBitWidth` | `Memory.Alignment.Error.swift:14` |

### Form map (relation / value)

| Role | Form | Disposition |
|------|------|-------------|
| Namespace + value | `Memory.Alignment` (deverbal/plain noun for a relation, §3) | **Keep** — already correct |
| Passive protocol | `Aligned` → **`Memory.Alignable`** | **Done (2026-06-03)** |
| Active protocol / gerund alias / witness / aligner | — | **None** — a relation has no machine. Do **not** add `Memory.Aligner` / `Memory.Aligning` |

`Memory.Alignment.Align` (the existing `.align.up/.down` Property accessor) is orthogonal to
the rejected `Aligner` machine — it is a stateless accessor namespace, and it stays.

### `Aligned` → `Memory.Alignable` — the passive `-able` form

A type conforming to this protocol *declares it has a canonical alignment* (`static var
alignment`). That is precisely the model's **passive** protocol (§4.2): data declaring a
property, named verb-stem + `-able` — directly analogous to `Parseable`'s `static var parser`
and `Iterable`'s `makeIterator()`. The current name `Aligned` is a past participle (a
*state*: "has been aligned"); `Alignable` (`-able`) names the *capability/property* ("has an
alignment / can be aligned"). The rename matches both the institute model (`Iterable`,
`Parseable`, `Serializable`) and the stdlib's own passive-protocol convention (`Comparable`,
`Equatable`, `Hashable`). It stays nested as `Memory.Alignable` (sibling of `Memory.Alignment`
under `Memory`), not bare top-level — same umbrella-namespace reasoning as `Memory.Allocating`.

**The rename is free — zero blast radius (verified 2026-06-03, [HANDOFF-050]/[PKG-NAME-013]):**

- Qualified references to the former `Aligned` protocol across all code org-mirrors (swift-primitives,
  swift-standards, swift-foundations, swift-institute, rule-*): **0** (beyond its own decl).
- Conformance-position scan (`: Aligned` / `, Aligned`): **0**.
- `Memory.Alignable`: **0** pre-existing — the target name is free.
- `Binary.Aligned` (the shape mentioned in `Memory.Alignment.swift:206`) is **not a real type**
  — illustrative comment only; no conflation.

Zero conformers ⇒ a pre-1.0 evergreen-window free rename ([ARCH-LAYER-008]: correctness is the
sole driver; consumer-count gating does not apply).

---

## GAP-O coordination (the only cross-arc coupling)

The GAP-O arc relocates today's aligned byte region `Buffer.Aligned`
(`swift-buffer-aligned-primitives`; `~Copyable`, specialized `Element == Byte`, conforms
`Buffer.\`Protocol\``, used by `swift-tensor-primitives`). Verified 2026-06-03:
`Buffer.Aligned` does **not** conform the former `Aligned` protocol today — so the rename touches it not at all.

The coupling is forward-looking: the relocated region will **conform** `Memory.Alignable`
(+ `Span.\`Protocol\``) — it is a *user* of the alignment capability, not the
protocol and not an aligner. Its own subject-name is a **GAP-O open sub-decision** (not this
note's; it is *not* `Memory.Alignable`, which is the capability-protocol slot).

**Sequencing**: the `Aligned` → `Memory.Alignable` rename (LANDED 2026-06-03) precedes / accompanies the GAP-O
`Buffer.Aligned` relocation, so the region conforms the correctly-named protocol from the
start and no double-rename is needed. The buffer/storage relocation itself is GAP-O's job
(Do-Not-Touch here).

---

## Verification ledger (every claim re-checked on disk, [RES-023])

| Claim | Verified | Where |
|-------|----------|-------|
| `Memory.Allocator.\`Protocol\`` exists (active protocol) | ✓ | `Memory.Allocator.Protocol.swift:23,34,45` |
| `Memory.Allocator` is a **struct** conformer (system malloc) | ✓ | `Memory.Allocator.swift:14` |
| `alignment` is a **parameter** of `allocate`, not a machine | ✓ | `Memory.Allocator.Protocol.swift:36` |
| `Memory.Allocation` is a namespace `enum` + `Granularity`; name **taken** (also the phantom tag) | ✓ | `Memory.Allocation.swift:22,34` |
| `Memory.Alignment` is an immutable value `struct` + stateless ops | ✓ | `Memory.Alignment.swift:33` (struct); `isAligned`/`alignUp`/`alignDown` ops by symbol (a concurrent doc-comment pass is drifting line numbers) |
| **No** stateful aligner (no `mutating`, no state in `Memory Alignment Primitives`) | ✓ | grep: 0 `mutating` |
| passive protocol (now `Memory.Alignable`), **zero conformers** | ✓ | `Memory.Alignable.swift:33` + 0-ref grep |
| `Allocating` / `Allocator.Witness` / `Allocatable` / `Aligner` / `Aligning` / `Alignable` **absent** | ✓ | 0 hits each, ecosystem-wide |
| `Memory.Allocator` / `Memory.Allocation` have **no external consumers** | ✓ | 0 refs outside decl files |
| `Buffer.Aligned` does **not** conform the alignment protocol today | ✓ | `swift-buffer-aligned-primitives` grep |

## Dead ends (do not re-derive)

- `Memory.Aligner` / `Memory.Aligning` — alignment has no machine (verified: no state/`mutating`).
- The alignment protocol as the relocated region's *name* — that is the capability-protocol slot.
- `Memory.Allocatable` / `Memory.Allocation`-as-witness-alias — deferred (no conformer) / blocked (name taken).
- Treating the allocation naming additions as independent of `allocation-substrate-first-principles.md` — they are the same surface; bundle.

## Execution (class-(c) — principal dispatches; NOT performed here)

1. **Alignment — LANDED 2026-06-03:** renamed `Aligned` → `Memory.Alignable` in
   `Memory Alignment Primitives` (+ its doc comment example). Mechanical, zero blast radius.
   **Sequence before/with** the GAP-O `Buffer.Aligned` relocation.
2. **Allocation (bundle):** fold the naming additions — `typealias Memory.Allocating =
   Memory.Allocator.\`Protocol\``; `Memory.Allocator.Witness`; struct→enum namespace — **into
   the `allocation-substrate-first-principles.md` implementation pass** (Region/Block/Request,
   protocol-signature change, L2 `Memory.Allocator.system`). Do **not** do them before it.
3. **No** `Memory.Allocatable`, **no** `Memory.Aligner`/`Aligning`, **no** witness result-noun alias.

## Follow-up (separate)

- **`memory-primitives` skill is stale** — flag for a `skill-lifecycle` pass. Verified stale
  sites: (a) Module Structure lists `Memory Namespace` (actual: singular `Memory Primitive`,
  [MOD-017] merge); (b) lists Lock/Map/Shared/Buffer/Pool/Arena as **internal targets** —
  they are separate sibling packages (on-disk targets are only Address/Alignment/Allocation/
  Contiguous/Inline/Shift + `Memory Primitive` root + umbrella + SLI, matching the [MOD-035]
  scope statement); (c) `[MEMP-003]` has the wrong location (`Memory Buffer Primitives`;
  actual `Memory Allocation Primitives`) and a stale signature (`byteCount: Int` /
  `throws(Memory.Address.Error)` / `deallocate(_:)`), itself superseded again by the
  allocation-substrate plan. The skill also predates both the allocation-substrate DECISION
  and this naming note.

## References

- `operation-domain-naming-and-organization.md` (DECISION, Tier 3) — the applied model (§3 classify, §4 active/passive, §5 witness, §7 ordering).
- `allocation-substrate-first-principles.md` (DECISION, this package) — the allocator-contract redesign this note rides with.
- Skill rules: `[PKG-NAME-001]` (noun namespace; machine→agent noun), `[PKG-NAME-002]` (`Namespace.\`Protocol\`` + gerund alias), `[PKG-NAME-015]` (witness `Namespace.Witness` + gated result-noun alias), `[API-NAME-001b]` (subject-vs-manner; relation classification), `[API-NAME-004a]` (witness-alias exemption), `[ARCH-LAYER-008]` (correctness-driven pre-1.0 reshape), `[MOD-035]` (memory scope statement), `[MEMP-003]` (allocator protocol — to be repaired).
- GAP-O: `HANDOFF-derive-for-free-gap-o-relocation.md`; `derive-for-free-capability-composition.md` @ `506ed08`.
