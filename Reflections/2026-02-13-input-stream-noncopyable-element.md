---
date: 2026-02-13
session_objective: Make Input.Stream.Protocol's Element associatedtype ~Copyable
packages:
  - swift-input-primitives
  - swift-parser-primitives
status: processed
processed_date: 2026-02-13
triage_outcomes:
  - type: skill_update
    target: copyable-remediation
    description: Add [COPY-REM-003] constraint cascade audit for ~Copyable/~Escapable changes
  - type: package_insight
    target: swift-input-primitives
    description: TestCollection constraint poisoning needs module-split treatment
  - type: experiment_topic
    target: input-slice-module-split-poisoning
    description: Validate module-split fixes constraint poisoning for Input.Slice TestCollection
---

# Input.Stream.Protocol ~Copyable Element — Constraint Cascade and ~Escapable Discovery

## What Happened

The session implemented a planned change: `associatedtype Element` to `associatedtype Element: ~Copyable` on `Input.Stream.Protocol`, removing `first: Element?` from protocol requirements (validated in prior experiment `read-accessor-noncopyable-optional`). The core streaming contract became `isEmpty` + `advance()`.

Parser-primitives consumers (`Parser.Byte`, `Parser.First.Where`, `Parser.Literal`) were rewritten from `guard let actual = input.first` to `guard !input.isEmpty` + `let actual = try! input.advance()`. `Parser.Tracked.first` and `Parser.Input.starts(with:)` were removed.

Three categories of cascade emerged:

1. **~Copyable on Element** — `Input.Slice<Base: Collection.Protocol>` broke because `Collection.Protocol.Element: ~Copyable` (from sequence-primitives). Subscript access on borrowed `base` couldn't produce Copyable values. Fixed with conditional conformance: `extension Input.Slice: Input.Protocol where Base.Element: Copyable`.

2. **~Copyable on ParseOutput** — `Parser.First.Element` and `Parser.First.Where` set `ParseOutput = Input.Element`, but `Parser.Protocol.ParseOutput` implicitly requires `Copyable`. Fixed by adding `where Input.Element: Copyable` on those parser structs.

3. **~Escapable on Input** — Pre-existing WIP change had added `associatedtype Input: ~Escapable` to `Parser.Protocol`. This broke `Parser.Optionally` because `Parser.Take.Builder<Input>` had implicit `Escapable` on its generic parameter. An experiment (`constraint-poisoning-module-split`) confirmed the fix: `Builder<Input: ~Escapable>`. No module split needed.

The `~Copyable` constraint poisoning on `TestCollection<Int>` in the test suite remains — the compiler cannot see through `Collection.Protocol`'s `Element: ~Copyable` to recognize the concrete `Int: Copyable`. This is the same constraint poisoning pattern previously solved with module splits for storage/buffer/data-structure types.

## What Worked and What Didn't

**Worked well**: The experiment-first approach ([EXP-011]) paid off twice. The prior `read-accessor-noncopyable-optional` experiment gave high confidence for removing `first` from the protocol. The new `constraint-poisoning-module-split` experiment resolved the `~Escapable` question in under a minute — no module split needed, just `Builder<Input: ~Escapable>`.

**Worked well**: The `isEmpty` + `advance()` rewrite pattern for parsers was mechanical and clean. Each parser's logic became more direct (consume then check, rather than peek then consume separately).

**Didn't work**: The plan underestimated the cascade from `Element: ~Copyable`. It said "No changes" for `Input.Buffer+Input.Protocol.swift` and `Input.Slice+Input.Protocol.swift`. `Input.Buffer` was fine (stdlib `RandomAccessCollection` requires `Copyable` elements), but `Input.Slice` broke because `Collection.Protocol` from collection-primitives already has `Element: ~Copyable`. The plan also missed `Parser.First.Element`, `Parser.First.Where` (ParseOutput Copyable requirement), and `Parser.Take.Builder` (~Escapable).

**Didn't work**: The test suite's `TestCollection<Int>` hits ~Copyable constraint poisoning. The compiler can't see that `TestCollection<Int>.Element = Int: Copyable` when the protocol chain declares `Element: ~Copyable`. This is the known module-split problem, not a new issue.

## Patterns and Root Causes

**~Copyable cascade is predictable but hard to fully enumerate in advance.** The three failure modes — subscript access on borrowed containers, ParseOutput Copyable requirement, and conditional conformance needed for generic types over ~Copyable protocols — are all instances of the same root cause: when a protocol declares `associatedtype X: ~Copyable`, every downstream generic context that touches `X` must either suppress `Copyable` or add it back as an explicit constraint. The cascade fans out at every generic boundary.

The plan was designed with full awareness of the `first` removal but missed the transitive effects through `Collection.Protocol`, `Parser.Protocol.ParseOutput`, and `Parser.Take.Builder`. This suggests that plans for `~Copyable`/`~Escapable` changes should include a "constraint audit" step — tracing every associated type through every conformer and extension to predict where explicit `Copyable`/`Escapable` constraints will be needed.

**~Escapable and ~Copyable are structurally identical problems but with different fix granularity.** ~Copyable constraint poisoning requires module splits because the compiler can't see through protocol-level associated type constraints to concrete types. ~Escapable constraint poisoning on generic parameters is fixable inline by simply adding `~Escapable` to the parameter declaration. The difference: ~Copyable poisoning happens at the *associated type witness* level (compiler limitation), while ~Escapable poisoning happens at the *generic parameter declaration* level (user error — forgot to suppress).

**Semantic note on the `advance()` rewrite**: The new parser pattern (consume then check) means on mismatch the byte is consumed, whereas the old pattern (peek then consume) left it unconsumed. For `Parser.Literal` this matches the documented "on partial match failure, input is left partially consumed" contract. For `Parser.Byte` this is a behavioral change — previously a mismatch left the byte unconsumed, now it's consumed. This is acceptable for streaming parsers (no backtracking), but worth noting.

## Action Items

- [ ] **[skill]** copyable-remediation: Add "constraint audit" guidance — when planning ~Copyable/~Escapable changes, trace every associated type through conformers and extensions to predict cascade [COPY-FIX-*]
- [ ] **[package]** swift-input-primitives: TestCollection constraint poisoning in test suite needs the same module-split treatment as storage/buffer/data-structure types
- [ ] **[experiment]** Validate ~Copyable constraint poisoning module-split fix for Input.Slice (same pattern as storage-primitives, but confirm it resolves the TestCollection issue specifically)
