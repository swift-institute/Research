---
date: 2026-04-15
session_objective: Resolve 28 audit findings across swift-executor-primitives (L1) and swift-executors (L3) by building missing ecosystem infrastructure bottom-up, then applying it.
packages:
  - swift-ordinal-primitives
  - swift-executor-primitives
  - swift-executors
  - swift-property-primitives
status: processed
processed_date: 2026-04-16
triage_outcomes:
  - type: skill_update
    target: existing-infrastructure
    description: "Added [INFRA-003a] Atomic<Ordinal.Protocol>.advance(within:) as canonical atomic round-robin primitive"
  - type: skill_update
    target: implementation
    description: "Added [PATTERN-054] Academic-grounding test for composition-over-new-type decisions"
  - type: no_action
    description: "[experiment] CAS vs FAA measurement — question captured in reflection Pattern section; defer experiment package creation to when the work is undertaken"
---

# Executor Audit Cleanup + Atomic<Ordinal.Protocol> Infrastructure

## What Happened

Session started as a three-phase audit cleanup per `HANDOFF-executor-audit-cleanup.md`: Cardinal stdlib integration, Property accessor adoption, mechanical cleanup. Mid-flight, two judgment-call reversals extended the scope:

1. **Typed count adoption (Phase 2b)** — initially deferred as "dependency sprawl for 4 internal expressions." User corrected: "we want to write clean code, and the deps allow us to do so." Added `swift-ordinal-primitives` + `swift-index-primitives` to swift-executors.

2. **`Atomic<Index<Kernel.Thread>>` + `advance(within:)`** — the 3-line mechanism (`wrappingAdd` + `Ordinal(raw)` + `%`) inside `enqueue()` read as mechanism, not intent. I proposed `Cyclic.Counter<Tag>`; user pushed back asking for academic grounding. Honest answer: composition, not a new construct. Final design: `Atomic<Tagged<Tag, Ordinal>>` with `advance(within:)` extension generic over `Ordinal.Protocol & AtomicRepresentable`. Three new files in `swift-ordinal-primitives/Sources/Ordinal Primitives Standard Library Integration/`:
   - `Ordinal+AtomicRepresentable.swift`
   - `Tagged+Ordinal.AtomicRepresentable.swift` (retroactive)
   - `Atomic+Ordinal.swift` (CAS-loop advance)

Built + tested green at each phase: 13 (executor-primitives) + 18 (swift-executors). Commits on `audit-cleanup` branches in both superrepos; submodule `swift-ordinal-primitives` on `main`.

Handoff + supervise authored post-work. Supervisor review passed 4/5 acceptance criteria; AC #3 (commit-message completeness) flagged two commits (`20b55e5`, `835347d`) as scope-bundled — they carried pre-existing upstream changes (self-join deadlock fix, Polling API redesign) that arrived via system-reminder mid-session and were committed along with my edits. User resolved the escalation: accept as-is, don't rewrite history for a pre-squash branch.

## What Worked and What Didn't

**Worked**:
- **Infrastructure-first cleanup** — Phase 0 (`Array+Cardinal`, later `Atomic+Ordinal`) unblocked clean expressions at call sites. Bottom-up sequencing was correct.
- **The `%` operator already existed.** Proposed `UInt64+Cardinal.swift` with remainder method; user pushed to explore the ecosystem. Found `Ordinal.Protocol % Cardinal.Protocol → Ordinal.Protocol` at `Ordinal+Cardinal.swift:135`. Composition instead of invention.
- **Rejecting `Cyclic.Counter<Tag>` as a named type.** User asked for academic grounding; honest answer was "no standard construct, this is FAA + modulo composition." Shifted to extending existing `Atomic` instead. The user's "academic grounding?" question saved invention.
- **Typed throws + typed catch patterns** held throughout.

**Didn't work first time**:
- Proposed `Property<Wake, Self>` in the Condvar accessor — compile error. Swift disallows covariant `Self` nested in generic return types. Fixed to concrete `Property<Wake, Executor.Wait.Condvar>`.
- Proposed `@usableFromInline internal let sync` + `internal import Thread_Synchronization` — compile error. `@usableFromInline` property can't have internally-imported type. Fixed by dropping `@inlinable` from Property methods (syscall wrappers don't benefit anyway).
- Initially proposed `Cyclic.Counter<Tag>` as a new ecosystem type. User correctly pushed back: no academic basis for naming a composition.
- Initially deferred Phase 2b typed count adoption citing "dep sprawl." User reversed: the deps ARE the point.

