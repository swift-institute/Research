# Memory-Safety Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-02
status: REFERENCE
-->

> Non-normative companion to `Skills/memory-safety/` (hub `SKILL.md` + companion files), per the
> platform-skill template (Research/platform-skill-rationale.md). This document holds evicted
> rationale prose, provenance, origin-incident walkthroughs, extended/second example variants,
> lint-enforcement scope detail, and the dated amendment changelog. The skill files remain the
> CANONICAL source for all `[MEM-*]` requirement statements; nothing in this archive is normative.
> Organized by rule ID in skill order; the dated frontmatter changelog entries are collected in
> the final §Changelog-Provenance section.
>
> Trim provenance: R2 wave-3 eviction, 2026-07-02. `linear.md` and `references.md` were already
> lean and are unchanged. The one clause found ONLY in a dated changelog entry (the [MEM-SEND-006]
> Category-D keyword-match scope, 2026-05-15) was hoisted verbatim into the rule body in
> `concurrency.md`; every other changelog-carried clause was verified present in its rule body.

---

## safety-isolation.md

### §[MEM-SAFE-023] Private Unsafe Storage

**Worked `~Escapable` example** (evicted; the exception paragraph and severity table remain in-skill):

```swift
// ACCEPTABLE - ~Escapable prevents the pointer from outliving the source.
// `@safe` is admitted by [MEM-SAFE-025b]; the adjacent disclosure
// satisfies [MEM-SAFE-025c].
// WHY: Category D (SP-5) — `~Escapable` View; pointer cannot outlive its
// WHY: source by construction, so the public exposure is structurally safe.
@safe public struct View: ~Copyable, ~Escapable {
    public let pointer: UnsafePointer<Char>  // Cannot dangle by construction
    public var span: Span<Char> { ... }      // Still preferred for callers
}
```

**Lint enforcement (full scope detail)**: `Lint.Rule.Memory.PrivateUnsafeStorage` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Memory`) flags public stored properties of `Unsafe*Pointer*` types not annotated `@unsafe`. Allowlist covers `UnsafePointer`, `UnsafeMutablePointer`, `UnsafeRawPointer`, `UnsafeMutableRawPointer`, plus their `BufferPointer` analogues. `~Escapable` exception is left to author judgement (suppress with disable-comment when applied). Added 2026-05-10 (Wave 2b finalization Batch 4).

---

### §[MEM-SAFE-024] `@unchecked Sendable` Semantic Categories

**Reference** (evicted verbatim): `swift-institute/Research/tilde-sendable-semantic-inventory.md` (superseded by `Research/ownership-transfer-conventions.md`); ecosystem audit finding 35 sites (16% of 218) across three subpatterns — `swift-institute/Research/unsafe-audit-findings.md` "Category D Adjudication" section. Current ecosystem inventories: `swift-institute/Audits/sendable-inventory-2026-05-13.md` §14 (`@unchecked Sendable`) + `swift-institute/Audits/sendable-constraint-arc-2026-06-01.md` (`: Sendable` constraints).

**Provenance** (evicted verbatim):
- Category A/B/C originally per tilde-sendable-semantic-inventory.
- Category D added per reflection `2026-04-15-ecosystem-unsafe-audit.md`, where 35 existing `@unchecked Sendable` sites were found to be none of A/B/C and resolved into three coherent subpatterns (SP-2, SP-4, SP-5). Two candidate subpatterns (SP-1, SP-8) were reclassified to B by the governing principle ("ownership transfer is the primary invariant; value-generic is incidental").
- **2026-05-13 BREAKING revision** ([SKILL-LIFE-003] Breaking): the Annotation column for Cat A/B/D changed from `@unsafe @unchecked Sendable` to bare `@unchecked Sendable`. Per `swift-institute/Research/safe-unsafe-attribute-and-unchecked-sendable-best-practices.md` v1.1.0 (RECOMMENDATION), `@unsafe` and `@unchecked Sendable` are peers in SE-0458's framework — `@unsafe` is scoped to the four memory-safety dimensions (lifetime / bounds / type / initialization), thread safety is the separate fifth dimension carried by `@unchecked Sendable` alone. The Swift stdlib + 15 surveyed Apple packages at HEAD of `main` on 2026-05-13 carry several hundred `@unchecked Sendable` sites with **zero `@unsafe @unchecked Sendable` pairs**. Source sweep deferred per principal direction; policy applies to all new sites immediately.

**Lint enforcement (full scope detail)**: `Lint.Rule.Memory.UncheckedSendableCategorized` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Memory`) flags `@unchecked Sendable` conformances that ALSO carry `@unsafe` on the same conformance clause (a deviation from Swift convention per SE-0458). Covers struct / class / enum / actor / extension declarations. The Category label (A/B/C/D) is documentation discipline (carried in a `## Safety Invariant` doc-comment or adjacent `// SAFETY:` / `// WHY:` block per [MEM-SAFE-025c]), not a trigger for additional `@unsafe` annotation. Originally added 2026-05-10 (Wave 2b finalization Batch 4) flagging `@unchecked Sendable` without `@unsafe`; **inverted 2026-05-13** to flag `@unchecked Sendable` with `@unsafe` instead, per the BREAKING revision above.

---

### §[MEM-SAFE-025a] `nonisolated(unsafe)` Requires Invariant Comment

**Evicted example variants** (one correct/incorrect pair remains in-skill):

```swift
// CORRECT — `// WHY:` form, multi-line, with skill citation
// WHY: Category D (SP-5) — UnsafeRawPointer in the dict blocks structural
// WHY: Sendable inference. COW discipline ensures each isolation domain owns
// WHY: its unique _Storage after first write. See [MEM-SAFE-024].
@usableFromInline
final class _Storage: @unchecked Sendable { ... }

// INCORRECT — blank line between comment and declaration
// SAFETY: Allocated once at module init.

nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
```

**Rationale (full prose)**: `nonisolated(unsafe)` encodes a temporal invariant ("set once before any concurrent read", "pointee never mutated") that the type system cannot express. The institute's convention is to state that invariant in prose immediately at the declaration site, so reviewers can verify the invariant without chasing through type metadata or attribute decoration. The `// SAFETY:` / `// WHY:` forms are the institute's existing comment idiom (compare the `// WHY: @unchecked Sendable —` comments in swift-executor-primitives' Deque pattern).

**Lint enforcement (full scope detail)**: `Lint.Rule.Memory.NonisolatedUnsafeInvariant` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Memory`) flags `nonisolated(unsafe)` declarations whose leading trivia does not contain an adjacent `// SAFETY:` or `// WHY:` line. Covers both `let` and `var`; the comment MUST be immediately adjacent (no intervening blank line — a restatement of the Statement's adjacency clause). Replaces `Lint.Rule.Memory.NonisolatedUnsafeSafe` per Wave 3 Thread 7 (2026-05-11).

