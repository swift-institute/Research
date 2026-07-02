---
date: 2026-06-12
session_objective: Run the Memory.Foreign research brief end-to-end — design doc v1.0.0 through v1.1.2, principal-review absorption, adversarial package review, recycle-channel prototype (Item C), and the read-only-column investigation (Item B)
packages:
  - swift-memory-foreign-primitives
  - swift-buffer-ring-primitives
  - swift-async-primitives
  - swift-span-primitives
  - swift-memory-map-primitives
  - swift-storage-primitives
  - swift-store-primitives
status: processed
processed_date: 2026-07-02
triage_outcomes:
  - type: no_action
    description: "Guarded-deinit memory-safety proposal: merged into the sibling entry 2026-06-12-memory-foreign-arc-comparison-to-shipped-regime.md's identical proposal per [REFL-PROC-002a] (dual provenance recorded there)."
  - type: skill_update
    target: research-process
    description: "Proposal collected (recommend KEEP, small fold into [RES-019] step-0): source-shape sweep — when the question includes 'does X already exist', grep Sources for candidate type shapes, not only Research/ docs (Memory.Map found shipped after the doc treated the owning mapped envelope as hypothetical)."
  - type: no_action
    description: "Async.Channel sending-seam adoption research topic: already recorded — the reflection itself states both constraints are written into memory-foreign-and-memory-protocol.md Residual #2 for sockets 2B+, and the sockets/async arc owns the consumer chain (project_memory_foreign_arc). A separate research doc would duplicate the parent doc's residual."
---

# Memory.Foreign Arc — the Third Ownership Regime

## What Happened

