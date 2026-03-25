---
date: 2026-03-25
session_objective: Conduct IO systems literature study and design audit of swift-io against prior art
packages:
  - swift-io
  - swift-file-system
  - swift-kernel-primitives
  - swift-kernel
  - swift-posix
status: pending
---

# IO Prior Art Literature Study and Design Audit

## What Happened

Session set out to answer whether swift-io introduces too many custom concepts or whether everything is correct and necessary. Conducted in two phases:

**Phase 1 — Literature survey**: Six parallel research agents investigated Rust (std::io, tokio, mio, tokio-uring), Go (io, bufio, os, net), Java NIO / .NET Pipelines, Zig (std.Io 0.15.1+) / OCaml (Eio), OS-level primitives (io_uring, epoll, kqueue, IOCP, libuv), and Haskell / academic theory / SwiftNIO. Produced 6,400 lines of per-system reference data, synthesized into a 4-tier concept necessity spectrum (irreducible → expected → valuable → paradigm-specific).

**Phase 2 — Design audit**: Explored swift-io (279 files, 7 targets, ~72 concepts) and swift-kernel-primitives IO types. Mapped every concept against the tier spectrum. Extended to swift-file-system after the user pointed out that read/write lives there. Discovered the full read/write stack spans L1 through L3 across five packages.

**Key deviation**: Initially framed the absence of a generic Reader/Writer trait (Go's `io.Reader`, Rust's `Read`) as a potential gap. The user challenged this, leading to a deeper analysis that concluded it's the correct architecture — a generic trait would erase typed errors and domain-specific capabilities.

**Deliverables**: One consolidated research document (`io-prior-art-and-swift-io-design-audit.md`), one per-system reference (`swift-io/Research/io-prior-art-per-system-reference.md`), one audit.md section recording the findings.

## What Worked and What Didn't

**Worked well**:
- Parallel research agents were highly effective. Six agents completed in ~15 minutes total, producing comprehensive per-system data. The parallel launch pattern (all six in one message) maximized throughput.
- The two-phase approach (literature first, swift-io second) prevented confirmation bias — the tier spectrum was established before seeing what swift-io actually does.
- The user's pushback on the Reader/Writer trait question produced the deepest insight of the session. The challenge forced analysis past prior-art-pattern-matching into ecosystem-specific reasoning.

**Didn't work well**:
- Initial framing assumed swift-io was a Read/Write abstraction layer (like Go's `io`). It's actually IO infrastructure (event loop, completion queue, thread pool). This misclassification persisted through the first draft until the actual code was explored. Should have done a quick structural survey before designing the comparison framework.
- The research went through three file reorganizations (two separate documents → consolidated → scratch files promoted to reference). Starting with the end-state structure would have saved effort.
- The Reader/Writer trait analysis went through three revisions: "potential gap" → "future additive option" → "correct absence by design." Each revision was prompted by the user, not self-initiated. The AI was too deferential to prior art consensus rather than reasoning from the ecosystem's own design principles.

## Patterns and Root Causes

**Pattern: Prior art framing can become a trap.** The literature survey established "every IO system has a Reader/Writer trait" as a near-universal pattern. This created an implicit assumption that swift-io *should* have one too. The assumption survived two rounds of analysis until the user directly challenged "what do you even mean by that?" — forcing a concrete examination of what such a trait would look like in this ecosystem. The conclusion — that it would violate typed throws and erase domain-specific information — was reachable from the start but wasn't reached because the prior art framing biased toward "gap" rather than "deliberate design."

Root cause: comparative analysis excels at identifying *what exists elsewhere* but can mistake *universal adoption* for *universal necessity*. The corrective is to always ask: "what would the proposed concept look like in *this* ecosystem's type system, and what would it cost?"

**Pattern: The ecosystem's typed-throws discipline is a genuine differentiator.** Across 15 systems, only Zig achieves comparable error type precision. Every other system erases error types at some level (Rust's single `io::Error`, Go's untyped `error`, Java's `IOException` hierarchy). The Swift Institute's insistence on per-operation typed throws (`Kernel.IO.Read.Error` vs `Kernel.IO.Write.Error` vs `IO.Event.Failure`) is what makes a generic Reader/Writer trait impractical — and that's a *feature*, not a limitation. The typed-throws discipline forces domain-specific APIs, which in turn produce better error messages, exhaustive handling, and semantic accessors (`.isNotFound`, `.isPermissionDenied`).

**Pattern: "File count ≠ concept count" needs to be said explicitly.** 279 files for 72 concepts (4:1 ratio) alarmed the initial analysis. The explanation — one-type-per-file convention, namespace-first structure, error decomposition — is obvious once stated but non-obvious from the outside. Future audits of large packages should lead with this framing.

## Action Items

- [ ] **[skill]** research-process: Add guidance that comparative prior art surveys should include a "what would this look like here?" step before flagging absences as gaps — prior art consensus can bias toward false gap identification
- [ ] **[doc]** io-prior-art-and-swift-io-design-audit.md: The document is complete but could benefit from a "How to Use This Document" section explaining the two-part structure (Part I: external survey, Part II: swift-io mapping) for future readers
- [ ] **[blog]** "Why We Don't Have io.Reader" — the progression from "every IO system has this" to "it would violate our type system" to "the layered concrete approach is correct" is a compelling narrative about principled API design vs. cargo-culting prior art