---

### §[MEM-SAFE-025b] `@safe` Attribute Admitted with Invariant Disclosure

**Evicted example variants** (the `// WHY:` correct form and the bare incorrect form remain in-skill):

```swift
// CORRECT — `@safe` accompanied by a `## Safety Invariant` doc section
/// ## Safety Invariant
/// Internal `Mutex<State>` serializes all access; the wrapped pointer
/// is only handed out within the mutex's critical section.
@safe public struct LockedState {
    private let lock = Mutex<State>(.initial)
}

// CORRECT — `@safe` on a property/method with an adjacent `// SAFETY:` line
public struct Container {
    // SAFETY: Bounds-checked at every call site; pointer arithmetic in
    // SAFETY: this subscript stays within `capacity`.
    @safe
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < capacity)
        return unsafe storage[index]
    }
}
```

**Rationale (full prose)**: Per SE-0458, `@safe` is the language-level mechanism that materializes the absorber-pattern role described by [MEM-SAFE-020]: it suppresses argument-unsafety diagnostics on callers, draws the no-propagation boundary, and exposes the absorber to audit tooling. Per cross-language convention (Rust `unsafe` + `// SAFETY:`, Haskell Safe extensions + haddocks, proof-carrying-code's witness + obligation pair), safety claims use **both** a machine-checkable attribute and a human-auditable explanation. The institute layers an explicit disclosure requirement on top of SE-0458's attribute so the corpus carries both halves: the attribute is the claim; the disclosure is the rationale.

The Wave 3 Thread 7 framing (forbid `@safe` in favour of prose comments alone) treated the attribute and the comment as alternatives. The structural re-examination in `swift-institute/Research/safe-attribute-absorber-pattern-fundamentals.md` v1.1.0 DECISION (Option B) inverts that framing: comments and attributes are complementary; both are admitted; both are required where `@safe` is used.

**Provenance (evicted verbatim)**: The inverted rule admits `@safe` per SE-0458's intent; [MEM-SAFE-021]/[MEM-SAFE-022]/[MEM-SAFE-023] examples showing `@safe public struct` are admitted by the new policy when accompanied by disclosure per [MEM-SAFE-025c]. Replaces the Wave 4 absorber-pattern carve-out (the carve-out predicate is no longer load-bearing under the inverted rule). See `swift-institute/Research/safe-attribute-absorber-pattern-fundamentals.md` v1.1.0 DECISION (Option B) for the full rationale and the cross-language prior-art survey.

**Lint enforcement (full scope detail)**: `Lint.Rule.Memory.SafeAttributeUndocumented` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Memory`) flags any `@safe`-attributed declaration whose leading trivia does not contain an adjacent `// SAFETY:` / `// WHY:` comment OR a `## Safety Invariant` doc-comment section. Severity warning. Inverted from `Lint.Rule.Memory.SafeForbidden` per the Option B DECISION (2026-05-12).

---

### §[MEM-SAFE-025c] `@safe` Declarations Require Invariant Disclosure

**Evicted example variants** (the Category-citing `// WHY:` correct form, the `## Safety Invariant` doc-section form, and the bare incorrect form remain in-skill):

```swift
// CORRECT — adjacent `// SAFETY:` block without Category (free-form prose)
// SAFETY: Transitive absorption of `Ownership.Borrow<Base>`; the wrapper's
// SAFETY: API never exposes the underlying borrow as a raw pointer, and
// SAFETY: `~Escapable` prevents lifetime escape.
@safe public struct Borrow<Base: ~Copyable>: ~Copyable, ~Escapable {
    private let inner: Tagged<Tag, Ownership.Borrow<Base>>
}

// CORRECT — `@safe` on a method with adjacent `// SAFETY:` line
public struct Buffer<Element> {
    // SAFETY: Bounds-checked precondition guards the unsafe load; the
    // SAFETY: caller cannot observe the unsafe pointer.
    @safe
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < capacity)
        return unsafe storage[index]
    }
}

// INCORRECT — comment present but not adjacent (blank line breaks adjacency)
// SAFETY: Allocated once at init.

@safe
public struct Pinned { ... }
```

**Rationale (full prose)**: Per SE-0458, `@safe` is the machine-checkable claim that a declaration's signature contains unsafe types but is nonetheless safe to use; the attribute provides argument-unsafety suppression and the no-propagation boundary. Per cross-language convention (Rust `unsafe` + `// SAFETY:`, Haskell Safe-Haskell + haddocks), the explanation that accompanies the claim belongs in prose (comment or doc section). This rule layers the explanation requirement on top of the SE-0458 attribute so the institute corpus carries both halves: machine-checked claim + human-auditable rationale.

---

### §[MEM-SAFE-012] Span Family as Normative Interface

**Second incorrect variant** (evicted; the lesson is carried by [MEM-SPAN-003] and [MEM-SAFE-014] in-skill):

```swift
// INCORRECT - vending a raw pointer to "fill an uninitialised tail"
public struct Buffer {
    @unsafe public var uninitializedTail: UnsafeMutableBufferPointer<UInt8> { ... }  // ❌ use OutputSpan
}
```

---

### §[MEM-SAFE-014] Closure Scope Over Property Access

**Second incorrect variant** (evicted; the OutputSpan supersession paragraph remains in-skill):

```swift
// INCORRECT - withUnsafe* over an uninitialised tail when OutputSpan fits
storage.withUnsafeMutableTail { raw in raw.initializeElement(at: 0, to: x) }  // ❌ use OutputSpan
```

---

### §[MEM-SAFE-015] Raw Pointer Is the Last Resort, Deeply Encapsulated

**Why (full prose)**: the ecosystem direction (2026-06-02) is Span-first — maximally eliminate `Unsafe*` and `*Pointer*` from API surfaces. Treating a raw accessor as "the primitive" (the pre-`OutputSpan` framing of `Storage.Protocol.pointer(at:)`, since removed) actively misleads implementers into vending raw pointers where a span fits. This rule inverts the default: span first, pointer only when the four gates are all satisfied and documented.

**Provenance**: principal direction 2026-06-02 (Span-first); `HANDOFF-storage-protocol-p6-depointer.md` (the de-pointer arc removing `Storage.Protocol.pointer(at:)`); `HANDOFF-memory-skills-span-first.md`.

---

### §[MEM-SAFE-027] `_deinitWorkaround` Placement

**Provenance**: `swift-institute/Research/swift-compiler-bug-catalog.md` §A14; `conditional-deinit-conditionally-copyable-generics.md` (tier-3, 2026-06-06); cleave-7 GOAL/PROGRESS; ratified by the seat (Cleave-7 disposition, 2026-06-06).

---

### §[MEM-SAFE-028] The Drain-Box Rule

