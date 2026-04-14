---
date: 2026-04-06
session_objective: Implement swift-io Tier 0 public API from converged design spec (HANDOFF.md)
packages:
  - swift-io
status: processed
---

# Intent Over Machinery — Module Boundaries Must Reflect User Concepts

## What Happened

Received a HANDOFF with the fully designed Tier 0 API (research doc v2.0 +
3-round converged plan). The task: resolve the Stream-vs-Channel architecture
question (A/B/C), then implement three "immediate" items (write(all:) on
Channel, IO.Buffer, IO.Error).

Analyzed all 25 research documents and 12+ source files. Recommended Option A
(IO.Stream wraps IO.Event.Channel). Attempted bottom-up implementation:
adding `write(all: UnsafeRawBufferPointer)` to Channel first.

The user stopped me at three points:

1. **"Why would we want a public API using UnsafeRawBufferPointer?"** — I was
   expanding the unsafe surface instead of defining the safe surface first.

2. **"We JUST DID the API spec — see the research doc"** — I was re-litigating
   settled decisions (proposing Q1–Q4 "open questions" that were already resolved
   in the converged plan).

3. **"IO Events and IO Completions feel like machinery"** — the module structure
   (`import IO` re-exporting `IO_Events`, `IO_Completions`) exposed implementation
   strategies as user-facing concepts. Users don't choose between reactor and
   proactor. They read and write bytes.

Wrote HANDOFF capturing the "intent over machinery" principle. No source files
modified.

## What Worked and What Didn't

**What worked**: The A/B/C analysis was sound. The error-personality argument
(a type should have one error type, not two overload sets with different throw
types) correctly identified Option A as the winner.

**What didn't work**: Bottom-up instinct. Given a task with both design and
implementation components, I gravitated toward the mechanical work (add
write(all:) to Channel) rather than the architectural work (define what users
see). This is exactly backwards when the spec already exists — the spec defines
the TOP, and implementation works DOWN from it.

Also: treating converged decisions as open questions. The research doc went
through 3 rounds of expert review. My "open questions" about naming, module
placement, and Span viability were already settled or easily answerable. This
wasted time and signaled that I hadn't fully absorbed the spec.

## Patterns and Root Causes

**Pattern: module boundaries must reflect user concepts, not implementation
strategies.** `IO Events` and `IO Completions` are named for HOW the I/O is
implemented (reactor, proactor). The user doesn't care. They care about WHAT
they can do: read bytes, write bytes, run an I/O workload. The module boundary
was drawn at an implementation seam rather than a user concept boundary. This
is the package-level analog of [IMPL-000] (call-site-first): module names
and exports should mirror what the user is trying to accomplish.

**Pattern: top-down when the spec exists, bottom-up when exploring.** When
research has converged on a spec, implementation works top-down: write the
types the user sees, then wire internals. Bottom-up (modifying Channel to
support features) is correct during exploration, when the target surface is
unknown. Applying the wrong direction wastes effort and can expand surfaces
that shouldn't exist.

## Action Items

- [ ] **[skill]** implementation: Add guidance for top-down vs bottom-up implementation direction — top-down when spec exists, bottom-up when exploring
- [ ] **[skill]** modularization: Add principle that module boundaries reflect user concepts, not implementation strategies — the package-level analog of call-site-first design
- [ ] **[package]** swift-io: Module restructuring needed — umbrella should show intent (Stream, Error, run) not machinery (Events, Completions, Blocking)
