<!--
version: 1.0.0
last_updated: 2026-04-15
status: IN_PROGRESS
tier: 2
workflow: Audit [AUDIT-*] + Discovery [RES-012]
trigger: Ecosystem @unsafe hygiene against skill [MEM-SAFE-024]
scope: swift-primitives, swift-standards, swift-foundations
-->

# Ecosystem `@unsafe` Audit — Findings

> Companion to [ownership-transfer-conventions.md](ownership-transfer-conventions.md) and skill [MEM-SAFE-024]. Drives `unsafe-audit` branches in swift-primitives and swift-foundations.

## Question

Every `@unchecked Sendable` conformance across the Swift Institute ecosystem needs to be classified per [MEM-SAFE-024] and either (a) marked `@unsafe @unchecked Sendable`, (b) kept bare with a `// WHY:` comment, or (c) flagged for redesign. Which hits belong in which bucket, and what does applying `@unsafe` actually mean under Swift 6.3?

## Context

- Toolchain: **Swift 6.3.0 stable** (`swiftlang-6.3.0.123.5`), matches ecosystem requirement (memory: `feedback_toolchain_versions.md`).
- `.strictMemorySafety()` is enabled ecosystem-wide.
- Skill [MEM-SAFE-024] defines the framework but has **not yet been applied anywhere** — zero existing sites of `@unsafe @unchecked Sendable` across all three superrepos.
- Handoff: `HANDOFF-ecosystem-unsafe-audit.md` (medium priority, independent).

---

## Phase 0 — `@unsafe` Semantics (Swift 6.3)

### Q1: What does `@unsafe` mean in Swift 6.3?

`@unsafe` is an attribute introduced alongside SE-0458 (strict memory safety) to explicitly mark a declaration as a **propagator**: using it forces the caller to write `unsafe` at the use site and to accept responsibility for an invariant the compiler cannot check. Three declaration roles exist per [MEM-SAFE-020]:

| Role | Attribute | Caller obligation | Pattern |
|------|-----------|-------------------|---------|
| Absorber | `@safe` | None | Encapsulates unsafe internals behind safe API |
| Propagator | `@unsafe` | Must write `unsafe` at use site | Escape hatch / assertion |
| Unspecified | (none) | Inferred from signature | Default |

On a Sendable conformance, `@unsafe @unchecked Sendable` converts the *implicit* `@unchecked` assertion ("I, the author, assert this is safe") into an *explicit* one at the conformance site. Consumers see at a glance that the Sendable claim is a deliberate, caller-visible escape hatch.

### Q2: Does `.strictMemorySafety()` *require* `@unsafe` on `@unchecked Sendable`?

**No.** Empirical evidence:

| Repo | `@unchecked Sendable` hits (Sources/) | `@unsafe @unchecked Sendable` sites | Current build status |
|------|--------------------------------------|------------------------------------|----------------------|
| swift-primitives | 141 (across ~100 files) | 0 | Builds (per ecosystem convention) |
| swift-standards | 0 | 0 | Builds |
| swift-foundations | 91 (across 63 files) | 0 | Builds |

If `.strictMemorySafety()` required `@unsafe` on `@unchecked Sendable`, swift-primitives would not compile. It does. Therefore: **`@unsafe` on `@unchecked Sendable` is semantic lint / documentation in Swift 6.3, not a compile requirement.** The value is caller-facing clarity, not build correctness.

### Q3: Ecosystem precedent

| Pattern | Count in ecosystem | Notes |
|---------|-------------------|-------|
| `@unsafe` on methods/initializers/properties | 30+ files in swift-primitives alone | Broadly applied; `@unsafe func pointer(at:)` is idiomatic |
| `@unsafe struct` | 0 | Correctly avoided per [MEM-SAFE-021] (would infect all `self`-accesses) |
| `@unsafe @unchecked Sendable` on a conformance | **0** | Skill rule defined but never applied |
| Dedicated wrapper (`Reference.Sendability.Unchecked`) | 1 | Ecosystem's canonical "I assert Sendable here" escape hatch |