**Why the rule is design, not just workaround (full prose)**: with the drain, the wrapped struct's oracle tears down an EMPTY buffer — count-driven, so correctness no longer depends on whether the compiler runs it (no double-free either way). This converges with the stdlib factoring: `_ContiguousArrayStorage` destroys elements in its class deinit; the stdlib never relies on a struct deinit behind a class.

**Provenance**: the W4 copyability spike (`PROPOSAL-tower-perfected-design.md` §1.4, ratified 2026-06-09); `Experiments/cow-box-deinit-omission-miscompile` (CONFIRMED, both swiftc-pair and SwiftPM forms); `Research/stdlib-array-family-source-archaeology.md` Q3 (the `_fixLifetime` close); first shipping site: `swift-shared-primitives` `Box`.

---

### §[MEM-SAFE-029] No Generic Address Caching

**Origin incident** (evicted from the Why paragraph): The pre-W5 `Storage.Generational` cached `_baseRaw` + `_slotStride`; the W5-1 re-bound dropped both for per-access derivation — which also retired the measured-stride hack (the pool owns its layout, including stride padding).

**Provenance**: principal-ratified 2026-06-11 at the W5-1 §A15 adoption (converged plan storage-generational-purity 2026-06-10; arena 208c8d1 over pool 9dd38e7; catalog §A15 — the same-type-conformance defect whose fix surfaced this discipline).

---

### §[MEM-SAFE-030] The Read-Only Fence

**Provenance**: `swift-institute/Research/read-only-foreign-column.md` v1.0.0 (Q1 fence + Outcome #3; consumer analysis file:line-verified 2026-06-12 — the only production consumer terminates in unconditional `_modify`). Round M skills batch (seat dispatch, 2026-06-13).

---

### §[MEM-SAFE-031] Two Unsafe Surfaces of an Owned Region

**Provenance**: `swift-institute/Research/memory-contiguous-dissolution.md` (2026-06-23) — the `Memory.Heap` floor (cached pointer + alloc/free) vs the read-`Span` surface (moving to `Storage.Contiguous` / bare `Swift.Span`) made the distinction load-bearing; principal direction (2026-06-23) to record it as a rule, not a one-off note. Synthesises the floor side of [MEM-SAFE-029] with the span side of [MEM-SAFE-030]/[MEM-SAFE-012] and adds the SE-0465 upgrade-path dimension.

---

## ownership.md

### §[MEM-COPY-001a] Deinit Immutability for ~Copyable Structs

**Rationale (full prose)**: The deinit immutability asymmetry is a recurring surprise when moving code between `consuming` methods and `deinit`. It is not a bug — `self` being immutable in `deinit` matches the semantic model: the value is about to cease to exist, so the compiler forbids you from observing it in an intermediate mutated state. The canonical idiom (read-only presence check) preserves the safety model while letting the destructor take local decisions based on whether the Optional is populated.

**Provenance**: Reflection `2026-04-13-scope-mutex-removal-deinit-immutability.md`.

---

### §[MEM-COPY-014] Native Ownership for Resource Types

**Provenance**: 2026-03-30-io-lane-boundary-completion-typed-throws.md

---

### §[MEM-COPY-002] Noncopyable in Error Types

**Lint enforcement (full scope detail)**: `Lint.Rule.Memory.ErrorNoncopyable` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Memory`). Added 2026-05-10 (Wave 2b finalization Batch 4).

---

### §[MEM-COPY-004] Suppression Restatement

**Worked examples (evicted verbatim)**: a sweep-wide migration left exactly ONE bare conformance — `extension Storage.Heap: Span.Protocol {` — which re-pinned the span capability to Copyable elements while siblings restated correctly (fixed `9d1d65b`, swift-storage-primitives); a reviewer's "marker protocol, no witnesses, fine" classification of `Array.Fixed: Collection.Access.Random {}` was OVERTURNED on edge 1 (fixed `b956bea`, swift-array-primitives); a multi-param `Storage.Split` extension restating only `Element` silently Copyable-constrained `Lanes`/`Elements` (edge: row 4).

**Provenance**: Reflection `2026-06-04-msb-capability-tower-w3-endgame.md` (the Findings 1/11 suppression-restatement family; six recurrences across one program).

**Lint enforcement (full scope detail)**: `Lint.Rule.Memory.ExtensionNoncopyableConstraint` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Memory`) flags `extension` declarations whose body has at least one `consuming` / `borrowing` method or parameter (a strong signal that the extended type is `~Copyable`-aware) AND whose `where` clause does not contain `~Copyable`. False positives suppressed via disable-comment when the underlying type is genuinely `Copyable`. Added 2026-05-10 (Wave 2b finalization Batch 4). **Widening candidate** (lint-rule-promotion): bare *conformance* extensions and protocol *refinements* on suppressed types — the family rows in-skill — are not yet mechanically covered.

---

## concurrency.md

### §[MEM-SEND-004] ~Copyable Structs Can Use Plain Sendable

**Lint enforcement (full scope detail)**: `Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Memory`). The compiler synthesises and checks `Sendable` for `~Copyable` structs the same way as for `Copyable` ones — `@unchecked` is a misleading safety claim. Drop `@unchecked` and let the checker verify. Added 2026-05-10 (Wave 2b finalization Batch 4).

**Provenance**: 2026-03-31-convention3-unchecked-sendable-audit.md; lint enforcement added 2026-05-10.

---

### §[MEM-SEND-005] Non-Mutating Concurrent Access for ~Copyable Wrappers

**Provenance**: Reflection `2026-04-16-executor-deque-peer-review-to-production.md` (Chase-Lev deque pattern).

---

### §[MEM-SEND-006] Compiler-Limitation `@unchecked Sendable` Requires Revalidation Anchor

The rule body was compressed at mechanization (2026-05-15, per [PROMOTE-006]); full Statement / anchor-format example / procedure / worked example / provenance live in the outcome record `Audits/PROMOTE-MEM-SEND-006-2026-05-15.md` `## Discipline reference`. The Category-D scope clause ("Categories A/B/C are semantic-responsibility cases and out of scope") existed ONLY in the 2026-05-15 changelog entry and was hoisted verbatim into the rule body during the 2026-07-02 trim.

---

### §[MEM-SEND-009] `inout sending Value` for `Mutex.withLock` Wrappers

**Compiler trace** (evicted from the Why): it is the `hasSendingResult()` flag and the `inout sending` parameter annotation that suppress the diagnostic. Traced to `diagnoseNonSendableTypesWithSendingCheck()` in `swiftlang/swift/lib/Sema/TypeCheckConcurrency.h`.

**Hazard status** (evicted parenthetical): Reproduced Swift 6.3.2, 2026-06-01; all current ecosystem `withLock { $0 }` sites return Sendable snapshots — none affected. Candidate for promotion to its own rule ID if the principal prefers.

