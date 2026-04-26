---
date: 2026-04-24
session_objective: Comparative analysis of SE-0527 (RigidArray/UniqueArray) against swift-array-primitives, then execute a multi-phase OutputSpan adoption across the four affected packages.
packages:
  - swift-array-primitives
  - swift-buffer-primitives
  - swift-cardinal-primitives
  - swift-ordinal-primitives
status: processed
processed_date: 2026-04-26
triage_outcomes:
  - type: skill_update
    target: research-process
    description: "[RES-023] Empirical-Claim Verification for Dependent-Package State — generalizes [RES-013a] beyond synthesis to all empirical claims about dependent-package state in research docs"
  - type: research_topic
    target: value-generic-parameter-naming-convention.md
    description: "IN_PROGRESS Tier 2 — convention selection between single-letter N (stdlib-aligned), semantic name (current), scope-disambiguated; migration cost analysis pending"
  - type: package_insight
    target: swift-array-primitives/Research/_Package-Insights.md
    description: "Added Value-Generic Parameter Name Shadows Runtime Properties section; documents Array.Static.freeCapacity workaround using type-level capacity directly via Array.Index.Count(UInt(capacity))"
---

# SE-0527 OutputSpan Adoption Wave

## What Happened

Single session that started as research and ended as 17 commits across four packages.

**Research phase**:
- Loaded SE-0527 (Active Review through 2026-04-27) in full and compared its proposed `RigidArray` / `UniqueArray` types against our five-variant `Array` / `Array.Fixed` / `Array.Static<N>` / `Array.Small<N>` / `Array.Bounded<N>` family.
- Inventoried what's landed in `swiftlang/swift@release/6.3.1`: the entire Span family (`Span`, `MutableSpan`, `OutputSpan`, `RawSpan`, `MutableRawSpan`, `OutputRawSpan`) ships; `InlineArray` ships; `RigidArray` / `UniqueArray` / `BorrowingSequence` / `SpanIterator` / the `Containers` module do not; `borrow` / `mutate` accessor keywords are experimental-only.
- Verified `swift-sequence-primitives` already has `Sequence.Borrowing.Protocol` + `Sequence.Iterator.Protocol.nextSpan` — our ecosystem analog of SE-0516's `BorrowingSequence`.
- Wrote `Research/se-0527-rigid-unique-array-alignment.md` (Tier 2 RECOMMENDATION) in `swift-array-primitives`.

**Research amendment (v1.0.0 → v1.1.0)**:
- Claimed in v1.0.0 that buffer-level uninitialized-tail affordances "already exist internally" without verifying. Went to look in Phase 0a planning and found the claim was wrong — `Buffer.Linear.span` / `.mutableSpan` / `.withUnsafeMutableBufferPointer` only cover `0..<count`; `header`/`storage` are `package`-scoped and not visible across SwiftPM package boundaries. Amended v1.1.0 with a `Substrate prerequisites` section.

**Plan**:
- Drafted a phased plan (Phase -1 substrate → Phase 0 buffer-level → Phase 1 array-level → Phase 2 follow-ons → Phase 3 doc bump).
- Initial Phase -1 proposed adding a new `Index Primitives Standard Library Integration` target. User redirected with "lowest tier possible, even if it splits the extensions" — `Index<T> = Tagged<T, Ordinal>` decomposes cleanly, so OutputSpan typed overloads went to `cardinal-primitives` (count-based) and `ordinal-primitives` (position-based) instead of a new index-primitives target.

