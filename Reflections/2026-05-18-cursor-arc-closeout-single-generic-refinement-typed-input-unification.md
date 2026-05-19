---
date: 2026-05-18
session_objective: Orchestrate cursor-abstractions arc closeout (Choice C → implementation → single-generic refinement) and dispatch typed-input unification (Item 2 / D5); supervisor-mode session reviewing four subordinate dispatches end-to-end
packages:
  - swift-primitives/swift-cursor-primitives
  - swift-primitives/swift-byte-primitives
  - swift-primitives/swift-byte-parser-primitives
  - swift-primitives/swift-binary-parser-primitives
  - swift-primitives/swift-text-primitives
  - swift-primitives/swift-lexer-primitives
  - swift-primitives/swift-input-primitives
  - swift-institute/Research
  - swift-institute/Experiments
status: pending
---

# Cursor Arc Closeout, Single-Generic Refinement, and Typed-Input Unification

## What Happened

Supervisor-mode session orchestrating four sequential subordinate dispatches across ~24 hours, each closing one architectural arc:

1. **Cursor Tier 3 research arc** (v1.0 → v1.2): produced an initial recommendation (Shape ι — full centralization preferred). Principal-side review identified three structural concerns (uneven duplication-elimination across Worlds, irreversible Tier 13 elevation, premature W3 placement). Recommendation inverted to v1.2.0 Shape γ (W2 unification only; Shape ι expansion deferred). Principal authorized Choice C (Shape γ now + Shape ι expansion committed as gated follow-on).

2. **Cursor implementation arc** (Phases 0-3): Phase 0 BENCH-011 hard gate passed with unexpected 20-100× Binary speedup; root-cause investigation attributed to legacy `public var position: Int` defect (resilient access through `@inlinable` mutating methods). cursor-primitives package landed at L1 Tier 6-8; Binary.Bytes.Input.View and Lexer.Scanner migrated to source-transparent typealiases/wrappers. Ecosystem build gate green across 7 packages.

3. **Single-generic Cursor reshape arc**: principal identified that the two-generic Shape A `Cursor<Storage, PositionTag>` was structurally redundant given `Byte: Ownership.Borrow.Protocol` conformance with `Borrowed = Byte.Borrowed`. Reshaped to `Cursor<DomainTag: Ownership.Borrow.Protocol>` with storage derived. Added `Text: Ownership.Borrow.Protocol` conformance in text-primitives with `typealias Borrowed = Byte.Borrowed`. BENCH-011 re-run showed parity vs the two-generic shape AND preserved the 20-100× legacy speedup. 7 commits across 6 repos.

4. **Typed-input unification arc** (HANDOFF.md Wave 1 Item 2 / D5): Phase 0 hard gate verified Binary.Bytes.Input's 5 extension files were 4-of-5 redundant with Input.Slice's existing surface; refactored `Binary.Bytes.Input = Byte.Input` (Option A pre-committed by principal per "older = older = refactor to match newer" steer). Phase 4 W3 centralization to cursor-primitives dissolved; Phase 4 reduces to W1 only.

Doc trail: cursor-abstractions-l1-ecosystem.md v1.0 → v1.7; byte-cursor-primitive-unification.md v1.0 → v1.3 (IN_PROGRESS, superseded by cursor-abstractions); cursor-shape-a-vs-three-worlds.md v1.0 → v1.2 (IMPLEMENTED); typed-input-unification.md v1.0.0 (DECISION).

## What Worked and What Didn't

**Worked**:

- **Phase 0 hard-gate discipline** caught defects pre-source-change in both implementation arcs. BENCH-011 surfaced the legacy `public var position: Int` perf defect. Typed-input Phase 0 surface-mapping caught the 4-of-5 redundant extension files before refactor began.
- **Subordinate empirical refutation of orchestrator-recommended architectural commitments** worked twice. The Tier 3 v1.1.0 Shape ι preferred recommendation was caught by principal review (three structural concerns); the single-generic redundancy was caught by principal observation post-Shape-A landing.
- **Multi-iteration with intermediate commits** preserved the analytical trail. cursor-abstractions doc went through 7 versions; each step is traceable in git + changelog. The "fast iteration with same-day commits" enabled three cursor shapes (Three Worlds → two-generic Shape A → single-generic) in ~36 hours without losing reasoning.
- **Pre-committing decisions at handoff-write time** saved round-trips. Typed-input Option A pre-commit ("Binary.Bytes.Input = Byte.Input") prevented the subordinate from re-deriving the canonical-home question.
- **Class-(c) escalation discipline** held. Subordinates surfaced `seek(to:)` API addition (cursor arc), 13-test `throws(any Swift.Error)` deferral (input-primitives lint pass), all with explicit rationale rather than silent absorption.

**Didn't work**:

- **The single-generic-Cursor redundancy should have been caught at Shape A v1.2.0 DECISION review**, not post-implementation. The principal asked "why not single-generic via Ownership.Borrow.Protocol?" only after the two-generic shape was already implemented and tested. At the v1.2.0 review moment, the single-generic shape was already deducible: Byte already conformed to Ownership.Borrow.Protocol; storage was therefore derivable from DomainTag. The two-generic shape's redundancy was visible-but-not-spotted by me in the review. Cost: one extra implementation iteration (~3 hours).
- **The Tier 3 v1.1.0 recommendation reached Shape ι (centralize everything) without adequately weighing tier elevation and reversibility.** The doc framed the decision space but the recommendation was structurally aspirational rather than principled-first. Principal pushback was the corrective.
- **v1.3.0 prior-art grep was ecosystem-only (swift-institute/Research/), missed per-package Research/.** Surfaced Binary.Cursor and the 2026-01-19 Lifetime Dependent Borrowed Cursors doc only after v1.3.0 was authored. Documented in the v1.3.0→IN_PROGRESS downgrade per [HANDOFF-013a] discipline.