**Reference experiment (full detail)**: `swift-institute/Experiments/sending-mutex-noncopyable-region/` — 23 variants, 6 confirmed.

---

### §[MEM-SEND-012] Region-Based Isolation Supersedes Sendable Constraint in Protocol-Layer Designs

**Worked example (the origin incident, evicted verbatim)**: A 2026-05-13 transformation-domain audit observed that `Parser.Protocol`, `Serializer.Protocol`, and `Coder.Protocol` use plain `: Swift.Error` (without `& Sendable`) and proposed tightening these to match an earlier research doc's prescription of `Error & Sendable`. The user reversed the proposal, citing the institute's broader move toward region-based isolation: *"we don't want the & Sendable constraint. we're moving to region based isolation over Sendable."* The reversal codifies the protocol-layer half of the move; existing [MEM-SEND-009]/[MEM-SEND-010] cover the boundary-crossing half.

**Provenance**: 2026-05-13 transformation-domain audit + collaboration discussion. Aligns with [MEM-SEND-010]'s direction ("`sending R` over `R: Sendable`") at the protocol-design layer.

---

### §[MEM-SEND-013] Region-Based Isolation Supersedes Sendable Constraint in Combinator-Layer Designs

**Worked example (Pattern B origin incident → terminal-direction landing, evicted verbatim)**:

A 2026-05-13 paired sweep first applied the **transitional** Pattern B recipe to `Binary.Bytes.Machine` inside `swift-binary-parser-primitives`: the upstream `Machine.Capture.Mode.Unchecked` was promoted to `@unchecked Sendable`, the consumer's `Mode` typealias flipped to it, combinator factories in `Combinators.swift` shed every `<T: Sendable>` / `@Sendable` annotation across `pure`/`map`/`tryMap`/`sequence`/`many`/`fold`/`optional`, and `Instruction` downgraded to `@unchecked Sendable` so that `Binary.Bytes.Machine.Parser: Sendable` survived by construction. The transitional state introduced two Cat C `@unchecked Sendable` sites (`Mode.Unchecked` and `Instruction`).

Later the same day, after an ecosystem-wide grep confirmed zero consumers depended on `Binary.Bytes.Machine.Parser: Sendable` for transport (no Sendable-typed Parser storage, no `T: Sendable` generic bounds binding the parser type, no `@Sendable` closure captures), the **terminal direction** landed: `Mode.Unchecked` reverted to plain `public struct Unchecked` (no `@unchecked Sendable`), `Instruction` dropped its `@unchecked Sendable` extension, `Binary.Bytes.Machine.Build.swift`'s `extension Parser: Sendable {}` was deleted, and the upstream `Machine.Program` / `Machine.Builder` struct-level `Leaf: Sendable` / `Mode: Sendable` constraints relaxed to conditional Sendable extensions (`extension Machine.Program: Sendable where Leaf: Sendable, Mode: Sendable {}`). The assembled `Binary.Bytes.Machine.Parser<Output>` is now non-Sendable; consumers transport via `sending` at the program-transport boundary. The two Cat C sites were eliminated.

A prerequisite upstream relaxation landed in `swift-graph-primitives`: `Graph.Sequential<Tag, Payload>` and `Graph.Sequential.Traverse` had their struct-level `where Payload: Sendable` constraints split into conditional Sendable conformance extensions (strictly generalizing — existing Sendable-Payload instantiations unchanged) so that downstream `Machine.Program` could store `Graph.Sequential<Node<Leaf, Failure, Mode>, ...>` without forcing `Payload: Sendable` upward.

Build/test verification at the terminal landing: `swift-graph-primitives` build green (test-runner SIGSEGV is a known pre-existing condition unrelated to Sendable changes; XCTest suite reports passed); `swift-machine-primitives` build green + 105/105 tests pass; `swift-binary-parser-primitives` build green + 69/69 tests pass; `swift-binary-coder-primitives` (downstream verification) build green + 41/41 tests pass; `swift-foundations/swift-ascii` (downstream Sendable-context check) build green.

**Landed detail (evicted verbatim)**: the `swift-parser-machine-primitives` cascade (the single largest in the parser-machine arc, ~91 site-level annotations) was applied via the terminal direction on 2026-05-13 (commit `85b6778`), joining the `Binary.Bytes.Machine` precedent documented in the worked example above. Its central `Mode` typealias now aliases `Machine.Capture.Mode.Unchecked` (`Parser.Machine.swift:19`), the `Node`/`Frame`/`Program` typealiases route through it, and the arc's coupled Cat C `@unchecked Sendable` sites were eliminated (verified footprint 2026-06-01: 6 `: Sendable` all out-of-scope-preserved, 0 `@unchecked`, 7 `sending`).

**Provenance (evicted verbatim)**: Pattern A — 2026-05-13 transformation-domain follow-up to [MEM-SEND-012]. User scope: *"the sendable cleanup is more to do with Sendable restrictions (not so much our Error types that are Sendable; that's fine), but protocol restrictions to Sendable are in scope to be upgraded to region based isolation."* Pattern B — 2026-05-13 Machine-subsystem follow-up paired with the input-primitives data-container sweep; reframed the Sendable cascade from a four-pattern coupled mass into a Mode-typealias root-and-fanout. Initial recipe promoted `@unchecked Sendable` upstream to preserve `Parser: Sendable`; same-day Phase B sweep (after `swift-institute/Audits/sendable-inventory-2026-05-13.md` resolved OQ-1 toward the "zero Cat C" endpoint) reframed Pattern B as **transitional** with the **terminal direction** dropping the upstream Sendable conformance and routing transport through `sending`. User direction: *"we really want to remove Sendable requirements in favour of sending or other region based isolation (huge unlock for us)."*

---

## advanced-ownership.md

### §[MEM-OWN-013] Consuming Does Not Suppress Deinit

**Provenance**: 2026-03-26-io-api-remediation-sync-submission.md

---

### §[MEM-OWN-014] Batch Slot Staging for Non-Sendable Sequences

**Provenance**: 2026-03-30-sending-sendable-migration-cascade.md

---

### §[MEM-OWN-016] `isolated` Parameter for Borrowing ~Copyable Across Actor Boundaries

**Experiment history** (evicted from the Rationale): Proven in experiment `actor-run-closure-alternatives` V1–V5; applied to `IO.Event.Selector.register` (collapsed 2 hops to 1).

**Provenance**: Experiment `actor-run-closure-alternatives` V1–V5; applied 2026-03-25 to `IO.Event.Selector.register`.

---

### §[MEM-COPY-016] Conditional-Copyable Cleanup Triangle

