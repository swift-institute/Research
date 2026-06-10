# Tower Research-Arc Riders (2026-06-10)

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

The riders of the post-archaeology research arc (companions to R1–R5:
`hashed-container-substrate-archaeology.md`, `container-protocol-lattice-borrowing-iteration.md`,
`slot-map-prior-art-and-the-generational-seam.md`, `column-spelling-ergonomics-alias-vocabulary.md`,
`deque-ring-bounded-queue-archaeology.md`). Five items: the SE-0527 re-land watch + shadow re-check, the
R-6 filing dossier (held — outward action needs a fresh principal YES), the gate-bump readiness dossier,
the single-allocation fusion scoping note, and the consuming-into-escaping-closure watch. All external
claims live-verified 2026-06-10 (sweep agent, primary sources; URLs in §References).

## 1 · SE-0527 re-land watch + `Swift.Array` shadow re-check

**Status: NOT re-landed.** The re-land is PR swiftlang/swift#89698 ("Reapply [stdlib] Implement
RigidArray and UniqueArray from swift-collections", branch `revert-revert-uniquearray`, forcing CMake
response files) — **OPEN**, with CI actively churning (latest trigger: Windows smoke test requested by
the author 2026-06-10T08:04Z). At today's main HEAD (`81b9ead`), `stdlib/public/core/UniqueArray/` and
`RigidArray/` do not exist (contents API 404). [Verified: 2026-06-10]

**Shadow pre-check: clean.** Zero bare `UniqueArray`/`RigidArray` identifiers in institute Sources
(grep across swift-primitives). The institute's `Array<S>` shadow and nested vocabulary don't collide
with the compound stdlib names. **Action on merge of #89698**: re-run the identifier grep; smoke a
swift-array-primitives build against the first 6.5-dev snapshot containing it (dev-toolchain probe only;
the 6.3.2 gate is unaffected). Watch trigger: #89698 `merged_at` non-null.

## 2 · R-6 filing dossier (HELD — file only on a fresh principal YES)

The repro is durably preserved and bug-report-ready:
`swift-institute/Experiments/cow-box-deinit-omission-miscompile/` (Experiments commits `2e2f7f1` +
`113c711`) — `MinimalRepro/{inner.swift, main.swift, run.sh}` (two-file swiftc pair), SwiftPM
two-module `Sources/{Nested,Repro}`, captured `Outputs/`, and the full mitigation matrix including the
Q8 guard shapes 11–12 (`@exclusivity(unchecked)` ✗, `@_eagerMove` ✗ — both negative, as the archaeology
anticipated). The R1-arc upstream search found **no existing duplicate** issue; when filed, it is novel.

**Draft issue skeleton** (ready; do not file):

- **Title**: `-O` omits a user `deinit` on a generic-namespace-nested `~Copyable` struct stored in a
  generic class box after `isKnownUniquelyReferenced` (fields still destroyed → element leak)
- **Body**: environment (Apple Swift 6.3.2 `swift-6.3.2-RELEASE`, macOS arm64; reproduces with the
  bundled two-file `swiftc -O` pair); the shape (`final class Box<W>` holding `NS<A>.Inner<E>` — a
  nested-generic `~Copyable` struct with a user `deinit` — plus `isKnownUniquelyReferenced(&box)` on the
  mutation path); observed (release: user deinit skipped, stored fields destroyed — elements leak, bytes
  freed; debug correct; flat top-level generics correct; paths without the uniqueness call correct);
  mitigation matrix (empty box deinit ✗ · `AnyObject?` first-field ✗ · `@exclusivity(unchecked)` ✗ ·
  `@_eagerMove` ✗ · **drain-in-class-deinit ✓** — the positive control); repro steps = `run.sh`.
- **Framing**: sibling of swiftlang/swift#86652 (config-dependent destroy correctness; that one is the
  cross-module `@_rawLayout` value-witness misclassification; this one is release-side user-deinit
  omission behind a class hop). Reference [MEM-SAFE-028] as the downstream mitigation users can apply.
- **Pre-filing checklist** (per the issue-investigation discipline): re-run `run.sh` on the
  then-current toolchain (6.3.2 + latest 6.4.x snapshot) the day of filing; attach both outputs; link
  the Experiments package, not /tmp paths.

