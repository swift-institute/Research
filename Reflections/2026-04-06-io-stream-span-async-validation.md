---
date: 2026-04-06
session_objective: Implement swift-io Tier 0 public API from converged design spec
packages:
  - swift-io
  - swift-institute
status: pending
---

# Span and MutableSpan Survive Async — The Perfect IO API Is Achievable Today

## What Happened

Started from the HANDOFF.md in swift-io which specified a fully designed Tier 0 API
(research doc v2.0 + converged plan). Three open questions needed resolution: module
structure, target placement, Span viability in async context.

Resolved Q1 (selective re-export: `import IO` gives Tier 0, `import IO_Events` for
Tier 1) and Q2 (new `IO Stream` target). For Q3 (Span + async), I assumed based on
general ~Escapable reasoning that the compiler would reject Span across suspension
points. Built the entire IO Stream target with raw pointers and a concrete IO.Buffer
type as a workaround.

The user challenged three assumptions in sequence:

1. **"I don't want an IO Buffer type"** — forced the question of whether the buffer
   is IO's concern. It isn't. A byte buffer is a general-purpose primitive.

2. **"What is the foundationally perfect approach?"** — forced first-principles
   thinking. Answer: `Span<UInt8>` for writes, `MutableSpan<UInt8>` for reads. The
   stream operates on memory regions, not containers.

3. **"Validate that the gap is the compiler, not the design"** — forced empirical
   verification via /experiment-process. The experiments proved my assumption WRONG:
   Span and MutableSpan both survive across async suspension in Swift 6.3.

4. **"Why is the return type Int?"** — forced [IMPL-002]/[IMPL-006] analysis. A byte
   count is a typed count (`Index<UInt8>.Count`), not raw `Int`. And `0 = EOF` is
   POSIX mechanism; `nil = EOF` is intent.

Final state: IO.Buffer deleted. Stream.write takes `Span<UInt8>`. Stream.read takes
`inout MutableSpan<UInt8>`, returns `Int?` (nil = EOF). No raw pointers in Tier 0.

## What Worked and What Didn't

**What worked**: The experiment-driven approach. Two experiments (`span-async-parameter`,
`mutablespan-async-read`) conclusively validated capabilities I had assumed were
impossible. The experiments took ~5 minutes each and fundamentally changed the design.

**What didn't work**: My initial assumptions about ~Escapable + async. I reasoned from
general principles ("~Escapable can't survive in async frames") rather than testing
empirically. This led to building an entire IO.Buffer type and raw-pointer bridge
that turned out to be unnecessary. Three commits of work partially wasted.

**Confidence calibration**: I was highly confident in my ~Escapable reasoning and
presented it as fact ("The gap is the compiler, not the design"). The user correctly
demanded verification. My confidence was exactly wrong — the claim I presented as
certain was false.

## Patterns and Root Causes

**Pattern: Assumed limitations compound into unnecessary architecture.** The chain:
"Span can't cross await" → "need raw pointers" → "need IO.Buffer to wrap them safely"
→ "need buffer protocol for genericity." One false assumption generated three layers
of workaround architecture. The experiment took 5 minutes; the workaround took 30.

This is the same pattern as [IMPL-077] (Verify Constraints Before Workarounds):
"When a compiler error or handoff claims a limitation, the constraint MUST be
verified via minimal experiment before implementing a workaround." I knew the rule
and still violated it because reasoning felt more efficient than testing.

**Pattern: The user asking "why" at each level drives toward the principled design.**
Each pushback ("why IO.Buffer?", "what's the perfect approach?", "why Int?") peeled
back a layer of accidental complexity. The final design is simpler than every
intermediate version. First-principles questioning is the highest-leverage design
tool.

**Root cause of the false assumption**: The HANDOFF.md from the previous session
stated "Span<UInt8> + async: untested. May need experiment." I read "may need
experiment" and instead reasoned about it. The previous session's uncertainty was
correctly flagged — I just didn't act on the flag correctly.

## Action Items

- [ ] **[skill]** implementation: Strengthen [IMPL-077] — add "reasoning about compiler capabilities is not verification; always experiment" with this session as the motivating example
- [ ] **[skill]** memory-safety: Add rule for Span/MutableSpan + async — CONFIRMED working in Swift 6.3, ~Escapable parameters survive across suspension points. Reference experiments `span-async-parameter` and `mutablespan-async-read`
- [ ] **[experiment]** Consolidate `span-async-parameter` and `mutablespan-async-read` into a single `span-mutablespan-async` experiment per [EXP-018], since they test related aspects of the same capability
