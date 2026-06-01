---
date: 2026-06-01
session_objective: Finish the Set.Ordered ×16 fan-out's protocol-stack consequences end-to-end as a sole-operator program — re-platform the trees onto institute iteration, land Collection.Protocol refines Iterable, drop the duplicate span-iterator protocol, and complete the tagged-collection consumer tail across the swift-primitives ADT stack.
packages:
  - swift-primitives/swift-array-primitives
  - swift-primitives/swift-collection-primitives
  - swift-primitives/swift-sequence-primitives
  - swift-primitives/swift-tree-keyed-primitives
  - swift-primitives/swift-tree-n-primitives
  - swift-primitives/swift-tree-unbounded-primitives
  - swift-primitives/swift-graph-primitives
  - swift-primitives/swift-pool-primitives
  - swift-primitives/swift-byte-parser-primitives
  - swift-primitives/swift-input-primitives
  - swift-primitives/swift-parser-primitives
status: pending
---

# Finish the Fan-Out — Collection.Protocol: Iterable refine edge + duplicate-iterator drop + .Indexed wrapper removal

## What Happened

Session objective per `HANDOFF-trees-collection-sequencer.md`: own and finish the entire remaining "finish the fan-out" program (9 Pieces, Decisions D1–D6 locked) as a sole operator. A `/quick-commit-and-push-all` ran first, so all state was re-derived from origin/disk per the handoff's pre-flight instruction.

The program landed end-to-end. 11 packages changed across 23 commits, all pushed, all working trees clean at closure. Per-piece:

- **Piece 7a** (array `9c226f5`): relaxed `Array` + `Array.Fixed` `Memory.Contiguous.Protocol` + `Iterable` from `where Element: Copyable` → `~Copyable`. Empirically confirmed **D4** (the memory→Iterable bridge `Memory.Contiguous+Iterable.swift` was already `~Copyable`-relaxed — "RELAXED (D4)" comment — so the refine edge has no Copyable wall). 173 green debug+release.
- **Piece 4** (byte-parser `933a473`): dropped the degenerate `Array<Byte>.Indexed<Byte>` → `Array<Byte>`. 26 green.
- **Piece 2** (graph `6273980` re-point, `402f443` migration, `70de836` dep cleanup): (2a) BFS/DFS conformers re-pointed off the duplicate `Sequence.Iterator.Protocol` → canonical `Iterator.Chunk.Protocol`; (2b) `Graph.Sequential.storage` → `Tagged<Tag, Array<Payload>>` bridge, scratch arrays → `Array.Fixed` + call-site `.retag(Element.self)`. §A9 `.disabled(if:)` guards untouched.
- **Piece 3** (pool `3930d21`): `Pool.Bounded.entries` → `Tagged<Slot, Array<Entry>.Fixed>` — read-only bridge sufficed because `Ownership.Slot` is a `final class` (mutation reaches heap interior through the reference). 61 green debug.
- **Piece 5** (array `80df5eb`): deleted `Array.Indexed` (3 files) + `Array.Fixed.Indexed` (3 files). Zero remaining wrapper consumers workspace-wide.
- **Piece 1** (tree-keyed `8866f92`, tree-unbounded `60c0a1c`, tree-n `b336f5f`): scalar iterators re-pointed to canonical `Iterator.Protocol` (stripped bolted-on `nextSpan`); order-views gained `Iterable` (via `Iterator.Materializing<scalar iterator>`) + `Sequenceable`; dropped `Swift.Sequence`; migrated test consumers (`Swift.Array(view)` → `view.collect()`). 93 / 112 / 40 green debug+release. Hand-written per-order scalar iterators kept per GR3.
- **Piece 6** (sequence `41bdc56`, parser `bd19a90`, input `fccd6da`): deleted the duplicate `Sequence.Iterator.Protocol`; re-pointed sequence SLI `Swift.Span.Iterator` ×2 + `Sequence.Borrowing.Protocol`'s associatedtype bound (kept Borrowing — used by `Sequence.Span`); re-pointed parser/input test fixtures. 160 / 153 / 44 green.
- **Piece 7b** (collection `3cc21cc`): the refine edge — `public protocol Collection.Protocol: Iterable, ~Copyable`. Deleted `Collection.ForEach` (→ inherited `Iterable.forEach`); kept `Collection.Indexed` (B2 delete deferred — it has `~Copyable`-element conformers and is the `~Copyable`-safe index root); made test-support fixtures Iterable. 20 green debug+release.
- **Piece 9** (verify): residual grep clean (no `Sequence.Iterator.Protocol`, no `.Indexed`/`.Indexed<>` forms, no `Collection.ForEach`); downstream build sweep across all 9 consumers green; test sweep green on clean builds.

