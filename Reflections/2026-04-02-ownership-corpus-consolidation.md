---
date: 2026-04-02
session_objective: Consolidate scattered ownership/memory-safety research and experiments into topic-based documents
packages:
  - swift-institute
  - swift-primitives
status: processed
---

# Ownership Corpus Consolidation: 22 → 4 Research Documents

## What Happened

User identified that research on ~Copyable, ~Escapable, sending, consuming, and
borrowing was scattered across ~40 research documents and ~50 experiments. Invoked
/corpus-meta-analysis with a focus on consolidation rather than just staleness
detection.

Executed [META-016] Consolidation Protocol across four topic clusters:

1. **ownership-transfer-conventions.md** — absorbed 9 documents covering sending,
   Sendable, ~Sendable, nonsending migration, non-Sendable strategy, callback
   redesign, rendering infrastructure, tagged types
2. **noncopyable-ecosystem-state.md** — absorbed 6 documents covering ergonomics,
   compiler state, transfer patterns, synchronization audit, deinit bug, CopyPropagation
3. **nonescapable-ecosystem-state.md** — absorbed 4 documents covering readiness,
   storage mechanisms, peek/Borrowed<T>, lifetime annotations (Swift 6.3)
4. **witness-ownership-integration.md** — absorbed 3 documents covering bifurcation
   theorem, Sendable removal, macro omission pattern

All 22 source documents marked SUPERSEDED with provenance. Both _index.md files
updated. Experiment consolidation (5 clusters, ~30 experiments) handed off via
HANDOFF-experiment-consolidation.md.

## What Worked and What Didn't

**Worked well**: Parallel agent extraction. Four agents read all source documents
simultaneously, each extracting findings organized by sub-topic. This produced
well-structured material for synthesis without sequentially reading 22 documents.

**Worked well**: Topic-based organization is dramatically clearer than the original
per-investigation scatter. The "Four-Tool Taxonomy" (sending vs Sendable vs @Sendable
vs no annotation) in ownership-transfer-conventions.md distills what took 9 documents
to develop.

**Confidence concern**: The consolidated documents omit some low-value details from
source documents (e.g., specific git commit hashes, line-by-line migration tracking).
This is intentional compression per [META-016] — the source documents are retained as
historical rationale — but a future reader might not find a specific detail without
checking the superseded source.

**Not attempted**: Experiment consolidation requires creating Swift packages that build.
Correctly handed off rather than attempting at the end of a long session.

## Patterns and Root Causes

The scatter pattern has a clear root cause: each investigation was written as a
standalone document at the time of discovery. This is correct per [RES-003] — research
starts as focused investigation. But the consolidation step ([META-016]) was never
triggered because the corpus never hit a review cycle where someone noticed the overlap.

The consolidation was tractable because the memory-safety skill had already absorbed
the *conclusions* into [MEM-*] requirement IDs. The research documents held the
*rationale and evidence* behind those conclusions. Consolidation preserved provenance
while eliminating the need to navigate 22 files to understand the ecosystem state.

This suggests a lifecycle pattern: investigation → skill absorption → research
consolidation. The skill absorption can happen incrementally (and did), but research
consolidation should be triggered when a topic cluster exceeds ~5 documents with
overlapping scope.

## Action Items

- [ ] **[skill]** corpus-meta-analysis: Add consolidation trigger threshold — when a topic cluster reaches 5+ documents with overlapping Questions, flag for consolidation during next sweep
- [ ] **[research]** Should stream-isolation research (stream-isolation-preserving-operators.md, stream-isolation-propagation.md) be consolidated with async-stream-sendable-requirement.md into a unified stream-concurrency document?
- [ ] **[package]** swift-institute: Process HANDOFF-experiment-consolidation.md to create 5 consolidated experiment packages