**Conclusion**: `@unsafe` as a general attribute is well-established. The specific `@unsafe @unchecked Sendable` form is a new pattern this audit is the first to apply. Syntax validity should be empirically verified on a single site before bulk application (see Phase 2 sequencing).

---

## Classification Framework

Per [MEM-SAFE-024], extended with a fourth category (D) observed in the ecosystem but not explicit in the skill.

| Cat | Semantics | Correct annotation | Action in this audit |
|-----|-----------|-------------------|----------------------|
| **A** | Synchronized — internal mutex / atomic / lock serializes access | `@unsafe @unchecked Sendable` + `## Safety Invariant` docstring | **APPLY** |
| **B** | Ownership transfer — `~Copyable` prevents sharing; Sendable enables move across threads | `@unsafe @unchecked Sendable` + `## Safety Invariant` docstring | **APPLY** (if docstring currently missing; tighten if present) |
| **C** | Thread-confined — single-thread access; `@unchecked Sendable` used only to cross one init boundary | **Should be `~Sendable`** (SE-0518) once stable | **SKIP** + `// WHY:` comment citing ~Sendable migration path |
| **D** | Tagged structural Sendable — phantom-type workaround; sound by construction (e.g., `Tagged<T, Cardinal>` not proving Sendable from `T: Sendable`) | `@unchecked Sendable` (no `@unsafe`) | **SKIP** + `// WHY:` comment citing phantom-type inference gap |

### Rationale for skipping C and D

- **Category C**: Adding `@unsafe` is a bandaid. The type isn't safe to send arbitrarily — it's safe to send *once*, to a specific thread. `@unsafe` makes the type look like "use carefully"; the truth is "don't use this form at all; the type should be `~Sendable` with one unsafe transfer site." Deferring per [MEM-SAFE-024] preserves the option to do the right fix later.
- **Category D**: The compiler cannot prove structural Sendable through phantom type parameters. There is no caller-visible invariant to uphold — the type is genuinely sound. `@unsafe` would mislead callers into thinking there's something dangerous about sending a `Hash.Table.Static<N>` across threads when in fact the bytes are pure values.

### Docstring template for Category A/B (uniform longer-form)

Every Category A or B site that receives `@unsafe` MUST carry the full three-section form, modeled on `Reference.Sendability.Unchecked`. At 232-hit scale, inconsistent depth creates future-author drift — the ecosystem anchor is longer, so every new site matches.

```swift
/// ## Safety Invariant
///
/// {One paragraph stating the invariant the caller must trust. For Cat A:
///  describe the synchronization mechanism (mutex, atomic, condition var).
///  For Cat B: describe the `~Copyable` ownership guarantee and the specific
///  move-across-threads semantics.}
///
/// ## Intended Use
///
/// {When this Sendable conformance is the right tool. Name the specific
///  use cases (e.g., "actor-owned job queue", "cross-thread ownership handoff
///  from submitter to worker"). Keep tight — 2–3 bullets or a short paragraph.}
///
/// ## Non-Goals
///
/// {What this conformance does NOT claim. Typical anti-patterns to warn away
///  from. E.g., "This does not grant arbitrary concurrent access — all
///  mutation must go through {named mechanism}" or "This does not survive
///  arbitrary sharing; ownership transfer is exactly-once via {mechanism}."}
```

The `@unsafe` attribute asks the caller to trust an invariant — the docstring MUST state what that invariant is, when the trust is warranted, and the shape of misuse.

### `// WHY:` comment template for Category C/D

```swift
// WHY: {Category C or D rationale, see unsafe-audit-findings.md}
// WHEN TO REMOVE: {~Sendable migration for C, or phantom-type inference fix for D}
// TRACKING: {ownership-transfer-conventions.md Tier 1 table for C}
```

---

## Pre-Classification Inventory

Sources/-only counts (Tests/, Experiments/, Research/, and Benchmarks/ excluded per handoff acceptance criterion `rg "@unchecked Sendable" Sources/`).

| Repo | Sources hits | Files touched |
|------|:------------:|:-------------:|
| swift-primitives | 141 | ~100 |
| swift-standards | 0 | 0 |
| swift-foundations (Sources/ only) | 91 | 63 |
| **Total** | **232** | **~163** |