**Worked example (the origin incident, evicted verbatim)**: the MSB W3 `Buffer.Slab<S>` reparam hit the wall verbatim (evidence record `bd04f32`, swift-buffer-slab-primitives — committed deliberately as "DOES NOT BUILD"); the Box-relocation pilot landed at `c3d3bb5` (Box holds storage + bitmap + `deinit`; its `Storage.Slab` oracle was deleted and absorbed → Box HAS the deinit). The sibling `Buffer.Arena` Box correctly has NO deinit — its held `Storage.Arena` backing self-cleans, so the substrate is the truth-holder. The same wall reappeared wherever a conditionally-Copyable discipline tried to self-clean (a generic `Buffer.Ring` cannot deinitialize its own slots; it delegates to the storage's deinit) — three sightings, one constraint.

**Provenance (the 2026-06-06 extension block)**: Reflection `2026-06-04-msb-capability-tower-w3-endgame.md` (the `bd04f32` wall; ASK-1/ASK-6 recurrences; supervisor-affirmed one-truth-holder invariant); 2026-06-06 promotion of `swift-institute/Research/conditional-deinit-conditionally-copyable-generics.md` (tier-3) + `swift-vector-primitives/Research/noncopyable-conditional-copyable.md` (DECISION); SE-0427 § Conformance to `Copyable`; ratified by the seat (Cleave-7 disposition, 2026-06-06).

*(Note: the law-is-fundamental clause, the inline-third-corner correction, and the Wall-1/Wall-2 split — the changelog-built [MEM-COPY-016] amendments — remain in-skill verbatim in `advanced-ownership.md`; only this provenance detail was evicted.)*

---

### §[MEM-COPY-017] Construction Captures Copyability Evidence

**Fired-trap incident** (evicted from How to apply): the `Shared` test suite's single `makeShared<E: ~Copyable>` helper built Copyable columns through the move-only constructor — caught by the backstop, fixed by splitting (`7acb5ed`).

**Provenance**: the W4 `Shared` combinator (constructor split `7acb5ed`; backstop in `ensureUnique()`); principal ruling Audit #3 (keep overloads + this rule; no API relabel) 2026-06-10.

---

### §[MEM-COPY-018] Same-Type Method Pins Derive Suppression Conditions

**Provenance**: ADT-families ratification spike (`.handoffs/probes-2026-06-10/queue-family-spike/`, F-4; one-variable experiment: full bound compiles, relaxed bound fails); seat-ratified 2026-06-10 with skill-encoding at adoption.

---

### §[MEM-OWN-017] A Closure Capture Cannot Be Consumed

**Provenance**: ADT-families ratification spike (`.handoffs/probes-2026-06-10/queue-family-spike/`, F-3 — `store.withUnique { $0.insert(element) }` rejected; the payload form proven end-to-end); seat-ratified 2026-06-10; landed as `Shared.withUnique(consuming:_:)` (`0c18a0b`).

---

### §[MEM-COPY-019] Box-Replacing Overloads MUST Split Per the Pinned Pair

**Defect-class detail (evicted verbatim)**: the stack Builder constructing-grammar twins (W5 Lane A′, the clone-less-box trap) and both dictionary families' Shared `removeAll` (`Dictionary+Columns.swift:239`, `Dictionary.Ordered+Columns.swift:245` — found by arc-2's model fleet stream within ~80 ops; masked by example tests that never forked after the wipe, the [TEST-035] class). Fix shape principal-ratified 2026-06-12 and landed as dictionary `c51d879` + dict-ordered `d1e3110`, regression-locked ("forking after removeAll keeps both siblings independently mutable").

**Provenance**: arc-2 finding ASK-W3-A (`REPORT-arc-model-tests-W3.md` Entry 2), seat-reproduced via independent /tmp probe (trap exit 133 pre-fix → clean post-fix); principal-ratified fix (i), 2026-06-12. Additive per [SKILL-LIFE-003].

---

## span.md

### §[MEM-SPAN-002] Span-Indexed Iteration Over `withUnsafePointer` at L3 Consumer Sites

**Origin incident** (evicted from the Why): The 2026-04-20 swift-file-system session landed `c3b9986` with the unsafe-pointer form, then had to apply this fix one iteration later when the supervisor flagged the `unsafe` leak — strictly superior, same 709/709 test pass.

**Provenance**: memory `feedback_span_indexed_over_unsafe_pointer.md` (2026-04-20 swift-file-system).

---

### §[MEM-SPAN-003] Span Family Selection

**Provenance**: principal direction 2026-06-02 (Span-first); `HANDOFF-memory-skills-span-first.md`; `HANDOFF-storage-protocol-p6-depointer.md` (de-pointer arc). SE-0527 (`OutputSpan`).

**Lint enforcement (full scope detail)**: `Lint.Rule.Memory.PointerArithmetic` (rule id `pointer advanced by`, institute tier — `Linter Rule Memory`) flags `unsafe …advanced(by:)` raw pointer arithmetic and recommends the Span family. `Strideable.advanced(by:)` (range / index iteration over a `Bound: Strideable`) carries no `unsafe` and is NOT flagged — the `unsafe` acknowledgement is the AST-visible proxy for "raw pointer." `Tests/` / `Experiments/` / `Examples/` paths and adjacent `// SAFETY:` / `// WHY:` last-resort justifications ([MEM-SAFE-015], mirroring [MEM-SAFE-025a]) are exempt. Re-aimed from `[IMPL-011]` to this rule 2026-06-03 (Span-first); discipline `swift-institute/Audits/PROMOTE-pointer-advanced-by-2026-06-03.md`.

---

### §[MEM-SPAN-004] Match the Addressing Seam to the Index Domain

**Worked example (the origin incident, evicted verbatim)**: `Buffer.Ring.Scalar.next()` (the `Sequenceable` consuming witness behind `first(where:)`/`contains`) read `base._storage.span[physical]` while `physicalSlot` produces capacity-relative slots. A wrapped ring (head > 0, count < capacity) places front-segment slots in `[count, capacity)` → "Index out of bounds" trap on iteration, while `subscript` and `forEach` — already on the per-slot seam — were correct. Fix: read through the storage's per-slot subscript, matching the sibling witnesses (swift-buffer-ring-primitives `b5ca83d`); wrapped/head-offset regression coverage added (`9a37bd6` — both tests trap pre-fix, pass post-fix).

**Provenance**: principal addendum (2026-06-04) to Reflection `2026-06-04-msb-capability-tower-w3-endgame.md`; evidence swift-buffer-ring-primitives `b5ca83d` + `9a37bd6`.

---

### §[MEM-SPAN-005] Span-First on Hot Paths Means Hoist-or-Cheapen

**The measured tax** (storage-arena B1 spike + lane-η probe, Swift 6.3.2, best-of-3 ratios — evicted verbatim):

