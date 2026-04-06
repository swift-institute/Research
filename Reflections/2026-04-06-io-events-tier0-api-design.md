---
date: 2026-04-06
session_objective: Design the definitive public API for IO Events, starting from first principles and arriving at a Tier 0 consumer surface
packages:
  - swift-io
status: pending
---

# IO Events Tier 0 API Design — From Specification to Architectural Challenge

## What Happened

Session began with a focused investigation brief (`HANDOFF-io-events-perfect-api.md`) asking for a `.swiftinterface`-level API specification for IO Events. Read all 6 research documents and 12+ source files. Produced `Research/io-events-perfect-public-api.md` with four access tiers, nine design tensions resolved, and full convention compliance.

The user then challenged the result: "this still looks quite difficult to use... why not just `IO.run { }`?" This reframed the entire exercise. The original "Tier 1" (Selector, Channel, Token) was actually Tier 2. The real Tier 0 — three concepts (Stream, Buffer, Error) — was missing.

Built the Tier 0 specification. The reviewer (second session) challenged Sendable on resource types. Created experiment `sending-vs-sendable-structured-concurrency` (10 variants) — discovered a fundamental constraint: ~Copyable values cannot be consumed in ANY escaping closure (Swift 6.3). The Sendable vs `sending` debate was moot.

Explored Apple's `swift-http-api-proposal` — found they explicitly reject Sendable on resource types, use `consuming sending` closure parameters, and never expose Reader/Writer to user task management. This led to replacing `split()` + Transfer wrapper with `callAsFunction` — `stream { reader } write: { writer }`.

Collaborative discussion (3 rounds, Claude + ChatGPT) converged on: one target, `IO.Run` property pattern per [IMPL-020], error mapping with reachability rule, staged build order.

User then challenged further: why a new `IO Stream` target? (No backward compat needed.) Then: why `IO.Stream` wrapping `IO.Event.Channel` at all? Then: should Event/Completion/Blocking even be a user-visible distinction? Each challenge simplified the design further. Final handoff presents three options (wrapper, collapse, SPI-gated) with the collapse direction clearly favored.

No source files modified. Two experiments created. One research document produced (v2.0). Handoff written.

## What Worked and What Didn't

**What worked:**
- The user's progressive challenges ("why not simpler?", "why a wrapper?", "why the distinction?") drove the design from 28 types to ~8. Each round of "why" removed an abstraction layer.
- The experiment-first approach for `consuming sending` / `callAsFunction` / `~Escapable` composition caught a real compiler limitation (~Copyable in escaping closures) before it could derail implementation.
- Exploring Apple's HTTP proposal at exactly the right moment provided empirical validation for the non-Sendable, `consuming sending` pattern. The prior art survey transformed a speculative design into a validated one.
- The collaborative discussion efficiently locked 12+ decisions in 3 rounds.

**What didn't work:**
- The initial research document's "Tier 1" was too low-level for app developers. The user had to push for the Tier 0 surface. I should have started from the user experience, not from the implementation types.
- The Sendable analysis in v1.0 was wrong ("redundant") — the reviewer caught it. The experiment revealed the real constraint was deeper (~Copyable + escaping closures). Multiple iterations were needed to get the Sendable story right.
- The research document went through 3 major revisions (v1.0 → v1.2 → v2.0) because each round revealed the prior framing was wrong. Starting from first principles of USER EXPERIENCE rather than type system features would have been more efficient.

## Patterns and Root Causes

**Pattern: API design must start from the call site, not the type system.**

The session began by cataloguing every type and its `~Copyable` / `~Escapable` / `Sendable` annotations. This produced a correct but unusable specification. The breakthrough came when the user asked "why not `IO.run { }`?" — forcing a call-site-first redesign. This is [IMPL-000] (call-site-first design) applied to API research, not just implementation. The skill says "write the ideal expression first" — the research should have started with the ideal USAGE first.

**Pattern: each "why" removes a layer.**

The session went through 5 simplification rounds: (1) add Tier 0 above Tier 1, (2) replace split+Transfer with callAsFunction, (3) remove new target, (4) question wrapper vs collapse, (5) question Event/Completion/Blocking distinction. Each was triggered by the user asking a form of "why is this necessary?" The design got better each time. The lesson: defensively justify every type, every module boundary, every distinction. If the justification requires backward compatibility, and backward compatibility isn't a constraint, the abstraction should collapse.

**Pattern: `consuming sending` is the successor to Sendable for ~Copyable resources.**

The Apple HTTP proposal validates this at scale. The experiment confirms it compiles. The architecture simplifies dramatically: no Sendable on resource types, no Transfer wrappers in user code, framework manages concurrency internally. This is likely a durable pattern for the ecosystem — anywhere ~Copyable resources need to cross isolation boundaries.

## Action Items

- [ ] **[skill]** implementation: Add guidance that API research must start from call-site usage examples (user experience), not from type declarations. Reference [IMPL-000] — "write the ideal expression first" applies to research, not just code.
- [ ] **[skill]** research-process: Add a check to [RES-003] template — "Does the API section start with usage examples before type declarations?" Research that catalogues types without showing usage is incomplete.
- [ ] **[package]** swift-io: The Stream-vs-Channel-collapse question (Option A/B/C in HANDOFF.md) is the next design decision. Resolution determines whether IO.Event.Channel remains public or becomes package-internal.