swift-standards is clean — no work needed there. The scope is swift-primitives + swift-foundations.

---

## Known Classifications (from prior research)

### Category A — Synchronized (apply `@unsafe`)

Confirmed from [ownership-transfer-conventions.md §4 Tier 3 Pattern A] and direct file inspection:

| Type | Package | Synchronization |
|------|---------|-----------------|
| `Kernel.Thread.Synchronization<N>` | swift-foundations/swift-threads | Internal `Kernel.Thread.Mutex` + condition vars |
| `Kernel.Thread.Barrier` | swift-foundations/swift-threads | Protected by Synchronization |
| `Kernel.Thread.Gate` | swift-foundations/swift-threads | Protected by Synchronization |
| `Kernel.Thread.Semaphore` | swift-foundations/swift-threads | Protected by Synchronization |
| `Kernel.Thread.Executor` | swift-foundations/swift-executors | Internal mutex + condvar + `SerialExecutor` conformance |
| `Kernel.Thread.Executor.Stealing` | swift-foundations/swift-executors | Atomic `nextVictim` + shutdown flag |
| `Kernel.Thread.Executor.Stealing.Worker` | swift-foundations/swift-executors | Internal deque + condvar |
| `Kernel.Thread.Executor.Polling` | swift-foundations/swift-executors | Internal synchronization |
| `Executor.Main` | swift-foundations/swift-executors | Job queue + condvar |
| `Executor.Cooperative` | swift-foundations/swift-executors | Job queue + condvar |
| `Executor.Scheduled<Base>` | swift-foundations/swift-executors | Mutex + condvar + base executor |
| `Kernel.Thread.Handle.Reference` | swift-foundations/swift-kernel | Atomic-like join semantics |

12 confirmed Category A sites. The 7-executor figure from the handoff is a subset of this set (executors only).

### Category B — Ownership Transfer (apply `@unsafe`)

Confirmed from [ownership-transfer-conventions.md §4 Tier 3 Pattern B]:

| Type | Package |
|------|---------|
| `Kernel.Thread.Worker` | swift-foundations/swift-kernel (exactly-once join) |
| (Storage / Queue / Stack / Tree / Heap / List `~Copyable` conformers) | swift-primitives/* — scope-level verification needed per file |

High-density `@unchecked Sendable` primitives files (≥2 hits, indicating struct + conformances):

- `Storage.Inline ~Copyable.swift` (4)
- `List.Linked.swift` (4)
- `Storage.Arena.Inline ~Copyable.swift` (3)
- `Storage.Pool.Inline ~Copyable.swift` (3)
- `Memory.Inline ~Copyable.swift` (3)
- `Heap.swift` (3)
- `Heap.MinMax.swift` (3)
- 20+ more with 1–2 hits each

These are the bulk of the ecosystem's `@unchecked Sendable` surface. Each needs per-file inspection during Phase 1 to distinguish B (genuine ownership transfer, apply `@unsafe`) from D (Tagged structural workaround, skip + WHY).

### Category C — Thread-Confined (SKIP + `// WHY:`)

From [ownership-transfer-conventions.md §4 Tier 1] — 3 known sites:

| Type | Package | Status |
|------|---------|--------|
| `IO.Completion.IOUring.Ring` | swift-foundations/swift-io | DEFERRED, targeted for `~Sendable` |
| `IO.Completion.IOCP.State` | swift-foundations/swift-io | DEFERRED, targeted for `~Sendable` |
| `File.Directory.Contents.IteratorHandle` | swift-foundations/swift-file-system | DEFERRED, targeted for `~Sendable` |

Note: `IOUring.Ring` and `IOCP.State` were not found in current swift-io Sources/ during Phase 0 grep — they may have been restructured. Phase 1 must re-locate the current files and classify in place.

### Category D — Tagged Structural Sendable (SKIP + `// WHY:`)

> **Provisional fourth category.** Not in skill [MEM-SAFE-024] (which lists A/B/C only). This audit handles Category D **inline with `// WHY:` comments**, not via skill extension — per ground rule #9. This section is the evidence base for a future `/skill-lifecycle` proposal deciding whether Category D is a genuine fourth category or a subset of A/B.

**Pattern definition**: A type uses `@unchecked Sendable` solely because the compiler cannot prove structural Sendable through phantom type parameters (typically `Tagged<T, Marker>` patterns where `T: Sendable` should imply the whole type is Sendable but doesn't). The stored data is genuinely value-type bytes, safe to memcpy, with no runtime synchronization and no ownership invariant — the `@unchecked` is a *type-system workaround*, not a safety assertion.

**Why it's distinct from A/B**:

| Property | Cat A (synchronized) | Cat B (ownership transfer) | Cat D (structural) |
|----------|----------------------|----------------------------|--------------------|
| Runtime synchronization | Yes (mutex, atomic) | No | No |
| `~Copyable` | No | Yes | No (or incidental) |
| Caller-visible invariant | "Go through the mutex" | "Single owner" | **None** |
| Proper annotation | `@unsafe @unchecked Sendable` | `@unsafe @unchecked Sendable` | `@unchecked Sendable` (no `@unsafe`) |
| Why not `@unsafe` | — | — | There's nothing for the caller to uphold; `@unsafe` would mislead |

**Known sites**:

| Type | Package | Phantom-type gap |
|------|---------|-------------------|
| `Hash.Table.Static<N>` | swift-primitives/swift-hash-table-primitives | `<bucketCapacity>` value-generic blocks structural Sendable inference |
| (Others across Tagged-heavy primitives) | swift-primitives/* | Per-file verification in Phase 1 |

**Open empirical question (tested by this audit)**: Does Category D hold as a genuine fourth classification, or do all candidate sites collapse into A or B on closer inspection? Phase 1 classification will surface the evidence. If Category D holds (>5 clear sites, structurally distinct from A/B), propose skill extension. If it collapses (all sites reclassify to A or B), drop the category.

**`// WHY:` comment template for Cat D**:

```swift
// WHY: Category D — structural Sendable workaround.
// WHY: {specific phantom-type reason, e.g., "Tagged<T, Cardinal> does not prove
// WHY: structural Sendable from T: Sendable without explicit propagation."}
// WHY: No caller invariant to uphold — data is pure value bytes.
// WHEN TO REMOVE: Swift compiler gains structural Sendable inference through
// WHEN TO REMOVE: phantom type parameters, OR explicit propagation is adopted.
// TRACKING: unsafe-audit-findings.md Category D; tagged-structural-sendable.md
```

### Tier 2 — Debatable (OUT OF SCOPE for this audit)

From [ownership-transfer-conventions.md §4 Tier 2] — flag for separate discussion:

| Type | Tension |
|------|---------|
| `Kernel.File.Write.Streaming.Context` | Immutable struct vs. sequential-use operational contract |
| `Kernel.Memory.Map.Region` | L1 raw metadata vs. concurrent pointer dereferencing |
| `IO.Event.Batch` | Documented ownership-transfer protocol vs. raw pointer danger |
| `IO.Blocking.Threads.Job.Instance` | `~Copyable` + Sendable single transfer |

These are flagged in this audit but NOT acted on. They require design discussion — out of the audit's scope per handoff ("flag those in the findings doc; separate handoff if any are substantial").

---

## Scope Exclusion — `swift-io-state-investigation`

`swift-foundations/swift-io-state-investigation/` is a **live package** mirroring ~30 `@unchecked Sendable` files from `swift-io`. Per ground rule #7, **excluded** from this audit — investigation repos are deliberately volatile and not production. If it stabilizes into a consumer, audit separately.

Operationally: Phase 1/2 globs MUST NOT include `swift-io-state-investigation/Sources/**`. Double-check before each file walk.

---

## Phase 1 Plan — Per-File Classification

Output: this document's "Findings" table, populated one section per package.

1. For each file with `@unchecked Sendable`, read just enough to classify:
   - Does the type have a `deinit` or visible mutex/atomic field? → **Category A**
   - Is the type `~Copyable`? → **Category B** (unless stored fields include `Tagged<T, ...>` phantom params — then **D**)
   - Is the type a class stored across an actor boundary with docstring saying "all access on the poll thread"? → **Category C**
   - Does the type use `Tagged<...>` generic params where Sendable inference fails? → **Category D**
2. Populate the findings table with: file, type, category, synchronization mechanism (A) / ownership arg (B) / WHY rationale (C/D).
3. Flag anything that doesn't fit the framework as Tier 2 (debatable) — separate handoff.

Agent-parallelizable within each package. Verify every agent finding against source per [AUDIT-006] step 5 — raw agent accuracy for code-surface rules with exceptions is ~45%.

---

## Pilot Result (2026-04-15)

**Status: PASS** — `@unsafe @unchecked Sendable` is empirically confirmed as a valid Swift 6.3 annotation form under `.strictMemorySafety()`.

**Site**: `swift-foundations/swift-threads/Sources/Thread Synchronization/Kernel.Thread.Synchronization.swift` — commit `da86a35` on main.

**Canonical annotation form** (use exactly this for all Category A/B sites):

```swift
/// Mutex + N condition variable(s) wrapper.
/// ...
///
/// ## Safety Invariant
///
/// {paragraph stating the invariant the caller must trust}
///
/// ## Intended Use
///
/// {2–4 bullets or short paragraph naming concrete use cases}
///
/// ## Non-Goals
///
/// {2–4 bullets warning away from typical misuse}
///
/// ## Usage  (optional — preserve if the existing docstring had one)
/// ```swift
/// ...
/// ```
public final class Synchronization<let N: Int>: @unsafe @unchecked Sendable {
```

**What the pilot verified**:

| Gate | Method | Result |
|------|--------|--------|
| (a) Syntax compiles on Swift 6.3 | `swift build` on swift-threads | Build complete in 50.67s, 428/428 modules compiled |
| (b) No strict-memory interaction | `swift build 2>&1 \| grep Synchronization.swift` | Empty — zero warnings touch the pilot file |
| (c) DocC syntax valid | Static inspection of `## H2` headers + code fences | Well-formed DocC; plugin not configured in swift-threads, so live render deferred |
| (d) Build + test green | `swift test` | All 35 tests in 18 suites passed (0.100s). "Synchronization Waiter Tracking" directly exercised the pilot target. |

**Unsurprising interactions**: `swift-executors` has preexisting strict-memory warnings on `asUnownedSerialExecutor()` / `asUnownedTaskExecutor()` referencing stdlib `UnownedSerialExecutor`/`UnownedTaskExecutor`. These are unrelated to the pilot — they flag where `@unsafe` needs to propagate into stdlib-bridging methods inside those executor types. Phase 1 classification will catch them separately.

**Alternate forms not tested** (Phase 1/2 should not need them):
- Extension-site conformance (`extension X: @unsafe @unchecked Sendable {}`) — the skill's example form; still works but declaration-site is simpler when the original code uses declaration-site.
- `@unsafe` attribute prefix on the class itself — violates [MEM-SAFE-021] (would infect all `self` accesses).

---

## Phase 2 Plan — Application

**Per-repo branches**: `unsafe-audit` in swift-primitives and swift-foundations. swift-standards skipped (clean).

**Sequencing** (per ground rule #10 — pilot first, required):

1. **Pilot**: apply `@unsafe @unchecked Sendable` + full longer-form docstring to **`Kernel.Thread.Synchronization`** in `swift-foundations/swift-threads/Sources/Thread Synchronization/Kernel.Thread.Synchronization.swift`. Verify:
   - (a) Syntax compiles on Swift 6.3 stable
   - (b) No interaction surprise with `.strictMemorySafety()` — no new warnings, no new errors
   - (c) DocC renders the three-section docstring correctly
   - (d) `swift build` + `swift test` green for swift-threads (and any dependents that must rebuild)
   - If any check fails: STOP, escalate to user, do not bulk-apply.
2. **Bulk Category A** — commit per logical group (threads primitives, executors, kernel handle, etc.).
3. **Bulk Category B** — commit per logical family (storage primitives, queue primitives, stack primitives, heap primitives, tree primitives, list primitives, memory primitives, etc.).
4. **Category C WHY comments** — one commit per repo covering all Cat C sites.
5. **Category D WHY comments** — one commit per repo covering all Cat D sites.
6. Push each branch after build+test green.

Per memory `feedback_ask_before_build_test.md`: **ask user before running `swift build` / `swift test`** at each gate.

**Acceptance gate (per repo)**:
```bash
# Every Sources/ hit is either @unsafe-marked or has a // WHY: comment adjacent.
# (Excludes swift-io-state-investigation/ per ground rule #7.)
rg -B2 "@unchecked Sendable" Sources/ \
  | rg -v "@unsafe|WHY:" \
  | rg "@unchecked Sendable"
# Expected output: empty
```

---

## Category D Adjudication (2026-04-15)

> Principal one-pass adjudication of 70 D-candidates from 7 agents. Evidence base for future `/skill-lifecycle` proposal per ground rule #9.

### Governing principle

**If a type IS `~Copyable` and owns resources (heap storage, arena, buffer), it is Category B regardless of whether it ALSO has structural inference gaps.** The caller-visible invariant ("single owner; move is sound because sender loses access") is real and load-bearing. The structural gap is *additional* — removing the gap (hypothetical future compiler improvement) would not remove the need for `@unsafe`, because the ownership invariant would remain.

Category D is reserved for types where `@unchecked Sendable` is **solely** a structural workaround with **no caller-visible invariant** — removing the compiler gap would make the type provably `Sendable` with no `@unchecked` needed.

### Subpattern decisions

**SP-1: `<let N: Int>` value-generic + `~Copyable` heap-owning container → B**

Applies to: Agent 2's 8 Inline/Static/Small storage/queue/stack variants, Agent 6's 15 buffer variants, Agent 7's array/set/dictionary/slab inline variants.

*Reasoning*: the same container family WITHOUT value-generics (e.g., `Buffer.Ring`, `Queue.DoubleEnded`, `Stack.Bounded`) is also `@unchecked Sendable` and unambiguously Cat B. The value-generic adds a second inference gap but doesn't change the fundamental Sendable story — raw-pointer backing storage blocks inference regardless. Removing the value-generic would NOT make the type provably `Sendable`.

This decision resolves Agent 2's 8 LOW_CONFIDENCE flags and Agent 6's 10 LOW_CONFIDENCE flags — they were double-flagged as both B and D; B wins.

**SP-2: `@_rawLayout` bridge types → D (confirmed)**

Applies to: `Storage.Inline._Raw`, `Storage.Arena.Inline._Raw`, `Storage.Pool.Inline._Raw` (Agent 2), `Buffer.Arena.Inline._Elements` (Agent 6).

*Reasoning*: internal types with no public API, no caller invariant, no stored properties beyond the `@_rawLayout` marker. The comment `// @_rawLayout types require @unchecked Sendable` is explicit. Removing the compiler limitation would make these provably Sendable. 4 sites total.

**SP-3: Phantom `Element: ~Copyable` on heap-owning containers → B; on inline-only types → D**

Applies to: `Hash.Table` (Agent 4) → **B** (owns `Buffer.Slots` heap storage). `Hash.Table.Static` (Agent 4) → **D** (all inline `InlineArray` storage; `~Copyable` is incidental from parent type layering, not semantic ownership).

*Reasoning*: Agent 4's queue analysis of Hash.Table.Static is the strongest D evidence in the ecosystem — the `~Copyable` trait is inherited from the parent's extension scope, not from owning a resource. All storage is pure inline value bytes. The `where Element: Sendable` constraint on a phantom parameter is the tell.

**SP-4: Non-Sendable generic parameter blocks inference (non-`~Copyable` or `~Copyable`-for-iteration-only) → D (confirmed)**

Applies to:
- `Plist.ND.State<I>`, `JSON.ND.State<I>`, `XML.ND.State<I>` (Agent 5) — `AsyncIteratorProtocol` generic; not `~Copyable`
- `Infinite.Observable.Iterator`, `Infinite.Map.Iterator`, `Infinite.Zip.Iterator`, `Infinite.Scan.Iterator`, `Infinite.Cycle.Iterator` (Agent 5) — `~Copyable` for single-use iterator semantics, NOT for resource ownership transfer
- `Predicate<T>` (Agent 5) — non-`@Sendable` closure field; not `~Copyable`

*Reasoning*: the `~Copyable` on Infinite iterators is for iteration protocol compliance (single-use), not for expressing "this iterator owns a resource that transfers to another thread." No caller would write `@unsafe` when consuming one of these. Removing the generic-parameter inference gap would make them provably Sendable. ~14 sites total.

**SP-5: Pointer-backed Copyable value descriptors → D (confirmed)**

Applies to: `Memory.Buffer`, `Memory.Buffer.Mutable` (Agent 3), `Witness.Values._Storage` (reclassified from A in spot-check), `Loader.Library.Handle` (Agent 7), `HTML.AnyView` (Agent 5).

*Reasoning*: Copyable types where `UnsafeRawPointer` / `UnsafeMutableRawPointer` / `Any` existential blocks structural Sendable inference. No synchronization, not `~Copyable`. The stored bytes are genuinely safe to memcpy. ~5 sites total.

Note: `Loader.Library.Handle` already has `@unsafe` on the struct itself ([MEM-SAFE-021] violation). Preexisting — flagged for separate remediation, not this audit's concern.

**SP-6: CoW macro-generated storage → D (confirmed)**

Applies to: `CoW.Storage` template (Agent 5). 1 site.

*Reasoning*: macro-generated class with no runtime synchronization. The CoW discipline prevents shared mutation via `isKnownUniquelyReferenced` at the call site, but the storage class itself has no invariant. Decision affects every `@CoW`-using type in the ecosystem — a macro policy choice, not a per-type classification. Removing the inference gap (if the macro generated `Sendable`-provable storage) would obsolete `@unchecked`.

**SP-7: Miscellaneous structural workarounds → D (confirmed)**

Applies to:
- `PDF.HTML.Context.Table.Recording` + `Recording.Command` (Agent 5) — `Any` existential in one enum case
- `_SampleBatchStorage` (Agent 5) — unconditional `@unchecked Sendable` on a non-`~Copyable` class (also flagged as potential bug: should be conditional on `Element: Sendable`)
- Machine types (`Machine.Value._Storage`, `Machine.Capture.Slot`, `Machine.Capture.Slot._Storage`) (Agent 7) — class-based state holders
- `_Accessor` in swift-dependencies (Agent 1) — enum with no synchronization
- Clock type D-candidates from Agent 7
- `Sequence.Consume.View` (Agent 5)
- Other single-hit scatter

*Reasoning*: each has a specific structural reason `@unchecked` is needed (raw pointers, existentials, class-reference non-inference) with no caller-visible invariant.

**SP-8: `~Copyable` containers with conditional `Sendable where Element: Sendable` and raw-pointer backing → B**

Applies to: `Tree.N`, `Tree.N.Small`, `Tree.N.Bounded`, `Tree.Unbounded`, `Tree.Keyed`, `Tree.N.Inline` (Agent 5), `Sample.Batch` (Agent 5), `Set.Ordered.*` where applicable, `Dictionary.*` heap-backed variants.

*Reasoning*: identical to SP-1. These types own arena/heap storage via raw pointers and are genuinely `~Copyable` for ownership. The conditional `where Element: Sendable` gating is correct ownership-transfer conditioning. The governing principle applies: `~Copyable` + owns resources = B.

### Aggregate reclassification

| From D-candidate | → B (ownership confirmed) | → D (structural confirmed) |
|------------------|--------------------------:|---------------------------:|
| SP-1 (`<let N: Int>` + ~Copyable) | ~31 | 0 |
| SP-2 (@_rawLayout) | 0 | 4 |
| SP-3 (phantom on heap vs inline) | 1 (Hash.Table) | 1 (Hash.Table.Static) |
| SP-4 (non-Sendable generic) | 0 | ~14 |
| SP-5 (pointer-backed Copyable) | 0 | ~5 |
| SP-6 (CoW macro) | 0 | 1 |
| SP-7 (misc structural) | 0 | ~10 |
| SP-8 (~Copyable conditional) | ~8 | 0 |
| **Total** | **~40** | **~35** |

Of 70 D-candidates: ~40 reclassified to B (confirmed ownership transfer), ~35 confirmed D (genuine structural workaround). Category D at **35/218 = 16%** of the ecosystem — still a significant fourth category, well above incidental.

### LOW_CONFIDENCE resolution

36 LOW_CONFIDENCE flags across all agents. Resolution:

- Agent 2's 8 LOW flags: all SP-1 (`<let N: Int>` variants) → **resolved as B**
- Agent 6's 10 LOW flags: all SP-1 → **resolved as B**
- Agent 3's 2 LOW flags: Memory.Buffer / Memory.Buffer.Mutable → **resolved as D** (SP-5)
- Agent 4's 1 LOW flag: Hash.Occupied.View → **remains unresolved** — pointer-lifetime invariant; needs separate treatment (possibly a new category or Cat A variant). Flagged for Phase 2 case-by-case.
- Agent 5's 6 LOW flags: resolved per subpattern decisions above (most are D per SP-4/5/7)
- Agent 7's 8 LOW flags: resolved per SP-1 (B) and SP-4/7 (D)

**35/36 LOW flags resolved.** 1 residual (Hash.Occupied.View) deferred to Phase 2 case-by-case.

### Spot-check correction

- `Witness.Values._Storage`: reclassified A → D (SP-5). Agent 1's only misclassification; remaining Agent 1 Cat A sites verified correct.
- `Stack.Bounded`: Agent 2's D-flag reasoning was factually wrong (no `<let N: Int>`). Primary B classification stands; remove from D queue.

---

## Final Classification Summary (Phase 1 complete)

| Category | Count | % | Action in Phase 2 |
|----------|------:|--:|-------------------|
| A (synchronized) | 34 | 16% | `@unsafe @unchecked Sendable` + three-section docstring |
| B (ownership transfer) | 148 | 68% | `@unsafe @unchecked Sendable` + three-section docstring |
| C (thread-confined) | 1 | 0.5% | Keep `@unchecked Sendable` + `// WHY:` comment |
| D (structural workaround) | 35 | 16% | Keep `@unchecked Sendable` + `// WHY:` comment |
| Pilot (already committed) | 1 | — | Done (`da86a35`) |
| **Total** | **218** | | |

**Phase 2 work**: 182 sites get `@unsafe` + docstring (A+B). 36 sites get `// WHY:` comments (C+D). 1 already committed. Total edit surface: 218 files.

---

## Findings

Per-agent findings files:
- `unsafe-audit-agent1-findings.md` (17 hits)
- `unsafe-audit-agent2-findings.md` (30 hits)
- `unsafe-audit-agent3-findings.md` (23 hits)
- `unsafe-audit-agent4-findings.md` (3 hits)
- `unsafe-audit-agent5-findings.md` (57 hits)
- `unsafe-audit-agent6-findings.md` (42 hits)
- `unsafe-audit-agent7-findings.md` (45 hits)
- `unsafe-audit-spot-check.md` (21-sample verification)
- `unsafe-audit-category-d-queue.md` (adjudication queue)

---

## References

- Skill: [memory-safety](../../Developer/.claude/skills/memory-safety) — [MEM-SAFE-020] through [MEM-SAFE-025]
- Skill: [audit](../../Developer/.claude/skills/audit) — [AUDIT-006] methodology
- [ownership-transfer-conventions.md](ownership-transfer-conventions.md) — canonical ecosystem convention doc
- [tilde-sendable-semantic-inventory.md](tilde-sendable-semantic-inventory.md) — SUPERSEDED; retained for rationale on 3 Tier 1 thread-confined types
- Handoff: `/Users/coen/Developer/HANDOFF-ecosystem-unsafe-audit.md`
- SE-0458 (Strict Memory Safety), SE-0518 (`~Sendable`)