**Uncertain**:
- Whether `.one` type inference works in generic `Ordinal.Protocol` context. I defaulted to `C.one` with explicit generic parameter to sidestep. Not proven wrong, but not tested either.
- Whether `Value.AtomicRepresentation == UInt.AtomicRepresentation` constraint is the most general form for `Atomic.advance(within:)`, or whether a separate extension per storage size would be more canonical.

## Patterns and Root Causes

**Pattern: "When tempted to invent a type, first see if composing existing primitives suffices."**

Three distinct moments in this session fit this pattern:
1. `UInt64+Cardinal.swift` with remainder method → existing `Ordinal.Protocol % Cardinal.Protocol` composes.
2. `Cyclic.Counter<Tag>` as a new type → `Atomic<Tagged<Tag, Ordinal>>` + `advance(within:)` extension composes.
3. Property accessor for `popReady`/`drainReady` → flat rename suffices; the parameter label carries the redundant "ready" semantics.

Each time, the composition is more principled than the new type because it slots into existing generic abstraction layers (`Ordinal.Protocol`, `Cardinal.Protocol`, `Atomic`, `Array`). The new type would have been a specific composition named for ergonomics — legible for the immediate use case, isolated from the generic layer.

**The test is academic grounding.** When I proposed `Cyclic.Counter`, I had to admit: there's no standard named type for "atomic monotonic counter + modulo." Hardware has "ring counter"; software has "round-robin counter"; neither is a formal construct. The composition IS the construct. Naming it adds vocabulary without adding semantics.

**Pattern: "Intent-over-mechanism recurses into the implementation body."**

Early in the session, my implementations had intent at the CALL SITE but mechanism inside the method body. User pushed: even the implementation body of `enqueue()` should read as intent. That's [IMPL-INTENT] applied recursively. The answer was always "find/add infrastructure that lets the body read as a single expression."

- `workers[cursor.advance(within: count)].enqueue(job)` is the terminal form. Every subexpression is a named typed operation.

**Pattern: "External working-tree changes get committed along with session work."**

The supervisor flagged two commits as scope-bundled. Investigation: both bundled diffs arrived via system-reminder notifications during the session — pre-existing upstream changes that sat in the working tree by the time I ran `git add`. Not authored in this session. The commits honestly reflect the working tree; the commit messages honestly reflect my intent. The mismatch is structural.

**Root cause**: the subtree-in-superrepo workflow means `git add` on a session's changes includes whatever else happens to be in the working tree for that subtree. No per-commit linting catches this. The audit trail requires either pre-commit triage (staged-only commits per logical change) or post-hoc disclosure in the branch-level handoff document. User chose to skip both for a pre-squash branch — pragmatic, correct tradeoff.

**Pattern: "Academic grounding is a legitimate pushback."**

The user's question "is there academic background to support it?" was not pedantry — it was a request for me to justify inventing a named type vs composing primitives. Honest answer: no. The question short-circuits naming-theater and forces the cleaner composition.

## Action Items

- [ ] **[skill]** existing-infrastructure: Add an INFRA-* catalog entry for `Atomic<Ordinal.Protocol>.advance(within:)` as the canonical atomic round-robin primitive. Note the `Value.AtomicRepresentation == UInt.AtomicRepresentation` constraint and the CAS-loop semantics (lock-free, invariant-preserving).

- [ ] **[skill]** implementation: Add a pattern note under [IMPL-INTENT] — "when tempted to invent a named type for a composition, verify academic grounding. If the composition has no standard construct, extending an existing stdlib/ecosystem primitive with a named method is more principled than minting a new type."

- [ ] **[experiment]** Measure `Atomic<Index>.advance(within:)` CAS-loop vs `Atomic<UInt64>.wrappingAdd + %` FAA under simulated executor-dispatch contention (10k, 100k, 1M dispatches; 1, 4, 16 concurrent threads). Validate the claim that CAS perf is noise at executor rates.