**Implementation** (commits in order):
- `cardinal-primitives@3baf384` — OutputSpan typed-cardinal overloads
- `ordinal-primitives@36930fd` — OutputSpan.swapAt typed-ordinal overload
- `buffer-primitives@c3f082c` — `Buffer.Linear.Bounded.init(capacity:initializingWith:)`
- `array-primitives@2a43b1a` — `Array.Fixed.init(capacity:initializingWith:)` (traps on partial init to preserve the "always fully initialized" invariant; throws propagate without trap)
- `buffer-primitives@8d45f6f` — `Buffer.Linear` `init` / `append(addingCapacity:)` / `edit(_:)` with ~Copyable and CoW-aware Copyable paths
- `array-primitives@9e94f27` — Array-layer delegations
- `array-primitives@f0cf7f2` — `swapAt(_:_:)` across dynamic/Fixed/Small/Static (Bounded deferred — `Algebra.Z<N>` index)
- `array-primitives@aeda9a6` + `@929836b` — `freeCapacity` (the v1 of this commit accidentally dropped `Array.Static` because of a name-shadow issue I didn't investigate carefully enough; user caught it; restored in 929836b)
- `array-primitives@309e773` — `Array.reserveCapacity(_:)` on dynamic
- `array-primitives@df6da40` — mirrored `base.pointee → base.value` migration across 4 Array Property.View sites to match `buffer-primitives@db34b05` (pre-existing in-tree work from before the session)
- `buffer-primitives@2cedfdf` + `array-primitives@a1dd5a3` — `clone()` / `clone(capacity:)` for Copyable elements
- `buffer-primitives@2b9d053` + `array-primitives@b98f721` — `reallocate(capacity:)` via `_growTo` with the grow-only guard lifted and a `capacity >= count` precondition
- `array-primitives@7b502b5` / `@e7a71bc` / `@fcf50c6` — research doc bumps v1.3.0 / v1.4.0 / v1.5.0

**Test counts at session end**:
- `swift-array-primitives`: 136 tests / 46 suites green (+37 over starting state)
- `swift-buffer-primitives`: 431 tests / 85 suites green (+28 over starting state)

**Meta-work**: produced a five-axis framework at the user's request for reasoning about deferred items (block kind / reversibility / scope / consumer pressure / design tension). Applied the framework to both remaining deferred items; user chose `reallocate` (decision-blocked, low-stakes) and parked `Array.Bounded swapAt/freeCapacity` (tension-blocked, no consumer pressure).

**Artifact cleanup**: no HANDOFF files at the session's working directory (swift-primitives root). `swift-buffer-primitives/HANDOFF-deinit-devirtualizer-crash.md` exists and is unrelated to this session's work — left alone. No audit findings updated.

## What Worked and What Didn't

**Worked**:

- **Substrate-first phasing**. The plan explicitly put the buffer-primitives prerequisite (Phase 0) before array-primitives adoption (Phase 1). When I wrote the research doc without verifying the substrate, the v1.1.0 amendment caught it before I started implementing; by the time Phase 0a was being written, the substrate gap was a known quantity, not a surprise during implementation.
- **Test-in-the-commit discipline**. Every commit landed code + tests together. Regressions got caught immediately (e.g., the `#expect(span.capacity == 0)` failure because OutputSpan is `~Copyable & ~Escapable` and `#expect` can't capture it — surfaced on first test run, fixed by extracting into local vars).
- **The "lowest tier possible" architectural rule**. User's prompt collapsed what was going to be a new index-primitives integration target into two entries in the existing cardinal-primitives and ordinal-primitives integration targets. Also surfaced that `sequence-primitives/Swift.Span+extracting.swift` is a tier violation (uses only Cardinal/Ordinal concepts but lives in a higher-tier package). Documented for a future cleanup; didn't bundle the migration into this session.
- **The five-axis framework for deferred items**. The user extracted it back out of my analysis ("give me the framework to think about the deferred items") — good signal that the underlying reasoning was transferable, not specific to this session.

**Didn't work**:

- **Research doc claimed substrate existed without verification** (v1.0.0). This is a recurring failure mode I have a memory entry for (`feedback_verify_prior_findings.md`, `feedback_verify_cited_sources.md`). I drifted. Caught at the Phase 0a planning boundary, but the right time to catch it was at the time of writing — before the reader (myself, the next session) had to rely on the claim.
- **Array.Static.freeCapacity removed instead of investigated**. When the name-shadow between `Array.Static<let capacity: Int>` (type-level generic) and a hypothetical runtime `capacity` property broke the build, I removed the Array.Static extension rather than investigate for 60 seconds. The correct fix was trivial: compute from the own generic parameter directly (`Array.Index.Count(UInt(capacity))`), no buffer-level change needed. The user asked "why was this removed?" and I restored it in a follow-up commit. The removal should have been a hypothesis I tested, not a first move.
- **Small test-API friction compounds**. Multiple small iterations on `Index.Count(Int)` (throwing) vs `Index.Count(UInt(x))` (non-throwing), `throwing:` labeled append vs unlabeled, `#expect` with non-Copyable subjects. None was individually a mistake; collectively they slowed each new test file by a recognizable amount. This is an ergonomic gap — either the conversion functions need clearer ergonomics or I need internalized shortcuts.

## Patterns and Root Causes

### Pattern 1 — Assert-without-verify in research docs is the same bug as unverified code claims

The v1.0.0 research doc said "these affordances already exist internally" about `swift-buffer-primitives`. This is the same failure shape as citing a function that doesn't exist, or a memory that's drifted. [RES-013a] "Synthesis Verification" already codifies the rule for carried-forward findings from prior research — it does NOT explicitly extend to *original* empirical claims about current dependent-package state. The rule should generalize: any claim a research doc makes about the live state of another package is verifiable and therefore MUST be verified before the document ships. My memory has individual feedback entries for this failure mode; the skill doesn't yet carry the rule in the universal form.

### Pattern 2 — Value-generic parameter naming creates shadowing hazards

`Array.Static<let capacity: Int>` and `Buffer.Linear.Inline<let capacity: Int>` both use `capacity` as the generic parameter name. Inside their scope, `capacity` refers to the type-level Int; any attempt to add a public instance property named `capacity` would shadow (and did, when I tried). By contrast, `Array.Small<let inlineCapacity: Int>` uses a scope-unambiguous name and has a clean `public var capacity: Index.Count`; `Array.Bounded<let N: Int>` is also clean. This is a real inconsistency in the ecosystem, not just an implementation detail — it changes what APIs the type can expose. The precipitating case was freeCapacity, but the next time someone wants to add a capacity-adjacent property to Array.Static or Buffer.Linear.Inline they'll hit the same wall.

### Pattern 3 — "Lowest tier possible" is a corrective lens, not just a placement rule

The rule resolved the OutputSpan-overload placement question in a single sentence. But it ALSO retroactively identified the existing `Swift.Span+extracting.swift` in `sequence-primitives` as misplaced (it uses only Cardinal/Ordinal concepts, which belong to a lower tier). When I initially argued to migrate that file ("conceptual home"), my reasoning was weak — the real reason to move it is the tier violation, not aesthetics. The user's pushback forced a clearer formulation. Takeaway: when arguing for a move, lead with the measurable rule (tier, convention ID) rather than the aesthetic claim.

### Pattern 4 — Deferral is a design decision with a type, not just a TODO

The five-axis framework I produced is essentially: "what KIND of deferred is this?" Decision-blocked items with low stakes and no tension ship immediately with a plausible default. Tension-blocked items with moderate stakes and no consumer sit in a `[research]` bucket until a forcing use case arrives. Substrate-blocked items get a substrate-first plan. Dependency-blocked items track the upstream. Each has a different next action. An operations audit that just lists "deferred" items without typing them is doing less than it could — typing the deferral enables the right action.

## Action Items

- [ ] **[skill]** research-process: Generalize [RES-013a] beyond "carried-forward findings from prior research." The rule as written applies to synthesis; extend it to any empirical claim a research doc makes about the current state of a dependent package or upstream source (file existence, API presence, substrate availability). Precipitating case: this session's v1.0.0 → v1.1.0 amendment where the doc claimed uninitialized-tail buffer affordances existed "internally" without verification.
- [ ] **[research]** Value-generic parameter naming convention in the primitives ecosystem: should `<let N: Int>` be the standard (as in `Array.Bounded`, or the stdlib's `InlineArray<N, T>`), or should semantic names like `<let inlineCapacity: Int>` (`Array.Small`) be preferred? Current inconsistency: `Array.Static<let capacity: Int>` and `Buffer.Linear.Inline<let capacity: Int>` shadow runtime-property attempts. Document the trade-off and pick a convention; write the rule into the conventions skill (primitives or code-surface).
- [ ] **[package]** swift-array-primitives: Add a `_Package-Insights.md` entry documenting the value-generic name-shadow gotcha and the workaround for `Array.Static.freeCapacity` (compute from the type's own generic parameter via `Array.Index.Count(UInt(capacity))` rather than through `_buffer.capacity`, which would resolve to the shadowed generic).