## 3 · Gate-bump readiness dossier (6.3.2 → 6.4)

| Item | Today (6.3.2 gate) | At the bump | Size/evidence |
|---|---|---|---|
| `@_lifetime` → `@lifetime` | underscored spelling required (archaeology Q5) | 64x parses both (32 `@lifetime` / 4 `@_lifetime` remnants in Span.swift) → mechanical sweep, non-blocking | **194 files / 436 occurrences** across swift-primitives (counted 2026-06-10) |
| `SuppressedAssociatedTypes` experimental flag | the entire iteration/collection lattice rides it (R2 discovery — bare 6.3.2 rejects `associatedtype X: ~Copyable`) | SE-0503 ("Suppressed Default Conformances on Associated Types With Defaults") is **Accepted** and its spelling matches; NUANCE: upstream main carries TWO flags — `SuppressedAssociatedTypesWithDefaults` (the SE-0503 feature, `Features.def:289`) and the older `SuppressedAssociatedTypes` (still separate, `:464`). At the bump: verify which gate (if any) 6.4-stable still requires, and whether defaulted-associated-type behavior changes conformers | 5+ lattice packages' `Package.swift` |
| SE-0499 (`Hashable & ~Copyable`) | unavailable — `Hash.Protocol` is the move-only key bound (R1) | Implemented (Swift 6.4): decide the convergence (alias/bridge/migrate); keep the key bound single-pointed until then | set/dict/hash packages |
| SE-0474 yielding accessors | not on 6.3.2 (W4 Q5 probe: `yielding borrow/mutate` doesn't parse) | **Accepted**, impl "partially available behind `-enable-experimental-feature CoroutineAccessors`" — verify 6.4-STABLE actually ships the accepted spelling before planning the `_read`/`_modify` idiom migration; unlocks requirement-position mutate + upstream-`Container` borrow-subscript parity (R2 layer 3) | tower-wide idiom |
| `@unsafe` wave on ManagedBuffer pointer methods (632→64x) | n/a | new `unsafe` marker requirements under `.strictMemorySafety()` for ManagedBuffer consumers | 5 packages still using ManagedBuffer: dictionary core (2 files), executor job deque, memory-heap (pre-reshape), standard-library-extensions |
| stdlib `UniqueArray`/`RigidArray` arrival | absent | rider §1's re-check on #89698 merge | pre-check clean |
| SE-0516 `Iterable` outcome | active review, **closes 2026-06-18** | the single naming-alignment pass for the iteration lattice (R2 rec. 3) | iterator/sequence packages |

## 4 · Single-allocation fusion scoping note

**The upstream single-allocation trio is now complete** (one verified template per tower discipline):
`_ContiguousArrayStorage` (linear; archaeology Q4), `_DictionaryStorage`/`_SetStorage` (hashed,
`allocWithTailElems_3/2` + bitmap-driven drain; R1), `_DequeBuffer` (ring — literally a
`ManagedBuffer<_DequeBufferHeader, Element>` subclass with a two-segment drain deinit; R5). Userland
door: `ManagedBuffer`/`ManagedBufferPointer` admit `Element: ~Copyable` **on 6.3.2** (archaeology Q4).
In-house precedent: the pre-reshape `Memory.Heap` @ `27e3af9` shipped exactly this shape (ManagedBuffer
backing, class-deinit oracle, conditional Copyable).

**The R-6 interaction (the reason this note exists).** The R-6 miscompile fires on [`-O` + IKUR +
generic class box + nested-generic `~Copyable` struct **stored field**]. A fused box is shaped
differently: POD header fields + **tail-allocated elements** (not a stored struct field) + a drain
deinit. Hypothesis (unverified): the omission shape may not arise at all in the fused form — and is
moot anyway, because the drain deinit IS the mitigation (R-5/[MEM-SAFE-028]) and tail elements are
manually managed (never destroyed by field-walk). **Spike recipe (≤1h, run before any fusion design
reliance)**: add shape 13 to `Experiments/cow-box-deinit-omission-miscompile` — ManagedBuffer-subclass
box + IKUR + `~Copyable` tail elements + drain deinit, `-O` oracle both ways (with/without the drain).
**Standing constraints unchanged**: 2-alloc is ratified; fusion is a future, non-breaking, internal,
measurement-gated option; the layer-collapse tension (PROPOSAL §1.2 footnote ¹ — "the class IS the
memory") still applies; the 64x `@unsafe` wave (§3) adds strict-memory-safety friction to the door.

## 5 · Consuming-into-escaping-closure watch

**Nothing upstream lifts the wall; it is normative, not a bug.** SE-0390's escaping-capture rule is the
source ("the compiler isn't able to statically know when the closure is invoked … so the captures must
always remain in a valid state"); SE-0429 is unrelated (no closure-capture content). The sanctioned
adjacent pattern is **SE-0528 `Continuation`** (Accepted with revisions) — whose motivation quotes the
exact 6.3.2 diagnostic the W4 sending-spike hit, and which explicitly defers the language fix: "If and
when Swift gains 'called once' closures…". Once-closures are unpitched (the 2016 attempt, SE-0073, was
**Rejected**; the 2024 forums thread has no core-team commitment). [Verified: 2026-06-10]

**Consequence (unchanged, now evidence-backed):** the W4 ruling stands — isolation-crossing ownership
transfer of move-only values is **structured `consuming sending` calls only**; `Task{}`-style
unstructured transfer stays off the table; design channel/executor handoffs accordingly (and note
SE-0528's `Continuation` is the upstream pattern for the callback corner — already on the institute's
6.4 adoption survey as the `Completion.Entry` convergence item). Watch trigger: a "called once"/`FnOnce`
closures pitch.

## Outcome

**Status: RECOMMENDATION.** Actions: (1) watch #89698 → run the §1 re-check on merge; (2) hold the R-6
draft (§2) ready — filing needs a fresh YES, and a day-of re-run; (3) treat §3 as the gate-bump
checklist skeleton (the 436-occurrence lifetime sweep and the two-flag SE-0503 check are the two items
nobody should rediscover late); (4) run the §4 shape-13 spike before any fusion design work; (5) no
action on §5 — the ruling stands, the watch is named.

## Residual (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| Fused-box R-6 behavior (§4 hypothesis) | **premise** for any future fusion work | Explicitly unverified; the shape-13 spike recipe is the mandatory pre-design step (≤1h, extends the existing Experiments package) |
| All §1/§3/§5 upstream statuses | premises | Live-verified 2026-06-10 (sweep agent, primary sources) |
| 6.4-stable contents (SE-0474 shipping state, flag gates) | direction | Verifiable only when 6.4 stabilizes — the dossier marks the check items |

## References

- PRs: swiftlang/swift#87521 (merged 06-04), #89696 (revert), **#89698 (re-land, OPEN, CI 2026-06-10)**;
  main HEAD `81b9ead` contents checks.
- Proposals (live-fetched): SE-0474 Yielding accessors (Accepted; `yielding borrow`/`yielding mutate`;
  `CoroutineAccessors` flag); SE-0503 Suppressed Default Conformances on Associated Types With Defaults
  (Accepted; `Features.def:289` vs `:464` two-flag nuance); SE-0390 (the escaping-capture rule);
  SE-0429 (unrelated — verified); SE-0528 Continuation (Accepted with revisions; quotes the diagnostic);
  SE-0073 (Rejected, 2016); SE-0499; SE-0516 (closes 06-18).
- Local: `Experiments/cow-box-deinit-omission-miscompile/` (`2e2f7f1`, `113c711`; MinimalRepro + shapes
  incl. 11–12); @_lifetime counts (194 files/436 occurrences, grep 2026-06-10); ManagedBuffer-consumer
  census (5 packages); collision pre-check (clean); `PROPOSAL-tower-perfected-design.md` §1.2¹/§1.4;
  `[MEM-SAFE-028]`; the R1–R5 companion docs.
- Forums: t/74485 (once-callable closures), t/68118 (async closure capture workaround), SE-0474
  acceptance t/80273.

### Verification

[RES-020]: the four watch items were established by a dedicated sweep agent against primary sources
(PR API states, raw proposal texts, Features.def, forums threads) on 2026-06-10; local counts and the
Experiments-package state re-derived first-hand the same day.