**Two verification-caught fixes beyond the recipe.** (1) A real compile error (`'Array<Element>.Small' does not conform to protocol 'Sequenceable'`): the refine edge cascades through `Collection.Access.Random: Collection.Bidirectional: Collection.Protocol` to `Array.Small` + `Array.Static`, which were `Iterable where Element: Copyable` but conform `Collection.Bidirectional where Element: ~Copyable`. The 7a enumeration captured only *direct* conformers and missed these *transitive* ones. Fixed by relaxing both to `~Copyable` over their existing `~Copyable` spans (array `222a92c`). (2) Redundant empty `extension X: Iterable {}` on the unconditional fixtures (`TestCollection`, `Parser.Test.Bytes`) — they now inherit Iterable via the refine edge; removed as cleanup.

**A §A9 escalation raised then retracted.** The *incremental* test sweep showed input + parser SIGSEGV/SIGBUS with a backtrace pointing at the `Collection.Protocol.subscript.read` witness thunk — and the refine edge had just added Iterable's suppressed associatedtype to `Collection.Protocol`, so §A9 (the known Swift 6.3.2 `SuppressedAssociatedTypes`/Tagged-metadata codegen SIGSEGV, fixed 6.4+, already gating graph) was a plausible cause. I raised an escalation. A clean rebuild (`rm -rf .build`) then passed parser **153 green**, input 44, tree-keyed 93 — the crashes were **stale incremental-build artifacts** from `swift package update` after a large upstream change, not §A9. I retracted the escalation and corrected the misleading parser rationale comment + commit (`21338ee`).

**Surfaced but not fixed (pre-existing, out of arc scope).** (a) pool `swift test -c release` — 5 unguarded `onEnqueue` (`#if DEBUG`) refs; (b) parser `swift test -c release -O` SIL crash on `Digit.parse`, reproduced on a fresh `git worktree` at HEAD (smells like a toolchain/SIL bug, not institute code); (c) graph full-suite "Nodes iteration" SIGSEGV (§A9 buffer-Escapable, OPEN, suites stay `.disabled(if:)`-guarded); (d) **tree-unbounded `forEachPostOrder`/`removeSubtree` single-stack subtree-drop bug** — silent data loss in a shipped container (`0→[1,2], 1→[3,4]` should yield `[3,4,1,2,0]`, yields `[2,0]`); the new iterators are confirmed correct, so the bug is in the pre-existing single-stack traversal. (b)+(a) are being batched and (d) dispatched as focused follow-ups this session; (c) needs no new action.

**Handoff cleanup** (per [REFL-009]) — see the dedicated section below.

## What Worked and What Didn't