## Patterns and Root Causes

**Pattern 1: Architectural-review depth has a "one level deeper" gap**. At every DECISION-grade architectural review moment, the natural disposition is to validate the *proposed* answer against the *enumerated* alternatives. But the missing question is "is there a simpler answer underneath this one?" The single-generic Cursor was the simplification underneath two-generic Shape A; both share the same Three Worlds finding, both produce identical runtime behavior, but the single-generic shape carries one less parameter at every call site. The two-generic answer was *correct given its framing*; it just had an unasked framing alternative. The discipline: at DECISION review, ask "what generic parameter could be derived from another?" "what type could be inferred from an existing protocol conformance?" "what alternative shape has the same observable behavior with less surface?"

**Pattern 2: Older-package-refactors-to-match-newer-architectural-insight, generalized**. The typed-input unification arc made this principle explicit. byte-primitives is newer (born from the 2026-05 byte arc); binary-primitives and binary-parser-primitives are older (2026-02). The older accumulated structural defects (Binary.Bytes.Input's hand-written struct duplicating Input.Slice; Binary.Bytes.Input.View's public-var-storage perf defect). The principled refactor direction is older → newer, NOT blend, NOT new direction. This generalizes: when two packages encode the same concept and one is newer, the newer is canonical until specific evidence refutes it. The pattern fires at any cross-package unification arc; codifying it shortens the directional-debate phase.

**Pattern 3: Fast iteration on architectural abstractions requires intermediate-state commitment**. Three cursor shapes in 36 hours (Three Worlds → two-generic Shape A → single-generic). Each iteration committed (research doc version bump + status transition + implementation if applicable). The temptation in fast iteration is to wait for the "right" answer before committing — but waiting loses the reasoning trail when a subsequent reader needs to understand why we didn't pick the earlier shape. The actual practice: commit at every coherent intermediate state, even if you anticipate further refinement. The trail through v1.0→v1.7 of cursor-abstractions IS the durable record of why current is current and not prior.

**Pattern 4: BENCH-011-style hard gates surface defects beyond their nominal purpose**. BENCH-011's nominal purpose was "verify no perf regression from generic specialization." Its actual yield was discovering a latent perf defect (public-var-storage) in legacy code that the migration accidentally fixed. The lesson: empirical probes are valuable for what they *don't* prove as well as what they do. The 20-100× speedup wasn't the cursor abstraction being magic; it was the legacy code having a fixable defect. Without the probe, we'd attribute the speedup to abstraction quality and miss the underlying ecosystem-wide pattern.

**Pattern 5: Choice C "commit-with-technical-gate-fallback" is a novel principal-disposition shape**. Distinct from binary approve/defer. The principal commits to an end-state (Shape ι expansion) while preserving a technical escape valve (BENCH-011 regression cancels the commitment). The commit creates forward momentum (subordinates can plan against the eventual end-state); the escape valve preserves correctness (if evidence contradicts the assumption, the commitment voids). This isn't the same as "approve conditionally" — conditional approve usually means "approve if conditions met"; Choice C is "commit now AND retain a void-clause grounded in objectively-measurable technical evidence." Worth recognizing as a pattern for future complex architectural commitments.

## Action Items

- [ ] **[research]** `swift-institute/Research/`: Ecosystem-wide audit of `public var` stored properties on structs with `@inlinable` mutating methods. The cursor migration's BENCH-011 surfaced a 20-100× speedup attributable to this defect class (resilient access through opaque getter/setter calls inside `@inlinable` methods). Audit scope: enumerate every L1 struct with the pattern; quantify exposure (which are in hot paths); produce a remediation plan before pre-1.0. Pattern source: legacy `Binary.Bytes.Input.View`'s `public var position: Int` defect.
- [ ] **[skill]** supervise: Add "look-one-level-deeper" discipline to DECISION-grade architectural reviews. At every DECISION transition (RECOMMENDATION → DECISION), the supervisor MUST ask three structural questions before authorizing: (a) can any generic parameter be derived from another via existing protocol conformance? (b) can any explicit type be inferred from an existing associated type or typealias? (c) does any alternative shape produce identical observable behavior with less surface? If any answer is yes, escalate to one-more-iteration before authorizing. Provenance: 2026-05-18 single-generic Cursor redundancy that should have been caught at Shape A v1.2.0 DECISION review.
- [ ] **[skill]** handoff: Add "refactor-older-to-match-newer" as a canonical directional steer for unification arc handoffs. When a unification arc has two candidate canonical-homes and one is newer (post-architectural-insight) and the other is older (pre-insight), the handoff SHOULD pre-commit the canonical direction (newer → canonical, older refactors to match) at handoff-write time. This generalizes Option A pre-commit from the typed-input arc to all cross-package unification handoffs. Saves a round-trip on the canonical-direction question.