| Access shape | Measurement | Verdict |
|---|---|---|
| Per-access spans through the `Store.Initialization` ledger (`Storage.Contiguous` planes) | validation 2.17×, iteration 1.50–1.60× vs the stdlib-plane control | FAILS any no-regression gate |
| Per-call spans through a ledger-free `capacitySpan` door (lane-η) | uniform 1.06–1.44× vs the ratified hybrid; hole-skip back at the pre-plane number | PROBED-NEGATIVE — the Contiguous-mediated indirection survives `-O`; a direct heap-base derive does not |
| Span-typed reads + three SAFETY-documented pointer transitions over the owned base ((b⁗) hybrid) | dominates the stdlib-plane control on every case (0.43–1.00×) | RATIFIED (R-12) — reads gain bounds checks; the unsafe surface shrinks to the named writes |

**Provenance**: `.handoffs/REPORT-round-m-W1.md` §2b finding 1 (spike evidence, root-cause isolation, R-12 adjudication); `.handoffs/REPORT-round-m-W4-terminal.md` §3 (lane-η `capacitySpan` probe, PROBED-NEGATIVE; the R-15 downgrade). Round M skills batch (seat dispatch, 2026-06-13).

---

## lifetime.md

### §[MEM-LIFE-005] Nested Coroutine ~Escapable Scope Limitation

**Provenance**: 2026-03-31-noncopyable-peek-escapable-scope-nesting-limit.md

---

### §[MEM-LIFE-006] ~Escapable Parameters in Async Methods

**Companion examples** (evicted; the `Span`-across-await example and the path table remain in-skill):

**Correct** — MutableSpan across await:
```swift
public mutating func read(
    into buffer: inout MutableSpan<UInt8>
) async throws(IO.Event.Failure) -> Int {
    while true {
        // ... attempt syscall into &buffer ...
        case .wouldBlock:
            try await arm()  // inout MutableSpan survives this suspension
        // ...
    }
}
```

**Correct** — `extracting(droppingFirst:)` replaces pointer arithmetic for partial writes:
```swift
public mutating func write(
    all data: Span<UInt8>
) async throws(IO.Error) {
    var offset = 0
    while offset < data.count {
        let slice = data.extracting(droppingFirst: offset)
        let n = try await channel.write(slice)
        offset += n
    }
}
```

**Empirical proof (full detail)**: swift-io Channel migration (commit `6a691f88`) — replaced 18 unsafe pointer sites with Span/MutableSpan parameters in async methods with EAGAIN retry loops.

**Provenance**: HANDOFF-escapable-async-skill-update.md (swift-io unsafe pointer audit)

---

### §[MEM-LIFE-008] ~Escapable Over `with*` Closure APIs for Borrowed Access

**Provenance**: memory `feedback_escapable_over_with_closures.md` (post-Lifetimes ecosystem; with*-pattern accumulation reverse).

---

## §Changelog-Provenance

The dated amendment changelog evicted from `SKILL.md` frontmatter, verbatim (newest first). Each entry's normative clauses were verified present in the owning rule body at trim time; the single exception (the [MEM-SEND-006] Category-D scope clause, 2026-05-15 entry) was hoisted into `concurrency.md`.

- 2026-06-13 (2): [MEM-SAFE-030] ADDED (safety-isolation.md) — the read-only fence: read-only regimes (Memory.Map .read windows, immutable foreign buffers) never conform Memory.Region; the conformance buys only Storage.Contiguous entry, which terminates in unconditional _modify = UB for read-only bytes; reads ride Span/Span.Protocol per [MEM-SPAN-001]. Additive per [SKILL-LIFE-003]. Provenance: Research/read-only-foreign-column.md v1.0.0 Q1 fence + Outcome #3 (Round M skills batch, seat dispatch). Rider: Rule Index currency repair — backfilled missing [MEM-SAFE-025c]/[MEM-SAFE-027]/[MEM-SAFE-028]/[MEM-SAFE-029] hooks; corrected the stale [MEM-SAFE-025b] hook to the post-Option-B inversion ("admitted with invariant disclosure", 2026-05-12).

- 2026-06-13: [MEM-SPAN-005] ADDED (span.md) — span-first on hot paths means hoist-or-cheapen: per-access span derivation through the Store.Initialization ledger is hot-path-hostile (B1 spike: validation 2.17×, iteration 1.5–1.6× vs stdlib-plane control; lane-η capacitySpan probe PROBED-NEGATIVE, uniform 1.06–1.44× vs the hybrid); blocked-hoist fallback = the R-12 (b⁗) hybrid under [MEM-SAFE-029]. Additive per [SKILL-LIFE-003]. Provenance: .handoffs/REPORT-round-m-W1.md §2b finding 1 + REPORT-round-m-W4-terminal.md §3 (Round M skills batch, seat dispatch).

- 2026-06-12 (later): [MEM-COPY-019] MECHANIZED (Round M ζ pilot 2): Lint.Rule.Tower.CloneLessBox landed (primitives tier, Tower pack); the in-rule lint-candidate line replaced by the Enforcement line; ladder+tower 0 findings (fixes hold), historical pre-fix calibration fires at the cited line exactly. Clarifying per [SKILL-LIFE-003].