**Worked**:
- **The 7a/7b split was the load-bearing sequencing decision.** The handoff's suggested waves put Piece 7 (the refine edge) in Wave 1 parallel with everything else. That is unsafe as-stated: `Array.Indexed` is a `Collection.Protocol` conformer that is *not* Iterable, and it is a Piece-5 *delete* target. Landing `Collection.Protocol: Iterable` while `Array.Indexed` still existed would break array-primitives. Splitting Piece 7 into 7a (additive `~Copyable` relaxation, early) and 7b (the refine edge, terminal — after the Piece-5 deletion) resolved it. The deliverable is identical; only the interdependency ordering changed. This is exactly the "sequence the interdependencies yourself" the handoff asked for.
- **Empirical D4 confirmation up front** (reading the memory→Iterable bridge on disk and seeing the `~Copyable` relaxation already in place) de-risked the arc's stated #1 risk before any tree work started. The Materializing path never hit the Copyable wall.
- **Parallel subagent fan-out** for the disjoint consumer pieces (byte-parser, graph-2b, pool, the three tree packages) with the proven re-point recipe + escalation valves. The terminal deletions (5, 6, 7b) and the architectural refine edge I drove directly.
- **The clean-build re-verify caught my own escalation.** The §A9 retraction is the session's strongest signal — the escalation was killed by `rm -rf .build`, the record corrected, the whole thing disclosed.

**Didn't work**:
- **I escalated the §A9 crash before clean-building.** `feedback_clean_build_before_compiler_limitation_claim` is an existing memory rule, and the immediately-preceding cause (`swift package update` after a major upstream protocol change) is the textbook stale-incremental-build trigger. The plausible §A9 backtrace + the freshly-landed suppressed-associatedtype edge made the compiler-bug hypothesis *feel* well-grounded, which is precisely when the cheap mechanical check should fire first. The escalation cost a round-trip; a `rm -rf .build` would have pre-empted it in one command.
- **The transitive-conformer gap (Array.Small/Static) was an enumeration miss, not an analysis miss.** I enumerated direct `Collection.Protocol` conformers for 7a but did not walk the refinement chain to its transitive leaves. The compiler caught it (a green-build gate, working as intended), but a chain-walk at enumeration time would have folded it into 7a instead of a follow-up fix commit.

## Patterns and Root Causes

### Pattern 1: A refine edge is a whole-subtree obligation, not a direct-parent obligation

Adding `protocol P: Q` does not obligate *P's conformers* to satisfy Q — it obligates *every type that conforms to anything refining P, transitively*. `Collection.Protocol: Iterable` cascaded down `Collection.Access.Random: Collection.Bidirectional: Collection.Protocol`, so `Array.Small` and `Array.Static` — which conform only `Collection.Bidirectional`, never naming `Collection.Protocol` directly — inherited the Iterable requirement. The mental model "enumerate the conformers of the protocol I'm editing" is one level too shallow; the correct model is "enumerate the conformers of the *transitive closure of refinements* of the protocol I'm editing."

The root cause is that protocol refinement in Swift is a DAG, and a new super-protocol edge propagates requirements *up the refinement arrows to every leaf*, while the author's attention naturally rests on the single node being edited. The compiler is a reliable backstop (it cannot miss a transitive non-conformance), but a refinement-chain walk at enumeration time turns a follow-up fix into a same-piece edit. This belongs in the iteration/collection design doc as a procedure: before adding a super-protocol to a base protocol, `grep` the refinement chain (`: Collection.Protocol`, then `: Collection.Bidirectional`, then `: Collection.Access.Random`, …) and enumerate conformers at *every* level.

### Pattern 2: A sibling-typed generic argument named identically to an associatedtype binds to the associatedtype

The Materializing template (`@_implements(Iterable, Iterator) typealias IterableIterator = Iterator.Materializing<Iterator>`) fails with a circular reference when the inner `Iterator` is written bare, because inside the `Iterable` conformance the name `Iterator` resolves to *the associatedtype being defined*, not the sibling struct `…Order.Post.Iterator`. The fix is full qualification: `Iterator.Materializing<Tree<Element>.Keyed<Key>.Order.Post.Iterator>`. This is a name-resolution shadowing trap specific to the institute's `Nest.Name` convention, where the scalar iterator type is conventionally *named* `Iterator` and the protocol's associatedtype is *also* `Iterator` — the two collide exactly at the conformance site. It is a recurring gotcha for every generator-style type adopting `Iterable` via Materializing (trees, bit-vectors, any non-span source), and belongs in the unified-iteration design doc's Materializing-template section as an explicit "fully-qualify the source iterator" warning.