One session carried the full arc. (1) `/research-process` on the dispatched brief: tower seam sources read before the corpus agents (which surfaced stale pre-W4 claims in older docs — source governed), the `foreign-region-tower-instantiation` probe (Storage tier CONFIRMED zero-change over the existing `Memory.Region` seam; Buffer tier REFUTED — heap same-type pins, diagnostics captured), five parallel primary-source verifiers per [RES-020] (three claim corrections: DPDK `RTE_MBUF_F_EXTERNAL` rename, SwiftNIO 2.96.0's `@_spi` allocator-vtable adoption init, SE-0446/0447/PR#2305 statuses), doc v1.0.0 committed `352874b`. (2) Principal review delivered two binding rulings — P1 (no load-bearing Sendable; region-based `sending` per [MEM-SEND-010/012/013]) and P2 (Span types over `Unsafe*`) — folded as v1.1.0 with the V5 sending probe (positive + negative confirmed under `.strictMemorySafety()`). (3) The principal overrode the creation gate; `swift-memory-foreign-primitives` was adversarially reviewed (five relayed deltas verified; five proposed fixes, all later landed at `02d9f13` including Witness→Census per [PKG-NAME-015]); doc v1.1.1 `2a883c4`. (4) Round-2 dispatch: Item C `foreign-recycle-channel` experiment (`e226246`, pushed, private repo) and Item B `read-only-foreign-column.md` + the v1.1.2 rider (`f087306`), with Item D's transport-seam audit consumed and its residual proven additive in the experiment.

HANDOFF scan per [REFL-009]: 7 files found at the workspace root (`HANDOFF-bit-primitives-domain-decomposition`, `HANDOFF-derive-for-free-capability-composition`, `HANDOFF-parser-release-sil-crash-{UPSTREAM-DRAFT,VERIFICATION,investigation}`, `HANDOFF-post-cascade-cleanup`, `HANDOFF-set-ordered-tagged-insert-crash`) — all out-of-authority (not authored, not worked, no completion signals encountered this session); 0 deleted, 0 annotated, 7 left untouched. The `.handoffs/` tower records are the seat's in-flight files — no-touch per [REFL-009a]. No `/audit` ran this session ([REFL-010] n/a). This arc's own state needs no handoff: the two research docs, the package, and the two experiments are the durable record.

## What Worked and What Didn't

**Worked.** Reading the seam sources before consuming corpus summaries caught three stale brief premises and two stale agent-relayed doc claims at zero cost. Probe-before-doc retired the central design risk and split the payoff thesis precisely (CONFIRMED/REFUTED per tier). The parallel primary-source verification earned its dispatch cost three times over — and the most load-bearing single datum was a *negative* (NIO's allocator-vtable shape, under which per-buffer finalizers are inexpressible). The review→fix loop converged in one round each time; every proposed fix was adopted unchanged.

**Didn't.** v1.0.0 shipped a `@Sendable`-finalizer + `@unchecked Sendable` posture and an `UnsafeMutableRawBufferPointer` surface that already-ratified skill law prohibited — P1 and P2 arrived as review *corrections* when they were discoverable as design *inputs* ([MEM-SEND-012/013] existed; the Memory.Buffer→Span.Raw retype was in live memory). v1.0.0 also overclaimed "uniqueness replaces the refcount … nothing is lost" even though my own DPDK verifier had flagged the refcnt living in the *shared* info — the sharing axis was in my evidence and I didn't read it back. Q4 listed the public Bounded init as non-allocating without reading its body (the seat caught it; one [RES-023] lapse in an otherwise verified doc). Confidence note: I expected the additive `receiveSending()` retrofit to be *rejected* by the region checker; it compiled and ran — the surprise direction worth remembering.

## Patterns and Root Causes

**Doctrine consultation fires too late.** The post-commit memory scan ([REFL-006]) is positioned after implementation; both P1 and P2 misses happened at *design-doc drafting* time. The pattern: when a doc proposes a type surface, the posture-class rules (Sendable/sending, pointer vocabulary, unsafe marking) should be swept from memory + skills *before* the sketch is drawn, not discovered in review. Same family as the post-commit scan — different firing point. (Deferred as a fourth action item under the [REFL-004] cap; the P1/P2 worked example is recorded here for when it's picked up.)

**The guarded-deinit shape is now an ecosystem idiom, not a workaround.** `discard self` requires trivially-destroyed stored properties (Swift 6.3.2), so any closure-bearing `~Copyable` needs the Optional-field + nil-in-consuming-op + guarded-deinit shape. Three shipped types now carry it independently: `Completion.Entry` (continuation), `Memory.Foreign` (finalizer), `Memory.Map` (region + unmap witness — evolved the same shape before the wall was named). Convergent evolution across three packages is the signal that this is the canonical pattern and deserves a name and a rule. Companion spellings discovered the same day: `sending` alone does not specify ownership for `~Copyable` parameters (`consuming sending` is the boundary form), and a `nonisolated(nonsending)` call's non-Sendable result is provably disconnected in a wrapper scope — which makes `sending` results retrofittable *additively*, a general migration pattern for seams whose declarations can't be touched yet.

**Shipped source is prior art the doc-grep misses.** Item B's decisive input was that `Memory.Map` already *is* an owning RAII envelope — something my own v1.1.0 taxonomy had presented as a hypothetical composition, because [RES-019]'s step-0 greps the Research corpus, not type shapes in Sources. "Does X already exist?" questions need a source-shape sweep alongside the doc sweep.

**Numbers shape the next arc.** Drop-site deinit (assertIsolated, both domains) plus the rejected direct-pool-touch probe make recycle closures isolation-agnostic *by construction*, and the ~4.7µs/buffer per-buffer channel tax (vs 3.1µs direct) says hot paths want batched (`send(contentsOf:)`) or ring-local recycling. Both constraints are now written into the parent doc's Residual #2 for sockets 2B+.

## Action Items

- [ ] **[skill]** memory-safety: codify the guarded-deinit escape hatch as the canonical pattern for closure-bearing/non-trivially-destroyed `~Copyable` types while the `discard self` wall stands — Optional field, nil-in-consuming-op, guarded deinit; cite the three shipped instances (`Completion.Entry.swift:102-131`, `Memory.Foreign.swift`, `Memory.Map.swift:94-97`) and the V5 diagnostic ("can only 'discard' type … trivially-destroyed stored properties"), plus the `consuming sending` boundary spelling for `~Copyable` params.
- [ ] **[skill]** research-process: extend [RES-019] step-0 with a source-shape sweep (grep Sources for candidate type names/shapes, not only Research/ docs) when the question includes "does X already exist" — provenance: `Memory.Map` found shipped after the parent doc treated the owning mapped envelope as hypothetical.
- [ ] **[research]** Async.Channel sending-seam adoption: land `sending` on `Receiver.receive()` (or ship the proven additive `receiveSending()`) and define the policy for sending-shaped results on future buffer-vending capabilities (`Completion.Actor.submit`) — carries the `foreign-recycle-channel` compile + runtime receipts and the Item D audit table.
