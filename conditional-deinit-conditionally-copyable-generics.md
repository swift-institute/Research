# Conditional `deinit` on Conditionally-`Copyable` Generics

<!--
---
version: 1.0.0
last_updated: 2026-06-06
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
---
-->

> **⚠ SUPERSEDED IN PART (2026-06-07).** The Wall-1 proof below — *a custom conditional `deinit` on a
> conditionally-`Copyable` generic is impossible* — is **correct and stands**. Its **conclusion** that the
> sparse-inline `.Inline`/`.Small` carve-out is therefore a permanent *"converged equilibrium"* is
> **withdrawn**. That conclusion analyzed the wrong architecture: occupancy held in the *buffer*, forcing a
> buffer `deinit`. Per `occupancy-lives-in-the-leaf.md` (ratified 2026-06-07), occupancy + teardown belong in
> a single-allocation *leaf* — where the dense side already keeps them — so the buffer needs no `deinit` and
> the carve-out **dissolves with no language feature** (this note's own S2 + S5 probes prove the pieces;
> S8 does not apply to a generic field). Wall-2 / [MEM-SAFE-027] are unaffected.

## Context

The MSB capability tower's end-state (`decomposition-layer-placement-package-map.md`,
`GOAL-cleave-7-end-state.md`) drives every buffer discipline to a **pure-generic**
spelling that *composes the Memory leaves* with **zero structural carve-outs** — e.g.
`Buffer<Storage.Contiguous<Memory.Inline>>.Slab` rather than a hand-written concrete
`Buffer.Slab.Inline` type. One corner resists: the **sparse + inline + move-only**
buffer. Its occupancy lives at the buffer (a bitmap / free-list), so cleanup must run
at the buffer — but a *generic, conditionally-`Copyable`* buffer **cannot host a
`deinit`** (the `bd04f32` wall). The pure-generic end-state would require a `deinit`
that runs **only** for the `~Copyable` instantiations and is absent for the `Copyable`
ones — a *conditional* `deinit`.

This note is a Tier-3 investigation of whether that capability is
**expressible now / planned / fundamental-vs-unimplemented / implementable by us**,
conducted empirically against the real compiler (Swift 6.3.2 and 6.4-dev), the
upstream `swiftlang/swift` source, Swift Evolution, the Swift Forums, and prior art
(Rust drop-glue the linchpin; C++ conditionally-trivial destructors).

**Two walls, kept distinct throughout.** The MSB inline corner is blocked by *two*
independent compiler facts that are easy to conflate:

- **Wall 1 — Sema (this note's subject).** A conditionally-`Copyable` *generic* value
  type cannot declare any `deinit` (diagnostic `copyable_illegal_deinit`). This forces
  an *unconditionally* `~Copyable` concrete `.Inline` variant. Removing this wall needs
  a **language feature** (a conditional `deinit`).
- **Wall 2 — IRGen (`swiftlang/swift#86652`).** Even the *unconditionally*-`~Copyable`
  buffer's `deinit` is **skipped cross-package** when its `@_rawLayout` storage is
  reached through cross-module composition (`Storage.Contiguous<Memory.Inline>`) — its
  value-witness is misclassified *trivial*. Removing this wall is a **codegen bug fix**.

The cleave-7 live work is the Wall-2 seam-fix; the `.Inline` *names* are a §C.3
hard-floor KEEP. **This note's question is whether Wall 1 can ever be removed** — i.e.
whether the `.Inline` carve-out is a permanent hard-floor or an eventually-evergreen
spelling.

### Trigger
Tier-3 dispatch `HANDOFF-research-conditional-deinit.md` (2026-06-06): "is the evergreen
unlock real / planned / expressible-now / implementable-by-us — and should we build it,
pitch it, or wait?"

### Constraints
Non-mutating on the live `swiftlang/swift` clone (WIP on `fix-87136-stale-assertion`);
read-only on institute production; probe the real compiler before any "impossible"
claim ([feedback_convention_vs_typesystem_constraint]); Tier-3 rigor per [RES-020]/
[RES-023]/[RES-024]/[RES-026].

## Question

Can a conditionally-`Copyable` generic struct carry a `deinit` that runs **only** for
its `~Copyable` instantiations and is absent/trivial for the `Copyable` ones?

```swift
struct Wrapper<T: ~Copyable>: ~Copyable {
    var value: T
    deinit where T: ~Copyable { /* custom teardown */ }   // ← does / will / could Swift allow this?
}
extension Wrapper: Copyable where T: Copyable {}
// goal: usable as Buffer<Storage.Contiguous<Memory.Inline>>.Slab — no concrete `.Inline` type
```

Answered on four axes: **expressible now?** · **work in progress?** ·
**fundamental vs merely unimplemented?** · **implementable by us (scope + path)?**

## Methodology (SLR — [RES-023])

| Source class | What was searched | Verification |
|---|---|---|
| Real compiler | 8 spikes (S1–S8) + all deinit experimental flags, on Swift **6.3.2** and **6.4-dev** (`TOOLCHAINS=swift`, `+assertions`) | Compiled/ran by the author 2026-06-06; exact diagnostics captured |
| Upstream source | `swiftlang/swift` @ `e578b3a1e17`: `DiagnosticsSema.def`, `TypeCheckInvertible.cpp`, `OwnershipManifesto.md`, `Features.def`, `git log -S` | Read directly; commit SHAs cited |
| Swift Evolution | SE-0390, SE-0427, SE-0429 (raw proposal text); `visions/` directory | Parallel-subagent survey ([RES-020]); SE-0427 deinit clause **independently re-verified by the author** via raw-source fetch ([RES-031]) |
| Swift Forums | `[Pitch] Box`; `Unavailable deinit in ~Copyable types`; SE-0427 reviews; noncopyable walkthroughs | Discourse JSON, verbatim quotes + post #/date/author |
| Issue tracker | `swiftlang/swift#86652` | GitHub API (title/state/author/date confirmed) |
| Prior art | Rust (Reference, Nomicon, std, error index); C++ (P0848R3, cppreference, `eel.is/c++draft`) | Parallel-subagent survey against primary sources ([RES-020]/[RES-021]/[RES-032]) |
| Internal ([RES-019]) | `buffer-arena-conditional-copyable.md`; `swift-compiler-bug-catalog.md` §A14; `[MEM-COPY-016]`; cleave-7 GOAL/PROGRESS; calculus/package-map | Read directly; cited |

## The precise limitation

### Exact diagnostic (empirical, both toolchains)

```
error: deinitializer cannot be declared in generic struct 'Wrapper' that conforms to 'Copyable'
```

Identical on Swift 6.3.2 (`swiftlang-6.3.2.1.108`) and 6.4-dev (`Swift d13cbbfd336f246`,
`+assertions`). [Verified: 2026-06-06]

### Source location

| Artifact | Location |
|---|---|
| Diagnostic def | `include/swift/AST/DiagnosticsSema.def:8390` — `ERROR(copyable_illegal_deinit, …, "deinitializer cannot be declared in %kind0 that conforms to 'Copyable'")` |
| Emission site | `lib/Sema/TypeCheckInvertible.cpp:228–233` — `if (ip == InvertibleProtocolKind::Copyable) { if (auto *deinit = nominalDecl->getValueTypeDestructor()) { deinit->diagnose(diag::copyable_illegal_deinit, nominalDecl); … } }` |
| Originating commit | `a4e9919f290` — *"[Sema] require value deinit absence for Copyable"* (Kavon Farvardin, 2023-11-06): *"A value type … cannot conform to Copyable if it has a deinit. When NoncopyableGenerics is enabled, we make that part of what is required to verify that such a nominal type conforms to Copyable."* |
| Classes exempt | `TypeCheckInvertible.cpp:221–223` — `// All classes can store noncopyable/nonescaping values.` `if (isa<ClassDecl>(nominalDecl)) return;` (this is the upstream grounding for the Box-relocation workaround) |

The check is **unconditional**: any value-type destructor on a nominal whose `Copyable`
conformance is being verified fires the error — conditional conformance is not special-
cased. The comment reads as a flat model rule (`// A deinit prevents a struct or enum
from conforming to Copyable.`), with no `TODO`/`FIXME`/"for now".

### Canonical design statements (this is *by design*, not an oversight)

**OwnershipManifesto.md:1473–1478** (the origin of the rule, pre-dating the `~Copyable`
spelling — note the obsolete `moveonly` keyword):

> A value type declared `moveonly` which **does not conform to `Copyable` (even
> conditionally)** may define a `deinit` method. `deinit` must be defined in the primary
> type definition, **not an extension**.

The parenthetical "(even conditionally)" is original to the manifesto and is the precise
rule. The second sentence explains spike **S4** (deinit-in-extension is independently
forbidden).

**SE-0427 (Noncopyable Generics), § "Conformance to `Copyable`"** — the *accepted-
proposal* statement, with its rationale [independently verified by the author against
raw proposal source, 2026-06-06]:

> A conditional `Copyable` conformance is not permitted if the struct or enum declares a
> `deinit`. **Deterministic destruction requires the type to be unconditionally
> noncopyable.**

`deinit` appears exactly twice in SE-0427; this clause is the controlling text.

## Empirical probe matrix

Every plausible spelling was compiled. The headline-finding bar from the brief — "if
ANY existing expression works, the evergreen end-state is reachable now" — is **not**
met: nothing works.

| # | Construct | 6.3.2 | 6.4-dev | Result |
|---|---|---|---|---|
| **S1** | conditional-`Copyable` generic + plain `deinit` | ❌ | ❌ | `copyable_illegal_deinit` — *the wall* |
| **S2** | **unconditional** `~Copyable` generic + `deinit` | ✅ | ✅ | compiles — the `.Inline` hard-floor shape ((a)+(c) leg) |
| **S3** | `deinit where T: ~Copyable` (the aspirational syntax) | ❌ | ❌ | `expected '{' for deinitializer` — **not grammar** |
| **S4** | `deinit` in `extension … where T: ~Copyable` | ❌ | ❌ | `deinitializers may only be declared within a class, actor, or noncopyable type` + `copyable_illegal_deinit` |
| **S5** | conditional-`Copyable` generic, **no** `deinit` | ✅ | ✅ | compiles — the conditional-`Copyable` *shape* is fine |
| **S6** | plain (non-generic) `Copyable` struct + `deinit` | ❌ | ❌ | `copyable_illegal_deinit` + note "consider adding '~Copyable'" — the baseline |
| **S7** | conditional-`Copyable` generic + `~Copyable` **field**, no custom `deinit` | ✅ | ✅ | compiles **and runs**: field `deinit` fires for the move-only instantiation; the `Copyable` instantiation copies |
| **S8** | conditional-`Copyable` wrapper holding an inner unconditionally-`~Copyable` **struct** field | ❌ | ❌ | `stored property 'inner' of 'Copyable'-conforming generic struct 'Wrapper' has non-Copyable type 'Inner<T>'` — **no struct-only escape** |
| flags | **S1 + all** of `MoveOnlyClasses`, `MoveOnlyEnumDeinits`, `ConsumeSelfInDeinit`, `MoveOnlyTuples`, `MoveOnlyPartialReinitialization` | ❌ | ❌ | identical `copyable_illegal_deinit` — **no experimental flag unlocks it** |

Two probes carry the formal weight:

- **S7 (runtime output):** `MoveOnly(1) deinit fired` then `copied ok: 42, 42`. Swift
  **already** has conditional *automatic field* teardown — the move-only instantiation
  recursively destroys its field; the `Copyable` instantiation copies. This is the
  direct analog of Rust's drop-glue.
- **S8:** the only relocation that preserves conditional `Copyable`-ness is a **class**
  (a Copyable-layout pointer); an inner `~Copyable` *struct* field poisons the wrapper.
  This is *why* the inline (non-heap) corner is uniquely stuck — class-relocation
  reintroduces the heap box that inline storage exists to avoid.

**Only expressible forms today**, none of which reach the goal:
1. **Unconditional `~Copyable` concrete variant** (S2) — the current `.Inline` hard-floor.
2. **Class/Box-relocation** ([MEM-COPY-016]; `Storage<Element>.Arena` class, shipped) —
   conditional `Copyable` *is* recovered, but via a heap class. Correct for **heap-backed**
   sparse buffers; **wrong for inline** (it is the heap box inline was built to avoid).

## Formal semantics ([RES-024])

**Swift's copyability predicate.** For a generic value type `W<T>` with stored fields
`f̄`, the language admits `W<T> : Copyable` iff `(¬ hasUserDeinit(W)) ∧ (∀ f ∈ f̄.
type(f)[T] : Copyable)`. A conditional conformance `extension W: Copyable where T:
Copyable` asserts the predicate for every `T : Copyable`.

**The deinit law (SE-0427).** `hasUserDeinit(W) ⟹ ¬∃ (W : Copyable)` — not even
conditionally. Equivalently, the destructor's applicability constraint is fixed at
`true` (it applies to *all* instantiations), which forces unconditional `~Copyable`.

**Soundness of the law.** If `W<T> : Copyable` for some `T`, a value `w` can be
duplicated to `w₁, w₂` sharing one logical resource; both run `deinit` ⟹ the resource
is destroyed twice. Hence `Copyable ∧ hasUserDeinit` is unsound. This is a genuine
invariant, mirrored verbatim by Rust (E0184) and by the SE-0427 rationale
("Deterministic destruction requires …").

**The requested feature is the generalization, not a violation.** A *conditional*
`deinit` gates the destructor by a constraint `C` and requires `C` to be the complement
of the `Copyable` condition:

```
destroy(W<T>) ≜  run user-deinit ; destroy-fields(W<T>)      if  T ⊨ C   (i.e. T : ~Copyable)
                 destroy-fields(W<T>)                          if  ¬(T ⊨ C) (i.e. T : Copyable)
   well-formed iff  { T | T ⊨ C }  ∩  { T | W<T> : Copyable }  =  ∅
```

Because the user-deinit runs **only** for instantiations where `W<T>` is `~Copyable`
(non-duplicable), the double-destroy argument never applies — **soundness is
preserved**. The current model is the special case `C = true`. The feature relaxes `C`
to the `~Copyable`-of-`T` subset.

**Automatic vs custom teardown — the exact gap.** S7 proves `destroy-fields` is *already*
conditional in Swift (a `~Copyable` field runs its own deinit; a `Copyable` field is
trivial). What the language ties to whole-type `~Copyable`-ness is the **custom**
`run user-deinit` step — and the MSB sparse buffer needs exactly that (walk the
occupancy bitmap, deinitialize live slots), because raw/sparse storage hides liveness
from the automatic field walk. So the gap is narrow and precise: *conditional
**custom** teardown over manually-managed storage*, not conditional destruction in
general.

## Prior art ([RES-021]) — the contextualization step

The brief's hypothesis (Swift is "behind Rust" here) is **refuted**. Two of the three
major affine/ownership languages converged on the *same* restriction; the third allows
it only because it does not tie destructors to copyability.

### Rust — the linchpin (identical restriction, identical escapes)

| Rust fact (primary source) | Swift analog |
|---|---|
| `Drop ⟹ !Copy`: "You cannot implement both `Copy` and `Drop` on the same type … makes it very hard to predict when, and how often destructors will be executed" (std `Drop`); rustc **E0184** | `deinit ⟹ ~Copyable` (SE-0427; `copyable_illegal_deinit`) — *the same law, same rationale* |
| **No conditional `Drop` impl**: "it is not possible to specialize `Drop` to a subset of implementations of a generic type" — rustc **E0367** | conditional-`Copyable` + `deinit` forbidden (S1) — *the same prohibition* |
| Drop **glue** = automatic, recursive field destruction; conditional on each field's own drop need | automatic memberwise destruction (S7) — *already present, already conditional* |
| Escapes: **(a)** hoist the bound onto the type (applies to all instances) / **(b)** wrapper struct carrying `Drop` (E0367 docs) | **(a)** make it unconditionally `~Copyable` (the `.Inline` variant) / **(b)** push the deinit to a class/Box ([MEM-COPY-016]) — *one-to-one* |
| `ManuallyDrop<T>` ("inhibit the compiler from automatically calling `T`'s destructor … 0-cost") for manual/sparse cleanup | manually-managed storage (`UnsafeMutablePointer` + manual `deinitialize`/`deallocate` from a `~Copyable` owner) |
| `dropck` / `#[may_dangle]` / `PhantomData` | **no Swift analog** — Rust-only lifetime-soundness machinery (where the comparison stops) |

**Conclusion:** Rust does **not** permit a user-written destructor conditional on a
generic bound. Its only instantiation-conditional destruction is *automatic field
drop-glue* — exactly what Swift's S7 already does. Custom sparse cleanup in Rust uses
`ManuallyDrop` + an inner unconditionally-non-`Copy` type — the precise twin of Swift's
class/Box-relocation. The institute is **not** missing a Rust trick.

### C++ — the lone exception, and why it does not port

C++ *does* express a "destructor that is trivial for some instantiations and non-trivial
for others": `std::optional` ("If `T` is trivially-destructible, then this destructor is
also trivial"), `std::variant` ("This destructor is trivial if
`std::is_trivially_destructible_v<T_i>` is `true` for all `T_i`"), generalized by
**P0848R3** (conditionally-trivial special member functions, C++20: "we want `wrapper<T>`
to be trivially copyable if and only if `T` is copyable", selected by most-constrained-
satisfied overload). But C++'s destructor is a **separate special member from the copy
constructor**; a user-provided destructor only *deprecates* the implicit copy ("rule of
three"), it does not delete it — `destructor ⇏ move-only`. Swift (and Rust) make the
*presence of a destructor the copyability switch itself*; C++ keeps the two axes
orthogonal. **C++'s model is therefore not portable to Swift** — the very thing that
lets C++ have a conditionally-trivial destructor (decoupling from copyability) is the
thing Swift's safety model deliberately couples.

**Universal-adoption ≠ universal-necessity ([RES-021]):** the *restriction* (no
user-written conditional destructor) is the cross-language norm among
copyability-coupled destructor models; only the decoupled (C++) model escapes it, at the
cost of the safety property Swift wants. The absence in Swift is a deliberate design
equilibrium, not a gap.

## Verdict on each axis

| Axis | Verdict |
|---|---|
| **Expressible now?** | **NO.** No spelling compiles (S1, S3, S4, S6); `deinit where` is not grammar (S3); deinit-in-extension is independently forbidden (S4); no experimental flag unlocks it. The only expressible forms (S2 concrete variant; class/Box-relocation) both abandon the pure-generic *inline* goal. There is **no struct-only escape** (S8). |
| **Work in progress — Wall 1 (the feature)?** | **NO.** Not in SE-0390/0427/0429, no ownership/noncopyable `visions/` doc, no roadmap, no forum pitch, and no compiler branch (upstream `main` history of `TypeCheckInvertible.cpp` is NFC renames + cxx-interop only). SE-0427 *explicitly forbids* it; the `[Pitch] Box` thread resolves the **identical shape** by making `Box` unconditionally `~Copyable` (post #1: "We can't make `Box` a copyable type because we need to be able to customize deinitialization"; Joe Groff engaged on naming only). The institute's `.Inline` hard-floor is exactly what Apple itself does. |
| **Work in progress — Wall 2 (`#86652` codegen)?** | **YES — by us.** `swiftlang/swift#86652` ("InlineArray<capacity, …> with value generic parameter skips deinit for cross-module ~Copyable elements") is **open**, filed 2026-01-20 by `coenttb`, no upstream PR yet; the fork carries adjacent IRGen branches (`fix-rawlayout-deinit-irgen`, `fix-87136-*`, `pr-88025-update`). Distinct from the feature. |
| **Fundamental vs unimplemented?** | **Two-level.** The *law* `deinit ⟹ (unconditionally) ~Copyable` is **fundamental** (soundness; mirrored by Rust E0184/E0367). The *feature* conditional-`deinit` **respects** that law (the deinit runs only for `~Copyable` instantiations) and is **sound-in-principle but unimplemented and deliberately excluded** by SE-0427's simpler whole-type model (and by the `TypeCheckInvertible.cpp:172` "simplifies the model a bit" conditional-conformance restriction). So: *not* fundamental-impossible — a deliberate simplification an Evolution proposal could relax. |
| **Implementable by us?** | **Wall 2: yes** — a bounded IRGen fix on the standard upstream-PR path, already in progress (§A14 "what an upstream fix must do": classify a struct transitively containing a cross-module `@_rawLayout` member as non-trivially destructible cross-package). **Wall 1: it is a language feature**, not a fork-only change — new grammar (S3) + a conditional-conformance-model generalization (Sema) + conditional drop-glue (IRGen, entangled with the same cross-package value-witness classification as `#86652`). It **requires a Swift Evolution proposal first**; a fork-gated experimental feature cannot be a dependency of public packages (consumers use stock toolchains). The principal's demonstrated compiler-contribution capability makes a *reference implementation* feasible — which strengthens a pitch — but does not convert a language feature into a fork patch. |

## The horizon + confidence

- **Wall 2 (`#86652`) — near-term, high confidence.** A real, filed, bounded codegen
  bug with an in-progress fork effort and a clear fix specification. Landing it makes the
  *current* `.Inline` hard-floor leak-free cross-package — the cleave-7 Phase-1 goal.
  This is the concrete, ownable win. Confidence **HIGH** that it is fixable by us;
  upstream-merge timeline is the usual swiftlang review variance.
- **Wall 1 (conditional `deinit`) — no near-term horizon.** Sound in principle but
  explicitly excluded by an accepted proposal, unmentioned on any roadmap, and resolved
  the opposite way (`Box`) the one time the Swift team met the identical shape. Two of
  three comparator languages enforce the same restriction. Confidence that the
  *evergreen pure-generic inline spelling* arrives without institute action: **LOW**.
  Confidence that a well-evidenced Swift Evolution pitch would be *accepted*: **LOW-to-
  MEDIUM** — the soundness argument is clean and the motivating case is real, but it must
  overturn SE-0427's stated rationale and the team's demonstrated `Box` preference, and
  the core team has signalled general skepticism toward new deinit-adjacent linear-type
  machinery (John McCall, *Unavailable deinit in ~Copyable types*, 2023: "the Rust
  community … pursued and ultimately abandoned a feature like this").

## The institute's best move — layered

1. **Now — land `#86652` (Wall 2): implement-in-fork + upstream PR.** This is the real,
   bounded, valuable, partly-in-progress win. It makes the existing inline hard-floor
   leak-free cross-package and unblocks cleave-7 Phase-1. Route via `/swift-pull-request`.
   *This is the action this note most strongly endorses.*
2. **~~Keep the `.Inline` concrete hard-floor~~ — WITHDRAWN 2026-06-07.** Superseded by
   `occupancy-lives-in-the-leaf.md`: the inline carve-out is **not** forced. It existed only
   because the occupancy oracle was held in the *buffer*; moving it into a move-only
   single-allocation *leaf* (the dense `Memory.Inline` pattern; the shipping `Storage.Arena`
   pattern) leaves the buffer with no `deinit`, so one generic `Buffer<…>.X` covers the inline
   case too. The leaf is move-only; the *type* dissolves. (The Wall-1 *law* in this note is
   untouched — it simply does not apply when the buffer carries no `deinit`.)
3. **Defer the conditional-`deinit` Swift Evolution pitch — do not fork-implement as a
   shipping path.** Hold it as a *strategic option*, to be revisited only if the
   institute accumulates **more** independent motivating cases (other inline + move-only +
   sparse needs) that would strengthen the Evolution evidence per [PITCH-PROC-002]. A
   single motivating case against an explicit accepted-proposal prohibition is thin
   evidence. A draft sketch is recorded below so the option is ready, not so it is taken
   now.

**Recommendation status:** RECOMMENDATION. Adopt move (1) immediately; ratify (2) as the
documented permanent disposition for the inline corner; hold (3).

## Appendix — Swift Evolution pitch sketch (held, not submitted — [PITCH-PROC-004])

> Recorded for readiness only. Submission is **not** recommended now (see move 3).
>
> **Update (2026-06-06):** promoted to a full draft — **PITCH-0003** (`Swift-Evolution/Drafts/Conditional Deinit for Conditionally-Copyable Generic Types.md`), on principal direction. **Held in `Drafts/`, not submitted.** Submission stays deferred per move 3; the draft now exists, ready when the evidence/timing warrant.

**Problem.** A generic value type that is `Copyable where T: Copyable` cannot declare a
`deinit`, even one that is only needed for its `~Copyable` instantiations. Authors of
inline, move-only-capable containers with manually-managed (sparse/raw) storage are
forced to either (a) ship a separate unconditionally-`~Copyable` concrete variant per
inline shape, or (b) relocate cleanup to a heap class — which defeats the purpose of
inline storage. Swift already performs conditional *automatic field* teardown; only
conditional *custom* teardown is missing.

**Proposed direction.** Permit a `deinit` on a type with a conditional `Copyable`
conformance, where the `deinit` is statically constrained to the complement of the
`Copyable` condition (it applies only to `~Copyable` instantiations). The compiler
verifies the partition (`Copyable`-instantiations have no applicable `deinit`) and emits
conditional drop-glue (the destructor is in the value-witness only for the `~Copyable`
specializations). Surface syntax TBD (a constrained `deinit`, or inference from the
conditional conformance) — note `deinit where …` is not currently grammar.

**Evidence.** The MSB sparse + inline + move-only buffer (`Buffer.Slab.Inline` &c.); the
empirical probe matrix (S1–S8) in this note; the soundness argument (the deinit runs
only for non-duplicable instantiations). Reference implementation feasible given prior
`swiftlang/swift` IRGen contributions in this subsystem.

**Open questions.** Syntax; interaction with `discard` (SE-0429) and resilience
(`@frozen`); whether conditionality may key on anything beyond `T: ~Copyable`; relation
to the cross-package value-witness classification that `#86652` already exercises.

**Impact.** Evergreen pure-generic inline containers — no per-shape `.Inline` variant —
across the MSB tower and any future inline move-only sparse structure.

**Related work.** SE-0390, SE-0427 (the prohibition this would relax), SE-0429; Rust
drop-glue / E0184 / E0367; C++ P0848R3; the `[Pitch] Box` thread.

## References

### Primary — Swift compiler (`swiftlang/swift` @ `e578b3a1e17`)
- `include/swift/AST/DiagnosticsSema.def:8390` — `copyable_illegal_deinit`.
- `lib/Sema/TypeCheckInvertible.cpp:221–233` — emission site; classes-exempt grounding.
- `docs/OwnershipManifesto.md:1473–1478` — "(even conditionally) … not an extension".
- `include/swift/Basic/Features.def:366,369,363` — `MoveOnlyEnumDeinits`, `ConsumeSelfInDeinit`, `MoveOnlyClasses` (none unlock the case).
- Commit `a4e9919f290` (Kavon Farvardin, 2023-11-06) — "[Sema] require value deinit absence for Copyable".

### Primary — Swift Evolution & Forums
- SE-0390 Noncopyable Structs and Enums — `…/0390-noncopyable-structs-and-enums.md` (§ Deinitializers; Future directions § "Conditionally copyable types", which omits deinit).
- SE-0427 Noncopyable Generics — `…/0427-noncopyable-generics.md` (§ "Conformance to `Copyable`": the controlling prohibition; verified 2026-06-06).
- SE-0429 Partial Consumption of Noncopyable Values — `…/0429-partial-consumption.md`.
- `[Pitch] Box` — https://forums.swift.org/t/box/84014 (Alejandro Alonso, 2026-01-07; posts #1, #18; Joe Groff #8 on naming).
- `Unavailable deinit in ~Copyable types` — https://forums.swift.org/t/unavailable-deinit-in-copyable-types/68627 (John McCall #6, #16, 2023-11-25/26).
- `swiftlang/swift#86652` — https://github.com/swiftlang/swift/issues/86652 (open; `coenttb`, 2026-01-20; no upstream PR).

### Primary — Prior art
- Rust E0184 — https://doc.rust-lang.org/error_codes/E0184.html ; E0367 — https://doc.rust-lang.org/error_codes/E0367.html ; `Drop` — https://doc.rust-lang.org/std/ops/trait.Drop.html ; destructors — https://doc.rust-lang.org/reference/destructors.html ; `ManuallyDrop` — https://doc.rust-lang.org/std/mem/struct.ManuallyDrop.html ; dropck — https://doc.rust-lang.org/nomicon/dropck.html.
- C++ P0848R3 — https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0848r3.html ; `[class.dtor]` — https://eel.is/c++draft/class.dtor ; `std::optional`/`std::variant` destructor triviality (cppreference).

### Internal ([RES-019])
- `buffer-arena-conditional-copyable.md` (IMPLEMENTED, v1.2.0) — heap-backed sparse solved by pushing the deinit to a `Storage` **class**; `.Inline`/`.Small` "requires Swift language evolution".
- `swift-compiler-bug-catalog.md` §A14 — `swift#86652` cross-package `@_rawLayout` deinit-skip (Wall 2).
- `[MEM-COPY-016]` (memory-safety/advanced-ownership) — Conditional-Copyable cleanup triangle; Box-relocation; one-truth-holder.
- `swift-vector-primitives/Research/noncopyable-conditional-copyable.md` (DECISION) — deinit-implies-noncopyable; `@_rawLayout` blocks conditional Copyable for Inline.
- `.handoffs/GOAL-cleave-7-end-state.md`, `cleave-7-PROGRESS.md` — the motivating end-state; §C.3 hard-floor KEEP.
- `decomposition-layer-placement-{calculus,package-map}.md` — the hard-floor framing.

### Canonical skill encoding (ratified by the seat 2026-06-06)
These findings are promoted from this note into the canonical skills (skills override memorized patterns):
- **memory-safety** `[MEM-COPY-016]` (EXTENDED) — the law-is-fundamental clause (SE-0427), the inline third corner (forced concrete `~Copyable` variant = converged equilibrium, removal gate), and the Wall-1/Wall-2 split.
- **memory-safety** `[MEM-SAFE-027]` (NEW) — the `_deinitWorkaround` placement rule for `swift#86652` (Wall 2 codegen): substrate-leaf for composed, on-the-type for direct-`@_rawLayout`, never buffer-level over a nested substrate (SIGSEGV).
- **ecosystem-data-structures** `[DS-002]` (CORRECTED) — the `.Static`/`.Small` unconditional-`~Copyable` disposition reframed as the by-design law (not a "compiler limitation"); the `#86652` item corrected (deinit fires same-package; only the cross-package skip remains).
- **ecosystem-data-structures** `[DS-023]` (NEW) — dense-occupancy inline dissolves-to-generic vs sparse-occupancy inline forces-the-concrete-variant.
- *(pending — Strata→modularization track)* `[MOD-PLACE]` — the placement-calculus hard-floor exception (cross-referenced, not encoded here).

### Empirical artifacts
- Spikes S1–S8 + flag probe + s7 runtime: `/tmp/cdspikes/` (Swift 6.3.2 and 6.4-dev, 2026-06-06).