### Pattern 3: A plausible mechanism backtrace is not evidence of that mechanism — the cheap refutation comes first

The §A9 escalation is a live-fire instance of a rule I already hold. What made it instructive is *why* the rule was hard to apply in the moment: the conditions genuinely matched a compiler bug — a known SIGSEGV in the exact codegen path (suppressed-associatedtype witness thunks), freshly triggered by the exact edge I'd just added (Iterable's suppressed associatedtype onto Collection.Protocol), with a backtrace pointing at the matching thunk. Every indicator aligned. But "every indicator aligns with hypothesis A" is *also* true of hypothesis B (stale incremental build) whenever B can produce the same crash — and a stale witness table from a half-rebuilt `Collection.Protocol` produces exactly this signature. The two are observationally indistinguishable until you clean-build. This is the same structure as the 2026-05-22 `Package.resolved` misdiagnosis (a stale dependency revision is observationally indistinguishable from a compiler overload-resolution bug until you inspect the resolved revision): in both cases a *stale-build-state* hypothesis and a *compiler-bug* hypothesis are indistinguishable from symptoms alone, the stale-state check is one cheap command, and the compiler-bug investigation is expensive. The rule generalizes: when symptoms match a compiler/toolchain bug, the *first* action is the cheap refutation of the stale-state alternative (`rm -rf .build` for incremental staleness; `Package.resolved` vs upstream HEAD for dependency staleness), never the expensive characterization of the bug.

## Action Items

- [ ] **[doc]** unified-iteration-design.md: add a "refine-edge transitive-conformer enumeration" procedure — before adding a super-protocol to a base protocol (e.g. `Collection.Protocol: Iterable`), walk the full refinement chain and enumerate conformers at every level, not just direct conformers of the edited protocol. Provenance: Array.Small/Static transitive gap, this session.
- [ ] **[doc]** unified-iteration-design.md: in the Materializing-template section, warn that the source iterator inside `Iterator.Materializing<…>` MUST be fully-qualified (e.g. `Tree<Element>.Keyed<Key>.Order.Post.Iterator`) — a bare `Iterator` shadows to the associatedtype being defined and produces a circular reference. Provenance: all three tree packages, this session.
- [ ] **[package]** swift-tree-unbounded-primitives: document the pre-existing `forEachPostOrder`/`removeSubtree` single-stack subtree-drop data-loss bug in `Research/_Package-Insights.md` (silent loss; new iterators are correct; the defect is in the single-stack traversal). Dispatched as a focused fix this session.

## Handoff Cleanup (per [REFL-009])

Workspace handoff scan: 5 `HANDOFF-*.md` files at root; 2 in this session's cleanup authority, 3 out.

| File | Triage outcome |
|------|----------------|
| `HANDOFF-trees-collection-sequencer.md` (this session's source program) | All 9 Pieces verifiably complete (committed + pushed + clean-build green); `## Constraints / Ground Rules` section present but no literal `### Supervisor Ground Rules` block, all constraints verified end-to-end (GR2/GR3/§A9/no-redo/verify-against-disk) → no [SUPER-011] gate → **deleting** per [REFL-009] |
| `HANDOFF-trees-collection-sequencer-PROGRESS.md` (this session's durable progress record) | Authored this session; "✅ STATUS: COMPLETE"; all content (commits, verify results, surfaced issues, §A9 correction) preserved in this reflection → **deleting** per [REFL-009] |
| `HANDOFF-bit-primitives-domain-decomposition.md` | Out of authority (not authored or worked this session); modified today → in-flight → **left unchanged**, no annotation per [REFL-009a] |
| `HANDOFF-post-cascade-cleanup.md` | Out of authority; modified today → in-flight → **left unchanged** |
| `HANDOFF-set-ordered-tagged-insert-crash.md` | Out of authority; modified today → in-flight → **left unchanged** |
