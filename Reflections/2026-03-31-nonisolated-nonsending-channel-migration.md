---
date: 2026-03-31
session_objective: Migrate 5 async functions from isolation: parameter to nonisolated(nonsending)
packages:
  - swift-async-primitives
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: package_insight
    target: swift-async-primitives
    description: nonisolated(nonsending) confirmed to satisfy AsyncIteratorProtocol with typed throws + ~Copyable
---

# Nonisolated(nonsending) Channel Migration — Protocol Witness Confirmation

## What Happened

Picked up a handoff brief to migrate 5 remaining `isolation: isolated (any Actor)? = #isolation` functions in swift-async-primitives to `nonisolated(nonsending)`. The already-migrated `Bounded.Sender.send(_:)` served as the template.

Grepped swift-primitives and swift-foundations for explicit `isolation:` call sites — found none. The `next(isolation: actor)` calls in `swift-foundations/swift-async/Sources/Async Sequence/` operate on generic `AsyncIteratorProtocol` iterators via the stdlib protocol method, not our concrete types. All callers of our 5 functions relied on the default value.

Migrated all 5 sites, cleaned up doc comments (including a stale `/// - isolation:` on the already-migrated sender), built successfully, io-bench tests passed.

## What Worked and What Didn't

**Worked well**: The handoff document was precise — exact file paths, line numbers, reference pattern, ordered next steps. Made the session nearly mechanical. Zero ambiguity about what to do.

**Confidence was initially uncertain on one point**: whether `nonisolated(nonsending) func next()` (without the `isolation:` parameter) satisfies `AsyncIteratorProtocol`'s `next(isolation:)` requirement. The handoff correctly flagged this as the key verification item. Build confirmed it works.

## Patterns and Root Causes

The protocol conformance question is the only non-trivial finding. SE-0461 was designed so that `nonisolated(nonsending)` replaces the `isolation: isolated (any Actor)? = #isolation` pattern — but "designed to work" and "confirmed working for typed-throws ~Copyable iterators" are different claims. This session provides empirical confirmation for the specific combination of:

- `nonisolated(nonsending)` on `next()`
- `AsyncIteratorProtocol` conformance
- Typed throws (`throws(Async.Channel<Element>.Error)`)
- `~Copyable` `Element` constraint
- `@_optimize(none)` workaround co-present

The broader pattern: handoff-driven sessions are efficient when the handoff is specific. This one took roughly 10 minutes of wall-clock time for a change that touches concurrency-sensitive code across 4 files. The call-site audit (grep across two superrepos) is the step that provides safety — without it, removing a public parameter would be a gamble.

## Action Items

- [ ] **[package]** swift-async-primitives: `nonisolated(nonsending)` confirmed to satisfy `AsyncIteratorProtocol.next(isolation:)` with typed throws and ~Copyable — can reference this session when migrating other `AsyncIteratorProtocol` conformances