- 2026-06-12: [MEM-COPY-019] ADDED (advanced-ownership.md) — box-replacing overloads MUST split per the [MEM-COPY-017] pair; ~Copyable-bounded contexts statically select the strategy-less init (the clone-less-box trap class: stack Builder twins + both dictionaries' removeAll, arc-2 ASK-W3-A; seat-reproduced; fix principal-ratified + landed c51d879/d1e3110, regression-locked). Lint candidate recorded in-rule. Additive per [SKILL-LIFE-003].

- 2026-06-11: [MEM-SAFE-029] ADDED (safety-isolation.md) — no generic address caching: generic code over a storage/pooling seam derives addresses per access (pointer(at:)); cached bases only behind concrete heap-pinned paths (Memory.Pooling L3 — inline resources move their bytes). Principal-ratified at the W5-1 §A15 adoption. Additive per [SKILL-LIFE-003].

- 2026-06-06: [MEM-COPY-016] EXTENDED (advanced-ownership.md) — added the law-is-fundamental clause (SE-0427 deinit⟹unconditionally-~Copyable; conditional-deinit not expressible, no horizon; Rust E0184/E0367 parallel), the inline THIRD corner (no Box-relocation for @_rawLayout → forced concrete unconditionally-~Copyable variant = converged equilibrium; removal gate = conditional deinit lands), and the Wall-1/Wall-2 split. Promotes swift-vector-primitives/Research/noncopyable-conditional-copyable.md (DECISION) + Research/conditional-deinit-conditionally-copyable-generics.md (tier-3). Additive+Clarifying per [SKILL-LIFE-003]. Seat-ratified (Cleave-7) 2026-06-06.

- 2026-06-10: [MEM-COPY-017] ADDED (advanced-ownership.md) — construction captures copyability evidence: CoW wrappers split constructors on element copyability AND every generic construction helper splits the same way (a ~Copyable-generic helper statically picks the strategy-less init → backstop trap on first shared mutation; fired-trap incident 7acb5ed). Principal ruling Audit #3 (keep overloads + skill rule) 2026-06-10. Additive per [SKILL-LIFE-003].

- 2026-06-10: [MEM-COPY-018] ADDED (advanced-ownership.md) — same-type method pins derive SUPPRESSION conditions, not protocol-conformance conditions: a column combinator consumed via `where S == Wrapper<E, Concrete<E>>` pins must carry its protocol obligations in the DECLARATION bound (conditional `where B: P` conformances reify ill-formed concrete-subject requirements at the pin; the extra-generic-param dodge also fails). One-variable proof: ADT-families spike F-4 (probes-2026-06-10/queue-family-spike). Seat-ratified 2026-06-10. Additive per [SKILL-LIFE-003].

- 2026-06-10: [MEM-OWN-017] ADDED (advanced-ownership.md) — a closure capture cannot be consumed ("missing reinitialization of closure capture after consume", non-escaping included): scoped-access APIs thread consuming payloads as closure PARAMETERS (`withUnique(consuming:_:)` shape) from birth; Copyable payloads mask the wall by copying. Spike F-3; landed 0c18a0b. Additive per [SKILL-LIFE-003].

- 2026-06-10: [MEM-SAFE-028] ADDED (safety-isolation.md) — the drain-box rule: a refcounted box over move-only storage OWNS element teardown in its class deinit (column-supplied @Sendable drain + _fixLifetime(self) close); never rely on a struct deinit behind a class hop (-O + isKnownUniquelyReferenced devirtualized destroy OMITS the user deinit of generic-namespace-nested ~Copyable structs — repro: Experiments/cow-box-deinit-omission-miscompile). Ratified R-5 (PROPOSAL-tower-perfected-design.md). Additive per [SKILL-LIFE-003].

- 2026-06-06: [MEM-SAFE-027] ADDED (safety-isolation.md) — _deinitWorkaround placement for the cross-package @_rawLayout deinit-skip (swift#86652 = Wall 2, a codegen bug distinct from the Wall-1 law): substrate-leaf for composed, on-the-type for direct-@_rawLayout, NEVER buffer-level over a nested substrate (SIGSEGV). Removal gate = #86652 lands. Additive per [SKILL-LIFE-003]. Provenance: bug-catalog §A14 + Research/conditional-deinit-conditionally-copyable-generics.md. Seat-ratified 2026-06-06.

- 2026-06-04: [MEM-COPY-016] added (advanced-ownership.md) — conditional-Copyable cleanup triangle: a conditionally-Copyable generic struct cannot declare `deinit` (`deinitializer cannot be declared in generic struct that conforms to Copyable`); (a) generic substrate / (b) conditional Copyable / (c) auto-cleanup — pick two; Box-relocation escape + exactly-one-cleanup-truth-holder invariant. Additive per [SKILL-LIFE-003]. Provenance: Reflections/2026-06-04-msb-capability-tower-w3-endgame.md (bd04f32 wall, ASK-1/ASK-6, slab pilot c3d3bb5).

- 2026-06-04: [MEM-COPY-004] extended (ownership.md) — retitled to the suppression-restatement family: restate ~Copyable for EVERY suppressed param on extensions, protocol refinements, AND conformances; conformances gate on existence (marker protocols included); S.Element projection constraints legal on extensions, illegal on suppressible-protocol conformances; Copyable-element tests mask the defect (move-only coverage per [TEST-035]). Clarifying + Additive per [SKILL-LIFE-003] (conformance extensions were already in-scope of the prior statement's plain reading; the refinement form and the edges are additive). Same provenance.

- 2026-06-04: [MEM-SPAN-004] added (span.md) — match the addressing seam to the index domain: capacity-domain disciplines (rings/offsets/occupancy) read via the per-slot Store.Protocol seam, never the count-bounded span; pairs with [TEST-035] wrap-state coverage. Additive per [SKILL-LIFE-003]. Provenance: principal addendum 2026-06-04; swift-buffer-ring-primitives b5ca83d + 9a37bd6.

- 2026-06-01: [MEM-SEND-009] Hazard subsection added (concurrency.md) — `withLock { $0 }` does NOT prevent escape of non-Sendable `State` (region-isolation soundness gap; reproduced Swift 6.3.2; Point-Free #360). All current ecosystem `withLock { $0 }` sites return Sendable snapshots (unaffected). Additive per [SKILL-LIFE-003]; flagged as a promotion candidate to its own rule ID. Provenance: B-track investigation 2026-06-01 + Experiments/sending-mutex-noncopyable-region.

- 2026-06-01: [MEM-SAFE-024] (safety-isolation.md) — fixed broken citation (unsafe-audit-findings.md lives in Research/ not Audits/); marked tilde-sendable-semantic-inventory.md superseded + added current-inventory pointers; added dated Category C deferral-status note (TildeSendable=0 canonical; revisit trigger = SE-0518 acceptance; eliminable Cat C = 1 site, IteratorHandle). Clarifying + Additive per [SKILL-LIFE-003]. Provenance: B-track investigation 2026-06-01.

- 2026-06-01: [MEM-SEND-013] Pattern B "Next candidates" currency fix (concurrency.md) — `swift-parser-machine-primitives` recorded as LANDED (commit `85b6778`, 2026-05-13: central `Mode` typealias now `Machine.Capture.Mode.Unchecked` at `Parser.Machine.swift:19`; `Node`/`Frame`/`Program` rerouted; coupled Cat C `@unchecked Sendable` sites eliminated), no longer listed as a pending next-candidate; the general per-Mode.Reference candidate rule retained verbatim. Clarifying per [SKILL-LIFE-003]. Provenance: commit `85b6778` + `swift-institute/Audits/sendable-inventory-2026-05-13.md` §11/§12.

- 2026-05-15: [MEM-SEND-006] mechanization — `Lint.Rule.Memory.UncheckedSendableRevalidationAnchor` landed in `swift-foundations/swift-linter-rules` (universal tier, target `Linter Rule Memory`). Bundle entry added to `Lint.Rule.Bundle.universal` after `.unchecked sendable noncopyable`. Second AST-domain pilot of `/promote-rule` per `swift-institute/Audits/PROMOTE-MEM-SEND-006-2026-05-15.md`; validation receipt at `swift-foundations/swift-linter-rules/Research/promote-MEM-SEND-006-validation-2026-05-15.md` (0 ladder findings across 7 packages; 18 ground-truth-probe findings on 7 broader packages, deferred for per-package batch-fix per Phase 6 branch 1). Rule body in `concurrency.md` compressed atomically per [PROMOTE-006]: full Statement / Anchor format example / Procedure / Why anchored / Worked example / Provenance migrated to the outcome record's `## Discipline reference` section. Anchor format Statement amendment landed in the same edit — institute practice (`WHY:` / `WHEN TO REMOVE:` / `TRACKING:` markers) supersedes the literal "WORKAROUND FOR COMPILER LIMITATION" header example per Pass A wording-only-defect carve-out (pilot 7 `[GH-REPO-074]` precedent). Phase 6 iteration loop branch 2 was taken mid-pilot to scope the keyword-match to `Category D` only — Categories A/B/C are semantic-responsibility cases (`[MEM-SAFE-024]`'s scheme) and out of scope for this rule. Clarifying per [SKILL-LIFE-003].

- 2026-05-13: [MEM-SEND-013] Pattern B REFRAMED as transitional — Phase B (`swift-institute/Audits/sendable-inventory-2026-05-13.md` OQ-1 resolution) added "terminal direction" recipe (non-Sendable upstream Mode + `sending` at transport, no Cat C site) alongside the existing "transitional" recipe (`@unchecked Sendable` upstream Mode preserving `Parser: Sendable`). How-to-apply expanded with a terminal-vs-transitional choice step and a new step 6 covering upstream `Builder` / `Program` struct-level `Leaf: Sendable` / `Mode: Sendable` constraint relaxation. Worked example updated end-to-end to walk the `Binary.Bytes.Machine` arc: transitional landing (morning) → terminal landing (afternoon, eliminating both Cat C sites). Pattern B's "Next candidates" reframed to recommend the terminal direction by default. Clarifying per [SKILL-LIFE-003] — Step 4 pre-flight grep confirmed zero load-bearing consumers depended on `Binary.Bytes.Machine.Parser: Sendable`, so the transition is not breaking; the transitional recipe remains a valid intermediate. Provenance: `swift-institute/Audits/sendable-inventory-2026-05-13.md` §6 OQ-1, §8 Phase A, §8.6 Phase B sequencing.

- 2026-05-13: [MEM-SEND-013] amended — added Pattern B (Mode-parameter cascade) subsection alongside the existing protocol-bound cascade body (now read as Pattern A). Mode-parameterized combinator layers dissolve their Sendable cascade via a one-line upstream `@unchecked Sendable` Mode promotion + consumer typealias flip + cascade-strip, distinct from Pattern A's coupled four-pattern drop. Out-of-scope data-container row expanded with `Input.Slice<Base>`, `Parser.Tracked.Checkpoint` worked examples and a forbidden-shape clarification (struct-level generic `Sendable` constraint vs conditional `Sendable` conformance). Additive per [SKILL-LIFE-003]. Provenance: 2026-05-13 paired Machine-subsystem (Pattern B worked example: `Binary.Bytes.Machine`) + input-primitives (data-container worked examples) sweeps.

- 2026-05-13: [MEM-SEND-013] added — extends [MEM-SEND-012] to the combinator layer; combinator structs parameterized over protocol-bound generics must not carry `: Sendable where T: Sendable` conditional conformances, generic-parameter `& Sendable` bounds, `where Self: Sendable` extension constraints, or `@Sendable` on stored closures. Concrete error types and pure data containers stay unaffected. Additive per [SKILL-LIFE-003]. Provenance: 2026-05-13 transformation-domain follow-up.

- 2026-05-13: [MEM-SEND-012] added — region-based isolation (SE-0414) supersedes Sendable constraint in protocol-layer designs; new protocol associatedtypes default to plain Error not Error & Sendable; boundary-crossing parameters prefer `sending` per [MEM-SEND-009]/[MEM-SEND-010]. Provenance: 2026-05-13 transformation-domain audit. Additive per [SKILL-LIFE-003].

- 2026-05-12: Option B DECISION (`swift-institute/Research/safe-attribute-absorber-pattern-fundamentals.md` v1.1.0). Inverts [MEM-SAFE-025b] from "forbid `@safe` in Sources/" to "admit `@safe`; require adjacent invariant disclosure per [MEM-SAFE-025c]". Adds [MEM-SAFE-025c] codifying the disclosure form (`// SAFETY:` / `// WHY:` line block OR `## Safety Invariant` doc section). Removes the Wave 4 absorber-pattern carve-out — the carve-out predicate is no longer load-bearing under the inverted rule. Removes the "Direct `@safe` on funcs/vars/lets/inits/subscripts remains forbidden" clause — `@safe` is admitted everywhere SE-0458 permits. Lint rule `Lint.Rule.Memory.SafeForbidden` renamed/inverted to `Lint.Rule.Memory.SafeAttributeUndocumented`. Replacing per [SKILL-LIFE-002].

- 2026-05-11: Wave 3 Thread 7 — split [MEM-SAFE-025] into [MEM-SAFE-025a] (invariant comment) + [MEM-SAFE-025b] (`@safe` forbidden in Sources/). Original [MEM-SAFE-025] marked SUPERSEDED per the corpus convention; historical body preserved as a one-line note pointing forward. Source migration of the 6 Wave-3 enumerated sites lands per-package in this thread; the broader [MEM-SAFE-021]/[MEM-SAFE-022]/[MEM-SAFE-023] absorber-pattern conflict is flagged in [MEM-SAFE-025b] for separate follow-up. Provenance: `swift-institute/Research/mem-safe-025-reconciliation.md` (DECISION Option B). Replacing per [SKILL-LIFE-002].

- 2026-05-10: Phase 3b TRIM-PROSE — compressed redundant How-to-apply / Rationale prose on [MEM-UNSAFE-004], [MEM-SEND-004] now that lint mechanically enforces. Statements unchanged per [SKILL-LIFE-001].

- 2026-05-10: Wave 2b lint extraction (HANDOFF-skill-to-ci-cd-extraction-inventory.md) — added Lint enforcement line for [MEM-UNSAFE-004] in safety-isolation.md mapping the rule to SwiftLint custom rule `no_unsafe_block_form`. Clarifying per [SKILL-LIFE-003].

- 2026-05-10: Wave 2b finalization Batch 4 (HANDOFF-wave-2b-finalization.md) — added Lint enforcement lines for [MEM-SAFE-023] (Lint.Rule.Memory.PrivateUnsafeStorage), [MEM-SAFE-024] (Lint.Rule.Memory.UncheckedSendableCategorized), [MEM-SAFE-025] (Lint.Rule.Memory.NonisolatedUnsafeSafe), [MEM-COPY-002] (Lint.Rule.Memory.ErrorNoncopyable), [MEM-COPY-004] (Lint.Rule.Memory.ExtensionNoncopyableConstraint), [MEM-SEND-004] (Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable). Each rule's prose section in safety-isolation.md / ownership.md / concurrency.md gets a **Lint enforcement** clarifying-addition per [SKILL-LIFE-003].
