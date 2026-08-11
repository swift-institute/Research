---
date: 2026-04-16
session_objective: Investigate sync→actor work delivery patterns; document findings; spike Chase-Lev deque for the work-stealing executor design
packages:
  - swift-executors
  - swift-executor-primitives
  - swift-storage-primitives
  - swift-memory-primitives
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Chase-Lev Spike and the Premature-Primitive Trap

## What Happened

Session began as a small question — "is it possible to sync enqueue to a
swift actor" — and grew into a multi-stage research initiative spanning
two repos. The arc:

1. **Sync→actor handoff pattern.** Walked through `Task` / `Task.immediate`
   / direct `enqueue(UnownedJob)` / channel-based options. Surveyed
   swift-executors and swift-io to ground the answer in their existing
   pattern. Concluded: channel-based via `Async.Channel.Unbounded`, matching
   `IO.Event.Actor`'s precedent. Wrote DECISION research note + first
   `.docc` catalogue for swift-executors.

2. **Work-stealing scheduler research.** Identified 8 draft research
   directions for swift-executors v1 (combining stdlib gaps from
   swiftlang/swift with academic theory). User asked to start with
   work-stealing. Wrote IN_PROGRESS Tier 2 research note covering deque
   ABI (Chase-Lev), victim selection, idle policy, pool sizing,
   actor-isolation interaction. Initial recommendations on all five
   sub-questions.

3. **Chase-Lev deque spike (4 variants).** V1 single-threaded smoke. V2
   contended with `UnsafeMutableBufferPointer<Int>`. V3 with
   `Memory.Inline<Int, 256>` (after user pointed me at
   `/ecosystem-data-structures`). V4 with `ManagedBuffer<Int, Int>`
   (after user pointed me at swiftlang/swift stdlib). All four PASS on
   Apple Swift 6.3 / macOS 26 arm64. Count reconciliation
   (`taken + stolen == pushed`) catches both losses and duplicates;
   confirmed correctness.

4. **Storage modularization research note.** Initially proposed
   `Storage<E>.Untracked.Heap` as a "missing cell." User pushed back —
   "do we NEED UnsafeMutableBufferPointer?", then "did you check
   storage-primitives and buffer-primitives?", then "Storage<E>.Untracked.Heap
   seems entirely wrong." After the third nudge, recalibrated: closed the
   research note as DECISION (status quo, no new primitive) and saved a
   project memory capturing that ManagedBuffer is vestigial in the
   ecosystem.

5. **Handoff for next session.** Sequential HANDOFF.md at
   `/Users/coen/Developer/HANDOFF.md` captures state and the 7 remaining
   draft research topics in priority order.

## What Worked and What Didn't

**Worked:**

- The research-process → experiment-process → ecosystem-consultation →
  research-note-update chain. The Chase-Lev spike's 4-variant structure
  (each a separate hypothesis per [EXP-009] / [EXP-011a]) was high-leverage:
  V1 validated the algorithm, V2 the concurrent contention, V3 ecosystem
  primitive compatibility, V4 stdlib precedent. Each variant answered one
  question cleanly.
- Citing stdlib file:line systematically (`_ContiguousArrayStorage` at
  `ContiguousArrayBuffer.swift:132-308`, `Atomic._address` at
  `Synchronization/Atomics/Atomic.swift:24`, etc.) gave the recommendations
  empirical anchoring. The user's "stdlib is locally available" nudge was
  the right correction for not consulting it earlier.
- Saving `project_managedbuffer_vestigial.md` as a project memory captured
  a non-obvious architectural intent that future sessions will need.
  Without it, the same trap recurs.

**Didn't work:**

- **Twice over-proposed new ecosystem primitives.** First
  "Memory.Contiguous.Mutable<E: BitwiseCopyable>" (wrong layer entirely).
  Then "Storage<E>.Untracked.Heap" (wrong framing — symmetric-completeness
  thinking applied to curated taxonomies). Each required user pushback to
  catch.
- **Did not consult `/ecosystem-data-structures` until the user pointed
  at it.** The skill auto-loads its description but I had been making
  recommendations without invoking it. The catalog was the missing
  consultation step.
- **Did not consult swiftlang/swift stdlib until the user pointed at it.**
  The local stdlib checkout is canonical evidence; my earlier "this
  primitive is missing" claims should have been preceded by "does stdlib
  itself have a primitive for this, and if not, what does it use?"
- **Iterative pushback as a defect signal — caught late.** The user
  escalated three times on the storage question before I recalibrated.
  Each pushback I treated as "the next layer down has the right answer"
  rather than "the framing is wrong."

## Patterns and Root Causes

**The premature-primitive trap.** When one consumer (Chase-Lev) needed a
shape that didn't have a single-named-type in the ecosystem, I twice
reached for "add a new primitive" rather than "use what exists, even
imperfectly." The trap has a specific shape:

1. Identify a use case
2. Survey the ecosystem; observe no single type fits perfectly
3. Notice a "symmetric gap" — e.g., "Memory.Buffer has Mutable, why
   doesn't Memory.Contiguous?"
4. Propose adding the missing cell
5. Justify with "the ecosystem aims for completeness"

Step 5 is the failure point. Curated taxonomies are *not* orthogonal grids
awaiting completion. They are intentional sets of named useful patterns,
where missing cells often reflect deliberate non-existence (the cell
either is covered by a different layer's primitive, or has no consumer
demand justifying a new name). Adding the cell on one consumer's behalf
is *premature primitive* — the abstraction has a name but no second
consumer to validate that the abstraction is the right shape.

The stdlib's own pattern proved the point: `_ContiguousArrayStorage` is
ad-hoc per-container — Array doesn't share its tail-allocated typed
storage with anything else. swift-storage-primitives' `Storage.Heap` /
`.Pool` / `.Split` *also* use ManagedBuffer per-discipline. The ecosystem
*already* lets concurrent containers like Chase-Lev do the same: own your
ManagedBuffer wrapping. No new primitive layer needed; that's how layered
architecture is supposed to work.

**Wrong-layer reasoning as a recurrent shape.** The Chase-Lev storage
question got framed at three different layers in succession (Memory →
Storage → "concurrent collection primitive backed by ManagedBuffer"). The
user pushed back at each of the first two. The recurring failure mode:
when the right answer is "this isn't where the abstraction lives," I
default to "let's add an abstraction at the layer I'm currently looking
at." Each layer-shift was a re-anchoring, not a re-questioning.

**Iterative pushback signals framing failure, not detail failure.** When
the user escalates corrections, the next correction is rarely about the
detail under discussion. It's about the frame the discussion is happening
in. Three pushbacks in a row — "are you sure?", "did you check X?", "did
you check Y?" — should have been read as "step out of the frame," not
"keep refining within it." I read them as the latter for too long.

**The ecosystem-data-structures skill's description auto-loads but the
skill itself doesn't fire until invoked.** The description tells me a
catalog exists; the skill body provides the catalog. I had access to the
description and made recommendations without invoking. The user's "see
also /ecosystem-data-structures btw" was a workaround for the deeper
problem: there's no convention enforcing "consult catalog before proposing
new primitives."

## Action Items

- [ ] **[skill]** ecosystem-data-structures: Add a "Before proposing a
  new primitive" gate at the top of the skill. Statement: when a
  recommendation involves *adding* an ecosystem primitive (Memory,
  Storage, Buffer, or Collection layer), the skill MUST be consulted
  first; the catalog plus composition with existing primitives MUST be
  shown not to cover the use case before a new primitive is proposed.
  Cross-reference the premature-primitive failure mode.
- [ ] **[skill]** research-process: Add a "Premature Primitive" anti-pattern
  under [RES-005] or as a new requirement. Statement: Tier 2+ research that
  proposes a *new* ecosystem primitive MUST include a "Why not compose
  existing primitives?" section AND a "Is there a second consumer?" check.
  Symmetric-completeness reasoning ("this cell is empty in the orthogonal
  grid") is explicitly disallowed as a sole justification. Cite this
  reflection as provenance.
- [ ] **[research]** swift-memory-primitives: Scope the ecosystem-wide
  ManagedBuffer-replacement project. What native primitive would replace
  ManagedBuffer's typed-tail-allocated-memory contract? Which existing
  Storage disciplines and ad-hoc consumers would migrate? What's the
  cost/benefit? Out of scope this session per the vestigial-ManagedBuffer
  memory; warrants its own Tier 2 research note when prioritized.
